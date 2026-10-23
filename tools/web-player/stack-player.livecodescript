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
-- specialFolderPath("resources") finds them too: see
-- playerLinkResources.
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
-- The names playerLinkResources linked into the resources folder for the
-- open stack, one a line
local sLinked
-- For a HyperCard stack copied out of a disk image, by the path of the
-- copy: the image's path and the stack's HFS path on it, so that a "go"
-- to another stack of the image finds it there (the HyperCard Library's
-- hcStackName)
local sFromImage

constant kStackExtensions = "livecode,oxtstack,rev,mc,livecodescript,lc,stack"
constant kLibraryName = "Stack Player"
-- The IDE's HyperCard libraries, as the build gives them to the player
-- (build-player.livecodescript, makeHyperCardLibraries)
constant kHyperCardScripts = "Player HyperCard Scripts"
constant kHyperCardImages = "Player HyperCard Disk Images"
constant kHyperCardMACE = "Player HyperCard MACE"
-- Between a disk image's path and the HFS path of a stack on it, in a
-- choice (an HFS path never has two colons in a row)
constant kImageSeparator = "::"
-- Beside a stack copied out of a disk image: its line of sFromImage
constant kFromImageSuffix = ".hcimage"

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
   playerUseHyperCardLibraries
   playerLog "ready" && the version && the platform && sMode
   playerTellPage "ready", the version
end playerStart

-- The IDE's HyperCard libraries, substacks of the player (see
-- playerFixHyperCard and playerImageStacks): their handlers all begin
-- with revHyperCard
private command playerUseHyperCardLibraries
   local tName
   -- a HyperCard stack's "go home" comes back to the player (the
   -- HyperCard Library's hcGoHome)
   global gHyperCardHome
   put the long id of me into gHyperCardHome
   repeat for each item tName in kHyperCardScripts & comma & kHyperCardImages & comma & kHyperCardMACE
      if there is a stack tName then
         start using stack tName
      end if
   end repeat
end playerUseHyperCardLibraries

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

-- The handlers below that playerOpenFile calls once the stack is open are
-- private, which a call reaches straight, not through the message path.
-- A stack imported from HyperCard has dynamicPaths true, and until the
-- engine's turn ends the message path of a handler in another stack (the
-- player's) runs through that stack's current card instead of its own
-- stack, so a public handler of the player's is not found there ("can't
-- find handler playerLog"). Nothing else calls them: the player is not in
-- the message path of the stacks it opens.

-- A line for the browser's console (and the checks of player_check.py)
private command playerLog pText
   replace return with " | " in pText
   write "PLAYER" && pText & return to stdout
end playerLog

-- pKind "error" for what went wrong, which the page shows as such
private command playerStatus pText, pKind
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
private command playerTellPage pEvent, pDetail
   local tError
   try
      do "if (window.oxtPlayer) window.oxtPlayer.event('" & pEvent & "'," & playerJSString(pDetail) & ");" as "JavaScript"
   catch tError
   end try
end playerTellPage

-- pText as a JavaScript string literal
private function playerJSString pText
   replace "\" with "\\" in pText
   replace quote with "\" & quote in pText
   replace return with "\n" in pText
   return quote & pText & quote
end playerJSString

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
         if kImageSeparator is in line 1 of tArgs then
            playerOpenFromImage line 1 of tArgs
         else if playerInLibrary(line 1 of tArgs) then
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
   -- a Mac disk image: its HyperCard stacks, to choose from (one is
   -- copied out of it only once it is chosen: a CD can hold thousands)
   if tStacks is empty then
      put playerImageStacks(tFolder) into tStacks
   end if
   if tStacks is empty then
      put kStackExtensions into tExtensions
      replace comma with ", ." in tExtensions
      playerStatus "There is no stack among the files you gave." && \
            "A stack file ends in ." & tExtensions & \
            ", or is a HyperCard stack or a Mac disk image with HyperCard stacks on it.", "error"
      playerRemoveFolder tFolder
      exit playerTake
   end if
   playerShowLibrary
   if the number of lines of tStacks is 1 and kImageSeparator is not in tStacks then
      playerOpenFile line 1 of tStacks
   else if the number of lines of tStacks is 1 then
      playerOpenFromImage line 1 of tStacks
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
      -- folders (which end in a slash). The macOS Finder's extra files,
      -- in __MACOSX, are kept: for a HyperCard stack they are its
      -- resource fork (__MACOSX/<folder>/._Name), which the import reads
      if char -1 of tItem is slash then
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
      else if playerIsHyperCard(pFolder & slash & tFile) then
         -- a HyperCard stack has no extension of its own (or any, as
         -- "Grimoire 1.0"): it is known by its first bytes
         put pFolder & slash & tFile & return after tResult
      end if
   end repeat
   put folders(pFolder) into tFolders
   repeat for each line tSub in tFolders
      -- (__MACOSX holds the resource forks of the stacks beside it)
      if tSub is "." or tSub is ".." or tSub is "__MACOSX" then
         next repeat
      end if
      put playerStacksIn(pFolder & slash & tSub) after tResult
   end repeat
   return tResult
end playerStacksIn

-- Whether pPath is a HyperCard stack, by the tests hc_import
-- (engine/src/hc.cpp) and File > Import Stack make of its first bytes: a
-- data fork (STAK at offset 4), an AppleSingle file, a MacBinary file of
-- type STAK, or a BinHex file. Its resource fork (Name.rsrc, ._Name)
-- is not one.
private function playerIsHyperCard pPath
   local tHeader, tName
   set the itemDelimiter to slash
   put item -1 of pPath into tName
   if tName begins with "._" or playerExtension(tName) is "rsrc" then
      return false
   end if
   open file pPath for binary read
   if the result is not empty then
      return false
   end if
   read from file pPath for 256
   put it into tHeader
   close file pPath
   if byte 5 to 8 of tHeader is "STAK" then
      return true
   end if
   if byte 1 to 4 of tHeader is (numToByte(0) & numToByte(5) & numToByte(22) & numToByte(0)) then
      return true
   end if
   if the number of bytes of tHeader >= 128 and byteToNum(byte 1 of tHeader) is 0 \
         and byteToNum(byte 75 of tHeader) is 0 and byteToNum(byte 83 of tHeader) is 0 then
      return byte 66 to 69 of tHeader is "STAK"
   end if
   return "(This file must be converted with BinHex" is in tHeader
end playerIsHyperCard

-- The HyperCard stacks on the Mac disk images among the files of pFolder
-- and its folders: "image path::HFS path" lines, as
-- revHyperCardImageStacks lists them
private function playerImageStacks pFolder
   local tFile, tPath, tList, tLine, tResult, tError, tSub
   repeat for each line tSub in folders(pFolder)
      -- (__MACOSX holds the resource forks of the files beside it)
      if tSub is "." or tSub is ".." or tSub is "__MACOSX" then
         next repeat
      end if
      put playerImageStacks(pFolder & slash & tSub) into tList
      if tList is not empty then
         put tList & return after tResult
      end if
   end repeat
   repeat for each line tFile in files(pFolder)
      put pFolder & slash & tFile into tPath
      try
         if not revHyperCardIsDiskImage(tPath) then
            next repeat
         end if
         put revHyperCardImageStacks(tPath) into tList
      catch tError
         next repeat
      end try
      set the itemDelimiter to tab
      repeat for each line tLine in tList
         put tPath & kImageSeparator & item 1 of tLine & return after tResult
      end repeat
   end repeat
   delete the last char of tResult
   return tResult
end playerImageStacks

-- Copies a stack chosen on a disk image ("image path::HFS path") out of
-- it, with its resource fork beside it, into the image's folder of the
-- library, and opens it. The library lists it from then on.
private command playerOpenFromImage pChoice
   local tImage, tStack, tAt, tFolder, tPath, tError
   put offset(kImageSeparator, pChoice) into tAt
   put char 1 to tAt - 1 of pChoice into tImage
   put char tAt + the number of chars of kImageSeparator to -1 of pChoice into tStack
   if not playerInLibrary(tImage) then
      exit playerOpenFromImage
   end if
   set the itemDelimiter to slash
   put item 1 to -2 of tImage into tFolder
   try
      put revHyperCardImageExtract(tImage, tStack, tFolder) into tPath
      put the result into tError
   catch tError
      put playerErrorText(tError) into tError
   end try
   if tPath is empty then
      if tError is empty then
         put "it is not on the image" into tError
      end if
      playerStatus "Could not copy" && tStack && "out of the disk image:" && tError, "error"
      exit playerOpenFromImage
   end if
   put tImage & return & tStack into sFromImage[tPath]
   -- and beside the stack, for a later visit, when the library is read
   -- again and sFromImage is empty
   try
      put sFromImage[tPath] into url ("binfile:" & tPath & kFromImageSuffix)
   catch tError
   end try
   playerOpenFile tPath
end playerOpenFromImage

-- A HyperCard stack the player has just read, with messages locked: its
-- scripts are rewritten so that they compile here and it is given the
-- HyperCard Library, as File > Import Stack does on the desktop
-- (revHyperCardFixScripts, the IDE's revhypercardscriptlibrary)
private command playerFixHyperCard pStack
   local tError
   -- HyperCard's message order (a background part's messages reach the
   -- card first), before the scripts are fixed
   try
      set the hyperTalkCompatible of pStack to true
   catch tError
      playerLog "hypercard-order-failed" && playerErrorText(tError)
   end try
   try
      playerLog "hypercard" && the last line of revHyperCardFixScripts(pStack)
   catch tError
      playerLog "hypercard-fix-failed" && playerErrorText(tError)
   end try
   -- its MACE sounds, which the engine's importer leaves out, decoded
   -- from its resource fork as audio clips
   try
      playerLog "hypercard-mace" && revHyperCardConvertMACESounds(pStack, the uHyperCard["file"] of pStack)
   catch tError
      playerLog "hypercard-mace-failed" && playerErrorText(tError)
   end try
   -- HyperCard's white paper and flat black-and-white buttons
   try
      revHyperCardClassicLook pStack
   catch tError
      playerLog "hypercard-look-failed" && playerErrorText(tError)
   end try
end playerFixHyperCard

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
      put playerChoiceLabel(tLine, tLibrary) & return after tList
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
      put playerChoiceLabel(tLine, tLibrary) & tab & tLine & return after tText
   end repeat
   delete the last char of tText
   playerTellPage "choices", tText
end playerShowChoices

-- How a choice reads in the list: its path in the library, or for a stack
-- on a disk image its HFS path on the volume
private function playerChoiceLabel pChoice, pLibrary
   local tAt
   put offset(kImageSeparator, pChoice) into tAt
   if tAt > 0 then
      return char tAt + the number of chars of kImageSeparator to -1 of pChoice
   end if
   replace pLibrary with empty in pChoice
   return pChoice
end playerChoiceLabel

-- A click on a line of the list (field "Library" sends it)
command playerLibraryClicked pLine
   local tLine
   put line pLine of the cPaths of field "Library" of card 1 of me into tLine
   set the itemDelimiter to tab
   if kImageSeparator is in item 2 of tLine then
      playerOpenFromImage item 2 of tLine
   else if item 2 of tLine is not empty then
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
   local tRect, tName, tError, tResult, tFolder, tOpenError, tHyperCard, tStack
   -- With a stack open, first home, and the stack opened after the one
   -- that goes is forgotten (as playerReload does): until then it is in
   -- memory, and a stack of the same name from another file (a newer copy
   -- of it, opened while it plays) would be read as that one, and then
   -- forgotten with it, while it shows
   if sCurrent is not empty then
      playerGoHome
      send "playerOpenFile" && quote & pPath & quote to me in 10 milliseconds
      exit playerOpenFile
   end if
   playerStatus "Opening" && pPath
   put the mainStacks into sStacksBefore
   set the itemDelimiter to slash
   put item 1 to -2 of pPath into tFolder
   -- A HyperCard stack is imported as it is read, and the stack it becomes
   -- has no file: each "stack <its path>" would import it again, as a new
   -- stack of the same name. So it is read once, with messages locked (as
   -- File > Import Stack reads it: a HyperCard virus runs from the
   -- stack's scripts), its scripts fixed, and then named by its long id.
   put playerIsHyperCard(pPath) into tHyperCard
   if tHyperCard then
      lock messages
   end if
   try
      -- reading the stack: its size, which "go ... in window" would give
      -- up for the player's, and its name
      if tHyperCard then
         put the long id of stack pPath into tStack
         put the rect of tStack into tRect
         put the short name of tStack into tName
         -- where it came from, as File > Import Stack notes it
         set the uHyperCard["file"] of tStack to pPath
         if sFromImage[pPath] is empty and there is a file (pPath & kFromImageSuffix) then
            put url ("binfile:" & pPath & kFromImageSuffix) into sFromImage[pPath]
         end if
         if sFromImage[pPath] is not empty then
            set the uHyperCard["image"] of tStack to line 1 of sFromImage[pPath]
            set the uHyperCard["imagepath"] of tStack to line 2 of sFromImage[pPath]
         end if
         playerFixHyperCard tStack
      else
         put the rect of stack pPath into tRect
         put the short name of stack pPath into tName
      end if
   catch tError
      put "the file is not a stack this engine can read (" & playerErrorText(tError) & ")" into tResult
   end try
   if tHyperCard then
      unlock messages
   end if
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
   playerLinkResources tFolder
   put tName into sCurrent
   put pPath into sCurrentFile
   try
      if tHyperCard and sMode is "page" then
         go tStack in window (the short name of me)
      else if tHyperCard then
         go tStack
      else if sMode is "page" then
         go stack pPath in window (the short name of me)
      else
         go stack pPath
      end if
      put the result into tResult
   catch tError
      put playerErrorText(tError) into tResult
      -- a script error in the stack's own openStack or openCard (a
      -- HyperCard stack calling an XCMD it no longer has): the stack is
      -- open, as it is on the desktop, and the error is reported once it
      -- shows
      if tHyperCard then
         if exists(tStack) then
            if the mode of tStack > 0 then
               put tError into tOpenError
               put empty into tResult
            end if
         end if
      else if there is a stack pPath then
         if the mode of stack pPath > 0 then
            put tError into tOpenError
            put empty into tResult
         end if
      end if
   end try
   if tResult is not empty then
      put empty into sCurrent
      playerUnlinkResources
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
   if tOpenError is not empty then
      playerShowError tOpenError, the long name of stack tName
   end if
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
      -- by long id: a stack named with a number ("2048") would otherwise be
      -- read as a window number
      go stack tPlayer in window (the long id of stack sCurrent)
   else
      go stack tPlayer
   end if
   send "playerForget" && quote & sCurrent & quote to me in 0 milliseconds
   put empty into sCurrent
   put empty into sCurrentFile
   playerUnlinkResources
   playerShowLibrary
   playerStatus empty
   playerTellPage "home", empty
end playerGoHome

-- specialFolderPath("resources") is the player's own folder in the
-- browser (/boot/standalone), but a stack's scripts expect the files that
-- came with it there: in the IDE it is the folder of the stack's file,
-- and in the stack's own standalone the folder its Copy Files went to.
-- So while the stack is open, each file and folder beside it is linked
-- into the player's folder under its own name, through the engine's file
-- system in the page (script cannot make a link), and
-- specialFolderPath("resources") & "/images/a.png" reads its
-- images/a.png. A name the player's own files have is left as it is
-- (DroidSansCombined.ttf and the extensionNN folders). The function still
-- returns /boot/standalone, as in any web standalone.
private command playerLinkResources pFolder
   local tError
   playerUnlinkResources
   try
      do "(function (from, to) {" & \
            "var fs = window.FS || (window.Module && window.Module.FS), made = [];" & \
            "if (!fs) return '';" & \
            "fs.readdir(from).forEach(function (n) {" & \
            "if (n == '.' || n == '..') return;" & \
            "try { fs.lstat(to + '/' + n); return; } catch (e) {}" & \
            "try { fs.symlink(from + '/' + n, to + '/' + n); made.push(n); } catch (e) {}" & \
            "});" & \
            "return made.join('\n');" & \
            "})(" & playerJSString(pFolder) & "," & playerJSString(specialFolderPath("resources")) & ")" as "JavaScript"
      put the result into sLinked
   catch tError
      put empty into sLinked
   end try
end playerLinkResources

-- Removes the links playerLinkResources made (only links: a file of the
-- same name the stack wrote there since stays)
private command playerUnlinkResources
   local tError
   if sLinked is empty then
      exit playerUnlinkResources
   end if
   try
      do "(function (to, names) {" & \
            "var fs = window.FS || (window.Module && window.Module.FS);" & \
            "if (!fs) return;" & \
            "names.split('\n').forEach(function (n) {" & \
            "try { if (fs.isLink(fs.lstat(to + '/' + n).mode)) fs.unlink(to + '/' + n); } catch (e) {}" & \
            "});" & \
            "})(" & playerJSString(specialFolderPath("resources")) & "," & playerJSString(sLinked) & ")" as "JavaScript"
   catch tError
   end try
   put empty into sLinked
end playerUnlinkResources

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
   if tFile is empty then
      -- a HyperCard stack, imported as it opened, has no file of its own:
      -- the copy is the stack it became
      put specialFolderPath("downloads") & slash & tName & ".oxtstack" into tCopy
   else
      put specialFolderPath("downloads") & slash & item -1 of tFile into tCopy
   end if
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
private function playerErrorText pError
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
private function playerNativeLibrary pError
   local tOffset, tName
   put offset("unable to load foreign library '", pError) into tOffset
   if tOffset is 0 then
      return empty
   end if
   put char tOffset + 32 to -1 of pError into tName
   put char 1 to offset("'", tName) - 1 of tName into tName
   return tName
end playerNativeLibrary

private function playerNativeText pLibrary
   return "it uses" && pLibrary & ", an extension built from native code for" && \
         "desktop computers. Native extensions do not run on the web yet."
end playerNativeText

command playerReportError pError, pObject
   playerShowError pError, pObject
end playerReportError

-- (private, for playerOpenFile: see playerLog)
private command playerShowError pError, pObject
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
end playerShowError

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
