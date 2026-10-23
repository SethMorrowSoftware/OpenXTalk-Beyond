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
--   HC_MODE  "fix" to stop after the scripts are fixed; "run" to go on
--            and open the stack, go to its first 40 cards and click up to
--            20 buttons on each of the first 20, the way a person would
--
-- The log's lines: IMPORTED name cards; NOIMPORT error; FIX summary;
-- LEFT name error text (a handler left out, its text in base64); ERR and
-- THROW phase error source (an error while running, base64); OPENED;
-- DONE. Text that may hold returns is base64 so a line stays a line.

local sDone, sOut

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
      if tLine is not among the items of "HyperCardSweep,HyperCardSweepErrors,revHyperCardScriptLibrary,revHyperCardMACELibrary" \
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

   insert the script of stack "HyperCardSweepErrors" into back
   put "open" into gSweepPhase
   try
      -- (by "do": "go to card 1 of" a variable is read when the script
      -- loads, before the stack is there)
      do "go to card 1 of" && tStack
   catch tError
      sweepLog "THROW" & tab & "open" & tab & sweepBase64(tError) & tab & sweepBase64(sweepSource(tError))
   end try
   sweepFlush
   sweepLog "OPENED"
   sweepTour tStack
   sweepLog "DONE"
   quit
end sweepRun

-- Go to the stack's first 40 cards, and on each of the first 20 click up
-- to 20 buttons, back on the card before each click
command sweepTour pStack
   local tCards, tCard, tButtons, tButton, tCardId, tError
   global gSweepPhase
   put min(40, the number of cards of pStack) into tCards
   repeat with tCard = 1 to tCards
      put "card" && tCard into gSweepPhase
      try
         do "go to card" && tCard && "of" && pStack
      catch tError
         sweepLog "THROW" & tab & gSweepPhase & tab & sweepBase64(tError) & tab & sweepBase64(sweepSource(tError))
      end try
      sweepFlush
      if there is not a pStack then exit repeat
      if tCard > 20 then next repeat
      put the long id of card tCard of pStack into tCardId
      put min(20, the number of buttons of tCardId) into tButtons
      repeat with tButton = 1 to tButtons
         put "click" && tCard & "," & tButton into gSweepPhase
         try
            if exists(tCardId) and the long id of this card of pStack is not tCardId then
               lock messages
               do "go to" && tCardId
               unlock messages
            end if
            if exists(tCardId) and the number of buttons of tCardId >= tButton then
               dispatch "mouseDown" to button tButton of tCardId
               dispatch "mouseUp" to button tButton of tCardId
            end if
         catch tError
            sweepLog "THROW" & tab & gSweepPhase & tab & sweepBase64(tError) & tab & sweepBase64(sweepSource(tError))
         end try
         sweepFlush
         if there is not a pStack then exit repeat
      end repeat
      if there is not a pStack then exit repeat
   end repeat
end sweepTour

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

-- The line of script an error names, and its object
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
      else if item 2 of tLine is an integer and item 2 of tLine > 0 then
         put item 2 of tLine into tNumber
      end if
   end repeat
   return empty
end sweepSource

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
