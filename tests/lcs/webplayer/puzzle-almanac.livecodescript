script "TestPuzzleAlmanac"
-- OXT-Beyond: the Puzzle Almanac game (the committed
-- tools/web-player/stacks/Puzzle Almanac.oxtstack, built by
-- tools/web-player/puzzle-almanac.livecodescript from
-- tools/web-player/puzzle-almanac-stack.livecodescript), on a desktop
-- engine.
--
-- The game's clock and day are in the test's hands: paTestBegin stops
-- its loop, fixes the random seed and the day (310, Saturday 7 November
-- 2026) and keeps what it saves in a file of the test's own; paTestStep
-- moves the clock on, paTestDay changes the day, and paState says how
-- things are. The buttons are pressed through paPress, as their scripts
-- do. tools/ci/puzzle_almanac_check.py plays it with real touches in a
-- phone's browser, and tools/ci/tests/test_puzzle_almanac.py works out
-- the day's puzzles here written down (TestTheDaysPuzzlesAreFixed) in
-- Python, from the files the stack is built from.

constant kStack = "Puzzle Almanac"
-- day 310's puzzles (tools/ci/tests/test_puzzle_almanac.py makes them
-- again from data/numbers.txt and data/answers.txt)
constant kDay310Size4 = "4010003010403000:4312213412433421"
constant kDay310Size6 = "142600300400000500050000030162020040:142653365421216534453216534162621345"
constant kDay310Size9 = "000437000913000000704019605009000006100008070230070001001806700400003010000040300:652437189913685427784219635879321546145968273236574891321896754468753912597142368"
constant kDay310Word4 = "wool"
constant kDay310Word5 = "float"
constant kDay310Word6 = "guitar"

local sSave

on TestSetup
   local tFile
   put specialFolderPath("temporary") & "/puzzle-almanac-test-" & the milliseconds & ".txt" into sSave
   if there is a file sSave then
      delete file sSave
   end if
   put TestGetEngineRepositoryPath() & "/tools/web-player/stacks/Puzzle Almanac.oxtstack" into tFile
   go stack tFile
   game "paTestBegin", 7, sSave, 310
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
   if sSave is not empty and there is a file sSave then
      delete file sSave
   end if
end TestTeardown

----------------------------------------------------------------------
-- Helpers

private command game pHandler, p1, p2, p3, p4
   dispatch pHandler to stack kStack with p1, p2, p3, p4
end game

-- One value of the game's paState
private function st pKey
   local tState
   dispatch function "paState" to stack kStack
   put the result into tState
   split tState by return and ":"
   return tState[pKey]
end st

-- A function of the game's
private function answerOf pHandler, p1, p2
   dispatch function pHandler to stack kStack with p1, p2
   return the result
end answerOf

private command press pButton
   game "paPress", pButton
end press

private command step pSeconds
   game "paTestStep", pSeconds
end step

-- A square of Number Place, chosen, and a number put in it
private command write1 pCell, pNumber
   game "paChoose", pCell
   press "N Key" && pNumber
end write1

-- Letters typed on the game's keyboard, then Enter (pEnter), and the
-- tiles let turn
private command type1 pWord, pEnter
   local tChar
   repeat for each char tChar in pWord
      press "W Key" && toUpper(tChar)
   end repeat
   if pEnter is not false then
      press "W Key Enter"
      step 3
   end if
end type1

-- Every square of the board that is not right, made right
private command solveBoard
   local tAnswer, tBoard, i
   put st("answer") into tAnswer
   put st("board") into tBoard
   repeat with i = 1 to the length of tAnswer
      if char i of tBoard is not char i of tAnswer then
         write1 i, char i of tAnswer
      end if
   end repeat
end solveBoard

-- A square that is empty, the first
private function emptySquare
   return offset("0", st("board"))
end emptySquare

-- A number that is not the right one for square pCell
private function wrongFor pCell
   local tRight
   put char pCell of st("answer") into tRight
   if tRight is 1 then
      return 2
   end if
   return 1
end wrongFor

private function fieldText pName
   return the text of field pName of card "Almanac" of stack kStack
end fieldText

-- Whether two boards are the same, digit for digit: "is" compares two
-- strings that look like numbers as numbers, to 15 digits or so, and a
-- board is a number of 16 to 81 digits
private function sameBoard pA, pB
   return ("n" & pA) is ("n" & pB)
end sameBoard

private function shown pGroup
   return the visible of group pGroup of card "Almanac" of stack kStack
end shown

private function saved
   local tText
   put url ("file:" & sSave) into tText
   return tText
end saved

-- The game opened again, as on another visit, with what it saved
private command visitAgain pDay
   game "paTestBegin", 7, sSave, pDay
end visitAgain

-- Whether rect pInner is wholly in rect pOuter
private function isInside pInner, pOuter
   return item 1 of pInner >= item 1 of pOuter and item 2 of pInner >= item 2 of pOuter and \
         item 3 of pInner <= item 3 of pOuter and item 4 of pInner <= item 4 of pOuter
end isInside

private function overlap pA, pB
   return item 1 of pA < item 3 of pB and item 1 of pB < item 3 of pA and \
         item 2 of pA < item 4 of pB and item 2 of pB < item 4 of pA
end overlap

-- The window at pWidth x pHeight, laid out again
private command windowSize pWidth, pHeight
   set the rect of stack kStack to 0, 0, pWidth, pHeight
   game "paResized"
end windowSize

-- Whether a puzzle:answer of pN squares a side is one: the answer has
-- every number once in each row, column and box, and the puzzle's
-- numbers are the answer's
private function isGrid pPuzzle, pN
   local tPuzzle, tAnswer, r, c, tRow, tCol, tBox, tBoxRows, tBoxCols, b, i, tCell, tAcross
   set the itemDelimiter to ":"
   put item 1 of pPuzzle into tPuzzle
   put item 2 of pPuzzle into tAnswer
   set the itemDelimiter to comma
   if the length of tPuzzle is not pN * pN or the length of tAnswer is not pN * pN then
      return false
   end if
   repeat with i = 1 to pN * pN
      if char i of tPuzzle is not 0 and char i of tPuzzle is not char i of tAnswer then
         return false
      end if
   end repeat
   if pN is 9 then
      put 3 into tBoxRows
   else
      put 2 into tBoxRows
   end if
   put pN div tBoxRows into tBoxCols
   -- (boxes across the grid)
   put pN div tBoxCols into tAcross
   repeat with r = 0 to pN - 1
      put empty into tRow
      put empty into tCol
      repeat with c = 0 to pN - 1
         put char (r * pN + c + 1) of tAnswer after tRow
         put char (c * pN + r + 1) of tAnswer after tCol
      end repeat
      if not allOnce(tRow, pN) or not allOnce(tCol, pN) then
         return false
      end if
   end repeat
   repeat with b = 0 to pN - 1
      put empty into tBox
      repeat with i = 0 to pN - 1
         put ((b div tAcross) * tBoxRows + i div tBoxCols) * pN + (b mod tAcross) * tBoxCols + i mod tBoxCols + 1 into tCell
         put char tCell of tAnswer after tBox
      end repeat
      if not allOnce(tBox, pN) then
         return false
      end if
   end repeat
   return true
end isGrid

private function allOnce pText, pN
   local i
   repeat with i = 1 to pN
      if i is not in pText then
         return false
      end if
   end repeat
   return the length of pText is pN
end allOnce

----------------------------------------------------------------------
-- Opening

on TestTheGameOpensOnHome
   TestAssert "Home is shown", st("screen") is "home" and shown("Home")
   TestAssert "and nothing over it", st("panel") is empty and not shown("Done") and not shown("Practice") and \
         not shown("Howto") and not shown("Settings") and not the visible of graphic "Shade" of stack kStack
   TestAssert "nor the other screens", not shown("Numbers") and not shown("Words") and not shown("Stickers") and \
         not shown("Top")
   TestAssert "with the day", fieldText("Home Date") is "Saturday 7 November"
   TestAssert "both puzzles new today", fieldText("Numbers Card State") is "New today" and \
         fieldText("Words Card State") is "New today"
   TestAssert "in the sizes of the settings", fieldText("Numbers Card Sub") is "Today's 6 by 6" and \
         fieldText("Words Card Sub") is "Today's word of 5 letters"
   TestAssert "no stars yet", not the visible of button "Numbers Card Badge" of stack kStack and \
         not the visible of button "Words Card Badge" of stack kStack
   TestAssert "no stickers, no runs", fieldText("Home Streak") is \
         "Stickers: 0 of 30" & return & "Days in a row: 0 for numbers, 0 for words"
   TestAssert "nothing moves", st("moving") is false
end TestTheGameOpensOnHome

-- What the builder put in the stack: every picture of the art list on
-- the Art card, every sound, the fonts, the puzzles and the words
on TestEverythingTheGameNeedsIsInTheStack
   local tList, tLine, tMissing, tSounds, tName, tCount
   put url ("file:" & TestGetEngineRepositoryPath() & "/tools/web-player/puzzle-almanac/art/art.txt") into tList
   TestAssert "the art list is read", tList is not empty
   set the itemDelimiter to tab
   repeat for each line tLine in tList
      if tLine is empty or char 1 of tLine is "#" then
         next repeat
      end if
      add 1 to tCount
      if there is not an image (item 1 of tLine) of card "Art" of stack kStack then
         put item 1 of tLine & space after tMissing
      end if
   end repeat
   set the itemDelimiter to comma
   TestAssert "every picture is on the Art card" && tMissing, tMissing is empty and tCount >= 37
   put the customKeys["cSounds"] of stack kStack into tSounds
   repeat for each item tName in "page,open,close,place,tap,erase,nope,reveal,coins,say-1,say-9,say-correct,say-congratulations"
      TestAssert "the sound" && tName && "is there", tName is among the lines of tSounds
   end repeat
   TestAssert "both faces of the font", the cFontRegular of stack kStack is not empty and \
         the cFontBold of stack kStack is not empty
   TestAssert "the puzzles", the number of lines of the cNumbers of stack kStack is 496
   TestAssert "the hidden words, without their notes", the number of lines of the cAnswers of stack kStack > 300 and \
         not ("#" is in the cAnswers of stack kStack)
   TestAssert "every word a try may be", the number of lines of the cWords of stack kStack > 20000 and \
         "float" is among the lines of the cWords of stack kStack
end TestEverythingTheGameNeedsIsInTheStack

----------------------------------------------------------------------
-- The days

on TestTheDaysAreCounted
   local tToday
   TestAssert "day 0 is 1 January 2026", answerOf("paDayOf", "2026,1,1,0,0,0,5") is 0
   TestAssert "the day before is -1", answerOf("paDayOf", "2025,12,31,0,0,0,4") is -1
   TestAssert "day 310 is 7 November", answerOf("paDayOf", "2026,11,7,9,30,0,7") is 310
   TestAssert "a leap year has its 29 February", answerOf("paDayOf", "2028,3,1,0,0,0,4") - answerOf("paDayOf", "2028,2,28,0,0,0,2") is 2
   TestAssert "a day as words", answerOf("paDateText", 0) is "Thursday 1 January" and \
         answerOf("paDateText", 790) is "Wednesday 1 March"
   put the date into tToday
   convert tToday to dateItems
   TestAssert "today is the computer's, without a test", answerOf("paDayOf", tToday) is an integer
end TestTheDaysAreCounted

-- The same puzzles on every engine, on the same day (the Python test
-- makes these from the files)
on TestTheDaysPuzzlesAreFixed
   TestAssert "day 310's 4 by 4", answerOf("paDailyNumbers", 4, 310) is kDay310Size4
   TestAssert "day 310's 6 by 6", answerOf("paDailyNumbers", 6, 310) is kDay310Size6
   TestAssert "day 310's 9 by 9", answerOf("paDailyNumbers", 9, 310) is kDay310Size9
   set the itemDelimiter to tab
   TestAssert "day 310's words", item 1 of answerOf("paDailyWord", 4, 310) is kDay310Word4 and \
         item 1 of answerOf("paDailyWord", 5, 310) is kDay310Word5 and item 1 of answerOf("paDailyWord", 6, 310) is kDay310Word6
   TestAssert "with what it means", item 2 of answerOf("paDailyWord", 5, 310) is not empty
   set the itemDelimiter to comma
   TestAssert "another day, another puzzle", answerOf("paDailyNumbers", 6, 311) is not kDay310Size6 and \
         answerOf("paDailyWord", 5, 311) is not answerOf("paDailyWord", 5, 310)
   TestAssert "a day before day 0 has one too", isGrid(answerOf("paDailyNumbers", 6, -5), 6)
end TestTheDaysPuzzlesAreFixed

-- A puzzle turned into another is still one: every day's, in every size
on TestEveryDaysPuzzleIsAGrid
   local tN, tDay, tBad, tPuzzle, tGivens
   repeat for each item tN in "4,6,9"
      repeat with tDay = 300 to 340
         put answerOf("paDailyNumbers", tN, tDay) into tPuzzle
         if not isGrid(tPuzzle, tN) then
            put tN & "/" & tDay & space after tBad
         end if
      end repeat
   end repeat
   TestAssert "every day's puzzle is a grid" && tBad, tBad is empty
   -- as many numbers given as the puzzle it came from: as few as that
   put answerOf("paDailyNumbers", 9, 310) into tPuzzle
   set the itemDelimiter to ":"
   put item 1 of tPuzzle into tPuzzle
   set the itemDelimiter to comma
   replace "0" with empty in tPuzzle
   TestAssert "a 9 by 9 gives 28 to 32 numbers", the length of tPuzzle >= 28 and the length of tPuzzle <= 32
end TestEveryDaysPuzzleIsAGrid

----------------------------------------------------------------------
-- Number Place

on TestTodaysNumberPlace
   press "Numbers Card"
   TestAssert "its screen", st("screen") is "numbers" and shown("Numbers") and shown("Top") and not shown("Home")
   TestAssert "with its name over it", fieldText("Top Title") is "Number Place"
   TestAssert "today's, 6 by 6", st("ndaily") is true and st("n") is 6 and st("nday") is 310 and \
         st("given") & ":" & st("answer") is kDay310Size6
   TestAssert "nothing written yet", sameBoard(st("board"), st("given")) and st("chosen") is 0
   TestAssert "the line over it", fieldText("N Info") is "Today's 6 by 6"
   TestAssert "says what to do", fieldText("N Message") is "Tap a square, then a number."
   TestAssert "six keys", the visible of button "N Key 6" of stack kStack and \
         not the visible of button "N Key 7" of stack kStack
   TestAssert "and 36 squares", the visible of field "N Cell 36" of stack kStack and \
         not the visible of field "N Cell 37" of stack kStack
   TestAssert "a given number is shown", fieldText("N Cell 1") is char 1 of st("given")
   press "Back"
   TestAssert "Back goes home", st("screen") is "home" and fieldText("Numbers Card State") is "New today"
end TestTodaysNumberPlace

-- A tap (a click) on any square of the grid chooses it, in every size:
-- what is under the finger there (controlAtLoc, which finds it as a
-- click does) is the square or its notes, and its mouseDown chooses it.
-- The grid's lines over the squares are pictures only: a polygon is
-- under the mouse near the steps to and from each gap between its lines,
-- which run across the board, and the phone check found them taking the
-- taps of some squares
on TestATapOnAnySquareChoosesIt
   local tSize, tMissed, tControl, i
   repeat for each item tSize in "6,9,4"
      if tSize is 6 then
         press "Numbers Card"
      else
         press "Back"
         press "Practice Open"
         press "P N" & tSize
      end if
      put empty into tMissed
      repeat with i = 1 to tSize * tSize
         set the defaultStack to kStack
         put controlAtLoc(the loc of field ("N Cell" && i) of stack kStack) into tControl
         if tControl is empty or the short name of tControl is not among the items of ("N Cell" && i & comma & "N Note" && i) then
            put i & ":" & the short name of tControl & comma after tMissed
            next repeat
         end if
         send "mouseDown" to tControl
         if st("chosen") is not i then
            put i & comma after tMissed
         end if
      end repeat
      TestAssert "a tap on any square of a" && tSize && "by" && tSize && "chooses it" && tMissed, tMissed is empty
   end repeat
end TestATapOnAnySquareChoosesIt

on TestANumberGoesInAndTheSameTakesItOut
   local tCell, tRight
   press "Numbers Card"
   put emptySquare() into tCell
   put char tCell of st("answer") into tRight
   write1 tCell, tRight
   TestAssert "the number is in its square", char tCell of st("board") is tRight and fieldText("N Cell" && tCell) is tRight
   TestAssert "in the colour of a written number", the textColor of field ("N Cell" && tCell) of stack kStack is "#2F6DB5"
   TestAssert "the square is chosen", st("chosen") is tCell and \
         the backgroundColor of field ("N Cell" && tCell) of stack kStack is "#F6D98A"
   TestAssert "Undo can take it back", st("undo") is 1
   press "N Key" && tRight
   TestAssert "the same number again takes it out", char tCell of st("board") is 0 and fieldText("N Cell" && tCell) is empty
   write1 tCell, tRight
   TestAssert "the board is kept as it is", "nboard=" & st("board") is among the lines of saved()
end TestANumberGoesInAndTheSameTakesItOut

on TestAGivenNumberStays
   local tBoard
   press "Numbers Card"
   put st("board") into tBoard
   write1 1, wrongFor(1)
   TestAssert "a given number does not change", sameBoard(st("board"), tBoard)
   TestAssert "and the message says why", fieldText("N Message") contains "stays"
   game "paChoose", 0
   game "paTestBegin", 7, sSave, 310
   press "Numbers Card"
   press "N Key 1"
   TestAssert "a number with no square chosen asks for one", fieldText("N Message") is "Tap a square first."
end TestAGivenNumberStays

on TestMistakesShowRed
   local tCell
   press "Numbers Card"
   put emptySquare() into tCell
   write1 tCell, wrongFor(tCell)
   TestAssert "a wrong number is red", the textColor of field ("N Cell" && tCell) of stack kStack is "#C2412D"
   press "Back"
   press "Settings Open"
   press "Set Mistakes"
   TestAssert "the switch says so", the label of button "Set Mistakes" of stack kStack is "Show mistakes: off" and \
         st("mistakes") is false
   press "Settings Done"
   press "Numbers Card"
   TestAssert "with mistakes not shown, it is the colour of any", \
         the textColor of field ("N Cell" && tCell) of stack kStack is "#2F6DB5"
   TestAssert "and the setting is kept", "mistakes=false" is among the lines of saved()
end TestMistakesShowRed

on TestNotes
   local tCell, tPeer, tNotes
   press "Numbers Card"
   put emptySquare() into tCell
   game "paChoose", tCell
   press "N Notes"
   TestAssert "Notes is on", st("noteson") is true and the label of button "N Notes" of stack kStack is "Notes: on"
   press "N Key 2"
   press "N Key 5"
   press "N Key 3"
   set the itemDelimiter to "."
   TestAssert "the notes are written in order", item tCell of st("notes") is "235"
   TestAssert "and shown, each in its place", fieldText("N Note" && tCell) is \
         empty & tab & "2" & tab & "3" & return & empty & tab & "5" & tab & empty
   press "N Key 3"
   TestAssert "a note again takes it out", item tCell of st("notes") is "25"
   press "N Notes"
   TestAssert "Notes is off", st("noteson") is false and the label of button "N Notes" of stack kStack is "Notes"
   -- a number in a square of the same row takes its note away
   put tCell + 1 into tPeer
   if (tCell - 1) mod 6 is 5 or char tPeer of st("given") is not 0 then
      put tCell - 1 into tPeer
   end if
   if char tPeer of st("given") is 0 then
      write1 tPeer, 5
      TestAssert "a number takes the same note from its row", item tCell of st("notes") is "2"
      press "N Undo"
      TestAssert "Undo puts the note back", item tCell of st("notes") is "25" and char tPeer of st("board") is 0
   end if
   set the itemDelimiter to comma
   TestAssert "the notes are kept", "nnotes=" & st("notes") is among the lines of saved()
end TestNotes

on TestUndoAndErase
   local tCell, tGiven
   press "Numbers Card"
   put emptySquare() into tCell
   write1 tCell, 1
   write1 tCell, 2
   press "N Undo"
   TestAssert "Undo takes the last back", char tCell of st("board") is 1
   press "N Undo"
   TestAssert "and the one before", char tCell of st("board") is 0
   press "N Undo"
   TestAssert "nothing more to take back", char tCell of st("board") is 0 and st("undo") is 0
   write1 tCell, 4
   press "N Erase"
   TestAssert "Erase empties the square", char tCell of st("board") is 0
   game "paChoose", 1
   put st("board") into tGiven
   press "N Erase"
   TestAssert "not a given one", sameBoard(st("board"), tGiven)
end TestUndoAndErase

on TestHint
   local tCell
   press "Numbers Card"
   press "N Hint"
   put st("chosen") into tCell
   TestAssert "a hint fills a square", tCell > 0 and char tCell of st("board") is char tCell of st("answer") and \
         char tCell of st("given") is 0
   TestAssert "and is counted", st("hints") is 1 and fieldText("N Info") is "Today's 6 by 6, 1 hint"
   put emptySquare() into tCell
   write1 tCell, wrongFor(tCell)
   press "N Hint"
   TestAssert "a hint puts a wrong number right", char tCell of st("board") is char tCell of st("answer")
   TestAssert "two hints", fieldText("N Info") is "Today's 6 by 6, 2 hints"
end TestHint

on TestTheKeysOfNumberPlace
   local tCell
   press "Numbers Card"
   game "paChoose", 8
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65363
   TestAssert "right moves on a square", st("chosen") is 9
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65364
   TestAssert "down, a row", st("chosen") is 15
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65362
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65362
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65362
   TestAssert "up, round to the bottom", st("chosen") is 33
   put emptySquare() into tCell
   game "paChoose", tCell
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 52
   TestAssert "a number key writes it", char tCell of st("board") is 4
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65288
   TestAssert "Backspace erases it", char tCell of st("board") is 0
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 57
   TestAssert "a number bigger than the grid does nothing", char tCell of st("board") is 0
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 110
   TestAssert "N for notes", st("noteson") is true
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65307
   TestAssert "Escape goes home", st("screen") is "home"
end TestTheKeysOfNumberPlace

-- On Home, N opens Number Place and W Hidden Word (so a computer plays
-- it from the keys alone; the check of its page on the web site does)
on TestTheKeysOfHome
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 110
   TestAssert "N opens Number Place", st("screen") is "numbers" and st("ndaily") is true and st("noteson") is not true
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65307
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 87
   TestAssert "W opens Hidden Word", st("screen") is "words" and st("wdaily") is true
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 119
   TestAssert "where w is a letter", st("typed") is "w"
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65307
   game "paOpenPanel", "howto"
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 110
   TestAssert "not under a panel", st("screen") is "home" and st("panel") is "howto"
   TestAssert "the window's size", st("window") is the width of stack kStack & comma & the height of stack kStack
end TestTheKeysOfHome

-- A row, a column or a box finished shines a moment
on TestAFinishedBoxShines
   local tAnswer, tBoard, tCell, tLast
   press "Numbers Card"
   put st("answer") into tAnswer
   put st("board") into tBoard
   -- the first row, all but its last empty square
   repeat with tCell = 1 to 6
      if char tCell of tBoard is 0 then
         put tCell into tLast
      end if
   end repeat
   repeat with tCell = 1 to 6
      if char tCell of tBoard is 0 and tCell is not tLast then
         write1 tCell, char tCell of tAnswer
      end if
   end repeat
   TestAssert "nothing shines yet", the backgroundColor of field "N Cell 2" of stack kStack is not "#CFE8C6"
   write1 tLast, char tLast of tAnswer
   TestAssert "the row finished shines", the backgroundColor of field "N Cell 2" of stack kStack is "#CFE8C6"
   step 1
   TestAssert "a moment", the backgroundColor of field "N Cell 2" of stack kStack is not "#CFE8C6"
end TestAFinishedBoxShines

on TestSolvingTodaysEarnsASticker
   press "Numbers Card"
   solveBoard
   TestAssert "solved", st("solved") is true and sameBoard(st("board"), st("answer"))
   TestAssert "Done is shown", st("panel") is "done" and shown("Done") and the visible of graphic "Shade" of stack kStack
   TestAssert "the first sticker: the owl", st("award") is "owl" and st("stickers") is 1 and \
         the visible of button "Done Sticker" of stack kStack and \
         the icon of button "Done Sticker" of stack kStack is the id of image "animal-owl" of card "Art" of stack kStack
   TestAssert "Done says so", fieldText("Done Title") is "Solved!" and fieldText("Done Note") contains "the owl" and \
         fieldText("Done Meaning") is "Every square, and no hints at all."
   TestAssert "the sparks fly", the visible of button "Done Spark 1" of stack kStack and st("moving") is true
   step 3
   TestAssert "a while", not the visible of button "Done Spark 1" of stack kStack
   TestAssert "a run of one day", st("nstreak") is 1 and st("nlast") is 310
   TestAssert "kept", "stickers=1" is among the lines of saved() and "nlast=310" is among the lines of saved()
   press "Done Home"
   TestAssert "home says it is solved", st("screen") is "home" and fieldText("Numbers Card State") is "Solved today" and \
         the visible of button "Numbers Card Badge" of stack kStack
   TestAssert "with the sticker and the run", line 1 of fieldText("Home Streak") is "Stickers: 1 of 30" and \
         line 2 of fieldText("Home Streak") is "Days in a row: 1 for numbers, 0 for words"
   press "Numbers Card"
   TestAssert "today's stays solved", st("solved") is true and fieldText("N Message") contains "tomorrow"
   write1 1, 2
   TestAssert "and takes no more numbers", sameBoard(st("board"), st("answer")) and st("stickers") is 1
end TestSolvingTodaysEarnsASticker

-- A board right at the top and empty below is not solved: the board and
-- the answer are compared digit for digit, not as the numbers they look
-- like (which the engine keeps to 15 digits or so: the phone check found
-- the game saying "Solved!" with half of the board still empty)
on TestABoardRightOnlyAtTheTopIsNotSolved
   local tAnswer, tBoard, i
   press "Numbers Card"
   put st("answer") into tAnswer
   put st("board") into tBoard
   repeat with i = 1 to 18
      if char i of tBoard is not char i of tAnswer then
         write1 i, char i of tAnswer
      end if
   end repeat
   TestAssert "the first three rows right", char 1 to 18 of st("board") is char 1 to 18 of tAnswer and \
         "0" is in char 19 to -1 of st("board")
   TestAssert "is not solved", st("solved") is false and st("panel") is empty and st("stickers") is 0
   TestAssert "and takes more numbers", st("nlast") is empty
   solveBoard
   TestAssert "the whole board is", st("solved") is true and st("panel") is "done" and st("stickers") is 1
end TestABoardRightOnlyAtTheTopIsNotSolved

-- A board started at the bottom is started: Home says so (the board and
-- the numbers given, compared digit for digit)
on TestABoardStartedAtTheBottomIsStarted
   local tCell
   press "Numbers Card"
   put the length of st("board") into tCell
   repeat while char tCell of st("given") is not 0
      subtract 1 from tCell
   end repeat
   write1 tCell, char tCell of st("answer")
   press "Back"
   TestAssert "home says it was started", fieldText("Numbers Card State") is "Started"
   visitAgain 310
   TestAssert "and again on the next visit", fieldText("Numbers Card State") is "Started"
end TestABoardStartedAtTheBottomIsStarted

on TestARunOfDays
   press "Numbers Card"
   solveBoard
   visitAgain 311
   TestAssert "the next day, a new puzzle", fieldText("Numbers Card State") is "New today"
   TestAssert "the run goes on until it is missed", line 2 of fieldText("Home Streak") begins with "Days in a row: 1 for"
   press "Numbers Card"
   solveBoard
   TestAssert "two days in a row", st("nstreak") is 2 and st("stickers") is 2 and st("award") is "rabbit"
   visitAgain 314
   TestAssert "a day missed ends it", line 2 of fieldText("Home Streak") begins with "Days in a row: 0 for"
   press "Numbers Card"
   solveBoard
   TestAssert "and a new one begins", st("nstreak") is 1 and st("stickers") is 3
end TestARunOfDays

on TestTodaysBoardIsKeptBetweenVisits
   local tCell, tBoard, tNotes
   press "Numbers Card"
   put emptySquare() into tCell
   write1 tCell, char tCell of st("answer")
   press "N Hint"
   game "paChoose", emptySquare()
   press "N Notes"
   press "N Key 1"
   put st("board") into tBoard
   put st("notes") into tNotes
   press "Back"
   visitAgain 310
   TestAssert "home says it was started", fieldText("Numbers Card State") is "Started"
   press "Numbers Card"
   TestAssert "the board is as it was", sameBoard(st("board"), tBoard) and st("notes") is tNotes and st("hints") is 1
   visitAgain 311
   press "Numbers Card"
   TestAssert "the next day it is a new one", sameBoard(st("board"), st("given")) and st("hints") is 0
end TestTodaysBoardIsKeptBetweenVisits

on TestASizeChangeStartsTodaysAgain
   press "Numbers Card"
   write1 emptySquare(), 1
   press "Back"
   press "Settings Open"
   press "Set Size"
   TestAssert "the size goes to 9 by 9", st("size") is 9 and the label of button "Set Size" of stack kStack is "Number Place: 9 by 9"
   TestAssert "and a note says today's starts again", fieldText("Settings Note") contains "start again"
   press "Settings Done"
   TestAssert "home says so", fieldText("Numbers Card Sub") is "Today's 9 by 9" and fieldText("Numbers Card State") is "New today"
   press "Numbers Card"
   TestAssert "today's 9 by 9", st("n") is 9 and st("given") & ":" & st("answer") is kDay310Size9 and \
         the visible of field "N Cell 81" of stack kStack
   press "Back"
   press "Settings Open"
   press "Set Size"
   TestAssert "then 4 by 4", st("size") is 4
   press "Set Size"
   TestAssert "then 6 by 6 again", st("size") is 6 and "size=6" is among the lines of saved()
end TestASizeChangeStartsTodaysAgain

on TestPracticeNumberPlace
   press "Practice Open"
   TestAssert "Practice is shown", st("panel") is "practice" and shown("Practice")
   press "P N4"
   TestAssert "a practice 4 by 4", st("screen") is "numbers" and st("n") is 4 and st("ndaily") is false and \
         isGrid(st("given") & ":" & st("answer"), 4)
   TestAssert "its name", fieldText("Top Title") is "Practice" and fieldText("N Info") is "Practice, 4 by 4"
   TestAssert "four keys", the visible of button "N Key 4" of stack kStack and not the visible of button "N Key 5" of stack kStack
   solveBoard
   TestAssert "solved, for no sticker", st("panel") is "done" and st("award") is empty and st("stickers") is 0 and \
         not the visible of button "Done Sticker" of stack kStack
   TestAssert "Done says so", fieldText("Done Note") contains "no sticker"
   press "Done Again"
   TestAssert "Practise another: another 4 by 4", st("panel") is empty and st("n") is 4 and st("solved") is false
   TestAssert "nothing of practice is kept", not ("nday=" is in saved())
end TestPracticeNumberPlace

----------------------------------------------------------------------
-- Hidden Word

on TestTodaysHiddenWord
   press "Words Card"
   TestAssert "its screen", st("screen") is "words" and shown("Words") and fieldText("Top Title") is "Hidden Word"
   TestAssert "today's word of 5 letters", st("wdaily") is true and st("len") is 5 and st("word") is kDay310Word5
   TestAssert "and 30 tiles", the visible of graphic "W Slot 30" of stack kStack and \
         not the visible of graphic "W Slot 31" of stack kStack
   TestAssert "the line over them", fieldText("W Info") is "Today's word: 5 letters, try 1 of 6"
   type1 "pla", false
   TestAssert "letters typed are on tiles", st("typed") is "pla" and fieldText("W Letter 3") is "A" and \
         the visible of button "W Tile 3" of stack kStack and not the visible of button "W Tile 4" of stack kStack
   press "W Key Back"
   TestAssert "Delete takes the last away", st("typed") is "pl" and fieldText("W Letter 3") is empty
   type1 "ntsx", false
   TestAssert "no more letters than the word has", st("typed") is "plnts"
end TestTodaysHiddenWord

on TestHowATryIsScored
   TestAssert "letters in the right place", answerOf("paScore", "float", "float") is "ggggg"
   TestAssert "in the word, another place", answerOf("paScore", "speed", "abide") is "ssbsb"
   TestAssert "a letter twice, once in the word", answerOf("paScore", "llama", "hello") is "bbsss"
   TestAssert "the right place first", answerOf("paScore", "eerie", "there") is "bsbsg"
   TestAssert "a word of 4", answerOf("paScore", "loow", "wool") is "bggb"
end TestHowATryIsScored

on TestATryMustBeAWord
   press "Words Card"
   type1 "plan", false
   press "W Key Enter"
   TestAssert "too few letters is not a try", st("rows") is empty and fieldText("W Message") is "Not enough letters yet."
   press "W Key Back"
   press "W Key Back"
   press "W Key Back"
   press "W Key Back"
   type1 "zzzzz", false
   press "W Key Enter"
   TestAssert "nor a word not in the list", st("rows") is empty and fieldText("W Message") contains "word list"
   TestAssert "and the letters stay to be changed", st("typed") is "zzzzz"
end TestATryMustBeAWord

on TestTheTilesTurnOneByOne
   press "Words Card"
   type1 "stone", false
   press "W Key Enter"
   TestAssert "the try is scored at once", st("rows") is "stone" and st("turning") is true
   TestAssert "its tiles still marble", the icon of button "W Tile 1" of stack kStack is \
         the id of image "tile-marble" of card "Art" of stack kStack
   type1 "a", false
   TestAssert "no typing while they turn", st("typed") is empty
   step 0.1
   TestAssert "the first turns", the icon of button "W Tile 1" of stack kStack is not \
         the id of image "tile-marble" of card "Art" of stack kStack and \
         the icon of button "W Tile 2" of stack kStack is the id of image "tile-marble" of card "Art" of stack kStack
   step 2
   TestAssert "then all", st("turning") is false and the icon of button "W Tile 5" of stack kStack is not \
         the id of image "tile-marble" of card "Art" of stack kStack
   -- stone against float: o and t are in it, o in its place
   TestAssert "scored", st("scores") is "sbgss"
   TestAssert "the tiles say so", the icon of button "W Tile 3" of stack kStack is \
         the id of image "tile-gold" of card "Art" of stack kStack and \
         the icon of button "W Tile 2" of stack kStack is the id of image "tile-blue" of card "Art" of stack kStack and \
         the icon of button "W Tile 1" of stack kStack is the id of image "tile-stone" of card "Art" of stack kStack
   TestAssert "and their marks: a star for gold, a dot for blue", the visible of graphic "W Mark 3" of stack kStack and \
         the visible of graphic "W Mark 2" of stack kStack and not the visible of graphic "W Mark 1" of stack kStack
   TestAssert "the keys take the colours", the backgroundColor of graphic "W Key O Shape" of stack kStack is "#FFCC00" and \
         the backgroundColor of graphic "W Key T Shape" of stack kStack is "#269FBD" and \
         the backgroundColor of graphic "W Key S Shape" of stack kStack is "#4C4740"
   TestAssert "the next try", fieldText("W Info") is "Today's word: 5 letters, try 2 of 6"
   TestAssert "the try is kept", "wrows=stone" is among the lines of saved()
end TestTheTilesTurnOneByOne

on TestFindingTheWordEarnsASticker
   press "Words Card"
   type1 "stone"
   type1 kDay310Word5
   TestAssert "found", st("over") is "won" and st("panel") is "done"
   TestAssert "Done says the word and what it means", fieldText("Done Title") is "Well done!" and \
         fieldText("Done Word") is toUpper(kDay310Word5) and fieldText("Done Meaning") contains "water"
   TestAssert "a sticker", st("award") is "owl" and fieldText("Done Note") contains "the owl"
   TestAssert "a run of one", st("wstreak") is 1 and st("wlast") is 310
   press "Done Home"
   TestAssert "home says it is solved", fieldText("Words Card State") is "Solved today" and \
         the visible of button "Words Card Badge" of stack kStack
   visitAgain 310
   press "Words Card"
   TestAssert "the tries are kept", st("rows") is "stone," & kDay310Word5 and st("over") is "won"
   TestAssert "today's takes no more", fieldText("W Message") contains "tomorrow"
   type1 "a", false
   TestAssert "no more letters", st("typed") is empty
end TestFindingTheWordEarnsASticker

on TestSixTriesUsed
   local tTry
   press "Words Card"
   repeat for each item tTry in "stone,crane,plumb,dirty,shake,quick"
      type1 tTry
   end repeat
   TestAssert "six tries and not found", st("over") is "lost" and st("panel") is "done"
   TestAssert "Done says the word", fieldText("Done Title") is "So close!" and fieldText("Done Word") is toUpper(kDay310Word5)
   TestAssert "no sticker", st("award") is empty and st("stickers") is 0 and not the visible of button "Done Sticker" of stack kStack
   TestAssert "a word tomorrow", fieldText("Done Note") contains "tomorrow"
   press "Done Home"
   TestAssert "home says so", fieldText("Words Card State") is "A new word tomorrow"
end TestSixTriesUsed

on TestPracticeHiddenWord
   press "Practice Open"
   press "P W6"
   TestAssert "a practice word of 6 letters", st("screen") is "words" and st("len") is 6 and st("wdaily") is false and \
         the length of st("word") is 6 and st("word") is not kDay310Word6
   TestAssert "and 36 tiles", the visible of graphic "W Slot 36" of stack kStack
   game "paStartWords", 5, false, "plant"
   type1 "plant"
   TestAssert "found, for no sticker", st("over") is "won" and st("award") is empty and st("stickers") is 0
   TestAssert "Done says practice", fieldText("Done Note") contains "no sticker"
   press "Done Again"
   TestAssert "Practise another: another word", st("panel") is empty and st("len") is 5 and st("rows") is empty
   TestAssert "nothing of practice is kept", not ("wday=" is in saved())
end TestPracticeHiddenWord

on TestTheKeysOfHiddenWord
   press "Words Card"
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 115
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 84
   TestAssert "letters, small or capital", st("typed") is "st"
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65288
   TestAssert "Backspace", st("typed") is "s"
   type1 "tone", false
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65293
   TestAssert "Return tries", st("rows") is "stone"
end TestTheKeysOfHiddenWord

on TestALengthChange
   press "Settings Open"
   press "Set Length"
   TestAssert "the length goes to 6 letters", st("length") is 6 and the label of button "Set Length" of stack kStack is "Hidden Word: 6 letters"
   press "Settings Done"
   press "Words Card"
   TestAssert "today's word of 6", st("len") is 6 and st("word") is kDay310Word6
   type1 "guitar"
   press "Done Home"
   press "Settings Open"
   press "Set Length"
   TestAssert "solved: the new length starts tomorrow", st("length") is 4 and fieldText("Settings Note") contains "tomorrow"
   press "Settings Done"
   press "Words Card"
   TestAssert "today's stays the word of 6", st("len") is 6 and st("over") is "won"
end TestALengthChange

----------------------------------------------------------------------
-- The sticker book, the settings, the panels

on TestTheStickerBook
   put "stickers=17" & return & "howto=true" & return into url ("file:" & sSave)
   visitAgain 310
   press "Stickers Open"
   TestAssert "its screen", st("screen") is "stickers" and shown("Stickers") and fieldText("Top Title") is "Sticker book"
   TestAssert "open at the newest", st("page") is 2 and fieldText("S Count") is "Stickers: 17 of 30"
   TestAssert "page 2 has two", the visible of button "S Slot 2" of stack kStack and \
         not the visible of button "S Slot 3" of stack kStack and fieldText("S Name 2") is "Horse"
   press "S Prev"
   TestAssert "page 1 is full", st("page") is 1 and the visible of button "S Slot 15" of stack kStack and \
         fieldText("S Name 1") is "Owl"
   TestAssert "its button is lit", the backgroundColor of graphic "S Prev Shape" of stack kStack is "#4E9A5B"
   press "Back"
   TestAssert "Back goes home", st("screen") is "home"
end TestTheStickerBook

on TestEveryStickerThenStars
   put "stickers=30" & return & "stars=2" & return into url ("file:" & sSave)
   visitAgain 310
   TestAssert "home counts the stars", line 1 of fieldText("Home Streak") is "Stickers: 30 of 30, and 2 gold stars"
   press "Numbers Card"
   solveBoard
   TestAssert "a gold star", st("award") is "star" and st("stars") is 3 and st("stickers") is 30 and \
         the icon of button "Done Sticker" of stack kStack is the id of image "star" of card "Art" of stack kStack
   TestAssert "Done says so", fieldText("Done Note") contains "gold star"
end TestEveryStickerThenStars

on TestASavedFileThatMakesNoSense
   put "stickers=lots" & return & "size=7" & return & "length=x" & return & "sound=maybe" & return & \
         "nday=310" & return & "nsize=6" & return & "nboard=12" & return & \
         "wday=310" & return & "wlen=5" & return & "wrows=ab,cd" & return & "nonsense" & return into url ("file:" & sSave)
   visitAgain 310
   TestAssert "is read as nothing saved", st("stickers") is 0 and st("size") is 6 and st("length") is 5
   TestAssert "the board and the tries too", fieldText("Numbers Card State") is "New today" and \
         fieldText("Words Card State") is "New today"
   press "Numbers Card"
   TestAssert "today's board is new", sameBoard(st("board"), st("given"))
end TestASavedFileThatMakesNoSense

on TestTheSettings
   press "Settings Open"
   TestAssert "the settings are shown", st("panel") is "settings" and shown("Settings")
   TestAssert "a window has no full screen switch", not the visible of button "Set Full" of stack kStack
   press "Set Voice"
   TestAssert "the voice", st("voice") is true and the label of button "Set Voice" of stack kStack is "Say the numbers: on"
   press "Set Sound"
   TestAssert "the sound (off for the test, so now on)", st("sound") is true and \
         the label of button "Set Sound" of stack kStack is "Sound: on"
   TestAssert "kept", "voice=true" is among the lines of saved() and "sound=true" is among the lines of saved()
   game "paTestBegin", 7, sSave, 310
   TestAssert "read again", st("voice") is true
   press "Settings Open"
   dispatch "rawKeyDown" to card "Almanac" of stack kStack with 65307
   TestAssert "Escape shuts a panel", st("panel") is empty and not shown("Settings")
end TestTheSettings

on TestHowToPlay
   press "Howto Open"
   TestAssert "how to play is shown", st("panel") is "howto" and shown("Howto")
   TestAssert "its tiles: gold, blue, stone", the icon of button "Howto Tile 1" of stack kStack is \
         the id of image "tile-gold" of card "Art" of stack kStack and the visible of graphic "Howto Mark 1" of stack kStack and \
         the visible of graphic "Howto Mark 2" of stack kStack and not the visible of graphic "Howto Mark 3" of stack kStack
   press "Howto Done"
   TestAssert "Got it shuts it", st("panel") is empty and st("howto") is true
   TestAssert "and it is not shown again", "howto=true" is among the lines of saved()
end TestHowToPlay

----------------------------------------------------------------------
-- The screens fit

-- Every screen and panel at pWidth x pHeight: on the window, the buttons
-- apart and big enough to tap, the squares and tiles on the window, the
-- words of each field whole
private command checkLayout pWidth, pHeight
   local tCard, tScreen, tBad, tName, tField, tLines, tRect
   windowSize pWidth, pHeight
   if the width of stack kStack is not pWidth or the height of stack kStack is not pHeight then
      TestSkip "at" && pWidth & "x" & pHeight, "the window could not be made that size here"
      exit checkLayout
   end if
   put 0, 0, pWidth, pHeight into tCard
   repeat for each item tScreen in "home,numbers 9,numbers 4,words 6,words 4,stickers,practice,howto,settings,done"
      switch word 1 of tScreen
         case "home"
            game "paGoHome"
            break
         case "numbers"
            game "paGoHome"
            game "paStartNumbers", word 2 of tScreen, false
            game "paShowScreen", "numbers"
            break
         case "words"
            game "paGoHome"
            game "paStartWords", word 2 of tScreen, false
            game "paShowScreen", "words"
            break
         case "stickers"
            game "paShowStickers"
            break
         case "done"
            game "paGoHome"
            game "paStartWords", 5, false, "plant"
            game "paShowScreen", "words"
            type1 "plant"
            break
         default
            game "paGoHome"
            game "paOpenPanel", tScreen
      end switch
      if st("panel") is empty then
         put word 1 of tScreen into tName
         put toUpper(char 1 of tName) & char 2 to -1 of tName into tName
      else
         put st("panel") into tName
         put toUpper(char 1 of tName) & char 2 to -1 of tName into tName
      end if
      put tScreen & ":" && checkGroup(tName, tCard) into tBad
      if tName is "Numbers" then
         put "N Cell 1,N Cell" && (word 2 of tScreen) ^ 2 & ",N Message" into tRect
         repeat for each item tField in tRect
            if not isInside(the rect of field tField of stack kStack, tCard) then
               put tField && "off the window;" after tBad
            end if
         end repeat
      end if
      if tName is "Words" then
         repeat for each item tField in "W Slot 1,W Slot" && 6 * word 2 of tScreen
            if not isInside(the rect of graphic tField of stack kStack, tCard) then
               put tField && "off the window;" after tBad
            end if
         end repeat
      end if
      TestAssert "at" && pWidth & "x" & pHeight & "," && tBad, tBad is (tScreen & ":" & space)
   end repeat
   -- the words of the screens show every line whole, with room above and
   -- below them
   put empty into tBad
   repeat for each item tName in "Home Streak,Practice Text,Howto Numbers,Howto Words,Howto Daily,Credits,Done Meaning,Done Note"
      put the long id of field tName of stack kStack into tField
      if not the visible of tField then
         next repeat
      end if
      put the number of lines of the formattedText of tField into tLines
      if the height of tField < tLines * the effective textHeight of tField then
         put tName && "is shorter than its" && tLines && "lines;" after tBad
      end if
      if the topMargin of tField < 4 or the bottomMargin of tField < 4 then
         put tName && "has no room above or below its lines;" after tBad
      end if
   end repeat
   TestAssert "at" && pWidth & "x" & pHeight & ": the words show whole" && tBad, tBad is empty
end checkLayout

-- What is wrong with a group's buttons: off the window, too small to
-- tap, or on each other (each button's face over its shape)
private function checkGroup pGroup, pCard
   local tGroup, i, tName, tRect, tRects, tBad, j
   put the long id of group pGroup of card "Almanac" of stack kStack into tGroup
   repeat with i = 1 to the number of buttons of tGroup
      put the short name of button i of tGroup into tName
      if there is a graphic (tName && "Shape") of card "Almanac" of stack kStack and the visible of button i of tGroup then
         put the rect of button i of tGroup into tRect
         if not isInside(tRect, pCard) then
            put tName && "off the window;" after tBad
         end if
         if item 4 of tRect - item 2 of tRect < 34 then
            put tName && "too small to tap;" after tBad
         end if
         put tName & tab & tRect & return after tRects
      end if
   end repeat
   set the itemDelimiter to tab
   repeat with i = 1 to the number of lines of tRects
      repeat with j = i + 1 to the number of lines of tRects
         if overlap(item 2 of line i of tRects, item 2 of line j of tRects) then
            put item 1 of line i of tRects && "on" && item 1 of line j of tRects & ";" after tBad
         end if
      end repeat
   end repeat
   set the itemDelimiter to comma
   if tRects is empty then
      put "no buttons;" after tBad
   end if
   return tBad
end checkGroup

on TestTheScreensFitAPhone
   checkLayout 390, 760
   checkLayout 320, 568
end TestTheScreensFitAPhone

on TestTheScreensFitAPhoneOnItsSide
   checkLayout 844, 390
   TestAssert "two parts side by side", st("side") is true
end TestTheScreensFitAPhoneOnItsSide

on TestTheScreensFitAWindow
   checkLayout 1024, 700
   checkLayout 768, 1024
end TestTheScreensFitAWindow

-- The tiles are one size on Home and How to play, another in Hidden Word
on TestEachScreenDrawsTheTilesItsSize
   windowSize 390, 760
   if the width of stack kStack is not 390 then
      TestSkip "the tiles' sizes", "the window could not be made that size here"
      exit TestEachScreenDrawsTheTilesItsSize
   end if
   game "paGoHome"
   TestAssert "Home's", the width of image "tile-gold" of card "Art" of stack kStack is st("hometile")
   press "Words Card"
   TestAssert "Hidden Word's", the width of image "tile-gold" of card "Art" of stack kStack is st("tile") and \
         st("tile") > st("hometile")
   TestAssert "a tile on its slot", \
         abs(item 1 of the loc of button "W Tile 1" of stack kStack - item 1 of the loc of graphic "W Slot 1" of stack kStack) <= 1 and \
         abs(item 2 of the loc of button "W Tile 1" of stack kStack - item 2 of the loc of graphic "W Slot 1" of stack kStack) <= 1
   press "Back"
   TestAssert "Home's again", the width of image "tile-gold" of card "Art" of stack kStack is st("hometile")
end TestEachScreenDrawsTheTilesItsSize
