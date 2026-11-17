script "OXTExamplesCheck"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- Run by tools/ci/examples_check.py with a standalone engine on an X
-- server: opens each remastered example in $OXT_EXAMPLES_DIR (the stacks
-- tools/examples builds) and checks where the arrow keys go. Each card
-- hears them before the window's frame (tools/examples/frame-runtime.
-- livecodescript), whichever control has the focus: a key sent to a
-- control of the frame, where a click can leave the focus, must reach the
-- card first too. And no arrow key turns the page (until 0.2.8-dp.2 left
-- and right went to the previous and next card). On every card of every
-- example, with a probe for the card's script:
--    - a card that plays the key keeps it, sent to the frame's list or to
--      the card;
--    - a card that passes it stays in front, either way;
--    - up and down never leave the card.
-- And a tile of the first card, lit with the pointer over it, is at rest
-- again, and the cursor no longer locked as a hand, when the card it goes
-- to opens (the engine finds the pointer still over the tile as the first
-- card closes). Then the cards of Animate a Letter, Balloon Game and Play
-- a Video whose programs play the arrow keys, with their own scripts: the
-- key sent to the frame plays the program, and the card stays.
--
-- Messages are locked throughout, so that no card's program starts when
-- it opens; a key sent here still runs the handlers it reaches. Logs to
-- $OXT_EXAMPLES_LOG an INFO line or two, a PASS or FAIL line for each
-- thing checked, ERROR when the check could not go on, then SUMMARY and
-- QUIT.
--
-- With $OXT_EXAMPLES_MODE "cards", instead: each card of each example
-- opens as it does for someone going through it, its preOpenCard and
-- openCard run and it has a moment for what they start, and each script
-- error is a line SCRIPTERROR (with the engine's error lines, | for a
-- line break), then a line CARD for the card. The examples_check.py
-- run of it only reports: a standalone engine has none of the IDE's
-- libraries, such as the data grid's, that some cards use.

global gOxtExProbe
local sPassed, sFailed

command logLine pText
   put pText & return after URL ("binfile:" & $OXT_EXAMPLES_LOG)
end logLine

on startup
   local tError
   put 0 into sPassed
   put 0 into sFailed
   logLine "INFO platform=" & the platform & " version=" & the version
   -- (revSpeak, below, for the programs that speak a score)
   insert the script of stack "OXTExamplesCheck" into back
   try
      if $OXT_EXAMPLES_MODE is "cards" then
         runCards
      else
         runCheck
      end if
   catch tError
      logLine "ERROR" && line 1 of tError
   end try
   logLine "SUMMARY passed=" & sPassed && "failed=" & sFailed
   logLine "QUIT"
   quit
end startup

command runCheck
   local tDir, tFiles, tFile
   put $OXT_EXAMPLES_DIR into tDir
   if tDir is empty or there is no folder tDir then
      throw "OXT_EXAMPLES_DIR is not a folder: " & tDir
   end if
   set the defaultFolder to tDir
   put the files into tFiles
   filter tFiles with "*.oxtstack"
   if tFiles is empty then
      throw "no stacks in " & tDir
   end if
   lock messages
   repeat for each line tFile in tFiles
      checkFrame tDir & "/" & tFile
   end repeat
   checkProgram tDir & "/Animate a Letter.oxtstack", "Arrow Keys", "left", "field", "Letter", "left", -10
   checkProgram tDir & "/Animate a Letter.oxtstack", "Arrow Keys", "right", "field", "Letter", "left", 10
   checkProgram tDir & "/Animate a Letter.oxtstack", "Arrow Keys", "up", "field", "Letter", "top", -10
   checkProgram tDir & "/Animate a Letter.oxtstack", "Jump Ball", "right", "field", "Letter", "loc", empty
   checkProgram tDir & "/Balloon Game.oxtstack", "page2", "right", "image", "balloon", "left", 18
   checkProgram tDir & "/Balloon Game.oxtstack", "page3", "up", "image", "balloon", "top", -18
   checkProgram tDir & "/Play a Video.oxtstack", "Theater", "right", empty, empty, empty, empty
end runCheck

-- Each card of each example, opened with its messages
local sErrors, sWhere

command runCards
   local tDir, tFiles, tFile, tStack, tCard
   put $OXT_EXAMPLES_DIR into tDir
   set the defaultFolder to tDir
   put the files into tFiles
   filter tFiles with "*.oxtstack"
   repeat for each line tFile in tFiles
      -- (the stack opens without its openStack: some answer when the
      -- IDE's data grid library is not there, and here it never is)
      lock messages
      go stack (tDir & "/" & tFile)
      put the short name of this stack into tStack
      unlock messages
      repeat with tCard = 1 to the number of cards of stack tStack
         put tStack & ", card" && tCard into sWhere
         put 0 into sErrors
         go card tCard of stack tStack
         put sWhere && "(" & the short name of this card & ")" into sWhere
         wait 300 milliseconds with messages
         logLine "CARD" && sWhere & ":" && sErrors && "script error(s)"
         add 1 to sPassed
      end repeat
      put tStack && "closing" into sWhere
      close stack tStack
      wait 50 milliseconds with messages
   end repeat
end runCards

on errorDialog pError
   add 1 to sErrors
   add 1 to sFailed
   replace return with "|" in pError
   logLine "SCRIPTERROR" && sWhere & ":" && pError
end errorDialog

-- The frame of one example, on each of its cards, with probes for the
-- cards' scripts
command checkFrame pPath
   local tStack, tCount, tCard, tScript, tList, tWhat
   go stack pPath
   put the short name of this stack into tStack
   put the number of cards of stack tStack into tCount
   logLine "INFO" && tStack & ":" && tCount && "cards"
   repeat with tCard = 1 to tCount
      go card tCard of stack tStack
      put tStack & ", card" && tCard && "(" & the short name of this card & ")" into tWhat
      put the script of this card into tScript
      put the long id of field "frameList" of this card into tList

      set the script of this card to probeScript(false)
      sendKey tList, "right"
      expect gOxtExProbe is "right" and the number of this card is tCard, tWhat, \
            "plays a right key sent to the frame's list, and stays"
      sendKey the long id of this card, "left"
      expect gOxtExProbe is "left" and the number of this card is tCard, tWhat, \
            "plays a left key sent to the card, and stays"

      set the script of this card to probeScript(true)
      sendKey tList, "up"
      expect gOxtExProbe is "up" and the number of this card is tCard, tWhat, \
            "hears an up key sent to the frame's list, and stays"
      sendKey tList, "right"
      expect gOxtExProbe is "right" and the number of this card of stack tStack is tCard, tWhat, \
            "hears a right key sent to the frame's list and passes it, and the frame stays on the card"
      set the script of card tCard of stack tStack to tScript
      go card tCard of stack tStack

      set the script of this card to probeScript(true)
      sendKey the long id of this card, "right"
      expect gOxtExProbe is "right" and the number of this card of stack tStack is tCard, tWhat, \
            "hears a right key sent to the card and passes it, and the frame stays on the card"
      set the script of card tCard of stack tStack to tScript
   end repeat
   checkRest tStack
   close stack tStack
end checkFrame

-- The first tile of the first card, lit, and the second card opened with
-- an empty script (so that only the frame's preOpenCard runs)
command checkRest pStack
   local tTile, tScript
   go card 1 of stack pStack
   if there is no group "tile1" of card 1 of stack pStack then
      expect false, pStack, "has a tile on its first card"
      exit checkRest
   end if
   put the long id of group "tile1" of card 1 of stack pStack into tTile
   dispatch "mouseEnter" to graphic 1 of tTile
   expect the backgroundColor of graphic 1 of tTile is the cLit of tTile and the lockCursor, pStack, \
         "lights its first card's first tile, and locks the cursor, with the pointer over it"
   go card 2 of stack pStack
   put the script of this card into tScript
   set the script of this card to empty
   dispatch "preOpenCard" to this card
   set the script of card 2 of stack pStack to tScript
   expect the backgroundColor of graphic 1 of tTile is the cRest of tTile and not the lockCursor, pStack, \
         "puts the tile at rest, and unlocks the cursor, when card 2 opens"
   unlock cursor
   set the backgroundColor of graphic 1 of tTile to the cRest of tTile
end checkRest

-- A card whose program plays an arrow key, with its own script: the key
-- sent to the frame's list plays it, and the card stays. The property
-- pProp of the control pType pName moves by pBy, or does not change when
-- pBy is empty (no control: only the card is checked)
command checkProgram pPath, pCard, pKey, pType, pName, pProp, pBy
   local tStack, tWhat, tExpr, tBefore, tAfter, tError
   go stack pPath
   put the short name of this stack into tStack
   go card pCard of stack tStack
   put tStack & ", card" && quote & pCard & quote into tWhat
   set the randomSeed to 1
   if pType is not empty then
      put "the" && pProp && "of" && pType && quote & pName & quote into tExpr
      put value(tExpr) into tBefore
   end if
   try
      sendKey the long id of field "frameList" of this card, pKey
   catch tError
      expect false, tWhat, "the" && pKey && "key sent to the frame's list stopped with an error:" && line 1 of tError
   end try
   expect the short name of this card of stack tStack is pCard, tWhat, \
         "keeps a" && pKey && "key sent to the frame's list"
   if tExpr is not empty then
      put value(tExpr) into tAfter
      if pBy is empty then
         expect tAfter is tBefore, tWhat, "the" && pKey && "key leaves" && tExpr && "at" && tBefore & ", and it is" && tAfter
      else
         expect tAfter is a number and tBefore is a number and tAfter - tBefore is pBy, tWhat, \
               "the" && pKey && "key moves" && tExpr && "by" && pBy & ": from" && tBefore && "to" && tAfter
      end if
   end if
   close stack tStack
end checkProgram

-- A card script that notes the arrow key it hears in gOxtExProbe, and
-- passes it when pPass is true
function probeScript pPass
   local tScript
   put "global gOxtExProbe" & return & "on arrowKey pKey" & return & "put pKey into gOxtExProbe" & return into tScript
   if pPass then
      put "pass arrowKey" & return after tScript
   end if
   return tScript & "end arrowKey"
end probeScript

-- An arrow key, sent to an object as the engine sends it to the one with
-- the focus
command sendKey pObj, pKey
   put empty into gOxtExProbe
   dispatch "arrowKey" to pObj with pKey
end sendKey

command expect pCondition, pWhat, pClaim
   if pCondition then
      add 1 to sPassed
      logLine "PASS" && pWhat & ":" && pClaim
   else
      add 1 to sFailed
      logLine "FAIL" && pWhat & ":" && pClaim
   end if
end expect

-- (Animate a Letter speaks the score when the letter reaches the ball)
command revSpeak pText
   logLine "INFO revSpeak" && pText
end revSpeak
