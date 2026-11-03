script "stack_Learn_Box2Dxt_Kit_card_id_1039"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Camera" (id 1039)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 09 Camera: a world bigger than the window
-- A level is often much wider than the window. The Kit's camera shows
-- part of it, and scrolls to keep the player in view.
--
--    b2kCamOn      a viewport: the rectangle of the card that shows the world
--    b2kCamBounds  how big the world is, so the camera stops at its edges
--    b2kCamFollow  which control to keep in view, and how smoothly
--    b2kCamShake   a shake, for a bump or a blast
--
-- With the camera on, places are places in the WORLD, not on the card.
-- The world's 0,0 is the top left corner of the viewport, before it
-- scrolls. This level is 1600 pixels wide and 378 high; the viewport
-- (the court, below the line of words) is 410 by 378. b2kCamMouseX and
-- b2kCamMouseY tell you where the mouse is in the world.

local sPlayer, sLoose, sDeadzone, sAuto

-- The Lab calls labWorld before labBuild. Handling it says "this card
-- makes its own walls": the world here is bigger than the court
on labWorld
   -- 1. The camera: the court, below its line of words, shows the world
   b2kCamOn "270,224,680,602"
   b2kCamBounds 0, 0, 1600, 378
   -- 2. The world's floor and its two ends: lines nothing passes through
   b2kWall 0, 378, 1600, 378
   b2kWall 0, -400, 0, 378
   b2kWall 1600, -400, 1600, 378
end labWorld

on labBuild
   local tIndex, tX
   -- 3. The level: ledges, each with a crate on it
   repeat for each line tIndex in "250,290,120" & return & "450,250,120" & return & "660,200,140" & return & \
         "910,280,120" & return & "1130,210,120" & return & "1370,140,160"
      b2kSpawnBox item 1 of tIndex, item 2 of tIndex, item 3 of tIndex, 16, "148,163,184"
      b2kSetStatic the result
      b2kSpawnBox item 1 of tIndex, item 2 of tIndex - 40, 30, 30, "180,120,60"
   end repeat
   -- (a marker every 200 pixels along the top, out of the player's
   -- reach, so that you see the world scroll by)
   repeat with tX = 200 to 1400 step 200
      b2kSpawnBox tX, 10, 4, 20, "71,85,105"
      b2kSetStatic the result
   end repeat
   -- 4. The player, as on the Player lesson, and the camera follows it
   b2kSheetFromImage "hero", the long id of image "AlienArt", 0, 0
   b2kSheetAddFrame "hero", "stand", 69, 379, 66, 92
   b2kSheetAddFrame "hero", "walk1", 69, 193, 68, 93
   b2kSheetAddFrame "hero", "walk2", 0, 0, 70, 96
   b2kSheetAddFrame "hero", "jump", 69, 286, 67, 93
   b2kSheetScale "hero", 0.6
   b2kAnimDef "hero", "idle", "stand", 1, true
   b2kAnimDef "hero", "run", "walk1,walk2", 8, true
   b2kAnimDef "hero", "jump", "jump", 1, true
   b2kPlayerMake 80, 320, 30, 54, "hero"
   put the result into sPlayer
   b2kPlayerAnims "idle", "run", "jump"
   b2kCamFollow sPlayer
   put false into sLoose
   put false into sDeadzone
   put false into sAuto
   b2kInputInjectOff
end labBuild

on labStep
   local tWhere, tView
   -- (b2kCamStatus says what is wrong, if the camera could not start)
   if b2kCamStatus() is not empty then
      labSay "The camera did not start:" && b2kCamStatus()
      exit labStep
   end if
   put b2kCamPos() into tView
   put b2kPosition(sPlayer) into tWhere
   labSay "the camera's middle: x" && item 1 of tView & ", y" && item 2 of tView & \
         "   the player: x" && round(item 1 of tWhere) & ", y" && round(item 2 of tWhere) && "(in the world)"
end labStep

-- (the arrow keys are the player's, so the card keeps them)
on arrowKey pKey
end arrowKey

on shake
   b2kCamShake 14, 500
end shake

-- Loose: the camera catches up slowly (0.04 of the way each frame)
on looseCamera
   put not sLoose into sLoose
   if sLoose then
      b2kCamFollow sPlayer, 0.04
   else
      b2kCamFollow sPlayer, 0.15
   end if
end looseCamera

-- Dead zone: the player can move about in a box in the middle before
-- the camera moves
on deadZone
   put not sDeadzone into sDeadzone
   if sDeadzone then
      b2kCamDeadzone 200, 120
   else
      b2kCamDeadzone 0, 0
   end if
end deadZone

-- Run by itself: the Kit can hold keys down for you (b2kInputInject),
-- which is how a demo, or a test, plays a game
on autoRun
   put not sAuto into sAuto
   if sAuto then
      b2kInputInject "right"
   else
      b2kInputInjectOff
   end if
end autoRun

on backToStart
   put false into sAuto
   b2kInputInjectOff
   b2kPlayerRespawn 80, 320
   b2kCamFollow sPlayer
   b2kCamGoto 80, 189
end backToStart

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "autoRun"
         return sAuto
      case "looseCamera"
         return sLoose
      case "deadZone"
         return sDeadzone
   end switch
   return false
end labLit
