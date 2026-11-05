script "PropertyInspectorRemoveFromMemory"
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

-- OXT-Beyond: the Inspector on a button, after File > Close and Remove From
-- Memory (revIDECloseStack with pDestroy true), which deletes the stack
-- with messages locked. It moves off the button that is gone, as it does
-- when the stack is closed, and brings no saved stack back into memory
-- (openxtalk.org p=25429). A locked Inspector keeps showing what it
-- showed, as before.

constant kStack = "TestInspectorRemove"

local sCloseNoWarn, sFolder

on TestSetup
   -- So that Close and Remove From Memory asks nothing
   put the cCloseNoWarn of stack "revPreferences" into sCloseNoWarn
   set the cCloseNoWarn of stack "revPreferences" to true
   put specialFolderPath("temporary") & slash & "oxt-inspector-remove-" & \
         the milliseconds into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   local tInspector
   set the cCloseNoWarn of stack "revPreferences" to sCloseNoWarn
   choose browse tool
   put __Inspector() into tInspector
   if tInspector is not empty then
      set the cLocked of stack tInspector to false
      close stack tInspector
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

-- The stack kStack with a button B1, saved if pSave is true, with the
-- Inspector open on the button
private command __InspectButton pSave
   create stack kStack
   set the defaultStack to kStack
   create button "B1"
   if pSave then
      save stack kStack as (sFolder & slash & kStack & ".oxtstack")
   end if
   go stack kStack
   choose pointer tool
   select button "B1" of card 1 of stack kStack
   wait 200 milliseconds with messages
   revIDEInspectObjects
   wait 500 milliseconds with messages
   revIDESetUnedited kStack
end __InspectButton

-- The name of the first Inspector open, if any
private function __Inspector
   local tStack
   repeat for each line tStack in the openStacks
      if tStack begins with "revPropertyInspector" then
         return tStack
      end if
   end repeat
   return empty
end __Inspector

private function __InspectedObjects
   local tInspector
   put __Inspector() into tInspector
   if tInspector is empty then
      return "(no Inspector)"
   end if
   return the cSelectedObjects of stack tInspector
end __InspectedObjects

on TestInspectorAfterRemoveFromMemory
   local tButton
   __InspectButton false
   put the long id of button "B1" of card 1 of stack kStack into tButton
   TestAssert "the Inspector shows the button", __InspectedObjects() is tButton

   revIDECloseStack the long id of stack kStack, true
   wait 200 milliseconds with messages
   TestAssert "the stack is removed from memory", kStack is not among the lines of the mainStacks
   TestAssert "the Inspector no longer shows the button that is gone", \
         __InspectedObjects() is not tButton
end TestInspectorAfterRemoveFromMemory

on TestInspectorAfterRemoveSavedFromMemory
   local tButton
   __InspectButton true
   put the long id of button "B1" of card 1 of stack kStack into tButton
   TestAssert "the Inspector shows the button of the saved stack", __InspectedObjects() is tButton

   revIDECloseStack the long id of stack kStack, true
   wait 200 milliseconds with messages
   TestAssert "the saved stack is removed from memory, and not read from its file again", \
         kStack is not among the lines of the mainStacks
   TestAssert "the Inspector no longer shows the button that is gone", \
         __InspectedObjects() is not tButton
end TestInspectorAfterRemoveSavedFromMemory

on TestLockedInspectorAfterRemoveFromMemory
   local tButton
   __InspectButton false
   put the long id of button "B1" of card 1 of stack kStack into tButton
   set the cLocked of stack __Inspector() to true
   wait 200 milliseconds with messages

   revIDECloseStack the long id of stack kStack, true
   wait 200 milliseconds with messages
   TestAssert "the stack is removed from memory", kStack is not among the lines of the mainStacks
   TestAssert "a locked Inspector keeps showing what it showed", \
         __InspectedObjects() is tButton
end TestLockedInspectorAfterRemoveFromMemory

-- OXT-Beyond: the Project Browser, opened once and closed again, still
-- hears ideDestroyStack. For a stack it listed under its name and that was
-- saved since, the long id it was given names the stack's file, it had no
-- row for that, and asking the engine about that long id read the stack
-- from its file again: after File > Close and Remove From Memory the
-- saved stack stayed in memory (found by tools/ci/everyday-tasks on
-- 0.2.7-rc.6.15, with the Stack Inspector open on the stack itself)
private command __ListThenSave pCloseBrowser
   create stack kStack
   set the defaultStack to kStack
   create button "B1"
   go stack kStack
   -- The Project Browser lists the stack under its name, unsaved
   if not revIDEPaletteIsVisible("Project Browser") then
      revIDETogglePalette "Project Browser"
   end if
   wait 500 milliseconds with messages
   TestAssert "the Project Browser opened", revIDEPaletteIsVisible("Project Browser") is true
   if pCloseBrowser then
      revIDETogglePalette "Project Browser"
      wait 200 milliseconds with messages
   end if
   save stack kStack as (sFolder & slash & kStack & ".oxtstack")
   -- The Stack Inspector on the stack itself
   choose pointer tool
   select empty
   revIDEInspectObjects the long id of stack kStack
   wait 500 milliseconds with messages
   revIDESetUnedited kStack
end __ListThenSave

private command __CloseBrowser
   if revIDEPaletteIsVisible("Project Browser") then
      revIDETogglePalette "Project Browser"
   end if
end __CloseBrowser

on TestRemoveSavedFromMemoryAfterProjectBrowserClosed
   __ListThenSave true
   TestAssert "the saved stack is in memory", kStack is among the lines of the mainStacks

   revIDECloseStack the long id of stack kStack, true
   wait 200 milliseconds with messages
   TestAssert "the saved stack is removed from memory, and not read from its file again", \
         kStack is not among the lines of the mainStacks
end TestRemoveSavedFromMemoryAfterProjectBrowserClosed

on TestRemoveSavedFromMemoryWithProjectBrowserOpen
   __ListThenSave false
   TestAssert "the saved stack is in memory", kStack is among the lines of the mainStacks

   revIDECloseStack the long id of stack kStack, true
   wait 500 milliseconds with messages
   TestAssert "the saved stack is removed from memory, and not read from its file again", \
         kStack is not among the lines of the mainStacks
   __CloseBrowser
end TestRemoveSavedFromMemoryWithProjectBrowserOpen
