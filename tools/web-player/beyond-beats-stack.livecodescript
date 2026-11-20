script "Beyond Beats"
-- Beyond Beats: a beat studio for a browser, made with OXT-Beyond.
-- Built by tools/web-player/beyond-beats.livecodescript in OXT-Beyond's
-- repository, from this script and the audio core beside it
-- (beyond-beats/audio-core.js). Its kit is made by that core, sample by
-- sample, and its synths are played by the browser's oscillators, so
-- there are no sound files but the ones a user brings.
--
-- What it has:
--   Channels   up to twelve, each a sound (a drum of the kit, a synth, or
--              a sample of the user's own) with a step row in each
--              pattern: up to 32 steps, each off or on at a velocity 1..9
--   Piano roll a channel's notes in a pattern, from C1 to B6, of any length
--   Playlist   eight tracks of 128 bars: where each pattern plays in the
--              song; Song mode plays it, Pattern mode loops the pattern
--              chosen
--   Mixer      each channel's volume, pan, mute, solo, low-pass filter,
--              reverb and delay sends and tuning, with meters; the
--              master's volume, the reverb's room and the delay's time and
--              feedback
--   Files      the song is kept in the browser and is there on the next
--              visit; Save and Open take it to and from a file (with the
--              samples in it), Export makes a WAV of it; Undo and Redo
--
-- How it is made:
--   the song is here, in sSong (below); the screen only shows it. Every
--     change goes through a bt... command, which changes sSong, draws what
--     changed, tells the audio core (btSend), saves and remembers it for
--     Undo (btChanged)
--   the sound is the page's: the audio core (the custom property
--     cAudioCore, run once with do ... as "JavaScript") makes the kit,
--     plays the synths and the samples, mixes the channels and books every
--     step on the browser's audio clock a moment ahead, so the beat stays
--     steady while the engine draws. About sixty times a second the
--     script asks it which step is sounding and how loud each channel is
--     (beyondBeats.poll), to move the playheads and the meters
--   four views over one panel, each a group made by the builder and shown
--     one at a time; only the one shown is drawn. Graphics and fields, not
--     pictures: a fixed set of controls, shown and hidden, never created
--     while it plays. btLayout places them all
--   outside a browser it opens and edits as well, saves to a file of its
--     own, and plays without sound: the playheads run on the engine's
--     clock
--
-- For the tests (tests/lcs/webplayer/beyond-beats.livecodescript):
-- btTestBegin keeps the song in a file of the test's own and saves at
-- once, and btState says how things are.

constant kKit = "Kick,Boom,Snare,Rim,Clap,Closed hat,Open hat,Crash,Ride,Low tom,High tom,Shaker,Cowbell,Clave,Snap,Bass"
constant kSynths = "Saw lead,Square bass,Soft pad,Pluck,Keys"
constant kColors = "#FF7A3D,#FFB52E,#FFE066,#7CF29A,#3DDBB8,#5CD6FF,#6C8CFF,#B48CFF,#FF6FB5,#FF5D73,#F2A65A,#9ED0FF"
constant kPatColors = "#FF7A3D,#FFB52E,#7CF29A,#5CD6FF,#B48CFF,#FF6FB5,#FFE066,#3DDBB8,#6C8CFF,#FF5D73,#F2A65A,#9ED0FF,#C9F27C,#FF9EDB,#8CE0FF,#D4B8FF"
constant kNoteNames = "C,C#,D,D#,E,F,F#,G,G#,A,A#,B"
-- the sounds, numbered from 1: the kit, then the synths, then the
-- user's sample slots
constant kKitSize = 16
constant kFirstSynth = 17
constant kFirstUser = 22
constant kUserSlots = 8
constant kSounds = 29
constant kMaxChannels = 12
constant kMaxPatterns = 16
constant kMaxSteps = 32
constant kMaxNotes = 64
constant kTracks = 8
constant kSongBars = 128
constant kViewBars = 32
constant kLowNote = 24
constant kHighNote = 95
constant kKeys = 24
constant kMaxSample = 4194304
constant kUndoDepth = 60
constant kSaveName = "beyond-beats.txt"
constant kFormat = "beyond-beats 2"
constant kOldFormat = "beyond-beats 1"

-- colours: the night sky and its fire
constant kNight = "#0B0D1F"
constant kPanel = "#151839"
constant kCell = "#1F2249"
constant kCellBeat = "#2A2E5E"
constant kLaneDark = "#181A3C"
constant kInk = "#F4EEFF"
constant kMuted = "#9A96C0"
constant kDim = "#4A4870"
constant kAmber = "#FFB52E"
constant kEmber = "#FF7A3D"
constant kKeyWhite = "#D9D4F2"
constant kMeter = "#7CF29A"

-- the rack's geometry: its rows, and the grid of pads in each
constant kRowTop = 122
constant kRowH = 34
constant kPadH = 28
constant kGridLeft = 500
constant kGridWidth = 444
-- the playlist's: the ruler, the tracks and their bars
constant kSongLeft = 266
constant kSongWidth = 678
constant kRulerTop = 104
constant kTrackTop = 128
constant kTrackH = 50
constant kCellH = 46
-- the piano roll's: the keys (the highest at the top) and the grid
constant kPianoLeft = 250
constant kPianoWidth = 694
constant kKeyTop = 128
constant kKeyH = 17
-- the mixer's: a strip a channel, the master's at the right
constant kStripLeft = 248
constant kStripW = 52
constant kFaderTop = 240
constant kFaderBottom = 420

-- sSong: the whole song
--   ["bpm"] 40..240, ["swing"] 0..100, ["cur"] the pattern shown (and
--     played in Pattern mode), ["mode"] "pattern" or "song", ["from"] the
--     bar Song mode starts at
--   ["master"]["vol"] 0..100, ["size"] the reverb, 0 a room or 1 a hall,
--     ["dly"] the delay's time, 2..4 steps, ["fb"] its feedback, 0..90
--   ["chans"] how many channels; ["ch"][n]["sound"] 1..29, ["vol"]
--     0..100, ["pan"] -100..100, ["mute"] and ["solo"] true or false,
--     ["cut"] the filter, 0..100 (100 open), ["rev"] and ["dly"] the
--     sends, 0..100, ["tune"] -24..24 semitones
--   ["pats"] how many patterns; ["pat"][p]["name"], ["steps"] 16 or 32,
--     ["rows"][n] 32 digits, one a step: 0 off, 1..9 its velocity (the
--     steps past ["steps"] are kept, so going back to 32 loses nothing),
--     ["notes"][n] a line a note: start step, length in steps, MIDI pitch,
--     velocity
--   ["track"][t][b] the pattern that starts at bar b of track t
--   ["user"][slot]["name"] the name of a sample of the user's own, and
--     ["file"] its file's key: the file is kept beside the song's
--     (btSampleFile), and a sample loaded over another gets a new key, so
--     that a step of Undo brings back the sound with its name
local sSong
local sView, sPianoCh, sPianoLow, sNoteLen, sSongView
local sPlaying, sStep, sTimer, sFallbackAt, sAudio
local sDrag, sDragFrom, sPaint, sPaintRow, sPaintLast
local sCellPaint, sCellTrack, sCellLast
local sNote, sNoteMode, sNoteFrom, sNoteMoved
local sPicker, sMenu, sSwallowUp, sNewArmed
local sSaveTimer, sSaveFile, sTest
local sUndo, sUndoAt, sUndoTop, sUndoHeld
local sExportTimer, sExportName

on preOpenCard
   if sSong is not an array then
      btReset
      if not btLoad() then
         btDemoSong true
      end if
      btUndoReset
      btShowView "rack"
      btSend
   end if
end preOpenCard

on closeCard
   btStop
end closeCard

-- How things are when the stack opens, before a song is in it.
command btReset
   put 0 into sStep
   put false into sPlaying
   put "rack" into sView
   put 1 into sPianoCh
   put 48 into sPianoLow
   put 2 into sNoteLen
   put 1 into sSongView
   put false into sNewArmed
   put false into sSwallowUp
   put false into sUndoHeld
   btEndDrag
   if there is a group "Picker" then
      btClosePicker
      btCloseMenu
   end if
end btReset

----------------------------------------------------------------------
-- The mouse and the keys
----------------------------------------------------------------------

on mouseDown pButton
   local tLong
   put the long name of the target into tLong
   if sMenu is not empty then
      -- a click away from the File menu only closes it
      if not btInGroup(tLong, "Files") and the short name of the target is not "File" then
         btCloseMenu
         put true into sSwallowUp
         exit mouseDown
      end if
      pass mouseDown
   end if
   if sPicker is not empty then
      -- a click away from the picker only closes it
      if not btInGroup(tLong, "Picker") then
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

-- Whether a control (by its long name) is in the group named pGroup.
function btInGroup pLongName, pGroup
   return pLongName contains ("group" && quote & pGroup & quote)
end btInGroup

-- A press at a point of the card, on the control named pName: a pad, a
-- bar of the playlist or a note (by where it is), a key, a slider or the
-- tempo. pAlt: a right-click or a shift-click. False when it is none of
-- those.
function btPointerDown pName, pX, pY, pAlt
   local tKind
   switch sView
      case "rack"
         if btRackDown(pX, pY, pAlt) then
            return true
         end if
         break
      case "piano"
         if pName begins with "key " and word 2 of pName is an integer then
            btHit sPianoCh, 7, sPianoLow + word 2 of pName - 1
            return true
         end if
         if btPianoDown(pX, pY, pAlt) then
            return true
         end if
         break
      case "song"
         if btSongDown(pX, pY, pAlt) then
            return true
         end if
         break
   end switch
   put btSliderOf(pName) into tKind
   switch word 1 of tKind
      case empty
         return false
      case "tempo"
         put "tempo" into sDrag
         put pY & comma & sSong["bpm"] into sDragFrom
         break
      case "tune"
         if not btIsChannel(word 2 of tKind) then
            return false
         end if
         put tKind into sDrag
         put pY & comma & sSong["ch"][word 2 of tKind]["tune"] into sDragFrom
         break
      default
         put tKind into sDrag
         btDragTo pX, pY
   end switch
   return true
end btPointerDown

-- The slider a control is part of ("vol 3", "fader 0", "swing", ...),
-- or empty: a slider's fill and a fader's cap are the slider too.
function btSliderOf pName
   local tWord, tN
   put word 1 of pName into tWord
   put word 2 of pName into tN
   if pName is among the items of "Swing Track,Swing Fill,Swing Knob" then
      return "swing"
   end if
   if pName is "Tempo" then
      return "tempo"
   end if
   if tWord ends with "fill" then
      delete char -4 to -1 of tWord
   else if tWord ends with "cap" then
      delete char -3 to -1 of tWord
   end if
   if tWord is "fb" and tN is empty then
      return "fb"
   end if
   if tN is not an integer then
      return empty
   end if
   if tWord is among the items of "vol,pan,cut,rev,dly,mxpan,fader" then
      return tWord && tN
   end if
   if tWord is "mxtune" then
      return "tune" && tN
   end if
   return empty
end btSliderOf

-- A press on the rack: a pad (by where it is, so that a pad under the
-- playhead is clicked as well as any other) turns on or off, and a drag
-- along its row paints the same; with pAlt, its velocity goes round.
function btRackDown pX, pY, pAlt
   local tRow, tStep
   put btRowAt(pY) into tRow
   put btStepAt(pX) into tStep
   if tRow < 1 or tStep < 1 then
      return false
   end if
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
end btRackDown

on mouseMove pX, pY
   btPointerMove pX, pY
   pass mouseMove
end mouseMove

-- The mouse moved while pressed: a slider follows it, a drag along a row
-- of pads or a track of the playlist paints it, and a note is moved or
-- made longer.
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
   else if sCellPaint is not empty then
      btSongMove pX, pY
   else if sNote is not empty then
      btPianoMove pX, pY
   end if
end btPointerMove

on mouseRelease
   btEndDrag
   pass mouseRelease
end mouseRelease

on mouseUp pButton
   local tName, tLine
   put the short name of the target into tName
   if sSwallowUp then
      put false into sSwallowUp
      exit mouseUp
   end if
   if btDragging() then
      btEndDrag
      exit mouseUp
   end if
   if word 1 of the long id of the target is "button" then
      btPress tName
   else if tName begins with "swatch " then
      btChooseChannel word 2 of tName
   else if tName begins with "pswatch " then
      btSelectPattern word 2 of tName
   else if tName is "Patterns" then
      put the hilitedLine of field "Patterns" into tLine
      if tLine is an integer then
         btSelectPattern tLine
      end if
   else
      pass mouseUp
   end if
end mouseUp

on mouseDoubleUp pButton
   if the short name of the target is "Patterns" then
      btAskPatternName
   else
      pass mouseDoubleUp
   end if
end mouseDoubleUp

on keyDown pKey
   if pKey is space and the selectedField is empty then
      btPlayStop
   else
      pass keyDown
   end if
end keyDown

-- Control-Z (Command-Z on a Mac) undoes, with Shift (or Control-Y) redoes.
on commandKeyDown pKey
   if pKey is "z" then
      if the shiftKey is down then
         btRedo
      else
         btUndo
      end if
   else if pKey is "y" then
      btRedo
   else
      pass commandKeyDown
   end if
end commandKeyDown

-- A button, by its name: what its mouseUp does (the tests press them
-- this way too).
command btPress pName
   local tWhich
   put word 2 of pName into tWhich
   if pName is not "New" and sNewArmed then
      put false into sNewArmed
      set the label of button "New" to "New empty song"
   end if
   switch
      case pName is "Play"
         btPlayStop
         break
      case pName is "Mode Pattern"
         btSetMode "pattern"
         break
      case pName is "Mode Song"
         btSetMode "song"
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
      case pName is "Undo"
         btUndo
         break
      case pName is "Redo"
         btRedo
         break
      case pName is "File"
         if sMenu is empty then
            btOpenMenu
         else
            btCloseMenu
         end if
         break
      case pName begins with "Tab "
         btShowView tolower(tWhich)
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
      case pName begins with "mxmute "
         btToggleMute tWhich
         break
      case pName begins with "solo "
      case pName begins with "mxsolo "
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
      case pName is "Pick Load"
         if sPicker is not empty then
            get sPicker
            btClosePicker
            btAskSample it, empty
         end if
         break
      case pName begins with "pick "
         if sPicker is not empty then
            get sPicker
            btClosePicker
            if tWhich >= kFirstUser and sSong["user"][tWhich - kFirstUser + 1]["name"] is empty then
               -- an empty slot: a sample of the user's own goes into it
               btAskSample it, tWhich - kFirstUser + 1
            else
               btSetSound it, tWhich
               btHit it, 7
            end if
         end if
         break
      case pName is "Piano Prev"
         btSetPianoChannel sPianoCh - 1
         break
      case pName is "Piano Next"
         btSetPianoChannel sPianoCh + 1
         break
      case pName is "Oct Down"
         btSetOctave sPianoLow - 12
         break
      case pName is "Oct Up"
         btSetOctave sPianoLow + 12
         break
      case pName is "Bars Back"
         btSetSongView sSongView - 16
         break
      case pName is "Bars On"
         btSetSongView sSongView + 16
         break
      case pName is "Reverb Room"
         btSetMaster "size", 0
         break
      case pName is "Reverb Hall"
         btSetMaster "size", 1
         break
      case pName begins with "Delay "
         btSetMaster "dly", tWhich
         break
      case pName is "File Save"
         btCloseMenu
         btAskSave
         break
      case pName is "File Open"
         btCloseMenu
         btAskOpen
         break
      case pName is "File Export"
         btCloseMenu
         btAskExport
         break
      case pName is "File Sample"
         btCloseMenu
         btAskSample empty, empty
         break
      case pName is "New"
         -- twice to be sure: the first press asks, the second clears
         if sNewArmed then
            put false into sNewArmed
            set the label of button "New" to "New empty song"
            btCloseMenu
            btNewSong
         else
            put true into sNewArmed
            set the label of button "New" to "Sure? Press again"
            btStatus "Press New again to start an empty song. Undo brings this one back."
         end if
         break
      case pName is "Demo"
         btCloseMenu
         btDemoSong
         break
   end switch
end btPress

-- the row (channel) and the step of the rack under a point of the card,
-- or 0
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

-- A slider dragged (or the tempo or a tuning, up and down), to the
-- mouse.
command btDragTo pX, pY
   local tKind, tN, tValue
   put word 1 of sDrag into tKind
   put word 2 of sDrag into tN
   switch tKind
      case "vol"
         btSetVolume tN, btAlong("vol" && tN, pX, 100)
         break
      case "pan"
      case "mxpan"
         btSetPan tN, btPanAlong(tKind && tN, pX)
         break
      case "cut"
      case "rev"
      case "dly"
         btSetChannel tN, tKind, btAlong(tKind && tN, pX, 100)
         break
      case "fader"
         put round(100 * (the bottom of graphic ("fader" && tN) - pY) / the height of graphic ("fader" && tN)) into tValue
         if tN is 0 then
            btSetMaster "vol", tValue
         else
            btSetVolume tN, tValue
         end if
         break
      case "fb"
         btSetMaster "fb", btAlong("fb", pX, 90)
         break
      case "swing"
         btSetSwing btAlong("Swing Track", pX, 100)
         break
      case "tempo"
         btSetTempo (item 2 of sDragFrom) + round((item 1 of sDragFrom - pY) / 3)
         break
      case "tune"
         btSetChannel tN, "tune", (item 2 of sDragFrom) + round((item 1 of sDragFrom - pY) / 8)
         break
   end switch
end btDragTo

-- How far along a slider a point is, from 0 to pTop.
function btAlong pGraphic, pX, pTop
   return round(pTop * (pX - the left of graphic pGraphic) / the width of graphic pGraphic)
end btAlong

-- A pan slider: -100 at its left, 100 at its right; it snaps to the
-- middle near it.
function btPanAlong pGraphic, pX
   local tValue
   put round(200 * (pX - the left of graphic pGraphic) / the width of graphic pGraphic) - 100 into tValue
   if abs(tValue) < 8 then
      return 0
   end if
   return tValue
end btPanAlong

function btDragging
   return sDrag is not empty or sPaint is not empty or sCellPaint is not empty or sNote is not empty
end btDragging

-- The mouse let go: what it dragged is one change, for Undo. A note
-- pressed and let go without moving is taken away.
command btEndDrag
   if sNote is not empty then
      if sNoteMode is "move" and not sNoteMoved then
         btDeleteNote sNote
      else if sNoteMode is "resize" then
         put item 2 of btNoteData(sNote) into sNoteLen
      end if
   end if
   put empty into sDrag
   put empty into sPaint
   put empty into sPaintRow
   put empty into sPaintLast
   put empty into sCellPaint
   put empty into sCellTrack
   put empty into sCellLast
   put empty into sNote
   put empty into sNoteMode
   put empty into sNoteFrom
   put false into sNoteMoved
   if sUndoHeld then
      put false into sUndoHeld
      btRemember
   end if
end btEndDrag

----------------------------------------------------------------------
-- The song: every change goes through here
----------------------------------------------------------------------

function btIsChannel pRow
   return pRow is an integer and pRow >= 1 and pRow <= sSong["chans"]
end btIsChannel

function btStep pRow, pStep
   return char pStep of sSong["pat"][sSong["cur"]]["rows"][pRow]
end btStep

command btSetStep pRow, pStep, pLevel
   local tP
   put sSong["cur"] into tP
   if not btIsChannel(pRow) or pStep < 1 or pStep > kMaxSteps then
      exit btSetStep
   end if
   put max(0, min(9, round(pLevel))) into char pStep of sSong["pat"][tP]["rows"][pRow]
   if sView is "rack" then
      btDrawPad pRow, pStep
   end if
   btChanged
end btSetStep

-- A step that is on, a shift-click or a right-click: normal (7), loud
-- (9), soft (4), round again. One that is off comes on loud.
command btCycleVelocity pRow, pStep
   btSetStep pRow, pStep, btNextVelocity(btStep(pRow, pStep))
   if not sPlaying then
      btHit pRow, btStep(pRow, pStep)
   end if
end btCycleVelocity

function btNextVelocity pLevel
   switch pLevel
      case 0
      case 7
         return 9
      case 9
         return 4
      default
         return 7
   end switch
end btNextVelocity

command btSetTempo pBpm
   if pBpm is not a number then
      exit btSetTempo
   end if
   put max(40, min(240, round(pBpm))) into sSong["bpm"]
   btDrawTop
   if sView is "song" then
      btDrawSongLength
   end if
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
   if not btIsChannel(pRow) or pVolume is not a number then
      exit btSetVolume
   end if
   put max(0, min(100, round(pVolume))) into sSong["ch"][pRow]["vol"]
   btDrawChannelViews pRow
   btChanged
end btSetVolume

command btSetPan pRow, pPan
   if not btIsChannel(pRow) or pPan is not a number then
      exit btSetPan
   end if
   put max(-100, min(100, round(pPan))) into sSong["ch"][pRow]["pan"]
   btDrawChannelViews pRow
   btChanged
end btSetPan

-- The mixer's settings of a channel: "cut" its filter (100 open, 0 dull),
-- "rev" and "dly" its sends to the reverb and the delay (0..100), "tune"
-- its tuning in semitones (-24..24).
command btSetChannel pRow, pKey, pValue
   if not btIsChannel(pRow) or pValue is not a number then
      exit btSetChannel
   end if
   switch pKey
      case "cut"
      case "rev"
      case "dly"
         put max(0, min(100, round(pValue))) into sSong["ch"][pRow][pKey]
         break
      case "tune"
         put max(-24, min(24, round(pValue))) into sSong["ch"][pRow]["tune"]
         break
      default
         exit btSetChannel
   end switch
   btDrawChannelViews pRow
   btChanged
end btSetChannel

-- The master's settings: "vol" 0..100, "size" the reverb (0 a room, 1 a
-- hall), "dly" the delay's time (2, 3 or 4 steps: an eighth, a dotted
-- eighth, a quarter), "fb" its feedback (0..90).
command btSetMaster pKey, pValue
   if pValue is not a number then
      exit btSetMaster
   end if
   switch pKey
      case "vol"
         put max(0, min(100, round(pValue))) into sSong["master"]["vol"]
         break
      case "size"
         put max(0, min(1, round(pValue))) into sSong["master"]["size"]
         break
      case "dly"
         put max(2, min(4, round(pValue))) into sSong["master"]["dly"]
         break
      case "fb"
         put max(0, min(90, round(pValue))) into sSong["master"]["fb"]
         break
      default
         exit btSetMaster
   end switch
   if sView is "mixer" then
      btDrawMaster
   end if
   btChanged
end btSetMaster

command btToggleMute pRow
   if not btIsChannel(pRow) then
      exit btToggleMute
   end if
   put not sSong["ch"][pRow]["mute"] into sSong["ch"][pRow]["mute"]
   btDrawView
   btChanged
end btToggleMute

command btToggleSolo pRow
   if not btIsChannel(pRow) then
      exit btToggleSolo
   end if
   put not sSong["ch"][pRow]["solo"] into sSong["ch"][pRow]["solo"]
   btDrawView
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
   if not btIsChannel(pRow) or pSound is not an integer or pSound < 1 or pSound > kSounds then
      exit btSetSound
   end if
   put pSound into sSong["ch"][pRow]["sound"]
   btDrawChannelViews pRow
   btChanged
end btSetSound

-- A sound's name: the kit's, a synth's, or the user's sample's.
function btSoundName pSound
   if pSound < kFirstSynth then
      return item pSound of kKit
   else if pSound < kFirstUser then
      return item pSound - kFirstSynth + 1 of kSynths
   end if
   if sSong["user"][pSound - kFirstUser + 1]["name"] is empty then
      return "Sample" && pSound - kFirstUser + 1
   end if
   return sSong["user"][pSound - kFirstUser + 1]["name"]
end btSoundName

-- The channel the piano roll edits (a click on a channel's colour in the
-- rack); it plays to say which.
command btChooseChannel pRow
   if not btIsChannel(pRow) then
      exit btChooseChannel
   end if
   put pRow into sPianoCh
   if sView is "rack" then
      btDrawChosen
   end if
   btHit pRow, 7
   btStatus "The piano roll plays" && btSoundName(sSong["ch"][pRow]["sound"]) && "(channel" && pRow & ")."
end btChooseChannel

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
      put empty into sSong["pat"][p]["notes"][n]
   end repeat
   btDrawAll
   btChanged
end btAddChannel

command btRemoveChannel pRow
   local n, p
   if not btIsChannel(pRow) then
      exit btRemoveChannel
   end if
   if sSong["chans"] <= 1 then
      btStatus "A song keeps at least one channel."
      exit btRemoveChannel
   end if
   repeat with n = pRow to sSong["chans"] - 1
      put sSong["ch"][n + 1] into sSong["ch"][n]
      repeat with p = 1 to sSong["pats"]
         put sSong["pat"][p]["rows"][n + 1] into sSong["pat"][p]["rows"][n]
         put sSong["pat"][p]["notes"][n + 1] into sSong["pat"][p]["notes"][n]
      end repeat
   end repeat
   delete variable sSong["ch"][sSong["chans"]]
   repeat with p = 1 to sSong["pats"]
      delete variable sSong["pat"][p]["rows"][sSong["chans"]]
      delete variable sSong["pat"][p]["notes"][sSong["chans"]]
   end repeat
   subtract 1 from sSong["chans"]
   if sPianoCh > pRow or sPianoCh > sSong["chans"] then
      put max(1, sPianoCh - 1) into sPianoCh
   end if
   btDrawAll
   btChanged
end btRemoveChannel

command btSelectPattern pPattern
   if pPattern is not an integer or pPattern < 1 or pPattern > sSong["pats"] then
      exit btSelectPattern
   end if
   put pPattern into sSong["cur"]
   btDrawAll
   btChanged true
end btSelectPattern

command btNewPattern
   if sSong["pats"] >= kMaxPatterns then
      btStatus "Sixteen patterns is the most a song has."
      exit btNewPattern
   end if
   add 1 to sSong["pats"]
   btEmptyPattern sSong["pats"], btPatternName()
   put sSong["pats"] into sSong["cur"]
   btDrawAll
   btChanged
end btNewPattern

-- A copy of the pattern shown, its notes too, after the last.
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
   put sSong["pats"] into sSong["cur"]
   btDrawAll
   btChanged
end btClonePattern

command btClearPattern
   local n
   repeat with n = 1 to sSong["chans"]
      put btEmptyRow() into sSong["pat"][sSong["cur"]]["rows"][n]
      put empty into sSong["pat"][sSong["cur"]]["notes"][n]
   end repeat
   btDrawAll
   btChanged
end btClearPattern

-- A pattern deleted: where it was in the song is empty, and the patterns
-- after it move up a number.
command btDeletePattern pPattern
   local p, t, b, tTrack
   if pPattern is not an integer or pPattern < 1 or pPattern > sSong["pats"] then
      exit btDeletePattern
   end if
   if sSong["pats"] <= 1 then
      btClearPattern
      exit btDeletePattern
   end if
   repeat with p = pPattern to sSong["pats"] - 1
      put sSong["pat"][p + 1] into sSong["pat"][p]
   end repeat
   delete variable sSong["pat"][sSong["pats"]]
   subtract 1 from sSong["pats"]
   repeat with t = 1 to kTracks
      put sSong["track"][t] into tTrack
      delete variable sSong["track"][t]
      repeat for each key b in tTrack
         if tTrack[b] < pPattern then
            put tTrack[b] into sSong["track"][t][b]
         else if tTrack[b] > pPattern then
            put tTrack[b] - 1 into sSong["track"][t][b]
         end if
      end repeat
   end repeat
   put min(pPattern, sSong["pats"]) into sSong["cur"]
   btDrawAll
   btChanged
end btDeletePattern

command btAskPatternName
   ask "Name this pattern:" with sSong["pat"][sSong["cur"]]["name"]
   if it is not empty then
      btRenamePattern sSong["cur"], it
   end if
end btAskPatternName

command btRenamePattern pPattern, pName
   if pPattern is not an integer or pPattern < 1 or pPattern > sSong["pats"] then
      exit btRenamePattern
   end if
   put btClean(pName) into sSong["pat"][pPattern]["name"]
   btDrawPatterns
   if sView is "song" then
      btDrawSong
   end if
   btChanged
end btRenamePattern

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
      put empty into sSong["pat"][pPattern]["notes"][n]
   end repeat
end btEmptyPattern

command btNewChannel pRow, pSound
   put pSound into sSong["ch"][pRow]["sound"]
   put 78 into sSong["ch"][pRow]["vol"]
   put 0 into sSong["ch"][pRow]["pan"]
   put false into sSong["ch"][pRow]["mute"]
   put false into sSong["ch"][pRow]["solo"]
   put 100 into sSong["ch"][pRow]["cut"]
   put 0 into sSong["ch"][pRow]["rev"]
   put 0 into sSong["ch"][pRow]["dly"]
   put 0 into sSong["ch"][pRow]["tune"]
end btNewChannel

-- A song with nothing in it but its settings.
function btBareSong
   local tSong
   put 120 into tSong["bpm"]
   put 0 into tSong["swing"]
   put 1 into tSong["cur"]
   put "pattern" into tSong["mode"]
   put 1 into tSong["from"]
   put 80 into tSong["master"]["vol"]
   put 0 into tSong["master"]["size"]
   put 3 into tSong["master"]["dly"]
   put 35 into tSong["master"]["fb"]
   put 0 into tSong["chans"]
   put 0 into tSong["pats"]
   return tSong
end btBareSong

-- An empty song: the eight channels a beat starts from, one pattern.
-- pQuiet: neither drawn nor saved (the demo goes on to fill it).
command btNewSong pQuiet
   local tSounds, n
   put "1,3,5,6,7,10,12,16" into tSounds
   put btBareSong() into sSong
   put the number of items of tSounds into sSong["chans"]
   repeat with n = 1 to sSong["chans"]
      btNewChannel n, item n of tSounds
   end repeat
   put 1 into sSong["pats"]
   btEmptyPattern 1, "Pattern 1"
   put 1 into sPianoCh
   put 1 into sSongView
   if pQuiet is not true then
      btDrawAll
      btChanged
      btStatus "An empty song. Click a pad to add a beat; Space plays and stops."
   end if
end btNewSong

-- The song it opens with the first time: four patterns, a synth bass and
-- keys, and an arrangement of eight bars in the playlist. pQuiet: not
-- drawn (the stack is opening, and draws once it is in).
command btDemoSong pQuiet
   local tKeys, tBass, n
   btNewSong true
   put 122 into sSong["bpm"]
   put 18 into sSong["swing"]
   btAddDemoChannel 18
   btAddDemoChannel 21
   put -18 into sSong["ch"][4]["pan"]
   put 22 into sSong["ch"][7]["pan"]
   put 70 into sSong["ch"][4]["vol"]
   put 62 into sSong["ch"][7]["vol"]
   put 25 into sSong["ch"][3]["rev"]
   put 15 into sSong["ch"][5]["dly"]
   put 70 into sSong["ch"][9]["vol"]
   put 72 into sSong["ch"][9]["cut"]
   put 60 into sSong["ch"][10]["vol"]
   put 35 into sSong["ch"][10]["rev"]
   put 20 into sSong["ch"][10]["dly"]
   put 4 into sSong["pats"]
   -- kick, snare, clap, closed hat, open hat, low tom, shaker, bass; the
   -- synths have notes, not steps
   btDemoPattern 1, "Groove", "9000900090009000,0000000000000000,0000900000009000,5070507050705070," & \
         "0000000000000000,0000000000000000,0000000000000000,0090000700900007"
   btDemoPattern 2, "Groove B", "9000900090009000,0000000000000300,0000900000009000,5070500050705000," & \
         "0090009000900090,0000000000000000,3060306030603060,9000009000900090"
   btDemoPattern 3, "Fill", "9000900090000000,0000900000909990,0000900000000000,5070507050700000," & \
         "0000000000000000,0000000090009000,3060306030600000,9000009000000000"
   btDemoPattern 4, "Chords", empty
   put 32 into sSong["pat"][4]["steps"]
   -- A minor, F, G: a square bass under the keys
   put "1,2,45,8;4,1,45,6;7,2,52,7;9,2,45,8;12,1,48,6;15,2,47,7;17,2,41,8;20,1,41,6;23,2,48,7;" & \
         "25,2,43,8;28,1,43,6;31,2,50,7" into tBass
   put "1,14,57,6;1,14,60,6;1,14,64,6;17,8,53,6;17,8,57,6;17,8,60,6;25,8,55,6;25,8,59,6;25,8,62,6" into tKeys
   replace ";" with return in tBass
   replace ";" with return in tKeys
   put tBass into sSong["pat"][4]["notes"][9]
   put tKeys into sSong["pat"][4]["notes"][10]
   -- the playlist: the drums on track 1, the chords (two bars each) on 2
   set the itemDelimiter to ":"
   repeat for each word n in "1:1 2:1 3:2 4:2 5:1 6:1 7:2 8:3"
      put item 2 of n into sSong["track"][1][item 1 of n]
   end repeat
   set the itemDelimiter to comma
   repeat for each item n in "1,3,5,7"
      put 4 into sSong["track"][2][n]
   end repeat
   put 1 into sSong["cur"]
   if pQuiet is not true then
      btDrawAll
      btChanged
   end if
   btStatus "A demo beat. Space plays and stops; click pads to change it as it plays. Song plays the playlist."
end btDemoSong

command btAddDemoChannel pSound
   add 1 to sSong["chans"]
   btNewChannel sSong["chans"], pSound
end btAddDemoChannel

-- One pattern of the demo: its rows (a comma list, one a channel, from
-- the first) and empty rows for the rest.
command btDemoPattern pPattern, pName, pRows
   local n
   btEmptyPattern pPattern, pName
   repeat with n = 1 to the number of items of pRows
      put item n of pRows into char 1 to 16 of sSong["pat"][pPattern]["rows"][n]
   end repeat
end btDemoPattern

----------------------------------------------------------------------
-- The playlist
----------------------------------------------------------------------

-- "pattern" loops the pattern chosen; "song" plays the playlist, from its
-- start bar. While it plays, it starts again in the new mode.
command btSetMode pMode
   if pMode is not "pattern" and pMode is not "song" then
      exit btSetMode
   end if
   if pMode is sSong["mode"] then
      exit btSetMode
   end if
   put pMode into sSong["mode"]
   btDrawTop
   btChanged
   if sPlaying then
      btStop
      btPlay
   end if
end btSetMode

-- The bar Song mode starts at (a click on the ruler).
command btSetFrom pBar
   if pBar is not an integer then
      exit btSetFrom
   end if
   put max(1, min(kSongBars, pBar)) into sSong["from"]
   if sView is "song" then
      btDrawStartMark
   end if
   btChanged
end btSetFrom

-- How many bars a pattern lasts: 1 for 16 steps, 2 for 32.
function btPatternBars pPattern
   return max(1, sSong["pat"][pPattern]["steps"] div 16)
end btPatternBars

-- What is at bar pBar of track pTrack: "start,pattern" for the block that
-- covers it (the bar it starts at, its pattern), or empty.
function btBlockAt pTrack, pBar
   local b
   repeat with b = pBar down to max(1, pBar - 1)
      if sSong["track"][pTrack][b] is not empty and b + btPatternBars(sSong["track"][pTrack][b]) > pBar then
         return b & comma & sSong["track"][pTrack][b]
      end if
   end repeat
   return empty
end btBlockAt

-- A pattern into the song at a bar of a track; what it covers there is
-- taken away. False when it does not fit before the song's end.
function btPlaceBlock pTrack, pBar, pPattern
   local tBars, b, tAt
   if pTrack is not an integer or pTrack < 1 or pTrack > kTracks or pBar is not an integer or pBar < 1 then
      return false
   end if
   if pPattern is not an integer or pPattern < 1 or pPattern > sSong["pats"] then
      return false
   end if
   put btPatternBars(pPattern) into tBars
   if pBar + tBars - 1 > kSongBars then
      btStatus "The song ends at bar" && kSongBars & "."
      return false
   end if
   repeat with b = pBar to pBar + tBars - 1
      put btBlockAt(pTrack, b) into tAt
      if tAt is not empty then
         delete variable sSong["track"][pTrack][item 1 of tAt]
      end if
   end repeat
   put pPattern into sSong["track"][pTrack][pBar]
   if sView is "song" then
      btDrawTrack pTrack
      btDrawSongLength
   end if
   btChanged
   return true
end btPlaceBlock

-- The block at a bar of a track taken out of the song.
command btRemoveBlockAt pTrack, pBar
   local tAt
   put btBlockAt(pTrack, pBar) into tAt
   if tAt is empty then
      exit btRemoveBlockAt
   end if
   delete variable sSong["track"][pTrack][item 1 of tAt]
   if sView is "song" then
      btDrawTrack pTrack
      btDrawSongLength
   end if
   btChanged
end btRemoveBlockAt

-- How many steps the song lasts: to the end of its last block, in whole
-- bars, at least one bar (what the audio core plays, beyondBeats.timeline).
function btSongSteps
   local t, b, tEnd
   put 16 into tEnd
   repeat with t = 1 to kTracks
      repeat for each key b in sSong["track"][t]
         put max(tEnd, (b - 1) * 16 + sSong["pat"][sSong["track"][t][b]]["steps"]) into tEnd
      end repeat
   end repeat
   return ((tEnd + 15) div 16) * 16
end btSongSteps

-- The step of the pattern shown that the song plays at its step pStep
-- (from 1), or 0 when the song is not playing it there.
function btCurStepAt pStep
   local t, b, tOff
   repeat with t = 1 to kTracks
      repeat for each key b in sSong["track"][t]
         if sSong["track"][t][b] is sSong["cur"] then
            put pStep - (b - 1) * 16 into tOff
            if tOff >= 1 and tOff <= sSong["pat"][sSong["cur"]]["steps"] then
               return tOff
            end if
         end if
      end repeat
   end repeat
   return 0
end btCurStepAt

-- A press on the playlist: on the ruler, the bar the song starts at; on
-- a track, the pattern chosen goes in at that bar, or the block there
-- comes out, and a drag along the track does the same to each bar it
-- crosses. With pAlt, the block's pattern is chosen.
function btSongDown pX, pY, pAlt
   local tBar, tTrack, tAt
   put btBarAt(pX) into tBar
   if tBar < 1 then
      return false
   end if
   if pY >= kRulerTop and pY < kRulerTop + 18 then
      btSetFrom tBar
      return true
   end if
   put btTrackAt(pY) into tTrack
   if tTrack < 1 then
      return false
   end if
   put btBlockAt(tTrack, tBar) into tAt
   if pAlt then
      if tAt is not empty then
         btSelectPattern item 2 of tAt
      end if
      return true
   end if
   put tTrack into sCellTrack
   put tBar into sCellLast
   if tAt is empty then
      put "add" into sCellPaint
      get btPlaceBlock(tTrack, tBar, sSong["cur"])
   else
      put "del" into sCellPaint
      btRemoveBlockAt tTrack, tBar
   end if
   return true
end btSongDown

command btSongMove pX, pY
   local tBar, b, tStep
   put btBarAt(pX) into tBar
   if tBar < 1 or tBar is sCellLast then
      exit btSongMove
   end if
   if tBar > sCellLast then
      put 1 into tStep
   else
      put -1 into tStep
   end if
   lock screen
   repeat with b = sCellLast + tStep to tBar step tStep
      if sCellPaint is "del" then
         btRemoveBlockAt sCellTrack, b
      else if btBlockAt(sCellTrack, b) is empty and \
            (btPatternBars(sSong["cur"]) is 1 or btBlockAt(sCellTrack, b + 1) is empty) then
         get btPlaceBlock(sCellTrack, b, sSong["cur"])
      end if
   end repeat
   unlock screen
   put tBar into sCellLast
end btSongMove

-- the bar (of the song) and the track under a point of the playlist, or 0
function btBarAt pX
   if pX < kSongLeft or pX >= kSongLeft + kSongWidth then
      return 0
   end if
   return sSongView + min(kViewBars - 1, (pX - kSongLeft) * kViewBars div kSongWidth)
end btBarAt

function btTrackAt pY
   local tTrack
   if pY < kTrackTop then
      return 0
   end if
   put (pY - kTrackTop) div kTrackH + 1 into tTrack
   if tTrack > kTracks or pY - kTrackTop - (tTrack - 1) * kTrackH >= kCellH then
      return 0
   end if
   return tTrack
end btTrackAt

-- The bars the playlist shows: 32 from pFirst (1, 17, 33 ... 97).
command btSetSongView pFirst
   if pFirst is not an integer then
      exit btSetSongView
   end if
   put max(1, min(kSongBars - kViewBars + 1, pFirst)) into sSongView
   if sView is "song" then
      btDrawSong
   end if
end btSetSongView

----------------------------------------------------------------------
-- The piano roll: the notes of a channel in the pattern shown
----------------------------------------------------------------------

function btNotes
   return sSong["pat"][sSong["cur"]]["notes"][sPianoCh]
end btNotes

function btNoteCount
   return the number of lines of btNotes()
end btNoteCount

-- A note: "start,length,pitch,velocity"
function btNoteData pNote
   return line pNote of btNotes()
end btNoteData

-- The note of the piano roll's channel that sounds at a step and a
-- pitch, or 0.
function btNoteAt pStep, pPitch
   local i, tNote
   put 0 into i
   repeat for each line tNote in btNotes()
      add 1 to i
      if item 3 of tNote is pPitch and item 1 of tNote <= pStep and item 1 of tNote + item 2 of tNote > pStep then
         return i
      end if
   end repeat
   return 0
end btNoteAt

-- A note added; its number, or 0 when the channel has as many as it
-- takes.
function btAddNote pStart, pLength, pPitch, pVelocity
   local tNotes, tSteps
   put btNotes() into tNotes
   if the number of lines of tNotes >= kMaxNotes then
      btStatus "Sixty-four notes is the most a channel has in a pattern."
      return 0
   end if
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   if pStart < 1 or pStart > tSteps or pPitch < kLowNote or pPitch > kHighNote then
      return 0
   end if
   put max(1, min(tSteps - pStart + 1, pLength)) into pLength
   if tNotes is not empty then
      put return after tNotes
   end if
   put pStart & comma & pLength & comma & pPitch & comma & max(1, min(9, pVelocity)) after tNotes
   put tNotes into sSong["pat"][sSong["cur"]]["notes"][sPianoCh]
   if sView is "piano" then
      btDrawNotes
   end if
   btChanged
   return the number of lines of tNotes
end btAddNote

-- A note changed: kept inside the pattern and the piano's range.
command btSetNote pNote, pStart, pLength, pPitch, pVelocity
   local tNotes, tSteps
   put btNotes() into tNotes
   if pNote is not an integer or pNote < 1 or pNote > the number of lines of tNotes then
      exit btSetNote
   end if
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   put max(1, min(tSteps, pStart)) into pStart
   put max(1, min(tSteps - pStart + 1, pLength)) into pLength
   put max(kLowNote, min(kHighNote, pPitch)) into pPitch
   put max(1, min(9, pVelocity)) into pVelocity
   put pStart & comma & pLength & comma & pPitch & comma & pVelocity into line pNote of tNotes
   put tNotes into sSong["pat"][sSong["cur"]]["notes"][sPianoCh]
   if sView is "piano" then
      btDrawNote pNote
   end if
   btChanged
end btSetNote

command btDeleteNote pNote
   local tNotes
   put btNotes() into tNotes
   if pNote is not an integer or pNote < 1 or pNote > the number of lines of tNotes then
      exit btDeleteNote
   end if
   delete line pNote of tNotes
   put tNotes into sSong["pat"][sSong["cur"]]["notes"][sPianoCh]
   if sView is "piano" then
      btDrawNotes
   end if
   btChanged
end btDeleteNote

-- A press on the piano roll: on a note, it is moved (or made longer, by
-- its right end), or taken away if let go without moving; with pAlt its
-- velocity goes round. On no note, a note is added, as long as the last
-- one made, and a drag to the right makes it longer.
function btPianoDown pX, pY, pAlt
   local tStep, tPitch, tNote, tData, tEnd
   put btPianoStepAt(pX) into tStep
   put btPitchAt(pY) into tPitch
   if tStep < 1 or tPitch < 1 then
      return false
   end if
   put btNoteAt(tStep, tPitch) into tNote
   if tNote > 0 then
      put btNoteData(tNote) into tData
      if pAlt then
         btSetNote tNote, item 1 of tData, item 2 of tData, item 3 of tData, btNextVelocity(item 4 of tData)
         if not sPlaying then
            btHit sPianoCh, item 4 of btNoteData(tNote), tPitch
         end if
         return true
      end if
      put btPianoX(item 1 of tData + item 2 of tData) into tEnd
      if pX >= tEnd - 8 then
         put "resize" into sNoteMode
      else
         put "move" into sNoteMode
      end if
      put tNote into sNote
      put tStep & comma & tPitch & comma & tData into sNoteFrom
      put false into sNoteMoved
      return true
   end if
   put btAddNote(tStep, sNoteLen, tPitch, 7) into tNote
   if tNote > 0 then
      put tNote into sNote
      put "resize" into sNoteMode
      put tStep & comma & tPitch & comma & btNoteData(tNote) into sNoteFrom
      put true into sNoteMoved
      if not sPlaying then
         btHit sPianoCh, 7, tPitch
      end if
   end if
   return true
end btPianoDown

-- The note pressed follows the mouse: its end (resize), or the whole note
-- (move), by as many steps and semitones as the mouse has gone.
command btPianoMove pX, pY
   local tStep, tPitch, tSteps, tStart, tLength, tNewStart, tNewPitch
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   put item 3 of sNoteFrom into tStart
   put item 4 of sNoteFrom into tLength
   if pX < kPianoLeft then
      put 1 into tStep
   else if pX >= kPianoLeft + kPianoWidth then
      put tSteps into tStep
   else
      put btPianoStepAt(pX) into tStep
   end if
   if sNoteMode is "resize" then
      put max(1, tStep - tStart + 1) into tLength
      if tLength is not item 2 of btNoteData(sNote) then
         btSetNote sNote, tStart, tLength, item 5 of sNoteFrom, item 6 of sNoteFrom
      end if
      exit btPianoMove
   end if
   put btPitchAt(max(kKeyTop, min(kKeyTop + kKeys * kKeyH - 1, pY))) into tPitch
   put max(1, min(tSteps - tLength + 1, tStart + tStep - item 1 of sNoteFrom)) into tNewStart
   put item 5 of sNoteFrom + tPitch - item 2 of sNoteFrom into tNewPitch
   put max(sPianoLow, min(sPianoLow + kKeys - 1, tNewPitch)) into tNewPitch
   if tNewStart is not item 1 of btNoteData(sNote) or tNewPitch is not item 3 of btNoteData(sNote) then
      if tNewPitch is not item 3 of btNoteData(sNote) and not sPlaying then
         btHit sPianoCh, item 6 of sNoteFrom, tNewPitch
      end if
      btSetNote sNote, tNewStart, tLength, tNewPitch, item 6 of sNoteFrom
      put true into sNoteMoved
   end if
end btPianoMove

-- the step and the pitch under a point of the piano roll, or 0
function btPianoStepAt pX
   local tSteps
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   if pX < kPianoLeft or pX >= kPianoLeft + kPianoWidth then
      return 0
   end if
   return min(tSteps, max(1, (pX - kPianoLeft) * tSteps div kPianoWidth + 1))
end btPianoStepAt

function btPitchAt pY
   if pY < kKeyTop or pY >= kKeyTop + kKeys * kKeyH then
      return 0
   end if
   return sPianoLow + kKeys - 1 - (pY - kKeyTop) div kKeyH
end btPitchAt

function btPianoX pStep
   return kPianoLeft + round((pStep - 1) * kPianoWidth / sSong["pat"][sSong["cur"]]["steps"])
end btPianoX

function btPitchY pPitch
   return kKeyTop + (sPianoLow + kKeys - 1 - pPitch) * kKeyH
end btPitchY

command btSetPianoChannel pRow
   if pRow < 1 then
      put sSong["chans"] into pRow
   else if pRow > sSong["chans"] then
      put 1 into pRow
   end if
   put pRow into sPianoCh
   if sView is "piano" then
      btDrawPiano
   end if
end btSetPianoChannel

-- The lowest note the piano roll shows: a C, two octaves up from it.
command btSetOctave pLow
   if pLow is not an integer then
      exit btSetOctave
   end if
   put max(kLowNote, min(kHighNote - kKeys + 1, pLow)) into pLow
   put pLow - (pLow - kLowNote) mod 12 into sPianoLow
   if sView is "piano" then
      btDrawPiano
   end if
end btSetOctave

-- A note's name: C4 is MIDI 60.
function btNoteName pPitch
   return item (pPitch mod 12) + 1 of kNoteNames & (pPitch div 12 - 1)
end btNoteName

----------------------------------------------------------------------
-- Undo
----------------------------------------------------------------------

-- After every change: the page hears it, it is saved, and it is a step
-- Undo goes back over (a drag is one step, when it ends; pNoUndo: not
-- one, as choosing a pattern is not).
command btChanged pNoUndo
   btSend
   if pNoUndo is not true then
      if btDragging() then
         put true into sUndoHeld
      else
         btRemember
      end if
   end if
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

command btUndoReset
   put empty into sUndo
   put btSongText() into sUndo[1]
   put 1 into sUndoAt
   put 1 into sUndoTop
   btTidySamples
end btUndoReset

-- The song as it is now, as the newest step of Undo; what Redo had is
-- gone. Only the last kUndoDepth are kept.
command btRemember
   local tText, i, tKept, tTidy
   if sUndoAt is empty then
      btUndoReset
      exit btRemember
   end if
   put btSongText() into tText
   if btWithoutCur(tText) is btWithoutCur(sUndo[sUndoAt]) then
      put tText into sUndo[sUndoAt]
      exit btRemember
   end if
   -- the steps Redo had, and the oldest one past the depth, are let go,
   -- and with them a sample file only they had
   repeat with i = sUndoAt + 1 to sUndoTop
      if btSampleKeys(sUndo[i]) is not empty then
         put true into tTidy
      end if
   end repeat
   add 1 to sUndoAt
   put tText into sUndo[sUndoAt]
   put sUndoAt into sUndoTop
   if sUndoTop > kUndoDepth then
      if btSampleKeys(sUndo[1]) is not empty then
         put true into tTidy
      end if
      repeat with i = 2 to sUndoTop
         put sUndo[i] into tKept[i - 1]
      end repeat
      put tKept into sUndo
      subtract 1 from sUndoAt
      subtract 1 from sUndoTop
   end if
   if tTidy is true then
      btTidySamples
   end if
end btRemember

-- (the pattern shown is not a change of the song)
function btWithoutCur pText
   set the itemDelimiter to tab
   if item 1 of line 4 of pText is "cur" then
      delete line 4 of pText
   end if
   return pText
end btWithoutCur

command btUndo
   if sUndoAt is empty or sUndoAt <= 1 then
      btStatus "Nothing to undo."
      exit btUndo
   end if
   subtract 1 from sUndoAt
   btRestore sUndo[sUndoAt]
   btStatus "Undone."
end btUndo

command btRedo
   if sUndoAt is empty or sUndoAt >= sUndoTop then
      btStatus "Nothing to redo."
      exit btRedo
   end if
   add 1 to sUndoAt
   btRestore sUndo[sUndoAt]
   btStatus "Redone."
end btRedo

-- A step of Undo back in the song; the pattern shown stays if it can.
command btRestore pText
   local tCur, tWas, n
   put sSong["cur"] into tCur
   repeat with n = 1 to kUserSlots
      put btSlotKey(n) into tWas[n]
   end repeat
   if not btReadSong(pText) then
      exit btRestore
   end if
   -- a slot whose sample the step had another of: that one to the page
   repeat with n = 1 to kUserSlots
      if btSlotKey(n) is not tWas[n] then
         if sSong["user"][n]["name"] is empty then
            btClearPageSample n
         else
            btSendSample n
         end if
      end if
   end repeat
   if tCur is an integer and tCur <= sSong["pats"] then
      put tCur into sSong["cur"]
   end if
   if sPianoCh > sSong["chans"] then
      put 1 into sPianoCh
   end if
   btDrawAll
   btChanged true
end btRestore

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

-- The user's samples are kept beside the song, a file a slot.
function btSampleFolder
   local tFolder
   put btSavePath() & "-samples" into tFolder
   if there is not a folder tFolder then
      create folder tFolder
   end if
   return tFolder
end btSampleFolder

-- The file of a slot's sample as the song has it now.
function btSampleFile pSlot
   return btKeyFile(btSlotKey(pSlot))
end btSampleFile

function btKeyFile pKey
   return btSampleFolder() & "/sample-" & pKey & ".bin"
end btKeyFile

-- A slot's file key: a song from before keys has the slot's number.
function btSlotKey pSlot
   if sSong["user"][pSlot]["name"] is empty then
      return empty
   end if
   if sSong["user"][pSlot]["file"] is empty then
      return pSlot
   end if
   return sSong["user"][pSlot]["file"]
end btSlotKey

-- A key no file has yet, for a sample coming into a slot.
function btNewSampleKey pSlot
   local tN
   put the milliseconds into tN
   repeat while there is a file btKeyFile(pSlot & "-" & tN)
      add 1 to tN
   end repeat
   return pSlot & "-" & tN
end btNewSampleKey

-- A key read from a song's text: digits, and a dash and digits, or none
-- (it names a file, so nothing else gets in).
function btGoodKey pKey
   return matchText(pKey, "^[1-9][0-9]*(-[0-9]+)?$")
end btGoodKey

-- The keys of the samples a song's text plays, a line each.
function btSampleKeys pText
   local tLine, tKeys
   set the itemDelimiter to tab
   filter pText with "sample" & tab & "*"
   repeat for each line tLine in pText
      if item 4 of tLine is not empty then
         put item 4 of tLine & return after tKeys
      else
         put item 2 of tLine & return after tKeys
      end if
   end repeat
   return tKeys
end btSampleKeys

-- The sample files that neither the song nor a step of Undo or Redo
-- plays are deleted: a sample loaded over another keeps the other's file
-- only while a step can bring it back.
command btTidySamples
   local tKeep, i, tFile, tFolder
   put btSavePath() & "-samples" into tFolder
   if there is not a folder tFolder then
      exit btTidySamples
   end if
   put btSampleKeys(btSongText()) into tKeep
   repeat with i = 1 to sUndoTop
      put btSampleKeys(sUndo[i]) after tKeep
   end repeat
   repeat for each line tFile in files(tFolder)
      if tFile begins with "sample-" and tFile ends with ".bin" then
         if not (char 8 to -5 of tFile is among the lines of tKeep) then
            delete file (tFolder & "/" & tFile)
         end if
      end if
   end repeat
end btTidySamples

-- The song as text: a line a setting, a line a channel, a line for each
-- pattern followed by its rows and its notes, a line a track of the
-- playlist and a line a sample, the items split by tabs.
function btSongText
   local tText, n, p, t, tKeys, b, tNotes
   put kFormat & return into tText
   put "bpm" & tab & sSong["bpm"] & return after tText
   put "swing" & tab & sSong["swing"] & return after tText
   put "cur" & tab & sSong["cur"] & return after tText
   put "mode" & tab & sSong["mode"] & return after tText
   put "from" & tab & sSong["from"] & return after tText
   put "master" & tab & sSong["master"]["vol"] & tab & sSong["master"]["size"] & tab & sSong["master"]["dly"] & \
         tab & sSong["master"]["fb"] & return after tText
   repeat with n = 1 to sSong["chans"]
      put "ch" & tab & sSong["ch"][n]["sound"] & tab & sSong["ch"][n]["vol"] & tab & sSong["ch"][n]["pan"] & tab & \
            (sSong["ch"][n]["mute"] is true) & tab & (sSong["ch"][n]["solo"] is true) & tab & sSong["ch"][n]["cut"] & \
            tab & sSong["ch"][n]["rev"] & tab & sSong["ch"][n]["dly"] & tab & sSong["ch"][n]["tune"] & return after tText
   end repeat
   repeat with p = 1 to sSong["pats"]
      put "pat" & tab & btClean(sSong["pat"][p]["name"]) & tab & sSong["pat"][p]["steps"] & return after tText
      repeat with n = 1 to sSong["chans"]
         put "row" & tab & sSong["pat"][p]["rows"][n] & return after tText
      end repeat
      repeat with n = 1 to sSong["chans"]
         put sSong["pat"][p]["notes"][n] into tNotes
         if tNotes is not empty then
            replace return with ";" in tNotes
            put "notes" & tab & n & tab & tNotes & return after tText
         end if
      end repeat
   end repeat
   repeat with t = 1 to kTracks
      put the keys of sSong["track"][t] into tKeys
      if tKeys is not empty then
         sort lines of tKeys numeric
         put "track" & tab & t & tab into b
         repeat for each line n in tKeys
            put n & ":" & sSong["track"][t][n] & comma after b
         end repeat
         delete the last char of b
         put b & return after tText
      end if
   end repeat
   repeat with n = 1 to kUserSlots
      if sSong["user"][n]["name"] is not empty then
         put "sample" & tab & n & tab & sSong["user"][n]["name"] & tab & btSlotKey(n) & return after tText
      end if
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
-- was) when the text is not one. The first version's songs (kOldFormat)
-- are read too: they are the same lines with fewer of them. A file saved
-- with Save has the samples' data in it too ("sampledata"): they are
-- kept and played.
-- pFromFile: a song file of the user's (File, Open a song), whose
-- samples come with it and take new keys here.
function btReadSong pText, pFromFile
   local tSong, tLine, tKey, n, p, tRow, tDigits, i, tSamples, tNotes, tNote, tList, tFormat, t, b, tBlock
   set the itemDelimiter to tab
   put line 1 of pText into tFormat
   if tFormat is not kFormat and tFormat is not kOldFormat then
      return false
   end if
   put btBareSong() into tSong
   put 0 into n
   repeat for each line tLine in line 2 to -1 of pText
      put item 1 of tLine into tKey
      switch tKey
         case "bpm"
         case "swing"
         case "cur"
         case "from"
            if item 2 of tLine is an integer then
               put item 2 of tLine into tSong[tKey]
            end if
            break
         case "mode"
            if item 2 of tLine is "song" then
               put "song" into tSong["mode"]
            end if
            break
         case "master"
            put btWithin(item 2 of tLine, 0, 100, 80) into tSong["master"]["vol"]
            put btWithin(item 3 of tLine, 0, 1, 0) into tSong["master"]["size"]
            put btWithin(item 4 of tLine, 2, 4, 3) into tSong["master"]["dly"]
            put btWithin(item 5 of tLine, 0, 90, 35) into tSong["master"]["fb"]
            break
         case "ch"
            if tSong["pats"] > 0 or tSong["chans"] >= kMaxChannels then
               return false
            end if
            add 1 to tSong["chans"]
            put tSong["chans"] into n
            put btWithin(item 2 of tLine, 1, kSounds, 1) into tSong["ch"][n]["sound"]
            put btWithin(item 3 of tLine, 0, 100, 78) into tSong["ch"][n]["vol"]
            put btWithin(item 4 of tLine, -100, 100, 0) into tSong["ch"][n]["pan"]
            put (item 5 of tLine is "true") into tSong["ch"][n]["mute"]
            put (item 6 of tLine is "true") into tSong["ch"][n]["solo"]
            put btWithin(item 7 of tLine, 0, 100, 100) into tSong["ch"][n]["cut"]
            put btWithin(item 8 of tLine, 0, 100, 0) into tSong["ch"][n]["rev"]
            put btWithin(item 9 of tLine, 0, 100, 0) into tSong["ch"][n]["dly"]
            put btWithin(item 10 of tLine, -24, 24, 0) into tSong["ch"][n]["tune"]
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
         case "notes"
            -- a channel's notes in the pattern above: start,length,pitch,
            -- velocity; each made safe, those that cannot be dropped
            if tSong["pats"] < 1 or item 2 of tLine is not an integer or item 2 of tLine < 1 or \
                  item 2 of tLine > tSong["chans"] then
               break
            end if
            put empty into tNotes
            put item 3 of tLine into tList
            replace ";" with return in tList
            set the itemDelimiter to comma
            repeat for each line tNote in tList
               if the number of lines of tNotes < kMaxNotes and item 1 of tNote is an integer and \
                     item 3 of tNote is an integer then
                  put btWithin(item 1 of tNote, 1, kMaxSteps, 1) into i
                  put i & comma & btWithin(item 2 of tNote, 1, kMaxSteps - i + 1, 1) & comma & \
                        btWithin(item 3 of tNote, kLowNote, kHighNote, 60) & comma & \
                        btWithin(item 4 of tNote, 1, 9, 7) & return after tNotes
               end if
            end repeat
            set the itemDelimiter to tab
            delete the last char of tNotes
            put tNotes into tSong["pat"][tSong["pats"]]["notes"][item 2 of tLine]
            break
         case "track"
            -- where patterns start in a track: bar:pattern, ...
            put item 2 of tLine into t
            if t is not an integer or t < 1 or t > kTracks then
               break
            end if
            put item 3 of tLine into tList
            set the itemDelimiter to ":"
            repeat for each word tBlock in replaceText(tList, ",", " ")
               put item 1 of tBlock into b
               if b is an integer and b >= 1 and b <= kSongBars and item 2 of tBlock is an integer then
                  put item 2 of tBlock into tSong["track"][t][b]
               end if
            end repeat
            set the itemDelimiter to tab
            break
         case "sample"
            if item 2 of tLine is an integer and item 2 of tLine >= 1 and item 2 of tLine <= kUserSlots then
               put char 1 to 40 of btCleanName(item 3 of tLine) into tSong["user"][item 2 of tLine]["name"]
               if btGoodKey(item 4 of tLine) then
                  put item 4 of tLine into tSong["user"][item 2 of tLine]["file"]
               end if
            end if
            break
         case "sampledata"
            if item 2 of tLine is an integer and item 2 of tLine >= 1 and item 2 of tLine <= kUserSlots then
               put item 3 of tLine into tSamples[item 2 of tLine]
            end if
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
   -- blocks of patterns the song does not have are not in it
   repeat with t = 1 to kTracks
      repeat for each key b in tSong["track"][t]
         if tSong["track"][t][b] < 1 or tSong["track"][t][b] > tSong["pats"] then
            delete variable tSong["track"][t][b]
         end if
      end repeat
   end repeat
   put btWithin(tSong["bpm"], 40, 240, 120) into tSong["bpm"]
   put btWithin(tSong["swing"], 0, 100, 0) into tSong["swing"]
   put btWithin(tSong["cur"], 1, tSong["pats"], 1) into tSong["cur"]
   put btWithin(tSong["from"], 1, kSongBars, 1) into tSong["from"]
   put tSong into sSong
   -- the samples a file brought: kept beside the song under new keys (a
   -- named slot that brought none has a key with no file), and played
   if pFromFile is true then
      repeat with n = 1 to kUserSlots
         if sSong["user"][n]["name"] is not empty then
            put btNewSampleKey(n) into sSong["user"][n]["file"]
            if tSamples[n] is not empty then
               put base64Decode(tSamples[n]) into url ("binfile:" & btSampleFile(n))
            end if
            btSendSample n
         end if
      end repeat
   end if
   return true
end btReadSong

function btWithin pValue, pLow, pHigh, pDefault
   if pValue is not an integer then
      return pDefault
   end if
   return max(pLow, min(pHigh, pValue))
end btWithin

-- A file's name made fit for a sound's name: no folders, no tabs.
function btCleanName pName
   set the itemDelimiter to "/"
   put the last item of pName into pName
   set the itemDelimiter to "\"
   put the last item of pName into pName
   replace tab with space in pName
   replace return with space in pName
   replace linefeed with space in pName
   return pName
end btCleanName

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
-- Files of the user's own: songs, samples and WAVs
----------------------------------------------------------------------

-- The song as a file to keep or to give: its text and, after it, each
-- sample's data.
function btProjectText
   local tText, n, tData
   put btSongText() into tText
   repeat with n = 1 to kUserSlots
      if sSong["user"][n]["name"] is not empty and there is a file btSampleFile(n) then
         put url ("binfile:" & btSampleFile(n)) into tData
         put base64Encode(tData) into tData
         replace return with empty in tData
         replace linefeed with empty in tData
         put "sampledata" & tab & n & tab & tData & return after tText
      end if
   end repeat
   return tText
end btProjectText

-- File > Save: the browser downloads the song (ask file names it);
-- elsewhere it is saved where the user says.
command btAskSave
   ask file "Save the song as:" with "my-song.beats"
   if it is empty then
      exit btAskSave
   end if
   btSaveProject it
end btAskSave

command btSaveProject pPath
   put textEncode(btProjectText(), "UTF-8") into url ("binfile:" & pPath)
   if the result is not empty then
      btStatus "It could not be saved:" && the result
   else if the platform is "HTML5" and pPath begins with "/downloads/" then
      -- the web engine hands a file written there to the browser as a
      -- download once it is closed (ask file answers such a path)
      btStatus "Downloaded" && btCleanName(pPath) & ". Open it again with File, Open a song."
   else
      btStatus "Saved" && btCleanName(pPath) & "."
   end if
end btSaveProject

command btAskOpen
   answer file "Open a song (a file saved with File, Save the song):"
   if it is empty then
      exit btAskOpen
   end if
   btOpenProject it
end btAskOpen

-- A song file opened: it takes the place of the song (Undo brings the
-- old one back).
command btOpenProject pPath
   local tText
   put textDecode(url ("binfile:" & pPath), "UTF-8") into tText
   if not btReadSong(tText, true) then
      btStatus btCleanName(pPath) && "is not a Beyond Beats song."
      exit btOpenProject
   end if
   put 1 into sPianoCh
   put 1 into sSongView
   btDrawAll
   btChanged
   btStatus "Opened" && btCleanName(pPath) & "."
end btOpenProject

-- A sample of the user's own (WAV, MP3, OGG...), chosen with the file
-- picker, into a slot (empty: the channel's own slot if it plays one,
-- else the first free) and played by a channel (empty: a new one).
command btAskSample pRow, pSlot
   answer file "Choose a sound file (WAV, MP3 or OGG):"
   if it is empty then
      exit btAskSample
   end if
   btImportSample pRow, it, pSlot
end btAskSample

command btImportSample pRow, pPath, pSlot
   local tData, tName, n
   put url ("binfile:" & pPath) into tData
   if tData is empty then
      btStatus "That file could not be read."
      exit btImportSample
   end if
   if length(tData) > kMaxSample then
      btStatus "A sample can be up to 4 MB: a few seconds of sound."
      exit btImportSample
   end if
   if pSlot is empty and btIsChannel(pRow) and sSong["ch"][pRow]["sound"] >= kFirstUser then
      put sSong["ch"][pRow]["sound"] - kFirstUser + 1 into pSlot
   end if
   if pSlot is empty then
      repeat with n = 1 to kUserSlots
         if sSong["user"][n]["name"] is empty then
            put n into pSlot
            exit repeat
         end if
      end repeat
   end if
   if pSlot is not an integer or pSlot < 1 or pSlot > kUserSlots then
      btStatus "Eight samples is the most a song has. Load one into a channel that plays a sample to replace it."
      exit btImportSample
   end if
   if not btIsChannel(pRow) then
      if sSong["chans"] >= kMaxChannels then
         btStatus "Twelve channels is the most a song has."
         exit btImportSample
      end if
      btAddChannel kFirstUser + pSlot - 1
      put sSong["chans"] into pRow
   end if
   put char 1 to 40 of btCleanName(pPath) into tName
   -- a new key: the file of a sample it replaces stays while Undo can
   -- bring that one back
   put tName into sSong["user"][pSlot]["name"]
   put btNewSampleKey(pSlot) into sSong["user"][pSlot]["file"]
   put tData into url ("binfile:" & btSampleFile(pSlot))
   btSendSample pSlot
   btSetSound pRow, kFirstUser + pSlot - 1
   btStatus "Channel" && pRow && "plays" && tName & ". Its notes in the piano roll play it higher and lower."
end btImportSample

-- A slot's sample, from its file, to the page.
command btSendSample pSlot
   local tData
   if sAudio is not "ok" or there is not a file btSampleFile(pSlot) then
      exit btSendSample
   end if
   put base64Encode(url ("binfile:" & btSampleFile(pSlot))) into tData
   replace return with empty in tData
   replace linefeed with empty in tData
   do "beyondBeats.loadSample(" & pSlot & ",'" & tData & "')" as "JavaScript"
end btSendSample

-- A slot the song no longer has a sample in, emptied in the page too.
command btClearPageSample pSlot
   if sAudio is "ok" then
      do "beyondBeats.clearSample(" & pSlot & ")" as "JavaScript"
   end if
end btClearPageSample

-- File > Export: the page renders the song (or, in Pattern mode, the
-- pattern) and the browser downloads it as a WAV.
command btAskExport
   if not btReady() then
      btStatus "Exporting needs a browser: the sound is made by the page."
      exit btAskExport
   end if
   ask file "Export the song as:" with "my-song.wav"
   if it is empty then
      exit btAskExport
   end if
   btExport btCleanName(it)
end btAskExport

command btExport pName
   local tName
   if not btReady() then
      btStatus "Exporting needs a browser: the sound is made by the page."
      exit btExport
   end if
   put pName into tName
   replace "'" with "_" in tName
   replace "\" with "_" in tName
   if tName is empty then
      put "my-song.wav" into tName
   end if
   if not (tName ends with ".wav") then
      put ".wav" after tName
   end if
   put tName into sExportName
   do "beyondBeats.exportWav('" & tName & "')" as "JavaScript"
   btStatus "Rendering" && tName & "..."
   btExportPoll
end btExport

on btExportPoll
   local tState
   set the defaultStack to the short name of me
   put empty into sExportTimer
   do "beyondBeats.exportState()" as "JavaScript"
   put the result into tState
   if tState is "working" then
      send "btExportPoll" to me in 200 milliseconds
      put the result into sExportTimer
   else if tState is "done" then
      do "beyondBeats.lastExport ? Math.round(beyondBeats.lastExport.seconds) : 0" as "JavaScript"
      btStatus "Exported" && sExportName && "(" & the result && "seconds). Your browser has it in its downloads."
   else
      btStatus "The export did not work:" && tState
   end if
end btExportPoll

----------------------------------------------------------------------
-- The page's sound
----------------------------------------------------------------------

-- Makes the audio core if need be; true when the page can play.
function btReady
   local tResult, n
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
   if tResult is "ok" then
      -- the samples the song plays, from their files
      repeat with n = 1 to kUserSlots
         if sSong["user"][n]["name"] is not empty then
            btSendSample n
         end if
      end repeat
   end if
   return tResult is "ok"
end btReady

-- The song, as the audio core takes it (beyondBeats.set): every number
-- as it counts from 0 there.
function btSongJson
   local tJson, n, p, tNotes, tNote, t, tKeys, b, tFirst
   put "{" & btKey("bpm") & sSong["bpm"] & "," & btKey("swing") & sSong["swing"] & "," & btKey("mode") & quote & \
         sSong["mode"] & quote & "," & btKey("cur") & sSong["cur"] - 1 & "," & btKey("from") & (sSong["from"] - 1) * 16 & \
         "," & btKey("master") & "[" & sSong["master"]["vol"] & "," & sSong["master"]["size"] & "," & \
         sSong["master"]["dly"] & "," & sSong["master"]["fb"] & "]," & btKey("ch") & "[" into tJson
   repeat with n = 1 to sSong["chans"]
      if n > 1 then
         put "," after tJson
      end if
      put "[" & sSong["ch"][n]["sound"] - 1 & "," & sSong["ch"][n]["vol"] & "," & sSong["ch"][n]["pan"] & "," & \
            btBit(sSong["ch"][n]["mute"]) & "," & btBit(sSong["ch"][n]["solo"]) & "," & sSong["ch"][n]["cut"] & "," & \
            sSong["ch"][n]["rev"] & "," & sSong["ch"][n]["dly"] & "," & sSong["ch"][n]["tune"] & "]" after tJson
   end repeat
   put "]," & btKey("pats") & "[" after tJson
   repeat with p = 1 to sSong["pats"]
      if p > 1 then
         put "," after tJson
      end if
      put "{" & btKey("steps") & sSong["pat"][p]["steps"] & "," & btKey("rows") & "[" after tJson
      repeat with n = 1 to sSong["chans"]
         if n > 1 then
            put "," after tJson
         end if
         put quote & char 1 to sSong["pat"][p]["steps"] of sSong["pat"][p]["rows"][n] & quote after tJson
      end repeat
      put "]," & btKey("notes") & "[" after tJson
      repeat with n = 1 to sSong["chans"]
         if n > 1 then
            put "," after tJson
         end if
         put "[" after tJson
         put true into tFirst
         repeat for each line tNote in sSong["pat"][p]["notes"][n]
            if not tFirst then
               put "," after tJson
            end if
            put false into tFirst
            put "[" & item 1 of tNote - 1 & "," & item 2 of tNote & "," & item 3 of tNote & "," & item 4 of tNote & "]" after tJson
         end repeat
         put "]" after tJson
      end repeat
      put "]}" after tJson
   end repeat
   put "]," & btKey("song") & "[" after tJson
   put true into tFirst
   repeat with t = 1 to kTracks
      put the keys of sSong["track"][t] into tKeys
      sort lines of tKeys numeric
      repeat for each line b in tKeys
         if not tFirst then
            put "," after tJson
         end if
         put false into tFirst
         put "[" & b - 1 & "," & sSong["track"][t][b] - 1 & "]" after tJson
      end repeat
   end repeat
   put "]}" after tJson
   return tJson
end btSongJson

function btKey pName
   return quote & pName & quote & ":"
end btKey

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

-- One channel's sound now: a pad, a key, a sound tried. pPitch: a MIDI
-- note (empty: the sound as a step plays it).
command btHit pRow, pVelocity, pPitch
   if pPitch is empty then
      put "null" into pPitch
   end if
   if btReady() and btIsChannel(pRow) then
      do "beyondBeats.hit(" & pRow - 1 & "," & pVelocity & "," & pPitch & ")" as "JavaScript"
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
         if sSong["mode"] is "song" then
            btStatus "Playing the song from bar" && sSong["from"] & ". Pattern mode loops the pattern chosen."
         else
            btStatus "Playing. Change pads, notes, sounds and levels as it plays: you hear it at once."
         end if
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
      btDrawMeters empty
   end if
end btStop

-- How many steps play, round and round: the pattern's, or the song's.
function btPlayLength
   if sSong["mode"] is "song" then
      return btSongSteps()
   end if
   return sSong["pat"][sSong["cur"]]["steps"]
end btPlayLength

-- Many times a second: which step is the page playing, and how loud is
-- each channel? The playheads and the meters go there.
on btFollow
   local tStep, tTotal, tPoll, tLevels, tFirst
   set the defaultStack to the short name of me
   put empty into sTimer
   if not sPlaying then
      exit btFollow
   end if
   if sAudio is "ok" then
      do "beyondBeats.poll()" as "JavaScript"
      put the result into tPoll
      set the itemDelimiter to "|"
      put item 1 of tPoll + 1 into tStep
      put item 2 of tPoll into tLevels
      set the itemDelimiter to comma
   else
      put btPlayLength() into tTotal
      put 0 into tFirst
      if sSong["mode"] is "song" then
         put min(tTotal - 1, (sSong["from"] - 1) * 16) into tFirst
      end if
      put ((tFirst + round((the milliseconds - sFallbackAt) / (15000 / sSong["bpm"]))) mod tTotal) + 1 into tStep
   end if
   if tStep is not sStep and tStep >= 1 then
      btShowStep tStep
   end if
   if sView is "mixer" and tLevels is not empty then
      btDrawMeters tLevels
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

-- One of the four views: "rack", "piano", "song" or "mixer". Only the
-- one shown is drawn, so it is drawn whole when it is shown.
command btShowView pView
   if pView is not among the items of "rack,piano,song,mixer" then
      exit btShowView
   end if
   put pView into sView
   lock screen
   btClosePicker
   btCloseMenu
   set the visible of group "View Rack" to pView is "rack"
   set the visible of group "View Piano" to pView is "piano"
   set the visible of group "View Song" to pView is "song"
   set the visible of group "View Mixer" to pView is "mixer"
   set the visible of field "Steps Label" to pView is "rack" or pView is "piano"
   set the visible of button "Steps 16" to pView is "rack" or pView is "piano"
   set the visible of button "Steps 32" to pView is "rack" or pView is "piano"
   btLight "Tab Rack", pView is "rack"
   btLight "Tab Piano", pView is "piano"
   btLight "Tab Song", pView is "song"
   btLight "Tab Mixer", pView is "mixer"
   btDrawAll
   if sPlaying then
      btShowStep sStep
   end if
   unlock screen
end btShowView

command btDrawAll
   lock screen
   btDrawTop
   btDrawPatterns
   btDrawView
   unlock screen
end btDrawAll

command btDrawView
   switch sView
      case "rack"
         btDrawRows
         break
      case "piano"
         btDrawPiano
         break
      case "song"
         btDrawSong
         break
      case "mixer"
         btDrawMixer
         break
   end switch
end btDrawView

-- A channel changed: drawn again in the view shown.
command btDrawChannelViews pRow
   switch sView
      case "rack"
         btDrawChannel pRow
         break
      case "mixer"
         btDrawStrip pRow
         break
      case "piano"
         if pRow is sPianoCh then
            btDrawPianoHeader
            btDrawNotes
         end if
         break
   end switch
end btDrawChannelViews

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
   btLight "Mode Pattern", sSong["mode"] is "pattern"
   btLight "Mode Song", sSong["mode"] is "song"
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

command btLightSmall pButton, pOn, pColor
   if pOn then
      set the backgroundColor of button pButton to pColor
      set the textColor of button pButton to kNight
   else
      set the backgroundColor of button pButton to kCell
      set the textColor of button pButton to kMuted
   end if
end btLightSmall

-- The pattern list, each pattern with its colour (its colour in the
-- playlist too).
command btDrawPatterns
   local tText, p
   repeat with p = 1 to sSong["pats"]
      put sSong["pat"][p]["name"] & return after tText
   end repeat
   delete the last char of tText
   set the text of field "Patterns" to tText
   set the hilitedLine of field "Patterns" to sSong["cur"]
   repeat with p = 1 to kMaxPatterns
      set the visible of graphic ("pswatch" && p) to p <= sSong["pats"]
   end repeat
end btDrawPatterns

-- a slider's fill, from its left, pValue of pTop along
command btHFill pTrack, pFill, pValue, pTop, pColor
   local tLeft
   put the left of graphic pTrack into tLeft
   set the rect of graphic pFill to tLeft, the top of graphic pTrack, \
         tLeft + max(2, round(the width of graphic pTrack * pValue / pTop)), the bottom of graphic pTrack
   set the backgroundColor of graphic pFill to pColor
end btHFill

-- a pan's fill, from the middle to one side
command btPanFill pTrack, pFill, pPan, pColor
   local tLeft, tWidth, tMid
   put the left of graphic pTrack into tLeft
   put the width of graphic pTrack into tWidth
   put tLeft + round(tWidth / 2) into tMid
   if pPan < 0 then
      set the rect of graphic pFill to tMid + round(tWidth / 2 * pPan / 100), \
            the top of graphic pTrack, tMid + 1, the bottom of graphic pTrack
   else
      set the rect of graphic pFill to tMid - 1, the top of graphic pTrack, \
            tMid + max(1, round(tWidth / 2 * pPan / 100)), the bottom of graphic pTrack
   end if
   set the backgroundColor of graphic pFill to pColor
end btPanFill

-- a fader's or a meter's fill, from its bottom, pValue of 100 up
command btVFill pTrack, pFill, pValue, pColor
   local tBottom, tHeight
   put the bottom of graphic pTrack into tBottom
   put round(the height of graphic pTrack * max(0, min(100, pValue)) / 100) into tHeight
   if tHeight < 1 then
      set the visible of graphic pFill to false
      exit btVFill
   end if
   set the rect of graphic pFill to the left of graphic pTrack, tBottom - tHeight, the right of graphic pTrack, tBottom
   set the backgroundColor of graphic pFill to pColor
   set the visible of graphic pFill to true
end btVFill

----------------------------------------------------------------------
-- The rack
----------------------------------------------------------------------

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
   btDrawChosen
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

-- The mark beside the channel the piano roll edits.
command btDrawChosen
   if sPianoCh > sSong["chans"] then
      put 1 into sPianoCh
   end if
   set the rect of graphic "Chosen" to 196, btRowY(sPianoCh) + 4, 199, btRowY(sPianoCh) + kPadH - 4
end btDrawChosen

-- One channel: its name, mute and solo, its levels and its pads.
command btDrawChannel pRow
   local tColor, tAudible, s, tSteps
   lock screen
   put item pRow of kColors into tColor
   put btAudible(pRow) into tAudible
   set the backgroundColor of graphic ("swatch" && pRow) to tColor
   set the label of button ("chan" && pRow) to btSoundName(sSong["ch"][pRow]["sound"])
   if tAudible then
      set the textColor of button ("chan" && pRow) to kInk
   else
      set the textColor of button ("chan" && pRow) to kDim
   end if
   btLightSmall "mute" && pRow, sSong["ch"][pRow]["mute"], kEmber
   btLightSmall "solo" && pRow, sSong["ch"][pRow]["solo"], kAmber
   -- the volume fills from the left, the pan from the middle
   btHFill "vol" && pRow, "volfill" && pRow, sSong["ch"][pRow]["vol"], 100, tColor
   btPanFill "pan" && pRow, "panfill" && pRow, sSong["ch"][pRow]["pan"], tColor
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   repeat with s = 1 to tSteps
      btDrawPad pRow, s, tColor, tAudible
   end repeat
   unlock screen
end btDrawChannel

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

----------------------------------------------------------------------
-- The playlist
----------------------------------------------------------------------

command btDrawSong
   local b, t, tBar
   lock screen
   set the text of field "Bars Label" to "Bars" && sSongView && "to" && sSongView + kViewBars - 1
   repeat with b = 1 to kViewBars
      put sSongView + b - 1 into tBar
      if (tBar - 1) mod 4 is 0 then
         set the text of field ("barno" && b) to tBar
      else
         set the text of field ("barno" && b) to empty
      end if
   end repeat
   repeat with t = 1 to kTracks
      btDrawTrack t
   end repeat
   btDrawStartMark
   btDrawSongLength
   set the visible of graphic "SongHead" to false
   unlock screen
end btDrawSong

-- the left of a bar of the song in the playlist
function btSongX pBar
   return kSongLeft + round((pBar - sSongView) * kSongWidth / kViewBars)
end btSongX

-- A track: each block in its pattern's colour, its first bar with the
-- pattern's number, the bars it goes on over fainter.
command btDrawTrack pTrack
   local tCover, tStart, b, k, p, c, tBar, tCell
   repeat for each key b in sSong["track"][pTrack]
      put sSong["track"][pTrack][b] into p
      put true into tStart[b]
      repeat with k = 0 to btPatternBars(p) - 1
         put p into tCover[b + k]
      end repeat
   end repeat
   lock screen
   repeat with c = 1 to kViewBars
      put sSongView + c - 1 into tBar
      put "cell" && pTrack & comma & c into tCell
      if tCover[tBar] is not empty then
         set the backgroundColor of graphic tCell to item tCover[tBar] of kPatColors
         -- only a block's first bar shows a name: a graphic whose label
         -- is empty shows its own name instead ("cell 1,9")
         if tStart[tBar] then
            set the blendLevel of graphic tCell to 0
            set the label of graphic tCell to tCover[tBar]
            set the showName of graphic tCell to true
         else
            set the blendLevel of graphic tCell to 40
            set the label of graphic tCell to empty
            set the showName of graphic tCell to false
         end if
      else
         if (tBar - 1) mod 4 is 0 then
            set the backgroundColor of graphic tCell to kCellBeat
         else
            set the backgroundColor of graphic tCell to kCell
         end if
         set the blendLevel of graphic tCell to 0
         set the label of graphic tCell to empty
         set the showName of graphic tCell to false
      end if
   end repeat
   unlock screen
end btDrawTrack

command btDrawStartMark
   local tX
   put btSongX(sSong["from"]) into tX
   set the visible of graphic "StartMark" to sSong["from"] >= sSongView and sSong["from"] < sSongView + kViewBars
   set the rect of graphic "StartMark" to tX, kRulerTop, tX + 6, kRulerTop + 18
end btDrawStartMark

command btDrawSongLength
   local tSteps, tSeconds
   put btSongSteps() into tSteps
   put round(tSteps * 15 / sSong["bpm"]) into tSeconds
   set the text of field "Song Length" to "Song:" && tSteps div 16 && "bars," && tSeconds div 60 & ":" & \
         char -2 to -1 of ("0" & tSeconds mod 60)
end btDrawSongLength

----------------------------------------------------------------------
-- The piano roll
----------------------------------------------------------------------

command btDrawPiano
   local k, tPitch, tSteps, s, tBlack
   lock screen
   btDrawPianoHeader
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   repeat with k = 1 to kKeys
      put sPianoLow + k - 1 into tPitch
      put (tPitch mod 12) is among the items of "1,3,6,8,10" into tBlack
      if tBlack then
         set the backgroundColor of graphic ("key" && k) to kNight
         set the backgroundColor of graphic ("lane" && k) to kLaneDark
      else
         set the backgroundColor of graphic ("key" && k) to kKeyWhite
         set the backgroundColor of graphic ("lane" && k) to kCell
      end if
      -- the Cs are named; the other keys show nothing (not their names)
      if tPitch mod 12 is 0 then
         set the label of graphic ("key" && k) to btNoteName(tPitch)
         set the showName of graphic ("key" && k) to true
      else
         set the label of graphic ("key" && k) to empty
         set the showName of graphic ("key" && k) to false
      end if
   end repeat
   repeat with s = 1 to kMaxSteps
      set the visible of graphic ("pline" && s) to s <= tSteps
      if s <= tSteps then
         set the rect of graphic ("pline" && s) to btPianoX(s), kKeyTop, btPianoX(s) + 1, kKeyTop + kKeys * kKeyH
         if s mod 4 is 1 then
            set the backgroundColor of graphic ("pline" && s) to kDim
         else
            set the backgroundColor of graphic ("pline" && s) to kCellBeat
         end if
      end if
   end repeat
   btDrawNotes
   set the visible of graphic "PianoHead" to false
   unlock screen
end btDrawPiano

command btDrawPianoHeader
   local tCh
   put sPianoCh into tCh
   if not btIsChannel(tCh) then
      put 1 into tCh
      put 1 into sPianoCh
   end if
   set the text of field "Piano Chan" to tCh & ". " & btSoundName(sSong["ch"][tCh]["sound"])
   set the textColor of field "Piano Chan" to item tCh of kColors
   set the text of field "Oct Label" to btNoteName(sPianoLow) && "to" && btNoteName(sPianoLow + kKeys - 1)
end btDrawPianoHeader

-- Every note of the channel in the pattern shown, and how many are out
-- of sight above and below.
command btDrawNotes
   local i, tAbove, tBelow, tNote, tInfo
   lock screen
   put 0 into tAbove
   put 0 into tBelow
   put 0 into i
   repeat for each line tNote in btNotes()
      add 1 to i
      if item 3 of tNote > sPianoLow + kKeys - 1 then
         add 1 to tAbove
      else if item 3 of tNote < sPianoLow then
         add 1 to tBelow
      end if
      btDrawNote i
   end repeat
   repeat with i = i + 1 to kMaxNotes
      set the visible of graphic ("note" && i) to false
   end repeat
   if tAbove > 0 then
      put tAbove && "higher" into tInfo
   end if
   if tBelow > 0 then
      if tInfo is not empty then
         put ", " after tInfo
      end if
      put tBelow && "lower" after tInfo
   end if
   if tInfo is not empty then
      put "Notes out of sight:" && tInfo into tInfo
   end if
   set the text of field "Piano Info" to tInfo
   unlock screen
end btDrawNotes

command btDrawNote pNote
   local tData, tNote, tSteps, tTop
   put "note" && pNote into tNote
   put btNoteData(pNote) into tData
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   if tData is empty or item 1 of tData > tSteps or item 3 of tData < sPianoLow or item 3 of tData > sPianoLow + kKeys - 1 then
      set the visible of graphic tNote to false
      exit btDrawNote
   end if
   put btPitchY(item 3 of tData) into tTop
   set the rect of graphic tNote to btPianoX(item 1 of tData) + 1, tTop + 1, \
         min(kPianoLeft + kPianoWidth, btPianoX(item 1 of tData + item 2 of tData)) - 1, tTop + kKeyH - 1
   if btAudible(sPianoCh) then
      set the backgroundColor of graphic tNote to item sPianoCh of kColors
   else
      set the backgroundColor of graphic tNote to kDim
   end if
   set the blendLevel of graphic tNote to (9 - item 4 of tData) * 7
   set the visible of graphic tNote to true
end btDrawNote

----------------------------------------------------------------------
-- The mixer
----------------------------------------------------------------------

command btDrawMixer
   local n, tShow, tName
   lock screen
   repeat with n = 1 to kMaxChannels
      put n <= sSong["chans"] into tShow
      repeat for each item tName in "mxsw,mxname,cut,cutfill,rev,revfill,dly,dlyfill,mxpan,mxpanfill,meterbg,fader,faderfill,fadercap,mxvol,mxtune"
         if tName is "mxname" or tName is "mxvol" or tName is "mxtune" then
            set the visible of field (tName && n) to tShow
         else
            set the visible of graphic (tName && n) to tShow
         end if
      end repeat
      set the visible of button ("mxmute" && n) to tShow
      set the visible of button ("mxsolo" && n) to tShow
      if tShow then
         btDrawStrip n
      else
         set the visible of graphic ("meter" && n) to false
      end if
   end repeat
   btDrawMaster
   unlock screen
end btDrawMixer

-- A channel's strip: its name, its filter, sends and pan, its fader and
-- its volume, mute, solo and tuning.
command btDrawStrip pRow
   local tColor, tTune
   lock screen
   put item pRow of kColors into tColor
   set the backgroundColor of graphic ("mxsw" && pRow) to tColor
   set the text of field ("mxname" && pRow) to btSoundName(sSong["ch"][pRow]["sound"])
   if btAudible(pRow) then
      set the textColor of field ("mxname" && pRow) to kInk
   else
      set the textColor of field ("mxname" && pRow) to kDim
   end if
   btHFill "cut" && pRow, "cutfill" && pRow, sSong["ch"][pRow]["cut"], 100, tColor
   btHFill "rev" && pRow, "revfill" && pRow, sSong["ch"][pRow]["rev"], 100, tColor
   btHFill "dly" && pRow, "dlyfill" && pRow, sSong["ch"][pRow]["dly"], 100, tColor
   btPanFill "mxpan" && pRow, "mxpanfill" && pRow, sSong["ch"][pRow]["pan"], tColor
   btVFill "fader" && pRow, "faderfill" && pRow, sSong["ch"][pRow]["vol"], tColor
   set the loc of graphic ("fadercap" && pRow) to item 1 of the loc of graphic ("fader" && pRow), \
         kFaderBottom - round((kFaderBottom - kFaderTop) * sSong["ch"][pRow]["vol"] / 100)
   set the text of field ("mxvol" && pRow) to sSong["ch"][pRow]["vol"]
   btLightSmall "mxmute" && pRow, sSong["ch"][pRow]["mute"], kEmber
   btLightSmall "mxsolo" && pRow, sSong["ch"][pRow]["solo"], kAmber
   put sSong["ch"][pRow]["tune"] into tTune
   if tTune > 0 then
      put "+" before tTune
   end if
   set the text of field ("mxtune" && pRow) to tTune
   unlock screen
end btDrawStrip

-- The master's fader, the reverb's room and the delay's time and
-- feedback.
command btDrawMaster
   lock screen
   btVFill "fader 0", "faderfill 0", sSong["master"]["vol"], kAmber
   set the loc of graphic "fadercap 0" to item 1 of the loc of graphic "fader 0", \
         kFaderBottom - round((kFaderBottom - kFaderTop) * sSong["master"]["vol"] / 100)
   set the text of field "mxvol 0" to sSong["master"]["vol"]
   btLight "Reverb Room", sSong["master"]["size"] is 0
   btLight "Reverb Hall", sSong["master"]["size"] is 1
   btLight "Delay 2", sSong["master"]["dly"] is 2
   btLight "Delay 3", sSong["master"]["dly"] is 3
   btLight "Delay 4", sSong["master"]["dly"] is 4
   btHFill "fb", "fbfill", sSong["master"]["fb"], 90, kAmber
   set the text of field "fbValue" to sSong["master"]["fb"] & "%"
   unlock screen
end btDrawMaster

-- The meters, from the page's levels (0..100, a channel an item and the
-- master last); empty: all down.
command btDrawMeters pLevels
   local n, tLevel, tColor
   if there is not a graphic "meter 0" then
      exit btDrawMeters
   end if
   lock screen
   repeat with n = 0 to sSong["chans"]
      if n is 0 then
         put item sSong["chans"] + 1 of pLevels into tLevel
      else
         put item n of pLevels into tLevel
      end if
      if tLevel is not a number then
         put 0 into tLevel
      end if
      if tLevel > 92 then
         put kEmber into tColor
      else if tLevel > 80 then
         put kAmber into tColor
      else
         put kMeter into tColor
      end if
      btVFill "meterbg" && n, "meter" && n, tLevel, tColor
   end repeat
   unlock screen
end btDrawMeters

----------------------------------------------------------------------
-- The playheads
----------------------------------------------------------------------

-- The step playing (from 1: of the pattern in Pattern mode, of the song
-- in Song mode; 0 stopped), shown in the view shown: on the pattern's
-- steps, if the pattern shown is the one playing, and on the playlist,
-- which follows it to the bars it plays.
command btShowStep pStep
   local tSteps, tCur, tPos, tX
   lock screen
   put pStep into sStep
   put 0 into tCur
   put sSong["pat"][sSong["cur"]]["steps"] into tSteps
   if pStep >= 1 then
      if sSong["mode"] is "song" then
         put btCurStepAt(pStep) into tCur
      else if pStep <= tSteps then
         put pStep into tCur
      end if
   end if
   switch sView
      case "rack"
         if tCur >= 1 then
            set the rect of graphic "Head" to btPadLeft(tCur, tSteps) - 2, the top of graphic "Head", \
                  btPadRight(tCur, tSteps) + 2, the bottom of graphic "Head"
         end if
         set the visible of graphic "Head" to tCur >= 1
         break
      case "piano"
         if tCur >= 1 then
            set the rect of graphic "PianoHead" to btPianoX(tCur), kKeyTop, btPianoX(tCur) + 2, kKeyTop + kKeys * kKeyH
         end if
         set the visible of graphic "PianoHead" to tCur >= 1
         break
      case "song"
         if pStep >= 1 and sSong["mode"] is "song" then
            put 1 + (pStep - 1) / 16 into tPos
            if tPos < sSongView or tPos >= sSongView + kViewBars then
               btSetSongView (trunc(tPos - 1) div 16) * 16 + 1
            end if
            put kSongLeft + round((tPos - sSongView) * kSongWidth / kViewBars) into tX
            set the rect of graphic "SongHead" to tX, kRulerTop, tX + 2, kTrackTop + kTracks * kTrackH - 4
            set the visible of graphic "SongHead" to true
         else
            set the visible of graphic "SongHead" to false
         end if
         break
   end switch
   unlock screen
end btShowStep

----------------------------------------------------------------------
-- The sound picker and the File menu
----------------------------------------------------------------------

-- The picker, over the rack, for one channel: the kit, the synths and
-- the user's samples (an empty slot loads one), the sound it plays lit.
command btOpenPicker pRow
   local i, tName
   if not btIsChannel(pRow) then
      exit btOpenPicker
   end if
   btCloseMenu
   put pRow into sPicker
   set the text of field "Picker Title" to "Channel" && pRow & ": choose a sound"
   repeat with i = 1 to kSounds
      if i >= kFirstUser then
         put sSong["user"][i - kFirstUser + 1]["name"] into tName
         if tName is empty then
            put "+ load" into tName
         end if
         set the label of button ("pick" && i) to tName
      end if
      btLight "pick" && i, i is sSong["ch"][pRow]["sound"]
      if i is not sSong["ch"][pRow]["sound"] then
         set the textColor of button ("pick" && i) to kInk
      end if
   end repeat
   set the visible of group "Picker" to true
end btOpenPicker

command btClosePicker
   put empty into sPicker
   set the visible of group "Picker" to false
end btClosePicker

command btOpenMenu
   if sPicker is not empty then
      btClosePicker
   end if
   put "file" into sMenu
   put false into sNewArmed
   set the label of button "New" to "New empty song"
   set the visible of group "Files" to true
   btLight "File", true
end btOpenMenu

command btCloseMenu
   put empty into sMenu
   if sNewArmed then
      put false into sNewArmed
      set the label of button "New" to "New empty song"
   end if
   set the visible of group "Files" to false
   btLight "File", false
   set the textColor of button "File" to kInk
end btCloseMenu

----------------------------------------------------------------------
-- Layout: every control's place (the builder calls it once)
----------------------------------------------------------------------

command btLayout
   local n, s, tY, i, tX, t, b, k, tL
   lock screen
   -- each view clips to the panel and keeps its place as its controls
   -- move. This comes first: a group whose rect is moved carries its
   -- controls with it, so set after them it would shift every one
   repeat for each item tL in "View Rack,View Piano,View Song,View Mixer"
      set the lockLoc of group tL to true
      set the rect of group tL to 192, 68, 952, 560
   end repeat

   -- the top bar
   set the rect of graphic "Bar" to 0, 0, 960, 60
   set the rect of field "Logo" to 14, 8, 176, 52
   set the rect of button "Play" to 186, 12, 262, 48
   set the rect of button "Mode Pattern" to 272, 17, 334, 43
   set the rect of button "Mode Song" to 336, 17, 388, 43
   set the rect of field "Tempo Label" to 400, 21, 444, 43
   set the rect of button "Tempo Down" to 446, 17, 470, 43
   set the rect of field "Tempo" to 472, 15, 518, 45
   set the rect of button "Tempo Up" to 520, 17, 544, 43
   set the rect of field "Swing Label" to 554, 21, 598, 43
   set the rect of graphic "Swing Track" to 602, 27, 682, 33
   set the rect of graphic "Swing Fill" to 602, 27, 603, 33
   set the rect of graphic "Swing Knob" to 0, 0, 16, 16
   set the rect of field "Swing Value" to 688, 21, 732, 43
   set the rect of button "Undo" to 748, 15, 806, 45
   set the rect of button "Redo" to 810, 15, 868, 45
   set the rect of button "File" to 880, 15, 950, 45

   -- the pattern list
   set the rect of graphic "Side" to 10, 68, 182, 560
   set the rect of field "Patterns Label" to 20, 74, 172, 96
   repeat with i = 1 to kMaxPatterns
      put 100 + (i - 1) * 22 into tY
      set the rect of graphic ("pswatch" && i) to 18, tY + 5, 24, tY + 17
      set the backgroundColor of graphic ("pswatch" && i) to item i of kPatColors
   end repeat
   set the rect of field "Patterns" to 28, 100, 174, 466
   set the rect of button "Pattern New" to 18, 474, 94, 502
   set the rect of button "Pattern Clone" to 98, 474, 174, 502
   set the rect of button "Pattern Clear" to 18, 508, 94, 536
   set the rect of button "Pattern Delete" to 98, 508, 174, 536
   set the rect of field "Patterns Hint" to 18, 538, 174, 556

   -- the main panel: its tabs, and a view over it at a time
   set the rect of graphic "Rack" to 192, 68, 952, 560
   set the rect of button "Tab Rack" to 202, 74, 290, 98
   set the rect of button "Tab Piano" to 294, 74, 382, 98
   set the rect of button "Tab Song" to 386, 74, 466, 98
   set the rect of button "Tab Mixer" to 470, 74, 536, 98
   set the rect of field "Steps Label" to 800, 76, 846, 96
   set the rect of button "Steps 16" to 850, 74, 890, 98
   set the rect of button "Steps 32" to 894, 74, 934, 98

   -- the rack: twelve rows of a channel's sound and levels, and its pads
   set the rect of field "Vol Label" to 374, 100, 436, 116
   set the rect of field "Pan Label" to 444, 100, 492, 116
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
   repeat with s = 1 to kMaxSteps
      set the rect of graphic ("dot" && s) to btPadLeft(s, 16), kRowTop - 12, btPadRight(s, 16), kRowTop - 8
   end repeat
   set the rect of graphic "Chosen" to 196, kRowTop + 4, 199, kRowTop + kPadH - 4
   set the rect of button "Add Channel" to 212, kRowTop, 368, kRowTop + 26
   set the rect of graphic "Head" to kGridLeft - 2, kRowTop - 4, kGridLeft + 26, kRowTop + 100

   -- the playlist: the ruler, eight tracks of 32 bars, the playhead
   set the rect of field "Bars Label" to 700, 76, 846, 96
   set the rect of button "Bars Back" to 850, 74, 890, 98
   set the rect of button "Bars On" to 894, 74, 934, 98
   set the rect of field "Ruler Label" to 204, kRulerTop, 262, kRulerTop + 18
   set the rect of graphic "Ruler" to kSongLeft, kRulerTop, kSongLeft + kSongWidth, kRulerTop + 18
   repeat with b = 1 to kViewBars
      put kSongLeft + round((b - 1) * kSongWidth / kViewBars) into tX
      set the rect of field ("barno" && b) to tX, kRulerTop, tX + 30, kRulerTop + 18
   end repeat
   set the rect of graphic "StartMark" to kSongLeft, kRulerTop, kSongLeft + 6, kRulerTop + 18
   repeat with t = 1 to kTracks
      put kTrackTop + (t - 1) * kTrackH into tY
      set the rect of field ("trk" && t) to 204, tY + 13, 262, tY + 33
      repeat with b = 1 to kViewBars
         set the rect of graphic ("cell" && t & comma & b) to kSongLeft + round((b - 1) * kSongWidth / kViewBars), tY, \
               kSongLeft + round(b * kSongWidth / kViewBars) - 2, tY + kCellH
      end repeat
   end repeat
   set the rect of graphic "SongHead" to kSongLeft, kRulerTop, kSongLeft + 2, kTrackTop + kTracks * kTrackH - 4
   set the rect of field "Song Hint" to 204, 532, 800, 556
   set the rect of field "Song Length" to 800, 532, 944, 556

   -- the piano roll: its channel and octaves, the keys and the grid
   set the rect of button "Piano Prev" to 204, 102, 228, 124
   set the rect of field "Piano Chan" to 232, 102, 420, 124
   set the rect of button "Piano Next" to 424, 102, 448, 124
   set the rect of button "Oct Down" to 462, 102, 486, 124
   set the rect of field "Oct Label" to 490, 102, 590, 124
   set the rect of button "Oct Up" to 594, 102, 618, 124
   set the rect of field "Piano Info" to 630, 102, 944, 124
   repeat with k = 1 to kKeys
      put kKeyTop + (kKeys - k) * kKeyH into tY
      set the rect of graphic ("key" && k) to 204, tY, 246, tY + kKeyH - 1
      set the rect of graphic ("lane" && k) to kPianoLeft, tY, kPianoLeft + kPianoWidth, tY + kKeyH - 1
   end repeat
   repeat with s = 1 to kMaxSteps
      put kPianoLeft + round((s - 1) * kPianoWidth / 16) into tX
      set the rect of graphic ("pline" && s) to tX, kKeyTop, tX + 1, kKeyTop + kKeys * kKeyH
   end repeat
   repeat with i = 1 to kMaxNotes
      set the rect of graphic ("note" && i) to kPianoLeft, kKeyTop, kPianoLeft + 20, kKeyTop + kKeyH - 2
      set the visible of graphic ("note" && i) to false
   end repeat
   set the rect of graphic "PianoHead" to kPianoLeft, kKeyTop, kPianoLeft + 2, kKeyTop + kKeys * kKeyH
   set the rect of field "Piano Hint" to 204, 538, 944, 556

   -- the mixer: the names of its rows, a strip a channel, the master's,
   -- and the reverb's and the delay's settings
   set the rect of field "Label Filter" to 196, 137, 246, 161
   set the rect of field "Label Reverb" to 196, 161, 246, 185
   set the rect of field "Label Delay" to 196, 185, 246, 209
   set the rect of field "Label Pan" to 196, 209, 246, 233
   set the rect of field "Label Volume" to 196, 317, 246, 341
   set the rect of field "Label Tune" to 196, 467, 246, 491
   repeat with n = 1 to kMaxChannels
      put kStripLeft + (n - 1) * kStripW into tL
      set the rect of graphic ("mxsw" && n) to tL, 104, tL + 48, 107
      set the rect of field ("mxname" && n) to tL - 1, 108, tL + 49, 142
      set the rect of graphic ("cut" && n) to tL + 4, 145, tL + 44, 153
      set the rect of graphic ("cutfill" && n) to tL + 4, 145, tL + 6, 153
      set the rect of graphic ("rev" && n) to tL + 4, 169, tL + 44, 177
      set the rect of graphic ("revfill" && n) to tL + 4, 169, tL + 6, 177
      set the rect of graphic ("dly" && n) to tL + 4, 193, tL + 44, 201
      set the rect of graphic ("dlyfill" && n) to tL + 4, 193, tL + 6, 201
      set the rect of graphic ("mxpan" && n) to tL + 4, 217, tL + 44, 225
      set the rect of graphic ("mxpanfill" && n) to tL + 23, 217, tL + 25, 225
      set the rect of graphic ("meterbg" && n) to tL + 8, kFaderTop, tL + 14, kFaderBottom
      set the rect of graphic ("meter" && n) to tL + 8, kFaderBottom - 2, tL + 14, kFaderBottom
      set the rect of graphic ("fader" && n) to tL + 24, kFaderTop, tL + 34, kFaderBottom
      set the rect of graphic ("faderfill" && n) to tL + 24, kFaderBottom - 2, tL + 34, kFaderBottom
      set the rect of graphic ("fadercap" && n) to tL + 17, kFaderTop - 5, tL + 41, kFaderTop + 5
      set the rect of field ("mxvol" && n) to tL, 424, tL + 48, 440
      set the rect of button ("mxmute" && n) to tL + 2, 446, tL + 23, 466
      set the rect of button ("mxsolo" && n) to tL + 25, 446, tL + 46, 466
      set the rect of field ("mxtune" && n) to tL, 470, tL + 48, 488
   end repeat
   set the rect of field "Master Label" to 880, 110, 944, 128
   set the rect of graphic "meterbg 0" to 890, kFaderTop, 896, kFaderBottom
   set the rect of graphic "meter 0" to 890, kFaderBottom - 2, 896, kFaderBottom
   set the rect of graphic "fader 0" to 906, kFaderTop, 916, kFaderBottom
   set the rect of graphic "faderfill 0" to 906, kFaderBottom - 2, 916, kFaderBottom
   set the rect of graphic "fadercap 0" to 899, kFaderTop - 5, 923, kFaderTop + 5
   set the rect of field "mxvol 0" to 880, 424, 944, 440
   set the rect of field "Reverb Label" to 204, 504, 256, 526
   set the rect of button "Reverb Room" to 258, 500, 318, 528
   set the rect of button "Reverb Hall" to 322, 500, 382, 528
   set the rect of field "Delay Label" to 398, 504, 444, 526
   set the rect of button "Delay 2" to 446, 500, 486, 528
   set the rect of button "Delay 3" to 490, 500, 530, 528
   set the rect of button "Delay 4" to 534, 500, 574, 528
   set the rect of field "Feedback Label" to 590, 504, 660, 526
   set the rect of graphic "fb" to 664, 510, 764, 518
   set the rect of graphic "fbfill" to 664, 510, 666, 518
   set the rect of field "fbValue" to 770, 504, 820, 526
   set the rect of field "Mixer Hint" to 204, 536, 944, 556

   set the rect of field "Status" to 14, 568, 946, 594

   -- the picker: a title, the kit in four columns, the synths in a row,
   -- the user's samples, and Load and Remove
   set the rect of graphic "Picker Back" to 204, 104, 628, 468
   set the rect of field "Picker Title" to 216, 112, 616, 134
   set the rect of field "Pick Kit Label" to 216, 138, 616, 154
   repeat with i = 1 to kKitSize
      put 216 + ((i - 1) mod 4) * 102 into tX
      put 158 + ((i - 1) div 4) * 32 into tY
      set the rect of button ("pick" && i) to tX, tY, tX + 96, tY + 28
   end repeat
   set the rect of field "Pick Synth Label" to 216, 288, 616, 304
   repeat with i = kFirstSynth to kFirstUser - 1
      put 216 + (i - kFirstSynth) * 81 into tX
      set the rect of button ("pick" && i) to tX, 308, tX + 77, 336
   end repeat
   set the rect of field "Pick User Label" to 216, 342, 616, 358
   repeat with i = kFirstUser to kSounds
      put 216 + ((i - kFirstUser) mod 4) * 102 into tX
      put 362 + ((i - kFirstUser) div 4) * 32 into tY
      set the rect of button ("pick" && i) to tX, tY, tX + 96, tY + 28
   end repeat
   set the rect of button "Pick Load" to 216, 430, 410, 458
   set the rect of button "Pick Remove" to 414, 430, 616, 458
   set the visible of group "Picker" to false

   -- the File menu, under its button
   set the rect of graphic "Files Back" to 712, 50, 952, 260
   put 0 into i
   repeat for each item tL in "File Open,File Save,File Export,File Sample,New,Demo"
      add 1 to i
      set the rect of button tL to 722, 58 + (i - 1) * 32, 942, 86 + (i - 1) * 32
   end repeat
   set the visible of group "Files" to false
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
   btStop
   put empty into sSong
   btReset
   if not btLoad() then
      btDemoSong true
   end if
   btUndoReset
   btShowView "rack"
end btTestBegin

command btTestEnd
   btStop
   if sExportTimer is not empty then
      cancel sExportTimer
   end if
   put empty into sExportTimer
   if sSaveTimer is not empty then
      cancel sSaveTimer
   end if
   put empty into sSaveTimer
   put false into sTest
   put empty into sSaveFile
   put empty into sSong
end btTestEnd

-- How things are: "bpm", "swing", "cur", "chans", "pats", "mode",
-- "from", "steps", "playing", "step", "picker", "menu", "view",
-- "text" (the file's text), "json" (what the page is told), "row n",
-- "notes n" (in the pattern shown), "sound n", "vol n", "pan n", "mute n",
-- "solo n", "cut n", "rev n", "dly n", "tune n", "audible n", "name p",
-- "master vol|size|dly|fb", "block t b" (the pattern at bar b of track t),
-- "track t" ("bar:pattern,..."), "songsteps", "pianoch", "pianolow",
-- "notelen", "songview", "undo" ("at/top"), "user slot", "file slot".
function btState pWhat
   local tN, tAt, tText
   put word 2 of pWhat into tN
   switch word 1 of pWhat
      case "bpm"
      case "swing"
      case "cur"
      case "chans"
      case "pats"
      case "mode"
      case "from"
         return sSong[word 1 of pWhat]
      case "steps"
         return sSong["pat"][sSong["cur"]]["steps"]
      case "playing"
         return sPlaying
      case "step"
         return sStep
      case "picker"
         return sPicker
      case "menu"
         return sMenu
      case "view"
         return sView
      case "text"
         return btSongText()
      case "json"
         return btSongJson()
      case "row"
         return sSong["pat"][sSong["cur"]]["rows"][tN]
      case "notes"
         return sSong["pat"][sSong["cur"]]["notes"][tN]
      case "sound"
      case "vol"
      case "pan"
      case "mute"
      case "solo"
      case "cut"
      case "rev"
      case "dly"
      case "tune"
         return sSong["ch"][tN][word 1 of pWhat]
      case "audible"
         return btAudible(tN)
      case "name"
         return sSong["pat"][tN]["name"]
      case "master"
         return sSong["master"][tN]
      case "block"
         put btBlockAt(tN, word 3 of pWhat) into tAt
         return item 2 of tAt
      case "track"
         put line (tN + 0) of btTrackLines() into tText
         return tText
      case "songsteps"
         return btSongSteps()
      case "pianoch"
         return sPianoCh
      case "pianolow"
         return sPianoLow
      case "notelen"
         return sNoteLen
      case "songview"
         return sSongView
      case "undo"
         return sUndoAt & "/" & sUndoTop
      case "user"
         return sSong["user"][tN]["name"]
      case "file"
         -- the file of a slot's sample, or empty
         if sSong["user"][tN]["name"] is empty then
            return empty
         end if
         return btSampleFile(tN)
   end switch
   return empty
end btState

-- each track's blocks, a line a track: "bar:pattern,..." in bar order
function btTrackLines
   local t, tKeys, b, tLine, tText
   repeat with t = 1 to kTracks
      put the keys of sSong["track"][t] into tKeys
      sort lines of tKeys numeric
      put empty into tLine
      repeat for each line b in tKeys
         put b & ":" & sSong["track"][t][b] & comma after tLine
      end repeat
      delete the last char of tLine
      put tLine & return after tText
   end repeat
   return tText
end btTrackLines

-- Loads a song from its text, as opening the stack does from its file.
function btTestRead pText
   local tOk
   put btReadSong(pText) into tOk
   if tOk then
      btDrawAll
   end if
   return tOk
end btTestRead
