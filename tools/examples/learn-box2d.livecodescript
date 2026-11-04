script "OXTExampleLearnBox2D"
-- OXT-Beyond: builds "Learn Box2D", thirteen lessons in Box2D, the 2D
-- physics engine that OXT-Beyond has built in through the xTalk Suite's
-- Box2Dxt (https://github.com/SethMorrowSoftware/xtalk-suite, box2dxt/).
-- Unlike the other examples here, it is not the remaster of an older
-- stack: it was written for OXT-Beyond in 2026.
--
-- Each lesson is a wide card (builder.livecodescript): its stage has a
-- court, a dark box where a Box2D world runs live, the lesson's buttons
-- above it, and beside it what the lesson shows, with the Box2D handlers
-- its script calls, each of which a click explains. The card's own
-- script makes its world with Box2Dxt's raw b2... handlers, so that what
-- a lesson teaches is Box2D's own API, as a stack of yours would call
-- it. What every lesson shares (the loop that steps the world, drawing,
-- dragging, the buttons) is the script of the group "Lab", a background
-- on the lessons, whose chip the scripts drawer shows beside the card's.
--
-- The worlds are made when a card opens and destroyed when it closes,
-- with every graphic drawn for them, so a saved stack holds none.
--
-- build-examples.livecodescript runs exBuild with the builder in use.
-- test-learn-box2d.livecodescript (in tools/examples) opens the built
-- stack on a real engine with Box2Dxt loaded and runs every lesson.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- The court, where a lesson's world runs (410 by 440 pixels: 8.2 by 8.8
-- metres at the Lab's 50 pixels a metre), and the column beside it
constant kCourt = "270,162,680,602"
constant kInfo = "694,162,986,602"
-- The front banner's toy world, at its right
constant kToy = "770,114,988,264"

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex
   exUseScripts the script of me
   exAddIcon "loader-circle", "<path d='M21 12a9 9 0 1 1-6.219-8.56'/>"
   exAddIcon "link", "<path d='M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71'/>" & \
         "<path d='M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71'/>"
   exAddIcon "circle-dot", "<circle cx='12' cy='12' r='10'/><circle cx='12' cy='12' r='1'/>"
   exAddIcon "pause", "<rect x='14' y='4' width='4' height='16' rx='1'/><rect x='6' y='4' width='4' height='16' rx='1'/>"
   exAddIcon "step-forward", "<line x1='6' x2='6' y1='4' y2='20'/><polygon points='10,4 20,12 10,20'/>"
   exAddIcon "hand", "<path d='M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2'/><path d='M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2'/>" & \
         "<path d='M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8'/>" & \
         "<path d='M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15'/>"
   put "Learn Box2D" into tInfo["name"]
   put "Box2D 3.1, through Box2Dxt" into tInfo["credit"]
   put "box" into tInfo["icon"]
   put lkColor("teal") into tInfo["accent"]
   put lkColor("sky") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn Box2D|A physics engine for your stacks, one idea at a time.|box|front" & return & \
         "World|The World|A world holds every body, pulls them with gravity and steps them through time.|globe|wide" & return & \
         "Bodies|Body Types|Static bodies stay put, kinematic ones move as told, dynamic ones obey physics.|layers|wide" & return & \
         "Shapes|Shapes|Circles, boxes, capsules, polygons and segments give bodies their form.|blocks|wide" & return & \
         "Materials|Materials|Density, friction and restitution: how heavy, how grippy, how bouncy.|palette|wide" & return & \
         "Forces|Forces & Motion|Push with forces, kick with impulses, or set a speed outright.|zap|wide" & return & \
         "Hinges|Hinges|The revolute joint: pendulums, motors and limits.|rotate-cw|wide" & return & \
         "Springs|Rods & Springs|Distance joints and welds: rods, springs, ropes and a bendy board.|link|wide" & return & \
         "Sliders|Sliders|The prismatic joint: a lift with a motor, and a piston with a spring.|move|wide" & return & \
         "Wheels|Wheels|The wheel joint: drive a car on sprung wheels with the arrow keys.|circle-dot|wide keys" & return & \
         "Dragging|Dragging|The mouse joint, and joints that break when they are pulled too hard.|mouse-pointer-2|wide" & return & \
         "Contacts|Contacts & Sensors|Who touched whom, sensors that notice, and filters that let things pass.|sparkles|wide" & return & \
         "Rays|Ray Casts|Ask the world what a line hits, or what is near a point.|target|wide" & return & \
         "Terrain|Terrain & Blasts|Smooth chain ground, explosions, and bodies that fall asleep.|map|wide" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      buildLesson exCardInfo(tIndex, "name")
   end repeat
   set the cOwnDrag of card "Dragging" of tStack to true
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn Box2D.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

################################################################################
#
# The front page
#

private command buildFront
   local tIndex, tLeft, tWidth, tTips
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 272), lkColor("teal") & "|" & lkColor("sky"), \
         "OXT-BEYOND  " & numToCodepoint(183) & "  BOX2D 3.1 THROUGH BOX2DXT", \
         "Physics, one idea at a time", \
         "Thirteen lessons, each a live world to play with, what it shows, and the script that makes it. " & \
         "They use Box2D's own handlers, the b2 ones, as your stacks will."
   -- (the banner's words keep to its left; its right is the toy's, a
   -- live Box2D world that the card's script runs)
   set the width of field "hero_text" to 470
   set the left of field "hero_text" to kLeft + 32
   set the height of field "hero_text" to the formattedHeight of field "hero_text"
   repeat with tIndex = 1 to 6
      if there is a graphic ("hero_star" & tIndex) and item 1 of the loc of graphic ("hero_star" & tIndex) > item 1 of kToy - 20 then
         delete graphic ("hero_star" & tIndex)
      end if
   end repeat
   get lkGroup("Toy", kToy, "hero")
   get lkBox("toyAnchor", lkR(item 1 of kToy, item 2 of kToy, item 1 of kToy + 1, item 2 of kToy + 1), empty, 0, "Toy")
   set the script of this card to exScript("Start/card")
   exProgramTiles 288, 5, 60, 10
   -- (the tiles say each lesson's short name: the long ones would not fit)
   repeat with tIndex = 1 to 13
      put exCardInfo(tIndex + 1, "name") into field ("tile" & tIndex & "_title")
      if the formattedWidth of field ("tile" & tIndex & "_title") > the width of field ("tile" & tIndex & "_title") then
         throw "the tile of " & exCardInfo(tIndex + 1, "name") & " is too narrow for its name"
      end if
   end repeat
   -- How a lesson works: four tips in a row
   put "mouse-pointer-click|Press the buttons above a court to try what the lesson shows." & return & \
         "hand|Drag any body to throw it. Reset starts the lesson again." & return & \
         "list|Click a Box2D call in a lesson's list to see what it does." & return & \
         "code|Open Scripts to read the code. Edit it, then press Reset to run it." into tTips
   put (kRight - kLeft - 3 * 12) div 4 into tWidth
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put kLeft + (tIndex - 1) * (tWidth + 12) into tLeft
      tip "Tip" & tIndex, tLeft, 500, tLeft + tWidth, kBottom, item 1 of line tIndex of tTips, item 2 of line tIndex of tTips
   end repeat
   set the itemDelimiter to comma
   -- The way to the Kit's lessons, beside the last row of tiles
   put exButton("OtherStack", 0, 442, 32, "Learn Box2Dxt Kit: games in pixels", "gamepad-2", "ghost", lkColor("teal"), empty, empty, 0) into tWidth
   set the right of group "OtherStack" to kRight
   set the toolTip of group "OtherStack" to "Open Learn Box2Dxt Kit, whose lessons make games with the Kit: pixels, sprites, players and sound"
end buildFront

private command tip pName, pLeft, pTop, pRight, pBottom, pIcon, pText
   local tObj
   get exPanel(pName, lkR(pLeft, pTop, pRight, pBottom), empty)
   get lkBox(pName & "_iconBg", lkR(pLeft + 16, pTop + 16, pLeft + 52, pTop + 52), lkMix("255,255,255", lkColor("teal"), 0.13), 12, empty)
   get exIcon(pName & "_icon", pIcon, lkColor("teal"), lkR(pLeft + 24, pTop + 24, pLeft + 44, pTop + 44), empty)
   put lkLabel(pName & "_text", lkR(pLeft + 16, pTop + 62, pRight - 14, pBottom - 8), pText, 12, lkColor("soft"), empty) into tObj
end tip

################################################################################
#
# A lesson
#

-- A lesson's card: its script, the Lab (made on the first lesson and
-- placed on the others), its buttons, and the column beside the court
private command buildLesson pCard
   local tScript
   go card pCard
   put exScript(pCard & "/card") into tScript
   set the script of this card to tScript
   if there is no group "Lab" of card "World" then
      buildLab
   else
      place group "Lab" of card "World" onto this card
   end if
   lessonButtons pCard
   lessonInfo pCard, tScript
end buildLesson

-- The Lab: the court, the line under it, Reset, Pause and Step, and the
-- script every lesson shares. A background, on each lesson
private command buildLab
   local tObj, tRight, tWidth
   get lkGroup("Lab", lkR(kLeft + 14, kTop + 14, kRight - 14, kBottom - 14), empty)
   set the backgroundBehavior of group "Lab" to true
   get lkBox("labAnchor", lkR(kLeft + 14, kTop + 14, kLeft + 15, kTop + 15), empty, 0, "Lab")
   put lkBox("Court", kCourt, lkColor("side"), 14, "Lab") into tObj
   lkGradient tObj, "30,41,59|20,24,54|15,23,42", item 1 of kCourt & "," & item 2 of kCourt, item 1 of kCourt & "," & item 4 of kCourt
   -- The group the Lab draws the world in: as big as the court, so that
   -- what is past its edges is cut off, and below the line of numbers
   -- and the buttons, so that bodies pass behind them. (A group needs
   -- something in it to be kept: an empty box at its corner)
   get lkGroup("Bodies", kCourt, "Lab")
   get lkBox("bodiesAnchor", lkR(item 1 of kCourt, item 2 of kCourt, item 1 of kCourt + 1, item 2 of kCourt + 1), empty, 0, "Bodies")
   -- The line of numbers, under the buttons at the court's top, where
   -- it is clear of the bodies that pile up on the floor, on a dark
   -- backing that the Lab sizes to its words (labSay)
   put lkBox("ReadoutBg", lkR(item 1 of kCourt + 8, item 2 of kCourt + 44, item 1 of kCourt + 9, item 2 of kCourt + 45), \
         "15,23,42", 8, "Lab") into tObj
   set the blendLevel of tObj to 20
   hide tObj
   put lkLabel("Readout", lkR(item 1 of kCourt + 14, item 2 of kCourt + 46, item 3 of kCourt - 14, item 2 of kCourt + 62), \
         empty, 11, "203,213,225", "Lab") into tObj
   set the sharedText of tObj to false
   -- Reset, Pause and Step, small and dark, in the court's top right
   -- corner: the row above the court is the lesson's own
   put item 3 of kCourt - 10 into tRight
   put exButton("LabStep", 0, item 2 of kCourt + 10, 26, "Step", "step-forward", "chip", lkColor("teal"), "Lab", empty, 0) into tWidth
   set the left of group "LabStep" to tRight - tWidth
   set the cDo of group "LabStep" to "labStepButton"
   subtract tWidth + 6 from tRight
   put exButton("LabPause", 0, item 2 of kCourt + 10, 26, "Pause", "pause", "chip", lkColor("teal"), "Lab", empty, 74) into tWidth
   set the left of group "LabPause" to tRight - tWidth
   set the cDo of group "LabPause" to "labTogglePause"
   set the sharedText of field "LabStep_label" to true
   set the sharedText of field "LabPause_label" to true
   subtract tWidth + 6 from tRight
   put exButton("LabReset", 0, item 2 of kCourt + 10, 26, "Reset", "undo-2", "chip", lkColor("teal"), "Lab", empty, 0) into tWidth
   set the left of group "LabReset" to tRight - tWidth
   set the cDo of group "LabReset" to "labRestart"
   set the sharedText of field "LabReset_label" to true
   -- The sign that the lesson is being made: it shows in the court's
   -- middle from when the card opens until its world is ready
   put exButton("LabLoading", 0, item 2 of kCourt + 200, 40, "Getting the lesson ready...", "loader-circle", "dark", lkColor("teal"), "Lab", empty, 0) into tWidth
   set the left of group "LabLoading" to (item 1 of kCourt + item 3 of kCourt - tWidth) div 2
   set the sharedText of field "LabLoading_label" to true
   hide group "LabLoading"
   set the script of group "Lab" to exScript("Lab")
   set the cDocs of group "Lab" to docs()
end buildLab

-- The card's own buttons, from the block "buttons" (card|label|handler,
-- and "switch" for one that switches something on and off), in a row
-- from the left, all alike. Each has a light, hidden: a wash of the
-- accent and its outline, which the Lab shows while a switch is on, or
-- for a moment when a button runs (labShowButtons)
private command lessonButtons pCard
   local tLine, tLeft, tWidth, tStyle, tName, tCount
   put kLeft + 14 into tLeft
   put 0 into tCount
   set the itemDelimiter to "|"
   repeat for each line tLine in exScript("buttons")
      if item 1 of tLine is not pCard then
         next repeat
      end if
      add 1 to tCount
      put "ghost" into tStyle
      put "Do" & tCount into tName
      put exButton(tName, tLeft, kTop + 14, 34, item 2 of tLine, empty, tStyle, lkColor("teal"), empty, empty, 0) into tWidth
      set the cDo of group tName to item 3 of tLine
      buttonLight tName, lkColor("teal")
      if item 4 of tLine is "switch" then
         set the cSwitch of group tName to true
         if "labLit" is not among the words of scriptFunctionNames(the script of this card) then
            set the itemDelimiter to comma
            throw "the switch " & item 2 of tLine & " of " & pCard & " needs a function labLit on its card"
         end if
      end if
      if word 1 to -1 of item 3 of tLine is not among the words of handlerNames(the script of this card) then
         set the itemDelimiter to comma
         throw "the button " & item 2 of tLine & " of " & pCard & " runs " & item 3 of tLine & ", which its card has not got"
      end if
      add tWidth + 8 to tLeft
   end repeat
   set the itemDelimiter to comma
   if tLeft > kRight - 6 then
      throw "the buttons of " & pCard & " run past the stage"
   end if
end lessonButtons

-- A button's light: a wash of the accent over it and an outline in it,
-- hidden (labLight shows them)
private command buttonLight pName, pAccent
   local tObj
   put lkBox(pName & "_lit", the rect of group pName, pAccent, 34, pName) into tObj
   set the blendLevel of tObj to 84
   set the visible of tObj to false
   put lkBox(pName & "_ring", the rect of group pName, empty, 34, pName) into tObj
   set the lineSize of tObj to 2
   set the foregroundColor of tObj to pAccent
   set the visible of tObj to false
end buttonLight

private function scriptFunctionNames pScript
   local tLine, tNames
   repeat for each line tLine in pScript
      if word 1 of tLine is "function" then
         put word 2 of tLine & space after tNames
      end if
   end repeat
   return tNames
end scriptFunctionNames

-- The names of the handlers a script has (on and command lines)
private function handlerNames pScript
   local tLine, tNames
   repeat for each line tLine in pScript
      if word 1 of tLine is "on" or word 1 of tLine is "command" then
         put word 2 of tLine & space after tNames
      end if
   end repeat
   return tNames
end handlerNames

-- The column beside the court: how it works, the Box2D calls the card's
-- script makes, and what the one clicked does
private command lessonInfo pCard, pScript
   local tObj, tLeft, tTop, tRight, tBottom, tCalls, tY, tRows, tTitle
   put item 1 of kInfo into tLeft
   put item 2 of kInfo into tTop
   put item 3 of kInfo into tRight
   put item 4 of kInfo into tBottom
   get exPanel("Info", kInfo, empty)
   put lkLabel("InfoTitle", lkR(tLeft + 18, tTop + 16, tRight - 18, tTop + 36), "How it works", 15, lkColor("ink"), empty) into tObj
   set the textStyle of tObj to "bold"
   put about("About", tLeft + 18, tTop + 44, tRight - 16, exScript(pCard & "/about")) into tY
   if tY > 400 then
      throw "the words of " & pCard & " are too long for its column (to " & tY & ")"
   end if
   put callsOf(pScript) into tCalls
   -- The list shows whole lines only, so it never ends on half a name;
   -- the title says when the wheel scrolls to more
   put (tBottom - 92 - (tY + 30) - 14) div 17 into tRows
   put "BOX2D CALLS ON THIS CARD:" && the number of lines of tCalls into tTitle
   if the number of lines of tCalls > tRows then
      put ", SCROLL" after tTitle
   end if
   put lkLabel("CallsTitle", lkR(tLeft + 18, tY + 10, tRight - 18, tY + 26), \
         tTitle, 11, lkColor("muted"), empty) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Calls", lkR(tLeft + 12, tY + 30, tRight - 12, tY + 30 + tRows * 17 + 14), tCalls, 12, lkColor("ink"), empty) into tObj
   set the listBehavior of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 17
   set the margins of tObj to "6," & 4 & ",6,4"
   -- (no scrollbar: the wheel scrolls a longer list)
   set the hiliteColor of tObj to lkMix("255,255,255", lkColor("teal"), 0.18)
   get lkBox("CallDocBg", lkR(tLeft + 12, tBottom - 84, tRight - 12, tBottom - 12), lkMix("255,255,255", lkColor("teal"), 0.08), 10, empty)
   put lkLabel("CallDoc", lkR(tLeft + 22, tBottom - 78, tRight - 20, tBottom - 16), "Click a call to see what it does.", 11, lkColor("soft"), empty) into tObj
   set the sharedText of tObj to false
end lessonInfo

-- Words, a paragraph a line, with room between them, as tall as they
-- are; returns their bottom
private function about pName, pLeft, pTop, pRight, pText
   local tObj, tIndex
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pTop + 400), pText, 12, lkColor("soft"), empty) into tObj
   repeat with tIndex = 1 to the number of lines of pText - 1
      set the spaceBelow of line tIndex of tObj to 7
   end repeat
   set the height of tObj to the formattedHeight of tObj + 4
   set the top of tObj to pTop - 4
   return the bottom of tObj
end about

-- The Box2D handlers a script calls (not those its comments name), in
-- the order it first calls them; each must have a line in the docs
private function callsOf pScript
   local tLine, tCode, tOffset, tWord, tCalls, tDocs, tChar, tIndex
   put docs() into tDocs
   repeat for each line tLine in pScript
      put tLine into tCode
      put offset("--", tCode) into tOffset
      if tOffset > 0 then
         delete char tOffset to -1 of tCode
      end if
      repeat with tIndex = 1 to the number of chars of tCode
         put char tIndex of tCode into tChar
         if tChar is not among the chars of "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" then
            put space into char tIndex of tCode
         end if
      end repeat
      repeat for each word tWord in tCode
         if char 1 to 2 of tWord is "b2" and char 3 of tWord is among the chars of "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
               and tWord is not among the lines of tCalls then
            if tWord is not among the keys of tDocs then
               throw "no docs line for " & tWord
            end if
            put tWord & return after tCalls
         end if
      end repeat
   end repeat
   delete the last char of tCalls
   return tCalls
end callsOf

-- What each Box2D handler the lessons call does, by name: "usage|what"
private function docs
   local tLine, tDocs
   set the itemDelimiter to "|"
   repeat for each line tLine in exScript("docs")
      if tLine is not empty then
         put item 2 to -1 of tLine into tDocs[item 1 of tLine]
      end if
   end repeat
   set the itemDelimiter to comma
   return tDocs
end docs

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
-- Learn Box2D: thirteen lessons in Box2D, written for OXT-Beyond in 2026.
--
-- Each lesson's world is made by the script of its card, with Box2Dxt's
-- b2... handlers, and run by the script of the group "Lab", a background
-- on every lesson: open Scripts on a lesson to read both. The sidebar,
-- the header and the drawer of scripts are the groups "Frame",
-- "Workbench" and "Scripts", which the script of the group "Frame" runs.
--
-- Box2D is Erin Catto's (https://box2d.org, MIT licence); Box2Dxt binds
-- it for xTalk (https://github.com/SethMorrowSoftware/xtalk-suite).
@*/

/*@ buttons
World|Drop a ball|dropBall
World|Drop a box|dropBox
World|Change gravity|changeGravity
Bodies|Drop a box|dropBox
Bodies|Shelf type|shelfType
Bodies|Spin platform|spinLift
Shapes|Circle|addCircle
Shapes|Box|addBox
Shapes|Capsule|addCapsule
Shapes|Polygon|addPolygon
Shapes|Two in one|addHammer
Materials|Bounce test|bounceTest
Materials|Slide test|slideTest
Materials|Heavy and light|heavyLight
Forces|Kick up|kickUp
Forces|Wind|toggleWind|switch
Forces|Spin|spinBox
Forces|Flip|flipBox
Forces|Throw|throwBall
Hinges|Push|pushSwing
Hinges|Faster|fasterMotor
Hinges|Reverse|reverseMotor
Hinges|Motor|toggleMotor|switch
Hinges|Drop balls|dropBalls
Springs|Pull down|pullWeight
Springs|Stiffer|stiffer
Springs|Softer|softer
Springs|Drop on board|dropOnBoard
Springs|Rigid board|toggleBoard|switch
Sliders|Up|liftUp|switch
Sliders|Stop|liftStop|switch
Sliders|Down|liftDown|switch
Sliders|Fire|firePiston
Sliders|Load boxes|loadBoxes
Wheels|Right|driveRight|switch
Wheels|Brake|brake|switch
Wheels|Left|driveLeft|switch
Wheels|Softer|softer
Wheels|Stiffer|stiffer
Dragging|Soft grab|softGrab|switch
Dragging|Firm grab|firmGrab|switch
Dragging|Weaker links|weaker
Dragging|Stronger links|stronger
Contacts|Drop red|dropRed
Contacts|Drop blue|dropBlue
Contacts|Drop five|dropFive
Rays|Closest / all|switchRay|switch
Rays|Follow mouse|switchAim|switch
Rays|Add shapes|addShape
Terrain|Drop ten|dropTen
Terrain|Big blast|bigBlast
Terrain|Wake all|wakeAll
Terrain|Sleep on/off|toggleSleep|switch
@*/

/*@ Lab
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
         and the mouseLoc is within the rect of graphic "Court" then
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
   put labMouseX() into tX
   put labMouseY() into tY
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
@*/

/*@ Start/card
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
@*/

/*@ World/card
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
@*/

/*@ World/about
A world holds every body and pulls them all with one gravity. You make it with b2NewWorld, put bodies in it, and step it: each b2Step moves time on by 1/60 of a second.
Box2D measures in metres, kilograms and seconds, and its y goes up. Here a metre is 50 pixels, and 0,0 is the middle of the floor.
Drag a body to throw it. Change the gravity, then watch the bodies at rest: they sleep until something wakes them.
@*/

/*@ Bodies/card
-- 02 Body Types
-- A body is a thing in the world: where it is, which way it turns, and
-- how it moves. Its type says how it moves:
--    0  static     never moves (floors, walls, shelves)
--    1  kinematic  moves at the speed you give it, and nothing stops it
--    2  dynamic    gravity, forces and collisions move it
-- Bodies have no size or form of their own: their shapes give them that.

local sWorld, sShelf, sLift

on labBuild
   local tIndex
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- A static shelf, at the left: b2NewBody's second number is the type
   put b2NewBody(sWorld, 0, -2.6, 3.2, 0, false, false) into sShelf
   get b2AddBox(sShelf, 1.2, 0.12, 1, 0.6, 0)
   labShow sShelf, "slate"
   -- A kinematic platform that slides to and fro: it keeps the speed
   -- b2SetVelocity gives it (in metres per second), whatever hits it
   put b2NewBody(sWorld, 1, 1.5, 1.8, 0, false, false) into sLift
   get b2AddBox(sLift, 1, 0.12, 1, 0.8, 0)
   b2SetVelocity sLift, 1.5, 0
   labShow sLift, "violet"
   -- Dynamic boxes, to land on both
   repeat with tIndex = 1 to 3
      dropBox
   end repeat
   labStart sWorld
end labBuild

-- Each step: the platform turns back at either end of its run
on labStep
   local tType
   if b2BodyX(sLift) > 2.8 and b2BodyVX(sLift) > 0 then
      b2SetVelocity sLift, -1.5, 0
   else if b2BodyX(sLift) < -0.2 and b2BodyVX(sLift) < 0 then
      b2SetVelocity sLift, 1.5, 0
   end if
   -- And where the mouse is, in metres: x across from the middle of the
   -- floor, y up from it
   put item (b2BodyType(sShelf) + 1) of "static,kinematic,dynamic" into tType
   labSay "mouse at x" && labNum(labMouseX(), 2) && "m, y" && labNum(labMouseY(), 2) && "m" & \
         "    the shelf is" && tType
end labStep

-- The Drop a box button
on dropBox
   local tBody
   put b2NewBody(sWorld, 2, random(60) / 10 - 3, 7.5, 0, false, false) into tBody
   get b2AddBox(tBody, 0.3, 0.3, 1, 0.6, 0.1)
   labShow tBody, "amber"
end dropBox

-- The Shelf type button: the shelf becomes dynamic (and falls), then
-- kinematic, then static again
on shelfType
   switch b2BodyType(sShelf)
      case 0
         b2SetBodyType sShelf, 2
         labTint sShelf, "amber"
         break
      case 2
         -- (a kinematic body with no speed hangs where it is)
         b2SetBodyType sShelf, 1
         b2SetVelocity sShelf, 0, 0
         b2SetAngularVelocity sShelf, 0
         labTint sShelf, "violet"
         break
      default
         b2SetBodyType sShelf, 0
         labTint sShelf, "slate"
   end switch
   b2SetAwake sShelf, true
end shelfType

-- The Spin platform button: a kinematic body turns, too, at the speed
-- in radians per second that b2SetAngularVelocity gives it
on spinLift
   if b2BodyAngularVelocity(sLift) is 0 then
      b2SetAngularVelocity sLift, 1.2
   else
      b2SetAngularVelocity sLift, 0
      b2SetTransform sLift, b2BodyX(sLift), b2BodyY(sLift), 0
   end if
end spinLift
@*/

/*@ Bodies/about
Every body has a type. Static bodies never move, like the grey shelf. Kinematic bodies move at the speed you set, like the purple platform, and nothing pushes them. Dynamic bodies, the boxes, are moved by gravity and by what they hit.
Shelf type switches the shelf between the three. The line at the top of the court shows where the mouse is in metres.
@*/

/*@ Shapes/card
-- 03 Shapes
-- A shape gives a body its form, and the stuff it is made of. One body
-- can have many shapes, which then move as one. Each kind has its own
-- handler; the last three numbers are always density, friction and
-- bounce (restitution).

local sWorld, sLast

on labBuild
   local tRamp, tBump
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- Segments: lines with no inside, best on static bodies. Two make a
   -- ramp on the left
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tRamp
   get b2AddSegment(tRamp, -4.1, 3, -1.6, 1.4, 0.6, 0)
   get b2AddSegment(tRamp, -1.6, 1.4, -0.6, 1.4, 0.6, 0)
   labShow tRamp, "slate"
   -- A static triangle: a polygon, built a point at a time
   put b2NewBody(sWorld, 0, 2.4, 0, 0, false, false) into tBump
   b2PolyBegin
   b2PolyAddPoint -1, 0
   b2PolyAddPoint 1, 0
   b2PolyAddPoint 0, 0.9
   get b2AddPolygon(tBump, 1, 0.6, 0)
   labShow tBump, "slate"
   addCircle
   addBox
   addCapsule
   addPolygon
   labStart sWorld
end labBuild

-- A new dynamic body, high up, for the buttons below
private function newBody
   return b2NewBody(sWorld, 2, random(60) / 10 - 3, 8, random(314) / 100, false, false)
end newBody

-- The Circle button: a circle's middle (around the body) and radius
on addCircle
   put newBody() into sLast
   get b2AddCircle(sLast, 0, 0, 0.35, 1, 0.3, 0.3)
   labShow sLast, "sky"
end addCircle

-- The Box button: half its width, half its height
on addBox
   put newBody() into sLast
   get b2AddBox(sLast, 0.5, 0.25, 1, 0.5, 0.1)
   labShow sLast, "amber"
end addBox

-- The Capsule button: a line between two points, made fat by a radius
on addCapsule
   put newBody() into sLast
   get b2AddCapsule(sLast, -0.35, 0, 0.35, 0, 0.2, 1, 0.5, 0.1)
   labShow sLast, "teal"
end addCapsule

-- The Polygon button: 3 to 7 points around the body's middle. Box2D
-- makes a convex polygon of them (no dents), of 8 points at most
on addPolygon
   local tCount, tIndex, tAngle
   put newBody() into sLast
   put 2 + random(5) into tCount
   b2PolyBegin
   repeat with tIndex = 1 to tCount
      put tIndex * 2 * pi / tCount into tAngle
      b2PolyAddPoint 0.45 * cos(tAngle), 0.45 * sin(tAngle)
   end repeat
   get b2AddPolygon(sLast, 1, 0.5, 0.1)
   labShow sLast, "rose"
end addPolygon

-- The Two in one button: a hammer, a box and a circle on one body
on addHammer
   put newBody() into sLast
   get b2AddBox(sLast, 0.08, 0.5, 1, 0.5, 0.1)
   get b2AddCircle(sLast, 0, 0.55, 0.22, 4, 0.5, 0.1)
   labShow sLast, "lime"
end addHammer

-- Each step: the newest body's shapes, by their type numbers
on labStep
   local tCount, tIndex, tTypes
   put b2BodyShapeCount(sLast) into tCount
   repeat with tIndex = 1 to tCount
      put item (b2ShapeType(b2BodyShapeAt(tIndex)) + 1) of "circle,capsule,segment,polygon,chain" & " " after tTypes
   end repeat
   labSay "the newest body has" && tCount && "shape(s):" && tTypes & "  mass" && labNum(b2BodyMass(sLast), 2) && "kg"
end labStep
@*/

/*@ Shapes/about
Shapes give bodies their form: circles, boxes, capsules, convex polygons of up to 8 points, and segments, which are lines best kept on static bodies.
A body can carry many shapes. The hammer is a box and a circle on one body, and they move as one. Its heavy head makes it land head first.
A shape's mass comes from its area and its density.
@*/

/*@ Materials/card
-- 04 Materials
-- Every shape has three numbers that say what it is made of:
--    density      kilograms per square metre: how heavy it is
--    friction     0 is ice; 1 or more grips
--    restitution  0 lands dead; 1 bounces back as high
-- Two shapes that touch mix their numbers: friction by the square root
-- of the two multiplied, restitution by the larger.

local sWorld, sRamp
-- The newest three balls of the bounce test, and until when the line at
-- the court's top keeps the masses Heavy and light put there
local sBalls, sHold

on labBuild
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- A ramp on the right: a static triangle, its friction 1
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into sRamp
   b2PolyBegin
   b2PolyAddPoint 0.2, 0
   b2PolyAddPoint 4.1, 0
   b2PolyAddPoint 4.1, 2.6
   get b2AddPolygon(sRamp, 1, 1, 0)
   labShow sRamp, "slate"
   bounceTest
   slideTest
   labStart sWorld
end labBuild

-- The Bounce test button: three balls, alike but for their restitution
on bounceTest
   put empty into sBalls
   dropBall -3.3, 0, "rose"
   dropBall -2.5, 0.5, "amber"
   dropBall -1.7, 0.9, "lime"
end bounceTest

private command dropBall pX, pBounce, pColor
   local tBody
   put b2NewBody(sWorld, 2, pX, 7, 0, false, false) into tBody
   get b2AddCircle(tBody, 0, 0, 0.3, 1, 0.3, pBounce)
   labShow tBody, pColor
   put tBody & "|" & pBounce & return after sBalls
end dropBall

-- Each step: how high each ball of the bounce test is, by its
-- restitution, so you can watch the bounces shrink
on labStep
   local tLine, tSay
   if the milliseconds < sHold then
      exit labStep
   end if
   set the itemDelimiter to "|"
   repeat for each line tLine in sBalls
      if labIsShown(item 1 of tLine) then
         put "    " & item 2 of tLine & ":" && labNum(b2BodyY(item 1 of tLine) - 0.3, 1) && "m" after tSay
      end if
   end repeat
   set the itemDelimiter to comma
   labSay "height by restitution" & tSay
end labStep

-- The Slide test button: three boxes on the ramp, alike but for their
-- friction: none, a little, and enough to hold
on slideTest
   setBox 3.5, 0, "rose"
   setBox 2.7, 0.2, "amber"
   setBox 1.9, 0.8, "lime"
end slideTest

-- A box resting on the ramp: turned to its slope, and lifted off it by
-- half its height
private command setBox pX, pFriction, pColor
   local tAngle, tY, tBody
   put atan2(2.6, 3.9) into tAngle
   put (pX - 0.2) * 2.6 / 3.9 into tY
   put b2NewBody(sWorld, 2, pX - 0.26 * sin(tAngle), tY + 0.26 * cos(tAngle), tAngle, false, false) into tBody
   get b2AddBox(tBody, 0.25, 0.25, 1, pFriction, 0)
   labShow tBody, pColor
end setBox

-- The Heavy and light button: two balls the same size, one 20 times
-- as dense, side by side on the floor; the heavy one is rolled into the
-- light one
on heavyLight
   local tHeavy, tLight
   put b2NewBody(sWorld, 2, -3.6, 0.4, 0, false, false) into tHeavy
   get b2AddCircle(tHeavy, 0, 0, 0.4, 10, 0.3, 0.2)
   labShow tHeavy, "violet"
   put b2NewBody(sWorld, 2, -1.2, 0.4, 0, false, false) into tLight
   get b2AddCircle(tLight, 0, 0, 0.4, 0.5, 0.3, 0.2)
   labShow tLight, "sky"
   b2SetVelocity tHeavy, 5, 0
   put the milliseconds + 3000 into sHold
   labSay "heavy:" && labNum(b2BodyMass(tHeavy), 1) && "kg    light:" && labNum(b2BodyMass(tLight), 1) && "kg", true
end heavyLight
@*/

/*@ Materials/about
A shape's material is three numbers. Density makes it heavy or light. Friction makes it slide or grip. Restitution makes it bounce.
The three balls differ only in restitution: 0, 0.5 and 0.9. The three boxes on the ramp differ only in friction: 0, 0.2 and 0.8. The ramp is steep, so only the green box holds.
Heavy and light rolls a heavy ball into a light one of the same size.
@*/

/*@ Forces/card
-- 05 Forces & Motion
-- You move a dynamic body by pushing it, or by telling it how fast to go:
--    b2ApplyForce          a push that lasts: give it every step
--    b2ApplyImpulse        a kick, all at once
--    b2ApplyTorque, b2ApplyAngularImpulse   the same, for turning
--    b2ApplyImpulseAt      a kick at a point: off the middle, it turns too
--    b2SetVelocity         a speed, at once, whatever the body weighs
-- A force in newtons moves 1 kilogram faster by 1 m/s every second.

local sWorld, sBall, sBox, sBalloon, sWind

on labBuild
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   put b2NewBody(sWorld, 2, -2, 0.4, 0, false, false) into sBall
   get b2AddCircle(sBall, 0, 0, 0.4, 1, 0.5, 0.3)
   labShow sBall, "sky"
   put b2NewBody(sWorld, 2, 1.5, 0.5, 0, false, false) into sBox
   get b2AddBox(sBox, 0.5, 0.5, 1, 0.6, 0.1)
   labShow sBox, "amber"
   -- A balloon: a body that gravity pulls up a little (a gravity scale
   -- below 0) and the air slows (linear damping)
   put b2NewBody(sWorld, 2, 3.2, 1, 0, false, false) into sBalloon
   get b2AddCircle(sBalloon, 0, 0, 0.35, 0.3, 0.3, 0.5)
   b2SetGravityScale sBalloon, -0.25
   b2SetLinearDamping sBalloon, 1.5
   labShow sBalloon, "rose"
   put false into sWind
   labStart sWorld
end labBuild

-- The Kick up button: an impulse up. An impulse changes a body's speed
-- by impulse / mass, so the ball's mass makes the kick the same for any
-- size of ball
on kickUp
   b2ApplyImpulse sBall, 0, 7 * b2BodyMass(sBall), true
end kickUp

-- The Wind button: a force to the right, which labStep gives every step
on toggleWind
   put not sWind into sWind
end toggleWind

-- The Spin button: an angular impulse turns the box
on spinBox
   b2ApplyAngularImpulse sBox, 2 * b2BodyMass(sBox), true
end spinBox

-- The Flip button: an impulse up, at the box's right side, so it turns
-- as it rises
on flipBox
   b2ApplyImpulseAt sBox, 0, 5 * b2BodyMass(sBox), b2BodyX(sBox) + 0.45, b2BodyY(sBox), true
end flipBox

-- The Throw button: a velocity, set: up and to the left, in m/s
on throwBall
   b2SetVelocity sBall, -4, 8
end throwBall

on labStep
   if sWind then
      -- (a force lasts one step: to keep pushing, push every step)
      b2ApplyForce sBall, 12, 0, true
      b2ApplyForce sBox, 12, 0, true
      b2ApplyForce sBalloon, 4, 0, true
   end if
   labSay "ball: speed" && labNum(sqrt(b2BodyVX(sBall) ^ 2 + b2BodyVY(sBall) ^ 2), 1) && "m/s" & \
         "    box: turning" && round(b2BodyAngularVelocity(sBox) * 180 / pi) && "degrees/s" & \
         "    wind:" && sWind
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "toggleWind"
         return sWind
   end switch
   return false
end labLit
@*/

/*@ Forces/about
A force pushes for as long as you keep giving it, once a step, as the wind does. An impulse is a kick, given once.
The box spins from an angular impulse. Flip kicks it at one side, so it turns as it rises. Throw sets the ball's speed outright.
The pink balloon has a gravity scale of -0.25, so gravity pulls it up. Its damping makes the air slow it.
@*/

/*@ Hinges/card
-- 06 Hinges: the revolute joint
-- A joint ties two bodies together. A revolute joint pins them at one
-- point and lets them turn about it, as a hinge or an axle does. Each
-- body has its own anchor, in its own frame: the two anchors are the
-- same point in the world. The joint can have
--    a motor   that turns it at a speed, with a torque it may not pass
--    a limit   two angles it may not turn beyond

local sWorld, sSwing, sBob, sMill, sFlap, sSpeed

on labBuild
   local tPivot, tHub, tBlades, tFlapHub, tFlap
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- A pendulum: a static pivot, and a ball 1.8 metres to its right. The
   -- pivot's anchor is its middle; the ball's is 1.8 metres to ITS left
   put b2NewBody(sWorld, 0, -2.4, 7.6, 0, false, false) into tPivot
   get b2AddCircle(tPivot, 0, 0, 0.08, 1, 0.5, 0)
   labShow tPivot, "slate"
   put b2NewBody(sWorld, 2, -0.6, 7.6, 0, false, false) into sBob
   get b2AddCircle(sBob, 0, 0, 0.35, 2, 0.5, 0.2)
   labShow sBob, "sky"
   put b2RevoluteJoint(sWorld, tPivot, sBob, 0, 0, -1.8, 0, false) into sSwing
   labShowJoint sSwing
   -- A windmill: a cross of two boxes on one body, on a hub, turned by
   -- the joint's motor at 1.5 radians a second, with up to 400 N m
   put b2NewBody(sWorld, 0, 1.6, 4.2, 0, false, false) into tHub
   get b2AddCircle(tHub, 0, 0, 0.12, 1, 0.5, 0)
   put b2NewBody(sWorld, 2, 1.6, 4.2, 0, false, false) into tBlades
   get b2AddBox(tBlades, 1.5, 0.1, 1, 0.5, 0.1)
   b2PolyBegin
   b2PolyAddPoint -0.1, -1.5
   b2PolyAddPoint 0.1, -1.5
   b2PolyAddPoint 0.1, 1.5
   b2PolyAddPoint -0.1, 1.5
   get b2AddPolygon(tBlades, 1, 0.5, 0.1)
   labShow tBlades, "violet"
   labShow tHub, "slate"
   put b2RevoluteJoint(sWorld, tHub, tBlades, 0, 0, 0, 0, false) into sMill
   put 1.5 into sSpeed
   b2RevoluteEnableMotor sMill, true, sSpeed, 400
   -- A flap with a limit: it may turn from -0.6 to 0.3 radians (about
   -- -34 to 17 degrees), and no further
   put b2NewBody(sWorld, 0, -3.4, 2.2, 0, false, false) into tFlapHub
   get b2AddCircle(tFlapHub, 0, 0, 0.08, 1, 0.5, 0)
   put b2NewBody(sWorld, 2, -2.6, 2.2, 0, false, false) into tFlap
   get b2AddBox(tFlap, 0.8, 0.08, 1, 0.6, 0)
   labShow tFlap, "amber"
   labShow tFlapHub, "slate"
   put b2RevoluteJoint(sWorld, tFlapHub, tFlap, 0, 0, -0.8, 0, false) into sFlap
   b2RevoluteEnableLimit sFlap, true, -0.6, 0.3
   dropBalls
   labStart sWorld
end labBuild

-- The Push button: an impulse to the pendulum's ball
on pushSwing
   b2ApplyImpulse sBob, 6 * b2BodyMass(sBob), 0, true
end pushSwing

-- The Faster button: the motor's speed, up to 6 radians a second
on fasterMotor
   if abs(sSpeed) < 6 then
      put sSpeed * 1.5 into sSpeed
   end if
   b2RevoluteEnableMotor sMill, true, sSpeed, 400
end fasterMotor

-- The Reverse button
on reverseMotor
   put -sSpeed into sSpeed
   b2RevoluteSetMotorSpeed sMill, sSpeed
   b2JointWakeBodies sMill
end reverseMotor

-- The Motor button (on and off): off, the windmill turns only when pushed
on toggleMotor
   b2RevoluteEnableMotor sMill, not b2RevoluteIsMotorEnabled(sMill), sSpeed, 400
   b2JointWakeBodies sMill
end toggleMotor

-- The Drop balls button
on dropBalls
   local tIndex, tBody
   repeat with tIndex = 1 to 4
      put b2NewBody(sWorld, 2, random(60) / 10 - 3, 8.4, 0, false, false) into tBody
      get b2AddCircle(tBody, 0, 0, 0.22, 1, 0.4, 0.3)
      labShow tBody, "lime"
   end repeat
end dropBalls

on labStep
   labSay "pendulum" && round(b2RevoluteAngle(sSwing) * 180 / pi) & "  windmill:" && \
         labNum(b2RevoluteMotorSpeed(sMill), 1) && "rad/s," && round(b2RevoluteMotorTorque(sMill)) && "N m" & \
         "  flap" && round(b2RevoluteAngle(sFlap) * 180 / pi) && "(limit -34 to 17)"
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "toggleMotor"
         return b2RevoluteIsMotorEnabled(sMill)
   end switch
   return false
end labLit
@*/

/*@ Hinges/about
A revolute joint is a hinge. It pins two bodies at one point and lets them turn. You give each body's anchor in that body's own frame, in metres.
The windmill turns by the joint's motor, at a speed, with no more torque than you allow. The yellow flap has a limit, two angles it cannot pass.
The dashed lines are the joints.
@*/

/*@ Springs/card
-- 07 Rods, Springs and Welds
-- A distance joint keeps two points a length apart:
--    as it is   a rigid rod
--    a spring   it stretches and pulls back (b2DistanceEnableSpring)
--    a range    a rope: any length up to the longest (b2DistanceSetLengthRange)
-- A weld joint glues two bodies so that they move as one; with a
-- stiffness, it bends and springs back (b2WeldSetStiffness).

local sWorld, sSpring, sWeight, sHertz, sWelds, sBendy

on labBuild
   local tCeiling, tA, tB, tRope, tBall, tWall, tPrev, tPlank, tIndex, tWeld
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   put b2NewBody(sWorld, 0, 0, 8.4, 0, false, false) into tCeiling
   get b2AddBox(tCeiling, 4.1, 0.1, 1, 0.5, 0)
   labShow tCeiling, "slate"
   -- A spring: a box hung 2.2 metres below the ceiling, 1.5 times a
   -- second (hertz), with a little damping (0.1)
   put b2NewBody(sWorld, 2, -2.8, 5.5, 0, false, false) into sWeight
   get b2AddBox(sWeight, 0.35, 0.35, 1, 0.5, 0.1)
   labShow sWeight, "amber"
   put b2DistanceJoint(sWorld, tCeiling, sWeight, -2.8, -0.1, 0, 0.35, 2.2, false) into sSpring
   put 1.5 into sHertz
   b2DistanceEnableSpring sSpring, true, sHertz, 0.1
   labShowJoint sSpring
   -- A rod: two balls kept 1.3 metres apart, thrown in the air
   put b2NewBody(sWorld, 2, -0.9, 6, 0, false, false) into tA
   get b2AddCircle(tA, 0, 0, 0.25, 1, 0.5, 0.2)
   put b2NewBody(sWorld, 2, 0.3, 6.5, 0, false, false) into tB
   get b2AddCircle(tB, 0, 0, 0.25, 1, 0.5, 0.2)
   labShow tA, "sky"
   labShow tB, "sky"
   labShowJoint b2DistanceJoint(sWorld, tA, tB, 0, 0, 0, 0, 1.3, false)
   b2ApplyAngularImpulse tA, 0.5, true
   -- A rope: a ball that may hang up to 2.5 metres below the ceiling,
   -- and swing anywhere nearer. A spring of 0 hertz pulls not at all; the
   -- range does the work
   put b2NewBody(sWorld, 2, 0.8, 7.6, 0, false, false) into tBall
   get b2AddCircle(tBall, 0, 0, 0.3, 1, 0.5, 0.2)
   labShow tBall, "rose"
   put b2DistanceJoint(sWorld, tCeiling, tBall, 0.6, -0.1, 0, 0, 2.5, false) into tRope
   b2DistanceEnableSpring tRope, true, 0, 0
   b2DistanceSetLengthRange tRope, 0, 2.5
   labShowJoint tRope
   -- A diving board: four planks out from the wall at the right, each
   -- welded to the one before it
   put b2NewBody(sWorld, 0, 3.8, 2.4, 0, false, false) into tWall
   get b2AddBox(tWall, 0.3, 0.5, 1, 0.5, 0)
   labShow tWall, "slate"
   put tWall into tPrev
   put empty into sWelds
   repeat with tIndex = 1 to 4
      put b2NewBody(sWorld, 2, 3.5 - tIndex * 0.5 + 0.25, 2.6, 0, false, false) into tPlank
      get b2AddBox(tPlank, 0.25, 0.07, 1, 0.6, 0)
      labShow tPlank, "teal"
      if tIndex is 1 then
         put b2WeldJoint(sWorld, tPrev, tPlank, -0.3, 0.2, 0.25, 0, 0, false) into tWeld
      else
         put b2WeldJoint(sWorld, tPrev, tPlank, -0.25, 0, 0.25, 0, 0, false) into tWeld
      end if
      put tWeld & comma after sWelds
      put tPlank into tPrev
   end repeat
   put true into sBendy
   setBoard
   labStart sWorld
end labBuild

-- The board's welds: bendy (an angular spring of 2 hertz) or rigid (0)
private command setBoard
   local tWeld
   repeat for each item tWeld in sWelds
      if sBendy then
         b2WeldSetStiffness tWeld, 0, 0, 2, 0.3
      else
         b2WeldSetStiffness tWeld, 0, 0, 0, 0
      end if
      b2JointWakeBodies tWeld
   end repeat
end setBoard

-- The Stiffer and Softer buttons: the spring's hertz
on stiffer
   put min(8, sHertz * 1.5) into sHertz
   b2DistanceEnableSpring sSpring, true, sHertz, 0.1
   b2JointWakeBodies sSpring
end stiffer

on softer
   put max(0.4, sHertz / 1.5) into sHertz
   b2DistanceEnableSpring sSpring, true, sHertz, 0.1
   b2JointWakeBodies sSpring
end softer

-- The Pull down button
on pullWeight
   b2ApplyImpulse sWeight, 0, -6 * b2BodyMass(sWeight), true
end pullWeight

-- The Drop on board button: a heavy ball onto the end of the board
on dropOnBoard
   local tBody
   put b2NewBody(sWorld, 2, 1.9, 6, 0, false, false) into tBody
   get b2AddCircle(tBody, 0, 0, 0.3, 3, 0.5, 0.1)
   labShow tBody, "violet"
end dropOnBoard

-- The Rigid board button: bendy, then rigid, then bendy again
on toggleBoard
   put not sBendy into sBendy
   setBoard
end toggleBoard

private function boardName
   if sBendy then
      return "bendy"
   end if
   return "rigid"
end boardName

on labStep
   labSay "spring" && labNum(sHertz, 1) && "hertz: rest 2.2 m, now" && \
         labNum(b2DistanceCurrentLength(sSpring), 2) && "m    board:" && boardName()
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "toggleBoard"
         return not sBendy
   end switch
   return false
end labLit
@*/

/*@ Springs/about
A distance joint holds two points a length apart. As it is, it is a rigid rod, like the blue pair. With a spring it stretches and pulls back, like the yellow box: the spring's hertz says how fast it bounces. With a range it is a rope, like the pink ball.
The board at the right is four planks welded end to end. Its welds have an angular spring, so it bends.
@*/

/*@ Sliders/card
-- 08 Sliders: the prismatic joint
-- A prismatic joint lets one body slide along a line (an axis) on
-- another, and not turn: a lift in its shaft, a piston, a drawer. Like a
-- hinge, it can have a limit (how far it slides) and a motor (how fast,
-- with a force it may not pass); it can also have a spring.

local sWorld, sLift, sLiftJoint, sRam, sRamJoint, sLiftMove

on labBuild
   local tShaft, tBase, tIndex
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- The lift: a platform on a static base, sliding on the axis 0,1 (up),
   -- from 0 to 5.5 metres above where it starts
   put b2NewBody(sWorld, 0, -2.6, 0, 0, false, false) into tShaft
   put b2NewBody(sWorld, 2, -2.6, 0.4, 0, false, false) into sLift
   get b2AddBox(sLift, 0.9, 0.1, 2, 0.8, 0)
   labShow sLift, "violet"
   put b2PrismaticJoint(sWorld, tShaft, sLift, 0, 0.4, 0, 0, 0, 1, 0, false) into sLiftJoint
   b2PrismaticEnableLimit sLiftJoint, true, 0, 5.5
   b2PrismaticEnableMotor sLiftJoint, true, 0, 3000
   put "stop" into sLiftMove
   -- The piston: a ram that slides along the floor (axis 1,0), held back
   -- by a spring
   put b2NewBody(sWorld, 0, 0.4, 0, 0, false, false) into tBase
   get b2AddBox(tBase, 0.15, 0.6, 1, 0.5, 0)
   labShow tBase, "slate"
   put b2NewBody(sWorld, 2, 0.95, 0.3, 0, false, false) into sRam
   get b2AddBox(sRam, 0.4, 0.28, 2, 0.2, 0)
   labShow sRam, "amber"
   put b2PrismaticJoint(sWorld, tBase, sRam, 0.55, 0.3, 0, 0, 1, 0, 0, false) into sRamJoint
   b2PrismaticEnableLimit sRamJoint, true, 0, 2
   b2PrismaticEnableSpring sRamJoint, true
   b2PrismaticSetSpringHertz sRamJoint, 2
   b2PrismaticSetSpringDamping sRamJoint, 0.3
   repeat with tIndex = 1 to 3
      loadBoxes
   end repeat
   labStart sWorld
end labBuild

-- The Up, Stop and Down buttons: the motor's speed, in metres a second
on liftUp
   put "up" into sLiftMove
   b2PrismaticSetMotorSpeed sLiftJoint, 1.2
   b2JointWakeBodies sLiftJoint
end liftUp

on liftStop
   put "stop" into sLiftMove
   b2PrismaticSetMotorSpeed sLiftJoint, 0
end liftStop

on liftDown
   put "down" into sLiftMove
   b2PrismaticSetMotorSpeed sLiftJoint, -1.2
   b2JointWakeBodies sLiftJoint
end liftDown

-- The Fire button: a kick to the ram; the spring brings it back
on firePiston
   local tBall
   put b2NewBody(sWorld, 2, 2, 0.3, 0, false, false) into tBall
   get b2AddCircle(tBall, 0, 0, 0.3, 1, 0.3, 0.3)
   labShow tBall, "lime"
   b2ApplyImpulse sRam, 9 * b2BodyMass(sRam), 0, true
end firePiston

-- The Load boxes button: a box onto the lift
on loadBoxes
   local tBody
   put b2NewBody(sWorld, 2, -2.6 + (random(10) - 5) / 10, 7, 0, false, false) into tBody
   get b2AddBox(tBody, 0.25, 0.25, 1, 0.6, 0)
   labShow tBody, "sky"
end loadBoxes

on labStep
   -- (at either end, the motor stops: the limit holds it there)
   labSay "lift:" && labNum(b2PrismaticTranslation(sLiftJoint), 2) && "m up, at" && \
         labNum(b2PrismaticSpeed(sLiftJoint), 1) && "m/s, motor force" && round(b2PrismaticMotorForce(sLiftJoint)) && "N" & \
         "    ram:" && labNum(b2PrismaticTranslation(sRamJoint), 2) && "m"
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "liftUp"
         return sLiftMove is "up"
      case "liftStop"
         return sLiftMove is not "up" and sLiftMove is not "down"
      case "liftDown"
         return sLiftMove is "down"
   end switch
   return false
end labLit
@*/

/*@ Sliders/about
A prismatic joint lets a body slide along one line and stops it turning.
The purple lift slides up its shaft by the joint's motor, between the limits 0 and 5.5 metres. Its motor force is what it takes to hold the boxes up.
The yellow ram slides along the floor. A spring on its joint pulls it back after Fire kicks it.
@*/

/*@ Wheels/card
-- 09 Wheels: the wheel joint
-- A wheel joint is made for vehicles. The wheel turns freely on its
-- axle, as on a hinge, and the axle slides up and down on a spring, as
-- in a slider: that is the suspension. Its motor drives the wheel; at a
-- speed of 0, the motor holds it, which is a brake.
-- Drive with the left and right arrow keys, or the buttons.

local sWorld, sCar, sWheels, sDrive, sKeyAt, sHertz

on labBuild
   local tBumps, tRamp, tWheel, tJoint, tX
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- Bumps on the floor: circles, half sunk; and a ramp at the right
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tBumps
   get b2AddCircle(tBumps, -0.6, -0.1, 0.3, 1, 0.8, 0)
   get b2AddCircle(tBumps, 0.2, -0.15, 0.3, 1, 0.8, 0)
   get b2AddCircle(tBumps, 0.9, -0.1, 0.25, 1, 0.8, 0)
   labShow tBumps, "slate"
   put b2NewBody(sWorld, 0, 0, 0, 0, false, false) into tRamp
   b2PolyBegin
   b2PolyAddPoint 1.9, 0
   b2PolyAddPoint 4.1, 0
   b2PolyAddPoint 4.1, 1.2
   get b2AddPolygon(tRamp, 1, 0.8, 0)
   labShow tRamp, "slate"
   -- The car's body
   put b2NewBody(sWorld, 2, -2.6, 1, 0, false, false) into sCar
   b2PolyBegin
   b2PolyAddPoint -0.85, -0.15
   b2PolyAddPoint 0.85, -0.15
   b2PolyAddPoint 0.7, 0.15
   b2PolyAddPoint 0.15, 0.45
   b2PolyAddPoint -0.55, 0.45
   b2PolyAddPoint -0.85, 0.15
   get b2AddPolygon(sCar, 1, 0.5, 0)
   labShow sCar, "rose"
   -- Two wheels. Each joint's anchor on the car is where the wheel's
   -- middle is; its axis is 0,1, the way the suspension moves
   put 4 into sHertz
   put empty into sWheels
   repeat for each item tX in "-0.55,0.55"
      put b2NewBody(sWorld, 2, -2.6 + tX, 0.5, 0, false, false) into tWheel
      get b2AddCircle(tWheel, 0, 0, 0.3, 1, 1.2, 0)
      labShow tWheel, "white"
      put b2WheelJoint(sWorld, sCar, tWheel, tX, -0.5, 0, 0, 0, 1, false) into tJoint
      b2WheelEnableSpring tJoint, true, sHertz, 0.7
      b2WheelEnableMotor tJoint, true, 0, 12
      labShowJoint tJoint
      put tJoint & comma after sWheels
   end repeat
   put 0 into sDrive
   labStart sWorld
end labBuild

-- Sets both wheels' motors: pDirection 1 is right, -1 left, 0 the brake
private command drive pDirection
   local tJoint
   put pDirection into sDrive
   repeat for each item tJoint in sWheels
      -- (a wheel rolling to the right turns clockwise: a minus speed)
      b2WheelEnableMotor tJoint, true, -12 * pDirection, 12
      b2JointWakeBodies tJoint
   end repeat
end drive

-- The buttons
on driveLeft
   drive -1
end driveLeft

on brake
   drive 0
end brake

on driveRight
   drive 1
end driveRight

-- The Softer and Stiffer buttons: the suspension's springs
on softer
   put max(1, sHertz / 1.5) into sHertz
   springs
end softer

on stiffer
   put min(12, sHertz * 1.5) into sHertz
   springs
end stiffer

private command springs
   local tJoint
   repeat for each item tJoint in sWheels
      b2WheelEnableSpring tJoint, true, sHertz, 0.7
      b2JointWakeBodies tJoint
   end repeat
end springs

-- The arrow keys drive while they are held: each key sent again while
-- held keeps it going; when they stop, labStep brakes
on arrowKey pKey
   if pKey is "left" then
      drive -1
      put the milliseconds into sKeyAt
   else if pKey is "right" then
      drive 1
      put the milliseconds into sKeyAt
   else
      pass arrowKey
   end if
end arrowKey

on labStep
   if sKeyAt is not empty and the milliseconds - sKeyAt > 600 then
      put empty into sKeyAt
      drive 0
   end if
   labSay "speed" && labNum(b2BodyVX(sCar), 1) && "m/s    motor torque" && \
         labNum(b2WheelMotorTorque(item 1 of sWheels), 1) && "N m    springs" && labNum(sHertz, 1) && "hertz"
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "driveRight"
         return sDrive is 1
      case "brake"
         return sDrive is 0
      case "driveLeft"
         return sDrive is -1
   end switch
   return false
end labLit
@*/

/*@ Wheels/about
A wheel joint lets a wheel spin on its axle while the axle rides up and down on a spring, the suspension.
Its motor drives the wheel. A speed of 0 holds it still, which is the brake. Drive over the bumps and up the ramp, then make the springs softer or stiffer and try again.
The arrow keys drive while you hold them.
@*/

/*@ Dragging/card
-- 10 Dragging: the mouse joint
-- A mouse joint pulls one body toward a target point, like a spring,
-- but never harder than the force you allow. Move the target each step
-- and the body follows the mouse; it still collides with everything.
-- Every lesson lets you drag; this card does it in its own script, so you
-- can read it (cOwnDrag tells the Lab to leave it to this card).
-- Joints also report the force they hold with: pull the chain hard and
-- a link that holds more than its limit is destroyed: it breaks.

local sWorld, sGround, sGrab, sHertz, sLinks, sLimit, sMost

on labBuild
   local tTop, tPrev, tLink, tJoint, tIndex, tWeight, tBox
   put b2NewWorld(0, -10, true, true) into sWorld
   put labWalls(sWorld) into sGround
   -- A chain of six links from the ceiling, and a weight at its end
   put b2NewBody(sWorld, 0, 1.8, 8.4, 0, false, false) into tTop
   get b2AddBox(tTop, 0.4, 0.08, 1, 0.5, 0)
   labShow tTop, "slate"
   put tTop into tPrev
   put empty into sLinks
   repeat with tIndex = 1 to 6
      put b2NewBody(sWorld, 2, 1.8, 8.4 - tIndex * 0.5 + 0.25, 0, false, false) into tLink
      get b2AddBox(tLink, 0.07, 0.25, 1, 0.5, 0)
      labShow tLink, "amber"
      if tIndex is 1 then
         put b2RevoluteJoint(sWorld, tPrev, tLink, 0, 0, 0, 0.25, false) into tJoint
      else
         put b2RevoluteJoint(sWorld, tPrev, tLink, 0, -0.25, 0, 0.25, false) into tJoint
      end if
      put tJoint & comma after sLinks
      put tLink into tPrev
   end repeat
   put b2NewBody(sWorld, 2, 1.8, 5.05, 0, false, false) into tWeight
   get b2AddCircle(tWeight, 0, 0, 0.35, 2, 0.5, 0.1)
   labShow tWeight, "violet"
   put b2RevoluteJoint(sWorld, tPrev, tWeight, 0, -0.25, 0, 0.3, false) into tJoint
   put tJoint & comma after sLinks
   -- Boxes on the floor, to drag about and stack
   repeat with tIndex = 1 to 5
      put b2NewBody(sWorld, 2, -3.5 + tIndex * 0.8, 0.35, 0, false, false) into tBox
      get b2AddBox(tBox, 0.3, 0.3, 1, 0.6, 0)
      labShow tBox, "sky"
   end repeat
   if sHertz is empty then
      put 5 into sHertz
   end if
   if sLimit is empty then
      put 150 into sLimit
   end if
   put 0 into sMost
   labStart sWorld
end labBuild

-- A click on a body: a mouse joint between the walls' static body and it,
-- its target where the click is. Its last number, the most force it may
-- pull with, is 1000 times the body's mass
on mouseDown pButton
   local tX, tY, tBody
   put labMouseX() into tX
   put labMouseY() into tY
   put b2BodyAtPoint(sWorld, tX, tY) into tBody
   if pButton is 1 and tBody is not 0 and b2BodyType(tBody) is 2 then
      put b2MouseJoint(sWorld, sGround, tBody, tX, tY, sHertz, 0.7, 1000 * b2BodyMass(tBody)) into sGrab
      b2SetAwake tBody, true
      labShowJoint sGrab
   end if
   pass mouseDown
end mouseDown

-- Each step: the target goes where the mouse is, until the button is let
-- go; and each link's force is checked against the limit
on labStep
   local tJoint, tForce, tLeft
   if sGrab is not empty then
      if the mouse is up then
         b2DestroyJoint sGrab
         put empty into sGrab
      else
         b2MouseSetTarget sGrab, labMouseX(), labMouseY()
      end if
   end if
   put 0 into tForce
   repeat for each item tJoint in sLinks
      put sqrt(b2JointConstraintForceX(tJoint) ^ 2 + b2JointConstraintForceY(tJoint) ^ 2) into tForce
      put max(sMost, tForce) into sMost
      if tForce > sLimit then
         b2DestroyJoint tJoint
      else
         put tJoint & comma after tLeft
      end if
   end repeat
   put tLeft into sLinks
   labSay "the most a link has held:" && round(sMost) && "N    links break above" && sLimit && "N    grab:" && sHertz && "hertz"
end labStep

-- The Soft grab and Firm grab buttons: the mouse joint's spring
on softGrab
   put 1.5 into sHertz
end softGrab

on firmGrab
   put 8 into sHertz
end firmGrab

-- The Weaker and Stronger buttons: the force a link breaks at
on weaker
   put max(40, sLimit - 40) into sLimit
end weaker

on stronger
   put sLimit + 80 into sLimit
end stronger

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "softGrab"
         return sHertz is 1.5
      case "firmGrab"
         return sHertz is 8
   end switch
   return false
end labLit
@*/

/*@ Dragging/about
A mouse joint pulls a body toward a point, like a spring with a force it cannot pass. Moving that point with the mouse each step drags the body, and it still bumps into everything.
Every joint reports the force it holds with. Drag the purple weight down hard: when a link holds more than its limit, the script destroys that joint, and the chain breaks. Press Reset to mend it.
@*/

/*@ Contacts/card
-- 11 Contacts, Sensors and Filters
-- After each step, Box2D keeps lists of what happened in it:
--    contact events  which bodies began (and stopped) touching
--    hit events      a touch faster than the world's hit speed, and how fast
--    sensor events   which shapes came into (and left) a sensor
-- A sensor is a shape that notices what passes through it but stops
-- nothing. Filters say which shapes may collide: a shape belongs to
-- categories (bits) and collides with the categories in its mask.

local sWorld, sSensor, sBegins, sEnds, sInside, sHit

-- The categories: 1 the walls (Box2D's own), 2 red, 4 blue, 8 the shelf
constant kRed = 2
constant kBlue = 4
constant kShelf = 8

on labBuild
   local tShelf
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- The shelf collides with red balls only: its mask is kRed
   put b2NewBody(sWorld, 0, -2, 5, -0.15, false, false) into tShelf
   b2ShapeDefFilter kShelf, kRed, 0
   get b2AddBox(tShelf, 1.6, 0.1, 1, 0.3, 0)
   labShow tShelf, "rose"
   -- The sensor: a box that stops nothing. The b2ShapeDef... calls set
   -- up the NEXT shape made, and only it
   put b2NewBody(sWorld, 0, 1.2, 2.2, 0, false, false) into sSensor
   b2ShapeDefSensor true
   b2ShapeDefEnableSensorEvents true
   get b2AddBox(sSensor, 1.6, 0.7, 1, 0.5, 0)
   labShow sSensor, "teal"
   -- A hit event for any touch faster than 2 metres a second
   b2SetHitEventThreshold sWorld, 2
   put 0 into sBegins
   put 0 into sEnds
   put 0 into sInside
   put 0 into sHit
   dropRed
   dropBlue
   labStart sWorld
end labBuild

-- A ball, set up to make hit and sensor events, in a category and with a
-- mask
private command dropBall pX, pCategory, pMask, pColor
   local tBody
   put b2NewBody(sWorld, 2, pX, 8.2, 0, false, false) into tBody
   b2ShapeDefFilter pCategory, pMask, 0
   b2ShapeDefEnableHitEvents true
   b2ShapeDefEnableSensorEvents true
   get b2AddCircle(tBody, 0, 0, 0.25, 1, 0.4, 0.4)
   labShow tBody, pColor
end dropBall

-- The Drop red button: red collides with the walls, red, blue and the
-- shelf (1 + 2 + 4 + 8)
on dropRed
   dropBall -2.6 + random(20) / 10, kRed, 1 + kRed + kBlue + kShelf, "rose"
end dropRed

-- The Drop blue button: blue's mask leaves out the shelf, so it falls
-- through it
on dropBlue
   dropBall -2.6 + random(20) / 10, kBlue, 1 + kRed + kBlue, "sky"
end dropBlue

-- The Drop five button
on dropFive
   dropRed
   dropBlue
   dropRed
   dropBlue
   dropRed
end dropFive

on labStep
   local tIndex
   -- Contacts: each body that began touching another flashes
   get b2ContactsUpdate(sWorld)
   repeat with tIndex = 1 to b2ContactBeginCount()
      labFlash b2ContactBeginBodyA(tIndex)
      labFlash b2ContactBeginBodyB(tIndex)
   end repeat
   add b2ContactBeginCount() to sBegins
   add b2ContactEndCount() to sEnds
   -- Hits: the speed of the last one
   repeat with tIndex = 1 to b2ContactHitCount()
      put b2ContactHitSpeed(tIndex) into sHit
   end repeat
   -- The sensor: how many are in it now, and green while any are
   get b2SensorsUpdate(sWorld)
   add b2SensorBeginCount() - b2SensorEndCount() to sInside
   if sInside > 0 then
      labTint sSensor, "lime"
   else
      labTint sSensor, "teal"
   end if
   labSay "touches began:" && sBegins && " ended:" && sEnds && "   last hit" && labNum(sHit, 1) && "m/s" & \
         "   in the sensor:" && sInside
end labStep
@*/

/*@ Contacts/about
After each step, Box2D lists the bodies that began or stopped touching. Each body here flashes white when it begins a touch. A hit event comes with the speed of the hit.
The green box is a sensor: it counts what passes through and stops nothing. Filters let red balls land on the red shelf, while blue ones fall through it.
@*/

/*@ Rays/card
-- 12 Ray Casts and Queries
-- You can ask the world questions:
--    b2CastRayClosest  what does a line from here to there hit first?
--    b2RayCastAll      everything along the line, nearest first
--    b2BodyAtPoint     which body is at this point? (how a click picks)
--    b2OverlapCircle   which shapes are in this circle?
-- The answers are read with b2Ray... and b2Query... after the question.

local sWorld, sAll, sSweep, sAngle, sFound

on labBuild
   local tBody, tIndex
   put b2NewWorld(0, -10, true, true) into sWorld
   get labWalls(sWorld)
   -- Things for the ray to hit: two static, and a heap of dynamic
   put b2NewBody(sWorld, 0, 1.5, 4.5, 0.4, false, false) into tBody
   get b2AddBox(tBody, 0.9, 0.15, 1, 0.5, 0)
   labShow tBody, "slate"
   put b2NewBody(sWorld, 0, -1, 6.5, 0, false, false) into tBody
   get b2AddCircle(tBody, 0, 0, 0.5, 1, 0.5, 0)
   labShow tBody, "slate"
   repeat with tIndex = 1 to 8
      addShape
   end repeat
   put false into sAll
   put true into sSweep
   put 0 into sAngle
   put 0 into sFound
   labStart sWorld
end labBuild

-- The Add shapes button
on addShape
   local tBody
   put b2NewBody(sWorld, 2, random(70) / 10 - 3, 6 + random(20) / 10, 0, false, false) into tBody
   if random(2) is 1 then
      get b2AddBox(tBody, 0.3, 0.3, 1, 0.5, 0.1)
      labShow tBody, "amber"
   else
      get b2AddCircle(tBody, 0, 0, 0.3, 1, 0.5, 0.1)
      labShow tBody, "violet"
   end if
end addShape

-- The Closest / All button
on switchRay
   put not sAll into sAll
end switchRay

-- The Follow mouse button: the ray points at the mouse, or sweeps
on switchAim
   put not sSweep into sSweep
end switchAim

-- A click on empty space: which shapes are within a metre of it?
on mouseDown pButton
   local tX, tY, tIndex
   put labMouseX() into tX
   put labMouseY() into tY
   if pButton is 1 and b2BodyAtPoint(sWorld, tX, tY) is 0 and the mouseLoc is within the rect of graphic "Court" then
      get b2OverlapCircle(sWorld, tX, tY, 1)
      put b2QueryCount() into sFound
      repeat with tIndex = 1 to sFound
         labFlash b2QueryBody(tIndex)
      end repeat
   end if
   pass mouseDown
end mouseDown

-- Each step: a ray from the bottom left corner, 15 metres long
on labStep
   local tX1, tY1, tX2, tY2, tAngle, tIndex, tCount
   put -3.9 into tX1
   put 0.2 into tY1
   if sSweep then
      add 0.01 to sAngle
      put pi / 4 + sin(sAngle) * pi / 4.2 into tAngle
   else
      put atan2(labMouseY() - tY1, labMouseX() - tX1) into tAngle
   end if
   put tX1 + 15 * cos(tAngle) into tX2
   put tY1 + 15 * sin(tAngle) into tY2
   if not sAll then
      repeat with tIndex = 2 to 12
         labDot "hit" & tIndex, 0, 0, empty
      end repeat
      if b2CastRayClosest(sWorld, tX1, tY1, tX2, tY2) then
         -- The hit point, and the surface's normal there (which way it faces)
         labLine "ray", tX1, tY1, b2RayX(), b2RayY(), "rose"
         labLine "normal", b2RayX(), b2RayY(), b2RayX() + b2RayNormalX() * 0.6, b2RayY() + b2RayNormalY() * 0.6, "lime"
         labDot "hit1", b2RayX(), b2RayY(), "white", 10
         labSay "hit at" && labNum(b2RayX(), 2) & "," && labNum(b2RayY(), 2) && "  " & \
               round(b2RayFraction() * 100) & "% along the ray   normal" && labNum(b2RayNormalX(), 2) & "," && \
               labNum(b2RayNormalY(), 2) & "   a click found" && sFound && "shapes"
      else
         labLine "ray", tX1, tY1, tX2, tY2, "rose"
         labLine "normal", 0, 0, 0, 0, empty
         labDot "hit1", 0, 0, empty
      end if
   else
      -- Every hit: a dot at each
      labLine "normal", 0, 0, 0, 0, empty
      labLine "ray", tX1, tY1, tX2, tY2, "rose"
      get b2RayCastAll(sWorld, tX1, tY1, tX2, tY2)
      put min(12, b2QueryCount()) into tCount
      repeat with tIndex = 1 to 12
         if tIndex <= tCount then
            labDot "hit" & tIndex, b2QueryX(tIndex), b2QueryY(tIndex), "white", 10
         else
            labDot "hit" & tIndex, 0, 0, empty
         end if
      end repeat
      labSay "the ray goes through" && b2QueryCount() && "shapes   a click found" && sFound && "shapes"
   end if
end labStep

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "switchRay"
         return sAll
      case "switchAim"
         return not sSweep
   end switch
   return false
end labLit
@*/

/*@ Rays/about
A ray cast asks what a line through the world hits. b2CastRayClosest gives the first hit: its point, how far along the ray it is, and its normal, the way the surface faces (the green line). b2RayCastAll gives every hit.
Click empty space to ask which shapes are within a metre of the click: they flash. Follow mouse aims the ray at the mouse.
@*/

/*@ Terrain/card
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

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "toggleSleep"
         return b2IsSleepingEnabled(sWorld)
   end switch
   return false
end labLit
@*/

/*@ Terrain/about
The hills are a chain, many segments in one shape, so balls roll over the joins smoothly. A chain is one-sided: it holds things up from above, and lets them through from below.
Click empty space for a blast: b2WorldExplode pushes nearby bodies away. Bodies that rest fall asleep and turn grey. They cost nothing until something wakes them.
@*/

/*@ docs
b2Version|b2Version()|The binding's version, 4. If calling it fails, Box2Dxt is not loaded.
b2NewWorld|b2NewWorld(gx, gy, allowSleep, continuous)|Makes a world with a gravity in m/s/s (y is up). Returns its handle.
b2DestroyWorld|b2DestroyWorld world|Destroys a world, with every body, shape and joint in it.
b2Step|b2Step world, seconds, subSteps|Moves the world on in time. Use the same step every time: 1/60 of a second, 4 sub-steps.
b2SetGravity|b2SetGravity world, gx, gy|Changes the world's gravity. Sleeping bodies notice it when woken.
b2WorldGravityX|b2WorldGravityX(world)|The world's gravity across, in m/s/s. b2WorldGravityY is up and down.
b2WorldGravityY|b2WorldGravityY(world)|The world's gravity up and down, in m/s/s: minus is down.
b2AwakeBodyCount|b2AwakeBodyCount(world)|How many bodies are awake, and being moved, now.
b2EnableSleeping|b2EnableSleeping world, flag|Lets bodies at rest fall asleep (true), or never (false).
b2IsSleepingEnabled|b2IsSleepingEnabled(world)|True when bodies at rest may fall asleep.
b2SetHitEventThreshold|b2SetHitEventThreshold world, speed|A touch faster than this many m/s makes a hit event.
b2WorldExplode|b2WorldExplode world, x, y, radius, falloff, impulse|Pushes every body near x,y away from it; less at the edge.
b2WorldCountersUpdate|b2WorldCountersUpdate world|Counts the world's bodies, shapes, contacts and joints, for b2WorldBodyCount and the rest.
b2WorldBodyCount|b2WorldBodyCount()|How many bodies b2WorldCountersUpdate counted.
b2WorldContactCount|b2WorldContactCount()|How many contacts (touching pairs) b2WorldCountersUpdate counted.
b2WorldProfileUpdate|b2WorldProfileUpdate world|Times the last step, for b2WorldProfileStep and the rest.
b2WorldProfileStep|b2WorldProfileStep()|How long the last step took, in milliseconds.
b2NewBody|b2NewBody(world, type, x, y, angle, bullet, fixedRotation)|Makes a body at x,y (metres), turned by angle (radians). Type: 0 static, 1 kinematic, 2 dynamic.
b2DestroyBody|b2DestroyBody body|Takes a body out of the world, with its shapes and joints.
b2BodyX|b2BodyX(body)|Where the body is across, in metres. b2BodyY is up.
b2BodyY|b2BodyY(body)|How high the body is, in metres.
b2BodyAngle|b2BodyAngle(body)|Which way the body is turned, in radians: times 180 / pi for degrees.
b2BodyType|b2BodyType(body)|0 static, 1 kinematic, 2 dynamic.
b2SetBodyType|b2SetBodyType body, type|Makes a body static (0), kinematic (1) or dynamic (2).
b2BodyMass|b2BodyMass(body)|The body's mass in kilograms, from its shapes' areas and densities.
b2BodyIsAwake|b2BodyIsAwake(body)|False while the body sleeps: it has stopped, and Box2D leaves it be.
b2SetAwake|b2SetAwake body, flag|Wakes a body (true), or puts it to sleep (false).
b2SetTransform|b2SetTransform body, x, y, angle|Moves a body to a place and angle at once: a teleport, not a motion.
b2SetVelocity|b2SetVelocity body, vx, vy|Sets a body's speed in m/s, whatever it weighs.
b2BodyVX|b2BodyVX(body)|The body's speed across, in m/s. b2BodyVY is up.
b2BodyVY|b2BodyVY(body)|The body's speed up (minus is down), in m/s.
b2SetAngularVelocity|b2SetAngularVelocity body, radiansPerSecond|Sets how fast a body turns. Plus is anticlockwise.
b2BodyAngularVelocity|b2BodyAngularVelocity(body)|How fast the body turns, in radians a second.
b2SetGravityScale|b2SetGravityScale body, scale|How much gravity pulls this body: 1 as usual, 0 not at all, minus the other way.
b2SetLinearDamping|b2SetLinearDamping body, damping|Slows a body as air does: 0 none, 1 or more a lot.
b2ApplyForce|b2ApplyForce body, fx, fy, wake|A push in newtons for one step. Give it every step to keep pushing.
b2ApplyImpulse|b2ApplyImpulse body, ix, iy, wake|A kick, at once: the speed changes by impulse / mass.
b2ApplyImpulseAt|b2ApplyImpulseAt body, ix, iy, x, y, wake|A kick at a point in the world. Off the middle, it turns the body too.
b2ApplyAngularImpulse|b2ApplyAngularImpulse body, impulse, wake|A twist, at once. Plus is anticlockwise.
b2BodyAtPoint|b2BodyAtPoint(world, x, y)|The body at a point, or 0: how a click picks a body.
b2BodyWorldPointX|b2BodyWorldPointX(body, localX, localY)|A point given around the body, as x in the world. b2BodyWorldPointY is its y.
b2BodyWorldPointY|b2BodyWorldPointY(body, localX, localY)|A point given around the body, as y in the world.
b2BodyShapeCount|b2BodyShapeCount(body)|How many shapes the body has. Then b2BodyShapeAt(1) and on give them.
b2BodyShapeAt|b2BodyShapeAt(index)|The body's shape number index (from 1), after b2BodyShapeCount.
b2AddSegment|b2AddSegment(body, x1, y1, x2, y2, friction, bounce)|A line from x1,y1 to x2,y2 (around the body). Best on static bodies.
b2AddCircle|b2AddCircle(body, x, y, radius, density, friction, bounce)|A circle, its middle at x,y around the body.
b2AddBox|b2AddBox(body, halfWidth, halfHeight, density, friction, bounce)|A box around the body's middle. Give half its width and half its height.
b2AddCapsule|b2AddCapsule(body, x1, y1, x2, y2, radius, density, friction, bounce)|A line between two points, made round and fat by a radius.
b2PolyBegin|b2PolyBegin|Starts a list of points for a polygon (or a cast).
b2PolyAddPoint|b2PolyAddPoint x, y|Adds a point to the list b2PolyBegin started, around the body.
b2AddPolygon|b2AddPolygon(body, density, friction, bounce)|A convex polygon of the points listed, 3 to 8 of them.
b2ShapeType|b2ShapeType(shape)|0 circle, 1 capsule, 2 segment, 3 polygon, 4 a chain's segment.
b2ShapeCircleUpdate|b2ShapeCircleUpdate shape|Reads a circle, for b2ShapeCircleX, b2ShapeCircleY and b2ShapeCircleRadius.
b2ShapeCircleX|b2ShapeCircleX()|The circle's middle, across, around its body.
b2ShapeCircleY|b2ShapeCircleY()|The circle's middle, up, around its body.
b2ShapeCircleRadius|b2ShapeCircleRadius()|The circle's radius, in metres.
b2ShapeCapsuleUpdate|b2ShapeCapsuleUpdate shape|Reads a capsule, for b2ShapeCapsuleX1 and the rest.
b2ShapeCapsuleX1|b2ShapeCapsuleX1()|A capsule's first point, across. X2, Y1 and Y2 are its other numbers.
b2ShapeCapsuleY1|b2ShapeCapsuleY1()|A capsule's first point, up.
b2ShapeCapsuleX2|b2ShapeCapsuleX2()|A capsule's second point, across.
b2ShapeCapsuleY2|b2ShapeCapsuleY2()|A capsule's second point, up.
b2ShapeCapsuleRadius|b2ShapeCapsuleRadius()|A capsule's radius.
b2ShapeSegmentUpdate|b2ShapeSegmentUpdate shape|Reads a segment, for b2ShapeSegmentX1 and the rest.
b2ShapeSegmentX1|b2ShapeSegmentX1()|A segment's first end, across.
b2ShapeSegmentY1|b2ShapeSegmentY1()|A segment's first end, up.
b2ShapeSegmentX2|b2ShapeSegmentX2()|A segment's other end, across.
b2ShapeSegmentY2|b2ShapeSegmentY2()|A segment's other end, up.
b2ShapePolygonUpdate|b2ShapePolygonUpdate(shape)|Reads a polygon. Returns how many points it has.
b2ShapePolygonVertexX|b2ShapePolygonVertexX(index)|A polygon's point number index, across.
b2ShapePolygonVertexY|b2ShapePolygonVertexY(index)|A polygon's point number index, up.
b2ShapeDefSensor|b2ShapeDefSensor flag|Makes the NEXT shape a sensor: it notices what passes and stops nothing.
b2ShapeDefFilter|b2ShapeDefFilter category, mask, group|The next shape's filter: its category bits, and the categories it collides with.
b2ShapeDefEnableSensorEvents|b2ShapeDefEnableSensorEvents flag|The next shape makes sensor events. A sensor and what visits it both need it.
b2ShapeDefEnableHitEvents|b2ShapeDefEnableHitEvents flag|The next shape makes hit events.
b2ChainBegin|b2ChainBegin|Starts a list of points for a chain.
b2ChainAddPoint|b2ChainAddPoint x, y|Adds a point to the chain's list. The first and last are ghosts.
b2CreateChain|b2CreateChain(body, loop, friction, bounce)|A chain of segments through the points listed: smooth, one-sided ground.
b2RevoluteJoint|b2RevoluteJoint(world, bodyA, bodyB, ax, ay, bx, by, collide)|A hinge. ax,ay is the pin around body A, bx,by the same pin around body B.
b2RevoluteEnableMotor|b2RevoluteEnableMotor joint, flag, speed, maxTorque|Turns the hinge at a speed (radians a second), with up to maxTorque.
b2RevoluteSetMotorSpeed|b2RevoluteSetMotorSpeed joint, speed|The motor's speed, in radians a second.
b2RevoluteIsMotorEnabled|b2RevoluteIsMotorEnabled(joint)|True when the hinge's motor is on.
b2RevoluteMotorSpeed|b2RevoluteMotorSpeed(joint)|The speed the motor is set to.
b2RevoluteMotorTorque|b2RevoluteMotorTorque(joint)|The torque the motor used in the last step, in N m.
b2RevoluteEnableLimit|b2RevoluteEnableLimit joint, flag, lower, upper|Two angles (radians) the hinge may not turn beyond.
b2RevoluteAngle|b2RevoluteAngle(joint)|How far the hinge has turned from where it started, in radians.
b2DistanceJoint|b2DistanceJoint(world, bodyA, bodyB, ax, ay, bx, by, length, collide)|Keeps a point on each body a length apart: a rod.
b2DistanceEnableSpring|b2DistanceEnableSpring joint, flag, hertz, damping|Makes the rod a spring: hertz is how fast it bounces, damping how soon it stops.
b2DistanceSetLengthRange|b2DistanceSetLengthRange joint, min, max|The shortest and longest it may be: with a range, a rope.
b2DistanceCurrentLength|b2DistanceCurrentLength(joint)|How far apart its two points are now.
b2WeldJoint|b2WeldJoint(world, bodyA, bodyB, ax, ay, bx, by, angle, collide)|Glues two bodies at a point, so that they move as one.
b2WeldSetStiffness|b2WeldSetStiffness joint, linHertz, linDamping, angHertz, angDamping|Lets a weld give: 0 hertz is rigid, more is a spring.
b2PrismaticJoint|b2PrismaticJoint(world, bodyA, bodyB, ax, ay, bx, by, axisX, axisY, angle, collide)|Lets body B slide along an axis on body A, and not turn.
b2PrismaticEnableLimit|b2PrismaticEnableLimit joint, flag, lower, upper|How far it may slide each way, in metres.
b2PrismaticEnableMotor|b2PrismaticEnableMotor joint, flag, speed, maxForce|Slides it at a speed (m/s), with up to maxForce newtons.
b2PrismaticSetMotorSpeed|b2PrismaticSetMotorSpeed joint, speed|The slider's motor speed, in m/s. At 0 it holds still.
b2PrismaticEnableSpring|b2PrismaticEnableSpring joint, flag|Puts a spring on the slider that pulls it back to where it started.
b2PrismaticSetSpringHertz|b2PrismaticSetSpringHertz joint, hertz|How stiff the slider's spring is.
b2PrismaticSetSpringDamping|b2PrismaticSetSpringDamping joint, damping|How soon the slider's spring stops bouncing.
b2PrismaticTranslation|b2PrismaticTranslation(joint)|How far it has slid, in metres.
b2PrismaticSpeed|b2PrismaticSpeed(joint)|How fast it is sliding, in m/s.
b2PrismaticMotorForce|b2PrismaticMotorForce(joint)|The force the motor used in the last step, in newtons.
b2WheelJoint|b2WheelJoint(world, bodyA, bodyB, ax, ay, bx, by, axisX, axisY, collide)|A wheel on a car: it spins freely, and rides on a spring along the axis.
b2WheelEnableSpring|b2WheelEnableSpring joint, flag, hertz, damping|The suspension: how stiff, and how soon it settles.
b2WheelEnableMotor|b2WheelEnableMotor joint, flag, speed, maxTorque|Drives the wheel at a speed (radians a second). At 0, a brake.
b2WheelMotorTorque|b2WheelMotorTorque(joint)|The torque the wheel's motor used in the last step.
b2MouseJoint|b2MouseJoint(world, bodyA, bodyB, tx, ty, hertz, damping, maxForce)|Pulls body B to a target like a spring. Body A is any static body.
b2MouseSetTarget|b2MouseSetTarget joint, x, y|Moves the mouse joint's target: each step, to the mouse.
b2DestroyJoint|b2DestroyJoint joint|Takes a joint away: the bodies are free of each other.
b2JointWakeBodies|b2JointWakeBodies joint|Wakes both bodies of a joint, after you change its motor or spring.
b2JointBodyA|b2JointBodyA(joint)|A joint's first body. 0 once the joint is destroyed.
b2JointBodyB|b2JointBodyB(joint)|A joint's second body.
b2JointLocalAnchorAX|b2JointLocalAnchorAX(joint)|Where the joint holds body A, across, around body A.
b2JointLocalAnchorAY|b2JointLocalAnchorAY(joint)|Where the joint holds body A, up, around body A.
b2JointLocalAnchorBX|b2JointLocalAnchorBX(joint)|Where the joint holds body B, across, around body B.
b2JointLocalAnchorBY|b2JointLocalAnchorBY(joint)|Where the joint holds body B, up, around body B.
b2JointConstraintForceX|b2JointConstraintForceX(joint)|The force across, in newtons, the joint held with in the last step.
b2JointConstraintForceY|b2JointConstraintForceY(joint)|The force up and down the joint held with in the last step.
b2ContactsUpdate|b2ContactsUpdate(world)|Reads the last step's contact and hit events. Call it once after each step.
b2ContactBeginCount|b2ContactBeginCount()|How many pairs of bodies began touching.
b2ContactBeginBodyA|b2ContactBeginBodyA(index)|One body of a pair that began touching (from 1).
b2ContactBeginBodyB|b2ContactBeginBodyB(index)|The other body of that pair.
b2ContactEndCount|b2ContactEndCount()|How many pairs stopped touching.
b2ContactHitCount|b2ContactHitCount()|How many hits: touches faster than the hit speed.
b2ContactHitSpeed|b2ContactHitSpeed(index)|How fast a hit was, in m/s.
b2SensorsUpdate|b2SensorsUpdate(world)|Reads the last step's sensor events. Returns how many began.
b2SensorBeginCount|b2SensorBeginCount()|How many shapes came into a sensor.
b2SensorEndCount|b2SensorEndCount()|How many shapes left a sensor.
b2CastRayClosest|b2CastRayClosest(world, x1, y1, x2, y2)|True if the line hits a shape. b2RayX and the rest say where.
b2RayX|b2RayX()|Where the ray hit, across.
b2RayY|b2RayY()|Where the ray hit, up.
b2RayNormalX|b2RayNormalX()|The way the surface faces where it was hit, across (a length of 1).
b2RayNormalY|b2RayNormalY()|The way the surface faces, up.
b2RayFraction|b2RayFraction()|How far along the ray the hit is: 0 at its start, 1 at its end.
b2RayCastAll|b2RayCastAll(world, x1, y1, x2, y2)|Every shape the line hits, nearest first. Returns how many.
b2OverlapCircle|b2OverlapCircle(world, x, y, radius)|The shapes in a circle. Returns how many.
b2QueryCount|b2QueryCount()|How many the last query found.
b2QueryBody|b2QueryBody(index)|The body of what the last query found, from 1.
b2QueryX|b2QueryX(index)|Where a ray hit, across, for a b2RayCastAll query.
b2QueryY|b2QueryY(index)|Where a ray hit, up.
@*/
