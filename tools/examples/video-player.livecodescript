script "OXTExampleVideoPlayer"
-- OXT-Beyond: builds "Play a Video", the remaster of the Video Player of
-- OpenXTalk Lite's demos (ide/Resources/Examples/Video Player.oxtstack),
-- which stays there as it was made. Its author is not recorded, and it
-- names no licence. It came with the video it plays,
-- ide/Resources/Examples/neville-segments.mp4, whose maker and licence
-- are not recorded either.
--
-- The original is one card: a player "a", and three buttons. "set
-- filename" gives the player the video beside the stack, "play" and "stop"
-- set the player's paused. The remaster keeps that program on its own
-- card, changed only where the window needs it: the player is on the
-- stage, and the video is found a folder up, as this stack is in
-- Remastered (each change is marked "(2026)" in the script). Then it grows
-- the program into a theater on a wide card: a time line, a play and pause
-- button, speeds, a loop, and another video to choose; and a page shows
-- the player's properties.
--
-- The video is not copied: the stack finds it beside the examples, from
-- its own file. The original stack has no pictures or other assets, so
-- nothing is copied from it. build-examples.livecodescript runs exBuild
-- with the builder in use.

constant kLeft = 256
constant kTop = 104
constant kRight = 1000
constant kBottom = 616
-- A program card's stage ends here
constant kNarrowRight = 600
-- The colour of a screen with nothing on it
constant kScreen = "2,6,23"

command exBuild pFolder
   local tInfo, tStack, tErrors, tPath
   exUseScripts the script of me
   -- (icons the kit does not have, from Lucide 0.469.0, ISC licence;
   -- play-solid and pause-solid are Lucide's play and pause, filled, and
   -- stop-solid is a filled square drawn here, smaller than Lucide's
   -- square, to sit beside them)
   exAddIcon "play-solid", "<polygon points='6 3 20 12 6 21 6 3' fill='currentColor'/>"
   exAddIcon "pause-solid", "<rect x='14' y='4' width='4' height='16' rx='1' fill='currentColor'/><rect x='6' y='4' width='4' height='16' rx='1' fill='currentColor'/>"
   exAddIcon "stop-solid", "<rect width='14' height='14' x='5' y='5' rx='2' fill='currentColor'/>"
   exAddIcon "repeat", "<path d='m17 2 4 4-4 4'/><path d='M3 11v-1a4 4 0 0 1 4-4h14'/><path d='m7 22-4-4 4-4'/><path d='M21 13v1a4 4 0 0 1-4 4H3'/>"
   exAddIcon "clock", "<circle cx='12' cy='12' r='10'/><polyline points='12 6 12 12 16 14'/>"
   exAddIcon "gauge", "<path d='m12 14 4-4'/><path d='M3.34 19a10 10 0 1 1 17.32 0'/>"
   exAddIcon "video-off", "<path d='M10.66 6H14a2 2 0 0 1 2 2v2.5l5.248-3.062A.5.5 0 0 1 22 7.87v8.196'/><path d='M16 16a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2'/><path d='m2 2 20 20'/>"
   exAddIcon "sliders-horizontal", "<line x1='21' x2='14' y1='4' y2='4'/><line x1='10' x2='3' y1='4' y2='4'/><line x1='21' x2='12' y1='12' y2='12'/><line x1='8' x2='3' y1='12' y2='12'/><line x1='21' x2='16' y1='20' y2='20'/><line x1='12' x2='3' y1='20' y2='20'/><line x1='14' x2='14' y1='2' y2='6'/><line x1='8' x2='8' y1='10' y2='14'/><line x1='16' x2='16' y1='18' y2='22'/>"
   put "Play a Video" into tInfo["name"]
   put "from OpenXTalk Lite's demos" into tInfo["credit"]
   put "film" into tInfo["icon"]
   put lkColor("rose") into tInfo["accent"]
   put lkColor("violet") into tInfo["accent2"]
   put "Step" into tInfo["noun"]
   put "stack" into tInfo["script"]
   put "Start|Play a Video|A video, a player and three buttons, in a few lines of xTalk.|film|front" & return & \
         "Three Buttons|Three Buttons|The original program: one button gives the player its video, two play and stop it.|mouse-pointer-click|program" & return & \
         "Theater|Theater|The same player, with a time line, speeds and a loop. Space plays, the arrows skip.|monitor-play|wide keys" & return & \
         "Properties|Properties|What a player tells a script, and what a script can set.|sliders-horizontal|page" into tInfo["cards"]
   lock messages
   put exNewStack(tInfo) into tStack
   exAddCards
   buildFront
   buildThreeButtons
   buildTheater
   buildProperties
   unlock messages
   put exCheck(tStack) into tErrors
   if tErrors is not empty then
      throw "scripts that do not compile:" & return & tErrors
   end if
   put pFolder & "/Play a Video.oxtstack" into tPath
   exSave tStack, tPath
   return tPath
end exBuild

################################################################################
#
# Helpers
#

-- A white panel with an icon on a tint, a bold title and words under it
private command infoPanel pName, pRect, pIcon, pTitle, pText
   local tObj, tLeft, tTop, tRight
   put item 1 of pRect into tLeft
   put item 2 of pRect into tTop
   put item 3 of pRect into tRight
   get lkGroup(pName, pRect, empty)
   put exPanel(pName & "_bg", pRect, pName) into tObj
   iconTile pName & "_icon", pIcon, tLeft + 20, tTop + 20, 40, lkColor("rose"), pName
   put lkLabel(pName & "_title", lkR(tLeft + 76, tTop + 22, tRight - 20, tTop + 42), pTitle, 15, lkColor("ink"), pName) into tObj
   set the textStyle of tObj to "bold"
   put lkLabel(pName & "_text", lkR(tLeft + 76, tTop + 48, tRight - 22, item 4 of pRect - 16), pText, 13, lkColor("soft"), pName) into tObj
end infoPanel

-- An icon on a rounded square of a tint of its colour
private command iconTile pName, pIcon, pLeft, pTop, pSize, pColor, pGroup
   local tInset
   get lkBox(pName & "Bg", lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), lkMix("255,255,255", pColor, 0.12), 11, pGroup)
   put pSize div 4 into tInset
   get exIcon(pName, pIcon, pColor, lkR(pLeft + tInset, pTop + tInset, pLeft + pSize - tInset, pTop + pSize - tInset), pGroup)
end iconTile

-- A round button with an icon in the middle, which lights up under the
-- pointer (the window's script lights a group with cRest and cLit)
private command roundButton pName, pIcon, pLeft, pTop, pSize, pBack, pInk, pLine, pGroup
   local tObj, tIcon, tInset
   get lkGroup(pName, lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), pGroup)
   put lkOval(pName & "_bg", lkR(pLeft, pTop, pLeft + pSize, pTop + pSize), pBack, pName) into tObj
   if pLine is not empty then
      lkBorder tObj, pLine
   end if
   put round(pSize * 0.28) into tInset
   put lkR(pLeft + tInset, pTop + tInset, pLeft + pSize - tInset, pTop + pSize - tInset) into tIcon
   get exIcon(pName & "_icon", pIcon, pInk, tIcon, pName)
   set the cRest of group pName to pBack
   if pBack is "255,255,255" then
      set the cLit of group pName to lkMix("255,255,255", lkColor("rose"), 0.08)
   else
      set the cLit of group pName to lkMix(pBack, "255,255,255", 0.16)
   end if
end roundButton

-- Makes the button pName (an exButton) pBy narrower, its icon and label
-- staying in its middle. (Its left stays where it is: a group whose rect
-- is set to a new left moves what is in it as well)
private command narrowButton pName, pBy
   local tRect
   put the rect of graphic (pName & "_bg") of group pName into tRect
   subtract pBy from item 3 of tRect
   set the rect of graphic (pName & "_bg") of group pName to tRect
   set the left of control (pName & "_icon") of group pName to the left of control (pName & "_icon") of group pName - pBy div 2
   set the left of field (pName & "_label") of group pName to the left of field (pName & "_label") of group pName - pBy div 2
   set the rect of group pName to tRect
end narrowButton

-- A field of code: its text in colour (the kit's colours, for a dark panel),
-- a fixed line height. The code font is chosen when the card opens
private function codeField pName, pRect, pText, pSize, pLineHeight, pGroup
   local tObj
   put lkLabel(pName, pRect, empty, pSize, lkColor("codeInk"), pGroup) into tObj
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to pLineHeight
   set the dontWrap of tObj to true
   set the htmlText of tObj to lkCodeHtml(pText)
   return tObj
end codeField

################################################################################
#
# The cards
#

-- The front page: what this is, a tile for each step, what it teaches and
-- where it came from
private command buildFront
   local tObj, tIndex, tTop, tRows
   go card "Start"
   exHero lkR(kLeft, kTop, kRight, 272), lkColor("violet") & "|" & lkColor("rose"), \
         "FROM OPENXTALK LITE'S DEMOS  " & numToCodepoint(183) & "  REMASTERED FOR OXT-BEYOND, 2026", \
         "A video player, in three buttons", \
         "The original is a player and three buttons: one gives the player its video, one plays it and one " & \
         "stops it. They are here as they were, and they grow into a theater with a time line, speeds and a loop."
   exProgramTiles 288, 3, 60, 12
   -- What it teaches, a line each
   get lkGroup("Learn", lkR(kLeft, 360, 620, kBottom), empty)
   put exPanel("Learn_bg", lkR(kLeft, 360, 620, kBottom), "Learn") into tObj
   put lkLabel("Learn_title", lkR(kLeft + 20, 380, 600, 400), "What you will learn", 15, lkColor("ink"), "Learn") into tObj
   set the textStyle of tObj to "bold"
   put "film|Give a player its video, with its filename." & return & \
         "play|Play it and stop it, with its paused." & return & \
         "clock|Show its time, with currentTime." & return & \
         "gauge|Play it faster or slower, with playRate." into tRows
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 4
      put 414 + (tIndex - 1) * 48 into tTop
      iconTile "Learn_icon" & tIndex, item 1 of line tIndex of tRows, kLeft + 20, tTop, 36, lkColor("rose"), "Learn"
      -- (room for a second line, where a computer's font is wider)
      put lkLabel("Learn_text" & tIndex, lkR(kLeft + 68, tTop + 9, 604, tTop + 46), item 2 of line tIndex of tRows, 13, \
            lkColor("soft"), "Learn") into tObj
   end repeat
   set the itemDelimiter to comma
   -- Where it came from
   infoPanel "Origin", lkR(636, 360, kRight, kBottom), "heart", "Where it came from", \
         "The three buttons came with OpenXTalk Lite's demos, and so did the video they play: a segmented " & \
         "button being made in xTalk. Neither says who made it."
   put lkLabel("Origin_note", lkR(712, 500, 980, 600), \
         "A player needs help to show a video: on Linux, OXT-Beyond plays it with mplayer, and in a browser, " & \
         "with the browser's own player.", 12, lkColor("soft"), "Origin") into tObj
end buildFront

-- The original program, on a program card: the three buttons and the
-- player. The names are the original's: player "a", buttons "set
-- filename", "play" and "stop"
private command buildThreeButtons
   local tObj, tAccent, tTop, tRows, tIndex, tWidth, tOver
   go card "Three Buttons"
   put lkColor("rose") into tAccent
   -- The buttons, where the original has them: "set filename" at the
   -- left, "play" and "stop" at the right
   put exButton("set filename", kLeft + 16, 120, 36, "Set filename", "folder-open", "ghost", tAccent, empty, empty, 0) into tWidth
   set the script of group "set filename" to exScript("Three Buttons/set filename")
   add exButton("play", kLeft + 160, 120, 36, "Play", "play-solid", "primary", tAccent, empty, empty, 0) to tWidth
   set the script of group "play" to exScript("Three Buttons/play")
   add exButton("stop", kLeft + 252, 120, 36, "Stop", "stop-solid", "ghost", tAccent, empty, empty, 0) to tWidth
   set the script of group "stop" to exScript("Three Buttons/stop")
   -- (at the kit's padding the three are a few points wider than the row
   -- with 8 between them: each gives up the same part of its padding, so
   -- that they fit with the same 8 between each two)
   put tWidth + 2 * 8 - (kNarrowRight - kLeft - 2 * 16) into tOver
   if tOver > 0 then
      repeat for each item tObj in "set filename,play,stop"
         narrowButton tObj, 2 * ((tOver + 5) div 6)
      end repeat
   end if
   set the left of group "set filename" to kLeft + 16
   set the left of group "play" to the right of group "set filename" + 8
   set the left of group "stop" to the right of group "play" + 8
   -- The player, with its controller as the original has it, on a dark
   -- bezel. (Its video is 1028 by 582, as the original's player was: here
   -- it is 300 wide, and the controller is 26 high under it)
   put lkBox("a_bezel", lkR(kLeft + 16, 172, kNarrowRight - 16, 380), kScreen, 14, empty) into tObj
   lkShadow tObj, 14, 4, 20
   create player "a"
   put it into tObj
   set the rect of tObj to kLeft + 22, 178, kNarrowRight - 22, 374
   set the showController of tObj to true
   set the showBorder of tObj to false
   -- (the part of the movie played, in the controller, is in the player's
   -- hiliteColor)
   set the hiliteColor of tObj to tAccent
   -- A dark screen over the place of the picture, which a video draws
   -- over: a player draws that place in a stipple until it plays
   put lkBox("a_screen", lkR(kLeft + 22, 178, kNarrowRight - 22, 348), kScreen, 0, empty) into tObj
   get exIcon("a_film", "film", lkColor("soft"), lkR(412, 247, 444, 279), empty)
   -- What the player has: a note, which "set filename" fills in
   put lkBox("Note_bg", lkR(kLeft + 16, 392, kNarrowRight - 16, 474), lkMix("255,255,255", lkColor("bg"), 0.6), 12, empty) into tObj
   lkBorder tObj, lkColor("line")
   get exIcon("Note_info", "info", lkColor("sky"), lkR(kLeft + 30, 404, kLeft + 48, 422), empty)
   get exIcon("Note_ok", "check", lkColor("emerald"), lkR(kLeft + 30, 404, kLeft + 48, 422), empty)
   get exIcon("Note_alert", "triangle-alert", lkColor("amber"), lkR(kLeft + 30, 404, kLeft + 48, 422), empty)
   hide image "Note_ok"
   hide image "Note_alert"
   put lkLabel("Note", lkR(kLeft + 58, 405, kNarrowRight - 28, 470), \
         "Press Set filename, to give the player its video.", 13, lkColor("soft"), empty) into tObj
   -- What each button does
   put lkLabel("Does_title", lkR(kLeft + 16, 488, kNarrowRight - 16, 502), "WHAT EACH BUTTON DOES", 11, tAccent, empty) into tObj
   set the textStyle of tObj to "bold"
   put "set filename|gives the player its video" & return & \
         "play|sets its paused to false" & return & \
         "stop|sets its paused to true" into tRows
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 3
      put 508 + (tIndex - 1) * 31 into tTop
      put lkBox("Does_chip" & tIndex, lkR(kLeft + 16, tTop, kLeft + 120, tTop + 24), lkMix("255,255,255", tAccent, 0.1), 8, empty) into tObj
      put lkLabel("Does_name" & tIndex, lkR(kLeft + 16, tTop + 6, kLeft + 120, tTop + 22), item 1 of line tIndex of tRows, 12, tAccent, empty, "center") into tObj
      set the textStyle of tObj to "bold"
      put lkLabel("Does_text" & tIndex, lkR(kLeft + 132, tTop + 5, kNarrowRight - 16, tTop + 21), item 2 of line tIndex of tRows, 13, \
            lkColor("soft"), empty) into tObj
   end repeat
   set the itemDelimiter to comma
end buildThreeButtons

-- The theater, on a wide card: a screen with the player on it, and under
-- it a bar with the time line and the buttons
private command buildTheater
   local tObj, tAccent, tWidth
   go card "Theater"
   put lkColor("rose") into tAccent
   set the script of this card to exScript("Theater/card")
   -- The screen, and the player on it: 720 by 408, as the video is 1028
   -- by 582
   put lkBox("Screen", lkR(kLeft, kTop, kRight, 536), kScreen, 18, empty) into tObj
   lkShadow tObj, 18, 6, 30
   create player "Movie"
   put it into tObj
   set the rect of tObj to kLeft + 12, kTop + 12, kRight - 12, 524
   set the showController of tObj to false
   set the showBorder of tObj to false
   set the traversalOn of tObj to false
   set the backgroundColor of tObj to kScreen
   set the script of tObj to exScript("Theater/Movie")
   -- (a dark screen over it, which the video draws over: a player draws
   -- its place in a stipple until it plays)
   put lkBox("Movie_screen", lkR(kLeft + 12, kTop + 12, kRight - 12, 524), kScreen, 0, empty) into tObj
   -- Before it plays: a big play button, and the video's name
   get lkGroup("Poster", lkR(kLeft, kTop, kRight, 536), empty)
   get lkBox("Poster_anchor", lkR(kLeft, kTop, kLeft + 1, kTop + 1), empty, 0, "Poster")
   put lkOval("Poster_circle", lkR(588, 252, 668, 332), tAccent, "Poster") into tObj
   lkGlow tObj, tAccent, 24, 60
   get exIcon("Poster_play", "play-solid", "255,255,255", lkR(614, 276, 646, 308), "Poster")
   put lkLabel("Poster_title", lkR(388, 350, 868, 370), "neville-segments.mp4", 15, "255,255,255", "Poster", "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Poster_text", lkR(388, 376, 868, 394), "Press play, or the space bar", 12, lkColor("muted"), "Poster", "center") into tObj
   set the script of group "Poster" to exScript("Theater/Poster")
   -- When it cannot play: why, in the middle of the screen
   get lkGroup("Notice", lkR(kLeft, kTop, kRight, 536), empty)
   get lkBox("Notice_anchor", lkR(kLeft, kTop, kLeft + 1, kTop + 1), empty, 0, "Notice")
   put lkBox("Notice_tile", lkR(600, 236, 656, 292), lkMix(kScreen, "255,255,255", 0.1), 16, "Notice") into tObj
   get exIcon("Notice_off", "video-off", lkMix(tAccent, "255,255,255", 0.3), lkR(614, 250, 642, 278), "Notice")
   put lkLabel("Notice_title", lkR(388, 310, 868, 332), empty, 17, "255,255,255", "Notice", "center") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Notice_text", lkR(418, 340, 838, 400), empty, 13, lkColor("sideInk"), "Notice", "center") into tObj
   hide group "Notice"
   -- The bar: play and pause, stop, the time line between the time and
   -- the length, the speed, the loop, and another video
   get lkGroup("Controls", lkR(kLeft, 548, kRight, kBottom), empty)
   put exPanel("Controls_bg", lkR(kLeft, 548, kRight, kBottom), "Controls") into tObj
   roundButton "PlayPause", "play-solid", kLeft + 16, 560, 44, tAccent, "255,255,255", empty, "Controls"
   set the name of image "PlayPause_icon" to "PlayPause_play"
   get exIcon("PlayPause_pause", "pause-solid", "255,255,255", the rect of image "PlayPause_play", "PlayPause")
   hide image "PlayPause_pause"
   roundButton "Stop", "stop-solid", kLeft + 68, 564, 36, "255,255,255", lkColor("soft"), lkColor("line"), "Controls"
   put lkLabel("Now", lkR(kLeft + 112, 574, kLeft + 160, 590), "0:00", 13, lkColor("ink"), "Controls", "right") into tObj
   set the textStyle of tObj to "bold"
   -- (the time line: a track, the part played, and a knob where it is; a
   -- white box under them takes the clicks between them)
   get lkGroup("Timeline", lkR(kLeft + 172, 566, 772, 598), "Controls")
   put lkBox("Timeline_hit", lkR(kLeft + 172, 566, 772, 598), "255,255,255", 0, "Timeline") into tObj
   put lkBox("Track", lkR(kLeft + 180, 579, 764, 585), lkColor("line"), 3, "Timeline") into tObj
   put lkBox("Played", lkR(kLeft + 180, 579, kLeft + 186, 585), tAccent, 3, "Timeline") into tObj
   hide tObj
   put lkOval("Knob", lkR(kLeft + 173, 575, kLeft + 187, 589), "255,255,255", "Timeline") into tObj
   lkBorder tObj, tAccent
   set the lineSize of tObj to 2
   lkShadow tObj, 4, 1, 25
   put lkLabel("Length", lkR(780, 574, 828, 590), "0:00", 13, lkColor("muted"), "Controls") into tObj
   put exButton("Speed", 836, 566, 32, "1" & numToCodepoint(215), empty, "ghost", tAccent, "Controls", empty, 60) into tWidth
   -- (the speed's label takes the button's width, as its text changes)
   set the rect of field "Speed_label" to 836, the top of field "Speed_label", 836 + tWidth, the bottom of field "Speed_label"
   set the textAlign of field "Speed_label" to "center"
   roundButton "Loop", "repeat", 904, 564, 36, "255,255,255", lkColor("soft"), lkColor("line"), "Controls"
   set the name of image "Loop_icon" to "Loop_off"
   get exIcon("Loop_on", "repeat", tAccent, the rect of image "Loop_off", "Loop")
   hide image "Loop_on"
   set the cOff of group "Loop" to "255,255,255"
   set the cLine of group "Loop" to lkColor("line")
   set the cOn of group "Loop" to lkMix("255,255,255", tAccent, 0.14)
   set the cOnLine of group "Loop" to lkMix("255,255,255", tAccent, 0.5)
   roundButton "Choose", "folder-open", 948, 564, 36, "255,255,255", lkColor("soft"), lkColor("line"), "Controls"
   set the script of group "Controls" to exScript("Theater/Controls")
end buildTheater

-- The player's properties: what each is, and what the Theater's player
-- has; and a few lines that use them
private command buildProperties
   local tObj, tRows, tIndex, tTop, tName
   go card "Properties"
   set the script of this card to exScript("Properties/card")
   get lkGroup("Table", lkR(kLeft, kTop, kRight, 456), empty)
   put exPanel("Table_bg", lkR(kLeft, kTop, kRight, 456), "Table") into tObj
   put lkLabel("Table_head1", lkR(276, 122, 420, 136), "PROPERTY", 11, lkColor("muted"), "Table") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Table_head2", lkR(436, 122, 790, 136), "WHAT IT IS", 11, lkColor("muted"), "Table") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("Table_head3", lkR(812, 122, 984, 136), "IN THE THEATER NOW", 11, lkColor("muted"), "Table") into tObj
   set the textStyle of tObj to "bold"
   put "filename|The video's file: its path, or a web address." & return & \
         "paused|true while it does not play: false plays it." & return & \
         "currentTime|Where it is in the movie, in the movie's units." & return & \
         "duration|How long the movie is, in the same units." & return & \
         "timeScale|How many of those units make a second." & return & \
         "playRate|How fast it plays: 1 as it was made, 2 twice as fast." & return & \
         "looping|true: at its end it starts again." & return & \
         "showController|true: the player draws its own play button and bar." into tRows
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 8
      put 146 + (tIndex - 1) * 34 into tTop
      put lkBox("Table_rule" & tIndex, lkR(272, tTop - 4, 984, tTop - 3), lkColor("line"), 0, "Table") into tObj
      put item 1 of line tIndex of tRows into tName
      put lkLabel("Prop_" & tName, lkR(276, tTop + 6, 430, tTop + 24), tName, 13, lkColor("rose"), "Table") into tObj
      set the textStyle of tObj to "bold"
      put lkLabel("Prop_text" & tIndex, lkR(436, tTop + 6, 800, tTop + 24), item 2 of line tIndex of tRows, 13, lkColor("soft"), "Table") into tObj
      put lkLabel("Now_" & tName, lkR(812, tTop + 6, 984, tTop + 24), "-", 13, lkColor("ink"), "Table") into tObj
      set the dontWrap of tObj to true
   end repeat
   set the itemDelimiter to comma
   put lkLabel("Table_note", lkR(276, 424, 984, 440), \
         "On Linux, a player asks mplayer for its movie's length: without mplayer, its duration is 0.", \
         12, lkColor("muted"), "Table") into tObj
   -- The lines, on a dark panel
   put lkBox("Code_bg", lkR(kLeft, 472, kRight, kBottom), lkColor("code"), 18, empty) into tObj
   lkShadow tObj, 18, 6, 30
   get lkOval("Code_dot1", lkR(kLeft + 18, 489, kLeft + 28, 499), "248,113,113", empty)
   get lkOval("Code_dot2", lkR(kLeft + 34, 489, kLeft + 44, 499), "251,191,36", empty)
   get lkOval("Code_dot3", lkR(kLeft + 50, 489, kLeft + 60, 499), "52,211,153", empty)
   put lkLabel("Code_caption", lkR(kLeft + 72, 487, 980, 503), "how a script uses them", 11, "100,116,139", empty) into tObj
   -- (its letters level with the dots)
   exMiddle tObj, 494
   put codeField("Code", lkR(kLeft + 20, 512, kRight - 16, 608), exScript("properties-code"), 12, 19, empty) into tObj
end buildProperties

################################################################################
#
# The scripts that go into the stack
#

/*@ stack
--Play a Video: the Video Player of OpenXTalk Lite's demos, remastered for OXT-Beyond in 2026
--The original names no author and has no dated comments.
--It came with the video it plays, neville-segments.mp4, which does not say who made it either.

--Each card's program is in the scripts of the card and its controls.
--The scripts panel beside the stage shows them (on the wide card, the drawer that the Scripts button opens).

--Why a video cannot play here, in words, or empty if it should play.
--The Three Buttons and the Theater ask it before they play
function videoTrouble pPath
   if pPath is empty then
      return "The player has no video yet."
   end if
   if there is no file pPath then
      return "The video is not where the script looks for it: " & pPath
   end if
   if the platform is "Linux" and there is no file "/usr/bin/mplayer" then
      return "On Linux, OXT-Beyond plays a video with mplayer, which this computer does not have." && \
            "Install mplayer, then try again."
   end if
   return empty
end videoTrouble

--Why a video that should have played did not, in words
function whyNot
   switch the platform
      case "Win32"
         return "Windows could not open this video. It plays video with DirectShow, which needs an extra" && \
               "codec for some kinds of video, MP4 among them."
      case "HTML5"
         return "This browser could not play this video. Try another one, or the desktop IDE."
      case "Linux"
         return "mplayer could not open this video. Try another one."
   end switch
   return "This computer could not open this video. Try another one."
end whyNot

--The note under the player of the Three Buttons, after "set filename": can it play what it has?
command showHow pPath
   local tTrouble, tTry
   put videoTrouble(pPath) into tTrouble
   if tTrouble is empty and the platform is not "Linux" then
      --(a player that can play its movie knows its length by now; on Linux it asks mplayer, so there the note says only that mplayer is there)
      repeat with tTry = 1 to 30
         if the duration of player "a" > 0 then
            exit repeat
         end if
         wait 100 milliseconds with messages
      end repeat
      if the duration of player "a" is 0 then
         put whyNot() into tTrouble
      end if
   end if
   if tTrouble is empty then
      setNote "ok", "The player has its video. Press Play."
   else
      setNote "alert", tTrouble
   end if
end showHow

command setNote pIcon, pText
   put pText into field "Note"
   set the visible of image "Note_info" to (pIcon is "info")
   set the visible of image "Note_ok" to (pIcon is "ok")
   set the visible of image "Note_alert" to (pIcon is "alert")
end setNote

--On Linux, a player's video is a window of its own, which stays where the player is when its card closes.
--So the player of the Three Buttons waits off the card while another card is open (the Theater moves its own)
on closeCard
   if there is a player "a" and the left of player "a" > -1000 then
      set the cHome of player "a" to the rect of player "a"
      set the rect of player "a" to -1000, -1000, -1000 + the width of player "a", -1000 + the height of player "a"
   end if
   pass closeCard
end closeCard

on preOpenCard
   if there is a player "a" and the cHome of player "a" is not empty then
      set the rect of player "a" to the cHome of player "a"
   end if
   pass preOpenCard
end preOpenCard
@*/

/*@ Three Buttons/set filename
--(Remastered for OXT-Beyond, 2026: the lines marked "(2026)" are new or changed, and say why)
on mousedown
   local myLongFilename  --(2026) declared, for strict compilation
   put the long name of this stack into myLongFilename
   replace QUOTE with "" in myLongFilename
   set the itemdelimiter to slash
   if word 1 of myLongFilename is "stack" then delete word 1 of myLongFilename
   delete last item of myLongFilename
   delete last item of myLongFilename  --(2026) this stack is in Remastered, in the folder the video is in
   put myLongFilename & slash & "neville-segments.mp4" into myLongFilename
   put myLongFilename
   set the filename of player "a" to myLongFilename
   showHow myLongFilename  --(2026) the note under the player: can it play the video here?
end mousedown
@*/

/*@ Three Buttons/play
on mousedown
   set the paused of player "a" to false
end mousedown
@*/

/*@ Three Buttons/stop
on mousedown
   set the paused of player "a" to true
end mousedown
@*/

/*@ Theater/card
--The Theater: the player of the Three Buttons, grown into a player with a time line, speeds and a loop.
--It plays a video as the original does, with the player's filename and its paused.
--The bar under the screen reads the player's currentTime, duration and timeScale, and sets its playRate and looping.
--The space bar plays and pauses, and the arrow keys skip back and on.

constant kSkip = 5  --seconds the arrow keys skip
constant kSpeeds = "1,1.5,2,0.5"  --the speeds the speed button goes through

local sSpeed  --which of them, by number
local sTicking  --the message that keeps the bar up to date, while this card is open
local sTrouble  --why the video cannot play here, or empty
local sPlaying  --true while the movie plays (on Linux, a player that has not played yet says it is not paused)
local sChecking  --the message that checks that it plays
local sPlayed  --true once the movie has shown its length: it can play here
local sMovie  --the video to play (the player has it only when it can play it here)
local sAway  --true while the movie is out of sight for the drawer of scripts

on openCard
   if sSpeed is empty then
      put 1 into sSpeed
   end if
   put false into sPlaying
   if sMovie is empty then
      put the filename of player "Movie" into sMovie  --(a video chosen before the stack was saved)
      if sMovie is empty then
         put sampleMovie() into sMovie
      end if
      loadMovie sMovie
   else if sTrouble is not empty then
      loadMovie sMovie  --(it may play now: say, mplayer is there now)
   else
      showPoster
   end if
   showTime
   startTicking
   pass openCard
end openCard

on closeCard
   stopTicking
   set the paused of player "Movie" to true  --(the movie waits for this card)
   put false into sPlaying
   placeMovie false  --(on Linux its window would stay over the next card)
   put false into sAway
   pass closeCard
end closeCard

on keyDown pKey  --the space bar plays and pauses
   if pKey is space then
      playPause
   else
      pass keyDown
   end if
end keyDown

on arrowKey pKey  --left and right skip back and on
   if pKey is "left" then
      skipBy -kSkip
   else if pKey is "right" then
      skipBy kSkip
   else
      pass arrowKey
   end if
end arrowKey

-- The video that came with the original: beside the examples, a folder up from this stack's own
function sampleMovie
   local tPath
   put the effective filename of this stack into tPath
   set the itemDelimiter to slash
   return item 1 to -3 of tPath & "/neville-segments.mp4"
end sampleMovie

-- Gives the player a video: ready to play, or why it cannot play here
command loadMovie pPath
   set the paused of player "Movie" to true
   put false into sPlaying
   put false into sPlayed
   put pPath into sMovie
   placeMovie false  --(out of sight until it plays)
   put videoTrouble(pPath) into sTrouble  --(the stack's script says)
   if sTrouble is empty then
      set the filename of player "Movie" to pPath
   else
      set the filename of player "Movie" to empty  --(on Linux, a player opens a window for its video even when it cannot play it)
   end if
   set the itemDelimiter to slash
   put the last item of pPath into field "Poster_title"
   set the itemDelimiter to comma
   if sTrouble is empty then
      showPoster
   else
      showNotice "It cannot play here yet", sTrouble
   end if
   showTime
end loadMovie

-- Asks for a video, and gives it to the player
command chooseMovie
   local tPath, tTypes
   put "Videos|mp4,m4v,mov,avi,wmv," into tTypes  --the kinds of video a player may play
   put "mpg,mpeg,webm,ogv,mkv|" after tTypes
   answer file "Choose a video to play:" with type tTypes
   put it into tPath
   if tPath is empty then
      exit chooseMovie  --(Cancel)
   end if
   loadMovie tPath
end chooseMovie

-- Plays the movie, or pauses it
command playPause
   if sTrouble is not empty or the filename of player "Movie" is empty then
      exit playPause
   end if
   if sPlaying is not true then
      if the duration of player "Movie" > 0 and the currentTime of player "Movie" >= the duration of player "Movie" then
         set the currentTime of player "Movie" to 0  --(at its end: from the start again)
      end if
      hide group "Poster"
      placeMovie true
      set the paused of player "Movie" to false
      set the playRate of player "Movie" to item sSpeed of kSpeeds  --(once it plays: a playRate of 0 is a pause)
      put true into sPlaying
      if sChecking is not empty then
         cancel sChecking
      end if
      send "checkPlaying 0" to me in 100 milliseconds
      put the result into sChecking
   else
      set the paused of player "Movie" to true
      put false into sPlaying
   end if
   showTime
end playPause

-- A movie that plays has a length: one that has none after three seconds cannot play here
on checkPlaying pTry
   put empty into sChecking
   set the defaultStack to the short name of the owner of me
   if the long id of this card is not the long id of me or sPlaying is not true or the duration of player "Movie" > 0 then
      exit checkPlaying
   end if
   if pTry < 30 then
      send "checkPlaying" && pTry + 1 to me in 100 milliseconds
      put the result into sChecking
   else
      set the paused of player "Movie" to true
      put false into sPlaying
      put whyNot() into sTrouble  --(the stack's script says)
      showNotice "It did not play", sTrouble
      showTime
   end if
end checkPlaying

-- Stop: the movie paused, back at its start
command stopMovie
   if sTrouble is not empty then
      exit stopMovie
   end if
   set the paused of player "Movie" to true
   put false into sPlaying
   set the currentTime of player "Movie" to 0
   showPoster
   showTime
end stopMovie

-- Skips pSeconds on, or back if pSeconds is less than 0
command skipBy pSeconds
   local tScale, tTime
   put the timeScale of player "Movie" into tScale
   if sTrouble is not empty or the duration of player "Movie" <= 0 or tScale <= 0 then
      exit skipBy
   end if
   put the currentTime of player "Movie" + pSeconds * tScale into tTime
   set the currentTime of player "Movie" to max(0, min(the duration of player "Movie", tTime))
   showTime
end skipBy

-- The time line: the movie goes to the time at pX along it
command seekTo pX
   local tLength, tAt
   put the duration of player "Movie" into tLength
   if sTrouble is not empty or tLength <= 0 then
      exit seekTo
   end if
   put max(0, min(1, (pX - the left of graphic "Track") / the width of graphic "Track")) into tAt
   set the currentTime of player "Movie" to round(tAt * tLength)
   drawTime round(tAt * tLength), tLength, the timeScale of player "Movie"
end seekTo

-- The speeds in turn: as it was made, faster, fastest, slower
command nextSpeed
   put sSpeed mod the number of items of kSpeeds + 1 into sSpeed
   put item sSpeed of kSpeeds & numToCodepoint(215) into field "Speed_label"
   if sPlaying is true then
      set the playRate of player "Movie" to item sSpeed of kSpeeds
   end if
end nextSpeed

-- Looping, or not: a looping movie starts again at its end
command toggleLoop
   local tLoop
   put not the looping of player "Movie" into tLoop
   set the looping of player "Movie" to tLoop
   set the visible of image "Loop_on" to tLoop
   set the visible of image "Loop_off" to not tLoop
   if tLoop then
      set the cRest of group "Loop" to the cOn of group "Loop"
      set the foregroundColor of graphic "Loop_bg" to the cOnLine of group "Loop"
   else
      set the cRest of group "Loop" to the cOff of group "Loop"
      set the foregroundColor of graphic "Loop_bg" to the cLine of group "Loop"
   end if
   set the backgroundColor of graphic "Loop_bg" to the cRest of group "Loop"
end toggleLoop

-- The bar, as the player is now
command showTime
   local tLength
   put the duration of player "Movie" into tLength
   if tLength > 0 then
      put true into sPlayed
   end if
   drawTime the currentTime of player "Movie", tLength, the timeScale of player "Movie"
   set the visible of image "PlayPause_play" to (sPlaying is not true)
   set the visible of image "PlayPause_pause" to (sPlaying is true)
end showTime

-- The bar from three numbers: where the movie is, its length, and the units in a second
command drawTime pNow, pLength, pScale
   local tAt, tX
   put timeText(pNow, pScale) into field "Now"
   put timeText(pLength, pScale) into field "Length"
   put 0 into tAt
   if pLength is a number and pLength > 0 then
      put max(0, min(1, pNow / pLength)) into tAt
   end if
   put the left of graphic "Track" + round(tAt * the width of graphic "Track") into tX
   set the rect of graphic "Played" to the left of graphic "Track", the top of graphic "Track", \
         max(tX, the left of graphic "Track" + the height of graphic "Track"), the bottom of graphic "Track"
   set the visible of graphic "Played" to (tAt > 0)
   set the loc of graphic "Knob" to tX, item 2 of the loc of graphic "Track"
end drawTime

-- A time in minutes and seconds, "1:05", from a number of units and the units in a second
function timeText pUnits, pScale
   local tSeconds
   if pUnits is not a number or pScale is not a number or pScale <= 0 then
      return "0:00"
   end if
   put round(pUnits / pScale) into tSeconds
   return tSeconds div 60 & ":" & format("%02d", tSeconds mod 60)
end timeText

-- Ready to play: the big play button on the screen
command showPoster
   hide group "Notice"
   placeMovie false
   show group "Poster"
end showPoster

-- Why it cannot play, on the screen in place of the movie
command showNotice pTitle, pText
   local tTop
   hide group "Poster"
   placeMovie false
   put pTitle into field "Notice_title"
   put pText into field "Notice_text"
   set the height of field "Notice_text" to the formattedHeight of field "Notice_text" + 4
   put item 2 of the loc of graphic "Screen" - (56 + 18 + 22 + 8 + the height of field "Notice_text") div 2 into tTop
   set the top of graphic "Notice_tile" to tTop
   set the loc of image "Notice_off" to the loc of graphic "Notice_tile"
   set the top of field "Notice_title" to tTop + 56 + 18 - 4
   set the top of field "Notice_text" to the bottom of field "Notice_title" + 8
   show group "Notice"
end showNotice

-- The movie in its place on the screen, or out of sight. A movie is drawn above everything (on
-- Linux, in a window of its own, which hiding the player does not hide): so the poster, the notice
-- and the drawer of scripts are seen only while the movie is moved off the card
command placeMovie pShown
   if pShown then
      set the rect of player "Movie" to the rect of graphic "Movie_screen"
   else
      set the rect of player "Movie" to -1000, -1000, -1000 + the width of graphic "Movie_screen", \
            -1000 + the height of graphic "Movie_screen"
   end if
end placeMovie

-- The drawer of scripts slides over the screen: the movie waits out of sight while it is open
command followDrawer
   local tOpen
   put there is a group "Scripts" and the visible of group "Scripts" into tOpen
   if tOpen and the left of player "Movie" >= 0 then
      set the paused of player "Movie" to true
      put false into sPlaying
      placeMovie false
      put true into sAway
   else if not tOpen and sAway then
      put false into sAway
      placeMovie true
   end if
end followDrawer

-- While this card is open, the bar follows the movie, four times a second
command startTicking
   if sTicking is empty then
      send "followMovie" to me in 250 milliseconds
      put the result into sTicking
   end if
end startTicking

command stopTicking
   if sTicking is not empty then
      cancel sTicking
      put empty into sTicking
   end if
end stopTicking

on followMovie
   put empty into sTicking
   set the defaultStack to the short name of the owner of me
   if the long id of this card is not the long id of me then
      exit followMovie
   end if
   showTime
   followDrawer
   startTicking
end followMovie

on playStopped  --the movie came to its end: ready to play again
   set the defaultStack to the short name of the owner of me
   if the long id of this card is the long id of me then
      if sPlaying is true and sPlayed is not true then  --(it stopped before it ever had a length: it did not play)
         put false into sPlaying
         put whyNot() into sTrouble  --(the stack's script says)
         showNotice "It did not play", sTrouble
      else
         put false into sPlaying
         if sTrouble is empty then
            showPoster
         end if
      end if
      showTime
   end if
   pass playStopped
end playStopped
@*/

/*@ Theater/Movie
on mouseUp  --a click on the movie plays it, or pauses it
   playPause
end mouseUp
@*/

/*@ Theater/Poster
on mouseUp  --the big play button
   playPause
end mouseUp
@*/

/*@ Theater/Controls
on mouseUp pButton  --a button of the bar: its group's name says which
   switch buttonOf(the long id of the target)
      case "PlayPause"
         playPause
         break
      case "Stop"
         stopMovie
         break
      case "Speed"
         nextSpeed
         break
      case "Loop"
         toggleLoop
         break
      case "Choose"
         chooseMovie
         break
      default
         pass mouseUp
   end switch
end mouseUp

on mouseDown pButton  --the time line: the movie follows the mouse while it is down
   if buttonOf(the long id of the target) is "Timeline" then
      seekTo the mouseH
      repeat while the mouse is down
         seekTo the mouseH
         wait 30 milliseconds with messages
      end repeat
   else
      pass mouseDown
   end if
end mouseDown

private function buttonOf pObj  --the group of the bar that pObj is in
   repeat while word 1 of pObj is not "card"
      if word 1 of pObj is "group" and the short name of pObj is not "Controls" then
         return the short name of pObj
      end if
      put the long owner of pObj into pObj
   end repeat
   return empty
end buttonOf
@*/

/*@ Properties/card
on preOpenCard  --what the Theater's player has now, and the code in a code font
   local tPlayer, tFont, tError
   put the long id of player "Movie" of card "Theater" into tPlayer
   set the itemDelimiter to slash
   put the last item of the filename of tPlayer into field "Now_filename"
   set the itemDelimiter to comma
   if field "Now_filename" is empty then
      put "(none)" into field "Now_filename"
   end if
   put the paused of tPlayer into field "Now_paused"
   put the currentTime of tPlayer into field "Now_currentTime"
   put the duration of tPlayer into field "Now_duration"
   put the timeScale of tPlayer into field "Now_timeScale"
   put the playRate of tPlayer into field "Now_playRate"
   put the looping of tPlayer into field "Now_looping"
   put the showController of tPlayer into field "Now_showController"
   if the environment is "development" and "Source Code Pro" is not among the lines of the fontNames then
      try  --(the IDE carries it for its Script Editor, as the scripts panel knows)
         start using font file (revIDESpecialFolderPath("fonts") & "/SourceCodePro-Regular.ttf")
      catch tError
      end try
   end if
   repeat for each item tFont in "Source Code Pro,Droid Sans Mono,Menlo,Consolas,DejaVu Sans Mono,Courier New"
      if tFont is among the lines of the fontNames then
         set the textFont of field "Code" to tFont
         exit repeat
      end if
   end repeat
   pass preOpenCard
end preOpenCard
@*/

/*@ properties-code
set the filename of player "Movie" to tPath  --its video
set the paused of player "Movie" to false  --it plays
put the currentTime of player "Movie" / the timeScale of player "Movie" into tSeconds
set the playRate of player "Movie" to 2  --twice as fast
set the looping of player "Movie" to true  --again and again
@*/
