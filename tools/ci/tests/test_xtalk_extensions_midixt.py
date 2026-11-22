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

"""midixt, the xTalk Suite's realtime MIDI library (RtMidi behind
org.openxtalk.library.midi, the id ShowControl's midi extension has always
had, so that its stacks keep working), as tools/oxt/xtalk-extensions.json
bundles it and the web engine links it.

Like gamepadxt it has no Android libraries (RtMidi's Android backend needs
Android 10 and Java code of its own), so the Android probe leaves it out.
Its Linux libraries need ALSA's library, the system's sound and MIDI
service: the checks count it as part of the base system
(tools/ci/check_native_deps.py LINUX_SYSTEM), as they do OpenSSL, and the
launcher's list still names its package, for the browser widget.

On the web it is not RtMidi: the same shim runs over the browser's Web MIDI
(the suite's midixt/src/midi_web.c), whose one JavaScript import only reads
and queues, so the shim and that layer are taken out of Asyncify's
instrumentation, which only a function that never sleeps may be. The
browser check drives it through a stand-in for Web MIDI, since CI's
browsers have no MIDI device and a page that asks for MIDI asks a person.
No network.

  python3 -m unittest discover -s tools/ci/tests
"""

import ast
import fnmatch
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))

import android_check  # noqa: E402
import check_linux_libraries  # noqa: E402
import check_native_deps  # noqa: E402
import xtalk_extensions  # noqa: E402
import xtalk_web_libraries as xwl  # noqa: E402

MODULE = 'org.openxtalk.library.midi'


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def constant(name, text):
    return re.search(r'^constant %s = "([^"]*)"' % re.escape(name), text, re.M).group(1).split(',')


def engine_lists(text):
    """The three lists of em-xtalk-web.cpp, each in the order written"""
    declared = re.findall(r'__attribute__\(\(weak\)\) const MCSLibraryStaticExport \*(\w+)_web_exports\(void\);', text)
    names = re.findall(r'\{ nullptr, "(\w+)", nullptr \},', text)
    table = text[text.index('t_exports[])(void) ='):]
    table = table[:table.index('};')]
    functions = re.findall(r'^\s*(\w+)_web_exports,\s*$', table, re.M)
    return declared, names, functions


def asyncify_remove_list():
    tree = ast.parse(read('util', 'emscripten-javascriptify.py'))
    lists = [ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
             and any(getattr(t, 'id', None) == 'asyncify_remove_xtalk' for t in n.targets)]
    assert len(lists) == 1, lists
    return lists[0]


class MidixtMemberTest(unittest.TestCase):

    def setUp(self):
        self.data = xtalk_extensions.load_manifest()
        self.member = next((m for m in self.data['members'] if m['name'] == 'midixt'), None)
        self.assertIsNotNone(self.member, 'no midixt member in xtalk-extensions.json')

    def test_taken_from_the_suite(self):
        self.assertEqual(self.member['repository'], 'SethMorrowSoftware/xtalk-suite')
        for f in self.member['files']:
            self.assertTrue(f['path'].startswith('midixt/'), f['path'])
        self.assertEqual(self.member['version_from']['path'], 'midixt/src/midi.lcb')

    def test_a_library_for_every_desktop_platform_and_none_for_android(self):
        have = {xtalk_extensions.library_platform(f)
                for f in xtalk_extensions.member_files(self.member, 'library')}
        desktop = {p for p in self.data['platforms'] if not p.endswith('-android')}
        self.assertEqual(have, desktop)

    def test_the_android_probe_leaves_it_out(self):
        found = [m['name'] for m, _, _ in android_check.xtalk_android_extensions(self.data)]
        self.assertNotIn('midixt', found)
        self.assertTrue(found)

    def test_windows_needs_no_runtime_dlls(self):
        # Built with the static CRT (/MT): Windows MM (winmm.dll), through
        # which RtMidi reaches the ports, is a system DLL
        for f in xtalk_extensions.member_files(self.member, 'library'):
            if xtalk_extensions.library_platform(f) in xtalk_extensions.WINDOWS_PLATFORMS:
                self.assertIn('winmm.dll', [d.lower() for d in f['imports']], f['path'])
                extra = [d for d in f['imports'] if not xtalk_extensions.is_system_dll(d)]
                self.assertEqual(extra, [], f['path'])

    def test_one_library_extension_and_its_probe(self):
        exts = [(e['kind'], e['id']) for e in self.member['extensions']]
        self.assertEqual(exts, [('lcb', MODULE)])
        e = self.member['extensions'][0]
        self.assertEqual(e['folder'], MODULE)
        self.assertEqual(e['probe'], 'midiVersion()')
        # What the shim answers: its ABI, which the binding's checkABI()
        # holds to 2
        self.assertRegex('2', e['expect'])
        for other in ('1', '3', '12', '20', '2.0'):
            self.assertNotRegex(other, e['expect'])

    def test_its_licences_are_carried(self):
        # RtMidi's MIT notice is in THIRD-PARTY-LICENSES.md
        paths = [f['path'] for f in xtalk_extensions.member_files(self.member, 'licence')]
        self.assertEqual(paths, ['midixt/LICENSE', 'midixt/THIRD-PARTY-LICENSES.md'])


class AlsaTest(unittest.TestCase):

    def test_alsas_library_is_part_of_the_base_system(self):
        # The library ALSA has shipped since 1.0, and no other name
        self.assertTrue(check_native_deps.LINUX_SYSTEM_RX.match('libasound.so.2'))
        for name in ('libasound.so', 'libasound.so.3', 'libasound.so.2.0.0', 'libasound_module_pcm_pulse.so'):
            self.assertIsNone(check_native_deps.LINUX_SYSTEM_RX.match(name), name)

    def test_the_launchers_list_still_names_its_package(self):
        # The browser widget needs it too: the launcher names its package
        # to a user who lacks it
        libs, problems = check_linux_libraries.read_list(os.path.join(REPO, 'Installer', 'linux', 'libraries.txt'))
        self.assertEqual(problems, [])
        self.assertEqual(libs.get('libasound.so.2'), ('browser', 'libasound2', 'alsa-lib'))


class MidixtWebTest(unittest.TestCase):

    def setUp(self):
        self.libs = {lib['name']: lib for lib in xwl.load()[1]['libraries']}
        self.cpp = read('engine', 'src', 'em-xtalk-web.cpp')
        self.builder = read('ide-support', 'revsaveasemscriptenstandalone.livecodescript')

    def test_the_archive_is_pinned(self):
        self.assertIn('midixt', self.libs)
        lib = self.libs['midixt']
        self.assertEqual(lib['repository'], 'SethMorrowSoftware/xtalk-suite')
        self.assertEqual(lib['path'], 'midixt/src/code/wasm32-emscripten/midixt.a')
        # one compiler for everything linked into one module
        self.assertEqual(lib['emscripten'], xwl.emscripten_version())

    def test_the_engine_registers_it_by_one_index(self):
        declared, names, functions = engine_lists(self.cpp)
        for found in (declared, names, functions):
            self.assertEqual(found.count('midixt'), 1, found)
        # The name row and the function row are read by the same index
        self.assertEqual(names.index('midixt'), functions.index('midixt'))

    def test_a_row_out_of_step_is_seen(self):
        # The reader above must see a function row that is missing
        _, names, functions = engine_lists(self.cpp.replace('\t\tmidixt_web_exports,\n', ''))
        self.assertIn('midixt', names)
        self.assertNotIn('midixt', functions)

    def test_the_fetcher_and_the_standalone_builder_know_it(self):
        self.assertIn('midixt', xwl.KNOWN)
        self.assertEqual(tuple(constant('kXTalkWebLibraries', self.builder)), xwl.KNOWN)
        self.assertIn(MODULE, constant('kXTalkWebExtensions', self.builder))

    def test_asyncify_leaves_out_the_shim_and_its_web_layer(self):
        # Their functions never sleep: the browser's events wait in a
        # JavaScript queue that midiPoll drains, and nothing is called
        # through a pointer. Instrumented, each poll and send would only be
        # slower
        patterns = asyncify_remove_list()
        for name in ('midi_in_drain_bytes', 'midi_out_send', 'midi_in_count', 'midi_close',
                     'rtmidi_in_get_message', 'rtmidi_open_port', 'rtmidi_out_send_message'):
            self.assertTrue(any(fnmatch.fnmatchcase(name, p) for p in patterns), name)

    def test_its_patterns_reach_nothing_of_the_engines(self):
        # A function taken out of Asyncify's instrumentation that sleeps
        # stops the engine: no C or C++ source of the engine and its
        # libraries may define a name that midixt's patterns reach
        defined = re.compile(r'\b(?:rtmidi|midi)_\w+\s*\(')
        found = []
        for top in ('engine', 'libfoundation', 'libscript', 'libgraphics', 'libbrowser'):
            for folder, _, files in os.walk(os.path.join(REPO, top)):
                for name in files:
                    if name.endswith(('.c', '.cpp', '.cc', '.h', '.hpp', '.mm', '.m')):
                        path = os.path.join(folder, name)
                        with open(path, encoding='utf-8', errors='replace') as f:
                            if defined.search(f.read()):
                                found.append(os.path.relpath(path, REPO))
        self.assertEqual(found, [])

    def test_the_browser_check_has_its_step(self):
        check = read('tools', 'ci', 'web-ide-xtalk.livecodescript')
        steps = constant('kSteps', check)
        self.assertIn('midi', steps)
        # before the steps that need a network, so a relay that is down
        # cannot hide it
        self.assertLess(steps.index('midi'), steps.index('nostr'))
        body = re.search(r'(?ms)^on xt_midi\b(.*?)^end xt_midi', check)
        self.assertIsNotNone(body, 'no xt_midi handler')
        body = body.group(1)
        for call in ('midiVersion', 'midiDecode', 'midiOpenVirtualInput', 'midiInputPorts', 'midiOutputPorts',
                     'midiOpenInput', 'midiOpenOutput', 'midiNoteOn', 'midiControlChange', 'midiSend',
                     'midiIgnoreTypes', 'midiPoll', 'midiClose', 'midiLastError'):
            self.assertIn(call, body, call)
        # The stand-in takes the browser's place before midixt first asks:
        # the real question would wait for a person
        self.assertLess(body.index('xtMidiStandIn()'), body.index('midiOpenVirtualInput'))
        self.assertLess(body.index('xtMidiStandIn()'), body.index('midiInputPorts()'))

    def test_the_stand_in_is_what_the_web_layer_asks_for(self):
        # What src/midi_web.c uses of Web MIDI, each in the stand-in
        check = read('tools', 'ci', 'web-ide-xtalk.livecodescript')
        body = re.search(r'(?ms)^function xtMidiStandIn\b(.*?)^end xtMidiStandIn', check)
        self.assertIsNotNone(body, 'no xtMidiStandIn function')
        js = ''.join(re.findall(r'"([^"]*)"', body.group(1)))
        for used in ("'requestMIDIAccess'", 'inputs:new Map', 'outputs:new Map', "this.state='connected'",
                     'addEventListener', 'removeEventListener', '.open=function', '.close=function',
                     'output.send=function', 'timeStamp:', 'sysex'):
            self.assertIn(used, js, used)


if __name__ == '__main__':
    unittest.main()
