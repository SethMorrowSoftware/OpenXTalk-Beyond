#!/usr/bin/env python3
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

"""Write the release notes of an OXT-Beyond release for Windows, macOS and
Linux (Markdown, for gh release create --notes-file).

  python3 tools/ci/release_notes.py --version V [--commit SHA]
      (--dir DIR | --files NAME... | --files-from FILE)
      [--out FILE] [--excerpt] [--strict] [--summary]

The files are the release's (tools/ci/release_assets.py: --dir is the
folder that its "assemble" wrote; --files and --files-from, one name per
line, give the names alone, to try the notes without the files). They
must be exactly the files release_assets.py expects for --version, so the
notes never name a file that the release lacks, nor leave one out. A
version with a pre-release part (0.1.0-beta.1: anything after a "-") is
a pre-release, as release.yml marks it on GitHub.

The first lines are what every user of the IDE's update check sees:
ide/Toolset/libraries/oxtbeyondupdater.livecodescript shows at most 12
lines of the notes (runs of empty lines counted as one, Markdown heading
marks dropped) and at most 700 characters, as plain text. So the notes
open with INTRO: what the release is, which file to download for each
platform and its minimum system, the Gatekeeper step of the macOS app,
the extensions' higher minimums, and a pointer to the rest; no Markdown
links or code spans there, which the dialog would show as they are.
Then one section per platform with its files and what it needs, the
files of all platforms and how to check them against SHA256SUMS, and
where the parts come from. GitHub's generated list of changes follows
when release.yml creates the release (gh release create
--generate-notes).

--excerpt prints what the update check shows of these notes (see
updater_excerpt) instead of the notes. The script checks that the
excerpt is exactly INTRO, whole; when it is not (a very long version
string can push it over 700 characters), it warns, or with --strict
fails. --summary appends the excerpt and the notes to the GitHub
Actions job summary.

Only the Python 3 standard library is used.
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import release_assets  # noqa: E402

# oxtbeyondupdater.livecodescript kExcerptLines and kExcerptChars
EXCERPT_LINES = 12
EXCERPT_CHARS = 700

# The minimum systems, as README.md states them and the builds check them
# (build-linux.yml: glibc 2.31 by check_elf_floor.py; build-macos.yml:
# 10.13 and 11.0 by check_macho_floor.py; the xTalk Suite libraries'
# floors by check_native_deps.py and check_linux_libraries.py)
WINDOWS_MIN = 'Windows 10 or later (x64)'
# (Every Apple Silicon Mac came with macOS 11 or later)
MAC_MIN = 'macOS 11 or later, or 10.13 or later on Intel'
LINUX_MIN = 'Linux x86-64 (glibc 2.31 or later)'

# Twelve lines for the update check (blank lines count), with the version
# and the file names filled in; about 610 characters for a version such as
# 0.1.0, which leaves room for a pre-release part. Plain text: see the
# module comment.
INTRO = '''\
OXT-Beyond {version} for Windows, macOS and Linux.{pre}

Download from the release page, under Assets:
- {windows_min}: {root}-win-x86_64-setup.exe
- {mac_min}: {root}-mac-universal.dmg
- {linux_min}: {root}-linux-x86_64.tar.xz

The Mac app is not notarized, so macOS blocks it until you allow it (see below).

Some bundled xTalk extensions need macOS 15, or on Linux glibc 2.33 (SodiumXT) or 2.38 and OpenSSL 3 (DataChannelXT).

The notes below list every file, what each platform needs, and how to check downloads.
'''

BODY = '''\
## Windows (x64)

Needs 64-bit Windows 10 or later.

- `{root}-win-x86_64-setup.exe`: the installer. It installs for all users or only for you, and adds a Start menu shortcut and the .oxtstack and .oxtscript file types.
- `{root}-win-x86_64-portable.zip`: the same program folder without an installer. Extract it and run `OXT-Beyond.exe`.
- `{root}-win-x86_64-binaries.zip`: the engine, externals and tools as built (`win-x86_64-bin`), without debug symbols, plus the licence files.
- `{root}-win-x86_64-symbols.zip`: debug symbols (`*.pdb`) for the binaries.

The executables are not code-signed, so Windows SmartScreen may warn when they are run for the first time.

## macOS (Apple Silicon and Intel)

One universal app, `OXT-Beyond.app`. It needs macOS 11 Big Sur or later on Apple Silicon, or macOS 10.13 High Sierra or later on an Intel Mac. The native libraries of the bundled xTalk Suite extensions SodiumXT, TorrentXT, enetxt, DataChannelXT, Box2Dxt and CoinXT need macOS 15 Sequoia or later: on older macOS the IDE starts, but those extensions do not load.

- `{root}-mac-universal.dmg`: the disk image. Open it and drag OXT-Beyond onto the Applications folder next to it.
- `{root}-mac-universal.zip`: the same app, for scripted installs (`ditto -x -k {root}-mac-universal.zip /Applications`).
- `{root}-mac-universal-binaries.tar.xz`: the build output (`Release/`, the Apple Silicon and Intel builds joined with lipo), signed ad hoc, without debug symbols and the build's own tools, plus the licence files.
- `{root}-mac-universal-symbols.zip`: debug symbols (`.dSYM` bundles) for the binaries.

**Opening it for the first time.** The app is signed ad hoc: it is not signed with an Apple Developer ID and not notarized by Apple, so macOS does not open a downloaded copy until you allow it. You do this once. On macOS 15 Sequoia and later:

1. Double-click OXT-Beyond. macOS says that it was not opened; click **Done** (not *Move to Trash*).
2. Open **System Settings > Privacy & Security** and scroll down to *Security*. Next to "OXT-Beyond was blocked to protect your Mac", click **Open Anyway**.
3. Confirm with **Open Anyway** and your password (or Touch ID).

On macOS 13 and 14, Control-click the app in Finder, choose *Open* and then *Open* again; on macOS 12 and earlier, the button is in *System Preferences > Security & Privacy > General*. Or, in Terminal, remove the quarantine flag that the browser set on the download:

```sh
xattr -dr com.apple.quarantine /Applications/OXT-Beyond.app
```

The same command helps if macOS says the app "is damaged and can't be opened": that is how some macOS versions report an app that is not notarized.

## Linux (x86-64)

Needs 64-bit x86 Linux with glibc 2.31 or later (Ubuntu 20.04, Debian 11, Fedora 32 or later) and an X11 desktop (on Wayland it runs through XWayland), with GTK 2: on Debian and Ubuntu the package `libgtk2.0-0` (`libgtk2.0-0t64` on Ubuntu 24.04 and Debian 13), on Fedora `gtk2`. The launcher names any library that is missing, with its package. The browser widget and revBrowser also need NSS, ALSA and a few more X11 libraries; without them the launcher turns the browser off. Of the bundled xTalk Suite extensions, SodiumXT needs glibc 2.33 (Ubuntu 21.04, Debian 12, Fedora 34 or later) and DataChannelXT glibc 2.38 and OpenSSL 3 (Ubuntu 24.04, Debian 13, Fedora 39 or later); on an older system these two do not load, and the IDE and the other extensions work.

- `{root}-linux-x86_64.tar.xz`: the program folder `{root}`. Extract it onto a Linux file system (not FAT, exFAT or a Windows drive) and run `./oxt-beyond` in it, or run `./install.sh` to install it for yourself: under `~/.local/share/oxt-beyond`, with a menu entry, icons, the .oxtstack and .oxtscript file types and the command `oxt-beyond`, without administrator rights.
- `{root}-linux-x86_64-binaries.tar.xz`: the engine, externals and tools as built (`linux-x86_64-bin`), without debug symbols and the build's own tools, plus the licence files.
- `{root}-linux-x86_64-symbols.tar.xz`: debug symbols (`.dbg` files) for the binaries.

## All platforms

- `{root}-xtalk-sources.zip`: every file of the bundled xTalk Suite extensions as this release took it from their repositories, with the manifest that pins them, so that the release can be rebuilt without those repositories (see BUILDING.md, "xTalk Suite extensions").
- `SHA256SUMS`: SHA-256 checksums of all the files above.

**Checking a download.** Compare its SHA-256 with the line for it in `SHA256SUMS`:

- Windows, in Command Prompt: `certutil -hashfile {root}-win-x86_64-setup.exe SHA256`
- macOS, in Terminal: `shasum -a 256 {root}-mac-universal.dmg`
- Linux, in the folder with the download and `SHA256SUMS`: `sha256sum -c SHA256SUMS --ignore-missing`

## About this release

Made by the "Release" workflow (`.github/workflows/release.yml`){commit}, which builds and tests all three platforms and publishes the release only when every package has passed.

The programs include the xTalk Suite extensions (SodiumXT, TorrentXT, enetxt, DataChannelXT, Box2Dxt, CoinXT, OnionXT and NostrXT) in their `Extensions` folder, taken from their own repositories at the commits listed in `Extensions/XTALK-EXTENSIONS.txt`. The Windows packages include the Microsoft Visual C++ runtime DLLs that enetxt and Box2Dxt need; the macOS and Linux packages do not, so a Windows standalone built there with either of them needs the Visual C++ Redistributable on the PC that runs it.

Each package's engine, externals and tools are built from this repository, for Windows x86-64, for macOS (Apple Silicon and Intel, joined into universal files) and for Linux x86-64, and so is the standalone runtime for its own platform. The standalone runtimes for other platforms (Windows x86-32, Linux x86-32 and Android, and in the Windows and macOS packages Linux x86-64) and the time zone library code for the other platforms are not built here: they are taken unchanged from OpenXTalk Lite 1.15, and are stock LiveCode 9.6.3 builds and files as Tom Perry shipped them, among them his 9.7.1-OXT Linux engine (see THIRD-PARTY-NOTICES.md). Only the Windows package has the Windows x86-64 standalone runtime, and only the macOS package has the macOS runtimes.

OXT-Beyond continues OpenXTalk Lite, started by Terry Little and developed by Tom Perry with contributions from the OpenXTalk community. It is based on LiveCode Community and licensed under the GNU GPL version 3.
'''


class NotesError(Exception):
    pass


def is_prerelease(version):
    # What release.yml marks as a pre-release: a version with a pre-release
    # part, as semantic versioning and the update check order it
    return '-' in version


def fill(template, version, commit):
    return template.format(
        version=version,
        root=release_assets.package_root(version),
        pre=' This is a pre-release.' if is_prerelease(version) else '',
        windows_min=WINDOWS_MIN, mac_min=MAC_MIN, linux_min=LINUX_MIN,
        commit=' from commit %s' % commit if commit else '')


def check_files(version, names):
    want = release_assets.release_files(version)
    got = [n for n in names if n]
    problems = []
    for name in want:
        if name not in got:
            problems.append('%s is not among the files' % name)
    for name in got:
        if name not in want:
            problems.append('%s is not a file of the release' % name)
    if len(set(got)) != len(got):
        problems.append('a file name is given twice')
    if problems:
        raise NotesError('the files are not the release\'s (tools/ci/release_assets.py): ' + '; '.join(problems))


def notes(version, names, commit=None):
    if not release_assets.VERSION_RE.match(version):
        raise NotesError('%r is not a version such as 0.1.0 or 0.1.0-beta.1' % version)
    check_files(version, names)
    body = fill(BODY, version, commit)
    for name in release_assets.release_files(version):
        # Every file is described (the table and the text must agree)
        if '`%s`' % name not in body:
            raise NotesError('the notes do not describe %s' % name)
    return fill(INTRO, version, commit) + '\n' + body


def _trim(text):
    # oxtbTrim: spaces, tabs and line ends at both ends
    return text.strip(' \t\n')


def _counted_lines(text, limit=None):
    """The lines oxtbNotesExcerpt counts: each trimmed, without leading "#"
    marks, and a run of empty lines as one empty line (none at the start).
    Returns (lines, True when there were more than limit)."""
    out = []
    last_empty = True
    for line in text.replace('\r', '').split('\n'):
        line = _trim(_trim(line).lstrip('#'))
        if not line:
            if last_empty:
                continue
            last_empty = True
        else:
            last_empty = False
        if limit is not None and len(out) >= limit:
            return out, True
        out.append(line)
    return out, False


def updater_excerpt(text):
    """What oxtbNotesExcerpt (oxtbeyondupdater.livecodescript) shows of
    release notes: at most EXCERPT_LINES counted lines (_counted_lines) and
    EXCERPT_CHARS characters, and " ..." when anything was cut. Returns
    (excerpt, cut)."""
    lines, cut = _counted_lines(text, EXCERPT_LINES)
    excerpt = _trim('\n'.join(lines))
    if len(excerpt) > EXCERPT_CHARS:
        excerpt = excerpt[:EXCERPT_CHARS]
        cut = True
    if cut and excerpt:
        excerpt += ' ...'
    return excerpt, cut


def check_intro(version, text):
    """None when the update check shows INTRO whole and nothing else;
    otherwise what is wrong."""
    intro = _trim(fill(INTRO, version, None))
    intro_lines = len(_counted_lines(intro)[0])
    if len(intro) > EXCERPT_CHARS:
        return ('the opening lines have %d characters; the update check shows %d'
                % (len(intro), EXCERPT_CHARS))
    if intro_lines != EXCERPT_LINES:
        return ('the opening lines count as %d lines for the update check, which shows %d'
                % (intro_lines, EXCERPT_LINES))
    excerpt, _ = updater_excerpt(text)
    shown = excerpt[:-len(' ...')] if excerpt.endswith(' ...') else excerpt
    if shown != intro:
        return 'the update check would not show exactly the opening lines'
    return None


def read_names(args):
    if args.dir:
        return sorted(e for e in os.listdir(args.dir) if os.path.isfile(os.path.join(args.dir, e)))
    if args.files_from:
        with open(args.files_from, encoding='utf-8') as f:
            return [line.strip() for line in f if line.strip()]
    return list(args.files)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--version', required=True, help='product version (ide/.version)')
    ap.add_argument('--commit', help='the commit the release is made from')
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument('--dir', help='the release folder (release_assets.py assemble)')
    src.add_argument('--files', nargs='+', metavar='NAME', help='the release file names')
    src.add_argument('--files-from', metavar='FILE', help='a file with one release file name per line')
    ap.add_argument('--out', help='write the notes here (default: standard output)')
    ap.add_argument('--excerpt', action='store_true', help='print what the update check shows instead')
    ap.add_argument('--strict', action='store_true', help='fail when the update check would not show the opening lines whole')
    ap.add_argument('--summary', action='store_true', help='also write to the GitHub Actions job summary')
    args = ap.parse_args(argv)

    try:
        text = notes(args.version, read_names(args), args.commit)
    except (NotesError, OSError) as e:
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::error title=Release notes::%s' % e)
        else:
            sys.stderr.write('error: %s\n' % e)
        return 1

    problem = check_intro(args.version, text)
    if problem:
        message = 'Release notes: %s (see INTRO in tools/ci/release_notes.py)' % problem
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::%s title=Release notes::%s' % ('error' if args.strict else 'warning', message))
        else:
            sys.stderr.write('%s: %s\n' % ('error' if args.strict else 'warning', message))
        if args.strict:
            return 1

    excerpt, _ = updater_excerpt(text)
    output = excerpt + '\n' if args.excerpt else text
    if args.out:
        with open(args.out, 'w', encoding='utf-8', newline='\n') as f:
            f.write(output)
    else:
        sys.stdout.write(output)

    if args.summary and os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8', newline='\n') as f:
            f.write('### Release notes\n\nWhat the update check in the IDE shows:\n\n```text\n%s\n```\n\n'
                    'The notes (GitHub\'s generated list of changes follows them in the release):\n\n'
                    '<details><summary>Show</summary>\n\n%s\n</details>\n\n' % (excerpt, text))
    return 0


if __name__ == '__main__':
    sys.exit(main())
