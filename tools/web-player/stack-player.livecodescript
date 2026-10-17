script "StackPlayer"
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

-- The script of the Stack Player: a web standalone (tools/web-player)
-- that opens any stack the user gives it. tools/web-player/
-- build-player.livecodescript makes the stack "Stack Player" with this
-- script and the controls it names, and builds it with the IDE's web
-- builder with every script library and extension the web engine has, so
-- that the stacks it opens find them as they would in their own
-- standalone.
--
-- A stack comes from the Open button (answer files), from files or a
-- folder dropped on the page, or from the list of stacks opened before. A
-- zip archive is unpacked first. Each one is copied into the player's
-- library, a folder in the home folder, which the browser keeps between
-- visits: a stack that saves itself saves there, and the list shows it
-- the next time. The stack then takes the page's window (go ... in window,
-- with the defaultFolder its own folder, so that its relative paths find
-- the files that came with it), or a window of its own with ?mode=window.
--
-- The page (tools/web-player/index.html) draws the player's home, its
-- library and its bar in HTML: its buttons call playerFromPage (one of
-- the cJavascriptHandlers), files the page is given are written to
-- /uploads and handed over the same way, and the player tells the page
-- what happened through window.oxtPlayer.event (the library, what is
-- open, what went wrong). The player's own card is what a page without
-- that script, or ?mode=window, shows.
--
-- Nothing here changes the engine: everything is script that any web
-- standalone could run.

-- The stack that has the page's window (its short name), its file, and
-- the main stacks that were in memory before it opened (those loaded
-- since are its own, and go when the player goes home)
local sCurrent, sCurrentFile, sStacksBefore
-- "page" (the stack takes the page's window) or "window"
local sMode
-- The stack files found in the last folder or archive the user gave
local sChoices
local sStarted
-- What the page asked for, for playerDo in the engine's next turn
local sPageArgs

constant kStackExtensions = "livecode,oxtstack,rev,mc,livecodescript,lc,stack"
constant kLibraryName = "Stack Player"

----------------------------------------------------------------
-- Start-up
----------------------------------------------------------------

on openStack
   if not sStarted then
      put true into sStarted
      send "playerStart" to me in 0 milliseconds
   end if
   playerShowLibrary
end openStack

command playerStart
   local tQuery, tError
   try
      do "window.location.search" as "JavaScript"
      put the result into tQuery
   catch tError
   end try
   put playerParam(tQuery, "mode") into sMode
   if sMode is not "window" then
      put "page" into sMode
   end if
   playerInstallErrorHandler
   playerLog "ready" && the version && the platform && sMode
   playerTellPage "ready", the version
end playerStart

-- The value of pName in a query string (?a=1&b=2)
function playerParam pQuery, pName
   local tPair, tAt
   if char 1 of pQuery is "?" then
      delete char 1 of pQuery
   end if
   replace "&" with return in pQuery
   repeat for each line tPair in pQuery
      put offset("=", tPair) into tAt
      if tAt > 0 and char 1 to tAt - 1 of tPair is pName then
         return urlDecode(char tAt + 1 to -1 of tPair)
      end if
   end repeat
   return empty
end playerParam

-- A line for the browser's console (and the checks of player_check.py)
command playerLog pText
   replace return with " | " in pText
   write "PLAYER" && pText & return to stdout
end playerLog

-- pKind "error" for what went wrong, which the page shows as such
command playerStatus pText, pKind
   if there is a field "Status" of card 1 of me then
      put pText into field "Status" of card 1 of me
   end if
   playerLog "status" && pText
   if pText is not empty then
      playerTellPage "status", pKind & return & pText
   end if
end playerStatus

-- Tells the page's script (index.html) what happened: pEvent "ready",
-- "opened" with the stack's name, "home", "library" and "choices" with
-- their lists (playerShowLibrary, playerShowChoices), or "status"
command playerTellPage pEvent, pDetail
   local tError
   replace "\" with "\\" in pDetail
   replace quote with "\" & quote in pDetail
   replace return with "\n" in pDetail
   try
      do "if (window.oxtPlayer) window.oxtPlayer.event('" & pEvent & "'," & quote & pDetail & quote & ");" as "JavaScript"
   catch tError
   end try
end playerTellPage

----------------------------------------------------------------
-- Calls from the page
----------------------------------------------------------------

-- The page calls this (it is in the cJavascriptHandlers): line 1 of
-- pWhat says what to do, and the lines after it are its arguments:
--
--   open, home, download, reload, library
--   take       the paths of files the page wrote into /uploads
--   openpath   a stack file of the library
--   forget     a folder of the library
--
-- A handler that the page calls cannot wait, and opening a stack can, so
-- the work runs in the engine's next turn.
on playerFromPage pWhat
   local tVerb
   put line 1 of pWhat into tVerb
   if tVerb is among the items of "open,home,download,reload,library,take,openpath,forget" then
      put line 2 to -1 of pWhat into sPageArgs
      send "playerDo" && tVerb to me in 0 milliseconds
      return true
   end if
   return false
end playerFromPage

on playerDo pWhat
   local tArgs
   put sPageArgs into tArgs
   put empty into sPageArgs
   switch pWhat
      case "open"
         playerChoose
         break
      case "home"
         playerGoHome
         break
      case "download"
         playerDownload
         break
      case "reload"
         playerReload
         break
      case "library"
         playerShowLibrary
         break
      case "take"
         playerTakeFromPage tArgs
         break
      case "openpath"
         if playerInLibrary(line 1 of tArgs) then
            playerOpenFile line 1 of tArgs
         end if
         break
      case "forget"
         playerForgetFolder line 1 of tArgs
         break
   end switch
end playerDo

-- Files the page wrote: only those in /uploads
private command playerTakeFromPage pPaths
   local tPath, tPaths
   repeat for each line tPath in pPaths
      if tPath begins with "/uploads/" and "/../" is not in tPath then
         put tPath & return after tPaths
      end if
   end repeat
   delete the last char of tPaths
   if tPaths is not empty then
      playerTake tPaths
   end if
end playerTakeFromPage

-- Whether pPath is a file in the library (and not above it)
private function playerInLibrary pPath
   return pPath begins with (playerLibraryFolder() & slash) and "/../" is not in pPath \
         and there is a file pPath
end playerInLibrary

----------------------------------------------------------------
-- Getting stacks from the user
----------------------------------------------------------------

on playerChoose
   local tFiles
   answer files "Choose a stack, or a stack and the files it uses:"
   if it is empty then
      exit playerChoose
   end if
   put it into tFiles
   playerTake tFiles
end playerChoose

on dragEnter
   if the dragData["files"] is not empty then
      set the dragAction to "copy"
   else
      pass dragEnter
   end if
end dragEnter

on dragDrop
   if the dragData["files"] is not empty then
      playerTake the dragData["files"]
   else
      pass dragDrop
   end if
end dragDrop

-- Files or folders the user gave (paths in /uploads, one a line): they
-- are copied into a new folder of the library, a zip archive unpacked
-- there, and the stack among them opened (or, with several, listed)
command playerTake pPaths
   local tName, tFolder, tPath, tStacks, tExtensions
   set the itemDelimiter to slash
   put item -1 of line 1 of pPaths into tName
   set the itemDelimiter to "."
   if the number of items of tName > 1 then
      delete item -1 of tName
   end if
   put playerNewLibraryFolder(tName) into tFolder
   set the itemDelimiter to slash
   repeat for each line tPath in pPaths
      if there is a folder tPath then
         playerCopyFolder tPath, tFolder & slash & item -1 of tPath
      else if playerIsZip(tPath) then
         playerUnzip tPath, tFolder
      else
         put url ("binfile:" & tPath) into url ("binfile:" & tFolder & slash & item -1 of tPath)
      end if
   end repeat
   put playerStacksIn(tFolder) into tStacks
   if tStacks is empty then
      put kStackExtensions into tExtensions
      replace comma with ", ." in tExtensions
      playerStatus "There is no stack among the files you gave." && \
            "A stack file ends in ." & tExtensions & ".", "error"
      playerRemoveFolder tFolder
      exit playerTake
   end if
   playerShowLibrary
   if the number of lines of tStacks is 1 then
      playerOpenFile line 1 of tStacks
   else
      put tStacks into sChoices
      playerShowChoices
      playerStatus "There are" && the number of lines of tStacks && "stacks. Choose the one to open."
   end if
end playerTake

private function playerIsZip pPath
   local tHeader
   open file pPath for binary read
   if the result is not empty then
      return false
   end if
   read from file pPath for 4
   put it into tHeader
   close file pPath
   return tHeader is ("PK" & numToByte(3) & numToByte(4))
end playerIsZip

private command playerUnzip pZip, pFolder
   local tItems, tItem, tTarget, tParent
   revZipOpenArchive pZip, "read"
   if the result is not empty then
      playerStatus "Could not open the archive:" && the result, "error"
      exit playerUnzip
   end if
   put revZipEnumerateItems(pZip) into tItems
   set the itemDelimiter to slash
   repeat for each line tItem in tItems
      -- the macOS Finder's extra files, and folders (which end in a slash)
      if tItem begins with "__MACOSX/" or char -1 of tItem is slash then
         next repeat
      end if
      put pFolder & slash & tItem into tTarget
      put item 1 to -2 of tTarget into tParent
      playerEnsureFolder tParent
      revZipExtractItemToFile pZip, tItem, tTarget
   end repeat
   revZipCloseArchive pZip
end playerUnzip

----------------------------------------------------------------
-- The library: copies of the stacks the user opened, kept between visits
----------------------------------------------------------------

function playerLibraryFolder
   local tFolder
   put specialFolderPath("documents") & slash & kLibraryName into tFolder
   playerEnsureFolder tFolder
   return tFolder
end playerLibraryFolder

-- A new folder in the library for pName (pName, pName 2, ...)
private function playerNewLibraryFolder pName
   local tBase, tFolder, tCount
   replace slash with "-" in pName
   if pName is empty then
      put "Stack" into pName
   end if
   put playerLibraryFolder() & slash & pName into tBase
   put tBase into tFolder
   put 1 into tCount
   repeat while there is a folder tFolder
      add 1 to tCount
      put tBase && tCount into tFolder
   end repeat
   create folder tFolder
   return tFolder
end playerNewLibraryFolder

-- The stack files in pFolder and the folders in it, by extension, one a
-- line (the ones nearest the top first)
function playerStacksIn pFolder
   local tFiles, tFile, tResult, tFolders, tSub
   put files(pFolder) into tFiles
   repeat for each line tFile in tFiles
      if playerExtension(tFile) is among the items of kStackExtensions then
         put pFolder & slash & tFile & return after tResult
      end if
   end repeat
   put folders(pFolder) into tFolders
   repeat for each line tSub in tFolders
      if tSub is "." or tSub is ".." then
         next repeat
      end if
      put playerStacksIn(pFolder & slash & tSub) after tResult
   end repeat
   return tResult
end playerStacksIn

-- The extension of a file name (after its last full stop), or empty
private function playerExtension pName
   set the itemDelimiter to "."
   if the number of items of pName < 2 then
      return empty
   end if
   return item -1 of pName
end playerExtension

-- The library's folders that hold a stack: "name<tab>stack path" lines,
-- with pDetails also the stack file's size in bytes, when it last
-- changed (in seconds) and how many stacks the folder holds
function playerLibraryList pDetails
   local tLibrary, tFolders, tSub, tStacks, tList, tInfo
   put playerLibraryFolder() into tLibrary
   put folders(tLibrary) into tFolders
   sort tFolders
   repeat for each line tSub in tFolders
      if tSub is "." or tSub is ".." then
         next repeat
      end if
      put playerStacksIn(tLibrary & slash & tSub) into tStacks
      if tStacks is not empty then
         put tSub & tab & line 1 of tStacks after tList
         if pDetails then
            put playerFileInfo(line 1 of tStacks) into tInfo
            put tab & tInfo & tab & the number of lines of tStacks after tList
         end if
         put return after tList
      end if
   end repeat
   delete the last char of tList
   return tList
end playerLibraryList

-- "<size in bytes><tab><last changed, in seconds>" of a file
private function playerFileInfo pPath
   local tFolder, tName, tLine
   set the itemDelimiter to slash
   put item 1 to -2 of pPath into tFolder
   put item -1 of pPath into tName
   repeat for each line tLine in files(tFolder, "detailed")
      set the itemDelimiter to comma
      if urlDecode(item 1 of tLine) is tName then
         return item 2 of tLine & tab & item 5 of tLine
      end if
   end repeat
   return 0 & tab & 0
end playerFileInfo

command playerShowLibrary
   if there is not a field "Library" of card 1 of me then
      exit playerShowLibrary
   end if
   put empty into sChoices
   local tList, tLine, tText
   put playerLibraryList() into tList
   set the itemDelimiter to tab
   repeat for each line tLine in tList
      put item 1 of tLine & return after tText
   end repeat
   delete the last char of tText
   put tText into field "Library" of card 1 of me
   set the cPaths of field "Library" of card 1 of me to tList
   put "Your stacks" into field "Library Title" of card 1 of me
   if tText is empty then
      put "Stacks you open are kept here, in this browser, for your next visit." into field "Library" of card 1 of me
      set the cPaths of field "Library" of card 1 of me to empty
   end if
   set the hilitedLine of field "Library" of card 1 of me to 0
   playerLog "library" && the number of lines of tList && "stacks:" && line 1 to -1 of field "Library" of card 1 of me
   playerTellPage "library", playerLibraryList(true)
end playerShowLibrary

-- Lists the stacks of the last folder or archive, to choose from
private command playerShowChoices
   local tLine, tText, tLibrary, tList
   put playerLibraryFolder() & slash into tLibrary
   repeat for each line tLine in sChoices
      put tLine into tText
      replace tLibrary with empty in tText
      put tText & return after tList
   end repeat
   delete the last char of tList
   put tList into field "Library" of card 1 of me
   set the itemDelimiter to tab
   put empty into tText
   repeat for each line tLine in sChoices
      put tLine & tab & tLine & return after tText
   end repeat
   delete the last char of tText
   set the cPaths of field "Library" of card 1 of me to tText
   put "Choose a stack" into field "Library Title" of card 1 of me
   -- "path in the library<tab>full path" lines
   put empty into tText
   repeat for each line tLine in sChoices
      put tLine into tList
      replace tLibrary with empty in tList
      put tList & tab & tLine & return after tText
   end repeat
   delete the last char of tText
   playerTellPage "choices", tText
end playerShowChoices

-- A click on a line of the list (field "Library" sends it)
command playerLibraryClicked pLine
   local tLine
   put line pLine of the cPaths of field "Library" of card 1 of me into tLine
   set the itemDelimiter to tab
   if item 2 of tLine is not empty then
      playerOpenFile item 2 of tLine
   end if
end playerLibraryClicked

-- Forgets the hilited stack of the list: its folder goes from the library
command playerForgetHilited
   local tLine, tFolder
   put line (the hilitedLine of field "Library" of card 1 of me) of \
         the cPaths of field "Library" of card 1 of me into tLine
   if tLine is empty or sChoices is not empty then
      playerStatus "Click a stack in the list first, then Forget."
      exit playerForgetHilited
   end if
   set the itemDelimiter to tab
   put playerLibraryFolder() & slash & item 1 of tLine into tFolder
   answer "Forget" && item 1 of tLine & "? Its files, and anything it saved, are removed from this browser." with "Cancel" or "Forget"
   if it is not "Forget" then
      exit playerForgetHilited
   end if
   playerRemoveFolder tFolder
   playerShowLibrary
   playerStatus "Forgot" && item 1 of tLine & "."
end playerForgetHilited

-- Forgets a folder of the library, by name (the page asked the user)
command playerForgetFolder pFolder
   if pFolder is empty or slash is in pFolder or pFolder is "." or pFolder is ".." then
      exit playerForgetFolder
   end if
   if there is not a folder (playerLibraryFolder() & slash & pFolder) then
      exit playerForgetFolder
   end if
   playerRemoveFolder playerLibraryFolder() & slash & pFolder
   playerShowLibrary
   playerStatus "Removed" && pFolder && "from this browser."
end playerForgetFolder

----------------------------------------------------------------
-- Opening a stack, and going back
----------------------------------------------------------------

command playerOpenFile pPath
   local tRect, tName, tError, tResult, tFolder
   if sCurrent is not empty then
      playerGoHome
   end if
   playerStatus "Opening" && pPath
   put the mainStacks into sStacksBefore
   set the itemDelimiter to slash
   put item 1 to -2 of pPath into tFolder
   try
      -- reading the stack: its size, which "go ... in window" would give
      -- up for the player's, and its name
      put the rect of stack pPath into tRect
      put the short name of stack pPath into tName
   catch tError
      put "the file is not a stack this engine can read (" & playerErrorText(tError) & ")" into tResult
   end try
   if tResult is empty and tName is the short name of me then
      put "it has the player's own name" into tResult
   end if
   if tResult is not empty then
      playerStatus "Could not open" && pPath & ":" && tResult, "error"
      exit playerOpenFile
   end if
   -- its relative paths are relative to its own folder, as in its own
   -- standalone
   set the defaultFolder to tFolder
   put tName into sCurrent
   put pPath into sCurrentFile
   try
      if sMode is "page" then
         go stack pPath in window (the short name of me)
      else
         go stack pPath
      end if
      put the result into tResult
   catch tError
      put playerErrorText(tError) into tResult
   end try
   if tResult is not empty then
      put empty into sCurrent
      if playerNativeLibrary(tResult) is not empty then
         put playerNativeText(playerNativeLibrary(tResult)) into tResult
      end if
      playerStatus "Could not open" && pPath & ":" && tResult, "error"
      exit playerOpenFile
   end if
   lock screen
   set the itemDelimiter to comma
   if the mode of stack tName > 0 then
      set the width of stack tName to item 3 of tRect - item 1 of tRect
      set the height of stack tName to item 4 of tRect - item 2 of tRect
      if sMode is not "page" then
         set the loc of stack tName to the screenLoc
      end if
   end if
   unlock screen
   playerLog "opened" && tName && "cards=" & the number of cards of stack tName && \
         "rect=" & the rect of stack tName
   playerTellPage "opened", tName & return & the number of cards of stack tName & return & the width of stack tName & "x" & the height of stack tName
end playerOpenFile

-- Back to the player: the stack's windows close, and it and the stacks it
-- loaded go from memory, so that opening it again reads its file again
command playerGoHome
   local tStack, tStacks, tPlayer, tInPage
   put the short name of me into tPlayer
   if sCurrent is empty then
      if the mode of me is 0 then
         go stack tPlayer
      end if
      exit playerGoHome
   end if
   put the openStacks into tStacks
   repeat for each line tStack in tStacks
      if tStack is not tPlayer and tStack is not sCurrent then
         close stack tStack
      end if
   end repeat
   -- (each test on its own: "there is a stack x and ..." reads the rest
   -- of the line as the stack's name)
   put false into tInPage
   if sMode is "page" and there is a stack sCurrent then
      put the mode of stack sCurrent > 0 into tInPage
   end if
   if tInPage then
      go stack tPlayer in window (sCurrent)
   else
      go stack tPlayer
   end if
   send "playerForget" && quote & sCurrent & quote to me in 0 milliseconds
   put empty into sCurrent
   put empty into sCurrentFile
   playerShowLibrary
   playerStatus empty
   playerTellPage "home", empty
end playerGoHome

-- Removes from memory the main stacks that were not there before the
-- stack opened
on playerForget pName
   local tStack
   if there is a stack pName then
      delete stack pName
   end if
   repeat for each line tStack in the mainStacks
      if tStack is among the lines of sStacksBefore or tStack is the short name of me then
         next repeat
      end if
      if there is a stack tStack then
         if the mode of stack tStack is 0 then
            delete stack tStack
         end if
      end if
   end repeat
end playerForget

-- Opens the current stack again from its file, as it was saved
command playerReload
   local tFile
   put sCurrentFile into tFile
   if tFile is not empty then
      playerGoHome
      send "playerOpenFile" && quote & tFile & quote to me in 10 milliseconds
   end if
end playerReload

-- Gives the user a copy of the stack as it is now, as a download: saved
-- as a file in /downloads, which the browser downloads when it is closed.
-- The stack keeps its own file name.
command playerDownload
   local tName, tFile, tCopy, tError
   if sCurrent is empty then
      exit playerDownload
   end if
   put sCurrent into tName
   put the filename of stack tName into tFile
   set the itemDelimiter to slash
   put specialFolderPath("downloads") & slash & item -1 of tFile into tCopy
   try
      save stack tName as tCopy
      set the filename of stack tName to tFile
   catch tError
      set the filename of stack tName to tFile
      answer "Could not save a copy of" && tName & ":" && playerErrorText(tError)
   end try
end playerDownload

----------------------------------------------------------------
-- Script errors of the stacks it opens
----------------------------------------------------------------

-- A standalone shows no error of its own: this button's script, in the
-- back of the message path, says which object and line, and what the
-- error was, in a dialog and in the browser's console. A stack that
-- handles errorDialog itself still does (the back script comes last).
private command playerInstallErrorHandler
   local tButton
   if there is not a button "Error Handler" of card 1 of me then
      exit playerInstallErrorHandler
   end if
   put the long id of button "Error Handler" of card 1 of me into tButton
   if tButton is not among the lines of the backScripts then
      insert the script of tButton into back
   end if
end playerInstallErrorHandler

-- The engine's error lines ("code,line,char,hint") as text
function playerErrorText pError
   local tLine, tText, tMessage, tMessages
   -- a standalone has no error texts of its own: the build keeps the
   -- IDE's in the player's cScriptErrors
   put the scriptExecutionErrors into tMessages
   if tMessages is empty then
      put the cScriptErrors of me into tMessages
   end if
   repeat for each line tLine in pError
      put line (item 1 of tLine) of tMessages into tMessage
      if tMessage is empty then
         next repeat
      end if
      put tMessage after tText
      if item 2 of tLine > 0 then
         put " (line" && item 2 of tLine & ")" after tText
      end if
      if item 4 of tLine is not empty then
         put ":" && item 4 of tLine after tText
      end if
      put return after tText
   end repeat
   delete the last char of tText
   if tText is empty then
      return pError
   end if
   return tText
end playerErrorText

-- An extension whose code is a native library (box2dxt's Box2D, sodiumxt,
-- coinxt...) has no build for the web: its first call fails with "unable to
-- load foreign library". That is said in plain words, with the library's
-- name, rather than as the extension's error trace.
function playerNativeLibrary pError
   local tOffset, tName
   put offset("unable to load foreign library '", pError) into tOffset
   if tOffset is 0 then
      return empty
   end if
   put char tOffset + 32 to -1 of pError into tName
   put char 1 to offset("'", tName) - 1 of tName into tName
   return tName
end playerNativeLibrary

function playerNativeText pLibrary
   return "it uses" && pLibrary & ", an extension built from native code for" && \
         "desktop computers. Native extensions do not run on the web yet."
end playerNativeText

command playerReportError pError, pObject
   local tText, tLibrary
   put playerErrorText(pError) into tText
   put playerNativeLibrary(pError) into tLibrary
   replace the long name of me with "the Stack Player" in pObject
   replace the long name of me with "the Stack Player" in tText
   -- the stack by its name, not by the path of its copy in the library
   if sCurrent is not empty and there is a stack sCurrent then
      replace the long name of stack sCurrent with "stack" && quote & sCurrent & quote in pObject
      replace the long name of stack sCurrent with "stack" && quote & sCurrent & quote in tText
   end if
   playerLog "script error in" && pObject & ":" && tText
   if tLibrary is not empty then
      answer error "This part of" && quote & sCurrent & quote && "can't run here:" && \
            playerNativeText(tLibrary)
   else
      answer error "A script error in" && pObject & ":" & return & return & tText
   end if
end playerReportError

----------------------------------------------------------------
-- Files
----------------------------------------------------------------

command playerEnsureFolder pFolder
   local tPath, tPart
   if there is a folder pFolder then
      exit playerEnsureFolder
   end if
   set the itemDelimiter to slash
   repeat for each item tPart in pFolder
      if tPath is empty and tPart is empty then
         next repeat
      end if
      put slash & tPart after tPath
      if there is not a folder tPath then
         create folder tPath
      end if
   end repeat
end playerEnsureFolder

command playerCopyFolder pFrom, pTo
   local tFile, tSub
   playerEnsureFolder pTo
   repeat for each line tFile in files(pFrom)
      put url ("binfile:" & pFrom & slash & tFile) into url ("binfile:" & pTo & slash & tFile)
   end repeat
   repeat for each line tSub in folders(pFrom)
      if tSub is not "." and tSub is not ".." then
         playerCopyFolder pFrom & slash & tSub, pTo & slash & tSub
      end if
   end repeat
end playerCopyFolder

command playerRemoveFolder pFolder
   local tFile, tSub
   if there is not a folder pFolder then
      exit playerRemoveFolder
   end if
   repeat for each line tFile in files(pFolder)
      delete file (pFolder & slash & tFile)
   end repeat
   repeat for each line tSub in folders(pFolder)
      if tSub is not "." and tSub is not ".." then
         playerRemoveFolder pFolder & slash & tSub
      end if
   end repeat
   delete folder pFolder
end playerRemoveFolder
