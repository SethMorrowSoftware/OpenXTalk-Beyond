script "oxt_ide_contrast_check"
-- Headless contrast check of the IDE's colour tokens (revIDEColor) in the
-- light and the dark appearance.
--
-- Run it with a development engine, without the IDE, on any platform:
--
--    OXT-Beyond.exe -ui tools\ci\ide-contrast-check.livecodescript
--    LiveCode-Community -ui tools/ci/ide-contrast-check.livecodescript
--
-- tools/ci/ide-contrast-check.ps1 does this under GitHub Actions and turns
-- the result into annotations and a job summary; on Linux and macOS run the
-- engine directly.
--
-- Environment variables:
--    OXT_CHECK_ROOT          the layout whose IDE libraries are checked:
--                            an installed layout or the repository's ide
--                            folder (the folder with Toolset) (required)
--    OXT_CONTRAST_PAIRS      the pairs table (default:
--                            ide-contrast-pairs.txt next to this script)
--    OXT_CONTRAST_BASELINE   the known failing pairs (default:
--                            ide-contrast-baseline.txt next to this script)
--    OXT_CONTRAST_UPDATE     1: rewrite the baseline with the pairs that
--                            fail now instead of comparing with it
--    OXT_CONTRAST_LIGHT_ONLY 1: accept a layout without revIDEIsDark() (an
--                            older one, such as main before the dark
--                            palette) and check it in light only, and
--                            accept a licence type other than community
--
-- The check loads the libraries that revIDEColor needs the way the IDE
-- does: revcommonlibrary and revidelibrary as libraries and the script of
-- revCore (which holds ideColorGet) as a backscript. Messages are locked,
-- so no library initialisation runs. It then sets the appearance override
-- of revIDEIsDark() (the global gREVAppearanceOverride) to "light" and to
-- "dark" in turn; without a user interface the engine always reports a
-- light systemAppearance, so the override is the only way to see the dark
-- tokens here. A layout without revIDEIsDark() cannot run the dark pass:
-- that is an error (the dark colours would silently go unchecked), unless
-- OXT_CONTRAST_LIGHT_ONLY is 1, and then only light is checked.
--
-- Some colours of ideColorGet depend on the edition, revLicenseType(); the
-- IDE is "community". The check stops unless it sees "community" too, so
-- that it measures the colours the IDE draws (an older revcommonlibrary
-- gives the environment, "development command line", without the IDE).
--
-- Each line of the pairs table is
--
--    <foreground tag> <background tag> <minimum ratio> [light|dark]
--
-- ("#" starts a comment). Both colours come from revIDEColor(<tag>), in
-- both appearances unless the fourth word limits the pair to one. The
-- ratio is the WCAG 2 contrast ratio of the two colours' relative
-- luminances: 4.5 is the minimum for text, 3 for icons and other parts
-- that must be seen.
--
-- A pair that is below its minimum fails. The baseline lists known
-- failures, one "<appearance> | <foreground> on <background>" per line;
-- they are reported but do not fail the check (a ratchet: once a pair
-- passes, remove it from the baseline).
--
-- Output on stdout: INFO and MODE lines, one PAIR line per pair and
-- appearance,
--
--    PAIR <appearance> | <fg> on <bg> | <ratio> | min <min> | <fg rgb> on <bg rgb> | <status>
--
-- where <status> is pass, known (fails, listed in the baseline), NEW
-- (fails, not listed) or ERROR (a tag gives no colour); a FIXED line for
-- each baseline entry that no longer fails, and a final SUMMARY line.
--
-- Exit code: 0 when no pair failed that is not in the baseline, 1 when one
-- did (or a tag gave no colour), 2 when the check could not run.

global gREVAppearanceOverride

local sOverlaySaved

on startup
   local tRoot, tScriptFolder, tPairsFile, tBaselineFile, tUpdate, tPairs, tBaseline
   local tResults, tModes, tSupportsDark, tIsDark, tKnown, tDarkError, tEdition
   local tCount, tFailed, tKnownCount, tNew, tErrors, tFixed, tFailures
   set the lockMessages to true
   -- The IDE compiles its scripts without explicit variables
   set the explicitVariables to false

   put $OXT_CHECK_ROOT into tRoot
   replace "\" with "/" in tRoot
   if the last char of tRoot is "/" then delete the last char of tRoot
   set the itemDelimiter to "/"
   put the effective filename of this stack into tScriptFolder
   replace "\" with "/" in tScriptFolder
   put item 1 to -2 of tScriptFolder into tScriptFolder
   set the itemDelimiter to comma
   put $OXT_CONTRAST_PAIRS into tPairsFile
   if tPairsFile is empty then put tScriptFolder & "/ide-contrast-pairs.txt" into tPairsFile
   put $OXT_CONTRAST_BASELINE into tBaselineFile
   if tBaselineFile is empty then put tScriptFolder & "/ide-contrast-baseline.txt" into tBaselineFile
   put ($OXT_CONTRAST_UPDATE is "1") into tUpdate

   write "INFO version=" & the version & " build=" & the buildNumber & " platform=" & the platform & " environment=" & the environment & return to stdout
   if tRoot is empty or there is not a folder (tRoot & "/Toolset") then
      fatal "OXT_CHECK_ROOT is not a layout with a Toolset folder: " & tRoot
   end if
   write "INFO root=" & tRoot & return to stdout
   write "INFO pairs=" & tPairsFile & return to stdout
   write "INFO baseline=" & tBaselineFile & return to stdout

   try
      put readPairs(tPairsFile) into tPairs
      if not tUpdate then put readBaseline(tBaselineFile) into tBaseline
      loadLibraries tRoot
      put revLicenseType() into tEdition
   catch tError
      fatal oneLine(tError)
   end try
   write "INFO revLicenseType=" & tEdition & return to stdout
   if tEdition is not "community" then
      if $OXT_CONTRAST_LIGHT_ONLY is "1" then
         write "INFO the edition colours are those of " & quote & tEdition & quote & ", not the IDE's (OXT_CONTRAST_LIGHT_ONLY)" & return to stdout
      else
         fatal "revLicenseType() is " & quote & tEdition & quote & ", not " & quote & "community" & quote & " as in the IDE: the edition colours of ideColorGet would not be the IDE's"
      end if
   end if

   -- The dark pass needs revIDEIsDark() and its override
   put "light" into tModes
   put true into tSupportsDark
   try
      put "dark" into gREVAppearanceOverride
      put revIDEIsDark() into tIsDark
   catch tError
      put false into tSupportsDark
      put oneLine(tError) into tDarkError
   end try
   if tSupportsDark then
      if tIsDark is not true then
         put empty into gREVAppearanceOverride
         fatal "revIDEIsDark() does not follow gREVAppearanceOverride"
      end if
      put comma & "dark" after tModes
   else if $OXT_CONTRAST_LIGHT_ONLY is "1" then
      write "INFO revIDEIsDark() is not available: the dark appearance cannot be forced, only light is checked (OXT_CONTRAST_LIGHT_ONLY)" & return to stdout
   else
      put empty into gREVAppearanceOverride
      fatal "revIDEIsDark() is not available or failed, so the dark colours cannot be checked (" & tDarkError & "); set OXT_CONTRAST_LIGHT_ONLY=1 to check an older layout in light only"
   end if

   put 0 into tCount
   put 0 into tFailed
   put 0 into tKnownCount
   put 0 into tNew
   put 0 into tErrors
   put empty into tFailures
   repeat for each item tMode in tModes
      put tMode into gREVAppearanceOverride
      if tSupportsDark then
         write "MODE " & tMode & " revIDEIsDark=" & revIDEIsDark() & return to stdout
      else
         write "MODE " & tMode & " systemAppearance=" & the systemAppearance & return to stdout
      end if
      repeat for each line tPair in tPairs
         if word 4 of tPair is not empty and word 4 of tPair is not tMode then next repeat
         local tKey, tFore, tBack, tRatio, tStatus, tDetail
         put tMode & " | " & word 1 of tPair & " on " & word 2 of tPair into tKey
         add 1 to tCount
         put empty into tRatio
         put empty into tDetail
         try
            put tokenRGB(word 1 of tPair) into tFore
            put tokenRGB(word 2 of tPair) into tBack
            put contrastRatio(tFore, tBack) into tRatio
            put tFore & " on " & tBack into tDetail
            if tRatio >= word 3 of tPair then
               put "pass" into tStatus
            else
               add 1 to tFailed
               put tKey & return after tFailures
               if tKey is among the lines of tBaseline then
                  put "known" into tStatus
                  add 1 to tKnownCount
                  put true into tKnown[tKey]
               else
                  put "NEW" into tStatus
                  add 1 to tNew
               end if
            end if
         catch tError
            put "ERROR" into tStatus
            put oneLine(tError) into tDetail
            add 1 to tErrors
         end try
         if tRatio is not empty then put format("%.2f", tRatio) into tRatio
         write "PAIR " & tKey & " | " & tRatio & " | min " & word 3 of tPair & " | " & tDetail & " | " & tStatus & return to stdout
      end repeat
   end repeat
   put empty into gREVAppearanceOverride

   put 0 into tFixed
   if not tUpdate then
      repeat for each line tEntry in tBaseline
         if tKnown[tEntry] then next repeat
         -- An entry for an appearance that was not checked is not fixed
         if word 1 of tEntry is not among the items of tModes then next repeat
         write "FIXED " & tEntry & return to stdout
         add 1 to tFixed
      end repeat
   else if tErrors > 0 then
      -- A pair that could not be evaluated has no line in tFailures, so a
      -- baseline written now would silently drop it; keep the old one
      write "INFO baseline not rewritten: " & tErrors & " pair(s) could not be evaluated" & return to stdout
   else
      writeBaseline tBaselineFile, tFailures
   end if

   write "SUMMARY pairs=" & tCount & " failed=" & tFailed & " known=" & tKnownCount & " new=" & tNew & " fixed=" & tFixed & " errors=" & tErrors & " modes=" & tModes & return to stdout
   if tErrors > 0 then quit 1
   if tUpdate then quit 0
   if tNew > 0 then quit 1
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
   replace tab with " " in pText
   return pText
end oneLine

-- revcommonlibrary and revidelibrary as libraries, revCore's script as a
-- backscript (Toolset/home.livecodescript does the same when the IDE
-- starts)
private command loadLibraries pRoot
   local tFile
   repeat for each item tRel in "Toolset/libraries/revcommonlibrary.livecodescript,Toolset/libraries/revidelibrary.8.livecodescript"
      put pRoot & "/" & tRel into tFile
      if there is not a file tFile then throw "not found: " & tFile
      start using stack tFile
      write "INFO library " & tRel & return to stdout
   end repeat
   put pRoot & "/Toolset/palettes/revCore.8.livecode" into tFile
   if there is not a file tFile then throw "not found: " & tFile
   insert the script of stack tFile into back
   write "INFO backscript Toolset/palettes/revCore.8.livecode" & return to stdout
end loadLibraries

-- The pairs as "<fg> <bg> <min> [<appearance>]" lines
private function readPairs pFile
   local tText, tPairs, tLineNumber
   if there is not a file pFile then throw "pairs table not found: " & pFile
   put textDecode(URL ("binfile:" & pFile), "UTF-8") into tText
   replace crlf with return in tText
   put 0 into tLineNumber
   repeat for each line tLine in tText
      add 1 to tLineNumber
      if "#" is in tLine then delete char offset("#", tLine) to -1 of tLine
      if the number of words of tLine is 0 then next repeat
      if the number of words of tLine > 4 or word 3 of tLine is not a number \
            or (word 4 of tLine is not empty and word 4 of tLine is not among the items of "light,dark") then
         throw "pairs table line " & tLineNumber & " is not <fg> <bg> <min> [light|dark]: " & tLine
      end if
      put word 1 to 4 of tLine & return after tPairs
   end repeat
   delete the last char of tPairs
   return tPairs
end readPairs

-- The baseline's entries, without comments and blank lines
private function readBaseline pFile
   local tText, tEntries
   if there is not a file pFile then return empty
   put textDecode(URL ("binfile:" & pFile), "UTF-8") into tText
   replace crlf with return in tText
   repeat for each line tLine in tText
      if tLine is empty or char 1 of tLine is "#" then next repeat
      put word 1 to -1 of tLine & return after tEntries
   end repeat
   delete the last char of tEntries
   return tEntries
end readBaseline

private command writeBaseline pFile, pFailures
   local tText
   put "# Known failing pairs of tools/ci/ide-contrast-check.livecodescript," & return & \
         "# one '<appearance> | <foreground> on <background>' per line. The check" & return & \
         "# reports them without failing; remove an entry once its pair passes." & return & \
         "# Regenerate with OXT_CONTRAST_UPDATE=1 (or ide-contrast-check.ps1" & return & \
         "# -UpdateBaseline)." & return into tText
   put pFailures after tText
   put textEncode(tText, "UTF-8") into URL ("binfile:" & pFile)
   if the result is not empty then fatal "could not write " & pFile & ": " & the result
   write "INFO baseline rewritten: " & the number of lines of pFailures & " entries" & return to stdout
end writeBaseline

-- The colour of an IDE colour tag as "r,g,b"; throws when the tag has none
private function tokenRGB pTag
   local tColor
   put revIDEColor(pTag) into tColor
   if tColor is empty then throw "revIDEColor(" & quote & pTag & quote & ") is empty"
   return colorRGB(tColor, pTag)
end tokenRGB

-- A colour ("r,g,b", "r,g,b,a", a colour name or "#rrggbb") as "r,g,b".
-- Names are resolved by the engine through the colorOverlay of the
-- template graphic (as revIDENamedColorToRGB does), which is restored.
private function colorRGB pColor, pTag
   local tRGB, tSaved
   if the number of items of pColor >= 3 and item 1 of pColor is an integer \
         and item 2 of pColor is an integer and item 3 of pColor is an integer then
      put item 1 to 3 of pColor into tRGB
   else if pColor is a color then
      put the colorOverlay of the templateGraphic into tSaved
      set the colorOverlay["color"] of the templateGraphic to pColor
      put the colorOverlay["color"] of the templateGraphic into tRGB
      set the colorOverlay of the templateGraphic to tSaved
   else
      throw "revIDEColor(" & quote & pTag & quote & ") is not a colour: " & pColor
   end if
   repeat for each item tChannel in tRGB
      if tChannel is not an integer or tChannel < 0 or tChannel > 255 then
         throw "revIDEColor(" & quote & pTag & quote & ") is not a colour: " & pColor
      end if
   end repeat
   return tRGB
end colorRGB

-- WCAG 2 relative luminance of an sRGB colour "r,g,b" (0-255)
private function relativeLuminance pRGB
   local tLinear
   repeat with i = 1 to 3
      local tC
      put item i of pRGB / 255 into tC
      if tC <= 0.04045 then
         put tC / 12.92 into tLinear[i]
      else
         put ((tC + 0.055) / 1.055) ^ 2.4 into tLinear[i]
      end if
   end repeat
   return 0.2126 * tLinear[1] + 0.7152 * tLinear[2] + 0.0722 * tLinear[3]
end relativeLuminance

-- WCAG 2 contrast ratio of two colours, from 1 to 21
private function contrastRatio pFore, pBack
   local tFore, tBack
   put relativeLuminance(pFore) into tFore
   put relativeLuminance(pBack) into tBack
   return (max(tFore, tBack) + 0.05) / (min(tFore, tBack) + 0.05)
end contrastRatio
