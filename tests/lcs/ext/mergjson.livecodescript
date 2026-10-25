script "TestMergJSON"
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

-- mergJSON (mergjson/), Monte Goulding's JSON external, built from his
-- source, with its library's JSONToArray and ArrayToJSON, which the IDE
-- loads from Ext/mergJSON as LiveCode's mergExt collection had them.
-- These pin what a script sees from them, so that a stack written for
-- LiveCode's mergJSON gets the same results here: the quirks its
-- documentation describes (mergjson/mergJSON.lcdoc) and the ones it does
-- not, such as the number a value like 007 becomes.

local sLibrary

on TestSetup
   TestSkipIfNot "external", "mergJSON"
   TestLoadExternal "mergJSON"

   -- as the IDE loads it (revInternal__LoadIfLibrary)
   put TestGetEngineRepositoryPath() & "/mergjson/src/mergJSONLibrary.livecodescript" into sLibrary
   send "revLoadLibrary" to stack sLibrary
end TestSetup

private function q pText
   replace "'" with quote in pText
   return pText
end q

on TestExternalFunctions
   local tFunctions
   put the externalFunctions of stack "mergJSON External" into tFunctions
   TestAssert "mergJSONEncode", "mergJSONEncode" is among the lines of tFunctions
   TestAssert "mergJSONDecode", "mergJSONDecode" is among the lines of tFunctions
   TestAssert "the library is in the back scripts", \
         the long id of stack sLibrary is among the lines of the backScripts
end TestExternalFunctions

on TestDecodeObject
   local tA
   put JSONToArray(q("{'s':'text','n':1,'r':1.50,'e':1e3,'t':true,'f':false,'z':null," & \
         "'a':[1,2],'o':{'k':'v'}}")) into tA
   TestAssert "every key", the number of lines of the keys of tA is 9
   TestAssert "a string", tA["s"] is "text"
   TestAssert "an integer", tA["n"] is "1"
   -- numbers keep the text they had in the JSON
   TestAssert "a real keeps its text", tA["r"] is "1.50"
   TestAssert "an exponent keeps its text", tA["e"] is "1e3"
   TestAssert "true", tA["t"] is "true"
   TestAssert "false", tA["f"] is "false"
   TestAssert "null is the word null", tA["z"] is "null"
   TestAssert "an array in an object", tA["a"][2] is "2"
   TestAssert "an object in an object", tA["o"]["k"] is "v"
end TestDecodeObject

on TestDecodeArray
   local tA, tKeys
   put JSONToArray(q("['one',['two','three'],{'k':['four']},5]")) into tA
   put the keys of tA into tKeys
   sort lines of tKeys numeric
   TestAssert "keys 1 to N", tKeys is "1" & return & "2" & return & "3" & return & "4"
   TestAssert "the order", tA[1] is "one" and tA[4] is "5"
   TestAssert "an array in an array", tA[2][1] is "two" and tA[2][2] is "three"
   TestAssert "an array in an object in an array", tA[3]["k"][1] is "four"
end TestDecodeArray

on TestDecodeEmptyAndScalars
   local tA
   TestAssert "an empty object is empty", JSONToArray("{}") is empty
   TestAssert "an empty array is empty", JSONToArray("[]") is empty
   TestAssert "a number", JSONToArray("42") is "42"
   TestAssert "a string", JSONToArray(q("'x'")) is "x"
   TestAssert "true", JSONToArray("true") is "true"
   put JSONToArray(" [ 1 , 2 ] ") into tA
   TestAssert "whitespace around it", tA[2] is "2"
end TestDecodeEmptyAndScalars

on TestDecodeUnicode
   local tA, tE
   put numToCodepoint(233) into tE
   -- an escape, and the same character as UTF-8: JSONToArray takes UTF-8
   put JSONToArray(q("{'escaped':'café'}")) into tA
   TestAssert "an escape", tA["escaped"] is "caf" & tE
   put JSONToArray(textEncode(q("{'raw':'caf" & tE & "'}"), "UTF8")) into tA
   TestAssert "UTF-8", tA["raw"] is "caf" & tE
   put JSONToArray(q("['😀']")) into tA
   TestAssert "a surrogate pair", tA[1] is numToCodepoint(128512)
end TestDecodeUnicode

on TestDecodeError
   local tError
   try
      get JSONToArray(q("{'a':}"))
   catch tError
   end try
   TestAssert "invalid JSON is an error", tError contains "could not decode JSON"
   put empty into tError
   try
      get JSONToArray("[1,")
   catch tError
   end try
   TestAssert "unfinished JSON is an error", tError contains "could not decode JSON"
end TestDecodeError

on TestEncodeArrays
   local tA
   put "three" into tA[3]
   put "one" into tA[1]
   put "two" into tA[2]
   TestAssert "keys 1 to N are a JSON array, in their order", \
         ArrayToJSON(tA) is q("['one','two','three']")
   TestAssert "unless forced to be an object", \
         textDecode(ArrayToJSON(tA, "object"), "UTF8") begins with "{"
   put empty into tA
   put "a" into tA[1]
   put "b" into tA[3]
   TestAssert "a gap makes an object", char 1 of ArrayToJSON(tA) is "{"
   put empty into tA
   put "a" into tA[0]
   put "b" into tA[1]
   TestAssert "a key 0 makes an object", char 1 of ArrayToJSON(tA) is "{"
   put empty into tA
   put "a" into tA["x"][1]
   put "b" into tA["x"][2]
   put "c" into tA["y"]["k"]
   TestAssert "nested arrays", ArrayToJSON(tA, , true) is \
         "{" & return & q("  'x': [") & return & q("    'a',") & return & q("    'b'") & return & \
         "  ]," & return & q("  'y': {") & return & q("    'k': 'c'") & return & "  }" & return & "}"
end TestEncodeArrays

on TestEncodeValues
   local tA
   put 1 into tA["n"]
   put "1.50" into tA["r"]
   put "-2" into tA["m"]
   put "true" into tA["t"]
   put "false" into tA["f"]
   put "null" into tA["z"]
   put "hello" into tA["s"]
   put empty into tA["e"]
   put "-" into tA["d"]
   -- pretty printing sorts the keys, which makes the order known
   TestAssert "numbers, literals and strings", ArrayToJSON(tA, , true) is \
         "{" & return & q("  'd': '-',") & return & q("  'e': '',") & return & \
         q("  'f': false,") & return & q("  'm': -2,") & return & q("  'n': 1,") & return & \
         q("  'r': 1.5,") & return & q("  's': 'hello',") & return & q("  't': true,") & return & \
         q("  'z': null") & return & "}"
   -- text that reads as a number is one (the external reads it with
   -- strtoll and strtod)
   put empty into tA
   put "007" into tA[1]
   put "1e3" into tA[2]
   TestAssert "text that reads as a number", ArrayToJSON(tA) is "[7,1000.0]"
end TestEncodeValues

on TestEncodeScalars
   TestAssert "a string", ArrayToJSON("hello") is q("'hello'")
   TestAssert "a number", ArrayToJSON(42) is "42"
   TestAssert "a number forced to be a string", ArrayToJSON("42", "string") is q("'42'")
   TestAssert "empty", ArrayToJSON(empty) is q("''")
   TestAssert "empty as an object", ArrayToJSON(empty, "object") is "{}"
   TestAssert "empty as an array", ArrayToJSON(empty, "array") is "[]"
end TestEncodeScalars

on TestEncodeBraces
   local tA
   -- the external reads a value that begins with "}" as JSON already
   -- encoded (its quirk 1); ArrayToJSON doubles such a brace, so the
   -- value stays text
   put "}not JSON" into tA["k"]
   TestAssert "a value that begins with a brace", ArrayToJSON(tA) is q("{'k':'}not JSON'}")
   put "}[1,2]" into tA["k"]
   TestAssert "mergJSONEncode reads it as JSON", mergJSONEncode("tA") is q("{'k':[1,2]}")
end TestEncodeBraces

on TestEncodeUnicode
   local tA, tJson, tB
   put "caf" & numToCodepoint(233) into tA["k"]
   put ArrayToJSON(tA) into tJson
   -- ArrayToJSON returns UTF-8
   TestAssert "UTF-8", tJson is textEncode(q("{'k':'caf" & numToCodepoint(233) & "'}"), "UTF8")
   put JSONToArray(tJson) into tB
   TestAssert "it decodes", tB["k"] is tA["k"]
end TestEncodeUnicode

on TestRoundTrip
   local tA, tB, tKeysA, tKeysB
   put "a" into tA["list"][1]
   put "b" into tA["list"][2]
   put "c" into tA["list"][3]["deep"]
   put "line 1" & return & "line 2" & tab & quote into tA["text"]
   put numToCodepoint(8364) & " 12" into tA["euro"]
   put "12.5" into tA["number"]
   put "true" into tA["yes"]
   put JSONToArray(ArrayToJSON(tA)) into tB
   put the keys of tA into tKeysA
   sort lines of tKeysA
   put the keys of tB into tKeysB
   sort lines of tKeysB
   TestAssert "the same keys", tKeysB is tKeysA
   TestAssert "an array", tB["list"][1] is "a" and tB["list"][2] is "b"
   TestAssert "an object in an array", tB["list"][3]["deep"] is "c"
   TestAssert "control characters and quotes", tB["text"] is tA["text"]
   TestAssert "Unicode", tB["euro"] is tA["euro"]
   TestAssert "a number", tB["number"] is "12.5"
   TestAssert "true", tB["yes"] is "true"
end TestRoundTrip

-- The JSONTestSuite cases that the JSON library is checked against
-- (extensions/libraries/json/tests): every "y_" file parses and every
-- "n_" file is refused, except where Jansson, which mergJSON is built
-- on, differs (mergJSON's own tests list the same, tests/broken.json in
-- its repository). The "i_" files may go either way.
constant kDiffers = "y_object_escaped_null_in_key.json,y_string_null_escape.json,y_string_utf16.json,n_object_non_string_key.json,n_object_non_string_key_but_huge_number_instead.json,n_number_then_00.json"

on TestJSONTestSuite
   local tFolder, tFile, tJson, tParsed, tWrong
   put TestGetEngineRepositoryPath() & "/extensions/libraries/json/tests/JSONTestSuite/test_parsing" \
         into tFolder
   repeat for each line tFile in files(tFolder)
      if char 1 to 2 of tFile is not among the items of "y_,n_" then
         next repeat
      end if
      put url ("binfile:" & tFolder & "/" & tFile) into tJson
      try
         get JSONToArray(tJson)
         put true into tParsed
      catch tParsed
         put false into tParsed
      end try
      if tParsed is not (char 1 of tFile is "y") then
         if tFile is not among the items of kDiffers then
            put tFile & comma after tWrong
         end if
      else if tFile is among the items of kDiffers then
         put tFile && "(listed as differing)" & comma after tWrong
      end if
   end repeat
   TestDiagnostic "wrong:" && tWrong
   TestAssert "every case as the suite says", tWrong is empty
end TestJSONTestSuite
