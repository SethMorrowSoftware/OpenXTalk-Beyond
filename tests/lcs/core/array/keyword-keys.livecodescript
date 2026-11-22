script "CoreArrayKeywordKeys"
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

-- A key that is one word of the language which is no expression by itself
-- (from, to, before, after, into, ...) is that word as a literal key, as
-- HyperXTalk reads it (HyperXTalk #608): tArray[from] is tArray["from"].
-- Such keys failed to compile before. Every key that compiled before reads
-- as it did, and every other key that fails to compile fails as it did.

on TestKeywordKeys
   local tArray
   put "a" into tArray[from]
   put "b" into tArray[to]
   put "c" into tArray[before]
   put "d" into tArray[after]
   put "e" into tArray[into]
   TestAssert "from", tArray["from"] is "a"
   TestAssert "to", tArray["to"] is "b"
   TestAssert "before", tArray["before"] is "c"
   TestAssert "after", tArray["after"] is "d"
   TestAssert "into", tArray["into"] is "e"
   TestAssert "read back with the word", tArray[from] & tArray[to] & tArray[before] & tArray[after] & tArray[into] is "abcde"
   TestAssert "five keys", the number of elements of tArray is 5
end TestKeywordKeys

on TestKeywordKeysNested
   local tArray
   put "someone@example.com" into tArray[From][Email]
   put "x" into tArray["to"]["name"]
   TestAssert "two levels", tArray["From"]["Email"] is "someone@example.com"
   TestAssert "two levels, read with the words", tArray[from][email] is "someone@example.com"
   TestAssert "a word, then a quoted key", tArray[to]["name"] is "x"
   TestAssert "a quoted key, then a word", tArray["to"][name] is "x"
end TestKeywordKeysNested

on TestKeywordKeysInStatements
   local tArray, tKeys
   put "1" into tArray[from]
   put "2" after tArray[from]
   TestAssert "put after", tArray[from] is "12"
   add 3 to tArray[to]
   TestAssert "add to", tArray[to] is 3
   TestAssert "is among the keys", "from" is among the keys of tArray
   TestAssert "there is a key", tArray[from] is not empty
   delete variable tArray[from]
   TestAssert "delete variable", not ("from" is among the keys of tArray)
   put tArray[to] + 1 into tKeys
   TestAssert "in an expression", tKeys is 4
   TestAssert "in value()", value("tArray[to]") is 3
   do "put 5 into tArray[before]"
   TestAssert "in do", tArray["before"] is 5
end TestKeywordKeysInStatements

on TestKeywordKeysCase
   local tArray
   put "x" into tArray[FROM]
   TestAssert "the key keeps the word as written", the keys of tArray is "FROM"
   TestAssert "read in any case", tArray[from] is "x"
end TestKeywordKeysCase

-- What scripts saw before stays as it was

on TestKeysThatAlreadyCompiled
   local tArray, tKey, tVar
   put "v" into tKey
   put 1 into tArray[tKey]
   TestAssert "a variable key is its value", tArray["v"] is 1
   put 2 into tArray[empty]
   TestAssert "empty is a constant", tArray[""] is 2
   put 3 into tArray[true]
   TestAssert "true is a constant", tArray["true"] is 3
   get "w"
   put 4 into tArray[it]
   TestAssert "it is a variable", tArray["w"] is 4 and tArray["it"] is empty
   put 5 into tArray[1 + 1]
   TestAssert "an expression", tArray[2] is 5
   put 6 into tArray[undeclaredWord]
   TestAssert "an unquoted word that names no variable", tArray["undeclaredWord"] is 6
end TestKeysThatAlreadyCompiled

on TestKeysThatStillFail
   -- Keys that are not one word fail to compile as before (the errors
   -- themselves are compared with the earlier build's by hand: see the
   -- pull request)
   TestAssert "two words", __CompileError("put 1 into tArray[from to]") is not empty
   TestAssert "an unfinished expression", __CompileError("put 1 into tArray[1 +]") is not empty
   TestAssert "no closing bracket", __CompileError("put 1 into tArray[from") is not empty
   TestAssert "an empty key", __CompileError("put 1 into tArray[]") is not empty
   TestAssert "a word key compiles", __CompileError("put 1 into tArray[from]") is empty
end TestKeysThatStillFail

on TestKeywordKeysWithExplicitVariables
   -- These words can name no variable, so they are keys with
   -- explicitVariables set too, as in HyperXTalk
   TestAssert "a word key with explicit variables", __CompileError("put 1 into tArray[from]", true) is empty
   TestAssert "an unquoted word still fails with explicit variables", __CompileError("put 1 into tArray[undeclaredWord]", true) is not empty
end TestKeywordKeysWithExplicitVariables

-- What setting a new button's script to a handler holding the statement
-- puts in the result: empty when it compiles, its errors otherwise
private function __CompileError pStatement, pExplicit
   local tScript, tResult, tButton, tOldExplicit
   put "on test" & return & "local tArray" & return & pStatement & return & "end test" into tScript
   put the explicitVariables into tOldExplicit
   set the explicitVariables to (pExplicit is true)
   create button
   put it into tButton
   set the script of tButton to tScript
   put the result into tResult
   delete tButton
   set the explicitVariables to tOldExplicit
   return tResult
end __CompileError
