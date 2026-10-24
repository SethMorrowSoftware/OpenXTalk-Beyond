script "TestJsonLibrary"
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

-- The JSON library (com.livecode.library.json) as a script uses it: JSON
-- with and without whitespace, escapes, what it refuses, and what
-- JsonExport makes of an array. Its own tests (extensions/libraries/json/
-- tests) check the parser against the JSONTestSuite; these pin what a
-- script sees, as LiveCode's library has always given it, on every
-- platform the engine tests run on. (openxtalk.org, October 2026: a
-- report that JsonImport failed with no error was "put ... after" an
-- array, below.)

on TestSetup
   TestSkipIfNot "lcb"
   TestLoadExtension "com.livecode.library.json"
end TestSetup

-- A reply from a chat server (OpenAI's format, as LM Studio sends it),
-- with no whitespace at all
private function chatReply
   return "{<Q>id<Q>:<Q>chatcmpl-1<Q>,<Q>object<Q>:<Q>chat.completion<Q>," & \
         "<Q>created<Q>:1761317000,<Q>model<Q>:<Q>gemma-4-31b<Q>," & \
         "<Q>choices<Q>:[{<Q>index<Q>:0,<Q>message<Q>:{<Q>role<Q>:<Q>assistant<Q>," & \
         "<Q>content<Q>:<Q>Connection was Successful<Q>},<Q>logprobs<Q>:null," & \
         "<Q>finish_reason<Q>:<Q>stop<Q>}],<Q>usage<Q>:{<Q>prompt_tokens<Q>:20," & \
         "<Q>completion_tokens<Q>:5,<Q>total_tokens<Q>:25},<Q>stats<Q>:{}}"
end chatReply

private function q pText
   replace "<Q>" with quote in pText
   return pText
end q

on TestImportWithoutWhitespace
   local tA
   put JsonImport(q(chatReply())) into tA
   TestAssert "an object is an array", tA is an array
   TestAssert "a string", tA["model"] is "gemma-4-31b"
   TestAssert "an array of objects", tA["choices"][1]["message"]["content"] is "Connection was Successful"
   TestAssert "a number", tA["usage"]["total_tokens"] is 25
   TestAssert "a big number", tA["created"] is 1761317000
   TestAssert "null is empty", tA["choices"][1]["logprobs"] is empty
   TestAssert "an empty object is empty", tA["stats"] is empty
   TestAssert "every key", the number of lines of the keys of tA is 7
end TestImportWithoutWhitespace

on TestImportWithWhitespace
   local tJson, tA, tB
   put q(chatReply()) into tJson
   put JsonImport(tJson) into tA
   -- spaces, tabs and both kinds of line ending between the tokens
   replace "{" with "{" & numToCodepoint(13) & numToCodepoint(10) & tab in tJson
   replace "," & quote with " ," & return & tab & tab & quote in tJson
   replace ":" with " : " in tJson
   replace "]" with return & "]" & numToCodepoint(13) in tJson
   put JsonImport(tJson) into tB
   TestAssert "the same content", tB["choices"][1]["message"]["content"] is tA["choices"][1]["message"]["content"]
   TestAssert "the same keys", the keys of tB is the keys of tA
   TestAssert "the same numbers", tB["usage"]["total_tokens"] is tA["usage"]["total_tokens"]
end TestImportWithWhitespace

on TestImportAJsonArray
   local tA, tKeys
   put JsonImport("[1,2,[3,4],{" & quote & "k" & quote & ":true},false,null]") into tA
   put the keys of tA into tKeys
   sort lines of tKeys numeric
   TestAssert "a JSON array is an array keyed from 1", tKeys is "1" & return & "2" & return & "3" & return & "4" & return & "5" & return & "6"
   TestAssert "nested", tA[3][2] is 4
   TestAssert "true", tA[4]["k"] is "true"
   TestAssert "false", tA[5] is "false"
   TestAssert "null", tA[6] is empty
end TestImportAJsonArray

on TestImportPutAfter
   -- JsonImport returns an array. Put before or after a variable, an
   -- array is text, which for an array is empty, so nothing is added and
   -- an array in the variable is emptied; "into" is what keeps it. As
   -- in LiveCode.
   local tA
   put JsonImport(q(chatReply())) after tA
   TestAssert "put after an empty variable puts nothing", tA is empty and tA is not an array
   put "x" into tA
   put JsonImport(q(chatReply())) after tA
   TestAssert "put after text leaves the text", tA is "x"
   put JsonImport(q(chatReply())) into tA
   TestAssert "put into is the array", tA["model"] is "gemma-4-31b"
   put JsonImport(q(chatReply())) into tA["reply"]
   TestAssert "put into an element is the array", tA["reply"]["model"] is "gemma-4-31b"
end TestImportPutAfter

on TestImportEscapes
   local tA
   put JsonImport(q("[<Q>\u00e9<Q>,<Q>\u4e2d<Q>,<Q>\ud83d\ude00<Q>,<Q>http:\/\/x<Q>,<Q>a\tb\nc<Q>,<Q>\<Q>\\<Q>]")) into tA
   TestAssert "an escaped e acute", tA[1] is numToCodepoint(233)
   TestAssert "an escaped CJK character", tA[2] is numToCodepoint(20013)
   TestAssert "an escaped surrogate pair", tA[3] is numToCodepoint(128512)
   TestAssert "an escaped slash", tA[4] is "http://x"
   TestAssert "an escaped tab and line feed", tA[5] is "a" & tab & "b" & numToCodepoint(10) & "c"
   TestAssert "an escaped quote and backslash", tA[6] is quote & numToCodepoint(92)
   put JsonImport("[" & quote & "caf" & numToCodepoint(233) & " " & numToCodepoint(128512) & quote & "]") into tA
   TestAssert "unescaped characters as they are", tA[1] is "caf" & numToCodepoint(233) & " " & numToCodepoint(128512)
end TestImportEscapes

private command importError pJson
   local tError
   try
      get JsonImport(pJson)
   catch tError
      return tError
   end try
   return empty
end importError

on TestImportErrors
   -- bad JSON is never quiet: JsonImport throws, saying where
   importError q("{<Q>a<Q>:1,}")
   TestAssert "a trailing comma throws", the result contains "syntax error: 1:"
   importError q("{<Q>a<Q>:1")
   TestAssert "an unfinished object throws", the result contains "syntax error"
   importError empty
   TestAssert "nothing throws", the result contains "syntax error"
   importError q("{a:1}")
   TestAssert "a key without quotes throws", the result contains "syntax error"
   -- a byte order mark left at the start is not JSON
   importError numToCodepoint(65279) & "{}"
   TestAssert "a byte order mark throws", the result contains "syntax error: 1:1"
   importError q("[<Q>a<Q>] x")
   TestAssert "text after the JSON throws", the result contains "syntax error"
end TestImportErrors

on TestExportAnArray
   -- An array is a JSON object whatever its keys, and text is a JSON
   -- string even when it looks like a number: JsonExport makes a JSON
   -- array only of a list, which a script cannot make. As in LiveCode.
   local tA, tJson
   put "user" into tA["messages"][1]["role"]
   put JsonExport(tA) into tJson
   TestAssert "keys 1 to N make an object", tJson is q("{<Q>messages<Q>: {<Q>1<Q>: {<Q>role<Q>: <Q>user<Q>}}}")
   put empty into tA
   put 0.1 into tA["t"]
   TestAssert "text that looks like a number is a string", JsonExport(tA) is "{" & quote & "t" & quote & ": " & quote & "0.1" & quote & "}"
   put 0.1 + 0 into tA["t"]
   TestAssert "a number is a number", JsonExport(tA) is "{" & quote & "t" & quote & ": 0.1}"
   put empty into tA
   put true into tA["b"]
   TestAssert "the constant true is true", JsonExport(tA) is q("{<Q>b<Q>: true}")
   put "true" into tA["b"]
   TestAssert "the text true is a string", JsonExport(tA) is q("{<Q>b<Q>: <Q>true<Q>}")
end TestExportAnArray

on TestRoundTrip
   local tA, tB
   put "gemma" into tA["model"]
   put "user" into tA["messages"][1]["role"]
   put "caf" & numToCodepoint(233) & quote & numToCodepoint(92) & tab into tA["messages"][1]["content"]
   put 7 + 0 into tA["n"]
   put JsonImport(JsonExport(tA)) into tB
   TestAssert "text comes back", tB["messages"][1]["content"] is tA["messages"][1]["content"]
   TestAssert "a number comes back", tB["n"] is 7
   TestAssert "keys come back", the keys of tB["messages"] is "1"
end TestRoundTrip
