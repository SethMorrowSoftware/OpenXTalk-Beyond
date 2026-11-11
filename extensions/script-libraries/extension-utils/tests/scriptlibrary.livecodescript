script "TestExtensionUtilsScriptLibrary"
-- OXT-Beyond: tests of extensionScriptLibraryProblems, which the Extension
-- Builder logs for a script library at each build and test, and of the
-- package a failed build leaves behind. Skids (forum p=26031): when a
-- script library does not build, the Extension Builder's messages are poor
-- and it leaves "extra files dotted about". The docs parser's errors went
-- to stdout, which the IDE does not show, so a library with no library
-- block said only "no id found in" its file when it was packaged; one that
-- did not compile built and installed with none of its handlers and said
-- nothing; and a package that failed part way stayed beside the extension.
-- Each library is built as the Extension Builder builds one
-- (revIDEExtensionUpdateAPI, then extensionGenerateManifestForLCSExtension).

local sFolder, sCount

on TestSetup
   TestSkipIfNot "externals", "revxml,revzip"
   TestLoadExternal "revxml"
   TestLoadExternal "revzip"
   start using stack (TestGetEngineRepositoryPath() & \
         "/extensions/script-libraries/extension-utils/extension-utils.livecodescript")
   start using stack (TestGetEngineRepositoryPath() & \
         "/ide-support/revdocsparser.livecodescript")
   put the temporary folder & "/oxt-extension-utils-scriptlibrary-" & the milliseconds into sFolder
   create folder sFolder
   put 0 into sCount
end TestSetup

on TestTeardown
   __DeleteFolder sFolder
end TestTeardown

private command __DeleteFolder pFolder
   local tStack
   repeat for each line tFile in files(pFolder)
      put pFolder & "/" & tFile into tStack
      if tFile ends with ".livecodescript" and there is a stack tStack then
         delete stack tStack
      end if
      delete file tStack
   end repeat
   repeat for each line tSub in folders(pFolder)
      if tSub is not ".." then
         __DeleteFolder pFolder & "/" & tSub
      end if
   end repeat
   delete folder pFolder
end __DeleteFolder

-- A new folder in the test's folder, for one extension
private function __NewFolder
   add 1 to sCount
   local tFolder
   put sFolder & "/ext" & sCount into tFolder
   create folder tFolder
   return tFolder
end __NewFolder

-- A library's name, its own in each test, so that no two of the stacks
-- the tests open share one
private function __Name
   return "org.openxtalk.test.scriptlib" & sCount & "x" & the milliseconds
end __Name

private function __LibraryBlock pVersion
   local tBlock
   put "/**" & return & \
         "Title: Test Script Library" & return & \
         "Author: OXT-Beyond" & return into tBlock
   if pVersion is not empty then
      put "Version:" && pVersion & return after tBlock
   end if
   put "Description:" & return & "A library to test with." & return & \
         "*/" & return after tBlock
   return tBlock
end __LibraryBlock

private function __Handler pBody
   return "/**" & return & "Summary: Says hello." & return & "*/" & return & \
         "function tslHello" & return & pBody & return & \
         "end tslHello" & return
end __Handler

-- Writes pText as the folder's script library and builds its docs and
-- manifest as the Extension Builder does; returns the file's path
private function __Build pFolder, pName, pText
   local tPath
   put pFolder & "/" & pName & ".livecodescript" into tPath
   put textEncode(pText, "utf-8") into url ("binfile:" & tPath)

   local tSource, tScript, tAPI
   if there is a stack tPath then
      put the long id of stack tPath into tSource
      put the script of stack tPath into tScript
   else
      put tPath into tSource
      put pText into tScript
   end if
   dispatch function "revDocsGenerateDocsFileFromText" to stack "revDocsParser" \
         with tScript, tSource
   put the result into tAPI
   put textEncode(tAPI, "utf-8") into url ("binfile:" & pFolder & "/api.lcdoc")
   extensionGenerateManifestForLCSExtension "revDocsParser", pFolder
   return tPath
end __Build

private function __ManifestId pFolder
   local tDataA
   put extensionFetchMetadata(pFolder & "/manifest.xml") into tDataA
   return tDataA["name"]
end __ManifestId

on TestGoodLibraryHasNoProblems
   local tFolder, tName, tProblems
   put __NewFolder() into tFolder
   put __Name() into tName
   get __Build(tFolder, tName, "script" && quote & tName & quote & return & \
         __LibraryBlock("1.0.0") & __Handler("   return" && quote & "hello" & quote))
   put extensionScriptLibraryProblems(tFolder) into tProblems
   TestDiagnostic tProblems
   TestAssert "a library that builds has no problems", tProblems is empty
   TestAssert "and its manifest has its id", __ManifestId(tFolder) is tName
end TestGoodLibraryHasNoProblems

-- The schoolboy error: the library builds and installs, and none of its
-- handlers is there
on TestCompileErrorIsReportedByFileLine
   local tFolder, tName, tPath, tProblems, tText
   put __NewFolder() into tFolder
   put __Name() into tName
   put "script" && quote & tName & quote & return & \
         __LibraryBlock("1.0.0") & __Handler("   put (1 into tX") into tText
   put __Build(tFolder, tName, tText) into tPath
   put extensionScriptLibraryProblems(tFolder) into tProblems
   TestDiagnostic tProblems
   -- the line of "put (1 into tX" in the file
   local tLine
   put lineOffset("put (1 into tX", tText) into tLine
   TestAssert "one problem", the number of lines of tProblems is 1
   TestAssert "it names the file and the line in the file", \
         tProblems begins with (tPath & ", line" && tLine & ":")
   TestAssert "it says what follows", \
         "none of its handlers until it compiles" is in tProblems
   TestAssert "the library itself is not changed", \
         the script of stack tPath contains "put (1 into tX"
end TestCompileErrorIsReportedByFileLine

on TestNoLibraryBlockIsReported
   local tFolder, tName, tProblems
   put __NewFolder() into tFolder
   put __Name() into tName
   get __Build(tFolder, tName, "script" && quote & tName & quote & return & \
         __Handler("   return 1"))
   put extensionScriptLibraryProblems(tFolder) into tProblems
   TestDiagnostic tProblems
   TestAssert "the manifest has no id", __ManifestId(tFolder) is empty
   TestAssert "the problem says there is no library block", \
         tProblems begins with "No library block was found in the docs of"
   TestAssert "and what one needs", \
         "with a Title: and a Version: line" is in tProblems
end TestNoLibraryBlockIsReported

on TestNoVersionIsReported
   local tFolder, tName, tProblems
   put __NewFolder() into tFolder
   put __Name() into tName
   get __Build(tFolder, tName, "script" && quote & tName & quote & return & \
         __LibraryBlock("") & __Handler("   return 1"))
   put extensionScriptLibraryProblems(tFolder) into tProblems
   TestDiagnostic tProblems
   TestAssert "the manifest has its id", __ManifestId(tFolder) is tName
   TestAssert "the problem says there is no version", \
         "has no Version: line" is in tProblems and the number of lines of tProblems is 1
end TestNoVersionIsReported

on TestNotAStackIsReported
   local tFolder, tPath, tProblems
   put __NewFolder() into tFolder
   put tFolder & "/notastack.livecodescript" into tPath
   put textEncode(__LibraryBlock("1.0.0") & __Handler("   return 1"), "utf-8") \
         into url ("binfile:" & tPath)
   put extensionScriptLibraryProblems(tFolder) into tProblems
   TestDiagnostic tProblems
   TestAssert "a file with no script line is not a stack", \
         tProblems begins with (tPath && "could not be opened as a stack")
end TestNotAStackIsReported

on TestFolderWithTwoMainFilesIsReported
   local tFolder, tProblems
   put __NewFolder() into tFolder
   put "script" && quote & "a" & quote & return into url ("file:" & tFolder & "/one.livecodescript")
   put "script" && quote & "b" & quote & return into url ("file:" & tFolder & "/two.livecodescript")
   put extensionScriptLibraryProblems(tFolder) into tProblems
   TestDiagnostic tProblems
   TestAssert "two main files are reported on one line", \
         tProblems begins with "Invalid extension folder" and \
         the number of lines of tProblems is 1
end TestFolderWithTwoMainFilesIsReported

on TestBuilderExtensionHasNoProblems
   local tFolder
   put __NewFolder() into tFolder
   put "library org.openxtalk.test.lcb" & return & "end library" & return \
         into url ("file:" & tFolder & "/test.lcb")
   TestAssert "a LiveCode Builder extension is not checked", \
         extensionScriptLibraryProblems(tFolder) is empty
end TestBuilderExtensionHasNoProblems

-- A package that fails part way is deleted, not left beside the extension.
-- The failure is made here, by this script in front of the zip external
-- refusing the manifest, so that it does not hang on what one platform's
-- libzip or file system refuses (a link to a missing file failed on one
-- and was packaged on another).
local sRefuseItem

on revZipAddItemWithFile pArchive, pItem, pFile
   if sRefuseItem is not empty and pItem is sRefuseItem then
      return "ziperr,refused by the test"
   end if
   pass revZipAddItemWithFile
end revZipAddItemWithFile

on TestFailedPackageIsNotLeftBehind
   local tFolder, tName, tPackage, tResult
   put __NewFolder() into tFolder
   put __Name() into tName
   get __Build(tFolder, tName, "script" && quote & tName & quote & return & \
         __LibraryBlock("1.0.0") & __Handler("   return 1"))
   put tFolder & "/" & tName & ".1.0.0.lce" into tPackage
   
   put "manifest.xml" into sRefuseItem
   insert the script of me into front
   extensionPackage tFolder, "", false
   put the result into tResult
   remove the script of me from front
   put empty into sRefuseItem
   TestDiagnostic tResult
   TestAssert "the package fails", tResult is "couldn't add manifest"
   TestAssert "and no package is left", there is not a file tPackage
   
   extensionPackage tFolder, "", false
   put the result into tResult
   TestDiagnostic tResult
   TestAssert "the same folder packages when nothing refuses it", \
         tResult is empty and there is a file tPackage
end TestFailedPackageIsNotLeftBehind
