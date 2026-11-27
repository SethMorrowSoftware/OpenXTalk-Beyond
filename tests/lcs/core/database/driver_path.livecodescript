script "CoreDatabaseDriverPath"
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

/*
revGetDatabaseDriverPath copied revdb's driver path with strdup even when
none had been set, which ended the engine on signal 11: in a standalone,
which sets none (revdb then looks for its drivers beside the
application), and in any engine before the script's first
revSetDatabaseDriverPath. It now gives empty. The test runs in an engine
of its own (_driver_path.livecodescript), since this one has set a path
(TestLoadExternal does).
*/

on TestDriverPathWithNoneSet
   TestSkipIfNot "shell"
   TestSkipIfNot "database"
   if the environment is "server" then
      TestSkip "the driver path with none set", "the server engine runs no stacks with -ui"
      exit TestDriverPathWithNoneSet
   end if

   local tExtension, tExternal, tStack, tFile, tOutput
   switch the platform
      case "MacOS"
         put "bundle" into tExtension
         break
      case "Win32"
         put "dll" into tExtension
         break
      default
         put "so" into tExtension
         break
   end switch
   put TestGetBinariesPath() & "/revdb." & tExtension into tExternal

   put specialFolderPath("temporary") & "/oxt-revdb-driver-path.txt" into tFile
   if there is a file tFile then
      delete file tFile
   end if
   put the effective filename of me into tStack
   set the itemDelimiter to slash
   put "_driver_path.livecodescript" into item -1 of tStack
   TestRunStack "-ui", tStack, quote & tExternal & quote
   TestDiagnostic "engine result:" && the result
   if there is a file tFile then
      put textDecode(url ("binfile:" & tFile), "UTF-8") into tOutput
      delete file tFile
   end if
   replace numToChar(13) with empty in tOutput
   TestDiagnostic "the other engine wrote:" && tOutput

   TestAssert "the other engine loaded revdb", line 1 of tOutput is "loaded true"
   TestAssert "it asked for the driver path with none set, and went on", the number of lines of tOutput is 3
   TestAssert "the path was empty", line 2 of tOutput is "[]"
   TestAssert "and once set, it is the path set", line 3 of tOutput is "[/oxt/drivers]"
end TestDriverPathWithNoneSet
