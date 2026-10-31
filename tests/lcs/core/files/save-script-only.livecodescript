script "CoreFilesSaveScriptOnly"
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

-- A script-only stack is saved in place, so a write that stopped part way
-- (a full disk, a crash) left the file cut short and the script lost; since
-- seth's decision 6A (2026-10-31) a copy of the file as it was is kept at
-- "<file>~" while the new text is written, put back when the write fails,
-- and deleted once it is written. On 0.2.7-rc.6.9 for Linux the failed
-- write test fails (the file is cut short); the others pass there too, as
-- they hold what a save already did: no "~" file is left, and one that was
-- there is not touched.

constant kFolder = "__CoreFilesSaveScriptOnly"
constant kStackName = "CoreFilesSaveScriptOnlyStack"

local sFolder

on TestSetup
   put the temporary folder & slash & kFolder & "-" & the seconds & "-" & random(100000) into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   local tFolder, tFile
   if there is a stack kStackName then delete stack kStackName
   if there is a folder sFolder then
      put the defaultFolder into tFolder
      set the defaultFolder to sFolder
      repeat for each line tFile in the files
         delete file tFile
      end repeat
      set the defaultFolder to tFolder
      delete folder sFolder
   end if
end TestTeardown

private function fileBytes pPath
   return URL ("binfile:" & pPath)
end fileBytes

-- Saved twice, the second time over its own file: the text is the new
-- script's and no "~" file is left
on TestScriptOnlySaveLeavesNoCopy
   TestSkipIfNot "write"
   local tPath
   put sFolder & slash & "saved.livecodescript" into tPath
   create script only stack kStackName
   set the filename of stack kStackName to tPath
   set the script of stack kStackName to "-- the first script"
   save stack kStackName
   TestAssert "the first save works", the result is empty
   TestAssert "the first save writes the script", fileBytes(tPath) contains "-- the first script"
   TestAssert "the first save leaves no copy", there is not a file (tPath & "~")
   set the script of stack kStackName to "-- the second script"
   save stack kStackName
   TestAssert "a save over the file works", the result is empty
   TestAssert "a save over the file writes the new script", fileBytes(tPath) contains "-- the second script"
   TestAssert "a save over the file takes the old script out", not (fileBytes(tPath) contains "-- the first script")
   TestAssert "a save over the file leaves no copy", there is not a file (tPath & "~")
end TestScriptOnlySaveLeavesNoCopy

-- A "~" file that is there already (an editor's backup) is not touched
on TestScriptOnlySaveLeavesAnotherCopyAlone
   TestSkipIfNot "write"
   local tPath, tOther
   put sFolder & slash & "other.livecodescript" into tPath
   put "an editor's own backup" into tOther
   create script only stack kStackName
   set the filename of stack kStackName to tPath
   set the script of stack kStackName to "-- the first script"
   save stack kStackName
   put tOther into URL ("binfile:" & tPath & "~")
   set the script of stack kStackName to "-- the second script"
   save stack kStackName
   TestAssert "the save works", the result is empty
   TestAssert "the save writes the new script", fileBytes(tPath) contains "-- the second script"
   TestAssert "the save leaves the other ~ file", there is a file (tPath & "~")
   TestAssert "the save leaves the other ~ file as it was", fileBytes(tPath & "~") is tOther
end TestScriptOnlySaveLeavesAnotherCopyAlone

-- A write that fails part way, run in an engine of its own that may write
-- no file longer than a few kilobytes: the file keeps its old text, and
-- the save's result is the error it was
on TestScriptOnlySaveFailedWriteKeepsTheFile
   TestSkipIfNot "write"
   TestSkipIfNot "shell"
   TestSkipIfNot "platform", "Linux,MacOS"
   TestSkipIf "standalone"
   local tPath, tOld, tChild, tEngine, tOptions, tCommand, tOutput
   put sFolder & slash & "limited.livecodescript" into tPath
   put "script" && quote & "CoreFilesSaveScriptOnlyLimited" & quote & lf & "-- the script as it was" & lf into tOld
   put tOld into URL ("binfile:" & tPath)
   put the effective filename of me into tChild
   set the itemDelimiter to slash
   put "_save-script-only-limited.livecodescript" into item -1 of tChild
   set the itemDelimiter to ":"
   -- (the address is <host>:<engine path>)
   put item 2 to -1 of the address into tEngine
   if the environment contains "command line" then put "-ui" into tOptions
   -- 8 blocks: 4 KB (512-byte blocks) or 8 KB (1 KB blocks); the old
   -- text is far shorter, the new far longer
   put format("ulimit -f 8; trap '' XFSZ; OXT_SAVE_TEST_FILE='%s' exec \"%s\" %s \"%s\"", \
         tPath, tEngine, tOptions, tChild) into tCommand
   put shell(tCommand) into tOutput
   TestDiagnostic "the engine said:" && tOutput
   TestAssert "the save in the limited engine fails as a write error", \
         tOutput contains "result: error writing stack script file"
   TestAssert "the file keeps its old text", fileBytes(tPath) is tOld
   TestAssert "no copy is left", there is not a file (tPath & "~")
end TestScriptOnlySaveFailedWriteKeepsTheFile
