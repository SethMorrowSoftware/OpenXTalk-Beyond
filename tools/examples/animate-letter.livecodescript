script "OXTExampleAnimateLetter"
-- OXT-Beyond: builds "Animate a Letter", the remaster of Terry Little's
-- Animate Letter v1.2 (2022, GPL 3 or later), which is in
-- ide/Resources/Examples/Animate Letter.oxtstack and stays there as he
-- made it.
--
-- His stack teaches animation in twelve small programs, a card each: a
-- letter to click, and the script that moves it. The remaster keeps his
-- programs, his comments and his lesson plan, in the window every
-- remastered example has (builder.livecodescript): the cards in a
-- sidebar, the program on a stage, and its script beside it. What
-- changed in the scripts is where things go: his cards were 485 by 445,
-- and a script that named a place on the card ("the loc of this card",
-- random(300)+100) now names the stage instead (the graphic "Stage").
-- The letters are tiles in two colours, and a letter's first colour is
-- kept in its custom property cColor, which Shift-click puts back.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kStageLeft = 256
constant kStageTop = 104
constant kStageRight = 600
constant kStageBottom = 616
-- The letters' colours: the first letter, and the second
constant kLetter1 = "124,58,237"
constant kLetter2 = "219,39,119"

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   put "Animate a Letter" into tInfo["name"]
   put "after Terry Little, 2022" into tInfo["credit"]
   put "type" into tInfo["icon"]
   put lkColor("pink") into tInfo["accent"]
   put lkColor("violet") into tInfo["accent2"]
   put "Program" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Animate a Letter|Animate an alphabet letter with these code examples.|type|front" & return & \
         "Change Color|Change Color|Click a letter to change the color (Shift-click to reset).|palette|program" & return & \
         "Move Around|Move Around|Click a letter to move it around the card.|move|program" & return & \
         "Jump|Jump|Click a letter to make it jump.|arrow-big-up|program" & return & \
         "Spin|Spin|Click a letter to make it spin.|rotate-cw|program" & return & \
         "Popup|Popup|Click a letter to pop up in another spot.|sparkles|program" & return & \
         "Dance Crazy|Dance Crazy|Click a letter to make it dance crazy.|music|program" & return & \
         "Keep Score|Keep Score|Drag a letter to the red ball to score points.|trophy|program" & return & \
         "Speak|Speak|Click a letter to speak the text in the balloon (type in it too).|message-square-text|program" & return & \
         "Arrow Keys|Arrow Keys|Move a letter with the arrow keys to the red ball to score points (click the letter to reset).|keyboard|program keys" & return & \
         "Jump Ball|Jump Ball|Press the up arrow to start, and again to jump the red ball.|gamepad-2|program keys" & return & \
         "Make a Story|Make a Story|Click a letter to make a story about Red Fox.|notebook-pen|program" & return & \
         "Your Card|Your Card|Imagine your coding idea here. You can do it!|lightbulb|program" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   buildChangeColor
   buildMoveAround
   buildJump
   buildSpin
   buildPopup
   buildDance
   buildKeepScore
   buildSpeak
   buildArrowKeys
   buildJumpBall
   buildStory
   buildYourCard
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Animate a Letter.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

-- The two letters most cards have, with their programs
private command letters pCard, pLetter1, pLetter2
   local tObj
   go card pCard
   put exLetter("Letter", pLetter1, kStageLeft + 24, kStageTop + 24, kLetter1) into tObj
   set the script of tObj to exScript(pCard & "/" & pLetter1)
   if pLetter2 is not empty then
      put exLetter("Letter2", pLetter2, kStageLeft + 96, kStageTop + 24, kLetter2) into tObj
      set the script of tObj to exScript(pCard & "/" & pLetter2)
   end if
end letters

-- A score, in the header at the right, that a click puts back to 0
private command score pCard
   local tObj
   go card pCard
   put lkLabel("ScoreLabel", "880,16,1000,30", "SCORE", 11, lkColor("soft"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Score", "860,28,1000,66", "0", 30, lkColor("pink"), empty, "right") into tObj
   set the textStyle of tObj to "bold"
   set the script of tObj to exScript(pCard & "/Score")
end score

-- The red ball, round and lit
private function ball pName, pLeft, pTop
   local tObj
   put lkOval(pName, lkR(pLeft, pTop, pLeft + 27, pTop + 27), "239,68,68", empty) into tObj
   lkGradient tObj, "252,165,165|239,68,68|185,28,28", (pLeft + 6) & "," & (pTop + 4), (pLeft + 24) & "," & (pTop + 27)
   lkShadow tObj, 10, 3, 30
   set the cStartLoc of tObj to the loc of tObj
   return tObj
end ball

################################################################################
#
# The cards
#

-- The front page: what this is, a tile for each program, and the lesson
-- plan for teachers
private command buildFront
   local tObj, tTop, tWidth
   go card "Start"
   exHero lkR(kStageLeft, kStageTop, 1000, 272), lkColor("pink") & "|" & lkColor("violet"), \
         "TERRY LITTLE, 2022  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "One letter, twelve small programs", \
         "Each card has a letter to click, and the script that moves it beside it: read it, change it, " & \
         "and run it again. The last card is yours, for your own idea."
   exProgramTiles 288, 4, 60, 12
   -- The lesson plan
   put 528 into tTop
   get lkGroup("LessonPlan", lkR(kStageLeft, tTop, 1000, 616), empty)
   put exPanel("LessonPlan_bg", lkR(kStageLeft, tTop, 1000, 616), "LessonPlan") into tObj
   put lkBox("LessonPlan_iconBg", lkR(kStageLeft + 18, tTop + 22, kStageLeft + 62, tTop + 66), \
         lkMix("255,255,255", lkColor("violet"), 0.12), 12, "LessonPlan") into tObj
   get lkIcon("LessonPlan_icon", "graduation-cap", lkColor("violet"), \
         lkR(kStageLeft + 29, tTop + 33, kStageLeft + 51, tTop + 55), "LessonPlan")
   put lkLabel("LessonPlan_title", lkR(kStageLeft + 78, tTop + 18, 720, 40 + tTop), "For teachers: a lesson plan", 15, lkColor("ink"), "LessonPlan") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("LessonPlan_text", lkR(kStageLeft + 78, tTop + 42, 700, tTop + 80), \
         "Terry Little's plan for grades 5 to 8: three lessons of 50 minutes, which end with each " & \
         "student's own animation on the last card.", 12, lkColor("soft"), "LessonPlan") into tObj
   put exButton("Save", 0, tTop + 28, 34, "Save", "file-text", "ghost", lkColor("violet"), "LessonPlan", empty, 0) into tWidth
   set the right of group "Save" to 1000 - 18
   set the script of group "Save" to exScript("Start/Save")
   put exButton("Copy", 0, tTop + 28, 34, "Copy the plan", "copy", "primary", lkColor("violet"), "LessonPlan", empty, 0) into tWidth
   set the right of group "Copy" to the left of group "Save" - 10
   set the script of group "Copy" to exScript("Start/Copy")
   set the cLessonPlan of this card to exScript("lesson-plan")
end buildFront

private command buildChangeColor
   letters "Change Color", "A", "B"
end buildChangeColor

private command buildMoveAround
   local tObj, tPoints, tStep, tAngle
   letters "Move Around", "C", "D"
   -- The way the second letter goes: a figure of eight, drawn dashed
   repeat with tStep = 0 to 120
      put tStep * 2 * pi / 120 into tAngle
      put round(428 + 110 * sin(2 * tAngle)) & "," & round(384 - 175 * sin(tAngle)) & return after tPoints
   end repeat
   delete the last char of tPoints
   create graphic "Curve1"
   put it into tObj
   set the style of tObj to "curve"
   set the points of tObj to tPoints
   set the lineSize of tObj to 2
   set the foregroundColor of tObj to lkMix("255,255,255", kLetter2, 0.35)
   set the dashes of tObj to "6,8"
   set the antialiased of tObj to true
   set the filled of tObj to false
   set the layer of tObj to 1
end buildMoveAround

private command buildJump
   letters "Jump", "E", "F"
end buildJump

private command buildSpin
   letters "Spin", "G", "H"
end buildSpin

private command buildPopup
   letters "Popup", "I", "J"
end buildPopup

private command buildDance
   letters "Dance Crazy", "K", "L"
end buildDance

private command buildKeepScore
   local tObj
   letters "Keep Score", "M"
   score "Keep Score"
   get ball("Ball", 415, 347)
end buildKeepScore

private command buildSpeak
   local tObj, tLeft, tTop
   letters "Speak", "N"
   put kStageLeft + 40 into tLeft
   put kStageTop + 120 into tTop
   -- A thought balloon: two small bubbles, then the big one with the text
   put lkOval("Bubble1", lkR(kStageLeft + 62, kStageTop + 96, kStageLeft + 72, kStageTop + 106), \
         lkMix("255,255,255", kLetter1, 0.1), empty) into tObj
   lkBorder tObj, lkMix("255,255,255", kLetter1, 0.35)
   put lkOval("Bubble2", lkR(kStageLeft + 70, kStageTop + 104, kStageLeft + 86, kStageTop + 120), \
         lkMix("255,255,255", kLetter1, 0.1), empty) into tObj
   lkBorder tObj, lkMix("255,255,255", kLetter1, 0.35)
   put lkBox("Bubble", lkR(tLeft, tTop, kStageRight - 24, tTop + 120), lkMix("255,255,255", kLetter1, 0.1), 28, empty) into tObj
   lkBorder tObj, lkMix("255,255,255", kLetter1, 0.35)
   put lkLabel("Balloon", lkR(tLeft + 20, tTop + 22, kStageRight - 44, tTop + 104), \
         "How are you today?" & return & "I can speak for characters in a story you make.", 15, lkColor("ink"), empty, "center") into tObj
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
end buildSpeak

private command buildArrowKeys
   local tObj
   go card "Arrow Keys"
   set the script of this card to exScript("Arrow Keys/card")
   -- (the original spells it "Boundry": the remaster spells it right, in
   -- the graphic's name and in every script that names it)
   put lkBox("Boundary", lkR(kStageLeft + 16, kStageTop + 16, kStageRight - 16, kStageBottom - 16), empty, 0, empty) into tObj
   hide tObj
   letters "Arrow Keys", "O"
   put ball("Ball", 415, 347) into tObj
   set the script of tObj to exScript("Arrow Keys/Ball")
   score "Arrow Keys"
end buildArrowKeys

private command buildJumpBall
   local tObj
   go card "Jump Ball"
   set the script of this card to exScript("Jump Ball/card")
   put lkBox("Boundary", lkR(kStageLeft + 16, 200, kStageRight - 16, 440), empty, 0, empty) into tObj
   hide tObj
   -- the ground the letter stands on and the ball rolls along
   get lkBox("Ground", lkR(kStageLeft + 16, 441, kStageRight - 16, 445), lkColor("line"), 2, empty)
   put exLetter("Letter", "P", 320, 376, kLetter1) into tObj
   set the script of tObj to exScript("Jump Ball/P")
   put ball("Ball", 545, 413) into tObj
   set the script of tObj to exScript("Jump Ball/Ball")
   score "Jump Ball"
end buildJumpBall

private command buildStory
   local tObj, tGroup, tTop, tIndex, tChoices, tQuestions
   letters "Make a Story", "Q"
   put "Where should Red Fox go?|the lake in the dark woods.|the field next to the farmer's white house.|the stream under the green bridge." & return & \
         "What should Red Fox do there?|look for friend yellow bumblebee.|find a purple flower to bring home.|watch the blue sky and puffy clouds." & return & \
         "What would you like to say to Red Fox?|I like your long bushy tail.|are you hungry? We could have lunch.|maybe we can be friends." into tChoices
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 3
      put "Fox" & tIndex into tGroup
      put kStageTop + 108 + (tIndex - 1) * 112 into tTop
      get lkGroup(tGroup, lkR(kStageLeft + 16, tTop, kStageRight - 16, tTop + 100), empty)
      put lkBox(tGroup & "_bg", lkR(kStageLeft + 16, tTop, kStageRight - 16, tTop + 100), \
            lkMix("255,255,255", lkColor("orange"), 0.07), 14, tGroup) into tObj
      put lkLabel("Label Field", lkR(kStageLeft + 30, tTop + 8, kStageRight - 30, tTop + 26), \
            item 1 of line tIndex of tChoices, 13, lkColor("ink"), tGroup) into tObj
      set the textStyle of tObj to "bold"
      radio tGroup, "Radio" & char tIndex of "ABC" & 1, item 2 of line tIndex of tChoices, tTop + 30, true
      radio tGroup, "Radio" & char tIndex of "ABC" & 2, item 3 of line tIndex of tChoices, tTop + 52, false
      radio tGroup, "Radio" & char tIndex of "ABC" & 3, item 4 of line tIndex of tChoices, tTop + 74, false
      set the radioBehavior of group tGroup to true
      hide group tGroup
   end repeat
   set the itemDelimiter to comma
   put lkLabel("Story", lkR(kStageLeft + 16, kStageTop + 108, kStageRight - 16, kStageBottom - 24), \
         empty, 14, lkColor("ink"), empty) into tObj
   set the opaque of tObj to true
   set the backgroundColor of tObj to "255,247,237"
   set the borderColor of tObj to lkMix("255,255,255", lkColor("orange"), 0.35)
   set the showBorder of tObj to true
   set the threeD of tObj to false
   set the borderWidth of tObj to 1
   set the margins of tObj to 16
   set the text of tObj to exScript("story")
   set the script of tObj to exScript("Make a Story/Story")
   hide tObj
end buildStory

private command radio pGroup, pName, pLabel, pTop, pHilite
   local tObj
   create button pName in group pGroup
   put it into tObj
   set the style of tObj to "radioButton"
   set the label of tObj to pLabel
   set the textSize of tObj to 13
   set the textColor of tObj to lkColor("soft")
   set the rect of tObj to kStageLeft + 26, pTop, kStageRight - 26, pTop + 22
   set the hilite of tObj to pHilite
end radio

private command buildYourCard
   local tObj
   go card "Your Card"
   put lkBox("Idea", lkR(kStageLeft + 24, kStageTop + 24, kStageRight - 24, kStageBottom - 24), empty, 16, empty) into tObj
   lkBorder tObj, lkColor("line")
   set the lineSize of tObj to 2
   set the dashes of tObj to "8,8"
   put lkLabel("IdeaText", lkR(kStageLeft + 48, 330, kStageRight - 48, 390), \
         "Your idea here" & return & "Draw it on paper first, then make it with the tools.", 13, lkColor("muted"), empty, "center") into tObj
   set the textStyle of line 1 of tObj to "bold"
   set the textSize of line 1 of tObj to 16
   set the cEmptyText of this card to exScript("Your Card/tips")
end buildYourCard

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Animate a Letter: Terry Little's Animate Letter v1.2, remastered for OXT-Beyond in 2026
--Animate Letter v1.2, Terry Little (c)7/2022, All Rights Reserved
--This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
--as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

--Each card's program is in the scripts of its letters (and, for the arrow keys, of its card):
--click a letter, and the panel beside the stage shows its script. The sidebar, the header and
--that panel are the groups "Frame" and "Workbench", which the script of the group "Frame" runs.

on newCard  --block new cards
   delete this card
   answer "Sorry, new cards are not allowed." with "OK" titled "Animate a Letter"
end newCard
@*/

/*@ Start/Copy
on mouseUp  --copy the lesson plan
   set the clipboardData["text"] to the cLessonPlan of this card  --custom property containing plan
   answer "The lesson plan is on the clipboard: paste it into a document." with "OK" titled "Teacher Lesson Plan"
end mouseUp
@*/

/*@ Start/Save
on mouseUp  --lesson plan.txt
   local tPath
   ask file "Save the lesson plan as:" with "Lesson Plan.txt"
   if it is empty then exit to top  --Cancel
   put it into tPath
   put the cLessonPlan of this card into url ("file:" & tPath)  --export text file, cLessonPlan is a custom property of this card
   if the result <> empty then answer "Sorry, there was a problem writing to a text file." &cr& the result with "OK" titled "Error"
   else answer "Saved the lesson plan as" && quote & tPath & quote & "." with "OK" titled "Teacher Lesson Plan"
end mouseUp
@*/

/*@ Change Color/A
on mouseUp  --color
   if shiftKey() = "down" then  --reset
      set the backColor of me to the cColor of me  --its first color, kept in a custom property
   else set the backColor of me to any line of colorNames()  --a line list of available colors
end mouseUp
@*/

/*@ Change Color/B
on mouseUp  --color
   if shiftKey() = "down" then  --reset
      set the backColor of me to the cColor of me  --its first color, kept in a custom property
   else set the backColor of me to any line of colorNames()
end mouseUp
@*/

/*@ Move Around/C
on mouseUp  --move me
   local tStartLoc, tEndLoc
   put the loc of me into tStartLoc  --starting point
   put the loc of graphic "Stage" into tEndLoc  --the middle of the stage
   move me from tStartLoc to tEndLoc  --move to new point
   wait .5 sec with messages  --optional
   move me from tEndLoc to tStartLoc  --move back
end mouseUp

--x,y point on card: position mouseArrow, in msg box type "put mouseLoc()", press returnKey (enter).
@*/

/*@ Move Around/D
on mouseUp  --move me
   local tStartLoc
   --set the visible of graphic "Curve1" to not the visible of graphic "Curve1"  --hide/show
   put the loc of me into tStartLoc  --starting point
   move me to the points of graphic "Curve1"  --move along a curve graphic (its dashed line)
   wait .5 sec with messages  --optional
   move me from the loc of me to tStartLoc  --move back
end mouseUp
@*/

/*@ Jump/E
on mouseUp  --jump
   local tStartLoc
   put the loc of me into tStartLoc  --starting point
   move me relative 0,-40  --move up to new point
   wait .5 sec with messages  --optional
   move me from the loc of me to tStartLoc  --move back
end mouseUp

--x,y point on card: position mouseArrow, in msg box type "put mouseLoc()", press returnKey (enter).
@*/

/*@ Jump/F
on mouseUp  --jump forward
   local tStartLoc
   put the loc of me into tStartLoc  --starting point
   move me relative 25,-40  --move up to new point
   wait .25 sec with messages  --optional
   move me relative 25,40  --move down to new point
   wait .5 sec with messages  --optional
   move me from the loc of me to tStartLoc  --move back
end mouseUp
@*/

/*@ Spin/G
--a field cannot spin, so make an image from the field and spin the image

on mouseUp  --spin image
   local tName
   put the short name of me into tName
   if there is an image tName then
      answer "Sorry, there is already an image of me." with "OK" titled "Animate a Letter"
      exit to top  --stop executing code
   end if
   lock screen
   import snapshot from field tName  --make image from field
   set the name of last image to tName
   set the loc of image tName to item 1 of the loc of me &","& item 2 of the loc of me + 80  --x,y position below
   unlock screen  --show image at new loc
   set the resizeQuality of image tName to "Good"  --image quality good for spin
   --code for image ("\" continues command over > 1 line)
   set the script of image tName to  \
         "on mouseUp" &cr& \
         "repeat 3" &cr& \
         "set the angle of me to 45"  &cr& \
         "wait .5 sec with messages"  &cr& \
         "set the angle of me to -45"  &cr& \
         "wait .5 sec with messages"  &cr& \
         "end repeat"  &cr& \
         "set the angle of me to 0  --straighten"  &cr& \
         "end mouseUp"
end mouseUp
@*/

/*@ Spin/H
--a field cannot spin, so make an image from the field and spin the image

on mouseUp  --spin image
   local tName
   put the short name of me into tName
   if there is an image tName then
      answer "Sorry, there is already an image of me." with "OK" titled "Animate a Letter"
      exit to top  --stop executing code
   end if
   lock screen
   import snapshot from field tName  --make image from field
   set the name of last image to tName
   set the loc of image tName to item 1 of the loc of me &","& item 2 of the loc of me + 80  --x,y position below
   unlock screen  --show image at new loc
   set the resizeQuality of image tName to "Good"  --image quality good for spin
   --code for image ("\" continues command over > 1 line)
   set the script of image tName to  \
         "on mouseUp" &cr& \
         "local tAngle =20" &cr& \
         "repeat 8" &cr& \
         "set the angle of me to tAngle" &cr& \
         "wait .25 sec with messages" &cr& \
         "add 20 to tAngle" &cr& \
         "end repeat"  &cr& \
         "set the angle of me to 0  --straighten"  &cr& \
         "end mouseUp"
end mouseUp
@*/

/*@ Popup/I
on mouseUp  --random popup
   local tX, tY
   repeat 8
      put the left of graphic "Stage" + 40 + random(the width of graphic "Stage" - 80) into tX  --a random x on the stage
      put the top of graphic "Stage" + 40 + random(the height of graphic "Stage" - 80) into tY  --and a random y
      set the loc of me to tX,tY
      wait .5 sec with messages
   end repeat
   set the loc of me to the cStartLoc of me  --reset, cStartLoc is a custom property of this object
end mouseUp
@*/

/*@ Popup/J
on mouseUp  --dropping popup
   local tX, tY
   put the left of graphic "Stage" + 40 + random(the width of graphic "Stage" - 80) into tX  --x-axis coordinate, anywhere across the stage
   put the bottom of graphic "Stage" - 240 into tY  --y-axis coordinate
   set the loc of me to tX,tY
   wait .75 sec with messages
   repeat 4
      set the loc of me to (item 1 of the loc of me) , (item 2 of the loc of me + 50)  --drop down in 50 pixel increments (200 px total)
      wait .75 sec with messages
   end repeat
   set the loc of me to the cStartLoc of me  --reset, cStartLoc is a custom property of this object
end mouseUp
@*/

/*@ Dance Crazy/K
on mouseUp  --dance crazy
   local tStartLoc, tEndLoc
   put the loc of me into tStartLoc  --starting point
   put the loc of graphic "Stage" into tEndLoc  --the middle of the stage
   move me from tStartLoc to tEndLoc  --move to new point
   repeat 15
      move me relative (item random(4) of "-15,-10,10,15",0)  --side to side
      wait .25 sec with messages
   end repeat
   move me from the loc of me to tStartLoc  --move back
end mouseUp
@*/

/*@ Dance Crazy/L
on mouseUp  --dance crazy
   local tStartLoc, tEndLoc
   put the loc of me into tStartLoc  --starting point
   put the loc of graphic "Stage" into tEndLoc  --the middle of the stage
   move me from tStartLoc to tEndLoc  --move to new point
   repeat 15
      move me relative random(50)-25 , random(50)-25  --+25 to -25
      wait .25 sec with messages
   end repeat
   move me from the loc of me to tStartLoc  --move back
end mouseUp
@*/

/*@ Keep Score/M
on mouseDown  --grab with mouse
   grab me  --move me around with mouse
end mouseDown

on mouseMove x,y  --better than mouseStillDown
   if intersect(me,graphic "Ball") then
      hide me  --release mouseDown grab
      set the loc of me to the cStartLoc of me  --start over, cStartLoc is a custom property of field "Letter"
      show me
      set the loc of graphic "Ball" to random(240)+300, random(400)+170  --random x,y on the stage
      beep
      add 10 to field "Score"  --win
      get the text of field "Score"  --put in temp container "it"
      if it = "10" then answer "You caught the Red Ball and scored 10 points! Yaaaa!" with "OK" titled "You Won"  --optional
      else if it >= "20" and it <= "50" then revSpeak "You have" && it && "points."  --optional
   end if
end mouseMove

on mouseUp
   move me from the loc of me to the cStartLoc of me  --back to starting point
end mouseUp
@*/

/*@ Keep Score/Score
on mouseUp  --reset
   put "0" into me
   set the loc of graphic "Ball" to the loc of graphic "Stage"
end mouseUp
@*/

/*@ Speak/N
on mouseUp  --speak text
   get the text of fld "Balloon"
   revSpeak it
end mouseUp
@*/

/*@ Arrow Keys/card
on arrowKey pKey  --in cd script, move field "Letter" and graphic "Ball"
   lock screen
   if pKey = "up" then
      if the top of fld "Letter" > the top of graphic "Boundary" then  --hidden graphic
         set the top of fld "Letter" to the top of fld "Letter" -10  --move up
      end if
   else if pKey = "down" then
      if the bottom of fld "Letter" < the bottom of graphic "Boundary" then
         set the bottom of fld "Letter" to the bottom of fld "Letter" +10  --move down
      end if
   else if pKey = "left" then
      if the left of fld "Letter" > the left of graphic "Boundary" then
         set the left of fld "Letter" to the left of fld "Letter" -10  --move left
      end if
   else if pKey = "right" then
      if the right of fld "Letter" < the right of graphic "Boundary" then
         set the right of fld "Letter" to the right of fld "Letter" +10  --move right
      end if
   end if
   if random(10) = "10" then  --random reposition graphic "Ball"
      set the loc of grc "Ball" to (the left of graphic "Boundary" + random(the width of graphic "Boundary" -150)+75 &","& \
            the top of graphic "Boundary" + random(the height of graphic "Boundary" -150)+75)
      repeat while intersect(fld "Letter",grc "Ball")  --try again
         set the loc of grc "Ball" to (the left of graphic "Boundary" + random(the width of graphic "Boundary" -150)+75 &","& \
               the top of graphic "Boundary" + random(the height of graphic "Boundary" -150)+75)
      end repeat
   end if
   unlock screen
   if intersect(fld "Letter",grc "Ball") then  --win
      add 10 to fld "Score"
      get fld "Score"
      revSpeak "You captured the Red Ball and now have" &&it&& "points."
      if it mod 30 = 0 then revSpeak "And moved to the next level."  --score/30 = no remainder: 30,60,90...
      send "mouseUp" to fld "Letter"  --reset
   end if
end arrowKey
@*/

/*@ Arrow Keys/O
--in msg box: set the cStartLoc of field "Letter" to the loc of field "Letter"  --created custom property of the object, cStartLoc, to store x,y location.
--card script has arrowKey message handler, hidden graphic "Boundary" provides restraint dimensions.

on mouseUp  --reset
   lock screen
   set the loc of me to the cStartLoc of me  --custom property
   set the loc of graphic "Ball" to the cStartLoc of graphic "Ball"  --its own custom property
end mouseUp
@*/

/*@ Arrow Keys/Ball
--in msg box: set the cStartLoc of graphic "Ball" to the loc of graphic "Ball"  --create custom property of the object, cStartLoc, to store x,y location.
@*/

/*@ Arrow Keys/Score
on mouseUp
   put "0" into me  --reset
end mouseUp
@*/

/*@ Jump Ball/card
local sLose  --declare script local container, available to all scripts below it
on arrowKey pKey  --in cd script, make field "Letter" jump over graphic "Ball"
   local i
   if pKey = "up" then  --start game or jump
      if the loc of graphic "Ball" = the cStartLoc of graphic "Ball" then  --start game  (move left with -x,y in 4 to 7 seconds)
         move grc "Ball" relative -(the left of grc "Ball" - the left of graphic "Boundary"),0 in random(4)+3 secs without waiting  --don't wait while moving
      else  --jump
         if the right of grc "Ball" < the left of fld "Letter" then exit to top  --jump after ball passes
         repeat with i = 1 to 16
            if i <= "8" then set the top of field "Letter" to the top of field "Letter" -10  --jump up
            else set the top of field "Letter" to the top of field "Letter" +10  --come down
            wait 200 millisecs with messages  --adjust jump speed, with messages allows engine to process
            put intersect(field "Letter",graphic "Ball") into sLose  --sLose="true" if they touch
            if sLose = "true" then exit repeat
         end repeat
      end if
   end if
end arrowKey

on moveStopped  --moving object reaches destination
   if sLose = "true" then subtract 10 from field "Score"  --lose
   else if sLose = "false" then add 10 to field "Score"  --win
   put empty into sLose  --reset, script local containers are persistent while stack is open
   set the loc of field "Letter" to the cStartLoc of field "Letter"  --reset, cStartLoc is custom property of field "Letter"
   set the loc of graphic "Ball" to the cStartLoc of graphic "Ball"  --reset, cStartLoc is custom property of graphic "Ball"
   exit to top  --stop all running scripts
end moveStopped
@*/

/*@ Jump Ball/P
--in msg box: set the cStartLoc of field "Letter" to the loc of field "Letter"  --created custom property of the object, cStartLoc, to store x,y location.
--card script has arrowKey message handler, hidden graphic "Boundary" provides restraint dimensions.
@*/

/*@ Jump Ball/Ball
--in msg box: set the cStartLoc of graphic "Ball" to the loc of graphic "Ball"  --create custom property of the object, cStartLoc, to store x,y location.
@*/

/*@ Jump Ball/Score
on mouseUp
   put "0" into me  --reset
end mouseUp
@*/

/*@ Make a Story/Q
on mouseUp  --make story
   local tChoice1, tChoice2, tChoice3, tStory
   lock screen for visual effect
   if not the visible of group "Fox1" then  --show groups
      show group "Fox1"
      show group "Fox2"
      show group "Fox3"
   else if not the visible of field "Story" then  --load story
      put the label of btn (the hilitedButton of group "Fox1") of group "Fox1" into tChoice1
      put the label of btn (the hilitedButton of group "Fox2") of group "Fox2" into tChoice2
      put the label of btn (the hilitedButton of group "Fox3") of group "Fox3" into tChoice3
      put "A Fox Adventure Story" &cr&cr& \
            "Red Fox wanted to go on an adventure this sunny day and decided to go to" && tChoice1 &cr&cr& \
            "It took almost an hour, but now Red Fox could finally" && tChoice2 &cr&cr& \
            "If you saw Red Fox on one of YOUR adventures, you could say" && quote& tChoice3 &quote into tStory  --"\" continues command to next line
      put tStory into field "Story"  --display
      show field "Story"
   else  --hide all
      hide group "Fox1"
      hide group "Fox2"
      hide group "Fox3"
      hide field "Story"
   end if
   unlock screen with visual effect "dissolve"  --quoted, for strict compilation mode
end mouseUp
@*/

/*@ Make a Story/Story
on mouseUp  --hide all
   lock screen for visual effect
   hide group "Fox1"
   hide group "Fox2"
   hide group "Fox3"
   hide me
   unlock screen with visual effect "dissolve"  --quoted, for strict compilation mode
end mouseUp
@*/

/*@ story
A Fox Adventure Story

Red Fox wanted to go on an adventure this sunny day and decided to go to the lake in the dark woods.

It took almost an hour, but now Red Fox could finally look for friend yellow bumblebee.

If you saw Red Fox on one of YOUR adventures, you could say "I like your long bushy tail."
@*/

/*@ Your Card/tips
Animation Coding Tips

1) Animate with a field, graphic, image, button, or button with icon.

2) A field has to be locked to receive a message.

3) Modify code examples used here for your own creation.

4) Use the Dictionary for more code examples and proper syntax. Help > Dictionary.

5) Draw your idea on paper first to make layout and coding easier.

To give a control a script: choose the Edit tool (the arrow) in the Tools palette, select the control, then Object > Object Script. To change how it looks: Object > Object Inspector, or double-click it.

Terry Little
@*/

/*@ lesson-plan
Lesson Plans / Learning Designs
(OpenXTalk is a free open-source multi-platform coding program for STEM curriculum)

1) Animate A Letter
==========

1) Animate A Letter
Topic: Code with OpenXTalk. (STEM)
Description: Grades 5-8. Each student reviews the animation code examples in the stack "Animate Letter" and codes an original animation on the last card of the stack.
Minutes: 50 x3 = 150, Students: 25
Aims: Why are you teaching this lesson? Become familiar with basic animation coding. Learn problem solving skills.
Outcomes:
What do you expect of students after this lesson?
Apply --use animation techniques in future coding projects.
Analyze --problem solve methods to present ideas.
Learn --move and drag animation, arrowKey motion.
Teaching Learning:
o Day 1: Students review the animation code examples in the stack "Animate Letter".
Discuss, 10 min. Ask each student to choose a favorite animation example from the stack to use for their own creation on the last card. Also note navigation and score examples.
Investigate, 30 min. Each student plays with the stack and examines object and card scripts.
1) Click right Edit Arrow on Tools Palette.
2) Click Letter to select it.
3) Menu: Object > Object Script
Menu: Object > Object Inspector
Menu: Card Script (for cards using arrowKeys)
Discuss, 10 min. Students choose a favorite animation example and begin drawing a layout on paper for the last card of the stack.
----
o Day 2. Finish layout and begin coding for last card.
Produce, 50 min. When students have their paper layout checked, allow to begin placing objects and writing animation code.
Code --move, lock screen, visual effect, hide, show, set, the loc, arrowKey, mouseUp, mouseDown, mouseMove, MoveStopped, random().
* For precise x,y location on screen, position mouseArrow and in msg box: put mouseLoc(), and hit returnKey (enter).
* For current x,y object location, in msg box: put the loc of graphic "Triangle".
----
o Day 3. Finish coding and debugging.
Produce, 50 min. Debug and troubleshoot problems. Make suggestions for future improvement.
Discuss, 10 min. Let students show their creations.
Post-Analysis: Impressions after presentation.
==========
@*/
