#!/bin/sh
# Builds vlcspike on Linux and runs it on the given media files.
# Needs the system libVLC: on Debian/Ubuntu, sudo apt install libvlc5 vlc-plugin-base
set -e
cd "$(dirname "$0")"
cc -O2 -Wall -o vlcspike vlcspike.c -ldl -lpthread
mkdir -p out
for f in "$@"; do
    echo "===== $f"
    ./vlcspike "$f" --out out --repeat || echo "exit $?"
done
