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

# The OXT-Beyond web host (tier 2, README.md): the web IDE and the Stack
# Player of one release, in one container. Built from this folder:
#
#   docker build --build-arg OXT_VERSION=0.2.7 -t oxt-beyond-web tools/web-host
#   docker run -d -p 8000:8000 -p 8001:8001 -v oxt-data:/data \
#       -e OXT_PASSWORD=... oxt-beyond-web
#
# The release's web IDE and Stack Player zips are downloaded from its GitHub
# Release while the image is built, and prepared (unpacked, and compressed
# with Brotli and gzip) then, so a container starts in about a second. The
# stacks users save live in the /data volume. compose.yaml puts Caddy in
# front for HTTPS.
FROM python:3.12-slim

ARG OXT_VERSION
ARG OXT_RELEASES=https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases/download

# Brotli copies: 32 MB on a first visit instead of 38 MB with gzip
RUN pip install --no-cache-dir "brotli==1.1.0"

WORKDIR /app
COPY oxt_web_host.py sync.js /app/

# The release's two web zips, prepared into /srv/sites
RUN test -n "$OXT_VERSION" || { echo "Build with --build-arg OXT_VERSION=<version>, for example 0.2.7" >&2; exit 1; }
ADD ${OXT_RELEASES}/v${OXT_VERSION}/OXT-Beyond-${OXT_VERSION}-web-ide.zip /tmp/release/
ADD ${OXT_RELEASES}/v${OXT_VERSION}/OXT-Beyond-${OXT_VERSION}-web-player.zip /tmp/release/
RUN python3 /app/oxt_web_host.py --ide /tmp/release/OXT-Beyond-${OXT_VERSION}-web-ide.zip \
        --player /tmp/release/OXT-Beyond-${OXT_VERSION}-web-player.zip \
        --sites /srv/sites --prepare-only \
    && test -f /srv/sites/ide/ide.zip.br \
    && rm -rf /tmp/release

# Not root: it needs only its own files and /data
RUN useradd --system --uid 10001 --home-dir /data oxt && mkdir -p /data && chown oxt /data
USER oxt
VOLUME /data
EXPOSE 8000 8001
ENV OXT_VERSION=${OXT_VERSION}
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/_host/health', timeout=4)"
CMD ["python3", "/app/oxt_web_host.py", "--sites", "/srv/sites", "--data", "/data", \
     "--host", "0.0.0.0", "--port", "8000", "--player-port", "8001"]
