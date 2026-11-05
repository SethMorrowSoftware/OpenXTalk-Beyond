script "DocsParser"
/*
Copyright (C) 2015 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

on TestSetup
   TestSkipIfNot "docs"
   
   -- Only run these tests on desktop platforms
   if the platform is not among the items of "MacOS,Windows,Linux" then
      return "SKIP Tests are not runnable on" && the platform
   end if

   local tDocsParser
   put TestGetEngineRepositoryPath() & "/ide-support/revdocsparser.livecodescript" into tDocsParser
   start using stack tDocsParser
end TestSetup

on TestBug16323
   local tDoc
   put "/*" into tDoc
   put return & "Name: OnOpen" after tDoc
   put return & "Type: message" after tDoc
   put return & "Syntax: OnOpen" after tDoc
   put return & "Name: OnClose" after tDoc
   put return & "Type: message" after tDoc
   put return & "Syntax: OnClose" after tDoc
   put return & "*/" after tDoc
   put return & "module com.livecode.widget" after tDoc
   put return & "end module" after tDoc

   local tParsed
   put revDocsGenerateDocsFileFromText(tDoc, "") into tParsed

   local tArray
   put revDocsParseDocTextToLibraryArray("", tParsed, "", "") into tArray

   TestAssert "unwanted syntax element accumulation", tArray["doc"][2]["Syntax"][2] is empty
end TestBug16323

on TestBug17523
   local tModule
   put "widget com.livecode.testdocs" into tModule
   put return & "/**" after tModule
   put return & "Summary: Test" after tModule
   put return & "*/" after tModule
   put return & "property" && quote & "testProp" & quote && "get mTest" after tModule
   put return & "end widget" after tModule
   
   local tParsed
   put revDocsGenerateDocsFileFromText(tModule, "") into tParsed
   
   local tArray
   put revDocsParseDocTextToLibraryArray("", tParsed, "", "") into tArray
   
   TestAssert "property name has quotes stripped", tArray["doc"][1]["display name"] is "testProp"
end TestBug17523

-- A script library's block followed by a handler instead of another doc
-- block (Skids, openxtalk.org p=25980 and p=25983, building Stam's
-- PhotonJson as an extension): the library keeps its name, title and
-- version, and extensionInitialize takes no docs from it. A first
-- handler's own docs (a Summary) stay that handler's.
private function docsLibraryParsed pScript
   local tStack, tParsed
   create invisible stack "docsparser_library"
   put the long id of stack "docsparser_library" into tStack
   set the script of tStack to pScript
   put revDocsGenerateDocsFileFromText(the script of tStack, tStack) into tParsed
   delete stack "docsparser_library"
   return tParsed
end docsLibraryParsed

on TestLibraryBlockBeforeAHandler
   local tScript, tParsed, tArray
   put "/**" & return & "Title: Photon JSON" & return & "Version: 1.2.0" & return & \
         "Description: Reads and writes JSON." & return & "*/" & return & \
         "on extensionInitialize" & return & "   insert the script of me into back" & return & \
         "end extensionInitialize" & return & return & \
         "/**" & return & "Summary: Parse JSON text" & return & return & \
         "Parameters:" & return & "pText: JSON text" & return & return & \
         "Description: Turns JSON into an array." & return & "*/" & return & \
         "function pjParse pText" & return & "   return pText" & return & "end pjParse" into tScript
   put docsLibraryParsed(tScript) into tParsed
   TestDiagnostic tParsed
   TestAssert "the library is named after its stack", "Library: docsparser_library" is among the lines of tParsed
   TestAssert "the library keeps its title", tParsed contains "Title: Photon JSON"
   TestAssert "the library keeps its version", tParsed contains "Version: 1.2.0"
   TestAssert "extensionInitialize takes no docs", not (tParsed contains "extensionInitialize")
   TestAssert "the documented handler keeps its docs", tParsed contains "Summary: Parse JSON text"
end TestLibraryBlockBeforeAHandler

on TestFirstHandlerDocsStayItsOwn
   local tScript, tParsed
   put "/**" & return & "Summary: Parse JSON text" & return & "*/" & return & \
         "function pjParse pText" & return & "   return pText" & return & "end pjParse" into tScript
   put docsLibraryParsed(tScript) into tParsed
   TestDiagnostic tParsed
   TestAssert "a first handler's own docs are not a library block", tParsed contains "Summary: Parse JSON text"
   TestAssert "no library from a handler's docs", not (tParsed contains "Library: docsparser_library")
end TestFirstHandlerDocsStayItsOwn
