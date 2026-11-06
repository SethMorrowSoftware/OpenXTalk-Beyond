script "TestResponsiveStarter"
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

-- The Responsive Starter's Saved card (tools/web-player/stacks), as it is
-- committed, on a desktop engine: places saved one after another and
-- unsaved, each with its name and its words on the Saved card, laid out
-- by the library's rules, found by the search, and laid out again for a
-- phone; and the same without the library, as in an engine older than
-- the library's layouts (bwmilby's forum report, November 2026: a second
-- place saved stopped with "can't find background", and the saved places
-- showed no names). tools/ci/responsive_web_check.py checks it in a
-- browser.

constant kStarter = "Responsive Starter"

local sLib, sPath

on TestSetup
   put TestGetEngineRepositoryPath() & "/extensions/script-libraries/mobileweb/mobileweb.livecodescript" into sLib
   put TestGetEngineRepositoryPath() & "/tools/web-player/stacks/Responsive Starter.oxtstack" into sPath
end TestSetup

on TestTearDown
   if there is a stack kStarter then
      delete stack kStarter
   end if
   if "com.livecode.library.mobileweb" is among the lines of the stacksInUse then
      stop using stack "com.livecode.library.mobileweb"
   end if
end TestTearDown

private command _Open pWithLibrary
   if pWithLibrary then
      start using stack sLib
   end if
   go invisible stack sPath
   set the rect of stack kStarter to 0, 0, 1240, 780
end _Open

private command _Save pPlace
   send "rsPick" && pPlace to stack kStarter
   send "rsToggleSave" to stack kStarter
end _Save

-- "number:name" of each place on the Saved card, in its order, and
-- whether each shows
private function _Saved
   local tGrid, tList, i
   put the long id of group "Saved Grid" of card "Saved" of stack kStarter into tGrid
   repeat with i = 1 to the number of groups of tGrid
      if the short name of group i of tGrid begins with "Tile" then
         put word 2 of the short name of group i of tGrid & ":" & \
               field "Name" of group i of tGrid & "," after tList
      end if
   end repeat
   delete the last char of tList
   return tList
end _Saved

private function _SavedTile pNumber
   return the long id of group ("Tile" && pNumber) of group "Saved Grid" of card "Saved" of stack kStarter
end _SavedTile

private function _ExploreTile pNumber
   return the long id of group ("Tile" && pNumber) of group "Grid" of card "Explore" of stack kStarter
end _ExploreTile

on TestSaveOnePlaceThenAnother
   _Open true
   _Save 1
   TestAssert "one place saved, with its name", _Saved() is "1:Kyoto"
   _Save 3
   TestAssert "a second place saved, with its name", _Saved() is "1:Kyoto,3:Lisbon"
   _Save 5
   TestAssert "a third", _Saved() is "1:Kyoto,3:Lisbon,5:Marrakesh"
   TestAssert "the place's button says it is saved", \
         the label of button "Place Save" of group "Detail" of card "Explore" of stack kStarter is "Saved"
end TestSaveOnePlaceThenAnother

on TestSavedPlacesKeepTheirWords
   local tTile
   _Open true
   _Save 2
   put _SavedTile(2) into tTile
   TestAssert "the blurb", field "Blurb" of tTile is field "Blurb" of _ExploreTile(2)
   TestAssert "the letter", field "Initial" of tTile is "R"
end TestSavedPlacesKeepTheirWords

on TestUnsave
   _Open true
   _Save 1
   _Save 3
   _Save 3
   TestAssert "unsaved, the place goes", _Saved() is "1:Kyoto"
   TestAssert "and its button says it can be saved", \
         the label of button "Place Save" of group "Detail" of card "Explore" of stack kStarter is "Save this place"
   _Save 3
   TestAssert "saved again, it comes back after the others", _Saved() is "1:Kyoto,3:Lisbon"
   _Save 1
   _Save 3
   TestAssert "all unsaved: none", _Saved() is empty
   send "rsGoTab Saved" to stack kStarter
   TestAssert "and the Saved card says so", the visible of field "Saved Empty" of card "Saved" of stack kStarter
end TestUnsave

on TestSavedPlacesAreLaidOut
   _Open true
   _Save 1
   _Save 3
   _Save 5
   TestAssert "a desktop: three in a row, where the first three of Explore are", \
         the rect of _SavedTile(1) is the rect of _ExploreTile(1) and \
         the rect of _SavedTile(3) is the rect of _ExploreTile(2) and \
         the rect of _SavedTile(5) is the rect of _ExploreTile(3)
   set the rect of stack kStarter to 0, 0, 390, 780
   TestAssert "a phone: one column", \
         item 1 of the rect of _SavedTile(1) is item 1 of the rect of _SavedTile(3) and \
         item 2 of the rect of _SavedTile(3) > item 4 of the rect of _SavedTile(1)
   TestAssert "a phone: still with their names", _Saved() is "1:Kyoto,3:Lisbon,5:Marrakesh"
   TestAssert "a phone: the back is the whole place", \
         the rect of graphic "Tile Back" of _SavedTile(5) is the rect of _SavedTile(5)
end TestSavedPlacesAreLaidOut

on TestTheSearchFindsSavedPlaces
   _Open true
   _Save 1
   _Save 3
   put "lis" into field "Search" of card "Explore" of stack kStarter
   send "rsFilter" to stack kStarter
   TestAssert "the search hides the saved places that do not match", \
         not the visible of _SavedTile(1) and the visible of _SavedTile(3)
   put empty into field "Search" of card "Explore" of stack kStarter
   send "rsFilter" to stack kStarter
   TestAssert "an empty search shows them all", the visible of _SavedTile(1) and the visible of _SavedTile(3)
end TestTheSearchFindsSavedPlaces

on TestSaveWithoutTheLibrary
   _Open false
   TestAssert "the badge says there is no library", \
         field "Badge Text" of card "Explore" of stack kStarter begins with "fixed layout"
   _Save 1
   _Save 3
   _Save 5
   TestAssert "the places are saved, with their names", _Saved() is "1:Kyoto,3:Lisbon,5:Marrakesh"
   TestAssert "in the first places of the grid, one after the other", \
         the topLeft of _SavedTile(1) is the topLeft of _ExploreTile(1) and \
         the topLeft of _SavedTile(3) is the topLeft of _ExploreTile(2) and \
         the topLeft of _SavedTile(5) is the topLeft of _ExploreTile(3)
   _Save 1
   TestAssert "unsaved, the others move up", \
         the topLeft of _SavedTile(3) is the topLeft of _ExploreTile(1) and _Saved() is "3:Lisbon,5:Marrakesh"
end TestSaveWithoutTheLibrary
