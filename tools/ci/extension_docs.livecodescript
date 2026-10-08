script "oxt_extension_docs"
-- Writes the dictionary data of the extensions that OXT-Beyond installs, for
-- the text dictionary (tools/oxt/text_dictionary.py --extensions): for each
-- extension the JSON that the IDE makes of its docs for LiveCode's
-- Dictionary when it loads the extension (revIDEGetExtensionDocsData in
-- ide/Toolset/libraries/revidelibrary.8.livecodescript), with the docs
-- parser of the repository (ide-support/revdocsparser.livecodescript).
-- tools/ci/build_docs.sh runs it with the engine that runs the docs
-- builder, without the IDE:
--
--    OXT_EXTENSION_DOCS=<folder> LiveCode-Community -ui tools/ci/extension_docs.livecodescript
--
-- <folder> has extensions.txt (text_dictionary.py --list-extensions writes
-- it): one extension a line, its id, kind, source, title and author
-- separated by tabs. The source is the extension's api.lcdoc, or its .lcb
-- or .livecodescript file, whose docs are made as the extension build makes
-- them (extension-utils' extensionExtractDocs:
-- revDocsGenerateDocsFileFromModularFile of a .lcb,
-- revDocsGenerateDocsFileFromText of the script of a stack). The title
-- names the library's own entry, as the title of the extension's manifest
-- does in the IDE. For each it writes <id>.lcdoc and <id>.js into
-- <folder>; an extension whose docs document nothing gets neither.
--
-- Output: one EXTENSION line per extension, a NOTE line for each note of
-- the docs parser (but those about handlers without docs, which most
-- scripts have) and a SUMMARY line.
-- Exit code: 0 when every extension was read, 1 when one failed, 2 when the
-- tool could not run.

local sFailures

on startup
   local tScriptFolder, tRepo, tFolder, tList, tWritten
   set the lockMessages to true
   put 0 into sFailures
   put 0 into tWritten

   put $OXT_EXTENSION_DOCS into tFolder
   replace "\" with "/" in tFolder
   if the last char of tFolder is "/" then delete the last char of tFolder
   set the itemDelimiter to "/"
   put the effective filename of this stack into tScriptFolder
   replace "\" with "/" in tScriptFolder
   put item 1 to -2 of tScriptFolder into tScriptFolder
   put item 1 to -3 of tScriptFolder into tRepo
   set the itemDelimiter to comma

   write "INFO version=" & the version & " platform=" & the platform & return to stdout
   if tFolder is empty or there is not a file (tFolder & "/extensions.txt") then
      fatal "OXT_EXTENSION_DOCS is not a folder with extensions.txt: " & tFolder
   end if
   if there is not a file (tRepo & "/ide-support/revdocsparser.livecodescript") then
      fatal "no docs parser in " & tRepo
   end if
   try
      start using stack (tRepo & "/ide-support/revdocsparser.livecodescript")
   catch tError
      fatal "the docs parser does not load: " & oneLine(tError)
   end try
   -- the parser's log command calls the logMessage handler, which this
   -- script handles from the back of the message path
   insert the script of me into back
   set the logMessage to "oxtExtensionDocsNote"

   put readText(tFolder & "/extensions.txt") into tList
   set the itemDelimiter to tab
   repeat for each line tLine in tList
      if tLine is empty then next repeat
      local tId, tSource, tTitle, tAuthor, tDocs, tLibraryA, tJSON
      put item 1 of tLine into tId
      put item 3 of tLine into tSource
      put item 4 of tLine into tTitle
      put item 5 of tLine into tAuthor
      put empty into tDocs
      try
         if tSource ends with ".lcdoc" then
            put readText(tSource) into tDocs
         else if tSource ends with ".lcb" then
            put revDocsGenerateDocsFileFromModularFile(tSource) into tDocs
         else if there is a stack tSource then
            put revDocsGenerateDocsFileFromText(the script of stack tSource, \
                  the long id of stack tSource) into tDocs
         else
            throw "no such file or stack"
         end if
         if "Name:" is not among the words of tDocs then
            write "EXTENSION " & tId & " | no entries" & return to stdout
            next repeat
         end if
         put textEncode(tDocs, "UTF-8") into URL ("binfile:" & tFolder & "/" & tId & ".lcdoc")
         put revDocsParseDocFileToLibraryArray(tFolder & "/" & tId & ".lcdoc", tTitle, tAuthor) into tLibraryA
         put revDocsFormatLibraryDocArrayAsJSON(tLibraryA) into tJSON
         if tJSON is empty then throw "the docs parser made no JSON"
         put textEncode(tJSON, "UTF-8") into URL ("binfile:" & tFolder & "/" & tId & ".js")
         write "EXTENSION " & tId & " | " & the number of elements of tLibraryA["doc"] & " entries" & return to stdout
         add 1 to tWritten
      catch tError
         write "EXTENSION " & tId & " | FAILED " & tSource & ": " & oneLine(tError) & return to stdout
         add 1 to sFailures
      end try
   end repeat
   set the itemDelimiter to comma

   write "SUMMARY written=" & tWritten & " failed=" & sFailures & return to stdout
   if sFailures > 0 then quit 1
   quit 0
end startup

on oxtExtensionDocsNote pNote
   if pNote contains "Required documentation not found" or \
         pNote contains "No handlers documented" then
      exit oxtExtensionDocsNote
   end if
   write "NOTE " & oneLine(pNote) & return to stdout
end oxtExtensionDocsNote

private command fatal pMessage
   write "FATAL " & pMessage & return to stdout
   quit 2
end fatal

private function oneLine pText
   replace crlf with " " in pText
   replace return with " " in pText
   replace numToCodepoint(13) with " " in pText
   return pText
end oneLine

private function readText pFile
   local tText
   put textDecode(URL ("binfile:" & pFile), "UTF-8") into tText
   replace crlf with return in tText
   replace numToCodepoint(13) with return in tText
   return tText
end readText
