script "stack_Play_a_Video_card_id_1032"
-- Stack file: ide/Resources/Examples/Remastered/Play a Video.oxtstack
-- Object: stack "Play a Video" > card "Theater" (id 1032)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

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
      loadMovie sMovie  --(it may play now: say, mplayer or GStreamer is there now)
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
