script "oxt_smoke_test"
-- Headless smoke test for a build of OXT-Beyond (Windows, Linux or macOS).
--
-- Run it with the development engine, without the IDE:
--
--    win-x86_64-bin\LiveCode-Community.exe -ui tools\ci\smoke-test.livecodescript
--    OXT-Beyond.exe -ui tools\ci\smoke-test.livecodescript    (installed)
--
-- tools/ci/smoke-test.ps1 (Windows) and tools/ci/run_livecode_check.py
-- (every platform) do this and set the expected values below from the
-- source tree. The script prints one PASS or FAIL line per check to stdout
-- and quits with the number of failed checks as the exit code.
--
-- Optional environment variables:
--    OXT_EXPECT_VERSION   expected "the version" (BUILD_SHORT_VERSION)
--    OXT_EXPECT_SQLITE    expected sqlite_version() (SQLITE_VERSION in
--                         thirdparty/libsqlite/include/sqlite3.h)
--    OXT_EXPECT_PROCESSOR expected "the processor" (default x86_64)
--    OXT_EXTERNAL_SUFFIX  file name suffix of the externals: .dll (the
--                         default), .so on Linux, .bundle on macOS
--    OXT_EXTERNALS_DIR    folder with revdb, revxml and revzip
--    OXT_DRIVERS_DIR      folder with dbsqlite
--    OXT_CODE_FOLDERS     the code folders of an LCB extension whose
--                         libraries the IDE maps on this platform, as
--                         comma-separated patterns in the IDE's order
--                         (revideextensionlibrary __MapCodeLibraryForIDE):
--                         x86_64-linux*, or arm64-mac*,universal-mac* on
--                         Apple Silicon; default <processor>-win32*
--    OXT_XTALK_PROBES     file listing the bundled xTalk Suite extensions to
--                         load and call, in load order (see smoke-test.ps1)
--    OXT_EXTENSIONS_DIR   the layout's Extensions folder
-- Both folders default to the engine's folder, as in win-x86_64-bin. In an
-- installed layout they are Externals and Externals/Database Drivers. The
-- defaults are the Windows x86-64 values, so smoke-test.ps1 sets none of
-- the three platform variables.

local sCodeFolders, sSystemName

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
   put $OXT_EXTERNALS_DIR into tExternals
   if tExternals is empty then put tEngine into tExternals
   replace "\" with "/" in tExternals
   put $OXT_DRIVERS_DIR into tDrivers
   if tDrivers is empty then put tEngine into tDrivers
   replace "\" with "/" in tDrivers
   put $OXT_EXPECT_PROCESSOR into tExpectProcessor
   if tExpectProcessor is empty then put "x86_64" into tExpectProcessor
   put $OXT_EXTERNAL_SUFFIX into tSuffix
   if tSuffix is empty then put ".dll" into tSuffix
   put $OXT_CODE_FOLDERS into sCodeFolders
   if sCodeFolders is empty then put the processor & "-win32*" into sCodeFolders
   -- What the dependency check is called: Windows DLL imports, or the
   -- libraries an ELF or Mach-O file needs
   if the platform is "Win32" then
      put "DLL imports" into sSystemName
   else
      put "native dependencies" into sSystemName
   end if
   write "INFO version=" & the version & " build=" & the buildNumber & " environment=" & the environment & " platform=" & the platform & " processor=" & the processor & return to stdout
   write "INFO engine=" & tEngine & return to stdout
   write "INFO externals=" & tExternals & " drivers=" & tDrivers & " suffix=" & tSuffix & " code folders=" & sCodeFolders & return to stdout

   try
      if tExpectVersion is empty then
         check "version", the version is not empty, the version
      else
         check "version", the version is tExpectVersion, the version & " (expected " & tExpectVersion & ")"
      end if
      check "processor", the processor is tExpectProcessor, the processor & " (expected " & tExpectProcessor & ")"

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

      -- OpenSSL, through revsecurity (.dll, .so, .dylib next to the engine)
      encrypt "secret message" using "aes-256-cbc" with password "pw"
      put it into tCipher
      put the result into tEncryptResult
      decrypt tCipher using "aes-256-cbc" with password "pw"
      check "encrypt/decrypt aes-256-cbc (OpenSSL)", it is "secret message" and tCipher is not "secret message", "result='" & tEncryptResult & "', ciphertext " & the number of bytes in tCipher & " bytes"
      -- Blowfish is one of the older ciphers that OpenSSL 3 keeps in its
      -- legacy provider, which revsecurity has built in and the engine loads
      encrypt "secret message" using "bf-cbc" with password "pw"
      put it into tCipher
      put the result into tEncryptResult
      decrypt tCipher using "bf-cbc" with password "pw"
      check "encrypt/decrypt bf-cbc (OpenSSL legacy provider)", it is "secret message" and tCipher is not "secret message", "result='" & tEncryptResult & "', ciphertext " & the number of bytes in tCipher & " bytes"
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

      -- Engine crashes inherited from LiveCode Community 9.6.3: each of
      -- these ended the engine, so reaching the next line is the check.
      -- This script runs with no display on Linux and no stack on screen,
      -- which two of them need.
      local tCrash
      put the penBack of me & the fillBack of me into tCrash
      check "penBack and fillBack of an object", tCrash is empty, tCrash
      put hostAddressToName(empty) into tCrash
      check "hostAddressToName of empty", tCrash is empty and the result is "invalid host address", tCrash && the result
      open socket to empty
      check "open socket to empty", the result is not empty, the result
      put topStack(1) & topWindow(1) into tCrash
      check "topStack and topWindow of a number", true, tCrash
      put the screenPixelScale into tCrash
      check "screenPixelScale", tCrash is a number and tCrash > 0, tCrash
      check "format of a number above 32 bits", format("%d", 3000000000) is "3000000000", format("%d", 3000000000)

      -- Externals: revDB, revXML and revZip (on macOS, bundles)
      set the externals of the templateStack to tExternals & "/revdb" & tSuffix & return & tExternals & "/revxml" & tSuffix & return & tExternals & "/revzip" & tSuffix
      create stack "oxt_smoke_test_externals"
      start using stack "oxt_smoke_test_externals"
      put the number of lines of the externalCommands of stack "oxt_smoke_test_externals" into tCommandCount
      put the number of lines of the externalFunctions of stack "oxt_smoke_test_externals" into tFunctionCount
      check "externals load", tCommandCount > 0 and tFunctionCount > 0, tCommandCount & " commands, " & tFunctionCount & " functions"
   catch tError
      check "no script error (core checks)", false, tError
   end try

   -- SQLite, through revDB and dbsqlite (revDB adds the platform's suffix)
   try
      revSetDatabaseDriverPath tDrivers
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
      -- Namespaces, both ways: revXMLCreateTree resolves prefixes (the root
      -- is "root" in namespace a), revXMLCreateTreeWithNamespaces keeps them
      -- in the names ("a:root"), through the SAX2 handler OXT-Beyond keeps
      -- in its libxml2 (see thirdparty/libxml/ORIGIN).
      put "<a:root xmlns:a=" & quote & "urn:a" & quote & " a:n=" & quote & "1" & quote & "><a:item>x</a:item></a:root>" into tXML
      put revXMLCreateTree(tXML, false, true, false) into tTree
      check "revXML namespaces resolved", revXMLRootNode(tTree) is "root", revXMLRootNode(tTree)
      if tTree is an integer then revXMLDeleteTree tTree
      put revXMLCreateTreeWithNamespaces(tXML, false, true, false) into tTree
      check "revXML namespace prefixes kept", revXMLRootNode(tTree) is "a:root" and revXMLAttribute(tTree, "/a:root", "a:n") is "1", revXMLRootNode(tTree) && revXMLAttribute(tTree, "/a:root", "a:n")
      if tTree is an integer then revXMLDeleteTree tTree
      -- A document that is not well formed is refused, with libxml2's message,
      -- when dontParseBadData (the second parameter) is true; when it is
      -- false, libxml2 recovers what it can and that is the tree
      put revXMLCreateTree("<root><item></root>", true, true, false) into tTree
      check "revXML refuses bad XML", tTree begins with "xmlerr", tTree
      -- DTD validation, XPath and XSLT (libxslt)
      put revXMLCreateTree("<list><n>b</n><n>a</n><n>c</n></list>", false, true, false) into tTree
      check "revXML DTD validation", revXMLValidateDTD(tTree, "<!ELEMENT list (n*)><!ELEMENT n (#PCDATA)>") is empty, revXMLValidateDTD(tTree, "<!ELEMENT list (n*)><!ELEMENT n (#PCDATA)>")
      check "revXML DTD validation fails", revXMLValidateDTD(tTree, "<!ELEMENT list (m*)><!ELEMENT m EMPTY>") is not empty, "(empty)"
      -- Every path is followed by the delimiter (return by default), the last
      -- one too: revXML has always done that
      put revXMLEvaluateXPath(tTree, "/list/n[2]") into tPath
      check "revXML XPath", tPath is "/list/n[2]" & return, tPath
      -- Each node's text is followed by the element delimiter, then the line
      -- delimiter; libxml2 2.15 builds node text in a buffer that revXML must
      -- detach before freeing it (see revxml/src/revxml.cpp)
      put revXMLDataFromXPathQuery(tTree, "/list/n", ",", "|") into tData
      check "revXML XPath data", tData is "b,|a,|c,|", tData
      put "<xsl:stylesheet version=" & quote & "1.0" & quote & " xmlns:xsl=" & quote & "http://www.w3.org/1999/XSL/Transform" & quote & ">" & \
            "<xsl:output method=" & quote & "text" & quote & "/><xsl:template match=" & quote & "/" & quote & ">" & \
            "<xsl:for-each select=" & quote & "//n" & quote & "><xsl:sort select=" & quote & "." & quote & "/><xsl:value-of select=" & quote & "." & quote & "/>" & \
            "</xsl:for-each></xsl:template></xsl:stylesheet>" into tXSL
      put revXMLCreateTree(tXSL, false, true, false) into tXSLTree
      put xsltLoadStylesheet(tXSLTree) into tStylesheet
      put xsltApplyStylesheet(tTree, tStylesheet) into tResult
      check "XSLT (libxslt) sorts and transforms", tResult is "abc", tResult
      if tXSLTree is an integer then revXMLDeleteTree tXSLTree
      if tTree is an integer then revXMLDeleteTree tTree
      -- Files: a gzip-compressed one (libxml2 2.15 reads those only when
      -- revXML asks it to, XML_PARSE_UNZIP), and one whose name is not ASCII
      -- (revXML gets the name in the platform's native encoding, and libxml2
      -- 2.15 opens files on Windows only through UTF-8)
      put tTemp & "/oxt_smoke_test.xml.gz" into tXMLFile
      put compress("<root><z>gz</z></root>") into URL ("binfile:" & tXMLFile)
      put revXMLCreateTreeFromFile(tXMLFile, false, true, false) into tTree
      check "revXML reads a gzip file", tTree is an integer and revXMLNodeContents(tTree, "/root/z") is "gz", tTree
      if tTree is an integer then revXMLDeleteTree tTree
      if there is a file tXMLFile then delete file tXMLFile
      -- On Linux the engine names files in the locale's character set, so
      -- under the C locale (the build containers) it cannot make this one
      put tTemp & "/oxt_smoke_test_caf" & numToChar(233) & ".xml" into tXMLFile
      put "<root><z>accent</z></root>" into URL ("binfile:" & tXMLFile)
      put the result into tWriteResult
      if there is a file tXMLFile then
         put revXMLCreateTreeFromFile(tXMLFile, false, true, false) into tTree
         check "revXML reads a file with an accented name", tTree is an integer and revXMLNodeContents(tTree, "/root/z") is "accent", tTree
         if tTree is an integer then revXMLDeleteTree tTree
         delete file tXMLFile
      else
         write "INFO revXML accented file name not checked: the engine could not create the file (" & tWriteResult & ")" & return to stdout
      end if
      -- What 0.2.4 (libxml2 2.9.4, libxslt 1.1.28) gave scripts and libxml2
      -- 2.15 alone changed; revXML and the two libraries keep it (see
      -- revxml/src/xmlnative.cpp and the ORIGIN files of thirdparty/libxml
      -- and thirdparty/libxslt).
      -- An entity that no DTD declares, in a document parsed with bad data
      -- allowed, drops out and leaves the text around it as one text node;
      -- 2.15 made a reference node of it, so the contents ended at "x "
      put revXMLCreateTree("<root><item>x &nbsp; y</item></root>", false, true, false) into tTree
      put revXMLNodeContents(tTree, "/root/item") into tContents
      check "revXML keeps the text around an undefined entity", tContents is "x  y", tContents
      if tTree is an integer then revXMLDeleteTree tTree
      -- Adjacent CDATA sections are one node, so the contents are all of them
      put revXMLCreateTree("<root><item><![CDATA[one]]><![CDATA[<two>]]></item></root>", false, true, false) into tTree
      put revXMLNodeContents(tTree, "/root/item") into tContents
      check "revXML merges adjacent CDATA sections", tContents is "one<two>", tContents
      if tTree is an integer then revXMLDeleteTree tTree
      -- Accented text in the native encoding (revXML is a v0 external) in a
      -- document that declares no encoding: libxml2 reads UTF-8, and revXML
      -- has it keep each byte that is not UTF-8, so the text, the attributes,
      -- XPath literals and the element's text come back as they went in
      -- (2.15 alone made them U+FFFD). With dontParseBadData the document is
      -- refused, as libxml2 2.9 refused it.
      put "caf" & numToChar(233) into tAccented
      put "<root><item name=" & quote & tAccented & quote & ">" & tAccented & "</item></root>" into tXML
      put revXMLCreateTree(tXML, false, true, false) into tTree
      put revXMLNodeContents(tTree, "/root/item") into tContents
      put revXMLAttribute(tTree, "/root/item", "name") into tAttribute
      check "revXML keeps native text", tContents is tAccented and tAttribute is tAccented, tContents && tAttribute
      put revXMLEvaluateXPath(tTree, "/root/item[.='" & tAccented & "']") into tPath
      check "revXML XPath literal with native text", tPath is ("/root/item" & return), tPath
      put revXMLText(tTree, "/root/item") into tText
      check "revXML writes native text back", tText is ("<item name=" & quote & tAccented & quote & ">" & tAccented & "</item>"), tText
      if tTree is an integer then revXMLDeleteTree tTree
      put revXMLCreateTree(tXML, true, true, false) into tTree
      check "revXML refuses native text when not parsing bad data", tTree begins with "xmlerr" and tTree contains "Input is not proper UTF-8", line 1 to 2 of tTree
      if tTree is an integer then revXMLDeleteTree tTree
      -- Attributes a DTD declares with a type other than CDATA are
      -- normalized, as 2.9 did, so id() finds an ID written with spaces
      -- around it, and one in native text
      put "<!DOCTYPE root [<!ATTLIST item id ID #IMPLIED>]><root><item id=" & quote & "  a1  " & quote & ">one</item>" & \
            "<item id=" & quote & tAccented & quote & ">two</item></root>" into tXML
      put revXMLCreateTree(tXML, false, true, false) into tTree
      put revXMLDataFromXPathQuery(tTree, "id('a1')", ",", "|") & revXMLDataFromXPathQuery(tTree, "id('" & tAccented & "')", ",", "|") into tData
      check "revXML normalizes declared IDs", revXMLAttribute(tTree, "/root/item[1]", "id") is "a1" and tData is "one,|two,|", revXMLAttribute(tTree, "/root/item[1]", "id") && tData
      if tTree is an integer then revXMLDeleteTree tTree
      -- 8-bit text labelled UTF-16 is read as UTF-8, as 2.9 read it (2.15
      -- made an empty tree of it); an encoding 2.9 could not read is refused
      -- by name before the parse (2.15 read some as UTF-16 or UCS-4 garbage)
      put revXMLCreateTree("<?xml version=" & quote & "1.0" & quote & " encoding=" & quote & "UTF-16" & quote & "?><root><z>abc</z></root>", false, true, false) into tTree
      put revXMLNodeContents(tTree, "/root/z") into tContents
      check "revXML reads 8-bit text labelled UTF-16", tContents is "abc", tContents
      if tTree is an integer then revXMLDeleteTree tTree
      put revXMLCreateTree("<?xml version=" & quote & "1.0" & quote & " encoding=" & quote & "UCS-4" & quote & "?><root/>", false, true, false) into tTree
      check "revXML refuses an encoding 0.2.4 could not read", tTree is ("xmlerr, can't parse xml" & return & "Unsupported encoding UCS-4" & return), tTree
      if tTree is an integer then revXMLDeleteTree tTree
      -- A control character put into a node reads back as itself (2.15 gave
      -- U+FFFD)
      put revXMLCreateTree("<root><z/></root>", false, true, false) into tTree
      revXMLPutIntoNode tTree, "/root/z", "a" & numToChar(1) & "b"
      put revXMLNodeContents(tTree, "/root/z") into tContents
      check "revXML stores a control character", tContents is ("a" & numToChar(1) & "b"), the number of chars in tContents & " chars"
      if tTree is an integer then revXMLDeleteTree tTree
      -- A location step taken from an empty node-set is "can't resolve
      -- xpath", unless the path is a plain one that libxml2 2.9 evaluated
      -- as a stream, which matched nothing (2.15 gave nothing for both)
      put revXMLCreateTree("<root><z/></root>", false, true, false) into tTree
      put revXMLDataFromXPathQuery(tTree, "/root/x/text()", ",", "|") & "/" & revXMLDataFromXPathQuery(tTree, "/root/x/y", ",", "|") into tData
      check "revXML XPath step from an empty node-set", tData is "xmlerr, can't resolve xpath/", tData
      if tTree is an integer then revXMLDeleteTree tTree
      -- A native byte written in an 8-bit encoding is a character reference,
      -- not read with the letter after it as one character (2.15 wrote the
      -- byte and the "O" as one letter); an attribute value in native text
      -- labels the document ISO-8859-1, as 2.9 did
      put revXMLCreateTree("<?xml version=" & quote & "1.0" & quote & " encoding=" & quote & "ISO-8859-1" & quote & "?><root><z/></root>", false, true, false) into tTree
      revXMLPutIntoNode tTree, "/root/z", "S" & numToChar(195) & "O"
      put revXMLText(tTree) into tText
      check "revXML writes a native byte in ISO-8859-1", tText contains "<z>S&#195;O</z>" or tText contains ("<z>S" & numToChar(195) & "O</z>"), oneLine(tText)
      if tTree is an integer then revXMLDeleteTree tTree
      put revXMLCreateTree("<root><z/></root>", false, true, false) into tTree
      revXMLSetAttribute tTree, "/root/z", "a", tAccented
      put revXMLText(tTree) into tText
      check "revXML labels native text in an attribute", tText begins with ("<?xml version=" & quote & "1.0" & quote & " encoding=" & quote & "ISO-8859-1" & quote & "?>"), oneLine(tText)
      if tTree is an integer then revXMLDeleteTree tTree
      -- An attribute value that the end of the document cuts off keeps what
      -- was read (2.15 lost the attribute)
      put revXMLCreateTree("<root><z a='cut", false, true, false) into tTree
      check "revXML keeps a cut-off attribute value", tTree is an integer and revXMLAttribute(tTree, "/root/z", "a") is "cut", line 1 to 2 of tTree
      if tTree is an integer then revXMLDeleteTree tTree
      -- A declared entity reused far past 5 times the document's size parses
      -- (2.15 refused it even with XML_PARSE_HUGE); nested entities that
      -- expand without bound ("billion laughs") are still refused
      put empty into tEntity
      repeat 200 times
         put "0123456789" after tEntity
      end repeat
      put "<!DOCTYPE root [<!ENTITY e " & quote & tEntity & quote & ">]><root>" into tXML
      repeat 600 times
         put "<z>&e;</z>" after tXML
      end repeat
      put revXMLCreateTree(tXML & "</root>", true, true, false) into tTree
      check "revXML reuses a large entity", tTree is an integer and revXMLNumberOfChildren(tTree, "/root", "z", 0) = 600, line 1 to 2 of tTree
      if tTree is an integer then revXMLDeleteTree tTree
      put "<!DOCTYPE root [<!ENTITY l0 " & quote & "lol" & quote & ">" into tXML
      repeat with tLevel = 1 to 9
         put "<!ENTITY l" & tLevel & " " & quote after tXML
         repeat 10 times
            put "&l" & (tLevel - 1) & ";" after tXML
         end repeat
         put quote & ">" after tXML
      end repeat
      put revXMLCreateTree(tXML & "]><root>&l9;</root>", true, true, false) into tTree
      check "revXML refuses an entity bomb", tTree begins with "xmlerr" and tTree contains "amplification", line 1 to 2 of tTree
      if tTree is an integer then revXMLDeleteTree tTree
      -- XSLT: a transformation that xsl:message terminate="yes" stops
      -- returns what it made until then, as libxslt 1.1.28 did (1.1.45
      -- alone returned nothing; the message itself goes to stderr)
      put "<xsl:stylesheet version=" & quote & "1.0" & quote & " xmlns:xsl=" & quote & "http://www.w3.org/1999/XSL/Transform" & quote & ">" & \
            "<xsl:output method=" & quote & "text" & quote & "/><xsl:template match=" & quote & "/" & quote & ">before" & \
            "<xsl:message terminate=" & quote & "yes" & quote & ">smoke test: stopped on purpose</xsl:message>after" & \
            "</xsl:template></xsl:stylesheet>" into tXSL
      put revXMLCreateTree(tXSL, false, true, false) into tXSLTree
      put revXMLCreateTree("<root/>", false, true, false) into tTree
      put xsltApplyStylesheet(tTree, xsltLoadStylesheet(tXSLTree)) into tResult
      check "XSLT returns the output of a terminated transform", tResult is "before", tResult
      if tXSLTree is an integer then revXMLDeleteTree tXSLTree
      -- translate() over native text: libxml2 2.9 stopped the translation at
      -- a byte that is not UTF-8 (2.15 stopped the whole transform)
      put "<xsl:stylesheet version=" & quote & "1.0" & quote & " xmlns:xsl=" & quote & "http://www.w3.org/1999/XSL/Transform" & quote & ">" & \
            "<xsl:output method=" & quote & "text" & quote & "/><xsl:template match=" & quote & "/" & quote & ">" & \
            "[<xsl:value-of select=" & quote & "translate(/p,'ab','AB')" & quote & "/>]after</xsl:template></xsl:stylesheet>" into tXSL
      put revXMLCreateTree(tXSL, false, true, false) into tXSLTree
      put revXMLCreateTree("<p>abc caf" & numToChar(233) & "</p>", false, true, false) into tDoc
      put xsltApplyStylesheet(tDoc, xsltLoadStylesheet(tXSLTree)) into tResult
      check "XSLT translate() over native text", tResult is ("[ABc cAf" & numToChar(233) & "]after"), tResult
      if tDoc is an integer then revXMLDeleteTree tDoc
      if tXSLTree is an integer then revXMLDeleteTree tXSLTree
      -- HTML output names its encoding in a meta http-equiv element, as
      -- libxml2 2.9 wrote it (2.15 writes <meta charset>)
      put "<xsl:stylesheet version=" & quote & "1.0" & quote & " xmlns:xsl=" & quote & "http://www.w3.org/1999/XSL/Transform" & quote & ">" & \
            "<xsl:output method=" & quote & "html" & quote & "/><xsl:template match=" & quote & "/" & quote & ">" & \
            "<html><head><title>T</title></head><body/></html></xsl:template></xsl:stylesheet>" into tXSL
      put revXMLCreateTree(tXSL, false, true, false) into tXSLTree
      put xsltApplyStylesheet(tTree, xsltLoadStylesheet(tXSLTree)) into tResult
      check "XSLT HTML output has a Content-Type meta", tResult contains ("<meta http-equiv=" & quote & "Content-Type" & quote & " content=" & quote & "text/html; charset=UTF-8" & quote & ">"), oneLine(tResult)
      if tXSLTree is an integer then revXMLDeleteTree tXSLTree
      if tTree is an integer then revXMLDeleteTree tTree
      -- XPath results longer than revXML's result buffer: 0.2.4 wrote past
      -- its end (heap corruption) and builds with _FORTIFY_SOURCE abort, so
      -- this one is last
      put empty into tLong
      repeat 4000 times
         put "0123456789" after tLong
      end repeat
      put revXMLCreateTree("<root><z>" & tLong & "</z></root>", false, true, false) into tTree
      put revXMLDataFromXPathQuery(tTree, "/root/z", ",", "|") into tData
      check "revXML XPath data of a long text", tData is (tLong & ",|"), the number of chars in tData & " chars"
      if tTree is an integer then revXMLDeleteTree tTree
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
      -- libzip 1.12 under revZip (see thirdparty/libzip/ORIGIN): files and
      -- stored items, a UTF-8 name, then update in place
      put tTemp & "/oxt_smoke_test_in.txt" into tFile
      -- compressible, so libzip keeps it deflated rather than storing it
      put empty into tFileData
      repeat 50 times
         put "file content " after tFileData
      end repeat
      put tFileData into URL ("binfile:" & tFile)
      put "stored" into tZipData
      revZipOpenArchive tZip, "write"
      revZipAddItemWithFile tZip, "dir/file.txt", tFile
      revZipAddUncompressedItemWithData tZip, "stored.txt", "tZipData"
      revZipAddItemWithData tZip, textDecode("caf" & numToByte(195) & numToByte(169) & ".txt", "UTF-8"), "tZipData"
      revZipAddItemWithFile tZip, "missing.txt", tTemp & "/oxt_smoke_test_no_such_file"
      check "revZip refuses a missing file", the result begins with "ziperr", the result
      revZipCloseArchive tZip
      check "revZip writes an archive", the result is empty, the result
      revZipOpenArchive tZip, "update"
      put revZipEnumerateItems(tZip) into tItems
      check "revZip lists three items", the number of lines of tItems is 3 and line 3 of tItems is textDecode("caf" & numToByte(195) & numToByte(169) & ".txt", "UTF-8"), tItems
      check "revZip stores uncompressed items", item 6 of revZipDescribeItem(tZip, "stored.txt") is "none", revZipDescribeItem(tZip, "stored.txt")
      check "revZip deflates", item 6 of revZipDescribeItem(tZip, "dir/file.txt") is "deflate", revZipDescribeItem(tZip, "dir/file.txt")
      revZipSetItemAttributes tZip, "stored.txt", 3, 1234
      revZipRenameItem tZip, "dir/file.txt", "renamed.txt"
      revZipDeleteItem tZip, textDecode("caf" & numToByte(195) & numToByte(169) & ".txt", "UTF-8")
      put "replaced" into tZipData
      revZipReplaceItemWithData tZip, "stored.txt", "tZipData"
      put revZipEnumerateItems(tZip) into tItems
      check "revZip lists pending changes", tItems is ("renamed.txt" & return & "stored.txt" & return), tItems
      revZipCloseArchive tZip
      check "revZip updates an archive", the result is empty, the result
      revZipOpenArchive tZip, "read"
      revZipExtractItemToVariable tZip, "stored.txt", "tUnzipped"
      check "revZip replaced item", tUnzipped is "replaced", tUnzipped
      check "revZip attributes", revZipGetItemAttributes(tZip, "stored.txt") is "3,1234", revZipGetItemAttributes(tZip, "stored.txt")
      put tTemp & "/oxt_smoke_test_out.txt" into tOutFile
      revZipExtractItemToFile tZip, "renamed.txt", tOutFile
      put the result into tExtractResult
      check "revZip extracts to a file", tExtractResult is empty and URL ("binfile:" & tOutFile) is URL ("binfile:" & tFile), tExtractResult
      revZipCloseArchive tZip
      check "revZip has no archives open", revZipOpenArchives() is empty, revZipOpenArchives()
      if there is a file tOutFile then delete file tOutFile
      if there is a file tZip then delete file tZip
      -- An item added and deleted before the archive is closed is not
      -- listed (libzip 1.12 answers ZIP_ER_INVAL for it, not
      -- ZIP_ER_DELETED); a file added to an archive is read when it is
      -- closed, so what was written to it in between is stored too
      put "first line" & return into URL ("binfile:" & tFile)
      revZipOpenArchive tZip, "write"
      revZipAddItemWithData tZip, "one.txt", "tZipData"
      revZipAddItemWithData tZip, "two.txt", "tZipData"
      revZipDeleteItem tZip, "one.txt"
      put revZipEnumerateItems(tZip) into tItems
      check "revZip forgets an item added then deleted", tItems is ("two.txt" & return), tItems
      -- An item still to be written has no compressed size yet (-1) and the
      -- method "none", as the old revZip described it
      put revZipDescribeItem(tZip, "two.txt") into tDescription
      check "revZip describes an item still to be written", item 5 to 6 of tDescription is "-1,none", tDescription
      revZipAddItemWithFile tZip, "grow.txt", tFile
      put "second line" & return after URL ("binfile:" & tFile)
      revZipCloseArchive tZip
      check "revZip writes after a delete", the result is empty, the result
      revZipOpenArchive tZip, "read"
      revZipExtractItemToVariable tZip, "grow.txt", "tUnzipped"
      check "revZip stores what was written to a file before close", tUnzipped is ("first line" & return & "second line" & return), tUnzipped
      revZipCloseArchive tZip
      if there is a file tFile then delete file tFile
      if there is a file tZip then delete file tZip
      -- "write" where no archive can be made (its folder does not exist)
      -- fails at open with the system's reason, as the old libzip did;
      -- libzip 1.12 alone opened it and failed at close, after every item
      -- had been added
      put tTemp & "/oxt_smoke_test_no_such_folder/new.zip" into tZip
      revZipOpenArchive tZip, "write"
      put the result into tOpenResult
      put tZip is among the lines of revZipOpenArchives() into tIsOpen
      check "revZip write to an uncreatable path fails at open", tOpenResult begins with "ziperr" and not tIsOpen, "result '" & tOpenResult & "', open: " & tIsOpen
      if tIsOpen then revZipCloseArchive tZip
   catch tError
      check "no script error (revZip checks)", false, tError
   end try

   -- The xTalk Suite extensions bundled in Extensions (only when the
   -- layout has them)
   if $OXT_XTALK_PROBES is not empty then
      try
         checkXtalkExtensions $OXT_XTALK_PROBES, $OXT_EXTENSIONS_DIR
      catch tError
         check "no script error (xTalk extension checks)", false, oneLine(tError)
      end try
   end if

   write "SUMMARY passed=" & sPasses & " failed=" & sFails & return to stdout
   quit sFails
end startup

private function oneLine pText
   replace return with " " in pText
   replace numToCodepoint(13) with " " in pText
   return pText
end oneLine

-- Loads and calls every extension in the list pProbeFile (tab-separated
-- lines written by smoke-test.ps1 from tools/oxt/xtalk-extensions.json):
--    lcb <folder> <module id> <probe> <expected (regex)> <missing DLLs>
--    lcs <folder> <stack> <probe> <expected (regex)> <requires>
--    missing <folder>
private command checkXtalkExtensions pProbeFile, pExtensionsDir
   local tList, tFields
   replace "\" with "/" in pProbeFile
   replace "\" with "/" in pExtensionsDir
   put textDecode(URL ("binfile:" & pProbeFile), "UTF-8") into tList
   replace numToCodepoint(13) with empty in tList
   write "INFO xtalk extensions=" & pExtensionsDir & return to stdout
   repeat for each line tLine in tList
      if tLine is empty then next repeat
      put tLine into tFields
      split tFields by tab
      switch tFields[1]
         case "lcb"
            checkXtalkLcb pExtensionsDir & "/" & tFields[2], tFields[2], tFields[3], tFields[4], tFields[5], tFields[6]
            break
         case "lcs"
            checkXtalkLcs pExtensionsDir & "/" & tFields[2], tFields[2], tFields[3], tFields[4], tFields[5]
            break
         default
            check "xtalk " & tFields[2] & " present", false, "listed in tools/oxt/xtalk-extensions.json but not in " & pExtensionsDir
      end switch
   end repeat
end checkXtalkExtensions

-- An LCB library, loaded as the IDE loads it (revideextensionlibrary
-- __LoadExtension): first every file of the code folders that match
-- sCodeFolders (code/<processor>-win32 on Windows) is mapped in
-- revLibraryMapping under its name without the extension
-- (__MapCodeLibraryForIDE), because the engine resolves a foreign handler's
-- "c:<token>>" library through that mapping; then module.lcm is loaded.
private command checkXtalkLcb pDir, pFolder, pId, pProbe, pExpect, pMissingRuntime
   local tCode, tLibrary, tMapped, tResult, tFolders
   try
      put 0 into tMapped
      put codeFolders(pDir & "/code") into tFolders
      repeat for each line tFolder in tFolders
         put pDir & "/code/" & tFolder into tCode
         repeat for each line tFile in files(tCode)
            if tFile begins with "." then next repeat
            set the itemDelimiter to "."
            put item 1 to -2 of tFile into tLibrary
            set the itemDelimiter to comma
            if tLibrary is empty then next repeat
            set the revLibraryMapping[tLibrary] to tCode & "/" & tLibrary
            add 1 to tMapped
         end repeat
      end repeat
      load extension from file (pDir & "/module.lcm") with resource path pDir
      put the result into tResult
      check "xtalk " & pFolder & " loads", tResult is empty and pId is among the lines of the loadedExtensions, \
            "result '" & tResult & "', " & tMapped & " code libraries mapped"
      if tResult is empty then
         checkXtalkProbe pFolder, pProbe, pExpect
      end if
   catch tError
      check "xtalk " & pFolder & " loads", false, oneLine(tError)
   end try
   -- This machine has the Visual C++ runtime (or, on Linux and macOS,
   -- whatever the build machine installed), so the library loaded
   -- whatever is next to it; on a machine without it it would not.
   if pMissingRuntime is empty then
      if the platform is "Win32" then
         check "xtalk " & pFolder & " DLL imports", true, "every import is a Windows system DLL or next to the library"
      else
         check "xtalk " & pFolder & " " & sSystemName, true, "every library it needs is a system library or next to it"
      end if
   else
      check "xtalk " & pFolder & " " & sSystemName, false, pMissingRuntime & " (not bundled; cannot load on a machine without it)"
   end if
end checkXtalkLcb

-- The folders of pCode (an extension's code folder) whose libraries the
-- IDE maps on this platform: those matching the patterns of sCodeFolders,
-- in their order, each once
private function codeFolders pCode
   local tAll, tMatched, tResult
   if there is not a folder pCode then return empty
   put folders(pCode) into tAll
   set the itemDelimiter to comma
   repeat for each item tPattern in sCodeFolders
      filter lines of tAll with tPattern into tMatched
      repeat for each line tFolder in tMatched
         if tFolder is not empty and tFolder is not among the lines of tResult then
            put tFolder & return after tResult
         end if
      end repeat
   end repeat
   if tResult is not empty then delete the last char of tResult
   return tResult
end codeFolders

-- A script library: started with "start using", as the members' docs tell
-- users, then its probe; then the extensionInitialize and extensionFinalize
-- handlers that the IDE sends must put it into the back scripts and take
-- it out again.
private command checkXtalkLcs pDir, pFolder, pStack, pProbe, pExpect
   local tName, tInBack, tOutOfBack
   try
      put the short name of stack (pDir & "/" & pStack & ".livecodescript") into tName
      start using stack tName
      check "xtalk " & pFolder & " start using", tName is pStack and tName is among the lines of the stacksInUse, \
            "stack " & quote & tName & quote
      checkXtalkProbe pFolder, pProbe, pExpect
      send "extensionInitialize" to stack tName
      put the long id of stack tName is among the lines of the backScripts into tInBack
      send "extensionFinalize" to stack tName
      put the long id of stack tName is not among the lines of the backScripts into tOutOfBack
      check "xtalk " & pFolder & " extensionInitialize/extensionFinalize", tInBack and tOutOfBack, \
            "in the back scripts after extensionInitialize: " & tInBack & ", out after extensionFinalize: " & tOutOfBack
   catch tError
      check "xtalk " & pFolder & " start using", false, oneLine(tError)
   end try
end checkXtalkLcs

private command checkXtalkProbe pFolder, pProbe, pExpect
   local tValue
   try
      put value(pProbe) into tValue
      check "xtalk " & pFolder & " " & pProbe, matchText(tValue, pExpect), tValue
   catch tError
      check "xtalk " & pFolder & " " & pProbe, false, "script error: " & oneLine(tError)
   end try
end checkXtalkProbe
