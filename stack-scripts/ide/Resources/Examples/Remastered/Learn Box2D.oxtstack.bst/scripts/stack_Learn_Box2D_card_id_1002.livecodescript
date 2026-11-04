script "stack_Learn_Box2D_card_id_1002"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "Start" (id 1002)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- The front page: a little Box2D world in the banner, the same way every
-- lesson works. Make a world with b2NewWorld, put bodies in it, then step
-- it with b2Step about 60 times a second and draw each body where Box2D
-- says it is. Shapes rain onto a spinning paddle and pile up; a click in
-- the banner blasts them apart with b2WorldExplode.

-- Pixels to a metre, and how many shapes are kept at once
constant kScale = 22
constant kMost = 26

-- The world, the loop's number (closing the card changes it, so a step
-- already on its way stops), the stack, the paddle, every body and its
-- graphic and outline (in metres), the order they came in, and the toy's
-- middle and floor in pixels
local sWorld, sGen, sStack, sPaddle, sGraphic, sOutline, sOrder, sTicks, sOX, sOY

on openCard
   frontStart
   pass openCard
end openCard

on closeCard
   frontStop
   pass closeCard
end closeCard

on closeStack
   frontStop
   pass closeStack
end closeStack

command frontStart
   local tError, tGround
   frontStop
   if there is no group "Toy" then
      exit frontStart
   end if
   -- (without Box2Dxt the banner just stays still)
   try
      if b2Version() is not 4 then
         exit frontStart
      end if
   catch tError
      exit frontStart
   end try
   put the short name of this stack into sStack
   put item 1 of the loc of group "Toy" into sOX
   put the bottom of group "Toy" - 4 into sOY
   put b2NewWorld(0, -10, true, true) into sWorld
   -- A floor and two walls, from one static body
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tGround
   get b2AddSegment(tGround, -4.9, 0, 4.9, 0, 0.6, 0)
   get b2AddSegment(tGround, -4.9, 0, -4.9, 30, 0.6, 0)
   get b2AddSegment(tGround, 4.9, 0, 4.9, 30, 0.6, 0)
   -- The paddle: a kinematic body, turned at a speed it is given, which
   -- pushes dynamic bodies and is never pushed back
   put b2NewBody(sWorld, 1, 0, 2.7, 0, false, false) into sPaddle
   get b2AddBox(sPaddle, 1.7, 0.1, 1, 0.4, 0.2)
   b2SetAngularVelocity sPaddle, -1.1
   frontAdd sPaddle, "-1.7,-0.1" & return & "1.7,-0.1" & return & "1.7,0.1" & return & "-1.7,0.1", 0
   put 0 into sTicks
   add 1 to sGen
   send ("frontTick" && sGen) to me in 0 milliseconds
end frontStart

command frontStop
   local tBody
   add 1 to sGen
   if sWorld is not empty then
      b2DestroyWorld sWorld
   end if
   put empty into sWorld
   lock messages
   repeat for each key tBody in sGraphic
      if there is a graphic id sGraphic[tBody] then
         delete graphic id sGraphic[tBody]
      end if
   end repeat
   unlock messages
   put empty into sGraphic
   put empty into sOutline
   put empty into sOrder
end frontStop

on frontTick pGen
   local tStart, tError
   if pGen is not sGen or sWorld is empty then
      exit frontTick
   end if
   -- (while the window is hidden, or made an icon, the toy waits)
   if the visible of stack sStack is false or the iconic of stack sStack then
      send ("frontTick" && pGen) to me in 250 milliseconds
      exit frontTick
   end if
   put the milliseconds into tStart
   -- (a message sent in time runs with whichever stack is in front)
   set the defaultStack to sStack
   lock screen
   try
      b2Step sWorld, 1/60, 4
      add 1 to sTicks
      if sTicks mod 18 is 1 then
         frontRain
      end if
      frontDraw
   catch tError
      -- (a world that went wrong stops; the banner stays as it is)
      unlock screen
      add 1 to sGen
      exit frontTick
   end try
   unlock screen
   send ("frontTick" && pGen) to me in max(1, 16 - (the milliseconds - tStart)) milliseconds
end frontTick

-- One more shape from the top: a ball, a box or a triangle, at random.
-- When there are too many, the oldest goes
private command frontRain
   local tBody, tX, tSize, tKind, tOutline, tIndex
   put (random(81) - 41) / 10 into tX
   put 0.22 + random(16) / 100 into tSize
   put random(3) into tKind
   put b2NewBody(sWorld, 2, tX, 8.4, random(628) / 100, false, false) into tBody
   switch tKind
      case 1
         get b2AddCircle(tBody, 0, 0, tSize, 1, 0.4, 0.45)
         repeat with tIndex = 0 to 15
            put tSize * cos(tIndex * pi / 8) & "," & tSize * sin(tIndex * pi / 8) & return after tOutline
         end repeat
         break
      case 2
         get b2AddBox(tBody, tSize, tSize, 1, 0.5, 0.2)
         put -tSize & "," & -tSize & return & tSize & "," & -tSize & return & tSize & "," & tSize & return & -tSize & "," & tSize & return into tOutline
         break
      default
         b2PolyBegin
         b2PolyAddPoint -tSize * 1.2, -tSize
         b2PolyAddPoint tSize * 1.2, -tSize
         b2PolyAddPoint 0, tSize * 1.1
         get b2AddPolygon(tBody, 1, 0.5, 0.2)
         put -tSize * 1.2 & "," & -tSize & return & tSize * 1.2 & "," & -tSize & return & 0 & "," & tSize * 1.1 & return into tOutline
   end switch
   delete the last char of tOutline
   frontAdd tBody, tOutline, item random(3) of "0,30,55"
   if the number of items of sOrder > kMost then
      put item 1 of sOrder into tBody
      delete item 1 of sOrder
      lock messages
      delete graphic id sGraphic[tBody]
      unlock messages
      delete variable sGraphic[tBody]
      delete variable sOutline[tBody]
      b2DestroyBody tBody
   end if
end frontRain

-- A body's graphic: white, more or less see-through
private command frontAdd pBody, pOutline, pBlend
   local tId, tPoint
   lock messages
   create graphic in group "Toy"
   put the id of it into tId
   set the style of graphic id tId to "polygon"
   set the antialiased of graphic id tId to true
   set the filled of graphic id tId to true
   set the backgroundColor of graphic id tId to "255,255,255"
   set the foregroundColor of graphic id tId to "255,255,255"
   set the lineSize of graphic id tId to 1
   set the blendLevel of graphic id tId to pBlend
   unlock messages
   put tId into sGraphic[pBody]
   -- (in pixels: kScale times the metres)
   repeat for each line tPoint in pOutline & return & line 1 of pOutline
      put item 1 of tPoint * kScale & "," & item 2 of tPoint * kScale & return after sOutline[pBody]
   end repeat
   delete the last char of sOutline[pBody]
   if pBody is not sPaddle then
      if sOrder is empty then
         put pBody into sOrder
      else
         put comma & pBody after sOrder
      end if
   end if
end frontAdd

-- Each body where Box2D says it is: its outline turned by its angle and
-- moved to its place, in pixels (y goes up in Box2D, down here). A body
-- asleep on the pile has not moved since it was drawn, and is left as it
-- is
private command frontDraw
   local tBody, tX, tY, tAngle, tCos, tSin, tPoint, tPixels
   repeat for each key tBody in sGraphic
      if not b2BodyIsAwake(tBody) then
         next repeat
      end if
      put sOX + b2BodyX(tBody) * kScale into tX
      put sOY - b2BodyY(tBody) * kScale into tY
      put b2BodyAngle(tBody) into tAngle
      put cos(tAngle) into tCos
      put sin(tAngle) into tSin
      put empty into tPixels
      repeat for each line tPoint in sOutline[tBody]
         put round(tX + tCos * item 1 of tPoint - tSin * item 2 of tPoint) & "," & \
               round(tY - tSin * item 1 of tPoint - tCos * item 2 of tPoint) & return after tPixels
      end repeat
      delete the last char of tPixels
      set the points of graphic id sGraphic[tBody] to tPixels
   end repeat
end frontDraw

-- A click in the banner: a blast where it is, which pushes every body
-- near it away. "Learn Box2Dxt Kit" opens that example, which is beside
-- this one
on mouseUp pButton
   if pButton is 1 and the long name of the target contains "group " & quote & "OtherStack" & quote then
      openOther
      exit mouseUp
   end if
   if pButton is 1 and the mouseLoc is within the rect of group "hero" then
      frontBlast the mouseH, the mouseV
   end if
   pass mouseUp
end mouseUp

command openOther
   local tPath
   set the itemDelimiter to slash
   put item 1 to -2 of the effective filename of this stack & "/Learn Box2Dxt Kit.oxtstack" into tPath
   set the itemDelimiter to comma
   if there is a file tPath then
      go stack tPath
   else if there is a stack "Learn Box2Dxt Kit" then
      go stack "Learn Box2Dxt Kit"
   else
      answer "Learn Box2Dxt Kit is with the other examples: open it from Home, under Examples."
   end if
end openOther

-- A blast at a point of the card: b2WorldExplode pushes every body within
-- 3 metres of it away, hardest at the middle
command frontBlast pH, pV
   if sWorld is not empty then
      b2WorldExplode sWorld, (pH - sOX) / kScale, (sOY - pV) / kScale, 3, 2, 3
   end if
end frontBlast
