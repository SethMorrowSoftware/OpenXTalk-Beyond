script "TestCommunityStacks"
-- OXT-Beyond: tests of File > Community Stacks...
-- (ide/Toolset/palettes/community/revcommunitystacks.livecodescript), the
-- gallery of shared stacks in the IDE: that the list of stacks is
-- believed only with the gallery's signature, that every word of it is
-- held to the gallery's own rules, that a copy is only ever the bytes
-- the signed list names, written only where it belongs, and that opening
-- a copy to look at runs none of it. The window itself is run by the IDE
-- tour's step community-stacks (tools/ci/ui-tour.livecodescript).
--
-- The signature tests need SodiumXT, from $XTALK_SUITE_EXTENSIONS (the
-- folder tools/oxt/xtalk_extensions.py build writes); without it they
-- are skipped, and the tour's step runs the same checks in a packaged
-- IDE, where SodiumXT is built in.

local sLib, sFolder, sFound, sSodium
-- A signing keypair made for the test (binary), and its public half as
-- signing-key.pub would hold it
local sPublic, sSecret, sPublicText

global gTestCommunityStacksRan

on TestSetup
   TestSkipIfNot "ide"
   TestLoadExtension "com.livecode.library.json"
   TestLoadExternal "revzip"
   put there is a stack "revCommunityStacks" into sFound
   put TestGetIDERepositoryPath() & "/Toolset/palettes/community/revcommunitystacks.livecodescript" into sLib
   get the short name of stack sLib
   put the tempName & "-communitystacks" into sFolder
   create folder sFolder
   put __LoadSodium() into sSodium
   if sSodium then
      sxSignKeypair sPublic, sSecret
      put base64Encode(sPublic) into sPublicText
   end if
   put empty into gTestCommunityStacksRan
end TestSetup

on TestTeardown
   local tName
   repeat for each item tName in "TestCommunitySample,revTestCommunityNamed"
      if there is a stack tName then
         lock messages
         delete stack tName
         unlock messages
      end if
   end repeat
   __RemoveFolder sFolder
   if sFound is not true and there is a stack "revCommunityStacks" then
      delete stack "revCommunityStacks"
   end if
end TestTeardown

private command __RemoveFolder pFolder
   local tName
   if pFolder is empty or there is no folder pFolder then
      exit __RemoveFolder
   end if
   repeat for each line tName in files(pFolder)
      delete file (pFolder & slash & tName)
   end repeat
   repeat for each line tName in folders(pFolder)
      if tName is not "." and tName is not ".." then
         __RemoveFolder pFolder & slash & tName
      end if
   end repeat
   delete folder pFolder
end __RemoveFolder

-- SodiumXT from $XTALK_SUITE_EXTENSIONS, as the IDE loads it; true when
-- it answers
private function __LoadSodium
   local tE, tCode, tLib, tError
   try
      get sxSignVerifyDetached("x", "y", "z")
      return true
   catch tError
   end try
   put $XTALK_SUITE_EXTENSIONS into tE
   if tE is empty or there is not a folder tE then
      return false
   end if
   switch the platform
      case "Win32"
         put "x86_64-win32" into tCode
         put "sodiumxt.dll" into tLib
         break
      case "MacOS"
         put "universal-mac" into tCode
         put "sodiumxt.dylib" into tLib
         break
      default
         put "x86_64-linux" into tCode
         put "sodiumxt.so" into tLib
   end switch
   try
      set the revLibraryMapping["sodiumxt"] to tE & "/org.openxtalk.library.sodium/code/" & tCode & "/" & tLib
      load extension from file (tE & "/org.openxtalk.library.sodium/module.lcm") with resource path (tE & "/org.openxtalk.library.sodium")
      sxSignKeypair sPublic, sSecret
   catch tError
      return false
   end try
   return the number of bytes of sPublic is 32
end __LoadSodium

private function __NeedsSodium pTest
   if sSodium is not true then
      TestSkip pTest, "SodiumXT is not loaded (XTALK_SUITE_EXTENSIONS)"
      return false
   end if
   return true
end __NeedsSodium

--------------------------------------------------------------------------------
-- Calling the library

private function __Verify pIndex, pSignature, pKey
   dispatch function "revCommunityStacksVerify" to stack sLib with pIndex, pSignature, pKey
   return the result
end __Verify

private function __Parse pIndex
   dispatch function "revCommunityStacksParse" to stack sLib with pIndex
   return the result
end __Parse

private function __Load pSite, pKey
   dispatch function "revCommunityStacksLoad" to stack sLib with pSite, pKey
   return the result
end __Load

private function __Get pEntry, pFolder, pSite
   dispatch "revCommunityStacksGet" to stack sLib with pEntry, pFolder, pSite
   return the result
end __Get

private function __Open pFile
   dispatch "revCommunityStacksOpenToRead" to stack sLib with pFile
   return the result
end __Open

--------------------------------------------------------------------------------
-- A gallery made for the test

private function __Sha256 pData
   local tHex
   get binaryDecode("H*", messageDigest(pData, "sha-256"), tHex)
   return toLower(tHex)
end __Sha256

-- The signature of pData with the test's key (or pSecret), on one line
-- as index.sig holds it (base64Encode breaks its lines at 72)
private function __Sign pData, pSecret
   local tText
   if pSecret is empty then
      put sSecret into pSecret
   end if
   put base64Encode(sxSignDetached(pData, pSecret)) into tText
   replace return with empty in tText
   return tText
end __Sign

private function __Q pText
   replace "\" with "\\" in pText
   replace quote with "\" & quote in pText
   replace return with "\n" in pText
   replace tab with "\t" in pText
   return quote & pText & quote
end __Q

-- The bytes of a stack named pName, whose opening scripts would set
-- gTestCommunityStacksRan; with a substack named pSubstack when one is
-- given
private function __StackBytes pName, pSubstack
   local tFile, tData, tSaved
   put the defaultStack into tSaved
   reset the templateStack
   lock messages
   create invisible stack pName
   set the script of stack pName to "global gTestCommunityStacksRan" & return & \
         "on preOpenStack" & return & "put true into gTestCommunityStacksRan" & return & "end preOpenStack" & return & \
         "on openStack" & return & "put true into gTestCommunityStacksRan" & return & "end openStack" & return & \
         "on preOpenCard" & return & "put true into gTestCommunityStacksRan" & return & "end preOpenCard" & return & \
         "on openCard" & return & "put true into gTestCommunityStacksRan" & return & "end openCard"
   if pSubstack is not empty then
      create invisible stack pSubstack
      set the mainStack of stack pSubstack to pName
   end if
   put sFolder & "/make-" & the milliseconds & "-" & random(100000) & ".oxtstack" into tFile
   save stack pName as tFile
   delete stack pName
   unlock messages
   set the defaultStack to tSaved
   put url ("binfile:" & tFile) into tData
   delete file tFile
   return tData
end __StackBytes

-- What a stack of the test's gallery is: a good one, as the gallery's
-- tools would write it. "stackData" and "notesData" are its two files
-- and "zipData" its download.
private function __Good
   local tA, tZip, tStack, tNotes, tExtra
   put __StackBytes("TestCommunitySample") into tStack
   put "Thank you for reading." & return into tNotes
   put "nobody listed this file" into tExtra
   put sFolder & "/zip-" & the milliseconds & "-" & random(100000) & ".zip" into tZip
   revZipOpenArchive tZip, "write"
   revZipAddItemWithData tZip, "Sample Stack.oxtstack", "tStack"
   revZipAddItemWithData tZip, "notes/readme.txt", "tNotes"
   -- (a file the list does not name: it must never be written)
   revZipAddItemWithData tZip, "stowaway.txt", "tExtra"
   revZipCloseArchive tZip
   put url ("binfile:" & tZip) into tA["zipData"]
   delete file tZip
   put tStack into tA["stackData"]
   put tNotes into tA["notesData"]
   put "sample-stack" into tA["slug"]
   put "1.2" into tA["version"]
   put "Sample Stack" into tA["title"]
   put "A. Name" into tA["author"]
   put "A stack made for a test. It does nothing at all, and does it well." into tA["description"]
   put "MIT" into tA["licence"]
   put "Sample Stack.oxtstack" into tA["main"]
   put "s/sample-stack/1.2/sample-stack-1.2.zip" into tA["download"]
   put "s/sample-stack/index.html" into tA["page"]
   put "s/sample-stack/play.html" into tA["play"]
   put "s/sample-stack/1.2/source.html" into tA["source"]
   put __Sha256(tA["zipData"]) into tA["sha256"]
   put the number of bytes of tA["zipData"] into tA["size"]
   put "Sample Stack.oxtstack" into tA["file1"]
   put __Sha256(tStack) into tA["file1sha"]
   put the number of bytes of tStack into tA["file1size"]
   put "notes/readme.txt" into tA["file2"]
   put __Sha256(tNotes) into tA["file2sha"]
   put the number of bytes of tNotes into tA["file2size"]
   put quote & "game" & quote & "," & quote & "puzzle" & quote into tA["tagsJson"]
   put quote & "files" & quote & "," & quote & "internet" & quote into tA["usesJson"]
   return tA
end __Good

-- One stack of the list, as JSON
private function __EntryJson pA
   local tFiles, tVersions
   put "{" & __Q("path") & ":" & __Q(pA["file1"]) & "," & __Q("sha256") & ":" & __Q(pA["file1sha"]) & "," & \
         __Q("size") & ":" & pA["file1size"] & "}" into tFiles
   if pA["file2"] is not empty then
      put ",{" & __Q("path") & ":" & __Q(pA["file2"]) & "," & __Q("sha256") & ":" & __Q(pA["file2sha"]) & "," & \
            __Q("size") & ":" & pA["file2size"] & "}" after tFiles
   end if
   put pA["versionsJson"] into tVersions
   if tVersions is empty then
      put "[{" & __Q("version") & ":" & __Q(pA["version"]) & "," & __Q("download") & ":" & __Q(pA["download"]) & "," & \
            __Q("sha256") & ":" & __Q(pA["sha256"]) & "," & __Q("size") & ":" & pA["size"] & "," & \
            __Q("files") & ":[" & tFiles & "]}]" into tVersions
   end if
   return "{" & __Q("slug") & ":" & __Q(pA["slug"]) & "," & __Q("version") & ":" & __Q(pA["version"]) & "," & \
         __Q("title") & ":" & __Q(pA["title"]) & "," & __Q("author") & ":" & __Q(pA["author"]) & "," & \
         __Q("description") & ":" & __Q(pA["description"]) & "," & __Q("licence") & ":" & __Q(pA["licence"]) & "," & \
         __Q("main") & ":" & __Q(pA["main"]) & "," & __Q("download") & ":" & __Q(pA["download"]) & "," & \
         __Q("page") & ":" & __Q(pA["page"]) & "," & __Q("play") & ":" & __Q(pA["play"]) & "," & \
         __Q("source") & ":" & __Q(pA["source"]) & "," & __Q("screenshot") & ":null," & \
         __Q("script_lines") & ":12," & \
         __Q("sha256") & ":" & __Q(pA["sha256"]) & "," & __Q("size") & ":" & pA["size"] & "," & \
         __Q("tags") & ":[" & pA["tagsJson"] & "]," & __Q("uses") & ":[" & pA["usesJson"] & "]," & \
         __Q("versions") & ":" & tVersions & "}"
end __EntryJson

-- The list, as the bytes of index.json, of the stacks given as JSON
private function __IndexBytes pEntriesJson
   return textEncode("{" & __Q("format") & ":1," & __Q("name") & ":" & __Q("Test Gallery") & "," & \
         __Q("stacks") & ":[" & pEntriesJson & "]}" & return, "utf-8")
end __IndexBytes

-- A stack of the list with one thing changed, as the list reads it:
-- how many stacks the list then has, and how many it leaves out
private function __Changed pKey, pValue
   local tA, tOut
   put __Good() into tA
   put pValue into tA[pKey]
   put __Parse(__IndexBytes(__EntryJson(tA))) into tOut
   return tOut["count"] & "," & tOut["leftOut"]
end __Changed

-- Writes the test's gallery into a folder of its own and returns it: the
-- list of the stack pA, its signature (when pSign) and its download
private function __Site pA, pSign
   local tSite, tIndex
   put sFolder & "/site-" & the milliseconds & "-" & random(100000) into tSite
   create folder tSite
   create folder (tSite & "/s")
   create folder (tSite & "/s/" & pA["slug"])
   create folder (tSite & "/s/" & pA["slug"] & "/" & pA["version"])
   put __IndexBytes(__EntryJson(pA)) into tIndex
   put tIndex into url ("binfile:" & tSite & "/index.json")
   if pSign then
      put __Sign(tIndex) & return into url ("binfile:" & tSite & "/index.sig")
   end if
   put pA["zipData"] into url ("binfile:" & tSite & "/" & pA["download"])
   return tSite
end __Site

--------------------------------------------------------------------------------
-- The address and the key

on TestSiteAndKey
   local tSite, tKey
   dispatch function "revCommunityStacksSite" to stack sLib
   put the result into tSite
   dispatch function "revCommunityStacksPublicKey" to stack sLib
   put the result into tKey
   TestAssert "the site is an https address that ends in a slash", tSite begins with "https://" and tSite ends with "/"
   TestAssert "the site is not openxtalk.org, where stacks must never be served", not (tSite contains "openxtalk.org")
   TestAssert "the key is one line of base64", the number of chars of tKey is 44 and the number of lines of tKey is 1
   TestAssert "the key is 32 bytes", the number of bytes of base64Decode(tKey) is 32
end TestSiteAndKey

--------------------------------------------------------------------------------
-- Believing the list

on TestVerify
   local tIndex, tSig, tOther, tOtherSecret, tChanged
   if not __NeedsSodium("the signature of the list") then
      exit TestVerify
   end if
   put __IndexBytes(empty) into tIndex
   put __Sign(tIndex) into tSig
   TestAssert "a good signature is believed", __Verify(tIndex, tSig, sPublicText) is empty
   TestAssert "as index.sig holds it, with its line end", __Verify(tIndex, tSig & return, sPublicText) is empty
   put tIndex into tChanged
   put "2" into char 11 of tChanged
   TestAssert "a list that was changed is not", __Verify(tChanged, tSig, sPublicText) is not empty
   TestAssert "nor a list that grew", __Verify(tIndex & space, tSig, sPublicText) is not empty
   sxSignKeypair tOther, tOtherSecret
   TestAssert "nor a list signed with another key", \
         __Verify(tIndex, __Sign(tIndex, tOtherSecret), sPublicText) is not empty
   TestAssert "nor when checked with another key", __Verify(tIndex, tSig, base64Encode(tOther)) is not empty
   TestAssert "the gallery's own key does not believe the test's", __Verify(tIndex, tSig, empty) is not empty
   TestAssert "no signature is not believed", __Verify(tIndex, empty, sPublicText) is not empty
   TestAssert "words are not a signature", __Verify(tIndex, "not a signature", sPublicText) is not empty
   TestAssert "a short signature is not one", __Verify(tIndex, char 1 to 40 of tSig, sPublicText) is not empty
   TestAssert "a signature with more after it is not one", __Verify(tIndex, tSig & "AAAA", sPublicText) is not empty
   TestAssert "an empty list is not believed", __Verify(empty, tSig, sPublicText) is not empty
   TestAssert "a key that is not one believes nothing", __Verify(tIndex, tSig, "AAAA") is not empty
end TestVerify

--------------------------------------------------------------------------------
-- Reading the list

on TestParse
   local tA, tOut, tStack
   put __Good() into tA
   put __Parse(__IndexBytes(__EntryJson(tA))) into tOut
   TestAssert "a good list has no problem", tOut["problem"] is empty
   TestAssert "one stack", tOut["count"] is 1 and tOut["leftOut"] is 0
   put tOut["stacks"][1] into tStack
   TestAssert "its name and version", tStack["slug"] is "sample-stack" and tStack["version"] is "1.2"
   TestAssert "its title and author", tStack["title"] is "Sample Stack" and tStack["author"] is "A. Name"
   TestAssert "what it does", tStack["description"] begins with "A stack made for a test."
   TestAssert "its licence, as the gallery shows it", tStack["licence"] is "MIT"
   TestAssert "its words", tStack["tags"] is ("game" & return & "puzzle")
   TestAssert "what it reaches for", tStack["uses"] is ("files" & return & "internet")
   TestAssert "its lines of script", tStack["lines"] is 12
   TestAssert "its download", tStack["download"] is tA["download"] and tStack["sha256"] is tA["sha256"] and tStack["size"] is tA["size"]
   TestAssert "its pages", tStack["play"] is tA["play"] and tStack["source"] is tA["source"] and tStack["page"] is tA["page"]
   TestAssert "its main file", tStack["main"] is "Sample Stack.oxtstack"
   TestAssert "its files", tStack["fileCount"] is 2 and tStack["files"][1]["path"] is "Sample Stack.oxtstack" \
         and tStack["files"][2]["path"] is "notes/readme.txt" and tStack["files"][2]["sha256"] is tA["file2sha"] \
         and tStack["files"][2]["size"] is tA["file2size"]
end TestParse

on TestParseAListThatIsNotOne
   local tOut
   put __Parse("this is not JSON") into tOut
   TestAssert "words are not a list", tOut["problem"] is not empty and tOut["count"] is 0
   put __Parse(textEncode("[1,2,3]", "utf-8")) into tOut
   TestAssert "nor is a list of numbers", tOut["problem"] is not empty and tOut["count"] is 0
   put __Parse(textEncode("{" & __Q("format") & ":2," & __Q("stacks") & ":[]}", "utf-8")) into tOut
   TestAssert "a newer form of the list is not guessed at", tOut["problem"] contains "newer"
   put __Parse(__IndexBytes(empty)) into tOut
   TestAssert "a gallery with no stacks is no problem", tOut["problem"] is empty and tOut["count"] is 0
end TestParseAListThatIsNotOne

on TestParseLeavesOutWhatBreaksTheRules
   local tA, tOut, tBadHash
   TestAssert "an unchanged stack is kept (the test's own check)", __Changed("title", "Sample Stack") is "1,0"
   -- its name and version
   TestAssert "a name with capitals", __Changed("slug", "Sample-Stack") is "0,1"
   TestAssert "a name with an underscore", __Changed("slug", "sample_stack") is "0,1"
   TestAssert "a name that goes up a folder", __Changed("slug", "..") is "0,1"
   TestAssert "a short name", __Changed("slug", "ab") is "0,1"
   TestAssert "a version with words", __Changed("version", "1.2-beta") is "0,1"
   TestAssert "a version that is a path", __Changed("version", "../1.2") is "0,1"
   -- what people read
   TestAssert "a title of one letter", __Changed("title", "A") is "0,1"
   TestAssert "a title of nothing but line ends", __Changed("title", return & return & tab) is "0,1"
   TestAssert "an author too long", __Changed("author", "An author whose name goes on for far longer than forty characters") is "0,1"
   TestAssert "nothing said about it", __Changed("description", "Short.") is "0,1"
   TestAssert "a licence that is a sentence", __Changed("licence", "do what you like!") is "0,1"
   TestAssert "a use that is not a word of the checker's", __Changed("usesJson", quote & "Bad Use" & quote) is "0,1"
   -- its download
   TestAssert "a download of another stack", __Changed("download", "s/other-stack/1.2/x.zip") is "0,1"
   TestAssert "a download that goes up a folder", __Changed("download", "s/sample-stack/1.2/../../x.zip") is "0,1"
   TestAssert "a download at an address", __Changed("download", "https://example.com/x.zip") is "0,1"
   TestAssert "a download that is not a .zip", __Changed("download", "s/sample-stack/1.2/x.exe") is "0,1"
   TestAssert "a hash in capitals", __Changed("sha256", toUpper(__Sha256("x"))) is "0,1"
   TestAssert "a short hash", __Changed("sha256", "abc123") is "0,1"
   TestAssert "a size of nothing", __Changed("size", 0) is "0,1"
   TestAssert "a size past the gallery's limit", __Changed("size", 52428801) is "0,1"
   TestAssert "a size that is not a number", __Changed("size", quote & "big" & quote) is "0,1"
   -- its files
   TestAssert "a main file that is not a stack", __Changed("main", "notes/readme.txt") is "0,1"
   TestAssert "a main file the download does not have", __Changed("main", "Other.oxtstack") is "0,1"
   TestAssert "a file that goes up a folder", __Changed("file2", "../readme.txt") is "0,1"
   TestAssert "a file that goes up a folder further in", __Changed("file2", "notes/../../readme.txt") is "0,1"
   TestAssert "a file from the root", __Changed("file2", "/etc/readme.txt") is "0,1"
   TestAssert "a file on a drive", __Changed("file2", "C:/readme.txt") is "0,1"
   TestAssert "a file with a backslash", __Changed("file2", "notes\readme.txt") is "0,1"
   TestAssert "a hidden file", __Changed("file2", ".profile") is "0,1"
   TestAssert "a file with a name Windows keeps", __Changed("file2", "notes/CON.txt") is "0,1"
   TestAssert "a file whose name ends in a dot", __Changed("file2", "notes/readme.") is "0,1"
   TestAssert "two files that differ only by case", __Changed("file2", "sample stack.oxtstack") is "0,1"
   TestAssert "a file with a short hash", __Changed("file2sha", "abc") is "0,1"
   TestAssert "a file past the gallery's limit", __Changed("file2size", 26214401) is "0,1"
   TestAssert "no versions", __Changed("versionsJson", "[]") is "0,1"
   put __Good() into tA
   put "[{" & __Q("version") & ":" & __Q("1.2") & "," & __Q("download") & ":" & __Q(tA["download"]) & "," & \
         __Q("sha256") & ":" & __Q(__Sha256("another file")) & "," & __Q("size") & ":" & tA["size"] & "," & \
         __Q("files") & ":[]}]" into tBadHash
   TestAssert "a newest version that is not the one listed", __Changed("versionsJson", tBadHash) is "0,1"
   -- the same stack twice
   put __Parse(__IndexBytes(__EntryJson(tA) & "," & __EntryJson(tA))) into tOut
   TestAssert "a stack listed twice is shown once", tOut["count"] is 1 and tOut["leftOut"] is 1
end TestParseLeavesOutWhatBreaksTheRules

on TestParseCleansWhatItKeeps
   local tA, tOut, tStack
   put __Good() into tA
   put "  Sample" & tab & "Stack  " into tA["title"]
   put "A stack made" & return & "for a test," & return & return & "with <b>marks</b> & more in it." into tA["description"]
   put quote & "game" & quote & "," & quote & "Not A Tag!" & quote & ",{" & __Q("a") & ":1}," & quote & "puzzle" & quote into tA["tagsJson"]
   put "https://example.com/play.html" into tA["play"]
   put "s/sample-stack/../../index.html" into tA["page"]
   put "s/other-stack/source.html" into tA["source"]
   put "Some-New-Licence-2.0" into tA["licence"]
   put __Parse(__IndexBytes(__EntryJson(tA))) into tOut
   TestAssert "the stack is kept", tOut["count"] is 1
   put tOut["stacks"][1] into tStack
   TestAssert "its title is one line, trimmed", tStack["title"] is "Sample Stack"
   TestAssert "what it does is one line, its marks kept as words", \
         tStack["description"] is "A stack made for a test, with <b>marks</b> & more in it."
   TestAssert "a word that is not a tag is dropped", tStack["tags"] is ("game" & return & "puzzle")
   TestAssert "a page at another address is not offered", tStack["play"] is empty
   TestAssert "nor a page that goes up a folder", tStack["page"] is empty
   TestAssert "nor another stack's page", tStack["source"] is empty
   TestAssert "a licence the gallery added since is shown by its name", tStack["licence"] is "Some-New-Licence-2.0"
end TestParseCleansWhatItKeeps

on TestUsesWords
   local tWords
   dispatch function "revCommunityStacksUsesWords" to stack sLib with "internet" & return & "files" & return & "javascript" & return & "something-new"
   put the result into tWords
   TestAssert "a line for each", the number of lines of tWords is 4
   TestAssert "the gallery's words", line 1 of tWords begins with "Uses the internet" & tab \
         and line 2 of tWords begins with "Opens or saves files" & tab and line 3 of tWords begins with "Runs JavaScript" & tab
   TestAssert "a word it does not know is still shown", line 4 of tWords begins with "Uses something-new" & tab
   dispatch function "revCommunityStacksUsesWords" to stack sLib with empty
   TestAssert "nothing for a stack that reaches for nothing", the result is empty
end TestUsesWords

--------------------------------------------------------------------------------
-- The list from a site

on TestLoad
   local tA, tSite, tOut, tIndex
   if not __NeedsSodium("the list from a site") then
      exit TestLoad
   end if
   put __Good() into tA
   put __Site(tA, true) into tSite
   put __Load(tSite, sPublicText) into tOut
   TestAssert "a signed list is shown", tOut["problem"] is empty and tOut["count"] is 1 and tOut["stacks"][1]["slug"] is "sample-stack"
   put __Load(tSite, empty) into tOut
   TestAssert "not with the gallery's own key, which did not sign it", tOut["problem"] is not empty and tOut["count"] is empty
   -- a list somebody changed after it was signed
   put url ("binfile:" & tSite & "/index.json") into tIndex
   replace "A. Name" with "B. Name" in tIndex
   put tIndex into url ("binfile:" & tSite & "/index.json")
   put __Load(tSite, sPublicText) into tOut
   TestAssert "a list changed after it was signed is not shown", tOut["problem"] is not empty and tOut["stacks"] is empty
   TestAssert "and that is not called unsigned", tOut["unsigned"] is not true
   -- a list with no signature
   put __Site(tA, false) into tSite
   put __Load(tSite, sPublicText) into tOut
   TestAssert "a list with no signature is not shown", tOut["problem"] is not empty and tOut["stacks"] is empty
   TestAssert "and the window is told that is all that is wrong", tOut["unsigned"] is true
   -- no list
   delete file (tSite & "/index.json")
   put __Load(tSite, sPublicText) into tOut
   TestAssert "a site with no list", tOut["problem"] is not empty and tOut["unsigned"] is not true
end TestLoad

on TestLoadOnlyFromHttps
   local tOut
   put __Load("http://example.invalid/", sPublicText) into tOut
   TestAssert "not from http", tOut["problem"] contains "https://"
   put __Load("file:///tmp/", sPublicText) into tOut
   TestAssert "not from a file address", tOut["problem"] contains "https://"
   put __Load("ftp://example.invalid/", sPublicText) into tOut
   TestAssert "not from ftp", tOut["problem"] contains "https://"
   put __Load(sFolder & "/no-such-folder", sPublicText) into tOut
   TestAssert "not from a folder that is not there", tOut["problem"] contains "https://"
end TestLoadOnlyFromHttps

--------------------------------------------------------------------------------
-- Getting a copy

-- The stack of the test's gallery as the list reads it, and the site
private function __Listed pA, @rSite
   local tOut
   put __Site(pA, false) into rSite
   put __Parse(__IndexBytes(__EntryJson(pA))) into tOut
   return tOut["stacks"][1]
end __Listed

on TestGet
   local tA, tSite, tEntry, tCopies, tMain, tAgain, tThird
   put __Good() into tA
   put __Listed(tA, tSite) into tEntry
   put sFolder & "/copies" into tCopies
   put __Get(tEntry, tCopies, tSite) into tMain
   TestAssert "the copy's main file, in a folder of its own", tMain is (tCopies & "/sample-stack-1.2/Sample Stack.oxtstack")
   TestAssert "it is the stack, byte for byte", url ("binfile:" & tMain) is tA["stackData"]
   TestAssert "its other file is with it, in its folder", url ("binfile:" & tCopies & "/sample-stack-1.2/notes/readme.txt") is tA["notesData"]
   TestAssert "a file the list does not name was not written", there is no file (tCopies & "/sample-stack-1.2/stowaway.txt")
   TestAssert "nothing else was written", the number of lines of files(tCopies & "/sample-stack-1.2") is 1 \
         and the number of lines of files(tCopies) is 0
   TestAssert "none of it ran", gTestCommunityStacksRan is empty
   -- again: the copy that is there is used
   put __Get(tEntry, tCopies, sFolder & "/no-site-at-all") into tAgain
   TestAssert "a copy that is there and whole is used again, without the site", tAgain is tMain
   -- the user changed their copy: it is left alone
   put "my own notes" into url ("binfile:" & tCopies & "/sample-stack-1.2/notes/readme.txt")
   put __Get(tEntry, tCopies, tSite) into tThird
   TestAssert "a changed copy is left alone: the new one gets a folder with a number", \
         tThird is (tCopies & "/sample-stack-1.2-2/Sample Stack.oxtstack")
   TestAssert "the changed copy still has the change", url ("binfile:" & tCopies & "/sample-stack-1.2/notes/readme.txt") is "my own notes"
end TestGet

on TestGetKeepsOnlyWhatTheListNames
   local tA, tSite, tEntry, tCopies, tResult, tZip, tStack, tNotes, tWrong
   put sFolder & "/copies-refused" into tCopies
   -- the download was changed on the site
   put __Good() into tA
   put __Listed(tA, tSite) into tEntry
   put tA["zipData"] & "x" into url ("binfile:" & tSite & "/" & tA["download"])
   put __Get(tEntry, tCopies, tSite) into tResult
   TestAssert "a download that grew is thrown away", tResult begins with "error:"
   put "not a zip at all" into url ("binfile:" & tSite & "/" & tA["download"])
   put __Get(tEntry, tCopies, tSite) into tResult
   TestAssert "a download that is something else is thrown away", tResult begins with "error:"
   delete file (tSite & "/" & tA["download"])
   put __Get(tEntry, tCopies, tSite) into tResult
   TestAssert "a download that is gone", tResult begins with "error:"
   TestAssert "nothing was written for any of them", there is no folder (tCopies & "/sample-stack-1.2")

   -- the download is the listed one, but a file in it is not the one the
   -- list names (the list was made of other files)
   put __Good() into tA
   put __Sha256("some other notes") into tA["file2sha"]
   put __Listed(tA, tSite) into tEntry
   put __Get(tEntry, tCopies, tSite) into tResult
   TestAssert "a file that is not the listed one stops the copy", tResult begins with "error:" and tResult contains "notes/readme.txt"
   TestAssert "and nothing of it is written, the good file neither", there is no folder (tCopies & "/sample-stack-1.2")

   -- the list names a file the download does not hold
   put __Good() into tA
   put "notes/missing.txt" into tA["file2"]
   put __Listed(tA, tSite) into tEntry
   put __Get(tEntry, tCopies, tSite) into tResult
   TestAssert "a file the download does not hold stops the copy", tResult begins with "error:"
   TestAssert "and nothing is written", there is no folder (tCopies & "/sample-stack-1.2")

   -- what is not a stack of the list
   put __Get("sample-stack", tCopies, tSite) into tResult
   TestAssert "a name is not a stack of the list", tResult begins with "error:"
end TestGetKeepsOnlyWhatTheListNames

--------------------------------------------------------------------------------
-- Opening a copy to look at

on TestOpenToRead
   local tFile, tResult
   put sFolder & "/Sample Stack.oxtstack" into tFile
   put __StackBytes("TestCommunitySample") into url ("binfile:" & tFile)
   put empty into gTestCommunityStacksRan
   put __Open(tFile) into tResult
   TestAssert "it opens", tResult is empty and there is a stack "TestCommunitySample" and the mode of stack "TestCommunitySample" is not 0
   TestAssert "from the copy's file", the effective filename of stack "TestCommunitySample" is tFile
   TestAssert "none of its opening scripts ran", gTestCommunityStacksRan is empty
   TestAssert "with the pointer tool", the tool is "pointer tool"
   lock messages
   close stack "TestCommunitySample"
   delete stack "TestCommunitySample"
   unlock messages
   choose browse tool
   put __Open(sFolder & "/no-such-file.oxtstack") into tResult
   TestAssert "a file that is not there", tResult begins with "error:"
end TestOpenToRead

on TestOpenToReadRefusesTheIDEsNames
   local tFile, tResult
   put sFolder & "/Named.oxtstack" into tFile
   put __StackBytes("revTestCommunityNamed") into url ("binfile:" & tFile)
   put empty into gTestCommunityStacksRan
   put __Open(tFile) into tResult
   TestAssert "a stack with a name the IDE keeps is not opened", tResult begins with "error:" and tResult contains "revTestCommunityNamed"
   TestAssert "and is not left in memory", there is no stack "revTestCommunityNamed"
   TestAssert "none of it ran", gTestCommunityStacksRan is empty

   -- and one that only holds a stack of such a name
   put sFolder & "/Holds.oxtstack" into tFile
   put __StackBytes("TestCommunityHolder", "revTestCommunityInside") into url ("binfile:" & tFile)
   put __Open(tFile) into tResult
   TestAssert "a stack that holds one with a name the IDE keeps is not opened", tResult begins with "error:" and tResult contains "revTestCommunityInside"
   TestAssert "and neither is left in memory", there is no stack "TestCommunityHolder" and there is no stack "revTestCommunityInside"
   TestAssert "none of that ran either", gTestCommunityStacksRan is empty
end TestOpenToReadRefusesTheIDEsNames

on TestOpenToReadLeavesAnOpenStackAlone
   local tFile, tResult, tSaved
   put sFolder & "/Twin.oxtstack" into tFile
   put __StackBytes("TestCommunitySample") into url ("binfile:" & tFile)
   -- a stack of the user's with the same name, open already
   put the defaultStack into tSaved
   lock messages
   create invisible stack "TestCommunitySample"
   set the uMine of stack "TestCommunitySample" to "the user's own"
   unlock messages
   set the defaultStack to tSaved
   put __Open(tFile) into tResult
   TestAssert "a copy named as a stack that is open is not opened over it", tResult begins with "error:"
   TestAssert "the user's stack is as it was", the uMine of stack "TestCommunitySample" is "the user's own"
end TestOpenToReadLeavesAnOpenStackAlone
