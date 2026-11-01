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

# Install and start the Linux arm64 package the way a Raspberry Pi owner
# does, on a Raspberry Pi OS-like system: a Debian (bookworm or trixie)
# arm64 container with the Raspberry Pi archive (archive.raspberrypi.com)
# added and upgraded from, as Raspberry Pi OS is. No real Pi has run the
# package; this is the nearest thing CI has (see .github/workflows/
# pi-os-check.yml, which runs it natively on GitHub's ARM runners and under
# QEMU as the Pi 3, Pi 4 and Pi 5 CPUs, Cortex-A53, A72 and A76, whose
# older instruction sets the ARM runners' Neoverse CPUs hide).
#
#   tools/ci/pi_os_check.sh <package .zip or .tar.xz> <output folder> [seconds]
#   tools/ci/pi_os_check.sh --print-screenshot <png>
#
# Runs as root in the container (it installs packages and adds a user)
# and does, in order:
#   1. adds the Raspberry Pi archive for this Debian release and upgrades
#      (PI_REPO=0 leaves it out);
#   2. installs only what the install instructions name (unzip, xz-utils
#      and GTK 2: libgtk2.0-0, or libgtk2.0-0t64 on trixie), unpacks the
#      package as an ordinary user, and checks that the launcher finds
#      every library it needs: the instructions are enough;
#   3. installs the screen and window manager the check needs, with the
#      Raspberry Pi desktop's GTK theme when the archive has it, and starts
#      the IDE with tools/ci/linux_ide_start.sh as that user;
#   4. runs install.sh and the uninstall script it installs, as that user.
# The output folder gets each step's output and the IDE's screenshots.
# Exit status 0 when every step passed.

# The GTK 2 package of a Debian release: the 64-bit time_t transition
# renamed it in trixie (Debian 13) and later
gtk_package() {
  case $1 in
    buster|bullseye|bookworm) echo libgtk2.0-0 ;;
    *) echo libgtk2.0-0t64 ;;
  esac
}

# The apt source of the Raspberry Pi archive for a Debian release, signed
# by a keyring file
pi_repo_line() {
  echo "deb [signed-by=$2] http://archive.raspberrypi.com/debian/ $1 main"
}

# The field of one package's stanza in a Packages file (stdin)
packages_field() {
  awk -v pkg="$1" -v field="$2" '
    /^Package: / { p = ($2 == pkg) }
    p && index($0, field ": ") == 1 { print substr($0, length(field) + 3); exit }'
}

# Install the archive's own keyring package, raspberrypi-archive-keyring,
# as Raspberry Pi OS has it, and print the keyring file apt should use.
# The key the archive publishes (raspberrypi.gpg.key) has SHA-1 bindings,
# which trixie's apt (sqv) refuses since 2026-02-01, so it is used only
# through gpgv, to verify InRelease; InRelease's SHA256 then verifies the
# Packages index, and that the package. Nothing is installed unverified.
pi_archive_keyring() {
  local release=$1 dir=$2 base=http://archive.raspberrypi.com/debian
  local arch file sum sumgot packages
  arch=$(dpkg --print-architecture)
  mkdir -p "$dir"
  curl -fsSL --retry 5 "$base/raspberrypi.gpg.key" | gpg --dearmor > "$dir/key.gpg" || return 1
  curl -fsSL --retry 5 "$base/dists/$release/InRelease" -o "$dir/InRelease" || return 1
  gpgv --keyring "$dir/key.gpg" --output "$dir/Release" "$dir/InRelease" 2> "$dir/gpgv.txt" || { cat "$dir/gpgv.txt" >&2; return 1; }
  packages=main/binary-$arch/Packages.xz
  sum=$(awk -v f="$packages" '/^SHA256:/ { s = 1; next } /^[^ ]/ { s = 0 } s && $3 == f { print $1 }' "$dir/Release")
  [ -n "$sum" ] || { echo "no $packages in InRelease" >&2; return 1; }
  curl -fsSL --retry 5 "$base/dists/$release/$packages" -o "$dir/Packages.xz" || return 1
  echo "$sum  $dir/Packages.xz" | sha256sum -c --quiet - >&2 || return 1
  file=$(xz -dc "$dir/Packages.xz" | packages_field raspberrypi-archive-keyring Filename)
  sum=$(xz -dc "$dir/Packages.xz" | packages_field raspberrypi-archive-keyring SHA256)
  [ -n "$file" ] && [ -n "$sum" ] || { echo "no raspberrypi-archive-keyring in $packages" >&2; return 1; }
  curl -fsSL --retry 5 "$base/$file" -o "$dir/keyring.deb" || return 1
  echo "$sum  $dir/keyring.deb" | sha256sum -c --quiet - >&2 || return 1
  dpkg -i "$dir/keyring.deb" > "$dir/dpkg.txt" 2>&1 || { cat "$dir/dpkg.txt" >&2; return 1; }
  dpkg -L raspberrypi-archive-keyring | grep -E '^/usr/share/keyrings/[^/]+\.(gpg|pgp|asc)$' | head -n 1 | grep . || return 1
}

# Whether the launcher's output says a library is missing (its message
# when a "core" or "gui" library is not found; Installer/linux/oxt-beyond)
launcher_missing_libraries() {
  grep -q 'cannot start: these libraries are missing' "$1"
}

# A screenshot scaled to 800 pixels wide, as a JPEG in base64 between
# BEGIN and END lines, for a reader of the log who cannot download the
# job's artifact (ImageMagick's convert)
print_screenshot() {
  [ -f "$1" ] || { echo "no screenshot $1"; return 1; }
  echo "----- BEGIN $(basename "$1" .png) 800px JPEG base64 -----"
  convert "$1" -resize '800x>' -quality 80 jpg:- | base64 -w 1000
  echo "----- END $(basename "$1" .png) -----"
}

# The program folder's tar.xz in a folder (an unzipped package also holds
# the -binaries and -symbols tar.xz, which sort before it)
package_tarball() {
  ls "$1"/OXT-Beyond-*-linux-arm64.tar.xz 2>/dev/null | head -n 1
}

main() {
  package=$1
  out=$2
  seconds=${3:-90}
  if [ -z "$package" ] || [ -z "$out" ] || [ ! -f "$package" ]; then
    echo "usage: $0 <package .zip or .tar.xz> <output folder> [seconds]" >&2
    exit 2
  fi
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  mkdir -p "$out"
  out=$(cd "$out" && pwd)
  package=$(cd "$(dirname "$package")" && pwd)/$(basename "$package")
  export DEBIAN_FRONTEND=noninteractive
  . /etc/os-release
  release=$VERSION_CODENAME
  failed=0
  apt=(apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 -y -q)
  echo "Machine: $(uname -m), $PRETTY_NAME, CPU model: ${QEMU_CPU:-native}"

  # 1. The Raspberry Pi archive, as on Raspberry Pi OS
  "${apt[@]}" update > "$out/apt.txt" 2>&1
  if [ "${PI_REPO:-1}" = 1 ]; then
    "${apt[@]}" install ca-certificates curl gpgv gnupg xz-utils >> "$out/apt.txt" 2>&1
    keyring=$(pi_archive_keyring "$release" "$out/keyring") || { echo "::error::cannot install the Raspberry Pi archive keyring"; exit 1; }
    pi_repo_line "$release" "$keyring" > /etc/apt/sources.list.d/raspi.list
    if ! "${apt[@]}" update >> "$out/apt.txt" 2>&1; then
      echo "::error::apt cannot read the Raspberry Pi archive for $release"
      tail -n 20 "$out/apt.txt"
      exit 1
    fi
    "${apt[@]}" dist-upgrade >> "$out/apt.txt" 2>&1
    echo "Raspberry Pi archive: $(pi_repo_line "$release" "$keyring")"
  fi

  # 2. The install instructions, and nothing else, as user "pi"
  gtk=$(gtk_package "$release")
  echo "Installing what the instructions name: unzip xz-utils $gtk"
  "${apt[@]}" install unzip xz-utils "$gtk" >> "$out/apt.txt" 2>&1 || { echo "::error::apt cannot install unzip xz-utils $gtk"; exit 1; }
  id pi > /dev/null 2>&1 || useradd -m -s /bin/bash pi
  chown pi "$out"
  work=/home/pi/oxt-test
  runuser -u pi -- mkdir -p "$work"
  cp "$package" "$work/"
  chown pi "$work/$(basename "$package")"
  as_pi() { runuser -u pi -- env HOME=/home/pi "$@"; }
  (
    cd "$work" || exit 1
    # the package's program folder, not its -binaries or -symbols tar.xz
    case $package in
      *.zip)
        as_pi unzip -q "$(basename "$package")" || exit 1
        tarball=$(package_tarball .) ;;
      *) tarball=$(basename "$package") ;;
    esac
    [ -n "$tarball" ] || { echo "::error::no OXT-Beyond-*-linux-arm64.tar.xz in the package"; exit 1; }
    as_pi tar -xJf "$tarball" || exit 1
  ) || exit 1
  root=$(ls -d "$work"/OXT-Beyond-*/ 2>/dev/null | head -n 1)
  root=${root%/}
  [ -x "$root/oxt-beyond" ] || { echo "::error::no oxt-beyond launcher in $root"; exit 1; }
  echo "Package: $(basename "$root")"

  # The launcher checks its libraries before the engine starts; with no
  # screen the engine then ends, which is fine here
  (cd "$root" && timeout 30 runuser -u pi -- env -u DISPLAY HOME=/home/pi ./oxt-beyond) > "$out/launcher-check.txt" 2>&1
  if launcher_missing_libraries "$out/launcher-check.txt"; then
    echo "::error title=Install instructions::with only $gtk installed, the launcher stops: a library is missing"
    cat "$out/launcher-check.txt"
    failed=1
  else
    echo "Library check: the launcher found every library it needs with only $gtk installed"
  fi

  # 3. A screen, a window manager and the Raspberry Pi desktop's GTK theme
  "${apt[@]}" install xvfb xauth openbox x11-utils imagemagick >> "$out/apt.txt" 2>&1 || { echo "::error::cannot install the screen tools"; exit 1; }
  theme=
  for t in $(apt-cache search --names-only '^(pixflat-theme|rpd-theme|rpd-gtk-theme)$' 2>/dev/null | cut -d' ' -f1); do
    "${apt[@]}" install "$t" >> "$out/apt.txt" 2>&1 && break
  done
  for rc in /usr/share/themes/PiXflat/gtk-2.0/gtkrc /usr/share/themes/PiXtrix/gtk-2.0/gtkrc /usr/share/themes/PiXnoir/gtk-2.0/gtkrc; do
    if [ -f "$rc" ]; then theme=$rc; break; fi
  done
  if [ -n "$theme" ]; then
    echo "GTK theme: $theme (the Raspberry Pi desktop's)"
    export GTK2_RC_FILES=$theme
  else
    echo "GTK theme: none of the Raspberry Pi desktop's found; GTK 2's default"
  fi
  dpkg-query -W -f='${Package} ${Version}\n' libgtk2.0-0 libgtk2.0-0t64 libc6 libcairo2 libpango-1.0-0 2>/dev/null > "$out/versions.txt"
  if ! runuser -u pi -- env GTK2_RC_FILES="${GTK2_RC_FILES:-}" GITHUB_STEP_SUMMARY= \
       bash "$here/linux_ide_start.sh" "$root" "$out/ide-start" "$seconds"; then
    failed=1
  fi

  # 4. install.sh and its uninstall script, as the instructions describe
  (
    cd "$root" || exit 1
    as_pi ./install.sh > "$out/install.txt" 2>&1 || { echo "::error::install.sh failed"; cat "$out/install.txt"; exit 1; }
    for f in /home/pi/.local/bin/oxt-beyond /home/pi/.local/share/oxt-beyond/uninstall.sh; do
      [ -e "$f" ] || { echo "::error::install.sh did not install $f"; exit 1; }
    done
    ls /home/pi/.local/share/applications/*oxt* > /dev/null 2>&1 || { echo "::error::install.sh added no menu entry"; exit 1; }
    as_pi /home/pi/.local/share/oxt-beyond/uninstall.sh >> "$out/install.txt" 2>&1 || { echo "::error::uninstall.sh failed"; exit 1; }
    [ ! -e /home/pi/.local/bin/oxt-beyond ] || { echo "::error::uninstall.sh left ~/.local/bin/oxt-beyond"; exit 1; }
    echo "install.sh: installed the command and menu entry; uninstall.sh removed them"
  ) || failed=1

  return $failed
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ "$1" = --print-screenshot ]; then
    print_screenshot "$2"
    exit $?
  fi
  main "$@"
  exit $?
fi
