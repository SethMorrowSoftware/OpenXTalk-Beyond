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

# Start the IDE of an extracted Linux package as a user does, through its
# launcher, with its home stack, splash, menus and palettes on an Xvfb
# screen under a window manager (openbox), and check that it is still
# running after a while and has put windows on the screen. The other Linux
# checks run the engine with -ui or with a test stack of their own, so
# none of them starts the IDE itself; this is the macOS IDE start check's
# twin (tools/ci/mac_ide_start.sh), and the first time the IDE runs on
# Linux arm64.
#
#   tools/ci/linux_ide_start.sh <package folder> <output folder> [seconds]
#
# The IDE runs with a scratch home folder, as on a first start. The output
# folder gets the engine's output, the top-level windows (xwininfo) and two
# screenshots. Exit status 0 when the IDE was still running at the end
# and had at least one window of its own on the screen. Needs Xvfb,
# openbox, xwininfo (x11-utils) and ImageMagick's import.

root=$1
out=$2
seconds=${3:-90}
if [ -z "$root" ] || [ -z "$out" ]; then
  echo "usage: $0 <package folder> <output folder> [seconds]" >&2
  exit 2
fi
mkdir -p "$out"
out=$(cd "$out" && pwd)
echo "Machine: $(uname -m), $(. /etc/os-release && echo "$PRETTY_NAME")"

display=
for n in $(seq 91 119); do
  if [ ! -e "/tmp/.X$n-lock" ]; then display=":$n"; break; fi
done
export DISPLAY=$display
Xvfb "$DISPLAY" -screen 0 1600x1000x24 -nolisten tcp > /dev/null 2>&1 &
xvfb=$!
sleep 2
openbox --replace > /dev/null 2>&1 &
wm=$!
sleep 2

home=$(mktemp -d)
mkdir -p "$home/.config" "$home/.local/share"
HOME=$home XDG_CONFIG_HOME=$home/.config XDG_DATA_HOME=$home/.local/share \
  "$root/oxt-beyond" > "$out/ide-output.txt" 2>&1 &
pid=$!
status=running
for i in $(seq 1 "$seconds"); do
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid"
    status="ended with exit status $? after $i s"
    break
  fi
  [ "$i" = 20 ] && import -window root "$out/ide-20s.png" 2>/dev/null
  sleep 1
done
import -window root "$out/ide-end.png" 2>/dev/null
# The top-level windows with a name (the window manager's have none here)
xwininfo -root -children 2>/dev/null | grep -E '^ +0x[0-9a-f]+ "' > "$out/windows.txt"
# openbox reparents a managed window into a frame: look one level down too
xwininfo -root -tree 2>/dev/null | grep -E '^ +0x[0-9a-f]+ "' > "$out/windows-tree.txt"
windows=$(grep -c . "$out/windows-tree.txt")
echo "IDE: $status"
echo "Windows with a name on the screen: $windows"
sed 's/^ */  /' "$out/windows-tree.txt" | head -40
kill "$pid" 2>/dev/null
sleep 2
kill -9 "$pid" 2>/dev/null
kill "$wm" "$xvfb" 2>/dev/null
rm -rf "$home"

echo "Engine output (last 40 lines):"
tail -n 40 "$out/ide-output.txt" | sed 's/^/  /'
if [ "$status" != running ]; then
  echo "::error title=IDE start::The IDE $status (tools/ci/linux_ide_start.sh; output and screenshots in the logs artifact)"
  exit 1
fi
if [ "$windows" -lt 1 ]; then
  echo "::error title=IDE start::The IDE was running but had no window on the screen after $seconds s"
  exit 1
fi
if [ -n "$GITHUB_STEP_SUMMARY" ]; then
  printf '### IDE start (%s)\n\nThe IDE was still running after %s s, with %s named windows on the screen.\n\n' \
    "$(uname -m)" "$seconds" "$windows" >> "$GITHUB_STEP_SUMMARY"
fi
exit 0
