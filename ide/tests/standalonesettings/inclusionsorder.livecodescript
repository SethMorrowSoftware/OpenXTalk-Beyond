script "StandaloneSettingsInclusionsOrder"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

-- OXT-Beyond: the Standalone Settings' Inclusions pane lists its rows in
-- the order of their titles, the same every run. They followed the order
-- the extensions were loaded in (revSBAvailableInclusions collects them
-- with `repeat for each`), so Palette Actions came first in one run and
-- Clock in another. What the pane saves does not depend on the order.

-- (not the name of this script's own stack, which a test cannot delete)
constant kStack = "OXTInclusionsOrderProbe"

local sFolder

on TestSetup
   start using stack "revSBLibrary"
   put specialFolderPath("temporary") & slash & "oxt-inclusions-order-" & \
         the milliseconds into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   if there is a stack "revStandaloneSettings" then
      close stack "revStandaloneSettings"
   end if
   if kStack is among the lines of the mainStacks then
      revIDESetUnedited kStack
      delete stack kStack
   end if
   if there is a file (sFolder & slash & kStack & ".oxtstack") then
      delete file (sFolder & slash & kStack & ".oxtstack")
   end if
   delete folder sFolder
end TestTeardown

-- The titles of pInclusions, in the order of their keys 1 to N
private function __Titles pInclusions
   local tTitles
   repeat with i = 1 to the number of elements in pInclusions
      put pInclusions[i]["title"] & return after tTitles
   end repeat
   delete the last char of tTitles
   return tTitles
end __Titles

on TestInclusionsByTitleOrder
   local tIn, tOut
   put "Zip" into tIn[1]["title"]
   put "library" into tIn[1]["type"]
   put "clock" into tIn[2]["title"]
   put "widget" into tIn[2]["type"]
   put "Browser" into tIn[3]["title"]
   put "widget" into tIn[3]["type"]
   put "Clock" into tIn[4]["title"]
   put "library" into tIn[4]["type"]
   put "x.y.extra" into tIn[4]["id"]
   put revSBInclusionsByTitle(tIn) into tOut
   TestAssert "four inclusions in, four out", the number of elements in tOut is 4
   TestAssert "titles in alphabetical order, ignoring case, then by type", \
         __Titles(tOut) is "Browser" & return & "Clock" & return & "clock" & return & "Zip"
   TestAssert "an element keeps its keys", tOut[2]["id"] is "x.y.extra"
   TestAssert "an empty array gives an empty array", \
         the number of elements in revSBInclusionsByTitle(empty) is 0
end TestInclusionsByTitleOrder

on TestInclusionsByTitleKeepsEveryInclusion
   local tAll, tSorted, tExpected, tGot
   put revSBAvailableInclusions() into tAll
   put revSBInclusionsByTitle(tAll) into tSorted
   TestAssert "every available inclusion is kept", \
         the number of elements in tSorted is the number of elements in tAll
   put __Titles(tAll) into tExpected
   sort lines of tExpected
   put __Titles(tSorted) into tGot
   TestDiagnostic tGot
   TestAssert "the available inclusions come out in the order of their titles", \
         tGot is tExpected
end TestInclusionsByTitleKeepsEveryInclusion

on TestInclusionsPaneOrder
   local tCard, tCount, tData, tStyle, tTitles, tSortedTitles, tAll, tWidget, tHilited
   -- a widget the stack includes, whose row must be the one ticked
   put revSBAvailableInclusions() into tAll
   repeat with i = 1 to the number of elements in tAll
      if tAll[i]["type"] is "widget" then
         put tAll[i] into tWidget
         exit repeat
      end if
   end repeat
   create stack kStack
   set the cRevStandaloneSettings["extensions"] of stack kStack to tWidget["id"]
   -- (the Standalone Settings ask to save a stack that has no file)
   save stack kStack as (sFolder & slash & kStack & ".oxtstack")
   revIDEStandaloneSettingsForStack the long id of stack kStack
   wait 500 milliseconds with messages
   TestAssert "the Standalone Settings are open", there is a stack "revStandaloneSettings"
   dispatch "navigateToCard" to stack "revStandaloneSettings" with "Inclusions"
   wait 500 milliseconds with messages
   put the long id of card "Inclusions" of stack "revStandaloneSettings" into tCard
   dispatch function "NumberOfRows" to tCard
   put the result into tCount
   TestAssert "the Inclusions pane lists rows", tCount > 0
   repeat with i = 1 to tCount
      put empty into tData
      dispatch "DataForRow" to tCard with i, tData, tStyle
      put tData["title"] & return after tTitles
   end repeat
   delete the last char of tTitles
   put tTitles into tSortedTitles
   sort lines of tSortedTitles
   TestDiagnostic tTitles
   TestAssert "the Inclusions pane lists its rows in the order of their titles", \
         tTitles is tSortedTitles and tTitles is not empty

   -- the stack's widget is ticked on its own row, wherever that row is
   -- (a new stack's settings tick a few other inclusions too)
   local tTicked, tTickedTitles
   put false into tTicked
   put the dvHilitedRows[true] of group "extensionList" of tCard into tHilited
   repeat for each item tRow in tHilited
      put empty into tData
      dispatch "DataForRow" to tCard with tRow, tData, tStyle
      put tData["title"] & comma after tTickedTitles
      if tData["id"] is tWidget["id"] then put true into tTicked
   end repeat
   TestDiagnostic "ticked:" && tTickedTitles && "widget:" && tWidget["id"]
   TestAssert "the row of the widget the stack includes is ticked", \
         tWidget["id"] is not empty and tTicked
end TestInclusionsPaneOrder

-- The ticked rows are drawn in the hilite colour under a name and icon in
-- revIDEColor("text_1"), white in the dark appearance. There the edition's
-- light selection colour (240,200,180) left them unreadable: it is
-- darkened, keeping its hue; in the light appearance it is as it was
on TestInclusionsHiliteColor
   local tCard, tLight, tDark, tSum, tExpected, tSelected
   create stack kStack
   save stack kStack as (sFolder & slash & kStack & ".oxtstack")
   revIDEStandaloneSettingsForStack the long id of stack kStack
   wait 500 milliseconds with messages
   TestAssert "the Standalone Settings are open", there is a stack "revStandaloneSettings"
   dispatch "navigateToCard" to stack "revStandaloneSettings" with "Inclusions"
   wait 500 milliseconds with messages
   put the long id of card "Inclusions" of stack "revStandaloneSettings" into tCard
   put "240,200,180" into tLight
   dispatch function "inclusionsHiliteColor" to tCard with tLight, false
   TestAssert "the light appearance keeps the selection colour", the result is tLight
   dispatch function "inclusionsHiliteColor" to tCard with tLight, true
   put the result into tDark
   TestDiagnostic "dark:" && tDark
   TestAssert "the dark appearance darkens the selection colour", tDark is "72,60,54"
   put item 1 of tDark + item 2 of tDark + item 3 of tDark into tSum
   -- white text on it, and apart from the dark rows (126 and 97)
   TestAssert "white is readable on the dark selection colour", 255 - tSum / 3 > 150
   TestAssert "the dark rows and the dark selection colour differ", 97 - tSum / 3 > 25
   dispatch function "inclusionsHiliteColor" to tCard with "red", true
   TestAssert "a colour name is left as it is", the result is "red"

   -- and the pane uses it, in the appearance the test runs in
   dispatch function "ideColorGet" to tCard with "pb_line_selected"
   put the result into tSelected
   TestDiagnostic "selection colour:" && tSelected && "appearance:" && the systemAppearance
   dispatch function "inclusionsHiliteColor" to tCard with \
         tSelected, the systemAppearance is "dark"
   put the result into tExpected
   TestAssert "the pane's hilite colour follows the appearance", \
         the viewProp["hilite color"] of group "extensionList" of tCard is tExpected
end TestInclusionsHiliteColor
