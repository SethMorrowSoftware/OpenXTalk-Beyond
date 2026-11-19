script "Beyond Beats"
-- Beyond Beats: a pattern studio for a browser, made with OXT-Beyond.
-- Built by tools/web-player/beyond-beats.livecodescript in OXT-Beyond's
-- repository, from this script and the audio core beside it
-- (beyond-beats/audio-core.js). Its sounds are made by that core, sample
-- by sample, so there are no sound files.
--
-- Up to twelve channels, each a sound of the kit with its own volume,
-- pan, mute and solo; up to sixteen patterns of 16 or 32 steps, each step
-- off or on at a velocity from 1 to 9; a tempo and a swing. The song is
-- kept in the browser's storage and is there on the next visit.
--
-- How it is made:
--   the song is here, in sSong (below); the screen only shows it. Every
--     change goes through a bt... command, which changes sSong, draws what
--     changed, tells the audio core and saves
--   the sound is the page's: the audio core (the custom property
--     cAudioCore, run once with do ... as "JavaScript") makes the kit,
--     mixes the channels and books every step on the browser's audio
--     clock a moment ahead, so the beat stays steady while the engine
--     draws. The script sends it the pattern playing with btSend and asks
--     it which step is sounding, about sixty times a second, to move the
--     playhead
--   graphics and fields, not pictures: a fixed set of controls made by the
--     builder (12 channel rows of 32 pads), shown and hidden, never created
--     while it plays. btLayout places them all
--   outside a browser it opens and edits as well, saves to a file of its
--     own, and plays without sound: the playhead runs on the engine's clock
--
-- For the tests (tests/lcs/webplayer/beyond-beats.livecodescript):
-- btTestBegin keeps the song in a file of the test's own and saves at
-- once, and btState says how things are.

constant kKit = "Kick,Boom,Snare,Rim,Clap,Closed hat,Open hat,Crash,Ride,Low tom,High tom,Shaker,Cowbell,Clave,Snap,Bass"
constant kColors = "#FF7A3D,#FFB52E,#FFE066,#7CF29A,#3DDBB8,#5CD6FF,#6C8CFF,#B48CFF,#FF6FB5,#FF5D73,#F2A65A,#9ED0FF"
constant kKitSize = 16
constant kMaxChannels = 12
constant kMaxPatterns = 16
constant kMaxSteps = 32
constant kSaveName = "beyond-beats.txt"
constant kFormat = "beyond-beats 1"

-- colours: the night sky and its fire
constant kNight = "#0B0D1F"
constant kPanel = "#151839"
constant kCell = "#1F2249"
constant kCellBeat = "#2A2E5E"
constant kInk = "#F4EEFF"
constant kMuted = "#9A96C0"
constant kDim = "#4A4870"
constant kAmber = "#FFB52E"
constant kEmber = "#FF7A3D"

-- the rack's geometry: its rows, and the grid of pads in each
constant kRowTop = 108
constant kRowH = 34
constant kPadH = 28
constant kGridLeft = 500
constant kGridWidth = 444

-- sSong: the whole song
--   ["bpm"] 40..240, ["swing"] 0..100, ["cur"] the pattern shown and played
--   ["chans"] how many channels; ["ch"][n]["sound"] 1..16, ["vol"] 0..100,
--     ["pan"] -100..100, ["mute"] and ["solo"] true or false
--   ["pats"] how many patterns; ["pat"][p]["name"], ["steps"] 16 or 32,
--     ["rows"][n] 32 digits, one a step: 0 off, 1..9 its velocity (the
--     steps past ["steps"] are kept, so going back to 32 loses nothing)
local sSong
local sPlaying, sStep, sTimer, sFallbackAt, sAudio
local sDrag, sDragFrom, sPaint, sPaintRow, sPaintLast, sPicker
local sSaveTimer, sSaveFile, sTest, sNewArmed, sSwallowUp

on preOpenCard
   if sSong is not an array then
      put 0 into sStep
      put false into sPlaying
      if not btLoad() then
         btDemoSong
      end if
      btDrawAll
      btSend
   end if
end preOpenCard

on closeCard
   btStop
end closeCard

----------------------------------------------------------------------
-- The mouse and the keys
----------------------------------------------------------------------

on mouseDown pButton
   if sPicker is not empty then
      if not (the long id of the target contains "group" && quote & "Picker" & quote) then
         -- a click away from the picker only closes it
         btClosePicker
         put true into sSwallowUp
         exit mouseDown
      end if
      pass mouseDown
   end if
   if not btPointerDown(the short name of the target, item 1 of the mouseLoc, item 2 of the mouseLoc, \
         pButton is 3 or the shiftKey is down) then
      pass mouseDown
   end if
end mouseDown

-- A press at a point of the card, on the control named pName: a pad (by
-- where it is), a slider, or the tempo. pAlt: a right-click or a
-- shift-click. False when it is none of those.
function btPointerDown pName, pX, pY, pAlt
   local tRow, tStep
   -- the grid: worked out from where the mouse is, so that a pad under
   -- the playhead is clicked as well as any other
   put btRowAt(pY) into tRow
   put btStepAt(pX) into tStep
   if tRow > 0 and tStep > 0 then
      if pAlt then
         btCycleVelocity tRow, tStep
      else
         if btStep(tRow, tStep) is 0 then
            put 7 into sPaint
         else
            put 0 into sPaint
         end if
         put tRow into sPaintRow
         put tStep into sPaintLast
         btSetStep tRow, tStep, sPaint
         if sPaint > 0 and not sPlaying then
            btHit tRow, sPaint
         end if
      end if
      return true
   end if
   if pName begins with "vol " or pName begins with "volfill " then
      put "vol" && word 2 of pName into sDrag
      btDragTo pX, pY
   else if pName begins with "pan " or pName begins with "panfill " then
      put "pan" && word 2 of pName into sDrag
      btDragTo pX, pY
   else if pName begins with "Swing " and pName is not "Swing Label" and pName is not "Swing Value" then
      put "swing" into sDrag
      btDragTo pX, pY
   else if pName is "Tempo" then
      put "tempo" into sDrag
      put pY & comma & sSong["bpm"] into sDragFrom
   else
      return false
   end if
   return true
end btPointerDown

on mouseMove pX, pY
   btPointerMove pX, pY
   pass mouseMove
end mouseMove

-- The mouse moved while pressed: a slider follows it, and a drag along a
-- row paints its steps on (or off, when it began on a step that was on).
command btPointerMove pX, pY
   local tStep, tFrom, tTo, s
   if sDrag is not empty then
      btDragTo pX, pY
   else if sPaint is not empty then
      put btStepAt(pX) into tStep
      if tStep < 1 or tStep is sPaintLast then
         exit btPointerMove
      end if
      -- every step from the last one painted, so a quick drag skips none;
      -- a step already on keeps its velocity
      put min(tStep, sPaintLast) into tFrom
      put max(tStep, sPaintLast) into tTo
      lock screen
      repeat with s = tFrom to tTo
         if (sPaint > 0) is not (btStep(sPaintRow, s) > 0) then
            btSetStep sPaintRow, s, sPaint
         end if
      end repeat
      unlock screen
      put tStep into sPaintLast
   end if
end btPointerMove

on mouseRelease
   btEndDrag
   pass mouseRelease
end mouseRelease

on mouseUp
   local tName, tLine
   put the short name of the target into tName
   if sSwallowUp then
      put false into sSwallowUp
      exit mouseUp
   end if
   if sDrag is not empty or sPaint is not empty then
      btEndDrag
      exit mouseUp
   end if
   if word 1 of the long id of the target is "button" then
      btPress tName
   else if tName begins with "swatch " then
      btHit word 2 of tName, 7
   else if tName is "Patterns" then
      put the hilitedLine of field "Patterns" into tLine
      if tLine is an integer then
         btSelectPattern tLine
      end if
   else
      pass mouseUp
   end if
end mouseUp

on keyDown pKey
   if pKey is space and the selectedField is empty then
      btPlayStop
   else
      pass keyDown
   end if
end keyDown

-- A button, by its name: what its mouseUp does (the tests press them
-- this way too).
command btPress pName
   local tWhich
   put word 2 of pName into tWhich
   if pName is not "New" and sNewArmed then
      put false into sNewArmed
      set the label of button "New" to "New"
   end if
   switch
      case pName is "Play"
         btPlayStop
         break
      case pName is "Tempo Down"
         if the shiftKey is down then
            btSetTempo sSong["bpm"] - 10
         else
            btSetTempo sSong["bpm"] - 1
         end if
         break
      case pName is "Tempo Up"
         if the shiftKey is down then
            btSetTempo sSong["bpm"] + 10
         else
            btSetTempo sSong["bpm"] + 1
         end if
         break
      case pName begins with "Steps "
         btSetSteps tWhich
         break
      case pName is "Pattern New"
         btNewPattern
         break
      case pName is "Pattern Clone"
         btClonePattern
         break
      case pName is "Pattern Clear"
         btClearPattern
         break
      case pName is "Pattern Delete"
         btDeletePattern sSong["cur"]
         break
      case pName is "Add Channel"
         btAddChannel
         break
      case pName begins with "chan "
         btOpenPicker tWhich
         break
      case pName begins with "mute "
         btToggleMute tWhich
         break
      case pName begins with "solo "
         btToggleSolo tWhich
         break
      case pName is "Pick Remove"
         -- (before "pick n", which its name also begins with)
         if sPicker is not empty then
            get sPicker
            btClosePicker
            btRemoveChannel it
         end if
         break
      case pName begins with "pick "
         if sPicker is not empty then
            btSetSound sPicker, tWhich
            btHit sPicker, 7
            btClosePicker
         end if
         break
      case pName is "New"
         -- twice to be sure: the first press asks, the second clears
         if sNewArmed then
            put false into sNewArmed
            set the label of button "New" to "New"
            btNewSong
         else
            put true into sNewArmed
            set the label of button "New" to "Sure?"
            btStatus "Press New again to start an empty song; the one you have is not kept."
         end if
         break
      case pName is "Demo"
         btDemoSong
         break
   end switch
end btPress

-- the row (channel) and the step under a point of the card, or 0
function btRowAt pY
   local tRow
   if pY < kRowTop then
      return 0
   end if
   put (pY - kRowTop) div kRowH + 1 into tRow
   if tRow > sSong["chans"] or pY - kRowTop - (tRow - 1) * kRowH >= kPadH then
      return 0
   end if
   return tRow
end btRowAt

function btStepAt pX
   local tSteps, tStep
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   if pX < kGridLeft or pX >= kGridLeft + kGridWidth or tSteps is empty then
      return 0
   end if
   put (pX - kGridLeft) * tSteps div kGridWidth + 1 into tStep
   return min(tSteps, max(1, tStep))
end btStepAt

-- A slider dragged (or the tempo, up and down), to the mouse.
command btDragTo pX, pY
   local tKind, tN, tLeft, tWidth, tValue
   put word 1 of sDrag into tKind
   put word 2 of sDrag into tN
   switch tKind
      case "vol"
         put the left of graphic ("vol" && tN) into tLeft
         put the width of graphic ("vol" && tN) into tWidth
         btSetVolume tN, round(100 * (pX - tLeft) / tWidth)
         break
      case "pan"
         put the left of graphic ("pan" && tN) into tLeft
         put the width of graphic ("pan" && tN) into tWidth
         put round(200 * (pX - tLeft) / tWidth) - 100 into tValue
         -- it snaps to the middle near it
         if abs(tValue) < 8 then
            put 0 into tValue
         end if
         btSetPan tN, tValue
         break
      case "swing"
         put the left of graphic "Swing Track" into tLeft
         put the width of graphic "Swing Track" into tWidth
         btSetSwing round(100 * (pX - tLeft) / tWidth)
         break
      case "tempo"
         btSetTempo (item 2 of sDragFrom) + round((item 1 of sDragFrom - pY) / 3)
         break
   end switch
end btDragTo

command btEndDrag
   put empty into sDrag
   put empty into sPaint
   put empty into sPaintRow
   put empty into sPaintLast
end btEndDrag

----------------------------------------------------------------------
-- The song: every change goes through here
----------------------------------------------------------------------

function btStep pRow, pStep
   return char pStep of sSong["pat"][sSong["cur"]]["rows"][pRow]
end btStep

command btSetStep pRow, pStep, pLevel
   local tP
   put sSong["cur"] into tP
   if pRow < 1 or pRow > sSong["chans"] or pStep < 1 or pStep > kMaxSteps then
      exit btSetStep
   end if
   put max(0, min(9, round(pLevel))) into char pStep of sSong["pat"][tP]["rows"][pRow]
   btDrawPad pRow, pStep
   btChanged
end btSetStep

-- A step that is on, a shift-click or a right-click: normal (7), loud
-- (9), soft (4), round again. One that is off comes on loud.
command btCycleVelocity pRow, pStep
   switch btStep(pRow, pStep)
      case 0
         btSetStep pRow, pStep, 9
         break
      case 7
         btSetStep pRow, pStep, 9
         break
      case 9
         btSetStep pRow, pStep, 4
         break
      default
         btSetStep pRow, pStep, 7
   end switch
   if not sPlaying then
      btHit pRow, btStep(pRow, pStep)
   end if
end btCycleVelocity

command btSetTempo pBpm
   if pBpm is not a number then
      exit btSetTempo
   end if
   put max(40, min(240, round(pBpm))) into sSong["bpm"]
   btDrawTop
   btChanged
end btSetTempo

command btSetSwing pSwing
   if pSwing is not a number then
      exit btSetSwing
   end if
   put max(0, min(100, round(pSwing))) into sSong["swing"]
   btDrawTop
   btChanged
end btSetSwing

command btSetSteps pSteps
   if pSteps is not 16 and pSteps is not 32 then
      exit btSetSteps
   end if
   put pSteps into sSong["pat"][sSong["cur"]]["steps"]
   btDrawAll
   btChanged
end btSetSteps

command btSetVolume pRow, pVolume
   put max(0, min(100, round(pVolume))) into sSong["ch"][pRow]["vol"]
   btDrawChannel pRow
   btChanged
end btSetVolume

command btSetPan pRow, pPan
   put max(-100, min(100, round(pPan))) into sSong["ch"][pRow]["pan"]
   btDrawChannel pRow
   btChanged
end btSetPan

command btToggleMute pRow
   put not sSong["ch"][pRow]["mute"] into sSong["ch"][pRow]["mute"]
   btDrawRows
   btChanged
end btToggleMute

command btToggleSolo pRow
   put not sSong["ch"][pRow]["solo"] into sSong["ch"][pRow]["solo"]
   btDrawRows
   btChanged
end btToggleSolo

-- Whether a channel is heard: not muted, and soloed if any channel is.
-- (The audio core asks the same: beyondBeats.audible.)
function btAudible pRow
   local n
   if sSong["ch"][pRow]["mute"] then
      return false
   end if
   repeat with n = 1 to sSong["chans"]
      if sSong["ch"][n]["solo"] then
         return sSong["ch"][pRow]["solo"] is true
      end if
   end repeat
   return true
end btAudible

command btSetSound pRow, pSound
   if pSound is not an integer or pSound < 1 or pSound > kKitSize then
      exit btSetSound
   end if
   put pSound into sSong["ch"][pRow]["sound"]
   btDrawChannel pRow
   btChanged
end btSetSound

command btAddChannel pSound
   local n, p
   if sSong["chans"] >= kMaxChannels then
      btStatus "Twelve channels is the most a song has."
      exit btAddChannel
   end if
   add 1 to sSong["chans"]
   put sSong["chans"] into n
   if pSound is empty then
      put 1 into pSound
   end if
   btNewChannel n, pSound
   repeat with p = 1 to sSong["pats"]
      put btEmptyRow() into sSong["pat"][p]["rows"][n]
   end repeat
   btDrawAll
   btChanged
end btAddChannel

command btRemoveChannel pRow
   local n, p
   if sSong["chans"] <= 1 then
      btStatus "A song keeps at least one channel."
      exit btRemoveChannel
   end if
   repeat with n = pRow to sSong["chans"] - 1
      put sSong["ch"][n + 1] into sSong["ch"][n]
      repeat with p = 1 to sSong["pats"]
         put sSong["pat"][p]["rows"][n + 1] into sSong["pat"][p]["rows"][n]
      end repeat
   end repeat
   delete variable sSong["ch"][sSong["chans"]]
   repeat with p = 1 to sSong["pats"]
      delete variable sSong["pat"][p]["rows"][sSong["chans"]]
   end repeat
   subtract 1 from sSong["chans"]
   btDrawAll
   btChanged
end btRemoveChannel

command btSelectPattern pPattern
   if pPattern is not an integer or pPattern < 1 or pPattern > sSong["pats"] then
      exit btSelectPattern
   end if
   put pPattern into sSong["cur"]
   btDrawAll
   btChanged
end btSelectPattern

command btNewPattern
   if sSong["pats"] >= kMaxPatterns then
      btStatus "Sixteen patterns is the most a song has."
      exit btNewPattern
   end if
   add 1 to sSong["pats"]
   btEmptyPattern sSong["pats"], btPatternName()
   btSelectPattern sSong["pats"]
end btNewPattern

-- A copy of the pattern shown, after the last.
command btClonePattern
   local tFrom
   if sSong["pats"] >= kMaxPatterns then
      btStatus "Sixteen patterns is the most a song has."
      exit btClonePattern
   end if
   put sSong["cur"] into tFrom
   add 1 to sSong["pats"]
   put sSong["pat"][tFrom] into sSong["pat"][sSong["pats"]]
   put btPatternName() into sSong["pat"][sSong["pats"]]["name"]
   btSelectPattern sSong["pats"]
end btClonePattern

command btClearPattern
   local n
   repeat with n = 1 to sSong["chans"]
      put btEmptyRow() into sSong["pat"][sSong["cur"]]["rows"][n]
   end repeat
   btDrawAll
   btChanged
end btClearPattern

command btDeletePattern pPattern
   local p
   if sSong["pats"] <= 1 then
      btClearPattern
      exit btDeletePattern
   end if
   repeat with p = pPattern to sSong["pats"] - 1
      put sSong["pat"][p + 1] into sSong["pat"][p]
   end repeat
   delete variable sSong["pat"][sSong["pats"]]
   subtract 1 from sSong["pats"]
   btSelectPattern min(pPattern, sSong["pats"])
end btDeletePattern

-- "Pattern n", n one more than any pattern of that name has
function btPatternName
   local p, tMost
   put 0 into tMost
   repeat with p = 1 to sSong["pats"]
      if word 1 of sSong["pat"][p]["name"] is "Pattern" and word 2 of sSong["pat"][p]["name"] is an integer then
         put max(tMost, word 2 of sSong["pat"][p]["name"]) into tMost
      end if
   end repeat
   return "Pattern" && tMost + 1
end btPatternName

function btEmptyRow
   local tRow
   repeat kMaxSteps times
      put "0" after tRow
   end repeat
   return tRow
end btEmptyRow

command btEmptyPattern pPattern, pName
   local n
   put pName into sSong["pat"][pPattern]["name"]
   put 16 into sSong["pat"][pPattern]["steps"]
   repeat with n = 1 to sSong["chans"]
      put btEmptyRow() into sSong["pat"][pPattern]["rows"][n]
   end repeat
end btEmptyPattern

command btNewChannel pRow, pSound
   put pSound into sSong["ch"][pRow]["sound"]
   put 78 into sSong["ch"][pRow]["vol"]
   put 0 into sSong["ch"][pRow]["pan"]
   put false into sSong["ch"][pRow]["mute"]
   put false into sSong["ch"][pRow]["solo"]
end btNewChannel

-- An empty song: the eight channels a beat starts from, one pattern.
command btNewSong
   local tSounds, n
   put "1,3,5,6,7,10,12,16" into tSounds
   put empty into sSong
   put 120 into sSong["bpm"]
   put 0 into sSong["swing"]
   put the number of items of tSounds into sSong["chans"]
   repeat with n = 1 to sSong["chans"]
      btNewChannel n, item n of tSounds
   end repeat
   put 1 into sSong["pats"]
   btEmptyPattern 1, "Pattern 1"
   put 1 into sSong["cur"]
   btDrawAll
   btChanged
   btStatus "An empty song. Click a pad to add a beat; Space plays and stops."
end btNewSong

-- The song it opens with the first time: three patterns to play with.
command btDemoSong
   local tRows, n
   btNewSong
   put 122 into sSong["bpm"]
   put 18 into sSong["swing"]
   put 3 into sSong["pats"]
   put -18 into sSong["ch"][4]["pan"]
   put 22 into sSong["ch"][7]["pan"]
   put 70 into sSong["ch"][4]["vol"]
   put 62 into sSong["ch"][7]["vol"]
   -- kick, snare, clap, closed hat, open hat, low tom, shaker, bass
   btDemoPattern 1, "Groove", "9000900090009000,0000000000000000,0000900000009000,5070507050705070," & \
         "0000000000000000,0000000000000000,0000000000000000,0090000700900007"
   btDemoPattern 2, "Groove B", "9000900090009000,0000000000000300,0000900000009000,5070500050705000," & \
         "0090009000900090,0000000000000000,3060306030603060,9000009000900090"
   btDemoPattern 3, "Fill", "9000900090000000,0000900000909990,0000900000000000,5070507050700000," & \
         "0000000000000000,0000000090009000,3060306030600000,9000009000000000"
   put 1 into sSong["cur"]
   btDrawAll
   btChanged
   btStatus "A demo beat. Space plays and stops; click pads to change it as it plays."
end btDemoSong

command btDemoPattern pPattern, pName, pRows
   local n
   btEmptyPattern pPattern, pName
   repeat with n = 1 to the number of items of pRows
      put item n of pRows into char 1 to 16 of sSong["pat"][pPattern]["rows"][n]
   end repeat
end btDemoPattern

-- After every change: the page hears it, and it is saved.
command btChanged
   btSend
   if sTest then
      btSaveNow
   else
      if sSaveTimer is not empty then
         cancel sSaveTimer
      end if
      send "btSaveNow" to me in 400 milliseconds
      put the result into sSaveTimer
   end if
end btChanged

----------------------------------------------------------------------
-- The song's file
----------------------------------------------------------------------

-- In a browser, the documents folder is the page's own storage, kept
-- between visits; elsewhere a folder for this sample.
function btSavePath
   local tFolder
   if sSaveFile is not empty then
      return sSaveFile
   end if
   if the platform is "HTML5" then
      put specialFolderPath("documents") into tFolder
   else
      put specialFolderPath("temporary") & "/oxt-beyond-beats" into tFolder
   end if
   if there is not a folder tFolder then
      create folder tFolder
   end if
   return tFolder & "/" & kSaveName
end btSavePath

-- The song as text: a line a setting, a line a channel, and a line for
-- each pattern followed by its rows, the items split by tabs.
function btSongText
   local tText, n, p
   put kFormat & return into tText
   put "bpm" & tab & sSong["bpm"] & return after tText
   put "swing" & tab & sSong["swing"] & return after tText
   put "cur" & tab & sSong["cur"] & return after tText
   repeat with n = 1 to sSong["chans"]
      put "ch" & tab & sSong["ch"][n]["sound"] & tab & sSong["ch"][n]["vol"] & tab & sSong["ch"][n]["pan"] & tab & \
            (sSong["ch"][n]["mute"] is true) & tab & (sSong["ch"][n]["solo"] is true) & return after tText
   end repeat
   repeat with p = 1 to sSong["pats"]
      put "pat" & tab & btClean(sSong["pat"][p]["name"]) & tab & sSong["pat"][p]["steps"] & return after tText
      repeat with n = 1 to sSong["chans"]
         put "row" & tab & sSong["pat"][p]["rows"][n] & return after tText
      end repeat
   end repeat
   return tText
end btSongText

function btClean pText
   replace tab with space in pText
   replace return with space in pText
   replace linefeed with space in pText
   if pText is empty then
      return "Pattern"
   end if
   return char 1 to 40 of pText
end btClean

-- A song from its text into sSong, made safe; false (and sSong as it
-- was) when the text is not one.
function btReadSong pText
   local tSong, tLine, tKey, n, p, tRow, tDigits, i
   set the itemDelimiter to tab
   if line 1 of pText is not kFormat then
      return false
   end if
   put 120 into tSong["bpm"]
   put 0 into tSong["swing"]
   put 1 into tSong["cur"]
   put 0 into tSong["chans"]
   put 0 into tSong["pats"]
   put 0 into n
   repeat for each line tLine in line 2 to -1 of pText
      put item 1 of tLine into tKey
      switch tKey
         case "bpm"
         case "swing"
         case "cur"
            if item 2 of tLine is an integer then
               put item 2 of tLine into tSong[tKey]
            end if
            break
         case "ch"
            if tSong["pats"] > 0 or tSong["chans"] >= kMaxChannels then
               return false
            end if
            add 1 to tSong["chans"]
            put tSong["chans"] into n
            put btWithin(item 2 of tLine, 1, kKitSize, 1) into tSong["ch"][n]["sound"]
            put btWithin(item 3 of tLine, 0, 100, 78) into tSong["ch"][n]["vol"]
            put btWithin(item 4 of tLine, -100, 100, 0) into tSong["ch"][n]["pan"]
            put (item 5 of tLine is "true") into tSong["ch"][n]["mute"]
            put (item 6 of tLine is "true") into tSong["ch"][n]["solo"]
            break
         case "pat"
            if tSong["chans"] < 1 or tSong["pats"] >= kMaxPatterns then
               return false
            end if
            add 1 to tSong["pats"]
            put tSong["pats"] into p
            put 0 into n
            put btClean(item 2 of tLine) into tSong["pat"][p]["name"]
            if item 3 of tLine is 32 then
               put 32 into tSong["pat"][p]["steps"]
            else
               put 16 into tSong["pat"][p]["steps"]
            end if
            break
         case "row"
            if tSong["pats"] < 1 or n >= tSong["chans"] then
               return false
            end if
            add 1 to n
            put empty into tDigits
            put char 1 to kMaxSteps of item 2 of tLine into tRow
            repeat with i = 1 to kMaxSteps
               if char i of tRow is not empty and char i of tRow is among the chars of "0123456789" then
                  put char i of tRow after tDigits
               else
                  put "0" after tDigits
               end if
            end repeat
            put tDigits into tSong["pat"][tSong["pats"]]["rows"][n]
            break
      end switch
   end repeat
   set the itemDelimiter to comma
   if tSong["chans"] < 1 or tSong["pats"] < 1 then
      return false
   end if
   -- a pattern the file cut short has empty rows for the channels it lacks
   repeat with p = 1 to tSong["pats"]
      repeat with n = 1 to tSong["chans"]
         if length(tSong["pat"][p]["rows"][n]) is not kMaxSteps then
            put btEmptyRow() into tSong["pat"][p]["rows"][n]
         end if
      end repeat
   end repeat
   put btWithin(tSong["bpm"], 40, 240, 120) into tSong["bpm"]
   put btWithin(tSong["swing"], 0, 100, 0) into tSong["swing"]
   put btWithin(tSong["cur"], 1, tSong["pats"], 1) into tSong["cur"]
   put tSong into sSong
   return true
end btReadSong

function btWithin pValue, pLow, pHigh, pDefault
   if pValue is not an integer then
      return pDefault
   end if
   return max(pLow, min(pHigh, pValue))
end btWithin

command btSaveNow
   put empty into sSaveTimer
   if sSong is not an array then
      exit btSaveNow
   end if
   put btSongText() into url ("file:" & btSavePath())
end btSaveNow

function btLoad
   local tText
   put url ("file:" & btSavePath()) into tText
   if tText is empty then
      return false
   end if
   return btReadSong(tText)
end btLoad

----------------------------------------------------------------------
-- The page's sound
----------------------------------------------------------------------

-- Makes the audio core if need be; true when the page can play.
function btReady
   local tResult
   if the platform is not "HTML5" then
      return false
   end if
   if sAudio is "ok" then
      return true
   end if
   try
      do the cAudioCore of me as "JavaScript"
      put the result into tResult
   catch tError
      put "none" into tResult
   end try
   put tResult into sAudio
   return tResult is "ok"
end btReady

-- The pattern shown, as the audio core takes it (beyondBeats.set).
function btSongJson
   local tP, tSteps, tJson, n
   put sSong["cur"] into tP
   put sSong["pat"][tP]["steps"] into tSteps
   put "{" & quote & "bpm" & quote & ":" & sSong["bpm"] & "," & quote & "swing" & quote & ":" & sSong["swing"] & \
         "," & quote & "steps" & quote & ":" & tSteps & "," & quote & "ch" & quote & ":[" into tJson
   repeat with n = 1 to sSong["chans"]
      if n > 1 then
         put "," after tJson
      end if
      put "[" & sSong["ch"][n]["sound"] - 1 & "," & sSong["ch"][n]["vol"] & "," & sSong["ch"][n]["pan"] & "," & \
            btBit(sSong["ch"][n]["mute"]) & "," & btBit(sSong["ch"][n]["solo"]) & "]" after tJson
   end repeat
   put "]," & quote & "rows" & quote & ":[" after tJson
   repeat with n = 1 to sSong["chans"]
      if n > 1 then
         put "," after tJson
      end if
      put quote & char 1 to tSteps of sSong["pat"][tP]["rows"][n] & quote after tJson
   end repeat
   put "]}" after tJson
   return tJson
end btSongJson

function btBit pFlag
   if pFlag is true then
      return 1
   end if
   return 0
end btBit

command btSend
   if sSong is not an array or not btReady() then
      exit btSend
   end if
   do "beyondBeats.set(" & btSongJson() & ")" as "JavaScript"
end btSend

command btHit pRow, pVelocity
   if btReady() then
      do "beyondBeats.hit(" & pRow - 1 & "," & pVelocity & ")" as "JavaScript"
   end if
end btHit

command btPlayStop
   if sPlaying then
      btStop
   else
      btPlay
   end if
end btPlayStop

command btPlay
   local tState
   put true into sPlaying
   put 0 into sStep
   set the label of button "Play" to "Stop"
   if btReady() then
      btSend
      do "beyondBeats.start()" as "JavaScript"
      do "beyondBeats.state()" as "JavaScript"
      put the result into tState
      if tState is "running" then
         btStatus "Playing. Change pads, sounds and levels as it plays: you hear it at once."
      else
         btStatus "Click anywhere in the page to let it make sound."
      end if
   else
      put the milliseconds into sFallbackAt
      btStatus "Open this stack in a browser to hear it: the sound is made by the page. The playhead runs anyway."
   end if
   btFollow
end btPlay

command btStop
   put false into sPlaying
   if sTimer is not empty then
      cancel sTimer
   end if
   put empty into sTimer
   if sAudio is "ok" then
      do "beyondBeats.stop()" as "JavaScript"
   end if
   if there is a button "Play" then
      set the label of button "Play" to "Play"
      btShowStep 0
   end if
end btStop

-- Many times a second: which step is the page playing? The playhead
-- goes there.
on btFollow
   local tStep, tSteps
   set the defaultStack to the short name of me
   put empty into sTimer
   if not sPlaying then
      exit btFollow
   end if
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   if sAudio is "ok" then
      do "beyondBeats.now()" as "JavaScript"
      put the result + 1 into tStep
   else
      put (round((the milliseconds - sFallbackAt) / (15000 / sSong["bpm"])) mod tSteps) + 1 into tStep
   end if
   if tStep is not sStep and tStep >= 1 then
      btShowStep tStep
   end if
   send "btFollow" to me in 16 milliseconds
   put the result into sTimer
end btFollow

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------

command btStatus pText
   if there is a field "Status" then
      set the text of field "Status" to pText
   end if
end btStatus

command btDrawAll
   lock screen
   btDrawTop
   btDrawPatterns
   btDrawRows
   unlock screen
end btDrawAll

command btDrawTop
   local tSteps, tLeft, tWidth
   set the text of field "Tempo" to sSong["bpm"]
   set the text of field "Swing Value" to sSong["swing"] & "%"
   put the left of graphic "Swing Track" into tLeft
   put the width of graphic "Swing Track" into tWidth
   set the width of graphic "Swing Fill" to max(1, round(tWidth * sSong["swing"] / 100))
   set the left of graphic "Swing Fill" to tLeft
   set the loc of graphic "Swing Knob" to tLeft + round(tWidth * sSong["swing"] / 100), \
         item 2 of the loc of graphic "Swing Track"
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   btLight "Steps 16", tSteps is 16
   btLight "Steps 32", tSteps is 32
end btDrawTop

-- a button of a pair, on or off
command btLight pButton, pOn
   if pOn then
      set the backgroundColor of button pButton to kAmber
      set the textColor of button pButton to kNight
   else
      set the backgroundColor of button pButton to kCell
      set the textColor of button pButton to kMuted
   end if
end btLight

command btDrawPatterns
   local tText, p
   repeat with p = 1 to sSong["pats"]
      put sSong["pat"][p]["name"] & return after tText
   end repeat
   delete the last char of tText
   set the text of field "Patterns" to tText
   set the hilitedLine of field "Patterns" to sSong["cur"]
end btDrawPatterns

-- Every channel row: those the song has shown, the rest hidden; the
-- step dots and the Add Channel button under the last row.
command btDrawRows
   local n, s, tSteps, tShow
   lock screen
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   repeat with s = 1 to kMaxSteps
      set the visible of graphic ("dot" && s) to s <= tSteps
      if s <= tSteps then
         set the rect of graphic ("dot" && s) to btPadLeft(s, tSteps), kRowTop - 12, btPadRight(s, tSteps), kRowTop - 8
         if s mod 4 is 1 then
            set the backgroundColor of graphic ("dot" && s) to kMuted
         else
            set the backgroundColor of graphic ("dot" && s) to kCellBeat
         end if
      end if
   end repeat
   repeat with n = 1 to kMaxChannels
      put n <= sSong["chans"] into tShow
      set the visible of graphic ("swatch" && n) to tShow
      set the visible of button ("chan" && n) to tShow
      set the visible of button ("mute" && n) to tShow
      set the visible of button ("solo" && n) to tShow
      set the visible of graphic ("vol" && n) to tShow
      set the visible of graphic ("volfill" && n) to tShow
      set the visible of graphic ("pan" && n) to tShow
      set the visible of graphic ("panfill" && n) to tShow
      repeat with s = 1 to kMaxSteps
         set the visible of graphic ("pad" && n & comma & s) to tShow and s <= tSteps
         if tShow and s <= tSteps then
            set the rect of graphic ("pad" && n & comma & s) to btPadLeft(s, tSteps), btRowY(n), \
                  btPadRight(s, tSteps), btRowY(n) + kPadH
         end if
      end repeat
      if tShow then
         btDrawChannel n
      end if
   end repeat
   set the top of button "Add Channel" to btRowY(sSong["chans"] + 1)
   set the visible of button "Add Channel" to sSong["chans"] < kMaxChannels
   set the height of graphic "Head" to sSong["chans"] * kRowH - (kRowH - kPadH) + 8
   set the top of graphic "Head" to kRowTop - 4
   unlock screen
end btDrawRows

function btRowY pRow
   return kRowTop + (pRow - 1) * kRowH
end btRowY

function btPadLeft pStep, pSteps
   return kGridLeft + round((pStep - 1) * kGridWidth / pSteps)
end btPadLeft

function btPadRight pStep, pSteps
   return kGridLeft + round(pStep * kGridWidth / pSteps) - 3
end btPadRight

-- One channel: its name, mute and solo, its levels and its pads.
command btDrawChannel pRow
   local tColor, tAudible, tLeft, tWidth, tMid, s, tSteps
   lock screen
   put item pRow of kColors into tColor
   put btAudible(pRow) into tAudible
   set the backgroundColor of graphic ("swatch" && pRow) to tColor
   set the label of button ("chan" && pRow) to item sSong["ch"][pRow]["sound"] of kKit
   if tAudible then
      set the textColor of button ("chan" && pRow) to kInk
   else
      set the textColor of button ("chan" && pRow) to kDim
   end if
   btLightSmall "mute" && pRow, sSong["ch"][pRow]["mute"], kEmber
   btLightSmall "solo" && pRow, sSong["ch"][pRow]["solo"], kAmber
   -- the volume fills from the left
   put the left of graphic ("vol" && pRow) into tLeft
   put the width of graphic ("vol" && pRow) into tWidth
   set the rect of graphic ("volfill" && pRow) to tLeft, the top of graphic ("vol" && pRow), \
         tLeft + max(2, round(tWidth * sSong["ch"][pRow]["vol"] / 100)), the bottom of graphic ("vol" && pRow)
   set the backgroundColor of graphic ("volfill" && pRow) to tColor
   -- the pan fills from the middle, to one side
   put the left of graphic ("pan" && pRow) into tLeft
   put the width of graphic ("pan" && pRow) into tWidth
   put tLeft + round(tWidth / 2) into tMid
   if sSong["ch"][pRow]["pan"] < 0 then
      set the rect of graphic ("panfill" && pRow) to tMid + round(tWidth / 2 * sSong["ch"][pRow]["pan"] / 100), \
            the top of graphic ("pan" && pRow), tMid + 1, the bottom of graphic ("pan" && pRow)
   else
      set the rect of graphic ("panfill" && pRow) to tMid - 1, the top of graphic ("pan" && pRow), \
            tMid + max(1, round(tWidth / 2 * sSong["ch"][pRow]["pan"] / 100)), the bottom of graphic ("pan" && pRow)
   end if
   set the backgroundColor of graphic ("panfill" && pRow) to tColor
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   repeat with s = 1 to tSteps
      btDrawPad pRow, s, tColor, tAudible
   end repeat
   unlock screen
end btDrawChannel

command btLightSmall pButton, pOn, pColor
   if pOn then
      set the backgroundColor of button pButton to pColor
      set the textColor of button pButton to kNight
   else
      set the backgroundColor of button pButton to kCell
      set the textColor of button pButton to kMuted
   end if
end btLightSmall

-- A pad: off (a beat's first step a little lighter), or on in its
-- channel's colour, fainter the softer it is; grey when the channel is
-- not heard.
command btDrawPad pRow, pStep, pColor, pAudible
   local tLevel, tPad
   put "pad" && pRow & comma & pStep into tPad
   put btStep(pRow, pStep) into tLevel
   if pColor is empty then
      put item pRow of kColors into pColor
      put btAudible(pRow) into pAudible
   end if
   if tLevel > 0 then
      if pAudible then
         set the backgroundColor of graphic tPad to pColor
      else
         set the backgroundColor of graphic tPad to kDim
      end if
      set the blendLevel of graphic tPad to (9 - tLevel) * 8
   else
      if pStep mod 4 is 1 then
         set the backgroundColor of graphic tPad to kCellBeat
      else
         set the backgroundColor of graphic tPad to kCell
      end if
      set the blendLevel of graphic tPad to 0
   end if
end btDrawPad

command btShowStep pStep
   local tSteps
   lock screen
   put pStep into sStep
   if pStep >= 1 then
      put sSong["pat"][sSong["cur"]]["steps"] into tSteps
      set the rect of graphic "Head" to btPadLeft(pStep, tSteps) - 2, the top of graphic "Head", \
            btPadRight(pStep, tSteps) + 2, the bottom of graphic "Head"
      set the visible of graphic "Head" to true
   else
      set the visible of graphic "Head" to false
   end if
   unlock screen
end btShowStep

-- The sound picker: the kit, over the rack, for one channel.
command btOpenPicker pRow
   local tTop
   put pRow into sPicker
   set the text of field "Picker Title" to "Channel" && pRow & ": choose a sound"
   put btRowY(pRow) + kRowH into tTop
   if tTop + the height of group "Picker" > 556 then
      put btRowY(pRow) - the height of group "Picker" - 4 into tTop
   end if
   set the topLeft of group "Picker" to 204, max(64, tTop)
   set the visible of group "Picker" to true
end btOpenPicker

command btClosePicker
   put empty into sPicker
   set the visible of group "Picker" to false
end btClosePicker

----------------------------------------------------------------------
-- Layout: every control's place (the builder calls it once)
----------------------------------------------------------------------

command btLayout
   local n, s, tY, i, tX
   lock screen
   set the rect of graphic "Bar" to 0, 0, 960, 60
   set the rect of field "Logo" to 14, 8, 186, 52
   set the rect of button "Play" to 196, 12, 282, 48
   set the rect of field "Tempo Label" to 296, 21, 346, 43
   set the rect of button "Tempo Down" to 348, 17, 374, 43
   set the rect of field "Tempo" to 376, 15, 424, 45
   set the rect of button "Tempo Up" to 426, 17, 452, 43
   set the rect of field "Swing Label" to 470, 21, 522, 43
   set the rect of graphic "Swing Track" to 526, 27, 626, 33
   set the rect of graphic "Swing Fill" to 526, 27, 527, 33
   set the rect of graphic "Swing Knob" to 0, 0, 16, 16
   set the rect of field "Swing Value" to 634, 21, 680, 43
   set the rect of field "Steps Label" to 690, 21, 740, 43
   set the rect of button "Steps 16" to 744, 17, 784, 43
   set the rect of button "Steps 32" to 788, 17, 828, 43
   set the rect of button "New" to 846, 15, 896, 45
   set the rect of button "Demo" to 900, 15, 950, 45

   set the rect of graphic "Side" to 10, 68, 182, 560
   set the rect of field "Patterns Label" to 20, 74, 172, 96
   set the rect of field "Patterns" to 18, 100, 174, 466
   set the rect of button "Pattern New" to 18, 474, 94, 502
   set the rect of button "Pattern Clone" to 98, 474, 174, 502
   set the rect of button "Pattern Clear" to 18, 508, 94, 536
   set the rect of button "Pattern Delete" to 98, 508, 174, 536

   set the rect of graphic "Rack" to 192, 68, 952, 560
   set the rect of field "Rack Label" to 204, 74, 360, 96
   set the rect of field "Vol Label" to 374, 74, 436, 96
   set the rect of field "Pan Label" to 444, 74, 492, 96
   repeat with n = 1 to kMaxChannels
      put btRowY(n) into tY
      set the rect of graphic ("swatch" && n) to 202, tY + 2, 208, tY + kPadH - 2
      set the rect of button ("chan" && n) to 212, tY, 312, tY + kPadH
      set the rect of button ("mute" && n) to 316, tY + 2, 340, tY + kPadH - 2
      set the rect of button ("solo" && n) to 344, tY + 2, 368, tY + kPadH - 2
      set the rect of graphic ("vol" && n) to 376, tY + 10, 436, tY + kPadH - 10
      set the rect of graphic ("volfill" && n) to 376, tY + 10, 378, tY + kPadH - 10
      set the rect of graphic ("pan" && n) to 446, tY + 10, 490, tY + kPadH - 10
      set the rect of graphic ("panfill" && n) to 467, tY + 10, 469, tY + kPadH - 10
      repeat with s = 1 to kMaxSteps
         set the rect of graphic ("pad" && n & comma & s) to btPadLeft(s, 16), tY, btPadRight(s, 16), tY + kPadH
      end repeat
   end repeat
   set the rect of button "Add Channel" to 212, kRowTop, 368, kRowTop + 26
   set the rect of graphic "Head" to kGridLeft - 2, kRowTop - 4, kGridLeft + 26, kRowTop + 100
   set the rect of field "Status" to 14, 568, 946, 594

   -- the picker: a title, the kit in four columns, and Remove
   set the rect of graphic "Picker Back" to 0, 0, 424, 214
   set the rect of field "Picker Title" to 12, 8, 412, 30
   repeat with i = 1 to kKitSize
      put 12 + ((i - 1) mod 4) * 102 into tX
      put 36 + ((i - 1) div 4) * 34 into tY
      set the rect of button ("pick" && i) to tX, tY, tX + 96, tY + 28
   end repeat
   set the rect of button "Pick Remove" to 12, 176, 210, 204
   set the visible of group "Picker" to false
   unlock screen
end btLayout

----------------------------------------------------------------------
-- For the tests
----------------------------------------------------------------------

-- The song in a file of the test's own, saved at once after every change.
-- It opens as preOpenCard opens it: the song in that file, or the demo.
command btTestBegin pFile
   put true into sTest
   put pFile into sSaveFile
   put false into sPlaying
   put 0 into sStep
   put empty into sSong
   btEndDrag
   btClosePicker
   if not btLoad() then
      btDemoSong
   end if
   btDrawAll
end btTestBegin

command btTestEnd
   btStop
   put false into sTest
   put empty into sSaveFile
   put empty into sSong
end btTestEnd

-- How things are: "bpm", "swing", "cur", "chans", "pats", "steps",
-- "playing", "picker", "text" (the file's text), "json" (what the
-- page is told), "row n", "sound n", "vol n", "pan n", "mute n",
-- "solo n", "audible n", "name p".
function btState pWhat
   local tN
   put word 2 of pWhat into tN
   switch word 1 of pWhat
      case "bpm"
      case "swing"
      case "cur"
      case "chans"
      case "pats"
         return sSong[word 1 of pWhat]
      case "steps"
         return sSong["pat"][sSong["cur"]]["steps"]
      case "playing"
         return sPlaying
      case "picker"
         return sPicker
      case "text"
         return btSongText()
      case "json"
         return btSongJson()
      case "row"
         return sSong["pat"][sSong["cur"]]["rows"][tN]
      case "sound"
      case "vol"
      case "pan"
      case "mute"
      case "solo"
         return sSong["ch"][tN][word 1 of pWhat]
      case "audible"
         return btAudible(tN)
      case "name"
         return sSong["pat"][tN]["name"]
   end switch
   return empty
end btState

-- Loads a song from its text, as opening the stack does from its file.
function btTestRead pText
   local tOk
   put btReadSong(pText) into tOk
   if tOk then
      btDrawAll
   end if
   return tOk
end btTestRead
