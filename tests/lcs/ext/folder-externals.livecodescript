script "TestFolderExternals"
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

-- The IDE loads an external that lives in a folder of its own
-- (Externals/blur/blur.so, or Externals/blur/code/<processor>-<platform>/
-- blur.so as an extension's code is laid out), from HyperXTalk (#575). Only
-- a binary named after its folder is loaded, so the browser's CEF folder in
-- the IDE's Externals folder, or a folder of the libraries an external
-- needs, is never loaded as externals, as it never was.
--
-- The handlers are the home stack's own (revInternal__FolderExternals and
-- the two it calls, in ide/Toolset/home.livecodescript), taken from it as
-- text into a stack of this test's, beside stand-ins for the folders the
-- IDE asks for, so this runs without the IDE and on files of its own.

constant kStack = "TestFolderExternalsStack"

local sFolder, sIDEExternals, sUserExternals

on TestSetup
   local tHome, tStart, tEnd, tHandlers, tStubs
   TestSkipIfNot "desktop"
   put url ("file:" & TestGetIDERepositoryPath() & "/Toolset/home.livecodescript") into tHome
   put lineOffset("private function revInternal__FolderExternals ", tHome) into tStart
   put lineOffset("end revInternal__FolderEntryNamed", tHome) into tEnd
   if tStart is 0 or tEnd is 0 or tEnd < tStart then
      throw "the home stack's folder externals handlers are not there"
   end if
   put line tStart to tEnd of tHome into tHandlers

   put specialFolderPath("temporary") & "/oxt-folder-externals-" & the milliseconds into sFolder
   put sFolder & "/ide" into sIDEExternals
   put sFolder & "/user" into sUserExternals
   create folder sFolder
   create folder sIDEExternals
   create folder sUserExternals

   -- The IDE's folders, as an installed IDE has them
   put "function revEnvironmentIsInstalled" & return & "return true" & return & \
         "end revEnvironmentIsInstalled" & return & \
         "function revEnvironmentExternalsPath" & return & \
         "return the cIDEExternals of me" & return & "end revEnvironmentExternalsPath" & return & \
         "function revEnvironmentBinariesPath" & return & "return empty" & return & \
         "end revEnvironmentBinariesPath" & return & \
         "function revEnvironmentUserExternalsPath" & return & \
         "return the cUserExternals of me" & return & "end revEnvironmentUserExternalsPath" & return & \
         "function testFolderExternals pExtension, pLoaded" & return & \
         "return revInternal__FolderExternals(pExtension, pLoaded)" & return & \
         "end testFolderExternals" & return into tStubs
   create stack kStack
   set the cIDEExternals of stack kStack to sIDEExternals
   set the cUserExternals of stack kStack to sUserExternals
   set the script of stack kStack to tStubs & tHandlers
   if the result is not empty then
      throw "the handlers do not compile:" && the result
   end if
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
   if sFolder is not empty and there is a folder sFolder then
      __DeleteFolder sFolder
   end if
end TestTeardown

--------------------------------------------------------------------------------

on TestNoFoldersNothingAdded
   TestAssert "no folders, nothing", __Found() is empty
end TestNoFoldersNothingAdded

on TestBinaryInItsFolder
   __MakeFile sUserExternals & "/blur/blur.so"
   TestAssert "the user's", __Found() is (sUserExternals & "/blur/blur.so")
end TestBinaryInItsFolder

on TestBinaryInTheIDEExternalsFolder
   __MakeFile sIDEExternals & "/sharp/sharp.so"
   TestAssert "the IDE's", __Found() is (sIDEExternals & "/sharp/sharp.so")
end TestBinaryInTheIDEExternalsFolder

on TestBinaryInItsCodeFolder
   local tCode
   put sUserExternals & "/blur/code/" & the processor & "-" & __Platform() into tCode
   __MakeFile tCode & "/blur.so"
   TestAssert "this processor and platform's code folder", __Found() is (tCode & "/blur.so")
end TestBinaryInItsCodeFolder

on TestOtherPlatformsCodeFoldersLeft
   __MakeFile sUserExternals & "/blur/code/" & the processor & "-other/blur.so"
   __MakeFile sUserExternals & "/blur/code/other-" & __Platform() & "/blur.so"
   TestAssert "another platform's or processor's code is not loaded", __Found() is empty
end TestOtherPlatformsCodeFoldersLeft

on TestUniversalOnlyOnMac
   local tFound
   __MakeFile sUserExternals & "/blur/code/universal-" & __Platform() & "/blur.so"
   put __Found() into tFound
   if the platform is "MacOS" then
      TestAssert "a universal build serves a Mac", tFound is (sUserExternals & "/blur/code/universal-mac/blur.so")
   else
      TestAssert "a universal folder serves only a Mac", tFound is empty
   end if
end TestUniversalOnlyOnMac

on TestOnlyTheFoldersOwnName
   -- The browser's own folder, as the installed IDE's Externals folder has
   -- it, and a folder of the libraries an external needs
   __MakeFile sIDEExternals & "/CEF/libcef.so"
   __MakeFile sIDEExternals & "/CEF/libvk_swiftshader.so"
   __MakeFile sUserExternals & "/blur/libblurhelper.so"
   __MakeFile sUserExternals & "/Database Drivers/dbsqlite.so"
   TestAssert "no other library is loaded", __Found() is empty
end TestOnlyTheFoldersOwnName

on TestNameInAnyCase
   __MakeFile sUserExternals & "/Blur/blur.so"
   TestAssert "the folder's name in another case", __Found() is (sUserExternals & "/Blur/blur.so")
end TestNameInAnyCase

on TestLooseOneNotTwice
   __MakeFile sUserExternals & "/blur.so"
   __MakeFile sUserExternals & "/blur/blur.so"
   TestAssert "a name loaded loose is not loaded from a folder too", \
         __Found(sUserExternals & "/blur.so" & return) is empty
end TestLooseOneNotTwice

on TestSameNameInBothFoldersOnce
   __MakeFile sIDEExternals & "/blur/blur.so"
   __MakeFile sUserExternals & "/blur/blur.so"
   TestAssert "the IDE's, once", __Found() is (sIDEExternals & "/blur/blur.so")
end TestSameNameInBothFoldersOnce

on TestBundlesAndHiddenFoldersLeft
   __MakeFile sUserExternals & "/blur.bundle/blur.bundle.so"
   __MakeFile sUserExternals & "/.hidden/.hidden.so"
   TestAssert "a .bundle and a hidden folder are left", __Found() is empty
end TestBundlesAndHiddenFoldersLeft

on TestOtherExtensionLeft
   __MakeFile sUserExternals & "/blur/blur.dll"
   TestAssert "another system's binary is not loaded", __Found() is empty
end TestOtherExtensionLeft

on TestSeveral
   local tFound
   __MakeFile sUserExternals & "/blur/blur.so"
   __MakeFile sUserExternals & "/sharp/sharp.so"
   put __Found() into tFound
   sort lines of tFound
   TestAssert "each, one per line", tFound is (sUserExternals & "/blur/blur.so" & return & sUserExternals & "/sharp/sharp.so")
end TestSeveral

--------------------------------------------------------------------------------
-- Helpers

-- What the home stack's handler finds for .so files, without the trailing
-- return it ends each line with
private function __Found pLoaded
   local tFound
   dispatch function "testFolderExternals" to stack kStack with "so", pLoaded
   if it is not "handled" then
      throw "the handler was not there"
   end if
   put the result into tFound
   if the last char of tFound is return then
      delete the last char of tFound
   end if
   return tFound
end __Found

private function __Platform
   switch the platform
      case "MacOS"
         return "mac"
      case "Win32"
         return "win32"
      default
         return toLower(the platform)
   end switch
end __Platform

private command __MakeFile pPath
   local tFolder
   set the itemDelimiter to slash
   repeat with i = 2 to the number of items of pPath - 1
      put item 1 to i of pPath into tFolder
      if there is no folder tFolder then
         create folder tFolder
      end if
   end repeat
   put "x" into url ("binfile:" & pPath)
end __MakeFile

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
