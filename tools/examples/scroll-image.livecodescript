script "OXTExampleScrollImage"
-- OXT-Beyond: builds "Scroll an Image", the remaster of the demo Scroll
-- Image from OpenXTalk Lite's demos (its author is not recorded; its
-- standalone settings say 2013), which is in
-- ide/Resources/Examples/Scroll Image.oxtstack and stays there as its
-- author made it.
--
-- The original teaches one thing, in its stack script's four steps: put a
-- picture in a group, give the group scrollbars, and it shows the picture
-- through a window of its own size. Its first card scrolls El Greco's Lady
-- in a Fur Wrap (a public domain painting), and its second a group of a
-- button and a field. The remaster keeps both, as "The Painting" and
-- "Controls Scroll Too", with the button's script, the field's text and
-- the painting copied from the original when this builder runs. What it
-- adds is in the original's spirit: the group's hScroll and vScroll in the
-- header as it scrolls (the message scrollbarDrag), a small copy of the
-- painting to drag in, a tour that scrolls by script, and a card of
-- switches that set the group's scrollbar properties and show the line of
-- script each one ran.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kStageLeft = 256
constant kStageTop = 104
constant kStageRight = 600
constant kStageBottom = 616
-- The stage's inside, 20 pixels in from its edges
constant kInLeft = 276
constant kInTop = 124
constant kInRight = 580
constant kInBottom = 596

-- The painting, read from the original stack; and the example's colour
local sPicture, sAccent

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tRepo, tOriginal, tButtonText, tFieldA
   exUseScripts the script of me
   exAddIcon "sliders-horizontal", "<line x1='21' x2='14' y1='4' y2='4'/><line x1='10' x2='3' y1='4' y2='4'/>" & \
         "<line x1='21' x2='12' y1='12' y2='12'/><line x1='8' x2='3' y1='12' y2='12'/><line x1='21' x2='16' y1='20' y2='20'/>" & \
         "<line x1='12' x2='3' y1='20' y2='20'/><line x1='14' x2='14' y1='2' y2='6'/><line x1='8' x2='8' y1='10' y2='14'/>" & \
         "<line x1='16' x2='16' y1='18' y2='22'/>"
   -- What the remaster takes from the original: the painting and the
   -- field's text. The original is read, then unloaded from memory (its
   -- file stays as it is), before the new stack is made
   set the itemDelimiter to slash
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put tRepo & "/ide/Resources/Examples/Scroll Image.oxtstack" into tOriginal
   put the text of image "ElGreco.jpg" of card 1 of stack tOriginal into sPicture
   put the htmlText of field "A" of card 2 of stack tOriginal into tFieldA
   put the label of button "Test Button" of card 2 of stack tOriginal into tButtonText
   delete stack tOriginal
   if sPicture is empty then
      throw "cannot read the painting from " & tOriginal
   end if

   put "Scroll an Image" into tInfo["name"]
   put "from OpenXTalk Lite's demos" into tInfo["credit"]
   put "move" into tInfo["icon"]
   put lkColor("teal") into tInfo["accent"]
   put lkColor("sky") into tInfo["accent2"]
   put lkColor("teal") into sAccent
   put "Program" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Scroll an Image|A small window onto a big picture: a group with scrollbars.|move|front" & return & \
         "The Painting|The Painting|Scroll El Greco's painting with the scrollbars, the wheel or the small copy, or take a tour.|image|program" & return & \
         "Controls Scroll Too|Controls Scroll Too|A group of buttons and fields scrolls the same way as a picture.|layers|program" & return & \
         "Scrollbar Settings|Scrollbar Settings|Turn the group's scrollbars on and off, and see the line of script each switch runs.|sliders-horizontal|program" \
         into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   buildPainting
   buildControls tFieldA, tButtonText
   buildSettings
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Scroll an Image.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

################################################################################
#
# Pieces the cards share
#

-- An image of the painting, scaled to pRect
private function siPicture pName, pRect, pGroup
   local tObj
   if pGroup is empty then
      create image pName
   else
      create image pName in group pGroup
   end if
   put it into tObj
   set the text of tObj to sPicture
   set the resizeQuality of tObj to "best"
   set the rect of tObj to pRect
   return tObj
end siPicture

-- A group that scrolls what it holds: made with a 1-pixel anchor at its
-- top left (the first control made in an empty group goes there), which
-- siScrollerDone deletes once the group holds what it shows
private command siScroller pName, pRect
   get lkGroup(pName, pRect, empty)
   get lkBox(pName & "_anchor", lkR(item 1 of pRect, item 2 of pRect, item 1 of pRect + 1, item 2 of pRect + 1), empty, 0, pName)
end siScroller

private command siScrollerDone pName, pRect, pMargins
   delete graphic (pName & "_anchor") of group pName
   set the margins of group pName to pMargins
   set the lockLoc of group pName to true
   set the rect of group pName to pRect
   set the hScrollbar of group pName to true
   set the vScrollbar of group pName to true
end siScrollerDone

-- A white panel on the front page: an icon on a tint, and a title
private command siPanel pName, pRect, pTitle, pIcon
   local tObj, tLeft, tTop
   put item 1 of pRect into tLeft
   put item 2 of pRect into tTop
   get lkGroup(pName, pRect, empty)
   put exPanel(pName & "_bg", pRect, pName) into tObj
   put lkBox(pName & "_iconBg", lkR(tLeft + 18, tTop + 18, tLeft + 54, tTop + 54), lkMix("255,255,255", sAccent, 0.12), 10, pName) into tObj
   get exIcon(pName & "_icon", pIcon, sAccent, lkR(tLeft + 26, tTop + 26, tLeft + 46, tTop + 46), pName)
   put lkLabel(pName & "_title", lkR(tLeft + 68, tTop + 26, item 3 of pRect - 18, tTop + 46), pTitle, 15, lkColor("ink"), pName) into tObj
   set the textStyle of tObj to "bold"
end siPanel

-- A line of a panel: a check (an icon) or a number in a disc, and words
private command siPanelRow pGroup, pName, pLeft, pTop, pRight, pMark, pText
   local tObj
   if pMark is a number then
      put lkOval(pName & "_disc", lkR(pLeft, pTop, pLeft + 22, pTop + 22), sAccent, pGroup) into tObj
      put lkLabel(pName & "_number", lkR(pLeft, pTop + 2, pLeft + 22, pTop + 20), pMark, 11, "255,255,255", pGroup, "center") into tObj
      set the textStyle of tObj to "bold"
      siMiddle tObj, pTop + 11
   else
      get exIcon(pName & "_icon", pMark, sAccent, lkR(pLeft + 2, pTop + 2, pLeft + 20, pTop + 20), pGroup)
   end if
   put lkLabel(pName & "_text", lkR(pLeft + 34, pTop + 2, pRight, pTop + 42), pText, 13, lkColor("soft"), pGroup) into tObj
end siPanelRow

-- Puts a label's text in the middle of pMid, up and down, as exButton does
private command siMiddle pObj, pMid
   local tTop
   put pMid - (the formattedHeight of pObj + 4) div 2 into tTop
   set the rect of pObj to item 1 of the rect of pObj, tTop, item 3 of the rect of pObj, tTop + the formattedHeight of pObj + 8
end siMiddle

-- The group's hScroll and vScroll, in the header at the right, as the
-- score is in Animate a Letter
private command siReadouts
   local tObj
   put lkLabel("HLabel", lkR(846, 16, 920, 30), "HSCROLL", 11, lkColor("soft"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("HValue", lkR(846, 28, 920, 66), "0", 28, sAccent, empty, "right") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("VLabel", lkR(926, 16, 1000, 30), "VSCROLL", 11, lkColor("soft"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("VValue", lkR(926, 28, 1000, 66), "0", 28, sAccent, empty, "right") into tObj
   set the textStyle of tObj to "bold"
end siReadouts

-- A switch, as Home draws its own: a row that lights up, a track, a knob
-- and a label, in a group of their own
private command siSwitch pName, pGroup, pLeft, pTop, pRight, pLabel
   local tObj
   get lkGroup(pName, lkR(pLeft, pTop, pRight, pTop + 34), pGroup)
   put lkBox(pName & "_bg", lkR(pLeft, pTop, pRight, pTop + 34), "255,255,255", 10, pName) into tObj
   lkBorder tObj, lkColor("line")
   put lkBox(pName & "_track", lkR(pLeft + 12, pTop + 8, pLeft + 46, pTop + 26), "203,213,225", 18, pName) into tObj
   put lkOval(pName & "_knob", lkR(pLeft + 14, pTop + 10, pLeft + 28, pTop + 24), "255,255,255", pName) into tObj
   lkShadow tObj, 3, 1, 30
   put lkLabel(pName & "_label", lkR(pLeft + 56, pTop + 8, pRight - 8, pTop + 26), pLabel, 13, lkColor("ink"), pName) into tObj
   siMiddle tObj, pTop + 17
   set the cRest of group pName to "255,255,255"
   set the cLit of group pName to lkMix("255,255,255", sAccent, 0.07)
end siSwitch

-- A choice of a row of them: a box that lights up, and a label
private command siChoice pName, pGroup, pLeft, pTop, pRight, pBottom, pLabel
   local tObj
   get lkGroup(pName, lkR(pLeft, pTop, pRight, pBottom), pGroup)
   put lkBox(pName & "_bg", lkR(pLeft, pTop, pRight, pBottom), "255,255,255", 8, pName) into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel(pName & "_label", lkR(pLeft, pTop, pRight, pBottom), pLabel, 13, lkColor("ink"), pName, "center") into tObj
   siMiddle tObj, (pTop + pBottom) div 2
   set the cRest of group pName to "255,255,255"
   set the cLit of group pName to lkMix("255,255,255", sAccent, 0.07)
end siChoice

################################################################################
#
# The cards
#

-- The front page: what this is, a tile for each program, what you will
-- learn and how the original was made
private command buildFront
   local tObj, tTop, tIndex, tRow, tOneLine, tSteps
   go card "Start"
   exHero lkR(kStageLeft, kStageTop, 1000, 272), lkColor("teal") & "|" & lkColor("sky"), \
         "FROM OPENXTALK LITE'S DEMOS  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "A small window onto a big picture", \
         "Put a picture in a group, give the group scrollbars, and the group shows the picture " & \
         "through a window of its own size. Scroll a painting, take a tour of it, and learn the " & \
         "properties and the message that do it."
   -- the painting, in a white frame, at the banner's right
   put lkBox("hero_frame", lkR(856, 118, 974, 258), "255,255,255", 4, "hero") into tObj
   lkShadow tObj, 18, 6, 40
   get siPicture("hero_picture", lkR(862, 124, 968, 252), "hero")
   exProgramTiles 288, 3, 60, 12

   put 364 into tTop
   siPanel "Learn", lkR(kStageLeft, tTop, 620, 616), "What you will learn", "graduation-cap"
   siPanelRow "Learn", "Learn1", kStageLeft + 22, tTop + 72, 600, "check", "Scrollbars: hScrollbar and vScrollbar"
   siPanelRow "Learn", "Learn2", kStageLeft + 22, tTop + 114, 600, "check", "How far it scrolled: hScroll and vScroll"
   siPanelRow "Learn", "Learn3", kStageLeft + 22, tTop + 156, 600, "check", "The message scrollbarDrag, as it scrolls"
   siPanelRow "Learn", "Learn4", kStageLeft + 22, tTop + 198, 600, "check", "Scrolling by script, a little at a time"

   siPanel "Steps", lkR(636, tTop, 1000, 616), "How the original was made", "notebook-pen"
   put "File > Import As Control > Image File." & return & \
         "Select the image, then Object > Group Selected." & return & \
         "Object > Object Inspector: check hScrollbar and vScrollbar." & return & \
         "Resize the group as you like: that is its window." into tSteps
   -- (a row as far below the last as the last one's words reach: one of
   -- two lines pushes the next down by a line, so the gaps stay the same;
   -- one line a row, they are level with the rows beside them)
   put tTop + 72 into tRow
   repeat with tIndex = 1 to 4
      siPanelRow "Steps", "Step" & tIndex, 658, tRow, 980, tIndex, line tIndex of tSteps
      if tIndex is 1 then
         put the formattedHeight of field "Step1_text" into tOneLine
      end if
      add 42 + the formattedHeight of field ("Step" & tIndex & "_text") - tOneLine to tRow
   end repeat
end buildFront

-- The painting in its group "Display", as the original's first card has
-- it; a small copy of it to drag in, and the tour
private command buildPainting
   local tObj, tWidth
   go card "The Painting"
   -- the group and its picture, at its natural size (435 by 543): the
   -- group shows 284 by 280 of it, and its scrollbars the rest
   siScroller "Display", lkR(kInLeft, kInTop, kInRight, 424)
   put siPicture("ElGreco.jpg", lkR(kInLeft, kInTop, kInLeft + 435, kInTop + 543), "Display") into tObj
   siScrollerDone "Display", lkR(kInLeft, kInTop, kInRight, 424), 0
   lkShadow the long id of group "Display", 14, 4, 22
   set the script of group "Display" to exScript("The Painting/Display")

   -- the small copy, in a white frame, and the frame of what the window shows
   put lkBox("MapFrame", lkR(kInLeft, 440, kInLeft + 108, 573), "255,255,255", 6, empty) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 10, 2, 14
   put siPicture("Map", lkR(kInLeft + 4, 444, kInLeft + 104, 569), empty) into tObj
   set the script of tObj to exScript("The Painting/Map")
   put lkBox("View", lkR(kInLeft + 4, 444, kInLeft + 4 + 65, 444 + 64), empty, 3, empty) into tObj
   set the style of tObj to "roundrect"
   set the lineSize of tObj to 2
   set the foregroundColor of tObj to "255,255,255"
   lkGlow tObj, sAccent, 6, 255

   put lkLabel("HowTo", lkR(400, 442, kInRight, 500), \
         "Scroll with the scrollbars or the wheel, drag in the small copy, or take a tour.", 13, lkColor("soft"), empty) into tObj
   put exButton("Tour", 400, 504, 34, "Take the tour", "compass", "primary", sAccent, empty, empty, 0) into tWidth
   set the script of group "Tour" to exScript("The Painting/Tour")
   put lkLabel("Stop", lkR(400, 550, kInRight, 568), "Lady in a Fur Wrap", 13, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Credit", lkR(400, 570, kInRight, 586), "El Greco, about 1577 to 1580", 12, lkColor("muted"), empty) into tObj
   siReadouts
end buildPainting

-- The original's second card: a group of a button and a field, which
-- scrolls as the picture does
private command buildControls pFieldA, pButtonText
   local tObj, tLeft, tTop, tWidth
   go card "Controls Scroll Too"
   -- (the original's group is 300 by 300, with its controls where it put
   -- them: the button at 228,4 and the field at 4,212 in the group)
   put kInLeft into tLeft
   put kInTop into tTop
   siScroller "Controls", lkR(tLeft, tTop, tLeft + 300, tTop + 300)
   -- a page under the controls, so that it shows the group scroll
   put lkBox("Page", lkR(tLeft + 4, tTop + 4, tLeft + 404, tTop + 338), lkColor("bg"), 12, "Controls") into tObj
   lkBorder tObj, lkColor("line")
   put lkLabel("Hint", lkR(tLeft + 16, tTop + 16, tLeft + 216, tTop + 110), \
         "This group holds a button and a field. Scroll to the right and down to find them both.", 13, lkColor("soft"), "Controls") into tObj
   create button "Test Button" in group "Controls"
   put it into tObj
   set the style of tObj to "roundrect"
   set the label of tObj to pButtonText
   set the opaque of tObj to true
   set the backgroundColor of tObj to sAccent
   set the borderColor of tObj to sAccent
   set the hiliteColor of tObj to lkMix(sAccent, "0,0,0", 0.2)
   set the textColor of tObj to "255,255,255"
   set the textSize of tObj to 13
   set the textStyle of tObj to "bold"
   set the showFocusBorder of tObj to false
   set the rect of tObj to tLeft + 228, tTop + 4, tLeft + 400, tTop + 34
   set the script of tObj to exScript("Controls Scroll Too/Test Button")
   create field "A" in group "Controls"
   put it into tObj
   set the htmlText of tObj to pFieldA
   set the textSize of tObj to 13
   set the textColor of tObj to lkColor("ink")
   set the opaque of tObj to true
   set the backgroundColor of tObj to "255,255,255"
   set the threeD of tObj to false
   set the showBorder of tObj to true
   set the borderColor of tObj to lkColor("line")
   set the borderWidth of tObj to 1
   set the margins of tObj to 8
   set the vScrollbar of tObj to true
   set the rect of tObj to tLeft + 4, tTop + 212, tLeft + 254, tTop + 334
   siScrollerDone "Controls", lkR(tLeft, tTop, tLeft + 300, tTop + 300), 4
   lkShadow the long id of group "Controls", 14, 4, 22
   set the script of group "Controls" to exScript("Controls Scroll Too/Controls")

   put lkLabel("About", lkR(kInLeft, 440, kInRight, 530), \
         "Anything can go in a group: buttons, fields, images, other groups. With its scrollbars on, " & \
         "the group is a window onto all of them, and the field " & quote & "A" & quote & " has a scrollbar of its own.", \
         13, lkColor("soft"), empty) into tObj
   put exButton("Find the button", kInLeft, 540, 34, "Find the button", "search", "ghost", sAccent, empty, empty, 0) into tWidth
   set the script of group "Find the button" to exScript("Controls Scroll Too/Find the button")
   siReadouts
end buildControls

-- The group's scrollbar properties, on switches that set them
private command buildSettings
   local tObj, tTop
   go card "Scrollbar Settings"
   siScroller "Window", lkR(kInLeft, kInTop, kInRight, 384)
   get siPicture("ElGreco.jpg", lkR(kInLeft, kInTop, kInLeft + 435, kInTop + 543), "Window")
   siScrollerDone "Window", lkR(kInLeft, kInTop, kInRight, 384), 0
   set the scrollbarWidth of group "Window" to 16
   lkShadow the long id of group "Window", 14, 4, 22

   put 400 into tTop
   get lkGroup("Settings", lkR(kInLeft, tTop, kInRight, 518), empty)
   get lkBox("Settings_anchor", lkR(kInLeft, tTop, kInLeft + 1, tTop + 1), empty, 0, "Settings")
   siSwitch "hScrollbar", "Settings", kInLeft, tTop, 424, "hScrollbar"
   siSwitch "vScrollbar", "Settings", 432, tTop, kInRight, "vScrollbar"
   put lkLabel("WidthCaption", lkR(kInLeft, tTop + 48, 380, tTop + 66), "scrollbarWidth", 13, lkColor("soft"), "Settings") into tObj
   siMiddle tObj, tTop + 58
   siChoice "Width 12", "Settings", 384, tTop + 44, 446, tTop + 72, "12"
   siChoice "Width 16", "Settings", 451, tTop + 44, 513, tTop + 72, "16"
   siChoice "Width 20", "Settings", 518, tTop + 44, kInRight, tTop + 72, "20"
   put lkLabel("SizeCaption", lkR(kInLeft, tTop + 86, 380, tTop + 104), "rect (its size)", 13, lkColor("soft"), "Settings") into tObj
   siMiddle tObj, tTop + 96
   siChoice "Size Small", "Settings", 384, tTop + 82, 480, tTop + 110, "Small"
   siChoice "Size Large", "Settings", 484, tTop + 82, kInRight, tTop + 110, "Large"
   delete graphic "Settings_anchor" of group "Settings"
   set the script of group "Settings" to exScript("Scrollbar Settings/Settings")

   -- the line of script the last click ran
   get lkBox("RanBg", lkR(kInLeft, 528, kInRight, kInBottom), lkColor("code"), 12, empty)
   put lkLabel("RanCaption", lkR(kInLeft + 16, 540, kInRight - 16, 554), "THE LINE IT RAN", 10, "100,116,139", empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Ran", lkR(kInLeft + 16, 558, kInRight - 12, 588), \
         "set the vScrollbar of group " & quote & "Window" & quote & " to true", 12, lkColor("codeInk"), empty) into tObj
   -- (the switches show the group as it is, as they will after each click)
   dispatch "showSettings" to group "Settings"
end buildSettings

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Scroll an Image: the demo Scroll Image of OpenXTalk Lite, remastered for OXT-Beyond in 2026
--Scroll Image:
--1) File > Import As Control > Image File.
--2) Select image, Object > Group Selected.
--3) Object > Object Inspector, check: hScrollBar, vScrollBar.
--4) Resize the group as desired.

--Each card's program is in the scripts of the things on it: click one, and the panel beside the
--stage shows its script. The sidebar, the header and that panel are the groups "Frame",
--"Workbench" and "Scripts", which the script of the group "Frame" runs.
@*/

/*@ The Painting/Display
--(added in the remaster) A group gets the
--message scrollbarDrag each time it
--scrolls: when its scrollbars are dragged,
--when the wheel turns, and when a script
--sets its hScroll or vScroll. Here it
--shows where it is: the numbers in the
--header, and the frame on the small copy.

on scrollbarDrag
   local tScale
   --how far it is scrolled to the right,
   --and how far down, in pixels
   put the hScroll of me into field "HValue"
   put the vScroll of me into field "VValue"
   --the small copy's size, to the painting
   put the width of image "Map" / the formattedWidth of image "ElGreco.jpg" into tScale
   set the topLeft of graphic "View" to the left of image "Map" + round(the hScroll of me * tScale), \
         the top of image "Map" + round(the vScroll of me * tScale)
end scrollbarDrag
@*/

/*@ The Painting/Map
--(added in the remaster) The whole
--painting, small: click or drag in it to
--choose what the group "Display" shows.

on mouseDown
   lookAt the mouseH, the mouseV
   --so that the panel beside the stage
   --shows this script
   pass mouseDown
end mouseDown

on mouseMove pX, pY
   if the mouse is down then lookAt pX, pY
end mouseMove

--scrolls the group so that the point pX,pY
--of the small copy is in the middle of its
--window
command lookAt pX, pY
   local tScale, tWide, tHigh
   put the width of me / the formattedWidth of image "ElGreco.jpg" into tScale
   --the window, less its scrollbar
   put the width of group "Display" - the scrollbarWidth of group "Display" into tWide
   put the height of group "Display" - the scrollbarWidth of group "Display" into tHigh
   lock screen
   --(the group keeps them in its range)
   set the hScroll of group "Display" to round((pX - the left of me) / tScale - tWide / 2)
   set the vScroll of group "Display" to round((pY - the top of me) / tScale - tHigh / 2)
   unlock screen
end lookAt
@*/

/*@ The Painting/Tour
--(added in the remaster) A tour of the
--painting: the script scrolls the group
--"Display" from place to place, a little
--at a time, so that its window glides. A
--click during the tour stops it.

local sTouring  --true while the tour is on

on mouseUp
   local tGroup, tCard, tLabel, tCaption, tStops, tStop
   if sTouring is true then
      put false into sTouring  --the tour stops
      exit mouseUp
   end if
   put true into sTouring
   --(long ids: the tour may end on another
   --card)
   put the long id of group "Display" into tGroup
   put the long id of this card into tCard
   put the long id of field "Tour_label" into tLabel
   put the long id of field "Stop" into tCaption
   set the text of tLabel to "Stop the tour"
   --each stop: what is there, and the
   --hScroll and vScroll that show it
   put "Her face,70,20" & return & \
         "Her hands and her ring,95,263" & return & \
         "The fur wrap,0,180" & return & \
         "The dark background,151,0" & return & \
         "Her face again,70,20" into tStops
   repeat for each line tStop in tStops
      set the text of tCaption to item 1 of tStop
      glide tGroup, item 2 of tStop, item 3 of tStop, tCard
      if sTouring is not true or the long id of this card is not tCard then exit repeat
      wait 1 second with messages
      if sTouring is not true or the long id of this card is not tCard then exit repeat
   end repeat
   put false into sTouring
   set the text of tLabel to "Take the tour"
   set the text of tCaption to "Lady in a Fur Wrap"
end mouseUp

--moves the window of pGroup to hScroll pX
--and vScroll pY in 40 small steps: fast at
--first, and slow at the end, as things
--come to rest
private command glide pGroup, pX, pY, pCard
   local tFromX, tFromY, tStep, tT
   put the hScroll of pGroup into tFromX
   put the vScroll of pGroup into tFromY
   repeat with tStep = 1 to 40
      if sTouring is not true or the long id of this card is not pCard then exit repeat
      put 1 - (1 - tStep / 40) ^ 3 into tT
      lock screen
      set the hScroll of pGroup to round(tFromX + (pX - tFromX) * tT)
      set the vScroll of pGroup to round(tFromY + (pY - tFromY) * tT)
      unlock screen
      wait 20 milliseconds with messages
   end repeat
end glide
@*/

/*@ Controls Scroll Too/Controls
--(added in the remaster) This group
--scrolls as the group "Display" on the
--card before does: scrollbarDrag shows
--where it is, in the header.

on scrollbarDrag
   put the hScroll of me into field "HValue"
   put the vScroll of me into field "VValue"
end scrollbarDrag
@*/

/*@ Controls Scroll Too/Test Button
on mouseUp
   answer "Hello, this is a test." with "OK"
end mouseUp
@*/

/*@ Controls Scroll Too/Find the button
--(added in the remaster) Scrolls the group
--until the button is in its window: its
--hScroll goes up by as much as the
--button's right edge is past the window's.

on mouseUp
   local tGroup, tPast
   put the long id of group "Controls" into tGroup
   --(the window ends where the group's
   --vertical scrollbar begins)
   put the right of button "Test Button" + 8 - (the right of tGroup - the scrollbarWidth of tGroup) into tPast
   lock screen
   if tPast > 0 then set the hScroll of tGroup to the hScroll of tGroup + tPast
   set the vScroll of tGroup to 0
   unlock screen
end mouseUp
@*/

/*@ Scrollbar Settings/Settings
--(added in the remaster) Each switch and
--button here sets one property of the
--group "Window", as the Object Inspector
--does, and the line under them is the
--line of script it ran.

on mouseUp
   local tSetting, tProperty, tValue
   --a switch is a group of its parts
   put the short name of the owner of the target into tSetting
   switch tSetting
      case "hScrollbar"
         --on or off: the bottom scrollbar
         put "hScrollbar" into tProperty
         put not the hScrollbar of group "Window" into tValue
         set the hScrollbar of group "Window" to tValue
         break
      case "vScrollbar"
         --on or off: the right scrollbar
         put "vScrollbar" into tProperty
         put not the vScrollbar of group "Window" into tValue
         set the vScrollbar of group "Window" to tValue
         break
      case "Width 12"
      case "Width 16"
      case "Width 20"
         --how thick the scrollbars are
         put "scrollbarWidth" into tProperty
         put word 2 of tSetting into tValue
         set the scrollbarWidth of group "Window" to tValue
         break
      case "Size Small"
         --the window: how much of the
         --painting shows at once
         put "rect" into tProperty
         put "276,124,476,304" into tValue
         set the rect of group "Window" to tValue
         break
      case "Size Large"
         put "rect" into tProperty
         put "276,124,580,384" into tValue
         set the rect of group "Window" to tValue
         break
      default
         exit mouseUp
   end switch
   showSettings
   put "set the" && tProperty && "of group" && quote & "Window" & quote && "to" && tValue into field "Ran"
end mouseUp

--the switches and buttons show the group's
--settings as they are now
command showSettings
   showSwitch "hScrollbar", the hScrollbar of group "Window"
   showSwitch "vScrollbar", the vScrollbar of group "Window"
   showChoice "Width 12", the scrollbarWidth of group "Window" is 12
   showChoice "Width 16", the scrollbarWidth of group "Window" is 16
   showChoice "Width 20", the scrollbarWidth of group "Window" is 20
   showChoice "Size Small", the width of group "Window" < 300
   showChoice "Size Large", the width of group "Window" >= 300
end showSettings

private command showSwitch pName, pOn
   if pOn then
      --on: the track is teal
      set the backgroundColor of graphic (pName & "_track") to "13,148,136"
      set the right of graphic (pName & "_knob") to the right of graphic (pName & "_track") - 2
   else
      --off: it is grey
      set the backgroundColor of graphic (pName & "_track") to "203,213,225"
      set the left of graphic (pName & "_knob") to the left of graphic (pName & "_track") + 2
   end if
end showSwitch

--(cRest is the colour the window gives a
--button when the pointer leaves it, and
--cLit when it is over it)
private command showChoice pName, pChosen
   if pChosen then
      set the cRest of group pName to "13,148,136"
      set the cLit of group pName to "20,184,166"
      set the textColor of field (pName & "_label") to "255,255,255"
   else
      set the cRest of group pName to "255,255,255"
      set the cLit of group pName to "240,250,249"
      set the textColor of field (pName & "_label") to "15,23,42"
   end if
   set the backgroundColor of graphic (pName & "_bg") to the cRest of group pName
end showChoice
@*/
