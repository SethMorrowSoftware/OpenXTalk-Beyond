#!/bin/bash
# CEF upgrade spike (Linux): how far is libbrowser from a current CEF?
#
# A measuring tool, not part of the build. It changes nothing in the tree
# that a build reads: everything happens in a scratch copy under $WORK.
#
#   1. Reads Spotify's CEF index and picks the newest STABLE linux64 build
#      (or CEF_VERSION if set), and prints what the index says about every
#      platform OXT ships a browser on (sizes, and whether a build exists).
#   2. Downloads its "minimal" distribution (headers, the libcef_dll wrapper
#      sources, Release/ and Resources/), checks the published SHA-1, and the
#      CEF 74 one the tree uses today (SHA-1 from prebuilt/cef-sha1sums), and
#      compares their unpacked sizes and the glibc/libstdc++ versions libcef.so
#      needs (the build's floor is glibc 2.31, GLIBCXX 3.4.28).
#   3. Swaps the new include/ and libcef_dll/ into a scratch copy of
#      thirdparty/libcef the way thirdparty/libcef/UPDATE.md says, regenerates
#      libcef.gypi and libcef.stubs with the tree's own generators, and runs
#      util/weak_stub_maker.pl over the result.
#   4. Compiles the libcef_dll wrapper and the four CEF sources of libbrowser
#      (libbrowser_cef.cpp, _cef_lnx.cpp, _cefprocess.cpp, _cefprocess_lnx.cpp)
#      against those headers with every compiler/standard pair in COMBOS, and
#      for the first pair that builds the wrapper, links nothing but checks
#      that every cef_* symbol the objects need is exported by the new libcef.so.
#
# Output: $OUT/report.md (also appended to $GITHUB_STEP_SUMMARY) and one log
# per compile under $OUT/logs.

set -u
set -o pipefail

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
WORK="${WORK:-$REPO/.cef-spike}"
OUT="${OUT:-$WORK/out}"
COMBOS="${COMBOS:-g++-9:c++11 g++-9:c++17 g++-10:c++17 g++-10:c++20}"
JOBS="$(nproc)"
mkdir -p "$WORK/dl" "$OUT/logs"
REPORT="$OUT/report.md"
: > "$REPORT"

say() { printf '%s\n' "$*" | tee -a "$REPORT"; }
mib() { awk -v b="$1" 'BEGIN { printf "%.1f MiB", b / 1048576 }'; }

say "# CEF upgrade spike (Linux)"
say ""
say "Tree today: headers $(sed -n 's/^#define CEF_VERSION "\(.*\)"$/\1/p' "$REPO/thirdparty/libcef/include/cef_version.h"), binaries $(cat "$REPO/prebuilt/versions/cef")+$(cat "$REPO/prebuilt/versions/cef_buildrevision")+chromium-$(cat "$REPO/prebuilt/versions/cefchromium")"
say ""

# --- 1. The index ----------------------------------------------------------
curl -fsSL --retry 3 -o "$WORK/dl/index.json" https://cef-builds.spotifycdn.com/index.json || { say "error: could not read the CEF index"; exit 1; }

python3 - "$WORK/dl/index.json" "${CEF_VERSION:-}" "$WORK/pick.env" >> "$REPORT" <<'EOF'
import json, sys
idx = json.load(open(sys.argv[1]))
want = sys.argv[2]
def stable(plat):
    for v in idx.get(plat, {}).get("versions", []):
        if want and v["cef_version"] != want:
            continue
        if want or v.get("channel") == "stable":
            return v
    return None
def minimal(v):
    for f in v["files"]:
        if f["type"] == "minimal":
            return f
    return None
pick = stable("linux64")
if not pick:
    print("error: no stable linux64 build in the index"); sys.exit(1)
m = minimal(pick)
with open(sys.argv[3], "w") as e:
    e.write("NEW_VER='%s'\nNEW_CHROMIUM='%s'\nNEW_FILE='%s'\nNEW_SHA1='%s'\n" % (pick["cef_version"], pick["chromium_version"], m["name"], m["sha1"]))
print("Newest stable CEF: **%s** (Chromium %s)\n" % (pick["cef_version"], pick["chromium_version"]))
print("| Platform (CEF name) | Newest stable | minimal download | standard download |")
print("|---|---|---|---|")
for plat in ["linux64", "linuxarm64", "linux32", "linuxarm", "windows64", "windows32", "windowsarm64", "macosx64", "macosarm64"]:
    v = stable(plat)
    if not v:
        print("| %s | none | | |" % plat); continue
    sizes = {f["type"]: f.get("size", 0) for f in v["files"]}
    fmt = lambda b: "%.0f MiB" % (b / 1048576.0) if b else "-"
    print("| %s | %s | %s | %s |" % (plat, v["cef_version"], fmt(sizes.get("minimal", 0)), fmt(sizes.get("standard", 0))))
for plat, label in [("linux64", "74.1.19 linux64"), ("windows64", "74.1.19 windows64"), ("windows32", "74.1.19 windows32")]:
    for v in idx.get(plat, {}).get("versions", []):
        if v["cef_version"].startswith("74.1.19+"):
            sizes = {f["type"]: f.get("size", 0) for f in v["files"]}
            print("| %s (today) | %s | %.0f MiB | %.0f MiB |" % (plat, v["cef_version"], sizes.get("minimal", 0) / 1048576.0, sizes.get("standard", 0) / 1048576.0))
print("")
EOF
[ -s "$WORK/pick.env" ] || exit 1
. "$WORK/pick.env"

# --- 2. Download and compare the binaries -------------------------------------
fetch() {  # fetch FILE SHA1 -> unpacks into $WORK/dl/<dir>
	local file="$1" sha="$2" url
	url="https://cef-builds.spotifycdn.com/$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$file")"
	if [ ! -f "$WORK/dl/$file" ]; then
		curl -fsSL --retry 3 -o "$WORK/dl/$file" "$url" || { say "error: download of $file failed"; return 1; }
	fi
	if [ "$(sha1sum "$WORK/dl/$file" | cut -d' ' -f1)" != "$sha" ]; then
		say "error: SHA-1 mismatch for $file"; rm -f "$WORK/dl/$file"; return 1
	fi
	(cd "$WORK/dl" && tar -xf "$file")
}
OLD_FILE="cef_binary_$(cat "$REPO/prebuilt/versions/cef")+$(cat "$REPO/prebuilt/versions/cef_buildrevision")+chromium-$(cat "$REPO/prebuilt/versions/cefchromium")_linux64_minimal.tar.bz2"
OLD_SHA1="$(awk -v f="$OLD_FILE" '$0 !~ /^#/ && $2 == f { print $1 }' "$REPO/prebuilt/cef-sha1sums")"
fetch "$NEW_FILE" "$NEW_SHA1" || exit 1
fetch "$OLD_FILE" "$OLD_SHA1" || exit 1
NEW_DIR="$WORK/dl/${NEW_FILE%.tar.bz2}"
OLD_DIR="$WORK/dl/${OLD_FILE%.tar.bz2}"

glibc_needs() {  # highest GLIBC_ and GLIBCXX_ a file needs
	objdump -T "$1" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1
	objdump -T "$1" 2>/dev/null | grep -o 'GLIBCXX_[0-9.]*' | sort -uV | tail -1
}
shipped_size() {  # what build-cef.sh packages: Release/ + Resources/, libcef.so stripped
	local d="$1" tmp
	tmp="$(mktemp -d)"
	cp -a "$d/Release/." "$d/Resources/." "$tmp/"
	strip --strip-unneeded "$tmp/libcef.so" 2>/dev/null
	du -sb "$tmp" | cut -f1
	rm -rf "$tmp"
}
say "## Binaries (what build-cef.sh would package into Externals/CEF)"
say ""
say "| | CEF 74 (today) | $NEW_VER |"
say "|---|---|---|"
say "| Externals/CEF total | $(mib "$(shipped_size "$OLD_DIR")") | $(mib "$(shipped_size "$NEW_DIR")") |"
say "| libcef.so (unstripped) | $(mib "$(stat -c%s "$OLD_DIR/Release/libcef.so")") | $(mib "$(stat -c%s "$NEW_DIR/Release/libcef.so")") |"
say "| needs (libcef.so) | $(glibc_needs "$OLD_DIR/Release/libcef.so" | paste -sd' ') | $(glibc_needs "$NEW_DIR/Release/libcef.so" | paste -sd' ') |"
say ""
say "Files in Release/ + Resources/ only in $NEW_VER (build-cef.sh copies all; prebuilt/libcef.gyp lists each):"
say '```'
comm -13 <(cd "$OLD_DIR" && find Release Resources -type f | sed 's|^[^/]*/||' | grep -v '^locales/' | sort) \
         <(cd "$NEW_DIR" && find Release Resources -type f | sed 's|^[^/]*/||' | grep -v '^locales/' | sort) | tee -a "$REPORT"
say '```'
say "Gone in $NEW_VER (still named by prebuilt/libcef.gyp, so the copy step would fail):"
say '```'
comm -23 <(cd "$OLD_DIR" && find Release Resources -type f | sed 's|^[^/]*/||' | grep -v '^locales/' | sort) \
         <(cd "$NEW_DIR" && find Release Resources -type f | sed 's|^[^/]*/||' | grep -v '^locales/' | sort) | tee -a "$REPORT"
say '```'
say "Locales: $(ls "$OLD_DIR/Resources/locales" | wc -l) today, $(ls "$NEW_DIR/Resources/locales" | wc -l) in $NEW_VER"
say ""

# --- 3. A scratch thirdparty/libcef with the new headers ----------------------
SCR="$WORK/libcef"
rm -rf "$SCR"; cp -a "$REPO/thirdparty/libcef" "$SCR"
rm -rf "$SCR/include" "$SCR/libcef_dll"
cp -a "$NEW_DIR/include" "$NEW_DIR/libcef_dll" "$SCR/"
(cd "$SCR" && python2 gen_libcef_paths.py libcef_dll > libcef.gypi.new 2> "$OUT/logs/gen_paths.err")
(cd "$SCR" && python2 gen_libcef_stubs.py include > libcef.stubs.new 2> "$OUT/logs/gen_stubs.err")
say "## Generators (UPDATE.md steps)"
say ""
say "- libcef.gypi: $(grep -c "\.cc'" "$REPO/thirdparty/libcef/libcef.gypi") .cc files today, $(grep -c "\.cc'" "$SCR/libcef.gypi.new") in $NEW_VER"
say "- libcef.stubs: $(grep -c '^	' "$REPO/thirdparty/libcef/libcef.stubs") stubs today, $(grep -c '^	' "$SCR/libcef.stubs.new") in $NEW_VER; $(grep -c '^#' "$SCR/libcef.stubs.new") signatures the generator could not convert"
say "- unknown types the stub generator reports (gen_libcef_stubs.py's table needs them):"
say '```'
sort "$OUT/logs/gen_stubs.err" | uniq -c | sort -rn | head -40 | tee -a "$REPORT"
say '```'
say "- stubs only in $NEW_VER / only today:"
say '```'
diff <(grep '^	' "$REPO/thirdparty/libcef/libcef.stubs" | sed 's/:.*//' | sort) <(grep '^	' "$SCR/libcef.stubs.new" | sed 's/:.*//' | sort) | grep '^[<>]' | tee -a "$REPORT"
say '```'
say "- signatures that changed:"
say '```'
diff <(grep '^	' "$REPO/thirdparty/libcef/libcef.stubs" | sort) <(grep '^	' "$SCR/libcef.stubs.new" | sort) | grep '^[<>]' | sed 's/^\([<>]\)\s*/\1 /' | sort -k2 | \
	awk '{n=$2; sub(":","",n); c[n]++; l[n]=l[n] "\n" $0} END {for (k in c) if (c[k]==2) print substr(l[k],2)}' | tee -a "$REPORT"
say '```'
if perl "$REPO/util/weak_stub_maker.pl" "$SCR/libcef.stubs.new" "$WORK/libcefstubs.cpp" > "$OUT/logs/weak_stub_maker.log" 2>&1; then
	say "- weak_stub_maker.pl: OK ($(wc -l < "$WORK/libcefstubs.cpp") lines)"
	if g++-9 -std=c++11 -c -w -fPIC "$WORK/libcefstubs.cpp" -o "$WORK/libcefstubs.o" > "$OUT/logs/libcefstubs.log" 2>&1; then
		say "- the generated libcefstubs.cpp compiles (g++-9, c++11)"
	else
		say "- the generated libcefstubs.cpp does NOT compile (logs/libcefstubs.log)"
	fi
else
	say "- weak_stub_maker.pl: FAILED (logs/weak_stub_maker.log)"
fi
say ""

# --- 4. Compile ------------------------------------------------------------
LB_SRCS="libbrowser_cef.cpp libbrowser_cef_lnx.cpp libbrowser_cefprocess.cpp libbrowser_cefprocess_lnx.cpp"
compile_set() {  # compile_set CXX STD HEADERS-DIR TAG
	local cxx="$1" std="$2" hdr="$3" tag="$4" objdir wfail lfail f
	objdir="$WORK/obj/$tag"
	mkdir -p "$objdir"
	(cd "$hdr" && find libcef_dll -name '*.cc') > "$objdir/wrapper.list"
	# The wrapper, as objects (step 4b reads the symbols they need); one log
	# per source, failures listed in $objdir/wrapper.failed
	: > "$objdir/wrapper.failed"
	export CXX_="$cxx" STD_="$std" OBJ_="$objdir"
	(cd "$hdr" && xargs -P"$JOBS" -n1 sh -c '
		n=$(echo "$0" | tr / _)
		"$CXX_" -std="$STD_" -c -w -fPIC -O0 -DWRAPPING_CEF_SHARED -DNDEBUG -I. "$0" -o "$OBJ_/$n.o" > "$OBJ_/$n.log" 2>&1 || echo "$0" >> "$OBJ_/wrapper.failed"
	' < "$objdir/wrapper.list")
	cat "$objdir"/*.log > "$OUT/logs/$tag-wrapper.log" 2>/dev/null
	wfail=$(wc -l < "$objdir/wrapper.failed")
	lfail=""
	: > "$OUT/logs/$tag-libbrowser.log"
	for f in $LB_SRCS; do
		if ! $cxx -std="$std" -c -w -fPIC -O0 -DNDEBUG -DUSING_CEF_SHARED=1 \
			-I"$REPO/libbrowser/include" -I"$REPO/libbrowser/src" -I"$REPO/libcore/include" \
			-I"$REPO/libfoundation/include" -I"$hdr" \
			"$REPO/libbrowser/src/$f" -o "$objdir/$f.o" >> "$OUT/logs/$tag-libbrowser.log" 2>&1; then
			lfail="$lfail $f"
		fi
	done
	echo "$wfail|$(wc -l < "$objdir/wrapper.list")|${lfail:- none}"
}
mkdir -p "$WORK/obj"
say "## Compile (the libcef_dll wrapper and libbrowser's CEF sources)"
say ""
say "The engine builds C++ as c++11 on Linux (config/linux-settings.gypi). Baseline is today's CEF 74 headers."
say ""
say "| Compiler | Standard | Headers | wrapper .cc failing | libbrowser sources failing | distinct errors (libbrowser) |"
say "|---|---|---|---|---|---|"
first_ok=""
r=$(compile_set g++-9 c++11 "$REPO/thirdparty/libcef" base-g++-9-c++11)
say "| g++-9 | c++11 | CEF 74 (today) | ${r%%|*} of $(echo "$r" | cut -d'|' -f2) | $(echo "$r" | cut -d'|' -f3) | $(grep -c 'error:' "$OUT/logs/base-g++-9-c++11-libbrowser.log") |"
for combo in $COMBOS; do
	cxx="${combo%%:*}"; std="${combo##*:}"; tag="new-$cxx-$std"
	command -v "$cxx" > /dev/null || { say "| $cxx | $std | $NEW_VER | (compiler not installed) | | |"; continue; }
	r=$(compile_set "$cxx" "$std" "$SCR" "$tag")
	say "| $cxx | $std | $NEW_VER | ${r%%|*} of $(echo "$r" | cut -d'|' -f2) | $(echo "$r" | cut -d'|' -f3) | $(grep 'error:' "$OUT/logs/$tag-libbrowser.log" | sort -u | wc -l) |"
	if [ -z "$first_ok" ] && [ "${r%%|*}" = 0 ]; then first_ok="$tag"; fi
done
say ""
for combo in $COMBOS; do
	tag="new-${combo%%:*}-${combo##*:}"
	[ -f "$OUT/logs/$tag-libbrowser.log" ] || continue
	say "<details><summary>$tag: first errors (wrapper, then libbrowser)</summary>"
	say ""
	say '```'
	grep -m 15 -E 'error|#error' "$OUT/logs/$tag-wrapper.log" | sed "s|$WORK/||g" | tee -a "$REPORT"
	say '---'
	grep -E 'error:' "$OUT/logs/$tag-libbrowser.log" | sed "s|$REPO/||g" | sort -u | head -80 | tee -a "$REPORT"
	say '```'
	say "</details>"
	say ""
done

# --- 4b. Symbols the objects need vs what the new libcef.so exports -----------
if [ -n "$first_ok" ]; then
	nm -D --defined-only "$NEW_DIR/Release/libcef.so" | awk '{print $3}' | sort -u > "$WORK/exports.txt"
	nm -u "$WORK/obj/$first_ok"/*.o 2>/dev/null | awk '{print $2}' | grep '^cef_' | sort -u > "$WORK/needs.txt"
	say "## Linkage ($first_ok objects vs $NEW_VER libcef.so)"
	say ""
	say "- cef_* symbols the compiled objects need: $(wc -l < "$WORK/needs.txt"); missing from libcef.so: $(comm -23 "$WORK/needs.txt" "$WORK/exports.txt" | wc -l)"
	comm -23 "$WORK/needs.txt" "$WORK/exports.txt" | sed 's/^/  - /' | tee -a "$REPORT"
	say "- needed but not in the regenerated libcef.stubs (the engine resolves CEF through those stubs): $(comm -23 "$WORK/needs.txt" <(grep '^	' "$SCR/libcef.stubs.new" | sed 's/^\t//; s/:.*//' | sort -u) | wc -l)"
	comm -23 "$WORK/needs.txt" <(grep '^	' "$SCR/libcef.stubs.new" | sed 's/^\t//; s/:.*//' | sort -u) | sed 's/^/  - /' | tee -a "$REPORT"
	say ""
fi

[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$REPORT" >> "$GITHUB_STEP_SUMMARY"
exit 0
