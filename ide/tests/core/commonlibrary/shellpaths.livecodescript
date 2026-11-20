script "CommonLibraryShellPaths"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

-- OXT-Beyond: revCopyFile, revCopyFolder, revMoveFolder and revDeleteFolder
-- on Linux hand their paths to cp, mv and rm in double quotes, where the
-- shell still reads a dollar sign, a backtick, a double quote and a
-- backslash. Up to 0.2.8-dp.2, and in LiveCode Community, a file with one
-- of those in its name was not copied (or another file was). A path that
-- names nothing there is still the shell's to read, as it always was.

local sFolder

on TestSetup
   put specialFolderPath("temporary") & slash & "oxt-shell-paths-" & the milliseconds into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   if sFolder is not empty and there is a folder sFolder then
      revDeleteFolder sFolder
   end if
end TestTeardown

private function __Names
   return "plain.txt" & return & "two words.txt" & return & "pri$e.txt" & return & \
         "back`tick.txt" & return & "say " & quote & "hi" & quote & ".txt" & return & \
         "back\slash.txt" & return & "$HOME.txt" & return & "it's.txt"
end __Names

on TestCopyFileWithShellCharacters
   TestSkipIfNot "platform", "linux"
   local tName, tSource, tTarget
   create folder (sFolder & "/out")
   repeat for each line tName in __Names()
      put sFolder & slash & tName into tSource
      put "data of" && tName into URL ("binfile:" & tSource)
      -- to a file of the same name in another folder
      put sFolder & "/out/" & tName into tTarget
      revCopyFile tSource, tTarget
      TestAssert "revCopyFile copies" && tName, there is a file tTarget and \
            URL ("binfile:" & tTarget) is "data of" && tName
      -- to a new name beside it, with the same characters
      put sFolder & "/copy of " & tName into tTarget
      revCopyFile tSource, tTarget
      TestAssert "revCopyFile copies" && tName && "to a name like it", there is a file tTarget and \
            URL ("binfile:" & tTarget) is "data of" && tName
   end repeat
   TestAssert "nothing else was written", the number of lines of files(sFolder & "/out") is the number of lines of __Names()
end TestCopyFileWithShellCharacters

on TestCopyFileIntoAFolder
   TestSkipIfNot "platform", "linux"
   create folder (sFolder & "/in$ide")
   put "x" into URL ("binfile:" & sFolder & "/pri$e.txt")
   revCopyFile sFolder & "/pri$e.txt", sFolder & "/in$ide"
   TestAssert "revCopyFile into a folder with a dollar sign", there is a file (sFolder & "/in$ide/pri$e.txt")
end TestCopyFileIntoAFolder

on TestFolderCommandsWithShellCharacters
   TestSkipIfNot "platform", "linux"
   local tSource
   put sFolder & "/my $tuff" into tSource
   create folder tSource
   put "x" into URL ("binfile:" & tSource & "/a`b.txt")
   revCopyFolder tSource, sFolder & "/copy of $tuff"
   TestAssert "revCopyFolder copies a folder with a dollar sign", \
         there is a file (sFolder & "/copy of $tuff/a`b.txt")
   revMoveFolder sFolder & "/copy of $tuff", sFolder & "/moved $tuff"
   TestAssert "revMoveFolder moves it", there is a file (sFolder & "/moved $tuff/a`b.txt") and \
         there is not a folder (sFolder & "/copy of $tuff")
   revDeleteFolder sFolder & "/moved $tuff"
   TestAssert "revDeleteFolder deletes it", there is not a folder (sFolder & "/moved $tuff")
   TestAssert "and nothing else", there is a file (tSource & "/a`b.txt")
end TestFolderCommandsWithShellCharacters

-- What a script could count on before: a path that names nothing as it is
-- written goes to the shell as it did, so "$HOME" in it is still the home
-- folder.
on TestAPathForTheShellIsStillTheShells
   TestSkipIfNot "platform", "linux"
   local tOldHome
   put $HOME into tOldHome
   put "x" into URL ("binfile:" & sFolder & "/from.txt")
   create folder (sFolder & "/home")
   put sFolder & "/home" into $HOME
   revCopyFile "$HOME/../from.txt", "$HOME/to.txt"
   -- and as the whole destination, a folder to copy into
   revCopyFile sFolder & "/from.txt", "$HOME"
   put tOldHome into $HOME
   TestAssert "$HOME in a path is still expanded", there is a file (sFolder & "/home/to.txt")
   TestAssert "$HOME alone as the destination is still the home folder", \
         there is a file (sFolder & "/home/from.txt")
   TestAssert "and no file of that name was made", there is not a file "$HOME"
end TestAPathForTheShellIsStillTheShells
