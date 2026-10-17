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

# Builds the web IDE: the IDE of an installed OXT-Beyond, run in a web page
# by the development engine of this checkout built for the web.
#
#   tools/ci/build-web-ide.sh <installed OXT-Beyond> <site folder>
#
# <installed OXT-Beyond> is an installed or extracted Linux OXT-Beyond
# (its Toolset, Plugins, Extensions and documentation go into the site,
# with this checkout's script-only IDE stacks over its own).
# <site folder> is new or empty: the site is static files that any web
# server can serve (tools/web-ide/build_site.py says what they are).
#
# The engine is engine.gyp's development-web, the IDE's engine (its
# development mode, with the IDE's own messages and commands), linked with
# its JavaScript libraries by javascriptify-development: the same libraries
# and the same WebAssembly as the web standalone engine that
# tools/ci/build-web.sh builds, which builds the libraries that both link
# (this script runs it with --libraries first). The web standalone engine
# and the desktop engines are built as before: this builds only targets of
# its own.
#
# It needs what tools/ci/build-web.sh needs (Linux, the Emscripten SDK of
# config/emscripten-version, Python 2.7 as "python" and python3 3.10 or
# later), and the same environment: WEB_JOBS, EMSDK.

set -euo pipefail

if [ $# -ne 2 ] ; then
	echo "usage: $0 <installed OXT-Beyond> <site folder>" >&2
	exit 2
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
INSTALL=$1
OUT=$2
JOBS=${WEB_JOBS:-$(nproc)}

function fail {
	echo "error: $*" >&2
	exit 1
}

[ -f "${INSTALL}/Toolset/home.livecodescript" ] ||
	fail "${INSTALL} has no Toolset/home.livecodescript: is it an installed OXT-Beyond?"
if [ -e "${OUT}" ] && [ -n "$(ls -A "${OUT}" 2>/dev/null)" ] ; then
	fail "${OUT} exists and is not empty"
fi

# 1. The libraries, and the checks of the tools (build-web.sh)
"${REPO}/tools/ci/build-web.sh" --libraries

if ! command -v emcc >/dev/null 2>&1 && [ -n "${EMSDK:-}" ] ; then
	# shellcheck disable=SC1091 # the SDK's own script
	source "${EMSDK}/emsdk_env.sh" >/dev/null
fi
export PREBUILT_SKIP_FETCH=1

# 2. The web IDE's engine
cd "${REPO}"
make config-emscripten
BUILDTYPE=Release emmake make -C build-emscripten/livecode javascriptify-development -j"${JOBS}"

# 3. The site
python3 "${REPO}/tools/web-ide/build_site.py" --install "${INSTALL}" \
	--engine "${REPO}/build-emscripten/livecode/out/Release" --out "${OUT}" --repo "${REPO}"
