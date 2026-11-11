#!/bin/bash
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

# Builds the web (HTML5) engine of this checkout and writes the web runtime
# into a new folder:
#
#   tools/ci/build-web.sh <runtime folder>
#   tools/ci/build-web.sh --libraries
#
# (--libraries builds only the libraries below, which a cache can then
# keep whether the engine builds or not.)
#
# The web runtime is what an installed OXT-Beyond has in
# Runtime/Emscripten/js (tools/oxt/package.py --web-runtime installs it),
# where the IDE's web builder takes a web standalone's files from:
#
#   standalone-community-<version>.js, .wasm   the engine (WebAssembly that
#                                              waits with Asyncify)
#   standalone-community-<version>.html        the page
#   lean/standalone-community-<version>.*      the same engine without the
#                                              xTalk Suite's libraries (step
#                                              5), for the standalones that
#                                              use none of them
#   emscripten-standalone-template/            the files every standalone
#                                              gets (its font)
#   emscripten-desktop-fonts/                  the desktop fonts (Arimo,
#                                              Tinos, Cousine), which the
#                                              builder adds for the Web
#                                              pane's "Desktop fonts"
#   emscripten-startup-template.livecodescript the startup script's template
#
# <version> is BUILD_SHORT_VERSION in the file version, which the IDE's
# builder asks for (the version of the IDE).
#
# It needs Linux with the tools of a Linux build (BUILDING.md: gcc and g++,
# make, perl, bison and flex, and Python 2.7 as "python" for gyp and
# config.py), python3 3.10 or later, and the Emscripten SDK of the version
# in config/emscripten-version, activated (emcc on PATH, which
# <emsdk>/emsdk_env.sh does) or named by EMSDK. .github/workflows/web.yml
# runs it in an Ubuntu 22.04 container, which has both Pythons.
#
# The libraries: the engine links OpenSSL, ICU and the Thirdparty libraries
# built with Emscripten (prebuilt/lib/emscripten/js), and the build's host
# tools (lc-compile, and the others that make the engine's sources) link
# ICU, libz and libffi built for Linux (prebuilt/lib/linux/<arch>). No
# server publishes these, so this script builds the ones that are missing:
# OpenSSL, ICU and the Thirdparty libraries with
# prebuilt/build-libraries.sh (OpenSSL's and ICU's sources are the only
# downloads), libz and libffi in a Linux build folder, build-linux-<arch>,
# which is configured for nothing else. The build runs
# prebuilt/fetch-libraries.sh, which would look for tarballs that nobody
# publishes, so this script sets PREBUILT_SKIP_FETCH=1. A second run, or a
# run with prebuilt's library folders restored from a cache (web.yml),
# builds only the engine.
#
# Environment:
#   WEB_JOBS  how many jobs make runs at once (default: the number of
#             processors)
#   EMSDK     the Emscripten SDK, when emcc is not on PATH
#   NO_XTALK_WEB=1, XTALK_WEB_LOCAL=<xTalk Suite checkout>
#             link none of the xTalk Suite's native libraries, or that
#             checkout's instead of the pinned ones (step 5)

set -euo pipefail

if [ $# -ne 1 ] ; then
	echo "usage: $0 <runtime folder> | --libraries" >&2
	exit 2
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT=
if [ "$1" != --libraries ] ; then
	OUT=$1
	case "${OUT}" in
		/*) ;;
		*) OUT="$(pwd)/${OUT}" ;;
	esac
fi
JOBS=${WEB_JOBS:-$(nproc)}

function fail {
	echo "error: $*" >&2
	exit 1
}

# A new folder, so that no file of another build stays in it
if [ -n "${OUT}" ] && [ -e "${OUT}" ] && [ -n "$(ls -A "${OUT}" 2>/dev/null)" ] ; then
	fail "${OUT} exists and is not empty"
fi

cd "${REPO}"

case "$(uname -s)" in
	Linux) ;;
	*) fail "the web engine is built on Linux" ;;
esac

# The architecture name of prebuilt/scripts/platform.inc, which names the
# folder of the host's libraries
case "$(uname -m)" in
	x86_64) HOST_ARCH=x86_64 ;;
	aarch64|arm64) HOST_ARCH=arm64 ;;
	*) fail "no prebuilt library folder for a $(uname -m) host" ;;
esac

# The tools
python -c 'import sys; sys.exit(sys.version_info[0] != 2)' 2>/dev/null ||
	fail "\"python\" must be Python 2.7 (gyp and config.py need it)"
python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null ||
	fail "python3 must be Python 3.10 or later (Emscripten needs it)"
if ! command -v emcc >/dev/null 2>&1 && [ -n "${EMSDK:-}" ] ; then
	# shellcheck disable=SC1091 # the SDK's own script
	source "${EMSDK}/emsdk_env.sh" >/dev/null
fi
command -v emcc >/dev/null 2>&1 ||
	fail "emcc not found: activate the Emscripten SDK (source <emsdk>/emsdk_env.sh) or set EMSDK"
EMSCRIPTEN_WANTED=$(head -n 1 config/emscripten-version | tr -d '[:space:]')
EMSCRIPTEN_FOUND=$(emcc --version | sed -n '1s/^emcc ([^)]*) \([^ ]*\).*/\1/p')
if [ "${EMSCRIPTEN_FOUND}" != "${EMSCRIPTEN_WANTED}" ] ; then
	echo "warning: Emscripten ${EMSCRIPTEN_FOUND:-of an unknown version} is not the" \
		"version this repository builds with, ${EMSCRIPTEN_WANTED} (config/emscripten-version)" >&2
fi

VERSION=$(sed -n 's/^BUILD_SHORT_VERSION *= *\([^ ]*\) *$/\1/p' version)
[ -n "${VERSION}" ] || fail "no BUILD_SHORT_VERSION in the file version"

echo "Web engine ${VERSION}: Emscripten ${EMSCRIPTEN_FOUND}, ${JOBS} jobs, host linux-${HOST_ARCH}"
echo "Runtime folder: ${OUT:-none (--libraries)}"

PREBUILT="${REPO}/prebuilt"
LIB_WEB="${PREBUILT}/lib/emscripten/js"
LIB_HOST="${PREBUILT}/lib/linux/${HOST_ARCH}"
BIN_HOST="${PREBUILT}/bin/linux/${HOST_ARCH}"

# True when every one of the libraries (lib<name>.a) is in the folder
function hasLibraries {
	local DIR=$1
	shift
	local LIB
	for LIB in "$@" ; do
		[ -f "${DIR}/${LIB}.a" ] || return 1
	done
}

# The Thirdparty libraries that the web engine links (lib_versions.inc)
read -r -a THIRDPARTY_LIBS <<< "$(bash -c 'source prebuilt/scripts/lib_versions.inc && echo "${Thirdparty_LIBS_emscripten}"')"
[ ${#THIRDPARTY_LIBS[@]} -gt 0 ] || fail "no Thirdparty_LIBS_emscripten in prebuilt/scripts/lib_versions.inc"
ICU_LIBS=(libicudata libicui18n libicuio libicutu libicuuc)
ICU_DATA=$(bash -c 'source prebuilt/scripts/lib_versions.inc && echo "icudt${ICU_VERSION%%.*}l.dat"')

# Every build of the engine runs prebuilt/fetch-libraries.sh (the actions of
# prebuilt/fetch.gyp's fetch-linux and fetch-emscripten, whose outputs gyp
# names relative to the build folder, where they never appear). The
# libraries it would fetch are built here, or restored by a cache.
export PREBUILT_SKIP_FETCH=1

# 1. ICU, for the host (its tools build ICU's data, and the host tools link
# it) and for the web (build-icu.sh builds both)
if hasLibraries "${LIB_WEB}" "${ICU_LIBS[@]}" && hasLibraries "${LIB_HOST}" "${ICU_LIBS[@]}" &&
		[ -x "${BIN_HOST}/icupkg" ] && [ -f "${PREBUILT}/include/unicode/uchar.h" ] &&
		[ -f "${PREBUILT}/share/${ICU_DATA}" ] ; then
	echo "ICU: already built"
else
	echo "ICU: building it for linux-${HOST_ARCH} and the web"
	(cd prebuilt && PREBUILT_MAKE_JOBS="${JOBS}" PREBUILT_BUILD_LIBS=icu ./build-libraries.sh emscripten js)
fi

# 2. libz and libffi for the host, in a Linux build folder of their own.
# config.py asks every Linux configuration for a Java SDK, which these two
# libraries do not use: a JAVA_SDK that is not set is given a name only.
if hasLibraries "${LIB_HOST}" libz libffi ; then
	echo "libz and libffi for linux-${HOST_ARCH}: already built"
else
	echo "libz and libffi: building them for linux-${HOST_ARCH}"
	JAVA_SDK="${JAVA_SDK:-/usr/lib/jvm/default-java}" make config-linux-"${HOST_ARCH}"
	make -C build-linux-"${HOST_ARCH}"/livecode libz libffi BUILDTYPE=Release -j"${JOBS}"
	mkdir -p "${LIB_HOST}"
	for LIB in libz libffi ; do
		cp "build-linux-${HOST_ARCH}/livecode/out/Release/obj.target/thirdparty/${LIB}/${LIB}.a" "${LIB_HOST}/"
	done
fi

# 3. The Thirdparty libraries for the web (build-thirdparty.sh configures
# build-emscripten and builds its target thirdparty-prebuilts)
if hasLibraries "${LIB_WEB}" "${THIRDPARTY_LIBS[@]}" ; then
	echo "Thirdparty libraries for the web: already built"
else
	echo "Thirdparty libraries: building them for the web"
	(cd prebuilt && PREBUILT_BUILD_LIBS=thirdparty ./build-libraries.sh emscripten js)
fi

# 4. OpenSSL for the web, for encrypt and decrypt (build-openssl.sh, which
# names its libraries libcustomcrypto and libcustomssl, as on Linux)
if hasLibraries "${LIB_WEB}" libcustomcrypto libcustomssl && [ -f "${PREBUILT}/include/openssl/evp.h" ] ; then
	echo "OpenSSL for the web: already built"
else
	echo "OpenSSL: building it for the web"
	(cd prebuilt && MAKEFLAGS="-j${JOBS}" PREBUILT_BUILD_LIBS=openssl ./build-libraries.sh emscripten js)
fi

if [ -z "${OUT}" ] ; then
	echo "The libraries are built."
	exit 0
fi

# 5. The xTalk Suite's native libraries that the engine links into itself
# (engine/src/em-xtalk-web.cpp), as the web IDE's does (build-web-ide.sh):
# the archives pinned in tools/oxt/xtalk-extensions.json ("web_libraries"),
# or with XTALK_WEB_LOCAL=<xTalk Suite checkout> that checkout's, written as
# objects into build-emscripten/xtalk-web. NO_XTALK_WEB=1 links none (the
# extensions then load and fail on their first call, as in earlier releases). The
# linked engine is deleted, so that the link below runs again with what is
# there now: its gyp inputs do not list the objects.
cd "${REPO}"
rm -rf build-emscripten/xtalk-web
if [ "${NO_XTALK_WEB:-}" != 1 ] ; then
	python3 "${REPO}/tools/web-ide/xtalk_web_libraries.py" fetch --out build-emscripten/xtalk-web \
		${XTALK_WEB_LOCAL:+--local "${XTALK_WEB_LOCAL}"}
fi
rm -f build-emscripten/livecode/out/Release/standalone-community-*.js \
	build-emscripten/livecode/out/Release/standalone-community-*.wasm
rm -rf build-emscripten/livecode/out/Release/lean

# 6. The engine: config-emscripten, then javascriptify, which links the
# engine's object with its JavaScript libraries into the .js and .wasm and
# writes the page (engine/engine.gyp)
make config-emscripten
BUILDTYPE=Release emmake make -C build-emscripten/livecode javascriptify -j"${JOBS}"

# 7. The runtime folder
BUILT="${REPO}/build-emscripten/livecode/out/Release"
mkdir -p "${OUT}"
for EXT in js wasm html ; do
	FILE="${BUILT}/standalone-community-${VERSION}.${EXT}"
	[ -s "${FILE}" ] || fail "the build wrote no ${FILE}"
	cp "${FILE}" "${OUT}/"
done
# The lean engine, without the xTalk Suite's libraries, under the same
# names in lean/ (engine.gyp's javascriptify), which the web builder gives
# the standalones that use none of them
mkdir -p "${OUT}/lean"
for EXT in js wasm html ; do
	FILE="${BUILT}/lean/standalone-community-${VERSION}.${EXT}"
	[ -s "${FILE}" ] || fail "the build wrote no ${FILE}"
	cp "${FILE}" "${OUT}/lean/"
done
# A WebAssembly module starts with "\0asm"
for WASM in "standalone-community-${VERSION}.wasm" "lean/standalone-community-${VERSION}.wasm" ; do
	[ "$(head -c 4 "${OUT}/${WASM}" | od -An -c | tr -d ' ')" = '\0asm' ] ||
		fail "${WASM} is not WebAssembly"
done
cp engine/rsrc/emscripten-startup-template.livecodescript "${OUT}/"
cp -R engine/rsrc/emscripten-standalone-template "${OUT}/"
# without the dotfiles (its .gitignore), which the IDE's builder would put
# into every standalone
find "${OUT}/emscripten-standalone-template" -name '.*' -prune -exec rm -rf {} +
[ -n "$(find "${OUT}/emscripten-standalone-template" -type f)" ] ||
	fail "engine/rsrc/emscripten-standalone-template has no files"
cp -R engine/rsrc/emscripten-desktop-fonts "${OUT}/"
find "${OUT}/emscripten-desktop-fonts" -name '.*' -prune -exec rm -rf {} +
[ "$(find "${OUT}/emscripten-desktop-fonts" -name '*.ttf' -type f | wc -l)" -eq 12 ] ||
	fail "engine/rsrc/emscripten-desktop-fonts has not the twelve fonts"

echo
echo "Web runtime ${VERSION} in ${OUT}:"
(cd "${OUT}" && find . -type f | LC_ALL=C sort | sed 's|^\./||' | while read -r FILE ; do
	printf '  %12s  %s  %s\n' "$(stat -c %s "${FILE}")" "$(sha256sum "${FILE}" | cut -c1-16)" "${FILE}"
done)
