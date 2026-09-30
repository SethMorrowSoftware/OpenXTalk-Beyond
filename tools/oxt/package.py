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

"""Stage the installed layout of OXT-Beyond for one platform.

  python tools/oxt/package.py [--platform P] --repo <repo>
      (--bin <build output> | --bin-tar <CI build tarball>)
      --out <stage-parent> [--build-number N] [--assets-cache DIR]
      [--no-external-assets] [--no-xtalk-extensions] [--xtalk-compiler-bin DIR]
      [--vc-redist DIR] [--allow-unpinned-vc-runtime] [--xtalk-cache DIR]
      [--eol lf|crlf|keep] [--allow-single-arch] [--summary-json FILE]
      [--compare <reference install or TSV> [--report FILE]]

P chooses the layout (PLATFORMS below; default win-x86_64):

  win-x86_64     OXT-Beyond.exe and everything else in one folder: what the
                 portable zip holds and Inno Setup installs. --bin defaults
                 to <repo>/win-x86_64-bin.
  linux-x86_64   the engine as OXT-Beyond and everything else in one folder:
                 what the portable tar.xz holds. --bin defaults to
                 <repo>/linux-x86_64-bin.
  linux-arm64    the same from an arm64 build, for staging only: the IDE has
                 no Linux arm64 standalone target and that build has no CEF,
                 so there is no browser and no Runtime folder of its own.
  mac-universal  OXT-Beyond.app, with everything the other layouts have at
                 their root in OXT-Beyond.app/Contents/Tools, from a build
                 whose Mach-O files hold arm64 and x86_64 (the lipo merge of
                 the two CI builds). --bin defaults to <repo>/_build/mac/Release.
  mac-arm64, mac-x86_64
                 OXT-Beyond.app from one architecture's build, to check the
                 layout; --allow-single-arch lets mac-universal take one too.

--bin-tar takes the build output as the tarball a CI build uploads
(OXT-Beyond-linux-<arch>-bin.tar.xz, OXT-Beyond-mac-<arch>-bin.tar.xz):
its one top-level folder is extracted into a temporary folder first,
without the debug symbols (*.dbg, *.dSYM, *.pdb) and macOS tar's "._"
AppleDouble files, keeping file modes and symbolic links.

The Linux and macOS layouts are Unix trees, so they are staged on Linux or
macOS (or WSL), never on Windows, which keeps neither modes nor symbolic
links:

  modes        executable build outputs (any x bit) and native libraries
               (of the xTalk extensions, and asset members stored with an
               x bit) get 0755, every other file 0644 and every folder 0755,
               whatever the umask or the checkout (git marks some IDE
               images executable).
  links        a symbolic link inside a build output folder is staged as
               the same (relative) link; one that leads out of its folder
               or is absolute is an error. A build output named directly
               (not in a folder) is copied through a link.
  names        two paths that differ only in letter case are a conflict on
               Windows and macOS (whose volumes are usually
               case-insensitive), not on Linux.
  text         generated files (Externals.txt, Database Drivers.txt) and
               the licence files get LF line endings; CRLF on Windows.

writes <stage-parent>/OXT-Beyond-<version>/, where <version> is the content
of ide/.version. An existing folder of that name is replaced. The folder is
what the platform's package holds (the portable zip and the installer on
Windows, the tar.xz on Linux; on macOS the folder holds OXT-Beyond.app). It
is put together from (paths relative to the tools folder, which is the
stage folder itself except on macOS):

  IDE          tools/oxt/layout.py assemble: ide/Toolset, Plugins, Resources,
               Documentation, Extensions, the ide/ root files and the 11
               ide-support scripts, plus the Sample Icons in
               Runtime/Windows/<arch>/Support (and, on macOS only,
               Resources/Mobile Examples: package.txt Mobile.MacOSX). Text
               files get LF line endings (--eol) so that the result does
               not depend on git's core.autocrlf.
  build        the files of --bin that Installer/package.txt installs on the
               platform, at its installed paths (see Platform and plan_build);
               the development engine becomes OXT-Beyond.exe, OXT-Beyond or
               OXT-Beyond.app. The platform's not_installed list gives the
               build outputs that are left out, and why.
  generated    edition.txt ("community"), Externals/Externals.txt and
               Externals/Database Drivers/Database Drivers.txt (at the root
               and under every runtime folder), .buildnumber (the build
               number), two empty dictionary folders (EMPTY_DIRS) and, on
               macOS, the app's Info.plist (the build's, with the renamed
               executable).
  licences     LICENSE, LICENSE-EXCEPTION.md and THIRD-PARTY-NOTICES.md from
               the repository root (CRLF line endings on Windows).
  assets       the archives in tools/oxt/external-assets.json (see
               fetch_assets.py), unless --no-external-assets.
  xtalk        the xTalk Suite extensions of tools/oxt/xtalk-extensions.json
               under Extensions/, byte for byte as
               tools/oxt/xtalk_extensions.py fetches and builds them (with
               the lc-compile of --xtalk-compiler-bin, default --bin: the
               compiled modules do not depend on the platform, so a macOS
               layout can be staged on Linux with a Linux build's compiler)
               in a temporary folder, plus Extensions/XTALK-EXTENSIONS.txt;
               unless --no-xtalk-extensions. Every platform gets the native
               libraries of every platform id in the manifest, so that
               standalones for the other platforms can be built.
               --vc-redist is Visual Studio's redistributable folder
               (VCToolsRedistDir): the Visual C++ runtime DLLs that enetxt
               and box2dxt import are then copied next to them, and each
               must be the one the manifest's "vc_runtime" pins
               (--allow-unpinned-vc-runtime only warns); without
               --vc-redist packaging warns, and those two libraries cannot
               load on a PC without the Visual C++ Redistributable. The
               cache is --xtalk-cache, else OXT_XTALK_CACHE, else <asset
               cache>/xtalk.

The build number is --build-number, else the environment variable
OXT_BUILD_NUMBER, else the current UTC time as YYYYMMDDHHMM. ide/.buildnumber
in the repository is a placeholder.

A warning says when the stage path has a folder name that makes the engine
run the IDE in repository mode (see repository_mode_trap): a package must
be tested from a neutral path.

--compare (win-x86_64 only) checks the staged tree against a reference
install (for example OpenXTalk Lite 1.15) or a TSV from "layout.py
classify" (also a part of one, such as only its build rows): every IDE,
build and external path of the reference must be staged (the engine under
its new name) unless an intended difference (INTENDED_MISSING) says why not,
and every staged path of the classes the reference lists must be in it
unless it is an intended addition (licence files, asset notices). With a
folder, external asset files must be byte-identical and empty folders must
match. IDE changes since the reference are listed but are not errors.

Exit status: 0 success, 1 unexplained differences (--compare), 2 errors
(missing build outputs, conflicts, asset download or checksum failures;
nothing is written when the plan has problems).

Only the Python 3 standard library is used.
"""

import argparse
import calendar
import collections
import datetime
import json
import os
import plistlib
import posixpath
import re
import shutil
import stat
import sys
import tarfile
import tempfile
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import binfmt  # noqa: E402
import layout  # noqa: E402
import fetch_assets  # noqa: E402
import xtalk_extensions  # noqa: E402

PRODUCT = 'OXT-Beyond'
EDITION = 'community'
BUILD_NUMBER_ENV = 'OXT_BUILD_NUMBER'

LICENCE_FILES = ('LICENSE', 'LICENSE-EXCEPTION.md', 'THIRD-PARTY-NOTICES.md')

# Folders that must exist although git cannot store them: the dictionary
# (Documentation/oxt_dictionary.oxtstack) writes exports into them.
EMPTY_DIRS = (
    'Documentation/html_viewer/resources/data/api/exports/builder/plugins',
    'Documentation/html_viewer/resources/data/api/exports/datagrid/plugins',
)

# components Extensions and TimeZone: the same 42 ids layout.py knows
PACKAGED_EXTENSIONS = layout.REPO_BUILT_EXTENSIONS

# ---------------------------------------------------------------------------
# Platforms: build output -> installed path. The tables transcribe
# Installer/package.txt with TargetEdition Community (for Windows and Linux
# TargetFolder = SupportFolder = ToolsFolder = the install root); a Platform
# docstring says where they follow the IDE or the engine instead.

# Build outputs that no platform installs (pattern, reason)
_NOT_IN_PACKAGE_TXT = (
    ('packaged_extensions/com.livecode.library.canvas/**',
     'not in package.txt Extensions (not shipped by LiveCode 9.6.3 or OpenXTalk Lite 1.15)'),
    ('packaged_extensions/com.livecode.library.ini/**',
     'not in package.txt Extensions (not shipped by LiveCode 9.6.3 or OpenXTalk Lite 1.15)'),
)
# Tools that the Linux and macOS builds make to build themselves (the
# gentle/reflex/perfect parser generators of lc-compile, its bootstrap
# stages, the zoneinfo compiler, the external interface compiler) and
# intermediate files
_BUILD_TOOLS = (
    ('gentle-target', 'build tool (lc-compile\'s grammar compiler)'),
    ('reflex-target', 'build tool (lc-compile\'s lexer generator)'),
    ('perfect-target', 'build tool (lc-compile\'s keyword hash generator)'),
    ('lc-bootstrap-compile*', 'build tool (first stage of lc-compile)'),
    ('lc-compile-stage*', 'build tool (intermediate stage of lc-compile)'),
    ('zic', 'build tool (compiles the zoneinfo data of the timezone library)'),
    ('lcidlc', 'build tool (external interface compiler)'),
    ('*.a', 'static library (build intermediate)'),
    ('**/*.a', 'static library (build intermediate)'),
    ('*.hmap', 'Xcode header map (build intermediate)'),
)


class Platform(object):
    """One installed layout: which build outputs go where, and how the
    staged files are written. Fields:

      name, family, arch   'linux-x86_64', 'linux', 'x86_64'
      bin_default          build output folder, relative to the repository
      dev_engine           development engine in the build output (a file,
                           or on macOS an .app folder)
      engine               its installed name, relative to the stage
      engine_executable    the program to run, relative to the stage
      engine_dir           folder of engine_executable in the stage ('' or
                           a prefix ending in '/'): where the engine looks
                           for revsecurity and (Linux) the CEF helper
      tools                prefix of everything else ('' or ending in
                           '/'): the folder that holds Toolset
      component            package.txt's platform name (for notes)
      externals            (name declared in Externals.txt, build output)
      database, drivers    the same for revdb and the database drivers
      engine_support       (build output, installed path): revpdfprinter
                           and revsecurity next to the engine
      mobile               build outputs installed into Externals/ at the
                           tools root only (package.txt Mobile.<platform>)
      toolchain            build outputs installed into Toolchain/
      cef                  None, or dict(files, trees: under
                           Externals/CEF of the build; helpers_in_cef: from
                           the build root into Externals/CEF;
                           helpers_at_engine: from the build root into the
                           engine's folder; helpers_at_runtime: from the
                           build root into a runtime folder's root)
      runtimes             dicts: folder, standalone (build output,
                           installed name), files (at the folder's root),
                           support (into Support/), externals (bool: the
                           Externals component)
      not_installed        (pattern, reason) for build outputs left out
      ide_include          layout.MANAGED_EXCLUDE prefixes staged too
      elf_arch, mac_archs  what the engine binaries must be built for
      unix                 file modes and symbolic links are staged
      case_sensitive       paths differing only in case do not conflict
      eol                  line ending of generated text and licence files
    """

    def __init__(self, name, family, arch, **kw):
        self.name = name
        self.family = family
        self.arch = arch
        self.bin_default = kw['bin_default']
        self.dev_engine = kw['dev_engine']
        self.engine = kw['engine']
        self.engine_executable = kw.get('engine_executable', self.engine)
        self.engine_dir = kw.get('engine_dir', '')
        self.tools = kw.get('tools', '')
        self.component = kw['component']
        self.externals = kw['externals']
        self.database = kw['database']
        self.drivers = kw['drivers']
        self.engine_support = kw['engine_support']
        self.mobile = kw['mobile']
        self.toolchain = kw['toolchain']
        self.cef = kw.get('cef')
        self.runtimes = kw['runtimes']
        self.not_installed = tuple(kw['not_installed'])
        self.ide_include = kw.get('ide_include', ())
        self.elf_arch = kw.get('elf_arch')
        self.mac_archs = kw.get('mac_archs')
        self.unix = family != 'windows'
        # macOS volumes (APFS, HFS+) are case-insensitive unless formatted
        # otherwise, like Windows; ext4 and the other Linux file systems
        # are not
        self.case_sensitive = family == 'linux'
        self.eol = b'\r\n' if family == 'windows' else b'\n'


def _windows_x86_64():
    """package.txt TargetPlatform Windows, TargetArchitecture x86_64."""
    externals = (('Speech', 'revspeech.dll'), ('XML', 'revxml.dll'),
                 ('Browser', 'revbrowser.dll'), ('Revolution Zip', 'revzip.dll'))
    return Platform(
        'win-x86_64', 'windows', 'x86_64',
        bin_default='win-x86_64-bin',
        dev_engine='LiveCode-Community.exe',
        engine=PRODUCT + '.exe',
        component='Windows',
        # component Externals.Windows (declare external lines in this order)
        externals=externals,
        # component Databases.Windows
        database=('Database', 'revdb.dll'),
        drivers=(('MySQL', 'dbmysql.dll'), ('ODBC', 'dbodbc.dll'),
                 ('PostgreSQL', 'dbpostgresql.dll'), ('SqLite', 'dbsqlite.dll')),
        # component Engine.Windows
        engine_support=(('revpdfprinter.dll', 'revpdfprinter.dll'),
                        ('revsecurity.dll', 'revsecurity.dll')),
        # component Mobile.Windows
        mobile=('revandroid.dll',),
        # component Toolchain.Windows
        toolchain=('lc-compile.exe', 'lc-run.exe', 'lc-compile-ffi-java.exe'),
        # component Externals.CEF.Windows: the helpers from the build root,
        # the rest from win-x86_64:Externals/CEF
        cef=dict(
            helpers_in_cef=('libbrowser-cefprocess.exe', 'revbrowser-cefprocess.exe'),
            helpers_at_engine=(), helpers_at_runtime=(),
            files=('libcef.dll', 'd3dcompiler_47.dll', 'libEGL.dll', 'libGLESv2.dll',
                   'chrome_elf.dll', 'cef.pak', 'cef_100_percent.pak',
                   'cef_200_percent.pak', 'cef_extensions.pak', 'icudtl.dat',
                   'natives_blob.bin', 'snapshot_blob.bin', 'v8_context_snapshot.bin',
                   'swiftshader/libEGL.dll', 'swiftshader/libGLESv2.dll'),
            trees=('locales',)),
        # component Runtime.Windows x86-64 (Sample Icons come from the IDE part)
        runtimes=(dict(folder='Runtime/Windows/x86-64',
                       standalone=('standalone-community.exe', 'Standalone'),
                       files=('w32-manifest-template.xml',
                              'w32-manifest-template-dpiaware.xml',
                              'w32-manifest-template-trustinfo.xml'),
                       support=('revpdfprinter.dll', 'revsecurity.dll'),
                       externals=True),),
        not_installed=(
            ('*.pdb', 'debug symbols; they go into the -symbols.zip'),
            ('installer.exe', 'LiveCode\'s installer engine; OXT-Beyond is installed by Inno Setup'),
            ('server-*', 'LiveCode Server engine and its externals; package.txt installs no server'),
            ('Externals/CEF/devtools_resources.pak', 'not in package.txt Externals.CEF.Windows'),
            ('Externals/CEF/libbrowser-cefprocess.exe',
             'package.txt takes the identical copy at the root of the build'),
            ('Externals/CEF/revbrowser-cefprocess.exe',
             'package.txt takes the identical copy at the root of the build'),
        ) + _NOT_IN_PACKAGE_TXT)


def _linux(arch):
    """package.txt TargetPlatform Linux. The arm64 build has no CEF and the
    IDE no Linux arm64 standalone target (revsblibrary: Linux, Linux x64,
    Linux armv6-hf), so linux-arm64 has neither."""
    cef = arch == 'x86_64'
    externals = (('XML', 'revxml.so'), ('Revolution Zip', 'revzip.so'))
    if cef:
        externals += (('Browser', 'revbrowser.so'),)
    not_installed = (
        ('*.dbg', 'debug symbols (objcopy --only-keep-debug); they go into the -symbols archive'),
        ('installer', 'LiveCode\'s installer engine; OXT-Beyond ships a portable folder'),
        ('server-*', 'LiveCode Server engine and its externals; package.txt installs no server'),
        ('Externals/CEF/chrome-sandbox',
         'CEF\'s setuid sandbox helper: CEF runs with no_sandbox (libbrowser_cef.cpp, cefbrowser.cpp), '
         'and the helper would need root ownership and mode 4755'),
        ('Externals/CEF/devtools_resources.pak', 'not in package.txt Externals.CEF.Linux'),
    ) + _NOT_IN_PACKAGE_TXT + _BUILD_TOOLS
    runtimes = ()
    if arch == 'x86_64':
        # component Runtime.Linux with TargetArchitecture x86_64, plus
        # Externals (which includes Externals.CEF.Linux)
        runtimes = (dict(folder='Runtime/Linux/x86-64',
                         standalone=('standalone-community', 'Standalone'),
                         files=(), support=('revpdfprinter.so', 'revsecurity.so'),
                         externals=True),)
    return Platform(
        'linux-' + arch, 'linux', arch,
        bin_default='linux-%s-bin' % arch,
        dev_engine='LiveCode-Community',
        # package.txt: [[ProductName]].[[TargetArchitecture]]; the Linux
        # package has one architecture and a launcher script, so the plain
        # name is enough (and what the .desktop file and docs say)
        engine=PRODUCT,
        component='Linux',
        # component Externals.Linux (no revspeech on Linux)
        externals=externals,
        database=('Database', 'revdb.so'),
        drivers=(('MySQL', 'dbmysql.so'), ('ODBC', 'dbodbc.so'),
                 ('PostgreSQL', 'dbpostgresql.so'), ('SqLite', 'dbsqlite.so')),
        engine_support=(('revpdfprinter.so', 'revpdfprinter.so'),
                        ('revsecurity.so', 'revsecurity.so')),
        mobile=('revandroid.so',),
        toolchain=('lc-compile', 'lc-run', 'lc-compile-ffi-java'),
        # component Externals.CEF.Linux, without chrome-sandbox; the helper
        # executables where the code starts them (see the Platform notes)
        cef=dict(
            helpers_in_cef=('revbrowser-cefprocess',),
            helpers_at_engine=('libbrowser-cefprocess',),
            helpers_at_runtime=('revbrowser-cefprocess', 'libbrowser-cefprocess'),
            files=('libcef.so', 'libEGL.so', 'libGLESv2.so', 'cef.pak',
                   'cef_100_percent.pak', 'cef_200_percent.pak', 'cef_extensions.pak',
                   'icudtl.dat', 'natives_blob.bin', 'snapshot_blob.bin',
                   'v8_context_snapshot.bin', 'swiftshader/libEGL.so',
                   'swiftshader/libGLESv2.so'),
            trees=('locales',)) if cef else None,
        runtimes=runtimes,
        not_installed=not_installed,
        elf_arch=arch)


# The macOS runtime folders, as the IDE's standalone builder uses them
# (revsblibrary revEngineCheck and revSBEnginePath, revsaveasstandalone
# revStandalonePlatformDetails and revSaveAsMacStandalone): x86-64 and
# x64-ARM64 are the engines deployed for the Intel and the Apple Silicon
# target, with their Support and Externals folders; x86-32/Standalone.app
# is only looked at, but must exist: it enables the Intel target, and every
# Mac standalone gets its icons (Contents/Resources/Standalone*.icns).
MAC_RUNTIMES = collections.OrderedDict([
    ('x86-64', dict(folder='Runtime/Mac OS X/x86-64',
                    standalone=('Standalone-Community.app', 'Standalone.app'),
                    files=(), support=('revpdfprinter.bundle', 'revsecurity.dylib'), externals=True)),
    ('x64-ARM64', dict(folder='Runtime/Mac OS X/x64-ARM64',
                       standalone=('Standalone-Community.app', 'Standalone-blank.app'),
                       files=(), support=('revpdfprinter.bundle', 'revsecurity.dylib'), externals=True)),
    ('x86-32', dict(folder='Runtime/Mac OS X/x86-32',
                    standalone=('Standalone-Community.app', 'Standalone.app'),
                    files=(), support=(), externals=False)),
])


def _mac(arch):
    """package.txt TargetPlatform MacOSX, with the IDE under
    OXT-Beyond.app/Contents/Tools. arch 'universal' is the release layout;
    'arm64' and 'x86_64' stage one architecture's build, with only its own
    runtime folder (and x86-32, whose Standalone.app the IDE needs for the
    icons; with a single-architecture layout the Intel target is offered
    but fails without x86-64/Standalone.app)."""
    app = PRODUCT + '.app'
    folders = {'universal': ('x86-64', 'x64-ARM64', 'x86-32'),
               'arm64': ('x64-ARM64', 'x86-32'),
               'x86_64': ('x86-64', 'x86-32')}[arch]
    return Platform(
        'mac-' + arch, 'mac', arch,
        bin_default='_build/mac/Release',
        dev_engine='LiveCode-Community.app',
        engine=app,
        engine_executable=app + '/Contents/MacOS/' + PRODUCT,
        engine_dir=app + '/Contents/MacOS/',
        # environment/stackbehavior.livecodescript: the tools path of an
        # engine in X.app/Contents/MacOS is X.app/Contents/Tools
        tools=app + '/Contents/Tools/',
        component='MacOSX',
        externals=(('Speech', 'revspeech.bundle'), ('XML', 'revxml.bundle'),
                   ('Browser', 'revbrowser.bundle'), ('Revolution Zip', 'revzip.bundle')),
        database=('Database', 'revdb.bundle'),
        drivers=(('MySQL', 'dbmysql.bundle'), ('ODBC', 'dbodbc.bundle'),
                 ('PostgreSQL', 'dbpostgresql.bundle'), ('SqLite', 'dbsqlite.bundle')),
        # component Engine.MacOSX: from the build root, which has the
        # stripped copies (the build also copies them into the app before
        # stripping: those keep their symbols and are left out)
        engine_support=(('revsecurity.dylib', app + '/Contents/MacOS/revsecurity.dylib'),
                        ('revpdfprinter.bundle', app + '/Contents/MacOS/revpdfprinter.bundle')),
        # component Mobile.MacOSX (its Resources/Mobile Examples come from ide/)
        mobile=('reviphone.bundle', 'revandroid.bundle'),
        toolchain=('lc-compile', 'lc-run', 'lc-compile-ffi-java'),
        cef=None,
        runtimes=tuple(MAC_RUNTIMES[f] for f in folders),
        not_installed=(
            ('*.dSYM/**', 'debug symbols; they go into the -symbols zip'),
            ('Installer.app/**', 'LiveCode\'s installer; OXT-Beyond ships the app in a disk image'),
            ('installer-stub', 'LiveCode\'s installer'),
            ('server-*', 'LiveCode Server engine and its externals; package.txt installs no server'),
            ('reviphoneproxy', 'iOS simulator helper; the copy inside reviphone.bundle is installed'),
            ('tz.dylib', 'native code of the timezone library; its packaged_extensions copy is installed'),
            ('inih.dylib', 'native code of com.livecode.library.ini, which package.txt does not install'),
            ('LiveCode-Community.app/Contents/Info.plist',
             'replaced by a generated Info.plist that names the renamed executable'),
            ('LiveCode-Community.app/Contents/_CodeSignature/**',
             'the build\'s seal of the app does not match the renamed executable and the new Info.plist; '
             'the app is signed again after it is assembled'),
            ('LiveCode-Community.app/Contents/MacOS/revsecurity.dylib',
             'unstripped copy; package.txt Engine.MacOSX takes the build root\'s'),
            ('LiveCode-Community.app/Contents/MacOS/revpdfprinter.bundle/**',
             'unstripped copy; package.txt Engine.MacOSX takes the build root\'s'),
        ) + _NOT_IN_PACKAGE_TXT + _BUILD_TOOLS,
        ide_include=('ide/Resources/Mobile Examples/',),
        mac_archs={'universal': ('arm64', 'x86_64'), 'arm64': ('arm64',), 'x86_64': ('x86_64',)}[arch])


PLATFORMS = collections.OrderedDict((p.name, p) for p in (
    _windows_x86_64(), _linux('x86_64'), _linux('arm64'), _mac('universal'), _mac('arm64'), _mac('x86_64')))
DEFAULT_PLATFORM = 'win-x86_64'

# Paths of a reference install (layout.py class build) that packaging does
# not produce on purpose (pattern, reason). Used by --compare.
_COMMERCIAL_LCI = ('com.livecode.library.native.android.barcode',
                   'com.livecode.library.native.android.barcodesupport',
                   'com.livecode.library.native.speech',
                   'com.livecode.library.securekey',
                   'com.livecode.widget.native.android.barcodescanner',
                   'com.livecode.widget.native.map',
                   'com.livecode.widget.pdf',
                   'com.livecode.widget.pdf.pdfium',
                   'com.livecode.widget.signature')
INTENDED_MISSING = tuple(
    [('Toolchain/modules/lci/%s.lci' % m,
      'interface of a LiveCode commercial-edition module; OpenXTalk Lite 1.15 ships '
      'the stock LiveCode 9.6.3 Toolchain, which has it, but the module is not in this '
      'repository and nothing in the IDE uses it') for m in _COMMERCIAL_LCI] +
    [('Toolchain/modules/lci/com.livecode.commercial.license.lci',
      'from the stock LiveCode 9.6.3 Toolchain; this repository compiles '
      'engine/src/license.lcb into lc-compile instead (engine_syntax_only_lcb_files) '
      'and writes no .lci for it'),
     ('Ext/**', 'the mergExt collection is not redistributed (licence unclear)')])


class PackageError(Exception):
    pass


class Item(object):
    """One file (or symbolic link) of the staged tree."""
    __slots__ = ('target', 'origin', 'source', 'data', 'member', 'asset', 'note', 'link')

    def __init__(self, target, origin, source=None, data=None, member=None, asset=None, note='', link=None):
        self.target = target      # installed path, "/" separators
        self.origin = origin      # ide, build, generated, licence, asset, xtalk
        self.source = source      # file on disk (ide, build, licence, xtalk)
        self.data = data          # bytes (generated)
        self.member = member      # zip member name (asset)
        self.asset = asset        # asset dict (asset)
        self.note = note
        self.link = link          # target of a symbolic link (build, Unix layouts)


# ---------------------------------------------------------------------------
# Plan

def read_version(repo):
    path = os.path.join(repo, 'ide', '.version')
    try:
        with open(path, encoding='utf-8') as f:
            version = f.read().strip()
    except OSError:
        raise PackageError('%s is missing' % path)
    if not re.match(r'^[0-9A-Za-z][0-9A-Za-z.+_-]*$', version):
        raise PackageError('%s holds %r, which is not usable as a version' % (path, version))
    return version


def engine_version(repo):
    try:
        with open(os.path.join(repo, 'version'), encoding='utf-8') as f:
            for line in f:
                m = re.match(r'^\s*BUILD_SHORT_VERSION\s*=\s*(\S+)\s*$', line)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return ''


def default_build_number(explicit=None):
    value = explicit or os.environ.get(BUILD_NUMBER_ENV) or \
        datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M')
    value = str(value).strip()
    if not re.match(r'^[0-9]{1,20}$', value):
        raise PackageError('build number %r must be digits only' % value)
    return value


def _lines(pairs, eol=b'\r\n'):
    return b''.join(('%s,%s' % p).encode('ascii') + eol for p in pairs)


def walk_tree(base):
    """Relative paths ("/" separators, sorted) of the files and symbolic
    links below base; a link to a folder is one entry, not followed (a
    macOS framework's Versions/Current must stay a link). Names starting
    with "." are skipped, as upstream packaging skips them (and macOS tar
    adds "._" AppleDouble files)."""
    out = []
    for dirpath, dirnames, filenames in os.walk(base):
        rel = os.path.relpath(dirpath, base)
        rel = '' if rel == '.' else rel.replace(os.sep, '/') + '/'
        links = [d for d in dirnames if os.path.islink(os.path.join(dirpath, d))]
        dirnames[:] = sorted(d for d in dirnames if not d.startswith('.') and d not in links)
        for name in filenames + links:
            if not name.startswith('.'):
                out.append(rel + name)
    out.sort()
    return out


def link_escapes(rel, link):
    """True when the symbolic link at rel (relative to a tree) with target
    link is absolute or leads out of the tree: staged elsewhere it would
    dangle or point into the build machine."""
    if link.startswith('/') or re.match(r'^[A-Za-z]:', link):
        return True
    resolved = posixpath.normpath(posixpath.join(posixpath.dirname(rel), link))
    return resolved == '..' or resolved.startswith('../')


class Planner(object):
    """Collects the items of one layout; problems are collected, not
    raised, so that one run reports all of them."""

    def __init__(self, platform, bin_dir):
        self.p = platform
        self.bin_dir = bin_dir
        self.items = []
        self.problems = []

    def add(self, item):
        self.items.append(item)

    def file(self, target, rel, note):
        """A build output file at an installed path (through a symbolic
        link, if it is one: the link's target is not staged next to it)."""
        path = layout.native(self.bin_dir, rel)
        if not os.path.isfile(path):
            self.problems.append('build output missing: %s (for %s)' % (rel, target))
            return
        self.add(Item(target, 'build', source=os.path.realpath(path) if os.path.islink(path) else path,
                      note='package.txt ' + note + ': ' + rel))

    def tree(self, target, rel, note, skip=(), rename=None):
        """A build output folder (or a macOS bundle) at an installed path.
        skip: glob patterns relative to the folder; rename: {relative path:
        new relative path}. Symbolic links inside it stay links on Unix
        layouts (and are copied through on Windows)."""
        base = layout.native(self.bin_dir, rel)
        if not os.path.isdir(base):
            self.problems.append('build output folder missing: %s (for %s)' % (rel, target))
            return
        files = [p for p in walk_tree(base) if not any(layout._glob_match(s, p) for s in skip)]
        if not files:
            self.problems.append('build output folder is empty: %s' % rel)
        for p in files:
            path = layout.native(base, p)
            link = None
            if os.path.islink(path):
                link = os.readlink(path)
                if link_escapes(p, link):
                    self.problems.append('symbolic link %s/%s -> %s leads out of %s' % (rel, p, link, rel))
                    continue
                if not self.p.unix:
                    if not os.path.isfile(path):
                        self.problems.append('%s/%s is a link to a folder, which a Windows layout cannot keep'
                                             % (rel, p))
                        continue
                    link = None
            self.add(Item(target + '/' + (rename or {}).get(p, p), 'build', source=path, link=link,
                          note='package.txt ' + note + ': ' + rel + '/'))

    def output(self, target, rel, note):
        """A build output that is a file or, on macOS, a bundle folder."""
        if os.path.isdir(layout.native(self.bin_dir, rel)):
            self.tree(target, rel, note)
        else:
            self.file(target, rel, note)

    def generated(self, target, data, note):
        self.add(Item(target, 'generated', data=data, note=note))


def externals_component(pl, prefix, runtime):
    """package.txt component Externals into <prefix>Externals: the
    externals and database drivers with their lists and, where there is
    CEF, the browser's files. prefix is the tools root or a runtime
    folder (ending in '/'); runtime says which."""
    p = pl.p
    ext = prefix + 'Externals'
    comp = p.component
    for _, name in p.externals + (p.database,):
        pl.output(ext + '/' + name, name, 'Externals.%s / Databases.%s' % (comp, comp))
    for _, name in p.drivers:
        pl.output(ext + '/Database Drivers/' + name, name, 'Databases.' + comp)
    if p.cef:
        note = 'Externals.CEF.' + comp
        for name in p.cef['helpers_in_cef']:
            pl.file(ext + '/CEF/' + name, name, note)
        at = (prefix, p.cef['helpers_at_runtime']) if runtime else (p.engine_dir, p.cef['helpers_at_engine'])
        for name in at[1]:
            pl.file(at[0] + name, name, note)
        for name in p.cef['files']:
            pl.file(ext + '/CEF/' + name, 'Externals/CEF/' + name, note)
        for tree in p.cef['trees']:
            pl.tree(ext + '/CEF/' + tree, 'Externals/CEF/' + tree, note)
    # The IDE and the standalone builder read these line by line, so on
    # Linux and macOS a CR would become part of every file name
    pl.generated(ext + '/Externals.txt', _lines(p.externals + (p.database,), p.eol),
                 'package.txt Externals: emit externals')
    pl.generated(ext + '/Database Drivers/Database Drivers.txt', _lines(p.drivers, p.eol),
                 'package.txt Externals: emit dbdrivers')


def plan_engine(pl):
    """The development engine under its new name, and its support files."""
    p = pl.p
    note = 'Engine.' + p.component
    if p.family != 'mac':
        pl.file(p.engine, p.dev_engine, note + ' (renamed)')
    else:
        # The app bundle, with Contents/MacOS/LiveCode-Community renamed
        # and an Info.plist that says so. The engine finds its tools from
        # its own path, never from its name.
        old = 'Contents/MacOS/' + p.dev_engine[:-len('.app')]
        new = p.engine_executable[len(p.engine) + 1:]
        replaced = [t[len(p.engine) + 1:] for _, t in p.engine_support]
        skip = ['Contents/Info.plist', 'Contents/_CodeSignature/**'] + replaced + [r + '/**' for r in replaced]
        pl.tree(p.engine, p.dev_engine, note + ' (renamed)', skip=skip, rename={old: new})
        plist_path = layout.native(pl.bin_dir, p.dev_engine + '/Contents/Info.plist')
        try:
            with open(plist_path, 'rb') as f:
                plist = plistlib.load(f)
        except (OSError, ValueError, plistlib.InvalidFileException) as e:
            pl.problems.append('cannot read %s: %s' % (plist_path, e))
        else:
            if plist.get('CFBundleExecutable') != p.dev_engine[:-len('.app')]:
                pl.problems.append('%s: CFBundleExecutable is %r, not %r'
                                   % (plist_path, plist.get('CFBundleExecutable'), p.dev_engine[:-len('.app')]))
            plist['CFBundleExecutable'] = new.rsplit('/', 1)[-1]
            pl.generated(p.engine + '/Contents/Info.plist', plistlib.dumps(plist, fmt=plistlib.FMT_XML),
                         'the build\'s Info.plist with CFBundleExecutable %s' % plist['CFBundleExecutable'])
    for rel, target in p.engine_support:
        pl.output(target, rel, note)


def plan_build(pl):
    p = pl.p
    tools = p.tools
    plan_engine(pl)
    # Toolset: emit variable TargetEdition
    pl.generated(tools + 'edition.txt', EDITION.encode('ascii'),
                 'package.txt Toolset: emit variable TargetEdition')
    # Externals (ToolsFolder) and Mobile.<platform>
    externals_component(pl, tools, False)
    for name in p.mobile:
        pl.output(tools + 'Externals/' + name, name, 'Mobile.' + p.component)
    # Toolchain.<platform>
    for name in p.toolchain:
        pl.file(tools + 'Toolchain/' + name, name, 'Toolchain.' + p.component)
    pl.tree(tools + 'Toolchain/modules', 'modules', 'Toolchain.' + p.component)
    # Runtime.<platform> (Windows Sample Icons come from the IDE part)
    for r in p.runtimes:
        folder = tools + r['folder'] + '/'
        rel, name = r['standalone']
        pl.output(folder + name, rel, 'Runtime.%s (%s as %s)' % (p.component, rel, name))
        for f in r['files']:
            pl.file(folder + f, f, 'Runtime.' + p.component)
        for f in r['support']:
            pl.output(folder + 'Support/' + f, f, 'Runtime.' + p.component)
        if r['externals']:
            externals_component(pl, folder, True)
    # Extensions and TimeZone
    for ext in PACKAGED_EXTENSIONS:
        pl.tree(tools + 'Extensions/' + ext, 'packaged_extensions/' + ext,
                'Extensions' if ext != 'com.livecode.library.timezone' else 'TimeZone')


def check_architecture(p, bin_dir, allow_single_arch):
    """Problems (and warnings) when the build is not for the platform: a
    Linux engine of the other architecture, or a macOS build that lacks
    an architecture of the layout (a mac-universal layout needs the lipo
    merge of both builds). Windows is not checked here."""
    problems, warnings = [], []
    if p.elf_arch:
        for rel in (p.dev_engine, 'standalone-community'):
            path = layout.native(bin_dir, rel)
            if os.path.isfile(path):
                arch = binfmt.elf_arch(path)
                if arch != p.elf_arch:
                    problems.append('%s is %s, not an ELF %s executable' % (rel, arch or 'not ELF', p.elf_arch))
    if p.mac_archs:
        name = p.dev_engine[:-len('.app')]
        for rel in (p.dev_engine + '/Contents/MacOS/' + name,
                    'Standalone-Community.app/Contents/MacOS/Standalone-Community', 'revsecurity.dylib'):
            path = layout.native(bin_dir, rel)
            if not os.path.isfile(path):
                continue
            archs = binfmt.macho_archs(path) or []
            lacking = [a for a in p.mac_archs if a not in archs]
            if lacking:
                msg = '%s holds %s, not %s' % (rel, ' '.join(archs) or 'no Mach-O code', ' and '.join(p.mac_archs))
                if allow_single_arch and archs:
                    warnings.append(msg + ' (--allow-single-arch)')
                else:
                    problems.append(msg + ('; a mac-universal layout needs the lipo merge of the arm64 and '
                                           'x86_64 builds (--allow-single-arch stages it anyway)'
                                           if p.arch == 'universal' else ''))
    return problems, warnings


def unused_build_outputs(p, bin_dir, used):
    """[(path, reason or None)] for build outputs that are not installed."""
    out = []
    for path in layout.walk_files(bin_dir):
        if os.path.normcase(layout.native(bin_dir, path)) in used:
            continue
        reason = next((why for pat, why in p.not_installed if layout._glob_match(pat, path)), None)
        out.append((path, reason))
    return out


def plan(repo, bin_dir, build_number, assets, xtalk=None, platform=None):
    """Return (items, folders, problems); folders are installed paths of
    folders to create even if empty. xtalk is what xtalk_extensions.build
    returned, or None."""
    p = platform or PLATFORMS[DEFAULT_PLATFORM]
    tools = p.tools
    pl = Planner(p, bin_dir)
    folders = [tools + d for d in EMPTY_DIRS]

    # IDE
    pairs, ide_problems = layout.plan_assemble(repo, p.ide_include)
    pl.problems.extend('IDE: ' + x for x in ide_problems)
    for target, repo_path in pairs:
        if target == '.buildnumber':
            continue
        pl.add(Item(tools + target, 'ide', source=layout.native(repo, repo_path), note=repo_path))
    pl.generated(tools + '.buildnumber', (build_number + '\n').encode('ascii'),
                 'build number (ide/.buildnumber is a placeholder)')

    # Build outputs
    plan_build(pl)

    # Licence files
    for name in LICENCE_FILES:
        path = os.path.join(repo, name)
        if not os.path.isfile(path):
            pl.problems.append('licence file missing: %s' % path)
            continue
        with open(path, 'rb') as f:
            data = layout._normalise(f.read()).replace(b'\n', p.eol)
        pl.add(Item(tools + name, 'licence', data=data,
                    note=name + (' (CRLF line endings)' if p.eol == b'\r\n' else ' (LF line endings)')))

    # External assets
    for asset, archive in assets:
        files, dirs = fetch_assets.plan_members(asset, archive)
        for target, member in files:
            pl.add(Item(tools + target, 'asset', source=archive, member=member, asset=asset,
                        note='asset %s: %s' % (asset['id'], member)))
        folders.extend(tools + d for d in dirs)

    # xTalk Suite extensions, as xtalk_extensions.build wrote them
    if xtalk:
        pl.add(Item(tools + 'Extensions/' + xtalk['stamp'], 'xtalk',
                    source=layout.native(xtalk['out'], xtalk['stamp']),
                    note='list of the xTalk Suite extensions'))
        for ext in xtalk['extensions']:
            for rel in ext['files']:
                pl.add(Item(tools + 'Extensions/' + rel, 'xtalk', source=layout.native(xtalk['out'], rel),
                            note='%s at %s' % (ext['repository'], ext['commit'][:12])))

    # Conflicts: case-insensitive, as on Windows and macOS volumes, except
    # on Linux
    seen = {}
    items, problems = pl.items, pl.problems
    for it in items:
        key = it.target if p.case_sensitive else it.target.lower()
        if key in seen:
            other = seen[key]
            problems.append('%s comes from both %s (%s) and %s (%s)'
                            % (it.target, other.origin, other.note, it.origin, it.note))
        else:
            seen[key] = it
    items.sort(key=lambda i: i.target)
    return items, sorted(set(folders)), problems


# ---------------------------------------------------------------------------
# Write

def _on_rm_error(func, path, exc_info):
    try:
        os.chmod(path, stat.S_IWRITE)
        func(path)
    except OSError:
        raise exc_info[1]


def remove_tree(path):
    if sys.version_info >= (3, 12):
        shutil.rmtree(path, onexc=lambda f, p, e: _on_rm_error(f, p, (None, e, None)))
    else:
        shutil.rmtree(path, onerror=_on_rm_error)


def _unix_mode(executable):
    return 0o755 if executable else 0o644


def write_stage(stage, items, folders, eol, log, platform=None):
    """Write the planned tree. For a Unix layout every file gets 0755 or
    0644 and every folder 0755 (see the module notes), and build symbolic
    links are recreated; a Windows layout is written as it always was."""
    unix = (platform or PLATFORMS[DEFAULT_PLATFORM]).unix
    if os.path.isdir(stage) and not os.path.islink(stage):
        log('removing the previous %s' % stage)
        remove_tree(stage)
    elif os.path.lexists(stage):
        os.remove(stage)
    os.makedirs(stage)
    archives = {}
    try:
        made = set()
        for it in items:
            dst = layout.native(stage, it.target)
            parent = os.path.dirname(dst)
            if parent not in made:
                os.makedirs(parent, exist_ok=True)
                made.add(parent)
            executable = False
            if it.origin == 'ide':
                if eol != 'keep' and layout.is_text(it.target):
                    with open(it.source, 'rb') as f:
                        data = layout._normalise(f.read())
                    if eol == 'crlf':
                        data = data.replace(b'\n', b'\r\n')
                    with open(dst, 'wb') as f:
                        f.write(data)
                else:
                    shutil.copyfile(it.source, dst)
            elif it.origin == 'build':
                if it.link is not None:
                    os.symlink(it.link, dst)
                    continue
                shutil.copy2(it.source, dst)
                executable = bool(os.stat(it.source).st_mode & 0o111)
            elif it.origin == 'xtalk':
                shutil.copyfile(it.source, dst)
                # the native libraries (code/<platform id>/*); dlopen does
                # not need the bit, but it is how libraries are installed
                executable = '/code/' in it.target
            elif it.origin in ('generated', 'licence'):
                with open(dst, 'wb') as f:
                    f.write(it.data)
            elif it.origin == 'asset':
                z = archives.get(it.source)
                if z is None:
                    z = archives[it.source] = zipfile.ZipFile(it.source)
                info = z.getinfo(it.member)
                # A zip made on Unix (make_runtimes_asset.py stores the
                # modes) says which members are executable or links
                zmode = (info.external_attr >> 16) if info.create_system == 3 else 0
                if unix and stat.S_ISLNK(zmode):
                    os.symlink(z.read(info).decode('utf-8'), dst)
                    continue
                with z.open(info) as src, open(dst, 'wb') as out:
                    shutil.copyfileobj(src, out, 1 << 20)
                # make_runtimes_asset.py stores UTC times
                ts = calendar.timegm(info.date_time + (0, 0, -1))
                os.utime(dst, (ts, ts))
                executable = bool(zmode & 0o111)
            else:
                raise PackageError('unknown origin %s' % it.origin)
            if unix:
                os.chmod(dst, _unix_mode(executable))
        for d in folders:
            os.makedirs(layout.native(stage, d), exist_ok=True)
        if unix:
            for dirpath, dirnames, _ in os.walk(stage):
                os.chmod(dirpath, 0o755)
    finally:
        for z in archives.values():
            z.close()


# ---------------------------------------------------------------------------
# Build tarballs

def _is_debug(parts):
    """Debug symbols, which no layout installs: Linux .dbg files (objcopy
    --only-keep-debug), macOS .dSYM bundles, Windows .pdb files."""
    return parts[-1].endswith(('.dbg', '.pdb')) or any(p.endswith('.dSYM') for p in parts)


def extract_bin_tar(path, dest, log):
    """Extract a CI build tarball into dest and return its build output
    folder (the tarball's one top-level folder). Modes, symbolic links and
    hard links are kept; debug symbols and "._" AppleDouble files (which
    macOS tar writes for extended attributes) are skipped. Member names are
    checked: nothing may land outside dest. Python 3.8 has no extraction
    filter, so the checks are made here."""
    tops, skipped, count = set(), 0, 0
    with tarfile.open(path, 'r|*') as tf:
        for m in tf:
            name = m.name
            while name.startswith('./'):
                name = name[2:]
            name = name.rstrip('/')
            if not name or name == '.':
                continue
            parts = name.split('/')
            if name.startswith('/') or '\\' in name or any(p in ('', '.', '..') for p in parts):
                raise PackageError('%s: unsafe member name %r' % (path, m.name))
            if any(p.startswith('._') for p in parts) or parts[-1] == '.DS_Store':
                continue
            if _is_debug(parts):
                skipped += 1
                continue
            tops.add(parts[0])
            target = os.path.join(dest, *parts)
            if m.isdir():
                os.makedirs(target, exist_ok=True)
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            if m.issym():
                if link_escapes(name, m.linkname):
                    raise PackageError('%s: symbolic link %s -> %s leads out of the tarball'
                                       % (path, name, m.linkname))
                os.symlink(m.linkname, target)
            elif m.islnk():
                other = m.linkname
                while other.startswith('./'):
                    other = other[2:]
                src = os.path.join(dest, *other.split('/'))
                if '..' in other.split('/') or not os.path.isfile(src):
                    raise PackageError('%s: hard link %s -> %s: no such file extracted before it'
                                       % (path, name, m.linkname))
                shutil.copy2(src, target)
            elif m.isfile():
                with tf.extractfile(m) as f, open(target, 'wb') as out:
                    shutil.copyfileobj(f, out, 1 << 20)
                os.chmod(target, m.mode & 0o777)
                os.utime(target, (m.mtime, m.mtime))
            else:
                raise PackageError('%s: %s is a device, FIFO or other special file' % (path, name))
            count += 1
    folders = [t for t in tops if os.path.isdir(os.path.join(dest, t))]
    if len(folders) != 1 or len(tops) != 1:
        raise PackageError('%s: expected one top-level folder, found %s' % (path, ', '.join(sorted(tops)) or 'none'))
    log('Extracted    : %d files from %s (%d debug symbol files skipped)' % (count, path, skipped))
    return os.path.join(dest, folders[0])


def repository_mode_trap(path, platform):
    """The folder name in path that makes the engine run the IDE in
    repository mode, or None. The engine's environment stack
    (engine/src/environment/stackbehavior.livecodescript guessRepositoryPath)
    and the IDE (home stack revEnvironmentGuessRepositoryPath) take the
    folder above the first item of the engine's path that is
    build-<platform>-<processor>, <platform>-<processor>-bin,
    <platform>-bin or _build (compared without regard to case, as
    LiveCode's "is among the items" does) as a source checkout, and load
    the IDE from its ide/ folder instead of the package's."""
    word = {'windows': 'win', 'linux': 'linux', 'mac': 'mac'}[platform.family]
    procs = platform.mac_archs or (platform.arch,)
    names = {'_build', word + '-bin'}
    for proc in procs:
        proc = 'x86' if proc == 'i386' else proc
        names.update(('build-%s-%s' % (word, proc), '%s-%s-bin' % (word, proc)))
    for part in re.split(r'[\\/]', path):
        if part.lower() in names:
            return part
    return None


# ---------------------------------------------------------------------------
# Compare with a reference install

def load_reference(ref):
    """Return (root or None, paths, empty folders, classes listed). For a
    TSV from "layout.py classify" the classes are those of its first
    column; otherwise None."""
    if os.path.isdir(ref):
        return ref, layout.walk_files(ref), layout.empty_dirs(ref), None
    paths, classes = set(), set()
    with open(ref, encoding='utf-8') as f:
        for line in f:
            cols = line.rstrip('\r\n').split('\t')
            if not line.strip():
                continue
            if cols[0] == 'class':
                continue
            if cols[0] in layout.CLASS_ORDER and len(cols) > 1:
                paths.add(cols[1])
                classes.add(cols[0])
            else:
                paths.add(cols[0])
    return None, sorted(paths), [], classes or None


def reference_engine(paths):
    exes = [p for p in paths if '/' not in p and p.lower().endswith('.exe') and not p.startswith('.')]
    return exes[0] if len(exes) == 1 else None


def compare(stage, items, ref, no_assets, report=None, no_xtalk=False, platform=None):
    """Print the comparison; return the number of unexplained differences.
    The reference is a Windows install (layout.py's classes describe
    one), so this is for the win-x86_64 layout."""
    exe_name = (platform or PLATFORMS[DEFAULT_PLATFORM]).engine
    root, ref_paths, ref_empty, listed_classes = load_reference(ref)
    by_target = {it.target: it for it in items}
    by_lower = {it.target.lower(): it for it in items}
    engine = reference_engine(ref_paths)
    rows = []            # (status, reference path, staged path, class, detail)
    matched = set()
    problems = 0
    counts = collections.Counter()

    for p in ref_paths:
        cls, _, _ = layout.classify_path(p)
        q = exe_name if p == engine else p
        it = by_target.get(q) or by_lower.get(q.lower())
        why = next((w for pat, w in INTENDED_MISSING if layout._glob_match(pat, p)), None)
        if cls in (layout.JUNK, layout.EXCLUDED):
            if it is not None:
                rows.append(('ERROR shipped', p, it.target, cls, 'class %s must not be packaged' % cls))
                problems += 1
                matched.add(it.target)
            else:
                rows.append(('not packaged', p, '', cls, 'class %s' % cls))
            counts[(cls, 'left out as intended')] += 1
            continue
        if it is None:
            if why:
                rows.append(('intended missing', p, '', cls, why))
                counts[(cls, 'intended missing')] += 1
            elif cls == layout.EXTERNAL and no_assets:
                rows.append(('intended missing', p, '', cls, '--no-external-assets'))
                counts[(cls, 'intended missing')] += 1
            elif cls == layout.XTALK and no_xtalk:
                rows.append(('intended missing', p, '', cls, '--no-xtalk-extensions'))
                counts[(cls, 'intended missing')] += 1
            elif cls == layout.IDE:
                rows.append(('IDE change: removed', p, '', cls, 'not in the repository\'s IDE'))
                counts[(cls, 'not in the IDE any more')] += 1
            else:
                rows.append(('ERROR missing', p, '', cls, 'not staged'))
                counts[(cls, 'MISSING')] += 1
                problems += 1
            continue
        matched.add(it.target)
        detail = ''
        status = 'present'
        if q != p:
            detail = 'renamed from %s' % p
        if root is not None:
            ref_file = layout.native(root, p)
            staged = layout.native(stage, it.target)
            if it.origin == 'generated':
                status = 'present (generated)'
                if _same_bytes(ref_file, staged):
                    status = 'present (generated, identical)'
            elif cls == layout.IDE:
                if not layout.same_content(p, ref_file, staged):
                    status = 'IDE change: modified'
            elif cls == layout.EXTERNAL:
                if not _same_bytes(ref_file, staged):
                    status = 'ERROR content'
                    detail = 'external asset file differs from the reference'
                    problems += 1
            elif cls in (layout.BUILD, layout.XTALK):
                status = 'present (identical)' if _same_bytes(ref_file, staged) else 'present (rebuilt)'
        rows.append((status, p, it.target, cls, detail))
        counts[(cls, status)] += 1

    # A TSV reference may list only some classes (for example only the
    # build files); staged files of other classes are then not compared.
    ref_classes = listed_classes or {layout.classify_path(p)[0] for p in ref_paths}
    for it in items:
        if it.target in matched:
            continue
        cls, _, _ = layout.classify_path(it.target)
        if root is None and cls not in ref_classes:
            counts[('(staged only)', 'class not in the list')] += 1
            continue
        if it.origin == 'licence':
            status, why = 'intended addition', 'OXT-Beyond licence file'
        elif it.origin == 'asset' and _asset_rel(it) in it.asset.get('rename', {}):
            status, why = 'intended addition', 'notice file of an external asset (%s)' % it.note
        elif it.origin == 'ide':
            status, why = 'IDE change: added', it.note
        elif it.origin == 'xtalk':
            status, why = 'intended addition', 'xTalk Suite extension (%s)' % it.note
        else:
            status, why = 'ERROR extra', '%s: %s' % (it.origin, it.note)
            problems += 1
        rows.append((status, '', it.target, cls, why))
        counts[('(staged only)', status)] += 1

    # Empty folders (a TSV reference has none to compare)
    staged_empty = set(layout.empty_dirs(stage)) if root is not None else set()
    for d in ref_empty:
        cls, _, _ = layout.classify_path(d + '/x')
        if d in staged_empty:
            rows.append(('present', d + '/', d + '/', 'folder', 'empty folder'))
            counts[('(empty folders)', 'present')] += 1
        elif cls == layout.EXTERNAL and (no_assets or d.startswith('Ext/')):
            rows.append(('intended missing', d + '/', '', 'folder', 'empty folder of an asset left out'))
            counts[('(empty folders)', 'intended missing')] += 1
        else:
            rows.append(('ERROR missing', d + '/', '', 'folder', 'empty folder of the reference'))
            counts[('(empty folders)', 'MISSING')] += 1
            problems += 1
    for d in sorted(staged_empty - set(ref_empty)):
        rows.append(('ERROR extra', '', d + '/', 'folder', 'empty folder not in the reference'))
        counts[('(empty folders)', 'extra')] += 1
        problems += 1

    print('')
    print('Comparison with %s' % ref)
    if engine:
        print('  engine %s is staged as %s' % (engine, exe_name))
    print('  %-10s %-26s %7s' % ('class', 'status', 'files'))
    for (cls, status) in sorted(counts, key=lambda k: (str(k[0]), k[1])):
        print('  %-10s %-26s %7d' % (cls, status, counts[(cls, status)]))
    for title in ('ERROR', 'intended missing', 'intended addition'):
        chosen = [r for r in rows if r[0].startswith(title)]
        if not chosen:
            continue
        print('')
        print('%s (%d):' % (title if title != 'ERROR' else 'Unexplained differences', len(chosen)))
        groups = collections.OrderedDict()
        for r in chosen:
            groups.setdefault((r[0], r[4]), []).append(r[1] or r[2])
        for (status, why), paths in groups.items():
            print('  [%s] %s' % (status, why))
            for pth in paths[:12]:
                print('      ' + pth)
            if len(paths) > 12:
                print('      ... and %d more' % (len(paths) - 12))
    ide_changes = [r for r in rows if r[0].startswith('IDE change')]
    if ide_changes:
        print('')
        print('IDE changes since the reference (not errors): %d' % len(ide_changes))
        for r in ide_changes[:40]:
            print('  [%s] %s' % (r[0][len('IDE change: '):], r[1] or r[2]))
        if len(ide_changes) > 40:
            print('  ... and %d more (see the report)' % (len(ide_changes) - 40))
    if report:
        with open(report, 'w', encoding='utf-8', newline='\n') as f:
            f.write('status\treference_path\tstaged_path\tclass\tdetail\n')
            for r in rows:
                f.write('\t'.join(r) + '\n')
        print('')
        print('report: %s' % report)
    print('')
    print('COMPARE %s (%d unexplained differences)' % ('FAILED' if problems else 'PASSED', problems))
    return problems


def _asset_rel(item):
    """Archive path of an asset item after strip."""
    return '/'.join(item.member.split('/')[item.asset['strip']:])


def _same_bytes(a, b):
    if os.path.getsize(a) != os.path.getsize(b):
        return False
    with open(a, 'rb') as fa, open(b, 'rb') as fb:
        while True:
            x = fa.read(1 << 20)
            y = fb.read(1 << 20)
            if x != y:
                return False
            if not x:
                return True


# ---------------------------------------------------------------------------
# Command line

def group_of(p, target):
    """Summary group of a staged path: layout.py's groups below the tools
    folder; on macOS the engine's own files are one group."""
    if p.tools and target.startswith(p.tools):
        return layout.group_of(target[len(p.tools):])
    if p.family == 'mac':
        return p.engine + ' (engine)'
    return layout.group_of(target)


def summarise(items, stage, bin_dir, used, log, platform=None):
    p = platform or PLATFORMS[DEFAULT_PLATFORM]
    by_origin = collections.Counter()
    size_origin = collections.Counter()
    by_group = collections.Counter()
    size_group = collections.Counter()
    for it in items:
        size = os.path.getsize(layout.native(stage, it.target))
        by_origin[it.origin] += 1
        size_origin[it.origin] += size
        g = group_of(p, it.target)
        by_group[g] += 1
        size_group[g] += size
    log('')
    log('Staged %d files, %s bytes, in %s' % (len(items), '{:,}'.format(sum(size_origin.values())), stage))
    for o in ('ide', 'build', 'generated', 'licence', 'asset', 'xtalk'):
        if by_origin[o]:
            log('  %-10s %6d files %15s bytes' % (o, by_origin[o], '{:,}'.format(size_origin[o])))
    empty = layout.empty_dirs(stage)
    log('  empty folders: %d (%s)' % (len(empty), ', '.join(empty)))
    log('')
    log('By folder:')
    for g in sorted(by_group):
        log('  %6d %15s  %s' % (by_group[g], '{:,}'.format(size_group[g]), g))
    unused = unused_build_outputs(p, bin_dir, used)
    if unused:
        log('')
        log('Build outputs not installed: %d' % len(unused))
        grouped = collections.OrderedDict()
        for path, why in unused:
            grouped.setdefault(why, []).append(path)
        for why, paths in grouped.items():
            shown = ', '.join(paths[:6]) + (' ... (%d files)' % len(paths) if len(paths) > 6 else '')
            log('  %s: %s' % (why or 'WARNING: no rule in package.py; not installed', shown))
    return by_origin, size_origin


def summarise_xtalk(xtalk, log):
    log('')
    log('xTalk Suite extensions (Extensions/):')
    for e in xtalk['extensions']:
        log('  %-36s %s %-8s %s@%s' % (e['folder'], e['kind'], e['version'], e['repository'], e['commit'][:12]))
    if xtalk['vc_runtime_files']:
        versions = sorted({f['file_version'] for f in xtalk['vc_runtime_files']})
        log('  Visual C++ runtime bundled: %d DLLs, file version %s, from the redistributable folder %s (%s)'
            % (len(xtalk['vc_runtime_files']), ', '.join(versions), xtalk['vc_redist_version'],
               'pinned' if xtalk['vc_runtime_pinned'] else 'NOT the pinned runtime'))
    for f in xtalk['vc_runtime_files']:
        if not f['pinned']:
            log('WARNING: Extensions/%s is NOT the pinned Visual C++ runtime (file version %s); packaged with '
                '--allow-unpinned-vc-runtime' % (f['path'], xtalk['vc_runtime_pinned_file_version']))
    for m in xtalk['missing_runtime']:
        log('WARNING: Extensions/%s needs %s, which is not bundled (no --vc-redist): it cannot load on a '
            'PC without the Visual C++ Redistributable' % (m['library'], ', '.join(m['needs'])))
    for s in xtalk['vc_runtime_older_than_build_tools']:
        log('WARNING: Extensions/%s was built with MSVC %s, but the Visual C++ runtime bundled for it is older '
            '(%s); Microsoft supports only a runtime at least as new as the newest toolset used'
            % (s['library'], s['linker'], ', '.join('%s %s' % (r['dll'], r['file_version']) for r in s['runtime'])))


def main(argv=None):
    p = argparse.ArgumentParser(description='Stage the installed layout of OXT-Beyond for one platform.')
    p.add_argument('--platform', choices=list(PLATFORMS), default=DEFAULT_PLATFORM,
                   help='layout to stage (default: %(default)s)')
    p.add_argument('--repo', default=os.path.dirname(os.path.dirname(HERE)),
                   help='repository root (default: two levels above this script)')
    p.add_argument('--bin', dest='bin_dir',
                   help='build output (default: the platform\'s, e.g. <repo>/win-x86_64-bin)')
    p.add_argument('--bin-tar', metavar='FILE',
                   help='build output as a CI tarball (OXT-Beyond-<platform>-bin.tar.xz), instead of --bin')
    p.add_argument('--out', required=True, help='folder to create OXT-Beyond-<version> in')
    p.add_argument('--build-number', help='default: $%s, else the UTC time as YYYYMMDDHHMM' % BUILD_NUMBER_ENV)
    p.add_argument('--assets-cache', metavar='DIR',
                   help='asset cache (default: $%s, else <repo>/prebuilt/fetched-assets)' % fetch_assets.CACHE_ENV)
    p.add_argument('--manifest', default=fetch_assets.DEFAULT_MANIFEST, help='asset manifest (default: %(default)s)')
    p.add_argument('--no-external-assets', action='store_true', help='leave the external assets out')
    p.add_argument('--no-xtalk-extensions', action='store_true',
                   help='leave the xTalk Suite extensions (tools/oxt/xtalk-extensions.json) out')
    p.add_argument('--xtalk-manifest', default=xtalk_extensions.DEFAULT_MANIFEST,
                   help='xTalk extensions manifest (default: %(default)s)')
    p.add_argument('--xtalk-cache', metavar='DIR',
                   help='xTalk extensions cache (default: $%s, else <asset cache>/xtalk)'
                        % xtalk_extensions.CACHE_ENV)
    p.add_argument('--xtalk-compiler-bin', metavar='DIR',
                   help='build output whose lc-compile and modules/lci compile the xTalk extensions '
                        '(default: --bin; a build this machine can run)')
    p.add_argument('--vc-redist', metavar='DIR',
                   help='Visual Studio\'s VC\\Redist\\MSVC\\<version> folder (VCToolsRedistDir): bundle '
                        'the Visual C++ runtime DLLs that xTalk extension libraries import')
    p.add_argument('--allow-unpinned-vc-runtime', action='store_true',
                   help='only warn when a Visual C++ runtime DLL is not the one the xTalk manifest pins '
                        '(never for a release)')
    p.add_argument('--offline', action='store_true', help='use cached assets and extensions only, never download')
    p.add_argument('--eol', choices=('lf', 'crlf', 'keep'), default='lf',
                   help='line endings of IDE text files (default: lf, as git stores them)')
    p.add_argument('--allow-single-arch', action='store_true',
                   help='mac-universal: stage a build that holds only one architecture (for testing)')
    p.add_argument('--summary-json', metavar='FILE', help='write a JSON summary here')
    p.add_argument('--compare', metavar='REF', help='installed folder or classify TSV to compare with')
    p.add_argument('--report', metavar='FILE', help='with --compare: write every path\'s status as TSV')
    args = p.parse_args(argv)
    plat = PLATFORMS[args.platform]
    if args.compare and plat.family != 'windows':
        p.error('--compare compares with a Windows install (layout.py classes); use it with win-x86_64')
    if args.bin_dir and args.bin_tar:
        p.error('pass --bin or --bin-tar, not both')

    log = print
    xtalk_tmp = None
    bin_tmp = None
    try:
        if plat.unix and os.name == 'nt':
            raise PackageError('stage the %s layout on Linux or macOS (or in WSL): Windows keeps neither the '
                               'file modes nor the symbolic links of a Unix tree' % plat.name)
        repo = os.path.abspath(args.repo)
        if not os.path.isdir(os.path.join(repo, 'ide')):
            raise PackageError('%s has no ide/ folder (not the repository root?)' % repo)
        if args.bin_tar:
            bin_tmp = tempfile.mkdtemp(prefix='oxt-bin-')
            bin_dir = extract_bin_tar(os.path.abspath(args.bin_tar), bin_tmp, log)
        else:
            bin_dir = os.path.abspath(args.bin_dir or layout.native(repo, plat.bin_default))
        if not os.path.exists(os.path.join(bin_dir, plat.dev_engine)):
            raise PackageError('no %s build in %s (%s is missing)' % (plat.name, bin_dir, plat.dev_engine))
        version = read_version(repo)
        build_number = default_build_number(args.build_number)
        out = os.path.abspath(args.out)
        package_root = '%s-%s' % (PRODUCT, version)
        stage = os.path.join(out, package_root)
        for inside in (repo, bin_dir):
            if os.path.normcase(stage) == os.path.normcase(inside) or \
                    os.path.normcase(inside).startswith(os.path.normcase(stage) + os.sep):
                raise PackageError('the stage folder %s would contain %s' % (stage, inside))

        log('Product      : %s %s (build %s)' % (PRODUCT, version, build_number))
        log('Platform     : %s' % plat.name)
        log('Engine       : %s' % (engine_version(repo) or '?'))
        log('Repository   : %s' % repo)
        log('Build output : %s' % (bin_dir if not args.bin_tar else '%s (from %s)' % (bin_dir, args.bin_tar)))
        log('Stage        : %s' % stage)
        trap = repository_mode_trap(stage, plat)
        if trap:
            log('WARNING: the stage path has a folder named %s: an engine started from it runs the IDE of '
                'the source checkout above it (repository mode), not the staged one' % trap)

        arch_problems, arch_warnings = check_architecture(plat, bin_dir, args.allow_single_arch)
        for w in arch_warnings:
            log('WARNING: ' + w)
        if arch_problems:
            for msg in arch_problems:
                sys.stderr.write('error: %s\n' % msg)
            raise PackageError('the build in %s is not a %s build' % (bin_dir, plat.name))

        assets = []
        if args.no_external_assets:
            log('External assets: left out (--no-external-assets)')
        else:
            cache = fetch_assets.cache_dir(repo, args.assets_cache)
            log('Asset cache  : %s' % cache)
            for a in fetch_assets.load_manifest(args.manifest):
                assets.append((a, fetch_assets.fetch(a, cache, args.offline, log)))

        xtalk = None
        if args.no_xtalk_extensions:
            log('xTalk extensions: left out (--no-xtalk-extensions)')
        else:
            # Built into a temporary folder with this build's lc-compile,
            # then staged byte for byte like build outputs
            xcache = xtalk_extensions.cache_dir(repo, args.xtalk_cache,
                                                fetch_assets.cache_dir(repo, args.assets_cache))
            compiler_bin = os.path.abspath(args.xtalk_compiler_bin or bin_dir)
            log('xTalk cache  : %s' % xcache)
            if compiler_bin != bin_dir:
                log('xTalk compiler: %s' % compiler_bin)
            if args.vc_redist:
                log('VC++ redist  : %s' % args.vc_redist)
            else:
                log('WARNING: no --vc-redist: the Visual C++ runtime that enetxt and box2dxt need is not bundled')
            xtalk_data = xtalk_extensions.load_manifest(args.xtalk_manifest)
            xtalk_tmp = tempfile.mkdtemp(prefix='oxt-xtalk-')
            xtalk = xtalk_extensions.build(xtalk_data, compiler_bin, xtalk_tmp, xcache, None, args.vc_redist,
                                           args.offline, log, args.allow_unpinned_vc_runtime)
            log('')

        items, folders, problems = plan(repo, bin_dir, build_number, assets, xtalk, plat)
        if problems:
            for msg in problems:
                sys.stderr.write('error: %s\n' % msg)
            raise PackageError('%d problem(s); nothing was written' % len(problems))

        t0 = time.time()
        write_stage(stage, items, folders, args.eol, log, plat)
        log('written in %.0f s' % (time.time() - t0))
        used = {os.path.normcase(it.source) for it in items if it.origin == 'build'}
        by_origin, size_origin = summarise(items, stage, bin_dir, used, log, plat)

        if args.summary_json:
            summary = collections.OrderedDict([
                ('product', PRODUCT),
                ('version', version),
                ('build_number', build_number),
                ('engine_version', engine_version(repo)),
                ('platform', plat.name),
                ('package_root', package_root),
                ('stage_dir', stage),
                ('exe', plat.engine),
                ('engine_executable', plat.engine_executable),
                ('tools_root', plat.tools.rstrip('/')),
                ('bin_dir', bin_dir if not args.bin_tar else None),
                ('bin_tar', os.path.abspath(args.bin_tar) if args.bin_tar else None),
                ('files', len(items)),
                ('bytes', sum(size_origin.values())),
                ('by_origin', collections.OrderedDict((o, by_origin[o]) for o in sorted(by_origin))),
                ('empty_dirs', layout.empty_dirs(stage)),
                ('external_assets', [collections.OrderedDict([('id', a['id']), ('sha256', a['sha256']),
                                                               ('url', a['url'])]) for a, _ in assets]),
                ('xtalk_extensions', [collections.OrderedDict(
                    (k, e[k]) for k in ('folder', 'kind', 'id', 'member', 'version', 'repository', 'commit'))
                    for e in (xtalk['extensions'] if xtalk else [])]),
                ('vc_redist', xtalk['vc_redist'] if xtalk else None),
                ('vc_redist_version', xtalk['vc_redist_version'] if xtalk else None),
                ('vc_runtime_pinned', xtalk['vc_runtime_pinned'] if xtalk else None),
                ('vc_runtime_pinned_file_version', xtalk['vc_runtime_pinned_file_version'] if xtalk else None),
                ('vc_runtime_files', xtalk['vc_runtime_files'] if xtalk else []),
                ('xtalk_missing_runtime', xtalk['missing_runtime'] if xtalk else []),
                ('vc_runtime_older_than_build_tools', xtalk['vc_runtime_older_than_build_tools'] if xtalk else []),
            ])
            with open(args.summary_json, 'w', encoding='utf-8', newline='\n') as f:
                json.dump(summary, f, indent=2)
                f.write('\n')

        if xtalk:
            summarise_xtalk(xtalk, log)

        if args.compare:
            if compare(stage, items, args.compare, args.no_external_assets, args.report,
                       args.no_xtalk_extensions, plat):
                return 1
    except (PackageError, fetch_assets.AssetError, xtalk_extensions.XtalkError) as e:
        sys.stderr.write('error: %s\n' % e)
        return 2
    finally:
        if xtalk_tmp:
            shutil.rmtree(xtalk_tmp, ignore_errors=True)
        if bin_tmp:
            shutil.rmtree(bin_tmp, ignore_errors=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
