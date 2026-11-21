script "TestJsonCodecLib"
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
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.
*/

on TestSetup
   local tLibFilename
   put TestGetEngineRepositoryPath() & \
         "/extensions/script-libraries/jsoncodec/jsoncodec.livecodescript" \
         into tLibFilename
   start using stack tLibFilename
end TestSetup

-- JSON is written here with ' for ", so that it can be read.
private function q pText
   replace "'" with quote in pText
   return pText
end q

-- A JSON \u escape. (Written out, one could be taken for the character
-- it names by a tool that edits this file.)
private function u pHex
   return "\" & "u" & pHex
end u

-- The text of what pHandler throws for pJSON, or empty when it throws
-- nothing.
private function decodeError pJSON
   local tError
   try
      get jsonDecode(pJSON)
   catch tError
      return tError
   end try
   return empty
end decodeError

-- A value written out on one line with its keys sorted, so that two values
-- can be compared as text. Keys that differ only in case are different
-- keys, and a line break in a key or a value cannot move it in the sort.
private function dump pValue
   local tOut, tElement
   set the caseSensitive to true
   if pValue is not an array then
      return "<" & oneLine(pValue) & ">"
   end if
   repeat for each key tKey in pValue
      put pValue[tKey] into tElement
      put "(" & oneLine(tKey) & ")=" & dump(tElement) & return after tOut
   end repeat
   delete the last char of tOut
   sort lines of tOut ascending text
   replace return with ";" in tOut
   return "{" & tOut & "}"
end dump

private function oneLine pText
   replace "\" with "\\" in pText
   replace return with "\n" in pText
   return pText
end oneLine

--------------------------------------------------------------------------------
-- Decoding
--------------------------------------------------------------------------------

on TestDecodeScalars
   TestAssert "a number", jsonDecode("42") is "42"
   TestAssert "a number keeps how it was written", jsonDecode("1.50") is "1.50" and \
         the number of chars of jsonDecode("1.50") is 4
   TestAssert "a long integer keeps its digits", \
         jsonDecode("123456789012345678901234567890") is "123456789012345678901234567890"
   TestAssert "a decoded number calculates", jsonDecode("2.50") + 1 is 3.5
   TestAssert "true", jsonDecode("true") is "true"
   TestAssert "false", jsonDecode("false") is "false"
   TestAssert "null is empty", jsonDecode("null") is empty
   TestAssert "a string", jsonDecode(q("'hello'")) is "hello"
   TestAssert "whitespace around a value", jsonDecode(" " & tab & return & numToCodepoint(13) & "7 ") is "7"
end TestDecodeScalars

on TestDecodeEscapes
   TestAssert "quote, backslash and slash", jsonDecode(q("'a\'b\\c\/d'")) is ("a" & quote & "b\c/d")
   TestAssert "control escapes", jsonDecode(q("'\b\f\n\r\t'")) is \
         (numToCodepoint(8) & numToCodepoint(12) & numToCodepoint(10) & numToCodepoint(13) & numToCodepoint(9))
   TestAssert "a \u escape", jsonDecode(q("'" & u("00e9") & u("0041") & "'")) is (numToCodepoint(233) & "A")
   TestAssert "a surrogate pair is one character", \
         jsonDecode(q("'" & u("d83d") & u("de00") & "'")) is numToCodepoint(128512)
   TestAssert "a character written as itself", jsonDecode(q("'caf") & numToCodepoint(233) & q("'")) is \
         ("caf" & numToCodepoint(233))
end TestDecodeEscapes

on TestLoneSurrogates
   local tJSON, tShape, tData
   -- Half a pair, which RFC 8259 lets a \u escape write, is read as that
   -- code unit, and written back escaped so that the text stays Unicode.
   put quote & u("d83d") & "x" & u("DE00") & quote into tJSON
   put jsonDecodeWithShape(tJSON, tShape) into tData
   TestAssert "read as code units", the number of codeunits of tData is 3 and \
         codepointToNum(codeunit 1 of tData) is 55357 and codepointToNum(codeunit 3 of tData) is 56832
   TestAssert "written back escaped", jsonEncode(tData, tShape) is \
         (quote & u("d83d") & "x" & u("de00") & quote)
   TestAssert "a pair is still written as itself", jsonEncode(numToCodepoint(128512)) is \
         (quote & numToCodepoint(128512) & quote)
end TestLoneSurrogates

on TestDecodeContainers
   local tData
   put jsonDecode(q("[10, 'x', [true, null], {'k': 'v'}]")) into tData
   TestAssert "an array is keyed 1 to N", the number of elements of tData is 4 and \
         tData[1] is "10" and tData[2] is "x"
   TestAssert "a nested array", tData[3][1] is "true" and tData[3][2] is empty and \
         the number of elements of tData[3] is 2
   TestAssert "a nested object", tData[4]["k"] is "v"
   TestAssert "an empty array is empty", jsonDecode("[]") is empty and jsonDecode("[]") is not an array
   TestAssert "an empty object is empty", jsonDecode("{}") is empty

   put jsonDecode(q("{'a': 1, 'a': 2}")) into tData
   TestAssert "a name given twice keeps the last value", tData["a"] is "2" and \
         the number of elements of tData is 1

   put jsonDecode(q("{'': 'empty name'}")) into tData
   TestAssert "an empty name", tData[""] is "empty name"
end TestDecodeContainers

on TestDecodeKeysThatDifferInCase
   local tData
   put jsonDecode(q("{'B': 1, 'b': 2}")) into tData
   set the caseSensitive to true
   TestAssert "both names are kept", the number of elements of tData is 2
   TestAssert "each with its own value", tData["B"] is "1" and tData["b"] is "2"
end TestDecodeKeysThatDifferInCase

on TestDecodeErrors
   local tCase, tError
   repeat for each line tCase in \
         "[1,2,]" & return & \
         "[1 2]" & return & \
         "{'a' 1}" & return & \
         "{'a': 1,}" & return & \
         "{a: 1}" & return & \
         "[01]" & return & \
         "[.5]" & return & \
         "[+1]" & return & \
         "[1.]" & return & \
         "[0x10]" & return & \
         "['a\x']" & return & \
         "['\u12']" & return & \
         "['abc" & return & \
         "[1" & return & \
         "{'a': 1" & return & \
         "tru" & return & \
         "True" & return & \
         "NULL" & return & \
         "1 2" & return & \
         "'a'b"
      put decodeError(q(tCase)) into tError
      TestAssert "refuses" && tCase, tError begins with "jsonDecode: syntax error"
   end repeat
   TestAssert "refuses empty text", decodeError(empty) begins with "jsonDecode: syntax error"
   TestAssert "refuses a raw control character in a string", \
         decodeError(quote & "a" & numToCodepoint(1) & quote) begins with "jsonDecode: syntax error"
   TestAssert "refuses a raw line break in a string", \
         decodeError(quote & "a" & return & quote) begins with "jsonDecode: syntax error"
   TestAssert "refuses a form feed as whitespace", \
         decodeError(numToCodepoint(12) & "1") begins with "jsonDecode: syntax error"
end TestDecodeErrors

on TestDecodeErrorPosition
   local tError
   put decodeError(q("{" & return & "  'a': tru}")) into tError
   TestDiagnostic tError
   TestAssert "names the line and column", tError contains "line 2, column 8"
   put decodeError("[1,2,]") into tError
   TestDiagnostic tError
   TestAssert "names the column on line 1", tError contains "line 1, column 6"
end TestDecodeErrorPosition

on TestDecodeAfterAnError
   local tData
   get decodeError("[1,")
   put jsonDecode("[5]") into tData
   TestAssert "the next call starts afresh", tData[1] is "5"
end TestDecodeAfterAnError

--------------------------------------------------------------------------------
-- Round trips through the shape
--------------------------------------------------------------------------------

on TestRoundTripWithShape
   local tCase, tShape, tData, tOut
   -- Each line is compact JSON that must come back exactly.
   repeat for each line tCase in \
         "[]" & return & \
         "{}" & return & \
         "[[],{}]" & return & \
         "{'1':'a','2':'b'}" & return & \
         "['a','b']" & return & \
         "{'id':'42'}" & return & \
         "{'id':42}" & return & \
         "{'n':1.50,'e':1E+5,'z':-0}" & return & \
         "123456789012345678901234567890" & return & \
         "{'b':1,'a':2,'c':{'z':1,'y':2}}" & return & \
         "null" & return & \
         "[null,'',true,'true',false,'false']" & return & \
         "{'B':1,'b':2}" & return & \
         "{'':0}" & return & \
         "'a\'b\\c\nd\u0001'" & return & \
         "[{'list':[[[]]],'obj':{'deep':{}}}]"
      put empty into tShape
      put jsonDecodeWithShape(q(tCase), tShape) into tData
      put jsonEncode(tData, tShape) into tOut
      TestDiagnostic tOut
      TestAssert "round trip" && tCase, tOut is q(tCase)
   end repeat
end TestRoundTripWithShape

on TestRoundTripBigDocument
   local tJSON, tData, tShape, tRecord
   -- 2000 records, compact, as another program would write them.
   repeat with i = 1 to 2000
      put q("{'id':" & i & ",'name':'user " & i & "','tags':['a','b'],'note':null,'ok':true,'zip':'0" & i & "'}") \
            & "," after tJSON
   end repeat
   put "[" & char 1 to -2 of tJSON & "]" into tJSON
   put jsonDecodeWithShape(tJSON, tShape) into tData
   TestAssert "all 2000 records", the number of elements of tData is 2000
   TestAssert "comes back exactly", jsonEncode(tData, tShape) is tJSON
end TestRoundTripBigDocument

-- Random JSON, written as jsonEncode writes it (compact, only the escapes
-- it must make), read and written back: 400 documents, the same ones each
-- run (a fixed random seed).
local sPieces

private function randomString
   local tOut, tCount
   -- each piece as JSON writes it: \\ and \" are a backslash and a quote
   if sPieces is empty then
      put "a,Z,0,1, ,/,{,},[,],:,e,-,.,\\,\" & quote into sPieces
   end if
   put random(8) - 1 into tCount
   repeat tCount times
      switch random(12)
         case 1
            put "\n" after tOut
            break
         case 2
            put "\t" after tOut
            break
         case 3
            put "\u0001" after tOut
            break
         case 4
            put numToCodepoint(233) after tOut
            break
         case 5
            put numToCodepoint(128512) after tOut
            break
         case 6
            put numToCodepoint(20013) after tOut
            break
         default
            put item random(the number of items of sPieces) of sPieces after tOut
      end switch
   end repeat
   return quote & tOut & quote
end randomString

private function randomJSON pDepth
   local tOut, tCount, tKey, tKeys
   switch random(10)
      case 1
      case 2
         if pDepth < 5 then
            put random(4) - 1 into tCount
            repeat tCount times
               put randomJSON(pDepth + 1) & "," after tOut
            end repeat
            delete the last char of tOut
            return "[" & tOut & "]"
         end if
         return "[]"
      case 3
      case 4
         if pDepth < 5 then
            put random(4) - 1 into tCount
            set the caseSensitive to true
            repeat tCount times
               put item random(10) of "1,2,Key,key,01,1.0,,name,1\n,\n" into tKey
               if tKeys[tKey] is not true then
                  put true into tKeys[tKey]
                  put quote & tKey & quote & ":" & randomJSON(pDepth + 1) & "," after tOut
               end if
            end repeat
            delete the last char of tOut
            return "{" & tOut & "}"
         end if
         return "{}"
      case 5
      case 6
         return randomString()
      case 7
      case 8
         return item random(12) of "0,-0,42,1.50,1e5,1E-5,-2.5e+10,123456789012345678901234567890,0.001,-7,3.0,10"
      default
         return item random(3) of "true,false,null"
   end switch
end randomJSON

-- Each document is also written without its shape, which is guessed, and
-- read back: the text may differ ([] and {} are both empty, a key 1 to N
-- is a list), but the value must not lose a key or change one.
on TestRandomRoundTrips
   local tJSON, tShape, tData, tFailed, tLost
   set the caseSensitive to true
   set the randomSeed to 20261119
   put 0 into tFailed
   put 0 into tLost
   repeat 400 times
      put randomJSON(0) into tJSON
      put empty into tShape
      put jsonDecodeWithShape(tJSON, tShape) into tData
      if jsonEncode(tData, tShape) is not tJSON then
         add 1 to tFailed
         TestDiagnostic "not the same:" && tJSON
      end if
      if dump(jsonDecode(jsonEncode(tData))) is not dump(tData) then
         add 1 to tLost
         TestDiagnostic "not the same value when guessed:" && tJSON
      end if
   end repeat
   TestAssert "all 400 random documents come back exactly", tFailed is 0
   TestAssert "all 400 random values come back when the shape is guessed", tLost is 0
end TestRandomRoundTrips

-- Neither reading nor writing calls itself for each level, so the depth
-- is not bound by the recursion limit, which a parser that recursed
-- reached near 100 levels.
on TestDeepNesting
   local tJSON, tShape, tData, tValue, tWrap
   repeat 3000 times
      put "[{" & quote & "k" & quote & ":" after tJSON
   end repeat
   put "1" after tJSON
   repeat 3000 times
      put "}]" after tJSON
   end repeat
   put jsonDecodeWithShape(tJSON, tShape) into tData
   TestAssert "a document 6000 levels deep comes back exactly", jsonEncode(tData, tShape) is tJSON
   TestAssert "and is guessed right", jsonEncode(tData) is tJSON
   -- (two arrays compared with "is" are compared as text, and are both empty)
   TestAssert "its guessed shape is the one read", \
         jsonEncode(jsonGuessShape(tData)) is jsonEncode(tShape)

   put "x" into tValue
   repeat 5000 times
      put empty into tWrap
      put tValue into tWrap[1]
      put tWrap into tValue
   end repeat
   put jsonEncode(tValue) into tJSON
   TestAssert "a value built 5000 levels deep is written", \
         the number of chars of tJSON is 10003 and char 1 to 3 of tJSON is "[[["
end TestDeepNesting

on TestChangedDataKeepsItsShape
   local tData, tShape
   put jsonDecodeWithShape(q("{'tags':[],'id':'42','opts':{},'n':null}"), tShape) into tData
   put "new" into tData["tags"][1]
   TestAssert "an empty sequence that was filled stays a sequence", \
         jsonEncode(tData, tShape) is q("{'tags':['new'],'id':'42','opts':{},'n':null}")

   put "x" into tData["added"]
   TestAssert "a new key goes after the known ones", \
         jsonEncode(tData, tShape) is q("{'tags':['new'],'id':'42','opts':{},'n':null,'added':'x'}")

   delete variable tData["id"]
   put "y" into tData["n"]
   TestAssert "a deleted key is left out, a value that no longer fits is guessed", \
         jsonEncode(tData, tShape) is q("{'tags':['new'],'opts':{},'n':'y','added':'x'}")
end TestChangedDataKeepsItsShape

on TestSequenceWithGapsAndMore
   local tData, tShape
   put jsonDecodeWithShape("[1,2,3]", tShape) into tData
   delete variable tData[2]
   TestAssert "a sequence with a gap is still an array, in order", jsonEncode(tData, tShape) is "[1,3]"
   put 4 into tData[10]
   TestAssert "an element added past the end", jsonEncode(tData, tShape) is "[1,3,4]"
   put "z" into tData["name"]
   TestAssert "a sequence that gained a name becomes an object", \
         jsonEncode(tData, tShape) is q("{'1':1,'10':4,'3':3,'name':'z'}")
end TestSequenceWithGapsAndMore

--------------------------------------------------------------------------------
-- Guessing
--------------------------------------------------------------------------------

on TestGuessing
   local tData
   TestAssert "empty is an empty string", jsonEncode(empty) is q("''")
   TestAssert "a JSON number", jsonEncode("12") is "12" and jsonEncode("-0.5e3") is "-0.5e3"
   TestAssert "a computed number", jsonEncode(1 + 1) is "2"
   TestAssert "not a JSON number", jsonEncode("012") is q("'012'") and jsonEncode(".5") is q("'.5'") \
         and jsonEncode("1.") is q("'1.'") and jsonEncode("+1") is q("'+1'") and jsonEncode(" 1") is q("' 1'")
   TestAssert "true and false", jsonEncode("true") is "true" and jsonEncode("false") is "false"
   TestAssert "TRUE is a string", jsonEncode("TRUE") is q("'TRUE'")
   TestAssert "text", jsonEncode("hello") is q("'hello'")

   put "a" into tData[1]
   put "b" into tData[2]
   TestAssert "keys 1 to N are an array", jsonEncode(tData) is q("['a','b']")
   put "c" into tData[4]
   TestAssert "keys with a gap are an object", jsonEncode(tData) is q("{'1':'a','2':'b','4':'c'}")

   put empty into tData
   put "a" into tData["01"]
   TestAssert "the key 01 is not 1", jsonEncode(tData) is q("{'01':'a'}")

   put empty into tData
   put 1 into tData["zeta"]
   put 2 into tData["alpha"]
   put 3 into tData["Mid"]
   TestAssert "the keys of an object are sorted", jsonEncode(tData) is q("{'Mid':3,'alpha':2,'zeta':1}")
end TestGuessing

-- Keys and text that a line-by-line or a $-anchored check would get wrong.
on TestGuessingOddKeys
   local tData, tShape
   set the caseSensitive to true
   put 7 into tData[empty]
   TestAssert "the empty key on its own", jsonEncode(tData) is q("{'':7}")
   put 1 into tData["a"]
   TestAssert "the empty key comes first", jsonEncode(tData) is q("{'':7,'a':1}")

   put empty into tData
   put "x" into tData["1" & return]
   TestAssert "a key 1 and a line break is not an index", jsonEncode(tData) is q("{'1\n':'x'}")
   put "y" into tData[1]
   TestAssert "nor beside the key 1", jsonEncode(tData) is q("{'1':'y','1\n':'x'}")
   TestAssert "nor when the shape says list", jsonEncode(tData, "sequence") is q("{'1':'y','1\n':'x'}")

   TestAssert "a number and a line break is text", jsonEncode("42" & return) is q("'42\n'")
   TestAssert "even when the shape says number", jsonEncode("42" & return, "number") is q("'42\n'")

   put jsonDecodeWithShape(q("{'a':1}"), tShape) into tData
   put 2 into tData[empty]
   TestAssert "an empty key added after reading", jsonEncode(tData, tShape) is q("{'a':1,'':2}")
end TestGuessingOddKeys

on TestStringEscaping
   TestAssert "quote and backslash", jsonEncode("a" & quote & "\") is (quote & "a\" & quote & "\\" & quote)
   TestAssert "line breaks and tabs", jsonEncode("a" & return & numToCodepoint(13) & tab) is q("'a\n\r\t'")
   TestAssert "other control characters", jsonEncode(numToCodepoint(1) & numToCodepoint(31)) is q("'\u0001\u001f'")
   TestAssert "a slash is itself", jsonEncode("a/b") is q("'a/b'")
   TestAssert "other characters are themselves", jsonEncode(numToCodepoint(233) & numToCodepoint(128512)) is \
         (quote & numToCodepoint(233) & numToCodepoint(128512) & quote)
end TestStringEscaping

on TestGuessShape
   local tData, tShape
   put "x" into tData["list"][1]
   put "42" into tData["id"]
   put "true" into tData["ok"]
   put "hi" into tData["s"]
   put jsonGuessShape(tData) into tShape
   TestAssert "the whole value", jsonKindOf(tShape, empty) is "dictionary"
   TestAssert "a sequence", jsonKindOf(tShape, "list") is "sequence"
   TestAssert "a number", jsonKindOf(tShape, "id") is "number"
   TestAssert "a boolean", jsonKindOf(tShape, "ok") is "boolean"
   TestAssert "a string", jsonKindOf(tShape, "s") is "string"
   TestAssert "the guessed shape encodes as the guess", jsonEncode(tData, tShape) is jsonEncode(tData)
end TestGuessShape

--------------------------------------------------------------------------------
-- Changing a shape
--------------------------------------------------------------------------------

on TestSetKind
   local tShape, tData, tPath
   jsonSetKind tShape, empty, "dictionary"
   jsonSetKind tShape, "items", "sequence"
   jsonSetKind tShape, "zip", "string"
   jsonSetKind tShape, "missing", "null"
   put empty into tData["items"]
   put "00501" into tData["zip"]
   put empty into tData["missing"]
   TestAssert "empty sequence, string, null", \
         jsonEncode(tData, tShape) is q("{'items':[],'missing':null,'zip':'00501'}")

   put empty into tData
   put "a" into tData[1]
   put "b" into tData[2]
   put empty into tShape
   jsonSetKind tShape, empty, "dictionary"
   TestAssert "keys 1 to N as an object", jsonEncode(tData, tShape) is q("{'1':'a','2':'b'}")

   put empty into tData
   put "123" into tData["users"][2]["zip"]
   put "x" into tData["users"][1]["zip"]
   put empty into tShape
   put "users" into tPath[1]
   put 2 into tPath[2]
   put "zip" into tPath[3]
   jsonSetKind tShape, tPath, "string"
   TestAssert "a path as an array", jsonKindOf(tShape, tPath) is "string"
   TestAssert "the parts above it are guessed", \
         jsonEncode(tData, tShape) is q("{'users':[{'zip':'x'},{'zip':'123'}]}")
   TestAssert "a path as lines", jsonKindOf(tShape, "users" & return & "2" & return & "zip") is "string"

   jsonSetKind tShape, tPath, empty
   TestAssert "empty guesses again", jsonEncode(tData) is q("{'users':[{'zip':'x'},{'zip':123}]}") and \
         jsonEncode(tData, tShape) is jsonEncode(tData)
end TestSetKind

on TestSetKindKeepsInnerParts
   local tShape, tData
   put jsonDecodeWithShape(q("[{'id':'1'}]"), tShape) into tData
   jsonSetKind tShape, empty, "dictionary"
   TestAssert "a sequence made a dictionary keeps its parts' shapes", \
         jsonEncode(tData, tShape) is q("{'1':{'id':'1'}}")
end TestSetKindKeepsInnerParts

on TestSetKindRefusesAnUnknownKind
   local tShape, tError
   try
      jsonSetKind tShape, empty, "list"
   catch tError
   end try
   TestAssert "an unknown kind is an error", tError contains "unknown kind"
end TestSetKindRefusesAnUnknownKind

on TestEncodeRefusesAnUnknownKind
   local tError
   try
      get jsonEncode("y", "text")
   catch tError
   end try
   TestAssert "an unknown kind in a shape is an error", tError contains "unknown kind"
end TestEncodeRefusesAnUnknownKind

on TestKindOf
   local tShape
   get jsonDecodeWithShape(q("{'a':[1,'2',true,null,{}]}"), tShape)
   TestAssert "dictionary", jsonKindOf(tShape, empty) is "dictionary"
   TestAssert "sequence", jsonKindOf(tShape, "a") is "sequence"
   TestAssert "number", jsonKindOf(tShape, "a" & return & 1) is "number"
   TestAssert "string", jsonKindOf(tShape, "a" & return & 2) is "string"
   TestAssert "boolean", jsonKindOf(tShape, "a" & return & 3) is "boolean"
   TestAssert "null", jsonKindOf(tShape, "a" & return & 4) is "null"
   TestAssert "an empty dictionary", jsonKindOf(tShape, "a" & return & 5) is "dictionary"
   TestAssert "a part the shape does not know", jsonKindOf(tShape, "b") is empty
   TestAssert "below a scalar", jsonKindOf(tShape, "a" & return & 1 & return & "x") is empty
end TestKindOf

--------------------------------------------------------------------------------
-- The JSON test suite (github.com/nst/JSONTestSuite), shared with the JSON
-- Library's tests: every y_ file must be read, every n_ file refused.
--------------------------------------------------------------------------------

on TestJSONTestSuite
   local tFolder, tFile, tName, tBytes, tError, tOk, tSkip
   put TestGetEngineRepositoryPath() & \
         "/extensions/libraries/json/tests/JSONTestSuite/test_parsing" into tFolder
   TestDiagnostic tFolder

   -- jsonDecode reads text. These files are not valid UTF-8 (or are UTF-16):
   -- what they say is decided by textDecode before jsonDecode sees them.
   put "n_array_invalid_utf8.json,n_number_invalid-utf-8-in-bigger-int.json," & \
         "n_number_invalid-utf-8-in-exponent.json,n_number_invalid-utf-8-in-int.json," & \
         "n_string_UTF8_surrogate_U+D800.json,n_string_invalid_utf-8.json," & \
         "n_string_iso_latin_1.json,n_string_lone_utf8_continuation_byte.json," & \
         "n_string_overlong_sequence_2_bytes.json,n_string_overlong_sequence_6_bytes.json," & \
         "n_string_overlong_sequence_6_bytes_null.json,n_structure_incomplete_UTF8_BOM.json," & \
         "y_string_utf16.json" into tSkip

   repeat for each line tFile in files(tFolder)
      if char 1 of tFile is not among the items of "y,n" then
         next repeat
      end if
      -- A "#" in a test's description stops the test library's output (the
      -- JSON Library's suite test writes it as U+0023 for the same reason).
      put tFile into tName
      replace "#" with "U+0023" in tName
      if tFile is among the items of tSkip then
         TestSkip tName, "not UTF-8 text: textDecode decides what it says"
         next repeat
      end if
      put url ("binfile:" & tFolder & slash & tFile) into tBytes
      put true into tOk
      put empty into tError
      try
         get jsonDecode(textDecode(tBytes, "UTF-8"))
      catch tError
         put false into tOk
      end try
      if char 1 of tFile is "y" then
         if not tOk then
            TestDiagnostic tName & ":" && line 1 of tError
         end if
         TestAssert "reads" && tName, tOk
      else
         TestAssert "refuses" && tName, not tOk
      end if
   end repeat
end TestJSONTestSuite

--------------------------------------------------------------------------------
-- Kinds of array: LiveCode 11's marks of a sequence and a dictionary
--------------------------------------------------------------------------------

on TestDecodeMarksArraysAndObjects
   local tData, tPlain
   put jsonDecode(q("[1, {'1': 'a'}, [], {}, {'k': [2]}]")) into tData
   TestAssert "a JSON array is strictly a sequence", tData is strictly a sequence
   TestAssert "an object keyed 1 is strictly a dictionary", tData[2] is strictly a dictionary
   TestAssert "an empty array is empty, as before", \
         tData[3] is empty and tData[3] is not a sequence and tData[3] is not an array
   TestAssert "an empty object is empty, as before", \
         tData[4] is empty and tData[4] is not a dictionary
   TestAssert "a JSON array deeper down", tData[5]["k"] is strictly a sequence
   put "a" into tPlain[1]
   TestAssert "a marked array is equal to an unmarked one", tData[2] is tPlain
   TestAssert "and dumps the same", dump(tData[2]) is dump(tPlain)
   put jsonDecodeWithShape(q("{'1': 'a'}"), tPlain) into tData
   TestAssert "jsonDecodeWithShape marks too", tData is strictly a dictionary
end TestDecodeMarksArraysAndObjects

on TestEncodeReadsMarksOnlyWhenAsked
   local tPlain, tShape
   TestAssert "a dictionary keyed 1 to N is guessed a sequence, as before", \
         jsonEncode({"1": "a", "2": "b"}) is q("['a','b']")
   TestAssert "an empty sequence is guessed a string, as before", jsonEncode([]) is q("''")
   TestAssert "with marks, a dictionary keyed 1 to N is an object", \
         jsonEncode({"1": "a", "2": "b"}, empty, "marks") is q("{'1':'a','2':'b'}")
   TestAssert "with marks, an empty sequence is []", jsonEncode([], empty, "marks") is "[]"
   TestAssert "with marks, an empty dictionary is {}", jsonEncode({}, empty, "marks") is "{}"
   TestAssert "with marks, deeper down", \
         jsonEncode({"a": [], "b": {}, "c": {"1": [1]}}, empty, "marks") is \
         q("{'a':[],'b':{},'c':{'1':[1]}}")
   put "a" into tPlain[1]
   TestAssert "with marks, an array with no mark is guessed", \
         jsonEncode(tPlain, empty, "marks") is q("['a']")
   TestAssert "with marks, empty text is guessed", jsonEncode(empty, empty, "marks") is q("''")
   jsonSetKind tShape, empty, "sequence"
   TestAssert "the shape comes before the mark", \
         jsonEncode({"1": "a"}, tShape, "marks") is q("['a']")
   TestAssert "an unknown option is refused", __EncodeError("sorted") contains "unknown option"
end TestEncodeReadsMarksOnlyWhenAsked

on TestRoundTripWithMarks
   local tJSON
   put q("{'list':[1,'x'],'object':{'1':'y','2':'z'},'nested':[{'2':3}]}") into tJSON
   TestAssert "decoding and encoding with marks keeps arrays and objects", \
         jsonEncode(jsonDecode(tJSON), empty, "marks") is \
         q("{'list':[1,'x'],'nested':[{'2':3}],'object':{'1':'y','2':'z'}}")
   TestAssert "a value changed in script keeps its mark", \
         jsonEncode(__AddedTo(jsonDecode(q("{'1':'a'}"))), empty, "marks") is q("{'1':'a','2':'b'}")
end TestRoundTripWithMarks

on TestGuessShapeWithMarks
   TestAssert "without marks, a dictionary keyed 1 is guessed a sequence", \
         jsonKindOf(jsonGuessShape({"1": "a"}), empty) is "sequence"
   TestAssert "with marks it is a dictionary", \
         jsonKindOf(jsonGuessShape({"1": "a"}, "marks"), empty) is "dictionary"
   TestAssert "with marks an empty sequence is a sequence", \
         jsonKindOf(jsonGuessShape({"e": []}, "marks"), "e") is "sequence"
end TestGuessShapeWithMarks

private function __EncodeError pOptions
   local tError
   try
      get jsonEncode("x1", empty, pOptions)
   catch tError
      return tError
   end try
   return empty
end __EncodeError

private function __AddedTo pArray
   put "b" into pArray[2]
   return pArray
end __AddedTo

--------------------------------------------------------------------------------
-- What was there before is untouched
--------------------------------------------------------------------------------

on TestNoOtherHandlersAreAdded
   local tScript, tHandler, tPublic
   -- The only public names this library puts in the message path. A new one
   -- is a new name that someone's stack could already use: add it here only
   -- after checking that.
   put the script of stack "com.livecode.library.jsoncodec" into tScript
   repeat for each line tHandler in tScript
      if word 1 of tHandler is among the items of "function,command,on" then
         put word 2 of tHandler & comma after tPublic
      end if
   end repeat
   TestAssert "only the library's own handlers are public", tPublic is \
         "extensionInitialize,extensionFinalize,jsonDecode,jsonDecodeWithShape," & \
         "jsonEncode,jsonGuessShape,jsonSetKind,jsonKindOf,"
end TestNoOtherHandlersAreAdded

on TestCallerOwnHandlerWins
   TestAssert "a handler of the caller's own is called first", jsonEncode("x") is "mine"
end TestCallerOwnHandlerWins

-- Every other test of this file passes through this handler to the
-- library's, as a stack that adds to jsonEncode would.
function jsonEncode pValue
   if pValue is "x" then
      return "mine"
   end if
   pass jsonEncode
end jsonEncode
