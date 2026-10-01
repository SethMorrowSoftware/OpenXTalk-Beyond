script "VLCPlayerCheck"

-- Automatic check of the player backend (engine/src/vlc-player.cpp), run in
-- the IDE: the engine crashes creating a player in -ui mode, with either
-- backend, so this cannot run headless. Use run-player-check.ps1, which sets
-- OXT_PLAYER_FILE (the media) and OXT_PLAYER_LOG (where PASS/FAIL/INFO lines
-- and a final SUMMARY line go), opens this stack in OXT-Beyond, and closes
-- OXT-Beyond when the summary appears.

local sPasses, sFails, sEvents

command check pName, pOK, pDetail
   if pOK then
      add 1 to sPasses
      emit "PASS " & pName & ": " & pDetail
   else
      add 1 to sFails
      emit "FAIL " & pName & ": " & pDetail
   end if
end check

command info pText
   emit "INFO " & pText
end info

-- Also appends to OXT_PLAYER_LOG, if set, so that a crash loses nothing.
command emit pLine
   write pLine & return to stdout
   if $OXT_PLAYER_LOG is not empty then
      put pLine & return after url ("file:" & $OXT_PLAYER_LOG)
   end if
end emit

-- Mean brightness and a checksum of the player as the engine draws it.
function snapshotStats
   local tPNG, tData, tSum, tCount, tHash
   export snapshot from player "Video" of card 1 of stack "VLCPlayerCheck" to tPNG as PNG
   set the text of image "Shot" of card 1 of stack "VLCPlayerCheck" to tPNG
   put the imageData of image "Shot" of card 1 of stack "VLCPlayerCheck" into tData
   repeat with i = 1 to the number of bytes of tData step 4 * 97
      add byteToNum(byte i + 1 of tData) + byteToNum(byte i + 2 of tData) + byteToNum(byte i + 3 of tData) to tSum
      add 3 to tCount
   end repeat
   put md5Digest(tData) into tHash
   if tCount is 0 then return "0," & tHash
   return round(tSum / tCount, 1) & "," & tHash
end snapshotStats

command waitFor pMilliseconds
   wait pMilliseconds milliseconds with messages
end waitFor

on openStack
   -- Let the IDE finish starting first.
   send "runChecks" to me in 1 second
end openStack

command runChecks
   local tFile, tScale, tDuration, tTime, tTime2, tShot1, tShot2, tShot3, tStart
   put 0 into sPasses
   put 0 into sFails

   -- Engine paths use slashes; the player's filename resolution needs them.
   put $OXT_PLAYER_FILE into tFile
   replace "\" with "/" in tFile
   if tFile is empty or there is no file tFile then
      check "media file", false, "set OXT_PLAYER_FILE to a video file (got '" & tFile & "')"
      emit "SUMMARY passed=" & sPasses & " failed=" & sFails
      exit runChecks
   end if

   set the rect of me to 100,100,700,500
   set the defaultStack to the short name of me
   create player "Video"
   set the rect of player "Video" to 0,0,520,320
   set the showController of player "Video" to false
   create image "Shot"

   put the milliseconds into tStart
   set the filename of player "Video" to tFile
   info "filename set in" && the milliseconds - tStart && "ms; the result:" && the result
   waitFor 1500

   put the timeScale of player "Video" into tScale
   put the duration of player "Video" into tDuration
   check "libVLC backend", tScale is 1000, "timeScale" && tScale && "(1000 = libVLC, 10000000 = DirectShow)"
   check "duration", tDuration > 0, tDuration && "units"
   check "size", the formattedWidth of player "Video" > 0, the formattedWidth of player "Video" & "x" & the formattedHeight of player "Video"
   info "mediaTypes:" && the mediaTypes of player "Video" && "trackCount:" && the trackCount of player "Video" && "tracks:" && replaceText(the tracks of player "Video", return, " | ")
   info "enabledTracks:" && replaceText(the enabledTracks of player "Video", return, ",")

   put snapshotStats() into tShot1
   check "first frame before playing", item 1 of tShot1 > 5, "mean brightness" && item 1 of tShot1

   -- Play
   set the callbacks of player "Video" to (tScale div 2) & ",cbHalfSecond"
   put empty into sEvents
   start player "Video"
   waitFor 2000
   put the currentTime of player "Video" into tTime
   check "plays", tTime >= tScale and tTime <= 3 * tScale, "currentTime after 2 s:" && tTime
   check "playStarted sent", "playStarted" is among the lines of sEvents, replaceText(sEvents, return, ",")
   check "callback at 0.5 s", "cbHalfSecond" is among the lines of sEvents, replaceText(sEvents, return, ",")
   check "currentTimeChanged sent", "currentTimeChanged" is among the lines of sEvents, ""
   put snapshotStats() into tShot2
   check "frames while playing", item 2 of tShot2 is not item 2 of tShot1, "snapshot changed; brightness" && item 1 of tShot2

   -- Pause, then seek while paused
   stop player "Video"
   waitFor 300
   put the currentTime of player "Video" into tTime
   waitFor 500
   check "pauses", the currentTime of player "Video" is tTime, "currentTime stays" && tTime
   set the currentTime of player "Video" to tDuration div 2
   waitFor 600
   put snapshotStats() into tShot3
   check "seek while paused shows the frame", item 2 of tShot3 is not item 2 of tShot2, "brightness" && item 1 of tShot3
   check "seek while paused keeps the time", the currentTime of player "Video" is tDuration div 2, the currentTime of player "Video"
   check "still paused after seek", the paused of player "Video", "paused:" && the paused of player "Video"

   -- Mirrored
   set the mirrored of player "Video" to true
   waitFor 200
   check "mirrored", item 2 of snapshotStats() is not item 2 of tShot3, "snapshot changed"
   set the mirrored of player "Video" to false

   -- Rate 2
   set the playRate of player "Video" to 2
   start player "Video"
   put the currentTime of player "Video" into tTime
   waitFor 1000
   put the currentTime of player "Video" into tTime2
   check "playRate 2", tTime2 - tTime >= 1.5 * tScale, "advanced" && tTime2 - tTime && "in 1 s"
   stop player "Video"
   set the playRate of player "Video" to 1

   -- Play to the end
   put empty into sEvents
   set the currentTime of player "Video" to max(0, tDuration - tScale)
   waitFor 300
   start player "Video"
   waitFor 2500
   check "finishes", "playStopped" is among the lines of sEvents, replaceText(sEvents, return, ",")
   check "not playing after the end", the paused of player "Video", "paused:" && the paused of player "Video" && "currentTime" && the currentTime of player "Video"

   -- Start again after the end
   start player "Video"
   waitFor 1000
   put the currentTime of player "Video" into tTime
   check "plays again from the start", tTime > 0 and tTime < 2 * tScale, "currentTime" && tTime
   stop player "Video"

   -- Play selection
   put empty into sEvents
   set the startTime of player "Video" to tScale
   set the endTime of player "Video" to 2 * tScale
   set the playSelection of player "Video" to true
   set the currentTime of player "Video" to tScale
   waitFor 300
   start player "Video"
   waitFor 1800
   put the currentTime of player "Video" into tTime
   check "play selection stops at its end", the paused of player "Video" and abs(tTime - 2 * tScale) <= tScale div 5, "currentTime" && tTime && "events" && replaceText(sEvents, return, ",")
   set the playSelection of player "Video" to false

   -- Replace the file
   set the filename of player "Video" to empty
   check "empty filename", the duration of player "Video" is 0, "duration" && the duration of player "Video"

   emit "SUMMARY passed=" & sPasses & " failed=" & sFails
end runChecks

command noteEvent pName
   if pName is not among the lines of sEvents then
      put pName & return after sEvents
   end if
end noteEvent

on playStarted
   noteEvent "playStarted"
   pass playStarted
end playStarted

on playStopped
   noteEvent "playStopped"
   pass playStopped
end playStopped

on playPaused
   noteEvent "playPaused"
   pass playPaused
end playPaused

on currentTimeChanged
   noteEvent "currentTimeChanged"
   pass currentTimeChanged
end currentTimeChanged

on cbHalfSecond
   noteEvent "cbHalfSecond"
end cbHalfSecond
