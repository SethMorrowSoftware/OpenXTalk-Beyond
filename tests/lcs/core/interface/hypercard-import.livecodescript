script "CoreInterfaceHyperCardImport"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

-- "import stack from file" with HyperCard stacks. The stacks in
-- lcs-input-files/hypercard are HyperCardPreview's test stacks (MIT, see
-- the LICENSE.txt there) and, in games/, a game released into the public
-- domain (UNLICENSE.txt); the README there says where each came from. The
-- values asserted for HyperCardPreview's stacks are the ones its own tests
-- assert, read the way this importer has always mapped HyperCard onto the
-- engine: rects one pixel wider and taller, the text of a background field
-- on a card is that card's text, HyperCard addressing ("field 1" is a
-- background field, "card field 1" a card's own).
--
-- An imported stack is opened, and its scripts run from then on: the
-- imports below lock messages so that no stack's own handlers run here.

-- Import lcs-input-files/hypercard/<pPath>, which makes a stack named
-- pStack (a plain stack is named after its file, a MacBinary or BinHex one
-- after the Mac file inside it).
private function _ImportFile pPath, pStack
   local tError
   lock messages
   try
      import stack from file TestGetInputFile("hypercard/" & pPath)
   catch tError
   end try
   unlock messages
   TestAssert pPath && "imports", tError is empty and there is a stack pStack
   return pStack
end _ImportFile

private function _Import pName
   return _ImportFile(pName & ".stack", pName & ".stack")
end _Import

private command _Close pStack
   lock messages
   if there is a stack pStack then
      delete stack pStack
   end if
   unlock messages
end _Close

private function _BgButton pStack, pBg, pIndex
   return the long id of button pIndex of bg pBg of stack pStack
end _BgButton

private function _BgField pStack, pBg, pIndex
   return the long id of field pIndex of bg pBg of stack pStack
end _BgField

on TestHyperCardImportCardsAndBackgrounds
   local tStack
   put _Import("TestCardsBackgrounds") into tStack
   TestAssert "number of cards", the number of cards of stack tStack is 6
   TestAssert "first and last card ids", \
      the id of card 1 of stack tStack & comma & the id of card 6 of stack tStack is "2842,5225"
   TestAssert "marked cards", \
      the mark of card 2 of stack tStack and not the mark of card 3 of stack tStack
   TestAssert "number of backgrounds", the number of bgs of stack tStack is 3
   TestAssert "background of card 3", the id of group 1 of card 3 of stack tStack is 3887
   _Close tStack
end TestHyperCardImportCardsAndBackgrounds

on TestHyperCardImportNewStackCard
   -- With messages unlocked, the import's new stack gets newStack, and a
   -- handler that refers to one of its cards (the IDE's do) made a card on
   -- the empty stack, which was kept as an extra, empty first card
   local tFront, tStack, tError
   put "HCNewStackFront" into tFront
   lock messages
   create stack tFront
   unlock messages
   set the script of stack tFront to "on newStack" & return & \
      "get the id of card 1 of the target" & return & \
      "pass newStack" & return & "end newStack"
   insert the script of stack tFront into front
   try
      import stack from file TestGetInputFile("hypercard/TestCardsBackgrounds.stack")
   catch tError
   end try
   remove the script of stack tFront from front
   _Close tFront
   put "TestCardsBackgrounds.stack" into tStack
   TestAssert "imports with messages unlocked", tError is empty and there is a stack tStack
   TestAssert "no card made by newStack", the number of cards of stack tStack is 6
   TestAssert "HyperCard's first card is the first card", the id of card 1 of stack tStack is 2842
   TestAssert "and the current card", the id of this card of stack tStack is 2842
   _Close tStack
end TestHyperCardImportNewStackCard

on TestHyperCardImportNewStackControl
   -- A newStack handler that puts a control on the new stack keeps its
   -- card, in front of HyperCard's, as before (deleting the card would
   -- leave the control behind)
   local tFront, tStack, tError
   put "HCNewStackControlFront" into tFront
   lock messages
   create stack tFront
   unlock messages
   set the script of stack tFront to "on newStack" & return & \
      "create button " & quote & "Made" & quote & " in card 1 of the target" & return & \
      "pass newStack" & return & "end newStack"
   insert the script of stack tFront into front
   try
      import stack from file TestGetInputFile("hypercard/TestCardsBackgrounds.stack")
   catch tError
   end try
   remove the script of stack tFront from front
   _Close tFront
   put "TestCardsBackgrounds.stack" into tStack
   TestAssert "imports with a control made by newStack", tError is empty and there is a stack tStack
   TestAssert "the card made by newStack is kept", the number of cards of stack tStack is 7
   TestAssert "with its control", there is a button "Made" of card 1 of stack tStack
   TestAssert "then HyperCard's first card", the id of card 2 of stack tStack is 2842
   _Close tStack
end TestHyperCardImportNewStackControl

on TestHyperCardImportMacRomanText
   -- the text is MacRoman, and comes in as the same characters on every
   -- platform (off the Mac it was converted the wrong way: a curly quote
   -- came in as a letter with an accent)
   local tStack
   put _Import("TestStrangeFlags") into tStack
   TestAssert "left double quote", \
      codepointToNum(char 7 of field 12 of card 13 of stack tStack) is 8220
   TestAssert "apostrophe", \
      codepointToNum(char 105 of field 4 of card 16 of stack tStack) is 8217
   _Close tStack
end TestHyperCardImportMacRomanText

on TestHyperCardImportCardOrder
   -- 200 cards over two PAGE blocks: the order is the LIST's
   local tStack
   put _Import("TestManyCards") into tStack
   TestAssert "number of cards", the number of cards of stack tStack is 200
   TestAssert "card order across pages", \
      the id of card 1 of stack tStack & comma & the id of card 101 of stack tStack \
      & comma & the id of card 102 of stack tStack & comma & the id of card 200 of stack tStack \
      is "2928,54806,3662,28851"
   _Close tStack
end TestHyperCardImportCardOrder

on TestHyperCardImportStack
   local tStack
   put _Import("TestWindowSize") into tStack
   TestAssert "card size", the width of stack tStack & "x" & the height of stack tStack is "640x480"
   _Close tStack

   put _Import("TestStackScript") into tStack
   TestAssert "stack script", the script of stack tStack is "-- script of stack" & return & "-- with two lines"
   _Close tStack
end TestHyperCardImportStack

on TestHyperCardImportCardProperties
   local tStack
   put _Import("TestCardProperties") into tStack
   TestAssert "cantDelete", the cantDelete of card 1 of stack tStack and not the cantDelete of card 2 of stack tStack
   TestAssert "dontSearch", the dontSearch of card 3 of stack tStack and not the dontSearch of card 4 of stack tStack
   TestAssert "card name", the short name of card 4 of stack tStack is "some card name"
   TestAssert "card script", the script of card 5 of stack tStack is "-- card script"
   _Close tStack
end TestHyperCardImportCardProperties

on TestHyperCardImportBackgroundProperties
   local tStack
   put _Import("TestBackgroundProperties") into tStack
   TestAssert "cantDelete", the cantDelete of bg 1 of stack tStack and not the cantDelete of bg 2 of stack tStack
   TestAssert "dontSearch", the dontSearch of bg 3 of stack tStack and not the dontSearch of bg 4 of stack tStack
   TestAssert "background name", the short name of bg 4 of stack tStack is "some background name"
   TestAssert "background script", the script of bg 5 of stack tStack is "-- background script"
   _Close tStack
end TestHyperCardImportBackgroundProperties

on TestHyperCardImportButtons
   local tStack
   put _Import("TestButtonProperties") into tStack
   TestAssert "part ids", the altId of _BgButton(tStack, 1, 1) & comma & the altId of _BgButton(tStack, 1, 2) is "1,2"
   TestAssert "enabled", the disabled of _BgButton(tStack, 1, 2) and not the disabled of _BgButton(tStack, 1, 3)
   TestAssert "visible", not the visible of _BgButton(tStack, 1, 3) and the visible of _BgButton(tStack, 1, 4)
   TestAssert "rect", the rect of _BgButton(tStack, 1, 4) is "44,188,140,211"
   TestAssert "family", the family of _BgButton(tStack, 1, 5) is 6
   TestAssert "sharedHilite", not the sharedHilite of _BgButton(tStack, 1, 6) and the sharedHilite of _BgButton(tStack, 1, 7)
   TestAssert "autoHilite", the autoHilite of _BgButton(tStack, 1, 7) and not the autoHilite of _BgButton(tStack, 1, 8)
   TestAssert "hilite", the hilite of _BgButton(tStack, 1, 8) and not the hilite of _BgButton(tStack, 1, 9)
   TestAssert "showName", not the showName of _BgButton(tStack, 1, 9) and the showName of _BgButton(tStack, 1, 10)
   TestAssert "name", the short name of _BgButton(tStack, 1, 11) is "some button name"
   TestAssert "script", the script of _BgButton(tStack, 1, 12) is "-- some button script"
   TestAssert "content", the text of _BgButton(tStack, 1, 13) is "some button content"
   -- HyperCardPreview counts the selected item from 0
   TestAssert "popup selected item", the menuHistory of _BgButton(tStack, 2, 1) is 4
   TestAssert "popup title width", the labelWidth of _BgButton(tStack, 2, 2) is 23
   TestAssert "text style", the textStyle of _BgButton(tStack, 4, 1) is "bold,underline"
   TestAssert "text font", the textFont of _BgButton(tStack, 4, 2) is "Geneva"
   TestAssert "text size", the textSize of _BgButton(tStack, 4, 3) is 17
   TestAssert "text align", the textAlign of _BgButton(tStack, 4, 4) & comma & \
      the textAlign of _BgButton(tStack, 4, 5) & comma & the textAlign of _BgButton(tStack, 4, 6) \
      is "left,center,right"
   _Close tStack
end TestHyperCardImportButtons

on TestHyperCardImportFields
   local tStack, tStyles
   put _Import("TestFieldProperties") into tStack
   TestAssert "part ids", the altId of _BgField(tStack, 1, 1) & comma & the altId of _BgField(tStack, 1, 2) is "5,6"
   TestAssert "lockText", the lockText of _BgField(tStack, 1, 2) and not the lockText of _BgField(tStack, 1, 3)
   TestAssert "autoTab", the autoTab of _BgField(tStack, 1, 3) and not the autoTab of _BgField(tStack, 1, 4)
   TestAssert "fixedLineHeight", the fixedLineHeight of _BgField(tStack, 1, 4) and not the fixedLineHeight of _BgField(tStack, 1, 5)
   TestAssert "sharedText", the sharedText of _BgField(tStack, 1, 5) and not the sharedText of _BgField(tStack, 1, 6)
   TestAssert "dontSearch", the dontSearch of _BgField(tStack, 1, 6) and not the dontSearch of _BgField(tStack, 1, 7)
   TestAssert "dontWrap", the dontWrap of _BgField(tStack, 1, 7) and not the dontWrap of _BgField(tStack, 1, 8)
   TestAssert "visible", not the visible of _BgField(tStack, 1, 8) and the visible of _BgField(tStack, 1, 9)
   TestAssert "rect", the rect of _BgField(tStack, 1, 9) is "271,210,447,239"
   TestAssert "multipleLines", the multipleHilites of _BgField(tStack, 1, 10) and not the multipleHilites of _BgField(tStack, 1, 9)
   TestAssert "wideMargins", the leftMargin of _BgField(tStack, 2, 1) & comma & the leftMargin of _BgField(tStack, 2, 2) is "14,8"
   TestAssert "showLines", the showLines of _BgField(tStack, 2, 2) and not the showLines of _BgField(tStack, 2, 3)
   TestAssert "autoSelect", the listBehavior of _BgField(tStack, 2, 3) and not the listBehavior of _BgField(tStack, 2, 2)
   TestAssert "name", the short name of _BgField(tStack, 2, 5) is "some field name"
   TestAssert "script", the script of _BgField(tStack, 2, 6) is "-- some field script"
   TestAssert "text style", the textStyle of _BgField(tStack, 3, 1) is "italic,link"
   TestAssert "text font", the textFont of _BgField(tStack, 3, 2) is "Palatino"
   TestAssert "text size", the textSize of _BgField(tStack, 3, 3) is 17
   TestAssert "text align", the textAlign of _BgField(tStack, 3, 4) & comma & \
      the textAlign of _BgField(tStack, 3, 5) & comma & the textAlign of _BgField(tStack, 3, 6) \
      is "left,center,right"
   TestAssert "text height", the textHeight of _BgField(tStack, 3, 7) is 21
   repeat with tIndex = 1 to 5
      put the opaque of _BgField(tStack, 4, tIndex) & "/" & the showBorder of _BgField(tStack, 4, tIndex) \
         & "/" & the shadow of _BgField(tStack, 4, tIndex) & "/" & the vScrollbar of _BgField(tStack, 4, tIndex) \
         & comma after tStyles
   end repeat
   TestAssert "field styles", tStyles is \
      "false/false/false/false,true/false/false/false,true/true/false/false,true/true/true/false,true/true/false/true,"
   _Close tStack
end TestHyperCardImportFields

on TestHyperCardImportContents
   local tStack
   put _Import("TestContents") into tStack
   TestAssert "card's text in a background field", the text of _BgField(tStack, 1, 1) is "card content in bg field"
   TestAssert "shared text", the text of _BgField(tStack, 1, 2) is "shared content"
   TestAssert "card field", the text of card field 1 of card 1 of stack tStack is "card content"
   _Close tStack
end TestHyperCardImportContents

on TestHyperCardImportStyledText
   -- style runs, one after another on a single line
   local tStack, tField
   put _Import("TestFormattedContent") into tStack
   TestAssert "plain text", the text of card field 1 of card 1 of stack tStack is "unformatted content"
   put the long id of card field 2 of card 1 of stack tStack into tField
   TestAssert "styled text", the text of tField is "formatted content: fontsizestyleall"
   TestAssert "font run", the textFont of char 20 to 23 of tField is "Palatino"
   TestAssert "size run", the textSize of char 24 to 27 of tField is 18
   TestAssert "style run", the textStyle of char 28 to 32 of tField is "bold"
   TestAssert "font, size and style run", the textFont of char 33 to 35 of tField & "/" & \
      the textSize of char 33 to 35 of tField & "/" & the textStyle of char 33 to 35 of tField \
      is "Courier/10/underline"
   TestAssert "unstyled run", the textFont of char 1 to 19 of tField is empty
   _Close tStack
end TestHyperCardImportStyledText

on TestHyperCardImportVersion1
   local tStack
   put _Import("TestV1") into tStack
   TestAssert "number of cards", the number of cards of stack tStack is 9
   TestAssert "number of backgrounds", the number of bgs of stack tStack is 3
   TestAssert "card buttons", the number of card buttons of card 1 of stack tStack is 7
   TestAssert "background buttons", the number of buttons of group 1 of card 1 of stack tStack is 3
   TestAssert "background field text", the text of field 1 of card 2 of stack tStack is "First, Previous, Next, Last, Return"
   _Close tStack
end TestHyperCardImportVersion1

on TestHyperCardImportPicture
   local tStack, tImage, tData, tAlpha
   put _Import("TestBitmap") into tStack
   TestAssert "card has a picture", the number of card images of card 1 of stack tStack is 1
   put the long id of image 1 of card 1 of stack tStack into tImage
   -- the picture is cut to the rows that have something in them
   TestAssert "picture rect", the rect of tImage is "0,0,512,98"
   -- with no mask, white is clear and black opaque: rows 0 to 7 are
   -- white, row 8 black (HyperCardPreview's rendering of the card)
   put the imageData of tImage into tData
   put the alphaData of tImage into tAlpha
   TestAssert "white is clear", byteToNum(byte 1 of tAlpha) is 0
   TestAssert "black is opaque", byteToNum(byte (512 * 8 + 1) of tAlpha) is 255
   TestAssert "black pixel", byte (512 * 4 * 8 + 2) to (512 * 4 * 8 + 4) of tData is \
      numToByte(0) & numToByte(0) & numToByte(0)
   _Close tStack
end TestHyperCardImportPicture

on TestHyperCardImportMacBinary
   -- the same stack in a MacBinary file, as a download from the Mac
   local tStack, tData, tHeader, tFile
   put url ("binfile:" & TestGetInputFile("hypercard/TestCardsBackgrounds.stack")) into tData
   -- the stack takes the Mac file name from the MacBinary header
   put numToByte(0) & numToByte(15) & "HCMacBinaryTest" into tHeader
   repeat 48 times
      put numToByte(0) after tHeader
   end repeat
   put "STAKWILD" after tHeader
   repeat 10 times
      put numToByte(0) after tHeader
   end repeat
   put binaryEncode("N", the number of bytes of tData) after tHeader
   repeat 128 - the number of bytes of tHeader times
      put numToByte(0) after tHeader
   end repeat
   put the temporary folder & "/hypercard-import-test.bin" into tFile
   put tHeader & tData into url ("binfile:" & tFile)
   lock messages
   import stack from file tFile
   unlock messages
   TestAssert "MacBinary imports", the result is empty
   put "HCMacBinaryTest" into tStack
   TestAssert "MacBinary cards", the number of cards of stack tStack is 6
   _Close tStack
   delete file tFile
end TestHyperCardImportMacBinary

on TestHyperCardImportNotAStack
   -- a file that is not a HyperCard stack throws, as it always has
   local tFile
   put the temporary folder & "/hypercard-import-test.txt" into tFile
   put "not a stack" into url ("binfile:" & tFile)
   local tError
   try
      import stack from file tFile
   catch tError
   end try
   TestAssert "not a stack is refused", tError is not empty
   delete file tFile
end TestHyperCardImportNotAStack

on TestHyperCardImportBinHex
   -- a BinHex 4.0 file, as stacks were posted to bulletin boards
   local tStack, tField
   put _ImportFile("TestFormattedContent.hqx", "TestFormattedContent") into tStack
   put the long id of card field 2 of card 1 of stack tStack into tField
   TestAssert "BinHex text", the text of tField is "formatted content: fontsizestyleall"
   TestAssert "BinHex style run", the textFont of char 20 to 23 of tField is "Palatino"
   _Close tStack
end TestHyperCardImportBinHex

on TestHyperCardImportOddStacks
   local tStack
   -- the top bits of some block sizes are flags
   put _Import("TestStrangeFlags") into tStack
   TestAssert "flagged block sizes: cards", the number of cards of stack tStack is 17
   TestAssert "flagged block sizes: backgrounds", the number of bgs of stack tStack is 17
   _Close tStack

   -- a password, and a password with Private Access, which encrypts part
   -- of the stack's header: the stack still imports
   put _Import("TestPassword") into tStack
   TestAssert "password: cards", the number of cards of stack tStack is 1
   _Close tStack
   put _Import("TestPrivateAccess") into tStack
   TestAssert "private access: cards", the number of cards of stack tStack is 1
   _Close tStack
end TestHyperCardImportOddStacks

on TestHyperCardImportGame
   -- a whole game from the time: 67 cards, each with its own picture
   local tStack, tPictures
   put _ImportFile("games/Surf.stack", "Surf.stack") into tStack
   TestAssert "game: cards", the number of cards of stack tStack is 67
   TestAssert "game: backgrounds", the number of bgs of stack tStack is 1
   TestAssert "game: card size", the width of stack tStack & "x" & the height of stack tStack is "640x480"
   TestAssert "game: first and last card", \
      the id of card 1 of stack tStack & comma & the id of card 67 of stack tStack is "3046,37217"
   TestAssert "game: stack script", the number of lines of the script of stack tStack is 60
   put 0 into tPictures
   repeat with tCard = 1 to 67
      add the number of card images of card tCard of stack tStack to tPictures
   end repeat
   TestAssert "game: a picture on every card", tPictures is 67
   _Close tStack
end TestHyperCardImportGame

on TestHyperCardImportBuiltinSounds
   -- HyperCard played boing, harpsichord and flute from its own resource
   -- fork: a stack whose scripts name one (TestV1 says play "Boing") gets
   -- a synthesised one, and a stack that names none gets none
   local tStack
   put _Import("TestV1") into tStack
   TestAssert "built-in sounds: boing", there is an audioClip "boing" of stack tStack
   TestAssert "built-in sounds: only the one named", the number of audioClips of stack tStack is 1
   local tSet
   put the customProperties["uHyperCard"] of audioClip "boing" of stack tStack into tSet
   TestAssert "built-in sounds: marked as synthesised", tSet["source"] is "synthesised"
   TestAssert "built-in sounds: logged", "Added HyperCard's" && quote & "boing" & quote is in the hcImportStat
   _Close tStack

   put _Import("TestCardsBackgrounds") into tStack
   TestAssert "built-in sounds: none unnamed", the number of audioClips of stack tStack is 0
   _Close tStack
end TestHyperCardImportBuiltinSounds

-- Play pSound (with pNotes, when given) and return how long after the
-- play the playStopped message is due, when there is no audio device to
-- play it on and the engine sends it when the sound would have ended;
-- empty if the sound is playing. Pending playStopped messages from
-- earlier plays are cancelled first.
private function _PlayLength pSound, pNotes
   local tLine, tStart
   repeat for each line tLine in the pendingMessages
      if item 3 of tLine is "playStopped" then cancel item 1 of tLine
   end repeat
   put the long seconds into tStart
   if pNotes is empty then
      play pSound
   else
      play pSound tempo 120 pNotes
   end if
   repeat for each line tLine in the pendingMessages
      if item 3 of tLine is "playStopped" then return item 2 of tLine - tStart
   end repeat
   return empty
end _PlayLength

on TestHyperCardImportPlayNotes
   -- `play "sound" tempo t "notes"` plays the notes with a sound from a
   -- HyperCard import (here the synthesised boing of a stack with no fork)
   local tStack, tError, tOther
   put _Import("TestV1") into tStack
   set the defaultStack to tStack
   local tPlain, tMelody
   put _PlayLength("boing") into tPlain
   put _PlayLength("boing", "c4q d e r e.") into tMelody
   if tMelody is not empty then
      -- four quarters and a dotted quarter (the last "e" is the note E,
      -- which keeps the quarter it carries) at 120 a minute: 2.75 seconds,
      -- measured against the boing alone (0.8 seconds) so that the clock
      -- the messages are timed by does not matter
      TestAssert "notes: the melody's length (boing" && tPlain & ", melody" && tMelody & ")", \
         abs((tMelody - tPlain) - (2.75 - 0.8)) < 0.1
   else
      -- (where it plays, its length is not measured here: an engine
      -- without an audio device can report it playing for good)
      TestAssert "notes: the melody plays", "boing" is in the sound
   end if
   play stop
   try
      play "boing" tempo "fast" "c"
   catch tError
   end try
   TestAssert "notes: the tempo is evaluated", tError is not empty
   _Close tStack

   -- anywhere else they are not evaluated, as before
   put "PlayNotesOther" & the milliseconds into tOther
   create invisible stack tOther
   set the defaultStack to tOther
   put empty into tError
   try
      play "flute" tempo "fast" "c"
   catch tError
   end try
   -- (only the error is asserted: what the play then reports differs, the
   -- web engine looking for a file called "flute" where desktops answer
   -- "no data in audioClip")
   TestAssert "notes: not evaluated outside imports", tError is empty
   delete stack tOther
end TestHyperCardImportPlayNotes

-- The resource fork. forks/ holds synthetic forks written by
-- lcs-input-files/hypercard/make-forks.py (ICON 128 "Synth Icon", CURS 129
-- "Synth Cursor", snd 130 "Synth Beep", and a PICT, an XCMD and an XFCN
-- the importer only logs); the tests put them beside a copy of a stack the
-- way each tool or file system leaves them.

-- A new, empty folder for one test, with a slash at the end
private function _NewFolder pName
   local tFolder
   put the temporary folder & "/hc-" & pName & "-" & the milliseconds & "/" into tFolder
   create folder tFolder
   return tFolder
end _NewFolder

private command _CopyInput pInput, pTo
   put url ("binfile:" & TestGetInputFile("hypercard/" & pInput)) into url ("binfile:" & pTo)
end _CopyInput

-- Delete a folder made by _NewFolder, with everything in it
private command _DeleteFolder pFolder
   local tFile, tOldFolder
   put the defaultFolder into tOldFolder
   set the defaultFolder to pFolder
   repeat for each line tFile in the files
      delete file (pFolder & tFile)
   end repeat
   repeat for each line tFile in the folders
      if tFile is not ".." and tFile is not "." then
         _DeleteFolder pFolder & tFile & "/"
      end if
   end repeat
   set the defaultFolder to tOldFolder
   delete folder pFolder
end _DeleteFolder

-- Import pFile and return the stack, which is named after the file
private function _ImportPath pFile
   local tError, tStack
   set the itemDelimiter to slash
   put the last item of pFile into tStack
   lock messages
   try
      import stack from file pFile
   catch tError
   end try
   unlock messages
   TestAssert tStack && "imports", tError is empty and there is a stack tStack
   return tStack
end _ImportPath

-- What the synthetic fork becomes: an icon, a cursor and a sound
private command _AssertSyntheticFork pWhat, pStack
   -- (with HyperCard addressing, the groups the importer makes are
   -- backgrounds, and their images background images)
   TestAssert pWhat & ": icon group", there is a bkgnd "HC Icons" of stack pStack
   TestAssert pWhat & ": icon", the short name of image id 128 of stack pStack is "Synth Icon"
   TestAssert pWhat & ": icon in its group", the short name of the owner of image id 128 of stack pStack is "HC Icons"
   TestAssert pWhat & ": cursor", there is an image "Synth Cursor" of bkgnd "HC cursors" of stack pStack
   -- the hot spot as the importer has always read it: v, h
   TestAssert pWhat & ": cursor hot spot", the hotSpot of image id 129 of stack pStack is "8,4"
   TestAssert pWhat & ": sound", there is an audioClip "Synth Beep" of stack pStack
   TestAssert pWhat & ": externals logged", "Not converting XCMD id   132 " & quote & "PopUpMenu" & quote is in the hcImportStat
end _AssertSyntheticFork

on TestHyperCardImportMacBinaryResourceFork
   -- a MacBinary file carries its fork, as it always has
   local tStack, tData, tFork, tHeader, tFile
   put url ("binfile:" & TestGetInputFile("hypercard/TestCardsBackgrounds.stack")) into tData
   put url ("binfile:" & TestGetInputFile("hypercard/forks/Synthetic.rsrc")) into tFork
   put numToByte(0) & numToByte(19) & "HCMacBinaryForkTest" into tHeader
   repeat 44 times
      put numToByte(0) after tHeader
   end repeat
   put "STAKWILD" after tHeader
   repeat 10 times
      put numToByte(0) after tHeader
   end repeat
   put binaryEncode("NN", the number of bytes of tData, the number of bytes of tFork) after tHeader
   repeat 128 - the number of bytes of tHeader times
      put numToByte(0) after tHeader
   end repeat
   repeat (128 - the number of bytes of tData mod 128) mod 128 times
      put numToByte(0) after tData
   end repeat
   put the temporary folder & "/hypercard-import-fork-test.bin" into tFile
   put tHeader & tData & tFork into url ("binfile:" & tFile)
   lock messages
   import stack from file tFile
   unlock messages
   TestAssert "MacBinary with a fork imports", the result is empty
   put "HCMacBinaryForkTest" into tStack
   _AssertSyntheticFork "MacBinary", tStack
   TestAssert "MacBinary: no sidecar named", "Reading the resource fork" is not in the hcImportStat
   _Close tStack
   delete file tFile
end TestHyperCardImportMacBinaryResourceFork

on TestHyperCardImportAppleDouble
   -- macOS on a FAT, exFAT or SMB volume: "._Name" beside the stack
   local tFolder, tStack
   put _NewFolder("appledouble") into tFolder
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Sidecar"
   _CopyInput "forks/Synthetic.appledouble", tFolder & "._HC Sidecar"
   put _ImportPath(tFolder & "HC Sidecar") into tStack
   _AssertSyntheticFork "AppleDouble", tStack
   TestAssert "AppleDouble: the log names it", \
      "Reading the resource fork from" && tFolder & "._HC Sidecar (AppleDouble)" is in the hcImportStat
   TestAssert "AppleDouble: the stack is as before", \
      the number of cards of stack tStack is 6 and the id of card 1 of stack tStack is 2842
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportAppleDouble

on TestHyperCardImportMacZip
   -- a zip made on a Mac: __MACOSX/<the same folders>/._Name at its root
   local tFolder, tStack
   put _NewFolder("maczip") into tFolder
   create folder tFolder & "Games"
   create folder tFolder & "Games/Cards"
   create folder tFolder & "__MACOSX"
   create folder tFolder & "__MACOSX/Games"
   create folder tFolder & "__MACOSX/Games/Cards"
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "Games/Cards/HC Zipped"
   _CopyInput "forks/Synthetic.appledouble", tFolder & "__MACOSX/Games/Cards/._HC Zipped"
   put _ImportPath(tFolder & "Games/Cards/HC Zipped") into tStack
   _AssertSyntheticFork "__MACOSX", tStack
   TestAssert "__MACOSX: the log names it", \
      "__MACOSX/Games/Cards/._HC Zipped (AppleDouble)" is in the hcImportStat
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportMacZip

on TestHyperCardImportRawForks
   -- a fork saved alone: "Name.rsrc", Basilisk II's ".rsrc/Name" and
   -- netatalk's ".AppleDouble/Name"
   local tFolder, tStack
   put _NewFolder("rsrc") into tFolder
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Raw"
   _CopyInput "forks/Synthetic.rsrc", tFolder & "HC Raw.rsrc"
   put _ImportPath(tFolder & "HC Raw") into tStack
   _AssertSyntheticFork "Name.rsrc", tStack
   TestAssert "Name.rsrc: the log names it", "HC Raw.rsrc (resource fork)" is in the hcImportStat
   _Close tStack
   _DeleteFolder tFolder

   put _NewFolder("basilisk") into tFolder
   create folder tFolder & ".rsrc"
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Basilisk"
   _CopyInput "forks/Synthetic.rsrc", tFolder & ".rsrc/HC Basilisk"
   put _ImportPath(tFolder & "HC Basilisk") into tStack
   _AssertSyntheticFork ".rsrc/Name", tStack
   _Close tStack
   _DeleteFolder tFolder

   put _NewFolder("netatalk") into tFolder
   create folder tFolder & ".AppleDouble"
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Netatalk"
   _CopyInput "forks/Synthetic.appledouble", tFolder & ".AppleDouble/HC Netatalk"
   put _ImportPath(tFolder & "HC Netatalk") into tStack
   _AssertSyntheticFork ".AppleDouble/Name", tStack
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportRawForks

on TestHyperCardImportNoUsableSidecar
   -- a "._Name" with an empty fork (macOS writes one for Finder info
   -- alone), or one that is not a fork at all, is passed over without a
   -- word, and the stack imports as it does with nothing beside it
   local tFolder, tStack, tPlainLog
   put _Import("TestCardsBackgrounds") into tStack
   put the hcImportStat into tPlainLog
   _Close tStack

   put _NewFolder("emptyfork") into tFolder
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "TestCardsBackgrounds.stack"
   _CopyInput "forks/Empty.appledouble", tFolder & "._TestCardsBackgrounds.stack"
   put "not a resource fork" into url ("binfile:" & tFolder & "TestCardsBackgrounds.stack.rsrc")
   put _ImportPath(tFolder & "TestCardsBackgrounds.stack") into tStack
   TestAssert "unusable sidecars: no icons", there is not a bkgnd "HC Icons" of stack tStack
   TestAssert "unusable sidecars: no sounds", the number of audioClips of stack tStack is 0
   TestAssert "unusable sidecars: the same log", line 2 to -1 of the hcImportStat is line 2 to -1 of tPlainLog
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportNoUsableSidecar

on TestHyperCardImportAppleSingle
   -- both forks in one AppleSingle file, named after the Mac file in it
   local tStack
   put _ImportFile("forks/TestCardsBackgrounds.applesingle", "Synthetic Stack") into tStack
   TestAssert "AppleSingle cards", the number of cards of stack tStack is 6
   _AssertSyntheticFork "AppleSingle", tStack
   _Close tStack
end TestHyperCardImportAppleSingle

on TestHyperCardImportInventory
   -- what the fork held, in the custom property set uHyperCard
   local tFolder, tStack, tSet
   put _NewFolder("inventory") into tFolder
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Inventory"
   _CopyInput "forks/Synthetic.appledouble", tFolder & "._HC Inventory"
   put _ImportPath(tFolder & "HC Inventory") into tStack
   put the customProperties["uHyperCard"] of stack tStack into tSet
   TestAssert "inventory: every resource", the number of lines of tSet["resources"] is 6
   TestAssert "inventory: type, id, size, name", line 1 of tSet["resources"] is "ICON" & tab & "128" & tab & "128" & tab & "Synth Icon"
   TestAssert "inventory: the sound", line 3 of tSet["resources"] begins with "snd " & tab & "130" & tab
   TestAssert "inventory: externals", tSet["externals"] is "XCMD" & tab & "PopUpMenu" & return & "XFCN" & tab & "FileName"
   TestAssert "inventory: source", tSet["source"] is tFolder & "._HC Inventory (AppleDouble)"
   _Close tStack
   _DeleteFolder tFolder

   -- a stack with no fork has no such set, as before
   put _Import("TestCardsBackgrounds") into tStack
   TestAssert "no fork: no uHyperCard", "uHyperCard" is not among the lines of the customPropertySets of stack tStack
   _Close tStack
end TestHyperCardImportInventory

on TestHyperCardImportIdClashes
   -- icon ids are kept, clashes are logged, and objects made later get
   -- ids above every icon
   local tFolder, tStack, tLog
   put _NewFolder("clash") into tFolder
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Clash"
   _CopyInput "forks/Clash.rsrc", tFolder & "HC Clash.rsrc"
   put _ImportPath(tFolder & "HC Clash") into tStack
   put the hcImportStat into tLog
   TestAssert "clash: icon and cursor", "Warning: ICON" && quote & "Twin Icon" & quote && "and CURS" && quote & "Twin Cursor" & quote && "have the same id, 129" is in tLog
   TestAssert "clash: icon and card", "Warning: ICON" && quote & "Card Twin" & quote && "and card" && quote is in tLog
   TestAssert "clash: the card keeps its id", the id of card 1 of stack tStack is 2842
   TestAssert "clash: the icon keeps its id", the short name of image id 30000 of stack tStack is "High Icon"
   lock messages
   create button "Made later" in card 1 of stack tStack
   unlock messages
   TestAssert "clash: a new object's id is above the icons", the id of button "Made later" of card 1 of stack tStack > 30000
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportIdClashes

on TestHyperCardImportSoundHeaders
   -- extended headers (16-bit, stereo) and IMA 4:1 import; MACE is
   -- named in the import log
   local tFolder, tStack, tLog
   put _NewFolder("sounds") into tFolder
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Sounds"
   _CopyInput "forks/Sounds.rsrc", tFolder & "HC Sounds.rsrc"
   put _ImportPath(tFolder & "HC Sounds") into tStack
   put the hcImportStat into tLog
   TestAssert "sound: 16-bit stereo", there is an audioClip "Stereo 16" of stack tStack
   TestAssert "sound: 8-bit extended", there is an audioClip "Mono 8 Extended" of stack tStack
   TestAssert "sound: IMA 4:1", there is an audioClip "IMA" of stack tStack
   TestAssert "MACE is not imported", there is not an audioClip "MACE" of stack tStack
   TestAssert "MACE is logged", "Not converting snd  id   203" && quote & "MACE" & quote & ": MACE 3:1 compression" is in tLog
   TestAssert "sounds in resource order", the short name of audioClip 1 of stack tStack is "Stereo 16" \
      and the short name of audioClip 3 of stack tStack is "IMA"
   -- the bytes of samples each header gives: 500 frames of two 16-bit
   -- channels, 800 of one byte, and 2 packets a channel of IMA's 64
   -- 16-bit samples
   TestAssert "samples: 16-bit stereo", the size of audioClip "Stereo 16" of stack tStack is 2000
   TestAssert "samples: 8-bit extended", the size of audioClip "Mono 8 Extended" of stack tStack is 800
   TestAssert "samples: IMA 4:1", the size of audioClip "IMA" of stack tStack is 512
   -- a nullCmd before the bufferCmd, as SoundEdit wrote: the header is the
   -- bufferCmd's. rc.6.3 read the nullCmd's offset, 0: it imported the
   -- resource itself as the samples (noise, 22 bytes too long), and with a
   -- synthesizer listed first (format 1) refused an unknown header
   TestAssert "after a nullCmd: imported", there is an audioClip "After NullCmd" of stack tStack
   TestAssert "after a nullCmd: the header's samples", there is an audioClip "After NullCmd" of stack tStack \
      and the size of audioClip "After NullCmd" of stack tStack is 600
   TestAssert "format 1, after a nullCmd: imported", there is an audioClip "After NullCmd 1" of stack tStack
   TestAssert "format 1, after a nullCmd: the header's samples", there is an audioClip "After NullCmd 1" of stack tStack \
      and the size of audioClip "After NullCmd 1" of stack tStack is 700
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportSoundHeaders

-- The red, green and blue of pixel (pX, pY) of an image, as "r,g,b"
private function _Pixel pImage, pX, pY
   local tData, tAt
   put the imageData of pImage into tData
   put (pY * the width of pImage + pX) * 4 + 2 into tAt
   return byteToNum(byte tAt of tData) & comma & byteToNum(byte tAt + 1 of tData) & comma & byteToNum(byte tAt + 2 of tData)
end _Pixel

on TestHyperCardImportPictures
   -- PICT resources become images in a new group, "HC Pictures"
   local tFolder, tStack, tImage, tUnnamed
   put _NewFolder("pictures") into tFolder
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Pictures"
   _CopyInput "forks/Pictures.rsrc", tFolder & "HC Pictures.rsrc"
   put _ImportPath(tFolder & "HC Pictures") into tStack
   TestAssert "pictures: the group", there is a bkgnd "HC Pictures" of stack tStack
   TestAssert "pictures: two images", the number of images of bkgnd "HC Pictures" of stack tStack is 2
   put the long id of image "Colour" of bkgnd "HC Pictures" of stack tStack into tImage
   TestAssert "version 2: size", the width of tImage & "x" & the height of tImage is "64x48"
   TestAssert "version 2: painted rectangle", _Pixel(tImage, 8, 8) is "255,0,0"
   TestAssert "version 2: painted oval", _Pixel(tImage, 24, 8) is "0,0,255"
   TestAssert "version 2: oval's corner left alone", _Pixel(tImage, 17, 1) is "255,255,255"
   TestAssert "version 2: framed rectangle", _Pixel(tImage, 32, 0) is "0,0,0" and _Pixel(tImage, 40, 8) is "255,255,255"
   TestAssert "version 2: 8-bit pixel map", _Pixel(tImage, 4, 24) is "0,255,0" and _Pixel(tImage, 12, 24) is "255,255,0"
   TestAssert "version 2: 32-bit pixel map", _Pixel(tImage, 24, 24) is "18,52,86"
   TestAssert "version 2: bitmap", _Pixel(tImage, 8, 36) is "0,0,0" and _Pixel(tImage, 8, 44) is "255,255,255"
   TestAssert "version 2: line", _Pixel(tImage, 30, 40) is "0,0,0" and _Pixel(tImage, 30, 41) is "255,255,255"
   TestAssert "version 1: named after its id", there is an image "PICT 301" of bkgnd "HC Pictures" of stack tStack
   put the long id of image "PICT 301" of bkgnd "HC Pictures" of stack tStack into tUnnamed
   TestAssert "version 1: oval", _Pixel(tUnnamed, 16, 8) is "0,0,0" and _Pixel(tUnnamed, 0, 0) is "255,255,255"
   TestAssert "version 1: bitmap", _Pixel(tUnnamed, 28, 28) is "0,0,0" and _Pixel(tUnnamed, 20, 28) is "255,255,255"
   TestAssert "pictures: not logged as unconverted", "Not converting PICT" is not in the hcImportStat
   TestAssert "pictures: ids above the stack's", the id of tImage > 5225
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportPictures

on TestHyperCardImportPalettes
   -- a PLTE resource becomes a substack named after it: its PICT, with a
   -- button on each of its rectangles that sends the PLTE's message
   local tFolder, tStack, tPalette, tOldDefault
   put _NewFolder("palettes") into tFolder
   _CopyInput "TestCardsBackgrounds.stack", tFolder & "HC Palettes"
   _CopyInput "forks/Pictures.rsrc", tFolder & "HC Palettes.rsrc"
   put _ImportPath(tFolder & "HC Palettes") into tStack
   put "Test Palette" into tPalette
   TestAssert "palette: a substack", tPalette is among the lines of the substacks of stack tStack
   TestAssert "palette: the picture's size", the width of stack tPalette & "x" & the height of stack tPalette is "64x48"
   TestAssert "palette: its picture", the number of images of card 1 of stack tPalette is 1
   TestAssert "palette: two buttons", the number of buttons of card 1 of stack tPalette is 2
   TestAssert "palette: button rectangle", the rect of button 2 of card 1 of stack tPalette is "0,16,16,32"
   TestAssert "palette: message", the uHCMessage of button 1 of card 1 of stack tPalette is "hcPaletteTest 3," && quote & "a,b" & quote

   set the script of stack tStack to "on hcPaletteTest p1, p2" & return & \
      "set the uPaletteParams of me to p1 & slash & p2" & return & "end hcPaletteTest"
   put the defaultStack into tOldDefault
   set the defaultStack to tStack
   send "mouseUp" to button 1 of card 1 of stack tPalette
   TestAssert "palette: a message to the card", the uPaletteParams of stack tStack is "3/a,b"
   TestAssert "palette: hilited button", the uHCHilitedButton of stack tPalette is 1
   send "mouseUp" to button 2 of card 1 of stack tPalette
   TestAssert "palette: a command", the uPaletteSet of stack tStack is 5
   TestAssert "palette: hilited button follows", the uHCHilitedButton of stack tPalette is 2
   set the defaultStack to tOldDefault

   set the enabledButton_2 of stack tPalette to false
   TestAssert "palette: enabledButton_n", not the enabled of button 2 of card 1 of stack tPalette
   TestAssert "palette: enabledButton_n reads", the enabledButton_2 of stack tPalette is false
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportPalettes

private function _Alpha pImage, pX, pY
   return byteToNum(byte (pY * the width of pImage + pX + 1) of the alphaData of pImage)
end _Alpha

on TestHyperCardImportAddColor
   -- HCbg and HCcd resources (AddColor) become one image per background or
   -- card, "HC AddColor", on top of its objects, with the blendMultiply ink,
   -- disabled so that clicks reach the objects below
   local tFolder, tStack, tBgImage, tCardImage, tLog
   put _NewFolder("addcolor") into tFolder
   _CopyInput "TestButtonProperties.stack", tFolder & "HC Colours"
   _CopyInput "forks/AddColor.rsrc", tFolder & "HC Colours.rsrc"
   put _ImportPath(tFolder & "HC Colours") into tStack
   put the hcImportStat into tLog

   TestAssert "addcolor: the background's colours", there is an image "HC AddColor" of bkgnd id 2670 of stack tStack
   put the long id of image "HC AddColor" of bkgnd id 2670 of stack tStack into tBgImage
   TestAssert "addcolor: the card's size", the width of tBgImage & "x" & the height of tBgImage is "512x342"
   TestAssert "addcolor: blendMultiply", the ink of tBgImage is "blendMultiply"
   TestAssert "addcolor: clicks go through", not the enabled of tBgImage
   TestAssert "addcolor: on top of the buttons, numbered after them", the layer of tBgImage > the layer of button 13 of bkgnd id 2670 of stack tStack \
         and the short name of button 13 of bkgnd id 2670 of stack tStack is "New Button"
   TestAssert "addcolor: a button's colour", _Pixel(tBgImage, 88, 60) is "255,0,0"
   TestAssert "addcolor: bevel, top left", _Pixel(tBgImage, 41, 49) is "255,127,127"
   TestAssert "addcolor: bevel, bottom right", _Pixel(tBgImage, 135, 70) is "127,0,0"
   TestAssert "addcolor: a hidden entry is not drawn", _Alpha(tBgImage, 91, 108) is 0
   TestAssert "addcolor: a rectangle", _Pixel(tBgImage, 450, 315) is "0,0,255"
   TestAssert "addcolor: transparent elsewhere", _Alpha(tBgImage, 250, 20) is 0

   put the long id of image "HC AddColor" of card id 2883 of stack tStack into tCardImage
   TestAssert "addcolor: the card's colours", there is tCardImage
   TestAssert "addcolor: a bevelled rectangle", _Pixel(tCardImage, 30, 25) is "255,255,0" \
         and _Pixel(tCardImage, 10, 10) is "255,255,127"
   TestAssert "addcolor: a picture", _Pixel(tCardImage, 408, 108) is "255,0,0"
   TestAssert "addcolor: a transparent picture's white", _Alpha(tCardImage, 408, 144) is 0
   TestAssert "addcolor: a picture file is logged", "AddColor picture file" && quote & "Sky.pict" & quote && "on card id 2883 not drawn" is in tLog
   TestAssert "addcolor: ids above the others", the id of tCardImage > the id of image "Colour" of bkgnd "HC Pictures" of stack tStack \
         and the id of tBgImage > the id of image "Colour" of bkgnd "HC Pictures" of stack tStack
   TestAssert "addcolor: other cards have none", there is not an image "HC AddColor" of card id 4067 of stack tStack
   TestAssert "addcolor: not logged as unconverted", "Not converting HCcd" is not in tLog and "Not converting HCbg" is not in tLog
   _Close tStack
   _DeleteFolder tFolder
end TestHyperCardImportAddColor
