script "stack_Learn_Box2Dxt_Kit_group_id_1199"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Quick" (id 1031) > group "Lab" (id 1199)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- The Lab: what every lesson of Learn the Box2Dxt Kit shares. It is the
-- script of the group "Lab", a background on each lesson card, with the
-- court the game runs in, the line of words at its top, Reset, Pause and
-- Step, and the tabs beside the court. When a card opens, the Lab:
--
--    makes the Kit's world, with b2kSetup, and fits it to the court:
--    40 pixels to a metre, the floor at the court's bottom, and a wall
--    on each side, so that nothing leaves the court (labOpen)
--    calls the card's labBuild, which makes the lesson's game, and
--    starts the Kit's loop with b2kStart
--    calls the card's labStep each frame, if it has one (b2kFrame)
--    lets you drag anything that moves, with b2kGrab and b2kRelease
--    takes the world and everything the Kit made away when the card
--    closes, with b2kClear and b2kTeardown (labClose)
--
-- The Kit works in pixels and screen coordinates (y goes DOWN), and in
-- degrees, and converts to Box2D's metres, y up and radians itself. A
-- game of yours does what labOpen does with the whole card, or simply
-- calls b2kQuickStart.

constant kScale = 40

-- The card in front and its stack
local sCard, sStack
-- True when the Kit is running a world for the card in front
local sReady
-- True while the Pause button holds the game still
local sPaused
-- What a card asked the Lab to take away when it closes (labKeep)
local sKept
-- When the line at the court's top last changed, and what it says
local sSaidAt, sSaid
-- True while a click in the court is handed to the card's mouseDown
local sForwarding
-- The button of the card's that is lit for a moment (labShowButtons)
local sFlashed, sLightTicks
-- The card being opened, until labOpenNow makes its lesson
local sOpening

########################################
#
# The card opens and closes
#

-- The card opens: the sign that the lesson is being made shows first,
-- and the lesson is made a moment later, when the window has drawn the
-- card and the sign. (Made at once, the card stays blank until it is
-- ready.) A card left before then is not made
on openCard
   labLoading true
   put the long id of this card into sOpening
   send "labOpenNow" to me in 20 milliseconds
   pass openCard
end openCard

command labOpenNow
   if sOpening is not the long id of this card then
      exit labOpenNow
   end if
   put empty into sOpening
   labOpen
   labLoading false
end labOpenNow

-- Shows, or takes away, the sign that the lesson is being made, with the
-- busy pointer
command labLoading pOn
   if there is a group "LabLoading" then
      set the visible of group "LabLoading" to pOn
   end if
   if pOn then
      lock cursor
      set the cursor to busy
   else
      unlock cursor
   end if
end labLoading

on closeCard
   labClose
   pass closeCard
end closeCard

on closeStack
   labClose
   pass closeStack
end closeStack

-- Makes the card's game: the Kit's world in the court, then the card's
-- labBuild, then the loop
command labOpen
   local tError, tLeft, tTop, tRight, tBottom
   labClose
   put the long id of this card into sCard
   put the short name of this stack into sStack
   put false into sPaused
   labPauseLabel
   labTabExplain
   labPaintCode
   if not labKitReady() then
      labSay "The Box2Dxt Kit is not loaded. Turn on Box2Dxt and the Box2Dxt Kit in Tools > Extension Manager, then open this card again.", true
      exit labOpen
   end if
   put the left of graphic "Court" into tLeft
   put the top of graphic "Court" into tTop
   put the right of graphic "Court" into tRight
   put the bottom of graphic "Court" into tBottom
   -- (locked while the card makes its game: a control is made before it
   -- is sized and put in its place)
   lock screen
   try
      -- A world, with gravity pulling down at 10 metres a second each
      -- second (y up, as Box2D counts), 40 pixels to a metre, and the
      -- world's 0,0 at the middle of the court's floor
      b2kSetup 0, -10
      b2kSetScale kScale
      b2kSetOrigin (tLeft + tRight) div 2, tBottom
      -- Walls around the court: lines that nothing passes through. (A
      -- card with a world bigger than the court, as Camera has, makes
      -- its own, in a labWorld handler)
      dispatch "labWorld" to sCard
      if it is not "handled" then
         b2kWall tLeft, tBottom, tRight, tBottom
         b2kWall tLeft, tTop, tLeft, tBottom
         b2kWall tRight, tTop, tRight, tBottom
         b2kWall tLeft, tTop, tRight, tTop
      end if
      -- Each frame, b2kFrame comes here; contacts go to the card
      b2kFrameTarget the long id of me
      b2kContactTarget sCard
      put true into sReady
      dispatch "labBuild" to sCard
      b2kStart
      labShowButtons empty
   catch tError
      labFail "labBuild", tError
   end try
   unlock screen
end labOpen

-- True when the Kit is there to call: its b2kVersion() is 4
function labKitReady
   local tError
   try
      return b2kVersion() is 4
   catch tError
      return false
   end try
end labKitReady

-- Stops the game and takes away what the Kit and the card made
command labClose
   local tId, tError
   if sReady then
      put false into sReady
      try
         b2kRelease
         -- (the keyboard, if a lesson read it)
         b2kInputInjectOff
         b2kInputOff
         -- (everything the Kit made that moves, then the world itself)
         b2kClear
         b2kTeardown
      catch tError
      end try
   end if
   lock screen
   lock messages
   repeat for each line tId in sKept
      if there is a tId then
         delete tId
      end if
   end repeat
   unlock messages
   unlock screen
   put empty into sKept
   put empty into sSaid
   if sCard is not empty and there is a field "Readout" of sCard then
      put empty into field "Readout" of sCard
   end if
   if there is a graphic "ReadoutBg" then
      hide graphic "ReadoutBg"
   end if
end labClose

-- A control the card made that is not the Kit's: the Lab deletes it
-- when the card closes or resets
command labKeep pObj
   put the long id of pObj & return after sKept
end labKeep

########################################
#
# Each frame
#

-- The Kit sends b2kFrame to its frame target (b2kFrameTarget) once a
-- frame, after it has moved everything: the card's labStep runs here
on b2kFrame
   local tError
   if not sReady then
      exit b2kFrame
   end if
   try
      dispatch "labStep" to sCard
   catch tError
      labFail "labStep", tError
   end try
   -- (the keys, and the lessons themselves, can switch things too: the
   -- lights follow, five times a second)
   add 1 to sLightTicks
   if sLightTicks mod 12 is 0 then
      labShowButtons empty
   end if
end b2kFrame

-- The Reset button
command labRestart
   labOpen
end labRestart

-- The Pause button: b2kPause holds the game still, b2kResume sets it
-- going again
command labTogglePause
   if not sReady then
      exit labTogglePause
   end if
   put not sPaused into sPaused
   if sPaused then
      b2kPause
   else
      b2kResume
   end if
   labPauseLabel
end labTogglePause

-- The Step button: one frame, then paused
command labStepButton
   if not sReady then
      exit labStepButton
   end if
   if not sPaused then
      put true into sPaused
      b2kPause
      labPauseLabel
   end if
   b2kStepOnce
end labStepButton

private command labPauseLabel
   if there is a field "LabPause_label" then
      if sPaused then
         put "Play" into field "LabPause_label"
      else
         put "Pause" into field "LabPause_label"
      end if
   end if
end labPauseLabel

-- When a handler of the card stops with an error, the game stops, and
-- the line at the court's top says where
command labFail pWhere, pError
   local tLine, tError
   put item 2 of line 1 of pError into tLine
   try
      b2kStop
   catch tError
   end try
   if tLine is an integer and tLine > 0 then
      labSay "Stopped: an error in" && pWhere && "or a handler it called, at line" && tLine & ". Fix it, then press Reset.", true
   else
      labSay "Stopped: an error in" && pWhere & ". Fix it, then press Reset.", true
   end if
end labFail

########################################
#
# The line of words at the court's top
#

-- Called each frame, it changes at most five times a second, which is
-- as fast as anyone reads; with pNow, at once
command labSay pText, pNow
   if pText is sSaid then
      exit labSay
   end if
   if not pNow and the milliseconds - sSaidAt < 200 then
      exit labSay
   end if
   put pText into sSaid
   put the milliseconds into sSaidAt
   if there is a field "Readout" then
      put pText into field "Readout"
      labFitReadout
   end if
end labSay

private command labFitReadout
   local tMax, tLeft, tTop
   put the left of field "Readout" into tLeft
   put the top of field "Readout" into tTop
   put the width of graphic "Court" - 28 into tMax
   set the dontWrap of field "Readout" to true
   if the formattedWidth of field "Readout" > tMax then
      set the dontWrap of field "Readout" to false
      set the rect of field "Readout" to tLeft, tTop, tLeft + tMax, tTop + 40
   else
      set the rect of field "Readout" to tLeft, tTop, tLeft + max(1, the formattedWidth of field "Readout"), tTop + 40
   end if
   set the height of field "Readout" to the formattedHeight of field "Readout" + 4
   set the top of field "Readout" to tTop
   set the rect of graphic "ReadoutBg" to the left of field "Readout" - 6, tTop - 3, \
         the right of field "Readout" + 6, the bottom of field "Readout" + 3
   set the visible of graphic "ReadoutBg" to (field "Readout" is not empty)
end labFitReadout

-- A number to a few places, for the line of words
function labNum pNumber, pPlaces
   if pPlaces is empty then
      put 1 into pPlaces
   end if
   if pNumber is not a number then
      return pNumber
   end if
   return format("%." & pPlaces & "f", pNumber)
end labNum

########################################
#
# The mouse
#

-- A click in the court grabs what is under it, if it moves (b2kGrab),
-- and goes to the card's own mouseDown too. (b2kCamMouseX and
-- b2kCamMouseY are the mouse's place in the world: the same as the
-- mouseH and the mouseV, unless a camera has scrolled the world)
on mouseDown pButton
   local tError
   if sForwarding then
      exit mouseDown
   end if
   if pButton is 1 and sReady and not sPaused and the mouseLoc is within the rect of graphic "Court" then
      get b2kGrab(b2kCamMouseX(), b2kCamMouseY())
   end if
   if labOwns(the long id of the target) then
      put true into sForwarding
      try
         dispatch "mouseDown" to this card with pButton
      catch tError
         put false into sForwarding
         labFail "mouseDown", tError
         exit mouseDown
      end try
      put false into sForwarding
      exit mouseDown
   end if
   pass mouseDown
end mouseDown

private function labOwns pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if tObj is the long id of me then
         return true
      end if
      put the long id of the owner of tObj into tObj
   end repeat
   return false
end labOwns

on mouseUp pButton
   local tDo, tTarget
   labLetGo
   put the long id of the target into tTarget
   put labButtonDo(tTarget) into tDo
   if tDo is not empty and pButton is 1 then
      labRun tDo
   end if
   if the short name of the target is "Calls" then
      labExplain the value of the clickLine
   end if
   pass mouseUp
end mouseUp

on mouseRelease
   labLetGo
   pass mouseRelease
end mouseRelease

private command labLetGo
   local tError
   if sReady then
      try
         b2kRelease
      catch tError
      end try
   end if
end labLetGo

-- The wheel scrolls the words in the tabs (65308 down, 65309 up), though
-- they have no scrollbar
on rawKeyDown pKey
   local tStep, tField
   if pKey is 65308 or pKey is 65309 then
      repeat for each item tField in "Explain,Calls,CallDoc,TryCode"
         if there is a field tField and the visible of field tField and the mouseLoc is within the rect of field tField then
            put 3 * 17 into tStep
            if pKey is 65309 then
               put -tStep into tStep
            end if
            set the vScroll of field tField to max(0, the vScroll of field tField + tStep)
            exit rawKeyDown
         end if
      end repeat
   end if
   pass rawKeyDown
end rawKeyDown

########################################
#
# The buttons, the tabs, and the calls
#

private function labButtonDo pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if the cDo of tObj is not empty then
         return the cDo of tObj
      end if
      put the long owner of tObj into tObj
   end repeat
   return empty
end labButtonDo

-- Runs a button's handler: the card's, or the Lab's own (Reset, Pause,
-- Step, the tabs and the Code tab's buttons)
command labRun pHandler
   local tError
   if sCard is empty then
      exit labRun
   end if
   if pHandler begins with "lab" then
      dispatch pHandler to me
      exit labRun
   end if
   if not sReady then
      exit labRun
   end if
   -- (the screen is locked while the button runs: a control is made
   -- before it is sized and put in its place, and would flash at the
   -- card's middle in the meantime)
   lock screen
   try
      dispatch pHandler to sCard
   catch tError
      labFail pHandler, tError
   end try
   labShowButtons pHandler
   unlock screen
end labRun

########################################
#
# The card's buttons light up
#
# A button that switches something on or off (its group's cSwitch is
# true, from "switch" in the builder's buttons block) stays lit while
# what it switches is on: the card's function labLit, given the
# button's handler, says whether it is. Any other button lights up for
# a moment when it runs. The light is the group's graphics "<name>_lit"
# (a wash of the accent) and "<name>_ring" (its outline), hidden when
# the button is not lit.

-- After a button's handler ran (empty: after the lesson was made, or
-- the Code tab's lines ran): puts every switch's light right, and
-- flashes the button that ran, if it is not a switch
command labShowButtons pHandler
   local tIndex, tObj, tOn, tError
   if sCard is empty then
      exit labShowButtons
   end if
   repeat with tIndex = 1 to the number of groups of sCard
      put the long id of group tIndex of sCard into tObj
      if not (the short name of tObj begins with "Do") or the cDo of tObj is empty then
         next repeat
      end if
      if the cSwitch of tObj is true then
         put false into tOn
         try
            dispatch function "labLit" to sCard with the cDo of tObj
            put (the result is true) into tOn
         catch tError
         end try
         labLight tObj, tOn
      else if pHandler is not empty and the cDo of tObj is pHandler then
         labLight tObj, true
         put tObj into sFlashed
         send "labUnflash" to me in 180 milliseconds
      end if
   end repeat
end labShowButtons

-- The end of a button's flash
command labUnflash
   if sFlashed is not empty and exists(sFlashed) then
      labLight sFlashed, false
   end if
   put empty into sFlashed
end labUnflash

-- Lights a button of the card's, or puts its light out
command labLight pGroup, pOn
   local tName
   put the short name of pGroup into tName
   if there is a graphic (tName & "_lit") of pGroup then
      set the visible of graphic (tName & "_lit") of pGroup to pOn
      set the visible of graphic (tName & "_ring") of pGroup to pOn
   end if
end labLight

command labTabExplain
   labTab "Explain"
end labTabExplain

command labTabCode
   labTab "Code"
end labTabCode

command labTabCalls
   labTab "Calls"
end labTabCalls

-- Shows one tab's pane, and puts the bar under its name
private command labTab pTab
   local tTab
   if there is no field "TabExplain" then
      exit labTab
   end if
   lock screen
   repeat for each item tTab in "Explain,Code,Calls"
      set the visible of group ("Pane" & tTab) to (tTab is pTab)
      if tTab is pTab then
         set the textStyle of field ("Tab" & tTab) to "bold"
      else
         set the textStyle of field ("Tab" & tTab) to "plain"
      end if
   end repeat
   set the rect of graphic "TabBar" to the left of field ("Tab" & pTab) + 2, item 2 of the rect of graphic "TabBar", \
         the right of field ("Tab" & pTab) - 2, item 4 of the rect of graphic "TabBar"
   unlock screen
end labTab

-- The Code tab's Run: its lines, run as the Kit's handlers would be
-- run from a script of yours
command labRunCode
   local tError, tLine
   if not sReady then
      labSay "Nothing to run the lines in: press Reset first.", true
      exit labRunCode
   end if
   labPaintCode
   -- (locked while the lines run: a control they make would flash at the
   -- card's middle before it is put in its place)
   lock screen
   try
      do field "TryCode"
      labSay "Ran your lines.", true
      labShowButtons empty
   catch tError
      put item 2 of line 1 of tError into tLine
      if tLine is an integer and tLine > 0 then
         labSay "Your lines stopped at line" && tLine & ": check the spelling and the commas.", true
      else
         labSay "Your lines stopped: check the spelling and the commas.", true
      end if
   end try
   unlock screen
end labRunCode

command labCopyCode
   set the clipboardData["text"] to field "TryCode"
   labSay "Copied. Paste the lines into a script of yours.", true
end labCopyCode

command labResetCode
   put the cTry of field "TryCode" into field "TryCode"
   labPaintCode
   labSay "The lines are as they were.", true
end labResetCode

-- The Code tab's lines in the scripts drawer's colours: comments grey,
-- the Kit's handlers violet, the rest light
command labPaintCode
   local tIndex, tLine, tWord
   if there is no field "TryCode" then
      exit labPaintCode
   end if
   lock screen
   set the textColor of char 1 to -1 of field "TryCode" to empty
   repeat with tIndex = 1 to the number of lines of field "TryCode"
      put line tIndex of field "TryCode" into tLine
      if word 1 of tLine begins with "--" then
         set the textColor of line tIndex of field "TryCode" to "148,163,184"
         next repeat
      end if
      repeat with tWord = 1 to the number of words of tLine
         if word tWord of tLine begins with "b2k" then
            set the textColor of word tWord of line tIndex of field "TryCode" to "196,181,253"
         end if
      end repeat
   end repeat
   unlock screen
end labPaintCode

-- What a Kit handler in the calls list does, in full
command labExplain pName
   local tDocs, tDoc, tText
   -- (the words are one array in the custom property cDocs: read whole,
   -- then by name. "the cDocs[pName]" would ask a custom property SET)
   put the cDocs of me into tDocs
   put tDocs[pName] into tDoc
   if tDoc is empty then
      exit labExplain
   end if
   set the itemDelimiter to "|"
   put item 1 of tDoc & return & item 2 of tDoc & return & return & item 3 to -1 of tDoc into tText
   set the itemDelimiter to comma
   replace "\n" with return in tText
   put tText into field "CallDoc"
   set the textStyle of line 1 of field "CallDoc" to "bold"
   set the textFont of line 1 of field "CallDoc" to the textFont of field "TryCode"
   set the vScroll of field "CallDoc" to 0
end labExplain
