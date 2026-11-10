script "Puzzle Almanac"
-- Puzzle Almanac: a daily book of two puzzles for a phone or a window,
-- made with OXT-Beyond and the Mobile Web library. Built by
-- tools/web-player/puzzle-almanac.livecodescript in OXT-Beyond's
-- repository, from this script and the files of puzzle-almanac/; its
-- pictures and sounds are Kenney's (kenney.nl), CC0, its font Atkinson
-- Hyperlegible (SIL Open Font License) and its words ENABLE's (public
-- domain).
--
-- Every day there is a new puzzle of each kind, the same for everyone:
--   Number Place  a grid of 4, 6 or 9 squares a side, in boxes; every
--                 row, column and box holds each number once. Every
--                 puzzle has one answer, found by looking alone: a
--                 square that can hold only one number, or a number
--                 that fits in only one square of a row, a column or a
--                 box (make_puzzles.py checks both). Notes pencil in
--                 what a square might be; Hint fills one square.
--   Hidden Word   a word of 4, 5 or 6 letters to find in six tries. A
--                 try's tiles turn gold for a letter in the right place,
--                 blue for a letter of the word in another place, stone
--                 for one not in it; gold and blue carry a mark too (a
--                 star, a dot), so that the colours are not all they say.
--                 A solved word says what it means.
-- Solving the day's puzzle earns a sticker (30 animals, then gold stars)
-- and keeps a run of days going. Practice gives as many more as anyone
-- likes, for no sticker. No clock, no score, nothing lost for a wrong
-- try: a calm game for a child, and for everyone else.
--
-- How it is made:
--   one card, "Almanac": every screen (Home, Numbers, Words, Stickers) is
--     a group, and the panels over them (Done, Practice, Howto,
--     Settings) are groups behind a veil (Shade)
--   the day's puzzle: the day is counted from 1 January 2026 (paToday).
--     A Number Place puzzle is one of puzzle-almanac/data/numbers.txt,
--     chosen by the day, with its numbers renamed, its rows, columns,
--     bands and stacks put in another order and perhaps turned half way
--     round, as the day says (paTransform, with a random-number maker of
--     its own, so that the day's puzzle is the same on every engine).
--     None of that changes its having one answer, found by looking.
--     The hidden word is one of answers.txt, chosen by the day; a try
--     must be a word of words.txt (ENABLE)
--   no loop while nothing moves: paTick runs only while tiles turn,
--     sparks fly, a box shines or a message waits to go
--   sprites: buttons whose icon is a picture of the "Art" card. A
--     picture drawn at another size is resized there (paFit), which
--     resizes every button showing it: the tiles are one size on Home
--     and another in Hidden Word, so each screen sets them as it shows
--
-- For the tests (tests/lcs/webplayer/puzzle-almanac.livecodescript),
-- paTestBegin takes the clock out of the loop's hands, fixes the random
-- seed and the day, and keeps what is saved in a file of the test's own;
-- paTestStep moves the clock on, and paState says how things are.

constant kFont = "Atkinson Hyperlegible"
constant kPaper = "#F7F0E1"
constant kCard = "#FFFBF2"
constant kCardDown = "#F1E6CF"
constant kEdge = "#E2D3B5"
constant kInk = "#3B2F2A"
constant kMuted = "#7D6E60"
constant kFaint = "#B9AC98"
constant kLeaf = "#4E9A5B"
constant kLeafDown = "#3B7E47"
constant kKey = "#EADFC8"
constant kKeyDown = "#D8C9AC"
constant kWhite = "#FFFFFF"
-- the squares of Number Place: chosen, in its row, column or box, with
-- the chosen number, in a box just finished; the numbers: written in,
-- wrong (when mistakes are shown)
constant kChosen = "#F6D98A"
constant kPeer = "#F3EAD6"
constant kSame = "#E1EDD6"
constant kShine = "#CFE8C6"
constant kWritten = "#2F6DB5"
constant kWrong = "#C2412D"
-- the tiles of Hidden Word, and the keys that take their colours
constant kGold = "#FFCC00"
constant kGoldDown = "#E0B300"
constant kBlue = "#269FBD"
constant kBlueDown = "#1E86A0"
constant kStone = "#4C4740"
constant kStoneDown = "#3A3631"
constant kSaveName = "puzzle-almanac.txt"
-- the stickers, in the order they are earned
constant kAnimals = "owl,rabbit,panda,frog,penguin,bear,duck,elephant,giraffe,monkey,chick,whale,zebra,pig,dog,cow,horse,goat,parrot,hippo,sloth,narwhal,walrus,moose,crocodile,snake,chicken,gorilla,rhino,buffalo"
constant kWeekdays = "Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday"
constant kMonths = "January,February,March,April,May,June,July,August,September,October,November,December"
-- day 0: 1 January 2026, at noon (a day is counted from noon to noon, so
-- that an hour more or less in summer never makes it another day), as
-- dateItems: all seven, or convert leaves it as it is (the seventh, the
-- day of the week, is not read)
constant kDayZero = "2026,1,1,12,0,0,5"
constant kLetters = "QWERTYUIOPASDFGHJKLZXCVBNM"
constant kTries = 6
-- how long a tile takes to turn, and a message to go, in seconds
constant kTurn = 0.25
constant kMessageFor = 3

-- the screen shown (home, numbers, words, stickers, or closed) and the
-- panel over it (done, practice, howto, settings, or empty); whether the
-- library is there; whether the test holds the clock; the loop's
-- message, when it last ran and the time the game has run (seconds)
local sLibrary, sScreen, sPanel, sManual, sLoop, sLast, sClock
-- another file for the saved things (the tests'), the day fixed by a
-- test, how sounds play ("web", "desktop", "none") and where, whether
-- the font was loaded
local sSaveFile, sToday, sAudio, sAudioDir, sFontLoaded
-- kept between visits: the settings, the stickers and stars, each
-- puzzle's run of days (and the last day it was solved), and the day's
-- puzzles as far as they were played (sSavedN, sSavedW)
local sSound, sVoice, sMistakes, sSize, sLength, sSeenHowto, sStickers, sStars
local sNStreak, sNLast, sWStreak, sWLast, sSavedN, sSavedW
-- the puzzles and words of the stack: sBank[size] (lines of
-- puzzle:answer), sAnswers[length] (lines of word<tab>meaning), sWords
-- (every word a try may be); the rows, columns and boxes of each size
-- (sUnits[n], lines of squares), the units of each square
-- (sCellUnits[n][i]) and the squares that share one with it (sPeers)
local sBank, sAnswers, sWords, sUnits, sCellUnits, sPeers
-- the random-number maker of paTransform
local sRand
-- the puzzle on the board: sN (Number Place) and sW (Hidden Word); what
-- each square shows now (sLook, so that only a change is drawn)
local sN, sW, sLook
-- the pictures' ids and the size each was made at
local sPic, sNatural
-- the layout: the window, its insets, whether it is wide (two parts side
-- by side) and short; where a screen starts and ends; the tile size of
-- Hidden Word and of Home; the board; each tile's rect; the sticker
-- rings and the size of a sticker in them; the sticker page shown
local sWidth, sHeight, sInsetT, sInsetB, sInsetL, sInsetR, sSide, sCompact, sTopY, sBottomY
local sT, sHomeT, sBoard, sTileRect, sRing, sStickerBox, sPage
-- what moves: the tiles of a try turning (sReveal), the sparks of the
-- Done panel (sSparkT, their centre and how far out), a finished box
-- shining (sShine, sShineUntil), the message waiting to go
local sReveal, sSparkT, sSparkAt, sSparkR, sShine, sShineUntil, sMessageUntil
-- the panel Done: the puzzle it was for (numbers, words) and what was
-- earned (an animal, "star" or empty)
local sDoneKind, sAward

----------------------------------------------------------------------
-- Opening and closing

on preOpenStack
   paInit
end preOpenStack

on closeStack
   paStopLoop
   if sScreen is not "closed" then
      paKeepProgress
   end if
   put "closed" into sScreen
   if sLibrary then
      try
         mwStop
      end try
   end if
end closeStack

on resizeStack
   paResized
   pass resizeStack
end resizeStack

command paInit
   local tError
   set the defaultStack to the short name of me
   put false into sManual
   put empty into sLoop
   put empty into sSaveFile
   put empty into sToday
   put 0 into sClock
   put empty into sPanel
   put "home" into sScreen
   put empty into sLook
   put empty into sN
   put empty into sW
   put 1 into sPage
   put 44 into sHomeT
   put 64 into sT
   paFindPictures
   paLoadFonts
   paReadData
   paLoad
   -- the library is in OXT-Beyond 0.2.7 and later; without it the game
   -- is a window that plays with the mouse and the keys
   put true into sLibrary
   try
      mwStart the short name of me, "none"
   catch tError
      put false into sLibrary
   end try
   paAudioStart
   paWatchPage
   paLooks
   paStopMoving
   paLayout
   paGoHome
   if not sSeenHowto then
      paOpenPanel "howto", false
   end if
end paInit

-- The ids of the pictures, and the size each was made at
private command paFindPictures
   local i, tImage
   put empty into sPic
   put empty into sNatural
   repeat with i = 1 to the number of images of card "Art" of me
      put the long id of image i of card "Art" of me into tImage
      put the id of tImage into sPic[the short name of tImage]
      put the width of tImage, the height of tImage into sNatural[the short name of tImage]
   end repeat
end paFindPictures

-- Atkinson Hyperlegible, from the stack (without it, the stack's own
-- font): its two faces, regular and bold
private command paLoadFonts
   local tData, tFile, tFace
   if sFontLoaded is true then
      exit paLoadFonts
   end if
   repeat for each item tFace in "Regular,Bold"
      if tFace is "Regular" then
         put the cFontRegular of me into tData
      else
         put the cFontBold of me into tData
      end if
      if tData is empty then
         next repeat
      end if
      put specialFolderPath("temporary") & "/puzzle-almanac-atkinson-" & toLower(tFace) & ".ttf" into tFile
      try
         put tData into url ("binfile:" & tFile)
         start using font file tFile
         if the result is empty then
            put true into sFontLoaded
         end if
      end try
   end repeat
   if sFontLoaded is not true then
      put kFont is among the lines of the fontNames into sFontLoaded
   end if
end paLoadFonts

-- The puzzles and the words, from the stack's custom properties
private command paReadData
   local tLine, tLength, tSize
   put empty into sBank
   set the itemDelimiter to ":"
   repeat for each line tLine in the cNumbers of me
      if the number of items of tLine is 3 then
         put item 2 of tLine & ":" & item 3 of tLine & return after sBank[item 1 of tLine]
      end if
   end repeat
   put empty into sAnswers
   set the itemDelimiter to tab
   repeat for each line tLine in the cAnswers of me
      put the length of item 1 of tLine into tLength
      if tLength >= 4 and tLength <= 6 then
         put tLine & return after sAnswers[tLength]
      end if
   end repeat
   set the itemDelimiter to comma
   repeat for each item tSize in "4,6,9"
      delete the last char of sBank[tSize]
   end repeat
   repeat for each item tLength in "4,5,6"
      delete the last char of sAnswers[tLength]
   end repeat
   put the cWords of me into sWords
   paMakeUnits 4, 2, 2
   paMakeUnits 6, 2, 3
   paMakeUnits 9, 3, 3
end paReadData

-- The rows, columns and boxes of a grid of pN squares a side, in boxes
-- of pRows by pCols; the squares are numbered from 1, row by row
private command paMakeUnits pN, pRows, pCols
   local r, c, k, tUnit, tUnits, tR0, tC0, tLine, tCell, tPeers, tCount
   put empty into tUnits
   repeat with r = 0 to pN - 1
      put empty into tUnit
      repeat with c = 0 to pN - 1
         put r * pN + c + 1 & comma after tUnit
      end repeat
      put char 1 to -2 of tUnit & return after tUnits
   end repeat
   repeat with c = 0 to pN - 1
      put empty into tUnit
      repeat with r = 0 to pN - 1
         put r * pN + c + 1 & comma after tUnit
      end repeat
      put char 1 to -2 of tUnit & return after tUnits
   end repeat
   repeat with tR0 = 0 to pN - 1 step pRows
      repeat with tC0 = 0 to pN - 1 step pCols
         put empty into tUnit
         repeat with r = tR0 to tR0 + pRows - 1
            repeat with c = tC0 to tC0 + pCols - 1
               put r * pN + c + 1 & comma after tUnit
            end repeat
         end repeat
         put char 1 to -2 of tUnit & return after tUnits
      end repeat
   end repeat
   delete the last char of tUnits
   put tUnits into sUnits[pN]
   put 0 into tCount
   repeat for each line tLine in tUnits
      add 1 to tCount
      repeat for each item tCell in tLine
         put tCount & comma after sCellUnits[pN][tCell]
      end repeat
   end repeat
   repeat with k = 1 to pN * pN
      delete the last char of sCellUnits[pN][k]
      put empty into tPeers
      repeat for each item tLine in sCellUnits[pN][k]
         repeat for each item tCell in line tLine of tUnits
            if tCell is not k then
               put true into tPeers[tCell]
            end if
         end repeat
      end repeat
      put the keys of tPeers into tLine
      replace return with comma in tLine
      put tLine into sPeers[pN][k]
   end repeat
end paMakeUnits

----------------------------------------------------------------------
-- Kept between visits. In a browser, the documents folder is the page's
-- own storage, kept between visits; on a desktop, a folder for this game.

private function paSavePath
   local tFolder
   if sSaveFile is not empty then
      return sSaveFile
   end if
   if the platform is "HTML5" then
      put specialFolderPath("documents") into tFolder
   else
      put specialFolderPath("temporary") & "/oxt-puzzle-almanac" into tFolder
   end if
   if there is not a folder tFolder then
      create folder tFolder
   end if
   return tFolder & "/" & kSaveName
end paSavePath

command paLoad
   local tText, tLine, tKey, tValue, tSaved, tAt
   put true into sSound
   put false into sVoice
   put true into sMistakes
   put 6 into sSize
   put 5 into sLength
   put false into sSeenHowto
   put 0 into sStickers
   put 0 into sStars
   put 0 into sNStreak
   put empty into sNLast
   put 0 into sWStreak
   put empty into sWLast
   put empty into sSavedN
   put empty into sSavedW
   try
      put url ("file:" & paSavePath()) into tText
   end try
   -- (each line name=value, split where the = is: the items of the checks
   -- below are parted by commas)
   repeat for each line tLine in tText
      put offset("=", tLine) into tAt
      if tAt < 2 then
         next repeat
      end if
      put char 1 to tAt - 1 of tLine into tKey
      put char tAt + 1 to -1 of tLine into tValue
      switch tKey
         case "sound"
         case "voice"
         case "mistakes"
         case "howto"
            if tValue is "true" or tValue is "false" then
               if tKey is "howto" then
                  put tValue into sSeenHowto
               else
                  do "put tValue into s" & tKey
               end if
            end if
            break
         case "size"
            if tValue is among the items of "4,6,9" then
               put tValue into sSize
            end if
            break
         case "length"
            if tValue is among the items of "4,5,6" then
               put tValue into sLength
            end if
            break
         case "stickers"
            if tValue is an integer and tValue >= 0 then
               put min(tValue, the number of items of kAnimals) into sStickers
            end if
            break
         case "stars"
         case "nstreak"
         case "wstreak"
            if tValue is an integer and tValue >= 0 then
               do "put tValue into s" & tKey
            end if
            break
         case "nlast"
         case "wlast"
            if tValue is an integer then
               do "put tValue into s" & tKey
            end if
            break
         case "nday"
         case "nhints"
         case "wday"
            if tValue is an integer then
               put tValue into tSaved[char 1 of tKey][char 2 to -1 of tKey]
            end if
            break
         case "nsize"
            if tValue is among the items of "4,6,9" then
               put tValue into tSaved["n"]["size"]
            end if
            break
         case "nboard"
         case "nnotes"
            put tValue into tSaved["n"][char 2 to -1 of tKey]
            break
         case "wlen"
            if tValue is among the items of "4,5,6" then
               put tValue into tSaved["w"]["len"]
            end if
            break
         case "wrows"
            put tValue into tSaved["w"]["rows"]
            break
      end switch
   end repeat
   put paSavedNumbers(tSaved["n"]) into sSavedN
   put paSavedWords(tSaved["w"]) into sSavedW
end paLoad

-- The day's Number Place as saved, if it makes sense: its day and size,
-- a square for every number of the board, and its notes
private function paSavedNumbers pSaved
   local tN, tChar
   put pSaved["size"] into tN
   if pSaved["day"] is not an integer or tN is empty then
      return empty
   end if
   if the length of pSaved["board"] is not tN * tN then
      return empty
   end if
   repeat for each char tChar in pSaved["board"]
      if tChar is not an integer or tChar > tN then
         return empty
      end if
   end repeat
   if pSaved["hints"] is not an integer then
      put 0 into pSaved["hints"]
   end if
   return pSaved
end paSavedNumbers

-- The day's Hidden Word as saved, if it makes sense: its day, its
-- length, and its tries, each a word of that many letters
private function paSavedWords pSaved
   local tRow
   if pSaved["day"] is not an integer or pSaved["len"] is empty then
      return empty
   end if
   if the number of items of pSaved["rows"] > kTries then
      return empty
   end if
   repeat for each item tRow in pSaved["rows"]
      if the length of tRow is not pSaved["len"] or not matchText(tRow, "^[a-z]+$") then
         return empty
      end if
   end repeat
   return pSaved
end paSavedWords

command paSave
   local tText
   put "sound=" & sSound & return & "voice=" & sVoice & return & "mistakes=" & sMistakes & return & \
         "size=" & sSize & return & "length=" & sLength & return & "howto=" & sSeenHowto & return & \
         "stickers=" & sStickers & return & "stars=" & sStars & return & \
         "nstreak=" & sNStreak & return & "nlast=" & sNLast & return & \
         "wstreak=" & sWStreak & return & "wlast=" & sWLast & return into tText
   if sSavedN["day"] is an integer then
      put "nday=" & sSavedN["day"] & return & "nsize=" & sSavedN["size"] & return & \
            "nboard=" & sSavedN["board"] & return & "nnotes=" & sSavedN["notes"] & return & \
            "nhints=" & sSavedN["hints"] & return after tText
   end if
   if sSavedW["day"] is an integer then
      put "wday=" & sSavedW["day"] & return & "wlen=" & sSavedW["len"] & return & \
            "wrows=" & sSavedW["rows"] & return after tText
   end if
   try
      put tText into url ("file:" & paSavePath())
   end try
end paSave

-- The day's puzzles as they are now, kept (a practice one is not)
command paKeepProgress
   if sN["daily"] is true then
      put sN["day"] into sSavedN["day"]
      put sN["n"] into sSavedN["size"]
      put sN["board"] into sSavedN["board"]
      put paNotesList() into sSavedN["notes"]
      put sN["hints"] into sSavedN["hints"]
   end if
   if sW["daily"] is true then
      put sW["day"] into sSavedW["day"]
      put sW["len"] into sSavedW["len"]
      put sW["rows"] into sSavedW["rows"]
      replace return with comma in sSavedW["rows"]
   end if
   paSave
end paKeepProgress

----------------------------------------------------------------------
-- Sound. In a browser, sounds go to its Web Audio, which mixes them (the
-- engine plays one at a time). The page may only make a sound once it
-- has been touched (or clicked, or a key pressed), so the first touch
-- wakes it.

private command paAudioStart
   local tSounds, tName, tData
   put "none" into sAudio
   put the customProperties["cSounds"] of me into tSounds
   if the keys of tSounds is empty then
      exit paAudioStart
   end if
   if the platform is "HTML5" then
      try
         do paAudioScript() as "JavaScript"
         repeat for each key tName in tSounds
            put base64Encode(tSounds[tName]) into tData
            replace return with empty in tData
            do "window.paAudio.add('" & tName & "','" & tData & "');" as "JavaScript"
         end repeat
         put "web" into sAudio
      end try
   else
      -- written to files when the first sound plays
      put "desktop" into sAudio
      put empty into sAudioDir
   end if
end paAudioStart

-- The mixer, made once a page: paAudio.add(name, base64 of a WAV),
-- paAudio.play(name, volume). The same sound is not started twice in
-- 45 milliseconds.
private function paAudioScript
   return "(function(){if(window.paAudio)return;" & \
         "var C=window.AudioContext||window.webkitAudioContext;" & \
         "var A=window.paAudio={c:null,raw:{},buf:{},last:{}};" & \
         "A.decode=function(n){var c=A.c;if(!c||A.buf[n]||!A.raw[n])return;A.buf[n]='wait';" & \
         "var s=atob(A.raw[n]),u=new Uint8Array(s.length);for(var i=0;i<s.length;i++)u[i]=s.charCodeAt(i);" & \
         "var ok=function(b){A.buf[n]=b;},no=function(){A.buf[n]=null;};" & \
         "try{var p=c.decodeAudioData(u.buffer,ok,no);if(p&&p.catch)p.catch(no);}catch(e){no();}};" & \
         "A.add=function(n,d){A.raw[n]=d;A.decode(n);};" & \
         "A.unlock=function(){if(!C)return;if(!A.c){try{A.c=new C();}catch(e){return;}}" & \
         "if(A.c.state==='suspended')A.c.resume();for(var n in A.raw)A.decode(n);};" & \
         "['touchend','pointerup','mousedown','keydown'].forEach(function(e){window.addEventListener(e,A.unlock,true);});" & \
         "A.play=function(n,v){var c=A.c,b=A.buf[n];if(!c||c.state!=='running'||!b||b==='wait')return;" & \
         "var t=c.currentTime;if(A.last[n]&&t-A.last[n]<0.045)return;A.last[n]=t;" & \
         "var s=c.createBufferSource(),g=c.createGain();s.buffer=b;g.gain.value=v;" & \
         "s.connect(g);g.connect(c.destination);s.start(0);};})();"
end paAudioScript

command paSound pName, pVolume
   local tSounds, tName
   if sSound is not true then
      exit paSound
   end if
   if pVolume is empty then
      put 1 into pVolume
   end if
   if sAudio is "web" then
      try
         do "window.paAudio.play('" & pName & "'," & pVolume & ");" as "JavaScript"
      end try
   else if sAudio is "desktop" then
      try
         if sAudioDir is empty then
            put specialFolderPath("temporary") & "/oxt-puzzle-almanac-sounds" into sAudioDir
            if there is not a folder sAudioDir then
               create folder sAudioDir
            end if
            put the customProperties["cSounds"] of me into tSounds
            repeat for each key tName in tSounds
               put tSounds[tName] into url ("binfile:" & sAudioDir & "/" & tName & ".wav")
            end repeat
         end if
         play (sAudioDir & "/" & pName & ".wav")
      catch tName
         put "none" into sAudio
      end try
   end if
end paSound

-- A voice, when Say the numbers is on: a number, "correct" or
-- "congratulations"
private command paSay pWhat
   if sVoice is true then
      paSound "say-" & pWhat, 1
   end if
end paSay

-- The page tells the stack when it is hidden (another app, another tab,
-- the phone locked), through paPageHidden, one of the stack's
-- cJavascriptHandlers: the board is saved at once
private command paWatchPage
   if the platform is not "HTML5" then
      exit paWatchPage
   end if
   try
      do "(function(){if(window.paPageWatch)return;window.paPageWatch=1;" & \
            "document.addEventListener('visibilitychange',function(){if(!document.hidden)return;" & \
            "try{var s=document.liveCode.findStackWithName('" & the short name of me & "');" & \
            "if(s&&s.paPageHidden)s.paPageHidden();}catch(e){}});})();" as "JavaScript"
   end try
end paWatchPage

on paPageHidden
   set the defaultStack to the short name of me
   paFinishTurning
   paKeepProgress
end paPageHidden

----------------------------------------------------------------------
-- The days

-- Today, as a day from 1 January 2026 (or the day a test fixed)
function paToday
   local tItems
   if sToday is an integer then
      return sToday
   end if
   put the date into tItems
   convert tItems to dateItems
   return paDayOf(tItems)
end paToday

-- The day of a date (year, month, day, as dateItems)
function paDayOf pItems
   local tAt, tZero
   put item 1 of pItems, item 2 of pItems, item 3 of pItems, 12, 0, 0, 1 into tAt
   convert tAt from dateItems to seconds
   put kDayZero into tZero
   convert tZero from dateItems to seconds
   return round((tAt - tZero) / 86400)
end paDayOf

-- A day as words: Saturday 7 November
function paDateText pDay
   local tAt
   put kDayZero into tAt
   convert tAt from dateItems to seconds
   add pDay * 86400 to tAt
   convert tAt from seconds to dateItems
   return item (item 7 of tAt) of kWeekdays && item 3 of tAt && item (item 2 of tAt) of kMonths
end paDateText

-- Whether two boards (or any two strings of digits) are the same, digit
-- for digit. "is" compares two strings that look like numbers as numbers:
-- a board is a number of 16 to 81 digits, which the engine keeps to 15 or
-- so, so a board with only its first rows right "is" the answer. Neither
-- is a number with a letter before it, and "is" compares them as text
private function paSameDigits pA, pB
   return ("n" & pA) is ("n" & pB)
end paSameDigits

-- pA mod pM, from 0 to pM - 1 for a day before day 0 too
private function paMod pA, pM
   return ((pA mod pM) + pM) mod pM
end paMod

private function paGcd pA, pB
   local tR
   repeat while pB is not 0
      put pA mod pB into tR
      put pB into pA
      put tR into pB
   end repeat
   return pA
end paGcd

-- How many days in a row a puzzle was solved, as of pToday: the run
-- ended if the last was before yesterday
private function paRun pStreak, pLast, pToday
   if pLast is an integer and pLast >= pToday - 1 then
      return pStreak
   end if
   return 0
end paRun

-- The run after solving the day pDay's puzzle
private function paRunAfter pStreak, pLast, pDay
   if pLast is an integer and pLast is pDay - 1 then
      return pStreak + 1
   end if
   if pLast is pDay then
      return pStreak
   end if
   return 1
end paRunAfter

-- A sticker for the day's puzzle: the next animal, or a gold star once
-- every animal is in the book
private function paAward
   if sStickers < the number of items of kAnimals then
      add 1 to sStickers
      return item sStickers of kAnimals
   end if
   add 1 to sStars
   return "star"
end paAward

----------------------------------------------------------------------
-- The day's puzzles, the same on every engine

-- A random-number maker of the game's own (Park and Miller's), so that a
-- day's puzzle is the same everywhere: a number from 0 to pBelow - 1
private function paRand pBelow
   put (sRand * 16807) mod 2147483647 into sRand
   return sRand mod pBelow
end paRand

-- 0 to pCount - 1, shuffled, as items
private function paOrder pCount
   local tList, i, j, tSwap
   repeat with i = 0 to pCount - 1
      put i into tList[i + 1]
   end repeat
   repeat with i = pCount down to 2
      put paRand(i) + 1 into j
      put tList[i] into tSwap
      put tList[j] into tList[i]
      put tSwap into tList[j]
   end repeat
   put empty into tSwap
   repeat with i = 1 to pCount
      put tList[i] & comma after tSwap
   end repeat
   return char 1 to -2 of tSwap
end paOrder

-- A puzzle (and its answer) of pN squares a side as another of the same
-- kind, as pSeed says: its numbers renamed, its bands and the rows in
-- each, its stacks and the columns in each, in another order, and
-- perhaps turned half way round. Returns puzzle:answer
function paTransform pPuzzle, pAnswer, pN, pSeed
   local tRows, tCols, tNames, tTurn, tBand, tInner, k, r, c, tR, tC, tFrom, tV, tPuzzle, tAnswer
   local tBoxRows, tBoxCols
   put paBoxRows(pN) into tBoxRows
   put pN / tBoxRows into tBoxCols
   put paMod(pSeed, 2147483646) + 1 into sRand
   repeat for each item tBand in paOrder(pN div tBoxRows)
      repeat for each item tInner in paOrder(tBoxRows)
         put tBand * tBoxRows + tInner & comma after tRows
      end repeat
   end repeat
   repeat for each item tBand in paOrder(pN div tBoxCols)
      repeat for each item tInner in paOrder(tBoxCols)
         put tBand * tBoxCols + tInner & comma after tCols
      end repeat
   end repeat
   put paOrder(pN) into tNames
   put paRand(2) into tTurn
   repeat with r = 0 to pN - 1
      repeat with c = 0 to pN - 1
         if tTurn is 1 then
            put item (pN - r) of tRows into tR
            put item (pN - c) of tCols into tC
         else
            put item (r + 1) of tRows into tR
            put item (c + 1) of tCols into tC
         end if
         put tR * pN + tC + 1 into tFrom
         put char tFrom of pPuzzle into tV
         if tV is not 0 then
            put item tV of tNames + 1 into tV
         end if
         put tV after tPuzzle
         put item (char tFrom of pAnswer) of tNames + 1 after tAnswer
      end repeat
   end repeat
   return tPuzzle & ":" & tAnswer
end paTransform

-- The rows of a box of a grid pN squares a side (its columns: pN over it)
function paBoxRows pN
   if pN is 9 then
      return 3
   end if
   return 2
end paBoxRows

-- The day's Number Place of pN squares a side: puzzle:answer
function paDailyNumbers pN, pDay
   local tCount, tLine
   put the number of lines of sBank[pN] into tCount
   put line (paMod(pDay * 7 + pN, tCount) + 1) of sBank[pN] into tLine
   set the itemDelimiter to ":"
   put paTransform(item 1 of tLine, item 2 of tLine, pN, pDay * 97 + pN) into tLine
   set the itemDelimiter to comma
   return tLine
end paDailyNumbers

-- The day's hidden word of pLength letters: word<tab>meaning. The words
-- come in a stride through the list that is prime to its length, so
-- that every word comes once before any comes again
function paDailyWord pLength, pDay
   local tCount, tStep
   put the number of lines of sAnswers[pLength] into tCount
   repeat for each item tStep in "37,41,43,47,53,59,61"
      if paGcd(tStep, tCount) is 1 then
         exit repeat
      end if
   end repeat
   return line (paMod(pDay * tStep + 11, tCount) + 1) of sAnswers[pLength]
end paDailyWord

----------------------------------------------------------------------
-- The screens and the panels

command paShowScreen pName
   lock screen
   put pName into sScreen
   set the visible of group "Home" to (pName is "home")
   set the visible of group "Numbers" to (pName is "numbers")
   set the visible of group "Words" to (pName is "words")
   set the visible of group "Stickers" to (pName is "stickers")
   set the visible of group "Top" to (pName is not "home")
   switch pName
      case "numbers"
         if sN["daily"] then
            set the text of field "Top Title" to "Number Place"
         else
            set the text of field "Top Title" to "Practice"
         end if
         break
      case "words"
         if sW["daily"] then
            set the text of field "Top Title" to "Hidden Word"
         else
            set the text of field "Top Title" to "Practice"
         end if
         break
      case "stickers"
         set the text of field "Top Title" to "Sticker book"
         break
   end switch
   paSizes
   paShowPanels
   unlock screen
end paShowScreen

private command paShowPanels
   set the visible of group "Done" to (sPanel is "done")
   set the visible of group "Practice" to (sPanel is "practice")
   set the visible of group "Howto" to (sPanel is "howto")
   set the visible of group "Settings" to (sPanel is "settings")
   set the visible of graphic "Shade" to (sPanel is not empty)
end paShowPanels

command paOpenPanel pName, pSound
   put pName into sPanel
   if pName is "settings" then
      set the text of field "Settings Note" to empty
      paSettingsLook
   end if
   lock screen
   paShowPanels
   unlock screen
   if pSound is not false then
      paSound "open", 0.7
   end if
end paOpenPanel

command paClosePanel pSound
   if sPanel is "done" then
      paStopSparks
   end if
   put empty into sPanel
   lock screen
   paShowPanels
   unlock screen
   if pSound is not false then
      paSound "close", 0.6
   end if
end paClosePanel

command paGoHome
   set the defaultStack to the short name of me
   paFinishTurning
   if sPanel is not empty then
      paClosePanel false
   end if
   paHomeLook
   paShowScreen "home"
end paGoHome

-- What Home says: the day, each puzzle's card, the stickers and the runs
private command paHomeLook
   local tDay, tState, tColor, tSolved, tSize, tLength
   put paToday() into tDay
   set the text of field "Home Date" to paDateText(tDay)
   -- Number Place
   put sSize into tSize
   put sNLast is tDay into tSolved
   if tSolved then
      if sSavedN["day"] is tDay then
         put sSavedN["size"] into tSize
      end if
      put "Solved today" into tState
   else if sSavedN["day"] is tDay and sSavedN["size"] is sSize and paStarted(sSavedN) then
      put "Started" into tState
   else
      put "New today" into tState
   end if
   set the text of field "Numbers Card Title" to "Number Place"
   set the text of field "Numbers Card Sub" to "Today's" && tSize && "by" && tSize
   set the text of field "Numbers Card State" to tState
   if tSolved then
      put kLeaf into tColor
   else
      put kMuted into tColor
   end if
   set the textColor of field "Numbers Card State" to tColor
   set the visible of button "Numbers Card Badge" to tSolved
   -- Hidden Word
   put sLength into tLength
   put sWLast is tDay into tSolved
   if sSavedW["day"] is tDay and (tSolved or paWordsOver(sSavedW) is not empty) then
      put sSavedW["len"] into tLength
   end if
   if tSolved then
      put "Solved today" into tState
   else if sSavedW["day"] is tDay and paWordsOver(sSavedW) is "lost" then
      put "A new word tomorrow" into tState
   else if sSavedW["day"] is tDay and sSavedW["len"] is sLength and sSavedW["rows"] is not empty then
      put "Started" into tState
   else
      put "New today" into tState
   end if
   set the text of field "Words Card Title" to "Hidden Word"
   set the text of field "Words Card Sub" to "Today's word of" && tLength && "letters"
   set the text of field "Words Card State" to tState
   if tSolved then
      put kLeaf into tColor
   else
      put kMuted into tColor
   end if
   set the textColor of field "Words Card State" to tColor
   set the visible of button "Words Card Badge" to tSolved
   set the text of field "Home Streak" to paStickerCount() & return & "Days in a row:" && \
         paRun(sNStreak, sNLast, tDay) && "for numbers," && paRun(sWStreak, sWLast, tDay) && "for words"
end paHomeLook

private function paStickerCount
   local tText
   put "Stickers:" && sStickers && "of" && the number of items of kAnimals into tText
   if sStars is 1 then
      put ", and a gold star" after tText
   else if sStars > 1 then
      put ", and" && sStars && "gold stars" after tText
   end if
   return tText
end paStickerCount

-- Whether a saved Number Place has a number or a note written in it
private function paStarted pSaved
   local tGiven
   if pSaved["notes"] is not empty and pSaved["notes"] is not paNoNotes(pSaved["size"]) then
      return true
   end if
   set the itemDelimiter to ":"
   put item 1 of paDailyNumbers(pSaved["size"], pSaved["day"]) into tGiven
   set the itemDelimiter to comma
   return not paSameDigits(pSaved["board"], tGiven)
end paStarted

-- Which screen Back goes to (Home, from every screen)
private command paBack
   paFinishTurning
   paKeepProgress
   paSound "page", 0.6
   paGoHome
end paBack

----------------------------------------------------------------------
-- The buttons

-- A button, pressed (pDown) or let go: its shape takes its colour
command paButtonLook pName, pDown
   local tShape
   put pName && "Shape" into tShape
   if there is not a graphic tShape then
      exit paButtonLook
   end if
   if pDown then
      set the backgroundColor of graphic tShape to the cDown of graphic tShape
   else
      set the backgroundColor of graphic tShape to the cUp of graphic tShape
   end if
end paButtonLook

-- What each button does (and a tap on a square of Number Place)
command paPress pName
   local tWhat
   set the defaultStack to the short name of me
   if word 1 to 2 of pName is "N Cell" or word 1 to 2 of pName is "N Note" then
      paChoose word 3 of pName
      exit paPress
   end if
   if word 1 to 2 of pName is "N Key" then
      paNumber word 3 of pName
      exit paPress
   end if
   if word 1 to 2 of pName is "W Key" then
      put word 3 of pName into tWhat
      if tWhat is "Enter" then
         paTry
      else if tWhat is "Back" then
         paUnletter
      else
         paLetter tWhat
      end if
      exit paPress
   end if
   switch pName
      case "Back"
         paBack
         break
      case "Numbers Card"
         paSound "page", 0.6
         paOpenNumbers
         break
      case "Words Card"
         paSound "page", 0.6
         paOpenWords
         break
      case "Stickers Open"
         paSound "page", 0.6
         paShowStickers
         break
      case "Practice Open"
         paOpenPanel "practice"
         break
      case "Howto Open"
         paOpenPanel "howto"
         break
      case "Settings Open"
         paOpenPanel "settings"
         break
      case "N Notes"
         paSound "tap", 0.5
         put not (sN["notes on"] is true) into sN["notes on"]
         paDrawBoard
         break
      case "N Erase"
         paErase
         break
      case "N Undo"
         paUndo
         break
      case "N Hint"
         paHint
         break
      case "S Prev"
      case "S Next"
         paSound "page", 0.6
         if pName is "S Prev" then
            put 1 into sPage
         else
            put 2 into sPage
         end if
         paStickersLook
         break
      case "Done Home"
         paClosePanel false
         paSound "page", 0.6
         paGoHome
         break
      case "Done Again"
         paClosePanel false
         paSound "page", 0.6
         if sDoneKind is "words" then
            paStartWords sW["len"], false
            paShowScreen "words"
         else
            paStartNumbers sN["n"], false
            paShowScreen "numbers"
         end if
         break
      case "P N4"
      case "P N6"
      case "P N9"
         paClosePanel false
         paSound "page", 0.6
         paStartNumbers char 4 of pName, false
         paShowScreen "numbers"
         break
      case "P W4"
      case "P W5"
      case "P W6"
         paClosePanel false
         paSound "page", 0.6
         paStartWords char 4 of pName, false
         paShowScreen "words"
         break
      case "Howto Done"
         if not sSeenHowto then
            put true into sSeenHowto
            paSave
         end if
         paClosePanel
         break
      case "Practice Close"
      case "Settings Done"
         paClosePanel
         break
      case "Set Sound"
      case "Set Voice"
      case "Set Mistakes"
      case "Set Size"
      case "Set Length"
      case "Set Full"
         paSetting pName
         break
   end switch
end paPress

-- The keys: numbers, the arrows, Delete and N on Number Place; letters,
-- Return and Delete on Hidden Word; Escape goes back (or shuts a panel)
on rawKeyDown pKey
   local tChar
   set the defaultStack to the short name of me
   if sPanel is not empty then
      if pKey is 65307 or pKey is 65293 or pKey is 65421 then
         switch sPanel
            case "done"
               paPress "Done Home"
               break
            case "howto"
               paPress "Howto Done"
               break
            case "practice"
               paPress "Practice Close"
               break
            case "settings"
               paPress "Settings Done"
               break
         end switch
         exit rawKeyDown
      end if
      pass rawKeyDown
   end if
   if pKey is 65307 and sScreen is not "home" then
      paPress "Back"
      exit rawKeyDown
   end if
   if sScreen is "home" then
      -- N opens Number Place, W Hidden Word
      if pKey is 110 or pKey is 78 then
         paPress "Numbers Card"
         exit rawKeyDown
      else if pKey is 119 or pKey is 87 then
         paPress "Words Card"
         exit rawKeyDown
      end if
   else if sScreen is "numbers" then
      if pKey >= 49 and pKey <= 57 then
         put pKey - 48 into tChar
      else if pKey >= 65457 and pKey <= 65465 then
         put pKey - 65456 into tChar
      end if
      if tChar is not empty then
         if tChar <= sN["n"] then
            paPress "N Key" && tChar
         end if
         exit rawKeyDown
      end if
      switch pKey
         case 65288
         case 65535
         case 48
            paPress "N Erase"
            exit rawKeyDown
         case 110
         case 78
            paPress "N Notes"
            exit rawKeyDown
         case 117
         case 85
            paPress "N Undo"
            exit rawKeyDown
         case 65361
            paMove 0, -1
            exit rawKeyDown
         case 65362
            paMove -1, 0
            exit rawKeyDown
         case 65363
            paMove 0, 1
            exit rawKeyDown
         case 65364
            paMove 1, 0
            exit rawKeyDown
      end switch
   else if sScreen is "words" then
      if (pKey >= 97 and pKey <= 122) or (pKey >= 65 and pKey <= 90) then
         paPress "W Key" && toUpper(numToCodepoint(pKey))
         exit rawKeyDown
      end if
      switch pKey
         case 65293
         case 65421
            paPress "W Key Enter"
            exit rawKeyDown
         case 65288
         case 65535
            paPress "W Key Back"
            exit rawKeyDown
      end switch
   else if sScreen is "stickers" then
      if pKey is 65361 then
         paPress "S Prev"
         exit rawKeyDown
      else if pKey is 65363 then
         paPress "S Next"
         exit rawKeyDown
      end if
   end if
   pass rawKeyDown
end rawKeyDown

-- (the arrows choose a square: they do not change the card)
on arrowKey pDirection
end arrowKey

----------------------------------------------------------------------
-- Settings

private command paSetting pName
   local tResult, tDay, tNote
   put paToday() into tDay
   switch pName
      case "Set Sound"
         put not sSound into sSound
         paSound "tap", 0.6
         break
      case "Set Voice"
         put not sVoice into sVoice
         paSay "correct"
         if not sVoice then
            paSound "tap", 0.6
         end if
         break
      case "Set Mistakes"
         put not sMistakes into sMistakes
         paSound "tap", 0.6
         break
      case "Set Size"
         paSound "tap", 0.6
         if sSize is 4 then
            put 6 into sSize
         else if sSize is 6 then
            put 9 into sSize
         else
            put 4 into sSize
         end if
         if sNLast is tDay then
            put "Today's Number Place is solved: the new size starts tomorrow." into tNote
         else if sSavedN["day"] is tDay and sSavedN["size"] is not sSize and paStarted(sSavedN) then
            put "Today's Number Place will start again," && sSize && "by" && sSize & "." into tNote
         end if
         break
      case "Set Length"
         paSound "tap", 0.6
         if sLength is 4 then
            put 5 into sLength
         else if sLength is 5 then
            put 6 into sLength
         else
            put 4 into sLength
         end if
         if sWLast is tDay or (sSavedW["day"] is tDay and paWordsOver(sSavedW) is not empty) then
            put "Today's Hidden Word is done: the new length starts tomorrow." into tNote
         else if sSavedW["day"] is tDay and sSavedW["len"] is not sLength and sSavedW["rows"] is not empty then
            put "Today's Hidden Word will start again, with" && sLength && "letters." into tNote
         end if
         break
      case "Set Full"
         paSound "tap", 0.6
         if sLibrary then
            try
               mwFullScreen not mwIsFullScreen()
               put the result into tResult
            catch tResult
            end try
            if tResult is not empty then
               put "This browser cannot hide its bars. On an iPhone, add the page to the home screen." into tNote
            end if
         end if
         break
   end switch
   set the text of field "Settings Note" to tNote
   paSave
   paSettingsLook
   paHomeLook
end paSetting

private command paSettingsLook
   local tFull
   set the label of button "Set Sound" to "Sound:" && paOnOff(sSound)
   set the label of button "Set Voice" to "Say the numbers:" && paOnOff(sVoice)
   set the label of button "Set Mistakes" to "Show mistakes:" && paOnOff(sMistakes)
   set the label of button "Set Size" to "Number Place:" && sSize && "by" && sSize
   set the label of button "Set Length" to "Hidden Word:" && sLength && "letters"
   put false into tFull
   if sLibrary then
      try
         put mwIsFullScreen() into tFull
      end try
   end if
   set the label of button "Set Full" to "Full screen:" && paOnOff(tFull is true)
end paSettingsLook

private function paOnOff pOn
   if pOn is true then
      return "on"
   end if
   return "off"
end paOnOff

----------------------------------------------------------------------
-- Number Place

-- Today's: as it was left, or new. Once solved, today's stays solved in
-- the size it was solved in; begun in another size than Settings says,
-- it starts again in the new one
command paOpenNumbers
   local tDay, tSize, tSolved
   put paToday() into tDay
   put sNLast is tDay into tSolved
   put sSize into tSize
   if sSavedN["day"] is tDay and (tSolved or sSavedN["size"] is sSize) then
      put sSavedN["size"] into tSize
   end if
   paSetNumbers tSize, paDailyNumbers(tSize, tDay), true, tDay
   if sSavedN["day"] is tDay and sSavedN["size"] is tSize then
      put sSavedN["board"] into sN["board"]
      paRestoreNotes sSavedN["notes"]
      put sSavedN["hints"] into sN["hints"]
      -- (the numbers given must be where the puzzle has them)
      if not paGivenKept() then
         put sN["given"] into sN["board"]
         paRestoreNotes empty
         put 0 into sN["hints"]
      end if
   end if
   if tSolved then
      put sN["answer"] into sN["board"]
      put true into sN["solved"]
   end if
   paShowScreen "numbers"
   paDrawBoard
   if tSolved then
      paMessage "Solved today. A new one comes tomorrow.", true
   else
      paMessage "Tap a square, then a number."
   end if
end paOpenNumbers

-- A practice puzzle of pN squares a side (or today's, pDaily)
command paStartNumbers pN, pDaily
   local tCount, tLine
   if pN is not among the items of "4,6,9" then
      put sSize into pN
   end if
   if pDaily is true then
      paSetNumbers pN, paDailyNumbers(pN, paToday()), true, paToday()
   else
      put the number of lines of sBank[pN] into tCount
      put line random(tCount) of sBank[pN] into tLine
      set the itemDelimiter to ":"
      paSetNumbers pN, paTransform(item 1 of tLine, item 2 of tLine, pN, random(2147483646)), false, empty
      set the itemDelimiter to comma
   end if
   paDrawBoard
   paMessage "Tap a square, then a number."
end paStartNumbers

private command paSetNumbers pN, pPuzzle, pDaily, pDay
   paStopShine
   put empty into sN
   put empty into sLook
   put pN into sN["n"]
   set the itemDelimiter to ":"
   put item 1 of pPuzzle into sN["given"]
   put item 2 of pPuzzle into sN["answer"]
   set the itemDelimiter to comma
   put sN["given"] into sN["board"]
   paRestoreNotes empty
   put 0 into sN["hints"]
   put 0 into sN["chosen"]
   put empty into sN["undo"]
   put false into sN["solved"]
   put false into sN["notes on"]
   put pDaily is true into sN["daily"]
   put pDay into sN["day"]
   lock screen
   paLayoutNumbers
   unlock screen
end paSetNumbers

-- Whether the board has the given numbers where the puzzle has them
private function paGivenKept
   local i, tG
   repeat with i = 1 to sN["n"] * sN["n"]
      put char i of sN["given"] into tG
      if tG is not 0 and char i of sN["board"] is not tG then
         return false
      end if
   end repeat
   return true
end paGivenKept

-- The notes, as kept: a note of each square, numbers run together, the
-- squares parted by dots
function paNotesList
   local i, tOut
   repeat with i = 1 to sN["n"] * sN["n"]
      put sN["notes"][i] & "." after tOut
   end repeat
   return char 1 to -2 of tOut
end paNotesList

private function paNoNotes pN
   local tOut, i
   repeat with i = 2 to pN * pN
      put "." after tOut
   end repeat
   return tOut
end paNoNotes

private command paRestoreNotes pList
   local i, tNote
   set the itemDelimiter to "."
   repeat with i = 1 to sN["n"] * sN["n"]
      put item i of pList into tNote
      if not matchText(tNote, "^[1-9]*$") then
         put empty into tNote
      end if
      put tNote into sN["notes"][i]
   end repeat
   set the itemDelimiter to comma
end paRestoreNotes

-- A square chosen (a tap on it)
command paChoose pCell
   if pCell is not an integer or pCell < 1 or pCell > sN["n"] * sN["n"] then
      exit paChoose
   end if
   put pCell into sN["chosen"]
   paDrawBoard
end paChoose

-- The arrows: the next square that way, round to the other side
private command paMove pDown, pAcross
   local tN, r, c
   put sN["n"] into tN
   if sN["chosen"] < 1 then
      paChoose 1
      exit paMove
   end if
   put (sN["chosen"] - 1) div tN into r
   put (sN["chosen"] - 1) mod tN into c
   put paMod(r + pDown, tN) into r
   put paMod(c + pAcross, tN) into c
   paChoose r * tN + c + 1
end paMove

-- A square as it is, to be put back by Undo: cell:number:notes
private function paSquare pCell
   return pCell & ":" & char pCell of sN["board"] & ":" & sN["notes"][pCell]
end paSquare

private command paRemember pSquares
   if sN["undo"] is empty then
      put pSquares into sN["undo"]
   else
      put return & pSquares after sN["undo"]
   end if
   if the number of lines of sN["undo"] > 300 then
      delete line 1 of sN["undo"]
   end if
end paRemember

-- Whether a square can take a number: one is chosen, the puzzle is not
-- solved, and it was not given
private function paCanWrite pCell
   if sN["solved"] then
      paMessage "Solved! Try a practice puzzle for more."
      paSound "nope", 0.5
      return false
   end if
   if pCell < 1 then
      paMessage "Tap a square first."
      paSound "nope", 0.5
      return false
   end if
   if char pCell of sN["given"] is not 0 then
      paMessage "That number was in the puzzle: it stays."
      paSound "nope", 0.5
      return false
   end if
   return true
end paCanWrite

-- A number key: the number in the chosen square, or a note of it
command paNumber pV
   local tCell, tPeer, tUndo, tNotes, tN
   put sN["chosen"] into tCell
   put sN["n"] into tN
   if pV is not an integer or pV < 1 or pV > tN then
      exit paNumber
   end if
   if not paCanWrite(tCell) then
      exit paNumber
   end if
   if sN["notes on"] then
      if char tCell of sN["board"] is not 0 then
         paMessage "Erase the number first, to write notes."
         paSound "nope", 0.5
         exit paNumber
      end if
      paRemember paSquare(tCell)
      put sN["notes"][tCell] into tNotes
      if pV is in tNotes then
         replace pV with empty in tNotes
      else
         put paSorted(tNotes & pV) into tNotes
      end if
      put tNotes into sN["notes"][tCell]
      paSound "tap", 0.5
   else
      if char tCell of sN["board"] is pV then
         -- the same number again takes it away
         paRemember paSquare(tCell)
         put 0 into char tCell of sN["board"]
         paSound "erase", 0.6
      else
         put paSquare(tCell) into tUndo
         repeat for each item tPeer in sPeers[tN][tCell]
            if pV is in sN["notes"][tPeer] then
               put comma & paSquare(tPeer) after tUndo
               replace pV with empty in sN["notes"][tPeer]
            end if
         end repeat
         paRemember tUndo
         put pV into char tCell of sN["board"]
         paSound "place", 0.7
         paSay pV
         paCheckNumbers tCell
      end if
   end if
   paKeepProgress
   paDrawBoard
end paNumber

-- The numbers of pText in order, each once
private function paSorted pText
   local tOut, i
   repeat with i = 1 to 9
      if i is in pText then
         put i after tOut
      end if
   end repeat
   return tOut
end paSorted

-- After a number: a row, column or box it finished shines (and the voice
-- says so), a finished board is solved, a full one that is wrong says so
private command paCheckNumbers pCell
   local tUnit, tCells, tCell, tDone, tShine, tFull
   if paSameDigits(sN["board"], sN["answer"]) then
      paSolvedNumbers
      exit paCheckNumbers
   end if
   repeat for each item tUnit in sCellUnits[sN["n"]][pCell]
      put line tUnit of sUnits[sN["n"]] into tCells
      put true into tDone
      repeat for each item tCell in tCells
         if char tCell of sN["board"] is not char tCell of sN["answer"] then
            put false into tDone
            exit repeat
         end if
      end repeat
      if tDone then
         put tCells & comma after tShine
      end if
   end repeat
   if tShine is not empty then
      put comma & tShine into sShine
      put sClock + 0.7 into sShineUntil
      paSay "correct"
      paSchedule
   end if
   put not ("0" is in sN["board"]) into tFull
   if tFull then
      if sMistakes then
         paMessage "Full! The red numbers are not right yet."
      else
         paMessage "Every square is full, but some are not right."
      end if
   end if
end paCheckNumbers

private command paSolvedNumbers
   put true into sN["solved"]
   put empty into sAward
   paStopShine
   if sN["daily"] and sNLast is not sN["day"] then
      put paRunAfter(sNStreak, sNLast, sN["day"]) into sNStreak
      put sN["day"] into sNLast
      put paAward() into sAward
   end if
   paKeepProgress
   paDrawBoard
   paMessage "Solved!", true
   paShowDone "numbers", true
end paSolvedNumbers

command paErase
   local tCell
   put sN["chosen"] into tCell
   if not paCanWrite(tCell) then
      exit paErase
   end if
   if char tCell of sN["board"] is 0 and sN["notes"][tCell] is empty then
      exit paErase
   end if
   paRemember paSquare(tCell)
   put 0 into char tCell of sN["board"]
   put empty into sN["notes"][tCell]
   paSound "erase", 0.6
   paKeepProgress
   paDrawBoard
end paErase

command paUndo
   local tLine, tSquare, tCell
   if sN["solved"] or sN["undo"] is empty then
      paSound "nope", 0.5
      exit paUndo
   end if
   put the last line of sN["undo"] into tLine
   delete the last line of sN["undo"]
   set the itemDelimiter to comma
   repeat for each item tSquare in tLine
      set the itemDelimiter to ":"
      put item 1 of tSquare into tCell
      put item 2 of tSquare into char tCell of sN["board"]
      put item 3 of tSquare into sN["notes"][tCell]
      set the itemDelimiter to comma
   end repeat
   put tCell into sN["chosen"]
   paSound "erase", 0.6
   paKeepProgress
   paDrawBoard
end paUndo

-- Hint: the right number in the chosen square (if it is empty or
-- wrong), or else in the square with the fewest numbers it could hold
command paHint
   local tCell, tN, i, tFewest, tCount
   if sN["solved"] then
      paSound "nope", 0.5
      exit paHint
   end if
   put sN["n"] into tN
   put sN["chosen"] into tCell
   if tCell < 1 or char tCell of sN["board"] is char tCell of sN["answer"] then
      put 0 into tCell
      put 99 into tFewest
      repeat with i = 1 to tN * tN
         if char i of sN["board"] is not char i of sN["answer"] then
            put paCouldHold(i) into tCount
            if char i of sN["board"] is not 0 then
               -- a wrong number first
               put 0 into tCount
            end if
            if tCount < tFewest then
               put tCount into tFewest
               put i into tCell
            end if
         end if
      end repeat
   end if
   if tCell < 1 then
      exit paHint
   end if
   paRemember paSquare(tCell)
   put char tCell of sN["answer"] into char tCell of sN["board"]
   put empty into sN["notes"][tCell]
   put tCell into sN["chosen"]
   add 1 to sN["hints"]
   paSound "reveal", 0.8
   paCheckNumbers tCell
   paKeepProgress
   paDrawBoard
end paHint

-- How many numbers a square could hold: those no square of its row,
-- column or box holds
private function paCouldHold pCell
   local tUsed, tPeer, tV, tCount
   repeat for each item tPeer in sPeers[sN["n"]][pCell]
      put char tPeer of sN["board"] into tV
      if tV is not 0 then
         put true into tUsed[tV]
      end if
   end repeat
   return sN["n"] - the number of lines of the keys of tUsed
end paCouldHold

-- The board as it is: each square's colour, number and notes (only what
-- changed), the keys, the line over the board
command paDrawBoard
   local tN, i, tV, tG, tChosen, tChosenV, tPeers, tBack, tColor, tStyle, tNotes, tCount, tKey, tInfo
   if sN["n"] is empty then
      exit paDrawBoard
   end if
   lock screen
   put sN["n"] into tN
   put sN["chosen"] into tChosen
   put 0 into tChosenV
   if tChosen > 0 then
      put char tChosen of sN["board"] into tChosenV
      put comma & sPeers[tN][tChosen] & comma into tPeers
   end if
   repeat with i = 1 to tN * tN
      put char i of sN["board"] into tV
      put char i of sN["given"] into tG
      if i is tChosen then
         put kChosen into tBack
      else if comma & i & comma is in sShine then
         put kShine into tBack
      else if tChosenV is not 0 and tV is tChosenV then
         put kSame into tBack
      else if comma & i & comma is in tPeers then
         put kPeer into tBack
      else
         put kCard into tBack
      end if
      if tG is not 0 then
         put kInk into tColor
         put "bold" into tStyle
      else if sMistakes and tV is not char i of sN["answer"] then
         put kWrong into tColor
         put "plain" into tStyle
      else
         put kWritten into tColor
         put "plain" into tStyle
      end if
      if tV is 0 then
         put paNotesText(sN["notes"][i], tN) into tNotes
         put empty into tV
      else
         put empty into tNotes
      end if
      paSquareLook i, tV, tBack, tColor, tStyle, tNotes
   end repeat
   -- a number that is everywhere it goes is done: its key is faint
   repeat with i = 1 to tN
      put 0 into tCount
      repeat with tKey = 1 to tN * tN
         if char tKey of sN["board"] is i then
            add 1 to tCount
         end if
      end repeat
      if tCount >= tN then
         set the textColor of button ("N Key" && i) to kFaint
      else
         set the textColor of button ("N Key" && i) to kInk
      end if
   end repeat
   paToggleLook "N Notes", sN["notes on"], "Notes: on", "Notes"
   if sN["daily"] then
      put "Today's" && tN && "by" && tN into tInfo
   else
      put "Practice," && tN && "by" && tN into tInfo
   end if
   if sN["hints"] is 1 then
      put ", 1 hint" after tInfo
   else if sN["hints"] > 1 then
      put "," && sN["hints"] && "hints" after tInfo
   end if
   set the text of field "N Info" to tInfo
   unlock screen
end paDrawBoard

-- A button that is on or off: green when on
private command paToggleLook pName, pOn, pOnLabel, pOffLabel
   local tShape
   put pName && "Shape" into tShape
   if pOn is true then
      set the cUp of graphic tShape to kLeaf
      set the cDown of graphic tShape to kLeafDown
      set the textColor of button pName to kWhite
      set the label of button pName to pOnLabel
   else
      set the cUp of graphic tShape to kKey
      set the cDown of graphic tShape to kKeyDown
      set the textColor of button pName to kInk
      set the label of button pName to pOffLabel
   end if
   set the backgroundColor of graphic tShape to the cUp of graphic tShape
end paToggleLook

-- One square: drawn only where it changed
private command paSquareLook pCell, pText, pBack, pColor, pStyle, pNotes
   local tLook
   put pText & "|" & pBack & "|" & pColor & "|" & pStyle & "|" & pNotes into tLook
   if sLook[pCell] is tLook then
      exit paSquareLook
   end if
   put tLook into sLook[pCell]
   set the text of field ("N Cell" && pCell) to pText
   set the backgroundColor of field ("N Cell" && pCell) to pBack
   set the textColor of field ("N Cell" && pCell) to pColor
   set the textStyle of field ("N Cell" && pCell) to pStyle
   set the text of field ("N Note" && pCell) to pNotes
end paSquareLook

-- A square's notes, each number in its place: 1 2 3 over 4 5 6 over
-- 7 8 9 (two columns for a grid of 4), parted by tabs
private function paNotesText pNotes, pN
   local tCols, tRows, r, c, tV, tOut
   if pNotes is empty then
      return empty
   end if
   if pN is 4 then
      put 2 into tCols
   else
      put 3 into tCols
   end if
   put pN div tCols into tRows
   repeat with r = 0 to tRows - 1
      repeat with c = 1 to tCols
         put r * tCols + c into tV
         if tV is in pNotes then
            put tV after tOut
         end if
         if c < tCols then
            put tab after tOut
         end if
      end repeat
      if r < tRows - 1 then
         put return after tOut
      end if
   end repeat
   return tOut
end paNotesText

----------------------------------------------------------------------
-- Hidden Word

-- Today's: as it was left, or new. Once solved (or out of tries), it
-- stays as it ended in the length it had
command paOpenWords
   local tDay, tLength, tSaved, tRow
   put paToday() into tDay
   put sLength into tLength
   put sSavedW["day"] is tDay into tSaved
   if tSaved and sSavedW["len"] is not sLength and sWLast is not tDay and paWordsOver(sSavedW) is empty then
      -- begun in another length: it starts again
      put false into tSaved
   end if
   if tSaved then
      put sSavedW["len"] into tLength
   end if
   paSetWords tLength, paDailyWord(tLength, tDay), true, tDay
   if tSaved then
      repeat for each item tRow in sSavedW["rows"]
         paAddTry tRow
      end repeat
   else if sWLast is tDay then
      -- solved, and its tries lost: the word alone
      paAddTry sW["answer"]
   end if
   paShowScreen "words"
   paDrawWords
   if sW["over"] is "won" then
      paMessage "Solved today. A new word comes tomorrow.", true
   else if sW["over"] is "lost" then
      paMessage "The word was" && toUpper(sW["answer"]) & ". A new one comes tomorrow.", true
   else
      paMessage "Type a word of" && sW["len"] && "letters, then Enter."
   end if
end paOpenWords

-- A practice word of pLength letters (not today's), or pWord (a test's)
command paStartWords pLength, pDaily, pWord
   local tCount, tLine, tToday, tTab
   if pLength is not among the items of "4,5,6" then
      put sLength into pLength
   end if
   put paToday() into tToday
   if pDaily is true then
      paSetWords pLength, paDailyWord(pLength, tToday), true, tToday
   else
      if pWord is not empty then
         put toLower(pWord) & tab & "A word of the test." into tLine
         put the length of pWord into pLength
      else
         put the number of lines of sAnswers[pLength] into tCount
         put line random(tCount) of sAnswers[pLength] into tLine
         if tLine is paDailyWord(pLength, tToday) then
            -- (not today's word: the one after it)
            put line (lineOffset(tLine, sAnswers[pLength]) mod tCount + 1) of sAnswers[pLength] into tLine
         end if
      end if
      paSetWords pLength, tLine, false, empty
   end if
   paDrawWords
   paMessage "Type a word of" && pLength && "letters, then Enter."
end paStartWords

private command paSetWords pLength, pLine, pDaily, pDay
   paFinishTurning
   put empty into sW
   put pLength into sW["len"]
   set the itemDelimiter to tab
   put toLower(item 1 of pLine) into sW["answer"]
   put item 2 of pLine into sW["meaning"]
   set the itemDelimiter to comma
   put empty into sW["rows"]
   put empty into sW["scores"]
   put empty into sW["typed"]
   put empty into sW["over"]
   put empty into sW["keys"]
   put pDaily is true into sW["daily"]
   put pDay into sW["day"]
   lock screen
   paLayoutWords
   unlock screen
end paSetWords

-- A try, scored, added to the board (and the keys told)
private command paAddTry pWord
   local tScore, i, tLetter, tWas
   put paScore(pWord, sW["answer"]) into tScore
   if sW["rows"] is empty then
      put pWord into sW["rows"]
      put tScore into sW["scores"]
   else
      put return & pWord after sW["rows"]
      put return & tScore after sW["scores"]
   end if
   repeat with i = 1 to the length of pWord
      put char i of pWord into tLetter
      put sW["keys"][tLetter] into tWas
      if char i of tScore is "g" or (char i of tScore is "b" and tWas is not "g") or tWas is empty then
         put char i of tScore into sW["keys"][tLetter]
      end if
   end repeat
   put paWordsOver(sW) into sW["over"]
end paAddTry

-- How a try did, a letter for each of its letters: g (the right place),
-- b (in the word, in another place) or s (not in it). A letter that is
-- twice in a try and once in the word is b or g once
function paScore pGuess, pAnswer
   local tLength, i, tOut, tLeft, tLetter
   put the length of pAnswer into tLength
   repeat with i = 1 to tLength
      if char i of pGuess is char i of pAnswer then
         put "g" after tOut
      else
         put "s" after tOut
         add 1 to tLeft[char i of pAnswer]
      end if
   end repeat
   repeat with i = 1 to tLength
      if char i of tOut is "s" then
         put char i of pGuess into tLetter
         if tLeft[tLetter] > 0 then
            put "b" into char i of tOut
            subtract 1 from tLeft[tLetter]
         end if
      end if
   end repeat
   return tOut
end paScore

-- won, lost or empty, for a puzzle's tries (as sW, or as saved)
private function paWordsOver pW
   local tRows, tAnswer
   put pW["rows"] into tRows
   replace comma with return in tRows
   if tRows is empty then
      return empty
   end if
   if pW["answer"] is not empty then
      put pW["answer"] into tAnswer
   else
      set the itemDelimiter to tab
      put item 1 of paDailyWord(pW["len"], pW["day"]) into tAnswer
      set the itemDelimiter to comma
   end if
   if tAnswer is among the lines of tRows then
      return "won"
   end if
   if the number of lines of tRows >= kTries then
      return "lost"
   end if
   return empty
end paWordsOver

-- Whether a try is a word
function paIsWord pWord
   return pWord is among the lines of sWords
end paIsWord

command paLetter pLetter
   if not paCanType() then
      exit paLetter
   end if
   if the length of sW["typed"] >= sW["len"] then
      exit paLetter
   end if
   put toLower(pLetter) after sW["typed"]
   paSound "place", 0.5
   paDrawWords
end paLetter

command paUnletter
   if not paCanType() then
      exit paUnletter
   end if
   if sW["typed"] is empty then
      exit paUnletter
   end if
   delete the last char of sW["typed"]
   paSound "erase", 0.5
   paDrawWords
end paUnletter

private function paCanType
   if sW["len"] is empty or sReveal["row"] > 0 then
      return false
   end if
   if sW["over"] is not empty then
      paMessage "Today's word is done. Try a practice one!"
      paSound "nope", 0.5
      return false
   end if
   return true
end paCanType

-- Enter: the try is scored, and its tiles turn one by one
command paTry
   local tWord, tRows
   if not paCanType() then
      exit paTry
   end if
   put sW["typed"] into tWord
   if the length of tWord < sW["len"] then
      paMessage "Not enough letters yet."
      paSound "nope", 0.5
      exit paTry
   end if
   if not paIsWord(tWord) then
      paMessage "That is not in this almanac's word list."
      paSound "nope", 0.5
      exit paTry
   end if
   put empty into sW["typed"]
   paAddTry tWord
   put empty into sAward
   if sW["over"] is "won" and sW["daily"] and sWLast is not sW["day"] then
      put paRunAfter(sWStreak, sWLast, sW["day"]) into sWStreak
      put sW["day"] into sWLast
      put paAward() into sAward
   else if sW["over"] is "lost" and sW["daily"] then
      put 0 into sWStreak
   end if
   paKeepProgress
   put the number of lines of sW["rows"] into tRows
   put tRows into sReveal["row"]
   put 0 into sReveal["t"]
   put 0 into sReveal["shown"]
   paMessage empty
   paDrawWords
   paSchedule
end paTry

-- The tiles of a try, turning: one every kTurn seconds
private command paTurnStep pDt
   local tShould
   add pDt to sReveal["t"]
   put min(sW["len"], 1 + trunc(sReveal["t"] / kTurn)) into tShould
   if tShould > sReveal["shown"] then
      put tShould into sReveal["shown"]
      paSound "reveal", 0.6
      paDrawWords
   end if
   if sReveal["t"] >= sW["len"] * kTurn + 0.3 then
      put 0 into sReveal["row"]
      paDrawWords
      paTurned
   end if
end paTurnStep

-- Every tile of a try turned: a word found, or the last try used, opens
-- Done
private command paTurned
   if sW["over"] is "won" then
      paSay "correct"
      paShowDone "words", true
   else if sW["over"] is "lost" then
      paShowDone "words", false
   end if
end paTurned

-- Every tile turned at once (when the board is left, or the page hidden)
private command paFinishTurning
   if sReveal["row"] > 0 then
      put 0 into sReveal["row"]
      paDrawWords
   end if
end paFinishTurning

-- The board as it is: the tries, the one being typed, the empty tiles,
-- the keys
command paDrawWords
   local tLength, tRows, r, c, i, tWord, tScore, tState
   if sW["len"] is empty then
      exit paDrawWords
   end if
   lock screen
   put sW["len"] into tLength
   put the number of lines of sW["rows"] into tRows
   repeat with r = 1 to kTries
      put empty into tWord
      put empty into tScore
      if r <= tRows then
         put line r of sW["rows"] into tWord
         put line r of sW["scores"] into tScore
      else if r is tRows + 1 and sW["over"] is empty then
         put sW["typed"] into tWord
      end if
      repeat with c = 1 to tLength
         put (r - 1) * tLength + c into i
         if c > the length of tWord then
            put empty into tState
         else if tScore is empty or (sReveal["row"] is r and c > sReveal["shown"]) then
            put "t" into tState
         else
            put char c of tScore into tState
         end if
         paTileLook i, char c of tWord, tState
      end repeat
   end repeat
   paKeysLook
   if sW["daily"] then
      put "Today's word:" && tLength && "letters" into tWord
   else
      put "Practice:" && tLength && "letters" into tWord
   end if
   if sW["over"] is empty then
      put ", try" && min(kTries, tRows + 1) && "of" && kTries after tWord
   end if
   set the text of field "W Info" to tWord
   unlock screen
end paDrawWords

-- A tile: empty (pState empty), typed (t), or turned: g, b, s
private command paTileLook pTile, pLetter, pState
   local tPicture, tRect, tSize
   if pState is empty then
      set the visible of button ("W Tile" && pTile) to false
      set the text of field ("W Letter" && pTile) to empty
      set the visible of graphic ("W Mark" && pTile) to false
      exit paTileLook
   end if
   switch pState
      case "g"
         put "tile-gold" into tPicture
         break
      case "b"
         put "tile-blue" into tPicture
         break
      case "s"
         put "tile-stone" into tPicture
         break
      default
         put "tile-marble" into tPicture
   end switch
   set the icon of button ("W Tile" && pTile) to sPic[tPicture]
   set the visible of button ("W Tile" && pTile) to true
   set the text of field ("W Letter" && pTile) to toUpper(pLetter)
   if pState is "g" then
      set the textColor of field ("W Letter" && pTile) to kInk
   else
      set the textColor of field ("W Letter" && pTile) to kWhite
   end if
   put sTileRect[pTile] into tRect
   paMark the long id of graphic ("W Mark" && pTile), pState, tRect
end paTileLook

-- A tile's mark, in its top right corner: a star for gold, a dot for
-- blue (none for stone, or a tile not yet turned)
private command paMark pGraphic, pState, pRect
   local tSize, tX, tY
   if pState is not "g" and pState is not "b" then
      set the visible of pGraphic to false
      exit paMark
   end if
   put item 3 of pRect - item 1 of pRect into tSize
   put item 3 of pRect - tSize * 0.2 into tX
   put item 2 of pRect + tSize * 0.2 into tY
   if pState is "g" then
      set the points of pGraphic to paStarPoints(tX, tY, max(4, tSize * 0.11))
      set the backgroundColor of pGraphic to kInk
   else
      set the points of pGraphic to paDotPoints(tX, tY, max(3, tSize * 0.07))
      set the backgroundColor of pGraphic to kWhite
   end if
   set the visible of pGraphic to true
end paMark

private function paStarPoints pX, pY, pR
   local i, tA, tR, tOut
   repeat with i = 0 to 10
      put -pi / 2 + i * pi / 5 into tA
      if i mod 2 is 0 then
         put pR into tR
      else
         put pR * 0.45 into tR
      end if
      put round(pX + tR * cos(tA)) & comma & round(pY + tR * sin(tA)) & return after tOut
   end repeat
   return char 1 to -2 of tOut
end paStarPoints

private function paDotPoints pX, pY, pR
   local i, tA, tOut
   repeat with i = 0 to 16
      put i * pi / 8 into tA
      put round(pX + pR * cos(tA)) & comma & round(pY + pR * sin(tA)) & return after tOut
   end repeat
   return char 1 to -2 of tOut
end paDotPoints

-- The keys, coloured as the turned tiles say each letter is
private command paKeysLook
   local tLetter, tState, tKnown, r, tRows, i, tScore, tWord
   -- the try still turning does not tell yet
   put the number of lines of sW["rows"] into tRows
   if sReveal["row"] > 0 then
      subtract 1 from tRows
   end if
   repeat with r = 1 to tRows
      put line r of sW["rows"] into tWord
      put line r of sW["scores"] into tScore
      repeat with i = 1 to the length of tWord
         put char i of tWord into tLetter
         put tKnown[tLetter] into tState
         if char i of tScore is "g" or (char i of tScore is "b" and tState is not "g") or tState is empty then
            put char i of tScore into tKnown[tLetter]
         end if
      end repeat
   end repeat
   repeat for each char tLetter in kLetters
      paKeyLook "W Key" && tLetter, tKnown[toLower(tLetter)]
   end repeat
end paKeysLook

private command paKeyLook pName, pState
   local tShape, tUp, tDown, tText
   put pName && "Shape" into tShape
   switch pState
      case "g"
         put kGold into tUp
         put kGoldDown into tDown
         put kInk into tText
         break
      case "b"
         put kBlue into tUp
         put kBlueDown into tDown
         put kWhite into tText
         break
      case "s"
         put kStone into tUp
         put kStoneDown into tDown
         put kWhite into tText
         break
      default
         put kKey into tUp
         put kKeyDown into tDown
         put kInk into tText
   end switch
   if the cUp of graphic tShape is tUp then
      exit paKeyLook
   end if
   set the cUp of graphic tShape to tUp
   set the cDown of graphic tShape to tDown
   set the backgroundColor of graphic tShape to tUp
   set the textColor of button pName to tText
end paKeyLook

----------------------------------------------------------------------
-- Done: a puzzle solved (or a word's last try used)

command paShowDone pKind, pWon
   local tTitle, tNote, tHints
   put pKind into sDoneKind
   lock screen
   if pKind is "words" then
      if pWon then
         put "Well done!" into tTitle
      else
         put "So close!" into tTitle
      end if
      set the text of field "Done Word" to toUpper(sW["answer"])
      set the text of field "Done Meaning" to sW["meaning"]
      set the visible of field "Done Word" to true
   else
      put "Solved!" into tTitle
      set the visible of field "Done Word" to false
      put sN["hints"] into tHints
      if tHints is 0 then
         set the text of field "Done Meaning" to "Every square, and no hints at all."
      else if tHints is 1 then
         set the text of field "Done Meaning" to "Every square, with one hint."
      else
         set the text of field "Done Meaning" to "Every square, with" && tHints && "hints."
      end if
   end if
   set the text of field "Done Title" to tTitle
   if sAward is "star" then
      set the icon of button "Done Sticker" to sPic["star"]
      put "Every sticker is in your book, so here is a gold star!" into tNote
   else if sAward is not empty then
      set the icon of button "Done Sticker" to sPic["animal-" & sAward]
      put "A new sticker for your book: the" && sAward & "!" into tNote
   else if pWon and paDoneDaily() then
      put "Today's is done. A new one comes tomorrow." into tNote
   else if pWon then
      put "Practice is just for fun: no sticker, as many as you like." into tNote
   else if sW["daily"] then
      put "A new word comes tomorrow." into tNote
   else
      put "Try another one!" into tNote
   end if
   set the visible of button "Done Sticker" to (sAward is not empty)
   set the text of field "Done Note" to tNote
   paLayoutDone
   paOpenPanel "done", false
   unlock screen
   if sAward is not empty then
      paSound "coins", 0.8
   else if pWon then
      paSound "open", 0.7
   else
      paSound "close", 0.6
   end if
   if pWon then
      paSay "congratulations"
      put 0 into sSparkT
      paSparkStep 0
      paSchedule
   end if
end paShowDone

-- Whether the puzzle Done is for was the day's
private function paDoneDaily
   if sDoneKind is "words" then
      return sW["daily"] is true
   end if
   return sN["daily"] is true
end paDoneDaily

-- The sparks: round the sticker (or the title), turning, breathing in
-- and out, and fading. sSparkR is how far out they go: across, down
private command paSparkStep pDt
   local i, tA, tR, tX, tY
   add pDt to sSparkT
   if sSparkT > 2.4 then
      paStopSparks
      exit paSparkStep
   end if
   repeat with i = 1 to 8
      put (i - 1) * pi / 4 + sSparkT * 1.2 into tA
      put 1 + 0.08 * sin(sSparkT * 5 + i) into tR
      put item 1 of sSparkAt + tR * item 1 of sSparkR * cos(tA) into tX
      put item 2 of sSparkAt + tR * item 2 of sSparkR * sin(tA) into tY
      set the loc of button ("Done Spark" && i) to round(tX), round(tY)
      set the blendLevel of button ("Done Spark" && i) to min(100, max(0, round((sSparkT - 1.6) * 120)))
      set the visible of button ("Done Spark" && i) to true
   end repeat
end paSparkStep

private command paStopSparks
   local i
   put empty into sSparkT
   repeat with i = 1 to 8
      set the visible of button ("Done Spark" && i) to false
   end repeat
end paStopSparks

----------------------------------------------------------------------
-- The sticker book

-- The book, open at the page of the newest sticker
command paShowStickers
   if sStickers > 15 then
      put 2 into sPage
   else
      put 1 into sPage
   end if
   paShowScreen "stickers"
end paShowStickers

private command paStickersLook
   local j, k, tName, tPicture
   lock screen
   if sPage is not 2 then
      put 1 into sPage
   end if
   repeat with j = 1 to 15
      put (sPage - 1) * 15 + j into k
      if k <= sStickers then
         put item k of kAnimals into tName
         put "animal-" & tName into tPicture
         set the icon of button ("S Slot" && j) to sPic[tPicture]
         paFit tPicture, sStickerBox
         paSprite "S Slot" && j, item 1 of sRing[j], item 2 of sRing[j]
         set the visible of button ("S Slot" && j) to true
         set the text of field ("S Name" && j) to toUpper(char 1 of tName) & char 2 to -1 of tName
         set the backgroundColor of graphic ("S Ring" && j) to "#FFF3D6"
         set the foregroundColor of graphic ("S Ring" && j) to kLeaf
      else
         set the visible of button ("S Slot" && j) to false
         set the text of field ("S Name" && j) to empty
         set the backgroundColor of graphic ("S Ring" && j) to "#F1E7D3"
         set the foregroundColor of graphic ("S Ring" && j) to kEdge
      end if
   end repeat
   set the text of field "S Count" to paStickerCount()
   paToggleLook "S Prev", sPage is 1, "Page 1", "Page 1"
   paToggleLook "S Next", sPage is 2, "Page 2", "Page 2"
   unlock screen
end paStickersLook

----------------------------------------------------------------------
-- What moves. Nothing runs while nothing moves; while something does,
-- paTick moves it on by the time since the last.

private command paSchedule
   if sManual or sLoop is not empty or sScreen is "closed" or not paMoving() then
      exit paSchedule
   end if
   put the milliseconds into sLast
   send "paTick" to me in 30 milliseconds
   put the result into sLoop
end paSchedule

private command paStopLoop
   if sLoop is not empty then
      cancel sLoop
      put empty into sLoop
   end if
end paStopLoop

private function paMoving
   return sReveal["row"] > 0 or sSparkT is a number or sShineUntil > 0 or sMessageUntil > 0
end paMoving

on paTick
   local tNow, tDt
   put empty into sLoop
   if sManual or sScreen is "closed" then
      exit paTick
   end if
   set the defaultStack to the short name of me
   put the milliseconds into tNow
   put max(0, min(0.1, (tNow - sLast) / 1000)) into tDt
   lock screen
   paAdvance tDt
   unlock screen
   paSchedule
end paTick

command paAdvance pDt
   add pDt to sClock
   if sReveal["row"] > 0 then
      paTurnStep pDt
   end if
   if sSparkT is a number then
      paSparkStep pDt
   end if
   if sShineUntil > 0 and sClock >= sShineUntil then
      paStopShine
      paDrawBoard
   end if
   if sMessageUntil > 0 and sClock >= sMessageUntil then
      put 0 into sMessageUntil
      set the text of field "N Message" to empty
      set the text of field "W Message" to empty
   end if
end paAdvance

private command paStopShine
   put empty into sShine
   put 0 into sShineUntil
end paStopShine

private command paStopMoving
   put empty into sReveal
   put 0 into sReveal["row"]
   paStopSparks
   paStopShine
   put 0 into sMessageUntil
end paStopMoving

-- A message under the board, for a while (or to stay, pStay)
command paMessage pText, pStay
   set the text of field "N Message" to pText
   set the text of field "W Message" to pText
   if pStay is true or pText is empty then
      put 0 into sMessageUntil
   else
      put sClock + kMessageFor into sMessageUntil
      paSchedule
   end if
end paMessage

----------------------------------------------------------------------
-- Pictures at the size a screen draws them

-- A picture of the Art card drawn to fit a square of pBox points (every
-- button showing it changes with it)
private command paFit pPicture, pBox
   local tW, tH, tScale, tImage
   put item 1 of sNatural[pPicture] into tW
   put item 2 of sNatural[pPicture] into tH
   if tW is empty then
      exit paFit
   end if
   put pBox / max(tW, tH) into tScale
   put max(1, round(tW * tScale)) into tW
   put max(1, round(tH * tScale)) into tH
   put the long id of image pPicture of card "Art" of me into tImage
   if the width of tImage is not tW or the height of tImage is not tH then
      set the rect of tImage to the left of tImage, the top of tImage, the left of tImage + tW, the top of tImage + tH
   end if
end paFit

-- A sprite, centred on pX, pY at its picture's size
private command paSprite pName, pX, pY
   local tId, tW, tH, tL, tT
   put the icon of button pName into tId
   put the width of image id tId of card "Art" of me into tW
   put the height of image id tId of card "Art" of me into tH
   put round(pX - tW / 2) into tL
   put round(pY - tH / 2) into tT
   set the rect of button pName to tL, tT, tL + tW, tT + tH
end paSprite

-- The pictures at the sizes the screen shown draws them: the tiles (one
-- size on Home and How to play, another in Hidden Word), the owl and the
-- stars of Home
private command paSizes
   local tTile, tPicture
   if sScreen is "words" then
      put sT into tTile
   else
      put sHomeT into tTile
   end if
   repeat for each item tPicture in "tile-marble,tile-gold,tile-blue,tile-stone"
      paFit tPicture, tTile
   end repeat
   if sScreen is "home" then
      paFit "animal-owl", 72
      paFit "star", 30
      paLayoutHomeArt
   else if sScreen is "words" then
      paLayoutWordsTiles
   else if sScreen is "stickers" then
      paStickersLook
   end if
   paLayoutHowtoTiles
end paSizes

-- The look of things that never change: the sparks, gold and blue by
-- turns; the three tiles of How to play; the cards' colours when pressed
private command paLooks
   local i
   repeat with i = 2 to 8 step 2
      set the icon of button ("Done Spark" && i) to sPic["sparkle-blue"]
   end repeat
   set the textColor of field "Howto Letter 1" to kInk
   set the textColor of field "Howto Letter 2" to kWhite
   set the textColor of field "Howto Letter 3" to kWhite
   set the visible of graphic "Howto Mark 3" to false
   repeat for each item i in "Numbers Card,Words Card"
      set the cUp of graphic (i && "Shape") to kCard
      set the cDown of graphic (i && "Shape") to kCardDown
   end repeat
end paLooks

----------------------------------------------------------------------
-- Layout: the window, in points

on paResized
   set the defaultStack to the short name of me
   lock screen
   paLayout
   paSizes
   paDrawBoard
   paDrawWords
   unlock screen
end paResized

-- The part of the screen under a notch, a rounded corner or the home bar:
-- the library's safe-area insets, 0 without it
private function paInset pSide
   local tView
   if not sLibrary then
      return 0
   end if
   try
      put mwViewport() into tView
   end try
   if tView[pSide] is not a number then
      return 0
   end if
   return max(0, tView[pSide])
end paInset

command paLayout
   set the defaultStack to the short name of me
   lock screen
   put the width of me into sWidth
   put the height of me into sHeight
   put paInset("top") into sInsetT
   put paInset("bottom") into sInsetB
   put paInset("left") into sInsetL
   put paInset("right") into sInsetR
   -- wide: a phone on its side or a window, with room for two parts side
   -- by side; short: less room above and below
   put sWidth >= 600 and sWidth >= sHeight * 1.2 into sSide
   put sHeight - sInsetT - sInsetB < 640 into sCompact
   if sCompact then
      put 36 into sHomeT
   else
      put 44 into sHomeT
   end if
   put sInsetT + 58 into sTopY
   put sHeight - sInsetB - 12 into sBottomY
   set the rect of graphic "Shade" to 0, 0, sWidth, sHeight
   paLayoutTop
   paLayoutHome
   paLayoutNumbers
   paLayoutWords
   paLayoutStickers
   paLayoutPractice
   paLayoutHowto
   paLayoutSettings
   paLayoutDone
   unlock screen
end paLayout

-- A button and its shape
private command paPlaceButton pName, pL, pT, pR, pB
   set the rect of button pName to round(pL), round(pT), round(pR), round(pB)
   set the rect of graphic (pName && "Shape") to round(pL), round(pT), round(pR), round(pB)
   set the roundRadius of graphic (pName && "Shape") to min(14, round((pB - pT) / 3))
end paPlaceButton

-- A field of words pWidth wide from pL, pT; returns its bottom
private function paPlaceText pName, pL, pT, pR
   set the width of field pName to round(pR - pL)
   set the rect of field pName to round(pL), round(pT), round(pR), round(pT) + the formattedHeight of field pName
   return the bottom of field pName
end paPlaceText

private command paLayoutTop
   paPlaceButton "Back", sInsetL + 12, sInsetT + 10, sInsetL + 104, sInsetT + 50
   set the rect of field "Top Title" to sInsetL + 110, sInsetT + 16, sWidth - sInsetR - 110, sInsetT + 44
end paLayoutTop

-- Home: the owl, the title and the day; the two puzzles' cards (one over
-- the other, or side by side), the stickers and runs, four buttons
private command paLayoutHome
   local tCW, tL, tR, tY, tCH, tMid, tBH, tW, i, tName, tNeed
   put sWidth div 2 into tMid
   if sSide then
      put min(sWidth - 32, 760) into tCW
   else
      put min(sWidth - 32, 440) into tCW
   end if
   put tMid - tCW div 2 into tL
   put tL + tCW into tR
   if sCompact then
      put 100 into tCH
      put 42 into tBH
   else
      put 116 into tCH
      put 48 into tBH
   end if
   -- all of it in the middle of the screen, top to bottom
   put 42 + 34 + tCH + 12 + paPlaceText("Home Streak", tL, 0, tR) + 10 + tBH into tNeed
   if not sCompact then
      add 80 to tNeed
   end if
   if not sSide then
      add tCH + 12 + tBH + 10 to tNeed
   end if
   put sInsetT + 14 + max(0, (sHeight - sInsetT - sInsetB - 28 - tNeed) div 2) into tY
   set the visible of button "Home Mascot" to not sCompact
   if not sCompact then
      set the loc of button "Home Mascot" to tMid, tY + 36
      add 80 to tY
   end if
   set the rect of field "Home Title" to tL, tY, tR, tY + 40
   add 42 to tY
   set the rect of field "Home Date" to tL, tY, tR, tY + 22
   add 34 to tY
   if sSide then
      paLayoutCard "Numbers", tL, tY, tMid - 6, tY + tCH
      paLayoutCard "Words", tMid + 6, tY, tR, tY + tCH
      add tCH + 12 to tY
   else
      paLayoutCard "Numbers", tL, tY, tR, tY + tCH
      add tCH + 12 to tY
      paLayoutCard "Words", tL, tY, tR, tY + tCH
      add tCH + 12 to tY
   end if
   put paPlaceText("Home Streak", tL, tY, tR) + 10 into tY
   if sSide then
      put (tCW - 3 * 10) / 4 into tW
      put 0 into i
      repeat for each item tName in "Practice Open,Stickers Open,Howto Open,Settings Open"
         paPlaceButton tName, tL + i * (tW + 10), tY, tL + i * (tW + 10) + tW, tY + tBH
         add 1 to i
      end repeat
   else
      put (tCW - 10) / 2 into tW
      paPlaceButton "Practice Open", tL, tY, tL + tW, tY + tBH
      paPlaceButton "Stickers Open", tR - tW, tY, tR, tY + tBH
      add tBH + 10 to tY
      paPlaceButton "Howto Open", tL, tY, tL + tW, tY + tBH
      paPlaceButton "Settings Open", tR - tW, tY, tR, tY + tBH
   end if
end paLayoutHome

-- A puzzle's card: its picture at the left (a little grid, or three
-- tiles), its name, size and state, and a star once it is solved
private command paLayoutCard pKind, pL, pT, pR, pB
   local tArt, tX, tTop
   set the rect of graphic (pKind && "Card Shape") to pL, pT, pR, pB
   set the rect of button (pKind && "Card") to pL, pT, pR, pB
   put round(sHomeT * 1.9) into tArt
   put pL + 16 + tArt + 14 into tX
   if sCompact then
      put pT + 12 into tTop
   else
      put pT + 18 into tTop
   end if
   set the rect of field (pKind && "Card Title") to tX, tTop, pR - 48, tTop + 28
   set the rect of field (pKind && "Card Sub") to tX, tTop + 30, pR - 12, tTop + 50
   set the rect of field (pKind && "Card State") to tX, tTop + 54, pR - 12, tTop + 76
   set the loc of button (pKind && "Card Badge") to pR - 28, pT + 28
end paLayoutCard

-- The cards' pictures, which follow the tile size of Home
private command paLayoutHomeArt
   local tShape, tL, tT, tB, tArt, tSide, tX, tY, tPoints, k, tCell
   put round(sHomeT * 1.9) into tArt
   -- the little grid, with a few numbers
   put the rect of graphic "Numbers Card Shape" into tShape
   put item 1 of tShape + 16 into tL
   put item 2 of tShape into tT
   put item 4 of tShape into tB
   put min(tArt, tB - tT - 28) into tSide
   put tSide div 3 into tCell
   put tCell * 3 into tSide
   put tL + (tArt - tSide) div 2 into tX
   put (tT + tB) div 2 - tSide div 2 into tY
   put tX & comma & tY & return & tX + tSide & comma & tY & return & tX + tSide & comma & tY + tSide & return & \
         tX & comma & tY + tSide & return & tX & comma & tY into tPoints
   repeat with k = 1 to 2
      put return & return & tX + k * tCell & comma & tY & return & tX + k * tCell & comma & tY + tSide after tPoints
      put return & return & tX & comma & tY + k * tCell & return & tX + tSide & comma & tY + k * tCell after tPoints
   end repeat
   set the points of graphic "Numbers Card Grid" to tPoints
   set the rect of field "Numbers Card Digits" to tX, tY, tX + tSide, tY + tSide
   set the textSize of field "Numbers Card Digits" to max(10, round(tCell * 0.6))
   set the textHeight of field "Numbers Card Digits" to tCell
   set the tabStops of field "Numbers Card Digits" to tCell
   set the leftMargin of field "Numbers Card Digits" to max(0, round(tCell / 2 - tCell * 0.17))
   set the topMargin of field "Numbers Card Digits" to 0
   set the text of field "Numbers Card Digits" to "3" & tab & tab & "8" & return & tab & "5" & return & "1" & tab & tab & "6"
   -- three tiles, fanned
   put the rect of graphic "Words Card Shape" into tShape
   put item 1 of tShape + 16 into tL
   put (item 2 of tShape + item 4 of tShape) div 2 into tY
   repeat with k = 1 to 3
      paSprite "Words Card Tile" && k, tL + sHomeT / 2 + (k - 1) * sHomeT * 0.45, tY + (k - 2) * 7
   end repeat
   -- the stars of solved puzzles
   repeat for each item k in "Numbers,Words"
      put the loc of button (k && "Card Badge") into tShape
      paSprite k && "Card Badge", item 1 of tShape, item 2 of tShape
   end repeat
   put the loc of button "Home Mascot" into tShape
   paSprite "Home Mascot", item 1 of tShape, item 2 of tShape
end paLayoutHomeArt

-- Number Place: the line over the board, the board, the message, the
-- number keys and the four tools under it; or, on a wide screen, the
-- board at the left and the keys in a block at its right
command paLayoutNumbers
   local tN, tCW, tL, tR, tY, tKeyH, tToolH, tBelow, tSide, tCell, tX, tW, k, tGap, tCols, tRows
   local tRightW, tTotal, tX1, tKeyW, tHeight, tTop, tName
   put sN["n"] into tN
   if tN is empty then
      put sSize into tN
   end if
   if sCompact then
      put 46 into tKeyH
      put 40 into tToolH
   else
      put 54 into tKeyH
      put 46 into tToolH
   end if
   if not sSide then
      put min(sWidth, 520) into tCW
      put (sWidth - tCW) div 2 into tL
      put tL + tCW into tR
      put sTopY into tY
      set the rect of field "N Info" to tL + 12, tY, tR - 12, tY + 22
      add 28 to tY
      put 8 + 26 + 8 + tKeyH + 10 + tToolH into tBelow
      put min(tCW - 28, sBottomY - tY - tBelow) into tSide
      put max(16, min(paLargestSquare(tN), tSide div tN)) into tCell
      put tCell * tN into tSide
      paPlaceGrid tL + (tCW - tSide) div 2, tY, tCell, tN
      put tY + tSide + 8 into tY
      set the rect of field "N Message" to tL + 12, tY, tR - 12, tY + 26
      add 34 to tY
      put 6 into tGap
      put min(72, (tCW - 24 - (tN - 1) * tGap) / tN) into tW
      put tL + (tCW - (tN * tW + (tN - 1) * tGap)) / 2 into tX
      repeat with k = 1 to tN
         paPlaceButton "N Key" && k, tX + (k - 1) * (tW + tGap), tY, tX + (k - 1) * (tW + tGap) + tW, tY + tKeyH
      end repeat
      add tKeyH + 10 to tY
      put min(110, (tCW - 24 - 3 * 8) / 4) into tW
      put tL + (tCW - (4 * tW + 3 * 8)) / 2 into tX
      put 0 into k
      repeat for each item tName in "N Notes,N Erase,N Undo,N Hint"
         paPlaceButton tName, tX + k * (tW + 8), tY, tX + k * (tW + 8) + tW, tY + tToolH
         add 1 to k
      end repeat
   else
      put sBottomY - sTopY into tHeight
      put min(tHeight - 28, round(sWidth * 0.55) - 24) into tSide
      put max(16, min(paLargestSquare(tN), tSide div tN)) into tCell
      put tCell * tN into tSide
      put min(340, sWidth - tSide - 80) into tRightW
      put tSide + 36 + tRightW into tTotal
      put (sWidth - tTotal) div 2 into tX
      -- (in the middle, top to bottom, when there is room to spare)
      put sTopY + max(0, (tHeight - 28 - tSide) div 2) into tTop
      set the rect of field "N Info" to tX, tTop, tX + tSide, tTop + 22
      paPlaceGrid tX, tTop + 28, tCell, tN
      put tTop + 28 into tY
      -- the keys in a block: three across (two for a grid of 4)
      put tX + tSide + 36 into tX1
      if tN is 4 then
         put 2 into tCols
      else
         put 3 into tCols
      end if
      put tN div tCols into tRows
      put 8 into tGap
      put min(80, (tRightW - (tCols - 1) * tGap) / tCols) into tKeyW
      put min(tKeyH + 6, (tSide - 2 * tToolH - tGap - 18 - 34 - (tRows - 1) * tGap) / tRows) into tKeyH
      put tRows * tKeyH + (tRows - 1) * tGap + 18 + 2 * tToolH + tGap + 34 into tHeight
      put tY + max(0, (tSide - tHeight) div 2) into tTop
      put tX1 + (tRightW - (tCols * tKeyW + (tCols - 1) * tGap)) / 2 into tX
      repeat with k = 1 to tN
         paPlaceButton "N Key" && k, tX + ((k - 1) mod tCols) * (tKeyW + tGap), \
               tTop + ((k - 1) div tCols) * (tKeyH + tGap), \
               tX + ((k - 1) mod tCols) * (tKeyW + tGap) + tKeyW, \
               tTop + ((k - 1) div tCols) * (tKeyH + tGap) + tKeyH
      end repeat
      put tTop + tRows * tKeyH + (tRows - 1) * tGap + 18 into tY
      put (tRightW - tGap) / 2 into tW
      paPlaceButton "N Notes", tX1, tY, tX1 + tW, tY + tToolH
      paPlaceButton "N Erase", tX1 + tW + tGap, tY, tX1 + tRightW, tY + tToolH
      add tToolH + tGap to tY
      paPlaceButton "N Undo", tX1, tY, tX1 + tW, tY + tToolH
      paPlaceButton "N Hint", tX1 + tW + tGap, tY, tX1 + tRightW, tY + tToolH
      add tToolH + 8 to tY
      set the rect of field "N Message" to tX1 - 10, tY, tX1 + tRightW + 10, tY + 26
      set the dontWrap of field "N Message" to false
   end if
   repeat with k = 1 to 9
      set the visible of button ("N Key" && k) to k <= tN
      set the visible of graphic ("N Key" && k && "Shape") to k <= tN
      set the textSize of button ("N Key" && k) to 22
   end repeat
end paLayoutNumbers

-- The biggest square of a grid of pN squares a side: a grid of 4 in a
-- window is not a wall
private function paLargestSquare pN
   if pN is 4 then
      return 96
   else if pN is 6 then
      return 80
   end if
   return 64
end paLargestSquare

-- The grid: its squares (a number each, and notes over it), its lines,
-- thin between squares and thick between boxes, and the board under it
private command paPlaceGrid pX, pY, pCell, pN
   local i, r, c, tRect, tSize, tLine, tNoteSize, tCols, tRows, tSide, tThin, tThick, k, tBoxRows, tBoxCols
   put pCell * pN into tSide
   put pX, pY, pCell into sBoard
   put round(pCell * 0.56) into tSize
   put max(8, min(16, round(pCell * 0.25))) into tNoteSize
   if pN is 4 then
      put 2 into tCols
   else
      put 3 into tCols
   end if
   put pN div tCols into tRows
   put paBoxRows(pN) into tBoxRows
   put pN div tBoxRows into tBoxCols
   repeat with i = 1 to 81
      if i > pN * pN then
         set the visible of field ("N Cell" && i) to false
         set the visible of field ("N Note" && i) to false
         next repeat
      end if
      put (i - 1) div pN into r
      put (i - 1) mod pN into c
      put pX + c * pCell, pY + r * pCell, pX + (c + 1) * pCell, pY + (r + 1) * pCell into tRect
      set the rect of field ("N Cell" && i) to tRect
      set the textSize of field ("N Cell" && i) to tSize
      set the textHeight of field ("N Cell" && i) to round(tSize * 1.25)
      set the topMargin of field ("N Cell" && i) to paMiddle(pCell, tSize)
      set the visible of field ("N Cell" && i) to true
      set the rect of field ("N Note" && i) to item 1 of tRect + 1, item 2 of tRect + 1, item 3 of tRect - 1, item 4 of tRect - 1
      set the textSize of field ("N Note" && i) to tNoteSize
      set the textHeight of field ("N Note" && i) to (pCell - 2) div tRows
      set the tabStops of field ("N Note" && i) to (pCell - 2) div tCols
      set the textAlign of field ("N Note" && i) to "left"
      set the leftMargin of field ("N Note" && i) to max(0, round((pCell - 2) / tCols / 2 - tNoteSize * 0.28))
      set the topMargin of field ("N Note" && i) to 0
      set the visible of field ("N Note" && i) to true
   end repeat
   -- the lines: a gap between each in the points
   repeat with k = 1 to pN - 1
      put pX + k * pCell & comma & pY & return & pX + k * pCell & comma & pY + tSide & return & return after tThin
      put pX & comma & pY + k * pCell & return & pX + tSide & comma & pY + k * pCell & return & return after tThin
      if k mod tBoxCols is 0 then
         put pX + k * pCell & comma & pY & return & pX + k * pCell & comma & pY + tSide & return & return after tThick
      end if
      if k mod tBoxRows is 0 then
         put pX & comma & pY + k * pCell & return & pX + tSide & comma & pY + k * pCell & return & return after tThick
      end if
   end repeat
   put pX & comma & pY & return & pX + tSide & comma & pY & return & pX + tSide & comma & pY + tSide & return & \
         pX & comma & pY + tSide & return & pX & comma & pY after tThick
   set the points of graphic "N Thin" to char 1 to -3 of tThin
   set the points of graphic "N Thick" to tThick
   set the rect of graphic "N Board" to pX - 8, pY - 8, pX + tSide + 8, pY + tSide + 8
   set the roundRadius of graphic "N Board" to 10
   set the lineSize of graphic "N Board" to 1
   set the foregroundColor of graphic "N Board" to kEdge
   put empty into sLook
end paPlaceGrid

-- The top margin that puts a line of pSize points (a number, a letter)
-- in the middle of a square pBox points high: half of what the line
-- leaves, and a little more, as a capital or a figure sits high in its
-- line
private function paMiddle pBox, pSize
   return max(0, (pBox - round(pSize * 1.25)) div 2 + round(pSize * 0.12) + 2)
end paMiddle

-- Hidden Word: the line over the tiles, six rows of tiles, the message
-- and the keyboard; or, on a wide screen, the tiles at the left and the
-- keyboard at their right
command paLayoutWords
   local tLength, tCW, tL, tR, tY, tKeyH, tBelow, tGap, tGridW, tX, tRightW, tTotal, tX1, tTop
   put sW["len"] into tLength
   if tLength is empty then
      put sLength into tLength
   end if
   put 6 into tGap
   if sCompact then
      put 42 into tKeyH
   else
      put 50 into tKeyH
   end if
   if not sSide then
      put min(sWidth, 520) into tCW
      put (sWidth - tCW) div 2 into tL
      put tL + tCW into tR
      put sTopY into tY
      set the rect of field "W Info" to tL + 12, tY, tR - 12, tY + 22
      add 28 to tY
      put 8 + 26 + 10 + 3 * tKeyH + 2 * 8 into tBelow
      put min(64, (tCW - 32 - (tLength - 1) * tGap) div tLength, \
            (sBottomY - tY - tBelow - (kTries - 1) * tGap) div kTries) into sT
      put max(20, sT) into sT
      put tLength * sT + (tLength - 1) * tGap into tGridW
      paPlaceTiles tL + (tCW - tGridW) div 2, tY, tLength, tGap
      put tY + kTries * sT + (kTries - 1) * tGap + 8 into tY
      set the rect of field "W Message" to tL + 12, tY, tR - 12, tY + 26
      set the dontWrap of field "W Message" to true
      add 36 to tY
      paPlaceKeyboard tL + 6, tY, tR - 6, tKeyH
   else
      put min(64, (sBottomY - sTopY - 28 - (kTries - 1) * tGap) div kTries) into sT
      put max(20, sT) into sT
      put tLength * sT + (tLength - 1) * tGap into tGridW
      put min(460, sWidth - tGridW - 80) into tRightW
      put tGridW + 40 + tRightW into tTotal
      put (sWidth - tTotal) div 2 into tX
      put sTopY + max(0, (sBottomY - sTopY - 28 - (kTries * sT + (kTries - 1) * tGap)) div 2) into tY
      set the rect of field "W Info" to tX - 20, tY, tX + tGridW + 20, tY + 22
      paPlaceTiles tX, tY + 28, tLength, tGap
      put tX + tGridW + 40 into tX1
      put min(tKeyH, (sBottomY - sTopY - 28 - 50 - 2 * 8) div 3) into tKeyH
      put tY + 28 + max(0, (kTries * sT + (kTries - 1) * tGap - (50 + 3 * tKeyH + 2 * 8)) div 2) into tTop
      set the rect of field "W Message" to tX1, tTop, tX1 + tRightW, tTop + 40
      set the dontWrap of field "W Message" to false
      paPlaceKeyboard tX1, tTop + 50, tX1 + tRightW, tKeyH
   end if
end paLayoutWords

-- Where each tile goes (shown or hidden by the length of the word)
private command paPlaceTiles pX, pY, pLength, pGap
   local r, c, i, tRect, tSize
   put empty into sTileRect
   repeat with r = 1 to kTries
      repeat with c = 1 to pLength
         put (r - 1) * pLength + c into i
         put pX + (c - 1) * (sT + pGap), pY + (r - 1) * (sT + pGap), \
               pX + (c - 1) * (sT + pGap) + sT, pY + (r - 1) * (sT + pGap) + sT into sTileRect[i]
      end repeat
   end repeat
   put round(sT * 0.5) into tSize
   repeat with i = 1 to 36
      if i > pLength * kTries then
         set the visible of graphic ("W Slot" && i) to false
         set the visible of button ("W Tile" && i) to false
         set the visible of field ("W Letter" && i) to false
         set the visible of graphic ("W Mark" && i) to false
         next repeat
      end if
      put sTileRect[i] into tRect
      set the rect of graphic ("W Slot" && i) to item 1 of tRect + 2, item 2 of tRect + 2, item 3 of tRect - 2, item 4 of tRect - 2
      set the roundRadius of graphic ("W Slot" && i) to max(4, round(sT / 8))
      set the visible of graphic ("W Slot" && i) to true
      set the rect of field ("W Letter" && i) to tRect
      set the textSize of field ("W Letter" && i) to tSize
      set the textHeight of field ("W Letter" && i) to round(tSize * 1.25)
      set the topMargin of field ("W Letter" && i) to paMiddle(sT, tSize)
      set the visible of field ("W Letter" && i) to true
   end repeat
   paLayoutWordsTiles
end paPlaceTiles

-- The tiles' buttons, at the size of their pictures
private command paLayoutWordsTiles
   local i, tRect
   repeat for each key i in sTileRect
      put sTileRect[i] into tRect
      paSprite "W Tile" && i, (item 1 of tRect + item 3 of tRect) / 2, (item 2 of tRect + item 4 of tRect) / 2
   end repeat
end paLayoutWordsTiles

-- The keyboard: three rows, the third with Enter and Delete at its ends
private command paPlaceKeyboard pL, pT, pR, pKeyH
   local tGap, tW, tX, tY, k, tLetter, tWide, tSize
   put 5 into tGap
   put (pR - pL - 9 * tGap) / 10 into tW
   put round(min(20, tW * 0.55)) into tSize
   repeat with k = 1 to 26
      put char k of kLetters into tLetter
      if k <= 10 then
         put pL + (k - 1) * (tW + tGap) into tX
         put pT into tY
      else if k <= 19 then
         put pL + (tW + tGap) / 2 + (k - 11) * (tW + tGap) into tX
         put pT + pKeyH + 8 into tY
      else
         put pL + 1.5 * tW + tGap * 1.5 + (k - 20) * (tW + tGap) into tX
         put pT + 2 * (pKeyH + 8) into tY
      end if
      paPlaceButton "W Key" && tLetter, tX, tY, tX + tW, tY + pKeyH
      set the textSize of button ("W Key" && tLetter) to tSize
   end repeat
   put pT + 2 * (pKeyH + 8) into tY
   put 1.5 * tW + tGap / 2 into tWide
   paPlaceButton "W Key Enter", pL, tY, pL + tWide, tY + pKeyH
   paPlaceButton "W Key Back", pR - tWide, tY, pR, tY + pKeyH
   set the textSize of button "W Key Enter" to max(11, min(16, round(tWide / 4.2)))
   set the textSize of button "W Key Back" to max(11, min(16, round(tWide / 4.2)))
end paPlaceKeyboard

-- The sticker book: a page of 15 rings, 3 across (5 on a wide screen),
-- and the pages' buttons under it
private command paLayoutStickers
   local tCW, tL, tR, tPageT, tPageB, tCols, tRows, tCellW, tCellH, tD, j, tCX, tCY, tMid, tBH
   put sWidth div 2 into tMid
   if sSide then
      put min(sWidth - 32, 820) into tCW
      put 5 into tCols
      put 3 into tRows
   else
      put min(sWidth - 32, 520) into tCW
      put 3 into tCols
      put 5 into tRows
   end if
   if sCompact then
      put 42 into tBH
   else
      put 48 into tBH
   end if
   put tMid - tCW div 2 into tL
   put tL + tCW into tR
   set the rect of field "S Count" to tL, sTopY, tR, sTopY + 26
   put sTopY + 32 into tPageT
   put sBottomY - tBH - 12 into tPageB
   set the rect of graphic "S Page" to tL, tPageT, tR, tPageB
   put (tCW - 16) / tCols into tCellW
   put (tPageB - tPageT - 16) / tRows into tCellH
   put max(30, min(tCellW - 14, tCellH - 26, 110)) into tD
   put round(tD * 0.78) into sStickerBox
   repeat with j = 1 to 15
      put tL + 8 + ((j - 1) mod tCols + 0.5) * tCellW into tCX
      put tPageT + 8 + ((j - 1) div tCols) * tCellH + (tCellH - 18) / 2 into tCY
      put round(tCX), round(tCY) into sRing[j]
      set the rect of graphic ("S Ring" && j) to round(tCX - tD / 2), round(tCY - tD / 2), round(tCX - tD / 2) + tD, round(tCY - tD / 2) + tD
      set the rect of field ("S Name" && j) to round(tCX - tCellW / 2), round(tCY + tD / 2 + 2), round(tCX + tCellW / 2), round(tCY + tD / 2 + 18)
   end repeat
   paPlaceButton "S Prev", tMid - 130, sBottomY - tBH, tMid - 6, sBottomY
   paPlaceButton "S Next", tMid + 6, sBottomY - tBH, tMid + 130, sBottomY
end paLayoutStickers

-- A panel's place: centred, and as high as it needs (pHeight)
private function paPanelTop pHeight
   return sInsetT + 12 + max(0, (sHeight - sInsetT - sInsetB - 24 - pHeight) div 2)
end paPanelTop

private command paLayoutPractice
   local tPW, tL, tR, tBH, tHeight, tT, tY, tW, k, tName
   put min(sWidth - 32, 380) into tPW
   put (sWidth - tPW) div 2 into tL
   put tL + tPW into tR
   if sCompact then
      put 42 into tBH
   else
      put 48 into tBH
   end if
   put paPlaceText("Practice Text", tL + 24, 0, tR - 24) into tHeight
   put 20 + 38 + tHeight + 10 + 30 + tBH + 16 + 30 + tBH + 20 + tBH + 22 into tHeight
   put paPanelTop(tHeight) into tT
   put tT + 20 into tY
   set the rect of field "Practice Title" to tL + 20, tY, tR - 20, tY + 30
   put paPlaceText("Practice Text", tL + 24, tY + 38, tR - 24) + 10 into tY
   put (tPW - 48 - 2 * 8) / 3 into tW
   set the rect of field "Practice Numbers" to tL + 20, tY, tR - 20, tY + 24
   add 30 to tY
   put 0 into k
   repeat for each item tName in "P N4,P N6,P N9"
      paPlaceButton tName, tL + 24 + k * (tW + 8), tY, tL + 24 + k * (tW + 8) + tW, tY + tBH
      add 1 to k
   end repeat
   add tBH + 16 to tY
   set the rect of field "Practice Words" to tL + 20, tY, tR - 20, tY + 24
   add 30 to tY
   put 0 into k
   repeat for each item tName in "P W4,P W5,P W6"
      paPlaceButton tName, tL + 24 + k * (tW + 8), tY, tL + 24 + k * (tW + 8) + tW, tY + tBH
      add 1 to k
   end repeat
   add tBH + 20 to tY
   paPlaceButton "Practice Close", tL + 24, tY, tR - 24, tY + tBH
   add tBH + 22 to tY
   set the rect of graphic "Practice Panel" to tL, tT, tR, tY
end paLayoutPractice

-- How to play: the two puzzles' rules, the three tiles and what each
-- says, the daily note; in two columns on a wide screen. The words a
-- size smaller where they would not fit
private command paLayoutHowto
   local tTwo, tPW, tL, tR, tSize, tBottom, tTall, tT, tY, tBH, tName
   put sSide into tTwo
   if tTwo then
      put min(sWidth - 32, 760) into tPW
   else
      put min(sWidth - 32, 400) into tPW
   end if
   put (sWidth - tPW) div 2 into tL
   put tL + tPW into tR
   put sHeight - sInsetT - sInsetB - 24 into tTall
   if sCompact then
      put 42 into tBH
   else
      put 48 into tBH
   end if
   repeat for each item tSize in "15,14,13,12"
      repeat for each item tName in "Howto Numbers,Howto Words,Howto Daily,Howto Key 1,Howto Key 2,Howto Key 3"
         set the textSize of field tName to tSize
      end repeat
      put paHowtoBody(tL, tR, 0, tTwo) into tBottom
      if tBottom + 20 + 36 + 14 + tBH + 22 <= tTall then
         exit repeat
      end if
   end repeat
   put paPanelTop(tBottom + 20 + 36 + 14 + tBH + 22) into tT
   set the rect of field "Howto Title" to tL + 20, tT + 18, tR - 20, tT + 48
   put paHowtoBody(tL, tR, tT + 56, tTwo) into tY
   add 14 to tY
   paPlaceButton "Howto Done", (tL + tR) div 2 - 110, tY, (tL + tR) div 2 + 110, tY + tBH
   set the rect of graphic "Howto Panel" to tL, tT, tR, tY + tBH + 22
end paLayoutHowto

-- The words and tiles of How to play from pTop; returns where they end
private function paHowtoBody pL, pR, pTop, pTwo
   local tLeftL, tLeftR, tRightL, tRightR, tY, tY2, k, tTextL
   put pL + 22 into tLeftL
   put pR - 22 into tRightR
   if pTwo then
      put (pL + pR) div 2 - 12 into tLeftR
      put (pL + pR) div 2 + 12 into tRightL
   else
      put tRightR into tLeftR
      put tLeftL into tRightL
   end if
   put pTop into tY
   set the rect of field "Howto Numbers Head" to tLeftL, tY, tLeftR, tY + 24
   put paPlaceText("Howto Numbers", tLeftL, tY + 26, tLeftR) + 8 into tY
   if pTwo then
      put paPlaceText("Howto Daily", tLeftL, tY, tLeftR) into tY2
      put pTop into tY
   end if
   set the rect of field "Howto Words Head" to tRightL, tY, tRightR, tY + 24
   put paPlaceText("Howto Words", tRightL, tY + 26, tRightR) + 6 into tY
   put tRightL + sHomeT + 12 into tTextL
   repeat with k = 1 to 3
      put tY, tRightL into sRing["howto" & k]
      put paPlaceText("Howto Key" && k, tTextL, tY, tRightR) into tY2
      set the top of field ("Howto Key" && k) to tY + max(0, (sHomeT - the height of field ("Howto Key" && k)) div 2)
      put max(tY + sHomeT, the bottom of field ("Howto Key" && k)) + 6 into tY
   end repeat
   paLayoutHowtoTiles
   if pTwo then
      return max(tY, the bottom of field "Howto Daily")
   end if
   return paPlaceText("Howto Daily", tLeftL, tY + 4, tLeftR)
end paHowtoBody

-- The three tiles of How to play, at Home's tile size
private command paLayoutHowtoTiles
   local k, tY, tX, tRect, tSize
   put round(sHomeT * 0.5) into tSize
   repeat with k = 1 to 3
      put item 1 of sRing["howto" & k] into tY
      put item 2 of sRing["howto" & k] into tX
      if tY is empty then
         next repeat
      end if
      put tX, tY, tX + sHomeT, tY + sHomeT into tRect
      paSprite "Howto Tile" && k, tX + sHomeT / 2, tY + sHomeT / 2
      set the rect of field ("Howto Letter" && k) to tRect
      set the textSize of field ("Howto Letter" && k) to tSize
      set the textHeight of field ("Howto Letter" && k) to round(tSize * 1.25)
      set the topMargin of field ("Howto Letter" && k) to paMiddle(sHomeT, tSize)
      paMark the long id of graphic ("Howto Mark" && k), char k of "gbs", tRect
   end repeat
end paLayoutHowtoTiles

-- Settings: its switches (in two columns on a wide screen), a note, who
-- made the pictures, and Done
private command paLayoutSettings
   local tTwo, tPW, tL, tR, tBH, tNames, tCount, tRows, tCredits, tHeight, tT, tY, tW, k, tName, tFull
   put sSide into tTwo
   if tTwo then
      put min(sWidth - 32, 640) into tPW
   else
      put min(sWidth - 32, 380) into tPW
   end if
   put (sWidth - tPW) div 2 into tL
   put tL + tPW into tR
   if sCompact then
      put 40 into tBH
   else
      put 46 into tBH
   end if
   put sLibrary and the platform is "HTML5" into tFull
   set the visible of button "Set Full" to tFull
   set the visible of graphic "Set Full Shape" to tFull
   put "Set Sound,Set Voice,Set Mistakes,Set Size,Set Length" into tNames
   if tFull then
      put ",Set Full" after tNames
   end if
   put the number of items of tNames into tCount
   if tTwo then
      put (tCount + 1) div 2 into tRows
   else
      put tCount into tRows
   end if
   set the visible of field "Credits" to not sCompact
   put 0 into tCredits
   if not sCompact then
      put paPlaceText("Credits", tL + 24, 0, tR - 24) + 10 into tCredits
   end if
   put 20 + 30 + 16 + tRows * (tBH + 8) + 42 + tCredits + tBH + 22 into tHeight
   put paPanelTop(tHeight) into tT
   set the rect of field "Settings Title" to tL + 20, tT + 20, tR - 20, tT + 50
   put tT + 66 into tY
   if tTwo then
      put (tPW - 48 - 10) / 2 into tW
   else
      put tPW - 48 into tW
   end if
   put 0 into k
   repeat for each item tName in tNames
      if tTwo then
         paPlaceButton tName, tL + 24 + (k mod 2) * (tW + 10), tY + (k div 2) * (tBH + 8), \
               tL + 24 + (k mod 2) * (tW + 10) + tW, tY + (k div 2) * (tBH + 8) + tBH
      else
         paPlaceButton tName, tL + 24, tY + k * (tBH + 8), tR - 24, tY + k * (tBH + 8) + tBH
      end if
      set the textSize of button tName to 16
      add 1 to k
   end repeat
   add tRows * (tBH + 8) to tY
   set the rect of field "Settings Note" to tL + 24, tY, tR - 24, tY + 40
   add 42 to tY
   if not sCompact then
      put paPlaceText("Credits", tL + 24, tY, tR - 24) + 10 into tY
   end if
   paPlaceButton "Settings Done", tL + 24, tY, tR - 24, tY + tBH
   set the rect of graphic "Settings Panel" to tL, tT, tR, tY + tBH + 22
end paLayoutSettings

-- Done: the title, the sticker earned, the word and what it means (or
-- the hints a board took), a note, and two buttons
command paLayoutDone
   local tPW, tL, tR, tBH, tBox, tHeight, tT, tY, tMid, tSticker, tWord, tPicture
   put min(sWidth - 32, 380) into tPW
   put (sWidth - tPW) div 2 into tL
   put tL + tPW into tR
   put sWidth div 2 into tMid
   if sCompact then
      put 42 into tBH
      put 64 into tBox
   else
      put 48 into tBH
      put 96 into tBox
   end if
   put the visible of button "Done Sticker" into tSticker
   put the visible of field "Done Word" into tWord
   put 20 + 48 into tHeight
   if tSticker then
      add tBox + 12 to tHeight
   end if
   if tWord then
      add 44 to tHeight
   end if
   add paPlaceText("Done Meaning", tL + 24, 0, tR - 24) + 8 to tHeight
   add paPlaceText("Done Note", tL + 24, 0, tR - 24) + 14 to tHeight
   add 2 * tBH + 10 + 22 to tHeight
   put paPanelTop(tHeight) into tT
   put tT + 20 into tY
   set the rect of field "Done Title" to tL + 20, tY, tR - 20, tY + 36
   put tMid, tY + 18 into sSparkAt
   put 130, 34 into sSparkR
   add 48 to tY
   if tSticker then
      put the icon of button "Done Sticker" into tPicture
      put the short name of image id tPicture of card "Art" of me into tPicture
      if tPicture is "star" then
         paFit "star", round(tBox * 0.8)
      else
         paFit tPicture, tBox
      end if
      paSprite "Done Sticker", tMid, tY + tBox / 2
      put tMid, round(tY + tBox / 2) into sSparkAt
      put round(tBox * 1.05), round(tBox * 0.45) into sSparkR
      add tBox + 12 to tY
   end if
   if tWord then
      set the rect of field "Done Word" to tL + 20, tY, tR - 20, tY + 38
      add 44 to tY
   end if
   put paPlaceText("Done Meaning", tL + 24, tY, tR - 24) + 8 into tY
   put paPlaceText("Done Note", tL + 24, tY, tR - 24) + 14 into tY
   paPlaceButton "Done Home", tL + 24, tY, tR - 24, tY + tBH
   add tBH + 10 to tY
   paPlaceButton "Done Again", tL + 24, tY, tR - 24, tY + tBH
   set the rect of graphic "Done Panel" to tL, tT, tR, tY + tBH + 22
end paLayoutDone

----------------------------------------------------------------------
-- For the tests: the clock in the test's hands

-- No loop, no sound, a fixed seed and day (310: Saturday 7 November
-- 2026, if pToday is empty), and the saved things in pSaveFile
command paTestBegin pSeed, pSaveFile, pToday
   set the defaultStack to the short name of me
   put true into sManual
   paStopLoop
   if pSeed is a number then
      set the randomSeed to pSeed
   end if
   put pSaveFile into sSaveFile
   if pToday is an integer then
      put pToday into sToday
   else
      put 310 into sToday
   end if
   paLoad
   put false into sSound
   paStopMoving
   put empty into sN
   put empty into sW
   put empty into sPanel
   put 1 into sPage
   paLayout
   paGoHome
end paTestBegin

-- The game's clock, pSeconds on, a thirtieth of a second at a time
command paTestStep pSeconds
   set the defaultStack to the short name of me
   lock screen
   repeat while pSeconds > 0.0001
      paAdvance min(pSeconds, 1/30)
      subtract 1/30 from pSeconds
   end repeat
   unlock screen
end paTestStep

-- Another day (as a day from 1 January 2026)
command paTestDay pDay
   put pDay into sToday
end paTestDay

-- How things are, a line each: name:value. One of the stack's
-- cJavascriptHandlers, so a page can ask it too (the check of the game's
-- page on the web site, tools/pages/check_puzzle_almanac_page.py)
function paState
   local tOut, tRows, tScores, tKeys, tLetter
   put sW["rows"] into tRows
   replace return with comma in tRows
   put sW["scores"] into tScores
   replace return with comma in tScores
   repeat for each char tLetter in "abcdefghijklmnopqrstuvwxyz"
      if sW["keys"][tLetter] is not empty then
         put tLetter & "=" & sW["keys"][tLetter] & comma after tKeys
      end if
   end repeat
   put "screen:" & sScreen & return & "panel:" & sPanel & return & "today:" & paToday() & return & \
         "size:" & sSize & return & "length:" & sLength & return & "sound:" & sSound & return & \
         "voice:" & sVoice & return & "mistakes:" & sMistakes & return & "howto:" & sSeenHowto & return & \
         "stickers:" & sStickers & return & "stars:" & sStars & return & "award:" & sAward & return & \
         "nstreak:" & sNStreak & return & "nlast:" & sNLast & return & \
         "wstreak:" & sWStreak & return & "wlast:" & sWLast & return & \
         "n:" & sN["n"] & return & "ndaily:" & sN["daily"] & return & "nday:" & sN["day"] & return & \
         "chosen:" & sN["chosen"] & return & "given:" & sN["given"] & return & "board:" & sN["board"] & return & \
         "answer:" & sN["answer"] & return & "notes:" & paNotesList() & return & "noteson:" & sN["notes on"] & return & \
         "hints:" & sN["hints"] & return & "solved:" & sN["solved"] & return & "undo:" & the number of lines of sN["undo"] & return & \
         "len:" & sW["len"] & return & "wdaily:" & sW["daily"] & return & "word:" & sW["answer"] & return & \
         "rows:" & tRows & return & "scores:" & tScores & return & "typed:" & sW["typed"] & return & \
         "over:" & sW["over"] & return & "turning:" & (sReveal["row"] > 0) & return & "keys:" & char 1 to -2 of tKeys & return & \
         "message:" & the text of field "N Message" & return & "page:" & sPage & return & \
         "side:" & sSide & return & "compact:" & sCompact & return & "tile:" & sT & return & "hometile:" & sHomeT & return & \
         "board rect:" & sBoard & return & "library:" & sLibrary & return & "audio:" & sAudio & return & \
         "font:" & sFontLoaded & return & "moving:" & paMoving() & return & \
         "window:" & the width of me & comma & the height of me into tOut
   return tOut
end paState
