script "oxt_ide_stack_dump"
-- A text dump of every object of a binary stack file, to compare two
-- versions of a stack (for example before and after
-- tools/oxt/ide-stack-patch.livecodescript) object by object.
--
-- Run it with a development engine, without the IDE:
--
--    OXT_DUMP_FILE=<stack file> OXT_DUMP_OUT=<text file> \
--       LiveCode-Community -ui tools/oxt/ide-stack-dump.livecodescript
--
-- and compare two dumps with any diff tool. The patch tool uses the same
-- dump as a library (start using), through ideStackDump().
--
-- The dump covers the main stack, its substacks, their cards, and the
-- groups and controls on each card (and groups on no card), each object
-- once, in card and layer order. For each object it lists
--    - its path (names and ids, never the file's location),
--    - every property of "the properties" (except the file name of a
--      stack and an image's data), arrays flattened to name[key] lines,
--    - every custom property of every custom property set,
--    - the htmlText of fields and the SHA-1 of the text of images,
--    - the script, one "| " line per script line.
-- Values are on one line: backslash, return, line feed and tab are
-- written as \\, \r, \n and \t.
--
-- The stack file is only loaded into memory, with messages locked; it is
-- never opened or saved.
--
-- Exit code: 0 on success, 2 when the dump could not be written.

local sDump, sVisited, sLabels

on startup
   local tFile, tOut, tName
   set the lockMessages to true
   put $OXT_DUMP_FILE into tFile
   put $OXT_DUMP_OUT into tOut
   if tFile is empty or there is not a file tFile or tOut is empty then
      write "FATAL set OXT_DUMP_FILE to a stack file and OXT_DUMP_OUT to the output file" & return to stdout
      quit 2
   end if
   try
      put the short name of stack tFile into tName
      put textEncode(ideStackDump(tName), "UTF-8") into URL ("binfile:" & tOut)
      if the result is not empty then throw the result
   catch tError
      write "FATAL " & line 1 of tError & return to stdout
      quit 2
   end try
   write "DUMP " & tFile & " -> " & tOut & return to stdout
   quit 0
end startup

-- The dump of the main stack pName (which must be in memory) and of its
-- substacks
function ideStackDump pName
   put empty into sDump
   put empty into sVisited
   put empty into sLabels
   dumpStack the long id of stack pName, "stack" && quote & pName & quote
   repeat for each line tSub in the substacks of stack pName
      dumpStack the long id of stack tSub of stack pName, "stack" && quote & pName & quote && ">" && "substack" && quote & tSub & quote
   end repeat
   return sDump
end ideStackDump

private command dumpStack pStack, pLabel
   local tCard, tGroup
   put empty into sVisited
   dumpObject pStack, pLabel
   repeat with tCardNumber = 1 to the number of cards of pStack
      put the long id of card tCardNumber of pStack into tCard
      dumpObject tCard, pLabel && ">" && objectLabel(tCard)
      dumpControls tCard, pLabel && ">" && objectLabel(tCard)
   end repeat
   repeat with tGroupNumber = 1 to the number of backgrounds of pStack
      put the long id of background tGroupNumber of pStack into tGroup
      if sVisited[the id of tGroup] then next repeat
      dumpControl tGroup, pLabel && ">" && "(on no card)"
   end repeat
end dumpStack

private command dumpControls pOwner, pLabel
   repeat for each line tID in the childControlIDs of pOwner
      dumpControl the long id of control id tID of pOwner, pLabel
   end repeat
end dumpControls

private command dumpControl pControl, pLabel
   local tLabel
   if sVisited[the id of pControl] then exit dumpControl
   put true into sVisited[the id of pControl]
   put pLabel && ">" && objectLabel(pControl) into tLabel
   dumpObject pControl, tLabel
   if word 1 of the name of pControl is "group" then
      dumpControls pControl, tLabel
   end if
end dumpControl

-- "button "OK" (id 1005)", or "button (id 1005)" for an unnamed object
private function objectLabel pObject
   local tType, tID, tShortName
   put word 1 of the name of pObject into tType
   put the id of pObject into tID
   put the short name of pObject into tShortName
   if tShortName is (tType && "id" && tID) then
      return tType && "(id" && tID & ")"
   end if
   return tType && quote & tShortName & quote && "(id" && tID & ")"
end objectLabel

private function escapeValue pValue
   replace "\" with "\\" in pValue
   replace numToCodepoint(13) with "\r" in pValue
   replace numToCodepoint(10) with "\n" in pValue
   replace tab with "\t" in pValue
   return pValue
end escapeValue

-- Appends "<prefix><name>[<key>]...: <value>" lines for a value that may
-- be an array, keys in a stable order
private command addValue pPrefix, pName, pValue
   local tKeys
   if pValue is an array then
      put the keys of pValue into tKeys
      set the caseSensitive to true
      sort lines of tKeys ascending text
      set the caseSensitive to false
      repeat for each line tKey in tKeys
         addValue pPrefix, pName & "[" & escapeValue(tKey) & "]", pValue[tKey]
      end repeat
   else
      put pPrefix & pName & ": " & escapeValue(pValue) & return after sDump
   end if
end addValue

-- The label (the "== " line) that the last ideStackDump gave an object
function ideStackDumpLabel pObject
   return sLabels[the long id of pObject]
end ideStackDumpLabel

private command dumpObject pObject, pLabel
   local tProps, tNames, tSets, tScript
   put "== " & pLabel & return after sDump
   put pLabel into sLabels[the long id of pObject]
   put the properties of pObject into tProps
   -- The script is listed below and an image's data as a digest; the
   -- file name of a stack is where it was loaded from, not part of it
   delete variable tProps["script"]
   delete variable tProps["fileName"]
   if word 1 of the name of pObject is "image" then
      repeat for each item tProp in "text,imageData,alphaData,maskData"
         delete variable tProps[tProp]
      end repeat
   end if
   put the keys of tProps into tNames
   set the caseSensitive to true
   sort lines of tNames ascending text
   set the caseSensitive to false
   repeat for each line tName in tNames
      addValue "prop ", tName, tProps[tName]
   end repeat

   -- The default custom property set has the empty name
   put the customPropertySets of pObject into tSets
   if empty is not among the lines of tSets then put return before tSets
   set the caseSensitive to true
   sort lines of tSets ascending text
   set the caseSensitive to false
   repeat for each line tSet in tSets
      addValue "custom ", "{" & escapeValue(tSet) & "}", the customProperties[tSet] of pObject
   end repeat

   switch word 1 of the name of pObject
      case "field"
         addValue "field ", "htmlText", the htmlText of pObject
         break
      case "image"
         addValue "image ", "text sha1", sha1Hex(the text of pObject)
         break
   end switch

   put the script of pObject into tScript
   put "script: " & the number of lines of tScript & " lines" & return after sDump
   repeat for each line tLine in tScript
      put "| " & escapeValue(tLine) & return after sDump
   end repeat
end dumpObject

private function sha1Hex pData
   local tHex
   get binaryDecode("H*", sha1Digest(pData), tHex)
   return tHex
end sha1Hex
