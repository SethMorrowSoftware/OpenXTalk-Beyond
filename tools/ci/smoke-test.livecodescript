script "oxt_smoke_test"
-- Headless smoke test for a Windows build of OpenXTalk Lite.
--
-- Run it with the development engine, without the IDE:
--
--    win-x86_64-bin\LiveCode-Community.exe -ui tools\ci\smoke-test.livecodescript
--
-- tools/ci/smoke-test.ps1 does this and sets the expected values below from
-- the source tree. The script prints one PASS or FAIL line per check to
-- stdout and quits with the number of failed checks as the exit code.
--
-- Optional environment variables:
--    OXT_EXPECT_VERSION  expected "the version" (BUILD_SHORT_VERSION)
--    OXT_EXPECT_SQLITE   expected sqlite_version() (SQLITE_VERSION in
--                        thirdparty/libsqlite/include/sqlite3.h)

local sFails, sPasses

command check pName, pOK, pDetail
   if pOK then
      add 1 to sPasses
      write "PASS " & pName & ": " & pDetail & return to stdout
   else
      add 1 to sFails
      write "FAIL " & pName & ": " & pDetail & return to stdout
   end if
end check

on startup
   put 0 into sFails
   put 0 into sPasses
   put specialFolderPath("engine") into tEngine
   put specialFolderPath("temporary") into tTemp
   put $OXT_EXPECT_VERSION into tExpectVersion
   put $OXT_EXPECT_SQLITE into tExpectSqlite
   write "INFO version=" & the version & " build=" & the buildNumber & " environment=" & the environment & " platform=" & the platform & " processor=" & the processor & return to stdout
   write "INFO engine=" & tEngine & return to stdout

   try
      if tExpectVersion is empty then
         check "version", the version is not empty, the version
      else
         check "version", the version is tExpectVersion, the version & " (expected " & tExpectVersion & ")"
      end if
      check "processor", the processor is "x86_64", the processor

      -- Script engine
      put 0 into tSum
      repeat with i = 1 to 100
         add i to tSum
      end repeat
      check "arithmetic", tSum = 5050, tSum
      put "b,c,a" into tList
      sort items of tList
      check "sort", tList is "a,b,c", tList
      put "x" into tArray["k"]
      check "arrays", tArray["k"] is "x" and the keys of tArray is "k", the keys of tArray
      get matchText("abc123def", "([0-9]+)", tNumber)
      check "regular expressions (PCRE)", it and tNumber is "123", tNumber
      put "hello hello hello hello hello" into tData
      check "compress (zlib)", decompress(compress(tData)) is tData, the number of bytes in compress(tData) & " bytes compressed"
      get binaryDecode("H*", messageDigest("abc", "SHA-256"), tHex)
      check "SHA-256", tHex is "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", tHex

      -- Unicode (ICU)
      put "e" & numToCodepoint(0x301) into tCombined
      check "grapheme clusters (ICU)", the number of chars in tCombined = 1 and the number of codepoints in tCombined = 2, the number of chars in tCombined & " char, " & the number of codepoints in tCombined & " codepoints"
      check "astral codepoint", the number of codepoints in numToCodepoint(0x1F600) = 1, codepointToNum(numToCodepoint(0x1F600))
      put normalizeText(numToCodepoint(0xE9), "NFD") into tDecomposed
      check "normalizeText NFD (ICU)", the number of codepoints in tDecomposed = 2, the number of codepoints in tDecomposed & " codepoints"
      set the caseSensitive to true
      put toUpper("abc" & numToCodepoint(0xE9)) into tUpper
      check "toUpper", tUpper is ("ABC" & numToCodepoint(0xC9)), codepointToNum(codepoint -1 of tUpper)
      set the caseSensitive to false

      -- OpenSSL, through revsecurity.dll
      encrypt "secret message" using "aes-256-cbc" with password "pw"
      put it into tCipher
      put the result into tEncryptResult
      decrypt tCipher using "aes-256-cbc" with password "pw"
      check "encrypt/decrypt aes-256-cbc (OpenSSL)", it is "secret message" and tCipher is not "secret message", "result='" & tEncryptResult & "', ciphertext " & the number of bytes in tCipher & " bytes"
      check "randomBytes", the number of bytes in randomBytes(16) = 16, the number of bytes in randomBytes(16) & " bytes"

      -- Windows light/dark mode support. Without a user interface the
      -- engine reports its default ("light"); the IDE reports the setting.
      put the systemAppearance into tAppearance
      check "systemAppearance", tAppearance is among the items of "light,dark", tAppearance

      -- Files and processes
      put tTemp & "/oxt_smoke_test.bin" into tFile
      put "round" & numToByte(0) & "trip" into URL ("binfile:" & tFile)
      check "binary file I/O", URL ("binfile:" & tFile) is ("round" & numToByte(0) & "trip"), the number of bytes in URL ("binfile:" & tFile) & " bytes"
      delete file tFile
      put shell("echo oxt") into tShell
      check "shell", word 1 of tShell is "oxt", word 1 of tShell

      -- Externals: revDB, revXML and revZip
      set the externals of the templateStack to tEngine & "/revdb.dll" & return & tEngine & "/revxml.dll" & return & tEngine & "/revzip.dll"
      create stack "oxt_smoke_test_externals"
      start using stack "oxt_smoke_test_externals"
      put the number of lines of the externalCommands of stack "oxt_smoke_test_externals" into tCommandCount
      put the number of lines of the externalFunctions of stack "oxt_smoke_test_externals" into tFunctionCount
      check "externals load", tCommandCount > 0 and tFunctionCount > 0, tCommandCount & " commands, " & tFunctionCount & " functions"
   catch tError
      check "no script error (core checks)", false, tError
   end try

   -- SQLite, through revDB and dbsqlite.dll
   try
      revSetDatabaseDriverPath tEngine
      put tTemp & "/oxt_smoke_test.sqlite" into tDatabase
      if there is a file tDatabase then delete file tDatabase
      put revOpenDatabase("sqlite", tDatabase) into tConnection
      check "SQLite open", tConnection is an integer, tConnection
      if tConnection is an integer then
         put revDataFromQuery(tab, return, tConnection, "select sqlite_version()") into tSqliteVersion
         if tExpectSqlite is empty then
            check "SQLite version", tSqliteVersion begins with "3.", tSqliteVersion
         else
            check "SQLite version", tSqliteVersion is tExpectSqlite, tSqliteVersion & " (expected " & tExpectSqlite & ")"
         end if
         revExecuteSQL tConnection, "create table t(id integer primary key, name text)"
         revExecuteSQL tConnection, "insert into t(name) values ('alpha'), ('beta')"
         put revDataFromQuery(tab, return, tConnection, "select group_concat(name) from t") into tRows
         check "SQLite query", tRows is "alpha,beta", tRows
         revExecuteSQL tConnection, "create virtual table ft using fts5(body)"
         revExecuteSQL tConnection, "insert into ft(body) values ('hello world'), ('goodbye moon')"
         put revDataFromQuery(tab, return, tConnection, "select body from ft where ft match 'hello'") into tMatch
         check "SQLite FTS5", tMatch is "hello world", tMatch
         put revDataFromQuery(tab, return, tConnection, "select json_extract('{" & quote & "a" & quote & ":{" & quote & "b" & quote & ":42}}', '$.a.b')") into tJson
         check "SQLite JSON", tJson is "42", tJson
         put revDataFromQuery(tab, return, tConnection, "select count(*) from pragma_compile_options where compile_options like 'ENABLE_RTREE%' or compile_options like 'ENABLE_FTS5%'") into tOptions
         check "SQLite RTREE and FTS5 compiled in", tOptions = 2, tOptions & " of 2"
         revCloseDatabase tConnection
      end if
      if there is a file tDatabase then delete file tDatabase
   catch tError
      check "no script error (SQLite checks)", false, tError
   end try

   -- revXML
   try
      put revXMLCreateTree("<root><item id=" & quote & "1" & quote & ">hi</item></root>", false, true, false) into tTree
      check "revXML parse", tTree is an integer, tTree
      if tTree is an integer then
         check "revXML node contents", revXMLNodeContents(tTree, "/root/item") is "hi", revXMLNodeContents(tTree, "/root/item")
         revXMLDeleteTree tTree
      end if
   catch tError
      check "no script error (revXML checks)", false, tError
   end try

   -- revZip
   try
      put tTemp & "/oxt_smoke_test.zip" into tZip
      if there is a file tZip then delete file tZip
      put "zip content 123" into tZipData
      revZipOpenArchive tZip, "write"
      revZipAddItemWithData tZip, "hello.txt", "tZipData"
      revZipCloseArchive tZip
      revZipOpenArchive tZip, "read"
      put revZipEnumerateItems(tZip) into tItems
      revZipExtractItemToVariable tZip, "hello.txt", "tUnzipped"
      revZipCloseArchive tZip
      check "revZip round trip", line 1 of tItems is "hello.txt" and tUnzipped is "zip content 123", line 1 of tItems & ": " & tUnzipped
      if there is a file tZip then delete file tZip
   catch tError
      check "no script error (revZip checks)", false, tError
   end try

   write "SUMMARY passed=" & sPasses & " failed=" & sFails & return to stdout
   quit sFails
end startup
