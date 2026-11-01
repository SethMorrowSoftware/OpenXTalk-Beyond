script "OXTExampleSqliteBookLibrary"
-- OXT-Beyond: builds "SQLite Books", the remaster of SQLite Book Library,
-- one of OpenXTalk Lite's demos (its author is not recorded), which is in
-- tools/examples/originals/SQLite Book Library.oxtstack and stays there as
-- its author made it.
--
-- The demo keeps a little library in an SQLite database: a field that
-- lists the books, a search field, a button that adds or deletes a book,
-- and a button that copies the list into a data grid. The remaster keeps
-- its scripts and its comments, in the window every remastered example
-- has (builder.livecodescript). What changed:
--
--    - the database handlers were in the stack script, and are in the
--      script of the card "Library" now (its preOpenStack is that card's
--      preOpenCard), so that the panel beside the stage shows them;
--    - the database file is where the original put it, in the documents
--      folder, which is writable (the stack's own folder may not be);
--      on a computer without one, it goes in the temporary folder;
--    - a word in the Display field, instead of a script error, when the
--      database cannot open, or the database library (revDB) is not
--      loaded;
--    - the search and the new record use placeholders (:1, :2), so that a
--      title with a quote in it (Charlotte's Web) no longer breaks the SQL;
--    - a search shows what it found in the Display field too;
--    - added: code is shown in the scripts panel's font (the stack
--      script's preOpenCard).
--
-- The data grid is made as the IDE makes one (a copy of the library's,
-- with a row template on a substack), and so it needs the data grid
-- library loaded: in the IDE it is, and here this builder loads it from
-- the checkout's Toolset (or OXT_INSTALL's), as the IDE does.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kStageLeft = 256
constant kStageTop = 104
constant kStageRight = 600
constant kStageBottom = 616
-- The data grid's templates substack (the IDE names one so, and finds it
-- by that name when a grid is added to the stack)
constant kTemplates = "Data Grid Templates 2026101803"

-- The row template of the grid made last, from gridNew
local sRowTemplate

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   exAddIcon "book-plus", "<path d='M12 7v6'/><path d='M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20'/><path d='M9 10h6'/>"
   exAddIcon "arrow-down", "<path d='M12 5v14'/><path d='m19 12-7 7-7-7'/>"
   gridLibrary
   put "SQLite Books" into tInfo["name"]
   put "from OpenXTalk Lite's demos" into tInfo["credit"]
   put "library-big" into tInfo["icon"]
   put lkColor("amber") into tInfo["accent"]
   put lkColor("orange") into tInfo["accent2"]
   put "Part" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|SQLite Books|A little library of books, kept in an SQLite database.|library-big|front" & return & \
         "Library|The Library|Add, find and delete books, then show them in a data grid.|database|program" & return & \
         "How It Works|How It Works|The lines of SQL behind each button, one at a time.|code|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   gridTemplates the short name of tStack
   buildFront
   buildLibrary
   buildHowItWorks
   unlock messages
   put exCheck(tStack) & exCheck(kTemplates) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/SQLite Books.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

################################################################################
#
# The cards
#

-- The front page: what this is, a tile for each part, and what the
-- library does
private command buildFront
   local tObj, tTop, tWidth, tIndex, tIcons, tTitles, tTexts, tX
   go card "Start"
   exHero lkR(kStageLeft, kStageTop, 1000, 272), lkColor("orange") & "|" & lkColor("amber"), \
         "FROM OPENXTALK LITE'S DEMOS  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "A little library, kept in SQLite", \
         "Add a book, find one or delete one: each button sends a line of SQL to a database " & \
         "file of your own. Then copy what it found into a data grid, a table to sort and edit."
   exProgramTiles 288, 2, 60, 12
   -- Three things it does, a panel each
   put "database|search|table" into tIcons
   put "Your own database|Find a book|From SQL to a grid" into tTitles
   put "The first time it opens, the library makes a database file in your documents folder, " & \
         "with three books in it. What you add stays there.|" & \
         "Type a word of a title or an author's name in the search field, and press Return: " & \
         "the Display field shows the books that match.|" & \
         "SQLite To DGTable copies what the Display field shows into the data grid, with a header " & \
         "for each column. Click a header to sort." into tTexts
   set the itemDelimiter to "|"
   put 364 into tTop
   put (1000 - kStageLeft - 2 * 12) div 3 into tWidth
   repeat with tIndex = 1 to 3
      put kStageLeft + (tIndex - 1) * (tWidth + 12) into tX
      get lkGroup("Feature" & tIndex, lkR(tX, tTop, tX + tWidth, 520), empty)
      put exPanel("Feature" & tIndex & "_bg", lkR(tX, tTop, tX + tWidth, 520), "Feature" & tIndex) into tObj
      put lkBox("Feature" & tIndex & "_iconBg", lkR(tX + 18, tTop + 18, tX + 54, tTop + 54), \
            lkMix("255,255,255", lkColor("amber"), 0.14), 11, "Feature" & tIndex) into tObj
      get exIcon("Feature" & tIndex & "_icon", item tIndex of tIcons, lkColor("amber"), \
            lkR(tX + 26, tTop + 26, tX + 46, tTop + 46), "Feature" & tIndex)
      put lkLabel("Feature" & tIndex & "_title", lkR(tX + 66, tTop + 24, tX + tWidth - 12, tTop + 46), \
            item tIndex of tTitles, 15, lkColor("ink"), "Feature" & tIndex) into tObj
      set the textStyle of tObj to "bold"
      put lkLabel("Feature" & tIndex & "_text", lkR(tX + 18, tTop + 66, tX + tWidth - 16, 512), \
            item tIndex of tTexts, 12, lkColor("soft"), "Feature" & tIndex) into tObj
      set the fixedLineHeight of tObj to true
      set the textHeight of tObj to 18
   end repeat
   set the itemDelimiter to comma
   -- What it uses: the words of the language it teaches
   put 532 into tTop
   get lkGroup("Uses", lkR(kStageLeft, tTop, 1000, 616), empty)
   put exPanel("Uses_bg", lkR(kStageLeft, tTop, 1000, 616), "Uses") into tObj
   put lkLabel("Uses_title", lkR(kStageLeft + 20, tTop + 18, 600, tTop + 36), "What it uses", 13, lkColor("ink"), "Uses") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Uses_text", lkR(kStageLeft + 20, tTop + 40, 640, tTop + 76), \
         "revDB's SQLite driver, which the desktop and the web IDE both have, and a data grid.", \
         12, lkColor("soft"), "Uses") into tObj
   -- (two rows of chips, each from the right edge in)
   put 1000 - 20 into tX
   repeat for each item tObj in "revExecuteSQL,revOpenDatabase"
      subtract useChip(tObj, tX, tTop + 14) + 8 from tX
   end repeat
   put 1000 - 20 into tX
   repeat for each item tObj in "dgText,revDataFromQuery"
      subtract useChip(tObj, tX, tTop + 46) + 8 from tX
   end repeat
end buildFront

-- A word of code on a soft chip, for "What it uses", its right edge at
-- pRight; returns its width
private function useChip pWord, pRight, pTop
   local tObj, tLabel, tWidth, tName
   put "Use_" & pWord into tName
   get lkGroup(tName, lkR(pRight - 300, pTop, pRight, pTop + 24), "Uses")
   put lkBox(tName & "_bg", lkR(pRight - 300, pTop, pRight, pTop + 24), \
         lkMix("255,255,255", lkColor("amber"), 0.12), 12, tName) into tObj
   put lkLabel(tName & "_label", lkR(pRight - 290, pTop + 4, pRight - 10, pTop + 22), pWord, 12, \
         lkMix(lkColor("amber"), lkColor("ink"), 0.35), tName) into tLabel
   set the textFont of tLabel to measureFace()
   set the dontWrap of tLabel to true
   put the formattedWidth of tLabel + 20 into tWidth
   codeFont tLabel
   set the rect of tObj to pRight - tWidth, pTop, pRight, pTop + 24
   set the rect of tLabel to pRight - tWidth + 10, item 2 of the rect of tLabel, pRight - 6, item 4 of the rect of tLabel
   -- (in the middle of its chip, up and down)
   exMiddle tLabel, pTop + 12
   set the rect of group tName to the rect of tObj
   return tWidth
end useChip

-- The library: the Display field, the search field, the two buttons and
-- the data grid, on the stage, in the order of the original card
private command buildLibrary
   local tObj, tTop, tWidth, tLeft, tRight, tGrid
   go card "Library"
   set the script of this card to exScript("Library/card")
   put kStageLeft + 16 into tLeft
   put kStageRight - 16 into tRight
   -- The Display field: every book, a line each (ID, author, title)
   caption "DisplayCaption", "field " & quote & "Display" & quote, tLeft, kStageTop + 16
   put lkBox("DisplayBox", lkR(tLeft, kStageTop + 36, tRight, kStageTop + 168), "255,255,255", 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel("Display", lkR(tLeft + 4, kStageTop + 42, tRight - 4, kStageTop + 162), empty, 13, lkColor("ink"), empty) into tObj
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 22
   set the margins of tObj to "10,4,8,4"
   set the tabStops of tObj to "36,140"
   set the vScrollbar of tObj to false
   set the text of tObj to "1" & tab & "Tolkien J" & tab & "Lord Of The Rings" & return & \
         "2" & tab & "Austen J" & tab & "Pride And Prejudice" & return & \
         "3" & tab & "Baum F" & tab & "Wizard Of Oz"
   -- Search, and add or delete
   put kStageTop + 184 into tTop
   caption "SearchCaption", "field " & quote & "Search Term" & quote & ": a word, then Return", tLeft, tTop
   put lkBox("SearchBox", lkR(tLeft, tTop + 20, tLeft + 186, tTop + 54), "255,255,255", 17, empty) into tObj
   lkBorder tObj, lkColor("line")
   get exIcon("SearchIcon", "search", lkColor("muted"), lkR(tLeft + 12, tTop + 29, tLeft + 28, tTop + 45), empty)
   put lkInput("Search Term", lkR(tLeft + 36, tTop + 28, tLeft + 178, tTop + 48), empty, 13, empty) into tObj
   set the script of tObj to exScript("Library/Search Term")
   put exButton("+/- Record", 0, tTop + 20, 34, "+/- Record", "book-plus", "ghost", lkColor("amber"), empty, empty, 0) into tWidth
   set the right of group "+/- Record" to tRight
   -- (the search box ends 8 short of the button)
   set the rect of graphic "SearchBox" to tLeft, tTop + 20, the left of group "+/- Record" - 8, tTop + 54
   set the right of field "Search Term" to the left of group "+/- Record" - 16
   set the script of group "+/- Record" to exScript("Library/+/- Record")
   -- The button that copies the list into the grid
   put kStageTop + 252 into tTop
   put exButton("SQLite To DGTable", tLeft, tTop, 36, "SQLite To DGTable", "arrow-down", "primary", lkColor("amber"), empty, empty, tRight - tLeft) into tWidth
   set the script of group "SQLite To DGTable" to exScript("Library/SQLite To DGTable")
   -- The data grid
   put kStageTop + 304 into tTop
   caption "GridCaption", "group " & quote & "DataGrid 1" & quote, tLeft, tTop
   put gridNew("DataGrid 1", lkR(tLeft, tTop + 20, tRight, kStageBottom - 16)) into tGrid
   gridReady tGrid, "table"
   gridLook tGrid, lkColor("amber")
   unlock messages
   set the dgProps["columns"] of tGrid to "ID" & return & "Author" & return & "Title"
   set the dgColumnWidth["ID"] of tGrid to 44
   set the dgColumnWidth["Author"] of tGrid to 112
   set the dgColumnWidth["Title"] of tGrid to tRight - tLeft - 44 - 112 - 2
   -- (the grid starts with the books the database starts with)
   set the dgText["true"] of tGrid to "ID" & tab & "Author" & tab & "Title" & return & the text of field "Display"
   lock messages
end buildLibrary

-- A small caption above a control, its name as a script names it
private command caption pName, pText, pLeft, pTop
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pLeft + 320, pTop + 16), pText, 11, lkColor("muted"), empty) into tObj
   codeFont tObj
   set the dontWrap of tObj to true
end caption

-- How it works: each of the library's lines of SQL, with what it does
private command buildHowItWorks
   local tObj, tTop, tIndex, tLine, tSteps, tHeight
   go card "How It Works"
   put lkLabel("Intro", lkR(kStageLeft, kStageTop + 4, 1000, kStageTop + 44), \
         "The library's script (the card " & quote & "Library" & quote & ") sends SQL, the language of " & \
         "databases, to SQLite: a statement for each thing it does. These are its five.", 14, lkColor("soft"), empty) into tObj
   put exScript("How It Works/steps") into tSteps
   set the itemDelimiter to "|"
   put kStageTop + 58 into tTop
   repeat with tIndex = 1 to the number of lines of tSteps
      put line tIndex of tSteps into tLine
      put 64 into tHeight
      if tIndex = 1 then
         put 82 into tHeight
      end if
      get lkGroup("Step" & tIndex, lkR(kStageLeft, tTop, 1000, tTop + tHeight), empty)
      put exPanel("Step" & tIndex & "_bg", lkR(kStageLeft, tTop, 1000, tTop + tHeight), "Step" & tIndex) into tObj
      put lkOval("Step" & tIndex & "_badge", lkR(kStageLeft + 16, tTop + 16, kStageLeft + 46, tTop + 46), \
            lkMix("255,255,255", lkColor("amber"), 0.16), "Step" & tIndex) into tObj
      put lkLabel("Step" & tIndex & "_number", lkR(kStageLeft + 16, tTop + 16, kStageLeft + 46, tTop + 46), \
            tIndex, 14, lkMix(lkColor("amber"), lkColor("ink"), 0.3), "Step" & tIndex, "center") into tObj
      set the textStyle of tObj to "bold"
      -- (the number in the middle of its circle)
      set the top of tObj to tTop + 31 - (the formattedHeight of tObj + 4) div 2
      put lkLabel("Step" & tIndex & "_title", lkR(kStageLeft + 58, tTop + 12, kStageLeft + 250, tTop + 32), \
            item 1 of tLine, 14, lkColor("ink"), "Step" & tIndex) into tObj
      set the textStyle of tObj to "bold"
      put lkLabel("Step" & tIndex & "_text", lkR(kStageLeft + 58, tTop + 32, kStageLeft + 250, tTop + tHeight - 6), \
            item 2 of tLine, 11, lkColor("soft"), "Step" & tIndex) into tObj
      put lkBox("Step" & tIndex & "_code", lkR(kStageLeft + 262, tTop + 10, 1000 - 12, tTop + tHeight - 10), lkColor("code"), 10, "Step" & tIndex) into tObj
      put lkLabel("Step" & tIndex & "_sql", lkR(kStageLeft + 276, tTop + 16, 1000 - 24, tTop + tHeight - 12), empty, 12, lkColor("codeInk"), "Step" & tIndex) into tObj
      set the textFont of tObj to measureFace()
      set the fixedLineHeight of tObj to true
      set the textHeight of tObj to 18
      set the htmlText of tObj to sqlHtml(item 3 of tLine)
      -- (in the middle of its box, up and down)
      set the height of tObj to the formattedHeight of tObj + 4
      codeFont tObj
      set the top of tObj to tTop + tHeight div 2 - (the formattedHeight of tObj + 4) div 2
      add tHeight + 10 to tTop
   end repeat
   set the itemDelimiter to comma
   -- The placeholders, and where the file is
   put lkLabel("Outro", lkR(kStageLeft, tTop + 6, 1000, kStageBottom), \
         "The :1 and :2 are placeholders: revDB puts the words you typed in their place, so that " & \
         "a quote in a title cannot break the statement. The database is a file named after the " & \
         "stack, SQLite Books.sqlite, in your documents folder.", 12, lkColor("soft"), empty) into tObj
end buildHowItWorks

-- A line of SQL in colour: its words in capitals as the language's own,
-- its strings and placeholders as values
private function sqlHtml pText
   local tOut, tWord, tColor, tLine, tEnd
   repeat for each line tLine in pText
      put "<p>" after tOut
      repeat for each word tWord in tLine
         -- (a placeholder, its colon and its number, as a value: the
         -- bracket or comma beside it, "(:1," or ":2)", in the words'
         -- colour, so that the two of VALUES (:1, :2) look alike)
         if char 1 to 2 of tWord is "(:" or char 1 of tWord is ":" then
            put offset(":", tWord) + 1 into tEnd
            repeat while char tEnd + 1 of tWord is a number
               add 1 to tEnd
            end repeat
            put "<font color=" & quote & "#e2e8f0" & quote & ">" & lkEscape(char 1 to offset(":", tWord) - 1 of tWord) & "</font>" & \
                  "<font color=" & quote & "#fcd34d" & quote & ">" & lkEscape(char offset(":", tWord) to tEnd of tWord) & "</font>" & \
                  "<font color=" & quote & "#e2e8f0" & quote & ">" & lkEscape(char tEnd + 1 to -1 of tWord) & "</font> " after tOut
            next repeat
         end if
         put "#e2e8f0" into tColor
         if toUpper(tWord) is tWord and tWord is not a number and the number of chars of tWord > 1 \
               and char 1 of tWord is not ":" and char 1 of tWord is not "'" then
            put "#c4b5fd" into tColor
         end if
         if char 1 of tWord is ":" or char 1 of tWord is "'" then
            put "#fcd34d" into tColor
         end if
         put "<font color=" & quote & tColor & quote & ">" & lkEscape(tWord) & "</font> " after tOut
      end repeat
      put "</p>" after tOut
   end repeat
   return tOut
end sqlHtml

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
-- (as the web IDE has Droid Sans Mono, not Source Code Pro)
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
   -- (a top margin of 12 puts the bold 12 in the middle of the header's
   -- 30, as in Data Grid Tables)
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
--SQLite Books: SQLite Book Library, one of OpenXTalk Lite's demos, remastered for OXT-Beyond in 2026
--(its author is not recorded)

--The library's handlers (preOpenStack, dbListAll, dbSearch, AddRecord and DeleteRecord) were in this
--stack script: they are in the script of the card "Library" now, so that the panel beside its stage
--shows them, and its preOpenStack is that card's preOpenCard.

on openStack  --added: a word, if the IDE's data grid library is not there to draw the grid
   if there is not a stack "revDataGridLibrary" then
      answer "The data grid on the Library card needs the IDE's data grid library, and it is not loaded." &cr& \
            "In Preferences, under Compatibility, untick Disable Data Grids, then start the IDE again." with "OK" titled "SQLite Books"
   end if
   pass openStack
end openStack

on preOpenCard  --added: the code on the card in the scripts panel's font (the web IDE, say, has Droid Sans Mono and not Source Code Pro)
   local tFont, tIndex, tField
   put codeFontHere() into tFont
   if tFont is not empty then
      repeat with tIndex = 1 to the number of fields of this card
         put the long id of field tIndex of this card into tField
         if the cCode of tField is true and the textFont of tField is not tFont then set the textFont of tField to tFont
      end repeat
   end if
   pass preOpenCard
end preOpenCard

function codeFontHere  --added: code's font, the scripts panel's (the window finds it before this stack's preOpenCard), or else the first of its choices this computer has
   local tFont
   if there is a field "codeText" then
      if the textFont of field "codeText" is not empty then return the textFont of field "codeText"
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then return tFont
   end repeat
   return empty
end codeFontHere
@*/

/*@ Library/card
--(remaster) a space after each comma of the database calls, so that the scripts panel can wrap them
local sDatabaseID  --script local, available to handlers below, persists until quit

on preOpenCard  --was preOpenStack, in the stack script
   local tName, tDatabaseFile, tTableSQL, tSQLStatement
   if sDatabaseID is an integer then  --added: open already, the last time this card opened
      put dbListAll() into fld "Display"
      pass preOpenCard
   end if
   if not dbLoaded() then  --added: a word, not a script error, where the database library is not loaded
      put "The database library, revDB, is not loaded here." into sDatabaseID
      put dbListAll() into fld "Display"
      pass preOpenCard
   end if
   put the short name of this stack into tName
   put dbFolder() & "/" & tName & ".sqlite" into tDatabaseFile
   if there is not a file tDatabaseFile then  --create db file
      put revOpenDatabase("sqlite", tDatabaseFile) into sDatabaseID
      if sDatabaseID is an integer then  --added: it opened (else the Display field says why)
         put "CREATE TABLE books(BookID INTEGER PRIMARY KEY AUTOINCREMENT, Author varchar(255), Title varchar(255))" into tTableSQL
         revExecuteSQL sDatabaseID, tTableSQL
         --add some inital entries:
         put "INSERT into books(Author,Title) VALUES ('Tolkien J','Lord Of The Rings')" into tSQLStatement
         revExecuteSQL sDatabaseID, tSQLStatement
         put "INSERT into books(Author,Title) VALUES ('Austen J','Pride And Prejudice')" into tSQLStatement
         revExecuteSQL sDatabaseID, tSQLStatement
         put "INSERT into books(Author,Title) VALUES ('Baum F','Wizard Of Oz')" into tSQLStatement
         revExecuteSQL sDatabaseID, tSQLStatement
      end if
   else put revOpenDatabase("sqlite", tDatabaseFile) into sDatabaseID  --db file exists
   put dbListAll() into fld "Display"
   pass preOpenCard  --added: the window lays out this card after it
end preOpenCard

function dbFolder  --added: where the database goes, the documents folder (the stack's own may not be writable)
   local tFolder
   put specialFolderPath("documents") into tFolder
   if tFolder is empty or there is not a folder tFolder then put specialFolderPath("temporary") into tFolder
   return tFolder
end dbFolder

function dbLoaded  --added: true if revDB is loaded (the IDE loads it, and the web engine has it built in)
   local tError
   try
      get revOpenDatabases()
   catch tError
      return false
   end try
   return true
end dbLoaded

function dbProblem  --added: what the Display field says when there is no database
   return "Sorry, the library could not open its database." &cr& sDatabaseID
end dbProblem

function dbListAll  --retrieve all from database:
   local tSQLStatement
   if sDatabaseID is not an integer then return dbProblem()  --added
   put "SELECT * FROM books" into tSQLStatement
   return revDataFromQuery(tab, cr, sDatabaseID, tSQLStatement)
end dbListAll

function dbSearch pSearchTerm  --retrieve where title or author matches search term
   local tSQLStatement, tLike
   if sDatabaseID is not an integer then return dbProblem()  --added
   --a placeholder (:1) for the search term, so that a quote in it cannot break the statement; it was:
   --put "SELECT * FROM books WHERE author LIKE '%" & pSearchTerm & "%' OR title LIKE '%" & pSearchTerm & "%'" into tSQLStatement
   put "%" & pSearchTerm & "%" into tLike
   put "SELECT * FROM books WHERE author LIKE :1 OR title LIKE :1" into tSQLStatement
   return revDataFromQuery(tab, cr, sDatabaseID, tSQLStatement, "tLike")
end dbSearch

command AddRecord pAuthor, pTitle  --add a record
   local tSQLStatement
   if sDatabaseID is not an integer then exit AddRecord  --added
   --placeholders (:1, :2) for the author and the title, as in dbSearch; it was:
   --put "INSERT INTO books(Author,Title) VALUES (" & quote & pAuthor & quote & comma & quote & pTitle & quote & ")" into tSQLStatement
   put "INSERT INTO books(Author,Title) VALUES (:1, :2)" into tSQLStatement
   revExecuteSQL sDatabaseID, tSQLStatement, "pAuthor", "pTitle"
   put dbListAll() into fld "Display"
end AddRecord

command DeleteRecord pID  --delete a record
   local tSQLStatement
   if sDatabaseID is not an integer then exit DeleteRecord  --added
   put "DELETE FROM books WHERE BookID = '" & pID & "'" into tSQLStatement
   revExecuteSQL sDatabaseID, tSQLStatement
   put dbListAll() into fld "Display"
end DeleteRecord
@*/

/*@ Library/Search Term
on returnInField
   put dbSearch(line 1 of me) into msg  --message box
   put dbSearch(line 1 of me) into fld "Display"  --added: and the Display field, which SQLite To DGTable copies
end returnInField
@*/

/*@ Library/+/- Record
on mouseUp
   local tAuthor, tTitle
   ask "Add Record: enter Author,Title." &cr& "Delete Record: enter record's ID integer." with "1" titled "Add/Delete Record"
   if it = empty then exit to top
   if the number of items in it = "2" then
      put item 1 of it into tAuthor
      put word 1 to -1 of item 2 of it into tTitle  --remove char 1 space
      AddRecord tAuthor, tTitle
   else if it is an integer and it >= "1" then DeleteRecord it
end mouseUp
@*/

/*@ Library/SQLite To DGTable
on mouseUp  --in button script, populate dg table
   local tData, tHeaders
   put field "Display" into tData  --tab delimited line list
   put "ID" &cr& "Author" &cr& "Title" into tHeaders
   set the dgProp["columns"] of group "DataGrid 1" to tHeaders  --populate headers first, line list
   replace cr with tab in tHeaders  --tab delimited
   set the dgText["true"] of group "DataGrid 1" to tHeaders &cr& tData  --headers in line 1
end mouseUp
@*/

/*@ How It Works/steps
Make the table|The first time, in a new database file.|CREATE TABLE books(BookID INTEGER PRIMARY KEY AUTOINCREMENT, Author varchar(255), Title varchar(255))
List every book|dbListAll, for the Display field.|SELECT * FROM books
Find a book|dbSearch, from the search field.|SELECT * FROM books WHERE author LIKE :1 OR title LIKE :1
Add a book|AddRecord, from +/- Record.|INSERT INTO books(Author,Title) VALUES (:1, :2)
Delete a book|DeleteRecord, by its ID.|DELETE FROM books WHERE BookID = '2'
@*/
