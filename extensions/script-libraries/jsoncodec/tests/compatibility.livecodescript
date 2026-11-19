script "TestJsonCodecCompatibility"
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

-- The JSON Codec library is loaded into every IDE session. These tests run
-- the JSON handlers that were there before it (the JSON Library's
-- JsonImport and JsonExport, and mergJSON's JSONToArray and ArrayToJSON)
-- over every file of the JSON test suite with the library out of the
-- message path and then in it, and require the same result, value for
-- value and error for error.

local sCodec
local sMergJSON

on TestSetup
   TestLoadExtension "com.livecode.library.json"
   put TestGetEngineRepositoryPath() & \
         "/extensions/script-libraries/jsoncodec/jsoncodec.livecodescript" into sCodec
   put TestGetEngineRepositoryPath() & "/mergjson/src/mergJSONLibrary.livecodescript" into sMergJSON
end TestSetup

-- The JSON texts: every file of the suite that is UTF-8 text.
private function corpus
   local tFolder, tFile, tCorpus, i, tText
   put TestGetEngineRepositoryPath() & \
         "/extensions/libraries/json/tests/JSONTestSuite/test_parsing" into tFolder
   put 0 into i
   repeat for each line tFile in files(tFolder)
      put textDecode(url ("binfile:" & tFolder & slash & tFile), "UTF-8") into tText
      add 1 to i
      put tFile into tCorpus[i]["name"]
      put tText into tCorpus[i]["text"]
   end repeat
   return tCorpus
end corpus

-- A value written out with its keys sorted, so two values can be compared
-- as text.
private function dump pValue
   local tKeys, tOut
   if pValue is not an array then
      return "<" & pValue & ">"
   end if
   put the keys of pValue into tKeys
   sort lines of tKeys ascending text
   repeat for each line tKey in tKeys
      put tKey & "=" & dump(pValue[tKey]) & ";" after tOut
   end repeat
   return "{" & tOut & "}"
end dump

private function runJsonLibrary pCorpus
   local tOut, tValue, tError
   repeat with i = 1 to the number of elements of pCorpus
      put pCorpus[i]["name"] & ": " after tOut
      try
         put JsonImport(pCorpus[i]["text"]) into tValue
         put dump(tValue) && JsonExport(tValue) after tOut
      catch tError
         put "error" && line 1 of tError after tOut
      end try
      put return after tOut
   end repeat
   return tOut
end runJsonLibrary

private function runMergJSON pCorpus
   local tOut, tValue, tError
   repeat with i = 1 to the number of elements of pCorpus
      put pCorpus[i]["name"] & ": " after tOut
      try
         put JSONToArray(pCorpus[i]["text"]) into tValue
         put dump(tValue) && ArrayToJSON(tValue) after tOut
      catch tError
         put "error" && line 1 of tError after tOut
      end try
      put return after tOut
   end repeat
   return tOut
end runMergJSON

on TestJsonLibraryUnchanged
   local tCorpus, tBefore, tAfter
   put corpus() into tCorpus
   TestAssert "the corpus was read", the number of elements of tCorpus > 300

   put runJsonLibrary(tCorpus) into tBefore
   start using stack sCodec
   put runJsonLibrary(tCorpus) into tAfter
   stop using stack sCodec
   TestAssert "JsonImport and JsonExport give the same results with the library in use", tAfter is tBefore

   -- as the IDE loads it: its script in the back scripts
   insert the script of stack sCodec into back
   put runJsonLibrary(tCorpus) into tAfter
   remove the script of stack sCodec from back
   TestAssert "JsonImport and JsonExport give the same results with the library in the back scripts", tAfter is tBefore
end TestJsonLibraryUnchanged

on TestMergJSONUnchanged
   local tCorpus, tBefore, tAfter
   TestSkipIfNot "external", "mergJSON"
   TestLoadExternal "mergJSON"
   send "revLoadLibrary" to stack sMergJSON

   put corpus() into tCorpus
   put runMergJSON(tCorpus) into tBefore
   start using stack sCodec
   put runMergJSON(tCorpus) into tAfter
   stop using stack sCodec
   TestAssert "JSONToArray and ArrayToJSON give the same results with the library in use", tAfter is tBefore

   -- as the IDE loads it: its script in the back scripts
   insert the script of stack sCodec into back
   put runMergJSON(tCorpus) into tAfter
   remove the script of stack sCodec from back
   TestAssert "JSONToArray and ArrayToJSON give the same results with the library in the back scripts", tAfter is tBefore
end TestMergJSONUnchanged

on TestCodecLeavesNoStateBehind
   local tBackScripts, tStacks
   put the backScripts into tBackScripts
   put the stacksInUse into tStacks
   start using stack sCodec
   stop using stack sCodec
   insert the script of stack sCodec into back
   remove the script of stack sCodec from back
   TestAssert "the back scripts are as they were", the backScripts is tBackScripts
   TestAssert "the stacks in use are as they were", the stacksInUse is tStacks
end TestCodecLeavesNoStateBehind
