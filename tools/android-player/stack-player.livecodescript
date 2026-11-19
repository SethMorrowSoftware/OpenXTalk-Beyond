script "AndroidStackPlayer"
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

-- The script of the Android Stack Player (tools/android-player): an
-- Android app that opens any stack the user gives it, as the web Stack
-- Player (tools/web-player) does in a browser. tools/android-player/
-- build-player.livecodescript makes the stack "OXT Stack Player" with
-- this script and the controls it names, and builds it with the IDE's
-- own Android builder.
--
-- A stack comes from the Open button (Android's "Open document" screen,
-- through the Android Documents library), from another app that opens a
-- file with the player (the standalone settings' android,documentTypes:
-- the address arrives in urlWakeUp and mobileGetLaunchUrl), or from the
-- list of stacks opened before. Each one is copied into the player's
-- library, a folder of the app's own documents, in a folder of its own: a
-- stack that saves itself saves there, and the file it came from is never
-- written to. The stack then opens as it would on the desktop, with its
-- folder as the defaultFolder.
--
-- While a stack plays, the messages it does not handle end in the
-- player's back script (stack-player-back.livecodescript, the script of
-- the button "Player Back Script"): Android's Back comes home, a file
-- opened from another app is taken in, and a script error is shown.
--
-- What the player does goes to the device's log, a line each that begins
-- with kSays: tools/android-player/build_android_player.py's device check reads
-- them.
--
-- Nothing here changes the engine: everything is script that any Android
-- standalone could run.

constant kPlayerName = "OXT Stack Player"
constant kSays = "OXT Stack Player:"
-- Points kept clear above the screen's bottom for Android's navigation
-- bar (48 with buttons, less with gestures) (playerSeenHeight)
constant kBarAllowance = 56
-- What a stack file's name ends with
constant kStackEndings = "oxtstack,livecode,rev,livecodescript,oxtscript,mc"

-- The stack that plays (its short name), its file, and the main stacks
-- that were in memory before it opened (those loaded since are its own,
-- and go when the player comes home)
local sCurrent, sCurrentFile, sStacksBefore
local sStarted
-- The address taken in last and when, so that the one a launch gives
-- twice (mobileGetLaunchUrl and urlWakeUp) is taken once
local sLastAddress, sLastSeconds
-- The library's folder when it is not the app's own (playerSetLibraryFolder)
local sLibraryFolder

on openStack
   if sStarted is true or the environment is not "mobile" then
      pass openStack
   end if
   put true into sStarted
   -- a player saved unseen draws nothing on Android (build-player
   -- saves it seen)
   set the visible of me to true
   insert the script of button "Player Back Script" of me into back
   playerLayout
   playerShowLibrary
   -- a stack turns with the device unless it says otherwise
   try
      mobileSetAllowedOrientations "portrait,portrait upside down,landscape left,landscape right"
   end try
   playerSay "ready" && the version && the platform
   playerSay "library" && the number of lines in playerLibrary()
   playerSayWhere
   -- after openStack, so that the player is on the screen first
   send "playerLaunched" to me in 100 milliseconds
end openStack

-- resizeStack comes to the card, so the target is never the stack: only
-- the player's own cards send it here (a stack that plays has its own)
on resizeStack
   playerLayout
   pass resizeStack
end resizeStack

-- The file the app was started to open, if any
on playerLaunched
   local tAddress
   try
      put mobileGetLaunchUrl() into tAddress
   end try
   if tAddress is not empty then
      playerTakeAddress tAddress
   end if
end playerLaunched

-- Where the Open button is on the device's screen, in its pixels, for a
-- check that taps it (build_android_player.py's device check)
command playerSayWhere
   local tLoc, tScale
   put globalLoc(the loc of button "Open" of stack kPlayerName) into tLoc
   put the pixelScale into tScale
   playerSay "open button at" && round(item 1 of tLoc * tScale) & comma & round(item 2 of tLoc * tScale) && \
         "scale" && tScale && "stack" && the rect of stack kPlayerName && "screen" && the screenRect
end playerSayWhere

command playerSay pLine
   replace return with " | " in pLine
   put kSays && pLine
end playerSay

----------------------------------------------------------------
-- The player's own card
----------------------------------------------------------------

-- Makes the player's controls on its card: build-player.livecodescript
-- calls it once, on the new stack, with the back script's text (the tests
-- of tests/lcs/androidplayer do the same)
command playerMake pBackScript
   local tDefault
   put the defaultStack into tDefault
   set the defaultStack to kPlayerName
   lock messages
   set the backgroundColor of stack kPlayerName to "#F4F1EA"
   playerMakeField "Title", 26, "bold", "OXT Stack Player"
   playerMakeField "Help", 15, empty, "Open a stack file (.oxtstack, .livecode, .rev or .livecodescript)" && \
         "from this device, or open one with this app from your files."
   create button "Open"
   set the label of button "Open" to "Open a stack..."
   set the textSize of button "Open" to 18
   set the script of button "Open" to "on mouseUp" & return & "   playerChoose" & return & "end mouseUp"
   playerMakeField "Library Title", 16, "bold", "Your stacks"
   create field "Library"
   set the listBehavior of field "Library" to true
   set the lockText of field "Library" to true
   -- no field of the player takes the focus: a field that has it brings
   -- up Android's keyboard, and Back then hides the keyboard first
   set the traversalOn of field "Library" to false
   set the textSize of field "Library" to 18
   set the fixedLineHeight of field "Library" to true
   set the textHeight of field "Library" to 44
   set the vScrollbar of field "Library" to true
   set the script of field "Library" to "on mouseUp" & return & \
         "   if the hilitedLine of me is not empty then playerPickLine the hilitedLine of me" & return & "end mouseUp"
   playerMakeField "Status", 14, empty, empty
   create button "Player Back Script"
   set the visible of button "Player Back Script" to false
   set the script of button "Player Back Script" to pBackScript
   unlock messages
   set the defaultStack to tDefault
   playerLayout
end playerMake

private command playerMakeField pName, pSize, pStyle, pText
   create field pName
   set the lockText of field pName to true
   set the traversalOn of field pName to false
   set the opaque of field pName to false
   set the showBorder of field pName to false
   set the borderWidth of field pName to 0
   set the textSize of field pName to pSize
   if pStyle is not empty then
      set the textStyle of field pName to pStyle
   end if
   put pText into field pName
end playerMakeField

-- The controls laid out for the screen as it is now. A short screen (a
-- phone held sideways) has no help text, so that the library keeps room
command playerLayout
   local tWidth, tHeight, tMargin, tTop
   put the width of stack kPlayerName into tWidth
   put playerSeenHeight() into tHeight
   put 20 into tMargin
   lock screen
   if tHeight < 520 then
      set the visible of field "Help" of stack kPlayerName to false
      set the rect of field "Title" of stack kPlayerName to tMargin, 10, tWidth - tMargin, 50
      set the rect of button "Open" of stack kPlayerName to tMargin, 56, tWidth - tMargin, 100
      put 108 into tTop
   else
      set the visible of field "Help" of stack kPlayerName to true
      set the rect of field "Title" of stack kPlayerName to tMargin, 40, tWidth - tMargin, 84
      set the rect of field "Help" of stack kPlayerName to tMargin, 90, tWidth - tMargin, 150
      set the rect of button "Open" of stack kPlayerName to tMargin, 160, tWidth - tMargin, 216
      put 236 into tTop
   end if
   set the rect of field "Library Title" of stack kPlayerName to tMargin, tTop, tWidth - tMargin, tTop + 26
   set the rect of field "Library" of stack kPlayerName to tMargin, tTop + 32, tWidth - tMargin, max(tTop + 80, tHeight - 60)
   set the rect of field "Status" of stack kPlayerName to tMargin, max(tTop + 86, tHeight - 54), tWidth - tMargin, max(tTop + 126, tHeight - 8)
   unlock screen
end playerLayout

-- How much of the player's card is seen. On Android 15 and later an app
-- is drawn edge to edge: the engine puts the stack below the status bar
-- but makes it as tall as the whole screen, so that its bottom is under
-- the navigation bar or past the screen. What lies below the screen's
-- bottom, and kBarAllowance above it, is left empty
function playerSeenHeight
   local tHeight, tSeen
   put the height of stack kPlayerName into tHeight
   if the environment is "mobile" then
      put item 4 of the screenRect - item 2 of the rect of stack kPlayerName - kBarAllowance into tSeen
      if tSeen > 300 and tSeen < tHeight then
         return tSeen
      end if
   end if
   return tHeight
end playerSeenHeight

command playerStatus pText
   put pText into field "Status" of stack kPlayerName
end playerStatus

-- The stacks of the library, a line each, newest first
command playerShowLibrary
   local tList, tEntry
   repeat for each line tEntry in playerLibrary()
      set the itemDelimiter to slash
      put item -1 of tEntry & return after tList
      set the itemDelimiter to comma
   end repeat
   delete the last char of tList
   put tList into field "Library" of stack kPlayerName
   set the cFiles of field "Library" of stack kPlayerName to playerLibrary()
end playerShowLibrary

-- A tap on a line of the library
command playerPickLine pLine
   local tFile
   put line pLine of the cFiles of field "Library" of stack kPlayerName into tFile
   if tFile is not empty then
      playerOpen tFile
   end if
end playerPickLine

-- The Open button: Android's "Open document" screen
command playerChoose
   local tAddress, tError
   try
      put androidPickDocument(empty) into tAddress
   catch tError
      playerProblem "The files cannot be shown:" && playerErrorLine(tError)
      exit playerChoose
   end try
   if tAddress is empty then
      playerSay "chose nothing"
      exit playerChoose
   end if
   playerTakeAddress tAddress
end playerChoose

----------------------------------------------------------------
-- The library
----------------------------------------------------------------

function playerLibraryFolder
   if sLibraryFolder is not empty then
      return sLibraryFolder
   end if
   return specialFolderPath("documents") & "/Stack Player"
end playerLibraryFolder

-- Another folder for the library (the player's tests: tests/lcs/
-- androidplayer), or empty for the app's own
command playerSetLibraryFolder pFolder
   put pFolder into sLibraryFolder
end playerSetLibraryFolder

-- Whether a file's name is a stack file's
function playerIsStackName pName
   local tEnding
   set the itemDelimiter to "."
   if the number of items in pName < 2 then
      return false
   end if
   put toLower(item -1 of pName) into tEnding
   set the itemDelimiter to comma
   return tEnding is among the items of kStackEndings
end playerIsStackName

-- A name from outside made a plain file name: its last path item, none of
-- the characters a path or a shell gives a meaning, no dot in front, and
-- no more than 80 characters with its ending kept
function playerSafeName pName
   local tName, tChar, tEnding, tCode
   replace backslash with slash in pName
   set the itemDelimiter to slash
   put item -1 of pName into pName
   repeat for each char tChar in pName
      put codepointToNum(tChar) into tCode
      if tCode < 32 or tCode is 127 or tChar is among the chars of (":*?<>|" & quote) then
         put "_" after tName
      else
         put tChar after tName
      end if
   end repeat
   put word 1 to -1 of tName into tName
   repeat while char 1 of tName is "."
      delete char 1 of tName
   end repeat
   if tName is empty then
      return "stack"
   end if
   if the number of chars in tName > 80 then
      set the itemDelimiter to "."
      put empty into tEnding
      if the number of items in tName > 1 and the number of chars in item -1 of tName <= 16 then
         put "." & item -1 of tName into tEnding
      end if
      put char 1 to 80 - the number of chars in tEnding of tName & tEnding into tName
   end if
   return tName
end playerSafeName

-- The folder of the library for a file of this name: named after it
-- without its ending, and with a number after it when there is one of
-- that name already
function playerNewFolder pName
   local tBase, tFolder, tCount
   set the itemDelimiter to "."
   put pName into tBase
   if the number of items in tBase > 1 then
      delete item -1 of tBase
   end if
   if tBase is empty then
      put "stack" into tBase
   end if
   put playerLibraryFolder() & slash & tBase into tFolder
   put 1 into tCount
   repeat while there is a folder tFolder or there is a file tFolder
      add 1 to tCount
      put playerLibraryFolder() & slash & tBase && tCount into tFolder
   end repeat
   return tFolder
end playerNewFolder

command playerEnsureFolder pFolder
   local tPath, tPart
   set the itemDelimiter to slash
   repeat for each item tPart in pFolder
      if tPath is empty and tPart is empty then
         put slash into tPath
         next repeat
      end if
      if tPath is slash or tPath is empty then
         put tPart after tPath
      else
         put slash & tPart after tPath
      end if
      if there is not a folder tPath then
         create folder tPath
      end if
   end repeat
   if there is not a folder pFolder then
      throw "cannot make the folder" && pFolder
   end if
end playerEnsureFolder

-- The stack files of the library, a path each, those opened last first
function playerLibrary
   local tFolder, tEntry, tName, tList, tSeconds, tFiles, tLibrary
   put playerLibraryFolder() into tLibrary
   if there is not a folder tLibrary then
      return empty
   end if
   repeat for each line tFolder in folders(tLibrary)
      if tFolder begins with "." then
         next repeat
      end if
      -- "detailed-utf8", because "detailed" turns a name to the native
      -- encoding first and loses what that has no letter for (a name in
      -- Greek, an emoji), so that the path made from it opens nothing
      put files(tLibrary & slash & tFolder, "detailed-utf8") into tFiles
      repeat for each line tEntry in tFiles
         put textDecode(urlDecode(item 1 of tEntry), "UTF-8") into tName
         if playerIsStackName(tName) then
            put item 5 of tEntry into tSeconds
            put tSeconds & tab & tLibrary & slash & tFolder & slash & tName & return after tList
         end if
      end repeat
   end repeat
   delete the last char of tList
   set the itemDelimiter to tab
   sort lines of tList descending numeric by item 1 of each
   put empty into tFiles
   repeat for each line tEntry in tList
      put item 2 of tEntry & return after tFiles
   end repeat
   delete the last char of tFiles
   return tFiles
end playerLibrary

----------------------------------------------------------------
-- Taking a file in
----------------------------------------------------------------

-- A file another app or the "Open document" screen gave, by its address:
-- copied into the library, and opened
command playerTakeAddress pAddress
   local tFile, tError
   -- Android can give one opening twice (as the app's launch address and
   -- as a wake-up): the second is left alone while the first still plays.
   -- Once the user is back home, the same file opened again is a new ask
   if pAddress is sLastAddress and the seconds - sLastSeconds < 3 and sCurrent is not empty then
      exit playerTakeAddress
   end if
   put pAddress into sLastAddress
   put the seconds into sLastSeconds
   playerSay "taking" && playerAddressKind(pAddress)
   try
      put playerImport(pAddress) into tFile
   catch tError
      playerProblem "That file cannot be read:" && playerErrorLine(tError)
      exit playerTakeAddress
   end try
   playerSay "imported" && playerShortPath(tFile)
   playerOpen tFile
end playerTakeAddress

-- What kind of address it is, for the log (never the address itself,
-- which can name a person's files)
function playerAddressKind pAddress
   set the itemDelimiter to ":"
   if the number of items in pAddress > 1 and the number of chars in item 1 of pAddress <= 12 then
      return item 1 of pAddress
   end if
   return "path"
end playerAddressKind

-- A path as the log and the status line say it: from the library on
function playerShortPath pFile
   if pFile begins with playerLibraryFolder() & slash then
      return char (the number of chars in playerLibraryFolder() + 2) to -1 of pFile
   end if
   set the itemDelimiter to slash
   return item -1 of pFile
end playerShortPath

-- The path a file address names: each %XX its byte, the bytes UTF-8, as
-- an address is written (RFC 3986 and 3629). Not urlDecode, which reads
-- a form: it makes a "+" a space, and each byte a native letter, so that
-- "A+B.oxtstack" and every name in Greek would name another file. A "%"
-- that two hex digits do not follow is itself
function playerAddressPath pAddress
   local tBytes, tPiece, tFirst
   set the itemDelimiter to "%"
   put true into tFirst
   repeat for each item tPiece in pAddress
      if tFirst then
         put false into tFirst
         put textEncode(tPiece, "UTF-8") after tBytes
      else if matchText(char 1 to 2 of tPiece, "^[0-9A-Fa-f]{2}$") then
         put numToByte(baseConvert(char 1 to 2 of tPiece, 16, 10)) after tBytes
         put textEncode(char 3 to -1 of tPiece, "UTF-8") after tBytes
      else
         put textEncode("%" & tPiece, "UTF-8") after tBytes
      end if
   end repeat
   -- an item after a last "%" is empty and so not walked
   if the last char of pAddress is "%" then
      put textEncode("%", "UTF-8") after tBytes
   end if
   return textDecode(tBytes, "UTF-8")
end playerAddressPath

-- Copies the file at an address (content://, file:// or a path) into the
-- library and returns the copy's path: in a new folder of its own, or,
-- when the library has that very file already (the same name and the
-- same bytes: a file opened twice from a mail app, or an app that Android
-- starts again with the file it was first started for), the copy that is
-- there. A file that is no stack by its name stops here.
function playerImport pAddress
   local tName, tFolder, tFile, tSource, tData, tIncoming, tTemp, tSame, tError
   if pAddress begins with "content:" then
      put playerSafeName(androidDocumentName(pAddress)) into tName
   else
      put pAddress into tSource
      if tSource begins with "file://" then
         put playerAddressPath(char 8 to -1 of tSource) into tSource
      end if
      put playerSafeName(tSource) into tName
   end if
   if not playerIsStackName(tName) then
      throw quote & tName & quote && "is not a stack file (its name ends with none of" && kStackEndings & ")"
   end if
   if tSource is not empty and there is not a file tSource then
      throw "there is no file there for this app"
   end if
   -- it arrives beside the library's folders, under a name that is none
   -- of theirs, and moves into one only whole
   put playerLibraryFolder() & "/.incoming" into tIncoming
   playerEnsureFolder tIncoming
   put tIncoming & slash & tName into tTemp
   try
      if there is a file tTemp then
         delete file tTemp
      end if
      if pAddress begins with "content:" then
         androidCopyDocument pAddress, tTemp
      else
         put url ("binfile:" & tSource) into tData
         if the result is not empty then
            throw the result
         end if
         put tData into url ("binfile:" & tTemp)
         if the result is not empty then
            throw the result
         end if
      end if
      if there is not a file tTemp then
         throw "nothing was copied"
      end if
      put playerSameInLibrary(tName, tTemp) into tSame
      if tSame is not empty then
         delete file tTemp
         return tSame
      end if
      put playerNewFolder(tName) into tFolder
      playerEnsureFolder tFolder
      put tFolder & slash & tName into tFile
      rename file tTemp to tFile
      if the result is not empty or there is not a file tFile then
         delete folder tFolder
         throw "the file could not be put into the library"
      end if
   catch tError
      -- nothing of a file that did not arrive stays in the library
      if there is a file tTemp then
         delete file tTemp
      end if
      throw tError
   end try
   return tFile
end playerImport

-- The library's own copy of a file: the stack file of that name in the
-- library whose bytes are those of pFile, or empty
function playerSameInLibrary pName, pFile
   local tDigest, tEntry
   put sha1Digest(url ("binfile:" & pFile)) into tDigest
   set the itemDelimiter to slash
   repeat for each line tEntry in playerLibrary()
      if item -1 of tEntry is pName and sha1Digest(url ("binfile:" & tEntry)) is tDigest then
         return tEntry
      end if
   end repeat
   return empty
end playerSameInLibrary

----------------------------------------------------------------
-- Playing a stack
----------------------------------------------------------------

command playerOpen pFile
   local tName, tError, tFolder
   if sCurrent is not empty then
      playerHome
   end if
   put the mainStacks into sStacksBefore
   set the itemDelimiter to slash
   put item 1 to -2 of pFile into tFolder
   set the itemDelimiter to comma
   try
      -- read without its messages first: its name, and how it wants the
      -- screen
      lock messages
      try
         put the short name of stack pFile into tName
      catch tError
         put empty into tName
      end try
      unlock messages
      if tName is empty then
         -- no stack, whatever its name says: it leaves the library, which
         -- would offer it again on every start
         playerDrop pFile
         throw "it is not a stack file, or one this engine cannot read"
      end if
      if tName is among the lines of sStacksBefore then
         throw "a stack named" && quote & tName & quote && "is part of the player"
      end if
      playerFit tName
      put tName into sCurrent
      put pFile into sCurrentFile
      set the defaultFolder to tFolder
      go stack tName
   catch tError
      unlock messages
      put empty into sCurrent
      put empty into sCurrentFile
      playerForget
      playerProblem "That stack cannot be opened:" && playerErrorLine(tError)
      exit playerOpen
   end try
   playerSay "opened" && tName
end playerOpen

-- A file of the library that is no stack leaves it, with its folder
-- when the folder holds nothing else (each file comes in to a folder of
-- its own). Nothing outside the library is touched
command playerDrop pFile
   local tFolder, tLibrary, tFolders
   put playerLibraryFolder() into tLibrary
   if not (pFile begins with tLibrary & slash) then
      exit playerDrop
   end if
   set the itemDelimiter to slash
   put item 1 to -2 of pFile into tFolder
   set the itemDelimiter to comma
   if there is a file pFile then
      delete file pFile
   end if
   -- folders() names ".." too, and on some systems "."
   put folders(tFolder) into tFolders
   filter lines of tFolders without "."
   filter lines of tFolders without ".."
   if tFolder is not tLibrary and files(tFolder) is empty and tFolders is empty then
      delete folder tFolder
   end if
   playerShowLibrary
   playerSay "dropped" && playerShortPath(pFile)
end playerDrop

-- How a stack that says nothing about a phone's screen is shown on one:
-- whole, scaled to the screen, with bars beside it (showAll). A stack
-- file does not keep its fullscreenMode: a stack made for phones sets it
-- as it opens (in preOpenStack or openStack), after this, and so keeps
-- its own.
command playerFit pStack
   if the fullscreenMode of stack pStack is empty then
      set the fullscreenMode of stack pStack to "showAll"
   end if
end playerFit

-- Back to the player: the stack that plays is closed and leaves memory
-- with every stack it loaded
command playerHome
   local tWas
   put sCurrent into tWas
   put empty into sCurrent
   put empty into sCurrentFile
   playerForget
   set the defaultFolder to specialFolderPath("documents")
   go stack kPlayerName
   playerShowLibrary
   if tWas is not empty then
      playerSay "home from" && tWas
   end if
end playerHome

-- Every main stack loaded since the player opened one leaves memory
private command playerForget
   local tStack
   repeat for each line tStack in the mainStacks
      if tStack is kPlayerName or tStack is among the lines of sStacksBefore then
         next repeat
      end if
      try
         lock messages
         close stack tStack
         delete stack tStack
         unlock messages
      catch tError
         unlock messages
      end try
   end repeat
end playerForget

-- The stack that plays (its short name), or empty at home
function playerCurrent
   return sCurrent
end playerCurrent

----------------------------------------------------------------
-- Problems
----------------------------------------------------------------

-- The line of an error that says what went wrong: an error a script
-- threw is its text, an engine's is its lines of numbers
function playerErrorLine pError
   local tLine, tCode, tText
   put line 1 of pError into tLine
   if item 1 of tLine is a number then
      put item 1 of tLine into tCode
      put line (tCode + 1) of the cScriptErrors of stack kPlayerName into tText
      if tText is empty then
         put "script error" && tCode into tText
      end if
      if item 4 to -1 of tLine is not empty then
         put " (" & item 4 to -1 of tLine & ")" after tText
      end if
      return tText
   end if
   return tLine
end playerErrorLine

-- Something went wrong: said in the log and on the player's card
command playerProblem pText
   playerSay "problem" && pText
   if sCurrent is not empty then
      playerHome
   end if
   playerStatus pText
end playerProblem

-- A script error in the stack that plays (from the back script)
command playerScriptError pError, pTarget
   local tText
   put playerErrorLine(pError) into tText
   playerSay "script error" && tText
   answer "Script error:" && tText with "Go on" or "Back to the player"
   if it is "Back to the player" then
      playerHome
   end if
end playerScriptError
