#!/bin/bash
# Lets a job's package steps go on when the machine's name servers give no
# answer for the package servers.
#
#   bash tools/ci/apt-name-servers.sh       before a step's first apt-get
#
# On 11 November 2026, from about 14:00 UTC, no apt-get of any Linux job
# could find its server ("Could not resolve 'archive.ubuntu.com'" in the
# build containers, "Temporary failure resolving
# 'azure.archive.ubuntu.com'" on the runners; ports.ubuntu.com on the
# arm64 ones). Measured on the runners that day (#476): their name servers
# (Azure's, behind systemd-resolved on a runner and behind Docker's
# resolver in a job container) timed out on every name of Canonical's
# zones, as Canonical's own name servers did when asked from a runner.
# Every other name resolved, the package servers answered when asked by
# address, and 1.1.1.1 (Cloudflare) and 9.9.9.9 (Quad9) resolved the names
# all along; 8.8.8.8 did not.
#
# So, when a server named in the machine's apt sources does not resolve,
# those two are added to /etc/resolv.conf AFTER the name servers that are
# there. The C library asks the next name server only when the one before
# gives no answer, so a name that resolved before still gets the same
# answer from the same server (a job's service containers, the runner's
# internal names), and a lookup that failed takes a few seconds longer and
# then works. While the servers resolve, nothing is changed. The lines stay
# for the rest of the job, whose later steps install packages too. apt
# checks the archive's signatures as it always does: a name server cannot
# make it accept packages the archive did not sign.
#
# A failure here never fails the step: the apt-get that follows says what
# is wrong.
#
# The container builds install their tools before there is a checkout
# (web.yml, web-ide.yml, build-linux.yml, android-engine.yml: "Install
# build tools"), so their retry loop carries these lines itself.
# tools/ci/tests/test_apt_retry.py runs both, and holds every step that
# installs packages to one of them.
#
# APT_ETC and RESOLV_CONF are for that test: the folder of the apt sources
# and the file that names the name servers.

etc="${APT_ETC:-/etc/apt}"
resolv="${RESOLV_CONF:-/etc/resolv.conf}"

# The servers of the sources: one-line files, deb822 files, and the mirror
# list that the hosted runners' sources point at
servers=$(cat "$etc"/sources.list "$etc"/sources.list.d/*.list "$etc"/sources.list.d/*.sources \
              "$etc"/apt-mirrors.txt 2> /dev/null |
          grep -v '^[[:space:]]*#' | grep -Eo 'https?://[^/[:space:]]+' |
          sed -e 's|^[a-z]*://||' -e 's|^.*@||' -e 's|:[0-9]*$||' | sort -u)

# The first one that does not resolve is enough: each lookup that fails
# takes the resolver's whole timeout (10 s on a runner)
missing=
for server in $servers; do
  if ! getent hosts "$server" > /dev/null 2>&1; then
    missing=$server
    break
  fi
done
if [ -z "$missing" ]; then
  exit 0
fi

if grep -Eq '^nameserver[[:space:]]+1\.1\.1\.1[[:space:]]*$' "$resolv" 2> /dev/null; then
  echo "::warning::$missing does not resolve, with 1.1.1.1 and 9.9.9.9 in $resolv already"
  exit 0
fi

echo "::warning::$missing does not resolve with this machine's name servers; 1.1.1.1 and 9.9.9.9 are added after them"
# (the first newline: a last line without one stays a line of its own)
if [ -w "$resolv" ]; then
  printf '\nnameserver 1.1.1.1\nnameserver 9.9.9.9\n' >> "$resolv"
else
  printf '\nnameserver 1.1.1.1\nnameserver 9.9.9.9\n' | sudo tee -a "$resolv" > /dev/null
fi
if getent hosts "$missing" > /dev/null 2>&1; then
  echo "$missing resolves now"
else
  echo "::warning::$missing still does not resolve"
fi
exit 0
