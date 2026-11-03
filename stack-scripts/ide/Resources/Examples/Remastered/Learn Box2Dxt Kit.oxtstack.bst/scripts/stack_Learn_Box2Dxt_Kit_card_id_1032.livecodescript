script "stack_Learn_Box2Dxt_Kit_card_id_1032"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2Dxt Kit.oxtstack
-- Object: stack "Learn Box2Dxt Kit" > card "Controls" (id 1032)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- 02 Your Controls: physics for the buttons and graphics of a card
-- The Kit can give a body to a control you made: a button, a field, a
-- graphic or an image. b2kAddBox gives it a box the size of its
-- rectangle, b2kAddBall a circle as wide as it is, b2kAddPolygon the
-- outline of a polygon graphic's points, and b2kAddStatic a box that
-- never moves. From then on the Kit moves the control wherever Box2D
-- moves its body. Buttons and fields stay upright; graphics and images
-- turn as their bodies do.
--
-- The controls here are made by labBuild, so that Reset can make them
-- again; on a card of yours they would be there already.

local sShelf, sButton, sField, sBall, sTriangle, sMoving

on labBuild
   local tObj
   -- A shelf: a graphic with a body that never moves
   create graphic "Shelf"
   put it into sShelf
   set the style of sShelf to "rectangle"
   set the opaque of sShelf to true
   set the lineSize of sShelf to 0
   set the backgroundColor of sShelf to "148,163,184"
   set the rect of sShelf to 300, 440, 560, 454
   labKeep sShelf
   b2kAddStatic sShelf
   -- A button: a box body the size of its rectangle (true: it moves)
   create button "Press me"
   put it into sButton
   set the rect of sButton to 330, 220, 430, 252
   labKeep sButton
   b2kAddBox sButton, true
   -- A field
   create field "Hello"
   put it into sField
   set the text of sField to "Hello, world!"
   set the lockText of sField to true
   set the rect of sField to 470, 210, 590, 238
   labKeep sField
   b2kAddBox sField, true
   -- An oval graphic: a ball body, as wide as the graphic
   create graphic "Ball"
   put it into sBall
   set the style of sBall to "oval"
   set the opaque of sBall to true
   set the backgroundColor of sBall to "251,146,60"
   set the rect of sBall to 500, 260, 550, 310
   labKeep sBall
   b2kAddBall sBall, true
   -- A triangle: a polygon graphic, with a body of its own points
   create graphic "Triangle"
   put it into sTriangle
   set the style of sTriangle to "polygon"
   set the opaque of sTriangle to true
   set the backgroundColor of sTriangle to "167,139,250"
   set the points of sTriangle to "380,300" & return & "440,360" & return & "320,360" & return & "380,300"
   labKeep sTriangle
   b2kAddPolygon sTriangle, true
   put false into sMoving
end labBuild

on labStep
   local tWhere
   put b2kPosition(sButton) into tWhere
   labSay "button at" && round(item 1 of tWhere) & "," & round(item 2 of tWhere) && "  triangle" && round(b2kAngle(sTriangle)) & numToCodepoint(176) && \
         "  ball" && labNum(b2kMass(sBall), 2) && "kg   shelf:" && b2kBodyType(sShelf)
   -- (a moving shelf turns back before it reaches a wall)
   if sMoving then
      put b2kPosition(sShelf) into tWhere
      if item 1 of tWhere > 560 then
         b2kSetVelocity sShelf, -80, 0
      else if item 1 of tWhere < 390 then
         b2kSetVelocity sShelf, 80, 0
      end if
   end if
end labStep

-- The button still works as a button, while it falls. (Every other
-- click is passed on: the lesson's own buttons need it.)
on mouseUp
   if the long id of the target is sButton then
      labSay "You pressed the button. It still works, physics or not.", true
   end if
   pass mouseUp
end mouseUp

-- Lift them: every control back to the top, and still
on liftThem
   b2kMoveTo sButton, 380, 236, 0
   b2kMoveTo sField, 530, 224, 0
   b2kMoveTo sBall, 525, 285, 0
   b2kMoveTo sTriangle, 380, 300, 0
   b2kSetVelocity sButton, 0, 0
   b2kSetVelocity sField, 0, 0
   b2kSetVelocity sBall, 0, 0
   b2kSetVelocity sTriangle, 0, 0
end liftThem

-- Shelf moves: a kinematic body goes at the speed you give it, and
-- pushes what is on it; back to static, it stops
on moveShelf
   put not sMoving into sMoving
   if sMoving then
      b2kSetType sShelf, "kinematic"
      b2kSetVelocity sShelf, 80, 0
   else
      b2kSetType sShelf, "static"
   end if
end moveShelf

-- Heavy ball: the same size, ten times as dense, so ten times the mass
on heavyBall
   if b2kMass(sBall) < 3 then
      b2kSetDensity sBall, 10
   else
      b2kSetDensity sBall, 1
   end if
end heavyBall

-- Drop a box onto them
on dropBox
   b2kSpawnBox 360 + random(250), 220, 40, 40, "56,189,248"
end dropBox

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "moveShelf"
         return sMoving
      case "heavyBall"
         return b2kMass(sBall) >= 3
   end switch
   return false
end labLit
