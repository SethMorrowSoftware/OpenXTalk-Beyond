script "oxt_visual_effect_check"
-- Visual effects on a card change, as a stack plays them: a window whose
-- cards are black and white in turn, and one visual effect after another
-- from one to the next, each played very slowly, so that a driver
-- watching the screen (tools/ci/visual_effect_check.py) sees the frames
-- between the two cards. The forum's report on 0.2.7 with macOS 15
-- (2026-11-19): visual effect transitions did not play, the card just
-- changed; on macOS 11 and later each frame was drawn as the card already
-- was (engine/src/desktop-stack.cpp, view_platform_updatewindowwithcallback).
-- The last four name no direction: the forum's report on 0.2.8-dp.1
-- (2026-11-19) that wipe, reveal, push and scroll crash the IDE; with none
-- they reached an unreachable default in engine/src/stacke.cpp, which the
-- Mac's build compiled into a crash. They play down (scroll left) now.
--
-- It runs as the development engine's home stack: copied to
-- <folder>/Startup.rev with REV_TOOLS_PATH set to <folder>.
--
-- Environment variables:
--    OXT_VE_OUT      folder for marks.txt (required)
--    OXT_VE_EFFECTS  the effects to play, separated by "|" (default
--                    kEffects); each is what follows "visual effect"
--    OXT_VE_RATE     the effectRate, in milliseconds (default 4000; the
--                    effects are played "very slowly", which takes that
--                    long, a dissolve twice as long)
--
-- marks.txt, a line per event, fields separated by tabs, each line
-- written whole with its file rewritten:
--    INFO    name  value
--    RECT    left,top,right,bottom  the card's area on the screen, in points
--    START   effect  from-colour  to-colour  (the effect starts 1500 ms later)
--    END     effect  milliseconds it took
--    ERROR   where  text
--    DONE
-- Exit code 0 when every effect was played, 2 when OXT_VE_OUT is not set,
-- 3 on a script error.

constant kStack = "oxt_visual_effect"
constant kEffects = "dissolve|wipe right|iris open|push left|barn door open|CIDissolveTransition|wipe|push|reveal|scroll"

local sOut
local sMarks
local sStarted

on startup
   local tCode
   put true into sStarted
   runEffectCheck
   put the result into tCode
   if tCode is not empty then quit tCode
   quit 0
end startup

-- Empty when every effect was played, otherwise the exit code
command runEffectCheck
   local tEffects, tRate, tColour, tNext, tStart, tElapsed, tEffect, tSyntax
   put $OXT_VE_OUT into sOut
   replace "\" with "/" in sOut
   if the last char of sOut is "/" then delete the last char of sOut
   if sOut is empty then
      write "OXT_VE_OUT is not set" & return to stdout
      return 2
   end if
   if there is not a folder sOut then create folder sOut
   put empty into sMarks
   put empty into url ("binfile:" & sOut & "/marks.txt")

   put $OXT_VE_EFFECTS into tEffects
   if tEffects is empty then put kEffects into tEffects
   put $OXT_VE_RATE into tRate
   if tRate is not an integer then put 4000 into tRate

   try
      addMark "INFO", "version", the version & " build " & the buildNumber
      addMark "INFO", "platform", the platform & " " & the systemVersion & " " & the processor
      buildStack tEffects
      addMark "RECT", the rect of stack kStack
      set the effectRate to tRate
      put "black" into tColour
      set the itemDelimiter to "|"
      repeat for each item tEffect in tEffects
         if tColour is "black" then
            put "white" into tNext
         else
            put "black" into tNext
         end if
         addMark "START", tEffect, tColour, tNext
         -- time for the driver to see the card as it is before the effect
         wait 1500 milliseconds with messages
         put the milliseconds into tStart
         -- a Core Image transition by its name, as a quoted string
         put tEffect into tSyntax
         if tEffect begins with "CI" then put quote & tEffect & quote into tSyntax
         do "visual effect" && tSyntax && "very slowly"
         go next card of stack kStack
         put the milliseconds - tStart into tElapsed
         addMark "END", tEffect, tElapsed
         -- and as it is after it
         wait 1500 milliseconds with messages
         put tNext into tColour
      end repeat
      addMark "DONE"
   catch tError
      addMark "ERROR", "script", oneLine(tError)
      return 3
   end try
   return empty
end runEffectCheck

on errorDialog pError
   addMark "ERROR", "errorDialog", oneLine(pError)
   quit 3
end errorDialog

-- A card for each effect and one more, black and white in turn, filled by
-- the card's backgroundColor alone (nothing else on it)
private command buildStack pEffects
   local tCount, n
   set the itemDelimiter to "|"
   put the number of items of pEffects + 1 into tCount
   lock screen
   create invisible stack kStack
   set the defaultStack to kStack
   set the rect of stack kStack to 160,160,560,460
   set the resizable of stack kStack to false
   set the backgroundColor of card 1 of stack kStack to "black"
   repeat with n = 2 to tCount
      create card
      if n mod 2 is 0 then
         set the backgroundColor of it to "white"
      else
         set the backgroundColor of it to "black"
      end if
   end repeat
   go card 1 of stack kStack
   unlock screen
   show stack kStack
   -- time for the window to come up and be drawn
   wait 2 seconds with messages
end buildStack

private command addMark
   local tLine, n
   repeat with n = 1 to the paramCount
      if n > 1 then put tab after tLine
      put param(n) after tLine
   end repeat
   put tLine & return after sMarks
   put sMarks into url ("binfile:" & sOut & "/marks.txt")
end addMark

private function oneLine pText
   replace return with " / " in pText
   return pText
end oneLine
