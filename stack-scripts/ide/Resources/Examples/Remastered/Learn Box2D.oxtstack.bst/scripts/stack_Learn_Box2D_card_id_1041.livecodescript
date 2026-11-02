script "stack_Learn_Box2D_card_id_1041"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Contacts" (id 1041)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 11 Contacts, Sensors and Filters
-- After each step, Box2D keeps lists of what happened in it:
--    contact events  which bodies began (and stopped) touching
--    hit events      a touch faster than the world's hit speed, and how fast
--    sensor events   which shapes came into (and left) a sensor
-- A sensor is a shape that notices what passes through it but stops
-- nothing. Filters say which shapes may collide: a shape belongs to
-- categories (bits) and collides with the categories in its mask.

local sWorld, sSensor, sBegins, sEnds, sInside, sHit

-- The categories: 1 the walls (Box2D's own), 2 red, 4 blue, 8 the shelf
constant kRed = 2
constant kBlue = 4
constant kShelf = 8

on labBuild
   local tShelf
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- The shelf collides with red balls only: its mask is kRed
   put b2NewBody(sWorld, 0, -2, 5, -0.15, false, false) into tShelf
   b2ShapeDefFilter kShelf, kRed, 0
   get b2AddBox(tShelf, 1.6, 0.1, 1, 0.3, 0)
   labShow tShelf, "rose"
   -- The sensor: a box that stops nothing. The b2ShapeDef... calls set
   -- up the NEXT shape made, and only it
   put b2NewBody(sWorld, 0, 1.2, 2.2, 0, false, false) into sSensor
   b2ShapeDefSensor true
   b2ShapeDefEnableSensorEvents true
   get b2AddBox(sSensor, 1.6, 0.7, 1, 0.5, 0)
   labShow sSensor, "teal"
   -- A hit event for any touch faster than 2 metres a second
   b2SetHitEventThreshold sWorld, 2
   put 0 into sBegins
   put 0 into sEnds
   put 0 into sInside
   put 0 into sHit
   dropRed
   dropBlue
   labStart sWorld
end labBuild

-- A ball, set up to make hit and sensor events, in a category and with a
-- mask
private command dropBall pX, pCategory, pMask, pColor
   local tBody
   put b2NewBody(sWorld, 2, pX, 8.2, 0, false, false) into tBody
   b2ShapeDefFilter pCategory, pMask, 0
   b2ShapeDefEnableHitEvents true
   b2ShapeDefEnableSensorEvents true
   get b2AddCircle(tBody, 0, 0, 0.25, 1, 0.4, 0.4)
   labShow tBody, pColor
end dropBall

-- The Drop red button: red collides with the walls, red, blue and the
-- shelf (1 + 2 + 4 + 8)
on dropRed
   dropBall -2.6 + random(20) / 10, kRed, 1 + kRed + kBlue + kShelf, "rose"
end dropRed

-- The Drop blue button: blue's mask leaves out the shelf, so it falls
-- through it
on dropBlue
   dropBall -2.6 + random(20) / 10, kBlue, 1 + kRed + kBlue, "sky"
end dropBlue

-- The Drop five button
on dropFive
   dropRed
   dropBlue
   dropRed
   dropBlue
   dropRed
end dropFive

on labStep
   local tIndex
   -- Contacts: each body that began touching another flashes
   get b2ContactsUpdate(sWorld)
   repeat with tIndex = 1 to b2ContactBeginCount()
      labFlash b2ContactBeginBodyA(tIndex)
      labFlash b2ContactBeginBodyB(tIndex)
   end repeat
   add b2ContactBeginCount() to sBegins
   add b2ContactEndCount() to sEnds
   -- Hits: the speed of the last one
   repeat with tIndex = 1 to b2ContactHitCount()
      put b2ContactHitSpeed(tIndex) into sHit
   end repeat
   -- The sensor: how many are in it now, and green while any are
   get b2SensorsUpdate(sWorld)
   add b2SensorBeginCount() - b2SensorEndCount() to sInside
   if sInside > 0 then
      labTint sSensor, "lime"
   else
      labTint sSensor, "teal"
   end if
   labSay "touches began:" && sBegins && " ended:" && sEnds && "   last hit" && labNum(sHit, 1) && "m/s" & \
         "   in the sensor:" && sInside
end labStep
