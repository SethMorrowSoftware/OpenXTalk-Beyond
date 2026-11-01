script "HyperCardSweep"
-- One stack of a HyperCard corpus sweep (see README.md): import it with
-- File > Import Stack's importer, fix its scripts with
-- revHyperCardFixScripts, and log what happened, one tab-separated line
-- at a time, to the file $HC_OUT. Run headless by sweep.py, which sets:
--
--   HC_IN    the stack (MacBinary or a plain HyperCard stack file)
--   HC_OUT   the log file
--   HC_LIB   the folder of the HyperCard libraries to load
--            (ide/Toolset/libraries in a checkout)
--   HC_ICONS the IDE's revicons.rev, with HyperCard's brushes and
--            patterns (ide/Toolset/palettes in a checkout), or empty
--   HC_MODE  "fix" to stop after the scripts are fixed; "run" to go on
--            and open the stack, go to its first 40 cards and click up to
--            20 buttons on each of the first 20, the way a person would
--   HC_IMAGE and HC_IMAGEPATH  (or empty) the disk image the stack came
--            from and its path on that image, Volume:Folder:Stack
--
-- The log's lines: IMPORTED name cards; NOIMPORT error; FIX summary;
-- LEFT name error text (a handler left out, its text in base64); LINE
-- name line how error text (a line left out of a handler that was kept,
-- rule T39); AT phase (a step of the run as it starts: open, card N,
-- click N,M, so that the last one of a stack that timed out is where it
-- stopped); ERR and THROW phase error source (an error while running,
-- base64); ABORT phase (a step a script ended with "exit to top", after
-- which the tour went on); MODAL phase name (a window that waited for a
-- person, closed by the sweep, the name base64); SKIP phase (a click
-- left out: the button hidden or disabled); DIALOG phase kind reply (an
-- answer or ask the sweep answered, the reply base64); OPENED; DONE.
-- Text that may hold returns is base64 so a line stays a line.

local sDone, sOut, sModal, sTour

on openStack
   if the short name of the owner of the target is not "HyperCardSweep" then pass openStack
   if sDone then pass openStack
   put true into sDone
   -- after openStack, so that the engine has finished starting
   send "sweepRun" to me in 0 milliseconds
end openStack

command sweepRun
   local tStack, tReport, tError, tLine, tLeft, i, tMace
   global gSweepPhase
   put $HC_OUT into sOut
   start using stack ($HC_LIB & "/revhypercardscriptlibrary.livecodescript")
   -- as in the IDE, which keeps revIcons in memory: HyperCard's brushes
   -- and patterns (images 101 to 136, and 137 on, of its substacks), so
   -- that a "set the pattern to 12" or a "reset paint" finds them. The
   -- stack is loaded, not opened, so it is not among the openStacks
   if $HC_ICONS is not empty and there is a file $HC_ICONS then
      get the short name of stack $HC_ICONS
   end if
   -- errors while running come here instead of a dialog
   create invisible stack "HyperCardSweepErrors"
   set the script of stack "HyperCardSweepErrors" to "on errorDialog pError" & return \
         & "global gSweepErrors" & return & "put pError & numToChar(1) after gSweepErrors" & return & "end errorDialog"
   lock messages
   try
      import stack from file $HC_IN
   catch tError
   end try
   put the result into tLine
   unlock messages
   repeat for each line tLine in the openStacks
      if tLine is not among the items of "HyperCardSweep,HyperCardSweepErrors,revHyperCardScriptLibrary,revHyperCardMACELibrary,revHyperCardDiskImageLibrary" \
            and not (tLine begins with "revHyperCardProbe") then
         put the long id of stack tLine into tStack
         exit repeat
      end if
   end repeat
   if tStack is empty then
      sweepLog "NOIMPORT" & tab & sweepBase64(tError & tLine)
      quit
   end if
   sweepLog "IMPORTED" & tab & the short name of tStack & tab & the number of cards of tStack

   -- From a disk image, as File > Import Stack does: where on the image the
   -- stack came from, so that a "go" or a "start using" finds a stack
   -- beside it there (the HyperCard Library's hcStackName). The stacks
   -- folder names its files by number, so beside a stack there, no stack
   -- is found by its name
   if $HC_IMAGE is not empty then
      if there is a file ($HC_LIB & "/revhypercarddiskimagelibrary.livecodescript") then
         start using stack ($HC_LIB & "/revhypercarddiskimagelibrary.livecodescript")
      end if
      set the uHyperCard["image"] of tStack to $HC_IMAGE
      set the uHyperCard["imagepath"] of tStack to $HC_IMAGEPATH
   end if
   -- as File > Import Stack does: HyperCard's message order (HC_ORDER=1,
   -- on an engine that has hyperTalkCompatible), the scripts, the MACE
   -- sounds and the classic look
   if $HC_ORDER is 1 then
      try
         set the hyperTalkCompatible of tStack to true
      catch tError
      end try
   end if
   put revHyperCardFixScripts(tStack) into tReport
   sweepLog "FIX" & tab & the last line of tReport
   put revHyperCardLeftOutHandlers() into tLeft
   repeat with i = 1 to the number of elements of tLeft
      sweepLog "LEFT" & tab & tLeft[i]["name"] & tab & tLeft[i]["error"] & tab & sweepBase64(tLeft[i]["text"])
   end repeat
   -- (a library from before rule T39 has no revHyperCardLeftOutLines)
   try
      put revHyperCardLeftOutLines() into tLeft
   catch tError
      put empty into tLeft
   end try
   repeat with i = 1 to the number of elements of tLeft
      sweepLog "LINE" & tab & tLeft[i]["name"] & tab & tLeft[i]["line"] & tab & tLeft[i]["how"] & tab & tLeft[i]["error"] & tab & sweepBase64(tLeft[i]["text"])
   end repeat
   if there is a file ($HC_LIB & "/revhypercardmacelibrary.livecodescript") then
      start using stack ($HC_LIB & "/revhypercardmacelibrary.livecodescript")
      put 0 into tMace
      repeat for each line tLine in the hcImportStat
         if tLine begins with "Not converting snd" and "MACE" is in tLine then add 1 to tMace
      end repeat
      try
         get revHyperCardConvertMACESounds(tStack, $HC_IN)
      catch tError
         put "error" into it
      end try
      if tMace > 0 or it > 0 then sweepLog "MACE" & tab & tMace & tab & it
   end if
   try
      revHyperCardClassicLook tStack
   catch tError
   end try
   if $HC_MODE is not "run" then
      sweepLog "DONE"
      quit
   end if

   -- A person answers "answer" and "ask": with their default button, as
   -- the sweep does here (DIALOG). The engine shows them with the stacks
   -- "Answer Dialog" and "Ask Dialog", which the IDE has and a run
   -- without it had not: there "it" was the engine's request to the
   -- dialog, title, prompt and buttons in one, and not a reply. A stack
   -- that asked how many players until it was told 1, 2 or 3 asked for
   -- ever, and one that asked for a year went on with that text as one
   -- (sweepDialog)
   create invisible stack "Answer Dialog"
   create invisible stack "Ask Dialog"
   repeat for each item tLine in "Answer Dialog,Ask Dialog"
      set the script of stack tLine to "on openStack" & return \
            & "dispatch " & quote & "sweepDialog" & quote && "to stack" && quote & "HyperCardSweep" & quote && "with the short name of me" & return \
            & "end openStack"
   end repeat

   insert the script of stack "HyperCardSweepErrors" into back
   send "sweepModalWatch" to me in 250 milliseconds
   put tStack into sTour["stack"]
   -- The import opened the stack with messages locked, before its scripts
   -- were fixed, so its own openStack, openBackground and openCard have
   -- not run, and "go" to a stack already open sends none. Closed (with
   -- messages locked, kept in memory) and gone to again, it opens as a
   -- person opens it once it is saved: with those messages, where many
   -- stacks set themselves up and call their externals first
   try
      set the destroyStack of tStack to false
      lock messages
      do "close" && tStack
   catch tError
   end try
   unlock messages
   sweepStep "open", "sweepRun", "sweepOpened"
   try
      -- (by "do": "go to card 1 of" a variable is read when the script
      -- loads, before the stack is there)
      do "go to card 1 of" && tStack
   catch tError
      sweepLog "THROW" & tab & "open" & tab & sweepBase64(tError) & tab & sweepBase64(sweepSource(tError))
   end try
   sweepStepDone
   sweepOpened
end sweepRun

-- The stack is open: its tour
command sweepOpened
   sweepFlush
   sweepLog "OPENED"
   sweepTour sTour["stack"]
end sweepOpened

-- Go to the stack's first 40 cards, and on each of the first 20 click up
-- to 20 buttons, back on the card before each click. One visit or one
-- click to a message, as a person does one thing at a time: the engine
-- starts each message afresh, as it starts each of a person's clicks,
-- with no screen or messages left locked and no dynamic path (after a
-- "go", a message of that handler goes on to the card it went to as well
-- as through its own stack), and the stack's own idle and timer messages
-- come between them. In one long handler, a button's "go home" that
-- opened another stack once left the stack's own handlers unanswered for
-- the rest of the tour, when the engine sent such a handler's messages to
-- the other stack in place of its own
command sweepTour pStack
   put pStack into sTour["stack"]
   put min(40, the number of cards of pStack) into sTour["cards"]
   put 0 into sTour["card"]
   put 0 into sTour["button"]
   put 0 into sTour["buttons"]
   send "sweepTourStep" to me in 0 milliseconds
end sweepTour

-- The tour's next click on this card, or else its next card
command sweepTourStep
   local tStack, tCardId, tError
   global gSweepPhase
   put sTour["stack"] into tStack
   if there is not a tStack then
      sweepTourDone
   else if sTour["button"] < sTour["buttons"] then
      add 1 to sTour["button"]
      put sTour["cardid"] into tCardId
      sweepStep "click" && sTour["card"] & "," & sTour["button"], "sweepTourStep", "sweepTourStep"
      try
         if exists(tCardId) and the long id of this card of tStack is not tCardId then
            lock messages
            do "go to" && tCardId
            unlock messages
         end if
         -- A person cannot click a button that is hidden, and HyperCard
         -- sends a disabled one no mouse messages: such a button is left
         -- out (SKIP). Clicked anyway, its script ran where it never runs
         -- in HyperCard, and its errors and waits were the sweep's own
         if exists(tCardId) and the number of buttons of tCardId >= sTour["button"] then
            if the visible of button sTour["button"] of tCardId and the enabled of button sTour["button"] of tCardId then
               dispatch "mouseDown" to button sTour["button"] of tCardId
               dispatch "mouseUp" to button sTour["button"] of tCardId
            else
               sweepLog "SKIP" & tab & gSweepPhase
            end if
         end if
      catch tError
         sweepLog "THROW" & tab & gSweepPhase & tab & sweepBase64(tError) & tab & sweepBase64(sweepSource(tError))
      end try
      sweepStepDone
      sweepFlush
      send "sweepTourStep" to me in 0 milliseconds
   else if sTour["card"] < sTour["cards"] then
      add 1 to sTour["card"]
      sweepStep "card" && sTour["card"], "sweepTourStep", "sweepCardVisited"
      try
         do "go to card" && sTour["card"] && "of" && tStack
      catch tError
         sweepLog "THROW" & tab & gSweepPhase & tab & sweepBase64(tError) & tab & sweepBase64(sweepSource(tError))
      end try
      sweepStepDone
      sweepFlush
      sweepCardVisited
   else
      sweepTourDone
   end if
end sweepTourStep

-- The card the tour went to: its buttons, on the first 20 cards, and on
-- to the next step
command sweepCardVisited
   local tStack
   put sTour["stack"] into tStack
   put 0 into sTour["button"]
   put 0 into sTour["buttons"]
   if there is a tStack and sTour["card"] <= 20 then
      put the long id of card sTour["card"] of tStack into sTour["cardid"]
      put min(20, the number of buttons of sTour["cardid"]) into sTour["buttons"]
   end if
   send "sweepTourStep" to me in 0 milliseconds
end sweepCardVisited

-- A step of the run (pPhase) starts: logged, so that a stack that timed
-- out shows where it stopped, and pending until sweepStepDone. A
-- script's "exit to top" ends every handler that is running, the
-- sweep's own pRunning too, before it goes on: sweepModalWatch finds the
-- step pending with pRunning no longer running, and goes on with
-- pResume, as a person goes on after a click that stopped. Without this
-- the tour stopped at the first such step, and the stack timed out
command sweepStep pPhase, pRunning, pResume
   global gSweepPhase
   put pPhase into gSweepPhase
   sweepLog "AT" & tab & pPhase
   put pRunning into sTour["running"]
   put pResume into sTour["resume"]
   put pPhase into sTour["pending"]
end sweepStep

command sweepStepDone
   put empty into sTour["pending"]
end sweepStepDone

-- Whether a handler named pHandler is running
function sweepIsRunning pHandler
   local tLine
   repeat for each line tLine in the executionContexts
      if item -2 of tLine is pHandler then return true
   end repeat
   return false
end sweepIsRunning

command sweepTourDone
   sweepLog "DONE"
   quit
end sweepTourDone

-- A modal window (a list dialog of the HyperCard library, a stack's own
-- modal stack) waits until a person closes it, and nobody is there to:
-- one still open a quarter of a second after it was first seen is
-- closed, as its Cancel button or close box would close it, and logged.
-- Without this the tour stopped at the first one, and the stack timed out.
-- The watch also goes on with the tour after a step that a script ended
-- with "exit to top" (sweepStep)
command sweepModalWatch
   local tLine, tSeen, tError, tResume
   global gSweepPhase
   -- (first, so that a script's "exit to top" as a window closes does not
   -- end the watch)
   send "sweepModalWatch" to me in 250 milliseconds
   -- a step a script ended with "exit to top" (sweepStep)
   if sTour["pending"] is not empty and not sweepIsRunning(sTour["running"]) then
      put sTour["resume"] into tResume
      put empty into sTour["pending"]
      sweepFlush
      sweepLog "ABORT" & tab & gSweepPhase
      send tResume to me in 0 milliseconds
   end if
   repeat for each line tLine in the openStacks
      if tLine is among the items of "HyperCardSweep,HyperCardSweepErrors,Answer Dialog,Ask Dialog" then next repeat
      try
         if the mode of stack tLine is among the items of "5,6" then
            if sModal[tLine] then
               sweepLog "MODAL" & tab & gSweepPhase & tab & sweepBase64(tLine)
               close stack tLine
            else
               put true into tSeen[tLine]
            end if
         end if
      catch tError
      end try
   end repeat
   put tSeen into sModal
end sweepModalWatch

-- The errors errorDialog collected since the last time, to the log
command sweepFlush
   global gSweepErrors, gSweepPhase
   local tError
   set the itemDelimiter to numToChar(1)
   repeat for each item tError in gSweepErrors
      if tError is not empty then
         sweepLog "ERR" & tab & gSweepPhase & tab & sweepBase64(tError) & tab & sweepBase64(sweepSource(tError))
      end if
   end repeat
   put empty into gSweepErrors
end sweepFlush

-- The line of script an error names, and its object: the statement that
-- failed, which in a repeat or an if is the line inside it (the error's
-- first line), not the repeat's or the if's (its line in the handler)
function sweepSource pError
   local tLine, tNumber, tObject
   put 0 into tNumber
   repeat for each line tLine in pError
      if item 1 of tLine is 353 then
         put item 4 to -1 of tLine into tObject
         try
            if tNumber > 0 and exists(tObject) then
               return word 1 to -1 of line tNumber of the script of tObject & " ||| " & tObject
            end if
         catch tLine
         end try
         -- (an object that is gone: the line of the handler that called)
         put 0 into tNumber
      else if tNumber is 0 and item 2 of tLine is an integer and item 2 of tLine > 0 then
         put item 2 of tLine into tNumber
      end if
   end repeat
   return empty
end sweepSource

-- An "answer" or "ask" (the stack pDialog of the engine's, opened as a
-- modal window): its default button, as a person most often clicks it.
-- The dialogData is the request, its parts separated by numToChar(0):
-- "answer" and its kind, the title, the prompt, the buttons a line each,
-- or "ask" and its kind, the title, the prompt, the reply it offers. An
-- answer's default is its last button (OK if it has none), as in
-- HyperCard; an ask's is OK with the reply it offers, which may be empty
command sweepDialog pDialog
   local tData, tReply, tKind
   global gSweepPhase
   put the dialogData into tData
   set the itemDelimiter to numToChar(0)
   put word 1 to 2 of item 1 of tData into tKind
   if word 1 of item 1 of tData is "ask" then
      put item 4 of tData into tReply
   else
      put item 4 of tData into tReply
      put line -1 of tReply into tReply
      if tReply is empty then put "OK" into tReply
   end if
   set the itemDelimiter to comma
   sweepLog "DIALOG" & tab & gSweepPhase & tab & tKind & tab & sweepBase64(tReply)
   set the dialogData to tReply
   -- (closed now, not later: a script that asks again at once would
   -- find it still open, and the engine would not ask it)
   close stack pDialog
end sweepDialog

command sweepLog pLine
   open file sOut for append
   write pLine & return to file sOut
   close file sOut
end sweepLog

function sweepBase64 pText
   local tText
   put base64Encode(textEncode(pText, "UTF-8")) into tText
   replace return with empty in tText
   return tText
end sweepBase64
