script "OXTMobileWebDeploy"
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

-- Writes the startup data of tools/ci/mobile_web_check.py's web
-- standalone, run with a development engine without a user interface, as
-- tools/ci/web-deploy.livecodescript writes the probe's:
--
--    <engine> -ui tools/ci/mobile-web-deploy.livecodescript
--
-- The main stack is the Phone Starter ($OXT_MW_STACK); beside it go the
-- Mobile Web library ($OXT_MW_LIBRARY), started as the IDE's builder
-- starts a library extension, and the check's own stack
-- ($OXT_MW_CHECK, tools/ci/mobile-web-check.livecodescript), whose
-- handlers the check calls from the page. $OXT_MW_TEMPLATE is the startup
-- script's template, $OXT_MW_VERSION the web engine's version and
-- $OXT_MW_OUTPUT the file to write. It prints "DEPLOY OK <file>" or
-- "DEPLOY FAILED <why>".

private function fileText pPath
   local tText
   open file pPath for "UTF-8" text read
   if the result is not empty then
      throw "cannot open " & pPath & ": " & the result
   end if
   read from file pPath until end
   put it into tText
   close file pPath
   return tText
end fileText

on startup
   local tParams, tResult, tError, tStartup
   try
      if $OXT_MW_VERSION is empty then
         throw "OXT_MW_VERSION is not set"
      end if
      put "start using stack" && quote & "com.livecode.library.mobileweb" & quote & return & \
            "dispatch" && quote & "extensionInitialize" & quote && "to stack" && \
            quote & "com.livecode.library.mobileweb" & quote & return & \
            "set the cJavascriptHandlers of stack" && quote & "MobileWebCheck" & quote && \
            "to" && quote & "mwcState" & quote && "& return &" && quote & "mwcFit" & quote && \
            "& return &" && quote & "mwcStopAndKeep" & quote && \
            "& return &" && quote & "mwcFitAlone" & quote && \
            "& return &" && quote & "mwcStarterScript" & quote && \
            "& return &" && quote & "mwcNotFromATap" & quote into tStartup
      put fileText($OXT_MW_TEMPLATE) into tParams["startup_script"]
      replace "@ENGINE_VERSION@" with $OXT_MW_VERSION in tParams["startup_script"]
      replace "@STARTUP_SCRIPT@" with tStartup in tParams["startup_script"]
      put $OXT_MW_STACK into tParams["stackfile"]
      put $OXT_MW_OUTPUT into tParams["output"]
      put empty into tParams["engine"]
      put $OXT_MW_LIBRARY & return & $OXT_MW_CHECK into tParams["auxiliary_stackfiles"]
      _internal deploy emscripten tParams
      put the result into tResult
   catch tError
      put "script error: " & tError into tResult
   end try
   if tResult is empty and there is a file $OXT_MW_OUTPUT then
      write "DEPLOY OK " & $OXT_MW_OUTPUT & return to stdout
      quit 0
   end if
   if tResult is empty then
      put "the deploy command wrote no file " & $OXT_MW_OUTPUT into tResult
   end if
   replace return with " | " in tResult
   write "DEPLOY FAILED " & tResult & return to stdout
   quit 1
end startup
