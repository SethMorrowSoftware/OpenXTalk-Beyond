script "CoreArrayKinds"
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

-- LiveCode 11's kinds of array, and its "as a <kind>" conversions. An array
-- can carry a mark that says it is a sequence or a dictionary: a literal
-- [...] or {...} has one, "as a sequence" and "as a dictionary" give one,
-- "as an array" takes it off, and a List from LCB comes back marked as a
-- sequence (tests/lcs/core/engine-lcb/array-kinds.livecodescript). Only
-- the new checks read it: "is a sequence" and "is a dictionary" ask what
-- an array's keys are, "is strictly a sequence" and "is strictly a
-- dictionary" ask the mark too. Everything that compiled before ignores
-- it, as the tests at the end say.

on TestIsASequence
   local tPlain
   put "a" into tPlain[1]
   put "b" into tPlain[2]
   TestAssert "an array keyed 1 to N is a sequence", tPlain is a sequence
   TestAssert "a literal sequence is a sequence", [1, 2, 3] is a sequence
   TestAssert "an array keyed by name is not", not ({"a": 1} is a sequence)
   TestAssert "is not a sequence", {"a": 1} is not a sequence
   TestAssert "an array keyed 0 to N is not", not (__Keyed("0,1,2") is a sequence)
   TestAssert "an array with a gap is not", not (__Keyed("1,3") is a sequence)
   TestAssert "text is not", not ("1,2,3" is a sequence)
   TestAssert "a number is not", not (1 is a sequence)
   TestAssert "empty text is not", not (empty is a sequence)
   TestAssert "an empty array marked as a sequence is", [] is a sequence
   TestAssert "an empty array marked as a dictionary is not", not ({} is a sequence)
   TestAssert "an array keyed 1 to N marked as a dictionary still is", \
         ({"1": "a", "2": "b"}) is a sequence
end TestIsASequence

on TestIsADictionary
   local tPlain
   put "a" into tPlain[1]
   TestAssert "every array with elements is a dictionary", tPlain is a dictionary
   TestAssert "a literal sequence too", [1, 2] is a dictionary
   TestAssert "an array keyed by name", {"a": 1} is a dictionary
   TestAssert "an empty array marked as a dictionary", {} is a dictionary
   TestAssert "an empty array marked as a sequence, as every sequence is", [] is a dictionary
   TestAssert "an empty array with no mark is not", ([] as an array) is not a dictionary
   TestAssert "text is not", "a" is not a dictionary
   TestAssert "empty text is not", empty is not a dictionary
end TestIsADictionary

on TestIsANumericSequence
   TestAssert "keys from 1", [5, 6] is a numeric sequence
   TestAssert "keys from 0", __Keyed("0,1,2") is a numeric sequence
   TestAssert "from a negative number", __Keyed("-2,-1,0,1") is a numeric sequence
   TestAssert "in any order", __Keyed("4,2,3") is a numeric sequence
   TestAssert "a gap", __Keyed("1,2,4") is not a numeric sequence
   TestAssert "a key that is not a whole number", __Keyed("1,2,x") is not a numeric sequence
   TestAssert "a key 1.5", __Keyed("1,1.5,2") is not a numeric sequence
   TestAssert "text", "abc" is not a numeric sequence
   TestAssert "an empty array marked as a sequence", [] is a numeric sequence
   TestAssert "an empty array marked as a dictionary", {} is not a numeric sequence
end TestIsANumericSequence

on TestIsStrictly
   local tPlain
   put "a" into tPlain[1]
   put "b" into tPlain[2]
   TestAssert "an array keyed 1 to N with no mark is strictly a sequence", \
         tPlain is strictly a sequence
   TestAssert "and not strictly a dictionary", tPlain is not strictly a dictionary
   TestAssert "marked as a dictionary, it is strictly a dictionary", \
         (tPlain as a dictionary) is strictly a dictionary
   TestAssert "and not strictly a sequence", \
         (tPlain as a dictionary) is not strictly a sequence
   TestAssert "a literal sequence", [1] is strictly a sequence
   TestAssert "a literal dictionary keyed 1", {"1": "a"} is strictly a dictionary
   TestAssert "an array keyed by name is strictly a dictionary", \
         __Keyed("a,b") is strictly a dictionary
   TestAssert "[] is strictly a sequence", [] is strictly a sequence
   TestAssert "{} is strictly a dictionary", {} is strictly a dictionary
   TestAssert "empty text is neither", \
         empty is not strictly a sequence and empty is not strictly a dictionary
   TestAssert "text is neither", \
         "x" is not strictly a sequence and "x" is not strictly a dictionary
end TestIsStrictly

on TestTheMarkStays
   local tList, tCopy, tKeyed
   put [1, 2] into tList
   put tList into tCopy
   TestAssert "a copy keeps it", tCopy is strictly a sequence
   put 3 into tCopy[3]
   TestAssert "an element added keeps it", tCopy is strictly a sequence
   TestAssert "the original is as it was", the number of elements of tList is 2
   put {"1": "a"} into tKeyed
   put "b" into tKeyed[2]
   TestAssert "an element added keeps a dictionary's", tKeyed is strictly a dictionary
   put [] into tList["inner"]
   put "x" into tList["inner"][1]
   TestAssert "an array inside an array keeps it", tList["inner"] is strictly a sequence
   delete variable tCopy[2]
   TestAssert "a gap: no longer a sequence", tCopy is not a sequence
   TestAssert "so strictly a dictionary", tCopy is strictly a dictionary
   put 2 into tCopy[2]
   TestAssert "the gap filled: a sequence again", tCopy is strictly a sequence
end TestTheMarkStays

on TestAsAnArray
   local tArray
   put {"1": "a", "2": "b"} as an array into tArray
   TestAssert "takes the mark off", tArray is strictly a sequence
   TestAssert "keeps the elements", tArray[1] is "a" and tArray[2] is "b"
   put [] as an array into tArray
   TestAssert "an empty array has no kind", \
         tArray is not a sequence and tArray is not a dictionary
   -- (an empty array is not "an array", as it was not before: bug 13737)
   TestAssert "and is empty", tArray is empty and tArray is not an array
   put empty as an array into tArray
   TestAssert "empty becomes an empty array with no kind", \
         tArray is empty and tArray is not a sequence and tArray is not a dictionary
   TestAssertThrow "text is not an array", "__AsArray", the long id of me, "EE_AS_NOTARRAY", "abc"
end TestAsAnArray

on TestAsASequence
   local tPlain, tSeq
   put "a" into tPlain[1]
   put "b" into tPlain[2]
   put tPlain as a sequence into tSeq
   TestAssert "an array keyed 1 to N", tSeq is strictly a sequence
   put {"1": "a", "2": "b"} as a sequence into tSeq
   TestAssert "a dictionary keyed 1 to N becomes a sequence", tSeq is strictly a sequence
   put empty as a sequence into tSeq
   TestAssert "empty becomes an empty sequence", tSeq is strictly a sequence and tSeq is empty
   TestAssert "the original keeps its mark", ({"1": "a"}) is strictly a dictionary
   TestAssertThrow "keys by name", "__AsSequence", the long id of me, "EE_AS_NOTSEQUENCE", {"a": 1}
   TestAssertThrow "keys 0 to N", "__AsSequence", the long id of me, "EE_AS_NOTSEQUENCE", __Keyed("0,1")
   TestAssertThrow "text", "__AsSequence", the long id of me, "EE_AS_NOTSEQUENCE", "1,2"
end TestAsASequence

on TestAsADictionary
   local tDict
   put [1, 2] as a dictionary into tDict
   TestAssert "a sequence becomes a dictionary", tDict is strictly a dictionary
   TestAssert "still keyed 1 to N", tDict is a sequence and tDict[2] is 2
   put empty as a dictionary into tDict
   TestAssert "empty becomes an empty dictionary", tDict is strictly a dictionary
   TestAssertThrow "text", "__AsDictionary", the long id of me, "EE_AS_NOTARRAY", "a"
end TestAsADictionary

on TestAsAScalar
   local tValue
   put 1 into tValue
   TestAssert "the literal 1 is not strictly an integer", tValue is not strictly an integer
   put 1 as an integer into tValue
   TestAssert "but 1 as an integer is", tValue is strictly an integer
   put "42" as an integer into tValue
   TestAssert "text that is a whole number", tValue is strictly an integer and tValue is 42
   put "2.0" as an integer into tValue
   TestAssert "text 2.0", tValue is strictly an integer and tValue is 2
   put "1.5" as a number into tValue
   TestAssert "as a number", tValue is strictly a real and tValue + 1 is 2.5
   put 12 as a string into tValue
   TestAssert "as a string", tValue is strictly a string and tValue is "12"
   put "abc" as a name into tValue
   TestAssert "as a name", tValue is "abc"
   put "abc" as a binary string into tValue
   TestAssert "as a binary string", tValue is strictly a binary string
   put "true" as a boolean into tValue
   TestAssert "as a boolean", tValue is strictly a boolean and tValue
   put "FALSE" as a boolean into tValue
   TestAssert "as a boolean in any case", tValue is strictly a boolean and not tValue
   put [] as a string into tValue
   TestAssert "an empty array as a string is empty", tValue is strictly a string and tValue is empty
   TestAssertThrow "an array as a string", "__AsString", the long id of me, "EE_AS_NOTTEXT", [1]
   TestAssertThrow "not a number", "__AsNumber", the long id of me, "EE_AS_NOTNUMBER", "abc"
   TestAssertThrow "not a whole number", "__AsInteger", the long id of me, "EE_AS_NOTINTEGER", 1.5
   TestAssertThrow "too large an integer", "__AsInteger", the long id of me, "EE_AS_NOTINTEGER", 2^40
   TestAssertThrow "not a boolean", "__AsBoolean", the long id of me, "EE_AS_NOTBOOLEAN", "yes"
end TestAsAScalar

on TestAsInExpressions
   local tValue
   -- "as" takes the value just before it, as a function takes its
   -- parameter: 1 + (2 as a string) is 3
   put 1 + 2 as a string into tValue
   TestAssert "binds to the value before it", tValue is 3 and tValue is not strictly a string
   put (1 + 2) as a string into tValue
   TestAssert "brackets for more", tValue is strictly a string
   TestAssert "in a comparison", "5" as a number > 4
   TestAssert "one after another", ([1] as a dictionary as an array) is strictly a sequence
   put {"k": [1]} into tValue
   TestAssert "after an element", (tValue["k"] as a dictionary) is strictly a dictionary
   TestAssert "the element keeps its own mark", tValue["k"] is strictly a sequence
   TestAssert "in a function's parameters", __Id([1] as a dictionary) is strictly a dictionary
   TestAssert "in value()", value("[1, 2] as a dictionary") is strictly a dictionary
   do "put [3] as a dictionary into tValue"
   TestAssert "in do", tValue is strictly a dictionary
end TestAsInExpressions

-- What compiled before compiles as it did. "sequence", "dictionary",
-- "numeric" and "as" are no keywords.
on TestNamesAsBefore
   local sequence, dictionary, numeric, tValue
   put 1 into sequence
   put 2 into dictionary
   put 3 into numeric
   TestAssert "variables named sequence, dictionary and numeric", \
         sequence + dictionary + numeric is 6
   put sequence into tValue[sequence]
   TestAssert "and as keys", tValue[1] is 1
   TestAssert "a handler named sequence", sequence() is "the handler"
   TestAssert "is a number is as it was", sequence is a number
end TestNamesAsBefore

function sequence
   return "the handler"
end sequence

on TestSequencesAsListsProperty
   TestAssert "the sequencesAsLists is false when a handler starts", \
         the sequencesAsLists is false
   set the sequencesAsLists to true
   TestAssert "it can be set", the sequencesAsLists
   TestAssert "and is the handler's own", __SequencesAsListsOfAnotherHandler() is false
   TestAssert "still set here", the sequencesAsLists
   set the sequencesAsLists to false
   TestAssert "it can be cleared", not the sequencesAsLists
   TestAssertThrow "only true or false", "__SetSequencesAsLists", the long id of me, empty, "maybe"
end TestSequencesAsListsProperty

on TestSequencesAsListsCustomPropertyAsBefore
   local tButton
   create button "OXTArrayKindsProbe"
   put it into tButton
   set the sequencesAsLists of tButton to "mine"
   TestAssert "the sequencesAsLists of an object is its custom property", \
         the sequencesAsLists of tButton is "mine"
   TestAssert "and the handler-local one is apart from it", the sequencesAsLists is false
   delete tButton
end TestSequencesAsListsCustomPropertyAsBefore

-- Marks are invisible to what compiled before
on TestMarksIgnoredAsBefore
   local tPlain
   put "a" into tPlain[1]
   put "b" into tPlain[2]
   TestAssert "a marked array is equal to an unmarked one", ["a", "b"] is tPlain
   TestAssert "a sequence and a dictionary with the same elements are equal", \
         ({"1": "a", "2": "b"}) = ["a", "b"]
   TestAssert "an empty array of either kind is empty", [] is empty and {} is empty
   TestAssert "an empty array of either kind is not an array, as before (bug 13737)", \
         [] is not an array and {} is not an array
   TestAssert "one with elements is", [1] is an array and {"a": 1} is an array
   TestAssert "arrayEncode does not hold the mark", \
         arrayEncode(["a", "b"]) is arrayEncode(tPlain)
   TestAssert "arrayDecode gives no mark", \
         arrayDecode(arrayEncode({"1": "a", "2": "b"})) is strictly a sequence
end TestMarksIgnoredAsBefore

-- The words compile only as the new syntax; a handler that compiled
-- before compiles as it did
on TestCompileErrors
   TestAssert "is a sequence compiles", __CompileError("get tX is a sequence") is empty
   TestAssert "is strictly a dictionary compiles", __CompileError("get tX is strictly a dictionary") is empty
   TestAssert "as a sequence compiles", __CompileError("get tX as a sequence") is empty
   TestAssert "as a kind that is not one is an error", __CompileError("get tX as a widget") is not empty
   TestAssert "is a kind that is not one is an error", __CompileError("get tX is a widgetkind") is not empty
   TestAssert "is strictly a numeric sequence is an error", \
         __CompileError("get tX is strictly a numeric sequence") is not empty
end TestCompileErrors

----------

private function __Keyed pKeys
   local tArray
   repeat for each item tKey in pKeys
      put tKey into tArray[tKey]
   end repeat
   return tArray
end __Keyed

private function __Id pValue
   return pValue
end __Id

on __AsArray pValue
   get pValue as an array
end __AsArray

on __AsSequence pValue
   get pValue as a sequence
end __AsSequence

on __AsDictionary pValue
   get pValue as a dictionary
end __AsDictionary

on __AsString pValue
   get pValue as a string
end __AsString

on __AsNumber pValue
   get pValue as a number
end __AsNumber

on __AsInteger pValue
   get pValue as an integer
end __AsInteger

on __AsBoolean pValue
   get pValue as a boolean
end __AsBoolean

on __SetSequencesAsLists pValue
   set the sequencesAsLists to pValue
end __SetSequencesAsLists

private function __SequencesAsListsOfAnotherHandler
   return the sequencesAsLists
end __SequencesAsListsOfAnotherHandler

-- The error a handler holding pLines gives as it compiles (its first
-- line: the code, line and column), or empty
private function __CompileError pLines
   local tButton, tError
   lock messages
   create button "OXTArrayKindsCompileProbe"
   put it into tButton
   set the script of tButton to "on probe" & return & "local tX" & return & pLines & return & "end probe"
   put line 1 of the result into tError
   delete tButton
   unlock messages
   return tError
end __CompileError
