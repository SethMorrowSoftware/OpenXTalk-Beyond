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
--    and keeps those that compile ("salvage"). Of a handler that does
--    not, it keeps every line that compiles, the lines that do not left
--    out as comments (T39: HyperCard ran a handler until it reached a
--    line it could not do, and many lines this engine cannot compile are
--    ones HyperCard did); a handler that still does not compile is put
--    in place of by one of the same name that passes its message on,
--    with the HyperTalk commented out inside it.
--
-- Scripts that compile are rewritten only where they do something else
-- here than in HyperCard. In a stack imported without HyperCard's
-- message order (its hyperTalkCompatible false), where no handler can be
-- called doMenu, an "on doMenu" handler is renamed hcDoMenu and every
-- "doMenu" command becomes "hcDoMenu", so that the stack's handler sees
-- the menu choices its own scripts make, and the library does what
-- HyperCard's menu items did (T15). With HyperCard's message order,
-- doMenu is a message and keeps its name: the stack's handlers see it,
-- and the library's do the item. And in every script, the statements
-- that stop with an error here where HyperCard went on, or do something
-- else, go to the library (T9 "go home", T16 "go" to a stack, T17 the
-- cursor, T18 the key commands, "picture" and "help", T19 "show
-- card picture", T20 "fileName(", T21 "show", "hide" and "close window",
-- T22 HyperCard 2.2's menus, T23 "start using" and "stop using" a stack,
-- T24 "print" a field, T25 "go" to a destination given by an expression,
-- T26 the properties of picture and palette windows, T27 "doMenu" with
-- the item's name not in quotes, T28 the properties of the message box,
-- T29 HyperCard the application: its name and version, send to it, T30
-- "choose tool" by HyperCard's number or by a name in a variable, T32 the
-- card's rect and HyperCard's text styles, T40 "open" an application or
-- a document with one, which this engine takes for a "go", and HyperCard
-- 2.4's "open url", T41 a menu message that is a statement, which
-- HyperCard sent as it was written ("with menuMsg go to card id 90024"),
-- or a list of messages). T33, in scripts that do not
-- compile, takes more forms HyperCard took: an answer's replies not in
-- quotes, "convert" of an expression, functions written without "the",
-- "go to card 1 of home", and names of several words not in quotes
-- after a cursor, a window or a "go". T34 takes the next forms by
-- reach in the corpus sweep: an external's arguments not in quotes that
-- are no value here ("ink on, 8"), an answer's replies over several
-- lines, "select """, "repeat with i is 1 to n", "sort the lines of",
-- "the number of windows", a field as a chunk's number ("line bg fld
-- "N" of bg fld "List""), "to the length of fld x of fld x", "reset
-- menubar" after "then", "unlock screen with visual ... to cd", and the
-- long date, the short target and the number of items in it in a
-- handler with a variable of that name. T36 takes doMenu's menu name and
-- "without dialog" ("doMenu "Paste Card", "Edit" without dialog"). T37
-- takes the next forms by reach in the sweep of 2026-10-25: a word this
-- engine refuses as a value where HyperCard took it as its own text (an
-- argument of a handler of the stack, of a command this engine does not
-- have or of picture, "ResetBtns on", "timeStamp scrollBar", "picture
-- "Chart", clipboard, zoom"; a side of a comparison, "if it = No", "if
-- x <> No"; what put puts, "put in into meas"), a variable named like a
-- word this engine's answer, ask or put takes first ("answer info", "put
-- header into x"), a comma that ends a command's arguments, "the number
-- of marked card i", a count without "the" ("card field number of card
-- fields", "line number of lines of t - 1 of t"), a card "in this bg",
-- "go cd" and "mark card" alone, palette after then, and "if ... then
-- ... else" at the end of a line, or "if ... then ..." with else alone
-- on the next line, which began an else of several lines. T38 takes
-- "exit" and "pass" with the name of another handler than their own
-- ("exit saveToDisk" in a handler called createText): the handler's own
-- name; and "global" with names in quotes or nothing between two commas
-- ("global "Mapper"", "global a, , b,"). T39 is the salvage of the lines
-- of a handler, in step 2. T42 takes "do" with a statement not in quotes
-- ("do go cd id 13086"), which HyperCard ran as the statement it was:
-- in quotes, where the probe finds it is no expression and compiles as
-- a statement (in a script that compiles too, where such a do runs its
-- first word alone). T43 takes a "go" to a card of a stack named
-- without the word "stack" after a background ("go last cd of bg
-- "stocks" of stackName") or after "in" ("go to card "Help" in "Mailing
-- List Maker""), as T31 does after a card; and a "go" to a background of
-- a stack, which this engine does not go to: its first card. T44 puts in
-- quotes an object's name, or a send's message, that this engine reads
-- as one of its constants ("show cd fld help", field 15 here; "send help
-- to card"), in a script that compiles too.
-- T45 takes HyperCard's Home stack named but not gone to ("set the script
-- of stack "Home" to tScript"), which here is the IDE's stack "home", to
-- the library's hcHome(), in a script that compiles too. T46 takes
-- HyperCard's windows, in a script that compiles too: where a window is,
-- which HyperCard gave by its top left, on the screen for a card window
-- ("set the loc of card window to 0,20") and from the card window's top
-- left for every other (the message box, a palette, a picture: "the loc
-- of window "Tools Palette"", "show msg at 15,300"), and this engine by
-- a stack's centre on the screen; a property of the card window
-- without "the" and followed by a sum ("item 1 of loc of card window
-- +191"), which this engine takes for a card of a stack named by the sum
-- and stops at; "show" and "hide card window", which
-- this engine does nothing for; HyperCard's own windows named in quotes
-- ("the visible of window "Scroll"") and the watchers shown and hidden
-- ("show variable watcher"); and the message box's properties without
-- "the" ("if visible of msg"). T47 takes a function called by a name
-- that is one of this engine's commands ("put replace(":", ",", t) into
-- t", "get sort(fld 1, "n")"), which compiles here and stops at the call
-- as no handler: the stack's own function of that name, as T1 renamed
-- it, else the library's stand-in for the external of that name
-- (hcX_Replace, hcX_Sort, hcX_Find), in a script that compiles too.
-- T48 takes HyperCard's menus read as values ("put menu "Font" into
-- tFonts", "the number of menuItems in menu "File"", "if last menuItem
-- of menu 3 is "-"", "there is a menu "Art Bits"", "the menus"), which
-- here read the IDE's menu bar, or stop with "can't find background"
-- where there is none: the library's menus, which T22's statements
-- change, in a script that compiles too. T49 takes "play" with a sound
-- named in a field or a button of the card or the background ("play card
-- field "sound"", "play cd fld x tempo 200 tNotes"), which this engine
-- reads as a player's "card" ("play card player "Movie"") and a field
-- found without it, one of the background in a stack from HyperCard:
-- the field in parentheses, its text, in a script that compiles too.
-- T50 takes a property of an object named by a chunk of a variable or of
-- a function's value ("the textHeight of item 1 of fieldList", "scroll of
-- last item of theFields()", from Power Tools' buttons that scroll
-- several fields together): HyperCard took the object the chunk's text
-- names, and this engine the object the whole text names, with the chunk
-- as text of it, and stops with an error. The chunk goes in
-- parentheses, in a script that compiles too. T51 takes a textFont set to
-- a font named in several words not in quotes ("set the textFont to New
-- York", "set textfont of me to new century schlbk"), which HyperCard
-- took as the text it was, and this engine as its first word, running
-- the rest as a command it cannot find: the name in quotes. T52 takes
-- the showPict of a card or a background ("if the showPict of this cd
-- then", "set showpict of card "author" to false"), which this engine
-- reads as true whatever the card shows and sets to nothing, and the
-- picture of a card or a background it names ("hide picture of card
-- "FX"", "show pict of this cd"), which stops with an error here: the
-- library's hcShowPict and hcShowPicture, which read and set whether
-- the picture T19 shows and hides is shown. T53 takes the textStyle and
-- the textAlign set with no object ("set textstyle to plain", "set the
-- textAlign to center"), HyperCard's style and alignment for the text
-- its text tool painted, which this engine cannot set and stops at: the
-- library's hcSetPaintText, which does nothing, as this engine's own
-- textFont, textSize and textHeight set so do. T54 takes the cards of a
-- background sorted ("sort cards of this bg by field "Name"", "sort
-- bkgnd "Data" numeric by ..."), which this engine refuses, and "sort
-- this stack", which is its "sort cards": the background's cards are
-- marked, sorted as marked cards and put back in the places they had
-- (the library's hcSortBegin and hcSortEnd; after "then" or "else", a
-- do of the three statements). T55 takes the version of a stack ("item 4
-- of the version of this stack"), which this engine takes for its own
-- version followed by "of": a script with one does not compile, and "get
-- the version of this stack" stops ("source is not a container"): the
-- library's hcStackVersion. T22 takes a menu or a menu item named by one
-- word that this engine does not take as a value ("create menu Control",
-- an object type here) as that word in quotes, the name HyperCard took.
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

-- The words a statement can start with here that are not a command a
-- handler could be (T37: _UnknownCommand)
constant kNotCommands = "else end case default catch finally then on function command private before after getprop setprop constant local global"

-- HyperTalk's own commands: an external of one of these names is never
-- what a call to it means
constant kHyperTalkCommands = "add answer arrowkey ask beep choose click close convert create debug delete dial disable divide domenu drag edit enable enterinfield enterkey export find flash functionkey get go help hide import lock mark multiply open palette picture play pop print push put read reply request reset returninfield returnkey save select send set show sort start stop subtract tabkey type unlock unmark visual wait write"

-- The externals named like commands of this engine that the library
-- stands in for, as hcX_<name>: called as functions ("replace(", T47)
constant kCommandExternals = "replace sort find"

-- The words a visual effect is made of here (engine/src/lextable.cpp)
constant kVisualWords = "barn black blinds bottom card center checkerboard close curl dissolve door down effect fast flip from gray grey in inverse iris left normal open option out plain push reveal right scroll shrink slow slowly sound stretch to top up venetian very white wipe with zoom visual"

-- HyperTalk's object words
constant kObjectWords = "field fld button btn card cd background bkgnd bg stack window"

-- Functions HyperTalk let a script write without "the", as "length of x"
constant kOneArgFunctions = "length random abs atan chartonum cos exp exp1 exp2 ln ln1 log2 numtochar round sin sqrt tan trunc value"

-- Variables' names this engine refuses that HyperTalk had no function or
-- property of, before "of" too (T2): "char stop to stop + len of field
-- "Text"" (Jargon), "character charNo + offset of field "Decoded Text""
-- (Cipher), where HyperCard's offset took two values in parentheses
constant kOfVariables = "len offset"

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

-- The name of the library's behavior in a stack with HyperCard's message
-- order (_AddMenus)
constant kMenusName = "HyperCard Menus"

-- The properties of a menu and a menu item in HyperCard 2.2's menus
constant kMenuProperties = "checkmark commandchar cmdchar enabled markchar name textstyle menumessage menumsg"
-- The words that name a menu item by its place ("last menuItem of menu 3"),
-- which the library's menus read (_HCMenuItemNumber)
constant kMenuOrdinals = "first second third fourth fifth sixth seventh eighth ninth tenth last middle"
-- Words that are no menu's or menu item's name after "menu" or
-- "menuItem" (T48: "go to card menu at 2", "menu of", a chunk)
constant kMenuNotNames = "the then else and or not is are into after before of in from to with without at by as for contains div mod a an no there menu menus menuitem menuitems line lines item items word words char chars character characters field fld button btn card cd background bkgnd bg stack window"
-- Words a menu item's name of several words cannot have (T48: "there is
-- a menuItem item x of fontList in menu "Font"")
constant kMenuItemStops = "then else into after before is are and or not contains menu menuitem"

-- The properties of HyperCard's picture and palette windows that this
-- engine's windows do not have (T26)
constant kWindowProperties = "scale scroll hilitedbutton zoom dithering globalloc globalrect"

-- The properties of the message box that scripts read and set (T28)
constant kMessageBoxProperties = "visible loc location rect rectangle top left bottom right width height topleft bottomright textfont textsize textstyle textalign"

-- HyperCard's properties of the text its text tool painted, set and read
-- with no object ("set textSize to 9", "the textHeight div 2"), by the
-- names the library's hcSetPaintText and hcPaintText take (T53)
constant kPaintText = "textFont textSize textHeight textStyle textAlign"

-- HyperCard's properties of the text that "print" of an expression
-- printed in ("set the printTextFont to "Courier"", "put the
-- printTextFont into savedPrintFont"), by the names the library's
-- hcSetPrintText and hcPrintText take (T72)
constant kPrintText = "printTextFont printTextSize printTextHeight printTextStyle printTextAlign"

-- HyperCard's global properties that this engine has not, which it
-- refuses to read or set ("set the dialingTime to 600"), by the names the
-- library's hcProperty and hcSetProperty take (T64)
constant kHyperCardProperties = "dialingTime dialingVolume language messageWatcher variableWatcher scriptEditor debugger"

-- HyperCard's own windows by the names scripts gave them in quotes
-- ("the visible of window "Scroll""), which are no stacks here (T46);
-- the library's kHCOwnWindows
constant kHCOwnWindows = "tool,tools,pattern,patterns,scroll,fatbits,navigator,variable watcher,message watcher"

-- A window's place, which HyperCard gave from the card window's top left
-- for every window but a card window (T46; the library's kHCPlaces, and
-- the globalLoc and globalRect, its place on the screen)
constant kWindowPlaces = "loc location rect rectangle topleft bottomright top left bottom right globalloc globalrect"

-- the words a "go" names its destination with, as against an expression
-- whose value is the destination (T25)
constant kGoPlaces = "card cd cards background bkgnd bg backgrounds stack stacks this next prev previous first last back forth home help recent any middle mid second third fourth fifth sixth seventh eighth ninth tenth marked id window url"

-- The words that name a background, and the ordinals a "go" names one by
-- ("go next bkgnd", T69)
constant kBackgroundWords = "background bkgnd bg"
constant kBackgroundOrdinals = "this next prev previous first second third fourth fifth sixth seventh eighth ninth tenth last middle mid any"

-- The words after "open" that say what this engine opens
-- (engine/src/lextable.cpp's open_table, and the words before it), and
-- HyperCard's "open report printing" (T12): an "open" of anything else
-- is HyperCard's of an application (T40)
constant kOpenWords = "directory driver file folder printing process socket standarderror standardinput standardoutput stderr stdin stdout secure datagram elevated report"

-- This engine's constants that HyperCard did not have, each with a value
-- other than its name (engine/src/lextable.cpp's constant_table: "help"
-- is 15, the help cursor's number): an object named by one of them not
-- in quotes is another object here (T44)
constant kEngineConstants = "arrow busy clock cross hand help ibeam none plus watch backslash cr crlf end endoffile eof infinity lf null scrollbarfactor slash"

-- HyperCard's properties of its objects, and not of text: one of an object
-- named by a chunk of a variable ("the textHeight of item 1 of fieldList")
-- is the object's that text names (T50). Not textFont, textSize and
-- textStyle, which HyperCard 2 had for a chunk of a field too, nor
-- number, which counts ("the number of items of x")
constant kChunkObjectProperties = "autohilite autoselect autotab botright bottom bottomright cantabort cantdelete cantmodify cantpeek dontsearch dontwrap enabled family fixedlineheight freesize height hilite highlight hilight icon id left loc location locktext marked multiplelines name partnumber rect rectangle right script scroll sharedhilite sharedtext showlines showname showpict style textalign textheight titlewidth top topleft visible widemargins width"

-- The chunks of text, and their ordinals ("last item of x"), T50
constant kChunkWords = "item line word char character"
constant kChunkOrdinals = "first second third fourth fifth sixth seventh eighth ninth tenth last middle any"

-- What the probes found: a name's verdict, so that each name is compiled
-- once (keys are the name in lower case)
local sVariableRefused
local sHandlerRefused
local sNameRefused
local sParameterRefused
local sWindowPropertyRefused
local sCallRefused, sCallCompiles
local sValueRefused

-- The object probes compile on, and the stack being fixed
local sProbe
local sStack

-- Whether the stack being fixed has HyperCard's message order (its
-- hyperTalkCompatible, which File > Import Stack sets before its scripts
-- are fixed): a handler can be called doMenu there, and doMenu is a
-- message that reaches the stack's handlers, then the library's
local sHyperTalk

-- The stack's own handlers a statement can call by name (lower case,
-- true), for _ExternalArguments (T37)
local sCallees

-- The stack's externals (lower case, true), for _ExternalArguments in a
-- script that compiles (_HyperCardRules, T37)
local sExternals

-- The stack's own functions (lower case, true), and the handlers renamed
-- because this engine refuses their names (lower case, the new name), for
-- T47 and T13
local sStackFunctions, sRenameHandlers

-- T62: the objects that define each of the stack's functions (by name,
-- then by _PathId, true), and those on the message path of every call
-- the script being fixed makes (by _PathId, true: _AlwaysOnPath)
local sFunctionDefiners, sReached

-- Each rule's count for the object being fixed, and for the whole stack
local sFired
local sFiredTotal

-- How many handlers, and how many of their lines, the last _Salvage left
-- out
local sLeftOut, sLinesLeftOut

-- The handlers the last revHyperCardFixScripts left out, for
-- revHyperCardLeftOutHandlers, the lines it left out of handlers, for
-- revHyperCardLeftOutLines, and the object whose script it is fixing
local sLeftOutLog, sLinesLeftOutLog, sObject, sLeftOutStack

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
   local tChanged, tSalvaged, tStubs, tLinesOut, tStill, tWasLocked, tLine, tSummary, tStandIns

   if word 1 of pStack is "stack" and exists(pStack) then
      put the long id of pStack into sStack
   else if there is a stack pStack then
      put the long id of stack pStack into sStack
   else
      return "no such stack:" && pStack for error
   end if
   put _HyperTalkOrder(sStack) into sHyperTalk
   put the lockMessages into tWasLocked
   lock messages

   put _Objects(sStack) into tObjects
   -- First pass: the handlers the stack defines (for the renamed ones, a
   -- call anywhere in the stack is renamed too), which of them are
   -- functions (and where, T62), and its externals
   put empty into sStackFunctions
   put empty into sFunctionDefiners
   repeat for each line tObject in tObjects
      repeat for each line tLine in the script of tObject
         if word 1 of tLine is among the items of "on,function" then
            put true into tDefines[_Lower(_Word2(tLine))]
            if word 1 of tLine is "function" then
               put true into sStackFunctions[_Lower(_Word2(tLine))]
               put true into sFunctionDefiners[_Lower(_Word2(tLine))][_PathId(tObject)]
            end if
         end if
      end repeat
   end repeat
   put _Externals(sStack) into tExternals
   put empty into sLeftOutLog
   put empty into sLinesLeftOutLog
   put sStack into sLeftOutStack

   _MakeProbe
   put empty into sFiredTotal
   put 0 into tChanged
   put 0 into tSalvaged
   put 0 into tStubs
   put 0 into tLinesOut
   put 0 into tStill
   repeat for each line tObject in tObjects
      local tOriginal, tNew, tNote, tCompiled
      put the script of tObject into tOriginal
      if tOriginal is empty then next repeat
      put _Compiles(tOriginal) into tCompiled
      put tObject into sObject
      put _AlwaysOnPath(tObject) into sReached
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
         add sLinesLeftOut to tLinesOut
         put "salvaged handler by handler," && tStubCount && "left out" into tNote
         if sLinesLeftOut > 0 then put "," && sLinesLeftOut && _Plural(sLinesLeftOut, "line") && "left out of handlers" after tNote
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
   put _QuietPalettes(sStack) into tLine
   if tLine is not empty then put tLine & return after tReport

   put "HyperCard scripts:" && tChanged && "rewritten," && tSalvaged && "salvaged by handler (" & tStubs && "handlers left out," && tLinesOut && "lines left out of handlers)," && tStill && "still do not compile" into tSummary
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

pHyperTalk (Boolean): Whether the script is for a stack with HyperCard's
message order, its hyperTalkCompatible true (optional; false when left
out), where doMenu keeps its name.

Returns (String): The rewritten script.
*/
function revHyperCardRewriteScript pScript, pExternals, pHyperTalk
   local tExternals, tLine
   repeat for each line tLine in pExternals
      if tLine is not empty then put true into tExternals[_Lower(tLine)]
   end repeat
   put pHyperTalk is true into sHyperTalk
   put empty into sFired
   put empty into sStackFunctions
   put empty into sFunctionDefiners
   put empty into sObject
   return _Rewrite(pScript, empty, tExternals, false)
end revHyperCardRewriteScript

/*
Gives an imported HyperCard stack HyperCard's look: white paper and
black ink, and its buttons and fields drawn flat in black and white
rather than in this platform's 3D look.

pStack (String): The imported stack.

Description:
File > Import Stack does this for a new import unless the preference
cHyperCardClassicLook is false, and the web Stack Player does it for
every HyperCard stack it opens. It sets the stack's colours (the cards
and controls that set none of their own take them), turns off the 3D
borders of its buttons and fields, and draws HyperCard's standard and
default buttons, which this engine would draw as the platform's push
buttons, as round rectangles. Check boxes, radio buttons and popups
keep the platform's look. The stack's uHyperCard["classic"] is set to
true, so it is not done twice. Only properties are set: nothing a script
reads changes but the colours, the threeD and the style of a standard
button.
*/
command revHyperCardClassicLook pStack
   local tObject, tStyle
   if word 1 of pStack is not "stack" then put the long id of stack pStack into pStack
   if the uHyperCard["classic"] of pStack is true then return empty
   lock screen
   set the backgroundColor of pStack to "white"
   set the foregroundColor of pStack to "black"
   set the borderColor of pStack to "black"
   set the shadowColor of pStack to "black"
   repeat for each line tObject in _Objects(pStack)
      switch word 1 of tObject
         case "button"
            put the style of tObject into tStyle
            if tStyle is among the words of "standard default" then
               set the style of tObject to "roundrect"
               put "roundrect" into tStyle
            end if
            if tStyle is among the words of "rectangle roundrect shadow transparent opaque" then
               set the threeD of tObject to false
            end if
            break
         case "field"
            set the threeD of tObject to false
            break
      end switch
   end repeat
   set the uHyperCard["classic"] of pStack to true
   unlock screen
   return empty
end revHyperCardClassicLook

/*
A summary of a HyperCard import for a person, a screenful at most: what
came in, what was converted, and what is missing and why, each with
where to look. File > Import Stack shows it after an import.

pStack (String): The imported stack, after <revHyperCardFixScripts>.

pImportLog (String): The engine's import log, the hcImportStat (optional;
the hcImportStat when left out).

Returns (String): The summary, as lines of text.
*/
function revHyperCardImportSummary pStack, pImportLog
   local tOut, tReport, tLine, tCount, tLeft, i, tNames, tType, tName, tLibrary, tDefines
   local tSounds, tMace, tTypes, tKind, tPicts, tFonts, tFont, tObject, tKey, tConverted

   if word 1 of pStack is not "stack" then put the long id of stack pStack into pStack
   if pImportLog is empty then put the hcImportStat into pImportLog

   put the short name of pStack & ":" && the number of cards of pStack && "cards," \
         && the number of backgrounds of pStack && "backgrounds" & return into tOut

   -- the scripts
   put the uHyperCard["scripts"] of pStack into tReport
   put the last line of tReport into tLine
   if tLine begins with "HyperCard scripts:" then
      put word 3 of tLine into tCount
      if tCount is an integer and tCount > 0 then
         put return & "Scripts: " & tCount && "rewritten to run here. Each keeps its HyperTalk in its object's uHyperCard[" & quote & "script" & quote & "]." & return after tOut
      end if
   end if
   put revHyperCardLeftOutHandlers() into tLeft
   if the number of elements of tLeft > 0 and sLeftOutStack is pStack then
      put return & "Left out:" && the number of elements of tLeft && _Plural(the number of elements of tLeft, "handler") && "still" \
            && _Plural(the number of elements of tLeft, "does", "do") && "not compile here, kept commented out in a handler that passes its message:" & return after tOut
      repeat with i = 1 to min(12, the number of elements of tLeft)
         put "   " & tLeft[i]["name"] && "in" && _ShortObject(tLeft[i]["object"]) & return after tOut
      end repeat
      if the number of elements of tLeft > 12 then put "   and" && the number of elements of tLeft - 12 && "more" & return after tOut
   end if
   put revHyperCardLeftOutLines() into tLeft
   if the number of elements of tLeft > 0 and sLeftOutStack is pStack then
      put return & "Lines left out:" && the number of elements of tLeft && _Plural(the number of elements of tLeft, "line") && "of handlers" \
            && _Plural(the number of elements of tLeft, "does", "do") && "not compile here, each kept as a comment: its handler goes on past it," \
            && "or stops there with an error at a return, exit or pass, or inside a loop that might not end without it:" & return after tOut
      repeat with i = 1 to min(8, the number of elements of tLeft)
         put "   " & tLeft[i]["name"] && "in" && _ShortObject(tLeft[i]["object"]) & ":" && tLeft[i]["text"] & return after tOut
      end repeat
      if the number of elements of tLeft > 8 then put "   and" && the number of elements of tLeft - 8 && "more" & return after tOut
   end if

   -- the externals: the XCMDs got stand-ins; the XFCNs the library
   -- does not have stop a script that calls them
   repeat for each line tLine in revHyperCardLibraryScript()
      if word 1 of tLine is among the words of "on function command" then put true into tLibrary[_Lower(word 2 of tLine)]
   end repeat
   repeat for each line tObject in _Objects(pStack)
      repeat for each line tLine in the script of tObject
         if word 1 of tLine is among the items of "on,function" then put true into tDefines[_Lower(_Word2(tLine))]
      end repeat
   end repeat
   set the itemDelimiter to tab
   put empty into tNames
   repeat for each line tLine in the uHyperCard["externals"] of pStack
      put word 1 to -1 of item 1 of tLine into tType
      put word 1 to -1 of item 2 of tLine into tName
      if tType is not "XFCN" or tName is empty then next repeat
      if tLibrary[_Lower(tName)] or tLibrary["hcx_" & _Lower(tName)] or tDefines[_Lower(tName)] then next repeat
      if tName is among the items of tNames then next repeat
      if tNames is not empty then put ", " after tNames
      put tName after tNames
   end repeat
   set the itemDelimiter to colon
   repeat for each line tLine in tReport
      if tLine begins with "Stand-ins:" then
         put return & "XCMDs that do nothing here:" && word 1 to -1 of item -1 of tLine & return after tOut
      end if
   end repeat
   set the itemDelimiter to comma
   if tNames is not empty then
      put return & "XFCNs that are not available (a script stops where it calls one):" && tNames & return after tOut
   end if

   -- what the engine could not convert
   put 0 into tSounds
   put 0 into tMace
   put 0 into tPicts
   -- the IDE's MACE decoder converts what the engine logged, and
   -- records the ids it converted
   put the uHyperCard["mace"] of pStack into tConverted
   repeat for each line tLine in pImportLog
      if tLine begins with "Not converting snd" then
         if word 5 of tLine is among the items of tConverted then next repeat
         add 1 to tSounds
         if "MACE" is in tLine then
            add 1 to tMace
         end if
      else if tLine begins with "Not converting" then
         put word 3 of tLine into tKind
         add 1 to tTypes[tKind]
      else if tLine begins with "PICT id" and "not drawn" is in tLine then
         add 1 to tPicts
      end if
   end repeat
   if tSounds > 0 then
      put return & "Sounds:" && tSounds && "not converted" after tOut
      if tMace > 0 then put " (" & tMace && "in MACE that could not be decoded)" after tOut
      put "." & return after tOut
   end if
   if tPicts > 0 then put return & "Pictures:" && tPicts && "drawn without some of their parts (text or QuickTime in a PICT)." & return after tOut
   if the number of elements of tTypes > 0 then
      put empty into tNames
      repeat for each key tKey in tTypes
         if tNames is not empty then put ", " after tNames
         put tKey && "x" & tTypes[tKey] after tNames
      end repeat
      put return & "Resources not converted:" && tNames & return after tOut
   end if

   -- fonts the stack names that this system does not have
   put empty into tNames
   repeat for each line tObject in _Objects(pStack)
      if word 1 of tObject is not among the words of "field button" then next repeat
      put the textFont of tObject into tFont
      if tFont is empty or tFont is among the lines of the fontNames or tFont is among the items of tNames then next repeat
      if tNames is not empty then put ", " after tNames
      put tFont after tNames
   end repeat
   if tNames is not empty then
      put return & "Fonts this system does not have, shown in another face:" && tNames & return after tOut
   end if

   put return & "The full log is the stack's uHyperCard[" & quote & "scripts" & quote & "] and the hcImportStat." after tOut
   return tOut
end revHyperCardImportSummary

-- pWord for one, else its plural (pPlural, or pWord & "s")
private function _Plural pCount, pWord, pPlural
   if pCount = 1 then return pWord
   if pPlural is not empty then return pPlural
   return pWord & "s"
end _Plural

-- An object as a person reads it: "button "Next" of card 3"
private function _ShortObject pObject
   local tName
   try
      if word 1 of pObject is "stack" then return "the stack script"
      put the name of pObject into tName
      if word 2 of pObject is "id" and word 1 of pObject is among the words of "card background bkgnd group" then return tName
      return tName && "of" && the name of the owner of pObject
   catch tError
      return pObject
   end try
end _ShortObject

/*
The handlers the last <revHyperCardFixScripts> left out because they
still did not compile after its rewrites (each one's HyperTalk is kept,
commented out, in a handler that passes its message): what a corpus
sweep counts (tools/hypercard-sweep).

Returns (Array): One element per handler, numbered from 1, each with the
keys "object" (the long id of the object whose script it is in), "name",
"error" (the first line of the engine's compile error, "number,line,
column,token") and "text" (the handler as rewritten).
*/
function revHyperCardLeftOutHandlers
   return sLeftOutLog
end revHyperCardLeftOutHandlers

/*
The lines the last <revHyperCardFixScripts> left out of handlers that
did not compile: each a statement that still did not compile after its
rewrites, in a handler that compiled without it and was kept so (rule
T39). The line is a comment in the handler, which goes on past it; in a
repeat that only a condition or an exit ends, and for return, exit and
pass, it is a throw, which stops the handler with an error naming it.

Returns (Array): One element per line, numbered from 1, each with the
keys "object" (the long id of the object whose script it is in), "name"
(the handler's), "line" (its number in the handler, from 1 for the on
line), "text" (its HyperTalk, on one line), "error" (the first line of
the engine's compile error, as for <revHyperCardLeftOutHandlers>) and
"how" ("skipped" or "stops").
*/
function revHyperCardLeftOutLines
   return sLinesLeftOutLog
end revHyperCardLeftOutLines

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
   -- (an XCMD is called as a command, which a function of the library of
   -- its name, hcX_Replace, does not answer)
   repeat for each line tLine in revHyperCardLibraryScript()
      if word 1 of tLine is among the words of "on command" then put true into tLibrary[_Lower(word 2 of tLine)]
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

-- The messages a palette window gets as it opens and closes, which a
-- palette made from a PLTE resource (a substack, its script made by the
-- engine's importer) would pass on to the stack's own script: in
-- HyperCard a palette was a window, not a stack, and the stack's
-- openStack did not run again as its palette opened (CoinMaster's
-- openStack, run from the palette it opens, found none of its fields)
constant kPaletteMessages = "preOpenStack openStack closeStack preOpenCard openCard closeCard openBackground closeBackground resumeStack suspendStack"
constant kPaletteFirstLine = "-- HyperCard palette (PLTE resource), made by the HyperCard importer"

private function _QuietPalettes pStack
   local tSub, tScript, tMessage, tAdd, tCount
   put 0 into tCount
   repeat for each line tSub in the substacks of pStack
      put the script of stack tSub of pStack into tScript
      if line 1 of tScript is not kPaletteFirstLine then next repeat
      put empty into tAdd
      repeat for each word tMessage in kPaletteMessages
         if ("on" && tMessage) is among the lines of tScript then next repeat
         put return & "on" && tMessage & return & "end" && tMessage after tAdd
      end repeat
      if tAdd is empty then next repeat
      set the script of stack tSub of pStack to tScript & return & \
            "-- (a palette's own opening and closing do not reach the stack)" & tAdd
      add 1 to tCount
   end repeat
   if tCount is 0 then return empty
   return "Palettes:" && tCount && "made to keep their opening and closing messages from the stack's script"
end _QuietPalettes

-- Add the library as a substack of the stack and make it the stack's
-- behavior, and in a stack with HyperCard's message order the library's
-- doMenu (_AddMenus). Returns a line for the report, or empty if it was
-- there.
private function _AddLibrary pStack, pStandIns
   local tName, tCount, tBase, tMenus, tTemp, tMain, tPlain
   if the behavior of pStack is not empty then
      return "Not added: the HyperCard library (the stack already has a behavior)"
   end if
   -- Named after the stack: the engine knows a behavior by its stack's
   -- name alone, so the libraries of two imports with one name were one
   -- library to it, and deleting either stack broke the other's. A
   -- substack of the import may have the name already: this library is
   -- the one marked as it, under the first free name
   put the short name of pStack into tMain
   put kLibraryName && "(" & tMain & ")" into tBase
   -- (a stack's name here has no comma: setting one makes each a "_", so
   -- that the library of "A,B,C's" is "HyperCard Library (A_B_C's)", the
   -- name it is found by. The name asked for, with its commas, was not
   -- found once set, and the import stopped there with an error: no
   -- library, and the stack's scripts' calls of it failed)
   replace comma with "_" in tBase
   put tBase into tName
   put 1 into tCount
   repeat while tName is among the lines of the substacks of pStack \
         and the uHyperCard["library"] of stack tName of pStack is not true
      add 1 to tCount
      put tBase && tCount into tName
   end repeat
   -- the mainStack of a substack is set by name, and a name that is a
   -- number ("007") is not found as one: the stack has another name
   -- while its library is made
   if tMain is a number then
      put "revHyperCardStack" & the milliseconds into tPlain
      set the name of pStack to tPlain
      put the long id of stack tPlain into pStack
   end if
   if tName is not among the lines of the substacks of pStack then
      -- made under a name no other stack has, as the library of a stack
      -- imported before would otherwise be the one "it" names
      put "revHyperCardLibrary" & the milliseconds into tTemp
      _CreateHiddenStack tTemp
      set the mainStack of stack tTemp to the short name of pStack
      set the name of stack tTemp of pStack to tName
      set the script of stack tName of pStack to revHyperCardLibraryScript() & pStandIns
      set the uHyperCard["library"] of stack tName of pStack to true
      -- create opens it: closed, it is not the topStack the IDE's
      -- palettes and menus act on, and it stays a substack
      close stack tName of pStack
   end if
   set the behavior of pStack to the long id of stack tName of pStack
   if sHyperTalk then put _AddMenus(pStack, tName, tMain) into tMenus
   if tPlain is not empty then set the name of pStack to tMain
   if tMenus is not empty then put return & tMenus into tMenus
   return "Added: the substack" && quote & tName & quote && "as the stack's behavior" & tMenus
end _AddLibrary

-- In a stack with HyperCard's message order, where doMenu is a message,
-- the substack "HyperCard Menus (<the stack's name>)" as the behavior of
-- its library (pLibrary): its "on doMenu" takes the doMenu no handler of
-- the stack takes, or one passes, and does HyperCard's menu item (the
-- library's hcMenuChoice). It is a stack of its own because only a
-- script of a stack with that order can have a handler called doMenu: an
-- engine without it (or the order turned off) refuses this script, and
-- the library's still compiles. pName: the stack's name, which pStack may
-- not have while it is made (_AddLibrary). Returns a line for the report
private function _AddMenus pStack, pLibrary, pName
   local tBase, tName, tCount, tTemp
   if the behavior of stack pLibrary of pStack is not empty then return empty
   put kMenusName && "(" & pName & ")" into tBase
   -- (with no comma, as _AddLibrary's)
   replace comma with "_" in tBase
   put tBase into tName
   put 1 into tCount
   repeat while tName is among the lines of the substacks of pStack \
         and the uHyperCard["menus"] of stack tName of pStack is not true
      add 1 to tCount
      put tBase && tCount into tName
   end repeat
   if tName is not among the lines of the substacks of pStack then
      put "revHyperCardMenus" & the milliseconds into tTemp
      _CreateHiddenStack tTemp
      set the mainStack of stack tTemp to the short name of pStack
      set the name of stack tTemp of pStack to tName
      set the script of stack tName of pStack to _MenusScript()
      if the result is not empty then
         -- (should not happen: the substack follows its mainstack's order)
         delete stack tName of pStack
         return empty
      end if
      set the uHyperCard["menus"] of stack tName of pStack to true
      close stack tName of pStack
   end if
   set the behavior of stack pLibrary of pStack to the long id of stack tName of pStack
   return "Added: the substack" && quote & tName & quote && "as the library's behavior, for doMenu"
end _AddMenus

-- Makes the invisible stack pName (_AddLibrary, _AddMenus, _MakeProbe)
-- with the recent cards locked. Create opens a stack, and the card it
-- opens on was the most recent card: a stack's "go back" or "pop card"
-- after its openStack's "push recent card" (Carrie's Coins, Datebook+)
-- went to the library or its menus in the session the stack was
-- imported in, and ran the stack's own handlers on that card. HyperCard's
-- own windows were never recent cards. A new stack is not one with
-- HyperCard's order, whose cards lockRecent would let through
private command _CreateHiddenStack pName
   local tRecent
   put the lockRecent into tRecent
   set the lockRecent to true
   create invisible stack pName
   set the lockRecent to tRecent
end _CreateHiddenStack

-- The script of the substack _AddMenus adds
private function _MenusScript
   return "-- OXT-Beyond: the behavior of this stack's HyperCard Library, which" & return & \
         "-- revHyperCardFixScripts adds to a stack with HyperCard's message order" & return & \
         "-- (its hyperTalkCompatible). doMenu is a message there, as in HyperCard:" & return & \
         "-- one that no handler of the stack takes, or that one passes, comes" & return & \
         "-- here and does HyperCard's menu item (the library's hcMenuChoice)." & return & \
         "on doMenu pItem, pMenu, pWithout" & return & \
         "   hcMenuChoice pItem, pMenu, pWithout" & return & \
         "   return the result" & return & \
         "end doMenu"
end _MenusScript

----------------------------------------------------------------------
-- Compiling

private command _MakeProbe
   local tName
   put "revHyperCardProbe" & the milliseconds into tName
   _CreateHiddenStack tName
   put the long id of stack tName into sProbe
   -- (with the message order of the stack being fixed, so that a script
   -- compiles on it as in the stack: "on doMenu")
   if sHyperTalk then
      try
         set the hyperTalkCompatible of sProbe to true
      catch tError
      end try
   end if
end _MakeProbe

-- Whether pStack has HyperCard's message order: its hyperTalkCompatible,
-- or its mainstack's
private function _HyperTalkOrder pStack
   local tOn
   try
      put the hyperTalkCompatible of pStack is true into tOn
      if not tOn and the mainStack of pStack is not the short name of pStack then
         put the hyperTalkCompatible of stack (the mainStack of pStack) is true into tOn
      end if
   catch tError
      put false into tOn
   end try
   return tOn
end _HyperTalkOrder

-- A handler _Salvage leaves out, with the compile error it gives on its own
private command _LogLeftOut pName, pText
   local tCount
   put the number of elements of sLeftOutLog + 1 into tCount
   put sObject into sLeftOutLog[tCount]["object"]
   put pName into sLeftOutLog[tCount]["name"]
   put pText into sLeftOutLog[tCount]["text"]
   if sProbe is empty or there is not a stack sProbe then _MakeProbe
   set the script of sProbe to pText
   put line 1 of the result into sLeftOutLog[tCount]["error"]
   set the script of sProbe to empty
end _LogLeftOut

-- The lines _LeaveOutLines left out of the handler pName (T39), for
-- revHyperCardLeftOutLines
private command _LogLinesLeftOut pName, pLines
   local tCount, i
   repeat with i = 1 to the number of elements of pLines
      put the number of elements of sLinesLeftOutLog + 1 into tCount
      put pLines[i] into sLinesLeftOutLog[tCount]
      put sObject into sLinesLeftOutLog[tCount]["object"]
      put pName into sLinesLeftOutLog[tCount]["name"]
   end repeat
end _LogLinesLeftOut

private function _Compiles pScript
   return _CompileError(pScript) is empty
end _Compiles

-- The engine's compile error for pScript, its first line "number,line,
-- column,token", or empty if it compiles
private function _CompileError pScript
   local tResult
   if sProbe is empty or there is not a stack sProbe then _MakeProbe
   set the script of sProbe to pScript
   put the result into tResult
   set the script of sProbe to empty
   return tResult
end _CompileError

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
   if pName is "domenu" then return not sHyperTalk
   if sHandlerRefused[pName] is empty then
      if sProbe is empty then
         put pName is among the words of kCommands or pName is among the words of "controlkey clickline cmdkey exists lineoffset me mouseline result round sum lower" into sHandlerRefused[pName]
      else
         put not _Compiles("on" && pName & return & "end" && pName) into sHandlerRefused[pName]
      end if
   end if
   return sHandlerRefused[pName]
end _HandlerRefused

-- T62: whether this engine takes a call "pName(...)" of the stack's
-- function pName for something else: one of its constants ("comma(hold)",
-- SalesWriter's), properties ("colors()", "Visible(place, object, i)",
-- "fileName(it)", which compile with an argument and stop with an error
-- each time they run) or functions ("selectedButton(1)", "round(x)",
-- which HyperCard sent to the stack's handler first, as it did every call
-- with parentheses, and only "the" form went straight to its own), or a
-- word a call of which compiles in neither form ("wrap(string)", an
-- operator). (A call that compiles of another word reaches the handler,
-- as in HyperCard, also from a "do" or a "value", which renaming it would
-- break)
private function _CallRefused pName
   put _Lower(pName) into pName
   if not _IsName(pName) or pName is among the words of kNotPlain then return false
   if sCallRefused[pName] is empty then
      put pName is among the lines of the constantNames or pName is among the lines of the propertyNames \
            or pName is among the lines of the functionNames into sCallRefused[pName]
   end if
   if sCallRefused[pName] or sProbe is empty then return sCallRefused[pName]
   if sCallCompiles[pName] is empty then
      put _Compiles("on hcProbe" & return & "put" && pName & "() into tValue" & return & "end hcProbe") \
            or _Compiles("on hcProbe" & return & "put" && pName & "(1) into tValue" & return & "end hcProbe") into sCallCompiles[pName]
   end if
   return not sCallCompiles[pName]
end _CallRefused

-- T62: in a script that compiles, the stack's functions that are renamed
-- (pRename: T1's and T62's, by their old names), where the line defines
-- one (its function, end, exit or pass) or calls one with parentheses
-- that reaches it (_Reached), which here reached this engine's own
-- function, property or constant of that name and in HyperCard the
-- stack's handler ("select line clickLine() of me", where the stack's
-- clickLine gives a line's number). (A function named like a command is
-- T47's.)
private function _RenamedFunctions pLine, pRename
   local tTokens, tCode, tIndex, tFirst, tWord, tPrev, tNext, tChanged
   -- (a line that names none of them, as most do, as it is)
   repeat for each key tWord in pRename
      if sStackFunctions[tWord] and tWord is in pLine then put true into tChanged
   end repeat
   if not tChanged then return pLine
   put false into tChanged
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put item 1 of tCode into tFirst
   repeat for each item tIndex in tCode
      if tTokens[tIndex]["k"] is not "w" then next repeat
      put _T(tTokens, tIndex) into tWord
      if pRename[tWord] is empty or not sStackFunctions[tWord] or tWord is among the words of kCommands then next repeat
      put _PrevCode(tCode, tIndex) into tPrev
      put _NextCode(tCode, tIndex) into tNext
      if (_T(tTokens, tPrev) is among the words of "on function end pass exit" \
            and (tPrev = tFirst or _T(tTokens, tPrev) is among the words of "pass exit")) \
            or (_T(tTokens, tNext) is "(" and _T(tTokens, tPrev) is not "the" and _Reached(tWord)) then
         put pRename[tWord] into tTokens[tIndex]["t"]
         put true into tChanged
         if _HandlerRefused(tWord) then
            _Fire "T1 handler named like a keyword"
         else
            _Fire "T62 a function named like a word of this engine"
         end if
      end if
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _RenamedFunctions

-- T1: a message sent to a handler that T1 renames (pRename), its name
-- not in quotes or in them, alone or before its parameters ("send move
-- to card id cardID", HyperQuest's, whose cards have "on move"; "send
-- "reset" to bkgnd btn 1"), which HyperCard's handler took. Here no
-- handler has that name, and this engine runs the message as its own
-- command ("move", which stops with an error): the handler's new name,
-- in quotes. Not a message sent to a window, a program or HyperCard (an
-- external's window takes "close"; HyperCard, named in quotes too ("send
-- "go to next card" to "hyperCard"", Bring in the Expert's, whose stack
-- has its own "on go"), runs its own handler, not the stack's), nor doMenu
-- (T15's)
private function _RenamedMessages pLine, pRename
   local tTokens, tCode, tIndex, tNext, tAfter, tWord, tText, tLength, tChanged, tTo
   if "send" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   repeat for each item tIndex in tCode
      if _Lower(tTokens[tIndex]["t"]) is not "send" or not _StatementStart(tTokens, tCode, tIndex) then next repeat
      put _NextCode(tCode, tIndex) into tNext
      if tNext is empty then next repeat
      put _NextCode(tCode, tNext) into tAfter
      if tAfter is not empty then
         if _Lower(tTokens[tAfter]["t"]) is not among the words of "to else" then next repeat
         if _Lower(tTokens[tAfter]["t"]) is "to" and _NextCode(tCode, tAfter) is not empty then
            put _Lower(tTokens[_NextCode(tCode, tAfter)]["t"]) into tTo
            if tTo is among the words of "window program hypercard" or tTo is quote & "hypercard" & quote then next repeat
         end if
      end if
      if tTokens[tNext]["k"] is "w" then
         put _Lower(tTokens[tNext]["t"]) into tWord
         if tWord is "domenu" or pRename[tWord] is empty then next repeat
         put quote & pRename[tWord] & quote into tTokens[tNext]["t"]
         put "s" into tTokens[tNext]["k"]
      else if tTokens[tNext]["k"] is "s" and char -1 of tTokens[tNext]["t"] is quote then
         put char 2 to -2 of tTokens[tNext]["t"] into tText
         put the number of chars of word 1 of tText into tLength
         put _Lower(word 1 of tText) into tWord
         if tLength = 0 or char 1 to tLength of tText is not word 1 of tText then next repeat
         if tWord is "domenu" or pRename[tWord] is empty then next repeat
         put pRename[tWord] into char 1 to tLength of tText
         put quote & tText & quote into tTokens[tNext]["t"]
      else
         next repeat
      end if
      _Fire "T1 handler named like a keyword"
      put true into tChanged
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _RenamedMessages

-- T62: whether every call of the stack's function pName that the script
-- being fixed makes reaches a definition of it: one in a script on the
-- message path of all its calls (sReached), its own included. Only such
-- a call is renamed to the new name of the function: HyperCard sent a
-- call that found no handler of the stack's on to its own function (a
-- card's function called from another card), which the call that is not
-- renamed still reaches here, and the new name would reach nothing. (A
-- script in no stack, revHyperCardRewriteScript's, defines what it
-- calls)
private function _Reached pName
   local tId
   if sFunctionDefiners[pName] is not an array then return true
   repeat for each key tId in sFunctionDefiners[pName]
      if sReached[tId] is true then return true
   end repeat
   return false
end _Reached

-- T62: pObject, the object of a script of the stack, as _AlwaysOnPath
-- and sFunctionDefiners name it: "stack" for the stack, else its id
private function _PathId pObject
   if word 1 of pObject is "stack" then return "stack"
   return the id of pObject
end _PathId

-- T62: the objects whose scripts are on the message path of every call
-- pObject's script makes (by _PathId, true): pObject, the groups and the
-- card it is on, that card's backgrounds, and the stack. A background
-- and its controls are on every card of it, so no card is. (In a stack
-- with HyperCard's addressing a control's long id begins "card button"
-- or "bkgnd field", and a card's still "card id")
private function _AlwaysOnPath pObject
   local tPath, tObject, tShared, tId, n
   put true into tPath["stack"]
   put pObject into tObject
   repeat with n = 1 to 20
      if tObject is empty or word 1 of tObject is "stack" then exit repeat
      if word 1 to 2 of tObject is "card id" then
         if not tShared then
            put true into tPath[the id of tObject]
            repeat for each line tId in the backgroundIDs of tObject
               put true into tPath[tId]
            end repeat
         end if
         exit repeat
      end if
      put true into tPath[the id of tObject]
      if word 1 of tObject is "group" and the backgroundBehavior of tObject then put true into tShared
      put the long id of the owner of tObject into tObject
   end repeat
   return tPath
end _AlwaysOnPath

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

-- The first code token of the line (its "t" and "k"), or empty
private function _FirstCode pLine
   local tTokens, tCode
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   if item 1 of tCode is empty then return empty
   return tTokens[item 1 of tCode]
end _FirstCode

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
   -- (or in this script) whose names this engine refuses, and (T62) the
   -- stack's functions it takes a call of for something else
   -- (_CallRefused). T47 and T62: the stack's functions, this script's
   -- too
   repeat with i = 1 to tSpanCount
      put true into pDefines[tSpans[i]["name"]]
      if word 1 of _CodeText(tLines[tSpans[i]["start"]]) is "function" then put true into sStackFunctions[tSpans[i]["name"]]
   end repeat
   repeat for each key tWord in pDefines
      if _HandlerRefused(tWord) or (sStackFunctions[tWord] and _CallRefused(tWord)) then
         put _NewHandlerName(tWord) into tRenameHandlers[tWord]
      end if
   end repeat
   -- T15: without HyperCard's message order, every doMenu goes to
   -- hcDoMenu, the stack's own (its "on doMenu", renamed) and then the
   -- library's, which does what HyperCard's menu items did; with it,
   -- doMenu is a message that reaches them as it is
   if not sHyperTalk then put "hcDoMenu" into tRenameHandlers["domenu"]
   -- T47: the new names
   put tRenameHandlers into sRenameHandlers
   -- T37: the stack's own handlers, whose arguments are taken as an
   -- external's are (_ExternalArguments)
   put empty into sCallees
   put pExternals into sExternals
   repeat for each key tWord in pDefines
      if tRenameHandlers[tWord] is empty and _IsName(tWord) and tWord is not among the words of kCommands \
            and tWord is not among the words of kHyperTalkCommands then
         put true into sCallees[tWord]
      end if
   end repeat

   if pCompiled then
      -- Only what changes what a script that compiles does, to what it did
      -- in HyperCard: the doMenu routing (in a stack without HyperCard's
      -- message order), HyperCard's version, the stack's functions that
      -- are renamed (T62), the statements that stop with an error here
      -- where HyperCard went on (_HyperCardRules), and the loops that
      -- wait for a colon that no path has here (T74)
      repeat with i = 1 to tCount
         if tRenameHandlers["domenu"] is not empty then put _RouteDoMenu(tLines[i]) into tLines[i]
         put _VersionRule(tLines[i]) into tLines[i]
         put _RenamedFunctions(tLines[i], tRenameHandlers) into tLines[i]
         put _RenamedMessages(tLines[i], tRenameHandlers) into tLines[i]
      end repeat
      repeat with i = 1 to tSpanCount
         _HyperCardRulesLines tLines, tSpans[i]["start"], tSpans[i]["end"], true
         _ColonLoops tLines, tSpans[i]["start"], tSpans[i]["end"]
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
      -- (tContinued: the line before ends with \, so this one goes on with
      -- its statement and starts none, "drag from a to b \" then "with
      -- optionKey")
      -- (tGoesOn: this line ends with \, and its statement goes on with
      -- the first code token of the next, tThen, which T2 reads)
      local tContinued, tGoesOn, tThen
      put false into tContinued
      repeat with tKey = tSpans[i]["start"] to tSpans[i]["end"]
         put char -1 of word 1 to -1 of _CodeText(tLines[tKey]) is "\" into tGoesOn
         put empty into tThen
         if tGoesOn and tKey < tSpans[i]["end"] then put _FirstCode(tLines[tKey + 1]) into tThen
         put _RewriteLine(tLines[tKey], tVars, tRename, pExternals, tRenameHandlers, tContinued, tThen) into tLines[tKey]
         put _RenamedMessages(tLines[tKey], tRenameHandlers) into tLines[tKey]
         put tGoesOn into tContinued
      end repeat
      _ContinuedCommands tLines, tSpans[i]["start"], tSpans[i]["end"], tVars
      _HyperCardRulesLines tLines, tSpans[i]["start"], tSpans[i]["end"], false
      _ExitPassNames tLines, tSpans[i]["start"], tSpans[i]["end"]
      _ColonLoops tLines, tSpans[i]["start"], tSpans[i]["end"]
   end repeat
   return _JoinLines(tLines, tCount)
end _Rewrite

-- T38: "exit" and "pass" with the name of another handler than the one
-- they are in ("exit saveToDisk" in a handler called createText, copied
-- from the other; "pass whatKey" in keyDown, its parameter's name),
-- which this engine refuses: the handler's own name, so that the
-- statement leaves the handler, or passes its message, as it meant to.
-- A name in quotes is a name too ("pass "doMenu"" in a doMenu handler
-- renamed hcDoMenu). "exit repeat" and "exit to ..." are not names. And
-- global with names in quotes or none between two commas (_GlobalNames)
private command _ExitPassNames @pLines, pStart, pEnd
   local tName, tTokens, tCode, i, k, n, tAt, tWord, tChanged, tContinued, tLine
   put _Tokens(pLines[pStart]) into tTokens
   put _Code(tTokens) into tCode
   put tTokens[item 2 of tCode]["t"] into tName
   if not _IsName(tName) then exit _ExitPassNames
   put false into tContinued
   repeat with i = pStart + 1 to pEnd - 1
      if not tContinued then
         put _GlobalNames(pLines[i]) into tLine
         if tLine is not pLines[i] then
            put tLine into pLines[i]
            _Fire "T38 global with names in quotes or none"
         end if
      end if
      put _Tokens(pLines[i]) into tTokens
      put _Code(tTokens) into tCode
      put the number of items of tCode into n
      put false into tChanged
      repeat with k = 1 to n - 1
         put _T(tTokens, item k of tCode) into tWord
         if tWord is not among the words of "exit pass" then next repeat
         -- (a statement's first word: the line's, or the word after then
         -- or else; and the name, the statement's last word)
         if k = 1 and tContinued then next repeat
         if k > 1 and _T(tTokens, item k - 1 of tCode) is not among the words of "then else" then next repeat
         if k + 1 < n and _T(tTokens, item k + 2 of tCode) is not "else" then next repeat
         put item k + 1 of tCode into tAt
         put _Lower(tTokens[tAt]["t"]) into tWord
         if tTokens[tAt]["k"] is not among the words of "w s" then next repeat
         if tTokens[tAt]["k"] is "w" and (tWord is _Lower(tName) or tWord is among the words of "repeat to") then next repeat
         put tName into tTokens[tAt]["t"]
         put true into tChanged
         _Fire "T38 exit or pass with another handler's name"
      end repeat
      if tChanged then put _Join(tTokens) into pLines[i]
      put _T(tTokens, item -1 of tCode) is "\" into tContinued
   end repeat
end _ExitPassNames

-- T38: a global statement with names in quotes ("global "Mapper"") or
-- none between two commas ("global a, , b,"), which HyperCard took and
-- this engine refuses: the names alone. Anything else in it (an
-- expression, "global the short name of the target") leaves it as it is
private function _GlobalNames pLine
   local tTokens, tCode, i, tItem, tName, tNames, tChanged, tOut
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   if _T(tTokens, item 1 of tCode) is not "global" then return pLine
   put empty into tName
   put false into tChanged
   repeat with i = 2 to the number of items of tCode + 1
      put item i of tCode into tItem
      if tItem is empty or tTokens[tItem]["t"] is comma then
         -- (the end of a name, or of none)
         if tName is empty then
            put true into tChanged
         else
            if tNames is not empty then put ", " after tNames
            put tName after tNames
         end if
         put empty into tName
      else if tName is not empty then
         return pLine
      else if tTokens[tItem]["k"] is "w" then
         put tTokens[tItem]["t"] into tName
      else if tTokens[tItem]["k"] is "s" and _IsName(char 2 to -2 of tTokens[tItem]["t"]) then
         put char 2 to -2 of tTokens[tItem]["t"] into tName
         put true into tChanged
      else
         return pLine
      end if
   end repeat
   if not tChanged or tNames is empty then return pLine
   if tTokens[1]["k"] is "sp" then put tTokens[1]["t"] into tOut
   put tTokens[item 1 of tCode]["t"] && tNames after tOut
   if tTokens[tTokens["count"]]["k"] is "c" then put space & tTokens[tTokens["count"]]["t"] after tOut
   return tOut
end _GlobalNames

-- T74: a loop that takes a path back to its folder one character at a
-- time, until its last character is a colon ("repeat until the last char
-- of it is ":"" and "delete the last char of it", on the long name of
-- the stack, Star Trek-DS9 Guide's). In HyperCard a stack's long name and
-- a file's path always had one ("Disk:Folder:Stack"); here a path has
-- none ("/Users/me/Stack") but for a Windows drive's ("C:/Users/me"), and
-- a stack not saved has its name alone, so the loop never ended. It ends
-- now when the text is empty, which is where it got to with no colon
-- left in it: the loop's head gets "or <text> is empty" ("and <text> is
-- not empty" after "while"). With a colon in the text it ends where it
-- did, as the text is never empty before it gets to it. Only a loop
-- whose every line is one of these is taken, so that once the text is
-- empty it could do nothing but go round: the text's last character
-- deleted ("delete last char of TEMP", "delete char length (PathName) of
-- PathName", "get char 1 to length(it)-1 of it"), put into the variable
-- the loop waits on, when it waits on one ("put last character of
-- stackFolder into lastChar", "get the last char of process"), and a put
-- of a value that calls no handler into another variable ("if it is not
-- ":" then put it before char 1 of holdPictName"). A loop with no
-- condition ("repeat", "repeat forever") that waits for the colon in an
-- if of its own (_ColonLoopForever: Script Manager's "if last char of
-- filename is ":" then exit repeat", the HyperTextBooks' "if last char
-- of manx <> ":" then delete last char of manx" and "else", "delete last
-- char of manx", "exit repeat") gets "until <text> is empty" in its
-- head, as "forever". In a script that compiles too
private command _ColonLoops @pLines, pStart, pEnd
   local i, k, n, tHead, tCode, tLine, tLines, tText, tWait, tOk, tEnded, tDeletes, tReads, tTokens, tAt
   repeat with i = pStart + 1 to pEnd - 1
      if _Lower(word 1 of pLines[i]) is "repeat" and _Lower(_CodeSpaced(pLines[i])) is among the items of "repeat,repeat forever" then
         put _ColonLoopForever(pLines, i, pEnd) into tText
         if tText is empty then next repeat
         put _Tokens(pLines[i]) into tTokens
         put _Code(tTokens) into tAt
         if the number of items of tAt is 1 then
            put " until" && tText && "is empty" after tTokens[item 1 of tAt]["t"]
         else
            put "until" && tText && "is empty" into tTokens[item 2 of tAt]["t"]
         end if
         put _Join(tTokens) into pLines[i]
         _Fire "T74 a loop that waits for a colon"
         next repeat
      end if
      if quote & ":" & quote is not in pLines[i] then next repeat
      put _ColonLoopHead(pLines[i]) into tHead
      if tHead is empty then next repeat
      -- the loop's lines, to its end repeat
      put 0 into n
      put true into tOk
      put false into tEnded
      put tHead["text"] into tText
      put tHead["wait"] into tWait
      repeat with k = i + 1 to pEnd - 1
         put _CodeText(pLines[k]) into tCode
         if _Lower(word 1 of tCode) is "end" and _Lower(word 2 of tCode) is "repeat" then
            put true into tEnded
            exit repeat
         end if
         put _ColonLoopLine(pLines[k]) into tLine
         if tLine is empty then
            put false into tOk
            exit repeat
         end if
         add 1 to n
         put tLine into tLines[n]
         -- (the text, when the loop waits on a variable: the one whose
         -- last character it deletes)
         if tText is empty and tLine["kind"] is "delete" then put tLine["text"] into tText
      end repeat
      if not tOk or not tEnded or not _LoopVariable(tText) then next repeat
      if tWait is not empty and (not _LoopVariable(tWait) or _Lower(tWait) is _Lower(tText)) then next repeat
      -- nothing but a delete writes the text, and nothing but a put of
      -- its last character the variable waited on
      put 0 into tDeletes
      put 0 into tReads
      repeat with k = 1 to n
         switch tLines[k]["kind"]
            case "delete"
               if _Lower(tLines[k]["text"]) is not _Lower(tText) then put false into tOk
               add 1 to tDeletes
               break
            case "read"
               if _Lower(tLines[k]["into"]) is _Lower(tText) then put false into tOk
               if _Lower(tLines[k]["into"]) is _Lower(tWait) then
                  if _Lower(tLines[k]["text"]) is not _Lower(tText) then put false into tOk
                  add 1 to tReads
               end if
               break
            case "put"
               if _Lower(tLines[k]["into"]) is _Lower(tText) or _Lower(tLines[k]["into"]) is _Lower(tWait) then put false into tOk
               break
         end switch
      end repeat
      if not tOk or tDeletes = 0 or (tWait is not empty and tReads = 0) then next repeat
      put _Tokens(pLines[i]) into tTokens
      put item -1 of _Code(tTokens) into tAt
      if tHead["until"] then
         put " or" && tText && "is empty" after tTokens[tAt]["t"]
      else
         put " and" && tText && "is not empty" after tTokens[tAt]["t"]
      end if
      put _Join(tTokens) into pLines[i]
      _Fire "T74 a loop that waits for a colon"
   end repeat
end _ColonLoops

-- T74: the text of a loop with no condition, its head pLines[pAt]
-- ("repeat" or "repeat forever"), that waits for a colon at the end of
-- the text in an if of its own, or empty. Each of its lines is one that
-- _ColonLoopLine takes, or an if that tests the text's last character
-- for a colon (_ColonTest), on one line or with its else and end if, one
-- at a time, or an exit (exit repeat, or exit or return with a name or
-- none) only where the text ends with a colon: after then when the if
-- tests that it does, after else when it tests that it does not. So
-- with the text empty nothing leaves the loop. And it has at least one
-- of each: a delete of the text's last character, a test and an exit
private function _ColonLoopForever @pLines, pAt, pEnd
   local k, tCode, tText, tState, tColon, tTest, tA, tB, tStatement, tExitHere, tLine, tInto, tCount
   put 0 into tCount["test"]
   put 0 into tCount["delete"]
   put 0 into tCount["exit"]
   repeat with k = pAt + 1 to pEnd - 1
      put _CodeSpaced(pLines[k]) into tCode
      put empty into tStatement
      put empty into tB
      if _Lower(tCode) is "end repeat" then
         if tState is among the words of "then else" then return empty
         if tCount["test"] = 0 or tCount["delete"] = 0 or tCount["exit"] = 0 then return empty
         -- (and nothing puts into the text)
         repeat for each key tA in tInto
            if _Lower(tA) is _Lower(tText) then return empty
         end repeat
         return tText
      else if matchText(tCode, "(?i)^if (.+) then(?: (.+))?$", tA, tB) and _ColonTest(tA) is not empty then
         if tState is among the words of "then else" then return empty
         put _ColonTest(tA) into tTest
         if not _ColonLoopText(tText, tTest["text"]) then return empty
         add 1 to tCount["test"]
         put tTest["colon"] into tColon
         put tColon into tExitHere
         put tB into tStatement
         -- (an if on one line may have its else on the next)
         if tStatement is empty then
            put "then" into tState
         else
            put "single" into tState
         end if
      else if matchText(tCode, "(?i)^else(?: (.+))?$", tB) then
         if tState is not among the words of "then single" then return empty
         put not tColon into tExitHere
         put tB into tStatement
         if tStatement is empty then
            put "else" into tState
         else
            put empty into tState
         end if
      else if _Lower(tCode) is "end if" then
         if tState is not among the words of "then else" then return empty
         put empty into tState
      else
         if tState is "single" then put empty into tState
         put (tState is "then" and tColon) or (tState is "else" and not tColon) into tExitHere
         put tCode into tStatement
      end if
      if tStatement is empty then next repeat
      if matchText(tStatement, "(?i)^(exit [^ ]+|return( [^ ]+)?)$") then
         if not tExitHere then return empty
         add 1 to tCount["exit"]
      else
         put _ColonLoopLine(tStatement) into tLine
         if tLine is empty then return empty
         if tLine["kind"] is "delete" then
            if not _ColonLoopText(tText, tLine["text"]) then return empty
            add 1 to tCount["delete"]
         else if tLine["into"] is not empty then
            put true into tInto[tLine["into"]]
         end if
      end if
   end repeat
   return empty
end _ColonLoopForever

-- T74: a test of the last character of a variable for a colon, "the last
-- char of x is ":"" (or "= ":"", and "is not" or "<>" for one that it is
-- not): ["text"] the variable, ["colon"] true for a test that it is one.
-- Empty for any other
private function _ColonTest pCode
   local tA, tB, tC, tOperator, tTest
   if not matchText(pCode, "(?i)^(the )?last (char|character) of ([^ ]+) (is not|is|=|< >) " & quote & ":" & quote & "$", tA, tB, tC, tOperator) then return empty
   put tC into tTest["text"]
   put _Lower(tOperator) is among the items of "is,=" into tTest["colon"]
   return tTest
end _ColonTest

-- T74: whether pName is the text of a loop, pText, which the first name
-- given it becomes when it has none
private function _ColonLoopText @pText, pName
   if not _LoopVariable(pName) then return false
   if pText is empty then put pName into pText
   return _Lower(pName) is _Lower(pText)
end _ColonLoopText

-- T74: the head of a loop that waits for a colon at the end of a text,
-- "repeat until E is ":"" (or "= ":"") or "repeat while E is not ":"" (or
-- "<> ":""): ["until"] true for until, and in ["text"] the variable E is
-- the last character of ("the last char of it", "char length (PathName)
-- of PathName"), or in ["wait"] E itself, a variable the loop puts that
-- character into ("lastChar"). Empty for any other line
private function _ColonLoopHead pLine
   local tCode, tKind, tE, tOperator, tA, tB, tC, tHead
   put _CodeSpaced(pLine) into tCode
   if not matchText(tCode, "(?i)^repeat (until|while) (.+) (is not|is|=|< >) " & quote & ":" & quote & "$", tKind, tE, tOperator) then return empty
   put _Lower(tKind) is "until" into tHead["until"]
   if tHead["until"] is not (_Lower(tOperator) is among the items of "is,=") then return empty
   if matchText(tE, "(?i)^(the )?last (char|character) of ([^ ]+)$", tA, tB, tC) then
      put tC into tHead["text"]
   else if matchText(tE, "(?i)^(char|character) length \( ([^ ]+) \) of ([^ ]+)$", tA, tB, tC) and _Lower(tB) is _Lower(tC) then
      put tC into tHead["text"]
   else if _IsName(tE) then
      put tE into tHead["wait"]
   else
      return empty
   end if
   return tHead
end _ColonLoopHead

-- T74: a line of a loop that waits for a colon, as _ColonLoops takes it:
-- ["kind"] "delete" for a delete of the last character of the variable
-- in ["text"], "read" for a put of that character into the variable in
-- ["into"] (a get, into "it"), "put" for a put of a value that calls no
-- handler into the variable in ["into"] or a chunk of it, after "if ...
-- then" or not, and "none" for a line with no code. Empty for any other
private function _ColonLoopLine pLine
   local tCode, tA, tB, tC, tD, tE, tLine, tWord, tPuts
   put _CodeSpaced(pLine) into tCode
   if tCode is empty then
      put "none" into tLine["kind"]
   else if matchText(tCode, "(?i)^delete (the )?last (char|character) of ([^ ]+)$", tA, tB, tC) then
      put "delete" into tLine["kind"]
      put tC into tLine["text"]
   else if matchText(tCode, "(?i)^delete (char|character) length \( ([^ ]+) \) of ([^ ]+)$", tA, tB, tC) and _Lower(tB) is _Lower(tC) then
      put "delete" into tLine["kind"]
      put tC into tLine["text"]
   else if matchText(tCode, "(?i)^get (char|character) 1 to length \( it \) - 1 of it$", tA) then
      put "delete" into tLine["kind"]
      put "it" into tLine["text"]
   else if matchText(tCode, "(?i)^put (the )?last (char|character) of ([^ ]+) into ([^ ]+)$", tA, tB, tC, tD) then
      put "read" into tLine["kind"]
      put tC into tLine["text"]
      put tD into tLine["into"]
   else if matchText(tCode, "(?i)^get (the )?last (char|character) of ([^ ]+)$", tA, tB, tC) then
      put "read" into tLine["kind"]
      put tC into tLine["text"]
      put "it" into tLine["into"]
   else
      -- (one put, and no else or call)
      put 0 into tPuts
      repeat for each word tWord in tCode
         if _Lower(tWord) is "put" then add 1 to tPuts
         if _Lower(tWord) is "else" then add 2 to tPuts
      end repeat
      if tPuts is not 1 or "(" is in tCode then return empty
      if not matchText(tCode, "(?i)^(if .+ then )?put .+ (before|after|into) ((char|character|word|item|line) [0-9]+ of )?([^ ]+)$", tA, tB, tC, tD, tE) then return empty
      if not _IsName(tE) then return empty
      put "put" into tLine["kind"]
      put tE into tLine["into"]
   end if
   return tLine
end _ColonLoopLine

-- T74: whether pWord can be the variable of a loop that waits for a
-- colon: a name that is no word of the grammar for an object or a value
-- ("me", "the target", "msg")
private function _LoopVariable pWord
   return _IsName(pWord) and _Lower(pWord) is not among the words of (kStructural && "msg message empty")
end _LoopVariable

-- The code tokens of a line, one space between each (strings as they are)
private function _CodeSpaced pLine
   local tTokens, tItem, tText
   put _Tokens(pLine) into tTokens
   repeat for each item tItem in _Code(tTokens)
      if tText is not empty then put space after tText
      put tTokens[tItem]["t"] after tText
   end repeat
   return tText
end _CodeSpaced

-- The commands of _LineCommands on a statement continued over lines (a
-- \ at the end of a line, HyperCard's option-return): the statement is
-- put on its first line, and the lines it took after that are left empty,
-- so that the lines after it keep their numbers. An answer continued over
-- lines also gets _ParserForms' rules for its replies (T34)
private command _ContinuedCommands @pLines, pStart, pEnd, pVars
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
      if tNew is tMerged and _Lower(word 1 of _CodeText(tMerged)) is "answer" then
         put _ParserForms(tMerged, pVars) into tNew
      end if
      if tNew is not tMerged then
         _PutContinued pLines, i, j, tNew
      end if
      put j + 1 into i
   end repeat
end _ContinuedCommands

-- _HyperCardRules on the lines pStart to pEnd, a statement continued
-- over lines taken whole ("put ... after menuItem ... of menu M \" and
-- "with menuMsg ..." on the next line): when a rule rewrites it, it is put
-- on its first line and the lines it took after that are left empty, as
-- _ContinuedCommands does (_PutContinued)
private command _HyperCardRulesLines @pLines, pStart, pEnd, pCompiled
   local i, j, tMerged, tNew
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
         _PutContinued pLines, i, j, tNew
      end if
      put j + 1 into i
   end repeat
end _HyperCardRulesLines

-- pNew, a statement continued over the lines pFirst to pLast that a rule
-- rewrote, in their place: on the first, the lines it took after that
-- left empty, so that the lines after it keep their numbers. When the
-- line after them starts with "then", which must follow the line of its
-- "if" here, the statement goes on over them with \ instead, its comment
-- on the last ("if the checkMark of menuItem 4 of menu 5 \", "and x = 1",
-- "then beep")
private command _PutContinued @pLines, pFirst, pLast, pNew
   local k, tTokens, i, tComment
   if _Lower(word 1 of _CodeText(pLines[pLast + 1])) is not "then" then
      put pNew into pLines[pFirst]
      repeat with k = pFirst + 1 to pLast
         put empty into pLines[k]
      end repeat
      exit _PutContinued
   end if
   -- (a comment at its end would hide the \: it goes on the last line)
   put _Tokens(pNew) into tTokens
   repeat with i = tTokens["count"] down to 1
      if tTokens[i]["k"] is "c" then
         put tTokens[i]["t"] into tComment
      else if tTokens[i]["k"] is not "sp" then
         exit repeat
      end if
      put empty into tTokens[i]["t"]
   end repeat
   put _Join(tTokens) && "\" into pLines[pFirst]
   repeat with k = pFirst + 1 to pLast - 1
      put "\" into pLines[k]
   end repeat
   put tComment into pLines[pLast]
end _PutContinued

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
            _Fire "T15 doMenu to hcDoMenu"
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

-- The first word of the statement the token at pIndex is in, lower case:
-- the first code token of its line, or the one after its then or else
private function _StatementVerb pTokens, pCode, pIndex
   local tItem, tVerb, tStart
   put true into tStart
   repeat for each item tItem in pCode
      if tStart then put _Lower(pTokens[tItem]["t"]) into tVerb
      if tItem = pIndex then exit repeat
      put _Lower(pTokens[tItem]["t"]) is among the words of "then else" into tStart
   end repeat
   return tVerb
end _StatementVerb

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

-- Whether the statement that starts with the token at pIndex goes on to
-- the end of the statement (the line, or else) with values only: numbers,
-- strings, the handler's variables, commas and signs; nothing that a
-- command of this engine would read as its own words ("sort lines of x")
private function _PlainCall pTokens, pCode, pIndex, pVars
   local tItem, tFound, tKind, tWord
   repeat for each item tItem in pCode
      if not tFound then
         if tItem = pIndex then put true into tFound
         next repeat
      end if
      put pTokens[tItem]["k"] into tKind
      put _Lower(pTokens[tItem]["t"]) into tWord
      if tKind is "w" and tWord is "else" then return true
      if tKind is among the words of "n s" then next repeat
      if tKind is "p" and (tWord is comma or tWord is "-" or tWord is "+") then next repeat
      if tKind is "w" and pVars[tWord] then next repeat
      return false
   end repeat
   return true
end _PlainCall

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
            -- "into me" in a field's or a button's script: the control, in
            -- HyperCard as here ("put mPP - 15 into me", a field's), not a
            -- variable. (Elsewhere, where it is no container, it is the
            -- variable T2 renames, as it was: "put (userName contains
            -- "Ari Halberstadt") into me", a stack's openStack)
            if _T(tTokens, tNext) is "me" and _MeIsControl() then next repeat
            if _T(tTokens, tAfter) is "of" then next repeat
            if tAfter is not empty and tTokens[tAfter]["k"] is "n" then next repeat
            if tAfter is not empty and _T(tTokens, tAfter) is among the words of kObjectWords then next repeat
            put true into tVars[_T(tTokens, tNext)]
         end if
      end repeat
   end repeat
   return tVars
end _HandlerVariables

-- Whether the script being fixed is a field's or a button's, whose "me"
-- is the control's text, here as in HyperCard: its long id begins "field
-- id" or "button id" ("card field id", "bkgnd button id" with HyperCard's
-- addressing). (revHyperCardRewriteScript's script is no object's)
private function _MeIsControl
   if word 1 of sObject is among the words of "card bkgnd" then return word 2 of sObject is among the words of "field button"
   return word 1 of sObject is among the words of "field button"
end _MeIsControl

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
   -- (T34: "the short target", "the long date")
   if tPrev is among the words of "the go long short abbreviated abbrev abbr english" then return false
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

-- Whether the code token pOf is "of" with the objects of a count after
-- it ("of card fields", "of btns"), as in "field number of card fields"
-- (T37, _ParserForms)
private function _CountOfObjects pTokens, pCode, pOf
   local tAt
   if pOf is empty or _T(pTokens, pOf) is not "of" then return false
   put _NextCode(pCode, pOf) into tAt
   if _T(pTokens, tAt) is among the words of "card cd background bkgnd bg" then put _NextCode(pCode, tAt) into tAt
   return _T(pTokens, tAt) is among the words of "fields flds buttons btns cards cds"
end _CountOfObjects

-- T3: a word of the grammar as an object's name, which HyperCard took for
-- the name where nothing else could follow the object: a preposition
-- after a field or a button whose name it ends ("show field TO", "if
-- line i of fld to is empty", Logo's; "put fld By into theitems", Order
-- Form's; "hide cd fld BY", Thermo's), and after the card of a go that it
-- ends, a preposition, an object's word or a part of a card ("go card
-- At", "go card In", "go card Cd", ChemElements' cards named for the
-- elements; "go cd characters", Runes'; "go to card buttons", Canary's).
-- Not after "the", "this", "next" or an ordinal ("go next card in a new
-- window"), and not a card's "next" or "prev"
private function _GrammarName pTokens, pCode, pIndex, pPrev, pNext
   local tWord, tObject, tBefore
   put _T(pTokens, pIndex) into tWord
   put _T(pTokens, pPrev) into tObject
   put _PrevCode(pCode, pPrev) into tBefore
   if tBefore is not empty and (_T(pTokens, tBefore) is among the words of "the this next prev previous" \
         or _T(pTokens, tBefore) is among the words of kChunkOrdinals) then
      return false
   end if
   if tObject is among the words of "field fld button btn" then
      return tWord is among the words of "to into in by from at with" and _NameEnds(pTokens, pCode, pNext)
   end if
   if tObject is not among the words of "card cd" or tBefore is empty then return false
   if pNext is not empty and _T(pTokens, pNext) is not "else" then return false
   if _T(pTokens, tBefore) is not "go" and not (_T(pTokens, tBefore) is "to" and _T(pTokens, _PrevCode(pCode, tBefore)) is "go") then
      return false
   end if
   return tWord is among the words of "to into in by from at with" or tWord is among the words of kObjectWords \
         or (tWord is among the words of kNeverNamesAfterCard and tWord is not among the words of "next prev previous")
end _GrammarName

-- The rules that work on one line of a handler (pContinued: the line
-- goes on with the statement of the line before; pThen: the line ends
-- with \, and this is the first code token of the next, as _FirstCode
-- gives it)
private function _RewriteLine pLine, pVars, pRename, pExternals, pRenameHandlers, pContinued, pThen
   local tTokens, tCode, tIndex, tPrev, tNext, tWord, tNew, tFirst, tAfter, tChanged
   local tLine, tThen

   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put item 1 of tCode into tFirst
   -- the token after the \ at the end, past the end of the line's tokens
   -- (so that _Join leaves it out), for T2 to read
   if pThen is an array and item -1 of tCode is not empty and _T(tTokens, item -1 of tCode) is "\" then
      put tTokens["count"] + 1 into tThen
      put pThen into tTokens[tThen]
   end if

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
      -- and calls to it (T62: a function of the stack that this engine
      -- takes a call of for something else, and its calls)
      if pRenameHandlers[tWord] is not empty then
         if _T(tTokens, tPrev) is among the words of "on function end pass exit" \
               and (tPrev = tFirst or _T(tTokens, tPrev) is among the words of "pass exit") then
            put pRenameHandlers[tWord] into tTokens[tIndex]["t"]
            if _HandlerRefused(tWord) then
               _Fire "T1 handler named like a keyword"
            else
               _Fire "T62 a function named like a word of this engine"
            end if
            next repeat
         end if
         if tWord is "domenu" or tWord is not among the words of kCommands then
            if (_StatementStart(tTokens, tCode, tIndex) and _HandlerRefused(tWord)) \
                  or (_T(tTokens, tNext) is "(" and _T(tTokens, tPrev) is not "the" and (_HandlerRefused(tWord) or _Reached(tWord))) then
               put pRenameHandlers[tWord] into tTokens[tIndex]["t"]
               if tWord is "domenu" then
                  _Fire "T15 doMenu to hcDoMenu"
               else if _HandlerRefused(tWord) then
                  _Fire "T1 handler named like a keyword"
               else
                  _Fire "T62 a function named like a word of this engine"
               end if
               next repeat
            end if
         else if _StatementStart(tTokens, tCode, tIndex) and _PlainCall(tTokens, tCode, tIndex, pVars) then
            -- ... and a call to one named like a command of this engine
            -- ("sort", "rename i", "remove") made as a handler is called,
            -- with nothing but values: HyperCard sent it to the handler
            put pRenameHandlers[tWord] into tTokens[tIndex]["t"]
            _Fire "T1 handler named like a keyword"
            next repeat
         end if
      end if

      -- T44: an object called home, its name not in quotes ("go to card
      -- home", Zaum Gadget's, whose card is called Home; "hide bg btn
      -- home"), which this engine reads as the "home" of "go home" and
      -- refuses: in quotes, as HyperCard took it, or the value of the
      -- handler's variable called home, which HyperCard took first (a
      -- stack called home is HyperCard's Home: T45)
      if tWord is "home" and _T(tTokens, tPrev) is among the words of "field fld button btn card cd background bkgnd bg" \
            and _T(tTokens, tNext) is not "(" then
         if pVars["home"] then
            put "(" & tTokens[tIndex]["t"] & ")" into tTokens[tIndex]["t"]
         else
            put quote & tTokens[tIndex]["t"] & quote into tTokens[tIndex]["t"]
            put "s" into tTokens[tIndex]["k"]
         end if
         _Fire "T44 object name that is a constant here"
         next repeat
      end if

      -- T13: an external named like a keyword (but a function's call
      -- reaches the stack's own function of that name, T47)
      if pExternals[tWord] and tWord is not among the words of kHyperTalkCommands \
            and tWord is not among the words of "set put get go if send do add show hide" \
            and (tWord is among the words of kCommands or tWord is among the words of kRefused or _HandlerRefused(tWord)) then
         if _StatementStart(tTokens, tCode, tIndex) or (_T(tTokens, tNext) is "(" and _T(tTokens, tPrev) is not "the" and not sStackFunctions[tWord]) then
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

      -- T2: a variable whose name is refused (where the word is last
      -- before a \ that ends the line, read with the token after it: "or
      -- menu \" then "is "Paste Card"", a doMenu's parameter)
      if pRename[tWord] is "where" then
         if tThen is not empty and tNext is item -1 of tCode and _T(tTokens, tNext) is "\" then put tThen into tAfter
         else put tNext into tAfter
         if _VariableHere(tTokens, tWord, tPrev, tAfter) then
            put "hc_" & tTokens[tIndex]["t"] into tTokens[tIndex]["t"]
            _Fire "T2 variable named like a keyword"
            next repeat
         end if
      else if pRename[tWord] is true then
         -- (T34: not "the long date", nor "the number of items in it";
         -- nor the format of a convert, "convert now to seconds" in a
         -- handler with a variable named seconds, On This Date's)
         -- (nor the menu bar a hide or a show names, "hide menuBar" in a
         -- handler with a variable named menuBar, Battle of Britain's)
         if _T(tTokens, tPrev) is not among the words of "the set long short abbreviated abbrev abbr english" \
               and not (_T(tTokens, tPrev) is "of" and _T(tTokens, tNext) is "in") \
               and not (tWord is "menubar" and _T(tTokens, tPrev) is among the words of "hide show") \
               and not (_T(tTokens, tNext) is "of" and _T(tTokens, tPrev) is not among the words of "char character word item line to into" \
               and _T(tTokens, tPrev) is not among the words of kObjectWords and tWord is not among the words of kOfVariables) \
               and not (_T(tTokens, tPrev) is "to" and tWord is "seconds" and _StatementVerb(tTokens, tCode, tIndex) is "convert") then
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
      -- field title of this card"); not "number of card fields", a
      -- count (T37, _ParserForms)
      if tPrev is not empty and not pVars[tWord] and tWord is not among the words of kNeverNames \
            and _T(tTokens, tFirst) is not "choose" \
            and not (tWord is "number" and _CountOfObjects(tTokens, tCode, tNext)) \
            and (_T(tTokens, tPrev) is among the words of "field fld button btn" \
            or (_T(tTokens, tPrev) is among the words of "card cd background bkgnd bg" and tWord is not among the words of kObjectWords \
            and tWord is not among the words of kNeverNamesAfterCard)) \
            and _NameEnds(tTokens, tCode, tNext) and _NameRefused(tWord) then
         put quote & tTokens[tIndex]["t"] & quote into tTokens[tIndex]["t"]
         put "s" into tTokens[tIndex]["k"]
         _Fire "T3 object name that is a keyword quoted"
         next repeat
      end if
      -- ... and a word of the grammar, which kNeverNames keeps from the
      -- names above, where it can be nothing else (_GrammarName)
      if tPrev is not empty and not pVars[tWord] and _GrammarName(tTokens, tCode, tIndex, tPrev, tNext) then
         put quote & tTokens[tIndex]["t"] & quote into tTokens[tIndex]["t"]
         put "s" into tTokens[tIndex]["k"]
         _Fire "T3 object name that is a keyword quoted"
         next repeat
      end if
   end repeat
   put _Join(tTokens) into pLine

   put _PhraseRules(pLine, pThen) into pLine
   put _ParserForms(pLine, pVars) into pLine
   put _ExternalArguments(pLine, pVars, pExternals, pContinued) into pLine
   put _LineCommands(pLine) into tLine
   if tLine is not pLine then return tLine
   put _PlayNotes(pLine) into pLine
   return _Visual(pLine)
end _RewriteLine

-- T4, T6, T7, T9, T10, T11: phrases, matched on tokens (pThen: as
-- _RewriteLine has it)
private function _PhraseRules pLine, pThen
   local tTokens, tCode, tCount, i, tIdx, tWords, tItem, n, tWord, tNext, tNext2, tPrev
   local tFirstWord, tAt, tOf

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

      -- T63: a mark of punctuation alone as a value ("set the itemDelimiter
      -- to :", "if theKey = . then", "digest sb,.,sa", "put the round of
      -- x &% into field score", "put ~&it into field "images""), which
      -- HyperCard took as the text it was, like a word not in quotes, and
      -- this engine refuses (# starts a comment here): in quotes. Not one
      -- that touches a word or a number ("5.", "10:30", "Stack.Name"), nor
      -- one that is not between an operator or a statement's verb and the
      -- end of a value
      if tTokens[tIdx[i]]["k"] is "p" and tWord is among the words of ". : % ~ ! #" \
            and tTokens[tIdx[i] - 1]["k"] is not among the words of "w n" and tTokens[tIdx[i] + 1]["k"] is not among the words of "w n" \
            and tPrev is among the words of "( , & + - * / = < > ^ is put return to and or not contains then else get with" \
            and (tNext is empty or tNext is among the words of kAfterValue) then
         put quote & tTokens[tIdx[i]]["t"] & quote into tTokens[tIdx[i]]["t"]
         put "s" into tTokens[tIdx[i]]["k"]
         _Fire "T63 a mark of punctuation as a value"
         next repeat
      end if

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

      -- T7: functions HyperTalk let a script write without "the" (and
      -- where the line ends with \ before their "of", "the rect of btn
      -- item 2 of value\" then "of the foundLine", Lesson 1 Severn
      -- Ojibwe's)
      put tNext into tOf
      if tNext is "\" and i + 1 = n and pThen is an array then put _Lower(pThen["t"]) into tOf
      if tWord is among the words of kOneArgFunctions and tOf is "of" and tPrev is not "the" and tTokens[tIdx[i]]["k"] is "w" then
         put "the " before tTokens[tIdx[i]]["t"]
         _Fire "T7 function without the"
         next repeat
      end if
      if tWord is "number" and tOf is "of" and tPrev is not "the" and tTokens[tIdx[i]]["k"] is "w" \
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

      -- T6: visual ... to cd (T34: and unlock screen with visual ... to cd)
      if (tFirstWord is "visual" or (tFirstWord is "unlock" and "visual" is among the words of pLine)) \
            and tWord is "cd" and tPrev is "to" then
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
      -- (and "the short version of HyperCard", which this engine refuses,
      -- HyperCard's version: "if short version of hypercard > 2.2 then"
      -- too)
      if tWord is "version" and tPrev is "short" and tNext is "of" and tNext2 is "hypercard" then
         if _T(tTokens, tIdx[i - 2]) is "the" then
            _Replace tTokens, tIdx, i - 2, i + 2, "hcVersion()"
         else
            _Replace tTokens, tIdx, i - 1, i + 2, "hcVersion()"
         end if
         _Fire "T10 HyperCard's version"
         next repeat
      end if

      -- T61: HyperCard 2.2's speech functions ("if the speech is not done
      -- then stop speech", "get line 1 of the voices", "if voices() is
      -- empty"), which this engine has not: the library's hcSpeech() and
      -- hcVoices(); with parentheses, unless the stack has a function of
      -- that name. (Stop speech: _HyperCardRules)
      if tWord is among the words of "speech voices" and tTokens[tIdx[i]]["k"] is "w" \
            and ((tPrev is "the" and tNext is not "of") \
            or (tNext is "(" and tNext2 is ")" and not sStackFunctions[tWord] and tPrev is not among the words of "the function on end")) then
         if tPrev is "the" then
            _Replace tTokens, tIdx, i - 1, i, "hc" & toUpper(char 1 of tWord) & char 2 to -1 of tWord & "()"
         else
            _Replace tTokens, tIdx, i, i + 2, "hc" & toUpper(char 1 of tWord) & char 2 to -1 of tWord & "()"
         end if
         _Fire "T61 HyperCard's speech"
         next repeat
      end if

      -- T64: HyperCard's global properties this engine has not, read ("put
      -- the dialingTime into SaveDialingTime", "put the language into
      -- oldlanguage"), which it does not compile: the library's
      -- hcProperty(), which gives back what a script set (a set is
      -- _SetHyperCardProperty's) or HyperCard's own value
      if tWord is among the words of kHyperCardProperties and tPrev is "the" and tNext is not "of" \
            and _T(tTokens, tIdx[i - 2]) is not "set" then
         _Replace tTokens, tIdx, i - 1, i, "hcProperty(" & quote & _HyperCardPropertyName(tWord) & quote & ")"
         _Fire "T64 HyperCard's global properties"
         next repeat
      end if

      -- T11: an object named by its type alone: "of cd", "of bkgnd", "the
      -- size of stack"
      if tWord is among the words of "bkgnd bg background cd card stack" and (tPrev is "of" or (tPrev is "to" and _StatementWord(tTokens, tIdx, i) is "send")) \
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
         put i into tAt
         if tPrev is "the" then subtract 1 from tAt
         -- (show and hide card window go to the library's hcWindow, which
         -- _ShowHide makes: T46)
         if tAt > 1 and _T(tTokens, tIdx[tAt - 1]) is among the words of "show hide" \
               and _StatementWord(tTokens, tIdx, tAt - 1) is _T(tTokens, tIdx[tAt - 1]) then next repeat
         -- T46: HyperCard read and set a card window's location by its
         -- top left on the screen, and this engine a stack's by its centre
         if tAt > 2 and _T(tTokens, tIdx[tAt - 1]) is "of" and _T(tTokens, tIdx[tAt - 2]) is among the words of "loc location" then
            put "topLeft" into tTokens[tIdx[tAt - 2]]["t"]
            _Fire "T46 HyperCard's windows"
         end if
         _Replace tTokens, tIdx, tAt, i + 1, "this stack"
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
      -- ("the name of card it in bkgnd 2" too); not the operator "is in"
      -- after one ("if the short name of this cd is in cd fld "Index"",
      -- which "of" made a line that does not compile), nor find's "in"
      -- before the field it looks in (_FindsIn)
      if tWord is "in" and tNext is among the words of "card cd bkgnd bg background stack" and i > 2 \
            and not _FindsIn(tTokens, tIdx, i) \
            and (tPrev is among the words of kObjectWords \
            or (tTokens[tIdx[i - 1]]["k"] is among the items of "s,n,w" and tPrev is not "is" \
            and _T(tTokens, tIdx[i - 2]) is among the words of kObjectWords) \
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
   local tTokens, tCode, tIdx, n, tItem, i, j, k, tEnd, tWord, tDepth, tAt, tTypes, tBefore, tLength, tCard
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
            -- T37: answer info, ask question with x: a variable named like
            -- an icon this engine's answer and ask take first, alone or
            -- before "with": in parentheses, a value
            if tTokens[tIdx[i + 1]]["k"] is "w" and _T(tTokens, tIdx[i + 1]) is among the words of "info information question error warning" \
                  and (i + 1 = tEnd or _T(tTokens, tIdx[i + 2]) is "with") then
               put "(" before tTokens[tIdx[i + 1]]["t"]
               put ")" after tTokens[tIdx[i + 1]]["t"]
               _Fire "T37 more forms HyperCard took"
            end if
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
                     -- (a comma made " or " above is "or" here, T34)
                     if tTokens[tIdx[j]]["k"] is "w" and (word 1 of _T(tTokens, tIdx[j - 1]) is among the words of "with or" or _T(tTokens, tIdx[j - 1]) is ",") \
                           and (j = tEnd or word 1 of _T(tTokens, tIdx[j + 1]) is "or" or _T(tTokens, tIdx[j + 1]) is ",") \
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
         case "put"
            -- T35: put x in y, which HyperCard took as put x into y (one
            -- value before "in" only: "put the number of words in x" is a
            -- count put into the message box, and stays as it is)
            if i + 3 <= tEnd and _T(tTokens, tIdx[i + 2]) is "in" \
                  and tTokens[tIdx[i + 1]]["k"] is among the items of "w,s,n" \
                  and _T(tTokens, tIdx[i + 1]) is not among the words of "the ( -" then
               put true into tAt
               repeat with j = i + 3 to tEnd
                  if _T(tTokens, tIdx[j]) is among the words of "into before after" then put false into tAt
               end repeat
               if tAt then
                  put "into" into tTokens[tIdx[i + 2]]["t"]
                  _Fire "T35 more forms HyperCard took"
               end if
            end if
            -- T35: put on into x, put off into x: the words "on" and "off"
            if i + 2 <= tEnd and _T(tTokens, tIdx[i + 1]) is among the words of "on off" and not pVars[_T(tTokens, tIdx[i + 1])] \
                  and _T(tTokens, tIdx[i + 2]) is among the words of "into before after" then
               put quote & tTokens[tIdx[i + 1]]["t"] & quote into tTokens[tIdx[i + 1]]["t"]
               put "s" into tTokens[tIdx[i + 1]]["k"]
               _Fire "T35 more forms HyperCard took"
            end if
            -- T37: put header into x: a variable named like a word this
            -- engine's put takes first, for a server ("put header",
            -- "put content", "put unicode"): in parentheses, a value
            if i + 1 <= tEnd and tTokens[tIdx[i + 1]]["k"] is "w" \
                  and _T(tTokens, tIdx[i + 1]) is among the words of "header content markup binary unicode secure httponly cookie" \
                  and (i + 1 = tEnd or _T(tTokens, tIdx[i + 2]) is among the words of "into before after & , + - * / ^") then
               put "(" before tTokens[tIdx[i + 1]]["t"]
               put ")" after tTokens[tIdx[i + 1]]["t"]
               _Fire "T37 more forms HyperCard took"
            end if
            break
         case "mark"
         case "unmark"
            -- T37: mark card, unmark cd: the card it is on, as for go
            if i + 1 = tEnd and _T(tTokens, tIdx[i + 1]) is among the words of "card cd" then
               put "this " before tTokens[tIdx[i + 1]]["t"]
               _Fire "T37 more forms HyperCard took"
            end if
            break
         case "domenu"
         case "hcdomenu"
            -- T35: doMenu Next, doMenu last: one word not in quotes that
            -- this engine refuses as a value (T27 takes two or more), the
            -- menu item's name as HyperCard took it
            if i + 1 = tEnd and tTokens[tIdx[i + 1]]["k"] is "w" and not pVars[_T(tTokens, tIdx[i + 1])] \
                  and (_T(tTokens, tIdx[i + 1]) is among the words of kRefused or _T(tTokens, tIdx[i + 1]) is among the words of kGoPlaces \
                  or _T(tTokens, tIdx[i + 1]) is among the words of kObjectWords or _ValueRefused(_T(tTokens, tIdx[i + 1]))) then
               put quote & tTokens[tIdx[i + 1]]["t"] & quote into tTokens[tIdx[i + 1]]["t"]
               put "s" into tTokens[tIdx[i + 1]]["k"]
               _Fire "T35 more forms HyperCard took"
            end if
            break
         case "play"
            -- T35: play harpsichord c d e f (and after "tempo 200"): the
            -- notes not in quotes, which HyperCard read as the text they
            -- were; one word that is a variable of the handler, or it,
            -- stays ("play "Harpsichord" tempo 150 it", Tiny Tim's), and
            -- so does an expression ("play x line n of tNotes": a note is
            -- never "of" or "the"), and a line that goes on after "\".
            -- The sound, and the tempo, can be in a field of the card or
            -- the background ("play cd fld 1 tempo card field speed c d
            -- e": T49 puts the sound's in parentheses). Another tempo is
            -- one word or number: one in another field or an expression
            -- ("tempo field 2", "tempo the speed of me") leaves the line
            -- as it is. The sound can be in quotes, or an expression in
            -- parentheses, too ("if qq>1 then play "Harpsichord" g3q d4 e
            -- ch", Home Improvements', "play (field "Name") tempo 220 cq e
            -- f gw", Resource Library's: T5 takes a sound in quotes only
            -- at the start of its line). A sound named by one word alone,
            -- or before the tempo, that this engine's play takes for its
            -- own ("play step", Garbage's, which here is a video's "step
            -- forward" with no clip, and does not compile) or refuses as a
            -- value, which HyperCard took as the sound's name, is put in
            -- quotes; "play stop" was HyperCard's own too
            put _PlayObject(tTokens, tIdx, i + 1, tEnd) into j
            if j is 0 and _T(tTokens, tIdx[i + 1]) is "(" then
               put 0 into tDepth
               repeat with j = i + 1 to tEnd
                  if _T(tTokens, tIdx[j]) is "(" then add 1 to tDepth
                  if _T(tTokens, tIdx[j]) is ")" then subtract 1 from tDepth
                  if tDepth = 0 then exit repeat
               end repeat
               if j > tEnd then
                  break
               end if
            else if j is 0 and tTokens[tIdx[i + 1]]["k"] is "w" and not pVars[_T(tTokens, tIdx[i + 1])] \
                  and (i + 1 = tEnd or _T(tTokens, tIdx[i + 2]) is "tempo") \
                  and _T(tTokens, tIdx[i + 1]) is not among the words of "stop tempo" \
                  and (_T(tTokens, tIdx[i + 1]) is among the words of "step pause resume video" \
                  or _ValueRefused(_T(tTokens, tIdx[i + 1]))) then
               put quote & tTokens[tIdx[i + 1]]["t"] & quote into tTokens[tIdx[i + 1]]["t"]
               put "s" into tTokens[tIdx[i + 1]]["k"]
               _Fire "T35 more forms HyperCard took"
            end if
            if j is 0 then put i + 1 into j
            add 1 to j
            if _T(tTokens, tIdx[j]) is "tempo" then
               put _PlayObject(tTokens, tIdx, j + 1, tEnd) into k
               if k > 0 then
                  put k + 1 into j
               else if _T(tTokens, tIdx[j + 1]) is among the words of kObjectWords or _T(tTokens, tIdx[j + 1]) is among the words of "the (" then
                  put tEnd + 1 into j
               else
                  add 2 to j
               end if
            end if
            -- (after a sound in quotes or in parentheses, notes of one
            -- word stay as they are, which this engine reads as the text
            -- they are, or the variable HyperCard read too)
            if ((tTokens[tIdx[i + 1]]["k"] is "s" or _T(tTokens, tIdx[i + 1]) is "(") and j < tEnd \
                  or tTokens[tIdx[i + 1]]["k"] is "w" and _T(tTokens, tIdx[i + 1]) is not among the words of "stop tempo" and j <= tEnd) \
                  and not (j = tEnd and (pVars[_T(tTokens, tIdx[j])] or _T(tTokens, tIdx[j]) is "it")) then
               put true into tAt
               repeat with k = j to tEnd
                  if tTokens[tIdx[k]]["k"] is "s" or _T(tTokens, tIdx[k]) is among the words of "& && ( ) , then else of the \" then
                     put false into tAt
                     exit repeat
                  end if
               end repeat
               if tAt and j = tEnd and tTokens[tIdx[j]]["k"] is not "w" then put false into tAt
               if tAt then
                  -- (apart from a sound in quotes they were written
                  -- against: "play "boing"c d e")
                  get quote & _Span(tTokens, tIdx, j, tEnd) & quote
                  if tTokens[tIdx[j] - 1]["k"] is not "sp" then put space before it
                  _Replace tTokens, tIdx, j, tEnd, it
                  _Fire "T35 more forms HyperCard took"
               end if
            end if
            break
         case "find"
            -- T37: find string, a word of find's forms alone that is a
            -- variable of the handler ("on searchStackFor string", Windoid's
            -- MultiWord Find), which HyperCard took for the text to find:
            -- in parentheses, a value
            if i + 1 = tEnd and tTokens[tIdx[i + 1]]["k"] is "w" and pVars[_T(tTokens, tIdx[i + 1])] \
                  and _T(tTokens, tIdx[i + 1]) is among the words of "whole string words word chars characters normal" then
               put "(" before tTokens[tIdx[i + 1]]["t"]
               put ")" after tTokens[tIdx[i + 1]]["t"]
               _Fire "T37 more forms HyperCard took"
            end if
            break
         case "select"
            -- T34: select "", which HyperCard took as select empty
            if i + 1 = tEnd and tTokens[tIdx[i + 1]]["t"] is quote & quote then
               put "empty" into tTokens[tIdx[i + 1]]["t"]
               put "w" into tTokens[tIdx[i + 1]]["k"]
               _Fire "T34 more forms HyperCard took"
               break
            end if
            -- T75: select (theLine), select fieldData(), select after text
            -- of fieldData(): the object or the chunk a value names, in
            -- parentheses or from a function of the stack, which HyperCard
            -- selected as if it were written there (the arrow keys of the
            -- Guide to XCMDs put the selectedLine into theLine, add 1 to
            -- its word 2 and select (theLine); WB2D's buttons select
            -- fieldData(), which returns "card field id 13"). This
            -- engine's select takes a variable, or one of its own
            -- functions, there, and refuses a value in parentheses or a
            -- call of a handler, so the script did not compile: "do" with
            -- the statement and the value after it, which reads the value
            -- as HyperCard did
            put i + 1 into j
            if _T(tTokens, tIdx[j]) is among the words of "before after" then add 1 to j
            if _T(tTokens, tIdx[j]) is "text" and _T(tTokens, tIdx[j + 1]) is "of" then add 2 to j
            if j < tEnd and _SelectValue(tTokens, tIdx, j, tEnd) then
               put "do" && quote & _Span(tTokens, tIdx, i, j - 1) & quote && "&&" into tItem
               _Replace tTokens, tIdx, i, j - 1, tItem
               _Fire "T75 select a value"
            end if
            break
         case "repeat"
            -- T34: repeat with i is 1 to n
            if _T(tTokens, tIdx[i + 1]) is "with" and tTokens[tIdx[i + 2]]["k"] is "w" \
                  and _T(tTokens, tIdx[i + 3]) is "is" and i + 3 < tEnd then
               put "=" into tTokens[tIdx[i + 3]]["t"]
               _Fire "T34 more forms HyperCard took"
            end if
            break
         case "sort"
            -- T34: sort the lines of x, sort the items of x
            if _T(tTokens, tIdx[i + 1]) is "the" and _T(tTokens, tIdx[i + 2]) is among the words of "lines items" \
                  and _T(tTokens, tIdx[i + 3]) is "of" then
               put empty into tTokens[tIdx[i + 1]]["t"]
               _ClearSpaceAfter tTokens, tIdx[i + 1]
               _Fire "T34 more forms HyperCard took"
            end if
            break
         case "go"
            -- T37: go cd, go to card: the card it is on, as HyperCard took
            -- "card" with nothing after it (a script went there to show a
            -- visual effect, or to draw the card again)
            put i + 1 into j
            if _T(tTokens, tIdx[j]) is "to" then add 1 to j
            if j = tEnd and _T(tTokens, tIdx[j]) is among the words of "card cd" then
               put "this " before tTokens[tIdx[j]]["t"]
               _Fire "T37 more forms HyperCard took"
               break
            end if
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

      -- T35: "on" and "off" as values ("if vsound = on"), which HyperCard
      -- took as their own text
      repeat with j = i + 1 to tEnd
         if _T(tTokens, tIdx[j]) is not among the words of "on off" or tTokens[tIdx[j]]["k"] is not "w" then next repeat
         if pVars[_T(tTokens, tIdx[j])] then next repeat
         if _T(tTokens, tIdx[j - 1]) is not among the words of "= <> is not" then next repeat
         if j < tEnd and _T(tTokens, tIdx[j + 1]) is not among the words of "then and or )" then next repeat
         put quote & tTokens[tIdx[j]]["t"] & quote into tTokens[tIdx[j]]["t"]
         put "s" into tTokens[tIdx[j]]["k"]
         _Fire "T35 more forms HyperCard took"
      end repeat

      -- T37: any other word this engine refuses as a value, alone where
      -- only a value can be and no variable of the handler ("if it = No",
      -- "if (iName = First)", "if movie is in the result", "put in into
      -- meas", "put stacks into whichField"): HyperCard took it as its
      -- own text
      repeat with j = i + 1 to tEnd
         if tTokens[tIdx[j]]["k"] is not "w" then next repeat
         if pVars[_T(tTokens, tIdx[j])] or _T(tTokens, tIdx[j]) is among the words of "on off" then next repeat
         if not _AloneAsValue(tTokens, tIdx, i, j, tEnd) or not _ValueRefused(_T(tTokens, tIdx[j])) then next repeat
         put quote & tTokens[tIdx[j]]["t"] & quote into tTokens[tIdx[j]]["t"]
         put "s" into tTokens[tIdx[j]]["k"]
         _Fire "T37 more forms HyperCard took"
      end repeat

      -- T37: the number of marked card i, which HyperCard took as the
      -- number of the i-th marked card, and this engine as the number of
      -- marked cards (then "card i" is left over): the number of the card
      -- with that card's id (its short id: in a stack with HyperCard's
      -- rules, the id of a card is "card id 1234", as in HyperCard)
      repeat with j = i to tEnd - 5
         if _T(tTokens, tIdx[j]) is "the" and _T(tTokens, tIdx[j + 1]) is "number" and _T(tTokens, tIdx[j + 2]) is "of" \
               and _T(tTokens, tIdx[j + 3]) is "marked" and _T(tTokens, tIdx[j + 4]) is among the words of "card cd" \
               and tTokens[tIdx[j + 5]]["k"] is among the items of "w,n" \
               and (j + 5 = tEnd or _T(tTokens, tIdx[j + 6]) is among the words of kAfterValue) then
            _Replace tTokens, tIdx, j, j + 5, "the number of card id (the short id of marked card" && tTokens[tIdx[j + 5]]["t"] & ")"
            _Fire "T37 more forms HyperCard took"
         end if
      end repeat

      -- T37: a card "in" this background ("go cd "Index" in this bg",
      -- "there is a cd id it in this bg"), where HyperCard took "in" as
      -- "of": "of"
      repeat with j = i + 2 to tEnd - 2
         if _T(tTokens, tIdx[j]) is not "in" or _T(tTokens, tIdx[j + 1]) is not "this" \
               or _T(tTokens, tIdx[j + 2]) is not among the words of "background bkgnd bg" then next repeat
         put j - 2 into k
         if k > i and _T(tTokens, tIdx[k]) is "id" then subtract 1 from k
         if _T(tTokens, tIdx[k]) is among the words of "card cd" and tTokens[tIdx[j - 1]]["k"] is among the items of "s,n,w" \
               and _T(tTokens, tIdx[j - 1]) is not among the words of "the a an of in into to and or not is" then
            put "of" into tTokens[tIdx[j]]["t"]
            _Fire "T37 more forms HyperCard took"
         end if
      end repeat

      -- T37: an object or a chunk numbered by a count without "the"
      -- ("card field number of card fields", "item number of me of x",
      -- "line number of lines of t - 1 of t"), which HyperCard took as
      -- the count: the count in parentheses, with "the". A count of a
      -- chunk ends where its container begins again
      repeat with j = i + 1 to tEnd - 2
         if _T(tTokens, tIdx[j]) is not "number" or _T(tTokens, tIdx[j + 1]) is not "of" then next repeat
         put _T(tTokens, tIdx[j - 1]) into tBefore
         put empty into tAt
         if tBefore is among the words of "field fld button btn card cd" then
            put j + 2 into k
            if _T(tTokens, tIdx[k]) is among the words of "card cd background bkgnd bg" then add 1 to k
            if k <= tEnd and _T(tTokens, tIdx[k]) is among the words of "fields flds buttons btns cards cds" then
               put k into tAt
            end if
         else if tBefore is among the words of "char character word item line" then
            if _T(tTokens, tIdx[j + 2]) is "me" then
               put j + 2 into tAt
            else if j + 5 <= tEnd and _T(tTokens, tIdx[j + 2]) is among the words of "chars characters words items lines" \
                  and _T(tTokens, tIdx[j + 3]) is "of" then
               repeat with k = j + 5 to tEnd - 1
                  if _T(tTokens, tIdx[k]) is not "of" then next repeat
                  repeat with tLength = 1 to min(tEnd - k, k - j - 4)
                     if (k + tLength = tEnd or _T(tTokens, tIdx[k + tLength + 1]) is among the words of kAfterValue) \
                           and _Lower(_Span(tTokens, tIdx, j + 4, j + 3 + tLength)) is _Lower(_Span(tTokens, tIdx, k + 1, k + tLength)) then
                        put k - 1 into tAt
                        exit repeat
                     end if
                  end repeat
                  if tAt is not empty then exit repeat
               end repeat
            end if
         end if
         if tAt is empty then next repeat
         put "(the " before tTokens[tIdx[j]]["t"]
         put ")" after tTokens[tIdx[tAt]]["t"]
         _Fire "T37 more forms HyperCard took"
      end repeat

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

      -- T34: char x to the length of fld "body" of fld "body": as above,
      -- the length's object ended where the same object began again
      repeat with j = i to tEnd - 6
         if _T(tTokens, tIdx[j]) is "to" and _T(tTokens, tIdx[j + 1]) is "the" and _T(tTokens, tIdx[j + 2]) is "length" \
               and _T(tTokens, tIdx[j + 3]) is "of" then
            repeat with k = j + 5 to tEnd - 1
               if k + (k - j - 4) > tEnd then exit repeat
               if _T(tTokens, tIdx[k]) is "of" \
                     and _Lower(_Span(tTokens, tIdx, j + 4, k - 1)) is _Lower(_Span(tTokens, tIdx, k + 1, k + (k - j - 4))) then
                  put "(" before tTokens[tIdx[j + 1]]["t"]
                  put ")" after tTokens[tIdx[k - 1]]["t"]
                  _Fire "T34 more forms HyperCard took"
                  exit repeat
               end if
            end repeat
         end if
      end repeat

      -- T34: a field or button as a chunk's number ("line bg fld "N" of
      -- bg fld "List"", which HyperCard took as the line the field's text
      -- numbers): the object in parentheses, with the card it is on when
      -- another "of" follows that ("line cd fld "N" of cd "Main" of cd
      -- fld "List"": no chunk is of a card)
      repeat with j = i to tEnd - 3
         if _T(tTokens, tIdx[j]) is not among the words of "char character word item line" then next repeat
         if j > 1 and _T(tTokens, tIdx[j - 1]) is "the" then next repeat
         put j + 1 into k
         if _T(tTokens, tIdx[k]) is among the words of "card cd background bkgnd bg" then add 1 to k
         if _T(tTokens, tIdx[k]) is not among the words of "field fld button btn" then next repeat
         add 1 to k
         if _T(tTokens, tIdx[k]) is "id" then add 1 to k
         if k >= tEnd or _T(tTokens, tIdx[k + 1]) is not "of" then next repeat
         if tTokens[tIdx[k]]["k"] is not among the items of "s,n,w" then next repeat
         if _T(tTokens, tIdx[k + 2]) is among the words of "card cd" \
               and _T(tTokens, tIdx[k + 3]) is not among the words of "field fld button btn" then
            put k + 3 into tCard
            if _T(tTokens, tIdx[tCard]) is "id" then add 1 to tCard
            if tCard < tEnd and _T(tTokens, tIdx[tCard + 1]) is "of" and tTokens[tIdx[tCard]]["k"] is among the items of "s,n,w" then
               put tCard into k
            end if
         end if
         put "(" before tTokens[tIdx[j + 1]]["t"]
         put ")" after tTokens[tIdx[k]]["t"]
         _Fire "T34 more forms HyperCard took"
      end repeat

      -- T34: the number of windows (HyperCard's, here the stacks' open
      -- windows)
      repeat with j = i to tEnd - 3
         if _T(tTokens, tIdx[j]) is "the" and _T(tTokens, tIdx[j + 1]) is "number" and _T(tTokens, tIdx[j + 2]) is "of" \
               and _T(tTokens, tIdx[j + 3]) is "windows" and _T(tTokens, tIdx[j + 4]) is not "of" then
            put "lines of the windows" into tTokens[tIdx[j + 3]]["t"]
            _Fire "T34 more forms HyperCard took"
         end if
      end repeat
   end repeat
   return _Join(tTokens)
end _ParserForms

-- T75: whether the code tokens pFrom to pTo are one value in parentheses,
-- or one call of a function of the stack (_StackFunction), and no more
private function _SelectValue pTokens, pIdx, pFrom, pTo
   local tDepth, k
   if _T(pTokens, pIdx[pFrom]) is not "(" then
      if pTokens[pIdx[pFrom]]["k"] is not "w" or not _StackFunction(_T(pTokens, pIdx[pFrom])) then return false
      add 1 to pFrom
      if _T(pTokens, pIdx[pFrom]) is not "(" then return false
   end if
   put 0 into tDepth
   repeat with k = pFrom to pTo
      if _T(pTokens, pIdx[k]) is "(" then add 1 to tDepth
      if _T(pTokens, pIdx[k]) is ")" then subtract 1 from tDepth
      if tDepth = 0 then return k = pTo
   end repeat
   return false
end _SelectValue

-- T75: whether pName is a function the stack defines, by its name or the
-- new one T1 or T62 gave it, and not one of this engine's own (a call of
-- which a select takes as it is)
private function _StackFunction pName
   local tOld
   if pName is among the lines of the functionNames then return false
   if sStackFunctions[pName] then return true
   repeat for each key tOld in sRenameHandlers
      if sStackFunctions[tOld] and _Lower(sRenameHandlers[tOld]) is pName then return true
   end repeat
   return false
end _StackFunction

-- T34: the arguments of an external (an XCMD or XFCN of the stack) that
-- are one word not in quotes and no value here ("ink on, 8", "video
-- sound, 2", "Version(numbers, stack)"). HyperCard passed such a word as
-- its own text when it was not a variable, so it goes in quotes: "on"
-- and "off" always, any other word only where a probe compile confirms
-- the engine refuses it as a value (a word it takes is its own text here
-- too, as a variable never set).
-- T37: the same for a call to one of the stack's own handlers
-- (sCallees), for a statement that calls a command this engine does not
-- have ("ResetBtns on", "timeStamp scrollBar", "gocd next, 1"), and for
-- HyperCard's picture command, which the library does (T18: "picture
-- "Chart", clipboard, zoom"); and
-- a comma that ends such a command's arguments ("showHistory "The
-- Outcome", 5,"), after which HyperCard passed an empty argument, gets
-- that argument. (pContinued: the line goes on with the statement of the
-- line before, so its first word starts none: "with optionKey")
-- pCompiled: the script compiles as it is, where only a word this engine
-- takes there for an object ("AddColor enableObject,cd,2": "can't find
-- card") or for something else ("url") goes in quotes; "on" and a comma
-- at the end never compile there, and every other word is its own text
private function _ExternalArguments pLine, pVars, pExternals, pContinued, pCompiled
   local tTokens, tCode, tIdx, n, tItem, i, j, tWord, tName, tDepth, tStart, tInCall, tStop, tRule, tLast, tCommand
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 1 to n
      if tTokens[tIdx[i]]["k"] is not "w" then next repeat
      put _T(tTokens, tIdx[i]) into tName
      if tName begins with "hcx_" then delete char 1 to 4 of tName
      -- (whether the word starts a statement)
      put (i = 1 and pContinued is not true) or (i > 1 and _T(tTokens, tIdx[i - 1]) is among the words of "then else") into tCommand
      if pExternals[tName] then
         put "T34 more forms HyperCard took" into tRule
      else if sCallees[tName] or (tCommand and (tName is "picture" or _UnknownCommand(tName, pVars))) then
         put "T37 more forms HyperCard took" into tRule
      else
         next repeat
      end if
      if _T(tTokens, tIdx[i + 1]) is "(" and _T(tTokens, tIdx[i - 1]) is not "the" then
         -- a call: the arguments inside its parentheses
         put true into tInCall
         put i + 2 into tStart
      else if tCommand then
         -- a command: its arguments to the end of the statement
         put false into tInCall
         put i + 1 into tStart
      else
         next repeat
      end if
      put 0 into tDepth
      put false into tStop
      put empty into tLast
      repeat with j = tStart to n
         put _T(tTokens, tIdx[j]) into tWord
         if not tInCall and tDepth = 0 and tWord is among the words of "then else" then exit repeat
         put j into tLast
         if tWord is "(" then
            add 1 to tDepth
            next repeat
         end if
         if tWord is ")" then
            subtract 1 from tDepth
            if tDepth < 0 then exit repeat
            next repeat
         end if
         if tDepth > 0 then next repeat
         if tTokens[tIdx[j]]["k"] is not "w" then next repeat
         -- one word alone between commas (or the bounds of the list)
         if j > tStart and _T(tTokens, tIdx[j - 1]) is not "," then next repeat
         if j < n and _T(tTokens, tIdx[j + 1]) is not "," and _T(tTokens, tIdx[j + 1]) is not ")" \
               and not (not tInCall and _T(tTokens, tIdx[j + 1]) is among the words of "then else") then next repeat
         if pVars[tWord] then next repeat
         if (tWord is among the words of "on off" and pCompiled is not true) or _ValueRefused(tWord) then
            put quote & tTokens[tIdx[j]]["t"] & quote into tTokens[tIdx[j]]["t"]
            put "s" into tTokens[tIdx[j]]["k"]
            _Fire tRule
         end if
      end repeat
      if not tInCall and tLast > tStart and _T(tTokens, tIdx[tLast]) is "," and pCompiled is not true then
         put ", empty" into tTokens[tIdx[tLast]]["t"]
         _Fire tRule
      end if
   end repeat
   return _Join(tTokens)
end _ExternalArguments

-- T37: whether a statement that starts with pName calls a command this
-- engine does not have (a handler of another stack, an external
-- elsewhere): not a command, a word of the grammar or a variable here.
-- Only with a probe, which knows every word of the grammar (without one,
-- _HandlerRefused knows only a list, and "the" or "of" would pass for a
-- command)
private function _UnknownCommand pName, pVars
   if sProbe is empty or pVars[pName] or not _IsName(pName) then return false
   if pName is among the words of kCommands or pName is among the words of kHyperTalkCommands \
         or pName is among the words of kNotCommands then return false
   return not _HandlerRefused(pName)
end _UnknownCommand

-- T37: whether the word at pAt, in the statement of the code tokens
-- pStart to pEnd, stands alone where only a value can: what put puts
-- ("put W into", "put in into meas"), what get gets and return returns
-- ("get W", "return W"), or a side of a comparison ("if W is", "= W
-- then", "(x = W)", "<> W"), where it is not a word of the grammar ("if
-- there is", "is a number", "is not in")
private function _AloneAsValue pTokens, pIdx, pStart, pAt, pEnd
   local tWord, tPrev, tNext, tVerb
   put _T(pTokens, pIdx[pAt]) into tWord
   put _T(pTokens, pIdx[pAt - 1]) into tPrev
   if pAt < pEnd then put _T(pTokens, pIdx[pAt + 1]) into tNext
   -- (<> is two tokens, < and >)
   if tPrev is ">" and pAt > 2 and _T(pTokens, pIdx[pAt - 2]) is "<" then put "<>" into tPrev
   if tNext is "<" and pAt + 2 <= pEnd and _T(pTokens, pIdx[pAt + 2]) is ">" then put "<>" into tNext
   if pAt = pStart + 1 then
      put _T(pTokens, pIdx[pStart]) into tVerb
      if tVerb is "put" and tNext is among the words of "into before after" then return true
      if tVerb is among the words of "get return" and pAt = pEnd then return true
   end if
   if tWord is among the words of kNeverNames or tWord is among the words of kObjectWords \
         or tWord is among the words of "there not among" then return false
   if (tPrev is among the words of "= <> is" or (tPrev is "not" and _T(pTokens, pIdx[pAt - 2]) is "is")) \
         and (pAt = pEnd or tNext is among the words of "then and or )") then return true
   if tPrev is among the words of "if and or (" and tNext is among the words of "= <> is" then return true
   return false
end _AloneAsValue

-- T10: the version and the long version, which in HyperCard are
-- HyperCard's, not this engine's (scripts test "the version < 2")
private function _VersionRule pLine
   local tTokens, tCode, tIdx, n, tItem, i, tWord, tAt, tStart
   if "heapspace" is in pLine then put _HeapSpaceRule(pLine) into pLine
   if "userlevel" is in pLine then put _UserLevelRule(pLine) into pLine
   if "systemversion" is in pLine then put _SystemVersionRule(pLine) into pLine
   if "version" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 2 to n
      -- T55: the version of a stack ("get the version of this stack",
      -- "item 3 of the version of stack x"), which this engine takes for
      -- its own version followed by "of": the script does not compile,
      -- or "get the version of this stack" stops ("source is not a
      -- container"). The library's hcStackVersion; "of stack" alone is
      -- this stack's (T11)
      if _T(tTokens, tIdx[i]) is "version" and _T(tTokens, tIdx[i + 1]) is "of" \
            and (_T(tTokens, tIdx[i + 2]) is "stack" or (_T(tTokens, tIdx[i + 2]) is "this" and _T(tTokens, tIdx[i + 3]) is "stack")) then
         put _StackRefEnd(tTokens, tIdx, i + 2, n) into tAt
         if tAt > 0 then
            put i into tStart
            if _T(tTokens, tIdx[tStart - 1]) is "long" then subtract 1 from tStart
            if _T(tTokens, tIdx[tStart - 1]) is "the" then subtract 1 from tStart
            if tAt = i + 2 then
               _Replace tTokens, tIdx, tStart, tAt, "hcStackVersion(the long id of this stack)"
            else
               _Replace tTokens, tIdx, tStart, tAt, "hcStackVersion(the long id of" && _Span(tTokens, tIdx, i + 2, tAt) & ")"
            end if
            _Fire "T55 the version of a stack"
            next repeat
         end if
      end if
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

-- T10: the heapSpace (or heapSpace()), the memory HyperCard had free,
-- which stacks checked before they ran ("if the heapSpace < 1321000 then
-- doMenu Quit HyperCard"); this engine gives 1000000 always, so it goes
-- to the library's hcHeapSpace()
private function _HeapSpaceRule pLine
   local tTokens, tCode, tIdx, n, tItem, i
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 1 to n
      if _T(tTokens, tIdx[i]) is not "heapspace" then next repeat
      if i > 1 and _T(tTokens, tIdx[i - 1]) is "the" then
         _Replace tTokens, tIdx, i - 1, i, "hcHeapSpace()"
         _Fire "T10 HyperCard's version"
      else if _T(tTokens, tIdx[i + 1]) is "(" and _T(tTokens, tIdx[i + 2]) is ")" then
         _Replace tTokens, tIdx, i, i + 2, "hcHeapSpace()"
         _Fire "T10 HyperCard's version"
      end if
   end repeat
   return _Join(tTokens)
end _HeapSpaceRule

-- T10: the systemVersion (or systemVersion()), the Mac's System, which
-- stacks compare with a number ("if the systemVersion < 7 then",
-- Finder Cleaner's): this engine's is the host's ("NT 10.0", "14.5.0"),
-- which such a comparison takes as text, and on macOS "14.5.0" is less
-- than 7. It goes to the library's hcSystemVersion(), the System's
-- version as HyperCard gave it ("7.55"), and so does value("the
-- systemVersion"), which stacks wrote for a HyperCard before 2, where
-- the systemVersion was not (HyperBattleship!'s)
private function _SystemVersionRule pLine
   local tTokens, tCode, tIdx, n, tItem, i
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 1 to n
      if _T(tTokens, tIdx[i]) is "value" and _T(tTokens, tIdx[i + 1]) is "(" and _T(tTokens, tIdx[i + 3]) is ")" \
            and _T(tTokens, tIdx[i + 2]) is quote & "the systemversion" & quote then
         _Replace tTokens, tIdx, i, i + 3, "hcSystemVersion()"
         _Fire "T10 HyperCard's version"
         next repeat
      end if
      if _T(tTokens, tIdx[i]) is not "systemversion" or tTokens[tIdx[i]]["k"] is not "w" then next repeat
      if i > 1 and _T(tTokens, tIdx[i - 1]) is "the" and _T(tTokens, tIdx[i + 1]) is not "of" then
         _Replace tTokens, tIdx, i - 1, i, "hcSystemVersion()"
         _Fire "T10 HyperCard's version"
      else if _T(tTokens, tIdx[i + 1]) is "(" and _T(tTokens, tIdx[i + 2]) is ")" and not sStackFunctions["systemversion"] \
            and _T(tTokens, tIdx[i - 1]) is not among the words of "the function on end" then
         _Replace tTokens, tIdx, i, i + 2, "hcSystemVersion()"
         _Fire "T10 HyperCard's version"
      end if
   end repeat
   return _Join(tTokens)
end _SystemVersionRule

-- T10: the userLevel, which in HyperCard is 1 (browsing) to 5
-- (scripting), and here 8 until a script sets it, so that "if the
-- userLevel is 5" is false and HyperCard's Home stack finds no button
-- "UserLevel 8" to point its arrow at: the library's hcUserLevel(),
-- which gives 5 for 8. A set is left as it is ("set the userLevel to
-- 5"), and so what a script set is what it reads
private function _UserLevelRule pLine
   local tTokens, tCode, tIdx, n, tItem, i
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 2 to n
      if _T(tTokens, tIdx[i]) is not "userlevel" or _T(tTokens, tIdx[i - 1]) is not "the" then next repeat
      if _T(tTokens, tIdx[i - 2]) is "set" or _T(tTokens, tIdx[i + 1]) is "of" then next repeat
      _Replace tTokens, tIdx, i - 1, i, "hcUserLevel()"
      _Fire "T10 HyperCard's version"
   end repeat
   return _Join(tTokens)
end _UserLevelRule

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
   -- (HyperCard's "in a new window" is no different for the Home stack,
   -- and neither is "in new window", which HyperCard took too: "go home
   -- in new window", My First Book of HyperCard 2's)
   if j + 4 = pCount and _Span(pTokens, pIdx, j + 1, pCount) is "in a new window" then put pCount into j
   if j + 3 = pCount and _Span(pTokens, pIdx, j + 1, pCount) is "in new window" then put pCount into j
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

-- T49: the field or button of the card or the background that names
-- play's sound ("play card field "sound"", "play cd fld id 12 tempo
-- 200"), from the code token pAt: the index of its last token, its name
-- (a word, a string, a number or an expression in parentheses), or 0.
-- One of another card ("card field 1 of card 2") or called as a
-- function ("cd fld f(1)") is not taken
private function _PlayObject pTokens, pIdx, pAt, pEnd
   local j, tDepth
   if _T(pTokens, pIdx[pAt]) is not among the words of "card cd background bkgnd bg" \
         or _T(pTokens, pIdx[pAt + 1]) is not among the words of "field fld button btn" then
      return 0
   end if
   put pAt + 2 into j
   if _T(pTokens, pIdx[j]) is "id" then add 1 to j
   if j > pEnd then return 0
   if _T(pTokens, pIdx[j]) is "(" then
      put 0 into tDepth
      repeat while j <= pEnd
         if _T(pTokens, pIdx[j]) is "(" then
            add 1 to tDepth
         else if _T(pTokens, pIdx[j]) is ")" then
            subtract 1 from tDepth
            if tDepth = 0 then exit repeat
         end if
         add 1 to j
      end repeat
      if j > pEnd then
         return 0
      end if
   else if pTokens[pIdx[j]]["k"] is "w" then
      if _T(pTokens, pIdx[j]) is among the words of kNotPlain or _T(pTokens, pIdx[j]) is among the words of "then else tempo" then
         return 0
      end if
   else if pTokens[pIdx[j]]["k"] is not among the words of "s n" then
      return 0
   end if
   if j < pEnd and _T(pTokens, pIdx[j + 1]) is among the words of "of ( in" then return 0
   return j
end _PlayObject

-- T50: from the code token pAt, a chunk of a variable or of a function's
-- value ("item 1 of fieldList", "last item of theFields()", "item i of
-- line 2 of it"): the index of its last token, or 0. A chunk of an
-- object ("line 1 of me", "word 2 of card field 1"), a range ("item 1 to
-- 3 of x"), a chunk numbered by an expression of several words and one
-- whose container goes on ("of x of y") are not taken
private function _ChunkObjectEnd pTokens, pIdx, pAt, pEnd
   local j, tPhrases, tDepth
   put pAt into j
   put 0 into tPhrases
   repeat while j < pEnd
      if _T(pTokens, pIdx[j]) is among the words of kChunkOrdinals and _T(pTokens, pIdx[j + 1]) is among the words of kChunkWords then
         add 2 to j
      else if _T(pTokens, pIdx[j]) is among the words of kChunkWords \
            and (pTokens[pIdx[j + 1]]["k"] is "n" or (pTokens[pIdx[j + 1]]["k"] is "w" \
            and _T(pTokens, pIdx[j + 1]) is not among the words of kNotPlain \
            and _T(pTokens, pIdx[j + 1]) is not among the words of kObjectWords)) then
         if _T(pTokens, pIdx[j + 2]) is "to" then return 0
         add 2 to j
      else
         exit repeat
      end if
      if j > pEnd or _T(pTokens, pIdx[j]) is not among the words of "of in" then return 0
      add 1 to j
      add 1 to tPhrases
   end repeat
   if tPhrases = 0 or j > pEnd or pTokens[pIdx[j]]["k"] is not "w" then return 0
   if _T(pTokens, pIdx[j]) is among the words of kObjectWords \
         or _T(pTokens, pIdx[j]) is among the words of "me this the target msg message selection menu" \
         or _T(pTokens, pIdx[j]) is among the words of kChunkWords \
         or _T(pTokens, pIdx[j]) is among the words of kChunkOrdinals then
      return 0
   end if
   if j < pEnd and _T(pTokens, pIdx[j + 1]) is "(" then
      -- a function's value: to its closing parenthesis
      put 0 into tDepth
      repeat with j = j + 1 to pEnd
         if _T(pTokens, pIdx[j]) is "(" then
            add 1 to tDepth
         else if _T(pTokens, pIdx[j]) is ")" then
            subtract 1 from tDepth
            if tDepth = 0 then exit repeat
         end if
      end repeat
      if j > pEnd then return 0
   end if
   if j < pEnd and _T(pTokens, pIdx[j + 1]) is among the words of "of in" then return 0
   return j
end _ChunkObjectEnd

-- T76: a card numbered by a sum or a difference not in parentheses,
-- after "of" ("put field "Season" of card it-1 into numSeasons", the Star
-- Trek guides' openStack; "set name of btn i to short name of cd i-1";
-- "put item wtln of fld AAs of cd x+1 into n1"), which HyperCard took for
-- the card the sum numbers, and this engine for the card of the first
-- number, adding to (or taking from) the value of what it names: the
-- guides' last card has no field "Season", the one before it has, so
-- that their stacks stopped as they opened. Only a sum of two operands,
-- each a number or a variable's name (or it), with + or - between them,
-- and after it nothing that binds tighter or goes on with it (*, /, ^,
-- div, mod, another + or -, a "(", or an "of" not before a background
-- or a stack); "&", which HyperCard's value took after the card ("put
-- field 1 of card "a" & x into y"), ends nothing here. The index of the
-- sum's last token, or 0
private function _CardSumEnd pTokens, pIdx, pAt, pCount
   local tAfter
   if pAt + 3 > pCount then return 0
   if not _CardSumOperand(pTokens, pIdx[pAt + 1]) then return 0
   if pTokens[pIdx[pAt + 2]]["t"] is not among the items of "+,-" then return 0
   if not _CardSumOperand(pTokens, pIdx[pAt + 3]) then return 0
   if pAt + 4 <= pCount then
      put _T(pTokens, pIdx[pAt + 4]) into tAfter
      if tAfter is among the items of "+,-,*,/,^,(" or tAfter is among the words of "div mod" then return 0
      if tAfter is "of" and _T(pTokens, pIdx[pAt + 5]) is not among the words of "background bkgnd bg stack" then return 0
   end if
   return pAt + 3
end _CardSumEnd

-- T76: whether the token at pAt is a number, it, or a word that can be
-- a variable's name there (not "the", "id", an object, a property)
private function _CardSumOperand pTokens, pAt
   local tWord
   if pTokens[pAt]["k"] is "n" then return true
   if pTokens[pAt]["k"] is not "w" then return false
   put _Lower(pTokens[pAt]["t"]) into tWord
   if tWord is "it" then return true
   if tWord is among the words of kNeverNames or tWord is among the words of kObjectWords \
         or tWord is among the words of kNeverNamesAfterCard or tWord is among the words of kChunkOrdinals \
         or tWord is among the words of kNotPlain or tWord is among the words of kChunkObjectProperties then
      return false
   end if
   return true
end _CardSumOperand

-- T59: a card named by an expression not in parentheses ("put empty into
-- field i of card "Div-"&c", 1040A's; "put empty into line count of
-- field "price" of card "order"&sheet", SalesWriter's; "set lockText of
-- field "Liste" of card "Liste" && Hunderter to true", and "put field
-- "Liste" of card "Liste" && Karte of background "Stammlisten" into
-- field "Lager"", Yeast Collection's; "mark card it + 1", StackTools'),
-- which HyperCard took for the card that the whole expression names or
-- numbers, as both take it in a go ("go to card "order"&sheet"), and
-- this engine refuses, as it takes the card "Div-" and then cannot place
-- the operator. Where the card, at pAt, is a put's destination's (after
-- its into, before or after) or a mark's, the expression goes on to the
-- end of the statement; a set's, to the set's "to"; and before an "of"
-- and a background or a stack, it is one word after the operator. The
-- index of its last token, or 0. The expression's first token is a
-- string, a number or a variable's name, and an operator follows it
private function _CardNameEnd pTokens, pIdx, pAt, pCount
   local tStart, tEnd, tVerb, j, k, tDepth
   put pAt into tStart
   repeat while tStart > 1 and _T(pTokens, pIdx[tStart - 1]) is not among the words of "then else"
      subtract 1 from tStart
   end repeat
   put pCount into tEnd
   repeat with k = pAt + 1 to pCount
      if _T(pTokens, pIdx[k]) is "else" then
         put k - 1 into tEnd
         exit repeat
      end if
   end repeat
   put _T(pTokens, pIdx[tStart]) into tVerb
   put pAt + 1 into j
   if j + 2 > tEnd or pTokens[pIdx[j]]["k"] is not among the items of "s,n,w" then return 0
   if pTokens[pIdx[j]]["k"] is "w" and _T(pTokens, pIdx[j]) is not "it" and (_T(pTokens, pIdx[j]) is among the words of kNeverNames \
         or _T(pTokens, pIdx[j]) is among the words of kObjectWords or _T(pTokens, pIdx[j]) is among the words of kChunkOrdinals \
         or _T(pTokens, pIdx[j]) is among the words of kNeverNamesAfterCard) then
      return 0
   end if
   if pTokens[pIdx[j + 1]]["t"] is not among the items of "&,+,-,*,/" then return 0
   -- (the operand after the operator, past the second "&" of "&&")
   put j + 2 into k
   if pTokens[pIdx[j + 1]]["t"] is "&" and pTokens[pIdx[k]]["t"] is "&" then add 1 to k
   if k > tEnd then return 0
   -- (not a property without "the": "card "A" & name of bkgnd 1")
   if k + 2 <= tEnd and pTokens[pIdx[k]]["k"] is "w" and _T(pTokens, pIdx[k + 1]) is "of" \
         and _T(pTokens, pIdx[k + 2]) is among the words of "background bkgnd bg stack" \
         and _T(pTokens, pIdx[pAt - 1]) is "of" and _T(pTokens, pIdx[k]) is not among the words of kChunkObjectProperties \
         and _T(pTokens, pIdx[k]) is not among the words of kNotPlain and _T(pTokens, pIdx[k]) is not "number" then
      return k
   end if
   switch tVerb
      case "mark"
      case "unmark"
         if pAt = tStart + 1 then return tEnd
         break
      case "put"
         if _T(pTokens, pIdx[pAt - 1]) is not "of" then return 0
         put 0 into tDepth
         repeat with k = tStart + 1 to pAt - 1
            if pTokens[pIdx[k]]["t"] is "(" then add 1 to tDepth
            if pTokens[pIdx[k]]["t"] is ")" then subtract 1 from tDepth
            if tDepth = 0 and _T(pTokens, pIdx[k]) is among the words of "into before after" then return tEnd
         end repeat
         break
      case "set"
         if _T(pTokens, pIdx[pAt - 1]) is not "of" then return 0
         put 0 into tDepth
         repeat with k = j + 2 to tEnd - 1
            if pTokens[pIdx[k]]["t"] is "(" then add 1 to tDepth
            if pTokens[pIdx[k]]["t"] is ")" then subtract 1 from tDepth
            if tDepth = 0 and _T(pTokens, pIdx[k]) is "to" then return k - 1
         end repeat
         break
   end switch
   return 0
end _CardNameEnd

-- T9, T16 to T30 and T32: statements that stop with an error here where
-- HyperCard went on, or that do something else here; in every script,
-- compiling or not, one statement a line at most (a statement continued
-- with \ is left as it is)
private function _HyperCardRules pLine, pCompiled, pElse
   local tTokens, tCode, tIdx, n, tItem, i, j, tEnd, tWord, tNew, tStackAt

   -- (pElse: the rest of a line from its else, whose phrases are done)
   if pCompiled and pElse is not true then put _PlayNotes(pLine) into pLine
   if char -1 of word 1 to -1 of _CodeText(pLine) is "\" then return pLine
   if pElse is not true then
      -- T37: in a script that compiles too, a word alone as an argument of
      -- an external, of one of the stack's handlers or of a command this
      -- engine does not have, which HyperCard passed as its text and this
      -- engine takes for an object it cannot find ("AddColor
      -- enableObject,cd,2", Color Tools; "putVar cd, myID, ...", Instance
      -- Variables; "toggleProperty cantDelete,card,..."), and stops: in
      -- quotes (_ExternalArguments, which a script that does not compile
      -- went through already). Such a word compiles there only before a
      -- comma
      if pCompiled and comma is in pLine then put _ExternalArguments(pLine, empty, sExternals, false, true) into pLine
      put _MenuItemProperties(pLine) into pLine
      put _MenuReads(pLine) into pLine
      put _CardWindow(pLine) into pLine
      put _HyperCardWindows(pLine) into pLine
      put _MessageBoxProperties(pLine) into pLine
      put _HyperCardObject(pLine) into pLine
      put _StacksNotOpen(pLine) into pLine
      put _NamedByAName(pLine) into pLine
      put _PictureProperties(pLine) into pLine
      put _PaintTextReads(pLine) into pLine
      put _PrintTextReads(pLine) into pLine
      -- (T56's chunks never compile here as they are)
      if not pCompiled then put _ChunkOrder(pLine) into pLine
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

      -- T47: a function called by a name that is one of this engine's
      -- commands ("put replace(":", ",", t) into t", "get sort(fld 1,
      -- "n")"), which compiles here but is no function, and stops there
      -- (any statement): the stack's own function of that name, as T1
      -- renamed it, else the library's stand-in for the external of that
      -- name, hcX_<name>. A statement that begins with one ("find (x)")
      -- is the command
      if i > 1 and _T(tTokens, tIdx[i + 1]) is "(" and tWord is among the words of kCommands \
            and _T(tTokens, tIdx[i - 1]) is not among the words of "the then else on function end pass exit" then
         if sStackFunctions[tWord] and sRenameHandlers[tWord] is not empty then
            put sRenameHandlers[tWord] into tTokens[tIdx[i]]["t"]
            _Fire "T47 function named like a command"
            next repeat
         else if tWord is among the words of kCommandExternals then
            put "hcX_" & tTokens[tIdx[i]]["t"] into tTokens[tIdx[i]]["t"]
            _Fire "T47 function named like a command"
            next repeat
         end if
      end if

      -- T44: an object's name not in quotes that this engine reads as one
      -- of its constants ("show cd fld help", field 15 here, "hide btn
      -- arrow", button 29, "add 1 to fld Plus", field 13), where
      -- HyperCard, which had no such constant, took the word as its text:
      -- in quotes (any statement). No variable can have such a name here:
      -- in a script that does not compile, T2 has renamed the variables
      -- HyperCard let have one ("put "F1" into help")
      if i > 1 and tWord is among the words of kEngineConstants \
            and _T(tTokens, tIdx[i - 1]) is among the words of "field fld button btn card cd background bkgnd bg stack" \
            and _T(tTokens, tIdx[i + 1]) is not "(" then
         put quote & tTokens[tIdx[i]]["t"] & quote into tTokens[tIdx[i]]["t"]
         put "s" into tTokens[tIdx[i]]["k"]
         _Fire "T44 object name that is a constant here"
         next repeat
      end if
      -- ... and the message a send names by such a word ("send help to
      -- card", Book Reporter's Guild's, which sent 15 here; "send help to
      -- hypercard", which T29 then sends to the library)
      if i > 1 and tWord is among the words of kEngineConstants and _T(tTokens, tIdx[i - 1]) is "send" \
            and _StatementWord(tTokens, tIdx, i - 1) is "send" \
            and (i = n or _T(tTokens, tIdx[i + 1]) is among the words of "to else") then
         put quote & tTokens[tIdx[i]]["t"] & quote into tTokens[tIdx[i]]["t"]
         put "s" into tTokens[tIdx[i]]["k"]
         _Fire "T44 object name that is a constant here"
         next repeat
      end if

      -- T45: HyperCard's Home stack named but not gone to ("set the script
      -- of stack "Home" to tScript", "the long name of stack Home", "send
      -- startUp to stack home"), which here is the IDE's own stack "home"
      -- (and "stack Home" does not compile): the library's hcHome(),
      -- HyperCard's Home if it was imported, else a stand-in, so that no
      -- script of the stack reads or changes the IDE's (any statement but
      -- a go, which goes home with hcGoHome or hcGo: T9, T16)
      if tWord is "stack" and i < n and (_T(tTokens, tIdx[i + 1]) is "home" or _T(tTokens, tIdx[i + 1]) is quote & "home" & quote) \
            and _StatementWord(tTokens, tIdx, i) is not "go" then
         put "hcHome()" into tTokens[tIdx[i + 1]]["t"]
         put "w" into tTokens[tIdx[i + 1]]["k"]
         _Fire "T45 HyperCard's Home stack"
         next repeat
      end if
      -- T45: and Home named without "stack" ("get the long name of home",
      -- Lab Logger's; "if the cantmodify of home then", Color Tools';
      -- "send startup to home", DevStackFix's), which compiles here as the
      -- "home" of "go home" and stops ("error in object expression"), or
      -- in a go does not compile ("go to card "Reset BBS" of home",
      -- HyperBBS's; T9 takes "go home" and "go to card 1 of home" to
      -- hcGoHome): Home's stack, not a variable called home
      -- (_HomeNamed)
      if tWord is "home" and _HomeNamed(tTokens, tIdx, i) then
         put "stack hcHome()" into tTokens[tIdx[i]]["t"]
         _Fire "T45 HyperCard's Home stack"
         next repeat
      end if

      -- T11: "in" for "of" after an object, before the card, background
      -- or stack it is on, in a script that compiles too ("hide card field
      -- "Sentence" in card 2", Teaching to Read; "get the id of first card
      -- in bkgnd id 2618", RefStak 88; "btn 1 in this card"): this engine
      -- reads such an "in" as a text chunk's and stops with "source is not
      -- a container" (_InForOf; _PhraseRules takes the same in a script
      -- that does not compile)
      if tWord is "in" and _InForOf(tTokens, tIdx, i) then
         put "of" into tTokens[tIdx[i]]["t"]
         _Fire "T11 HyperCard object words"
         next repeat
      end if

      -- T50: a property of an object named by a chunk of a variable or of
      -- a function's value ("the textHeight of item 1 of fieldList",
      -- "scroll of last item of theFields()", "top of item i of
      -- objectList"), where the text names the object ("card field 1,card
      -- field 2"), which HyperCard took as that object, as it takes a
      -- variable that holds such a name. This engine takes the variable's
      -- whole text for the object, with the chunk as text of it, and stops
      -- with an error: the chunk in parentheses, whose text this engine
      -- takes for the object (any statement)
      if tWord is among the words of kChunkObjectProperties and _T(tTokens, tIdx[i + 1]) is "of" \
            and (i = 1 or _T(tTokens, tIdx[i - 1]) is not among the words of kChunkWords) then
         put _ChunkObjectEnd(tTokens, tIdx, i + 2, n) into j
         if j > 0 then
            put "(" before tTokens[tIdx[i + 2]]["t"]
            put ")" after tTokens[tIdx[j]]["t"]
            _Fire "T50 an object named by a chunk of a variable"
            next repeat
         end if
      end if

      -- T76: a card numbered by a sum after "of", in a script that
      -- compiles too (_CardSumEnd)
      if i > 1 and tWord is among the words of "card cd" and _T(tTokens, tIdx[i - 1]) is "of" then
         put _CardSumEnd(tTokens, tIdx, i, n) into j
         if j > 0 then
            put "(" before tTokens[tIdx[i + 1]]["t"]
            put ")" after tTokens[tIdx[j]]["t"]
            _Fire "T76 a card numbered by a sum"
            next repeat
         end if
      end if

      -- T59: a card named by an expression not in parentheses, in a
      -- script that does not compile (_CardNameEnd)
      if not pCompiled and i > 1 and tWord is among the words of "card cd" then
         put _CardNameEnd(tTokens, tIdx, i, n) into j
         if j > 0 then
            put "(" before tTokens[tIdx[i + 1]]["t"]
            put ")" after tTokens[tIdx[j]]["t"]
            _Fire "T59 a card named by an expression"
            next repeat
         end if
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
            -- (T43 first, as it makes an "in" "of")
            put _GoStackAt(tTokens, tIdx, i, tEnd) into tStackAt
            put _GoStack(tTokens, tIdx, i, tEnd, tStackAt) into tNew
            if tNew is empty then put _GoBackground(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _GoTo(tTokens, tIdx, i, tEnd) into tNew
            break
         case "set"
            put _SetCursor(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetMenuItem(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetWindow(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetMessageBox(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetCardAndStyle(tTokens, tIdx, i, tEnd) into tNew
            -- (T53 before T51, which takes a font of several words with no
            -- object too: "set the textFont to New York")
            if tNew is empty then put _SetPaintText(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetPrintText(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetHyperCardProperty(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetTextFont(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty then put _SetShowPict(tTokens, tIdx, i, tEnd) into tNew
            break
         case "sort"
            put _SortCards(tTokens, tIdx, i, tEnd, n) into tNew
            break
         case "find"
            put _FindMarked(tTokens, tIdx, i, tEnd, n) into tNew
            break
         case "put"
            put _PutIntoMenu(tTokens, tIdx, i, tEnd) into tNew
            if tNew is empty and not pCompiled then put _PutChunkOrder(tTokens, tIdx, i, tEnd, n) into tNew
            if tNew is empty and not pCompiled then put _PutIntoQuoted(tTokens, tIdx, i, tEnd) into tNew
            break
         case "enable"
         case "disable"
         case "create"
         case "delete"
            put _MenuCommand(tTokens, tIdx, i, tEnd) into tNew
            break
         case "reset"
            -- T53: reset paint, which HyperCard's paint text went back to
            -- its defaults with too: the library's hcResetPaint, which
            -- resets this engine's paint properties and the paint text's
            if _T(tTokens, tIdx[i + 1]) is "paint" and i + 1 = tEnd then
               _Fire "T53 the paint text's properties"
               put "hcResetPaint" into tNew
            end if
            -- T72: reset printing, which HyperCard's print text went back
            -- to its defaults with too: the library's hcResetPrinting
            if _T(tTokens, tIdx[i + 1]) is "printing" and i + 1 = tEnd then
               _Fire "T72 the print text's properties"
               put "hcResetPrinting" into tNew
            end if
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
            -- T61: stop speech, HyperCard 2.2's, which this engine refuses
            -- ("bad action"): the library's hcStopSpeech
            if tWord is "stop" and _T(tTokens, tIdx[i + 1]) is "speech" and i + 1 = tEnd then
               _Fire "T61 HyperCard's speech"
               put "hcStopSpeech" into tNew
            end if
            break
         case "speak"
            -- T61: speak with a voice, HyperCard 2.2's ("speak (item 4 of
            -- pasteList) with voice it", "speak x with female voice"),
            -- which this engine refuses: the library's Speak, which
            -- speaks the text (in the voice speech has here). The speak
            -- without one is a call of the library's Speak as it is
            repeat with j = i + 2 to tEnd - 1
               if _T(tTokens, tIdx[j]) is "with" and (_T(tTokens, tIdx[j + 1]) is "voice" \
                     or (_T(tTokens, tIdx[j + 1]) is among the words of "male female neuter robotic" and _T(tTokens, tIdx[j + 2]) is "voice")) then
                  _Fire "T61 HyperCard's speech"
                  put "Speak" && _Span(tTokens, tIdx, i + 1, j - 1) into tNew
                  exit repeat
               end if
            end repeat
            break
         case "answer"
            -- T67: answer program, HyperCard 2.1's choice of a program on
            -- another Macintosh to send messages to ("answer program "Pick
            -- a remote Hypercard to use:"", Chess Set!; "answer program
            -- "Choose a recipient:" of type "WILDep01"", HC Communications;
            -- 11 stacks of the corpus), which put the choice into it, and
            -- nothing when it was cancelled. This engine shows the prompt
            -- with an OK button and puts "OK" into it, a program of that
            -- name to the script, and refuses "of type": the library's
            -- hcAnswerProgram, whose value, put into it, is nothing, as no
            -- program can be chosen here
            if _T(tTokens, tIdx[i + 1]) is "program" and tEnd > i + 1 then
               put _FindWord(tTokens, tIdx, i + 2, tEnd, "of", "type") into j
               if j is empty then put tEnd + 1 into j
               if j > i + 2 then
                  _Fire "T67 answer program"
                  put "get hcAnswerProgram(" & _Span(tTokens, tIdx, i + 2, j - 1) & ")" into tNew
               end if
            end if
            break
         case "help"
            -- T18: help alone, HyperCard's command for its Help stack
            -- ("help", a Help button's; "if it is 2 then help", in a
            -- button with its own "on help"): the library's hcHelp, which
            -- sends the message from this object as HyperCard did, so
            -- that a handler of the stack's takes it first, and then goes
            -- to Help. ("help "x"" is a stack's own handler's, called as
            -- it was)
            if tEnd = i then
               _Fire "T18 key and picture commands"
               put "hcHelp the long id of me" into tNew
            end if
            break
         case "quit"
            -- T70: quit, which was no command of HyperCard's but the
            -- message it sent as it quit: a script that called it sent
            -- the message, which a stack's own "on quit" took (renamed
            -- hc_quit by T1) and HyperCard let go if none did ("if it is
            -- "Cancel" then quit", "quit mouseUp" for an exit). This
            -- engine's quit quits at once, the IDE itself in the IDE,
            -- past the stack's handler: the library's hcQuit sends the
            -- message from this object, as HyperCard did
            _Fire "T70 quit"
            if tEnd = i then
               put "hcQuit the long id of me" into tNew
            else
               put "hcQuit the long id of me," && _Span(tTokens, tIdx, i + 1, tEnd) into tNew
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
            put _Print(tTokens, tIdx, i, tEnd) into tNew
            break
         case "ask"
            put _AskPassword(tTokens, tIdx, i, tEnd) into tNew
            break
         case "play"
            -- T49: a sound named in a field or button of the card or the
            -- background ("play card field "sound"", "play cd fld x tempo
            -- 200 tNotes"), whose text HyperCard played. This engine takes
            -- the "card" or "background" for its own, a player's ("play
            -- card player "Movie""), and looks for the field without it:
            -- in a stack from HyperCard, one of the background where the
            -- card's was meant (no such object). In parentheses, the
            -- field is a value, its text, as in HyperCard. Its name gets
            -- T44 here, which the rules for single words reach only in a
            -- statement no rule rewrites ("play cd fld help")
            put _PlayObject(tTokens, tIdx, i + 1, tEnd) into j
            if j > 0 then
               if tTokens[tIdx[j]]["k"] is "w" and _T(tTokens, tIdx[j]) is among the words of kEngineConstants and _T(tTokens, tIdx[j - 1]) is not "id" then
                  put quote & tTokens[tIdx[j]]["t"] & quote into tTokens[tIdx[j]]["t"]
                  put "s" into tTokens[tIdx[j]]["k"]
                  _Fire "T44 object name that is a constant here"
               end if
               _Fire "T49 play a sound named in a field"
               put tTokens[tIdx[i]]["t"] && "(" & _Span(tTokens, tIdx, i + 1, j) & ")" into tNew
               if j < tEnd then put space & _Span(tTokens, tIdx, j + 1, tEnd) after tNew
            end if
            break
         case "show"
         case "hide"
         case "close"
            put _ShowHide(tTokens, tIdx, i, tEnd) into tNew
            break
         case "send"
            -- T29: send ... to HyperCard, the application, which had the
            -- message's built-in handler: hcSendToHyperCard (a message
            -- named by a word this engine reads as one of its constants,
            -- "send help to hypercard", in quotes, as T44 puts it). Also
            -- HyperCard named in quotes ("send "go to next card" to
            -- "hyperCard"", Bring in the Expert's), which here names no
            -- object and stops with an error
            if tEnd > i + 2 and (_T(tTokens, tIdx[tEnd]) is "hypercard" or _T(tTokens, tIdx[tEnd]) is quote & "hypercard" & quote) \
                  and _T(tTokens, tIdx[tEnd - 1]) is "to" then
               _Fire "T29 HyperCard the application"
               if tEnd = i + 3 and tTokens[tIdx[i + 1]]["k"] is "w" and _T(tTokens, tIdx[i + 1]) is among the words of kEngineConstants then
                  put "hcSendToHyperCard" && quote & tTokens[tIdx[i + 1]]["t"] & quote into tNew
               else
                  put "hcSendToHyperCard" && _Span(tTokens, tIdx, i + 1, tEnd - 2) into tNew
               end if
            end if
            break
         case "open"
            put _OpenApplication(tTokens, tIdx, i, tEnd) into tNew
            break
         case "do"
            put _DoStatement(tTokens, tIdx, i, tEnd) into tNew
            break
         case "domenu"
         case "hcdomenu"
            -- T36: doMenu's menu name after a comma, and "without dialog",
            -- which this engine's doMenu does not take
            put _DoMenuForms(tTokens, tIdx, i, tEnd) into tNew
            if tNew is not empty then break
            -- T27: doMenu with the item's name not in quotes ("doMenu
            -- New Card"), which HyperCard took as the text it was;
            -- here two names side by side are no expression
            if tEnd > i + 1 and _PlainWords(tTokens, tIdx, i + 1, tEnd) then
               _Fire "T27 doMenu with the item not in quotes"
               put tTokens[tIdx[i]]["t"] && quote & _Span(tTokens, tIdx, i + 1, tEnd) & quote into tNew
            end if
            -- (the library's hcDoMenu, or in a stack with HyperCard's
            -- message order its "on doMenu", names a new button "New
            -- Button", as HyperCard did, and closes the stack on "Quit
            -- HyperCard" in the IDE rather than quit the IDE, T15)
            break
         case "opencard"
         case "closecard"
         case "openbackground"
         case "closebackground"
         case "openstack"
         case "closestack"
         case "resumestack"
         case "suspendstack"
         case "idle"
         case "openfield"
         case "closefield"
         case "exitfield"
         case "mouseup"
         case "mousedown"
         case "mousestilldown"
         case "mouseenter"
         case "mouseleave"
         case "mousewithin"
         case "startup"
         case "resume"
         case "suspend"
         case "newcard"
         case "newbackground"
         case "newstack"
            -- T35: a message HyperCard sent ("openCard"), called alone as a
            -- command: what no handler took, HyperCard took; here it is
            -- passed off the end of the message path, where this engine
            -- has no such command and stops with an error. Sent instead,
            -- it goes the same way and ends quietly, in the HyperCard
            -- Library's handler of it, which passes it on
            if tEnd = i then
               _Fire "T35 more forms HyperCard took"
               put "send" && quote & tTokens[tIdx[i]]["t"] & quote && "to me" into tNew
            end if
            break
         case "debug"
            -- T35: HyperCard 2's debug command: "debug checkpoint" is this
            -- engine's breakpoint, and its other options ("debug sound
            -- off", "debug pureQuickDraw true") have nothing to set here
            if tEnd = i + 1 and _T(tTokens, tIdx[i + 1]) is "checkpoint" then
               _Fire "T35 more forms HyperCard took"
               put "breakpoint" into tNew
            else if tEnd > i and tTokens[tIdx[i + 1]]["k"] is "w" and quote is not in _Span(tTokens, tIdx, i + 1, tEnd) then
               _Fire "T35 more forms HyperCard took"
               put "hcDebug" && quote & _Span(tTokens, tIdx, i + 1, tEnd) & quote into tNew
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

-- Whether the code tokens pFrom to pTo are a run of plain words, a name
-- HyperCard took as the text it was ("New Card", "New Stack...": the
-- dots are part of the name), not an expression
private function _PlainWords pTokens, pIdx, pFrom, pTo
   local j
   if pFrom > pTo then return false
   repeat with j = pFrom to pTo
      if j > pFrom and pTokens[pIdx[j]]["k"] is "p" and pTokens[pIdx[j]]["t"] is "." then next repeat
      if pTokens[pIdx[j]]["k"] is not "w" or _T(pTokens, pIdx[j]) is among the words of kNotPlain then return false
   end repeat
   return true
end _PlainWords

-- The code tokens pFrom to pTo as a value: in quotes if they are plain
-- words (_PlainWords), else as they are
private function _ValueOf pTokens, pIdx, pFrom, pTo
   if pFrom = pTo and pTokens[pIdx[pFrom]]["k"] is "w" and _ValueRefused(_T(pTokens, pIdx[pFrom])) then
      return quote & _Span(pTokens, pIdx, pFrom, pTo) & quote
   end if
   if pFrom < pTo and _PlainWords(pTokens, pIdx, pFrom, pTo) then
      return quote & _Span(pTokens, pIdx, pFrom, pTo) & quote
   end if
   return _Span(pTokens, pIdx, pFrom, pTo)
end _ValueOf

-- T36: doMenu item, menu, and doMenu item [, menu] without dialog: the
-- statement this engine takes, or empty for any other doMenu (pStart:
-- doMenu, or hcDoMenu after T1 or T15; pEnd: the statement's end). The
-- menu's name and "without dialog" become parameters of hcDoMenu; in a
-- stack with HyperCard's message order, of the doMenu message, which
-- dispatch sends as this engine's doMenu does
private function _DoMenuForms pTokens, pIdx, pStart, pEnd
   local tLast, tWithout, tComma, tDepth, j, tItem, tMenu
   put pEnd into tLast
   put false into tWithout
   if pEnd > pStart + 2 and _T(pTokens, pIdx[pEnd]) is "dialog" and _T(pTokens, pIdx[pEnd - 1]) is "without" then
      put true into tWithout
      put pEnd - 2 into tLast
   end if
   put 0 into tDepth
   repeat with j = pStart + 1 to tLast
      if _T(pTokens, pIdx[j]) is "(" then add 1 to tDepth
      if _T(pTokens, pIdx[j]) is ")" then subtract 1 from tDepth
      if tDepth = 0 and _T(pTokens, pIdx[j]) is comma then
         put j into tComma
         exit repeat
      end if
   end repeat
   if tComma is empty and not tWithout then return empty
   if tComma is empty then
      if tLast <= pStart then return empty
      put _ValueOf(pTokens, pIdx, pStart + 1, tLast) into tItem
      put "empty" into tMenu
   else
      if tComma = pStart + 1 or tComma = tLast then return empty
      put _ValueOf(pTokens, pIdx, pStart + 1, tComma - 1) into tItem
      put _ValueOf(pTokens, pIdx, tComma + 1, tLast) into tMenu
   end if
   if tWithout then put comma && quote & "without dialog" & quote after tMenu
   _Fire "T36 doMenu with a menu, or without dialog"
   if sHyperTalk then
      return "dispatch" && quote & "doMenu" & quote && "with" && tItem & comma && tMenu
   end if
   return "hcDoMenu" && tItem & comma && tMenu
end _DoMenuForms

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
-- runs it with the stack expression in the variable tHCStack. A name of
-- several words that the probe finds is no expression here, which
-- HyperCard took as the text it was ("go to stack flood control", "go to
-- card "Player" of stack Chess Library"; "go stack the stack you wish to
-- process", Script Changer's, which made HyperCard ask "Where is the
-- stack you wish to process?"), is that text in quotes: as an
-- expression, the statement hcGo makes did not compile and stopped the
-- handler. pStackAt: where a stack named without the word "stack" starts
-- (T43, _GoStackAt)
private function _GoStack pTokens, pIdx, pAt, pEnd, pStackAt
   local j, k, tLast, tFirst, tCard, tStack, tName
   if pStackAt is empty then
      repeat with j = pAt + 1 to pEnd
         if _T(pTokens, pIdx[j]) is "stack" and _T(pTokens, pIdx[j - 1]) is not "this" then
            put j into k
            exit repeat
         end if
      end repeat
      if k is empty or k = pEnd then return empty
      if _T(pTokens, pIdx[k + 1]) is among the words of "id this" then return empty
      put k + 1 into pStackAt
   else
      put pStackAt - 1 into k
      put "stack " into tStack
   end if
   put _ExpressionEnd(pTokens, pIdx, pStackAt, pEnd, "in as without") into tLast
   -- T43: a background of the stack ("go bkgnd "Workouts" of stack
   -- tName"), which this engine does not go to (it stays on the card it
   -- is on): its first card, where HyperCard went, as T69 has a "go
   -- bkgnd" without a stack go
   put pAt + 1 into tFirst
   if _T(pTokens, pIdx[tFirst]) is "to" then add 1 to tFirst
   if tFirst < k and _T(pTokens, pIdx[tFirst]) is among the words of "background bkgnd bg" then
      put "card 1 of " into tCard
      _Fire "T43 go to a card of a stack"
   end if
   _Fire "T16 go to a stack not open"
   put _Span(pTokens, pIdx, pStackAt, tLast) into tName
   if pStackAt < tLast and sProbe is not empty and not _Compiles("on hcProbe" & return & "get (" & tName & ")" & return & "end hcProbe") then
      put _Literal(tName) into tName
      _Fire "T33 more forms HyperCard took"
   end if
   return "do hcGo(" & _Literal(_Raw(pTokens, pIdx[pAt], pIdx[tFirst] - 1) & tCard & _Raw(pTokens, pIdx[tFirst], pIdx[pStackAt] - 1) & tStack & "tHCStack" & _Raw(pTokens, pIdx[tLast] + 1, pIdx[pEnd])) & ", " & _Literal(tName) & ")"
end _GoStack

-- T69: a "go" to a background without a card ("go to background
-- "Game"", Art Game's openStack, which then hid a button of that
-- background; "go bg i", "go next bkgnd"), which HyperCard went to the
-- first card of ("If you name a stack (or background) without specifying
-- a card, HyperCard goes to the first card of the stack (or background)",
-- its AppleScript reference), leaving "No such card" in the result when
-- there was no such background. This engine stays on the card it is on,
-- and then counts only that background's cards ("the number of this
-- card" is 0, "go to card 3" goes to its third) until a "go" names a card.
-- The statement goes to the library's hcGoBackground with the
-- background's id, its name or number, or the ordinal that names it. A
-- "go" with more after the background ("of this stack", "in a new
-- window") gets "card 1 of" before the background instead, which goes to
-- its first card too (or to the stack's first card when there is no such
-- background). Empty when the "go" names no background, or a card
private function _GoBackground pTokens, pIdx, pAt, pEnd
   local j, k, tWord, tMore
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "to" then add 1 to j
   if j >= pEnd then return empty
   put _T(pTokens, pIdx[j]) into tWord
   if tWord is not among the words of kBackgroundWords then
      if tWord is not among the words of kBackgroundOrdinals then return empty
      if _T(pTokens, pIdx[j + 1]) is not among the words of kBackgroundWords then return empty
   end if
   put false into tMore
   repeat with k = j + 1 to pEnd
      if _T(pTokens, pIdx[k]) is among the words of "stack in as" then put true into tMore
   end repeat
   _Fire "T69 go to a background"
   if tMore or (tWord is among the words of kBackgroundOrdinals and j + 1 < pEnd) then
      return _Span(pTokens, pIdx, pAt, j - 1) && "card 1 of" && _Span(pTokens, pIdx, j, pEnd)
   end if
   if tWord is among the words of kBackgroundOrdinals then
      return "hcGoBackground" && quote & tWord & quote
   end if
   if _T(pTokens, pIdx[j + 1]) is "id" and j + 2 <= pEnd then
      return "hcGoBackground" && quote & "id" & quote & "," && _Span(pTokens, pIdx, j + 2, pEnd)
   end if
   return "hcGoBackground" && quote & "name" & quote & "," && _Span(pTokens, pIdx, j + 1, pEnd)
end _GoBackground

-- T43: where the stack starts in a go to a card or a background of a
-- stack named without the word "stack": after "of" following a
-- background ("go last cd of bg "stocks" of stackName", "go bkgnd
-- "Workouts" of importStack"), or after "in" following a card or a
-- background ("go to card "Help" in "Mailing List Maker"", "go last card
-- in omaNimi", which this engine compiles as a window and stops at when
-- it runs), which HyperCard took as "of stack". That "in" becomes "of".
-- Empty if there is none ("of" after a card alone is T31's, in a script
-- that does not compile)
private function _GoStackAt @pTokens, pIdx, pAt, pEnd
   local j, tItem, tNext, tDepth, tAt, tBackground
   put false into tAt
   put false into tBackground
   put 0 into tDepth
   repeat with j = pAt + 1 to pEnd - 1
      put _T(pTokens, pIdx[j]) into tItem
      if tItem is "(" then add 1 to tDepth
      if tItem is ")" then subtract 1 from tDepth
      if tDepth > 0 or tItem is ")" then next repeat
      if tItem is among the words of "card cd" then put true into tAt
      if tItem is among the words of "background bkgnd bg" then
         put true into tAt
         put true into tBackground
      end if
      if tItem is among the words of "stack char character word item line url" then return empty
      if tAt and (tItem is "in" or (tItem is "of" and tBackground)) then
         put _T(pTokens, pIdx[j + 1]) into tNext
         -- (a card's background, whose own "of" may follow)
         if tItem is "of" and tNext is among the words of "background bkgnd bg" then next repeat
         if pTokens[pIdx[j + 1]]["k"] is "s" or (pTokens[pIdx[j + 1]]["k"] is "w" \
               and tNext is not among the words of kGoPlaces and tNext is not among the words of kObjectWords \
               and tNext is not among the words of "the me target a new window this") then
            put "of" into pTokens[pIdx[j]]["t"]
            _Fire "T43 go to a card of a stack"
            return j + 1
         end if
         return empty
      end if
   end repeat
   return empty
end _GoStackAt

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

-- T40: open an application, or a document with one ("open "TeachText"",
-- "open tDoc with tApp", "open MacDraw 1.9.5"), which HyperCard launched,
-- asking "Where is ...?" when it could not find the application and
-- failing that leaving "Couldn't open that application." in the result.
-- This engine takes an "open" of anything but a file, printing, a process
-- or a socket for a "go", which stops with an error when there is no
-- such stack; the library's hcOpen launches the application instead. And
-- HyperCard 2.4's "open url", which gave the URL to the browser (launch
-- url here), and "open report printing" in a script that compiles, which
-- T12 takes in one that does not. An "open" of what this engine opens
-- (kOpenWords), or of a place a "go" names ("open stack", which
-- HyperCard did not have), is left as it is
private function _OpenApplication pTokens, pIdx, pAt, pEnd
   local tWord, tLast
   if pAt = pEnd then return empty
   put _T(pTokens, pIdx[pAt + 1]) into tWord
   if tWord is "url" and pAt + 1 < pEnd then
      _Fire "T40 open an application"
      return "launch url" && _Span(pTokens, pIdx, pAt + 2, pEnd)
   end if
   if tWord is "report" and pAt + 2 = pEnd and _T(pTokens, pIdx[pEnd]) is "printing" then
      _Fire "T12 HyperCard command to the library"
      return "hcOpenReportPrinting empty"
   end if
   if tWord is among the words of kOpenWords or tWord is among the words of kGoPlaces or tWord is "with" then return empty
   if tWord is "the" and _T(pTokens, pIdx[pAt + 2]) is among the words of kGoPlaces then return empty
   -- (the document, then "with" and the application)
   put _ExpressionEnd(pTokens, pIdx, pAt + 1, pEnd, "with") into tLast
   if tLast = pEnd - 1 then return empty
   _Fire "T40 open an application"
   if tLast < pEnd then
      return "hcOpen" && _OpenName(pTokens, pIdx, tLast + 2, pEnd) & ", " & _OpenName(pTokens, pIdx, pAt + 1, tLast)
   end if
   return "hcOpen" && _OpenName(pTokens, pIdx, pAt + 1, pEnd)
end _OpenApplication

-- T40: the code tokens pFrom to pTo as the name of an application or a
-- document. A name HyperCard took as the text it was, words, numbers,
-- dots and the colons of an HFS path ("open MacDraw 1.9.5", "open Hard
-- Disk:Apps:VersaTerm Pro"), is put in quotes, and so is one word this
-- engine does not take as a value; anything else is an expression, kept
-- as it is unless the probe finds it is no expression here, when its text
-- is the name
private function _OpenName pTokens, pIdx, pFrom, pTo
   local j, tKind, tWords, tSpan
   put _Span(pTokens, pIdx, pFrom, pTo) into tSpan
   put 0 into tWords
   repeat with j = pFrom to pTo
      put pTokens[pIdx[j]]["k"] into tKind
      if tKind is "w" and _T(pTokens, pIdx[j]) is not among the words of kNotPlain then
         add 1 to tWords
      else if not (tKind is "n" or (tKind is "p" and pTokens[pIdx[j]]["t"] is among the chars of ".:")) then
         put empty into tWords
         exit repeat
      end if
   end repeat
   if tWords is not empty and tWords > 0 then
      if pFrom < pTo or _ValueRefused(tSpan) then return _Literal(tSpan)
      return tSpan
   end if
   -- (in parentheses: get takes an expression and leaves the rest of the
   -- line, so "get go to card 3" compiles)
   if sProbe is not empty and not _Compiles("on hcProbe" & return & "get (" & tSpan & ")" & return & "end hcProbe") then return _Literal(tSpan)
   return tSpan
end _OpenName

-- T24 and T71: print. HyperCard printed cards ("print card", "print this
-- card", "print 6 cards", "print it cards", "print marked cards", "print
-- first card of bg "PPRINT"", "print card from 0,84 to 506,1274"), as
-- this engine does, and the text of any expression (T71: "print it",
-- "print allHelp", "print "Index" & return & temp", "print (bg field id
-- 5)"), which this engine stops at ("error in object expression") or
-- does not compile ("print "a" & b"): the library's hcPrint, which prints
-- the text as HyperCard did. A field alone (T24: "print card field
-- "Notes"") goes to the library's PrintField; one joined with more text
-- ("print fld "scripter1" & return & fld "scripter2"") is an expression.
-- "print <document> with <application>" ("print temp with "teachText"",
-- a file of text a script wrote), which HyperCard had the application
-- print: the library's hcPrintDocument, the names as T40's ("open tDoc
-- with tApp"). This engine's own forms ("print break", "print anchor")
-- are left as they are
private function _Print pTokens, pIdx, pAt, pEnd
   local j, tFirst, tDepth, tJoined, tLast
   if pAt >= pEnd then return empty
   put _T(pTokens, pIdx[pAt + 1]) into tFirst
   if tFirst is among the words of "break anchor link bookmark unicode" then return empty
   -- (cards: a number of cards, or a card, with "the", "this" or a place,
   -- each with "from" a point "to" a point after it or not)
   repeat with j = pAt + 1 to pEnd
      if _T(pTokens, pIdx[j]) is among the words of "cards cds" \
            and (j = pEnd or _T(pTokens, pIdx[j + 1]) is "from") then
         return empty
      end if
   end repeat
   put pAt + 1 into j
   if tFirst is "the" then add 1 to j
   if _T(pTokens, pIdx[j]) is among the words of "this next prev previous first second third fourth fifth sixth seventh eighth ninth tenth last middle any recent" then add 1 to j
   if _T(pTokens, pIdx[j]) is among the words of "card cd" and _T(pTokens, pIdx[j + 1]) is not among the words of "field fld" then return empty
   -- (an "&" outside parentheses joins more text to a field)
   put 0 into tDepth
   put false into tJoined
   repeat with j = pAt + 1 to pEnd
      if _T(pTokens, pIdx[j]) is "(" then add 1 to tDepth
      if _T(pTokens, pIdx[j]) is ")" then subtract 1 from tDepth
      if tDepth = 0 and _T(pTokens, pIdx[j]) is "&" then put true into tJoined
   end repeat
   put pAt + 1 into j
   if tFirst is among the words of "card cd background bkgnd bg" then add 1 to j
   if _T(pTokens, pIdx[j]) is among the words of "field fld" and j < pEnd and not tJoined then
      _Fire "T24 print a field"
      return "PrintField the long id of" && _Span(pTokens, pIdx, pAt + 1, pEnd)
   end if
   put _ExpressionEnd(pTokens, pIdx, pAt + 1, pEnd, "with") into tLast
   if tLast = pEnd - 1 then return empty
   if tLast < pEnd then
      _Fire "T71 print a document with an application"
      return "hcPrintDocument" && _OpenName(pTokens, pIdx, pAt + 1, tLast) & ", " & _OpenName(pTokens, pIdx, tLast + 2, pEnd)
   end if
   _Fire "T71 print an expression"
   return "hcPrint" && _Span(pTokens, pIdx, pAt + 1, pEnd)
end _Print

-- T73: ask password, which HyperCard answered with a number it made from
-- the reply, not with the reply. Scripts kept the number and compared a
-- later reply's with it ("ask password "Enter Password"", then "if
-- password <> passwordEntered then ... doMenu "Quit HyperCard"",
-- Jerome's Journal, whose card keeps 1114205292, an empty reply's
-- number), or with a number of their own ("if it = 2170878455", Sword
-- Play's). This engine's ask password gives the reply as it was typed,
-- which no number matches: the library's hcAskPassword, which puts
-- HyperCard's number into it, and nothing when the dialog is cancelled.
-- "ask password clear", the reply as typed, is the same here and is left
-- as it is
private function _AskPassword pTokens, pIdx, pAt, pEnd
   local tLast
   if pAt + 2 > pEnd or _T(pTokens, pIdx[pAt + 1]) is not "password" then return empty
   if _T(pTokens, pIdx[pAt + 2]) is "clear" then return empty
   put _ExpressionEnd(pTokens, pIdx, pAt + 2, pEnd, "with") into tLast
   if tLast = pEnd - 1 then return empty
   _Fire "T73 ask password"
   if tLast < pEnd then
      return "hcAskPassword it," && _Span(pTokens, pIdx, pAt + 2, tLast) & "," && _Span(pTokens, pIdx, tLast + 2, pEnd)
   end if
   return "hcAskPassword it," && _Span(pTokens, pIdx, pAt + 2, pEnd)
end _AskPassword

-- T42: do with a statement not in quotes ("do go cd id 13086", "do put
-- offset(x, y) into z"), which HyperCard ran as the statement it was.
-- Here do takes an expression: the line does not compile, or does and
-- runs the first word alone ("do go cd "Two"" does "go", which stops
-- with an error). The statement is put in quotes, where the probe finds
-- it is no expression and compiles as a statement; do then runs it in
-- the handler's context, its variables included. A do of an expression
-- ("do tCommands") is left as it is, and so is HyperCard 2.2's "do
-- tScript as AppleScript"
private function _DoStatement pTokens, pIdx, pAt, pEnd
   local tSpan, j
   if pAt = pEnd or sProbe is empty or pTokens[pIdx[pAt + 1]]["k"] is not "w" then return empty
   repeat with j = pAt + 1 to pEnd
      if _T(pTokens, pIdx[j]) is "as" then return empty
   end repeat
   put _Span(pTokens, pIdx, pAt + 1, pEnd) into tSpan
   -- (in parentheses, as get takes an expression and leaves the rest of
   -- the line: "get go to card 3" compiles)
   if _Compiles("on hcProbe" & return & "get (" & tSpan & ")" & return & "end hcProbe") then return empty
   if not _Compiles("on hcProbe" & return & tSpan & return & "end hcProbe") then return empty
   _Fire "T42 do with a statement not in quotes"
   return "do" && _Literal(tSpan)
end _DoStatement

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
   if sValueRefused[pName] is empty then
      put not _Compiles("on hcProbe" & return & "get" && pName & return & "end hcProbe") into sValueRefused[pName]
   end if
   return sValueRefused[pName]
end _ValueRefused

-- The first word of the statement code token pAt is in: the line's,
-- or the one after the nearest "then" or "else" before it (T35: "if c
-- then send x to card")
private function _StatementWord pTokens, pIdx, pAt
   repeat while pAt > 1 and _T(pTokens, pIdx[pAt - 1]) is not among the words of "then else"
      subtract 1 from pAt
   end repeat
   return _T(pTokens, pIdx[pAt])
end _StatementWord

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
            and _T(tTokens, tIdx[i + 5]) is among the words of "of in" and _T(tTokens, tIdx[i + 6]) is "menu" then
         _Replace tTokens, tIdx, i, i + 7, "hcMenuItem(" & quote & _T(tTokens, tIdx[i + 1]) & quote & comma && _MenuName(tTokens, tIdx, i + 7, i + 7) & comma && _MenuName(tTokens, tIdx, i + 4, i + 4) & ")"
         _Fire "T22 HyperCard menus"
         put true into tChanged
      end if
   end repeat
   -- ... without the ("if checkMark of menuItem 1 of menu M"), or with
   -- "in menu", which HyperCard took too
   repeat with i = 1 to n - 6
      if _T(tTokens, tIdx[i]) is among the words of kMenuProperties and _T(tTokens, tIdx[i - 1]) is not among the words of "the set" \
            and tTokens[tIdx[i]]["k"] is "w" \
            and _T(tTokens, tIdx[i + 1]) is "of" and _T(tTokens, tIdx[i + 2]) is "menuitem" \
            and _T(tTokens, tIdx[i + 4]) is among the words of "of in" and _T(tTokens, tIdx[i + 5]) is "menu" then
         _Replace tTokens, tIdx, i, i + 6, "hcMenuItem(" & quote & _T(tTokens, tIdx[i]) & quote & comma && _MenuName(tTokens, tIdx, i + 6, i + 6) & comma && _MenuName(tTokens, tIdx, i + 3, i + 3) & ")"
         _Fire "T22 HyperCard menus"
         put true into tChanged
      end if
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _MenuItemProperties

-- T48: HyperCard's menus read as values, which here read the IDE's menu
-- bar, or stop the script with "can't find background" where there is
-- none (any statement): the library's menus, as T22 keeps them.
--    there is [not] a menu M, there is no menu M: [not] hcThereIsMenu(M)
--    there is a menuItem I of menu M: hcThereIsMenu(M, I)
--    the menus, the number of menus: hcMenus(), hcMenuCount()
--    [the] number of menuItems of menu M: hcMenuItemCount(M)
--    [the] P of menu M, of menuItem I or [the] last menuItem of menu M
--    (not after set, nor what _MenuItemProperties took):
--    hcMenuItem("P", M, I), I empty for the menu's own name and enabled
--    [the last] menuItem I of menu M: hcMenuItem("name", M, I)
--    menu M ("put menu "Font" into tFonts", "if x is in menu 5", "line 2
--    of menu 7"): hcMenuText(M)
-- "in menu" is "of menu". M is one token, a call or a group in
-- parentheses, and so is I, or several words before "of menu". A menu
-- or a menu item that its statement puts into, creates, deletes,
-- enables, disables or sets is T22's, and is left as it is
private function _MenuReads pLine
   local tTokens, tCode, tIdx, n, tItem, i, j, tWord, tStart, tLast, tNot, tText, tRef, tChanged
   if "menu" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   put 1 into i
   repeat while i <= n
      put _T(tTokens, tIdx[i]) into tWord
      put i into tStart
      put empty into tText
      put empty into tRef
      if tWord is "there" and _T(tTokens, tIdx[i + 1]) is "is" then
         -- there is [not] a menu M, there is no menuItem I of menu M
         put i + 2 into j
         put false into tNot
         if _T(tTokens, tIdx[j]) is "not" then
            put true into tNot
            add 1 to j
         end if
         if _T(tTokens, tIdx[j]) is "no" then put true into tNot
         if _T(tTokens, tIdx[j]) is among the words of "a an no" \
               and _T(tTokens, tIdx[j + 1]) is among the words of "menu menuitem" then
            put _MenuRef(tTokens, tIdx, j + 1, n) into tRef
            if tRef["kind"] is "menu" then
               put "hcThereIsMenu(" & tRef["menu"] & ")" into tText
            else if tRef["kind"] is "item" then
               put "hcThereIsMenu(" & tRef["menu"] & comma && tRef["item"] & ")" into tText
            end if
            if tText is not empty and tNot then put "not" && tText into tText
         end if
      else if tWord is "the" and _T(tTokens, tIdx[i + 1]) is "menus" then
         put "hcMenus()" into tText
         put i + 1 into tRef["end"]
      else if tWord is "number" and _T(tTokens, tIdx[i + 1]) is "of" then
         -- [the] number of menus, [the] number of menuItems of menu M
         if _T(tTokens, tIdx[i - 1]) is "the" then put i - 1 into tStart
         if _T(tTokens, tIdx[i + 2]) is "menus" then
            put "hcMenuCount()" into tText
            put i + 2 into tRef["end"]
         else if _T(tTokens, tIdx[i + 2]) is "menuitems" and _T(tTokens, tIdx[i + 3]) is among the words of "of in" \
               and _T(tTokens, tIdx[i + 4]) is "menu" then
            put _MenuRef(tTokens, tIdx, i + 4, n) into tRef
            if tRef["kind"] is "menu" then put "hcMenuItemCount(" & tRef["menu"] & ")" into tText
         end if
      else if tWord is among the words of kMenuProperties and _T(tTokens, tIdx[i + 1]) is "of" \
            and _T(tTokens, tIdx[i + 2]) is among the words of ("menu menuitem the" && kMenuOrdinals) \
            and _T(tTokens, tIdx[i - 1]) is not among the words of "short long abbr abbrev abbreviated" then
         -- [the] P of menu M, [the] P of menuItem I of menu M
         if _T(tTokens, tIdx[i - 1]) is "the" then put i - 1 into tStart
         put _MenuRef(tTokens, tIdx, i + 2, n) into tRef
         if tRef["end"] is not empty then
            if _T(tTokens, tIdx[tStart - 1]) is "set" then
               -- (set's, T22's)
               put tRef["end"] + 1 into i
               next repeat
            end if
            put "hcMenuItem(" & quote & tWord & quote & comma && tRef["menu"] & comma && tRef["item"] & ")" into tText
         end if
      else if tWord is "menuitem" or (tWord is among the words of kMenuOrdinals and _T(tTokens, tIdx[i + 1]) is "menuitem") then
         -- [the last] menuItem I of menu M
         if tWord is not "menuitem" and _T(tTokens, tIdx[i - 1]) is "the" then put i - 1 into tStart
         put _MenuRef(tTokens, tIdx, i, n) into tRef
         if tRef["end"] is not empty then
            if _MenuWritten(tTokens, tIdx, tStart) then
               put tRef["end"] + 1 into i
               next repeat
            end if
            put "hcMenuItem(" & quote & "name" & quote & comma && tRef["menu"] & comma && tRef["item"] & ")" into tText
         end if
      else if tWord is "menu" then
         -- menu M, its items
         put _MenuRef(tTokens, tIdx, i, n) into tRef
         if tRef["end"] is not empty then
            if _MenuWritten(tTokens, tIdx, i) or _MenuOfMenuItem(tTokens, tIdx, i) then
               put tRef["end"] + 1 into i
               next repeat
            end if
            put "hcMenuText(" & tRef["menu"] & ")" into tText
         end if
      end if
      if tText is empty then
         add 1 to i
         next repeat
      end if
      put tRef["end"] into tLast
      _Replace tTokens, tIdx, tStart, tLast, tText
      _Fire "T48 HyperCard menus read"
      put true into tChanged
      put tLast + 1 into i
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _MenuReads

-- The menu or menu item named from pAt to no further than pTo: "menu M",
-- "menuItem I of menu M", or "[the] last menuItem of menu M" with pAt the
-- "last" or the "the". ["kind"] "menu" or "item", ["menu"] M, ["item"] I
-- (the place in quotes, "last"; "empty" for a menu), ["end"] its last
-- code token; empty if it is none of these (_MenuReads)
private function _MenuRef pTokens, pIdx, pAt, pTo
   local tRef, j, k, tEnd
   put pAt into j
   if _T(pTokens, pIdx[j]) is "the" and _T(pTokens, pIdx[j + 1]) is among the words of kMenuOrdinals then add 1 to j
   if _T(pTokens, pIdx[j]) is "menu" then
      put _MenuOperandEnd(pTokens, pIdx, j + 1, pTo) into tEnd
      if tEnd is empty then return empty
      put "menu" into tRef["kind"]
      put _MenuName(pTokens, pIdx, j + 1, tEnd) into tRef["menu"]
      put "empty" into tRef["item"]
      put tEnd into tRef["end"]
      return tRef
   end if
   if _T(pTokens, pIdx[j]) is among the words of kMenuOrdinals and _T(pTokens, pIdx[j + 1]) is "menuitem" then
      put quote & _T(pTokens, pIdx[j]) & quote into tRef["item"]
      add 2 to j
   else if _T(pTokens, pIdx[j]) is "menuitem" then
      put _MenuOperandEnd(pTokens, pIdx, j + 1, pTo) into tEnd
      if tEnd is empty or _T(pTokens, pIdx[tEnd + 1]) is not among the words of "of in" or _T(pTokens, pIdx[tEnd + 2]) is not "menu" then
         -- a name of several words: to the "of menu" ("menuItem item x
         -- of fontList in menu "Font""), with none of kMenuItemStops
         put _FindWord(pTokens, pIdx, j + 1, pTo, "of in", "menu") into tEnd
         if tEnd is empty or tEnd = j + 1 then return empty
         subtract 1 from tEnd
         repeat with k = j + 1 to tEnd
            if _T(pTokens, pIdx[k]) is among the words of kMenuItemStops or _T(pTokens, pIdx[k]) is among the items of "=,<,>" then return empty
         end repeat
      end if
      put _MenuName(pTokens, pIdx, j + 1, tEnd) into tRef["item"]
      put tEnd + 1 into j
   else
      return empty
   end if
   if _T(pTokens, pIdx[j]) is not among the words of "of in" or _T(pTokens, pIdx[j + 1]) is not "menu" then return empty
   put _MenuOperandEnd(pTokens, pIdx, j + 2, pTo) into tEnd
   if tEnd is empty then return empty
   put "item" into tRef["kind"]
   put _MenuName(pTokens, pIdx, j + 2, tEnd) into tRef["menu"]
   put tEnd into tRef["end"]
   return tRef
end _MenuRef

-- The last code token of a menu's or a menu item's name or number that
-- starts at pFrom: a string, a number, a name (a variable's, or one
-- HyperCard took as its text) with the parentheses of its call if it is
-- a function's, or a group in parentheses; empty if there is none
private function _MenuOperandEnd pTokens, pIdx, pFrom, pTo
   local j, tDepth
   if pFrom > pTo then return empty
   if pTokens[pIdx[pFrom]]["k"] is among the words of "s n" then return pFrom
   if pTokens[pIdx[pFrom]]["k"] is "w" then
      if _T(pTokens, pIdx[pFrom]) is among the words of kMenuNotNames then return empty
      if pFrom = pTo or _T(pTokens, pIdx[pFrom + 1]) is not "(" then return pFrom
      add 1 to pFrom
   else if _T(pTokens, pIdx[pFrom]) is not "(" then
      return empty
   end if
   put 0 into tDepth
   repeat with j = pFrom to pTo
      if _T(pTokens, pIdx[j]) is "(" then add 1 to tDepth
      if _T(pTokens, pIdx[j]) is ")" then
         subtract 1 from tDepth
         if tDepth = 0 then return j
      end if
   end repeat
   return empty
end _MenuOperandEnd

-- The name or number of a menu or a menu item, the code tokens pFrom to
-- pTo, as the library's handlers take it: one word that this engine does
-- not take as a value ("create menu Control", "Control" an object type
-- here; only with a probe) in quotes, the text HyperCard took it for;
-- anything else as it is, a variable's name too
private function _MenuName pTokens, pIdx, pFrom, pTo
   if pFrom = pTo and pTokens[pIdx[pFrom]]["k"] is "w" and _ValueRefused(pTokens[pIdx[pFrom]]["t"]) then
      return _Literal(pTokens[pIdx[pFrom]]["t"])
   end if
   return _Span(pTokens, pIdx, pFrom, pTo)
end _MenuName

-- _MenuName for the text of a menu's name that T12 takes from a line
-- ("create menu Control", "delete menu 5 -- Tools"): its one code token
-- in quotes if it is a word this engine does not take as a value
private function _MenuNameText pText
   local tTokens, tCode
   put _Tokens(pText) into tTokens
   put _Code(tTokens) into tCode
   if tCode is not an integer then return pText
   if tTokens[tCode]["k"] is not "w" or not _ValueRefused(tTokens[tCode]["t"]) then return pText
   put _Literal(tTokens[tCode]["t"]) into tTokens[tCode]["t"]
   return _Join(tTokens)
end _MenuNameText

-- Whether the menu or menu item named from pStart is what its statement
-- changes, T22's: after into, after or before (put), create, delete,
-- enable, disable or from (delete ... from menu); a property's when the
-- property was not taken as a value (set the checkMark of menuItem ...);
-- after "a", "an" or "no" (there is a ...) when that was not taken; or
-- an object's name ("go to card menu 2")
private function _MenuWritten pTokens, pIdx, pStart
   local tBefore
   put _T(pTokens, pIdx[pStart - 1]) into tBefore
   if tBefore is among the words of "into after before create delete enable disable from a an no" then return true
   if tBefore is among the words of "card cd field fld button btn background bkgnd bg stack window part" then return true
   if tBefore is among the words of "of in" and _T(pTokens, pIdx[pStart - 2]) is among the words of kMenuProperties then return true
   return false
end _MenuWritten

-- Whether "menu" at pAt, after "of" or "in", is the menu of a menuItem
-- before it that was not taken as a value ("disable menuItem x of menu
-- y", "delete menuItem item 2 of tList of menu y")
private function _MenuOfMenuItem pTokens, pIdx, pAt
   local j
   if _T(pTokens, pIdx[pAt - 1]) is not among the words of "of in" then return false
   repeat with j = pAt - 2 down to 1
      if _T(pTokens, pIdx[j]) is "menuitem" then return true
      if _T(pTokens, pIdx[j]) is among the words of "menu menus menuitems then else" then return false
   end repeat
   return false
end _MenuOfMenuItem

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
   repeat with i = n - 2 down to 1
      if _T(tTokens, tIdx[i]) is "the" and _T(tTokens, tIdx[i - 1]) is not "set" \
            and _T(tTokens, tIdx[i + 1]) is among the words of kMessageBoxProperties \
            and _T(tTokens, tIdx[i + 2]) is "of" then
         put _MessageBoxRef(tTokens, tIdx, i + 3) into tRef
         if tRef > 0 then
            _Replace tTokens, tIdx, i, i + 2 + tRef, "hcMessageBox(" & quote & _T(tTokens, tIdx[i + 1]) & quote & ")"
            _Fire "T28 message box properties"
            put true into tChanged
         end if
      else if _T(tTokens, tIdx[i]) is among the words of kMessageBoxProperties and _T(tTokens, tIdx[i + 1]) is "of" \
            and _T(tTokens, tIdx[i - 1]) is not among the words of "the set" then
         -- T46: and without "the" ("if visible of msg", "item 2 of loc
         -- of msg")
         put _MessageBoxRef(tTokens, tIdx, i + 2) into tRef
         if tRef > 0 then
            _Replace tTokens, tIdx, i, i + 1 + tRef, "hcMessageBox(" & quote & _T(tTokens, tIdx[i]) & quote & ")"
            _Fire "T46 HyperCard's windows"
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

-- T46: a property of the card window, in a script that compiles too: the
-- window of this stack, its loc its top left ("put item 1 of it + item 1
-- of loc of card window +191 into horiz", WorkStation's; "left of card
-- window + left of me + 1", HyperFTP's). Without "the" and followed by a
-- plus, a minus or a comma, it compiles here, as a card of a stack named
-- by what follows, and stops there ("can't find stack"); a script that
-- does not compile has had it rewritten by _PhraseRules already
private function _CardWindow pLine
   local tTokens, tCode, tIdx, n, tItem, i, tAt, tChanged
   if "window" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   put false into tChanged
   repeat with i = 2 to n - 1
      if _T(tTokens, tIdx[i]) is not among the words of "card cd" or _T(tTokens, tIdx[i + 1]) is not "window" then next repeat
      put i into tAt
      if _T(tTokens, tIdx[tAt - 1]) is "the" then subtract 1 from tAt
      if tAt < 3 or _T(tTokens, tIdx[tAt - 1]) is not "of" then next repeat
      if _T(tTokens, tIdx[tAt - 2]) is among the words of "loc location" then
         put "topLeft" into tTokens[tIdx[tAt - 2]]["t"]
      end if
      _Replace tTokens, tIdx, tAt, i + 1, "this stack"
      put true into tChanged
      _Fire "T46 HyperCard's windows"
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _CardWindow

-- T28: the properties of HyperCard's own windows ("the visible of tool
-- window", "set the visible of the variable watcher to true"), which
-- this engine does not have: what a script sets reads back
-- (hcWindowProperty and hcSetWindow in the library). T46: and any
-- window's place, which the library gives as HyperCard did
private function _HyperCardWindows pLine
   local tTokens, tCode, tIdx, n, tItem, i, j, k, tStart, tProperty, tName, tEnd, tSet
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
      put _T(tTokens, tIdx[i - 1]) into tProperty
      put i - 1 into tStart
      if _T(tTokens, tIdx[tStart - 1]) is "the" then subtract 1 from tStart
      put _T(tTokens, tIdx[tStart - 1]) is "set" and (tStart = 2 or _T(tTokens, tIdx[tStart - 2]) is among the words of "then else") into tSet
      -- (tName: the window's name in quotes, or T46's window; k: its
      -- last token)
      put empty into tName
      put j + 1 into k
      if _T(tTokens, tIdx[j]) is among the words of "tool tools pattern patterns scroll fatbits navigator" and _T(tTokens, tIdx[j + 1]) is "window" then
         put quote & _T(tTokens, tIdx[j]) & quote into tName
         _Fire "T28 message box properties"
      else if _T(tTokens, tIdx[j]) is among the words of "variable message" and _T(tTokens, tIdx[j + 1]) is "watcher" then
         put quote & _T(tTokens, tIdx[j]) && "watcher" & quote into tName
         _Fire "T28 message box properties"
      else if _T(tTokens, tIdx[j]) is "window" and tTokens[tIdx[j + 1]]["k"] is "s" \
            and _Lower(char 2 to -2 of tTokens[tIdx[j + 1]]["t"]) is among the items of kHCOwnWindows then
         -- T46: one of them named in quotes ("the visible of window
         -- "Scroll""), which here would be a stack
         put tTokens[tIdx[j + 1]]["t"] into tName
         _Fire "T46 HyperCard's windows"
      else if _T(tTokens, tIdx[j]) is "window" and j < n and _MessageBoxRef(tTokens, tIdx, j) = 0 \
            and tProperty is among the words of kWindowPlaces and not (tSet and tProperty is among the words of "globalloc globalrect") then
         -- T46: a window's place, which HyperCard gave from the card
         -- window's top left for every window but a card window, and
         -- this engine gives a stack's on the screen, its loc its centre:
         -- the library's, which finds which window it is. (T26 sets a
         -- window's globalLoc and globalRect)
         put _WindowRef(tTokens, tIdx, j + 1, n) into k
         if k is empty then next repeat
         if k = j + 1 then
            put _PlainName(tTokens, tIdx, k, k, false) into tName
         else
            put _Span(tTokens, tIdx, j + 1, k) into tName
         end if
         _Fire "T46 HyperCard's windows"
      else if _T(tTokens, tIdx[j]) is "window" and j < n and _MessageBoxRef(tTokens, tIdx, j) = 0 \
            and tProperty is not among the words of kWindowProperties and _WindowPropertyRefused(tProperty, tStart < i - 1, tSet) then
         -- T60: a property this engine has for no window, of the window of
         -- an external ("set the scrollbar of window "Message Crate" to
         -- 8", Development Library's; "set selectedLine of window
         -- "TheList" to x", Listoid's; "put currTime of window
         -- demoMovieName into MovieCurrTime", QuickTime Tools'; "put
         -- Btn1Name of window "Chiclette Editor" into windName",
         -- Chiclette's), which HyperCard handed to the external and this
         -- engine refuses (the import left the line or its handler out),
         -- or in a get takes for a get and a call that fails each time it
         -- runs (_WindowPropertyRefused): the library's, as for
         -- HyperCard's own windows. No external runs
         -- here, so its window is never open: a set leaves "No such
         -- window" in the result, as HyperCard did for a window that was
         -- not, and a read gives empty
         put _WindowRef(tTokens, tIdx, j + 1, n) into k
         if k is empty then next repeat
         if k = j + 1 then
            put _PlainName(tTokens, tIdx, k, k, false) into tName
         else
            put _Span(tTokens, tIdx, j + 1, k) into tName
         end if
         _Fire "T60 the properties of an external's window"
      end if
      if tName is empty then next repeat
      if tSet and _T(tTokens, tIdx[k + 1]) is "to" and k + 1 < n then
         put _FindWord(tTokens, tIdx, k + 2, n, "else", empty) into tEnd
         if tEnd is empty then
            put n into tEnd
         else
            subtract 1 from tEnd
         end if
         _Replace tTokens, tIdx, tStart - 1, tEnd, "hcSetWindow" && quote & tProperty & quote & comma && tName & comma && _HyperCardWindows(_Span(tTokens, tIdx, k + 2, tEnd))
         -- (and what follows an else)
         return _HyperCardWindows(_Join(tTokens))
      end if
      _Replace tTokens, tIdx, tStart, k, "hcWindowProperty(" & quote & tProperty & quote & comma && tName & ")"
   end repeat
   return _Join(tTokens)
end _HyperCardWindows

-- T46: the last code token of the window named from pFrom, in a line's
-- code tokens to pTo: one word (a variable, or a name not in quotes) that
-- is no part of a longer expression, a name in quotes, or an expression
-- in parentheses; empty for another (window id 3, window 2, which this
-- engine finds no window by)
private function _WindowRef pTokens, pIdx, pFrom, pTo
   local tDepth, j
   if pFrom > pTo then return empty
   if pTokens[pIdx[pFrom]]["k"] is "s" then return pFrom
   if pTokens[pIdx[pFrom]]["k"] is "w" then
      if _T(pTokens, pIdx[pFrom]) is among the words of kNotPlain or _T(pTokens, pIdx[pFrom]) is among the words of "id to into then else" \
            or _T(pTokens, pIdx[pFrom]) is among the words of "item line word char character" then return empty
      if pFrom < pTo and (_T(pTokens, pIdx[pFrom + 1]) is among the words of "of (" or pTokens[pIdx[pFrom + 1]]["k"] is "n") then return empty
      return pFrom
   end if
   if pTokens[pIdx[pFrom]]["t"] is not "(" then return empty
   put 0 into tDepth
   repeat with j = pFrom to pTo
      if pTokens[pIdx[j]]["t"] is "(" then add 1 to tDepth
      if pTokens[pIdx[j]]["t"] is ")" then
         subtract 1 from tDepth
         if tDepth = 0 then return j
      end if
   end repeat
   return empty
end _WindowRef

-- T60: whether this engine refuses the property pProp of a window (a
-- stack here), read (or with pSet set) with "the" or, without pThe, with
-- none, by a probe of that form: one that is no property of an object of
-- this engine's ("scrollbar", "current", a function's name as
-- "selectedLine" for a set), or that it takes for a property only with
-- "the" ("currTime of window x"). A property of this engine's objects
-- (kChunkObjectProperties), a chunk's word or a word of the grammar is
-- left to the other rules, and with no probe (outside
-- revHyperCardFixScripts) none is refused. A read is probed in a put:
-- "get currTime of window x" compiles here, as "get currTime" and a call
-- of a handler "of" with the window as its parameter, which fails each
-- time it runs (a window is no container), so a get is fixed with the
-- rest
private function _WindowPropertyRefused pProp, pThe, pSet
   local tKey, tForm
   put _Lower(pProp) into pProp
   if sProbe is empty or not _IsName(pProp) or pProp is among the words of kNotPlain \
         or pProp is among the words of kChunkWords or pProp is among the words of kNeverNames or pProp is "number" \
         or pProp is among the words of kChunkObjectProperties then
      return false
   end if
   put pProp & comma & pThe & comma & pSet into tKey
   if sWindowPropertyRefused[tKey] is empty then
      put pProp && "of stack 1" into tForm
      if pThe then put "the" && tForm into tForm
      if pSet then
         put "set" && tForm && "to 1" into tForm
      else
         put "put" && tForm && "into tValue" into tForm
      end if
      put not _Compiles("on hcProbe" & return & tForm & return & "end hcProbe") into sWindowPropertyRefused[tKey]
   end if
   return sWindowPropertyRefused[tKey]
end _WindowPropertyRefused

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

-- T65: a stack that is not open, which HyperCard looked for where it
-- looked for the stack of a "go" (in the stack's folder, "if there is a
-- stack "Audio Help" then", or at a path from it, "if there is a stack
-- ":Support Files:Pictoid XCMD" then") and sent a message to ("send
-- "startSound" to stack "Audio Help""): here there is none until it is
-- open or in memory, the send stops with "can't find stack", and the
-- stack's companion is never used.
--    there is [not] a stack S, there is no stack S: [not] hcThereIsStack(S)
--    send M to stack S, S its statement's last words: send M to stack
--    hcSendStack(S)
-- S is a string, a variable or a group in parentheses (_StackRefEnd), not
-- Home (T45's) nor a word that is one of this engine's constants (T44's)
private function _StacksNotOpen pLine
   local tTokens, tCode, tIdx, n, tItem, i, j, tAt, tNot, tChanged
   if "stack" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = n down to 1
      if _T(tTokens, tIdx[i]) is "to" and _T(tTokens, tIdx[i + 1]) is "stack" and _StatementWord(tTokens, tIdx, i) is "send" then
         put _StackRefEnd(tTokens, tIdx, i + 1, n) into tAt
         if tAt > i + 1 and (tAt = n or _T(tTokens, tIdx[tAt + 1]) is "else") and _StackNotOpenName(tTokens, tIdx, i + 2, tAt) then
            _Replace tTokens, tIdx, i + 2, tAt, "hcSendStack(" & _Span(tTokens, tIdx, i + 2, tAt) & ")"
            _Fire "T65 a stack that is not open"
            put true into tChanged
         end if
         next repeat
      end if
      if _T(tTokens, tIdx[i]) is not "there" or _T(tTokens, tIdx[i + 1]) is not "is" then next repeat
      put i + 2 into j
      put false into tNot
      if _T(tTokens, tIdx[j]) is "not" then
         put true into tNot
         add 1 to j
      end if
      if _T(tTokens, tIdx[j]) is "no" then
         put true into tNot
      else if _T(tTokens, tIdx[j]) is not among the words of "a an" then
         next repeat
      end if
      if _T(tTokens, tIdx[j + 1]) is not "stack" then next repeat
      put _StackRefEnd(tTokens, tIdx, j + 1, n) into tAt
      -- (a stack alone is this one, which is open; and a name that does
      -- not end the phrase, "there is a stack line i of tList", "there is
      -- a stack "Notes" & n", is left as it was)
      if tAt <= j + 1 or not _StackNotOpenName(tTokens, tIdx, j + 2, tAt) then next repeat
      if tAt < n and _T(tTokens, tIdx[tAt + 1]) is not among the words of "then and or ) , else into" then next repeat
      if tNot then
         _Replace tTokens, tIdx, i, tAt, "not hcThereIsStack(" & _Span(tTokens, tIdx, j + 2, tAt) & ")"
      else
         _Replace tTokens, tIdx, i, tAt, "hcThereIsStack(" & _Span(tTokens, tIdx, j + 2, tAt) & ")"
      end if
      _Fire "T65 a stack that is not open"
      put true into tChanged
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _StacksNotOpen

-- T66: an object named by the short name of another, without "the" ("go
-- to card short name of the target", "show cd fld short name of me",
-- "send mouseUp to bg btn short name of me", "go cd c of stack short name
-- of me"), which HyperCard took for the object of that name, as both take
-- "card the short name of me": here "go" stays where it is and anything
-- else stops with an error. "the" before the name, a short, long or
-- abbreviated one
private function _NamedByAName pLine
   local tTokens, tCode, tIdx, n, tItem, i, tChanged
   if "name" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 1 to n - 3
      if _T(tTokens, tIdx[i]) is among the words of "card cd field fld button btn background bkgnd bg stack" \
            and _T(tTokens, tIdx[i + 1]) is among the words of "short long abbr abbrev abbreviated" \
            and tTokens[tIdx[i + 1]]["k"] is "w" \
            and _T(tTokens, tIdx[i + 2]) is "name" and _T(tTokens, tIdx[i + 3]) is "of" then
         put "the " before tTokens[tIdx[i + 1]]["t"]
         _Fire "T66 an object named by a name"
         put true into tChanged
      end if
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _NamedByAName

-- Whether the "in" at pAt is HyperCard's "of" between an object and the
-- card, background or stack it is on (T11): after an object's type
-- ("first card in bkgnd 2"), its name or number ("fld "Notes" in card
-- "Menu"") or its id ("btn id 3 in card 2"), before "card", "bkgnd",
-- "stack", or "this" and one of them. Never the operator "is in", a
-- count's "in" ("the number of card fields in card 2"), which this
-- engine takes, nor find's (_FindsIn)
private function _InForOf pTokens, pIdx, pAt
   local tPrev, tNext
   if pAt < 3 then return false
   put _T(pTokens, pIdx[pAt + 1]) into tNext
   if tNext is "this" then put _T(pTokens, pIdx[pAt + 2]) into tNext
   if tNext is not among the words of "card cd bkgnd bg background stack" then return false
   if _FindsIn(pTokens, pIdx, pAt) then return false
   put _T(pTokens, pIdx[pAt - 1]) into tPrev
   if tPrev is among the words of kObjectWords then return true
   if pTokens[pIdx[pAt - 1]]["k"] is not among the items of "s,n,w" or tPrev is "is" \
         or tPrev is among the words of kNeverNamesAfterCard then return false
   if _T(pTokens, pIdx[pAt - 2]) is among the words of kObjectWords then return true
   return pAt > 3 and _T(pTokens, pIdx[pAt - 2]) is "id" and _T(pTokens, pIdx[pAt - 3]) is among the words of kObjectWords
end _InForOf

-- Whether the "in" at pAt is find's, before the field it looks in
-- ("find word the short name of bkgnd btn id 122 in bkgnd field kk",
-- MacSUNRISE; "find cd fld "name" in cd fld "names"", Lesson 1 Severn
-- Ojibwe), which T11 does not take for "of" after the object that ends
-- the text to find
private function _FindsIn pTokens, pIdx, pAt
   return _T(pTokens, pIdx[pAt + 2]) is among the words of "field fld" \
         and _StatementWord(pTokens, pIdx, pAt) is "find"
end _FindsIn

-- T45: whether the word home at pAt, not in quotes, names HyperCard's
-- Home stack: the stack of a send ("send startup to home"), or what has
-- a property ("the long name of home"), cards ("the number of cards of
-- home") or a card ("card "Reset BBS" of home", "last card of home"), as
-- against a chunk of a variable called home ("word 2 of home", "the
-- length of home")
private function _HomeNamed pTokens, pIdx, pAt
   local tBefore, tOwner
   if pAt < 3 or pTokens[pIdx[pAt]]["k"] is not "w" or _T(pTokens, pIdx[pAt + 1]) is "(" then return false
   put _T(pTokens, pIdx[pAt - 1]) into tBefore
   if tBefore is "to" then return _StatementWord(pTokens, pIdx, pAt) is "send"
   if tBefore is not "of" then return false
   put _T(pTokens, pIdx[pAt - 2]) into tOwner
   if pTokens[pIdx[pAt - 2]]["k"] is "w" and (tOwner is among the words of kChunkObjectProperties \
         or tOwner is among the words of "name script cards cds backgrounds bkgnds bgs card cd background bkgnd bg") then return true
   -- (a card or a background by its name, number or id)
   if pAt > 3 and _T(pTokens, pIdx[pAt - 3]) is among the words of "card cd background bkgnd bg" then return true
   return pAt > 4 and _T(pTokens, pIdx[pAt - 3]) is "id" and _T(pTokens, pIdx[pAt - 4]) is among the words of "card cd background bkgnd bg"
end _HomeNamed

-- Whether the code tokens pFrom to pTo, a stack's name, are one T65
-- takes: not Home (T45's, which here is the IDE's own) nor a word that
-- is one of this engine's constants (T44's, quoted)
private function _StackNotOpenName pTokens, pIdx, pFrom, pTo
   local tName
   if pFrom < pTo then return true
   put _T(pTokens, pIdx[pFrom]) into tName
   if tName is "home" or tName is quote & "home" & quote then return false
   return not (pTokens[pIdx[pFrom]]["k"] is "w" and tName is among the words of kEngineConstants)
end _StackNotOpenName

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
   local j, k, tProperty, tTo, tObject, tValue, tNeeded, tWord, tDepth, tFrom
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   put _T(pTokens, pIdx[j]) into tProperty
   if _T(pTokens, pIdx[j + 1]) is not "of" then return empty
   -- the value follows the first "to" outside parentheses that is not a
   -- chunk's range's, which follows a chunk and its number after "of"
   -- ("set the textStyle of word 1 to 2 of me to "Bold,Condense"", Cool
   -- Address Book's; "of word sw+1 to slw of fld "situation" to
   -- "group"", the Dock stacks'), as the value can have a range of its
   -- own ("to item 1 to 2 of tStyles")
   put empty into tTo
   put 0 into tDepth
   put j + 2 into tFrom
   repeat with k = j + 2 to pEnd
      if _T(pTokens, pIdx[k]) is "(" then add 1 to tDepth
      if _T(pTokens, pIdx[k]) is ")" then subtract 1 from tDepth
      if tDepth is not 0 then next repeat
      if _T(pTokens, pIdx[k]) is "of" then put k + 1 into tFrom
      if _T(pTokens, pIdx[k]) is "to" and _T(pTokens, pIdx[tFrom]) is not among the words of "char character word item line" then
         put k into tTo
         exit repeat
      end if
   end repeat
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
   local j, tProperty, tMenu, tTo, tItem, tOrdinal
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   put _T(pTokens, pIdx[j]) into tProperty
   if tProperty is not among the words of kMenuProperties or _T(pTokens, pIdx[j + 1]) is not "of" then return empty
   put _FindWord(pTokens, pIdx, j + 2, pEnd, "to", empty) into tTo
   if tTo is empty or tTo = pEnd then return empty
   put j + 2 into tOrdinal
   if _T(pTokens, pIdx[tOrdinal]) is "the" then add 1 to tOrdinal
   if _T(pTokens, pIdx[j + 2]) is "menuitem" then
      put _FindWord(pTokens, pIdx, j + 3, tTo, "of in", "menu") into tMenu
      if tMenu is empty or tMenu = j + 3 or tMenu + 2 > tTo - 1 then return empty
      put _MenuName(pTokens, pIdx, j + 3, tMenu - 1) into tItem
      add 2 to tMenu
   else if _T(pTokens, pIdx[tOrdinal]) is among the words of kMenuOrdinals and _T(pTokens, pIdx[tOrdinal + 1]) is "menuitem" then
      -- set the checkMark of [the] last menuItem of menu M
      put _FindWord(pTokens, pIdx, tOrdinal + 2, tTo, "of in", "menu") into tMenu
      if tMenu is not tOrdinal + 2 or tMenu + 2 > tTo - 1 then return empty
      put quote & _T(pTokens, pIdx[tOrdinal]) & quote into tItem
      add 2 to tMenu
   else if _T(pTokens, pIdx[j + 2]) is "menu" and j + 3 < tTo then
      put "empty" into tItem
      put j + 3 into tMenu
   else
      return empty
   end if
   _Fire "T22 HyperCard menus"
   return "hcSetMenuItem" && quote & tProperty & quote & comma && _MenuName(pTokens, pIdx, tMenu, tTo - 1) & comma && tItem & comma && _Span(pTokens, pIdx, tTo + 1, pEnd)
end _SetMenuItem

-- put E into (after, before) menu M [with menuMsg(s) X], put E into
-- menuItem I of menu M: hcPutIntoMenu E, "into", M, X, I
private function _PutIntoMenu pTokens, pIdx, pAt, pEnd
   local tPrep, tWith, tMenu, tItem, tMessages, tOrdinal, tLast
   -- (from the first token of E, which may be a parenthesis: "put ("About"
   -- && tName) into menuItem 1 of menu 1")
   put _FindWord(pTokens, pIdx, pAt + 1, pEnd, "into after before", "menu menuitem") into tPrep
   if tPrep is empty then
      -- put E into [the] last menuItem of menu M
      put _FindWord(pTokens, pIdx, pAt + 1, pEnd, "into after before", kMenuOrdinals && "the") into tPrep
      if tPrep is not empty then
         put tPrep + 1 into tOrdinal
         if _T(pTokens, pIdx[tOrdinal]) is "the" then add 1 to tOrdinal
         if _T(pTokens, pIdx[tOrdinal]) is not among the words of kMenuOrdinals or _T(pTokens, pIdx[tOrdinal + 1]) is not "menuitem" then
            put empty into tPrep
         end if
      end if
   end if
   if tPrep is empty or tPrep = pAt + 1 or tPrep + 2 > pEnd then return empty
   put "empty" into tMessages
   put "empty" into tItem
   -- with menuMsgs X, after the menu or the item
   put _FindWord(pTokens, pIdx, tPrep + 2, pEnd, "with", "menumsg menumsgs menumessage menumessages") into tWith
   if tWith is not empty then
      if tWith + 2 > pEnd or tWith = tPrep + 2 then return empty
      put pEnd into tLast
      put tWith - 1 into pEnd
   end if
   if _T(pTokens, pIdx[tPrep + 1]) is "menuitem" then
      put _FindWord(pTokens, pIdx, tPrep + 2, pEnd, "of in", "menu") into tMenu
      if tMenu is empty or tMenu = tPrep + 2 or tMenu + 2 > pEnd then return empty
      put _MenuName(pTokens, pIdx, tPrep + 2, tMenu - 1) into tItem
      put _MenuName(pTokens, pIdx, tMenu + 2, pEnd) into tMenu
   else if tOrdinal is not empty then
      put _FindWord(pTokens, pIdx, tOrdinal + 2, pEnd, "of in", "menu") into tMenu
      if tMenu is not tOrdinal + 2 or tMenu + 2 > pEnd then return empty
      put quote & _T(pTokens, pIdx[tOrdinal]) & quote into tItem
      put _MenuName(pTokens, pIdx, tMenu + 2, pEnd) into tMenu
   else
      put _MenuName(pTokens, pIdx, tPrep + 2, pEnd) into tMenu
   end if
   if tWith is not empty then put _MenuMessages(pTokens, pIdx, tWith + 2, tLast) into tMessages
   _Fire "T22 HyperCard menus"
   return "hcPutIntoMenu" && _Span(pTokens, pIdx, pAt + 1, tPrep - 1) & comma && quote & _T(pTokens, pIdx[tPrep]) & quote & comma && tMenu & comma && tMessages & comma && tItem
end _PutIntoMenu

-- The menu messages after "with menuMsgs": one for each item put into the
-- menu, separated by commas. HyperCard took each as an expression where
-- it was one ("doHelp", tMessages, item i of tList, "go cd " & it), and
-- otherwise as the text written, a statement it sent when the item was
-- chosen ("with menuMsg go to card id 90024", "with menumsg doMenu "New
-- Card"", which here do not compile): then the whole list is put in
-- quotes, one string with its commas, which the library's hcPutIntoMenu
-- takes apart. A list of expressions ("AC_Front,AC_Closer", ""AC_Undo",
-- "",...") becomes one, its expressions joined by commas: as it was, the
-- second message was taken for the menu item to put into, and those after
-- it were lost
private function _MenuMessages pTokens, pIdx, pFrom, pTo
   local j, tDepth, tStart, tCount, tParts, tSpan, tOut
   put 0 into tDepth
   put pFrom into tStart
   put 0 into tCount
   repeat with j = pFrom to pTo + 1
      if j <= pTo then
         if _T(pTokens, pIdx[j]) is "(" then add 1 to tDepth
         if _T(pTokens, pIdx[j]) is ")" then subtract 1 from tDepth
         if tDepth is not 0 or _T(pTokens, pIdx[j]) is not comma then next repeat
      end if
      add 1 to tCount
      if tStart > j - 1 then
         put "empty" into tParts[tCount]
      else
         put _Span(pTokens, pIdx, tStart, j - 1) into tSpan
         if _MenuMessageIsStatement(pTokens, pIdx, tStart, j - 1, tSpan) then
            _Fire "T41 menu messages"
            return _Literal(_Span(pTokens, pIdx, pFrom, pTo))
         end if
         if tStart < j - 1 then put "(" & tSpan & ")" into tSpan
         put tSpan into tParts[tCount]
      end if
      put j + 1 into tStart
   end repeat
   if tCount = 1 then return _Span(pTokens, pIdx, pFrom, pTo)
   _Fire "T41 menu messages"
   repeat with j = 1 to tCount
      if j > 1 then put " & comma & " after tOut
      put tParts[j] after tOut
   end repeat
   return tOut
end _MenuMessages

-- _MenuMessages on the text after "with menuMsgs" (rule T12, which takes
-- a line at a time), the comment after it kept
private function _MenuMessagesText pText
   local tTokens, tCode, tIdx, n, tItem, tNew, tComment
   put _Tokens(pText) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   if n = 0 then return pText
   put _MenuMessages(tTokens, tIdx, 1, n) into tNew
   if tNew is _Span(tTokens, tIdx, 1, n) then return pText
   if tTokens[tTokens["count"]]["k"] is "c" then put space & tTokens[tTokens["count"]]["t"] into tComment
   return tNew & tComment
end _MenuMessagesText

-- Whether the menu message pSpan, the code tokens pFrom to pTo, is a
-- statement rather than an expression: it starts with a name (not a
-- function's, before "(") and does not compile as get's value (in
-- parentheses, as get leaves what follows its expression); or, with no
-- probe (a script rewritten outside revHyperCardFixScripts), it starts
-- with one of HyperTalk's commands followed by more
private function _MenuMessageIsStatement pTokens, pIdx, pFrom, pTo, pSpan
   if pTokens[pIdx[pFrom]]["k"] is not "w" or (pFrom < pTo and _T(pTokens, pIdx[pFrom + 1]) is "(") then return false
   if sProbe is not empty then return not _Compiles("on hcProbe" & return & "get (" & pSpan & ")" & return & "end hcProbe")
   return pFrom < pTo and _T(pTokens, pIdx[pFrom]) is among the words of kHyperTalkCommands
end _MenuMessageIsStatement

-- enable and disable menu M, menuItem I of menu M; create menu M; delete
-- menu M, menuItem I of menu M
private function _MenuCommand pTokens, pIdx, pAt, pEnd
   local tVerb, tMenu, tItem, tOrdinal
   put _T(pTokens, pIdx[pAt]) into tVerb
   if pAt + 2 > pEnd then return empty
   put pAt + 1 into tOrdinal
   if _T(pTokens, pIdx[tOrdinal]) is "the" then add 1 to tOrdinal
   if _T(pTokens, pIdx[pAt + 1]) is "menu" then
      put _MenuName(pTokens, pIdx, pAt + 2, pEnd) into tMenu
      put "empty" into tItem
   else if _T(pTokens, pIdx[pAt + 1]) is "menuitem" and tVerb is not "create" then
      put _FindWord(pTokens, pIdx, pAt + 2, pEnd, "of in", "menu") into tMenu
      if tMenu is empty and tVerb is "delete" then put _FindWord(pTokens, pIdx, pAt + 2, pEnd, "from", "menu") into tMenu
      if tMenu is empty or tMenu = pAt + 2 or tMenu + 2 > pEnd then return empty
      put _MenuName(pTokens, pIdx, pAt + 2, tMenu - 1) into tItem
      put _MenuName(pTokens, pIdx, tMenu + 2, pEnd) into tMenu
   else if _T(pTokens, pIdx[tOrdinal]) is among the words of kMenuOrdinals and _T(pTokens, pIdx[tOrdinal + 1]) is "menuitem" \
         and tVerb is not "create" then
      -- disable [the] last menuItem of menu M
      put _FindWord(pTokens, pIdx, tOrdinal + 2, pEnd, "of in from", "menu") into tMenu
      if tMenu is not tOrdinal + 2 or tMenu + 2 > pEnd then return empty
      put quote & _T(pTokens, pIdx[tOrdinal]) & quote into tItem
      put _MenuName(pTokens, pIdx, tMenu + 2, pEnd) into tMenu
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

-- T51: set the textFont to a font named in several words not in quotes
-- ("set the textFont to New York", "set textfont of me to new century
-- schlbk", "chicago gray"), which HyperCard took as the text it was. This
-- engine sets the font to the first word and runs the rest as a command,
-- which stops with "can't find handler": the name in quotes. The value
-- follows the last "to", as a chunk's range has one ("of char 1 to 3 of
-- fld 1"). A name of one word, and a value that is an object or an
-- expression ("to bg field FontName", "to line Keuze of fonts", "to it"),
-- are left as they are
private function _SetTextFont pTokens, pIdx, pAt, pEnd
   local j, tProperty, tTo, tFont
   put pAt + 1 into tProperty
   if _T(pTokens, pIdx[tProperty]) is "the" then add 1 to tProperty
   if _T(pTokens, pIdx[tProperty]) is not "textfont" or _T(pTokens, pIdx[tProperty + 1]) is not among the words of "of to" then return empty
   put 0 into tTo
   repeat with j = tProperty + 1 to pEnd
      if _T(pTokens, pIdx[j]) is "to" then put j into tTo
   end repeat
   if tTo = 0 then return empty
   put _FontLiteral(pTokens, pIdx, tTo + 1, pEnd) into tFont
   if tFont is empty then return empty
   return _Span(pTokens, pIdx, pAt, tTo) && tFont
end _SetTextFont

-- T51: the code tokens pFrom to pEnd, a font named in several plain words
-- not in quotes ("New York", "new century schlbk"), as the text they are,
-- in quotes; else empty
private function _FontLiteral pTokens, pIdx, pFrom, pEnd
   local j, tWords
   if not _PlainWords(pTokens, pIdx, pFrom, pEnd) then return empty
   put 0 into tWords
   repeat with j = pFrom to pEnd
      if _T(pTokens, pIdx[j]) is among the words of kObjectWords \
            or _T(pTokens, pIdx[j]) is among the words of "me it target empty msg message selection" then
         return empty
      end if
      if pTokens[pIdx[j]]["k"] is "w" then add 1 to tWords
   end repeat
   if tWords < 2 then return empty
   _Fire "T51 a font name of several words not in quotes"
   return _Literal(_Span(pTokens, pIdx, pFrom, pEnd))
end _FontLiteral

-- T53: the textFont, the textSize, the textHeight, the textStyle or the
-- textAlign set with no object ("set textstyle to plain", "set the
-- textAlign to "right"", "set the textStyle to bold,italic", "set
-- textSize to 9"), HyperCard's for the text its text tool painted, which
-- a script read back (_PaintTextReads). Setting the textStyle or the
-- textAlign stops the script here ("can't find object", "no object to
-- set property"), where the other three set so do nothing: the library's
-- hcSetPaintText, which keeps the value as it was (a list of styles is
-- its parameters), for hcPaintText to give back. A font named in several
-- words not in quotes is the text it was (T51: "set the textFont to New
-- York")
private function _SetPaintText pTokens, pIdx, pAt, pEnd
   local tProperty, tValue
   put pAt + 1 into tProperty
   if _T(pTokens, pIdx[tProperty]) is "the" then add 1 to tProperty
   if _T(pTokens, pIdx[tProperty]) is not among the words of kPaintText \
         or _T(pTokens, pIdx[tProperty + 1]) is not "to" or tProperty + 1 >= pEnd then
      return empty
   end if
   put _Span(pTokens, pIdx, tProperty + 2, pEnd) into tValue
   if _T(pTokens, pIdx[tProperty]) is "textfont" then
      get _FontLiteral(pTokens, pIdx, tProperty + 2, pEnd)
      if it is not empty then put it into tValue
   end if
   _Fire "T53 the paint text's properties"
   return "hcSetPaintText" && quote & _PaintTextName(_T(pTokens, pIdx[tProperty])) & quote & comma && tValue
end _SetPaintText

-- The paint text's property pWord, a word of kPaintText in any case, by
-- the name the library takes ("textheight": "textHeight")
private function _PaintTextName pWord
   local tName
   repeat for each word tName in kPaintText
      if tName is pWord then return tName
   end repeat
   return pWord
end _PaintTextName

-- T64: HyperCard's global properties that this engine has not, set ("set
-- the dialingTime to 600", "set language to oldlanguage"), which it
-- refuses ("set: no property specified"): the library's hcSetProperty,
-- which keeps the value for hcProperty() to give back (a read is
-- _PhraseRules')
private function _SetHyperCardProperty pTokens, pIdx, pAt, pEnd
   local tProperty
   put pAt + 1 into tProperty
   if _T(pTokens, pIdx[tProperty]) is "the" then add 1 to tProperty
   -- T68: the dragSpeed set to a number above this engine's highest,
   -- 65535, which it refuses ("set the dragSpeed to 999999 -- fast enough
   -- for ya?", Logo's openStack, which stopped there), where HyperCard
   -- dragged as fast as it could: this engine's highest, as fast
   if _T(pTokens, pIdx[tProperty]) is "dragspeed" and _T(pTokens, pIdx[tProperty + 1]) is "to" \
         and tProperty + 2 = pEnd and pTokens[pIdx[pEnd]]["k"] is "n" and _T(pTokens, pIdx[pEnd]) > 65535 then
      _Fire "T68 a dragSpeed above this engine's highest"
      return _Span(pTokens, pIdx, pAt, tProperty + 1) && "65535"
   end if
   if _T(pTokens, pIdx[tProperty]) is not among the words of kHyperCardProperties \
         or _T(pTokens, pIdx[tProperty + 1]) is not "to" or tProperty + 1 >= pEnd then
      return empty
   end if
   _Fire "T64 HyperCard's global properties"
   return "hcSetProperty" && quote & _HyperCardPropertyName(_T(pTokens, pIdx[tProperty])) & quote & comma && _Span(pTokens, pIdx, tProperty + 2, pEnd)
end _SetHyperCardProperty

-- HyperCard's global property pWord, a word of kHyperCardProperties in
-- any case, by the name the library takes ("dialingtime": "dialingTime")
private function _HyperCardPropertyName pWord
   local tName
   repeat for each word tName in kHyperCardProperties
      if tName is pWord then return tName
   end repeat
   return pWord
end _HyperCardPropertyName

-- T53: the paint text's textFont, textSize, textHeight, textStyle or
-- textAlign read with no object ("put the textHeight div 2 into h", "if
-- the textStyle is "Plain" then", "put the textFont into oldFont"),
-- HyperCard's for the text its text tool painted, as a script set it or
-- as HyperCard had it ("reset paint": Geneva, 12, a textHeight of 16,
-- plain and left): the library's hcPaintText. This engine reads them as
-- empty, and does not compile one before div ("the textHeight div 2",
-- Graph Maker's) or the textStyle before any operator ("the textStyle is
-- "Plain"", Stack Starter's). One of an object or a chunk ("the textSize
-- of fld 1", "the textFont of msg", T28's) and the one a set sets ("set
-- the textSize to 12", _SetPaintText's) are not taken
private function _PaintTextReads pLine
   local tTokens, tCode, tIdx, n, tItem, i, tChanged
   if "text" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = n down to 2
      if _T(tTokens, tIdx[i]) is not among the words of kPaintText or _T(tTokens, tIdx[i - 1]) is not "the" then next repeat
      if _T(tTokens, tIdx[i + 1]) is among the words of "of in" or _T(tTokens, tIdx[i - 2]) is "set" then next repeat
      _Replace tTokens, tIdx, i - 1, i, "hcPaintText(" & quote & _PaintTextName(_T(tTokens, tIdx[i])) & quote & ")"
      _Fire "T53 the paint text's properties"
      put true into tChanged
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _PaintTextReads

-- T72: the printTextFont, the printTextSize, the printTextHeight, the
-- printTextStyle or the printTextAlign set ("set the printTextFont to
-- "Courier"", "set printtextfont to palatino", "set PrintTextSize to
-- 24", "set the printTextStyle to "plain""), HyperCard's for the text
-- print of an expression printed (T71), which this engine sets to
-- nothing: the library's hcSetPrintText, which keeps the value as it was
-- (a list of styles is its parameters), for hcPrint to print in and
-- hcPrintText to give back. A font named in several words not in quotes
-- is the text it was (T51: "set the printTextFont to New York")
private function _SetPrintText pTokens, pIdx, pAt, pEnd
   local tProperty, tValue
   put pAt + 1 into tProperty
   if _T(pTokens, pIdx[tProperty]) is "the" then add 1 to tProperty
   if _T(pTokens, pIdx[tProperty]) is not among the words of kPrintText \
         or _T(pTokens, pIdx[tProperty + 1]) is not "to" or tProperty + 1 >= pEnd then
      return empty
   end if
   put _Span(pTokens, pIdx, tProperty + 2, pEnd) into tValue
   if _T(pTokens, pIdx[tProperty]) is "printtextfont" then
      get _FontLiteral(pTokens, pIdx, tProperty + 2, pEnd)
      if it is not empty then put it into tValue
   end if
   _Fire "T72 the print text's properties"
   return "hcSetPrintText" && quote & _PrintTextName(_T(pTokens, pIdx[tProperty])) & quote & comma && tValue
end _SetPrintText

-- The print text's property pWord, a word of kPrintText in any case, by
-- the name the library takes ("printtextsize": "printTextSize")
private function _PrintTextName pWord
   local tName
   repeat for each word tName in kPrintText
      if tName is pWord then return tName
   end repeat
   return pWord
end _PrintTextName

-- T72: the print text's printTextFont, printTextSize, printTextHeight,
-- printTextStyle or printTextAlign read ("put the printTextFont into
-- savedPrintFont", Internet Gopher's, which sets it back after printing
-- in Courier), as a script set it or as HyperCard had it (Geneva, 10, a
-- printTextHeight of 13, plain and left): the library's hcPrintText.
-- This engine reads them as empty. The one a set sets ("set the
-- printTextSize to 12", _SetPrintText's) is not taken
private function _PrintTextReads pLine
   local tTokens, tCode, tIdx, n, tItem, i, tChanged
   if "printtext" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = n down to 2
      if _T(tTokens, tIdx[i]) is not among the words of kPrintText or _T(tTokens, tIdx[i - 1]) is not "the" then next repeat
      if _T(tTokens, tIdx[i - 2]) is "set" then next repeat
      _Replace tTokens, tIdx, i - 1, i, "hcPrintText(" & quote & _PrintTextName(_T(tTokens, tIdx[i])) & quote & ")"
      _Fire "T72 the print text's properties"
      put true into tChanged
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _PrintTextReads

-- T56: a chunk of a chunk no larger than itself ("item 2 of word 1 of
-- line j of fld seqNames", Aligner's; "char 3 of line n of line n of
-- tRow", Import SYLK's; "line a of item n of linkLists", Telling
-- Tools'), which HyperCard took in any order, chunk by chunk from the
-- container in, and this engine refuses ("bad chunk order": the import
-- left the line or its handler out). As a value, the part from the first
-- chunk out of order on goes in parentheses, which this engine reads as
-- HyperCard did, and the part within them is taken again. The
-- destination of a put is _PutChunkOrder's; a chunk out of order of a
-- property ("the textStyle of item 2 of word 1 of fld 1"), and one to
-- delete or select, are left as they are. (A chunk numbered by a field,
-- "item field CurrentChoice of line 4 of field VolTable", is T34's.)
private function _ChunkOrder pLine
   local tNew, i
   repeat with i = 1 to 20
      put _ChunkOrderOnce(pLine) into tNew
      if tNew is pLine then exit repeat
      put tNew into pLine
   end repeat
   return pLine
end _ChunkOrder

-- T56: the line with its first chunk out of order put right
-- (_ChunkOrder); else as it is
private function _ChunkOrderOnce pLine
   local tTokens, tCode, tIdx, n, tItem, i, j, p, tPhrases, tStart, tPrev, tVerb
   if " of " is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = 1 to n - 2
      -- where a chunk expression starts, not within one
      if _T(tTokens, tIdx[i]) is among the words of kChunkOrdinals then
         put i into tStart
         if i > 1 and _T(tTokens, tIdx[i - 1]) is "the" then
            put i - 1 into tStart
         end if
      else if _T(tTokens, tIdx[i]) is among the words of kChunkWords \
            and (i = 1 or _T(tTokens, tIdx[i - 1]) is not among the words of kChunkOrdinals) then
         put i into tStart
      else
         next repeat
      end if
      if tStart = 1 or _T(tTokens, tIdx[tStart - 1]) is "of" then next repeat
      put _ChunkPhrases(tTokens, tIdx, tStart, n) into tPhrases
      put _ChunkBreak(tPhrases, 1) into p
      if p = 0 then next repeat
      -- as a value only: not the destination of a put, an add or a
      -- subtract, nor an object's name, nor what a delete, a select or a
      -- sort takes (j: the statement's first token)
      put _T(tTokens, tIdx[tStart - 1]) into tPrev
      put tStart - 1 into j
      repeat while j > 1 and _T(tTokens, tIdx[j - 1]) is not among the words of "then else"
         subtract 1 from j
      end repeat
      put _T(tTokens, tIdx[j]) into tVerb
      if tPrev is among the words of "then else into before after" or tPrev is among the words of kObjectWords \
            or (tPrev is among the words of "to from" and tVerb is among the words of "add subtract") \
            or (j = tStart - 1 and tVerb is among the words of "delete select multiply divide sort find mark") then
         next repeat
      end if
      put "(" before tTokens[tIdx[tPhrases[p]["at"]]]["t"]
      put ")" after tTokens[tIdx[tPhrases["end"]]]["t"]
      _Fire "T56 a chunk of a smaller chunk"
      return _Join(tTokens)
   end repeat
   return pLine
end _ChunkOrderOnce

-- T56: the chunk expression from the code token pAt to pEnd at most
-- ("item 2 of word 1 of x", "the second word of line 1 of fld 2"): its
-- phrases (["count"]; for each, its first token ["at"] and the size of
-- its chunk ["rank"], 1 a char to 4 a line), and the last token of its
-- container (["end"]); a count of 0 if no chunk of a container starts
-- there
private function _ChunkPhrases pTokens, pIdx, pAt, pEnd
   local tPhrases, tCount, j, k, tOf, tWord, tDepth, tLast
   put 0 into tCount
   put pAt into j
   repeat while j < pEnd
      put empty into tWord
      put empty into tOf
      if _T(pTokens, pIdx[j]) is "the" and _T(pTokens, pIdx[j + 1]) is among the words of kChunkOrdinals \
            and _T(pTokens, pIdx[j + 2]) is among the words of kChunkWords then
         put _T(pTokens, pIdx[j + 2]) into tWord
         put j + 3 into tOf
      else if _T(pTokens, pIdx[j]) is among the words of kChunkOrdinals and _T(pTokens, pIdx[j + 1]) is among the words of kChunkWords then
         put _T(pTokens, pIdx[j + 1]) into tWord
         put j + 2 into tOf
      else if _T(pTokens, pIdx[j]) is among the words of kChunkWords then
         -- its number or its range ("char x to x + 50"), to the "of"
         -- after it
         put _T(pTokens, pIdx[j]) into tWord
         put 0 into tDepth
         repeat with k = j + 1 to pEnd
            if _T(pTokens, pIdx[k]) is "(" then add 1 to tDepth
            if _T(pTokens, pIdx[k]) is ")" then subtract 1 from tDepth
            if tDepth < 0 then exit repeat
            if tDepth = 0 and k > j + 1 and _T(pTokens, pIdx[k]) is "of" then
               put k into tOf
               exit repeat
            end if
            if tDepth = 0 and _T(pTokens, pIdx[k]) is among the words of "then else into before after with for until by , of" then
               exit repeat
            end if
         end repeat
      end if
      if tWord is empty or tOf is empty or tOf >= pEnd or _T(pTokens, pIdx[tOf]) is not "of" then exit repeat
      add 1 to tCount
      put j into tPhrases[tCount]["at"]
      if tWord is "character" then put "char" into tWord
      put itemOffset(tWord, "char,word,item,line") into tPhrases[tCount]["rank"]
      put tOf + 1 into j
   end repeat
   put 0 into tPhrases["count"]
   if tCount = 0 then return tPhrases
   -- the container: to the first word or sign outside parentheses that
   -- ends a value
   put 0 into tDepth
   put pEnd into tLast
   repeat with k = j to pEnd
      if _T(pTokens, pIdx[k]) is "(" then
         add 1 to tDepth
      else if _T(pTokens, pIdx[k]) is ")" then
         if tDepth = 0 then
            put k - 1 into tLast
            exit repeat
         end if
         subtract 1 from tDepth
      else if tDepth = 0 and (pTokens[pIdx[k]]["k"] is "p" \
            or _T(pTokens, pIdx[k]) is among the words of "then else into before after to from with without for until by at and or is contains div mod in within among not") then
         put k - 1 into tLast
         exit repeat
      end if
   end repeat
   if tLast < j or tDepth > 0 then return tPhrases
   put tCount into tPhrases["count"]
   put tLast into tPhrases["end"]
   return tPhrases
end _ChunkPhrases

-- T56: the first of the phrases pFrom on (_ChunkPhrases) whose chunk is no
-- larger than the one before it, or 0
private function _ChunkBreak pPhrases, pFrom
   local p
   repeat with p = max(pFrom, 2) to pPhrases["count"]
      if pPhrases[p]["rank"] <= pPhrases[p - 1]["rank"] then return p
   end repeat
   return 0
end _ChunkBreak

-- T56: put V into (before, after) a chunk of a chunk no larger than
-- itself ("put x into item 1 of word 1 of line 2 of field "Card Id"",
-- GenChart's; "put "another" into second word of line 1 of item 1 of card
-- field "narration"", DragTracer's), which HyperCard put into the chunk
-- within the chunk: the three statements that do that here, the larger
-- chunk into a variable (hcChunk), V into its chunk, and the variable
-- back; after a then or an else, a do of the three (as T54's). A
-- destination with two chunks out of order is left as it is
private function _PutChunkOrder pTokens, pIdx, pAt, pEnd, pCount
   local tPrep, tPhrases, p, tChunk, tLarger, tPut
   put _FindWord(pTokens, pIdx, pAt + 2, pEnd, "into before after", empty) into tPrep
   if tPrep is empty or tPrep >= pEnd then return empty
   put _ChunkPhrases(pTokens, pIdx, tPrep + 1, pEnd) into tPhrases
   if tPhrases["end"] <> pEnd then return empty
   put _ChunkBreak(tPhrases, 1) into p
   if p = 0 or _ChunkBreak(tPhrases, p + 1) <> 0 then return empty
   put _Span(pTokens, pIdx, tPhrases[1]["at"], tPhrases[p]["at"] - 1) into tChunk
   put _Span(pTokens, pIdx, tPhrases[p]["at"], pEnd) into tLarger
   _Fire "T56 a chunk of a smaller chunk"
   put "put" && tLarger && "into hcChunk;" && "put" && _Span(pTokens, pIdx, pAt + 1, tPrep - 1) && pTokens[pIdx[tPrep]]["t"] \
         && tChunk && "hcChunk;" && "put hcChunk into" && tLarger into tPut
   if pAt = 1 and pEnd = pCount then return tPut
   return "do" && _Literal(tPut)
end _PutChunkOrder

-- T57: a put into a variable named in quotes ("Put 29.95 into "Price"",
-- Type & Graphics Preview's; "put the value of card field F3 into
-- "bagone"", MENDELIAN GENETICS I's; "put empty into "fire"",
-- MathAttack's; "put "N" into "KFL"", TwinPeaksTrivia's), which HyperCard
-- put into the variable of that name, as these stacks read it after
-- ("global Product,Price", "put bagone into card field "CLASS1"") and
-- this engine refuses ("bad destination": the import left the line or
-- its handler out): the name without its quotes, a name this engine
-- takes for a variable; a name it refuses, or one that is the message
-- box here, is left as it is
private function _PutIntoQuoted pTokens, pIdx, pAt, pEnd
   local tPrep, tName
   put _FindWord(pTokens, pIdx, pAt + 2, pEnd, "into before after", empty) into tPrep
   if tPrep is empty or tPrep <> pEnd - 1 or pTokens[pIdx[pEnd]]["k"] is not "s" then return empty
   put pTokens[pIdx[pEnd]]["t"] into tName
   if the number of chars of tName < 3 or char -1 of tName is not quote then return empty
   put char 2 to -2 of tName into tName
   if not _IsName(tName) or _Lower(tName) is among the words of kStructural \
         or _Lower(tName) is among the words of "msg message" or _VariableRefused(tName) then
      return empty
   end if
   _Fire "T57 a variable named in quotes"
   return _Span(pTokens, pIdx, pAt, tPrep) && tName
end _PutIntoQuoted

-- T58: find in the marked cards ("find string searchStr of marked cards",
-- HyperStacks'; "find string (cd fld "Key Word" of card index) of marked
-- cards", Recipe's; "find whole firstTerm in field "Record" of marked
-- cards", Hyper-Ref's), which HyperCard searched alone and this engine
-- refuses (the import left the line out, or made it the throw of a line
-- that does not compile, which stopped the handler): the library's
-- hcFindMarkedBegin sets the dontSearch of the cards that are not
-- marked, which this engine's find passes over, the find searches the
-- others by the script's own form and text, and hcFindMarkedEnd sets
-- them back and gives back the find's result ("not found"), which the
-- script reads after. This engine's find in a field searches it whatever
-- a card's dontSearch, so the field goes to hcFindMarkedBegin instead,
-- which leaves it alone to be searched on the marked cards ("find string
-- findString in bkgnd field "alpha pool" of marked cards", GuessWords':
-- "hcFindMarkedBegin the long id of bkgnd field "alpha pool"; find
-- string findString; hcFindMarkedEnd the result"). That is three
-- statements; after "then" or "else", a do of them (as T54's)
private function _FindMarked pTokens, pIdx, pAt, pEnd, pCount
   local tIn, tFind
   if pEnd - pAt < 4 or _T(pTokens, pIdx[pEnd]) is not among the words of "cards cds" \
         or _T(pTokens, pIdx[pEnd - 1]) is not "marked" or _T(pTokens, pIdx[pEnd - 2]) is not "of" then
      return empty
   end if
   put _FindWord(pTokens, pIdx, pAt + 2, pEnd - 3, "in", empty) into tIn
   if tIn is not empty and (tIn = pEnd - 3 or _T(pTokens, pIdx[tIn + 1]) is not among the words of kObjectWords) then return empty
   _Fire "T58 find in the marked cards"
   if tIn is empty then
      put "hcFindMarkedBegin;" && _Span(pTokens, pIdx, pAt, pEnd - 3) into tFind
   else
      put "hcFindMarkedBegin the long id of" && _Span(pTokens, pIdx, tIn + 1, pEnd - 3) & ";" && _Span(pTokens, pIdx, pAt, tIn - 1) into tFind
   end if
   put ";" && "hcFindMarkedEnd the result" after tFind
   if pAt = 1 and pEnd = pCount then return tFind
   return "do" && _Literal(tFind)
end _FindMarked

-- T54: sort the cards of a background ("sort cards of this bg by field
-- "Name"", "sort bkgnd "Data" numeric by line 1 of field f", "sort this
-- background by ...", "sort marked cards of bkgnd 2 by ..."), which
-- HyperCard took and this engine refuses ("sort: error sorting"); and
-- sort this stack ("sort this stack by ...", "sort stack descending by
-- ..."), which here is "sort cards". A background's cards are sorted
-- among the places they had, as in HyperCard, by the script's own
-- expression, its variables and all: the library's hcSortBegin marks
-- them (with "marked", the ones of them that are marked), this
-- engine's "sort marked cards" sorts them, and hcSortEnd puts them back
-- in their places, in their new order, and the marks back as they were.
-- That is three statements, which a sort of a background alone on its
-- line becomes; after "then" or "else", a do of them
private function _SortCards pTokens, pIdx, pAt, pEnd, pCount
   local j, k, tMarked, tRefEnd, tBy, tSort
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "this" and _T(pTokens, pIdx[j + 1]) is "stack" then add 1 to j
   if _T(pTokens, pIdx[j]) is "stack" then
      if j = pEnd or _T(pTokens, pIdx[j + 1]) is not among the words of "ascending descending text numeric international datetime by" then
         return empty
      end if
      _Fire "T54 sort a background's cards, and this stack"
      return "sort cards" && _Span(pTokens, pIdx, j + 1, pEnd)
   end if
   put pAt + 1 into j
   put false into tMarked
   if _T(pTokens, pIdx[j]) is "marked" then
      put true into tMarked
      add 1 to j
   end if
   if _T(pTokens, pIdx[j]) is among the words of "cards cds" then
      if _T(pTokens, pIdx[j + 1]) is not "of" then return empty
      add 2 to j
   else if tMarked then
      return empty
   end if
   if j > pEnd then return empty
   put _CardRefEnd(pTokens, pIdx, j, pEnd) into tRefEnd
   if tRefEnd = 0 or _PictureKind(pTokens, pIdx, j) is not "background" then return empty
   -- the order and the kind of sort, then "by"
   put 0 into tBy
   repeat with k = tRefEnd + 1 to pEnd
      if _T(pTokens, pIdx[k]) is "by" then
         put k into tBy
         exit repeat
      end if
      if _T(pTokens, pIdx[k]) is not among the words of "ascending descending text numeric international datetime" then return empty
   end repeat
   if tBy = 0 or tBy = pEnd then return empty
   _Fire "T54 sort a background's cards, and this stack"
   put "hcSortBegin the long id of" && _Span(pTokens, pIdx, j, tRefEnd) & comma && tMarked & ";" \
         && "sort marked cards" && _Span(pTokens, pIdx, tRefEnd + 1, pEnd) & ";" && "hcSortEnd" into tSort
   if pAt = 1 and pEnd = pCount then return tSort
   -- after a then or an else, or before an else, where one statement
   -- goes: a do of the three, which runs them in the handler, its
   -- variables and all (as T42's do)
   return "do" && _Literal(tSort)
end _SortCards

-- T19: show and hide card picture, background picture (which this engine
-- reads as a card named "picture"); T21: show, hide and close window,
-- and HyperCard's own windows (the scroll window, the tool window...),
-- which are not stacks here; T46: show and hide card window, which this
-- engine does nothing for ("show card window at 0,0" stops with an
-- error), and the message box and HyperCard's own windows shown at a
-- place, which this engine shows where they were (the library puts a
-- window shown at a place where HyperCard did)
private function _ShowHide pTokens, pIdx, pAt, pEnd
   local j, tVerb, tWhich, tShow, tLast, tRef
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
   -- T52: the picture of a card or a background it names ("hide picture
   -- of card "FX"", "show pict of this cd", "hide picture of prev card")
   if tVerb is not "close" and _T(pTokens, pIdx[j]) is among the words of "picture pict" and _T(pTokens, pIdx[j + 1]) is "of" \
         and _CardRefEnd(pTokens, pIdx, j + 2, pEnd) = pEnd then
      _Fire "T52 the picture of a card or a background"
      return "hcShowPicture" && quote & _PictureKind(pTokens, pIdx, j + 2) & quote & comma && (tVerb is "show") & comma \
            && "the long id of" && _Span(pTokens, pIdx, j + 2, pEnd)
   end if
   if tVerb is not "close" and _T(pTokens, pIdx[j]) is among the words of "card cd" and _T(pTokens, pIdx[j + 1]) is "window" then
      if j + 1 = pEnd then
         _Fire "T46 HyperCard's windows"
         return "hcWindow" && quote & tVerb & quote & comma && quote & "card window" & quote
      end if
      if tVerb is not "show" or _T(pTokens, pIdx[j + 2]) is not "at" or j + 2 = pEnd then return empty
      _Fire "T46 HyperCard's windows"
      return "hcWindow" && quote & "show" & quote & comma && quote & "card window" & quote & comma && _Span(pTokens, pIdx, j + 3, pEnd)
   end if
   -- (T46: the variable and message watchers, which are not here either)
   if _T(pTokens, pIdx[j]) is among the words of "variable message" and _T(pTokens, pIdx[j + 1]) is "watcher" then
      if j + 1 = pEnd then
         _Fire "T46 HyperCard's windows"
         return "hcWindow" && quote & tVerb & quote & comma && quote & _T(pTokens, pIdx[j]) && "watcher" & quote
      end if
      if tVerb is "show" and _T(pTokens, pIdx[j + 2]) is "at" and j + 2 < pEnd then
         _Fire "T46 HyperCard's windows"
         return "hcWindow" && quote & "show" & quote & comma && quote & _T(pTokens, pIdx[j]) && "watcher" & quote & comma && _Span(pTokens, pIdx, j + 3, pEnd)
      end if
      return empty
   end if
   put pAt + 1 into j
   if tVerb is "show" and _T(pTokens, pIdx[j]) is not "window" then
      put _MessageBoxRef(pTokens, pIdx, j) into tRef
      if tRef > 0 and _T(pTokens, pIdx[j + tRef]) is "at" and j + tRef < pEnd then
         _Fire "T46 HyperCard's windows"
         return "hcWindow" && quote & "show" & quote & comma && quote & "message" & quote & comma && _Span(pTokens, pIdx, j + tRef + 1, pEnd)
      end if
   end if
   if _T(pTokens, pIdx[j]) is "window" and j < pEnd then
      put _ExpressionEnd(pTokens, pIdx, j + 1, pEnd, "at") into tLast
      _Fire "T21 windows"
      if tLast = pEnd then return "hcWindow" && quote & tVerb & quote & comma && _PlainName(pTokens, pIdx, j + 1, pEnd, false)
      if tLast + 1 = pEnd then return empty
      return "hcWindow" && quote & tVerb & quote & comma && _PlainName(pTokens, pIdx, j + 1, tLast, false) & comma && _Span(pTokens, pIdx, tLast + 2, pEnd)
   end if
   if _T(pTokens, pIdx[j]) is among the words of "tool tools pattern patterns scroll fatbits navigator" \
         and _T(pTokens, pIdx[j + 1]) is "window" then
      if j + 1 = pEnd then
         _Fire "T21 windows"
         return "hcWindow" && quote & tVerb & quote & comma && quote & _T(pTokens, pIdx[j]) & quote
      end if
      if tVerb is "show" and _T(pTokens, pIdx[j + 2]) is "at" and j + 2 < pEnd then
         _Fire "T46 HyperCard's windows"
         return "hcWindow" && quote & "show" & quote & comma && quote & _T(pTokens, pIdx[j]) & quote & comma && _Span(pTokens, pIdx, j + 3, pEnd)
      end if
   end if
   return empty
end _ShowHide

-- T52: the showPict of a card or a background read ("if the showPict of
-- this cd then", "put the showPict of this bg into PictShown", "not
-- (showpict of this cd)"), which this engine reads as true whatever the
-- card shows: hcShowPict("card", the long id of this cd), whether the
-- picture T19 shows and hides is shown. Set, it is _SetShowPict's
private function _PictureProperties pLine
   local tTokens, tCode, tIdx, n, tItem, i, tStart, tEnd, tChanged
   if "showpict" is not in pLine then return pLine
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      put tItem into tIdx[n]
   end repeat
   repeat with i = n - 2 down to 1
      if _T(tTokens, tIdx[i]) is not "showpict" or _T(tTokens, tIdx[i + 1]) is not "of" then next repeat
      put i into tStart
      if _T(tTokens, tIdx[i - 1]) is "the" then subtract 1 from tStart
      if _T(tTokens, tIdx[tStart - 1]) is "set" then next repeat
      put _CardRefEnd(tTokens, tIdx, i + 2, n) into tEnd
      if tEnd = 0 then next repeat
      _Replace tTokens, tIdx, tStart, tEnd, "hcShowPict(" & quote & _PictureKind(tTokens, tIdx, i + 2) & quote & comma \
            && "the long id of" && _Span(tTokens, tIdx, i + 2, tEnd) & ")"
      _Fire "T52 the showPict of a card or a background"
      put true into tChanged
   end repeat
   if not tChanged then return pLine
   return _Join(tTokens)
end _PictureProperties

-- T52: set [the] showPict of a card or a background to V, which this
-- engine ignores: hcShowPicture, as T19 shows and hides the picture
private function _SetShowPict pTokens, pIdx, pAt, pEnd
   local j, tEnd
   put pAt + 1 into j
   if _T(pTokens, pIdx[j]) is "the" then add 1 to j
   if _T(pTokens, pIdx[j]) is not "showpict" or _T(pTokens, pIdx[j + 1]) is not "of" then return empty
   put _CardRefEnd(pTokens, pIdx, j + 2, pEnd) into tEnd
   if tEnd = 0 or _T(pTokens, pIdx[tEnd + 1]) is not "to" or tEnd + 2 > pEnd then return empty
   _Fire "T52 the showPict of a card or a background"
   return "hcShowPicture" && quote & _PictureKind(pTokens, pIdx, j + 2) & quote & comma && _Span(pTokens, pIdx, tEnd + 2, pEnd) & comma \
         && "the long id of" && _Span(pTokens, pIdx, j + 2, tEnd)
end _SetShowPict

-- T52: the last code token of a card or a background named from pFrom
-- ("this cd", "prev card", "card "Keywords"", "cd 1", "card id 2946",
-- "bg heros"), or 0. One of another stack or background ("card 1 of
-- stack x"), or named by an expression ("card (n + 1)"), is not taken
private function _CardRefEnd pTokens, pIdx, pFrom, pTo
   local j, tNamed
   put pFrom into j
   -- (tNamed: a card word with its name or number after it, not after
   -- "this", "next" or an ordinal)
   put not (_T(pTokens, pIdx[j]) is among the words of "this next prev previous" \
         or _T(pTokens, pIdx[j]) is among the words of kChunkOrdinals) into tNamed
   if not tNamed then add 1 to j
   if j > pTo or _T(pTokens, pIdx[j]) is not among the words of "card cd background bkgnd bg" then return 0
   if tNamed then
      add 1 to j
      if _T(pTokens, pIdx[j]) is "id" then add 1 to j
      if j > pTo then return 0
      if pTokens[pIdx[j]]["k"] is not among the words of "s n" then
         if pTokens[pIdx[j]]["k"] is not "w" or _T(pTokens, pIdx[j]) is among the words of kNotPlain \
               or _T(pTokens, pIdx[j]) is among the words of kObjectWords or _T(pTokens, pIdx[j + 1]) is "(" then
            return 0
         end if
      end if
   end if
   if j < pTo and _T(pTokens, pIdx[j + 1]) is "of" then return 0
   return j
end _CardRefEnd

-- T52: "card" or "background", what the reference from pFrom names
private function _PictureKind pTokens, pIdx, pFrom
   if _T(pTokens, pIdx[pFrom]) is not among the words of "card cd background bkgnd bg" then add 1 to pFrom
   if _T(pTokens, pIdx[pFrom]) is among the words of "background bkgnd bg" then return "background"
   return "card"
end _PictureKind

-- T55: the last code token of a stack named from pFrom ("this stack",
-- "stack "Data"", "stack tName", "stack ("x" & y)"), or 0; "stack" with
-- no name after it (this stack, as T11 takes it) ends at pFrom
private function _StackRefEnd pTokens, pIdx, pFrom, pTo
   local j, tDepth
   put pFrom into j
   if _T(pTokens, pIdx[j]) is "this" then
      if _T(pTokens, pIdx[j + 1]) is not "stack" then return 0
      return j + 1
   end if
   if _T(pTokens, pIdx[j]) is not "stack" then return 0
   if j = pTo then return j
   add 1 to j
   if _T(pTokens, pIdx[j]) is "(" then
      put 0 into tDepth
      repeat with j = j to pTo
         if _T(pTokens, pIdx[j]) is "(" then
            add 1 to tDepth
         else if _T(pTokens, pIdx[j]) is ")" then
            subtract 1 from tDepth
            if tDepth = 0 then exit repeat
         end if
      end repeat
      if j > pTo then
         return 0
      end if
   else if pTokens[pIdx[j]]["k"] is not "s" then
      -- a name in a variable; anything else after "stack" (an operator,
      -- "is", "into") leaves it alone, this stack
      if pTokens[pIdx[j]]["k"] is not "w" or _T(pTokens, pIdx[j]) is among the words of kNotPlain \
            or _T(pTokens, pIdx[j]) is among the words of kObjectWords \
            or _T(pTokens, pIdx[j]) is among the words of "into then else to with from" then
         return pFrom
      end if
   end if
   if j < pTo and _T(pTokens, pIdx[j + 1]) is "of" then return 0
   return j
end _StackRefEnd

-- T12 and T8: HyperCard commands this engine does not have, to the
-- library's handlers; and "group" after a comma in a text style, which
-- this engine would read as a group (an object) and not compile
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
   -- (T34: after then or else, "if q then reset menubar else ...")
   if _Match(pLine, "(?i)^(.*\b(?:then|else)\s+)reset\s+menubar\b(.*)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into tRest
      _Fire "T34 more forms HyperCard took"
      return tIndent & "hcResetMenubar" & tRest
   end if
   if _Match(pLine, "(?i)^(\s*)(create|delete)\s+menu\s+(.+)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into a
      put sMatch[3] into tRest
      if _Lower(word 1 of tRest) is not among the words of "item items" then
         _Fire "T12 HyperCard command to the library"
         put _MenuNameText(tRest) into tRest
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
      return tIndent & "hcPutIntoMenu" && a & comma && quote & b & quote & comma && _MenuNameText(c) & comma && _MenuMessagesText(d)
   end if
   if _Match(pLine, "(?i)^(\s*(?:(?:then|else)\s+)?)palette\s+(.+?,.+)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into a
      _Fire "T12 HyperCard command to the library"
      return tIndent & "hcPalette" && a
   end if
   -- (T37: after then or else in the line, "if there is not a window
   -- "Nav" then palette "Nav", "254,0"", to the end of the line)
   if _Match(pLine, "(?i)^(.*\b(?:then|else)\s+)palette\s+((?:(?!\belse\b).)+?,(?:(?!\belse\b).)+)$") then
      put sMatch[1] into tIndent
      put sMatch[2] into a
      _Fire "T37 more forms HyperCard took"
      return tIndent & "hcPalette" && a
   end if
   -- (quoted, it is the style group, which this engine calls link: "set
   -- textStyle of it to bold,group" makes the text bold and grouped, as
   -- in HyperCard, and rule T32 then takes the style through hcTextStyle.
   -- It was left out of the style, so the text was not grouped)
   if _Match(pLine, "(?i)^(\s*set\s+(?:the\s+)?textstyle\b.*\bto\b.*?,\s*)group\b(.*)$") then
      put sMatch[1] into a
      put sMatch[2] into b
      _Fire "T12 HyperCard command to the library"
      return a & quote & "group" & quote & b
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
-- variables' values put in. And the same after "unlock screen with"
-- ("unlock screen with visual zoom theVisEffect", "unlock screen with
-- wipe it"), whose first three words are kept as they are
private function _Visual pLine
   local tTokens, tCode, tItem, tWord, tUnknown, tOut, tIndent, tLiteral, tFrom, n
   put _Tokens(pLine) into tTokens
   put _Code(tTokens) into tCode
   if _T(tTokens, item 1 of tCode) is "visual" then
      put 1 into tFrom
   else if _T(tTokens, item 1 of tCode) is "unlock" and _T(tTokens, item 2 of tCode) is "screen" \
         and _T(tTokens, item 3 of tCode) is "with" and the number of items of tCode > 3 then
      put 4 into tFrom
   else
      return pLine
   end if
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      if n < tFrom then next repeat
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
   put 0 into n
   repeat for each item tItem in tCode
      add 1 to n
      if n < tFrom or _T(tTokens, tItem) is among the words of kVisualWords then
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

-- Keep the handlers of pScript that compile on their own, and of each one
-- that does not, the lines that compile (T39, _LeaveOutLines); put in
-- place of each one that still does not a handler that passes its
-- message, holding the HyperTalk of pOriginal's handler of the same name
-- commented out. A second handler of a name already defined is commented
-- out (HyperCard ran the first). Returns the script; sLeftOut is the
-- number of handlers left out, sLinesLeftOut the number of lines.
private function _Salvage pScript, pOriginal
   local tPieces, tCount, i, tOut, tName, tKind, tSeen, tLeftOut, tOriginalHandlers, tStub, tText
   local tHyperTalk, tKept, tLines, tLinesOut
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
      -- T37: "if ... then ... else" at the end of a line (or "if ...
      -- then ..." and else alone on the next), which in HyperCard began
      -- an else of the lines after it, up to "end if", and here takes
      -- only the next statement: the if as a block (";", _ElseBlocks),
      -- kept if the handler compiles so (an else that took one statement
      -- in HyperCard too has no "end if" after it, and the handler would
      -- not)
      put _ElseBlocks(tPieces[i]["text"]) into tText
      if tText is not tPieces[i]["text"] and _Compiles(tText) then
         _Fire "T37 more forms HyperCard took"
         put tText & return after tOut
         next repeat
      end if
      -- T39: the handler without the lines that do not compile (with
      -- the else blocks above first, then without them)
      put _OriginalHandler(tOriginalHandlers, tName, tPieces[i]["text"]) into tHyperTalk
      put empty into tKept
      if tText is not tPieces[i]["text"] then put _LeaveOutLines(tText, tHyperTalk, tLines) into tKept
      if tKept is empty then put _LeaveOutLines(tPieces[i]["text"], tHyperTalk, tLines) into tKept
      if tKept is not empty then
         _Fire "T39 lines that do not compile here, left out"
         _LogLinesLeftOut tName, tLines
         add the number of elements of tLines to tLinesOut
         put tKept & return after tOut
         next repeat
      end if
      add 1 to tLeftOut
      _LogLeftOut tName, tPieces[i]["text"]
      put _Stub(tKind, tName, tHyperTalk) into tStub
      if not _Compiles(tStub) then
         -- a name no handler can have here ("v" in quotes, time&Date):
         -- nothing can call it, so it is commented out whole
         put _Commented(tHyperTalk, "a handler whose name cannot be a handler's here") into tStub
      end if
      put tStub & return after tOut
   end repeat
   delete the last char of tOut
   put tLeftOut into sLeftOut
   put tLinesOut + 0 into sLinesLeftOut
   return tOut
end _Salvage

-- T39: the handler pText, which does not compile here, with each of its
-- statements that do not compile left out, one at a time, until it does:
-- HyperCard ran a handler until it reached a line it could not do, and
-- many of the lines this engine cannot compile are ones HyperCard did (a
-- property of an external's window, "send ... to stack Home", an
-- external's arguments), so the handler here goes on past the line,
-- which is kept as a comment. (A line HyperCard could not do either,
-- "hide field" and nothing after it, did nothing there but stop the
-- handler with an error.) Two kinds of line are a throw instead, which
-- stops the handler with an error naming the line: one in a repeat that
-- only a condition or an exit ends ("repeat until", "while", "forever"),
-- where going on past it could leave the loop running for ever, and
-- return, exit and pass, which end a handler. Only a statement can be
-- left out: an error on a line of the handler's structure (on, end,
-- repeat; an if's condition) leaves the handler as it was. A statement
-- after the then or the else of an if on its line is left out with the
-- if kept: hcLeftOut, a handler of the HyperCard Library that does
-- nothing, takes its place (or the throw). pHyperTalk: the handler as
-- it was imported, line for line (the rules keep a handler's lines), for
-- the comments. Returns the handler, or empty if it still does not
-- compile so; pLeftOut gets the lines left out, for
-- revHyperCardLeftOutLines
private function _LeaveOutLines pText, pHyperTalk, @pLeftOut
   local tLines, tCount, tHyperTalk, tLine, n, tError, tTries, k, s, e, m, tTokens, tCode, tFirst, tIndent, tStatement, tPart
   put empty into pLeftOut
   put 0 into tCount
   repeat for each line tLine in pText
      add 1 to tCount
      put tLine into tLines[tCount]
   end repeat
   put 0 into m
   repeat for each line tLine in pHyperTalk
      add 1 to m
      put tLine into tHyperTalk[m]
   end repeat
   if m is not tCount then put tLines into tHyperTalk
   put 0 into n
   -- (one line at a time: each try compiles the whole handler, and a
   -- handler with more lines than this that do not compile is more
   -- HyperTalk than this engine can run)
   repeat with tTries = 1 to 12
      put line 1 of _CompileError(_JoinLines(tLines, tCount)) into tError
      if tError is empty then
         if n = 0 then return empty
         return _JoinLines(tLines, tCount)
      end if
      put item 2 of tError into k
      if k is not an integer or k < 2 or k >= tCount then return empty
      -- the statement: from the line it starts on to the line it ends on
      -- (\ at the end of a line goes on to the next)
      put k into s
      repeat while s > 2 and _GoesOn(tLines[s - 1])
         subtract 1 from s
      end repeat
      put k into e
      repeat while _GoesOn(tLines[e])
         add 1 to e
         if e >= tCount then return empty
      end repeat
      put _Tokens(tLines[s]) into tTokens
      put _Code(tTokens) into tCode
      put _T(tTokens, item 1 of tCode) into tFirst
      put empty into tPart
      if tFirst is among the words of "if else then" and s = e then
         -- (the statement after a then or an else, if the error is in it;
         -- one already left out means that it was not: the error is in
         -- the if)
         put _StatementPart(tTokens, item 3 of tError) into tPart
         if tPart is not empty and _T(tTokens, item 1 of tPart) is among the words of "hcLeftOut throw" then return empty
      end if
      if tPart is empty and (tFirst is empty or tFirst is among the words of "on function end repeat if else then") then return empty
      add 1 to n
      put s into pLeftOut[n]["line"]
      put tError into pLeftOut[n]["error"]
      if tPart is not empty then
         put _Raw(tTokens, item 1 of tPart, item 2 of tPart) into tStatement
         put word 1 to -1 of tHyperTalk[s] into pLeftOut[n]["text"]
         if _T(tTokens, item 1 of tPart) is among the words of "return exit pass" or _InOpenLoop(tLines, s) then
            put "throw" && _Literal("HyperCard import: a line that does not compile here:" && tStatement) into tTokens[item 1 of tPart]["t"]
            put "stops" into pLeftOut[n]["how"]
         else
            put "hcLeftOut" && _Literal(tStatement) into tTokens[item 1 of tPart]["t"]
            put "skipped" into pLeftOut[n]["how"]
         end if
         repeat with m = item 1 of tPart + 1 to item 2 of tPart
            put empty into tTokens[m]["t"]
         end repeat
         put _Join(tTokens) into tLines[s]
         next repeat
      end if
      put empty into tIndent
      if tTokens[1]["k"] is "sp" then put tTokens[1]["t"] into tIndent
      put empty into tStatement
      repeat with m = s to e
         put word 1 to -1 of _WithoutContinuation(tHyperTalk[m]) & space after tStatement
      end repeat
      put word 1 to -1 of tStatement into tStatement
      put tStatement into pLeftOut[n]["text"]
      if tFirst is among the words of "return exit pass" or _InOpenLoop(tLines, s) then
         put tIndent & "throw" && _Literal("HyperCard import: a line that does not compile here:" && tStatement) into tLines[s]
         put "stops" into pLeftOut[n]["how"]
      else
         put tIndent & "-- HyperCard import: left out, it does not compile here:" && word 1 to -1 of tHyperTalk[s] into tLines[s]
         put "skipped" into pLeftOut[n]["how"]
      end if
      repeat with m = s + 1 to e
         put tIndent & "-- " & word 1 to -1 of tHyperTalk[m] into tLines[m]
      end repeat
   end repeat
   return empty
end _LeaveOutLines

-- T39: the statement after a then or an else on the line of pTokens that
-- the column pColumn of a compile error is in: "from,to", the indices of
-- its first and last code tokens. Empty if no then or else comes before
-- the column (the error is in the if's condition), or the statement is
-- an if ("else if ...") or has a ; in it (the blocks of _ElseBlocks). A
-- then or an else at the column counts: an error at the end of a
-- statement ("if x then put", nothing where put needs a value) is
-- given at the then or the else before it
private function _StatementPart pTokens, pColumn
   local tCode, tColumn, tStart, i, tItem, tAfter, tFrom, tTo
   if pColumn is not an integer then return empty
   put _Code(pTokens) into tCode
   put 1 into tColumn
   repeat with i = 1 to pTokens["count"]
      put tColumn into tStart[i]
      add the number of chars of pTokens[i]["t"] to tColumn
   end repeat
   -- the last then or else before the column, or at it
   put empty into tAfter
   repeat for each item tItem in tCode
      if tStart[tItem] > pColumn then exit repeat
      if _T(pTokens, tItem) is among the words of "then else" then put tItem into tAfter
   end repeat
   if tAfter is empty then return empty
   -- the statement after it, to the next else or the end of the line
   put empty into tFrom
   repeat for each item tItem in tCode
      if tItem <= tAfter then next repeat
      if _T(pTokens, tItem) is "else" then exit repeat
      if _T(pTokens, tItem) is ";" then return empty
      if tFrom is empty then put tItem into tFrom
      put tItem into tTo
   end repeat
   if tFrom is empty or _T(pTokens, tFrom) is "if" then return empty
   return tFrom & comma & tTo
end _StatementPart

-- Whether a line ends with the \ that goes on to the next
private function _GoesOn pLine
   return char -1 of word 1 to -1 of _CodeText(pLine) is "\"
end _GoesOn

-- Whether line pAt of the handler pLines is inside a repeat that only a
-- condition or an exit ends: "repeat", "repeat forever", "repeat until
-- ...", "repeat while ..." (not "repeat with", "repeat for each" or
-- "repeat 5 times", which end by themselves)
private function _InOpenLoop pLines, pAt
   local tDepth, tOpen, i, tTokens, tCode, tWord
   put 0 into tDepth
   repeat with i = 2 to pAt - 1
      put _Tokens(pLines[i]) into tTokens
      put _Code(tTokens) into tCode
      put _T(tTokens, item 1 of tCode) into tWord
      if tWord is "repeat" then
         add 1 to tDepth
         put _T(tTokens, item 2 of tCode) into tWord
         put tWord is empty or tWord is among the words of "forever until while" into tOpen[tDepth]
      else if tWord is "end" and _T(tTokens, item 2 of tCode) is "repeat" and tDepth > 0 then
         subtract 1 from tDepth
      end if
   end repeat
   repeat with i = 1 to tDepth
      if tOpen[i] then return true
   end repeat
   return false
end _InOpenLoop

-- T37: each statement of pText that is "if c then s else" (or "else if c
-- then s else", or "then s else" after an if on the line before), with a
-- statement between its then and the else that ends it, as "if c then;
-- s; else": the else of a block, which is what HyperCard made of it. And
-- "if c then s" with "else" alone on the line after it, which began a
-- block there too: "if c then; s". A statement can go on over lines
-- (\): its then and its else may be on any of them
private function _ElseBlocks pText
   local tLine, tCount, tTokens, tCode, tChanged, tFlat, tItem, k, s, m, n, tThens, tThen, tOut
   put 0 into tCount
   repeat for each line tLine in pText
      add 1 to tCount
      put tLine into tOut[tCount]
      put _Tokens(tLine) into tTokens[tCount]
      put _Code(tTokens[tCount]) into tCode[tCount]
   end repeat
   put 1 into s
   repeat with k = 1 to tCount
      -- (the statement goes on to the next line)
      if _T(tTokens[k], item -1 of tCode[k]) is "\" then next repeat
      -- the code tokens of the statement on lines s to k, without the \
      -- that continue it, and its thens
      put 0 into n
      put 0 into tThens
      repeat with m = s to k
         repeat for each item tItem in tCode[m]
            if m < k and tItem = item -1 of tCode[m] then next repeat
            add 1 to n
            put m into tFlat[n]["line"]
            put tItem into tFlat[n]["token"]
            if _T(tTokens[m], tItem) is "then" then
               add 1 to tThens
               put n into tThen
            end if
         end repeat
      end repeat
      put k + 1 into s
      if tThens is not 1 or tThen = n then next repeat
      if _T(tTokens[tFlat[1]["line"]], tFlat[1]["token"]) is not among the words of "if else then" \
            or _T(tTokens[tFlat[tThen + 1]["line"]], tFlat[tThen + 1]["token"]) is "else" then next repeat
      if _T(tTokens[tFlat[n]["line"]], tFlat[n]["token"]) is "else" then
         put "then;" into tTokens[tFlat[tThen]["line"]][tFlat[tThen]["token"]]["t"]
         put "; else" into tTokens[tFlat[n]["line"]][tFlat[n]["token"]]["t"]
         put true into tChanged[tFlat[tThen]["line"]]
         put true into tChanged[tFlat[n]["line"]]
      else
         -- (the next line with code, alone: else)
         put k + 1 into m
         repeat while m <= tCount and tCode[m] is empty
            add 1 to m
         end repeat
         if m <= tCount and the number of items of tCode[m] = 1 and _T(tTokens[m], tCode[m]) is "else" then
            put "then;" into tTokens[tFlat[tThen]["line"]][tFlat[tThen]["token"]]["t"]
            put true into tChanged[tFlat[tThen]["line"]]
         end if
      end if
   end repeat
   repeat for each key k in tChanged
      put _Join(tTokens[k]) into tOut[k]
   end repeat
   return _JoinLines(tOut, tCount)
end _ElseBlocks

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
