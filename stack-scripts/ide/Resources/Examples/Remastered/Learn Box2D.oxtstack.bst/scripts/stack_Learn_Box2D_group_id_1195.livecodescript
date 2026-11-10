script "stack_Learn_Box2D_group_id_1195"
-- Stack file: ide/Resources/Examples/Remastered/Learn Box2D.oxtstack
-- Object: stack "Learn Box2D" > card "World" (id 1031) > group "Lab" (id 1195)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- The Lab: what every lesson of Learn Box2D shares. It is the script of
-- the group "Lab", a background on each lesson card, with the court the
-- bodies move in, the line of numbers at its top and the Reset, Pause
-- and Step buttons. A card's own script makes a world and its bodies with
-- Box2D's handlers (the b2... ones), and hands the world to labStart. From
-- then on, the lab:
--
--    steps the world 60 times a second, with b2Step (labTick)
--    calls the card's labStep after each step, if it has one
--    draws every body labShow was given, where Box2D says it is
--    lets you grab a body and throw it, with a mouse joint (labGrab)
--    destroys the world when the card closes (labClose)
--
-- Box2D works in metres, seconds and radians, with y going UP. The court
-- is 50 pixels to a metre, with 0,0 in the middle of its floor: x runs
-- from -4.1 at the left wall to 4.1 at the right, and y from 0 at the
-- floor to 8.8 at the top. labPX, labPY, labMX and labMY turn one into
-- the other.

constant kScale = 50
-- How long one step of the world is, in seconds, and how many smaller
-- steps Box2D's solver takes inside it (4 is what Box2D suggests)
constant kStep = 0.016666667
constant kSubSteps = 4

-- The world of the card in front, its card and stack, and the loop's
-- number: closing a card changes it, so a step already on its way stops
local sWorld, sCard, sStack, sGen
-- True while the Pause button holds the world still
local sPaused
-- What labShow draws: the graphics of each body (sBodies[body] is their
-- ids), each graphic's points around its body (in pixels, made from
-- metres once, when it is shown), where and at what angle each body was
-- last drawn, the points each graphic was last given, and the colour
-- each graphic is drawn in
local sBodies, sPoints, sPose, sDrawn, sColor
-- The joints labShowJoint draws, the lines and dots labLine and labDot
-- draw, and the bodies labFlash lit, with when they go back
local sJoints, sMarks, sFlash
-- The button of the card's that is lit for a moment (labShowButtons),
-- and the card's switches, after the card's long id (labSwitchLights)
local sFlashed, sLightTicks, sSwitches
-- The card being opened, until labOpenNow makes its lesson
local sOpening
-- What each joint labShowJoint draws holds: its second body and the two
-- points it holds, each around its own body (they never change; its line's
-- points are sDrawn["joint" & the joint])
local sJointInfo
-- True when the window was hidden or made an icon: the world waited,
-- and is drawn whole when it is back
local sHidden
-- The mouse joint that holds a body you drag, and the static body it is
-- tied to
local sDrag, sDragGround
-- When the line at the court's top last changed, and what it says
local sSaidAt, sSaid
-- True while a click in the court is handed to the card's mouseDown
local sForwarding
-- Each card's ready-made words for the calls list, and the court's middle
-- and floor, in pixels
local sOriginX, sOriginY

########################################
#
# The card opens and closes
#

-- The card opens: the sign that the lesson is being made shows first,
-- and the lesson is made a moment later, when the window has drawn the
-- card and the sign. (Made at once, the card stays blank until it is
-- ready.) A card left before then is not made
on openCard
   labLoading true
   put the long id of this card into sOpening
   send "labOpenNow" to me in 20 milliseconds
   pass openCard
end openCard

command labOpenNow
   if sOpening is not the long id of this card then
      exit labOpenNow
   end if
   put empty into sOpening
   labOpen
   labLoading false
end labOpenNow

-- Shows, or takes away, the sign that the lesson is being made, with the
-- busy pointer
command labLoading pOn
   if there is a group "LabLoading" then
      set the visible of group "LabLoading" to pOn
   end if
   if pOn then
      lock cursor
      set the cursor to busy
   else
      unlock cursor
   end if
end labLoading

on closeCard
   labClose
   pass closeCard
end closeCard

on closeStack
   labClose
   pass closeStack
end closeStack

-- Makes the card's world: its script's labBuild makes it, and its
-- labStart hands it to the loop
command labOpen
   local tError
   labClose
   put the long id of this card into sCard
   put the short name of this stack into sStack
   put item 1 of the loc of graphic "Court" into sOriginX
   put the bottom of graphic "Court" into sOriginY
   put false into sPaused
   labPauseLabel
   put "Click a call to see what it does." into field "CallDoc"
   if not labReady() then
      labSay "Box2D is not loaded. Turn on Box2Dxt in Tools > Extension Manager, then open this card again.", true
      exit labOpen
   end if
   try
      dispatch "labBuild" to sCard
   catch tError
      labFail "labBuild", tError
   end try
   labShowButtons empty
end labOpen

-- True when the Box2Dxt extension is loaded: its b2Version() is 4
function labReady
   local tError
   try
      return b2Version() is 4
   catch tError
      return false
   end try
end labReady

-- Starts the loop with a world the card made
command labStart pWorld
   put pWorld into sWorld
   add 1 to sGen
   send ("labTick" && sGen) to me in 0 milliseconds
end labStart

-- Stops the loop, destroys the world and everything in it, and takes
-- away what was drawn
command labClose
   local tId
   add 1 to sGen
   if sWorld is not empty then
      -- (every body, shape and joint in it goes too)
      b2DestroyWorld sWorld
   end if
   put empty into sWorld
   put empty into sDrag
   put empty into sDragGround
   lock screen
   lock messages
   repeat for each element tId in sMarks
      labDelete tId
   end repeat
   repeat for each element tId in sJoints
      labDelete tId
   end repeat
   repeat for each key tId in sPoints
      labDelete tId
   end repeat
   unlock messages
   unlock screen
   put empty into sBodies
   put empty into sPoints
   put empty into sPose
   put empty into sDrawn
   put empty into sColor
   put empty into sJoints
   put empty into sJointInfo
   put false into sHidden
   put empty into sMarks
   put empty into sFlash
   put empty into sSaid
   if sStack is not empty and there is a field "Readout" of sCard then
      put empty into field "Readout" of sCard
   end if
   if there is a graphic "ReadoutBg" then
      hide graphic "ReadoutBg"
   end if
end labClose

private command labDelete pId
   if there is a graphic id pId then
      delete graphic id pId
   end if
end labDelete

########################################
#
# The loop
#

-- One step of the world: b2Step moves every body 1/60 of a second, the
-- card's labStep does what it does each step, and every body that moved
-- is drawn again. Then it sends itself, to run again in what is left of
-- 16 milliseconds, so about 60 times a second.
-- Paused, nothing moves, so nothing is drawn: it only lets go of a body
-- the mouse let go of, and puts out the bodies labFlash lit, 20 times a
-- second. (A button pressed while paused draws what it changed: labRun)
-- While the window is hidden, or made an icon, the world waits, as if
-- paused, and is drawn again whole when the window is back
on labTick pGen
   local tStart, tError
   if pGen is not sGen or sWorld is empty then
      exit labTick
   end if
   if the visible of stack sStack is false or the iconic of stack sStack then
      put true into sHidden
      send ("labTick" && pGen) to me in 250 milliseconds
      exit labTick
   end if
   put the milliseconds into tStart
   -- (a step sent in milliseconds runs in whichever stack is in front:
   -- the graphics this draws are on this stack's card)
   set the defaultStack to sStack
   lock screen
   try
      if not sPaused then
         labStepOnce
      else
         labDrag
         labFlashesOut
      end if
   catch tError
      unlock screen
      labFail "labStep", tError
      exit labTick
   end try
   unlock screen
   if sPaused then
      send ("labTick" && pGen) to me in 50 milliseconds
   else
      send ("labTick" && pGen) to me in max(1, 16 - (the milliseconds - tStart)) milliseconds
   end if
end labTick

-- What the Step button does, and what each tick does when it runs
command labStepOnce
   labDrag
   b2Step sWorld, kStep, kSubSteps
   dispatch "labStep" to sCard
   labDraw
   -- (the arrow keys can switch things too: the lights follow, five
   -- times a second)
   add 1 to sLightTicks
   if sLightTicks mod 12 is 0 then
      labSwitchLights
   end if
end labStepOnce

-- The Reset button: the card made again from the start
command labRestart
   labOpen
end labRestart

-- The Pause button
command labTogglePause
   put not sPaused into sPaused
   labPauseLabel
end labTogglePause

-- The Step button: one step, and paused after it
command labStepButton
   if sWorld is empty then
      exit labStepButton
   end if
   put true into sPaused
   labPauseLabel
   lock screen
   labStepOnce
   unlock screen
end labStepButton

private command labPauseLabel
   if there is a field "LabPause_label" then
      if sPaused then
         put "Play" into field "LabPause_label"
      else
         put "Pause" into field "LabPause_label"
      end if
   end if
end labPauseLabel

-- When a handler of the card stops with an error, the loop stops, and
-- the line at the court's top says where
command labFail pWhere, pError
   local tLine
   add 1 to sGen
   put item 2 of line 1 of pError into tLine
   if tLine is an integer and tLine > 0 then
      labSay "Stopped: an error in" && pWhere && "or a handler it called, at line" && tLine & ". Fix it, then press Reset.", true
   else
      labSay "Stopped: an error in" && pWhere & ". Fix it, then press Reset.", true
   end if
end labFail

########################################
#
# Metres and pixels
#

-- A pixel across the card, as metres across the world, and back
function labMX pPixelX
   return (pPixelX - sOriginX) / kScale
end labMX

function labMY pPixelY
   return (sOriginY - pPixelY) / kScale
end labMY

function labPX pMetresX
   return round(sOriginX + pMetresX * kScale)
end labPX

function labPY pMetresY
   return round(sOriginY - pMetresY * kScale)
end labPY

-- The court's size in metres: 8.2 across, 8.8 high
function labWidth
   return the width of graphic "Court" / kScale
end labWidth

function labHeight
   return the height of graphic "Court" / kScale
end labHeight

-- Where the mouse is, in metres
function labMouseX
   return labMX(the mouseH)
end labMouseX

function labMouseY
   return labMY(the mouseV)
end labMouseY

-- Where the mouse was pressed, in metres: the clickLoc, kept from the
-- press itself. A press is handled a moment after it is made, and on a
-- busy machine the mouse may have moved on by then, so a mouseDown that
-- asks where the mouse is now can miss what was pressed
function labClickX
   return labMX(the clickH)
end labClickX

function labClickY
   return labMY(the clickV)
end labClickY

-- A number with pPlaces decimals, for the line at the court's top
function labNum pNumber, pPlaces
   return format("%." & pPlaces & "f", pNumber)
end labNum

########################################
#
# Walls
#

-- The floor and the two side walls, as most cards have them: one static
-- body with three segment shapes, along the court's edges. The walls go
-- on up above the court, so that nothing falls out over them
function labWalls pWorld
   local tBody, tHalf
   put labWidth() / 2 into tHalf
   put b2NewBody(pWorld, 0, 0, 0, 0, false, false) into tBody
   get b2AddSegment(tBody, -tHalf, 0, tHalf, 0, 0.6, 0)
   get b2AddSegment(tBody, -tHalf, 0, -tHalf, 30, 0.6, 0)
   get b2AddSegment(tBody, tHalf, 0, tHalf, 30, 0.6, 0)
   return tBody
end labWalls

########################################
#
# Drawing
#

-- Draws a body: a graphic for each of its shapes, which follows it from
-- then on. pColor is one of sky, amber, rose, lime, violet, teal, orange,
-- white, slate or ground
command labShow pBody, pColor
   local tCount, tIndex, tShapes, tShape, tPoints, tId
   put b2BodyShapeCount(pBody) into tCount
   repeat with tIndex = 1 to tCount
      put b2BodyShapeAt(tIndex) & comma after tShapes
   end repeat
   -- (locked until the body is drawn where it is: a new graphic shows at
   -- the card's middle until then)
   lock screen
   lock messages
   repeat for each item tShape in tShapes
      put labShapePoints(tShape) into tPoints
      if tPoints is empty then
         next repeat
      end if
      put labNewGraphic(b2ShapeType(tShape) is 2, pColor) into tId
      put labScaled(tPoints) into sPoints[tId]
      put pColor into sColor[tId]
      put tId & comma after sBodies[pBody]
   end repeat
   unlock messages
   labDrawBody pBody, true
   unlock screen
end labShow

-- Takes a body out of the world, and its graphics off the card
command labForget pBody
   local tId
   if labIsShown(pBody) then
      lock messages
      repeat for each item tId in sBodies[pBody]
         labDelete tId
         delete variable sPoints[tId]
         delete variable sDrawn[tId]
         delete variable sColor[tId]
      end repeat
      unlock messages
      delete variable sBodies[pBody]
      delete variable sPose[pBody]
   end if
   b2DestroyBody pBody
end labForget

function labIsShown pBody
   return pBody is among the keys of sBodies
end labIsShown

-- The ids of the graphics labShow drew for a body, a comma between each
function labGraphics pBody
   if labIsShown(pBody) then
      return item 1 to -1 of sBodies[pBody]
   end if
   return empty
end labGraphics

-- Every body labShow drew, a comma between each
function labBodies
   local tList
   put the keys of sBodies into tList
   replace return with comma in tList
   return tList
end labBodies

-- Gives a body's graphics another colour, until labTint gives it another
command labTint pBody, pColor
   local tId
   if not labIsShown(pBody) then
      exit labTint
   end if
   repeat for each item tId in sBodies[pBody]
      put pColor into sColor[tId]
      labPaint tId, pColor
   end repeat
end labTint

-- Lights a body up white for a moment
command labFlash pBody
   local tId
   if not labIsShown(pBody) then
      exit labFlash
   end if
   put the milliseconds + 160 into sFlash[pBody]
   repeat for each item tId in sBodies[pBody]
      labPaint tId, "white"
   end repeat
end labFlash

-- Draws a joint as a dashed line between the points it holds together
-- (or, for a hinge or a wheel, from body to body through its pin), and
-- keeps it there
command labShowJoint pJoint
   local tId
   lock messages
   create graphic in group "Bodies"
   put the id of it into tId
   set the style of graphic id tId to "line"
   set the foregroundColor of graphic id tId to "226,232,240"
   set the lineSize of graphic id tId to 2
   set the dashes of graphic id tId to "5,4"
   set the antialiased of graphic id tId to true
   set the points of graphic id tId to "0,0" & return & "1,1"
   unlock messages
   put tId into sJoints[pJoint]
   put b2JointBodyB(pJoint) & "," & b2JointLocalAnchorAX(pJoint) & "," & b2JointLocalAnchorAY(pJoint) & "," & \
         b2JointLocalAnchorBX(pJoint) & "," & b2JointLocalAnchorBY(pJoint) into sJointInfo[pJoint]
   labDrawJoint pJoint
end labShowJoint

-- Stops drawing a joint (destroy it with b2DestroyJoint)
command labHideJoint pJoint
   if pJoint is among the keys of sJoints then
      labDelete sJoints[pJoint]
      delete variable sJoints[pJoint]
      delete variable sJointInfo[pJoint]
      delete variable sDrawn["joint" & pJoint]
   end if
end labHideJoint

-- A line, named, from one point to another (in metres): made the first
-- time, moved after. An empty pColor hides it
command labLine pName, pX1, pY1, pX2, pY2, pColor
   local tId, tLook
   put labMark(pName, "line") into tId
   if pColor is empty then
      put empty into tLook
   else
      put pColor & "|" & labPX(pX1) & "," & labPY(pY1) & return & labPX(pX2) & "," & labPY(pY2) into tLook
   end if
   -- (called every step: a line just as it was is left alone)
   if tLook is sDrawn["mark" & tId] then
      exit labLine
   end if
   put tLook into sDrawn["mark" & tId]
   if pColor is empty then
      hide graphic id tId
      exit labLine
   end if
   set the itemDelimiter to "|"
   set the foregroundColor of graphic id tId to labRGB(pColor)
   set the points of graphic id tId to item 2 of tLook
   set the itemDelimiter to comma
   show graphic id tId
end labLine

-- A dot, named, at a point (in metres), pSize pixels across
command labDot pName, pX, pY, pColor, pSize
   local tId, tX, tY, tR
   put labMark(pName, "oval") into tId
   if pColor is empty then
      put empty into tX
   else
      put labPX(pX) into tX
      put labPY(pY) into tY
      put max(1, pSize div 2) into tR
   end if
   -- (called every step: a dot just as it was is left alone)
   if pColor & "|" & tX & "|" & tY & "|" & tR is sDrawn["mark" & tId] then
      exit labDot
   end if
   put pColor & "|" & tX & "|" & tY & "|" & tR into sDrawn["mark" & tId]
   if pColor is empty then
      hide graphic id tId
      exit labDot
   end if
   set the backgroundColor of graphic id tId to labRGB(pColor)
   set the rect of graphic id tId to tX - tR, tY - tR, tX + tR, tY + tR
   show graphic id tId
end labDot

-- A path, named, through points (in metres, "x,y" a line), drawn once:
-- for a chain, which labShow cannot read back
command labPath pName, pPoints, pColor
   local tId, tPoint, tPixels
   put labMark(pName, "line") into tId
   put empty into sDrawn["mark" & tId]
   repeat for each line tPoint in pPoints
      put labPX(item 1 of tPoint) & "," & labPY(item 2 of tPoint) & return after tPixels
   end repeat
   delete the last char of tPixels
   set the foregroundColor of graphic id tId to labRGB(pColor)
   set the lineSize of graphic id tId to 3
   set the points of graphic id tId to tPixels
   show graphic id tId
end labPath

private function labMark pName, pStyle
   local tId
   if pName is among the keys of sMarks then
      if there is a graphic id sMarks[pName] then
         return sMarks[pName]
      end if
   end if
   lock messages
   create graphic in group "Bodies"
   put the id of it into tId
   set the style of graphic id tId to pStyle
   set the antialiased of graphic id tId to true
   set the lineSize of graphic id tId to 2
   set the opaque of graphic id tId to (pStyle is "oval")
   if pStyle is "oval" then
      set the lineSize of graphic id tId to 0
   end if
   set the points of graphic id tId to "0,0" & return & "1,1"
   unlock messages
   put tId into sMarks[pName]
   -- (not yet drawn: labLine and labDot draw it whatever they are given)
   put "new" into sDrawn["mark" & tId]
   return tId
end labMark

-- The line of words at the court's top. Called every step, it changes
-- at most five times a second, which is as fast as anyone reads; with
-- pNow, at once
command labSay pText, pNow
   if pText is sSaid then
      exit labSay
   end if
   if not pNow and the milliseconds - sSaidAt < 200 then
      exit labSay
   end if
   put pText into sSaid
   put the milliseconds into sSaidAt
   if there is a field "Readout" then
      put pText into field "Readout"
      labFitReadout
   end if
end labSay

-- The line's field as wide as its words (two lines when they are wider
-- than the court), and its dark backing around it
private command labFitReadout
   local tMax, tLeft, tTop
   put the left of field "Readout" into tLeft
   put the top of field "Readout" into tTop
   put the width of graphic "Court" - 28 into tMax
   set the dontWrap of field "Readout" to true
   if the formattedWidth of field "Readout" > tMax then
      set the dontWrap of field "Readout" to false
      set the rect of field "Readout" to tLeft, tTop, tLeft + tMax, tTop + 40
   else
      set the rect of field "Readout" to tLeft, tTop, tLeft + max(1, the formattedWidth of field "Readout"), tTop + 40
   end if
   -- (a few pixels more than its lines, or the engine cuts off the
   -- letters that hang below them)
   set the height of field "Readout" to the formattedHeight of field "Readout" + 4
   set the top of field "Readout" to tTop
   set the rect of graphic "ReadoutBg" to the left of field "Readout" - 6, tTop - 3, \
         the right of field "Readout" + 6, the bottom of field "Readout" + 3
   set the visible of graphic "ReadoutBg" to (field "Readout" is not empty)
end labFitReadout

-- Each step: every body that moved, where it is now; bodies that left
-- the court far behind are forgotten. After the window was hidden, or
-- made an icon, everything is drawn again
private command labDraw
   local tBody, tY, tGone, tFirst
   labFlashesOut
   put sHidden into tFirst
   put false into sHidden
   repeat for each key tBody in sBodies
      put b2BodyY(tBody) into tY
      if tY < -3 or abs(b2BodyX(tBody)) > 12 then
         put tBody & comma after tGone
         next repeat
      end if
      labDrawBody tBody, tFirst
   end repeat
   repeat for each item tBody in tGone
      labForget tBody
   end repeat
   repeat for each key tBody in sJoints
      labDrawJoint tBody
   end repeat
end labDraw

-- The bodies labFlash lit whose moment is over, back in their colours
private command labFlashesOut
   local tBody, tNow, tGone
   if sFlash is empty then
      exit labFlashesOut
   end if
   put the milliseconds into tNow
   repeat for each key tBody in sFlash
      if tNow > sFlash[tBody] then
         put tBody & comma after tGone
      end if
   end repeat
   repeat for each item tBody in tGone
      delete variable sFlash[tBody]
      labRepaint tBody
   end repeat
end labFlashesOut

-- Turns a body's shapes, as Box2D has them around the body, into points
-- on the card: each point turned by the body's angle, moved to where the
-- body is, in pixels. A body asleep, or one that has not moved since it
-- was last drawn (one that never moves, as a static body, among them),
-- is not drawn again
private command labDrawBody pBody, pFirst
   local tX, tY, tAngle, tPose, tCos, tSin, tId, tPoint, tPixels, tAX, tAY
   if not pFirst and not b2BodyIsAwake(pBody) then
      exit labDrawBody
   end if
   put b2BodyX(pBody) into tX
   put b2BodyY(pBody) into tY
   put b2BodyAngle(pBody) into tAngle
   put tX & "," & tY & "," & tAngle into tPose
   if not pFirst and tPose is sPose[pBody] then
      exit labDrawBody
   end if
   put tPose into sPose[pBody]
   put cos(tAngle) into tCos
   put sin(tAngle) into tSin
   -- (where the body is, in pixels; y goes up in Box2D, down here)
   put sOriginX + tX * kScale into tX
   put sOriginY - tY * kScale into tY
   repeat for each item tId in sBodies[pBody]
      put empty into tPixels
      repeat for each line tPoint in sPoints[tId]
         put item 1 of tPoint into tAX
         put item 2 of tPoint into tAY
         put round(tX + tCos * tAX - tSin * tAY) & "," & round(tY - tSin * tAX - tCos * tAY) & return after tPixels
      end repeat
      delete the last char of tPixels
      -- (points that did not change are not set again, which would draw
      -- the graphic again)
      if tPixels is not sDrawn[tId] then
         put tPixels into sDrawn[tId]
         set the points of graphic id tId to tPixels
      end if
   end repeat
end labDrawBody

-- A shape's points, in metres a line, as pixels (not rounded: they are
-- turned and moved first, each time the body is drawn)
private function labScaled pPoints
   local tPoint, tScaled
   repeat for each line tPoint in pPoints
      put item 1 of tPoint * kScale & "," & item 2 of tPoint * kScale & return after tScaled
   end repeat
   delete the last char of tScaled
   return tScaled
end labScaled

-- A joint's line: its two points, each where its body has it now. A
-- joint's bodies and points never change, so labShowJoint asks for them
-- once. The line is set again only when it is not where it was
private command labDrawJoint pJoint
   local tA, tB, tAX, tAY, tBX, tBY, tPixels
   put b2JointBodyA(pJoint) into tA
   if tA is 0 then
      -- (the joint was destroyed)
      labHideJoint pJoint
      exit labDrawJoint
   end if
   put item 1 of sJointInfo[pJoint] into tB
   put b2BodyWorldPointX(tA, item 2 of sJointInfo[pJoint], item 3 of sJointInfo[pJoint]) into tAX
   put b2BodyWorldPointY(tA, item 2 of sJointInfo[pJoint], item 3 of sJointInfo[pJoint]) into tAY
   put b2BodyWorldPointX(tB, item 4 of sJointInfo[pJoint], item 5 of sJointInfo[pJoint]) into tBX
   put b2BodyWorldPointY(tB, item 4 of sJointInfo[pJoint], item 5 of sJointInfo[pJoint]) into tBY
   if abs(tAX - tBX) + abs(tAY - tBY) > 0.01 then
      -- (a rod, a spring, a rope: from one anchor to the other)
      put labPX(tAX) & "," & labPY(tAY) & return & labPX(tBX) & "," & labPY(tBY) into tPixels
   else
      -- (a hinge or a wheel, whose two anchors are one point: from the
      -- middle of one body, through the pin, to the middle of the other)
      put labPX(b2BodyX(tA)) & "," & labPY(b2BodyY(tA)) & return & \
            labPX(tAX) & "," & labPY(tAY) & return & labPX(b2BodyX(tB)) & "," & labPY(b2BodyY(tB)) into tPixels
   end if
   if tPixels is not sDrawn["joint" & pJoint] then
      put tPixels into sDrawn["joint" & pJoint]
      set the points of graphic id sJoints[pJoint] to tPixels
   end if
end labDrawJoint

-- A shape's outline, around its body, in metres: what Box2D gives back
-- for each kind of shape (0 circle, 1 capsule, 2 segment, 3 polygon)
private function labShapePoints pShape
   local tPoints, tCount, tIndex, tX, tY, tR, tX2, tY2, tAngle, tStep
   switch b2ShapeType(pShape)
      case 0
         -- A circle: its middle, then around it, so that a line from the
         -- middle to the edge shows it turning
         b2ShapeCircleUpdate pShape
         put b2ShapeCircleX() into tX
         put b2ShapeCircleY() into tY
         put b2ShapeCircleRadius() into tR
         put tX & "," & tY & return into tPoints
         repeat with tIndex = 0 to 24
            put tIndex * 2 * pi / 24 into tAngle
            put tX + tR * cos(tAngle) & "," & tY + tR * sin(tAngle) & return after tPoints
         end repeat
         break
      case 1
         -- A capsule: half a circle round each end
         b2ShapeCapsuleUpdate pShape
         put b2ShapeCapsuleX1() into tX
         put b2ShapeCapsuleY1() into tY
         put b2ShapeCapsuleX2() into tX2
         put b2ShapeCapsuleY2() into tY2
         put b2ShapeCapsuleRadius() into tR
         put atan2(tY2 - tY, tX2 - tX) into tAngle
         put pi / 10 into tStep
         repeat with tIndex = 0 to 10
            put tX2 + tR * cos(tAngle - pi / 2 + tIndex * tStep) & "," & \
                  tY2 + tR * sin(tAngle - pi / 2 + tIndex * tStep) & return after tPoints
         end repeat
         repeat with tIndex = 0 to 10
            put tX + tR * cos(tAngle + pi / 2 + tIndex * tStep) & "," & \
                  tY + tR * sin(tAngle + pi / 2 + tIndex * tStep) & return after tPoints
         end repeat
         put line 1 of tPoints & return after tPoints
         break
      case 2
         b2ShapeSegmentUpdate pShape
         put b2ShapeSegmentX1() & "," & b2ShapeSegmentY1() & return & \
               b2ShapeSegmentX2() & "," & b2ShapeSegmentY2() & return into tPoints
         break
      case 3
         put b2ShapePolygonUpdate(pShape) into tCount
         repeat with tIndex = 1 to tCount
            put b2ShapePolygonVertexX(tIndex) & "," & b2ShapePolygonVertexY(tIndex) & return after tPoints
         end repeat
         if tCount > 0 then
            put line 1 of tPoints & return after tPoints
         end if
         break
   end switch
   delete the last char of tPoints
   return tPoints
end labShapePoints

private function labNewGraphic pIsLine, pColor
   local tId
   create graphic in group "Bodies"
   put the id of it into tId
   set the style of graphic id tId to "polygon"
   set the antialiased of graphic id tId to true
   set the points of graphic id tId to "0,0" & return & "1,1"
   if pIsLine then
      set the filled of graphic id tId to false
      set the lineSize of graphic id tId to 3
   else
      set the filled of graphic id tId to true
      set the lineSize of graphic id tId to 2
   end if
   labPaint tId, pColor
   return tId
end labNewGraphic

private command labPaint pId, pColor
   local tRGB
   put labRGB(pColor) into tRGB
   set the backgroundColor of graphic id pId to tRGB
   set the foregroundColor of graphic id pId to labEdge(tRGB)
end labPaint

-- A body's colours back, after a flash
private command labRepaint pBody
   local tId
   if labIsShown(pBody) then
      repeat for each item tId in sBodies[pBody]
         labPaint tId, sColor[tId]
      end repeat
   end if
end labRepaint

-- The colours bodies are drawn in, by name
function labRGB pColor
   switch pColor
      case "sky"
         return "56,189,248"
      case "amber"
         return "251,191,36"
      case "rose"
         return "251,113,133"
      case "lime"
         return "163,230,53"
      case "violet"
         return "167,139,250"
      case "teal"
         return "45,212,191"
      case "orange"
         return "251,146,60"
      case "white"
         return "248,250,252"
      case "ground"
         return "71,85,105"
      case "dim"
         return "100,116,139"
      default
         -- slate, for what does not move
         return "148,163,184"
   end switch
end labRGB

-- A colour's edge: the colour, darker
private function labEdge pRGB
   return round(item 1 of pRGB * 0.55) & "," & round(item 2 of pRGB * 0.55) & "," & round(item 3 of pRGB * 0.55)
end labEdge

########################################
#
# Grabbing a body: a mouse joint
#
# A mouse joint pulls a body toward a point, as a soft spring does, but
# no harder than a force you give it. The Dragging card shows the same
# code on its own; here it is what lets you throw bodies on every card.

on mouseDown pButton
   local tError
   -- (the card's own mouseDown, which this hands it below, passes it
   -- here again: it goes no further)
   if sForwarding then
      exit mouseDown
   end if
   if pButton is 1 and sWorld is not empty and the cOwnDrag of this card is not true \
         and the clickLoc is within the rect of graphic "Court" then
      labGrab
   end if
   -- A click in the court or on Reset, Pause or Step goes to the card's
   -- own mouseDown, if it has one (a click on a body, or on empty space),
   -- and stops there: the window would show this long script in its
   -- Scripts panel on every such click, which takes most of a second and
   -- holds up the click and the drag. (The panel's Lab chip shows it)
   if labOwns(the long id of the target) then
      put true into sForwarding
      try
         dispatch "mouseDown" to this card with pButton
         if sPaused and sWorld is not empty then
            lock screen
            labDraw
            unlock screen
         end if
      catch tError
         put false into sForwarding
         labFail "mouseDown", tError
         exit mouseDown
      end try
      put false into sForwarding
      exit mouseDown
   end if
   pass mouseDown
end mouseDown

-- True for the Lab and what is in it
private function labOwns pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if tObj is the long id of me then
         return true
      end if
      put the long id of the owner of tObj into tObj
   end repeat
   return false
end labOwns

-- The calls list scrolls with the wheel (65308 down, 65309 up), three
-- calls a turn, though it has no scrollbar
on rawKeyDown pKey
   local tStep
   if (pKey is 65308 or pKey is 65309) and there is a field "Calls" \
         and the mouseLoc is within the rect of field "Calls" then
      put 3 * the textHeight of field "Calls" into tStep
      if pKey is 65309 then
         put -tStep into tStep
      end if
      set the vScroll of field "Calls" to max(0, the vScroll of field "Calls" + tStep)
      exit rawKeyDown
   end if
   pass rawKeyDown
end rawKeyDown

on mouseUp pButton
   local tDo
   labLetGo
   -- A button of the card's: its cDo is the handler it runs
   put labButtonDo(the long id of the target) into tDo
   if tDo is not empty and pButton is 1 then
      labRun tDo
   end if
   if the short name of the target is "Calls" then
      labExplain the value of the clickLine
   end if
   pass mouseUp
end mouseUp

on mouseRelease
   labLetGo
   pass mouseRelease
end mouseRelease

private command labGrab
   local tX, tY, tBody
   -- (the body where the mouse was pressed: until 0.2.7-rc.6.17 it was
   -- the one under the mouse when the press was handled, and a press on
   -- a busy machine, with the mouse already moving, grabbed nothing)
   put labClickX() into tX
   put labClickY() into tY
   put b2BodyAtPoint(sWorld, tX, tY) into tBody
   -- (only a dynamic body: static and kinematic ones go where they go)
   if tBody is 0 or b2BodyType(tBody) is not 2 then
      exit labGrab
   end if
   if sDragGround is empty then
      put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into sDragGround
   end if
   -- 5 hertz, damped 0.7, and a pull up to a thousand times its weight
   put b2MouseJoint(sWorld, sDragGround, tBody, tX, tY, 5, 0.7, 1000 * b2BodyMass(tBody)) into sDrag
   b2SetAwake tBody, true
end labGrab

-- Each step, the mouse joint's target is where the mouse is
private command labDrag
   if sDrag is empty then
      exit labDrag
   end if
   if the mouse is up then
      labLetGo
   else
      b2MouseSetTarget sDrag, labMouseX(), labMouseY()
   end if
end labDrag

private command labLetGo
   if sDrag is not empty then
      b2DestroyJoint sDrag
      put empty into sDrag
   end if
end labLetGo

########################################
#
# The card's buttons, and the calls list
#

-- The handler a button runs: the cDo of the button's group
private function labButtonDo pObj
   local tObj
   put pObj into tObj
   repeat while word 1 of tObj is not "card" and word 1 of tObj is not "stack" and tObj is not empty
      if the cDo of tObj is not empty then
         return the cDo of tObj
      end if
      put the long owner of tObj into tObj
   end repeat
   return empty
end labButtonDo

-- Runs a button's handler in the card's script (or this one's, for
-- Reset, Pause and Step); an error stops the loop and says where
command labRun pHandler
   local tError
   -- (without a world, Box2D is not loaded or the card's labBuild
   -- stopped: the line at the court's top says so, and only Reset, Pause
   -- and Step, the Lab's own, have anything to do)
   if sCard is empty then
      exit labRun
   end if
   if sWorld is empty and pHandler is not among the items of "labRestart,labTogglePause,labStepButton" then
      exit labRun
   end if
   -- (the screen is locked while the button runs: a body's graphics are
   -- made before they are put where the body is, and would flash at the
   -- card's middle in the meantime)
   lock screen
   try
      dispatch pHandler to sCard
      -- (paused, the loop draws nothing: what the button changed is
      -- drawn here)
      if sPaused and sWorld is not empty and pHandler is not "labStepButton" then
         labDraw
      end if
   catch tError
      labFail pHandler, tError
   end try
   labShowButtons pHandler
   unlock screen
end labRun

########################################
#
# The card's buttons light up
#
# A button that switches something on or off (its group's cSwitch is
# true, from "switch" in the builder's buttons block) stays lit while
# what it switches is on: the card's function labLit, given the
# button's handler, says whether it is. Any other button lights up for
# a moment when it runs. The light is the group's graphics "<name>_lit"
# (a wash of the accent) and "<name>_ring" (its outline), hidden when
# the button is not lit.

-- After a button's handler ran (empty: after the lesson was made, or
-- the Code tab's lines ran): puts every switch's light right, and
-- flashes the button that ran, if it is not a switch
command labShowButtons pHandler
   local tIndex, tObj, tOn, tError
   if sCard is empty then
      exit labShowButtons
   end if
   repeat with tIndex = 1 to the number of groups of sCard
      put the long id of group tIndex of sCard into tObj
      if not (the short name of tObj begins with "Do") or the cDo of tObj is empty then
         next repeat
      end if
      if the cSwitch of tObj is true then
         put false into tOn
         try
            dispatch function "labLit" to sCard with the cDo of tObj
            put (the result is true) into tOn
         catch tError
         end try
         labLight tObj, tOn
      else if pHandler is not empty and the cDo of tObj is pHandler then
         labLight tObj, true
         put tObj into sFlashed
         send "labUnflash" to me in 180 milliseconds
      end if
   end repeat
end labShowButtons

-- Every switch's light right, five times a second while the lesson
-- runs: the card's switches are found once, when it opens, not each time
command labSwitchLights
   local tObj, tOn, tError
   if sCard is empty then
      exit labSwitchLights
   end if
   -- (a line each: a long id holds the stack's path, which can hold a
   -- comma)
   if line 1 of sSwitches is not sCard then
      put sCard into sSwitches
      repeat with tObj = 1 to the number of groups of sCard
         if the short name of group tObj of sCard begins with "Do" and the cDo of group tObj of sCard is not empty \
               and the cSwitch of group tObj of sCard is true then
            put return & the long id of group tObj of sCard after sSwitches
         end if
      end repeat
   end if
   repeat for each line tObj in line 2 to -1 of sSwitches
      put false into tOn
      try
         dispatch function "labLit" to sCard with the cDo of tObj
         put (the result is true) into tOn
      catch tError
      end try
      labLight tObj, tOn
   end repeat
end labSwitchLights

-- The end of a button's flash
command labUnflash
   if sFlashed is not empty and exists(sFlashed) then
      labLight sFlashed, false
   end if
   put empty into sFlashed
end labUnflash

-- Lights a button of the card's, or puts its light out
command labLight pGroup, pOn
   local tName
   put the short name of pGroup into tName
   if there is a graphic (tName & "_lit") of pGroup then
      set the visible of graphic (tName & "_lit") of pGroup to pOn
      set the visible of graphic (tName & "_ring") of pGroup to pOn
   end if
end labLight

-- What a Box2D handler in the calls list does
command labExplain pName
   local tDocs, tDoc
   -- (the words are one array in the custom property cDocs: read whole,
   -- then by name. "the cDocs[pName]" would ask a custom property SET
   -- named cDocs, which there is not, and always be empty)
   put the cDocs of me into tDocs
   put tDocs[pName] into tDoc
   if tDoc is empty then
      exit labExplain
   end if
   set the itemDelimiter to "|"
   put item 1 of tDoc & return & item 2 of tDoc into field "CallDoc"
   set the textStyle of line 1 of field "CallDoc" to "bold"
   set the itemDelimiter to comma
end labExplain
