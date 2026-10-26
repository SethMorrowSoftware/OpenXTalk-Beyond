#!/usr/bin/env bash
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

# Dump the scripts of every binary IDE stack to text, for build_map.py.
#   bash make_dumps.sh <OpenXTalk-Beyond checkout> <LiveCode-Community engine> <out dir>
# Uses tools/oxt/ide-stack-dump.livecodescript headless (-ui): each stack is
# loaded with messages locked and never saved, so the checkout is not changed.
set -u
repo=$(cd "$1" && pwd); engine=$2; out=$(mkdir -p "$3" && cd "$3" && pwd)
cd "$repo"
git ls-files -z -- 'ide/*.livecode' 'ide/*.rev' 'ide/*.oxtstack' 'ide-support/*' | \
while IFS= read -r -d '' s; do
  case "$s" in *.livecode|*.rev|*.oxtstack) ;; *) continue ;; esac
  dst="$out/$(printf '%s' "$s" | tr '/ ' '__').txt"
  OXT_DUMP_FILE="$repo/$s" OXT_DUMP_OUT="$dst" timeout 60 "$engine" -ui tools/oxt/ide-stack-dump.livecodescript >/dev/null 2>&1 \
    || echo "not dumped: $s"
done
