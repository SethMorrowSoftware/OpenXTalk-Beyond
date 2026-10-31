script "WebProbe"
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

-- The script of the probe stack that tools/ci/web_check.py opens in a
-- headless browser: tools/ci/web-deploy.livecodescript makes a web
-- standalone of it, with the controls it uses (a button, a field, a filled
-- graphic and a PNG image).
--
-- Each check writes one line to stdout, which the web engine sends to the
-- browser's console (the page's Module.print):
--
--    PROBE <check> PASS <detail>
--    PROBE <check> FAIL <detail>
--    PROBE info <name> <value>
--
-- The checks run from openStack on, with nobody acting but web_check.py,
-- which answers the page's dialogs as they come. Then the probe writes
-- "PROBE ready", and web_check.py does what a user and a page do: it
-- clicks the button (mouseUp writes "PROBE click PASS <count>"), types
-- into the field, holds Shift down, taps the button and drags a finger
-- across the graphic, taps the field and types into it with a touch
-- screen's keyboard, holds the mouse down on the graphic "Mouse Zone"
-- and clicks while its script waits for a click, takes snapshots of the
-- page and drags out the rectangle of one, clicks and types under a
-- modal dialog and into it, drags a palette by its title bar and closes
-- it with its close box, and calls the handlers that the stack's
-- cJavascriptHandlers name: probeFromJS, probeReport and probeUnfocus.
--
-- The checks run only in the web standalone: in the IDE, which opens the
-- stack while it builds the standalone, openStack does nothing more.

local sClicks, sKeys, sLoaded, sLoadedData, sInner, sOrder, sPlayStopped
local sBrowserCalls, sBrowserEvents, sDrag, sDnd, sDrop, sMouseLoop
-- how many systemAppearanceChanged messages the stack had (probeReport
-- "appearance")
local sAppearanceChanges
-- the probe's own backgroundColor while probeColorsOpen's stack is open
local sColorsBack

private command probeLine pText
   write "PROBE " & pText & return to stdout
end probeLine

private command probeCheck pName, pPassed, pDetail
   if pPassed then
      probeLine pName && "PASS" && pDetail
   else
      probeLine pName && "FAIL" && pDetail
   end if
end probeCheck

private command probeInfo pName, pValue
   probeLine "info" && pName && pValue
end probeInfo

on openStack
   local tStart, tElapsed
   if the environment begins with "development" then
      pass openStack
   end if
   probeInfo "version", the version
   probeInfo "environment", the environment
   probeCheck "platform", the platform is "HTML5", the platform
   -- A wait in openStack, at startup: LiveCode's HTML5 engine refused
   -- every wait inside a handler
   put the milliseconds into tStart
   wait 200 milliseconds
   put the milliseconds - tStart into tElapsed
   probeCheck "wait-openstack", tElapsed >= 190, tElapsed & " ms"
   -- The page opened in two tabs (with ?tab=first and ?tab=second) runs
   -- no checks: web_check.py only calls its probeReport, to check that
   -- the two tabs keep each other's files in the home folder
   do "window.location.search" as "JavaScript"
   if the result contains "tab=" then
      exit openStack
   end if
   send "probeRun" to me in 10 milliseconds
end openStack

on probeRun
   local tCheck, tError
   repeat for each item tCheck in "probeWaits,probeSends,probeJavaScript,probeFiles,probeFonts,probeUrls,probeDialogs,probeSystem,probeSound,probePlayer,probeBrowser,probeObjects,probeExternals,probeCiphers,probeSpeech,probePrint"
      try
         dispatch tCheck to me
      catch tError
         probeLine tCheck && "FAIL" && "script error" && line 1 of tError
      end try
   end repeat
   probeLine "ready"
end probeRun

command probeWaits
   local tStart, tElapsed, tDeadline
   -- A wait in a handler that a timer sent
   put the milliseconds into tStart
   wait 100 milliseconds
   put the milliseconds - tStart into tElapsed
   probeCheck "wait-handler", tElapsed >= 95, tElapsed & " ms"

   -- Messages are handled during a wait with messages, and a handler that
   -- one of them runs can wait too (a nested wait)
   put empty into sInner
   send "probeInner" to me in 20 milliseconds
   put the milliseconds into tStart
   wait 400 milliseconds with messages
   put the milliseconds - tStart into tElapsed
   probeCheck "wait-nested", sInner is "done" and tElapsed >= 395, "inner=" & sInner && tElapsed & " ms"

   -- A wait until a condition that a timer makes true
   put empty into sInner
   send "probeSetFlag" to me in 50 milliseconds
   put the milliseconds into tStart
   put tStart + 5000 into tDeadline
   wait until sInner is "flag" or the milliseconds > tDeadline with messages
   put the milliseconds - tStart into tElapsed
   probeCheck "wait-until", sInner is "flag" and tElapsed >= 45, tElapsed & " ms"
end probeWaits

on probeInner
   local tStart
   put the milliseconds into tStart
   wait 50 milliseconds
   if the milliseconds - tStart >= 45 then
      put "done" into sInner
   else
      put "short" into sInner
   end if
end probeInner

on probeSetFlag
   put "flag" into sInner
end probeSetFlag

command probeSends
   put empty into sOrder
   send "probeOrder 3" to me in 60 milliseconds
   send "probeOrder 1" to me in 20 milliseconds
   send "probeOrder 2" to me in 40 milliseconds
   wait 200 milliseconds with messages
   probeCheck "send-in-time", sOrder is "1,2,3", sOrder
end probeSends

on probeOrder pNumber
   if sOrder is empty then
      put pNumber into sOrder
   else
      put comma & pNumber after sOrder
   end if
end probeOrder

command probeJavaScript
   do "6 * 7" as "JavaScript"
   probeCheck "javascript", the result is 42, the result
   do "document.title" as "JavaScript"
   probeInfo "document-title", the result
end probeJavaScript

command probeFiles
   local tData, tStarted, tStopped
   put "hello web" into url "file:/tmp/probe.txt"
   put url "file:/tmp/probe.txt" into tData
   probeCheck "file-roundtrip", tData is "hello web", tData
   probeCheck "standalone-folder", there is a file "/boot/standalone/DroidSansCombined.ttf", the defaultFolder

   -- A font file that the stack starts using (a copy of the standalone's
   -- font) is in use until the stack stops using it; a missing one is not
   put url "binfile:/boot/standalone/DroidSansCombined.ttf" into url "binfile:/tmp/probe-font.ttf"
   start using font file "/tmp/probe-font.ttf"
   put the result & "|" & the fontFilesInUse into tStarted
   stop using font file "/tmp/probe-font.ttf"
   put the result & "|" & the fontFilesInUse into tStopped
   start using font file "/tmp/probe-no-font.ttf"
   probeCheck "font-file", tStarted is "|/tmp/probe-font.ttf" and tStopped is "|" \
         and the result is "can't load font file", \
         "started=" & tStarted && "stopped=" & tStopped && "missing=" & the result
end probeFiles

-- The standalone's fonts (DroidSansCombined.ttf, and DroidSansCombined-
-- Bold.ttf for bold): bold text is wider than plain text, with no font
-- set (the web engine's default), in the standalone's own font, and in a
-- font the page has not got (Arial), which falls back to it. The plain
-- widths go to web_check.py, which holds them to the ones the font of
-- LiveCode's HTML5 standalones gave, so that text wraps where it did.
-- The field "Font Sample" is then left with a plain line and a bold one,
-- with Chinese, Japanese and symbols, for the screenshot.
command probeFonts
   local tFont, tPlain, tBold, tWider, tWidths
   put true into tWider
   put "Hello, World 123" into field "Font Sample"
   repeat for each item tFont in ",Droid Sans,Arial"
      set the textFont of field "Font Sample" to tFont
      set the textStyle of field "Font Sample" to empty
      put the formattedWidth of line 1 of field "Font Sample" into tPlain
      set the textStyle of field "Font Sample" to "bold"
      put the formattedWidth of line 1 of field "Font Sample" into tBold
      put tPlain & ">" & tBold & comma after tWidths
      if tBold <= tPlain then
         put false into tWider
      end if
   end repeat
   delete the last char of tWidths
   probeInfo "font-widths", tWidths
   probeInfo "font-styles", replaceText(fontStyles("Droid Sans", 0), return, comma)
   probeCheck "font-bold", tWider and "bold" is among the lines of fontStyles("Droid Sans", 0), tWidths
   set the textFont of field "Font Sample" to empty
   set the textStyle of field "Font Sample" to empty
   put "Plain: Hello, World" & return & "Bold: Hello, World" & return & \
         numToCodepoint(0x65E5) & numToCodepoint(0x672C) & numToCodepoint(0x8A9E) && \
         numToCodepoint(0x4E2D) & numToCodepoint(0x6587) && numToCodepoint(0x2192) && \
         numToCodepoint(0x2460) && numToCodepoint(0x25B2) into field "Font Sample"
   set the textStyle of line 2 of field "Font Sample" to "bold"
end probeFonts

command probeUrls
   local tOrigin, tData, tResult, tDeadline, tLibUrl, tExpected
   do "window.location.origin" as "JavaScript"
   put the result into tOrigin
   probeInfo "origin", tOrigin

   -- The IDE's builder adds the Internet library (libURL), with its web
   -- driver, to a stack whose scripts use URLs: libURL then loads them,
   -- as on the desktop. Without it, the engine does, as on iOS and
   -- Android.
   put probeUsesLibUrl() into tLibUrl
   probeInfo "backscripts", probeBackScripts()
   if tLibUrl then
      probeInfo "url-path", "libURL"
   else
      probeInfo "url-path", "engine"
   end if

   put url (tOrigin & "/probe-data.txt") into tData
   put the result into tResult
   probeCheck "url-get", tData is "probe data 123" and tResult is empty, "data=" & tData && "result=" & tResult

   -- A post sends a form's data, as on the desktop
   post "a=1&b=2" to url (tOrigin & "/echo")
   put it into tData
   put the result into tResult
   probeCheck "url-post", tData is "POST application/x-www-form-urlencoded a=1&b=2" and tResult is empty, \
         "data=" & tData && "result=" & tResult

   put "stored text" into url (tOrigin & "/store")
   put the result into tResult
   put url (tOrigin & "/store") into tData
   probeCheck "url-put", tData is "stored text" and tResult is empty, "data=" & tData && "result=" & tResult

   -- A page that the server answers with an error status (here 404) is
   -- an error that comes with the page the server sent: libURL's result
   -- is "error 404 Not Found", as on the desktop, and the engine's
   -- "404 Not Found", as on iOS and Android
   put url (tOrigin & "/missing") into tData
   put the result into tResult
   if tLibUrl then
      put "error 404 Not Found" into tExpected
   else
      put "404 Not Found" into tExpected
   end if
   probeCheck "url-missing", tData is "not found" and tResult is tExpected, "data=" & tData && "result=" & tResult

   -- load url: libURL sends the message with the status "cached", and
   -- the page is then in its cache, as on the desktop; the engine sends
   -- "downloaded" and the page, as on iOS and Android
   put empty into sLoaded
   put empty into sLoadedData
   load url (tOrigin & "/probe-data.txt") with message "probeLoaded"
   put the milliseconds + 10000 into tDeadline
   wait until sLoaded is not empty or the milliseconds > tDeadline with messages
   if tLibUrl then
      put url (tOrigin & "/probe-data.txt") into sLoadedData
      probeCheck "url-load", sLoaded is "cached" and sLoadedData is "probe data 123", \
            "status=" & sLoaded && "cached=" & sLoadedData
   else
      probeCheck "url-load", sLoaded is "downloaded" and sLoadedData is "probe data 123", \
            "status=" & sLoaded && "data=" & sLoadedData
   end if
end probeUrls

-- True when libURL loads URLs: its stack is in the back scripts
private function probeUsesLibUrl
   local tObject
   repeat for each line tObject in the backScripts
      if the short name of tObject is "revLibUrl" then
         return true
      end if
   end repeat
   return false
end probeUsesLibUrl

private function probeBackScripts
   local tObject, tNames
   repeat for each line tObject in the backScripts
      if tNames is not empty then
         put comma after tNames
      end if
      put the short name of tObject after tNames
   end repeat
   return tNames
end probeBackScripts

on probeLoaded pUrl, pStatus, pData
   put pStatus into sLoaded
   put pData into sLoadedData
end probeLoaded

command probeDialogs
   -- The page's dialogs, which stand in for the desktop's: web_check.py
   -- clicks each one's default button (the last), typing "Ada" into the
   -- ask dialog's field. As on the desktop, it is the button clicked, and
   -- "OK" for an answer dialog without buttons.
   answer "Hello from the probe"
   probeCheck "answer", it is "OK", it
   answer "Go on?" with "Cancel" or "OK"
   probeCheck "answer-confirm", it is "OK", it
   ask "What is your name?" with "nobody"
   probeCheck "ask", it is "Ada" and the result is empty, it && "result=" & the result
end probeDialogs

command probeSystem
   local tFolder, tMissing, tHost, tCursor, tAlias
   -- The standard folders, which the engine makes in its file system
   repeat for each item tFolder in "home,documents,desktop,preferences,support"
      if there is not a folder specialFolderPath(tFolder) then
         put tFolder & "=" & specialFolderPath(tFolder) & space after tMissing
      end if
   end repeat
   probeCheck "folders", tMissing is empty and specialFolderPath("downloads") is "/downloads", \
         "missing=" & tMissing && "downloads=" & specialFolderPath("downloads")

   -- The home folder is /openxtalk; /livecode, its name until 0.2.7-rc.6.2,
   -- is a link to it, so what a script writes by the old name is in it
   put "by the old name" into url "file:/livecode/Documents/probe-alias.txt"
   put url ("file:" & specialFolderPath("documents") & "/probe-alias.txt") into tAlias
   put "|" & url "file:~livecode/Documents/probe-alias.txt" after tAlias
   delete file "/livecode/Documents/probe-alias.txt"
   probeCheck "home-alias", specialFolderPath("home") is "/openxtalk" \
         and tAlias is "by the old name|by the old name" \
         and there is not a file (specialFolderPath("documents") & "/probe-alias.txt"), \
         "home=" & specialFolderPath("home") && "read=" & tAlias

   -- A file written to /downloads goes to the user as a download, which
   -- web_check.py checks
   put "download me" into url "file:/downloads/probe-download.txt"
   probeCheck "download-written", the result is empty, the result

   -- The address is the page's host and the program's name
   do "window.location.hostname" as "JavaScript"
   put the result into tHost
   probeCheck "address", the address begins with (tHost & ":"), the address
   probeCheck "random-bytes", the length of randomBytes(16) is 16, the length of randomBytes(16)

   -- No key is down yet; web_check.py holds Shift down later
   probeCheck "modifiers", the shiftKey is "up" and the keysDown is empty, \
         "shiftKey=" & the shiftKey && "keysDown=" & the keysDown

   -- The cursor is the canvas's CSS cursor
   set the lockCursor to true
   set the cursor to hand
   do "document.getElementById('canvas').style.cursor" as "JavaScript"
   put the result into tCursor
   set the lockCursor to false
   probeCheck "cursor", tCursor is "pointer", tCursor
end probeSystem

-- An audio clip, from a WAV file: the browser plays its samples (web_check.py
-- checks what it was given), and when they have played, the sound is done
-- and playStopped is sent, as on the desktop. A browser that waits for the
-- user's first click before it makes a sound holds the clip back, and then
-- it has played when it would have ended.
command probeSound
   local tFile, tData, tStart, tDeadline, tPlaying, tAfter, tElapsed
   put specialFolderPath("temporary") & "/probe-sound.wav" into tFile
   -- 0.3 s of a 400 Hz square wave: 8000 samples a second of 8 bits
   repeat 120
      put numToByte(192) & numToByte(192) & numToByte(192) & numToByte(192) & numToByte(192) \
            & numToByte(192) & numToByte(192) & numToByte(192) & numToByte(192) & numToByte(192) \
            & numToByte(64) & numToByte(64) & numToByte(64) & numToByte(64) & numToByte(64) \
            & numToByte(64) & numToByte(64) & numToByte(64) & numToByte(64) & numToByte(64) after tData
   end repeat
   put "RIFF" & probeLittleEndian(36 + 2400, 4) & "WAVE" & "fmt " & probeLittleEndian(16, 4) \
         & probeLittleEndian(1, 2) & probeLittleEndian(1, 2) & probeLittleEndian(8000, 4) \
         & probeLittleEndian(8000, 4) & probeLittleEndian(1, 2) & probeLittleEndian(8, 2) \
         & "data" & probeLittleEndian(2400, 4) & tData into url ("binfile:" & tFile)
   put empty into sPlayStopped
   put the milliseconds into tStart
   play tFile
   put the sound into tPlaying
   put tStart + 5000 into tDeadline
   wait until sPlayStopped is not empty or the milliseconds > tDeadline with messages
   put the milliseconds - tStart into tElapsed
   put the sound into tAfter
   probeCheck "sound", tPlaying is "audioclip" && quote & "probe-sound.wav" & quote and tAfter is "done" \
         and sPlayStopped is "probe-sound.wav" and tElapsed >= 250, \
         "playing=" & tPlaying && "after=" & tAfter && "stopped=" & sPlayStopped && tElapsed & " ms"
end probeSound

private function probeLittleEndian pValue, pBytes
   local tBytes
   repeat pBytes
      put numToByte(pValue mod 256) after tBytes
      put pValue div 256 into pValue
   end repeat
   return tBytes
end probeLittleEndian

-- A player, with the audio clip's WAV file: the page plays it in a video
-- element of its own, and the player has its duration in milliseconds and,
-- at its end, sends playStopped, as on the desktop. Its playLoudness is 0,
-- so the browser plays it before the user's first click (a browser plays
-- a muted movie without one).
command probePlayer
   local tResult, tDuration, tScale, tStart, tDeadline, tElapsed
   put empty into sPlayStopped
   create player "probe-player"
   set the playLoudness of player "probe-player" to 0
   set the filename of player "probe-player" to specialFolderPath("temporary") & "/probe-sound.wav"
   put the result into tResult
   put the duration of player "probe-player" into tDuration
   put the timeScale of player "probe-player" into tScale
   put the milliseconds into tStart
   start player "probe-player"
   put tStart + 5000 into tDeadline
   wait until sPlayStopped is not empty or the milliseconds > tDeadline with messages
   put the milliseconds - tStart into tElapsed
   delete player "probe-player"
   probeCheck "player", tResult is empty and tScale is 1000 and abs(tDuration - 300) <= 20 \
         and sPlayStopped is "probe-player" and tElapsed >= 250, \
         "result=" & tResult && "duration=" & tDuration && "scale=" & tScale \
         && "stopped=" & sPlayStopped && tElapsed & " ms"
end probePlayer

-- An audio clip names itself; a player sends it with no parameter
on playStopped pName
   if pName is empty then
      put the short name of the target into pName
   end if
   put pName into sPlayStopped
end playStopped

-- A browser widget, which the standalone has (web_check.py includes it):
-- the page shows it in a frame. Its htmlText's script calls a handler of
-- its javascriptHandlers, with a number, a string, an array and an object;
-- then it loads a page of the site, as the widget reports (the page calls
-- the handler too), and JavaScript that the stack sends to the page (do
-- ... in widget) calls it once more.
command probeBrowser
   local tStart, tDeadline, tUrl, tHtml, tWanted, tElapsed, tExtensions
   put empty into sBrowserCalls
   put empty into sBrowserEvents
   -- The standalone has the browser widget's extension unless the IDE that
   -- built it had none (on Linux without CEF the IDE leaves the browser
   -- widget out); web_check.py then expects this line, not the check
   put the loadedExtensions into tExtensions
   replace return with comma in tExtensions
   probeInfo "extensions", tExtensions
   if "com.livecode.widget.browser" is not among the items of tExtensions then
      probeInfo "browser-widget", "not loaded"
      exit probeBrowser
   end if
   put the milliseconds into tStart
   put tStart + 20000 into tDeadline
   create widget "Probe Browser" as "com.livecode.widget.browser"
   if there is not a widget "Probe Browser" then
      probeCheck "browser", false, "no browser widget: " & the result
      exit probeBrowser
   end if
   set the rect of widget "Probe Browser" to 20,120,260,300
   set the javascriptHandlers of widget "Probe Browser" to "probeBrowserCall"
   set the htmlText of widget "Probe Browser" to "<!DOCTYPE html><html><body>" & \
         "<script>liveCode.probeBrowserCall(21, 'web', [1, 2], {k: 'v'})</script></body></html>"
   wait until the number of lines of sBrowserCalls >= 1 or the milliseconds > tDeadline with messages
   set the url of widget "Probe Browser" to "probe-page.html"
   wait until the number of lines of sBrowserCalls >= 2 and "complete" is among the words of sBrowserEvents \
         or the milliseconds > tDeadline with messages
   put the url of widget "Probe Browser" into tUrl
   put the htmlText of widget "Probe Browser" into tHtml
   do "liveCode.probeBrowserCall('do', 6 * 7)" in widget "Probe Browser"
   wait until the number of lines of sBrowserCalls >= 3 or the milliseconds > tDeadline with messages
   put the milliseconds - tStart into tElapsed
   delete widget "Probe Browser"
   put "21|web|1,2|k=v" & return & "page|Probe Page" & return & "do|42" into tWanted
   replace return with " / " in sBrowserCalls
   replace return with " / " in tWanted
   probeCheck "browser", sBrowserCalls is tWanted and tUrl ends with "/probe-page.html" \
         and sBrowserEvents is ("begin complete") and "Probe Page" is in tHtml, \
         "calls=" & sBrowserCalls && "events=" & sBrowserEvents && "url=" & tUrl && tElapsed & " ms"
end probeBrowser

-- The page calls this (the javascriptHandlers): each call is a line of the
-- values it was given, an array as its elements or keys and elements
on probeBrowserCall
   local tLine, tIndex, tValue, tKey, tKeys
   repeat with tIndex = 1 to the paramCount
      put param(tIndex) into tValue
      if tIndex > 1 then
         put "|" after tLine
      end if
      if tValue is an array then
         put the keys of tValue into tKeys
         sort tKeys
         repeat for each line tKey in tKeys
            if tKey is not line 1 of tKeys then
               put comma after tLine
            end if
            if tKey is a number then
               put tValue[tKey] after tLine
            else
               put tKey & "=" & tValue[tKey] after tLine
            end if
         end repeat
      else
         put tValue after tLine
      end if
   end repeat
   if sBrowserCalls is not empty then
      put return after sBrowserCalls
   end if
   put tLine after sBrowserCalls
end probeBrowserCall

-- The widget's messages for the page of the site
on browserNavigateBegin pUrl
   if sBrowserEvents is not empty then
      put space after sBrowserEvents
   end if
   put "begin" after sBrowserEvents
end browserNavigateBegin

on browserNavigateComplete pUrl
   if sBrowserEvents is not empty then
      put space after sBrowserEvents
   end if
   put "complete" after sBrowserEvents
end browserNavigateComplete

command probeObjects
   probeCheck "objects", there is a button "Probe Button" and there is a field "Probe Field" \
         and there is a graphic "Probe Graphic" and there is an image "Probe Image", the number of controls
   probeInfo "stack-rect", the rect of this stack
   probeInfo "button-rect", the rect of button "Probe Button"
   probeInfo "field-rect", the rect of field "Probe Field"
   probeInfo "graphic-rect", the rect of graphic "Probe Graphic"
   probeInfo "image-rect", the rect of image "Probe Image"
   probeInfo "drag-source-rect", the rect of field "Drag Source"
   probeInfo "drag-target-rect", the rect of field "Drag Target"
   probeInfo "drop-zone-rect", the rect of graphic "Drop Zone"
   probeInfo "mouse-zone-rect", the rect of graphic "Mouse Zone"
end probeObjects

-- revXML, revZip and revDB with its SQLite driver, which the web engine
-- links into itself (engine/src/em-externals.cpp). The IDE's builder
-- includes them for a stack whose scripts use them, as this one's do, and
-- web-deploy.livecodescript names them when it builds without the IDE.
command probeExternals
   local tTree, tStyleTree, tStyle, tText, tZip, tData, tOut, tResult, tDB, tId, tName, tFile
   put revXMLCreateTree("<root><item id='1'>Hello</item><item id='2'>World</item></root>", false, true, false) into tTree
   put revXMLNodeContents(tTree, "root/item[2]") & comma & revXMLAttribute(tTree, "root/item[1]", "id") \
         & comma & revXMLNumberOfChildren(tTree, "root", "item", 0) into tText
   probeCheck "xml", tTree is a number and tText is "World,1,2", "tree=" & tTree && "values=" & tText

   put revXMLCreateTree("<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>" & \
         "<xsl:output method='text'/><xsl:template match='/'>" & \
         "<xsl:for-each select='root/item'><xsl:value-of select='.'/>;</xsl:for-each>" & \
         "</xsl:template></xsl:stylesheet>", false, true, false) into tStyleTree
   put xsltLoadStylesheet(tStyleTree) into tStyle
   put xsltApplyStylesheet(tTree, tStyle) into tText
   probeCheck "xslt", tText is "Hello;World;", tText
   revXMLDeleteTree tStyleTree
   revXMLDeleteTree tTree

   put "/tmp/probe.zip" into tZip
   put "zipped" && the milliseconds into tData
   revZipOpenArchive tZip, "write"
   revZipAddItemWithData tZip, "folder/a.txt", "tData"
   revZipCloseArchive tZip
   put the result into tResult
   revZipOpenArchive tZip, "read"
   put revZipEnumerateItems(tZip) into tText
   revZipExtractItemToVariable tZip, "folder/a.txt", "tOut"
   revZipCloseArchive tZip
   probeCheck "zip", tResult is empty and line 1 of tText is "folder/a.txt" and tOut is tData, \
         "result=" & tResult && "items=" & line 1 of tText && "extracted=" & tOut

   put revOpenDatabase("sqlite", "/tmp/probe.db") into tDB
   revExecuteSQL tDB, "CREATE TABLE t (id INTEGER, name TEXT)"
   put 1 into tId
   put "one" into tName
   revExecuteSQL tDB, "INSERT INTO t VALUES (:1, :2)", "tId", "tName"
   put revDataFromQuery(",", ";", tDB, "SELECT * FROM t") into tText
   probeCheck "database", tDB is a number and tText is "1,one", "connection=" & tDB && "data=" & tText
   -- SQLite reports an error with a C++ exception, which revDB catches
   put revDataFromQuery(",", ";", tDB, "SELECT * FROM nosuch") into tText
   probeCheck "database-error", tText begins with "revdberr," and tText contains "no such table", tText
   revCloseDatabase tDB

   -- A database in the home folder, which the browser's storage keeps:
   -- SQLite's sync asks for the folder to be written back to it soon
   -- (engine/src/em-system.js), and web_check.py looks for this row there
   put specialFolderPath("documents") & "/probe.db" into tFile
   if there is a file tFile then
      delete file tFile
   end if
   put revOpenDatabase("sqlite", tFile) into tDB
   revExecuteSQL tDB, "CREATE TABLE t (name TEXT)"
   put "kept between visits" into tName
   revExecuteSQL tDB, "INSERT INTO t VALUES (:1)", "tName"
   put revDataFromQuery(",", ";", tDB, "SELECT name FROM t") into tText
   revCloseDatabase tDB
   probeCheck "database-home", tDB is a number and tText is tName, "connection=" & tDB && "data=" & tText
end probeExternals

-- encrypt, decrypt and the cipherNames, with the OpenSSL that the web
-- engine links into itself. The values are the desktop engines'.
command probeCiphers
   local tKey, tIV, tData, tResult, tNames
   put "0123456789abcdef" into tKey
   put "fedcba9876543210" into tIV
   encrypt "Hello, web" using "aes-128-cbc" with key tKey and iv tIV at 128 bit
   put base64Encode(it) into tData
   put the result into tResult
   decrypt base64Decode(tData) using "aes-128-cbc" with key tKey and iv tIV at 128 bit
   probeCheck "encrypt", tData is "CPUtnmCm2X43Wjx2WV6Qtg==" and tResult is empty and it is "Hello, web", \
         "encrypted=" & tData && "decrypted=" & it && "result=" & tResult
   -- Blowfish, one of the ciphers of OpenSSL's legacy provider, with a
   -- key made from a password and a salt
   encrypt "Hello, web" using "bf-cbc" with password "secret" and salt "12345678"
   put base64Encode(it) into tData
   probeCheck "encrypt-legacy", tData is "U2FsdGVkX18xMjM0NTY3OLwmsv4iuE4cuOXag9W4z6s=", \
         "encrypted=" & tData && "result=" & the result
   put the cipherNames into tNames
   probeCheck "cipher-names", "aes-256-cbc,256" is among the lines of tNames \
         and "bf-cbc,128" is among the lines of tNames, the number of lines of tNames && "ciphers"
end probeCiphers

-- revSpeech, which the web engine links into itself and which speaks with
-- the browser's speech synthesis. web_check.py gives the page three voices
-- of its own (headless Chromium has none), one of them named in Japanese,
-- and records what they are asked to say, with the voice, rate, pitch and
-- volume the browser is given: the text below (with an e acute and a euro
-- sign), the voice named in Japanese, and the speed, pitch and volume set
-- here (a rate of 3, a pitch of 0.5 and a volume of 0.5).
command probeSpeech
   local tResult, tVoices, tJapanese, tFemale, tMale, tText, tSpeaking, tVolume, tStopped
   revLoadSpeech
   put the result into tResult
   put revSpeechVoices() into tVoices
   put revSpeechVoices("female") into tFemale
   put revSpeechVoices("male") into tMale
   put "Probe " & numToCodepoint(26085) & numToCodepoint(26412) & numToCodepoint(35486) into tJapanese
   revSetSpeechVoice line 3 of tVoices
   revSetSpeechSpeed 390
   revSetSpeechPitch 120
   revSetSpeechVolume 50
   put "Caf" & numToCodepoint(233) && numToCodepoint(8364) & "1" into tText
   revSpeak tText
   put revIsSpeaking() into tSpeaking
   put revGetSpeechVolume() into tVolume
   revStopSpeech
   put revIsSpeaking() into tStopped
   revUnloadSpeech
   probeCheck "speech", tResult is empty and the number of lines of tVoices is 3 \
         and line 1 of tVoices is "Probe Female Voice" and line 2 of tVoices is "Probe Male Voice" \
         and line 3 of tVoices is tJapanese and tFemale is "Probe Female Voice" \
         and tMale is "Probe Male Voice" and tSpeaking is true and tVolume is 50 and tStopped is false, \
         "load=" & tResult && "voices=" & the number of lines of tVoices && "female=" & tFemale \
         && "male=" & tMale && "japanese=" & (line 3 of tVoices is tJapanese) \
         && "speaking=" & tSpeaking && "volume=" & tVolume && "stopped=" & tStopped
end probeSpeech

-- Printing. The browser prints the pages that the stack prints, in a frame
-- of the page whose print() web_check.py's hook records, with the size of
-- each page and its pixels: two pages here, the card where the layout puts
-- it (at 72,72), and the card at half its size in the page's top left.
-- Printing that is cancelled prints nothing. open printing to pdf writes a
-- PDF, which goes to the user as a download, being in /downloads:
-- web_check.py reads its pages, link, anchor, bookmarks and document
-- information. With the printerOutput set to a file, printing writes a PDF
-- there.
command probePrint
   local tSettings, tAnswer, tStart, tPrinted, tCancelled, tOptions, tPdf, tFile, tFileResult, tData
   put the printerName & "|" & the printPaperSize & "|" & the printRectangle & "|" & \
         the printerFeatures & "|" & the printerOutput into tSettings
   -- The browser's dialog comes when the pages print: answer printer goes on
   answer printer
   put it & "|" & the result into tAnswer

   -- The first page is landscape and the second portrait, taller: the
   -- browser prints pages of different sizes each on its own paper
   put the milliseconds into tStart
   set the printPaperOrientation to "landscape"
   open printing
   print this card
   print break
   set the printPaperOrientation to "portrait"
   print this card into 0,0,240,180
   close printing
   put the result into tPrinted
   probeInfo "print-ms", the milliseconds - tStart

   open printing
   print this card
   cancel printing
   close printing
   put the result into tCancelled

   put the milliseconds into tStart
   put "Probe PDF" into tOptions["title"]
   put "OXT-Beyond" && numToCodepoint(233) into tOptions["Author"]
   open printing to pdf specialFolderPath("downloads") & "/probe.pdf" with options tOptions
   print anchor "Probe" at 72,72
   print link to url "https://example.com/probe" with rect 72,72,552,432
   print bookmark "Probe card" at 72,72
   print this card
   print break
   print link to anchor "probe" with rect 0,0,100,100
   print bookmark "Second page" with level 2
   print this card into 0,0,240,180
   close printing
   put the result into tPdf
   probeInfo "pdf-ms", the milliseconds - tStart

   put specialFolderPath("documents") & "/probe-output.pdf" into tFile
   set the printerOutput to "file:" & tFile
   print this card
   put the result into tFileResult
   set the printerOutput to "device"
   put url ("binfile:" & tFile) into tData

   probeCheck "print", tSettings is "|612,792|0,0,612,792|color|device" and tAnswer is "|" \
         and tPrinted is empty and tCancelled is "Cancel" and tPdf is empty and tFileResult is empty \
         and byte 1 to 8 of tData is "%PDF-1.4" and "/Count 1" is in tData, \
         "settings=" & tSettings && "answer=" & tAnswer && "printed=" & tPrinted && "cancelled=" & tCancelled \
         && "pdf=" & tPdf && "file=" & tFileResult && byte 1 to 8 of tData
end probePrint

command probeClicked
   add 1 to sClicks
   probeLine "click PASS" && sClicks
end probeClicked

-- web_check.py drags a finger across the graphic, whose script calls this
-- with its mouseDown, mouseUp and mouseRelease: sDrag gets each, with the
-- mouseLoc, and the first mouseMove between down and up (see mouseMove)
command probeDrag pWhat
   if pWhat is "down" then
      put empty into sDrag
   end if
   put pWhat & "@" & the mouseLoc & space after sDrag
end probeDrag

on mouseMove pX, pY
   if the last word of sDrag begins with "down@" then
      put "move@" & pX & comma & pY & space after sDrag
   end if
   pass mouseMove
end mouseMove

-- web_check.py holds the mouse down on the graphic "Mouse Zone", whose
-- mouseDown calls this, moves it and lets it go, then clicks: a loop that
-- asks for the mouse until its button goes up, as old stacks drag things,
-- then a wait for a click, which no message is sent for. sMouseLoop gets
-- how many times the loop ran, the last mouseLoc it saw, whether the
-- button went up before the deadline, the clickLoc, and whether the click
-- came before the deadline. (Without the page's events coming in while
-- the loop runs, it would never see the button go up.)
command probeMouseLoop
   local tDeadline, tCount, tLoc
   put the milliseconds + 10000 into tDeadline
   put 0 into tCount
   repeat while the mouse is down and the milliseconds < tDeadline
      add 1 to tCount
      put the mouseLoc into tLoc
   end repeat
   put (tCount > 1) & "|" & tLoc & "|" & (the milliseconds < tDeadline) into sMouseLoop
   put the milliseconds + 10000 into tDeadline
   wait until the mouseClick or the milliseconds > tDeadline
   put "|" & the clickLoc & "|" & (the milliseconds <= tDeadline) after sMouseLoop
end probeMouseLoop

-- web_check.py drags the field "Drag Source" onto the field "Drag
-- Target", whose scripts call this with dragStart, dragEnter, dragDrop
-- and dragEnd: sDnd gets each
command probeDnd pWhat
   if sDnd is not empty then
      put "|" after sDnd
   end if
   put pWhat after sDnd
end probeDnd

-- web_check.py drops a file from outside the page onto the graphic
-- "Drop Zone", whose script calls this with the dragData["files"]: sDrop
-- gets their paths and the first one's text
command probeDrop pFiles
   put pFiles & ":" & url ("file:" & line 1 of pFiles) into sDrop
end probeDrop

-- web_check.py moves the mouse over the graphic and asks for snapshots of
-- what the page shows, as the desktop engines take them of the screen
-- (probeReport("snapshot")): of the graphic, by the stack's window; of
-- the whole stack, by its rect on the screen, at half its size; of the
-- graphic as a PNG; and the colour under the mouse. Each picture's size
-- and the colours of points in it (the graphic's, then the card's), the
-- PNG's first bytes and the mouseColor.
private function probeSnapshots
   local tWindow, tResult, tPng, tError
   put the windowID of stack "WebProbe" into tWindow
   try
      import snapshot from rect (the rect of graphic "Probe Graphic" of stack "WebProbe") of window tWindow
      put probeImage(50, 50) into tResult
      import snapshot from rect (the rect of stack "WebProbe") at size 240,180
      put "|" & probeImage(175, 45, 220, 160) after tResult
      export snapshot from rect (the rect of graphic "Probe Graphic" of stack "WebProbe") of window tWindow to tPng as PNG
      put "|" & (byte 2 to 4 of tPng) & "|" & the mouseColor after tResult
   catch tError
      put "error" && item 1 of tError after tResult
   end try
   return tResult
end probeSnapshots

-- A stack whose colours are all unset (the probe's own set theirs), with
-- one empty field, for probeDefaultColors: opened by one call from the
-- page and read by the next, since a handler the page calls cannot wait
-- for the page to draw it. A mainstack's colours come from the home
-- stack, which in a standalone is its own stack, this one: so this
-- one's blue is taken off until "colors-close" puts it back
private function probeColorsOpen
   local tDefault, tError
   put the defaultStack into tDefault
   try
      if there is a stack "Probe Colors" then
         delete stack "Probe Colors"
      else
         put the backgroundColor of stack "WebProbe" into sColorsBack
      end if
      set the backgroundColor of stack "WebProbe" to empty
      create stack "Probe Colors"
      set the rect of stack "Probe Colors" to 660,0,860,100
      set the defaultStack to "Probe Colors"
      create field "Plain Field"
      set the rect of field "Plain Field" of stack "Probe Colors" to 10,10,190,50
      -- two check boxes that set no colour, for probeCheckBoxColors: one
      -- unticked and one ticked, clear of the two points
      -- probeDefaultColors reads (100,30 and 100,80)
      probeColorsCheckBox "Plain Check", "10,55,90,75", false
      probeColorsCheckBox "Ticked Check", "110,55,190,75", true
      go stack "Probe Colors"
   catch tError
      set the defaultStack to tDefault
      return "error" && item 1 of tError
   end try
   set the defaultStack to tDefault
   return "opened"
end probeColorsOpen

-- One of probeColorsOpen's check boxes, in the default stack
private command probeColorsCheckBox pName, pRect, pTicked
   create button pName
   set the style of button pName of stack "Probe Colors" to "checkbox"
   set the shadow of button pName of stack "Probe Colors" to false
   set the showName of button pName of stack "Probe Colors" to false
   set the rect of button pName of stack "Probe Colors" to pRect
   set the hilite of button pName of stack "Probe Colors" to pTicked
end probeColorsCheckBox

-- The colours of the boxes of probeColorsOpen's two check boxes, which set
-- no colour of their own, from a snapshot of its stack: the snapshot's
-- size, then a point in the middle of the unticked box, one in a corner of
-- the ticked box clear of its tick and one on its tick,
-- 200x100:255,255,255:255,255,255:0,0,0 (a white box and a black tick, in
-- the light appearance). In the dark appearance the boxes are dark and the
-- tick white: a white box there looked ticked (engine/src/buttondraw.cpp,
-- MCButton::drawcheck). The box is CHECK_SIZE (13) points square, at the
-- button's left margin less 2 and in the middle of its height, less its
-- 2-point border; its tick is the polygon drawcheck draws in it
private function probeCheckBoxColors
   local tDefault, tResult, tError, tPlain, tTicked
   if there is not a stack "Probe Colors" then
      return "no stack"
   end if
   put the defaultStack into tDefault
   try
      set the defaultStack to "Probe Colors"
      put probeCheckBoxInside("Plain Check") into tPlain
      put probeCheckBoxInside("Ticked Check") into tTicked
      import snapshot from rect 0,0,200,100 of window (the windowID of stack "Probe Colors")
      put probeImage(item 1 of tPlain + 4, item 2 of tPlain + 4, \
            item 1 of tTicked + 7, item 2 of tTicked + 7, \
            item 1 of tTicked + 4, item 2 of tTicked + 5) into tResult
   catch tError
      put "error" && item 1 of tError into tResult
   end try
   set the defaultStack to tDefault
   return tResult
end probeCheckBoxColors

-- The top left of the inside of a check box's box (drawcheck's trect, less
-- its border): x,y
private function probeCheckBoxInside pName
   local tLeft, tTop
   put the left of button pName + the leftMargin of button pName - 2 + 2 into tLeft
   put the top of button pName + ((the height of button pName - 13) div 2) + 1 + 2 into tTop
   return tLeft & comma & tTop
end probeCheckBoxInside

-- The colours that a field and a card that set none are drawn in (the web
-- engine's theme, engine/src/em-theme.cpp), from a snapshot of the stack
-- that probeColorsOpen opened: the snapshot's size, then the colour of a
-- point in the field and of one on the card,
-- 200x100:255,255,255:240,240,240
private function probeDefaultColors
   local tDefault, tResult, tError
   if there is not a stack "Probe Colors" then
      return "no stack"
   end if
   put the defaultStack into tDefault
   try
      set the defaultStack to "Probe Colors"
      import snapshot from rect 0,0,200,100 of window (the windowID of stack "Probe Colors")
      put probeImage(100, 30, 100, 80) into tResult
   catch tError
      put "error" && item 1 of tError into tResult
   end try
   set the defaultStack to tDefault
   return tResult
end probeDefaultColors

-- The size of the last image and the colours of points in it (x, y, ...),
-- then deletes it: 100x100:204,51,0
private function probeImage
   local tData, tResult, tOffset, tIndex
   put the imageData of last image into tData
   put the width of last image & "x" & the height of last image into tResult
   repeat with tIndex = 1 to the paramCount div 2
      put ((param(tIndex * 2) * the width of last image) + param(tIndex * 2 - 1)) * 4 into tOffset
      put ":" & byteToNum(byte tOffset + 2 of tData) & comma & byteToNum(byte tOffset + 3 of tData) \
            & comma & byteToNum(byte tOffset + 4 of tData) after tResult
   end repeat
   delete last image
   return tResult
end probeImage

-- web_check.py drags out a rectangle on the graphic for "import snapshot"
-- with no rectangle, which waits for it as on the desktop; then it
-- cancels a second one with Escape, and the import fails
-- (probeReport("snapshot-select"))
command probeSnapshotSelect
   local tResult, tError
   try
      import snapshot
      put probeImage(40, 40) into tResult
   catch tError
      put "cancelled" into tResult
   end try
   probeInfo "snapshot-select", tResult
end probeSnapshotSelect

-- web_check.py opens a modal dialog (probeReport("modal")), clicks the
-- button and the field under it and types, which must reach neither,
-- then types into the dialog's field and clicks its OK button: the
-- dialog's field's text, the clicks on the button meanwhile, and whether
-- the field under it has the text it had. The dialog is a stack of its
-- own, so that its keys do not come to this script.
command probeModal
   local tClicks, tText
   if there is not a stack "Probe Dialog" then
      create stack "Probe Dialog"
      set the rect of stack "Probe Dialog" to 0,0,200,120
      set the backgroundColor of stack "Probe Dialog" to "#DDDDDD"
      set the script of stack "Probe Dialog" to "on openStack" & return \
            & "   send" && quote & "probeDialogOpened" & quote && "to stack" && quote & "WebProbe" & quote && "in 0 milliseconds" & return \
            & "end openStack"
      create button "OK" in card 1 of stack "Probe Dialog"
      set the rect of button "OK" of stack "Probe Dialog" to 50,40,150,70
      set the script of button "OK" of stack "Probe Dialog" to "on mouseUp" & return \
            & "   close stack" && quote & "Probe Dialog" & quote & return & "end mouseUp"
      create field "Dialog Field" in card 1 of stack "Probe Dialog"
      set the rect of field "Dialog Field" of stack "Probe Dialog" to 10,80,190,105
      set the backgroundColor of field "Dialog Field" of stack "Probe Dialog" to "#FFFFFF"
      set the lockText of field "Dialog Field" of stack "Probe Dialog" to false
      set the traversalOn of field "Dialog Field" of stack "Probe Dialog" to true
      set the defaultStack to "WebProbe"
   end if
   put sClicks into tClicks
   put the text of field "Probe Field" of stack "WebProbe" into tText
   modal stack "Probe Dialog"
   probeInfo "modal", (the text of field "Dialog Field" of stack "Probe Dialog") & "|" & (sClicks - tClicks) \
         & "|" & (the text of field "Probe Field" of stack "WebProbe" is tText)
end probeModal

-- web_check.py opens a palette (probeReport("window")), see-through by
-- its blendLevel, clicks through it while its ignoreMouseEvents is true
-- (probeReport("window-ignore") and "window-heed"), drags it by the
-- title bar that the page gives its window, and clicks the title bar's
-- close box: the palette's moveStack and closeStackRequest, and its
-- closeStack, report each (probeWindowSaw). It opens below this stack,
-- so that it covers none of it.
command probeWindow
   if there is not a stack "Probe Palette" then
      create stack "Probe Palette"
      set the title of stack "Probe Palette" to "Probe Palette"
      set the rect of stack "Probe Palette" to 20,420,180,500
      set the backgroundColor of stack "Probe Palette" to "#33AA55"
      set the script of stack "Probe Palette" to "on moveStack" & return \
            & "   dispatch" && quote & "probeWindowSaw" & quote && "to stack" && quote & "WebProbe" & quote \
            && "with" && quote & "moved" & quote & ", the rect of me" & return \
            & "end moveStack" & return \
            & "on closeStackRequest" & return \
            & "   dispatch" && quote & "probeWindowSaw" & quote && "to stack" && quote & "WebProbe" & quote \
            && "with" && quote & "request" & quote & return \
            & "   pass closeStackRequest" & return \
            & "end closeStackRequest" & return \
            & "on closeStack" & return \
            & "   dispatch" && quote & "probeWindowSaw" & quote && "to stack" && quote & "WebProbe" & quote \
            && "with" && quote & "closed" & quote & return \
            & "end closeStack"
      set the blendLevel of stack "Probe Palette" to 40
      set the defaultStack to "WebProbe"
   end if
   palette stack "Probe Palette"
   set the defaultStack to "WebProbe"
   probeInfo "window-rect", the rect of stack "Probe Palette"
end probeWindow

-- What the palette heard: "PROBE info window-moved" with its rect after
-- each move, then "window-request" and "window-closed"
command probeWindowSaw pWhat, pRect
   probeInfo "window-" & pWhat, pRect
end probeWindowSaw

-- web_check.py has an option menu (probeReport("menu")), opens it with
-- a click on its button, and clicks the page outside every window, which
-- must close it with no menuPick, as a click outside a menu closes it on
-- the desktop; then it opens it again and closes it the same way, and
-- the button goes (probeReport("menu-done")). Its menuPick would say
-- "PROBE info menu-pick" with the line picked (probeMenuSaw).
command probeMenu
   if there is not a button "Probe Menu" then
      create button "Probe Menu"
      set the style of button "Probe Menu" to "menu"
      set the menuMode of button "Probe Menu" to "option"
      set the text of button "Probe Menu" to "One" & return & "Two" & return & "Three"
      set the rect of button "Probe Menu" to 170,20,290,44
      set the script of button "Probe Menu" to "on menuPick pItem" & return \
            & "   dispatch" && quote & "probeMenuSaw" & quote && "to stack" && quote & "WebProbe" & quote \
            && "with pItem" & return \
            & "end menuPick"
   end if
   probeInfo "menu-rect", the rect of button "Probe Menu"
end probeMenu

command probeMenuSaw pItem
   probeInfo "menu-pick", pItem
end probeMenuSaw

-- Once the dialog is open where the engine put it: where its field and
-- its OK button are on the screen
command probeDialogOpened
   probeInfo "modal-field-rect", probeDialogRect(the rect of field "Dialog Field" of stack "Probe Dialog")
   probeInfo "modal-button-rect", probeDialogRect(the rect of button "OK" of stack "Probe Dialog")
end probeDialogOpened

-- A rect of the dialog's card, on the screen
private function probeDialogRect pRect
   local tLeft, tTop
   put item 1 of the rect of stack "Probe Dialog" into tLeft
   put item 2 of the rect of stack "Probe Dialog" into tTop
   return (item 1 of pRect + tLeft) & comma & (item 2 of pRect + tTop) & comma \
         & (item 3 of pRect + tLeft) & comma & (item 4 of pRect + tTop)
end probeDialogRect

on keyDown pKey
   put pKey after sKeys
   pass keyDown
end keyDown

-- Called from the page. A handler that the page calls runs while the
-- engine is paused, so it cannot wait: the wait fails with an error (as
-- in LiveCode's HTML5 engine), and the handler goes on.
function probeFromJS pValue
   local tWaited, tError
   try
      wait 10 milliseconds
      put "waited" into tWaited
   catch tError
      put "refused" into tWaited
   end try
   probeLine "info js-call value=" & pValue && "wait=" & tWaited
   return pValue * 2
end probeFromJS

-- Called from the page: the field loses the keyboard focus, so a touch
-- screen's keyboard goes away
command probeUnfocus
   focus on nothing
end probeUnfocus

-- Called from the page: what the user did, or with "keys", the keys that
-- are down, with "drag", the drag on the graphic, with "dnd", the drag
-- and drop between the fields and the text of the field it dropped on,
-- with "drop", the file dropped from outside the page, with "mouse", the
-- loop while the mouse was down and the click after it, or with
-- "snapshot", the snapshots of the page (probeSnapshots). With
-- "snapshot-select" and "modal" it starts probeSnapshotSelect and
-- probeModal, which wait for the user: a handler that the page calls
-- cannot. With "window" it opens the palette (probeWindow), and with
-- "window-ignore" and "window-heed" sets the palette's ignoreMouseEvents.
-- With "menu" it makes the option menu (probeMenu), and with "menu-done"
-- deletes it. With "home-write <name>" it writes the file <name>.txt in
-- its documents folder, and with "home-has <name>" says whether that
-- file is there: web_check.py opens the page in two tabs and checks that
-- what one writes there is kept when the other writes too.
function probeReport pWhat
   local tFile
   if word 1 of pWhat is "home-write" or word 1 of pWhat is "home-has" then
      put specialFolderPath("documents") & "/" & word 2 of pWhat & ".txt" into tFile
      if word 1 of pWhat is "home-has" then
         if there is a file tFile then
            return URL ("file:" & tFile)
         end if
         return "none"
      end if
      put "written by" && word 2 of pWhat into URL ("binfile:" & tFile)
      return "written"
   end if
   if pWhat is "snapshot" then
      return probeSnapshots()
   end if
   if pWhat is "window" then
      send "probeWindow" to me in 0 milliseconds
      return "started"
   end if
   if pWhat is "menu" then
      send "probeMenu" to me in 0 milliseconds
      return "started"
   end if
   if pWhat is "menu-done" then
      if there is a button "Probe Menu" then
         delete button "Probe Menu"
      end if
      return "done"
   end if
   if pWhat is "window-ignore" or pWhat is "window-heed" then
      set the ignoreMouseEvents of stack "Probe Palette" to (pWhat is "window-ignore")
      return the ignoreMouseEvents of stack "Probe Palette"
   end if
   if pWhat is "snapshot-select" or pWhat is "modal" then
      if pWhat is "modal" then
         send "probeModal" to me in 0 milliseconds
      else
         send "probeSnapshotSelect" to me in 0 milliseconds
      end if
      return "started"
   end if
   if pWhat is "keys" then
      return the shiftKey & "|" & the keysDown
   end if
   if pWhat is "drag" then
      return word 1 to -1 of sDrag
   end if
   if pWhat is "dnd" then
      return sDnd & "|" & the text of field "Drag Target"
   end if
   if pWhat is "drop" then
      return sDrop
   end if
   if pWhat is "mouse" then
      return sMouseLoop
   end if
   -- the systemAppearance, and how many times it changed (web_check.py
   -- opens the page in a browser set to dark, as built and as a page that
   -- follows the browser's colour scheme)
   if pWhat is "appearance" then
      return the systemAppearance & "," & (sAppearanceChanges + 0)
   end if
   -- the colours of a field and a card that set none (web_check.py opens
   -- the page as built and as a page that asks for fields in the card's
   -- grey): "colors-open" opens a stack for it, "colors" reads them once
   -- the page has drawn it, and "colors-close" deletes it
   if pWhat is "colors-open" then
      return probeColorsOpen()
   end if
   if pWhat is "colors" then
      return probeDefaultColors()
   end if
   -- the colours of the boxes of two check boxes that set none, in the
   -- same stack (web_check.py reads them in a browser set to dark, on the
   -- page as built and on the page that follows the browser)
   if pWhat is "checks" then
      return probeCheckBoxColors()
   end if
   if pWhat is "colors-close" then
      if there is a stack "Probe Colors" then
         delete stack "Probe Colors"
         set the backgroundColor of stack "WebProbe" to sColorsBack
      end if
      return "closed"
   end if
   return the text of field "Probe Field" & "|" & sKeys & "|" & sClicks
end probeReport

on systemAppearanceChanged
   add 1 to sAppearanceChanges
   pass systemAppearanceChanged
end systemAppearanceChanged
