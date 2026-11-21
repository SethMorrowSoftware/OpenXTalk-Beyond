script "TestRender3DTour"
-- OXT-Beyond: the Render3D Tour (the committed
-- tools/web-player/stacks/Render3D Tour.oxtstack, built by
-- tools/web-player/render3d-tour.livecodescript from
-- tools/web-player/render3d-tour-stack.livecodescript), on a desktop
-- engine.
--
-- The tour draws with render3dxt, the xTalk Suite's 3D renderer, which
-- the Stack Player's web engine has built in. A desktop engine has it
-- only as an extension: set OXT_RENDER3DXT to the extension's folder (its
-- module.lcm and its library), a folder with it in, or an installed
-- IDE's folder, and these tests load it (loadRenderer); without it the
-- tests of the pictures are skipped, and the tour is checked opening on
-- its notice.
--
-- The tour's clock is in the test's hands: rtTestBegin stops its loop,
-- rtTestStep moves an exhibit on and draws it, rtClickView and
-- rtHoverView are the mouse over the picture, and rtState says how
-- things are. The buttons are pressed as a finger does, by mouseUp.

constant kStack = "Render3D Tour"
constant kExtension = "org.openxtalk.library.renderthreed"
constant kViewW = 640
constant kViewH = 480

on TestSetup
   local tFile
   loadRenderer
   -- a desktop engine starts with "png": the tour must leave it so
   set the paintCompression to "png"
   put TestGetEngineRepositoryPath() & "/tools/web-player/stacks/Render3D Tour.oxtstack" into tFile
   go stack tFile
   tour "rtTestBegin"
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
end TestTeardown

-- render3dxt from OXT_RENDER3DXT, once (an engine that has it already, or
-- no such folder: nothing to do). The folder is the extension's own (its
-- module.lcm, and its library beside it or in code/<platform>/, as
-- tools/oxt/xtalk_extensions.py builds it), or one with the extension's
-- folder in it, or an installed IDE's (its Extensions folder)
private command loadRenderer
   local tRoot, tFolder, tTry, tLib, tPick, tError, tPlatform
   try
      get r3ABIVersion()
      exit loadRenderer
   catch tError
   end try
   put $OXT_RENDER3DXT into tRoot
   if tRoot is empty then
      exit loadRenderer
   end if
   repeat for each item tTry in ",/" & kExtension & ",/Extensions/" & kExtension
      if there is a file (tRoot & tTry & "/module.lcm") then
         put tRoot & tTry into tFolder
         exit repeat
      end if
   end repeat
   if tFolder is empty then
      exit loadRenderer
   end if
   switch the platform
      case "Win32"
         put "render3dxt.dll" into tLib
         put "-win32" into tPlatform
         break
      case "MacOS"
         put "render3dxt.dylib" into tLib
         put "-mac" into tPlatform
         break
      default
         put "render3dxt.so" into tLib
         put "-" & toLower(the platform) into tPlatform
   end switch
   if there is a file (tFolder & "/" & tLib) then
      set the revLibraryMapping["render3dxt"] to tFolder & "/" & tLib
   else
      -- code/<processor>-<platform>/: only this platform's folders (the
      -- extension carries Android's libraries under the same file name)
      repeat for each line tTry in folders(tFolder & "/code")
         if tPlatform is not in tTry then next repeat
         if there is a file (tFolder & "/code/" & tTry & "/" & tLib) then
            if tPick is empty or (tTry begins with (the processor & "-")) then
               put tFolder & "/code/" & tTry & "/" & tLib into tPick
            end if
         end if
      end repeat
      if tPick is not empty then
         set the revLibraryMapping["render3dxt"] to tPick
      end if
   end if
   try
      load extension from file (tFolder & "/module.lcm") with resource path tFolder
   end try
end loadRenderer

----------------------------------------------------------------------
-- Helpers

private command tour pHandler, p1, p2
   dispatch pHandler to stack kStack with p1, p2
end tour

-- One value of the tour's rtState
private function st pKey
   local tState
   dispatch function "rtState" to stack kStack
   put the result into tState
   split tState by return and "="
   return tState[pKey]
end st

private function drawing
   return st("have") is true
end drawing

private function needRenderer pWhat
   if drawing() then
      return true
   end if
   TestSkip pWhat, "no render3dxt here: set OXT_RENDER3DXT to a folder with its module.lcm and library"
   return false
end needRenderer

private command press pButton
   send "mouseUp" to button pButton of card "Tour" of stack kStack
end press

private function picture
   return the imageData of image "View" of card "Tour" of stack kStack
end picture

private function fieldText pName
   return the text of field pName of card "Tour" of stack kStack
end fieldText

-- How many pixels of pData, one in every 97, are not the colour of its
-- first pixel (the sky)
private function paintedPixels pData
   local tSky, tAt, tCount
   put byte 2 to 4 of pData into tSky
   put 0 into tCount
   repeat with tAt = 0 to kViewW * kViewH - 1 step 97
      if byte (tAt * 4 + 2) to (tAt * 4 + 4) of pData is not tSky then
         add 1 to tCount
      end if
   end repeat
   return tCount
end paintedPixels

-- Where in the picture a point of the scene is: "x,y", whole pixels
private function spotOf pX, pY, pZ
   local tSpot
   put r3SceneProject(st("scene"), kViewW, kViewH, pX, pY, pZ) into tSpot
   return trunc(item 1 of tSpot) & comma & trunc(item 2 of tSpot)
end spotOf

----------------------------------------------------------------------
-- Tests

on TestItOpens
   TestAssert "the tour is open", there is a stack kStack
   TestAssert "the picture's image is the picture's size", the width of image "View" of stack kStack is kViewW \
         and the height of image "View" of stack kStack is kViewH
   if drawing() then
      TestAssert "on the first exhibit", st("exhibit") is 1
      TestAssert "the notice is hidden", the visible of field "Missing" of stack kStack is false
      TestAssert "its button is lit", the hilite of button "Ex1" of stack kStack
   else
      TestAssert "without render3dxt, the notice says so", the visible of field "Missing" of stack kStack \
            and fieldText("Missing") contains "render3dxt"
      TestAssert "and no picture is shown", the visible of image "View" of stack kStack is false
   end if
end TestItOpens

on TestWithoutTheRendererNothingThrows
   if drawing() then
      exit TestWithoutTheRendererNothingThrows
   end if
   press "Ex4"
   press "Smooth"
   tour "rtTestStep", 1
   tour "rtClickView", 100, 100
   TestAssert "no exhibit", st("exhibit") is empty
end TestWithoutTheRendererNothingThrows

on TestEveryExhibitDrawsAPicture
   local tN, tData, tLive
   if not needRenderer("the ten exhibits") then
      exit TestEveryExhibitDrawsAPicture
   end if
   repeat with tN = 1 to 10
      press "Ex" & tN
      tour "rtTestStep", 0.5
      put picture() into tData
      TestAssert "exhibit" && tN && "is shown", st("exhibit") is tN and the hilite of button ("Ex" & tN) of stack kStack
      TestAssert "exhibit" && tN && "draws a whole picture", st("frame") is kViewW * kViewH * 4 \
            and the number of bytes of tData is kViewW * kViewH * 4
      TestAssert "exhibit" && tN && "draws triangles", item 1 of st("stats") > 10
      -- (the first exhibit is mostly night sky)
      TestAssert "exhibit" && tN && "paints over the sky", paintedPixels(tData) > 100
      TestAssert "exhibit" && tN && "says what it shows", the number of words of fieldText("About") > 15
      TestAssert "exhibit" && tN && "says what the picture cost", fieldText("Stats") contains "triangles, drawn in"
      -- the exhibit before is given back: one scene, and no more lights
      -- than one scene can hold
      put st("live") into tLive
      TestAssert "exhibit" && tN && "is the only scene alive", item 1 of tLive is 1 and item 2 of tLive is st("nodes")
   end repeat
   TestAssert "the paintCompression is left as it was found", the paintCompression is "png"
end TestEveryExhibitDrawsAPicture

on TestClosingGivesEverythingBack
   if not needRenderer("closing") then
      exit TestClosingGivesEverythingBack
   end if
   press "Ex9"
   tour "rtTestStep", 0.2
   close stack kStack
   TestAssert "no scene, node, mesh, material, texture or light is left", r3LiveCounts() is "0,0,0,0,0,0"
end TestClosingGivesEverythingBack

on TestTheSunAndItsPlanets
   local tAt, tSpot, tCamera
   if not needRenderer("the sun and its planets") then
      exit TestTheSunAndItsPlanets
   end if
   tour "rtGo", 1
   tour "rtTestStep", 0.5
   TestAssert "the lamp is in the sun, and the far sun is out", st("lights") is 2 and st("light 1") ends with "false" \
         and st("light 2") contains ";0,0,0;" and st("light 2") ends with "true"
   TestAssert "four planets, three moons, a ring, a comet and 160 stars", st("part planet4") is not empty and st("part moons") is 3 \
         and st("part moon3") is not empty and st("part ring") is not empty and st("part comet") is not empty and st("part stars") is 160
   TestAssert "it starts by showing them all", st("part focus") is 0 and fieldText("Tag1") contains "Click a planet"
   TestAssert "the corner says how fast, or that it is at rest", fieldText("Fps") is not empty
   put r3NodePosition(st("part planet3")) into tAt
   -- a click on planet 3 flies the camera to it, and names it
   put spotOf(item 1 of tAt, 0, item 3 of tAt) into tSpot
   tour "rtClickView", item 1 of tSpot, item 2 of tSpot
   TestAssert "a click on the giant chooses it", st("part focus") is 3 and fieldText("Stats") contains "Colossus"
   repeat 12 times
      tour "rtTestStep", 0.1
   end repeat
   put st("camera") into tCamera
   put r3NodePosition(st("part planet3")) into tAt
   -- from the side the sun lights: the camera is nearer the sun than the
   -- planet is
   TestAssert "it looks at the planet's day side", sqrt(item 1 of tCamera ^ 2 + item 3 of tCamera ^ 2) < sqrt(item 1 of tAt ^ 2 + item 3 of tAt ^ 2)
   TestAssert "the camera flies to it and looks at it", abs(item 4 of tCamera - item 1 of tAt) < 0.3 and abs(item 6 of tCamera - item 3 of tAt) < 0.3 \
         and sqrt((item 1 of tCamera - item 4 of tCamera) ^ 2 + (item 2 of tCamera - item 5 of tCamera) ^ 2 + (item 3 of tCamera - item 6 of tCamera) ^ 2) < 10
   TestAssert "and its name floats over it", fieldText("Tag1") is "Colossus" and the visible of field "Tag1" of card "Tour" of stack kStack
   -- its moons are its own: a click on one keeps the planet
   put r3NodePosition(st("part moon2")) into tAt
   put spotOf(item 1 of tAt, item 2 of tAt, item 3 of tAt) into tSpot
   tour "rtClickView", item 1 of tSpot, item 2 of tSpot
   TestAssert "a click on a moon is a click on its planet", st("part focus") is 3
   -- the sun, or the dark, shows everything again
   tour "rtFocusPlanet", 0
   repeat 20 times
      tour "rtTestStep", 0.1
   end repeat
   put st("camera") into tCamera
   TestAssert "and it comes back to the whole system", st("part focus") is 0 and abs(item 4 of tCamera) < 0.2 and abs(item 6 of tCamera) < 0.2 \
         and fieldText("Tag1") contains "Click a planet"
   tour "rtFocusPlanet", 99
   tour "rtFocusPlanet", "x"
   TestAssert "a planet that is not there is nobody", st("part focus") is 0
   tour "rtTestStep", 3
   TestAssert "the picture is drawn through all of it", the number of bytes of picture() is kViewW * kViewH * 4 and paintedPixels(picture()) > 40
end TestTheSunAndItsPlanets

-- How many rtFrame messages wait to be delivered
private function framesWaiting
   local tLine, tCount
   put 0 into tCount
   repeat for each line tLine in the pendingMessages
      if item 3 of tLine is "rtFrame" then
         add 1 to tCount
      end if
   end repeat
   return tCount
end framesWaiting

on TestTheLoopKeepsItsPace
   local tFrames, tSpan, tStarted
   if not needRenderer("the loop") then
      exit TestTheLoopKeepsItsPace
   end if
   tour "rtGo", 1
   put st("frames") into tFrames
   put the milliseconds into tStarted
   tour "rtTestEnd"
   wait 1500 milliseconds with messages
   put the milliseconds - tStarted into tSpan
   put st("frames") - tFrames into tFrames
   -- a frame is due every sixteen milliseconds and never sooner; a slow
   -- machine shows fewer, so only the top is strict
   TestAssert "the loop shows pictures, and never more than sixty-odd a second (" & tFrames && "in" && tSpan && "ms)", \
         tFrames >= 10 and tFrames <= tSpan / 15 + 2
   TestAssert "one frame is waiting, not a pile of them", framesWaiting() is 1
   TestAssert "the corner and the stats line say how fast", fieldText("Fps") contains "fps" and fieldText("Stats") contains "pictures a second" \
         and fieldText("Stats") contains "the longest wait"
   TestAssert "the badge is as wide as its words", abs(the width of field "Fps" of card "Tour" of stack kStack - the formattedWidth of field "Fps" of card "Tour" of stack kStack) <= 1
   tour "rtTestBegin"
   TestAssert "and it stops when told", framesWaiting() is 0 and st("running") is false
end TestTheLoopKeepsItsPace

on TestShapesAndTheirLabels
   local tN, tLoc, tRect
   if not needRenderer("the shapes") then
      exit TestShapesAndTheirLabels
   end if
   press "Ex2"
   tour "rtTestStep", 0.1
   TestAssert "a floor, four shapes and a model", st("nodes") is 6
   put the rect of image "View" of stack kStack into tRect
   repeat with tN = 1 to 5
      put the loc of field ("Tag" & tN) of stack kStack into tLoc
      TestAssert "label" && tN && "is shown over the picture", the visible of field ("Tag" & tN) of stack kStack \
            and tLoc is within tRect
   end repeat
   TestAssert "the labels run from left to right", item 1 of the loc of field "Tag1" of stack kStack \
         < item 1 of the loc of field "Tag5" of stack kStack
   TestAssert "the sixth label is not used", the visible of field "Tag6" of stack kStack is false
end TestShapesAndTheirLabels

on TestTexturesFromFourSources
   if not needRenderer("the textures") then
      exit TestTexturesFromFourSources
   end if
   press "Ex3"
   TestAssert "the PNG in the script is decoded", st("part lattice size") is "32x32"
   TestAssert "two checkers, the bricks, the lattice and the floor's", item 5 of st("live") is 5
end TestTexturesFromFourSources

on TestALampIsSwitchedByAClick
   local tLamp, tSpot
   if not needRenderer("the lamps") then
      exit TestALampIsSwitchedByAClick
   end if
   press "Ex5"
   tour "rtTestStep", 0.3
   TestAssert "a sun and three lamps", st("lights") is 4
   put st("part lamp2") into tLamp
   TestAssert "the lamp is on", r3LightIsEnabled(tLamp)
   put r3LightVector(tLamp) into tSpot
   put spotOf(item 1 of tSpot, item 2 of tSpot, item 3 of tSpot) into tSpot
   tour "rtClickView", item 1 of tSpot, item 2 of tSpot
   TestAssert "a click on its bulb switches it off", r3LightIsEnabled(tLamp) is false
   TestAssert "and says where the click landed", st("picked") contains "metres away"
   tour "rtClickView", item 1 of tSpot, item 2 of tSpot
   TestAssert "and another switches it on", r3LightIsEnabled(tLamp)
end TestALampIsSwitchedByAClick

on TestTheModelComesFromText
   if not needRenderer("the model") then
      exit TestTheModelComesFromText
   end if
   press "Ex6"
   TestAssert "the model's file names two materials", st("part slots") is "walls,roof"
   TestAssert "its faces become triangles", st("part house triangles") is 14
   TestAssert "the words name the picture the file asks for", fieldText("About") contains "bricks.png"
end TestTheModelComesFromText

on TestTheHillsAreBuiltCornerByCorner
   local tBounds
   if not needRenderer("the hills") then
      exit TestTheHillsAreBuiltCornerByCorner
   end if
   press "Ex7"
   TestAssert "the hill has 625 corners and 1152 triangles", st("part hill size") is "625,1152"
   put st("part hill bounds") into tBounds
   TestAssert "twelve metres each way", item 1 of tBounds is -6 and item 4 of tBounds is 6 \
         and item 3 of tBounds is -6 and item 6 of tBounds is 6
   TestAssert "with hills and valleys", item 2 of tBounds < -0.5 and item 5 of tBounds > 0.5
end TestTheHillsAreBuiltCornerByCorner

on TestTheWalkAndItsFog
   local tCamera, tFoggy
   if not needRenderer("the colonnade") then
      exit TestTheWalkAndItsFog
   end if
   press "Ex8"
   tour "rtTestStep", 0.2
   put st("camera") into tCamera
   TestAssert "nothing is drawn past seventy metres", st("part clip") is "0.05,70"
   put picture() into tFoggy
   tour "rtTestStep", 0.5
   TestAssert "the camera walks", item 3 of st("camera") < item 3 of tCamera
   -- dragging does not move a camera the exhibit moves itself
   put st("camera") into tCamera
   tour "rtOrbitBy", 40, 10
   TestAssert "a drag leaves the walk alone", st("camera") is tCamera
   put picture() into tFoggy
   TestAssert "Fog is ticked", the hilite of button "Fog" of stack kStack and st("fog") is true
   press "Fog"
   TestAssert "Fog unticks", the hilite of button "Fog" of stack kStack is false and st("fog") is false
   TestAssert "and the picture changes", picture() is not tFoggy
   press "Fog"
   TestAssert "ticked again, the picture is as it was", picture() is tFoggy
end TestTheWalkAndItsFog

on TestPointingAndClicking
   local tSpot
   if not needRenderer("click and aim") then
      exit TestPointingAndClicking
   end if
   press "Ex9"
   tour "rtTestStep", 0.3
   TestAssert "twenty-five balls", st("part balls") is 25
   TestAssert "the ray cast down meets something", st("part under the ray") is not 0
   -- the ball in the middle, number 13, sits at 0, 0.42, 0
   put spotOf(0, 0.42, 0) into tSpot
   tour "rtHoverView", item 1 of tSpot, item 2 of tSpot
   TestAssert "the pointer over the middle ball finds it", st("hover") is 13
   tour "rtClickView", item 1 of tSpot, item 2 of tSpot
   TestAssert "a click turns it gold", st("part gold13") is true
   TestAssert "and says where it was touched", st("picked") contains "metres away"
   tour "rtClickView", item 1 of tSpot, item 2 of tSpot
   TestAssert "another click turns it back", st("part gold13") is false
   tour "rtHoverView", 2, 2
   TestAssert "the pointer over the sky finds nothing", st("hover") is empty
end TestPointingAndClicking

on TestManyThingsMoveInOneCall
   local tBefore
   if not needRenderer("the wave") then
      exit TestManyThingsMoveInOneCall
   end if
   press "Ex10"
   tour "rtTestStep", 0.1
   TestAssert "there are 225 cubes", st("part cubes") is 225 and st("nodes") is 225
   TestAssert "one call moved them all", st("part moved") is 225
   put picture() into tBefore
   tour "rtTestStep", 0.4
   TestAssert "and the picture moves", picture() is not tBefore
end TestManyThingsMoveInOneCall

on TestSmoothEdges
   local tWas
   if not needRenderer("smooth edges") then
      exit TestSmoothEdges
   end if
   press "Ex2"
   put st("smooth") into tWas
   TestAssert "the box and the scene agree", the hilite of button "Smooth" of stack kStack is tWas \
         and (st("supersample") is 2) is tWas
   press "Smooth"
   TestAssert "the box changes the scene", the hilite of button "Smooth" of stack kStack is not tWas \
         and (st("supersample") is 2) is not tWas
   press "Ex3"
   TestAssert "and the next exhibit keeps it", (st("supersample") is 2) is not tWas
   press "Smooth"
end TestSmoothEdges

on TestTheCamera
   local tCamera
   if not needRenderer("the camera") then
      exit TestTheCamera
   end if
   press "Ex2"
   put st("camera") into tCamera
   tour "rtOrbitBy", 60, 0
   TestAssert "a drag walks the camera round", item 1 of st("camera") is not item 1 of tCamera
   put st("camera") into tCamera
   tour "rtZoom", 0.5
   TestAssert "the wheel comes closer", abs(item 3 of st("camera")) < abs(item 3 of tCamera)
   tour "rtZoom", 0.01
   TestAssert "but never into the things", item 1 of st("camera") ^ 2 + item 3 of st("camera") ^ 2 > 4
end TestTheCamera
