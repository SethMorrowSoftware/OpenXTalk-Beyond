script "stack_Learn_Box2Dxt_Kit_card_id_1042"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Terrain" (id 1042)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 12 Terrain and Rays: hills, holes, and seeing what is there
-- Ground in a game is rarely flat. b2kSmoothGround makes a smooth
-- ground from a list of points: a chain of lines with no corners for
-- fast things to catch on. It is invisible, so the card draws a graphic
-- with the same points. A chain is solid on one side only: list the
-- points from right to left, and the top is solid.
--
-- b2kKillFloor takes away what falls below a line: here, into the pit.
-- The Kit sends b2kFell before it does.
--
-- A ray (b2kRayHit) is a line the world is asked about: what does it hit
-- first, where, and how far away? Games use rays for lasers, line of
-- sight, and whether a character stands on something. b2kOverlapCircle
-- asks what is inside a circle.

local sFell, sLaser, sBeam, sDot

on labBuild
   local tRight, tLeft
   -- 1. Two hills with a pit between them. Each list runs right to
   --    left; its first and last lines are "ghosts" that only steer the
   --    ends, so each runs one point past the ground you see
   put "700,420" & return & "680,420" & return & "630,470" & return & "580,480" & return & \
         "530,450" & return & "524,610" & return & "520,640" into tRight
   put "470,640" & return & "466,610" & return & "460,440" & return & "400,470" & return & \
         "340,450" & return & "290,450" & return & "270,450" & return & "250,450" into tLeft
   b2kSmoothGround tRight
   b2kSmoothGround tLeft
   drawHill "HillRight", line 2 to -2 of tRight
   drawHill "HillLeft", line 2 to -2 of tLeft
   -- 2. Anything that falls below 570 (into the pit) goes
   b2kKillFloor 570
   put 0 into sFell
   -- 3. The laser's beam and the dot where it hits
   put true into sLaser
   create graphic "Beam"
   put it into sBeam
   set the style of sBeam to "line"
   set the foregroundColor of sBeam to "244,63,94"
   set the lineSize of sBeam to 2
   labKeep sBeam
   create graphic "Dot"
   put it into sDot
   set the style of sDot to "oval"
   set the opaque of sDot to true
   set the lineSize of sDot to 0
   set the backgroundColor of sDot to "244,63,94"
   set the rect of sDot to 0, 0, 10, 10
   labKeep sDot
   dropBalls
end labBuild

-- A hill as a filled shape: its points, then down to the floor
private command drawHill pName, pPoints
   local tObj
   create graphic pName
   put it into tObj
   set the style of tObj to "polygon"
   set the opaque of tObj to true
   set the lineSize of tObj to 0
   set the backgroundColor of tObj to "52,211,153"
   set the points of tObj to pPoints & return & item 1 of line -1 of pPoints & ",602" & return & \
         item 1 of line 1 of pPoints & ",602" & return & line 1 of pPoints
   labKeep tObj
end drawHill

-- Each frame: the laser, from the top left of the court towards the
-- mouse (or down the slope, when the mouse is not in the court), and on
-- for 1000 pixels
on labStep
   local tX, tY, tHit, tWords, tLength
   if the mouseLoc is within the rect of graphic "Court" and the mouseLoc is not "290,240" then
      put the mouseH into tX
      put the mouseV into tY
   else
      put 640 into tX
      put 560 into tY
   end if
   put sqrt((tX - 290) ^ 2 + (tY - 240) ^ 2) into tLength
   put round(290 + (tX - 290) * 1000 / tLength) into tX
   put round(240 + (tY - 240) * 1000 / tLength) into tY
   if not sLaser then
      set the points of sBeam to empty
      hide sDot
      labSay "fell into the pit:" && sFell
      exit labStep
   end if
   put b2kRayHit(290, 240, tX, tY) into tHit
   if b2kRayHitX() is empty then
      set the points of sBeam to "290,240" & return & tX & "," & tY
      hide sDot
      put "the laser hits nothing" into tWords
   else
      set the points of sBeam to "290,240" & return & b2kRayHitX() & "," & b2kRayHitY()
      set the loc of sDot to b2kRayHitX(), b2kRayHitY()
      show sDot
      if tHit is empty then
         put "the laser hits the ground or a wall" into tWords
      else
         put "the laser hits a" && word 1 of tHit into tWords
      end if
      put " at" && b2kRayHitX() & "," & b2kRayHitY() & "," && round(b2kRayDist()) && "pixels away" after tWords
   end if
   labSay tWords & "   fell into the pit:" && sFell
end labStep

-- The Kit sends this just before it takes something below the kill
-- floor away
on b2kFell pControl
   add 1 to sFell
end b2kFell

on dropBalls
   local tIndex
   repeat with tIndex = 1 to 5
      b2kSpawnBall 300 + random(360), 240, 20 + random(16), "251,146,60"
   end repeat
end dropBalls

on dropBoxes
   local tIndex
   repeat with tIndex = 1 to 3
      b2kSpawnBox 300 + random(360), 240, 30, 30, "56,189,248"
   end repeat
end dropBoxes

-- Who is near? Everything inside a circle in the middle of the court
-- jumps
on whoIsNear
   local tObj
   repeat for each line tObj in b2kOverlapCircle(475, 420, 110)
      b2kPush tObj, 0, -400
   end repeat
end whoIsNear

on laser
   put not sLaser into sLaser
end laser

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "laser"
         return sLaser
   end switch
   return false
end labLit
