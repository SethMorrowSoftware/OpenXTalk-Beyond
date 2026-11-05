script "oxtwebideidle"
-- How much of the computer the web IDE takes while nobody uses it: a tour
-- for tools/ci/web_ide_tour.py --tour, which puts this file into a copy
-- of the site's ide.zip as a script library extension, as it does
-- web-ide-tour.livecodescript, and speaks the same lines with the page
-- (that file's header lists them), with one more:
--
--    ACT <id> cpu <name> <seconds> <budget>
--
-- for which the page measures how busy the browser's main thread is for
-- <seconds> (Chromium's DevTools protocol, Performance.getMetrics'
-- TaskDuration: the engine, its timers and its drawing all run there),
-- logs it as a percentage of one core, and fails the check when it is
-- above <budget>. A browser without the protocol logs "not measured".
--
--    python3 tools/ci/web_ide_tour.py --site SITE --out OUT \
--       --tour tools/ci/web-ide-idle.livecodescript
--
-- On 0.2.7-rc.6.14 (seth, 2026-11-04: "about half a CPU core while
-- idle") the IDE alone took 0.1% of a core; all the rest was Home's
-- animated welcome (palettes/web home), 38% of a core in front at 1x
-- (72% at 2x), and 10% for as long as it stayed open behind the user's
-- own stacks (as much as in front when the user had never clicked Home);
-- Home's Examples took 33% in front. The steps:
--
--    pictures   Home's four drifting lights are pictures on the web
--               (hmOrbPicture), and each draws the same pixels as the
--               gradient graphic it stands for, at its place, within
--               kTolerance of 255 in every channel: the lights' gradients,
--               drawn again every frame, were two fifths of Home's frame
--    front      Home in front, as the IDE opens: its animations run (the
--               budget only catches a runaway; the number is in the log)
--    behind     a stack of the user's in front of Home: Home holds still
--               and looks twice a second whether it is back in use
--    back       Home's title bar clicked: Home moves again
--    learn      Home's Examples (Learn's gallery): the lights of its
--               banner are pictures, as Home's (revLearnKit), it moves in
--               front, and the main thread's work there is logged
--    alone      Home closed: the IDE with nothing moving
--
-- A step that throws fails. The budgets have room for a slower runner
-- than the one they were measured on (0.5% behind, 0.1% alone).

/**
Title: Web IDE idle check (CI)
Author: OXT-Beyond contributors
Description:
Measures how busy the web IDE keeps the browser while nobody uses it, for
its CI job (tools/ci/web_ide_tour.py --tour). Only CI's copy of the site
has it.
*/

constant kSteps = "pictures,front,behind,back,learn,alone"
constant kSample = "Web Idle Sample"
constant kSeconds = 12
constant kFrontBudget = 85
constant kBehindBudget = 5
constant kAloneBudget = 5
constant kTolerance = 3

local sStarted, sAct, sWatchdog

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   if sStarted is not true and tourJS("typeof window.oxtTour") is "object" then
      put true into sStarted
      send "tourWhenStarted 0" to me in 1 second
   end if
end extensionInitialize

on tourWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then
      put the cREVLaunching of stack "Home" into tLaunching
   end if
   if (tLaunching is true or tourJS("window.oxtTour.go") is not "true") and pTries < 600 then
      send "tourWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      -- (Home's lights and pages have slid in, and the IDE's deferred
      -- messages have run, before anything is measured)
      send "tourRun" to me in 5 seconds
   end if
end tourWhenStarted

on tourRun
   local tStep, tHandler, tError, tOnly
   put 0 into sAct
   put tourJS("window.oxtTour.only") into tOnly
   tourRecord "STARTED"
   tourRecord "INFO version" && the version && the buildNumber
   tourRecord "INFO platform" && the platform && the environment
   tourRecord "INFO openStacks" && tourJoin(the openStacks)
   tourCatchErrors
   repeat for each item tStep in kSteps
      if tOnly is not empty and tStep is not among the items of tOnly then
         next repeat
      end if
      put "idle_" & tStep into tHandler
      send "tourWatchdog" && quote & tStep & quote to me in 60 seconds
      put the result into sWatchdog
      try
         dispatch tHandler to me
         tourRecord "STEP" && tStep && "ok"
      catch tError
         tourRecord "STEP" && tStep && "FAILED" && tourJoin(tError)
      end try
      cancel sWatchdog
   end repeat
   tourRecord "INFO openStacks at the end" && tourJoin(the openStacks)
   tourRecord "DONE"
end tourRun

command tourCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      put the defaultStack into tDefault
      set the defaultStack to "oxtwebideidle"
      lock messages
      create invisible button "oxt_web_idle_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "tourScriptError" & quote & " to stack " & quote & "oxtwebideidle" & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      tourRecord "INFO catching errors:" && tourJoin(tError)
   end try
end tourCatchErrors

on tourScriptError pError
   tourRecord "ERROR" && tourJoin(pError)
end tourScriptError

----------------------------------------------------------------
-- Steps

-- Each light's picture against the graphic it stands for: both drawn at
-- the picture's place, one after the other, with no wait between (so
-- Home draws no frame between them and nothing else has moved)
on idle_pictures
   local tHome
   put idleHome() into tHome
   if tHome is empty then
      throw "Home is not open:" && tourJoin(the openStacks)
   end if
   idleCheckLights tHome, "heroOrb", "Home's light"
end idle_pictures

-- Home's Examples (Learn's gallery, revLearn): the lights of its banner
-- are pictures too (revLearnKit's lkGlowPicture), drawn with the
-- graphics' blend; it moves in front, where its work is logged, and
-- holds still behind the user's stack as Home does (lkTick)
on idle_learn
   local tHome
   put idleHome() into tHome
   if tHome is empty or tHome is not "revHub" then
      throw "OXT-Beyond Home is not open:" && tourJoin(the openStacks)
   end if
   dispatch "revHubShow" to stack tHome with "examples"
   tourWait 4000
   idleCheckLights tHome, "p_heroGlow", "Examples' light"
   if not idleMoving(tHome, "p_heroGlow1Pic") then
      throw "Examples in front holds still"
   end if
   tourAct "cpu examples-front" && kSeconds && kFrontBudget
   -- (the user's stack clicked in front of it: it holds still)
   if there is a stack kSample then
      go stack kSample
      tourWait 500
      tourAct "click" && item 1 of the loc of stack kSample && item 2 of the loc of stack kSample
      tourWait 1500
      tourRecord "INFO active window" && idleActiveWindow()
      if idleMoving(tHome, "p_heroGlow1Pic") then
         throw "Examples behind the user's stack still moves"
      end if
      tourAct "cpu examples-behind" && kSeconds && kBehindBudget
   end if
   dispatch "revHubShow" to stack tHome with "home"
   tourWait 2000
end idle_learn

-- Each light's picture against the graphic it stands for (pPrefix<n> and
-- pPrefix<n>Pic of stack pStack): both drawn at the picture's place, one
-- after the other, with no wait between (so no frame is drawn between
-- them and nothing else has moved), the graphic with its gradient
-- centred on it as the stacks centre it
command idleCheckLights pStack, pPrefix, pWhat
   local tIndex, tPic, tGraphic, tRect, tA, tB, tWorst, tDiff
   put 0 into tWorst
   repeat with tIndex = 1 to 4
      if there is not an image (pPrefix & tIndex & "Pic") of stack pStack then
         throw pWhat && tIndex && "is not a picture (" & pPrefix & tIndex & "Pic)"
      end if
      put the long id of image (pPrefix & tIndex & "Pic") of stack pStack into tPic
      put the long id of graphic (pPrefix & tIndex) of stack pStack into tGraphic
      if the visible of tGraphic then
         throw pWhat && tIndex && "is drawn twice: its graphic is still shown"
      end if
      if the blendLevel of tPic is not the blendLevel of tGraphic then
         throw pWhat && tIndex & "'s picture has the blend" && the blendLevel of tPic & ", its graphic" && the blendLevel of tGraphic
      end if
      put the rect of tPic into tRect
      put idleShot(pStack, tRect) into tA
      lock messages
      set the rect of tGraphic to tRect
      set the fillGradient["from"] of tGraphic to the loc of tGraphic
      set the fillGradient["to"] of tGraphic to (item 1 of the loc of tGraphic + the width of tGraphic div 2) & comma & item 2 of the loc of tGraphic
      set the fillGradient["via"] of tGraphic to item 1 of the loc of tGraphic & comma & (item 2 of the loc of tGraphic + the width of tGraphic div 2)
      show tGraphic
      hide tPic
      unlock messages
      put idleShot(pStack, tRect) into tB
      lock messages
      hide tGraphic
      show tPic
      unlock messages
      put idleCompare(tA, tB) into tDiff
      tourRecord "INFO" && pWhat && tIndex && "at" && tRect & ":" && tDiff && "at most apart"
      put max(tWorst, tDiff) into tWorst
   end repeat
   if tWorst > kTolerance then
      throw pWhat & "'s picture differs from its gradient by" && tWorst && "(at most" && kTolerance & ")"
   end if
end idleCheckLights

on idle_front
   local tHome
   put idleHome() into tHome
   if tHome is empty then
      throw "Home is not open:" && tourJoin(the openStacks)
   end if
   go stack tHome
   tourWait 1500
   tourRecord "INFO active window" && idleActiveWindow()
   if not idleMoving(tHome) then
      throw "Home in front holds still"
   end if
   tourAct "cpu home-front" && kSeconds && kFrontBudget
end idle_front

-- A stack of the user's, clicked as a user brings a window to the front,
-- in front of a Home that never had the keyboard (so it never heard
-- suspendStack: before 0.2.7-rc.6.15 it went on at sixty frames a second
-- there)
on idle_behind
   local tDefault, tHome
   put idleHome() into tHome
   if there is a stack kSample then
      delete stack kSample
   end if
   put the defaultStack into tDefault
   create stack kSample
   set the rect of stack kSample to 400, 200, 800, 500
   set the defaultStack to tDefault
   go stack kSample
   tourWait 500
   tourAct "click" && item 1 of the loc of stack kSample && item 2 of the loc of stack kSample
   tourWait 1500
   tourRecord "INFO active window" && idleActiveWindow()
   if tHome is not empty and idleMoving(tHome) then
      throw "Home behind the user's stack still moves"
   end if
   tourAct "cpu home-behind" && kSeconds && kBehindBudget
end idle_behind

-- Home's title bar clicked: Home in front again moves again
on idle_back
   local tHome
   put idleHome() into tHome
   if tHome is empty then
      throw "Home is not open:" && tourJoin(the openStacks)
   end if
   -- (the page's title bar, 31 high, above the window: revWebIDEKeepOnPage)
   tourAct "click" && item 1 of the rect of stack tHome + 200 && item 2 of the rect of stack tHome - 15
   tourWait 1500
   tourRecord "INFO active window" && idleActiveWindow()
   if not idleMoving(tHome) then
      throw "Home brought to the front again holds still"
   end if
end idle_back

on idle_alone
   local tHome
   if there is a stack kSample then
      close stack kSample
      delete stack kSample
   end if
   put idleHome() into tHome
   if tHome is not empty then
      close stack tHome
   end if
   tourWait 2000
   tourRecord "INFO openStacks" && tourJoin(the openStacks)
   tourAct "cpu ide-alone" && kSeconds && kAloneBudget
end idle_alone

----------------------------------------------------------------
-- Helpers

-- The open stack that has Home's welcome: OXT-Beyond Home (revHub, from
-- 0.2.7-rc.6.12, with revWebHome as its behavior) or revWebHome's own
-- window before it
function idleHome
   local tName
   repeat for each item tName in "revHub,revWebHome"
      if tName is among the lines of the openStacks and there is a group "hero" of stack tName then
         return tName
      end if
   end repeat
   return empty
end idleHome

-- Whether a light of Home (pPicture, Home's welcome's first by default)
-- moves within a little over a second
function idleMoving pHome, pPicture
   local tBefore
   if pPicture is empty then
      put "heroOrb1Pic" into pPicture
   end if
   if there is not an image pPicture of stack pHome then
      return false
   end if
   put the rect of image pPicture of stack pHome into tBefore
   tourWait 1200
   return the rect of image pPicture of stack pHome is not tBefore
end idleMoving

-- The title of the page's window that has the keyboard, and its classes
function idleActiveWindow
   return tourJS("(function(){var a=document.querySelector('.oxt-window-active');" & \
         "if(!a)return 'none';var l=a.querySelector('.oxt-window-label');" & \
         "return (l?l.textContent:'?')+' ('+a.className+')';})()")
end idleActiveWindow

-- The imageData of pRect of stack pStack's card, as it draws it now
function idleShot pStack, pRect
   local tDefault, tData
   put the defaultStack into tDefault
   set the defaultStack to pStack
   import snapshot from rect pRect of this card
   put the imageData of it into tData
   delete it
   set the defaultStack to tDefault
   return tData
end idleShot

-- The largest difference of a channel between two imageDatas of a size
-- (255 when their sizes differ), looked at in every third pixel
function idleCompare pA, pB
   local tCount, tPixel, tByte, tChannel, tDiff, tMax
   if the number of bytes of pA is 0 or the number of bytes of pB is not the number of bytes of pA then
      return 255
   end if
   put 0 into tMax
   put the number of bytes of pA div 4 into tCount
   repeat with tPixel = 0 to tCount - 1 step 3
      repeat with tChannel = 2 to 4
         put tPixel * 4 + tChannel into tByte
         put abs(byteToNum(byte tByte of pA) - byteToNum(byte tByte of pB)) into tDiff
         if tDiff > tMax then
            put tDiff into tMax
         end if
      end repeat
   end repeat
   return tMax
end idleCompare

command tourWait pMilliseconds
   wait pMilliseconds milliseconds with messages
end tourWait

-- An action of the page (web_ide_tour.py's act), waited for: a measure
-- takes its seconds, so the wait is as long, and it looks only twice a
-- second, so that the tour itself costs next to nothing while it waits
command tourAct pAction
   local tId, tDeadline
   add 1 to sAct
   put sAct into tId
   tourRecord "ACT" && tId && pAction
   put the milliseconds + 20000 into tDeadline
   if word 1 of pAction is "cpu" and word 3 of pAction is a number then
      add word 3 of pAction * 1000 to tDeadline
   end if
   repeat until tourJS("window.oxtTour.done") >= tId or the milliseconds > tDeadline
      wait 500 milliseconds with messages
   end repeat
end tourAct

on tourWatchdog pStep
   tourRecord "INFO" && pStep && "still running after 60 s; open stacks:" && tourJoin(the openStacks)
end tourWatchdog

command tourRecord pLine
   get tourJS("window.oxtTour.record(" & tourString(pLine) & ")")
end tourRecord

-- The value of the JavaScript expression pExpression in the page
function tourJS pExpression
   do pExpression as "JavaScript"
   return the result
end tourJS

-- pText as a JavaScript string
function tourString pText
   replace "\" with "\\" in pText
   replace "'" with "\'" in pText
   replace return with "\n" in pText
   replace numToChar(13) with "\r" in pText
   return "'" & pText & "'"
end tourString

function tourJoin pText
   replace return with " | " in pText
   return pText
end tourJoin
