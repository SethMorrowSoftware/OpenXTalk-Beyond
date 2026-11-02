script "stack_Learn_Box2D_card_id_1032"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Bodies" (id 1032)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 02 Body Types
-- A body is a thing in the world: where it is, which way it turns, and
-- how it moves. Its type says how it moves:
--    0  static     never moves (floors, walls, shelves)
--    1  kinematic  moves at the speed you give it, and nothing stops it
--    2  dynamic    gravity, forces and collisions move it
-- Bodies have no size or form of their own: their shapes give them that.

local sWorld, sShelf, sLift

on labBuild
   local tIndex
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- A static shelf, at the left: b2NewBody's second number is the type
   put b2NewBody(sWorld, 0, -2.6, 3.2, 0, false, false) into sShelf
   get b2AddBox(sShelf, 1.2, 0.12, 1, 0.6, 0)
   labShow sShelf, "slate"
   -- A kinematic platform that slides to and fro: it keeps the speed
   -- b2SetVelocity gives it (in metres per second), whatever hits it
   put b2NewBody(sWorld, 1, 1.5, 1.8, 0, false, false) into sLift
   get b2AddBox(sLift, 1, 0.12, 1, 0.8, 0)
   b2SetVelocity sLift, 1.5, 0
   labShow sLift, "violet"
   -- Dynamic boxes, to land on both
   repeat with tIndex = 1 to 3
      dropBox
   end repeat
   labStart sWorld
end labBuild

-- Each step: the platform turns back at either end of its run
on labStep
   local tType
   if b2BodyX(sLift) > 2.8 and b2BodyVX(sLift) > 0 then
      b2SetVelocity sLift, -1.5, 0
   else if b2BodyX(sLift) < -0.2 and b2BodyVX(sLift) < 0 then
      b2SetVelocity sLift, 1.5, 0
   end if
   -- And where the mouse is, in metres: x across from the middle of the
   -- floor, y up from it
   put item (b2BodyType(sShelf) + 1) of "static,kinematic,dynamic" into tType
   labSay "mouse at x" && labNum(labMouseX(), 2) && "m, y" && labNum(labMouseY(), 2) && "m" & \
         "    the shelf is" && tType
end labStep

-- The Drop a box button
on dropBox
   local tBody
   put b2NewBody(sWorld, 2, random(60) / 10 - 3, 7.5, 0, false, false) into tBody
   get b2AddBox(tBody, 0.3, 0.3, 1, 0.6, 0.1)
   labShow tBody, "amber"
end dropBox

-- The Shelf type button: the shelf becomes dynamic (and falls), then
-- kinematic, then static again
on shelfType
   switch b2BodyType(sShelf)
      case 0
         b2SetBodyType sShelf, 2
         labTint sShelf, "amber"
         break
      case 2
         -- (a kinematic body with no speed hangs where it is)
         b2SetBodyType sShelf, 1
         b2SetVelocity sShelf, 0, 0
         b2SetAngularVelocity sShelf, 0
         labTint sShelf, "violet"
         break
      default
         b2SetBodyType sShelf, 0
         labTint sShelf, "slate"
   end switch
   b2SetAwake sShelf, true
end shelfType

-- The Spin platform button: a kinematic body turns, too, at the speed
-- in radians per second that b2SetAngularVelocity gives it
on spinLift
   if b2BodyAngularVelocity(sLift) is 0 then
      b2SetAngularVelocity sLift, 1.2
   else
      b2SetAngularVelocity sLift, 0
      b2SetTransform sLift, b2BodyX(sLift), b2BodyY(sLift), 0
   end if
end spinLift
