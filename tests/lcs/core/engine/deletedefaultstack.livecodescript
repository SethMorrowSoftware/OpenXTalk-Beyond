script "CoreEngineDeleteDefaultStack"
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

/*
Deleting the default stack when no stack window is open (an engine run
with -ui, so no top stack) left the engine with no default stack, and the
next use of it crashed (an access violation on Windows, found building
the Beyond Sampler with -ui). The default stack now falls back to the home
stack when there is no top stack. Where a stack window is open, the top
stack is still the one chosen, as before; the IDE's own tests cover that.
*/

private function _DeleteDefaultRun pArgs
   local tFile, tStack, tOutput
   put specialFolderPath("temporary") & "/oxt-delete-default-stack.txt" into tFile
   if there is a file tFile then delete file tFile
   put the effective filename of me into tStack
   set the itemDelimiter to slash
   put "_deletedefaultstack.livecodescript" into item -1 of tStack
   TestRunStack "-ui", tStack, pArgs
   put the result into tOutput
   TestDiagnostic "engine result:" && tOutput
   if there is a file tFile then
      put url ("file:" & tFile) into tOutput
      delete file tFile
   else
      put empty into tOutput
   end if
   TestDiagnostic "child wrote:" && tOutput
   return tOutput
end _DeleteDefaultRun

on TestDeleteDefaultStackWithNoTopStack
   TestSkipIfNot "shell"
   if the environment is "server" then
      TestSkip "delete the default stack", "the server engine runs no stacks with -ui"
      exit TestDeleteDefaultStackWithNoTopStack
   end if

   local tOut
   put _DeleteDefaultRun("") into tOut
   TestAssert "set the defaultStack, delete it: the engine goes on", tOut is not empty
   TestAssert "the default stack is then a stack that exists", line 2 of tOut is "true"
   -- (the defaultStack gives the stack's name, `stack "..."`)
   TestAssert "the default stack is then the home stack", line 1 of tOut is line 3 of tOut
end TestDeleteDefaultStackWithNoTopStack

on TestDeleteGoneToStackWithNoTopStack
   TestSkipIfNot "shell"
   if the environment is "server" then
      TestSkip "delete the stack gone to", "the server engine runs no stacks with -ui"
      exit TestDeleteGoneToStackWithNoTopStack
   end if

   local tOut
   put _DeleteDefaultRun("go") into tOut
   TestAssert "go stack, delete it: the engine goes on", tOut is not empty
   TestAssert "the default stack is then a stack that exists", line 2 of tOut is "true"
end TestDeleteGoneToStackWithNoTopStack
