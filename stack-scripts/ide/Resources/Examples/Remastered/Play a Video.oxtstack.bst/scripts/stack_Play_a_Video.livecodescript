script "stack_Play_a_Video"
-- Stack file: ide/Resources/Examples/Remastered/Play a Video.oxtstack
-- Object: stack "Play a Video"
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

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
   if the platform is "Linux" and not linuxCanPlay() then
      return "On Linux, OXT-Beyond plays a video with mplayer or GStreamer, and this computer has neither." && \
            "Install one of them (GStreamer's plugins, or mplayer), then try again."
   end if
   return empty
end videoTrouble

--Whether a Linux player can play a movie: through mplayer, or through GStreamer, which OXT-Beyond uses when mplayer is not there
function linuxCanPlay
   local tFolder
   if there is a file "/usr/bin/mplayer" then
      return true
   end if
   repeat for each item tFolder in "/usr/lib/x86_64-linux-gnu,/usr/lib/aarch64-linux-gnu,/usr/lib/i386-linux-gnu,/usr/lib/arm-linux-gnueabihf,/usr/lib64,/usr/lib,/lib/x86_64-linux-gnu,/lib/aarch64-linux-gnu,/lib64"
      if there is a file (tFolder & "/libgstreamer-1.0.so.0") then
         return true
      end if
   end repeat
   return false
end linuxCanPlay

--Why a video that should have played did not, in words
function whyNot
   switch the platform
      case "Win32"
         return "Windows could not open this video. It plays video with DirectShow, which needs an extra" && \
               "codec for some kinds of video, MP4 among them."
      case "HTML5"
         return "This browser could not play this video. Try another one, or the desktop IDE."
      case "Linux"
         return "Linux could not open this video (with mplayer, or GStreamer and its plugins). Try another one."
   end switch
   return "This computer could not open this video. Try another one."
end whyNot

--The note under the player of the Three Buttons, after "set filename": can it play what it has?
command showHow pPath
   local tTrouble, tTry
   put videoTrouble(pPath) into tTrouble
   if tTrouble is empty and the platform is not "Linux" then
      --(a player that can play its movie knows its length by now; on Linux it asks mplayer or GStreamer, so there the note says only that one of them is there)
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
