script "CoreFilesTrash"
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

-- "move file <path> to trash" (and folder) and "show <path> in finder" (or
-- explorer), from HyperXTalk (#538, #539). Neither "trash", "finder" nor
-- "explorer" became a word of the language. "move file <path> to ..." did
-- not compile before; "show <path> in finder" compiled as "show <path>"
-- and a call of a handler "in", and stopped when it ran. Every statement
-- that ran without stopping before does what it did, and "show <object>
-- in finder" still shows the object and stops as it did (compared with
-- the earlier build by hand: see the pull request).
--
-- Only Linux is asked to really trash a file here, into a trash of the
-- test's own ($XDG_DATA_HOME, which gio and the engine's own fallback both
-- use), so the user's trash is never touched. The Recycle Bin and the
-- Finder's trash, and the file managers that "show" starts, are checked by
-- hand on those systems (see the pull request).

local sFolder

on TestSetup
   put specialFolderPath("temporary") & "/oxt-trash-test-" & the milliseconds into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   if sFolder is not empty and there is a folder sFolder then
      __DeleteFolder sFolder
   end if
end TestTeardown

--------------------------------------------------------------------------------
-- The new forms compile, and the old ones compile as they did

on TestTrashCompiles
   TestAssert "move file to trash", __CompileError("move file tPath to trash") is empty
   TestAssert "move folder to trash", __CompileError("move folder tPath to trash") is empty
   TestAssert "move directory to trash", __CompileError("move directory tPath to trash") is empty
   TestAssert "a quoted path", __CompileError("move file " & quote & "/tmp/x" & quote & " to trash") is empty
   TestAssert "an expression for the path", __CompileError("move file (tPath & slash & tName) to trash") is empty
   TestAssert "TRASH in any case", __CompileError("move file tPath to TRASH") is empty
end TestTrashCompiles

on TestMoveCompilesAsBefore
   TestAssert "an object to a point", __CompileError("move button 1 to 10,10") is empty
   TestAssert "an object to a variable", __CompileError("move button 1 to tPoints") is empty
   TestAssert "an object to a variable named trash", __CompileError("move button 1 to trash") is empty
   TestAssert "an object relative", __CompileError("move button 1 relative 5,5") is empty
   TestAssert "file with no path, as before", __CompileError("move file to trash") is empty
   TestAssert "a file to any other place, as before", __CompileError("move file tPath to tPlace") is not empty
   TestAssert "with no target", __CompileError("move") is not empty
   TestAssert "trash alone", __CompileError("move trash") is not empty
end TestMoveCompilesAsBefore

on TestMoveRunsAsBefore
   -- (the earlier build: EE_CHUNK_BADOBJECTEXP, then EE_MOVE_BADOBJECT)
   TestAssertThrow "move file to trash, with no path, stops as before", "__MoveFileNoPath", the long id of me, "EE_CHUNK_BADOBJECTEXP,EE_MOVE_BADOBJECT"
end TestMoveRunsAsBefore

on __MoveFileNoPath
   do "move file to trash"
end __MoveFileNoPath

on TestShowInFinderCompiles
   TestAssert "show in finder", __CompileError("show tPath in finder") is empty
   TestAssert "show in explorer", __CompileError("show tPath in explorer") is empty
   TestAssert "FINDER in any case", __CompileError("show tPath in FINDER") is empty
end TestShowInFinderCompiles

on TestShowCompilesAsBefore
   TestAssert "show an object", __CompileError("show button 1") is empty
   TestAssert "show at a point", __CompileError("show button 1 at 10,10") is empty
   TestAssert "show a variable named finder", __CompileError("show finder") is empty
   TestAssert "show a button named finder", __CompileError("show button " & quote & "finder" & quote) is empty
   TestAssert "in with another word", __CompileError("show button 1 in tPlace") is empty
   TestAssert "an object in finder", __CompileError("show button 1 in finder") is empty
end TestShowCompilesAsBefore

on TestShowObjectInFinderAsBefore
   -- An object's reference is never a path: the button is shown, and the
   -- rest of the line is a call of a handler "in", which stops the script
   create invisible button "TestShowFinderButton"
   TestAssertThrow "show <object> in finder stops as before", "__ShowObjectInFinder", the long id of me, "EE_STATEMENT_BADCOMMAND"
   TestAssert "after showing the object", the visible of button "TestShowFinderButton"
   delete button "TestShowFinderButton"
end TestShowObjectInFinderAsBefore

on __ShowObjectInFinder
   show button "TestShowFinderButton" in finder
end __ShowObjectInFinder

on TestShowVariableHoldingAnObject
   -- A difference, listed in the pull request and the dictionary: a
   -- variable is a path, even when it holds an object's long id. Before,
   -- the object was shown and the script stopped
   TestSkipIfNot "desktop"
   local tObject
   create invisible button "TestShowFinderVariable"
   put the long id of button "TestShowFinderVariable" into tObject
   show tObject in finder
   TestAssert "the long id is no file", the result is "file not found"
   TestAssert "and the object is not shown", not the visible of button "TestShowFinderVariable"
   delete button "TestShowFinderVariable"
end TestShowVariableHoldingAnObject

--------------------------------------------------------------------------------
-- What the commands do

on TestTrashMissingFile
   TestSkipIfNot "desktop"
   move file (sFolder & "/no such file.txt") to trash
   TestAssert "no file: can't find that file", the result is "can't find that file"
   move folder (sFolder & "/no such folder") to trash
   TestAssert "no folder: can't find that file", the result is "can't find that file"
end TestTrashMissingFile

on TestShowMissingFile
   TestSkipIfNot "desktop"
   local tPath
   put sFolder & "/no such file.txt" into tPath
   show tPath in finder
   TestAssert "no file: file not found", the result is "file not found"
   show tPath in explorer
   TestAssert "the same with explorer", the result is "file not found"
end TestShowMissingFile

on TestTrashFileOnLinux
   TestSkipIfNot "platform", "Linux"
   local tOldDataHome, tTrash, tPath
   put $XDG_DATA_HOME into tOldDataHome
   put sFolder & "/data" into tTrash
   create folder tTrash
   put tTrash into $XDG_DATA_HOME

   put sFolder & "/notes.txt" into tPath
   put "some notes" into url ("file:" & tPath)
   move file tPath to trash
   TestAssert "the result is empty", the result is empty
   TestAssert "the file is gone", there is no file tPath
   TestAssert "it is in the trash", url ("file:" & tTrash & "/Trash/files/notes.txt") is "some notes"
   TestAssert "with a note of where it came from", there is a file (tTrash & "/Trash/info/notes.txt.trashinfo")

   put tOldDataHome into $XDG_DATA_HOME
end TestTrashFileOnLinux

on TestTrashFolderOnLinux
   TestSkipIfNot "platform", "Linux"
   local tOldDataHome, tTrash, tPath
   put $XDG_DATA_HOME into tOldDataHome
   put sFolder & "/data" into tTrash
   create folder tTrash
   put tTrash into $XDG_DATA_HOME

   -- a folder that is not empty, which delete folder would not delete
   put sFolder & "/project" into tPath
   create folder tPath
   put "a" into url ("file:" & tPath & "/a.txt")
   move folder tPath to trash
   TestAssert "the result is empty", the result is empty
   TestAssert "the folder is gone", there is no folder tPath
   TestAssert "it is in the trash, with what it held", url ("file:" & tTrash & "/Trash/files/project/a.txt") is "a"

   put tOldDataHome into $XDG_DATA_HOME
end TestTrashFolderOnLinux

on TestTrashLinkNotWhatItPointsTo
   -- a symbolic link goes to the trash itself, and the folder it points to
   -- stays where it is (HyperXTalk trashed the folder)
   TestSkipIfNot "platform", "Linux"
   local tOldDataHome, tTrash, tTarget, tLink
   put $XDG_DATA_HOME into tOldDataHome
   put sFolder & "/data" into tTrash
   create folder tTrash
   put tTrash into $XDG_DATA_HOME

   put sFolder & "/kept" into tTarget
   create folder tTarget
   put "k" into url ("file:" & tTarget & "/k.txt")
   put sFolder & "/link" into tLink
   create alias tLink to folder tTarget
   TestAssert "the link was made", there is a folder tLink

   move folder tLink to trash
   TestAssert "the result is empty", the result is empty
   TestAssert "the link is gone", there is no folder tLink
   TestAssert "what it pointed to is kept", url ("file:" & tTarget & "/k.txt") is "k"
   TestAssert "the link is in the trash", url ("file:" & tTrash & "/Trash/files/link/k.txt") is "k"

   -- delete file and delete folder take a link's target, so the link
   -- leaves by the shell, and TestTeardown removes the rest
   get shell("rm -f" && quote & tTrash & "/Trash/files/link" & quote)
   put tOldDataHome into $XDG_DATA_HOME
end TestTrashLinkNotWhatItPointsTo

on TestTrashTakesTheDefaultFolder
   TestSkipIfNot "platform", "Linux"
   local tOldDataHome, tOldFolder, tTrash
   put $XDG_DATA_HOME into tOldDataHome
   put the defaultFolder into tOldFolder
   put sFolder & "/data" into tTrash
   create folder tTrash
   put tTrash into $XDG_DATA_HOME

   set the defaultFolder to sFolder
   put "x" into url "file:relative.txt"
   move file "relative.txt" to trash
   TestAssert "a name alone is in the defaultFolder", the result is empty and there is no file (sFolder & "/relative.txt")
   TestAssert "and it is in the trash", there is a file (tTrash & "/Trash/files/relative.txt")

   set the defaultFolder to tOldFolder
   put tOldDataHome into $XDG_DATA_HOME
end TestTrashTakesTheDefaultFolder

on TestTrashSameNameTwice
   TestSkipIfNot "platform", "Linux"
   local tOldDataHome, tTrash, tPath, tFiles
   put $XDG_DATA_HOME into tOldDataHome
   put sFolder & "/data" into tTrash
   create folder tTrash
   put tTrash into $XDG_DATA_HOME

   put sFolder & "/twice.txt" into tPath
   put "first" into url ("file:" & tPath)
   move file tPath to trash
   put "second" into url ("file:" & tPath)
   move file tPath to trash
   TestAssert "the second went too", the result is empty and there is no file tPath
   put files(tTrash & "/Trash/files") into tFiles
   TestAssert "both are in the trash", the number of lines of tFiles is 2

   put tOldDataHome into $XDG_DATA_HOME
end TestTrashSameNameTwice

on TestTrashNeedsDiskAccess
   TestSkipIfNot "desktop"
   TestSkipIfNot "securitypermissions", "set"
   -- (the secureMode cannot be set back within one run, so this only
   -- checks the call stops where delete file stops)
   TestAssert "trash needs the disk", "disk" is among the items of the securityPermissions or the secureMode
end TestTrashNeedsDiskAccess

--------------------------------------------------------------------------------
-- Helpers

-- What setting a new button's script to a handler holding the statement
-- puts in the result: empty when it compiles, its errors otherwise
private function __CompileError pStatement
   local tScript, tResult, tButton
   put "on test" & return & "local tPath, tName, tPoints, tPlace" & return & \
         pStatement & return & "end test" into tScript
   create button
   put it into tButton
   set the script of tButton to tScript
   put the result into tResult
   delete tButton
   return tResult
end __CompileError

private command __DeleteFolder pFolder
   repeat for each line tFile in files(pFolder)
      delete file (pFolder & slash & tFile)
   end repeat
   repeat for each line tSub in folders(pFolder)
      if tSub is "." or tSub is ".." then next repeat
      __DeleteFolder pFolder & slash & tSub
   end repeat
   delete folder pFolder
end __DeleteFolder
