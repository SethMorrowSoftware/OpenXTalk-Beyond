#!/bin/sh
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

# Removes what install.sh installed for the current user, and only that:
# the entries of ${XDG_DATA_HOME:-~/.local/share}/oxt-beyond/.install-manifest
# (see install.sh) are
#
#   file <path>     removed
#   link <path>     removed if it is still a symbolic link
#   program <path>  the program folder, removed with everything in it
#   dir <path>      a folder install.sh created, removed when empty
#   mimedb <path>   the mime database was made by install.sh: once no
#                   other program's file is left in <path>/packages, the
#                   files update-mime-database generated go too; otherwise
#                   update-mime-database runs again, without our types
#   desktopdb <path>
#                   the same for applications/mimeinfo.cache
#
# The IDE's preferences, caches and logs (~/.oxt-beyond) and your own
# stacks and extensions are not touched. It works from the installed
# folder (which it removes) and from any extracted package: it always acts
# on the install of the current user.
#
# POSIX sh only (dash, bash, busybox sh).

set -f
nl='
'
manifest_header='# OXT-Beyond install manifest 1'

die() {
    printf 'uninstall.sh: %s\n' "$1" >&2
    exit 1
}

for arg in "$@"; do
    case $arg in
        -h|--help)
            cat <<'EOF'
Usage: uninstall.sh

Removes OXT-Beyond as install.sh installed it for you: the program folder
${XDG_DATA_HOME:-~/.local/share}/oxt-beyond, the menu entry, the icons, the
file types and ~/.local/bin/oxt-beyond. Your preferences (~/.oxt-beyond),
stacks and extensions stay.
EOF
            exit 0 ;;
        *) die "unknown argument $arg (see --help)" ;;
    esac
done

[ "$(id -u)" != 0 ] || die "do not run this as root (or with sudo): OXT-Beyond is installed for one user; run uninstall.sh as that user."
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set to a folder"

data=${XDG_DATA_HOME:-}
case $data in
    /*) ;;
    *) data=$HOME/.local/share ;;
esac
data=${data%/}
app=$data/oxt-beyond
manifest=$app/.install-manifest

[ -f "$manifest" ] || die "there is no OXT-Beyond installed by install.sh in $app (no $manifest)"
entries=$(cat "$manifest") || die "cannot read $manifest"
case $entries in
    "$manifest_header$nl"*|"$manifest_header") ;;
    *) die "$manifest is not an OXT-Beyond install manifest; nothing was removed" ;;
esac
has() {
    case "$nl$entries$nl" in
        *"$nl$1$nl"*) return 0 ;;
    esac
    return 1
}
has "program $app" || die "$manifest does not name $app as the program folder; nothing was removed"

# Leave the program folder, which is about to go (this script may be in it)
cd / || die "cannot leave $app"

printf 'Removing OXT-Beyond from %s\n' "$app"

# 1. Files and links
while IFS= read -r line; do
    path=${line#* }
    case $line in
        "file "*) if [ -f "$path" ] || [ -L "$path" ]; then rm -f "$path" || printf 'uninstall.sh: warning: cannot remove %s\n' "$path" >&2; fi ;;
        # (only while it still leads to our launcher)
        "link "*) if [ -L "$path" ] && [ "$(readlink "$path")" = "$app/oxt-beyond" ]; then
                      rm -f "$path" || printf 'uninstall.sh: warning: cannot remove %s\n' "$path" >&2
                  fi ;;
    esac
done <<EOF
$entries
EOF

# Whether a folder holds anything but the names given (globbing is off
# for the rest of the script, so it is turned on here only)
only_holds() {    # folder name...
    folder=$1
    shift
    set +f
    for entry in "$folder"/* "$folder"/.[!.]* "$folder"/..?*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        name=${entry##*/}
        allowed=0
        for keep in "$@"; do
            [ "$name" = "$keep" ] && allowed=1
        done
        if [ "$allowed" = 0 ]; then
            set -f
            return 1
        fi
    done
    set -f
    return 0
}

# 2. The desktop's databases, now without our entries
mime=$data/mime
if [ -d "$mime" ]; then
    if has "mimedb $mime" && { [ ! -d "$mime/packages" ] || only_holds "$mime/packages"; }; then
        # Everything but packages/ was generated from our file alone
        set +f
        for entry in "$mime"/* "$mime"/.[!.]* "$mime"/..?*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            [ "$entry" = "$mime/packages" ] || rm -rf "$entry"
        done
        set -f
    elif command -v update-mime-database >/dev/null 2>&1; then
        update-mime-database "$mime" || printf 'uninstall.sh: warning: update-mime-database %s failed\n' "$mime" >&2
    fi
fi
apps=$data/applications
if [ -d "$apps" ]; then
    if has "desktopdb $apps" && only_holds "$apps" mimeinfo.cache; then
        rm -f "$apps/mimeinfo.cache"
    elif command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$apps" || printf 'uninstall.sh: warning: update-desktop-database %s failed\n' "$apps" >&2
    fi
fi
if [ -f "$data/icons/hicolor/icon-theme.cache" ] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f "$data/icons/hicolor" || printf 'uninstall.sh: warning: gtk-update-icon-cache failed\n' >&2
fi
[ -d "$data/icons/hicolor" ] && touch "$data/icons/hicolor"

# 3. The program folder, then the folders install.sh created, deepest
# first, as far as they are empty now
rm -rf "$app" || die "cannot remove $app"
printf '%s\n' "$entries" | sed -n 's/^dir //p' | awk '{ print length($0) "\t" $0 }' | sort -rn | cut -f2- |
while IFS= read -r folder; do
    [ -d "$folder" ] && rmdir "$folder" 2>/dev/null
done

printf 'Removed. Your preferences in ~/.oxt-beyond, and your stacks and extensions, are still there.\n'
exit 0
