#!/bin/sh
# Writes the scripts inside the binary IDE stacks (ide/ and ide-support/)
# to stack-scripts/, one file per object script, so that Git can show what
# changed in them (tools/oxt/stack_scripts.py says how they are named), or
# with --check reports whether stack-scripts/ matches the stacks. Either way
# it then reads the stacks' buttons and fields for a text colour that the
# dark or the light window hides (tools/ci/stack_inks.py).
#
#   tools/oxt/stack-scripts.sh <development engine> [--check]
#
# <development engine> is the LiveCode-Community program of a Linux or macOS
# build (for example from a release's linux-x86_64-binaries archive). Each
# stack is read with tools/oxt/ide-stack-dump.livecodescript, headless, with
# messages locked, and never saved, so the stacks are not changed. Run it
# after changing a binary stack and commit stack-scripts/ with the stack;
# the Linux build checks it (build-linux.yml, "Binary stack scripts").
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)

if [ $# -lt 1 ] || [ $# -gt 2 ] || { [ $# -eq 2 ] && [ "$2" != "--check" ]; }; then
    echo "usage: $0 <development engine> [--check]" >&2
    exit 2
fi
engine=$1
if [ ! -x "$engine" ]; then
    echo "not an executable engine: $engine" >&2
    exit 2
fi
engine=$(cd "$(dirname "$engine")" && pwd)/$(basename "$engine")

dumps=$(mktemp -d)
trap 'rm -rf "$dumps"' EXIT
bash "$repo/tools/codebase-map/make_dumps.sh" "$repo" "$engine" "$dumps"
status=0
python3 "$here/stack_scripts.py" --dumps "$dumps" ${2:+"$2"} || status=$?
# The same dumps say whether a control's words can be read in the dark and
# in the light appearance (tools/ci/stack_inks.py): after a stack change,
# and in the build's check
python3 "$repo/tools/ci/stack_inks.py" --dumps "$dumps" || status=$?
exit $status
