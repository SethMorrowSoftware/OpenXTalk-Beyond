script "CoreEngineLcbArrayKinds"
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

-- Kinds of array across the bridge to LCB (tests/lcs/core/array/kinds.
-- livecodescript has the kinds themselves). A List from LCB comes into
-- script as an array keyed 1 to N, as it always did, now marked as a
-- sequence, at any depth. Into LCB, nothing changes unless a handler sets
-- the handler-local sequencesAsLists to true: then an array marked as a
-- sequence goes in as a List, at any depth, to a handler's parameters, a
-- widget's properties and the state "import widget" gives to OnLoad. That
-- last is what lets a widget whose state holds Lists be copied through
-- script (HyperXTalk issue 447). _array_kinds.lcb describes what arrives:
-- list(...) for a List, array(key:...) for an Array. (A number written in
-- script is text until it is calculated with, so it arrives as a string,
-- as it always did; a number from LCB stays a number.)

on TestSetup
   TestSkipIfNot "lcb"
   TestLoadAuxiliaryExtension "_array_kinds"
   TestLoadAuxiliaryExtension "_widget_array_kinds"
end TestSetup

on TestListsComeBackAsSequences
   local tValue
   put TestArrayKinds_MakeList() into tValue
   TestAssert "a List is an array keyed 1 to N, as before", \
         tValue is an array and the number of elements of tValue is 4
   TestAssert "marked as a sequence", tValue is strictly a sequence
   TestAssert "a List in it too", tValue[2] is strictly a sequence
   TestAssert "an empty List is an empty sequence", \
         tValue[3] is empty and tValue[3] is strictly a sequence
   TestAssert "an Array in it is not marked", tValue[4] is not strictly a sequence
   TestAssert "a List in that Array is", tValue[4]["k"] is strictly a sequence
   put TestArrayKinds_MakeArray() into tValue
   TestAssert "an Array's Lists", tValue["l"] is strictly a sequence
   TestAssert "an Array's empty List", tValue["e"] is strictly a sequence
   TestAssert "an Array inside", tValue["a"] is strictly a dictionary
end TestListsComeBackAsSequences

on TestIntoLcbAsBefore
   -- Without the sequencesAsLists, every array goes in as an Array, as it
   -- did before, marked or not
   TestAssert "a marked sequence to any is an Array", \
         TestArrayKinds_Any([1, 2]) is "array(1:string,2:string)"
   TestAssert "a nested one too", \
         TestArrayKinds_Array({"a": ["x"]}) is "array(a:array(1:string))"
   TestAssert "an array keyed 1 to N to a List is a List, as before", \
         TestArrayKinds_List(__Plain()) is "list(string,string)"
   TestAssert "but what is in it stays an array", \
         TestArrayKinds_List([[1]]) is "list(array(1:string))"
   TestAssert "a List that came back goes in as an Array", \
         TestArrayKinds_Any(TestArrayKinds_MakeList()) begins with "array("
end TestIntoLcbAsBefore

on TestIntoLcbWithSequencesAsLists
   set the sequencesAsLists to true
   TestAssert "a marked sequence to any is a List", \
         TestArrayKinds_Any([1, 2]) is "list(string,string)"
   TestAssert "an empty one is an empty List", TestArrayKinds_Any([]) is "list()"
   TestAssert "a dictionary stays an Array", \
         TestArrayKinds_Any({"1": "a"}) is "array(1:string)"
   TestAssert "an array with no mark stays an Array", \
         TestArrayKinds_Any(__Plain()) is "array(1:string,2:string)"
   TestAssert "an Array parameter is an Array, its sequences Lists", \
         TestArrayKinds_Array({"a": ["x", ["y"]], "b": {"c": [1]}}) is \
         "array(a:list(string,list(string)),b:array(c:list(string)))"
   TestAssert "a List parameter's sequences are Lists", \
         TestArrayKinds_List([[1], {"k": 2}]) is "list(list(string),array(k:string))"
   TestAssert "a List that came back goes in as one again", \
         TestArrayKinds_Any(TestArrayKinds_MakeList()) is \
         "list(number,list(number,number),list(),array(k:list(number)))"
   TestAssert "the handler-local setting does not reach another handler", \
         __AnyFromAnotherHandler([1]) is "array(1:string)"
end TestIntoLcbWithSequencesAsLists

on TestEditedSequences
   local tValue
   set the sequencesAsLists to true
   put [1, 2, 3] into tValue
   put 4 into tValue[4]
   TestAssert "an element added keeps it a List", \
         TestArrayKinds_Any(tValue) is "list(string,string,string,string)"
   delete variable tValue[2]
   TestAssert "a gap makes it an Array", \
         TestArrayKinds_Any(tValue) is "array(1:string,3:string,4:string)"
   TestAssert "as an array takes the mark off", \
         TestArrayKinds_Any([1] as an array) is "array(1:string)"
   TestAssert "as a sequence puts it on", \
         TestArrayKinds_Any(__Plain() as a sequence) is "list(string,string)"
end TestEditedSequences

-- HyperXTalk issue 447: a widget whose state holds Lists, copied through
-- script with export and import
on TestImportWidgetWithLists
   local tState, tWidget
   create stack "ArrayKindsWidgetTest"
   set the defaultStack to "ArrayKindsWidgetTest"
   create widget "Source" as "com.livecode.lcs_tests.core.engine_lcb.widget_array_kinds"
   export widget "Source" to array tState
   TestAssert "the exported state's List is a sequence", \
         tState["$state"]["items"] is strictly a sequence
   TestAssert "a List inside an Array too", \
         tState["$state"]["more"]["nested"] is strictly a sequence

   -- As before: OnLoad gets arrays, and a widget that wants its Lists back
   -- does not load
   import widget from array tState
   put it into tWidget
   TestAssert "without the sequencesAsLists the copy does not load, as before", \
         __LoadedState(tWidget) is not "loaded"

   set the sequencesAsLists to true
   import widget from array tState
   put it into tWidget
   TestAssert "with it the copy loads", __LoadedState(tWidget) is "loaded"
   TestAssert "with its Lists", the loadedItems of tWidget is 2

   delete stack "ArrayKindsWidgetTest"
end TestImportWidgetWithLists

on TestWidgetPropertyWithSequencesAsLists
   local tWidget
   create stack "ArrayKindsWidgetPropertyTest"
   set the defaultStack to "ArrayKindsWidgetPropertyTest"
   create widget "Target" as "com.livecode.lcs_tests.core.engine_lcb.widget_array_kinds"
   put it into tWidget
   set the sequencesAsLists to true
   set the itemsInfo of tWidget to {"a": [1, 2]}
   TestAssert "a property set gets its sequences as Lists", \
         the itemsInfo of tWidget is "array(a:list(string,string))"
   set the sequencesAsLists to false
   set the itemsInfo of tWidget to {"a": [1, 2]}
   TestAssert "and without it arrays, as before", \
         the itemsInfo of tWidget is "array(a:array(1:string,2:string))"
   delete stack "ArrayKindsWidgetPropertyTest"
end TestWidgetPropertyWithSequencesAsLists

----------

private function __Plain
   local tArray
   put "a" into tArray[1]
   put "b" into tArray[2]
   return tArray
end __Plain

private function __AnyFromAnotherHandler pValue
   return TestArrayKinds_Any(pValue)
end __AnyFromAnotherHandler

private function __LoadedState pWidget
   local tState
   try
      put the loadedState of pWidget into tState
   catch tError
      put "error" into tState
   end try
   return tState
end __LoadedState
