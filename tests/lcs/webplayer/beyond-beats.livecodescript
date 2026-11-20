script "TestBeyondBeats"
-- OXT-Beyond: the Beyond Beats beat studio (the committed
-- tools/web-player/stacks/Beyond Beats.oxtstack, built by
-- tools/web-player/beyond-beats.livecodescript from
-- tools/web-player/beyond-beats-stack.livecodescript), on a desktop engine.
--
-- A desktop engine has no Web Audio, so these tests drive what the stack
-- owns: the song, the screen and the files. btTestBegin opens the stack
-- as it opens in a browser, but with its song kept in a file of the
-- test's own and saved at once after every change; btState says how
-- things are. The mouse is given as points of the card (btPointerDown,
-- btPointerMove, btEndDrag), which is what the stack's mouseDown and
-- mouseMove pass on, and buttons are pressed through btPress, as their
-- mouseUp does; a few tests send the mouse's messages themselves, to the
-- controls, as the engine does. What the page is told (btState "json") is
-- checked here; what the page does with it, in a browser, is
-- tools/ci/beyond_beats_check.py's.

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
   local tFolder, tFile
   if there is a stack kStack then
      studio "btTestEnd"
      delete stack kStack
   end if
   if sSave is not empty and there is a file sSave then
      delete file sSave
   end if
   put sSave & "-samples" into tFolder
   if sSave is not empty and there is a folder tFolder then
      repeat for each line tFile in files(tFolder)
         delete file (tFolder & "/" & tFile)
      end repeat
      delete folder tFolder
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

-- a press somewhere, and let go
private command clickAt pName, pX, pY, pAlt
   get says("btPointerDown", pName, pX, pY, pAlt is true)
   studio "btEndDrag"
end clickAt

-- the middle of a bar (from 1, as the playlist shows it) of a track
private function cellLoc pTrack, pColumn
   return the loc of ctl("graphic", "cell" && pTrack & comma & pColumn)
end cellLoc

private command clickCell pTrack, pColumn, pAlt
   local tLoc
   put cellLoc(pTrack, pColumn) into tLoc
   clickAt "cell" && pTrack & comma & pColumn, item 1 of tLoc, item 2 of tLoc, pAlt
end clickCell

-- a point of the piano roll: inside a step, on a pitch's lane
private function pianoX pStep
   return says("btPianoX", pStep) + 4
end pianoX

private function pianoY pPitch
   return says("btPitchY", pPitch) + 8
end pianoY

private command clickNote pStep, pPitch, pAlt
   clickAt "lane", pianoX(pStep), pianoY(pPitch), pAlt
end clickNote

-- the song's JSON for a channel, as the page is told it
private function chJson pSound, pVol, pPan, pMute, pSolo, pCut, pReverb, pDelay, pTune
   return "[" & pSound & "," & pVol & "," & pPan & "," & pMute & "," & pSolo & "," & pCut & "," & pReverb & "," & \
         pDelay & "," & pTune & "]"
end chJson

-- a WAV file of a short click: 16-bit mono at 8000 a second
private function wavFile
   local tData, i
   repeat with i = 1 to 400
      if i <= 20 then
         put binaryEncode("s", 12000) after tData
      else
         put binaryEncode("s", 0) after tData
      end if
   end repeat
   return binaryEncode("a4Ia4a4ISSIISSa4I", "RIFF", 36 + length(tData), "WAVE", "fmt ", 16, 1, 1, 8000, 16000, 2, 16, \
         "data", length(tData)) & tData
end wavFile

----------------------------------------------------------------------
-- Opening

on TestItOpensOnTheDemoSong
   TestAssert "four patterns", st("pats") is 4
   TestAssert "ten channels", st("chans") is 10
   TestAssert "its tempo and swing", st("bpm") is 122 and st("swing") is 18
   TestAssert "the first pattern is shown", st("cur") is 1 and st("name 1") is "Groove"
   TestAssert "four on the floor", st("row 1") is "9000900090009000" & zeros(16)
   TestAssert "the kick's name", the label of ctl("button", "chan 1") is "Kick"
   TestAssert "the bass's name", the label of ctl("button", "chan 8") is "Bass"
   TestAssert "a synth's name", the label of ctl("button", "chan 10") is "Keys"
   TestAssert "a channel's pads to the pattern's end", the visible of pad(1, 16)
   TestAssert "no pads past it", not the visible of pad(1, 17)
   TestAssert "no eleventh channel", not the visible of ctl("button", "chan 11")
   TestAssert "the pattern list", the text of ctl("field", "Patterns") is "Groove" & return & "Groove B" & return & \
         "Fill" & return & "Chords"
   TestAssert "a colour for each pattern", the visible of ctl("graphic", "pswatch 4") and \
         not the visible of ctl("graphic", "pswatch 5")
   TestAssert "the tempo shown", the text of ctl("field", "Tempo") is "122"
   TestAssert "the swing shown", the text of ctl("field", "Swing Value") is "18%"
   TestAssert "the picker hidden", not the visible of ctl("group", "Picker")
   TestAssert "the menu hidden", not the visible of ctl("group", "Files")
   TestAssert "the rack shown", st("view") is "rack" and the visible of ctl("group", "View Rack") and \
         not the visible of ctl("group", "View Mixer")
   TestAssert "Pattern mode", st("mode") is "pattern" and the backgroundColor of ctl("button", "Mode Pattern") is "#FFB52E"
   TestAssert "a playlist of eight bars", st("track 1") is "1:1,2:1,3:2,4:2,5:1,6:1,7:2,8:3" and \
         st("track 2") is "1:4,3:4,5:4,7:4" and st("songsteps") is 128
   TestAssert "the chords' notes", the number of lines of says("btState", "notes 10") is 0
   studio "btSelectPattern", 4
   TestAssert "are in their pattern", the number of lines of st("notes 10") is 9 and line 1 of st("notes 10") is "1,14,57,6"
end TestItOpensOnTheDemoSong

on TestTheSongIsReadBackAsItWasSaved
   local tText
   studio "btSetStep", 2, 3, 5
   studio "btSetTempo", 99
   studio "btSetPan", 4, -40
   studio "btToggleMute", 6
   studio "btSetChannel", 9, "rev", 44
   studio "btSetChannel", 9, "tune", -5
   studio "btSetMaster", "size", 1
   studio "btSetMode", "song"
   studio "btSetFrom", 3
   get says("btPlaceBlock", 5, 20, 3)
   put st("text") into tText
   TestAssert "every change is saved at once", saved() is tText
   -- the stack opened again, from the same file
   studio "btTestBegin", sSave
   TestAssert "the song is the one saved", st("text") is tText
   TestAssert "its step", char 3 of st("row 2") is "5"
   TestAssert "its tempo", st("bpm") is 99
   TestAssert "its pan", st("pan 4") is -40
   TestAssert "its mute", st("mute 6") is true
   TestAssert "its sends and tuning", st("rev 9") is 44 and st("tune 9") is -5
   TestAssert "its reverb", st("master size") is 1
   TestAssert "its mode and start", st("mode") is "song" and st("from") is 3
   TestAssert "its playlist", st("block 5 20") is 3
   studio "btSelectPattern", 4
   TestAssert "its notes", line 2 of st("notes 9") is "4,1,45,6"
end TestTheSongIsReadBackAsItWasSaved

on TestOldSongsStillOpen
   local tSong
   -- a song as the first version saved it: no mixer, notes or playlist
   put "beyond-beats 1" & return & "bpm" & tab & "100" & return & "swing" & tab & "10" & return & "cur" & tab & "1" & return into tSong
   put "ch" & tab & "6" & tab & "60" & tab & "-10" & tab & "false" & tab & "false" & return after tSong
   put "pat" & tab & "Old" & tab & "16" & return & "row" & tab & "9090" & return after tSong
   TestAssert "it is read", says("btTestRead", tSong)
   TestAssert "as it was", st("bpm") is 100 and st("sound 1") is 6 and st("vol 1") is 60 and st("name 1") is "Old"
   TestAssert "the mixer's settings as a new channel has them", st("cut 1") is 100 and st("rev 1") is 0 and \
         st("dly 1") is 0 and st("tune 1") is 0
   TestAssert "the master's", st("master vol") is 80 and st("master dly") is 3 and st("master fb") is 35
   TestAssert "in Pattern mode, with an empty playlist", st("mode") is "pattern" and st("track 1") is empty
   TestAssert "saved in the new form", line 1 of st("text") is "beyond-beats 2"
end TestOldSongsStillOpen

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
      repeat with n = 1 to 10
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
   get says("btPointerDown", "Tempo", 495, 30, false)
   studio "btPointerMove", 495, 0
   studio "btEndDrag"
   TestAssert "the tempo dragged up 30 points is 10 faster", st("bpm") is 132
end TestTheSlidersFollowTheMouse

----------------------------------------------------------------------
-- Volume, pan, mute and solo

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
   TestAssert "the page is told", st("json") contains chJson(2, 78, 0, 1, 1, 100, 0, 0, 0)
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
   TestAssert "the page is told", st("json") contains chJson(0, 0, 100, 0, 0, 100, 0, 0, 0)
   studio "btSetVolume", 40, 50
   TestAssert "no fortieth channel", st("chans") is 10 and st("vol 40") is empty
end TestVolumeAndPanKeepToTheirRanges

----------------------------------------------------------------------
-- Channels and the sound picker

on TestChannelsComeAndGo
   local tRow3
   put st("row 3") into tRow3
   press "Add Channel"
   TestAssert "an eleventh channel", st("chans") is 11
   TestAssert "it is shown", the visible of ctl("button", "chan 11") and the visible of pad(11, 1)
   TestAssert "empty in this pattern", st("row 11") is zeros(32) and st("notes 11") is empty
   studio "btSelectPattern", 2
   TestAssert "and in every other", st("row 11") is zeros(32)
   studio "btSelectPattern", 1
   studio "btRemoveChannel", 2
   TestAssert "ten again", st("chans") is 10
   TestAssert "the clap moved up", st("sound 2") is 5 and st("row 2") is tRow3 and st("rev 2") is 25
   TestAssert "its name too", the label of ctl("button", "chan 2") is "Clap"
   TestAssert "the last row hidden", not the visible of ctl("button", "chan 11")
   studio "btSelectPattern", 4
   TestAssert "the synths' notes moved up with them", line 1 of st("notes 9") is "1,14,57,6" and \
         line 1 of st("notes 8") is "1,2,45,8"
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
   TestAssert "the sound it plays is lit", the backgroundColor of ctl("button", "pick 5") is "#FFB52E"
   TestAssert "the kit, the synths and the samples", the label of ctl("button", "pick 16") is "Bass" and \
         the label of ctl("button", "pick 17") is "Saw lead" and the label of ctl("button", "pick 21") is "Keys" and \
         the label of ctl("button", "pick 22") is "+ load"
   press "pick 16"
   TestAssert "channel 3 plays the bass", st("sound 3") is 16
   TestAssert "and says so", the label of ctl("button", "chan 3") is "Bass"
   TestAssert "the picker closes", st("picker") is empty and not the visible of ctl("group", "Picker")
   TestAssert "the page is told", st("json") contains chJson(2, 78, 0, 0, 0, 100, 0, 0, 0) & "," & \
         chJson(15, 78, 0, 0, 0, 100, 25, 0, 0) & "," & chJson(5, 70, -18, 0, 0, 100, 0, 0, 0)
   press "chan 3"
   press "pick 19"
   TestAssert "a synth", st("sound 3") is 19 and the label of ctl("button", "chan 3") is "Soft pad"
   press "chan 8"
   TestAssert "the picker for the last row stays on the card", the bottom of ctl("group", "Picker") <= 560
   press "Pick Remove"
   TestAssert "Remove takes the channel away", st("chans") is 9
   studio "btSetSound", 1, 30
   TestAssert "no thirtieth sound", st("sound 1") is 1
end TestThePickerChoosesASound

-- The mouse's own messages, sent to the controls as the engine sends
-- them: the picker takes a click on itself, and a click away closes it.
on TestThePickerAnswersTheMouse
   local tPick, tRows
   put st("row 1") & st("row 2") into tRows
   send "mouseDown 1" to ctl("button", "chan 3")
   send "mouseUp 1" to ctl("button", "chan 3")
   TestAssert "a click on a channel's name opens the picker", st("picker") is 3
   put ctl("button", "pick 7") into tPick
   send "mouseDown 1" to tPick
   send "mouseUp 1" to tPick
   TestAssert "a click on a sound in it chooses it", st("sound 3") is 7 and st("picker") is empty
   send "mouseDown 1" to ctl("button", "chan 2")
   send "mouseUp 1" to ctl("button", "chan 2")
   send "mouseDown 1" to ctl("graphic", "Rack")
   send "mouseUp 1" to ctl("graphic", "Rack")
   TestAssert "a click away only closes it", st("picker") is empty and st("sound 2") is 3
   send "mouseDown 1" to ctl("button", "File")
   send "mouseUp 1" to ctl("button", "File")
   TestAssert "File opens its menu", st("menu") is "file" and the visible of ctl("group", "Files")
   send "mouseDown 1" to ctl("button", "Demo")
   send "mouseUp 1" to ctl("button", "Demo")
   TestAssert "a click on it chooses an item", st("menu") is empty and not the visible of ctl("group", "Files")
   send "mouseDown 1" to ctl("button", "File")
   send "mouseUp 1" to ctl("button", "File")
   send "mouseDown 1" to ctl("button", "Tab Mixer")
   send "mouseUp 1" to ctl("button", "Tab Mixer")
   TestAssert "a click away closes it and does nothing else", st("menu") is empty and st("view") is "rack"
   TestAssert "no pad was clicked on the way", st("row 1") & st("row 2") is tRows
end TestThePickerAnswersTheMouse

----------------------------------------------------------------------
-- Patterns

on TestPatternsAreMadeCopiedClearedAndDeleted
   press "Pattern New"
   TestAssert "a fifth pattern, shown", st("pats") is 5 and st("cur") is 5
   TestAssert "named", st("name 5") is "Pattern 1"
   TestAssert "empty", st("row 1") is zeros(32)
   TestAssert "in the list, chosen", the hilitedLine of ctl("field", "Patterns") is 5
   studio "btSelectPattern", 4
   press "Pattern Clone"
   TestAssert "a copy", st("pats") is 6 and st("cur") is 6 and st("name 6") is "Pattern 2"
   TestAssert "of its steps and notes", st("steps") is 32 and the number of lines of st("notes 10") is 9
   studio "btSelectPattern", 2
   press "Pattern Clone"
   TestAssert "of its rows", st("row 5") is ("0090009000900090" & zeros(16))
   press "Pattern Clear"
   TestAssert "cleared", st("row 1") is zeros(32) and st("row 5") is zeros(32)
   studio "btSelectPattern", 2
   TestAssert "the original is not", st("row 5") is ("0090009000900090" & zeros(16))
   press "Pattern Delete"
   TestAssert "deleted", st("pats") is 6 and st("name 2") is "Fill"
   TestAssert "the next one is shown", st("cur") is 2
   TestAssert "out of the playlist, the later ones a number less", st("track 1") is "1:1,2:1,5:1,6:1,8:2" and \
         st("track 2") is "1:3,3:3,5:3,7:3"
   studio "btRenamePattern", 2, "Break" & tab & "down"
   TestAssert "renamed, without a tab", st("name 2") is "Break down" and line 2 of the text of ctl("field", "Patterns") is "Break down"
   repeat 20 times
      studio "btNewPattern"
   end repeat
   TestAssert "sixteen at most", st("pats") is 16
   repeat 20 times
      press "Pattern Delete"
   end repeat
   TestAssert "one is always left, cleared", st("pats") is 1 and st("row 1") is zeros(16) and st("notes 10") is empty
   TestAssert "its blocks stay where they were", st("track 1") is "1:1,2:1,5:1,6:1" and st("track 2") is empty
   studio "btSelectPattern", 7
   TestAssert "no pattern past the last", st("cur") is 1
end TestPatternsAreMadeCopiedClearedAndDeleted

----------------------------------------------------------------------
-- The views

-- Every control where the layout puts it: laid out again, nothing moves.
-- (A view's group moved after its controls were placed once carried
-- every one of them 12 points left and 6 up.)
on TestLaidOutAgainNothingMoves
   local tBefore, tAfter
   put rects() into tBefore
   studio "btLayout"
   studio "btDrawAll"
   put rects() into tAfter
   TestAssert "every control as it was built", tBefore is tAfter
   TestAssert "the playlist's first bar under the ruler's start", \
         the left of ctl("graphic", "cell 1,1") is the left of ctl("graphic", "Ruler")
   TestAssert "a view fills the rack", the rect of ctl("group", "View Song") is "192,68,952,560"
end TestLaidOutAgainNothingMoves

private function rects
   local i, tText
   repeat with i = 1 to the number of controls of card kCard of stack kStack
      put the long name of control i of card kCard of stack kStack && the rect of control i of card kCard of stack kStack & \
            return after tText
   end repeat
   return tText
end rects

on TestTabsShowOneViewAtATime
   local tView
   repeat for each item tView in "Song,Piano,Mixer,Rack"
      press "Tab" && tView
      TestAssert tView && "is shown", the visible of ctl("group", "View" && tView)
      TestAssert tView && "is the view", st("view") is tolower(tView)
      TestAssert tView && "tab is lit", the backgroundColor of ctl("button", "Tab" && tView) is "#FFB52E"
   end repeat
   TestAssert "one at a time", not the visible of ctl("group", "View Song") and \
         not the visible of ctl("group", "View Piano") and not the visible of ctl("group", "View Mixer")
   press "Tab Song"
   TestAssert "the steps are the pattern editors'", not the visible of ctl("button", "Steps 16")
   press "Tab Piano"
   TestAssert "the piano roll edits steps too", the visible of ctl("button", "Steps 16")
end TestTabsShowOneViewAtATime

----------------------------------------------------------------------
-- The playlist

on TestThePlaylistShowsTheSong
   press "Tab Song"
   TestAssert "the bars shown", the text of ctl("field", "Bars Label") is "Bars 1 to 32"
   TestAssert "a block's first bar in its pattern's colour, with its number", \
         the backgroundColor of ctl("graphic", "cell 1,3") is "#FFB52E" and the label of ctl("graphic", "cell 1,3") is "2" and \
         the blendLevel of ctl("graphic", "cell 1,3") is 0
   TestAssert "a two-bar pattern goes on over the next", the backgroundColor of ctl("graphic", "cell 2,2") is "#5CD6FF" and \
         the label of ctl("graphic", "cell 2,2") is empty and the blendLevel of ctl("graphic", "cell 2,2") is 40
   TestAssert "an empty bar", the backgroundColor of ctl("graphic", "cell 3,2") is "#1F2249" and \
         the label of ctl("graphic", "cell 3,2") is empty
   TestAssert "only a block's first bar shows a name, not the graphic's own", \
         the showName of ctl("graphic", "cell 1,3") and not the showName of ctl("graphic", "cell 2,2") and \
         not the showName of ctl("graphic", "cell 3,2")
   TestAssert "the ruler numbers every fourth bar", the text of ctl("field", "barno 1") is "1" and \
         the text of ctl("field", "barno 5") is "5" and the text of ctl("field", "barno 2") is empty
   TestAssert "its length", the text of ctl("field", "Song Length") is "Song: 8 bars, 0:16"
   TestAssert "where it starts", the left of ctl("graphic", "StartMark") is the left of ctl("graphic", "cell 1,1")
end TestThePlaylistShowsTheSong

on TestPatternsGoIntoThePlaylist
   local tLoc, tJson
   press "Tab Song"
   studio "btSelectPattern", 3
   clickCell 3, 10
   TestAssert "a click puts the chosen pattern in", st("block 3 10") is 3
   TestAssert "drawn", the label of ctl("graphic", "cell 3,10") is "3"
   clickCell 3, 10
   TestAssert "a second takes it out", st("block 3 10") is empty and st("track 3") is empty
   studio "btSelectPattern", 4
   clickCell 3, 10
   TestAssert "two bars for 32 steps", st("block 3 10") is 4 and st("block 3 11") is 4 and st("block 3 12") is empty
   clickCell 3, 11
   TestAssert "a click on its second bar takes it out", st("track 3") is empty
   studio "btSelectPattern", 1
   clickCell 3, 10
   studio "btSelectPattern", 4
   clickCell 3, 9
   TestAssert "a block put over another takes its place", st("track 3") is "9:4"
   clickCell 3, 1, true
   TestAssert "shift-click on nothing does nothing", st("cur") is 4 and st("track 3") is "9:4"
   clickCell 1, 8, true
   TestAssert "shift-click on a block chooses its pattern", st("cur") is 3 and st("track 1") contains "8:3"
   TestAssert "the song grows", st("songsteps") is 160
   studio "btSelectPattern", 1
   clickCell 4, 32
   TestAssert "to its last block", st("songsteps") is 512
   put st("json") into tJson
   TestAssert "the page is told the playlist", tJson contains quote & "song" & quote & ":[[0,0],[1,0],[2,1]," and \
         tJson contains "[8,3]," and tJson contains "[31,0]]"
   TestAssert "beside the bars of its patterns", the number of lines of saved() > 0 and saved() contains "track" & tab & "4" & tab & "32:1"
   get says("btPlaceBlock", 1, 128, 4)
   TestAssert "no block past the song's end", it is false and st("block 1 128") is empty
   get says("btPlaceBlock", 9, 1, 1)
   TestAssert "no ninth track", it is false
   get says("btPlaceBlock", 1, 1, 9)
   TestAssert "no pattern the song lacks", it is false
end TestPatternsGoIntoThePlaylist

on TestADragAlongATrackPaintsIt
   local tLoc
   press "Tab Song"
   studio "btSelectPattern", 1
   put cellLoc(5, 1) into tLoc
   get says("btPointerDown", "cell 5,1", item 1 of tLoc, item 2 of tLoc, false)
   put cellLoc(5, 6) into tLoc
   studio "btPointerMove", item 1 of tLoc, item 2 of tLoc + 50
   studio "btEndDrag"
   TestAssert "a block a bar along the drag, on its own track", st("track 5") is "1:1,2:1,3:1,4:1,5:1,6:1" and \
         st("track 6") is empty
   studio "btSelectPattern", 4
   put cellLoc(6, 1) into tLoc
   get says("btPointerDown", "cell 6,1", item 1 of tLoc, item 2 of tLoc, false)
   put cellLoc(6, 6) into tLoc
   studio "btPointerMove", item 1 of tLoc, item 2 of tLoc
   studio "btEndDrag"
   TestAssert "two bars apart for a two-bar pattern", st("track 6") is "1:4,3:4,5:4"
   put cellLoc(5, 2) into tLoc
   get says("btPointerDown", "cell 5,2", item 1 of tLoc, item 2 of tLoc, false)
   put cellLoc(5, 4) into tLoc
   studio "btPointerMove", item 1 of tLoc, item 2 of tLoc
   studio "btEndDrag"
   TestAssert "a drag from a block takes blocks out", st("track 5") is "1:1,5:1,6:1"
end TestADragAlongATrackPaintsIt

on TestThePlaylistScrollsToBar128
   press "Tab Song"
   press "Bars On"
   TestAssert "on 16 bars", st("songview") is 17 and the text of ctl("field", "Bars Label") is "Bars 17 to 48"
   TestAssert "the ruler follows", the text of ctl("field", "barno 1") is "17"
   studio "btSelectPattern", 1
   clickCell 7, 1
   TestAssert "a click is at the bar shown", st("block 7 17") is 1
   repeat 10 times
      press "Bars On"
   end repeat
   TestAssert "to the last 32", st("songview") is 97
   press "Bars Back"
   TestAssert "and back", st("songview") is 81
   TestAssert "the start mark hidden off its bars", not the visible of ctl("graphic", "StartMark")
end TestThePlaylistScrollsToBar128

on TestSongModeAndWhereItStarts
   local tLoc
   press "Mode Song"
   TestAssert "Song mode", st("mode") is "song" and the backgroundColor of ctl("button", "Mode Song") is "#FFB52E"
   TestAssert "the page is told", st("json") contains quote & "mode" & quote & ":" & quote & "song" & quote
   press "Tab Song"
   put cellLoc(1, 5) into tLoc
   clickAt "Ruler", item 1 of tLoc, the top of ctl("graphic", "Ruler") + 5
   TestAssert "a click on the ruler: where it starts", st("from") is 5
   TestAssert "the page is told its step", st("json") contains quote & "from" & quote & ":64,"
   TestAssert "the mark moves", the left of ctl("graphic", "StartMark") is the left of ctl("graphic", "cell 1,5")
   TestAssert "the playlist is as it was", st("track 1") is "1:1,2:1,3:2,4:2,5:1,6:1,7:2,8:3"
   studio "btSetFrom", 500
   TestAssert "not past the song's end", st("from") is 128
   press "Mode Pattern"
   TestAssert "Pattern mode", st("mode") is "pattern" and st("json") contains quote & "mode" & quote & ":" & quote & "pattern" & quote
end TestSongModeAndWhereItStarts

----------------------------------------------------------------------
-- The piano roll

on TestThePianoRollAddsAndStretchesNotes
   local tY
   studio "btChooseChannel", 9
   TestAssert "a channel's colour chooses it for the piano roll", st("pianoch") is 9
   TestAssert "and marks it", the top of ctl("graphic", "Chosen") > the top of pad(9, 1)
   press "Tab Piano"
   TestAssert "its name", the text of ctl("field", "Piano Chan") is "9. Square bass"
   TestAssert "two octaves", the text of ctl("field", "Oct Label") is "C3 to B4" and st("pianolow") is 48
   TestAssert "the Cs named", the label of ctl("graphic", "key 1") is "C3" and the label of ctl("graphic", "key 13") is "C4"
   TestAssert "a black key", the backgroundColor of ctl("graphic", "key 2") is "#0B0D1F"
   TestAssert "a key that is not a C shows no name, not even its own", not the showName of ctl("graphic", "key 2") and \
         not the showName of ctl("graphic", "key 3") and the showName of ctl("graphic", "key 13")
   clickNote 3, 50
   TestAssert "a click adds a note, two steps long", st("notes 9") is "3,2,50,7"
   TestAssert "it is drawn", the visible of ctl("graphic", "note 1") and \
         the left of ctl("graphic", "note 1") is says("btPianoX", 3) + 1 and \
         the top of ctl("graphic", "note 1") is says("btPitchY", 50) + 1
   -- a drag to the right makes the next one longer
   get says("btPointerDown", "lane", pianoX(5), pianoY(52), false)
   studio "btPointerMove", pianoX(10), pianoY(52) + 40
   studio "btEndDrag"
   TestAssert "a drag makes it longer, at its pitch", line 2 of st("notes 9") is "5,6,52,7"
   TestAssert "and the next one as long", st("notelen") is 6
   clickNote 15, 48
   TestAssert "kept in the pattern", line 3 of st("notes 9") is "15,2,48,7"
   clickNote 16, 60
   TestAssert "the last step: one step long", line 4 of st("notes 9") is "16,1,60,7"
   TestAssert "the page is told", st("json") contains "[[2,2,50,7],[4,6,52,7],[14,2,48,7],[15,1,60,7]]"
   TestAssert "the file has them", saved() contains "notes" & tab & "9" & tab & "3,2,50,7;5,6,52,7;15,2,48,7;16,1,60,7"
   -- by the right end of a note, it is made longer or shorter
   get says("btPointerDown", "note 2", the right of ctl("graphic", "note 2") - 2, pianoY(52), false)
   studio "btPointerMove", pianoX(6), pianoY(52)
   studio "btEndDrag"
   TestAssert "its end dragged back", line 2 of st("notes 9") is "5,2,52,7"
end TestThePianoRollAddsAndStretchesNotes

on TestNotesMoveAndGo
   local tY
   studio "btChooseChannel", 10
   press "Tab Piano"
   clickNote 1, 55
   TestAssert "a note", st("notes 10") is "1,2,55,7"
   -- a drag moves it, by steps and semitones
   get says("btPointerDown", "note 1", pianoX(1), pianoY(55), false)
   studio "btPointerMove", pianoX(4), pianoY(58)
   studio "btEndDrag"
   TestAssert "moved, and kept", st("notes 10") is "4,2,58,7"
   get says("btPointerDown", "note 1", pianoX(4), pianoY(58), false)
   studio "btPointerMove", pianoX(16) + 40, pianoY(58)
   studio "btEndDrag"
   TestAssert "not past the pattern's end", st("notes 10") is "15,2,58,7"
   clickNote 15, 58, true
   TestAssert "shift-click: louder", st("notes 10") is "15,2,58,9"
   TestAssert "drawn solid", the blendLevel of ctl("graphic", "note 1") is 0
   clickNote 16, 58, true
   TestAssert "softer", st("notes 10") is "15,2,58,4"
   clickNote 15, 58
   TestAssert "a click without a drag takes it away", st("notes 10") is empty
   TestAssert "and its drawing", not the visible of ctl("graphic", "note 1")
   -- two steps long, every other step: no note under the next click
   repeat with tY = 1 to 70
      clickNote ((tY - 1) mod 8) * 2 + 1, 48 + (tY - 1) div 8
   end repeat
   TestAssert "at most 64 notes", the number of lines of st("notes 10") is 64
end TestNotesMoveAndGo

on TestThePianoRollsChannelAndOctaves
   press "Tab Piano"
   studio "btSelectPattern", 4
   press "Piano Prev"
   TestAssert "Prev from the first goes round to the last", st("pianoch") is 10 and \
         the text of ctl("field", "Piano Chan") is "10. Keys"
   TestAssert "its notes drawn", the visible of ctl("graphic", "note 9") and not the visible of ctl("graphic", "note 10")
   press "Piano Next"
   TestAssert "Next goes round to the first", st("pianoch") is 1
   press "Oct Down"
   TestAssert "an octave lower", st("pianolow") is 36 and the text of ctl("field", "Oct Label") is "C2 to B3"
   repeat 5 times
      press "Oct Down"
   end repeat
   TestAssert "C1 at the lowest", st("pianolow") is 24
   repeat 9 times
      press "Oct Up"
   end repeat
   TestAssert "C5 at the highest", st("pianolow") is 72 and the text of ctl("field", "Oct Label") is "C5 to B6"
   TestAssert "a note as high as the piano roll goes", says("btAddNote", 1, 1, 95, 7) is 1
   TestAssert "none higher, where it could not be seen", says("btAddNote", 1, 1, 96, 7) is 0 and \
         says("btAddNote", 1, 1, 23, 7) is 0 and the number of lines of st("notes 1") is 1
   studio "btSetPianoChannel", 10
   TestAssert "notes out of sight are counted", the text of ctl("field", "Piano Info") is "Notes out of sight: 9 lower"
   TestAssert "and not drawn", not the visible of ctl("graphic", "note 1")
   TestAssert "a key plays its note", says("btPointerDown", "key 1", 220, 200, false)
end TestThePianoRollsChannelAndOctaves

----------------------------------------------------------------------
-- The mixer

on TestTheMixerSetsEachChannel
   local tG
   press "Tab Mixer"
   TestAssert "a strip a channel", the visible of ctl("graphic", "fader 10") and not the visible of ctl("graphic", "fader 11")
   TestAssert "named", the text of ctl("field", "mxname 9") is "Square bass"
   TestAssert "its volume", the text of ctl("field", "mxvol 4") is "70"
   put ctl("graphic", "fader 4") into tG
   get says("btPointerDown", "fader 4", item 1 of the loc of tG, the bottom of tG - the height of tG div 4, false)
   studio "btEndDrag"
   TestAssert "a fader a quarter up is 25", st("vol 4") is 25 and the text of ctl("field", "mxvol 4") is "25"
   TestAssert "its fill a quarter high", the height of ctl("graphic", "faderfill 4") is round(the height of tG / 4)
   get says("btPointerDown", "fadercap 4", item 1 of the loc of tG, the top of tG - 30, false)
   studio "btEndDrag"
   TestAssert "its cap drags it too, to 100 at most", st("vol 4") is 100
   repeat for each item tG in "cut,rev,dly"
      get says("btPointerDown", tG && 2, the left of ctl("graphic", tG && 2) + the width of ctl("graphic", tG && 2) div 2, \
            item 2 of the loc of ctl("graphic", tG && 2), false)
      studio "btEndDrag"
      TestAssert tG && "half along is 50", st(tG && 2) is 50
   end repeat
   get says("btPointerDown", "mxpanfill 2", the right of ctl("graphic", "mxpan 2"), item 2 of the loc of ctl("graphic", "mxpan 2"), false)
   studio "btEndDrag"
   TestAssert "the pan's right end is 100", st("pan 2") is 100
   TestAssert "the page is told", st("json") contains chJson(2, 78, 100, 0, 0, 50, 50, 50, 0)
   press "mxmute 2"
   TestAssert "mute", st("mute 2") is true and the backgroundColor of ctl("button", "mxmute 2") is "#FF7A3D"
   TestAssert "its name greyed", the textColor of ctl("field", "mxname 2") is "#4A4870"
   press "mxsolo 3"
   TestAssert "solo", st("solo 3") is true and not st("audible 1")
   studio "btSetChannel", 2, "cut", 300
   studio "btSetChannel", 2, "rev", -5
   studio "btSetChannel", 2, "tune", 99
   studio "btSetChannel", 2, "colour", 5
   TestAssert "each in its range", st("cut 2") is 100 and st("rev 2") is 0 and st("tune 2") is 24
   TestAssert "tuning shown with its sign", the text of ctl("field", "mxtune 2") is "+24"
end TestTheMixerSetsEachChannel

on TestATuningIsDraggedUpAndDown
   local tF
   press "Tab Mixer"
   put ctl("field", "mxtune 5") into tF
   get says("btPointerDown", "mxtune 5", item 1 of the loc of tF, 300, false)
   studio "btPointerMove", item 1 of the loc of tF, 260
   TestAssert "up 40 points is 5 semitones up", st("tune 5") is 5
   studio "btPointerMove", item 1 of the loc of tF, 340
   studio "btEndDrag"
   TestAssert "down 40 is 5 down", st("tune 5") is -5 and the text of ctl("field", "mxtune 5") is "-5"
   TestAssert "the page is told", st("json") contains chJson(6, 78, 0, 0, 0, 100, 0, 15, -5)
end TestATuningIsDraggedUpAndDown

on TestTheMasterAndTheEffects
   local tG
   press "Tab Mixer"
   TestAssert "the master's volume", the text of ctl("field", "mxvol 0") is "80"
   put ctl("graphic", "fader 0") into tG
   get says("btPointerDown", "fader 0", item 1 of the loc of tG, the top of tG + the height of tG div 2, false)
   studio "btEndDrag"
   TestAssert "the master's fader", st("master vol") is 50
   TestAssert "a room", the backgroundColor of ctl("button", "Reverb Room") is "#FFB52E"
   press "Reverb Hall"
   TestAssert "a hall", st("master size") is 1 and the backgroundColor of ctl("button", "Reverb Hall") is "#FFB52E"
   press "Delay 4"
   TestAssert "a delay of a quarter", st("master dly") is 4 and the backgroundColor of ctl("button", "Delay 4") is "#FFB52E"
   put ctl("graphic", "fb") into tG
   get says("btPointerDown", "fbfill", the right of tG + 20, item 2 of the loc of tG, false)
   studio "btEndDrag"
   TestAssert "feedback 90 at most", st("master fb") is 90 and the text of ctl("field", "fbValue") is "90%"
   TestAssert "the page is told", st("json") contains quote & "master" & quote & ":[50,1,4,90]"
   studio "btSetMaster", "dly", 9
   studio "btSetMaster", "size", 5
   TestAssert "each in its range", st("master dly") is 4 and st("master size") is 1
end TestTheMasterAndTheEffects

on TestTheMetersShowTheLevels
   press "Tab Mixer"
   studio "btDrawMeters", "50,0,0,0,0,0,0,0,0,100,95"
   TestAssert "a channel's meter at half", the visible of ctl("graphic", "meter 1") and \
         the height of ctl("graphic", "meter 1") is round(the height of ctl("graphic", "meterbg 1") / 2)
   TestAssert "a silent one down", not the visible of ctl("graphic", "meter 2")
   TestAssert "a loud one ember", the backgroundColor of ctl("graphic", "meter 10") is "#FF7A3D"
   TestAssert "the master's", the visible of ctl("graphic", "meter 0") and the backgroundColor of ctl("graphic", "meter 0") is "#FF7A3D"
   studio "btDrawMeters", empty
   TestAssert "all down", not the visible of ctl("graphic", "meter 1") and not the visible of ctl("graphic", "meter 0")
end TestTheMetersShowTheLevels

----------------------------------------------------------------------
-- Undo and Redo

on TestUndoAndRedo
   local tFirst
   put st("text") into tFirst
   TestAssert "nothing to undo yet", st("undo") is "1/1"
   clickPad 2, 2
   studio "btSetTempo", 100
   TestAssert "two steps", st("undo") is "3/3"
   press "Undo"
   TestAssert "the tempo back", st("bpm") is 122 and char 2 of st("row 2") is "7"
   press "Undo"
   TestAssert "the pad back", char 2 of st("row 2") is "0" and st("text") is tFirst
   TestAssert "and drawn", the backgroundColor of pad(2, 2) is "#1F2249"
   press "Undo"
   TestAssert "no further", st("text") is tFirst and the text of ctl("field", "Status") is "Nothing to undo."
   press "Redo"
   press "Redo"
   TestAssert "both again", st("bpm") is 100 and char 2 of st("row 2") is "7"
   press "Undo"
   studio "btSetSwing", 40
   press "Redo"
   TestAssert "a change after Undo ends Redo", st("bpm") is 122 and st("swing") is 40
   studio "btSelectPattern", 3
   TestAssert "choosing a pattern is not a change", st("undo") is "3/3"
   press "New"
   press "New"
   TestAssert "a new song", st("pats") is 1
   press "Undo"
   TestAssert "Undo brings the old one back", st("pats") is 4 and st("swing") is 40
   TestAssert "and saves it", saved() is st("text")
end TestUndoAndRedo

on TestADragIsOneStepOfUndo
   local tTrack, tY, tX
   put ctl("graphic", "Swing Track") into tTrack
   put item 2 of the loc of tTrack into tY
   get says("btPointerDown", "Swing Track", the left of tTrack, tY, false)
   repeat with tX = 1 to 10
      studio "btPointerMove", the left of tTrack + tX * 5, tY
   end repeat
   studio "btEndDrag"
   TestAssert "one step", st("undo") is "2/2"
   press "Undo"
   TestAssert "the swing as it was", st("swing") is 18
   studio "btChooseChannel", 9
   press "Tab Piano"
   clickNote 2, 50
   get says("btPointerDown", "note 1", pianoX(2), pianoY(50), false)
   studio "btPointerMove", pianoX(5), pianoY(53)
   studio "btEndDrag"
   press "Undo"
   TestAssert "a note's move undone", st("notes 9") is "2,2,50,7"
   press "Undo"
   TestAssert "and the note", st("notes 9") is empty
end TestADragIsOneStepOfUndo

----------------------------------------------------------------------
-- New and Demo

on TestNewAsksFirst
   local tText
   put st("text") into tText
   press "New"
   TestAssert "the first press asks", the label of ctl("button", "New") is "Sure? Press again"
   TestAssert "and changes nothing", st("text") is tText
   press "Tempo Up"
   TestAssert "another button takes the question back", the label of ctl("button", "New") is "New empty song"
   press "New"
   press "New"
   TestAssert "two presses: an empty song", st("pats") is 1 and st("chans") is 8 and st("row 1") is zeros(32)
   TestAssert "at 120", st("bpm") is 120 and st("swing") is 0
   TestAssert "with an empty playlist", st("track 1") is empty and st("songsteps") is 16
   press "Demo"
   TestAssert "Demo brings the demo back", st("pats") is 4 and st("name 2") is "Groove B"
end TestNewAsksFirst

----------------------------------------------------------------------
-- What the page is told, and what a file may hold

on TestThePageIsToldTheSong
   local tRows, tJson, n
   press "New"
   press "New"
   studio "btSetStep", 1, 1, 9
   studio "btSetStep", 8, 16, 3
   studio "btSetPan", 2, -25
   studio "btToggleSolo", 3
   put quote & "9" & zeros(15) & quote into tRows
   repeat 6 times
      put "," & quote & zeros(16) & quote after tRows
   end repeat
   put "," & quote & zeros(15) & "3" & quote after tRows
   put "{" & quote & "bpm" & quote & ":120," & quote & "swing" & quote & ":0," & quote & "mode" & quote & ":" & quote & \
         "pattern" & quote & "," & quote & "cur" & quote & ":0," & quote & "from" & quote & ":0," & quote & "master" & \
         quote & ":[80,0,3,35]," & quote & "ch" & quote & ":[" & chJson(0, 78, 0, 0, 0, 100, 0, 0, 0) & "," & \
         chJson(2, 78, -25, 0, 0, 100, 0, 0, 0) & "," & chJson(4, 78, 0, 0, 1, 100, 0, 0, 0) & "," & \
         chJson(5, 78, 0, 0, 0, 100, 0, 0, 0) & "," & chJson(6, 78, 0, 0, 0, 100, 0, 0, 0) & "," & \
         chJson(9, 78, 0, 0, 0, 100, 0, 0, 0) & "," & chJson(11, 78, 0, 0, 0, 100, 0, 0, 0) & "," & \
         chJson(15, 78, 0, 0, 0, 100, 0, 0, 0) & "]," & quote & "pats" & quote & ":[{" & quote & "steps" & quote & ":16," & \
         quote & "rows" & quote & ":[" & tRows & "]," & quote & "notes" & quote & ":[[],[],[],[],[],[],[],[]]}]," & \
         quote & "song" & quote & ":[]}" into tJson
   TestAssert "the song as JSON", st("json") is tJson
end TestThePageIsToldTheSong

on TestAFileThatIsNotASongIsRefused
   local tText, tSong
   put st("text") into tText
   TestAssert "nonsense", not says("btTestRead", "hello")
   TestAssert "Beat Box's file", not says("btTestRead", "120" & return & "1000100010001000,false")
   TestAssert "no channels", not says("btTestRead", "beyond-beats 2" & return & "bpm" & tab & "100")
   TestAssert "a row before any pattern", not says("btTestRead", "beyond-beats 2" & return & "ch" & tab & "1" & return & "row" & tab & "9")
   TestAssert "a newer version", not says("btTestRead", "beyond-beats 3" & return & "ch" & tab & "1" & return & "pat" & tab & "A" & tab & "16")
   TestAssert "the song is as it was", st("text") is tText
   put "beyond-beats 2" & return & "bpm" & tab & "999" & return & "swing" & tab & "-4" & return & "cur" & tab & "9" & return into tSong
   put "mode" & tab & "sideways" & return & "from" & tab & "999" & return & "master" & tab & "300" & tab & "7" & tab & "1" & tab & "x" & return after tSong
   put "ch" & tab & "40" & tab & "500" & tab & "0" & tab & "true" & tab & "false" & tab & "-1" & tab & "200" & tab & "50" & tab & "60" & return after tSong
   put "ch" & tab & "2" & tab & "50" & tab & "-20" & tab & "false" & tab & "true" & return after tSong
   put "pat" & tab & "Odd" & tab & "7" & return after tSong
   put "row" & tab & "9x7" & return after tSong
   put "notes" & tab & "1" & tab & "40,4,10,12;5,99,64,3;x,1,60,7;2,1,60" & return after tSong
   put "notes" & tab & "7" & tab & "1,1,60,7" & return after tSong
   put "track" & tab & "1" & tab & "1:1,0:1,200:1,3:2,x:1,5:1" & return after tSong
   put "track" & tab & "9" & tab & "1:1" & return after tSong
   put "sample" & tab & "3" & tab & "a/b/kick.wav" & return & "sample" & tab & "12" & tab & "no.wav" & return after tSong
   TestAssert "a song made safe is read", says("btTestRead", tSong)
   TestAssert "its tempo in range", st("bpm") is 240 and st("swing") is 0
   TestAssert "its pattern in range", st("cur") is 1 and st("steps") is 16
   TestAssert "its mode and start", st("mode") is "pattern" and st("from") is 128
   TestAssert "its master", st("master vol") is 100 and st("master size") is 1 and st("master dly") is 2 and st("master fb") is 35
   TestAssert "a sound in range", st("sound 1") is 29 and st("vol 1") is 100 and st("mute 1") is true
   TestAssert "its mixer in range", st("cut 1") is 0 and st("rev 1") is 100 and st("dly 1") is 50 and st("tune 1") is 24
   TestAssert "the second channel", st("sound 2") is 2 and st("pan 2") is -20 and st("solo 2") is true and st("cut 2") is 100
   TestAssert "what is not a digit is off, and short rows filled", st("row 1") is "907" & zeros(29)
   TestAssert "a missing row is empty", st("row 2") is zeros(32)
   TestAssert "notes made safe, nonsense dropped", st("notes 1") is "32,1,24,9" & return & "5,28,64,3" & return & "2,1,60,7"
   TestAssert "notes of a channel it lacks dropped", st("notes 2") is empty and the number of lines of st("text") > 0
   TestAssert "blocks made safe", st("track 1") is "1:1,5:1"
   TestAssert "a sample's name, without its folders", st("user 3") is "kick.wav" and st("user 8") is empty
end TestAFileThatIsNotASongIsRefused

----------------------------------------------------------------------
-- Files of the user's own

on TestASongFileGoesAndComesBack
   local tFile, tText
   put sSave & "-song.beats" into tFile
   studio "btSetTempo", 140
   studio "btSetChannel", 10, "rev", 80
   put st("text") into tText
   studio "btSaveProject", tFile
   TestAssert "saved", there is a file tFile and the text of ctl("field", "Status") contains "Saved"
   press "New"
   press "New"
   TestAssert "a new song", st("bpm") is 120
   studio "btOpenProject", tFile
   TestAssert "the song opened", st("text") is tText
   TestAssert "and said so", the text of ctl("field", "Status") contains "Opened"
   TestAssert "and kept", saved() is tText
   put "hello" into url ("file:" & tFile)
   studio "btOpenProject", tFile
   TestAssert "a file that is not a song is not opened", st("text") is tText and \
         the text of ctl("field", "Status") contains "is not a Beyond Beats song"
   delete file tFile
end TestASongFileGoesAndComesBack

on TestASampleIsLoadedAndKept
   local tFolder, tWav, tLong, tSong
   put sSave & "-in" into tFolder
   create folder tFolder
   put tFolder & "/click.wav" into tWav
   put wavFile() into url ("binfile:" & tWav)
   studio "btImportSample", 3, tWav
   TestAssert "into the first slot, by its name", st("user 1") is "click.wav"
   TestAssert "channel 3 plays it", st("sound 3") is 22
   TestAssert "and is named for it", the label of ctl("button", "chan 3") is "click.wav"
   TestAssert "kept beside the song", there is a file (sSave & "-samples/sample-1.bin") and \
         url ("binfile:" & sSave & "-samples/sample-1.bin") is wavFile()
   TestAssert "in the song's file", saved() contains "sample" & tab & "1" & tab
   press "chan 3"
   TestAssert "the picker names it", the label of ctl("button", "pick 22") is "click.wav" and \
         the backgroundColor of ctl("button", "pick 22") is "#FFB52E"
   press "Tab Rack"
   studio "btImportSample", 3, tWav
   TestAssert "loaded again into a channel that plays one: the same slot", st("user 2") is empty and st("sound 3") is 22
   studio "btImportSample", empty, tWav
   TestAssert "with no channel, a new one in the next slot", st("chans") is 11 and st("sound 11") is 23 and \
         st("user 2") is "click.wav"
   put tFolder & "/" & zeros(30) & "-a-sample-with-a-long-name.wav" into tLong
   put wavFile() into url ("binfile:" & tLong)
   studio "btImportSample", 11, tLong
   TestAssert "a long name is cut to 40 characters", st("user 2") is char 1 to 40 of (zeros(30) & "-a-sample-with-a-long-name.wav")
   delete file tLong
   -- a song file carries its samples
   put sSave & "-with-samples.beats" into tSong
   studio "btSaveProject", tSong
   TestAssert "the file has the data", url ("file:" & tSong) contains "sampledata" & tab & "1" & tab & \
         replaceText(base64Encode(wavFile()), "[\r\n]", "")
   delete file (sSave & "-samples/sample-1.bin")
   delete file (sSave & "-samples/sample-2.bin")
   press "New"
   press "New"
   studio "btOpenProject", tSong
   TestAssert "opened, the samples are back", st("sound 3") is 22 and \
         url ("binfile:" & sSave & "-samples/sample-1.bin") is wavFile() and there is a file (sSave & "-samples/sample-2.bin")
   put "x" into url ("binfile:" & tWav)
   put "" into url ("binfile:" & tWav)
   studio "btImportSample", 4, tWav
   TestAssert "an empty file is not a sample", st("sound 4") is 6 and the text of ctl("field", "Status") contains "could not be read"
   delete file tWav
   delete folder tFolder
   delete file tSong
end TestASampleIsLoadedAndKept

on TestExportingNeedsABrowser
   if the platform is "HTML5" then
      studio "btExport", "test.wav"
      do "window.beyondBeats ? beyondBeats.exportState() : 'none'" as "JavaScript"
      TestAssert "the page renders the song", the result is among the items of "working,done"
   else
      press "File Export"
      TestAssert "elsewhere it says why not", the text of ctl("field", "Status") contains "needs a browser"
   end if
end TestExportingNeedsABrowser

----------------------------------------------------------------------
-- Playing, without a browser

-- On a desktop the playheads run on the engine's clock; in the web engine
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

on TestSongModePlaysThePlaylist
   press "Tab Song"
   press "Mode Song"
   studio "btSetFrom", 5
   press "Play"
   if the platform is "HTML5" then
      do "window.beyondBeats ? beyondBeats.song.mode + ',' + beyondBeats.song.from + ',' + beyondBeats.at.length : 'none'" as "JavaScript"
      TestAssert "the page's core plays the song from bar 5", the result is "song,64,128"
   else
      wait 300 milliseconds with messages
      TestAssert "the song's playhead from bar 5", the visible of ctl("graphic", "SongHead") and \
            the left of ctl("graphic", "SongHead") >= the left of ctl("graphic", "cell 1,5")
      TestAssert "at the song's step", st("step") >= 65
   end if
   press "Tab Rack"
   if the platform is not "HTML5" then
      -- bars 5 and 6 play Groove (pattern 1), not Fill (pattern 3)
      wait 50 milliseconds with messages
      TestAssert "the rack's playhead on the pattern shown where it plays", the visible of ctl("graphic", "Head")
      studio "btSelectPattern", 3
      wait 50 milliseconds with messages
      TestAssert "and not where it does not", not the visible of ctl("graphic", "Head")
   end if
   press "Mode Pattern"
   TestAssert "a mode changed as it plays plays on", st("playing") is true
   press "Play"
   TestAssert "stopped", st("playing") is false
end TestSongModePlaysThePlaylist
