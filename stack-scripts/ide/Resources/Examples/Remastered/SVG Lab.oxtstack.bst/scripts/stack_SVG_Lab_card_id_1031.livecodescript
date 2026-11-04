script "stack_SVG_Lab_card_id_1031"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab" > card "Logo" (id 1031)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- Every frame: the logo's SVG, with new numbers for the rays, the glow, the shine, the
-- electricity and the sparks, compiled and shown. The template is the stack's cLogoLive

local sRunning, sMessage, sFrames, sStart

on openCard
   logoStart
   pass openCard
end openCard

on closeCard
   logoStop
   pass closeCard
end closeCard

command logoStart
   if sRunning then
      exit logoStart
   end if
   put true into sRunning
   put 0 into sFrames
   put the milliseconds into sStart
   put "Pause" into field "Pause_label" of group "Pause"
   logoTick
end logoStart

command logoStop
   put false into sRunning
   if sMessage is not empty then
      cancel sMessage
   end if
   put empty into sMessage
   put "Play" into field "Pause_label" of group "Pause"
end logoStop

command logoToggle
   if sRunning then
      logoStop
   else
      logoStart
   end if
end logoToggle

on logoTick
   local tDrawing
   if not sRunning then
      exit logoTick
   end if
   put svgCompile(logoFrame(), "all") into tDrawing
   if the result is not empty then
      put the result into field "Status"
      logoStop
      exit logoTick
   end if
   set the text of image "Logo Live" to tDrawing
   add 1 to sFrames
   if sFrames mod 15 is 0 then
      put round(sFrames * 1000 / max(1, the milliseconds - sStart)) && "frames a second, each a fresh SVG." into field "Status"
   end if
   send "logoTick" to me in 20 milliseconds
   put the result into sMessage
end logoTick

function logoFrame
   local tSvg, tTime
   put the milliseconds / 1000 into tTime
   put the cLogoLive of this stack into tSvg
   replace "@RAYS@" with round(tTime * 8 mod 360, 1) in tSvg
   replace "@GLOW@" with round(0.34 + 0.14 * sin(tTime * 2.5), 2) in tSvg
   replace "@HALO@" with round(0.5 + 0.2 * sin(tTime * 7) + random(30) / 100, 2) in tSvg
   replace "@SHINE@" with round(tTime * 520 mod 1500 - 100) in tSvg
   replace "@ARCS@" with logoArc(705, 250, -1) & logoArc(790, 300, 1) in tSvg
   replace "@SPARKS@" with logoSparks(tTime) in tSvg
   return tSvg
end logoFrame

-- A jagged bolt of electricity, new every frame, leaving the logo's bolt
function logoArc pX, pY, pSide
   local tPoints, tIndex
   put pX & comma & pY into tPoints
   repeat with tIndex = 1 to 5
      add pSide * (14 + random(30)) to pX
      subtract random(44) - 8 from pY
      put space & pX & comma & pY after tPoints
   end repeat
   return "<polyline class='arc' stroke='#BFEFFF' stroke-width='5' fill='none' opacity='" & (random(6) + 3) / 10 & "' points='" & tPoints & "'/>"
end logoArc

-- Sparks that drift out from the bolt and fade
function logoSparks pTime
   local tIndex, tOut, tAge, tAngle, tDistance
   repeat with tIndex = 1 to 16
      put pTime / 2.4 + tIndex * 0.137 into tAge
      put tAge - trunc(tAge) into tAge
      put tIndex * 2.4 into tAngle
      put 60 + tAge * 300 into tDistance
      put "<circle cx='" & round(720 + tDistance * cos(tAngle)) & "' cy='" & round(270 + tDistance * sin(tAngle)) & \
            "' r='" & 3 + tIndex mod 5 & "' fill='#FFF4B0' opacity='" & round(1 - tAge, 2) & "'/>" after tOut
   end repeat
   return tOut
end logoSparks
