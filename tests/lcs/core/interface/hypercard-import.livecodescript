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
