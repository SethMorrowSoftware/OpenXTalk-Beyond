script "oxtwebidetour"
-- Screenshots of the web IDE (tools/web-ide), run inside the IDE in a
-- web page by tools/ci/web_ide_tour.py: the script puts this file into a
-- copy of the site's ide.zip as a script library extension
-- (/boot/Extensions/oxtwebidetour), so that the IDE loads it as it starts,
-- as it loads every extension. The page has no command line and no
-- files the script can reach, so the two talk through the page:
-- web_ide_tour.py gives the page window.oxtTour before the IDE starts,
-- this script hands it lines with "do ... as JavaScript", and the page
-- takes the screenshots, the clicks and the keys this script asks for.
-- Without window.oxtTour (the library in a page of its own) it does
-- nothing.
--
-- It waits for the IDE to finish starting and for web_ide_tour.py to say
-- go, then opens the IDE's windows one by one, as a user does on the web:
-- a stack of the user with the usual controls, the Property Inspector,
-- the Script Editor, the Message Box, the Project Browser, a click in
-- browse mode that opens an answer dialog, the Dictionary, Preferences,
-- the File menu, and the page made narrow. For each it asks for a
-- screenshot of the page. A step still running after 30 seconds (a
-- dialog it waits on) has its modal dialogs closed. Script errors in the
-- IDE's windows are recorded instead of shown.
--
-- Lines (window.oxtTour.record):
--    STARTED
--    INFO <key> <value>
--    ERROR <a script error, its lines joined with " | ">
--    ACT <id> shot <file>          a screenshot of the page
--    ACT <id> click <x> <y>        a click at a point of the page
--    ACT <id> key <key>            a key (Playwright's name, "Escape")
--    ACT <id> size <width> <height>  the page's size
--    ACT <id> dialog               a click on the default button of the
--                                  page's dialog (answer, ask, ...)
--    STEP <name> ok | STEP <name> FAILED <error>
--    DONE
-- Ids count up from 1. The page answers each ACT by setting
-- window.oxtTour.done to its id.

/**
Title: Web IDE tour (CI)
Author: OXT-Beyond contributors
Description:
Screenshots of the web IDE for its CI job (tools/ci/web_ide_tour.py).
Only CI's copy of the site has it.
*/

constant kSteps = "start,sample,inspector,script-editor,message-box,project-browser,browse,dictionary,preferences,file-menu,narrow"
constant kSample = "Web Tour Sample"

local sStarted, sAct, sWatchdog, sFlag

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if
   if sStarted is not true and tourJS("typeof window.oxtTour") is "object" then
      put true into sStarted
      send "tourWhenStarted 0" to me in 1 second
   end if
end extensionInitialize

-- Waits until the IDE has finished starting (home.livecodescript sets the
-- cREVLaunching of stack "Home" while it opens its palettes) and the page
-- says go, then a little more for their deferred messages
on tourWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then
      put the cREVLaunching of stack "Home" into tLaunching
   end if
   if (tLaunching is true or tourJS("window.oxtTour.go") is not "true") and pTries < 600 then
      send "tourWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "tourRun" to me in 2 seconds
   end if
end tourWhenStarted

on tourRun
   local tStep, tHandler, tError, tOnly
   put 0 into sAct
   -- the steps to run (web_ide_tour.py --only), empty for all
   put tourJS("window.oxtTour.only") into tOnly
   tourRecord "STARTED"
   tourRecord "INFO version" && the version && the buildNumber
   tourRecord "INFO platform" && the platform && the environment
   tourRecord "INFO screenRect" && the screenRect
   tourRecord "INFO openStacks" && tourJoin(the openStacks)
   tourCatchErrors
   repeat for each item tStep in kSteps
      if tOnly is not empty and tStep is not among the items of tOnly then
         next repeat
      end if
      put "tour_" & tStep into tHandler
      replace "-" with "_" in tHandler
      send "tourWatchdog" && quote & tStep & quote to me in 30 seconds
      put the result into sWatchdog
      try
         dispatch tHandler to me
         tourRecord "STEP" && tStep && "ok"
      catch tError
         tourRecord "STEP" && tStep && "FAILED" && tourJoin(tError)
      end try
      cancel sWatchdog
      -- whatever a step left in the way
      tourCloseDialogs
   end repeat
   tourRecord "INFO openStacks at the end" && tourJoin(the openStacks)
   tourRecord "DONE"
end tourRun

-- Errors in the IDE's scripts are recorded, not shown in the IDE's error
-- dialog or the debugger (revTestEnvironment, as the IDE's test runner
-- sets it)
command tourCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      put the defaultStack into tDefault
      set the defaultStack to "oxtwebidetour"
      lock messages
      create invisible button "oxt_web_tour_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "tourScriptError" & quote & " to stack " & quote & "oxtwebidetour" & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      tourRecord "INFO catching errors:" && tourJoin(tError)
   end try
end tourCatchErrors

on tourScriptError pError
   tourRecord "ERROR" && tourJoin(pError)
end tourScriptError

----------------------------------------------------------------
-- Steps

-- The IDE as it opens: the menu bar and toolbar across the page, and the
-- Tools palette
on tour_start
   tourShot "01-ide"
end tour_start

on tour_sample
   go tourSampleStack()
   tourWait 1000
   tourShot "02-sample-stack"
end tour_sample

on tour_inspector
   local tButton, tPI
   put tourSample("Push") into tButton
   go stack kSample
   revIDESelectObjects tButton
   revIDEInspectObjects tButton
   tourWait 2000
   put tourStackNamed("revPropertyInspector") into tPI
   if tPI is empty then
      throw "no inspector opened:" && tourJoin(the openStacks)
   end if
   tourShot "03-inspector"
   tourCloseInspectors
end tour_inspector

on tour_script_editor
   local tSE
   revIDEEditScriptOfObject tourSample("Push")
   tourWait 2500
   put tourStackNamed("revNewScriptEditor") into tSE
   if tSE is empty then
      throw "no script editor opened:" && tourJoin(the openStacks)
   end if
   tourShot "04-script-editor"
   close stack tSE
end tour_script_editor

on tour_message_box
   local tStack
   put revIDEPaletteToStackName("message box") into tStack
   revIDEOpenPalette "message box"
   tourWait 1000
   if tStack is empty or there is not a stack tStack or not the visible of stack tStack then
      throw "the Message Box did not open"
   end if
   tourShot "05-message-box"
   close stack tStack
end tour_message_box

-- With the sample's button shown in it, as Show In Project Browser does
on tour_project_browser
   local tStack, tButton
   put tourSample("Push") into tButton
   put revIDEPaletteToStackName("project browser") into tStack
   revIDEOpenPalette "project browser"
   tourWait 1000
   revIDEShowInProjectBrowser tButton
   tourWait 1500
   if tStack is empty or there is not a stack tStack or not the visible of stack tStack then
      throw "the Project Browser did not open"
   end if
   tourShot "06-project-browser"
   close stack tStack
end tour_project_browser

-- A click on the sample's button in browse mode runs its script, which
-- opens an answer dialog: the click comes from the page, as a user's does
on tour_browse
   local tLoc
   go stack kSample
   choose browse tool
   tourWait 500
   put the globalLoc of the loc of button "Push" of card 1 of stack kSample into tLoc
   tourRecord "INFO the button's loc on the page" && tLoc
   put empty into sFlag
   send "tourShotAnswer" && quote & "07-browse-answer" & quote to me in 2 seconds
   tourAct "click" && item 1 of tLoc && item 2 of tLoc
   -- (the engine waits on the dialog: the click returns once it has
   -- closed)
   tourWaitFlag "07-browse-answer", 10000
   choose pointer tool
   if sFlag is not "07-browse-answer shown" then
      throw "no answer dialog opened (" & sFlag & ")"
   end if
end tour_browse

-- The web engine's answer dialog is the page's (em-dialog.js): an element
-- over the page, which the engine waits on with its timers running
on tourShotAnswer pFile
   if tourPageDialog() then
      tourShot pFile
      put pFile && "shown" into sFlag
   else
      tourRecord "INFO" && pFile && "no answer dialog; open stacks:" && tourJoin(the openStacks)
      put pFile && "none" into sFlag
   end if
   tourCloseDialogs
end tourShotAnswer

-- True while the page shows one of the engine's dialogs
function tourPageDialog
   return tourJS("document.querySelector('.oxt-dialog-default') !== null") is "true"
end tourPageDialog

-- As Help > Dictionary does
on tour_dictionary
   local tBefore, tNew
   put the openStacks into tBefore
   send "tNewDictionaryDisplay" to stack "revMenuBar"
   repeat 40 times
      put tourNewStack(tBefore) into tNew
      if tNew is not empty then
         exit repeat
      end if
      tourWait 500
   end repeat
   if tNew is empty then
      throw "no dictionary window opened"
   end if
   -- its page loads in the browser widget
   tourWait 5000
   tourShot "08-dictionary"
   close stack tNew
end tour_dictionary

on tour_preferences
   local tStack
   put revIDEPaletteToStackName("preferences") into tStack
   revIDEOpenPalette "preferences"
   tourWait 1500
   if tStack is empty or there is not a stack tStack or not the visible of stack tStack then
      throw "Preferences did not open"
   end if
   tourShot "09-preferences"
   close stack tStack
end tour_preferences

-- The File menu, opened by a click on its name in the menu bar
on tour_file_menu
   local tMenu
   put tourMenuButton("File") into tMenu
   if tMenu is empty then
      throw "no File menu in revMenuBar"
   end if
   tourAct "click" && item 1 of the globalLoc of the loc of tMenu && item 2 of the globalLoc of the loc of tMenu
   tourWait 1500
   tourShot "10-file-menu"
   tourAct "key Escape"
   tourWait 800
end tour_file_menu

-- The page made narrow, as a phone or a small window has it: the IDE
-- follows the page's size (ideDesktopChanged)
on tour_narrow
   go stack kSample
   tourAct "size 900 700"
   tourWait 3000
   tourRecord "INFO screenRect when narrow" && the screenRect
   tourShot "11-narrow-page"
   tourAct "size 1400 900"
   tourWait 2000
end tour_narrow

----------------------------------------------------------------
-- Helpers

-- The user's stack the inspector and the editors look at
function tourSampleStack
   local tDefault
   if there is a stack kSample then
      return the long id of stack kSample
   end if
   put the defaultStack into tDefault
   lock screen
   lock messages
   create stack kSample
   set the rect of it to "300,180,760,520"
   set the defaultStack to kSample
   create button "Push"
   set the rect of it to "20,20,140,46"
   set the script of it to "on mouseUp pButton" & return & \
         "   -- a comment" & return & \
         "   put " & quote & "Hello from the web IDE" & quote & " into tText" & return & \
         "   if pButton is 1 then answer tText" & return & \
         "end mouseUp"
   create button "Check"
   set the style of it to "checkbox"
   set the rect of it to "160,22,280,44"
   set the hilite of it to true
   create button "Option"
   set the style of it to "menu"
   set the menuMode of it to "option"
   set the text of it to "Choice one" & return & "Choice two"
   set the label of it to "Choice one"
   set the rect of it to "300,20,440,46"
   create field "Text"
   set the rect of it to "20,64,220,144"
   set the text of it to "Text in a field." & return & "A second line."
   create field "List"
   set the listBehavior of it to true
   set the vScrollbar of it to true
   set the rect of it to "240,64,440,144"
   set the text of it to "One" & return & "Two" & return & "Three" & return & "Four" & return & "Five" & return & "Six"
   set the hilitedLine of it to 2
   create scrollbar "Progress"
   set the style of it to "progress"
   set the rect of it to "20,162,220,182"
   set the endValue of it to 100
   set the thumbPosition of it to 60
   create graphic "Box"
   set the style of it to "roundRect"
   set the rect of it to "240,160,440,300"
   set the opaque of it to true
   set the backColor of it to "255,200,120"
   create button "Tabs"
   set the style of it to "menu"
   set the menuMode of it to "tabbed"
   set the text of it to "First" & return & "Second"
   set the rect of it to "20,196,220,300"
   unlock messages
   unlock screen
   set the defaultStack to tDefault
   return the long id of stack kSample
end tourSampleStack

-- The long id of the control pName of the sample stack
function tourSample pName
   get tourSampleStack()
   return the long id of control pName of card 1 of stack kSample
end tourSample

command tourCloseInspectors
   local tStack
   repeat for each line tStack in the openStacks
      if tStack begins with "revPropertyInspector" then
         close stack tStack
      end if
   end repeat
   revIDEDeselectAll
   tourWait 300
end tourCloseInspectors

-- The first visible open stack whose name starts with pPrefix
function tourStackNamed pPrefix
   local tStack
   repeat for each line tStack in the openStacks
      if tStack begins with pPrefix and the visible of stack tStack then
         return tStack
      end if
   end repeat
   return empty
end tourStackNamed

-- A visible stack in the openStacks that was not in pBefore
function tourNewStack pBefore
   local tStack
   repeat for each line tStack in the openStacks
      if tStack is not among the lines of pBefore and the visible of stack tStack then
         return tStack
      end if
   end repeat
   return empty
end tourNewStack

-- The button of the menu pName in the IDE's menu bar
function tourMenuButton pName
   local tGroup
   if there is not a stack "revMenuBar" then
      return empty
   end if
   put the long id of group "revMenuBar" of card 1 of stack "revMenuBar" into tGroup
   if there is a button pName of tGroup then
      return the long id of button pName of tGroup
   end if
   return empty
end tourMenuButton

command tourWait pMilliseconds
   wait pMilliseconds milliseconds with messages
end tourWait

-- Waits until sFlag begins with pFlag, at most pMilliseconds
command tourWaitFlag pFlag, pMilliseconds
   local tDeadline
   put the milliseconds + pMilliseconds into tDeadline
   repeat until sFlag begins with pFlag or the milliseconds > tDeadline
      wait 100 milliseconds with messages
   end repeat
end tourWaitFlag

command tourShot pFile
   tourUnlockScreen pFile
   tourAct "shot" && pFile
end tourShot

-- The screen as ui-tour.livecodescript unlocks it: a window that opens
-- with the screen locked (the Script Editor) leaves it locked until no
-- handler runs, which for a user is the next moment the IDE is idle, but
-- here not until the tour ends: unlocked, so that the windows show what
-- they hold
command tourUnlockScreen pWhat
   if the lockScreen then
      tourRecord "INFO" && pWhat & ": the screen was locked"
      repeat while the lockScreen
         unlock screen
      end repeat
      tourWait 300
   end if
end tourUnlockScreen

-- Asks the page for an action and waits until it is done (at most 20
-- seconds; the page records one that it could not do)
command tourAct pAction
   local tId, tDeadline
   add 1 to sAct
   put sAct into tId
   tourRecord "ACT" && tId && pAction
   put the milliseconds + 20000 into tDeadline
   -- (an action asked for while this one waits, by a handler that runs in
   -- a dialog's modal loop, is done after it)
   repeat until tourJS("window.oxtTour.done") >= tId or the milliseconds > tDeadline
      wait 100 milliseconds with messages
   end repeat
end tourAct

on tourWatchdog pStep
   tourRecord "INFO" && pStep && "still running after 30 s; open stacks:" && tourJoin(the openStacks)
   tourCloseDialogs true
end tourWatchdog

-- Closes the page's dialog (with its default button, as Return does),
-- the IDE's answer and ask dialogs, and with pAnyModal every modal or
-- sheet stack
command tourCloseDialogs pAnyModal
   local tName
   if tourPageDialog() then
      tourRecord "INFO closing the page's dialog"
      tourAct "dialog"
   end if
   repeat for each item tName in "Answer Dialog,Ask Dialog"
      if there is a stack tName and the mode of stack tName is not 0 then
         tourRecord "INFO closing" && tName
         close stack tName
      end if
   end repeat
   if pAnyModal is true then
      repeat for each line tName in the openStacks
         if there is a stack tName and the mode of stack tName is among the items of "5,6" then
            tourRecord "INFO closing the modal stack" && tName
            close stack tName
         end if
      end repeat
   end if
end tourCloseDialogs

command tourRecord pLine
   get tourJS("window.oxtTour.record(" & tourString(pLine) & ")")
end tourRecord

-- The value of the JavaScript expression pExpression in the page
function tourJS pExpression
   do pExpression as "JavaScript"
   return the result
end tourJS

-- pText as a JavaScript string
function tourString pText
   replace "\" with "\\" in pText
   replace "'" with "\'" in pText
   replace return with "\n" in pText
   replace numToChar(13) with "\r" in pText
   return "'" & pText & "'"
end tourString

function tourJoin pText
   replace return with " | " in pText
   return pText
end tourJoin
