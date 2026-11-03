script "stack_Learn_Box2D_card_id_1042"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Rays" (id 1042)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 12 Ray Casts and Queries
-- You can ask the world questions:
--    b2CastRayClosest  what does a line from here to there hit first?
--    b2RayCastAll      everything along the line, nearest first
--    b2BodyAtPoint     which body is at this point? (how a click picks)
--    b2OverlapCircle   which shapes are in this circle?
-- The answers are read with b2Ray... and b2Query... after the question.

local sWorld, sAll, sSweep, sAngle, sFound

on labBuild
   local tBody, tIndex
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- Things for the ray to hit: two static, and a heap of dynamic
   put b2NewBody(sWorld, 0, 1.5, 4.5, 0.4, false, false) into tBody
   get b2AddBox(tBody, 0.9, 0.15, 1, 0.5, 0)
   labShow tBody, "slate"
   put b2NewBody(sWorld, 0, -1, 6.5, 0, false, false) into tBody
   get b2AddCircle(tBody, 0, 0, 0.5, 1, 0.5, 0)
   labShow tBody, "slate"
   repeat with tIndex = 1 to 8
      addShape
   end repeat
   put false into sAll
   put true into sSweep
   put 0 into sAngle
   put 0 into sFound
   labStart sWorld
end labBuild

-- The Add shapes button
on addShape
   local tBody
   put b2NewBody(sWorld, 2, random(70) / 10 - 3, 6 + random(20) / 10, 0, false, false) into tBody
   if random(2) is 1 then
      get b2AddBox(tBody, 0.3, 0.3, 1, 0.5, 0.1)
      labShow tBody, "amber"
   else
      get b2AddCircle(tBody, 0, 0, 0.3, 1, 0.5, 0.1)
      labShow tBody, "violet"
   end if
end addShape

-- The Closest / All button
on switchRay
   put not sAll into sAll
end switchRay

-- The Follow mouse button: the ray points at the mouse, or sweeps
on switchAim
   put not sSweep into sSweep
end switchAim

-- A click on empty space: which shapes are within a metre of it?
on mouseDown pButton
   local tX, tY, tIndex
   put labMouseX() into tX
   put labMouseY() into tY
   if pButton is 1 and b2BodyAtPoint(sWorld, tX, tY) is 0 and the mouseLoc is within the rect of graphic "Court" then
      get b2OverlapCircle(sWorld, tX, tY, 1)
      put b2QueryCount() into sFound
      repeat with tIndex = 1 to sFound
         labFlash b2QueryBody(tIndex)
      end repeat
   end if
   pass mouseDown
end mouseDown

-- Each step: a ray from the bottom left corner, 15 metres long
on labStep
   local tX1, tY1, tX2, tY2, tAngle, tIndex, tCount
   put -3.9 into tX1
   put 0.2 into tY1
   if sSweep then
      add 0.01 to sAngle
      put pi / 4 + sin(sAngle) * pi / 4.2 into tAngle
   else
      put atan2(labMouseY() - tY1, labMouseX() - tX1) into tAngle
   end if
   put tX1 + 15 * cos(tAngle) into tX2
   put tY1 + 15 * sin(tAngle) into tY2
   if not sAll then
      repeat with tIndex = 2 to 12
         labDot "hit" & tIndex, 0, 0, empty
      end repeat
      if b2CastRayClosest(sWorld, tX1, tY1, tX2, tY2) then
         -- The hit point, and the surface's normal there (which way it faces)
         labLine "ray", tX1, tY1, b2RayX(), b2RayY(), "rose"
         labLine "normal", b2RayX(), b2RayY(), b2RayX() + b2RayNormalX() * 0.6, b2RayY() + b2RayNormalY() * 0.6, "lime"
         labDot "hit1", b2RayX(), b2RayY(), "white", 10
         labSay "hit at" && labNum(b2RayX(), 2) & "," && labNum(b2RayY(), 2) && "  " & \
               round(b2RayFraction() * 100) & "% along the ray   normal" && labNum(b2RayNormalX(), 2) & "," && \
               labNum(b2RayNormalY(), 2) & "   a click found" && sFound && "shapes"
      else
         labLine "ray", tX1, tY1, tX2, tY2, "rose"
         labLine "normal", 0, 0, 0, 0, empty
         labDot "hit1", 0, 0, empty
      end if
   else
      -- Every hit: a dot at each
      labLine "normal", 0, 0, 0, 0, empty
      labLine "ray", tX1, tY1, tX2, tY2, "rose"
      get b2RayCastAll(sWorld, tX1, tY1, tX2, tY2)
      put min(12, b2QueryCount()) into tCount
      repeat with tIndex = 1 to 12
         if tIndex <= tCount then
            labDot "hit" & tIndex, b2QueryX(tIndex), b2QueryY(tIndex), "white", 10
         else
            labDot "hit" & tIndex, 0, 0, empty
         end if
      end repeat
      labSay "the ray goes through" && b2QueryCount() && "shapes   a click found" && sFound && "shapes"
   end if
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "switchRay"
         return sAll
      case "switchAim"
         return not sSweep
   end switch
   return false
end labLit
