script "oxt_ide_stack_patch"
-- Applies the script patches of tools/oxt/ide-stack-patches to the binary
-- IDE stacks, with proof that nothing else in the stack files changes.
--
-- Run it with a development engine, without the IDE, for example the Linux
-- engine of a build (tools/oxt/ide-stack-patch.sh does this):
--
--    OXT_PATCH_ROOT=ide LiveCode-Community -ui tools/oxt/ide-stack-patch.livecodescript
--
-- Environment variables:
--    OXT_PATCH_ROOT   the folder with Toolset whose stacks are patched in
--                     place, normally the repository's ide folder (required)
--    OXT_PATCH_DIR    the patch definitions (default: ide-stack-patches
--                     next to this script)
--    OXT_PATCH_CHECK  1: only report whether each patch is applied; never
--                     save (exit code 1 if one is not)
--
-- A patch definition (one per *.txt file, applied in name order) is
--
--    # comments
--    file: <stack file, relative to OXT_PATCH_ROOT>
--    object: <object of the file's main stack, for example
--             button "X" of card 1 of stack "sub", or "stack" for the main
--             stack itself>
--    replace:
--    |<script line>|
--    ...
--    with:
--    |<script line>|
--    ...
--
-- The lines of the text to find and of its replacement are written between
-- bars, so that leading and trailing blanks survive editors and line-ending
-- conversion. The text to find must occur exactly once in the object's
-- script and the replacement must not occur yet: then the patch is applied.
-- If the text to find does not occur and the replacement occurs once, the
-- patch was applied before and nothing is done, so running the tool again
-- changes nothing. Anything else fails.
--
-- For each stack file the tool
--    1. loads the file (messages locked; the stack is never opened) and
--       dumps every object with tools/oxt/ide-stack-dump.livecodescript,
--    2. sets the patched scripts (each must compile) and dumps again: only
--       the scripts of the patched objects may differ from step 1,
--    3. saves the stack (the engine keeps the oldest file format that holds
--       it, 7.0 for the IDE stacks), removes it from memory, loads the saved
--       file and dumps it: this must equal the dump of step 2 exactly, and
--       the file's header (its format version) must be unchanged.
-- If step 3 fails, the original file is written back. The bytes of a saved
-- file differ from the original in places that carry no content: the
-- character set byte (the platform that saved it), the font table names of
-- inherited (unset) fonts and the order of custom properties.
--
-- Output: one PATCH line per patch (applied, already applied or FAILED
-- with the reason), a FILE line per stack file and a SUMMARY line.
-- Exit code: 0 when every patch is applied (now or before), 1 when a patch
-- failed or, with OXT_PATCH_CHECK, is not applied, 2 when the tool could
-- not run.

local sRoot, sFailures, sApplied, sAlready, sPending

on startup
   local tScriptFolder, tPatchDir, tCheck, tPatches, tFiles
   set the lockMessages to true
   -- The IDE compiles its scripts without explicit variables
   set the explicitVariables to false
   put 0 into sFailures
   put 0 into sApplied
   put 0 into sAlready
   put 0 into sPending

   put $OXT_PATCH_ROOT into sRoot
   replace "\" with "/" in sRoot
   if the last char of sRoot is "/" then delete the last char of sRoot
   set the itemDelimiter to "/"
   put the effective filename of this stack into tScriptFolder
   replace "\" with "/" in tScriptFolder
   put item 1 to -2 of tScriptFolder into tScriptFolder
   set the itemDelimiter to comma
   put $OXT_PATCH_DIR into tPatchDir
   if tPatchDir is empty then put tScriptFolder & "/ide-stack-patches" into tPatchDir
   replace "\" with "/" in tPatchDir
   put ($OXT_PATCH_CHECK is "1") into tCheck

   write "INFO version=" & the version & " build=" & the buildNumber & " platform=" & the platform & return to stdout
   if sRoot is empty or there is not a folder (sRoot & "/Toolset") then
      fatal "OXT_PATCH_ROOT is not a folder with Toolset: " & sRoot
   end if
   if there is not a folder tPatchDir then fatal "no patch folder " & tPatchDir
   write "INFO root=" & sRoot & return to stdout
   if tCheck then
      write "INFO patches=" & tPatchDir & " (check only)" & return to stdout
   else
      write "INFO patches=" & tPatchDir & return to stdout
   end if

   try
      start using stack (tScriptFolder & "/ide-stack-dump.livecodescript")
      put readPatches(tPatchDir) into tPatches
   catch tError
      fatal oneLine(tError)
   end try

   -- The stack files, in the order of their first patch
   repeat with i = 1 to the number of elements of tPatches
      if tPatches[i]["file"] is not among the lines of tFiles then
         put tPatches[i]["file"] & return after tFiles
      end if
   end repeat
   repeat for each line tFile in tFiles
      try
         patchFile tFile, tPatches, tCheck
      catch tError
         write "FILE " & tFile & " | FAILED " & oneLine(tError) & return to stdout
         add 1 to sFailures
      end try
   end repeat

   write "SUMMARY patches=" & the number of elements of tPatches & " applied=" & sApplied & " already=" & sAlready & " pending=" & sPending & " failed=" & sFailures & return to stdout
   if sFailures > 0 or sPending > 0 then quit 1
   quit 0
end startup

private command fatal pMessage
   write "FATAL " & pMessage & return to stdout
   quit 2
end fatal

private function oneLine pText
   replace crlf with " " in pText
   replace return with " " in pText
   replace numToCodepoint(13) with " " in pText
   return pText
end oneLine

private function readText pFile
   local tText
   put textDecode(URL ("binfile:" & pFile), "UTF-8") into tText
   replace crlf with return in tText
   replace numToCodepoint(13) with return in tText
   return tText
end readText

-- The patch definitions as a numbered array of arrays with the keys name,
-- file, object, old and new
private function readPatches pDir
   local tNames, tPatches, tCount, tPatch, tSection, tLineNumber
   put the defaultFolder into tSection
   set the defaultFolder to pDir
   put the files into tNames
   set the defaultFolder to tSection
   filter tNames with "*.txt"
   sort lines of tNames ascending text
   put 0 into tCount
   repeat for each line tName in tNames
      put empty into tPatch
      put tName into tPatch["name"]
      put empty into tSection
      put 0 into tLineNumber
      repeat for each line tLine in readText(pDir & "/" & tName)
         add 1 to tLineNumber
         if tSection is empty and (tLine is empty or char 1 of tLine is "#") then next repeat
         if tLine begins with "file:" then
            put word 1 to -1 of (char 6 to -1 of tLine) into tPatch["file"]
         else if tLine begins with "object:" then
            put word 1 to -1 of (char 8 to -1 of tLine) into tPatch["object"]
         else if tLine is "replace:" then
            put "old" into tSection
         else if tLine is "with:" then
            put "new" into tSection
         else if tSection is not empty and char 1 of tLine is "|" and char -1 of tLine is "|" and the number of chars of tLine >= 2 then
            put char 2 to -2 of tLine & return after tPatch[tSection]
         else if tLine is empty then
            next repeat
         else
            throw tName & " line " & tLineNumber & ": not a patch line: " & tLine
         end if
      end repeat
      if tPatch["file"] is empty or tPatch["object"] is empty or tPatch["old"] is empty or tPatch["new"] is empty then
         throw tName & ": needs file:, object:, replace: and with:"
      end if
      -- Each text ends with the return of its last line
      add 1 to tCount
      put tPatch into tPatches[tCount]
   end repeat
   if tCount is 0 then throw "no *.txt patch in " & pDir
   return tPatches
end readPatches

-- How often pNeedle occurs in pText (case-sensitive, not overlapping)
private function occurrences pNeedle, pText
   local tCount, tOffset, tSkip
   set the caseSensitive to true
   put 0 into tCount
   put 0 into tSkip
   repeat
      put offset(pNeedle, pText, tSkip) into tOffset
      if tOffset is 0 then exit repeat
      add 1 to tCount
      add tOffset + the number of chars of pNeedle - 1 to tSkip
   end repeat
   set the caseSensitive to false
   return tCount
end occurrences

private function objectRef pObject, pMain
   if pObject is "stack" then return the long id of stack pMain
   return value("the long id of" && pObject && "of stack" && quote & pMain & quote)
end objectRef

private command patchFile pRel, pPatches, pCheck
   local tPath, tOriginal, tMain, tBefore, tExpected, tAfter, tChanged
   local tObject, tScript, tOld, tNew, tOldCount, tNewCount, tPatched
   local tAppliedHere, tFailedHere, tSame
   put sRoot & "/" & pRel into tPath
   if there is not a file tPath then throw "not found: " & tPath
   put URL ("binfile:" & tPath) into tOriginal
   put the short name of stack tPath into tMain
   put ideStackDump(tMain) into tBefore
   put 0 into tAppliedHere
   put false into tFailedHere

   repeat with i = 1 to the number of elements of pPatches
      if pPatches[i]["file"] is not pRel then next repeat
      put pPatches[i]["name"] & " | " & pRel & " | " & pPatches[i]["object"] into tPatched
      try
         put objectRef(pPatches[i]["object"], tMain) into tObject
      catch tError
         write "PATCH " & tPatched & " | FAILED no such object" & return to stdout
         add 1 to sFailures
         put true into tFailedHere
         next repeat
      end try
      put the script of tObject into tScript
      put pPatches[i]["old"] into tOld
      put pPatches[i]["new"] into tNew
      put occurrences(tOld, tScript) into tOldCount
      put occurrences(tNew, tScript) into tNewCount
      if tOldCount is 0 and tNewCount is 1 then
         write "PATCH " & tPatched & " | already applied" & return to stdout
         add 1 to sAlready
      else if tOldCount is 1 and tNewCount is 0 and pCheck then
         write "PATCH " & tPatched & " | NOT APPLIED" & return to stdout
         add 1 to sPending
      else if tOldCount is 1 and tNewCount is 0 then
         set the caseSensitive to true
         replace tOld with tNew in tScript
         set the caseSensitive to false
         set the script of tObject to tScript
         if the result is not empty then
            write "PATCH " & tPatched & " | FAILED the patched script does not compile: " & oneLine(the result) & return to stdout
            add 1 to sFailures
            put true into tFailedHere
         else
            write "PATCH " & tPatched & " | applied" & return to stdout
            add 1 to sApplied
            add 1 to tAppliedHere
         end if
      else
         write "PATCH " & tPatched & " | FAILED the text to replace occurs " & tOldCount & " time(s) and the replacement " & tNewCount & " time(s)" & return to stdout
         add 1 to sFailures
         put true into tFailedHere
      end if
   end repeat

   -- A file is saved only when all of its patches could be applied
   if tAppliedHere is 0 or tFailedHere then
      unloadStack tMain
      if tFailedHere then
         write "FILE " & pRel & " | not saved" & return to stdout
      else
         write "FILE " & pRel & " | unchanged" & return to stdout
      end if
      exit patchFile
   end if

   -- Only the patched scripts may differ from the file as it was loaded
   put ideStackDump(tMain) into tExpected
   put scriptsChangedOnly(tBefore, tExpected, tAppliedHere) into tChanged

   save stack tMain
   if the result is not empty then
      put tOriginal into URL ("binfile:" & tPath)
      throw "could not save " & pRel & ": " & the result
   end if
   unloadStack tMain
   put the short name of stack tPath into tMain
   put ideStackDump(tMain) into tAfter
   unloadStack tMain
   set the caseSensitive to true
   put tAfter is tExpected into tSame
   set the caseSensitive to false
   if not tSame then
      put tOriginal into URL ("binfile:" & tPath)
      throw "the saved file does not load as the patched stack; the original is restored"
   end if
   if byte 1 to 8 of URL ("binfile:" & tPath) is not byte 1 to 8 of tOriginal then
      put tOriginal into URL ("binfile:" & tPath)
      throw "the saved file has another format than the original (" & byte 1 to 8 of tOriginal & "); the original is restored"
   end if
   write "FILE " & pRel & " | saved and verified: format " & byte 1 to 8 of tOriginal & ", " & the number of lines of tAfter & " dump lines equal to the patched stack, which differs from the original only in the script of " & the number of lines of tChanged & " object(s)" & return to stdout
   repeat for each line tLabel in tChanged
      write "CHANGED " & pRel & " | " & tLabel & " | script" & return to stdout
   end repeat
end patchFile

-- Removes a main stack (and its substacks) from memory; the file is not
-- touched. A stack with cantDelete set is cleared in memory first (as in
-- tools/ci/ide-compile-check.livecodescript); it is not saved again.
private command unloadStack pName
   try
      delete stack pName
   catch tError
      set the cantDelete of stack pName to false
      repeat for each line tSub in the substacks of stack pName
         set the cantDelete of stack tSub of stack pName to false
      end repeat
      delete stack pName
   end try
end unloadStack

-- Throws unless pBefore and pAfter (two ideStackDump results) have the
-- same objects with the same properties, and the scripts of at least one
-- and at most pPatchCount of them differ. Returns the labels of the
-- objects whose scripts differ, one per line.
private function scriptsChangedOnly pBefore, pAfter, pPatchCount
   local tBeforeA, tAfterA, tBeforeKeys, tAfterKeys, tChanged
   put dumpObjects(pBefore) into tBeforeA
   put dumpObjects(pAfter) into tAfterA
   put the keys of tBeforeA into tBeforeKeys
   put the keys of tAfterA into tAfterKeys
   sort lines of tBeforeKeys
   sort lines of tAfterKeys
   if tBeforeKeys is not tAfterKeys then throw "the objects of the stack changed"
   set the caseSensitive to true
   repeat for each line tKey in tBeforeKeys
      if tBeforeA[tKey]["props"] is not tAfterA[tKey]["props"] then
         set the caseSensitive to false
         throw "properties of " & tKey & " changed"
      end if
      if tBeforeA[tKey]["script"] is not tAfterA[tKey]["script"] then
         put tKey & return after tChanged
      end if
   end repeat
   set the caseSensitive to false
   delete the last char of tChanged
   if the number of lines of tChanged < 1 or the number of lines of tChanged > pPatchCount then
      throw the number of lines of tChanged & " object script(s) changed for " & pPatchCount & " patch(es)"
   end if
   return tChanged
end scriptsChangedOnly

-- The objects of a dump: [<label>]["props"] (all lines but the script)
-- and [<label>]["script"]
private function dumpObjects pDump
   local tObjects, tLabel
   repeat for each line tLine in pDump
      if tLine begins with "== " then
         put char 4 to -1 of tLine into tLabel
      else if tLine begins with "| " or tLine begins with "script: " then
         put tLine & return after tObjects[tLabel]["script"]
      else
         put tLine & return after tObjects[tLabel]["props"]
      end if
   end repeat
   return tObjects
end dumpObjects
