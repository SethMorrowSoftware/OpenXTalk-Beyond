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

# Generate the documentation data of the IDE into the checkout, as
# LiveCode's build machines did before packaging. Git keeps none of it
# (ide/.gitignore): the .lcdoc and Markdown files are its only sources, and
# tools/oxt/package.py packages nothing without it.
#
#   tools/ci/build_docs.sh <work folder> [<build output folder>]
#
# 1. LiveCode's docs builder (builder/builder_tool.livecodescript --stage
#    docs) makes LiveCode's Dictionary and the guides from docs/,
#    ide/Documentation/guides, ide/Documentation/dictionary and the
#    LiveCode Builder modules of libscript/ and engine/.
# 2. tools/ci/extension_docs.livecodescript makes the dictionary data of the
#    extensions that OXT-Beyond installs and of the IDE library, as the IDE
#    makes it when it loads them (tools/oxt/text_dictionary.py
#    --list-extensions lists them).
# 3. tools/oxt/text_dictionary.py makes the entries of the text dictionary
#    (Preferences > Dictionary) from both.
#
# It writes, in ide/Documentation/html_viewer/resources/data:
#
#   api/api.sqlite                   LiveCode's Dictionary (the IDE adds the
#                                    extensions it loads)
#   api_livecode_script/*.js,
#   api_livecode_builder/*.js        the same, as JSON
#   guide/distributed_guide.js       the guides
#   api/exports/<section>/resaved/,
#   index.txt, substitutions.txt     the text dictionary's entries
#
# and nothing else outside <work folder>.
#
# The docs run on the development engine of <build output folder>: a Linux
# build's linux-<arch>-bin, or a macOS build's Release folder. Without one,
# the script downloads the Linux x86_64 engine of an OXT-Beyond release
# (DOCS_ENGINE_* below), checks its SHA-256 and keeps it in <work folder>;
# this works on Linux x86_64 only, which includes WSL on Windows. The CI
# builds use that engine (.github/workflows/docs.yml), so that every
# platform's package gets the same data while the engines build. The
# engine's modules/lci decide which modules of libscript/ and engine/ are
# documented: only those the engine has. A new module needs a newer pinned
# engine. The script needs curl, xz, sha256sum, zip and Python 3, and the
# engine's "core" libraries of Installer/linux/libraries.txt; it needs no
# screen.

set -euo pipefail

DOCS_ENGINE_VERSION=0.2.4-rc.4
DOCS_ENGINE_URL=https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases/download/v$DOCS_ENGINE_VERSION/OXT-Beyond-$DOCS_ENGINE_VERSION-linux-x86_64-binaries.tar.xz
DOCS_ENGINE_SHA256=43a7d107b827ff905eb112e5446beabc602afb069f81ab49f948a73e61586de2

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: $0 <work folder> [<build output folder>]" >&2
  exit 2
fi
repo=$(cd "$(dirname "$0")/../.." && pwd -P)
mkdir -p "$1"
work=$(cd "$1" && pwd -P)
data=$repo/ide/Documentation/html_viewer/resources/data

if [ $# -eq 2 ]; then
  bin=$(cd "$2" && pwd -P)
else
  if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != x86_64 ]; then
    echo "$0: the pinned engine runs on Linux x86_64 only; give a build output folder" >&2
    exit 2
  fi
  bin=$work/engine/linux-x86_64-bin
  if [ "$(cat "$work/engine/sha256" 2> /dev/null)" != "$DOCS_ENGINE_SHA256" ]; then
    tarball=$work/OXT-Beyond-$DOCS_ENGINE_VERSION-linux-x86_64-binaries.tar.xz
    if ! echo "$DOCS_ENGINE_SHA256  $tarball" | sha256sum -c --status - 2> /dev/null; then
      echo "Downloading the engine of OXT-Beyond $DOCS_ENGINE_VERSION (Linux x86_64)"
      curl -sSfL --retry 3 -o "$tarball" "$DOCS_ENGINE_URL"
      echo "$DOCS_ENGINE_SHA256  $tarball" | sha256sum -c -
    fi
    rm -rf "$work/engine"
    mkdir -p "$work/engine"
    tar -xJf "$tarball" -C "$work/engine"
    echo "$DOCS_ENGINE_SHA256" > "$work/engine/sha256"
  fi
fi

if [ -x "$bin/LiveCode-Community" ]; then
  engine=$bin/LiveCode-Community
  platform=linux-x86_64
elif [ -x "$bin/LiveCode-Community.app/Contents/MacOS/LiveCode-Community" ]; then
  engine=$bin/LiveCode-Community.app/Contents/MacOS/LiveCode-Community
  platform=macosx
else
  echo "$0: no development engine (LiveCode-Community) in $bin" >&2
  exit 2
fi
echo "Engine: $engine"

# Every file this writes, so that a file left from an earlier run cannot
# pass for one this run did not write, and the API data that the IDE
# writes when it runs from the checkout (api_livecode_ide too)
rm -rf "$data"/api_* "$data/guide" "$work/ext" "$work/builder" "$work/output"
rm -f "$data/api/api.sqlite"
for section in xtalk builder datagrid; do
  rm -rf "$data/api/exports/$section/resaved"
  rm -f "$data/api/exports/$section/index.txt" "$data/api/exports/$section/substitutions.txt"
done

# 1. The docs builder finds a platform's build as <engine dir>/<name>-bin,
# and reads the module interfaces of "mac-bin"
mkdir -p "$work/engines" "$work/builder" "$work/output"
for name in mac-bin linux-x86_64-bin; do
  rm -f "$work/engines/$name"
  ln -s "$bin" "$work/engines/$name"
done
echo "LiveCode's docs builder"
"$engine" -ui "$repo/builder/builder_tool.livecodescript" \
  --platform "$platform" --stage docs --edition community \
  --engine-dir "$work/engines" --work-dir "$work/builder" --output-dir "$work/output"

# 2. The extensions' docs
echo "The extensions' docs"
python3 "$repo/tools/oxt/text_dictionary.py" --list-extensions "$work/ext"
OXT_EXTENSION_DOCS=$work/ext "$engine" -ui "$repo/tools/ci/extension_docs.livecodescript"

# 3. The text dictionary
echo "The text dictionary"
python3 "$repo/tools/oxt/text_dictionary.py" --extensions "$work/ext"

status=0
for f in api/api.sqlite api_livecode_script/script.js api_livecode_script/dg.js \
  api_livecode_builder/builder.js guide/distributed_guide.js \
  api/exports/{xtalk,builder,datagrid}/{index,substitutions}.txt; do
  if [ ! -s "$data/$f" ]; then
    echo "$0: no $f was written" >&2
    status=1
  fi
done
echo "Written in $data:"
for d in api api_livecode_script api_livecode_builder guide; do
  echo "  $d: $(find "$data/$d" -type f | wc -l | tr -d ' ') files, $(du -sk "$data/$d" | cut -f1) KB"
done
exit $status
