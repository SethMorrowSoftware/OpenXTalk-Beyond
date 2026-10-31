script "CoreFieldUndoTypedReturn"
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

-- Undo takes out a typed return, as it takes out a typed char. A typed
-- return made no undo record, so Undo undid whatever had been recorded
-- before it: nothing, so the return stayed; or text typed just before,
-- leaving the return; or text typed earlier, at an index the return had
-- moved, so the wrong char went (found while fixing p=25422, October
-- 2026; older than rc.6.5). On 0.2.7-rc.6.9 for Linux every test here
-- fails. A return joins the typing it follows, as a typed char does, so
-- Undo takes out the run of typing that holds it.

private function setUpField pText
   create stack "TestStack"
   set the defaultStack to "TestStack"
   create field "Test"
   put pText into field "Test"
   focus on field "Test"
   return the long id of field "Test"
end setUpField

on TestTeardown
   if there is a stack "TestStack" then delete stack "TestStack"
end TestTeardown

on TestUndoReturnTypedFirst
   TestSkipIfNot "wait"
   get setUpField("abc")
   select before char 1 of field "Test"
   type return
   TestAssert "the return is typed first", the text of field "Test" is (return & "abc")
   undo
   TestAssert "undo takes out a return typed first", the text of field "Test" is "abc"
   undo
   TestAssert "a second undo puts the return back", the text of field "Test" is (return & "abc")
end TestUndoReturnTypedFirst

on TestUndoReturnTypedInALine
   TestSkipIfNot "wait"
   get setUpField("abc")
   select after char 2 of field "Test"
   type return
   TestAssert "the return splits the line", the text of field "Test" is ("ab" & return & "c")
   undo
   TestAssert "undo joins the line again", the text of field "Test" is "abc"
end TestUndoReturnTypedInALine

-- Typed text, then a return: Undo takes out both, not the text alone
on TestUndoTextThenReturn
   TestSkipIfNot "wait"
   get setUpField("abc")
   select after char 3 of field "Test"
   type "x"
   type return
   TestAssert "the text and the return are typed", the text of field "Test" is ("abcx" & return)
   undo
   TestAssert "undo takes out the text and the return", the text of field "Test" is "abc"
end TestUndoTextThenReturn

-- A return, then text: Undo takes out both
on TestUndoReturnThenText
   TestSkipIfNot "wait"
   get setUpField("abc")
   select after char 3 of field "Test"
   type return
   type "de"
   TestAssert "the return and the text are typed", the text of field "Test" is ("abc" & return & "de")
   undo
   TestAssert "undo takes out the return and the text", the text of field "Test" is "abc"
end TestUndoReturnThenText

-- Text typed elsewhere before: Undo must not take a char out where that
-- text was, which the return has moved
on TestUndoReturnAfterTypingElsewhere
   TestSkipIfNot "wait"
   get setUpField("abc")
   select after char 3 of field "Test"
   type "x"
   select before char 1 of field "Test"
   type return
   TestAssert "the return is typed first", the text of field "Test" is (return & "abcx")
   undo
   TestAssert "undo takes out the return, not a char", the text of field "Test" is "abcx"
end TestUndoReturnAfterTypingElsewhere

-- Two lines: the return goes in the second, and Undo takes it out there
on TestUndoReturnInSecondLine
   TestSkipIfNot "wait"
   get setUpField("ab" & return & "cd")
   select after char 4 of field "Test"
   type return
   TestAssert "the return splits the second line", the text of field "Test" is ("ab" & return & "c" & return & "d")
   undo
   TestAssert "undo joins the second line again", the text of field "Test" is ("ab" & return & "cd")
end TestUndoReturnInSecondLine
