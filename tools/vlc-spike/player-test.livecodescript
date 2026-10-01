script "VLCPlayerTest"

-- Manual test stack for the libVLC player backend (engine/src/vlc-player.cpp).
-- Open it in OXT-Beyond with File > Open Stack...; it creates its controls
-- each time it opens. To compare with the DirectShow player, start
-- OXT-Beyond with the environment variable OXT_PLAYER_BACKEND=directshow.

constant kSample = "C:/Users/sethc/Desktop/winoxt-vlc/ide/Resources/Examples/neville-segments.mp4"
constant kButtons = "Load sample,Open file...,Play,Pause,Step +1,Step -1,Seek 50%,Rate 0.5,Rate 1,Rate 2,Loop on/off,Mirror on/off,AlwaysBuffer on/off,Overlay on/off,Volume 30/100,Play selection 5-10 s,Callbacks every 5 s,Snapshot,Info,Clear log"

local sTimeChanged

on preOpenStack
   set the title of me to "VLC player test"
   set the rect of me to 100,100,1060,800
   if there is no player "Video" of card 1 of me then
      buildControls
   end if
end preOpenStack

command buildControls
   local tTop, tLabel
   lock screen
   set the defaultStack to the short name of me

   create player "Video"
   set the rect of player "Video" to 20,20,660,420
   set the showController of player "Video" to true

   -- Drawn over the video: only possible when the engine draws the video.
   create graphic "Overlay"
   set the style of graphic "Overlay" to "rectangle"
   set the filled of graphic "Overlay" to true
   set the backgroundColor of graphic "Overlay" to "255,128,0"
   set the blendLevel of graphic "Overlay" to 50
   set the rect of graphic "Overlay" to 40,40,240,140
   set the visible of graphic "Overlay" to false

   create field "Log"
   set the rect of field "Log" to 20,430,660,690
   set the vScrollbar of field "Log" to true
   set the textSize of field "Log" to 11

   create image "Snapshot"
   set the rect of image "Snapshot" to 680,580,940,690
   set the lockLoc of image "Snapshot" to true

   put 20 into tTop
   repeat for each item tLabel in kButtons
      create button tLabel
      set the rect of button tLabel to 680, tTop, 940, tTop + 24
      set the script of button tLabel to "on mouseUp" & return & "   testAction the short name of me" & return & "end mouseUp"
      add 27 to tTop
   end repeat
   unlock screen
end buildControls

command testAction pAction
   local tScale, tFile
   set the defaultStack to the short name of me
   switch pAction
      case "Load sample"
         loadFile kSample
         break
      case "Open file..."
         answer file "Choose a video or audio file"
         put it into tFile
         if tFile is not empty then
            loadFile tFile
         end if
         break
      case "Play"
         start player "Video"
         break
      case "Pause"
         stop player "Video"
         break
      case "Step +1"
         stepBy 1
         break
      case "Step -1"
         stepBy -1
         break
      case "Seek 50%"
         set the currentTime of player "Video" to the duration of player "Video" div 2
         logLine "currentTime set to" && the currentTime of player "Video"
         break
      case "Rate 0.5"
         set the playRate of player "Video" to 0.5
         break
      case "Rate 1"
         set the playRate of player "Video" to 1
         break
      case "Rate 2"
         set the playRate of player "Video" to 2
         break
      case "Loop on/off"
         set the looping of player "Video" to not the looping of player "Video"
         logLine "looping" && the looping of player "Video"
         break
      case "Mirror on/off"
         set the mirrored of player "Video" to not the mirrored of player "Video"
         logLine "mirrored" && the mirrored of player "Video"
         break
      case "AlwaysBuffer on/off"
         set the alwaysBuffer of player "Video" to not the alwaysBuffer of player "Video"
         logLine "alwaysBuffer" && the alwaysBuffer of player "Video"
         break
      case "Overlay on/off"
         set the visible of graphic "Overlay" to not the visible of graphic "Overlay"
         break
      case "Volume 30/100"
         if the playLoudness of player "Video" is 100 then
            set the playLoudness of player "Video" to 30
         else
            set the playLoudness of player "Video" to 100
         end if
         logLine "playLoudness" && the playLoudness of player "Video"
         break
      case "Play selection 5-10 s"
         put the timeScale of player "Video" into tScale
         set the startTime of player "Video" to 5 * tScale
         set the endTime of player "Video" to 10 * tScale
         set the showSelection of player "Video" to true
         set the playSelection of player "Video" to true
         set the currentTime of player "Video" to 5 * tScale
         start player "Video"
         logLine "playing the selection 5-10 s; it should stop at 10 s"
         break
      case "Callbacks every 5 s"
         setupCallbacks
         break
      case "Snapshot"
         takeSnapshot
         break
      case "Info"
         showInfo
         break
      case "Clear log"
         put empty into field "Log"
         break
   end switch
end testAction

command loadFile pPath
   local tStart, tWidth, tHeight, tFactor
   put the milliseconds into tStart
   set the filename of player "Video" to pPath
   logLine "loaded in" && the milliseconds - tStart && "ms; the result:" && the result

   -- Fit the video into the area, keeping its shape; 26 is the controller.
   put the formattedWidth of player "Video" into tWidth
   put the formattedHeight of player "Video" into tHeight
   if tWidth > 0 and tHeight > 0 then
      put min(640 / tWidth, 374 / tHeight) into tFactor
      set the width of player "Video" to round(tWidth * tFactor)
      set the height of player "Video" to round(tHeight * tFactor) + 26
      set the topLeft of player "Video" to 20,20
   end if
   showInfo
end loadFile

command stepBy pFrames
   local tScale
   put the timeScale of player "Video" into tScale
   set the currentTime of player "Video" to max(0, the currentTime of player "Video" + pFrames * round(tScale / 30))
   logLine "stepped to" && the currentTime of player "Video"
end stepBy

command setupCallbacks
   local tScale, tSeconds, tList, tSecond
   put the timeScale of player "Video" into tScale
   put the duration of player "Video" / tScale into tSeconds
   repeat with tSecond = 5 to tSeconds step 5
      put tSecond * tScale & ",playerCallback" & return after tList
   end repeat
   delete the last char of tList
   set the callbacks of player "Video" to tList
   logLine "callbacks set:" && the number of lines of tList
end setupCallbacks

command takeSnapshot
   local tData
   -- Renders the player through the engine, as printing and effects do.
   export snapshot from player "Video" to tData as PNG
   set the text of image "Snapshot" to tData
   logLine "snapshot: the video should appear below the buttons"
end takeSnapshot

command showInfo
   logLine "duration" && the duration of player "Video" && "timeScale" && the timeScale of player "Video" \
         && "currentTime" && the currentTime of player "Video" && "loadedTime" && the loadedTime of player "Video"
   logLine "size" && the formattedWidth of player "Video" & "x" & the formattedHeight of player "Video" \
         && "mediaTypes" && the mediaTypes of player "Video" && "status" && the status of player "Video"
   logLine "trackCount" && the trackCount of player "Video" & "; tracks:" && replaceText(the tracks of player "Video", return, " | ")
   logLine "enabledTracks" && replaceText(the enabledTracks of player "Video", return, ",") \
         && "playRate" && the playRate of player "Video" && "playLoudness" && the playLoudness of player "Video"
   logLine "looping" && the looping of player "Video" && "mirrored" && the mirrored of player "Video" \
         && "alwaysBuffer" && the alwaysBuffer of player "Video"
end showInfo

command logLine pText
   put the milliseconds mod 100000 && pText & return after field "Log" of card 1 of stack "VLCPlayerTest"
   set the vScroll of field "Log" of card 1 of stack "VLCPlayerTest" to \
         the formattedHeight of field "Log" of card 1 of stack "VLCPlayerTest"
end logLine

on playStarted
   logLine "playStarted"
   pass playStarted
end playStarted

on playPaused
   logLine "playPaused at" && the currentTime of player "Video" of card 1 of stack "VLCPlayerTest"
   pass playPaused
end playPaused

on playStopped
   logLine "playStopped at" && the currentTime of player "Video" of card 1 of stack "VLCPlayerTest"
   pass playStopped
end playStopped

on currentTimeChanged pTime
   add 1 to sTimeChanged
   if sTimeChanged mod 20 is 0 then
      logLine "currentTimeChanged" && pTime && "(every 20th shown)"
   end if
   pass currentTimeChanged
end currentTimeChanged

on playerCallback
   logLine "callback at" && the currentTime of player "Video" of card 1 of stack "VLCPlayerTest"
end playerCallback
