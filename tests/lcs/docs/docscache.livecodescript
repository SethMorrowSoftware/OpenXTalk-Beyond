script "TestDocsCache"
-- OXT-Beyond: tests of the IDE's documentation cache
-- (ide/Toolset/libraries/revidedocumentationlibrary.livecodescript), with a
-- stand-in for the IDE handlers it calls. Every build of one engine version
-- shares one cache folder, and its api.sqlite used to be copied from the
-- distributed one only when there was none: a cache an older build made was
-- kept for good, and one made while no api.sqlite shipped held only the
-- extensions' docs, so the Script Editor and the xTalk Assistant found no
-- entry for "put". The cache now notes the distributed file it holds and,
-- when that changes, takes the distributed libraries' entries afresh and
-- keeps the extensions'. An uninstalled extension's entries leave it
-- (ideDocsRemoveLibrary), and they used to stay (openxtalk.org p=25441).

constant kStub = "revDocsCacheTestIDE"

-- This test's folders: the distributed dictionary's and the cache's
local sFolder, sDistFolder, sCacheFolder

on TestSetup
   local tStub
   TestSkipIfNot "docs"
   TestSkipIfNot "database", "sqlite"
   TestLoadExternal "revdb"

   start using stack (TestGetEngineRepositoryPath() & "/ide-support/revdocsparser.livecodescript")

   put specialFolderPath("temporary") & "/oxt-docs-cache-" & the milliseconds into sFolder
   put sFolder & "/dist" into sDistFolder
   put sFolder & "/cache" into sCacheFolder
   create folder sFolder
   create folder sDistFolder
   create folder sCacheFolder

   -- The IDE's handlers the library calls, the folders from this test
   put "function revIDESpecialFolderPath pKey" & return & \
         "if pKey is `API` then" & return & "return the cDistFolder of me" & return & \
         "else if pKey is `documentation cache` then" & return & "return the cCacheFolder of me" & return & \
         "end if" & return & "return empty" & return & "end revIDESpecialFolderPath" & return & \
         "function revEnvironmentIsInstalled" & return & "return true" & return & \
         "end revEnvironmentIsInstalled" & return & \
         "on ideThrow pMessage, pDetail" & return & "throw pMessage & return & pDetail" & return & \
         "end ideThrow" & return into tStub
   replace "`" with quote in tStub
   create stack kStub
   set the script of stack kStub to tStub
   set the cDistFolder of stack kStub to sDistFolder
   set the cCacheFolder of stack kStub to sCacheFolder
   start using stack kStub

   start using stack (TestGetIDERepositoryPath() & "/Toolset/libraries/revidedocumentationlibrary.livecodescript")
end TestSetup

on TestTeardown
   __CloseCache
   if sFolder is not empty and there is a folder sFolder then
      __DeleteFolder sFolder
   end if
end TestTeardown

--------------------------------------------------------------------------------
-- Helpers

-- Adds a library's entries (pEntries: "name,type" lines) under API pAPI to
-- the api.sqlite in pFolder, as the IDE writes them
private command __AddDocs pFolder, pAPI, pLibrary, pEntries
   local tConnection, tLibraryA, tCount, tResult
   revDocsOpenAPIDatabase pFolder
   put the result into tConnection
   if tConnection is not a number then
      throw "unable to open" && pFolder & return & tConnection
   end if
   put pLibrary into tLibraryA["display name"]
   repeat for each line tLine in pEntries
      add 1 to tCount
      put item 1 of tLine into tLibraryA["doc"][tCount]["display name"]
      put item 1 of tLine into tLibraryA["doc"][tCount]["name"]
      put item 2 of tLine into tLibraryA["doc"][tCount]["type"]
      put pLibrary into tLibraryA["doc"][tCount]["library"]
   end repeat
   revExecuteSQL tConnection, "BEGIN TRANSACTION"
   revDocsUpdateDatabase tConnection, pAPI, tLibraryA
   put the result into tResult
   revExecuteSQL tConnection, "COMMIT"
   revCloseDatabase tConnection
   if tResult is not empty then
      throw "unable to add" && pLibrary & return & tResult
   end if
end __AddDocs

-- The distributed dictionary: the core libraries, as the build makes it
private command __MakeDistributed pScriptEntries
   __AddDocs sDistFolder, "livecode_script", "LiveCode Script", pScriptEntries
   __AddDocs sDistFolder, "livecode_builder", "LiveCode Builder", "variable,statement"
   __AddDocs sDistFolder, "livecode_script", "Data Grid", "dgText,property"
end __MakeDistributed

-- How many entries a lookup of pTerm in the xTalk Script dictionary finds,
-- through the library as the Script Editor and the xTalk Assistant look
private function __Found pTerm
   local tEntries
   put ideDocsFetchLCSData(pTerm) into tEntries
   if tEntries is not an array then
      return 0
   end if
   return the number of elements of tEntries
end __Found

-- How many entries a lookup of pTerm finds in every library of the xTalk
-- Script API, extensions' included, as the Script Editor's documentation
-- pane looks
private function __FoundInAny pTerm
   local tEntries
   put ideDocsFetchScriptData(pTerm) into tEntries
   if tEntries is not an array then
      return 0
   end if
   return the number of elements of tEntries
end __FoundInAny

-- Every entry of the cache, "library:name" lines, sorted
private function __CacheEntries
   local tConnection, tEntries
   put revOpenDatabase("sqlite", sCacheFolder & "/api.sqlite",,,,,,) into tConnection
   put revDataFromQuery(":", return, tConnection, \
         "SELECT library_name, entry_name FROM dictionary_data") into tEntries
   revCloseDatabase tConnection
   sort lines of tEntries
   return tEntries
end __CacheEntries

private function __Digest pFile
   local tHex
   get binaryDecode("H*", md5Digest(url ("binfile:" & pFile)), tHex)
   return tHex
end __Digest

private function __Note
   return url ("binfile:" & sCacheFolder & "/api.sqlite.source")
end __Note

-- Closes the library's cache connection (the only one these tests leave
-- open), as quitting the IDE does: the next lookup opens it again, as the
-- next session's first does
private command __CloseCache
   try
      repeat for each item tConnection in revOpenDatabases()
         revCloseDatabase tConnection
      end repeat
   catch tError
   end try
end __CloseCache

private command __DeleteFolder pFolder
   repeat for each line tFile in files(pFolder)
      delete file (pFolder & slash & tFile)
   end repeat
   repeat for each line tSub in folders(pFolder)
      if tSub is not among the items of ".,.." then
         __DeleteFolder pFolder & slash & tSub
      end if
   end repeat
   delete folder pFolder
end __DeleteFolder

--------------------------------------------------------------------------------
-- Tests

-- The first lookup with no cache copies the distributed file, and notes it,
-- so it is not taken again
on TestFreshCacheIsACopy
   __MakeDistributed "put,command" & return & "menuPick,message"
   TestAssert "put found", __Found("put") is 1
   TestAssert "menuPick found", __Found("menuPick") is 1
   TestAssert "the cache is the distributed file", \
         __Digest(sCacheFolder & "/api.sqlite") is __Digest(sDistFolder & "/api.sqlite")
   TestAssert "the cache notes the distributed file", __Note() is __Digest(sDistFolder & "/api.sqlite")
end TestFreshCacheIsACopy

-- A cache that holds only extensions' docs, as one made while no
-- api.sqlite shipped does, gets the core entries and keeps the extensions'
on TestCacheOfExtensionsOnly
   local tEntries
   __AddDocs sCacheFolder, "livecode_script", "Tree View", "treeViewSelect,message" & return & "pathDelimiter,property"
   __MakeDistributed "put,command" & return & "menuPick,message" & return & "menubar,property"

   TestAssert "put found", __Found("put") is 1
   TestAssert "menuPick found", __Found("menuPick") is 1
   TestAssert "menuBar found whatever its case", __Found("menuBar") is 1
   put __CacheEntries() into tEntries
   TestDiagnostic tEntries
   TestAssert "extension entries kept", "Tree View:treeViewSelect" is among the lines of tEntries \
         and "Tree View:pathDelimiter" is among the lines of tEntries
   TestAssert "builder entries in", "LiveCode Builder:variable" is among the lines of tEntries
   TestAssert "Data Grid entries in", "Data Grid:dgText" is among the lines of tEntries
   TestAssert "nothing twice", the number of lines of tEntries is 7
   TestAssert "the cache notes the distributed file", __Note() is __Digest(sDistFolder & "/api.sqlite")
   TestAssert "the library names", ideDocsFetchLibraryNames() is \
         "Data Grid" & return & "LiveCode Builder" & return & "LiveCode Script" & return & "Tree View"
end TestCacheOfExtensionsOnly

-- An empty cache file, as the copy of a missing file leaves, has no tables
on TestEmptyCacheFile
   put empty into url ("binfile:" & sCacheFolder & "/api.sqlite")
   __MakeDistributed "put,command"
   TestAssert "put found", __Found("put") is 1
   TestAssert "the cache notes the distributed file", __Note() is __Digest(sDistFolder & "/api.sqlite")
end TestEmptyCacheFile

-- With no distributed file the cache is left as it is and nothing is noted;
-- once one ships, the next session takes its entries
on TestDistributedFileArrivesLater
   __AddDocs sCacheFolder, "livecode_script", "Tree View", "treeViewSelect,message"
   TestAssert "nothing found while none ships", __Found("put") is 0
   TestAssert "nothing noted", there is not a file (sCacheFolder & "/api.sqlite.source")
   TestAssert "extension entries as they were", __CacheEntries() is "Tree View:treeViewSelect"

   __CloseCache
   __MakeDistributed "put,command"
   TestAssert "put found once it ships", __Found("put") is 1
   TestAssert "extension entries kept", "Tree View:treeViewSelect" is among the lines of __CacheEntries()
end TestDistributedFileArrivesLater

-- The cache is taken from the distributed file once: a later session with
-- the same file changes nothing, and a new file replaces the core entries
-- (one it no longer has goes) and keeps the extensions'
on TestNewDistributedFileReplacesCoreEntries
   local tConnection, tEntries
   __AddDocs sCacheFolder, "livecode_script", "Tree View", "treeViewSelect,message"
   __MakeDistributed "put,command" & return & "oldEntry,command"
   TestAssert "put found", __Found("put") is 1
   TestAssert "oldEntry found", __Found("oldEntry") is 1
   __CloseCache

   -- A mark in the cache that taking the distributed entries again would remove
   __AddDocs sCacheFolder, "livecode_script", "LiveCode Script", "mark,command"
   TestAssert "the same file is not taken again", __Found("mark") is 1
   __CloseCache

   -- The next release's file
   delete file (sDistFolder & "/api.sqlite")
   __MakeDistributed "put,command" & return & "find,command"
   TestAssert "the new entry found", __Found("find") is 1
   TestAssert "the old entry gone", __Found("oldEntry") is 0
   TestAssert "the mark gone", __Found("mark") is 0
   TestAssert "put found once", __Found("put") is 1
   put __CacheEntries() into tEntries
   TestDiagnostic tEntries
   TestAssert "extension entries kept", "Tree View:treeViewSelect" is among the lines of tEntries
   TestAssert "nothing twice", the number of lines of tEntries is 5
   TestAssert "the cache notes the new file", __Note() is __Digest(sDistFolder & "/api.sqlite")
end TestNewDistributedFileReplacesCoreEntries

-- A distributed file that is not a dictionary changes nothing, and is tried
-- again next session
on TestBrokenDistributedFile
   __AddDocs sCacheFolder, "livecode_script", "Tree View", "treeViewSelect,message"
   put "not a database" into url ("binfile:" & sDistFolder & "/api.sqlite")
   TestAssert "nothing found", __Found("put") is 0
   TestAssert "extension entry still found", the number of elements of ideDocsFetchScriptData("treeViewSelect") is 1
   TestAssert "nothing noted", there is not a file (sCacheFolder & "/api.sqlite.source")
   TestAssert "extension entries as they were", __CacheEntries() is "Tree View:treeViewSelect"
end TestBrokenDistributedFile

-- An uninstalled extension's entries leave the cache (ideDocsRemoveLibrary,
-- as revIDEExtensionUninstall calls it), and every other library's stay,
-- among them a library of the same name under another API
on TestRemoveLibrary
   local tEntries
   __AddDocs sCacheFolder, "livecode_script", "Tree View", "treeViewSelect,message" & return & "pathDelimiter,property"
   __AddDocs sCacheFolder, "livecode_builder", "Tree View", "TreeViewNode,type"
   __MakeDistributed "put,command"
   TestAssert "the extension's entry found", __FoundInAny("treeViewSelect") is 1

   ideDocsRemoveLibrary "livecode_script", "Tree View"
   TestAssert "removed with no error", the result is empty
   TestAssert "its entry gone", __FoundInAny("treeViewSelect") is 0
   put __CacheEntries() into tEntries
   TestDiagnostic tEntries
   TestAssert "nothing of it left under its API", "Tree View:pathDelimiter" is not among the lines of tEntries
   TestAssert "the same name under another API kept", "Tree View:TreeViewNode" is among the lines of tEntries
   TestAssert "the core entries kept", __Found("put") is 1 and "Data Grid:dgText" is among the lines of tEntries
   TestAssert "nothing else gone", the number of lines of tEntries is 4
end TestRemoveLibrary

-- An extension the user installed under the name of a library the
-- distributed file documents (here the Data Grid's) wrote its entries over
-- the distributed ones, with one the distributed library lacks: once it is
-- uninstalled, the distributed entries are back, and only they
on TestRemoveLibraryOfADistributedName
   local tEntries
   __MakeDistributed "put,command"
   TestAssert "the distributed entry found", __FoundInAny("dgText") is 1
   __CloseCache

   -- The extension's, as revIDEGetExtensionDocsData writes them
   __AddDocs sCacheFolder, "livecode_script", "Data Grid", "dgText,property" & return & "dgExtra,command"
   TestAssert "the extension's entry found", __FoundInAny("dgExtra") is 1

   ideDocsRemoveLibrary "livecode_script", "Data Grid"
   TestAssert "removed with no error", the result is empty
   TestAssert "the extension's entry gone", __FoundInAny("dgExtra") is 0
   TestAssert "the distributed entry back, once", __FoundInAny("dgText") is 1
   put __CacheEntries() into tEntries
   TestDiagnostic tEntries
   TestAssert "the core entries kept", __Found("put") is 1 and "LiveCode Builder:variable" is among the lines of tEntries
   TestAssert "nothing twice", the number of lines of tEntries is 3
end TestRemoveLibraryOfADistributedName

-- A library or an API the cache does not have is nothing to remove
on TestRemoveLibraryNotInTheCache
   __AddDocs sCacheFolder, "livecode_script", "Tree View", "treeViewSelect,message"
   __MakeDistributed "put,command"
   ideDocsRemoveLibrary "livecode_script", "No Such Library"
   TestAssert "an unknown library is no error", the result is empty
   ideDocsRemoveLibrary "no_such_api", "Tree View"
   TestAssert "an unknown API is no error", the result is empty
   TestAssert "the extension's entry kept", __FoundInAny("treeViewSelect") is 1
   TestAssert "the core entry kept", __Found("put") is 1
end TestRemoveLibraryNotInTheCache

-- With a distributed file that is not a dictionary, or none, the
-- extension's entries still go, and nothing comes back
on TestRemoveLibraryWithNoDistributedFile
   __AddDocs sCacheFolder, "livecode_script", "Tree View", "treeViewSelect,message"
   __AddDocs sCacheFolder, "livecode_script", "Other", "otherThing,command"
   put "not a database" into url ("binfile:" & sDistFolder & "/api.sqlite")
   ideDocsRemoveLibrary "livecode_script", "Tree View"
   TestAssert "removed with no error", the result is empty
   TestAssert "only the other library left", __CacheEntries() is "Other:otherThing"

   __CloseCache
   delete file (sDistFolder & "/api.sqlite")
   ideDocsRemoveLibrary "livecode_script", "Other"
   TestAssert "removed with no file", the result is empty
   TestAssert "nothing left", __CacheEntries() is empty
end TestRemoveLibraryWithNoDistributedFile

-- A cache file with no tables, as the copy of a missing file leaves, has
-- nothing to remove
on TestRemoveLibraryFromAnEmptyCache
   put empty into url ("binfile:" & sCacheFolder & "/api.sqlite")
   ideDocsRemoveLibrary "livecode_script", "Tree View"
   TestAssert "no error", the result is empty
   TestAssert "nothing in it", __CacheEntries() is empty
end TestRemoveLibraryFromAnEmptyCache

--------------------------------------------------------------------------------
-- The docs of the externals the user added (ideDocsUserExternalsDocs,
-- ideDocsNoteUserExternalsDocs): their .lcdoc files were never read, and
-- went into the Dictionary only wrapped in an LCB library (Skids,
-- openxtalk.org p=25608)

private command __WriteFile pFile, pText
   local tFolder
   set the itemDelimiter to slash
   put item 1 to -2 of pFile into tFolder
   if there is not a folder tFolder then
      create folder tFolder
   end if
   put textEncode(pText, "utf-8") into url ("binfile:" & pFile)
end __WriteFile

-- "key|title|file name" lines of what ideDocsUserExternalsDocs finds
private function __ExternalsDocs pFolder
   local tDocsA, tLines
   put ideDocsUserExternalsDocs(pFolder) into tDocsA
   set the itemDelimiter to slash
   repeat with tIndex = 1 to the number of elements of tDocsA
      put tDocsA[tIndex]["key"] & "|" & tDocsA[tIndex]["title"] & "|" & \
            item -1 of tDocsA[tIndex]["file"] & return after tLines
   end repeat
   delete the last char of tLines
   return tLines
end __ExternalsDocs

-- A folder with no .lcdoc, as every one was, gives nothing, and so does
-- one that is not there
on TestUserExternalsWithoutDocs
   local tExternals
   put sFolder & "/Externals" into tExternals
   TestAssert "no folder, no docs", __ExternalsDocs(tExternals) is empty
   __WriteFile tExternals & "/Externals.txt", "blur,blur.so"
   __WriteFile tExternals & "/blur.so", "not an external"
   create folder tExternals & "/Legacy"
   TestAssert "no .lcdoc, no docs", __ExternalsDocs(tExternals) is empty
   TestAssert "empty folder name, no docs", __ExternalsDocs(empty) is empty
end TestUserExternalsWithoutDocs

-- A .lcdoc beside the externals, in a folder of one and in a bundle, each
-- once, under its own Library name or else its file's (or folder's)
on TestUserExternalsDocsFound
   local tExternals, tFound
   put sFolder & "/Externals" into tExternals
   __WriteFile tExternals & "/blur.lcdoc", "Library: Blur" & return & return & "Name: blur" & return
   -- (indented, as LiveCode's own blur.lcdoc is)
   __WriteFile tExternals & "/indented.lcdoc", " Library: Indented" & return & return & " Name: indented" & return
   __WriteFile tExternals & "/noname.lcdoc", "Name: nonameCommand" & return
   __WriteFile tExternals & "/mergFoo/api.lcdoc", "Library:  mergFoo Lib  " & numToChar(13) & numToChar(10)
   __WriteFile tExternals & "/rreThing.bundle/Contents/Resources/api.lcdoc", "Name: rreThing" & return
   __WriteFile tExternals & "/rreThing.bundle/Contents/Resources/notdocs.txt", "Library: no"
   __WriteFile tExternals & "/rreThing.bundle/api.lcdoc", "Name: rreThing" & return
   put __ExternalsDocs(tExternals) into tFound
   TestDiagnostic tFound
   TestAssert "beside the externals, by Library name", "blur|Blur|blur.lcdoc" is among the lines of tFound
   TestAssert "beside the externals, by file name", "noname|noname|noname.lcdoc" is among the lines of tFound
   TestAssert "in a folder, by Library name, CRLF", "mergFoo_api|mergFoo Lib|api.lcdoc" is among the lines of tFound
   TestAssert "a bundle's, by its name", "rreThing.bundle_api|rreThing|api.lcdoc" is among the lines of tFound
   TestAssert "an indented Library name", "indented|Indented|indented.lcdoc" is among the lines of tFound
   TestAssert "each once", the number of lines of tFound is 5
end TestUserExternalsDocsFound

-- The cache notes each one's library, and when its .lcdoc goes, its
-- folder and its entries go, but not a library another still has, nor an
-- installed extension's
on TestUserExternalsDocsForgotten
   local tExternals, tCache, tDocsA, tEntries
   put sFolder & "/Externals" into tExternals
   put sFolder & "/userdocs/Externals" into tCache
   __MakeDistributed "put,command"
   __AddDocs sCacheFolder, "livecode_script", "Blur", "blur,command"
   __AddDocs sCacheFolder, "livecode_script", "Tree View", "treeViewSelect,message"
   TestAssert "put found", __Found("put") is 1

   __WriteFile tExternals & "/blur.lcdoc", "Library: Blur" & return
   __WriteFile tExternals & "/other.lcdoc", "Library: Tree View" & return
   put ideDocsUserExternalsDocs(tExternals) into tDocsA
   ideDocsNoteUserExternalsDocs tCache, tDocsA, "Tree View"
   TestAssert "a folder for each", there is a folder (tCache & "/blur") and there is a folder (tCache & "/other")
   TestAssert "its library noted", url ("binfile:" & tCache & "/blur/library.txt") is "Blur"
   TestAssert "entries kept while there", "Blur:blur" is among the lines of __CacheEntries()

   delete file tExternals & "/blur.lcdoc"
   delete file tExternals & "/other.lcdoc"
   put ideDocsUserExternalsDocs(tExternals) into tDocsA
   ideDocsNoteUserExternalsDocs tCache, tDocsA, "Tree View"
   put __CacheEntries() into tEntries
   TestDiagnostic tEntries
   TestAssert "its folder gone", there is not a folder (tCache & "/blur")
   TestAssert "the other's folder gone", there is not a folder (tCache & "/other")
   TestAssert "its entries gone", "Blur:blur" is not among the lines of tEntries
   TestAssert "an installed extension's kept", "Tree View:treeViewSelect" is among the lines of tEntries
   TestAssert "the distributed kept", "LiveCode Script:put" is among the lines of tEntries
end TestUserExternalsDocsForgotten
