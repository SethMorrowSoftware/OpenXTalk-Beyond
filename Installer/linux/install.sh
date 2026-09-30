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

# Installs OXT-Beyond for the current user, from the folder this script is
# in (the extracted OXT-Beyond-<version>-linux-x86_64.tar.xz):
#
#   ${XDG_DATA_HOME:-~/.local/share}/oxt-beyond/   a copy of the folder
#   .../applications/oxt-beyond.desktop            the menu entry; it opens
#                                                  .oxtstack and .oxtscript
#   .../icons/hicolor/<n>x<n>/apps/oxt-beyond.png  the icon, 16 to 512 px
#   .../mime/packages/oxt-beyond.xml               the two file types
#   ~/.local/bin/oxt-beyond                        a link to the launcher
#
# and runs update-desktop-database and update-mime-database where they
# exist, and gtk-update-icon-cache where the icon folder already has a
# cache (creating one would hide the icons that other programs install
# later without updating it). Nothing needs root, and it refuses to run as
# root: the files belong in one user's home folder.
#
# Every file, link and folder it creates is listed in
# oxt-beyond/.install-manifest, which uninstall.sh reads to remove exactly
# those again (and the program folder); a file it did not create is never
# replaced or removed. Running it again replaces the installed copy (a newer
# version, say) and removes what the previous install created that this one
# does not. Run from the installed copy itself, it only registers the menu
# entry, icons, file types and link again.
#
# POSIX sh only (dash, bash, busybox sh).

set -f
nl='
'
tab=$(printf '\t')
manifest_name=.install-manifest
manifest_header='# OXT-Beyond install manifest 1'
icon_sizes='16 24 32 48 64 128 256 512'

die() {
    printf 'install.sh: %s\n' "$1" >&2
    exit 1
}

for arg in "$@"; do
    case $arg in
        -h|--help)
            cat <<'EOF'
Usage: ./install.sh

Installs OXT-Beyond for you (not for all users) from the folder this script
is in: the program into ${XDG_DATA_HOME:-~/.local/share}/oxt-beyond, a menu
entry, icons and the .oxtstack and .oxtscript file types, and the command
~/.local/bin/oxt-beyond. Run it again to update; run uninstall.sh (in the
installed folder) to remove everything it installed.
EOF
            exit 0 ;;
        *) die "unknown argument $arg (see --help)" ;;
    esac
done

[ "$(id -u)" != 0 ] || die "do not run this as root (or with sudo): it installs OXT-Beyond for one user, into that user's home folder. Run it as that user."
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set to a folder"

# The folder of this script (the package), with symbolic links followed
self=$0
case $self in
    */*) ;;
    *) self=./$self ;;
esac
hops=0
while [ -L "$self" ]; do
    hops=$((hops + 1))
    if [ "$hops" -gt 40 ] || ! link=$(readlink "$self"); then
        die "cannot follow the symbolic link $self"
    fi
    case $link in
        /*) self=$link ;;
        *) self=${self%/*}/$link ;;
    esac
done
dir=${self%/*}
[ -n "$dir" ] || dir=/
src=$(cd -P -- "$dir" && pwd -P) || die "cannot enter $dir"
for f in OXT-Beyond oxt-beyond uninstall.sh linux/oxt-beyond.desktop linux/oxt-beyond.xml linux/libraries.txt; do
    [ -e "$src/$f" ] || die "$src/$f is missing: run install.sh from the extracted OXT-Beyond folder, with all its files"
done
for n in $icon_sizes; do
    [ -f "$src/linux/icons/oxt-beyond-$n.png" ] || die "$src/linux/icons/oxt-beyond-$n.png is missing"
done

# Where things go. XDG_DATA_HOME counts only when it is an absolute path
# (the XDG Base Directory specification says to ignore a relative one).
data=${XDG_DATA_HOME:-}
case $data in
    /*) ;;
    *) data=$HOME/.local/share ;;
esac
data=${data%/}
bindir=$HOME/.local/bin
app=$data/oxt-beyond
manifest=$app/$manifest_name
case $app$bindir in
    *"$nl"*|*"$tab"*) die "the install folder $app has a line break or tab in its name, which a desktop entry cannot hold" ;;
esac

# The previous install's manifest, if any: install.sh replaces only what
# it installed itself
old_manifest=
if [ -f "$manifest" ]; then
    old_manifest=$(cat "$manifest") || die "cannot read $manifest"
    case $old_manifest in
        "$manifest_header$nl"*|"$manifest_header") ;;
        *) die "$manifest is not an OXT-Beyond install manifest; remove $app yourself first" ;;
    esac
fi
in_old() {
    case "$nl$old_manifest$nl" in
        *"$nl$1$nl"*) return 0 ;;
    esac
    return 1
}

# The manifest of this install, built as things are created
new_manifest=$manifest_header
record() {
    case "$nl$new_manifest$nl" in
        *"$nl$1$nl"*) ;;
        *) new_manifest=$new_manifest$nl$1 ;;
    esac
}

# mkdir -p that records every folder it creates (parents first)
make_dir() {
    [ -d "$1" ] && return 0
    [ -e "$1" ] || [ -L "$1" ] && die "$1 exists and is not a folder"
    parent=${1%/*}
    [ -n "$parent" ] && make_dir "$parent"
    mkdir "$1" || die "cannot create the folder $1"
    record "dir $1"
}

# A folder that an earlier install created stays recorded, so that
# uninstall.sh still removes it (when it is empty)
keep_old_dirs() {
    while IFS= read -r line; do
        case $line in
            "dir "*) [ -d "${line#dir }" ] && record "$line" ;;
        esac
    done <<EOF
$old_manifest
EOF
}

# A file of ours: a new one, or one an earlier install created
own_or_new() {
    [ -e "$1" ] || [ -L "$1" ] || return 0
    in_old "file $1" || in_old "link $1"
}

copy_file() {    # source target (recorded as a file of ours)
    if ! own_or_new "$2"; then
        printf 'install.sh: warning: %s exists and was not installed by install.sh; left as it is\n' "$2" >&2
        return 0
    fi
    make_dir "${2%/*}"
    rm -f "$2"
    cp "$1" "$2" && chmod 0644 "$2" || die "cannot write $2"
    record "file $2"
}

# 1. The program folder
if [ "$src" = "$app" ]; then
    printf 'Registering OXT-Beyond in %s (already installed there)\n' "$app"
else
    if [ -e "$app" ] || [ -L "$app" ]; then
        [ -n "$old_manifest" ] || die "$app exists but was not installed by install.sh (it has no $manifest_name); move or remove it first"
        printf 'Replacing the OXT-Beyond installed in %s\n' "$app"
    else
        printf 'Installing OXT-Beyond into %s\n' "$app"
    fi
    make_dir "$data"
    new=$app.new-$$
    failed=$app.copy-failed-$$
    rm -rf "$new" "$failed"
    mkdir "$new" || die "cannot create $new"
    # tar keeps the package's modes, symbolic links and hard links (the
    # runtime's CEF files are the IDE's; cp -R would store them twice)
    { (cd "$src" && tar -cf - .) || : > "$failed"; } | (cd "$new" && tar -xpf -)
    status=$?
    if [ "$status" != 0 ] || [ -e "$failed" ]; then
        rm -rf "$new" "$failed"
        die "copying $src to $new failed (is the disk full?); nothing was changed"
    fi
    rm -f "$new/$manifest_name"
    if [ -e "$app" ] || [ -L "$app" ]; then
        rm -rf "$app" || die "cannot remove the previous $app (the new copy is in $new)"
    fi
    mv "$new" "$app" || die "cannot move $new to $app"
fi
record "program $app"
keep_old_dirs

# The desktop's databases (see 6.) before anything is added to them
mime_db_ours=0
if in_old "mimedb $data/mime" || [ ! -e "$data/mime/mime.cache" ]; then
    mime_db_ours=1
fi
desktop_db_ours=0
if in_old "desktopdb $data/applications" || [ ! -e "$data/applications/mimeinfo.cache" ]; then
    desktop_db_ours=1
fi

# 2. The menu entry: the package's desktop file with the launcher's
# absolute path, quoted as the Desktop Entry Specification asks (inside
# double quotes, backslash, double quote, backquote and dollar sign are
# escaped with a backslash, and then every backslash is escaped again as a
# string value; a literal % is %%)
exec_arg=$(printf '%s' "$app/oxt-beyond" | sed -e 's/\\/\\\\\\\\/g' -e 's/"/\\\\"/g' -e 's/`/\\\\`/g' -e 's/\$/\\\\$/g' -e 's/%/%%/g')
tryexec=$(printf '%s' "$app/oxt-beyond" | sed -e 's/\\/\\\\/g')
desktop=$data/applications/oxt-beyond.desktop
if own_or_new "$desktop"; then
    make_dir "$data/applications"
    rm -f "$desktop"
    while IFS= read -r line; do
        case $line in
            Exec=*) printf 'Exec="%s" %%f\n' "$exec_arg" ;;
            TryExec=*) printf 'TryExec=%s\n' "$tryexec" ;;
            *) printf '%s\n' "$line" ;;
        esac
    done < "$app/linux/oxt-beyond.desktop" > "$desktop" || die "cannot write $desktop"
    chmod 0644 "$desktop"
    record "file $desktop"
else
    printf 'install.sh: warning: %s exists and was not installed by install.sh; left as it is\n' "$desktop" >&2
fi

# 3. Icons and file types
for n in $icon_sizes; do
    copy_file "$app/linux/icons/oxt-beyond-$n.png" "$data/icons/hicolor/${n}x$n/apps/oxt-beyond.png"
done
copy_file "$app/linux/oxt-beyond.xml" "$data/mime/packages/oxt-beyond.xml"

# 4. The command
link=$bindir/oxt-beyond
if [ -L "$link" ] && { in_old "link $link" || [ "$(readlink "$link")" = "$app/oxt-beyond" ]; }; then
    rm -f "$link"
fi
if [ -e "$link" ] || [ -L "$link" ]; then
    printf 'install.sh: warning: %s exists and is not a link that install.sh made; left as it is\n' "$link" >&2
else
    make_dir "$bindir"
    ln -s "$app/oxt-beyond" "$link" || die "cannot create the link $link"
    record "link $link"
fi

# 5. What the previous install created and this one did not
while IFS= read -r line; do
    case $line in
        "file "*|"link "*)
            case "$nl$new_manifest$nl" in
                *"$nl$line$nl"*) ;;
                *) path=${line#* }
                   if [ -L "$path" ] || [ -f "$path" ]; then rm -f "$path"; fi ;;
            esac ;;
    esac
done <<EOF
$old_manifest
EOF

# 6. The desktop's databases. update-mime-database compiles
# mime/packages/*.xml into the rest of the mime folder (mime.cache, globs2,
# application/x-oxtstack.xml and so on), update-desktop-database the
# MimeType lines of applications/*.desktop into mimeinfo.cache. When there
# was no such database before OXT-Beyond's first install, it is recorded as
# ours ("mimedb", "desktopdb"): uninstall.sh then removes it once no other
# program's file is left in it, instead of leaving an empty database behind.
if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database "$data/mime" || printf 'install.sh: warning: update-mime-database %s failed\n' "$data/mime" >&2
    [ "$mime_db_ours" = 1 ] && record "mimedb $data/mime"
fi
if command -v update-desktop-database >/dev/null 2>&1 && [ -d "$data/applications" ]; then
    update-desktop-database "$data/applications" || printf 'install.sh: warning: update-desktop-database %s failed\n' "$data/applications" >&2
    [ "$desktop_db_ours" = 1 ] && record "desktopdb $data/applications"
fi
if [ -f "$data/icons/hicolor/icon-theme.cache" ] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f "$data/icons/hicolor" || printf 'install.sh: warning: gtk-update-icon-cache failed\n' >&2
fi
# A theme folder with a newer date makes running programs look again
[ -d "$data/icons/hicolor" ] && touch "$data/icons/hicolor"

# 7. The manifest, written last: a failed install leaves the previous one
printf '%s\n' "$new_manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest" || die "cannot write $manifest"

printf 'Installed. Start OXT-Beyond from the application menu (Development), or with\n'
case ":${PATH:-}:" in
    *":$bindir:"*) printf '  oxt-beyond\n' ;;
    *) printf '  %s\n(%s is not on your PATH.)\n' "$link" "$bindir" ;;
esac
printf 'To remove it again: %s/uninstall.sh\n' "$app"
