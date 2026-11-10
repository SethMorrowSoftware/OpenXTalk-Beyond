script "ResponsiveStarterBuilder"
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

-- Builds stacks/Responsive Starter.oxtstack, the stack to copy for one
-- stack that fits a phone, a tablet and a desktop, with the Mobile Web
-- library (extensions/script-libraries/mobileweb). The stack is never
-- edited by hand: change this script and
-- responsive-starter-stack.livecodescript, and build it again, with any
-- OXT-Beyond engine (the IDE's, or the development engine of a build):
--
--    <engine> -ui tools/web-player/responsive-starter.livecodescript
--
-- OXT_RESPONSIVE_STARTER names another file to write. It prints "BUILT
-- <file>" or "FAILED <why>".
--
-- What it is: a small app of places to go, on three cards (Explore, Saved
-- and "How it works"), laid out three ways:
--   phone    (under 600 wide)  a tab bar at the bottom, one column of
--                              places, a place's details as a sheet over
--                              them
--   tablet   (600 to 1023)     a rail at the left, two columns, the
--                              details in a pane at the right
--   desktop  (1024 and over)   a sidebar, three columns, the details in a
--                              pane; hovering, and keys 1 to 3 and /
-- The layouts are rules, kept on the controls in their mwLayout custom
-- property sets and set here (see setRules), which the library follows;
-- the stack's script does only what changes with the layout. The stack is
-- saved laid out for a desktop, so that it also opens as one where the
-- library is not.

constant kWidth = 1240
constant kHeight = 780
constant kTabs = "Explore,Saved,Guide"
constant kPlaces = 8

on startup
   local tFile, tError
   put $OXT_RESPONSIVE_STARTER into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/Responsive Starter.oxtstack" into the last item of tFile
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
   local tName, tLibrary, i
   put "Responsive Starter" into tName
   if there is a stack tName then
      delete stack tName
   end if
   -- the library, to lay the stack out once before it is saved
   put the effective filename of me into tLibrary
   set the itemDelimiter to slash
   put "../../extensions/script-libraries/mobileweb/mobileweb.livecodescript" into the last item of tLibrary
   set the itemDelimiter to comma
   start using stack tLibrary

   create invisible stack tName
   set the defaultStack to tName
   set the rect of stack tName to 100, 60, 100 + kWidth, 60 + kHeight
   set the minWidth of stack tName to 320
   set the minHeight of stack tName to 460
   set the resizable of stack tName to true
   set the textFont of stack tName to empty
   set the textSize of stack tName to 15
   set the script of stack tName to stackScript()
   if the result is not empty then
      throw "the stack's script does not compile:" && the result
   end if

   set the name of card 1 to "Explore"
   buildNav
   buildTopBar
   buildGrid "Grid"
   buildDetail
   -- the fields of the groups every card shares show the same text on
   -- each (a background's field keeps a text for each card otherwise, and
   -- the cards made next would show none)
   shareText the long id of group "Nav"
   shareText the long id of group "Top Bar"
   shareText the long id of group "Detail"
   -- and the places' fields, so that a place copied to the Saved card
   -- takes its name and its words with it (a field's text is kept for
   -- the card it is on otherwise, and the copy would show none)
   repeat with i = 1 to kPlaces
      shareText the long id of group ("Tile" && i) of group "Grid"
   end repeat

   -- (a new card gets the groups that behave as backgrounds)
   create card "Saved"
   buildSavedGrid
   relayer group "Detail" of card "Saved" to front of card "Saved"
   create card "Guide"
   remove group "Detail" from card "Guide"
   buildGuide
   go card "Explore"

   -- laid out for its size now, in the light look
   send "rsTheme" && quote & "light" & quote to stack tName
   mwApplyLayout tName
   if the result is not empty then
      throw "the rules:" && the result
   end if
   send "rsAfterLayout" to stack tName

   -- (made invisible while it is built; it opens visible)
   set the visible of stack tName to true
   save stack tName as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
   stop using stack tLibrary
end buildStack

-- A control's rules: pRules is lines of "<key>=<rule>", the key "phone",
-- "tablet", "desktop", any of them with " portrait" or " landscape", or
-- "all"
private command setRules pObject, pRules
   local tLine, tKey
   set the itemDelimiter to "="
   repeat for each line tLine in pRules
      put item 1 of tLine into tKey
      set the mwLayout[tKey] of pObject to item 2 of tLine
   end repeat
   set the itemDelimiter to comma
end setRules

-- The same rule for the three classes
private function allRule pRule
   return "all=" & pRule
end allRule

private function threeRules pPhone, pTablet, pDesktop
   return "phone=" & pPhone & return & "tablet=" & pTablet & return & "desktop=" & pDesktop
end threeRules

-- A filled shape, its colour by its role (rsTheme): pStyle rectangle or
-- roundrect
private command setShape pObject, pStyle, pRole, pRadius
   set the style of pObject to pStyle
   set the opaque of pObject to true
   set the lineSize of pObject to 0
   set the showBorder of pObject to false
   if pRadius is a number then
      set the roundRadius of pObject to pRadius
   end if
   set the uRole of pObject to pRole
end setShape

-- A field that is a label: locked, no frame, no focus
private command setLabel pField, pText, pSize, pRole, pStyle
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to false
   set the vScrollbar of pField to false
   set the textSize of pField to pSize
   set the textStyle of pField to pStyle
   set the text of pField to pText
   set the uRole of pField to pRole
end setLabel

-- A flat button with rounded corners: pFill the role of its colour
-- (empty for none), pRole its words'
private command setButton pButton, pLabel, pFill, pRole
   set the showBorder of pButton to false
   set the threeD of pButton to false
   set the showFocusBorder of pButton to false
   set the traversalOn of pButton to false
   set the autoHilite of pButton to false
   if pFill is empty then
      set the style of pButton to "transparent"
      set the opaque of pButton to false
   else
      set the style of pButton to "roundrect"
      set the opaque of pButton to true
      set the borderWidth of pButton to 0
      set the uFill of pButton to pFill
   end if
   set the textStyle of pButton to "bold"
   set the label of pButton to pLabel
   set the uRole of pButton to pRole
end setButton

-- A group with no frame, that keeps the rect it is given
private command setPlain pGroup
   set the lockLoc of pGroup to true
   set the showBorder of pGroup to false
   set the margins of pGroup to 0
end setPlain

private command shareText pGroup
   local i
   repeat with i = 1 to the number of fields of pGroup
      set the sharedText of field i of pGroup to true
   end repeat
end shareText

-- The navigation: a tab bar at the bottom on a phone, a rail on a tablet,
-- a sidebar on a desktop. Its own rules, and its controls' within it
private command buildNav
   local tGroup, i, tTab, tTop
   create group "Nav"
   put the long id of group "Nav" into tGroup
   setPlain tGroup
   setRules tGroup, threeRules("left 0, right 0, bottom 0, height 64, bleed", \
         "left 0, top 0, bottom 0, width 88, bleed", \
         "left 0, top 0, bottom 0, width 232, bleed")
   create graphic "Nav Back" in tGroup
   setShape the long id of graphic "Nav Back" of tGroup, "rectangle", "surface"
   setRules the long id of graphic "Nav Back" of tGroup, allRule("within, left 0, top 0, right 0, bottom 0, bleed")
   create graphic "Nav Line" in tGroup
   setShape the long id of graphic "Nav Line" of tGroup, "rectangle", "line"
   setRules the long id of graphic "Nav Line" of tGroup, \
         threeRules("within, left 0, right 0, top 0, height 1, bleed", \
         "within, right 0, top 0, bottom 0, width 1, bleed", \
         "within, right 0, top 0, bottom 0, width 1, bleed")
   create field "Brand" in tGroup
   setLabel the long id of field "Brand" of tGroup, "Places", 22, "text", "bold"
   setRules the long id of field "Brand" of tGroup, threeRules("hidden", "hidden", \
         "within, left 24, right 16, top 20, height 36")
   -- the mark under the card's tab: placed by the stack's script
   create graphic "Nav Mark" in tGroup
   setShape the long id of graphic "Nav Mark" of tGroup, "roundrect", "accentSoft", 12
   put 0 into i
   repeat for each item tTab in kTabs
      create button ("Nav" && tTab) in tGroup
      if tTab is "Guide" then
         setButton the long id of button ("Nav" && tTab) of tGroup, "How it works", empty, "quiet"
      else
         setButton the long id of button ("Nav" && tTab) of tGroup, tTab, empty, "quiet"
      end if
      set the textSize of button ("Nav" && tTab) of tGroup to 14
      set the margins of button ("Nav" && tTab) of tGroup to 16
      set the script of button ("Nav" && tTab) of tGroup to "on mouseUp" & return & \
            "   rsGoTab" && quote & tTab & quote & return & "end mouseUp"
      switch i
         case 0
            put "within, left 0, width 33%, top 0, bottom 0" into tTop
            break
         case 1
            put "within, left 33%, width 34%, top 0, bottom 0" into tTop
            break
         default
            put "within, left 67%, right 0, top 0, bottom 0" into tTop
            break
      end switch
      setRules the long id of button ("Nav" && tTab) of tGroup, \
            threeRules(tTop, "within, left 4, right 4, top" && 72 + i * 64 & ", height 56", \
            "within, left 12, right 12, top" && 84 + i * 52 & ", height 44")
      add 1 to i
   end repeat
   create field "Nav Tip" in tGroup
   setLabel the long id of field "Nav Tip" of tGroup, \
         "Make the window narrower: under 1024 pixels this is a tablet's layout, and under 600 a phone's.", \
         13, "quiet", "plain"
   setRules the long id of field "Nav Tip" of tGroup, threeRules("hidden", "hidden", \
         "within, left 24, right 20, bottom 24, height 96")
   set the backgroundBehavior of tGroup to true
end buildNav

-- The bar at the top: the card's title, what the layout is (a badge), a
-- search and the look. On a phone the search and the badge are a second
-- row
private command buildTopBar
   local tGroup, tBadge, tBox
   create group "Top Bar"
   put the long id of group "Top Bar" into tGroup
   setPlain tGroup
   setRules tGroup, threeRules("left 0, right 0, top 0, height 108, bleed", \
         "left 88, right 0, top 0, height 60, bleed", \
         "left 232, right 0, top 0, height 68, bleed")
   create graphic "Top Back" in tGroup
   setShape the long id of graphic "Top Back" of tGroup, "rectangle", "page"
   setRules the long id of graphic "Top Back" of tGroup, allRule("within, left 0, top 0, right 0, bottom 0, bleed")
   create graphic "Top Line" in tGroup
   setShape the long id of graphic "Top Line" of tGroup, "rectangle", "line"
   setRules the long id of graphic "Top Line" of tGroup, allRule("within, left 0, right 0, bottom 0, height 1")
   create field "Title" in tGroup
   setLabel the long id of field "Title" of tGroup, "Explore", 26, "text", "bold"
   set the dontWrap of field "Title" of tGroup to true
   setRules the long id of field "Title" of tGroup, threeRules("within, left 12, right 84, top 10, height 38", \
         "within, left 20, top 11, width 186, height 38", \
         "within, left 28, top 14, width 206, height 40")

   create group "Badge" in tGroup
   put the long id of group "Badge" of tGroup into tBadge
   setPlain tBadge
   setRules tBadge, threeRules("within, right 12, top 68, width 160, height 28", \
         "within, left 212, top 16, width 176, height 28", \
         "within, left 240, top 20, width 210, height 28")
   create graphic "Badge Back" in tBadge
   setShape the long id of graphic "Badge Back" of tBadge, "roundrect", "accentSoft", 28
   setRules the long id of graphic "Badge Back" of tBadge, allRule("within, left 0, top 0, right 0, bottom 0")
   create field "Badge Text" in tBadge
   setLabel the long id of field "Badge Text" of tBadge, "desktop · landscape · mouse", 12, "accent", "bold"
   set the textAlign of field "Badge Text" of tBadge to "center"
   set the dontWrap of field "Badge Text" of tBadge to true
   set the margins of field "Badge Text" of tBadge to "4,5,4,0"
   setRules the long id of field "Badge Text" of tBadge, allRule("within, left 0, top 0, right 0, bottom 0")

   -- the search: a rounded box, the hint in it while it is empty, and
   -- the field over them (with no box of its own)
   create group "Search Box" in tGroup
   put the long id of group "Search Box" of tGroup into tBox
   setPlain tBox
   setRules tBox, threeRules("within, left 12, right 184, top 62, height 40", \
         "within, right 80, top 12, width 180, height 36", \
         "within, right 88, top 16, width 260, height 36")
   create graphic "Search Back" in tBox
   setShape the long id of graphic "Search Back" of tBox, "roundrect", "surface", 12
   set the lineSize of graphic "Search Back" of tBox to 1
   set the uEdge of graphic "Search Back" of tBox to "line"
   setRules the long id of graphic "Search Back" of tBox, allRule("within, left 0, top 0, right 0, bottom 0")
   create field "Search Hint" in tBox
   setLabel the long id of field "Search Hint" of tBox, "Search places", 15, "quiet", "plain"
   set the dontWrap of field "Search Hint" of tBox to true
   set the margins of field "Search Hint" of tBox to "12,8,8,0"
   setRules the long id of field "Search Hint" of tBox, allRule("within, left 0, top 0, right 0, bottom 0")
   create field "Search" in tBox
   set the lockText of field "Search" of tBox to false
   set the traversalOn of field "Search" of tBox to false
   set the opaque of field "Search" of tBox to false
   set the showBorder of field "Search" of tBox to false
   set the threeD of field "Search" of tBox to false
   set the showFocusBorder of field "Search" of tBox to false
   set the dontWrap of field "Search" of tBox to true
   set the textSize of field "Search" of tBox to 15
   set the margins of field "Search" of tBox to "12,8,8,0"
   set the uRole of field "Search" of tBox to "text"
   set the toolTip of field "Search" of tBox to "Search the places (press / on a desktop)"
   set the script of field "Search" of tBox to "on textChanged" & return & "   rsFilter" & return & \
         "   pass textChanged" & return & "end textChanged"
   setRules the long id of field "Search" of tBox, allRule("within, left 0, top 0, right 0, bottom 0")

   create button "Theme" in tGroup
   setButton the long id of button "Theme" of tGroup, "Dark", "surface", "text"
   set the textSize of button "Theme" of tGroup to 13
   set the script of button "Theme" of tGroup to "on mouseUp" & return & "   rsToggleTheme" & return & "end mouseUp"
   setRules the long id of button "Theme" of tGroup, threeRules("within, right 12, top 12, width 64, height 34", \
         "within, right 12, top 12, width 60, height 36", \
         "within, right 16, top 16, width 64, height 36")
   set the backgroundBehavior of tGroup to true
end buildTopBar

-- A grid of the places: one column on a phone, two on a tablet, three on
-- a desktop ("flow"), each a card that lays itself out within itself
private command buildGrid pName
   local tGrid, i, tTile, tInfo
   create group pName
   put the long id of group pName into tGrid
   setPlain tGrid
   setGridRules tGrid
   repeat with i = 1 to kPlaces
      put the long id of group pName into tGrid
      create group ("Tile" && i) in tGrid
      put the long id of group ("Tile" && i) of tGrid into tTile
      setPlain tTile
      set the rect of tTile to 0, 0, 300, 96
      -- a row on a phone; on a tablet or a desktop, where a column is
      -- narrow, a card with a band of colour on top (its height is a rule
      -- too: the grid keeps each card's height)
      setRules tTile, threeRules("height 96", "height 156", "height 156")
      set the script of tTile to tileScript()
      put placeInfo(i) into tInfo
      set the itemDelimiter to "|"
      create graphic "Tile Back" in tTile
      setShape the long id of graphic "Tile Back" of tTile, "roundrect", "surface", 18
      set the lineSize of graphic "Tile Back" of tTile to 1
      set the uEdge of graphic "Tile Back" of tTile to "line"
      setRules the long id of graphic "Tile Back" of tTile, allRule("within, left 0, top 0, right 0, bottom 0")
      create graphic "Swatch" in tTile
      setShape the long id of graphic "Swatch" of tTile, "roundrect", empty, 16
      set the backgroundColor of graphic "Swatch" of tTile to item 3 of tInfo
      setRules the long id of graphic "Swatch" of tTile, threeRules("within, left 16, top 18, width 60, height 60", \
            "within, left 10, right 10, top 10, height 58", "within, left 10, right 10, top 10, height 58")
      create field "Initial" in tTile
      setLabel the long id of field "Initial" of tTile, char 1 of item 1 of tInfo, 26, empty, "bold"
      set the textColor of field "Initial" of tTile to "#FFFFFF"
      set the textAlign of field "Initial" of tTile to "center"
      set the topMargin of field "Initial" of tTile to 14
      setRules the long id of field "Initial" of tTile, threeRules("within, left 16, top 18, width 60, height 60", \
            "within, left 10, right 10, top 10, height 58", "within, left 10, right 10, top 10, height 58")
      create field "Name" in tTile
      setLabel the long id of field "Name" of tTile, item 1 of tInfo, 17, "text", "bold"
      set the dontWrap of field "Name" of tTile to true
      setRules the long id of field "Name" of tTile, threeRules("within, left 88, right 12, top 14, height 28", \
            "within, left 12, right 10, top 74, height 28", "within, left 12, right 10, top 74, height 28")
      create field "Blurb" in tTile
      setLabel the long id of field "Blurb" of tTile, item 2 of tInfo, 14, "quiet", "plain"
      setRules the long id of field "Blurb" of tTile, threeRules("within, left 88, right 12, top 42, bottom 6", \
            "within, left 12, right 10, top 102, bottom 6", "within, left 12, right 10, top 102, bottom 6")
      set the itemDelimiter to comma
   end repeat
end buildGrid

private command setGridRules pGrid
   setRules pGrid, threeRules("left 0, right 0, top 108, bottom 64, flow 1, gap 12", \
         "left 88, right 40%, top 60, bottom 0, flow 2, gap 14", \
         "left 232, right 340, top 68, bottom 0, flow 3, gap 16")
end setGridRules

private function tileScript
   return "on mouseDown" & return & "   rsTileDown the long id of me" & return & "end mouseDown" & return & \
         "on mouseUp" & return & "   rsTileUp the long id of me" & return & "end mouseUp" & return & \
         "on mouseEnter" & return & "   rsHover the long id of me, true" & return & "end mouseEnter" & return & \
         "on mouseLeave" & return & "   rsHover the long id of me, false" & return & "end mouseLeave"
end tileScript

-- A place's details: a pane at the right on a tablet or a desktop, a
-- sheet over everything on a phone (shown by the stack's script while a
-- place is open). On a tablet on its side (a phone on its side, mostly),
-- where there is little height, the picture is small
private command buildDetail
   local tGroup, tName
   create group "Detail"
   put the long id of group "Detail" into tGroup
   setPlain tGroup
   setRules tGroup, threeRules("left 0, right 0, top 0, bottom 0, bleed", \
         "right 0, width 40%, top 60, bottom 0, bleed", \
         "right 0, width 340, top 68, bottom 0, bleed")
   create graphic "Detail Back" in tGroup
   setShape the long id of graphic "Detail Back" of tGroup, "rectangle", "surface"
   setRules the long id of graphic "Detail Back" of tGroup, allRule("within, left 0, top 0, right 0, bottom 0, bleed")
   create graphic "Detail Line" in tGroup
   setShape the long id of graphic "Detail Line" of tGroup, "rectangle", "line"
   setRules the long id of graphic "Detail Line" of tGroup, threeRules("hidden", \
         "within, left 0, top 0, bottom 0, width 1, bleed", "within, left 0, top 0, bottom 0, width 1, bleed")
   create button "Place Close" in tGroup
   setButton the long id of button "Place Close" of tGroup, "Close", "accentSoft", "accent"
   set the script of button "Place Close" of tGroup to "on mouseUp" & return & "   rsCloseSheet" & return & "end mouseUp"
   setRules the long id of button "Place Close" of tGroup, threeRules("within, left 16, top 10, width 90, height 40", \
         "hidden", "hidden")

   create graphic "Photo" in tGroup
   setShape the long id of graphic "Photo" of tGroup, "roundrect", empty, 22
   create field "Photo Letter" in tGroup
   setLabel the long id of field "Photo Letter" of tGroup, empty, 64, empty, "bold"
   set the textColor of field "Photo Letter" of tGroup to "#FFFFFF"
   set the textAlign of field "Photo Letter" of tGroup to "center"
   repeat for each item tName in "Photo,Photo Letter"
      setRules the long id of control tName of tGroup, \
            threeRules("within, left 16, right 16, top 60, height 200", \
            "within, left 20, right 20, top 20, height 150", \
            "within, left 24, right 24, top 24, height 190") & return & \
            "tablet landscape=within, left 20, width 72, top 16, height 72"
   end repeat
   -- (the letter in the middle of the picture, whatever its height)
   set the topMargin of field "Photo Letter" of tGroup to 40

   create field "Place Name" in tGroup
   setLabel the long id of field "Place Name" of tGroup, empty, 24, "text", "bold"
   set the dontWrap of field "Place Name" of tGroup to true
   setRules the long id of field "Place Name" of tGroup, \
         threeRules("within, left 16, right 16, top 272, height 36", \
         "within, left 20, right 20, top 182, height 36", \
         "within, left 24, right 24, top 226, height 36") & return & \
         "tablet landscape=within, left 106, right 20, top 18, height 34"
   create field "Place Facts" in tGroup
   setLabel the long id of field "Place Facts" of tGroup, empty, 14, "quiet", "plain"
   setRules the long id of field "Place Facts" of tGroup, \
         threeRules("within, left 16, right 16, top 310, height 26", \
         "within, left 20, right 20, top 218, height 26", \
         "within, left 24, right 24, top 264, height 26") & return & \
         "tablet landscape=within, left 106, right 20, top 54, height 24"
   create field "Place Text" in tGroup
   setLabel the long id of field "Place Text" of tGroup, empty, 16, "text", "plain"
   setRules the long id of field "Place Text" of tGroup, \
         threeRules("within, left 16, right 16, top 344, bottom 80", \
         "within, left 20, right 20, top 250, bottom 70", \
         "within, left 24, right 24, top 300, bottom 80") & return & \
         "tablet landscape=within, left 20, right 20, top 100, bottom 66"
   create button "Place Save" in tGroup
   setButton the long id of button "Place Save" of tGroup, "Save this place", "accent", empty
   set the textColor of button "Place Save" of tGroup to "#FFFFFF"
   set the textSize of button "Place Save" of tGroup to 15
   set the script of button "Place Save" of tGroup to "on mouseUp" & return & "   rsToggleSave" & return & "end mouseUp"
   setRules the long id of button "Place Save" of tGroup, \
         threeRules("within, left 16, right 16, bottom 16, height 48", \
         "within, left 20, right 20, bottom 14, height 44", \
         "within, left 24, right 24, bottom 24, height 44") & return & \
         "tablet landscape=within, left 20, right 20, bottom 12, height 44"
   create field "Detail Hint" in tGroup
   setLabel the long id of field "Detail Hint" of tGroup, \
         "Pick a place to see it here." & return & "On a phone, it opens over the list.", 16, "quiet", "plain"
   set the textAlign of field "Detail Hint" of tGroup to "center"
   setRules the long id of field "Detail Hint" of tGroup, allRule("within, left 24, right 24, top 38%, height 60")
   set the backgroundBehavior of tGroup to true
end buildDetail

-- The Saved card: the same grid, filled by the stack's script, and what
-- it says while it is empty
private command buildSavedGrid
   local tGrid
   create group "Saved Grid"
   put the long id of group "Saved Grid" into tGrid
   setPlain tGrid
   setGridRules tGrid
   create field "Saved Empty"
   setLabel the long id of field "Saved Empty", \
         "Nothing saved yet. Open a place and press" && quote & "Save this place" & quote & \
         ", and it is kept here.", 16, "quiet", "plain"
   setRules the long id of field "Saved Empty", threeRules("left 24, right 24, top 140, height 80", \
         "left 112, right 42%, top 100, height 80", "left 264, right 372, top 108, height 80")
end buildSavedGrid

-- How it works: the stack's own story, the layout now and the rules
-- followed (filled by the stack's script), and on a desktop, buttons
-- that make the window a phone's, a tablet's or a desktop's
private command buildGuide
   local tGroup, tTry, tName, i, tRule
   create group "Guide"
   put the long id of group "Guide" into tGroup
   setPlain tGroup
   setRules tGroup, threeRules("left 0, right 0, top 108, bottom 64", \
         "left 88, right 0, top 60, bottom 0", "left 232, right 0, top 68, bottom 0")
   create field "Guide Text" in tGroup
   setLabel the long id of field "Guide Text" of tGroup, empty, 15, "text", "plain"
   set the htmlText of field "Guide Text" of tGroup to guideText()
   setRules the long id of field "Guide Text" of tGroup, \
         threeRules("within, left 16, right 16, top 12, bottom 250", \
         "within, left 24, right 52%, top 16, bottom 16", \
         "within, left 32, right 50%, top 24, bottom 24")
   create field "Live Title" in tGroup
   setLabel the long id of field "Live Title" of tGroup, "Right now", 13, "accent", "bold"
   setRules the long id of field "Live Title" of tGroup, \
         threeRules("within, left 16, right 16, bottom 204, height 26", \
         "within, left 50%, right 24, top 16, height 26", \
         "within, left 52%, right 32, top 24, height 26")
   create field "Live" in tGroup
   setLabel the long id of field "Live" of tGroup, empty, 13, "text", "plain"
   set the opaque of field "Live" of tGroup to true
   set the showBorder of field "Live" of tGroup to true
   set the borderWidth of field "Live" of tGroup to 1
   set the margins of field "Live" of tGroup to 12
   set the uFill of field "Live" of tGroup to "surface"
   setRules the long id of field "Live" of tGroup, \
         threeRules("within, left 16, right 16, bottom 60, height 140", \
         "within, left 50%, right 24, top 46, bottom 72", \
         "within, left 52%, right 32, top 54, bottom 84")

   create group "Try" in tGroup
   put the long id of group "Try" of tGroup into tTry
   setPlain tTry
   setRules tTry, threeRules("within, left 16, right 16, bottom 10, height 40", \
         "within, left 50%, right 24, bottom 16, height 44", \
         "within, left 52%, right 32, bottom 24, height 44")
   put 0 into i
   repeat for each item tName in "Phone,Tablet,Desktop"
      create button ("Try" && tName) in tTry
      setButton the long id of button ("Try" && tName) of tTry, "As a" && toLower(tName), "accentSoft", "accent"
      set the textSize of button ("Try" && tName) of tTry to 13
      set the script of button ("Try" && tName) of tTry to "on mouseUp" & return & \
            "   rsTrySize" && quote & toLower(tName) & quote & return & "end mouseUp"
      switch i
         case 0
            put "within, left 0, width 32%, top 0, bottom 0" into tRule
            break
         case 1
            put "within, left 34%, width 32%, top 0, bottom 0" into tRule
            break
         default
            put "within, right 0, width 32%, top 0, bottom 0" into tRule
            break
      end switch
      setRules the long id of button ("Try" && tName) of tTry, allRule(tRule)
      add 1 to i
   end repeat
end buildGuide

private function guideText
   local tHtml
   put "<p><b>One stack, every screen.</b></p>" & \
         "<p>This stack lays itself out for a phone, a tablet or a desktop. Make the window narrower " & \
         "or wider, or turn your phone, and watch the badge at the top change.</p><p></p>" & \
         "<p><b>1. Two lines when it opens</b></p>" & \
         "<p>In preOpenStack, <font color=" & quote & "#4F46E5" & quote & ">mwStart</font> fills a phone's " & \
         "screen, and <font color=" & quote & "#4F46E5" & quote & ">mwResponsive</font> lays the stack out " & \
         "for its size, now and each time it changes.</p><p></p>" & \
         "<p><b>2. Rules on the controls</b></p>" & \
         "<p>Each control says where it goes in its mwLayout custom properties: one rule for a phone, one " & \
         "for a tablet, one for a desktop. The bar of tabs is a tab bar on a phone, a rail on a tablet and " & \
         "a sidebar on a desktop, from three rules and no code:</p>" & \
         "<p><font color=" & quote & "#4F46E5" & quote & ">set the mwLayout[" & quote & "phone" & quote & \
         "] of group " & quote & "Nav" & quote & " to " & quote & "left 0, right 0, bottom 0, height 64" & \
         quote & "</font></p><p></p>" & \
         "<p><b>3. Grids that reflow</b></p>" & \
         "<p>The rule " & quote & "flow 3" & quote & " sets the places out in three columns on a desktop; " & \
         "on a tablet the rule says two, and on a phone one. Each place lays out its own controls " & \
         quote & "within" & quote & " itself.</p><p></p>" & \
         "<p><b>4. layoutChanged for the rest</b></p>" & \
         "<p>When the stack crosses from one layout to another, its card gets layoutChanged. This stack " & \
         "uses it to show a place beside the grid on a big screen, and over it on a phone.</p><p></p>" & \
         "<p><b>Make it yours</b></p>" & \
         "<p>Save a copy, then change the places and the rules. The guide " & quote & \
         "Stacks for Every Screen" & quote & " in the Dictionary tells the whole story.</p>" into tHtml
   return tHtml
end guideText

-- The places: name|what it is|colour (as the stack's script has them)
private function placeInfo pNumber
   switch pNumber
      case 1
         return "Kyoto|Temples, gardens and quiet lanes|#F97316"
      case 2
         return "Reykjavik|Hot springs under the northern lights|#0EA5E9"
      case 3
         return "Lisbon|Trams, tiles and sunset viewpoints|#EAB308"
      case 4
         return "Patagonia|Glaciers and granite towers|#14B8A6"
      case 5
         return "Marrakesh|Souks, spice and riad courtyards|#EF4444"
      case 6
         return "Banff|Turquoise lakes in the Rockies|#22C55E"
      case 7
         return "Hanoi|Street food and lantern-lit streets|#A855F7"
      case 8
         return "Cape Town|Table Mountain and two oceans|#3B82F6"
   end switch
end placeInfo

-- The stack's script: responsive-starter-stack.livecodescript beside
-- this file, without its first line (a script-only stack's header, there
-- so that editors and checkers read it as xTalk)
private function stackScript
   local tFile, tScript
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "responsive-starter-stack.livecodescript" into the last item of tFile
   set the itemDelimiter to comma
   open file tFile for "UTF-8" text read
   if the result is not empty then
      throw "cannot read" && tFile & ":" && the result
   end if
   read from file tFile until end
   put it into tScript
   close file tFile
   delete line 1 of tScript
   return tScript
end stackScript
