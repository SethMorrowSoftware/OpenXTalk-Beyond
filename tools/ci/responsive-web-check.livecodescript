script "ResponsiveCheck"
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

-- tools/ci/responsive_web_check.py's eyes in the page: a script-only
-- stack that the check's web standalone of the Responsive Starter carries
-- beside the Mobile Web library. Its javascriptHandlers (set by the
-- standalone's startup script, tools/ci/mobile-web-deploy.livecodescript)
-- let the check read what the Responsive Starter shows (rcState), give
-- the library a safe area as a phone with a notch reports it (rcInsets),
-- and read the stack's script (rcStarterScript). It changes nothing in
-- the Responsive Starter.

constant kStack = "Responsive Starter"

-- What the Responsive Starter shows, a line "name=value" each
function rcState
   local tState, tGrid, i, tTiles, tTile
   put "card=" & the short name of this card of stack kStack & return after tState
   put "rect=" & the rect of stack kStack & return after tState
   put "class=" & mwLayoutClass(kStack) & return after tState
   put "badge=" & field "Badge Text" of stack kStack & return after tState
   put "title=" & field "Title" of stack kStack & return after tState
   put "look=" & the backgroundColor of stack kStack & return after tState
   repeat for each item i in "Nav,Top Bar"
      put rcKey(i) & "=" & the rect of group i of stack kStack & return after tState
      put rcKey(i) & "shown=" & the visible of group i of stack kStack & return after tState
   end repeat
   -- (the details are on Explore and Saved, not on How it works)
   put "detail=" & the rect of group "Detail" of card "Explore" of stack kStack & return after tState
   put "detailshown=" & the visible of group "Detail" of card "Explore" of stack kStack & return after tState
   put "navback=" & the rect of graphic "Nav Back" of stack kStack & return after tState
   put "topback=" & the rect of graphic "Top Back" of stack kStack & return after tState
   put "titlerect=" & the rect of field "Title" of stack kStack & return after tState
   put "navexplore=" & the rect of button "Nav Explore" of stack kStack & return after tState
   put "navguide=" & the rect of button "Nav Guide" of stack kStack & ";" & \
         the label of button "Nav Guide" of stack kStack & return after tState
   put "mark=" & the rect of graphic "Nav Mark" of stack kStack & return after tState
   put "search=" & the visible of group "Search Box" of stack kStack & ";" & the rect of field "Search" of stack kStack & return after tState
   put "brand=" & the visible of field "Brand" of stack kStack & return after tState
   -- (the text on this card: a field of a group on every card shows the
   -- same text on each only when its text is shared)
   put "brandtext=" & field "Brand" of stack kStack & return after tState
   -- the place open, and the pane's or the sheet's controls
   put "place=" & field "Place Name" of group "Detail" of card "Explore" of stack kStack & return after tState
   put "placeshown=" & the visible of field "Place Name" of group "Detail" of card "Explore" of stack kStack & return after tState
   put "close=" & the visible of button "Place Close" of group "Detail" of card "Explore" of stack kStack & ";" & \
         the rect of button "Place Close" of group "Detail" of card "Explore" of stack kStack & return after tState
   put "save=" & the label of button "Place Save" of group "Detail" of card "Explore" of stack kStack & ";" & \
         the rect of button "Place Save" of group "Detail" of card "Explore" of stack kStack & return after tState
   put "photo=" & the rect of graphic "Photo" of group "Detail" of card "Explore" of stack kStack & return after tState
   -- the grids: each card of a place that shows, "number:rect" separated
   -- by ;
   put "grid=" & the rect of group "Grid" of card "Explore" of stack kStack & return after tState
   put "tiles=" & rcTiles("Explore", "Grid") & return after tState
   put "saved=" & rcTiles("Saved", "Saved Grid") & return after tState
   put "tile1back=" & the backgroundColor of graphic "Tile Back" of group "Tile 1" of group "Grid" of \
         card "Explore" of stack kStack & ";" & the rect of graphic "Tile Back" of group "Tile 1" of group "Grid" of \
         card "Explore" of stack kStack & return after tState
   put "tile1name=" & the rect of field "Name" of group "Tile 1" of group "Grid" of card "Explore" of stack kStack & return after tState
   -- the last place in the grid, below the window on a phone: its back
   -- and its blurb laid out within all of it, not only the part that shows
   put "lasttile=" & rcLastTile() & return after tState
   put "try=" & the visible of group "Try" of card "Guide" of stack kStack & return after tState
   put "live=" & rcOneLine(field "Live" of card "Guide" of stack kStack) & return after tState
   put "guide=" & the rect of field "Guide Text" of card "Guide" of stack kStack & return after tState
   put "searchtext=" & field "Search" of card "Explore" of stack kStack after tState
   return tState
end rcState

private function rcKey pName
   replace space with empty in pName
   return toLower(pName)
end rcKey

private function rcTiles pCard, pGrid
   local tList, tGrid, i, tTile
   put the long id of group pGrid of card pCard of stack kStack into tGrid
   repeat with i = 1 to the number of groups of tGrid
      put the long id of group i of tGrid into tTile
      if the short name of tTile begins with "Tile" and the visible of tTile then
         put word 2 of the short name of tTile & ":" & the rect of tTile & ";" after tList
      end if
   end repeat
   delete the last char of tList
   return tList
end rcTiles

private function rcLastTile
   local tGrid, tTile
   put the long id of group "Grid" of card "Explore" of stack kStack into tGrid
   put the long id of group "Tile 8" of tGrid into tTile
   return the rect of tTile & ";" & the rect of graphic "Tile Back" of tTile & ";" & \
         the rect of field "Blurb" of tTile
end rcLastTile

private function rcOneLine pText
   replace return with "|" in pText
   return pText
end rcOneLine

-- The safe area of a phone with a notch, as the browser reports it (the
-- browser here has none to report): the library's own message, with the
-- page's size now and the insets given (top, right, bottom, left). The
-- library lays the stacks mwResponsive started out again for them
command rcInsets pTop, pRight, pBottom, pLeft
   local tSize, tOrient
   do "(document.documentElement.clientWidth || window.innerWidth) + ',' + window.innerHeight" as "JavaScript"
   put the result into tSize
   if item 1 of tSize > item 2 of tSize then
      put "landscape" into tOrient
   else
      put "portrait" into tOrient
   end if
   dispatch "mwFromBrowser" to stack "com.livecode.library.mobileweb" with "viewport", \
         item 1 to 2 of tSize & ",0," & pTop & comma & pRight & comma & pBottom & comma & pLeft & comma & tOrient
end rcInsets

-- The Responsive Starter's own script, to compare with the file it is
-- built from (tools/web-player/responsive-starter-stack.livecodescript)
function rcStarterScript
   return the script of stack kStack
end rcStarterScript
