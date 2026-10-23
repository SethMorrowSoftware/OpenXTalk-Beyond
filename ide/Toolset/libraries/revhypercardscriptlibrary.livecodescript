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
--    comments, one token at a time (the rules are named T0 to T14 and
--    T31 in the log; T15 to T30 and T32 are below);
-- 2. if it still does not compile, compiles its handlers one at a time
--    and keeps those that compile, putting in place of each one that does
--    not a handler of the same name that passes its message on, with the
--    HyperTalk commented out inside it ("salvage": in effect what
--    HyperCard did, which ran a handler until it reached a bad line).
--
-- Scripts that compile are rewritten only where they do something else
-- here than in HyperCard. In a stack with an "on doMenu" handler (renamed
-- hcDoMenu, as no handler here can be called doMenu) every "doMenu"
-- command becomes "hcDoMenu", so that the stack's handler sees the menu
-- choices its own scripts make (T15). And in every script, the statements
-- that stop with an error here where HyperCard went on, or do something
-- else, go to the library (T9 "go home", T16 "go" to a stack, T17 the
-- cursor, T18 tabKey and the other key commands and "picture", T19 "show
-- card picture", T20 "fileName(", T21 "show", "hide" and "close window",
-- T22 HyperCard 2.2's menus, T23 "start using" and "stop using" a stack,
-- T24 "print" a field, T25 "go" to a destination given by an expression,
-- T26 the properties of picture and palette windows, T27 "doMenu" with
-- the item's name not in quotes, T28 the properties of the message box,
-- T29 HyperCard the application: its name and version, send to it, T30
-- "choose tool" by HyperCard's number or by a name in a variable, T32 the
-- card's rect and HyperCard's text styles). T33, in scripts that do not
-- compile, takes more forms HyperCard took: an answer's replies not in
-- quotes, "convert" of an expression, functions written without "the",
-- "go to card 1 of home", and names of several words not in quotes
-- after a cursor, a window or a "go".
-- A script whose rewrite would not compile when it did before is left as
-- it was. Each object whose script changes keeps its HyperTalk in the
-- custom property uHyperCard["script"], and the stack's
-- uHyperCard["scripts"] lists every change.
--
-- The rewritten scripts call a few handlers HyperCard had and this engine
-- does not (hcDoMenu, hcVersion(), hcGoHome...): they are in the
-- substack "HyperCard Library (<the stack's name>)" this adds to the
-- stack, which is the stack's behavior, so that it comes at the end of
-- the stack's message path where HyperCard's Home stack and HyperCard
-- itself were, and goes wherever the stack goes.

-- Names that this engine refuses as variable names (measured on 0.2.7-rc.4
-- over the names HyperCard stacks use), from the script sweeps of
-- 2026-10-18 and 2026-10-22. A name in the list is renamed only where a probe compile
-- confirms it is refused (_VariableRefused).
constant kRefused = "ac address angle arm arrow at avg backscripts bottom bottommargin brush btn button bytes cantmodify card cardnames cards cds checkmark clickline clickloc clickv colors cr current currentcard currentpage currentwindow date dateformat default disabled documents done duration editmode elements enabled endtime eps exp exp1 exp2 externals field fields filename filetype filled first fld floor format from graphic group hand header height hilited hostname icon id in ink item items keyboardtype kind label labelwidth layer left leftmargin len length lf line lineinc lineindex lines linesize ln loc location lower machine mainstack mark max maxheight maxwidth me menu menubar menuitem menuitems menuname mid min mode name nodes num number of offset orientation params partnumber password pattern player players points processor project rect result right rightmargin scale script scroll sec second seconds selected selectedfield selectedline selectedlines selection size slash sound stack stacks stacksinuse starttime status style sum systemversion target tempname temporary text textarrows the theme this time title titlewidth to tool top topmargin upper userlevel value version vis visible volumes watch wd width windowid windows xscale yscale"

-- Words that are part of HyperTalk's own grammar too: never renamed as
-- variables, and never quoted as an object's name
constant kStructural = "at btn button card cd field fld from in item line me of the this to first second id stack menu arrow hand target selection tool scroll password menuitem"

-- Words of HyperTalk's grammar that HyperCard let a script use as a
-- variable too ("put x into this", "on doMenu menuItem, menu") and this
-- engine does not: renamed only where the word is a variable of the
-- handler and stands where a variable stands, not where it is a word of
-- the grammar ("this card", "item 2 of", "the target"); from the sweep of
-- 2026-10-22
constant kRenamedWhereVariable = "this item menu menuitem button btn field fld card cd stack line word by first second third last next prev previous middle any help arrow hand selection window bg bkgnd background id target password part"

-- The words that can follow a variable, or an object's unquoted name, in
-- an expression: the end of the statement, an operator, a preposition
constant kAfterValue = "then else into before after to from with for until at and or is contains div mod , ) & = < > + - * / ^"

-- Words that are never an object's name: operators and words of the
-- grammar; and after "card" or "bkgnd", plurals ("the number of card
-- buttons") and the card's own parts
constant kNeverNames = "id this me it the a an is are and or not contains div mod in within of to into then else with by from at"
constant kNeverNamesAfterCard = "cards cds fields flds buttons btns backgrounds bkgnds bgs stacks parts lines items words chars characters picture window next prev previous"

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

-- Functions with no arguments that HyperTalk let a script write without
-- "the" or "()", as "if optionKey is down" (T33); the sweep of 2026-10-23
constant kBareFunctions = "mouse mouseloc mouseh mousev clickloc clickh clickv optionkey commandkey cmdkey shiftkey capslockkey"

-- The keys among them, which after "with" ("type "C" with commandKey",
-- "drag ... with optionKey, shiftKey") name a modifier, not a value
constant kModifierKeys = "optionkey commandkey cmdkey shiftkey capslockkey"

-- Words an answer's reply, unquoted, keeps as it is: constants, and "it"
constant kReplyKeep = "empty return quote space tab comma it true false cr lf eol"

-- Words that end an expression in a plain run of words (T27, T33): a run
-- of other words is a name HyperCard took as the text it was
constant kNotPlain = "the of and or not is in contains div mod within among"

constant kLibraryName = "HyperCard Library"

-- The properties of a menu and a menu item in HyperCard 2.2's menus
constant kMenuProperties = "checkmark commandchar cmdchar enabled markchar name textstyle menumessage menumsg"

-- The properties of HyperCard's picture and palette windows that this
-- engine's windows do not have (T26)
constant kWindowProperties = "scale scroll hilitedbutton zoom dithering globalloc globalrect"

-- The properties of the message box that scripts read and set (T28)
constant kMessageBoxProperties = "visible loc location rect rectangle top left bottom right width height topleft bottomright textfont textsize textstyle textalign"

-- the words a "go" names its destination with, as against an expression
-- whose value is the destination (T25)
constant kGoPlaces = "card cd cards background bkgnd bg backgrounds stack stacks this next prev previous first last back forth home help recent any middle mid second third fourth fifth sixth seventh eighth ninth tenth marked id window url"

-- What the probes found: a name's verdict, so that each name is compiled
-- once (keys are the name in lower case)
local sVariableRefused
local sHandlerRefused
local sNameRefused
local sParameterRefused

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

-- The names of the externals the last _StandIns made stand-ins for
local sStandInNames

-- The IDE loads this library at startup (revInternal__LoadLibrary, which
-- sends extensionInitialize); without these handlers it was loaded but
-- never put in the message path, so File > Import Stack could not call it
-- and stopped without a word
on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   if the long id of me is not among the lines of the backScripts then
      insert the script of me into back
   end if
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if
   remove the script of me from back
end extensionFinalize

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
as it is, except for the doMenu routing and the statements that stop
with an error here where HyperCard went on, described in the library's
header. Every object whose script changes keeps its HyperTalk in its
custom property uHyperCard["script"]; the stack's uHyperCard["scripts"]
holds the report, and the summary line is added to the hcImportStat.
The substack "HyperCard Library (<stack name>)" is added as the stack's
behavior.

Messages are locked while it runs, so that no handler of the stack runs.
*/
function revHyperCardFixScripts pStack
   local tObjects, tObject, tLines, tDefines, tExternals, tReport
   local tChanged, tSalvaged, tStubs, tStill, tWasLocked, tLine, tSummary, tStandIns

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
   put _StandIns(sStack, tDefines) into tStandIns
   delete sProbe
   put empty into sProbe

   put _AddLibrary(sStack, tStandIns) into tLine
   if tLine is not empty then put tLine & return after tReport
   if tLine begins with "Added" and sStandInNames is not empty then
      put "Stand-ins: the stack's external commands, which this engine cannot run, do nothing when called:" && sStandInNames & return after tReport
   end if

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
The script of the substack "HyperCard Library (<stack name>)" that
<revHyperCardFixScripts> adds to an imported stack: the file
revhypercardlibrary.livecodescript beside this library, without its
first line. A copy of this library with no such file beside it (the web
Stack Player carries one in its own stack) keeps that script in its
custom property cHyperCardLibraryScript.

Returns (String): The script.
*/
function revHyperCardLibraryScript
   local tPath, tScript
   if the cHyperCardLibraryScript of me is not empty then
      return the cHyperCardLibraryScript of me
   end if
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

-- Stand-ins for the stack's external commands (the XCMDs of its resource
-- fork, which the importer lists in uHyperCard["externals"]): this engine
-- cannot run them, and a script that called one stopped with "can't find
-- handler" where in HyperCard the external did its work (most often a
-- sound, colour, a palette or a menu). A stand-in does nothing but leave
-- "<name> is not available" in the result, which a script that checks
-- for the external's errors sees, so that the script goes on; the report
-- names each one. An external function (XFCN) gets none: what it gave is
-- what the script goes on with, and empty in its place would be a wrong
-- value no one sees, where the error at least says where it stopped.
-- None is made for a name the stack's scripts define, or the library
-- does, or that cannot be a handler's name here; an external named like
-- a keyword is called hcX_<name> after T13, and its stand-in is too.
private function _StandIns pStack, pDefines
   local tLine, tType, tName, tCall, tLibrary, tHandler, tOut, tDone
   put empty into sStandInNames
   repeat for each line tLine in revHyperCardLibraryScript()
      if word 1 of tLine is among the words of "on function command" then put true into tLibrary[_Lower(word 2 of tLine)]
   end repeat
   set the itemDelimiter to tab
   repeat for each line tLine in the uHyperCard["externals"] of pStack
      put word 1 to -1 of item 1 of tLine into tType
      put word 1 to -1 of item 2 of tLine into tName
      if tType is not "XCMD" then next repeat
      if not _IsName(tName) then next repeat
      if pDefines[_Lower(tName)] or tLibrary[_Lower(tName)] or tDone[_Lower(tName)] then next repeat
      put tName into tCall
      if _Lower(tName) is not among the words of kHyperTalkCommands \
            and _Lower(tName) is not among the words of "set put get go if send do add show hide" \
            and (_Lower(tName) is among the words of kCommands or _Lower(tName) is among the words of kRefused or _HandlerRefused(tName)) then
         put "hcX_" & tName into tCall
      end if
      if tLibrary[_Lower(tCall)] then next repeat
      put "on" && tCall & return & "   return" && quote & tName && "is not available" & quote & return & "end" && tCall into tHandler
      if not _Compiles(tHandler) then next repeat
      put true into tDone[_Lower(tName)]
      put return & return & "-- The" && tType && tName && "of the stack, which this engine cannot run (a stand-in)" & return & tHandler after tOut
      if sStandInNames is not empty then put ", " after sStandInNames
      put tName after sStandInNames
   end repeat
   if tOut is not empty and not _Compiles(revHyperCardLibraryScript() & tOut) then
      put empty into sStandInNames
      return empty
   end if
   return tOut
end _StandIns

-- Add the library as a substack of the stack and make it the stack's
-- behavior. Returns a line for the report, or empty if it was there.
private function _AddLibrary pStack, pStandIns
   local tName, tCount, tBase
   if the behavior of pStack is not empty then
      return "Not added: the HyperCard library (the stack already has a behavior)"
   end if
   -- Named after the stack: the engine knows a behavior by its stack's
   -- name alone, so the libraries of two imports with one name were one
   -- library to it, and deleting either stack broke the other's. A
   -- substack of the import may have the name already: this library is
   -- the one marked as it, under the first free name
   put kLibraryName && "(" & the short name of pStack & ")" into tBase
   put tBase into tName
   put 1 into tCount
   repeat while tName is among the lines of the substacks of pStack \
         and the uHyperCard["library"] of stack tName of pStack is not true
      add 1 to tCount
      put tBase && tCount into tName
   end repeat
   if tName is not among the lines of the substacks of pStack then
      -- made under a name no other stack has, as the library of a stack
      -- imported before would otherwise be the one "it" names
      local tTemp
      put "revHyperCardLibrary" & the milliseconds into tTemp
      create invisible stack tTemp
      set the mainStack of stack tTemp to the short name of pStack
      set the name of stack tTemp of pStack to tName
      set the script of stack tName of pStack to revHyperCardLibraryScript() & pStandIns
      set the uHyperCard["library"] of stack tName of pStack to true
      -- create opens it: closed, it is not the topStack the IDE's
      -- palettes and menus act on, and it stays a substack
      close stack tName of pStack
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

-- Whether this engine refuses pName as a parameter's name ("on choose
-- tool, n", "on fill f, invisible"), which a variable of that name is
-- not always refused as
private function _ParameterRefused pName
   put _Lower(pName) into pName
   if sProbe is empty or not _IsName(pName) then return false
   if sParameterRefused[pName] is empty then
      put not _Compiles("on hcProbe" && pName & return & "end hcProbe") into sParameterRefused[pName]
   end if
   return sParameterRefused[pName]
end _ParameterRefused

-- Whether this engine refuses pName as an object's name not in quotes
-- ("field next", "card fld button")
private function _NameRefused pName
   put _Lower(pName) into pName
   if sNameRefused[pName] is empty then
      if sProbe is empty then
         put pName is among the words of kRefused or pName is among the words of kRenamedWhereVariable into sNameRefused[pName]
      else
         put not _Compiles("on hcProbe" & return & "get field" && pName & return & "end hcProbe") into sNameRefused[pName]
      end if
   end if
   return sNameRefused[pName]
end _NameRefused

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

-- Whether pText is one word token: a name a handler could have
private function _IsName pText
   local tChar
   if pText is empty or not _IsWordStart(char 1 of pText) then return false
   repeat for each char tChar in pText
      if not _IsWordChar(tChar) then return false
   end repeat
   return true
end _IsName

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
      -- handler), HyperCard's version, and the statements that stop with
      -- an error here where HyperCard went on (_HyperCardRules)
      repeat with i = 1 to tCount
         if tRenameHandlers["domenu"] is not empty then put _RouteDoMenu(tLines[i]) into tLines[i]
         put _VersionRule(tLines[i]) into tLines[i]
      end repeat
      repeat with i = 1 to tSpanCount
         _HyperCardRulesLines tLines, tSpans[i]["start"], tSpans[i]["end"], true
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
         if _VariableRefused(tWord) then
            put true into tRename[tWord]
         else if tWord is among the words of kRenamedWhereVariable or _ParameterRefused(tWord) then
            put "where" into tRename[tWord]
         end if
      end repeat
      repeat with tKey = tSpans[i]["start"] to tSpans[i]["end"]
         put _RewriteLine(tLines[tKey], tVars, tRename, pExternals, tRenameHandlers) into tLines[tKey]
      end repeat
      _ContinuedCommands tLines, tSpans[i]["start"], tSpans[i]["end"]
      _HyperCardRulesLines tLines, tSpans[i]["start"], tSpans[i]["end"], false
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

-- _HyperCardRules on the lines pStart to pEnd, a statement continued
-- over lines taken whole ("put ... after menuItem ... of menu M \" and
-- "with menuMsg ..." on the next line): when a rule rewrites it, it is put
-- on its first line and the lines it took after that are left empty, as
-- _ContinuedCommands does
private command _HyperCardRulesLines @pLines, pStart, pEnd, pCompiled
   local i, j, k, tMerged, tNew
   put pStart into i
   repeat while i <= pEnd
      if char -1 of word 1 to -1 of _CodeText(pLines[i]) is not "\" then
         put _HyperCardRules(pLines[i], pCompiled) into pLines[i]
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
      put _HyperCardRules(tMerged, pCompiled) into tNew
      if tNew is not tMerged then
         put tNew into pLines[i]
         repeat with k = i + 1 to j
            put empty into pLines[k]
         end repeat
      end if
      put j + 1 into i
   end repeat
end _HyperCardRulesLines

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
   local tVars, i, tCode, tWord, tTokens, tIndices, tIndex, tNext, tAfter, tInGlobal
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
   put false into tInGlobal
   repeat with i = pStart to pEnd
      put _CodeText(pLines[i]) into tCode
      -- a global statement, and the lines it is continued over with \
      if word 1 of tCode is "global" or tInGlobal then
         put char -1 of word 1 to -1 of tCode is "\" into tInGlobal
         if word 1 of tCode is "global" then delete word 1 of tCode
         replace comma with space in tCode
         repeat for each word tWord in tCode
            if tWord is not "\" and _IsWordStart(char 1 of tWord) then put true into tVars[_Lower(tWord)]
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
            -- "into field x", "into line 2 of x": not a variable ("into
            -- card" alone is one)
            if _T(tTokens, tNext) is among the words of kObjectWords and tAfter is not empty and _T(tTokens, tAfter) is not "else" then next repeat
            if _T(tTokens, tAfter) is "of" then next repeat
            if tAfter is not empty and tTokens[tAfter]["k"] is "n" then next repeat
            if tAfter is not empty and _T(tTokens, tAfter) is among the words of kObjectWords then next repeat
            put true into tVars[_T(tTokens, tNext)]
         end if
      end repeat
   end repeat
   return tVars
end _HandlerVariables

-- Whether pWord, a variable of the handler named like a word of the
-- grammar (kRenamedWhereVariable), stands here where a variable stands:
-- before the end of the statement or an operator ("put x into this",
-- "if item is 1", "on doMenu menuItem, menu"), or as a chunk's number
-- ("line item of x"); not after "the" or "go", nor as the card or the
-- background after "of" ("the name of card", which T11 reads as this
-- card)
private function _VariableHere pTokens, pWord, pPrev, pNext
   local tPrev, tNext
   put _T(pTokens, pPrev) into tPrev
   put _T(pTokens, pNext) into tNext
   if tPrev is among the words of "the go" then return false
   if tPrev is "of" and pWord is among the words of "card cd background bkgnd bg" then return false
   if tPrev is among the words of "char character word item line" and tNext is among the words of "of to" then return true
   if pNext is empty then return true
   if pTokens[pNext]["k"] is among the items of "n,s" then return false
   return tNext is among the words of kAfterValue
end _VariableHere

-- Whether an object's name ends before pNext: the end of the statement,
-- an operator, or "of" and the object it is in ("of this card")
private function _NameEnds pTokens, pCode, pNext
   local tNext
   if pNext is empty then return true
   put _T(pTokens, pNext) into tNext
   if tNext is "of" then
      return _T(pTokens, _NextCode(pCode, pNext)) is among the words of "this card cd background bkgnd bg stack"
   end if
   if pTokens[pNext]["k"] is among the items of "n,s" then return false
   return tNext is among the words of kAfterValue
end _NameEnds

-- The rules that work on one line of a handler
private function _RewriteLine pLine, pVars, pRename, pExternals, pRenameHandlers
   local tTokens, tCode, tIndex, tPrev, tNext, tWord, tNew, tFirst, tAfter, tChanged
   local tLine

   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put item 1 of tCode into tFirst

   -- T31: a string not closed at the end of the line, which HyperCard
   -- closed there ("domenu " & quote & "Quit HyperCard")
   put item -1 of tCode into tIndex
   if tIndex is not empty and tTokens[tIndex]["k"] is "s" and tIndex = tTokens["count"] \
         and (the number of chars of tTokens[tIndex]["t"] = 1 or char -1 of tTokens[tIndex]["t"] is not quote) \
         and char -1 of word -1 of tTokens[tIndex]["t"] is not "\" then
      put quote after tTokens[tIndex]["t"]
      _Fire "T31 HyperTalk this engine's parser refuses"
   end if

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

      -- T33: a function with no arguments written without "the" or "()"
      -- ("put mouseLoc into p", "if optionKey is down"), where it is not
      -- a variable of the handler, nor a command or a message's name, nor
      -- a modifier key after "with"
      if tWord is among the words of kBareFunctions and not pVars[tWord] \
            and _T(tTokens, tPrev) is not among the words of "the on function end pass exit send with" \
            and not (tWord is among the words of kModifierKeys and _T(tTokens, tPrev) is "," \
            and _T(tTokens, _PrevCode(tCode, tPrev)) is among the words of kModifierKeys) \
            and (tNext is empty or tTokens[tNext]["k"] is "p" or _T(tTokens, tNext) is among the words of kAfterValue) \
            and _T(tTokens, tNext) is not "(" \
            and not _StatementStart(tTokens, tCode, tIndex) then
         put "the " before tTokens[tIndex]["t"]
         _Fire "T33 more forms HyperCard took"
         next repeat
      end if

      -- T2: a variable whose name is refused
      if pRename[tWord] is "where" then
         if _VariableHere(tTokens, tWord, tPrev, tNext) then
            put "hc_" & tTokens[tIndex]["t"] into tTokens[tIndex]["t"]
            _Fire "T2 variable named like a keyword"
            next repeat
         end if
      else if pRename[tWord] is true then
         if _T(tTokens, tPrev) is not among the words of "the set" \
               and not (_T(tTokens, tNext) is "of" and _T(tTokens, tPrev) is not among the words of "char character word item line to into" \
               and _T(tTokens, tPrev) is not among the words of kObjectWords) then
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
      -- ... and any other word this engine refuses there, where the name
      -- ends the object ("field next", "card fld button into x", "bg
      -- field title of this card")
      if tPrev is not empty and not pVars[tWord] and tWord is not among the words of kNeverNames \
            and _T(tTokens, tFirst) is not "choose" \
            and (_T(tTokens, tPrev) is among the words of "field fld button btn" \
            or (_T(tTokens, tPrev) is among the words of "card cd background bkgnd bg" and tWord is not among the words of kObjectWords \
            and tWord is not among the words of kNeverNamesAfterCard)) \
            and _NameEnds(tTokens, tCode, tNext) and _NameRefused(tWord) then
         put quote & tTokens[tIndex]["t"] & quote into tTokens[tIndex]["t"]
         put "s" into tTokens[tIndex]["k"]
         _Fire "T3 object name that is a keyword quoted"
         next repeat
      end if
   end repeat
   put _Join(tTokens) into pLine

   put _PhraseRules(pLine) into pLine
   put _ParserForms(pLine, pVars) into pLine
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
      if tWord is among the words of "message msg" and tPrev is "the" and tNext is not "of" and tNext is not "watcher" then
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
      if tWord is "number" and tNext is "of" and tPrev is not "the" and tTokens[tIdx[i]]["k"] is "w" \
            and tPrev is not among the words of "char character word item line" and tPrev is not among the words of kObjectWords then
         put "the " before tTokens[tIdx[i]]["t"]
         _Fire "T7 function without the"
         next repeat
      end if
      if tWord is "version" and tPrev is among the words of "if put get return then else and or not is ( , = < > & + - * /" \
            and (tNext is empty or tNext is among the words of ") , into then else and or is = < > & + - * /") then
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
      -- (T33: and without "the", "if version of HyperCard < 2"; not "the
      -- long version of HyperCard", which compiles as it is)
      if tWord is "version" and tPrev is not among the words of "the long short abbreviated abbrev abbr english" \
            and tNext is "of" and tNext2 is "hypercard" then
         _Replace tTokens, tIdx, i, i + 2, "hcVersion()"
         _Fire "T33 more forms HyperCard took"
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

      -- T11: an object named by its type alone: "of cd", "of bkgnd", "the
      -- size of stack"
      if tWord is among the words of "bkgnd bg background cd card stack" and (tPrev is "of" or (tPrev is "to" and tFirstWord is "send")) \
            and (tNext is empty or tNext is among the words of ") , into to then else and or with is = < > & + - * /") then
         put "this " before tTokens[tIdx[i]]["t"]
         _Fire "T11 HyperCard object words"
         next repeat
      end if
      -- "of window" alone (SuperCard's, in stacks that ran in both): the
      -- window of this stack
      if tWord is "window" and tPrev is "of" \
            and (tNext is empty or tNext is among the words of ") , into to then else and or with is = < > + - * /") then
         put "this stack" into tTokens[tIdx[i]]["t"]
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
      -- fld "Notes" in card "Menu", first cd in bg "Recipes": "in" for
      -- "of" after an object, before the card or background it is on
      if tWord is "in" and tNext is among the words of "card cd bkgnd bg background stack" and i > 2 \
            and (tPrev is among the words of kObjectWords \
            or (tTokens[tIdx[i - 1]]["k"] is among the items of "s,n,w" and _T(tTokens, tIdx[i - 2]) is among the words of kObjectWords) \
            or (tTokens[tIdx[i - 1]]["k"] is among the items of "s,n,w" and _T(tTokens, tIdx[i - 2]) is "id" and _T(tTokens, tIdx[i - 3]) is among the words of kObjectWords)) then
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

-- T31: forms HyperCard took and this engine's parser refuses, statement
-- by statement (a statement starts a line, or follows "then" or "else");
-- pVars: the handler's variables
private function _ParserForms pLine, pVars
   local tTokens, tCode, tIdx, n, tItem, i, j, k, tEnd, tWord, tDepth, tAt, tTypes
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   put "STAK" into tTypes["stack"]
   put "TEXT" into tTypes["text"]
   put "APPL" into tTypes["application"]
   put "PICT" into tTypes["picture"]
   put "PNTG" into tTypes["painting"]
   put "PNTG" into tTypes["paint"]

   repeat with i = 1 to n
      if tTokens[tIdx[i]]["k"] is not "w" then next repeat
      if i > 1 and _T(tTokens, tIdx[i - 1]) is not among the words of "then else" then next repeat
      put _T(tTokens, tIdx[i]) into tWord
      put n into tEnd
      repeat with j = i + 1 to n
         if _T(tTokens, tIdx[j]) is among the words of "then else" then
            put j - 1 into tEnd
            exit repeat
         end if
      end repeat

      switch tWord
         case "answer"
         case "ask"
            if _T(tTokens, tIdx[i + 1]) is "file" then
               -- answer file "Open which?" of type stack: the file type by
               -- the name HyperCard gave it
               repeat with j = i + 2 to tEnd - 1
                  if _T(tTokens, tIdx[j]) is "type" and _T(tTokens, tIdx[j - 1]) is "of" then
                     repeat with k = j + 1 to tEnd
                        if tTypes[_T(tTokens, tIdx[k])] is not empty and tTokens[tIdx[k]]["k"] is "w" then
                           put quote & tTypes[_T(tTokens, tIdx[k])] & quote into tTokens[tIdx[k]]["t"]
                           put "s" into tTokens[tIdx[k]]["k"]
                           _Fire "T31 HyperTalk this engine's parser refuses"
                        else if _T(tTokens, tIdx[k]) is not among the words of "or ," then
                           exit repeat
                        end if
                     end repeat
                     exit repeat
                  end if
               end repeat
            else if tWord is "answer" then
               -- answer "Which?" with "A", "B", "C": the replies with "or"
               -- between them, as this engine takes them
               put empty into tAt
               put 0 into tDepth
               repeat with j = i + 1 to tEnd
                  if _T(tTokens, tIdx[j]) is "(" then add 1 to tDepth
                  if _T(tTokens, tIdx[j]) is ")" then subtract 1 from tDepth
                  if tDepth = 0 and tAt is empty and _T(tTokens, tIdx[j]) is "with" then put j into tAt
                  if tDepth = 0 and tAt is not empty and _T(tTokens, tIdx[j]) is "," then
                     put " or " into tTokens[tIdx[j]]["t"]
                     _ClearSpaceAfter tTokens, tIdx[j]
                     _Fire "T31 HyperTalk this engine's parser refuses"
                  end if
               end repeat
               -- T33: a reply that is one word not in quotes ("with Yes
               -- or No"), which HyperCard took as the text it was when it
               -- was not a variable: in quotes
               if tAt is not empty then
                  repeat with j = tAt + 1 to tEnd
                     if tTokens[tIdx[j]]["k"] is "w" and _T(tTokens, tIdx[j - 1]) is among the items of "with,or,," \
                           and (j = tEnd or _T(tTokens, tIdx[j + 1]) is among the items of "or,,") \
                           and not pVars[_T(tTokens, tIdx[j])] and _T(tTokens, tIdx[j]) is not among the words of kReplyKeep then
                        put quote & tTokens[tIdx[j]]["t"] & quote into tTokens[tIdx[j]]["t"]
                        put "s" into tTokens[tIdx[j]]["k"]
                        _Fire "T33 more forms HyperCard took"
                     end if
                  end repeat
               end if
            end if
            break
         case "convert"
            -- T33: convert an expression that is not a container
            -- ("convert fileModDate(f) to short date"), which HyperCard
            -- put into it converted: get it, then convert it (a statement
            -- alone on its line only)
            if i = 1 and tEnd = n then
               put empty into tAt
               put 0 into tDepth
               repeat with j = i + 1 to tEnd
                  if _T(tTokens, tIdx[j]) is "(" then add 1 to tDepth
                  if _T(tTokens, tIdx[j]) is ")" then subtract 1 from tDepth
                  if tDepth = 0 and _T(tTokens, tIdx[j]) is "to" then put j into tAt
               end repeat
               if tAt is not empty and tAt > i + 2 and tAt < tEnd \
                     and _T(tTokens, tIdx[i + 1]) is not among the words of "char character word item line" \
                     and _T(tTokens, tIdx[i + 1]) is not among the words of kObjectWords \
                     and _T(tTokens, tIdx[i + 1]) is not among the words of "card cd background bkgnd bg" then
                  _Fire "T33 more forms HyperCard took"
                  return _Raw(tTokens, 1, tIdx[i] - 1) & "get" && _Span(tTokens, tIdx, i + 1, tAt - 1) & "; convert it" && _Raw(tTokens, tIdx[tAt], tTokens["count"])
               end if
            end if
            break
         case "create"
            -- create stack ... in a new window: this engine opens the new
            -- stack in a window of its own anyway
            if _T(tTokens, tIdx[i + 1]) is "stack" and tEnd > i + 5 and _Span(tTokens, tIdx, tEnd - 3, tEnd) is "in a new window" then
               _Replace tTokens, tIdx, tEnd - 3, tEnd, empty
               put empty into tTokens[tIdx[tEnd - 3] - 1]["t"]
               _Fire "T31 HyperTalk this engine's parser refuses"
            end if
            break
         case "go"
            -- go to first card of "Addresses": "of" a stack named without
            -- the word "stack", after a card (T16 then finds the stack)
            put false into tAt
            put 0 into tDepth
            repeat with j = i + 1 to tEnd - 1
               put _T(tTokens, tIdx[j]) into tItem
               if tItem is "(" then add 1 to tDepth
               if tItem is ")" then subtract 1 from tDepth
               if tDepth > 0 or tItem is ")" then next repeat
               if tItem is among the words of "card cd" then put true into tAt
               if tItem is among the words of "stack background bkgnd bg char character word item line url" then exit repeat
               if tItem is "of" and tAt then
                  put _T(tTokens, tIdx[j + 1]) into tItem
                  if tTokens[tIdx[j + 1]]["k"] is "s" or (tTokens[tIdx[j + 1]]["k"] is "w" \
                        and tItem is not among the words of kGoPlaces and tItem is not among the words of kObjectWords \
                        and tItem is not among the words of "the me target") then
                     put "stack " before tTokens[tIdx[j + 1]]["t"]
                     _Fire "T31 HyperTalk this engine's parser refuses"
                  end if
                  exit repeat
               end if
            end repeat
            break
      end switch

      -- the number of items in line i of fld "toc" of line i of fld
      -- "toc": HyperCard took the count's chunk to end where the same
      -- chunk began again; here the count takes all of it
      repeat with j = i to tEnd - 6
         if _T(tTokens, tIdx[j]) is "the" and _T(tTokens, tIdx[j + 1]) is "number" and _T(tTokens, tIdx[j + 2]) is "of" \
               and _T(tTokens, tIdx[j + 4]) is among the words of "in of" then
            repeat with k = j + 6 to tEnd - 1
               if _T(tTokens, tIdx[k]) is "of" and _Lower(_Span(tTokens, tIdx, j + 5, k - 1)) is _Lower(_Span(tTokens, tIdx, k + 1, tEnd)) then
                  put "(" before tTokens[tIdx[j]]["t"]
                  put ")" after tTokens[tIdx[k - 1]]["t"]
                  _Fire "T31 HyperTalk this engine's parser refuses"
                  exit repeat
               end if
            end repeat
         end if
      end repeat
   end repeat
   return _Join(tTokens)
end _ParserForms

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
   -- (T33: go to card 1 of home, go first card of stack home, with Home
   -- not in quotes: the Home card, which is the first)
   if _Span(pTokens, pIdx, j, j + 2) is among the lines of ("card 1 of" & return & "cd 1 of" & return & "first card of" & return & "first cd of") then
      add 3 to j
      if _T(pTokens, pIdx[j]) is "stack" then add 1 to j
      if _T(pTokens, pIdx[j]) is not "home" then
         return false
      end if
   else if _Span(pTokens, pIdx, j, j + 3) is among the lines of ("the first card of" & return & "the first cd of") then
      add 4 to j
      if _T(pTokens, pIdx[j]) is "stack" then add 1 to j
      if _T(pTokens, pIdx[j]) is not "home" then
         return false
      end if
   end if
   if _T(pTokens, pIdx[j]) is "stack" then add 1 to j
   if _T(pTokens, pIdx[j]) is not "home" and _T(pTokens, pIdx[j]) is not quote & "home" & quote then return false
   -- (HyperCard's "in a new window" is no different for the Home stack)
   if j + 4 = pCount and _Span(pTokens, pIdx, j + 1, pCount) is "in a new window" then put pCount into j
   if j <> pCount then return false
   _Replace pTokens, pIdx, pAt, j, "hcGoHome"
   return true
end _GoHome

-- T5: notes after play, unquoted
private function _PlayNotes pLine
   local tHead, tNotes, tComment
   if matchText(pLine, "(?i)^(\s*play\s+(?:" & quote & "[^" & quote & "]*" & quote & "|\w+)(?:\s+(?:tempo\s+\w+|faster|slower|fast|slow))*\s+)([a-gr][#bs]?\d?[whqestx3.]*\d?(?:\s+[a-gr][#bs]?\d?[whqestx3.]*\d?)*)\s*(--.*)?$", tHead, tNotes, tComment) then
      if quote is not in tNotes then
         _Fire "T5 unquoted notes"
         if tComment is not empty then put space before tComment
         return tHead & quote & tNotes & quote & tComment
      end if
   end if
   return pLine
end _PlayNotes

-- T9, T16 to T30 and T32: statements that stop with an error here where
-- HyperCard went on, or that do something else here; in every script,
-- compiling or not, one statement a line at most (a statement continued
-- with \ is left as it is)
private function _HyperCardRules pLine, pCompiled, pElse
   local tTokens, tCode, tIdx, n, tItem, i, j, tEnd, tWord, tNew, tPlain

   -- (pElse: the rest of a line from its else, whose phrases are done)
   if pCompiled and pElse is not true then put _PlayNotes(pLine) into pLine
   if char -1 of word 1 to -1 of _CodeText(pLine) is "\" then return pLine
   if pElse is not true then
      put _MenuItemProperties(pLine) into pLine
      put _HyperCardWindows(pLine) into pLine
      put _MessageBoxProperties(pLine) into pLine
      put _HyperCardObject(pLine) into pLine
   end if
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat

   repeat with i = 1 to n
      if tTokens[tIdx[i]]["k"] is not "w" then next repeat
      put _T(tTokens, tIdx[i]) into tWord

      -- T20: fileName(...), the XFCN, which this engine reads as the
      -- property: the library's stand-in (any statement)
      if tWord is "filename" and _T(tTokens, tIdx[i + 1]) is "(" and _T(tTokens, tIdx[i - 1]) is not among the words of "the of" then
         put "hcX_" & tTokens[tIdx[i]]["t"] into tTokens[tIdx[i]]["t"]
         _Fire "T20 fileName()"
         next repeat
      end if

      if i > 1 and _T(tTokens, tIdx[i - 1]) is not among the words of "then else" then next repeat
      -- the statement: to the end of the line, or to an else
      put n into tEnd
      repeat with j = i + 1 to n
         if _T(tTokens, tIdx[j]) is "else" then
            put j - 1 into tEnd
            exit repeat
         end if
      end repeat

      put empty into tNew
      switch tWord
         case "go"
            if pCompiled and _GoHome(tTokens, tIdx, i, n) then
               _Fire "T9 go home"
               return _Join(tTokens)
            end if
            -- T25: "in" for "of" before a background or a stack, which
            -- HyperCard took ("go to first card in bkgnd 2")
            repeat with j = i + 1 to tEnd - 1
               if _T(tTokens, tIdx[j]) is "in" and _T(tTokens, tIdx[j + 1]) is among the words of "bkgnd bg background stack" then
                  _Fire "T25 go: in for of"
                  put "of" into tTokens[tIdx[j]]["t"]
               end if
            end repeat
            put _GoStack(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _GoTo(tTokens, tIdx, i, tEnd) into tNew
            break
         case "set"
            put _SetCursor(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetMenuItem(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetWindow(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetMessageBox(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetCardAndStyle(tTokens, tIdx, i, tEnd) into tNew
            break
         case "put"
            put _PutIntoMenu(tTokens, tIdx, i, tEnd) into tNew
            break
         case "enable"
         case "disable"
         case "create"
         case "delete"
            put _MenuCommand(tTokens, tIdx, i, tEnd) into tNew
            break
         case "start"
         case "stop"
            -- T23: start and stop using a stack that is not open, which
            -- the library finds as it finds the stack of a "go"
            if _T(tTokens, tIdx[i + 1]) is "using" and _T(tTokens, tIdx[i + 2]) is "stack" and i + 3 <= tEnd then
               _Fire "T23 start using a stack not open"
               if tWord is "start" then
                  put "hcStartUsing" && _Span(tTokens, tIdx, i + 3, tEnd) into tNew
               else
                  put "hcStopUsing" && _Span(tTokens, tIdx, i + 3, tEnd) into tNew
               end if
            end if
            break
         case "choose"
            -- T30: choose tool 4, choose tool x, choose btn tool: this
            -- engine takes "choose button tool" alone, and stops with an
            -- error on "choose tool x" whatever x is
            if _T(tTokens, tIdx[i + 1]) is "tool" and i + 2 <= tEnd then
               _Fire "T30 choose tool"
               put "hcChooseTool" && _Span(tTokens, tIdx, i + 2, tEnd) into tNew
            else if tEnd > i and _T(tTokens, tIdx[tEnd]) is not "tool" then
               -- choose "Select Tool", choose tName: the tool by a name in
               -- an expression, which this engine takes in lower case only
               _Fire "T30 choose tool"
               put "hcChooseTool" && _Span(tTokens, tIdx, i + 1, tEnd) into tNew
            else if _T(tTokens, tIdx[i + 1]) is among the words of "btn fld" and _T(tTokens, tIdx[i + 2]) is "tool" and i + 2 = tEnd then
               _Fire "T30 choose tool"
               if _T(tTokens, tIdx[i + 1]) is "btn" then
                  put "choose button tool" into tNew
               else
                  put "choose field tool" into tNew
               end if
            end if
            break
         case "print"
            -- T24: print a field, which HyperCard printed and this engine
            -- does not (it prints cards): the library's PrintField
            put i + 1 into j
            if _T(tTokens, tIdx[j]) is among the words of "card cd background bkgnd bg" then add 1 to j
            if _T(tTokens, tIdx[j]) is among the words of "field fld" and j < tEnd then
               _Fire "T24 print a field"
               put "PrintField the long id of" && _Span(tTokens, tIdx, i + 1, tEnd) into tNew
            end if
            break
         case "show"
         case "hide"
         case "close"
            put _ShowHide(tTokens, tIdx, i, tEnd) into tNew
            break
         case "send"
            -- T29: send ... to HyperCard, the application, which had the
            -- message's built-in handler: hcSendToHyperCard
            if tEnd > i + 2 and _T(tTokens, tIdx[tEnd]) is "hypercard" and _T(tTokens, tIdx[tEnd - 1]) is "to" then
               _Fire "T29 HyperCard the application"
               put "hcSendToHyperCard" && _Span(tTokens, tIdx, i + 1, tEnd - 2) into tNew
            end if
            break
         case "domenu"
         case "hcdomenu"
            -- T27: doMenu with the item's name not in quotes ("doMenu
            -- New Card"), which HyperCard took as the text it was;
            -- here two names side by side are no expression
            if tEnd > i + 1 then
               put true into tPlain
               repeat with j = i + 1 to tEnd
                  -- (the dots of "New Stack..." are part of the name)
                  if j > i + 1 and tTokens[tIdx[j]]["k"] is "p" and tTokens[tIdx[j]]["t"] is "." then next repeat
                  if tTokens[tIdx[j]]["k"] is not "w" or _T(tTokens, tIdx[j]) is among the words of kNotPlain then
                     put false into tPlain
                     exit repeat
                  end if
               end repeat
               if tPlain then
                  _Fire "T27 doMenu with the item not in quotes"
                  put tTokens[tIdx[i]]["t"] && quote & _Span(tTokens, tIdx, i + 1, tEnd) & quote into tNew
               end if
            end if
            -- doMenu "New Button": HyperCard named the button it made "New
            -- Button", and scripts go on to set its name by that one; the
            -- library makes it so (this engine's button has no name)
            if tWord is "domenu" and tEnd = i + 1 and _T(tTokens, tIdx[i + 1]) is quote & "new button" & quote then
               _Fire "T27 doMenu with the item not in quotes"
               put "hcDoMenu" && tTokens[tIdx[i + 1]]["t"] into tNew
            end if
            break
         default
            -- T18: tabKey and HyperCard's other key commands, and the
            -- picture command
            if tWord is among the words of "tabkey arrowkey returnkey enterkey returninfield enterinfield functionkey picture" then
               put "hc" & item itemOffset(tWord, "tabkey,arrowkey,returnkey,enterkey,returninfield,enterinfield,functionkey,picture") of "TabKey,ArrowKey,ReturnKey,EnterKey,ReturnInField,EnterInField,FunctionKey,Picture" into tTokens[tIdx[i]]["t"]
               _Fire "T18 key and picture commands"
               return _AndElse(tTokens, tIdx, tEnd, n, pCompiled)
            end if
      end switch
      if tNew is not empty then
         _Replace tTokens, tIdx, i, tEnd, tNew
         return _AndElse(tTokens, tIdx, tEnd, n, pCompiled)
      end if
   end repeat
   return _Join(tTokens)
end _HyperCardRules

-- The line, with the rules applied to its else as well when a statement
-- before it was rewritten ("if x then go stack A else go stack B")
private function _AndElse @pTokens, pIdx, pEnd, pCount, pCompiled
   local tHead, tRest, k
   if pEnd >= pCount then return _Join(pTokens)
   repeat with k = 1 to pTokens["count"]
      if k < pIdx[pEnd + 1] then
         put pTokens[k]["t"] after tHead
      else
         put pTokens[k]["t"] after tRest
      end if
   end repeat
   return tHead & _HyperCardRules(tRest, pCompiled, true)
end _AndElse

-- The text of the code tokens pFrom to pTo, spaces between them included
private function _Span pTokens, pIdx, pFrom, pTo
   if pFrom > pTo then return empty
   return _Raw(pTokens, pIdx[pFrom], pIdx[pTo])
end _Span

-- Where the expression that starts at pFrom ends, before pTo or before
-- the first of pWords outside parentheses
private function _ExpressionEnd pTokens, pIdx, pFrom, pTo, pWords
   local j, tDepth
   put 0 into tDepth
   repeat with j = pFrom to pTo
      if _T(pTokens, pIdx[j]) is "(" then add 1 to tDepth
      if _T(pTokens, pIdx[j]) is ")" then subtract 1 from tDepth
      if tDepth = 0 and j > pFrom and _T(pTokens, pIdx[j]) is among the words of pWords then return j - 1
   end repeat
   return pTo
end _ExpressionEnd

-- pText as a string literal, quotes and all
private function _Literal pText
   local tOut, tChar
   put quote into tOut
   repeat for each char tChar in pText
      if tChar is quote then
         put quote & " & quote & " & quote after tOut
      else
         put tChar after tOut
      end if
   end repeat
   put quote after tOut
   if char 1 to 5 of tOut is (quote & quote & " & ") then delete char 1 to 5 of tOut
   if char -5 to -1 of tOut is (" & " & quote & quote) then delete char -5 to -1 of tOut
   return tOut
end _Literal

-- T16: go to a stack. HyperCard looked for a stack that was not open
-- (asking "Where is ...?" if need be) and, failing that, went on with
-- "No such card" in the result; this engine stops with an error. The
-- statement is run by the library's hcGo, which finds the stack first
-- (the files beside the one imported, the disk image it came from) and
-- runs it with the stack expression in the variable tHCStack
private function _GoStack pTokens, pIdx, pAt, pEnd
   local j, k, tLast
   repeat with j = pAt + 1 to pEnd
      if _T(pTokens, pIdx[j]) is "stack" and _T(pTokens, pIdx[j - 1]) is not "this" then
         put j into k
         exit repeat
      end if
   end repeat
   if k is empty or k = pEnd then return empty
   if _T(pTokens, pIdx[k + 1]) is among the words of "id this" then return empty
   put _ExpressionEnd(pTokens, pIdx, k + 1, pEnd, "in as without") into tLast
   _Fire "T16 go to a stack not open"
   return "do hcGo(" & _Literal(_Raw(pTokens, pIdx[pAt], pIdx[k + 1] - 1) & "tHCStack" & _Raw(pTokens, pIdx[tLast] + 1, pIdx[pEnd])) & ", " & _Literal(_Span(pTokens, pIdx, k + 1, tLast)) & ")"
end _GoStack

-- T25: go to a destination given by an expression ("go " & quote &
-- "Addresses" & quote, "go to it", "go tWhere"), which HyperCard took for
-- a stack's name when it was not a card's description. This engine stops
-- with an error when there is no such stack open, or no such card; the
-- library's hcGoTo goes to the card, or finds the stack as hcGo does,
-- and failing both leaves "No such card" in the result
private function _GoTo pTokens, pIdx, pAt, pEnd
   local j, tLast, tTail
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "to" then add 1 to j
   if j > pEnd then return empty
   if _T(pTokens, pIdx[j]) is among the words of kGoPlaces then return empty
   if _T(pTokens, pIdx[j]) is "the" and _T(pTokens, pIdx[j + 1]) is among the words of kGoPlaces then return empty
   put _ExpressionEnd(pTokens, pIdx, j, pEnd, "in") into tLast
   if tLast < pEnd then put ", " & _Literal(_Span(pTokens, pIdx, tLast + 1, pEnd)) into tTail
   _Fire "T25 go to a destination by its name"
   return "hcGoTo" && _PlainName(pTokens, pIdx, j, tLast, true) & tTail
end _GoTo

-- T33: the code tokens pFrom to pTo as a name HyperCard took as the text
-- it was ("set the cursor to Mouse Cursor", "go Electronic Parts", "hide
-- window Clipboard"): in quotes when they are two words or more (numbers
-- too, with pNumbers, and the dots of "New Stack..."), or one word this
-- engine does not take as a value; otherwise the tokens as they are
private function _PlainName pTokens, pIdx, pFrom, pTo, pNumbers
   local j, tKind, tWords
   if pFrom > pTo or pTokens[pIdx[pFrom]]["k"] is not "w" then return _Span(pTokens, pIdx, pFrom, pTo)
   put 0 into tWords
   repeat with j = pFrom to pTo
      put pTokens[pIdx[j]]["k"] into tKind
      if tKind is "w" and _T(pTokens, pIdx[j]) is not among the words of kNotPlain then
         add 1 to tWords
      else if not ((tKind is "n" and pNumbers) or (tKind is "p" and pTokens[pIdx[j]]["t"] is ".")) then
         return _Span(pTokens, pIdx, pFrom, pTo)
      end if
   end repeat
   if tWords = 1 and pFrom = pTo and not _ValueRefused(pTokens[pIdx[pFrom]]["t"]) then return _Span(pTokens, pIdx, pFrom, pTo)
   _Fire "T33 more forms HyperCard took"
   return _Literal(_Span(pTokens, pIdx, pFrom, pTo))
end _PlainName

-- Whether this engine refuses pName as a value ("get clipboard"): only
-- with a probe, as a word that is a value is a variable or the text it is
private function _ValueRefused pName
   if sProbe is empty or not _IsName(pName) then return false
   return not _Compiles("on hcProbe" & return & "get" && pName & return & "end hcProbe")
end _ValueRefused

-- The text of the tokens pFrom to pTo
private function _Raw pTokens, pFrom, pTo
   local tText, k
   repeat with k = pFrom to pTo
      put pTokens[k]["t"] after tText
   end repeat
   return tText
end _Raw

-- T22: HyperCard 2.2's menus, which are not this engine's menus (an
-- imported stack has no menu bar here, and "menu" names a button of one):
-- each statement goes to the library, which keeps the menus as the
-- stack's scripts make them, so that what a script puts in a menu, checks
-- or disables reads back as it was, and no statement stops with an error

-- the checkMark (and the other properties) of menuItem I of menu M, in
-- an expression, menu and item each one token: hcMenuItem("checkmark",
-- M, I) (not after set, which _SetMenuItem rewrites)
private function _MenuItemProperties pLine
   local tTokens, tCode, tIdx, n, tItem, i, tChanged
   if "menuitem" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 1 to n - 7
      if _T(tTokens, tIdx[i]) is "the" and _T(tTokens, tIdx[i - 1]) is not "set" \
            and _T(tTokens, tIdx[i + 1]) is among the words of kMenuProperties \
            and _T(tTokens, tIdx[i + 2]) is "of" and _T(tTokens, tIdx[i + 3]) is "menuitem" \
            and _T(tTokens, tIdx[i + 5]) is "of" and _T(tTokens, tIdx[i + 6]) is "menu" then
         _Replace tTokens, tIdx, i, i + 7, "hcMenuItem(" & quote & _T(tTokens, tIdx[i + 1]) & quote & comma && tTokens[tIdx[i + 7]]["t"] & comma && tTokens[tIdx[i + 4]]["t"] & ")"
         _Fire "T22 HyperCard menus"
         put true into tChanged
      end if
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _MenuItemProperties

-- T28: the properties of the message box ("the visible of msg", "set
-- the loc of the message box to 18,30", "window " & quote & "Message" &
-- quote), which this engine reads as the text in the message box and so
-- stops with an error: the library's hcMessageBox("P") and
-- hcSetMessageBox "P", V

-- How many tokens from pAt name the message box (msg, message, message
-- box, message window, window "message"), or 0
private function _MessageBoxRef pTokens, pIdx, pAt
   local tWord
   put _T(pTokens, pIdx[pAt]) into tWord
   if tWord is "the" and _T(pTokens, pIdx[pAt + 1]) is among the words of "msg message" then
      return 1 + _MessageBoxRef(pTokens, pIdx, pAt + 1)
   end if
   if tWord is among the words of "msg message" then
      if _T(pTokens, pIdx[pAt + 1]) is among the words of "box window" then return 2
      -- (the message watcher is a window of its own)
      if _T(pTokens, pIdx[pAt + 1]) is "watcher" then return 0
      return 1
   end if
   if tWord is among the words of "window wd" and _T(pTokens, pIdx[pAt + 1]) is among the items of (quote & "message" & quote & comma & quote & "message box" & quote & comma & quote & "msg" & quote) then return 2
   return 0
end _MessageBoxRef

-- the P of the message box, in an expression (not after set, which
-- _SetMessageBox rewrites): hcMessageBox("P")
private function _MessageBoxProperties pLine
   local tTokens, tCode, tIdx, n, tItem, i, tChanged, tRef
   if "msg" is not in pLine and "message" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = n - 3 down to 1
      if _T(tTokens, tIdx[i]) is "the" and _T(tTokens, tIdx[i - 1]) is not "set" \
            and _T(tTokens, tIdx[i + 1]) is among the words of kMessageBoxProperties \
            and _T(tTokens, tIdx[i + 2]) is "of" then
         put _MessageBoxRef(tTokens, tIdx, i + 3) into tRef
         if tRef > 0 then
            _Replace tTokens, tIdx, i, i + 2 + tRef, "hcMessageBox(" & quote & _T(tTokens, tIdx[i + 1]) & quote & ")"
            _Fire "T28 message box properties"
            put true into tChanged
         end if
      end if
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _MessageBoxProperties

-- set [the] P of the message box to V: hcSetMessageBox "P", V
private function _SetMessageBox pTokens, pIdx, pAt, pEnd
   local j, tProperty, tRef
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   put _T(pTokens, pIdx[j]) into tProperty
   if tProperty is not among the words of kMessageBoxProperties or _T(pTokens, pIdx[j + 1]) is not "of" then return empty
   put _MessageBoxRef(pTokens, pIdx, j + 2) into tRef
   if tRef = 0 or _T(pTokens, pIdx[j + 2 + tRef]) is not "to" or j + 3 + tRef > pEnd then return empty
   _Fire "T28 message box properties"
   return "hcSetMessageBox" && quote & tProperty & quote & comma && _Span(pTokens, pIdx, j + 3 + tRef, pEnd)
end _SetMessageBox

-- T28: the properties of HyperCard's own windows ("the visible of tool
-- window", "set the visible of the variable watcher to true"), which
-- this engine does not have: what a script sets reads back
-- (hcWindowProperty and hcSetWindow in the library)
private function _HyperCardWindows pLine
   local tTokens, tCode, tIdx, n, tItem, i, j, k, tStart, tProperty, tName, tEnd
   if "window" is not in pLine and "watcher" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 2 to n - 2
      if _T(tTokens, tIdx[i]) is not "of" or tTokens[tIdx[i - 1]]["k"] is not "w" then next repeat
      put i + 1 into j
      if _T(tTokens, tIdx[j]) is "the" then add 1 to j
      put empty into tName
      if _T(tTokens, tIdx[j]) is among the words of "tool tools pattern patterns scroll fatbits navigator" and _T(tTokens, tIdx[j + 1]) is "window" then
         put _T(tTokens, tIdx[j]) into tName
      else if _T(tTokens, tIdx[j]) is among the words of "variable message" and _T(tTokens, tIdx[j + 1]) is "watcher" then
         put _T(tTokens, tIdx[j]) && "watcher" into tName
      end if
      if tName is empty then next repeat
      put j + 1 into k
      put _T(tTokens, tIdx[i - 1]) into tProperty
      put i - 1 into tStart
      if _T(tTokens, tIdx[tStart - 1]) is "the" then subtract 1 from tStart
      _Fire "T28 message box properties"
      if _T(tTokens, tIdx[tStart - 1]) is "set" and (tStart = 2 or _T(tTokens, tIdx[tStart - 2]) is among the words of "then else") \
            and _T(tTokens, tIdx[k + 1]) is "to" and k + 1 < n then
         put _FindWord(tTokens, tIdx, k + 2, n, "else", empty) into tEnd
         if tEnd is empty then
            put n into tEnd
         else
            subtract 1 from tEnd
         end if
         _Replace tTokens, tIdx, tStart - 1, tEnd, "hcSetWindow" && quote & tProperty & quote & comma && quote & tName & quote & comma && _HyperCardWindows(_Span(tTokens, tIdx, k + 2, tEnd))
         return _Join(tTokens)
      end if
      _Replace tTokens, tIdx, tStart, k, "hcWindowProperty(" & quote & tProperty & quote & comma && quote & tName & quote & ")"
   end repeat
   return _Join(tTokens)
end _HyperCardWindows

-- T29: HyperCard, the application, as an object: "the long name of
-- HyperCard" (its path, which scripts take apart for the folder of their
-- stacks), "the version of HyperCard"; here an object of that name is not
-- found. hcHyperCardName("long"), hcVersion(), hcLongVersion()
private function _HyperCardObject pLine
   local tTokens, tCode, tIdx, n, tItem, i, tChanged, tForm
   if "hypercard" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = n down to 4
      if _T(tTokens, tIdx[i]) is not "hypercard" or _T(tTokens, tIdx[i - 1]) is not "of" then next repeat
      if _T(tTokens, tIdx[i - 2]) is "name" then
         put empty into tForm
         if _T(tTokens, tIdx[i - 3]) is among the words of "long short abbr abbrev abbreviated" then put _T(tTokens, tIdx[i - 3]) into tForm
         if tForm is not empty and _T(tTokens, tIdx[i - 4]) is "the" then
            _Replace tTokens, tIdx, i - 4, i, "hcHyperCardName(" & quote & tForm & quote & ")"
         else if tForm is empty and _T(tTokens, tIdx[i - 3]) is "the" then
            _Replace tTokens, tIdx, i - 3, i, "hcHyperCardName(" & quote & quote & ")"
         else
            next repeat
         end if
      else if _T(tTokens, tIdx[i - 2]) is "version" then
         if _T(tTokens, tIdx[i - 3]) is "long" and _T(tTokens, tIdx[i - 4]) is "the" then
            _Replace tTokens, tIdx, i - 4, i, "hcLongVersion()"
         else if _T(tTokens, tIdx[i - 3]) is "the" then
            _Replace tTokens, tIdx, i - 3, i, "hcVersion()"
         else
            next repeat
         end if
      else
         next repeat
      end if
      _Fire "T29 HyperCard the application"
      put true into tChanged
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _HyperCardObject

-- The first code token from pFrom to pTo, outside parentheses, that is
-- pWord followed by one of pNext (empty for any), or empty
private function _FindWord pTokens, pIdx, pFrom, pTo, pWord, pNext
   local j, tDepth
   put 0 into tDepth
   repeat with j = pFrom to pTo
      if _T(pTokens, pIdx[j]) is "(" then add 1 to tDepth
      if _T(pTokens, pIdx[j]) is ")" then subtract 1 from tDepth
      if tDepth = 0 and _T(pTokens, pIdx[j]) is among the words of pWord \
            and (pNext is empty or _T(pTokens, pIdx[j + 1]) is among the words of pNext) then return j
   end repeat
   return empty
end _FindWord

-- T32: the rect of the card, which in HyperCard 2.2 resized the card
-- (here, the stack's window) and here cannot be set: the library's
-- hcSetCardRect; and a text style of HyperCard's that this engine does
-- not have (outline, shadow, condense, extend, group), which here stops
-- the script: the style through the library's hcTextStyle, which gives
-- this engine's names for condense, extend and group and leaves out
-- outline and shadow
private function _SetCardAndStyle pTokens, pIdx, pAt, pEnd
   local j, k, tProperty, tTo, tObject, tValue, tNeeded, tWord
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   put _T(pTokens, pIdx[j]) into tProperty
   if _T(pTokens, pIdx[j + 1]) is not "of" then return empty
   put _FindWord(pTokens, pIdx, j + 2, pEnd, "to", empty) into tTo
   if tTo is empty or tTo = pEnd then return empty
   if tProperty is among the words of "rect rectangle" then
      put _Lower(_Span(pTokens, pIdx, j + 2, tTo - 1)) into tObject
      if tObject is not among the items of "card,cd,this card,this cd" then return empty
      _Fire "T32 card size and text styles"
      return "hcSetCardRect" && _Span(pTokens, pIdx, tTo + 1, pEnd)
   end if
   if tProperty is not "textstyle" then return empty
   put false into tNeeded
   repeat with k = tTo + 1 to pEnd
      put _Lower(pTokens[pIdx[k]]["t"]) into tValue
      replace quote with space in tValue
      replace comma with space in tValue
      repeat for each word tWord in tValue
         if tWord is among the words of "outline shadow condense extend group" then put true into tNeeded
      end repeat
   end repeat
   put empty into tValue
   if not tNeeded then return empty
   repeat with k = pIdx[tTo + 1] to pIdx[pEnd]
      if pTokens[k]["k"] is "w" and _Lower(pTokens[k]["t"]) is "group" then
         put quote & pTokens[k]["t"] & quote after tValue
      else
         put pTokens[k]["t"] after tValue
      end if
   end repeat
   _Fire "T32 card size and text styles"
   return _Span(pTokens, pIdx, pAt, tTo) && "hcTextStyle(" & tValue & ")"
end _SetCardAndStyle

-- T26: the properties of HyperCard's picture and palette windows, and of
-- the card window, which this engine's windows (stacks) do not have: set
-- [the] P of window W to V, set [the] P of card window to V: hcSetWindow
-- "P", W, V ("card window" for the card window, as for "this stack")
private function _SetWindow pTokens, pIdx, pAt, pEnd
   local j, tProperty, tTo, tWindow
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   put _T(pTokens, pIdx[j]) into tProperty
   if tProperty is not among the words of kWindowProperties or _T(pTokens, pIdx[j + 1]) is not "of" then return empty
   put _FindWord(pTokens, pIdx, j + 2, pEnd, "to", empty) into tTo
   if tTo is empty or tTo = pEnd then return empty
   if _T(pTokens, pIdx[j + 2]) is among the words of "window wd" and j + 3 < tTo then
      put _Span(pTokens, pIdx, j + 3, tTo - 1) into tWindow
   else if _T(pTokens, pIdx[j + 2]) is among the words of "card cd" and _T(pTokens, pIdx[j + 3]) is among the words of "window wd" and j + 4 = tTo then
      put quote & "card window" & quote into tWindow
   else if _T(pTokens, pIdx[j + 2]) is "this" and _T(pTokens, pIdx[j + 3]) is "stack" and j + 4 = tTo and tProperty is "scroll" then
      put quote & "card window" & quote into tWindow
   else
      return empty
   end if
   _Fire "T26 window properties"
   return "hcSetWindow" && quote & tProperty & quote & comma && tWindow & comma && _Span(pTokens, pIdx, tTo + 1, pEnd)
end _SetWindow

-- set [the] P of menuItem I of menu M to V, set [the] P of menu M to V:
-- hcSetMenuItem "P", M, I, V
private function _SetMenuItem pTokens, pIdx, pAt, pEnd
   local j, tProperty, tMenu, tTo, tItem
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   put _T(pTokens, pIdx[j]) into tProperty
   if tProperty is not among the words of kMenuProperties or _T(pTokens, pIdx[j + 1]) is not "of" then return empty
   put _FindWord(pTokens, pIdx, j + 2, pEnd, "to", empty) into tTo
   if tTo is empty or tTo = pEnd then return empty
   if _T(pTokens, pIdx[j + 2]) is "menuitem" then
      put _FindWord(pTokens, pIdx, j + 3, tTo, "of", "menu") into tMenu
      if tMenu is empty or tMenu = j + 3 or tMenu + 2 > tTo - 1 then return empty
      put _Span(pTokens, pIdx, j + 3, tMenu - 1) into tItem
      add 2 to tMenu
   else if _T(pTokens, pIdx[j + 2]) is "menu" and j + 3 < tTo then
      put "empty" into tItem
      put j + 3 into tMenu
   else
      return empty
   end if
   _Fire "T22 HyperCard menus"
   return "hcSetMenuItem" && quote & tProperty & quote & comma && _Span(pTokens, pIdx, tMenu, tTo - 1) & comma && tItem & comma && _Span(pTokens, pIdx, tTo + 1, pEnd)
end _SetMenuItem

-- put E into (after, before) menu M [with menuMsg(s) X], put E into
-- menuItem I of menu M: hcPutIntoMenu E, "into", M, X, I
private function _PutIntoMenu pTokens, pIdx, pAt, pEnd
   local tPrep, tWith, tMenu, tItem, tMessages
   put _FindWord(pTokens, pIdx, pAt + 2, pEnd, "into after before", "menu menuitem") into tPrep
   if tPrep is empty or tPrep + 2 > pEnd then return empty
   put "empty" into tMessages
   put "empty" into tItem
   -- with menuMsgs X, after the menu or the item
   put _FindWord(pTokens, pIdx, tPrep + 2, pEnd, "with", "menumsg menumsgs menumessage menumessages") into tWith
   if tWith is not empty then
      if tWith + 2 > pEnd or tWith = tPrep + 2 then return empty
      put _Span(pTokens, pIdx, tWith + 2, pEnd) into tMessages
      put tWith - 1 into pEnd
   end if
   if _T(pTokens, pIdx[tPrep + 1]) is "menuitem" then
      put _FindWord(pTokens, pIdx, tPrep + 2, pEnd, "of", "menu") into tMenu
      if tMenu is empty or tMenu = tPrep + 2 or tMenu + 2 > pEnd then return empty
      put _Span(pTokens, pIdx, tPrep + 2, tMenu - 1) into tItem
      put _Span(pTokens, pIdx, tMenu + 2, pEnd) into tMenu
   else
      put _Span(pTokens, pIdx, tPrep + 2, pEnd) into tMenu
   end if
   _Fire "T22 HyperCard menus"
   return "hcPutIntoMenu" && _Span(pTokens, pIdx, pAt + 1, tPrep - 1) & comma && quote & _T(pTokens, pIdx[tPrep]) & quote & comma && tMenu & comma && tMessages & comma && tItem
end _PutIntoMenu

-- enable and disable menu M, menuItem I of menu M; create menu M; delete
-- menu M, menuItem I of menu M
private function _MenuCommand pTokens, pIdx, pAt, pEnd
   local tVerb, tMenu, tItem
   put _T(pTokens, pIdx[pAt]) into tVerb
   if pAt + 2 > pEnd then return empty
   if _T(pTokens, pIdx[pAt + 1]) is "menu" then
      put _Span(pTokens, pIdx, pAt + 2, pEnd) into tMenu
      put "empty" into tItem
   else if _T(pTokens, pIdx[pAt + 1]) is "menuitem" and tVerb is not "create" then
      put _FindWord(pTokens, pIdx, pAt + 2, pEnd, "of", "menu") into tMenu
      if tMenu is empty and tVerb is "delete" then put _FindWord(pTokens, pIdx, pAt + 2, pEnd, "from", "menu") into tMenu
      if tMenu is empty or tMenu = pAt + 2 or tMenu + 2 > pEnd then return empty
      put _Span(pTokens, pIdx, pAt + 2, tMenu - 1) into tItem
      put _Span(pTokens, pIdx, tMenu + 2, pEnd) into tMenu
   else
      return empty
   end if
   _Fire "T22 HyperCard menus"
   switch tVerb
      case "enable"
      case "disable"
         return "hcEnableMenu" && (tVerb is "enable") & comma && tMenu & comma && tItem
      case "create"
         return "hcCreateMenu" && tMenu
      case "delete"
         if tItem is "empty" then return "hcDeleteMenu" && tMenu
         return "hcDeleteMenuItem" && tMenu & comma && tItem
   end switch
   return empty
end _MenuCommand

-- T17: set the cursor to HyperCard's cursor numbers (1 to 4), names, and
-- the stack's own cursors (CURS resources, imported as the images of the
-- group "HC cursors"), which this engine refuses: the library's hcCursor()
-- gives this engine's number for each
private function _SetCursor pTokens, pIdx, pAt, pEnd
   local j
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   if _T(pTokens, pIdx[j]) is not "cursor" or _T(pTokens, pIdx[j + 1]) is not "to" or j + 2 > pEnd then return empty
   if _T(pTokens, pIdx[j + 2]) is "hccursor" then return empty
   _Fire "T17 cursor"
   return "set the cursor to hcCursor(" & _PlainName(pTokens, pIdx, j + 2, pEnd, false) & ")"
end _SetCursor

-- T19: show and hide card picture, background picture (which this engine
-- reads as a card named "picture"); T21: show, hide and close window,
-- and HyperCard's own windows (the scroll window, the tool window...),
-- which are not stacks here
private function _ShowHide pTokens, pIdx, pAt, pEnd
   local j, tVerb, tWhich, tShow, tLast
   put _T(pTokens, pIdx[pAt]) into tVerb
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   if tVerb is not "close" and _T(pTokens, pIdx[j]) is among the words of "card cd background bkgnd bg" \
         and _T(pTokens, pIdx[j + 1]) is among the words of "picture pict" then
      put "card" into tWhich
      if _T(pTokens, pIdx[j]) is not among the words of "card cd" then put "background" into tWhich
      put (tVerb is "show") into tShow
      _Fire "T19 card and background picture"
      if j + 1 = pEnd then return "hcShowPicture" && quote & tWhich & quote & comma && tShow
      if _T(pTokens, pIdx[j + 2]) is not "of" or j + 2 = pEnd then return empty
      return "hcShowPicture" && quote & tWhich & quote & comma && tShow & comma && "the long id of" && _Span(pTokens, pIdx, j + 3, pEnd)
   end if
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "window" and j < pEnd then
      put _ExpressionEnd(pTokens, pIdx, j + 1, pEnd, "at") into tLast
      _Fire "T21 windows"
      if tLast = pEnd then return "hcWindow" && quote & tVerb & quote & comma && _PlainName(pTokens, pIdx, j + 1, pEnd, false)
      if tLast + 1 = pEnd then return empty
      return "hcWindow" && quote & tVerb & quote & comma && _PlainName(pTokens, pIdx, j + 1, tLast, false) & comma && _Span(pTokens, pIdx, tLast + 2, pEnd)
   end if
   if _T(pTokens, pIdx[j]) is among the words of "tool tools pattern patterns scroll fatbits navigator" \
         and _T(pTokens, pIdx[j + 1]) is "window" and j + 1 = pEnd then
      _Fire "T21 windows"
      return "hcWindow" && quote & tVerb & quote & comma && quote & _T(pTokens, pIdx[j]) & quote
   end if
   return empty
end _ShowHide

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
