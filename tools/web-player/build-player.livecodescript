script "OXTBuildStackPlayer"
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

-- Builds the Stack Player (tools/web-player) with the IDE's own web
-- builder. tools/web-player/build_player.py starts the IDE with this
-- script named on its command line (as tools/ci/web-deploy.livecodescript
-- is started); once the IDE has started, it
--
--   1. makes the stack "Stack Player": the script of
--      tools/web-player/stack-player.livecodescript and the controls it
--      names;
--   2. builds it with revSaveAsEmscriptenStandalone, with every script
--      library (the Data Grid, Geometry, Internet, Animation, Printing,
--      Table and XML-RPC), the externals the web engine has (revXML,
--      revZip, revDB with SQLite, revSpeech) and every widget and library
--      extension installed for the web, so that a stack the player opens
--      finds what its own standalone would carry;
--      it carries the IDE's HyperCard script, disk image and MACE libraries
--      as substacks, so that it opens a HyperCard stack as File > Import
--      Stack does (see makeHyperCardLibraries);
--   3. with OXT_PLAYER_SAMPLES, saves there the stacks that
--      player_check.py opens in the player: they use the Data Grid, a
--      widget, a substack, a script error, revXML, SQLite and a file beside
--      the stack.
--
-- Environment:
--    OXT_PLAYER_SCRIPT   the player's script (stack-player.livecodescript)
--    OXT_PLAYER_OUTPUT   the folder to build the standalone in
--    OXT_PLAYER_SAMPLES  optional: the folder for the sample stacks
--    OXT_PLAYER_LOG      the file for the lines below
--
-- It writes "INFO <name> <value>" lines, then "BUILD OK <folder>" or
-- "BUILD FAILED <reason>" and "DONE" to the log, and leaves the IDE
-- running: build_player.py ends it.

constant kPlayerName = "Stack Player"

local sStarted

on openStack
   if sStarted is not true and the environment is "development" then
      put true into sStarted
      -- out of the way of the IDE's windows
      hide me
      send "playerWhenStarted 0" to me in 1 second
   end if
   pass openStack
end openStack

-- Waits until the IDE has finished starting (home.livecodescript sets the
-- cREVLaunching of stack "Home" while it opens its palettes), then a
-- little more for their deferred messages
on playerWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then
      put the cREVLaunching of stack "Home" into tLaunching
   end if
   if tLaunching is true and pTries < 240 then
      send "playerWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "playerBuild" to me in 2 seconds
   end if
end playerWhenStarted

private command buildLog pLine
   replace return with " | " in pLine
   put pLine & return after url ("binfile:" & $OXT_PLAYER_LOG)
end buildLog

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

on playerBuild
   local tSettings, tFolder, tError
   buildLog "INFO version" && the version && the buildNumber
   buildLog "INFO platform" && the platform && the processor
   buildCatchErrors
   try
      if $OXT_PLAYER_SAMPLES is not empty then
         makeSamples $OXT_PLAYER_SAMPLES
      end if
      makePlayer
      put revSBGetSettings(kPlayerName, true) into tSettings
      put playerSettings(tSettings) into tSettings
      buildLog "INFO scriptLibraries" && tSettings["scriptLibraries"]
      buildLog "INFO databaseDrivers" && tSettings["databaseDrivers"]
      buildLog "INFO extensions" && tSettings["extensions"]
      put $OXT_PLAYER_OUTPUT into tFolder
      if there is not a folder tFolder then
         create folder tFolder
      end if
      dispatch "revSaveAsEmscriptenStandalone" to stack "revsaveasemscriptenstandalone" \
            with kPlayerName, tFolder, tSettings
      buildLog "INFO warnings" && revStandaloneGetWarnings()
      buildLog "INFO files" && buildFiles(tFolder)
   catch tError
   end try
   if "revStandaloneProgress" is among the lines of the openStacks then
      close stack "revStandaloneProgress"
   end if
   if tError is empty then
      buildLog "BUILD OK" && tFolder
   else
      buildLog "BUILD FAILED" && tError
   end if
   buildLog "DONE"
end playerBuild

-- The player's standalone settings: the web target, and everything a
-- stack it opens might use
private function playerSettings pSettings
   local tInclusion, tExtensions, tPlatforms
   put true into pSettings["Emscripten"]
   put "StackPlayer" into pSettings["name"]
   put "Stack Player" into pSettings["emscripten,title"]
   put "select" into pSettings["inclusions"]
   -- the script libraries (revsblibrary's kScriptLibraries), then the
   -- titles of the externals that the web engine has
   -- (revsaveasemscriptenstandalone's kWebExternals)
   put "Animation,DataGrid,Geometry,Internet,Printing,Table,XMLRPC,XML,Database,Revolution Zip,Speech" \
         into pSettings["scriptLibraries"]
   replace comma with return in pSettings["scriptLibraries"]
   put "SQLite" into pSettings["databaseDrivers"]
   -- every widget and library extension that is installed for the web
   repeat for each element tInclusion in revSBAvailableInclusions()
      if tInclusion["type"] is not among the items of "widget,library" then
         next repeat
      end if
      put tInclusion["platforms"] into tPlatforms
      if "Emscripten" is not among the items of tPlatforms then
         next repeat
      end if
      put tInclusion["id"] & return after tExtensions
   end repeat
   delete the last char of tExtensions
   sort lines of tExtensions
   put tExtensions into pSettings["extensions"]
   return pSettings
end playerSettings

----------------------------------------------------------------
-- The player's stack
----------------------------------------------------------------

private command makePlayer
   local tScript, tStack
   put fileText($OXT_PLAYER_SCRIPT) into tScript
   if line 1 of tScript begins with "script " then
      delete line 1 of tScript
   end if
   if there is a stack kPlayerName then
      delete stack kPlayerName
   end if
   create stack kPlayerName
   put the long id of stack kPlayerName into tStack
   set the title of tStack to kPlayerName
   set the rect of tStack to 0,0,720,480
   set the resizable of tStack to false
   set the backgroundColor of tStack to "#F4F1EA"
   set the script of tStack to tScript
   set the cJavascriptHandlers of tStack to "playerFromPage"
   -- the texts of the engine's script errors, which a standalone does not
   -- have (playerErrorText)
   set the cScriptErrors of tStack to the scriptExecutionErrors
   set the defaultStack to kPlayerName

   playerField "Title", "20,20,700,62", 26, "bold"
   put "OXT-Beyond Stack Player" into field "Title"
   playerField "Help", "20,66,700,120", 14, empty
   put "Try a stack in your browser. Open a stack file (.livecode, .oxtstack," && \
         ".rev, .livecodescript), or a folder or .zip with a stack and its files," && \
         "or drop one anywhere on this page." into field "Help"

   create button "Open"
   set the rect of button "Open" to 20,130,200,164
   set the label of button "Open" to "Open a stack..."
   set the script of button "Open" to "on mouseUp" & return & "   playerChoose" & return & "end mouseUp"

   playerField "Library Title", "20,182,500,206", 15, "bold"
   put "Your stacks" into field "Library Title"

   create field "Library"
   set the rect of field "Library" to 20,210,500,410
   set the listBehavior of field "Library" to true
   set the lockText of field "Library" to true
   set the dontWrap of field "Library" to true
   set the vScrollbar of field "Library" to true
   set the textSize of field "Library" to 14
   set the script of field "Library" to "on mouseUp" & return & \
         "   if the hilitedLine of me is not empty then" & return & \
         "      playerLibraryClicked the hilitedLine of me" & return & \
         "   end if" & return & \
         "end mouseUp"

   create button "Forget"
   set the rect of button "Forget" to 520,210,700,240
   set the label of button "Forget" to "Forget the chosen stack"
   set the script of button "Forget" to "on mouseUp" & return & "   playerForgetHilited" & return & "end mouseUp"

   playerField "Status", "20,420,700,470", 13, empty
   set the textColor of field "Status" to "#555555"

   makeHyperCardLibraries tStack

   -- the back script for script errors (see playerInstallErrorHandler)
   create invisible button "Error Handler"
   set the script of button "Error Handler" to \
         "on errorDialog pError" & return & \
         "   dispatch " & quote & "playerReportError" & quote & " to stack " & quote & kPlayerName & quote & \
         " with pError, the long name of the target" & return & \
         "end errorDialog"
   save stack kPlayerName as (specialFolderPath("temporary") & "/StackPlayer.livecode")
end makePlayer

-- The IDE's HyperCard libraries, as invisible substacks of the player
-- under names of their own (the IDE has the originals open): the script
-- library rewrites the scripts of a HyperCard stack the player opens, as
-- File > Import Stack does, and the disk image library reads the stacks
-- on a Mac disk image. The library that the script library gives each
-- stack it fixes is read from a file beside it in the IDE; the player has
-- no such file, so it is kept in a custom property of the substack
-- (revHyperCardLibraryScript reads it from there).
private command makeHyperCardLibraries pPlayer
   local tName
   put "Player HyperCard Scripts" into tName
   create invisible stack tName
   set the mainStack of stack tName to the short name of pPlayer
   set the script of stack tName of pPlayer to the script of stack "revHyperCardScriptLibrary"
   if the result is not empty then
      throw "the HyperCard script library: " & the result
   end if
   set the cHyperCardLibraryScript of stack tName of pPlayer to \
         revHyperCardLibraryScript()
   if the cHyperCardLibraryScript of stack tName of pPlayer is empty then
      throw "the HyperCard library's script is empty"
   end if
   close stack tName of pPlayer

   put "Player HyperCard Disk Images" into tName
   create invisible stack tName
   set the mainStack of stack tName to the short name of pPlayer
   set the script of stack tName of pPlayer to the script of stack "revHyperCardDiskImageLibrary"
   if the result is not empty then
      throw "the HyperCard disk image library: " & the result
   end if
   close stack tName of pPlayer

   -- the MACE decoder (LGPL 2.1 or later, see its header): a stack's
   -- MACE sounds as audio clips
   put "Player HyperCard MACE" into tName
   create invisible stack tName
   set the mainStack of stack tName to the short name of pPlayer
   set the script of stack tName of pPlayer to the script of stack "revHyperCardMACELibrary"
   if the result is not empty then
      throw "the HyperCard MACE library: " & the result
   end if
   close stack tName of pPlayer
   set the defaultStack to the short name of pPlayer
end makeHyperCardLibraries

private command playerField pName, pRect, pSize, pStyle
   create field pName
   set the rect of field pName to pRect
   set the lockText of field pName to true
   set the opaque of field pName to false
   set the showBorder of field pName to false
   set the traversalOn of field pName to false
   set the textSize of field pName to pSize
   if pStyle is not empty then
      set the textStyle of field pName to pStyle
   end if
end playerField

----------------------------------------------------------------
-- The sample stacks that player_check.py opens
----------------------------------------------------------------

private command makeSamples pFolder
   if there is not a folder pFolder then
      create folder pFolder
   end if
   makeTour pFolder & "/Tour.livecode"
   makeGrid pFolder & "/Grid.livecode"
   makeData pFolder & "/Data.livecode"
   makeHyper pFolder & "/Hyper.livecode"
end makeSamples

-- Cards, a palette substack, a script error and a widget
private command makeTour pFile
   local tStack
   create stack "Tour"
   put the long id of stack "Tour" into tStack
   set the rect of tStack to 0,0,480,320
   set the backgroundColor of tStack to "#3366CC"
   set the resizable of tStack to true
   set the defaultStack to "Tour"
   set the script of tStack to \
         "on openStack" & return & \
         "   write " & quote & "SAMPLE tour-openStack" & quote & " & return to stdout" & return & \
         "end openStack" & return & \
         "on resizeStack" & return & \
         "   write " & quote & "SAMPLE tour-resize " & quote & " & the width of this stack & return to stdout" & return & \
         "   pass resizeStack" & return & \
         "end resizeStack"
   sampleLabel "Greeting", "20,18,460,56", 22, "bold"
   put "A desktop stack, in your browser" into field "Greeting"
   create button "Next"
   set the rect of button "Next" to 20,80,150,110
   set the script of button "Next" to "on mouseUp" & return & "   go next card" & return & "end mouseUp"
   create button "Palette"
   set the rect of button "Palette" to 170,80,300,110
   set the script of button "Palette" to "on mouseUp" & return & \
         "   palette stack " & quote & "Tools" & quote & return & \
         "   write " & quote & "SAMPLE palette " & quote & " & the mode of stack " & quote & "Tools" & quote & " & return to stdout" & return & \
         "end mouseUp"
   create button "Error"
   set the rect of button "Error" to 320,80,450,110
   set the script of button "Error" to "on mouseUp" & return & "   put 1 / tNothingHere into tResult" & return & \
         "   put tResult + " & quote & "x" & quote & " into tResult" & return & "end mouseUp"
   -- a widget, from an extension the player carries
   sampleLabel "Tip", "20,128,320,300", 14, empty
   put "Next goes to the second card." & return & return & \
         "Palette opens a substack as a palette window, which you can drag by its title bar." & return & return & \
         "Error makes a script error on purpose: the player shows which object and line." \
         into field "Tip"
   -- a widget, from an extension the player carries
   create widget "Clock" as "com.livecode.widget.clock"
   set the rect of widget "Clock" to 340,150,440,250
   create card
   set the backgroundColor of this card to "#22AA66"
   sampleLabel "Two", "20,18,460,56", 22, "bold"
   put "Card 2" into field "Two"
   sampleLabel "Tip 2", "20,128,460,200", 14, empty
   put "go next card worked. Back returns to the first card, as it would on the desktop." into field "Tip 2"
   create button "Back"
   set the rect of button "Back" to 20,80,150,110
   set the script of button "Back" to "on mouseUp" & return & "   go previous card" & return & "end mouseUp"
   go card 1 of stack "Tour"
   create stack "Tools"
   set the mainStack of stack "Tools" to "Tour"
   set the rect of stack "Tools" to 100,100,260,180
   set the defaultStack to "Tools"
   create button "Hello" in card 1 of stack "Tools"
   set the rect of button "Hello" of card 1 of stack "Tools" to 10,10,150,40
   set the defaultStack to "Tour"
   save stack "Tour" as pFile
   delete stack "Tour"
end makeTour

-- A locked, borderless white label of a sample stack
private command sampleLabel pName, pRect, pSize, pStyle
   create field pName
   set the rect of field pName to pRect
   set the lockText of field pName to true
   set the opaque of field pName to false
   set the showBorder of field pName to false
   set the traversalOn of field pName to false
   set the textColor of field pName to "#FFFFFF"
   set the textSize of field pName to pSize
   if pStyle is not empty then
      set the textStyle of field pName to pStyle
   end if
end sampleLabel

-- A data grid with three rows
private command makeGrid pFile
   local tStack, tGrid
   create stack "Grid"
   put the long id of stack "Grid" into tStack
   set the rect of tStack to 0,0,480,320
   set the defaultStack to "Grid"
   go stack "Grid"
   revIDECreateObject "com.livecode.interface.classic.DataGrid", the long id of card 1 of tStack, "240,160"
   put the long id of group 1 of card 1 of tStack into tGrid
   set the name of tGrid to "People"
   set the rect of tGrid to 20,20,460,300
   set the dgText[true] of tGrid to "Name" & tab & "Age" & return & "Ada" & tab & 36 & return & "Grace" & tab & 85 & return & "Alan" & tab & 41
   -- the stack fills the grid again as it opens, so the check sees the
   -- Data Grid library at work in the browser, not only the saved rows
   local tScript
   put "on openStack" & return & \
         "   local tText" & return & \
         "   set the dgProp[`columns`] of group `People` to `Name` & return & `Age`" & return & \
         "   set the dgText[true] of group `People` to `Name` & tab & `Age` & return & `Ada` & tab & 36 & return & `Grace` & tab & 85 & return & `Alan` & tab & 41" & return & \
         "   put the dgText of group `People` into tText" & return & \
         "   set the itemDelimiter to tab" & return & \
         "   write `SAMPLE grid ` & the dgNumberOfRecords of group `People` & comma & item 1 of line 2 of tText & comma & the number of lines of the dgProp[`columns`] of group `People` & return to stdout" & return & \
         "end openStack" into tScript
   replace "`" with quote in tScript
   set the script of tStack to tScript
   if the result is not empty then
      throw "the Grid sample's script: " & the result
   end if
   save stack "Grid" as pFile
   delete stack "Grid"
end makeGrid

-- revXML, revZip and SQLite, and a file of its own beside it
private command makeData pFile
   local tFolder
   set the itemDelimiter to slash
   put item 1 to -2 of pFile into tFolder
   put "beside the stack" into url ("file:" & tFolder & "/note.txt")
   create stack "Data"
   set the rect of stack "Data" to 0,0,440,240
   set the backgroundColor of stack "Data" to "#1F2A44"
   set the defaultStack to "Data"
   sampleLabel "Heading", "20,16,420,48", 20, "bold"
   put "Files and data" into field "Heading"
   create field "Report"
   set the rect of field "Report" to 20,60,420,220
   set the lockText of field "Report" to true
   set the textSize of field "Report" to 14
   set the margins of field "Report" to 12
   local tScript
   put "on openStack" & return & \
         "   local tTree, tDb, tRows, tXml, tNote, tResource" & return & \
         "   put revXMLCreateTree(`<a><b>xml ok</b></a>`, false, true, false) into tTree" & return & \
         "   put revXMLNodeContents(tTree, `/a/b`) into tXml" & return & \
         "   put revOpenDatabase(`sqlite`, specialFolderPath(`temporary`) & `/d.db`) into tDb" & return & \
         "   revExecuteSQL tDb, `create table t (v text)`" & return & \
         "   revExecuteSQL tDb, `insert into t values ('sql ok')`" & return & \
         "   put revDataFromQuery(,, tDb, `select v from t`) into tRows" & return & \
         "   revCloseDatabase tDb" & return & \
         "   put url `file:note.txt` into tNote" & return & \
         "   put url (`file:` & specialFolderPath(`resources`) & `/note.txt`) into tResource" & return & \
         "   put `revXML read an XML tree:` & tab & tXml & return & \" & return & \
         "         `SQLite answered a query:` & tab & tRows & return & \" & return & \
         "         `A file beside the stack says:` & tab & tNote & return & \" & return & \
         "         `And from the resources folder:` & tab & tResource into field `Report`" & return & \
         "   write `SAMPLE data ` & tXml & comma & tRows & comma & tNote & comma & tResource & return to stdout" & return & \
         "end openStack" into tScript
   replace "`" with quote in tScript
   set the script of stack "Data" to tScript
   if the result is not empty then
      throw "the Data sample's script: " & the result
   end if
   set the tabStops of field "Report" to 230
   save stack "Data" as pFile
   delete stack "Data"
end makeData

-- dynamicPaths true, as a stack imported from HyperCard has it: the
-- player's own handlers must still be found once it is open. Its first
-- card calls an XCMD it does not have, as many HyperCard stacks do: the
-- stack still opens, and the player reports the error
private command makeHyper pFile
   create stack "Hyper"
   set the rect of stack "Hyper" to 0,0,512,342
   set the backgroundColor of stack "Hyper" to "#FFFFFF"
   set the dynamicPaths of stack "Hyper" to true
   set the defaultStack to "Hyper"
   set the script of stack "Hyper" to \
         "on openStack" & return & \
         "   write " & quote & "SAMPLE hyper " & quote & " & the dynamicPaths of this stack & return to stdout" & return & \
         "end openStack"
   set the script of card 1 of stack "Hyper" to \
         "on openCard" & return & "   hyperMissingXCMD" & return & "end openCard"
   create field "Words"
   set the rect of field "Words" to 20,20,492,80
   set the lockText of field "Words" to true
   set the textSize of field "Words" to 18
   put "A stack with dynamicPaths, as HyperCard stacks have" into field "Words"
   create card
   lock messages
   go card 1 of stack "Hyper"
   unlock messages
   save stack "Hyper" as pFile
   delete stack "Hyper"
end makeHyper

private function buildFiles pFolder
   local tFiles
   put files(pFolder) into tFiles
   filter tFiles without ".*"
   sort tFiles
   replace return with comma in tFiles
   return tFiles
end buildFiles

-- Errors in the IDE's scripts go to the log, not to the IDE's error dialog
-- or the debugger (as tools/ci/web-deploy.livecodescript does)
private command buildCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      put the defaultStack into tDefault
      set the defaultStack to the short name of me
      lock messages
      create invisible button "oxt_player_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "buildScriptError" & quote & " to stack " & quote & the short name of me & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      buildLog "INFO catching errors:" && tError
   end try
end buildCatchErrors

on buildScriptError pError
   buildLog "ERROR" && pError
end buildScriptError
