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

# Start the IDE of an installed OXT-Beyond.app as a user does, with its home
# stack, splash, menus and palettes and a user interface, and check that it
# is still running after a while. The other macOS checks run the engine
# with -ui or with a test stack of their own, so none of them builds the
# IDE's menu bar: 0.2.1 crashed there on macOS 15 a few seconds after it
# started, and every check passed.
#
#   tools/ci/mac_ide_start.sh <OXT-Beyond.app> <output folder> [seconds]
#
# The output folder gets the engine's output, two screenshots and, if the
# IDE ended, the crash report macOS wrote, whose faulting thread is also
# printed. It also gets the windows that came and went while the IDE
# started (tools/ci/startup_windows.py watches the IDE's windows on the
# screen from before it starts): a window that showed and was taken away
# again is a "ghost window" (LittleNemo, openxtalk.org p=25967; the splash
# is meant to go), as tools/ci/linux_ide_start.sh checks on Linux. Exit
# status 0 when the IDE was still running at the end and no window came
# and went. With OXT_GHOST_WINDOWS=warn, windows that came and went are a
# warning: media-check.yml starts a published release, which the change
# that runs it did not build.

app=$1
out=$2
seconds=${3:-90}
if [ -z "$app" ] || [ -z "$out" ]; then
  echo "usage: $0 <OXT-Beyond.app> <output folder> [seconds]" >&2
  exit 2
fi
mkdir -p "$out"
echo "Machine: $(uname -m), macOS $(sw_vers -productVersion)"

reports=~/Library/Logs/DiagnosticReports
ls "$reports" > "$out/reports-before.txt" 2>/dev/null

# The windows that come and go while the IDE starts, watched from before
# it starts
here=$(cd "$(dirname "$0")" && pwd)
watch_seconds=$(( seconds < 60 ? seconds : 60 ))
rm -f "$out/startup-windows-ready"
python3 "$here/startup_windows.py" --process OXT-Beyond --seconds "$watch_seconds" \
  --log "$out/startup-windows.txt" --ready "$out/startup-windows-ready" \
  > "$out/startup-windows-errors.txt" 2>&1 &
watcher=$!
watching=no
for i in $(seq 1 50); do
  if [ -e "$out/startup-windows-ready" ]; then watching=yes; break; fi
  sleep 0.1
done

"$app/Contents/MacOS/OXT-Beyond" > "$out/ide-output.txt" 2>&1 &
pid=$!
status=running
for i in $(seq 1 "$seconds"); do
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid"
    status="ended with exit status $? after $i s"
    break
  fi
  [ "$i" = 20 ] && screencapture -x "$out/ide-20s.png"
  sleep 1
done
screencapture -x "$out/ide-end.png"
echo "IDE: $status"
kill "$pid" 2>/dev/null
sleep 2
kill -9 "$pid" 2>/dev/null
echo "--- the engine's output"
head -c 20000 "$out/ide-output.txt"
echo

wait "$watcher"
ghost_status=$?
echo "--- windows while the IDE started (tools/ci/startup_windows.py)"
cat "$out/startup-windows.txt" 2>/dev/null
windows=ok
if [ "$watching" != yes ]; then
  echo "The window watcher's output:"
  tail -n 20 "$out/startup-windows-errors.txt"
  echo "::error title=IDE start::The window watcher (tools/ci/startup_windows.py) did not start, so the start was not checked for windows that came and went"
  windows=failed
elif [ "$ghost_status" != 0 ]; then
  echo "The window watcher's output:"
  tail -n 20 "$out/startup-windows-errors.txt"
  ghosts=$(grep '^GHOST' "$out/startup-windows.txt" 2>/dev/null | sed 's/^GHOST //' | tr '\n' ';')
  ghosts=${ghosts:-the watcher ended with exit status $ghost_status}
  if [ "${OXT_GHOST_WINDOWS:-error}" = warn ]; then
    echo "::warning title=IDE start::Windows came and went while the IDE started (a release this change did not build): $ghosts"
  else
    echo "::error title=IDE start::Windows came and went while the IDE started: $ghosts"
    windows=failed
  fi
fi
if [ "$status" = running ]; then
  [ "$windows" = ok ] && exit 0
  exit 1
fi

# macOS writes the crash report a few seconds after the crash
for i in $(seq 1 30); do
  new=$(ls "$reports" 2>/dev/null | grep -E '^(OXT-Beyond|LiveCode)' | grep -vxF -f "$out/reports-before.txt")
  [ -n "$new" ] && break
  sleep 1
done
for f in $new; do
  cp "$reports/$f" "$out/"
  echo "--- $f: the faulting thread (image, offset, symbol)"
  python3 - "$reports/$f" <<'PY'
import json, sys
text = open(sys.argv[1]).read()
try:
    body = json.loads(text[text.index('\n') + 1:])
except ValueError:
    print(text[:20000])
    sys.exit(0)
print(body.get('exception'))
images = body.get('usedImages', [])
thread = body['threads'][body.get('faultingThread', 0)]
for frame in thread.get('frames', [])[:40]:
    image = images[frame['imageIndex']] if frame.get('imageIndex', -1) < len(images) else {}
    print('  %-24s 0x%-8x %s' % (image.get('name', '?'), frame.get('imageOffset', 0), frame.get('symbol', '')))
PY
done
exit 1
