script "oxt_field_speed_test"
-- Times what a Sudoku stack does with its fields, with a user interface:
-- 81 small fields in 3x3 boxes, each holding a digit or the candidates
-- "1 2 3 4 5 6 7 8 9", filled with their text size, style and colour, the
-- candidates pruned group by group, and a puzzle solved by backtracking on
-- the fields themselves, reading all 243 cells of the rows, columns and
-- boxes after every guess. A Mac user's stack that does this froze the
-- macOS IDE of 0.2.3 while OpenXTalk Lite 1.15 ran it quickly; this
-- builds a stack of the same shape (its own code, not that stack) so that
-- the time each step takes can be compared between engines and platforms.
--
-- Like tools/ci/render-test.livecodescript, it runs as the development
-- engine's home stack: copied to <folder>/Startup.rev with REV_TOOLS_PATH
-- set to <folder> (tools/ci/field_speed_test.py does this). Every use of
-- syntax newer than OpenXTalk Lite 1.15 is inside "do".
--
-- Environment variables:
--    OXT_SPEED_OUT         folder for speed.txt (required)
--    OXT_SPEED_APPEARANCE  what to set the appAppearance to first (light,
--                          dark or system); empty leaves the default
--    OXT_SPEED_FONT        the text font of the large puzzle field; empty
--                          for "Atkinson Hyperlegible Mono VF Bold", the
--                          font of that user's stack
--    OXT_SPEED_SOLVE_MS    how long the solve may run (default 20000)
--
-- speed.txt has one line per result, separated by tabs:
--    INFO    name  value
--    RESULT  step  milliseconds  count  milliseconds per count
-- When the solve starts the script writes <OXT_SPEED_OUT>/solving, for a
-- profiler to start. Exit code 0 when every step ran, 3 on a script error.

constant kStack = "oxt_field_speed"
-- Arto Inkala's 2012 puzzle, rows from the top, "-" for an empty cell
constant kPuzzle = "8--------|--36-----|-7--9-2--|-5---7---|----457--|---1---3-|--1----68|--85---1-|-9----4--"
constant kCandidates = "1 2 3 4 5 6 7 8 9"

local sOut
local sSolveMs
local sDeadline
local sStopped
local sSolved
local sGuesses
local sStarted

on startup
   put true into sStarted
   runSpeedTest
   if the result is not empty then quit the result
   quit 0
end startup

-- Opened in the IDE (tools/ci/field_speed_test.py --ide sends the IDE an
-- open document event for this file): the same steps once the IDE has
-- opened it. The IDE is left running; the driver ends it.
on openStack
   if sStarted or the short name of the target is not the short name of me then pass openStack
   put true into sStarted
   send "runSpeedTest" to me in 1 second
   pass openStack
end openStack

-- Empty when every step ran, otherwise the exit code
command runSpeedTest
   put $OXT_SPEED_OUT into sOut
   replace "\" with "/" in sOut
   if the last char of sOut is "/" then delete the last char of sOut
   if sOut is empty then
      write "OXT_SPEED_OUT is not set" & return to stdout
      return 2
   end if
   if there is not a folder sOut then create folder sOut
   put empty into url ("binfile:" & sOut & "/speed.txt")
   put $OXT_SPEED_SOLVE_MS into sSolveMs
   if sSolveMs is not an integer then put 20000 into sSolveMs

   try
      describeEngine
      buildStack
      timeSteps
      addRecord "INFO", "done", "true"
   catch tError
      addRecord "ERROR", "script", oneLine(tError)
      return 3
   end try
   return empty
end runSpeedTest

on errorDialog pError
   addRecord "ERROR", "errorDialog", oneLine(pError)
   quit 3
end errorDialog

private command describeEngine
   local tValue, tError, tRequested
   addRecord "INFO", "version", the version & " build " & the buildNumber
   addRecord "INFO", "environment", the environment
   addRecord "INFO", "platform", the platform & " " & the systemVersion & " " & the processor
   addRecord "INFO", "systemAppearance", the systemAppearance
   put $OXT_SPEED_APPEARANCE into tRequested
   try
      if tRequested is not empty then
         do "set the appAppearance to " & quote & tRequested & quote
      end if
      do "put the effective appAppearance into tValue"
      addRecord "INFO", "effectiveAppAppearance", tValue
   catch tError
      addRecord "INFO", "effectiveAppAppearance", "(no appAppearance)"
   end try
end describeEngine

-- The stack: a group of nine box outlines, the 81 cells B1 to B81 in box
-- order (B1 to B9 are the top left box, left to right, top to bottom), a
-- large opaque threeD field for the puzzle text, buttons and a group of
-- radio buttons
private command buildStack
   local tFont, tBox, tIndex, tLeft, tTop
   put $OXT_SPEED_FONT into tFont
   if tFont is empty then put "Atkinson Hyperlegible Mono VF Bold" into tFont

   lock screen
   create invisible stack kStack
   set the defaultStack to kStack
   set the rect of stack kStack to 151,110,1136,822
   create group "Squares"
   repeat with tBox = 0 to 8
      put (tBox mod 3) * 150 + 74 into tLeft
      put (tBox div 3) * 150 + 74 into tTop
      create graphic ("Box" & tBox + 1) in group "Squares"
      set the style of it to "rectangle"
      set the rect of it to tLeft, tTop, tLeft + 150, tTop + 150
      set the lineSize of it to 4
   end repeat
   repeat with n = 1 to 81
      put (n - 1) div 9 into tBox
      put (n - 1) mod 9 into tIndex
      put (tBox mod 3) * 150 + (tIndex mod 3) * 50 + 75 into tLeft
      put (tBox div 3) * 150 + (tIndex div 3) * 50 + 75 into tTop
      create field ("B" & n)
      set the rect of it to tLeft, tTop, tLeft + 50, tTop + 50
      set the showBorder of it to true
      set the borderWidth of it to 2
      set the opaque of it to false
      set the textAlign of it to "center"
      set the lockText of it to true
   end repeat
   create field "Puzzle"
   set the rect of it to 602,106,900,480
   set the threeD of it to true
   set the opaque of it to true
   set the textFont of it to tFont
   set the textSize of it to 32
   set the textAlign of it to "center"
   put kPuzzle into tLeft
   replace "|" with return in tLeft
   put tLeft into fld "Puzzle"
   addRecord "INFO", "puzzleFieldFont", the effective textFont of fld "Puzzle"
   addRecord "INFO", "cellFont", the effective textFont of fld "B1"
   makeButton "Solve!", "231,552,347,613", 32
   makeButton "New Puzzle", "661,493,853,545", 24
   makeButton "Check Progress", "409,552,525,613", 18
   makeButton "Hint", "76,552,192,613", 18
   create group "Difficulty"
   set the radioBehavior of it to true
   put 607 into tLeft
   repeat for each item tName in "Easy,Medium,Hard,Spicy"
      create button tName in group "Difficulty"
      set the style of it to "radioButton"
      set the rect of it to tLeft, 550, tLeft + 70, 573
      add 72 to tLeft
   end repeat
   unlock screen
end buildStack

private command makeButton pName, pRect, pSize
   create button pName
   set the rect of it to pRect
   set the textSize of it to pSize
end makeButton

private command timeSteps
   local t0, tScript, tCell, tDigit, tX

   -- Showing it
   put the milliseconds into t0
   show stack kStack
   wait 0 milliseconds with messages
   addResult "open", the milliseconds - t0, 1

   -- Filling the cells and pruning the candidates, with the screen
   -- unlocked, as a card's openCard would; then drawing it
   put the milliseconds into t0
   fillCells
   pruneAll
   put the milliseconds - t0 into tScript
   addResult "fill-and-prune", tScript, 1
   put the milliseconds into t0
   wait 0 milliseconds with messages
   addResult "draw-after-fill", the milliseconds - t0, 1

   lock screen
   put the milliseconds into t0
   repeat 2000 times
      put fld "B1" into tX
   end repeat
   addResult "read-cell", the milliseconds - t0, 2000

   put firstOpenCell() into tCell
   put fld ("B" & tCell) into tX
   put the milliseconds into t0
   repeat with i = 1 to 1000
      if i mod 2 is 1 then
         put 5 into fld ("B" & tCell)
      else
         put empty into fld ("B" & tCell)
      end if
   end repeat
   addResult "write-cell", the milliseconds - t0, 1000
   put tX into fld ("B" & tCell)

   put the milliseconds into t0
   repeat with i = 1 to 200
      if i mod 2 is 1 then
         set the textSize of fld ("B" & tCell) to 36
      else
         set the textSize of fld ("B" & tCell) to 12
      end if
   end repeat
   addResult "set-text-size", the milliseconds - t0, 200

   put the milliseconds into t0
   repeat 100 times
      get boardIsValid()
   end repeat
   addResult "check-board-locked", the milliseconds - t0, 100

   put the milliseconds into t0
   repeat with i = 1 to 100
      get tryDigit(tCell, (i mod 9) + 1)
   end repeat
   addResult "try-digit-locked", the milliseconds - t0, 100
   unlock screen

   put the milliseconds into t0
   repeat with i = 1 to 30
      get tryDigit(tCell, (i mod 9) + 1)
   end repeat
   addResult "try-digit-unlocked", the milliseconds - t0, 30
   put the milliseconds into t0
   wait 0 milliseconds with messages
   addResult "draw-after-tries", the milliseconds - t0, 1

   -- Solving it on the fields, as the user's stack does after New Puzzle,
   -- for at most sSolveMs
   put empty into url ("binfile:" & sOut & "/solving")
   put 0 into sGuesses
   put false into sSolved
   put false into sStopped
   put the milliseconds + sSolveMs into sDeadline
   lock screen
   put the milliseconds into t0
   solveCells
   addResult "solve-locked", the milliseconds - t0, sGuesses
   unlock screen
   addRecord "INFO", "solved", sSolved
   addRecord "INFO", "solveStoppedAtLimit", sStopped
end timeSteps

-- The cells from the puzzle: a given digit large, bold and red, an empty
-- cell the nine candidates small and black, with a script of its own
private command fillCells
   local tChar, tScript
   put "on mouseUp" & return & "beep" & return & "end mouseUp" into tScript
   repeat with n = 1 to 81
      put puzzleChar(n) into tChar
      if tChar is "-" then
         put kCandidates into fld ("B" & n)
         set the textSize of fld ("B" & n) to 12
         set the textStyle of fld ("B" & n) to "plain"
         set the foregroundColor of fld ("B" & n) to "black"
         set the lockText of fld ("B" & n) to true
         set the script of fld ("B" & n) to tScript
      else
         put tChar into fld ("B" & n)
         set the textSize of fld ("B" & n) to 36
         set the textStyle of fld ("B" & n) to "bold"
         set the foregroundColor of fld ("B" & n) to "red"
         set the lockText of fld ("B" & n) to true
      end if
   end repeat
end fillCells

-- The puzzle's character for cell n in box order
private function puzzleChar n
   local tBox, tIndex, tRow, tCol
   put (n - 1) div 9 into tBox
   put (n - 1) mod 9 into tIndex
   put (tBox div 3) * 3 + tIndex div 3 + 1 into tRow
   put (tBox mod 3) * 3 + tIndex mod 3 + 1 into tCol
   set the itemDelimiter to "|"
   return char tCol of item tRow of kPuzzle
end puzzleChar

private command pruneAll
   repeat with i = 1 to 9
      pruneGroup boxCells(i)
      pruneGroup rowCells(i)
      pruneGroup colCells(i)
   end repeat
end pruneAll

-- Takes the digits of the group's solved cells out of its other cells'
-- candidates; a cell left with one becomes a solved cell (bold and navy)
private command pruneGroup pCells
   local tDigits, tText
   repeat for each item tCell in pCells
      put the text of fld ("B" & tCell) into tText
      if the length of tText is 1 then put tText after tDigits
   end repeat
   if tDigits is empty then exit pruneGroup
   repeat for each item tCell in pCells
      put the text of fld ("B" & tCell) into tText
      if the length of tText > 1 then
         repeat for each char tChar in tDigits
            replace tChar with empty in tText
         end repeat
         replace space with empty in tText
         if the length of tText is 1 then
            set the text of fld ("B" & tCell) to tText
            set the textStyle of fld ("B" & tCell) to "bold"
            set the textSize of fld ("B" & tCell) to 36
            set the foregroundColor of fld ("B" & tCell) to "navy"
         else
            set the text of fld ("B" & tCell) to tText
         end if
      end if
   end repeat
end pruneGroup

private function boxCells pBox
   local tCells
   repeat with i = 1 to 9
      put (pBox - 1) * 9 + i & comma after tCells
   end repeat
   delete the last char of tCells
   return tCells
end boxCells

private function rowCells pRow
   local tCells, tBox
   repeat with tBoxCol = 0 to 2
      put ((pRow - 1) div 3) * 3 + tBoxCol into tBox
      repeat with tCol = 0 to 2
         put tBox * 9 + ((pRow - 1) mod 3) * 3 + tCol + 1 & comma after tCells
      end repeat
   end repeat
   delete the last char of tCells
   return tCells
end rowCells

private function colCells pCol
   local tCells, tBox
   repeat with tBoxRow = 0 to 2
      put tBoxRow * 3 + (pCol - 1) div 3 into tBox
      repeat with tRow = 0 to 2
         put tBox * 9 + tRow * 3 + ((pCol - 1) mod 3) + 1 & comma after tCells
      end repeat
   end repeat
   delete the last char of tCells
   return tCells
end colCells

-- Whether a group has a digit twice, read from its fields
private function groupHasRepeat pCells
   local tSeen, tValue
   repeat for each item tCell in pCells
      if there is a fld ("B" & tCell) then
         put fld ("B" & tCell) into tValue
         if the length of tValue is 1 and tValue is a number then
            if tValue is among the items of tSeen then return true
            put tValue & comma after tSeen
         end if
      end if
   end repeat
   return false
end groupHasRepeat

private function boardIsValid
   repeat with i = 1 to 9
      if groupHasRepeat(rowCells(i)) then return false
      if groupHasRepeat(colCells(i)) then return false
      if groupHasRepeat(boxCells(i)) then return false
   end repeat
   return true
end boardIsValid

-- Puts the digit in the cell, checks the whole board and puts the cell
-- back as it was
private function tryDigit pCell, pDigit
   local tWas, tValid
   put fld ("B" & pCell) into tWas
   put pDigit into fld ("B" & pCell)
   put boardIsValid() into tValid
   put tWas into fld ("B" & pCell)
   add 1 to sGuesses
   return tValid
end tryDigit

private function firstOpenCell
   repeat with n = 1 to 81
      if fld ("B" & n) is empty or the length of fld ("B" & n) > 1 then return n
   end repeat
   return empty
end firstOpenCell

private command solveCells
   local tCell
   if the milliseconds > sDeadline then
      put true into sStopped
      exit solveCells
   end if
   put firstOpenCell() into tCell
   if tCell is empty then
      put true into sSolved
      exit solveCells
   end if
   repeat with tDigit = 1 to 9
      if tryDigit(tCell, tDigit) then
         put tDigit into fld ("B" & tCell)
         solveCells
         if sSolved or sStopped then exit solveCells
         put empty into fld ("B" & tCell)
      end if
   end repeat
end solveCells

private command addResult pStep, pMs, pCount
   local tPer
   if pCount > 0 then
      put format("%.3f", pMs / pCount) into tPer
   end if
   addRecord "RESULT", pStep, pMs, pCount, tPer
end addResult

-- Any parameters after pValue are further fields
private command addRecord pKind, pName, pValue
   local tLine
   put pKind & tab & pName & tab & oneLine(pValue) into tLine
   repeat with i = 4 to the paramCount
      put tab & param(i) after tLine
   end repeat
   put tLine & return after url ("file:" & sOut & "/speed.txt")
end addRecord

private function oneLine pText
   replace return with " " in pText
   replace numToCodepoint(13) with " " in pText
   replace tab with " " in pText
   return pText
end oneLine
