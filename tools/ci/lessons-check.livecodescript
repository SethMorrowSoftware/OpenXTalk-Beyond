script "oxt_lessons_check"
-- Headless run of the examples of the website's lessons
-- (tools/pages/lessons/src), each one as a reader runs it: pasted
-- into the xTalk Academy's playground, with the Academy's own runner
-- (revAcademyRun of Toolset/palettes/academy/revacademy.livecodescript),
-- so that what the page shows under "Output" is what the playground
-- shows. tools/ci/lessons_check.py takes the examples out of the page,
-- runs this script with an engine without the IDE (-ui) and compares what
-- each one put with what the page says it puts:
--
--    oxt-beyond -ui tools/ci/lessons-check.livecodescript
--
-- Environment variables:
--    OXT_LESSONS_TOOLSET     the Toolset folder whose Academy runs the
--                            examples (required)
--    OXT_LESSONS_DIR         the examples, as lessons_check.py writes them
--                            (required): for each one <name>.xt, its code,
--                            and <name>.how, how to run it (below)
--    OXT_LESSONS_EXTENSIONS  the folder of the extensions an example may
--                            need (an installed IDE's Extensions), each
--                            in a folder of its own with its module.lcm
--    OXT_LESSONS_EXTERNALS   the folder of the externals an example may
--                            need (an installed IDE's Externals: revdb and
--                            the others, with its Database Drivers)
--
-- <name>.how has a line for each thing: its first line is how the example
-- is run, its second how many seconds to wait after the run (for a timer
-- the example starts), its third "shot" when the lesson shows what the
-- example drew, and the lines after them the extensions it needs (a
-- folder of OXT_LESSONS_EXTENSIONS, or the path of a .lcm file) and the
-- externals ("external:revdb"), which the IDE loads as it starts and
-- this script loads before the example:
--    run      run with revAcademyRun, as the playground's Run does
--    compile  set as an object's script (handlers only: what goes into a
--             button or a stack, such as one that opens a dialog or needs
--             the internet), which must compile, and is not run
--
-- For each example it writes <name>.res: "ok" or "error" on its first
-- line, then the error's title, its words and its line (the Academy's,
-- as the playground shows them), and <name>.out, what the example put, a
-- line a value, as UTF-8. For an example with a shot it also writes
-- <name>.png, a snapshot of the stage's card as the run (and the wait)
-- left it, at twice its size, so that it is sharp on a screen of high
-- density: the stage is the window the playground shows what the code
-- made in (revAcademyStage), and the Academy leaves it until the next
-- run. With no stage there is no .png. Output on stdout: an INFO line for each example
-- and a DONE line. The exit code is 0 when every example was run (whatever
-- it did: lessons_check.py decides), and 2 when the check could not run.

local sHost, sLate

on startup
   local tToolset, tDir, tFiles, tFile, tName, tCount, tError
   put $OXT_LESSONS_TOOLSET into tToolset
   put $OXT_LESSONS_DIR into tDir
   if tToolset is empty or tDir is empty then
      write "ERROR OXT_LESSONS_TOOLSET and OXT_LESSONS_DIR must be set" & return to stdout
      quit 2
   end if
   try
      get the short name of stack (tToolset & "/palettes/academy/revacademy.livecodescript")
      get the short name of stack (tToolset & "/palettes/learn/revlearnkit.livecodescript")
   catch tError
      write "ERROR could not load the Academy:" && line 1 of tError & return to stdout
      quit 2
   end try
   -- libURL (URL "http:" and the other internet commands), which the IDE
   -- puts into use as it starts: an installed Toolset has it among its
   -- libraries, and this checkout keeps it in ide-support
   put tToolset & "/libraries/revliburl.livecodescript" into tFile
   if there is not a file tFile then
      set the itemDelimiter to slash
      put item 1 to -3 of tToolset & "/ide-support/revliburl.livecodescript" into tFile
      set the itemDelimiter to comma
   end if
   if there is a file tFile then
      start using stack tFile
   else
      write "INFO no libURL beside the Toolset: an example that uses the internet will fail" & return to stdout
   end if
   -- (the output a timer puts after the run comes here: see runExample)
   create invisible stack "oxtLessonsHost"
   set the script of stack "oxtLessonsHost" to \
         "on revAcademyOutput pText" & return & \
         "   dispatch " & quote & "lessonsLate" & quote & " to stack " & quote & "oxt_lessons_check" & quote & " with pText" & return & \
         "end revAcademyOutput" & return & \
         "on revAcademyError pError" & return & \
         "   dispatch " & quote & "lessonsLateError" & quote & " to stack " & quote & "oxt_lessons_check" & quote & " with pError" & return & \
         "end revAcademyError"
   put the long id of stack "oxtLessonsHost" into sHost
   put files(tDir) into tFiles
   sort lines of tFiles
   put 0 into tCount
   repeat for each line tFile in tFiles
      if tFile ends with ".xt" then
         put char 1 to -4 of tFile into tName
         runExample tDir, tName
         add 1 to tCount
      end if
   end repeat
   write "DONE examples=" & tCount & return to stdout
   quit 0
end startup

command runExample pDir, pName
   local tCode, tHow, tMode, tWait, tShot, tNeed, tProblem, tRun, tOut, tRes, tLoaded, tUntil
   put textDecode(URL ("binfile:" & pDir & "/" & pName & ".xt"), "UTF-8") into tCode
   put textDecode(URL ("binfile:" & pDir & "/" & pName & ".how"), "UTF-8") into tHow
   put line 1 of tHow into tMode
   put line 2 of tHow into tWait
   put line 3 of tHow is "shot" into tShot
   put empty into tProblem
   repeat for each line tNeed in line 4 to -1 of tHow
      if tNeed is not empty and tProblem is empty then
         put loadExtension(tNeed) into tProblem
      end if
   end repeat
   if tProblem is not empty then
      put "error" & return & "The extension did not load" & return & tProblem & return & 0 into tRes
   else if tMode is "compile" then
      put compileOnly(tCode) into tProblem
      if tProblem is empty then
         put "ok" into tRes
      else
         put "error" & return & "It does not compile" & return & tProblem & return & 0 into tRes
      end if
   else
      put empty into sLate
      dispatch function "revAcademyRun" to stack "revAcademy" with tCode, false
      put the result into tRun
      put tRun["output"] into tOut
      if tWait is a number and tWait > 0 then
         -- What a timer the example started puts after the run: the stage
         -- sends it to its host, which here is this script's
         if there is a stack "revAcademyStage" then
            set the cAcademyHost of stack "revAcademyStage" to sHost
         end if
         -- (in short steps: in an engine without a window, one long wait
         -- with messages answers timers but not sockets, which the IDE's
         -- event loop answers as they come)
         put the milliseconds + tWait * 1000 into tUntil
         repeat while the milliseconds < tUntil
            wait 20 milliseconds with messages
         end repeat
         if sLate is not empty then
            if tOut is empty and tRun["output"] is empty then
               put char 1 to -2 of sLate into tOut
            else
               put return & char 1 to -2 of sLate after tOut
            end if
         end if
         if there is a stack "revAcademyStage" then
            set the cAcademyHost of stack "revAcademyStage" to the long id of stack "revAcademy"
         end if
      end if
      if tRun["ok"] then
         put "ok" into tRes
      else
         put "error" & return & tRun["title"] & return & line 1 of tRun["error"] & return & tRun["line"] into tRes
      end if
      if tShot then
         takeShot pDir & "/" & pName & ".png"
      end if
   end if
   put textEncode(tRes, "UTF-8") into URL ("binfile:" & pDir & "/" & pName & ".res")
   put textEncode(tOut, "UTF-8") into URL ("binfile:" & pDir & "/" & pName & ".out")
   write "INFO" && pName && line 1 of tRes & return to stdout
end runExample

-- A snapshot of the stage's card, as the run left it, into the PNG file
-- pFile: twice the card's size, which the engine draws anew at that size
-- (text and lines stay sharp), not a copy of the screen made bigger. The
-- stage is invisible here (the Academy's window is not open, so it does
-- not show it), and the engine draws an invisible stack's card all the
-- same. With no stage, no file.
command takeShot pFile
   local tWidth, tHeight, tProblem
   if there is no stack "revAcademyStage" then
      exit takeShot
   end if
   put the width of this card of stack "revAcademyStage" into tWidth
   put the height of this card of stack "revAcademyStage" into tHeight
   try
      export snapshot from this card of stack "revAcademyStage" at size 2 * tWidth, 2 * tHeight to file pFile as PNG
   catch tProblem
      write "INFO snapshot failed:" && line 1 of tProblem & return to stdout
   end try
end takeShot

-- A value a timer put after the run (sent by the host stack)
command lessonsLate pText
   put pText & return after sLate
end lessonsLate

-- An error in a handler that ran after the run
command lessonsLateError pError
   put "(error after the run:" && line 1 of pError & ")" & return after sLate
end lessonsLateError

-- Loads the extension pNeed (a folder of OXT_LESSONS_EXTENSIONS, or a
-- .lcm file), once; empty, or why it did not load
function loadExtension pNeed
   local tFile, tFolder, tLibrary, tProblem
   if pNeed begins with "external:" then
      return loadExternal(char (the length of "external:") + 1 to -1 of pNeed)
   end if
   if pNeed is among the lines of the cLoaded of me then
      return empty
   end if
   if pNeed ends with ".lcm" then
      put pNeed into tFile
      set the itemDelimiter to slash
      put item 1 to -2 of tFile into tFolder
      set the itemDelimiter to comma
   else
      if $OXT_LESSONS_EXTENSIONS is empty then
         return "OXT_LESSONS_EXTENSIONS is not set, and the example needs" && pNeed
      end if
      put $OXT_LESSONS_EXTENSIONS & "/" & pNeed into tFolder
      if there is not a folder tFolder then
         -- a folder named with its version, as the Calendar and Pie Chart
         -- widgets' are (com.livecode.widget.piechart.1.0.0)
         put versionedFolder($OXT_LESSONS_EXTENSIONS, pNeed) into tFolder
      end if
      -- the module file the IDE loads (revIDEExtensionModuleFileInFolder):
      -- module.lcm, or else the engine's own module.2.lcm, or module.0.lcm
      put tFolder & "/module.lcm" into tFile
      if there is not a file tFile and there is a file (tFolder & "/module.2.lcm") then
         put tFolder & "/module.2.lcm" into tFile
      else if there is not a file tFile and there is a file (tFolder & "/module.0.lcm") then
         put tFolder & "/module.0.lcm" into tFile
      end if
      if there is not a file tFile then
         -- an extension written in xTalk (a script library), which the IDE
         -- puts into use as it starts (revInternal__LoadLibrary): it
         -- sends the library's stack extensionInitialize, which puts its
         -- script into the message path and sets it up (the MIME library
         -- fills its table of types), and starts using a stack that has
         -- no such handler
         put files(tFolder) into tLibrary
         filter tLibrary with "*.livecodescript"
         if the number of lines of tLibrary is 1 then
            put tFolder & "/" & tLibrary into tLibrary
            if "extensionInitialize" is among the items of handlerNames(tLibrary) then
               try
                  send "extensionInitialize" to stack tLibrary
               catch tProblem
                  return tProblem
               end try
            else
               start using stack tLibrary
               if the result is not empty then
                  return the result
               end if
            end if
            set the cLoaded of me to the cLoaded of me & pNeed & return
            return empty
         end if
      end if
   end if
   if there is not a file tFile then
      return "no file" && tFile
   end if
   -- as the IDE loads it (revideextensionlibrary's __LoadExtension): its
   -- native code libraries (code/<processor>-<platform>/) mapped by name,
   -- so that a foreign handler "binds to" one, and its resources folder,
   -- if it has one, as the resource path
   if there is a folder (tFolder & "/code") then
      mapCodeLibraries tFolder & "/code"
   end if
   if there is a folder (tFolder & "/resources") then
      load extension from file tFile with resource path (tFolder & "/resources")
   else
      load extension from file tFile
   end if
   if the result is not empty then
      return the result
   end if
   set the cLoaded of me to the cLoaded of me & pNeed & return
   return empty
end loadExtension

-- The names of the handlers of the stack in the file pFile, separated by
-- commas (the revAvailableHandlers lines: "M extensionInitialize 1 9")
function handlerNames pFile
   local tNames, tLine
   repeat for each line tLine in the revAvailableHandlers of stack pFile
      put word 2 of tLine & comma after tNames
   end repeat
   return char 1 to -2 of tNames
end handlerNames

-- The folder in pExtensions of the extension pId when its name carries
-- the extension's version (pId.1.0.0), or pId's own when there is none
function versionedFolder pExtensions, pId
   local tFolders, tFolder
   put folders(pExtensions) into tFolders
   filter tFolders with pId & ".[0-9]*"
   repeat for each line tFolder in tFolders
      if matchText(char (the length of pId) + 2 to -1 of tFolder, "^[0-9]+(\.[0-9]+)*$") then
         return pExtensions & "/" & tFolder
      end if
   end repeat
   return pExtensions & "/" & pId
end versionedFolder

-- Maps the native libraries in an extension's code folder pCode by name
-- (the revLibraryMapping), for this platform and processor, as the IDE's
-- __MapCodeLibraryForIDE does
command mapCodeLibraries pCode
   local tFolders, tFolder, tLibraries, tLibrary
   put folders(pCode) into tFolders
   switch the platform
      case "MacOS"
         filter tFolders with "*-mac*"
         break
      case "Win32"
         filter tFolders with "*-win32*"
         break
      default
         filter tFolders with "*-" & toLower(the platform) & "*"
   end switch
   repeat for each line tFolder in tFolders
      if not (tFolder begins with the processor & "-" or tFolder begins with "universal-") then
         next repeat
      end if
      put files(pCode & "/" & tFolder) & return & folders(pCode & "/" & tFolder) into tLibraries
      filter tLibraries without ".*"
      set the itemDelimiter to "."
      repeat for each line tLibrary in tLibraries
         if tLibrary is empty then
            next repeat
         end if
         delete the last item of tLibrary
         if tLibrary is not empty then
            set the revLibraryMapping[tLibrary] to pCode & "/" & tFolder & "/" & tLibrary
         end if
      end repeat
      set the itemDelimiter to comma
   end repeat
end mapCodeLibraries

-- An external of the IDE's, such as revdb (the database commands), which
-- the IDE's Home stack loads as it starts: empty, or why it did not load.
-- The engine loads a stack's externals as it reads the stack from its
-- file, and not when its externals property is set, so a stack that names
-- the external is saved to a file, removed and used again from the file.
-- revdb also needs its database drivers, which the IDE's database library
-- points it at (revSetDatabaseDriverPath) as it starts.
function loadExternal pName
   local tFolder, tFile, tStack, tStackFile
   if pName is among the lines of the cLoaded of me then
      return empty
   end if
   put $OXT_LESSONS_EXTERNALS into tFolder
   if tFolder is empty then
      return "OXT_LESSONS_EXTERNALS is not set, and the example needs the external" && pName
   end if
   switch the platform
      case "MacOS"
         put tFolder & "/" & pName & ".bundle" into tFile
         break
      case "Win32"
         put tFolder & "/" & pName & ".dll" into tFile
         break
      default
         put tFolder & "/" & pName & ".so" into tFile
   end switch
   if there is not a file tFile and there is not a folder tFile then
      return "no file" && tFile
   end if
   put "oxtLessonsExternal_" & pName into tStack
   put specialFolderPath("temporary") & "/" & tStack & ".oxtstack" into tStackFile
   create invisible stack tStack
   set the externals of stack tStack to tFile
   save stack tStack as tStackFile
   delete stack tStack
   start using stack tStackFile
   if there is a file tStackFile then
      delete file tStackFile
   end if
   if the externalCommands of stack tStack is empty and the externalFunctions of stack tStack is empty then
      return "the external did not load:" && tFile
   end if
   if pName is "revdb" then
      if there is a folder (tFolder & "/Database Drivers") then
         revSetDatabaseDriverPath tFolder & "/Database Drivers"
      else
         revSetDatabaseDriverPath tFolder
      end if
   end if
   set the cLoaded of me to the cLoaded of me & pName & return
   return empty
end loadExternal

-- Whether pCode compiles as an object's script: empty, or the engine's
-- answer (its line, and what it found)
function compileOnly pCode
   local tExplicit, tResult
   if there is not a stack "oxtLessonsCompile" then
      create invisible stack "oxtLessonsCompile"
   end if
   put the explicitVariables into tExplicit
   set the explicitVariables to false
   lock messages
   set the script of stack "oxtLessonsCompile" to pCode
   put the result into tResult
   unlock messages
   set the explicitVariables to tExplicit
   if tResult is empty then
      return empty
   end if
   return "line" && item 2 of line 1 of tResult & ":" && line (item 1 of line 1 of tResult) of the scriptParsingErrors
end compileOnly
