#!/bin/bash
# Installs Ubuntu's packages in a job on a hosted runner, and goes on when
# a package server is slow or out for a while:
#
#   bash "$GITHUB_WORKSPACE/tools/ci/apt-install.sh" PACKAGE...
#       the packages, installed (without the ones they only recommend:
#       apt-get install --no-install-recommends)
#   bash "$GITHUB_WORKSPACE/tools/ci/apt-install.sh" --with-recommends PACKAGE...
#       the packages and the ones they recommend (as apt-get install
#       does by itself), for a step that needs one of those: the
#       Raspberry Pi OS check's cross compiler links with
#       libc6-dev-arm64-cross, which gcc-13-aarch64-linux-gnu only
#       recommends (#597's review)
#   bash "$GITHUB_WORKSPACE/tools/ci/apt-install.sh" --update
#       apt's lists only (as apt-get update), for a step that asks
#       apt-cache which packages there are before it installs them
#   bash "$GITHUB_WORKSPACE/tools/ci/apt-install.sh" --fetch PACKAGE...
#       the packages downloaded into apt's cache, not installed
#   bash "$GITHUB_WORKSPACE/tools/ci/apt-install.sh" --download PACKAGE=VERSION...
#       the packages' files downloaded into the current folder (as apt-get
#       download)
#   bash "$GITHUB_WORKSPACE/tools/ci/apt-install.sh" --playwright PYTHON BROWSER...
#       Playwright's browsers with the packages they need (as PYTHON -m
#       playwright install --with-deps BROWSER...)
#
# by its path in the checkout, with bash, as tools/ci/apt-name-servers.sh
# is called (which this calls first).
#
# Why: a package step on a runner had a single try, and a package server
# that failed for a few minutes failed the step. While 0.2.8-dp.2 was cut
# (19 Nov 2026), the package job's "Install Playwright and Chromium" step
# failed on every server of the runner's mirror list at once (the runner's
# own mirror, us-east-2.ec2.archive.ubuntu.com, gave nothing, then
# archive.ubuntu.com, and security.ubuntu.com answered 503), and its Server
# check ran past its 10 minutes while that mirror sent apache2 and valgrind
# a few kilobytes a second. On 5 November the runners' mirror had sent
# WebKit's packages as slowly (.github/actions/install-playwright). The
# container builds' "Install build tools" steps already went on (their
# retry loop, tools/ci/tests/test_apt_retry.py), and the package job's
# runtime libraries step; this is that for every other step.
#
# So the lists and the downloads (never an install, which must not be
# stopped half-way) are tried up to three times, each try with a time
# limit (APT_TRY_LIMIT seconds, 300 when it is not set) and 15 s, then 30 s
# apart, every try keeping what the one before finished. After a try that
# did not finish, the runner's own mirror (the first of
# /etc/apt/apt-mirrors.txt, the list the runners' apt sources point at) is
# left out for the rest of the job, so that the next try asks
# archive.ubuntu.com: a mirror that crawls is not asked again. Then the
# packages are installed from what was downloaded, once; if no try
# finished, the install still runs, and apt-get's own message says what is
# wrong. apt checks every package against the archive's signatures as it
# always does, from whichever server it came.
#
# The exit status is apt-get's (or Playwright's) for an install, and 1 when
# no try finished for --update, --fetch and --download.
#
# APT_ETC is for tools/ci/tests/test_apt_retry.py, as in
# apt-name-servers.sh: the folder of the apt sources and the mirror list.

etc="${APT_ETC:-/etc/apt}"
limit="${APT_TRY_LIMIT:-300}"
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mode=install
recommends=(--no-install-recommends)
case $1 in
  --update|--fetch|--download|--playwright) mode=${1#--}; shift ;;
  --with-recommends) recommends=(); shift ;;
esac
case $1 in
  --*) echo "apt-install.sh: unknown option $1" >&2; exit 2 ;;
esac
if [ "$mode" = playwright ]; then
  python=$1
  shift
fi
if [ "$mode" != update ] && [ $# -eq 0 ]; then
  echo "apt-install.sh: no packages named" >&2
  exit 2
fi

# (sudo does not pass the job's environment on; a job that runs as root,
# in a container, has no sudo)
root=()
if [ "$(id -u)" != 0 ]; then root=(sudo); fi
apt=("${root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30)

# Leaves the runner's own mirror out of its mirror list: the first server
# there, when another follows it and it is not one of Ubuntu's own
# (archive.ubuntu.com, which has every pocket, comes next on the runners;
# security.ubuntu.com, last, has only the security pockets, so it is never
# left to answer alone)
leave_out_mirror() {
  local list="$etc/apt-mirrors.txt" first rest host
  [ -f "$list" ] || return 0
  first=$(grep -Ev '^[[:space:]]*(#|$)' "$list" | head -n 1)
  rest=$(grep -Ev '^[[:space:]]*(#|$)' "$list" | tail -n +2)
  [ -n "$first" ] && [ -n "$rest" ] || return 0
  host=$(printf '%s\n' "$first" | sed -E 's|^[a-z+]*://([^/[:space:]]*).*|\1|')
  case $host in
    archive.ubuntu.com|security.ubuntu.com|ports.ubuntu.com) return 0 ;;
  esac
  echo "::warning::Leaving the runner's mirror $host out of its mirror list for the rest of the job"
  printf '%s\n' "$rest" | "${root[@]}" tee "$list" > /dev/null
}

# One try: the lists, then what the mode downloads, each within the limit
one_try() {
  timeout "$limit" "${apt[@]}" update || return 1
  case $mode in
    update) ;;
    download) timeout "$limit" apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 download "$@" ;;
    *) timeout "$limit" "${apt[@]}" install -y "${recommends[@]}" --download-only "$@" ;;
  esac
}

# Up to three tries; 0 when one finished
tries() {
  local try
  for try in 1 2 3; do
    if one_try "$@"; then
      return 0
    fi
    if [ "$try" = 3 ]; then
      echo "::warning::apt-get did not finish in three tries of $limit s"
      return 1
    fi
    echo "::warning::apt-get did not finish on try $try of 3; it runs again in $((try * 15)) s"
    leave_out_mirror
    sleep $((try * 15))
  done
}

# (public name servers too, if the runner's own give no answer for the package servers)
bash "$here/apt-name-servers.sh"

case $mode in
  update|fetch|download)
    tries "$@"
    ;;
  install)
    tries "$@"
    "${apt[@]}" install -y "${recommends[@]}" "$@"
    ;;
  playwright)
    # The packages that Playwright's install asks apt for: its dry run
    # prints the command, sh -c "apt-get update&& apt-get install -y
    # --no-install-recommends <packages>"
    list=$("$python" -m playwright install-deps --dry-run "$@" |
           sed -n 's/.*--no-install-recommends \([^"]*\)".*/\1/p')
    read -r -a pkgs <<< "$list"
    if [ ${#pkgs[@]} -gt 0 ]; then
      echo "Fetching ${#pkgs[@]} packages: ${pkgs[*]}"
      mode=fetch
      tries "${pkgs[@]}"
    else
      echo "::warning::Playwright's dry run named no packages; installing without fetching them first"
    fi
    # Playwright's install finds the packages in apt's cache; its browsers
    # come from Playwright's own server, which it retries itself. Twice, as
    # its own apt-get update can still meet a server that is out.
    "$python" -m playwright install --with-deps "$@" && exit 0
    echo "::warning::Playwright's install did not finish; it runs again in 30 s"
    sleep 30
    "$python" -m playwright install --with-deps "$@"
    ;;
esac
