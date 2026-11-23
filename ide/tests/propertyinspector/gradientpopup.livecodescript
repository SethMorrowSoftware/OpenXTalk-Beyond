script "TestInspectorGradientPopup"
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

-- OXT-Beyond: the Inspector closed while its Fill gradient popup is open
-- takes the popup with it and takes the gradient's handles off the card.
-- Up to 0.2.8-dp.2, and in LiveCode Community 9.6.3, the popup stayed
-- open with no inspector to report to and the graphic's editMode stayed
-- "fillGradient" (openxtalk.org "Known Bugs"; the fix is OpenXTalkPaul's,
-- p=15278). The popup's own OK is as it was.

constant kStack = "TestInspectorGradient"
constant kPopup = "revPropertyPopup fillGradient"

on TestSetup
   local tGradient
   create stack kStack
   set the defaultStack to kStack
   create graphic "G1"
   set the style of graphic "G1" to "rectangle"
   set the opaque of graphic "G1" to true
   set the rect of graphic "G1" to 40,40,240,200
   put "linear" into tGradient["type"]
   put "0,255,0,0" & return & "1,0,0,255" into tGradient["ramp"]
   put "60,120" into tGradient["from"]
   put "220,120" into tGradient["to"]
   put "60,180" into tGradient["via"]
   set the fillGradient of graphic "G1" to tGradient
end TestSetup

on TestTeardown
   local tInspector
   choose browse tool
   put __Inspector() into tInspector
   if tInspector is not empty then
      set the cLocked of stack tInspector to false
      close stack tInspector
   end if
   if there is a stack kPopup then
      lock messages
      delete stack kPopup
      unlock messages
   end if
   if kStack is among the lines of the mainStacks then
      revIDESetUnedited kStack
      delete stack kStack
   end if
end TestTeardown

private function __Inspector
   local tStack
   repeat for each line tStack in the openStacks
      if tStack begins with "revPropertyInspector" then
         return tStack
      end if
   end repeat
   return empty
end __Inspector

-- The Inspector open on the graphic, at its Colors section, with the Fill
-- gradient popup open as a click on the gradient opens it. Returns the
-- Inspector's name, or empty when the popup could not be opened.
private function __OpenGradientPopup
   local tInspector, tEditor, tIndex, tName
   go stack kStack
   choose pointer tool
   select graphic "G1" of card 1 of stack kStack
   wait 200 milliseconds with messages
   revIDEInspectObjects
   wait 500 milliseconds with messages
   put __Inspector() into tInspector
   if tInspector is empty then return empty
   dispatch "inspectorSectionChanged" to stack tInspector with "Colors"
   wait 500 milliseconds with messages
   repeat with tIndex = 1 to the number of groups of stack tInspector
      put empty into tName
      try
         put the editorProperty["property_name"] of group tIndex of stack tInspector into tName
      end try
      if tName is "fillGradient" then
         put the long id of group tIndex of stack tInspector into tEditor
         exit repeat
      end if
   end repeat
   if tEditor is empty then return empty
   dispatch "editorPopup" to tEditor with "0,0"
   wait 500 milliseconds with messages
   return tInspector
end __OpenGradientPopup

on TestInspectorClosedWithItsGradientPopupOpen
   local tInspector
   put __OpenGradientPopup() into tInspector
   TestAssert "the Fill gradient popup opens", tInspector is not empty and kPopup is among the lines of the openStacks
   TestAssert "the gradient's handles are on the card while it is open", \
         the editMode of graphic "G1" of card 1 of stack kStack is "fillGradient"
   if tInspector is empty then exit TestInspectorClosedWithItsGradientPopupOpen

   close stack tInspector
   wait 500 milliseconds with messages
   TestAssert "the popup closes with its inspector", kPopup is not among the lines of the openStacks
   TestAssert "and is out of memory", there is not a stack kPopup
   TestAssert "the gradient's handles are off the card", \
         the editMode of graphic "G1" of card 1 of stack kStack is "none"
   TestAssert "the gradient is as it was", \
         the fillGradient["type"] of graphic "G1" of card 1 of stack kStack is "linear"
end TestInspectorClosedWithItsGradientPopupOpen

on TestGradientPopupDismissedWithOK
   local tInspector
   put __OpenGradientPopup() into tInspector
   TestAssert "the Fill gradient popup opens", tInspector is not empty and kPopup is among the lines of the openStacks
   if tInspector is empty then exit TestGradientPopupDismissedWithOK

   send "mouseUp" to button "OK" of stack kPopup
   wait 500 milliseconds with messages
   TestAssert "OK closes the popup", kPopup is not among the lines of the openStacks
   TestAssert "and takes the handles off the card", \
         the editMode of graphic "G1" of card 1 of stack kStack is "none"
   TestAssert "the inspector stays open", tInspector is among the lines of the openStacks
end TestGradientPopupDismissedWithOK
