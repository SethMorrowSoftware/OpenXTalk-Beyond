#!/bin/bash
# Diagnostic: runs the browser check in the session of the environment
# (DISPLAY, and for a Wayland session WAYLAND_DISPLAY, XDG_RUNTIME_DIR and
# XDG_SESSION_TYPE), sampling the X window tree while it runs, and prints
# the stack of an engine that left a core file.
#   check-in-session.sh NAME OXT_ROOT LOGS CORES [media_check arguments]
name=$1; root=$2; logs=$3; cores=$4; shift 4
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
mkdir -p "$logs" "$cores"
ulimit -c unlimited
echo "----- $name: DISPLAY=$DISPLAY WAYLAND_DISPLAY=${WAYLAND_DISPLAY-} XDG_SESSION_TYPE=${XDG_SESSION_TYPE-} XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR-}"
rm -f "$logs/$name.tree" "$logs/$name.tree.stop"
if [ -n "$DISPLAY" ]; then bash "$here/sample-tree.sh" "$DISPLAY" "$logs/$name.tree" & sampler=$!; fi
python3 "$repo/tools/ci/media_check.py" --install "$root" --platform linux-x86_64 --what widget,revbrowser \
  --browser-backend cef --log "$logs/$name.log" "$@"
echo "RESULT $name: exit status $?"
touch "$logs/$name.tree.stop"; [ -n "${sampler-}" ] && wait "$sampler"
if [ -s "$logs/$name.tree" ]; then
  echo "The X window tree with the most windows while it ran ($(wc -l < "$logs/$name.tree") lines):"
  grep -v '^$' "$logs/$name.tree" | cut -c1-170 | head -60
fi
exe=$(find "$root/Runtime/Linux" -name Standalone -type f | grep x86-64 | head -1)
for core in "$cores"/core.*; do
  [ -f "$core" ] || continue
  echo "===== $core ($(stat -c %s "$core") bytes)"
  timeout 600 gdb -batch -ex "set solib-search-path $root/Externals/CEF:$(dirname "$exe")/Externals/CEF" \
    -ex "bt 45" "$exe" "$core" 2>&1 | grep -v "^warning: \|^\[New LWP\|^$" | cut -c1-260 | tail -70
  mv "$core" "$core.done"
done
