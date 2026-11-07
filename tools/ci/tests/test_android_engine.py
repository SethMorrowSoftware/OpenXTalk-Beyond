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

"""The Android engine built here with a current NDK (the Android plan's phase
2): config.py's and prebuilt/scripts/android.inc's choice of toolchain (the
NDK's own when there is no standalone toolchain, which is used as before
when there is one), OpenSSL's Android targets, the linker the gyp settings
name, tools/ci/build-android.sh's names, libffi's assembly for each
Android architecture (assembled with this host's clang when it has one),
tools/ci/android_engine.py's checks on made-up ELF files, and
android-engine.yml. No NDK, SDK or engine is needed.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import importlib.util
import io
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from unittest import mock

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import android_engine as ae  # noqa: E402
import android_java  # noqa: E402

BASH = shutil.which('bash') if os.name != 'nt' else None


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


def load_config():
    """config.py as a module (Python 2 code that Python 3 can import: its
    functions that the tests call are both)."""
    spec = importlib.util.spec_from_file_location('oxt_config', os.path.join(REPO, 'config.py'))
    module = importlib.util.module_from_spec(spec)
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')     # its regular expressions' escapes
        spec.loader.exec_module(module)
    return module


CONFIG = load_config()
HOSTS = {'Linux': 'linux-x86_64', 'Darwin': 'darwin-x86_64', 'Windows': 'windows-x86_64'}


def touch(path, data=b''):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data)


def fake_ndk(root, hosts=('linux-x86_64', 'darwin-x86_64', 'windows-x86_64')):
    """An NDK folder with its own toolchain's clang for the hosts."""
    ndk = os.path.join(root, 'ndk')
    touch(os.path.join(ndk, 'source.properties'), b'Pkg.Revision = 30.0.16248370\n')
    for host in hosts:
        touch(os.path.join(ndk, 'toolchains', 'llvm', 'prebuilt', host, 'bin',
                           'clang.exe' if host.startswith('windows') else 'clang'))
    return ndk


def llvm_bin(ndk, host):
    return os.path.join(ndk, 'toolchains', 'llvm', 'prebuilt', host, 'bin')


# ---------------------------------------------------------------------------
# config.py


class ConfigToolchain(unittest.TestCase):
    """config.py's validate_android_tools: the NDK's own toolchain when there
    is no standalone toolchain, and the standalone toolchain as before."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.ndk = fake_ndk(self.tmp)
        self.sdk = os.path.join(self.tmp, 'sdk')
        os.makedirs(os.path.join(self.sdk, 'build-tools', '36.0.0'))
        self.toolchains = os.path.join(self.tmp, 'toolchain')
        os.makedirs(self.toolchains)
        self.system = mock.patch.object(CONFIG.platform, 'system', return_value='Linux')
        self.system.start()
        self.addCleanup(self.system.stop)

    def options(self, arch, **extra):
        opts = {}
        with mock.patch.dict(os.environ, {}, clear=True):
            CONFIG.process_env_options(opts)
        opts.update(TARGET_ARCH=arch, ANDROID_NDK=self.ndk, ANDROID_SDK=self.sdk,
                    ANDROID_TOOLCHAIN_DIR=self.toolchains)
        opts.update(extra)
        CONFIG.validate_android_tools(opts)
        return opts

    def test_the_ndks_own_toolchain(self):
        bin_ = llvm_bin(self.ndk, 'linux-x86_64')
        o = self.options('arm64')
        self.assertEqual(o['ANDROID_NDK_PLATFORM_VERSION'], '21')
        self.assertEqual(o['ANDROID_FUSE_LD'], 'lld')
        self.assertEqual(o['AR'], os.path.join(bin_, 'llvm-ar'))
        self.assertEqual(o['OBJCOPY'], os.path.join(bin_, 'llvm-objcopy'))
        self.assertEqual(o['OBJDUMP'], os.path.join(bin_, 'llvm-objdump'))
        self.assertEqual(o['STRIP'], os.path.join(bin_, 'llvm-strip'))
        self.assertEqual(o['CC'].split(), [os.path.join(bin_, 'clang'), '-target', 'aarch64-linux-android21',
                                           '-Qunused-arguments'])
        self.assertEqual(o['CXX'].split()[0], os.path.join(bin_, 'clang++'))
        self.assertEqual(o['LINK'].split(), [os.path.join(bin_, 'clang++'), '-target', 'aarch64-linux-android21',
                                             '-fuse-ld=lld', '-static-libstdc++'])
        self.assertEqual(o['ANDROID_LIB_PATH'],
                         os.path.join(os.path.dirname(bin_), 'sysroot', 'usr', 'lib', 'aarch64-linux-android', '21'))
        self.assertIsNone(o['ANDROID_TOOLCHAIN'])

    def test_each_architecture(self):
        bin_ = llvm_bin(self.ndk, 'linux-x86_64')
        cases = {
            'armv7': ('armv7a-linux-androideabi21', ['-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=vfpv3-d16',
                                                    '-mthumb'], 'arm-linux-androideabi'),
            'arm64': ('aarch64-linux-android21', [], 'aarch64-linux-android'),
            'x86': ('i686-linux-android21', ['-march=i686'], 'i686-linux-android'),
            'x86_64': ('x86_64-linux-android21', [], 'x86_64-linux-android'),
        }
        for arch, (target, flags, libdir) in cases.items():
            with self.subTest(arch=arch):
                o = self.options(arch)
                cc = o['CC'].split()
                self.assertEqual(cc[1:3], ['-target', target])
                for flag in flags:
                    self.assertIn(flag, cc)
                link = o['LINK'].split()
                self.assertEqual(link[1:3], ['-target', target])
                self.assertIn('-fuse-ld=lld', link)
                self.assertNotIn('-fuse-ld=bfd', link)
                self.assertNotIn('-integrated-as', cc)
                if arch == 'armv7':
                    self.assertIn('-Wl,--fix-cortex-a8', link)
                self.assertEqual(o['ANDROID_LIB_PATH'],
                                 os.path.join(os.path.dirname(bin_), 'sysroot', 'usr', 'lib', libdir, '21'))

    def test_a_platform_version_that_is_set_stays(self):
        o = self.options('x86_64', ANDROID_NDK_PLATFORM_VERSION='24')
        self.assertEqual(o['ANDROID_NDK_PLATFORM_VERSION'], '24')
        self.assertIn('x86_64-linux-android24', o['CC'])
        self.assertTrue(o['ANDROID_LIB_PATH'].endswith(os.path.join('x86_64-linux-android', '24')))

    def test_tools_that_are_set_stay(self):
        o = self.options('arm64', CC='my-cc', AR='my-ar', ANDROID_FUSE_LD='gold', ANDROID_LIB_PATH='/libs')
        self.assertEqual(o['CC'], 'my-cc')
        self.assertEqual(o['AR'], 'my-ar')
        self.assertEqual(o['ANDROID_FUSE_LD'], 'gold')
        self.assertEqual(o['ANDROID_LIB_PATH'], '/libs')
        self.assertIn('clang++', o['CXX'])

    def test_each_host(self):
        for system, host in HOSTS.items():
            with self.subTest(system=system), mock.patch.object(CONFIG.platform, 'system', return_value=system):
                self.assertEqual(CONFIG.guess_ndk_llvm_bin(self.ndk), llvm_bin(self.ndk, host))
        with mock.patch.object(CONFIG.platform, 'system', return_value='CYGWIN_NT-10.0'):
            self.assertEqual(CONFIG.guess_ndk_llvm_bin(self.ndk), llvm_bin(self.ndk, 'windows-x86_64'))

    def test_an_ndk_without_its_own_toolchain(self):
        old = os.path.join(self.tmp, 'old-ndk')
        os.makedirs(old)
        self.assertIsNone(CONFIG.guess_ndk_llvm_bin(old))
        with self.assertRaises(SystemExit), contextlib.redirect_stdout(io.StringIO()) as out:
            self.options('arm64', ANDROID_NDK=old)
        self.assertIn('Android toolchain not found for architecture arm64', out.getvalue())

    def test_a_standalone_toolchain_is_used_as_before(self):
        # (what config.py did before the NDK's own toolchain: the standalone
        # toolchain of make_standalone_toolchain.py in the toolchain folder,
        # API 16, the bfd linker)
        for arch, folder, prefix, triple in (('arm64', 'standalone-arm64', 'aarch64-linux-android-',
                                              'aarch64-linux-android'),
                                             ('armv7', 'standalone-arm', 'arm-linux-androideabi-',
                                              'armv7-linux-androideabi')):
            with self.subTest(arch=arch):
                os.makedirs(os.path.join(self.toolchains, folder), exist_ok=True)
                o = self.options(arch)
                tc = os.path.join(self.toolchains, folder, 'bin', prefix)
                self.assertEqual(o['ANDROID_TOOLCHAIN'], tc)
                self.assertEqual(o['ANDROID_NDK_PLATFORM_VERSION'], '16')
                self.assertEqual(o['ANDROID_FUSE_LD'], 'bfd')
                self.assertEqual(o['AR'], tc + 'ar ')
                self.assertEqual(o['OBJCOPY'], tc + 'objcopy ')
                self.assertTrue(o['CC'].startswith(tc + 'clang -target %s ' % triple))
                self.assertIn('-integrated-as', o['CC'])
                self.assertIn('-fuse-ld=bfd', o['LINK'])
                self.assertNotIn('-static-libstdc++', o['LINK'])

    def test_a_named_toolchain_is_used_as_before(self):
        o = self.options('x86', ANDROID_TOOLCHAIN='/opt/tc/bin/i686-linux-android-')
        self.assertEqual(o['CC'].split()[:3], ['/opt/tc/bin/i686-linux-android-clang', '-target',
                                               'i686-linux-android'])
        self.assertEqual(o['ANDROID_FUSE_LD'], 'bfd')
        self.assertEqual(o['ANDROID_NDK_PLATFORM_VERSION'], '16')

    def test_the_linker_reaches_gyp(self):
        text = read('config.py')
        configure = text[text.index('def configure_android('):]
        configure = configure[:configure.index('\ndef ')]
        self.assertIn("'ANDROID_FUSE_LD'", configure)
        env = text[text.index('def process_env_options('):]
        self.assertIn("'ANDROID_FUSE_LD'", env[:env.index('\ndef ')])
        # android.gypi reads it for every gyp file, and android-settings.gypi
        # has it again for its target_conditions (which see a target's
        # variables, not a file's)
        self.assertEqual(gyp('config', 'android.gypi')['variables']['android_fuse_ld%'],
                         '<!(echo ${ANDROID_FUSE_LD:-bfd})')
        settings = gyp('config', 'android-settings.gypi')
        self.assertEqual(settings['variables']['android_fuse_ld%'], '<(android_fuse_ld)')
        self.assertEqual(settings['ldflags'], ['-fuse-ld=<(android_fuse_ld)'])
        self.assertNotIn("'-fuse-ld=bfd'", read('config', 'android-settings.gypi'))


# ---------------------------------------------------------------------------
# prebuilt/scripts/android.inc and build-openssl.sh


@unittest.skipUnless(BASH, 'needs bash (not on Windows)')
class PrebuiltToolchain(unittest.TestCase):
    """configureAndroidToolchain, which every prebuilt library's script
    builds with."""

    VARS = ('ANDROID_CC', 'ANDROID_CFLAGS', 'ANDROID_CXX', 'ANDROID_CXXFLAGS', 'ANDROID_LINK', 'ANDROID_LDFLAGS', 'ANDROID_AR',
            'ANDROID_OBJCOPY', 'ANDROID_RANLIB', 'ANDROID_STRIP', 'ANDROID_TOOLCHAIN_BASE', 'ANDROID_LLVM_BIN',
            'ANDROID_API', 'ANDROID_TRIPLE')

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.home = os.path.join(self.tmp, 'home')
        os.makedirs(self.home)
        self.ndk = fake_ndk(self.tmp)

    def configure(self, arch, ok=True, **env):
        script = ('source "$1"; configureAndroidToolchain "$2"; ' +
                  ' '.join('echo "%s=${%s}";' % (v, v) for v in self.VARS))
        environ = {'PATH': os.environ.get('PATH', ''), 'HOME': self.home, 'ANDROID_NDK': self.ndk}
        environ.update(env)
        p = subprocess.run([BASH, '-c', script, 'bash', os.path.join(REPO, 'prebuilt', 'scripts', 'android.inc'),
                            arch], env=environ, capture_output=True, text=True)
        if not ok:
            self.assertNotEqual(p.returncode, 0)
            return p.stderr
        self.assertEqual(p.returncode, 0, p.stderr)
        return dict(line.split('=', 1) for line in p.stdout.splitlines())

    def host(self):
        system = subprocess.run(['uname', '-s'], capture_output=True, text=True).stdout.strip()
        return 'darwin-x86_64' if system.startswith('Darwin') else 'linux-x86_64'

    def test_the_ndks_own_toolchain(self):
        bin_ = llvm_bin(self.ndk, self.host())
        v = self.configure('arm64')
        self.assertEqual(v['ANDROID_LLVM_BIN'], bin_)
        self.assertEqual(v['ANDROID_API'], '21')
        self.assertEqual(v['ANDROID_CC'], bin_ + '/clang')
        self.assertEqual(v['ANDROID_CXX'], bin_ + '/clang++')
        self.assertEqual(v['ANDROID_LINK'], bin_ + '/clang++')
        for name, tool in (('AR', 'llvm-ar'), ('OBJCOPY', 'llvm-objcopy'), ('RANLIB', 'llvm-ranlib'),
                           ('STRIP', 'llvm-strip')):
            self.assertEqual(v['ANDROID_' + name], bin_ + '/' + tool)
        self.assertEqual(v['ANDROID_TOOLCHAIN_BASE'], os.path.dirname(bin_))
        # position-independent code for what the shared libraries link
        for name in ('CFLAGS', 'CXXFLAGS'):
            self.assertEqual(v['ANDROID_' + name], '-target aarch64-linux-android21 -fPIC')
        self.assertEqual(v['ANDROID_LDFLAGS'], '-target aarch64-linux-android21')

    def test_each_architecture(self):
        cases = {
            'armv7': ('-target armv7a-linux-androideabi21 -mthumb', 'arm-linux-androideabi'),
            'arm64': ('-target aarch64-linux-android21', 'aarch64-linux-android'),
            'x86': ('-target i686-linux-android21 -march=i686', 'i686-linux-android'),
            'x86_64': ('-target x86_64-linux-android21', 'x86_64-linux-android'),
        }
        for arch, (flags, triple) in cases.items():
            with self.subTest(arch=arch):
                v = self.configure(arch)
                self.assertEqual(v['ANDROID_CFLAGS'], flags + ' -fPIC')
                self.assertEqual(v['ANDROID_CXXFLAGS'], flags + ' -fPIC')
                self.assertEqual(v['ANDROID_LDFLAGS'], flags)
                self.assertEqual(v['ANDROID_TRIPLE'], triple)    # ICU's --host

    def test_the_platform_version(self):
        v = self.configure('x86_64', ANDROID_NDK_PLATFORM_VERSION='26')
        self.assertEqual(v['ANDROID_API'], '26')
        self.assertEqual(v['ANDROID_CFLAGS'], '-target x86_64-linux-android26 -fPIC')

    def test_armv6_is_refused(self):
        self.assertIn('does not build for armv6', self.configure('armv6', ok=False))

    def test_a_standalone_toolchain_is_used_as_before(self):
        os.makedirs(os.path.join(self.home, 'android', 'toolchain', 'standalone-arm64'))
        v = self.configure('arm64')
        tc = os.path.join(self.home, 'android', 'toolchain', 'standalone-arm64', 'bin', 'aarch64-linux-android-')
        self.assertEqual(v['ANDROID_LLVM_BIN'], '')
        self.assertEqual(v['ANDROID_CC'], tc + 'clang')
        self.assertEqual(v['ANDROID_AR'], tc + 'ar')
        self.assertEqual(v['ANDROID_CFLAGS'], '-target aarch64-linux-android')
        self.assertEqual(v['ANDROID_CXXFLAGS'], '-target aarch64-linux-android')
        self.assertEqual(v['ANDROID_TOOLCHAIN_BASE'], os.path.join(self.home, 'android', 'toolchain',
                                                                   'standalone-arm64'))

    def test_a_named_toolchain_is_used_as_before(self):
        v = self.configure('armv7', ANDROID_TOOLCHAIN='/opt/arm/bin/arm-linux-androideabi-')
        self.assertEqual(v['ANDROID_LLVM_BIN'], '')
        self.assertEqual(v['ANDROID_CC'], '/opt/arm/bin/arm-linux-androideabi-clang')
        self.assertEqual(v['ANDROID_CFLAGS'], '-target arm-linux-androideabi -march=armv7a -mthumb')
        self.assertEqual(v['ANDROID_TOOLCHAIN_BASE'], '/opt/arm')

    def test_a_custom_toolchain_is_used_as_before(self):
        v = self.configure('arm64', OBJCOPY='objcopy', CC='my-cc', CXX='my-c++', LINK='my-link')
        self.assertEqual(v['ANDROID_LLVM_BIN'], '')
        self.assertEqual((v['ANDROID_CC'], v['ANDROID_CXX'], v['ANDROID_LINK']), ('my-cc', 'my-c++', 'my-link'))

    def test_an_old_ndk_names_the_standalone_toolchain_as_before(self):
        old = os.path.join(self.tmp, 'old-ndk')
        os.makedirs(old)
        v = self.configure('x86', ANDROID_NDK=old)
        self.assertEqual(v['ANDROID_LLVM_BIN'], '')
        self.assertEqual(v['ANDROID_CC'], os.path.join(self.home, 'android', 'toolchain', 'standalone-x86', 'bin',
                                                       'i686-linux-android-clang'))


def openssl_case():
    """buildOpenSSL's case on the platform (build-openssl.sh), the part that
    chooses OpenSSL's target and its environment."""
    text = read('prebuilt', 'scripts', 'build-openssl.sh')
    body = text[text.index('function buildOpenSSL'):]
    start = body.index('\tcase "${PLATFORM}" in')
    end = body.index('\n\tesac\n', start) + len('\n\tesac\n')
    return body[start:end]


@unittest.skipUnless(BASH, 'needs bash (not on Windows)')
class OpenSSLTarget(unittest.TestCase):
    """build-openssl.sh's Android targets, with configureAndroidToolchain
    standing in for android.inc's."""

    def run_case(self, arch, llvm_bin='/ndk/llvm/bin'):
        script = ('configureAndroidToolchain() { ANDROID_LLVM_BIN=%s; ANDROID_API=21; '
                  'ANDROID_TOOLCHAIN_BASE=/tc; }\n' % (llvm_bin or "''") +
                  'PLATFORM=android; ARCH=%s; ANDROID_NDK=/ndk; export CROSS_SYSROOT=/sysroot; '
                  'export ANDROID_NDK_HOME=/old; CFLAGS=; EXTRA_OPTIONS=\n' % arch +
                  openssl_case() +
                  'echo "SPEC=$SPEC"; echo "EXTRA=$EXTRA_OPTIONS"; echo "ROOT=${ANDROID_NDK_ROOT-unset}"; '
                  'echo "HOME=${ANDROID_NDK_HOME-unset}"; echo "SYSROOT=${CROSS_SYSROOT-unset}"; '
                  'echo "PATH1=${PATH%%:*}"; echo "CFLAGS=$CFLAGS"; echo "CC=$CONFIGURE_CC_FOR_TARGET"\n')
        p = subprocess.run([BASH, '-c', script], capture_output=True, text=True,
                           env={'PATH': os.environ.get('PATH', '')})
        return p.returncode, dict(line.split('=', 1) for line in p.stdout.splitlines() if '=' in line), p.stderr

    def test_the_ndks_own_toolchain(self):
        for arch, spec in (('arm64', 'android-arm64'), ('armv7', 'android-arm'), ('x86', 'android-x86'),
                           ('x86_64', 'android-x86_64')):
            with self.subTest(arch=arch):
                status, v, err = self.run_case(arch)
                self.assertEqual(status, 0, err)
                self.assertEqual(v['SPEC'], spec)
                self.assertEqual(v['EXTRA'], '-D__ANDROID_API__=21')
                self.assertEqual(v['ROOT'], '/ndk')
                self.assertEqual(v['HOME'], 'unset')
                self.assertEqual(v['SYSROOT'], 'unset')
                self.assertEqual(v['PATH1'], '/ndk/llvm/bin')
                self.assertEqual(v['CFLAGS'], '')      # no GNU assembler or bfd linker to ask for
                self.assertEqual(v['CC'], '0')

    def test_armv6_is_refused(self):
        status, _, err = self.run_case('armv6')
        self.assertNotEqual(status, 0)
        self.assertIn('no OpenSSL target for Android armv6', err)

    def test_a_standalone_toolchain_is_used_as_before(self):
        cases = (('arm64', 'android-arm64', '-fno-integrated-as', ''),
                 ('armv7', 'android-arm', '-fno-integrated-as', '-latomic'),
                 ('x86', 'android-x86', '-fuse-ld=bfd', ''),
                 ('x86_64', 'android-x86_64', '', ''))
        for arch, spec, cflags, extra in cases:
            with self.subTest(arch=arch):
                status, v, err = self.run_case(arch, llvm_bin=None)
                self.assertEqual(status, 0, err)
                self.assertEqual(v['SPEC'], spec)
                self.assertEqual(v['CFLAGS'], cflags)
                self.assertEqual(v['EXTRA'], extra)
                self.assertEqual(v['HOME'], '/tc')
                self.assertEqual(v['PATH1'], '/tc/bin')
                self.assertEqual(v['ROOT'], 'unset')
                self.assertEqual(v['SYSROOT'], '/sysroot')


# ---------------------------------------------------------------------------
# tools/ci/build-android.sh


def bash_assoc(text, name):
    """A bash associative array's [key]=value pairs (declare -A NAME=(...))."""
    m = re.search(r'declare -A %s=\((.*?)\)\n' % name, text, re.S)
    return dict(re.findall(r'\[([^\]]+)\]=(\S+)', m.group(1)))


def bash_array(text, name):
    m = re.search(r'^%s=\((.*?)\)\n' % name, text, re.S | re.M)
    return m.group(1).split()


class BuildScript(unittest.TestCase):
    """build-android.sh names what android_engine.py and android_java.py
    check, and what the gyp files build."""

    @classmethod
    def setUpClass(cls):
        cls.text = read('tools', 'ci', 'build-android.sh')

    def test_the_architectures(self):
        abis = bash_assoc(self.text, 'ABIS')
        self.assertEqual(abis, {'arm64': 'arm64-v8a', 'armv7': 'armeabi-v7a', 'x86_64': 'x86_64', 'x86': 'x86'})
        self.assertEqual(set(abis.values()), set(ae.ABIS))
        self.assertEqual(set(abis.values()), set(android_java.ABIS))

    def test_the_folder(self):
        self.assertEqual(set(bash_assoc(self.text, 'LIBRARIES').values()), {ae.ENGINE} | set(ae.EXTERNALS))
        self.assertEqual(set(bash_assoc(self.text, 'FILES').values()), set(ae.TOP_FILES))
        self.assertEqual(ae.ENGINE, android_java.ENGINE_NAME)

    def test_the_targets_make_the_libraries(self):
        """Each gyp target the script builds names, for Android, one of the
        products the script takes from the build folder."""
        targets = bash_array(self.text, 'ENGINE_TARGETS')
        products = set(bash_assoc(self.text, 'LIBRARIES'))
        found = set()
        gyps = ('engine/engine.gyp', 'revdb/revdb.gyp', 'revxml/revxml.gyp', 'revzip/revzip.gyp',
                'revpdfprinter/revpdfprinter.gyp', 'thirdparty/libopenssl/libopenssl.gyp')
        texts = dict((g, read(*g.split('/'))) for g in gyps)
        for target in targets:
            holders = [g for g, t in texts.items() if "'target_name': '%s'" % target in t]
            self.assertEqual(len(holders), 1, target)
            # (every target of that name: a gyp file can have one for each
            # platform, as libopenssl.gyp's revsecurity)
            text = texts[holders[0]]
            names = set()
            for m in re.finditer(r"'target_name': '%s'" % re.escape(target), text):
                nxt = text.find("'target_name':", m.end())
                block = text[m.start():nxt if nxt > 0 else len(text)]
                names |= set(re.findall(r"'product_name': '([^']+)'", block)) & products
            self.assertEqual(len(names), 1, '%s: %s' % (target, names))
            found |= names
        self.assertEqual(found, products)

    def test_the_lowest_android(self):
        self.assertEqual(re.search(r'^ANDROID_MIN_API=(\d+)$', self.text, re.M).group(1), str(ae.MIN_API))

    def test_the_ndk_version(self):
        version = read('config', 'android-ndk-version').strip()
        self.assertRegex(version, r'^\d+\.\d+\.\d+$')
        self.assertIn('config/android-ndk-version', self.text)
        # the libraries' folder: ndk<API>r<major>, as config/android.gypi's
        # android_subplatform names it from the same two variables
        self.assertIn('export ANDROID_NDK_VERSION="r${NDK_WANTED%%.*}"', self.text)
        self.assertIn('SUBPLATFORM="ndk${ANDROID_NDK_PLATFORM_VERSION}${ANDROID_NDK_VERSION}"', self.text)
        self.assertIn("'android_subplatform%': 'ndk<(android_ndk_platform_version)<(android_ndk_version)'",
                      read('config', 'android.gypi'))

    def test_the_libraries_it_builds(self):
        for lib in ('icu', 'thirdparty', 'openssl'):
            self.assertRegex(self.text, r'PREBUILT_BUILD_LIBS=%s \./build-libraries\.sh android "\$\{ARCH\}" '
                                        r'"\$\{SUBPLATFORM\}"' % lib)
        self.assertIn('export PREBUILT_SKIP_FETCH=1', self.text)
        # OpenSSL before the Thirdparty libraries, whose libmysql includes
        # OpenSSL's headers (as build-libraries.sh orders them: CI's first
        # run built them the other way round and failed on
        # openssl/opensslv.h)
        order = [self.text.index('PREBUILT_BUILD_LIBS=%s ./build-libraries.sh android' % lib)
                 for lib in ('icu', 'openssl', 'thirdparty')]
        self.assertEqual(order, sorted(order))
        self.assertIn('PREBUILT_LIBS="openssl icu thirdparty"', read('prebuilt', 'build-libraries.sh'))
        self.assertIn('Thirdparty_LIBS_android', self.text)

    def test_stripped_with_the_debug_information_kept(self):
        self.assertIn('llvm-strip" --strip-debug -o "${OUT}/${ABI}/', self.text)
        self.assertIn('cp "${FILE}" "${OUT}/debug/${ABI}/', self.text)

    @unittest.skipUnless(BASH and sys.platform.startswith('linux'), 'needs bash 4 on Linux')
    def test_arguments(self):
        script = os.path.join(REPO, 'tools', 'ci', 'build-android.sh')
        p = subprocess.run([BASH, script], capture_output=True, text=True)
        self.assertEqual(p.returncode, 2)
        self.assertIn('usage:', p.stderr)
        p = subprocess.run([BASH, script, 'mips', '--libraries'], capture_output=True, text=True)
        self.assertEqual(p.returncode, 1)
        self.assertIn('no Android architecture mips', p.stderr)
        with tempfile.TemporaryDirectory() as tmp:
            touch(os.path.join(tmp, 'out', 'old'))
            p = subprocess.run([BASH, script, 'arm64', os.path.join(tmp, 'out')], capture_output=True, text=True)
            self.assertEqual(p.returncode, 1)
            self.assertIn('exists and is not empty', p.stderr)


# ---------------------------------------------------------------------------
# The assembly the Android build compiles (libffi's), which an NDK from r24
# on reads only with Clang's integrated assembler: it has no GNU as, which
# took the old VFP mnemonics that CI's first ARMv7 build stopped on


ANDROID_ARCHS = ('armv7', 'arm64', 'x86', 'x86_64')

# A load or store of several VFP registers written in the syntax before the
# unified one (fldmiad, fstmiadeq, fstmfdd, ...): the integrated assembler
# knows none of them (vldmia, vstmia, vstmdb, vpush and vpop are the same
# instructions)
OLD_VFP_MULTIPLE = re.compile(r'^\s*(?:[\w.$]+:\s*)?(f(?:ld|st)m\w*)\b', re.M | re.I)

# The lines CI's first ARMv7 build stopped on (sysv.S lines 365, 414, 425,
# 475 and 478), and what they are now
OLD_VFP_LINES = ('\tfldmiadgt\tip, {d0-d7}', '\tfstmiadeq\tr2, {d0-d3}', '\tfstmfdd\tsp!, {d0-d7}',
                 '\tfldmiad\tsp, {d0-d1}', '\tfldmiad\tsp, {d0-d3}')
UAL_VFP_LINES = ('\tvldmiagt\tip, {d0-d7}', '\tvstmiaeq\tr2, {d0-d3}', '\tvstmdb\tsp!, {d0-d7}',
                 '\tvldmia\tsp, {d0-d1}', '\tvldmia\tsp, {d0-d3}')


def strip_asm_comments(text):
    """An assembly file without its C and @ comments (the preprocessor's
    and GNU as's ARM ones), so that a mnemonic in prose is not taken for
    an instruction."""
    text = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), text, flags=re.S)
    return re.sub(r'(?://|@).*', '', text)


def libffi_android_sources(arch):
    """What libffi.gyp compiles for Android on an architecture, from its
    own conditions (Python expressions, as gyp reads them): the include
    folder and the assembly files, relative to thirdparty/libffi."""
    text = read('thirdparty', 'libffi', 'libffi.gyp')
    found = []
    for m in re.finditer(r"\[\s*'([^']*)',\s*\{\s*'platform_include_dirs':\s*\[\s*'<@\((\w+)\)',?\s*\],"
                         r"\s*'sources':\s*\[\s*'<@\((\w+)\)'", text, re.S):
        if eval(m.group(1), {'__builtins__': {}}, {'toolset_os': 'android', 'toolset_arch': arch}):
            found.append(m.groups()[1:])
    assert len(found) == 1, (arch, found)
    def listed(name):
        block = re.search(r"'%s':\s*\[(.*?)\]" % name, text, re.S).group(1)
        return re.findall(r"'([^']+)'", block)
    include = listed(found[0][0])
    assert len(include) == 1, include
    return include[0], [s for s in listed(found[0][1]) if s.endswith('.S')]


def android_clang_flags(arch):
    """The compiler flags config.py gives the gyp build, which compiles
    libffi, for an architecture at the lowest Android the build targets."""
    march = CONFIG.guess_android_march(arch)
    return (['-target', CONFIG.ndk_clang_target(arch, str(ae.MIN_API))] +
            (['-march=' + march] if march else []) +
            CONFIG.android_extra_cflags(arch).split() + ['-Qunused-arguments', '-fintegrated-as'])


def clang_targets():
    """The architectures this host's clang can assemble for (none without
    a clang: the NDK's is the same compiler, with every target)."""
    clang = shutil.which('clang')
    if not clang:
        return clang, ()
    ok = []
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, 'probe.S')
        touch(src, b'\t.text\n')
        for arch in ANDROID_ARCHS:
            p = subprocess.run([clang] + android_clang_flags(arch) + ['-c', src, '-o', os.path.join(tmp, 'p.o')],
                               capture_output=True)
            if p.returncode == 0:
                ok.append(arch)
    return clang, tuple(ok)


class AndroidAssembly(unittest.TestCase):
    """libffi's assembly for each Android architecture is what Clang's
    integrated assembler reads."""

    @classmethod
    def setUpClass(cls):
        cls.clang, cls.targets = clang_targets()

    def test_the_sources(self):
        """What the gyp file builds for each architecture: the ARM files
        among them (so that the checks below have something to look at),
        and each file there."""
        self.assertEqual(libffi_android_sources('armv7'), ('./include_android', ['src/arm/sysv.S', 'src/arm/trampoline.S']))
        self.assertEqual(libffi_android_sources('arm64'), ('./include_linux/arm64', ['src/aarch64/sysv.S']))
        for arch in ANDROID_ARCHS:
            include, sources = libffi_android_sources(arch)
            self.assertTrue(sources, arch)
            self.assertTrue(os.path.isdir(os.path.join(REPO, 'thirdparty', 'libffi', include)), include)
            for source in sources:
                self.assertTrue(os.path.isfile(os.path.join(REPO, 'thirdparty', 'libffi', source)), source)

    def test_the_old_mnemonics_are_found(self):
        """The check below finds each line CI's ARMv7 build stopped on, and
        none of what they are now, or of a comment naming them."""
        for line in OLD_VFP_LINES:
            self.assertTrue(OLD_VFP_MULTIPLE.search(strip_asm_comments(line + '\n')), line)
            self.assertTrue(OLD_VFP_MULTIPLE.search(strip_asm_comments('label:' + line + '\n')), line)
        for line in UAL_VFP_LINES + ('\t@ was fldmiad', '/* fstmfdd */', '\tvpush\t{d8}', '\tfldd\td0, [ip]'):
            self.assertFalse(OLD_VFP_MULTIPLE.search(strip_asm_comments(line + '\n')), line)

    def test_no_old_vfp_multiple(self):
        for source in libffi_android_sources('armv7')[1]:
            text = strip_asm_comments(read('thirdparty', 'libffi', *source.split('/')))
            self.assertEqual([m.group(1) for m in OLD_VFP_MULTIPLE.finditer(text)], [], source)
        # what CI's ARMv7 build stopped on is gone, and is written so
        sysv = read('thirdparty', 'libffi', 'src', 'arm', 'sysv.S')
        for old, new in zip(OLD_VFP_LINES, UAL_VFP_LINES):
            self.assertNotIn(old + '\n', sysv)
            self.assertIn(new + '\n', sysv)
        # a local change to vendored code, marked and recorded as the others
        self.assertIn('@ OXT-Beyond:', sysv)
        self.assertIn('src/arm/sysv.S', read('thirdparty', 'libffi', 'ORIGIN'))
        self.assertIn('[`thirdparty/libffi/ORIGIN`](thirdparty/libffi/ORIGIN)', read('THIRD-PARTY-NOTICES.md'))

    def assemble(self, arch, text):
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, 'case.S')
            touch(src, text.encode('ascii'))
            return subprocess.run([self.clang] + android_clang_flags(arch) +
                                  ['-c', src, '-o', os.path.join(tmp, 'case.o')], capture_output=True, text=True)

    def test_clang_refuses_the_old_mnemonics(self):
        """The check below would have caught what CI's ARMv7 build stopped
        on: the integrated assembler refuses each old line, and takes what
        it is now, with the VFP directive sysv.S has."""
        if 'armv7' not in self.targets:
            self.skipTest('no clang here that assembles for ARMv7')
        head = '\t.syntax unified\n\t.arm\n\t.fpu\tvfp\n'
        for old, new in zip(OLD_VFP_LINES, UAL_VFP_LINES):
            p = self.assemble('armv7', head + old + '\n')
            self.assertNotEqual(p.returncode, 0, old)
            self.assertIn('invalid instruction', p.stderr)
            p = self.assemble('armv7', head + new + '\n')
            self.assertEqual(p.returncode, 0, p.stderr)

    def test_clang_assembles_them(self):
        """Each assembly file of each architecture, as the gyp build
        compiles it: its include folders and config.py's flags."""
        if not self.targets:
            self.skipTest('no clang here that assembles for Android')
        for arch in self.targets:
            include, sources = libffi_android_sources(arch)
            for source in sources:
                with self.subTest(arch=arch, source=source), tempfile.TemporaryDirectory() as tmp:
                    path = os.path.join(REPO, 'thirdparty', 'libffi', *source.split('/'))
                    p = subprocess.run([self.clang] + android_clang_flags(arch) +
                                       ['-DFFI_BUILDING', '-I', os.path.join(REPO, 'thirdparty', 'libffi', include),
                                        '-I', os.path.dirname(path), '-c', path, '-o', os.path.join(tmp, 'out.o')],
                                       capture_output=True, text=True)
                    self.assertEqual(p.returncode, 0, p.stderr)


# ---------------------------------------------------------------------------
# What a current Clang and the NDK's current headers refuse in the sources
# the Android build compiles, which NDK r15 took: found with a Clang of the
# same family on x86 (and, for libffi, in CI's third x86 build)


def c_functions(text, return_type):
    """(name, body) of each function defined at the top level with this
    return type, its body up to the closing brace in the first column."""
    for m in re.finditer(r'^%s\s+([\w:]+)\s*\([^;{]*?\)\s*\{(.*?)^\}' % re.escape(return_type), text, re.M | re.S):
        yield m.group(1), m.group(2)


class NewerCompiler(unittest.TestCase):

    def test_ffi_call_sysv_takes_what_it_is_given(self):
        """x86's ffi_call_SYSV is declared to take the function its callers
        pass (ffi_prep_args and ffi_prep_args_raw, which return unsigned
        int): Clang from 16 on refuses the mismatch with the void it said."""
        text = read('thirdparty', 'libffi', 'src', 'x86', 'ffi.c')
        decl = re.search(r'extern void ffi_call_SYSV\(([\w ]+\(\*\)\([^)]*\)),', text)
        self.assertIsNotNone(decl)
        param = decl.group(1).replace(' ', '')
        for name in ('ffi_prep_args', 'ffi_prep_args_raw'):
            self.assertRegex(text, r'\n(?:static\s+)?unsigned int\s*\n?%s\s*\(char \*stack, extended_cif \*ecif\)' % name)
            self.assertRegex(text, r'ffi_call_SYSV\(%s,' % name)
        self.assertEqual(param, 'unsignedint(*)(char*,extended_cif*)')
        # as ffi_call_win32 has always said
        self.assertIn('ffi_call_win32(unsigned int (*)(char *, extended_cif *)', text)
        self.assertIn('/* OXT-Beyond:', text[:decl.start()][-600:])
        self.assertIn('src/x86/ffi.c', read('thirdparty', 'libffi', 'ORIGIN'))

    def ffi_call_sysv_case(self, declaration):
        """A C file that calls ffi_call_SYSV as ffi.c does, with ffi.c's
        declaration of it and of what its callers pass."""
        return ('typedef struct extended_cif extended_cif;\n'
                'unsigned int ffi_prep_args(char *stack, extended_cif *ecif);\n'
                'unsigned int ffi_prep_args_raw(char *stack, extended_cif *ecif);\n' + declaration + '\n'
                'void call(extended_cif *e, unsigned *r, void (*fn)(void))\n'
                '{\n\tffi_call_SYSV(ffi_prep_args, e, 0, 0, r, fn);\n'
                '\tffi_call_SYSV(ffi_prep_args_raw, e, 0, 0, r, fn);\n}\n')

    def test_a_compiler_takes_the_call(self):
        """What the NDK's Clang refused, compiled: the old declaration is an
        error where the mismatch is (Clang 16 and later make it one by
        default), and ffi.c's own is not."""
        clang = shutil.which('clang')
        if not clang:
            self.skipTest('no clang here')
        text = read('thirdparty', 'libffi', 'src', 'x86', 'ffi.c')
        declaration = re.search(r'extern void ffi_call_SYSV\(.*?\);', text, re.S).group(0)
        old = declaration.replace('unsigned int (*)(char *, extended_cif *)', 'void (*)(char *, extended_cif *)')
        self.assertNotEqual(old, declaration)
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, 'case.c')
            def compile_it(decl):
                touch(src, self.ffi_call_sysv_case(decl).encode('ascii'))
                return subprocess.run([clang, '-fsyntax-only', '-Werror=incompatible-function-pointer-types',
                                       '-Werror=incompatible-pointer-types', src], capture_output=True, text=True)
            p = compile_it(old)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn('incompatible', p.stderr)
            p = compile_it(declaration)
            self.assertEqual(p.returncode, 0, p.stderr)

    def test_android_bool_functions_return_bools(self):
        """No Android engine function that returns bool returns nil, which
        is nullptr in C++: a current Clang refuses it (popupaskdialog did)."""
        found = []
        for name in sorted(os.listdir(os.path.join(REPO, 'engine', 'src'))):
            if 'android' in name and name.endswith('.cpp'):
                for func, body in c_functions(read('engine', 'src', name), 'bool'):
                    if re.search(r'\breturn\s+nil\s*;', body):
                        found.append('%s: %s' % (name, func))
        self.assertEqual(found, [])
        dialog = dict(c_functions(read('engine', 'src', 'mblandroiddialog.cpp'), 'bool'))
        self.assertIn('MCScreenDC::popupaskdialog', dialog)
        self.assertIn('return false;', dialog['MCScreenDC::popupaskdialog'])

    def test_the_finder_sees_a_nil_return(self):
        text = 'bool f(int x)\n{\n\tif (x)\n\t\treturn nil;\n\treturn true;\n}\n'
        self.assertEqual([(n, bool(re.search(r'\breturn\s+nil\s*;', b))) for n, b in c_functions(text, 'bool')],
                         [('f', True)])

    def test_skia_arm_multiply(self):
        """Skia's 32-bit ARM SkFixedMul is the portable product, with no
        smull of its own (Clang refused one with both halves in a register);
        the change is marked and recorded."""
        text = read('thirdparty', 'libskia', 'include', 'private', 'SkFixed.h')
        arm = text[text.index('#if defined(SK_CPU_ARM32)'):]
        arm = arm[:arm.index('#endif')]
        self.assertNotIn('smull', re.sub(r'/\*.*?\*/', '', arm, flags=re.S))
        body = re.search(r'inline SkFixed SkFixedMul_arm\(SkFixed x, SkFixed y\)\s*\{(.*?)\}', arm, re.S).group(1)
        self.assertEqual(body.split(), ['return', 'SkFixedMul_longlong(x,', 'y);'])
        self.assertIn('#define SkFixedMul(x, y)        SkFixedMul_arm(x, y)', arm)
        self.assertIn('/* OXT-Beyond:', arm)
        self.assertIn('return (SkFixed)((int64_t)a * b >> 16);', text)
        self.assertIn('include/private/SkFixed.h', read('thirdparty', 'libskia', 'ORIGIN'))
        self.assertIn('[`thirdparty/libskia/ORIGIN`](thirdparty/libskia/ORIGIN)', read('THIRD-PARTY-NOTICES.md'))

    def test_the_two_products_agree(self):
        """What the assembly worked out (the low word shifted right 16, the
        high word's low 16 bits above it) is the portable product, bits 16
        to 47 of the 64-bit product, for every pair of inputs: these, the
        edges and a spread between them."""
        def s32(v):
            v &= 0xffffffff
            return v - (1 << 32) if v & 0x80000000 else v

        def assembly(x, y):
            p = (x * y) & 0xffffffffffffffff      # smull: RdLo, RdHi
            lo, hi = p & 0xffffffff, p >> 32
            return s32((lo >> 16) | (hi << 16))   # lsr #16, then orr lsl #16

        def portable(x, y):
            return s32((x * y) >> 16)             # (int64_t)a * b >> 16, as SkFixed

        edges = [-2 ** 31, -2 ** 31 + 1, -65536, -65535, -1, 0, 1, 65535, 65536, 2 ** 31 - 1]
        spread = [s32(i * 0x9E3779B1) for i in range(1, 400)]
        for x in edges + spread:
            for y in edges + spread[:40]:
                self.assertEqual(assembly(x, y), portable(x, y), (x, y))

    def test_64_bit_stdio_offsets_where_there_are_some(self):
        """libFoundation's stdio streams ask for 64-bit file offsets except on
        32-bit Android below API 24, where bionic has no fseeko64 and
        ftello64 and a current NDK then declares no fseeko or ftello (CI's
        armv7 build stopped there): such a build keeps the 32-bit ones, as
        NDK r15's headers gave it. The #if is evaluated as the preprocessor
        would, for each kind of build."""
        text = read('libfoundation', 'src', 'system-stream.cpp')
        m = re.search(r'^#if (.*?)\n#define _FILE_OFFSET_BITS 64\n#endif\n', text, re.M | re.S)
        self.assertIsNotNone(m, 'the request is guarded')
        self.assertEqual(len(re.findall(r'_FILE_OFFSET_BITS 64', text)), 1)
        self.assertLess(m.end(), text.index('#include'), 'before any header')
        self.assertIn('fseeko (t_stream', text)
        self.assertIn('ftello (t_stream)', text)
        condition = m.group(1).replace('\\\n', ' ')

        def holds(**macros):
            expr = re.sub(r'defined\((\w+)\)', lambda d: str(d.group(1) in macros), condition)
            expr = re.sub(r'\b__\w+__\b', lambda n: str(macros.get(n.group(0), 0)), expr)
            expr = expr.replace('&&', ' and ').replace('||', ' or ')
            expr = re.sub(r'!(?!=)', ' not ', expr)
            return eval(expr, {'__builtins__': {}})

        self.assertTrue(holds(__linux__=1, __LP64__=1))                 # Linux, macOS
        self.assertTrue(holds(__linux__=1))                             # 32-bit Linux
        self.assertTrue(holds(__ANDROID__=1, __LP64__=1, __ANDROID_MIN_SDK_VERSION__=21))
        self.assertFalse(holds(__ANDROID__=1, __ANDROID_MIN_SDK_VERSION__=21))
        self.assertFalse(holds(__ANDROID__=1, __ANDROID_MIN_SDK_VERSION__=23))
        self.assertTrue(holds(__ANDROID__=1, __ANDROID_MIN_SDK_VERSION__=24))
        self.assertFalse(holds(__ANDROID__=1))                          # a standalone toolchain's Clang
        self.assertTrue(holds(__ANDROID__=1, __LP64__=1))

    def test_posix_headers_for_what_they_declare(self):
        """PATH_MAX and gettimeofday come from where POSIX puts them, not
        from whichever header brought them in with NDK r15's headers."""
        fs = read('libcore', 'src', 'filesystem.cpp')
        self.assertLess(fs.index('#include <limits.h>'), fs.index('char t_path[PATH_MAX];'))
        process = read('engine', 'src', 'mblandroidprocess.cpp')
        self.assertLess(process.index('#include <sys/time.h>'), process.index('gettimeofday('))


# ---------------------------------------------------------------------------
# C++17 for what includes ICU's headers, which ICU 75 and later need: an
# Android build merges its settings, -std=c++11 among them, after a target's
# own (as a web build does), so the targets ask for C++17 again there. CI's
# third arm64 build stopped on hb-icu.cc and ICU 78's char16ptr.h for want
# of it.


def gyp(*path):
    import ast
    # gyp files are Python 2 literals, where an escape such as engine-
    # sources.gypi's '\.' is the two characters it is in Python 3, which
    # warns about it from 3.12 on
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', SyntaxWarning)
        return ast.literal_eval(read(*path))


def gyp_target(data, name):
    found = [t for t in data['targets'] if t['target_name'] == name]
    assert len(found) == 1, name
    return found[0]


def late_cflags_cc(target, **names):
    """The C++ flags a target's target_conditions add where their condition
    holds (gyp's conditions are Python expressions), in order."""
    flags = []
    for entry in target.get('target_conditions', []):
        cond, then = entry[0], entry[1]
        other = entry[2] if len(entry) > 2 else {}
        try:
            holds = eval(cond, {'__builtins__': {}}, names)
        except NameError:
            continue
        flags += (then if holds else other).get('cflags_cc', [])
    return flags


class AndroidCxxStandard(unittest.TestCase):

    def test_android_merges_its_settings_late(self):
        """Why the targets need the flag again: config/android.gypi brings in
        android-settings.gypi (the target) and linux-settings.gypi (the
        host) in target_conditions, after a target's own flags, and both say
        -std=<(c++_std), C++11 unless CXX_STD says otherwise."""
        conds = gyp('config', 'android.gypi')['target_defaults']['target_conditions']
        self.assertEqual([(c[0], c[1]['includes'], c[2]['includes']) for c in conds],
                         [('_toolset == "host"', ['linux-settings.gypi'], ['android-settings.gypi'])])
        for name in ('android-settings.gypi', 'linux-settings.gypi'):
            settings = gyp('config', name)
            self.assertEqual(settings['variables']['c++_std'], '<!(echo ${CXX_STD:-c++11})', name)
            self.assertIn('-std=<(c++_std)', settings['cflags_cc'], name)

    def test_libfoundation(self):
        target = gyp_target(gyp('libfoundation', 'libfoundation.gyp'), 'libFoundation')
        self.assertIn('-std=c++17', target['cflags_cc'])
        for toolset in ('target', 'host'):
            self.assertEqual(late_cflags_cc(target, OS='android', toolset_os='android', _toolset=toolset),
                             ['-std=c++17'], toolset)
        self.assertEqual(late_cflags_cc(target, OS='emscripten', toolset_os='emscripten', _toolset='target'),
                         ['-std=c++17'])
        # a desktop build merges its settings first, and keeps the target's
        for os_name in ('linux', 'mac', 'win'):
            self.assertEqual(late_cflags_cc(target, OS=os_name, toolset_os=os_name, _toolset='target'), [], os_name)

    def test_libharfbuzz(self):
        target = gyp_target(gyp('thirdparty', 'libharfbuzz', 'libharfbuzz.gyp'), 'libharfbuzz')
        self.assertIn('src/hb-icu.cc', target['sources'])
        for os_name in ('android', 'emscripten'):
            self.assertEqual(late_cflags_cc(target, toolset_os=os_name, _toolset='target'), ['-std=c++17'], os_name)
        self.assertEqual(late_cflags_cc(target, toolset_os='linux', _toolset='target'), [])

    def test_position_independent_code(self):
        """Everything an Android build compiles is position-independent, as
        it all ends up in shared libraries (lld refuses the NDK's default
        PIE code there): the gyp settings of the target, as a Linux build's
        say for its own."""
        for name in ('android-settings.gypi', 'linux-settings.gypi'):
            self.assertIn('-fPIC', gyp('config', name)['cflags'], name)

    def test_icu_needs_it(self):
        """The ICU the build uses is one that needs C++17 for its headers."""
        version = read('prebuilt', 'versions', 'icu').strip()
        self.assertRegex(version, r'^\d+\.\d+$')
        self.assertGreaterEqual(int(version.split('.')[0]), 75)


# ---------------------------------------------------------------------------
# The C++ library: with a current NDK (lld) every library links it into
# itself, from LINK's -static-libstdc++ (config.py), and no gyp file adds
# -lstdc++, which there named the NDK's libc++_shared.so, a library Android
# does not have: CI's first whole arm64 build asked for it in the engine and
# every external, through config/android-settings.gypi and ICU's link
# flags. A standalone toolchain keeps -lstdc++ where it had it.


def condition_branches(entry, names):
    """The branches of a gyp condition ([cond, then, cond, then, ..., else])
    that can apply where `names` hold; a condition that names anything else
    could go either way."""
    branches = []
    i = 0
    while i < len(entry):
        if not isinstance(entry[i], str):  # the else
            branches.append(entry[i])
            break
        try:
            holds = eval(entry[i], {'__builtins__': {}}, names)
        except NameError:
            branches.append(entry[i + 1])
        else:
            if holds:
                branches.append(entry[i + 1])
                break
        i += 2
    return branches


def gyp_link_flags(node, names, wanted):
    """Every flag of `wanted` a gyp tree can put in link flags (ldflags,
    libraries) where `names` hold, in its order: a branch's own flags, then
    its nested conditions', as gyp merges them."""
    found = []
    if isinstance(node, list):
        for item in node:
            found += gyp_link_flags(item, names, wanted)
    elif isinstance(node, dict):
        nested = []
        for key, value in node.items():
            if key in ('conditions', 'target_conditions'):
                nested += [b for entry in value for b in condition_branches(entry, names)]
            elif key.rstrip('!/+=') in ('ldflags', 'libraries'):
                found += [flag for flag in value if flag in wanted]
            else:
                found += gyp_link_flags(value, names, wanted)
        for branch in nested:
            found += gyp_link_flags(branch, names, wanted)
    return found


def gyp_lists(node, names, keys):
    """Every item a gyp tree can put in the lists named `keys` (sources, say)
    where `names` hold, in order, as gyp_link_flags walks it."""
    found = []
    if isinstance(node, list):
        for item in node:
            found += gyp_lists(item, names, keys)
    elif isinstance(node, dict):
        nested = []
        for key, value in node.items():
            if key in ('conditions', 'target_conditions'):
                nested += [b for entry in value for b in condition_branches(entry, names)]
            elif key.rstrip('!/+=') in keys:
                found += list(value)
            else:
                found += gyp_lists(value, names, keys)
        for branch in nested:
            found += gyp_lists(branch, names, keys)
    return found


def gyp_files():
    """Every gyp file of the tree (not gyp's own tests, nor a build's)."""
    found = []
    for top, dirs, files in os.walk(REPO):
        rel = os.path.relpath(top, REPO)
        dirs[:] = sorted(d for d in dirs if not d.startswith(('.', 'build-'))
                         and not (rel == '.' and d in ('gyp', '_cache')))
        found += [os.path.join(rel, f) for f in sorted(files) if f.endswith(('.gyp', '.gypi'))]
    return found


def find_python2():
    """A Python 2, which the tree's gyp needs (config.py runs it), or None."""
    for name in ('python2', 'python2.7', 'python'):
        path = shutil.which(name)
        if path and subprocess.run([path, '-c', 'import sys; sys.exit(sys.version_info[0] != 2)'],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            return path
    return None


PYTHON2 = find_python2()

# An Android library's target, and the two routes config.py takes
ANDROID_TARGET = dict(OS='android', toolset_os='android', _toolset='target', host_os='linux',
                      cross_compile=1, mobile=1, GENERATOR='make', _type='loadable_module')
CXX_LIBRARY_FLAGS = ('-lstdc++', '-lc++', '-lc++_shared', '-lgnustl_shared', '-lc++_static')


class CxxLibrary(unittest.TestCase):

    def flags(self, path, linker, **names):
        return gyp_link_flags(gyp(*path.split('/')), dict(ANDROID_TARGET, android_fuse_ld=linker, **names),
                              CXX_LIBRARY_FLAGS)

    def test_no_gyp_file_names_one_with_a_current_ndk(self):
        """Every gyp file in the tree, every branch that could apply to an
        Android library's target with lld: none names a C++ library."""
        files = gyp_files()
        self.assertIn(os.path.join('config', 'android-settings.gypi'), files)
        self.assertGreater(len(files), 50)
        named = {}
        for path in files:
            flags = self.flags(path.replace(os.sep, '/'), 'lld')
            if flags:
                named[path] = flags
        self.assertEqual(named, {})

    def test_a_standalone_toolchain_keeps_it(self):
        """With a standalone toolchain (bfd, or a linker set by hand) the two
        places that gave -lstdc++ give it still, and nothing else does."""
        for linker in ('bfd', 'gold'):
            named = {}
            for path in gyp_files():
                path = path.replace(os.sep, '/')
                flags = self.flags(path, linker)
                if flags:
                    named[path] = flags
            self.assertEqual(named, {'config/android-settings.gypi': ['-lstdc++'],
                                     'prebuilt/libicu.gyp': ['-lstdc++']}, linker)

    def test_the_settings_in_order(self):
        """android-settings.gypi's link flags for a library, as before but
        for -lstdc++ with lld, and none for a static library."""
        settings = gyp('config', 'android-settings.gypi')
        every = ('<(android_lib_path)', '-lstdc++', '-landroid')
        for linker, wanted in (('lld', ['<(android_lib_path)', '-landroid']),
                               ('bfd', list(every)), ('gold', list(every))):
            self.assertEqual(gyp_link_flags(settings, dict(ANDROID_TARGET, android_fuse_ld=linker), every),
                             wanted, linker)
            self.assertEqual(gyp_link_flags(settings, dict(ANDROID_TARGET, android_fuse_ld=linker,
                                                           _type='static_library'), every),
                             [], linker)

    def test_icu_in_order(self):
        """ICU's link flags for an Android target, as before but for
        -lstdc++ with lld."""
        link = gyp_target(gyp('prebuilt', 'libicu.gyp'), 'libicu_link')
        every = ('-licui18n', '-licuio', '-licuuc', '-licudata', '-lstdc++', '-lm', '-latomic')
        for linker, wanted in (('lld', [f for f in every if f != '-lstdc++']), ('bfd', list(every))):
            self.assertEqual(gyp_link_flags(link, dict(ANDROID_TARGET, android_fuse_ld=linker), every),
                             wanted, linker)

    def test_the_route_that_picks_lld_links_it_in(self):
        """lld is the linker of the route whose LINK says -static-libstdc++
        (ConfigToolchain runs config.py on both routes), and the check of a built
        engine refuses libc++_shared.so."""
        text = read('config.py')
        self.assertIn("'bfd' if llvm_bin is None else 'lld'", text)
        self.assertIn("'-target {} {} -fuse-ld=lld -static-libstdc++ {}'", text)
        self.assertNotIn('libc++_shared.so', ae.SYSTEM_LIBRARIES)
        self.assertIn('never libc++_shared.so', read('tools', 'ci', 'android_engine.py'))

    @unittest.skipUnless(PYTHON2, "needs a Python 2 (gyp's)")
    def test_gyp_says_the_same(self):
        """gyp itself, on a loadable module and a static library given the
        settings as config/android.gypi gives them (its linker variable
        included): the link flags for each linker are the ones above."""
        with tempfile.TemporaryDirectory() as tmp:
            shutil.copy(os.path.join(REPO, 'config', 'android-settings.gypi'), tmp)
            with open(os.path.join(tmp, 'lib.c'), 'w'):
                pass
            fuse_ld = gyp('config', 'android.gypi')['variables']['android_fuse_ld%']
            with open(os.path.join(tmp, 't.gyp'), 'w') as f:
                f.write(repr({
                    'variables': {'android_fuse_ld%': fuse_ld},
                    'target_defaults': {
                        'variables': {'silence_warnings': 0},
                        'target_conditions': [
                            ['_toolset == "host"', {}, {'includes': ['android-settings.gypi']}],
                        ],
                    },
                    'targets': [
                        {'target_name': 'Lib', 'type': 'loadable_module', 'sources': ['lib.c']},
                        {'target_name': 'Static', 'type': 'static_library', 'sources': ['lib.c']},
                    ],
                }))
            run = ('import sys; sys.path.insert(0, sys.argv[1]); import gyp; '
                   'sys.exit(gyp.main(sys.argv[2:]))')
            for linker, wanted in (('lld', ['-L/libs', '-landroid']),
                                   ('bfd', ['-L/libs', '-lstdc++', '-landroid'])):
                env = dict(os.environ, ANDROID_FUSE_LD=linker, ANDROID_LIB_PATH='/libs')
                env.pop('CXX_STD', None)
                out = 'out-' + linker
                subprocess.run([PYTHON2, '-c', run, os.path.join(REPO, 'gyp', 'pylib'),
                                '--depth=.', '-f', 'make', '--generator-output=' + out, 't.gyp'],
                               cwd=tmp, env=env, check=True, stdout=subprocess.DEVNULL)

                def ldflags(target):
                    with open(os.path.join(tmp, out, target + '.target.mk')) as f:
                        text = f.read()
                    block = re.search(r'^LDFLAGS_Release := \\\n((?:\t.*\n)*)', text, re.M)
                    return [line.strip().rstrip(' \\') for line in block.group(1).splitlines()]
                self.assertEqual(ldflags('Lib'), ['-fuse-ld=' + linker] + wanted, linker)
                self.assertEqual(ldflags('Static'), ['-fuse-ld=' + linker], linker)


# ---------------------------------------------------------------------------
# The AIDL interfaces: compiled from the Java kept beside each .aidl file
# (LiveCode's own aidl output), as android_java.py builds the Java layer;
# CI's fourth x86 build stopped on the aidl of build tools 36, which wants
# a file's folder among its import paths, spelled alike.


def aidl_methods(text):
    """The names of the methods an .aidl interface declares."""
    body = re.sub(r'/\*.*?\*/|//[^\n]*', '', text, flags=re.S)
    body = body[body.index('{') + 1:body.rindex('}')]
    return re.findall(r'(\w+)\s*\(', body)


class AidlInterfaces(unittest.TestCase):

    def kernel_java_sources(self):
        target = gyp_target(gyp('engine', 'kernel.gyp'), 'kernel-java')
        android = [c[1] for c in target['conditions'] if c[0] == 'OS == "android"']
        self.assertEqual(len(android), 1)
        return android[0]['sources']

    def test_kernel_java_compiles_the_java_beside_each(self):
        sources = self.kernel_java_sources()
        self.assertEqual(sources[-1], '<@(engine_java_source_files)')
        # no .aidl for the aidl rule, and nothing aidl would have written
        self.assertNotIn('<@(engine_aidl_source_files)', sources)
        for entry in sources:
            self.assertNotIn('INTERMEDIATE_DIR', entry)
            self.assertNotIn('intermediate_dir', entry)
        self.assertEqual(len(sources), 2)
        command = sources[0]
        self.assertTrue(command.startswith('<!@(') and command.endswith(')'), command)
        if not BASH:
            self.skipTest('no sh here to run what gyp runs')
        # what gyp runs: the list in place of its name, words of the output
        _, aidls = android_java.java_sources()
        script = command[len('<!@('):-1].replace('<@(engine_aidl_source_files)', ' '.join(aidls))
        out = subprocess.run(['sh', '-c', script], cwd=os.path.join(REPO, 'engine'),
                             capture_output=True, text=True, check=True).stdout.split()
        self.assertEqual(out, [os.path.splitext(x)[0] + '.java' for x in aidls])
        for x in out:
            self.assertTrue(os.path.isfile(os.path.join(REPO, 'engine', x)), x)

    def test_the_java_is_the_interface(self):
        """Each .java beside an .aidl is that interface, as aidl writes one:
        its package, an IInterface, a Stub, and each method."""
        _, aidls = android_java.java_sources()
        self.assertEqual(len(aidls), 4)
        for x in aidls:
            aidl = read('engine', *x.split('/'))
            java = read('engine', *(os.path.splitext(x)[0] + '.java').split('/'))
            name = os.path.splitext(os.path.basename(x))[0]
            package = re.search(r'^package\s+([\w.]+);', aidl, re.M).group(1)
            self.assertRegex(java, r'(?m)^package %s;' % re.escape(package))
            self.assertIn('public interface %s extends android.os.IInterface' % name, java)
            self.assertIn('public static abstract class Stub extends android.os.Binder implements %s.%s'
                          % (package, name), java)
            methods = aidl_methods(aidl)
            self.assertTrue(methods, x)
            for method in methods:
                self.assertRegex(java, r'public [\w.<>\[\], ]+ %s\(' % method, (x, method))

    def test_the_method_finder(self):
        self.assertEqual(aidl_methods('package a;\n/** b(c) */\ninterface I {\n  // d(e)\n'
                                      '  int f(int x);\n  void g(in Bundle b, String s);\n}\n'), ['f', 'g'])

    def test_the_build_needs_no_aidl(self):
        script = read('tools', 'ci', 'build-android.sh')
        self.assertNotIn('/aidl', script)
        self.assertIn('[ -d "${ANDROID_SDK}/build-tools/${ANDROID_BUILD_TOOLS}" ]', script)


# ---------------------------------------------------------------------------
# tools/ci/android_engine.py on made-up ELF files


def elf(is64=True, machine=183, align=16384, needed=('libc.so', 'liblog.so'), textrel=None, api=21,
        project='last', exports=('JNI_OnLoad',), etype=3, relro=None, writable=()):
    """A small ELF file with what android_engine.py reads: LOAD and DYNAMIC
    segments, .dynstr, .dynsym, .dynamic, .note.android.ident and .project.
    Addresses are file offsets. project: None (no .project), 'last',
    'section-after' (an allocated section after it), 'segment-after' (an
    empty LOAD segment after its own) or 'padded' (its segment's data goes
    on after it). relro: (start, end) of a PT_GNU_RELRO segment; writable:
    sections only the section table names, (name, address, size) and
    optionally their flags (SHF_WRITE | SHF_ALLOC by default) and type
    (SHT_PROGBITS by default)."""
    e = '<'
    word = 'Q' if is64 else 'I'
    ehsize, phentsize, shentsize = (64, 56, 64) if is64 else (52, 32, 40)

    dynstr = b'\0'
    names = {}
    for n in list(needed) + list(exports) + ['abort']:
        names[n] = len(dynstr)
        dynstr += n.encode() + b'\0'

    sym_size = 24 if is64 else 16

    def sym(name, shndx):
        if is64:
            return struct.pack(e + 'IBBHQQ', name, 0x12, 0, shndx, 0, 0)
        return struct.pack(e + 'IIIBBH', name, 0, 0, 0x12, 0, shndx)

    dynsym = sym(0, 0) + b''.join(sym(names[n], 7) for n in exports) + sym(names['abort'], 0)
    note = struct.pack(e + 'III', 8, 4, 1) + b'Android\0' + struct.pack(e + 'I', api) if api is not None else b''

    phnum = 2 + (1 if project == 'segment-after' else 0) + (1 if relro else 0)
    off = ehsize + phnum * phentsize
    blobs = []

    def place(name, data, sh_type, flags=2, link=0, entsize=0):
        nonlocal off
        off = (off + 7) & ~7
        blobs.append({'name': name, 'data': data, 'type': sh_type, 'flags': flags, 'addr': off, 'offset': off,
                      'link': link, 'entsize': entsize})
        off += len(data)

    place('.dynstr', dynstr, 3)
    dynstr_addr = blobs[-1]['addr']
    place('.dynsym', dynsym, 11, link=1, entsize=sym_size)
    tags = [(1, names[n]) for n in needed] + [(5, dynstr_addr), (10, len(dynstr))]
    if textrel == 'tag':
        tags.append((22, 0))
    elif textrel == 'flag':
        tags.append((30, 4 | 8))
    tags.append((0, 0))
    dynamic = b''.join(struct.pack(e + ('qQ' if is64 else 'iI'), t, v) for t, v in tags)
    place('.dynamic', dynamic, 6, flags=3)
    if note:
        place('.note.android.ident', note, 7)
    if project:
        place('.project', b'#!project' + b'\0' * 55, 1, flags=3)
    if project == 'section-after':
        place('.after', b'\0' * 16, 1, flags=3)
    load_end = off + (16 if project == 'padded' else 0)
    off = load_end
    for w in writable:
        w = tuple(w) + (3, 1)[len(w) - 3:]
        blobs.append({'name': w[0], 'data': b'', 'size': w[2], 'type': w[4], 'flags': w[3], 'addr': w[1],
                      'offset': 0, 'link': 0, 'entsize': 0})
    shstrtab = b'\0'
    sections = [{'name': '', 'type': 0, 'flags': 0, 'addr': 0, 'offset': 0, 'data': b'', 'link': 0,
                 'entsize': 0}] + blobs
    for s in sections[1:]:
        s['name_at'] = len(shstrtab)
        shstrtab += s['name'].encode() + b'\0'
    sections[0]['name_at'] = 0
    place_name = len(shstrtab)
    shstrtab += b'.shstrtab\0'
    sections.append({'name': '.shstrtab', 'name_at': place_name, 'type': 3, 'flags': 0, 'addr': 0,
                     'offset': off, 'data': shstrtab, 'link': 0, 'entsize': 0})
    off += len(shstrtab)
    shoff = (off + 7) & ~7

    out = bytearray(shoff + shentsize * len(sections))
    ident = b'\x7fELF' + bytes([2 if is64 else 1, 1, 1]) + b'\0' * 9
    out[0:16] = ident
    fmt = 'HHI' + word * 3 + 'IHHHHHH'
    struct.pack_into(e + fmt, out, 16, etype, machine, 1, 0, ehsize, shoff, 0, ehsize, phentsize, phnum,
                     shentsize, len(sections), len(sections) - 1)

    def phdr(i, p_type, offset, vaddr, filesz, memsz, flags, p_align):
        at = ehsize + i * phentsize
        if is64:
            struct.pack_into(e + 'IIQQQQQQ', out, at, p_type, flags, offset, vaddr, vaddr, filesz, memsz, p_align)
        else:
            struct.pack_into(e + 'IIIIIIII', out, at, p_type, offset, vaddr, vaddr, filesz, memsz, flags, p_align)

    dyn = [b for b in blobs if b['name'] == '.dynamic'][0]
    phdr(0, 1, 0, 0, load_end, load_end, 7, align)
    phdr(1, 2, dyn['offset'], dyn['addr'], len(dyn['data']), len(dyn['data']), 6, 8)
    if project == 'segment-after':
        later = (load_end + 0xFFFF) & ~0xFFFF
        phdr(2, 1, load_end, later, 0, 16, 6, align)
    if relro:
        phdr(phnum - 1, 0x6474e552, 0, relro[0], relro[1] - relro[0], relro[1] - relro[0], 4, 1)
    for s in sections:
        if s['data']:
            out[s['offset']:s['offset'] + len(s['data'])] = s['data']
    for i, s in enumerate(sections):
        at = shoff + i * shentsize
        if is64:
            struct.pack_into(e + 'IIQQQQIIQQ', out, at, s['name_at'], s['type'], s['flags'], s['addr'], s['offset'],
                             s.get('size', len(s['data'])), s['link'], 0, 8, s['entsize'])
        else:
            struct.pack_into(e + 'IIIIIIIIII', out, at, s['name_at'], s['type'], s['flags'], s['addr'],
                             s['offset'], s.get('size', len(s['data'])), s['link'], 0, 4, s['entsize'])
    return bytes(out)


ABI_ELF = {'arm64-v8a': dict(is64=True, machine=183), 'armeabi-v7a': dict(is64=False, machine=40),
           'x86_64': dict(is64=True, machine=62), 'x86': dict(is64=False, machine=3)}


def jar():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as z:
        z.writestr('com/runrev/android/Engine.class', b'\xca\xfe\xba\xbe')
    return buf.getvalue()


class Runtime(unittest.TestCase):
    """android_engine.py check on a made-up runtime folder."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        self.root = os.path.join(self.tmp, 'Android')

    def make(self, abis=tuple(ABI_ELF), engine=None, external=None, skip=()):
        for abi in abis:
            for name in (ae.ENGINE,) + ae.EXTERNALS:
                if '%s/%s' % (abi, name) in skip:
                    continue
                kw = dict(ABI_ELF[abi])
                if name == ae.ENGINE:
                    kw.update(engine or {})
                else:
                    kw.update(project=None, exports=('getXtable',))
                    kw.update(external or {})
                touch(os.path.join(self.root, abi, name), elf(**kw))
        for name in ae.TOP_FILES:
            if name not in skip:
                touch(os.path.join(self.root, name), jar() if name == 'Classes' else b'<x/>')

    def problems(self, abis=()):
        problems, seen = ae.check(self.root, abis)
        return problems

    def assertProblem(self, problems, *words):
        hits = [p for p in problems if all(w in p for w in words)]
        self.assertTrue(hits, 'no problem with %s in %s' % (words, problems))

    def test_a_good_runtime(self):
        self.make()
        problems, seen = ae.check(self.root)
        self.assertEqual(problems, [])
        self.assertEqual(len(seen), 4 * 8)
        self.assertIn('arm64-v8a/Standalone:', seen[0])
        self.assertIn('LOAD aligned to 16384, API 21, needs libc.so, liblog.so', seen[0])

    def test_one_abi(self):
        self.make(abis=('x86',))
        self.assertEqual(self.problems(['x86']), [])
        self.assertProblem(self.problems(['x86', 'arm64-v8a']), 'has no arm64-v8a folder')
        self.assertProblem(self.problems(['mips']), 'no Android ABI mips')

    def test_no_abi_at_all(self):
        os.makedirs(self.root)
        self.assertProblem(self.problems(), 'has no ABI folder')

    def test_the_wrong_machine(self):
        self.make(abis=('arm64-v8a',), engine={'machine': 62})
        self.assertProblem(self.problems(), 'arm64-v8a/Standalone is for machine 62 (64-bit)')
        self.make(abis=('armeabi-v7a',), external={'is64': True})
        self.assertProblem(self.problems(), 'armeabi-v7a/RevDb is for machine 40 (64-bit)')

    def test_not_a_shared_library(self):
        self.make(abis=('x86_64',), engine={'etype': 2})
        self.assertProblem(self.problems(), 'x86_64/Standalone is not a shared library')

    def test_16_kb_pages(self):
        self.make(abis=('arm64-v8a', 'x86_64'), external={'align': 4096})
        self.assertProblem(self.problems(), 'arm64-v8a/RevZip has LOAD segments aligned to 4096, under 16 KB')
        self.assertProblem(self.problems(), 'x86_64/DbMysql has LOAD segments aligned to 4096')
        # the 32-bit ABIs have no devices with 16 KB pages
        shutil.rmtree(self.root)
        self.make(abis=('armeabi-v7a', 'x86'), engine={'align': 4096}, external={'align': 4096})
        self.assertEqual(self.problems(), [])

    def test_relro_pages(self):
        """A library whose RELRO ends in a page that .data starts in (the
        engine that lld linked with the old script, at 16 KB) is refused,
        on the 64-bit ABIs at 16 KB and on the others at 4 KB; one whose
        .data starts on the next page passes, and the summary line names
        RELRO."""
        old = dict(relro=(0x4000, 0x8030), writable=[('.got', 0x8000, 0x30), ('.data', 0x8030, 0x18)])
        self.make(abis=('x86_64', 'x86'), external=old)
        problems = self.problems()
        self.assertProblem(problems, 'x86_64/RevDb: RELRO (0x4000 to 0x8030) shares its 16 KB pages with .data,')
        self.assertProblem(problems, 'x86/RevZip: RELRO (0x4000 to 0x8030) shares its 4 KB pages with .data,')
        self.assertFalse([p for p in problems if '.got' in p])
        shutil.rmtree(self.root)
        self.make(abis=('x86_64', 'x86'),
                  external=dict(relro=(0x4000, 0x5000), writable=[('.got', 0x4190, 0x30), ('.data', 0x8000, 0x18)]))
        problems, seen = ae.check(self.root)
        self.assertEqual(problems, [])
        self.assertTrue(seen[1].endswith('; RELRO 0x4000 to 0x5000'), seen[1])
        self.assertFalse(seen[0].endswith('0x5000'), seen[0])  # the engine has no RELRO here

    def test_text_relocations(self):
        for how in ('tag', 'flag'):
            with self.subTest(how=how):
                shutil.rmtree(self.root, ignore_errors=True)
                self.make(abis=('x86',), external={'textrel': how})
                self.assertProblem(self.problems(), 'x86/RevXml has text relocations')

    def test_libraries_android_has_not_got(self):
        self.make(abis=('arm64-v8a',), external={'needed': ('libc.so', 'libc++_shared.so')})
        self.assertProblem(self.problems(), 'arm64-v8a/RevSecurity needs libc++_shared.so')
        shutil.rmtree(self.root)
        self.make(abis=('arm64-v8a',), engine={'needed': ('libc.so', 'libssl.so', 'libandroid.so')})
        problems = self.problems()
        self.assertProblem(problems, 'arm64-v8a/Standalone needs libssl.so, not a library of Android')
        self.assertFalse([p for p in problems if 'libandroid.so' in p])

    def test_the_lowest_android(self):
        self.make(abis=('x86_64',), engine={'api': 24})
        self.assertProblem(self.problems(), 'x86_64/Standalone is for Android API 24 and later, not 21')
        shutil.rmtree(self.root)
        self.make(abis=('x86_64',), external={'api': None})
        self.assertProblem(self.problems(), 'x86_64/RevPdfPrinter has no .note.android.ident')

    def test_the_project_section(self):
        cases = {
            None: 'has no .project section',
            'section-after': 'has sections after .project in memory (.after)',
            'segment-after': 'the LOAD segment that holds .project is not the last',
            'padded': ".project does not end its LOAD segment's data",
        }
        for project, words in cases.items():
            with self.subTest(project=project):
                shutil.rmtree(self.root, ignore_errors=True)
                self.make(abis=('armeabi-v7a',), engine={'project': project})
                self.assertProblem(self.problems(), 'armeabi-v7a/Standalone', words)
        # (only the engine needs one)
        shutil.rmtree(self.root)
        self.make(abis=('armeabi-v7a',), external={'project': None})
        self.assertEqual(self.problems(), [])

    def test_jni_onload(self):
        self.make(abis=('arm64-v8a',), engine={'exports': ('Java_com_runrev_android_Engine_doCreate',)})
        self.assertProblem(self.problems(), 'arm64-v8a/Standalone does not export JNI_OnLoad')
        # an undefined JNI_OnLoad is not an export
        self.assertNotIn('abort', ae.Elf(elf(exports=())).exports())

    def test_missing_files(self):
        self.make(abis=('x86',), skip=('x86/DbSqlite', 'Manifest.xml'))
        problems = self.problems()
        self.assertProblem(problems, 'has no x86/DbSqlite')
        self.assertProblem(problems, 'has no Manifest.xml')
        touch(os.path.join(self.root, 'Manifest.xml'))
        self.assertProblem(self.problems(), 'has no Manifest.xml (or it is empty)')

    def test_classes_is_a_jar(self):
        self.make(abis=('x86',))
        touch(os.path.join(self.root, 'Classes'), b'not a jar')
        self.assertProblem(self.problems(), 'Classes is not a jar')

    def test_not_elf(self):
        self.make(abis=('x86',))
        touch(os.path.join(self.root, 'x86', 'RevZip'), b'#!/bin/sh\n')
        self.assertProblem(self.problems(), 'x86/RevZip: not an ELF file')

    def test_the_elf_reader(self):
        for is64 in (True, False):
            with self.subTest(is64=is64):
                f = ae.Elf(elf(is64=is64, needed=('libm.so', 'libz.so'), exports=('JNI_OnLoad', 'Java_x')))
                self.assertEqual(f.needed(), ['libm.so', 'libz.so'])
                self.assertEqual(f.exports(), {'JNI_OnLoad', 'Java_x'})
                self.assertEqual(f.android_api(), 21)
                self.assertFalse(f.text_relocations())
                self.assertEqual([s['name'] for s in f.sections][-2:], ['.project', '.shstrtab'])

    def test_main(self):
        self.make(abis=('x86_64',))
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(ae.main(['check', self.root, '--abi', 'x86_64']), 0)
        self.assertIn('passed every check', out.getvalue())
        touch(os.path.join(self.root, 'x86_64', 'RevDb'), elf(machine=183))
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(ae.main(['check', self.root]), 1)
        self.assertIn('PROBLEM: x86_64/RevDb is for machine 183', out.getvalue())

    def test_the_names_agree_with_the_builder(self):
        """The IDE's Android builder takes these files from Runtime/Android."""
        builder = read('ide-support', 'revsaveasandroidstandalone.livecodescript')
        for name in ae.EXTERNALS + ('Standalone', 'Classes', 'Manifest.xml', 'notify_icon.png'):
            self.assertIn(name, builder, name)


# ---------------------------------------------------------------------------
# .github/workflows/android-engine.yml


# ---------------------------------------------------------------------------
# RELRO and the engine's linker script. Android's loader makes RELRO's pages
# read-only whole; the engine that lld linked with the old GNU ld script
# (engine/standalone-android.link, which puts .got after
# DATA_SEGMENT_RELRO_END) had RELRO end inside .data's first page, and died
# loading on the emulator (SEGV_ACCERR in MCScriptRegisterBuiltinModule).
# engine/engine.gyp gives lld a copy with .got inside RELRO.


WRITE_ALLOC = 3
SHT_PROGBITS = 1
SHT_NOBITS = 8
SHF_TLS = 0x400


class Relro(unittest.TestCase):
    """android_engine.py's check_relro on made-up ELF files."""

    def problems(self, relro, writable, is64=True, page=None):
        f = ae.Elf(elf(is64=is64, project=None, relro=relro, writable=writable))
        return ae.check_relro(f, 'x86_64/Standalone', page or (ae.PAGE_16K if is64 else ae.PAGE_4K))

    def test_the_old_script_under_lld(self):
        """RELRO from .data.rel.ro to the end of .got, which lld put after
        the page boundary DATA_SEGMENT_RELRO_END set: .data and .bss share
        .got's page."""
        problems = self.problems((0x4000, 0x8030), [('.data.rel.ro', 0x4000, 0x190), ('.got', 0x8000, 0x30),
                                                    ('.data', 0x8030, 0x18), ('.bss', 0x8048, 0x10, WRITE_ALLOC,
                                                                              SHT_NOBITS)])
        self.assertEqual(len(problems), 1)
        self.assertIn('x86_64/Standalone: RELRO (0x4000 to 0x8030) shares its 16 KB pages with .data, .bss, '
                      'which is writable and not RELRO', problems[0])
        self.assertNotIn('.got', problems[0])
        self.assertNotIn('.data.rel.ro', problems[0])

    def test_the_lld_script(self):
        """RELRO ends with .got; .data starts on the next page."""
        self.assertEqual(self.problems((0x4000, 0x5000), [('.data.rel.ro', 0x4000, 0x190), ('.got', 0x4190, 0x30),
                                                          ('.data', 0x8000, 0x18)]), [])

    def test_gnu_ld(self):
        """The standalone route: GNU ld ends RELRO on the page boundary and
        puts .got (not RELRO there) and .data after it."""
        self.assertEqual(self.problems((0x7e68, 0x8000), [('.data.rel.ro', 0x7e68, 0x190), ('.got', 0x8000, 0x30),
                                                          ('.data', 0x8030, 0x18)]), [])

    def test_the_page_of_the_abi(self):
        """.data a page of 4 KB after RELRO's: fine on 4 KB pages, which the
        32-bit ABIs have, and not on the 16 KB the 64-bit ones can have."""
        layout = ((0x4000, 0x4100), [('.got', 0x4000, 0x100), ('.data', 0x5000, 0x18)])
        self.assertEqual(self.problems(*layout, is64=False), [])
        self.assertEqual(self.problems(*layout, is64=True, page=ae.PAGE_4K), [])
        problems = self.problems(*layout, is64=True)
        self.assertEqual(len(problems), 1)
        self.assertIn('16 KB pages with .data,', problems[0])

    def test_relros_first_page(self):
        """Writable data in the page RELRO starts in is caught too."""
        problems = self.problems((0x4100, 0x5000), [('.data.early', 0x4000, 0x10), ('.got', 0x4100, 0x30)],
                                 is64=False)
        self.assertEqual(len(problems), 1)
        self.assertIn('4 KB pages with .data.early,', problems[0])

    def test_a_section_across_relros_end(self):
        problems = self.problems((0x4000, 0x4100), [('.across', 0x40f0, 0x20)], is64=False)
        self.assertIn('with .across,', problems[0])

    def test_what_is_not_caught(self):
        """Read-only sections, empty ones and TLS's .tbss (which takes no
        room in the image) in RELRO's pages; and no RELRO at all."""
        self.assertEqual(self.problems((0x4000, 0x4100), [
            ('.rodata', 0x4100, 0x40, 2), ('.empty', 0x4200, 0, WRITE_ALLOC),
            ('.tbss', 0x4100, 0x40, WRITE_ALLOC | SHF_TLS, SHT_NOBITS)]), [])
        self.assertIn('.tdata', self.problems((0x4000, 0x4100), [
            ('.tdata', 0x4100, 0x40, WRITE_ALLOC | SHF_TLS, SHT_PROGBITS)])[0])
        self.assertEqual(self.problems(None, [('.data', 0x4000, 0x18)]), [])


def find_lld():
    """An ELF lld: on PATH (by any version's name), or the NDK's that
    ANDROID_NDK_HOME or ANDROID_NDK_LATEST_HOME (GitHub's runners) names."""
    for name in ['ld.lld'] + ['ld.lld-%d' % v for v in range(30, 13, -1)]:
        path = shutil.which(name)
        if path:
            return path
    for var in ('ANDROID_NDK_HOME', 'ANDROID_NDK_LATEST_HOME', 'ANDROID_NDK_ROOT'):
        ndk = os.environ.get(var)
        if ndk:
            path = os.path.join(llvm_bin(ndk, 'linux-x86_64'), 'ld.lld')
            if os.path.isfile(path):
                return path
    return None


LINKABLE = sys.platform.startswith('linux') and shutil.which('cc')
LLD = find_lld() if LINKABLE else None
BFD = shutil.which('ld.bfd') if LINKABLE else None

# What MCScriptRegisterBuiltinModule and the module loaders lc-compile
# writes do: a static constructor writes a module's info, in .data (it holds
# relocated pointers), and a list's head; and what .got, .data.rel.ro and
# .project hold
RELRO_SOURCE = r"""
extern int ext_var;
struct info { struct info *next; const char *name; void (*fn)(void); };
static void f(void) {}
struct info module_info = { 0, "x", f };
const struct info ro_info = { 0, "y", f };
static struct info *head;
void reg(struct info *p) { p->next = head; head = p; }
__attribute__((constructor)) static void ctor(void) { reg(&module_info); }
int get(void) { return ext_var; }
__attribute__((section(".project"))) char project[16] = "project";
"""


class LinkScript(unittest.TestCase):
    """The two linker scripts: engine/engine.gyp's choice of one, their one
    difference, and (with this host's linkers) what each makes."""

    OLD = 'engine/standalone-android.link'
    LLD_SCRIPT = 'engine/standalone-android-lld.link'

    def scripts(self, **names):
        target = gyp_target(gyp('engine', 'engine.gyp'), 'standalone')
        found = gyp_link_flags(target, dict(ANDROID_TARGET, **names), ('-Wl,-T,$(abs_srcdir)/' + self.OLD,
                                                                       '-Wl,-T,$(abs_srcdir)/' + self.LLD_SCRIPT))
        sources = gyp_lists(target, dict(ANDROID_TARGET, **names), ('sources',))
        return found, [x for x in sources if x.endswith('.link')]

    def test_the_choice(self):
        """lld (a current NDK's own toolchain) takes the copy; GNU ld, or a
        linker set by hand, the script as before; -no-undefined first."""
        self.assertEqual(self.scripts(android_fuse_ld='lld'),
                         (['-Wl,-T,$(abs_srcdir)/' + self.LLD_SCRIPT], [self.LLD_SCRIPT]))
        for linker in ('bfd', 'gold'):
            self.assertEqual(self.scripts(android_fuse_ld=linker),
                             (['-Wl,-T,$(abs_srcdir)/' + self.OLD], [self.OLD]), linker)
        target = gyp_target(gyp('engine', 'engine.gyp'), 'standalone')
        for linker in ('lld', 'bfd'):
            flags = gyp_link_flags(target, dict(ANDROID_TARGET, android_fuse_ld=linker),
                                   ('-Wl,-no-undefined', '-Wl,-T,$(abs_srcdir)/' + self.OLD,
                                    '-Wl,-T,$(abs_srcdir)/' + self.LLD_SCRIPT))
            self.assertEqual(flags[0], '-Wl,-no-undefined', linker)
            self.assertEqual(len(flags), 2, linker)
        # (and no other platform takes either)
        self.assertEqual(self.scripts(android_fuse_ld='lld', OS='linux', toolset_os='linux'), ([], []))

    def test_the_one_difference(self):
        """The copy is the script with its OXT-Beyond comments and .got
        moved before DATA_SEGMENT_RELRO_END, and nothing else."""
        old = read(*self.OLD.split('/'))
        new = read(*self.LLD_SCRIPT.split('/'))
        self.assertNotIn('OXT-Beyond', old)
        comments = re.findall(r'[ \t]*/\* OXT-Beyond:.*?\*/\n\n?', new, re.S)
        self.assertEqual(len(comments), 2)
        for c in comments:
            new = new.replace(c, '', 1)
        got = '  .got            : { *(.got.plt) *(.igot.plt) *(.got) *(.igot) }\n'
        end = '  . = DATA_SEGMENT_RELRO_END (0, .);\n'
        self.assertIn(end + got, old)
        self.assertEqual(new, old.replace(end + got, got + end))
        self.assertIn("lld counts .got as RELRO", read(*self.LLD_SCRIPT.split('/')))

    def link(self, tmp, linker, script, page):
        out = os.path.join(tmp, '%s-%d-%s.so' % (os.path.basename(linker), page, os.path.basename(script)))
        subprocess.run([linker, '-shared', '-z', 'max-page-size=%d' % page, '-z', 'now', '-z', 'relro',
                        '-T', os.path.join(REPO, *script.split('/')), os.path.join(tmp, 't.o'), '-o', out],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        with open(out, 'rb') as f:
            return ae.Elf(f.read())

    def compiled(self):
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        with open(os.path.join(tmp, 't.c'), 'w') as f:
            f.write(RELRO_SOURCE)
        subprocess.run(['cc', '-c', '-fPIC', '-O1', os.path.join(tmp, 't.c'), '-o', os.path.join(tmp, 't.o')],
                       check=True)
        return tmp

    @staticmethod
    def section(f, name):
        return [s for s in f.sections if s['name'] == name][0]

    @unittest.skipUnless(LLD, 'needs Linux, cc and lld')
    def test_lld_links_each(self):
        """lld with the old script ends RELRO with .got, in .data's page,
        which the check refuses; with the copy, .data starts on the next
        page at either page size, and the check passes."""
        tmp = self.compiled()
        for page in (ae.PAGE_4K, ae.PAGE_16K):
            with self.subTest(page=page):
                f = self.link(tmp, LLD, self.OLD, page)
                got, data = self.section(f, '.got'), self.section(f, '.data')
                relro = [s for s in f.segments if s['type'] == ae.PT_GNU_RELRO][0]
                self.assertEqual(relro['vaddr'] + relro['memsz'], got['addr'] + got['size'])
                self.assertEqual(data['addr'] // page, got['addr'] // page)
                problems = ae.check_relro(f, 'x', page)
                self.assertEqual(len(problems), 1)
                self.assertIn('pages with .data,', problems[0])

                f = self.link(tmp, LLD, self.LLD_SCRIPT, page)
                self.assertEqual(ae.check_relro(f, 'x', page), [])
                self.assertEqual(self.section(f, '.data')['addr'] % page, 0)
                project = self.section(f, '.project')
                self.assertEqual(max(s['addr'] for s in f.sections if s['flags'] & 2), project['addr'])

    @unittest.skipUnless(BFD, 'needs Linux, cc and GNU ld')
    def test_gnu_ld_as_before(self):
        """GNU ld with the old script, the standalone route's, passes."""
        tmp = self.compiled()
        for page in (ae.PAGE_4K, ae.PAGE_16K):
            with self.subTest(page=page):
                self.assertEqual(ae.check_relro(self.link(tmp, BFD, self.OLD, page), 'x', page), [])


# ---------------------------------------------------------------------------
# Null `this`: a current NDK's Clang deletes checks of it, which the bundled
# HarfBuzz makes for every null object it destroys or references; the engine
# built here died on its first text (SIGSEGV at 0 in
# hb_unicode_funcs_destroy, from hb_buffer_create). The lld route's settings
# keep such checks.


NULL_CHECKS = '-fno-delete-null-pointer-checks'
HARFBUZZ = os.path.join(REPO, 'thirdparty', 'libharfbuzz', 'src')
# hb_buffer_create's path: a new buffer's reset destroys its (null) unicode
# functions
HARFBUZZ_MAIN = r"""
#include "hb.h"
int main(void)
{
    hb_buffer_t *b = hb_buffer_create();
    hb_buffer_add_utf8(b, "probe", -1, 0, -1);
    unsigned int n = hb_buffer_get_length(b);
    hb_buffer_destroy(b);
    return n == 5 ? 0 : 3;
}
"""


def clang_major():
    """This host's clang++ major version, or None."""
    if not (sys.platform.startswith('linux') and shutil.which('clang++') and shutil.which('clang')):
        return None
    out = subprocess.run(['clang++', '-dumpversion'], stdout=subprocess.PIPE, universal_newlines=True).stdout
    return int(out.split('.')[0]) if out.strip() else None


CLANG = clang_major()


class NullThis(unittest.TestCase):

    def cflags(self, linker):
        settings = gyp('config', 'android-settings.gypi')
        return gyp_lists(settings, dict(ANDROID_TARGET, android_fuse_ld=linker), ('cflags',))

    def test_the_lld_route_keeps_the_checks(self):
        self.assertIn(NULL_CHECKS, self.cflags('lld'))
        for linker in ('bfd', 'gold'):
            self.assertNotIn(NULL_CHECKS, self.cflags(linker), linker)
        # (a static library, which the Thirdparty libraries are, too)
        settings = gyp('config', 'android-settings.gypi')
        self.assertIn(NULL_CHECKS, gyp_lists(settings, dict(ANDROID_TARGET, android_fuse_ld='lld',
                                                            _type='static_library'), ('cflags',)))

    def test_harfbuzz_checks_this(self):
        """What the flag is for is still there: HarfBuzz checks `this`."""
        with open(os.path.join(HARFBUZZ, 'hb-object-private.hh'), encoding='utf-8') as f:
            self.assertIn('if (unlikely (!this || this->is_inert ()))', f.read())

    @unittest.skipUnless(CLANG, 'needs Linux and clang')
    def test_harfbuzz_with_this_hosts_clang(self):
        """The bundled HarfBuzz, built as the lld route builds it (-O3, the
        flags the settings give), creates a buffer; and, with a Clang that
        marks `this` nonnull (13 and later), crashes there without the
        flag, as the engine did."""
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp)
        with open(os.path.join(tmp, 'main.cc'), 'w') as f:
            f.write(HARFBUZZ_MAIN)
        flags = [x for x in self.cflags('lld') if x == NULL_CHECKS]
        self.assertEqual(flags, [NULL_CHECKS])

        def build(extra):
            out = os.path.join(tmp, 'hb%d' % len(extra))
            common = ['-O3', '-w', '-DHB_NO_MT', '-DHAVE_UCDN', '-I', HARFBUZZ, '-I',
                      os.path.join(HARFBUZZ, 'hb-ucdn')] + extra
            objects = []
            for name in ('hb-buffer.cc', 'hb-unicode.cc', 'hb-common.cc', 'hb-ucdn.cc', 'hb-ucdn/ucdn.c'):
                obj = os.path.join(tmp, '%s-%d.o' % (os.path.basename(name), len(extra)))
                cc = ['clang', '-std=gnu99'] if name.endswith('.c') else \
                    ['clang++', '-std=c++11', '-fno-exceptions', '-fno-rtti']
                subprocess.run(cc + common + ['-c', os.path.join(HARFBUZZ, name), '-o', obj], check=True)
                objects.append(obj)
            subprocess.run(['clang++'] + common + [os.path.join(tmp, 'main.cc')] + objects + ['-o', out],
                           check=True)
            return subprocess.run([out], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode

        self.assertEqual(build(flags), 0)
        if CLANG >= 13:
            self.assertLess(build([]), 0)    # killed by a signal


class Workflow(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            import yaml
        except ImportError:
            raise unittest.SkipTest('no PyYAML')
        cls.text = read('.github', 'workflows', 'android-engine.yml')
        cls.wf = yaml.safe_load(cls.text)
        cls.job = cls.wf['jobs']['build']
        cls.steps = dict((s.get('name'), s) for s in cls.job['steps'])

    def test_every_architecture(self):
        include = self.job['strategy']['matrix']['include']
        abis = bash_assoc(read('tools', 'ci', 'build-android.sh'), 'ABIS')
        self.assertEqual(dict((x['arch'], x['abi']) for x in include), abis)
        self.assertFalse(self.job['strategy']['fail-fast'])

    def test_the_container(self):
        self.assertEqual(self.job['container']['image'], 'mirror.gcr.io/library/ubuntu:22.04')
        self.assertIn('/usr/local/lib/android:/usr/local/lib/android', self.job['container']['volumes'])
        self.assertTrue(self.job['env']['ANDROID_SDK'].startswith('/usr/local/lib/android/'))
        self.assertIn('python2', self.job['env']['BUILD_PKGS'].split())
        self.assertIn('openjdk-17-jdk-headless', self.job['env']['BUILD_PKGS'].split())

    def test_the_ndk_of_the_repository(self):
        run = self.steps['Set up the NDK and the SDK']['run']
        self.assertIn('config/android-ndk-version', run)
        self.assertNotIn(read('config', 'android-ndk-version').strip(), self.text)
        key = self.steps['Compute the cache key']['run']
        for name in ('config/android-ndk-version', 'tools/ci/build-android.sh', 'config.py', 'config/*.gypi',
                     'prebuilt/scripts/*.inc', 'prebuilt/scripts/*.sh', 'HEAD:thirdparty', '${ARCH}'):
            self.assertIn(name, key)

    def test_it_builds_and_checks(self):
        self.assertEqual(self.steps['Build the libraries']['run'].strip(),
                         'tools/ci/build-android.sh "$ARCH" --libraries')
        self.assertEqual(self.steps['Build the engine and the externals']['run'].strip(),
                         'tools/ci/build-android.sh "$ARCH" android-runtime')
        self.assertEqual(self.steps['Check what Android and the builder ask of them']['run'].strip(),
                         'python3 tools/ci/android_engine.py check android-runtime --abi "$ABI"')
        jni = ' '.join(self.steps['Check the engine against its Java layer (JNI)']['run'].replace('\\\n', '').split())
        self.assertIn('tools/ci/android_java.py jni --classes android-runtime/Classes --runtime android-runtime',
                      jni)
        upload = self.steps['Upload the runtime']['with']
        self.assertEqual(upload['path'], 'android-runtime/')

    def test_nothing_is_published(self):
        # the device job downloads the latest release's IDE to run the
        # builder in; nothing is written to a release, a package or the
        # repository
        self.assertEqual(self.wf['permissions'], {'contents': 'read'})
        for job in self.wf['jobs'].values():
            self.assertNotIn('permissions', job)
        self.assertNotRegex(self.text, r':\s*write\b')
        runs = ' '.join(s.get('run', '') for job in self.wf['jobs'].values() for s in job['steps'])
        self.assertEqual(re.findall(r'gh release (\w+)', runs), ['list', 'download'])
        uses = [s['uses'].split('@')[0] for job in self.wf['jobs'].values() for s in job['steps'] if 'uses' in s]
        self.assertEqual(sorted(set(uses)), ['actions/cache/restore', 'actions/cache/save', 'actions/checkout',
                                             'actions/download-artifact', 'actions/upload-artifact'])

    def test_what_starts_it(self):
        on = self.wf[True]
        paths = on['pull_request']['paths']
        self.assertEqual(paths, on['push']['paths'])
        for name in ('.github/workflows/android-engine.yml', 'tools/ci/build-android.sh', 'tools/ci/android_engine.py',
                     'tools/ci/android_java.py'):
            self.assertIn(name, paths)
        self.assertEqual(paths[0], '**')
        # the files the build runs, outside the folders it builds from
        for name in re.findall(r"'\.\./tools/([\w.-]+\.sh)'", read('config', 'java.gypi')):
            self.assertIn('tools/' + name, paths)

    def test_the_device_job(self):
        """The engine built here runs: the device job takes the four build
        jobs' folders as one runtime, puts it and this builder into the
        release's IDE, builds both probes with it, checks each package's
        engine is the one built here, and runs them on Android 13 and with
        16 KB pages"""
        import fnmatch
        job = self.wf['jobs']['device']
        self.assertEqual(job['needs'], 'build')
        self.assertEqual(job['runs-on'], 'ubuntu-24.04')
        self.assertNotIn('container', job)
        self.assertNotIn('if', job)
        steps = dict((s.get('name'), s) for s in job['steps'])
        download = steps['Download the runtime']
        self.assertTrue(download['uses'].startswith('actions/download-artifact@'))
        pattern = download['with']['pattern']
        self.assertTrue(download['with']['merge-multiple'])
        self.assertEqual(download['with']['path'], '${{ runner.temp }}/android/engine')
        # every build job's folder, and not the device job's own upload
        for abi in bash_assoc(read('tools', 'ci', 'build-android.sh'), 'ABIS').values():
            name = self.steps['Upload the runtime']['with']['name'].replace('${{ matrix.abi }}', abi)
            self.assertTrue(fnmatch.fnmatchcase(name, pattern), name)
        own = steps['Upload the packages and logs']['with']['name']
        self.assertFalse(fnmatch.fnmatchcase(own, pattern), own)
        self.assertIn('echo "WORK=$RUNNER_TEMP/android" >> "$GITHUB_ENV"', steps['Download the IDE']['run'])

        def lines(step):
            return [' '.join(x.split()) for x in steps[step]['run'].replace('\\\n', ' ').splitlines() if x.strip()]

        unpack = lines('Unpack the IDE, and put this builder and the runtime into it')
        self.assertIn('python3 tools/ci/android_check.py overlay --root "$WORK/ide" --engine "$WORK/engine"', unpack)
        built = lines('Build the probes with this engine')
        self.assertEqual([x for x in built if ' ide ' in x], [
            'python3 tools/ci/android_check.py ide --install "$IDE" --platform "$PLATFORM" --work "$WORK/app" '
            '--sdk "$SDK" --jdk "$JDK" --no-units --builds debug',
            'python3 tools/ci/android_check.py ide --install "$IDE" --platform "$PLATFORM" --work "$WORK/java" '
            '--sdk "$SDK" --jdk "$JDK" --no-units --builds debug --probe java'])
        self.assertIn('for probe in app java; do', built)
        self.assertIn('python3 tools/ci/android_check.py verify --work "$WORK/$probe" --sdk "$SDK" --jdk "$JDK" '
                      '--builds debug --target 36 --engine "$WORK/engine"', built)
        # the debug build has every architecture, so verify --engine checks
        # every engine built here
        sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))
        import android_check as ac
        self.assertEqual(ac.BUILDS['debug']['abis'], set(ae.ABIS))
        app = '--within-bars'
        java = '--allow android.permission.POST_NOTIFICATIONS --picture oxt-beyond-probe.png --back --within-bars'
        for step, where in (('Run the probes on Android 13', 'api33'), ('Run the probes with 16 KB pages', '16k')):
            runs = [x for x in lines(step) if ' device ' in x]
            self.assertEqual(runs, [
                'python3 tools/ci/android_check.py device --apk "$WORK/app/out/debug.apk" --serial emulator-5554 '
                '--sdk "$SDK" --out "$WORK/screen-%s-app.png" --log-out "$WORK/logcat-%s-app.txt" %s'
                % (where, where, app),
                'python3 tools/ci/android_check.py device --apk "$WORK/java/out/debug.apk" --serial emulator-5554 '
                '--sdk "$SDK" --out "$WORK/screen-%s-java.png" --log-out "$WORK/logcat-%s-java.txt" %s'
                % (where, where, java)], step)
        # options the check has
        for flag in set(re.findall(r'(--[a-z-]+)', app + ' ' + java)):
            self.assertIn("d.add_argument('%s'" % flag, read('tools', 'ci', 'android_check.py'), flag)
        sixteen = steps['Run the probes with 16 KB pages']['run']
        self.assertIn('[ "$page" = 16384 ]', sixteen)
        self.assertIn('--awake --settle', sixteen)
        self.assertIn('--awake --settle', steps['Wait for the emulator']['run'])
        setup = steps['Set up the JDK and the Android SDK']['run']
        for part in ('"platforms;android-36"', '"system-images;android-33;google_apis;x86_64"', '"$img16"',
                     'google_apis_ps16k;x86_64', '"emulator"'):
            self.assertIn(part, setup)
        self.assertEqual(steps['Upload the packages and logs']['if'], 'always()')

    def test_the_desktop_builds_skip_it(self):
        import yaml
        for wf in ('build-linux.yml', 'build-macos.yml', 'build-windows.yml'):
            ignore = yaml.safe_load(read('.github', 'workflows', wf))[True]['push']['paths-ignore']
            for name in ('.github/workflows/android-engine.yml', 'tools/ci/build-android.sh',
                         'tools/ci/android_engine.py', 'config/android-ndk-version'):
                self.assertIn(name, ignore, wf)


if __name__ == '__main__':
    unittest.main()
