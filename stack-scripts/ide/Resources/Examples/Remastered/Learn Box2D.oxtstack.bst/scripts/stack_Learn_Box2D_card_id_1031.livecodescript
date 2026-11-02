script "stack_Learn_Box2D_card_id_1031"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "World" (id 1031)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 01 The World
-- Everything in Box2D lives in a world. b2NewWorld makes one, with a
-- gravity; bodies go into it; and the world moves them forward in time,
-- a step at a time. The Lab (see its chip) calls b2Step 60 times a
-- second, and draws each body where Box2D says it is.

local sWorld, sGravity

-- The Lab runs labBuild when the card opens, and when Reset is pressed
on labBuild
   local tGround, tIndex
   -- A world. Gravity is 0 across and -10 up and down: Box2D's y goes UP,
   -- so -10 is 10 metres per second per second, down. The first true
   -- lets bodies that have stopped moving fall asleep (they cost nothing
   -- then); the second keeps fast bodies from passing through walls
   put b2NewWorld(0, -10, true, true) into sWorld
   put "down" into sGravity
   -- The floor and the walls: a static body (type 0) at 0,0, with three
   -- segment shapes along the court's edges. A segment is a line with
   -- no inside; its last two numbers are its friction and bounce
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tGround
   get b2AddSegment(tGround, -4.1, 0, 4.1, 0, 0.6, 0)
   get b2AddSegment(tGround, -4.1, 0, -4.1, 30, 0.6, 0)
   get b2AddSegment(tGround, 4.1, 0, 4.1, 30, 0.6, 0)
   -- Things to fall: they start in the air, and gravity does the rest
   repeat with tIndex = 1 to 4
      dropBall
      dropBox
   end repeat
   -- The world goes to the Lab, which steps it and draws it
   labStart sWorld
end labBuild

-- The Drop a ball button: a dynamic body (type 2), high up, with a
-- circle shape 0.3 metres in radius. A dynamic body is one that gravity,
-- forces and collisions move
on dropBall
   local tBody
   put b2NewBody(sWorld, 2, random(64) / 10 - 3.2, 8, 0, false, false) into tBody
   -- density 1, friction 0.4, bounce (restitution) 0.4
   get b2AddCircle(tBody, 0, 0, 0.3, 1, 0.4, 0.4)
   labShow tBody, "sky"
end dropBall

-- The Drop a box button: a box 0.7 metres square (b2AddBox takes half
-- its width and half its height), at an angle in radians
on dropBox
   local tBody
   put b2NewBody(sWorld, 2, random(64) / 10 - 3.2, 8, random(314) / 100, false, false) into tBody
   get b2AddBox(tBody, 0.35, 0.35, 1, 0.5, 0.1)
   labShow tBody, "amber"
end dropBox

-- The Change gravity button: down, then sideways, then up, then none
on changeGravity
   local tBody
   switch sGravity
      case "down"
         put "sideways" into sGravity
         b2SetGravity sWorld, 8, -4
         break
      case "sideways"
         put "up" into sGravity
         b2SetGravity sWorld, 0, 6
         break
      case "up"
         put "off" into sGravity
         b2SetGravity sWorld, 0, 0
         break
      default
         put "down" into sGravity
         b2SetGravity sWorld, 0, -10
   end switch
   -- A body that has fallen asleep does not notice a new gravity: wake
   -- every one
   repeat for each item tBody in labBodies()
      b2SetAwake tBody, true
   end repeat
end changeGravity

-- The Lab runs labStep after every step of the world
on labStep
   labSay "gravity" && b2WorldGravityX(sWorld) & "," && b2WorldGravityY(sWorld) && "m/s/s  (" & sGravity & ")" & \
         "   bodies awake:" && b2AwakeBodyCount(sWorld)
end labStep
