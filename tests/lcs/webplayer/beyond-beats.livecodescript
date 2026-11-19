script "TestBeyondBeats"
-- OXT-Beyond: the Beyond Beats pattern studio (the committed
-- tools/web-player/stacks/Beyond Beats.oxtstack, built by
-- tools/web-player/beyond-beats.livecodescript from
-- tools/web-player/beyond-beats-stack.livecodescript), on a desktop engine.
--
-- A desktop engine has no Web Audio, so these tests drive what the stack
-- owns: the song, the screen and the file. btTestBegin opens the stack as
-- it opens in a browser, but with its song kept in a file of the test's
-- own and saved at once after every change; btState says how things are.
-- The mouse is given as points of the card (btPointerDown, btPointerMove,
-- btEndDrag), which is what the stack's mouseDown and mouseMove pass on,
-- and buttons are pressed through btPress, as their mouseUp does. What
-- the page is told (btState "json") is checked here; what the page does
-- with it, in a browser, is tools/ci/beyond_beats_check.py's.

constant kStack = "Beyond Beats"
constant kCard = "Studio"

local sSave

on TestSetup
   local tFile
   put specialFolderPath("temporary") & "/beyond-beats-test-" & the milliseconds & ".txt" into sSave
   if there is a file sSave then
      delete file sSave
   end if
   put TestGetEngineRepositoryPath() & "/tools/web-player/stacks/Beyond Beats.oxtstack" into tFile
   -- opened with its messages locked: preOpenCard would read the song
   -- from the user's own file
   lock messages
   go stack tFile
   unlock messages
   studio "btTestBegin", sSave
end TestSetup

on TestTeardown
   if there is a stack kStack then
      studio "btTestEnd"
      delete stack kStack
   end if
   if sSave is not empty and there is a file sSave then
      delete file sSave
   end if
end TestTeardown

----------------------------------------------------------------------
-- Helpers

private command studio pHandler, p1, p2, p3, p4
   dispatch pHandler to card kCard of stack kStack with p1, p2, p3, p4
end studio

private function says pFunction, p1, p2, p3, p4
   dispatch function pFunction to card kCard of stack kStack with p1, p2, p3, p4
   return the result
end says

private function st pWhat
   return says("btState", pWhat)
end st

private command press pButton
   studio "btPress", pButton
end press

private function saved
   local tText
   put url ("file:" & sSave) into tText
   return tText
end saved

private function zeros pCount
   local tText
   repeat pCount times
      put "0" after tText
   end repeat
   return tText
end zeros

-- the middle of a control of the card
private function middle pControl
   return the loc of pControl
end middle

private function pad pRow, pStep
   return the long id of graphic ("pad" && pRow & comma & pStep) of card kCard of stack kStack
end pad

private function ctl pType, pName
   if pType is "button" then
      return the long id of button pName of card kCard of stack kStack
   else if pType is "field" then
      return the long id of field pName of card kCard of stack kStack
   else if pType is "group" then
      return the long id of group pName of card kCard of stack kStack
   end if
   return the long id of graphic pName of card kCard of stack kStack
end ctl

-- a press on a pad, where it is, and let go
private command clickPad pRow, pStep, pAlt
   local tLoc
   put the loc of pad(pRow, pStep) into tLoc
   get says("btPointerDown", "pad" && pRow & comma & pStep, item 1 of tLoc, item 2 of tLoc, pAlt is true)
   studio "btEndDrag"
end clickPad

----------------------------------------------------------------------
-- Opening

on TestItOpensOnTheDemoSong
   TestAssert "three patterns", st("pats") is 3
   TestAssert "eight channels", st("chans") is 8
   TestAssert "its tempo and swing", st("bpm") is 122 and st("swing") is 18
   TestAssert "the first pattern is shown", st("cur") is 1 and st("name 1") is "Groove"
   TestAssert "four on the floor", st("row 1") is "9000900090009000" & zeros(16)
   TestAssert "the kick's name", the label of ctl("button", "chan 1") is "Kick"
   TestAssert "the bass's name", the label of ctl("button", "chan 8") is "Bass"
   TestAssert "a channel's pads to the pattern's end", the visible of pad(1, 16)
   TestAssert "no pads past it", not the visible of pad(1, 17)
   TestAssert "no ninth channel", not the visible of ctl("button", "chan 9")
   TestAssert "the pattern list", the text of ctl("field", "Patterns") is "Groove" & return & "Groove B" & return & "Fill"
   TestAssert "the tempo shown", the text of ctl("field", "Tempo") is "122"
   TestAssert "the swing shown", the text of ctl("field", "Swing Value") is "18%"
   TestAssert "the picker hidden", not the visible of ctl("group", "Picker")
end TestItOpensOnTheDemoSong

on TestTheSongIsReadBackAsItWasSaved
   local tText
   studio "btSetStep", 2, 3, 5
   studio "btSetTempo", 99
   studio "btSetPan", 4, -40
   studio "btToggleMute", 6
   put st("text") into tText
   TestAssert "every change is saved at once", saved() is tText
   -- the stack opened again, from the same file
   studio "btTestBegin", sSave
   TestAssert "the song is the one saved", st("text") is tText
   TestAssert "its step", char 3 of st("row 2") is "5"
   TestAssert "its tempo", st("bpm") is 99
   TestAssert "its pan", st("pan 4") is -40
   TestAssert "its mute", st("mute 6") is true
end TestTheSongIsReadBackAsItWasSaved

----------------------------------------------------------------------
-- Pads and steps

on TestAPadTurnsOnAndOff
   TestAssert "row 2 step 5 is off", char 5 of st("row 2") is "0"
   clickPad 2, 5
   TestAssert "a click turns it on, at 7", char 5 of st("row 2") is "7"
   TestAssert "in its channel's colour", the backgroundColor of pad(2, 5) is "#FFB52E"
   TestAssert "the file has it", saved() contains "row" & tab & "0000700000000000" & zeros(16)
   clickPad 2, 5
   TestAssert "a second click turns it off", char 5 of st("row 2") is "0"
   TestAssert "a beat's first step is lighter", the backgroundColor of pad(2, 5) is "#2A2E5E"
   TestAssert "the others darker", the backgroundColor of pad(2, 6) is "#1F2249"
end TestAPadTurnsOnAndOff

on TestEveryPadIsWhereItsPointIs
   local tLoc, n, s, tWrong, tSteps
   repeat for each item tSteps in "16,32"
      studio "btSetSteps", tSteps
      repeat with n = 1 to 8
         repeat with s = 1 to tSteps
            put the loc of pad(n, s) into tLoc
            if says("btRowAt", item 2 of tLoc) is not n or says("btStepAt", item 1 of tLoc) is not s then
               put n & comma & s & " " after tWrong
            end if
         end repeat
      end repeat
   end repeat
   TestAssert "each pad's middle is its row and step" && tWrong, tWrong is empty
   TestAssert "the gap between rows is no pad", says("btRowAt", the bottom of pad(1, 1) + 2) is 0
   TestAssert "left of the grid is no step", says("btStepAt", the left of pad(1, 1) - 30) is 0
end TestEveryPadIsWhereItsPointIs

on TestVelocityGoesRound
   clickPad 1, 1, true
   TestAssert "a loud step goes soft", char 1 of st("row 1") is "4"
   TestAssert "a soft step is fainter", the blendLevel of pad(1, 1) is 40
   clickPad 1, 1, true
   TestAssert "soft goes normal", char 1 of st("row 1") is "7"
   clickPad 1, 1, true
   TestAssert "normal goes loud", char 1 of st("row 1") is "9"
   TestAssert "a loud step is solid", the blendLevel of pad(1, 1) is 0
   clickPad 1, 2, true
   TestAssert "a step that was off comes on loud", char 2 of st("row 1") is "9"
end TestVelocityGoesRound

on TestADragPaintsARow
   local tLoc
   put the loc of pad(6, 1) into tLoc
   get says("btPointerDown", "pad 6,1", item 1 of tLoc, item 2 of tLoc, false)
   put the loc of pad(6, 6) into tLoc
   -- the mouse drifts to the row below: the drag keeps to its own row
   studio "btPointerMove", item 1 of tLoc, item 2 of tLoc + 34
   studio "btEndDrag"
   TestAssert "the steps under the drag are on", char 1 to 6 of st("row 6") is "777777"
   TestAssert "the row below is as it was", char 1 to 6 of st("row 7") is "000000"
   -- a drag that begins on a step that is on takes steps off
   put the loc of pad(4, 1) into tLoc
   get says("btPointerDown", "pad 4,1", item 1 of tLoc, item 2 of tLoc, false)
   put the loc of pad(4, 8) into tLoc
   studio "btPointerMove", item 1 of tLoc, item 2 of tLoc
   studio "btEndDrag"
   TestAssert "the hats under it are off", char 1 to 8 of st("row 4") is "00000000"
   TestAssert "the rest are not", char 9 to 16 of st("row 4") is "50705070"
end TestADragPaintsARow

on TestThirtyTwoStepsKeepWhatSixteenHides
   studio "btSetSteps", 32
   TestAssert "thirty-two steps", st("steps") is 32
   TestAssert "pads to 32", the visible of pad(1, 32)
   clickPad 1, 20
   TestAssert "step 20 is on", char 20 of st("row 1") is "7"
   studio "btSetSteps", 16
   TestAssert "sixteen steps hide it", not the visible of pad(1, 20)
   TestAssert "the page is told 16 steps", st("json") contains quote & "9000900090009000" & quote
   studio "btSetSteps", 32
   TestAssert "but it is kept", char 20 of st("row 1") is "7"
   studio "btSetSteps", 24
   TestAssert "only 16 or 32", st("steps") is 32
   press "Steps 16"
   TestAssert "the button sets it", st("steps") is 16
end TestThirtyTwoStepsKeepWhatSixteenHides

----------------------------------------------------------------------
-- Tempo and swing

on TestTempoAndSwingKeepToTheirRanges
   studio "btSetTempo", 300
   TestAssert "at most 240", st("bpm") is 240
   studio "btSetTempo", 10
   TestAssert "at least 40", st("bpm") is 40
   studio "btSetTempo", "fast"
   TestAssert "not a number changes nothing", st("bpm") is 40
   studio "btSetTempo", 120.4
   TestAssert "whole beats", st("bpm") is 120
   press "Tempo Up"
   TestAssert "+ adds one", st("bpm") is 121
   press "Tempo Down"
   press "Tempo Down"
   TestAssert "- takes one", st("bpm") is 119
   TestAssert "shown", the text of ctl("field", "Tempo") is "119"
   studio "btSetSwing", -5
   TestAssert "swing 0 at least", st("swing") is 0
   studio "btSetSwing", 150
   TestAssert "swing 100 at most", st("swing") is 100
   TestAssert "swing shown", the text of ctl("field", "Swing Value") is "100%"
end TestTempoAndSwingKeepToTheirRanges

on TestTheSlidersFollowTheMouse
   local tTrack, tY
   put ctl("graphic", "Swing Track") into tTrack
   put item 2 of the loc of tTrack into tY
   get says("btPointerDown", "Swing Track", the left of tTrack, tY, false)
   TestAssert "the swing's left end is 0", st("swing") is 0
   studio "btPointerMove", the left of tTrack + the width of tTrack div 2, tY
   TestAssert "its middle is 50", st("swing") is 50
   studio "btPointerMove", the right of tTrack + 40, tY
   TestAssert "past its end is 100", st("swing") is 100
   studio "btEndDrag"
   TestAssert "the knob is at the end", item 1 of the loc of ctl("graphic", "Swing Knob") is the right of tTrack
   put ctl("graphic", "vol 3") into tTrack
   get says("btPointerDown", "vol 3", the left of tTrack + the width of tTrack div 4, item 2 of the loc of tTrack, false)
   studio "btEndDrag"
   TestAssert "a volume a quarter along is 25", st("vol 3") is 25
   TestAssert "its fill a quarter long", the width of ctl("graphic", "volfill 3") is round(the width of tTrack / 4)
   put ctl("graphic", "pan 3") into tTrack
   get says("btPointerDown", "pan 3", the left of tTrack, item 2 of the loc of tTrack, false)
   TestAssert "the pan's left end is -100", st("pan 3") is -100
   studio "btPointerMove", item 1 of the loc of tTrack + 1, item 2 of the loc of tTrack
   studio "btEndDrag"
   TestAssert "near the middle snaps to it", st("pan 3") is 0
   get says("btPointerDown", "Tempo", 400, 30, false)
   studio "btPointerMove", 400, 0
   studio "btEndDrag"
   TestAssert "the tempo dragged up 30 points is 10 faster", st("bpm") is 132
end TestTheSlidersFollowTheMouse

----------------------------------------------------------------------
-- The mixer: volume, pan, mute and solo

on TestMuteAndSolo
   TestAssert "every channel is heard", st("audible 1") and st("audible 2")
   press "solo 2"
   TestAssert "a solo silences the rest", not st("audible 1") and st("audible 2")
   TestAssert "solo is lit", the backgroundColor of ctl("button", "solo 2") is "#FFB52E"
   TestAssert "a channel not heard is grey", the backgroundColor of pad(1, 1) is "#4A4870"
   press "solo 3"
   TestAssert "two solos are both heard", st("audible 2") and st("audible 3") and not st("audible 1")
   press "mute 2"
   TestAssert "mute wins over solo", not st("audible 2")
   TestAssert "the page is told", st("json") contains "[2,78,0,1,1]"
   press "solo 2"
   press "solo 3"
   press "mute 2"
   TestAssert "all heard again", st("audible 1") and st("audible 2") and st("audible 3")
   TestAssert "and coloured again", the backgroundColor of pad(1, 1) is "#FF7A3D"
end TestMuteAndSolo

on TestVolumeAndPanKeepToTheirRanges
   studio "btSetVolume", 1, 150
   TestAssert "volume 100 at most", st("vol 1") is 100
   studio "btSetVolume", 1, -3
   TestAssert "volume 0 at least", st("vol 1") is 0
   studio "btSetPan", 1, -150
   TestAssert "pan -100 at most left", st("pan 1") is -100
   studio "btSetPan", 1, 101
   TestAssert "pan 100 at most right", st("pan 1") is 100
   TestAssert "the page is told", st("json") contains "[0,0,100,0,0]"
end TestVolumeAndPanKeepToTheirRanges

----------------------------------------------------------------------
-- Channels and the sound picker

on TestChannelsComeAndGo
   local tRow3
   put st("row 3") into tRow3
   press "Add Channel"
   TestAssert "a ninth channel", st("chans") is 9
   TestAssert "it is shown", the visible of ctl("button", "chan 9") and the visible of pad(9, 1)
   TestAssert "empty in this pattern", st("row 9") is zeros(32)
   studio "btSelectPattern", 2
   TestAssert "and in every other", st("row 9") is zeros(32)
   studio "btSelectPattern", 1
   studio "btRemoveChannel", 2
   TestAssert "eight again", st("chans") is 8
   TestAssert "the clap moved up", st("sound 2") is 5 and st("row 2") is tRow3
   TestAssert "its name too", the label of ctl("button", "chan 2") is "Clap"
   TestAssert "the last row hidden", not the visible of ctl("button", "chan 9")
   repeat 10 times
      studio "btAddChannel"
   end repeat
   TestAssert "twelve at most", st("chans") is 12
   TestAssert "then no Add Channel", not the visible of ctl("button", "Add Channel")
   repeat 20 times
      studio "btRemoveChannel", 1
   end repeat
   TestAssert "one at least", st("chans") is 1
end TestChannelsComeAndGo

on TestThePickerChoosesASound
   press "chan 3"
   TestAssert "the picker opens for channel 3", st("picker") is 3 and the visible of ctl("group", "Picker")
   TestAssert "it says which", the text of ctl("field", "Picker Title") contains "Channel 3"
   press "pick 16"
   TestAssert "channel 3 plays the bass", st("sound 3") is 16
   TestAssert "and says so", the label of ctl("button", "chan 3") is "Bass"
   TestAssert "the picker closes", st("picker") is empty and not the visible of ctl("group", "Picker")
   TestAssert "the page is told", st("json") contains "[2,78,0,0,0],[15,78,0,0,0],[5,70,-18,0,0]"
   press "chan 8"
   TestAssert "the picker for the last row stays on the card", the bottom of ctl("group", "Picker") <= 560
   press "Pick Remove"
   TestAssert "Remove takes the channel away", st("chans") is 7
   studio "btSetSound", 1, 17
   TestAssert "no seventeenth sound", st("sound 1") is 1
end TestThePickerChoosesASound

----------------------------------------------------------------------
-- Patterns

on TestPatternsAreMadeCopiedClearedAndDeleted
   press "Pattern New"
   TestAssert "a fourth pattern, shown", st("pats") is 4 and st("cur") is 4
   TestAssert "named", st("name 4") is "Pattern 1"
   TestAssert "empty", st("row 1") is zeros(32)
   TestAssert "in the list, chosen", the hilitedLine of ctl("field", "Patterns") is 4
   studio "btSelectPattern", 2
   press "Pattern Clone"
   TestAssert "a copy", st("pats") is 5 and st("cur") is 5 and st("name 5") is "Pattern 2"
   TestAssert "of its steps", st("row 5") is ("0090009000900090" & zeros(16))
   press "Pattern Clear"
   TestAssert "cleared", st("row 1") is zeros(32) and st("row 5") is zeros(32)
   studio "btSelectPattern", 2
   TestAssert "the original is not", st("row 5") is ("0090009000900090" & zeros(16))
   press "Pattern Delete"
   TestAssert "deleted", st("pats") is 4 and st("name 2") is "Fill"
   TestAssert "the next one is shown", st("cur") is 2
   repeat 20 times
      studio "btNewPattern"
   end repeat
   TestAssert "sixteen at most", st("pats") is 16
   repeat 20 times
      press "Pattern Delete"
   end repeat
   TestAssert "one is always left", st("pats") is 1
   studio "btSelectPattern", 7
   TestAssert "no pattern past the last", st("cur") is 1
end TestPatternsAreMadeCopiedClearedAndDeleted

----------------------------------------------------------------------
-- New and Demo

on TestNewAsksFirst
   local tText
   put st("text") into tText
   press "New"
   TestAssert "the first press asks", the label of ctl("button", "New") is "Sure?"
   TestAssert "and changes nothing", st("text") is tText
   press "Tempo Up"
   TestAssert "another button takes the question back", the label of ctl("button", "New") is "New"
   press "New"
   press "New"
   TestAssert "two presses: an empty song", st("pats") is 1 and st("chans") is 8 and st("row 1") is zeros(32)
   TestAssert "at 120", st("bpm") is 120 and st("swing") is 0
   press "Demo"
   TestAssert "Demo brings the demo back", st("pats") is 3 and st("name 2") is "Groove B"
end TestNewAsksFirst

----------------------------------------------------------------------
-- What the page is told, and what a file may hold

on TestThePageIsToldThePatternShown
   press "New"
   press "New"
   studio "btSetStep", 1, 1, 9
   studio "btSetStep", 8, 16, 3
   studio "btSetPan", 2, -25
   studio "btToggleSolo", 3
   TestAssert "the song as JSON", st("json") is \
         "{" & quote & "bpm" & quote & ":120," & quote & "swing" & quote & ":0," & quote & "steps" & quote & ":16," & \
         quote & "ch" & quote & ":[[0,78,0,0,0],[2,78,-25,0,0],[4,78,0,0,1],[5,78,0,0,0],[6,78,0,0,0],[9,78,0,0,0],[11,78,0,0,0],[15,78,0,0,0]]," & \
         quote & "rows" & quote & ":[" & quote & "9" & zeros(15) & quote & "," & quote & zeros(16) & quote & "," & \
         quote & zeros(16) & quote & "," & quote & zeros(16) & quote & "," & quote & zeros(16) & quote & "," & \
         quote & zeros(16) & quote & "," & quote & zeros(16) & quote & "," & quote & zeros(15) & "3" & quote & "]}"
end TestThePageIsToldThePatternShown

on TestAFileThatIsNotASongIsRefused
   local tText, tSong
   put st("text") into tText
   TestAssert "nonsense", not says("btTestRead", "hello")
   TestAssert "Beat Box's file", not says("btTestRead", "120" & return & "1000100010001000,false")
   TestAssert "no channels", not says("btTestRead", "beyond-beats 1" & return & "bpm" & tab & "100")
   TestAssert "a row before any pattern", not says("btTestRead", "beyond-beats 1" & return & "ch" & tab & "1" & return & "row" & tab & "9")
   TestAssert "the song is as it was", st("text") is tText
   put "beyond-beats 1" & return & "bpm" & tab & "999" & return & "swing" & tab & "-4" & return & "cur" & tab & "9" & return into tSong
   put "ch" & tab & "40" & tab & "500" & tab & "0" & tab & "true" & tab & "false" & return after tSong
   put "ch" & tab & "2" & tab & "50" & tab & "-20" & tab & "false" & tab & "true" & return after tSong
   put "pat" & tab & "Odd" & tab & "7" & return after tSong
   put "row" & tab & "9x7" & return after tSong
   TestAssert "a song made safe is read", says("btTestRead", tSong)
   TestAssert "its tempo in range", st("bpm") is 240 and st("swing") is 0
   TestAssert "its pattern in range", st("cur") is 1 and st("steps") is 16
   TestAssert "a sound in range", st("sound 1") is 16 and st("vol 1") is 100 and st("mute 1") is true
   TestAssert "the second channel", st("sound 2") is 2 and st("pan 2") is -20 and st("solo 2") is true
   TestAssert "what is not a digit is off, and short rows filled", st("row 1") is "907" & zeros(29)
   TestAssert "a missing row is empty", st("row 2") is zeros(32)
end TestAFileThatIsNotASongIsRefused

----------------------------------------------------------------------
-- Playing, without a browser

-- On a desktop the playhead runs on the engine's clock; in the web engine
-- (tools/ci/web_tests.py) the page's audio core plays, and its clock runs
-- only once the page has had a click, which a test does not give it, so
-- there the test asks the core instead.
on TestPlayRunsThePlayheadWithoutSound
   local tCore
   press "Play"
   TestAssert "it plays", st("playing") is true
   TestAssert "Play says Stop", the label of ctl("button", "Play") is "Stop"
   if the platform is "HTML5" then
      do "window.beyondBeats ? String(beyondBeats.playing) + ',' + beyondBeats.song.bpm : 'none'" as "JavaScript"
      put the result into tCore
      TestAssert "the page's core plays at the stack's tempo", tCore is "true,122"
   else
      TestAssert "and why there is no sound", the text of ctl("field", "Status") contains "browser"
      wait 300 milliseconds with messages
      TestAssert "the playhead moves", the visible of ctl("graphic", "Head")
      TestAssert "over the pads", the left of ctl("graphic", "Head") >= the left of pad(1, 1) - 2
   end if
   press "Play"
   TestAssert "it stops", st("playing") is false and the label of ctl("button", "Play") is "Play"
   TestAssert "the playhead goes", not the visible of ctl("graphic", "Head")
   if the platform is "HTML5" then
      do "window.beyondBeats ? String(beyondBeats.playing) : 'none'" as "JavaScript"
      TestAssert "and the page's core stops", the result is "false"
   end if
end TestPlayRunsThePlayheadWithoutSound
