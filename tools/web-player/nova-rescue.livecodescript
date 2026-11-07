script "NovaRescueBuilder"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- Builds stacks/Nova Rescue.oxtstack, a space game for a phone, made with
-- the Mobile Web library (extensions/script-libraries/mobileweb). The
-- stack is never edited by hand: change this script, or the game's script
-- (nova-rescue-stack.livecodescript beside it), and build it again, with
-- any OXT-Beyond engine (the IDE's, or the development engine of a build):
--
--    <engine> -ui tools/web-player/nova-rescue.livecodescript
--
-- OXT_NOVA_RESCUE names another file to write. It prints "BUILT <file>"
-- or "FAILED <why>".
--
-- What goes in:
--   card "Art"    every picture of nova-rescue/art (art.txt), each the
--                 size the game draws it at, from a file with two or
--                 three times as many pixels: a sprite is a button whose
--                 icon is one of them, and a button draws its icon at the
--                 image's size, so the extra pixels keep it sharp on a
--                 phone's screen. The card is never shown.
--   card "Space"  the game: the stars, a fixed set of sprites for each
--                 kind of thing that flies (made once, shown and hidden,
--                 never created while it plays), the HUD, the banner, and
--                 the screens (Title, Howto, Paused, Over, Settings), each
--                 a group over the play area
--   the sounds    nova-rescue/sounds, as the custom property set cSounds
--   the font      KenVector Future, as the custom property cFont, which
--                 the game hands to "start using font file" as it opens
--
-- Every place and size of a control is set by the game's nrLayout as it
-- opens and whenever the window changes: here they are only made, with
-- their look. The stack's script is set last, so that nothing it does
-- runs while the stack is built.

constant kWidth = 390
constant kHeight = 760

-- The sprites: name of the pool, how many, and the picture each starts
-- with (the game sets another as it uses one)
constant kPools = "Pod:3:astronaut1,Power:3:power-twin,Rock:10:meteor-big1,Foe:8:scout,Bolt:12:bolt,Laser:12:laser,Fx:16:smoke1"
constant kStars = 26
constant kPops = 5

-- How big the game draws each picture, as a share of the size of
-- Kenney's PNG (art.txt): a phone is about 390 points across, and the
-- packs are drawn for a screen three times as wide
constant kScales = "ship=0.6,ship-damage1=0.6,ship-damage2=0.6,ship-damage3=0.6,life=0.66,flame1=0.6,flame2=0.6,shield=0.64,laser=0.66,laser-hit=0.5,bolt=0.66,bolt-hit=0.5,scout=0.55,weaver=0.52,gunship=0.6,ufo=0.56,meteor-big1=0.6,meteor-big2=0.62,meteor-big3=0.6,meteor-med1=0.66,meteor-med2=0.66,meteor-med3=0.66,meteor-small1=0.7,meteor-small2=0.7,meteor-small3=0.7,power-twin=0.8,power-shield=0.8,power-repair=0.8,star=0.76,spark1=0.6,spark2=0.6,spark3=0.6,astronaut1=0.8,astronaut2=0.8,astronaut3=0.8,mothership=0.85,missile=0.6,smoke1=0.9,smoke2=0.9,smoke3=0.9,logo-nova=1"

-- The look (the game's script has the same colours)
constant kFont = "KenVector Future"
constant kAmber = "#FFB52E"
constant kAmberDown = "#D18A12"
constant kInk = "#FFFFFF"
constant kDark = "#2A1A05"
constant kMuted = "#B9B2E0"
constant kGood = "#7CF29A"
constant kBad = "#FF5D73"
constant kPanel = "#221A3C"
constant kPanelDown = "#3A2E66"
constant kEdge = "#7C6CF0"

on startup
   local tFile, tError
   put $OXT_NOVA_RESCUE into tFile
   if tFile is empty then
      put the effective filename of me into tFile
      set the itemDelimiter to slash
      put "stacks/Nova Rescue.oxtstack" into the last item of tFile
      set the itemDelimiter to comma
   end if
   try
      buildStack tFile
   catch tError
      write "FAILED" && tError & return to stdout
      quit 1
   end try
   write "BUILT" && tFile & return to stdout
   quit 0
end startup

private command buildStack pFile
   local tName, tScript
   put "Nova Rescue" into tName
   if there is a stack tName then
      delete stack tName
   end if
   create invisible stack tName
   set the defaultStack to tName
   set the rect of stack tName to 100, 60, 100 + kWidth, 60 + kHeight
   set the minWidth of stack tName to 320
   set the minHeight of stack tName to 480
   set the resizable of stack tName to true
   set the backgroundColor of stack tName to "#140F26"
   set the textFont of stack tName to empty
   set the textSize of stack tName to 14
   -- the page calls nrPageHidden when it is hidden (another app, a
   -- locked phone), so that a run never plays on behind it; nrState says
   -- how the game is, for the checks of its page on the web site
   -- (tools/pages/check_nova_rescue_page.py), which play it there as
   -- anyone would
   set the cJavascriptHandlers of stack tName to "nrPageHidden" & return & "nrState"

   -- the pictures, on a card of their own
   set the name of card 1 of stack tName to "Space"
   create card "Art"
   importArt
   importSounds tName
   importFont tName

   go card "Space" of stack tName
   -- Kenney's dark purple space, as a colour: the engine draws a card's
   -- pattern for every pixel it draws again, and in a phone's browser
   -- that was most of a frame (a frame took four times as long)
   set the backgroundColor of card "Space" to "#3A2E3F"
   buildPlay
   buildHud
   buildBanner
   buildShade
   buildTitle
   buildHowto
   buildPaused
   buildOver
   buildSettings

   -- last: the script, which lays everything out as the stack opens
   put stackScript() into tScript
   set the script of stack tName to tScript
   if the result is not empty then
      throw "the stack's script does not compile:" && the result
   end if
   set the visible of stack tName to true
   save stack tName as pFile
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
end buildStack

-- A file beside this script, in nova-rescue/
private function assetPath pName
   local tFile
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "nova-rescue/" & pName into the last item of tFile
   return tFile
end assetPath

private function fileText pFile
   local tText
   open file pFile for "UTF-8" text read
   if the result is not empty then
      throw "cannot read" && pFile & ":" && the result
   end if
   read from file pFile until end
   put it into tText
   close file pFile
   return tText
end fileText

private function fileData pFile
   local tData
   if there is not a file pFile then
      throw "no file" && pFile
   end if
   put url ("binfile:" & pFile) into tData
   if tData is empty then
      throw "cannot read" && pFile
   end if
   return tData
end fileData

-- Every picture of art.txt, the size the game draws it at
private command importArt
   local tScales, tLine, tName, tFile, tWidth, tHeight, tX, tY, tRowH
   put kScales into tScales
   split tScales by comma and "="
   put 0 into tX
   put 0 into tY
   put 0 into tRowH
   repeat for each line tLine in fileText(assetPath("art/art.txt"))
      if tLine is empty or char 1 of tLine is "#" then
         next repeat
      end if
      set the itemDelimiter to tab
      put item 1 of tLine into tName
      put item 2 of tLine into tFile
      put item 3 of tLine into tWidth
      put item 4 of tLine into tHeight
      set the itemDelimiter to comma
      if tScales[tName] is empty then
         throw "no size for the picture" && tName
      end if
      import paint from file assetPath("art/" & tFile)
      if the result is not empty then
         throw "cannot import" && tFile & ":" && the result
      end if
      set the name of last image to tName
      put round(tWidth * tScales[tName]) into tWidth
      put round(tHeight * tScales[tName]) into tHeight
      -- (laid out in rows, so that the card can be looked at)
      if tX + tWidth > 600 then
         put 0 into tX
         add tRowH + 4 to tY
         put 0 into tRowH
      end if
      set the lockLoc of image tName to true
      set the rect of image tName to tX, tY, tX + tWidth, tY + tHeight
      set the resizeQuality of image tName to "good"
      add tWidth + 4 to tX
      put max(tRowH, tHeight) into tRowH
      delete variable tScales[tName]
   end repeat
   if the keys of tScales is not empty then
      throw "no picture for" && the keys of tScales
   end if
end importArt

private command importSounds pStack
   local tFolder, tFile, tFiles
   put assetPath("sounds") into tFolder
   set the defaultFolder to tFolder
   put the files into tFiles
   repeat for each line tFile in tFiles
      if tFile ends with ".wav" then
         set the cSounds[char 1 to -5 of tFile] of stack pStack to fileData(tFolder & "/" & tFile)
      end if
   end repeat
   if the number of lines of the customKeys["cSounds"] of stack pStack < 15 then
      throw "the sounds are not all there:" && the customKeys["cSounds"] of stack pStack
   end if
end importSounds

private command importFont pStack
   set the cFont of stack pStack to fileData(assetPath("fonts/kenvector_future.ttf"))
end importFont

-- The play area, back to front: the dimmed sides (in landscape), the
-- stars, then the sprites, each in its pool, then the floating scores
-- and the red flash of a hit
private command buildPlay
   local tPool, tName, tCount, tPicture, i
   repeat for each item tName in "Dim Left,Dim Right"
      create graphic tName
      setBox the long id of graphic tName, "#000000"
      set the blendLevel of graphic tName to 45
      set the visible of graphic tName to false
   end repeat
   repeat for each item tName in "Edge Left,Edge Right"
      create graphic tName
      set the style of graphic tName to "line"
      set the lineSize of graphic tName to 2
      set the foregroundColor of graphic tName to "#3C2F6E"
      set the visible of graphic tName to false
   end repeat
   repeat with i = 1 to kStars
      create graphic ("Star" && i)
      set the style of graphic ("Star" && i) to "oval"
      set the opaque of graphic ("Star" && i) to true
      set the lineSize of graphic ("Star" && i) to 0
      if i mod 3 is 0 then
         set the backgroundColor of graphic ("Star" && i) to "#FFFFFF"
      else if i mod 3 is 1 then
         set the backgroundColor of graphic ("Star" && i) to "#9C92D8"
      else
         set the backgroundColor of graphic ("Star" && i) to "#C9C2F2"
      end if
   end repeat
   -- the ring that marks each astronaut
   repeat with i = 1 to 3
      create graphic ("Ring" && i)
      set the style of graphic ("Ring" && i) to "oval"
      set the opaque of graphic ("Ring" && i) to false
      set the lineSize of graphic ("Ring" && i) to 2
      set the foregroundColor of graphic ("Ring" && i) to kGood
      set the visible of graphic ("Ring" && i) to false
   end repeat
   local tFx
   repeat for each item tPool in kPools
      set the itemDelimiter to ":"
      put item 1 of tPool into tName
      put item 2 of tPool into tCount
      put item 3 of tPool into tPicture
      set the itemDelimiter to comma
      if tName is "Laser" then
         -- the ship's flame and its lasers under the ship
         makeSprite "Flame", "flame1"
      end if
      if tName is "Bolt" then
         makeSprite "Boss", "mothership"
      end if
      repeat with i = 1 to tCount
         makeSprite tName && i, tPicture
      end repeat
      if tName is "Fx" then
         put tCount into tFx
      end if
   end repeat
   makeSprite "Ship", "ship"
   makeSprite "Cracks", "ship-damage1"
   makeSprite "Shield", "shield"
   -- (the explosions over the ship: made last of the sprites)
   repeat with i = 1 to tFx
      set the layer of button ("Fx" && i) to top
   end repeat
   repeat with i = 1 to kPops
      create field ("Pop" && i)
      setLabel the long id of field ("Pop" && i), empty, 15, kInk, "bold", "center"
      set the visible of field ("Pop" && i) to false
   end repeat
   create graphic "Flash"
   setBox the long id of graphic "Flash", kBad
   set the blendLevel of graphic "Flash" to 70
   set the visible of graphic "Flash" to false
end buildPlay

-- A sprite: a button that is only its icon
private command makeSprite pName, pPicture, pGroup
   if pGroup is empty then
      create button pName
   else
      create button pName in group pGroup
   end if
   set the style of button pName to "transparent"
   set the showName of button pName to false
   set the showBorder of button pName to false
   set the threeD of button pName to false
   set the opaque of button pName to false
   set the autoHilite of button pName to false
   set the showFocusBorder of button pName to false
   set the traversalOn of button pName to false
   set the margins of button pName to 0
   set the icon of button pName to the id of image pPicture of card "Art"
   set the rect of button pName to 0, 0, the width of image pPicture of card "Art", \
         the height of image pPicture of card "Art"
   set the visible of button pName to false
end makeSprite

-- The score, the streak, the sector's crew, the hull and the pause
-- button; the mothership's health under them
private command buildHud
   local i
   create group "HUD"
   create field "Score" in group "HUD"
   setLabel the long id of field "Score", "0", 24, kInk, "plain", "left"
   create field "Sector" in group "HUD"
   setLabel the long id of field "Sector", "SECTOR 1", 12, kMuted, "plain", "left"
   create graphic "Bar Back" in group "HUD"
   setBox the long id of graphic "Bar Back", "#3B3170"
   create graphic "Bar Fill" in group "HUD"
   setBox the long id of graphic "Bar Fill", kGood
   create field "Crew" in group "HUD"
   setLabel the long id of field "Crew", "0/5", 12, kGood, "plain", "left"
   create field "Streak" in group "HUD"
   -- (the bonus in the stack's own font: KenVector's X is hard to tell
   -- from its H)
   setLabel the long id of field "Streak", "x1", 22, kAmber, "bold", "right"
   set the textFont of field "Streak" to empty
   create field "Streak Label" in group "HUD"
   -- (11 points, not 10: the browser cuts KenVector Future off half way
   -- down its letters at 10)
   setLabel the long id of field "Streak Label", "BONUS", 11, kMuted, "plain", "right"
   repeat with i = 1 to 3
      create button ("Hull" && i) in group "HUD"
      setIcon the long id of button ("Hull" && i), "life"
   end repeat
   -- the pause button: its two bars between its shape and its face
   makeShape "Pause", "HUD", false
   create graphic "Pause Bar 1" in group "HUD"
   setBox the long id of graphic "Pause Bar 1", kInk
   create graphic "Pause Bar 2" in group "HUD"
   setBox the long id of graphic "Pause Bar 2", kInk
   makeFace "Pause", empty, "HUD", false
   set the showName of button "Pause" to false
   create field "Boss Label" in group "HUD"
   setLabel the long id of field "Boss Label", "MOTHERSHIP", 11, kBad, "plain", "center"
   create graphic "Boss Back" in group "HUD"
   setBox the long id of graphic "Boss Back", "#3A1630"
   create graphic "Boss Fill" in group "HUD"
   setBox the long id of graphic "Boss Fill", kBad
   repeat for each item i in "Boss Label,Boss Back,Boss Fill"
      set the visible of control i of group "HUD" to false
   end repeat
   set the visible of group "HUD" to false
end buildHud

-- A sector's name, a warning, and what a sector clear was worth
private command buildBanner
   create group "Banner"
   create graphic "Stripe" in group "Banner"
   setBox the long id of graphic "Stripe", kAmber
   create field "Banner Text" in group "Banner"
   setLabel the long id of field "Banner Text", empty, 28, kInk, "plain", "center"
   create field "Banner Sub" in group "Banner"
   setLabel the long id of field "Banner Sub", empty, 14, kAmber, "plain", "center"
   set the visible of group "Banner" to false
end buildBanner

-- The dark veil over the play area, behind a panel
private command buildShade
   create graphic "Shade"
   setBox the long id of graphic "Shade", "#07040F"
   set the blendLevel of graphic "Shade" to 35
   set the visible of graphic "Shade" to false
end buildShade

private command buildTitle
   create group "Title"
   -- (a picture: KenVector Future draws a V as a U, so "NOVA" would say
   -- NOUA; tools/web-player/nova-rescue/make_assets.py draws it)
   makeSprite "Logo Nova", "logo-nova", "Title"
   set the visible of button "Logo Nova" to true
   create field "Logo Rescue" in group "Title"
   setLabel the long id of field "Logo Rescue", "R E S C U E", 26, kInk, "plain", "center"
   create graphic "Logo Line" in group "Title"
   set the style of graphic "Logo Line" to "line"
   set the lineSize of graphic "Logo Line" to 2
   set the foregroundColor of graphic "Logo Line" to kEdge
   create field "Tagline" in group "Title"
   setText the long id of field "Tagline", "Fly the rescue cutter. Save the stranded crews.", 15, kMuted, "center"
   makeButton "Play", "PLAY", "Title", true
   makeButton "Howto Open", "HOW TO PLAY", "Title", false
   makeButton "Settings Open", "SETTINGS", "Title", false
   create field "Records" in group "Title"
   setLabel the long id of field "Records", "BEST 0", 13, kMuted, "plain", "center"
   set the visible of group "Title" to false
end buildTitle

private command buildHowto
   local i, tTitles, tTexts, tIcons
   create group "Howto"
   makePanel "Howto"
   create field "Howto Title" in group "Howto"
   setLabel the long id of field "Howto Title", "HOW TO PLAY", 20, kAmber, "plain", "center"
   put "DRAG TO FLY,RESCUE THE CREW,DODGE AND BLAST,GRAB POWER-UPS" into tTitles
   put "Put a finger anywhere and slide it: the cutter moves as your finger does, and fires on its own." & return & \
         "Fly over the drifting astronauts. Each rescue in a row raises your bonus, up to x5; one that drifts away starts it again." & return & \
         "A meteor, a raider or a shot takes a hull point. Lose all three and the run is over." & return & \
         "Raiders sometimes drop twin lasers, a shield or a repair. Every few sectors, a mothership." into tTexts
   put "ship,astronaut1,meteor-med1,power-shield" into tIcons
   repeat with i = 1 to 4
      create button ("Howto Icon" && i) in group "Howto"
      setIcon the long id of button ("Howto Icon" && i), item i of tIcons
      set the visible of button ("Howto Icon" && i) to true
      create field ("Howto Head" && i) in group "Howto"
      setLabel the long id of field ("Howto Head" && i), item i of tTitles, 13, kInk, "plain", "left"
      create field ("Howto Text" && i) in group "Howto"
      setText the long id of field ("Howto Text" && i), line i of tTexts, 14, kMuted, "left"
   end repeat
   makeButton "Howto Go", "GOT IT", "Howto", true
   set the visible of group "Howto" to false
end buildHowto

private command buildPaused
   create group "Paused"
   makePanel "Paused"
   create field "Paused Title" in group "Paused"
   setLabel the long id of field "Paused Title", "PAUSED", 24, kInk, "plain", "center"
   makeButton "Resume", "RESUME", "Paused", true
   makeButton "Restart", "RESTART", "Paused", false
   makeButton "Pause Settings", "SETTINGS", "Paused", false
   makeButton "Pause Home", "HOME", "Paused", false
   set the visible of group "Paused" to false
end buildPaused

private command buildOver
   create group "Over"
   makePanel "Over"
   create field "Over Title" in group "Over"
   setLabel the long id of field "Over Title", "HULL LOST", 22, kBad, "plain", "center"
   create field "Final" in group "Over"
   setLabel the long id of field "Final", "0", 40, kAmber, "plain", "center"
   create field "Best Note" in group "Over"
   setLabel the long id of field "Best Note", empty, 14, kGood, "plain", "center"
   create field "Stats" in group "Over"
   setLabel the long id of field "Stats", empty, 12, kMuted, "plain", "center"
   makeButton "Again", "PLAY AGAIN", "Over", true
   makeButton "Over Home", "HOME", "Over", false
   set the visible of group "Over" to false
end buildOver

private command buildSettings
   create group "Settings"
   makePanel "Settings"
   create field "Settings Title" in group "Settings"
   setLabel the long id of field "Settings Title", "SETTINGS", 22, kInk, "plain", "center"
   makeButton "Sound", "SOUND: ON", "Settings", false
   makeButton "Buzz", "BUZZ: ON", "Settings", false
   makeButton "Controls", "CONTROLS: DRAG", "Settings", false
   makeButton "Full", "FULL SCREEN", "Settings", false
   create field "Settings Note" in group "Settings"
   setText the long id of field "Settings Note", empty, 13, kAmber, "center"
   create field "Credits" in group "Settings"
   setText the long id of field "Credits", "Pictures, sounds and the KenVector font by Kenney (kenney.nl), CC0. Made with OXT-Beyond.", 12, kMuted, "center"
   makeButton "Settings Back", "DONE", "Settings", true
   set the visible of group "Settings" to false
end buildSettings

-- A panel's glass and the brackets at two of its corners (the game
-- draws them for the panel's size)
private command makePanel pGroup
   create graphic (pGroup && "Glass") in group pGroup
   set the style of graphic (pGroup && "Glass") to "polygon"
   set the opaque of graphic (pGroup && "Glass") to true
   set the filled of graphic (pGroup && "Glass") to true
   set the backgroundColor of graphic (pGroup && "Glass") to kPanel
   set the lineSize of graphic (pGroup && "Glass") to 2
   set the foregroundColor of graphic (pGroup && "Glass") to kEdge
   set the antialiased of graphic (pGroup && "Glass") to true
   create graphic (pGroup && "Trim") in group pGroup
   set the style of graphic (pGroup && "Trim") to "polygon"
   set the opaque of graphic (pGroup && "Trim") to false
   set the filled of graphic (pGroup && "Trim") to false
   set the lineSize of graphic (pGroup && "Trim") to 3
   set the foregroundColor of graphic (pGroup && "Trim") to kAmber
   set the antialiased of graphic (pGroup && "Trim") to true
end makePanel

-- A button of the screens: its shape, a polygon with two corners cut
-- (amber for the main one), and over it a button with no look of its
-- own, its label, which takes the taps. The game sets the shape's points
-- for its place; the shape's cUp and cDown are its colours, up and
-- pressed.
private command makeButton pName, pLabel, pGroup, pMain
   makeShape pName, pGroup, pMain
   makeFace pName, pLabel, pGroup, pMain
end makeButton

private command makeShape pName, pGroup, pMain
   local tShape
   put pName && "Shape" into tShape
   create graphic tShape in group pGroup
   set the style of graphic tShape to "polygon"
   set the opaque of graphic tShape to true
   set the filled of graphic tShape to true
   set the antialiased of graphic tShape to true
   if pMain then
      set the backgroundColor of graphic tShape to kAmber
      set the cUp of graphic tShape to kAmber
      set the cDown of graphic tShape to kAmberDown
      set the lineSize of graphic tShape to 0
   else
      set the backgroundColor of graphic tShape to kPanel
      set the cUp of graphic tShape to kPanel
      set the cDown of graphic tShape to kPanelDown
      set the lineSize of graphic tShape to 2
      set the foregroundColor of graphic tShape to kEdge
   end if
end makeShape

private command makeFace pName, pLabel, pGroup, pMain
   create button pName in group pGroup
   set the style of button pName to "transparent"
   set the showBorder of button pName to false
   set the threeD of button pName to false
   set the opaque of button pName to false
   set the autoHilite of button pName to false
   set the showFocusBorder of button pName to false
   set the traversalOn of button pName to false
   set the showName of button pName to true
   set the label of button pName to pLabel
   set the textFont of button pName to kFont
   if pMain then
      set the textSize of button pName to 20
      set the textColor of button pName to kDark
   else
      set the textSize of button pName to 15
      set the textColor of button pName to kInk
   end if
   set the script of button pName to buttonScript()
end makeFace

-- Every button of the screens: pressed, it looks pressed; let go on it,
-- it does what it is for (nrPress, in the stack's script). A second tap
-- soon after the first comes as mouseDoubleDown and mouseDoubleUp.
private function buttonScript
   return "on mouseDown" & return & "   nrButtonLook the short name of me, true" & return & "end mouseDown" & return & \
         "on mouseDoubleDown" & return & "   nrButtonLook the short name of me, true" & return & "end mouseDoubleDown" & return & \
         "on mouseUp" & return & "   nrButtonLook the short name of me, false" & return & \
         "   nrPress the short name of me" & return & "end mouseUp" & return & \
         "on mouseDoubleUp" & return & "   nrButtonLook the short name of me, false" & return & \
         "   nrPress the short name of me" & return & "end mouseDoubleUp" & return & \
         "on mouseRelease" & return & "   nrButtonLook the short name of me, false" & return & "end mouseRelease"
end buttonScript

-- A filled rectangle with no border
private command setBox pObject, pColor
   set the style of pObject to "rectangle"
   set the opaque of pObject to true
   set the filled of pObject to true
   set the lineSize of pObject to 0
   set the showBorder of pObject to false
   set the backgroundColor of pObject to pColor
end setBox

-- A field that is a label, in the game's font: locked, no frame, no
-- focus, no margins (the game places it to the point)
private command setLabel pField, pText, pSize, pColor, pStyle, pAlign
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to true
   set the margins of pField to 0
   set the textFont of pField to kFont
   set the textSize of pField to pSize
   set the textColor of pField to pColor
   set the textStyle of pField to pStyle
   set the textAlign of pField to pAlign
   set the text of pField to pText
end setLabel

-- A field of words, in the stack's own font, that wraps. It is 4 points
-- deeper above and below its lines: with no margins, a field as tall as
-- its formattedHeight cut off the tops of its first line and the tails
-- of its last (y, g, p), on Windows and in a browser
private command setText pField, pText, pSize, pColor, pAlign
   set the lockText of pField to true
   set the traversalOn of pField to false
   set the opaque of pField to false
   set the showBorder of pField to false
   set the threeD of pField to false
   set the dontWrap of pField to false
   set the margins of pField to "0,4,0,4"
   set the textSize of pField to pSize
   set the textColor of pField to pColor
   set the textAlign of pField to pAlign
   set the text of pField to pText
end setText

-- A button that is a picture, in a screen or the HUD
private command setIcon pButton, pPicture
   set the style of pButton to "transparent"
   set the showName of pButton to false
   set the showBorder of pButton to false
   set the threeD of pButton to false
   set the opaque of pButton to false
   set the autoHilite of pButton to false
   set the showFocusBorder of pButton to false
   set the traversalOn of pButton to false
   set the margins of pButton to 0
   set the icon of pButton to the id of image pPicture of card "Art"
   set the rect of pButton to 0, 0, the width of image pPicture of card "Art", \
         the height of image pPicture of card "Art"
end setIcon

-- The stack's script: nova-rescue-stack.livecodescript beside this file,
-- without its first line (a script-only stack's header, there so that
-- editors and checkers read it as xTalk)
private function stackScript
   local tFile, tScript
   put the effective filename of me into tFile
   set the itemDelimiter to slash
   put "nova-rescue-stack.livecodescript" into the last item of tFile
   set the itemDelimiter to comma
   put fileText(tFile) into tScript
   delete line 1 of tScript
   return tScript
end stackScript
