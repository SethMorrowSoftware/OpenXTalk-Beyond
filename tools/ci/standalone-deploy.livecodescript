script "OXTStandaloneDeployTest"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- Builds a standalone the way the IDE's standalone builder does at its
-- core (revStandaloneDeployWithParams in ide-support/
-- revsaveasstandalone.livecodescript): a stack file is saved and then
-- "_internal deploy" attaches it to a packaged standalone engine. The
-- standalone it makes writes a line (PROBE ...) and then one FEATURE line
-- for each of featureProbes() to stdout and quits, so that
-- tools/ci/standalone_check.py can run it and check what it reports.
--
-- Run with a development engine, without a user interface:
--    <engine> -ui tools/ci/standalone-deploy.livecodescript
-- Environment:
--    OXT_DEPLOY_PLATFORM  macosx, linux or windows (the deploy command's
--                         platform)
--    OXT_DEPLOY_ENGINE    the standalone engine to attach the stack to
--    OXT_DEPLOY_OUTPUT    the standalone to write
--    OXT_DEPLOY_STACK     where to save the stack file
--    OXT_DEPLOY_ARCHS     optional: the architectures to keep ("x86-64",
--                         "arm64", or both, comma-separated; all when empty)
--
-- Writes "DEPLOY OK <output>" or "DEPLOY FAILED <reason>" and exits with 0
-- or 1.

-- The features a standalone engine is asked about (FEATURE lines): each
-- is a change made since the runtimes asset was built (ffc75ba5b,
-- 2026-10-11) that a script can see without a user interface. Each is
-- worked out by value() in a try, so that the probe stack compiles on
-- every engine, and an engine without the feature answers "no" or
-- "error" rather than failing: standalone_check.py fails only a runtime
-- built from this commit for a "no", and reports the others (the
-- modernization plan's MOD-03, evidence for MOD-D1).
--    microseconds     the microseconds (#215)
--    matches          matches wildcard and matches regex (#215)
--    literal-arrays   [1, 2] and {"key": value} where an expression goes
private function featureProbes
   local tProbes
   put "microseconds" & tab & "the microseconds is a number and the microseconds > 0" & return after tProbes
   put "matches" & tab & "(" & quote & "a.txt" & quote & " matches wildcard " & quote & "*.txt" & quote & ") and (" \
         & quote & "2026" & quote & " matches regex " & quote & "^[0-9]+$" & quote & ")" & return after tProbes
   put "literal-arrays" & tab & "the number of elements of [10, 20, 30] is 3 and " \
         & "the number of elements of {" & quote & "k" & quote & ": 7, " & quote & "j" & quote & ": 8} is 2" after tProbes
   return tProbes
end featureProbes

private function probeScript
   local tScript, tProbe
   put "on startup" & return into tScript
   put "   write " & quote & "PROBE version=" & quote & " & the version & " & quote & " processor=" & quote \
         & " & the processor & " & quote & " platform=" & quote & " & the platform & " & quote \
         & " environment=" & quote & " & the environment & return to stdout" & return after tScript
   set the itemDelimiter to tab
   repeat for each line tProbe in featureProbes()
      put "   probeFeature " & quote & item 1 of tProbe & quote & ", " & quote \
            & replaceText(item 2 of tProbe, quote, quote & " & quote & " & quote) & quote & return after tScript
   end repeat
   put "   quit 0" & return & "end startup" & return after tScript
   put "on probeFeature pName, pExpression" & return after tScript
   put "   local tAnswer" & return after tScript
   put "   try" & return after tScript
   put "      if value(pExpression) is true then" & return after tScript
   put "         put " & quote & "yes" & quote & " into tAnswer" & return after tScript
   put "      else" & return after tScript
   put "         put " & quote & "no" & quote & " into tAnswer" & return after tScript
   put "      end if" & return after tScript
   put "   catch tError" & return after tScript
   put "      put " & quote & "error" & quote & " into tAnswer" & return after tScript
   put "   end try" & return after tScript
   put "   write " & quote & "FEATURE " & quote & " & pName & " & quote & "=" & quote & " & tAnswer & return to stdout" \
         & return after tScript
   put "end probeFeature" & return after tScript
   return tScript
end probeScript

on startup
   local tParams, tResult
   write "INFO engine version=" & the version & " platform=" & the platform & " processor=" & the processor & return to stdout
   try
      if $OXT_DEPLOY_PLATFORM is not among the items of "macosx,linux,windows" then
         throw "OXT_DEPLOY_PLATFORM must be macosx, linux or windows, not '" & $OXT_DEPLOY_PLATFORM & "'"
      end if
      if there is not a file $OXT_DEPLOY_ENGINE then
         throw "no standalone engine at " & $OXT_DEPLOY_ENGINE
      end if
      create stack "OXTStandaloneProbe"
      set the script of stack "OXTStandaloneProbe" to probeScript()
      save stack "OXTStandaloneProbe" as $OXT_DEPLOY_STACK
      if the result is not empty then
         throw "cannot save the stack as " & $OXT_DEPLOY_STACK & ": " & the result
      end if
      put $OXT_DEPLOY_STACK into tParams["stackfile"]
      put $OXT_DEPLOY_ENGINE into tParams["engine"]
      put $OXT_DEPLOY_OUTPUT into tParams["output"]
      if $OXT_DEPLOY_ARCHS is not empty then
         put $OXT_DEPLOY_ARCHS into tParams["architectures"]
      end if
      if $OXT_DEPLOY_PLATFORM is "macosx" then
         -- a new LC_UUID for the executable, as the builder gives each one
         put uuid() into tParams["uuid"]
         _internal deploy macosx tParams
      else if $OXT_DEPLOY_PLATFORM is "windows" then
         -- what revStandaloneDeployWithParams passes besides the icons,
         -- the version resource and the manifest, which are optional
         _internal deploy windows tParams
      else
         _internal deploy linux tParams
      end if
      put the result into tResult
   catch tError
      -- a thrown message, or the engine's error records (the first names
      -- the error; see engine/src/executionerrors.h)
      put "script error: " & tError into tResult
   end try
   if tResult is empty and there is a file $OXT_DEPLOY_OUTPUT then
      write "DEPLOY OK " & $OXT_DEPLOY_OUTPUT & return to stdout
      quit 0
   end if
   if tResult is empty then
      put "the deploy command wrote no file " & $OXT_DEPLOY_OUTPUT into tResult
   end if
   replace return with " | " in tResult
   write "DEPLOY FAILED " & tResult & return to stdout
   quit 1
end startup
