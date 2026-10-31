script "OXTWebDeployTest"
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

-- Makes a web standalone of the probe stack, for tools/ci/web_check.py,
-- in one of two ways:
--
-- 1. Without the IDE: run with a development engine without a user
--    interface, it makes the standalone's startup data the way the IDE's
--    web builder does (storeDeployedStack in ide-support/
--    revsaveasemscriptenstandalone.livecodescript): a stack file is saved,
--    the startup script is made from the startup template, and
--    "_internal deploy emscripten" writes the data that the web engine
--    reads from /boot/__startup.data. web_check.py puts it into
--    standalone.zip with the template folder.
--       <engine> -ui tools/ci/web-deploy.livecodescript
--
-- 2. With the IDE: named on the IDE's command line, it is opened once the
--    IDE has started (as tools/ci/ui-tour.livecodescript is), waits for
--    the IDE to finish starting, and builds the standalone with the IDE's
--    own web builder (revSaveAsEmscriptenStandalone, as Test does in
--    ide-support/revdeploylibraryemscripten.livecodescript), with the
--    standalone settings a new stack has: the builder searches the
--    stack's scripts for the script libraries it needs (the probe's use
--    of URLs brings in the Internet library and its web driver), and
--    copies the engine and writes the page itself.
--       <IDE engine> tools/ci/web-deploy.livecodescript
--
-- The stack is the probe stack: the script of
-- tools/ci/web-probe.livecodescript (without its first line, the
-- script-only stack's header), with the controls that the probe uses, so
-- that the web engine reads them from a stack file: a button, a field, a
-- filled graphic (which reports a drag across it) and a PNG image. The
-- standalone has the browser widget, which the probe makes when it runs:
-- 1 is given its module (and that of the library it uses), and 2 names it
-- in the standalone settings.
--
-- 1 also makes the stack of tools/ci/web_tests.py, which runs the engine's
-- tests (OXT_WEB_KIND "tests"): the test runner's script
-- (tools/ci/web-tests.livecodescript) in a stack without controls, named
-- StandaloneTestRunnerMainstack as LiveCode's standalone test runner
-- names its own, which tells the test library that it runs in a
-- standalone.
--
-- Environment:
--    OXT_WEB_KIND      1: "tests" for web_tests.py's stack, else the probe
--    OXT_WEB_PROBE     the probe's script (tools/ci/web-probe.livecodescript),
--                      or the test runner's
--    OXT_WEB_STACK     where to save the stack file
--    OXT_WEB_OUTPUT    1: the startup data to write; 2: the folder to build
--                      the standalone in, and with "-fields" after it, the
--                      folder of the one with its fields in the card's grey
--    OXT_WEB_TEMPLATE  1: the startup template
--                      (engine/rsrc/emscripten-startup-template.livecodescript)
--    OXT_WEB_VERSION   1: the web engine's version, which the startup script
--                      checks (the builder puts its own engine's there)
--    OXT_WEB_MODULES   1: the extensions the standalone loads: their
--                      module.lcm files, one a line, each after those it
--                      uses (2: the builder finds them itself)
--    OXT_WEB_LOG       2: the file for the lines below
--
-- 1 writes "DEPLOY OK <output>" or "DEPLOY FAILED <reason>" to stdout and
-- exits with 0 or 1. 2 writes "INFO <name> <value>" lines, then
-- "BUILD OK <folder>" or "BUILD FAILED <reason>" and "DONE" to the log,
-- and leaves the IDE running: web_check.py ends it.

-- A 24x24 PNG, all of it the colour 0,170,0
constant kGreenPNG = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAIAAABvFaqvAAAAHklEQVR42mNgWMVAHTRq0KhBowaNGjRq0KhBA28QADGLfpBqGLo1AAAAAElFTkSuQmCC"

private function fileText pPath
   local tText
   open file pPath for "UTF-8" text read
   if the result is not empty then
      throw "cannot open " & pPath & ": " & the result
   end if
   read from file pPath until end
   put it into tText
   close file pPath
   return tText
end fileText

-- The probe stack, with its script and controls (see the header)
private command makeProbeStack
   local tScript, tStack
   put fileText($OXT_WEB_PROBE) into tScript
   if line 1 of tScript begins with "script " then
      delete line 1 of tScript
   end if
   create stack "WebProbe"
   put the long id of stack "WebProbe" into tStack
   set the label of tStack to "Web Probe"
   set the rect of tStack to 100,100,580,460
   set the backgroundColor of tStack to "#3366CC"
   set the script of tStack to tScript
   -- The handlers that the page can call (document.liveCode.findStackWithName)
   set the cJavascriptHandlers of tStack to "probeFromJS" & return & "probeReport" & return & "probeUnfocus"
   set the defaultStack to "WebProbe"

   create button "Probe Button"
   set the rect of button "Probe Button" to 20,20,160,50
   set the label of button "Probe Button" to "Click me"
   set the script of button "Probe Button" to "on mouseUp" & return & "   probeClicked" & return & "end mouseUp"

   create field "Probe Field"
   set the rect of field "Probe Field" to 20,70,260,100
   set the backgroundColor of field "Probe Field" to "#FFFFFF"
   set the lockText of field "Probe Field" to false
   set the traversalOn of field "Probe Field" to true

   create graphic "Probe Graphic"
   set the style of graphic "Probe Graphic" to "rectangle"
   set the rect of graphic "Probe Graphic" to 300,40,400,140
   set the opaque of graphic "Probe Graphic" to true
   set the lineSize of graphic "Probe Graphic" to 0
   set the backgroundColor of graphic "Probe Graphic" to "#CC3300"
   -- what a drag across it sends (probeDrag)
   set the script of graphic "Probe Graphic" to \
         "on mouseDown" & return & "   probeDrag" && quote & "down" & quote & return & "end mouseDown" & return & \
         "on mouseUp" & return & "   probeDrag" && quote & "up" & quote & return & "end mouseUp" & return & \
         "on mouseRelease" & return & "   probeDrag" && quote & "release" & quote & return & "end mouseRelease"

   create image "Probe Image"
   set the text of image "Probe Image" to base64Decode(kGreenPNG)
   set the rect of image "Probe Image" to 300,200,324,224

   -- drag and drop: a field whose dragStart gives the drag its text, and
   -- an unlocked field that takes it (probeDnd)
   create field "Drag Source"
   set the rect of field "Drag Source" to 20,250,160,280
   set the lockText of field "Drag Source" to true
   set the text of field "Drag Source" to "Drag me"
   set the script of field "Drag Source" to \
         "on dragStart" & return & "   set the dragData[" & quote & "text" & quote & "] to" && quote & "dropped text" & quote & return & \
         "   probeDnd" && quote & "start" & quote & return & "end dragStart" & return & \
         "on dragEnd" & return & "   probeDnd" && quote & "end:" & quote && "& the dragAction" & return & "end dragEnd"

   create field "Drag Target"
   set the rect of field "Drag Target" to 200,250,440,280
   set the backgroundColor of field "Drag Target" to "#FFFFFF"
   set the lockText of field "Drag Target" to false
   set the script of field "Drag Target" to \
         "on dragEnter" & return & "   probeDnd" && quote & "enter" & quote & return & "   pass dragEnter" & return & "end dragEnter" & return & \
         "on dragDrop" & return & "   probeDnd" && quote & "drop:" & quote && "& the dragData[" & quote & "text" & quote & "]" & return & \
         "   pass dragDrop" & return & "end dragDrop"

   -- a graphic that takes files dropped on it from outside the page
   -- (probeDrop)
   create graphic "Drop Zone"
   set the style of graphic "Drop Zone" to "rectangle"
   set the opaque of graphic "Drop Zone" to true
   set the rect of graphic "Drop Zone" to 20,300,160,340
   set the script of graphic "Drop Zone" to \
         "on dragEnter" & return & "   if the dragData[" & quote & "files" & quote & "] is not empty then" & return & \
         "      set the dragAction to" && quote & "copy" & quote & return & "   end if" & return & "end dragEnter" & return & \
         "on dragDrop" & return & "   probeDrop the dragData[" & quote & "files" & quote & "]" & return & "end dragDrop"

   -- a graphic whose mouseDown loops while the mouse is down, then waits
   -- for a click (probeMouseLoop)
   create graphic "Mouse Zone"
   set the style of graphic "Mouse Zone" to "rectangle"
   set the opaque of graphic "Mouse Zone" to true
   set the rect of graphic "Mouse Zone" to 340,150,460,230
   set the script of graphic "Mouse Zone" to "on mouseDown" & return & "   probeMouseLoop" & return & "end mouseDown"

   -- a field of plain and bold text (probeFonts), clear of the points
   -- that the snapshots and the screenshot take colours at
   create field "Font Sample"
   set the rect of field "Font Sample" to 180,290,420,354
   set the backgroundColor of field "Font Sample" to "#FFFFFF"
   set the lockText of field "Font Sample" to true
   set the textSize of field "Font Sample" to 14
end makeProbeStack

-- The test runner's stack (see the header)
private command makeTestsStack
   local tScript
   put fileText($OXT_WEB_PROBE) into tScript
   if line 1 of tScript begins with "script " then
      delete line 1 of tScript
   end if
   create stack "StandaloneTestRunnerMainstack"
   set the script of stack "StandaloneTestRunnerMainstack" to tScript
   set the defaultStack to "StandaloneTestRunnerMainstack"
end makeTestsStack

----------------------------------------------------------------
-- 1. Without the IDE
----------------------------------------------------------------

-- The startup script, as getStartupScript in the builder makes it
private function startupScript
   local tScript
   put fileText($OXT_WEB_TEMPLATE) into tScript
   replace "@ENGINE_VERSION@" with $OXT_WEB_VERSION in tScript
   -- the script that the builder generates for the libraries and
   -- extensions of the standalone; the probe has none
   replace "@STARTUP_SCRIPT@" with empty in tScript
   return tScript
end startupScript

on startup
   local tParams, tResult, tError
   write "INFO engine version=" & the version & " platform=" & the platform & return to stdout
   try
      if $OXT_WEB_VERSION is empty then
         throw "OXT_WEB_VERSION is not set"
      end if
      local tStack
      if $OXT_WEB_KIND is "tests" then
         makeTestsStack
         put "StandaloneTestRunnerMainstack" into tStack
      else
         makeProbeStack
         put "WebProbe" into tStack
      end if
      save stack tStack as $OXT_WEB_STACK
      if the result is not empty then
         throw "cannot save the stack as " & $OXT_WEB_STACK & ": " & the result
      end if
      put startupScript() into tParams["startup_script"]
      put $OXT_WEB_STACK into tParams["stackfile"]
      put $OXT_WEB_OUTPUT into tParams["output"]
      -- as the builder: the deploy command needs the key
      put empty into tParams["engine"]
      -- the externals the standalone loads, as the builder names those of
      -- the web engine's that a stack uses: the probe's use them all
      -- (probeExternals and probeSpeech), the tests none
      if $OXT_WEB_KIND is "tests" then
         put empty into tParams["externals"]
      else
         put "revxml" & return & "revzip" & return & "revdb" & return & "revspeech" into tParams["externals"]
      end if
      -- the extensions, which load before the stack (as the builder lists
      -- them: their module.lcm files, one a line, in the order they load)
      if $OXT_WEB_MODULES is not empty then
         put $OXT_WEB_MODULES into tParams["modules"]
      end if
      _internal deploy emscripten tParams
      put the result into tResult
   catch tError
      put "script error: " & tError into tResult
   end try
   if tResult is empty and there is a file $OXT_WEB_OUTPUT then
      write "DEPLOY OK " & $OXT_WEB_OUTPUT & return to stdout
      quit 0
   end if
   if tResult is empty then
      put "the deploy command wrote no file " & $OXT_WEB_OUTPUT into tResult
   end if
   replace return with " | " in tResult
   write "DEPLOY FAILED " & tResult & return to stdout
   quit 1
end startup

----------------------------------------------------------------
-- 2. With the IDE
----------------------------------------------------------------

local sStarted

on openStack
   if sStarted is not true and the environment is "development" then
      put true into sStarted
      -- out of the way of the IDE's windows
      hide me
      send "webWhenStarted 0" to me in 1 second
   end if
   pass openStack
end openStack

-- Waits until the IDE has finished starting (home.livecodescript sets the
-- cREVLaunching of stack "Home" while it opens its palettes), then a
-- little more for their deferred messages
on webWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then
      put the cREVLaunching of stack "Home" into tLaunching
   end if
   if tLaunching is true and pTries < 240 then
      send "webWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "webBuild" to me in 2 seconds
   end if
end webWhenStarted

private command webLog pLine
   replace return with " | " in pLine
   put pLine & return after url ("binfile:" & $OXT_WEB_LOG)
end webLog

on webBuild
   local tSettings, tFolder, tError, tFieldsSettings, tFieldsFolder
   webLog "INFO version" && the version && the buildNumber
   webLog "INFO platform" && the platform && the processor
   webCatchErrors
   try
      makeProbeStack
      save stack "WebProbe" as $OXT_WEB_STACK
      if the result is not empty then
         throw "cannot save the stack as" && $OXT_WEB_STACK & ":" && the result
      end if
      -- What Test does (deployDo): the stack's standalone settings with
      -- their defaults, which a new stack has
      put revSBGetSettings("WebProbe", true) into tSettings
      put true into tSettings["Emscripten"]
      -- The probe makes a browser widget when it runs: the extension is
      -- named in the settings, as for a stack whose cards have none yet
      -- (the builder finds the widgets on its cards itself)
      if "com.livecode.widget.browser" is not among the lines of tSettings["extensions"] then
         if tSettings["extensions"] is not empty then
            put return after tSettings["extensions"]
         end if
         put "com.livecode.widget.browser" after tSettings["extensions"]
      end if
      webLog "INFO name" && tSettings["name"]
      webLog "INFO inclusions" && tSettings["inclusions"]
      webLog "INFO extensions" && tSettings["extensions"]
      webLog "INFO browser-extension-loaded" && \
            ("com.livecode.widget.browser" is among the lines of the loadedExtensions)
      put $OXT_WEB_OUTPUT into tFolder
      if there is not a folder tFolder then
         create folder tFolder
      end if
      dispatch "revSaveAsEmscriptenStandalone" to stack "revsaveasemscriptenstandalone" \
            with "WebProbe", tFolder, tSettings
      webLog "INFO warnings" && revStandaloneGetWarnings()
      webLog "INFO files" && webFiles(tFolder)
      -- The same standalone with the HTML5 pane's Fields setting at "The
      -- card's grey" (seth's choice 9A of 2026-10-31), in a folder beside
      -- it: web_check.py checks that its page is the one above with the
      -- builder's <meta name="oxt-field-background" content="card">, and
      -- that the web engine draws a field that sets no colour in the
      -- card's grey on it
      put tSettings into tFieldsSettings
      put "card" into tFieldsSettings["emscripten,fieldBackground"]
      put $OXT_WEB_OUTPUT & "-fields" into tFieldsFolder
      if there is not a folder tFieldsFolder then
         create folder tFieldsFolder
      end if
      dispatch "revSaveAsEmscriptenStandalone" to stack "revsaveasemscriptenstandalone" \
            with "WebProbe", tFieldsFolder, tFieldsSettings
      webLog "INFO fields-warnings" && revStandaloneGetWarnings()
      webLog "INFO fields-files" && webFiles(tFieldsFolder)
   catch tError
   end try
   if "revStandaloneProgress" is among the lines of the openStacks then
      close stack "revStandaloneProgress"
   end if
   if tError is empty then
      webLog "BUILD OK" && tFolder
   else
      webLog "BUILD FAILED" && tError
   end if
   webLog "DONE"
end webBuild

private function webFiles pFolder
   local tFiles
   put files(pFolder) into tFiles
   filter tFiles without ".*"
   sort tFiles
   replace return with comma in tFiles
   return tFiles
end webFiles

-- Errors in the IDE's scripts go to the log, not to the IDE's error dialog
-- or the debugger (revTestEnvironment, as the IDE's test runner sets it)
private command webCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      put the defaultStack into tDefault
      set the defaultStack to the short name of me
      lock messages
      create invisible button "oxt_web_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "webScriptError" & quote & " to stack " & quote & the short name of me & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      webLog "INFO catching errors:" && tError
   end try
end webCatchErrors

on webScriptError pError
   webLog "ERROR" && pError
end webScriptError
