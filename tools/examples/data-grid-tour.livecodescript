script "OXTExampleDataGridTour"
-- OXT-Beyond: builds "A Data Grid Tour", the remaster of LiveCode Ltd's
-- Data Grid Tour v1.0 (edited and debranded for open source at LiveCode
-- Ltd's request), which is in ide/Resources/Examples/Data Grid
-- Tour.oxtstack and stays there as it was made.
--
-- Their tour is ten cards: the data grid beside a field and a table field,
-- where to find it, a table built in five steps and a form in two (each
-- step a button that runs the card script's handlers), how a grid is made
-- (the grid, its row template and its behavior script), a template that
-- fills a grid a row at a time, the behavior's two handlers, the
-- Inspector's panes, and where to read more. The remaster keeps their
-- words, their programs and their data, in the window every remastered
-- example has (builder.livecodescript). What changed:
--
--    - the pictures of the IDE of 2009 (the Tools palette, the Inspector,
--      a stack with its templates substack, the Script Editor) are drawn
--      in the window's look, and where a picture showed a grid, the card
--      has a live one: How It Works fills one from the template, and
--      Properties has a grid to try the Inspector's properties on, in
--      lines to click (the fields "Try Contents" and "Try Columns");
--    - the tour's title bar, page slider and Back and Next buttons (its
--      group "Chrome") are the window's sidebar and header;
--    - View Demonstration Script opens the scripts drawer on the card
--      script, where it opened the Script Editor;
--    - the step buttons are buttons still, with their numbers drawn in the
--      window's colors, and the row colors the steps set are the window's;
--    - the card scripts declare their variables and quote a message's name
--      (strict compilation), and pass preOpenCard (the window lays each
--      card out when it gets that message); Properties shows a group for
--      each pane where it showed a picture; a few words are mended
--      (mendTexts, each with its reason);
--    - added: a Replay button on The Template, the wheel for the fields
--      that hold more than they show (with a slim thumb, as the scripts
--      panel has), and code shown in the scripts panel's font (the stack
--      script's preOpenCard).
--
-- Their words, the grids' data, the flags and the template's sample text
-- are read from their stack when this one is built. The grids are made as
-- the IDE makes them (a copy of the data grid library's, with a row
-- template on a substack), and so they need the data grid library loaded:
-- in the IDE it is, and here this builder loads it from the checkout's
-- Toolset (or OXT_INSTALL's), as the IDE does.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kStageLeft = 256
constant kStageTop = 104
constant kStageRight = 1000
constant kStageBottom = 616
-- A wide card's two sides: the steps at the left, a rule at kSplit, and
-- the grid at the right, where the scripts drawer opens over it
constant kPlayLeft = 272
constant kPlayRight = 600
constant kSplit = 616
constant kSideLeft = 640
constant kSideRight = 976
-- A form's row, as tall as the template made for it
constant kRowHeight = 44
-- The data grids' templates substack (the IDE names one so, and finds it
-- by that name when a grid is added to the stack)
constant kTemplates = "Data Grid Templates 2026101801"

-- The row template of the grid made last (from gridNew), and the form
-- template of The Template's grid, which How It Works shows too
local sRowTemplate, sFormTemplate
-- Their stack, read when the build starts: their words by key (sOrig, a
-- heading's line begins with "@@"), the Top 100 Cities grid's data and
-- column properties, and the flags of the Table card's grid, by name
local sOrig, sCities, sCityProps, sFlags
-- The images of the steps' numbers, by number
local sDigits

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   -- (six icons Learn's kit does not have, from Lucide)
   exAddIcon "rows-3", "<rect width='18' height='18' x='3' y='3' rx='2'/><path d='M21 9H3'/><path d='M21 15H3'/>"
   exAddIcon "layout-template", "<rect width='18' height='7' x='3' y='3' rx='1'/><rect width='9' height='7' x='3' y='14' rx='1'/><rect width='5' height='7' x='16' y='14' rx='1'/>"
   exAddIcon "sliders-horizontal", "<line x1='21' x2='14' y1='4' y2='4'/><line x1='10' x2='3' y1='4' y2='4'/><line x1='21' x2='12' y1='12' y2='12'/><line x1='8' x2='3' y1='12' y2='12'/><line x1='21' x2='16' y1='20' y2='20'/><line x1='12' x2='3' y1='20' y2='20'/><line x1='14' x2='14' y1='2' y2='6'/><line x1='8' x2='8' y1='10' y2='14'/><line x1='16' x2='16' y1='18' y2='22'/>"
   exAddIcon "arrow-down", "<path d='M12 5v14'/><path d='m19 12-7 7-7-7'/>"
   exAddIcon "chevron-down", "<path d='m6 9 6 6 6-6'/>"
   exAddIcon "columns-3", "<rect width='18' height='18' x='3' y='3' rx='2'/><path d='M9 3v18'/><path d='M15 3v18'/>"
   gridLibrary
   readOriginal
   mendTexts
   put "A Data Grid Tour" into tInfo["name"]
   put "after LiveCode Ltd" into tInfo["credit"]
   put "table" into tInfo["icon"]
   put lkColor("indigo") into tInfo["accent"]
   put lkColor("sky") into tInfo["accent2"]
   put "Stop" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Welcome|A Data Grid Tour|LiveCode Ltd's tour of the data grid: tables, forms, and how they work.|table|front" & return & \
         "Overview|Overview|Fields, table fields and data grids, side by side, and what each is good for.|layers|page" & return & \
         "Introduction|How To Use It|Where the data grid is, and how to set one up.|compass|page" & return & \
         "Table|A Table|Build a data grid table in five steps, each a few lines of script.|table|wide" & return & \
         "Form|A Form|A form lays out each row as you design it, and is filled from an array.|rows-3|wide" & return & \
         "How It Works|How It Works|A data grid, the template its rows are made from, and the script that fills them.|blocks|page" & return & \
         "The Template|The Template|One group, copied for each row of data: watch the rows arrive.|layout-template|wide" & return & \
         "Behaviors|Behaviors|Two handlers fill each row with its data, and lay it out.|braces|page" & return & \
         "Properties|Properties|Over 60 properties: the Inspector sets them, and so can your scripts.|sliders-horizontal|wide" & return & \
         "Summary|Summary|Where to read more about data grids, and the words this tour used.|book-open-text|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   gridTemplates the short name of tStack
   buildWelcome
   buildOverview
   buildIntroduction
   buildTable
   buildForm
   buildTemplate
   buildHowItWorks
   buildBehaviors
   buildProperties
   buildSummary
   go card 1
   unlock messages
   put exCheck(tStack) & exCheck(kTemplates) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/A Data Grid Tour.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

################################################################################
#
# Their stack, read
#

-- Their stack, read and then unloaded (its file stays as it is): the words
-- of each card, the Overview's fields and grid, the cards' data, the
-- template's sample text, and the flags on the templates substack
private command readOriginal
   local tRepo, tOriginal, tLocked, tLine, tText, tKey, tGrid, tCache, tSub, tCardId, tIndex, tName
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put tRepo & "/ide/Resources/Examples/Data Grid Tour.oxtstack" into tOriginal
   if there is no file tOriginal then
      throw "cannot find LiveCode Ltd's Data Grid Tour at " & tOriginal
   end if
   put the lockMessages into tLocked
   lock messages
   get the name of stack tOriginal
   -- Their words, by the ids of the fields they are in (a heading's field
   -- holds older words below its first line, hidden: its first line only)
   set the itemDelimiter to "|"
   repeat for each line tLine in originalFields()
      put the text of field id (item 3 of tLine) of card (item 2 of tLine) of stack tOriginal into tText
      if item 4 of tLine is "head" then
         put line 1 of tText into tText
      end if
      put word 1 to -1 of tText into sOrig[item 1 of tLine]
      if sOrig[item 1 of tLine] is empty then
         throw "their " & item 2 of tLine & " card no longer has words in field id " & item 3 of tLine
      end if
   end repeat
   set the itemDelimiter to comma
   -- The words with headings in bold
   put headedText(tOriginal, "Welcome", "Notes") into sOrig["welcome"]
   put headedText(tOriginal, "Properties", "Prop1") into sOrig["prop1"]
   -- The Overview's fields, its table field and its grid
   repeat for each item tKey in "Rank,GDP,City,Country,Notes"
      put the text of field tKey of group tKey of group "Fields" of card "Overview" of stack tOriginal into sOrig["field" & tKey]
      put the text of field (tKey && "Label") of group tKey of group "Fields" of card "Overview" of stack tOriginal into sOrig["label" & tKey]
   end repeat
   put word 1 to -1 of the text of field "Table Field" of card "Overview" of stack tOriginal into sOrig["tableField"]
   put the long id of group "Top 100 Cities" of card "Overview" of stack tOriginal into tGrid
   put the dgProps["columns"] of tGrid into sOrig["citiesColumns"]
   put the dgProps["sort by column"] of tGrid into sOrig["citiesSort"]
   put the dgProps["column properties"] of tGrid into sCityProps
   put the customProperties["dgCache"] of tGrid into tCache
   put tCache["data"] into sCities
   if sCities is not an array or sOrig["citiesColumns"] is empty then
      throw "cannot read the Overview's grid"
   end if
   -- The data the cards' scripts load
   put the cData of card "Table" of stack tOriginal into sOrig["tableData"]
   put the cHeaders of card "Table" of stack tOriginal into sOrig["tableHeaders"]
   put the cData of card "Form" of stack tOriginal into sOrig["formData"]
   put the cHeaders of card "Form" of stack tOriginal into sOrig["formHeaders"]
   put the cData of card "The Template" of stack tOriginal into sOrig["templateData"]
   put the cHeader of card "The Template" of stack tOriginal into sOrig["templateHeader"]
   repeat for each item tKey in "tableData,formData,formHeaders,templateData,templateHeader"
      if sOrig[tKey] is empty then
         throw "their stack no longer has the data " & tKey
      end if
   end repeat
   -- The sample text of their template's picture
   repeat for each item tKey in "Employee ID,Name,Email,phone"
      put word 1 to -1 of the text of field tKey of group "Row Template" of card "The Template" of stack tOriginal into sOrig["mock" & tKey]
   end repeat
   -- The flags, on the card of the Table card's row template
   put line 1 of the substacks of stack tOriginal into tSub
   put word 7 of the dgProps["row template"] of group "SampleTable" of card "Table" of stack tOriginal into tCardId
   repeat with tIndex = 1 to the number of images of card id tCardId of stack tSub
      put the short name of image tIndex of card id tCardId of stack tSub into tName
      put the text of image tIndex of card id tCardId of stack tSub into sFlags[tName]
   end repeat
   if the number of lines of the keys of sFlags < 40 then
      throw "cannot read the flags of the Table card's grid"
   end if
   delete stack tOriginal
   set the lockMessages to tLocked
end readOriginal

-- Their fields, a line each: the key their words go under here, the card,
-- the field's id, and "head" for a heading's field
private function originalFields
   return "intro|Introduction|12317" & return & \
         "fieldsHead|Overview|1465|head" & return & \
         "tablesHead|Overview|1466|head" & return & \
         "gridsHead|Overview|1467|head" & return & \
         "fieldsText|Overview|1015" & return & \
         "tablesText|Overview|1017" & return & \
         "gridsText|Overview|1018" & return & \
         "tableTitle0|Table|43557" & return & \
         "tableText0|Table|43558" & return & \
         "tableTitle1|Table|18851" & return & \
         "tableText1|Table|18852" & return & \
         "tableTitle2|Table|25974" & return & \
         "tableText2|Table|25975" & return & \
         "tableTitle3|Table|28826" & return & \
         "tableText3|Table|28825" & return & \
         "tableTitle4|Table|34284" & return & \
         "tableText4|Table|34285" & return & \
         "tableTitle5|Table|151475" & return & \
         "tableText5|Table|151476" & return & \
         "viewScript|Table|68695" & return & \
         "formHead|Form|15371" & return & \
         "formText|Form|15372" & return & \
         "formTitle0|Form|168162" & return & \
         "formText0|Form|168163" & return & \
         "formTitle1|Form|168164" & return & \
         "formText1|Form|168165" & return & \
         "formTitle2|Form|168166" & return & \
         "formText2|Form|168167" & return & \
         "worksHead1|How It Works|17396" & return & \
         "worksText1|How It Works|17395" & return & \
         "worksHead2|How It Works|17398" & return & \
         "worksText2|How It Works|17397" & return & \
         "worksHead3|How It Works|17399" & return & \
         "worksText3|How It Works|17400" & return & \
         "templateHead|The Template|17759" & return & \
         "templateText|The Template|17760" & return & \
         "behaviorsHead|Behaviors|17765" & return & \
         "behaviorsText|Behaviors|17766" & return & \
         "handler1Head|Behaviors|17767" & return & \
         "handler1Text|Behaviors|17768" & return & \
         "handler2Head|Behaviors|17769" & return & \
         "handler2Text|Behaviors|17770" & return & \
         "resources|Summary|192144" & return & \
         "guideHead|Summary|142350" & return & \
         "guideText|Summary|142349" & return & \
         "userHead|Summary|142351" & return & \
         "userText|Summary|142352"
end originalFields

-- A field of their stack whose bold lines are headings: its text, with
-- "@@" before each heading
private function headedText pStack, pCard, pField
   local tText, tIndex, tOut
   put the text of field pField of card pCard of stack pStack into tText
   repeat with tIndex = 1 to the number of lines of tText
      if the textStyle of line tIndex of field pField of card pCard of stack pStack is "bold" then
         put "@@" after tOut
      end if
      put line tIndex of tText & return after tOut
   end repeat
   repeat while the number of lines of tOut > 0 and word 1 to -1 of line -1 of tOut is empty
      delete line -1 of tOut
   end repeat
   if "@@" is not in tOut then
      throw "their field " & pField & " has no headings"
   end if
   return tOut
end headedText

-- Their words, but for a few that this window mends, each with its reason
private command mendTexts
   -- (a slip of the keys)
   fixText "welcome", "direcly", "directly"
   -- (an apostrophe that belongs before the s, and a slip of the keys)
   fixText "fieldsText", "a fields" & numToCodepoint(8217) & "s appearance", "a field" & numToCodepoint(8217) & "s appearance"
   fixText "fieldsText", "line spaceing", "line spacing"
   -- (a slip of the keys)
   fixText "formText", "more freedon", "more freedom"
   -- (the pane is drawn here, not a screenshot of it)
   fixText "prop1", "This screenshot shows a 'form' style selection. When", "With the form style chosen, it offers both. When"
end mendTexts

-- Replaces pFrom with pTo in their words under pKey: if they no longer
-- have pFrom, the build stops, so that the change is looked at again
private command fixText pKey, pFrom, pTo
   local tText
   put sOrig[pKey] into tText
   if pFrom is not in tText then
      throw "their words (" & pKey & ") no longer have " & quote & pFrom & quote
   end if
   replace pFrom with pTo in tText
   put tText into sOrig[pKey]
end fixText

-- Headed words as sections: the title and the words under it, by number
private function sectionsOf pText
   local tLine, tCount, tOut
   put 0 into tCount
   repeat for each line tLine in pText
      if char 1 to 2 of tLine is "@@" then
         add 1 to tCount
         put char 3 to -1 of tLine into tOut[tCount]["title"]
      else if tCount > 0 and word 1 to -1 of tLine is not empty then
         if tOut[tCount]["text"] is not empty then
            put return after tOut[tCount]["text"]
         end if
         put tLine after tOut[tCount]["text"]
      end if
   end repeat
   return tOut
end sectionsOf

################################################################################
#
# The cards
#

-- The front page: what the tour is, a tile for each stop, and their three
-- notes on what a data grid is
private command buildWelcome
   local tObj, tWidth, tIndex, tX, tTop, tIcons, tSections
   go card "Welcome"
   exHero lkR(kStageLeft, kStageTop, kStageRight, 248), lkColor("sky") & "|" & lkColor("indigo"), \
         "LIVECODE LTD  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "A tour of the data grid", \
         "Tables that sort, resize and edit, and forms whose rows you design. Nine stops show what " & \
         "a data grid is, how it works, and how to script one."
   exProgramTiles 260, 3, 56, 8
   put sectionsOf(sOrig["welcome"]) into tSections
   put (kStageRight - kStageLeft - 2 * 12) div 3 into tWidth
   put 456 into tTop
   put "sparkles,sliders-horizontal,puzzle" into tIcons
   repeat with tIndex = 1 to 3
      put kStageLeft + (tIndex - 1) * (tWidth + 12) into tX
      put exPanel("Note" & tIndex, lkR(tX, tTop, tX + tWidth, kStageBottom), empty) into tObj
      put lkBox("Note" & tIndex & "IconBg", lkR(tX + 16, tTop + 16, tX + 48, tTop + 48), \
            lkMix("255,255,255", lkColor("indigo"), 0.12), 10, empty) into tObj
      get exIcon("Note" & tIndex & "Icon", item tIndex of tIcons, lkColor("indigo"), lkR(tX + 24, tTop + 24, tX + 40, tTop + 40), empty)
      put lkLabel("Note" & tIndex & "Title", lkR(tX + 60, tTop + 22, tX + tWidth - 12, tTop + 42), \
            tSections[tIndex]["title"], 15, lkColor("ink"), empty) into tObj
      set the textStyle of tObj to "bold"
      put lkLabel("Note" & tIndex & "Text", lkR(tX + 16, tTop + 60, tX + tWidth - 14, kStageBottom - 6), \
            tSections[tIndex]["text"], 12, lkColor("soft"), empty) into tObj
      set the fixedLineHeight of tObj to true
      set the textHeight of tObj to 17
   end repeat
end buildWelcome

-- The Overview: a field, a table field and a data grid, each on a panel
-- with their words on what it is good for
private command buildOverview
   local tObj, tX, tW, tIndex, tLefts, tWidths, tIcons, tKeys
   go card "Overview"
   put "256,504,764" into tLefts
   put "236,248,236" into tWidths
   put "text-cursor-input,sheet,table" into tIcons
   put "fields,tables,grids" into tKeys
   repeat with tIndex = 1 to 3
      put item tIndex of tLefts into tX
      put item tIndex of tWidths into tW
      put exPanel("Kind" & tIndex, lkR(tX, kStageTop, tX + tW, kStageBottom), empty) into tObj
      put lkBox("Kind" & tIndex & "Demo", lkR(tX + 12, kStageTop + 12, tX + tW - 12, 336), lkColor("bg"), 12, empty) into tObj
      put lkBox("Kind" & tIndex & "IconBg", lkR(tX + 16, 352, tX + 46, 382), lkMix("255,255,255", lkColor("indigo"), 0.12), 9, empty) into tObj
      get exIcon("Kind" & tIndex & "Icon", item tIndex of tIcons, lkColor("indigo"), lkR(tX + 23, 359, tX + 39, 375), empty)
      put lkLabel("Kind" & tIndex & "Head", lkR(tX + 56, 354, tX + tW - 12, 380), sOrig[item tIndex of tKeys & "Head"], 18, lkColor("ink"), empty) into tObj
      set the textStyle of tObj to "bold"
      put lkLabel("Kind" & tIndex & "Text", lkR(tX + 16, 394, tX + tW - 14, kStageBottom - 8), \
            sOrig[item tIndex of tKeys & "Text"], 12, lkColor("soft"), empty) into tObj
      set the fixedLineHeight of tObj to true
      set the textHeight of tObj to 17
   end repeat
   overviewFields 272
   overviewTable 520
   overviewGrid 780
end buildOverview

-- Their fields: a label and a field for each of a city's facts, the notes
-- a field that scrolls (pLeft, the demo's inside left)
private command overviewFields pLeft
   local tObj
   overviewField "Rank", pLeft, pLeft + 46, pLeft + 50, pLeft + 78, 128
   overviewField "GDP", pLeft + 80, pLeft + 160, pLeft + 164, pLeft + 204, 128
   overviewField "City", pLeft, pLeft + 46, pLeft + 50, pLeft + 204, 160
   overviewField "Country", pLeft, pLeft + 46, pLeft + 50, pLeft + 204, 192
   overviewField "Notes", pLeft, pLeft + 46, pLeft + 50, pLeft + 204, 224
   -- (the notes: as tall as the rest of the demo, wrapped, and scrolled
   -- with the wheel)
   put lkBox("NotesBox", lkR(pLeft + 50, 224, pLeft + 204, 324), "255,255,255", 6, empty) into tObj
   lkBorder tObj, lkColor("line")
   -- (six whole lines, from below the box's edge to above it)
   set the rect of field "Notes" to pLeft + 52, 225, pLeft + 202, 323
   set the dontWrap of field "Notes" to false
   set the fixedLineHeight of field "Notes" to true
   set the textHeight of field "Notes" to 15
   set the textSize of field "Notes" to 11
   set the margins of field "Notes" to "4,4,10,4"
   set the layer of field "Notes" to top
   wheelThumb the long id of field "Notes", "NotesThumb", empty
end overviewFields

-- A fact of a city: its label, right aligned up to pLabelRight, and its
-- field on a white box from pBoxLeft to pBoxRight
private command overviewField pKey, pLabelLeft, pLabelRight, pBoxLeft, pBoxRight, pTop
   local tObj
   put lkLabel(pKey & " Label", lkR(pLabelLeft - 30, pTop + 5, pLabelRight, pTop + 21), sOrig["label" & pKey], 11, lkColor("soft"), empty, "right") into tObj
   put lkBox(pKey & "Box", lkR(pBoxLeft, pTop, pBoxRight, pTop + 26), "255,255,255", 6, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkInput(pKey, lkR(pBoxLeft + 6, pTop + 5, pBoxRight - 4, pTop + 23), sOrig["field" & pKey], 12, empty) into tObj
end overviewField

-- Their table field: a field with tab stops, and lines across and down,
-- that scrolls with the wheel
private command overviewTable pLeft
   local tObj
   put lkBox("TableFieldBox", lkR(pLeft, 128, pLeft + 212, 324), "255,255,255", 6, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel("Table Field", lkR(pLeft + 1, 133, pLeft + 211, 323), empty, 11, lkColor("ink"), empty) into tObj
   -- (ten rows of 19, and its margins)
   set the rect of tObj to pLeft + 1, 129, pLeft + 211, 323
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the hGrid of tObj to true
   set the vGrid of tObj to true
   set the borderColor of tObj to lkColor("line")
   set the tabStops of tObj to "24,110,166"
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 19
   set the margins of tObj to "4,2,4,2"
   set the text of tObj to sOrig["tableField"]
   wheelThumb tObj, "TableFieldThumb", empty
end overviewTable

-- Their data grid of the 100 cities, made as the IDE makes one
private command overviewGrid pLeft
   local tGrid
   put gridNew("Top 100 Cities", lkR(pLeft, 128, pLeft + 204, 324)) into tGrid
   gridReady tGrid, "table"
   gridLook tGrid, lkColor("indigo")
   gridProp tGrid, "text size", 11
   gridProp tGrid, "header text size", 11
   gridProp tGrid, "header height", 26
   gridProp tGrid, "row height", 22
   gridProp tGrid, "header margins", "6,8,6,0"
   gridCities tGrid, "28,82,56,36"
end overviewGrid

-- How To Use It: their words on where the data grid is, and three steps
-- drawn as the IDE has them, the Tools palette, a card, the Inspector
private command buildIntroduction
   local tObj, tIndex, tX, tTitles, tCaptions, tTexts
   go card "Introduction"
   put lkLabel("Lead", lkR(kStageLeft, 112, kStageRight, 154), sOrig["intro"], 15, lkColor("soft"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 21
   put "Find it|Drag it in|Set it up" into tTitles
   put "The data grid is in the Tools palette, with the other controls.|" & \
         "Drag one onto a card: it is a group, named " & quote & "DataGrid 1" & quote & ".|" & \
         "Double-click it: the Inspector sets its style, its columns and its data." into tCaptions
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 3
      put kStageLeft + (tIndex - 1) * 252 into tX
      put exPanel("Way" & tIndex, lkR(tX, 166, tX + 240, 452), empty) into tObj
      badge "Way" & tIndex & "Badge", tX + 30, 196, tIndex, 26
      put lkLabel("Way" & tIndex & "Title", lkR(tX + 52, 187, tX + 228, 207), item tIndex of tTitles, 15, lkColor("ink"), empty) into tObj
      set the textStyle of tObj to "bold"
      put lkBox("Way" & tIndex & "Picture", lkR(tX + 16, 222, tX + 224, 392), lkColor("bg"), 12, empty) into tObj
      put lkLabel("Way" & tIndex & "Caption", lkR(tX + 16, 404, tX + 224, 446), item tIndex of tCaptions, 12, lkColor("soft"), empty) into tObj
      set the fixedLineHeight of tObj to true
      set the textHeight of tObj to 17
   end repeat
   set the itemDelimiter to comma
   drawPalette kStageLeft + 16
   drawCard kStageLeft + 252 + 16
   drawInspector kStageLeft + 504 + 16
   -- (from one step to the next)
   repeat with tIndex = 1 to 2
      put kStageLeft + tIndex * 252 - 6 into tX
      put lkOval("WayArrow" & tIndex & "Bg", lkR(tX - 15, 292, tX + 15, 322), "255,255,255", empty) into tObj
      lkBorder tObj, lkColor("line")
      lkShadow tObj, 8, 2, 12
      get exIcon("WayArrow" & tIndex, "arrow-right", lkColor("indigo"), lkR(tX - 8, 299, tX + 8, 315), empty)
   end repeat
   -- Good to know
   put exPanel("Know", lkR(kStageLeft, 466, kStageRight, kStageBottom), empty) into tObj
   put lkBox("KnowIconBg", lkR(kStageLeft + 16, 482, kStageLeft + 48, 514), lkMix("255,255,255", lkColor("amber"), 0.14), 10, empty) into tObj
   get exIcon("KnowIcon", "lightbulb", lkColor("amber"), lkR(kStageLeft + 24, 490, kStageLeft + 40, 506), empty)
   put lkLabel("KnowTitle", lkR(kStageLeft + 60, 488, kStageRight - 16, 508), "Good to know", 15, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   put "A data grid is a group: a script names it group " & quote & "DataGrid 1" & quote & ".|" & \
         "Its rows are copies of a template, a group on a substack the IDE adds to your stack. How It Works shows it.|" & \
         "Its style is table or form. The next two stops build one of each, a step at a time." into tTexts
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 3
      put kStageLeft + 16 + (tIndex - 1) * 244 into tX
      get lkOval("KnowDot" & tIndex, lkR(tX, 533, tX + 6, 539), lkColor("indigo"), empty)
      put lkLabel("KnowText" & tIndex, lkR(tX + 14, 528, tX + 226, kStageBottom - 8), item tIndex of tTexts, 12, lkColor("soft"), empty) into tObj
      set the fixedLineHeight of tObj to true
      set the textHeight of tObj to 17
   end repeat
   set the itemDelimiter to comma
end buildIntroduction

-- The Tools palette, dark, with its controls in tiles: the data grid's lit,
-- and its name beside it (pLeft, the picture's left)
private command drawPalette pLeft
   local tObj, tX, tY, tIndex, tIcons, tPal
   put pLeft + 52 into tPal
   put lkBox("PaletteBg", lkR(tPal, 234, tPal + 104, 380), lkColor("side2"), 12, empty) into tObj
   lkShadow tObj, 14, 4, 22
   put lkLabel("PaletteTitle", lkR(tPal, 243, tPal + 104, 257), "Tools", 10, lkColor("sideInk"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   put "mouse-pointer-click,pencil,type,text-cursor-input,sheet,table,image,play,list-tree,layout-grid,globe,square-terminal" into tIcons
   repeat with tIndex = 1 to 12
      put tPal + 13 + ((tIndex - 1) mod 3) * 28 into tX
      put 264 + ((tIndex - 1) div 3) * 28 into tY
      if tIndex is 6 then
         put lkBox("PaletteTile" & tIndex, lkR(tX, tY, tX + 22, tY + 22), lkColor("indigo"), 6, empty) into tObj
         lkGlow tObj, lkColor("indigo"), 12, 160
         get exIcon("PaletteIcon" & tIndex, item tIndex of tIcons, "255,255,255", lkR(tX + 4, tY + 4, tX + 18, tY + 18), empty)
      else
         put lkBox("PaletteTile" & tIndex, lkR(tX, tY, tX + 22, tY + 22), lkColor("sideLine"), 6, empty) into tObj
         get exIcon("PaletteIcon" & tIndex, item tIndex of tIcons, lkColor("sideInk"), lkR(tX + 5, tY + 5, tX + 17, tY + 17), empty)
      end if
   end repeat
   -- (the lit tile's name, as a tip beside it)
   put lkBox("PaletteTip", lkR(tPal + 86, 318, tPal + 150, 338), "255,255,255", 6, empty) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 8, 2, 16
   put lkLabel("PaletteTipText", lkR(tPal + 86, 322, tPal + 150, 336), "Data Grid", 11, lkColor("ink"), empty, "center") into tObj
end drawPalette

-- A card with a new data grid on it, empty and selected (pLeft, the
-- picture's left)
private command drawCard pLeft
   local tObj, tTop, tIndex, tLeft, tRight, tGridTop, tGridBottom, tColor, tX, tY
   put miniWindow("CardWin", lkR(pLeft + 14, 234, pLeft + 194, 380), "Untitled 1", 22, 7, 10) into tTop
   put pLeft + 34 into tLeft
   put pLeft + 174 into tRight
   put tTop + 18 into tGridTop
   put tGridTop + 86 into tGridBottom
   put lkBox("CardGridHead", lkR(tLeft, tGridTop, tRight, tGridTop + 16), "241,245,249", 0, empty) into tObj
   repeat with tIndex = 1 to 5
      if tIndex mod 2 is 0 then
         put lkMix("255,255,255", lkColor("indigo"), 0.07) into tColor
      else
         put "255,255,255" into tColor
      end if
      get lkBox("CardGridRow" & tIndex, lkR(tLeft, tGridTop + 16 + (tIndex - 1) * 14, tRight, tGridTop + 30 + (tIndex - 1) * 14), tColor, 0, empty)
   end repeat
   repeat with tIndex = 1 to 2
      get lkBox("CardGridColumn" & tIndex, lkR(tLeft + tIndex * 47, tGridTop, tLeft + tIndex * 47 + 1, tGridBottom), lkColor("line"), 0, empty)
   end repeat
   put lkBox("CardGridFrame", lkR(tLeft, tGridTop, tRight, tGridBottom), empty, 0, empty) into tObj
   lkBorder tObj, lkMix(lkColor("line"), lkColor("muted"), 0.4)
   -- (selected: a handle at each corner and in the middle of each side)
   repeat with tIndex = 1 to 8
      put item tIndex of (tLeft & "," & (tLeft + tRight) div 2 & "," & tRight & "," & tRight & "," & tRight & "," & \
            (tLeft + tRight) div 2 & "," & tLeft & "," & tLeft) into tX
      put item tIndex of (tGridTop & "," & tGridTop & "," & tGridTop & "," & (tGridTop + tGridBottom) div 2 & "," & \
            tGridBottom & "," & tGridBottom & "," & tGridBottom & "," & (tGridTop + tGridBottom) div 2) into tY
      put lkBox("CardHandle" & tIndex, lkR(tX - 3, tY - 3, tX + 4, tY + 4), lkColor("indigo"), 1, empty) into tObj
   end repeat
end drawCard

-- The Inspector of a data grid, at its Basic Properties pane (pLeft, the
-- picture's left)
private command drawInspector pLeft
   local tObj, tTop, tY, tIndex, tChecks, tLeft, tRight
   put miniWindow("InspWin", lkR(pLeft + 22, 230, pLeft + 186, 386), "Inspector", 22, 7, 10) into tTop
   put pLeft + 34 into tLeft
   put pLeft + 174 into tRight
   -- (the pane's menu)
   put tTop + 7 into tY
   put lkBox("InspMenu", lkR(tLeft, tY, tRight, tY + 20), lkMix("255,255,255", lkColor("indigo"), 0.1), 6, empty) into tObj
   put lkLabel("InspMenuText", lkR(tLeft + 8, tY + 5, tRight - 20, tY + 18), "Basic Properties", 10, lkMix(lkColor("indigo"), lkColor("ink"), 0.3), empty) into tObj
   set the textStyle of tObj to "bold"
   get exIcon("InspMenuIcon", "chevron-down", lkColor("indigo"), lkR(tRight - 16, tY + 4, tRight - 4, tY + 16), empty)
   -- (its name and its style)
   add 26 to tY
   inspectorRow "Name", "DataGrid 1", tLeft, tRight, tY
   add 22 to tY
   inspectorRow "Style", "Table", tLeft, tRight, tY
   get exIcon("InspStyleIcon", "chevron-down", lkColor("soft"), lkR(tRight - 14, tY + 4, tRight - 4, tY + 14), empty)
   -- (and its switches)
   put "Border,Alternate Row Colors,Allow Text Editing" into tChecks
   add 24 to tY
   repeat with tIndex = 1 to 3
      put lkBox("InspCheck" & tIndex, lkR(tLeft, tY + 2, tLeft + 10, tY + 12), lkColor("indigo"), 3, empty) into tObj
      put lkLabel("InspCheckText" & tIndex, lkR(tLeft + 16, tY + 1, tRight, tY + 13), item tIndex of tChecks, 10, lkColor("ink"), empty) into tObj
      add 16 to tY
   end repeat
end drawInspector

private command inspectorRow pLabel, pValue, pLeft, pRight, pTop
   local tObj
   put lkLabel("Insp" & pLabel, lkR(pLeft, pTop + 4, pLeft + 36, pTop + 16), pLabel, 10, lkColor("soft"), empty) into tObj
   put lkBox("Insp" & pLabel & "Box", lkR(pLeft + 40, pTop, pRight, pTop + 18), "255,255,255", 4, empty) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel("Insp" & pLabel & "Value", lkR(pLeft + 46, pTop + 4, pRight - 4, pTop + 17), pValue, 10, lkColor("ink"), empty) into tObj
end inspectorRow

-- The Table: their six steps at the left, each a button that runs the
-- card script's handlers, and their grid at the right
private command buildTable
   local tObj, tTop, tIndex, tGrid, tLeft
   go card "Table"
   set the cData of this card to sOrig["tableData"]
   set the cHeaders of this card to sOrig["tableHeaders"]
   set the script of this card to exScript("Table")
   digitImages
   splitRule
   put kStageTop + 18 into tTop
   repeat with tIndex = 0 to 5
      put stepRow("Table", tIndex, tTop, sOrig["tableTitle" & tIndex], sOrig["tableText" & tIndex]) + 12 into tTop
   end repeat
   -- (as wide as the columns their script sets, in the middle of the
   -- right side)
   put (kSplit + kStageRight) div 2 - 141 into tLeft
   caption "GridCaption", "group " & quote & "SampleTable" & quote, tLeft, kStageTop + 18
   put gridNew("SampleTable", lkR(tLeft, kStageTop + 38, tLeft + 282, 548)) into tGrid
   gridReady tGrid, "table"
   gridLook tGrid, lkColor("indigo")
   -- (the colors their reset puts back)
   gridProp tGrid, "alternate row color", "248,250,252"
   gridProp tGrid, "header text style", "normal"
   countryColumn
   viewButton tLeft + 282, 564
end buildTable

-- The Form: their words and three steps at the left, and their grid at
-- the right, with its row template
private command buildForm
   local tObj, tTop, tIndex, tGrid
   go card "Form"
   set the cData of this card to sOrig["formData"]
   set the cHeaders of this card to sOrig["formHeaders"]
   set the script of this card to exScript("Form")
   splitRule
   put heading("FormHead", sOrig["formHead"], kStageTop + 18) into tTop
   put lkLabel("FormText", lkR(kPlayLeft, tTop + 10, kPlayRight, tTop + 300), sOrig["formText"], 13, lkColor("soft"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 19
   fitLabel tObj, tTop + 10
   put the bottom of tObj + 22 into tTop
   repeat with tIndex = 0 to 2
      put stepRow("Form", tIndex, tTop, sOrig["formTitle" & tIndex], sOrig["formText" & tIndex]) + 12 into tTop
   end repeat
   caption "GridCaption", "group " & quote & "SampleForm" & quote, kSideLeft, kStageTop + 18
   put gridNew("SampleForm", lkR(kSideLeft, kStageTop + 38, kSideRight, 548)) into tGrid
   formTemplate kSideRight - kSideLeft, exScript("Form Row Behavior")
   gridReady tGrid, "form"
   gridLook tGrid, lkColor("indigo")
   gridProp tGrid, "row height", kRowHeight
   gridProp tGrid, "alternate row color", "248,250,252"
   viewButton kSideRight, 564
end buildForm

-- The Template: their words and the template itself at the left, the grid
-- it fills a row at a time at the right
private command buildTemplate
   local tObj, tTop, tGrid, tTemplate
   go card "The Template"
   set the cHeader of this card to sOrig["templateHeader"]
   set the cData of this card to sOrig["templateData"]
   set the script of this card to exScript("The Template")
   splitRule
   -- (the grid first: the template on the left is a copy of its own)
   caption "GridCaption", "group " & quote & "SlowLoadingGrid" & quote, kSideLeft, kStageTop + 18
   put gridNew("SlowLoadingGrid", lkR(kSideLeft, kStageTop + 38, kSideRight, 548)) into tGrid
   formTemplate kSideRight - kSideLeft, exScript("Template Row Behavior")
   put sRowTemplate into sFormTemplate
   gridReady tGrid, "form"
   gridLook tGrid, lkColor("indigo")
   gridProp tGrid, "row height", kRowHeight
   -- Their words
   put heading("TemplateHead", sOrig["templateHead"], kStageTop + 18) into tTop
   put lkLabel("TemplateText", lkR(kPlayLeft, tTop + 10, kPlayRight, tTop + 300), sOrig["templateText"], 13, lkColor("soft"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 19
   fitLabel tObj, tTop + 10
   -- The template: a copy of the group the grid copies for each row
   put the bottom of tObj + 24 into tTop
   caption "TemplateCaption", "group " & quote & "Row Template" & quote, kPlayLeft, tTop
   put templateCopy("Row Template", kPlayLeft + 6, tTop + 30, kPlayRight - kPlayLeft - 12) into tTemplate
   put lkBox("TemplateFrame", lkR(kPlayLeft, tTop + 24, kPlayRight, tTop + 30 + kRowHeight + 6), empty, 10, empty) into tObj
   lkBorder tObj, lkMix("255,255,255", lkColor("indigo"), 0.45)
   set the lineSize of tObj to 2
   set the dashes of tObj to "6,5"
   get exIcon("TemplateArrow", "arrow-right", lkColor("indigo"), lkR(kSplit - 9, tTop + 30 + kRowHeight div 2 - 8, kSplit + 7, tTop + 30 + kRowHeight div 2 + 8), empty)
   -- (what it holds)
   put tTop + 30 + kRowHeight + 18 into tTop
   put lkLabel("TemplateHolds", lkR(kPlayLeft, tTop, kPlayRight, tTop + 16), "One group: a graphic and four fields.", 12, lkColor("soft"), empty) into tObj
   chipRow "TemplatePart", "graphic " & quote & "Background" & quote & "|field " & quote & "Employee ID" & quote & "|field " & quote & "Name" & quote & \
         "|field " & quote & "Email" & quote & "|field " & quote & "phone" & quote, kPlayLeft, tTop + 24, kPlayRight
   -- Under the grid: Replay, and the script
   get exButton("Replay", kSideLeft, 564, 34, "Replay", "rotate-cw", "primary", lkColor("indigo"), empty, empty, 0)
   set the script of group "Replay" to exScript("Replay")
   viewButton kSideRight, 564
end buildTemplate

-- How It Works: their picture of a stack with a data grid, and the
-- substack with its template and behavior, drawn with a live grid; their
-- words at the right
private command buildHowItWorks
   local tObj, tTop, tGrid, tBottom, tCode
   go card "How It Works"
   -- Your stack
   put miniWindow("StackWin", lkR(kStageLeft, kStageTop, 612, 338), "My Stack", 30, 9, 12) into tTop
   badge "StackBadge", 590, kStageTop + 15, 1, 22
   put gridMake("Employees", lkR(kStageLeft + 14, tTop + 13, 598, tTop + 13 + 4 * kRowHeight)) into tGrid
   put sFormTemplate into sRowTemplate
   gridReady tGrid, "form"
   gridLook tGrid, lkColor("indigo")
   gridProp tGrid, "row height", kRowHeight
   gridFillRows tGrid, 4
   -- (its substack)
   get exIcon("SubArrow", "arrow-down", lkColor("indigo"), lkR(kStageLeft + 20, 350, kStageLeft + 36, 366), empty)
   put lkLabel("SubWord", lkR(kStageLeft + 46, 351, 612, 367), "A substack holds the template and its script.", 12, lkColor("soft"), empty) into tObj
   put miniWindow("SubWin", lkR(kStageLeft, 380, 612, kStageBottom), "Data Grid Templates", 30, 9, 12) into tTop
   caption "SubTemplateCaption", "group " & quote & "Row Template" & quote, kStageLeft + 16, tTop + 10
   badge "TemplateBadge", 590, tTop + 17, 2, 22
   get templateCopy("WorksTemplate", kStageLeft + 16, tTop + 32, 612 - 16 - kStageLeft - 16)
   put tTop + 32 + kRowHeight + 12 into tTop
   caption "SubBehaviorCaption", "button " & quote & "Behavior Script" & quote, kStageLeft + 16, tTop
   badge "BehaviorBadge", 590, tTop + 7, 3, 22
   put lkBox("SubCode", lkR(kStageLeft + 16, tTop + 22, 596, kStageBottom - 12), lkColor("code"), 10, empty) into tObj
   put lkCodeField("SubCodeText", lkR(kStageLeft + 26, tTop + 30, 588, kStageBottom - 16), 11, 17, empty) into tObj
   codeFont tObj
   -- (the first line of each of its handlers)
   put "on FillInData pDataArray" & return & "on LayoutControl" & return & "setprop dgHilite pBoolean" & return & \
         "getprop dgDataControl" into tCode
   set the htmlText of tObj to lkCodeHtml(tCode)
   -- Their words
   put exPanel("WorksPanel", lkR(628, kStageTop, kStageRight, kStageBottom), empty) into tObj
   put textSection("Works1", 1, sOrig["worksHead1"], sOrig["worksText1"], 646, kStageTop + 20, 982, 13) into tBottom
   put textSection("Works2", 2, sOrig["worksHead2"], sOrig["worksText2"], 646, tBottom + 22, 982, 13) into tBottom
   put textSection("Works3", 3, sOrig["worksHead3"], sOrig["worksText3"], 646, tBottom + 22, 982, 13) into tBottom
   if tBottom > kStageBottom - 12 then
      throw "How It Works: their words run below the panel, to " & tBottom
   end if
end buildHowItWorks

-- Behaviors: their words at the left, and the behavior script of The
-- Template's rows at the right, its two handlers marked
private command buildBehaviors
   local tObj, tTop, tBottom, tHtml, tLine, tSpaces, tWidth, tBand, tCount
   go card "Behaviors"
   put exPanel("BehaviorsPanel", lkR(kStageLeft, kStageTop, 568, kStageBottom), empty) into tObj
   put heading("BehaviorsHead", sOrig["behaviorsHead"], kStageTop + 18) into tTop
   set the left of field "BehaviorsHead" to kStageLeft + 18
   put lkLabel("BehaviorsText", lkR(kStageLeft + 18, tTop + 10, 552, tTop + 300), sOrig["behaviorsText"], 12, lkColor("soft"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 18
   fitLabel tObj, tTop + 10
   put textSection("Handler1", 1, sOrig["handler1Head"], sOrig["handler1Text"], kStageLeft + 18, the bottom of tObj + 22, 552) into tBottom
   put textSection("Handler2", 2, sOrig["handler2Head"], sOrig["handler2Text"], kStageLeft + 18, tBottom + 18, 552) into tBottom
   -- The script, as the scripts panel shows one
   put lkBox("CodePanel", lkR(584, kStageTop, kStageRight, kStageBottom), lkColor("code"), 16, empty) into tObj
   lkShadow tObj, 18, 6, 30
   get lkOval("CodeDot1", lkR(602, 121, 612, 131), "248,113,113", empty)
   get lkOval("CodeDot2", lkR(618, 121, 628, 131), "251,191,36", empty)
   get lkOval("CodeDot3", lkR(634, 121, 644, 131), "52,211,153", empty)
   caption "CodeCaption", "the script of button " & quote & "Behavior Script" & quote, 656, 119
   set the textColor of field "CodeCaption" to "100,116,139"
   put lkCodeField("BehaviorCode", lkR(596, 148, 984, kStageBottom - 14), 12, 18, empty) into tObj
   codeFont tObj
   set the margins of tObj to "8,4,14,4"
   -- (a letter of the code font, Source Code Pro or Droid Sans Mono, is 0.6
   -- of its size wide, whatever font this build has to measure with)
   put 12 * 0.6 into tWidth
   put lkHex(lkMix(lkColor("code"), lkColor("indigo"), 0.45)) into tBand
   put 0 into tCount
   repeat for each line tLine in exScript("Template Row Behavior")
      put 0 into tSpaces
      repeat while char tSpaces + 1 of tLine is space
         add 1 to tSpaces
      end repeat
      put "<p leftindent=" & quote & round((tSpaces + 3) * tWidth) & quote & " firstindent=" & quote & -round(3 * tWidth) & quote after tHtml
      if word 1 of tLine is "on" and word 2 of tLine is among the items of "FillInData,LayoutControl" then
         put " bgcolor=" & quote & tBand & quote after tHtml
         add 1 to tCount
      end if
      put ">" & codeLineHtml(char tSpaces + 1 to -1 of tLine) & "</p>" after tHtml
   end repeat
   if tCount is not 2 then
      throw "the template's behavior no longer has FillInData and LayoutControl"
   end if
   set the htmlText of tObj to tHtml
   wheelThumb tObj, "BehaviorCodeThumb", empty
   set the backgroundColor of graphic "BehaviorCodeThumb" to "100,116,139"
end buildBehaviors

-- Properties: a grid to try properties on at the left, with the message
-- box and the three panes' buttons; the panes at the right, their words
-- on the Inspector's first, and lines to try in the other two
private command buildProperties
   local tObj, tGrid, tTop, tIndex, tTitles, tTexts
   go card "Properties"
   set the script of this card to exScript("Properties")
   splitRule
   caption "GridCaption", "group " & quote & "Cities" & quote, kPlayLeft, kStageTop + 18
   put gridNew("Cities", lkR(kPlayLeft, kStageTop + 38, kPlayRight, 378)) into tGrid
   gridReady tGrid, "table"
   gridLook tGrid, lkColor("indigo")
   gridProp tGrid, "row height", 26
   gridCities tGrid, "44,124,102,56"
   get messageBox(kPlayLeft, 390, kPlayRight, 1, "Pick pane 2 or 3, then click a line.", "28,138,232")
   put lkLabel("PanesWord", lkR(kPlayLeft, 442, kPlayRight, 456), "THE INSPECTOR'S PANES", 11, lkColor("muted"), empty) into tObj
   set the textStyle of tObj to "bold"
   put "Basic Properties|Contents|Columns" into tTitles
   put "Its name, its border, its style, its template.|Its data: as text, or as an array.|" & \
         "Each column's label, width, alignment and sort." into tTexts
   set the itemDelimiter to "|"
   put 464 into tTop
   repeat with tIndex = 1 to 3
      put stepRow("Properties", tIndex, tTop, item tIndex of tTitles, item tIndex of tTexts) + 12 into tTop
   end repeat
   set the itemDelimiter to comma
   -- Basic Properties: their words on what the Inspector sets, under a
   -- title as the other panes have
   get lkGroup("prop1", lkR(632, kStageTop + 8, 992, kStageBottom - 8), empty)
   get lkBox("prop1Anchor", lkR(632, kStageTop + 8, 633, kStageTop + 9), empty, 0, "prop1")
   put lkBox("prop1IconBg", lkR(640, kStageTop + 16, 672, kStageTop + 48), lkMix("255,255,255", lkColor("indigo"), 0.12), 10, "prop1") into tObj
   get exIcon("prop1Icon", "sliders-horizontal", lkColor("indigo"), lkR(648, kStageTop + 24, 664, kStageTop + 40), "prop1")
   put lkLabel("prop1Title", lkR(684, kStageTop + 21, 984, kStageTop + 43), "The Inspector", 17, lkColor("ink"), "prop1") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Prop1", lkR(640, kStageTop + 60, 984, kStageBottom - 12), empty, 13, lkColor("soft"), "prop1") into tObj
   set the margins of tObj to "0,4,14,4"
   set the htmlText of tObj to headedHtml(sOrig["prop1"])
   wheelThumb tObj, "Prop1Thumb", "prop1"
   -- Contents, and Columns: what each pane holds, and lines to try
   paneGroup "prop2", "file-text", "Contents", \
         "The Contents pane holds the grid's data: a line for each row, with a tab between its columns. " & \
         "Your scripts get and set the same data, as text or as an array.", "Try Contents", "Properties/try2"
   paneGroup "prop3", "columns-3", "Columns", \
         "The Columns pane sets each column's label, its width, its alignment, how it sorts and whether it shows. " & \
         "Each of these is a property your scripts can set as well.", "Try Columns", "Properties/try3"
end buildProperties

-- A pane of the Inspector, as a group pName at the right of the stage: its
-- icon and title, its words, and lines to try, the field pTry
private command paneGroup pName, pIcon, pTitle, pText, pTry, pKey
   local tObj, tTop
   get lkGroup(pName, lkR(632, kStageTop + 8, 992, kStageBottom - 8), empty)
   get lkBox(pName & "Anchor", lkR(632, kStageTop + 8, 633, kStageTop + 9), empty, 0, pName)
   put lkBox(pName & "IconBg", lkR(640, kStageTop + 16, 672, kStageTop + 48), lkMix("255,255,255", lkColor("indigo"), 0.12), 10, pName) into tObj
   get exIcon(pName & "Icon", pIcon, lkColor("indigo"), lkR(648, kStageTop + 24, 664, kStageTop + 40), pName)
   put lkLabel(pName & "Title", lkR(684, kStageTop + 21, 984, kStageTop + 43), pTitle, 17, lkColor("ink"), pName) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel(pName & "Text", lkR(640, kStageTop + 62, 984, kStageTop + 300), pText, 13, lkColor("soft"), pName) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 19
   fitLabel tObj, kStageTop + 62
   put the bottom of tObj + 20 into tTop
   put lkLabel(pName & "TryTitle", lkR(640, tTop, 984, tTop + 18), "Try It", 14, lkMix(lkColor("indigo"), lkColor("ink"), 0.25), pName) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel(pName & "TryHint", lkR(694, tTop + 1, 984, tTop + 17), "click a line: it runs as in the message box", 12, lkColor("muted"), pName) into tObj
   set the dontWrap of tObj to true
   get tryField(pTry, pKey, 634, tTop + 26, 984, pName)
end paneGroup

-- The Summary: their two guides, a tile each that opens it, and the words
-- the tour used
private command buildSummary
   local tObj, tIndex, tX, tY, tWords, tTexts
   go card "Summary"
   put lkLabel("ResourcesHead", lkR(kStageLeft, 114, kStageRight, 140), sOrig["resources"], 20, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   resourceTile "Data Grid Guide", kStageLeft, 152, 622, 300, sOrig["guideHead"], sOrig["guideText"], "book-open-text"
   resourceTile "User Guide", 634, 152, kStageRight, 300, sOrig["userHead"], sOrig["userText"], "file-text"
   put exPanel("Words", lkR(kStageLeft, 316, kStageRight, kStageBottom), empty) into tObj
   put lkBox("WordsIconBg", lkR(kStageLeft + 16, 332, kStageLeft + 48, 364), lkMix("255,255,255", lkColor("indigo"), 0.12), 10, empty) into tObj
   get exIcon("WordsIcon", "code", lkColor("indigo"), lkR(kStageLeft + 24, 340, kStageLeft + 40, 356), empty)
   put lkLabel("WordsTitle", lkR(kStageLeft + 60, 338, kStageRight - 16, 358), "The words this tour used", 15, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   put "the dgText|the dgData|dgProps[" & quote & "columns" & quote & "]|dgColumnWidth[" & quote & "City" & quote & "]|" & \
         "dgProps[" & quote & "sort by column" & quote & "]|dgProps[" & quote & "row template" & quote & "]|" & \
         "on FillInData pDataArray|on LayoutControl" into tWords
   put "A grid's data as text, tab delimited.|" & \
         "The same data as an array, a key per column.|" & \
         "The names of a table's columns, a line each.|" & \
         "A column's width, one of its properties.|" & \
         "The column whose order the rows take.|" & \
         "The group that each row is a copy of.|" & \
         "Sent to a row with its data, to put into its controls.|" & \
         "Sent to a row when its controls are to be placed." into tTexts
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 8
      put kStageLeft + 16 + ((tIndex - 1) div 4) * 364 into tX
      put 378 + ((tIndex - 1) mod 4) * 58 into tY
      get codeChip("Word" & tIndex, item tIndex of tWords, tX, tY, empty)
      put lkLabel("WordText" & tIndex, lkR(tX + 2, tY + 30, tX + 348, tY + 48), item tIndex of tTexts, 12, lkColor("soft"), empty) into tObj
   end repeat
   set the itemDelimiter to comma
end buildSummary

-- A guide: a tile that lights up, with its icon, its title and their words
-- on it; its script opens the guide
private command resourceTile pName, pLeft, pTop, pRight, pBottom, pTitle, pText, pIcon
   local tObj
   get lkGroup(pName, lkR(pLeft, pTop, pRight, pBottom), empty)
   put lkBox(pName & "_bg", lkR(pLeft, pTop, pRight, pBottom), "255,255,255", 16, pName) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 16, 3, 10
   put lkBox(pName & "_iconBg", lkR(pLeft + 20, pTop + 20, pLeft + 64, pTop + 64), lkMix("255,255,255", lkColor("indigo"), 0.12), 12, pName) into tObj
   get exIcon(pName & "_icon", pIcon, lkColor("indigo"), lkR(pLeft + 30, pTop + 30, pLeft + 54, pTop + 54), pName)
   get exIcon(pName & "_open", "external-link", lkColor("muted"), lkR(pRight - 36, pTop + 20, pRight - 20, pTop + 36), pName)
   put lkLabel(pName & "_title", lkR(pLeft + 80, pTop + 26, pRight - 44, pTop + 48), pTitle, 16, lkColor("ink"), pName) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel(pName & "_text", lkR(pLeft + 80, pTop + 56, pRight - 24, pBottom - 12), pText, 13, lkColor("soft"), pName) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 19
   set the cRest of group pName to "255,255,255"
   set the cLit of group pName to lkMix("255,255,255", lkColor("indigo"), 0.06)
   set the script of group pName to exScript("Summary/" & pName)
end resourceTile

################################################################################
#
# What the cards are made of
#

-- A heading at the left of a wide card (or of a panel); returns its bottom
private function heading pName, pText, pTop
   local tObj
   put lkLabel(pName, lkR(kPlayLeft, pTop, kPlayRight, pTop + 26), pText, 20, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   return pTop + 26
end heading

-- A label as tall as its text, its text from pTop down
private command fitLabel pObj, pTop
   set the rect of pObj to the left of pObj, pTop - 4, the right of pObj, pTop - 2 + the formattedHeight of pObj
end fitLabel

-- A numbered section of words: its number on a circle, its title, and
-- its words under them (pSize, or 12), from pLeft to pRight; returns its
-- bottom
private function textSection pName, pNumber, pTitle, pText, pLeft, pTop, pRight, pSize
   local tObj
   if pSize is empty then
      put 12 into pSize
   end if
   badge pName & "Badge", pLeft + 11, pTop + 11, pNumber, 22
   put lkLabel(pName & "Title", lkR(pLeft + 32, pTop + 1, pRight, pTop + 22), pTitle, 16, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel(pName & "Text", lkR(pLeft, pTop + 32, pRight, pTop + 400), pText, pSize, lkColor("soft"), empty) into tObj
   set the fixedLineHeight of tObj to true
   -- (lines of 18 for 12, 20 for 13)
   set the textHeight of tObj to 2 * pSize - 6
   fitLabel tObj, pTop + 32
   return the bottom of tObj
end textSection

-- A number on a circle of the accent, its middle at pX,pY
private command badge pName, pX, pY, pNumber, pSize
   local tObj, tLeft, tTop
   put pX - pSize div 2 into tLeft
   get lkOval(pName, lkR(tLeft, pY - pSize div 2, tLeft + pSize, pY - pSize div 2 + pSize), lkColor("indigo"), empty)
   put lkLabel(pName & "Number", lkR(tLeft, pY - 8, tLeft + pSize, pY + 8), pNumber, 12, "255,255,255", empty, "center") into tObj
   set the textStyle of tObj to "bold"
   -- (in the middle, up and down, as a button's label is)
   put pY - (the formattedHeight of tObj + 4) div 2 into tTop
   set the rect of tObj to tLeft, tTop, tLeft + pSize, tTop + the formattedHeight of tObj + 8
end badge

-- A small window, as the pictures of the IDE draw one: white and rounded,
-- with three dots and its title on its bar. Returns its body's top
private function miniWindow pName, pRect, pTitle, pBar, pDot, pSize
   local tObj, tLeft, tTop, tRight, tMid, tIndex, tColors
   -- (the dots' colors, red, amber and green, a line each)
   put "248,113,113" & return & "251,191,36" & return & "52,211,153" into tColors
   put item 1 of pRect into tLeft
   put item 2 of pRect into tTop
   put item 3 of pRect into tRight
   put lkBox(pName, pRect, "255,255,255", 10, empty) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 14, 3, 12
   put tTop + pBar div 2 into tMid
   repeat with tIndex = 1 to 3
      get lkOval(pName & "Dot" & tIndex, lkR(tLeft + pDot + (tIndex - 1) * (pDot + 5), tMid - pDot div 2, \
            tLeft + pDot + (tIndex - 1) * (pDot + 5) + pDot, tMid - pDot div 2 + pDot), \
            line tIndex of tColors, empty)
   end repeat
   put lkLabel(pName & "Title", lkR(tLeft + 4 * pDot + 10, tMid - 8, tRight - 4 * pDot - 10, tMid + 8), pTitle, pSize, lkColor("soft"), empty, "center") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   -- (in the middle of the bar, up and down)
   set the top of tObj to tMid - (the formattedHeight of tObj + 4) div 2
   get lkBox(pName & "Rule", lkR(tLeft + 1, tTop + pBar, tRight - 1, tTop + pBar + 1), lkColor("line"), 0, empty)
   return tTop + pBar + 1
end miniWindow

-- A copy of the form template (the grid's own, without its behavior) on
-- this card, pWidth wide, at pLeft,pTop: what the grid copies for a row.
-- Returns it
private function templateCopy pName, pLeft, pTop, pWidth
   local tObj, tStack, tSource, tIndex
   put the short name of this stack into tStack
   put the long id of group id (word 3 of sFormTemplate) of card id (word 7 of sFormTemplate) of stack kTemplates into tSource
   copy tSource to this card of stack tStack
   put it into tObj
   set the name of tObj to pName
   -- (a group's fields keep their words card by card: the copy is given
   -- those they have on the template's card)
   repeat with tIndex = 1 to the number of fields of tSource
      set the text of field tIndex of tObj to the text of field tIndex of tSource
   end repeat
   set the behavior of tObj to empty
   set the lockLoc of tObj to true
   set the rect of graphic "Background" of group pName to 0, 0, pWidth, kRowHeight
   set the rect of tObj to 0, 0, pWidth, kRowHeight
   -- (as the behavior's LayoutControl places them: the phone at the right)
   set the right of field "phone" of group pName to pWidth
   set the topLeft of tObj to pLeft, pTop
   set the backgroundColor of graphic "Background" of group pName to lkMix("255,255,255", lkColor("indigo"), 0.05)
   set the foregroundColor of tObj to lkColor("ink")
   return tObj
end templateCopy

-- Code chips in a row from pLeft, going on below when the row is full
private command chipRow pName, pWords, pLeft, pTop, pRight
   local tX, tY, tIndex, tWidth, tWord
   put pLeft into tX
   put pTop into tY
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to the number of items of pWords
      put item tIndex of pWords into tWord
      put codeChip(pName & tIndex, tWord, tX, tY, empty) into tWidth
      if tX + tWidth > pRight and tX > pLeft then
         -- (on the next line)
         delete graphic (pName & tIndex & "_bg")
         delete field (pName & tIndex)
         put pLeft into tX
         add 30 to tY
         put codeChip(pName & tIndex, tWord, tX, tY, empty) into tWidth
      end if
      add tWidth + 6 to tX
   end repeat
   set the itemDelimiter to comma
end chipRow

-- A word of code on a soft chip, its left edge at pLeft; returns its width
private function codeChip pName, pWord, pLeft, pTop, pGroup
   local tObj, tLabel, tWidth
   put lkBox(pName & "_bg", lkR(pLeft, pTop, pLeft + 200, pTop + 24), \
         lkMix("255,255,255", lkColor("indigo"), 0.1), 12, pGroup) into tObj
   put lkLabel(pName, lkR(pLeft + 10, pTop + 4, pLeft + 300, pTop + 22), pWord, 12, \
         lkMix(lkColor("indigo"), lkColor("ink"), 0.35), pGroup) into tLabel
   set the dontWrap of tLabel to true
   -- (as wide as its word in a monospaced font, as tryField measures)
   set the textFont of tLabel to measureFace()
   put the formattedWidth of tLabel + 20 into tWidth
   codeFont tLabel
   set the rect of tObj to pLeft, pTop, pLeft + tWidth, pTop + 24
   -- (the word in the middle of its chip, up and down)
   set the rect of tLabel to pLeft + 10, pTop + 12 - (the formattedHeight of tLabel + 4) div 2, pLeft + tWidth - 6, \
         pTop + 12 - (the formattedHeight of tLabel + 4) div 2 + the formattedHeight of tLabel + 4
   return tWidth
end codeChip

-- A small caption above a control: its name, as a script names it
private command caption pName, pText, pLeft, pTop
   local tObj
   put lkLabel(pName, lkR(pLeft, pTop, pLeft + 340, pTop + 16), pText, 11, lkColor("muted"), empty) into tObj
   codeFont tObj
   set the dontWrap of tObj to true
end caption

-- The rule between a wide card's two sides
private command splitRule
   get lkBox("SplitRule", lkR(kSplit, kStageTop + 24, kSplit + 1, kStageBottom - 24), lkColor("line"), 0, empty)
end splitRule

-- Their View Demonstration Script, a button whose right edge is at pRight
private command viewButton pRight, pTop
   local tWidth
   put exButton("View Script", pRight, pTop, 34, sOrig["viewScript"], "code", "ghost", lkColor("indigo"), empty, empty, 0) into tWidth
   set the left of group "View Script" to pRight - tWidth
   set the script of group "View Script" to exScript("View Script")
end viewButton

-- A step of a demonstration: its button (the step's number, as their
-- buttons were), its title and its words. Returns the bottom of the row
private function stepRow pCard, pIndex, pTop, pTitle, pText
   local tButton, tObj
   create button ("step" & pIndex)
   put it into tButton
   set the style of tButton to "transparent"
   set the showName of tButton to false
   set the autoHilite of tButton to false
   set the traversalOn of tButton to false
   set the showFocusBorder of tButton to false
   set the icon of tButton to sDigits[pIndex]
   set the rect of tButton to kPlayLeft, pTop, kPlayLeft + 36, pTop + 36
   set the script of tButton to exScript(pCard & "/step" & pIndex)
   put lkLabel("Step" & pIndex & "Title", lkR(kPlayLeft + 50, pTop + 1, kPlayRight, pTop + 20), pTitle, 14, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Step" & pIndex & "Text", lkR(kPlayLeft + 50, pTop + 23, kPlayRight, pTop + 200), pText, 12, lkColor("soft"), empty) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 17
   fitLabel tObj, pTop + 23
   return max(pTop + 36, the bottom of tObj)
end stepRow

-- The steps' numbers: an image each, as their step buttons' icons were, a
-- circle of the accent with the number in white (drawn, then snapshot),
-- hidden on the Table card. Their ids go into sDigits
private command digitImages
   local tIndex, tObj, tData, tTop
   repeat with tIndex = 0 to 5
      get lkGroup("digitDraw", lkR(300, 300, 336, 336), empty)
      get lkOval("digitDraw_bg", lkR(300, 300, 336, 336), lkColor("indigo"), "digitDraw")
      put lkLabel("digitDraw_label", lkR(300, 310, 336, 326), tIndex, 16, "255,255,255", "digitDraw", "center") into tObj
      set the textStyle of tObj to "bold"
      put 318 - (the formattedHeight of tObj + 4) div 2 into tTop
      set the rect of tObj to 300, tTop, 336, tTop + the formattedHeight of tObj + 8
      export snapshot from group "digitDraw" to tData as PNG
      delete group "digitDraw"
      create image (tIndex & ".png")
      put it into tObj
      set the text of tObj to tData
      hide tObj
      put the id of tObj into sDigits[tIndex]
   end repeat
end digitImages

-- The message box, on the stage: the field "Message", which shows what a
-- line put into the message box, pLines lines of it, its columns at
-- pTabs. Returns its bottom
private function messageBox pLeft, pTop, pRight, pLines, pText, pTabs
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
   set the tabStops of tObj to pTabs
   return tBottom
end messageBox

-- Lines to run with a click, as the message box runs a line typed into it:
-- a field, its lines on light bands, as tall as they are. Returns its bottom
private function tryField pName, pKey, pLeft, pTop, pRight, pGroup
   local tObj, tHtml, tLine
   repeat for each line tLine in exScript(pKey)
      put "<p bgcolor=" & quote & "#f1f5f9" & quote & " spaceabove=" & quote & "4" & quote & \
            " firstindent=" & quote & "-14" & quote & " leftindent=" & quote & "20" & quote & ">" & \
            codeHtml(tLine) & "</p>" after tHtml
   end repeat
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + 300), empty, 12, lkColor("ink"), pGroup) into tObj
   set the margins of tObj to "6,0,6,4"
   set the htmlText of tObj to tHtml
   set the script of tObj to exScript("Try It")
   -- (as tall as its lines: measured in a monospaced font)
   set the textFont of tObj to measureFace()
   set the height of tObj to the formattedHeight of tObj + 4
   codeFont tObj
   set the top of tObj to pTop
   return the bottom of tObj
end tryField

-- A slim thumb at the right of a field that the wheel scrolls: the field's
-- cWheel is true and its cThumb names the thumb, whose cField names it.
-- The stack script moves the thumb, and a drag of it scrolls the field
private command wheelThumb pField, pName, pGroup
   local tObj
   put lkBox(pName, lkR(the right of pField - 7, the top of pField + 8, the right of pField - 3, the top of pField + 40), \
         "203,213,225", 2, pGroup) into tObj
   hide tObj
   set the cField of tObj to the short name of pField
   set the cWheel of pField to true
   set the cThumb of pField to pName
end wheelThumb

################################################################################
#
# Words and code, in the look of Learn's pages
#

-- Headed words as htmlText: each heading bold and dark, the words under it
private function headedHtml pText
   local tHtml, tLine
   repeat for each line tLine in pText
      if char 1 to 2 of tLine is "@@" then
         put "<p>" & htmlFont(lkEscape(char 3 to -1 of tLine), 15, lkColor("ink"), true) & "</p>" after tHtml
      else if word 1 to -1 of tLine is empty then
         put "<p></p>" after tHtml
      else
         put "<p>" & lkEscape(tLine) & "</p>" after tHtml
      end if
   end repeat
   return tHtml
end headedHtml

-- A line of a script in the scripts panel's colors: a comment that begins
-- with a hash is grey, as the panel shows it
private function codeLineHtml pLine
   if char 1 of pLine is "#" then
      return lkSpan(pLine, "#64748b")
   end if
   return lkCodeLineHtml(pLine)
end codeLineHtml

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
-- named here)
private function codeFace
   -- (see codeFont)
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
   put gridMake(pName, pRect) into tGrid
   put the defaultStack into tStack
   put the lockMessages into tLocked
   lock messages
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

-- A data grid without a template of its own (it takes one made before)
private function gridMake pName, pRect
   local tStack, tGrid, tLocked
   put the defaultStack into tStack
   put the lockMessages into tLocked
   -- (the grid sets itself up as it is made, from a message)
   unlock messages
   copy group "DataGrid" of group "Templates" of card 1 of stack "revDataGridLibrary" to this card of stack tStack
   put it into tGrid
   lock messages
   set the name of tGrid to pName
   set the rect of tGrid to pRect
   set the lockMessages to tLocked
   return tGrid
end gridMake

-- A form's row template, on the substack's card in front: the library's,
-- remade in the window's look as theirs was made (the graphic "Background"
-- and the fields "Employee ID", "Name", "Email" and "phone"), pWidth wide
-- and kRowHeight high, with pScript, their behavior, in its button
-- "Behavior Script". Its fields' text has no color of its own, so that it
-- takes the row's: dark at rest, white when the row is selected
private command formTemplate pWidth, pScript
   local tStack, tLocked, tObj
   put the defaultStack into tStack
   put the lockMessages into tLocked
   lock messages
   set the defaultStack to kTemplates
   delete field "Label"
   set the rect of graphic "Background" to 0, 0, pWidth, kRowHeight
   set the backgroundColor of graphic "Background" to "255,255,255"
   put lkLabel("Employee ID", lkR(14, 14, 48, 30), sOrig["mockEmployee ID"], 12, empty, "Row Template") into tObj
   set the blendLevel of tObj to 45
   put lkLabel("Name", lkR(52, 6, pWidth - 134, 24), sOrig["mockName"], 13, empty, "Row Template") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   put lkLabel("Email", lkR(52, 24, pWidth - 134, 40), sOrig["mockEmail"], 12, empty, "Row Template") into tObj
   set the blendLevel of tObj to 35
   set the dontWrap of tObj to true
   put lkLabel("phone", lkR(pWidth - 140, 14, pWidth, 30), sOrig["mockphone"], 12, empty, "Row Template") into tObj
   set the textAlign of tObj to "right"
   set the margins of tObj to "0,4,14,0"
   set the blendLevel of tObj to 20
   set the dontWrap of tObj to true
   set the rect of group "Row Template" to 0, 0, pWidth, kRowHeight
   set the script of button "Behavior Script" to pScript
   set the defaultStack to tStack
   set the lockMessages to tLocked
end formTemplate

-- The Country column of the Table card's grid, as their step 5 copies it
-- into the row template: on the template's card, their flags (hidden: a
-- button shows one by its name), the button "Country Behavior" with their
-- script, and the group "Country", a button that shows a flag
private command countryColumn
   local tStack, tLocked, tName, tObj, tButton
   put the defaultStack into tStack
   put the lockMessages into tLocked
   lock messages
   set the defaultStack to kTemplates
   repeat for each key tName in sFlags
      create image tName
      put it into tObj
      set the text of tObj to sFlags[tName]
      set the topLeft of tObj to 289, 193
      hide tObj
   end repeat
   create button "Country Behavior"
   put it into tButton
   set the visible of tButton to false
   set the rect of tButton to 22, 83, 162, 115
   set the script of tButton to exScript("Country Behavior")
   create group "Country"
   create button "Country" in group "Country"
   put it into tObj
   set the style of tObj to "transparent"
   set the showName of tObj to false
   set the autoHilite of tObj to false
   set the traversalOn of tObj to false
   set the showFocusBorder of tObj to false
   set the rect of tObj to 108, 180, 190, 203
   set the behavior of group "Country" to tButton
   set the defaultStack to tStack
   set the lockMessages to tLocked
end countryColumn

-- The grid takes its style and its row template, and sets itself up
private command gridReady pGrid, pStyle
   local tLocked, tRect
   put the lockMessages into tLocked
   put the rect of pGrid into tRect
   unlock messages
   set the dgProps["style"] of pGrid to pStyle
   set the dgProps["row template"] of pGrid to sRowTemplate
   send "ResetControl" to pGrid
   -- (a grid made a form takes the size the library's has: it is given its
   -- own again, and lays itself out in it)
   set the rect of pGrid to tRect
   set the lockMessages to tLocked
end gridReady

-- A property of a grid, which the grid's script sets
private command gridProp pGrid, pProp, pValue
   local tLocked
   put the lockMessages into tLocked
   unlock messages
   set the dgProps[pProp] of pGrid to pValue
   set the lockMessages to tLocked
end gridProp

-- Their 100 cities: the columns of their grid, its labels, alignment and
-- sorting, with widths here (pWidths, an item each), the data and the
-- column it is sorted by
private command gridCities pGrid, pWidths
   local tLocked, tIndex, tColumn
   put the lockMessages into tLocked
   unlock messages
   set the dgProps["columns"] of pGrid to sOrig["citiesColumns"]
   repeat with tIndex = 1 to the number of lines of sOrig["citiesColumns"]
      put line tIndex of sOrig["citiesColumns"] into tColumn
      -- (narrower than the library's least, 40, as theirs were)
      set the dgColumnMinWidth[tColumn] of pGrid to min(40, item tIndex of pWidths)
      set the dgColumnWidth[tColumn] of pGrid to item tIndex of pWidths
      if sCityProps[tColumn]["alignment"] is not empty then
         set the dgColumnAlignment[tColumn] of pGrid to sCityProps[tColumn]["alignment"]
      end if
      if sCityProps[tColumn]["sort type"] is not empty then
         set the dgColumnSortType[tColumn] of pGrid to sCityProps[tColumn]["sort type"]
      end if
      if sCityProps[tColumn]["sort direction"] is not empty then
         set the dgColumnSortDirection[tColumn] of pGrid to sCityProps[tColumn]["sort direction"]
      end if
      -- (a label of a space, to hide a narrow column's name, is not kept:
      -- the column is wide enough here)
      if word 1 to -1 of sCityProps[tColumn]["label"] is not empty then
         set the dgColumnLabel[tColumn] of pGrid to sCityProps[tColumn]["label"]
      end if
   end repeat
   set the dgData of pGrid to sCities
   if sOrig["citiesSort"] is not empty then
      set the dgProps["sort by column"] of pGrid to sOrig["citiesSort"]
   end if
   set the lockMessages to tLocked
end gridCities

-- The first pCount people of The Template's data, as their card script
-- makes the array: a number for each row, a key for each column
private command gridFillRows pGrid, pCount
   local tLocked, tData, tLine, tIndex, tItem, tHeaders
   put sOrig["templateHeader"] into tHeaders
   set the itemDelimiter to tab
   repeat with tIndex = 1 to pCount
      put line tIndex of sOrig["templateData"] into tLine
      repeat with tItem = 1 to the number of items of tHeaders
         put item tItem of tLine into tData[tIndex][item tItem of tHeaders]
      end repeat
   end repeat
   set the itemDelimiter to comma
   put the lockMessages into tLocked
   unlock messages
   set the dgData of pGrid to tData
   set the lockMessages to tLocked
end gridFillRows

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
--A Data Grid Tour: LiveCode Ltd's Data Grid Tour v1.0, remastered for OXT-Beyond in 2026
--Data Grid Tour v1.0, (c) LiveCode Ltd., edited and debranded for open source as requested by LiveCode Ltd.

--Each stop of the tour is a card. The sidebar, the header, the stage and the scripts drawer are the
--groups "Frame", "Workbench" and "Scripts", which the script of the group "Frame" runs: they take the
--place of the tour's own title bar, page slider and Back and Next buttons (its group "Chrome").

--(remaster) Where the wheel is taking a field and which field, and where a drag of a thumb began
local sGlideGoal, sGlideField, sDragField, sDragFrom, sDragScroll

on openStack
   choose browse tool
   --added: a word, if the IDE's data grid library is not there to draw the grids
   if there is not a stack "revDataGridLibrary" then
      answer "The data grids on these cards need the IDE's data grid library, and it is not loaded." &cr& \
            "In Preferences, under Compatibility, untick Disable Data Grids, then start the IDE again." with "OK" titled "A Data Grid Tour"
   end if
end openStack

on preOpenCard  --(remaster) the code on the card in the scripts panel's font; a glide stops, and each field the wheel scrolls is at its top, with its thumb
   local tIndex, tField, tFont
   put empty into sGlideGoal
   put empty into sDragField
   put codeFontHere() into tFont
   repeat with tIndex = 1 to the number of fields of this card
      put the long id of field tIndex of this card into tField
      if tFont is not empty and the cCode of tField is true and the textFont of tField is not tFont then
         set the textFont of tField to tFont
      end if
      if the cWheel of tField is true then
         set the vScroll of tField to 0
         wheelSync tField
      end if
   end repeat
   pass preOpenCard
end preOpenCard

function codeFontHere  --(remaster) code's font: the scripts panel's (the window finds it before this stack's preOpenCard), or else the first of its choices this computer has
   local tFont
   if there is a field "codeText" then
      if the textFont of field "codeText" is not empty then return the textFont of field "codeText"
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then return tFont
   end repeat
   return empty
end codeFontHere

--(remaster) A field that holds more than it shows (its custom property cWheel is true) scrolls with the
--wheel, without a scrollbar, as the scripts panel does: the slim thumb at its right (the graphic its
--cThumb names) shows how far down it is, and can be dragged.

on rawKeyDown pKey
   local tField, tGliding
   if pKey is not 65308 and pKey is not 65309 then pass rawKeyDown  --the wheel, down or up
   put wheelField() into tField
   if tField is empty then pass rawKeyDown
   put sGlideGoal is not empty into tGliding  --a glide under way takes the new goal (a second one beside it would double its speed)
   if not tGliding or tField is not sGlideField then put the vScroll of tField into sGlideGoal
   put tField into sGlideField
   if pKey is 65308 then add 48 to sGlideGoal
   else subtract 48 from sGlideGoal
   put max(0, min(sGlideGoal, wheelRoom(tField))) into sGlideGoal
   if not tGliding then wheelGlide
end rawKeyDown

on wheelGlide  --one step of the scroll toward where the wheel is taking it
   local tNow, tStep
   if sGlideGoal is empty or sGlideField is empty or not exists(sGlideField) then
      put empty into sGlideGoal
      exit wheelGlide
   end if
   put the vScroll of sGlideField into tNow
   put round((sGlideGoal - tNow) * 0.35) into tStep
   if abs(sGlideGoal - tNow) <= 1 or tStep is 0 then
      set the vScroll of sGlideField to sGlideGoal
      put empty into sGlideGoal
   else
      set the vScroll of sGlideField to tNow + tStep
      if the vScroll of sGlideField is tNow then put empty into sGlideGoal  --it did not move: it is at its end, and the glide is over
      else send "wheelGlide" to me in 16 milliseconds
   end if
   wheelSync sGlideField
end wheelGlide

function wheelField  --the field under the pointer that the wheel scrolls (or whose thumb it is over), or empty
   local tControl
   put the mouseControl into tControl
   if tControl is empty then return empty
   put the long id of tControl into tControl
   if word 1 of tControl is "field" and the cWheel of tControl is true then return tControl
   if word 1 of tControl is "graphic" and the cField of tControl is not empty then
      return the long id of fld (the cField of tControl)
   end if
   return empty
end wheelField

function wheelRoom pField  --how far down a field goes: measured, as the engine stops a field's scroll a few pixels short of its formattedHeight less its height
   local tNow, tRoom, tLocked
   put the vScroll of pField into tNow
   put the lockMessages into tLocked
   lock screen
   lock messages
   set the vScroll of pField to the formattedHeight of pField + the height of pField
   put the vScroll of pField into tRoom
   set the vScroll of pField to tNow
   set the lockMessages to tLocked
   unlock screen
   return max(0, tRoom)
end wheelRoom

command wheelSync pField  --the field's thumb: as long as the share of the field it shows, as far down as the field is
   local tThumb, tRoom, tTrack, tSize, tTop
   if pField is empty or not exists(pField) then exit wheelSync
   put the cThumb of pField into tThumb
   if tThumb is empty or there is no grc tThumb then exit wheelSync
   put wheelRoom(pField) into tRoom
   if tRoom < 8 then
      hide grc tThumb
      exit wheelSync
   end if
   put the height of pField - 16 into tTrack
   put max(24, round(tTrack * tTrack / (tTrack + tRoom))) into tSize
   put the top of pField + 8 + round((tTrack - tSize) * min(1, the vScroll of pField / tRoom)) into tTop
   set the rect of grc tThumb to item 1 of the rect of grc tThumb, tTop, item 3 of the rect of grc tThumb, tTop + tSize
   show grc tThumb
end wheelSync

on mouseDown pButton  --a thumb, dragged: its field goes as far down as it does
   if pButton is 1 and word 1 of the target is "graphic" and the cField of the target is not empty then
      put the long id of fld (the cField of the target) into sDragField
      put item 2 of the mouseLoc into sDragFrom
      put the vScroll of sDragField into sDragScroll
      put empty into sGlideGoal
   end if
   pass mouseDown
end mouseDown

on mouseMove pX, pY
   local tTrack, tRoom
   if sDragField is empty then pass mouseMove
   if the mouse is up or not exists(sDragField) then
      put empty into sDragField
      pass mouseMove
   end if
   put the height of sDragField - 16 - the height of grc (the cThumb of sDragField) into tTrack
   if tTrack > 0 then
      put wheelRoom(sDragField) into tRoom
      set the vScroll of sDragField to max(0, min(tRoom, sDragScroll + round((pY - sDragFrom) * tRoom / tTrack)))
      wheelSync sDragField
   end if
   pass mouseMove
end mouseMove

on mouseUp pButton
   put empty into sDragField
   pass mouseUp
end mouseUp

on mouseRelease pButton
   put empty into sDragField
   pass mouseRelease
end mouseRelease
@*/

/*@ Table
## STEP 1
on loadData
   ## 1: Set the data of the grid. (This is stored in a custom property of this card).
   set the dgText of group "SampleTable" to the cData of this card
end loadData

## STEP 2
on columnsSetNames
   ## 1: Set the column names of the data grid.
   set the dgProps["columns"] of group "SampleTable" to "Rank" & return & "City" & return & "Country" & return & "IconID"
end columnsSetNames

## STEP 3
on columnsSetLook
   ## 1: Make the headers stand out a little more by making the text bold.
   set the dgProps["header text style"] of group "SampleTable" to "bold"
   ## 2: Set the column widths to fit the data nicely.
   set the dgColumnWidth["Rank"] of group "SampleTable" to "50"
   set the dgColumnWidth["City"] of group "SampleTable" to "130"
   set the dgColumnWidth["Country"] of group "SampleTable" to "98"
   ## 3: Make the final column invisible because it is not data useful to the end use.
   set the dgColumnIsVisible["IconID"] of group "SampleTable" to "false"
end columnsSetLook

## STEP 4
on columnsSetOrder
   ## 1: Set the column data type to 'numeric' so that ordering works correctly.
   ## 1: By default a column will act as text.
   set the dgColumnSortType["Rank"] of group "SampleTable" to "Numeric"
   ## 2: Sort the data by column 1.
   set the dgProps["sort by column"] of group "SampleTable" to "Rank"
   ## 3: Set the row colors to match the background.
   set the dgProps["row color"] of group "SampleTable" to "#EEF2FF"  --(remaster) this window's colors: it was "#E6F6FE"
   set the dgProps["alternate row color"] of group "SampleTable" to "#E0E7FF"  --(remaster) it was "#7FC9E8"
   ## 4: Now that columns are setup, disable resizing.
   set the dgColumnIsResizable["Rank"] of group "SampleTable" to false
   set the dgColumnIsResizable["City"] of group "SampleTable" to false
   set the dgColumnIsResizable["Country"] of group "SampleTable" to false
end columnsSetOrder

## STEP 5
on columnsAddFlags
   local tTemplateID, tCardID  --(remaster) declared: strict compilation
   ## Change row template with country flags, adjust column widths.
   put the dgProps["row template"] of group "SampleTable" into tTemplateID
   put tTemplateID into tCardID
   repeat while word 1 of tCardID is not "card"
      delete word 1 of tCardID
   end repeat
   copy group "Country" of tCardID to tTemplateID
   send "resetList" to group "SampleTable"
   set the dgColumnWidth["City"] of group "SampleTable" to "174"
   set the dgColumnWidth["Country"] of group "SampleTable" to "55"
end columnsAddFlags

## STEP 0
on resetDemonstration
   local tTemplateID  --(remaster) declared: strict compilation
   ## This function resets all the properties back to their original setting.
   set the dgProps["columns"] of group "SampleTable" to ""
   set the dgText of group "SampleTable" to ""

   set the dgProps["header text style"] of group "SampleTable" to "normal"
   set the dgProps["row color"] of group "SampleTable" to "#ffffff"
   set the dgProps["alternate row color"] of group "SampleTable" to "#F8FAFC"  --(remaster) the grid's own: it was "#E6EDF7"

   put the dgProps["row template"] of group "SampleTable" into tTemplateID
   if there is a group "Country" of tTemplateID then delete group "Country" of tTemplateID
end resetDemonstration


## OTHER FUNCTION AND HANDLERS

on stepSet pStep
   local x  --(remaster) declared: strict compilation
   ## This function iterates over the step 'buttons' on the interface and fades out
   ## the ones which have not been applied
   repeat with x = 0 to 5
      if x <= pStep then set the blendlevel of button ("Step" & x) to 0
      else set the blendlevel of button ("Step" & x) to 50
   end repeat
end stepSet

on preopencard
   ## Resets the demonstration and sets the stage to 0
   resetDemonstration
   stepSet 0
   pass preOpenCard  --(remaster) so that the window lays this card out
end preopencard
@*/

/*@ Table/step0
on mouseUp
   lock screen
   resetDemonstration

   stepSet 0
   unlock screen
end mouseUp
@*/

/*@ Table/step1
on mouseUp
   lock screen
   resetDemonstration

   ## The load data handler found on the card script inserts
   ## our data into the data grid
   loadData

   stepSet 1
   unlock screen
end mouseUp
@*/

/*@ Table/step2
on mouseUp
   lock screen
   resetDemonstration

   ## These action handlers can be found in the card script
   columnsSetNames
   loadData

   stepSet 2
   unlock screen
end mouseUp
@*/

/*@ Table/step3
on mouseUp
   lock screen
   resetDemonstration

   ## These action handlers can be found in the card script
   columnsSetNames
   loadData
   columnsSetLook

   stepSet 3
   unlock screen
end mouseUp
@*/

/*@ Table/step4
on mouseUp
   lock screen
   resetDemonstration

   ## These action handlers can be found in the card script
   columnsSetNames
   loadData
   columnsSetLook
   columnsSetOrder

   stepSet 4
   unlock screen
end mouseUp
@*/

/*@ Table/step5
on mouseUp
   lock screen
   resetDemonstration

   ## These action handlers can be found in the card script
   columnsSetNames
   loadData
   columnsSetLook
   columnsSetOrder
   columnsAddFlags

   stepSet 5
   unlock screen
end mouseUp
@*/

/*@ View Script
on mouseUp  --opens the scripts drawer on the card's script, the demonstration script
   --edit the script of this card  --(remaster) it opened the Script Editor; the drawer's Edit script button does now
   frameDrawer true, true
   frameShowObject the long id of this card
end mouseUp
@*/

/*@ Country Behavior
-- This script defines the behavior of a table column's custom template.

on FillInData pData
   -- This message is sent when the Data Grid needs to populate
   -- this template with the column data. pData is the value to be displayed.

   -- Example:

   set the icon of button 1 of me to (pData & ".png")
   set the tooltip of button 1 of me to pData
end FillInData


on LayoutControl
   local theMasterRect

   -- This message is sent when you should layout your template's controls if your template is a group.
   -- If your template is not a group then there is no work to do here.
   -- The first thing you should do is capture 'the rect of me'.
   -- You can use items 1 through 4 of the rect as boundaries for laying out your controls.

   -- Example:
   put the rect of me into theMasterRect

   set the rect of button 1 of me to theMasterRect
end LayoutControl


setprop dgHilite pBoolean
   -- This custom property is set when the highlight of your column template has
   -- changed. You only add script here if you want to customize the highlight.

   if pBoolean then
      set the foregroundcolor of me to the dgProp["hilited text color"] of the dgControl of me
   else
      set the foregroundcolor of me to empty
   end if
end dgHilite


getprop dgDataControl
   -- Required by library so that it can locate your control.
   return the long id of me
end dgDataControl


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
         if the dgProps["allow editing"] of the dgControl of me then
            EditFieldText the long id of the target, the dgIndex of me, word 1 to -2 of the short name of me
         end if
      end if
   end if

   pass mouseDoubleUp
end mouseDoubleUp
@*/

/*@ Form
## STEP 1
on loadData
   local tHeaders, tData, tLine, tKey1, tKey2, tCount
   local theDataArray  --(remaster) declared: strict compilation
   ## 1: The headers and data for the form are loaded from custom properties on this card.
   put the cHeaders of this card into tHeaders
   put the cData of this card into tData
   ## 2: The data is multiple rows each containing items separated by the tab character.
   ## 2: Set the itemDelimiter to tab to repeat over each item.
   set the itemDelimiter to tab
   ## 3: Iterate through each line in the data.
   repeat for each line tLine in tData
      add 1 to tKey1
      put 0 into tCount
      ## 4: Iterate over each item in the header names.
      repeat for each item tKey2 in tHeaders
         add 1 to tCount
         ## 5: Put the current item of the current line into the two-dimensional array.
         ## 5: KEY 1 : The line number, an integer from 1 to x.
         ## 5: KEY 2 : The name of the header, a key word that holds the value.
         ## 5: DATA : The current item in the current line of data.
         put item tCount of tLine into theDataArray[tKey1][tKey2]
      end repeat
   end repeat
   ## 6: Load the array data into the data grid by setting the dgData property.
   set the dgData of group "SampleForm" to theDataArray
end loadData

## STEP 2
on formatForm
   ## 3: Set the row colors to match the background.
   set the dgProps["row color"] of group "SampleForm" to "#EEF2FF"  --(remaster) this window's colors: it was "#E6F6FE"
   set the dgProps["alternate row color"] of group "SampleForm" to "#E0E7FF"  --(remaster) it was "#7FC9E8"
end formatForm

## STEP 0
on resetDemonstration
   ## This function resets all the properties back to their original setting.
   set the dgData of group "SampleForm" to ""
   set the dgProps["row color"] of group "SampleForm" to "#ffffff"
   set the dgProps["alternate row color"] of group "SampleForm" to "#F8FAFC"  --(remaster) the grid's own: it was "#E6EDF7"
end resetDemonstration

## OTHER FUNCTION AND HANDLERS

on stepSet pStep
   local x  --(remaster) declared: strict compilation
   ## This function iterates over the step 'buttons' on the interface and fades out
   ## the ones which have not been applied.
   repeat with x = 0 to 2
      if x <= pStep then set the blendlevel of button ("Step" & x) to 0
      else set the blendlevel of button ("Step" & x) to 50
   end repeat
end stepSet

on preopencard
   ## Resets the demonstration and sets the stage to 0.
   resetDemonstration
   stepSet 0
   pass preOpenCard  --(remaster) so that the window lays this card out
end preopencard
@*/

/*@ Form/step0
on mouseUp
   lock screen
   resetDemonstration

   stepSet 0
   unlock screen
end mouseUp
@*/

/*@ Form/step1
on mouseUp
   lock screen
   resetDemonstration

   ## The load data handler found on the card script inserts
   ## our data into the data grid
   loadData

   stepSet 1
   unlock screen
end mouseUp
@*/

/*@ Form/step2
on mouseUp
   lock screen
   resetDemonstration

   ## These action handlers can be found in the card script
   formatForm
   loadData

   stepSet 2
   unlock screen
end mouseUp
@*/

/*@ Form Row Behavior
-- This script defines the behavior of your data grid's custom template. This behavior
-- only applies to 'forms' and not 'tables'.

on FillInData pDataArray
   local tName  --(remaster) declared: strict compilation

   put pDataArray["First name"] & ", " & pDataArray["Last Name"] into tName
   put tName into field "name" of me

   put pDataArray["Email"] into field "email" of me
   put pDataArray["ecPhone"] into field "phone" of me
   put pDataArray["Employee ID"] into field "Employee ID" of me

end FillInData

on mouseDown pMouseButton
   local theDataGrid, theLineNo, theDataA  --(remaster) declared: strict compilation
   if pMouseButton is 1 then
      if the short name of the target is "arrow" then
         put the dgControl of me into theDataGrid
         put the dgLine of me into theLineNo

         put the dgDataOfLine[theLineNo] of theDataGrid into theDataA
         put not theDataA["Expanded"] into theDataA["Expanded"]
         set the dgDataOfLine[theLineNo] of theDataGrid to theDataA
      end if
   end if

   pass mouseDown
end mouseDown


on LayoutControl
   local theFieldRect,theMasterRect
   local r  --(remaster) declared: strict compilation

   -- This message is sent when you should layout your template's controls.
   -- This is where you resize the 'Background' graphic, resize fields and
   -- position objects.
   -- The first thing you should do is capture 'the rect of me'.
   -- For fixed height data grid forms you can use items 1 through 4 of the rect as
   -- boundaries for laying out your controls.
   -- For variable height data grid forms you can use items 1 through 3 of the rect as
   -- boundaries.

   put the rect of me into theMasterRect

   set the right of field "phone" of me to item 3 of theMasterRect

   put the rect of grc "Background" of me into r

   set the rect of grc "Background" of me to r
end LayoutControl


setprop dgHilite pBoolean
   -- This custom property is set when the highlight of your custom template has
   -- changed. By default the "Background" graphic will be highlighted for you.
   -- You only add script here if you want to further customize the highlight.

   -- Example:
   if pBoolean then
      set the foregroundcolor of me to the dgProp["hilited text color"] of the dgControl of me
   else
      set the foregroundcolor of me to empty
   end if
end dgHilite


getprop dgDataControl
   -- Required by library so that it can locate your control.
   return the long id of me
end dgDataControl


on mouseDoubleUp pMouseBtnNum
   local theKey

   -- Example of how to edit the contents of a field.
   -- By passing the index of the record associated with copy of this template being displayed and
   -- a key (array key) the data grid will automatically save the changes the user
   -- makes and refresh the UI by calling FillInData and resizeControl.
   if pMouseBtnNum is 1 then
      if the dgProps["allow editing"] of the dgControl of me then
         switch the short name of the target
            case "Label"
               put "Label 1" into theKey
               EditFieldText the long id of the target, the dgIndex of me, theKey
               break
         end switch
      end if
   end if

   pass mouseDoubleUp
end mouseDoubleUp
@*/

/*@ The Template
## This script works by repeatedly setting the data of the grid. In effect,
## adding an extra row of data to the grid every 3/4 of a second until 8 rows are filled.

## Script locals track the current number of rows displayed and have the data array.
local sDataArray
local sRowCount

## Set the row count to 0 and the demo starts.
on openCard
   put 0 into sRowCount
   demonstrationStart
   pass openCard
end openCard

## The demonstrationPrepare command is taking the data and header information stored
## in a custom property on this card and processing it into a two-dimension array the data grid can understand.
on demonstrationPrepare pRowCount
   local tHeaders, tData, tKey1, tKey2, tLine, tCount
   put the cHeader of this card into tHeaders
   put the cData of this card into tData
   put empty into sDataArray
   set the itemDelimiter to tab
   put 0 into tKey1
   repeat for each line tLine in tData
      add 1 to tKey1
      if tKey1 <= sRowCount then
         put 0 into tCount
         repeat for each item tKey2 in tHeaders
            add 1 to tCount
            put item tCount of tLine into sDataArray[tKey1][tKey2]
            put "false" into sDataArray[tKey1]["expanded"]
         end repeat
      end if
   end repeat
end demonstrationPrepare

on demonstrationStart
   ## Check that the user is still on this card.
   if the short name of this card is "The Template" then
      ## After displaying 8 rows or more, stop the demo.
      if sRowCount > 8 then
         --put 0 into sRowCount  --loop demo until user leaves card.
         exit to top  --stop demo.
      end if
      add 1 to sRowCount
      ## Prepare the data to insert into the data grid.
      demonstrationPrepare sRowCount
      ## Set the data in the data grid.
      set the dgData of group "SlowLoadingGrid" to sDataArray
      ## Add another row to the grid in 3/4 of a second.
      send "demonstrationStart" to me in 750 milliseconds  --(remaster) the message's name quoted: strict compilation
   end if
end demonstrationStart
@*/

/*@ Replay
on mouseUp  --added: the rows arrive again, as when the card opens
   local tMessage
   repeat for each line tMessage in the pendingMessages
      if item 3 of tMessage is "demonstrationStart" then cancel item 1 of tMessage
   end repeat
   dispatch "openCard" to this card  --(dispatch, as the card passes openCard on: a send would end in an error)
end mouseUp
@*/

/*@ Template Row Behavior
-- This script defines the behavior of your data grid's custom template. This behavior
-- only applies to 'forms' and not 'tables'.

on FillInData pDataArray
   local tName  --(remaster) declared: strict compilation
   put pDataArray["First name"] & ", " & pDataArray["Last Name"] into tName
   put tName into field "name" of me

   put pDataArray["Email"] into field "email" of me
   put pDataArray["ecPhone"] into field "phone" of me
   put pDataArray["Employee ID"] into field "Employee ID" of me
end FillInData

on LayoutControl
   local theFieldRect,theMasterRect
   local r  --(remaster) declared: strict compilation

   -- This message is sent when you should layout your template's controls.
   -- This is where you resize the 'Background' graphic, resize fields and
   -- position objects.
   -- The first thing you should do is capture 'the rect of me'.
   -- For fixed height data grid forms you can use items 1 through 4 of the rect as
   -- boundaries for laying out your controls.
   -- For variable height data grid forms you can use items 1 through 3 of the rect as
   -- boundaries.

   put the rect of me into theMasterRect

   set the right of field "phone" of me to item 3 of theMasterRect

   put the rect of grc "Background" of me into r
   put item 3 of theMasterRect into item 3 of r
   set the rect of grc "Background" of me to r
end LayoutControl


setprop dgHilite pBoolean
   -- This custom property is set when the highlight of your custom template has
   -- changed. By default the "Background" graphic will be highlighted for you.
   -- You only add script here if you want to further customize the highlight.

   -- Example:
   if pBoolean then
      set the foregroundcolor of me to the dgProp["hilited text color"] of the dgControl of me
   else
      set the foregroundcolor of me to empty
   end if
end dgHilite


getprop dgDataControl
   -- Required by library so that it can locate your control.
   return the long id of me
end dgDataControl


on mouseDoubleUp pMouseBtnNum
   local theKey

   -- Example of how to edit the contents of a field.
   -- By passing the index of the record associated with copy of this template being displayed and
   -- a key (array key) the data grid will automatically save the changes the user
   -- makes and refresh the UI by calling FillInData and resizeControl.
   if pMouseBtnNum is 1 then
      if the dgProps["allow editing"] of the dgControl of me then
         switch the short name of the target
            case "Label"
               put "Label 1" into theKey
               EditFieldText the long id of the target, the dgIndex of me, theKey
               break
         end switch
      end if
   end if

   pass mouseDoubleUp
end mouseDoubleUp
@*/

/*@ Properties
on preopencard
   stepSet 1
   pass preOpenCard  --(remaster) so that the window lays this card out
end preopencard

on stepSet pStep
   local x  --(remaster) declared: strict compilation
   ## This iterates over the step 'buttons' on the interface and fades out the buttons not applied.
   repeat with x = 1 to 3
      set the blendLevel of button ("Step" & x) to 50
      hide group ("prop" & x)  --(remaster) each pane is a group here, where it was a picture: hide image ("prop" & x)
      hide field ("prop1")
   end repeat
   set the blendLevel of button ("Step" & pStep) to 0
   show group ("prop" & pStep)  --(remaster) it was show image ("prop" & pStep)
   if pStep = 1 then show field "Prop1"
end stepSet
@*/

/*@ Properties/step1
on mouseUp
   stepSet 1
end mouseUp
@*/

/*@ Properties/step2
on mouseUp
   stepSet 2
end mouseUp
@*/

/*@ Properties/step3
on mouseUp
   stepSet 3
end mouseUp
@*/

/*@ Properties/try2
put line 1 of the dgText of grp "Cities"
put the dgNumberOfLines of grp "Cities"
set the dgHilitedLines of grp "Cities" to 3
put the dgHilitedLines of grp "Cities"
@*/

/*@ Properties/try3
set the dgColumnIsVisible["Country"] of grp "Cities" to false
set the dgColumnIsVisible["Country"] of grp "Cities" to true
set the dgColumnAlignment["City"] of grp "Cities" to "center"
set the dgColumnAlignment["City"] of grp "Cities" to "left"
set the dgProps["sort by column"] of grp "Cities" to "City"
set the dgProps["sort by column"] of grp "Cities" to "Rank"
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

/*@ Summary/Data Grid Guide
on mouseUp  --added: opens the guide, as Help > Data Grid Guide PDF does
   local tError
   if the platform is "HTML5" then
      answer "The Data Grid Guide is a PDF in the Help menu of OXT-Beyond on a computer: a browser cannot open it from here." with "OK" titled "A Data Grid Tour"
      exit mouseUp
   end if
   try
      revIDELaunchResource "Data Grid Guide"
   catch tError
      answer "The Data Grid Guide could not be opened from here. It is in the Help menu of OXT-Beyond." with "OK" titled "A Data Grid Tour"
   end try
end mouseUp
@*/

/*@ Summary/User Guide
on mouseUp  --added: opens the guide, as Help > User Guide PDF does
   local tError
   if the platform is "HTML5" then
      answer "The User Guide is a PDF in the Help menu of OXT-Beyond on a computer: a browser cannot open it from here." with "OK" titled "A Data Grid Tour"
      exit mouseUp
   end if
   try
      revIDELaunchResource "User Guide"
   catch tError
      answer "The User Guide could not be opened from here. It is in the Help menu of OXT-Beyond." with "OK" titled "A Data Grid Tour"
   end try
end mouseUp
@*/
