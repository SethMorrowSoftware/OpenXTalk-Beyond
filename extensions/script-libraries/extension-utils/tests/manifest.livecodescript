script "TestExtensionUtilsManifest"
-- OXT-Beyond: tests of extensionGenerateManifestForLCSExtension, which
-- writes a script library's manifest from its docs when the library is
-- built. A library named in its kLibrariesFoundByHandlers (the Mobile Web
-- library) gets a <handler> entry for each command and function its docs
-- describe, so that "Search for required inclusions" in the standalone
-- builder finds it in a stack that calls them. Every other library's
-- manifest is written as it was before, without handlers, so the
-- standalones of stacks built before keep their inclusions.

local sFolder

on TestSetup
   TestSkipIfNot "externals", "revxml"
   TestLoadExternal "revxml"
   start using stack (TestGetEngineRepositoryPath() & \
         "/extensions/script-libraries/extension-utils/extension-utils.livecodescript")
   start using stack (TestGetEngineRepositoryPath() & \
         "/ide-support/revdocsparser.livecodescript")
   put the temporary folder & "/oxt-extension-utils-manifest-" & the milliseconds into sFolder
   create folder sFolder
end TestSetup

on TestTeardown
   repeat for each line tFile in files(sFolder)
      delete file (sFolder & "/" & tFile)
   end repeat
   delete folder sFolder
end TestTeardown

-- The docs of a library with two commands, a function, a message and a
-- second entry for one of the commands, as extensionExtractDocs writes
-- them into api.lcdoc.
private function __Docs pLibrary
   local tDocs, tEntry
   put "Library: " & pLibrary & return & return & \
         "Type: library" & return & return & \
         "Title: Test Library" & return & return & \
         "Author: OXT-Beyond" & return & return & \
         "Version: 1.0.0" & return & return & \
         "Description:" & return & "A library to test with." & return & return into tDocs
   repeat for each item tEntry in "tlStart command,tlStop command,tlReady function,tlSaid message,tlStart command"
      put "Name: " & word 1 of tEntry & return & return & \
            "Type: " & word 2 of tEntry & return & return & \
            "Syntax: " & word 1 of tEntry & return & return & \
            "Summary: Does a thing." & return & return & \
            "Description:" & return & "Does a thing." & return & return after tDocs
   end repeat
   return tDocs
end __Docs

private function __ManifestOf pLibrary
   put textEncode(__Docs(pLibrary), "utf-8") into url ("binfile:" & sFolder & "/api.lcdoc")
   extensionGenerateManifestForLCSExtension "revDocsParser", sFolder
   return extensionFetchMetadata(sFolder & "/manifest.xml")
end __ManifestOf

on TestMobileWebManifestNamesItsHandlers
   local tDataA
   put __ManifestOf("com.livecode.library.mobileweb") into tDataA
   TestDiagnostic url ("file:" & sFolder & "/manifest.xml")
   TestAssert "the manifest is of the library", \
         tDataA["name"] is "com.livecode.library.mobileweb"
   TestAssert "its commands and functions are named, each once, messages not", \
         tDataA["handlers"] is ("tlStart" & return & "tlStop" & return & "tlReady")
end TestMobileWebManifestNamesItsHandlers

on TestOtherManifestsNameNoHandlers
   local tDataA, tManifest
   put __ManifestOf("com.livecode.library.test") into tDataA
   put url ("file:" & sFolder & "/manifest.xml") into tManifest
   TestDiagnostic tManifest
   TestAssert "the manifest is of the library", \
         tDataA["name"] is "com.livecode.library.test"
   TestAssert "no handlers are named", tDataA["handlers"] is empty
   TestAssert "the manifest has no handler entry", \
         "<handler" is not in tManifest
   TestAssert "the rest is written as before", \
         tDataA["title"] is "Test Library" and tDataA["author"] is "OXT-Beyond" and \
         tDataA["version"] is "1.0.0" and tDataA["type"] is "library"
end TestOtherManifestsNameNoHandlers
