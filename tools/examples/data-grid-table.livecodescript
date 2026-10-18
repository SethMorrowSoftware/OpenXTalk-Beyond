script "OXTExampleDataGridTable"
-- OXT-Beyond: builds "Data Grid Tables", the remaster of Terry Little's
-- DataGrid Table v1.0 (2022, GPL 3 or later), which is in
-- ide/Resources/Examples/DataGrid Table.oxtstack and stays there as he
-- made it.
--
-- His stack teaches the data grid table in five lessons on four cards: a
-- table to edit by hand and with code (two buttons and a field), the line
-- a click selects, a column whose numbers turn red, a column to add in the
-- Inspector, a grid of your own, a card to copy and paste, and a field made
-- into a table, to compare. The remaster keeps his programs, his notes and
-- his lesson plan, in the window every remastered example has
-- (builder.livecodescript). Each lesson is a wide card: its grid and the
-- things to try at the left of the stage, his notes at the right (the
-- field "Info", in a background group, as his was), and the scripts in the
-- drawer. What changed:
--
--    - lessons 3 and 4 shared a card: each has its own now, and lesson 4's
--      has a grid to copy (his lesson 3 example, Fruit and Tree), so that
--      it works when lesson 3 was skipped;
--    - his < Prev and Next > buttons are the window's Back and Next; the
--      line of their scripts that put the notes back at the top is in the
--      stack script's preOpenCard;
--    - his Lesson Plan button wrote a file on the desktop: the lesson plan
--      tile on the front page copies the plan, or saves it where you say;
--    - a click on a line of lesson 1's grid shows the line under the grid,
--      as well as in the message box; and on lessons 2, 4 and 5 the lines
--      his notes have you type in the message box are in a list to click
--      (the field "Try It"), which runs them as the message box would;
--    - the closeField handler of field "Table 1" declares i (strict
--      compilation), and a few words of his notes are mended or added
--      (lessonText, each with its reason);
--    - added: the wheel scrolls his notes (with a slim thumb, as the
--      scripts panel has), and code is shown in the scripts panel's font
--      (the stack script's preOpenCard).
--
-- His notes, the grids' data, the Display field's text, field "Table 1"
-- and the lesson plan are read from his stack when this one is built. The
-- grids are made as the IDE makes them (a copy of the data grid library's,
-- with a row template on a substack, and the "Num" column's template and
-- behavior as the Inspector's "+" makes them), and so they need the data
-- grid library loaded: in the IDE it is, and here this builder loads it
-- from the checkout's Toolset (or OXT_INSTALL's), as the IDE does.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kStageLeft = 256
constant kStageTop = 104
constant kStageRight = 1000
constant kStageBottom = 616
-- A lesson's stage: the things to try at the left, and the notes from
-- kSplit to the right, where the scripts drawer opens over them
constant kSplit = 616
constant kPlayLeft = 272
constant kPlayRight = 584
-- The lessons' cards, in order
constant kLessons = "Lesson 1,Lesson 2,Lesson 3,Lesson 4,Lesson 5"
-- The data grids' templates substack (the IDE names one so, and finds it
-- by that name when a grid is added to the stack)
constant kTemplates = "Data Grid Templates 2026101802"

-- The row template of the grid made last, from gridNew
local sRowTemplate
-- Terry's stack, read when the build starts: his notes by lesson (a
-- heading's line begins with "@@"), the Display field's text, field
-- "Table 1" as htmlText and his lesson plan; his grids' columns, sort
-- column, data and column properties, by his card's number
local sOrig, sGridData, sColumnProps

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   -- (four icons Learn's kit does not have, from Lucide)
   exAddIcon "arrow-down", "<path d='M12 5v14'/><path d='m19 12-7 7-7-7'/>"
   exAddIcon "arrow-up", "<path d='m5 12 7-7 7 7'/><path d='M12 19V5'/>"
   exAddIcon "arrow-up-down", "<path d='m21 16-4 4-4-4'/><path d='M17 20V4'/><path d='m3 8 4-4 4 4'/><path d='M7 4v16'/>"
   exAddIcon "columns-3", "<rect width='18' height='18' x='3' y='3' rx='2'/><path d='M9 3v18'/><path d='M15 3v18'/>"
   gridLibrary
   readOriginal
   put "Data Grid Tables" into tInfo["name"]
   put "after Terry Little, 2022" into tInfo["credit"]
   put "sheet" into tInfo["icon"]
   put lkColor("emerald") into tInfo["accent"]
   put lkColor("teal") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Data Grid Tables|Terry Little's five lessons on the data grid table, and a field table to compare.|sheet|front" & return & \
         "Lesson 1|A Data Grid Table|Edit a table by hand and with code, read the line you click, and color its numbers.|table|wide" & return & \
         "Lesson 2|Add a Column|Give the table a third column in its Inspector, and try its properties in code.|columns-3|wide" & return & \
         "Lesson 3|Make Your Own|Drag a data grid from the Tools palette onto this card, and fill it in.|pencil|wide" & return & \
         "Lesson 4|Paste a Data Grid|Copy this card and paste it: the copy has a data grid of its own.|clipboard-copy|wide" & return & \
         "Lesson 5|A Field Table|A scrolling field made into a table, with a color rule of its own.|text-cursor-input|wide" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   gridTemplates the short name of tStack
   buildFront
   buildNotes
   buildLesson1
   buildLesson2
   buildLesson3
   buildLesson4
   buildLesson5
   go card 1
   unlock messages
   put exCheck(tStack) & exCheck(kTemplates) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Data Grid Tables.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

-- Terry's stack, read and then unloaded (its file stays as it is): the
-- notes of each card, a bold line marked as a heading; his two grids'
-- columns, sort column, data and column properties; the Display field;
-- field "Table 1"; the lesson plan of his Lesson Plan button
private command readOriginal
   local tRepo, tOriginal, tLocked, tCard, tField, tText, tIndex, tGrid, tCache
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put tRepo & "/ide/Resources/Examples/DataGrid Table.oxtstack" into tOriginal
   if there is no file tOriginal then
      throw "cannot find Terry Little's stack at " & tOriginal
   end if
   put the lockMessages into tLocked
   lock messages
   get the name of stack tOriginal
   repeat with tCard = 1 to 4
      put the text of field "Info" of card tCard of stack tOriginal into tField
      put empty into tText
      repeat with tIndex = 1 to the number of lines of tField
         if the textStyle of line tIndex of field "Info" of card tCard of stack tOriginal is "bold" then
            put "@@" after tText
         end if
         put line tIndex of tField & return after tText
      end repeat
      put tText into sOrig["notes" & tCard]
   end repeat
   repeat with tCard = 1 to 2
      put the long id of group "DataGrid 1" of card tCard of stack tOriginal into tGrid
      put the dgProps["columns"] of tGrid into sOrig["columns" & tCard]
      put the dgProps["sort by column"] of tGrid into sOrig["sort" & tCard]
      put the dgProps["column properties"] of tGrid into sColumnProps[tCard]
      put the customProperties["dgCache"] of tGrid into tCache
      put tCache["data"] into sGridData[tCard]
      if sGridData[tCard] is not an array then
         throw "cannot read the data of the grid on card " & tCard
      end if
   end repeat
   put the text of field "Display" of card 1 of stack tOriginal into sOrig["display"]
   put the htmlText of field "Table 1" of card 4 of stack tOriginal into sOrig["table1"]
   put the cLessonPlan of button "Lesson Plan" of card 1 of stack tOriginal into sOrig["plan"]
   delete stack tOriginal
   set the lockMessages to tLocked
end readOriginal

-- A lesson's notes, as Terry wrote them, but for the few words this
-- window changes, each with its reason. His third card held lessons 3 and
-- 4, with a line of dashes between them
private function lessonText pLesson
   local tText, tCut
   if pLesson is 3 or pLesson is 4 then
      put sOrig["notes3"] into tText
      put lineOffset(return & "----" & return, return & tText & return) into tCut
      if tCut is 0 then
         throw "Terry's lesson 3 and 4 notes have no line of dashes between them"
      end if
      if pLesson is 3 then
         put line 1 to tCut - 1 of tText into tText
      else
         put line tCut + 1 to -1 of tText into tText
      end if
   else if pLesson is 5 then
      put sOrig["notes4"] into tText
   else
      put sOrig["notes" & pLesson] into tText
   end if
   switch pLesson
      case 1
         -- (the drawer shows the scripts on the card: the notes say so)
         textChange tText, "Object > Object Script." & return & return & "@@Hilited Line", \
               "Object > Object Script. Or open Scripts, at the top right of this window." & return & return & "@@Hilited Line"
         textChange tText, "select the dg Table, Object > Object Script.", \
               "select the dg Table, Object > Object Script. Or open Scripts, at the top right."
         -- (the line shows under the grid as well)
         textChange tText, "to extract that line of data to the message box.", \
               "to extract that line of data to the message box. It shows under the grid too."
         break
      case 2
         -- (a slip of the keys)
         textChange tText, "You make get lucky.", "You may get lucky."
         -- (the lines to try are on the card, to click)
         textChange tText, "@@DataGrid Table Tips", "@@DataGrid Table Tips" & return & \
               "Some of these lines are on the card, under the grid: click one to run it."
         break
      case 4
         -- (the window's lesson 4 is a card of its own, and the copy goes
         -- after it)
         textChange tText, "duplicated on a new 4th card.", "duplicated on a new card, after this one."
         put return & return & "The copy has no line of its own in the list at the left: Next goes to it. " & \
               "To delete it, go to it and type in the message box: delete this card" after tText
         break
      case 5
         -- (vScroll is how far down a field is scrolled: the property that
         -- hides its scrollbar is vScrollbar)
         textChange tText, "set the vScroll of fld " & quote & "Table 1" & quote & " to " & quote & "false" & quote, \
               "set the vScrollbar of fld " & quote & "Table 1" & quote & " to " & quote & "false" & quote
         -- (the field is named "Table 1")
         textChange tText, "of line 1 of fld " & quote & "Table" & quote & " to", \
               "of line 1 of fld " & quote & "Table 1" & quote & " to"
         break
   end switch
   -- (no empty lines at the end)
   repeat while the number of lines of tText > 0 and word 1 to -1 of line -1 of tText is empty
      delete line -1 of tText
   end repeat
   return tText
end lessonText

-- Replaces pFrom with pTo in a lesson's text: if his text no longer has
-- pFrom, the build stops, so that the change is looked at again
private command textChange @pText, pFrom, pTo
   if pFrom is not in pText then
      throw "Terry's notes no longer have " & quote & pFrom & quote
   end if
   replace pFrom with pTo in pText
end textChange

################################################################################
#
# The cards
#

-- The front page: what this is, a tile for each lesson and the lesson
-- plan's, and what the lessons teach
private command buildFront
   local tObj, tTop, tWidth, tIndex, tIcons, tTitles, tTexts, tCodes, tX, tY
   go card "Start"
   exHero lkR(kStageLeft, kStageTop, kStageRight, 272), lkColor("teal") & "|" & lkColor("emerald"), \
         "TERRY LITTLE, 2022  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "Five lessons on the data grid table", \
         "A data grid shows data in a table that people can sort and edit. Terry Little's lessons fill " & \
         "one by hand and with code, read the line you click, color its numbers, make one of your own " & \
         "and copy it, then compare a table made of a field."
   exProgramTiles 288, 3, 60, 12
   -- The sixth tile: Terry's lesson plan, for teachers
   put (kStageRight - kStageLeft - 2 * 12) div 3 into tWidth
   put kStageLeft + 2 * (tWidth + 12) into tX
   put 288 + 60 + 12 into tY
   get lkGroup("Lesson Plan", lkR(tX, tY, tX + tWidth, tY + 60), empty)
   put lkBox("Lesson Plan_bg", lkR(tX, tY, tX + tWidth, tY + 60), "255,255,255", 14, "Lesson Plan") into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 10, 2, 8
   put lkBox("Lesson Plan_iconBg", lkR(tX + 12, tY + 12, tX + 52, tY + 48), lkMix("255,255,255", lkColor("teal"), 0.14), 12, "Lesson Plan") into tObj
   get exIcon("Lesson Plan_icon", "graduation-cap", lkColor("teal"), lkR(tX + 22, tY + 20, tX + 42, tY + 40), "Lesson Plan")
   put lkLabel("Lesson Plan_word", lkR(tX + 64, tY + 13, tX + tWidth - 8, tY + 27), "FOR TEACHERS", 11, lkColor("muted"), "Lesson Plan") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Lesson Plan_title", lkR(tX + 64, tY + 29, tX + tWidth - 8, tY + 49), "The Lesson Plan", 14, lkColor("ink"), "Lesson Plan") into tObj
   set the textStyle of tObj to "bold"
   set the cRest of group "Lesson Plan" to "255,255,255"
   set the cLit of group "Lesson Plan" to lkMix("255,255,255", lkColor("teal"), 0.07)
   set the script of group "Lesson Plan" to exScript("Start/Lesson Plan")
   set the cLessonPlan of group "Lesson Plan" to sOrig["plan"]
   -- What the lessons teach, a panel each, with the words they use
   put "arrow-up-down|mouse-pointer-click|palette" into tIcons
   put "Data in, data out|The line you click|Color by value" into tTitles
   put "A table's data is lines of items with a tab between them: dgText puts them into a grid, " & \
         "and takes them out.|" & \
         "dgHilitedLine is the number of the line that is selected, so a click can read that line's " & \
         "data.|" & \
         "A column can have a behavior of its own, which fills each of its cells and can turn " & \
         "a number red from 3 up." into tTexts
   put "the dgText|the dgHilitedLine|on FillInData" into tCodes
   set the itemDelimiter to "|"
   put 436 into tTop
   repeat with tIndex = 1 to 3
      put kStageLeft + (tIndex - 1) * (tWidth + 12) into tX
      get lkGroup("Feature" & tIndex, lkR(tX, tTop, tX + tWidth, kStageBottom), empty)
      put exPanel("Feature" & tIndex & "_bg", lkR(tX, tTop, tX + tWidth, kStageBottom), "Feature" & tIndex) into tObj
      put lkBox("Feature" & tIndex & "_iconBg", lkR(tX + 18, tTop + 18, tX + 54, tTop + 54), \
            lkMix("255,255,255", lkColor("emerald"), 0.14), 11, "Feature" & tIndex) into tObj
      get exIcon("Feature" & tIndex & "_icon", item tIndex of tIcons, lkColor("emerald"), \
            lkR(tX + 26, tTop + 26, tX + 46, tTop + 46), "Feature" & tIndex)
      put lkLabel("Feature" & tIndex & "_title", lkR(tX + 66, tTop + 26, tX + tWidth - 12, tTop + 48), \
            item tIndex of tTitles, 15, lkColor("ink"), "Feature" & tIndex) into tObj
      set the textStyle of tObj to "bold"
      put lkLabel("Feature" & tIndex & "_text", lkR(tX + 18, tTop + 66, tX + tWidth - 16, tTop + 130), \
            item tIndex of tTexts, 12, lkColor("soft"), "Feature" & tIndex) into tObj
      set the fixedLineHeight of tObj to true
      set the textHeight of tObj to 18
      get codeChip("Feature" & tIndex & "_code", item tIndex of tCodes, tX + 18, tTop + 140, "Feature" & tIndex)
   end repeat
   set the itemDelimiter to comma
end buildFront

-- A word of code on a soft chip, its left edge at pLeft; returns its width
private function codeChip pName, pWord, pLeft, pTop, pGroup
   local tObj, tLabel, tWidth
   put lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + 200, pTop + 24), \
         lkMix("255,255,255", lkColor("emerald"), 0.12), 12, pGroup) into tObj
   put lkLabel(pName, lkR(pLeft + 10, pTop + 4, pLeft + 300, pTop + 22), pWord, 12, \
         lkMix(lkColor("emerald"), lkColor("ink"), 0.35), pGroup) into tLabel
   set the textFont of tLabel to measureFace()
   set the dontWrap of tLabel to true
   put the formattedWidth of tLabel + 20 into tWidth
   codeFont tLabel
   set the rect of tObj to pLeft, pTop, pLeft + tWidth, pTop + 24
   -- (the word in the middle of its chip, up and down)
   set the rect of tLabel to pLeft + 10, pTop + 12 - (the formattedHeight of tLabel + 4) div 2, pLeft + tWidth - 6, \
         pTop + 12 - (the formattedHeight of tLabel + 4) div 2 + the formattedHeight of tLabel + 4
   return tWidth
end codeChip

-- Terry's notes, at the right of each lesson's stage: the field "Info" in
-- the group "Notes", a background, as his was in the group "Nav" (so it
-- has a text of its own on each card). The stack script scrolls it with
-- the wheel, and moves its thumb
private command buildNotes
   local tObj, tIndex, tBreak, tWord
   go card (item 1 of kLessons)
   get lkGroup("Notes", lkR(kSplit, kStageTop, kStageRight, kStageBottom), empty)
   set the backgroundBehavior of group "Notes" to true
   -- (the first control made in a group goes to its top left: this one
   -- is already there)
   get lkBox("notesAnchor", lkR(kSplit, kStageTop, kSplit + 1, kStageTop + 1), empty, 0, "Notes")
   put lkBox("notesRule", lkR(kSplit, kStageTop + 24, kSplit + 1, kStageBottom - 24), lkColor("line"), 0, "Notes") into tObj
   get exIcon("notesIcon", "book-open", lkColor("emerald"), lkR(kSplit + 24, 124, kSplit + 40, 140), "Notes")
   put lkLabel("notesWord", lkR(kSplit + 48, 125, kStageRight - 24, 140), "LESSON NOTES", 11, lkColor("muted"), "Notes") into tObj
   set the textStyle of tObj to "bold"
   set the sharedText of tObj to true
   put lkLabel("Info", lkR(kSplit + 12, 152, kStageRight - 14, kStageBottom - 12), empty, 13, lkColor("soft"), "Notes") into tObj
   set the rect of tObj to kSplit + 12, 146, kStageRight - 14, kStageBottom - 12
   set the margins of tObj to "12,10,14,12"
   -- (the columns of the data he has you write)
   set the tabStops of tObj to 84
   -- (its text can be selected, to copy a line of code)
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   -- (where its foot may go: the stack script's notesFit stops it short of
   -- there, at the foot of the last line that shows whole)
   set the cNotesBottom of tObj to kStageBottom - 12
   put lkBox("notesThumb", lkR(kStageRight - 9, 156, kStageRight - 5, 200), "203,213,225", 2, "Notes") into tObj
   hide tObj
   repeat with tIndex = 2 to the number of items of kLessons
      place group "Notes" of card (item 1 of kLessons) onto card (item tIndex of kLessons)
   end repeat
   repeat with tIndex = 1 to the number of items of kLessons
      set the htmlText of field "Info" of card (item tIndex of kLessons) to notesHtml(lessonText(tIndex), 0)
      -- (a lesson's name too long for one line is made again as two, with
      -- room between them: its lines are as far apart as the notes' own,
      -- which the field fixes for all its lines. Measured on its card,
      -- where the field is laid out)
      go card (item tIndex of kLessons)
      put 0 into tBreak
      repeat with tWord = 2 to the number of words of line 1 of field "Info"
         if item 2 of the formattedRect of word tWord of line 1 of field "Info" > item 2 of the formattedRect of word 1 of line 1 of field "Info" then
            put tWord - 1 into tBreak
            exit repeat
         end if
      end repeat
      if tBreak > 0 then
         set the htmlText of field "Info" of card (item tIndex of kLessons) to notesHtml(lessonText(tIndex), tBreak)
      end if
      -- (the font of the code in them, which the stack script changes to
      -- the scripts panel's when the card opens: see codeFont)
      set the cNotesFace of card (item tIndex of kLessons) to codeFace()
   end repeat
end buildNotes

-- Lesson 1: Terry's grid, the line a click selects, his two buttons and
-- the Display field
private command buildLesson1
   local tObj, tGrid, tWidth, tTop
   go card "Lesson 1"
   caption "GridCaption", "group " & quote & "DataGrid 1" & quote, kPlayLeft, kStageTop + 16
   put gridNew("DataGrid 1", lkR(kPlayLeft, kStageTop + 36, kPlayRight, kStageTop + 208)) into tGrid
   gridReady tGrid, "table"
   gridColumn "Num", exScript("Lesson 1/Num Behavior")
   gridLook tGrid, lkColor("emerald")
   gridFill tGrid, 1, "100,124,86"
   set the script of tGrid to exScript("Lesson 1/DataGrid 1")
   -- What a click puts into the message box, under the grid too
   get messageBox(kPlayLeft, kStageTop + 220, kPlayRight, 1, "Click a line of the grid above.")
   -- His two buttons
   put kStageTop + 272 into tTop
   put exButton("DG > Text", kPlayLeft, tTop, 34, "DG > Text", "arrow-down", "ghost", lkColor("emerald"), empty, empty, 0) into tWidth
   set the script of group "DG > Text" to exScript("Lesson 1/DG > Text")
   get exButton("Text > DG", kPlayLeft + tWidth + 10, tTop, 34, "Text > DG", "arrow-up", "primary", lkColor("emerald"), empty, empty, 0)
   set the script of group "Text > DG" to exScript("Lesson 1/Text > DG")
   -- The Display field, a line for each line of the table
   put kStageTop + 322 into tTop
   caption "DisplayCaption", "field " & quote & "Display" & quote, kPlayLeft, tTop
   put lkBox("DisplayBox", lkR(kPlayLeft, tTop + 20, kPlayRight, kStageBottom - 16), "255,255,255", 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel("Display", lkR(kPlayLeft + 4, tTop + 26, kPlayRight - 4, kStageBottom - 22), empty, 13, lkColor("ink"), empty) into tObj
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 22
   set the margins of tObj to "10,4,8,4"
   set the tabStops of tObj to "100,224"
   set the text of tObj to sOrig["display"]
end buildLesson1

-- Lesson 2: Terry's second grid, to add a column to, and the lines of his
-- tips to try on it
private command buildLesson2
   local tGrid
   go card "Lesson 2"
   caption "GridCaption", "group " & quote & "DataGrid 1" & quote, kPlayLeft, kStageTop + 16
   put gridNew("DataGrid 1", lkR(kPlayLeft, kStageTop + 36, kPlayRight, kStageTop + 208)) into tGrid
   gridReady tGrid, "table"
   gridLook tGrid, lkColor("emerald")
   gridFill tGrid, 2, "156,154"
   -- (a column added in the Inspector may make the table wider than the grid)
   gridScrolls tGrid
   get tryPanel(kStageTop + 224, "Lesson 2/try", 2)
end buildLesson2

-- Lesson 3: a place for the grid you make, and Terry's data for it, as
-- he has you write it on paper
private command buildLesson3
   local tObj, tTop, tData, tLine, tHtml
   go card "Lesson 3"
   put lkBox("Yours", lkR(kPlayLeft, kStageTop + 16, kPlayRight, kStageTop + 300), \
         lkMix("255,255,255", lkColor("emerald"), 0.03), 16, empty) into tObj
   lkBorder tObj, lkMix("255,255,255", lkColor("emerald"), 0.4)
   set the lineSize of tObj to 2
   set the dashes of tObj to "8,8"
   put lkBox("YoursIconBg", lkR(404, kStageTop + 92, 452, kStageTop + 140), lkMix("255,255,255", lkColor("emerald"), 0.14), 14, empty) into tObj
   get exIcon("YoursIcon", "table", lkColor("emerald"), lkR(416, kStageTop + 104, 440, kStageTop + 128), empty)
   put lkLabel("YoursText", lkR(kPlayLeft + 24, kStageTop + 156, kPlayRight - 24, kStageTop + 286), \
         "Your data grid here" & return & \
         "Drag a data grid from the Tools palette onto this card. It is a table, and its name is " & \
         quote & "DataGrid 1" & quote & ".", 13, lkColor("soft"), empty, "center") into tObj
   set the textStyle of line 1 of tObj to "bold"
   set the textSize of line 1 of tObj to 16
   set the textColor of line 1 of tObj to lkColor("ink")
   -- His data, on paper
   put kStageTop + 316 into tTop
   put exPanel("Paper", lkR(kPlayLeft, tTop, kPlayRight, kStageBottom - 16), empty) into tObj
   put lkLabel("PaperTitle", lkR(kPlayLeft + 18, tTop + 16, kPlayRight - 18, tTop + 34), "On paper first", 14, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("PaperText", lkR(kPlayLeft + 18, tTop + 38, kPlayRight - 18, tTop + 56), \
         "Two columns, with a header each. Something like:", 12, lkColor("soft"), empty) into tObj
   put paperData() into tData
   repeat for each line tLine in tData
      put "<p>" & lkEscape(item 1 of tLine & tab & item 2 of tLine) & "</p>" after tHtml
   end repeat
   put lkLabel("PaperData", lkR(kPlayLeft + 18, tTop + 64, kPlayRight - 18, kStageBottom - 26), empty, 13, lkColor("ink"), empty) into tObj
   codeFont tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 20
   set the tabStops of tObj to 100
   set the htmlText of tObj to tHtml
   set the textStyle of line 1 of tObj to "bold"
   set the textColor of line 1 of tObj to lkMix(lkColor("emerald"), lkColor("ink"), 0.3)
   set the cEmptyText of this card to exScript("Lesson 3/tips")
end buildLesson3

-- Lesson 4: a grid with Terry's lesson 3 data, on a card to copy and
-- paste, and the lines that do it
private command buildLesson4
   local tGrid, tData, tLine, tText, tTop, tObj
   go card "Lesson 4"
   caption "GridCaption", "group " & quote & "DataGrid 1" & quote, kPlayLeft, kStageTop + 16
   put gridNew("DataGrid 1", lkR(kPlayLeft, kStageTop + 36, kPlayRight, kStageTop + 180)) into tGrid
   gridReady tGrid, "table"
   gridLook tGrid, lkColor("emerald")
   gridScrolls tGrid
   put paperData() into tData
   unlock messages
   set the dgProps["columns"] of tGrid to item 1 of line 1 of tData & return & item 2 of line 1 of tData
   set the dgColumnWidth[item 1 of line 1 of tData] of tGrid to 156
   set the dgColumnWidth[item 2 of line 1 of tData] of tGrid to 154
   repeat for each line tLine in tData
      put item 1 of tLine & tab & item 2 of tLine & return after tText
   end repeat
   delete the last char of tText
   set the dgText["true"] of tGrid to tText
   lock messages
   put tryPanel(kStageTop + 196, "Lesson 4/try", 1) into tTop
   -- What the copy is
   put tTop + 16 into tTop
   put exPanel("CopyPanel", lkR(kPlayLeft, tTop, kPlayRight, kStageBottom - 16), empty) into tObj
   put lkBox("CopyIconBg", lkR(kPlayLeft + 16, tTop + 16, kPlayLeft + 52, tTop + 52), \
         lkMix("255,255,255", lkColor("emerald"), 0.14), 11, empty) into tObj
   get exIcon("CopyIcon", "clipboard-copy", lkColor("emerald"), lkR(kPlayLeft + 24, tTop + 24, kPlayLeft + 44, tTop + 44), empty)
   put lkLabel("CopyTitle", lkR(kPlayLeft + 64, tTop + 14, kPlayRight - 16, tTop + 34), "Two cards, two grids", 14, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("CopyText", lkR(kPlayLeft + 64, tTop + 36, kPlayRight - 16, kStageBottom - 26), \
         "The copy comes after this card, with a data grid of its own. Change a word in it, then go back: " & \
         "the grid on this card is as it was.", 12, lkColor("soft"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 18
end buildLesson4

-- Terry's lesson 3 data: the lines after "Something like:" in his notes,
-- a header and its items, two to a line (comma between them)
private function paperData
   local tText, tStart, tLine, tOut
   put lessonText(3) into tText
   put lineOffset("Something like:", tText) into tStart
   if tStart is 0 then
      throw "Terry's lesson 3 notes no longer have their example data"
   end if
   repeat for each line tLine in line tStart + 1 to -1 of tText
      if word 1 to -1 of tLine is empty then
         exit repeat
      end if
      put word 1 of tLine & comma & word 2 to -1 of tLine & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end paperData

-- Lesson 5: Terry's field table, and the lines of his notes to try on it
private command buildLesson5
   local tObj
   go card "Lesson 5"
   caption "TableCaption", "field " & quote & "Table 1" & quote, kPlayLeft, kStageTop + 16
   -- (his properties: dontWrap on, vScrollbar off, vGrid on, tabStops 75,
   -- a light yellow fill and a grey border and grid)
   put lkLabel("Table 1", lkR(kPlayLeft, kStageTop + 40, kPlayLeft + 230, kStageTop + 172), empty, 13, lkColor("ink"), empty) into tObj
   -- (as wide as his three columns of 75, and its margins)
   set the rect of tObj to kPlayLeft, kStageTop + 36, kPlayLeft + 230, kStageTop + 168
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the opaque of tObj to true
   set the backgroundColor of tObj to "255,255,221"
   set the showBorder of tObj to true
   set the threeD of tObj to false
   set the borderWidth of tObj to 1
   set the borderColor of tObj to "192,192,192"
   set the dontWrap of tObj to true
   set the vScrollbar of tObj to false
   set the vGrid of tObj to true
   set the hGrid of tObj to false
   set the tabStops of tObj to 75
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 20
   set the margins of tObj to "6,6,6,6"
   set the htmlText of tObj to sOrig["table1"]
   set the script of tObj to exScript("Lesson 5/Table 1")
   get tryPanel(kStageTop + 184, "Lesson 5/try", 5)
end buildLesson5

-- A small caption above a control: its name, as a script names it
private command caption pName, pText, pLeft, pTop
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pLeft + 320, pTop + 16), pText, 11, lkColor("muted"), empty) into tObj
   codeFont tObj
   set the dontWrap of tObj to true
end caption

-- The message box, on the stage: the field "Message", which shows what a
-- line put into the message box, pLines lines of it. Returns its bottom
private function messageBox pLeft, pTop, pRight, pLines, pText
   local tObj, tBottom
   put pTop + 18 + pLines * 16 into tBottom
   put lkBox("MessageBox", lkR(pLeft, pTop, pRight, tBottom), lkColor("code"), 10, empty) into tObj
   put lkLabel("MessageWord", lkR(pLeft + 12, pTop + 10, pLeft + 44, pTop + 26), "msg", 11, "100,116,139", empty) into tObj
   codeFont tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Message", lkR(pLeft + 48, pTop + 9, pRight - 10, tBottom - 5), pText, 12, lkColor("codeInk"), empty) into tObj
   codeFont tObj
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 16
   -- (a line of the table: its items in columns)
   set the tabStops of tObj to "64,160"
   return tBottom
end messageBox

-- Lines from Terry's notes to run with a click, as the message box runs a
-- line typed into it: the field "Try It" in a panel from pTop down, and
-- the message box under it, pMessageLines lines high. Returns the panel's
-- bottom
private function tryPanel pTop, pKey, pMessageLines
   local tObj, tPanel, tHtml, tLine, tBottom
   put exPanel("TryPanel", lkR(kPlayLeft, pTop, kPlayRight, pTop + 100), empty) into tPanel
   put lkLabel("TryTitle", lkR(kPlayLeft + 16, pTop + 14, kPlayRight - 16, pTop + 32), "Try It", 14, lkMix(lkColor("emerald"), lkColor("ink"), 0.25), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("TryHint", lkR(kPlayLeft + 66, pTop + 15, kPlayRight - 16, pTop + 31), \
         "click a line: it runs as in the message box", 12, lkColor("muted"), empty) into tObj
   set the dontWrap of tObj to true
   repeat for each line tLine in exScript(pKey)
      put "<p bgcolor=" & quote & "#f1f5f9" & quote & " spaceabove=" & quote & "4" & quote & \
            " firstindent=" & quote & "-14" & quote & " leftindent=" & quote & "20" & quote & \
            " rightindent=" & quote & "8" & quote & ">" & codeHtml(tLine) & "</p>" after tHtml
   end repeat
   put lkLabel("Try It", lkR(kPlayLeft + 10, pTop + 40, kPlayRight - 10, pTop + 300), empty, 12, lkColor("ink"), empty) into tObj
   set the margins of tObj to "6,0,6,4"
   set the htmlText of tObj to tHtml
   set the script of tObj to exScript("Try It")
   -- (as tall as its lines, and the message box under it)
   set the textFont of tObj to measureFace()
   set the height of tObj to the formattedHeight of tObj + 4
   codeFont tObj
   set the top of tObj to pTop + 40
   put messageBox(kPlayLeft + 12, the bottom of tObj + 10, kPlayRight - 12, pMessageLines, "Click a line above.") into tBottom
   set the rect of tPanel to kPlayLeft, pTop, kPlayRight, tBottom + 12
   return tBottom + 12
end tryPanel

################################################################################
#
# Terry's notes, in the look of Learn's pages
#

-- His notes as htmlText: the lesson's name large, his bold headings bold,
-- "Try It" in the accent, his lists hanging, and code (and the data he
-- has you write) in the code font on a tinted band. The words are his,
-- and each line stays a line, but for the lesson's name when it is too
-- long for one: pBreak, if not 0, is how many of its words fit on its
-- first
private function notesHtml pText, pBreak
   local tHtml, tLine, tFirst, tData, tSpaces, tIndent, tAccent
   put lkMix(lkColor("emerald"), lkColor("ink"), 0.25) into tAccent
   put true into tFirst
   put false into tData
   set the caseSensitive to true
   repeat for each line tLine in pText
      if char 1 to 2 of tLine is "@@" then
         delete char 1 to 2 of tLine
         if tFirst then
            -- (8 under it, as Learn's pages have; a name of two lines, 4
            -- between them, which the field's fixed line height, made for
            -- the 13 of the notes, did not leave the 18 of the name)
            if pBreak > 0 then
               put "<p>" & htmlFont(lkEscape(word 1 to pBreak of tLine), 18, lkColor("ink"), true) & "</p>" & \
                     "<p spaceabove=" & quote & "4" & quote & " spacebelow=" & quote & "8" & quote & ">" & \
                     htmlFont(lkEscape(word pBreak + 1 to -1 of tLine), 18, lkColor("ink"), true) & "</p>" after tHtml
            else
               put "<p spacebelow=" & quote & "8" & quote & ">" & htmlFont(lkEscape(tLine), 18, lkColor("ink"), true) & "</p>" after tHtml
            end if
         else if tLine begins with "Try It" then
            put "<p>" & htmlFont(lkEscape(tLine), 14, tAccent, true) & "</p>" after tHtml
         else
            put "<p>" & htmlFont(lkEscape(tLine), 15, lkColor("ink"), true) & "</p>" after tHtml
         end if
      else if word 1 to -1 of tLine is empty then
         put false into tData
         put "<p></p>" after tHtml
      else if tData then
         -- (his example data, in columns)
         put "<p bgcolor=" & quote & "#f1f5f9" & quote & " leftindent=" & quote & "6" & quote & "><font face=" & quote & codeFace() & quote & \
               " size=" & quote & "12" & quote & ">" & lkEscape(word 1 of tLine & tab & word 2 to -1 of tLine) & "</font></p>" after tHtml
      else if notesIsCode(tLine) then
         -- (a line too long for the notes goes on below itself, further
         -- in than its own indent, as in the scripts panel)
         put 0 into tSpaces
         repeat while char tSpaces + 1 of tLine is space
            add 1 to tSpaces
         end repeat
         put (tSpaces + 3) * 7 into tIndent
         put "<p bgcolor=" & quote & "#f1f5f9" & quote & " firstindent=" & quote & -tIndent & quote & \
               " leftindent=" & quote & tIndent + 6 & quote & " rightindent=" & quote & "6" & quote & "><font face=" & quote & codeFace() & quote & \
               " size=" & quote & "12" & quote & ">" & codeHtml(tLine) & "</font></p>" after tHtml
      else if char 1 to 2 of tLine is "* " then
         -- (his stars, as bullets)
         put "<p firstindent=" & quote & "-14" & quote & " leftindent=" & quote & "14" & quote & ">" & \
               htmlFont(numToCodepoint(8226), empty, tAccent, true) & " " & lkEscape(char 3 to -1 of tLine) & "</p>" after tHtml
      else if matchText(tLine, "^[A-Z0-9]\) ") then
         put "<p firstindent=" & quote & "-18" & quote & " leftindent=" & quote & "18" & quote & ">" & lkEscape(tLine) & "</p>" after tHtml
      else
         put "<p>" & lkEscape(tLine) & "</p>" after tHtml
      end if
      if tLine ends with "Something like:" then
         put true into tData
      end if
      put false into tFirst
   end repeat
   set the caseSensitive to false
   return tHtml
end notesHtml

-- A line of code in his notes: one that is indented, or that begins with
-- a word of the language, small, as code is written (his prose begins
-- with a capital)
private function notesIsCode pLine
   set the caseSensitive to true
   if char 1 of pLine is space then
      return true
   end if
   return word 1 of pLine is among the items of "on,end,put,set,get,if,else"
end notesIsCode

-- Code, in colour on a light band: the first word of a line (a command, or
-- on and end), strings and comments
private function codeHtml pLine
   local tOut, tPos, tLen, tStart, tFirst
   put the number of chars of pLine into tLen
   put 1 into tPos
   repeat while tPos <= tLen and char tPos of pLine is space
      put space after tOut
      add 1 to tPos
   end repeat
   put true into tFirst
   repeat while tPos <= tLen
      if char tPos of pLine is quote then
         put tPos into tStart
         add 1 to tPos
         repeat while tPos <= tLen and char tPos of pLine is not quote
            add 1 to tPos
         end repeat
         put htmlFont(lkEscape(char tStart to tPos of pLine), empty, "180,83,9", false) after tOut
         add 1 to tPos
      else if char tPos to tPos + 1 of pLine is "--" then
         put htmlFont(lkEscape(char tPos to tLen of pLine), empty, "100,116,139", false) after tOut
         exit repeat
      else if tFirst and char tPos of pLine is not space then
         put tPos into tStart
         repeat while tPos <= tLen and char tPos of pLine is not space
            add 1 to tPos
         end repeat
         put htmlFont(lkEscape(char tStart to tPos - 1 of pLine), empty, "124,58,237", false) after tOut
         put false into tFirst
      else
         if char tPos of pLine is ";" then
            -- (a second command on the line)
            put true into tFirst
         end if
         put lkEscape(char tPos of pLine) after tOut
         add 1 to tPos
      end if
   end repeat
   return tOut
end codeHtml

private function htmlFont pText, pSize, pColor, pBold
   local tOut
   put "<font" into tOut
   if pSize is not empty then
      put " size=" & quote & pSize & quote after tOut
   end if
   put " color=" & quote & lkHex(pColor) & quote & ">" & pText & "</font>" after tOut
   if pBold then
      put "<b>" & tOut & "</b>" into tOut
   end if
   return tOut
end htmlFont

################################################################################
#
# Data grids, made as the IDE makes them
#

-- The font code is shown in on the cards: Source Code Pro, which the IDE
-- loads when it starts (the engine that builds cannot load it, so it is
-- named here; see codeFont for a computer without it)
private function codeFace
   if lkCodeFont() is not empty then
      return lkCodeFont()
   end if
   return "Source Code Pro"
end codeFace

-- Code's font on a field, and its mark, cCode: when a card opens, the
-- stack script gives each marked field the font the scripts panel found
-- (as the web IDE has Droid Sans Mono, not Source Code Pro), and the code
-- in the notes too (the card's cNotesFace names the font it is in)
private command codeFont pObj
   set the textFont of pObj to codeFace()
   set the cCode of pObj to true
end codeFont

-- A monospaced font to measure code in, as wide as Source Code Pro: the
-- engine that builds has DejaVu Sans Mono, where it has no Source Code Pro
private function measureFace
   if "DejaVu Sans Mono" is among the lines of the fontNames and codeFace() is not among the lines of the fontNames then
      return "DejaVu Sans Mono"
   end if
   return codeFace()
end measureFace

-- The data grid library, which the IDE loads when it starts, and the
-- script-only stacks of its behaviors: from this checkout's Toolset, or
-- else from the install's (OXT_INSTALL). It is loaded, not opened: its
-- openStack asks for the IDE's preferences
private command gridLibrary
   local tRepo, tPath, tFolder, tLine, tLocked
   if there is a stack "revDataGridLibrary" then
      exit gridLibrary
   end if
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tRepo
   put tRepo & "/ide/Toolset/palettes/revdatagridlibrary.rev" into tPath
   if there is no file tPath and $OXT_INSTALL is not empty then
      put $OXT_INSTALL & "/Toolset/palettes/revdatagridlibrary.rev" into tPath
   end if
   put item 1 to -2 of tPath into tFolder
   set the itemDelimiter to comma
   if there is no file tPath then
      throw "no data grid library at " & tPath
   end if
   put the lockMessages into tLocked
   lock messages
   get the name of stack tPath
   repeat for each line tLine in the stackFiles of stack "revDataGridLibrary"
      get the name of stack (tFolder & "/" & item 2 of tLine)
   end repeat
   set the lockMessages to tLocked
end gridLibrary

-- The stack's templates substack, as the IDE makes one for the first data
-- grid on a stack: its first card has the library's instructions, a
-- background that the cards made after it have too
private command gridTemplates pMain
   local tStack, tObj, tLocked
   put the defaultStack into tStack
   put the lockMessages into tLocked
   lock messages
   if there is a stack kTemplates then
      delete stack kTemplates
   end if
   create stack kTemplates
   set the mainStack of stack kTemplates to pMain
   set the rect of stack kTemplates to 180, 180, 780, 580
   set the defaultStack to kTemplates
   copy group "_DataGridTemplateInstructions_" of group "Templates" of card 1 of stack "revDataGridLibrary" to card 1 of stack kTemplates
   put it into tObj
   set the backgroundBehavior of tObj to true
   set the bottomLeft of tObj to 0, the height of stack kTemplates
   set the defaultStack to tStack
   set the lockMessages to tLocked
end gridTemplates

-- A data grid, as the IDE makes one: a copy of the library's, on the card
-- in front, and a row template for it on a new card of the templates
-- substack (a copy of the library's default one, with its behavior, a
-- button "Behavior Script" beside it). Returns the grid's long id; the
-- template's is in sRowTemplate, and its card is the substack's card in
-- front until the next grid
private function gridNew pName, pRect
   local tStack, tGrid, tObj, tLocked
   put the defaultStack into tStack
   put the lockMessages into tLocked
   -- (the grid sets itself up as it is made, from a message)
   unlock messages
   copy group "DataGrid" of group "Templates" of card 1 of stack "revDataGridLibrary" to this card of stack tStack
   put it into tGrid
   lock messages
   set the name of tGrid to pName
   set the rect of tGrid to pRect
   set the defaultStack to kTemplates
   create card
   copy group "Default Row Template" of group "Templates" of card 1 of stack "revDataGridLibrary" to this card of stack kTemplates
   put it into sRowTemplate
   set the name of sRowTemplate to "Row Template"
   set the topLeft of sRowTemplate to 0, 0
   create button "Behavior Script"
   put it into tObj
   set the visible of tObj to false
   set the script of tObj to the uDefaultScript of button "Default Script" of card 1 of stack "revDataGridLibrary"
   set the behavior of sRowTemplate to tObj
   set the defaultStack to tStack
   set the lockMessages to tLocked
   return tGrid
end gridNew

-- A column of the table with a template of its own, as the Inspector's
-- "+" makes one (revIDENewDataGridColumnBehavior): a copy of the library's
-- default column template in the row template, named as the column, and
-- its behavior, a hidden button "<column> Behavior" beside the row
-- template, with pScript
private command gridColumn pColumn, pScript
   local tStack, tGroup, tButton, tLocked
   put the defaultStack into tStack
   put the lockMessages into tLocked
   lock messages
   copy group "Default Column Template" of group "Templates" of card 1 of stack "revDataGridLibrary" to sRowTemplate
   put it into tGroup
   set the name of tGroup to pColumn
   set the topLeft of tGroup to 100, 0
   put pColumn into field 1 of tGroup
   set the defaultStack to kTemplates
   create button (pColumn && "Behavior")
   put it into tButton
   set the visible of tButton to false
   set the rect of tButton to 22, 43, 162, 75
   set the script of tButton to pScript
   set the behavior of tGroup to tButton
   set the defaultStack to tStack
   set the lockMessages to tLocked
end gridColumn

-- The grid takes its style and its row template, and sets itself up
private command gridReady pGrid, pStyle
   local tLocked
   put the lockMessages into tLocked
   unlock messages
   set the dgProps["style"] of pGrid to pStyle
   set the dgProps["row template"] of pGrid to sRowTemplate
   send "ResetControl" to pGrid
   set the lockMessages to tLocked
end gridReady

-- Terry's columns, their widths here (pWidths, an item each), their
-- alignment, his data and the column it is sorted by, from his grid on
-- card pCard
private command gridFill pGrid, pCard, pWidths
   local tLocked, tIndex, tColumn
   put the lockMessages into tLocked
   unlock messages
   set the dgProps["columns"] of pGrid to sOrig["columns" & pCard]
   repeat with tIndex = 1 to the number of lines of sOrig["columns" & pCard]
      put line tIndex of sOrig["columns" & pCard] into tColumn
      set the dgColumnWidth[tColumn] of pGrid to item tIndex of pWidths
      if sColumnProps[pCard][tColumn]["alignment"] is not empty then
         set the dgColumnAlignment[tColumn] of pGrid to sColumnProps[pCard][tColumn]["alignment"]
      end if
   end repeat
   set the dgData of pGrid to sGridData[pCard]
   if sOrig["sort" & pCard] is not empty then
      set the dgProps["sort by column"] of pGrid to sOrig["sort" & pCard]
   end if
   set the lockMessages to tLocked
end gridFill

-- A grid that a lesson may make wider than itself: a scrollbar along its
-- foot, when it is
private command gridScrolls pGrid
   local tLocked
   put the lockMessages into tLocked
   unlock messages
   set the dgProps["show hscrollbar"] of pGrid to "auto"
   set the lockMessages to tLocked
end gridScrolls

-- The look of the remaster's grids: the window's colours, a light header
-- and taller rows
private command gridLook pGrid, pAccent
   local tLocked
   put the lockMessages into tLocked
   unlock messages
   set the dgProps["header background color"] of pGrid to "255,255,255" & return & "241,245,249"
   set the dgProps["header background hilite color"] of pGrid to lkMix("255,255,255", pAccent, 0.08) & return & lkMix("255,255,255", pAccent, 0.18)
   set the dgProps["header divider color"] of pGrid to lkColor("line")
   set the dgProps["header divider threed color"] of pGrid to "255,255,255"
   set the dgProps["header text color"] of pGrid to lkColor("soft")
   set the dgProps["header text size"] of pGrid to 12
   set the dgProps["header text style"] of pGrid to "bold"
   set the dgProps["header height"] of pGrid to 30
   set the dgProps["text size"] of pGrid to 13
   set the dgProps["text color"] of pGrid to lkColor("ink")
   set the dgProps["row height"] of pGrid to 28
   set the dgProps["row color"] of pGrid to "255,255,255"
   set the dgProps["alternate row colors"] of pGrid to true
   set the dgProps["alternate row color"] of pGrid to lkMix("255,255,255", pAccent, 0.05)
   set the dgProps["hilite color"] of pGrid to pAccent
   set the dgProps["dimmed hilite color"] of pGrid to lkMix("255,255,255", pAccent, 0.35)
   set the dgProps["hilited text color"] of pGrid to "255,255,255"
   set the dgProps["dim on focusOut"] of pGrid to false
   set the dgProps["column divider color"] of pGrid to lkColor("line")
   set the dgProps["border color"] of pGrid to lkColor("line")
   set the dgProps["background color"] of pGrid to "255,255,255"
   set the dgProps["corner color"] of pGrid to "241,245,249"
   set the dgProps["header margins"] of pGrid to "8,12,8,0"
   set the dgProps["show hscrollbar"] of pGrid to false
   -- (no scrollbar, as the window's panels have none: the wheel scrolls)
   set the dgProps["show vscrollbar"] of pGrid to false
   set the dgProps["scroll when vscrollbar is hidden"] of pGrid to true
   set the lockMessages to tLocked
end gridLook

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Data Grid Tables: Terry Little's DataGrid Table v1.0, remastered for OXT-Beyond in 2026
--DataGrid Table v1.0, Terry Little, c 2022.
--This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
--as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

--Each lesson is a card: its data grid and the things to try at the left of the stage, and the lesson's
--notes at the right (the field "Info", in the background group "Notes", as Terry's was in the group
--"Nav"). The sidebar, the header, the stage and the scripts drawer are the groups "Frame", "Workbench"
--and "Scripts", which the script of the group "Frame" runs.

--(remaster) Where the wheel is taking the notes, and where a drag of their thumb began
local sGlideGoal, sDragFrom, sDragScroll

on openStack  --added: a word, if the IDE's data grid library is not there to draw the grids
   if there is not a stack "revDataGridLibrary" then
      answer "The data grids on these cards need the IDE's data grid library, and it is not loaded." &cr& \
            "In Preferences, under Compatibility, untick Disable Data Grids, then start the IDE again." with "OK" titled "Data Grid Tables"
   end if
   pass openStack
end openStack

on preOpenCard  --was in Terry's < Prev and Next > buttons, which the window's Back and Next are now
   put empty into sGlideGoal  --(remaster) a glide of the last card's notes stops
   codeFontMatch  --(remaster) the code on the card in the scripts panel's font
   if there is a fld "Info" then set the vScroll of fld "Info" to "0"  --top
   notesFit  --(remaster) the notes end at the foot of a line, not halfway down one
   notesThumb  --(remaster) the thumb that shows how far down the notes are
   pass preOpenCard
end preOpenCard

--(remaster) Code in the scripts panel's font (the window finds it before this stack's preOpenCard),
--or else in the first of its choices this computer has: each field whose cCode is true, and the
--code in the notes, whose font the card's cNotesFace names. The web IDE, say, has Droid Sans Mono
--and not Source Code Pro.

command codeFontMatch
   local tFont, tIndex, tField, tWas, tHtml
   put codeFontHere() into tFont
   if tFont is empty then exit codeFontMatch
   repeat with tIndex = 1 to the number of fields of this card
      put the long id of field tIndex of this card into tField
      if the cCode of tField is true and the textFont of tField is not tFont then set the textFont of tField to tFont
   end repeat
   put the cNotesFace of this card into tWas
   if there is a fld "Info" and tWas is not empty and tWas is not tFont then
      put the htmlText of fld "Info" into tHtml
      replace "face=" & quote & tWas & quote with "face=" & quote & tFont & quote in tHtml
      set the htmlText of fld "Info" to tHtml
      set the cNotesFace of this card to tFont
   end if
end codeFontMatch

function codeFontHere
   local tFont
   if there is a field "codeText" then
      if the textFont of field "codeText" is not empty then return the textFont of field "codeText"
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then return tFont
   end repeat
   return empty
end codeFontHere

--(remaster) The notes as tall as the lines of this card's notes that show whole: their foot as
--far down as cNotesBottom lets it, at the foot of the last such line (a line of a paragraph, as
--its words show where it ends), so that the card does not open on a line cut in half.

command notesFit
   local tBottom, tLimit, tLine, tWord, tRect, tFoot, tCount
   if there is no fld "Info" or the cNotesBottom of fld "Info" is empty then exit notesFit
   put the cNotesBottom of fld "Info" into tLimit
   set the rect of fld "Info" to item 1 of the rect of fld "Info", item 2 of the rect of fld "Info", item 3 of the rect of fld "Info", tLimit
   put empty into tFoot
   put the number of lines of fld "Info" into tCount
   repeat with tLine = 1 to tCount
      put item 4 of the formattedRect of line tLine of fld "Info" into tBottom
      if tBottom > tLimit then exit repeat
      put tBottom into tFoot
   end repeat
   if tLine <= tCount then  --a paragraph runs past the foot: as far as its whole lines go
      repeat with tWord = 1 to the number of words of line tLine of fld "Info"
         put the formattedRect of word tWord of line tLine of fld "Info" into tRect
         if item 4 of tRect > tLimit then exit repeat
         put max(tFoot, item 4 of tRect) into tFoot
      end repeat
   end if
   if tFoot is not empty then
      set the rect of fld "Info" to item 1 of the rect of fld "Info", item 2 of the rect of fld "Info", item 3 of the rect of fld "Info", tFoot + 2
   end if
end notesFit

--(remaster) The notes scroll with the wheel, without a scrollbar, as the scripts panel does: the slim
--thumb at their right shows how far down they are, and can be dragged.

on rawKeyDown pKey
   local tGliding
   if pKey is not 65308 and pKey is not 65309 then pass rawKeyDown  --the wheel, down or up
   if not notesUnderMouse() then pass rawKeyDown
   put sGlideGoal is not empty into tGliding  --a glide under way takes the new goal (a second one beside it would double its speed)
   if not tGliding then put the vScroll of fld "Info" into sGlideGoal
   if pKey is 65308 then add 48 to sGlideGoal
   else subtract 48 from sGlideGoal
   put max(0, min(sGlideGoal, notesRoom())) into sGlideGoal
   if not tGliding then notesGlide
end rawKeyDown

on notesGlide  --one step of the scroll toward where the wheel is taking it
   local tNow, tStep
   if sGlideGoal is empty or there is no fld "Info" then
      put empty into sGlideGoal
      exit notesGlide
   end if
   put the vScroll of fld "Info" into tNow
   put round((sGlideGoal - tNow) * 0.35) into tStep
   if abs(sGlideGoal - tNow) <= 1 or tStep is 0 then
      set the vScroll of fld "Info" to sGlideGoal
      put empty into sGlideGoal
   else
      set the vScroll of fld "Info" to tNow + tStep
      if the vScroll of fld "Info" is tNow then put empty into sGlideGoal  --it did not move: it is at its end, and the glide is over
      else send "notesGlide" to me in 16 milliseconds
   end if
   notesThumb
end notesGlide

function notesUnderMouse  --the pointer is over the notes or their thumb (not the scripts drawer)
   local tControl
   if there is no fld "Info" then return false
   put the mouseControl into tControl
   if tControl is empty then return false
   return the long id of tControl is the long id of fld "Info" or the short name of tControl is "notesThumb"
end notesUnderMouse

function notesRoom  --how far down the notes go: measured, as the engine stops a field's scroll a few pixels short of its formattedHeight less its height
   local tNow, tRoom, tLocked
   put the vScroll of fld "Info" into tNow
   put the lockMessages into tLocked
   lock screen
   lock messages
   set the vScroll of fld "Info" to the formattedHeight of fld "Info" + the height of fld "Info"
   put the vScroll of fld "Info" into tRoom
   set the vScroll of fld "Info" to tNow
   set the lockMessages to tLocked
   unlock screen
   return max(0, tRoom)
end notesRoom

command notesThumb
   local tRoom, tTrack, tSize, tTop
   if there is no fld "Info" or there is no grc "notesThumb" then exit notesThumb
   put notesRoom() into tRoom
   if tRoom < 8 then
      hide grc "notesThumb"
      exit notesThumb
   end if
   put the height of fld "Info" - 16 into tTrack
   put max(24, round(tTrack * tTrack / (tTrack + tRoom))) into tSize
   put the top of fld "Info" + 8 + round((tTrack - tSize) * min(1, the vScroll of fld "Info" / tRoom)) into tTop
   set the rect of grc "notesThumb" to item 1 of the rect of grc "notesThumb", tTop, item 3 of the rect of grc "notesThumb", tTop + tSize
   show grc "notesThumb"
end notesThumb

on mouseDown pButton  --the thumb, dragged: the notes go as far down as it does
   if pButton is 1 and the short name of the target is "notesThumb" and there is a fld "Info" then
      put item 2 of the mouseLoc into sDragFrom
      put the vScroll of fld "Info" into sDragScroll
      put empty into sGlideGoal
   end if
   pass mouseDown
end mouseDown

on mouseMove pX, pY
   local tTrack, tRoom
   if sDragFrom is empty then pass mouseMove
   if the mouse is up or there is no fld "Info" then
      put empty into sDragFrom
      pass mouseMove
   end if
   put the height of fld "Info" - 16 - the height of grc "notesThumb" into tTrack
   if tTrack > 0 then
      put notesRoom() into tRoom
      set the vScroll of fld "Info" to max(0, min(tRoom, sDragScroll + round((pY - sDragFrom) * tRoom / tTrack)))
      notesThumb
   end if
   pass mouseMove
end mouseMove

on mouseUp pButton
   put empty into sDragFrom
   pass mouseUp
end mouseUp

on mouseRelease pButton
   put empty into sDragFrom
   pass mouseRelease
end mouseRelease
@*/

/*@ Start/Lesson Plan
on mouseUp  --lesson plan.txt
   local tPath, tPlan
   answer "Terry Little's lesson plan, for teachers: copy it, or save it as a text file." with "Cancel" or "Copy" or "Save" titled "Teacher Lesson Plan"
   if it = "Cancel" then exit to top
   put the cLessonPlan of me into tPlan  --custom property containing plan
   if it = "Copy" then  --added: on the clipboard, to paste into a document
      set the clipboardData["text"] to tPlan
      answer "The lesson plan is on the clipboard: paste it into a document." with "OK" titled "Teacher Lesson Plan"
      exit to top
   end if
   if the platform is "HTML5" then  --added: a browser cannot save a file here
      answer "A browser cannot save a file here: choose Copy, then paste the plan into a document." with "OK" titled "Teacher Lesson Plan"
      exit to top
   end if
   --it was a file on the desktop, which a computer may not let a program write to; you say where now:
   --put specialfolderPath("desktop") &"/"& "Lesson Plan.txt" into tPath  --create new
   ask file "Save the lesson plan as:" with "Lesson Plan.txt"
   if it is empty then exit to top  --Cancel
   put it into tPath
   put tPlan into url ("file:" & tPath)  --export text file
   if result() <> empty then answer "Sorry, there was a problem writing to a text file." &cr& result() with "OK" titled "Error"
   else answer "Successfully exported a text file" &&quote& "Lesson Plan" &quote&& "to" && tPath & "." with "OK" titled "Teacher Lesson Plan"
end mouseUp
@*/

/*@ Lesson 1/DataGrid 1
on mouseUp  --in dg table main group script
   put line (the dgHilitedLine of me) of the dgText of me into msg  --selected line of data
   put msg into fld "Message"  --added: the message box, under the grid too
end mouseUp
@*/

/*@ Lesson 1/Num Behavior
-- This script defines the behavior of a table column's custom template.

on FillInData pData
   set the text of fld 1 of me to pData
   set the textAlign of fld 1 of me to the dgColumnAlignment["Num"] of grp "DataGrid 1"  --col align bug fix
   if pData >= "3" then set the textColor of fld 1 of me to "Red"  --dg table conditional text color
   else set the textColor of fld 1 of me to empty  --default black
end FillInData


on LayoutControl pControlRect
   -- This message is sent when you should layout your template's controls if your template is a group.
   -- If your template is not a group then there is no work to do here.
   -- You can use items 1 through 4 of pControlRect as boundaries for laying out your controls.

   -- Example:
   set the rect of field 1 of me to pControlRect
end LayoutControl


on ResetData
   -- Sent when column data is being emptied because the control is no longer being used to display data
   set the text of field 1 of me to empty
end ResetData


on PreFillInData
   -- Sent right before new data is going to replace existing data in the column
end PreFillInData


setprop dgHilite pBoolean
   -- This custom property is set when the highlight of your column template has
   -- changed. You only add script here if you want to customize the highlight.

   if pBoolean then
      set the foregroundColor of me to the dgProp["hilited text color"] of the dgControl of me
   else
      set the foregroundColor of me to empty
   end if
end dgHilite


getprop dgDataControl
   -- Required by library so that it can locate your control.
   return the long ID of me
end dgDataControl


-- Data grid will call EditValue if a user action asks to edit cell content.
command EditValue
   if there is a field 1 of me then
      EditFieldText the long ID of field 1 of me, the dgIndex of me, the dgColumn of me
   end if
end EditValue


on mouseDoubleUp pMouseBtnNum
   -- Example of how to edit the contents of a field (assuming the column template this is
   -- associated with is a field).
   -- By passing the index of the record linked to the copy of this template and the name of the
   -- column being edited the data grid will automatically save the changes the user
   -- makes and refresh the UI by calling FillInData and resizeControl.
   if pMouseBtnNum is 1 then
      if word 1 of the target is "field" then
         ## word 1 to -2 because of unique numbers (i.e. 0001, 0002) that the data grid adds to each
         ## copy of this template that is made.
         if the dgProps["allow editing"] of the dgControl of me \
               and the dgColumnIsEditable[the dgColumn of me] of the dgControl of me then
            EditCellOfIndex the dgColumn of me, the dgIndex of me
            exit mouseDoubleUp
         end if
      end if
   end if

   pass mouseDoubleUp
end mouseDoubleUp
@*/

/*@ Lesson 1/DG > Text
on mouseUp  --dg > text
   local tText
   put the dgText of grp "DataGrid 1" into tText
   put tText into fld "Display"
end mouseUp

--put the dgHilitedLine of grp "DataGrid 1"  --2, if line two is selected
--put line 2 of the dgText of grp "DataGrid 1"  --extract line 2 of tabbed data
--set the itemDel to tab; put item 3 of line 2 of the dgText of grp "Datagrid 1"  --extract data from one cell
@*/

/*@ Lesson 1/Text > DG
on mouseUp  --text > dg
   local tText
   if fld "Display" = empty then
      answer "Sorry, there's no data in the field." with "OK" titled "Error"
      exit to top
   end if
   put fld "Display" into tText  --dg requires tab delimited data
   filter lines of tText without empty  --remove empty lines
   set the dgText of grp "DataGrid 1" to tText
end mouseUp

----
--set the opaque of fld "Colors 0003" of grp "Datagrid 1" to "true"  --allow color
--set the backColor of fld "Colors 0003" of grp "Datagrid 1" to "pink"  --color a cell
----
--dg table properties inspector > columns > select a column to color, click btn "Column Behavior",
--paste in the column's "column behavior" button script:
on FillInData pData  --dg table conditional text color
   set the text of fld 1 of me to pData
   if pData >= "3" then set the textColor of fld 1 of me to "Red"
   else set the textColor of fld 1 of me to empty  --default black
end FillInData
@*/

/*@ Try It
on mouseUp  --added: runs the line you click, as the message box runs a line you type and Return
   local tLine, tParts, tIndex, tStatement, tScript, tResult, tError
   put the value of the clickLine into tLine
   if word 1 to -1 of tLine is empty then exit mouseUp
   put tLine into tParts
   split tParts by ";"
   repeat with tIndex = 1 to the number of elements of tParts
      put word 1 to -1 of tParts[tIndex] into tStatement
      if word 1 of tStatement is "put" and " into " is not in tStatement and " after " is not in tStatement and " before " is not in tStatement then
         put " into tResult" after tStatement  --what would go to the message box goes to this card's
      end if
      put tStatement & return after tScript
   end repeat
   put "Done." into tResult
   try
      do tScript
   catch tError
      put "Sorry, that line did not run here." into tResult
   end try
   if there is a fld "Message" then put tResult into fld "Message"  --on the card (a line may go to another)
end mouseUp
@*/

/*@ Lesson 2/try
put line 2 of the dgText of grp "DataGrid 1"
set the itemDel to tab; put item 2 of line 2 of the dgText of grp "DataGrid 1"
set the dgColumnAlignment["Fruit"] of grp "DataGrid 1" to "right"
set the dgColumnAlignment["Fruit"] of grp "DataGrid 1" to "left"
@*/

/*@ Lesson 3/tips
Your data grid goes on this card

Drag a data grid from the Tools palette onto the stage, then fill it in its Inspector, as the notes say.

Give it a script (Object > Object Script), and the script shows here when the card opens again.
@*/

/*@ Lesson 4/try
copy this card
paste
go prev card
go next card
@*/

/*@ Lesson 5/Table 1
on closeField  --conditional color in field table column, msg sent when text changes and fld loses focus
   local tData, tLines, i  --(remaster) i added: strict compilation declares every variable
   put fld "Table 1" into tData
   put number(lines in tData) into tLines
   set the itemDel to tab
   lock screen
   repeat with i = 2 to tLines
      if item -1 of line i of tData is a number and item -1 of line i of tData >= "3" then set the textColor of item -1 of line i of fld "Table 1" to "Red"
      else set the textcolor of item -1 of line i of fld "Table 1" to empty  --default black
   end repeat
end closeField
@*/

/*@ Lesson 5/try
put line 2 of fld "Table 1"
set the itemDel to tab; put item 2 of line 2 of fld "Table 1"
put line 2 to -1 of fld "Table 1"
set the vGrid of fld "Table 1" to "false"
set the vGrid of fld "Table 1" to "true"
@*/
