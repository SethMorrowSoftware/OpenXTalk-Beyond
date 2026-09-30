script "oxt_ide_stack_patch"
-- Applies the patches of tools/oxt/ide-stack-patches to the binary IDE
-- stacks, with proof that nothing else in the stack files changes.
--
-- Run it with a development engine, without the IDE, for example the Linux
-- engine of a build (tools/oxt/ide-stack-patch.sh does this):
--
--    OXT_PATCH_ROOT=ide LiveCode-Community -ui tools/oxt/ide-stack-patch.livecodescript
--
-- Environment variables:
--    OXT_PATCH_ROOT   the folder with Toolset whose stacks are patched in
--                     place, normally the repository's ide folder, or an
--                     installed layout with OXT_PATCH_CHECK (required)
--    OXT_PATCH_DIR    the patch definitions (default: ide-stack-patches
--                     next to this script)
--    OXT_PATCH_CHECK  1: only report whether each patch is applied; never
--                     save (exit code 1 if one is not)
--
-- A patch definition file (*.txt, applied in name order) is either a script
-- patch or a property patch.
--
-- A script patch replaces text in the script of one object:
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
-- A property patch sets properties of one or more objects of one stack
-- file, each from a known value to a new one:
--
--    # comments
--    file: <stack file, relative to OXT_PATCH_ROOT>
--    object: <object, as for a script patch>
--    property: <property name, for example foregroundColor>
--    from: <the value the stack file has>
--    to: <the new value; empty for none>
--    property: <another property of the same object>
--    from: ...
--    to: ...
--    object: <another object>
--    ...
--
-- Values are written as tools/oxt/ide-stack-dump.livecodescript writes them
-- (backslash, return, line feed and tab as \\, \r, \n and \t) and compared
-- exactly (case-sensitive), so the "from" value is the one in the stack's
-- dump. A value may be written between bars (from: |value|) to keep
-- leading or trailing blanks. Each object/property pair is one patch: it is
-- applied when the property has the "from" value, and already applied when
-- it has the "to" value; anything else fails. The patches of a file are
-- applied in their order, and setting one property can set others (a
-- button's style its showBorder, a menu's text its label): a later patch
-- of the file may declare such a property, with the value it gets or, to
-- set it back, the value in between as "from" and the file's as "to".
--
-- For each stack file the tool
--    1. loads the file (messages locked; the stack is never opened) and
--       dumps every object with tools/oxt/ide-stack-dump.livecodescript,
--    2. sets the patched scripts (each must compile) and properties and
--       dumps again: the two dumps must differ in exactly the scripts of the
--       objects with script patches and, for the objects with property
--       patches, in exactly one property line per patched property, which
--       now shows the new value,
--    3. saves the stack (the engine keeps the oldest file format that holds
--       it, 7.0 for the IDE stacks), removes it from memory, loads the saved
--       file and dumps it: this must equal the dump of step 2 exactly, and
--       the file's header, which holds its stack file version (for example
--       REVO7000), must be unchanged.
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

-- A property value as written in a patch: optionally between bars, with
-- the escapes of the stack dump (\\, \r, \n, \t)
private function patchValue pText
   local tValue, tChar, tNext, i
   put word 1 to -1 of pText into pText
   if the number of chars of pText >= 2 and char 1 of pText is "|" and char -1 of pText is "|" then
      put char 2 to -2 of pText into pText
   end if
   put 1 into i
   repeat while i <= the number of chars of pText
      put char i of pText into tChar
      if tChar is "\" and i < the number of chars of pText then
         put char i + 1 of pText into tNext
         switch tNext
            case "\"
               put "\" after tValue
               break
            case "n"
               put numToCodepoint(10) after tValue
               break
            case "r"
               put numToCodepoint(13) after tValue
               break
            case "t"
               put tab after tValue
               break
            default
               throw "unknown escape \" & tNext & " in a property value"
         end switch
         add 2 to i
      else
         put tChar after tValue
         add 1 to i
      end if
   end repeat
   return tValue
end patchValue

-- The patch definitions as a numbered array of arrays with the keys name,
-- kind ("script" or "property"), file and object, and old and new for a
-- script patch or property, from and to for a property patch
private function readPatches pDir
   local tNames, tPatches, tCount, tPatch, tSection, tLineNumber, tKind
   local tFile, tObject, tInFile, tName
   put the defaultFolder into tSection
   set the defaultFolder to pDir
   put the files into tNames
   set the defaultFolder to tSection
   filter tNames with "*.txt"
   sort lines of tNames ascending text
   put 0 into tCount
   repeat for each line tFileName in tNames
      put empty into tPatch
      put tFileName into tPatch["name"]
      put "script" into tPatch["kind"]
      put empty into tSection
      put empty into tKind
      put empty into tFile
      put empty into tObject
      put 0 into tInFile
      put 0 into tLineNumber
      repeat for each line tLine in readText(pDir & "/" & tFileName)
         add 1 to tLineNumber
         if tSection is empty and (tLine is empty or char 1 of tLine is "#") then next repeat
         -- In a property patch file, file: and object: apply to the
         -- property: lines that follow them, not to the one before
         if tLine begins with "file:" then
            put word 1 to -1 of (char 6 to -1 of tLine) into tFile
            if tKind is not "property" then
               put tFile into tPatch["file"]
            end if
         else if tLine begins with "object:" then
            put word 1 to -1 of (char 8 to -1 of tLine) into tObject
            if tKind is not "property" then
               put tObject into tPatch["object"]
            end if
         else if tLine begins with "property:" then
            if tKind is "script" then throw tFileName & " line " & tLineNumber & ": a patch is either a script or a property patch"
            put "property" into tKind
            if tObject is empty then throw tFileName & " line " & tLineNumber & ": property: before object:"
            -- A property patch before this one is complete: keep it
            if tPatch["property"] is not empty then
               checkPropertyPatch tPatch, tFileName
               add 1 to tCount
               put tPatch into tPatches[tCount]
            end if
            add 1 to tInFile
            put empty into tPatch
            put tFileName && "#" & tInFile into tPatch["name"]
            put "property" into tPatch["kind"]
            put tFile into tPatch["file"]
            put tObject into tPatch["object"]
            put word 1 to -1 of (char 10 to -1 of tLine) into tName
            -- Only a plain property name: it is used in a statement
            if tName is empty or not matchText(tName, "^[A-Za-z][A-Za-z0-9]*$") then
               throw tFileName & " line " & tLineNumber & ": not a property name: " & tName
            end if
            put tName into tPatch["property"]
         else if tLine begins with "from:" and tKind is "property" then
            put true into tPatch["hasFrom"]
            put patchValue(char 6 to -1 of tLine) into tPatch["from"]
         else if tLine begins with "to:" and tKind is "property" then
            put true into tPatch["hasTo"]
            put patchValue(char 4 to -1 of tLine) into tPatch["to"]
         else if tLine is "replace:" and tKind is not "property" then
            put "script" into tKind
            put "old" into tSection
         else if tLine is "with:" and tKind is not "property" then
            put "script" into tKind
            put "new" into tSection
         else if tSection is not empty and char 1 of tLine is "|" and char -1 of tLine is "|" and the number of chars of tLine >= 2 then
            put char 2 to -2 of tLine & return after tPatch[tSection]
         else if tLine is empty then
            next repeat
         else
            throw tFileName & " line " & tLineNumber & ": not a patch line: " & tLine
         end if
      end repeat
      if tKind is "property" then
         checkPropertyPatch tPatch, tFileName
      else if tPatch["file"] is empty or tPatch["object"] is empty or tPatch["old"] is empty or tPatch["new"] is empty then
         throw tFileName & ": needs file:, object:, replace: and with:"
      else if occurrences(tPatch["old"], tPatch["new"]) > 0 then
         -- An applied patch is recognised by the text to replace being gone
         throw tFileName & ": the replacement contains the text to replace; replace a text that the patch changes"
      end if
      -- Each text of a script patch ends with the return of its last line
      add 1 to tCount
      put tPatch into tPatches[tCount]
   end repeat
   if tCount is 0 then throw "no *.txt patch in " & pDir
   return tPatches
end readPatches

private command checkPropertyPatch pPatch, pFileName
   if pPatch["file"] is empty or pPatch["object"] is empty or pPatch["property"] is empty \
         or pPatch["hasFrom"] is not true or pPatch["hasTo"] is not true then
      throw pFileName & ": a property patch needs file:, object:, property:, from: and to:"
   end if
   set the caseSensitive to true
   if pPatch["from"] is pPatch["to"] then
      set the caseSensitive to false
      throw pFileName & ": the property " & pPatch["property"] & " of " & pPatch["object"] & " has the same from: and to:"
   end if
   set the caseSensitive to false
end checkPropertyPatch

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

-- The value of a property of an object (pProperty is a plain name, checked
-- by readPatches)
private function propertyValue pObject, pProperty
   local tValue
   do "put the" && pProperty && "of pObject into tValue"
   return tValue
end propertyValue

private command patchFile pRel, pPatches, pCheck
   local tPath, tOriginal, tMain, tBefore, tExpected, tAfter, tChanged
   local tObject, tScript, tOld, tNew, tOldCount, tNewCount, tPatched
   local tAppliedHere, tFailedHere, tSame, tScriptObjects, tLabels, tPropertyA, tAppliedA
   local tCompileError, tSaveError, tCurrent, tLabel
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
      if pPatches[i]["kind"] is "property" then put " | " & pPatches[i]["property"] after tPatched
      try
         put objectRef(pPatches[i]["object"], tMain) into tObject
      catch tError
         write "PATCH " & tPatched & " | FAILED no such object" & return to stdout
         add 1 to sFailures
         put true into tFailedHere
         next repeat
      end try

      if pPatches[i]["kind"] is "property" then
         try
            put propertyValue(tObject, pPatches[i]["property"]) into tCurrent
         catch tError
            write "PATCH " & tPatched & " | FAILED the object has no such property" & return to stdout
            add 1 to sFailures
            put true into tFailedHere
            next repeat
         end try
         set the caseSensitive to true
         if tCurrent is pPatches[i]["to"] then
            set the caseSensitive to false
            write "PATCH " & tPatched & " | already applied" & return to stdout
            add 1 to sAlready
            -- Setting one property can set another (a menu's text sets its
            -- label and menuHistory): a property the file patches may have
            -- its new value because of another patch of this run
            put pPatches[i]["to"] into tPropertyA[tObject][pPatches[i]["property"]]
         else if tCurrent is pPatches[i]["from"] then
            set the caseSensitive to false
            if pCheck then
               write "PATCH " & tPatched & " | NOT APPLIED" & return to stdout
               add 1 to sPending
            else
               try
                  do "set the" && pPatches[i]["property"] && "of tObject to pPatches[i][" & quote & "to" & quote & "]"
                  put propertyValue(tObject, pPatches[i]["property"]) into tCurrent
               catch tError
                  put "(" & oneLine(tError) & ")" into tCurrent
               end try
               set the caseSensitive to true
               if tCurrent is not pPatches[i]["to"] then
                  set the caseSensitive to false
                  write "PATCH " & tPatched & " | FAILED the property does not take the new value: " & oneLine(tCurrent) & return to stdout
                  add 1 to sFailures
                  put true into tFailedHere
               else
                  set the caseSensitive to false
                  write "PATCH " & tPatched & " | applied" & return to stdout
                  add 1 to sApplied
                  add 1 to tAppliedHere
                  -- One entry per object and property, for the dump check
                  put pPatches[i]["to"] into tPropertyA[tObject][pPatches[i]["property"]]
                  put true into tAppliedA[tObject][pPatches[i]["property"]]
               end if
            end if
         else
            set the caseSensitive to false
            write "PATCH " & tPatched & " | FAILED the property is neither the from: nor the to: value but: " & oneLine(tCurrent) & return to stdout
            add 1 to sFailures
            put true into tFailedHere
         end if
         next repeat
      end if

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
         -- Keep the compile errors: the next statement resets the result
         put the result into tCompileError
         if tCompileError is not empty then
            write "PATCH " & tPatched & " | FAILED the patched script does not compile: " & oneLine(tCompileError) & return to stdout
            add 1 to sFailures
            put true into tFailedHere
         else
            write "PATCH " & tPatched & " | applied" & return to stdout
            add 1 to sApplied
            add 1 to tAppliedHere
            put tObject & return after tScriptObjects
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

   -- Only the patched scripts and properties may differ from the file as
   -- it was loaded (ideStackDumpLabel needs the dump that follows)
   put ideStackDump(tMain) into tExpected
   repeat for each line tObject in tScriptObjects
      put ideStackDumpLabel(tObject) & return after tLabels
   end repeat
   local tPropertyLabels, tAppliedLabels
   repeat for each key tObject in tPropertyA
      put ideStackDumpLabel(tObject) into tLabel
      if tLabel is empty then throw "a patched object is not in the dump"
      put tPropertyA[tObject] into tPropertyLabels[tLabel]
      put tAppliedA[tObject] into tAppliedLabels[tLabel]
   end repeat
   put changedAsPatched(tBefore, tExpected, tLabels, tPropertyLabels, tAppliedLabels) into tChanged

   -- The engine saves in the oldest format that holds the stack, but not
   -- older than 7.0; a stack in an older format (REVO5500) is saved in its
   -- own, the format of its header (REVOabcd is a.b)
   local tVersion, tOldVersion
   put the stackFileVersion into tOldVersion
   put byte 5 to 8 of tOriginal into tVersion
   if byte 1 to 4 of tOriginal is "REVO" and tVersion is an integer and tVersion < 7000 then
      set the stackFileVersion to char 1 of tVersion & "." & char 2 of tVersion
   end if
   save stack tMain
   -- Writing the original back sets the result, so keep the save error
   put the result into tSaveError
   set the stackFileVersion to tOldVersion
   if tSaveError is not empty then
      put tOriginal into URL ("binfile:" & tPath)
      throw "could not save " & pRel & ": " & tSaveError
   end if
   unloadStack tMain
   put the short name of stack tPath into tMain
   put ideStackDump(tMain) into tAfter
   unloadStack tMain
   put dumpsMatch(tExpected, tAfter) into tSame
   if tSame is false then
      put tOriginal into URL ("binfile:" & tPath)
      throw "the saved file does not load as the patched stack; the original is restored"
   end if
   -- The header holds the stack file version (REVO7000 for 7.0)
   if byte 1 to 8 of URL ("binfile:" & tPath) is not byte 1 to 8 of tOriginal then
      put tOriginal into URL ("binfile:" & tPath)
      throw "the saved file has another stack file version than the original (" & byte 1 to 8 of tOriginal & "); the original is restored"
   end if
   local tRounding
   if tSame > 0 then
      put " (" & tSame & " number(s) reloaded with a rounding difference below 0.01)" into tRounding
   end if
   write "FILE " & pRel & " | saved and verified: format " & byte 1 to 8 of tOriginal & ", " & the number of lines of tAfter & " dump lines equal to the patched stack" & tRounding & ", which differs from the original only in " & the number of lines of tChanged & " patched script(s) and propert(ies)" & return to stdout
   repeat for each line tLine in tChanged
      write "CHANGED " & pRel & " | " & tLine & return to stdout
   end repeat
end patchFile

-- Whether pAfter, the dump of a saved and reloaded stack, is the dump
-- pExpected of the stack before it was saved: false if not, else the
-- number of lines that differ only by rounding. A scrollbar's lineInc,
-- pageInc and thumbSize can come back a little different (9.999634 as
-- 9.998886) whether or not anything was patched, so a number property
-- whose values differ by less than 0.01 is the same.
private function dumpsMatch pExpected, pAfter
   local tRounded, tA, tB
   set the caseSensitive to true
   if pExpected is pAfter then
      set the caseSensitive to false
      return 0
   end if
   if the number of lines of pExpected is not the number of lines of pAfter then
      set the caseSensitive to false
      return false
   end if
   put 0 into tRounded
   repeat with i = 1 to the number of lines of pExpected
      put line i of pExpected into tA
      put line i of pAfter into tB
      if tA is tB then next repeat
      if tA begins with "prop " and tB begins with "prop " and offset(": ", tA) > 0 \
            and char 1 to offset(": ", tA) of tA is char 1 to offset(": ", tB) of tB then
         put char offset(": ", tA) + 2 to -1 of tA into tA
         put char offset(": ", tB) + 2 to -1 of tB into tB
         if tA is a number and tB is a number and abs(tA - tB) < 0.01 then
            add 1 to tRounded
            next repeat
         end if
      end if
      set the caseSensitive to false
      return false
   end repeat
   set the caseSensitive to false
   return tRounded
end dumpsMatch

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

-- The key of a property in "the properties" (and so in the dump), for the
-- synonyms a patch may use
private function propertyKey pProperty
   switch pProperty
      case "foregroundColor"
      case "textColor"
      case "foreColor"
         return "foreColor"
      case "backgroundColor"
      case "fillColor"
      case "backColor"
         return "backColor"
      case "foregroundPattern"
      case "forePattern"
         return "forePattern"
      case "backgroundPattern"
      case "backPattern"
         return "backPattern"
   end switch
   return pProperty
end propertyKey

-- The dump value of a property line: as ide-stack-dump.livecodescript
-- writes it
private function dumpValue pValue
   replace "\" with "\\" in pValue
   replace numToCodepoint(13) with "\r" in pValue
   replace numToCodepoint(10) with "\n" in pValue
   replace tab with "\t" in pValue
   return pValue
end dumpValue

-- Throws unless pBefore and pAfter (two ideStackDump results) have the
-- same objects and differ in the scripts of exactly the objects labelled
-- in pScriptLabels (one label per line) and, for the objects that are keys
-- of pPropertyLabels ([label][property] = new value, for every property
-- patch of the file), only in lines of patched properties, which show the
-- new value, and in the line of every property patched in this run
-- (pAppliedLabels[label][property] is true). Returns one line per change:
-- "<label> | script" or "<label> | <property>".
private function changedAsPatched pBefore, pAfter, pScriptLabels, pPropertyLabels, pAppliedLabels
   local tBeforeA, tAfterA, tBeforeKeys, tAfterKeys, tChanged, tExpected
   local tResult, tBeforeProps, tAfterProps, tWanted, tLine, tKey, tSeen
   put dumpObjects(pBefore) into tBeforeA
   put dumpObjects(pAfter) into tAfterA
   put the keys of tBeforeA into tBeforeKeys
   put the keys of tAfterA into tAfterKeys
   sort lines of tBeforeKeys
   sort lines of tAfterKeys
   if tBeforeKeys is not tAfterKeys then throw "the objects of the stack changed"
   set the caseSensitive to true
   repeat for each line tLabel in tBeforeKeys
      if tBeforeA[tLabel]["props"] is not tAfterA[tLabel]["props"] then
         if pPropertyLabels[tLabel] is not an array then
            set the caseSensitive to false
            throw "properties of " & tLabel & " changed"
         end if
         -- The lines that differ must be those of patched properties
         put empty into tWanted
         put empty into tSeen
         repeat for each key tProperty in pPropertyLabels[tLabel]
            put "prop " & propertyKey(tProperty) & ": " & dumpValue(pPropertyLabels[tLabel][tProperty]) into tWanted[propertyKey(tProperty)]
         end repeat
         put tBeforeA[tLabel]["props"] into tBeforeProps
         put tAfterA[tLabel]["props"] into tAfterProps
         if the number of lines of tBeforeProps is not the number of lines of tAfterProps then
            set the caseSensitive to false
            throw "properties of " & tLabel & " were added or removed"
         end if
         repeat with i = 1 to the number of lines of tAfterProps
            put line i of tAfterProps into tLine
            if tLine is line i of tBeforeProps then next repeat
            put char 6 to (offset(": ", tLine) - 1) of tLine into tKey
            if not (tLine begins with "prop ") or tWanted[tKey] is empty or tLine is not tWanted[tKey] then
               set the caseSensitive to false
               throw "a property of " & tLabel & " changed that no patch sets: " & tLine
            end if
            put tLabel & " | " & tKey & return after tResult
            put true into tSeen[tKey]
         end repeat
         -- A patched property shows its new value; or, when a patch of the
         -- same object changed it and this one set it back, the old one
         repeat for each key tProperty in pAppliedLabels[tLabel]
            if tSeen[propertyKey(tProperty)] is not true and \
                  tWanted[propertyKey(tProperty)] is not among the lines of tBeforeProps then
               set the caseSensitive to false
               throw "the patched property " & tProperty & " of " & tLabel & " is not in the dump as patched"
            end if
         end repeat
      else if pAppliedLabels[tLabel] is an array then
         set the caseSensitive to false
         throw "the patched properties of " & tLabel & " did not change in the dump"
      end if
      if tBeforeA[tLabel]["script"] is not tAfterA[tLabel]["script"] then
         put tLabel & return after tChanged
      end if
   end repeat
   delete the last char of tChanged
   -- The same object can be named by more than one patch
   repeat for each line tLabel in pScriptLabels
      if tLabel is empty then throw "a patched object is not in the dump"
      if tLabel is not among the lines of tExpected then put tLabel & return after tExpected
   end repeat
   delete the last char of tExpected
   sort lines of tChanged
   sort lines of tExpected
   if tChanged is not tExpected then
      set the caseSensitive to false
      throw "the scripts that changed are not those of the patched objects: " & \
            the number of lines of tChanged & " changed, " & the number of lines of tExpected & " patched"
   end if
   set the caseSensitive to false
   repeat for each line tLabel in tChanged
      put tLabel & " | script" & return after tResult
   end repeat
   delete the last char of tResult
   return tResult
end changedAsPatched

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
