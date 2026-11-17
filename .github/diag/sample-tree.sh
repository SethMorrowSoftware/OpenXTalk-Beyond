#!/bin/bash
# Diagnostic: samples the X window tree of display $1 until "$2.stop" is
# there, and keeps the sample with the most windows in $2.
best=0
while [ ! -e "$2.stop" ]; do
  t=$(xwininfo -display "$1" -root -tree 2>/dev/null)
  n=$(printf '%s\n' "$t" | wc -l)
  if [ "$n" -gt "$best" ]; then best=$n; printf '%s\n' "$t" > "$2"; fi
  sleep 0.3
done
