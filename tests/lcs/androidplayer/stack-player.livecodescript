script "TestAndroidStackPlayer"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- The Android Stack Player's script (tools/android-player/
-- stack-player.livecodescript) on the desktop: its library, the files it
-- takes in by a path, and a stack played and left again. What only
-- Android has (its "Open document" screen, content addresses, the Back
-- key from the system) is checked on an emulator by
-- tools/android-player/build_android_player.py.

constant kPlayer = "OXT Stack Player"

local sWork

private function fileText pPath
   return textDecode(url ("binfile:" & pPath), "UTF-8")
end fileText

-- The paths are whole and literal where they are read: the runners of
-- the Android and web test suites find the checkout's files that tests
-- read by them (TestGetEngineRepositoryPath() & "/<path>")
private function scriptOf pPath
   local tScript
   put fileText(pPath) into tScript
   if line 1 of tScript begins with "script " then
      delete line 1 of tScript
   end if
   return tScript
end scriptOf

private function playerScript
   return scriptOf(TestGetEngineRepositoryPath() & "/tools/android-player/stack-player.livecodescript")
end playerScript

private function backScript
   return scriptOf(TestGetEngineRepositoryPath() & "/tools/android-player/stack-player-back.livecodescript")
end backScript

on TestSetup
   put the tempName & "-player" into sWork
   create folder sWork
   create invisible stack kPlayer
   set the rect of stack kPlayer to 0,0,360,640
   set the script of stack kPlayer to playerScript()
   set the cScriptErrors of stack kPlayer to the scriptExecutionErrors
   dispatch "playerMake" to stack kPlayer with backScript()
   dispatch "playerSetLibraryFolder" to stack kPlayer with sWork & "/library"
   -- as the player's openStack does in the app
   insert the script of button "Player Back Script" of stack kPlayer into back
end TestSetup

on TestTeardown
   local tStack
   if there is a button "Player Back Script" of stack kPlayer then
      remove the script of button "Player Back Script" of stack kPlayer from back
   end if
   repeat for each item tStack in "Sample One,Sample Two," & kPlayer
      if there is a stack tStack then
         delete stack tStack
      end if
   end repeat
   removeTree sWork
end TestTeardown

private command removeTree pFolder
   local tName
   if there is not a folder pFolder then
      exit removeTree
   end if
   repeat for each line tName in files(pFolder)
      delete file (pFolder & slash & tName)
   end repeat
   repeat for each line tName in folders(pFolder)
      if tName is not "." and tName is not ".." then
         removeTree pFolder & slash & tName
      end if
   end repeat
   delete folder pFolder
end removeTree

private function fromPlayer2 pFunction, pArg1, pArg2
   dispatch function pFunction to stack kPlayer with pArg1, pArg2
   return the result
end fromPlayer2

private function fromPlayer pFunction, pArg
   dispatch function pFunction to stack kPlayer with pArg
   return the result
end fromPlayer

-- A stack file outside the library, as a user has one, and gone from
-- memory again. With pFullscreenMode it sets that as it opens, as a stack
-- made for phones does
private function makeSample pName, pFile, pFullscreenMode
   local tPath
   put sWork & slash & pFile into tPath
   if pFile contains slash then
      set the itemDelimiter to slash
      create folder (sWork & slash & item 1 to -2 of pFile)
      set the itemDelimiter to comma
   end if
   create invisible stack pName
   set the rect of stack pName to 0,0,800,600
   set the script of stack pName to "on openStack" & return & "   set the cOpened of me to the cOpened of me + 1" & return & \
         "   if " & quote & pFullscreenMode & quote & " is not empty then set the fullscreenMode of me to " & quote & pFullscreenMode & quote & return & \
         "   set the cFolder of me to the defaultFolder" & return & "end openStack"
   save stack pName as tPath
   delete stack pName
   return tPath
end makeSample

on TestTheControlsAreMade
   local tName, tMissing, tFocus
   repeat for each item tName in "Brand,Title,Help,Library Title,Hint,Library,Empty,Status"
      if there is not a field tName of stack kPlayer then
         put tName & comma after tMissing
      else if the traversalOn of field tName of stack kPlayer or not the lockText of field tName of stack kPlayer then
         put tName & comma after tFocus
      end if
   end repeat
   TestAssert "every field is there", tMissing is empty
   -- a field with the focus brings up Android's keyboard over the library
   TestAssert "no field takes the focus or is typed into", tFocus is empty
   TestAssert "the Open button", there is a button "Open" of stack kPlayer
   TestAssert "the back script's button, with its script", \
         the script of button "Player Back Script" of stack kPlayer contains "on backKey"
   -- the stack's own size: on a phone the engine gives a stack the screen's
   TestAssert "the controls are inside the card", \
         item 3 of the rect of button "Open" of stack kPlayer <= the width of stack kPlayer and \
         item 4 of the rect of field "Status" of stack kPlayer <= the height of stack kPlayer
end TestTheControlsAreMade

-- Android turns the screen: resizeStack comes to the player's card. On a
-- phone the stack keeps the screen's size whatever its rect is set to,
-- and part of it is under Android's bars, so what is asked is measured
-- against what the player says is seen
on TestTheControlsFollowTheScreen
   local tWidth, tHeight
   set the rect of stack kPlayer to 0,0,640,360
   dispatch "resizeStack" to this card of stack kPlayer with 640,360,360,640
   put fromPlayer("playerSeenWidth") into tWidth
   put fromPlayer("playerSeenHeight") into tHeight
   TestAssert "the Open button is as wide as the seen card", \
         the width of button "Open" of stack kPlayer is tWidth - 40
   TestAssert "the status line is on the seen card", the bottom of field "Status" of stack kPlayer <= tHeight
   if the environment is "mobile" then
      TestSkip "off a phone the whole card is seen", "this is a phone"
   else
      TestAssert "off a phone the whole card is seen", tHeight is 360 and tWidth is 640
   end if
end TestTheControlsFollowTheScreen

on TestTheLibraryAsItIsShown
   local tCopy
   dispatch "playerShowLibrary" to stack kPlayer
   TestAssert "an empty library says how to fill it", the visible of field "Empty" of stack kPlayer
   TestAssert "and counts nothing", field "Library Title" of stack kPlayer is "YOUR STACKS"
   put fromPlayer("playerImport", makeSample("Sample One", "A &amp; B &lt;i&gt;.livecode", empty)) into tCopy
   dispatch "playerShowLibrary" to stack kPlayer
   -- (a file's name cannot hold < or >: playerSafeName makes them _)
   TestAssert "a name with & is shown as it is, not as HTML", \
         line 1 of the text of field "Library" of stack kPlayer is "A &amp; B &lt;i&gt;" & tab & "livecode - today"
   TestAssert "the empty library's words go", not the visible of field "Empty" of stack kPlayer
   TestAssert "the stacks are counted", field "Library Title" of stack kPlayer is "YOUR STACKS (1)"
   TestAssert "its line opens its file", line 1 of the cFiles of field "Library" of stack kPlayer is tCopy
end TestTheLibraryAsItIsShown

on TestWhenAsAPersonSaysIt
   local tNow, tThen
   put "2026,11,19,18,30,0,5" into tNow
   convert tNow from dateItems to seconds
   put "2026,11,19,0,10,0,5" into tThen
   convert tThen from dateItems to seconds
   TestAssert "earlier the same day", fromPlayer2("playerWhen", tThen, tNow) is "today"
   put "2026,11,18,23,50,0,4" into tThen
   convert tThen from dateItems to seconds
   TestAssert "the evening before", fromPlayer2("playerWhen", tThen, tNow) is "yesterday"
   put "2026,3,2,12,0,0,2" into tThen
   convert tThen from dateItems to seconds
   TestAssert "this year", fromPlayer2("playerWhen", tThen, tNow) is "2 Mar"
   put "2025,12,31,12,0,0,4" into tThen
   convert tThen from dateItems to seconds
   TestAssert "a year before", fromPlayer2("playerWhen", tThen, tNow) is "31 Dec 2025"
   TestAssert "no time", fromPlayer2("playerWhen", empty, tNow) is "new"
end TestWhenAsAPersonSaysIt

on TestAStackIsRemoved
   local tCopy, tOther
   put fromPlayer("playerImport", makeSample("Sample One", "Sample One.oxtstack", empty)) into tCopy
   put fromPlayer("playerImport", makeSample("Sample Two", "Sample Two.oxtstack", empty)) into tOther
   -- what the stack saved beside itself goes with it
   put "notes" into url ("file:" & sWork & "/library/Sample One/notes.txt")
   dispatch "playerRemove" to stack kPlayer with tCopy
   TestAssert "its folder has gone, with what it saved", there is not a folder (sWork & "/library/Sample One")
   TestAssert "the other stays", fromPlayer("playerLibrary") is tOther
   TestAssert "the list shows the other alone", the number of lines in the text of field "Library" of stack kPlayer is 1
   TestAssert "the file it came from is where it was", there is a file (sWork & "/Sample One.oxtstack")
   dispatch "playerRemove" to stack kPlayer with sWork & "/Sample Two.oxtstack"
   TestAssert "a file outside the library is never removed", there is a file (sWork & "/Sample Two.oxtstack")
   dispatch "playerRemove" to stack kPlayer with sWork & "/library/../Sample Two.oxtstack"
   TestAssert "nor one reached from it by ..", there is a file (sWork & "/Sample Two.oxtstack")
end TestAStackIsRemoved

on TestStackNames
   TestAssert "an oxtstack", fromPlayer("playerIsStackName", "My Stack.oxtstack")
   TestAssert "a livecode file, in capitals", fromPlayer("playerIsStackName", "OLD.LIVECODE")
   TestAssert "a rev file", fromPlayer("playerIsStackName", "a.rev")
   TestAssert "a script-only stack", fromPlayer("playerIsStackName", "a.livecodescript")
   TestAssert "a picture is none", not fromPlayer("playerIsStackName", "a.png")
   TestAssert "a name without an ending is none", not fromPlayer("playerIsStackName", "oxtstack")
   TestAssert "an ending inside the name is none", not fromPlayer("playerIsStackName", "a.oxtstack.exe")
end TestStackNames

on TestSafeNames
   TestAssert "a plain name stays", fromPlayer("playerSafeName", "My Stack.oxtstack") is "My Stack.oxtstack"
   TestAssert "only the last path item", fromPlayer("playerSafeName", "../../etc/passwd") is "passwd"
   TestAssert "of a Windows path too", fromPlayer("playerSafeName", "C:\Users\x\a.rev") is "a.rev"
   TestAssert "no dot in front", fromPlayer("playerSafeName", "..hidden.rev") is "hidden.rev"
   TestAssert "no control or reserved characters", \
         fromPlayer("playerSafeName", "a" & numToCodepoint(10) & "b:c*d?.rev") is "a_b_c_d_.rev"
   TestAssert "nothing left gives a name", fromPlayer("playerSafeName", "...") is "stack"
   TestAssert "empty gives a name", fromPlayer("playerSafeName", empty) is "stack"
   local tLong, tSafe
   repeat 30 times
      put "abcdefghij" after tLong
   end repeat
   put fromPlayer("playerSafeName", tLong & ".oxtstack") into tSafe
   TestAssert "a long name is cut to 80 characters", the number of chars in tSafe is 80
   TestAssert "and keeps its ending", tSafe ends with ".oxtstack"
end TestSafeNames

-- A file address as Android writes one (Uri.fromFile): each byte of the
-- path's UTF-8 that is not a letter, a digit, one of -_.~ or a slash as
-- %XX; a space is %20, never the "+" of urlEncode
private function fileAddress pPath
   local tBytes, tByte, tCode, tAddress
   put textEncode(pPath, "UTF-8") into tBytes
   repeat for each byte tByte in tBytes
      put byteToNum(tByte) into tCode
      if (tCode >= 48 and tCode <= 57) or (tCode >= 65 and tCode <= 90) or (tCode >= 97 and tCode <= 122) \
            or tCode is among the items of "45,46,47,95,126" then
         put numToChar(tCode) after tAddress
      else
         put "%" & char -2 to -1 of ("0" & baseConvert(tCode, 10, 16)) after tAddress
      end if
   end repeat
   return "file://" & tAddress
end fileAddress

on TestAFileIsTakenIntoTheLibrary
   local tSource, tCopy, tAgain, tOther
   put makeSample("Sample One", "Sample One.oxtstack", empty) into tSource
   put fromPlayer("playerImport", tSource) into tCopy
   TestAssert "the copy is in a folder of its own in the library", \
         tCopy is sWork & "/library/Sample One/Sample One.oxtstack"
   TestAssert "and is the file", url ("binfile:" & tCopy) is url ("binfile:" & tSource)
   put fromPlayer("playerImport", fileAddress(tSource)) into tAgain
   TestAssert "the same file again, by a file address too, is the copy that is there", tAgain is tCopy
   TestAssert "the library lists it once", the number of lines in fromPlayer("playerLibrary") is 1
   -- another file of that name
   put makeSample("Sample Two", "other/Sample One.oxtstack", empty) into tOther
   put fromPlayer("playerImport", tOther) into tAgain
   TestAssert "another file of that name goes beside it", \
         tAgain is sWork & "/library/Sample One 2/Sample One.oxtstack"
   TestAssert "the library lists both", the number of lines in fromPlayer("playerLibrary") is 2
   TestAssert "nothing is left where files arrive", files(sWork & "/library/.incoming") is empty
end TestAFileIsTakenIntoTheLibrary

-- A name the native encoding has no letters for: Greek, and an emoji
private function farName
   return numToCodepoint(0x3A3) & numToCodepoint(0x3C4) & numToCodepoint(0x3B1) & numToCodepoint(0x3BA) & \
         " " & numToCodepoint(0x1F60A)
end farName

on TestAFarNameStaysWhole
   local tSource, tCopy, tAgain
   put makeSample("Sample One", farName() & ".oxtstack", empty) into tSource
   put fromPlayer("playerImport", fileAddress(tSource)) into tCopy
   TestAssert "a file address with such a name finds its file", \
         tCopy is sWork & "/library/" & farName() & "/" & farName() & ".oxtstack"
   TestAssert "the library lists it by its own path", fromPlayer("playerLibrary") is tCopy
   TestAssert "and that path is the file", there is a file (line 1 of fromPlayer("playerLibrary"))
   put fromPlayer("playerImport", fileAddress(tSource)) into tAgain
   TestAssert "given again, it is the copy that is there", tAgain is tCopy
   TestAssert "and the library still lists it once", the number of lines in fromPlayer("playerLibrary") is 1
end TestAFarNameStaysWhole

on TestAPlusInAnAddressIsAPlus
   local tPlus, tSpace, tCopy
   put makeSample("Sample One", "A+B.oxtstack", empty) into tPlus
   put makeSample("Sample Two", "A B.oxtstack", empty) into tSpace
   put fromPlayer("playerImport", "file://" & tPlus) into tCopy
   TestAssert "a + written as it is names the file with a +", tCopy ends with "/A+B.oxtstack"
   put fromPlayer("playerImport", "file://" & replaceText(tSpace, " ", "%20")) into tCopy
   TestAssert "and %20 the file with a space", tCopy ends with "/A B.oxtstack"
end TestAPlusInAnAddressIsAPlus

on TestAddressPaths
   TestAssert "%2B is a +", fromPlayer("playerAddressPath", "/a/A%2BB") is "/a/A+B"
   TestAssert "a + is a +", fromPlayer("playerAddressPath", "/a/A+B") is "/a/A+B"
   TestAssert "the bytes are UTF-8", \
         fromPlayer("playerAddressPath", "/a/%CE%A3%F0%9F%98%8A") is "/a/" & numToCodepoint(0x3A3) & numToCodepoint(0x1F60A)
   TestAssert "a letter written as it is stays", \
         fromPlayer("playerAddressPath", "/a/" & numToCodepoint(0x3A3)) is "/a/" & numToCodepoint(0x3A3)
   TestAssert "a % with no two hex digits is itself", fromPlayer("playerAddressPath", "/a/100%_b%") is "/a/100%_b%"
   TestAssert "%% is two of them", fromPlayer("playerAddressPath", "%%41") is "%A"
end TestAddressPaths

on ImportAPicture
   put "not a stack" into url ("binfile:" & sWork & "/picture.png")
   get fromPlayer("playerImport", sWork & "/picture.png")
end ImportAPicture

on ImportNothing
   get fromPlayer("playerImport", sWork & "/missing.oxtstack")
end ImportNothing

on TestWhatIsNoStackStaysOut
   TestAssertThrow "a file that is no stack by its name is refused", "ImportAPicture", the long id of me
   TestAssertThrow "a file that is not there is refused", "ImportNothing", the long id of me
   TestAssert "and nothing of either is in the library", \
         there is not a folder (sWork & "/library") or fromPlayer("playerLibrary") is empty
end TestWhatIsNoStackStaysOut

-- A folder as the engine names it once it is the defaultFolder (Android
-- names the app's own folder /data/data/... however it was reached)
private function folderAsTheEngineSays pFolder
   local tWas, tFolder
   put the defaultFolder into tWas
   set the defaultFolder to pFolder
   put the defaultFolder into tFolder
   set the defaultFolder to tWas
   return tFolder
end folderAsTheEngineSays

-- A file named as a stack that is none: Android hands the player any
-- file of such a name
on TestANoStackFileLeavesTheLibrary
   local tFile, tCopy
   put sWork & "/Broken.oxtstack" into tFile
   put "this is no stack" into url ("binfile:" & tFile)
   put fromPlayer("playerImport", tFile) into tCopy
   TestAssert "it comes into the library by its name", there is a file tCopy
   dispatch "playerOpen" to stack kPlayer with tCopy
   TestAssert "it does not play", fromPlayer("playerCurrent") is empty
   TestAssert "the player says so on its card", \
         field "Status" of stack kPlayer begins with "That stack cannot be opened: it is not a stack file"
   TestAssert "it has left the library", there is not a file tCopy and fromPlayer("playerLibrary") is empty
   TestAssert "with its folder", there is not a folder (sWork & "/library/Broken")
   TestAssert "and the list shows it no more", the text of field "Library" of stack kPlayer is empty
   TestAssert "the file it came from is where it was", there is a file tFile
end TestANoStackFileLeavesTheLibrary

-- Only a file of the library is ever dropped
on TestOnlyTheLibraryIsDropped
   local tCopy
   put fromPlayer("playerImport", makeSample("Sample One", "Sample One.oxtstack", empty)) into tCopy
   dispatch "playerDrop" to stack kPlayer with sWork & "/elsewhere.oxtstack"
   TestAssert "a file outside the library is never dropped", fromPlayer("playerLibrary") is tCopy
end TestOnlyTheLibraryIsDropped

on TestAStackPlaysAndIsLeft
   local tCopy, tFolder
   put fromPlayer("playerImport", makeSample("Sample One", "Sample One.oxtstack", empty)) into tCopy
   put folderAsTheEngineSays(sWork & "/library/Sample One") into tFolder
   dispatch "playerOpen" to stack kPlayer with tCopy
   TestAssert "the stack is open", "Sample One" is among the lines of the openStacks
   TestAssert "the player says which plays", fromPlayer("playerCurrent") is "Sample One"
   TestAssert "its openStack ran once", the cOpened of stack "Sample One" is 1
   TestAssert "with its folder as the defaultFolder", \
         the cFolder of stack "Sample One" is tFolder
   TestAssert "a stack that says nothing of the screen is shown whole", \
         the fullscreenMode of stack "Sample One" is "showAll"
   -- Android's Back, which the stack does not handle
   dispatch "backKey" to this card of stack "Sample One"
   TestAssert "Back comes home", fromPlayer("playerCurrent") is empty
   TestAssert "the stack has left memory", there is not a stack "Sample One"
   TestAssert "the library lists it, by its name, its kind and when", \
         line 1 of the text of field "Library" of stack kPlayer is "Sample One" & tab & "oxtstack - today"
   -- and from the library's list
   dispatch "playerPickLine" to stack kPlayer with 1
   TestAssert "a tap on its line plays it again", fromPlayer("playerCurrent") is "Sample One"
   dispatch "playerHome" to stack kPlayer
end TestAStackPlaysAndIsLeft

-- Android can give one opening twice; the same file opened again after
-- the user came home is a new ask, however soon
on TestAnAddressGivenTwice
   local tFile
   put makeSample("Sample One", "Sample One.oxtstack", empty) into tFile
   dispatch "playerTakeAddress" to stack kPlayer with tFile
   TestAssert "the stack plays", fromPlayer("playerCurrent") is "Sample One"
   dispatch "playerTakeAddress" to stack kPlayer with tFile
   TestAssert "given again at once, it is not opened a second time", the cOpened of stack "Sample One" is 1
   dispatch "playerHome" to stack kPlayer
   dispatch "playerTakeAddress" to stack kPlayer with tFile
   TestAssert "given again after the user came home, it plays again", fromPlayer("playerCurrent") is "Sample One"
   TestAssert "and is the library's one copy", the number of lines in fromPlayer("playerLibrary") is 1
   dispatch "playerHome" to stack kPlayer
end TestAnAddressGivenTwice

on TestAStacksOwnScreenModeIsKept
   local tCopy
   put fromPlayer("playerImport", makeSample("Sample Two", "Sample Two.livecode", "exactFit")) into tCopy
   dispatch "playerOpen" to stack kPlayer with tCopy
   TestAssert "its fullscreenMode is its own", the fullscreenMode of stack "Sample Two" is "exactFit"
   dispatch "playerHome" to stack kPlayer
end TestAStacksOwnScreenModeIsKept

on TestOneStackAtATime
   local tOne, tTwo
   put fromPlayer("playerImport", makeSample("Sample One", "Sample One.oxtstack", empty)) into tOne
   put fromPlayer("playerImport", makeSample("Sample Two", "Sample Two.livecode", empty)) into tTwo
   dispatch "playerOpen" to stack kPlayer with tOne
   dispatch "playerOpen" to stack kPlayer with tTwo
   TestAssert "the second plays", fromPlayer("playerCurrent") is "Sample Two"
   TestAssert "the first has left memory", there is not a stack "Sample One"
   dispatch "playerHome" to stack kPlayer
end TestOneStackAtATime

on TestAStackNamedAsThePlayerIsRefused
   local tCopy
   put fromPlayer("playerImport", makeSample("Sample One", "Sample One.oxtstack", empty)) into tCopy
   -- a file that is no stack at all, under a stack's name
   put "nothing of a stack" into url ("binfile:" & tCopy)
   dispatch "playerOpen" to stack kPlayer with tCopy
   TestAssert "a file that is no stack does not play", fromPlayer("playerCurrent") is empty
   TestAssert "and the player says so", the text of field "Status" of stack kPlayer begins with "That stack cannot be opened"
end TestAStackNamedAsThePlayerIsRefused

on TestErrorLines
   TestAssert "an error a script threw is its text", fromPlayer("playerErrorLine", "the file is gone") is "the file is gone"
   TestAssert "an engine's error is its text", \
         fromPlayer("playerErrorLine", "219,3,1,foo") begins with line 220 of the scriptExecutionErrors
end TestErrorLines
