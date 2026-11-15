script "OXTBrowserCompat"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- What a script sees of the browser's htmlText and url, written down so
-- that two builds can be compared line by line: the CEF the browser is
-- built on can change (CEF 74 to 156), and none of this may change with it
-- (CLAUDE.md, "no breaking changes"). tools/ci/browser_compat_check.py
-- copies a runtime of an installed layout to a folder of its own, serves
-- two pages and runs
--
--    <standalone engine> tools/ci/browser-compat-check.livecodescript
--
-- (on Linux under Xvfb), then compares the lines with those of the
-- release before (tools/ci/browser-compat/<platform>.txt). Environment:
--    OXT_COMPAT_LOG        the file to append the lines to (OBS, INFO,
--                          DONE); a standalone with a user interface has
--                          no reliable stdout on Windows
--    OXT_COMPAT_WHAT       comma-separated: widget, revbrowser
--    OXT_COMPAT_BASE       the URL of the folder the pages are served from,
--                          ending in "/" (page1.html and page2.html)
--    OXT_COMPAT_EXTENSIONS the Extensions folder with the browser widget
--                          and com.livecode.library.widgetutils
--    OXT_COMPAT_REVBROWSER the revbrowser external (.so or .dll)
--
-- Every OBS line is "OBS <step>: <what> = <value>", the value on one line.
-- The served URLs differ from run to run (a new port each time), so the
-- base is written as {BASE}. The browser's own version (its user agent)
-- is not written: it is what changes.

local sEvents, sBase, sReports

command logLine pText
   -- (as UTF-8: the pages hold text outside the native encoding)
   put textEncode(pText & return, "UTF-8") after URL ("binfile:" & $OXT_COMPAT_LOG)
end logLine

function oneLine pValue
   replace sBase with "{BASE}" in pValue
   replace crlf with "\r\n" in pValue
   replace return with "\n" in pValue
   replace numToChar(13) with "\r" in pValue
   replace tab with "\t" in pValue
   return pValue
end oneLine

command obs pStep, pWhat, pValue
   logLine "OBS " & pStep & ": " & pWhat & " = " & oneLine(pValue)
end obs

-- Called by the test stack's script with every message it is sent
command compatEvent pEvent
   put pEvent & return after sEvents
end compatEvent

-- Called by the test stack's script with what a page's JavaScript reports
command compatReport pReport
   put pReport & return after sReports
end compatReport

-- Waits until pEvent has come (or pSeconds have passed), then for the
-- messages that follow it to settle: what the browser sends after a load
-- is part of what is compared
function waitFor pEvent, pSeconds
   put the milliseconds + pSeconds * 1000 into tEnd
   repeat while the milliseconds < tEnd
      if sEvents contains pEvent then exit repeat
      wait 100 milliseconds with messages
   end repeat
   wait 1500 milliseconds with messages
   return sEvents contains pEvent
end waitFor

function waitForReport pCount, pSeconds
   put the milliseconds + pSeconds * 1000 into tEnd
   repeat while the milliseconds < tEnd
      if the number of lines of sReports >= pCount then exit repeat
      wait 100 milliseconds with messages
   end repeat
   wait 500 milliseconds with messages
   return sReports
end waitForReport

-- The messages since the step began, in the order they came, each once
-- (CEF may send a message twice in a row; the order of the kinds is what a
-- script relies on)
function eventList
   local tSeen, tList
   repeat for each line tLine in sEvents
      if tLine is empty then next repeat
      if tLine is among the lines of tSeen then next repeat
      put tLine & return after tSeen
      put tLine & " ; " after tList
   end repeat
   delete char -3 to -1 of tList
   return tList
end eventList

private function stackScript
   local tScript
   repeat for each item tMessage in "browserDocumentLoadBegin,browserDocumentLoadComplete,browserDocumentLoadFailed," & \
         "browserFrameDocumentLoadBegin,browserFrameDocumentLoadComplete,browserFrameDocumentLoadFailed," & \
         "browserNavigateBegin,browserNavigateComplete,browserNavigateFailed," & \
         "browserBeforeNavigate,browserDocumentComplete,browserDocumentFailed,browserNavigateCompleteFrame," & \
         "browserDocumentCompleteFrame,browserBeforeNavigateFrame,browserNewUrlWindow,browserLoadRequest," & \
         "browserLoadRequestFrame,browserUnhandledLoadRequest"
      put "on" && tMessage && "p1, p2" & return after tScript
      put "   dispatch" && quote & "compatEvent" & quote && "to stack" && quote & "OXTBrowserCompat" & quote && \
            "with" && quote & tMessage & ":" & quote && "&& p1 && p2" & return after tScript
      put "end" && tMessage & return after tScript
   end repeat
   put "on oxtReport p1" & return after tScript
   put "   dispatch" && quote & "compatReport" & quote && "to stack" && quote & "OXTBrowserCompat" & quote && "with p1" & return after tScript
   put "end oxtReport" & return after tScript
   -- revBrowser calls a JavaScript handler with its arguments in an array
   put "on oxtRevReport p1" & return after tScript
   put "   dispatch" && quote & "compatReport" & quote && "to stack" && quote & "OXTBrowserCompat" & quote && "with p1" & return after tScript
   put "end oxtRevReport" & return after tScript
   return tScript
end stackScript

-- A page given as htmlText that reports where it thinks it is: these are
-- what a data: URL in place of CEF's LoadString would change (the
-- document's URL, its base for relative links, its origin and so its
-- storage)
function probePage pCallback, pTag
   local tPage, tJs
   put "<!DOCTYPE html><html><head><meta charset=" & quote & "utf-8" & quote & ">" into tPage
   put "<title>compat " & pTag & "</title></head><body>" after tPage
   put "<p id=" & quote & "p" & quote & ">caf" & numToCodepoint(233) & " " after tPage
   put numToCodepoint(20013) & numToCodepoint(25991) & " " & numToCodepoint(128512) & "</p>" after tPage
   put "<a id=" & quote & "a" & quote & " href=" & quote & "page2.html?x=1#y" & quote & ">rel</a>" after tPage
   put "function oxtProbe(){var r=[];" & return into tJs
   put "r.push('href='+location.href);" & return after tJs
   put "r.push('protocol='+location.protocol);" & return after tJs
   put "r.push('baseURI='+document.baseURI);" & return after tJs
   put "r.push('origin='+window.origin);" & return after tJs
   put "r.push('link='+document.getElementById('a').href);" & return after tJs
   put "r.push('title='+document.title);" & return after tJs
   put "r.push('text='+document.getElementById('p').textContent);" & return after tJs
   put "var s='none';try{localStorage.setItem('oxt','1');s='localStorage ok';}catch(e){s='localStorage '+e.name;}r.push(s);" & return after tJs
   put "var c='none';try{document.cookie='oxt=1';c='cookie '+(document.cookie.indexOf('oxt=1')>=0?'kept':'dropped');}catch(e){c='cookie '+e.name;}r.push(c);" & return after tJs
   put "r.push('referrer='+document.referrer);" & return after tJs
   put "r.push('history='+history.length);" & return after tJs
   put "return r.join(' | ');}" & return after tJs
   put "setTimeout(function(){if(window.liveCode&&liveCode." & pCallback & ")liveCode." & pCallback & "(oxtProbe());},300);" & return after tJs
   put "<script>" & return & tJs & "</script></body></html>" after tPage
   return tPage
end probePage

on startup
   put empty into sEvents
   put empty into sReports
   put $OXT_COMPAT_BASE into sBase
   put $OXT_COMPAT_WHAT into tWhat
   if tWhat is empty then put "widget,revbrowser" into tWhat
   logLine "INFO platform=" & the platform & " version=" & the version & " processor=" & the processor
   try
      create stack "BrowserCompat"
      set the script of stack "BrowserCompat" to stackScript()
      set the rect of stack "BrowserCompat" to 100,100,740,580
      go stack "BrowserCompat"
      wait 500 milliseconds with messages
      if "widget" is among the items of tWhat then compatWidget
      if "revbrowser" is among the items of tWhat then compatRevBrowser
   catch tError
      logLine "INFO script error: " & oneLine(tError)
   end try
   logLine "DONE"
   quit 0
end startup

-- The browser widget ---------------------------------------------------

command widgetStep pStep
   put empty into sEvents
   put empty into sReports
end widgetStep

command widgetState pStep
   obs pStep, "url", the url of widget "Browser" of stack "BrowserCompat"
   obs pStep, "htmlText", the htmlText of widget "Browser" of stack "BrowserCompat"
   obs pStep, "messages", eventList()
end widgetState

command compatWidget
   load extension from file ($OXT_COMPAT_EXTENSIONS & "/com.livecode.library.widgetutils/module.lcm")
   load extension from file ($OXT_COMPAT_EXTENSIONS & "/com.livecode.widget.browser/module.lcm")
   put the result into tResult
   if tResult is not empty then
      logLine "INFO widget: the extension does not load: " & tResult
      exit compatWidget
   end if

   widgetStep "w1 new"
   create widget "Browser" as "com.livecode.widget.browser" in card 1 of stack "BrowserCompat"
   set the rect of widget "Browser" of stack "BrowserCompat" to 0,0,640,400
   set the javascriptHandlers of widget "Browser" of stack "BrowserCompat" to "oxtReport"
   wait 2 seconds with messages
   widgetState "w1 new"

   -- htmlText given: the page, where it is, and what the url says
   widgetStep "w2 htmlText"
   set the htmlText of widget "Browser" of stack "BrowserCompat" to probePage("oxtReport", "w2")
   obs "w2 htmlText", "page reports", waitForReport(1, 20)
   put waitFor("zz-never", 0) into tIgnored
   widgetState "w2 htmlText"

   -- The same htmlText again (CEF 74 reloads the dummy URL)
   widgetStep "w3 htmlText again"
   set the htmlText of widget "Browser" of stack "BrowserCompat" to probePage("oxtReport", "w3")
   obs "w3 htmlText again", "page reports", waitForReport(1, 20)
   widgetState "w3 htmlText again"

   -- A url, then htmlText over it, then the url again
   widgetStep "w4 url"
   set the url of widget "Browser" of stack "BrowserCompat" to sBase & "page1.html"
   put waitFor("browserDocumentLoadComplete:", 30) into tIgnored
   widgetState "w4 url"

   widgetStep "w5 htmlText after url"
   set the htmlText of widget "Browser" of stack "BrowserCompat" to probePage("oxtReport", "w5")
   obs "w5 htmlText after url", "page reports", waitForReport(1, 20)
   widgetState "w5 htmlText after url"

   widgetStep "w6 url after htmlText"
   set the url of widget "Browser" of stack "BrowserCompat" to sBase & "page2.html"
   put waitFor("browserDocumentLoadComplete:", 30) into tIgnored
   widgetState "w6 url after htmlText"

   -- Empty htmlText (CEF crashed on an empty string: libbrowser loads an
   -- empty page in its place) and an empty url
   widgetStep "w7 empty htmlText"
   set the htmlText of widget "Browser" of stack "BrowserCompat" to empty
   wait 3 seconds with messages
   widgetState "w7 empty htmlText"

   widgetStep "w8 url to empty"
   set the url of widget "Browser" of stack "BrowserCompat" to sBase & "page1.html"
   put waitFor("browserDocumentLoadComplete:", 30) into tIgnored
   set the url of widget "Browser" of stack "BrowserCompat" to empty
   wait 3 seconds with messages
   widgetState "w8 url to empty"

   -- htmlText that is not a whole document
   widgetStep "w9 fragment"
   set the htmlText of widget "Browser" of stack "BrowserCompat" to "<b>bold</b> text"
   wait 3 seconds with messages
   widgetState "w9 fragment"

   -- A click on the relative link of an htmlText page: where it goes
   widgetStep "w10 relative link"
   set the htmlText of widget "Browser" of stack "BrowserCompat" to probePage("oxtReport", "w10")
   put waitForReport(1, 20) into tIgnored
   widgetStep "w10 relative link"
   do "document.getElementById('a').click();" in widget "Browser" of stack "BrowserCompat"
   wait 4 seconds with messages
   widgetState "w10 relative link"

   delete widget "Browser" of stack "BrowserCompat"
end compatWidget

-- revBrowser -------------------------------------------------------------

command revState pStep, pId
   obs pStep, "url", revBrowserGet(pId, "url")
   obs pStep, "htmltext", revBrowserGet(pId, "htmltext")
   obs pStep, "busy", revBrowserGet(pId, "busy")
   obs pStep, "messages", eventList()
end revState

command compatRevBrowser
   put specialFolderPath("temporary") & "/oxt-browser-compat-externals.livecode" into tFile
   create stack "RevBrowserHost"
   set the externals of stack "RevBrowserHost" to $OXT_COMPAT_REVBROWSER
   save stack "RevBrowserHost" as tFile
   delete stack "RevBrowserHost"
   start using stack tFile
   if "revBrowser" is not among the lines of the externalPackages of stack "RevBrowserHost" then
      logLine "INFO revBrowser: the external does not load: " & oneLine(the externalPackages of stack "RevBrowserHost")
      exit compatRevBrowser
   end if

   put empty into sEvents
   put empty into sReports
   try
      put revBrowserOpenCef(the windowID of stack "BrowserCompat", sBase & "page1.html") into tId
   catch tError
      put tError into tId
   end try
   if tId is not an integer then
      logLine "INFO revBrowser: no browser: " & oneLine(tId)
      exit compatRevBrowser
   end if
   revBrowserSet tId, "rect", "0,0,640,400"
   revBrowserAddJavaScriptHandler tId, "oxtRevReport"
   put waitFor("browserDocumentComplete:", 30) into tIgnored
   revState "r1 open with url", tId

   put empty into sEvents
   put empty into sReports
   revBrowserSet tId, "htmltext", probePage("oxtRevReport", "r2")
   obs "r2 htmltext", "page reports", waitForReport(1, 20)
   try
      put revBrowserExecuteScript(tId, "result = oxtProbe();") into tProbe
   catch tError
      put "error" into tProbe
   end try
   obs "r2 htmltext", "page probe", tProbe
   revState "r2 htmltext", tId

   put empty into sEvents
   put empty into sReports
   revBrowserSet tId, "url", sBase & "page2.html"
   put waitFor("browserDocumentComplete:", 30) into tIgnored
   revState "r3 url after htmltext", tId

   put empty into sEvents
   put empty into sReports
   revBrowserSet tId, "htmltext", empty
   wait 3 seconds with messages
   revState "r4 empty htmltext", tId

   put empty into sEvents
   put empty into sReports
   revBrowserSet tId, "htmltext", "<b>bold</b> text"
   wait 3 seconds with messages
   revState "r5 fragment", tId

   put empty into sEvents
   put empty into sReports
   revBrowserSet tId, "htmltext", probePage("oxtRevReport", "r6")
   put waitForReport(1, 20) into tIgnored
   put empty into sEvents
   try
      put revBrowserExecuteScript(tId, "document.getElementById('a').click(); result = 'clicked';") into tClicked
   catch tError
      put "error" into tClicked
   end try
   obs "r6 relative link", "executeScript", tClicked
   wait 4 seconds with messages
   -- (not its htmltext: revBrowser can wait for ever for the source of
   -- Chromium's error page, with CEF 74 as released)
   obs "r6 relative link", "url", revBrowserGet(tId, "url")
   obs "r6 relative link", "messages", eventList()

   revBrowserClose tId
end compatRevBrowser
