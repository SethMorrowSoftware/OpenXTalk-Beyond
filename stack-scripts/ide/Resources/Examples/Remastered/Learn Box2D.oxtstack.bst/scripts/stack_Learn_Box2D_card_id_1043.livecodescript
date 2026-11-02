script "stack_Learn_Box2D_card_id_1043"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Terrain" (id 1043)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 13 Terrain, Blasts and Sleep
-- A chain is a line of many segments, made for ground: smooth, so that
-- things roll over its joins without catching. It is one-sided: it
-- stops things on the side its normals face, and lets them through from
-- the other. b2WorldExplode pushes every body near a point away from it.
-- A body that has been still for a moment falls asleep: Box2D stops
-- moving it until something wakes it. Here sleeping bodies turn grey.

local sWorld, sColors, sSleeping, sBlast

on labBuild
   local tGround, tX, tPoints, tPoint, tPath
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- The hills: points from right to left, so that the chain's normals face up.
   -- The first and the last are ghosts: they only shape the ends
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tGround
   -- (in tenths of a metre, 4.4 down to -4.4: a "step" in a repeat with
   -- is not kept by every engine, so the loop counts down for itself)
   put 44 into tX
   repeat while tX >= -44
      put tX / 10 & "," & 1.6 + 0.7 * sin(tX / 10 * 1.4) + 0.3 * sin(tX / 10 * 3.1) & return after tPoints
      subtract 4 from tX
   end repeat
   delete the last char of tPoints
   b2ChainBegin
   repeat for each line tPoint in tPoints
      b2ChainAddPoint item 1 of tPoint, item 2 of tPoint
   end repeat
   get b2CreateChain(tGround, false, 0.7, 0)
   -- (labShow cannot read a chain back: the lab draws the points, but the ghosts)
   put line 2 to -2 of tPoints into tPath
   labPath "hills", tPath, "slate"
   put empty into sColors
   put empty into sSleeping
   dropTen
   labStart sWorld
end labBuild

-- The Drop ten button
on dropTen
   local tIndex, tBody, tColor
   repeat with tIndex = 1 to 10
      put b2NewBody(sWorld, 2, random(70) / 10 - 3.5, 7 + random(15) / 10, 0, false, false) into tBody
      if random(2) is 1 then
         get b2AddCircle(tBody, 0, 0, 0.22, 1, 0.5, 0.2)
         put "sky" into tColor
      else
         get b2AddBox(tBody, 0.22, 0.22, 1, 0.5, 0.1)
         put "amber" into tColor
      end if
      labShow tBody, tColor
      put tColor into sColors[tBody]
   end repeat
end dropTen

-- A blast at a point: bodies within 2.5 metres are pushed away, less
-- the further they are (falloff), by 4 units of impulse per metre of
-- their outline
private command blast pX, pY
   b2WorldExplode sWorld, pX, pY, 2.5, 1.5, 4
   labDot "blast", pX, pY, "orange", 40
   put the milliseconds into sBlast
end blast

-- A click on empty space sets off a blast there
on mouseDown pButton
   if pButton is 1 and the mouseLoc is within the rect of graphic "Court" and \
         b2BodyAtPoint(sWorld, labMouseX(), labMouseY()) is 0 then
      blast labMouseX(), labMouseY()
   end if
   pass mouseDown
end mouseDown

-- The Big blast button: one under the middle
on bigBlast
   blast 0, 1.5
end bigBlast

-- The Wake all button
on wakeAll
   local tBody
   repeat for each item tBody in labBodies()
      b2SetAwake tBody, true
   end repeat
end wakeAll

-- The Sleep on/off button: with sleeping off, nothing ever sleeps
on toggleSleep
   b2EnableSleeping sWorld, not b2IsSleepingEnabled(sWorld)
end toggleSleep

-- Each step: sleeping bodies grey, awake ones in their colour, and the
-- world's counts
on labStep
   local tBody, tAwake
   repeat for each item tBody in labBodies()
      put b2BodyIsAwake(tBody) into tAwake
      if tAwake and sSleeping[tBody] is true then
         labTint tBody, sColors[tBody]
         put false into sSleeping[tBody]
      else if not tAwake and sSleeping[tBody] is not true then
         labTint tBody, "dim"
         put true into sSleeping[tBody]
      end if
   end repeat
   if sBlast is not empty and the milliseconds - sBlast > 150 then
      labDot "blast", 0, 0, empty
      put empty into sBlast
   end if
   b2WorldCountersUpdate sWorld
   b2WorldProfileUpdate sWorld
   labSay "bodies" && b2WorldBodyCount() && "  awake" && b2AwakeBodyCount(sWorld) && "  contacts" && \
         b2WorldContactCount() && "  step" && labNum(b2WorldProfileStep(), 2) && "ms   sleeping on:" && \
         b2IsSleepingEnabled(sWorld)
end labStep
