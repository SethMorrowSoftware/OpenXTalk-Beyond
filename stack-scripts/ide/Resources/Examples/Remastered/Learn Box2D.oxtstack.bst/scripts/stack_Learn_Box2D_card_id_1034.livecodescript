script "stack_Learn_Box2D_card_id_1034"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Materials" (id 1034)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 04 Materials
-- Every shape has three numbers that say what it is made of:
--    density      kilograms per square metre: how heavy it is
--    friction     0 is ice; 1 or more grips
--    restitution  0 lands dead; 1 bounces back as high
-- Two shapes that touch mix their numbers: friction by the square root
-- of the two multiplied, restitution by the larger.

local sWorld, sRamp
-- The newest three balls of the bounce test, and until when the line at
-- the court's top keeps the masses Heavy and light put there
local sBalls, sHold

on labBuild
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- A ramp on the right: a static triangle, its friction 1
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into sRamp
   b2PolyBegin
   b2PolyAddPoint 0.2, 0
   b2PolyAddPoint 4.1, 0
   b2PolyAddPoint 4.1, 2.6
   get b2AddPolygon(sRamp, 1, 1, 0)
   labShow sRamp, "slate"
   bounceTest
   slideTest
   labStart sWorld
end labBuild

-- The Bounce test button: three balls, alike but for their restitution
on bounceTest
   put empty into sBalls
   dropBall -3.3, 0, "rose"
   dropBall -2.5, 0.5, "amber"
   dropBall -1.7, 0.9, "lime"
end bounceTest

private command dropBall pX, pBounce, pColor
   local tBody
   put b2NewBody(sWorld, 2, pX, 7, 0, false, false) into tBody
   get b2AddCircle(tBody, 0, 0, 0.3, 1, 0.3, pBounce)
   labShow tBody, pColor
   put tBody & "|" & pBounce & return after sBalls
end dropBall

-- Each step: how high each ball of the bounce test is, by its
-- restitution, so you can watch the bounces shrink
on labStep
   local tLine, tSay
   if the milliseconds < sHold then
      exit labStep
   end if
   set the itemDelimiter to "|"
   repeat for each line tLine in sBalls
      if labIsShown(item 1 of tLine) then
         put "    " & item 2 of tLine & ":" && labNum(b2BodyY(item 1 of tLine) - 0.3, 1) && "m" after tSay
      end if
   end repeat
   set the itemDelimiter to comma
   labSay "height by restitution" & tSay
end labStep

-- The Slide test button: three boxes on the ramp, alike but for their
-- friction: none, a little, and enough to hold
on slideTest
   setBox 3.5, 0, "rose"
   setBox 2.7, 0.2, "amber"
   setBox 1.9, 0.8, "lime"
end slideTest

-- A box resting on the ramp: turned to its slope, and lifted off it by
-- half its height
private command setBox pX, pFriction, pColor
   local tAngle, tY, tBody
   put atan2(2.6, 3.9) into tAngle
   put (pX - 0.2) * 2.6 / 3.9 into tY
   put b2NewBody(sWorld, 2, pX - 0.26 * sin(tAngle), tY + 0.26 * cos(tAngle), tAngle, false, false) into tBody
   get b2AddBox(tBody, 0.25, 0.25, 1, pFriction, 0)
   labShow tBody, pColor
end setBox

-- The Heavy and light button: two balls the same size, one 20 times
-- as dense, side by side on the floor; the heavy one is rolled into the
-- light one
on heavyLight
   local tHeavy, tLight
   put b2NewBody(sWorld, 2, -3.6, 0.4, 0, false, false) into tHeavy
   get b2AddCircle(tHeavy, 0, 0, 0.4, 10, 0.3, 0.2)
   labShow tHeavy, "violet"
   put b2NewBody(sWorld, 2, -1.2, 0.4, 0, false, false) into tLight
   get b2AddCircle(tLight, 0, 0, 0.4, 0.5, 0.3, 0.2)
   labShow tLight, "sky"
   b2SetVelocity tHeavy, 5, 0
   put the milliseconds + 3000 into sHold
   labSay "heavy:" && labNum(b2BodyMass(tHeavy), 1) && "kg    light:" && labNum(b2BodyMass(tLight), 1) && "kg", true
end heavyLight
