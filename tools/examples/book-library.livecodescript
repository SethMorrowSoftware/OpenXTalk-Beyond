script "OXTExampleBookLibrary"
-- OXT-Beyond: builds "Bookshelf", the remaster of Book Library, the second
-- sample of the Start Center, by LiveCode Ltd (its controls' ids date it to
-- 2014), which came with LiveCode Community under the GNU General Public
-- License, version 3. The original is in
-- ide/Resources/Start Center/samples/sample_2/BookLibrary.livecode, and it
-- stays there as LiveCode Ltd made it.
--
-- The sample keeps a list of books in an SQLite database: a card that says
-- what it does and a Go button, and a card with the list, a search, and a
-- book's details, which you can add, edit and delete. The remaster keeps
-- its scripts and their comments, in the window every remastered example
-- has (builder.livecodescript): the introduction is the front page and the
-- page "How It Works", the library is a wide card, and a page shows the
-- SQL each handler sends. The database handlers stay in the stack's
-- script, and the window's in the card's. What the remaster changed or
-- added is marked "(remaster)" in the scripts:
--
--    - bookAdd, bookUpdate and booksSearch hand the words to SQLite with
--      placeholders (:1, :2), so that a quote in a title (Charlotte's Web,
--      or the word "Title" in double quotes) no longer breaks the SQL;
--    - the database file is where the original put it, bookLibrary.sqlite
--      in the documents folder, which is writable (the stack's own folder
--      may not be), or the temporary folder if there is no documents
--      folder; in a browser, the web engine's documents folder;
--    - where the database library is not loaded, or the file cannot be
--      opened, the list says so, instead of a script error;
--    - the card is laid out on the stage (the window keeps one size), the
--      buttons are the window's, and the Status menu is a pulldown menu,
--      drawn as the window draws its controls;
--    - Save asks for a title, Edit and Delete ask for a book, and the
--      search finds as you type; each book has a cover in a colour of its
--      own.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- The library's card: the line between the list and the book's details
constant kDiv = 620

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   addIcons
   put "Bookshelf" into tInfo["name"]
   put "after LiveCode Ltd" into tInfo["credit"]
   put "library" into tInfo["icon"]
   put lkColor("indigo") into tInfo["accent"]
   put lkColor("violet") into tInfo["accent2"]
   put "Page" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Bookshelf|A library of your books, kept in an SQLite database.|library|front" & return & \
         "How It Works|How It Works|One file holds the whole library: how the stack makes it, and opens it.|database|page" & return & \
         "Book Data|The Library|Find a book, read about it, and add, change or delete books.|library-big|wide" & return & \
         "The SQL|The SQL|Each thing the library does is one line of SQL, which a handler sends.|code|page" into tInfo["cards"]
   codeFontForBuild
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   buildHow
   buildLibrary
   buildSQL
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Bookshelf.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

-- Icons the kit does not have, from Lucide (ISC licence)
private command addIcons
   exAddIcon "library", "<path d='m16 6 4 14'/><path d='M12 6v14'/><path d='M8 8v12'/><path d='M4 4v16'/>"
   exAddIcon "plus", "<path d='M5 12h14'/><path d='M12 5v14'/>"
   exAddIcon "trash-2", "<path d='M3 6h18'/><path d='M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6'/>" & \
         "<path d='M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2'/><line x1='10' x2='10' y1='11' y2='17'/><line x1='14' x2='14' y1='11' y2='17'/>"
   exAddIcon "chevron-down", "<path d='m6 9 6 6 6-6'/>"
   exAddIcon "book-marked", "<path d='M10 2v8l3-3 3 3V2'/>" & \
         "<path d='M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20'/>"
   exAddIcon "file-key-2", "<path d='M4 22h14a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v6'/><path d='M14 2v4a2 2 0 0 0 2 2h4'/>" & \
         "<circle cx='4' cy='16' r='2'/><path d='m10 10-4.5 4.5'/><path d='m9 11 1 1'/>"
end addIcons

-- The code on the pages is in Source Code Pro where the computer has it,
-- or else in a monospaced font: the card's script sets it when the card
-- opens. The engine here loads Source Code Pro where it can (not on
-- Linux), so that what is measured is measured in a code font
private command codeFontForBuild
   local tFile, tError
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me & "/ide/Toolset/resources/supporting_files/fonts/SourceCodePro-Regular.ttf" into tFile
   set the itemDelimiter to comma
   if "Source Code Pro" is among the lines of the fontNames or there is no file tFile then
      exit codeFontForBuild
   end if
   try
      start using font file tFile
   catch tError
   end try
end codeFontForBuild

################################################################################
#
# Drawing helpers
#

-- A label as tall as its text; returns its bottom
private function textBlock pName, pLeft, pTop, pRight, pText, pSize, pColor, pGroup
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + 400), pText, pSize, pColor, pGroup) into tObj
   set the height of tObj to the formattedHeight of tObj + 4
   set the top of tObj to pTop - 4
   return the bottom of tObj - 4
end textBlock

-- A heading, bold
private function heading pName, pLeft, pTop, pRight, pText, pSize, pGroup
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + pSize + 10), pText, pSize, lkColor("ink"), pGroup) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   return tObj
end heading

-- A small word in capitals, above a list or a value
private function caption pName, pRect, pText, pAlign, pGroup
   local tObj
   put lkLabel(pName, pRect, pText, 11, lkColor("muted"), pGroup, pAlign) into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   return tObj
end caption

-- An icon on a tint of a colour, in a rounded square
private command iconBadge pName, pIcon, pLeft, pTop, pSize, pColor, pGroup
   local tInset
   get lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), lkMix("255,255,255", pColor, 0.13), pSize div 3, pGroup)
   put (pSize - 20) div 2 into tInset
   get exIcon(pName & "_icon", pIcon, pColor, lkR(pLeft + tInset, pTop + tInset, pLeft + tInset + 20, pTop + tInset + 20), pGroup)
end iconBadge

-- A white panel with an icon and a title at its top; returns the top of
-- the room under the title
private function titledPanel pName, pRect, pTitle, pIcon, pColor
   local tObj
   get lkGroup(pName, pRect, empty)
   get exPanel(pName & "_bg", pRect, pName)
   iconBadge pName & "_badge", pIcon, item 1 of pRect + 20, item 2 of pRect + 16, 32, pColor, pName
   put heading(pName & "_title", item 1 of pRect + 62, item 2 of pRect + 22, item 3 of pRect - 20, pTitle, 16, pName) into tObj
   return item 2 of pRect + 64
end titledPanel

-- A panel of rows, each an icon and a line or two of words; with pActions
-- (a line for each row), a row is a button that goes to a card
private command rowsPanel pName, pRect, pTitle, pRows, pColor, pActions
   local tL, tT, tR, tB, tIndex, tRow, tTop, tObj, tGroup
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   put item 4 of pRect into tB
   get lkGroup(pName, pRect, empty)
   get exPanel(pName & "_bg", pRect, pName)
   put heading(pName & "_title", tL + 20, tT + 18, tR - 20, pTitle, 15, pName) into tObj
   set the itemDelimiter to "|"
   put 0 into tIndex
   repeat for each line tRow in pRows
      add 1 to tIndex
      put tT + 52 + (tIndex - 1) * 48 into tTop
      put pName & "_row" & tIndex into tGroup
      get lkGroup(tGroup, lkR(tL + 10, tTop - 6, tR - 10, tTop + 42), pName)
      get lkBox(tGroup & "_bg", lkR(tL + 10, tTop - 6, tR - 10, tTop + 42), "255,255,255", 12, tGroup)
      iconBadge tGroup & "_badge", item 1 of tRow, tL + 20, tTop, 36, pColor, tGroup
      put lkLabel(tGroup & "_text", lkR(tL + 68, tTop, tR - 22, tTop + 38), item 2 of tRow, 13, lkColor("soft"), tGroup) into tObj
      if line tIndex of pActions is not empty then
         -- (room at the right for a chevron; the item delimiter is | here)
         set the rect of tObj to tL + 68, the top of tObj, tR - 44, the bottom of tObj
      end if
      -- (one line or two, in the middle of the row; 4 more at the bottom
      -- keeps the last line's descenders whole)
      set the height of tObj to the formattedHeight of tObj + 4
      set the top of tObj to tTop + 18 - (the formattedHeight of tObj + 4) div 2
      if line tIndex of pActions is not empty then
         get exIcon(tGroup & "_go", "chevron-right", lkColor("muted"), lkR(tR - 34, tTop + 10, tR - 18, tTop + 26), tGroup)
         set the cRest of group tGroup to "255,255,255"
         set the cLit of group tGroup to lkMix("255,255,255", pColor, 0.07)
         set the cAction of group tGroup to line tIndex of pActions
      end if
   end repeat
   set the itemDelimiter to comma
end rowsPanel

-- A panel of numbered steps, each a few words in bold and a line or two
-- under them, pSpacing apart; pCode puts the bold words in the code's font
private command stepsPanel pName, pRect, pTitle, pIcon, pSteps, pColor, pCode, pSpacing
   local tL, tT, tR, tIndex, tStep, tTop, tObj
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   put titledPanel(pName, pRect, pTitle, pIcon, pColor) into tTop
   set the itemDelimiter to "|"
   put 0 into tIndex
   repeat for each line tStep in pSteps
      add 1 to tIndex
      put tT + 62 + (tIndex - 1) * pSpacing into tTop
      put lkOval(pName & "_n" & tIndex, lkR(tL + 22, tTop + 1, tL + 44, tTop + 23), lkMix("255,255,255", pColor, 0.14), pName) into tObj
      put lkLabel(pName & "_nl" & tIndex, lkR(tL + 22, tTop + 4, tL + 44, tTop + 20), tIndex, 11, pColor, pName, "center") into tObj
      set the textStyle of tObj to "bold"
      if pCode then
         put lkLabel(pName & "_head" & tIndex, lkR(tL + 56, tTop + 2, tR - 10, tTop + 20), item 1 of tStep, 11, \
               lkMix(pColor, lkColor("ink"), 0.25), pName) into tObj
         set the textFont of tObj to "Source Code Pro"
         set the cCode of tObj to true
      else
         put lkLabel(pName & "_head" & tIndex, lkR(tL + 56, tTop + 2, tR - 10, tTop + 20), item 1 of tStep, 13, \
               lkColor("ink"), pName) into tObj
      end if
      set the textStyle of tObj to "bold"
      set the dontWrap of tObj to true
      put lkLabel(pName & "_text" & tIndex, lkR(tL + 56, tTop + 23, tR - 14, tTop + pSpacing - 6), item 2 of tStep, 12, lkColor("soft"), pName) into tObj
   end repeat
   set the itemDelimiter to comma
end stepsPanel

-- A panel of handlers: each name in the code's font, and what it does
private command handlersPanel pName, pRect, pTitle, pIcon, pRows, pColor
   local tL, tT, tR, tIndex, tRow, tTop, tObj
   put item 1 of pRect into tL
   put item 2 of pRect into tT
   put item 3 of pRect into tR
   put titledPanel(pName, pRect, pTitle, pIcon, pColor) into tTop
   set the itemDelimiter to "|"
   put 0 into tIndex
   repeat for each line tRow in pRows
      add 1 to tIndex
      put tT + 62 + (tIndex - 1) * 26 into tTop
      put lkLabel(pName & "_name" & tIndex, lkR(tL + 22, tTop, tL + 152, tTop + 18), item 1 of tRow, 12, \
            lkMix(pColor, lkColor("ink"), 0.2), pName) into tObj
      set the textFont of tObj to "Source Code Pro"
      set the cCode of tObj to true
      set the textStyle of tObj to "bold"
      set the dontWrap of tObj to true
      put lkLabel(pName & "_what" & tIndex, lkR(tL + 156, tTop, tR - 16, tTop + 18), item 2 of tRow, 12, lkColor("soft"), pName) into tObj
      set the dontWrap of tObj to true
   end repeat
   set the itemDelimiter to comma
end handlersPanel

-- A line, an arrow if pArrow
private function lineGraphic pName, pPoints, pColor, pSize, pArrow, pDashes, pGroup
   local tObj
   if pGroup is empty then
      create graphic pName
   else
      create graphic pName in group pGroup
   end if
   put it into tObj
   set the style of tObj to "line"
   set the points of tObj to pPoints
   set the lineSize of tObj to pSize
   set the foregroundColor of tObj to pColor
   set the antialiased of tObj to true
   set the capStyle of tObj to "round"
   if pArrow then
      set the endArrow of tObj to true
      set the arrowSize of tObj to 3
   end if
   if pDashes is not empty then
      set the dashes of tObj to pDashes
   end if
   return tObj
end lineGraphic

-- A word in the code's font on a tint, as a file's name is shown. The
-- page sets the code's font when it opens (its card's script), and a
-- monospaced font is wider than most: the chip is as wide as the words in
-- the wider of the two, and they are in its middle
private function pathChip pName, pLeft, pTop, pText, pColor, pGroup
   local tBox, tObj, tWidth
   put lkBox(pName, lkR(pLeft, pTop, pLeft + 100, pTop + 30), lkMix("255,255,255", pColor, 0.1), 10, pGroup) into tBox
   put lkLabel(pName & "_text", lkR(pLeft + 12, pTop + 6, pLeft + 600, pTop + 24), pText, 12, lkMix(pColor, lkColor("ink"), 0.3), pGroup, "center") into tObj
   set the dontWrap of tObj to true
   put measureText(pText, tObj) into tWidth
   if "DejaVu Sans Mono" is among the lines of the fontNames then
      set the textFont of tObj to "DejaVu Sans Mono"
      put max(tWidth, measureText(pText, tObj)) into tWidth
   end if
   put max(tWidth, round(the number of chars of pText * 12 * 0.61)) + 8 into tWidth
   set the textFont of tObj to "Source Code Pro"
   set the cCode of tObj to true
   set the rect of tObj to pLeft + 12, the top of tObj, pLeft + 12 + tWidth, the bottom of tObj
   set the rect of tBox to pLeft, pTop, pLeft + tWidth + 24, pTop + 30
   return pTop + 30
end pathChip

-- SQL in colour, as the scripts panel colours xTalk: its words in violet,
-- what it is given (:1, 'words') in teal and amber, numbers in orange
private function sqlHtml pSQL
   local tOut, tPos, tLen, tChar, tStart, tWord
   put the number of chars of pSQL into tLen
   put 1 into tPos
   repeat while tPos <= tLen
      put char tPos of pSQL into tChar
      if tChar is "'" then
         put tPos into tStart
         add 1 to tPos
         repeat while tPos <= tLen and char tPos of pSQL is not "'"
            add 1 to tPos
         end repeat
         put lkSpan(char tStart to tPos of pSQL, "#fcd34d") after tOut
         add 1 to tPos
      else if tChar is ":" and char tPos + 1 of pSQL is a number then
         put lkSpan(char tPos to tPos + 1 of pSQL, "#5eead4") after tOut
         add 2 to tPos
      else if lkIsWordChar(tChar) then
         put tPos into tStart
         repeat while tPos <= tLen and lkIsWordChar(char tPos of pSQL)
            add 1 to tPos
         end repeat
         put char tStart to tPos - 1 of pSQL into tWord
         if tWord is a number then
            put lkSpan(tWord, "#fdba74") after tOut
         else if tWord is among the items of "create,table,integer,primary,key,autoincrement,varchar,insert,into,values,select,from,where,like,or,and,update,set,delete" then
            put lkSpan(tWord, "#c4b5fd") after tOut
         else
            put lkSpan(tWord, "#e2e8f0") after tOut
         end if
      else
         put lkSpan(tChar, "#94a3b8") after tOut
         add 1 to tPos
      end if
   end repeat
   return tOut
end sqlHtml

################################################################################
#
# The cards
#

-- The front page: what this is and who made it, the sample's Go button,
-- a tile for each card, what to try and what it teaches
private command buildFront
   local tObj, tIndex, tX, tY, tH, tW, tWidth
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 300), lkColor("indigo") & "|" & lkColor("violet") & "|" & lkColor("pink"), \
         "LIVECODE LTD  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "Your books, in an SQLite database", \
         "Search your books, read about each one, and add, change or delete them: " & \
         "a small app that keeps its whole library in one SQLite file."
   -- (the words stop short of the shelf)
   put the long id of field "hero_text" of group "hero" into tObj
   set the rect of tObj to item 1 of the rect of tObj, item 2 of the rect of tObj, item 1 of the rect of tObj + 520, item 4 of the rect of tObj
   -- (the sparkles, around the shelf: off the words, and off the books)
   repeat with tIndex = 1 to 6
      set the loc of graphic ("hero_star" & tIndex) of group "hero" to \
            item tIndex of "808,792,826,948,963,836", item tIndex of "134,233,192,282,143,273"
      show graphic ("hero_star" & tIndex) of group "hero"
   end repeat
   -- A shelf of books, at the banner's right
   put lkBox("hero_shelf", lkR(842, 254, 986, 260), "255,255,255", 3, "hero") into tObj
   set the blendLevel of tObj to 20
   lkShadow tObj, 8, 3, 25
   put 850 into tX
   repeat with tIndex = 1 to 6
      put item tIndex of "17,13,19,14,20,15" into tW
      put item tIndex of "88,70,100,80,94,74" into tH
      put lkBox("hero_book" & tIndex, lkR(tX, 254 - tH, tX + tW, 254), "255,255,255", 3, "hero") into tObj
      set the blendLevel of tObj to item tIndex of "8,35,0,22,12,40"
      lkShadow tObj, 6, 2, 18
      -- (a band on some of the spines)
      if tIndex is among the items of "1,3,5" then
         put lkBox("hero_band" & tIndex, lkR(tX + 3, 254 - tH + 12, tX + tW - 3, 254 - tH + 16), lkColor("violet"), 1, "hero") into tObj
         set the blendLevel of tObj to 40
      end if
      add tW + 3 to tX
   end repeat
   -- (the last one leans on the others)
   create graphic "hero_lean" in group "hero"
   put it into tObj
   set the style of tObj to "polygon"
   set the opaque of tObj to true
   set the lineSize of tObj to 0
   set the antialiased of tObj to true
   set the backgroundColor of tObj to "255,255,255"
   set the points of tObj to tX + 1 & ",254" & return & tX + 15 & ",254" & return & tX + 33 & ",178" & return & tX + 19 & ",175" & return & tX + 1 & ",254"
   set the blendLevel of tObj to 18
   -- The sample's Go button, which opens the library
   put exButton("Go", kLeft + 32, 246, 38, "Open the library", "book-open", "light", lkColor("indigo"), empty, empty, 0) into tWidth
   set the script of group "Go" to exScript("Start/Go")
   exProgramTiles 316, 3, 60, 12
   -- What to try, and what it teaches
   rowsPanel "Try", lkR(kLeft, 392, 620, kBottom), "Try it", \
         "library-big|Open the library, and choose a book to read about it." & return & \
         "pencil|Edit a book: lend it out, add a comment, then save it." & return & \
         "search|Search for a word of a title or an author.", \
         lkColor("indigo"), empty
   rowsPanel "Learn", lkR(636, 392, kRight, kBottom), "What you will learn", \
         "database|Make a database file, with a table in it" & return & \
         "code|Add, change, find and delete rows with SQL" & return & \
         "table|Show what a query finds, in a list", \
         lkColor("violet"), "go How It Works" & return & "go The SQL" & return & "go Book Data"
end buildFront

-- How It Works: the introduction's teaching, in four panels: the file,
-- what happens when the stack opens, and where the code is
private command buildHow
   local tTop, tObj
   go card "How It Works"
   set the script of this card to exScript("Page/code font")
   -- The file
   put titledPanel("File", lkR(kLeft, kTop, 620, 330), "One file is the whole library", "file-key-2", lkColor("indigo")) into tTop
   put textBlock("File_text", kLeft + 22, tTop, 600, \
         "SQLite keeps a whole database in a single file on your computer: there is no server to set up. " & \
         "This library is one file, in your documents folder:", 13, lkColor("soft"), "File") into tTop
   put pathChip("File_path", kLeft + 22, tTop + 10, "Documents/bookLibrary.sqlite", lkColor("indigo"), "File") into tTop
   put textBlock("File_note", kLeft + 22, tTop + 12, 600, \
         "In a browser, the web engine keeps it for the page. Delete the file, and the stack makes a new one.", \
         12, lkColor("muted"), "File") into tTop
   -- When the stack opens
   stepsPanel "Opens", lkR(636, kTop, kRight, 330), "When the stack opens", "rocket", \
         "Look for the file|bookLibrary.sqlite, in the documents folder." & return & \
         "Not there? Make it|Open it new, add a books table, and three books." & return & \
         "There? Open it|Its number goes to every handler that uses it.", \
         lkColor("violet"), false, 50
   -- Where the code is
   handlersPanel "StackCode", lkR(kLeft, 346, 620, kBottom), "The stack's script: the data", "database", \
         "preOpenStack|opens the library, or makes it" & return & \
         "bookAdd|adds a book" & return & \
         "bookUpdate|changes a book" & return & \
         "bookDelete|deletes a book" & return & \
         "booksListAll|lists every book" & return & \
         "booksSearch|finds the books a word is in", \
         lkColor("indigo")
   put textBlock("StackCode_note", kLeft + 22, 568, 600, \
         "With a server, such as MySQL or PostgreSQL, revOpenDatabase would open it instead of a file.", \
         12, lkColor("muted"), "StackCode") into tTop
   handlersPanel "CardCode", lkR(636, 346, kRight, kBottom), "The card's script: the window", "layout-grid", \
         "listBooks|fills the list with every book" & return & \
         "searchBooks|fills it with what a search finds" & return & \
         "showBookDetails|shows the book chosen" & return & \
         "newBook, editBook|let you type in its details" & return & \
         "saveBook|adds the book, or updates it" & return & \
         "deleteBook|asks, then deletes it" & return & \
         "layoutCard|puts each control in its place", \
         lkColor("violet")
end buildHow

-- The Library: the sample's card "Book Data", with its list, search and
-- book's details on the stage, and its program in the card's script.
-- layoutCard, in that script, puts each control in its place: what is
-- made here is laid out by it at the end
private command buildLibrary
   local tObj, tWidth, tGroup
   go card "Book Data"
   set the script of this card to exScript("Book Data/card")
   -- The line between the two halves
   put lkBox("verticalDiv", lkR(kDiv, kTop + 1, kDiv + 1, kBottom - 1), lkColor("line"), 0, empty) into tObj
   -- The search box: its box, an icon and the words in it when it is empty
   put lkBox("SearchBox", lkR(kLeft + 16, kTop + 16, kDiv - 16, kTop + 52), "248,250,252", 18, empty) into tObj
   lkBorder tObj, lkColor("line")
   put exIcon("SearchIcon", "search", lkColor("muted"), lkR(kLeft + 30, kTop + 26, kLeft + 46, kTop + 42), empty) into tObj
   put lkLabel("SearchHint", lkR(kLeft + 54, kTop + 25, kDiv - 110, kTop + 43), "Search titles and authors", 13, lkColor("muted"), empty) into tObj
   set the dontWrap of tObj to true
   -- The search's field, in front of those words. It is the first field
   -- on the card, as in the sample: when the card opens, the engine puts
   -- the keyboard focus in the first control that takes it, and here that
   -- is the search, not the list (whose first line would light up)
   create field "Search Term"
   put it into tObj
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the opaque of tObj to false
   set the showBorder of tObj to false
   set the showFocusBorder of tObj to false
   set the threeD of tObj to false
   set the dontWrap of tObj to true
   set the textSize of tObj to 13
   set the textColor of tObj to lkColor("ink")
   set the margins of tObj to "4,8,4,4"
   set the rect of tObj to kLeft + 50, kTop + 19, kDiv - 100, kTop + 49
   set the script of tObj to exScript("Book Data/Search Term")
   -- What the list says when it is empty, behind it
   put lkLabel("ListEmpty", lkR(kLeft + 32, 330, kDiv - 32, 400), empty, 13, lkColor("soft"), empty, "center") into tObj
   hide tObj
   -- The list: the books, a line each, in columns (the comments and the
   -- BookID are there too, out of sight at the right)
   create field "List"
   put it into tObj
   set the lockText of tObj to true
   set the listBehavior of tObj to true
   set the multipleHilites of tObj to false
   set the traversalOn of tObj to true
   set the opaque of tObj to false
   set the showBorder of tObj to false
   set the showFocusBorder of tObj to false
   set the threeD of tObj to false
   set the dontWrap of tObj to true
   set the textSize of tObj to 13
   set the textColor of tObj to lkColor("ink")
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 32
   set the margins of tObj to "6,4,6,4"
   set the scrollbarWidth of tObj to 12
   -- (a table: each column clips its words, and its lines are white)
   set the vGrid of tObj to true
   set the borderColor of tObj to "255,255,255"
   set the tabStops of tObj to "150,254,2000,4000"
   set the hiliteColor of tObj to lkMix("255,255,255", lkColor("indigo"), 0.12)
   set the vScrollbar of tObj to false
   set the rect of tObj to kLeft + 16, 188, kDiv - 16, 552
   set the script of tObj to exScript("Book Data/List")
   -- Save (made here so that its script is one of the panel's chips)
   put exButton("Save", 900, kBottom - 52, 36, "Save", "check", "primary", lkColor("indigo"), empty, empty, 88) into tWidth
   set the script of group "Save" to exScript("Book Data/Save")
   -- The list's titles, over its columns
   create field "List Titles"
   put it into tObj
   set the lockText of tObj to true
   set the traversalOn of tObj to false
   set the opaque of tObj to false
   set the showBorder of tObj to false
   set the threeD of tObj to false
   set the dontWrap of tObj to true
   set the textSize of tObj to 11
   set the textStyle of tObj to "bold"
   set the textColor of tObj to lkColor("muted")
   set the margins of tObj to "6,4,6,0"
   set the vGrid of tObj to true
   set the borderColor of tObj to "255,255,255"
   set the tabStops of tObj to "150,254,2000,4000"
   set the text of tObj to "TITLE" & tab & "AUTHOR" & tab & "STATUS"
   set the rect of tObj to kLeft + 16, 164, kDiv - 16, 188
   -- The buttons: Search, and Add, Edit and Delete under the list
   put exButton("Search", kDiv - 96, kTop + 20, 28, "Search", empty, "primary", lkColor("indigo"), empty, empty, 0) into tWidth
   set the script of group "Search" to exScript("Book Data/Search")
   put exButton("Add Book", kLeft + 16, kBottom - 52, 36, "Add book", "plus", "primary", lkColor("indigo"), empty, empty, 0) into tWidth
   set the script of group "Add Book" to exScript("Book Data/Add Book")
   put exButton("Edit Book", kLeft + 16 + tWidth + 8, kBottom - 52, 36, "Edit", "pencil", "ghost", lkColor("indigo"), empty, empty, 0) into tWidth
   set the script of group "Edit Book" to exScript("Book Data/Edit Book")
   put exButton("Delete Book", kDiv - 110, kBottom - 52, 36, "Delete", "trash-2", "ghost", lkColor("rose"), empty, empty, 0) into tWidth
   set the script of group "Delete Book" to exScript("Book Data/Delete Book")
   -- The cover: the book's colour, a spine, its title and author; a book's
   -- icon when there is no book
   -- (the group is bigger than the cover, which casts a shadow; the anchor
   -- keeps the cover from going to the group's top left)
   get lkGroup("Cover", lkR(kDiv + 4, kTop + 8, kDiv + 128, kTop + 176), empty)
   get lkBox("CoverAnchor", lkR(kDiv + 4, kTop + 8, kDiv + 5, kTop + 9), empty, 0, "Cover")
   put lkBox("CoverArt", lkR(kDiv + 16, kTop + 20, kDiv + 116, kTop + 160), "241,245,249", 6, "Cover") into tObj
   lkShadow tObj, 12, 4, 22
   put lkBox("CoverSpine", lkR(kDiv + 16, kTop + 20, kDiv + 25, kTop + 160), "15,23,42", 0, "Cover") into tObj
   set the blendLevel of tObj to 78
   put lkBox("CoverLine", lkR(kDiv + 27, kTop + 20, kDiv + 28, kTop + 160), "255,255,255", 0, "Cover") into tObj
   set the blendLevel of tObj to 70
   put exIcon("CoverIcon", "book-marked", lkColor("muted"), lkR(kDiv + 50, kTop + 52, kDiv + 82, kTop + 84), "Cover") into tObj
   put lkLabel("CoverTitle", lkR(kDiv + 32, kTop + 36, kDiv + 110, kTop + 124), empty, 13, "255,255,255", "Cover", "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("CoverAuthor", lkR(kDiv + 32, kTop + 132, kDiv + 110, kTop + 150), empty, 10, "255,255,255", "Cover", "center") into tObj
   set the dontWrap of tObj to true
   set the blendLevel of tObj to 15
   -- The book's details: title, author, status and comments
   put caption("Title Label", lkR(756, kTop + 20, kRight - 16, kTop + 34), "TITLE", "left", empty) into tObj
   bookField "Title", lkR(748, kTop + 36, kRight - 16, kTop + 68), 16, lkColor("ink"), true
   put caption("Author Label", lkR(756, kTop + 78, kRight - 16, kTop + 92), "AUTHOR", "left", empty) into tObj
   bookField "Author", lkR(748, kTop + 94, kRight - 16, kTop + 124), 14, lkColor("soft"), false
   put caption("Status Label", lkR(756, kTop + 134, kRight - 16, kTop + 148), "STATUS", "left", empty) into tObj
   -- (the Status menu's box, which shows while a book is edited)
   get lkGroup("StatusBox", lkR(748, kTop + 150, 880, kTop + 180), empty)
   put lkBox("StatusBox_bg", lkR(748, kTop + 150, 880, kTop + 180), "255,255,255", 15, "StatusBox") into tObj
   lkBorder tObj, "203,213,225"
   get exIcon("StatusBox_chevron", "chevron-down", lkColor("soft"), lkR(856, kTop + 158, 870, kTop + 172), "StatusBox")
   hide group "StatusBox"
   create button "Status"
   put it into tObj
   set the style of tObj to "menu"
   set the menuMode of tObj to "pulldown"
   set the text of tObj to "On Shelf" & return & "On Loan"
   set the label of tObj to "On Shelf"
   set the threeD of tObj to false
   set the showBorder of tObj to false
   set the opaque of tObj to false
   set the traversalOn of tObj to false
   set the textSize of tObj to 13
   set the textColor of tObj to lkColor("ink")
   set the textAlign of tObj to "left"
   set the margins of tObj to 8
   set the rect of tObj to 748, kTop + 150, 880, kTop + 180
   set the enabled of tObj to false
   set the script of tObj to exScript("Book Data/Status")
   put caption("Comments Label", lkR(kDiv + 18, kTop + 190, kRight - 16, kTop + 204), "COMMENTS", "left", empty) into tObj
   put lkBox("CommentsBox", lkR(kDiv + 16, kTop + 208, kRight - 16, kBottom - 68), "248,250,252", 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   create field "Comments"
   put it into tObj
   set the lockText of tObj to true
   set the traversalOn of tObj to true
   set the opaque of tObj to false
   set the showBorder of tObj to false
   set the showFocusBorder of tObj to false
   set the threeD of tObj to false
   set the dontWrap of tObj to false
   set the textSize of tObj to 13
   set the textColor of tObj to lkColor("soft")
   set the margins of tObj to "10,8,10,8"
   set the scrollbarWidth of tObj to 10
   set the vScrollbar of tObj to false
   set the rect of tObj to kDiv + 18, kTop + 210, kRight - 18, kBottom - 70
   -- Cancel, at Save's left; the BookID, which is never seen
   put exButton("Cancel", 800, kBottom - 52, 36, "Cancel", "x", "ghost", lkColor("indigo"), empty, empty, 0) into tWidth
   set the script of group "Cancel" to exScript("Book Data/Cancel")
   put lkLabel("bookID", lkR(kDiv + 16, kBottom - 40, kDiv + 80, kBottom - 24), empty, 11, lkColor("muted"), empty) into tObj
   hide tObj
   -- As the card is when it opens: nothing being edited, Save and Cancel
   -- faded, and every control in its place
   set the enabled of group "Save" to false
   set the enabled of group "Cancel" to false
   set the blendLevel of group "Save" to 60
   set the blendLevel of group "Cancel" to 60
   dispatch "layoutCard" to this card
end buildLibrary

-- A field of the book's details: white, with a border while it is edited
private command bookField pName, pRect, pSize, pColor, pBold
   local tObj
   create field pName
   put it into tObj
   set the lockText of tObj to true
   set the traversalOn of tObj to true
   set the opaque of tObj to true
   set the backgroundColor of tObj to "255,255,255"
   set the showBorder of tObj to false
   set the showFocusBorder of tObj to false
   set the threeD of tObj to false
   set the borderWidth of tObj to 1
   set the borderColor of tObj to "203,213,225"
   set the dontWrap of tObj to true
   set the textSize of tObj to pSize
   set the textColor of tObj to pColor
   if pBold then
      set the textStyle of tObj to "bold"
   end if
   -- (the words in the middle of the box, up and down)
   set the margins of tObj to "8,10,8,0"
   set the rect of tObj to pRect
   set the script of tObj to exScript("Book Data/Title and Author")
end bookField

-- The SQL: each statement the library sends, in colour, with the handler
-- that sends it; why the remaster's SQL has :1 in it; and the two ways to
-- talk to a database
private command buildSQL
   local tObj, tHtml, tLine, tIndex, tTop, tCount
   go card "The SQL"
   set the script of this card to exScript("Page/code font")
   -- (tall enough for the SQL in a monospaced font, which is wider: eight
   -- lines, where it is six in the window's font)
   put lkBox("SQLBox", lkR(kLeft, kTop, kRight, 360), lkColor("code"), 16, empty) into tObj
   lkShadow tObj, 16, 4, 18
   get lkOval("SQLBox_dot1", lkR(kLeft + 16, kTop + 15, kLeft + 25, kTop + 24), "248,113,113", empty)
   get lkOval("SQLBox_dot2", lkR(kLeft + 31, kTop + 15, kLeft + 40, kTop + 24), "251,191,36", empty)
   get lkOval("SQLBox_dot3", lkR(kLeft + 46, kTop + 15, kLeft + 55, kTop + 24), "52,211,153", empty)
   put lkLabel("SQLBox_caption", lkR(kLeft + 66, kTop + 12, kRight - 14, kTop + 28), \
         "The SQL each handler sends, from the stack's script", 11, "100,116,139", empty) into tObj
   set the dontWrap of tObj to true
   -- (in the middle of the dots, up and down, as the scripts panel's is)
   set the top of tObj to kTop + 20 - (the formattedHeight of tObj + 4) div 2
   put "preOpenStack|CREATE TABLE books(BookID INTEGER PRIMARY KEY AUTOINCREMENT, Title varchar(255),Author varchar(255),Status varchar(50),Comments varchar(500))" & return & \
         "booksListAll|SELECT Title,Author,Status,Comments, BookID from books" & return & \
         "booksSearch|SELECT Title,Author,Status,Comments,BookID from books WHERE title LIKE :1 OR author LIKE :1" & return & \
         "bookAdd|INSERT into books(Title,Author,Status,Comments) VALUES (:1, :2, :3, :4)" & return & \
         "bookUpdate|UPDATE books SET status=:1, title=:2, author=:3, comments=:4 WHERE BookID = :5" & return & \
         "bookDelete|DELETE from books WHERE BookID = '3'" into tLine
   set the itemDelimiter to "|"
   put 0 into tCount
   repeat for each line tIndex in tLine
      add 1 to tCount
      put "<p>" & lkSpan(item 1 of tIndex, "#5eead4") & tab & sqlHtml(item 2 to -1 of tIndex) & "</p>" after tHtml
   end repeat
   set the itemDelimiter to comma
   put lkLabel("SQLBox_code", lkR(kLeft + 6, kTop + 40, kRight - 8, 352), empty, 12, lkColor("codeInk"), empty) into tObj
   set the textFont of tObj to "Source Code Pro"
   set the cCode of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 19
   set the margins of tObj to "12,4,12,4"
   set the tabStops of tObj to 128
   set the htmlText of tObj to tHtml
   -- (each statement's lines under its first, after the handler's name)
   repeat with tIndex = 1 to tCount
      set the leftIndent of line tIndex of tObj to 128
      set the firstIndent of line tIndex of tObj to -128
      if tIndex > 1 then
         set the spaceAbove of line tIndex of tObj to 9
      end if
   end repeat
   -- Why :1: two paragraphs in one field, so that the second follows the
   -- first in any font (the IDE's are a little wider than the build's)
   put titledPanel("Why", lkR(kLeft, 376, 620, kBottom), "Why :1, and not the words", "lightbulb", lkColor("amber")) into tTop
   put lkLabel("Why_text", lkR(kLeft + 22, tTop, 600, kBottom - 12), \
         "The original put each word into the SQL itself, between quotes. A title with a quote in it, " & \
         "such as Charlotte's Web, ended those words too soon, and the SQL broke." & return & \
         "With :1 and :2 in the SQL, and the names of variables after it, revDB hands their words to SQLite " & \
         "apart from the SQL: any word is safe.", 13, lkColor("soft"), "Why") into tObj
   set the spaceAbove of line 2 of tObj to 12
   -- Two ways to talk to a database
   stepsPanel "Ways", lkR(636, 376, kRight, kBottom), "Changes, and questions", "database", \
         "revExecuteSQL|Changes the database: CREATE, INSERT, UPDATE and DELETE. The result is how many rows changed, or what went wrong." & return & \
         "revDataFromQuery|Asks it a question: SELECT. It returns the rows found, a tab between columns and a return between rows.", \
         lkColor("teal"), true, 84
end buildSQL

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Bookshelf: LiveCode Ltd's Book Library, the second sample of the Start Center, remastered for OXT-Beyond in 2026
--Book Library: LiveCode Ltd, 2014. It came with LiveCode Community, under the GNU General Public License, version 3

--These are the database handlers: preOpenStack opens the library, and makes it the first time, and
--the others add, update, delete and find books in it. The window's handlers are in the script of the
--card "Book Data", and call these. What the remaster added or changed is marked (remaster).

local sDatabaseID
-- (remaster) Why the library could not be opened, if it could not
local sDatabaseProblem

on preOpenStack
   local tDatabaseFile
   local tSQLStatement -- (remaster) declared, for strict compilation
   put empty into sDatabaseProblem
   -- (remaster) Without the database library, revDB, the stack opens all
   -- the same, and the list says why it is empty
   if not databaseLoaded() then
      put "The database library, revDB, is not loaded here." into sDatabaseProblem
      exit preOpenStack
   end if
   #check specialFolderPath("documents") is not empty
   -- (remaster) and that the folder is there: a computer may have none
   if specialFolderPath("documents") is not empty and there is a folder specialFolderPath("documents") then
      ## Connect to the SQLite database using the database file path
      -- (remaster) The library is the file bookLibrary.sqlite in your
      -- documents folder, where you can write (this stack's own folder may
      -- be the application's, where you cannot). In a browser, the web
      -- engine keeps the documents folder for the page
      put specialFolderPath("documents") & "/bookLibrary.sqlite" into tDatabaseFile
   else
      put specialFolderPath("temporary") & "/bookLibrary.sqlite" into tDatabaseFile
   end if

   if there is not a file tDatabaseFile then
      ## If the file does not exist it will be automatically created
      local tTableSQL

      ## Add a books table
      put revOpenDatabase("sqlite",tDatabaseFile) into sDatabaseID
      put "CREATE TABLE books(BookID INTEGER PRIMARY KEY AUTOINCREMENT, Title varchar(255),Author varchar(255),Status varchar(50),Comments varchar(500))" into tTableSQL
      revExecuteSQL sDatabaseID,tTableSQL

      ## Add some inital entries
      put "INSERT into books(Title,Author,Status) VALUES ('The Lord of the Rings','JRR Tolkien','On Shelf')" into tSQLStatement
      revExecuteSQL sDatabaseID,tSQLStatement
      -- put the result -- (remaster) a line left from testing: it put the result in the Message Box

      put "INSERT into books(Title,Author,Status) VALUES ('Pride and Prejudice','Jane Austen','On Shelf')" into tSQLStatement
      revExecuteSQL sDatabaseID,tSQLStatement

      put "INSERT into books(Title,Author,Status) VALUES ('His Dark Materials','Philip Pullman','On Shelf')" into tSQLStatement
      revExecuteSQL sDatabaseID,tSQLStatement
   else
      ## The database exists so simply connect to it
      put revOpenDatabase("sqlite",tDatabaseFile) into sDatabaseID
   end if

   -- (remaster) A database that did not open says why, in the list
   if sDatabaseID is not an integer then
      put sDatabaseID into sDatabaseProblem
      put empty into sDatabaseID
   end if
end preOpenStack

-- (remaster) True where the database library, revDB, is loaded: the IDE
-- loads it, and the web engine has it built in. Without it, its commands
-- would stop the stack with an error
function databaseLoaded
   local tError
   try
      get revOpenDatabases()
   catch tError
      return false
   end try
   return true
end databaseLoaded

-- (remaster) Why the library could not be opened, or empty if it was
function databaseProblem
   return sDatabaseProblem
end databaseProblem

## Add a book to the database
command bookAdd pTitle, pAuthor, pStatus, pComments
   local tSQLStatement
   if sDatabaseID is empty then exit bookAdd -- (remaster) no database: see preOpenStack

   ## Construct the SQL statement and execute it on the database
   -- (remaster) The original put the words themselves into the SQL, each
   -- between double quotes:
   --    put "INSERT into books(Title,Author,Status,Comments) VALUES (" & quote & pTitle & quote & comma & quote & pAuthor & quote & comma & quote & pStatus & quote & comma & quote & pComments & quote & ")" into tSQLStatement
   -- so a double quote in a title broke the SQL, and SQLite took a title
   -- that is a column's name, such as Title, for that column. :1 to :4
   -- stand for the variables named after the SQL, whose words go to
   -- SQLite as they are
   put "INSERT into books(Title,Author,Status,Comments) VALUES (:1, :2, :3, :4)" into tSQLStatement
   revExecuteSQL sDatabaseID,tSQLStatement, "pTitle", "pAuthor", "pStatus", "pComments"

   ## Give some feedback to the user
   if the result is an integer then
      answer "Book successfully added."
   else
      answer "Sorry, there was a problem adding that book."
   end if
end bookAdd

## Update a book in the database
command bookUpdate pBookID, pTitle, pAuthor, pStatus, pComments
   local tSQLStatement
   if sDatabaseID is empty then exit bookUpdate -- (remaster) no database: see preOpenStack

   ## Construct the SQL statement and execute it on the database
   -- (remaster) with :1 to :5, as bookAdd does. The original's
   --    put "UPDATE books SET status='" & pStatus & "', title='" & pTitle & "',author='" & pAuthor & "',comments='" & pComments &"' WHERE BookID = '" & pBookID & "'" into tSQLStatement
   -- broke on a word with an apostrophe in it, such as Charlotte's Web
   put "UPDATE books SET status=:1, title=:2, author=:3, comments=:4 WHERE BookID = :5" into tSQLStatement
   revExecuteSQL sDatabaseID,tSQLStatement, "pStatus", "pTitle", "pAuthor", "pComments", "pBookID"

   ## Give some feedback to the user
   if the result is an integer then
      answer "Book successfully updated."
   else
      answer "Sorry, there was a problem updating that book."
   end if
end bookUpdate

## Delete a book from the database
command bookDelete pBookID
   local tSQLStatement
   if sDatabaseID is empty then exit bookDelete -- (remaster) no database: see preOpenStack

   ## Construct the SQL statement and execute it on the database
   put "DELETE from books WHERE BookID = '" & pBookID & "'" into tSQLStatement
   revExecuteSQL sDatabaseID,tSQLStatement

   ## Give some feedback to the user
   if the result is an integer then
      answer "Book successfully deleted."
   else
      answer "Sorry, there was a problem deleting that book."
   end if
end bookDelete

## Retrieve a list of books from the database and return it
function booksListAll
   local tSQLStatement, tList
   if sDatabaseID is empty then return empty -- (remaster) no database: see preOpenStack

   ## Construct the SQL statement and query the database
   put "SELECT Title,Author,Status,Comments, BookID from books" into tSQLStatement
   put revDataFromQuery(tab,return,sDatabaseID,tSQLStatement) into tList
   return tList
end booksListAll

## Retrieve a list of books where the Title or Author matches a search term
function booksSearch pSearchTerm
   local tSQLStatement, tList
   local tPattern -- (remaster) what LIKE looks for: % is any letters
   if sDatabaseID is empty then return empty -- (remaster) no database: see preOpenStack

   ## Construct the SQL statement and query the database
   -- (remaster) with :1, as bookAdd does. The original's
   --    put "SELECT Title,Author,Status,Comments,BookID from books WHERE title LIKE '%" & pSearchTerm & "%' OR author LIKE '%" & pSearchTerm & "%'" into tSQLStatement
   -- broke on a word with an apostrophe in it
   put "%" & pSearchTerm & "%" into tPattern
   put "SELECT Title,Author,Status,Comments,BookID from books WHERE title LIKE :1 OR author LIKE :1" into tSQLStatement
   put revDataFromQuery(tab,return,sDatabaseID,tSQLStatement,"tPattern") into tList
   return tList
end booksSearch

on resizeStack
   -- (remaster) The window keeps one size, so this comes only if it is
   -- made resizable. The card "intro" is the front page now, which was
   -- laid out once, when the stack was made:
   --    send "layoutCard" to card "intro"
   send "layoutCard" to card "book data"
end resizeStack
@*/

/*@ Start/Go
on mouseUp
   go to card "Book Data"
end mouseUp
@*/

/*@ Book Data/card
-- The Library: the card "Book Data" of Book
-- Library. Its handlers run the window: the
-- list of books, the search, and the book's
-- details. The database handlers they call
-- are in the stack's script.
-- What the remaster added or changed is
-- marked (remaster). The buttons are the
-- window's, which are groups: "group Save"
-- where the sample said "button Save".

on preOpenCard
   layoutCard

   ## Clear the search and entry fields
   put empty into field "Search Term"
   clearFields
   -- (remaster) and nothing is being edited
   lockFields
   set the enabled of group "Cancel" to false
   set the enabled of group "Save" to false
   buttonsLook

   ## Populate the list of books
   listBooks
   pass preOpenCard -- (remaster) so that the window lays the card out
end preOpenCard

command clearFields
   ## Clear the entry fields
   put empty into field "Title"
   put empty into field "Author"
   put empty into field "Comments"
   put empty into field "BookID"

   ## Set the Option menu to the default
   set the label of button "Status" to "On Shelf"
   detailsLook -- (remaster) and a blank cover
end clearFields

command editFields
   ## Make the entry fields editable
   set the lockText of field "Title" to false
   set the lockText of field "Author" to false
   set the lockText of field "Comments" to false
   set the enabled of button "Status" to true

   set the showBorder of field "Title" to true
   set the showBorder of field "Author" to true
   show group "StatusBox" -- (remaster) the Status menu's box, as the fields have their borders
   detailsLook -- (remaster)
end editFields

command lockFields
   ## Make the fields read only
   set the lockText of field "Title" to true
   set the lockText of field "Author" to true
   set the lockText of field "Comments" to true
   set the enabled of button "Status" to false

   set the showBorder of field "Title" to false
   set the showBorder of field "Author" to false
   hide group "StatusBox" -- (remaster)
   detailsLook -- (remaster)
end lockFields

command listBooks
   local tList
   put booksListAll() into tList
   put tList into field "List"
   listLook -- (remaster) the list's colours, and words when it is empty
end listBooks

command searchBooks
   local tSearchTerm, tList

   put field "Search Term" into tSearchTerm
   put booksSearch(tSearchTerm) into tList
   put tList into field "List"
   listLook -- (remaster)
end searchBooks

command showBookDetails
   local tLineNumber, tBookDetails

   ## Get the hilited line number of the list
   ## Get the text of that line
   put the hilitedLine of field "List" into tLineNumber
   if tLineNumber is empty then exit showBookDetails -- (remaster) no book chosen
   put line tLineNumber of field "List" into tBookDetails

   ## Set the item delimiter to tab
   ## This allows us to refer to each tab separated item
   set the itemDelimiter to tab
   put item 1 of tBookDetails into field "Title"
   put item 2 of tBookDetails into field "Author"
   set the label of button "Status" to item 3 of tBookDetails
   put item 4 of tBookDetails into field "Comments"

   ## The BookID is an invisible field, used to identify the book
   put item 5 of tBookDetails into field "BookID"

   ## Make the fields non editbale
   lockFields

   ## Disable the Cancel and Save buttons
   set the disabled of group "Cancel" to true
   set the disabled of group "Save" to true
   buttonsLook -- (remaster)
end showBookDetails

command saveBook
   local tTitle, tAuthor, tStatus, tComments, tBookID
   local tPath

   ## Retrieve the user input
   put field "Title" into tTitle
   put field "Author" into tAuthor
   put the label of button "Status" into tStatus
   put field "Comments" into tComments
   put field "BookID" into tBookID

   -- (remaster) A book needs a title: without one, Save says so
   if tTitle is empty then
      answer "Please give the book a title first."
      exit saveBook
   end if

   ## Check for return chracters in comments
   ## Not allowed as our data is line separated
   ## Replace with a space instead
   replace return with space in tComments
   -- (remaster) the same for the title and the author; and no tabs, which
   -- separate the list's columns
   replace return with space in tTitle
   replace return with space in tAuthor
   replace tab with space in tTitle
   replace tab with space in tAuthor
   replace tab with space in tComments

   if tBookID is empty then
      ## This is a new book
      ## Add the book to the database
      bookAdd tTitle, tAuthor, tStatus, tComments
   else
      ## This is an update
      ## Only the status can be updated
      bookUpdate tBookID, tTitle, tAuthor, tStatus, tComments
   end if

   ## Update the list of books
   ## Clear the entry fields
   lock screen
   listBooks
   clearFields
   -- (remaster) and back to reading, as when a book is chosen; the
   -- typing stops, so the arrow keys go from page to page again
   lockFields
   set the enabled of group "Cancel" to false
   set the enabled of group "Save" to false
   buttonsLook
   focus on nothing
   unlock screen
end saveBook

## Prepare the details pane for a new book entry
command newBook
   lock screen
   clearFields
   set the hilitedLines of field "List" to empty -- (remaster) no book chosen in the list

   ## Make the fields editbale
   editFields

   ## Enable the Cancel and Save buttons
   set the enabled of group "Cancel" to true
   set the enabled of group "Save" to true
   buttonsLook -- (remaster)

   focus on field "title"
   unlock screen
end newBook

## Prepare the details pane to edit a book entry
command editBook
   -- (remaster) With no book chosen, there is nothing to edit
   if the hilitedLine of field "List" is empty then
      answer "Please choose a book in the list first."
      exit editBook
   end if
   lock screen
   showBookDetails

   ## Make the fields editbale
   editFields

   ## Enable the Cancel and Save buttons
   set the enabled of group "Cancel" to true
   set the enabled of group "Save" to true
   buttonsLook -- (remaster)

   focus on field "title"
   unlock screen
end editBook

command deleteBook
   local tLineNumber, tBookID

   ## Get the hilited line number of the list
   ## Get the title of that book
   set the itemDel to tab
   put the hilitedLine of field "List" into tLineNumber
   -- (remaster) With no book chosen, there is nothing to delete
   if tLineNumber is empty then
      answer "Please choose a book in the list first."
      exit deleteBook
   end if
   put item 5 of line tLineNumber of field "List" into tBookID

   ## Check the user wants to delete the book
   answer "Are you sure you want to delete this book?" with "OK" or "Cancel"
   if it is "OK" then

      ## Delete the selected book
      bookDelete tBookID

      ## Refresh the list
      clearFields
      listBooks
   end if
end deleteBook

command layoutCard
   ## This handler lays out all controls based on the size of the stack
   -- (remaster) on the stage: the window less the sidebar at its left,
   -- the header at its top, and a margin. The list takes the left half,
   -- and the book's details the right
   local tLeftPaneWidth, tLeft, tTop, tRight, tBottom, tDiv, tX
   put 256 into tLeft
   put 104 into tTop
   put the width of this stack - 24 into tRight
   put the height of this stack - 24 into tBottom
   put round((tRight - tLeft) / 2) - 8 into tLeftPaneWidth
   put tLeft + tLeftPaneWidth into tDiv

   set the rect of graphic "verticalDiv" of me to tDiv, tTop + 1, tDiv + 1, tBottom - 1

   ## The search, the list and its buttons, on the left
   set the rect of graphic "SearchBox" of me to tLeft + 16, tTop + 16, tDiv - 16, tTop + 52
   set the topLeft of image "SearchIcon" of me to tLeft + 30, tTop + 26
   set the topRight of group "Search" of me to tDiv - 20, tTop + 20
   set the rect of field "Search Term" of me to tLeft + 50, tTop + 19, the left of group "Search" of me - 6, tTop + 49
   set the topLeft of field "SearchHint" of me to tLeft + 54, tTop + 24
   set the rect of field "List Titles" of me to tLeft + 16, tTop + 60, tDiv - 16, tTop + 84
   set the rect of field "List" of me to tLeft + 16, tTop + 84, tDiv - 16, tBottom - 64
   set the loc of field "ListEmpty" of me to the loc of field "List" of me
   set the topLeft of group "Add Book" of me to tLeft + 16, tBottom - 52
   set the topLeft of group "Edit Book" of me to the right of group "Add Book" of me + 8, tBottom - 52
   set the topRight of group "Delete Book" of me to tDiv - 16, tBottom - 52

   ## The book's details, on the right: its cover, and beside it what it is
   set the topLeft of group "Cover" of me to tDiv + 4, tTop + 8
   put the right of graphic "CoverArt" of me + 12 into tX
   set the topLeft of field "Title Label" of me to tX + 8, tTop + 16
   set the rect of field "Title" of me to tX, tTop + 36, tRight - 16, tTop + 68
   set the topLeft of field "Author Label" of me to tX + 8, tTop + 74
   set the rect of field "Author" of me to tX, tTop + 94, tRight - 16, tTop + 124
   set the topLeft of field "Status Label" of me to tX + 8, tTop + 130
   set the topLeft of group "StatusBox" of me to tX, tTop + 150
   set the rect of button "Status" of me to the rect of group "StatusBox" of me
   set the topLeft of field "Comments Label" of me to tDiv + 18, tTop + 186
   set the rect of graphic "CommentsBox" of me to tDiv + 16, tTop + 208, tRight - 16, tBottom - 68
   set the rect of field "Comments" of me to tDiv + 18, tTop + 210, tRight - 18, tBottom - 70
   set the topRight of group "Save" of me to tRight - 16, tBottom - 52
   set the topRight of group "Cancel" of me to the left of group "Save" of me - 8, tBottom - 52
end layoutCard

-- (remaster) The list's look: each book's status in its colour, a scroll
-- bar only when the books do not fit, and words in the list when it is
-- empty, which say why
command listLook
   local tCount, tIndex, tText
   put the number of lines of field "List" into tCount
   set the itemDelimiter to tab
   repeat with tIndex = 1 to tCount
      set the textColor of line tIndex of field "List" to "15,23,42"
      set the textColor of item 2 of line tIndex of field "List" to "71,85,105"
      if item 3 of line tIndex of field "List" is "On Loan" then
         set the textColor of item 3 of line tIndex of field "List" to "180,83,9"
      else
         set the textColor of item 3 of line tIndex of field "List" to "4,120,87"
      end if
   end repeat
   set the itemDelimiter to comma
   set the vScrollbar of field "List" to the formattedHeight of field "List" > the height of field "List"
   set the visible of field "SearchHint" to field "Search Term" is empty
   if tCount > 0 then
      hide field "ListEmpty"
      exit listLook
   end if
   if databaseProblem() is not empty then
      put "The library could not open." & return & databaseProblem() into tText
   else if field "Search Term" is not empty then
      put "No book has" && quote & field "Search Term" & quote & return & "in its title or its author." into tText
   else
      put "There are no books yet." & return & "Add one with Add book." into tText
   end if
   set the text of field "ListEmpty" to tText
   show field "ListEmpty"
end listLook

-- (remaster) The book's cover: its title and author on a colour of its
-- own, the same each time for the same title, or blank with no book; and
-- the comments' scroll bar, only when they do not fit
command detailsLook
   local tTitle, tSum, tCodepoint, tColor, tRect, tPalette
   put field "Title" into tTitle
   put the rect of graphic "CoverArt" into tRect
   if tTitle is empty then
      put "241,245,249" into tColor
      set the fillGradient["ramp"] of graphic "CoverArt" to "0.000," & tColor & return & "1.000," & tColor
      hide graphic "CoverSpine"
      hide graphic "CoverLine"
      show image "CoverIcon"
      set the textColor of field "CoverTitle" to "148,163,184"
      set the textSize of field "CoverTitle" to 11
      if the lockText of field "Title" then
         put "No book chosen" into field "CoverTitle"
      else
         put "A new book" into field "CoverTitle"
      end if
      set the top of field "CoverTitle" to item 2 of tRect + 72
      put empty into field "CoverAuthor"
   else
      put 0 into tSum
      repeat for each codepoint tCodepoint in tTitle
         add codepointToNum(tCodepoint) to tSum
      end repeat
      -- (ten colours, a word each: the title's letters choose one)
      put "79,70,229 124,58,237 13,148,136 2,132,199 217,119,6" && \
            "225,29,72 5,150,105 234,88,12 219,39,119 71,85,105" into tPalette
      put word (tSum mod 10) + 1 of tPalette into tColor
      set the fillGradient["ramp"] of graphic "CoverArt" to "0.000," & colorMix(tColor, "255,255,255", 0.15) & return & \
            "1.000," & colorMix(tColor, "15,23,42", 0.35)
      show graphic "CoverSpine"
      show graphic "CoverLine"
      hide image "CoverIcon"
      set the textColor of field "CoverTitle" to "255,255,255"
      set the textSize of field "CoverTitle" to 13
      put tTitle into field "CoverTitle"
      set the top of field "CoverTitle" to item 2 of tRect + 14
      put field "Author" into field "CoverAuthor"
   end if
   -- (the colour runs from the top left to the bottom right)
   set the fillGradient["type"] of graphic "CoverArt" to "linear"
   set the fillGradient["from"] of graphic "CoverArt" to item 1 of tRect & comma & item 2 of tRect
   set the fillGradient["to"] of graphic "CoverArt" to item 3 of tRect & comma & item 4 of tRect
   set the fillGradient["via"] of graphic "CoverArt" to item 1 of tRect - (item 4 of tRect - item 2 of tRect) & comma & \
         item 2 of tRect + (item 3 of tRect - item 1 of tRect)
   set the vScrollbar of field "Comments" to the formattedHeight of field "Comments" > the height of field "Comments"
end detailsLook

-- (remaster) A colour between two: pAmount of the way from pFrom to pTo
function colorMix pFrom, pTo, pAmount
   local tOut, tIndex
   repeat with tIndex = 1 to 3
      put round(item tIndex of pFrom + (item tIndex of pTo - item tIndex of pFrom) * pAmount) & comma after tOut
   end repeat
   delete the last char of tOut
   return tOut
end colorMix

-- (remaster) Save and Cancel are the window's buttons, groups, which look
-- the same enabled or not: a disabled one fades
command buttonsLook
   local tName
   repeat for each item tName in "Cancel,Save"
      if the enabled of group tName then
         set the blendLevel of group tName to 0
      else
         set the blendLevel of group tName to 60
      end if
   end repeat
end buttonsLook
@*/

/*@ Book Data/Search Term
on returnInField
   ## This message is sent when the retun key is pressed
   ## By handling it here we "trap" it meaning there cannot be multiple lines in the field
   ## Call searchBooks so the list is filtered when return is pressed
   searchBooks
end returnInField

on enterInField
   ## As with return but for enter
   searchBooks
end enterInField

-- (remaster) and as you type
on textChanged
   searchBooks
end textChanged

-- (remaster) The window goes from page to
-- page with the left and right arrow keys,
-- but not in a field being typed in. While
-- the search is empty, they go from page to
-- page here too
on arrowKey pKey
   if me is empty and (pKey is "left" or pKey is "right") then
      focus on nothing
   end if
   pass arrowKey
end arrowKey
@*/

/*@ Book Data/Search
on mouseUp
   searchBooks
end mouseUp
@*/

/*@ Book Data/List
on selectionChanged
   showBookDetails
end selectionChanged
@*/

/*@ Book Data/Add Book
on mouseUp
   newBook
end mouseUp
@*/

/*@ Book Data/Edit Book
on mouseUp
   editBook
end mouseUp
@*/

/*@ Book Data/Delete Book
on mouseUp
   deleteBook
end mouseUp
@*/

/*@ Book Data/Save
on mouseUp
   saveBook
end mouseUp
@*/

/*@ Book Data/Cancel
on mouseUp
   lock screen
   clearFields
   lockFields
   -- (remaster) and Save and Cancel are off, and
   -- no book is chosen in the list, as when the
   -- card opens; the typing stops
   set the enabled of group "Cancel" to false
   set the enabled of group "Save" to false
   buttonsLook
   set the hilitedLines of field "List" to empty
   focus on nothing
   unlock screen
end mouseUp
@*/

/*@ Book Data/Status
-- (remaster) The sample's Status was an
-- option menu, which shows the status
-- chosen by itself. This one is a pulldown
-- menu, drawn as the window draws its other
-- controls, and it shows the status chosen
-- here. Its menu is its text: On Shelf, and
-- On Loan.
on menuPick pItem
   set the label of me to pItem
end menuPick
@*/

/*@ Book Data/Title and Author
-- (remaster) The cover shows what you type,
-- as you type it
on textChanged
   detailsLook
end textChanged
@*/

/*@ Page/code font
-- The code on this page is in a code font:
-- Source Code Pro, which the IDE carries for
-- its Script Editor, or else the first
-- monospaced font the computer has, as in
-- the panel of scripts. The fields of code
-- have a custom property, cCode, that says so
on preOpenCard
   local tError, tFont, tIndex
   if the environment is "development" and \
         "Source Code Pro" is not among the lines of the fontNames then
      try
         start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
      catch tError
      end try
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then
         repeat with tIndex = 1 to the number of controls of me
            if the cCode of control tIndex of me is true then
               set the textFont of control tIndex of me to tFont
            end if
         end repeat
         exit repeat
      end if
   end repeat
   pass preOpenCard
end preOpenCard
@*/
