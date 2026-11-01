script "revAcademy"
-- OXT-Beyond: the xTalk Academy, a course in coding that is taught in
-- xTalk and run in the IDE.
--
-- It is a place of OXT-Beyond Home (palettes/home/revhub.livecodescript):
-- Help > xTalk Academy and the toolbar's Tutorials open Home there, and
-- Home hosts this stack as its window's behavior (see "Hosted in Home"
-- below). Opened on its own, as its file can be, it is its own window as
-- before. It teaches what every programmer learns first (values and
-- variables, decisions, loops, handlers, lists and arrays, events, objects,
-- debugging and a few classic algorithms) in plain xTalk, the way the
-- language's own books and courses did: Danny Goodman's HyperCard
-- handbooks, RunRev's Revolution tutorials, LiveCode's lessons and its
-- "Create it with LiveCode" and Summer Academy courses. A lesson is short,
-- and everything in it can be run: each example has Try it, which puts it
-- in the playground and runs it; a quick check asks a question and says
-- why its answer is right; and a challenge is checked by running the
-- learner's code against tests, as a teacher would mark it.
--
-- The window has three columns, drawn by revLearnKit (its behavior), in
-- the look of Learn: a dark sidebar with the courses, the progress and an
-- index of the lessons; the lesson; and the playground, a code editor
-- with Run and Check and the output below it.
--
-- The courses are text files in palettes/academy/courses (one a course,
-- read in the order of their names), in a small markup that the course
-- "For teachers" describes, so that a teacher can change a lesson or
-- write a course without changing this script. File > Open a course on the
-- teachers' page adds one from anywhere for this session.
--
-- The learner's code runs in a stack of its own, the stage
-- (revAcademyStage, acRunCode): its handlers become the stage's script,
-- and its other lines a handler that is sent to it, so that "put" with no
-- container, a click on a button the code made and an error all behave as
-- they would in the learner's own stack. What the code puts into the
-- Message Box goes to the output instead (the stage's msgChanged), every
-- value on a line of its own. A repeat loop that runs for longer than ten
-- seconds is stopped, with a word on why (acGuardLoops). The stage's
-- window shows only when the code made something to show, or the lesson
-- is about objects.
--
-- What the learner has done (the lessons finished, and their code) is
-- kept in the IDE's preferences (cAcademy), and nothing else is written:
-- the Academy changes no file.
--
-- It is a script-only stack, so it keeps no controls: this script builds
-- them when it opens, and draws each page anew. Its name begins with
-- "rev", so the IDE treats it as one of its own windows. Its public
-- handlers that do not draw (revAcademyCourses, revAcademyRun,
-- revAcademyCheck) are what tools/academy/check-courses.livecodescript
-- runs every lesson with.

constant kSide = 248
constant kPlay = 452
constant kWidth = 1280
constant kHeight = 800
constant kMinWidth = 1000
constant kMinHeight = 620
constant kMinPlay = 380
constant kMaxPlay = 680
constant kHeaderHeight = 92
constant kPad = 36
constant kColumn = 640
constant kIndexLine = 24
constant kTextInset = 4
constant kStage = "revAcademyStage"
constant kRunHandler = "academyRun"
constant kLoopSeconds = 10
constant kMaxOutputLines = 2000
constant kPrefSet = "cAcademy"

-- The courses, by number: each one's "title", "id", "icon", "accent",
-- "blurb", "credit", "file", its units (sCourses[n]["unit"][u]: "title",
-- "icon", "blurb", "first", "last") and lessons (sCourses[n]["lesson"][l]:
-- "title", "id", "unit", "minutes", "stage", "body"); and how many there
-- are (sCourses["count"])
local sCourses
-- The course in front, and the lesson in front of each course (0 is the
-- course's own first page)
local sCourse, sLesson
-- What the learner has done: the keys of the lessons finished
-- ("course/lesson"), the quick checks answered right ("course/lesson/n"),
-- the code of each lesson's challenge, and how many times each challenge
-- was checked
local sDone, sQuiz, sDrafts, sTries
-- The playground: what is in it ("challenge", "example" or "free"), the
-- lesson it came from (its key) and the example's number; the output, a
-- line a value; and whether a run is going on (the output is drawn when
-- it ends)
local sMode, sModeKey, sExample, sOutput, sRunning
-- Where the learner last put the stage's window
local sStageRect
-- The run: the lines of the stage's script that came from the editor, by
-- the script's line number (acSandboxScript), and the editor's text
local sLineMap, sRunCode
-- Each code block of the lesson in front, each quick check (its right
-- answer and the answer shown), and the challenge
local sCode, sQuizInfo, sChallenge
-- The window's size, the reading column (its left and width), where the
-- next thing goes on the page
local sWidth, sHeight, sX, sColW, sY
-- The sidebar's highlight, sliding to the course in front
local sNavY, sNavTarget
-- The hero's lights, the confetti, when the toast goes, the colouring of
-- the editor that is pending, and the relayout after a resize
local sHero, sConfetti, sToastUntil, sRecolor, sRelayout, sPlaced
-- The extra course files opened this session
local sExtra
-- The lesson each line of the index stands for
local sIndexMap
-- The answer last picked in each quick check, by its key
local sPicked

################################################################################
#
# Opening and closing
#

-- Opens the Academy at a course (its id, or its number) and a lesson (its
-- id, or 0 for the course's first page), or brings it to the front there.
-- With neither, it opens where the learner left it.
command revAcademyShow pCourse, pLesson
   -- (OXT-Beyond Home, when the IDE has it, is where the Academy opens
   -- now. The property is read, not lkHosted: the kit may not be this
   -- stack's behavior yet.)
   if the cHubPlaces of me is empty and acOpenInHome(pCourse, pLesson) then
      exit revAcademyShow
   end if
   if the mode of me is 0 then
      if pCourse is not empty then
         put pCourse & "|" & pLesson into sCourse
      end if
      modeless me
   else
      go me
      if pCourse is not empty then
         acGoTo pCourse, pLesson
      end if
   end if
end revAcademyShow

on preOpenStack
   local tSaved, tError, tWant, tLesson
   if not acForMe() then
      pass preOpenStack
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   try
      acUseKit
      -- (light or dark, as the desktop is: lkAppearanceChanged)
      get lkReadAppearance()
      acLoadCourses
      acLoadProgress
      put sCourse into tWant
      if tWant contains "|" then
         put empty into sCourse
      else
         put acPref("place") into tWant
      end if
      acBuild
      acPlace
      -- (revAcademyShow's course|lesson, or the place, course,lesson)
      replace "|" with comma in tWant
      put item 2 of tWant into tLesson
      put item 1 of tWant into tWant
      acGoTo tWant, tLesson, true
      -- (a script-only stack is made invisible when it is loaded)
      show me
   catch tError
      acRestore tSaved
      throw tError
   end try
   acRestore tSaved
end preOpenStack

################################################################################
#
# Hosted in Home
#
-- OXT-Beyond Home (palettes/home/revhub.livecodescript) uses this stack as
-- its window's behavior for its Academy place. It sends these four
-- messages, and the window's own preOpenStack, openStack and closeStack
-- never reach this script (Home keeps them), so these do what those do
-- here, but for the window's place and size, which are Home's. A page is
-- "course" or "course,lesson" (an id or a number, as revAcademyShow
-- takes them).

-- Opens Home at the Academy, if the IDE has Home; false when it does
-- not, or it failed
private function acOpenInHome pCourse, pLesson
   local tPath, tError, tPage
   put acToolset() & "/palettes/home/revhub.livecodescript" into tPath
   if there is no file tPath then
      return false
   end if
   if pCourse is not empty then
      put pCourse & comma & pLesson into tPage
   end if
   try
      dispatch "revHubShow" to stack tPath with "academy", tPage
   catch tError
      return false
   end try
   return it is "handled"
end acOpenInHome

on revHubAttach pPlace, pPage
   local tSaved, tError
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   try
      acUseKit
      get lkReadAppearance()
      acLoadCourses
      acLoadProgress
      acBuild
      acLayout
   catch tError
      acRestore tSaved
      throw tError
   end try
   acRestore tSaved
end revHubAttach

on revHubStart pPlace, pPage
   local tWant
   if pPage is empty then
      put acPref("place") into tWant
   else
      put pPage into tWant
   end if
   replace "|" with comma in tWant
   acGoTo item 1 of tWant, item 2 of tWant, true
   lkStartTicking
   lkEnter "side"
   lkFollowAppearance
end revHubStart

on revHubNavigate pPlace, pPage
   if pPage is empty then
      exit revHubNavigate
   end if
   replace "|" with comma in pPage
   acGoTo item 1 of pPage, item 2 of pPage
end revHubNavigate

on revHubDetach
   lkStopTicking
   acKeepDraft
   acSaveProgress
   if sRecolor is not empty then
      cancel sRecolor
      put empty into sRecolor
   end if
   if sRelayout is not empty then
      cancel sRelayout
      put empty into sRelayout
   end if
   acCloseStage true
end revHubDetach

-- The sidebar in Home: Home's mark and places, then the courses, each
-- with how many of its lessons are done, then the index. (The progress
-- card's controls are made too, out of sight, so that acSyncProgress
-- finds them.)
private command acBuildHostedSide
   local tObj, tY, tIndex
   put lkHubHead(kSide) into tY
   put 84 into sNavY
   add 8 to tY
   lkHubHeading "coursesWord", tY, "Courses", kSide
   add 18 to tY
   repeat with tIndex = 1 to sCourses["count"]
      lkNavItem "nav_" & tIndex, tY, 28, sCourses[tIndex]["title"], sCourses[tIndex]["icon"], "course" && tIndex, 13, kSide - 10
      put lkLabel("navDone_" & tIndex, lkR(kSide - 70, tY + 7, kSide - 18, tY + 23), empty, 11, lkColor("sideMuted"), "nav_" & tIndex, "right") into tObj
      set the dontWrap of tObj to true
      add 30 to tY
   end repeat
   get lkLabel("progWord", lkR(28, -100, kSide - 28, -84), "YOUR PROGRESS", 10, lkColor("sideMuted"), empty)
   get lkLabel("progText", lkR(28, -100, kSide - 28, -84), empty, 12, lkColor("sideInk"), empty, "right")
   get lkBox("progTrack", lkR(28, -100, kSide - 28, -92), lkColor("sideLine"), 4, empty)
   get lkBox("progFill", lkR(28, -100, 36, -92), lkColor("emerald"), 4, empty)
   hide field "progWord"
   hide field "progText"
   hide graphic "progTrack"
   hide graphic "progFill"

   -- The index
   add 8 to tY
   put lkLabel("idx", lkR(8, tY, kSide - 8, kHeight - 116), empty, 13, lkColor("sideInk"), empty) into tObj
   set the listBehavior of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to kIndexLine
   set the margins of tObj to "8,2,2,2"
   set the threeDHilite of tObj to false
   set the tabStops of tObj to 30

   -- Back, Next, and where you are
   get lkButton("back", 14, kHeight - 104, 32, "Back", "chevron-left", "dark", empty, empty, "go prev", 106)
   get lkButton("next", kSide - 120, kHeight - 104, 32, "Next", "chevron-right", "dark", empty, empty, "go next", 106)
   get lkLabel("navCount", lkR(0, kHeight - 60, kSide, kHeight - 44), empty, 12, lkColor("sideMuted"), empty, "center")
   get lkLabel("navKeys", lkR(0, kHeight - 43, kSide, kHeight - 27), "or use the arrow keys", 11, lkColor("sideMuted"), empty, "center")
end acBuildHostedSide

-- Each course's lessons done, beside its name in Home's sidebar
private command acSyncCourseCounts
   local tIndex
   repeat with tIndex = 1 to sCourses["count"]
      if there is a field ("navDone_" & tIndex) then
         put acDoneCount(tIndex) & "/" & sCourses[tIndex]["lessons"] into field ("navDone_" & tIndex)
      end if
   end repeat
end acSyncCourseCounts

-- Whether a stack message is about this stack. (One that is using it as
-- a library, as a test does, hears every stack's: the stage's closeStack
-- must not close the Academy.)
private function acForMe
   local tTarget
   put the long id of the target into tTarget
   return tTarget is the long id of me or tTarget is the long id of this card of me
end acForMe

private command acRestore pSaved
   if pSaved is not empty and there is a stack pSaved then
      set the defaultStack to pSaved
   end if
end acRestore

on openStack
   if not acForMe() then
      pass openStack
   end if
   lkStartTicking
   lkEnter "side"
   lkFollowAppearance
   -- (on Linux a resizable window can open at its minimum size, whatever
   -- its rect was: once it is up, it goes where acPlace put it)
   send "acKeepPlace" to me in 250 milliseconds
end openStack

on acKeepPlace
   if the mode of me is 0 or sPlaced is empty then
      exit acKeepPlace
   end if
   if the rect of me is not sPlaced then
      set the rect of me to sPlaced
   end if
end acKeepPlace

on closeStack
   if not acForMe() then
      pass closeStack
   end if
   lkStopTicking
   acKeepDraft
   acSaveProgress
   if sRecolor is not empty then
      cancel sRecolor
      put empty into sRecolor
   end if
   if sRelayout is not empty then
      cancel sRelayout
      put empty into sRelayout
   end if
   acCloseStage true
end closeStack

on resizeStack
   if not acForMe() then
      pass resizeStack
   end if
   if the mode of me is 0 then
      pass resizeStack
   end if
   acLayout
   if sRelayout is not empty then
      cancel sRelayout
   end if
   send "acRelayout" to me in 120 milliseconds
   put the result into sRelayout
   pass resizeStack
end resizeStack

-- The desktop switched between light and dark (revLearnKit): the window
-- is built again in the other colours, at its size, on the page it shows
-- and scrolled where it was, and the playground keeps what is in it: the
-- code, the output and what it is for
on lkAppearanceChanged
   local tRect, tScroll, tCode, tEdScroll, tOut, tStatus, tStatusColor, tWhat, tCheck
   put the rect of me into tRect
   put the vScroll of group "body" of me into tScroll
   put the text of field "ed" of me into tCode
   put the vScroll of field "ed" of me into tEdScroll
   put the htmlText of field "out" of me into tOut
   put field "outStatus" of me into tStatus
   put the textColor of field "outStatus" of me into tStatusColor
   put field "playWhat" of me into tWhat
   put the visible of group "check" of me into tCheck
   lock screen
   lkClear
   acBuild
   set the rect of me to tRect
   put tWhat into field "playWhat" of me
   set the visible of group "check" of me to tCheck
   acLayout
   acSyncSide
   acRender true
   set the vScroll of group "body" of me to tScroll
   acSetEditor tCode
   set the vScroll of field "ed" of me to tEdScroll
   set the htmlText of field "out" of me to tOut
   put tStatus into field "outStatus" of me
   -- (a run's colours are the same in both; the rest is the muted grey)
   if tStatusColor is not "52,211,153" and tStatusColor is not "251,113,133" and tStatusColor is not "251,191,36" then
      put lkColor("muted") into tStatusColor
   end if
   set the textColor of field "outStatus" of me to tStatusColor
   set the vScroll of field "out" of me to max(0, the formattedHeight of field "out" of me - the height of field "out" of me)
   unlock screen
end lkAppearanceChanged

on acRelayout
   put empty into sRelayout
   if the mode of me is 0 then
      exit acRelayout
   end if
   acRender
end acRelayout

-- The kit is this stack's behavior (see revLearnKit)
private command acUseKit
   local tKit
   if the behavior of me is not empty then
      exit acUseKit
   end if
   if there is no stack "revLearnKit" then
      put acToolset() & "/palettes/learn/revlearnkit.livecodescript" into tKit
      -- (naming the file loads the stack)
      get the short name of stack tKit
   end if
   set the behavior of me to the long id of stack "revLearnKit"
end acUseKit

-- This stack's folder and the IDE's Toolset folder, from this stack's
-- file: the same in a source tree, an installed IDE and the web IDE
-- (hosted in Home, "me" is Home's window, whose file is elsewhere: the
-- file is this script's own stack's, revAcademy)
private function acFolder
   set the itemDelimiter to slash
   return item 1 to -2 of the filename of stack "revAcademy"
end acFolder

private function acToolset
   set the itemDelimiter to slash
   return item 1 to -4 of the filename of stack "revAcademy"
end acToolset

-- Below the menu bar, as large as the screen allows
private command acPlace
   local tScreen, tTop, tWidth, tHeight, tError
   put the screenRect into tScreen
   put item 2 of tScreen + 40 into tTop
   if there is a stack "revMenubar" and the visible of stack "revMenubar" then
      put max(tTop, the bottom of stack "revMenubar" + 44) into tTop
   end if
   put min(kWidth, item 3 of tScreen - item 1 of tScreen - 40) into tWidth
   put min(kHeight, item 4 of tScreen - tTop - 20) into tHeight
   put max(kMinWidth, tWidth) into tWidth
   put max(kMinHeight, tHeight) into tHeight
   if tTop + tHeight > item 4 of tScreen then
      put max(item 2 of tScreen + 31, item 4 of tScreen - tHeight) into tTop
   end if
   set the rect of me to 0, 0, tWidth, tHeight
   set the topLeft of me to max(item 1 of tScreen, (item 1 of tScreen + item 3 of tScreen - tWidth) div 2), tTop
   put the rect of me into sPlaced
   if there is a stack "revWebIDELibrary" then
      try
         revWebIDEKeepOnPage the long id of me, empty, true
      catch tError
      end try
   end if
   acLayout
end acPlace

################################################################################
#
# What the learner has done
#

-- A preference of the Academy's (cAcademy), or empty outside the IDE
private function acPref pName
   local tProps, tError
   if there is no stack "revPreferences" then
      return empty
   end if
   try
      put the customProperties[kPrefSet] of stack "revPreferences" into tProps
   catch tError
      return empty
   end try
   return tProps[pName]
end acPref

private command acSetPref pName, pValue
   local tError
   if there is no stack "revIDELibrary" or there is no stack "revPreferences" then
      exit acSetPref
   end if
   try
      if acPref(pName) is not pValue then
         revIDESetPreferenceOfSet kPrefSet, pName, pValue
      end if
   catch tError
   end try
end acSetPref

private command acLoadProgress
   local tKey, tDrafts, tError
   put empty into sDone
   put empty into sQuiz
   repeat for each line tKey in acPref("done")
      if tKey is not empty then
         put true into sDone[tKey]
      end if
   end repeat
   repeat for each line tKey in acPref("quiz")
      if tKey is not empty then
         put true into sQuiz[tKey]
      end if
   end repeat
   put acPref("drafts") into tDrafts
   if tDrafts is not empty then
      try
         put arrayDecode(base64Decode(tDrafts)) into sDrafts
      catch tError
         put empty into sDrafts
      end try
   end if
end acLoadProgress

private command acSaveProgress
   local tKeys
   put the keys of sDone into tKeys
   sort lines of tKeys
   acSetPref "done", tKeys
   put the keys of sQuiz into tKeys
   sort lines of tKeys
   acSetPref "quiz", tKeys
   if sDrafts is an array then
      acSetPref "drafts", base64Encode(arrayEncode(sDrafts))
   else
      acSetPref "drafts", empty
   end if
   if sCourse is an integer and sCourse >= 1 and sCourse <= sCourses["count"] then
      acSetPref "place", sCourses[sCourse]["id"] & comma & sLesson[sCourse]
   end if
end acSaveProgress

-- A lesson's key: its course's id and its own
private function acKey pCourse, pLesson
   return sCourses[pCourse]["id"] & "/" & sCourses[pCourse]["lesson"][pLesson]["id"]
end acKey

private function acIsDone pCourse, pLesson
   return sDone[acKey(pCourse, pLesson)] is true
end acIsDone

-- How many lessons of a course are done (only those that have something to
-- do count: a course's pages for reading are done when read)
private function acDoneCount pCourse
   local tCount, tIndex
   put 0 into tCount
   repeat with tIndex = 1 to sCourses[pCourse]["lessons"]
      if acIsDone(pCourse, tIndex) then
         add 1 to tCount
      end if
   end repeat
   return tCount
end acDoneCount

private command acMarkDone pCourse, pLesson
   local tKey
   put acKey(pCourse, pLesson) into tKey
   if sDone[tKey] is true then
      exit acMarkDone
   end if
   put true into sDone[tKey]
   acSaveProgress
   if the mode of me is not 0 then
      acFillIndex
      acSyncProgress
   end if
end acMarkDone

-- Forgets what was done in a course (its lessons, its quick checks and
-- its code)
private command acForget pCourse
   local tPrefix, tKey
   put sCourses[pCourse]["id"] & "/" into tPrefix
   repeat for each key tKey in sDone
      if tKey begins with tPrefix then
         delete variable sDone[tKey]
      end if
   end repeat
   repeat for each key tKey in sQuiz
      if tKey begins with tPrefix then
         delete variable sQuiz[tKey]
      end if
   end repeat
   repeat for each key tKey in sDrafts
      if tKey begins with tPrefix then
         delete variable sDrafts[tKey]
      end if
   end repeat
   repeat for each key tKey in sTries
      if tKey begins with tPrefix then
         delete variable sTries[tKey]
      end if
   end repeat
   acSaveProgress
end acForget

################################################################################
#
# The courses
#

-- The courses' files: the Academy's own, in the order of their names, and
-- those opened this session
private function acCourseFiles
   local tFolder, tFiles, tFile, tList
   put acFolder() & "/courses" into tFolder
   if there is a folder tFolder then
      put files(tFolder) into tFiles
      sort lines of tFiles
      repeat for each line tFile in tFiles
         if tFile ends with ".txt" then
            put tFolder & slash & tFile & return after tList
         end if
      end repeat
   end if
   repeat for each line tFile in sExtra
      if tFile is not empty and tFile is not among the lines of tList then
         put tFile & return after tList
      end if
   end repeat
   delete the last char of tList
   return tList
end acCourseFiles

private command acLoadCourses
   local tFile, tCourse, tCount
   put empty into sCourses
   put 0 into tCount
   repeat for each line tFile in acCourseFiles()
      put acParseCourse(acReadFile(tFile)) into tCourse
      if tCourse["lessons"] is not an integer or tCourse["lessons"] < 1 then
         next repeat
      end if
      add 1 to tCount
      put tFile into tCourse["file"]
      put tCourse into sCourses[tCount]
   end repeat
   put tCount into sCourses["count"]
end acLoadCourses

-- A text file, as UTF-8, its lines ended by return alone
private function acReadFile pFile
   local tData
   put url ("binfile:" & pFile) into tData
   put textDecode(tData, "UTF-8") into tData
   -- (a byte order mark, which some editors write first)
   if char 1 of tData is numToCodepoint(65279) then
      delete char 1 of tData
   end if
   replace crlf with return in tData
   replace numToChar(13) with return in tData
   return tData
end acReadFile

-- The courses as the Academy reads them, for the checks of
-- tools/academy (see acLoadCourses)
function revAcademyCourses
   if sCourses["count"] is empty then
      acLoadCourses
   end if
   return sCourses
end revAcademyCourses

-- A course from its text. A line "course:", "unit:" or "lesson:" at the
-- start of a line begins one, and the lines "name: value" right after it
-- are its settings, up to the first blank line; a lesson's other lines,
-- up to the next unit or lesson, are its body. Lines in a block (from
-- "<code>" to "</code>", and the other blocks of acBlocks) never begin
-- anything, so a lesson can show those words in its code.
function acParseCourse pText
   local tCourse, tLine, tWhat, tName, tValue, tUnit, tLesson, tInHeader, tBlock, tBody
   put 0 into tUnit
   put 0 into tLesson
   put empty into tWhat
   put false into tInHeader
   repeat for each line tLine in pText
      if tBlock is empty then
         put acHeadWord(tLine) into tName
         if tName is among the items of "course,unit,lesson" then
            -- (the lesson before ends here; a unit's lines are not its)
            if tWhat is "lesson" then
               put tBody into tCourse["lesson"][tLesson]["body"]
            end if
            put empty into tBody
            put tName into tWhat
            put char offset(":", tLine) + 1 to -1 of tLine into tValue
            put word 1 to -1 of tValue into tValue
            put true into tInHeader
            switch tName
               case "course"
                  put tValue into tCourse["title"]
                  break
               case "unit"
                  add 1 to tUnit
                  put tValue into tCourse["unit"][tUnit]["title"]
                  put tLesson + 1 into tCourse["unit"][tUnit]["first"]
                  put tLesson into tCourse["unit"][tUnit]["last"]
                  break
               case "lesson"
                  add 1 to tLesson
                  if tUnit is 0 then
                     put 1 into tUnit
                     put tCourse["title"] into tCourse["unit"][1]["title"]
                     put 1 into tCourse["unit"][1]["first"]
                  end if
                  put tValue into tCourse["lesson"][tLesson]["title"]
                  put tUnit into tCourse["lesson"][tLesson]["unit"]
                  put tLesson into tCourse["unit"][tUnit]["last"]
                  break
            end switch
            next repeat
         end if
         if tInHeader then
            if word 1 to -1 of tLine is empty then
               put false into tInHeader
               next repeat
            end if
            put acHeadWord(tLine) into tName
            if tName is not empty then
               put char offset(":", tLine) + 1 to -1 of tLine into tValue
            put word 1 to -1 of tValue into tValue
               switch tWhat
                  case "course"
                     put tValue into tCourse[tName]
                     break
                  case "unit"
                     put tValue into tCourse["unit"][tUnit][tName]
                     break
                  case "lesson"
                     put tValue into tCourse["lesson"][tLesson][tName]
                     break
               end switch
               next repeat
            end if
            put false into tInHeader
         end if
      end if
      -- a block opens and closes on lines of its own
      if tBlock is empty then
         put acBlockTag(tLine) into tBlock
      else if word 1 to -1 of tLine is ("</" & tBlock & ">") then
         put empty into tBlock
      end if
      if tWhat is "lesson" then
         put tLine & return after tBody
      else if tWhat is "course" or tWhat is "unit" then
         -- (the words after a course's or a unit's settings are its blurb)
         if tWhat is "course" and word 1 to -1 of tLine is not empty then
            if tCourse["blurb"] is not empty then
               put space after tCourse["blurb"]
            end if
            put word 1 to -1 of tLine after tCourse["blurb"]
         else if tWhat is "unit" and word 1 to -1 of tLine is not empty then
            if tCourse["unit"][tUnit]["blurb"] is not empty then
               put space after tCourse["unit"][tUnit]["blurb"]
            end if
            put word 1 to -1 of tLine after tCourse["unit"][tUnit]["blurb"]
         end if
      end if
   end repeat
   if tWhat is "lesson" then
      put tBody into tCourse["lesson"][tLesson]["body"]
   end if
   put tUnit into tCourse["units"]
   put tLesson into tCourse["lessons"]
   -- What a course and a lesson have when their file says nothing
   if tCourse["id"] is empty then
      put acSlug(tCourse["title"]) into tCourse["id"]
   end if
   if tCourse["icon"] is empty then
      put "graduation-cap" into tCourse["icon"]
   end if
   if tCourse["accent"] is empty then
      put "violet" into tCourse["accent"]
   end if
   repeat with tLesson = 1 to tCourse["lessons"]
      if tCourse["lesson"][tLesson]["id"] is empty then
         put acSlug(tCourse["lesson"][tLesson]["title"]) into tCourse["lesson"][tLesson]["id"]
      end if
      if tCourse["lesson"][tLesson]["minutes"] is not an integer then
         put max(2, round(the number of words of tCourse["lesson"][tLesson]["body"] / 90)) into tCourse["lesson"][tLesson]["minutes"]
      end if
   end repeat
   repeat with tUnit = 1 to tCourse["units"]
      if tCourse["unit"][tUnit]["icon"] is empty then
         put "book-open" into tCourse["unit"][tUnit]["icon"]
      end if
   end repeat
   return tCourse
end acParseCourse

-- The chars pFrom to pTo of pText (a chunk of a chunk must be the larger
-- of the two, so the words of chars go through this)
private function acSpan pText, pFrom, pTo
   return char pFrom to pTo of pText
end acSpan

-- The name before the colon of a line "name: value" that starts at the
-- line's first character, in lower case, or empty
private function acHeadWord pLine
   local tColon, tName
   put offset(":", pLine) into tColon
   if tColon < 2 or char 1 of pLine is space or char 1 of pLine is tab then
      return empty
   end if
   put char 1 to tColon - 1 of pLine into tName
   if not matchText(tName, "^[A-Za-z][A-Za-z0-9-]*$") then
      return empty
   end if
   return toLower(tName)
end acHeadWord

-- The block a line opens ("code", "tip", "quiz", "challenge" and so on),
-- or empty
private function acBlockTag pLine
   local tTag
   put word 1 to -1 of pLine into pLine
   if char 1 of pLine is not "<" or char -1 of pLine is not ">" or char 2 of pLine is "/" then
      return empty
   end if
   put word 1 of acSpan(pLine, 2, -2) into tTag
   if tTag is among the items of "code,tip,note,important,caution,quiz,challenge" then
      return tTag
   end if
   return empty
end acBlockTag

-- An id from a title: lower case letters and digits, with dashes
private function acSlug pText
   local tSlug, tChar
   repeat for each char tChar in toLower(pText)
      if tChar is among the chars of "abcdefghijklmnopqrstuvwxyz0123456789" then
         put tChar after tSlug
      else if tSlug is not empty and the last char of tSlug is not "-" then
         put "-" after tSlug
      end if
   end repeat
   if the last char of tSlug is "-" then
      delete the last char of tSlug
   end if
   return tSlug
end acSlug

-- The blocks of a lesson's body: tBlocks[n]["kind"] is "text", "code",
-- "tip", "note", "important", "caution", "quiz" or "challenge", with
-- tBlocks[n]["lines"] (a text or a callout's lines, a code block's code)
-- and tBlocks[n]["flags"] (the words after a block's name: "<code dialog>"
-- is code that opens a dialog, which the checks only compile;
-- "<code error>" is code that stops on an error, to show one). A quick
-- check has "question", "options" (a line each), "right" (the number of
-- the right one) and "explain"; a challenge has "text", "starter",
-- "solution", "checks" and "hint". tBlocks["count"] is how many there are.
function acBlocks pBody
   local tBlocks, tCount, tLine, tTag, tPart, tOpt
   put 0 into tCount
   repeat for each line tLine in pBody
      if tTag is empty then
         put acBlockTag(tLine) into tTag
         if tTag is not empty then
            add 1 to tCount
            put tTag into tBlocks[tCount]["kind"]
            put word 2 to -1 of acSpan(word 1 to -1 of tLine, 2, -2) into tBlocks[tCount]["flags"]
            put 0 into tBlocks[tCount]["optionCount"]
            put empty into tPart
            next repeat
         end if
         if tCount is 0 or tBlocks[tCount]["kind"] is not "text" then
            add 1 to tCount
            put "text" into tBlocks[tCount]["kind"]
         end if
         put tLine & return after tBlocks[tCount]["lines"]
         next repeat
      end if
      if word 1 to -1 of tLine is ("</" & tTag & ">") then
         put empty into tTag
         next repeat
      end if
      switch tTag
         case "quiz"
            -- "- " a wrong answer, "* " the right one, "= " why; the rest
            -- is the question
            if char 1 to 2 of tLine is "- " or char 1 to 2 of tLine is "* " then
               add 1 to tBlocks[tCount]["optionCount"]
               put tBlocks[tCount]["optionCount"] into tOpt
               put char 3 to -1 of tLine into tBlocks[tCount]["option"][tOpt]
               if char 1 of tLine is "*" then
                  put tOpt into tBlocks[tCount]["right"]
               end if
            else if char 1 to 2 of tLine is "= " then
               if tBlocks[tCount]["explain"] is not empty then
                  put space after tBlocks[tCount]["explain"]
               end if
               put char 3 to -1 of tLine after tBlocks[tCount]["explain"]
            else if word 1 to -1 of tLine is not empty then
               if tBlocks[tCount]["question"] is not empty then
                  put space after tBlocks[tCount]["question"]
               end if
               put word 1 to -1 of tLine after tBlocks[tCount]["question"]
            end if
            break
         case "challenge"
            -- "<starter>", "<solution>", "<check>" and "<hint>" each open a
            -- part, closed by its own end tag; the rest is what to do
            if tPart is empty and word 1 to -1 of tLine is among the items of "<starter>,<solution>,<check>,<hint>" then
               put char 2 to -2 of word 1 to -1 of tLine into tPart
               next repeat
            end if
            if tPart is not empty and word 1 to -1 of tLine is ("</" & tPart & ">") then
               put empty into tPart
               next repeat
            end if
            if tPart is empty then
               put tLine & return after tBlocks[tCount]["text"]
            else if tPart is "check" then
               if word 1 to -1 of tLine is not empty then
                  put word 1 to -1 of tLine & return after tBlocks[tCount]["checks"]
               end if
            else
               put tLine & return after tBlocks[tCount][tPart]
            end if
            break
         default
            put tLine & return after tBlocks[tCount]["lines"]
      end switch
   end repeat
   put tCount into tBlocks["count"]
   -- (code loses the blank lines at either end, and the last return)
   repeat with tCount = 1 to tBlocks["count"]
      if tBlocks[tCount]["kind"] is "code" then
         put acTrimLines(tBlocks[tCount]["lines"]) into tBlocks[tCount]["lines"]
      else if tBlocks[tCount]["kind"] is "challenge" then
         repeat for each item tPart in "starter,solution,hint,text,checks"
            put acTrimLines(tBlocks[tCount][tPart]) into tBlocks[tCount][tPart]
         end repeat
      end if
   end repeat
   return tBlocks
end acBlocks

private function acTrimLines pText
   repeat while pText is not empty and word 1 to -1 of line 1 of pText is empty
      delete line 1 of pText
   end repeat
   repeat while pText is not empty and word 1 to -1 of the last line of pText is empty
      delete the last line of pText
   end repeat
   return pText
end acTrimLines

-- A lesson's challenge, if it has one (its block), and how many quick
-- checks it has
private function acChallengeOf pCourse, pLesson
   local tBlocks, tIndex
   put acBlocks(sCourses[pCourse]["lesson"][pLesson]["body"]) into tBlocks
   repeat with tIndex = 1 to tBlocks["count"]
      if tBlocks[tIndex]["kind"] is "challenge" then
         return tBlocks[tIndex]
      end if
   end repeat
   return empty
end acChallengeOf

################################################################################
#
# Building the window
#

private command acBuild
   local tSaved
   if there is a group "body" of me then
      exit acBuild
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   -- (hosted in Home, the window's title and size are Home's)
   if not lkHosted() then
      set the label of me to "xTalk Academy"
      set the resizable of me to true
      set the minWidth of me to kMinWidth
      set the minHeight of me to kMinHeight
      set the destroyStack of me to true
      set the rect of me to 0, 0, kWidth, kHeight
   end if
   set the backgroundColor of me to lkColor("bg")
   acBuildSide
   acBuildHeader
   get lkGroup("body", lkR(kSide, kHeaderHeight, kWidth - kPlay, kHeight), empty)
   acBuildPlayground
   -- (the kit's slim thumbs, in place of the scrollbars)
   if lkDark() then
      lkScroller "bodyThumb", the long id of group "body", "148,163,184", 45, empty
   else
      lkScroller "bodyThumb", the long id of group "body", "100,116,139", 45, empty
   end if
   lkScroller "idxThumb", the long id of field "idx", "255,255,255", 70, empty
   lkScroller "outThumb", the long id of field "out", "255,255,255", 70, empty
   acBuildToast
   acBuildConfetti
   unlock messages
   unlock screen
   acRestore tSaved
end acBuild

private command acBuildSide
   local tObj, tY, tIndex
   put lkBox("sideBg", lkR(0, 0, kSide, kHeight), lkColor("side"), 0, empty) into tObj
   if lkHosted() then
      -- (Home's sidebar is one colour in every place)
      lkGradient tObj, "15,23,42|20,24,54|36,27,82", "0,0", "0," & kHeight
      acBuildHostedSide
      exit acBuildSide
   end if
   lkGradient tObj, "15,23,42|17,32,52|19,46,62", "0,0", "0," & kHeight
   -- The mark
   put lkBox("sideMark", "20,22,56,58", lkColor("emerald"), 22, empty) into tObj
   lkGradient tObj, "16,185,129|2,132,199", "20,22", "56,58"
   lkGlow tObj, "45,212,191", 16, 110
   get lkIcon("sideMarkIcon", "code", "255,255,255", "28,30,48,50", empty)
   get lkLabel("sideTitle", lkR(66, 21, kSide - 8, 45), "xTalk Academy", 19, "255,255,255", empty)
   get lkLabel("sideSub", lkR(66, 45, kSide - 8, 61), "Learn to code, one step at a time", 11, lkColor("sideMuted"), empty)

   -- The courses
   put lkBox("navHi", lkR(10, 84, kSide - 10, 116), lkColor("side2"), 16, empty) into tObj
   lkBorder tObj, lkColor("sideLine")
   put lkBox("navBar", "10,91,14,109", lkColor("emerald"), 4, empty) into tObj
   put 84 into tY
   put tY into sNavY
   repeat with tIndex = 1 to sCourses["count"]
      lkNavItem "nav_" & tIndex, tY, 32, sCourses[tIndex]["title"], sCourses[tIndex]["icon"], "course" && tIndex, 14, kSide - 10
      add 36 to tY
   end repeat

   -- The progress: a card with a bar
   add 8 to tY
   put lkBox("progBg", lkR(14, tY, kSide - 14, tY + 58), lkColor("side2"), 14, empty) into tObj
   lkBorder tObj, lkColor("sideLine")
   get lkLabel("progWord", lkR(28, tY + 10, kSide - 28, tY + 26), "YOUR PROGRESS", 10, lkColor("sideMuted"), empty)
   set the textStyle of field "progWord" to "bold"
   put lkLabel("progText", lkR(28, tY + 9, kSide - 28, tY + 26), empty, 12, lkColor("sideInk"), empty, "right") into tObj
   get lkBox("progTrack", lkR(28, tY + 36, kSide - 28, tY + 44), lkColor("sideLine"), 4, empty)
   put lkBox("progFill", lkR(28, tY + 36, 36, tY + 44), lkColor("emerald"), 4, empty) into tObj
   lkGradient tObj, "16,185,129|45,212,191", "28,0", (kSide - 28) & ",0"

   -- The index
   add 70 to tY
   put lkLabel("idx", lkR(8, tY, kSide - 8, kHeight - 116), empty, 13, lkColor("sideInk"), empty) into tObj
   set the listBehavior of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the fixedLineHeight of tObj to true
   set the textHeight of tObj to kIndexLine
   set the margins of tObj to "8,2,2,2"
   set the threeDHilite of tObj to false
   set the tabStops of tObj to 30

   -- Back, Next, and where you are
   get lkButton("back", 14, kHeight - 104, 32, "Back", "chevron-left", "dark", empty, empty, "go prev", 106)
   get lkButton("next", kSide - 120, kHeight - 104, 32, "Next", "chevron-right", "dark", empty, empty, "go next", 106)
   get lkLabel("navCount", lkR(0, kHeight - 60, kSide, kHeight - 44), empty, 12, lkColor("sideMuted"), empty, "center")
   get lkLabel("navKeys", lkR(0, kHeight - 43, kSide, kHeight - 27), "or use the arrow keys", 11, lkColor("sideMuted"), empty, "center")
end acBuildSide

private command acBuildHeader
   local tObj
   get lkGroup("hdr", lkR(kSide, 0, kWidth - kPlay, kHeaderHeight), empty)
   put lkLabel("hdrTitle", lkR(kSide + kPad, 16, kWidth - kPlay - kPad, 52), empty, 26, lkColor("ink"), "hdr") into tObj
   set the dontWrap of tObj to true
   put lkLabel("hdrTag", lkR(kSide + kPad, 54, kWidth - kPlay - kPad, 72), empty, 13, lkColor("soft"), "hdr") into tObj
   set the dontWrap of tObj to true
   put lkBox("hdrLine", lkR(kSide + kPad, 78, kSide + kPad + 56, 81), lkColor("emerald"), 3, "hdr") into tObj
end acBuildHeader

-- The playground: the editor, Run and Check, and the output, on a dark
-- panel down the window's right
private command acBuildPlayground
   local tObj, tX
   put kWidth - kPlay into tX
   get lkGroup("play", lkR(tX, 0, kWidth, kHeight), empty)
   put lkBox("playBg", lkR(tX, 0, kWidth, kHeight), lkColor("code"), 0, "play") into tObj
   lkGradient tObj, "15,23,42|23,26,58|30,27,75", tX & ",0", tX & "," & kHeight
   put lkBox("playEdge", lkR(tX, 0, tX + 1, kHeight), lkColor("sideLine"), 0, "play") into tObj

   -- Its title, and what is in it
   put lkBox("playMark", lkR(tX + 20, 22, tX + 52, 54), lkColor("side2"), 12, "play") into tObj
   lkBorder tObj, lkColor("sideLine")
   get lkIcon("playMarkIcon", "square-terminal", "45,212,191", lkR(tX + 28, 30, tX + 44, 46), "play")
   put lkLabel("playTitle", lkR(tX + 64, 20, kWidth - 20, 40), "Playground", 16, "255,255,255", "play") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("playWhat", lkR(tX + 64, 40, kWidth - 20, 56), empty, 12, lkColor("muted"), "play") into tObj
   set the dontWrap of tObj to true

   -- The editor: line numbers, and the code
   put lkBox("edBg", lkR(tX + 18, 70, kWidth - 18, 400), "8,13,28", 14, "play") into tObj
   lkBorder tObj, lkColor("sideLine")
   put lkCodeField("edNums", lkR(tX + 22, 82, tX + 58, 392), 13, 20, "play") into tObj
   set the textAlign of tObj to "right"
   set the textColor of tObj to "71,85,105"
   set the dontWrap of tObj to true
   put lkCodeField("ed", lkR(tX + 66, 82, kWidth - 26, 392), 13, 20, "play") into tObj
   set the lockText of tObj to false
   set the traversalOn of tObj to true
   set the autoHilite of tObj to true
   set the dontWrap of tObj to true
   set the autoTab of tObj to false
   set the hScrollbar of tObj to false
   set the vScrollbar of tObj to false
   set the hiliteColor of tObj to "51,65,85"
   set the margins of tObj to "4," & kTextInset & ",4,4"
   lkScroller "edThumb", the long id of field "ed", "255,255,255", 70, "play"

   -- Run, Check and Reset
   get lkButton("run", tX + 18, 412, 34, "Run", "play", "primary", lkColor("emerald"), "play", "run", 90)
   get lkButton("check", tX + 118, 412, 34, "Check", "check", "primary", lkColor("violet"), "play", "check", 100)
   get lkButton("reset", kWidth - 18 - 96, 412, 34, "Reset", "rotate-cw", "dark", empty, "play", "reset", 96)
   get lkLabel("runKeys", lkR(tX + 228, 421, kWidth - 120, 437), "Ctrl+Enter runs", 11, lkColor("sideMuted"), "play")
   set the dontWrap of field "runKeys" to true

   -- The output
   put lkBox("outBg", lkR(tX + 18, 460, kWidth - 18, kHeight - 18), "8,13,28", 14, "play") into tObj
   lkBorder tObj, lkColor("sideLine")
   put lkLabel("outWord", lkR(tX + 34, 472, tX + 160, 488), "OUTPUT", 10, lkColor("muted"), "play") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel("outStatus", lkR(tX + 100, 471, kWidth - 70, 488), empty, 12, lkColor("muted"), "play", "right") into tObj
   set the dontWrap of tObj to true
   get lkGroup("outClear", lkR(kWidth - 60, 466, kWidth - 30, 494), "play")
   get lkBox("outClear_bg", lkR(kWidth - 60, 466, kWidth - 30, 494), lkColor("sideLine"), 12, "outClear")
   get lkIcon("outClear_icon", "x", lkColor("sideInk"), lkR(kWidth - 52, 473, kWidth - 38, 487), "outClear")
   acLiveFade "outClear", "clear"
   put lkCodeField("out", lkR(tX + 30, 496, kWidth - 30, kHeight - 28), 13, 19, "play") into tObj
   set the dontWrap of tObj to false
   set the vScrollbar of tObj to false
   set the textColor of tObj to lkColor("codeInk")
end acBuildPlayground

-- A small thing that lights up by showing its box more
private command acLiveFade pName, pAction
   local tLook
   put pName & "_bg" into tLook["bg"]
   put 60 into tLook["blend0"]
   put 0 into tLook["blend1"]
   set the blendLevel of graphic (pName & "_bg") to 60
   lkLive pName, "side", pAction, tLook
end acLiveFade

-- A dark pill at the foot of the page, for a word on what just happened
private command acBuildToast
   local tObj
   get lkGroup("toast", lkR(0, 0, 400, 40), empty)
   put lkBox("toast_bg", lkR(0, 0, 400, 40), lkColor("side"), 20, "toast") into tObj
   lkShadow tObj, 18, 6, 40
   get lkIcon("toast_icon", "check", lkColor("emerald"), "16,12,32,28", "toast")
   put lkLabel("toast_label", "42,11,390,29", empty, 13, "255,255,255", "toast") into tObj
   set the dontWrap of tObj to true
   hide group "toast"
end acBuildToast

-- Confetti, for a challenge done: little bits of colour that fall over the
-- page (acConfettiFrame)
private command acBuildConfetti
   local tIndex, tObj
   get lkGroup("confetti", lkR(0, 0, kWidth, kHeight), empty)
   repeat with tIndex = 1 to 48
      put lkBox("conf" & tIndex, lkR(0, 0, 8, 12), lkHue(tIndex * 47, 0.85, 0.6), 2, "confetti") into tObj
   end repeat
   hide group "confetti"
end acBuildConfetti

-- Places what moves with the window's size
private command acLayout
   local tW, tH, tX, tY, tMid, tEdBottom, tSaved, tObj
   put the width of me into tW
   put the height of me into tH
   put tW into sWidth
   put tH into sHeight
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   -- the sidebar
   set the rect of graphic "sideBg" to 0, 0, kSide, tH
   lkGradientPoints the long id of graphic "sideBg", "0,0", "0," & tH
   set the rect of field "idx" to 8, the top of field "idx", kSide - 8, tH - 116
   set the top of group "back" to tH - 104
   lkRestAt "back"
   set the top of group "next" to tH - 104
   lkRestAt "next"
   set the top of field "navCount" to tH - 60 - kTextInset
   set the top of field "navKeys" to tH - 43 - kTextInset
   -- the playground, at the right
   put tW - acPlay() into tX
   set the rect of group "play" to tX, 0, tW, tH
   set the rect of graphic "playBg" to tX, 0, tW, tH
   lkGradientPoints the long id of graphic "playBg", tX & ",0", tX & "," & tH
   set the rect of graphic "playEdge" to tX, 0, tX + 1, tH
   set the left of graphic "playMark" to tX + 20
   set the left of image "playMarkIcon" to tX + 28
   set the rect of field "playTitle" to tX + 64, the top of field "playTitle", tW - 20, the bottom of field "playTitle"
   set the rect of field "playWhat" to tX + 64, the top of field "playWhat", tW - 20, the bottom of field "playWhat"
   -- (the editor takes a little more than half of what is left)
   put 70 + round((tH - 70 - 72 - 160) * 0.62) into tEdBottom
   set the rect of graphic "edBg" to tX + 18, 70, tW - 18, tEdBottom
   set the rect of field "edNums" to tX + 22, 82 - kTextInset, tX + 58, tEdBottom - 8
   set the rect of field "ed" to tX + 62, 82 - kTextInset, tW - 26, tEdBottom - 8
   put tEdBottom + 12 into tY
   set the topLeft of group "run" to tX + 18, tY
   lkRestAt "run"
   set the topLeft of group "check" to the right of group "run" + 10, tY
   lkRestAt "check"
   set the topLeft of group "reset" to tW - 18 - the width of group "reset", tY
   lkRestAt "reset"
   if the visible of group "check" then
      put the right of group "check" + 14 into tMid
   else
      put the right of group "run" + 14 into tMid
   end if
   set the rect of field "runKeys" to tMid, tY + 9 - kTextInset, the left of group "reset" - 8, tY + 26
   -- (in a narrow window, the hint goes rather than show half of itself)
   set the visible of field "runKeys" to the formattedWidth of field "runKeys" <= the width of field "runKeys"
   put tY + 48 into tY
   set the rect of graphic "outBg" to tX + 18, tY, tW - 18, tH - 18
   set the topLeft of field "outWord" to tX + 34, tY + 12 - kTextInset
   set the rect of field "outStatus" to tX + 100, tY + 11 - kTextInset, tW - 70, tY + 28
   set the rect of group "outClear" to tW - 60, tY + 6, tW - 30, tY + 34
   set the rect of graphic "outClear_bg" to tW - 60, tY + 6, tW - 30, tY + 34
   set the topLeft of image "outClear_icon" to tW - 52, tY + 13
   set the rect of field "out" to tX + 30, tY + 36 - kTextInset, tW - 30, tH - 28
   -- the page, between the two
   acColumn
   set the rect of group "hdr" to kSide, 0, tX, kHeaderHeight
   set the rect of field "hdrTitle" to sX, the top of field "hdrTitle", tX - kPad, the bottom of field "hdrTitle"
   set the rect of field "hdrTag" to sX, the top of field "hdrTag", tX - kPad, the bottom of field "hdrTag"
   set the left of graphic "hdrLine" to sX
   if the visible of group "hdr" then
      set the rect of group "body" to kSide, kHeaderHeight, tX, tH
   else
      set the rect of group "body" to kSide, 0, tX, tH
   end if
   set the rect of group "confetti" to 0, 0, tW, tH
   unlock screen
   acRestore tSaved
end acLayout

-- The playground's width: kPlay at the window's first size, and a share
-- of what the window gains or loses from there, within bounds
private function acPlay
   return max(kMinPlay, min(kMaxPlay, kPlay + round((sWidth - kWidth) * 0.44)))
end acPlay

-- The page's column: its left (sX) and width (sColW)
private command acColumn
   local tRoom
   put sWidth - acPlay() - kSide - 2 * kPad into tRoom
   put min(kColumn, tRoom) into sColW
   put kSide + kPad + (tRoom - sColW) div 2 into sX
end acColumn

################################################################################
#
# The sidebar
#

-- The sidebar shows the course in front: its tab lit, its accent, its
-- progress and its index
private command acSyncSide
   local tAccent, tIndex, tName
   put acAccent() into tAccent
   if lkHosted() then
      -- (Home's places, the Academy's lit; the course in front is lit in
      -- the list of courses below them, but the highlight stays on the
      -- Academy)
      put lkHubSync(tAccent) into sNavTarget
   end if
   repeat with tIndex = 1 to sCourses["count"]
      put "nav_" & tIndex into tName
      if there is not a group tName then
         next repeat
      end if
      if tIndex is sCourse then
         lkSetLook tName, "ink0", "255,255,255"
         lkIconInk the long id of image (tName & "_icon"), sCourses[tIndex]["icon"], lkMix(tAccent, "255,255,255", 0.35)
         if not lkHosted() then
            put the top of group tName into sNavTarget
         end if
      else
         lkSetLook tName, "ink0", lkColor("sideInk")
         lkIconInk the long id of image (tName & "_icon"), sCourses[tIndex]["icon"], lkColor("sideInk")
      end if
   end repeat
   set the backgroundColor of graphic "navBar" to tAccent
   lkGlow the long id of graphic "navBar", tAccent, 10, 160
   set the hiliteColor of field "idx" to lkMix(lkColor("side2"), tAccent, 0.45)
   set the backgroundColor of graphic "hdrLine" to tAccent
   set the linkColor of me to lkAccentInk(tAccent)
   set the linkHiliteColor of me to lkAccentText(tAccent, 0.3)
   set the linkVisitedColor of me to lkAccentInk(tAccent)
   acSyncProgress
   acFillIndex
end acSyncSide

-- The course's accent colour
private function acAccent
   if sCourse is not an integer or sCourse < 1 then
      return lkColor("emerald")
   end if
   return lkColor(sCourses[sCourse]["accent"])
end acAccent

private command acSyncProgress
   local tDone, tCount, tWidth
   if sCourse is not an integer or sCourse < 1 then
      exit acSyncProgress
   end if
   put acDoneCount(sCourse) into tDone
   put sCourses[sCourse]["lessons"] into tCount
   if lkHosted() then
      acSyncCourseCounts
   end if
   put tDone && "of" && tCount && "done" into field "progText"
   put the width of graphic "progTrack" into tWidth
   if tDone is 0 then
      hide graphic "progFill"
   else
      show graphic "progFill"
      set the width of graphic "progFill" to max(8, round(tWidth * tDone / tCount))
      set the left of graphic "progFill" to the left of graphic "progTrack"
   end if
end acSyncProgress

-- The index: the course's first page, then each unit and its lessons
private command acFillIndex
   local tHtml, tCount, tUnit, tIndex, tMark
   put empty into sIndexMap
   put 0 into tCount
   add 1 to tCount
   put 0 into sIndexMap[tCount]
   put "<p><font color=" & quote & "#94a3b8" & quote & ">&#9733;</font>" & tab & "Start here</p>" after tHtml
   repeat with tUnit = 1 to sCourses[sCourse]["units"]
      add 1 to tCount
      put sCourses[sCourse]["unit"][tUnit]["first"] into sIndexMap[tCount]
      put "<p><font size=" & quote & "10" & quote & " color=" & quote & "#94a3b8" & quote & "><b>" & \
            lkEscape(toUpper(sCourses[sCourse]["unit"][tUnit]["title"])) & "</b></font></p>" after tHtml
      repeat with tIndex = sCourses[sCourse]["unit"][tUnit]["first"] to sCourses[sCourse]["unit"][tUnit]["last"]
         add 1 to tCount
         put tIndex into sIndexMap[tCount]
         if acIsDone(sCourse, tIndex) then
            put "<font color=" & quote & "#34d399" & quote & ">&#10003;</font>" into tMark
         else
            put "<font color=" & quote & "#94a3b8" & quote & ">" & format("%02d", tIndex) & "</font>" into tMark
         end if
         put "<p>" & tMark & tab & lkEscape(sCourses[sCourse]["lesson"][tIndex]["title"]) & "</p>" after tHtml
      end repeat
   end repeat
   lock screen
   set the htmlText of field "idx" to tHtml
   acFitIndex
   unlock screen
   acSyncIndex
end acFillIndex

-- A line of the index too long for the sidebar ends in an ellipsis
private command acFitIndex
   local tRoom, tLine
   put the width of field "idx" - 8 - 2 - 12 into tRoom
   repeat with tLine = 1 to the number of lines of field "idx"
      if the formattedWidth of line tLine of field "idx" <= tRoom then
         next repeat
      end if
      repeat while the formattedWidth of line tLine of field "idx" > tRoom \
            and the number of chars of line tLine of field "idx" > 6
         delete the last char of line tLine of field "idx"
      end repeat
      delete the last char of line tLine of field "idx"
      repeat while the last char of line tLine of field "idx" is space
         delete the last char of line tLine of field "idx"
      end repeat
      put numToCodepoint(8230) after line tLine of field "idx"
   end repeat
end acFitIndex

-- The index marks the lesson in front, and scrolls to it
private command acSyncIndex
   local tLine, tKey, tTop, tCount, tLesson
   put sLesson[sCourse] into tLesson
   put empty into tLine
   repeat with tKey = 1 to the number of lines of field "idx"
      -- (a unit's line and its first lesson's stand for the same page:
      -- the lesson's is the one marked)
      if sIndexMap[tKey] is tLesson and sIndexMap[tKey + 1] is not tLesson then
         put tKey into tLine
         exit repeat
      end if
   end repeat
   if tLine is empty then
      set the hilitedLine of field "idx" to empty
   else
      set the hilitedLine of field "idx" to tLine
      put (tLine - 1) * kIndexLine into tTop
      if tTop < the vScroll of field "idx" or tTop + kIndexLine > the vScroll of field "idx" + the height of field "idx" - 8 then
         set the vScroll of field "idx" to max(0, tTop - (the height of field "idx" div 2) + kIndexLine)
      end if
   end if
   put sCourses[sCourse]["lessons"] into tCount
   if tLesson is 0 then
      put tCount && "lessons" into field "navCount"
   else
      put "Lesson" && tLesson && "of" && tCount into field "navCount"
   end if
end acSyncIndex

################################################################################
#
# Going from page to page
#

-- Goes to a course (its id or number) at a lesson (its id or number; 0 is
-- the course's first page; empty is where the learner was). pFirst is
-- true when the window is opening: nothing slides in.
command acGoTo pCourse, pLesson, pFirst
   local tCourse, tLesson, tIndex
   put empty into tCourse
   if pCourse is an integer and pCourse >= 1 and pCourse <= sCourses["count"] then
      put pCourse into tCourse
   else
      repeat with tIndex = 1 to sCourses["count"]
         if sCourses[tIndex]["id"] is pCourse then
            put tIndex into tCourse
            exit repeat
         end if
      end repeat
   end if
   if tCourse is empty then
      put 1 into tCourse
   end if
   put empty into tLesson
   if pLesson is an integer and pLesson >= 0 and pLesson <= sCourses[tCourse]["lessons"] then
      put pLesson into tLesson
   else if pLesson is not empty then
      repeat with tIndex = 1 to sCourses[tCourse]["lessons"]
         if sCourses[tCourse]["lesson"][tIndex]["id"] is pLesson then
            put tIndex into tLesson
            exit repeat
         end if
      end repeat
   end if
   if tLesson is empty then
      put sLesson[tCourse] into tLesson
   end if
   if tLesson is not an integer then
      put 0 into tLesson
   end if
   acShow tCourse, tLesson, "dissolve", pFirst
end acGoTo

-- Shows lesson pLesson of course pCourse, with a visual effect (none when
-- pFirst)
private command acShow pCourse, pLesson, pEffect, pFirst
   local tSaved
   if sCourses["count"] < 1 then
      acRenderEmpty
      exit acShow
   end if
   acKeepDraft
   -- (a course not visited yet opens at its first page)
   if pLesson is not an integer or pLesson < 0 then
      put 0 into pLesson
   end if
   -- (what the last lesson's code made does not stay over the next one)
   if pCourse is not sCourse or pLesson is not sLesson[sCourse] then
      if sRunning is not true then
         acCloseStage
      end if
   end if
   put pCourse into sCourse
   put pLesson into sLesson[pCourse]
   put empty into sChallenge
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   if not pFirst then
      lock screen for visual effect in rect lkR(kSide, 0, sWidth - acPlay(), sHeight)
   end if
   acSyncSide
   acRender
   acSetupPlayground
   if not pFirst then
      unlock screen with visual effect pEffect very fast
   end if
   -- (a lesson with nothing to do is done once it is read)
   if pLesson > 0 and not acHasWork(pCourse, pLesson) then
      acMarkDone pCourse, pLesson
   end if
   acSaveProgress
   acRestore tSaved
end acShow

-- Whether a lesson has something to do: a challenge or a quick check
private function acHasWork pCourse, pLesson
   local tBody
   put sCourses[pCourse]["lesson"][pLesson]["body"] into tBody
   return tBody contains "<challenge>" or tBody contains "<quiz>"
end acHasWork

-- Next and Back: the lesson after or before, across units
command acGo pWhere
   local tLesson
   put sLesson[sCourse] into tLesson
   switch pWhere
      case "next"
         if tLesson >= sCourses[sCourse]["lessons"] then
            exit acGo
         end if
         acShow sCourse, tLesson + 1, "push left"
         break
      case "prev"
         if tLesson <= 0 then
            exit acGo
         end if
         acShow sCourse, tLesson - 1, "push right"
         break
      default
         if pWhere is an integer and pWhere >= 0 and pWhere <= sCourses[sCourse]["lessons"] and pWhere is not tLesson then
            acShow sCourse, pWhere, "dissolve"
         end if
   end switch
end acGo

on mouseUp pButton
   if word 1 of the name of the target is "field" and the short name of the target is "idx" then
      if pButton is 1 then
         acIndexClick
      end if
      exit mouseUp
   end if
   pass mouseUp
end mouseUp

private command acIndexClick
   local tLine
   put the hilitedLine of field "idx" into tLine
   if tLine is empty or sIndexMap[tLine] is empty then
      acSyncIndex
      exit acIndexClick
   end if
   if sIndexMap[tLine] is sLesson[sCourse] then
      acSyncIndex
   else
      acGo sIndexMap[tLine]
   end if
end acIndexClick

on arrowKey pKey
   -- (a field keeps its arrow keys: the editor's, and one in another
   -- window, the Message Box's say)
   if word 1 of the name of the target is "field" and the short name of the target is not "idx" then
      pass arrowKey
   end if
   switch pKey
      case "left"
         acGo "prev"
         break
      case "right"
         acGo "next"
         break
      default
         pass arrowKey
   end switch
end arrowKey

on linkClicked pLink
   local tError
   try
      if pLink contains "://" then
         launch url pLink
      else if pLink begins with "lesson:" then
         acGoTo sCourse, char 8 to -1 of pLink
      else if pLink begins with "course:" then
         acGoTo char 8 to -1 of pLink, 0
      end if
   catch tError
      acToast "That could not open:" && lkErrorText(tError), "bad"
   end try
end linkClicked

################################################################################
#
# What a click does
#

on lkAction pAction
   local tSaved, tError
   -- (an action can come from another stack, as Learn's does)
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   try
      acAction pAction
   catch tError
      acRestore tSaved
      throw tError
   end try
   acRestore tSaved
end lkAction

private command acAction pAction
   local tArg
   put word 2 to -1 of pAction into tArg
   switch word 1 of pAction
      case "course"
         if tArg is not sCourse then
            acShow tArg, sLesson[tArg], "dissolve"
         end if
         break
      case "go"
         acGo tArg
         break
      case "run"
         acRunEditor
         break
      case "check"
         acCheckEditor
         break
      case "reset"
         acResetEditor
         break
      case "clear"
         put empty into sOutput
         acShowOutput empty, empty
         break
      case "try"
         acTryExample tArg
         break
      case "copy"
         acCopy tArg
         break
      case "quiz"
         acAnswer word 2 of pAction, word 3 of pAction
         break
      case "start"
         acSetupPlayground "challenge"
         focus on field "ed"
         break
      case "hint"
         put not (sChallenge["hint"] is true) into sChallenge["hint"]
         acRender true
         break
      case "solution"
         acRevealSolution
         break
      case "use"
         acUseSolution
         break
      case "forget"
         acAskForget
         break
      case "openCourse"
         acOpenCourseFile
         break
      case "stage"
         acShowStage
         break
   end switch
end acAction

private command acCopy pIndex
   if sCode[pIndex] is empty then
      exit acCopy
   end if
   set the clipboardData["text"] to sCode[pIndex]["code"]
   acToast "Copied: paste it into a script, or into the Message Box to run it.", "ok"
end acCopy

-- A word at the foot of the page for a moment: ok, warn or bad
private command acToast pText, pKind
   local tColor, tIcon, tWidth, tLeft, tTop, tSaved
   if the mode of me is 0 then
      exit acToast
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   switch pKind
      case "warn"
         put lkColor("amber") into tColor
         put "triangle-alert" into tIcon
         break
      case "bad"
         put lkColor("rose") into tColor
         put "triangle-alert" into tIcon
         break
      case "win"
         put lkColor("flame") into tColor
         put "trophy" into tIcon
         break
      default
         put lkMix(lkColor("emerald"), "255,255,255", 0.2) into tColor
         put "check" into tIcon
   end switch
   lock screen
   put pText into field "toast_label"
   lkIconInk the long id of image "toast_icon", tIcon, tColor
   put min(sWidth - acPlay() - kSide - 40, the formattedWidth of field "toast_label" + 62) into tWidth
   put kSide + (sWidth - acPlay() - kSide - tWidth) div 2 into tLeft
   put sHeight - 64 into tTop
   set the rect of group "toast" to tLeft, tTop, tLeft + tWidth, tTop + 40
   set the rect of graphic "toast_bg" to tLeft, tTop, tLeft + tWidth, tTop + 40
   set the topLeft of image "toast_icon" to tLeft + 16, tTop + 12
   set the rect of field "toast_label" to tLeft + 42, tTop + 11 - kTextInset, tLeft + tWidth - 10, tTop + 31
   show group "toast"
   unlock screen
   put lkNow() + 2800 into sToastUntil
   acRestore tSaved
end acToast

-- A course's progress is forgotten, once the learner says so
private command acAskForget
   local tTitle
   put sCourses[sCourse]["title"] into tTitle
   answer warning "Start" && quote & tTitle & quote && "again? The lessons you finished and the code you wrote in it are forgotten." \
         with "Cancel" or "Start again"
   if it is not "Start again" then
      exit acAskForget
   end if
   acForget sCourse
   put empty into sMode
   acSyncSide
   acRender
   acSetupPlayground
   acToast "This course starts afresh.", "ok"
end acAskForget

-- A course file from anywhere, for this session
private command acOpenCourseFile
   local tFile, tCourse, tIndex
   answer file "Open an xTalk Academy course (a .txt file):" with type "Course|txt|TEXT"
   if it is empty then
      exit acOpenCourseFile
   end if
   put it into tFile
   put acParseCourse(acReadFile(tFile)) into tCourse
   if tCourse["lessons"] is not an integer or tCourse["lessons"] < 1 then
      acToast "That file has no lessons: each one begins with a line" && quote & "lesson: its title" & quote & ".", "warn"
      exit acOpenCourseFile
   end if
   repeat with tIndex = 1 to sCourses["count"]
      if sCourses[tIndex]["id"] is tCourse["id"] and sCourses[tIndex]["file"] is not tFile then
         acToast "A course with the id" && quote & tCourse["id"] & quote && "is open already.", "warn"
         exit acOpenCourseFile
      end if
   end repeat
   if tFile is not among the lines of sExtra then
      put tFile & return after sExtra
   end if
   acRebuild
   acGoTo tCourse["id"], 0
end acOpenCourseFile

-- The courses read again, and the sidebar built again for them
private command acRebuild
   local tSaved
   acKeepDraft
   acLoadCourses
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   lock screen
   lock messages
   lkForget "side"
   lkForget "page"
   repeat while the number of controls of me > 0
      delete control 1 of me
   end repeat
   unlock messages
   acBuild
   acLayout
   unlock screen
   lkEnter "side"
   acRestore tSaved
end acRebuild

################################################################################
#
# One frame
#

on lkFrame
   local tY
   -- The sidebar's highlight slides to the course in front
   if sNavTarget is not empty and abs(sNavY - sNavTarget) > 0.5 then
      put sNavY + (sNavTarget - sNavY) * min(1, lkDt() * 14) into sNavY
      put round(sNavY) into tY
      set the top of graphic "navHi" to tY
      set the top of graphic "navBar" to tY + 7
   else if sNavTarget is not empty and sNavY is not sNavTarget then
      put sNavTarget into sNavY
      set the top of graphic "navHi" to sNavY
      set the top of graphic "navBar" to sNavY + 7
   end if
   if sToastUntil is not empty and lkNow() > sToastUntil then
      put empty into sToastUntil
      hide group "toast"
   end if
   -- the line numbers follow the editor however it was scrolled
   if the vScroll of field "edNums" is not the vScroll of field "ed" then
      set the vScroll of field "edNums" to the vScroll of field "ed"
   end if
   acHeroFrame
   acConfettiFrame
end lkFrame

-- Confetti falls from the top of the page, each bit at its own speed and
-- spin, and is gone in a few seconds
private command acCelebrate
   local tIndex
   if the mode of me is 0 then
      exit acCelebrate
   end if
   put lkNow() into sConfetti["start"]
   repeat with tIndex = 1 to 48
      put kSide + random(sWidth - kSide) into sConfetti[tIndex]["x"]
      put -20 - random(220) into sConfetti[tIndex]["y"]
      put (random(160) - 80) into sConfetti[tIndex]["vx"]
      put 220 + random(260) into sConfetti[tIndex]["vy"]
      put random(628) / 100 into sConfetti[tIndex]["phase"]
   end repeat
   show group "confetti"
end acCelebrate

private command acConfettiFrame
   local tT, tIndex, tX, tY, tW
   if sConfetti["start"] is empty then
      exit acConfettiFrame
   end if
   put (lkNow() - sConfetti["start"]) / 1000 into tT
   if tT > 3.2 then
      put empty into sConfetti
      hide group "confetti"
      exit acConfettiFrame
   end if
   repeat with tIndex = 1 to 48
      put sConfetti[tIndex]["x"] + sConfetti[tIndex]["vx"] * tT + 18 * sin(tT * 5 + sConfetti[tIndex]["phase"]) into tX
      put sConfetti[tIndex]["y"] + sConfetti[tIndex]["vy"] * tT + 90 * tT * tT into tY
      -- (a bit turns as it falls: it is drawn narrower and wider)
      put max(2, round(9 * abs(cos(tT * 7 + sConfetti[tIndex]["phase"])))) into tW
      set the rect of graphic ("conf" & tIndex) to round(tX), round(tY), round(tX) + tW, round(tY) + 11
      set the blendLevel of graphic ("conf" & tIndex) to round(max(0, min(100, (tT - 2.2) * 100)))
   end repeat
end acConfettiFrame

################################################################################
#
# Drawing a page
#

-- Draws the page in front anew; with pKeepScroll, where it was scrolled to
command acRender pKeepScroll
   local tSaved, tScroll
   if the mode of me is 0 and not the visible of me then
      exit acRender
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   put 0 into tScroll
   if pKeepScroll is true then
      put the vScroll of group "body" into tScroll
   end if
   lock screen
   lock messages
   lkForget "page"
   if there is a group "page" then
      delete group "page"
   end if
   -- (the new page is laid out at the body's top: a scroll left over
   -- from the last one would push it down by as much)
   set the vScroll of group "body" to 0
   put empty into sCode
   put empty into sQuizInfo
   put empty into sHero
   if sCourses["count"] < 1 then
      acRenderEmpty
   else if sLesson[sCourse] is 0 then
      acRenderLanding
   else
      acRenderLesson
   end if
   set the vScroll of group "body" to tScroll
   unlock messages
   unlock screen
   if pKeepScroll is not true then
      lkEnter "page"
   end if
   acRestore tSaved
end acRender

-- The header: a page's title and tagline, or none (a first page)
private command acHeader pTitle, pTag
   local tSize
   if pTitle is empty then
      hide group "hdr"
      set the rect of group "body" to kSide, 0, sWidth - acPlay(), sHeight
      exit acHeader
   end if
   show group "hdr"
   set the rect of group "body" to kSide, kHeaderHeight, sWidth - acPlay(), sHeight
   put pTitle into field "hdrTitle"
   -- (a long title is set smaller, to stay on one line)
   put 26 into tSize
   set the textSize of field "hdrTitle" to tSize
   repeat while tSize > 17 and the formattedWidth of field "hdrTitle" > the width of field "hdrTitle"
      subtract 2 from tSize
      set the textSize of field "hdrTitle" to tSize
   end repeat
   put pTag into field "hdrTag"
end acHeader

-- The page's group, in the body
private command acBeginPage
   local tObj
   acColumn
   put lkGroup("page", the rect of group "body", "body") into tObj
   set the lockLoc of tObj to false
   -- (the first control made in an empty group is moved to the group's
   -- top left: this one is there already, and holds the page's top)
   get lkBox("p_top", lkR(kSide, the top of group "body", kSide + 1, the top of group "body" + 1), empty, 0, "page")
   put the top of group "body" + 28 into sY
end acBeginPage

-- Room below the last thing on the page
private command acEndPage
   get lkBox("p_end", lkR(sX, sY, sX + 1, sY + 48), empty, 0, "page")
end acEndPage

-- A field of htmlText at sY, as tall as its text
private function acHtmlField pName, pLeft, pWidth, pHtml, pSize, pColor, pGroup
   local tObj
   if pGroup is empty then
      put "page" into pGroup
   end if
   put lkLabel(pName, lkR(pLeft, sY, pLeft + pWidth, sY + 20), empty, pSize, pColor, pGroup) into tObj
   set the htmlText of tObj to pHtml
   acFit tObj
   return tObj
end acHtmlField

-- A field made as tall as its text, its top kept
private command acFit pObj
   local tRect
   put the rect of pObj into tRect
   set the rect of pObj to item 1 of tRect, item 2 of tRect, item 3 of tRect, \
         item 2 of tRect + the formattedHeight of pObj + kTextInset + 2
end acFit

-- A label's text in the middle of a band, top to bottom
private command acCenterIn pObj, pTop, pBottom
   local tHeight
   put min(the formattedHeight of pObj, pBottom - pTop) into tHeight
   set the rect of pObj to item 1 of the rect of pObj, (pTop + pBottom - tHeight) div 2 - kTextInset div 2, \
         item 3 of the rect of pObj, (pTop + pBottom + tHeight) div 2 + kTextInset
end acCenterIn

-- When there are no courses at all: where they would be
private command acRenderEmpty
   local tObj
   acHeader "xTalk Academy", "No courses in this copy of the IDE"
   acBeginPage
   put acHtmlField("p_none", sX, sColW, "<p>" & lkEscape("The courses are text files in the folder" && \
         acFolder() & "/courses, and there are none there.") & "</p>", 15, lkColor("soft")) into tObj
   put the bottom of tObj + 20 into sY
   acEndPage
end acRenderEmpty

################################################################################
#
# A course's first page
#

private command acRenderLanding
   local tCourse, tMinutes, tIndex, tNext, tDone, tButton1, tButton2, tStats, tAccent, tObj, tColors
   put sCourse into tCourse
   put acAccent() into tAccent
   acHeader empty
   acBeginPage
   put 0 into tMinutes
   put empty into tNext
   repeat with tIndex = 1 to sCourses[tCourse]["lessons"]
      add sCourses[tCourse]["lesson"][tIndex]["minutes"] to tMinutes
      if tNext is empty and not acIsDone(tCourse, tIndex) then
         put tIndex into tNext
      end if
   end repeat
   put acDoneCount(tCourse) into tDone
   if tDone is 0 then
      put "Start with lesson 1|go 1|play" into tButton1
   else if tNext is empty then
      put "Read it again|go 1|book-open" into tButton1
   else
      put "Go on: lesson" && tNext & "|go" && tNext & "|play" into tButton1
   end if
   if sCourses[tCourse]["teachers"] is "yes" then
      put "Open a course file|openCourse|folder-open" into tButton2
   end if
   put sCourses[tCourse]["lessons"] && "lessons in" && sCourses[tCourse]["units"] && "units, about" && \
         acHours(tMinutes) into tStats
   if tDone > 0 then
      put ", and" && tDone && "done" after tStats
   end if
   switch sCourses[tCourse]["accent"]
      case "orange"
      case "amber"
      case "flame"
         put "234,88,12|219,39,119|124,58,237" into tColors
         break
      case "sky"
      case "indigo"
         put "2,132,199|79,70,229|124,58,237" into tColors
         break
      case "violet"
      case "pink"
         put "124,58,237|219,39,119|249,115,22" into tColors
         break
      default
         put "5,150,105|13,148,136|2,132,199" into tColors
   end switch
   acHero toUpper(sCourses[tCourse]["eyebrow"]), sCourses[tCourse]["title"], sCourses[tCourse]["blurb"], \
         tStats & ".", tColors, tButton1, tButton2
   repeat with tIndex = 1 to sCourses[tCourse]["units"]
      acUnitCard tCourse, tIndex
   end repeat
   -- Who made it, and starting again
   if sCourses[tCourse]["credit"] is not empty then
      put acHtmlField("p_credit", sX, sColW, "<p>" & acInline(sCourses[tCourse]["credit"]) & "</p>", 12, lkColor("muted")) into tObj
      add the height of tObj + 14 to sY
   end if
   if tDone > 0 then
      get lkButton("p_forget", sX, sY, 32, "Start this course again", "rotate-cw", "ghost", tAccent, "page", "forget", 0, "page")
      add 32 + 10 to sY
   end if
   acEndPage
end acRenderLanding

-- Minutes as words: "40 minutes", "an hour", "3 hours"
private function acHours pMinutes
   if pMinutes < 55 then
      return round(pMinutes / 5) * 5 && "minutes"
   end if
   if pMinutes < 90 then
      return "an hour"
   end if
   return round(pMinutes / 60) && "hours"
end acHours

-- A unit, as a card: its icon, number and title, what it is about, and a
-- line for each of its lessons
private command acUnitCard pCourse, pUnit
   local tAccent, tTop, tName, tObj, tFirst, tLast, tIndex, tRow, tLook, tDone, tCount, tY, tMinutes
   put acAccent() into tAccent
   put sCourses[pCourse]["unit"][pUnit]["first"] into tFirst
   put sCourses[pCourse]["unit"][pUnit]["last"] into tLast
   put "p_unit" & pUnit into tName
   put sY into tTop
   put lkBox(tName & "_bg", lkR(sX, tTop, sX + sColW, tTop + 100), lkColor("panel"), 16, "page") into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 10, 2, 22
   get lkBox(tName & "_tint", lkR(sX + 22, tTop + 22, sX + 66, tTop + 66), lkTint(tAccent, 0.12), 12, "page")
   get lkIcon(tName & "_icon", sCourses[pCourse]["unit"][pUnit]["icon"], lkAccentInk(tAccent), lkR(sX + 33, tTop + 33, sX + 55, tTop + 55), "page")
   put lkLabel(tName & "_eyebrow", lkR(sX + 82, tTop + 22, sX + sColW - 120, tTop + 38), "UNIT" && pUnit, 11, lkAccentInk(tAccent), "page") into tObj
   set the textStyle of tObj to "bold"
   put lkLabel(tName & "_title", lkR(sX + 82, tTop + 40, sX + sColW - 22, tTop + 64), sCourses[pCourse]["unit"][pUnit]["title"], 18, lkColor("ink"), "page") into tObj
   set the textStyle of tObj to "bold"
   put 0 into tDone
   put tLast - tFirst + 1 into tCount
   repeat with tIndex = tFirst to tLast
      if acIsDone(pCourse, tIndex) then
         add 1 to tDone
      end if
   end repeat
   put lkLabel(tName & "_count", lkR(sX + sColW - 140, tTop + 22, sX + sColW - 22, tTop + 38), tDone && "of" && tCount && "done", 12, \
         lkColor("muted"), "page", "right") into tObj
   if tDone is tCount and tCount > 0 then
      set the textColor of tObj to lkColor("ok")
   end if
   put tTop + 70 into sY
   if sCourses[pCourse]["unit"][pUnit]["blurb"] is not empty then
      put acHtmlField(tName & "_blurb", sX + 82, sColW - 104, "<p>" & acInline(sCourses[pCourse]["unit"][pUnit]["blurb"]) & "</p>", \
            14, lkColor("soft")) into tObj
      put the bottom of tObj + 8 into sY
   end if
   add 6 to sY
   -- the lessons, a row each
   repeat with tIndex = tFirst to tLast
      put "p_row" & tIndex into tRow
      put sY into tY
      get lkGroup(tRow, lkR(sX + 14, tY, sX + sColW - 14, tY + 38), "page")
      put lkBox(tRow & "_bg", lkR(sX + 14, tY, sX + sColW - 14, tY + 38), lkColor("panel"), 10, tRow) into tObj
      if acIsDone(pCourse, tIndex) then
         get lkOval(tRow & "_dot", lkR(sX + 70, tY + 9, sX + 90, tY + 29), lkTint(lkColor("ok"), 0.16), tRow)
         get lkIcon(tRow & "_tick", "check", lkColor("ok"), lkR(sX + 73, tY + 12, sX + 87, tY + 26), tRow)
      else
         get lkOval(tRow & "_dot", lkR(sX + 70, tY + 9, sX + 90, tY + 29), lkColor("bg"), tRow)
         put lkLabel(tRow & "_num", lkR(sX + 70, tY + 12, sX + 90, tY + 26), tIndex, 10, lkColor("soft"), tRow, "center") into tObj
         acCenterIn tObj, tY + 9, tY + 29
      end if
      put lkLabel(tRow & "_label", lkR(sX + 102, tY + 10, sX + sColW - 110, tY + 30), sCourses[pCourse]["lesson"][tIndex]["title"], \
            14, lkColor("ink"), tRow) into tObj
      lkEllipsize tObj
      acCenterIn tObj, tY, tY + 38
      put sCourses[pCourse]["lesson"][tIndex]["minutes"] into tMinutes
      put lkLabel(tRow & "_min", lkR(sX + sColW - 110, tY + 10, sX + sColW - 30, tY + 30), tMinutes && "min", 12, lkColor("muted"), tRow, "right") into tObj
      acCenterIn tObj, tY, tY + 38
      put tRow & "_bg" into tLook["bg"]
      put lkColor("panel") into tLook["bg0"]
      put lkTint(tAccent, 0.07) into tLook["bg1"]
      put tRow & "_label" into tLook["label"]
      put lkColor("ink") into tLook["ink0"]
      put lkAccentText(tAccent, 0.35) into tLook["ink1"]
      lkLive tRow, "page", "go" && tIndex, tLook
      add 40 to sY
   end repeat
   add 14 to sY
   set the rect of graphic (tName & "_bg") to sX, tTop, sX + sColW, sY
   add 22 to sY
end acUnitCard

-- The big banner at the top of a first page: a gradient, lights that
-- float over it, and its words laid out from the top down
private command acHero pEyebrow, pTitle, pText, pStats, pColors, pButton1, pButton2
   local tTop, tBottom, tObj, tBg, tIndex, tLeft, tRight, tX, tSize, tY, tButton, tName, tWidth
   put sY - 6 into tTop
   put sX + 36 into tLeft
   put sX + sColW - 36 into tRight
   get lkGroup("p_hero", lkR(sX, tTop, sX + sColW, tTop + 250), "page")
   put lkBox("p_heroBg", lkR(sX, tTop, sX + sColW, tTop + 250), lkColor("indigo"), 22, "p_hero") into tBg
   -- lights: soft round glows, and sparkles
   repeat with tIndex = 1 to 4
      put item tIndex of "240,170,200,130" into tSize
      put lkOval("p_heroGlow" & tIndex, lkR(0, 0, tSize, tSize), "255,255,255", "p_hero") into tObj
      lkGlowFill tObj, "255,255,255", item tIndex of "70,55,60,45"
      set the blendLevel of tObj to 40
   end repeat
   repeat with tIndex = 1 to 6
      put lkBox("p_heroStar" & tIndex, lkR(0, 0, 10, 10), "255,255,255", 0, "p_hero") into tObj
      set the style of tObj to "polygon"
      set the points of tObj to lkSparklePoints(0, 0, item tIndex of "9,6,11,5,7,8")
      set the blendLevel of tObj to 30
   end repeat
   if pEyebrow is empty then
      put "COURSE" into pEyebrow
   end if
   put lkLabel("p_heroEyebrow", lkR(tLeft, tTop + 32, tRight, tTop + 48), pEyebrow, 12, "255,255,255", "p_hero") into tObj
   set the textStyle of tObj to "bold"
   set the blendLevel of tObj to 25
   put lkLabel("p_heroTitle", lkR(tLeft, tTop + 54, tRight, tTop + 94), pTitle, 32, "255,255,255", "p_hero") into tObj
   set the textStyle of tObj to "bold"
   set the dontWrap of tObj to true
   -- (a smaller size where the column is too narrow for it on one line)
   repeat while the formattedWidth of tObj > tRight - tLeft and the textSize of tObj > 20
      set the textSize of tObj to the textSize of tObj - 2
   end repeat
   put tTop + 102 into tY
   put lkLabel("p_heroText", lkR(tLeft, tY, tRight, tY + 40), pText, 15, "255,255,255", "p_hero") into tObj
   acFit tObj
   set the blendLevel of tObj to 8
   put the bottom of tObj + 20 into tY
   put tLeft into tX
   -- The buttons go in a row, and one that would pass the right edge
   -- starts the next row, as on Learn's first pages
   set the itemDelimiter to "|"
   repeat with tIndex = 1 to 2
      put param(5 + tIndex) into tButton
      if tButton is empty then
         next repeat
      end if
      put "p_heroB" & tIndex into tName
      put lkButton(tName, tX, tY, 38, item 1 of tButton, item 3 of tButton, "light", \
            acAccent(), "p_hero", item 2 of tButton, 0, "page") into tWidth
      if tX > tLeft and tX + tWidth > tRight then
         add 38 + 12 to tY
         put tLeft into tX
         set the topLeft of group tName to tX, tY
      end if
      add tWidth + 12 to tX
   end repeat
   set the itemDelimiter to comma
   if tX > tLeft then
      add 38 + 20 to tY
   end if
   put lkLabel("p_heroStats", lkR(tLeft, tY, tRight, tY + 16), pStats, 12, "255,255,255", "p_hero") into tObj
   acFit tObj
   set the blendLevel of tObj to 25
   put the bottom of tObj + 26 into tBottom
   -- (the group's top left stays where it is, so nothing in it moves)
   set the rect of group "p_hero" to sX, tTop, sX + sColW, tBottom
   set the rect of tBg to sX, tTop, sX + sColW, tBottom
   lkGradient tBg, pColors, sX & "," & tTop, (sX + sColW) & "," & tBottom
   put lkNow() into sHero["start"]
   put tBottom + 30 into sY
   acHeroFrame
end acHero

-- The hero's lights drift; their places are worked out from the hero's
-- rect each frame, so that they move with the page when it scrolls
private command acHeroFrame
   local tRect, tW, tH, tT, tIndex, tX, tY, tObj
   if sHero["start"] is empty or there is no graphic "p_heroBg" then
      exit acHeroFrame
   end if
   put the rect of graphic "p_heroBg" into tRect
   put item 3 of tRect - item 1 of tRect into tW
   put item 4 of tRect - item 2 of tRect into tH
   put (lkNow() - sHero["start"]) / 1000 into tT
   repeat with tIndex = 1 to 4
      put item 1 of tRect + tW * (item tIndex of "0.72,0.9,0.55,0.18") + 60 * sin(tT * (0.35 + tIndex * 0.07) + tIndex * 1.7) into tX
      put item 2 of tRect + tH * (item tIndex of "0.2,0.85,0.95,0.1") + 30 * cos(tT * (0.3 + tIndex * 0.05) + tIndex) into tY
      set the loc of graphic ("p_heroGlow" & tIndex) to round(tX), round(tY)
   end repeat
   repeat with tIndex = 1 to 6
      put "p_heroStar" & tIndex into tObj
      put item 1 of tRect + tW * (item tIndex of "0.62,0.7,0.8,0.88,0.94,0.76") into tX
      put item 2 of tRect + tH * (item tIndex of "0.22,0.62,0.3,0.7,0.18,0.86") + 6 * sin(tT * 1.3 + tIndex) into tY
      set the loc of graphic tObj to round(tX), round(tY)
      set the blendLevel of graphic tObj to round(30 + 45 * (0.5 + 0.5 * sin(tT * 2.2 + tIndex * 1.9)))
   end repeat
end acHeroFrame

################################################################################
#
# A lesson
#

private command acRenderLesson
   local tCourse, tLesson, tUnit, tTag, tBlocks, tIndex, tQuiz
   put sCourse into tCourse
   put sLesson[tCourse] into tLesson
   put sCourses[tCourse]["lesson"][tLesson]["unit"] into tUnit
   put sCourses[tCourse]["unit"][tUnit]["title"] && "  " & numToCodepoint(183) & "  Lesson" && tLesson && "of" && \
         sCourses[tCourse]["lessons"] && "  " & numToCodepoint(183) & "  " & sCourses[tCourse]["lesson"][tLesson]["minutes"] && "min" into tTag
   if acIsDone(tCourse, tLesson) and acHasWork(tCourse, tLesson) then
      put "  " & numToCodepoint(183) & "  Done" && numToCodepoint(10003) after tTag
   end if
   acHeader sCourses[tCourse]["lesson"][tLesson]["title"], tTag
   acBeginPage
   put acBlocks(sCourses[tCourse]["lesson"][tLesson]["body"]) into tBlocks
   put 0 into tQuiz
   repeat with tIndex = 1 to tBlocks["count"]
      switch tBlocks[tIndex]["kind"]
         case "text"
            acTextBlock "p_t" & tIndex, sX, sColW, tBlocks[tIndex]["lines"], "page"
            break
         case "code"
            acCodeBlock tIndex, tBlocks[tIndex]
            break
         case "quiz"
            add 1 to tQuiz
            acQuizCard tIndex, tBlocks[tIndex], tQuiz
            break
         case "challenge"
            acChallengeCard tIndex, tBlocks[tIndex]
            break
         default
            acCallout tIndex, tBlocks[tIndex]["kind"], tBlocks[tIndex]["lines"]
      end switch
   end repeat
   acLessonFoot tLesson
   acEndPage
end acRenderLesson

-- A run of text, in a field: headings ("## "), smaller headings ("### "),
-- bullets ("- "), numbered steps ("1. ") and paragraphs (lines that follow
-- each other, up to a blank line), with `code`, **bold** and
-- [links](https://...) in them
private command acTextBlock pName, pLeft, pWidth, pLines, pGroup
   local tHtml, tKinds, tCount, tN, tObj
   put acTextHtml(pLines, tKinds) into tHtml
   put tKinds["count"] into tCount
   if tCount is 0 then
      exit acTextBlock
   end if
   put acHtmlField(pName, pLeft, pWidth, tHtml, 15, lkColor("text"), pGroup) into tObj
   repeat with tN = 1 to tCount
      switch tKinds[tN]
         case "heading"
            if tN > 1 then
               set the spaceAbove of line tN of tObj to 18
            end if
            set the spaceBelow of line tN of tObj to 4
            break
         case "sub"
            if tN > 1 then
               set the spaceAbove of line tN of tObj to 14
            end if
            set the spaceBelow of line tN of tObj to 2
            break
         case "bullet"
         case "number"
            set the leftIndent of line tN of tObj to 24
            set the firstIndent of line tN of tObj to -16
            if tN > 1 and tKinds[tN - 1] is not tKinds[tN] then
               set the spaceAbove of line tN of tObj to 10
            else
               set the spaceAbove of line tN of tObj to 4
            end if
            break
         default
            if tN > 1 then
               set the spaceAbove of line tN of tObj to 12
            end if
      end switch
   end repeat
   acFit tObj
   put the bottom of tObj + 14 into sY
end acTextBlock

-- The htmlText of a run of text (see acTextBlock), a paragraph a line, and
-- the kind of each line (rKinds[n], and rKinds["count"])
private function acTextHtml pLines, @rKinds
   local tItems, tCount, tLine, tTrim, tKind, tN, tHtml, tAccent, tText
   put 0 into tCount
   put empty into tKind
   repeat for each line tLine in pLines
      put word 1 to -1 of tLine into tTrim
      if tTrim is empty then
         put empty into tKind
         next repeat
      end if
      if char 1 to 3 of tTrim is "## " or char 1 to 4 of tTrim is "### " then
         add 1 to tCount
         if char 3 of tTrim is "#" then
            put "sub" into tItems[tCount]["kind"]
            put word 1 to -1 of acSpan(tTrim, 4, -1) into tItems[tCount]["text"]
         else
            put "heading" into tItems[tCount]["kind"]
            put word 1 to -1 of acSpan(tTrim, 3, -1) into tItems[tCount]["text"]
         end if
         put empty into tKind
         next repeat
      end if
      if char 1 to 2 of tTrim is "- " then
         add 1 to tCount
         put "bullet" into tItems[tCount]["kind"]
         put word 1 to -1 of acSpan(tTrim, 3, -1) into tItems[tCount]["text"]
         put "bullet" into tKind
         next repeat
      end if
      if matchText(tTrim, "^[0-9]+\. ") then
         add 1 to tCount
         put "number" into tItems[tCount]["kind"]
         put tTrim into tItems[tCount]["text"]
         put "number" into tKind
         next repeat
      end if
      -- a line that goes on from the one before it
      if tKind is not empty then
         put space & tTrim after tItems[tCount]["text"]
         next repeat
      end if
      add 1 to tCount
      put "para" into tItems[tCount]["kind"]
      put tTrim into tItems[tCount]["text"]
      put "para" into tKind
   end repeat
   put acAccent() into tAccent
   repeat with tN = 1 to tCount
      put tItems[tN]["kind"] into rKinds[tN]
      put tItems[tN]["text"] into tText
      switch tItems[tN]["kind"]
         case "heading"
            put "<p><font size=" & quote & "19" & quote & " color=" & quote & lkHex(lkColor("ink")) & quote & "><b>" & \
                  acInline(tText) & "</b></font></p>" after tHtml
            break
         case "sub"
            put "<p><font size=" & quote & "16" & quote & " color=" & quote & lkHex(lkAccentText(tAccent, 0.25)) & \
                  quote & "><b>" & acInline(tText) & "</b></font></p>" after tHtml
            break
         case "bullet"
            put "<p><font color=" & quote & lkHex(lkAccentInk(tAccent)) & quote & ">&#8226;</font>" & tab & acInline(tText) & "</p>" after tHtml
            break
         case "number"
            put "<p><font color=" & quote & lkHex(lkAccentInk(tAccent)) & quote & "><b>" & lkEscape(word 1 of tText) & "</b></font>" & tab & \
                  acInline(word 2 to -1 of tText) & "</p>" after tHtml
            break
         default
            put "<p>" & acInline(tText) & "</p>" after tHtml
      end switch
   end repeat
   put tCount into rKinds["count"]
   return tHtml
end acTextHtml

-- A line's words as htmlText: `code` in the code font and the accent's
-- dark shade, **bold**, and [a link](https://...)
function acInline pText
   local tOut, tPos, tLen, tChar, tEnd, tClose
   put the number of chars of pText into tLen
   put 1 into tPos
   repeat while tPos <= tLen
      put char tPos of pText into tChar
      if tChar is "`" then
         put offset("`", pText, tPos) into tEnd
         if tEnd > 0 then
            put acCodeSpan(char tPos + 1 to tPos + tEnd - 1 of pText) after tOut
            put tPos + tEnd + 1 into tPos
            next repeat
         end if
      else if tChar is "*" and char tPos + 1 of pText is "*" then
         put offset("**", pText, tPos + 1) into tEnd
         if tEnd > 0 then
            put "<b>" & acInline(char tPos + 2 to tPos + tEnd of pText) & "</b>" after tOut
            put tPos + tEnd + 3 into tPos
            next repeat
         end if
      else if tChar is "[" then
         put offset("](", pText, tPos) into tEnd
         if tEnd > 0 then
            put offset(")", pText, tPos + tEnd + 1) into tClose
            if tClose > 0 then
               put "<a href=" & quote & lkEscape(char tPos + tEnd + 2 to tPos + tEnd + tClose of pText) & quote & ">" & \
                     acInline(char tPos + 1 to tPos + tEnd - 1 of pText) & "</a>" after tOut
               put tPos + tEnd + tClose + 2 into tPos
               next repeat
            end if
         end if
      end if
      put lkEscape(tChar) after tOut
      add 1 to tPos
   end repeat
   return tOut
end acInline

-- A word of code among words: the code font, on a tint
private function acCodeSpan pCode
   local tFace
   if lkCodeFont() is not empty then
      put " face=" & quote & lkCodeFont() & quote into tFace
   end if
   return "<font" & tFace & " color=" & quote & lkHex(lkAccentText(acAccent(), 0.45)) & quote & \
         " bgcolor=" & quote & lkHex(lkTint(acAccent(), 0.1)) & quote & ">" & lkEscape(pCode) & "</font>"
end acCodeSpan

-- Code, on a dark panel, in colour, with Try it (which puts it in the
-- playground and runs it) and Copy
private command acCodeBlock pIndex, pBlock
   local tCode, tName, tTop, tBox, tObj, tWidth, tNote
   put pBlock["lines"] into tCode
   if word 1 to -1 of tCode is empty then
      exit acCodeBlock
   end if
   put tCode into sCode[pIndex]["code"]
   put pBlock["flags"] into sCode[pIndex]["flags"]
   put "p_c" & pIndex into tName
   put sY + 4 into tTop
   put lkBox(tName & "_bg", lkR(sX, tTop, sX + sColW, tTop + 60), lkColor("code"), 14, "page") into tBox
   get lkOval(tName & "_d1", lkR(sX + 16, tTop + 15, sX + 26, tTop + 25), "248,113,113", "page")
   get lkOval(tName & "_d2", lkR(sX + 32, tTop + 15, sX + 42, tTop + 25), "251,191,36", "page")
   get lkOval(tName & "_d3", lkR(sX + 48, tTop + 15, sX + 58, tTop + 25), "52,211,153", "page")
   if pBlock["flags"] contains "text" then
      put "Text  " & numToCodepoint(183) & "  not code to run" into tNote
   else if pBlock["flags"] contains "dialog" then
      put "xTalk  " & numToCodepoint(183) & "  opens a dialog" into tNote
   else if pBlock["flags"] contains "error" then
      put "xTalk  " & numToCodepoint(183) & "  stops on an error, on purpose" into tNote
   else
      put "xTalk" into tNote
   end if
   put lkLabel(tName & "_kind", lkR(sX + 70, tTop + 11, sX + sColW - 180, tTop + 27), tNote, 11, "148,163,184", "page") into tObj
   set the dontWrap of tObj to true
   acCenterIn tObj, tTop + 10, tTop + 30
   put lkButton(tName & "_copy", sX, tTop + 7, 26, "Copy", "copy", "dark", empty, "page", "copy" && pIndex, 0, "page") into tWidth
   set the left of group (tName & "_copy") to sX + sColW - tWidth - 10
   lkRestAt tName & "_copy"
   -- (a block of text, a course file's markup say, is not run)
   if pBlock["flags"] is not "text" then
      put lkButton(tName & "_try", sX, tTop + 7, 26, "Try it", "play", "dark", empty, "page", "try" && pIndex, 0, "page") into tWidth
      set the left of group (tName & "_try") to the left of group (tName & "_copy") - tWidth - 8
      lkRestAt tName & "_try"
   end if
   put lkCodeField(tName & "_code", lkR(sX + 20, tTop + 42, sX + sColW - 20, tTop + 60), 13, 20, "page") into tObj
   set the dontWrap of tObj to false
   set the htmlText of tObj to lkCodeHtml(tCode)
   acFit tObj
   set the rect of tBox to sX, tTop, sX + sColW, the bottom of tObj + 14
   put the bottom of tBox + 18 into sY
end acCodeBlock

-- A tip, a note, an important point or a caution: a tinted panel with an
-- icon and a word for what it is
private command acCallout pIndex, pKind, pLines
   local tAccent, tIcon, tWord, tName, tBox, tBar, tObj, tHtml, tKinds, tTop
   switch pKind
      case "tip"
         put lkColor("emerald") into tAccent
         put "lightbulb" into tIcon
         put "Tip" into tWord
         break
      case "note"
         put lkColor("sky") into tAccent
         put "info" into tIcon
         put "Note" into tWord
         break
      case "important"
         put lkColor("violet") into tAccent
         put "star" into tIcon
         put "Remember" into tWord
         break
      default
         put lkColor("rose") into tAccent
         put "triangle-alert" into tIcon
         put "Watch out" into tWord
   end switch
   put acTextHtml(pLines, tKinds) into tHtml
   if tHtml is empty then
      exit acCallout
   end if
   put "p_n" & pIndex into tName
   put sY + 2 into tTop
   put lkBox(tName & "_bg", lkR(sX, tTop, sX + sColW, tTop + 60), lkTint(tAccent, 0.07), 12, "page") into tBox
   lkBorder tBox, lkTint(tAccent, 0.3)
   put lkBox(tName & "_bar", lkR(sX, tTop, sX + 4, tTop + 60), tAccent, 0, "page") into tBar
   get lkIcon(tName & "_icon", tIcon, lkAccentInk(tAccent), lkR(sX + 18, tTop + 15, sX + 36, tTop + 33), "page")
   get lkLabel(tName & "_word", lkR(sX + 46, tTop + 15, sX + 200, tTop + 33), tWord, 13, lkAccentText(tAccent, 0.3), "page")
   set the textStyle of field (tName & "_word") to "bold"
   put tTop + 38 into sY
   put acHtmlField(tName & "_text", sX + 46, sColW - 66, tHtml, 14, lkAccentText(tAccent, 0.55)) into tObj
   set the rect of tBox to sX, tTop, sX + sColW, the bottom of tObj + 14
   -- (the bar runs down the panel's left, inside its rounded corners)
   set the rect of tBar to sX + 1, tTop + 10, sX + 4, the bottom of tObj + 4
   put the bottom of tBox + 18 into sY
end acCallout

-- A quick check: a question and its answers, each a row to click. The
-- right one turns green and says why; a wrong one turns red, and the
-- learner tries again.
private command acQuizCard pIndex, pBlock, pQuiz
   local tKey, tRight, tPicked, tAccent, tName, tTop, tObj, tOpt, tRow, tY, tLook, tInk, tFill, tIcon, tText, tColor, tLetter
   put acKey(sCourse, sLesson[sCourse]) & "/" & pQuiz into tKey
   put sQuiz[tKey] is true into tRight
   put sPicked[tKey] into tPicked
   put pBlock["right"] into sQuizInfo[pQuiz]["right"]
   put acAccent() into tAccent
   put "p_q" & pIndex into tName
   put sY + 4 into tTop
   put lkBox(tName & "_bg", lkR(sX, tTop, sX + sColW, tTop + 60), lkColor("panel"), 16, "page") into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 10, 2, 22
   get lkIcon(tName & "_icon", "message-circle", lkAccentInk(tAccent), lkR(sX + 22, tTop + 20, sX + 38, tTop + 36), "page")
   put lkLabel(tName & "_word", lkR(sX + 46, tTop + 20, sX + 300, tTop + 36), "QUICK CHECK", 11, lkAccentInk(tAccent), "page") into tObj
   set the textStyle of tObj to "bold"
   put tTop + 46 into sY
   put acHtmlField(tName & "_question", sX + 22, sColW - 44, "<p><b>" & acInline(pBlock["question"]) & "</b></p>", 15, lkColor("ink")) into tObj
   put the bottom of tObj + 12 into sY
   repeat with tOpt = 1 to pBlock["optionCount"]
      put tName & "_o" & tOpt into tRow
      put sY into tY
      put lkColor("line") into tColor
      put lkColor("panel") into tFill
      put lkColor("ink") into tInk
      put empty into tIcon
      if tRight and tOpt is pBlock["right"] then
         put lkColor("ok") into tColor
         put lkTint(lkColor("ok"), 0.1) into tFill
         put "check" into tIcon
      else if not tRight and tOpt is tPicked then
         put lkColor("bad") into tColor
         put lkTint(lkColor("bad"), 0.08) into tFill
         put "x" into tIcon
      else if tRight then
         put lkColor("muted") into tInk
      end if
      get lkGroup(tRow, lkR(sX + 20, tY, sX + sColW - 20, tY + 40), "page")
      put lkBox(tRow & "_bg", lkR(sX + 22, tY, sX + sColW - 22, tY + 40), tFill, 12, tRow) into tObj
      lkBorder tObj, tColor
      put numToChar(64 + tOpt) into tLetter
      if tIcon is empty then
         get lkOval(tRow & "_dot", lkR(sX + 34, tY + 9, sX + 56, tY + 31), lkColor("bg"), tRow)
         put lkLabel(tRow & "_letter", lkR(sX + 34, tY + 12, sX + 56, tY + 28), tLetter, 12, lkColor("soft"), tRow, "center") into tObj
         set the textStyle of tObj to "bold"
         acCenterIn tObj, tY + 9, tY + 31
      else
         get lkOval(tRow & "_dot", lkR(sX + 34, tY + 9, sX + 56, tY + 31), tColor, tRow)
         get lkIcon(tRow & "_mark", tIcon, "255,255,255", lkR(sX + 38, tY + 13, sX + 52, tY + 27), tRow)
      end if
      put acHtmlField(tRow & "_label", sX + 68, sColW - 104, "<p>" & acInline(pBlock["option"][tOpt]) & "</p>", 14, tInk, tRow) into tObj
      -- (a long answer makes its row taller)
      if the height of tObj > 26 then
         set the rect of graphic (tRow & "_bg") to sX + 22, tY, sX + sColW - 22, the bottom of tObj + 10
         set the rect of group tRow to sX + 20, tY, sX + sColW - 20, the bottom of tObj + 10
         set the top of tObj to tY + 10 - kTextInset
      else
         acCenterIn tObj, tY, tY + 40
      end if
      if not tRight then
         put tRow & "_bg" into tLook["bg"]
         put tFill into tLook["bg0"]
         put lkMix(tFill, tAccent, 0.08) into tLook["bg1"]
         put tColor into tLook["line0"]
         put tAccent into tLook["line1"]
         lkLive tRow, "page", "quiz" && pQuiz && tOpt, tLook
      end if
      put the bottom of graphic (tRow & "_bg") + 8 into sY
   end repeat
   -- what the answer means
   if tRight then
      put "<p><b>Right.</b>" && acInline(pBlock["explain"]) & "</p>" into tText
      put lkAccentText(lkColor("ok"), 0.35) into tColor
   else if tPicked is not empty then
      put "<p><b>Not quite.</b> Have another look, and pick again.</p>" into tText
      put lkAccentText(lkColor("bad"), 0.3) into tColor
   else
      put empty into tText
   end if
   if tText is not empty then
      add 4 to sY
      put acHtmlField(tName & "_answer", sX + 24, sColW - 48, tText, 14, tColor) into tObj
      put the bottom of tObj + 4 into sY
   end if
   add 12 to sY
   set the rect of graphic (tName & "_bg") to sX, tTop, sX + sColW, sY
   add 18 to sY
end acQuizCard

-- The learner picks answer pOpt of quick check pQuiz
private command acAnswer pQuiz, pOpt
   local tKey
   put acKey(sCourse, sLesson[sCourse]) & "/" & pQuiz into tKey
   if sQuiz[tKey] is true then
      exit acAnswer
   end if
   put pOpt into sPicked[tKey]
   if pOpt is sQuizInfo[pQuiz]["right"] then
      put true into sQuiz[tKey]
      acSaveProgress
      acLessonCheck
   end if
   acRender true
end acAnswer

-- A lesson is done when every quick check in it has been answered right
-- and its challenge passed
private command acLessonCheck
   local tCourse, tLesson, tBlocks, tIndex, tQuiz, tPrefix
   put sCourse into tCourse
   put sLesson[tCourse] into tLesson
   if tLesson < 1 or acIsDone(tCourse, tLesson) then
      exit acLessonCheck
   end if
   put acKey(tCourse, tLesson) & "/" into tPrefix
   put acBlocks(sCourses[tCourse]["lesson"][tLesson]["body"]) into tBlocks
   put 0 into tQuiz
   repeat with tIndex = 1 to tBlocks["count"]
      if tBlocks[tIndex]["kind"] is "quiz" then
         add 1 to tQuiz
         if sQuiz[tPrefix & tQuiz] is not true then
            exit acLessonCheck
         end if
      else if tBlocks[tIndex]["kind"] is "challenge" then
         if sQuiz[tPrefix & "challenge"] is not true then
            exit acLessonCheck
         end if
      end if
   end repeat
   acMarkDone tCourse, tLesson
   put "  " & numToCodepoint(183) & "  Done" && numToCodepoint(10003) after field "hdrTag"
   acToast "Lesson" && tLesson && "done. On to the next!", "win"
end acLessonCheck

-- The challenge: what to do, what Check looks for, and the way to the
-- playground, a hint and a solution
private command acChallengeCard pIndex, pBlock
   local tKey, tDone, tAccent, tName, tTop, tObj, tX, tLine, tHtml, tWord, tWidth, tTries, tCount
   put acKey(sCourse, sLesson[sCourse]) into tKey
   put sQuiz[tKey & "/challenge"] is true into tDone
   put pBlock into sChallenge["block"]
   put acAccent() into tAccent
   put "p_ch" & pIndex into tName
   put sY + 6 into tTop
   put lkBox(tName & "_bg", lkR(sX, tTop, sX + sColW, tTop + 60), lkTint(tAccent, 0.04), 18, "page") into tObj
   lkBorder tObj, lkTint(tAccent, 0.45)
   lkShadow tObj, 14, 3, 26
   put lkBox(tName & "_tile", lkR(sX + 22, tTop + 22, sX + 62, tTop + 62), tAccent, 12, "page") into tObj
   lkGradient tObj, lkMix(tAccent, "255,255,255", 0.15) & "|" & lkMix(tAccent, "15,23,42", 0.2), (sX + 22) & "," & (tTop + 22), (sX + 62) & "," & (tTop + 62)
   get lkIcon(tName & "_icon", "trophy", "255,255,255", lkR(sX + 32, tTop + 32, sX + 52, tTop + 52), "page")
   put lkLabel(tName & "_word", lkR(sX + 76, tTop + 22, sX + sColW - 140, tTop + 38), "CHALLENGE", 11, lkAccentInk(tAccent), "page") into tObj
   set the textStyle of tObj to "bold"
   if tDone then
      put "Done" && numToCodepoint(10003) into tWord
   else
      put "To do" into tWord
   end if
   put lkLabel(tName & "_state", lkR(sX + sColW - 130, tTop + 22, sX + sColW - 22, tTop + 38), tWord, 12, lkColor("muted"), "page", "right") into tObj
   set the textStyle of tObj to "bold"
   if tDone then
      set the textColor of tObj to lkColor("ok")
   end if
   put tTop + 42 into sY
   acTextBlock tName & "_text", sX + 76, sColW - 98, pBlock["text"], "page"
   -- what Check looks for: each test's words
   repeat for each line tLine in pBlock["checks"]
      if tLine contains "|" then
         put "<p><font color=" & quote & lkHex(lkAccentInk(tAccent)) & quote & ">" & numToCodepoint(10003) & "</font>" & tab & \
               acInline(word 1 to -1 of acSpan(tLine, offset("|", tLine) + 1, -1)) & "</p>" after tHtml
      end if
   end repeat
   if tHtml is not empty then
      put acHtmlField(tName & "_looks", sX + 76, sColW - 98, "<p><font color=" & quote & lkHex(lkColor("muted")) & quote & \
            "><b>CHECK LOOKS FOR</b></font></p>" & tHtml, 13, lkColor("soft")) into tObj
      set the textSize of line 1 of tObj to 11
      repeat with tCount = 2 to the number of lines of tObj
         set the leftIndent of line tCount of tObj to 22
         set the firstIndent of line tCount of tObj to -18
         set the spaceAbove of line tCount of tObj to 3
      end repeat
      acFit tObj
      put the bottom of tObj + 14 into sY
   end if
   -- the buttons
   put sX + 76 into tX
   if sMode is "challenge" then
      put "Back to your code" into tWord
   else if sDrafts[tKey] is not empty then
      put "Go on with your code" into tWord
   else
      put "Start coding" into tWord
   end if
   add 10 + lkButton(tName & "_start", tX, sY, 36, tWord, "square-code", "primary", tAccent, "page", "start", 0, "page") to tX
   if pBlock["hint"] is not empty then
      if sChallenge["hint"] is true then
         put "Hide the hint" into tWord
      else
         put "Hint" into tWord
      end if
      add 10 + lkButton(tName & "_hint", tX, sY, 36, tWord, "lightbulb", "ghost", tAccent, "page", "hint", 0, "page") to tX
   end if
   if pBlock["solution"] is not empty and sChallenge["solution"] is not true then
      add 10 + lkButton(tName & "_sol", tX, sY, 36, "Solution", "key-round", "ghost", tAccent, "page", "solution", 0, "page") to tX
   end if
   add 36 + 16 to sY
   if sChallenge["hint"] is true and pBlock["hint"] is not empty then
      put lkBox(tName & "_hintBg", lkR(sX + 76, sY, sX + sColW - 22, sY + 40), lkTint(lkColor("amber"), 0.1), 12, "page") into tObj
      put sY + 12 into sY
      acTextBlock tName & "_hintText", sX + 92, sColW - 130, pBlock["hint"], "page"
      set the rect of graphic (tName & "_hintBg") to sX + 76, the top of graphic (tName & "_hintBg"), sX + sColW - 22, sY - 2
      add 12 to sY
   end if
   if sChallenge["solution"] is true and pBlock["solution"] is not empty then
      put sY into tTop
      put lkBox(tName & "_solBg", lkR(sX + 76, tTop, sX + sColW - 22, tTop + 60), lkColor("code"), 14, "page") into tObj
      put lkLabel(tName & "_solWord", lkR(sX + 94, tTop + 12, sX + 300, tTop + 28), "ONE WAY TO DO IT", 10, "148,163,184", "page") into tObj
      set the textStyle of tObj to "bold"
      put lkButton(tName & "_use", sX, tTop + 7, 26, "Use this", "square-code", "dark", empty, "page", "use", 0, "page") into tWidth
      set the left of group (tName & "_use") to sX + sColW - 22 - tWidth - 10
      lkRestAt tName & "_use"
      put lkCodeField(tName & "_solCode", lkR(sX + 94, tTop + 40, sX + sColW - 40, tTop + 60), 13, 20, "page") into tObj
      set the dontWrap of tObj to false
      set the htmlText of tObj to lkCodeHtml(pBlock["solution"])
      acFit tObj
      set the rect of graphic (tName & "_solBg") to sX + 76, tTop, sX + sColW - 22, the bottom of tObj + 14
      put the bottom of tObj + 28 into sY
   end if
   put sTries[tKey] into tTries
   if tTries is an integer and tTries > 0 and not tDone then
      put lkLabel(tName & "_tries", lkR(sX + 76, sY - 6, sX + sColW - 22, sY + 10), "Checked" && acTimes(tTries) & \
            ". Every try teaches you something.", 12, lkColor("muted"), "page") into tObj
      add 18 to sY
   end if
   add 6 to sY
   set the rect of graphic (tName & "_bg") to sX, the top of graphic (tName & "_bg"), sX + sColW, sY
   add 22 to sY
end acChallengeCard

private function acTimes pCount
   if pCount is 1 then
      return "once"
   end if
   if pCount is 2 then
      return "twice"
   end if
   return pCount && "times"
end acTimes

-- The foot of a lesson: the lessons before and after it
private command acLessonFoot pLesson
   local tWidth
   add 14 to sY
   put (sColW - 16) div 2 into tWidth
   if pLesson >= 1 then
      acFootCard "p_prev", sX, tWidth, "Previous", acFootTitle(pLesson - 1), "go prev", "arrow-left"
   end if
   if pLesson < sCourses[sCourse]["lessons"] then
      acFootCard "p_next", sX + sColW - tWidth, tWidth, "Next", acFootTitle(pLesson + 1), "go next", "arrow-right"
   end if
   add 86 to sY
end acLessonFoot

private function acFootTitle pLesson
   if pLesson is 0 then
      return "The course"
   end if
   return pLesson & ". " & sCourses[sCourse]["lesson"][pLesson]["title"]
end acFootTitle

-- A card that goes to another page, lit when the pointer is over it
private command acFootCard pName, pLeft, pWidth, pWord, pTitle, pAction, pIcon
   local tObj, tLook, tAccent, tRight
   put acAccent() into tAccent
   put pLeft + pWidth into tRight
   get lkGroup(pName, lkR(pLeft - 12, sY - 12, tRight + 12, sY + 88), "page")
   put lkBox(pName & "_bg", lkR(pLeft, sY, tRight, sY + 68), lkColor("panel"), 14, pName) into tObj
   lkBorder tObj, lkColor("line")
   lkShadow tObj, 10, 2, 26
   if pIcon is "arrow-left" then
      get lkIcon(pName & "_icon", pIcon, lkAccentInk(tAccent), lkR(pLeft + 18, sY + 25, pLeft + 36, sY + 43), pName)
      put lkLabel(pName & "_word", lkR(pLeft + 48, sY + 14, tRight - 16, sY + 30), pWord, 12, lkColor("muted"), pName) into tObj
      put lkLabel(pName & "_label", lkR(pLeft + 48, sY + 33, tRight - 16, sY + 54), pTitle, 15, lkColor("ink"), pName) into tObj
   else
      get lkIcon(pName & "_icon", pIcon, lkAccentInk(tAccent), lkR(tRight - 36, sY + 25, tRight - 18, sY + 43), pName)
      put lkLabel(pName & "_word", lkR(pLeft + 16, sY + 14, tRight - 48, sY + 30), pWord, 12, lkColor("muted"), pName, "right") into tObj
      put lkLabel(pName & "_label", lkR(pLeft + 16, sY + 33, tRight - 48, sY + 54), pTitle, 15, lkColor("ink"), pName, "right") into tObj
   end if
   set the textStyle of tObj to "bold"
   lkEllipsize tObj
   put pName & "_bg" into tLook["bg"]
   put lkColor("panel") into tLook["bg0"]
   put lkTint(tAccent, 0.06) into tLook["bg1"]
   put lkColor("line") into tLook["line0"]
   put tAccent into tLook["line1"]
   put true into tLook["shadow"]
   lkLive pName, "page", pAction, tLook
end acFootCard

################################################################################
#
# The playground
#

-- Puts in the playground what the lesson in front works with: pMode
-- "challenge" (the learner's code for it, or its starter), "example" (its
-- first example) or "free" (the scratch pad). With no pMode, the first of
-- those that the lesson has.
private command acSetupPlayground pMode
   local tKey, tChallenge, tCode, tWhat, tFirst, tIndex
   acKeepDraft
   put empty into sExample
   put empty into tKey
   if sLesson[sCourse] > 0 then
      put acKey(sCourse, sLesson[sCourse]) into tKey
      put acChallengeOf(sCourse, sLesson[sCourse]) into tChallenge
   end if
   put empty into tFirst
   repeat for each key tIndex in sCode
      if tFirst is empty or tIndex < tFirst then
         put tIndex into tFirst
      end if
   end repeat
   if pMode is "challenge" and tChallenge is empty then
      put empty into pMode
   end if
   if pMode is empty then
      if tChallenge is not empty then
         put "challenge" into pMode
      else if tFirst is not empty then
         put "example" into pMode
      else
         put "free" into pMode
      end if
   end if
   switch pMode
      case "challenge"
         if sDrafts[tKey] is not empty then
            put sDrafts[tKey] into tCode
         else
            put tChallenge["starter"] into tCode
         end if
         put "Challenge:" && sCourses[sCourse]["lesson"][sLesson[sCourse]]["title"] into tWhat
         break
      case "example"
         put sCode[tFirst]["code"] into tCode
         put tFirst into sExample
         put "An example from the lesson: change it, and run it again" into tWhat
         break
      default
         put "free" into pMode
         put sDrafts["~free"] into tCode
         if tCode is empty then
            put "-- The playground: type xTalk here and press Run." & return & \
                  "put" && quote & "Hello from the xTalk Academy!" & quote into tCode
         end if
         put "Your scratch pad: try anything" into tWhat
   end switch
   put pMode into sMode
   put tKey into sModeKey
   lock screen
   acSetEditor tCode
   put tWhat into field "playWhat"
   lkEllipsize the long id of field "playWhat"
   set the visible of group "check" to (pMode is "challenge")
   acLayout
   put empty into sOutput
   acShowOutput empty, empty, empty
   unlock screen
end acSetupPlayground

-- Keeps what the learner typed for the challenge, or in the scratch pad
private command acKeepDraft
   local tText, tChallenge
   if sMode is empty or there is no field "ed" of me then
      exit acKeepDraft
   end if
   put the text of field "ed" of me into tText
   if sMode is "challenge" and sModeKey is not empty then
      set the itemDelimiter to "/"
      put acChallengeOfKey(sModeKey) into tChallenge
      set the itemDelimiter to comma
      if tText is tChallenge["starter"] or word 1 to -1 of tText is empty then
         delete variable sDrafts[sModeKey]
      else
         put tText into sDrafts[sModeKey]
      end if
   else if sMode is "free" then
      put tText into sDrafts["~free"]
   end if
end acKeepDraft

-- The challenge of the lesson whose key is pKey
private function acChallengeOfKey pKey
   local tCourse, tLesson
   set the itemDelimiter to "/"
   repeat with tCourse = 1 to sCourses["count"]
      if sCourses[tCourse]["id"] is not item 1 of pKey then
         next repeat
      end if
      repeat with tLesson = 1 to sCourses[tCourse]["lessons"]
         if sCourses[tCourse]["lesson"][tLesson]["id"] is item 2 of pKey then
            return acChallengeOf(tCourse, tLesson)
         end if
      end repeat
   end repeat
   return empty
end acChallengeOfKey

-- The editor's text, in colour, with its line numbers
private command acSetEditor pCode
   lock screen
   set the htmlText of field "ed" to acEditorHtml(pCode)
   set the vScroll of field "ed" to 0
   acNumberLines
   unlock screen
end acSetEditor

-- htmlText for the editor: the kit's colours, and the empty line a last
-- return makes, which the kit leaves out
private function acEditorHtml pCode
   local tHtml
   put lkCodeHtml(pCode) into tHtml
   if pCode is empty or the last char of pCode is return then
      put "<p></p>" after tHtml
   end if
   return tHtml
end acEditorHtml

private command acNumberLines
   local tCount, tIndex, tNums
   put max(1, the number of lines of the text of field "ed") into tCount
   if the last char of the text of field "ed" is return then
      add 1 to tCount
   end if
   repeat with tIndex = 1 to tCount
      put tIndex & return after tNums
   end repeat
   delete the last char of tNums
   if field "edNums" is not tNums then
      put tNums into field "edNums"
   end if
   set the vScroll of field "edNums" to the vScroll of field "ed"
end acNumberLines

on textChanged
   if the short name of the target is "ed" then
      acNumberLines
      -- (the colours come back when the typing stops)
      if sRecolor is not empty then
         cancel sRecolor
      end if
      send "acRecolor" to me in 350 milliseconds
      put the result into sRecolor
      exit textChanged
   end if
   pass textChanged
end textChanged

-- The editor in colour again, its selection and scroll kept
on acRecolor
   local tChunk, tFrom, tTo, tScroll, tSaved, tFocused
   put empty into sRecolor
   if the mode of me is 0 then
      exit acRecolor
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   put false into tFocused
   if the selectedField is not empty then
      put the long id of the selectedField is the long id of field "ed" into tFocused
   end if
   if tFocused then
      put the selectedChunk into tChunk
      put word 2 of tChunk into tFrom
      put word 4 of tChunk into tTo
   end if
   put the vScroll of field "ed" into tScroll
   lock screen
   set the htmlText of field "ed" to acEditorHtml(the text of field "ed")
   if tFocused and tFrom is an integer and tTo is an integer then
      select char tFrom to tTo of field "ed"
   end if
   set the vScroll of field "ed" to tScroll
   acNumberLines
   unlock screen
   acRestore tSaved
end acRecolor

-- Return goes to a new line as far in as the one before, and further in
-- after a line that opens a block (if ... then, repeat, a handler); with
-- Control (Command on a Mac) down, it runs the code
on returnInField
   if the short name of the target is not "ed" then
      pass returnInField
   end if
   if the commandKey is down or the controlKey is down then
      acRunEditor
      exit returnInField
   end if
   acNewLine
end returnInField

on enterInField
   if the short name of the target is "ed" then
      acRunEditor
      exit enterInField
   end if
   pass enterInField
end enterInField

private command acNewLine
   local tChunk, tLineNo, tLine, tSpaces, tFirst
   put the selectedLine into tChunk
   put word 2 of tChunk into tLineNo
   if tLineNo is not an integer then
      put return into the selection
      exit acNewLine
   end if
   put line tLineNo of field "ed" into tLine
   put 0 into tSpaces
   repeat while char tSpaces + 1 of tLine is space
      add 1 to tSpaces
   end repeat
   put word 1 of tLine into tFirst
   if tFirst is "private" then
      put word 2 of tLine into tFirst
   end if
   if tFirst is among the items of "on,command,function,getprop,setprop,repeat,switch,case,default,try,catch,else" \
         or (tFirst is "if" and word -1 of tLine is "then") then
      add 3 to tSpaces
   end if
   put return & char 1 to tSpaces of "                                                            " into the selection
   acNumberLines
end acNewLine

-- Tab puts three spaces in the editor; Shift-Tab takes them away from the
-- start of the line
on tabKey
   local tLineNo
   if the short name of the target is not "ed" then
      pass tabKey
   end if
   if the shiftKey is down then
      put word 2 of the selectedLine into tLineNo
      if tLineNo is an integer and char 1 to 3 of line tLineNo of field "ed" is "   " then
         delete char 1 to 3 of line tLineNo of field "ed"
      end if
   else
      put "   " into the selection
   end if
   acNumberLines
end tabKey

-- Runs the editor's code
private command acRunEditor
   local tCode, tRun
   if acBusy() then
      exit acRunEditor
   end if
   put the text of field "ed" into tCode
   if word 1 to -1 of tCode is empty then
      acShowOutput "Nothing to run yet: type some xTalk first.", "warn", empty
      exit acRunEditor
   end if
   acKeepDraft
   acShowOutput "Running" & numToCodepoint(8230), "muted", empty
   put acRunCode(tCode, acStageLesson()) into tRun
   acShowRun tRun, empty
end acRunEditor

-- Whether code is running still (it waits, with messages, say): a second
-- run would delete the stage under it, so it says so and waits its turn
private function acBusy
   if sRunning is not true then
      return false
   end if
   acToast "Your code is still running: wait for it to finish, then run it again.", "warn"
   return true
end acBusy

-- Whether the lesson in front is about objects: its stage shows each run
private function acStageLesson
   if sLesson[sCourse] < 1 then
      return false
   end if
   return sCourses[sCourse]["lesson"][sLesson[sCourse]]["stage"] is "yes"
end acStageLesson

-- Checks the editor's code against the challenge's tests
private command acCheckEditor
   local tChallenge, tCode, tCheck, tKey, tHtml, tIndex, tColor, tMark
   if sMode is not "challenge" or acBusy() then
      exit acCheckEditor
   end if
   put sModeKey into tKey
   put acChallengeOfKey(tKey) into tChallenge
   put the text of field "ed" into tCode
   acKeepDraft
   acShowOutput "Checking" & numToCodepoint(8230), "muted", empty
   put acCheckCode(tCode, tChallenge["checks"], acStageLesson()) into tCheck
   add 1 to sTries[tKey]
   -- what each test found
   repeat with tIndex = 1 to tCheck["count"]
      if tCheck[tIndex]["ok"] then
         put "#34d399" into tColor
         put numToCodepoint(10003) into tMark
      else
         put "#fb7185" into tColor
         put numToCodepoint(10007) into tMark
      end if
      put "<p><font color=" & quote & tColor & quote & ">" & tMark & "  " & lkEscape(tCheck[tIndex]["text"]) & "</font>" after tHtml
      if not tCheck[tIndex]["ok"] and tCheck[tIndex]["why"] is not empty then
         put "<font color=" & quote & "#94a3b8" & quote & ">" & " (" & lkEscape(tCheck[tIndex]["why"]) & ")</font>" after tHtml
      end if
      put "</p>" after tHtml
   end repeat
   if tCheck["passed"] then
      put "<p></p><p><font color=" & quote & "#fbbf24" & quote & "><b>" & numToCodepoint(9733) && \
            "Challenge done. Well coded!</b></font></p>" after tHtml
   else if tCheck["run"]["ok"] then
      put "<p></p><p><font color=" & quote & "#94a3b8" & quote & ">Not yet: change your code and press Check again." & \
            "</font></p>" after tHtml
   end if
   acShowRun tCheck["run"], tHtml
   if tCheck["passed"] then
      acShowOutput "All" && tCheck["count"] && "checks passed", "win", tHtml
      put true into sQuiz[tKey & "/challenge"]
      acSaveProgress
      acCelebrate
      acLessonCheck
      if not acIsDone(sCourse, sLesson[sCourse]) then
         acToast "Challenge done! Answer the quick checks to finish the lesson.", "win"
      end if
   else if tCheck["run"]["ok"] then
      acShowOutput tCheck["good"] && "of" && tCheck["count"] && "checks passed", "warn", tHtml
   end if
   if acKey(sCourse, sLesson[sCourse]) is tKey then
      acRender true
   end if
end acCheckEditor

-- The starting code back in the editor, once the learner says so
private command acResetEditor
   local tChallenge, tCode
   switch sMode
      case "challenge"
         put acChallengeOfKey(sModeKey) into tChallenge
         put tChallenge["starter"] into tCode
         break
      case "example"
         put sCode[sExample]["code"] into tCode
         break
      default
         put "-- The playground: type xTalk here and press Run." & return & \
               "put" && quote & "Hello from the xTalk Academy!" & quote into tCode
   end switch
   if the text of field "ed" is tCode then
      exit acResetEditor
   end if
   answer "Put the starting code back? What is in the editor now is lost." with "Cancel" or "Put it back"
   if it is not "Put it back" then
      exit acResetEditor
   end if
   acSetEditor tCode
   acKeepDraft
   put empty into sOutput
   acShowOutput empty, empty, empty
end acResetEditor

-- An example of the lesson, in the playground, run
private command acTryExample pIndex
   local tRun
   if sCode[pIndex] is empty or acBusy() then
      exit acTryExample
   end if
   acKeepDraft
   put "example" into sMode
   put pIndex into sExample
   lock screen
   acSetEditor sCode[pIndex]["code"]
   put "An example from the lesson: change it, and run it again" into field "playWhat"
   hide group "check"
   acLayout
   unlock screen
   acShowOutput "Running" & numToCodepoint(8230), "muted", empty
   put acRunCode(sCode[pIndex]["code"], acStageLesson()) into tRun
   acShowRun tRun, empty
end acTryExample

-- A solution is shown once the learner has tried twice (or done it)
private command acRevealSolution
   local tKey
   put acKey(sCourse, sLesson[sCourse]) into tKey
   if sTries[tKey] < 2 and sQuiz[tKey & "/challenge"] is not true then
      acToast "Have a go first: after two tries with Check, the solution is yours to see.", "warn"
      exit acRevealSolution
   end if
   put true into sChallenge["solution"]
   acRender true
end acRevealSolution

private command acUseSolution
   local tChallenge
   put acChallengeOf(sCourse, sLesson[sCourse]) into tChallenge
   if tChallenge is empty then
      exit acUseSolution
   end if
   acSetupPlayground "challenge"
   acSetEditor tChallenge["solution"]
   acKeepDraft
   acToast "The solution is in the playground: run it, and see how it works.", "ok"
end acUseSolution

-- The output of a run: what it put, then an error in words (and its line,
-- marked in the editor), then pExtra (htmlText)
private command acShowRun pRun, pExtra
   local tHtml, tStatus, tKind
   if pRun["ok"] then
      if pRun["ms"] < 1 then
         put "Ran in under 1 ms" into tStatus
      else
         put "Ran in" && pRun["ms"] && "ms" into tStatus
      end if
      put "ok" into tKind
      if pRun["output"] is empty and pExtra is empty then
         put "<p><font color=" & quote & "#94a3b8" & quote & ">It ran, and put nothing. Use put to see a value here.</font></p>" into tHtml
      end if
   else
      put "Stopped" into tStatus
      put "bad" into tKind
      put "<p><font color=" & quote & "#fb7185" & quote & "><b>" & lkEscape(pRun["title"]) & "</b></font></p>" after tHtml
      put "<p><font color=" & quote & "#fda4af" & quote & ">" & lkEscape(pRun["error"]) & "</font></p>" after tHtml
      if pRun["line"] is an integer then
         acMarkLine pRun["line"]
      end if
   end if
   if pRun["made"] is true then
      put "<p><font color=" & quote & "#5eead4" & quote & ">Your code made things: they are on the Stage window.</font></p>" after tHtml
   end if
   if pExtra is not empty then
      if tHtml is not empty then
         put "<p></p>" after tHtml
      end if
      put pExtra after tHtml
   end if
   acShowOutput tStatus, tKind, tHtml
end acShowRun

-- The editor's line pLine, selected, so the learner sees where it stopped
private command acMarkLine pLine
   if pLine < 1 or pLine > the number of lines of field "ed" then
      exit acMarkLine
   end if
   select line pLine of field "ed"
   if (pLine - 1) * 20 < the vScroll of field "ed" or pLine * 20 > the vScroll of field "ed" + the height of field "ed" then
      set the vScroll of field "ed" to max(0, (pLine - 3) * 20)
   end if
   acNumberLines
end acMarkLine

-- The output field: every value the code put, a line each, then pExtra
-- (htmlText); and the status above it, in the colour of pKind
command acShowOutput pStatus, pKind, pExtra
   local tHtml, tLine, tColor, tSaved
   if the mode of me is 0 or there is no field "out" of me then
      exit acShowOutput
   end if
   put the defaultStack into tSaved
   set the defaultStack to the short name of me
   repeat for each line tLine in sOutput
      put "<p>" & lkEscape(tLine) & "</p>" after tHtml
   end repeat
   put pExtra after tHtml
   if tHtml is empty then
      put "<p><font color=" & quote & "#94a3b8" & quote & ">What your code puts shows here. Press Run, or Ctrl+Enter.</font></p>" into tHtml
   end if
   lock screen
   set the htmlText of field "out" to tHtml
   switch pKind
      case "ok"
         put "52,211,153" into tColor
         break
      case "bad"
         put "251,113,133" into tColor
         break
      case "win"
         put "251,191,36" into tColor
         break
      case "warn"
         put "251,191,36" into tColor
         break
      default
         put lkColor("muted") into tColor
   end switch
   put pStatus into field "outStatus"
   set the textColor of field "outStatus" to tColor
   set the vScroll of field "out" to max(0, the formattedHeight of field "out" - the height of field "out")
   unlock screen
   acRestore tSaved
end acShowOutput

-- What a run's code put after the run was over: a click on a button it
-- made, say (sent by the stage's msgChanged)
command revAcademyOutput pText
   if the number of lines of sOutput >= kMaxOutputLines then
      exit revAcademyOutput
   end if
   -- (a line each, ended by a return, so that a first value that is
   -- empty is a line too)
   put pText & return after sOutput
   if sRunning is not true then
      acShowOutput "From the stage", "ok", empty
   end if
end revAcademyOutput

################################################################################
#
# Running the learner's code
#

-- Runs pCode as the playground runs it, and returns what happened (see
-- acRunCode). pStage true shows the stage's window whatever the code did.
-- The check of the courses (tools/academy) runs every example with it.
function revAcademyRun pCode, pStage
   return acRunCode(pCode, pStage is true)
end revAcademyRun

-- Runs pCode and then the tests pChecks (see acCheckCode)
function revAcademyCheck pCode, pChecks, pStage
   return acCheckCode(pCode, pChecks, pStage is true)
end revAcademyCheck

-- Runs pCode in the stage, a stack made anew for each run, and returns
-- what happened: "ok" (whether it ran to its end), "ms" (how long it
-- took), "output" (what it put, a line each), "made" (whether it made
-- controls) and, when it stopped, "title", "error" (in words a learner
-- can use) and "line" (the editor's line, when it is known).
--
-- The code's handlers become the stage's script at the lines they have
-- in the editor, and its other lines the handler academyRun, below them,
-- which is sent to the stage: so an error's line is the editor's line
-- (sLineMap), and the code's handlers stay in the stage after the run,
-- for a click on a button it made, or for a challenge's tests.
private function acRunCode pCode, pStage
   local tScript, tProblem, tResult, tError, tSaved, tExplicit, tStart, tRun
   put the defaultStack into tSaved
   if acIsStage(tSaved) then
      put the short name of me into tSaved
   end if
   put empty into sOutput
   put pCode into sRunCode
   put acSandboxScript(pCode, tScript) into tProblem
   if tProblem is not empty then
      put false into tRun["ok"]
      put "That name is the Academy's own" into tRun["title"]
      put tProblem into tRun["error"]
      return tRun
   end if
   acMakeStage
   set the cAcademyCode of stack kStage to pCode
   -- (a learner's first programs use variables they never declared)
   put the explicitVariables into tExplicit
   set the explicitVariables to false
   lock messages
   set the script of stack kStage to tScript
   put the result into tResult
   unlock messages
   set the explicitVariables to tExplicit
   if tResult is not empty then
      return acCompileError(tResult)
   end if
   set the defaultStack to kStage
   put true into sRunning
   -- (while the run lasts, a wait in a loop does not restart its clock;
   -- after it, a pause between clicks on the stage does)
   set the cAcademyRunning of stack kStage to true
   put the milliseconds into tStart
   try
      send kRunHandler to stack kStage
      put true into tRun["ok"]
   catch tError
      put acRunError(tError) into tRun
   end try
   if there is a stack kStage then
      set the cAcademyRunning of stack kStage to false
   end if
   put the milliseconds - tStart into tRun["ms"]
   put false into sRunning
   acRestore tSaved
   -- (the code may have deleted the stack that was in front)
   if acIsStage(the defaultStack) and the mode of me is not 0 then
      set the defaultStack to the short name of me
   end if
   put char 1 to -2 of sOutput into tRun["output"]
   put acStageMade() into tRun["made"]
   if tRun["made"] or pStage then
      acShowStage
   end if
   return tRun
end acRunCode

-- Whether the stage has controls the code made
private function acStageMade
   if there is no stack kStage then
      return false
   end if
   return the number of controls of card 1 of stack kStage > 0
end acStageMade

-- The script of the stage, from the editor's text pCode (into rScript),
-- or a sentence on why it cannot be run.
--
-- A line that is part of a handler, or a declaration (local, global,
-- constant) outside one, keeps its line; every other line that is not
-- blank or a comment is moved into academyRun, below, and sLineMap says
-- where it came from. Each repeat gets a call to academyGuard (on the
-- same line, so no line moves), which stops a loop that has gone on for
-- too long. The Academy's own handlers (msgChanged, errorDialog and the
-- academy* ones) come between the two.
private function acSandboxScript pCode, @rScript
   local tLines, tCount, tIndex, tLine, tHandler, tWord, tName, tTop, tRun, tRunCount, tGoOn, tHead
   local tPlace, tGuard
   put false into tGuard
   put false into tGoOn
   put empty into sLineMap
   split pCode by return
   put the number of elements of pCode into tCount
   repeat with tIndex = 1 to tCount
      put pCode[tIndex] into tLine
      put word 1 of tLine into tWord
      -- (a repeat's guard goes after its header, on the header's last
      -- line when it goes on with "\")
      if tWord is "repeat" and not tGoOn then
         put true into tGuard
      end if
      if tGuard and not acGoesOn(tLine) then
         put acGuardLine(tLine) into tLine
         put false into tGuard
      end if
      if tHandler is not empty then
         -- in a handler, until its end
         put tLine into tLines[tIndex]
         if tWord is "end" and word 2 of tLine is tHandler then
            put empty into tHandler
         end if
      else if tGoOn and tPlace is "keep" then
         -- the rest of a declaration that went on with "\"
         put tLine into tLines[tIndex]
      else if tGoOn then
         -- the rest of a statement that went on with "\"
         add 1 to tRunCount
         put tLine into tRun[tRunCount]
         put tIndex into sLineMap[tRunCount]
      else
         put acHandlerName(tLine) into tName
         if tName is not empty then
            put tName into tHandler
            put tLine into tLines[tIndex]
            if tName begins with "academy" or tName is "msgChanged" or tName is "errorDialog" then
               return "The name" && tName && "is one the Academy uses itself, to run your code." && \
                     "Please call your handler something else."
            end if
         else if tWord is among the items of "local,global,constant" or acIsQuiet(tLine) then
            put tLine into tLines[tIndex]
            put "keep" into tPlace
         else
            add 1 to tRunCount
            put tLine into tRun[tRunCount]
            put tIndex into sLineMap[tRunCount]
            put "run" into tPlace
         end if
      end if
      put acGoesOn(pCode[tIndex]) into tGoOn
   end repeat
   -- the editor's lines, in place
   repeat with tIndex = 1 to tCount
      put tLines[tIndex] & return after rScript
   end repeat
   -- the Academy's handlers
   put acHelperScript() into tHead
   put tHead & return after rScript
   -- and the code's statements, in academyRun
   put tCount + the number of lines of tHead + 1 into tTop
   put "on" && kRunHandler & return & "academyBegin" & return after rScript
   repeat with tIndex = 1 to tRunCount
      put tRun[tIndex] & return after rScript
   end repeat
   put "end" && kRunHandler after rScript
   -- sLineMap: the stage's line of each statement, to the editor's
   local tMap
   repeat with tIndex = 1 to tRunCount
      put sLineMap[tIndex] into tMap[tTop + 1 + tIndex]
   end repeat
   put tCount into tMap["editor"]
   put tTop + 2 + tRunCount into tMap["end"]
   put tMap into sLineMap
   return empty
end acSandboxScript

-- The name of the handler that the line pLine begins, if it begins one
private function acHandlerName pLine
   local tWord
   put word 1 of pLine into tWord
   if tWord is "private" then
      put word 2 of pLine into tWord
      if tWord is among the items of "command,function" then
         return acBareName(word 3 of pLine)
      end if
      return empty
   end if
   if tWord is among the items of "on,command,function,getProp,setProp,before,after" then
      return acBareName(word 2 of pLine)
   end if
   return empty
end acHandlerName

-- A handler's name without the "(" a function's name may have stuck to
-- it, or the "[" of a custom property's key (getProp score[pPlayer])
private function acBareName pWord
   local tCut, tChar
   repeat for each item tChar in "(,["
      put offset(tChar, pWord) into tCut
      if tCut > 0 then
         delete char tCut to -1 of pWord
      end if
   end repeat
   return pWord
end acBareName

-- Whether pLine is blank or only a comment
private function acIsQuiet pLine
   put word 1 to -1 of pLine into pLine
   return pLine is empty or pLine begins with "--" or pLine begins with "#" or pLine begins with "//"
end acIsQuiet

-- Whether pLine's statement goes on to the next line (ends with "\")
private function acGoesOn pLine
   local tCut
   put acCommentAt(pLine) into tCut
   if tCut > 0 then
      delete char tCut to -1 of pLine
   end if
   put word 1 to -1 of pLine into pLine
   return the last char of pLine is "\"
end acGoesOn

-- Where pLine's comment begins (0 with none), outside its quotes
private function acCommentAt pLine
   local tIndex, tQuoted, tChar
   put false into tQuoted
   repeat with tIndex = 1 to the number of chars of pLine
      put char tIndex of pLine into tChar
      if tChar is quote then
         put not tQuoted into tQuoted
      else if not tQuoted then
         if tChar is "#" or (tChar is "-" and char tIndex + 1 of pLine is "-") or \
               (tChar is "/" and char tIndex + 1 of pLine is "/") then
            return tIndex
         end if
      end if
   end repeat
   return 0
end acCommentAt

-- The repeat line pLine with the loop guard after its header: before
-- the ";" of a one-line loop, or the comment, or at the end
private function acGuardLine pLine
   local tIndex, tQuoted, tChar, tAt
   put false into tQuoted
   put 0 into tAt
   repeat with tIndex = 1 to the number of chars of pLine
      put char tIndex of pLine into tChar
      if tChar is quote then
         put not tQuoted into tQuoted
      else if not tQuoted and tChar is ";" then
         put tIndex into tAt
         exit repeat
      end if
   end repeat
   if tAt is 0 then
      put acCommentAt(pLine) into tAt
   end if
   if tAt is 0 then
      return pLine & "; academyGuard"
   end if
   return char 1 to tAt - 1 of pLine & "; academyGuard " & char tAt to -1 of pLine
end acGuardLine

-- The stage's own handlers: what the code puts goes to the Academy's
-- output (not to the Message Box), a loop is stopped after a while, an
-- error after the run (in a handler a click ran, say) is shown in the
-- output, and a few helpers for the challenges' tests
private function acHelperScript
   local tScript
   put "local sAcademyStart, sAcademyLast, sAcademyOut, sAcademyCount" & return & \
         "command academyBegin" & return & \
         "   put the milliseconds into sAcademyStart" & return & \
         "   put sAcademyStart into sAcademyLast" & return & \
         "end academyBegin" & return & \
         "command academyGuard" & return & \
         "   local tNow" & return & \
         "   put the milliseconds into tNow" & return & \
         "   if tNow - sAcademyLast > 1000 and the cAcademyRunning of me is not true then put tNow into sAcademyStart" & return & \
         "   put tNow into sAcademyLast" & return & \
         "   if tNow - sAcademyStart > " & kLoopSeconds * 1000 & " then throw " & quote & "academy-loop" & quote & return & \
         "end academyGuard" & return & \
         "on msgChanged" & return & \
         "   if sAcademyCount >= " & kMaxOutputLines & " then exit msgChanged" & return & \
         "   if sAcademyCount > 0 then put return after sAcademyOut" & return & \
         "   put msg after sAcademyOut" & return & \
         "   add 1 to sAcademyCount" & return & \
         "   local tAcademyHost" & return & \
         "   put academyHost() into tAcademyHost" & return & \
         "   dispatch " & quote & "revAcademyOutput" & quote & " to tAcademyHost with msg" & return & \
         "end msgChanged" & return & \
         "on errorDialog pError" & return & \
         "   local tAcademyHost" & return & \
         "   put academyHost() into tAcademyHost" & return & \
         "   dispatch " & quote & "revAcademyError" & quote & " to tAcademyHost with pError" & return & \
         "end errorDialog" & return & \
         "function academyHost" & return & \
         "   if the cAcademyHost of me is not empty then" & return & \
         "      if exists(the cAcademyHost of me) then return the cAcademyHost of me" & return & \
         "   end if" & return & \
         "   return the long id of stack " & quote & "revAcademy" & quote & return & \
         "end academyHost" & return & \
         "function academyOutput" & return & \
         "   return sAcademyOut" & return & \
         "end academyOutput" & return & \
         "function academyCode" & return & \
         "   return the cAcademyCode of me" & return & \
         "end academyCode" & return & \
         "function academyClick pName" & return & \
         "   send " & quote & "mouseUp 1" & quote & " to button pName of card 1 of me" & return & \
         "   return true" & return & \
         "end academyClick" & return & \
         "function academyType pField, pText" & return & \
         "   put pText into field pField of card 1 of me" & return & \
         "   return true" & return & \
         "end academyType" into tScript
   return tScript
end acHelperScript

-- The run's answer for a script that did not compile: pResult is the
-- result of setting it ("code,line,column,hint")
private function acCompileError pResult
   local tRun, tCode, tText
   put item 1 of line 1 of pResult into tCode
   put false into tRun["ok"]
   put 0 into tRun["ms"]
   put empty into tRun["output"]
   put false into tRun["made"]
   put acEditorLine(item 2 of line 1 of pResult) into tRun["line"]
   if tCode is an integer then
      put line tCode of the scriptParsingErrors into tText
      if tText is empty then
         put acEngineWords(tCode, "parse") into tText
      end if
   end if
   if tRun["line"] is an integer then
      put "Line" && tRun["line"] & ": xTalk could not read this" into tRun["title"]
   else
      put "xTalk could not read your code" into tRun["title"]
   end if
   put acExplain(tText, item 4 of line 1 of pResult, "parse") into tRun["error"]
   return tRun
end acCompileError

-- The run's answer for an error thrown while it ran: pError is the
-- engine's trace (a "code,line,column,hint" line a step, innermost
-- first), or what the code threw itself
private function acRunError pError
   local tRun, tLine, tCode, tText, tHint, tAt
   put false into tRun["ok"]
   if line 1 of pError is "academy-loop" then
      put "Stopped after" && kLoopSeconds && "seconds" into tRun["title"]
      put "A repeat loop was still going after" && kLoopSeconds && "seconds, so the Academy stopped it." && \
            "Check that the loop's condition can become false, and that each time round brings it nearer its end." into tRun["error"]
      return tRun
   end if
   if item 1 of line 1 of pError is not an integer then
      put "Your code threw an error" into tRun["title"]
      put line 1 of pError into tRun["error"]
      return tRun
   end if
   -- the engine's words for the first step that says what went wrong,
   -- and the first line of the stage's script that it names
   repeat for each line tLine in pError
      put item 1 of tLine into tCode
      if tCode is not an integer or tCode is 353 then
         next repeat
      end if
      if tText is empty then
         put line tCode of the scriptExecutionErrors into tText
         if tText is empty then
            put acEngineWords(tCode, "run") into tText
         end if
         put item 4 to -1 of tLine into tHint
      end if
      if tAt is empty and item 2 of tLine is an integer and item 2 of tLine > 0 then
         put item 2 of tLine into tAt
      end if
   end repeat
   put acEditorLine(tAt) into tRun["line"]
   if tRun["line"] is an integer then
      put "Line" && tRun["line"] & ": your code stopped here" into tRun["title"]
   else
      put "Your code stopped" into tRun["title"]
   end if
   put acExplain(tText, tHint, "run") into tRun["error"]
   return tRun
end acRunError

-- The engine's words for the errors a learner meets most, by their
-- number, for an engine that has no table of them (the scriptParsingErrors
-- and the scriptExecutionErrors are empty in a standalone engine, as the
-- web IDE's may be); only the words acExplain looks for
private function acEngineWords pCode, pKind
   if pKind is "parse" then
      switch pCode
         case 114
            return "Expression: missing factor"
         case 118
            return "Expression: unquoted literal"
         case 167
            return "Handler: end doesn't match handler name"
         case 169
            return "Handler: bad handler name (may be reserved word)"
         case 189
            return "if: missing 'then'"
         case 190
            return "if: missing 'end if'"
         case 219
            return "local: not a valid variable or constant name"
         case 339
            return "repeat: missing 'end repeat'"
      end switch
      return empty
   end if
   switch pCode
      case 573
         return "Handler: can't find handler"
      case 153
         return "numeric: divide by zero"
      case 77
      case 89
      case 95
         return "Chunk: no such object"
      case 9
      case 148
      case 333
      case 578
         return "destination has a bad format (numeric?)"
      case 155
      case 156
      case 198
      case 199
      case 312
      case 313
      case 318
      case 319
      case 375
      case 376
      case 394
      case 395
         return "Operators: error in operand"
   end switch
   return empty
end acEngineWords

-- The editor's line for the stage's script line pLine (empty when the
-- line is the Academy's own)
private function acEditorLine pLine
   if pLine is not an integer or pLine < 1 then
      return empty
   end if
   if pLine <= sLineMap["editor"] then
      return pLine
   end if
   if sLineMap[pLine] is an integer then
      return sLineMap[pLine]
   end if
   -- (an "if" or "repeat" left open is found at the end of academyRun)
   if pLine is sLineMap["end"] and sLineMap["editor"] > 0 then
      return sLineMap["editor"]
   end if
   return empty
end acEditorLine

-- An error in words a learner can use: the engine's own (pText, as
-- "Area: what"), what it was about (pHint), and a sentence on the
-- mistakes that most often cause it. pKind is "parse" or "run".
private function acExplain pText, pHint, pKind
   local tWhat, tColon, tWhy
   put pText into tWhat
   put offset(":", tWhat) into tColon
   if tColon > 0 then
      put word 1 to -1 of acSpan(tWhat, tColon + 1, -1) into tWhat
   end if
   put word 1 to -1 of pHint into pHint
   if pText contains "can't find handler" then
      if pHint is not empty then
         return "xTalk does not know a command or function called" && quote & pHint & quote & "." && \
               "Check its spelling; if it is one of your own, check that its handler is in the editor."
      end if
      return "xTalk does not know a command or function on this line. Check the spelling."
   end if
   if pText contains "divide by zero" then
      return "This divides by zero, which has no answer, so xTalk stops. Check the number you divide by."
   end if
   if pText contains "operand" or pText contains "is not a number" or pText contains "(numeric?)" then
      if pHint is not empty then
         put "This needs a number, but got" && quote & pHint & quote & "." into tWhy
      else
         put "This needs a number, and one of its values is not one." into tWhy
      end if
      return tWhy && "Text in a sum is a mistake: check the variables have the values you think (put them, to see)."
   end if
   if pText contains "can't find object" or pText contains "no such object" or pText contains "can't find card" then
      return "There is no object by that name on the stage. Check its name, and that your code made it before using it."
   end if
   if pText contains "missing 'end if'" then
      return "An if that runs more than one line needs an end if after its last line."
   end if
   if pText contains "missing 'end repeat'" or (pText contains "repeat" and pText contains "end") then
      return "A repeat needs an end repeat after the lines it repeats."
   end if
   if pText contains "missing 'then'" then
      return "An if needs then after its condition, as in: if tScore > 10 then"
   end if
   if pText contains "end doesn't match" then
      return "This end names another handler than the one it closes: it should say end and the handler's name."
   end if
   if pText contains "unquoted literal" then
      if pHint is not empty then
         return quote & pHint & quote && "is not a word xTalk knows here. If it is text, put it in quotes."
      end if
      return "A word here is not one xTalk knows. If it is text, put it in quotes."
   end if
   if pText contains "missing factor" or pText contains "missing left operand" then
      return "Something is missing in an expression here: a value after an operator, or a closing bracket."
   end if
   if pText contains "bad handler name" then
      return "That handler's name is one of xTalk's own words (a function like average or length, say)," && \
            "so it cannot be used for a handler. Choose another, like averageOf or myLength."
   end if
   if pText contains "not a valid variable" then
      return "That cannot be a variable's name. A name starts with a letter, has no spaces, and is not a word xTalk uses itself."
   end if
   if tWhat is not empty then
      if pHint is not empty and pKind is "run" then
         return "xTalk says:" && tWhat && "(" & pHint & ")."
      end if
      return "xTalk says:" && tWhat & "."
   end if
   return "Check this line's spelling and its quotes."
end acExplain

-- An error in a handler of the stage after its run (a click on a button
-- the code made, say), sent by the stage's errorDialog
command revAcademyError pError
   local tRun, tSaved
   put acRunError(pError) into tRun
   if the mode of me is 0 then
      exit revAcademyError
   end if
   -- (a click on the stage made the stage the defaultStack)
   put the defaultStack into tSaved
   if acIsStage(tSaved) then
      put the short name of me into tSaved
   end if
   set the defaultStack to the short name of me
   lock screen
   acShowRun tRun, empty
   unlock screen
   acRestore tSaved
end revAcademyError

################################################################################
#
# Checking a challenge
#

-- Runs pCode, then each test of pChecks ("expression | what it looks
-- for", a line each) and returns what each found: ["count"], and for each
-- n, [n]["ok"], [n]["text"] (what it looks for) and [n]["why"] (when it
-- failed: what the expression was, or its error); ["good"] (how many
-- passed), ["passed"] (all of them, and the code ran) and ["run"] (the
-- run, as acRunCode returns it).
--
-- An expression is evaluated in the stage, so it can call the code's own
-- functions; in it, the word output stands for what the code put (a line
-- each) and the word code for the code itself, outside quotes.
private function acCheckCode pCode, pChecks, pStage
   local tCheck, tLine, tExpr, tText, tIndex, tValue, tError, tSaved, tFailed
   put acRunCode(pCode, pStage) into tCheck["run"]
   put 0 into tCheck["good"]
   put 0 into tIndex
   repeat for each line tLine in pChecks
      if word 1 to -1 of tLine is empty then
         next repeat
      end if
      add 1 to tIndex
      set the itemDelimiter to "|"
      put word 1 to -1 of item 1 of tLine into tExpr
      put word 1 to -1 of item 2 to -1 of tLine into tText
      set the itemDelimiter to comma
      if tText is empty then
         put tExpr into tText
      end if
      put tText into tCheck[tIndex]["text"]
      put false into tCheck[tIndex]["ok"]
      if not tCheck["run"]["ok"] then
         put "the code stopped before its end" into tCheck[tIndex]["why"]
         next repeat
      end if
      if there is no stack kStage then
         put "the stage was closed" into tCheck[tIndex]["why"]
         next repeat
      end if
      put the defaultStack into tSaved
      set the defaultStack to kStage
      put true into sRunning
      try
         put value(acCheckExpression(tExpr), card 1 of stack kStage) into tValue
         if tValue is true then
            put true into tCheck[tIndex]["ok"]
            add 1 to tCheck["good"]
         else
            put empty into tCheck[tIndex]["why"]
         end if
      catch tError
         put acRunError(tError) into tFailed
         put "it could not be checked:" && tFailed["error"] into tCheck[tIndex]["why"]
      end try
      put false into sRunning
      acRestore tSaved
   end repeat
   put tIndex into tCheck["count"]
   put tCheck["run"]["ok"] and tIndex > 0 and tCheck["good"] is tIndex into tCheck["passed"]
   -- (what a test put, or a click it made, is not the code's output)
   put tCheck["run"]["output"] into sOutput
   if sOutput is not empty then
      put return after sOutput
   end if
   return tCheck
end acCheckCode

-- A test's expression, with the words output and code (outside quotes)
-- as the stage's functions that return them
private function acCheckExpression pExpr
   local tOut, tIndex, tQuoted, tChar, tWord
   put false into tQuoted
   repeat with tIndex = 1 to the number of chars of pExpr
      put char tIndex of pExpr into tChar
      if tChar is quote then
         put not tQuoted into tQuoted
      end if
      if not tQuoted and acIsWordChar(tChar) then
         put tChar after tWord
         next repeat
      end if
      put acCheckWord(tWord) & tChar after tOut
      put empty into tWord
   end repeat
   put acCheckWord(tWord) after tOut
   return tOut
end acCheckExpression

private function acCheckWord pWord
   switch pWord
      case "output"
         return "academyOutput()"
      case "code"
         return "academyCode()"
   end switch
   return pWord
end acCheckWord

private function acIsWordChar pChar
   -- (xTalk compares without case, so capitals are in the list too)
   return pChar is not empty and pChar is in "abcdefghijklmnopqrstuvwxyz0123456789_"
end acIsWordChar

################################################################################
#
# The stage
#

-- A new stage for a run: the old one is gone, with whatever it had
private command acMakeStage
   local tSaved
   put the defaultStack into tSaved
   if acIsStage(tSaved) then
      put the short name of me into tSaved
   end if
   acDropStage
   -- (a new stack becomes the defaultStack: it is put back below)
   create invisible stack kStage
   set the _ideoverride of stack kStage to true
   set the destroyStack of stack kStage to true
   set the title of stack kStage to "Stage: what your code made"
   -- (where its output goes: the Academy's window, or Home's that hosts it)
   set the cAcademyHost of stack kStage to the long id of me
   set the width of stack kStage to 480
   set the height of stack kStage to 360
   set the backgroundColor of stack kStage to "#F8FAFC"
   set the defaultStack to tSaved
end acMakeStage

-- Whether pName (the defaultStack, which may be a name or 'stack "name"')
-- is the stage
private function acIsStage pName
   return pName is kStage or pName is ("stack" && quote & kStage & quote)
end acIsStage

-- The stage, gone from memory. (The engine must not be left with a
-- deleted stack as its defaultStack: it crashes on the next use of it.)
private command acDropStage
   if there is no stack kStage then
      exit acDropStage
   end if
   if the visible of stack kStage then
      put the rect of stack kStage into sStageRect
   end if
   if acIsStage(the defaultStack) then
      set the defaultStack to the short name of me
   end if
   delete stack kStage
end acDropStage

-- The stage's window, beside the lesson (or where the learner put it):
-- modeless, so a click on what the code made runs it, whatever tool the
-- IDE has in hand
private command acShowStage
   -- (the stage's window goes with the Academy's: a check of the courses
   -- runs them with the Academy closed, and shows nothing)
   if the mode of me is 0 then
      exit acShowStage
   end if
   if there is no stack kStage then
      acToast "There is no stage yet: run some code that makes a button or a field.", "warn"
      exit acShowStage
   end if
   -- (a stack made with create is open, but invisible, until it is shown)
   if not the visible of stack kStage then
      if sStageRect is not empty then
         set the rect of stack kStage to sStageRect
      else
         set the topLeft of stack kStage to the left of me + kSide + 40, the top of me + kHeaderHeight + 40
      end if
   end if
   modeless stack kStage
   show stack kStage
   -- (the stage comes to the front, and the Academy's handlers go on)
   set the defaultStack to the short name of me
end acShowStage

-- The stage, closed (pGone: and forgotten, as the Academy closes)
private command acCloseStage pGone
   if there is no stack kStage then
      exit acCloseStage
   end if
   if the visible of stack kStage then
      put the rect of stack kStage into sStageRect
   end if
   if pGone then
      acDropStage
   else
      close stack kStage
   end if
end acCloseStage
