script "PuzzleAlmanacBuilder"
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

-- Builds stacks/Puzzle Almanac.oxtstack, a daily book of two puzzles for
-- a phone (Number Place and Hidden Word), made with the Mobile Web
-- library (extensions/script-libraries/mobileweb). The stack is never
-- edited by hand: change this script, or the game's script
-- (puzzle-almanac-stack.livecodescript beside it), and build it again,
-- with any OXT-Beyond engine (the IDE's, or the development engine of a
-- build):
--
--    <engine> -ui tools/web-player/puzzle-almanac.livecodescript
--
-- OXT_PUZZLE_ALMANAC names another file to write. It prints
-- "BUILT <file>" or "FAILED <why>".
--
-- What goes in:
--   card "Art"      every picture of puzzle-almanac/art (art.txt), each the
--                   size the game draws it at, from a file with two or
--                   three times as many pixels: a tile or a sticker is a
--                   button whose icon is one of them. The card is never
--                   shown.
--   card "Almanac"  the game: every screen (Home, Numbers, Words, Stickers)
--                   a group, and the panels over them (Done, Practice,
--                   Howto, Settings), each a group behind a veil (Shade)
--   the sounds      puzzle-almanac/sounds, as the custom property set
--                   cSounds
--   the font        Atkinson Hyperlegible, as the custom properties
--                   cFontRegular and cFontBold, which the game hands to
--                   "start using font file" as it opens
--   the puzzles     puzzle-almanac/data: numbers.txt as cNumbers,
--                   words.txt as cWords, answers.txt (without its notes)
--                   as cAnswers
--
-- Every place and size of a control is set by the game's paLayout as it
-- opens and whenever the window changes: here they are only made, with
-- their look. The stack's script is set last, so that nothing it does
-- runs while the stack is built.

constant kWidth = 390
constant kHeight = 760

-- The look (the game's script has the same colours)
constant kFont = "Atkinson Hyperlegible"
constant kPaper = "#F7F0E1"
constant kCard = "#FFFBF2"
constant kEdge = "#E2D3B5"
constant kInk = "#3B2F2A"
constant kMuted = "#7D6E60"
constant kLeaf = "#4E9A5B"
constant kLeafDown = "#3B7E47"
constant kKey = "#EADFC8"
constant kKeyDown = "#D8C9AC"
constant kWhite = "#FFFFFF"

-- How many of each: the cells of the biggest grid, the tiles of the
-- longest word in six tries, the stickers of the book's page
constant kCells = 81
constant kTiles = 36
constant kSlots = 15
constant kSparks = 8

on startup
   local tFile, tError
   put $OXT_PUZZLE_ALMANAC into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/Puzzle Almanac.oxtstack" into the last item of tFile
      set the itemDelimiter to comma
   end if
   try
      buildStack tFile
   catch tError
      write "FAILED" && tError & return to stdout
      quit 1
   end try
   write "BUILT" && tFile & return to stdout
   quit 0
end startup

private command buildStack pFile
   local tName, tScript
   put "Puzzle Almanac" into tName
   if there is a stack tName then
      delete stack tName
   end if
   create invisible stack tName
   set the defaultStack to tName
   set the rect of stack tName to 100, 60, 100 + kWidth, 60 + kHeight
   set the minWidth of stack tName to 320
   set the minHeight of stack tName to 480
   set the resizable of stack tName to true
   set the backgroundColor of stack tName to kPaper
   set the textFont of stack tName to empty
   set the textSize of stack tName to 14
   -- the page calls paPageHidden when it is hidden (another app, a
   -- locked phone), so that what is on the board is saved at once;
   -- paState says how the game is, for the checks of its page on the web
   -- site (tools/pages/check_puzzle_almanac_page.py) and on phones
   -- (tools/ci/puzzle_almanac_check.py)
   set the cJavascriptHandlers of stack tName to "paPageHidden" & return & "paState"

   set the name of card 1 of stack tName to "Almanac"
   create card "Art"
   importArt
   importSounds tName
   importFonts tName
   importData tName

   go card "Almanac" of stack tName
   set the backgroundColor of card "Almanac" to kPaper
   buildTop
   buildHome
   buildNumbers
   buildWords
   buildStickers
   create graphic "Shade"
   setBox the long id of graphic "Shade", "#2A211C"
   set the blendLevel of graphic "Shade" to 45
   set the visible of graphic "Shade" to false
   buildDone
   buildPractice
   buildHowto
   buildSettings

   -- last: the script, which lays everything out as the stack opens
   put stackScript() into tScript
   set the script of stack tName to tScript
   if the result is not empty then
      throw "the stack's script does not compile:" && the result
   end if
   set the visible of stack tName to true
   save stack tName as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
end buildStack

-- A file beside this script, in puzzle-almanac/
private function assetPath pName
   local tFile
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "puzzle-almanac/" & pName into the last item of tFile
   return tFile
end assetPath

private function fileText pFile
   local tText
   open file pFile for "UTF-8" text read
   if the result is not empty then
      throw "cannot read" && pFile & ":" && the result
   end if
   read from file pFile until end
   put it into tText
   close file pFile
   return tText
end fileText

private function fileData pFile
   local tData
   if there is not a file pFile then
      throw "no file" && pFile
   end if
   put url ("binfile:" & pFile) into tData
   if tData is empty then
      throw "cannot read" && pFile
   end if
   return tData
end fileData

-- Every picture of art.txt, the size the game draws it at
private command importArt
   local tLine, tName, tFile, tWidth, tHeight, tX, tY, tRowH, tCount
   put 0 into tX
   put 0 into tY
   put 0 into tRowH
   put 0 into tCount
   repeat for each line tLine in fileText(assetPath("art/art.txt"))
      if tLine is empty or char 1 of tLine is "#" then
         next repeat
      end if
      set the itemDelimiter to tab
      put item 1 of tLine into tName
      put item 2 of tLine into tFile
      put item 3 of tLine into tWidth
      put item 4 of tLine into tHeight
      set the itemDelimiter to comma
      import paint from file assetPath("art/" & tFile)
      if the result is not empty then
         throw "cannot import" && tFile & ":" && the result
      end if
      set the name of last image to tName
      -- (laid out in rows, so that the card can be looked at)
      if tX + tWidth > 600 then
         put 0 into tX
         add tRowH + 4 to tY
         put 0 into tRowH
      end if
      set the lockLoc of image tName to true
      set the rect of image tName to tX, tY, tX + tWidth, tY + tHeight
      set the resizeQuality of image tName to "good"
      add tWidth + 4 to tX
      put max(tRowH, tHeight) into tRowH
      add 1 to tCount
   end repeat
   if tCount < 37 then
      throw "the pictures are not all there:" && tCount
   end if
end importArt

private command importSounds pStack
   local tFolder, tFile, tFiles
   put assetPath("sounds") into tFolder
   set the defaultFolder to tFolder
   put the files into tFiles
   repeat for each line tFile in tFiles
      if tFile ends with ".wav" then
         set the cSounds[char 1 to -5 of tFile] of stack pStack to fileData(tFolder & "/" & tFile)
      end if
   end repeat
   if the number of lines of the customKeys["cSounds"] of stack pStack < 20 then
      throw "the sounds are not all there:" && the customKeys["cSounds"] of stack pStack
   end if
end importSounds

private command importFonts pStack
   set the cFontRegular of stack pStack to fileData(assetPath("fonts/AtkinsonHyperlegible-Regular.ttf"))
   set the cFontBold of stack pStack to fileData(assetPath("fonts/AtkinsonHyperlegible-Bold.ttf"))
end importFonts

-- The puzzles and the words, as text (the game splits them as it opens)
private command importData pStack
   local tText, tLine, tAnswers
   put fileText(assetPath("data/numbers.txt")) into tText
   if the number of lines of tText < 400 then
      throw "the puzzles are not all there"
   end if
   set the cNumbers of stack pStack to tText
   put fileText(assetPath("data/words.txt")) into tText
   if the number of lines of tText < 20000 then
      throw "the words are not all there"
   end if
   set the cWords of stack pStack to tText
   repeat for each line tLine in fileText(assetPath("data/answers.txt"))
      if tLine is empty or char 1 of tLine is "#" then
         next repeat
      end if
      put tLine & return after tAnswers
   end repeat
   delete the last char of tAnswers
   if the number of lines of tAnswers < 300 then
      throw "the hidden words are not all there"
   end if
   set the cAnswers of stack pStack to tAnswers
end importData

-- The bar over a screen: Back and the screen's name
private command buildTop
   create group "Top"
   makeButton "Back", "Back", "Top", false
   create field "Top Title" in group "Top"
   setLabel the long id of field "Top Title", empty, 20, kInk, "bold", "center"
   set the visible of group "Top" to false
end buildTop

private command buildHome
   local tKind
   create group "Home"
   makeSprite "Home Mascot", "animal-owl", "Home"
   create field "Home Title" in group "Home"
   setLabel the long id of field "Home Title", "Puzzle Almanac", 32, kInk, "bold", "center"
   create field "Home Date" in group "Home"
   setLabel the long id of field "Home Date", empty, 17, kMuted, "plain", "center"
   repeat for each item tKind in "Numbers,Words"
      create graphic (tKind && "Card Shape") in group "Home"
      setRound the long id of graphic (tKind && "Card Shape"), kCard, kEdge
      create field (tKind && "Card Title") in group "Home"
      setLabel the long id of field (tKind && "Card Title"), empty, 22, kInk, "bold", "left"
      create field (tKind && "Card Sub") in group "Home"
      setLabel the long id of field (tKind && "Card Sub"), empty, 15, kMuted, "plain", "left"
      create field (tKind && "Card State") in group "Home"
      setLabel the long id of field (tKind && "Card State"), empty, 16, kLeaf, "bold", "left"
      makeSprite tKind && "Card Badge", "star", "Home"
   end repeat
   -- a little grid for Number Place, three little tiles for Hidden Word
   create graphic "Numbers Card Grid" in group "Home"
   set the style of graphic "Numbers Card Grid" to "polygon"
   set the opaque of graphic "Numbers Card Grid" to false
   set the filled of graphic "Numbers Card Grid" to false
   set the lineSize of graphic "Numbers Card Grid" to 2
   set the foregroundColor of graphic "Numbers Card Grid" to kLeaf
   set the antialiased of graphic "Numbers Card Grid" to true
   setPictureOnly the long id of graphic "Numbers Card Grid"
   create field "Numbers Card Digits" in group "Home"
   setLabel the long id of field "Numbers Card Digits", empty, 15, kInk, "bold", "left"
   set the dontWrap of field "Numbers Card Digits" to false
   set the fixedLineHeight of field "Numbers Card Digits" to true
   makeSprite "Words Card Tile 1", "tile-gold", "Home"
   makeSprite "Words Card Tile 2", "tile-blue", "Home"
   makeSprite "Words Card Tile 3", "tile-stone", "Home"
   -- the cards take their taps over everything on them
   makeFace "Numbers Card", empty, "Home", false
   makeFace "Words Card", empty, "Home", false
   create field "Home Streak" in group "Home"
   setText the long id of field "Home Streak", empty, 15, kMuted, "center"
   makeButton "Practice Open", "Practice", "Home", false
   makeButton "Stickers Open", "Stickers", "Home", false
   makeButton "Howto Open", "How to play", "Home", false
   makeButton "Settings Open", "Settings", "Home", false
   set the visible of group "Home" to false
end buildHome

-- Number Place: the cells (a field each, and a field of small numbers,
-- the notes, over it), the lines of the grid, the keys and the tools
private command buildNumbers
   local i
   create group "Numbers"
   create field "N Info" in group "Numbers"
   setLabel the long id of field "N Info", empty, 15, kMuted, "plain", "center"
   create graphic "N Board" in group "Numbers"
   setRound the long id of graphic "N Board", kCard, kInk
   set the lineSize of graphic "N Board" to 3
   repeat with i = 1 to kCells
      create field ("N Cell" && i) in group "Numbers"
      setLabel the long id of field ("N Cell" && i), empty, 24, kInk, "bold", "center"
      set the opaque of field ("N Cell" && i) to true
      set the backgroundColor of field ("N Cell" && i) to kCard
      set the fixedLineHeight of field ("N Cell" && i) to true
      set the script of field ("N Cell" && i) to tapScript()
   end repeat
   repeat with i = 1 to kCells
      create field ("N Note" && i) in group "Numbers"
      setLabel the long id of field ("N Note" && i), empty, 9, kMuted, "plain", "center"
      set the dontWrap of field ("N Note" && i) to false
      set the fixedLineHeight of field ("N Note" && i) to true
      -- (a tap on the notes is a tap on the cell under them)
      set the script of field ("N Note" && i) to tapScript()
   end repeat
   create graphic "N Thin" in group "Numbers"
   setLines the long id of graphic "N Thin", kEdge, 1
   create graphic "N Thick" in group "Numbers"
   setLines the long id of graphic "N Thick", kInk, 3
   repeat with i = 1 to 9
      makeButton "N Key" && i, i, "Numbers", false
   end repeat
   makeButton "N Notes", "Notes", "Numbers", false
   makeButton "N Erase", "Erase", "Numbers", false
   makeButton "N Undo", "Undo", "Numbers", false
   makeButton "N Hint", "Hint", "Numbers", false
   create field "N Message" in group "Numbers"
   setText the long id of field "N Message", empty, 15, kMuted, "center"
   set the visible of group "Numbers" to false
end buildNumbers

-- Hidden Word: six rows of tiles (each an empty slot, a tile, its letter
-- and its mark) and a keyboard
private command buildWords
   local i, tLetter
   create group "Words"
   create field "W Info" in group "Words"
   setLabel the long id of field "W Info", empty, 15, kMuted, "plain", "center"
   repeat with i = 1 to kTiles
      create graphic ("W Slot" && i) in group "Words"
      setRound the long id of graphic ("W Slot" && i), kCard, kEdge
      set the lineSize of graphic ("W Slot" && i) to 2
      makeSprite "W Tile" && i, "tile-marble", "Words"
      create field ("W Letter" && i) in group "Words"
      setLabel the long id of field ("W Letter" && i), empty, 30, kInk, "bold", "center"
      set the fixedLineHeight of field ("W Letter" && i) to true
      create graphic ("W Mark" && i) in group "Words"
      set the style of graphic ("W Mark" && i) to "polygon"
      set the opaque of graphic ("W Mark" && i) to true
      set the filled of graphic ("W Mark" && i) to true
      set the antialiased of graphic ("W Mark" && i) to true
      set the lineSize of graphic ("W Mark" && i) to 0
      set the visible of graphic ("W Mark" && i) to false
      setPictureOnly the long id of graphic ("W Mark" && i)
   end repeat
   repeat for each char tLetter in "QWERTYUIOPASDFGHJKLZXCVBNM"
      makeButton "W Key" && tLetter, tLetter, "Words", false
   end repeat
   makeButton "W Key Enter", "Enter", "Words", true
   makeButton "W Key Back", "Delete", "Words", false
   create field "W Message" in group "Words"
   setText the long id of field "W Message", empty, 15, kMuted, "center"
   set the visible of group "Words" to false
end buildWords

-- The sticker book: a page of rings, each with its sticker once it is
-- earned, and the page's turns
private command buildStickers
   local i
   create group "Stickers"
   create field "S Count" in group "Stickers"
   setText the long id of field "S Count", empty, 16, kMuted, "center"
   create graphic "S Page" in group "Stickers"
   setRound the long id of graphic "S Page", kCard, kEdge
   repeat with i = 1 to kSlots
      create graphic ("S Ring" && i) in group "Stickers"
      set the style of graphic ("S Ring" && i) to "oval"
      set the opaque of graphic ("S Ring" && i) to true
      set the filled of graphic ("S Ring" && i) to true
      set the backgroundColor of graphic ("S Ring" && i) to "#F1E7D3"
      set the lineSize of graphic ("S Ring" && i) to 2
      set the foregroundColor of graphic ("S Ring" && i) to kEdge
      set the antialiased of graphic ("S Ring" && i) to true
      makeSprite "S Slot" && i, "animal-owl", "Stickers"
      create field ("S Name" && i) in group "Stickers"
      setLabel the long id of field ("S Name" && i), empty, 13, kMuted, "plain", "center"
   end repeat
   makeButton "S Prev", "Page 1", "Stickers", false
   makeButton "S Next", "Page 2", "Stickers", false
   set the visible of group "Stickers" to false
end buildStickers

-- A solved puzzle: its sticker, and for a word, what it means
private command buildDone
   local i
   create group "Done"
   makePanel "Done"
   repeat with i = 1 to kSparks
      makeSprite "Done Spark" && i, "sparkle-gold", "Done"
   end repeat
   create field "Done Title" in group "Done"
   setLabel the long id of field "Done Title", empty, 28, kLeaf, "bold", "center"
   makeSprite "Done Sticker", "animal-owl", "Done"
   create field "Done Word" in group "Done"
   setLabel the long id of field "Done Word", empty, 30, kInk, "bold", "center"
   create field "Done Meaning" in group "Done"
   setText the long id of field "Done Meaning", empty, 17, kInk, "center"
   create field "Done Note" in group "Done"
   setText the long id of field "Done Note", empty, 15, kMuted, "center"
   makeButton "Done Home", "Back to the almanac", "Done", true
   makeButton "Done Again", "Practise another", "Done", false
   set the visible of group "Done" to false
end buildDone

private command buildPractice
   create group "Practice"
   makePanel "Practice"
   create field "Practice Title" in group "Practice"
   setLabel the long id of field "Practice Title", "Practice", 24, kInk, "bold", "center"
   create field "Practice Text" in group "Practice"
   setText the long id of field "Practice Text", "As many as you like, just for fun. Pick one:", 15, kMuted, "center"
   create field "Practice Numbers" in group "Practice"
   setLabel the long id of field "Practice Numbers", "Number Place", 17, kInk, "bold", "center"
   makeButton "P N4", "4 by 4", "Practice", false
   makeButton "P N6", "6 by 6", "Practice", false
   makeButton "P N9", "9 by 9", "Practice", false
   create field "Practice Words" in group "Practice"
   setLabel the long id of field "Practice Words", "Hidden Word", 17, kInk, "bold", "center"
   makeButton "P W4", "4 letters", "Practice", false
   makeButton "P W5", "5 letters", "Practice", false
   makeButton "P W6", "6 letters", "Practice", false
   makeButton "Practice Close", "Close", "Practice", true
   set the visible of group "Practice" to false
end buildPractice

private command buildHowto
   local i
   create group "Howto"
   makePanel "Howto"
   create field "Howto Title" in group "Howto"
   setLabel the long id of field "Howto Title", "How to play", 24, kInk, "bold", "center"
   create field "Howto Numbers Head" in group "Howto"
   setLabel the long id of field "Howto Numbers Head", "Number Place", 18, kLeaf, "bold", "left"
   create field "Howto Numbers" in group "Howto"
   setText the long id of field "Howto Numbers", "Fill the grid so that every row, every column and every box with a thick edge has each number once. Tap a square, then a number. Notes lets you pencil in the numbers a square might be.", 15, kInk, "left"
   create field "Howto Words Head" in group "Howto"
   setLabel the long id of field "Howto Words Head", "Hidden Word", 18, kLeaf, "bold", "left"
   create field "Howto Words" in group "Howto"
   setText the long id of field "Howto Words", "Find the hidden word in six tries. Type a word and press Enter; the tiles show how close it was:", 15, kInk, "left"
   repeat with i = 1 to 3
      makeSprite "Howto Tile" && i, item i of "tile-gold,tile-blue,tile-stone", "Howto"
      create field ("Howto Letter" && i) in group "Howto"
      setLabel the long id of field ("Howto Letter" && i), char i of "BAT", 24, kInk, "bold", "center"
      set the fixedLineHeight of field ("Howto Letter" && i) to true
      create graphic ("Howto Mark" && i) in group "Howto"
      set the style of graphic ("Howto Mark" && i) to "polygon"
      set the opaque of graphic ("Howto Mark" && i) to true
      set the filled of graphic ("Howto Mark" && i) to true
      set the antialiased of graphic ("Howto Mark" && i) to true
      set the lineSize of graphic ("Howto Mark" && i) to 0
      setPictureOnly the long id of graphic ("Howto Mark" && i)
      create field ("Howto Key" && i) in group "Howto"
      setText the long id of field ("Howto Key" && i), line i of ("in the right place" & return & "in the word, in another place" & return & "not in the word"), 14, kInk, "left"
   end repeat
   create field "Howto Daily" in group "Howto"
   setText the long id of field "Howto Daily", "There is a new puzzle of each every day, the same for everyone. Solve one to earn a sticker for your book.", 15, kMuted, "left"
   makeButton "Howto Done", "Got it", "Howto", true
   set the visible of group "Howto" to false
end buildHowto

private command buildSettings
   create group "Settings"
   makePanel "Settings"
   create field "Settings Title" in group "Settings"
   setLabel the long id of field "Settings Title", "Settings", 24, kInk, "bold", "center"
   makeButton "Set Sound", "Sound: on", "Settings", false
   makeButton "Set Voice", "Say the numbers: off", "Settings", false
   makeButton "Set Mistakes", "Show mistakes: on", "Settings", false
   makeButton "Set Size", "Number Place: 6 by 6", "Settings", false
   makeButton "Set Length", "Hidden Word: 5 letters", "Settings", false
   makeButton "Set Full", "Full screen", "Settings", false
   create field "Settings Note" in group "Settings"
   setText the long id of field "Settings Note", empty, 13, kMuted, "center"
   create field "Credits" in group "Settings"
   setText the long id of field "Credits", "Pictures and sounds by Kenney (kenney.nl), CC0. Font: Atkinson Hyperlegible, by the Braille Institute (SIL Open Font License). Words: ENABLE, public domain. Made with OXT-Beyond.", 12, kMuted, "center"
   makeButton "Settings Done", "Done", "Settings", true
   set the visible of group "Settings" to false
end buildSettings

-- A panel: a card with rounded corners (the game sets its size)
private command makePanel pGroup
   create graphic (pGroup && "Panel") in group pGroup
   setRound the long id of graphic (pGroup && "Panel"), kCard, kEdge
   set the lineSize of graphic (pGroup && "Panel") to 2
end makePanel

-- A button: its shape, a rounded rectangle (green for the main one), and
-- over it a button with no look of its own, its label, which takes the
-- taps. The shape's cUp and cDown are its colours, up and pressed.
private command makeButton pName, pLabel, pGroup, pMain
   local tShape
   put pName && "Shape" into tShape
   create graphic tShape in group pGroup
   if pMain then
      setRound the long id of graphic tShape, kLeaf, kLeafDown
      set the cUp of graphic tShape to kLeaf
      set the cDown of graphic tShape to kLeafDown
      set the lineSize of graphic tShape to 0
   else
      setRound the long id of graphic tShape, kKey, kKeyDown
      set the cUp of graphic tShape to kKey
      set the cDown of graphic tShape to kKeyDown
      set the lineSize of graphic tShape to 0
   end if
   makeFace pName, pLabel, pGroup, pMain
end makeButton

private command makeFace pName, pLabel, pGroup, pMain
   create button pName in group pGroup
   set the style of button pName to "transparent"
   set the showBorder of button pName to false
   set the threeD of button pName to false
   set the opaque of button pName to false
   set the autoHilite of button pName to false
   set the showFocusBorder of button pName to false
   set the traversalOn of button pName to false
   set the showName of button pName to pLabel is not empty
   set the label of button pName to pLabel
   set the textFont of button pName to kFont
   set the textStyle of button pName to "bold"
   set the textSize of button pName to 17
   if pMain then
      set the textColor of button pName to kWhite
   else
      set the textColor of button pName to kInk
   end if
   set the script of button pName to buttonScript()
end makeFace

-- Every button: pressed, it looks pressed; let go on it, it does what it
-- is for (paPress, in the stack's script). A second tap soon after the
-- first comes as mouseDoubleDown and mouseDoubleUp.
private function buttonScript
   return "on mouseDown" & return & "   paButtonLook the short name of me, true" & return & "end mouseDown" & return & \
         "on mouseDoubleDown" & return & "   paButtonLook the short name of me, true" & return & "end mouseDoubleDown" & return & \
         "on mouseUp" & return & "   paButtonLook the short name of me, false" & return & \
         "   paPress the short name of me" & return & "end mouseUp" & return & \
         "on mouseDoubleUp" & return & "   paButtonLook the short name of me, false" & return & \
         "   paPress the short name of me" & return & "end mouseDoubleUp" & return & \
         "on mouseRelease" & return & "   paButtonLook the short name of me, false" & return & "end mouseRelease"
end buttonScript

-- A cell of the grid (or its notes): a tap selects it at once, as the
-- finger comes down
private function tapScript
   return "on mouseDown" & return & "   paPress the short name of me" & return & "end mouseDown" & return & \
         "on mouseDoubleDown" & return & "   paPress the short name of me" & return & "end mouseDoubleDown"
end tapScript

-- A sprite: a button that is only its icon
private command makeSprite pName, pPicture, pGroup
   create button pName in group pGroup
   set the style of button pName to "transparent"
   set the showName of button pName to false
   set the showBorder of button pName to false
   set the threeD of button pName to false
   set the opaque of button pName to false
   set the autoHilite of button pName to false
   set the showFocusBorder of button pName to false
   set the traversalOn of button pName to false
   set the margins of button pName to 0
   set the icon of button pName to the id of image pPicture of card "Art"
   set the rect of button pName to 0, 0, the width of image pPicture of card "Art", \
         the height of image pPicture of card "Art"
end makeSprite

-- A filled rectangle with no border
private command setBox pObject, pColor
   set the style of pObject to "rectangle"
   set the opaque of pObject to true
   set the filled of pObject to true
   set the lineSize of pObject to 0
   set the showBorder of pObject to false
   set the backgroundColor of pObject to pColor
end setBox

-- A rectangle with rounded corners, filled, with an edge
private command setRound pObject, pFill, pEdge
   set the style of pObject to "roundrect"
   set the roundRadius of pObject to 14
   set the opaque of pObject to true
   set the filled of pObject to true
   set the lineSize of pObject to 1
   set the backgroundColor of pObject to pFill
   set the foregroundColor of pObject to pEdge
   set the antialiased of pObject to true
end setRound

-- Lines, as a polygon whose points have a gap between each line
private command setLines pObject, pColor, pSize
   set the style of pObject to "polygon"
   set the opaque of pObject to false
   set the filled of pObject to false
   set the lineSize of pObject to pSize
   set the foregroundColor of pObject to pColor
   set the antialiased of pObject to false
   setPictureOnly pObject
end setLines

-- A graphic that is only a picture: a tap goes through it to what is
-- under it. The engine finds a polygon under the mouse near any of its
-- segments, the steps to and from each gap's marker among them, and
-- those run from the end of each line far off to the top left, across
-- the squares of the grid: a tap on some squares was lost to the lines
-- over them, on a phone and with the mouse alike. A disabled graphic
-- looks the same (only a label it shows would be greyed) and is never
-- under the mouse
private command setPictureOnly pObject
   set the disabled of pObject to true
end setPictureOnly

-- A field that is a label, in the game's font: locked, no frame, no
-- focus, no margins (the game places it to the point)
private command setLabel pField, pText, pSize, pColor, pStyle, pAlign
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to true
   set the margins of pField to 0
   set the textFont of pField to kFont
   set the textSize of pField to pSize
   set the textColor of pField to pColor
   set the textStyle of pField to pStyle
   set the textAlign of pField to pAlign
   set the text of pField to pText
end setLabel

-- A field of words, in the game's font, that wraps. It has 4 points
-- round its lines: with no margins, a field as tall as its
-- formattedHeight cut off the tops of its first line and the tails of
-- its last (y, g, p), on Windows and in a browser, and a line as wide as
-- the field lost a letter at each end
private command setText pField, pText, pSize, pColor, pAlign
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to false
   set the margins of pField to 4
   set the textFont of pField to kFont
   set the textSize of pField to pSize
   set the textColor of pField to pColor
   set the textAlign of pField to pAlign
   set the text of pField to pText
end setText

-- The stack's script: puzzle-almanac-stack.livecodescript beside this
-- file, without its first line (a script-only stack's header, there so
-- that editors and checkers read it as xTalk)
private function stackScript
   local tFile, tScript
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "puzzle-almanac-stack.livecodescript" into the last item of tFile
   set the itemDelimiter to comma
   put fileText(tFile) into tScript
   delete line 1 of tScript
   return tScript
end stackScript
