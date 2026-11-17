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

"""A page's liveCode object with CEF (the javascriptHandlers of the browser
widget, revBrowser's JavaScript handlers and the IDE Dictionary's calls).

Until 0.2.8-dp.2 the object came only with the handler list the browser
process sends when a page starts to load (OnLoadStart). With CEF 156 that
message could reach the render process before the new document had its
script context, or reach the process of the page before; on Windows a page
then rarely never had liveCode at all (the "Browser and player check" and
the Dictionary in the IDE screenshots, 2026-11-16). The render process now
keeps the list and gives every new main-frame document liveCode before the
page's own script runs, and asks for the list when it has none.

The behaviour itself is checked with the engine by the media check
(tools/ci/media_check.py, media-check.livecodescript: the widget's second
load of a page calls a handler as the page is read). Here the sources are
held to the parts of the fix, so that none of them goes missing quietly.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)
sys.path.insert(0, os.path.join(os.path.dirname(CI), 'oxt'))

import media_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def method(source, signature):
    """The body of the first method whose line has signature, to its
    closing brace at the method's own indentation."""
    start = source.index(signature)
    line_start = source.rindex('\n', 0, start) + 1
    indent = source[line_start:start]
    end = source.index('\n' + indent + '}\n', start)
    return source[start:end]


class RenderProcess(unittest.TestCase):
    def setUp(self):
        self.source = read('libbrowser', 'src', 'libbrowser_cefprocess.cpp')

    def test_on_context_created_is_on_every_platform(self):
        # It was Linux only (the click listener): the handlers are needed
        # on Windows too
        signature = 'virtual void OnContextCreated('
        self.assertEqual(self.source.count(signature), 1)
        before = self.source[:self.source.index(signature)]
        opened = len(re.findall(r'^#if', before, re.M))
        closed = len(re.findall(r'^#endif', before, re.M))
        self.assertEqual(opened, closed, 'OnContextCreated is inside an #if')

    def test_main_frame_documents_get_the_kept_list_or_ask_for_it(self):
        body = method(self.source, 'virtual void OnContextCreated(')
        self.assertIn('IsMain()', body)
        self.assertIn('m_handler_lists.find(p_browser->GetIdentifier())', body)
        self.assertIn('InstallLiveCodeHandlers(p_browser, p_context,', body)
        self.assertIn('MC_CEFMSG_GET_JS_HANDLER_LIST', body)
        self.assertIn('PID_BROWSER', body)
        # The Linux click listener is still added there
        self.assertIn('AddTakeFocusListener(p_context)', body)

    def test_the_message_keeps_the_list_before_it_installs_it(self):
        body = method(self.source, 'bool SetLiveCodeHandlers(')
        kept = body.index('m_handler_lists[p_browser->GetIdentifier()]')
        installed = body.index('InstallLiveCodeHandlers(')
        self.assertLess(kept, installed)
        # A copy: the message's own list is not kept
        self.assertIn('p_handlers->Copy()', body)

    def test_the_object_is_made_as_before(self):
        # Delete, then a read-only object with one function per handler,
        # as the message always made it
        body = method(self.source, 'bool InstallLiveCodeHandlers(')
        self.assertLess(body.index('DeleteLiveCodeGlobalObj(p_context)'),
                        body.index('GetLiveCodeGlobalObj(p_context, t_livecode_obj)'))
        self.assertIn('AddHandlerList(p_browser, t_livecode_obj, p_handlers)', body)
        self.assertIn('p_context->Exit()', body)
        getter = method(self.source, 'bool GetLiveCodeGlobalObj(')
        self.assertIn('V8_PROPERTY_ATTRIBUTE_READONLY', getter)

    def test_a_closed_browser_is_forgotten(self):
        body = method(self.source, 'virtual void OnBrowserDestroyed(')
        self.assertIn('m_handler_lists.erase(p_browser->GetIdentifier())', body)


class BrowserProcess(unittest.TestCase):
    def setUp(self):
        self.source = read('libbrowser', 'src', 'libbrowser_cef.cpp')
        self.header = read('libbrowser', 'src', 'libbrowser_cef.h')

    def test_the_request_message_is_named_apart(self):
        names = dict(re.findall(r'#define (MC_CEFMSG_\w+) "([^"]+)"', self.header))
        self.assertIn('MC_CEFMSG_GET_JS_HANDLER_LIST', names)
        self.assertEqual(len(set(names.values())), len(names), 'two messages share a name')

    def test_the_browser_answers_a_request_through_the_asking_frame(self):
        start = self.source.index('t_message_name == MC_CEFMSG_GET_JS_HANDLER_LIST')
        branch = self.source[start:self.source.index('else if', start)]
        self.assertIn('p_frame->IsMain()', branch)
        self.assertIn('SyncJavaScriptHandlers(p_frame)', branch)

    def test_load_start_sends_through_the_committed_main_frame(self):
        body = method(self.source, 'virtual void OnLoadStart(')
        self.assertIn('SyncJavaScriptHandlers(p_frame)', body)
        # and through the main frame for an iframe, as before
        self.assertIn('SyncJavaScriptHandlers();', body)

    def test_sending_through_a_frame_sends_the_same_list(self):
        body = method(self.source, 'bool MCCefBrowserBase::SyncJavaScriptHandlers(CefRefPtr<CefFrame> p_frame)')
        self.assertIn('MC_CEFMSG_SET_JS_HANDLER_LIST', body)
        self.assertIn('m_js_handler_list->Copy()', body)
        self.assertIn('p_frame->SendProcessMessage(PID_RENDERER', body)
        # an invalid frame falls back to the main frame
        self.assertIn('return SyncJavaScriptHandlers();', body)


class MediaCheck(unittest.TestCase):
    def test_the_page_calls_a_handler_as_it_is_read(self):
        page = media_check.PAGE
        inline = page.index("liveCode.oxtReport('inline'")
        # before anything else of its script, outside the timer
        self.assertLess(inline, page.index('setTimeout'))
        self.assertLess(inline, page.index("getElementById('h').textContent"))
        # the call still made after the page loaded
        self.assertIn("liveCode.oxtReport('loaded'", page)

    def test_the_widget_loads_the_page_again_and_waits_for_the_inline_call(self):
        script = read('tools', 'ci', 'media-check.livecodescript')
        body = script[script.index('command checkWidget'):script.index('end checkWidget')]
        again = body.index('pUrl & "?again"')
        self.assertLess(body.index('waitFor("oxtReport: loaded", 15)'), again)
        self.assertIn('waitFor("oxtReport: inline ?again"', body[again:])
        self.assertIn('the platform is "Win32" or $OXT_BROWSER_BACKEND is "cef"', body)


if __name__ == '__main__':
    unittest.main()
