script "_saveScriptOnlyLimited"
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

-- Run by save-script-only.livecodescript in an engine of its own, which
-- the shell lets write no file longer than a few kilobytes (ulimit -f,
-- with SIGXFSZ ignored, so that a write past the limit fails as a full
-- disk's would): the script-only stack in the file $OXT_SAVE_TEST_FILE
-- is given a script longer than that and saved, so the write fails part
-- way. The result of the save goes to stdout.

on startup
   local tPath, tStack, tScript, tResult
   put $OXT_SAVE_TEST_FILE into tPath
   put the short name of stack tPath into tStack
   repeat 1000 times
      put "-- a line of a script much longer than the file size limit" & return after tScript
   end repeat
   set the script of stack tStack to tScript
   save stack tStack
   -- (taken at once, before another command can change it)
   put the result into tResult
   write "result:" && tResult to stdout
   quit 0
end startup
