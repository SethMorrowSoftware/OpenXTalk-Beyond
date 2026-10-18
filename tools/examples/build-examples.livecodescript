script "OXTBuildExamples"
-- OXT-Beyond: builds the remastered examples (tools/examples/README.md).
--
-- Run it with the development engine of an installed OXT-Beyond, without
-- the IDE, from a checkout:
--
--    <install>/OXT-Beyond -ui tools/examples/build-examples.livecodescript
--
-- It builds every example in kExamples, or those named (by their
-- builders' file names, comma separated) in OXT_EXAMPLES, into
-- ide/Resources/Examples/Remastered, or the folder in OXT_EXAMPLES_OUT.
-- Before it saves a stack it compiles every script in it as the IDE's
-- strict compilation mode does, and a script that does not compile stops
-- the build. It writes a line for each step to stdout, and ends with
-- "DONE" (exit code 0) or "FAILED <reason>" (exit code 1).
--
-- The icons are drawn by the drawing library's drawingSvgCompile, which
-- reads SVG with revXML. Without the IDE neither is loaded, so this
-- script loads them from the install it runs in, as the IDE does.

-- The examples, by their builders' file names in this folder
constant kExamples = "animate-letter,quick-start,scroll-image,rss-reader,video-player,bouncing-balls,balloon-game,sqlite-tour,zip-archives,book-library,data-grid-tour,data-grid-table,sqlite-book-library"

on startup
   local tFolder, tRepo, tOut, tName, tError, tExamples
   set the itemDelimiter to slash
   put item 1 to -2 of the filename of me into tFolder
   put item 1 to -4 of the filename of me into tRepo
   set the itemDelimiter to comma
   put $OXT_EXAMPLES_OUT into tOut
   if tOut is empty then
      put tRepo & "/ide/Resources/Examples/Remastered" into tOut
   end if
   put $OXT_EXAMPLES into tExamples
   if tExamples is empty then
      put kExamples into tExamples
   end if
   try
      buildDrawing
      start using stack (tRepo & "/ide/Toolset/palettes/learn/revlearnkit.livecodescript")
      start using stack (tFolder & "/builder.livecodescript")
      repeat for each item tName in tExamples
         buildLog "BUILD" && tName
         dispatch "exBuild" to stack (tFolder & "/" & tName & ".livecodescript") with tOut
         if it is not "handled" then
            throw tName & ".livecodescript has no exBuild handler"
         end if
         buildLog "SAVED" && the result
      end repeat
   catch tError
      buildLog "FAILED" && buildErrorText(tError)
      if $OXT_EXAMPLES_DEBUG is not empty then
         buildLog tError
      end if
      quit 1
   end try
   buildLog "DONE"
   quit 0
end startup

command buildLog pLine
   write pLine & return to stdout
end buildLog

-- An error, in words: the compiler's or the engine's message for its first
-- line, or the text a builder threw
private function buildErrorText pError
   local tLine, tCode, tText
   if item 1 of line 1 of pError is not an integer then
      return line 1 of pError
   end if
   repeat for each line tLine in pError
      put item 1 of tLine into tCode
      if tCode is an integer and tCode > 0 then
         put line tCode of the scriptExecutionErrors into tText
         if tText is not empty then
            return tText && "(line" && item 2 of tLine & ", near" && item 4 to -1 of tLine & ")"
         end if
      end if
   end repeat
   return pError
end buildErrorText

-- Loads revXML and the drawing library, unless they are loaded already
-- (in the IDE they are)
private command buildDrawing
   local tEngine, tHelper, tLibrary, tError
   try
      if the number of bytes of drawingSvgCompile("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'><path d='M0 0h4' stroke='#000'/></svg>") > 0 then
         exit buildDrawing
      end if
   catch tError
   end try
   put specialFolderPath("engine") into tEngine
   if $OXT_INSTALL is not empty then
      put $OXT_INSTALL into tEngine
   end if
   -- (an external is loaded by a stack whose externals name it; the
   -- stack must be on disk for the engine to load them. Its file's name
   -- is this run's own, so that two builds at once do not share it)
   put specialFolderPath("temporary") & "/oxt-examples-xml-" & the milliseconds & "-" & random(1000000) & ".livecode" into tHelper
   create stack "oxtExamplesXml"
   if the platform is "Win32" then
      set the externals of stack "oxtExamplesXml" to tEngine & "/Externals/revxml.dll"
   else if the platform is "MacOS" then
      set the externals of stack "oxtExamplesXml" to tEngine & "/Externals/revxml.bundle"
   else
      set the externals of stack "oxtExamplesXml" to tEngine & "/Externals/revxml.so"
   end if
   save stack "oxtExamplesXml" as tHelper
   delete stack "oxtExamplesXml"
   start using stack tHelper
   delete file tHelper
   put tEngine & "/Extensions/com.livecode.library.drawing/drawing.livecodescript" into tLibrary
   if there is no file tLibrary then
      throw "no drawing library at " & tLibrary & ": set OXT_INSTALL to the installed OXT-Beyond"
   end if
   -- (the library's start-up handler asks the standalone builder to
   -- include it; that handler is below, and does nothing)
   insert the script of me into back
   dispatch "extensionInitialize" to stack tLibrary
   if the number of bytes of drawingSvgCompile("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'><path d='M0 0h4' stroke='#000'/></svg>") is 0 then
      throw "the drawing library draws nothing: is revXML loaded?"
   end if
end buildDrawing

on revSBAddDependencyForInclusion
end revSBAddDependencyForInclusion
