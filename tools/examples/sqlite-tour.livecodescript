script "OXTExampleSqliteTour"
-- OXT-Beyond: builds "A Tour of SQLite", the remaster of LiveCode Ltd's
-- SQLite Tour v1.0 (debranded for OpenXTalk at LiveCode Ltd's request),
-- which is in ide/Resources/Examples/SQLite Tour.oxtstack and stays there
-- as they made it. The stack says "(c) LiveCode Ltd" and states no
-- licence of its own: it came with the IDE.
--
-- The tour teaches revDB and SQLite in eighteen cards: what revDB is, a
-- little SQL and the plan of a two-table database, then buttons that make
-- the database, fill it, read it, change it, join its tables in reports,
-- change its columns and keep a picture in it. The remaster keeps its
-- programs (the buttons' scripts, with their comments) and what it
-- teaches, in the window every remastered example has
-- (builder.livecodescript): a front page and fourteen chapters, as many
-- as the sidebar holds. So its cards 4, 5 and 6 (the plan, the tables and
-- the data types) are one page, and its cards 14 and 15 (deleting a
-- table, the schema) one chapter. Its long texts are shorter, and drawn
-- as tables, diagrams and code.
--
-- revDB, not altSQLite3: the original's examples already used revDB
-- (revOpenDatabase, revExecuteSQL, revDataFromQuery, revQueryDatabase,
-- revDatabaseColumnNamed, revCloseDatabase), which OXT-Beyond ships and
-- its web engine has built in, so nothing needed porting. Its button
-- "Purchase altSQLite3 NOW!", an advertisement for a commercial external,
-- is left out, as are its author's tools (togglePaletteMode, Reset
-- Fields) and Chipp Walters' column headers (the groups altFldHeader),
-- which the tables' own headers replace.
--
-- What changed in the scripts is said where it changed:
--   - the databases are files in the temporary folder, which a program
--     can always write to, not on the desktop: the remaster sits in the
--     IDE's Resources folder, which may be read-only, and a browser has no
--     desktop
--   - what they answered in dialogs is said in a panel under the buttons
--     (showResult, in the stack script), and the lists they returned fill
--     tables on the card; a question before something that cannot be
--     undone is still asked
--   - the buttons are the kit's, which are groups: "send ... to btn" is
--     "send ... to group"
--   - and what was broken: errors answered with a variable never set,
--     checks for "revdberr" after revExecuteSQL (whose errors do not say
--     it), a dialog's "Cancel" and "OK" joined with "and", double quotes
--     doubled inside SQL's single quotes, a list split at commas
--
-- build-examples.livecodescript runs exBuild with the builder in use.

-- The content, and inside the stage of a wide card, where its things go
constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
constant kInLeft = 280
constant kInTop = 128
constant kInRight = 976
constant kInBottom = 592
-- The height of a button, and of a line of code
constant kButton = 36
constant kCodeLine = 18

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tRepo, tOriginal, tIcon, tUsers, tApps
   exUseScripts the script of me
   -- From the original: the picture the binary chapter keeps in the database, and the
   -- ready-made rows of its Default Data buttons (each of the three has the same)
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put tRepo & "/ide/Resources/Examples/SQLite Tour.oxtstack" into tOriginal
   put the text of image "Icon1" of card "Binary Data" of stack tOriginal into tIcon
   put the altDefaultUsersData of button "Default Data" of card "Edit Databases" of stack tOriginal into tUsers
   put the altDefaultAppsData of button "Default Data" of card "Edit Databases" of stack tOriginal into tApps
   delete stack tOriginal
   if tIcon is empty or tUsers is empty or tApps is empty then
      throw "cannot read the picture and the default data of " & tOriginal
   end if
   addIcons
   put "A Tour of SQLite" into tInfo["name"]
   put "after LiveCode Ltd" into tInfo["credit"]
   put "database" into tInfo["icon"]
   put lkColor("sky") into tInfo["accent"]
   put lkColor("indigo") into tInfo["accent2"]
   put "Chapter" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|A Tour of SQLite|Build a small database, one chapter at a time.|database|front" & return & \
         "About revDB|About revDB|The engine's built-in library for talking to databases.|layers|page" & return & \
         "SQL Primer|SQL Primer|Tables, rows, columns, and the six commands the tour uses.|square-terminal|page" & return & \
         "The Plan|The Plan|Two linked tables: the users, and the apps they registered.|link|page" & return & \
         "Connect|Connect|Make the database file and connect to it.|plug|wide" & return & \
         "Create Tables|Create Tables|Give the database its two tables.|table-properties|wide" & return & \
         "Add Data|Add Data|Add rows to the users table with INSERT INTO.|list-plus|wide" & return & \
         "View and Delete|View & Delete|Read rows with SELECT, and remove them with DELETE.|list-x|wide" & return & \
         "Update Data|Update Data|Click a cell to change it with UPDATE.|pencil|wide" & return & \
         "Both Tables|Both Tables|Fill both tables, ready for the reports.|sheet|wide" & return & \
         "Reports|Reports|Join the two tables to answer questions.|git-merge|wide" & return & \
         "The Schema|The Schema|The structure of the database, and dropping a table.|file-code|wide" & return & \
         "Columns|Columns|Delete and add columns by rebuilding a table.|columns-3|wide" & return & \
         "Binary Data|Binary Data|Keep a picture in the database, and get it back.|binary|wide" & return & \
         "All Done|All Done|What you can do now, and a reference to keep.|party-popper|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   setLooks
   buildStart
   buildAbout
   buildPrimer
   buildPlan
   buildConnect
   buildCreate
   buildAdd
   buildView
   buildUpdate
   buildBoth tUsers, tApps
   buildReports
   buildSchema tUsers, tApps
   buildColumns tUsers, tApps
   buildBinary tIcon
   buildDone
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/A Tour of SQLite.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

-- Lucide's icons that the kit does not have (the block "icons": name|elements)
private command addIcons
   local tLine
   set the itemDelimiter to "|"
   repeat for each line tLine in exScript("icons")
      if tLine is not empty then
         exAddIcon item 1 of tLine, item 2 of tLine
      end if
   end repeat
end addIcons

-- Colours the stack script uses when it shows what happened, kept in the stack's custom
-- properties so that it names none itself; and the code colours, the window's (the kit's)
private command setLooks
   local tSky, tGood, tBad
   put lkColor("sky") into tSky
   put lkColor("emerald") into tGood
   put lkColor("rose") into tBad
   set the cOkBack of this stack to lkMix("255,255,255", tGood, 0.08)
   set the cOkEdge of this stack to lkMix("255,255,255", tGood, 0.35)
   set the cErrorBack of this stack to lkMix("255,255,255", tBad, 0.07)
   set the cErrorEdge of this stack to lkMix("255,255,255", tBad, 0.35)
   set the cInfoBack of this stack to lkMix("255,255,255", tSky, 0.06)
   set the cInfoEdge of this stack to lkMix("255,255,255", tSky, 0.3)
   set the cOn of this stack to tGood
   set the cOnBack of this stack to lkMix("255,255,255", tGood, 0.1)
   set the cOnEdge of this stack to lkMix("255,255,255", tGood, 0.4)
   set the cOff of this stack to lkColor("muted")
   -- (words in the off state are in the body grey: the paler one, right
   -- for the dot and the dashed line, was hard to read as words on white)
   set the cOffInk of this stack to lkColor("soft")
   set the cOffBack of this stack to "255,255,255"
   set the cOffEdge of this stack to lkColor("line")
   set the cVennOn of this stack to tSky
   set the cVennMid of this stack to lkMix("255,255,255", tSky, 0.3)
   set the cVennOff of this stack to lkMix("255,255,255", tSky, 0.08)
   set the cVennInk of this stack to lkColor("ink")
   set the cSqlWord of this stack to lkWordColor("put")
   set the cSqlType of this stack to lkWordColor("field")
   set the cSqlNumber of this stack to lkWordColor("1")
   set the cSqlName of this stack to lkWordColor("someName")
   set the cSqlString of this stack to spanColor(lkCodeLineHtml(quote & "x" & quote))
   set the cSqlComment of this stack to spanColor(lkCodeLineHtml("--x"))
end setLooks

-- The colour of the first span of a line of code in colour
private function spanColor pHtml
   local tPos
   put offset("#", pHtml) into tPos
   return char tPos to tPos + 6 of pHtml
end spanColor

################################################################################
#
# The building blocks of the tour's cards
#

-- The colour of a word of code among words: the accent, darker
private function codeInk
   return lkMix(lkColor("sky"), lkColor("ink"), 0.35)
end codeInk

-- Words as htmlText from a block of the tour's own markup: a line is a paragraph, **this**
-- is bold, `this` is code, and a line that begins "- " is a bullet
private function markup pText
   local tLine, tHtml, tParas, tCount, tIndex
   repeat for each line tLine in pText
      if word 1 to -1 of tLine is empty then
         next repeat
      end if
      put lkEscape(tLine) into tLine
      put markSpans(tLine, "**", "<b>", "</b>") into tLine
      put markSpans(tLine, "`", "<font color=" & quote & lkHex(codeInk()) & quote & ">", "</font>") into tLine
      replace "-&gt;" with numToCodepoint(8594) in tLine
      if char 1 to 2 of tLine is "- " then
         put numToCodepoint(8226) & "  " & char 3 to -1 of tLine into tLine
      end if
      add 1 to tCount
      put tLine into tParas[tCount]
   end repeat
   repeat with tIndex = 1 to tCount
      if tIndex < tCount then
         put "<p spacebelow=" & quote & "8" & quote & ">" & tParas[tIndex] & "</p>" after tHtml
      else
         put "<p>" & tParas[tIndex] & "</p>" after tHtml
      end if
   end repeat
   return tHtml
end markup

-- Each pair of pMark in pLine: the first opens a span, the second shuts it
private function markSpans pLine, pMark, pOpen, pClose
   local tOut, tPos, tOpen
   put false into tOpen
   repeat
      put offset(pMark, pLine) into tPos
      if tPos is 0 then
         exit repeat
      end if
      put char 1 to tPos - 1 of pLine after tOut
      if tOpen then
         put pClose after tOut
      else
         put pOpen after tOut
      end if
      put not tOpen into tOpen
      delete char 1 to tPos + the number of chars of pMark - 1 of pLine
   end repeat
   return tOut & pLine
end markSpans

-- Words: htmlText in a label as tall as its text; returns the label
private function wordsBox pName, pLeft, pTop, pRight, pHtml, pSize, pColor
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + 20), empty, pSize, pColor, empty) into tObj
   set the htmlText of tObj to pHtml
   fitHeight tObj
   return tObj
end wordsBox

private command fitHeight pObj
   local tRect
   put the rect of pObj into tRect
   put item 2 of tRect + the formattedHeight of pObj + 2 into item 4 of tRect
   set the rect of pObj to tRect
end fitHeight

-- A bold heading, 15 points; returns the label
private function heading pName, pLeft, pTop, pRight, pText
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + 20), pText, 15, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   return tObj
end heading

-- An icon on a tint of its colour, 44 by 44
private command iconTile pName, pLeft, pTop, pIcon, pColor
   get lkBox(pName & "Bg", lkR(pLeft, pTop, pLeft + 44, pTop + 44), lkMix("255,255,255", pColor, 0.12), 12, empty)
   get exIcon(pName, pIcon, pColor, lkR(pLeft + 11, pTop + 11, pLeft + 33, pTop + 33), empty)
end iconTile

-- Code in colour, as the window's scripts panel shows it: a line of xTalk in the kit's
-- colours, and a line of SQL (it begins with a word of SQL in capitals, or goes on from one,
-- indented) as the stack script colours the SQL it shows
private function codeHtml pCode
   local tHtml, tLine, tSql
   set the caseSensitive to true
   put false into tSql
   repeat for each line tLine in pCode
      if word 1 of tLine is among the items of "SELECT,INSERT,CREATE,DROP,DELETE,UPDATE,BEGIN,COMMIT,FROM,WHERE" then
         put true into tSql
      else if char 1 of tLine is not space then
         put false into tSql
      end if
      if tSql then
         put "<p>" & sqlLineOf(tLine) & "</p>" after tHtml
      else
         put "<p>" & lkCodeLineHtml(tLine) & "</p>" after tHtml
      end if
   end repeat
   return tHtml
end codeHtml

-- A line of SQL in colour, by the stack script's own function, so that SQL looks the same
-- built as shown later
private function sqlLineOf pLine
   dispatch function "sqlLineHtml" to this stack with pLine
   return the result
end sqlLineOf

-- Code on a card, in colour, in a dark box: a line of code a line of the field, which does
-- not wrap. The stack script gives it the code font when the card opens (cCode). Returns
-- the box's bottom
private function snippet pName, pLeft, pTop, pRight, pCode
   local tObj, tHeight
   put (the number of lines of pCode) * kCodeLine + 24 into tHeight
   get lkBox(pName & "Box", lkR(pLeft, pTop, pRight, pTop + tHeight), lkColor("code"), 12, empty)
   put lkLabel(pName, lkR(pLeft + 14, pTop + 12, pRight - 8, pTop + tHeight - 6), empty, 12, lkColor("codeInk"), empty) into tObj
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to kCodeLine
   set the htmlText of tObj to codeHtml(pCode)
   set the cCode of tObj to true
   return pTop + tHeight
end snippet

-- A wide card's words (the block "<card>/words"), from pTop; returns their bottom
private function lesson pCard, pBlock, pTop, pLeft, pRight
   local tObj
   put wordsBox(pBlock, pLeft, pTop, pRight, markup(exScript(pCard & "/" & tolower(pBlock))), 13, lkColor("soft")) into tObj
   return the bottom of tObj
end lesson

-- A row of buttons from pLeft: a line of pList for each, name|label|icon|style. Each one's
-- script is the block "<card>/<name>". Returns the right of the last
private function buttonRow pCard, pLeft, pTop, pList
   local tLine, tX, tWidth
   put pLeft into tX
   set the itemDelimiter to "|"
   repeat for each line tLine in pList
      put exButton(item 1 of tLine, tX, pTop, kButton, item 2 of tLine, item 3 of tLine, item 4 of tLine, \
            lkColor("sky"), empty, empty, 0) into tWidth
      set the script of group (item 1 of tLine) to exScript(pCard & "/" & item 1 of tLine)
      add tWidth + 10 to tX
   end repeat
   return tX - 10
end buttonRow

-- The panel under the buttons where they say what they did (the stack script's showResult).
-- When the card opens it gives the card's hint (cHint). Returns its bottom
private function statusBar pTop, pHint
   local tObj, tSky, tIconRect
   put lkColor("sky") into tSky
   put lkBox("StatusBg", lkR(kInLeft, pTop, kInRight, pTop + 44), lkMix("255,255,255", tSky, 0.06), 12, empty) into tObj
   lkBorder tObj, lkMix("255,255,255", tSky, 0.3)
   put lkR(kInLeft + 14, pTop + 13, kInLeft + 32, pTop + 31) into tIconRect
   get exIcon("StatusInfo", "info", tSky, tIconRect, empty)
   put exIcon("StatusOk", "circle-check", lkColor("emerald"), tIconRect, empty) into tObj
   hide tObj
   put exIcon("StatusError", "circle-alert", lkColor("rose"), tIconRect, empty) into tObj
   hide tObj
   put lkLabel("Status", lkR(kInLeft + 44, pTop + 12, kInRight - 14, pTop + 34), empty, 13, lkColor("ink"), empty) into tObj
   set the htmlText of tObj to "<p><b>" & lkEscape(pHint) & "</b></p>"
   set the cHint of this card to pHint
   return pTop + 44
end statusBar

-- The connection, in the header beside the Scripts button (the stack script's
-- showConnection writes it, and makes the badge as wide as its words)
private command badge
   local tObj
   put lkBox("BadgeBg", lkR(758, 27, 884, 55), "255,255,255", 14, empty) into tObj
   lkBorder tObj, lkColor("line")
   get lkOval("BadgeDot", lkR(772, 37, 780, 45), lkColor("muted"), empty)
   put lkLabel("Badge", lkR(786, 38, 880, 55), "Not connected", 12, lkColor("soft"), empty) into tObj
   set the dontWrap of tObj to true
end badge

-- A table: a box, a band with the columns' names (field pName & "Head") and the rows (field
-- pName), tab-delimited, pRow high. The stack script makes each column as wide as what it
-- holds, by the header its custom property cHead names. pSelect: a row can be chosen
private function tableBox pName, pRect, pColumns, pSelect, pRow
   local tObj, tHead, tSky, tLeft, tTop, tRight, tBottom, tBand
   put lkColor("sky") into tSky
   put item 1 of pRect into tLeft
   put item 2 of pRect into tTop
   put item 3 of pRect into tRight
   put item 4 of pRect into tBottom
   put lkMix("255,255,255", tSky, 0.07) into tBand
   put lkBox(pName & "Frame", pRect, "255,255,255", 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   get lkBox(pName & "Band", lkR(tLeft + 1, tTop + 1, tRight - 1, tTop + 31), tBand, 11, empty)
   get lkBox(pName & "BandFoot", lkR(tLeft + 1, tTop + 16, tRight - 1, tTop + 31), tBand, 0, empty)
   get lkBox(pName & "Rule", lkR(tLeft + 1, tTop + 31, tRight - 1, tTop + 32), lkColor("line"), 0, empty)
   put lkLabel(pName & "Head", lkR(tLeft + 1, tTop + 13, tRight - 1, tTop + 31), pColumns, 12, lkColor("soft"), empty) into tHead
   set the textStyle of tHead to "bold"
   set the dontWrap of tHead to true
   set the margins of tHead to "12,4,4,0"
   put lkLabel(pName, lkR(tLeft + 1, tTop + 33, tRight - 1, tBottom - 2), empty, 12, lkColor("ink"), empty) into tObj
   set the dontWrap of tObj to true
   -- (its top at the rule. A field of fixed line height sets each line's words at the foot of
   -- the line, so the taller a row, the lower its words sit between its grid lines: the tables
   -- that fill from the database keep rows of 22, where the words sit in the middle)
   set the rect of tObj to tLeft + 1, tTop + 32, tRight - 1, tBottom - 2
   set the margins of tObj to "12,4,4,0"
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to pRow
   set the hGrid of tObj to true
   set the borderColor of tObj to lkMix(lkColor("line"), "255,255,255", 0.4)
   if pSelect then
      -- (a label does not hilite what is clicked; a table whose rows are chosen does)
      set the autoHilite of tObj to true
      set the listBehavior of tObj to true
      set the traversalOn of tObj to true
      set the hiliteColor of tObj to tSky
   end if
   set the tabStops of tHead to evenStops(tRight - tLeft - 16, pColumns)
   set the tabStops of tObj to the tabStops of tHead
   set the cHead of tObj to pName & "Head"
   set the cWheel of tObj to true
   return tObj
end tableBox

-- Words in the middle of an empty table (the field pTable, from tableBox), which say how to
-- fill it: the stack script's showEmpty shows them while the table has no rows
private command emptyHint pTable, pText
   local tObj, tRect, tRows
   put the rect of graphic (pTable & "Frame") into tRect
   put lkLabel(pTable & "Empty", lkR(item 1 of tRect + 16, 0, item 3 of tRect - 16, 18), pText, 13, lkColor("soft"), empty, "center") into tObj
   -- (in the middle of the middle row, between two of the table's lines, which the empty
   -- table still draws, a row of 22 each under its band of 32)
   put (item 4 of tRect - item 2 of tRect - 32) div 22 into tRows
   exMiddle tObj, item 2 of tRect + 32 + 22 * ((tRows - 1) div 2) + 11
   set the cEmptyHint of field pTable to pTable & "Empty"
end emptyHint

-- Tab stops that share pWidth among the columns of pColumns
private function evenStops pWidth, pColumns
   local tCount, tIndex, tStops
   set the itemDelimiter to tab
   put the number of items of pColumns into tCount
   repeat with tIndex = 1 to tCount - 1
      put round(pWidth * tIndex / tCount) & comma after tStops
   end repeat
   delete the last char of tStops
   return tStops
end evenStops

-- A pill of words on a tint, its left at pLeft; returns its right
private function pill pName, pLeft, pTop, pText, pColor
   local tObj, tWidth
   put lkLabel(pName, lkR(pLeft + 10, pTop + 9, pLeft + 300, pTop + 26), pText, 12, lkMix(pColor, lkColor("ink"), 0.3), empty) into tObj
   set the dontWrap of tObj to true
   put the formattedWidth of tObj into tWidth
   set the width of tObj to tWidth + 4
   set the left of tObj to pLeft + 10
   get lkBox(pName & "Bg", lkR(pLeft, pTop, pLeft + tWidth + 20, pTop + 24), lkMix("255,255,255", pColor, 0.12), 12, empty)
   set the layer of it to the layer of tObj
   return pLeft + tWidth + 20
end pill

-- A soft panel on the white stage of a wide card
private function softPanel pName, pRect
   local tObj
   put lkBox(pName, pRect, lkMix(lkColor("bg"), "255,255,255", 0.35), 14, empty) into tObj
   lkBorder tObj, lkColor("line")
   return tObj
end softPanel

################################################################################
#
# The cards
#

-- The front page: what the tour is, a tile for each chapter, and SQLite at a glance
private command buildStart
   local tObj, tTop, tIndex, tX, tWidth, tLine
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 272), lkColor("sky") & "|" & lkColor("indigo"), \
         "LIVECODE LTD  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "A whole database in one file", \
         "SQLite needs no setup and no server: a whole database is one file. Build one with two linked " & \
         "tables, fill them, join them and keep a picture in them. Each chapter builds on the last."
   -- (narrower than the hero makes it, so that its words end before the sparkles)
   set the rect of field "hero_text" to kLeft + 32, the top of field "hero_text", kLeft + 512, the bottom of field "hero_text"
   exProgramTiles 284, 4, 56, 10
   -- SQLite at a glance, as the original's first card had it
   put 550 into tTop
   get exPanel("Glance", lkR(kLeft, tTop, kRight, kBottom), empty)
   put (kRight - kLeft) div 4 into tWidth
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put line tIndex of exScript("Start/glance") into tLine
      put kLeft + (tIndex - 1) * tWidth into tX
      if tIndex > 1 then
         get lkBox("GlanceRule" & tIndex, lkR(tX, tTop + 16, tX + 1, kBottom - 16), lkColor("line"), 0, empty)
      end if
      get exIcon("GlanceIcon" & tIndex, item 1 of tLine, lkColor("sky"), lkR(tX + 20, tTop + 23, tX + 40, tTop + 43), empty)
      put lkLabel("GlanceTitle" & tIndex, lkR(tX + 52, tTop + 15, tX + tWidth - 8, tTop + 33), item 2 of tLine, 13, lkColor("ink"), empty) into tObj
      set the textStyle of tObj to "bold"
      lkEllipsize tObj
      put lkLabel("GlanceText" & tIndex, lkR(tX + 52, tTop + 34, tX + tWidth - 8, tTop + 50), item 3 of tLine, 12, lkColor("soft"), empty) into tObj
      lkEllipsize tObj
   end repeat
end buildStart

-- About revDB: what it is, then its four commands, each with how it is called and how its
-- error shows
private command buildAbout
   local tObj, tTop, tBottom, tIndex, tLine, tY, tRow, tSky
   go card "About revDB"
   put lkColor("sky") into tSky
   put exPanel("AboutPanel", lkR(kLeft, kTop, kRight, kTop + 100), empty) into tObj
   iconTile "AboutIcon", kLeft + 20, kTop + 20, "layers", tSky
   get heading("AboutTitle", kLeft + 84, kTop + 18, kRight - 24, "One library, many databases")
   put wordsBox("AboutWords", kLeft + 84, kTop + 44, kRight - 28, markup(exScript("About revDB/words")), 13, lkColor("soft")) into tObj
   put the bottom of tObj + 16 into tBottom
   set the rect of graphic "AboutPanel" to kLeft, kTop, kRight, tBottom
   -- the four commands, a row each
   put (kBottom - tBottom - 12 - 3 * 10) div 4 into tRow
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put line tIndex of exScript("About revDB/commands") into tLine
      put tBottom + 12 + (tIndex - 1) * (tRow + 10) into tY
      get exPanel("Command" & tIndex, lkR(kLeft, tY, kRight, tY + tRow), empty)
      iconTile "CommandIcon" & tIndex, kLeft + 18, tY + (tRow - 44) div 2, item 2 of tLine, tSky
      get heading("CommandName" & tIndex, kLeft + 76, tY + (tRow - 58) div 2, 600, item 1 of tLine)
      get wordsBox("CommandText" & tIndex, kLeft + 76, tY + (tRow - 58) div 2 + 24, 560, lkEscape(item 3 of tLine), 13, lkColor("soft"))
      get snippet("CommandCode" & tIndex, 576, tY + (tRow - 60) div 2, kRight - 14, exScript("About revDB/code" & tIndex))
   end repeat
end buildAbout

-- The SQL primer: how SQL sees a database, the table USERS for instance, and six commands
private command buildPrimer
   local tObj, tTop, tIndex, tLine, tY, tSky, tAmber, tRule
   go card "SQL Primer"
   put lkColor("sky") into tSky
   put lkColor("amber") into tAmber
   -- How it works, and the table USERS
   get exPanel("HowPanel", lkR(kLeft, kTop, 620, kBottom), empty)
   iconTile "HowIcon", kLeft + 20, kTop + 20, "square-terminal", tSky
   get heading("HowTitle", kLeft + 76, kTop + 39, 600, "How it works")
   put wordsBox("HowWords", kLeft + 20, kTop + 80, 600, markup(exScript("SQL Primer/words")), 13, lkColor("soft")) into tObj
   put the bottom of tObj + 14 into tTop
   put wordsBox("UsersCaption", kLeft + 20, tTop, 600, markup(exScript("SQL Primer/caption")), 13, lkColor("ink")) into tObj
   put the bottom of tObj + 10 into tTop
   -- the record and the column the legend names, tinted behind the table
   put tableBox("Primer", lkR(kLeft + 20, tTop, 600, tTop + 32 + 4 * 30), "User ID" & tab & "Name" & tab & "Email Address", false, 30) into tObj
   -- (its row lines are drawn, not the field's grid: a field sets each line's words at the
   -- foot of its line, so in a row this tall its grid sits close under the words and far
   -- over them. The field goes up 6 pixels, and the lines go halfway between its rows)
   set the hGrid of tObj to false
   set the rect of tObj to kLeft + 21, tTop + 26, 599, tTop + 32 + 4 * 30 - 2
   set the tabStops of field "PrimerHead" to "70,190"
   set the tabStops of field "Primer" to "70,190"
   set the cHead of field "Primer" to empty
   set the cWheel of field "Primer" to false
   set the text of field "Primer" to exScript("SQL Primer/users")
   get lkBox("PrimerColumn", lkR(kLeft + 21 + 70 + 6, tTop + 1, kLeft + 21 + 190 + 6, tTop + 32 + 4 * 30 - 1), lkMix("255,255,255", tSky, 0.12), 0, empty)
   get lkBox("PrimerRow", lkR(kLeft + 21, tTop + 32 + 30, 599, tTop + 32 + 59), lkMix("255,255,255", tAmber, 0.16), 0, empty)
   repeat with tIndex = 1 to 3
      get lkBox("PrimerLine" & tIndex, lkR(kLeft + 21, tTop + 31 + tIndex * 30, 599, tTop + 32 + tIndex * 30), \
            lkMix(lkColor("line"), "255,255,255", 0.4), 0, empty)
   end repeat
   -- (the column and the row go under the rule, the header and the rows)
   set the layer of graphic "PrimerRule" to top
   set the layer of field "PrimerHead" to top
   set the layer of field "Primer" to top
   put tTop + 32 + 4 * 30 + 14 into tTop
   put pill("LegendRow", kLeft + 20, tTop, "a row: one record", tAmber) into tRule
   get pill("LegendColumn", tRule + 10, tTop, "a column: one kind of information", tSky)
   -- The six commands
   get exPanel("CommandsPanel", lkR(632, kTop, kRight, kBottom), empty)
   get heading("CommandsTitle", 652, kTop + 22, 980, "Six commands")
   put wordsBox("CommandsWords", 652, kTop + 48, 980, markup("SQL has many commands. The tour uses these:"), 13, lkColor("soft")) into tObj
   put the bottom of tObj + 12 into tTop
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 6
      put line tIndex of exScript("SQL Primer/commands") into tLine
      put tTop + (tIndex - 1) * 44 into tY
      get lkBox("Command" & tIndex & "Bg", lkR(652, tY, 778, tY + 34), lkColor("code"), 10, empty)
      put lkLabel("Command" & tIndex, lkR(652, tY + 14, 778, tY + 32), empty, 12, lkColor("codeInk"), empty, "center") into tObj
      set the htmlText of tObj to "<p><b>" & sqlLineOf(item 1 of tLine) & "</b></p>"
      set the cCode of tObj to true
      get wordsBox("CommandText" & tIndex, 792, tY + 14, 984, lkEscape(item 2 of tLine), 13, lkColor("soft"))
   end repeat
   -- a command at work on the table USERS
   put tTop + 5 * 44 + 34 + 14 into tY
   get lkLabel("ExampleCaption", lkR(652, tY, 980, tY + 18), "For instance, on the table USERS:", 12, lkColor("soft"), empty)
   get snippet("Example", 652, tY + 22, 980, exScript("SQL Primer/example"))
   get exButton("Learn SQL", 652, kBottom - 56, kButton, "Learn more SQL", "external-link", "ghost", tSky, empty, empty, 0)
   set the script of group "Learn SQL" to exScript("SQL Primer/Learn SQL")
end buildPrimer

-- The plan: the two tables, their columns and keys, how they link, and the data types
private command buildPlan
   local tObj, tTop, tBottom, tSky, tX, tY, tIndex
   go card "The Plan"
   put lkColor("sky") into tSky
   put wordsBox("PlanWords", kLeft, kTop, kRight, markup(exScript("The Plan/words")), 14, lkColor("soft")) into tObj
   put the bottom of tObj + 14 into tTop
   put tTop + 48 + 4 * 30 + 12 into tBottom
   schemaCard "apps", lkR(kLeft, tTop, 608, tBottom), exScript("The Plan/apps")
   schemaCard "users", lkR(648, tTop, kRight, tBottom), exScript("The Plan/users")
   -- the foreign key: from apps' appUserID to users' userID
   create graphic "KeyLink"
   put it into tObj
   set the style of tObj to "polygon"
   set the filled of tObj to false
   set the lineSize of tObj to 2
   set the foregroundColor of tObj to tSky
   set the antialiased of tObj to true
   set the points of tObj to "608," & (tTop + 48 + 3 * 30 + 15) & return & "628," & (tTop + 48 + 3 * 30 + 15) & return & \
         "628," & (tTop + 48 + 15) & return & "646," & (tTop + 48 + 15)
   set the endArrow of tObj to true
   set the arrowSize of tObj to 4
   -- How they link, for instance
   put tBottom + 12 into tTop
   get exPanel("LinkPanel", lkR(kLeft, tTop, 640, kBottom), empty)
   put wordsBox("LinkWords", kLeft + 20, tTop + 18, 620, markup(exScript("The Plan/link")), 13, lkColor("soft")) into tObj
   put the bottom of tObj + 10 into tY
   -- (8 more than its four rows, so that the last one is not against the
   -- box's foot)
   get tableBox("Example", lkR(kLeft + 20, tY, 620, tY + 32 + 4 * 22 + 9), \
         "appName" & tab & "appRegCode" & tab & "appUserID" & tab & "user", false, 22)
   set the text of field "Example" to exScript("The Plan/example")
   set the cHead of field "Example" to empty
   set the cWheel of field "Example" to false
   -- (appRegCode is the widest heading: its column gets the room the first one does not need)
   set the tabStops of field "ExampleHead" to "78,170,252"
   set the tabStops of field "Example" to "78,170,252"
   set the itemDelimiter to tab
   repeat with tIndex = 1 to 4
      set the textColor of item 4 of line tIndex of field "Example" to codeInk()
   end repeat
   get wordsBox("ExampleNote", kLeft + 20, tY + 32 + 4 * 22 + 19, 620, markup(exScript("The Plan/note")), 12, lkColor("soft"))
   -- The data types
   get exPanel("TypesPanel", lkR(652, tTop, kRight, kBottom), empty)
   put wordsBox("TypesWords", 672, tTop + 18, 980, markup(exScript("The Plan/types")), 13, lkColor("soft")) into tObj
   put 672 into tX
   put the bottom of tObj + 10 into tTop
   set the itemDelimiter to comma
   repeat for each item tObj in "text,integer,date,time,boolean,float,char,double,long,varchar,blob"
      if tX + 70 > 984 then
         put 672 into tX
         add 32 to tTop
      end if
      put pill("Type" & tObj, tX, tTop, tObj, tSky) + 8 into tX
   end repeat
   get wordsBox("TypesNote", 672, tTop + 40, 980, markup(exScript("The Plan/storage")), 12, lkColor("soft"))
end buildPlan

-- A table of the plan, on a white panel: its name, and a row for each of its columns (the
-- block's lines, name|type|what it holds|key or link)
private command schemaCard pTable, pRect, pColumns
   local tObj, tLeft, tTop, tRight, tLine, tIndex, tY, tSky
   put lkColor("sky") into tSky
   put item 1 of pRect into tLeft
   put item 2 of pRect into tTop
   put item 3 of pRect into tRight
   get exPanel(pTable & "Panel", pRect, empty)
   get exIcon(pTable & "Icon", "table", tSky, lkR(tLeft + 18, tTop + 16, tLeft + 38, tTop + 36), empty)
   get heading(pTable & "Name", tLeft + 48, tTop + 23, tLeft + 200, pTable)
   put lkLabel(pTable & "Kind", lkR(tRight - 160, tTop + 23, tRight - 18, tTop + 41), "table, 4 columns", 12, lkColor("soft"), empty, "right") into tObj
   get lkBox(pTable & "Rule", lkR(tLeft + 1, tTop + 47, tRight - 1, tTop + 48), lkColor("line"), 0, empty)
   set the itemDelimiter to "|"
   put 0 into tIndex
   repeat for each line tLine in pColumns
      add 1 to tIndex
      put tTop + 48 + (tIndex - 1) * 30 into tY
      if item 4 of tLine is "key" then
         get exIcon(pTable & "Key" & tIndex, "key-round", lkColor("amber"), lkR(tLeft + 20, tY + 8, tLeft + 34, tY + 22), empty)
      else if item 4 of tLine is "link" then
         get exIcon(pTable & "Key" & tIndex, "link", tSky, lkR(tLeft + 20, tY + 8, tLeft + 34, tY + 22), empty)
      end if
      put lkLabel(pTable & "Column" & tIndex, lkR(tLeft + 44, tY + 12, tLeft + 150, tY + 30), item 1 of tLine, 13, lkColor("ink"), empty) into tObj
      set the textStyle of tObj to "bold"
      set the cCode of tObj to true
      put lkLabel(pTable & "Type" & tIndex, lkR(tLeft + 150, tY + 12, tLeft + 230, tY + 30), item 2 of tLine, 12, codeInk(), empty) into tObj
      set the cCode of tObj to true
      put lkLabel(pTable & "Use" & tIndex, lkR(tLeft + 230, tY + 12, tRight - 14, tY + 30), item 3 of tLine, 12, lkColor("soft"), empty) into tObj
      lkEllipsize tObj
   end repeat
end schemaCard

-- Connect: open (and make) AppRegister, close it, delete its file; and a drawing of the
-- connection, which the stack script keeps up to date
private command buildConnect
   local tTop, tMid, tObj, tSky
   go card "Connect"
   put lkColor("sky") into tSky
   badge
   put lesson("Connect", "Words", kInTop, kInLeft, kInRight) into tTop
   put snippet("Snippet", kInLeft, tTop + 10, kInRight, exScript("Connect/code")) into tTop
   put lesson("Connect", "Words2", tTop + 12, kInLeft, kInRight) into tTop
   get buttonRow("Connect", kInLeft, tTop + 16, \
         "Connect|Connect To AppRegister|plug|primary" & return & \
         "Disconnect|Disconnect|unplug|ghost" & return & \
         "Delete File|Delete Database File|trash-2|ghost")
   put statusBar(tTop + 16 + kButton + 12, "Click Connect To AppRegister to make the database and connect to it.") into tTop
   -- the drawing: your stack, the connection, the database's file
   put tTop + 12 into tTop
   get softPanel("LinkPanel", lkR(kInLeft, tTop, kInRight, kInBottom))
   put (tTop + kInBottom) div 2 - 30 into tMid
   linkNode "LinkStack", 360, tMid, "layers", "Your stack"
   linkNode "LinkBase", 896, tMid, "database", "AppRegister.sqlite"
   create graphic "LinkLine"
   put it into tObj
   set the style of tObj to "line"
   set the lineSize of tObj to 3
   set the antialiased of tObj to true
   set the points of tObj to "406," & tMid & return & "850," & tMid
   set the foregroundColor of tObj to lkColor("muted")
   set the dashes of tObj to "6,6"
   set the layer of tObj to the layer of graphic "LinkStackBox"
   get lkBox("LinkPill", lkR(538, tMid - 14, 718, tMid + 14), "255,255,255", 14, empty)
   lkBorder it, lkColor("line")
   put lkLabel("LinkLabel", lkR(538, tMid - 3, 718, tMid + 14), "not connected", 12, lkColor("soft"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("LinkFile", lkR(kInLeft + 20, tMid + 82, kInRight - 20, tMid + 100), empty, 12, lkColor("soft"), empty, "center") into tObj
   set the dontWrap of tObj to true
   set the cCode of tObj to true
end buildConnect

-- A box with an icon, and its name under it, for the drawing of the connection
private command linkNode pName, pX, pY, pIcon, pLabel
   local tObj
   put lkBox(pName & "Box", lkR(pX - 44, pY - 36, pX + 44, pY + 36), "255,255,255", 18, empty) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 12, 3, 12
   get exIcon(pName & "Icon", pIcon, lkColor("sky"), lkR(pX - 16, pY - 16, pX + 16, pY + 16), empty)
   put lkLabel(pName & "Name", lkR(pX - 110, pY + 44, pX + 110, pY + 62), pLabel, 13, lkColor("ink"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
end linkNode

-- Create Tables: the two CREATE TABLE buttons, and the two tables they make, which say
-- whether the database has them yet
private command buildCreate
   local tTop
   go card "Create Tables"
   badge
   put lesson("Create Tables", "Words", kInTop, kInLeft, kInRight) into tTop
   put snippet("Snippet", kInLeft, tTop + 10, kInRight, exScript("Create Tables/code")) into tTop
   get buttonRow("Create Tables", kInLeft, tTop + 16, \
         "Create Users|Create Table Users|table-properties|primary" & return & \
         "Create Apps|Create Table Apps|table-properties|primary")
   put statusBar(tTop + 16 + kButton + 12, "Click each Create Table button once. Then click one again, to see how an error comes back.") into tTop
   tableCard "users", lkR(kInLeft, tTop + 12, 620, kInBottom), exScript("Create Tables/users"), \
         "CREATE TABLE users(userID integer primary key,name text,email text,emailList boolean)"
   tableCard "apps", lkR(636, tTop + 12, kInRight, kInBottom), exScript("Create Tables/apps"), \
         "CREATE TABLE apps(appID integer primary key,appName text,appRegCode text,appUserID integer)"
end buildCreate

-- A table the Create Tables card draws: its name, whether it is made (the stack script's
-- showTables), its columns with their types, and the SQL its button runs
private command tableCard pTable, pRect, pColumns, pSQL
   local tObj, tLeft, tTop, tRight, tBottom, tHtml, tLine
   put item 1 of pRect into tLeft
   put item 2 of pRect into tTop
   put item 3 of pRect into tRight
   put item 4 of pRect into tBottom
   get softPanel(pTable & "Card", pRect)
   get exIcon(pTable & "Icon", "table", lkColor("sky"), lkR(tLeft + 18, tTop + 16, tLeft + 38, tTop + 36), empty)
   get heading(pTable & "Title", tLeft + 48, tTop + 23, tLeft + 200, pTable)
   put lkBox(pTable & "StateBg", lkR(tRight - 136, tTop + 14, tRight - 16, tTop + 38), "255,255,255", 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel(pTable & "State", lkR(tRight - 136, tTop + 23, tRight - 16, tTop + 40), "not created yet", 12, lkColor("soft"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   set the itemDelimiter to "|"
   repeat for each line tLine in pColumns
      put "<p><b>" & lkEscape(item 1 of tLine) & "</b>" & tab & "<font color=" & quote & lkHex(codeInk()) & quote & ">" & \
            lkEscape(item 2 of tLine) & "</font></p>" after tHtml
   end repeat
   put lkLabel(pTable & "Columns", lkR(tLeft + 20, tTop + 52, tRight - 16, tTop + 52 + 4 * 26), empty, 13, lkColor("ink"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 26
   set the tabStops of tObj to 110
   set the htmlText of tObj to tHtml
   set the cCode of tObj to true
   -- the SQL
   get lkBox(pTable & "SQLBox", lkR(tLeft + 16, tBottom - 78, tRight - 16, tBottom - 14), lkColor("code"), 10, empty)
   put lkLabel(pTable & "SQL", lkR(tLeft + 28, tBottom - 68, tRight - 24, tBottom - 18), empty, 12, lkColor("codeInk"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 16
   set the htmlText of tObj to "<p>" & sqlLineOf(pSQL) & "</p>"
   set the cCode of tObj to true
end tableCard

-- Add Data: INSERT INTO, with the table it fills, which shows the rows as they are now
private command buildAdd
   local tTop, tObj
   go card "Add Data"
   badge
   put lesson("Add Data", "Words", kInTop, kInLeft, kInRight) into tTop
   put snippet("Snippet", kInLeft, tTop + 10, kInRight, exScript("Add Data/code")) into tTop
   put lesson("Add Data", "Words2", tTop + 12, kInLeft, kInRight) into tTop
   get buttonRow("Add Data", kInLeft, tTop + 16, "Add Data|Add Data To Users|list-plus|primary")
   put statusBar(tTop + 16 + kButton + 12, "Click Add Data To Users, as often as you like: the table shows each new row.") into tTop
   put tableBox("Users", lkR(kInLeft, tTop + 12, kInRight, kInBottom), "userID" & tab & "name" & tab & "email" & tab & "emailList", false, 22) into tObj
   set the cQuery of tObj to "SELECT * FROM users"
   emptyHint "Users", "No rows yet: click Add Data To Users"
end buildAdd

-- View and Delete: SELECT and DELETE, and the table they fill
private command buildView
   local tTop
   go card "View and Delete"
   set the script of this card to exScript("View and Delete/card")
   badge
   put lesson("View and Delete", "Words", kInTop, kInLeft, kInRight) into tTop
   put snippet("Snippet", kInLeft, tTop + 10, kInRight, exScript("View and Delete/code")) into tTop
   get buttonRow("View and Delete", kInLeft, tTop + 16, \
         "Refresh Table|Refresh Table|refresh-cw|primary" & return & \
         "Delete Row|Delete Row|trash-2|ghost")
   put statusBar(tTop + 16 + kButton + 12, "Click Refresh Table to show the users table, then choose a row and click Delete Row.") into tTop
   get tableBox("Users", lkR(kInLeft, tTop + 12, kInRight, kInBottom), "userID" & tab & "name" & tab & "email" & tab & "emailList", true, 22)
   emptyHint "Users", "No rows yet: click Refresh Table"
end buildView

-- Update Data: UPDATE, and the table whose cells a click changes
private command buildUpdate
   local tTop, tObj
   go card "Update Data"
   set the script of this card to exScript("Update Data/card")
   badge
   put lesson("Update Data", "Words", kInTop, kInLeft, kInRight) into tTop
   put snippet("Snippet", kInLeft, tTop + 10, kInRight, exScript("Update Data/code")) into tTop
   get exIcon("TipIcon", "lightbulb", lkColor("amber"), lkR(kInLeft, tTop + 13, kInLeft + 18, tTop + 31), empty)
   put lesson("Update Data", "Tip", tTop + 14, kInLeft + 28, kInRight) into tTop
   get buttonRow("Update Data", kInLeft, tTop + 14, "Refresh Table|Refresh Table|refresh-cw|primary")
   put statusBar(tTop + 14 + kButton + 12, "Click Refresh Table, then click any cell of the table to change it.") into tTop
   put tableBox("Users", lkR(kInLeft, tTop + 12, kInRight, kInBottom), "userID" & tab & "name" & tab & "email" & tab & "emailList", true, 22) into tObj
   set the script of tObj to exScript("Update Data/Users")
   emptyHint "Users", "No rows yet: click Refresh Table"
end buildUpdate

-- Both Tables: both tables, each with its own buttons, and the ready-made rows
private command buildBoth pUsers, pApps
   local tTop, tWidth, tObj
   go card "Both Tables"
   set the script of this card to exScript("Both Tables/card")
   badge
   put lesson("Both Tables", "Words", kInTop, kInLeft, 760) into tTop
   put exButton("Default Data", 0, kInTop + 2, kButton, "Default Data", "database", "primary", lkColor("sky"), empty, empty, 0) into tWidth
   set the right of group "Default Data" to kInRight
   set the script of group "Default Data" to exScript("Both Tables/Default Data")
   set the altDefaultUsersData of group "Default Data" to pUsers
   set the altDefaultAppsData of group "Default Data" to pApps
   put max(tTop, kInTop + kButton) + 16 into tTop
   -- the layers go apps, then users: the drawer has chips for a card's first five scripts
   tableSide "Apps", "apps", kInLeft, 620, tTop, "appID" & tab & "appName" & tab & "appRegCode" & tab & "appUserID", "App"
   tableSide "Users", "users", 636, kInRight, tTop, "userID" & tab & "name" & tab & "email" & tab & "emailList", "User"
   get statusBar(kInBottom - 44, "Click Refresh on each table to see what it holds, or Default Data to fill both.")
end buildBoth

-- One table of Both Tables: its name, its three buttons, and the table
private command tableSide pName, pTable, pLeft, pRight, pTop, pColumns, pNoun
   local tX, tWidth
   get heading(pName & "Title", pLeft, pTop + 8, pLeft + 80, pTable)
   put pRight into tX
   put exButton("Delete " & pNoun, 0, pTop, 32, "Delete Row", empty, "ghost", lkColor("sky"), empty, empty, 0) into tWidth
   set the right of group ("Delete " & pNoun) to tX
   subtract tWidth + 8 from tX
   put exButton("Add " & pNoun, 0, pTop, 32, "Add Row", empty, "ghost", lkColor("sky"), empty, empty, 0) into tWidth
   set the right of group ("Add " & pNoun) to tX
   subtract tWidth + 8 from tX
   put exButton("Refresh " & pName, 0, pTop, 32, "Refresh", empty, "ghost", lkColor("sky"), empty, empty, 0) into tWidth
   set the right of group ("Refresh " & pName) to tX
   set the script of group ("Refresh " & pName) to exScript("Both Tables/Refresh " & pName)
   set the script of group ("Add " & pNoun) to exScript("Both Tables/Add " & pNoun)
   set the script of group ("Delete " & pNoun) to exScript("Both Tables/Delete " & pNoun)
   get tableBox(pName, lkR(pLeft, pTop + 44, pRight, kInBottom - 56), pColumns, true, 22)
   emptyHint pName, "No rows yet: click Refresh, or Default Data"
end tableSide

-- Reports: five reports, the join each makes drawn as two circles, the SQL it ran and the
-- records it returned
private command buildReports
   local tTop, tObj, tX
   go card "Reports"
   badge
   put lesson("Reports", "Words", kInTop, kInLeft, 650) into tTop
   venn 820, kInTop + 50
   put buttonRow("Reports", kInLeft, max(tTop, kInTop + 120) + 14, \
         "Inner Join 1|Inner Join 1||ghost" & return & "Inner Join 2|Inner Join 2||ghost" & return & \
         "Inner Join 3|Inner Join 3||ghost" & return & "Outer Join 1|Outer Join 1||ghost" & return & \
         "Outer Join 2|Outer Join 2||ghost") into tX
   put max(tTop, kInTop + 120) + 14 + kButton + 12 into tTop
   put statusBar(tTop, "Click a report to run it. No rows? Go back a chapter and click Default Data.") into tTop
   add 12 to tTop
   get lkBox("ReportSQLBox", lkR(kInLeft, tTop, 616, kInBottom), lkColor("code"), 12, empty)
   put lkLabel("ReportSQL", lkR(kInLeft + 14, tTop + 12, 608, kInBottom - 8), empty, 12, lkColor("codeInk"), empty) into tObj
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to kCodeLine
   set the text of tObj to "--The SQL of the report you run" & return & "--shows here, a clause a line."
   set the cCode of tObj to true
   set the cSQL of tObj to true
   get tableBox("Report", lkR(632, tTop, kInRight, kInBottom), "name" & tab & "app", false, 22)
   emptyHint "Report", "No rows yet: click a report"
end buildReports

-- Two circles, users and apps, and where they meet: the stack script's showReport fills
-- what the report's join keeps
private command venn pX, pY
   local tObj, tR, tD, tLeft, tRight, tAlpha, tStep, tAngle, tPoints, tSky
   put lkColor("sky") into tSky
   put 46 into tR
   put 54 into tD
   put pX - tD / 2 into tLeft
   put pX + tD / 2 into tRight
   put lkOval("VennLeft", lkR(round(tLeft - tR), pY - tR, round(tLeft + tR), pY + tR), lkMix("255,255,255", tSky, 0.08), empty) into tObj
   lkBorder tObj, lkMix("255,255,255", tSky, 0.55)
   put lkOval("VennRight", lkR(round(tRight - tR), pY - tR, round(tRight + tR), pY + tR), lkMix("255,255,255", tSky, 0.08), empty) into tObj
   lkBorder tObj, lkMix("255,255,255", tSky, 0.55)
   -- the lens where they meet: the left circle's right arc, then the right circle's left one
   put acos((tD / 2) / tR) into tAlpha
   repeat with tStep = 0 to 24
      put -tAlpha + 2 * tAlpha * tStep / 24 into tAngle
      put round(tLeft + tR * cos(tAngle)) & "," & round(pY + tR * sin(tAngle)) & return after tPoints
   end repeat
   repeat with tStep = 0 to 24
      put pi - tAlpha + 2 * tAlpha * tStep / 24 into tAngle
      put round(tRight + tR * cos(tAngle)) & "," & round(pY + tR * sin(tAngle)) & return after tPoints
   end repeat
   delete the last char of tPoints
   put lkBox("VennLens", lkR(0, 0, 10, 10), lkMix("255,255,255", tSky, 0.3), 0, empty) into tObj
   set the style of tObj to "polygon"
   set the points of tObj to tPoints
   set the lineSize of tObj to 0
   -- (each name in the middle of the part of its circle the other does not cover)
   put lkLabel("VennUsers", lkR(round(tLeft - tR) + 2, pY - 3, round(tRight - tR) - 2, pY + 14), "users", 12, lkColor("ink"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("VennApps", lkR(round(tLeft + tR) + 2, pY - 3, round(tRight + tR) - 2, pY + 14), "apps", 12, lkColor("ink"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("VennCaption", lkR(pX - 160, pY + tR + 10, pX + 160, pY + tR + 28), "Two tables, and the rows where they meet.", 12, lkColor("soft"), empty, "center") into tObj
end venn

-- The Schema: sqlite_master, DROP TABLE, and the schema the button lists
private command buildSchema pUsers, pApps
   local tTop, tObj
   go card "The Schema"
   badge
   put lesson("The Schema", "Words", kInTop, kInLeft, kInRight) into tTop
   put snippet("Snippet", kInLeft, tTop + 10, kInRight, exScript("The Schema/code")) into tTop
   get buttonRow("The Schema", kInLeft, tTop + 16, \
         "Show Schema|Show the Schema|file-code|primary" & return & \
         "Delete Users|Delete Users Table|trash-2|ghost" & return & \
         "Default Data|Default Data|database|ghost")
   set the altDefaultUsersData of group "Default Data" to pUsers
   set the altDefaultAppsData of group "Default Data" to pApps
   put statusBar(tTop + 16 + kButton + 12, "Click Show the Schema. Click Delete Users Table twice, to see the error the second time.") into tTop
   add 12 to tTop
   get lkBox("SchemaBox", lkR(kInLeft, tTop, kInRight, kInBottom), lkColor("code"), 12, empty)
   put lkLabel("Schema", lkR(kInLeft + 14, tTop + 12, kInRight - 8, kInBottom - 8), empty, 12, lkColor("codeInk"), empty) into tObj
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to kCodeLine
   set the text of tObj to exScript("The Schema/schema")
   set the cCode of tObj to true
   set the cSQL of tObj to true
   set the cWheel of tObj to true
end buildSchema

-- Columns: the six steps, the example of t1, and the buttons that rebuild users, with the
-- new schema and the new table
private command buildColumns pUsers, pApps
   local tTop, tObj, tLine, tIndex, tCode
   go card "Columns"
   badge
   -- the steps, at the left
   put lesson("Columns", "Words", kInTop, kInLeft, 600) into tTop
   put 0 into tIndex
   repeat for each line tLine in exScript("Columns/steps")
      add 1 to tIndex
      get lkOval("Step" & tIndex & "Bg", lkR(kInLeft, tTop + 10 + (tIndex - 1) * 24, kInLeft + 20, tTop + 30 + (tIndex - 1) * 24), \
            lkMix("255,255,255", lkColor("sky"), 0.14), empty)
      put lkLabel("Step" & tIndex & "Number", lkR(kInLeft, tTop + 19 + (tIndex - 1) * 24, kInLeft + 20, tTop + 34 + (tIndex - 1) * 24), \
            tIndex, 11, codeInk(), empty, "center") into tObj
      set the textStyle of tObj to "bold"
      get lkLabel("Step" & tIndex, lkR(kInLeft + 30, tTop + 17 + (tIndex - 1) * 24, 610, tTop + 35 + (tIndex - 1) * 24), tLine, 13, lkColor("soft"), empty)
   end repeat
   -- the example, at the right
   put lkLabel("ExampleCaption", lkR(624, kInTop, kInRight, kInTop + 18), "To delete column c from a table t1(a,b,c):", 12, lkColor("soft"), empty) into tObj
   put snippet("Snippet", 624, kInTop + 24, kInRight, exScript("Columns/code")) into tCode
   put max(tTop + 10 + 6 * 24, tCode) into tTop
   put lesson("Columns", "Words2", tTop + 12, kInLeft, kInRight) into tTop
   get buttonRow("Columns", kInLeft, tTop + 14, \
         "Delete Columns|Delete Columns|columns-3|primary" & return & \
         "Add Columns|Add Columns|plus|primary" & return & \
         "Default Data|Default Data|database|ghost")
   set the altDefaultUsersData of group "Default Data" to pUsers
   set the altDefaultAppsData of group "Default Data" to pApps
   put statusBar(tTop + 14 + kButton + 12, "Click Delete Columns. Then Default Data, which puts them back, and Add Columns.") into tTop
   add 12 to tTop
   -- the schema, and the table users, as they are now
   get lkBox("SchemaBox", lkR(kInLeft, tTop, 560, kInBottom), lkColor("code"), 12, empty)
   put lkLabel("Schema", lkR(kInLeft + 12, tTop + 10, 552, kInBottom - 6), empty, 11, lkColor("codeInk"), empty) into tObj
   set the cCode of tObj to true
   set the cSQL of tObj to true
   set the cWheel of tObj to true
   set the cQuery of tObj to "SELECT sql FROM sqlite_master"
   set the cEmpty of tObj to "--The schema shows here" & return & "--when you are connected."
   put tableBox("Users", lkR(572, tTop, kInRight, kInBottom), "userID" & tab & "name" & tab & "email" & tab & "emailList", false, 22) into tObj
   set the cQuery of tObj to "SELECT * FROM users"
   set the cTable of tObj to "users"
   emptyHint "Users", "No rows yet: click Default Data"
end buildColumns

-- Binary Data: a BLOB column, the picture that goes in (Icon1, from the original), the row
-- it makes, and the picture that comes back (Icon2)
private command buildBinary pIcon
   local tTop, tObj, tMid
   go card "Binary Data"
   badge
   put lesson("Binary Data", "Words", kInTop, kInLeft, kInRight) into tTop
   put snippet("Snippet", kInLeft, tTop + 10, kInRight, exScript("Binary Data/code")) into tTop
   get buttonRow("Binary Data", kInLeft, tTop + 16, \
         "Insert|Insert Binary Data|binary|primary" & return & \
         "Retrieve|Retrieve Binary Data|image|primary" & return & \
         "Reset Icon2|Reset Icon2|x|ghost")
   put statusBar(tTop + 16 + kButton + 12, "Click Insert Binary Data, then Retrieve Binary Data. Both work in BinaryTest.sqlite.") into tTop
   add 12 to tTop
   put (tTop + kInBottom) div 2 - 8 into tMid
   pictureTile "Icon1", 340, tMid, "Icon1: goes in"
   create image "Icon1"
   put it into tObj
   set the text of tObj to pIcon
   set the lockLoc of tObj to true
   set the resizeQuality of tObj to "normal"
   set the rect of tObj to 308, tMid - 32, 372, tMid + 32
   pictureTile "Icon2", 916, tMid, "Icon2: comes back"
   create image "Icon2"
   put it into tObj
   set the lockLoc of tObj to true
   set the resizeQuality of tObj to "normal"
   set the rect of tObj to 884, tMid - 32, 948, tMid + 32
   get exIcon("Arrow1", "arrow-right", lkColor("muted"), lkR(412, tMid - 10, 432, tMid + 10), empty)
   get exIcon("Arrow2", "arrow-right", lkColor("muted"), lkR(824, tMid - 10, 844, tMid + 10), empty)
   get tableBox("Example", lkR(446, tTop, 810, kInBottom - 26), "name" & tab & "email", false, 22)
   put lkLabel("ExampleNote", lkR(446, kInBottom - 20, 810, kInBottom - 4), \
         "table example in BinaryTest.sqlite, and its icon column, a BLOB", 12, lkColor("muted"), empty, "center") into tObj
end buildBinary

-- A white tile for a picture, its dashed outline and its name under it
private command pictureTile pName, pX, pY, pLabel
   local tObj
   put lkBox(pName & "Tile", lkR(pX - 56, pY - 52, pX + 56, pY + 52), "255,255,255", 16, empty) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 12, 3, 10
   put lkBox(pName & "Frame", lkR(pX - 36, pY - 36, pX + 36, pY + 36), empty, 8, empty) into tObj
   lkBorder tObj, lkMix(lkColor("line"), lkColor("muted"), 0.4)
   set the dashes of tObj to "4,4"
   put lkLabel(pName & "Name", lkR(pX - 80, pY + 58, pX + 80, pY + 76), pLabel, 12, lkColor("soft"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
end pictureTile

-- All Done: what you can do now, where to go next, and the original's reference
private command buildDone
   local tObj, tTop, tSky, tWidth, tIndex, tCount
   go card "All Done"
   put lkColor("sky") into tSky
   -- the banner
   put lkBox("DoneBanner", lkR(kLeft, kTop, 604, 300), tSky, 18, empty) into tObj
   lkGradient tObj, lkColor("sky") & "|" & lkColor("indigo"), kLeft & "," & kTop, "604,300"
   lkShadow tObj, 16, 4, 16
   get exIcon("DoneIcon", "party-popper", "255,255,255", lkR(kLeft + 24, kTop + 24, kLeft + 56, kTop + 56), empty)
   put lkLabel("DoneTitle", lkR(kLeft + 24, kTop + 72, 580, kTop + 104), "You did it", 24, "255,255,255", empty) into tObj
   set the textStyle of tObj to "bold"
   get wordsBox("DoneWords", kLeft + 24, kTop + 112, 580, markup(exScript("All Done/banner")), 14, "255,255,255")
   -- what next
   get exPanel("NextPanel", lkR(kLeft, 312, 604, kBottom), empty)
   iconTile "NextIcon", kLeft + 20, 332, "rocket", tSky
   get heading("NextTitle", kLeft + 76, 351, 590, "Start coding with SQLite")
   put wordsBox("NextWords", kLeft + 20, 392, 584, markup(exScript("All Done/words")), 13, lkColor("soft")) into tObj
   put exButton("SQLite Site", kLeft + 20, kBottom - 56, kButton, "sqlite.org", "external-link", "ghost", tSky, empty, empty, 0) into tWidth
   set the script of group "SQLite Site" to exScript("All Done/SQLite Site")
   get exButton("Learn SQL", kLeft + 30 + tWidth, kBottom - 56, kButton, "Learn more SQL", "external-link", "ghost", tSky, empty, empty, 0)
   set the script of group "Learn SQL" to exScript("All Done/Learn SQL")
   -- the reference, as the original's last card had it
   put lkBox("ReferenceBox", lkR(620, kTop, kRight, kBottom), lkColor("code"), 18, empty) into tObj
   lkShadow tObj, 18, 6, 30
   put lkLabel("ReferenceTitle", lkR(640, kTop + 20, 860, kTop + 38), "SQLite reference", 15, "255,255,255", empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("ReferenceHint", lkR(640, kTop + 42, 860, kTop + 58), "the wheel scrolls it", 11, lkColor("muted"), empty) into tObj
   put exButton("Copy Reference", 0, kTop + 18, 32, "Copy", "copy", "dark", tSky, empty, empty, 0) into tWidth
   set the right of group "Copy Reference" to kRight - 18
   set the script of group "Copy Reference" to exScript("All Done/Copy Reference")
   put lkLabel("Reference", lkR(636, kTop + 72, kRight - 12, kBottom - 14), empty, 12, lkColor("codeInk"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to kCodeLine
   set the htmlText of tObj to codeHtml(exScript("All Done/reference"))
   -- (a line too long for the panel goes on below, further in)
   put the number of lines of field "Reference" into tCount
   repeat with tIndex = 1 to tCount
      set the leftIndent of line tIndex of field "Reference" to 21
      set the firstIndent of line tIndex of field "Reference" to -21
   end repeat
   set the cCode of tObj to true
   set the cWheel of tObj to true
   -- (more below: the panel fades out at its foot)
   put lkBox("ReferenceFade", lkR(621, kBottom - 44, kRight - 1, kBottom - 14), lkColor("code"), 0, empty) into tObj
   set the fillGradient["type"] of tObj to "linear"
   set the fillGradient["ramp"] of tObj to "0.000," & lkColor("code") & ",0" & return & "1.000," & lkColor("code") & ",255"
   lkGradientPoints tObj, "621," & (kBottom - 44), "621," & (kBottom - 14)
end buildDone

################################################################################
#
# Words for the cards
#

/*@ icons
plug|<path d='M12 22v-5'/><path d='M9 8V2'/><path d='M15 8V2'/><path d='M18 8v5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8Z'/>
unplug|<path d='m19 5 3-3'/><path d='m2 22 3-3'/><path d='M6.3 20.3a2.4 2.4 0 0 0 3.4 0L12 18l-6-6-2.3 2.3a2.4 2.4 0 0 0 0 3.4Z'/><path d='M7.5 13.5 10 11'/><path d='M10.5 16.5 13 14'/><path d='m12 6 6 6 2.3-2.3a2.4 2.4 0 0 0 0-3.4l-2.6-2.6a2.4 2.4 0 0 0-3.4 0Z'/>
trash-2|<path d='M3 6h18'/><path d='M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6'/><path d='M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2'/><line x1='10' x2='10' y1='11' y2='17'/><line x1='14' x2='14' y1='11' y2='17'/>
list-plus|<path d='M11 12H3'/><path d='M16 6H3'/><path d='M16 18H3'/><path d='M18 9v6'/><path d='M21 12h-6'/>
list-x|<path d='M11 12H3'/><path d='M16 6H3'/><path d='M16 18H3'/><path d='m19 10-4 4'/><path d='m15 10 4 4'/>
link|<path d='M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71'/><path d='M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71'/>
git-merge|<circle cx='18' cy='18' r='3'/><circle cx='6' cy='6' r='3'/><path d='M6 21V9a9 9 0 0 0 9 9'/>
file-code|<path d='M10 12.5 8 15l2 2.5'/><path d='m14 12.5 2 2.5-2 2.5'/><path d='M14 2v4a2 2 0 0 0 2 2h4'/><path d='M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z'/>
columns-3|<rect width='18' height='18' x='3' y='3' rx='2'/><path d='M9 3v18'/><path d='M15 3v18'/>
binary|<rect x='14' y='14' width='4' height='6' rx='2'/><rect x='6' y='4' width='4' height='6' rx='2'/><path d='M6 20h4'/><path d='M14 10h4'/><path d='M6 14h2v6'/><path d='M14 4h2v6'/>
party-popper|<path d='M5.8 11.3 2 22l10.7-3.79'/><path d='M4 3h.01'/><path d='M22 8h.01'/><path d='M15 2h.01'/><path d='M22 20h.01'/><path d='m22 2-2.24.75a2.9 2.9 0 0 0-1.96 3.12c.1.86-.57 1.63-1.45 1.63h-.38c-.86 0-1.6.6-1.76 1.44L14 10'/><path d='m22 13-.82-.33c-.86-.34-1.82.2-1.98 1.11c-.11.7-.72 1.22-1.43 1.22H17'/><path d='m11 2 .33.82c.34.86-.2 1.82-1.11 1.98C9.52 4.9 9 5.52 9 6.23V7'/><path d='M11 13c1.93 1.93 2.83 4.17 2 5-.83.83-3.07-.07-5-2-1.93-1.93-2.83-4.17-2-5 .83-.83 3.07.07 5 2Z'/>
key-round|<path d='M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 1.414-.586l.814-.814a6.5 6.5 0 1 0-4-4z'/><circle cx='16.5' cy='7.5' r='.5' fill='currentColor'/>
refresh-cw|<path d='M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8'/><path d='M21 3v5h-5'/><path d='M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16'/><path d='M8 16H3v5'/>
plus|<path d='M5 12h14'/><path d='M12 5v14'/>
circle-check|<circle cx='12' cy='12' r='10'/><path d='m9 12 2 2 4-4'/>
circle-alert|<circle cx='12' cy='12' r='10'/><line x1='12' x2='12' y1='8' y2='12'/><line x1='12' x2='12.01' y1='16' y2='16'/>
table-properties|<path d='M15 3v18'/><rect width='18' height='18' x='3' y='3' rx='2'/><path d='M21 9H3'/><path d='M21 15H3'/>
@*/

/*@ Start/glance
zap|No setup|Nothing to install
rocket|Fast and compact|Up to terabytes of data
hard-drive|One file|Copy it anywhere
database|Room to grow|Can move to MySQL
@*/

/*@ About revDB/words
xTalk talks to databases through revDB, a library built into the engine, with the same commands for SQLite, MySQL, PostgreSQL and more. These four are all a very capable database app needs.
A query's rows come back as a **data list**, plain text with a row on each line, or as a **record set**, which you step through. Data lists are simpler for small databases, so the tour uses them; only the picture in its last chapter needs a record set.
@*/

/*@ About revDB/commands
revOpenDatabase|plug|Connects to a database, and makes its file if it is not there yet.
revExecuteSQL|play|Runs SQL that returns no rows, such as INSERT or DROP.
revDataFromQuery|table|Runs a query, and returns the rows it finds as a list.
revCloseDatabase|unplug|Disconnects from the database when you are done with it.
@*/

/*@ About revDB/code1
put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
if the result is not an integer then --an error
@*/

/*@ About revDB/code2
revExecuteSQL tConID,tSQL --[,variablesList]
if the result is not an integer then --an error
@*/

/*@ About revDB/code3
put revDataFromQuery(,,tConID,tSQL) into tList
if "revdberr" is in the result then --an error
@*/

/*@ About revDB/code4
revCloseDatabase tConID
if "revdberr" is in the result then --an error
@*/

/*@ SQL Primer/words
SQL, the Structured Query Language, is how you talk to a database and control it. A database like SQLite keeps its data in tables, each with a name of its own.
Each record is a row of a table, and each column holds one kind of information, named for what it holds.
@*/

/*@ SQL Primer/caption
For instance, the table **USERS** has three columns, User ID, Name and Email Address, and four records:
@*/

/*@ SQL Primer/users
1	John Smith	john@ibm.com
2	Frank Jones	frank@yahoo.com
3	Sarah Daniels	sd@google.com
4	Jane Shafer	jane@hotmail.com
@*/

/*@ SQL Primer/commands
SELECT|reads data from a table
UPDATE|changes data in a table
DELETE|deletes rows from a table
INSERT INTO|adds new rows to a table
CREATE TABLE|makes a new table
DROP TABLE|deletes a whole table
@*/

/*@ SQL Primer/example
SELECT Email FROM USERS
WHERE Name = 'Jane Shafer'
--gives jane@hotmail.com
@*/

/*@ The Plan/words
The tour builds **AppRegister**, a database of the people who registered a company's apps, so that you can see what anyone bought and send them their registration code. It has two tables, **apps** and **users**: one user can have many apps, and each app's row points back to its user. That link makes it a relational database.
@*/

/*@ The Plan/apps
appID|integer|a unique number|key
appName|text|the app's name|
appRegCode|text|its registration code|
appUserID|integer|who registered it|link
@*/

/*@ The Plan/users
userID|integer|a unique number|key
name|text|the user's name|
email|text|their email|
emailList|boolean|on our email list|
@*/

/*@ The Plan/link
**How they link.** Each app's appUserID is the userID of the user it is registered to: a foreign key. One user, many apps (one to many); many apps, one user (many to one).
@*/

/*@ The Plan/example
AppRed	RX1234	1	John Smith
AppBlue	BX2345	1	John Smith
AppGreen	GX3456	1	John Smith
AppRed	RX4567	2	Frank Jones
@*/

/*@ The Plan/note
The first three apps point to user 1, John Smith, and the last to user 2, Frank Jones.
@*/

/*@ The Plan/storage
SQLite itself keeps each value as NULL, INTEGER, REAL, TEXT or BLOB, and fits the other type names to these.
@*/

/*@ The Plan/types
**Data types.** Typing each column is not required, but it is good practice, and a column of binary data, such as a picture, must be BLOB. revDB knows these:
@*/

/*@ Connect/words
SQLite comes built in: there is nothing to install or manage. Each database is a file of its own, and connecting to a file that is not there yet makes it. One command does both:
@*/

/*@ Connect/code
put specialFolderPath("temporary") & "/AppRegister.sqlite" into tPath
put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
@*/

/*@ Connect/words2
**Connect To AppRegister** says the connection ID, which the tour keeps in the global `gConID` for the next chapters. **Disconnect** closes the connection, and **Delete Database File** starts again from nothing.
@*/

/*@ Create Tables/words
AppRegister is open, but it has no tables yet. CREATE TABLE makes one: the table's name, then each column's name and type, in brackets.
@*/

/*@ Create Tables/code
put "CREATE TABLE <table name>(<column1 column1type>,<column2 column2type>...)" into tSQL
revExecuteSQL <connectionID>, tSQL
@*/

/*@ Create Tables/users
userID|integer primary key
name|text
email|text
emailList|boolean
@*/

/*@ Create Tables/apps
appID|integer primary key
appName|text
appRegCode|text
appUserID|integer
@*/

/*@ Add Data/words
INSERT INTO adds a row to a table. Give null for the primary key, and SQLite numbers the row for you:
@*/

/*@ Add Data/code
put "INSERT INTO <table>(<col1>,<col2>...) VALUES(<col1 value>,<col 2 value>...)" into tSQL
revExecuteSQL <connectionID>, tSQL
@*/

/*@ Add Data/words2
**Add Data To Users** asks for a name and an email, then whether they want the email list. Its function `cleanSQL` doubles each single quote, so that a name like O'Brien cannot break the SQL.
@*/

/*@ View and Delete/words
SELECT reads rows from a table, and `revDataFromQuery` gives them to you as a list. DELETE removes the rows its WHERE clause picks.
@*/

/*@ View and Delete/code
put "SELECT * FROM <table_name>" into tSQL  --select all records
put revDataFromQuery(,,gConID,tSQL) into tList  --the delimiters are tab and cr by default

put "DELETE FROM <table_name> WHERE <column_name> = <value>" into tSQL
revExecuteSQL <connectionID>,tSQL
@*/

/*@ Update Data/words
UPDATE changes rows that are already there: SET gives a column its new value, and WHERE picks the rows.
@*/

/*@ Update Data/code
put "UPDATE <table_name> SET <col1name>=<value1>,<col2name>=<value2>..." && \
      "WHERE <column_name> = <some_value>" into tSQL
revExecuteSQL <connectionID>,tSQL
@*/

/*@ Update Data/tip
Use `revExecuteSQL` to run SQL that returns no rows, and `revDataFromQuery` to run a query whose rows you want back.
@*/

/*@ Both Tables/words
Here are both tables. Fill them with rows of your own for the reports in the next chapter, or click **Default Data** for ready-made ones. Each app's appUserID must be the userID of someone in users, and nothing checks that for you: if you are unsure, use Default Data.
@*/

/*@ Reports/words
A join links two tables in one query. An **inner join** keeps only the rows that match in both; a **left outer join** keeps every row of the first table, with what matches in the second, if anything (a right join is the same, the tables swapped). In `users.userID` the dot joins a table and its column.
@*/

/*@ The Schema/words
A database's schema is its structure: its tables and their columns, without the data. It is the CREATE TABLE commands that made it, and SQLite keeps them in **sqlite_master**, a read-only table of its own with five columns: type, name, tbl_name, rootpage and sql. DROP TABLE deletes a table: its rows and its schema.
@*/

/*@ The Schema/code
put "SELECT sql FROM sqlite_master" into tSQL
put revDataFromQuery(,,<connectionID>,tSQL) into tList

put "DROP TABLE users" into tSQL
revExecuteSQL <connectionID>,tSQL
@*/

/*@ The Schema/schema
--Show the Schema lists the CREATE TABLE commands here, such as the apps table's:
CREATE TABLE apps(appID integer primary key,appName text,appRegCode text,appUserID integer)
@*/

/*@ Columns/words
Older SQLite could not change a table's columns in place, so you rebuild the table, in six steps and one transaction:
@*/

/*@ Columns/steps
Create a temporary table with the new columns
Copy the data of the old table into it
Drop (delete) the old table
Create the new table with the columns you want
Copy the data from the temporary table into it
Drop the temporary table
@*/

/*@ Columns/code
BEGIN TRANSACTION;
CREATE TEMPORARY TABLE t1_temp(a,b);
INSERT INTO t1_temp SELECT a,b FROM t1;
DROP TABLE t1;
CREATE TABLE t1(a,b);
INSERT INTO t1 SELECT a,b FROM t1_temp;
DROP TABLE t1_temp;
COMMIT;
@*/

/*@ Columns/words2
Semicolons separate the statements, so one `revExecuteSQL` runs them all. Newer SQLite, like OXT-Beyond's, can also do it in a line: `ALTER TABLE users ADD COLUMN city text`, or `DROP COLUMN city`.
@*/

/*@ Binary Data/words
SQLite keeps binary data, such as a picture, in a column of type BLOB. In the INSERT, `:1`, `:2` and `:3` stand for the variables named after the SQL, and the name of one that holds binary data begins with `*b`. To read it back, `revQueryDatabase` gives a record set, and `revDatabaseColumnNamed` puts its column into a variable.
@*/

/*@ Binary Data/code
CREATE TABLE example(id INTEGER PRIMARY KEY AUTOINCREMENT,
   name TEXT NULL,email TEXT NULL,icon BLOB NULL)
put "INSERT INTO example(name,email,icon) VALUES (:1,:2,:3)" into tSQL
revExecuteSQL gConID,tSQL,"tName","tEmail","*btIcon"  --quoted variables, *b for binary data
put revQueryDatabase(gConID,"SELECT icon FROM example WHERE id=1") into tRecordSetID
put revDatabaseColumnNamed(tRecordSetID,"icon","tIcon") into tTemp  --tIcon gets the data
@*/

/*@ All Done/banner
You can make a database with tables, add, change and delete its rows, join its tables in reports and change its schema: about all that a database app needs.
@*/

/*@ All Done/words
SQLite speaks standard SQL, so a database can move to a hosted MySQL server later with little more than a new connection string. That is one of the many reasons database coders like it.
Every chapter's program stays in its buttons: open a chapter's Scripts drawer to read it again.
Thanks for taking the SQLite tour.
@*/

/*@ All Done/reference
revOpenDatabase("sqlite",[filepath],,,,,,)  --error: the result is not an integer
revExecuteSQL databaseID,SQLQuery[,variablesList]  --error: the result is not an integer
revCloseDatabase databaseID  --error: "revdberr" is in the result
revDataFromQuery([columnDelim],[rowDelim], databaseID,SQLQuery[, varsList])  --error: "revdberr" is in the result
----
put specialFolderPath("documents") & "/AppRegister.sqlite" into tPath  --a folder you can write to
put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
----
put "CREATE TABLE users(userID integer primary key,name text,email text,emailList boolean)" into tSQL
revExecuteSQL gConID,tSQL
----
put "DROP TABLE users" into tSQL
revExecuteSQL gConID,tSQL
----
put "INSERT INTO users(userID,name,email,emailList) VALUES (null," & tRowData & ")" into tSQL
put "INSERT INTO books(Author,Title) VALUES ('Tolkien J','Lord Of The Rings')" into tSQL
put "INSERT INTO books(Author,Title) VALUES (" &quote& pAuthor &quote& comma &quote& pTitle &quote& ")" into tSQL
revExecuteSQL gConID,tSQL
----
put "INSERT INTO example(name,email,icon) VALUES (:1,:2,:3)" into tSQL
revExecuteSQL gConID,tSQL,"tName","tEmail","*btIcon"  --insert binary
----
put "DELETE FROM users WHERE userID=" & tUserID into tSQL
put "DELETE FROM books WHERE BookID = '" & pID & "'" into tSQL
revExecuteSQL gConID,tSQL
----
put "SELECT * FROM users" into tSQL  --select all
put "SELECT * FROM books WHERE author LIKE '%" &pSearchTerm& "%' OR title LIKE '%" &pSearchTerm& "%'" into tSQL
put revDataFromQuery(tab,cr,gConID,tSQL) into tList
----
put "SELECT users.Name, apps.appName FROM users,apps WHERE users.userID=apps.appUserID" into tSQL  --inner join
put revDataFromQuery(,,gConID,tSQL) into tList
----
put "SELECT icon FROM example WHERE id=1" into tSQL  --first row of table,retrieve binary
put revQueryDatabase(gConID,tSQL) into tRecordSetID  --retrieve binary
put revDatabaseColumnNamed(tRecordSetID, "icon","tIcon") into tTemp  --retrieve binary
if there is an image "Icon2" then set the text of image "Icon2" to tIcon  --display binary data
revCloseCursor tRecordSetID  --done with the record set
----
@*/

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--A Tour of SQLite: LiveCode Ltd's SQLite Tour v1.0, remastered for OXT-Beyond in 2026
--SQLite Tour v1.0, (c) LiveCode Ltd, edited and debranded for open source as requested by LiveCode Ltd.

--Each chapter's program is in the scripts of its buttons (and, on a few, of its card): click
--a button, or open the Scripts drawer, to read them. Where the original tour answered in a
--dialog, they say what happened in the panel under the buttons, with showResult, below, and
--the tables, the schema and the drawings they fill are brought up to date here too.
--The tour's databases are files in the temporary folder, which a program can always write
--to. (The original kept them on the desktop: the remaster sits in the IDE's Resources
--folder, which may be read-only, and a browser has no desktop.)
--The original's openCard put each card's name into its title and its chapter slider: the
--window's sidebar and header do that now, in the script of the group "Frame".

global gConID  --the connection to the database, as the tour's scripts keep it

local sCodeFont  --the font code is shown in, found once

on preOpenCard
   codeFonts
   if there is a field "Status" then
      showResult "info", the cHint of this card  --each visit starts with the card's hint
   end if
   pass preOpenCard
end preOpenCard

################################################################################
# What the buttons did

-- In the panel under the buttons: pKind is "ok", "error" or "info", and pMessage what
-- happened, its first line in bold. Then the card is brought up to date with the database
command showResult pKind, pMessage
   local tHtml, tLine, tBack, tEdge, tMid, tHeight
   if there is no field "Status" then
      answer pMessage  --(a card without the panel)
      exit showResult
   end if
   lock screen
   repeat for each line tLine in pMessage
      if tHtml is empty then
         put "<p><b>" & htmlOf(tLine) & "</b></p>" after tHtml
      else
         put "<p>" & htmlOf(tLine) & "</p>" after tHtml
      end if
   end repeat
   hide image "StatusOk"
   hide image "StatusError"
   hide image "StatusInfo"
   switch pKind
      case "ok"
         show image "StatusOk"
         put the cOkBack of this stack into tBack
         put the cOkEdge of this stack into tEdge
         break
      case "error"
         show image "StatusError"
         put the cErrorBack of this stack into tBack
         put the cErrorEdge of this stack into tEdge
         break
      default
         show image "StatusInfo"
         put the cInfoBack of this stack into tBack
         put the cInfoEdge of this stack into tEdge
   end switch
   set the backgroundColor of graphic "StatusBg" to tBack
   set the foregroundColor of graphic "StatusBg" to tEdge
   set the htmlText of field "Status" to tHtml
   -- (a line or two, in the middle of the panel)
   put item 2 of the loc of graphic "StatusBg" into tMid
   put the formattedHeight of field "Status" into tHeight
   -- (taller than its words by a few pixels, so that no descender is cut)
   set the rect of field "Status" to item 1 of the rect of field "Status", tMid - tHeight div 2 - 2, \
         item 3 of the rect of field "Status", tMid - tHeight div 2 + tHeight + 6
   showCard
   unlock screen
end showResult

-- The card, as the database is now
command showCard
   showConnection
   showTables
   showLive
   showReport
   showSQL
   fitTables
   showEmpty
end showCard

################################################################################
# The connection

-- The database the tour is connected to, by the name of its file: in the badge at the top,
-- and in the Connect card's drawing
command showConnection
   local tFile, tName, tOn
   put connectedFile() into tFile
   put tFile is not empty into tOn
   set the itemDelimiter to slash
   put the last item of tFile into tName
   if there is a field "Badge" then
      if tOn then
         set the text of field "Badge" to tName & ", ID" && gConID
      else
         set the text of field "Badge" to "Not connected"
      end if
      lightBadge tOn
   end if
   if there is a graphic "LinkLine" then
      drawLink tOn, tFile
   end if
end showConnection

-- The path of the file of the database gConID is connected to, or empty
function connectedFile
   local tList, tError
   if gConID is empty then
      return empty
   end if
   try
      put revDataFromQuery(tab, return, gConID, "PRAGMA database_list") into tList
   catch tError
      return empty  --(no such connection, or no revDB)
   end try
   if "revdberr" is in tList then
      return empty
   end if
   set the itemDelimiter to tab
   return item 3 of line 1 of tList
end connectedFile

-- The badge, green when connected, and as wide as its words, its right where it was
private command lightBadge pOn
   local tRight, tWidth
   if pOn then
      set the backgroundColor of graphic "BadgeDot" to the cOn of this stack
      set the backgroundColor of graphic "BadgeBg" to the cOnBack of this stack
      set the foregroundColor of graphic "BadgeBg" to the cOnEdge of this stack
   else
      set the backgroundColor of graphic "BadgeDot" to the cOff of this stack
      set the backgroundColor of graphic "BadgeBg" to the cOffBack of this stack
      set the foregroundColor of graphic "BadgeBg" to the cOffEdge of this stack
   end if
   put the right of graphic "BadgeBg" into tRight
   put measureText(the text of field "Badge", field "Badge") into tWidth
   set the rect of graphic "BadgeBg" to tRight - tWidth - 42, the top of graphic "BadgeBg", tRight, the bottom of graphic "BadgeBg"
   set the left of graphic "BadgeDot" to tRight - tWidth - 28
   set the rect of field "Badge" to tRight - tWidth - 14, the top of field "Badge", tRight - 6, the bottom of field "Badge"
end lightBadge

-- The Connect card's drawing: the line from your stack to the database, and its file
private command drawLink pOn, pFile
   local tPath
   if pOn then
      set the dashes of graphic "LinkLine" to empty
      set the foregroundColor of graphic "LinkLine" to the cOn of this stack
      set the text of field "LinkLabel" to "connected: gConID is" && gConID
      set the textColor of field "LinkLabel" to the cOn of this stack
      set the backgroundColor of graphic "LinkPill" to the cOnBack of this stack
      set the foregroundColor of graphic "LinkPill" to the cOnEdge of this stack
      put pFile into tPath
   else
      set the dashes of graphic "LinkLine" to "6,6"
      set the foregroundColor of graphic "LinkLine" to the cOff of this stack
      set the text of field "LinkLabel" to "not connected"
      set the textColor of field "LinkLabel" to the cOffInk of this stack
      set the backgroundColor of graphic "LinkPill" to the cOffBack of this stack
      set the foregroundColor of graphic "LinkPill" to the cOffEdge of this stack
      put specialFolderPath("temporary") & "/AppRegister.sqlite" into tPath  --where the buttons make it
   end if
   if there is a file tPath then
      set the text of field "LinkFile" to tPath
      set the blendLevel of graphic "LinkBaseBox" to 0
      set the blendLevel of image "LinkBaseIcon" to 0
   else
      set the text of field "LinkFile" to tPath && "(not made yet)"
      set the blendLevel of graphic "LinkBaseBox" to 50
      set the blendLevel of image "LinkBaseIcon" to 60
   end if
   set the itemDelimiter to slash
   set the text of field "LinkBaseName" to the last item of tPath
end drawLink

################################################################################
# Tables

-- The Create Tables card: each table it draws says whether the database has it yet
command showTables
   local tList, tTable
   if there is no field "usersState" then
      exit showTables
   end if
   put tablesNow() into tList
   repeat for each item tTable in "users,apps"
      if tTable is among the lines of tList then
         set the text of field (tTable & "State") to "created"
         set the textColor of field (tTable & "State") to the cOn of this stack
         set the backgroundColor of graphic (tTable & "StateBg") to the cOnBack of this stack
         set the foregroundColor of graphic (tTable & "StateBg") to the cOnEdge of this stack
         set the blendLevel of field (tTable & "Columns") to 0
      else
         set the text of field (tTable & "State") to "not created yet"
         set the textColor of field (tTable & "State") to the cOffInk of this stack
         set the backgroundColor of graphic (tTable & "StateBg") to the cOffBack of this stack
         set the foregroundColor of graphic (tTable & "StateBg") to the cOffEdge of this stack
         set the blendLevel of field (tTable & "Columns") to 50
      end if
   end repeat
end showTables

-- The names of the tables in the database, a line each
function tablesNow
   local tList, tError
   if gConID is empty then
      return empty
   end if
   try
      put revDataFromQuery(tab, return, gConID, "SELECT name FROM sqlite_master WHERE type='table'") into tList
   catch tError
      return empty
   end try
   if "revdberr" is in tList then
      return empty
   end if
   return tList
end tablesNow

-- A field with a query of its own (its custom property cQuery) shows what the query finds now
command showLive
   local tIndex, tObj, tList, tError
   repeat with tIndex = 1 to the number of controls of this card
      put the long id of control tIndex of this card into tObj
      if word 1 of tObj is not "field" or the cQuery of tObj is empty then
         next repeat
      end if
      put empty into tList
      if gConID is not empty then
         try
            put revDataFromQuery(tab, return, gConID, the cQuery of tObj) into tList
         catch tError
            put empty into tList
         end try
         if "revdberr" is in tList then
            put empty into tList
         end if
      end if
      if tList is empty then
         put the cEmpty of tObj into tList  --(what a box says when it has nothing to show)
      end if
      set the text of tObj to tList
   end repeat
end showLive

-- Each table on the card (a field whose custom property cHead names its header): its header
-- from its table's columns, if it names a table (cTable), and each column as wide as what it
-- holds, sharing the table's width
command fitTables
   local tIndex, tObj
   repeat with tIndex = 1 to the number of controls of this card
      put the long id of control tIndex of this card into tObj
      if word 1 of tObj is "field" and the cHead of tObj is not empty then
         fitTable tObj, the long id of field (the cHead of tObj)
      end if
   end repeat
end fitTables

private command fitTable pField, pHead
   local tNames, tCount, tCol, tWidth, tLine, tTotal, tRoom, tStops, tX
   if the cTable of pField is not empty then
      put columnsOf(the cTable of pField) into tNames
      if tNames is not empty then
         set the text of pHead to tNames
      end if
   end if
   set the itemDelimiter to tab
   put the number of items of the text of pHead into tCount
   repeat for each line tLine in the text of pField
      put max(tCount, the number of items of tLine) into tCount
   end repeat
   if tCount < 2 then
      exit fitTable
   end if
   repeat with tCol = 1 to tCount
      put measureText(item tCol of the text of pHead, pHead) + 24 into tWidth[tCol]
   end repeat
   repeat for each line tLine in the text of pField
      repeat with tCol = 1 to tCount
         put max(tWidth[tCol], measureText(item tCol of tLine, pField) + 24) into tWidth[tCol]
      end repeat
   end repeat
   put 0 into tTotal
   repeat with tCol = 1 to tCount
      add tWidth[tCol] to tTotal
   end repeat
   put the width of pField - 16 into tRoom
   put 0 into tX
   repeat with tCol = 1 to tCount - 1
      add tWidth[tCol] * tRoom / tTotal to tX
      put round(tX) & comma after tStops
   end repeat
   delete the last char of tStops
   set the tabStops of pField to tStops
   set the tabStops of pHead to tStops
end fitTable

-- Each table with words for when it is empty (its custom property cEmptyHint names them):
-- they show while it has no rows
command showEmpty
   local tIndex, tObj
   repeat with tIndex = 1 to the number of controls of this card
      put the long id of control tIndex of this card into tObj
      if word 1 of tObj is "field" and the cEmptyHint of tObj is not empty then
         set the visible of field (the cEmptyHint of tObj) to (word 1 to -1 of the text of tObj is empty)
      end if
   end repeat
end showEmpty

-- The names of a table's columns, tab-delimited, from PRAGMA table_info
function columnsOf pTable
   local tList, tLine, tNames, tError
   if gConID is empty then
      return empty
   end if
   try
      put revDataFromQuery(tab, return, gConID, "PRAGMA table_info(" & pTable & ")") into tList
   catch tError
      return empty
   end try
   if "revdberr" is in tList then
      return empty
   end if
   set the itemDelimiter to tab
   repeat for each line tLine in tList
      put item 2 of tLine & tab after tNames
   end repeat
   delete the last char of tNames
   return tNames
end columnsOf

################################################################################
# Reports

-- The Reports card: the circles show the join the report's SQL makes, and the table's header
-- names what it selects
command showReport
   local tSQL, tKind
   if there is no field "ReportSQL" then
      exit showReport
   end if
   put the text of field "ReportSQL" into tSQL
   replace return with space in tSQL
   if word 1 of tSQL is not "SELECT" then
      put "none" into tKind
   else if " LEFT JOIN " is in tSQL then
      put "outer" into tKind
   else
      put "inner" into tKind
   end if
   set the textColor of field "VennUsers" to the cVennInk of this stack
   switch tKind
      case "inner"
         set the backgroundColor of graphic "VennLeft" to the cVennOff of this stack
         set the backgroundColor of graphic "VennLens" to the cVennOn of this stack
         set the text of field "VennCaption" to "Inner join: only the rows that match in both."
         break
      case "outer"
         set the backgroundColor of graphic "VennLeft" to the cVennOn of this stack
         set the backgroundColor of graphic "VennLens" to the cVennOn of this stack
         set the textColor of field "VennUsers" to "255,255,255"  --(on the filled circle)
         set the text of field "VennCaption" to "Left outer join: every user, with apps or not."
         break
      default
         set the backgroundColor of graphic "VennLeft" to the cVennOff of this stack
         set the backgroundColor of graphic "VennLens" to the cVennMid of this stack
         set the text of field "VennCaption" to "Two tables, and the rows where they meet."
   end switch
   if tKind is not "none" then
      set the text of field "ReportHead" to selectList(tSQL)
   end if
end showReport

-- What a SELECT returns, for a header: the columns between SELECT and FROM, tab-delimited
private function selectList pSQL
   local tList, tItem, tHead
   put char 8 to offset(" FROM ", pSQL) - 1 of pSQL into tList
   repeat for each item tItem in tList
      put word 1 to -1 of tItem & tab after tHead
   end repeat
   delete the last char of tHead
   return tHead
end selectList

################################################################################
# SQL and code in colour

-- A box of SQL a script fills (custom property cSQL), in colour, a clause a line
command showSQL
   local tIndex, tObj
   repeat with tIndex = 1 to the number of controls of this card
      put the long id of control tIndex of this card into tObj
      if word 1 of tObj is "field" and the cSQL of tObj is true then
         set the htmlText of tObj to sqlHtml(the text of tObj)
      end if
   end repeat
end showSQL

-- SQL in colour; a SELECT on one line is broken before each of its clauses
function sqlHtml pSQL
   local tHtml, tLine, tPart
   repeat for each line tLine in pSQL
      if word 1 of tLine is "SELECT" and " FROM " is in tLine then
         repeat for each item tPart in "FROM,LEFT JOIN,WHERE,ON,GROUP BY,ORDER BY"
            replace (space & tPart & space) with (return & tPart & space) in tLine
         end repeat
         replace " AND " with (return & "  AND ") in tLine
      end if
      repeat for each line tPart in tLine
         put "<p>" & sqlLineHtml(tPart) & "</p>" after tHtml
      end repeat
   end repeat
   return tHtml
end sqlHtml

-- A line of SQL in colour: its words, the types of its columns, its numbers, its quoted
-- strings and a comment each in their own colour
function sqlLineHtml pLine
   local tOut, tPos, tLen, tChar, tStart, tWord
   if word 1 of pLine begins with "--" then
      return spanOf(pLine, the cSqlComment of this stack)
   end if
   put the number of chars of pLine into tLen
   put 1 into tPos
   repeat while tPos <= tLen
      put char tPos of pLine into tChar
      if tChar is "'" then
         put tPos into tStart
         add 1 to tPos
         repeat while tPos <= tLen and char tPos of pLine is not "'"
            add 1 to tPos
         end repeat
         put spanOf(char tStart to tPos of pLine, the cSqlString of this stack) after tOut
         add 1 to tPos
      else if tChar is not empty and tChar is in "abcdefghijklmnopqrstuvwxyz0123456789_." then
         put tPos into tStart
         repeat while tPos <= tLen and char tPos of pLine is in "abcdefghijklmnopqrstuvwxyz0123456789_."
            add 1 to tPos
         end repeat
         put char tStart to tPos - 1 of pLine into tWord
         put spanOf(tWord, sqlColor(tWord)) after tOut
      else
         put htmlOf(tChar) after tOut
         add 1 to tPos
      end if
   end repeat
   return tOut
end sqlLineHtml

private function sqlColor pWord
   if pWord is a number then
      return the cSqlNumber of this stack
   end if
   if pWord is among the items of "SELECT,FROM,WHERE,AND,OR,NOT,INSERT,INTO,VALUES,UPDATE,SET,DELETE,CREATE," & \
         "TABLE,DROP,LEFT,RIGHT,INNER,OUTER,JOIN,ON,GROUP,BY,ORDER,COUNT,BEGIN,TRANSACTION,COMMIT,ROLLBACK," & \
         "TEMPORARY,PRIMARY,KEY,AUTOINCREMENT,NULL,IF,EXISTS,AS,LIKE,ALTER,ADD,COLUMN,PRAGMA" then
      return the cSqlWord of this stack
   end if
   if pWord is among the items of "integer,text,boolean,blob,real,float,date,time,char,double,long,varchar" then
      return the cSqlType of this stack
   end if
   return the cSqlName of this stack
end sqlColor

private function spanOf pText, pColor
   return "<font color=" & quote & pColor & quote & ">" & htmlOf(pText) & "</font>"
end spanOf

function htmlOf pText
   replace "&" with "&amp;" in pText
   replace "<" with "&lt;" in pText
   replace ">" with "&gt;" in pText
   return pText
end htmlOf

-- Code in the code font (the fields whose custom property cCode is true): Source Code Pro,
-- which the IDE carries for its Script Editor, else Droid Sans Mono, which its Dictionary
-- carries (the web engine can load that one), else a monospaced font the computer has, as
-- the window's scripts panel chooses
command codeFonts
   local tIndex, tObj
   if sCodeFont is empty then
      put codeFont() into sCodeFont
   end if
   if sCodeFont is "-" then
      exit codeFonts
   end if
   repeat with tIndex = 1 to the number of controls of this card
      put the long id of control tIndex of this card into tObj
      if word 1 of tObj is "field" and the cCode of tObj is true then
         set the textFont of tObj to sCodeFont
      end if
   end repeat
end codeFonts

private function codeFont
   local tError, tFont
   if the environment is "development" then
      try
         if "Source Code Pro" is not among the lines of the fontNames then
            start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
         end if
      catch tError
      end try
      try
         if "Source Code Pro" is not among the lines of the fontNames and \
               "Droid Sans Mono" is not among the lines of the fontNames then
            start using font file (revIDESpecialFolderPath("IDE") & \
                  "/Documentation/html_viewer/resources/data/api/DroidSansMono.ttf")
         end if
      catch tError
      end try
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then
         return tFont
      end if
   end repeat
   return "-"
end codeFont

################################################################################
# Clicks and the wheel

-- A click on a button: until what it does is done, and if its dialog is cancelled, the panel
-- gives the card's hint, not what the last button did. (The window itself shows the button's
-- script in the Scripts drawer, as it does any control's.) These buttons are groups (the
-- kit's), whose parts have no scripts of their own
on mouseDown pButton
   local tOwner
   put the long owner of the target into tOwner
   if pButton is 1 and word 1 of tOwner is "group" and the script of tOwner is not empty \
         and the cLit of tOwner is not empty and not isOwn(tOwner) then
      if there is a field "Status" then
         showResult "info", the cHint of this card
      end if
   end if
   pass mouseDown
end mouseDown

-- True for the window's own controls: the groups Frame, Workbench and Scripts, and theirs
private function isOwn pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if word 1 of tObj is "group" and the short name of tObj is among the items of "Frame,Workbench,Scripts" then
         return true
      end if
      put the long owner of tObj into tObj
   end repeat
   return false
end isOwn

-- The wheel scrolls a table or a box of code under the pointer (custom property cWheel), as
-- the window's own scripts panel scrolls
on rawKeyDown pKey
   local tObj
   if pKey is not 65308 and pKey is not 65309 then
      pass rawKeyDown
   end if
   put wheelField() into tObj
   if tObj is empty then
      pass rawKeyDown
   end if
   if pKey is 65308 then
      set the vScroll of tObj to the vScroll of tObj + 48
   else
      set the vScroll of tObj to max(0, the vScroll of tObj - 48)
   end if
end rawKeyDown

private function wheelField
   local tIndex, tObj
   if there is a group "Scripts" and the visible of group "Scripts" and the mouseLoc is within the rect of group "Scripts" then
      return empty  --(the drawer is open over it)
   end if
   repeat with tIndex = 1 to the number of controls of this card
      put the long id of control tIndex of this card into tObj
      if word 1 of tObj is "field" and the cWheel of tObj is true and the visible of tObj \
            and the mouseLoc is within the rect of tObj then
         return tObj
      end if
   end repeat
   return empty
end wheelField
@*/

/*@ SQL Primer/Learn SQL
on mouseUp
   --w3schools' free SQL tutorial, which the original tour sends you to for more SQL
   launch url "https://www.w3schools.com/sql/"
end mouseUp
@*/

/*@ Connect/Connect
on mouseUp
   global gConID
   local tConId, tPath
   put specialFolderPath("temporary") & "/AppRegister.sqlite" into tPath  --a folder you can write to (the original used the desktop)
   put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
   if the result is an integer then
      put tConID into gConID  --(first, so that the panel shows the connection)
      showResult "ok", "AppRegister Connected! Your connection ID is:" && tConID &"."
   else showResult "error", "Sorry, there was a problem creating or accessing the database." &cr& the result
end mouseUp
@*/

/*@ Connect/Disconnect
on mouseUp
   global gConID
   if gConID is empty then
      showResult "error", "Sorry, the database is not connected. Please connect to the database first."
      exit mouseUp
   end if
   revCloseDatabase gConID
   if "revdberr" is not in the result then
      put empty into gConID  --(first, so that the panel shows it closed)
      showResult "ok", "Connection Terminated."
   else showResult "error", the result
end mouseUp
@*/

/*@ Connect/Delete File
on mouseUp
   global gConID
   local tPath
   answer question "Delete the database file AppRegister.sqlite?" with "Cancel" or "OK" titled "Delete Database"
   if it = "Cancel" then exit to top
   put specialFolderPath("temporary") & "/AppRegister.sqlite" into tPath  --(the original used the desktop)
   if gConID is not empty then  --(added: a file the database has open cannot be deleted everywhere)
      revCloseDatabase gConID
      put empty into gConID
   end if
   if there is a file tPath then
      delete file tPath
      if the result = empty then showResult "ok", "Successfully deleted the database file AppRegister.sqlite."
      else showResult "error", the result
   else showResult "info", "There is no database file to delete yet."  --(added)
end mouseUp
@*/

/*@ Create Tables/Create Users
on mouseUp
   global gConID
   local tSQL
   if gConID is empty then
      showResult "error", "Sorry, the database is not connected. Please connect to the database first."
      exit mouseUp
   end if
   put "CREATE TABLE users(userID integer primary key,name text,email text,emailList boolean)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is an integer then showResult "ok", "The table Users was added to the database."
   else showResult "error", the result  --(the original answered tResult, a variable it never set)
end mouseUp
@*/

/*@ Create Tables/Create Apps
on mouseUp
   global gConID
   local tSQL
   if gConID is empty then
      showResult "error", "Sorry, the database is not connected. Please connect to the database first."
      exit mouseUp
   end if
   put "CREATE TABLE apps(appID integer primary key,appName text,appRegCode text,appUserID integer)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is an integer then showResult "ok", "The table Apps was added to the database."
   else showResult "error", the result  --(the original answered tResult, a variable it never set)
end mouseUp
@*/

/*@ Add Data/Add Data
on mouseUp
   global gConID
   local tColumnItems, tRowData, tSQL, i
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   --
   put "name,email" into tColumnItems
   repeat for each item i in tColumnItems
      ask question "Please enter a new value for column:" && i &"." titled "Add Data To Users"
      if it is empty or the result is "cancel" then exit to top
      put "'" & cleanSQL(it) & "'" & "," after tRowData
   end repeat
   answer question "Does" && item 1 of tRowData && "want to be on the Email List?" with "Cancel" or "No" or "Yes" titled "Add Data To Users"
   if it = "Cancel" then exit to top
   if it = "No" then put "'" & "false" & "'" after tRowData
   else put "'" & "true" & "'" after tRowData
   --
   put "INSERT INTO users(userID,name,email,emailList) VALUES (null," & tRowData & ")" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is an integer then showResult "ok", "A new row has been added to table Users."
   else showResult "error", the result  --(the original answered tResult, a variable it never set)
end mouseUp

function cleanSQL pSQL
   replace "'" with "''" in pSQL  --replace single quote with double quote
   return pSQL
end cleanSQL
@*/

/*@ View and Delete/card
on preOpenCard
   put empty into fld "users"
   pass preOpenCard
end preOpenCard
@*/

/*@ View and Delete/Refresh Table
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   put "SELECT * FROM users" into tSQL  --select all
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is not in the result then
      put tList into fld "Users"
      showResult "ok", "Records returned:" && the number of lines of tList  --(added)
   else
      showResult "error", the result
   end if
end mouseUp
@*/

/*@ View and Delete/Delete Row
on mouseUp
   global gConID
   local tRowNumber, tUserID, tSQL
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   put the hilitedLine of fld "users" into tRowNumber
   if tRowNumber is empty or line tRowNumber of fld "users" is empty then  --no row selected (added: or an empty one)
      showResult "info", "Choose a row of the table first."  --(added)
      exit mouseUp
   end if
   set the itemDel to tab
   put item 1 of line tRowNumber of fld "users" into tUserID
   put "DELETE FROM users WHERE userID=" & tUserID into tSQL
   revExecuteSQL gConID,tSQL
   if the result is an integer then send "mouseUp" to group "Refresh Table"  --(a button of the kit is a group)
   else showResult "error", the result
end mouseUp
@*/

/*@ Update Data/card
on preOpenCard
   put empty into fld "users"
   pass preOpenCard
end preOpenCard
@*/

/*@ Update Data/Refresh Table
on mouseUp
   global gConID
   local tSQL, tList, tLine, tItem, tRowData
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   put "SELECT * FROM users" into tSQL  --select all records
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit mouseUp
   end if
   set the itemDelimiter to tab  --(the columns are tab-delimited: split at commas, a value with a comma in it became two)
   repeat for each line tLine in tList
      repeat for each item tItem in tLine
         put tItem & tab after tRowData
      end repeat
      delete last char of tRowData  --last tab
      put return after tRowData
   end repeat
   delete last char of tRowData  --last return
   put tRowData into fld "Users"  --display
   showResult "ok", "Records returned:" && the number of lines of tList & ". Click a cell to change it."  --(added)
end mouseUp
@*/

/*@ Update Data/Users
on selectionChanged
   global gConID
   local tLineNum, tXLoc, tTabStops, tIncrement, tClickedText, tUserID, tColumnToUpdate, tNewValue, tSQL, x
   if the lockText of me = "false" then exit to top
   put word 2 of the clickLine into tLineNum
   if tLineNum is empty then exit selectionChanged  --(added: a click below the rows)
   put item 1 of the clickLoc into tXLoc
   subtract the left of me from tXLoc
   put the tabStops of me into tTabStops
   repeat until last item of tTabStops > tXLoc
      put last item of tTabStops - item -2 of tTabStops into tIncrement
      put "," & last item of tTabStops + tIncrement after tTabStops
   end repeat
   put 1 into x
   repeat while item x of tTabStops < tXLoc
      add 1 to x
   end repeat
   set itemDel to tab
   put item x of line tLineNum of me into tClickedText
   put item 1 of line tLineNum of me into tUserID
   --create SQL string
   switch x
      case "1" --> userID
         showResult "error", "Sorry, can't change a Primary Key"
         exit to top
         break
      case "2" --> name
         put "name" into tColumnToUpdate
         break
      case "3" --> email
         put "email" into tColumnToUpdate
         break
      case "4" --> emailList
         put "emailList" into tColumnToUpdate
         break
   end switch
   --
   ask "New value for " & tColumnToUpdate &":" with tClickedText
   if it is empty or the result is "Cancel" then exit to top
   put "'" & cleanSQL(it) & "'" into tNewValue
   put "UPDATE users SET " & tColumnToUpdate & "=" & tNewValue & " WHERE userID=" & tUserID into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit to top
   else send "mouseUp" to group "Refresh Table"  --display change
end selectionChanged

function cleanSQL pSQL
   replace "'" with "''" in pSQL
   --(the original also doubled double quotes, which SQL keeps as they are between single quotes)
   replace cr with "*CR*" in pSQL
   replace tab with "*TAB*" in pSQL
   return pSQL
end cleanSQL
@*/

/*@ Both Tables/card
on preOpenCard
   put "" into fld "users"
   put "" into fld "apps"
   pass preOpenCard
end preOpenCard
@*/

/*@ Both Tables/Refresh Users
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   put "SELECT * FROM users" into tSQL
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is not in the result then
      put tList into fld "Users"
      showResult "ok", "Records returned from users:" && the number of lines of tList  --(added)
   else
      showResult "error", the result
   end if
end mouseUp
@*/

/*@ Both Tables/Refresh Apps
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   put "SELECT * FROM apps" into tSQL
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is not in the result then
      put tList into fld "apps"
      showResult "ok", "Records returned from apps:" && the number of lines of tList  --(added)
   else
      showResult "error", the result
   end if
end mouseUp
@*/

/*@ Both Tables/Delete User
--(the original's "Delete Row" of the table users)
on mouseUp
   global gConID
   local tNum, tUserID, tSQL
   put the hilitedLine of fld "Users" into tNum
   if tNum is empty or line tNum of fld "Users" is empty then  --(added: no row chosen, or an empty one)
      showResult "info", "Choose a row of users first."  --(added)
      exit mouseUp
   end if
   set the itemDel to tab
   put item 1 of line tNum of fld "Users" into tUserID
   put "DELETE FROM users WHERE userID=" & tUserID into tSQL
   revExecuteSQL gConID,tSQL
   if the result is an integer then send "mouseUp" to group "Refresh Users"
   else showResult "error", the result
end mouseUp
@*/

/*@ Both Tables/Add User
--(the original's "Add Row" of the table users)
on mouseUp
   global gConID
   local tColumnItems, tRowData, tSQL, i
   if gConID = empty then  --(added, as the other buttons do)
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   put "name,email" into tColumnItems
   repeat for each item i in tColumnItems
      ask question "New value for column:" && i titled "Add Users Row"
      if it is empty or the result is "Cancel" then exit to top
      put "'" & cleanSQL(it) & "'" & "," after tRowData
   end repeat
   answer question "Does" && item 1 of tRowData && "want to be on the Email List?" with "Cancel" or "No" or "Yes" titled "Add Users Row"
   if it = "Cancel" then exit to top
   if it = "No" then put "'" & "false" & "'" after tRowData
   else put "'" & "true" & "'" after tRowData
   put "INSERT INTO users(userID,name,email,emailList) VALUES(null," & tRowData & ")" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is an integer then send "mouseUp" to group "Refresh Users"
   else showResult "error", the result
end mouseUp

function cleanSQL pSQL
   replace "'" with "''" in pSQL
   return pSQL
end cleanSQL
@*/

/*@ Both Tables/Delete App
--(the original's "Delete Row" of the table apps)
on mouseUp
   global gConID
   local tNum, tAppID, tSQL
   put the hilitedLine of fld "Apps" into tNum
   if tNum is empty or line tNum of fld "Apps" is empty then  --(added: no row chosen, or an empty one)
      showResult "info", "Choose a row of apps first."  --(added)
      exit mouseUp
   end if
   set the itemDel to tab
   put item 1 of line tNum of fld "Apps" into tAppID
   put "DELETE FROM apps WHERE appID=" & tAppID into tSQL
   revExecuteSQL gConID,tSQL
   if the result is an integer then send "mouseUp" to group "Refresh Apps"
   else showResult "error", the result
end mouseUp
@*/

/*@ Both Tables/Add App
--(the original's "Add Row" of the table apps)
on mouseUp
   global gConID
   local tColumnItems, tRowData, tSQL, i
   if gConID = empty then  --(added, as the other buttons do)
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   put "appName,appRegCode" into tColumnItems
   repeat for each item i in tColumnItems
      ask question "New value for column:" && i titled "Add Apps Row"
      if it is empty or the result is "Cancel" then exit to top
      put "'" & cleanSQL(it) & "'" & "," after tRowData
   end repeat
   ask question "Please enter a valid userID from table 'users':" with "1" titled "Add Apps Row"
   if it is empty or the result is "cancel" then exit to top
   put "'" & cleanSQL(it) & "'" after tRowData
   put "INSERT INTO apps(appID, appName, appRegCode, appUserID) VALUES(null," & tRowData & ")" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is an integer then send "mouseUp" to group "Refresh Apps"
   else showResult "error", the result
end mouseUp

function cleanSQL pSQL
   replace "'" with "''" in pSQL
   return pSQL
end cleanSQL
@*/

/*@ Both Tables/Default Data
on mouseUp
   global gConID
   local tConId, tPath, tSQL, tList, tLine
   if gConID = empty then  --connect
      put specialFolderPath("temporary") & "/AppRegister.sqlite" into tPath  --(the original used the desktop)
      put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
      if the result is an integer then
         put tConID into gConID
         showResult "ok", "AppRegister Connected! Your connection ID is:" && tConID &"."
      else
         showResult "error", "Sorry, there was a problem creating or accessing the database." &cr& the result
         exit to top
      end if
   end if
   answer "Inserting default data will delete existing data in the database." with "Cancel" or "OK" titled "Default Data"
   if it = "Cancel" then exit mouseUp
   --(revExecuteSQL's errors do not say "revdberr", which the original looked for: the result is not
   --an integer then. So the tables are dropped IF EXISTS, as a new database has none to drop)
   put "DROP TABLE IF EXISTS users" into tSQL
   revExecuteSQL gConID, tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "DROP TABLE IF EXISTS apps" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "CREATE TABLE users(userID integer primary key,name text,email text,emailList boolean)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "CREATE TABLE apps(appID integer primary key,appName text,appRegCode text,appUserID integer)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --answer information "New tables: users and apps created." with "OK" titled "Default Data"
   --
   put the altDefaultUsersData of me into tList
   repeat for each line tLine in tList
      put "INSERT INTO users(userID,name,email,emailList) VALUES(null," & tLine & ")" into tSQL
      revExecuteSQL gConID,tSQL
      if the result is not an integer then
         showResult "error", the result
         exit mouseUp
      end if
   end repeat
   --
   put the altDefaultAppsData of me into tList
   repeat for each line tLine in tList
      put "INSERT INTO apps(appID, appName, appRegCode, appUserID) VALUES(null," & tLine & ")" into tSQL
      revExecuteSQL gConID,tSQL
      if the result is not an integer then
         showResult "error", the result
         exit mouseUp
      end if
   end repeat
   --
   send "mouseUp" to group "Refresh Users"
   send "mouseUp" to group "Refresh Apps"
   showResult "ok", "Default data has been successfully inserted."  --(added)
end mouseUp

function cleanSQL pSQL
   replace "'" with "''" in pSQL
   --(the original also doubled double quotes, which SQL keeps as they are between single quotes)
   replace cr with "*CR*" in pSQL
   replace tab with "*TAB*" in pSQL
   return pSQL
end cleanSQL
@*/

/*@ Reports/Inner Join 1
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   --This will return a list of all users and the apps they've purchased.
   --(The original asked first, in a dialog: the panel says it now.)
   put "SELECT users.Name, apps.appName FROM users,apps WHERE users.userID=apps.appUserID" into tSQL
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit mouseUp
   end if
   set the itemDelimiter to tab  --(the columns are tab-delimited: the original put commas between them for its dialog)
   sort lines of tList by word 1 of item 1 of each  --first name a-z
   sort lines of tList by word -1 of item 1 of each  --last name a-z
   put tSQL into field "ReportSQL"  --the SQL, and the records returned
   put tList into field "Report"
   showResult "ok", "All users and the apps they've purchased." & return & "Records returned:" && the number of lines of tList
end mouseUp
@*/

/*@ Reports/Inner Join 2
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   --This will return a list of the apps purchased by John Smith.
   put "SELECT users.Name, apps.appName FROM users,apps WHERE users.userID=apps.appUserID AND users.name='John Smith'" into tSQL
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit mouseUp
   end if
   set the itemDelimiter to tab  --(the columns are tab-delimited)
   sort lines of tList by item 2 of each  --apps a-z
   put tSQL into field "ReportSQL"  --the SQL, and the records returned
   put tList into field "Report"
   showResult "ok", "The apps purchased by John Smith." & return & "Records returned:" && the number of lines of tList
end mouseUp
@*/

/*@ Reports/Inner Join 3
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   --This will return a list of all the people who purchased AppRed.
   put "SELECT users.Name, apps.appName FROM users,apps WHERE users.userID=apps.appUserID AND apps.appName='AppRed'" into tSQL
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit mouseUp
   end if
   set the itemDelimiter to tab  --(the columns are tab-delimited)
   sort lines of tList by word 1 of item 1 of each  --first name a-z
   sort lines of tList by word -1 of item 1 of each  --last name a-z
   put tSQL into field "ReportSQL"  --the SQL, and the records returned
   put tList into field "Report"
   showResult "ok", "All the people who purchased AppRed." & return & "Records returned:" && the number of lines of tList
end mouseUp
@*/

/*@ Reports/Outer Join 1
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   --This will return a list of all users and the apps purchased (if any).
   --SQLite has long had no right outer join, but a left outer join, the tables swapped, does what one would.
   put "SELECT users.name, apps.appName FROM users LEFT JOIN apps ON users.userID=apps.appUserID" into tSQL
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit mouseUp
   end if
   set the itemDelimiter to tab  --(the columns are tab-delimited)
   sort lines of tList by word 1 of item 1 of each  --first name a-z
   sort lines of tList by word -1 of item 1 of each  --last name a-z
   put tSQL into field "ReportSQL"  --the SQL, and the records returned
   put tList into field "Report"
   showResult "ok", "All users and the apps purchased (if any)." & return & "Records returned:" && the number of lines of tList
end mouseUp
@*/

/*@ Reports/Outer Join 2
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   --This will return a list of all users and the number of apps they purchased (if any).
   --COUNT, GROUP BY and ORDER BY: www.w3schools.com teaches them, and much more SQL.
   put "SELECT users.name, COUNT(apps.appID) FROM users LEFT JOIN apps ON users.userID=apps.appUserID GROUP BY name ORDER BY name" into tSQL
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit mouseUp
   end if
   set the itemDelimiter to tab  --(the columns are tab-delimited)
   sort lines of tList by word 1 of item 1 of each  --first name a-z
   sort lines of tList by word -1 of item 1 of each  --last name a-z
   sort lines of tList descending numeric by item 2 of each  --integer
   put tSQL into field "ReportSQL"  --the SQL, and the records returned
   put tList into field "Report"
   showResult "ok", "All users and the number of apps they purchased (if any)." & return & "Records returned:" && the number of lines of tList
end mouseUp
@*/

/*@ The Schema/Show Schema
--(the original's "Show SQLite_Master Schema": the table is sqlite_master)
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then  --(added, as the other buttons do)
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   --This will return a list of the SQL used to create all tables in the current database.
   put "SELECT sql FROM sqlite_master" into tSQL
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit to top
   end if
   put tList into field "Schema"  --(the original answered with it)
   showResult "ok", "Records returned:" && the number of lines of tList
end mouseUp
@*/

/*@ The Schema/Delete Users
--(the original's "Delete Users Table")
on mouseUp
   global gConID
   local tSQL
   if gConID = empty then
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   put "DROP TABLE users" into tSQL
   revExecuteSQL gConID,tSQL
   if "revdberr" is in the result then
      showResult "error", the result
      exit mouseUp
   end if
   if the result is an integer then showResult "ok", "The Users table has been deleted."
   else showResult "error", the result
end mouseUp
@*/

/*@ The Schema/Default Data
on mouseUp
   global gConID
   local tConId, tPath, tSQL, tList, tLine
   if gConID = empty then  --connect
      put specialFolderPath("temporary") & "/AppRegister.sqlite" into tPath  --(the original used the desktop)
      put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
      if the result is an integer then
         put tConID into gConID
         showResult "ok", "AppRegister Connected! Your connection ID is:" && tConID &"."
      else
         showResult "error", "Sorry, there was a problem creating or accessing the database." &cr& the result
         exit to top
      end if
   end if
   answer "Inserting default data will delete existing data in the database." with "Cancel" or "OK" titled "Default Data"
   if it = "Cancel" then exit mouseUp
   --(revExecuteSQL's errors do not say "revdberr", which the original looked for: the result is not
   --an integer then. So the tables are dropped IF EXISTS, as a new database has none to drop)
   put "DROP TABLE IF EXISTS users" into tSQL
   revExecuteSQL gConID, tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "DROP TABLE IF EXISTS apps" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "CREATE TABLE users(userID integer primary key,name text,email text,emailList boolean)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "CREATE TABLE apps(appID integer primary key,appName text,appRegCode text,appUserID integer)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --answer information "New tables: users and apps created." with "OK" titled "Default Data"
   --
   put the altDefaultUsersData of me into tList
   repeat for each line tLine in tList
      put "INSERT INTO users(userID,name,email,emailList) VALUES(null," & tLine & ")" into tSQL
      revExecuteSQL gConID,tSQL
      if the result is not an integer then
         showResult "error", the result
         exit mouseUp
      end if
   end repeat
   --
   put the altDefaultAppsData of me into tList
   repeat for each line tLine in tList
      put "INSERT INTO apps(appID, appName, appRegCode, appUserID) VALUES(null," & tLine & ")" into tSQL
      revExecuteSQL gConID,tSQL
      if the result is not an integer then
         showResult "error", the result
         exit mouseUp
      end if
   end repeat
   showResult "ok", "Default data has been successfully inserted."
end mouseUp

function cleanSQL pSQL
   replace "'" with "''" in pSQL
   --(the original also doubled double quotes, which SQL keeps as they are between single quotes)
   replace cr with "*CR*" in pSQL
   replace tab with "*TAB*" in pSQL
   return pSQL
end cleanSQL
@*/

/*@ Columns/Delete Columns
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then  --(added, as the other buttons do)
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   answer information "This will delete the columns 'email' and 'emailList' from table 'users' and " & \
         "rename column 'name' to 'fullname'." with "Cancel" or "OK" titled "Delete Columns"
   if it = "Cancel" then exit to top
   --
   put "BEGIN TRANSACTION;" into tSQL
   put "CREATE TEMPORARY TABLE users_temp(userID,name);" after tSQL
   put "INSERT INTO users_temp SELECT userID,name FROM users;" after tSQL
   put "DROP TABLE users;" after tSQL
   put "CREATE TABLE users(userID,fullname);" after tSQL
   put "INSERT INTO users SELECT userID,name FROM users_temp;" after tSQL
   put "DROP TABLE users_temp;" after tSQL
   put "COMMIT;" after tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      revExecuteSQL gConID,"ROLLBACK"  --(added: undo what ran before the error, which left the transaction open)
      exit to top
   end if
   --
   put "SELECT sql FROM sqlite_master" into tSQL  --new schema
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit to top
   end if
   put tList into field "Schema"  --(the original answered with it)
   --
   put "SELECT * FROM users" into tSQL  --new table users
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit to top
   end if
   put tList into field "Users"  --(the original answered with it)
   showResult "ok", "New schema created, and the new table 'users': both are below."
end mouseUp
@*/

/*@ Columns/Add Columns
on mouseUp
   global gConID
   local tSQL, tList
   if gConID = empty then  --(added, as the other buttons do)
      showResult "error", "Sorry, please connect to the database first."
      exit to top
   end if
   answer information "This will add the columns 'city' and 'state' to table 'users'." with "Cancel" or "OK" titled "Add Columns"  --(the original had "and" for "or")
   if it = "Cancel" then exit to top
   --
   put "BEGIN TRANSACTION;" into tSQL
   put "CREATE TEMPORARY TABLE users_temp(userID,name,email,emailList);" after tSQL
   put "INSERT INTO users_temp SELECT userID,name,email,emailList FROM users;" after tSQL
   put "DROP TABLE users;" after tSQL
   put "CREATE TABLE users(userID integer primary key,name text,email text,emailList boolean,city text,state text);" after tSQL
   put "INSERT INTO users(userID,name,email,emailList) SELECT userID,name,email,emailList FROM users_temp;" after tSQL
   put "DROP TABLE users_temp;" after tSQL
   put "COMMIT;" after tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      revExecuteSQL gConID,"ROLLBACK"  --(added: undo what ran before the error, which left the transaction open)
      exit to top
   end if
   --
   put "SELECT sql FROM sqlite_master" into tSQL  --new schema
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit to top
   end if
   put tList into field "Schema"  --(the original answered with it)
   --
   put "SELECT * FROM users" into tSQL  --new table users
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit to top
   end if
   put tList into field "Users"  --(the original answered with it)
   showResult "ok", "New schema created, and the new table 'users': both are below."
end mouseUp
@*/

/*@ Columns/Default Data
on mouseUp
   global gConID
   local tConId, tPath, tSQL, tList, tLine
   if gConID = empty then  --connect
      put specialFolderPath("temporary") & "/AppRegister.sqlite" into tPath  --(the original used the desktop)
      put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
      if the result is an integer then
         put tConID into gConID
         showResult "ok", "AppRegister Connected! Your connection ID is:" && tConID &"."
      else
         showResult "error", "Sorry, there was a problem creating or accessing the database." &cr& the result
         exit to top
      end if
   end if
   answer "Inserting default data will delete existing data in the database." with "Cancel" or "OK" titled "Default Data"
   if it = "Cancel" then exit mouseUp
   --(revExecuteSQL's errors do not say "revdberr", which the original looked for: the result is not
   --an integer then. So the tables are dropped IF EXISTS, as a new database has none to drop)
   put "DROP TABLE IF EXISTS users" into tSQL
   revExecuteSQL gConID, tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "DROP TABLE IF EXISTS apps" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "CREATE TABLE users(userID integer primary key,name text,email text,emailList boolean)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --
   put "CREATE TABLE apps(appID integer primary key,appName text,appRegCode text,appUserID integer)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", the result
      exit mouseUp
   end if
   --answer information "New tables: users and apps created." with "OK" titled "Default Data"
   --
   put the altDefaultUsersData of me into tList
   repeat for each line tLine in tList
      put "INSERT INTO users(userID,name,email,emailList) VALUES(null," & tLine & ")" into tSQL
      revExecuteSQL gConID,tSQL
      if the result is not an integer then
         showResult "error", the result
         exit mouseUp
      end if
   end repeat
   --
   put the altDefaultAppsData of me into tList
   repeat for each line tLine in tList
      put "INSERT INTO apps(appID, appName, appRegCode, appUserID) VALUES(null," & tLine & ")" into tSQL
      revExecuteSQL gConID,tSQL
      if the result is not an integer then
         showResult "error", the result
         exit mouseUp
      end if
   end repeat
   showResult "ok", "Default data has been successfully inserted."
end mouseUp

function cleanSQL pSQL
   replace "'" with "''" in pSQL
   --(the original also doubled double quotes, which SQL keeps as they are between single quotes)
   replace cr with "*CR*" in pSQL
   replace tab with "*TAB*" in pSQL
   return pSQL
end cleanSQL
@*/

/*@ Binary Data/Insert
--(the original's "Insert Binary Data")
on mouseUp
   global gConID
   local tPath, tConId, tSQL, tName, tEmail, tIcon, tList
   answer information "This will insert binary data into table 'example' in file 'BinaryTest.sqlite'." with "Cancel" or "OK" titled "Insert Binary Data"
   if it = "Cancel" then exit to top
   --disconnect old
   if gConID <> empty then
      revCloseDatabase gConID
      if "revdberr" is in the result then
         showResult "error", the result
         exit to top
      else put empty into gConID
   end if
   --connect new
   put specialFolderPath("temporary") & "/BinaryTest.sqlite" into tPath  --(the original used the desktop)
   if there is a file tPath then delete file tPath  --delete old file
   put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
   if the result is not an integer then
      showResult "error", "Sorry, there was a problem creating or accessing the database." &cr& the result
      exit to top
   else put tConID into gConID
   --create table
   put "CREATE TABLE example(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NULL,email TEXT NULL,icon BLOB NULL)" into tSQL
   revExecuteSQL gConID,tSQL
   if the result is not an integer then
      showResult "error", "Sorry, there was a problem creating the table." &cr& the result
      exit to top
   end if
   --insert data
   put "John Smith" into tName
   put "john@ibm.com" into tEmail
   if there is not an image "Icon1" then showResult "error", "Sorry, could not find image 'Icon1' for binary data."
   else put the text of image "Icon1" into tIcon  --binary data of image
   put "INSERT INTO example(name,email,icon) VALUES (:1,:2,:3)" into tSQL
   revExecuteSQL gConID,tSQL,"tName","tEmail","*btIcon"  --quoted variables, *b for binary data
   if the result is not an integer then
      showResult "error", "Sorry, there was a problem inserting data into the table." &cr& the result
      exit to top
   end if
   --display non-binary data
   put "SELECT name,email FROM example" into tSQL  --non-binary data
   put revDataFromQuery(,,gConID,tSQL) into tList
   if "revdberr" is in the result then
      showResult "error", the result
      exit mouseUp
   end if
   put tList into field "Example"  --(the original answered with it)
   showResult "ok", "A new row containing binary data has been added to table 'example'." & return & \
         "Its icon column holds the" && the number of bytes of tIcon && "bytes of image Icon1."
end mouseUp
@*/

/*@ Binary Data/Retrieve
--(the original's "Retrieve Binary Data")
on mouseUp
   global gConID
   local tPath, tConID, tSQL, tRecordSetID, tIcon, tTemp
   --This will retrieve binary data from table 'example' in file 'BinaryTest.sqlite'.
   --(The original asked first, in a dialog: the panel says it now.)
   --connect
   put specialFolderPath("temporary") & "/BinaryTest.sqlite" into tPath  --(the original used the desktop)
   if there is not a file tPath then
      showResult "error", "Sorry, please insert binary data first."
      exit to top
   else if gConID = empty then
      put revOpenDatabase("sqlite",tPath,,,,,,) into tConID
      if the result is not an integer then
         showResult "error", "Sorry, there was a problem creating or accessing the database." &cr& the result
         exit to top
      else put tConID into gConID
   end if
   --
   put "SELECT icon FROM example WHERE id=1" into tSQL  --first row of table
   put revQueryDatabase(gConID,tSQL) into tRecordSetID  --an integer
   if the result is not an integer then
      showResult "error", the result
      exit to top
   end if
   --retrieve binary data using tRecordSetID
   put revDatabaseColumnNamed(tRecordSetID, "icon", "tIcon") into tTemp  --holder variable required for binary data
   if "revdberr" is in the result then
      showResult "error", the result
      exit to top
   end if
   revCloseCursor tRecordSetID  --(added: a record set is closed when you are done with it)
   if there is not an image "Icon2" then showResult "error", "Sorry, could not find image 'Icon2'."
   else
      set the text of image "Icon2" to tIcon  --display binary data
      showResult "ok", "Icon2 shows the" && the number of bytes of tIcon && "bytes read back from the database."  --(added)
   end if
end mouseUp
@*/

/*@ Binary Data/Reset Icon2
on mouseUp
   set the text of image "Icon2" to empty  --reset
   showResult "info", "Icon2 is empty again."  --(added)
end mouseUp
@*/

/*@ All Done/SQLite Site
on mouseUp
   --SQLite's own site, which the original tour's first card names
   launch url "https://www.sqlite.org"
end mouseUp
@*/

/*@ All Done/Learn SQL
on mouseUp
   --w3schools' free SQL tutorial, which the original tour sends you to for more SQL
   launch url "https://www.w3schools.com/sql/"
end mouseUp
@*/

/*@ All Done/Copy Reference
on mouseUp
   set the clipboardData["text"] to the text of field "Reference"  --the reference, to paste into a script
   answer "The SQLite reference is on the clipboard: paste it into a script." with "OK" titled "A Tour of SQLite"
end mouseUp
@*/
