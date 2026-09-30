#!/bin/sh
# Applies the script patches of tools/oxt/ide-stack-patches to the binary
# IDE stacks in the repository's ide folder, with a development engine and
# no user interface (tools/oxt/ide-stack-patch.livecodescript explains the
# patches and how the result is verified).
#
#   tools/oxt/ide-stack-patch.sh <development engine> [--check]
#
# <development engine> is the LiveCode-Community program of a Linux or macOS
# build of this repository (for example from the linux-x86_64-bin artifact
# of a CI run). --check only reports whether each patch is applied.
#
# Run it again after changing a patch: patches that are applied already are
# left alone. Do not use a Windows engine on a PC where OXT-Beyond or
# LiveCode is running: a second Windows engine hands its command line to
# the running one (engine/src/w32relaunch.cpp) instead of running it.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "usage: $0 <development engine> [--check]" >&2
    exit 2
fi
engine=$1
check=
if [ $# -eq 2 ]; then
    if [ "$2" != "--check" ]; then
        echo "usage: $0 <development engine> [--check]" >&2
        exit 2
    fi
    check=1
fi
if [ ! -x "$engine" ]; then
    echo "not an executable engine: $engine" >&2
    exit 2
fi

# A script that does not compile makes the engine wait instead of exiting
timeout_cmd=
if command -v timeout >/dev/null 2>&1; then
    timeout_cmd="timeout 300"
fi

status=0
OXT_PATCH_ROOT="$repo/ide" OXT_PATCH_CHECK="$check" \
    $timeout_cmd "$engine" -ui "$here/ide-stack-patch.livecodescript" || status=$?
exit $status
