script "TestInspectorCustomPropsOpenField"
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

-- The Property Inspector's custom properties editor leaves the caret where
-- a click puts it, from HyperXTalk (BerndN, #601). Every editor of the
-- inspector has revInspectorEditorBehavior's "after openField", which
-- selects all of a field's text: a click into a custom property's value
-- selected the whole value, and the next key typed replaced it. The
-- editor's own empty "after openField" (in
-- com.livecode.pi.customprops.behavior) keeps that one from running for
-- it, and only for it. The two handlers are compiled from their files,
-- each as the script of a button, the editor's button behaving as the
-- inspector's, as the editor does in the IDE.

constant kInspector = "/Toolset/palettes/inspector"

on TestSetup
   create stack "TestCustomPropsOpenField"
   set the defaultStack to "TestCustomPropsOpenField"
   create button "inspector"
   set the script of button "inspector" to \
         __Handler("/behaviors/revinspectoreditorbehavior.livecodescript")
   TestAssert "the inspector's handler compiles", the result is empty
   create button "customprops"
   set the script of button "customprops" to \
         __Handler("/editors/com.livecode.pi.customprops.behavior.livecodescript")
   TestAssert "the editor's handler compiles", the result is empty
   set the behavior of button "customprops" to the long id of button "inspector"
   create field "value"
   put "first line" & return & "second line" into field "value"
end TestSetup

on TestTeardown
   if there is a stack "TestCustomPropsOpenField" then
      delete stack "TestCustomPropsOpenField"
   end if
end TestTeardown

on TestOtherEditorsSelectAll
   -- what the inspector's other editors do, as before
   set the defaultStack to "TestCustomPropsOpenField"
   set the behavior of field "value" to the long id of button "inspector"
   focus on field "value"
   TestAssert "a field of another editor has all its text selected", \
         word 1 to 4 of the selectedChunk is "char 1 to 22"
end TestOtherEditorsSelectAll

on TestCustomPropsLeavesTheCaret
   set the defaultStack to "TestCustomPropsOpenField"
   set the behavior of field "value" to the long id of button "customprops"
   focus on field "value"
   TestAssert "the custom property's value is not all selected", \
         word 1 to 4 of the selectedChunk is not "char 1 to 22"
end TestCustomPropsLeavesTheCaret

-- The file's "after openField" handler, alone
private function __Handler pFile
   local tText, tStart, tEnd
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & kInspector & pFile), "UTF-8") into tText
   replace numToChar(13) & numToChar(10) with return in tText
   put offset(return & "after openField" & return, tText) into tStart
   put offset(return & "end openField", tText, tStart) into tEnd
   if tStart is 0 or tEnd is 0 then
      throw "no after openField handler in" && pFile
   end if
   return char tStart + 1 to tStart + tEnd + length("end openField") of tText
end __Handler
