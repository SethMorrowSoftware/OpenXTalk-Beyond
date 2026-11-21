script "Render3D Tour"
-- Render3D Tour: nine small 3D scenes, each showing one thing that
-- render3dxt (the xTalk Suite's 3D renderer) can do, drawn into an
-- ordinary image control. Built by
-- tools/web-player/render3d-tour.livecodescript in OXT-Beyond's
-- repository, from this script alone: it has no pictures, models or other
-- files, so every texture and model in it is made here, in script.
--
-- How it is made:
--   one card, "Tour": the picture (image "View"), a button for each
--     exhibit (Ex1 to Ex9), three tick boxes (Smooth, Fog, Spin), a few
--     words about the exhibit (About), what the last picture cost
--     (Stats), and six labels (Tag1 to Tag6) that float over the things
--     in the picture
--   one exhibit at a time: rtGo makes a scene and everything in it, and
--     gives back the one before (rtClear), so nothing is left behind
--   one loop: rtFrame shows the picture begun a frame ago, moves things
--     by the clock (rtTick), and begins the next picture. On a desktop
--     the picture is drawn on other threads while the engine does its
--     own work; in a browser there are none, and it is drawn at once
--   the camera: drag the picture to walk round the scene, and turn the
--     wheel (or press + and -) to come closer or go away
--
-- For the tests (tests/lcs/webplayer/render3d-tour.livecodescript) the
-- clock can be taken out of the loop's hands: rtTestBegin stops the
-- loop, rtTestStep moves the tour on by so many seconds and draws,
-- rtClickView and rtHoverView are the mouse over the picture, and
-- rtState says how things are.

constant kViewW = 640
constant kViewH = 480
constant kExhibits = 9
constant kTags = 6
constant kNight = "24,28,40"

local sHave                  -- true when render3dxt answers
local sScene                 -- the scene of the exhibit that is shown
local sMeshes, sMats, sTexs  -- what this exhibit made, to give back
local sParts                 -- array: the exhibit's own nodes, lights and numbers
local sExhibit               -- 1 to kExhibits, or empty
local sTime                  -- seconds the exhibit has played
local sDelta                 -- seconds since the last tick
local sClock                 -- the milliseconds at the last frame
local sRunning, sFrameMsg
local sBegun                 -- a picture was begun and waits to be shown
local sStale                 -- the scene changed since the last picture was begun
local sYaw, sPitch, sDist, sTarget
local sOwnCamera             -- true when the exhibit moves the camera itself
local sSmooth, sFog, sSpin
local sFogNear, sFogFar, sBack
local sDragging, sDragX, sDragY, sDragMoved
local sFrames, sFpsClock, sFpsFrames, sFps
local sTagAt                 -- array: tag number -> "x,y,z" it floats over
local sHover                 -- the node under the pointer in "Click and aim"
local sPicked                -- what the last click said
local sTesting

----------------------------------------------------------------------
-- The stack's own messages

on openStack
   rtStart
end openStack

on closeStack
   rtStop
end closeStack

on mouseUp
   local tName
   put the short name of the target into tName
   if tName is "View" then
      rtDragEnd true
   else if tName begins with "Ex" and char 3 to -1 of tName is an integer then
      rtGo char 3 to -1 of tName
   else if tName is "Smooth" then
      rtSetSmooth (sSmooth is not true)
   else if tName is "Fog" then
      rtSetFog (sFog is not true)
   else if tName is "Spin" then
      rtSetSpin (sSpin is not true)
   else
      pass mouseUp
   end if
end mouseUp

on mouseDown
   if the short name of the target is not "View" then
      pass mouseDown
   end if
   put true into sDragging
   put the mouseH into sDragX
   put the mouseV into sDragY
   put 0 into sDragMoved
end mouseDown

on mouseMove pX, pY
   if sDragging is true then
      rtOrbitBy pX - sDragX, pY - sDragY
      add abs(pX - sDragX) + abs(pY - sDragY) to sDragMoved
      put pX into sDragX
      put pY into sDragY
   else if sExhibit is 8 and the short name of the target is "View" then
      rtHoverView pX - the left of image "View", pY - the top of image "View"
   else
      pass mouseMove
   end if
end mouseMove

on mouseRelease
   rtDragEnd false
end mouseRelease

-- The wheel, as the engine tells a stack about it
on rawKeyDown pKey
   if pKey is 65309 then
      rtZoom 0.9
   else if pKey is 65308 then
      rtZoom 1.1
   else
      pass rawKeyDown
   end if
end rawKeyDown

on keyDown pKey
   if pKey is "+" or pKey is "=" then
      rtZoom 0.9
   else if pKey is "-" then
      rtZoom 1.1
   else
      pass keyDown
   end if
end keyDown

command rtDragEnd pOverPicture
   local tWas
   put (sDragging is true) into tWas
   put false into sDragging
   if tWas and pOverPicture and sDragMoved < 4 then
      rtClickView the mouseH - the left of image "View", the mouseV - the top of image "View"
   end if
end rtDragEnd

----------------------------------------------------------------------
-- Start and stop

-- True if render3dxt is part of this engine: a function of an extension
-- that is not there cannot be called
function rtHaveRenderer
   local tVersion, tError
   try
      do "put r3LibraryVersion() into tVersion"
   catch tError
      return false
   end try
   return tVersion is not empty
end rtHaveRenderer

command rtStart
   local tIndex
   set the defaultStack to the short name of me
   put rtHaveRenderer() into sHave
   put false into sRunning
   put false into sDragging
   put false into sBegun
   put false into sStale
   put empty into sFrameMsg
   put empty into sExhibit
   put empty into sScene
   put 0 into sFrames
   put 0 into sFps
   put empty into sPicked
   repeat with tIndex = 1 to kTags
      hide field ("Tag" & tIndex)
   end repeat
   if sHave is not true then
      hide image "View"
      show field "Missing"
      put empty into field "Stats"
      put "Nothing can be drawn here yet." into field "About"
      exit rtStart
   end if
   hide field "Missing"
   show image "View"
   -- smooth edges are four times the work: on by default where there are
   -- threads to share it (a desktop), off where there are none (a browser)
   put (r3ThreadCount() > 1) into sSmooth
   put true into sFog
   put true into sSpin
   set the hilite of button "Smooth" to sSmooth
   set the hilite of button "Fog" to sFog
   set the hilite of button "Spin" to sSpin
   rtGo 1
   if sTesting is not true then
      put true into sRunning
      put the milliseconds into sClock
      put sClock into sFpsClock
      put 0 into sFpsFrames
      send "rtFrame" to me in 16 milliseconds
      put the result into sFrameMsg
   end if
end rtStart

command rtStop
   put false into sRunning
   if sFrameMsg is not empty then
      cancel sFrameMsg
      put empty into sFrameMsg
   end if
   if sHave is true then
      rtClear
   end if
end rtStop

-- Gives back everything the exhibit made: the scene (with its nodes and
-- lights), then the meshes, materials and textures
command rtClear
   local tHandle
   put false into sBegun
   if sScene is not empty then
      r3SceneDestroy sScene
   end if
   repeat for each item tHandle in sMeshes
      r3MeshDestroy tHandle
   end repeat
   repeat for each item tHandle in sMats
      r3MaterialDestroy tHandle
   end repeat
   repeat for each item tHandle in sTexs
      r3TextureDestroy tHandle
   end repeat
   put empty into sScene
   put empty into sMeshes
   put empty into sMats
   put empty into sTexs
   put empty into sParts
   put empty into sTagAt
   put empty into sHover
end rtClear

----------------------------------------------------------------------
-- One exhibit

command rtGo pExhibit
   local tIndex
   if sHave is not true then
      exit rtGo
   end if
   if pExhibit is not an integer or pExhibit < 1 or pExhibit > kExhibits then
      exit rtGo
   end if
   set the defaultStack to the short name of me
   lock screen
   rtClear
   put pExhibit into sExhibit
   put 0 into sTime
   put 0 into sDelta
   put empty into sPicked
   put false into sOwnCamera
   put r3SceneCreate() into sScene
   -- what every exhibit starts from: a night sky, a little light from
   -- everywhere, a sun over the left shoulder, fog far away
   put kNight into sBack
   put 18 into sFogNear
   put 60 into sFogFar
   put "0,1,0" into sTarget
   put 11 into sDist
   put 0.5 into sYaw
   put 0.35 into sPitch
   r3SceneSetAmbient sScene, 100, 104, 118
   -- a new scene comes with one light, a sun: the tour aims and tints it
   if r3SceneLightCount(sScene) > 0 then
      put r3SceneLight(sScene, 1) into sParts["sun"]
      r3LightSetDirection sParts["sun"], -0.5, -1, -0.6
      r3LightSetColor sParts["sun"], 255, 246, 232, 1.1
   else
      put r3LightCreateDirectional(sScene, -0.5, -1, -0.6, 255, 246, 232, 1) into sParts["sun"]
   end if
   repeat with tIndex = 1 to kTags
      hide field ("Tag" & tIndex)
   end repeat
   switch sExhibit
      case 1
         rtBuildShapes
         break
      case 2
         rtBuildTextures
         break
      case 3
         rtBuildMaterials
         break
      case 4
         rtBuildLights
         break
      case 5
         rtBuildModel
         break
      case 6
         rtBuildTerrain
         break
      case 7
         rtBuildColonnade
         break
      case 8
         rtBuildAim
         break
      case 9
         rtBuildMany
         break
   end switch
   r3SceneSetBackground sScene, item 1 of sBack, item 2 of sBack, item 3 of sBack
   rtApplyLook
   rtAim
   rtTick
   repeat with tIndex = 1 to kExhibits
      set the hilite of button ("Ex" & tIndex) to (tIndex is sExhibit)
   end repeat
   rtDraw
   rtShowStats
   unlock screen
end rtGo

-- The two tick boxes that change how any scene is drawn
command rtApplyLook
   if sSmooth is true then
      r3SceneSetSupersample sScene, 2
   else
      r3SceneSetSupersample sScene, 1
   end if
   if sFog is true then
      r3SceneSetFog sScene, item 1 of sBack, item 2 of sBack, item 3 of sBack, sFogNear, sFogFar
   else
      r3SceneSetFog sScene, item 1 of sBack, item 2 of sBack, item 3 of sBack, 0, 0
   end if
end rtApplyLook

command rtSetSmooth pOn
   put (pOn is true) into sSmooth
   set the hilite of button "Smooth" to sSmooth
   rtLookChanged
end rtSetSmooth

command rtSetFog pOn
   put (pOn is true) into sFog
   set the hilite of button "Fog" to sFog
   rtLookChanged
end rtSetFog

command rtSetSpin pOn
   put (pOn is true) into sSpin
   set the hilite of button "Spin" to sSpin
end rtSetSpin

command rtLookChanged
   if sScene is empty then
      exit rtLookChanged
   end if
   rtApplyLook
   rtChanged
end rtLookChanged

-- Something in the scene changed: the loop draws it, or, with the loop
-- stopped, it is drawn now
command rtChanged
   if sRunning is true then
      put true into sStale
   else
      rtDraw
   end if
end rtChanged

----------------------------------------------------------------------
-- The camera

command rtAim
   local tX, tY, tZ
   if sScene is empty or sOwnCamera is true then
      exit rtAim
   end if
   put item 1 of sTarget + sDist * cos(sPitch) * sin(sYaw) into tX
   put item 2 of sTarget + sDist * sin(sPitch) into tY
   put item 3 of sTarget + sDist * cos(sPitch) * cos(sYaw) into tZ
   r3SceneSetCamera sScene, tX, tY, tZ, item 1 of sTarget, item 2 of sTarget, item 3 of sTarget, 50
end rtAim

command rtOrbitBy pDx, pDy
   if sScene is empty or sOwnCamera is true then
      exit rtOrbitBy
   end if
   subtract pDx * 0.01 from sYaw
   add pDy * 0.01 to sPitch
   -- never under the floor, never straight overhead
   put max(0.05, min(1.45, sPitch)) into sPitch
   rtAim
   rtPlaceTags
   rtChanged
end rtOrbitBy

command rtZoom pBy
   if sScene is empty or sOwnCamera is true then
      exit rtZoom
   end if
   put max(3, min(40, sDist * pBy)) into sDist
   rtAim
   rtPlaceTags
   rtChanged
end rtZoom

----------------------------------------------------------------------
-- The loop

on rtFrame
   local tNow, tSpent
   -- a message that comes later finds its controls in the default stack
   set the defaultStack to the short name of me
   put empty into sFrameMsg
   if sRunning is not true then
      exit rtFrame
   end if
   put the milliseconds into tNow
   if sBegun is true then
      put false into sBegun
      rtShow r3SceneFrame(sScene)
      add 1 to sFrames
      add 1 to sFpsFrames
      if tNow - sFpsClock >= 500 then
         put sFpsFrames * 1000 / (tNow - sFpsClock) into sFps
         put tNow into sFpsClock
         put 0 into sFpsFrames
         rtShowStats
      end if
   else if tNow - sFpsClock >= 500 then
      -- nothing is being drawn: nothing moves and nothing was touched
      put 0 into sFps
      put tNow into sFpsClock
      put 0 into sFpsFrames
      rtShowStats
   end if
   if sSpin is true then
      -- by the clock, so a slow machine shows fewer pictures and never a
      -- slower turn; a long stall is forgiven, not caught up
      put min(0.1, max(0, (tNow - sClock) / 1000)) into sDelta
      add sDelta to sTime
      rtTick
      put true into sStale
   end if
   put tNow into sClock
   if sStale is true then
      put false into sStale
      put (r3SceneRenderBegin(sScene, kViewW, kViewH) > 0) into sBegun
   end if
   put the milliseconds - tNow into tSpent
   send "rtFrame" to me in max(1, 16 - tSpent) milliseconds
   put the result into sFrameMsg
end rtFrame

-- A picture drawn and shown at once
command rtDraw
   if sScene is empty then
      exit rtDraw
   end if
   put false into sBegun
   put false into sStale
   rtShow r3SceneRender(sScene, kViewW, kViewH)
end rtDraw

-- Hands a picture to the image. The engine packs what is set as imageData
-- the way the paintCompression says, and a desktop engine starts with
-- "png", which costs more than drawing the picture did. The property is
-- everybody's, so it is changed for this one line and put back.
command rtShow pPicture
   local tWas
   if pPicture is empty then
      exit rtShow
   end if
   put the paintCompression into tWas
   set the paintCompression to "rle"
   set the imageData of image "View" to pPicture
   set the paintCompression to tWas
end rtShow

command rtShowStats
   local tStats, tText
   if sScene is empty then
      exit rtShowStats
   end if
   put r3SceneStats(sScene) into tStats
   put item 1 of tStats && "triangles, drawn in" && format("%.1f", item 3 of tStats) && "ms" into tText
   if r3ThreadCount() > 1 then
      put " on" && r3ThreadCount() && "threads" after tText
   end if
   if sFps > 0 then
      put ";" && round(sFps) && "pictures a second" after tText
   else if sRunning is true then
      put "; nothing moves, so nothing is drawn" after tText
   end if
   if sPicked is not empty then
      put return & sPicked after tText
   end if
   put tText into field "Stats"
end rtShowStats

command rtTick
   switch sExhibit
      case 1
         rtTickTurners 0.9
         break
      case 2
         rtTickTurners 0.6
         break
      case 3
         rtTickMaterials
         break
      case 4
         rtTickLights
         break
      case 5
         rtTickTurners 0.4
         break
      case 6
         rtTickTerrain
         break
      case 7
         rtTickColonnade
         break
      case 8
         rtTickAim
         break
      case 9
         rtTickMany
         break
   end switch
   rtPlaceTags
end rtTick

----------------------------------------------------------------------
-- What the exhibits share

function rtMesh pHandle
   put pHandle & comma after sMeshes
   return pHandle
end rtMesh

function rtTex pHandle
   put pHandle & comma after sTexs
   return pHandle
end rtTex

function rtMat pR, pG, pB
   local tMat
   put r3MaterialCreate(pR, pG, pB) into tMat
   put tMat & comma after sMats
   return tMat
end rtMat

-- A white material that wears a texture
function rtTexMat pTexture
   local tMat
   put rtMat(255, 255, 255) into tMat
   r3MaterialSetTexture tMat, pTexture
   return tMat
end rtTexMat

function rtNode pMesh, pMat, pX, pY, pZ
   local tNode
   put r3NodeCreate(sScene, pMesh) into tNode
   if pMat is not empty and pMat is not 0 then
      r3NodeSetMaterial tNode, pMat
   end if
   r3NodeSetPosition tNode, pX, pY, pZ
   return tNode
end rtNode

-- Turns a node by pAngle (radians) about an axis of length 1
command rtRotate pNode, pAx, pAy, pAz, pAngle
   local tSin
   put sin(pAngle / 2) into tSin
   r3NodeSetRotation pNode, pAx * tSin, pAy * tSin, pAz * tSin, cos(pAngle / 2)
end rtRotate

-- A checked floor, pHalf metres each way from the middle
command rtFloor pHalf, pR1, pG1, pB1, pR2, pG2, pB2
   local tMesh, tTexture
   put rtMesh(r3MeshPlane(pHalf, pHalf, pHalf, pHalf)) into tMesh
   put rtTex(r3TextureChecker(64, 2, pR1, pG1, pB1, pR2, pG2, pB2)) into tTexture
   put rtNode(tMesh, rtTexMat(tTexture), 0, 0, 0) into sParts["floor"]
end rtFloor

-- A label that floats over a point of the scene
command rtTag pTag, pText, pX, pY, pZ
   put pText into field ("Tag" & pTag)
   put pX & comma & pY & comma & pZ into sTagAt[pTag]
end rtTag

-- r3SceneProject says where in the picture a point of the scene is
command rtPlaceTags
   local tTag, tSpot, tAt, tLeft, tTop
   if sScene is empty then
      exit rtPlaceTags
   end if
   put the left of image "View" into tLeft
   put the top of image "View" into tTop
   repeat with tTag = 1 to kTags
      put sTagAt[tTag] into tAt
      if tAt is empty then
         next repeat
      end if
      put r3SceneProject(sScene, kViewW, kViewH, item 1 of tAt, item 2 of tAt, item 3 of tAt) into tSpot
      if tSpot is empty or item 1 of tSpot < 50 or item 1 of tSpot > kViewW - 50 \
            or item 2 of tSpot < 12 or item 2 of tSpot > kViewH - 12 then
         hide field ("Tag" & tTag)
      else
         set the loc of field ("Tag" & tTag) to round(tLeft + item 1 of tSpot), round(tTop + item 2 of tSpot)
         show field ("Tag" & tTag)
      end if
   end repeat
end rtPlaceTags

-- The things listed in sParts["turners"] turn about the y axis
command rtTickTurners pSpeed
   local tNode, tCount
   put 0 into tCount
   repeat for each item tNode in sParts["turners"]
      add 1 to tCount
      rtRotate tNode, 0, 1, 0, sTime * pSpeed + tCount
   end repeat
end rtTickTurners

-- Bricks, as the imageData of a picture 64 pixels each way: four bytes
-- a pixel, the first unused, then red, green and blue
function rtBrickData
   local tData, tX, tY, tRow, tShift, tShade
   repeat with tY = 0 to 63
      put tY div 16 into tRow
      put (tRow mod 2) * 16 into tShift
      repeat with tX = 0 to 63
         if tY mod 16 < 2 or (tX + tShift) mod 32 < 2 then
            put numToByte(255) & numToByte(206) & numToByte(200) & numToByte(188) after tData
         else
            put 150 + ((tX * 7 + tY * 3 + tRow * 40 + ((tX + tShift) div 32) * 23) mod 40) into tShade
            put numToByte(255) & numToByte(tShade) & numToByte(trunc(tShade * 0.42)) & numToByte(trunc(tShade * 0.3)) after tData
         end if
      end repeat
   end repeat
   return tData
end rtBrickData

-- A PNG file, as text: a wooden lattice 32 pixels each way whose gaps
-- are transparent. A stack with a picture file would hand its bytes to
-- r3TextureDecode the same way.
function rtLatticePng
   local tText
   put "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABOUlEQVR42sWXWVICQRBE81ogMAN4" into tText
   put "FtwVEVQu4gru+74cMG0+/CEyYqLESeo/u7PqVfWCg06F49UF3mw1+NzP+TVs83SlyqvNOh97OT/2" after tText
   put "WjxervJivcb77Yxvuy0eJs3ZWo233QZf+k1+Dxc5SmtcJ83TTs7P/TZPkuZyo86HXsb3tMbRUoXn" after tText
   put "aY27bsbXQZO/++Ivov80i7IzLDKLsjMsMouyMywyC1mWQCizET1kWQKhMgwZkGUJhMIRMqAYRvSq" after tText
   put "d+BkqBoOToZqOuBkqOYfToZq/uFkqA4rOBmqEw5Ohuo4xqwMnbcj3Pf/tFm47/9ps5jnc2yyL+b5" after tText
   put "HJvsC1mWQCizoSmQZQmEyjBkQJYlEApHyIBiGNGr3oGToWo4OBmq6YCToZp/OBmq+YeTofxwOhnK" after tText
   put "D6eT4aw/qx97zuLMWYRxcAAAAABJRU5ErkJggg==" after tText
   return base64Decode(tText)
end rtLatticePng

----------------------------------------------------------------------
-- 1. Shapes: the five meshes made to measure, and a model

command rtBuildShapes
   local tGem
   put "Six shapes. A box, a ball, a cylinder, a capsule and a floor are made to measure with one call each; the gem is a model, read from the text of an OBJ file. Each label is put where r3SceneProject says its shape is in the picture." into field "About"
   rtFloor 12, 60, 66, 84, 44, 49, 64
   put "0,1,0" into sTarget
   put 9 into sDist
   put 0 into sYaw
   put 0.24 into sPitch
   put rtNode(rtMesh(r3MeshBox(0.6, 0.6, 0.6)), rtMat(230, 96, 70), -4, 0.9, 0) & comma into sParts["turners"]
   put rtNode(rtMesh(r3MeshSphere(0.7, 28, 14)), rtMat(250, 190, 60), -2, 0.9, 0) & comma after sParts["turners"]
   put rtNode(rtMesh(r3MeshCylinder(0.55, 0.7, 28)), rtMat(90, 190, 120), 0, 0.9, 0) & comma after sParts["turners"]
   put rtNode(rtMesh(r3MeshCapsule(0.4, 0.45, 24, 8)), rtMat(80, 150, 240), 2, 0.9, 0) & comma after sParts["turners"]
   put rtMesh(r3MeshParseObj(rtGemObj(), rtGemMtl())) into tGem
   put rtNode(tGem, empty, 4, 0.9, 0) & comma after sParts["turners"]
   rtTag 1, "Box", -4, 2, 0
   rtTag 2, "Sphere", -2, 2, 0
   rtTag 3, "Cylinder", 0, 2, 0
   rtTag 4, "Capsule", 2, 2, 0
   rtTag 5, "A model", 4, 2, 0
end rtBuildShapes

-- A model as the text of a Wavefront OBJ file: a gem with eight sides
function rtGemObj
   local tObj
   put "mtllib gem.mtl" & return & "usemtl gem" & return into tObj
   put "v 0 0.8 0" & return & "v 0 -0.8 0" & return after tObj
   put "v 0.6 0 0" & return & "v -0.6 0 0" & return after tObj
   put "v 0 0 0.6" & return & "v 0 0 -0.6" & return after tObj
   put "f 1 3 6" & return & "f 1 6 4" & return & "f 1 4 5" & return & "f 1 5 3" & return after tObj
   put "f 2 6 3" & return & "f 2 4 6" & return & "f 2 5 4" & return & "f 2 3 5" & return after tObj
   return tObj
end rtGemObj

function rtGemMtl
   return "newmtl gem" & return & "Kd 0.75 0.35 0.9" & return
end rtGemMtl

----------------------------------------------------------------------
-- 2. Textures: four ways to get one, and how it is drawn

command rtBuildTextures
   local tCube, tSharp, tSoft, tBricks, tLattice, tMat
   put "Four crates, four textures. Two are the same small checkerboard, drawn with sharp squares and then with smooth ones. The bricks are pixels this stack worked out and handed over as imageData. The lattice is a PNG file whose gaps are transparent, so you can see through it." into field "About"
   rtFloor 12, 70, 78, 70, 52, 60, 54
   put "0,1.1,0" into sTarget
   put 9 into sDist
   put 0.2 into sYaw
   put 0.24 into sPitch
   put rtMesh(r3MeshBox(0.8, 0.8, 0.8)) into tCube
   -- the same sixteen pixels, with and without smoothing
   put rtTex(r3TextureChecker(16, 4, 250, 250, 250, 40, 110, 200)) into tSharp
   r3TextureSetSmooth tSharp, false
   put rtTex(r3TextureChecker(16, 4, 250, 250, 250, 40, 110, 200)) into tSoft
   r3TextureSetSmooth tSoft, true
   put rtTex(r3TextureFromImageData(rtBrickData(), 64, 64)) into tBricks
   put rtTex(r3TextureDecode(rtLatticePng())) into tLattice
   r3TextureSetSmooth tLattice, false
   put rtNode(tCube, rtTexMat(tSharp), -3.6, 1, 0) & comma into sParts["turners"]
   put rtNode(tCube, rtTexMat(tSoft), -1.2, 1, 0) & comma after sParts["turners"]
   put rtNode(tCube, rtTexMat(tBricks), 1.2, 1, 0) & comma after sParts["turners"]
   put rtTexMat(tLattice) into tMat
   r3MaterialSetCutout tMat, true
   r3MaterialSetDoubleSided tMat, true
   put rtNode(tCube, tMat, 3.6, 1, 0) & comma after sParts["turners"]
   put r3TextureWidth(tLattice) & "x" & r3TextureHeight(tLattice) into sParts["lattice size"]
   rtTag 1, "Sharp", -3.6, 2.4, 0
   rtTag 2, "Smooth", -1.2, 2.4, 0
   rtTag 3, "From imageData", 1.2, 2.4, 0
   rtTag 4, "A PNG with gaps", 3.6, 2.4, 0
end rtBuildTextures

----------------------------------------------------------------------
-- 3. Materials: what a surface does with light

command rtBuildMaterials
   local tBall, tRough, tMat
   put "Five balls of the same red, five materials. Matte only takes the light. Shiny throws a highlight back at you. Glowing gives off light of its own. Unlit ignores the lamps and shows its plain colour. Flat lights every triangle as one facet. A lamp goes round them so you can see each answer." into field "About"
   rtFloor 12, 58, 58, 66, 42, 42, 50
   put "0,1,0" into sTarget
   put 9 into sDist
   put 0 into sYaw
   put 0.26 into sPitch
   r3LightSetColor sParts["sun"], 255, 246, 232, 0.45
   put r3LightCreatePoint(sScene, 0, 3, 3, 255, 255, 255, 2.2, 14) into sParts["lamp"]
   put rtNode(rtMesh(r3MeshSphere(0.12, 10, 6)), empty, 0, 3, 3) into sParts["bulb"]
   put rtMat(255, 255, 230) into tMat
   r3MaterialSetUnlit tMat, true
   r3NodeSetMaterial sParts["bulb"], tMat
   put rtMesh(r3MeshSphere(0.75, 32, 16)) into tBall
   put rtMesh(r3MeshSphere(0.75, 10, 6)) into tRough
   get rtNode(tBall, rtMat(200, 50, 45), -4, 0.9, 0)
   put rtMat(200, 50, 45) into tMat
   r3MaterialSetSpecular tMat, 0.9, 60
   get rtNode(tBall, tMat, -2, 0.9, 0)
   put rtMat(200, 50, 45) into tMat
   r3MaterialSetEmissive tMat, 120, 20, 10
   get rtNode(tBall, tMat, 0, 0.9, 0)
   put rtMat(200, 50, 45) into tMat
   r3MaterialSetUnlit tMat, true
   get rtNode(tBall, tMat, 2, 0.9, 0)
   put rtMat(200, 50, 45) into tMat
   r3MaterialSetFlat tMat, true
   put rtNode(tRough, tMat, 4, 0.9, 0) & comma into sParts["turners"]
   rtTag 1, "Matte", -4, 2.1, 0
   rtTag 2, "Shiny", -2, 2.1, 0
   rtTag 3, "Glowing", 0, 2.1, 0
   rtTag 4, "Unlit", 2, 2.1, 0
   rtTag 5, "Flat", 4, 2.1, 0
end rtBuildMaterials

command rtTickMaterials
   local tX, tZ
   rtTickTurners 0.5
   put 5 * sin(sTime * 0.8) into tX
   put 2.6 * cos(sTime * 0.8) into tZ
   r3LightSetPosition sParts["lamp"], tX, 2.6, tZ
   r3NodeSetPosition sParts["bulb"], tX, 2.6, tZ
end rtTickMaterials

----------------------------------------------------------------------
-- 4. Lights: a sun and three coloured lamps

command rtBuildLights
   local tColumn, tWhite, tBulb, tIndex, tAngle, tColors, tMat, tTexture
   put "A dim sun and three lamps: red, green and blue. A lamp lights what is near it and fades with distance, and where two meet their colours add. Light is worked out at the corners of a mesh, so this floor is made of many small squares. Click a lamp's bulb to switch it off and on." into field "About"
   -- light is worked out at a mesh's corners and blended between them, so
   -- a floor that lamps should paint needs corners near the lamps: this one
   -- has a corner every 40 centimetres
   put rtTex(r3TextureChecker(32, 2, 235, 235, 235, 190, 190, 190)) into tTexture
   r3TextureSetRepeat tTexture, true
   put rtNode(rtGridMesh(40, 0.4, false), rtTexMat(tTexture), 0, 0, 0) into sParts["floor"]
   put "0,0.8,0" into sTarget
   put 9.5 into sDist
   put 0.4 into sYaw
   put 0.5 into sPitch
   r3SceneSetAmbient sScene, 22, 24, 30
   r3LightSetColor sParts["sun"], 255, 246, 232, 0.12
   put rtMat(235, 235, 235) into tWhite
   r3MaterialSetSpecular tWhite, 0.5, 40
   put rtMesh(r3MeshCylinder(0.3, 1, 20)) into tColumn
   repeat with tIndex = 0 to 5
      put tIndex * pi / 3 into tAngle
      get rtNode(tColumn, tWhite, 3.4 * cos(tAngle), 1, 3.4 * sin(tAngle))
   end repeat
   get rtNode(rtMesh(r3MeshSphere(1, 32, 16)), tWhite, 0, 1, 0)
   put "255,60,50" & return & "60,255,90" & return & "70,110,255" into tColors
   put rtMesh(r3MeshSphere(0.16, 12, 8)) into tBulb
   repeat with tIndex = 1 to 3
      put r3LightCreatePoint(sScene, 0, 1.5, 0, item 1 of line tIndex of tColors, item 2 of line tIndex of tColors, \
            item 3 of line tIndex of tColors, 2.2, 7) into sParts["lamp" & tIndex]
      put rtMat(item 1 of line tIndex of tColors, item 2 of line tIndex of tColors, item 3 of line tIndex of tColors) into tMat
      r3MaterialSetUnlit tMat, true
      put rtNode(tBulb, tMat, 0, 1.5, 0) into sParts["bulb" & tIndex]
      -- the bulb's tag is its lamp's number: a click on the picture finds
      -- the bulb, and its tag says which lamp to switch
      r3NodeSetTag sParts["bulb" & tIndex], tIndex
   end repeat
   put r3SceneLightCount(sScene) into sParts["lights"]
end rtBuildLights

command rtTickLights
   local tIndex, tAngle, tX, tZ
   repeat with tIndex = 1 to 3
      put sTime * 0.7 + tIndex * 2 * pi / 3 into tAngle
      put 2.1 * cos(tAngle) into tX
      put 2.1 * sin(tAngle) into tZ
      r3LightSetPosition sParts["lamp" & tIndex], tX, 1.5 + 0.5 * sin(sTime + tIndex), tZ
      r3NodeSetPosition sParts["bulb" & tIndex], tX, 1.5 + 0.5 * sin(sTime + tIndex), tZ
   end repeat
end rtTickLights

----------------------------------------------------------------------
-- 5. A model: read from text, with its own materials

command rtBuildModel
   local tHouse, tSlot, tNames, tWants, tBricks, tSpire
   rtFloor 12, 62, 110, 66, 50, 92, 56
   put "0,1,0" into sTarget
   put 8.5 into sDist
   put 0.7 into sYaw
   put 0.35 into sPitch
   -- nothing is read from disk: the model and its material file are text
   put rtMesh(r3MeshParseObj(rtHouseObj(), rtHouseMtl())) into tHouse
   put rtTex(r3TextureFromImageData(rtBrickData(), 64, 64)) into tBricks
   repeat with tSlot = 1 to r3MeshSlotCount(tHouse)
      put r3MeshSlotName(tHouse, tSlot) & comma after tNames
      r3MaterialSetFlat r3MeshSlotMaterial(tHouse, tSlot), true
      -- a material file names a picture; the stack that has it puts it on
      if r3MeshSlotTextureName(tHouse, tSlot) is not empty then
         put r3MeshSlotTextureName(tHouse, tSlot) into tWants
         r3MaterialSetTexture r3MeshSlotMaterial(tHouse, tSlot), tBricks
      end if
   end repeat
   delete the last char of tNames
   put tNames into sParts["slots"]
   put r3MeshTriangleCount(tHouse) into sParts["house triangles"]
   put rtNode(tHouse, empty, -1.2, 0, 0) & comma into sParts["turners"]
   -- and a mesh from a plain list of triangles, nine numbers a line
   put rtMesh(r3MeshFromTrianglesText(rtSpireTriangles())) into tSpire
   get rtNode(tSpire, rtMat(240, 200, 80), 2.6, 0, 0)
   put "A house, read from the text of an OBJ model and its material file. The file names two materials (" & replaceText(tNames, ",", " and ") & ") and asks for a picture called " & tWants & " on the walls, which this stack makes and puts on. The spire beside it comes from a plain list of triangles." into field "About"
   rtTag 1, "A model from OBJ text", -1.2, 2.5, 0
   rtTag 2, "A list of triangles", 2.6, 2.5, 0
end rtBuildModel

-- Walls with texture coordinates, so bricks can go on them, and a roof
function rtHouseObj
   local tObj
   put "mtllib house.mtl" & return into tObj
   put "v -1 0 1" & return & "v 1 0 1" & return & "v 1 0 -1" & return & "v -1 0 -1" & return after tObj
   put "v -1 1.2 1" & return & "v 1 1.2 1" & return & "v 1 1.2 -1" & return & "v -1 1.2 -1" & return after tObj
   put "v 0 2 1" & return & "v 0 2 -1" & return after tObj
   put "vt 0 0" & return & "vt 2 0" & return & "vt 2 1" & return & "vt 0 1" & return & "vt 1 1.7" & return after tObj
   put "usemtl walls" & return after tObj
   put "f 1/1 2/2 6/3 5/4" & return & "f 2/1 3/2 7/3 6/4" & return after tObj
   put "f 3/1 4/2 8/3 7/4" & return & "f 4/1 1/2 5/3 8/4" & return after tObj
   put "f 5/4 6/3 9/5" & return & "f 7/4 8/3 10/5" & return after tObj
   put "usemtl roof" & return after tObj
   put "f 6 7 10 9" & return & "f 8 5 9 10" & return after tObj
   return tObj
end rtHouseObj

function rtHouseMtl
   local tMtl
   put "newmtl walls" & return & "Kd 1 1 1" & return & "map_Kd bricks.png" & return into tMtl
   put "newmtl roof" & return & "Kd 0.45 0.2 0.18" & return after tMtl
   return tMtl
end rtHouseMtl

-- Four sides of a tall pyramid, counter-clockwise seen from outside
function rtSpireTriangles
   local tText
   put "-0.6,0,0.6,0.6,0,0.6,0,2.2,0" & return into tText
   put "0.6,0,0.6,0.6,0,-0.6,0,2.2,0" & return after tText
   put "0.6,0,-0.6,-0.6,0,-0.6,0,2.2,0" & return after tText
   put "-0.6,0,-0.6,-0.6,0,0.6,0,2.2,0" after tText
   return tText
end rtSpireTriangles

----------------------------------------------------------------------
-- 6. A mesh of your own: hills, corner by corner

constant kHillCells = 24
constant kHillStep = 0.5

function rtHillHeight pX, pZ
   return 0.7 * sin(pX * 0.9) * cos(pZ * 0.7) + 0.35 * sin(pX * 0.35 + pZ * 0.5)
end rtHillHeight

-- A square of pCells by pCells squares, each pStep metres, added corner
-- by corner to an empty mesh: flat, or with the hills' heights
function rtGridMesh pCells, pStep, pHilly
   local tMesh, tI, tJ, tX, tZ, tY, tA, tSide
   put rtMesh(r3MeshCreate()) into tMesh
   put pCells + 1 into tSide
   put 0 into tY
   repeat with tJ = 0 to pCells
      put (tJ - pCells / 2) * pStep into tZ
      repeat with tI = 0 to pCells
         put (tI - pCells / 2) * pStep into tX
         if pHilly is true then
            put rtHillHeight(tX, tZ) into tY
         end if
         get r3MeshAddVertex(tMesh, tX, tY, tZ, 0, 1, 0, tI / 4, tJ / 4)
      end repeat
   end repeat
   repeat with tJ = 0 to pCells - 1
      repeat with tI = 0 to pCells - 1
         put tJ * tSide + tI + 1 into tA
         -- two triangles a square, each counter-clockwise seen from above
         get r3MeshAddTriangle(tMesh, tA, tA + tSide, tA + 1, 1)
         get r3MeshAddTriangle(tMesh, tA + 1, tA + tSide, tA + tSide + 1, 1)
      end repeat
   end repeat
   r3MeshComputeNormals tMesh
   return tMesh
end rtGridMesh

command rtBuildTerrain
   local tMesh, tGrass
   put "Hills made corner by corner: this stack adds 625 corners and 1152 triangles to an empty mesh and asks render3dxt to work out which way each faces. The ball asks the same sum for the height under it. The camera goes round by itself; drag to take over." into field "About"
   put "0,0.3,0" into sTarget
   put 12 into sDist
   put 0.3 into sYaw
   put 0.45 into sPitch
   put 9 into sFogNear
   put 24 into sFogFar
   put rtGridMesh(kHillCells, kHillStep, true) into tMesh
   put rtTex(r3TextureChecker(32, 2, 96, 170, 90, 76, 146, 74)) into tGrass
   r3TextureSetRepeat tGrass, true
   get rtNode(tMesh, rtTexMat(tGrass), 0, 0, 0)
   put r3MeshVertexCount(tMesh) & comma & r3MeshTriangleCount(tMesh) into sParts["hill size"]
   put r3MeshBounds(tMesh) into sParts["hill bounds"]
   put rtNode(rtMesh(r3MeshSphere(0.3, 20, 10)), rtMat(240, 240, 250), 0, 1, 0) into sParts["ball"]
end rtBuildTerrain

command rtTickTerrain
   local tX, tZ
   put 4.5 * sin(sTime * 0.5) into tX
   put 4.5 * sin(sTime * 0.37 + 1) into tZ
   r3NodeSetPosition sParts["ball"], tX, rtHillHeight(tX, tZ) + 0.3, tZ
   if sDragging is not true then
      add sDelta * 0.15 to sYaw
      rtAim
   end if
end rtTickTerrain

----------------------------------------------------------------------
-- 7. Fog and distance: a walk between columns

constant kColumnGap = 3

command rtBuildColonnade
   local tColumn, tStone, tMesh, tTexture, tIndex
   put "A walk between two rows of columns. Fog fades what is far away into the sky's colour, so the rows seem to go on for ever; untick Fog and you can see where they stop. Here the camera walks by itself." into field "About"
   put true into sOwnCamera
   put 5 into sFogNear
   put 30 into sFogFar
   put "36,40,58" into sBack
   -- nothing farther than 70 metres is drawn at all
   r3SceneSetClip sScene, 0.05, 70
   put rtMesh(r3MeshPlane(6, 48, 4, 32)) into tMesh
   put rtTex(r3TextureChecker(64, 2, 120, 112, 100, 96, 90, 82)) into tTexture
   get rtNode(tMesh, rtTexMat(tTexture), 0, 0, -40)
   put rtMesh(r3MeshCylinder(0.35, 1.6, 20)) into tColumn
   put rtMat(226, 220, 205) into tStone
   repeat with tIndex = 0 to 17
      get rtNode(tColumn, tStone, -2.2, 1.6, 3 - tIndex * kColumnGap)
      get rtNode(tColumn, tStone, 2.2, 1.6, 3 - tIndex * kColumnGap)
   end repeat
   put r3SceneClip(sScene) into sParts["clip"]
end rtBuildColonnade

-- The camera walks one gap and starts again: every gap looks the same,
-- so the walk never seems to end
command rtTickColonnade
   local tZ
   put 4 - ((sTime * 1.5) mod kColumnGap) into tZ
   r3SceneSetCamera sScene, 0, 1.5, tZ, 0, 1.4, tZ - 10, 60
end rtTickColonnade

----------------------------------------------------------------------
-- 8. Click and aim: what is under a point, and what a ray meets

command rtBuildAim
   local tBall, tI, tJ, tNode, tMat, tCount
   put "Move the pointer over a ball and it lights up; click it and it turns gold. r3ScenePick says which thing is under a point of the picture and where it was touched. The red dot rides on whatever a ray cast straight down meets first: a ball, or the floor." into field "About"
   rtFloor 12, 56, 62, 80, 42, 47, 62
   put "0,0.4,0" into sTarget
   put 9 into sDist
   put 0.5 into sYaw
   put 0.6 into sPitch
   put rtMesh(r3MeshSphere(0.42, 20, 10)) into tBall
   put 0 into tCount
   repeat with tJ = -2 to 2
      repeat with tI = -2 to 2
         add 1 to tCount
         put rtMat(90, 150, 230) into tMat
         r3MaterialSetSpecular tMat, 0.5, 40
         put rtNode(tBall, tMat, tI * 1.2, 0.42, tJ * 1.2) into tNode
         -- a ball's tag is its number, 1 to 25
         r3NodeSetTag tNode, tCount
         put tMat into sParts["mat" & tCount]
         put false into sParts["gold" & tCount]
      end repeat
   end repeat
   put tCount into sParts["balls"]
   put rtMat(255, 60, 50) into tMat
   r3MaterialSetUnlit tMat, true
   put rtNode(rtMesh(r3MeshSphere(0.12, 12, 8)), tMat, 0, 5, 0) into sParts["dot"]
   put rtMat(255, 150, 140) into tMat
   r3MaterialSetUnlit tMat, true
   put rtNode(rtMesh(r3MeshCylinder(0.015, 0.5, 6)), tMat, 0, 5, 0) into sParts["beam"]
end rtBuildAim

-- A ray from high up, straight down: r3SceneRayCast says what it meets
-- and r3HitText where. The dot and its beam step aside while it is cast,
-- so the ray never finds them.
command rtTickAim
   local tX, tZ, tNode, tHit, tY
   put 2.6 * cos(sTime * 0.6) into tX
   put 2.6 * sin(sTime * 0.78) into tZ
   r3NodeSetVisible sParts["dot"], false
   r3NodeSetVisible sParts["beam"], false
   put r3SceneRayCast(sScene, tX, 6, tZ, 0, -1, 0) into tNode
   put 0 into tY
   if tNode is not 0 then
      put r3HitText() into tHit
      put item 2 of tHit into tY
   end if
   put tNode into sParts["under the ray"]
   r3NodeSetPosition sParts["dot"], tX, tY + 0.1, tZ
   r3NodeSetPosition sParts["beam"], tX, (6 + tY) / 2, tZ
   r3NodeSetScale sParts["beam"], 1, 6 - tY, 1
   r3NodeSetVisible sParts["dot"], true
   r3NodeSetVisible sParts["beam"], true
end rtTickAim

-- The colour a ball shows: gold when it was clicked, and lit from inside
-- while the pointer is over it
command rtPaintBall pTag
   local tMat
   put sParts["mat" & pTag] into tMat
   if tMat is empty then
      exit rtPaintBall
   end if
   if sParts["gold" & pTag] is true then
      r3MaterialSetColor tMat, 250, 196, 50
   else
      r3MaterialSetColor tMat, 90, 150, 230
   end if
   if sHover is pTag then
      r3MaterialSetEmissive tMat, 70, 70, 70
   else
      r3MaterialSetEmissive tMat, 0, 0, 0
   end if
end rtPaintBall

----------------------------------------------------------------------
-- 9. Many things: one call a frame moves them all

constant kManySide = 15

command rtBuildMany
   local tCube, tMats, tI, tJ, tNode, tCount
   put "225 cubes ride a wave. This stack writes one line of text for each (where it is and how it is turned) and hands the whole list to r3SceneApplyMoves in one call a frame. It is the list box3dxt writes for the bodies it simulates, which is how the two work together." into field "About"
   put "0,0.6,0" into sTarget
   put 12 into sDist
   put 0.6 into sYaw
   put 0.55 into sPitch
   put rtMesh(r3MeshBox(0.2, 0.2, 0.2)) into tCube
   put rtMat(240, 96, 80) & comma & rtMat(250, 190, 70) & comma & rtMat(100, 200, 130) & comma \
         & rtMat(80, 160, 240) & comma & rtMat(190, 120, 230) into tMats
   put 0 into tCount
   repeat with tJ = 1 to kManySide
      repeat with tI = 1 to kManySide
         add 1 to tCount
         put rtNode(tCube, item ((tI + tJ) mod 5) + 1 of tMats, 0, 0, 0) into tNode
         r3NodeSetTag tNode, tCount
      end repeat
   end repeat
   put tCount into sParts["cubes"]
end rtBuildMany

command rtTickMany
   local tMoves, tI, tJ, tCount, tX, tZ, tY, tAngle
   put 0 into tCount
   repeat with tJ = 1 to kManySide
      put (tJ - 8) * 0.6 into tZ
      repeat with tI = 1 to kManySide
         add 1 to tCount
         put (tI - 8) * 0.6 into tX
         put 0.7 + 0.45 * sin(sTime * 2 + tI * 0.5 + tJ * 0.35) into tY
         put sTime + tI * 0.2 + tJ * 0.2 into tAngle
         -- tag, where, how it is turned (a quaternion), and a last number
         -- that box3dxt uses and this stack does not
         put tCount & comma & tX & comma & tY & comma & tZ & ",0," & sin(tAngle / 2) & ",0," & cos(tAngle / 2) & ",0" & return after tMoves
      end repeat
   end repeat
   put r3SceneApplyMoves(sScene, tMoves) into sParts["moved"]
end rtTickMany

----------------------------------------------------------------------
-- The mouse over the picture

-- A click at pX, pY of the picture
command rtClickView pX, pY
   local tNode, tTag, tHit, tLamp
   if sScene is empty then
      exit rtClickView
   end if
   set the defaultStack to the short name of me
   put r3ScenePick(sScene, kViewW, kViewH, pX + 0.5, pY + 0.5) into tNode
   put empty into sPicked
   if tNode is not 0 then
      put r3HitText() into tHit
      put r3NodeTag(tNode) into tTag
      put "You touched something" && format("%.1f", item 4 of tHit) && "metres away, at" \
            && format("%.2f, %.2f, %.2f", item 1 of tHit, item 2 of tHit, item 3 of tHit) into sPicked
      if sExhibit is 4 and tTag >= 1 and tTag <= 3 then
         put sParts["lamp" & tTag] into tLamp
         r3LightSetEnabled tLamp, not r3LightIsEnabled(tLamp)
         r3NodeSetScale sParts["bulb" & tTag], 1, 1, 1
         if r3LightIsEnabled(tLamp) is not true then
            r3NodeSetScale sParts["bulb" & tTag], 0.5, 0.5, 0.5
         end if
      else if sExhibit is 8 and tTag >= 1 and tTag <= sParts["balls"] then
         put (sParts["gold" & tTag] is not true) into sParts["gold" & tTag]
         rtPaintBall tTag
      end if
   end if
   rtChanged
   rtShowStats
end rtClickView

-- The pointer at pX, pY of the picture, in "Click and aim"
command rtHoverView pX, pY
   local tNode, tTag, tWas
   if sScene is empty or sExhibit is not 8 then
      exit rtHoverView
   end if
   put r3ScenePick(sScene, kViewW, kViewH, pX + 0.5, pY + 0.5) into tNode
   put empty into tTag
   if tNode is not 0 and r3NodeTag(tNode) >= 1 and r3NodeTag(tNode) <= sParts["balls"] then
      put r3NodeTag(tNode) into tTag
   end if
   if tTag is sHover then
      exit rtHoverView
   end if
   put sHover into tWas
   put tTag into sHover
   if tWas is not empty then
      rtPaintBall tWas
   end if
   if tTag is not empty then
      rtPaintBall tTag
   end if
   rtChanged
end rtHoverView

----------------------------------------------------------------------
-- For the tests

command rtTestBegin
   put true into sTesting
   put false into sRunning
   if sFrameMsg is not empty then
      cancel sFrameMsg
      put empty into sFrameMsg
   end if
end rtTestBegin

-- Moves the exhibit on by pSeconds and draws it
command rtTestStep pSeconds
   if sScene is empty then
      exit rtTestStep
   end if
   set the defaultStack to the short name of me
   put pSeconds into sDelta
   add pSeconds to sTime
   rtTick
   rtDraw
   rtShowStats
end rtTestStep

-- How things are, a line each: name=value
function rtState
   local tState, tKey, tIndex, tLight
   put "have=" & (sHave is true) & return into tState
   put "exhibit=" & sExhibit & return after tState
   put "smooth=" & (sSmooth is true) & return after tState
   put "fog=" & (sFog is true) & return after tState
   put "spin=" & (sSpin is true) & return after tState
   put "picked=" & sPicked & return after tState
   put "hover=" & sHover & return after tState
   if sHave is true then
      put "live=" & r3LiveCounts() & return after tState
      if sScene is not empty then
         put "scene=" & sScene & return after tState
         put "nodes=" & r3SceneNodeCount(sScene) & return after tState
         put "lights=" & r3SceneLightCount(sScene) & return after tState
         put "ambient=" & r3SceneAmbient(sScene) & return after tState
         repeat with tIndex = 1 to r3SceneLightCount(sScene)
            put r3SceneLight(sScene, tIndex) into tLight
            put "light " & tIndex & "=" & r3LightKind(tLight) & ";" & r3LightColor(tLight) & ";" & r3LightVector(tLight) & ";" & r3LightIsEnabled(tLight) & return after tState
         end repeat
         put "stats=" & r3SceneStats(sScene) & return after tState
         put "camera=" & r3SceneCamera(sScene) & return after tState
         put "supersample=" & r3SceneSupersample(sScene) & return after tState
         put "frame=" & r3SceneFrameLength(sScene) & return after tState
      end if
   end if
   repeat for each key tKey in sParts
      if the number of lines of sParts[tKey] <= 1 then
         put "part " & tKey & "=" & sParts[tKey] & return after tState
      end if
   end repeat
   return tState
end rtState
