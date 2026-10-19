script "revHyperCardScriptLibrary"
-- OXT-Beyond: HyperTalk scripts that compile after File > Import Stack.
--
-- The engine imports a HyperCard stack's scripts as they were, and about
-- one script in ten does not compile here: HyperTalk let a variable be
-- called "group" or "name", let a handler be called "doMenu", and took
-- forms such as "the message box", "of cd" and unquoted notes after
-- "play" that this engine's parser refuses. A script that does not
-- compile loses every handler in it, where HyperCard only complained on
-- reaching the bad line. (A sweep of 2,186 stacks found 69% losing at
-- least one script, and 22% of all handlers lost with them.)
--
-- revHyperCardFixScripts goes over the scripts of a stack just imported
-- and, for each one that does not compile:
--
-- 1. rewrites the HyperTalk forms below, outside string literals and
--    comments, one token at a time (the rules are named T0 to T14 in the
--    log; T15 is the doMenu routing, below);
-- 2. if it still does not compile, compiles its handlers one at a time
--    and keeps those that compile, putting in place of each one that does
--    not a handler of the same name that passes its message on, with the
--    HyperTalk commented out inside it ("salvage": in effect what
--    HyperCard did, which ran a handler until it reached a bad line).
--
-- Scripts that compile are left alone, except that in a stack with an
-- "on doMenu" handler (renamed hcDoMenu, as no handler here can be called
-- doMenu) every "doMenu" command becomes "hcDoMenu", so that the stack's
-- handler sees the menu choices its own scripts make, as in HyperCard. A
-- script whose rewrite would not compile when it did before is left as it
-- was. Each object whose script changes keeps its HyperTalk in the custom
-- property uHyperCard["script"], and the stack's uHyperCard["scripts"]
-- lists every change.
--
-- The rewritten scripts call a few handlers HyperCard had and this engine
-- does not (hcDoMenu, hcVersion(), hcGoHome...): they are in the
-- substack "HyperCard Library" this adds to the stack, which is the
-- stack's behavior, so that it comes at the end of the stack's message
-- path where HyperCard's Home stack and HyperCard itself were, and goes
-- wherever the stack goes.

-- Names that this engine refuses as variable names (measured on 0.2.7-rc.4
-- over the names HyperCard stacks use), from the script sweep of
-- 2026-10-18. A name in the list is renamed only where a probe compile
-- confirms it is refused (_VariableRefused).
constant kRefused = "ac address angle arm arrow at avg backscripts bottom bottommargin btn button bytes cantmodify card cards cds clickloc clickv colors cr current currentcard currentpage date default documents done duration editmode enabled endtime eps exp exp1 exp2 field fields filename filetype filled first fld floor format from graphic group hand header height hilited hostname icon id in item items keyboardtype kind label labelwidth layer left leftmargin len length lf line lineinc lineindex lines ln loc location lower machine mainstack mark max maxheight maxwidth me menu menubar menuitem menuitems menuname mid min mode name nodes num number of offset params partnumber password pattern player players points processor rect result right rightmargin scale script scroll sec second seconds selectedline selectedlines selection size slash sound stack stacks stacksinuse starttime status style sum systemversion target tempname temporary text the this time title titlewidth to tool top topmargin upper userlevel value version vis visible wd width windowid xscale yscale"

-- Words that are part of HyperTalk's own grammar too: never renamed as
-- variables, and never quoted as an object's name
constant kStructural = "at btn button card cd field fld from in item line me of the this to first second id stack menu arrow hand target selection tool scroll password menuitem"

-- This engine's commands (engine/src/lextable.cpp): an external, or a
-- handler of the stack's own, called like one of these is not a call to
-- it here
constant kCommands = "accept add answer ask assert beep break breakpoint call cancel choose clear click clone close combine command compact constant convert copy create crop cut debugdo decrypt define dehilite delete difference disable dispatch divide do domenu drag drawer edit enable encrypt exit export filter find flip focus function get getprop global go grab group hide hilite if import include insert intersect kill launch library load local lock log macseticon mark modal modeless move multiply new next on open option palette pass paste place play pop popup post prepare print private pulldown push put quit read record redo relayer release remove rename repeat replace reply request require reset resolve return revert rotate save secure seek select send set setprop sheet show sort split start stop subtract switch symmetric throw toplevel try type undefine undo ungroup unhilite union unload unlock unmark visual wait write"

-- HyperTalk's own commands: an external of one of these names is never
-- what a call to it means
constant kHyperTalkCommands = "add answer arrowkey ask beep choose click close convert create debug delete dial disable divide domenu drag edit enable enterinfield enterkey export find flash functionkey get go help hide import lock mark multiply open palette picture play pop print push put read reply request reset returninfield returnkey save select send set show sort start stop subtract tabkey type unlock unmark visual wait write"

-- The words a visual effect is made of here (engine/src/lextable.cpp)
constant kVisualWords = "barn black blinds bottom card center checkerboard close curl dissolve door down effect fast flip from gray grey in inverse iris left normal open option out plain push reveal right scroll shrink slow slowly sound stretch to top up venetian very white wipe with zoom visual"

-- HyperTalk's object words
constant kObjectWords = "field fld button btn card cd background bkgnd bg stack window"

-- Functions HyperTalk let a script write without "the", as "length of x"
constant kOneArgFunctions = "length random abs atan chartonum cos exp exp1 exp2 ln ln1 log2 numtochar round sin sqrt tan trunc value"

constant kLibraryName = "HyperCard Library"

-- What the probes found: a name's verdict, so that each name is compiled
-- once (keys are the name in lower case)
local sVariableRefused
local sHandlerRefused

-- The object probes compile on, and the stack being fixed
local sProbe
local sStack

-- Each rule's count for the object being fixed, and for the whole stack
local sFired
local sFiredTotal

-- How many handlers the last _Salvage left out
local sLeftOut

-- The pieces of the last _Match
local sMatch

/*
Rewrites the HyperTalk scripts of a stack the engine has just imported
so that they compile here.

pStack (String): The long id or the name of a stack imported from
HyperCard.

Returns (String): A report: one line per object whose script changed (its
long name, a tab, and what was done to it), then a summary line. Empty
with an error in the result if pStack is not a stack.

Description:
Each script that does not compile is rewritten (HyperTalk forms this
engine refuses, outside strings and comments) and, if it still does not
compile, salvaged one handler at a time. A script that compiles is left
as it is, except for the doMenu routing described in the library's
header. Every object whose script changes keeps its HyperTalk in its
custom property uHyperCard["script"]; the stack's uHyperCard["scripts"]
holds the report, and the summary line is added to the hcImportStat.
The substack "HyperCard Library" is added as the stack's behavior.

Messages are locked while it runs, so that no handler of the stack runs.
*/
function revHyperCardFixScripts pStack
   local tObjects, tObject, tLines, tDefines, tExternals, tReport
   local tChanged, tSalvaged, tStubs, tStill, tWasLocked, tLine, tSummary

   if word 1 of pStack is "stack" and exists(pStack) then
      put the long id of pStack into sStack
   else if there is a stack pStack then
      put the long id of stack pStack into sStack
   else
      return "no such stack:" && pStack for error
   end if
   put the lockMessages into tWasLocked
   lock messages

   put _Objects(sStack) into tObjects
   -- First pass: the handlers the stack defines (for the renamed ones, a
   -- call anywhere in the stack is renamed too) and its externals
   repeat for each line tObject in tObjects
      repeat for each line tLine in the script of tObject
         if word 1 of tLine is among the items of "on,function" then
            put true into tDefines[_Lower(_Word2(tLine))]
         end if
      end repeat
   end repeat
   put _Externals(sStack) into tExternals

   _MakeProbe
   put empty into sFiredTotal
   put 0 into tChanged
   put 0 into tSalvaged
   put 0 into tStubs
   put 0 into tStill
   repeat for each line tObject in tObjects
      local tOriginal, tNew, tNote, tCompiled
      put the script of tObject into tOriginal
      if tOriginal is empty then next repeat
      put _Compiles(tOriginal) into tCompiled
      put empty into sFired
      put _Rewrite(tOriginal, tDefines, tExternals, tCompiled) into tNew
      put empty into tNote
      if tCompiled then
         -- only the doMenu routing touches a script that compiles, and
         -- never so that it no longer does
         if tNew is tOriginal or not _Compiles(tNew) then
            next repeat
         end if
      else if not _Compiles(tNew) then
         local tStubCount
         put _Salvage(tNew, tOriginal) into tNew
         put sLeftOut into tStubCount
         add 1 to tSalvaged
         add tStubCount to tStubs
         put "salvaged handler by handler," && tStubCount && "left out" into tNote
         if not _Compiles(tNew) then
            -- (should not happen: each piece compiled on its own)
            add 1 to tStill
            put "still does not compile" into tNote
         end if
      end if
      if tNew is tOriginal then
         add 1 to tStill
         put the long name of tObject & tab & "does not compile; nothing to rewrite" & return after tReport
         next repeat
      end if
      set the script of tObject to tNew
      set the uHyperCard["script"] of tObject to tOriginal
      add 1 to tChanged
      put the long name of tObject & tab & _FiredText(tNote) & return after tReport
   end repeat
   delete sProbe
   put empty into sProbe

   put _AddLibrary(sStack) into tLine
   if tLine is not empty then put tLine & return after tReport

   put "HyperCard scripts:" && tChanged && "rewritten," && tSalvaged && "salvaged by handler (" & tStubs && "handlers left out)," && tStill && "still do not compile" into tSummary
   put tSummary after tReport
   set the uHyperCard["scripts"] of sStack to tReport
   if the hcImportStat is empty then
      set the hcImportStat to tSummary
   else
      set the hcImportStat to the hcImportStat & return & tSummary
   end if

   set the lockMessages to tWasLocked
   return tReport
end revHyperCardFixScripts

/*
Rewrites one HyperTalk script so that it compiles here, without salvage
and without probing: the rules revHyperCardFixScripts applies, for a
script that is not in a stack.

pScript (String): The HyperTalk script, as the engine imported it.

pExternals (String): The names of the XCMDs and XFCNs the script may call,
one per line (optional).

Returns (String): The rewritten script.
*/
function revHyperCardRewriteScript pScript, pExternals
   local tExternals, tLine
   repeat for each line tLine in pExternals
      if tLine is not empty then put true into tExternals[_Lower(tLine)]
   end repeat
   put empty into sFired
   return _Rewrite(pScript, empty, tExternals, false)
end revHyperCardRewriteScript

/*
The script of the substack "HyperCard Library" that
<revHyperCardFixScripts> adds to an imported stack: the file
revhypercardlibrary.livecodescript beside this library, without its
first line.

Returns (String): The script.
*/
function revHyperCardLibraryScript
   local tPath, tScript
   set the itemDelimiter to slash
   put the effective filename of me into tPath
   put "revhypercardlibrary.livecodescript" into item -1 of tPath
   put textDecode(url ("binfile:" & tPath), "UTF-8") into tScript
   replace numToChar(13) & numToChar(10) with return in tScript
   -- the file is a script-only stack: its first line names it
   if word 1 of line 1 of tScript is "script" then delete line 1 of tScript
   return tScript
end revHyperCardLibraryScript

----------------------------------------------------------------------
-- The objects and the library

-- The long ids of every object of the stack that can have a script: the
-- stack, its cards, its backgrounds, and their controls, each once
private function _Objects pStack
   local tList, tSeen, tCard, tBg, tControl, tId
   put pStack & return into tList
   repeat with tCard = 1 to the number of cards of pStack
      put the long id of card tCard of pStack & return after tList
   end repeat
   repeat with tBg = 1 to the number of backgrounds of pStack
      put the long id of background tBg of pStack into tId
      put true into tSeen[the id of background tBg of pStack]
      put tId & return after tList
      repeat with tControl = 1 to the number of controls of background tBg of pStack
         put the id of control tControl of background tBg of pStack into tId
         if tSeen[tId] then next repeat
         put true into tSeen[tId]
         put the long id of control tControl of background tBg of pStack & return after tList
      end repeat
   end repeat
   repeat with tCard = 1 to the number of cards of pStack
      repeat with tControl = 1 to the number of controls of card tCard of pStack
         put the id of control tControl of card tCard of pStack into tId
         if tSeen[tId] then next repeat
         put true into tSeen[tId]
         put the long id of control tControl of card tCard of pStack & return after tList
      end repeat
   end repeat
   delete the last char of tList
   return tList
end _Objects

-- The externals a call may mean: those of the stack's resource fork (the
-- importer lists them in uHyperCard["externals"]), and the ones stacks
-- most often called from the Home stack or a shared library, whose
-- resource fork the import does not see
private function _Externals pStack
   local tList, tLine, tResult
   put the uHyperCard["externals"] of pStack into tList
   repeat for each line tLine in tList
      if item 2 of tLine is not empty then
         put true into tResult[_Lower(item -1 of tLine)]
      else
         put true into tResult[_Lower(word -1 of tLine)]
      end if
   end repeat
   repeat for each word tLine in "popup release version files move"
      put true into tResult[tLine]
   end repeat
   return tResult
end _Externals

-- Add the library as a substack of the stack and make it the stack's
-- behavior. Returns a line for the report, or empty if it was there.
private function _AddLibrary pStack
   local tName, tCount
   if the behavior of pStack is not empty then
      return "Not added: the HyperCard library (the stack already has a behavior)"
   end if
   -- A substack of the import may have the name already (a PLTE palette
   -- is one): this library is the one marked as it, under the first free
   -- name
   put kLibraryName into tName
   put 1 into tCount
   repeat while tName is among the lines of the substacks of pStack \
         and the uHyperCard["library"] of stack tName of pStack is not true
      add 1 to tCount
      put kLibraryName && tCount into tName
   end repeat
   if tName is not among the lines of the substacks of pStack then
      create invisible stack tName
      set the mainStack of it to the short name of pStack
      set the script of stack tName of pStack to revHyperCardLibraryScript()
      set the uHyperCard["library"] of stack tName of pStack to true
   end if
   set the behavior of pStack to the long id of stack tName of pStack
   return "Added: the substack" && quote & tName & quote && "as the stack's behavior"
end _AddLibrary

----------------------------------------------------------------------
-- Compiling

private command _MakeProbe
   local tName
   put "revHyperCardProbe" & the milliseconds into tName
   create invisible stack tName
   put the long id of stack tName into sProbe
end _MakeProbe

private function _Compiles pScript
   local tResult
   if sProbe is empty or there is not a stack sProbe then _MakeProbe
   set the script of sProbe to pScript
   put the result into tResult
   set the script of sProbe to empty
   return tResult is empty
end _Compiles

-- Whether this engine refuses pName as a variable (a parameter, a global
-- and the target of "put into"), for a name in kRefused
private function _VariableRefused pName
   put _Lower(pName) into pName
   if pName is among the words of kStructural then return false
   if pName is not among the words of kRefused then return false
   if sVariableRefused[pName] is empty then
      if sProbe is empty then
         -- (no probe outside revHyperCardFixScripts: trust the list)
         return true
      end if
      put not _Compiles("on hcProbe" && pName & return & "global" && pName & return & "put 1 into" && pName & return & "end hcProbe") into sVariableRefused[pName]
   end if
   return sVariableRefused[pName]
end _VariableRefused

-- Whether this engine refuses pName as a handler's name
private function _HandlerRefused pName
   put _Lower(pName) into pName
   if pName is "domenu" then return true
   if sHandlerRefused[pName] is empty then
      if sProbe is empty then
         put pName is among the words of kCommands or pName is among the words of "controlkey clickline cmdkey exists lineoffset me mouseline result round sum lower" into sHandlerRefused[pName]
      else
         put not _Compiles("on" && pName & return & "end" && pName) into sHandlerRefused[pName]
      end if
   end if
   return sHandlerRefused[pName]
end _HandlerRefused

----------------------------------------------------------------------
-- Tokens
--
-- A line is cut into tokens: word (letters, digits and _ starting with a
-- letter or _), number, string (a quote to the next, or to the end of the
-- line), comment (-- to the end of the line), space, and any other
-- character alone. Joined back, the tokens are the line. Rules change
-- the text of word tokens and read the kinds of the others, so strings
-- and comments are never touched.

private function _Tokens pLine
   local tTokens, tCount, i, tLength, tChar, tStart, tKind
   put 0 into tCount
   put the number of chars of pLine into tLength
   put 1 into i
   repeat while i <= tLength
      put char i of pLine into tChar
      put i into tStart
      if tChar is quote then
         put "s" into tKind
         add 1 to i
         repeat while i <= tLength and char i of pLine is not quote
            add 1 to i
         end repeat
         add 1 to i
      else if tChar is "-" and char i + 1 of pLine is "-" then
         put "c" into tKind
         put tLength + 1 into i
      else if tChar is space or tChar is tab then
         put "sp" into tKind
         repeat while i <= tLength and (char i of pLine is space or char i of pLine is tab)
            add 1 to i
         end repeat
      else if _IsWordStart(tChar) then
         put "w" into tKind
         repeat while i <= tLength and _IsWordChar(char i of pLine)
            add 1 to i
         end repeat
      else if tChar is a number then
         put "n" into tKind
         repeat while i <= tLength and (char i of pLine is a number or char i of pLine is ".")
            add 1 to i
         end repeat
      else
         put "p" into tKind
         add 1 to i
      end if
      add 1 to tCount
      put tKind into tTokens[tCount]["k"]
      put char tStart to i - 1 of pLine into tTokens[tCount]["t"]
   end repeat
   put tCount into tTokens["count"]
   return tTokens
end _Tokens

private function _IsWordStart pChar
   local tCode
   put charToNum(pChar) into tCode
   return pChar is "_" or tCode >= 128 or (tCode >= 65 and tCode <= 90) or (tCode >= 97 and tCode <= 122)
end _IsWordStart

private function _IsWordChar pChar
   return _IsWordStart(pChar) or pChar is among the chars of "0123456789"
end _IsWordChar

private function _Join pTokens
   local tLine, i
   repeat with i = 1 to pTokens["count"]
      put pTokens[i]["t"] after tLine
   end repeat
   return tLine
end _Join

-- The indices of the tokens that are code (not space, string or comment
-- are code; strings count, as they are values)
private function _Code pTokens
   local tList, i
   repeat with i = 1 to pTokens["count"]
      if pTokens[i]["k"] is not "sp" and pTokens[i]["k"] is not "c" then
         put i & comma after tList
      end if
   end repeat
   delete the last char of tList
   return tList
end _Code

-- The line with strings replaced by "" and the comment cut off
private function _CodeText pLine
   local tTokens, i, tText
   put _Tokens(pLine) into tTokens
   repeat with i = 1 to tTokens["count"]
      switch tTokens[i]["k"]
         case "c"
            break
         case "s"
            put quote & quote after tText
            break
         default
            put tTokens[i]["t"] after tText
      end switch
   end repeat
   return tText
end _CodeText

private function _Lower pText
   return toLower(pText)
end _Lower

-- The second word of a line, without what follows a comma
private function _Word2 pLine
   local tWord
   put word 2 of pLine into tWord
   if comma is in tWord then put item 1 of tWord into tWord
   return tWord
end _Word2

----------------------------------------------------------------------
-- The rewrite

-- pDefines: the handlers the stack defines (lower case, true); pExternals:
-- its externals; pCompiled: whether the script compiles as it is, in
-- which case only the doMenu routing applies
private function _Rewrite pScript, pDefines, pExternals, pCompiled
   local tLines, tCount, i, tCode, tSpans, tSpanCount, tInHandler, tName, tStart
   local tOut, tCovered, tKey, tRenameHandlers, tWord

   put 0 into tCount
   repeat for each line tCode in pScript
      add 1 to tCount
      put tCode into tLines[tCount]
   end repeat
   -- (a script ending in a return has an empty last line)
   if char -1 of pScript is return then
      add 1 to tCount
      put empty into tLines[tCount]
   end if

   -- The handlers: on or function NAME to end NAME
   put 0 into tSpanCount
   put empty into tInHandler
   repeat with i = 1 to tCount
      put _CodeText(tLines[i]) into tCode
      if tInHandler is empty then
         if word 1 of tCode is among the items of "on,function" and _Word2(tCode) is not empty then
            put _Lower(_Word2(tCode)) into tInHandler
            put i into tStart
         end if
      else if word 1 of tCode is "end" and _Lower(word 2 of tCode) is tInHandler then
         add 1 to tSpanCount
         put tStart into tSpans[tSpanCount]["start"]
         put i into tSpans[tSpanCount]["end"]
         put tInHandler into tSpans[tSpanCount]["name"]
         repeat with tKey = tStart to i
            put true into tCovered[tKey]
         end repeat
         put empty into tInHandler
      end if
   end repeat

   -- The handlers that are renamed: those defined anywhere in the stack
   -- (or in this script) whose names this engine refuses
   repeat with i = 1 to tSpanCount
      put true into pDefines[tSpans[i]["name"]]
   end repeat
   repeat for each key tWord in pDefines
      if _HandlerRefused(tWord) then put _NewHandlerName(tWord) into tRenameHandlers[tWord]
   end repeat

   if pCompiled then
      -- Only what changes what a script that compiles does, to what it did
      -- in HyperCard: the doMenu routing (in a stack with an "on doMenu"
      -- handler) and HyperCard's version
      repeat with i = 1 to tCount
         if tRenameHandlers["domenu"] is not empty then put _RouteDoMenu(tLines[i]) into tLines[i]
         put _VersionRule(tLines[i]) into tLines[i]
      end repeat
      return _JoinLines(tLines, tCount)
   end if

   -- T0: text outside handlers, which HyperCard ignored
   repeat with i = 1 to tCount
      if tCovered[i] then next repeat
      put _CodeText(tLines[i]) into tCode
      if word 1 of tCode is not empty then
         put "-- " & tLines[i] into tLines[i]
         _Fire "T0 text outside handlers"
      end if
   end repeat

   -- The rules inside each handler
   repeat with i = 1 to tSpanCount
      local tVars, tRename
      put _HandlerVariables(tLines, tSpans[i]["start"], tSpans[i]["end"]) into tVars
      put empty into tRename
      repeat for each key tWord in tVars
         if _VariableRefused(tWord) then put true into tRename[tWord]
      end repeat
      repeat with tKey = tSpans[i]["start"] to tSpans[i]["end"]
         put _RewriteLine(tLines[tKey], tVars, tRename, pExternals, tRenameHandlers) into tLines[tKey]
      end repeat
      _ContinuedCommands tLines, tSpans[i]["start"], tSpans[i]["end"]
   end repeat
   return _JoinLines(tLines, tCount)
end _Rewrite

-- The commands of _LineCommands on a statement continued over lines (a
-- \ at the end of a line, HyperCard's option-return): the statement is
-- put on its first line, and the lines it took after that are left empty,
-- so that the lines after it keep their numbers
private command _ContinuedCommands @pLines, pStart, pEnd
   local i, j, tMerged, tNew, tCode
   put pStart into i
   repeat while i < pEnd
      put word 1 to -1 of _CodeText(pLines[i]) into tCode
      if char -1 of tCode is not "\" then
         add 1 to i
         next repeat
      end if
      put pLines[i] into tMerged
      put i into j
      repeat while j < pEnd and char -1 of word 1 to -1 of _CodeText(pLines[j]) is "\"
         put _WithoutContinuation(tMerged) into tMerged
         add 1 to j
         put space & word 1 to -1 of pLines[j] after tMerged
      end repeat
      put _LineCommands(tMerged) into tNew
      if tNew is not tMerged then
         put tNew into pLines[i]
         repeat with i = i + 1 to j
            put empty into pLines[i]
         end repeat
      end if
      put j + 1 into i
   end repeat
end _ContinuedCommands

-- A line without the \ that continues it (the last one, outside strings
-- and comments)
private function _WithoutContinuation pLine
   local tTokens, i
   put _Tokens(pLine) into tTokens
   repeat with i = tTokens["count"] down to 1
      if tTokens[i]["k"] is among the words of "sp c" then
         put empty into tTokens[i]["t"]
         next repeat
      end if
      if tTokens[i]["t"] is "\" then put empty into tTokens[i]["t"]
      exit repeat
   end repeat
   return _Join(tTokens)
end _WithoutContinuation

private function _JoinLines pLines, pCount
   local tOut, i
   repeat with i = 1 to pCount
      put pLines[i] after tOut
      if i < pCount then put return after tOut
   end repeat
   return tOut
end _JoinLines

private function _NewHandlerName pName
   if pName is "domenu" then return "hcDoMenu"
   return "hc_" & pName
end _NewHandlerName

private command _Fire pRule
   add 1 to sFired[pRule]
   add 1 to sFiredTotal[pRule]
end _Fire

private function _FiredText pNote
   local tText, tRule
   repeat for each line tRule in _SortedKeys(sFired)
      put tRule && "x" & sFired[tRule] & "; " after tText
   end repeat
   if pNote is not empty then put pNote & "; " after tText
   if tText is empty then return "rewritten"
   delete char -2 to -1 of tText
   return tText
end _FiredText

private function _SortedKeys pArray
   local tKeys
   put the keys of pArray into tKeys
   sort lines of tKeys
   return tKeys
end _SortedKeys

-- doMenu as a command becomes hcDoMenu (rule T15)
private function _RouteDoMenu pLine
   local tTokens, tCode, tIndex, tPrev
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   repeat for each item tIndex in tCode
      if tTokens[tIndex]["k"] is "w" and _Lower(tTokens[tIndex]["t"]) is "domenu" then
         if _StatementStart(tTokens, tCode, tIndex) then
            put "hcDoMenu" into tTokens[tIndex]["t"]
            _Fire "T15 doMenu sent to the stack's handler"
         end if
      end if
   end repeat
   return _Join(tTokens)
end _RouteDoMenu

-- Whether the token at pIndex starts a statement: the first on its line,
-- or after then or else
private function _StatementStart pTokens, pCode, pIndex
   local tPrev
   put _PrevCode(pCode, pIndex) into tPrev
   if tPrev is empty then return true
   return _Lower(pTokens[tPrev]["t"]) is among the words of "then else"
end _StatementStart

private function _PrevCode pCode, pIndex
   local tItem, tPrev
   repeat for each item tItem in pCode
      if tItem = pIndex then return tPrev
      put tItem into tPrev
   end repeat
   return empty
end _PrevCode

private function _NextCode pCode, pIndex
   local tItem, tFound
   repeat for each item tItem in pCode
      if tFound then return tItem
      if tItem = pIndex then put true into tFound
   end repeat
   return empty
end _NextCode

-- A token's text in lower case, or empty for no token
private function _T pTokens, pIndex
   if pIndex is empty then return empty
   return _Lower(pTokens[pIndex]["t"])
end _T

-- The variables of a handler: its parameters, its globals, the targets
-- of "put ... into" and "repeat with"
private function _HandlerVariables pLines, pStart, pEnd
   local tVars, i, tCode, tWord, tTokens, tIndices, tIndex, tNext, tAfter
   put _CodeText(pLines[pStart]) into tCode
   repeat for each item tWord in word 3 to -1 of tCode
      put word 1 of tWord into tWord
      if tWord is not empty and _IsWordStart(char 1 of tWord) then put true into tVars[_Lower(tWord)]
   end repeat
   -- a parameter right after the name, with no comma ("on mouseUp x")
   if comma is in word 2 of tCode then
      put word 2 of tCode into tWord
      put item 2 of tWord into tWord
      if tWord is not empty then put true into tVars[_Lower(tWord)]
   end if
   repeat with i = pStart to pEnd
      put _CodeText(pLines[i]) into tCode
      if word 1 of tCode is "global" then
         replace comma with space in tCode
         repeat for each word tWord in word 2 to -1 of tCode
            if tWord is not "\" then put true into tVars[_Lower(tWord)]
         end repeat
         next repeat
      end if
      put _Tokens(tCode) into tTokens
      put _Code(tTokens) into tIndices
      repeat for each item tIndex in tIndices
         if _T(tTokens, tIndex) is "into" or (_T(tTokens, tIndex) is "with" and _T(tTokens, _PrevCode(tIndices, tIndex)) is "repeat") then
            put _NextCode(tIndices, tIndex) into tNext
            if tNext is empty or tTokens[tNext]["k"] is not "w" then next repeat
            put _NextCode(tIndices, tNext) into tAfter
            -- "into field x", "into line 2 of x": not a variable
            if _T(tTokens, tNext) is among the words of kObjectWords then next repeat
            if _T(tTokens, tAfter) is "of" then next repeat
            if tAfter is not empty and tTokens[tAfter]["k"] is "n" then next repeat
            if tAfter is not empty and _T(tTokens, tAfter) is among the words of kObjectWords then next repeat
            put true into tVars[_T(tTokens, tNext)]
         end if
      end repeat
   end repeat
   return tVars
end _HandlerVariables

-- The rules that work on one line of a handler
private function _RewriteLine pLine, pVars, pRename, pExternals, pRenameHandlers
   local tTokens, tCode, tIndex, tPrev, tNext, tWord, tNew, tFirst, tAfter, tChanged
   local tLine

   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put item 1 of tCode into tFirst

   repeat for each item tIndex in tCode
      if tTokens[tIndex]["k"] is not "w" then next repeat
      put _T(tTokens, tIndex) into tWord
      put _PrevCode(tCode, tIndex) into tPrev
      put _NextCode(tCode, tIndex) into tNext

      -- T1: a handler whose name is refused, its end, its pass and exit,
      -- and calls to it
      if pRenameHandlers[tWord] is not empty then
         if _T(tTokens, tPrev) is among the words of "on function end pass exit" \
               and (tPrev = tFirst or _T(tTokens, tPrev) is among the words of "pass exit") then
            put pRenameHandlers[tWord] into tTokens[tIndex]["t"]
            _Fire "T1 handler named like a keyword"
            next repeat
         end if
         if tWord is "domenu" or tWord is not among the words of kCommands then
            if _StatementStart(tTokens, tCode, tIndex) or (_T(tTokens, tNext) is "(" and _T(tTokens, tPrev) is not "the") then
               put pRenameHandlers[tWord] into tTokens[tIndex]["t"]
               _Fire "T1 handler named like a keyword"
               next repeat
            end if
         end if
      end if

      -- T13: an external named like a keyword
      if pExternals[tWord] and tWord is not among the words of kHyperTalkCommands \
            and tWord is not among the words of "set put get go if send do add show hide" \
            and (tWord is among the words of kCommands or tWord is among the words of kRefused or _HandlerRefused(tWord)) then
         if _StatementStart(tTokens, tCode, tIndex) or (_T(tTokens, tNext) is "(" and _T(tTokens, tPrev) is not "the") then
            put "hcX_" & tTokens[tIndex]["t"] into tTokens[tIndex]["t"]
            _Fire "T13 external named like a keyword"
            next repeat
         end if
      end if

      -- T2: a variable whose name is refused
      if pRename[tWord] then
         if _T(tTokens, tPrev) is not among the words of "the set" \
               and not (_T(tTokens, tNext) is "of" and _T(tTokens, tPrev) is not among the words of "char character word item line to into") then
            put "hc_" & tTokens[tIndex]["t"] into tTokens[tIndex]["t"]
            _Fire "T2 variable named like a keyword"
            next repeat
         end if
      end if

      -- T3: an object's name, unquoted, that is a keyword: field result
      if tPrev is not empty and _T(tTokens, tPrev) is among the words of kObjectWords \
            and tWord is among the words of kRefused and not pVars[tWord] \
            and tWord is not among the words of kStructural and tWord is not "id" \
            and tWord is not among the words of "cards cds fields buttons stacks items lines" \
            and _T(tTokens, tNext) is not "of" and _T(tTokens, tNext) is not "(" then
         put quote & tTokens[tIndex]["t"] & quote into tTokens[tIndex]["t"]
         put "s" into tTokens[tIndex]["k"]
         _Fire "T3 object name that is a keyword quoted"
         next repeat
      end if
   end repeat
   put _Join(tTokens) into pLine

   put _PhraseRules(pLine) into pLine
   put _LineCommands(pLine) into tLine
   if tLine is not pLine then return tLine
   put _PlayNotes(pLine) into pLine
   return _Visual(pLine)
end _RewriteLine

-- T4, T6, T7, T9, T10, T11: phrases, matched on tokens
private function _PhraseRules pLine
   local tTokens, tCode, tCount, i, tIdx, tWords, tItem, n, tWord, tNext, tNext2, tPrev
   local tFirstWord

   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   -- the code tokens in order, by position
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   put _T(tTokens, tIdx[1]) into tFirstWord

   repeat with i = 1 to n
      put _T(tTokens, tIdx[i]) into tWord
      if tWord is empty then next repeat
      put _T(tTokens, tIdx[i + 1]) into tNext
      put _T(tTokens, tIdx[i + 2]) into tNext2
      put _T(tTokens, tIdx[i - 1]) into tPrev

      -- T4: the message box, the msg, the message window
      if tWord is among the words of "message msg" and tNext is among the words of "box window" then
         if tPrev is "the" then put empty into tTokens[tIdx[i - 1]]["t"]
         put "msg" into tTokens[tIdx[i]]["t"]
         put empty into tTokens[tIdx[i + 1]]["t"]
         _ClearSpaceAfter tTokens, tIdx[i]
         if tPrev is "the" then _ClearSpaceAfter tTokens, tIdx[i - 1]
         _Fire "T4 the message box"
         next repeat
      end if
      if tWord is among the words of "message msg" and tPrev is "the" and tNext is not "of" then
         put empty into tTokens[tIdx[i - 1]]["t"]
         _ClearSpaceAfter tTokens, tIdx[i - 1]
         put "msg" into tTokens[tIdx[i]]["t"]
         _Fire "T4 the message box"
         next repeat
      end if

      -- T7: functions HyperTalk let a script write without "the"
      if tWord is among the words of kOneArgFunctions and tNext is "of" and tPrev is not "the" and tTokens[tIdx[i]]["k"] is "w" then
         put "the " before tTokens[tIdx[i]]["t"]
         _Fire "T7 function without the"
         next repeat
      end if
      if tWord is "selection" and tPrev is not "the" then
         put "the " before tTokens[tIdx[i]]["t"]
         _Fire "T7 function without the"
         next repeat
      end if

      -- T6: visual ... to cd
      if tFirstWord is "visual" and tWord is "cd" and tPrev is "to" then
         put "card" into tTokens[tIdx[i]]["t"]
         _Fire "T6 visual to cd"
         next repeat
      end if

      -- T10: HyperCard's version, the long version, scripting languages,
      -- the suspended
      if tWord is "version" and tPrev is "the" and tNext is "of" and tNext2 is "hypercard" then
         _Replace tTokens, tIdx, i - 1, i + 2, "hcVersion()"
         _Fire "T10 HyperCard's version"
         next repeat
      end if
      if tWord is "version" and tNext is "of" and tNext2 is "scriptinglanguage" then
         if tPrev is "the" then
            _Replace tTokens, tIdx, i - 1, i + 3, "hcVersion()"
         else
            _Replace tTokens, tIdx, i, i + 3, "hcVersion()"
         end if
         _Fire "T10 HyperCard's version"
         next repeat
      end if
      if tWord is "there" and tNext is "is" and tNext2 is "a" and _T(tTokens, tIdx[i + 3]) is "scriptinglanguage" then
         _Replace tTokens, tIdx, i, i + 4, "false"
         _Fire "T10 HyperCard's version"
         next repeat
      end if
      if tWord is "suspended" and tPrev is "the" then
         _Replace tTokens, tIdx, i - 1, i, "hcSuspended()"
         _Fire "T10 HyperCard's version"
         next repeat
      end if

      -- T11: an object named by its type alone: "of cd", "of bkgnd"
      if tWord is among the words of "bkgnd bg background cd card" and (tPrev is "of" or (tPrev is "to" and tFirstWord is "send")) \
            and (tNext is empty or tNext is among the words of ") , into to then else and or with is = <>") then
         put "this " before tTokens[tIdx[i]]["t"]
         _Fire "T11 HyperCard object words"
         next repeat
      end if
      -- the card window
      if tWord is among the words of "card cd" and tNext is "window" then
         if tPrev is "the" then
            _Replace tTokens, tIdx, i - 1, i + 1, "this stack"
         else
            _Replace tTokens, tIdx, i, i + 1, "this stack"
         end if
         _Fire "T11 HyperCard object words"
         next repeat
      end if
      -- cd prev
      if tWord is among the words of "card cd" and tNext is among the words of "prev previous next" then
         put tTokens[tIdx[i]]["t"] into tWord
         put tTokens[tIdx[i + 1]]["t"] into tTokens[tIdx[i]]["t"]
         put tWord into tTokens[tIdx[i + 1]]["t"]
         _Fire "T11 HyperCard object words"
         next repeat
      end if
      -- the marked of a card
      if tWord is "marked" and tNext is "of" then
         if tPrev is "the" then
            put "mark" into tTokens[tIdx[i]]["t"]
         else
            put "the mark" into tTokens[tIdx[i]]["t"]
         end if
         _Fire "T11 HyperCard object words"
         next repeat
      end if

      -- exit to HyperCard
      if tWord is "hypercard" and tPrev is "to" and _T(tTokens, tIdx[i - 2]) is "exit" then
         put "top" into tTokens[tIdx[i]]["t"]
         _Fire "T11 HyperCard object words"
         next repeat
      end if
      -- card 3 in this bg, the last card in this background
      if tWord is "in" and tPrev is among the words of "card cd cards cds" and tNext is "this" then
         put "of" into tTokens[tIdx[i]]["t"]
         _Fire "T11 HyperCard object words"
         next repeat
      end if

      -- T9: go to stack home
      if tWord is "go" and _GoHome(tTokens, tIdx, i, n) then
         _Fire "T9 go home"
         exit repeat
      end if
   end repeat

   put _VersionRule(_Join(tTokens)) into pLine
   -- a reset alone
   if word 1 to -1 of _CodeText(pLine) is "reset" then
      put "reset paint" into word 1 of pLine
      _Fire "T11 HyperCard object words"
   end if
   return pLine
end _PhraseRules

-- T10: the version and the long version, which in HyperCard are
-- HyperCard's, not this engine's (scripts test "the version < 2")
private function _VersionRule pLine
   local tTokens, tCode, tIdx, n, tItem, i, tWord
   if "version" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 2 to n
      if _T(tTokens, tIdx[i]) is not "version" or _T(tTokens, tIdx[i + 1]) is "of" then next repeat
      if _T(tTokens, tIdx[i - 1]) is "long" and _T(tTokens, tIdx[i - 2]) is "the" then
         _Replace tTokens, tIdx, i - 2, i, "hcLongVersion()"
         _Fire "T10 HyperCard's version"
      else if _T(tTokens, tIdx[i - 1]) is "the" then
         _Replace tTokens, tIdx, i - 1, i, "hcVersion()"
         _Fire "T10 HyperCard's version"
      end if
   end repeat
   return _Join(tTokens)
end _VersionRule

-- Replace the code tokens pFrom to pTo with pText
private command _Replace @pTokens, pIdx, pFrom, pTo, pText
   local i, k
   repeat with k = pIdx[pFrom] to pIdx[pTo]
      put empty into pTokens[k]["t"]
   end repeat
   put pText into pTokens[pIdx[pFrom]]["t"]
end _Replace

private command _ClearSpaceAfter @pTokens, pIndex
   if pTokens[pIndex + 1]["k"] is "sp" then put empty into pTokens[pIndex + 1]["t"]
end _ClearSpaceAfter

-- go [to] stack home, go [to] home: hcGoHome
private function _GoHome @pTokens, pIdx, pAt, pCount
   local j
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "to" then add 1 to j
   if _T(pTokens, pIdx[j]) is "stack" then add 1 to j
   if _T(pTokens, pIdx[j]) is not "home" or j <> pCount then return false
   _Replace pTokens, pIdx, pAt, j, "hcGoHome"
   return true
end _GoHome

-- T5: notes after play, unquoted
private function _PlayNotes pLine
   local tHead, tNotes, tComment
   if matchText(pLine, "(?i)^(\s*play\s+(?:" & quote & "[^" & quote & "]*" & quote & "|\w+)(?:\s+(?:tempo\s+\d+|faster|slower|fast|slow))*\s+)([a-gr][#b]?\d?[whqestx3.]*(?:\s+[a-gr][#b]?\d?[whqestx3.]*)*)\s*(--.*)?$", tHead, tNotes, tComment) then
      if quote is not in tNotes then
         _Fire "T5 unquoted notes"
         if tComment is not empty then put space before tComment
         return tHead & quote & tNotes & quote & tComment
      end if
   end if
   return pLine
end _PlayNotes

-- T12 and T8: HyperCard commands this engine does not have, to the
-- library's handlers; and "group" in a text style, which is not a style
-- here
private function _LineCommands pLine
   local tIndent, tRest, a, b, c, d
   -- Each pattern is matched with the inside of strings and comments
   -- blanked, so that only the code outside them can match; the pieces
   -- are then cut from the line itself (_Match)
   if _Match(pLine, "(?i)^(\s*)reset\s+menubar\s*(--.*)?$") then
      put sMatch[1] into tIndent
      put sMatch[2] into tRest
      _Fire "T8 reset menubar"
      return tIndent & "hcResetMenubar" & _Spaced(tRest)
   end if
   if _Match(pLine, "(?i)^(\s*)(create|delete)\s+menu\s+(.+)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into a
      put sMatch[3] into tRest
      if _Lower(word 1 of tRest) is not among the words of "item items" then
         _Fire "T12 HyperCard command to the library"
         if _Lower(a) is "create" then return tIndent & "hcCreateMenu" && tRest
         return tIndent & "hcDeleteMenu" && tRest
      end if
   end if
   if _Match(pLine, "(?i)^(\s*)open\s+report\s+printing\b(.*)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into tRest
      _Fire "T12 HyperCard command to the library"
      return tIndent & "hcOpenReportPrinting" && _Quoted(tRest)
   end if
   if _Match(pLine, "(?i)^(\s*)dial\s+(.*?)\s+with\s+modem\b(.*)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into a
      put sMatch[3] into tRest
      _Fire "T12 HyperCard command to the library"
      return tIndent & "hcDial" && a & comma && _Quoted(tRest)
   end if
   if _Match(pLine, "(?i)^(\s*)put\s+(.+?)\s+(into|after|before)\s+menu\s+(.+?)\s+with\s+menu(?:msgs?|messages?)\s+(.+)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into a
      put sMatch[3] into b
      put sMatch[4] into c
      put sMatch[5] into d
      _Fire "T12 HyperCard command to the library"
      return tIndent & "hcPutIntoMenu" && a & comma && quote & b & quote & comma && c & comma && d
   end if
   if _Match(pLine, "(?i)^(\s*(?:(?:then|else)\s+)?)palette\s+(.+?,.+)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into a
      _Fire "T12 HyperCard command to the library"
      return tIndent & "hcPalette" && a
   end if
   if _Match(pLine, "(?i)^(\s*set\s+(?:the\s+)?textstyle\b.*\bto\b.*?),\s*group\b(.*)$") then
      put sMatch[1] into a
      put sMatch[2] into b
      _Fire "T12 HyperCard command to the library"
      return a & b
   end if
   return pLine
end _LineCommands

-- matchText on pLine, with the inside of its strings and comments blanked
-- for the match (the same length, so the pieces line up); the pieces are
-- cut from pLine into sMatch[1] to sMatch[5]
private function _Match pLine, pPattern
   local tMasked, s1, e1, s2, e2, s3, e3, s4, e4, s5, e5
   put empty into sMatch
   put _Masked(pLine) into tMasked
   if not matchChunk(tMasked, pPattern, s1, e1, s2, e2, s3, e3, s4, e4, s5, e5) then
      return false
   end if
   put _Piece(pLine, s1, e1) into sMatch[1]
   put _Piece(pLine, s2, e2) into sMatch[2]
   put _Piece(pLine, s3, e3) into sMatch[3]
   put _Piece(pLine, s4, e4) into sMatch[4]
   put _Piece(pLine, s5, e5) into sMatch[5]
   return true
end _Match

private function _Piece pLine, pStart, pEnd
   if pStart is not an integer or pEnd is not an integer or pEnd < pStart then return empty
   return char pStart to pEnd of pLine
end _Piece

-- pLine with every char inside a string, and every char of a comment after
-- its "--", made an x
private function _Masked pLine
   local tOut, tChar, tInString, i
   put false into tInString
   repeat with i = 1 to the number of chars of pLine
      put char i of pLine into tChar
      if tInString then
         if tChar is quote then
            put false into tInString
         else
            put "x" into tChar
         end if
      else if tChar is quote then
         put true into tInString
      else if tChar is "-" and char i + 1 of pLine is "-" then
         put "--" & _Xs(the number of chars of pLine - i - 1) after tOut
         return tOut
      end if
      put tChar after tOut
   end repeat
   return tOut
end _Masked

private function _Xs pCount
   local tOut
   repeat pCount times
      put "x" after tOut
   end repeat
   return tOut
end _Xs

private function _Spaced pText
   if pText is empty then return empty
   return space & pText
end _Spaced

private function _Quoted pText
   put word 1 to -1 of pText into pText
   if pText is empty then return "empty"
   replace quote with "'" in pText
   return quote & pText & quote
end _Quoted

-- T14: a visual effect with a variable where this engine expects one of
-- its words (HyperCard evaluated it): the statement is run with do, the
-- variables' values put in
private function _Visual pLine
   local tTokens, tCode, tItem, tWord, tUnknown, tOut, tIndent, tLiteral
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   if _T(tTokens, item 1 of tCode) is not "visual" then return pLine
   repeat for each item tItem in tCode
      if tTokens[tItem]["k"] is "w" and _T(tTokens, tItem) is not among the words of kVisualWords then
         put true into tUnknown
      else if tTokens[tItem]["k"] is not "w" then
         -- a string or anything else: leave it to the parser
         return pLine
      end if
   end repeat
   if not tUnknown then return pLine
   if tTokens[1]["k"] is "sp" then put tTokens[1]["t"] into tIndent
   put empty into tLiteral
   repeat for each item tItem in tCode
      if _T(tTokens, tItem) is among the words of kVisualWords then
         put tTokens[tItem]["t"] & space after tLiteral
      else
         if tLiteral is not empty then
            put quote & word 1 to -1 of tLiteral & quote && "&& " after tOut
         end if
         put tTokens[tItem]["t"] && "&& " after tOut
         put empty into tLiteral
      end if
   end repeat
   if tLiteral is not empty then
      put quote & word 1 to -1 of tLiteral & quote after tOut
   else
      delete char -4 to -1 of tOut
   end if
   _Fire "T14 visual effect from a variable"
   if tTokens[tTokens["count"]]["k"] is "c" then put space & tTokens[tTokens["count"]]["t"] after tOut
   return tIndent & "do" && tOut
end _Visual

----------------------------------------------------------------------
-- Salvage

-- Keep the handlers of pScript that compile on their own; put in place of
-- each one that does not a handler that passes its message, holding the
-- HyperTalk of pOriginal's handler of the same name commented out. A
-- second handler of a name already defined is commented out (HyperCard
-- ran the first). Returns the script; sLeftOut is the number of handlers
-- left out.
private function _Salvage pScript, pOriginal
   local tPieces, tCount, i, tOut, tName, tKind, tSeen, tLeftOut, tOriginalHandlers, tStub
   put _Handlers(pScript) into tPieces
   put _Handlers(pOriginal) into tOriginalHandlers
   put 0 into tLeftOut
   repeat with i = 1 to tPieces["count"]
      if tPieces[i]["name"] is empty then
         -- lines between handlers, commented out already by T0
         put tPieces[i]["text"] & return after tOut
         next repeat
      end if
      put tPieces[i]["name"] into tName
      put tPieces[i]["kind"] into tKind
      if tSeen[_Lower(tName)] then
         put _Commented(tPieces[i]["text"], "a second handler called" && tName & "; HyperCard ran the first") & return after tOut
         add 1 to tLeftOut
         next repeat
      end if
      put true into tSeen[_Lower(tName)]
      if _Compiles(tPieces[i]["text"]) then
         put tPieces[i]["text"] & return after tOut
         next repeat
      end if
      add 1 to tLeftOut
      put _Stub(tKind, tName, _OriginalHandler(tOriginalHandlers, tName, tPieces[i]["text"])) into tStub
      if not _Compiles(tStub) then
         -- a name no handler can have here ("v" in quotes, time&Date):
         -- nothing can call it, so it is commented out whole
         put _Commented(_OriginalHandler(tOriginalHandlers, tName, tPieces[i]["text"]), "a handler whose name cannot be a handler's here") into tStub
      end if
      put tStub & return after tOut
   end repeat
   delete the last char of tOut
   put tLeftOut into sLeftOut
   return tOut
end _Salvage

-- The text of the original handler called pName, or pDefault
private function _OriginalHandler pHandlers, pName, pDefault
   local i
   repeat with i = 1 to pHandlers["count"]
      if _Lower(pHandlers[i]["name"]) is _Lower(pName) then return pHandlers[i]["text"]
   end repeat
   return pDefault
end _OriginalHandler

-- The handlers of a script and the text between them, in order: each with
-- its kind (on or function), name and text; the text between has no name
private function _Handlers pScript
   local tPieces, tCount, tLine, tCode, tIn, tName, tKind, tBuffer
   put 0 into tCount
   repeat for each line tLine in pScript
      put _CodeText(tLine) into tCode
      if tIn is empty then
         if word 1 of tCode is among the items of "on,function" and _Word2(tCode) is not empty then
            if tBuffer is not empty then
               add 1 to tCount
               delete the last char of tBuffer
               put tBuffer into tPieces[tCount]["text"]
               put empty into tBuffer
            end if
            put _Lower(_Word2(tCode)) into tIn
            put _Word2(tCode) into tName
            put _Lower(word 1 of tCode) into tKind
         end if
         put tLine & return after tBuffer
      else
         put tLine & return after tBuffer
         if word 1 of tCode is "end" and _Lower(word 2 of tCode) is tIn then
            add 1 to tCount
            delete the last char of tBuffer
            put tBuffer into tPieces[tCount]["text"]
            put tName into tPieces[tCount]["name"]
            put tKind into tPieces[tCount]["kind"]
            put empty into tBuffer
            put empty into tIn
         end if
      end if
   end repeat
   if tBuffer is not empty then
      -- an unclosed handler, or text after the last one: commented out
      delete the last char of tBuffer
      add 1 to tCount
      if tIn is not empty then
         put _Commented(tBuffer, "a handler with no end" && tIn) into tPieces[tCount]["text"]
      else
         put tBuffer into tPieces[tCount]["text"]
      end if
   end if
   put tCount into tPieces["count"]
   return tPieces
end _Handlers

private function _Commented pText, pWhy
   local tOut, tLine
   put "-- HyperCard import: left out," && pWhy & return into tOut
   repeat for each line tLine in pText
      put "-- " & tLine & return after tOut
   end repeat
   delete the last char of tOut
   return tOut
end _Commented

-- A handler in place of one that did not compile: a message goes on as if
-- the handler were not there; a function returns empty. The HyperTalk is
-- inside it, commented out, to fix by hand.
private function _Stub pKind, pName, pHyperTalk
   local tOut, tLine
   put pKind && pName & return into tOut
   put "   -- HyperCard import: this handler did not compile here, and is" & return after tOut
   put "   -- left out. Its HyperTalk, to fix by hand:" & return after tOut
   repeat for each line tLine in pHyperTalk
      put "   -- " & tLine & return after tOut
   end repeat
   if pKind is "on" then
      put "   pass" && pName & return after tOut
   else
      put "   return empty" & return after tOut
   end if
   put "end" && pName after tOut
   return tOut
end _Stub
