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

"""The Windows player through Media Foundation (engine/src/w32-mf-player.cpp)
for a file DirectShow cannot open: the engine's order (DirectShow first,
always), mfplay.dll loaded at run time, the media check's expectations
(the MP4 files must play wherever Media Foundation is there) and the
Windows workflow that gives its runner Media Foundation.

  python3 -m unittest discover -s tools/ci/tests

The player itself plays the files in the Windows build's "Browser and
player check" (build-windows.yml, tools/ci/media_check.py). Here, with a
MinGW-w64 compiler on PATH (x86_64-w64-mingw32-g++, i686-w64-mingw32-g++),
w32-mf-player.cpp is also compiled and linked on its own, which it can be
because it uses nothing of the engine's.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import media_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))
SRC = os.path.join(REPO, 'engine', 'src')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def function_body(source, signature):
    """The text of a C++ function, from its signature to its closing brace
    at the start of a line."""
    start = source.index(signature)
    end = source.index('\n}\n', start)
    return source[start:end + 3]


class MediaCheckExpectations(unittest.TestCase):
    """Before 0.2.8-dp.2 the MP4 files were known not to play on Windows;
    now they must, wherever Windows has Media Foundation."""

    def test_mp4_must_play_with_media_foundation(self):
        known = media_check.known_failures('windows', 'auto', [])
        self.assertNotIn('oxt-check.mp4', known)
        self.assertNotIn('oxt-check-silent.mp4', known)

    def test_mp4_known_without_media_foundation(self):
        known = media_check.known_failures('windows', 'auto', ['mfplay.dll'])
        self.assertIn('oxt-check.mp4', known)
        self.assertIn('oxt-check-silent.mp4', known)
        self.assertIn('without Media Foundation', known['oxt-check.mp4'])

    def test_mp4_known_with_directshow_alone(self):
        known = media_check.known_failures('windows', 'directshow', [])
        self.assertIn('oxt-check.mp4', known)

    def test_other_platforms_unchanged(self):
        for family in ('linux', 'mac'):
            self.assertEqual(media_check.known_failures(family, 'auto', ['mfplay.dll']),
                             media_check.KNOWN.get(family, {}))

    def test_finds_what_is_missing(self):
        folder = tempfile.mkdtemp()
        try:
            self.assertEqual(media_check.windows_media_foundation(folder), list(media_check.MEDIA_FOUNDATION_DLLS))
            for name in media_check.MEDIA_FOUNDATION_DLLS:
                open(os.path.join(folder, name), 'wb').close()
            self.assertEqual(media_check.windows_media_foundation(folder), [])
            os.remove(os.path.join(folder, 'msmpeg2vdec.dll'))
            self.assertEqual(media_check.windows_media_foundation(folder), ['msmpeg2vdec.dll'])
        finally:
            shutil.rmtree(folder)

    def test_backend_option(self):
        source = read('tools', 'ci', 'media_check.py')
        self.assertIn("choices=('auto', 'gstreamer', 'mplayer', 'directshow', 'mediafoundation')", source)
        self.assertIn('known = known_failures(p.family, args.player_backend, missing_mf)', source)
        self.assertIn("'INFO Media Foundation: %s'", source)


class EngineOrder(unittest.TestCase):
    """A file DirectShow opens goes the way it always has: Media Foundation
    is tried only after DirectShow failed (or OXT_PLAYER_BACKEND asks)."""

    def setUp(self):
        self.ds = read('engine', 'src', 'w32-ds-player.cpp')
        self.set_url = function_body(self.ds, 'bool MCWin32DSPlayer::SetUrl(MCStringRef p_url)\n{')

    def test_directshow_first(self):
        body = self.set_url
        open_ds = body.index('t_success = OpenFile(p_url);')
        open_mf = body.index('OpenFileWithMediaFoundation(p_url)')
        self.assertLess(open_ds, open_mf)
        # only when DirectShow did not open it
        self.assertIn('if (!t_success && t_backend != kMCWin32PlayerBackendDirectShow && '
                      'OpenFileWithMediaFoundation(p_url))', body)
        # DirectShow is skipped only when Media Foundation alone is asked for
        self.assertIn('if (t_success && t_backend != kMCWin32PlayerBackendMediaFoundation)\n'
                      '\t\tt_success = OpenFile(p_url);', body)

    def test_directshow_path_after_the_fallback_is_unchanged(self):
        # what followed OpenFile before follows it still
        tail = self.set_url[self.set_url.index('if (t_success && HasVideo())'):]
        self.assertEqual(tail, '''if (t_success && HasVideo())
		t_success = SetVideoWindow(m_video_window);

	if (t_success)
		t_success = SetEventWindow(m_event_window);

	if (t_success && HasVideo())
		t_success = SetVisible(true);

	if (!t_success)
		CloseFile();

	Pause();

	//InvalidateRect(m_video_window, NULL, FALSE);
	//UpdateWindow(m_video_window);
	//m_MediaViewer->Pause();

	return t_success;
}
''')

    def test_backend_names(self):
        self.assertIn('getenv("OXT_PLAYER_BACKEND")', self.ds)
        self.assertRegex(self.ds, r'_stricmp\(t_choice, "directshow"\) == 0\)\s*return kMCWin32PlayerBackendDirectShow')
        self.assertRegex(self.ds, r'_stricmp\(t_choice, "mediafoundation"\) == 0\)\s*'
                                  r'return kMCWin32PlayerBackendMediaFoundation')

    def test_every_media_foundation_branch_is_guarded(self):
        # each place the movie's properties go to Media Foundation is behind
        # m_mf, which only OpenFileWithMediaFoundation sets
        assigns = re.findall(r'\bm_mf\s*=\s*([^;=]+);', self.ds)
        self.assertEqual(sorted(a.strip() for a in assigns), ['nil', 'nil', 't_playback'])
        for method in ('GetPlayRate', 'SetPlayRate', 'GetTimeScale', 'GetDuration', 'GetCurrentPosition',
                       'SetCurrentPosition', 'SetPositions', 'GetLoadedPosition', 'GetVolume', 'SetVolume',
                       'Play', 'Pause', 'SeekRelative', 'GetFormattedSize'):
            m = re.search(r'bool MCWin32DSPlayer::%s\([^)]*\)\n\{\n(.*?)\n\}\n' % method, self.ds, re.S)
            self.assertIsNotNone(m, method)
            first = [x for x in m.group(1).splitlines() if x.strip() and not x.strip().startswith('//')][0]
            self.assertEqual(first.strip(), 'if (m_mf != nil)', method)

    def test_the_end_is_handled_as_directshow_handles_it(self):
        ended = function_body(self.ds, 'void MCWin32DSPlayer::MFPlaybackEnded(void)\n{')
        graph = function_body(self.ds, 'bool MCWin32DSPlayer::HandleGraphEvent()\n{')
        for line in ('if (m_looping)', 'Play();', 'Pause(true);', 'MCPlatformCallbackSendPlayerFinished(this);'):
            self.assertIn(line, ended)
            self.assertIn(line, graph)

    def test_built_into_the_engine(self):
        gypi = read('engine', 'engine-sources.gypi')
        self.assertIn("'src/w32-mf-player.cpp',", gypi)
        self.assertIn("'src/w32-mf-player.h',", gypi)
        self.assertLess(gypi.index("'src/w32-ds-player.cpp',"), gypi.index("'src/w32-mf-player.cpp',"))


class RunTimeLoading(unittest.TestCase):
    """mfplay.dll is loaded at run time from the system folder: the engine
    starts on a Windows without Media Foundation, and links no Media
    Foundation library."""

    def setUp(self):
        self.mf = read('engine', 'src', 'w32-mf-player.cpp')

    def test_loaded_from_the_system_folder(self):
        self.assertIn('GetSystemDirectoryW(', self.mf)
        self.assertIn('L"\\\\mfplay.dll"', self.mf)
        self.assertIn('GetProcAddress(t_module,', self.mf)
        self.assertIn('"MFPCreateMediaPlayer"', self.mf)
        # never by a name alone, which searches the stack's folder too
        self.assertNotIn('LoadLibraryW(L"mfplay.dll")', self.mf)
        self.assertNotIn('LoadLibraryA(', self.mf)

    def test_links_no_media_foundation_library(self):
        for text in (self.mf, read('engine', 'src', 'w32-ds-player.cpp'), read('engine', 'engine.gyp'),
                     read('engine', 'engine-sources.gypi')):
            self.assertNotRegex(text, r'(?i)mfplay\.lib|mfplat\.lib|mfuuid\.lib|#pragma\s+comment\s*\(\s*lib')
        # MFPlay's own entry point is only ever called through the pointer
        self.assertNotRegex(self.mf, r'(?<![_\w])MFPCreateMediaPlayer\(')

    def test_uses_nothing_of_the_engines(self):
        includes = re.findall(r'#include\s+[<"]([^>"]+)[>"]', self.mf + read('engine', 'src', 'w32-mf-player.h'))
        self.assertEqual(sorted(set(includes)),
                         ['mfplay.h', 'new', 'objbase.h', 'propidl.h', 'stdint.h', 'w32-mf-player.h', 'windows.h'])

    def test_no_sound_device_still_plays_the_picture(self):
        self.assertIn('t_playback->SetItem(p_path, true, p_wait, p_timeout_ms, t_retry)', self.mf)
        self.assertIn('t_item->SetStreamSelection(i, FALSE)', self.mf)

    def test_events_on_the_engine_thread(self):
        # MFP_OPTION_FREE_THREADED_CALLBACK would call back on a thread of
        # Media Foundation's own, where no script may run
        self.assertNotIn('MFP_OPTION_FREE_THREADED_CALLBACK', self.mf)
        self.assertIn('MFP_OPTION_NONE', self.mf)


MINGW = {'x86_64': 'x86_64-w64-mingw32-g++', 'i686': 'i686-w64-mingw32-g++'}

HARNESS = r'''
#include "w32-mf-player.h"
static void wait_a_moment(void) { MSG m; while (PeekMessageW(&m, NULL, 0, 0, PM_REMOVE)) DispatchMessageW(&m); Sleep(10); }
struct Owner : MCWin32MFPlaybackOwner { void MFPlaybackEnded(void) {} } owner;
int main(void)
{
	MCWin32MFPlayback *t_playback = MCWin32MFPlayback::Open(L"x.mp4", NULL, &owner, wait_a_moment, 1000);
	delete t_playback;
	return 0;
}
'''


class CompileOnItsOwn(unittest.TestCase):
    def compile(self, arch):
        cxx = shutil.which(MINGW[arch])
        if not cxx:
            self.skipTest('%s is not installed' % MINGW[arch])
        work = tempfile.mkdtemp()
        try:
            harness = os.path.join(work, 'harness.cpp')
            with open(harness, 'w') as f:
                f.write(HARNESS)
            exe = os.path.join(work, 'harness.exe')
            proc = subprocess.run([cxx, '-std=c++11', '-DWINVER=0x0601', '-D_WIN32_WINNT=0x0601', '-Wall', '-Wextra',
                                   '-Werror', '-I', SRC, os.path.join(SRC, 'w32-mf-player.cpp'), harness,
                                   '-lole32', '-o', exe],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
            self.assertEqual(proc.returncode, 0, proc.stdout)
            objdump = shutil.which(MINGW[arch].replace('g++', 'objdump'))
            if objdump:
                imports = subprocess.run([objdump, '-p', exe], stdout=subprocess.PIPE,
                                         universal_newlines=True).stdout.lower()
                for dll in ('mfplay.dll', 'mfplat.dll', 'mf.dll'):
                    self.assertNotIn('dll name: %s' % dll, imports)
        finally:
            shutil.rmtree(work, ignore_errors=True)

    def test_x86_64(self):
        self.compile('x86_64')

    def test_i686(self):
        self.compile('i686')


class Workflow(unittest.TestCase):
    def test_gives_the_runner_media_foundation(self):
        workflow = read('.github', 'workflows', 'build-windows.yml')
        step = workflow.index('- name: Media Foundation for the player check')
        check = workflow.index('- name: Browser and player check')
        self.assertLess(step, check)
        self.assertIn('Install-WindowsFeature Server-Media-Foundation', workflow[step:check])
        for dll in media_check.MEDIA_FOUNDATION_DLLS:
            self.assertIn("'%s'" % dll, workflow[step:check])


if __name__ == '__main__':
    unittest.main()
