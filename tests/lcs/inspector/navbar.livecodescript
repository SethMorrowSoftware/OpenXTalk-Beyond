script "TestInspectorNavBar"
-- OXT-Beyond: tests of the Property Inspector's editor of a navigation
-- bar's items, the editor com.livecode.pi.navbar
-- (ide/Toolset/palettes/inspector/editors/com.livecode.pi.navbar.livecode
-- and its behavior, on the editors' own behavior,
-- revinspectoreditorbehavior.livecodescript), made as the Inspector makes
-- one: the editor stack's group "template" copied, given the behavior and
-- the property's info, then editorInitialize.
--
-- The editor is a navigation bar widget in its edit mode, which draws a
-- white sheet with black labels in the light appearance (in the dark one
-- a dark sheet with light labels and icons, which the IDE tour checks: the
-- engine's tests run in the light one), a row of 50 points
-- for each item: its label, its icon, its highlighted icon and three
-- actions. It draws the icon in the widget's foreground colour. The
-- editor's widget had none of its own, so the icon took the Inspector's
-- text colour, which is light in the dark appearance: on a Mac the icon
-- could not be seen on the sheet, and on Linux hardly (bwmilby, issue
-- 568). The editor now gives its widget the labels' black as its own
-- colour. A stack's foregroundColor stands for the Inspector's text
-- colour here: white for a dark Inspector, black for a light one.

constant kEditor = "com.livecode.pi.navbar"
constant kBehavior = "com.livecode.pi.navbar.behavior"
constant kStack = "TestInspectorNavBarStack"
-- the editor's widget in the test: this wide, at 10,10 of the card
constant kWidth = 320
-- of the pixels of an icon's rect, 30 points square, how many a round
-- icon that can be seen covers at the least (a disc 30 across is 706)
constant kSeen = 300

-- The stacks the test found in memory, which it leaves there
local sFound

on TestSetup
   local tStack
   TestSkipIfNot "ide"
   TestLoadExtension "com.livecode.library.widgetutils"
   TestLoadExtension "com.livecode.library.iconsvg"
   TestLoadExtension "com.livecode.widget.navbar"
   repeat for each item tStack in "revInspectorEditorBehavior," & kBehavior & comma & kEditor
      put there is a stack tStack into sFound[tStack]
   end repeat
   get the long id of stack (TestGetIDERepositoryPath() & "/Toolset/palettes/inspector/behaviors/revinspectoreditorbehavior.livecodescript")
   get the long id of stack (TestGetIDERepositoryPath() & "/Toolset/palettes/inspector/editors/com.livecode.pi.navbar.behavior.livecodescript")
   get the long id of stack (TestGetIDERepositoryPath() & "/Toolset/palettes/inspector/editors/com.livecode.pi.navbar.livecode")
   create stack kStack
   set the hiliteColor of stack kStack to "10,95,244"
end TestSetup

on TestTeardown
   local tStack
   if there is a stack kStack then delete stack kStack
   repeat for each item tStack in kEditor & comma & kBehavior & ",revInspectorEditorBehavior"
      if there is a stack tStack and sFound[tStack] is not true then delete stack tStack
   end repeat
end TestTeardown

--------------------------------------------------------------------------------
-- Helpers

-- An editor of a navigation bar's items, made and initialized as the
-- Inspector makes one (propertyRegister in
-- revinspectorgroupbehavior.livecodescript), showing the widget's own
-- items with a disc for every icon, its widget kWidth wide at 10,10 of
-- the card: its long id
private function makeEditor
   local tInfo, tEditor, tWidget, tItems, tKey
   set the defaultStack to kStack
   lock messages
   copy group "template" of stack kEditor to card 1 of stack kStack
   put it into tEditor
   set the name of tEditor to "itemArray"
   set the behavior of stack kBehavior to the long id of stack "revInspectorEditorBehavior"
   set the behavior of tEditor to the long id of stack kBehavior
   unlock messages
   put "itemArray" into tInfo["property_name"]
   put false into tInfo["read_only"]
   set the editorPropertyInfo of tEditor to tInfo
   dispatch "editorInitialize" to tEditor
   put the long id of widget 1 of tEditor into tWidget
   put the itemArray of tWidget into tItems
   repeat for each key tKey in tItems
      put "circle" into tItems[tKey]["icon_name"]
      put "circle" into tItems[tKey]["hilited_icon_name"]
   end repeat
   set the editorValue of tEditor to tItems
   dispatch "editorUpdate" to tEditor
   set the rect of tWidget to 10, 10, 10 + kWidth, 10 + the desiredHeight of tWidget
   return tEditor
end makeEditor

-- The rect, from the widget's top left, of the icon of the row pRow of
-- the edit mode of the navigation bar pWidget, or with pHilited of its
-- highlighted icon: 30 points square, 145 points in from the right (the
-- highlighted icon 95), 10 down the row's 50 (calculateEditModeIconRects
-- in extensions/widgets/navbar/navbar.lcb)
private function iconRect pWidget, pRow, pHilited
   local tLeft, tTop
   put the width of pWidget - 145 into tLeft
   if pHilited is true then add 50 to tLeft
   put (pRow - 1) * 50 + 10 into tTop
   return tLeft & comma & tTop & comma & (tLeft + 30) & comma & (tTop + 30)
end iconRect

-- The red, green and blue of every pixel of a snapshot of the widget
-- pWidget, and the snapshot's width, for inkIn and pixelAt
private function pixelsOf pWidget, @rWidth
   local tData
   export snapshot from pWidget to tData as PNG
   create image "TestInspectorNavBarPixels" in card 1 of stack kStack
   set the text of image "TestInspectorNavBarPixels" of card 1 of stack kStack to tData
   put the width of image "TestInspectorNavBarPixels" of card 1 of stack kStack into rWidth
   put the imageData of image "TestInspectorNavBarPixels" of card 1 of stack kStack into tData
   delete image "TestInspectorNavBarPixels" of card 1 of stack kStack
   return tData
end pixelsOf

-- Of the pixels of the rect pRect of the widget pWidget, as a snapshot of
-- it shows them: how many are ink (red, green and blue each under 100),
-- and how many are not the sheet's white (one of the three under 240),
-- "ink,drawn"
private function inkIn pWidget, pRect
   local tData, tWidth, tInk, tDrawn, tAt, tR, tG, tB, tX, tY
   put pixelsOf(pWidget, tWidth) into tData
   put 0 into tInk
   put 0 into tDrawn
   repeat with tY = item 2 of pRect to item 4 of pRect - 1
      repeat with tX = item 1 of pRect to item 3 of pRect - 1
         put (tY * tWidth + tX) * 4 into tAt
         put byteToNum(byte tAt + 2 of tData) into tR
         put byteToNum(byte tAt + 3 of tData) into tG
         put byteToNum(byte tAt + 4 of tData) into tB
         if tR < 100 and tG < 100 and tB < 100 then add 1 to tInk
         if tR < 240 or tG < 240 or tB < 240 then add 1 to tDrawn
      end repeat
   end repeat
   return tInk & comma & tDrawn
end inkIn

-- The red, green and blue of the widget pWidget at pX, pY from its top
-- left, as a snapshot of it shows it
private function pixelAt pWidget, pX, pY
   local tData, tWidth, tAt
   put pixelsOf(pWidget, tWidth) into tData
   put (pY * tWidth + pX) * 4 into tAt
   return byteToNum(byte tAt + 2 of tData) & comma & byteToNum(byte tAt + 3 of tData) & comma & \
         byteToNum(byte tAt + 4 of tData)
end pixelAt

--------------------------------------------------------------------------------
-- Tests

-- A dark Inspector, whose text is white: every row's icon is drawn in
-- ink on the white sheet, and the highlighted icon beside it as before.
-- Then the widget's own colour is taken off, as it was before the editor
-- gave it one: the icon is the Inspector's white, on the white sheet
on TestTheIconsShowOnTheSheetInADarkInspector
   local tEditor, tWidget, tItems, tRows, tRow, tShown, tHilited
   set the foregroundColor of stack kStack to "255,255,255"
   put makeEditor() into tEditor
   put the long id of widget 1 of tEditor into tWidget
   put the itemArray of tWidget into tItems
   put the number of elements of tItems into tRows
   TestDiagnostic "the widget" && the rect of tWidget & ", rows" && tRows & ", its foregroundColor" && \
         the foregroundColor of tWidget & ", the effective one" && the effective foregroundColor of tWidget
   TestAssert "the editor's widget is in its edit mode", the editMode of tWidget is true
   TestAssert "the editor shows a row for an item or more", tRows >= 1
   TestAssert "the editor gives its widget black as its own colour", the foregroundColor of tWidget is "0,0,0"
   TestAssert "the sheet is white between an icon and its highlighted icon", \
         pixelAt(tWidget, the width of tWidget - 105, 25) is "255,255,255"
   repeat with tRow = 1 to tRows
      put inkIn(tWidget, iconRect(tWidget, tRow, false)) into tShown
      put inkIn(tWidget, iconRect(tWidget, tRow, true)) into tHilited
      TestDiagnostic "row" && tRow & ": the icon's ink and drawn pixels" && tShown & ", the highlighted icon's" && tHilited
      TestAssert "the icon of row" && tRow && "is drawn in ink on the sheet", item 1 of tShown >= kSeen
      TestAssert "the highlighted icon of row" && tRow && "is drawn, as before", item 2 of tHilited >= kSeen
   end repeat

   set the foregroundColor of tWidget to empty
   put inkIn(tWidget, iconRect(tWidget, 1, false)) into tShown
   TestDiagnostic "with no colour of its own: the icon's ink and drawn pixels" && tShown
   TestAssert "with no colour of its own the widget draws the icon in the Inspector's white, " & \
         "which the white sheet does not show (bwmilby, issue 568)", tShown is "0,0"
end TestTheIconsShowOnTheSheetInADarkInspector

-- A light Inspector, whose text is black: the icons are black on the
-- sheet, and pixel for pixel what they were with no colour of the
-- widget's own, the Inspector's black
on TestTheIconsAreAsBeforeInALightInspector
   local tEditor, tWidget, tItems, tRows, tRow, tShown, tBefore
   set the foregroundColor of stack kStack to "0,0,0"
   put makeEditor() into tEditor
   put the long id of widget 1 of tEditor into tWidget
   put the itemArray of tWidget into tItems
   put the number of elements of tItems into tRows
   TestAssert "the editor shows a row for an item or more", tRows >= 1
   repeat with tRow = 1 to tRows
      put inkIn(tWidget, iconRect(tWidget, tRow, false)) into tShown[tRow]
      TestDiagnostic "row" && tRow & ": the icon's ink and drawn pixels" && tShown[tRow]
      TestAssert "the icon of row" && tRow && "is drawn in ink on the sheet", item 1 of tShown[tRow] >= kSeen
   end repeat
   set the foregroundColor of tWidget to empty
   repeat with tRow = 1 to tRows
      put inkIn(tWidget, iconRect(tWidget, tRow, false)) into tBefore
      TestAssert "the icon of row" && tRow && "has the pixels it had in the Inspector's black", tBefore is tShown[tRow]
   end repeat
end TestTheIconsAreAsBeforeInALightInspector
