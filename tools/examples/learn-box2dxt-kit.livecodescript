script "OXTExampleLearnBox2DxtKit"
-- OXT-Beyond: builds "Learn the Box2Dxt Kit", lessons in making games
-- with physics through the Box2Dxt Kit, the library of b2k... handlers
-- that OXT-Beyond has built in beside Box2Dxt (the xTalk Suite's
-- box2dxt/, https://github.com/SethMorrowSoftware/xtalk-suite). The Kit
-- works in pixels, screen coordinates and degrees, and moves the
-- controls of a card: where "Learn Box2D" teaches Box2D's own handlers,
-- this teaches the Kit's, as a game of yours would call them.
--
-- Each lesson is a wide card, as in Learn Box2D: a court where the
-- lesson runs live, its buttons above it, and beside it a column with
-- three tabs: Explain (what the lesson shows, in plain words), Code (a
-- few lines to try, which the reader can change and run) and Calls (the
-- Kit handlers the card's script calls, each of which a click explains
-- in full: what it does, its parameters and their units, and what it
-- returns). What every lesson shares (making the Kit's world in the
-- court, Reset, Pause and Step, dragging, the tabs) is the script of the
-- group "Lab", a background on the lessons.
--
-- The pictures are Kenney's (https://kenney.nl), CC0, from the sheets in
-- the xTalk Suite's box2dxt/Spritesheets, copied to
-- tools/examples/assets/kenney.
--
-- build-examples.livecodescript runs exBuild with the builder in use.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- The court (410 by 440 pixels), and the column beside it
constant kCourt = "270,162,680,602"
constant kInfo = "694,162,986,602"
-- The front banner's toy, at its right
constant kToy = "770,114,988,264"

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath, tIndex
   exUseScripts the script of me
   exAddIcon "pause", "<rect x='14' y='4' width='4' height='16' rx='1'/><rect x='6' y='4' width='4' height='16' rx='1'/>"
   exAddIcon "step-forward", "<line x1='6' x2='6' y1='4' y2='20'/><polygon points='10,4 20,12 10,20'/>"
   exAddIcon "hand", "<path d='M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2'/><path d='M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2'/>" & \
         "<path d='M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8'/>" & \
         "<path d='M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15'/>"
   exAddIcon "play", "<polygon points='6 3 20 12 6 21 6 3'/>"
   exAddIcon "copy", "<rect width='14' height='14' x='8' y='8' rx='2' ry='2'/><path d='M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2'/>"
   exAddIcon "loader-circle", "<path d='M21 12a9 9 0 1 1-6.219-8.56'/>"
   exAddIcon "link", "<path d='M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71'/>" & \
         "<path d='M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71'/>"
   exAddIcon "gamepad-2", "<line x1='6' x2='10' y1='11' y2='11'/><line x1='8' x2='8' y1='9' y2='13'/>" & \
         "<line x1='15' x2='15.01' y1='12' y2='12'/><line x1='18' x2='18.01' y1='10' y2='10'/>" & \
         "<path d='M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z'/>"
   put "Learn Box2Dxt Kit" into tInfo["name"]
   put "Games with physics, in pixels" into tInfo["credit"]
   put "gamepad-2" into tInfo["icon"]
   put lkColor("violet") into tInfo["accent"]
   put lkColor("pink") into tInfo["accent2"]
   put "Lesson" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Learn Box2Dxt Kit|Make games with physics, one idea at a time.|gamepad-2|front" & return & \
         "Quick|Quick Start|Balls, boxes and pills that fall, in a few lines of script.|sparkles|wide" & return & \
         "Controls|Your Controls|Give your own buttons, fields and graphics a body.|blocks|wide" & return & \
         "Moves|Pushes and Spins|Push, kick, spin and blast: the ways to make things move.|zap|wide" & return & \
         "Joints|Joints|Hinges, ropes, sliders and wheels, and motors to drive them.|link|wide" & return & \
         "Keys|Keyboard|Move a hero with the arrow keys, and jump.|keyboard|wide keys" & return & \
         "Sprites|Sprite Sheets|Many pictures in one image: cut them out, name them, show them.|image|wide" & return & \
         "Anim|Animation & GIFs|Pictures that move by themselves: animations, GIFs, and sheets from files.|film|wide" & return & \
         "Player|A Player|A character that runs, jumps, climbs and swims, with the arrow keys.|footprints|wide keys" & return & \
         "Camera|A Camera|A level wider than the window: the view follows the player.|eye|wide keys" & return & \
         "Sound|Sound|Beeps and tunes made by the script, and a sound when things hit.|volume-2|wide" & return & \
         "Contacts|Contacts & Sensors|Who touched what, coins that notice, and layers that pass through.|trophy|wide" & return & \
         "Terrain|Terrain & Rays|Hills, a pit, and a laser that sees what it hits.|map|wide" & return & \
         "Reference|Reference|Every handler in the Kit: find one, and see how to call it.|search|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildArt
   buildFront
   repeat with tIndex = 2 to the number of lines of tInfo["cards"]
      if exCardInfo(tIndex, "layout") is "wide" then
         buildLesson exCardInfo(tIndex, "name")
      end if
   end repeat
   buildReference
   go card 1
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Learn Box2Dxt Kit.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

################################################################################
#
# The pictures
#

-- The Kenney sheets the lessons use, as images in the stack, hidden, on
-- the card that shows them: a lesson's script finds them by name
private command buildArt
   local tFolder
   set the itemDelimiter to slash
   put item 1 to -2 of the filename of stack "OXTExampleLearnBox2DxtKit" & "/assets/kenney" into tFolder
   set the itemDelimiter to comma
   art "Sprites", "AlienArt", tFolder & "/alienGreen.png"
   art "Sprites", "TileArt", tFolder & "/spritesheet-tiles-default.png"
   art "Anim", "AlienArt", tFolder & "/alienGreen.png"
   art "Anim", "WalkGif", tFolder & "/alien-walk.gif"
   art "Player", "AlienArt", tFolder & "/alienGreen.png"
   art "Camera", "AlienArt", tFolder & "/alienGreen.png"
end buildArt

private command art pCard, pName, pFile
   local tData
   put URL ("binfile:" & pFile) into tData
   if tData is empty then
      throw "no picture at " & pFile
   end if
   go card pCard
   create image pName
   set the text of image pName to tData
   set the topLeft of image pName to kLeft, kBottom + 40
   hide image pName
end art

################################################################################
#
# The front page
#

private command buildFront
   local tIndex, tLeft, tWidth, tTips
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 272), lkColor("violet") & "|" & lkColor("pink"), \
         "OXT-BEYOND  " & numToCodepoint(183) & "  THE BOX2DXT KIT", \
         "Games with physics, one idea at a time", \
         "Each lesson is a little game to play with, what it shows in plain words, and the script that makes it. " & \
         "The Kit works in pixels and degrees, and moves the buttons and pictures on your cards."
   exProgramTiles 288, 5, 60, 10
   -- (the tiles say each lesson's short name: the long ones would not fit)
   repeat with tIndex = 1 to the number of lines of exScript("short")
      put line tIndex of exScript("short") into field ("tile" & tIndex & "_title")
      if the formattedWidth of field ("tile" & tIndex & "_title") > the width of field ("tile" & tIndex & "_title") then
         throw "the tile of " & line tIndex of exScript("short") & " is too narrow for its name"
      end if
   end repeat
   put "mouse-pointer-click|Press the buttons above a game to try what the lesson shows." & return & \
         "book-open|Explain tells you what you see. Calls has every detail." & return & \
         "code|Code has lines to try: change a number, then press Run." & return & \
         "hand|Drag anything that moves. Reset starts the lesson again." into tTips
   put (kRight - kLeft - 3 * 12) div 4 into tWidth
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put kLeft + (tIndex - 1) * (tWidth + 12) into tLeft
      tip "Tip" & tIndex, tLeft, 500, tLeft + tWidth, kBottom, item 1 of line tIndex of tTips, item 2 of line tIndex of tTips
   end repeat
   set the itemDelimiter to comma
   -- The way to the other stack, beside the last row of tiles
   put exButton("OtherStack", 0, 442, 32, "Learn Box2D: the physics underneath", "book-open", "ghost", lkColor("violet"), empty, empty, 0) into tWidth
   set the right of group "OtherStack" to kRight
   set the toolTip of group "OtherStack" to "Open Learn Box2D, whose lessons show the Box2D calls the Kit makes for you"
   set the script of this card to exScript("Start/card")
end buildFront

private command tip pName, pLeft, pTop, pRight, pBottom, pIcon, pText
   local tObj
   get exPanel(pName, lkR(pLeft, pTop, pRight, pBottom), empty)
   get lkBox(pName & "_iconBg", lkR(pLeft + 16, pTop + 16, pLeft + 52, pTop + 52), lkMix("255,255,255", lkColor("violet"), 0.13), 12, empty)
   get exIcon(pName & "_icon", pIcon, lkColor("violet"), lkR(pLeft + 24, pTop + 24, pLeft + 44, pTop + 44), empty)
   put lkLabel(pName & "_text", lkR(pLeft + 16, pTop + 62, pRight - 14, pBottom - 8), pText, 12, lkColor("soft"), empty) into tObj
end tip

################################################################################
#
# A lesson
#

# The Reference card: every Kit handler, a search box, and what each
# does, with the lessons that call it
#

private command buildReference
   local tObj, tDocs, tNames, tName, tUsed, tIndex, tCard
   -- (which lessons call each handler: the same list as each lesson's
   -- Calls tab)
   repeat with tIndex = 2 to the number of lines of sInfoCards()
      if exCardInfo(tIndex, "layout") is not "wide" then
         next repeat
      end if
      put exCardInfo(tIndex, "name") into tCard
      repeat for each line tName in callsOf(exScript(tCard & "/card"))
         if tUsed[tName] is not empty then
            put ", " after tUsed[tName]
         end if
         put exCardInfo(tIndex, "title") after tUsed[tName]
      end repeat
   end repeat
   put docs() into tDocs
   put the keys of tDocs into tNames
   sort lines of tNames
   go card "Reference"
   get lkBox("RefPanel", lkR(kLeft, kTop, kRight, kBottom), "255,255,255", 14, empty)
   set the borderColor of it to lkColor("line")
   put lkLabel("RefIntro", lkR(kLeft + 20, kTop + 16, kRight - 20, kTop + 52), \
         "Type part of a name, or a word such as " & quote & "jump" & quote & " or " & quote & "sound" & quote & \
         ". Click a handler to see how to call it, what to give it, what it gives back, and which lessons use it.", \
         13, lkColor("soft"), empty) into tObj
   get lkBox("RefFindBg", lkR(kLeft + 20, kTop + 62, kLeft + 300, kTop + 92), lkColor("bg"), 8, empty)
   put lkLabel("RefFind", lkR(kLeft + 28, kTop + 66, kLeft + 292, kTop + 88), empty, 13, lkColor("ink"), empty) into tObj
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the margins of tObj to "4,2,4,2"
   set the dontWrap of tObj to true
   set the toolTip of tObj to "Type to find a handler"
   put lkLabel("RefCount", lkR(kLeft + 20, kTop + 96, kLeft + 300, kTop + 112), empty, 11, lkColor("muted"), empty) into tObj
   put lkLabel("RefList", lkR(kLeft + 20, kTop + 116, kLeft + 300, kBottom - 16), empty, 12, lkColor("ink"), empty) into tObj
   set the listBehavior of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 18
   set the hiliteColor of tObj to lkMix("255,255,255", lkColor("violet"), 0.18)
   get lkBox("RefDocBg", lkR(kLeft + 316, kTop + 62, kRight - 20, kBottom - 16), lkMix("255,255,255", lkColor("violet"), 0.06), 10, empty)
   put lkLabel("RefDoc", lkR(kLeft + 328, kTop + 70, kRight - 28, kBottom - 22), \
         "Click a handler on the left.", 13, lkColor("soft"), empty) into tObj
   set the cRef of this card to tDocs
   set the cNames of this card to tNames
   set the cUsedIn of this card to tUsed
   set the script of this card to exScript("Reference/card")
end buildReference

private function sInfoCards
   local tIndex, tLines
   repeat with tIndex = 1 to 100
      if exCardInfo(tIndex, "name") is empty then
         exit repeat
      end if
      put tIndex & return after tLines
   end repeat
   return tLines
end sInfoCards

private command buildLesson pCard
   local tScript
   go card pCard
   put exScript(pCard & "/card") into tScript
   set the script of this card to tScript
   if there is no group "Lab" of card 2 then
      buildLab
   else
      place group "Lab" of card 2 onto this card
   end if
   lessonButtons pCard
   lessonInfo pCard, tScript
end buildLesson

-- The Lab: the court, the line of words at its top, Reset, Pause and
-- Step, and the script every lesson shares. A background, on each lesson
private command buildLab
   local tObj, tRight, tWidth
   get lkGroup("Lab", lkR(kLeft + 14, kTop + 14, kRight - 14, kBottom - 14), empty)
   set the backgroundBehavior of group "Lab" to true
   get lkBox("labAnchor", lkR(kLeft + 14, kTop + 14, kLeft + 15, kTop + 15), empty, 0, "Lab")
   put lkBox("Court", kCourt, lkColor("side"), 14, "Lab") into tObj
   lkGradient tObj, "30,41,59|36,27,82|15,23,42", item 1 of kCourt & "," & item 2 of kCourt, item 1 of kCourt & "," & item 4 of kCourt
   put lkBox("ReadoutBg", lkR(item 1 of kCourt + 8, item 2 of kCourt + 44, item 1 of kCourt + 9, item 2 of kCourt + 45), \
         "15,23,42", 8, "Lab") into tObj
   set the blendLevel of tObj to 20
   hide tObj
   put lkLabel("Readout", lkR(item 1 of kCourt + 14, item 2 of kCourt + 46, item 3 of kCourt - 14, item 2 of kCourt + 62), \
         empty, 11, "203,213,225", "Lab") into tObj
   set the sharedText of tObj to false
   put item 3 of kCourt - 10 into tRight
   put exButton("LabStep", 0, item 2 of kCourt + 10, 26, "Step", "step-forward", "chip", lkColor("violet"), "Lab", empty, 0) into tWidth
   set the left of group "LabStep" to tRight - tWidth
   set the cDo of group "LabStep" to "labStepButton"
   set the toolTip of group "LabStep" to "Run the game for one frame (1/60 of a second), then stay paused"
   subtract tWidth + 6 from tRight
   put exButton("LabPause", 0, item 2 of kCourt + 10, 26, "Pause", "pause", "chip", lkColor("violet"), "Lab", empty, 74) into tWidth
   set the left of group "LabPause" to tRight - tWidth
   set the cDo of group "LabPause" to "labTogglePause"
   set the toolTip of group "LabPause" to "Freeze the game, or set it going again"
   set the sharedText of field "LabStep_label" to true
   set the sharedText of field "LabPause_label" to true
   subtract tWidth + 6 from tRight
   put exButton("LabReset", 0, item 2 of kCourt + 10, 26, "Reset", "undo-2", "chip", lkColor("violet"), "Lab", empty, 0) into tWidth
   set the left of group "LabReset" to tRight - tWidth
   set the cDo of group "LabReset" to "labRestart"
   set the toolTip of group "LabReset" to "Start the lesson again from the beginning"
   set the sharedText of field "LabReset_label" to true
   -- The sign that the lesson is being made: it shows in the court's
   -- middle from when the card opens until its world is ready
   put exButton("LabLoading", 0, item 2 of kCourt + 200, 40, "Getting the lesson ready...", "loader-circle", "dark", lkColor("violet"), "Lab", empty, 0) into tWidth
   set the left of group "LabLoading" to (item 1 of kCourt + item 3 of kCourt - tWidth) div 2
   set the sharedText of field "LabLoading_label" to true
   hide group "LabLoading"
   set the script of group "Lab" to exScript("Lab")
   set the cDocs of group "Lab" to docs()
end buildLab

-- The card's own buttons, from the block "buttons" (card|label|handler|
-- tip, and "switch" for one that switches something on and off), in a
-- row from the left, all alike. Each has a light, hidden: a wash of the
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
      put exButton(tName, tLeft, kTop + 14, 34, item 2 of tLine, empty, tStyle, lkColor("violet"), empty, empty, 0) into tWidth
      set the cDo of group tName to item 3 of tLine
      buttonLight tName, lkColor("violet")
      if item 5 of tLine is "switch" then
         set the cSwitch of group tName to true
         if "labLit" is not among the words of scriptFunctionNames(the script of this card) then
            set the itemDelimiter to comma
            throw "the switch " & item 2 of tLine & " of " & pCard & " needs a function labLit on its card"
         end if
      end if
      set the toolTip of group tName to item 4 of tLine
      if item 4 of tLine is empty then
         set the itemDelimiter to comma
         throw "the button " & item 2 of tLine & " of " & pCard & " has no tip"
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

private function handlerNames pScript
   local tLine, tNames
   repeat for each line tLine in pScript
      if word 1 of tLine is "on" or word 1 of tLine is "command" then
         put word 2 of tLine & space after tNames
      end if
   end repeat
   return tNames
end handlerNames

-- The column beside the court: three tabs, Explain, Code and Calls, and
-- a pane for each, in a group of its own that the Lab shows and hides
private command lessonInfo pCard, pScript
   local tObj, tLeft, tTop, tRight, tBottom, tCalls, tX, tTab, tPane, tRows, tCode
   put item 1 of kInfo into tLeft
   put item 2 of kInfo into tTop
   put item 3 of kInfo into tRight
   put item 4 of kInfo into tBottom
   get exPanel("Info", kInfo, empty)
   -- The tabs: words in a row, the one in front bold, with a bar under it
   put tLeft + 18 into tX
   repeat for each item tTab in "Explain,Code,Calls"
      put lkLabel("Tab" & tTab, lkR(tX, tTop + 14, tX + 80, tTop + 36), tTab, 14, lkColor("ink"), empty) into tObj
      set the dontWrap of tObj to true
      set the textStyle of tObj to "bold"
      set the width of tObj to the formattedWidth of tObj + 6
      set the left of tObj to tX
      set the cDo of tObj to "labTab" & tTab
      add the width of tObj + 18 to tX
   end repeat
   get lkBox("TabLine", lkR(tLeft + 14, tTop + 42, tRight - 14, tTop + 43), lkColor("line"), 0, empty)
   get lkBox("TabBar", lkR(tLeft + 18, tTop + 40, tLeft + 60, tTop + 43), lkColor("violet"), 2, empty)

   -- Explain: the lesson in plain words
   put lkGroup("PaneExplain", lkR(tLeft + 4, tTop + 50, tRight - 4, tBottom - 4), empty) into tPane
   put paneWords("Explain", tLeft + 18, tTop + 56, tRight - 16, tBottom - 12, exScript(pCard & "/explain"), "PaneExplain") into tObj

   -- Code: lines to try, which the reader may change, and Run and Copy
   put lkGroup("PaneCode", lkR(tLeft + 4, tTop + 50, tRight - 4, tBottom - 4), empty) into tPane
   put lkLabel("TryTitle", lkR(tLeft + 18, tTop + 56, tRight - 18, tTop + 90), \
         "Try this. Change a number, then press Run.", 12, lkColor("soft"), "PaneCode") into tObj
   put exScript(pCard & "/try") into tCode
   -- (on a dark box, as code is in an editor, in the colours of the
   -- scripts drawer: the Lab paints comments and the Kit's names)
   put lkBox("TryBg", lkR(tLeft + 12, tTop + 92, tRight - 12, tBottom - 58), "15,23,42", 10, "PaneCode") into tObj
   put lkCodeField("TryCode", lkR(tLeft + 18, tTop + 98, tRight - 16, tBottom - 64), 12, 17, "PaneCode") into tObj
   set the text of tObj to tCode
   set the cTry of tObj to tCode
   set the textColor of tObj to "226,232,240"
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the margins of tObj to "4,2,4,2"
   set the dontWrap of tObj to true
   set the sharedText of tObj to false
   put tLeft + 12 into tX
   add 8 + exButton("TryRun", tX, tBottom - 48, 32, "Run", "play", "primary", lkColor("violet"), "PaneCode", empty, 0) to tX
   set the cDo of group "TryRun" to "labRunCode"
   set the toolTip of group "TryRun" to "Run the lines above in this lesson's game"
   add 8 + exButton("TryCopy", tX, tBottom - 48, 32, "Copy", "copy", "ghost", lkColor("violet"), "PaneCode", empty, 0) to tX
   set the cDo of group "TryCopy" to "labCopyCode"
   set the toolTip of group "TryCopy" to "Copy the lines, to paste into a script of your own"
   add 8 + exButton("TryUndo", tX, tBottom - 48, 32, "Undo", empty, "ghost", lkColor("violet"), "PaneCode", empty, 0) to tX
   set the cDo of group "TryUndo" to "labResetCode"
   set the toolTip of group "TryUndo" to "Put back the lines as they were"
   if tX - 8 > tRight - 12 then
      throw "the Code tab buttons of " & pCard & " are too wide for the column: " & tX && tRight
   end if
   hide group "PaneCode"

   -- Calls: every Kit handler the card's script calls, and the one
   -- clicked, in full
   put lkGroup("PaneCalls", lkR(tLeft + 4, tTop + 50, tRight - 4, tBottom - 4), empty) into tPane
   put callsOf(pScript) into tCalls
   put lkLabel("CallsTitle", lkR(tLeft + 18, tTop + 54, tRight - 18, tTop + 70), \
         "THE KIT HANDLERS THIS CARD CALLS:" && the number of lines of tCalls, 11, lkColor("muted"), "PaneCalls") into tObj
   set the textStyle of tObj to "bold"
   put 8 into tRows
   put lkLabel("Calls", lkR(tLeft + 12, tTop + 74, tRight - 12, tTop + 74 + tRows * 17 + 10), tCalls, 12, lkColor("ink"), "PaneCalls") into tObj
   set the listBehavior of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to 17
   set the margins of tObj to "6,4,6,4"
   set the hiliteColor of tObj to lkMix("255,255,255", lkColor("violet"), 0.18)
   put tTop + 74 + tRows * 17 + 18 into tX
   get lkBox("CallDocBg", lkR(tLeft + 12, tX, tRight - 12, tBottom - 12), lkMix("255,255,255", lkColor("violet"), 0.07), 10, "PaneCalls")
   put lkLabel("CallDoc", lkR(tLeft + 20, tX + 6, tRight - 18, tBottom - 16), \
         "Click a handler above to see what it does, what to give it, and what it gives back. The wheel scrolls.", 11, lkColor("soft"), "PaneCalls") into tObj
   set the sharedText of tObj to false
   set the lockText of tObj to true
   hide group "PaneCalls"
end lessonInfo

-- Words, a paragraph a line, with room between them
private function paneWords pName, pLeft, pTop, pRight, pBottom, pText, pGroup
   local tObj, tIndex, tShown, tLine
   -- (headings start "# ", points "* ": what shows is without them, or
   -- with a bullet)
   repeat for each line tLine in pText
      if tLine begins with "# " then
         put char 3 to -1 of tLine & return after tShown
      else if tLine begins with "* " then
         put numToCodepoint(8226) & space & char 3 to -1 of tLine & return after tShown
      else
         put tLine & return after tShown
      end if
   end repeat
   delete the last char of tShown
   put lkLabel(pName, lkR(pLeft, pTop, pRight, pBottom), tShown, 13, lkColor("soft"), pGroup) into tObj
   repeat with tIndex = 1 to the number of lines of pText
      if line tIndex of pText begins with "* " then
         set the firstIndent of line tIndex of tObj to -12
         set the leftIndent of line tIndex of tObj to 12
         set the spaceBelow of line tIndex of tObj to 4
      else if line tIndex of pText begins with "# " then
         set the textStyle of line tIndex of tObj to "bold"
         set the textColor of line tIndex of tObj to lkColor("ink")
         set the spaceAbove of line tIndex of tObj to 2
         set the spaceBelow of line tIndex of tObj to 3
      else
         set the spaceBelow of line tIndex of tObj to 6
      end if
   end repeat
   if the formattedHeight of tObj > pBottom - pTop then
      throw "the words of " & pName & " are too long for the column (" & the formattedHeight of tObj & " of " & pBottom - pTop & ")"
   end if
   return tObj
end paneWords

-- The Kit handlers a script calls (not those its comments name), in the
-- order it first calls them; each must have a line in the docs
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
         if char 1 to 3 of tWord is "b2k" and char 4 of tWord is among the chars of "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
               and tWord is not among the lines of tCalls then
            if tWord is not among the keys of tDocs then
               throw tWord & " is not a Kit handler"
            end if
            if tWord is not among the lines of plainNames() then
               throw "no plain words in the block docs for " & tWord
            end if
            put tWord & return after tCalls
         end if
      end repeat
   end repeat
   delete the last char of tCalls
   return tCalls
end callsOf

-- Every Kit handler, by name: "usage|what it does|details", from the
-- block "ref" (made by learn-box2d-docs.py from the Kit's dictionary),
-- with the block "docs" saying what each one a lesson calls does in
-- plainer words
private function docs
   local tLine, tDocs, tPlain
   set the itemDelimiter to "|"
   repeat for each line tLine in exScript("ref")
      if tLine is not empty then
         put item 2 to -1 of tLine into tDocs[item 1 of tLine]
      end if
   end repeat
   repeat for each line tLine in exScript("docs")
      if tLine is empty then
         next repeat
      end if
      if item 1 of tLine is not among the keys of tDocs then
         set the itemDelimiter to comma
         throw "the docs name " & item 1 of tLine & ", which the Kit has not got"
      end if
      put item 2 of tLine into tPlain
      put tPlain into item 2 of tDocs[item 1 of tLine]
   end repeat
   set the itemDelimiter to comma
   return tDocs
end docs

-- The names the block "docs" has plain words for
private function plainNames
   local tLine, tNames
   set the itemDelimiter to "|"
   repeat for each line tLine in exScript("docs")
      if tLine is not empty then
         put item 1 of tLine & return after tNames
      end if
   end repeat
   set the itemDelimiter to comma
   return tNames
end plainNames

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
-- Learn the Box2Dxt Kit: lessons in making games with physics, written
-- for OXT-Beyond in 2026.
--
-- Each lesson's game is made by the script of its card, with the Kit's
-- b2k... handlers, in the court of the group "Lab", a background on
-- every lesson: open Scripts on a lesson to read both.
--
-- The Kit and Box2Dxt are the xTalk Suite's
-- (https://github.com/SethMorrowSoftware/xtalk-suite); Box2D is Erin
-- Catto's (https://box2d.org, MIT licence). The pictures are Kenney's
-- (https://kenney.nl), CC0.
@*/

/*@ short
Basics
Controls
Moves
Joints
Keyboard
Sprites
Animate
Player
Camera
Sound
Contacts
Terrain
Look up
@*/

/*@ buttons
Quick|Ball|addBall|Drop a ball of a random size and colour
Quick|Box|addBox|Drop a box of a random size and colour
Quick|Pill|addCapsule|Drop a capsule: a box with round ends
Quick|Rain|rain|Drop ten shapes of every kind at once
Quick|Clear|clearAll|Take away everything that moves (the walls stay)
Controls|Lift them|liftThem|Put the button, field, ball and triangle back at the top
Controls|Shelf moves|moveShelf|Make the shelf a kinematic body that slides, or static again|switch
Controls|Heavy ball|heavyBall|Make the ball ten times as dense, or light again|switch
Controls|Drop a box|dropBox|Drop a box onto the controls
Moves|Jump|jump|Push the ball up: 450 pixels a second more
Moves|Kick|kick|Kick every box with the same impulse
Moves|Spin|spin|Spin the ball at 900 degrees a second
Moves|Boom|boom|An explosion at the floor that blasts things away
Moves|Bouncy|bouncy|Make the ball bouncy, or not|switch
Moves|Moon|moon|Moon gravity (a sixth of the Earth's), or Earth again|switch
Joints|Faster|faster|Double the windmill motor's speed
Joints|Reverse|reverse|Turn the windmill the other way|switch
Joints|Lift|liftUp|Drive the lift up, or back down
Joints|Springy|springy|Make the rope stretch like a spring
Joints|Cut rope|cutRope|Remove the rope joint, and let the weight fall
Joints|Drive|drive|Turn the cart's wheel motors on: to the right, then back to the left
Keys|Higher jumps|higher|Jump higher, or normally again|switch
Keys|Ice|ice|No friction: the hero slides|switch
Keys|Drop boxes|dropBoxes|Drop four boxes to climb on
Sprites|Next picture|nextPicture|Show the alien's next picture from the sheet
Sprites|Walk|walk|Play the walk pictures one after the other, as an animation
Sprites|Flip|flipAlien|Turn the alien to face the other way|switch
Sprites|Drop a crate|dropCrate|Drop a crate: a picture from the tile sheet on a box that falls
Sprites|See the sheet|seeSheet|Show the whole sheet, with each named picture outlined|switch
Anim|Hop|hop|Play the hop animation once, and jump
Anim|Ouch|ouch|Play the ouch animation once
Anim|Faster|faster|Double the alien's frames a second, for every animation it plays (back to 3 after 24)
Anim|Stop / go|stopGo|Stop both animations on the frame they show, or go on|switch
Anim|From files|fromFiles|Write a PNG and an XML file, then load a sheet from them
Player|Double jump|doubleJump|Allow one more jump in the air, or not|switch
Player|Faster|runFaster|Run at 340 pixels a second, or 220 again|switch
Player|Ouch|hurtPlayer|Hit the player from the right
Player|Start again|startAgain|Put the player back where it started
Camera|Run by itself|autoRun|Hold the right arrow key down for you, or let go of it|switch
Camera|Shake|shake|Shake the view for half a second
Camera|Loose|looseCamera|Make the camera catch up slowly, or quickly again|switch
Camera|Dead zone|deadZone|Let the player move in a box in the middle before the camera moves, or not|switch
Camera|Back to start|backToStart|Put the player and the view back at the start
Sound|Coin|coin|Play the coin sound
Sound|Jump|jumpAll|Play the jump sound, and make every ball jump
Sound|Tune|tune|Play the tune over and over
Sound|Stop|stopSound|Stop the sound that is playing
Sound|Mute|muteSound|Turn every sound off, or on again|switch
Contacts|Drop balls|dropBalls|Drop four balls that land on the boxes and take coins
Contacts|Ghosts|ghosts|Drop four ghost balls that pass through the boxes
Contacts|Solid boxes|boxesSolid|Put the boxes on layer 1, so ghosts land on them; press again to undo|switch
Terrain|Drop balls|dropBalls|Drop five balls on the hills
Terrain|Drop boxes|dropBoxes|Drop three boxes on the hills
Terrain|Who is near?|whoIsNear|Make everything in a circle in the middle jump
Terrain|Laser|laser|Turn the laser off, or on again|switch
@*/

/*@ Lab
-- The Lab: what every lesson of Learn the Box2Dxt Kit shares. It is the
-- script of the group "Lab", a background on each lesson card, with the
-- court the game runs in, the line of words at its top, Reset, Pause and
-- Step, and the tabs beside the court. When a card opens, the Lab:
--
--    makes the Kit's world, with b2kSetup, and fits it to the court:
--    40 pixels to a metre, the floor at the court's bottom, and a wall
--    on each side, so that nothing leaves the court (labOpen)
--    calls the card's labBuild, which makes the lesson's game, and
--    starts the Kit's loop with b2kStart
--    calls the card's labStep each frame, if it has one (b2kFrame)
--    lets you drag anything that moves, with b2kGrab and b2kRelease
--    takes the world and everything the Kit made away when the card
--    closes, with b2kClear and b2kTeardown (labClose)
--
-- The Kit works in pixels and screen coordinates (y goes DOWN), and in
-- degrees, and converts to Box2D's metres, y up and radians itself. A
-- game of yours does what labOpen does with the whole card, or simply
-- calls b2kQuickStart.

constant kScale = 40

-- The card in front and its stack
local sCard, sStack
-- True when the Kit is running a world for the card in front
local sReady
-- True while the Pause button holds the game still
local sPaused
-- What a card asked the Lab to take away when it closes (labKeep)
local sKept
-- When the line at the court's top last changed, and what it says
local sSaidAt, sSaid
-- True while a click in the court is handed to the card's mouseDown
local sForwarding
-- The button of the card's that is lit for a moment (labShowButtons)
local sFlashed, sLightTicks
-- The card being opened, until labOpenNow makes its lesson
local sOpening

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

-- Makes the card's game: the Kit's world in the court, then the card's
-- labBuild, then the loop
command labOpen
   local tError, tLeft, tTop, tRight, tBottom
   labClose
   put the long id of this card into sCard
   put the short name of this stack into sStack
   put false into sPaused
   labPauseLabel
   labTabExplain
   labPaintCode
   if not labKitReady() then
      labSay "The Box2Dxt Kit is not loaded. Turn on Box2Dxt and the Box2Dxt Kit in Tools > Extension Manager, then open this card again.", true
      exit labOpen
   end if
   put the left of graphic "Court" into tLeft
   put the top of graphic "Court" into tTop
   put the right of graphic "Court" into tRight
   put the bottom of graphic "Court" into tBottom
   -- (locked while the card makes its game: a control is made before it
   -- is sized and put in its place)
   lock screen
   try
      -- A world, with gravity pulling down at 10 metres a second each
      -- second (y up, as Box2D counts), 40 pixels to a metre, and the
      -- world's 0,0 at the middle of the court's floor
      b2kSetup 0, -10
      b2kSetScale kScale
      b2kSetOrigin (tLeft + tRight) div 2, tBottom
      -- Walls around the court: lines that nothing passes through. (A
      -- card with a world bigger than the court, as Camera has, makes
      -- its own, in a labWorld handler)
      dispatch "labWorld" to sCard
      if it is not "handled" then
         b2kWall tLeft, tBottom, tRight, tBottom
         b2kWall tLeft, tTop, tLeft, tBottom
         b2kWall tRight, tTop, tRight, tBottom
         b2kWall tLeft, tTop, tRight, tTop
      end if
      -- Each frame, b2kFrame comes here; contacts go to the card
      b2kFrameTarget the long id of me
      b2kContactTarget sCard
      put true into sReady
      dispatch "labBuild" to sCard
      b2kStart
      labShowButtons empty
   catch tError
      labFail "labBuild", tError
   end try
   unlock screen
end labOpen

-- True when the Kit is there to call: its b2kVersion() is 4
function labKitReady
   local tError
   try
      return b2kVersion() is 4
   catch tError
      return false
   end try
end labKitReady

-- Stops the game and takes away what the Kit and the card made
command labClose
   local tId, tError
   if sReady then
      put false into sReady
      try
         b2kRelease
         -- (the keyboard, if a lesson read it)
         b2kInputInjectOff
         b2kInputOff
         -- (everything the Kit made that moves, then the world itself)
         b2kClear
         b2kTeardown
      catch tError
      end try
   end if
   lock screen
   lock messages
   repeat for each line tId in sKept
      if there is a tId then
         delete tId
      end if
   end repeat
   unlock messages
   unlock screen
   put empty into sKept
   put empty into sSaid
   if sCard is not empty and there is a field "Readout" of sCard then
      put empty into field "Readout" of sCard
   end if
   if there is a graphic "ReadoutBg" then
      hide graphic "ReadoutBg"
   end if
end labClose

-- A control the card made that is not the Kit's: the Lab deletes it
-- when the card closes or resets
command labKeep pObj
   put the long id of pObj & return after sKept
end labKeep

########################################
#
# Each frame
#

-- The Kit sends b2kFrame to its frame target (b2kFrameTarget) once a
-- frame, after it has moved everything: the card's labStep runs here
on b2kFrame
   local tError
   if not sReady then
      exit b2kFrame
   end if
   try
      dispatch "labStep" to sCard
   catch tError
      labFail "labStep", tError
   end try
   -- (the keys, and the lessons themselves, can switch things too: the
   -- lights follow, five times a second)
   add 1 to sLightTicks
   if sLightTicks mod 12 is 0 then
      labShowButtons empty
   end if
end b2kFrame

-- The Reset button
command labRestart
   labOpen
end labRestart

-- The Pause button: b2kPause holds the game still, b2kResume sets it
-- going again
command labTogglePause
   if not sReady then
      exit labTogglePause
   end if
   put not sPaused into sPaused
   if sPaused then
      b2kPause
   else
      b2kResume
   end if
   labPauseLabel
end labTogglePause

-- The Step button: one frame, then paused
command labStepButton
   if not sReady then
      exit labStepButton
   end if
   if not sPaused then
      put true into sPaused
      b2kPause
      labPauseLabel
   end if
   b2kStepOnce
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

-- When a handler of the card stops with an error, the game stops, and
-- the line at the court's top says where
command labFail pWhere, pError
   local tLine, tError
   put item 2 of line 1 of pError into tLine
   try
      b2kStop
   catch tError
   end try
   if tLine is an integer and tLine > 0 then
      labSay "Stopped: an error in" && pWhere && "or a handler it called, at line" && tLine & ". Fix it, then press Reset.", true
   else
      labSay "Stopped: an error in" && pWhere & ". Fix it, then press Reset.", true
   end if
end labFail

########################################
#
# The line of words at the court's top
#

-- Called each frame, it changes at most five times a second, which is
-- as fast as anyone reads; with pNow, at once
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
   set the height of field "Readout" to the formattedHeight of field "Readout" + 4
   set the top of field "Readout" to tTop
   set the rect of graphic "ReadoutBg" to the left of field "Readout" - 6, tTop - 3, \
         the right of field "Readout" + 6, the bottom of field "Readout" + 3
   set the visible of graphic "ReadoutBg" to (field "Readout" is not empty)
end labFitReadout

-- A number to a few places, for the line of words
function labNum pNumber, pPlaces
   if pPlaces is empty then
      put 1 into pPlaces
   end if
   if pNumber is not a number then
      return pNumber
   end if
   return format("%." & pPlaces & "f", pNumber)
end labNum

########################################
#
# The mouse
#

-- A click in the court grabs what is under it, if it moves (b2kGrab),
-- and goes to the card's own mouseDown too. (b2kCamMouseX and
-- b2kCamMouseY are the mouse's place in the world: the same as the
-- mouseH and the mouseV, unless a camera has scrolled the world)
on mouseDown pButton
   local tError
   if sForwarding then
      exit mouseDown
   end if
   if pButton is 1 and sReady and not sPaused and the mouseLoc is within the rect of graphic "Court" then
      get b2kGrab(b2kCamMouseX(), b2kCamMouseY())
   end if
   if labOwns(the long id of the target) then
      put true into sForwarding
      try
         dispatch "mouseDown" to this card with pButton
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

on mouseUp pButton
   local tDo, tTarget
   labLetGo
   put the long id of the target into tTarget
   put labButtonDo(tTarget) into tDo
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

private command labLetGo
   local tError
   if sReady then
      try
         b2kRelease
      catch tError
      end try
   end if
end labLetGo

-- The wheel scrolls the words in the tabs (65308 down, 65309 up), though
-- they have no scrollbar
on rawKeyDown pKey
   local tStep, tField
   if pKey is 65308 or pKey is 65309 then
      repeat for each item tField in "Explain,Calls,CallDoc,TryCode"
         if there is a field tField and the visible of field tField and the mouseLoc is within the rect of field tField then
            put 3 * 17 into tStep
            if pKey is 65309 then
               put -tStep into tStep
            end if
            set the vScroll of field tField to max(0, the vScroll of field tField + tStep)
            exit rawKeyDown
         end if
      end repeat
   end if
   pass rawKeyDown
end rawKeyDown

########################################
#
# The buttons, the tabs, and the calls
#

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

-- Runs a button's handler: the card's, or the Lab's own (Reset, Pause,
-- Step, the tabs and the Code tab's buttons)
command labRun pHandler
   local tError
   if sCard is empty then
      exit labRun
   end if
   if pHandler begins with "lab" then
      dispatch pHandler to me
      exit labRun
   end if
   if not sReady then
      exit labRun
   end if
   -- (the screen is locked while the button runs: a control is made
   -- before it is sized and put in its place, and would flash at the
   -- card's middle in the meantime)
   lock screen
   try
      dispatch pHandler to sCard
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

command labTabExplain
   labTab "Explain"
end labTabExplain

command labTabCode
   labTab "Code"
end labTabCode

command labTabCalls
   labTab "Calls"
end labTabCalls

-- Shows one tab's pane, and puts the bar under its name
private command labTab pTab
   local tTab
   if there is no field "TabExplain" then
      exit labTab
   end if
   lock screen
   repeat for each item tTab in "Explain,Code,Calls"
      set the visible of group ("Pane" & tTab) to (tTab is pTab)
      if tTab is pTab then
         set the textStyle of field ("Tab" & tTab) to "bold"
      else
         set the textStyle of field ("Tab" & tTab) to "plain"
      end if
   end repeat
   set the rect of graphic "TabBar" to the left of field ("Tab" & pTab) + 2, item 2 of the rect of graphic "TabBar", \
         the right of field ("Tab" & pTab) - 2, item 4 of the rect of graphic "TabBar"
   unlock screen
end labTab

-- The Code tab's Run: its lines, run as the Kit's handlers would be
-- run from a script of yours
command labRunCode
   local tError, tLine
   if not sReady then
      labSay "Nothing to run the lines in: press Reset first.", true
      exit labRunCode
   end if
   labPaintCode
   -- (locked while the lines run: a control they make would flash at the
   -- card's middle before it is put in its place)
   lock screen
   try
      do field "TryCode"
      labSay "Ran your lines.", true
      labShowButtons empty
   catch tError
      put item 2 of line 1 of tError into tLine
      if tLine is an integer and tLine > 0 then
         labSay "Your lines stopped at line" && tLine & ": check the spelling and the commas.", true
      else
         labSay "Your lines stopped: check the spelling and the commas.", true
      end if
   end try
   unlock screen
end labRunCode

command labCopyCode
   set the clipboardData["text"] to field "TryCode"
   labSay "Copied. Paste the lines into a script of yours.", true
end labCopyCode

command labResetCode
   put the cTry of field "TryCode" into field "TryCode"
   labPaintCode
   labSay "The lines are as they were.", true
end labResetCode

-- The Code tab's lines in the scripts drawer's colours: comments grey,
-- the Kit's handlers violet, the rest light
command labPaintCode
   local tIndex, tLine, tWord
   if there is no field "TryCode" then
      exit labPaintCode
   end if
   lock screen
   set the textColor of char 1 to -1 of field "TryCode" to empty
   repeat with tIndex = 1 to the number of lines of field "TryCode"
      put line tIndex of field "TryCode" into tLine
      if word 1 of tLine begins with "--" then
         set the textColor of line tIndex of field "TryCode" to "148,163,184"
         next repeat
      end if
      repeat with tWord = 1 to the number of words of tLine
         if word tWord of tLine begins with "b2k" then
            set the textColor of word tWord of line tIndex of field "TryCode" to "196,181,253"
         end if
      end repeat
   end repeat
   unlock screen
end labPaintCode

-- What a Kit handler in the calls list does, in full
command labExplain pName
   local tDocs, tDoc, tText
   -- (the words are one array in the custom property cDocs: read whole,
   -- then by name. "the cDocs[pName]" would ask a custom property SET)
   put the cDocs of me into tDocs
   put tDocs[pName] into tDoc
   if tDoc is empty then
      exit labExplain
   end if
   set the itemDelimiter to "|"
   put item 1 of tDoc & return & item 2 of tDoc & return & return & item 3 to -1 of tDoc into tText
   set the itemDelimiter to comma
   replace "\n" with return in tText
   put tText into field "CallDoc"
   set the textStyle of line 1 of field "CallDoc" to "bold"
   set the textFont of line 1 of field "CallDoc" to the textFont of field "TryCode"
   set the vScroll of field "CallDoc" to 0
end labExplain
@*/

/*@ Quick/card
-- 01 Quick Start: a world in a few lines
-- The Kit's world is like Box2D's (Learn Box2D shows it), but you talk to
-- it in pixels: a ball 60 pixels across, at 400, 260 on the card. The
-- Kit turns that into metres for Box2D, and moves the ball's graphic to
-- where Box2D says it is, 60 times a second.
--
-- The Lab has made the world for this court and started it. On a card
-- of your own, one line does that for the whole card:
--
--    on openCard
--       b2kQuickStart
--       b2kSpawnBall 200, 80, 50
--    end openCard
--    on mouseDown
--       get b2kGrab(the mouseH, the mouseV)
--    end mouseDown
--    on mouseUp
--       b2kRelease
--    end mouseUp
--    on closeCard
--       b2kStop
--    end closeCard

-- The colours the shapes are made in, a line each
local sColors

on labBuild
   put "251,146,60" & return & "56,189,248" & return & "167,139,250" & return & \
         "52,211,153" & return & "244,114,182" & return & "250,204,21" into sColors
   -- A ball, 60 pixels across, its middle at 400, 260
   b2kSpawnBall 400, 260, 60, line 1 of sColors
   -- A box, 80 wide and 50 high
   b2kSpawnBox 520, 240, 80, 50, line 2 of sColors
   -- A capsule (a pill), 90 long and 30 thick
   b2kSpawnCapsule 470, 320, 90, 30, line 3 of sColors
end labBuild

on labStep
   labSay "bodies:" && b2kBodyCount() & "   still moving:" && b2kAwakeCount()
end labStep

on addBall
   b2kSpawnBall 300 + random(350), 230, 30 + random(40), any line of sColors
end addBall

on addBox
   b2kSpawnBox 300 + random(350), 230, 30 + random(60), 30 + random(40), any line of sColors
end addBox

on addCapsule
   b2kSpawnCapsule 300 + random(350), 230, 60 + random(60), 24 + random(16), any line of sColors
end addCapsule

-- Rain: ten of them, of every kind
on rain
   local tIndex
   repeat with tIndex = 1 to 10
      switch tIndex mod 3
         case 0
            addBall
            break
         case 1
            addBox
            break
         default
            addCapsule
      end switch
   end repeat
end rain

-- Clear: everything that moves goes; the walls stay
on clearAll
   b2kClear
end clearAll
@*/

/*@ Quick/explain
# What you see
Balls, boxes and pills that fall, land, roll and pile up, as real things do. Drag them about, and throw them.
# The Kit in a few lines
On a card of yours:
* b2kQuickStart makes a world with gravity and walls round the card, and starts it.
* b2kSpawnBall, b2kSpawnBox and b2kSpawnCapsule make shapes that fall.
* b2kGrab and b2kRelease let the mouse drag them.
* b2kStop stops it all when the card closes.
# Try
Press Rain a few times, then drag a box into the pile. Open Scripts to read the card's script.
@*/

/*@ Quick/try
-- A red ball, 80 pixels across,
-- in the middle of the court
b2kSpawnBall 475, 250, 80, "red"

-- A long thin box: 160 by 20
b2kSpawnBox 475, 200, 160, 20, "orange"
@*/

/*@ Controls/card
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
@*/

/*@ Controls/explain
# What you see
A real button, field and graphics that fall and bump into each other. Press the button: it still works.
# How
* b2kAddBox gives a control a box the size of its rectangle.
* b2kAddBall gives it a circle, b2kAddPolygon its own outline.
* b2kAddStatic gives it a body that never moves, like the shelf.
* After that the Kit moves the control for you.
# Try
Press Shelf moves, and watch it carry what is on it. Then Heavy ball, and drop boxes onto it.
@*/

/*@ Controls/try
-- Make a button, then give it a body
create button "Me too"
set the rect of it to 450, 200, 540, 230
b2kAddBox it, true

-- Turn the triangle upside down
b2kMoveTo the long id of graphic "Triangle", 450, 250, 180
@*/

/*@ Moves/card
-- 03 Pushes and Spins: making things move
-- There are three ways to make a body go, and they feel different:
--
--    b2kPush       adds to its speed, in pixels a second, whatever it weighs
--    b2kImpulse    a kick: the same kick moves a heavy body less
--    b2kSetVelocity  sets its speed outright
--
-- and b2kSpin sets how fast it turns, in degrees a second. b2kExplode
-- kicks everything near a point away from it. The surface a body has
-- matters too: b2kSetBounce (how bouncy) and b2kSetFriction (how grippy).
-- Up is NEGATIVE y on the card: a push of 0, -450 goes up.

local sBall, sBoxes, sBouncy, sMoon

on labBuild
   local tRow, tCol
   -- The ball you move
   b2kSpawnBall 330, 500, 50, "251,146,60"
   put the result into sBall
   -- A tower of boxes
   put empty into sBoxes
   repeat with tRow = 0 to 4
      repeat with tCol = 0 to 1
         b2kSpawnBox 560 + tCol * 44, 580 - tRow * 42, 40, 40, "56,189,248"
         put the result & return after sBoxes
      end repeat
   end repeat
   put false into sBouncy
   put false into sMoon
end labBuild

on labStep
   local tVelocity
   put b2kVelocity(sBall) into tVelocity
   labSay "ball: speed" && round(b2kSpeed(sBall)) && "px/s   velocity" && round(item 1 of tVelocity) & "," & round(item 2 of tVelocity) && \
         "   turning" && round(b2kSpinRate(sBall)) && "deg/s"
end labStep

-- Jump: 450 pixels a second more, upward
on jump
   b2kPush sBall, 0, -450
end jump

-- Kick: the same kick for every box; the bottom ones are held by the rest
on kick
   local tBox
   repeat for each line tBox in sBoxes
      b2kImpulse tBox, -60, -40
   end repeat
end kick

on spin
   b2kSpin sBall, 900
end spin

-- Boom: a blast at the court's floor, 220 pixels wide
on boom
   b2kExplode 475, 600, 220, 1200
end boom

on bouncy
   put not sBouncy into sBouncy
   if sBouncy then
      b2kSetBounce sBall, 0.9
   else
      b2kSetBounce sBall, 0.1
   end if
end bouncy

-- Moon: a sixth of the gravity
on moon
   put not sMoon into sMoon
   if sMoon then
      b2kSetGravity 0, -1.6
   else
      b2kSetGravity 0, -10
   end if
end moon

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "bouncy"
         return sBouncy
      case "moon"
         return sMoon
   end switch
   return false
end labLit
@*/

/*@ Moves/explain
# What you see
An orange ball and a tower of boxes. The buttons push, kick, spin and blast them.
# Three ways to move a body
* b2kPush adds speed, whatever the body weighs.
* b2kImpulse is a kick: heavy things move less.
* b2kSetVelocity sets the speed outright.
* b2kSpin makes it turn, b2kExplode blasts things away from a point.
On the card, up is minus: a push of 0, -450 goes up.
# Try
Bouncy, then Jump. Moon, then Boom.
@*/

/*@ Moves/try
-- Every box flies up and to the right
repeat for each line tBox in b2kOverlapMoving(270, 160, 680, 600)
   b2kPush tBox, 200, -600
end repeat
@*/

/*@ Joints/card
-- 04 Joints: hinges, ropes, sliders and wheels
-- A joint ties two bodies together, or one body to the world:
--
--    b2kHinge   a pin they turn about (a door, a pendulum)
--    b2kRope    a fixed distance between their middles, springy with b2kSpring
--    b2kSlider  a line one slides along (a lift, a piston)
--    b2kWheel   a wheel on a sprung axle
--    b2kWeld    glued
--
-- A joint is invisible: this card draws a line for each, each frame.
-- Joints with a motor (b2kMotor, b2kSliderMotor, b2kWheelMotor) turn or
-- move by themselves, at a speed you give, with as much force as you allow.

local sPendulum, sMill, sMillJoint, sMillSpeed, sHook, sWeight, sRope, sLift, sLiftJoint
local sCart, sWheels, sWheelJoints, sLines, sDirection

on labBuild
   local tObj
   -- A pendulum: a ball pinned to the world (empty) at 330, 250
   b2kSpawnBall 410, 330, 36, "251,146,60"
   put the result into sPendulum
   b2kHinge sPendulum, empty, 330, 250
   -- A windmill: a long box pinned at its middle, with a motor
   b2kSpawnBox 580, 330, 150, 14, "167,139,250"
   put the result into sMill
   b2kHinge sMill, empty, 580, 330
   put the result into sMillJoint
   put 90 into sMillSpeed
   b2kMotor sMillJoint, sMillSpeed, 5000
   -- A rope: a hook that never moves, and a weight on a rope from it
   create graphic "Hook"
   put it into sHook
   set the style of sHook to "oval"
   set the opaque of sHook to true
   set the backgroundColor of sHook to "148,163,184"
   set the rect of sHook to 445, 245, 455, 255
   labKeep sHook
   b2kAddStatic sHook
   b2kSpawnBox 450, 370, 40, 40, "56,189,248"
   put the result into sWeight
   b2kRope sHook, sWeight
   put the result into sRope
   -- A lift: a platform that slides up and down (90 degrees), with a motor
   b2kSpawnBox 640, 520, 70, 12, "52,211,153"
   put the result into sLift
   b2kSlider sLift, empty, 90
   put the result into sLiftJoint
   b2kSliderLimit sLiftJoint, -150, 60
   -- A cart: a box with two wheels on sprung axles
   b2kSpawnBox 360, 515, 110, 22, "244,114,182"
   put the result into sCart
   put empty into sWheels
   put empty into sDirection
   put empty into sWheelJoints
   repeat for each item tObj in "325,395"
      b2kSpawnBall tObj, 530, 30, "71,85,105"
      put the result & return after sWheels
      b2kWheel sCart, the result, tObj, 530
      put the result & return after sWheelJoints
      -- (a firm spring: 6 bounces a second, settling quickly)
      b2kWheelSpring line -1 of sWheelJoints, 6, 0.7
   end repeat
   -- The lines that show the pendulum's rod and the rope
   put empty into sLines
   repeat for each item tObj in "rod,rope"
      create graphic ("joint_" & tObj)
      set the style of it to "line"
      set the foregroundColor of it to "226,232,240"
      set the lineSize of it to 2
      labKeep it
      put the long id of it into sLines[tObj]
   end repeat
end labBuild

-- Each frame: the lines, and the numbers
on labStep
   set the points of sLines["rod"] to "330,250" & return & b2kPosition(sPendulum)
   if sRope is not empty then
      set the points of sLines["rope"] to "450,250" & return & b2kPosition(sWeight)
   end if
   labSay "windmill" && (round(b2kHingeAngle(sMillJoint)) mod 360 + 360) mod 360 & numToCodepoint(176) && \
         "  lift" && round(b2kSliderPos(sLiftJoint)) && "px   rope" && ropeWords() && "   cart" && round(b2kSpeed(sCart)) && "px/s"
end labStep

private function ropeWords
   if sRope is empty then
      return "cut"
   end if
   return round(b2kRopeLength(sRope)) && "px"
end ropeWords

on faster
   if abs(sMillSpeed) < 700 then
      put sMillSpeed * 2 into sMillSpeed
   end if
   b2kMotor sMillJoint, sMillSpeed, 5000
end faster

on reverse
   put -sMillSpeed into sMillSpeed
   b2kMotor sMillJoint, sMillSpeed, 5000
end reverse

-- Lift: up and then down, 120 pixels a second. (A body that has stopped
-- is asleep, and a motor does not wake it: b2kSetVelocity does)
on liftUp
   b2kSetVelocity sLift, 0, 0
   if b2kSliderPos(sLiftJoint) > -100 then
      b2kSliderMotor sLiftJoint, -120, 2000
   else
      b2kSliderMotor sLiftJoint, 120, 2000
   end if
end liftUp

-- Springy: the rope stretches, 2 times a second, a little damped
on springy
   if sRope is not empty then
      b2kSpring sRope, 2, 0.1
   end if
end springy

on cutRope
   if sRope is not empty then
      b2kRemoveJoint sRope
      put empty into sRope
      set the points of sLines["rope"] to empty
   end if
end cutRope

-- Drive: both wheels turn, 600 degrees a second, to the right; Drive
-- again goes back to the left
on drive
   local tJoint
   if sDirection is 1 then
      put -1 into sDirection
   else
      put 1 into sDirection
   end if
   -- (the cart and its wheels may be asleep: setting a speed wakes them)
   b2kSetVelocity sCart, 0, 0
   repeat for each line tJoint in sWheels
      b2kSetVelocity tJoint, 0, 0
   end repeat
   repeat for each line tJoint in sWheelJoints
      b2kWheelMotor tJoint, -600 * sDirection, 400
   end repeat
end drive

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "reverse"
         return sMillSpeed < 0
   end switch
   return false
end labLit
@*/

/*@ Joints/explain
# What you see
A pendulum, a windmill with a motor, a weight on a rope, a lift and a cart. The white lines show the joints, which you would not see.
# Joints
* b2kHinge pins two things, or one to the world.
* b2kRope keeps them a distance apart; b2kSpring makes it stretch.
* b2kSlider lets one slide along a line.
* b2kWheel puts a wheel on a springy axle.
* b2kMotor, b2kSliderMotor and b2kWheelMotor make them go.
# Try
Springy, then pull the weight down and let go. Lift, Drive, then Cut rope.
@*/

/*@ Joints/try
-- A chain of three balls, hung from the hook
b2kSpawnBall 520, 260, 24, "yellow"
put the result into tA
b2kRope the long id of graphic "Hook", tA
b2kSpawnBall 560, 300, 24, "yellow"
b2kRope tA, the result
@*/

/*@ Keys/card
-- 05 Keyboard: playing with the arrow keys
-- A game reads the keyboard once a frame, so that holding a key makes
-- something keep going. b2kInputOn starts the Kit reading it. Then:
--
--    b2kKeyIsDown("left")      is the key held now?
--    b2kKeyPressed("space")    did it go down this frame?
--
-- Better still, give keys a meaning: b2kBindAxis "move", "left,a",
-- "right,d" makes an axis, and b2kAxis("move") is -1, 0 or 1. b2kBindAction
-- "jump", "up,w,space" makes an action, and b2kActionPressed("jump") is
-- true in the frame it starts. A player can then use either set of keys,
-- and you change them in one place.

local sHero, sJump, sIce

on labBuild
   local tIndex
   b2kInputOn
   b2kBindAxis "move", "left,a", "right,d"
   b2kBindAction "jump", "up,w,space"
   -- The hero: a graphic 34 wide and 60 high, with a capsule body (a
   -- taller-than-wide control makes a capsule that stands up), that
   -- never falls over
   create graphic "Hero"
   put it into sHero
   set the opaque of sHero to true
   set the backgroundColor of sHero to "251,146,60"
   set the rect of sHero to 323, 510, 357, 570
   labKeep sHero
   b2kAddCapsule sHero, true
   b2kSetFixedRotation sHero, true
   -- Platforms: boxes made static
   repeat for each line tIndex in "430,500" & return & "560,430" & return & "430,360" & return & "580,280"
      b2kSpawnBox item 1 of tIndex, item 2 of tIndex, 110, 14, "148,163,184"
      b2kSetStatic the result
   end repeat
   put 520 into sJump
   put false into sIce
end labBuild

-- Each frame: left and right set the hero's speed across; jump pushes it
-- up, when it is standing on something (going neither up nor down)
on labStep
   local tMove, tVelocity
   put b2kAxis("move") into tMove
   put b2kVelocity(sHero) into tVelocity
   b2kSetVelocity sHero, tMove * 220, item 2 of tVelocity
   if b2kActionPressed("jump") and abs(item 2 of tVelocity) < 5 then
      b2kPush sHero, 0, -sJump
   end if
   labSay "keys held:" && b2kKeysHeld() & "   move:" && tMove & "   jump:" && b2kActionIsDown("jump")
end labStep

-- The arrow keys belong to the game on this card: without this, the
-- window would take them to go to the next lesson. (The Kit reads the
-- keys by itself, each frame, so nothing more is needed here)
on arrowKey pKey
end arrowKey

on higher
   if sJump < 700 then
      put 760 into sJump
   else
      put 520 into sJump
   end if
end higher

-- Ice: no friction, so the hero slides
on ice
   put not sIce into sIce
   if sIce then
      b2kSetFriction sHero, 0
   else
      b2kSetFriction sHero, 0.6
   end if
end ice

on dropBoxes
   local tIndex
   repeat with tIndex = 1 to 4
      b2kSpawnBox 320 + random(320), 220, 34, 34, "56,189,248"
   end repeat
end dropBoxes

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "higher"
         return sJump > 700
      case "ice"
         return sIce
   end switch
   return false
end labLit
@*/

/*@ Keys/explain
# What you see
An orange hero on platforms. The arrow keys move it, Up or Space jumps. A, D and W work too.
# How
* b2kInputOn starts the Kit reading the keys, once a frame.
* b2kBindAxis gives two sets of keys one name: b2kAxis is -1, 0 or 1.
* b2kBindAction names a set of keys: b2kActionPressed says when it starts.
* labStep sets the hero's speed from them.
# Try
Climb to the top platform. Then Ice, and Higher jumps.
@*/

/*@ Keys/try
-- Make Q a jump key too
b2kBindAction "jump", "up,w,space,q"

-- A pill that is not the hero: it can roll,
-- because only the hero has fixed rotation
b2kSpawnCapsule 400, 300, 80, 40, "pink"
@*/

/*@ Sprites/card
-- 06 Sprite Sheets: many pictures in one image
-- A sprite sheet is one image with many small pictures in it: every pose
-- of a character, or every tile of a level. Games use them because one
-- image is quicker to load and easier to keep than fifty. The Kit cuts a
-- sheet into frames, each with a name, and a sprite is a picture on the
-- card that shows one frame at a time.
--
-- The two sheets here are images on this card, hidden: "AlienArt", the
-- green alien in its poses, and "TileArt", a grid of 64 by 64 tiles.
-- Both are Kenney's (https://kenney.nl), free to use (CC0).

-- The alien, its poses in order, the pose it shows, and the whole sheet
-- when "See the sheet" shows it
local sAlien, sPoses, sPose, sSheet

on labBuild
   local tIndex
   -- 1. A sheet with no grid (0 by 0), because the alien's pictures are
   --    not all the same size. Each one is named with where it is in the
   --    image: its left, its top, its width and its height, in pixels
   b2kSheetFromImage "alien", the long id of image "AlienArt", 0, 0
   b2kSheetAddFrame "alien", "stand", 69, 379, 66, 92
   b2kSheetAddFrame "alien", "walk1", 69, 193, 68, 93
   b2kSheetAddFrame "alien", "walk2", 0, 0, 70, 96
   b2kSheetAddFrame "alien", "jump", 69, 286, 67, 93
   b2kSheetAddFrame "alien", "duck", 0, 380, 69, 71
   b2kSheetAddFrame "alien", "hurt", 0, 288, 69, 92
   b2kSheetAddFrame "alien", "climb", 70, 0, 66, 92
   put "stand,walk1,walk2,jump,duck,hurt,climb" into sPoses
   put 1 into sPose
   -- 2. A sheet that IS a grid: squares of 64 by 64 pixels, with 1 pixel
   --    between them (the last two numbers: no border, a gap of 1). The
   --    Kit numbers the squares 1, 2, 3, ... across each row, then down
   b2kSheetFromImage "tiles", the long id of image "TileArt", 64, 64, empty, 0, 1
   -- 3. An animation: the two walk pictures, 6 a second, round and round
   b2kAnimDef "alien", "walk", "walk1,walk2", 6, true
   -- 4. The sprite: a picture on the card, showing the frame "stand", in
   --    the middle of the court. b2kAddBox gives it a body, so it falls,
   --    lands, and can be dragged
   b2kSpriteNew "alien", "stand", 475, 300
   put the result into sAlien
   b2kAddBox sAlien, true
   -- 5. A floor of tiles: sprites from the grid sheet (square 28 is a
   --    brown brick), each with a body that does not move (b2kAddStatic)
   repeat with tIndex = 0 to 5
      b2kSpriteNew "tiles", 28, 315 + tIndex * 64, 570
      b2kAddStatic the result
   end repeat
   put empty into sSheet
end labBuild

-- Each frame: what the alien shows, and how big that frame is
on labStep
   local tFrame
   if sSheet is not empty then
      exit labStep
   end if
   put b2kSpriteFrame(sAlien) into tFrame
   labSay "showing:" && tFrame & "   (" & item 1 of b2kSheetFrameSize("alien", tFrame) && "by" && item 2 of b2kSheetFrameSize("alien", tFrame) & " pixels)" & \
         "   alien sheet:" && b2kSheetFrames("alien") && "frames   tile sheet:" && b2kSheetFrames("tiles")
end labStep

-- Next picture: the next pose, by its name. b2kSpriteSetFrame stops an
-- animation that is playing
on nextPicture
   if sheetShown() then
      exit nextPicture
   end if
   put sPose mod the number of items of sPoses + 1 into sPose
   b2kSpriteSetFrame sAlien, item sPose of sPoses
end nextPicture

-- Walk: the animation made in labBuild
on walk
   if sheetShown() then
      exit walk
   end if
   b2kSpritePlay sAlien, "walk"
end walk

-- Flip: the same pictures, mirrored, so the alien faces the other way
on flipAlien
   if sheetShown() then
      exit flipAlien
   end if
   b2kSpriteFlipH sAlien, not b2kSpriteFlipped(sAlien)
end flipAlien

-- Drop a crate: square 10 of the tile sheet (wooden planks), with a box
-- body, from above the alien
on dropCrate
   if sheetShown() then
      exit dropCrate
   end if
   b2kSpriteNew "tiles", 10, random(300) + 320, 200
   b2kAddBox the result, true
end dropCrate

-- See the sheet: the whole alien sheet, smaller, with a line around each
-- frame named in labBuild, over the game. Again, to go back to it
on seeSheet
   local tPose, tRect, tObj, tScale, tLeft, tTop, tList
   if sSheet is not empty then
      put empty into sSheet
      labRestart
      exit seeSheet
   end if
   -- (the game's sprites go: Reset, or See the sheet again, makes them)
   b2kClear
   b2kPause
   put 0.7 into tScale
   put the left of graphic "Court" + 24 into tLeft
   put the top of graphic "Court" + 84 into tTop
   lock screen
   -- (a dark cover over the game, below the court's buttons)
   create graphic "sheet_cover"
   put it into tObj
   set the style of tObj to "rectangle"
   set the opaque of tObj to true
   set the lineSize of tObj to 0
   set the backgroundColor of tObj to "15,23,42"
   set the rect of tObj to the left of graphic "Court", the top of graphic "Court" + 40, \
         the right of graphic "Court", the bottom of graphic "Court"
   labKeep tObj
   create field "sheet_words"
   put it into tObj
   set the lockText of tObj to true
   set the showBorder of tObj to false
   set the opaque of tObj to false
   set the textColor of tObj to "226,232,240"
   set the textSize of tObj to 12
   set the rect of tObj to tLeft - 4, the top of graphic "Court" + 44, the right of graphic "Court" - 16, tTop - 4
   set the text of tObj to "The alien's sheet: one image of" && the formattedWidth of image "AlienArt" && "by" && \
         the formattedHeight of image "AlienArt" && "pixels. Each yellow box is a frame that labBuild named with b2kSheetAddFrame. " & \
         "Press See the sheet again to play."
   labKeep tObj
   clone image "AlienArt"
   put it into sSheet
   set the width of sSheet to round(the formattedWidth of image "AlienArt" * tScale)
   set the height of sSheet to round(the formattedHeight of image "AlienArt" * tScale)
   set the topLeft of sSheet to tLeft, tTop
   show sSheet
   labKeep sSheet
   repeat for each item tPose in sPoses
      put frameRect(tPose) into tRect
      create graphic ("sheet_" & tPose)
      put it into tObj
      set the style of tObj to "rectangle"
      set the opaque of tObj to false
      set the foregroundColor of tObj to "250,204,21"
      set the lineSize of tObj to 2
      set the rect of tObj to tLeft + round(item 1 of tRect * tScale), tTop + round(item 2 of tRect * tScale), \
            tLeft + round((item 1 of tRect + item 3 of tRect) * tScale), tTop + round((item 2 of tRect + item 4 of tRect) * tScale)
      labKeep tObj
      -- (its name in the box, and in the list to the right of the sheet,
      -- where it is and how big)
      create field ("sheet_tag_" & tPose)
      put it into tObj
      set the lockText of tObj to true
      set the showBorder of tObj to false
      set the opaque of tObj to true
      set the backgroundColor of tObj to "250,204,21"
      set the textColor of tObj to "15,23,42"
      set the textSize of tObj to 10
      set the margins of tObj to 1
      set the text of tObj to tPose
      set the rect of tObj to tLeft + round(item 1 of tRect * tScale) + 2, tTop + round(item 2 of tRect * tScale) + 2, \
            tLeft + round(item 1 of tRect * tScale) + 40, tTop + round(item 2 of tRect * tScale) + 16
      set the width of tObj to the formattedWidth of tObj + 2
      set the left of tObj to tLeft + round(item 1 of tRect * tScale) + 2
      labKeep tObj
      put tPose & tab & item 1 to 2 of tRect & tab & item 3 of tRect && "by" && item 4 of tRect & return after tList
   end repeat
   create field "sheet_list"
   put it into tObj
   set the lockText of tObj to true
   set the showBorder of tObj to false
   set the opaque of tObj to false
   set the textColor of tObj to "226,232,240"
   set the textSize of tObj to 11
   set the tabStops of tObj to "50,110"
   set the rect of tObj to tLeft + round(256 * tScale) + 24, tTop, the right of graphic "Court" - 10, tTop + 200
   set the text of tObj to "frame" & tab & "left, top" & tab & "size" & return & tList
   set the textStyle of line 1 of tObj to "bold"
   labKeep tObj
   unlock screen
end seeSheet

-- While the sheet shows, the game's sprites are gone: a button that
-- needs them says how to get them back instead
private function sheetShown
   if sSheet is empty then
      return false
   end if
   labSay "The sheet is showing: press See the sheet again to go back to the game.", true
   return true
end sheetShown

-- Where a frame is in the sheet: what labBuild gave b2kSheetAddFrame
-- (the Kit keeps it to itself, so the lesson keeps a copy to draw)
private function frameRect pPose
   switch pPose
      case "stand"
         return "69,379,66,92"
      case "walk1"
         return "69,193,68,93"
      case "walk2"
         return "0,0,70,96"
      case "jump"
         return "69,286,67,93"
      case "duck"
         return "0,380,69,71"
      case "hurt"
         return "0,288,69,92"
      default
         return "70,0,66,92"
   end switch
end frameRect

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "flipAlien"
         return b2kSpriteFlipped(sAlien)
      case "seeSheet"
         return sSheet is not empty
   end switch
   return false
end labLit
@*/

/*@ Sprites/explain
# What you see
The alien and the tiles are small pictures cut out of two big images, called sprite sheets. A game has hundreds of little pictures: a few big images are tidier, and quicker to load.
# How the Kit does it
* b2kSheetFromImage gives an image a name as a sheet.
* b2kSheetAddFrame names one picture in it.
* A grid sheet's squares are numbered for you.
* b2kSpriteNew puts a picture on the card.
# Try
Press See the sheet, and again to go back to the game. Then Next picture, Walk and Flip. Drop crates, and drag the alien.
@*/

/*@ Sprites/try
-- A sprite: the alien's "jump" picture
b2kSpriteNew "alien", "jump", 470, 220
-- give it a body, so it falls
b2kAddBox the result, true

-- A gem from the tile sheet: square 58
b2kSpriteNew "tiles", 58, 380, 220
b2kAddBox the result, true
@*/

/*@ Anim/card
-- 07 Animation and GIFs: pictures that move by themselves
-- An animation is a list of frames from a sheet, shown one after the
-- other: b2kAnimDef names it, says how many frames a second, and whether
-- it goes round and round (loops) or plays once. b2kSpritePlay starts it
-- on a sprite. When one that plays once ends, the Kit can send you a
-- message (b2kSpriteOnFinish), so that you know when to do the next thing.
--
-- An animated GIF is simpler: the engine plays it by itself.
-- b2kSpriteFromGIF puts one on the card from a GIF file.
--
-- Sheets can come from files too. b2kSheetLoadAtlas reads a PNG and an
-- XML file that names each picture in it (Kenney's packs come that way).
-- This lesson writes its own picture and XML to files, to show how.

-- The alien, the GIF, how fast the alien animates, and what last finished
local sAlien, sGif, sFps, sFinished

on labBuild
   local tPath
   -- 1. The alien's sheet, as on Sprite Sheets: a name for each picture
   b2kSheetFromImage "alien", the long id of image "AlienArt", 0, 0
   b2kSheetAddFrame "alien", "stand", 69, 379, 66, 92
   b2kSheetAddFrame "alien", "walk1", 69, 193, 68, 93
   b2kSheetAddFrame "alien", "walk2", 0, 0, 70, 96
   b2kSheetAddFrame "alien", "jump", 69, 286, 67, 93
   b2kSheetAddFrame "alien", "duck", 0, 380, 69, 71
   b2kSheetAddFrame "alien", "hurt", 0, 288, 69, 92
   -- 2. Three animations: the name of the sheet, a name for the
   --    animation, its frames, frames a second, and true to loop
   b2kAnimDef "alien", "walk", "walk1,walk2", 6, true
   b2kAnimDef "alien", "hop", "duck,jump,jump,jump,stand", 8, false
   b2kAnimDef "alien", "ouch", "hurt,hurt,hurt,stand", 6, false
   -- 3. The alien, walking. When "hop" or "ouch" ends, the Kit sends
   --    alienDone (below)
   b2kSpriteNew "alien", "stand", 400, 400
   put the result into sAlien
   b2kAddBox sAlien, true
   b2kSpritePlay sAlien, "walk"
   b2kSpriteOnFinish sAlien, "alienDone"
   put 6 into sFps
   put empty into sFinished
   -- 4. A GIF, from a file: the lesson writes the GIF that is in this
   --    stack (image "WalkGif") to one first. It falls too: a GIF is an
   --    image, and b2kAddBox works on images
   put specialFolderPath("temporary") & "/learn-kit-walk.gif" into tPath
   put the text of image "WalkGif" into URL ("binfile:" & tPath)
   b2kSpriteFromGIF tPath, 580, 400
   put the result into sGif
   b2kAddBox sGif, true
end labBuild

-- Each frame: what the alien is playing, and the frame it shows
on labStep
   labSay "alien: playing" && quote & b2kSpriteAnim(sAlien) & quote && "at" && sFps && "frames a second, showing" && \
         b2kSpriteFrame(sAlien) & "   GIF: picture" && the currentFrame of sGif & sFinished
end labStep

-- The Kit sends this when an animation that does not loop has ended:
-- the sprite, and the animation's name. Then the alien walks again
on alienDone pSprite, pAnim
   put "   (" & pAnim && "finished)" into sFinished
   b2kSpritePlay pSprite, "walk"
end alienDone

on hop
   b2kSpritePlay sAlien, "hop"
   b2kPush sAlien, 0, -380
end hop

on ouch
   b2kSpritePlay sAlien, "ouch"
end ouch

-- Faster: the same animation, at a speed of your choosing (b2kSpriteFPS)
on faster
   if sFps < 24 then
      put sFps * 2 into sFps
   else
      put 3 into sFps
   end if
   b2kSpriteFPS sAlien, sFps
end faster

-- Stop and go: b2kSpriteStop holds the frame it is on; b2kSpritePlay
-- goes on. It works on the GIF too
on stopGo
   if b2kSpriteAnim(sAlien) is empty then
      b2kSpritePlay sAlien, "walk"
      b2kSpritePlay sGif
   else
      b2kSpriteStop sAlien
      b2kSpriteStop sGif
   end if
end stopGo

-- From files: the alien's picture as a PNG file, and an XML file that
-- names each frame in it, the way Kenney's packs do. b2kSheetLoadAtlas
-- reads both, and the frames are called by the names in the XML
on fromFiles
   local tFolder, tXml, tFrame, tCount
   put specialFolderPath("temporary") into tFolder
   put the text of image "AlienArt" into URL ("binfile:" & tFolder & "/learn-kit-alien.png")
   put "<TextureAtlas imagePath=" & quote & "learn-kit-alien.png" & quote & ">" & return into tXml
   repeat for each line tFrame in "climb,70,0,66,92" & return & "swim,0,96,70,92" & return & "jump,69,286,67,93"
      put "  <SubTexture name=" & quote & item 1 of tFrame & quote && \
            "x=" & quote & item 2 of tFrame & quote && "y=" & quote & item 3 of tFrame & quote && \
            "width=" & quote & item 4 of tFrame & quote && "height=" & quote & item 5 of tFrame & quote & "/>" & return after tXml
   end repeat
   put "</TextureAtlas>" & return after tXml
   put tXml into URL ("file:" & tFolder & "/learn-kit-alien.xml")
   b2kSheetLoadAtlas "fromfiles", tFolder & "/learn-kit-alien.png", tFolder & "/learn-kit-alien.xml"
   put the result into tCount
   -- A sprite of each frame the XML named, dropped from above
   repeat for each line tFrame in b2kSheetFrameNames("fromfiles")
      b2kSpriteNew "fromfiles", tFrame, 300 + random(350), 250
      b2kAddBox the result, true
   end repeat
   put "   (read" && tCount && "frames from a PNG and an XML file)" into sFinished
end fromFiles

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "stopGo"
         return b2kSpriteAnim(sAlien) is empty
   end switch
   return false
end labLit
@*/

/*@ Anim/explain
# What you see
An alien that walks by itself, and a GIF of it walking beside it. The buttons change what the alien plays.
# How
* b2kAnimDef makes an animation: frames, how fast, loop or once.
* b2kSpritePlay starts it; b2kSpriteFPS changes its speed.
* b2kSpriteOnFinish sends you a message when one ends.
* b2kSpriteFromGIF shows a GIF, which plays by itself.
* b2kSheetLoadAtlas reads a sheet from a PNG and an XML file.
# Try
Hop, Ouch, Faster, then From files.
@*/

/*@ Anim/try
-- A new animation: duck and stand, over and over
b2kAnimDef "alien", "bob", "duck,stand", 4, true
b2kSpriteNew "alien", "stand", 330, 300
put the result into tNew
b2kAddBox tNew, true
b2kSpritePlay tNew, "bob"
@*/

/*@ Player/card
-- 08 A Player: a character that runs, jumps, climbs and swims
-- Most games have one character that the player moves. The Kit has a
-- controller for it that does what platform games do: run and jump
-- with the arrow keys, a jump that goes higher while you hold the key,
-- ladders, water, and being hurt. It picks the animation for you, and
-- turns the character to face the way it runs.
--
--    b2kPlayerMake     makes the character: a body, and a sprite on it
--    b2kPlayerAnims    which animation is for standing, running, ...
--    b2kPlayerSet      its knobs: how fast, how high, ...
--    b2kPlayerAddLadder and b2kPlayerAddWater: places on the card
--
-- The arrow keys move it, Up or Space jumps, Down ducks. On a ladder,
-- Up and Down climb.

local sPlayer, sDouble, sFast

on labBuild
   local tObj
   -- 1. The alien's sheet again, under its own name, and smaller
   b2kSheetFromImage "hero", the long id of image "AlienArt", 0, 0
   b2kSheetAddFrame "hero", "stand", 69, 379, 66, 92
   b2kSheetAddFrame "hero", "walk1", 69, 193, 68, 93
   b2kSheetAddFrame "hero", "walk2", 0, 0, 70, 96
   b2kSheetAddFrame "hero", "jump", 69, 286, 67, 93
   b2kSheetAddFrame "hero", "duck", 0, 380, 69, 71
   b2kSheetAddFrame "hero", "hurt", 0, 288, 69, 92
   b2kSheetAddFrame "hero", "climb", 70, 0, 66, 92
   b2kSheetAddFrame "hero", "climb2", 135, 380, 66, 91
   b2kSheetAddFrame "hero", "swim", 0, 96, 70, 92
   b2kSheetScale "hero", 0.6
   b2kAnimDef "hero", "idle", "stand", 1, true
   b2kAnimDef "hero", "run", "walk1,walk2", 8, true
   b2kAnimDef "hero", "jump", "jump", 1, true
   b2kAnimDef "hero", "duck", "duck", 1, true
   b2kAnimDef "hero", "climb", "climb,climb2", 6, true
   b2kAnimDef "hero", "hurt", "hurt", 1, true
   b2kAnimDef "hero", "swim", "swim,jump", 4, true
   -- 2. The level: a pool on the left, a platform, and a ladder up to a
   --    high ledge on the right
   labArea "Pool", "56,189,248", 280, 520, 410, 602
   b2kPlayerAddWater 280, 510, 410, 602
   b2kSpawnBox 495, 470, 150, 16, "148,163,184"
   b2kSetStatic the result
   labArea "Ladder", "180,120,60", 578, 300, 604, 602
   b2kPlayerAddLadder 578, 290, 604, 602
   b2kSpawnBox 642, 316, 72, 16, "148,163,184"
   b2kSetStatic the result
   -- 3. The player: 30 wide and 54 high, with the "hero" sheet on it,
   --    and the animation for each thing it does
   b2kPlayerMake 470, 420, 30, 54, "hero"
   put the result into sPlayer
   b2kPlayerAnims "idle", "run", "jump", "jump", empty, "duck", "climb", "hurt", "swim"
   put false into sDouble
   put false into sFast
end labBuild

-- Each frame: what the controller says the player is doing
on labStep
   local tFacing
   if b2kPlayerFacing() is 1 then
      put "right" into tFacing
   else
      put "left" into tFacing
   end if
   labSay "doing:" && b2kPlayerState() & "   on the ground:" && b2kPlayerOnGround() & "   facing:" && \
         tFacing & "   in water:" && b2kPlayerInWater() & "   on a ladder:" && b2kPlayerInLadder()
end labStep

-- The arrow keys belong to the game on this card, not to the window
on arrowKey pKey
end arrowKey

-- A painted area for a zone (a zone itself is invisible): the pool's
-- water, see-through, and the ladder
private command labArea pName, pColor, pLeft, pTop, pRight, pBottom
   local tObj
   create graphic pName
   put it into tObj
   set the style of tObj to "rectangle"
   set the opaque of tObj to true
   set the lineSize of tObj to 0
   set the backgroundColor of tObj to pColor
   set the blendLevel of tObj to 55
   set the rect of tObj to pLeft, pTop, pRight, pBottom
   labKeep tObj
end labArea

-- Double jump: one more jump in the air (the airJumps knob)
on doubleJump
   put not sDouble into sDouble
   if sDouble then
      b2kPlayerSet "airJumps", 1
   else
      b2kPlayerSet "airJumps", empty
   end if
end doubleJump

-- Faster: run at 340 pixels a second, not 220
on runFaster
   put not sFast into sFast
   if sFast then
      b2kPlayerSet "moveSpeed", 340
   else
      b2kPlayerSet "moveSpeed", empty
   end if
end runFaster

-- Ouch: a hit from the right; the player pops away from it
on hurtPlayer
   b2kPlayerHurt item 1 of b2kPosition(sPlayer) + 40
end hurtPlayer

on startAgain
   b2kPlayerRespawn 470, 420
end startAgain

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "doubleJump"
         return sDouble
      case "runFaster"
         return sFast
   end switch
   return false
end labLit
@*/

/*@ Player/explain
# What you see
The alien again, now a player you move with the arrow keys. Up or Space jumps; Down ducks. Swim in the pool, climb the ladder.
# How
* b2kPlayerMake makes the player, with a sprite on its body.
* b2kPlayerAnims says which animation shows what it does.
* b2kPlayerAddWater and b2kPlayerAddLadder mark places.
* b2kPlayerSet turns its knobs.
# Try
Climb to the ledge. Then Double jump, and jump twice.
@*/

/*@ Player/try
-- Jump much higher (the default is 460)
b2kPlayerSet "jumpSpeed", 700

-- Slide down walls, and jump off them
b2kPlayerSet "wallJumpX", 300
b2kPlayerSet "wallJumpY", 450
@*/

/*@ Camera/card
-- 09 Camera: a world bigger than the window
-- A level is often much wider than the window. The Kit's camera shows
-- part of it, and scrolls to keep the player in view.
--
--    b2kCamOn      a viewport: the rectangle of the card that shows the world
--    b2kCamBounds  how big the world is, so the camera stops at its edges
--    b2kCamFollow  which control to keep in view, and how smoothly
--    b2kCamShake   a shake, for a bump or a blast
--
-- With the camera on, places are places in the WORLD, not on the card.
-- The world's 0,0 is the top left corner of the viewport, before it
-- scrolls. This level is 1600 pixels wide and 378 high; the viewport
-- (the court, below the line of words) is 410 by 378. b2kCamMouseX and
-- b2kCamMouseY tell you where the mouse is in the world.

local sPlayer, sLoose, sDeadzone, sAuto

-- The Lab calls labWorld before labBuild. Handling it says "this card
-- makes its own walls": the world here is bigger than the court
on labWorld
   -- 1. The camera: the court, below its line of words, shows the world
   b2kCamOn "270,224,680,602"
   b2kCamBounds 0, 0, 1600, 378
   -- 2. The world's floor and its two ends: lines nothing passes through
   b2kWall 0, 378, 1600, 378
   b2kWall 0, -400, 0, 378
   b2kWall 1600, -400, 1600, 378
end labWorld

on labBuild
   local tIndex, tX
   -- 3. The level: ledges, each with a crate on it
   repeat for each line tIndex in "250,290,120" & return & "450,250,120" & return & "660,200,140" & return & \
         "910,280,120" & return & "1130,210,120" & return & "1370,140,160"
      b2kSpawnBox item 1 of tIndex, item 2 of tIndex, item 3 of tIndex, 16, "148,163,184"
      b2kSetStatic the result
      b2kSpawnBox item 1 of tIndex, item 2 of tIndex - 40, 30, 30, "180,120,60"
   end repeat
   -- (a marker every 200 pixels along the top, out of the player's
   -- reach, so that you see the world scroll by)
   repeat with tX = 200 to 1400 step 200
      b2kSpawnBox tX, 10, 4, 20, "71,85,105"
      b2kSetStatic the result
   end repeat
   -- 4. The player, as on the Player lesson, and the camera follows it
   b2kSheetFromImage "hero", the long id of image "AlienArt", 0, 0
   b2kSheetAddFrame "hero", "stand", 69, 379, 66, 92
   b2kSheetAddFrame "hero", "walk1", 69, 193, 68, 93
   b2kSheetAddFrame "hero", "walk2", 0, 0, 70, 96
   b2kSheetAddFrame "hero", "jump", 69, 286, 67, 93
   b2kSheetScale "hero", 0.6
   b2kAnimDef "hero", "idle", "stand", 1, true
   b2kAnimDef "hero", "run", "walk1,walk2", 8, true
   b2kAnimDef "hero", "jump", "jump", 1, true
   b2kPlayerMake 80, 320, 30, 54, "hero"
   put the result into sPlayer
   b2kPlayerAnims "idle", "run", "jump"
   b2kCamFollow sPlayer
   put false into sLoose
   put false into sDeadzone
   put false into sAuto
   b2kInputInjectOff
end labBuild

on labStep
   local tWhere, tView
   -- (b2kCamStatus says what is wrong, if the camera could not start)
   if b2kCamStatus() is not empty then
      labSay "The camera did not start:" && b2kCamStatus()
      exit labStep
   end if
   put b2kCamPos() into tView
   put b2kPosition(sPlayer) into tWhere
   labSay "the camera's middle: x" && item 1 of tView & ", y" && item 2 of tView & \
         "   the player: x" && round(item 1 of tWhere) & ", y" && round(item 2 of tWhere) && "(in the world)"
end labStep

-- (the arrow keys are the player's, so the card keeps them)
on arrowKey pKey
end arrowKey

on shake
   b2kCamShake 14, 500
end shake

-- Loose: the camera catches up slowly (0.04 of the way each frame)
on looseCamera
   put not sLoose into sLoose
   if sLoose then
      b2kCamFollow sPlayer, 0.04
   else
      b2kCamFollow sPlayer, 0.15
   end if
end looseCamera

-- Dead zone: the player can move about in a box in the middle before
-- the camera moves
on deadZone
   put not sDeadzone into sDeadzone
   if sDeadzone then
      b2kCamDeadzone 200, 120
   else
      b2kCamDeadzone 0, 0
   end if
end deadZone

-- Run by itself: the Kit can hold keys down for you (b2kInputInject),
-- which is how a demo, or a test, plays a game
on autoRun
   put not sAuto into sAuto
   if sAuto then
      b2kInputInject "right"
   else
      b2kInputInjectOff
   end if
end autoRun

on backToStart
   put false into sAuto
   b2kInputInjectOff
   b2kPlayerRespawn 80, 320
   b2kCamFollow sPlayer
   b2kCamGoto 80, 189
end backToStart

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "autoRun"
         return sAuto
      case "looseCamera"
         return sLoose
      case "deadZone"
         return sDeadzone
   end switch
   return false
end labLit
@*/

/*@ Camera/explain
# What you see
A level four times as wide as the court. Run right with the arrow keys (or press Run by itself): the camera follows the alien.
# How
* b2kCamOn makes the court a window on the world.
* b2kCamBounds says how big the world is.
* b2kCamFollow keeps the player in view.
* b2kCamShake shakes it.
Places are in the world: x goes from 0 to 1600 here, and 0,0 is the court's top left before it scrolls.
# Try
Run to the end. Then Loose, and Dead zone.
@*/

/*@ Camera/try
-- Look at the far end of the level for a moment
b2kCamUnfollow
b2kCamGoto 1400, 189
@*/

/*@ Sound/card
-- 10 Sound: beeps and tunes, made by the script
-- The Kit can make sounds without any sound files. b2kToneMake writes
-- one from a list of notes, given as frequencies in hertz (440 is the
-- A above middle C; 0 is a rest), how long each note lasts, how loud,
-- and the shape of the wave: "sine" is soft, "square" is a retro beep.
-- Then b2kSound plays it by its name. The engine plays one sound at a
-- time: a new one cuts the one that is playing.
--
-- The card plays a "tock" when two things hit each other hard: the Kit
-- sends the card b2kContact when two bodies start to touch.

local sLastTock, sMuted

on labBuild
   local tIndex
   -- 1. The sounds: a name, the notes, milliseconds each, loudness, wave
   b2kToneMake "coin", "988,1319", 70, 50, "square"
   b2kToneMake "jump", "392,523,659", 45, 50, "square"
   b2kToneMake "tock", "220", 35, 40, "sine"
   b2kToneMake "tune", "523,659,784,659,523,0,392,0", 140, 40, "sine"
   put false into sMuted
   b2kSoundMute false
   put 0 into sLastTock
   -- 2. Things to bump
   repeat with tIndex = 1 to 4
      b2kSpawnBall 320 + tIndex * 70, 250, 40, "250,204,21"
      b2kSetBounce the result, 0.7
   end repeat
end labBuild

on labStep
   if b2kSoundStatus() is empty then
      labSay "sound: working" & "   muted:" && sMuted
   else
      labSay "sound: off on this computer (" & b2kSoundStatus() & ")"
   end if
end labStep

-- The Kit sends this when two bodies start to touch (an empty control
-- is a wall). Not more than one tock every tenth of a second
on b2kContact pA, pB
   if the milliseconds - sLastTock > 100 then
      put the milliseconds into sLastTock
      b2kSound "tock"
   end if
end b2kContact

on coin
   b2kSound "coin"
end coin

on jumpAll
   local tBall
   b2kSound "jump"
   repeat for each line tBall in b2kOverlapMoving(270, 162, 680, 602)
      b2kPush tBall, 0, -500
   end repeat
end jumpAll

-- The tune plays round and round until Stop or another sound
on tune
   b2kSoundLoop "tune"
end tune

on stopSound
   b2kSoundStop
end stopSound

on muteSound
   put not sMuted into sMuted
   b2kSoundMute sMuted
end muteSound

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "muteSound"
         return sMuted
   end switch
   return false
end labLit
@*/

/*@ Sound/explain
# What you see
Yellow balls that tock when they land. The buttons play the card's sounds.
# How
* b2kToneMake makes a sound from notes: no sound files.
* b2kSound plays it; b2kSoundLoop plays it over and over.
* b2kSoundStop stops it, b2kSoundMute silences them all.
* The Kit sends b2kContact when two things touch: the card plays a sound then.
# Try
Coin, Jump, then the Tune. Change a note on the Code tab.
@*/

/*@ Sound/try
-- A siren: two notes, again and again
b2kToneMake "siren", "660,880,660,880,660,880", 160, 40, "square"
b2kSound "siren"
@*/

/*@ Contacts/card
-- 11 Contacts and Sensors: who touched what
-- Games need to know when things touch: the ball hit the target, the
-- player reached the coin. After each frame the Kit sends the card:
--
--    b2kContact pA, pB         two bodies started touching
--    b2kSensorEnter pS, pV     something came into a sensor
--
-- A sensor (b2kAddSensor) is a body that nothing bumps into: it only
-- notices. Coins and finish lines are sensors.
--
-- Layers decide what bumps into what. Layers are numbered 1, 2, 4, 8 and
-- so on, and every body starts on layer 1. b2kSetCategory puts a body on
-- a layer; b2kSetMask says which layers it bumps into. The boxes here are
-- on layer 2. The ghost balls bump into layer 1 only: the walls and the
-- other balls, but not the boxes. (The Kit can name layers too, as
-- b2kSetCategory tSlime, "enemies" does: see the Reference.)

local sTouches, sCoins, sGot, sTaken, sBoxes, sLayer

on labBuild
   local tIndex, tObj
   put 0 into sTouches
   put 2 into sLayer
   put 0 into sGot
   put empty into sTaken
   -- 1. Coins: yellow circles that are sensors
   put empty into sCoins
   repeat with tIndex = 1 to 5
      create graphic ("coin" & tIndex)
      put it into tObj
      set the style of tObj to "oval"
      set the opaque of tObj to true
      set the lineSize of tObj to 0
      set the backgroundColor of tObj to "250,204,21"
      set the rect of tObj to 280 + tIndex * 62, 420, 304 + tIndex * 62, 444
      labKeep tObj
      b2kAddSensor tObj, "ball"
      put tObj & return after sCoins
   end repeat
   -- 2. Boxes, on layer 2
   put empty into sBoxes
   repeat with tIndex = 0 to 3
      b2kSpawnBox 360 + tIndex * 80, 560, 50, 50, "56,189,248"
      put the result & return after sBoxes
      b2kSetCategory line -1 of sBoxes, 2
   end repeat
end labBuild

-- Two bodies started touching: count it
on b2kContact pA, pB
   add 1 to sTouches
end b2kContact

-- Something came into a sensor: if the sensor is a coin, it is taken.
-- (The coin goes in labStep: a control is not deleted while the Kit is
-- telling us about it)
on b2kSensorEnter pSensor, pVisitor
   if pSensor is among the lines of sCoins and pSensor is not among the lines of sTaken then
      put pSensor & return after sTaken
      add 1 to sGot
   end if
end b2kSensorEnter

on labStep
   local tCoin
   repeat for each line tCoin in sTaken
      if there is tCoin then
         b2kRemove tCoin
         delete tCoin
      end if
   end repeat
   put empty into sTaken
   labSay "touches so far:" && sTouches & "   touching this frame:" && b2kContactCount() & "   coins:" && sGot && "of 5"
end labStep

-- Drop balls: ordinary ones, which land on the boxes and take coins
on dropBalls
   local tIndex
   repeat with tIndex = 1 to 4
      b2kSpawnBall 320 + random(320), 230, 28, "251,146,60"
   end repeat
end dropBalls

-- Ghosts: balls whose mask is layer 1 only, so they fall through the
-- boxes, which are not on it
on ghosts
   local tIndex
   repeat with tIndex = 1 to 4
      b2kSpawnBall 340 + random(300), 230, 28, "196,181,253"
      b2kSetMask the result, 1
   end repeat
end ghosts

-- Solid boxes: the boxes on layer 1, so ghosts land on them too; again,
-- back on layer 2
on boxesSolid
   local tBox
   if sLayer is 1 then
      put 2 into sLayer
   else
      put 1 into sLayer
   end if
   repeat for each line tBox in sBoxes
      b2kSetCategory tBox, sLayer
   end repeat
end boxesSolid

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "boxesSolid"
         return sLayer is 1
   end switch
   return false
end labLit
@*/

/*@ Contacts/explain
# What you see
Yellow coins, blue boxes, and the balls you drop. Orange balls take the coins; violet ghosts fall through the boxes.
# How
* The Kit sends the card b2kContact when two things touch.
* b2kAddSensor makes a body that only notices: b2kSensorEnter says who came in.
* b2kSetCategory and b2kSetMask decide what bumps into what.
# Try
Drop balls until every coin is taken. Then Ghosts.
@*/

/*@ Contacts/try
-- Twenty balls at once: watch the touches go up
repeat 20
   b2kSpawnBall 300 + random(360), 240, 20, "pink"
end repeat
@*/

/*@ Terrain/card
-- 12 Terrain and Rays: hills, holes, and seeing what is there
-- Ground in a game is rarely flat. b2kSmoothGround makes a smooth
-- ground from a list of points: a chain of lines with no corners for
-- fast things to catch on. It is invisible, so the card draws a graphic
-- with the same points. A chain is solid on one side only: list the
-- points from right to left, and the top is solid.
--
-- b2kKillFloor takes away what falls below a line: here, into the pit.
-- The Kit sends b2kFell before it does.
--
-- A ray (b2kRayHit) is a line the world is asked about: what does it hit
-- first, where, and how far away? Games use rays for lasers, line of
-- sight, and whether a character stands on something. b2kOverlapCircle
-- asks what is inside a circle.

local sFell, sLaser, sBeam, sDot

on labBuild
   local tRight, tLeft
   -- 1. Two hills with a pit between them. Each list runs right to
   --    left; its first and last lines are "ghosts" that only steer the
   --    ends, so each runs one point past the ground you see
   put "700,420" & return & "680,420" & return & "630,470" & return & "580,480" & return & \
         "530,450" & return & "524,610" & return & "520,640" into tRight
   put "470,640" & return & "466,610" & return & "460,440" & return & "400,470" & return & \
         "340,450" & return & "290,450" & return & "270,450" & return & "250,450" into tLeft
   b2kSmoothGround tRight
   b2kSmoothGround tLeft
   drawHill "HillRight", line 2 to -2 of tRight
   drawHill "HillLeft", line 2 to -2 of tLeft
   -- 2. Anything that falls below 570 (into the pit) goes
   b2kKillFloor 570
   put 0 into sFell
   -- 3. The laser's beam and the dot where it hits
   put true into sLaser
   create graphic "Beam"
   put it into sBeam
   set the style of sBeam to "line"
   set the foregroundColor of sBeam to "244,63,94"
   set the lineSize of sBeam to 2
   labKeep sBeam
   create graphic "Dot"
   put it into sDot
   set the style of sDot to "oval"
   set the opaque of sDot to true
   set the lineSize of sDot to 0
   set the backgroundColor of sDot to "244,63,94"
   set the rect of sDot to 0, 0, 10, 10
   labKeep sDot
   dropBalls
end labBuild

-- A hill as a filled shape: its points, then down to the floor
private command drawHill pName, pPoints
   local tObj
   create graphic pName
   put it into tObj
   set the style of tObj to "polygon"
   set the opaque of tObj to true
   set the lineSize of tObj to 0
   set the backgroundColor of tObj to "52,211,153"
   set the points of tObj to pPoints & return & item 1 of line -1 of pPoints & ",602" & return & \
         item 1 of line 1 of pPoints & ",602" & return & line 1 of pPoints
   labKeep tObj
end drawHill

-- Each frame: the laser, from the top left of the court towards the
-- mouse (or down the slope, when the mouse is not in the court), and on
-- for 1000 pixels
on labStep
   local tX, tY, tHit, tWords, tLength
   if the mouseLoc is within the rect of graphic "Court" and the mouseLoc is not "290,240" then
      put the mouseH into tX
      put the mouseV into tY
   else
      put 640 into tX
      put 560 into tY
   end if
   put sqrt((tX - 290) ^ 2 + (tY - 240) ^ 2) into tLength
   put round(290 + (tX - 290) * 1000 / tLength) into tX
   put round(240 + (tY - 240) * 1000 / tLength) into tY
   if not sLaser then
      set the points of sBeam to empty
      hide sDot
      labSay "fell into the pit:" && sFell
      exit labStep
   end if
   put b2kRayHit(290, 240, tX, tY) into tHit
   if b2kRayHitX() is empty then
      set the points of sBeam to "290,240" & return & tX & "," & tY
      hide sDot
      put "the laser hits nothing" into tWords
   else
      set the points of sBeam to "290,240" & return & b2kRayHitX() & "," & b2kRayHitY()
      set the loc of sDot to b2kRayHitX(), b2kRayHitY()
      show sDot
      if tHit is empty then
         put "the laser hits the ground or a wall" into tWords
      else
         put "the laser hits a" && word 1 of tHit into tWords
      end if
      put " at" && b2kRayHitX() & "," & b2kRayHitY() & "," && round(b2kRayDist()) && "pixels away" after tWords
   end if
   labSay tWords & "   fell into the pit:" && sFell
end labStep

-- The Kit sends this just before it takes something below the kill
-- floor away
on b2kFell pControl
   add 1 to sFell
end b2kFell

on dropBalls
   local tIndex
   repeat with tIndex = 1 to 5
      b2kSpawnBall 300 + random(360), 240, 20 + random(16), "251,146,60"
   end repeat
end dropBalls

on dropBoxes
   local tIndex
   repeat with tIndex = 1 to 3
      b2kSpawnBox 300 + random(360), 240, 30, 30, "56,189,248"
   end repeat
end dropBoxes

-- Who is near? Everything inside a circle in the middle of the court
-- jumps
on whoIsNear
   local tObj
   repeat for each line tObj in b2kOverlapCircle(475, 420, 110)
      b2kPush tObj, 0, -400
   end repeat
end whoIsNear

on laser
   put not sLaser into sLaser
end laser

-- Which of the switches is on (the Lab lights its button)
function labLit pHandler
   switch pHandler
      case "laser"
         return sLaser
   end switch
   return false
end labLit
@*/

/*@ Terrain/explain
# What you see
Green hills with a pit between them, and a red laser that follows the mouse. What rolls into the pit is gone.
# How
* b2kSmoothGround makes ground from points; the card draws it.
* b2kKillFloor takes away what falls too far.
* b2kRayHit says what a line hits first, and where.
* b2kOverlapCircle says what is inside a circle.
# Try
Move the mouse over the court. Drop balls, then Who is near?
@*/

/*@ Terrain/try
-- A ball that the laser follows: drop it on the
-- right hill and watch the numbers
b2kSpawnBall 650, 300, 50, "violet"
@*/

/*@ Reference/card
-- Every handler in the Kit: type to find one, click it to read about it.
-- The words are kept in two custom properties of this card, made when
-- the stack was built: cRef holds each handler's usage, what it does
-- and its details, and cUsedIn the lessons that call it.

on openCard
   refFilter
   pass openCard
end openCard

-- Each letter typed in the search box narrows the list
on textChanged
   if the short name of the target is "RefFind" then
      refFilter
   end if
   pass textChanged
end textChanged

on mouseUp
   if the short name of the target is "RefList" and the clickLine is not empty then
      set the hilitedLine of field "RefList" to word 2 of the clickLine
      refExplain the value of the clickLine
   end if
   pass mouseUp
end mouseUp

-- The wheel scrolls the list and the words (65308 down, 65309 up)
on rawKeyDown pKey
   local tField, tStep
   if pKey is 65308 or pKey is 65309 then
      repeat for each item tField in "RefList,RefDoc"
         if the mouseLoc is within the rect of field tField then
            put 54 into tStep
            if pKey is 65309 then
               put -tStep into tStep
            end if
            set the vScroll of field tField to max(0, the vScroll of field tField + tStep)
         end if
      end repeat
      exit rawKeyDown
   end if
   pass rawKeyDown
end rawKeyDown

-- Up and down choose in the list, while you type; the other arrow keys
-- go to the next or last card, unless you are typing
on arrowKey pKey
   local tLine
   if pKey is "up" or pKey is "down" then
      put the hilitedLine of field "RefList" into tLine
      if tLine is empty then
         put 0 into tLine
      end if
      if pKey is "down" then
         put min(tLine + 1, the number of lines of field "RefList") into tLine
      else
         put max(tLine - 1, 1) into tLine
      end if
      if tLine > 0 then
         set the hilitedLine of field "RefList" to tLine
         refExplain line tLine of field "RefList"
      end if
   else if the selectedField is empty then
      pass arrowKey
   end if
end arrowKey

-- The handlers whose name or words have what is in the search box
command refFilter
   local tRef, tFind, tName, tShown, tCount
   put the cRef of this card into tRef
   put field "RefFind" into tFind
   repeat for each line tName in the cNames of this card
      if tFind is empty or tFind is in tName or tFind is in tRef[tName] then
         put tName & return after tShown
         add 1 to tCount
      end if
   end repeat
   delete the last char of tShown
   put tShown into field "RefList"
   put max(0, tCount) && "of" && the number of lines of the cNames of this card && "handlers" into field "RefCount"
end refFilter

-- One handler: how to call it, what it does, its details, and which
-- lessons call it
command refExplain pName
   local tRef, tUsed, tDoc, tText
   put the cRef of this card into tRef
   put the cUsedIn of this card into tUsed
   put tRef[pName] into tDoc
   if tDoc is empty then
      exit refExplain
   end if
   set the itemDelimiter to "|"
   put item 1 of tDoc & return & item 2 of tDoc & return & return & item 3 to -1 of tDoc into tText
   set the itemDelimiter to comma
   replace "\n" with return in tText
   if tUsed[pName] is not empty then
      put return & return & "In the lessons:" && tUsed[pName] after tText
   end if
   put tText into field "RefDoc"
   set the textStyle of line 1 of field "RefDoc" to "bold"
   set the textFont of line 1 of field "RefDoc" to "Courier"
   set the vScroll of field "RefDoc" to 0
end refExplain
@*/

/*@ Start/card
-- The front page: the tiles and the arrows are the window's. A click on
-- "Learn Box2D" opens that example, which is beside this one

on mouseUp
   if the long name of the target contains "group " & quote & "OtherStack" & quote then
      openOther
   else
      pass mouseUp
   end if
end mouseUp

command openOther
   local tPath
   set the itemDelimiter to slash
   put item 1 to -2 of the effective filename of this stack & "/Learn Box2D.oxtstack" into tPath
   set the itemDelimiter to comma
   if there is a file tPath then
      go stack tPath
   else if there is a stack "Learn Box2D" then
      go stack "Learn Box2D"
   else
      answer "Learn Box2D is with the other examples: open it from Home, under Examples."
   end if
end openOther
@*/

/*@ docs
b2kSheetFromImage|Makes a sprite sheet from an image that is in your stack, and gives it a name.
b2kSheetAddFrame|Names one picture inside a sheet, by where it is in the image.
b2kAnimDef|Makes an animation: a list of frames that a sprite shows one after the other.
b2kSpriteNew|Puts a sprite on the card: a picture showing one frame of a sheet.
b2kAddBox|Gives a control a body the shape of its rectangle, so that it takes part in the physics.
b2kAddStatic|Gives a control a body that never moves: a floor, a wall, a platform.
b2kSpriteFrame|Tells you which frame a sprite is showing now.
b2kSheetFrameSize|Tells you how big one frame of a sheet is.
b2kSheetFrames|Tells you how many frames a sheet has.
b2kSpriteSetFrame|Makes a sprite show one frame, and stops any animation it is playing.
b2kSpritePlay|Plays an animation on a sprite.
b2kSpriteFlipH|Mirrors a sprite left to right, so a character faces the other way.
b2kSpriteFlipped|Tells you whether a sprite is mirrored.
b2kPause|Freezes the game: nothing moves until b2kResume.
b2kClear|Takes away everything that moves and every sprite, and keeps the world.
b2kSpawnBall|Makes a ball that falls: a round graphic with a body, where you say, as wide as you say.
b2kSpawnBox|Makes a box that falls: a rectangle graphic with a body, as wide and as high as you say.
b2kSpawnCapsule|Makes a pill shape that falls: a rectangle with round ends, and a body.
b2kBodyCount|Tells you how many bodies there are.
b2kAwakeCount|Tells you how many bodies are still moving. A body that stops falls asleep, and costs nothing.
b2kAddCapsule|Gives a control a pill-shaped body: lying down if the control is wider than it is high, standing up if it is higher.
b2kAddBall|Gives a control a round body, as wide as the control.
b2kAddPolygon|Gives a polygon graphic a body the shape of its own points.
b2kPosition|Tells you where a body's middle is, in pixels on the card.
b2kAngle|Tells you how far a body has turned, in degrees.
b2kMass|Tells you how heavy a body is, in kilograms.
b2kBodyType|Tells you what kind of body it is: static, kinematic or dynamic.
b2kMoveTo|Puts a body somewhere else at once, turned to the angle you give.
b2kSetVelocity|Sets how fast a body goes, across and down, in pixels a second.
b2kSetType|Changes what kind of body it is: static never moves, kinematic moves only at the speed you give it, dynamic falls and gets pushed.
b2kSetDensity|Sets how heavy a body is for its size. Twice the density, twice the mass.
b2kSpeed|Tells you how fast a body is going, in pixels a second.
b2kVelocity|Tells you how fast a body goes across and down, in pixels a second. Up is minus.
b2kSpinRate|Tells you how fast a body is turning, in degrees a second.
b2kPush|Adds to a body's speed, the same for a light body as for a heavy one.
b2kImpulse|Kicks a body. The same kick moves a heavy body less than a light one.
b2kSpin|Makes a body turn, at so many degrees a second.
b2kExplode|A blast: pushes everything near a point away from it.
b2kSetBounce|Sets how bouncy a body is: 0 does not bounce, 1 bounces back as high as it fell.
b2kSetGravity|Changes gravity for the whole world. 0, -10 is like the Earth; 0, -1.6 like the Moon.
b2kSetFriction|Sets how grippy a body is: 0 is ice, 1 is rubber.
b2kHinge|Pins two bodies together at a point, or one body to the world, so that they turn about it.
b2kMotor|Makes a hinge turn by itself, at the speed you give, as hard as you allow.
b2kRope|Keeps two bodies the same distance apart, like a stiff rope between their middles.
b2kSpring|Makes a rope stretchy: how many times a second it bounces, and how soon it settles.
b2kRemoveJoint|Takes a joint away: what it held is free again.
b2kSlider|Lets a body slide along one line only, like a lift in its shaft.
b2kSliderLimit|Sets how far a slider can go each way, in pixels.
b2kSliderMotor|Makes a slider move by itself, at the speed you give.
b2kSliderPos|Tells you how far a slider has moved from where it started, in pixels.
b2kWheel|Puts a wheel on a body, on a springy axle, like a car's.
b2kWheelSpring|Sets how stiff a wheel's springy axle is, and how soon it stops bouncing.
b2kWheelMotor|Makes a wheel turn by itself, so the car drives.
b2kHingeAngle|Tells you how far a hinge has turned, in degrees.
b2kRopeLength|Tells you how long a rope is now, in pixels.
b2kInputOn|Starts the Kit reading the keyboard, once a frame.
b2kInputOff|Stops the Kit reading the keyboard.
b2kBindAxis|Gives two sets of keys one name, such as "move": one set is -1 (left), the other +1 (right).
b2kBindAction|Gives a set of keys one name, such as "jump", so that any of them does it.
b2kAxis|Tells you -1, 0 or 1 for a name made with b2kBindAxis: which way the player is pressing.
b2kActionPressed|Tells you true in the one frame that a named action's key went down.
b2kActionIsDown|Tells you true while any key of a named action is held.
b2kKeysHeld|Tells you every key held down now, by name.
b2kKeyIsDown|Tells you true while a key is held.
b2kKeyPressed|Tells you true in the one frame that a key went down.
b2kSetFixedRotation|Stops a body turning over, so a character stays upright.
b2kSetStatic|Makes a body one that never moves.
b2kOverlapMoving|Tells you every moving body inside a rectangle on the card, one a line.
b2kQuickStart|Makes a world for the whole card, with gravity and walls round it, and starts it. One line.
b2kGrab|Starts dragging the body under the mouse.
b2kRelease|Lets go of a dragged body.
b2kStop|Stops the world, for when the card closes.
b2kWeld|Glues two bodies together, so that they move as one.
b2kSpriteAnim|Tells you the name of the animation a sprite is playing, or empty when it is stopped.
b2kSpriteOnFinish|Asks the Kit to send you a message when an animation that plays once has ended.
b2kSpriteFPS|Changes how many frames a second a sprite's animation shows.
b2kSpriteStop|Stops a sprite's animation on the frame it shows.
b2kSpriteFromGIF|Puts an animated GIF on the card, from a file. The GIF plays by itself.
b2kSheetLoadAtlas|Makes a sheet from two files: a PNG picture, and an XML file that names each frame in it.
b2kSheetFrameNames|Tells you the names of every frame in a sheet, one a line.
b2kSheetScale|Makes a sheet's frames bigger or smaller: 0.5 is half the size.
b2kPlayerMake|Makes the player: a body that the arrow keys move, with a sprite on it.
b2kPlayerAnims|Says which animation shows each thing the player does: standing, running, jumping, ...
b2kPlayerAddWater|Marks a rectangle as water: in it, the player swims.
b2kPlayerAddLadder|Marks a rectangle as a ladder: in it, Up and Down climb.
b2kPlayerState|Tells you what the player is doing: idle, run, jump, fall, duck, climb, swim or hurt.
b2kPlayerOnGround|Tells you true when the player is standing on something.
b2kPlayerFacing|Tells you which way the player faces: 1 is right, -1 is left.
b2kPlayerInWater|Tells you true when the player is in water.
b2kPlayerInLadder|Tells you true when the player is on a ladder.
b2kPlayerSet|Turns one of the player's knobs, such as moveSpeed or jumpSpeed. Empty puts it back.
b2kPlayerHurt|Hurts the player: it jumps back, away from where the hit came from.
b2kPlayerRespawn|Puts the player somewhere, standing still, as if the game had just begun.
b2kCamOn|Turns the camera on: a rectangle of the card becomes a window on a bigger world, whose 0,0 is that rectangle's top left corner.
b2kCamBounds|Tells the camera how big the world is, so that it stops at the edges.
b2kCamAdopt|Puts a control of yours into the camera's world, so that it scrolls with it.
b2kCamFollow|Makes the camera follow a control. A smaller number follows more slowly.
b2kCamUnfollow|Stops the camera following anything.
b2kCamPos|Tells you where the middle of the camera's view is, in the world.
b2kCamShake|Shakes the view: how far, and for how many milliseconds.
b2kCamDeadzone|A box in the middle of the view that the player can move in before the camera follows.
b2kCamGoto|Moves the camera's view to a place in the world at once.
b2kCamMouseX|Tells you where the mouse is across the world, even when the camera has scrolled it.
b2kCamMouseY|Tells you where the mouse is up and down the world, even when the camera has scrolled it.
b2kCamStatus|Tells you why the camera is not working, or nothing when it is.
b2kWall|Puts an invisible line between two points that nothing can pass through.
b2kContact|The Kit sends your card this when two things start to touch. It tells you which two.
b2kSensorEnter|The Kit sends your card this when something comes into a sensor. It tells you the sensor, and what came in.
b2kFell|The Kit sends this just before it takes away something that fell below the kill floor.
b2kFrame|The Kit sends this once a frame, after everything has moved: the place to run your game.
b2kEndContact|The Kit sends your card this when two things stop touching.
b2kSensorExit|The Kit sends your card this when something leaves a sensor.
b2kToneMake|Makes a sound from a list of notes: no sound file needed.
b2kSound|Plays a sound, by its name. It stops the one that was playing.
b2kSoundLoop|Plays a sound over and over, until b2kSoundStop or another sound.
b2kSoundStop|Stops the sound that is playing.
b2kSoundMute|Turns every sound off (true), or on again (false).
b2kSoundStatus|Tells you why sound is not working, or nothing when it is.
b2kAddSensor|Gives a control a body that nothing bumps into: it only notices what comes in.
b2kContactCount|Tells you how many pairs of things started touching in this frame.
b2kSetCategory|Puts a body on a layer: 1, 2, 4, 8 and so on, or a name. Every body starts on layer 1.
b2kSetMask|Says which layers a body bumps into. It passes through the others.
b2kRemove|Takes a body away. If the Kit made the control, the control goes too.
b2kSmoothGround|Makes smooth, invisible ground from a list of points, one "x,y" a line.
b2kKillFloor|Takes away anything that falls below a line, so it does not fall for ever.
b2kRayHit|Asks what a line between two points hits first. It tells you the control, or empty for the ground or a wall.
b2kRayHitX|Tells you across where the last ray hit, or empty when it hit nothing.
b2kRayHitY|Tells you how far down the last ray hit, or empty when it hit nothing.
b2kRayDist|Tells you how far the last ray went before it hit, in pixels.
b2kOverlapCircle|Tells you every body inside a circle, one a line.
b2kInputInject|Holds keys down for you, as if they were pressed, until b2kInputInjectOff: for demos and tests.
b2kInputInjectOff|Goes back to reading the real keyboard.
@*/

/*@ ref
b2kActionIsDown|b2kActionIsDown(name)|Report whether any key of an action is held.|name: The action's name.\nGives back: true or false; false for an action that was never bound.\nReport whether any key of an action is held.
b2kActionPressed|b2kActionPressed(name)|Report whether an action started this frame.|name: The action's name.\nGives back: true on the frame the first of its keys went down.\nReport whether an action started this frame.
b2kActionReleased|b2kActionReleased(name)|Report whether an action ended this frame.|name: The action's name.\nGives back: true on the frame the last of its keys came up.\nReport whether an action ended this frame.
b2kAddBall|b2kAddBall control, dynamic|Give a control a circular body.|control: The control, by reference (the long id of the control is safest).\ndynamic: true (the default) for a dynamic body, false for a static one.\nGives back: The body handle through the result, or 0 when there is no world or the control has no width.\nThe radius is half the control's width. A graphic is redrawn as a circle, an image rotates through its angle, and other controls follow position. The shape starts with density 1, friction 0.4 and bounce 0.4.
b2kAddBox|b2kAddBox control, dynamic|Give a control a box-shaped body matching its rect.|control: The control, by reference (the long id of the control is safest).\ndynamic: true (the default) for a dynamic body, false for a static one.\nGives back: The body handle through the result, or 0 when there is no world or the control has no size.\nA graphic becomes a polygon outline that rotates with its body; a dynamic image rotates through its angle; other controls (buttons, fields) follow position only and have their rotation locked so the simulation matches the upright drawing. The control is drawn at once, even with the loop stopped. The shape starts with density 1, friction 0.4 and bounce 0.2.
b2kAddCapsule|b2kAddCapsule control, dynamic|Give a control a capsule (pill) body.|control: The control, by reference (the long id of the control is safest).\ndynamic: true (the default) for a dynamic body, false for a static one.\nGives back: The body handle through the result, or 0 when there is no world or the control has no size.\nThe longer side of the control's rect is the capsule's axis and the shorter side its diameter. A dynamic graphic is redrawn as a rounded outline that rotates; a dynamic image rotates through its angle; other controls follow position upright.
b2kAddChain|b2kAddChain control, points, loop|Give a control a static chain body from its outline points.|control: The control, by reference (the long id of the control is safest).\npoints: Screen points, one "x,y" per line.\nloop: true to close the outline into a solid blob; anything else leaves an open line.\nGives back: The body handle through the result, or 0 when there is no world.\nUnlike b2kChain the body is registered against the control, so b2kControlAt, b2kMoveTo and b2kRemove treat it like any static part. The points are taken relative to the control's centre. These chains are solid terrain and do not carry the "oneway" layer.
b2kAddGround|b2kAddGround screenY|Add a wide, invisible static floor across the card.|screenY: The floor's screen y in pixels. Empty means 40 px above the card's bottom edge.\nThe floor is a long static segment (1000 m wide), not tracked as a body, so b2kClear keeps it. With no world it does nothing.
b2kAddPolygon|b2kAddPolygon control, dynamic|Give a polygon graphic a body built from its own points.|control: The polygon graphic, by reference. Its points must form a convex outline.\ndynamic: true (the default) for a dynamic body, false for a static one.\nGives back: The body handle through the result, or 0 when there is no world or fewer than 3 points.\nOnly the first 8 points are used, relative to the control's centre. The graphic is redrawn from those points as the body moves and rotates.
b2kAddSensor|b2kAddSensor control, shape|Give a control a static sensor body: it reports overlaps but never blocks.|control: The control, by reference (the long id of the control is safest).\nshape: "box" (the default), "ball" or "capsule".\nGives back: The body handle through the result, or 0 when there is no world or the control has no size.\nEach frame, bodies that entered or left the sensor are reported to the contact target (b2kContactTarget) as b2kSensorEnter and b2kSensorExit, with the sensor control and the visitor control. The frame target does not get them. The Kit enables sensor events on every body it creates, so its bodies are detected. Sensor messages suit one-shot triggers such as coins and goals. For presence (pressure plates) poll b2kOverlapMoving each frame instead.
b2kAddStatic|b2kAddStatic control|Give a control an immovable box body.|control: The control, by reference (the long id of the control is safest).\nThe same as b2kAddBox with pDynamic false.
b2kAddWalls|b2kAddWalls|Add static, invisible walls along the four card edges.|The walls are untracked world bodies, so b2kClear leaves them in place. They are placed for the current scale and origin, so set those first.
b2kAngle|b2kAngle(control)|A body's rotation in degrees.|control: The control, by reference (the long id of the control is safest).\nGives back: The angle in degrees (counter-clockwise positive, not wrapped), or 0 when the control has no body.\nA body's rotation in degrees.
b2kAngularImpulse|b2kAngularImpulse control, impulse|Apply a one-shot, mass-aware turning impulse.|control: The control, by reference (the long id of the control is safest).\nimpulse: The angular impulse, in Box2D units; the sign sets the direction.\nBodies with more rotational inertia turn less. A control with no Kit body is ignored.
b2kAnimDef|b2kAnimDef sheet, anim, frames, fPS, loop|Define a named animation over a sheet's frames.|sheet: The sheet's name.\nanim: The animation's name.\nframes: A comma list of frame names and numbers; a numeric range such as 1-8 expands.\nfPS: Frames per second, clamped to 0.1-120.\nloop: false for a one-shot animation; anything else loops.\nDefine a named animation over a sheet's frames.
b2kAwakeBodyCount|b2kAwakeBodyCount()|How many bodies Box2D has awake.|Gives back: The native count, or 0 with no world.\nIt counts every awake body in the world, including bodies the Kit does not track.
b2kAwakeCount|b2kAwakeCount()|How many non-static Kit bodies are awake.|Gives back: The count, walked over the Kit's own bodies.\nb2kAwakeBodyCount asks Box2D instead and counts bodies the Kit does not track too.
b2kAxis|b2kAxis(name)|Read an axis.|name: The axis's name.\nGives back: -1, 0 or 1. Both directions held, or neither, gives 0.\nRead an axis.
b2kBindAction|b2kBindAction name, keyList|Name a set of keys as one action.|name: The action's name, such as "jump".\nkeyList: A comma list of key names, such as "space,up,w".\nAny bound key counts, and pressed and released treat the set as one key. Keycodes are resolved once, here.
b2kBindAxis|b2kBindAxis name, negKeys, posKeys|Define a -1, 0, +1 axis from two key sets.|name: The axis's name, such as "moveX".\nnegKeys: A comma list of keys for the -1 direction.\nposKeys: A comma list of keys for the +1 direction.\nDefine a -1, 0, +1 axis from two key sets.
b2kBodyCount|b2kBodyCount()|How many bodies the Kit is tracking.|Gives back: The number of controls with a Kit body.\nHow many bodies the Kit is tracking.
b2kBodyOf|b2kBodyOf(control)|The raw Box2D body handle behind a control.|control: The control, by reference (the long id of the control is safest).\nGives back: The body handle, or empty when the control has no Kit body.\nUse it to mix Kit code with calls to the raw b2 layer.
b2kBodyType|b2kBodyType(control)|A body's type as a word.|control: The control, by reference (the long id of the control is safest).\nGives back: "static", "kinematic" or "dynamic"; "static" when the control has no body.\nA body's type as a word.
b2kCamAdopt|b2kCamAdopt ctrl|Move an existing control into the camera's viewport.|ctrl: The control, by reference (the long id of the control is safest).\nFor levels laid out in the IDE. With the camera off it does nothing.
b2kCamApply|b2kCamApply|Write the camera's scroll.|Internal handler: clamps the view to the bounds, adds any shake and sets the group's scroll when it changed.
b2kCamBounds|b2kCamBounds x1, y1, x2, y2|Keep the view inside the level's rectangle.|x1: The level's left, in world pixels.\ny1: The level's top, in world pixels.\nx2: The level's right, in world pixels.\ny2: The level's bottom, in world pixels.\nSet the bounds before b2kCamGoto.
b2kCamDeadzone|b2kCamDeadzone w, h|Set a centre box the target may move in before the camera chases.|w: The box's width in pixels; 0 always centres.\nh: The box's height in pixels; 0 always centres.\nSet a centre box the target may move in before the camera chases.
b2kCamFollow|b2kCamFollow ctrl, lerp|Make the camera follow a control.|ctrl: The control, by reference (the long id of the control is safest).\nlerp: Optional smoothing, 0.01 to 1 (1 snaps). The default is 0.15.\nThe camera eases toward the control, and snaps when the control would leave the view.
b2kCamGoto|b2kCamGoto x, y|Cut the view to a world point.|x: The new view centre x, in world pixels.\ny: The new view centre y, in world pixels.\nThe point is clamped to the bounds and applied at once.
b2kCamGroup|b2kCamGroup()|The camera's viewport group.|Gives back: The group's long id, or empty when the camera is off.\nCreate your own level controls inside it so they scroll.
b2kCamIsOn|b2kCamIsOn()|Report whether the camera is on.|Gives back: true or false.\nReport whether the camera is on.
b2kCamLocSemantics|b2kCamLocSemantics()|Which grouped-location model this engine uses.|Gives back: "visual" when grouped controls report scroll-adjusted locations, else "content".\nA diagnostic from the probe b2kCamOn runs; the Kit compensates either way.
b2kCamMouseX|b2kCamMouseX()|The mouse's x in world pixels.|Gives back: The mouse x adjusted for the camera scroll; the plain mouseH when the camera is off.\nThe mouse's x in world pixels.
b2kCamMouseY|b2kCamMouseY()|The mouse's y in world pixels.|Gives back: The mouse y adjusted for the camera scroll; the plain mouseV when the camera is off.\nThe mouse's y in world pixels.
b2kCamOff|b2kCamOff|Turn off the camera.|The viewport is dissolved and its controls return to the card with their world locations. b2kTeardown calls it.
b2kCamOn|b2kCamOn rect|Turn on the scrolling camera.|rect: The viewport rect on the card. Empty means the card's rect.\nIt creates a clipped viewport group the loop scrolls. While it is on, controls the Kit creates go inside it and keep world-pixel locations. Turn it on before building the level, after any static backdrop. Check b2kCamStatus afterwards: a failure is reported there, not thrown.
b2kCamPos|b2kCamPos()|The view's centre.|Gives back: "x,y" in world pixels.\nThe view's centre.
b2kCamShake|b2kCamShake ampPx, ms|Shake the view for a moment.|ampPx: The shake size in pixels, 0-200.\nms: How long it lasts, in milliseconds, 0-5000.\nShake the view for a moment.
b2kCamShiftX|b2kCamShiftX(ref)|The horizontal scroll to subtract when placing a control in the viewport.|ref: The control's long id.\nGives back: The scroll in pixels on a visual-model engine for a control inside the viewport, else 0.\nb2kSpriteMoveTo and the renderer apply it for you.
b2kCamShiftY|b2kCamShiftY(ref)|The vertical scroll to subtract when placing a control in the viewport.|ref: The control's long id.\nGives back: The scroll in pixels on a visual-model engine for a control inside the viewport, else 0.\nThe vertical scroll to subtract when placing a control in the viewport.
b2kCamStatus|b2kCamStatus()|Why the camera is not working, if it is not.|Gives back: Empty when healthy (or off), otherwise the reason.\nWhy the camera is not working, if it is not.
b2kCamTick|b2kCamTick|Run one frame of the camera.|Internal handler: the loop calls it each frame. It chases the followed control, then applies the view with b2kCamApply, and forces the scroll if the target ever ends up outside the view.
b2kCamUnfollow|b2kCamUnfollow|Stop the camera following.|Stop the camera following.
b2kCapsuleVerts|b2kCapsuleVerts(l, r, horiz)|The local outline the Kit draws a capsule with.|l: The capsule's half-length, in metres.\nr: The radius, in metres.\nhoriz: true for a horizontal capsule, false for vertical.\nGives back: 18 local points in metres, one "x,y" per line.\nDrawing only: the collision shape is a true capsule.
b2kChain|b2kChain points, loop|Build smooth static terrain from a list of screen points.|points: Screen points, one "x,y" per line. At least 4 points.\nloop: true to close the chain into a loop; anything else leaves it open.\nGives back: The chain handle through the result, or 0 when there is no world.\nA chain has no inner corners for fast bodies to catch on. It is invisible (draw a graphic to match) and one-sided: the solid side is to the right of the direction the points run, so list a floor's top surface right to left. On an open chain the first and last segments are ghost anchors that do not collide, so run the chain one segment past the surface you need at each end. Every Kit chain carries the reserved "oneway" layer, which lets the player drop through it. It is not a tracked body, so b2kClear leaves it.
b2kClamp|b2kClamp(value, lo, hi)|Clamp a value into a range.|value: The value to clamp. Empty or not a number counts as the low bound.\nlo: The lower bound.\nhi: The upper bound.\nGives back: The value limited to the range from the low to the high bound.\nClamp a value into a range.
b2kClear|b2kClear|Remove every moving body and every sprite, keeping the world.|Use b2kClear to reset a scene without rebuilding the world. Every non-static Kit body is removed with b2kRemove (controls the Kit spawned are deleted, attached controls are only detached), sprites are removed, and the player controller's state and ladder and water zones are dropped. Player tuning, input bindings, loaded sheets, sounds, static bodies, walls and chains stay.
b2kCodesInSet|b2kCodesInSet(set, codes)|Report whether any of a list of keycodes is in a comma-wrapped set.|set: A set of keycodes wrapped in commas.\ncodes: A comma list of keycodes.\nGives back: true when any code is in the set; false for an empty set.\nA helper behind the action and axis queries.
b2kContactA|b2kContactA(index)|The first control of a pair that began touching this frame.|index: The 1-based index of the event within this frame.\nGives back: The control's long id, or empty for a wall, the ground, an untracked body or an index out of range.\nThe first control of a pair that began touching this frame.
b2kContactB|b2kContactB(index)|The second control of a pair that began touching this frame.|index: The 1-based index of the event within this frame.\nGives back: The control's long id, or empty for a wall, the ground, an untracked body or an index out of range.\nThe second control of a pair that began touching this frame.
b2kContactCount|b2kContactCount()|How many pairs of bodies began touching this frame.|Gives back: The count, 0 when none.\nPoll it from b2kFrame instead of, or alongside, the b2kContact message. Events are collected after every fixed step of the frame, so none is lost on a two-step frame or repeated on a zero-step one.
b2kContactTarget|b2kContactTarget object|Set the object that receives contact and sensor messages.|object: A reference to the object, such as the long id of the card. Empty turns the messages off.\nAfter each frame the Kit sends this object b2kContact and b2kEndContact (two controls that began or stopped touching), and b2kSensorEnter and b2kSensorExit (a sensor control and a visitor control). A control parameter is empty for a wall, the ground or any body the Kit does not track. Without a target no message is sent; the polling functions such as b2kContactCount work either way.
b2kControlAt|b2kControlAt(screenX, screenY)|The Kit control whose body covers a screen point.|screenX: The point's x, in pixels.\nscreenY: The point's y, in pixels.\nGives back: The control's long id, or empty when no Kit body is there.\nWith the camera on, pass world pixels from b2kCamMouseX and b2kCamMouseY.
b2kControlContains|b2kControlContains(control, screenX, screenY)|Report whether a screen point is inside one control's collision shape.|control: The control, by reference (the long id of the control is safest).\nscreenX: The point's x, in pixels.\nscreenY: The point's y, in pixels.\nGives back: true when the point is inside the shape (rotation and shape aware); false otherwise or when the control has no shape.\nReport whether a screen point is inside one control's collision shape.
b2kCorner|b2kCorner(wx, wy, lx, ly, c, s)|One outline corner in screen pixels.|wx: The body's x, in metres.\nwy: The body's y, in metres.\nlx: The corner's local x, in metres.\nly: The corner's local y, in metres.\nc: The cosine of the body's angle.\ns: The sine of the body's angle.\nGives back: "x,y" in rounded screen pixels.\nOne outline corner in screen pixels.
b2kDamping|b2kDamping(control)|A body's linear and angular damping.|control: The control, by reference (the long id of the control is safest).\nGives back: "linear,angular", or "0,0" when the control has no body.\nA body's linear and angular damping.
b2kDefineLayer|b2kDefineLayer name|Define or look up a named collision layer.|name: The layer's name.\nGives back: The layer's bit value through the result, or 0 when all 31 nameable layers are taken.\nLayers are handed out from bit 1 up to bit 2^30. The top bit, 2^31, is the Kit's reserved "oneway" layer for chains; it can be named in a list but is never handed out. You rarely need to call this yourself: the layer lists of b2kSetCategory and b2kSetMask define names as they meet them.
b2kDisable|b2kDisable control|Take a body out of the simulation.|control: The control, by reference (the long id of the control is safest).\nA disabled body has no gravity and no collisions and its control stays where it is. Move it out of the way first if it should vanish. A control with no Kit body is ignored.
b2kDispatchContacts|b2kDispatchContacts|Send this frame's contact messages.|Internal handler: sends b2kContact and b2kEndContact to the contact target, in step order. No target, no messages.
b2kDispatchSensors|b2kDispatchSensors|Send this frame's sensor messages.|Internal handler: sends b2kSensorEnter and b2kSensorExit to the contact target, in step order. No target, no messages.
b2kDrawBall|b2kDrawBall ref, wx, wy|Redraw a ball graphic at a body position.|ref: The control's long id.\nwx: The body's x, in metres.\nwy: The body's y, in metres.\nInternal handler: sets the graphic's rect from the stored radius.
b2kDrawBody|b2kDrawBody ref, wx, wy, wa|Place a control at a body pose.|ref: The control's long id.\nwx: The body's x, in metres.\nwy: The body's y, in metres.\nwa: The body's angle, in radians.\nInternal handler: picks the renderer for the control's kind and skips the write when nothing visible changed.
b2kDrawImage|b2kDrawImage ref, wx, wy, wa|Move and rotate an image to a body pose.|ref: The control's long id.\nwx: The body's x, in metres.\nwy: The body's y, in metres.\nwa: The body's angle, in radians.\nInternal handler: sets the image's angle in whole degrees and its location; the image keeps its design size.
b2kDrawPoly|b2kDrawPoly ref, wx, wy, wa|Redraw a polygon graphic at a body pose.|ref: The control's long id.\nwx: The body's x, in metres.\nwy: The body's y, in metres.\nwa: The body's angle, in radians.\nInternal handler: re-points the graphic from its stored outline.
b2kEdge|b2kEdge wx1, wy1, wx2, wy2|Add a static segment between two points given in world metres.|wx1: X of the first point, in metres.\nwy1: Y of the first point, in metres (y up).\nwx2: X of the second point, in metres.\nwy2: Y of the second point, in metres (y up).\nInternal handler: b2kWall and b2kAddWalls build their segments with it. With no world it is a quiet no-op. Most scripts want b2kWall, which takes screen pixels.
b2kEnableContinuous|b2kEnableContinuous flag|Turn continuous collision (CCD) on or off for the world.|flag: true to stop fast bodies tunnelling through static walls, false to turn it off.\nUse b2kSetBullet for continuous collision between moving bodies.
b2kEnableSleeping|b2kEnableSleeping flag|Turn island sleeping on or off for the whole world.|flag: true to let resting bodies sleep, false to keep them all awake.\nSleeping saves CPU when bodies rest, and it is on by default. Use b2kSetSleepEnabled to change it for one body.
b2kEnableWarmStarting|b2kEnableWarmStarting flag|Turn the solver's warm starting on or off.|flag: true to reuse the last step's solution (the default), false to turn it off.\nWarm starting makes stacks faster and more stable. With no world it does nothing.
b2kEnable|b2kEnable control|Put a disabled body back into the simulation.|control: The control, by reference (the long id of the control is safest).\nA control with no Kit body is ignored.
b2kEndContactA|b2kEndContactA(index)|The first control of a pair that stopped touching this frame.|index: The 1-based index of the event within this frame.\nGives back: The control's long id, or empty for a wall, the ground, an untracked body or an index out of range.\nThe first control of a pair that stopped touching this frame.
b2kEndContactB|b2kEndContactB(index)|The second control of a pair that stopped touching this frame.|index: The 1-based index of the event within this frame.\nGives back: The control's long id, or empty for a wall, the ground, an untracked body or an index out of range.\nThe second control of a pair that stopped touching this frame.
b2kEndContactCount|b2kEndContactCount()|How many pairs of bodies stopped touching this frame.|Gives back: The count, 0 when none.\nEvents are collected after every fixed step of the frame, so none is lost on a two-step frame or repeated on a zero-step one.
b2kEnsureNativeLib|b2kEnsureNativeLib|Point the engine at a box2dxt library saved beside the stack.|When a file named box2dxt.dll, box2dxt.dylib or box2dxt.so (by platform) sits in the folder of the saved stack, b2kEnsureNativeLib sets the revLibraryMapping for "box2dxt" to it, so the extension's foreign handlers resolve with no install. Otherwise it leaves the engine's own search alone. An unsaved stack is a quiet no-op. b2kSetup calls it for you. Scripts that use the raw b2 layer without the Kit can call it before their first b2 call.
b2kEventsReset|b2kEventsReset|Zero this frame's event counts.|Internal handler: the loop calls it before stepping. The event readers check the counts, so old entries are never returned.
b2kExplodeLegacy|b2kExplodeLegacy screenX, screenY, radiusPx, powerPx|The older velocity-based blast, for Kit bodies only.|screenX: The blast centre x, in pixels.\nscreenY: The blast centre y, in pixels.\nradiusPx: The reach in pixels. Empty means 180.\npowerPx: The speed added at the centre, falling to 0 at the edge. Empty means 900.\nIt adds velocity directly to every non-static Kit body in range, ignoring size and mass. Kept for scripts that relied on that feel; new code should use b2kExplode.
b2kExplode|b2kExplode screenX, screenY, radiusPx, powerPx|Push dynamic bodies away from a point with a radial blast.|screenX: The blast centre x, in pixels.\nscreenY: The blast centre y, in pixels.\nradiusPx: The reach in pixels. Empty means 180.\npowerPx: The impulse per unit of facing surface, scaled by the Kit's pixels per metre. Empty means 900.\nIt uses Box2D's own explosion, which is shape-aware (a wide plank catches more than a small ball) and affects every dynamic body in range, not only Kit bodies. With no world it does nothing.
b2kForce|b2kForce control, fxPx, fyPx|Apply a continuous force to a body's centre.|control: The control, by reference (the long id of the control is safest).\nfxPx: Horizontal force, scaled by the Kit's pixels per metre (positive is right).\nfyPx: Vertical force, scaled the same way (positive is down).\nA force acts for one step, so call it every frame (from b2kFrame) for thrust or wind. It wakes the body. A control with no Kit body is ignored.
b2kFrameMS|b2kFrameMS()|The real time the last frame covered.|Gives back: Milliseconds, or 0 before the first frame. A hand step counts as one 1/60 s step.\nDrive animations and game timers from this, not the frame count: a frame may run zero, one or several fixed physics steps.
b2kFrameTarget|b2kFrameTarget object|Set the object that receives a b2kFrame message every frame.|object: A reference to the object, such as the long id of the card. Empty turns the message off.\nThe Kit sends b2kFrame once per simulated frame, after bodies, input, the player, sprites and the camera have updated. Put per-frame game logic there. The same object receives b2kFell (b2kKillFloor) and sprite finish messages (b2kSpriteOnFinish). An error inside b2kFrame is caught silently so the screen never stays locked; the rest of that frame's work is skipped.
b2kGrab|b2kGrab(screenX, screenY)|Start dragging the dynamic body under a screen point.|screenX: The point's x, in pixels.\nscreenY: The point's y, in pixels.\nGives back: The grabbed control, or empty when no dynamic body is there.\nCall it from mouseDown and b2kRelease from mouseUp. While a body is held, the loop pulls it toward the mouse each frame with a mouse joint. With the camera on, pass b2kCamMouseX and b2kCamMouseY.
b2kGravityScale|b2kGravityScale(control)|A body's gravity multiplier.|control: The control, by reference (the long id of the control is safest).\nGives back: The gravity scale, or 0 when the control has no body.\nA body's gravity multiplier.
b2kHarvestEvents|b2kHarvestEvents|Collect the last step's contact and sensor events.|Internal handler: runs after every fixed step, because Box2D keeps only the latest step's events.
b2kHingeAngle|b2kHingeAngle(joint)|A hinge joint's current angle.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nGives back: The angle in degrees, or 0 for an empty or 0 handle.\nA hinge joint's current angle.
b2kHingeLimitOff|b2kHingeLimitOff joint|Remove a hinge joint's angle limits.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nRemove a hinge joint's angle limits.
b2kHingeLimit|b2kHingeLimit joint, lowerDeg, upperDeg|Limit a hinge joint's angle.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nlowerDeg: The lowest angle in degrees.\nupperDeg: The highest angle in degrees.\nAngles are measured from the pose the bodies had when the hinge was made.
b2kHinge|b2kHinge ctrlA, ctrlB, screenX, screenY|Pin two controls together, or one to the world, at a screen point.|ctrlA: The control, by reference (the long id of the control is safest).\nctrlB: The second control, or empty to pin the first to the world.\nscreenX: The pivot x, in pixels.\nscreenY: The pivot y, in pixels.\nGives back: The joint handle through the result, or 0 when a control has no body or there is no world.\nA revolute joint: the bodies keep the pivot point in common and rotate freely about it. Good for pendulums, doors and wheels on a fixed axle.
b2kImpulse|b2kImpulse control, ixPx, iyPx|Apply a one-shot, mass-aware impulse to a body's centre.|control: The control, by reference (the long id of the control is safest).\nixPx: Horizontal impulse, scaled by the Kit's pixels per metre (positive is right).\niyPx: Vertical impulse, scaled the same way (positive is down).\nHeavier bodies move less. It wakes the body. A control with no Kit body is ignored.
b2kInputInjectOff|b2kInputInjectOff|Return to reading the real keyboard.|Return to reading the real keyboard.
b2kInputInject|b2kInputInject keys|Replace the keyboard with a scripted set of held keys.|keys: A comma list of key names or codes to hold; empty holds nothing.\nUntil b2kInputInjectOff, each frame's sample reads this set instead of the keyboard, and pressed and released edges come from the normal frame comparison. For tests, input replays and scripted characters.
b2kInputIsOn|b2kInputIsOn()|Report whether the keyboard sample is on.|Gives back: true or false.\nReport whether the keyboard sample is on.
b2kInputOff|b2kInputOff|Turn off the per-frame keyboard sample.|Every key reads as up afterwards. Bindings are kept.
b2kInputOn|b2kInputOn|Turn on the per-frame keyboard sample.|Each frame the loop reads the keys held down and compares them with the previous frame, so the key, action and axis queries work from b2kFrame. No focus or key messages are needed. It also fills empty bindings: action "jump" (space), action "dash" (shift, x), axis "moveX" (left, a / right, d) and axis "moveY" (up, w / down, s). Your own bindings are kept.
b2kInputTick|b2kInputTick|Take this frame's keyboard sample.|Internal handler: the loop and b2kStepOnce call it once per frame. The current key set becomes the previous one and a new set is read from the keyboard, or from the injected keys. A no-op while input is off.
b2kIsAwake|b2kIsAwake(control)|Report whether a body is awake.|control: The control, by reference (the long id of the control is safest).\nGives back: true or false; false when the control has no body.\nReport whether a body is awake.
b2kIsBullet|b2kIsBullet(control)|Report whether a body uses continuous (bullet) collision.|control: The control, by reference (the long id of the control is safest).\nGives back: true or false; false when the control has no body.\nReport whether a body uses continuous (bullet) collision.
b2kIsEnabled|b2kIsEnabled(control)|Report whether a body is in the simulation.|control: The control, by reference (the long id of the control is safest).\nGives back: true or false; false when the control has no body.\nReport whether a body is in the simulation.
b2kIsRunning|b2kIsRunning()|Report whether the loop is running and not paused.|Gives back: true while the loop is stepping; false when stopped or paused.\nReport whether the loop is running and not paused.
b2kKeyCodes|b2kKeyCodes(key)|The keycodes a key name matches.|key: A key name (left, right, up, down, space, return, escape, tab, shift, control, alt, backspace, delete), a single character, or a raw keycode.\nGives back: A comma list of keycodes. A letter gives both cases; a number of 32 or more is returned as is; an unknown name gives 0.\nThe keycodes a key name matches.
b2kKeyInSet|b2kKeyInSet(set, key)|Report whether a key is in a comma-wrapped keycode set.|set: A set of keycodes wrapped in commas, such as ",65361,32,".\nkey: A key name (left, right, up, down, space, return, escape, tab, shift, control, alt, backspace, delete), a single character, or a raw keycode.\nGives back: true when any of the key's codes is in the set; false for an empty set.\nA helper behind b2kKeyIsDown, b2kKeyPressed and b2kKeyReleased.
b2kKeyIsDown|b2kKeyIsDown(key)|Report whether a key is held this frame.|key: A key name (left, right, up, down, space, return, escape, tab, shift, control, alt, backspace, delete), a single character, or a raw keycode.\nGives back: true or false.\nNeeds b2kInputOn; read it from b2kFrame.
b2kKeyListCodes|b2kKeyListCodes(keyList)|Every keycode a comma list of key names matches.|keyList: A comma list of key names or codes.\nGives back: A comma list of keycodes.\nA helper the bind commands use.
b2kKeyName|b2kKeyName(code)|The friendly name of a keycode.|code: A keycode.\nGives back: The key's name, a lower-case letter or digit, or the code itself when it has no name.\nThe friendly name of a keycode.
b2kKeyPressed|b2kKeyPressed(key)|Report whether a key went down this frame.|key: A key name (left, right, up, down, space, return, escape, tab, shift, control, alt, backspace, delete), a single character, or a raw keycode.\nGives back: true only on the frame the key went down.\nReport whether a key went down this frame.
b2kKeyReleased|b2kKeyReleased(key)|Report whether a key came up this frame.|key: A key name (left, right, up, down, space, return, escape, tab, shift, control, alt, backspace, delete), a single character, or a raw keycode.\nGives back: true only on the frame the key came up.\nReport whether a key came up this frame.
b2kKeysHeld|b2kKeysHeld()|Every key held this frame, by name.|Gives back: The names separated by spaces, or empty.\nHandy for a debug display.
b2kKillFloor|b2kKillFloor screenY|Remove moving Kit bodies whose centre falls below a screen line.|screenY: The screen y in pixels below which moving bodies are removed. Empty turns the kill floor off.\nCrates pushed into pits and enemies knocked off a level are removed instead of falling forever. The player controller's body is exempt; your game owns its respawn. Before each removal the Kit sends the message b2kFell, with the control as its parameter, to the frame target (b2kFrameTarget). Use it to clean up companions such as bound sprites, but do not delete the control in that handler, because the Kit is removing it.
b2kLayerBits|b2kLayerBits(layerList)|Turn a list of layer names into a bitmask.|layerList: A comma or space separated list of layer names or raw numbers.\nGives back: The combined bit value.\nUnknown names are defined on the way (b2kDefineLayer); "oneway" is bit 2^31.
b2kLE16|b2kLE16(n)|Pack a number as two little-endian bytes.|n: A whole number from 0 to 65535.\nGives back: Two bytes.\nPack a number as two little-endian bytes.
b2kLE32|b2kLE32(n)|Pack a number as four little-endian bytes.|n: A whole number from 0 to 4294967295.\nGives back: Four bytes.\nPack a number as four little-endian bytes.
b2kLocalAnchor|b2kLocalAnchor(body, wx, wy)|Convert a world point to a raw body's local frame.|body: A raw body handle (see b2kBodyOf).\nwx: The world x, in metres.\nwy: The world y, in metres.\nGives back: "lx,ly" in metres in the body's local frame.\nA helper the joint constructors use to place anchors.
b2kMass|b2kMass(control)|A body's mass.|control: The control, by reference (the long id of the control is safest).\nGives back: The mass in Box2D units (kilograms), or 0 when the control has no body.\nA body's mass.
b2kMotorOff|b2kMotorOff joint|Turn a hinge joint's motor off.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nThe hinge swings freely again.
b2kMotorTo|b2kMotorTo mover, ref, offsetXPx, offsetYPx, angleDeg, maxForce, maxTorque|Drive a control toward a pose offset from another control or the world.|mover: The control to drive, by reference.\nref: The control the offset is measured from, or empty for the world.\noffsetXPx: The target x offset, in pixels.\noffsetYPx: The target y offset, in pixels (positive is down).\nangleDeg: The target angle offset in degrees. Empty means 0.\nmaxForce: The most force the joint may use. Empty means 1000.\nmaxTorque: The most torque the joint may use. Empty means 1000.\nGives back: The joint handle through the result, or 0 when a control has no body or there is no world.\nA motor joint, good for followers and lifts. Remove it with b2kRemoveJoint.
b2kMotor|b2kMotor joint, degPerSec, maxTorque|Drive a hinge joint at a set speed.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\ndegPerSec: The target speed in degrees per second.\nmaxTorque: The most torque the motor may use. Empty means 1000.\nDrive a hinge joint at a set speed.
b2kMoveTo|b2kMoveTo control, screenX, screenY, angleDeg|Teleport a body to a screen point and angle.|control: The control, by reference (the long id of the control is safest).\nscreenX: The new centre x, in pixels.\nscreenY: The new centre y, in pixels.\nangleDeg: The new angle in degrees. Empty means 0.\nThe control is redrawn at once. Velocity is kept; follow it with b2kSetVelocity to stop the body. A control with no Kit body is ignored.
b2kNoCollide|b2kNoCollide ctrlA, ctrlB|Stop two controls colliding with each other.|ctrlA: The control, by reference (the long id of the control is safest).\nctrlB: The second control, by reference.\nGives back: The joint handle through the result, or 0 when a control has no body or there is no world.\nA filter joint: only this pair stops colliding; each still collides with everything else. Remove it with b2kRemoveJoint.
b2kNumberOr|b2kNumberOr(value, default)|Return a value when it is a number, else a default.|value: The value to test.\ndefault: What to return when the value is empty or not a number.\nGives back: The value, or the default.\nA small helper the Kit uses to make optional arguments safe.
b2kOverlapCircle|b2kOverlapCircle(x, y, radiusPx)|The Kit controls whose bodies overlap a screen circle.|x: The centre x, in pixels.\ny: The centre y, in pixels.\nradiusPx: The radius, in pixels.\nGives back: The controls' long ids, one per line, or empty.\nThe Kit controls whose bodies overlap a screen circle.
b2kOverlapMoving|b2kOverlapMoving(x1, y1, x2, y2)|The non-static Kit controls overlapping a screen rectangle.|x1: One corner's x, in pixels.\ny1: One corner's y, in pixels.\nx2: The other corner's x, in pixels.\ny2: The other corner's y, in pixels.\nGives back: The controls' long ids, one per line, or empty.\nThe presence poll for pressure plates and buttons: static bodies are filtered out, dynamic and kinematic bodies count, and sleeping bodies still register.
b2kOverlap|b2kOverlap(x1, y1, x2, y2)|The Kit controls whose bodies overlap a screen rectangle.|x1: One corner's x, in pixels.\ny1: One corner's y, in pixels.\nx2: The other corner's x, in pixels.\ny2: The other corner's y, in pixels.\nGives back: The controls' long ids, one per line, or empty.\nIt asks Box2D's broadphase, whose boxes are slightly enlarged (about 0.1 m, a few pixels), so a rectangle touching the floor reports the floor. Use b2kOverlapMoving for presence checks.
b2kPause|b2kPause|Freeze stepping without stopping the loop.|While paused, the loop keeps running but no physics step, sync or frame message happens. b2kStepOnce still advances one step.
b2kPlayerAddLadder|b2kPlayerAddLadder x1, y1, x2, y2|Register a ladder zone.|x1: One corner's x, in pixels.\ny1: One corner's y, in pixels.\nx2: The other corner's x, in pixels.\ny2: The other corner's y, in pixels.\nWhile the player's centre is inside, UP starts a climb (DOWN too when airborne): gravity stops, y moves at climbSpeed and x at half speed, and JUMP leaves with a normal jump. Zones are plain rectangles with no physics; b2kClear removes them. Start the zone a little above the platform at the ladder's top. Corners that are not numbers are ignored.
b2kPlayerAddWater|b2kPlayerAddWater x1, y1, x2, y2|Register a water (swim) zone.|x1: One corner's x, in pixels.\ny1: One corner's y, in pixels.\nx2: The other corner's x, in pixels.\ny2: The other corner's y, in pixels.\nWhile the player's centre is inside, it swims: gravity drops to swimGravity, sinking is capped at swimMaxFall, UP and DOWN move at swimSpeed, and each JUMP press is an upward stroke. Zones have no physics; b2kClear removes them. Top the zone a little above the drawn water surface.
b2kPlayerAnims|b2kPlayerAnims idle, run, jump, fall, land, duck, climb, hurt, swim, wall, dash|Map the controller's states to the art's animation names.|idle: Animation for standing still.\nrun: Animation for running.\njump: Animation for rising.\nfall: Optional animation for falling. Empty uses the jump animation.\nland: Optional one-shot touch-down animation, held for its own length.\nduck: Optional crouch animation. Empty uses idle.\nclimb: Optional ladder animation. Empty uses jump.\nhurt: Optional knockback animation. Empty uses jump.\nswim: Optional swim animation. Empty uses the fall animation.\nwall: Optional wall-slide animation. Empty uses the fall animation.\ndash: Optional dash animation. Empty uses run.\nThe controller then plays these on the player's art and flips it to face the way it moves. If your game uses b2kSpriteOnFinish on the player's art, map a looping animation to hurt: a one-shot hurt pose fires the finish message mid-knockback.
b2kPlayerAttach|b2kPlayerAttach ctrl|Make an existing control the player.|ctrl: The control, by reference (the long id of the control is safest).\nA control without a body gets a capsule body with low friction (0.08) and no bounce; a body you made yourself keeps its material. The body gets fixed rotation and is never allowed to sleep, and input is turned on. There is one player at a time: attaching another replaces the controller's state, and the old body and sprite stay. With no world it does nothing.
b2kPlayerClimbEnd|b2kPlayerClimbEnd body|End the climb's gravity hold.|body: The player's raw body handle, b2kBodyOf(b2kPlayer()).\nInternal handler: restores the saved gravity scale. Without a start it is a no-op.
b2kPlayerClimbStart|b2kPlayerClimbStart body|Start the climb's gravity hold.|body: The player's raw body handle, b2kBodyOf(b2kPlayer()).\nInternal handler: saves the body's gravity scale and sets it to 0. A repeated start is a no-op.
b2kPlayerControl|b2kPlayerControl flag|Give the controller control of the player, or make it only observe.|flag: false to observe only; anything else gives control back.\nWhile observing, ground, state and facing stay fresh but the controller writes no velocity and no animation (the maxFall limit still applies); use it for cutscenes and scripted poses. Either call cancels a knockback in progress with no mercy window. Giving control back re-applies the state's animation.
b2kPlayerDashEnd|b2kPlayerDashEnd body|End a dash.|body: The player's raw body handle, b2kBodyOf(b2kPlayer()).\nInternal handler: restores the saved gravity scale. Without a start it is a no-op.
b2kPlayerDashStart|b2kPlayerDashStart body|Start a dash.|body: The player's raw body handle, b2kBodyOf(b2kPlayer()).\nInternal handler: saves the gravity scale and sets it to 0, and starts the dash timer and cooldown in the facing direction. A repeated start is a no-op.
b2kPlayerDefault|b2kPlayerDefault(key)|The shipped default of a player tuning knob.|key: The knob's name in lower case, such as "jumpspeed".\nGives back: The default value, or empty for a knob the controller does not know.\nThe defaults suit a 32 by 48 px player at scale 40: moveSpeed 220, jumpSpeed 460, maxFall 900, and so on. The opt-in actions default to off. b2kPlayerGet lower-cases its key for you; this does not.
b2kPlayerDropRestore|b2kPlayerDropRestore|Close the drop-through window.|Internal handler: puts back the mask b2kPlayerDropStart saved.
b2kPlayerDropStart|b2kPlayerDropStart|Open the drop-through window.|Internal handler: takes the reserved one-way bit (2^31) out of the player's collision mask, so one-way chains alone stop colliding, for dropMs.
b2kPlayerDuckSet|b2kPlayerDuckSet wantDuck|Shrink the player to a crawl, or stand up when there is room.|wantDuck: true to crawl; anything else stands up if a ray finds headroom.\nOnly active when duckScale is below 1 (the default is 1, a no-op). The capsule is rebuilt shorter with the feet planted, keeping its collision filter, with friction 0.08 and no bounce.
b2kPlayerFacing|b2kPlayerFacing()|Which way the player faces.|Gives back: 1 for right, -1 for left (the last horizontal input).\nWhich way the player faces.
b2kPlayerForget|b2kPlayerForget full|Drop the controller's state.|full: true to drop the tuning knobs too.\nInternal handler: b2kClear passes false and b2kTeardown and b2kPlayerRemove pass true. A climb, swim, dash or drop in progress is ended first so the body gets its gravity and mask back. Ladder and water zones go either way.
b2kPlayerGet|b2kPlayerGet(key)|Read a player tuning knob.|key: The knob's name (case does not matter).\nGives back: The knob's value, or its default when unset. A known knob set to a non-number reads as its default.\nRead a player tuning knob.
b2kPlayerHalfH|b2kPlayerHalfH()|The player capsule's current half-height.|Gives back: Pixels, or 0 when there is no player.\nIt shrinks during a reshaped crawl, so read it live rather than using a constant.
b2kPlayerHalfW|b2kPlayerHalfW()|The player capsule's half-width.|Gives back: Pixels, or 0 when there is no player.\nThe player capsule's half-width.
b2kPlayerHurtIs|b2kPlayerHurtIs()|Report whether the player is in knockback or its mercy window.|Gives back: true or false.\nReport whether the player is in knockback or its mercy window.
b2kPlayerHurt|b2kPlayerHurt fromX|Knock the player back from a hit.|fromX: The x the hit came from; the player pops away from it. Empty pops backward from the facing.\nThe contact-damage standard: an away pop (hurtPopX, hurtPopY), the hurt state, input ignored until hurtMs has passed or the first landing after half of it, whichever is later, then an invulnMs mercy window in which this command does nothing. Ignored while control is off. Keep your respawn flow for lethal falls.
b2kPlayerInLadder|b2kPlayerInLadder()|Report whether the player is inside a ladder zone this frame.|Gives back: true or false.\nReport whether the player is inside a ladder zone this frame.
b2kPlayerInWater|b2kPlayerInWater()|Report whether the player is inside a water zone this frame.|Gives back: true or false.\nReport whether the player is inside a water zone this frame.
b2kPlayerJump|b2kPlayerJump speed|Make the player jump, with no ground check.|speed: The launch speed in px/s. Empty means the jumpSpeed knob.\nThe same launch as a pressed jump, for springs and power-ups; the caller decides when it is allowed. Use it for every upward boost: a raw upward velocity on a grounded player is treated as a rebound and snapped away.
b2kPlayerMake|b2kPlayerMake x, y, w, h, sheet|Create a platformer player in one call.|x: The centre x in pixels. Not a number means the world origin's x.\ny: The centre y in pixels. Not a number means the world origin's y.\nw: The collision width in pixels. Empty means 32.\nh: The collision height in pixels. Empty means 48.\nsheet: Optional sheet name: a sprite of its first frame is created and pinned on top.\nGives back: The player control's long id through the result, or empty when there is no world.\nIt creates a rectangle graphic as the body host (hidden when a sprite of the sheet is made), attaches it with b2kPlayerAttach, and turns input on. The collision size is independent of the art size. Give the returned control to b2kCamFollow and your hazard checks.
b2kPlayerOnGround|b2kPlayerOnGround()|Report whether the player is grounded this frame.|Gives back: true or false; false on the frame a jump launches.\nReport whether the player is grounded this frame.
b2kPlayerProbe|b2kPlayerProbe body, vY|Run the controller's ground probe.|body: The player's raw body handle, b2kBodyOf(b2kPlayer()).\nvY: The body's vertical velocity in px/s, screen oriented (negative is rising).\nInternal handler: three short rays down from the capsule decide whether the player is grounded (a surface whose normal points up within maxSlopeDeg). Skipped while the controller's own jump is still rising.
b2kPlayerRemove|b2kPlayerRemove|Remove the player controller.|The controller's state and tuning go. The body and sprite stay; remove them with b2kRemove and b2kSpriteRemove.
b2kPlayerResolveArt|b2kPlayerResolveArt|Find the control whose animations the controller drives.|Internal handler: the player itself if it is a sprite, else the first sprite pinned to it with b2kSpriteBind. Call it after binding new art to an existing player.
b2kPlayerRespawn|b2kPlayerRespawn x, y|Teleport the player and reset it to a clean standing idle.|x: The new centre x in pixels. Not a number keeps the current x.\ny: The new centre y in pixels. Not a number keeps the current y.\nVelocity is zeroed; jump, hurt, dash, climb, swim, drop and duck states are cleared; the air-jump budget is refilled and control is on. Tuning and zones are kept.
b2kPlayerSet|b2kPlayerSet key, value|Set a player tuning knob.|key: The knob's name (case does not matter).\nvalue: The new value; empty goes back to the default.\nThe knobs: moveSpeed, accel, airAccel, jumpSpeed, jumpCut, coyoteMs, bufferMs, maxFall, maxSlopeDeg, dropMs, climbSpeed, swimSpeed, swimJump, swimGravity, swimMaxFall, hurtPopX, hurtPopY, hurtMs, invulnMs, and the opt-in airJumps, wallJumpX, wallJumpY, wallSlideMax, dashSpeed, dashMs, dashCooldownMs, airDash, duckScale and platformCarry (b2kPlayerDefault gives each default). Unknown keys are stored for your own use. Set them before or after the player exists; a change applies from the next frame. b2kClear keeps them; b2kTeardown and b2kPlayerRemove reset them.
b2kPlayerShowState|b2kPlayerShowState now, vX|Play the animation and facing for the player's state.|now: The controller's clock, in milliseconds.\nvX: The player's horizontal velocity, in px/s.\nInternal handler: the tick calls it while the controller has control and art.
b2kPlayerSprite|b2kPlayerSprite()|The control the controller animates.|Gives back: The art control, or empty when none is found.\nThe control the controller animates.
b2kPlayerStandUp|b2kPlayerStandUp|Restore the player's standing capsule.|Internal handler: stands the player up with no headroom check whenever it is ducked. b2kPlayerRespawn uses it.
b2kPlayerState|b2kPlayerState()|The player's current state.|Gives back: idle, run, jump, fall, duck, climb, hurt, swim, wallslide or dash, or land for one frame on touch-down; empty when there is no player.\nRead it from b2kFrame. A drop-through reads as fall. The wallslide and dash states appear only when their knobs are on.
b2kPlayerSwimEnd|b2kPlayerSwimEnd body|End the swim's buoyancy.|body: The player's raw body handle, b2kBodyOf(b2kPlayer()).\nInternal handler: restores the saved gravity scale. Without a start it is a no-op.
b2kPlayerSwimStart|b2kPlayerSwimStart body|Start the swim's buoyancy.|body: The player's raw body handle, b2kBodyOf(b2kPlayer()).\nInternal handler: saves the body's gravity scale and sets it to swimGravity. A repeated start is a no-op.
b2kPlayerTick|b2kPlayerTick|Run one frame of the player controller.|Internal handler: the loop and b2kStepOnce call it after the input sample. It probes the ground, applies input, jumping, ladders, water, hurt and the opt-in actions, and picks the animation. It exits at once when there is no player.
b2kPlayerTuneCache|b2kPlayerTuneCache|Copy the tuning knobs into the controller's fast variables.|Internal handler: b2kPlayerSet calls it, so a knob takes effect on the next frame.
b2kPlayerWallProbe|b2kPlayerWallProbe body, axis|Look for a wall beside the player.|body: The player's raw body handle, b2kBodyOf(b2kPlayer()).\naxis: The side to look: -1 left, 1 right, 0 the facing.\nInternal handler: one sideways ray for the wall-slide and wall-jump system. Its result has no public reader.
b2kPlayer|b2kPlayer()|The player control.|Gives back: The player's long id, or empty when there is no player.\nThe player control.
b2kPosition|b2kPosition(control)|A body's centre in screen pixels.|control: The control, by reference (the long id of the control is safest).\nGives back: "x,y" in screen pixels (sub-pixel), or "0,0" when the control has no body.\nA body's centre in screen pixels.
b2kProfile|b2kProfile()|Timings for the last physics step.|Gives back: "totalStep,collide,solve" in milliseconds, or empty with no world.\nTimings for the last physics step.
b2kPruneDeadRefs|b2kPruneDeadRefs dead|Forget controls that no longer exist.|dead: Control references, one per line.\nInternal handler: destroys each one's body and drops every record of it, as b2kRemove would.
b2kPush|b2kPush control, dvxPx, dvyPx|Add to a body's velocity in pixels per second.|control: The control, by reference (the long id of the control is safest).\ndvxPx: Change in horizontal velocity, px/s.\ndvyPx: Change in vertical velocity, px/s (negative is up).\nA one-shot kick that ignores mass: every body gains the same speed. It wakes the body. Use b2kImpulse for a mass-aware kick. A control with no Kit body is ignored.
b2kQueryToControls|b2kQueryToControls(count)|Turn the last raw query's rows into Kit controls.|count: The row count the raw query returned.\nGives back: The controls' long ids, one per line; rows with no Kit control are skipped.\nA helper behind b2kOverlap, b2kOverlapCircle and b2kRayHitAll.
b2kQuickStart|b2kQuickStart gravityY|Make a world with gravity, walls around the card, and start the loop.|gravityY: Vertical gravity in Box2D units, y up (negative pulls down). Empty means -10.\nThe one-call start: b2kSetup with no horizontal gravity, b2kAddWalls around the card edges, then b2kStart.
b2kRayDist|b2kRayDist()|The distance from the last ray's start to its hit, in pixels.|Gives back: The distance, or empty when the last ray missed.\nThe distance from the last ray's start to its hit, in pixels.
b2kRayHitAll|b2kRayHitAll(x1, y1, x2, y2)|Every Kit control a ray between two screen points crosses.|x1: Start x, in pixels.\ny1: Start y, in pixels.\nx2: End x, in pixels.\ny2: End y, in pixels.\nGives back: The controls' long ids, one per line, nearest first, or empty.\nEvery Kit control a ray between two screen points crosses.
b2kRayHitNormalX|b2kRayHitNormalX()|The x part of the surface normal at the last ray hit.|Gives back: A unit-vector component, screen oriented, or empty when the last ray missed.\nThe x part of the surface normal at the last ray hit.
b2kRayHitNormalY|b2kRayHitNormalY()|The y part of the surface normal at the last ray hit.|Gives back: A unit-vector component, screen oriented (negative points up), or empty when the last ray missed.\nThe y part of the surface normal at the last ray hit.
b2kRayHitX|b2kRayHitX()|The x of the last ray hit, in screen pixels.|Gives back: The rounded x, or empty when the last ray missed.\nThe x of the last ray hit, in screen pixels.
b2kRayHitY|b2kRayHitY()|The y of the last ray hit, in screen pixels.|Gives back: The rounded y, or empty when the last ray missed.\nThe y of the last ray hit, in screen pixels.
b2kRayHit|b2kRayHit(x1, y1, x2, y2)|Cast a ray between two screen points and find the closest hit.|x1: Start x, in pixels.\ny1: Start y, in pixels.\nx2: End x, in pixels.\ny2: End y, in pixels.\nGives back: The Kit control hit, or empty when nothing is hit or the body is not a Kit body.\nAfter a hit, b2kRayHitX, b2kRayHitY, b2kRayHitNormalX, b2kRayHitNormalY and b2kRayDist describe it; after a miss they are empty. Walls and chains count as hits even though they return empty, so test b2kRayHitX to tell a wall from a miss. A ray that starts inside a shape does not report that shape.
b2kRegister|b2kRegister ref, body, isStatic|Record a control and body pair in the Kit's tables.|ref: The control's long id.\nbody: The raw body handle.\nisStatic: true when the body never moves, so the sync skips it.\nInternal handler: the attach handlers call it. Registering a body you made with the raw b2 layer lets Kit getters and events find its control, but the Kit does not draw it until a render kind is set by an attach handler.
b2kRelease|b2kRelease|Let go of a dragged body.|Safe to call when nothing is held.
b2kRemoveJoint|b2kRemoveJoint joint|Destroy a joint.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nWorks for every joint the Kit makes, including b2kMotorTo and b2kNoCollide joints. A stale handle is harmless.
b2kRemove|b2kRemove control|Destroy a control's body and forget it.|control: The control, by reference (the long id of the control is safest).\nIf the Kit created the control (b2kSpawn commands, sprites) the control is deleted too; a control you attached is left on the card. The body's joints are destroyed with it.
b2kResetTables|b2kResetTables|Empty the Kit's control and body tables.|Internal handler: b2kSetup and b2kTeardown call it. It forgets every control-to-body pairing, shape, render kind and camera membership, but it destroys no body and deletes no control, so calling it on a live world leaves bodies the Kit no longer tracks.
b2kReshape|b2kReshape control, shape, w, h|Rebuild a body's collision shape from the control's current size.|control: The control, by reference (the long id of the control is safest).\nshape: "box" (the default), "ball", "capsule" or "poly".\nw: Optional width in pixels to use instead of the control's width (box, ball and capsule).\nh: Optional height in pixels to use instead of the control's height (box and capsule).\nThe new shape goes on the same body, so joints stay valid, and the control is redrawn at once. The new shape has the default material and collision filter, so re-apply bounce, friction, density and layers after it. A sensor stays a sensor. If the new size is zero, or a poly outline has fewer than 3 points, the old shape is kept. Pass pW and pH for a polygon graphic: the engine will not resize one by setting its height.
b2kResume|b2kResume|Resume stepping after a pause.|The elapsed-time clock restarts from now, so the pause is not replayed as one long catch-up step.
b2kRopeLength|b2kRopeLength(joint)|A distance joint's current length.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nGives back: The length in pixels, or 0 for an empty or 0 handle.\nA distance joint's current length.
b2kRopeRange|b2kRopeRange joint, minPx, maxPx|Set a distance joint's minimum and maximum length.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nminPx: The shortest length in pixels.\nmaxPx: The longest length in pixels.\nSet a distance joint's minimum and maximum length.
b2kRopeSetLength|b2kRopeSetLength joint, lengthPx|Set a distance joint's rest length.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nlengthPx: The rest length in pixels.\nSet a distance joint's rest length.
b2kRope|b2kRope ctrlA, ctrlB, lengthPx|Link two controls by a distance joint between their centres.|ctrlA: The control, by reference (the long id of the control is safest).\nctrlB: The second control, by reference.\nlengthPx: The rest length in pixels. Empty means the current distance between the centres.\nGives back: The joint handle through the result, or 0 when a control has no body or there is no world.\nAs built, the joint holds the bodies at the rest length. Use b2kRopeRange for a slack rope with a minimum and maximum, and b2kSpring to make it springy.
b2kSensorCount|b2kSensorCount()|How many sensor entries happened this frame.|Gives back: The count, 0 when none.\nThe polling alternative to the b2kSensorEnter message; read it from b2kFrame. Events are collected after every fixed step of the frame.
b2kSensorEnterSensor|b2kSensorEnterSensor(index)|The sensor control of an entry this frame.|index: The 1-based index of the entry within this frame.\nGives back: The sensor's long id, or empty for an untracked body or an index out of range.\nThe sensor control of an entry this frame.
b2kSensorEnterVisitor|b2kSensorEnterVisitor(index)|The visiting control of an entry this frame.|index: The 1-based index of the entry within this frame.\nGives back: The visitor's long id, or empty for an untracked body or an index out of range.\nThe visiting control of an entry this frame.
b2kSensorExitCount|b2kSensorExitCount()|How many sensor exits happened this frame.|Gives back: The count, 0 when none.\nHow many sensor exits happened this frame.
b2kSensorExitSensor|b2kSensorExitSensor(index)|The sensor control of an exit this frame.|index: The 1-based index of the exit within this frame.\nGives back: The sensor's long id, or empty for an untracked body or an index out of range.\nThe sensor control of an exit this frame.
b2kSensorExitVisitor|b2kSensorExitVisitor(index)|The visiting control of an exit this frame.|index: The 1-based index of the exit within this frame.\nGives back: The visitor's long id, or empty for an untracked body or an index out of range.\nThe visiting control of an exit this frame.
b2kSetBounce|b2kSetBounce control, restitution|Set how bouncy a control's shape is (restitution).|control: The control, by reference (the long id of the control is safest).\nrestitution: 0 for no bounce up to 1 for a full bounce; clamped to 0-2.\nA control with no Kit shape is ignored.
b2kSetBullet|b2kSetBullet control, flag|Turn continuous collision on or off for one fast body.|control: The control, by reference (the long id of the control is safest).\nflag: true to treat the body as a bullet, false for normal stepping.\nA bullet does not tunnel through other moving bodies. A control with no Kit body is ignored.
b2kSetCategory|b2kSetCategory control, layerList|Set which collision layers a control belongs to.|control: The control, by reference (the long id of the control is safest).\nlayerList: A comma or space separated list of layer names or raw numbers.\nTwo shapes collide only when each one's category is in the other's mask. The shape keeps its mask and group. A control with no Kit shape is ignored.
b2kSetCollisionGroup|b2kSetCollisionGroup control, group|Set a control's collision group index.|control: The control, by reference (the long id of the control is safest).\ngroup: A negative group never collides with its own group; a positive one always does; 0 uses category and mask.\nThe group overrides category and mask. A control with no Kit shape is ignored.
b2kSetContactTuning|b2kSetContactTuning hertz, damping, pushPx|Tune contact softness for the world.|hertz: Contact stiffness, in hertz.\ndamping: The contact damping ratio.\npushPx: The fastest speed, in pixels per second, at which overlapping shapes are pushed apart.\nWith no world it does nothing.
b2kSetDamping|b2kSetDamping control, linear, angular|Set a body's linear and angular damping (drag).|control: The control, by reference (the long id of the control is safest).\nlinear: Linear damping, 0 for none. Empty leaves it unchanged.\nangular: Angular damping, 0 for none. Empty leaves it unchanged.\nA control with no Kit body is ignored.
b2kSetDensity|b2kSetDensity control, density|Set a control's shape density, which sets its mass.|control: The control, by reference (the long id of the control is safest).\ndensity: Density in kilograms per square metre; clamped to 0-10000. The default is 1.\nA control with no Kit shape is ignored.
b2kSetDynamic|b2kSetDynamic control|Make a body dynamic (moved by forces and collisions).|control: The control, by reference (the long id of the control is safest).\nThe same as b2kSetType with "dynamic".
b2kSetFixedRotation|b2kSetFixedRotation control, flag|Stop or allow a body's rotation.|control: The control, by reference (the long id of the control is safest).\nflag: true to stop the body rotating, false to let it rotate.\nCharacters usually want fixed rotation. A control with no Kit body is ignored.
b2kSetFriction|b2kSetFriction control, friction|Set a control's shape friction.|control: The control, by reference (the long id of the control is safest).\nfriction: Friction, usually 0 (ice) to 1 (rubber); clamped to 0-10.\nA control with no Kit shape is ignored.
b2kSetGravityScale|b2kSetGravityScale control, scale|Set a per-body gravity multiplier.|control: The control, by reference (the long id of the control is safest).\nscale: 1 is normal gravity, 0 none, a negative value floats the body up.\nA control with no Kit body is ignored.
b2kSetGravity|b2kSetGravity gx, gy|Change the world's gravity.|gx: Horizontal gravity in Box2D units (metres per second squared). Not a number means 0.\ngy: Vertical gravity in Box2D units, y up, so negative pulls down. Not a number means -10.\nThe values go to Box2D unchanged, in metres per second squared with y pointing up, the same convention as b2kSetup. With no world it does nothing.
b2kSetJointTuning|b2kSetJointTuning hertz, damping|Tune joint softness for the world.|hertz: Joint stiffness, in hertz.\ndamping: The joint damping ratio.\nWith no world it does nothing.
b2kSetKinematic|b2kSetKinematic control|Make a body kinematic (moved only by its velocity).|control: The control, by reference (the long id of the control is safest).\nThe same as b2kSetType with "kinematic".
b2kSetMask|b2kSetMask control, layerList|Set which collision layers a control collides with.|control: The control, by reference (the long id of the control is safest).\nlayerList: A comma or space separated list of layer names or raw numbers.\nThe reserved "oneway" bit is always added, so a body with a custom mask still stands on b2kChain terrain. The shape keeps its category and group. A control with no Kit shape is ignored.
b2kSetMaxSpeed|b2kSetMaxSpeed pxPerSec|Limit how fast any body can move.|pxPerSec: The top speed, in pixels per second.\nWith no world it does nothing.
b2kSetOrigin|b2kSetOrigin screenX, screenY|Set the screen point that maps to the world origin.|screenX: Screen x in pixels. Empty or not a number keeps the current value.\nscreenY: Screen y in pixels. Empty or not a number keeps the current value.\nb2kSetup puts the origin at the card's bottom centre. Change it before adding bodies, because conversions made earlier are not redone.
b2kSetRestitutionThreshold|b2kSetRestitutionThreshold pxPerSec|Set the speed below which collisions stop bouncing.|pxPerSec: The approach speed, in pixels per second.\nA higher value removes small jittery bounces. With no world it does nothing.
b2kSetScale|b2kSetScale pixelsPerMetre|Set how many screen pixels make one Box2D metre.|pixelsPerMetre: Pixels per metre, clamped to 1-10000. The default after setup is 40.\nSet the scale right after b2kSetup, before adding bodies: bodies already in the world keep the size they were built with. Moving objects behave best at roughly 0.1 to 10 metres, so 4 to 400 px at the default scale.
b2kSetSensor|b2kSetSensor control, flag|Mark a control's shape as a sensor or as solid, for its next rebuild.|control: The control, by reference (the long id of the control is safest).\nflag: true for a sensor, anything else for solid.\nThe sensor flag lives on the shape, so this only records the choice. Rebuild the shape with b2kReshape to apply it.
b2kSetSleepEnabled|b2kSetSleepEnabled control, flag|Allow or forbid one body ever falling asleep.|control: The control, by reference (the long id of the control is safest).\nflag: true to allow sleep; anything else forbids it and wakes the body.\nb2kEnableSleeping switches the whole world; this switches one body. The player controller forbids sleep on its body so it always responds to input. A control with no Kit body is ignored.
b2kSetSleepThreshold|b2kSetSleepThreshold control, pxPerSec|Set the speed below which a body may fall asleep.|control: The control, by reference (the long id of the control is safest).\npxPerSec: The speed in pixels per second. Lower keeps the body awake longer.\nA control with no Kit body is ignored.
b2kSetStatic|b2kSetStatic control|Make a body static (immovable).|control: The control, by reference (the long id of the control is safest).\nThe same as b2kSetType with "static".
b2kSetSubsteps|b2kSetSubsteps n|Set the solver sub-steps per physics step.|n: Sub-steps per step, rounded and clamped to 1-64. The default is 4.\nMore sub-steps make stacks and joints stiffer and cost more CPU.
b2kSetType|b2kSetType control, type|Change a body's type by name.|control: The control, by reference (the long id of the control is safest).\ntype: "static", "kinematic" or "dynamic"; any other value means dynamic.\nA kinematic body moves only by the velocity you give it and is not pushed by others, which suits moving platforms. A non-static body is woken. A control with no Kit body is ignored.
b2kSetup|b2kSetup gravityX, gravityY|Create the physics world and reset the Kit to a clean state.|gravityX: Horizontal gravity in Box2D units (metres per second squared, y up). Empty means 0.\ngravityY: Vertical gravity in Box2D units, y up, so a negative value pulls down. Empty means -10.\nUse b2kSetup to start a world without starting the loop. It first tears down any previous world (b2kTeardown), then sets the scale to 40 pixels per metre, the origin to the card's bottom centre (40 px up from the bottom edge) and 4 solver sub-steps. The gravity values go to Box2D unchanged, in metres per second squared with y pointing up. It also maps a native library saved beside the stack (b2kEnsureNativeLib).
b2kSetVelocity|b2kSetVelocity control, vxPx, vyPx|Set a body's velocity in pixels per second, and wake it.|control: The control, by reference (the long id of the control is safest).\nvxPx: Horizontal velocity in px/s (positive is right).\nvyPx: Vertical velocity in px/s (positive is down).\nSetting a velocity always wakes the body. Do not write a velocity every frame to a body that is meant to come to rest: it never sleeps. For a player under the controller use b2kPlayerJump for upward boosts. A control with no Kit body is ignored.
b2kSheetAddFrame|b2kSheetAddFrame sheet, frame, x, y, w, h|Name one rectangular region of a loaded sheet as a frame.|sheet: The sheet's name.\nframe: The frame's name.\nx: The region's left, in source pixels.\ny: The region's top, in source pixels.\nw: The region's width in pixels, at least 1.\nh: The region's height in pixels, at least 1.\nThe path for packed sheets that have no XML: load the source with a frame size of 0, then add each frame. It also works on top of a grid or an atlas. Redefining a name drops its old slices. Bad arguments, or a sheet that is not loaded, are ignored.
b2kSheetAdoptAtlas|b2kSheetAdoptAtlas name, pngPath, xmlPath|Register an atlas from the stamp a saved stack carries.|name: The sheet's name.\npngPath: The PNG path the atlas was first loaded from.\nxmlPath: The XML path the atlas was first loaded from.\nGives back: The frame count through the result, or 0 when there is nothing to adopt.\nInternal handler: b2kSheetLoadAtlas calls it when sheets persist. It adopts only when the image b2ksheet_ plus the sheet name exists and was stamped from the same PNG and XML paths, and a malformed stamp adopts nothing. It reads no file.
b2kSheetAtlasRows|b2kSheetAtlasRows(name)|Every frame region of a sheet, one per line.|name: The sheet's name.\nGives back: Lines of "x,y,w,h,name" in source pixels, in definition order; empty for an unknown sheet.\nThe name comes last so a name with a comma survives. For a persisting atlas this is also the stamp a saved stack adopts.
b2kSheetEnsureFlip|b2kSheetEnsureFlip sheet, key|Make a frame's mirrored image now instead of on first display.|sheet: The sheet's name.\nkey: The frame's name or number.\nIt slices the frame first if needed. If this engine's flip fails, the unmirrored frame is used.
b2kSheetEnsureIcon|b2kSheetEnsureIcon sheet, key|Slice a frame's image now instead of on first display.|sheet: The sheet's name.\nkey: The frame's name or number.\nFrames are sliced lazily, and a slice made mid-game costs a visible hitch. Pre-warm frames that first appear during play. The result is cached, so a second call is free.
b2kSheetForget|b2kSheetForget name|Forget one sheet.|name: The sheet's name.\nIt deletes the sheet's sliced and mirrored frame images, the source image if the Kit loaded it, and the sheet's animations. Sprites that show it stay on the card.
b2kSheetFrameNames|b2kSheetFrameNames(name)|Every frame key of a sheet.|name: The sheet's name.\nGives back: The frame names or numbers, one per line, in definition order.\nEvery frame key of a sheet.
b2kSheetFrameSize|b2kSheetFrameSize(name, frame)|A frame's display size.|name: The sheet's name.\nframe: The frame's name or number.\nGives back: "w,h" in pixels (the region times the sheet scale), or empty for an unknown frame.\nA frame's display size.
b2kSheetFrames|b2kSheetFrames(name)|How many frames a sheet has.|name: The sheet's name.\nGives back: The frame count, 0 for an unknown sheet.\nHow many frames a sheet has.
b2kSheetFromImage|b2kSheetFromImage name, imgRef, fW, fH, count, margin, spacing|Register an image already in the stack as a grid sheet.|name: The sheet's name.\nimgRef: The image, by reference.\nfW: Frame width in pixels; 0 or empty registers no grid.\nfH: Frame height in pixels; 0 or empty registers no grid.\ncount: Optional number of frames to register; empty means every whole cell.\nmargin: Optional outer border in pixels. Empty means 0.\nspacing: Optional gap between cells in pixels. Empty means 0.\nGives back: The sheet's frame count through the result.\nThe image is used in place and the Kit never deletes it.
b2kSheetGridRegions|b2kSheetGridRegions name, fW, fH, count, margin, spacing|Register numbered grid frames over a sheet's source image.|name: The sheet's name.\nfW: Frame width in pixels; 0 or empty registers no grid.\nfH: Frame height in pixels; 0 or empty registers no grid.\ncount: Optional number of frames to register; empty means every whole cell.\nmargin: Optional outer border in pixels. Empty means 0.\nspacing: Optional gap between cells in pixels. Empty means 0.\nInternal handler: the grid loaders call it. A frame size below 1 registers nothing.
b2kSheetHasFrame|b2kSheetHasFrame(name, frame)|Report whether a sheet has a frame.|name: The sheet's name.\nframe: The frame's name or number.\nGives back: true or false.\nReport whether a sheet has a frame.
b2kSheetKeyIndex|b2kSheetKeyIndex(sheet, key)|A frame's position in its sheet.|sheet: The sheet's name.\nkey: The frame's name or number.\nGives back: The 1-based position in definition order, or 0 when absent.\nIt names saved slices so a reopened stack can find and reuse them.
b2kSheetLoadAtlas|b2kSheetLoadAtlas name, pngPath, xmlPath|Register a packed atlas: a PNG and its TextureAtlas XML.|name: The sheet's name.\npngPath: The PNG file's path.\nxmlPath: The XML file's path. Empty means the PNG path with an xml extension.\nGives back: The sheet's frame count through the result, or 0 when a file cannot be read.\nThe XML names each region in SubTexture tags (the Kenney format), and frames are addressed by those names. With b2kSheetPersist on, the first load stamps the regions on the Kit's source image and a later load, even in a reopened saved stack, adopts them with no file access.
b2kSheetLoad|b2kSheetLoad name, path, fW, fH, count, margin, spacing|Register an image file as a sheet of numbered grid frames.|name: The sheet's name.\npath: The image file's path.\nfW: Frame width in pixels; 0 or empty registers no grid.\nfH: Frame height in pixels; 0 or empty registers no grid.\ncount: Optional number of frames to register; empty means every whole cell.\nmargin: Optional outer border in pixels. Empty means 0.\nspacing: Optional gap between cells in pixels. Empty means 0.\nGives back: The sheet's frame count through the result, or 0 when the file cannot be loaded.\nFrames are numbered 1 to N left to right, top to bottom. With no grid, name regions yourself with b2kSheetAddFrame. The image is loaded into a hidden image the Kit owns.
b2kSheetPersists|b2kSheetPersists()|Report whether sheets survive teardown.|Gives back: true or false.\nReport whether sheets survive teardown.
b2kSheetPersist|b2kSheetPersist flag|Keep loaded sheets alive across teardowns.|flag: true (or empty) to keep sheets, false to wipe them with each teardown (the starting state).\nWith persistence on, sheets survive b2kTeardown like sounds do, so a multi-level game loads its atlases once and an identical reload is a no-op. The Kit's source and frame images have stable names and are marked with where they came from, so a saved stack carries them: on reopen a load adopts the images already in the stack, and an atlas needs neither its PNG nor its XML. b2kSheetsWipe still clears everything.
b2kSheetScale|b2kSheetScale name, scale|Set the display scale of a sheet's frames.|name: The sheet's name.\nscale: The scale factor, clamped to 0.05-8. The default is 1.\nSet it right after loading, before making sprites: frames already sliced are dropped and re-sliced at the new scale, but existing sprite buttons keep their size.
b2kSheetSliceSig|b2kSheetSliceSig(sheet)|A sheet's provenance stamp.|sheet: The sheet's name.\nGives back: A string naming the sheet's source, its load arguments and its scale.\nA saved slice is reused only when its stamp matches, so new art or a new scale is re-sliced.
b2kSheetSourceFromFile|b2kSheetSourceFromFile(name, path)|Load an image file into the hidden source image of a sheet.|name: The sheet's name.\npath: The image file's path.\nGives back: The source image's long id, or empty on failure.\nInternal handler: the sheet loaders call it. The file is loaded as image content. When sheets persist and an image already loaded from the same path is in the stack, it is reused without reading the file.
b2kSheetsWipe|b2kSheetsWipe|Forget every sheet and remove every sprite.|It also deletes Kit-made sprite and sheet images a previous session left on the card. b2kTeardown calls it unless sheets persist; call it yourself to force a clean reload.
b2kSleep|b2kSleep control|Put a body to sleep until something wakes it.|control: The control, by reference (the long id of the control is safest).\nA sleeping body stops simulating until a contact, a joint or a call such as b2kWake wakes it. A control with no Kit body is ignored.
b2kSliderLimitOff|b2kSliderLimitOff joint|Remove a slider joint's travel limits.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nRemove a slider joint's travel limits.
b2kSliderLimit|b2kSliderLimit joint, lowerPx, upperPx|Limit a slider joint's travel.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nlowerPx: The lowest translation in pixels.\nupperPx: The highest translation in pixels.\nTranslation is measured along the joint's axis from where the joint was made.
b2kSliderMotorOff|b2kSliderMotorOff joint|Turn a slider joint's motor off.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nTurn a slider joint's motor off.
b2kSliderMotor|b2kSliderMotor joint, pxPerSec, maxForce|Drive a slider joint at a set speed.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\npxPerSec: The target speed in pixels per second along the axis.\nmaxForce: The most force the motor may use. Empty means 1000.\nDrive a slider joint at a set speed.
b2kSliderPos|b2kSliderPos(joint)|A slider joint's current translation.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nGives back: The translation in pixels along the axis, or 0 for an empty or 0 handle.\nA slider joint's current translation.
b2kSlider|b2kSlider ctrlA, ctrlB, axisDeg|Let one control slide along an axis relative to another, or to the world.|ctrlA: The control that slides, by reference.\nctrlB: The control it slides against, or empty for the world.\naxisDeg: The on-screen slide direction in degrees: 0 is horizontal, 90 vertical. Empty means 90.\nGives back: The joint handle through the result, or 0 when a control has no body or there is no world.\nA prismatic joint. Drive it with b2kSliderMotor and bound it with b2kSliderLimit.
b2kSmoothGround|b2kSmoothGround points|Build an open chain of smooth static terrain.|points: Screen points, one "x,y" per line. At least 4 points.\nGives back: The chain handle through the result, or 0 when there is no world.\nThe same as b2kChain with pLoop false; its ghost rule and winding apply.
b2kSoundClip|b2kSoundClip(name)|The audioClip that plays a named sound.|name: The sound's name.\nGives back: The clip's name, or empty.\nA clip already in the stack under the Kit's name for the sound (as in a reopened saved stack) is adopted instead of being made again.
b2kSoundIsLoaded|b2kSoundIsLoaded(name)|Report whether a named sound exists.|name: The sound's name.\nGives back: true or false; true too for a clip a saved stack carried in.\nReport whether a named sound exists.
b2kSoundLoad|b2kSoundLoad name, path|Import a sound file under a name.|name: The sound's name.\npath: A WAV, AIFF or AU file's path.\nThe file becomes an audioClip in the stack, replacing a sound of the same name. A missing file or failed import is reported by b2kSoundStatus, not thrown.
b2kSoundLoop|b2kSoundLoop name|Loop a named sound until stopped.|name: The sound's name.\nIt plays until b2kSoundStop or the next sound.
b2kSoundMuted|b2kSoundMuted()|Report whether sounds are muted.|Gives back: true or false.\nReport whether sounds are muted.
b2kSoundMute|b2kSoundMute flag|Mute or unmute the Kit's sounds.|flag: true to mute; anything else unmutes.\nMuting also stops the current sound. The setting survives b2kTeardown but not a reopened stack; save it yourself if needed.
b2kSoundStatus|b2kSoundStatus()|Why audio is degraded, if it is.|Gives back: Empty when healthy, otherwise the latest reason (missing file, failed import or play).\nWhy audio is degraded, if it is.
b2kSoundStop|b2kSoundStop|Stop the current sound.|Stop the current sound.
b2kSoundsWipe|b2kSoundsWipe|Stop playback and delete every Kit sound.|It deletes every Kit-made audioClip, including ones a previous session left in the stack, and resets audio after a failure. The mute setting survives.
b2kSoundVolume|b2kSoundVolume pct|Set the engine's global playback volume.|pct: Volume 0-100.\nIt sets the playLoudness, which affects every stack's audio, so let the user choose it.
b2kSound|b2kSound name|Play a named sound.|name: The sound's name.\nThe engine plays one clip at a time, so this cuts whatever is playing. Unknown names, mute and dead audio are silent no-ops; a failed play turns audio off for the session and b2kSoundStatus says why.
b2kSpawnBall|b2kSpawnBall screenX, screenY, diameter, color|Create a filled circle graphic with a dynamic ball body.|screenX: Centre x in pixels. Not a number means the world origin's x.\nscreenY: Centre y in pixels. Not a number means the world origin's y.\ndiameter: Diameter in pixels. Empty means 40.\ncolor: Optional fill colour. An unknown name is ignored.\nGives back: The new control's long id through the result, or empty when there is no world.\nThe Kit owns the control: b2kRemove and b2kClear delete it.
b2kSpawnBox|b2kSpawnBox screenX, screenY, w, h, color|Create a filled rectangle graphic with a dynamic box body.|screenX: Centre x in pixels. Not a number means the world origin's x.\nscreenY: Centre y in pixels. Not a number means the world origin's y.\nw: Width in pixels. Empty means 40.\nh: Height in pixels. Empty means the width.\ncolor: Optional fill colour, such as "orange" or "255,128,0". An unknown name is ignored.\nGives back: The new control's long id through the result, or empty when there is no world.\nThe Kit owns the control: b2kRemove and b2kClear delete it. While the camera is on it is created inside the viewport. Read the result on the very next line, because the next command replaces it.
b2kSpawnCapsule|b2kSpawnCapsule screenX, screenY, length, thickness, color|Create a pill-shaped graphic with a dynamic capsule body.|screenX: Centre x in pixels. Not a number means the world origin's x.\nscreenY: Centre y in pixels. Not a number means the world origin's y.\nlength: Length along the pill's axis in pixels. Empty means 80.\nthickness: Thickness across the pill in pixels. Empty means 40.\ncolor: Optional fill colour. An unknown name is ignored.\nGives back: The new control's long id through the result, or empty when there is no world.\nThe pill is horizontal when the length is at least the thickness, vertical otherwise. The Kit owns the control.
b2kSpeed|b2kSpeed(control)|A body's speed in pixels per second.|control: The control, by reference (the long id of the control is safest).\nGives back: The speed, or 0 when the control has no body.\nA body's speed in pixels per second.
b2kSpinBy|b2kSpinBy control, degPerSec|Add to a body's angular velocity, in degrees per second.|control: The control, by reference (the long id of the control is safest).\ndegPerSec: The change in spin rate, degrees per second.\nIt wakes the body. A control with no Kit body is ignored.
b2kSpinRate|b2kSpinRate(control)|A body's rotation speed in degrees per second.|control: The control, by reference (the long id of the control is safest).\nGives back: The angular velocity, or 0 when the control has no body.\nA body's rotation speed in degrees per second.
b2kSpin|b2kSpin control, degPerSec|Set a body's angular velocity in degrees per second.|control: The control, by reference (the long id of the control is safest).\ndegPerSec: The spin rate in degrees per second.\nIt replaces the current spin. A control with no Kit body is ignored.
b2kSpring|b2kSpring joint, hertz, damping|Make a distance joint springy.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nhertz: The spring stiffness in hertz.\ndamping: The damping ratio. Empty means 0.5.\nMake a distance joint springy.
b2kSpriteAnim|b2kSpriteAnim(ctrl)|The animation a sprite is playing.|ctrl: The sprite control, by reference.\nGives back: The animation's name, or empty when stopped or the control is gone.\nThe animation a sprite is playing.
b2kSpriteBind|b2kSpriteBind ctrl, bodyCtrl, dX, dY|Pin a sprite to another control's position every frame.|ctrl: The sprite control, by reference. Empty makes this a no-op.\nbodyCtrl: The control to follow, by reference. Empty makes this a no-op.\ndX: Optional x offset in pixels. Empty means 0.\ndY: Optional y offset in pixels. Empty means 0.\nThe usual pattern for art bigger than its collision shape: an invisible control owns the body and the sprite follows it.
b2kSpriteFlipH|b2kSpriteFlipH ctrl, flag|Make a sprite face left or right.|ctrl: The sprite control, by reference. Empty makes this a no-op.\nflag: true to mirror the frames (face left), false for the art as drawn.\nMirrored frames are made the first time they are needed and shared by every sprite of the sheet.
b2kSpriteFlipped|b2kSpriteFlipped(ctrl)|Report whether a sprite is mirrored.|ctrl: The sprite control, by reference.\nGives back: true or false.\nReport whether a sprite is mirrored.
b2kSpriteForget|b2kSpriteForget ref|Drop a sprite's records once its control is gone.|ref: The sprite's long id.\nInternal handler: b2kSpriteRemove and the sprite tick call it. It deletes no control.
b2kSpriteFPS|b2kSpriteFPS ctrl, fPS|Override a sprite's animation speed.|ctrl: The sprite control, by reference. Empty makes this a no-op.\nfPS: Frames per second; empty goes back to each animation's own speed.\nOverride a sprite's animation speed.
b2kSpriteFrame|b2kSpriteFrame(ctrl)|The frame a sprite is showing.|ctrl: The sprite control, by reference.\nGives back: The frame's name or number, or empty.\nThe frame a sprite is showing.
b2kSpriteFromGIF|b2kSpriteFromGIF path, x, y|Create a sprite from an animated GIF file.|path: The GIF file's path.\nx: The centre x in pixels. Empty means the card's centre.\ny: The centre y in pixels. Empty means the card's centre.\nGives back: The image's long id through the result, or empty when the file cannot be loaded.\nThe engine plays the GIF. b2kSpritePlay and b2kSpriteStop set its repeatCount and b2kSpriteSetFrame its currentFrame.
b2kSpriteMoveTo|b2kSpriteMoveTo ctrl, x, y|Move a control to a world position, camera-correct.|ctrl: The control, by reference. Empty makes this a no-op.\nx: The world x, in pixels.\ny: The world y, in pixels.\nUse it instead of setting the loc for things you animate by hand, such as patrols. Outside a camera it is a plain loc set. It does not move a body; use b2kMoveTo for that.
b2kSpriteNew|b2kSpriteNew sheet, frame, x, y|Create a sprite: a transparent button showing a sheet frame.|sheet: The sheet's name.\nframe: The frame to show. Empty means the sheet's first frame.\nx: The centre x in pixels. Empty means the card's centre.\ny: The centre y in pixels. Empty means the card's centre.\nGives back: The sprite's long id through the result, or empty for an unknown sheet or frame.\nThe button is sized to the frame. It is an ordinary Kit control: give it a body with b2kAddCapsule or b2kAddBox (sprites follow position and do not rotate), or pin it to another control with b2kSpriteBind. b2kClear removes it.
b2kSpriteOnFinish|b2kSpriteOnFinish ctrl, message|Name a message to send when a one-shot animation ends.|ctrl: The sprite control, by reference. Empty makes this a no-op.\nmessage: The message name; empty turns it off.\nWhen a non-looping animation on this sprite ends, the Kit sends the message to the frame target (b2kFrameTarget) with two parameters, the sprite and the animation name. It fires for every non-looping animation, whoever started it.
b2kSpritePlay|b2kSpritePlay ctrl, anim, restart|Play a named animation on a sprite.|ctrl: The sprite control, by reference. Empty makes this a no-op.\nanim: The animation's name, defined with b2kAnimDef for the sprite's sheet.\nrestart: true to restart from the first frame when it is already playing.\nPlaying the animation that is already playing does nothing, so a state machine can call it every frame. An unknown animation is ignored.
b2kSpriteRemove|b2kSpriteRemove ctrl|Remove a sprite, and its body if it has one.|ctrl: The sprite control, by reference.\nA control that is already gone is still cleared from the Kit's records.
b2kSpritesClear|b2kSpritesClear|Remove every sprite.|Internal handler: b2kClear and b2kTeardown call it. Sheets stay loaded.
b2kSpriteSetFrame|b2kSpriteSetFrame ctrl, frame|Show one frame on a sprite, stopping any animation.|ctrl: The sprite control, by reference. Empty makes this a no-op.\nframe: The frame's name or number.\nShow one frame on a sprite, stopping any animation.
b2kSpriteShowFrame|b2kSpriteShowFrame ref, key|Point a sprite's icon at a frame.|ref: The sprite's long id.\nkey: The frame's name or number.\nInternal handler: it honours the sprite's facing and skips the icon set when the frame is already shown. It does not stop an animation; use b2kSpriteSetFrame for that.
b2kSpritesTick|b2kSpritesTick|Run one frame of sprite service.|Internal handler: the loop calls it each frame. Bound sprites follow their control and playing animations advance on wall-clock time; sprites whose control vanished are forgotten. Only bound or playing sprites are visited.
b2kSpriteStop|b2kSpriteStop ctrl|Stop a sprite's animation on its current frame.|ctrl: The sprite control, by reference. Empty makes this a no-op.\nStop a sprite's animation on its current frame.
b2kSpriteSweepOrphans|b2kSpriteSweepOrphans keepAssets|Delete Kit controls a previous session left on the card.|keepAssets: true to keep sheet images (sources and frames) and delete only sprites and dead viewports.\nA reopened stack resets script variables but keeps its controls, so old sprites would linger frozen. It deletes controls on this card named with the Kit's prefixes: dead camera viewports (ungrouped first), sprites, and unless kept, sheet images. Teardowns call it.
b2kSpriteUnbind|b2kSpriteUnbind ctrl|Stop a sprite following another control.|ctrl: The sprite control, by reference. Empty makes this a no-op.\nStop a sprite following another control.
b2kStart|b2kStart|Start the simulation loop.|Use b2kStart to begin stepping the world at a fixed 1/60 s step, syncing controls and delivering events once per frame. If no world exists yet it calls b2kSetup first. Starting again replaces any running loop rather than adding a second one.
b2kStepOnce|b2kStepOnce|Advance the world exactly one fixed step.|It works while paused, for a Step button or tests, and runs one full frame: sync, input, player, sprites, camera, events and b2kFrame. It does nothing unless the loop has been started.
b2kStop|b2kStop|Stop the simulation loop.|The world and its bodies stay; nothing steps until b2kStart. Use b2kTeardown to destroy the world as well.
b2kSyncAllBodies|b2kSyncAllBodies|Draw every awake, non-static Kit body.|Internal handler: the caller holds the screen lock. b2kSync wraps it in one.
b2kSyncAll|b2kSyncAll|Redraw every awake, moving Kit body's control now.|The same as b2kSync.
b2kSyncBodies|b2kSyncBodies|Draw the bodies that moved in the last step.|Internal handler: the loop calls it under its screen lock. It reads Box2D's move events, applies the kill floor, and forgets controls that vanished.
b2kSync|b2kSync|Redraw every awake, moving Kit body's control now.|For a stopped or paused world, such as an editor, where no step produces the move events the loop draws from. It holds one screen lock and always releases it.
b2kTeardown|b2kTeardown|Stop the loop and destroy the world and all Kit state.|Use b2kTeardown when a scene is finished. It stops the loop, destroys the Box2D world, forgets the player controller (tuning included), removes sprites, dissolves the camera viewport and empties the Kit's tables. Sheets are wiped too unless b2kSheetPersist is on, in which case only the sprite instances go and the sheet cache survives. Sounds always survive; use b2kSoundsWipe to remove them.
b2kToneBytes|b2kToneBytes(freq, ms, volPct, shape)|Synthesize one note as raw samples.|freq: The frequency in hertz; 0 or below is a rest.\nms: The length in milliseconds.\nvolPct: Volume 0-100.\nshape: "sine", or anything else for square.\nGives back: 8-bit unsigned mono samples at 22050 Hz with a linear decay, or empty for a zero length.\nSynthesize one note as raw samples.
b2kToneMake|b2kToneMake name, freqs, msPerNote, volPct, shape|Synthesize a sound from note frequencies, with no asset file.|name: The sound's name.\nfreqs: A comma list of frequencies in hertz; 0 is a rest.\nmsPerNote: Each note's length in milliseconds, 5-2000.\nvolPct: Volume 0-100. Empty means 60.\nshape: "sine" for a soft tone; anything else is a square wave.\nIt builds an 8-bit mono WAV at 22050 Hz in script, with a decay on each note, and imports it as an audioClip, replacing a sound of the same name. About 22 KB per second: keep effects short.
b2kTorque|b2kTorque control, torque|Apply a continuous turning force to a body.|control: The control, by reference (the long id of the control is safest).\ntorque: The torque, in Box2D units; the sign sets the direction.\nLike b2kForce, call it every frame for a sustained twist. A control with no Kit body is ignored.
b2kToScreenX|b2kToScreenX(wx)|Convert a world x in metres to a screen x in pixels.|wx: The world x, in metres.\nGives back: The screen x, in pixels.\nConvert a world x in metres to a screen x in pixels.
b2kToScreenY|b2kToScreenY(wy)|Convert a world y in metres (y up) to a screen y in pixels (y down).|wy: The world y, in metres.\nGives back: The screen y, in pixels.\nConvert a world y in metres (y up) to a screen y in pixels (y down).
b2kToWorldX|b2kToWorldX(sx)|Convert a screen x in pixels to a world x in metres.|sx: The screen x, in pixels.\nGives back: The world x in metres, or 0 before b2kSetup.\nConvert a screen x in pixels to a world x in metres.
b2kToWorldY|b2kToWorldY(sy)|Convert a screen y in pixels (y down) to a world y in metres (y up).|sy: The screen y, in pixels.\nGives back: The world y in metres, or 0 before b2kSetup.\nConvert a screen y in pixels (y down) to a world y in metres (y up).
b2kVelocity|b2kVelocity(control)|A body's velocity in pixels per second.|control: The control, by reference (the long id of the control is safest).\nGives back: "vx,vy" in px/s with y down, or "0,0" when the control has no body.\nA body's velocity in pixels per second.
b2kVersion|b2kVersion()|The native library's ABI version.|Gives back: The ABI version number of the loaded box2dxt library (4 for this Kit).\nA load and in-sync check from Kit-only code. It calls the extension, so it throws if the box2dxt extension is not loaded.
b2kWake|b2kWake control|Wake a sleeping body.|control: The control, by reference (the long id of the control is safest).\nA control with no Kit body is ignored.
b2kWall|b2kWall x1, y1, x2, y2|Add an invisible static segment between two screen points.|x1: Screen x of the first point, in pixels.\ny1: Screen y of the first point, in pixels.\nx2: Screen x of the second point, in pixels.\ny2: Screen y of the second point, in pixels.\nUse b2kWall for custom walls, ramps and ledges. The segment is two-sided: bodies collide from either side. It is invisible, so draw a graphic to match, and it is not tracked as a body, so b2kClear leaves it. For one-sided surfaces use b2kChain.
b2kWavWrap|b2kWavWrap(data)|Wrap raw samples in a WAV file header.|data: 8-bit mono samples at 22050 Hz.\nGives back: The bytes of a WAV file.\nWrap raw samples in a WAV file header.
b2kWeldSpring|b2kWeldSpring joint, hertz, damping|Make a weld joint springy.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nhertz: The stiffness in hertz for both the linear and angular parts; 0 makes the weld rigid again.\ndamping: The damping ratio. Empty means 0.5.\nMake a weld joint springy.
b2kWeld|b2kWeld ctrlA, ctrlB|Glue two controls rigidly together.|ctrlA: The control, by reference (the long id of the control is safest).\nctrlB: The second control, by reference.\nGives back: The joint handle through the result, or 0 when a control has no body or there is no world.\nThe bodies keep their current relative position and angle. b2kWeldSpring makes the weld springy.
b2kWheelMotorOff|b2kWheelMotorOff joint|Turn a wheel joint's motor off.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nTurn a wheel joint's motor off.
b2kWheelMotor|b2kWheelMotor joint, degPerSec, maxTorque|Drive a wheel joint at a set spin speed.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\ndegPerSec: The target spin in degrees per second.\nmaxTorque: The most torque the motor may use. Empty means 1000.\nDrive a wheel joint at a set spin speed.
b2kWheelSpring|b2kWheelSpring joint, hertz, damping|Tune a wheel joint's suspension.|joint: The joint handle a Kit joint constructor reported. Empty or 0 makes this a no-op.\nhertz: The spring stiffness in hertz. Empty means 4.\ndamping: The damping ratio. Empty means 0.7.\nTune a wheel joint's suspension.
b2kWheel|b2kWheel chassis, wheel, screenX, screenY, axisDeg|Attach a wheel to a chassis with a sprung axis and free spin.|chassis: The chassis control, by reference.\nwheel: The wheel control, by reference.\nscreenX: The anchor x in pixels. Empty means the wheel's centre.\nscreenY: The anchor y in pixels, used when an anchor x is given.\naxisDeg: The suspension axis in screen degrees. Empty means straight up.\nGives back: The joint handle through the result, or 0 when a control has no body or there is no world.\nAttach a wheel to a chassis with a sprung axis and free spin.
b2kWorldCenter|b2kWorldCenter(control)|A body's centre of mass in screen pixels.|control: The control, by reference (the long id of the control is safest).\nGives back: "x,y" in screen pixels, or "0,0" when the control has no body.\nIt differs from b2kPosition for off-centre shapes; it is the true pivot for spin and torque.
b2kWorld|b2kWorld()|The raw Box2D world handle.|Gives back: The world handle, or empty before setup.\nUse it to mix Kit code with calls to the raw b2 layer.
b2kXmlAttr|b2kXmlAttr(line, attr)|Read one attribute value from an XML tag line.|line: A line holding one XML tag.\nattr: The attribute's name.\nGives back: The attribute's value, or empty when it is absent.\nThe atlas loader's small parser.
b2kFrame|on b2kFrame|Sent to the frame target after each frame (message).|The Kit sends it to the object b2kFrameTarget named, once a frame, after the bodies have moved and the controls have been drawn.\nRead the keys, move your player and check your game here.
b2kContact|on b2kContact pA, pB|Sent when two bodies start to touch (message).|pA: The first control, or empty for a wall, the ground or a body the Kit does not track.\npB: The second control, the same way.\nThe Kit sends it to the object b2kContactTarget named, after each frame. b2kContactCount and b2kContactA are the polling way to ask the same.
b2kEndContact|on b2kEndContact pA, pB|Sent when two bodies stop touching (message).|pA: The first control, or empty for a wall or untracked body.\npB: The second control, the same way.\nSent to the contact target (b2kContactTarget) after each frame.
b2kSensorEnter|on b2kSensorEnter pSensor, pVisitor|Sent when something comes into a sensor (message).|pSensor: The sensor control (b2kAddSensor).\npVisitor: The control that came in.\nSent to the contact target (b2kContactTarget) after each frame. Do not delete either control in the handler: note it, and remove it in your b2kFrame handler.
b2kSensorExit|on b2kSensorExit pSensor, pVisitor|Sent when something leaves a sensor (message).|pSensor: The sensor control.\npVisitor: The control that left.\nSent to the contact target (b2kContactTarget) after each frame.
b2kFell|on b2kFell pControl|Sent just before a body below the kill floor is taken away (message).|pControl: The control that fell.\nSent to the frame target (b2kFrameTarget). Clean up companions, such as a sprite bound to it, but do not delete the control here: the Kit removes it.
@*/
