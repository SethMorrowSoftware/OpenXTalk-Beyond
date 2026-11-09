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
-- a stack of the user with the usual controls, the Property Inspector
-- (and its section icons clicked: inspector-tabs; a button's colour given
-- and reset in it, and set by a script: inspector-reset-colour), the
-- Script Editor, the Message Box, the Project Browser, a click in
-- browse mode that opens an answer dialog, the Dictionary, Preferences,
-- the File menu, one of each control Object > New Control makes, the
-- page made narrow, a cascade of the File menu on a page as narrow as a
-- phone in portrait, File's items with a submenu tapped on a touch
-- screen, the ticks of File > Import Stack's HyperCard options, the browser switched between light and dark and back (the
-- page follows it: index.html's oxt-appearance), a tooltip in the light
-- and the dark appearance (its text must stand out from its background),
-- and the page's
-- not-saved bar as the IDE opens and when the browser's storage refuses
-- a write and then takes one. For each it asks for a screenshot of the
-- page. A step still running after 30 seconds (a
-- dialog it waits on) has its modal dialogs closed. Script errors in the
-- IDE's windows are recorded instead of shown.
--
-- Lines (window.oxtTour.record):
--    STARTED
--    INFO <key> <value>
--    ERROR <a script error, its lines joined with " | ">
--    ACT <id> shot <file>          a screenshot of the page
--    ACT <id> click <x> <y>        a click at a point of the page
--    ACT <id> move <x> <y>         the pointer moved to a point of the page
--    ACT <id> tap <x> <y>          a finger's tap at a point of the page
--    ACT <id> key <key>            a key (Playwright's name, "Escape")
--    ACT <id> size <width> <height>  the page's size
--    ACT <id> scheme light|dark    the browser's colour scheme
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

constant kSteps = "start,storage-open,keep,kept,sample,inspector,inspector-tabs,inspector-reset-colour,script-editor,message-box,project-browser,browse,dictionary,preferences,file-menu,new-controls,narrow,phone-menu,touch-menu,import-stack-marks,appearance,tooltip,storage"
constant kSample = "Web Tour Sample"
-- Steps that run only when web_ide_tour.py --only names them: keep, on
-- the released web IDE, saves a stack and a preference in the home
-- folder (the browser's storage), and kept, on the new one in the same
-- browser profile, finds them (web-ide.yml's upgrade job: an update of
-- the site keeps what the user saved, with no cache to clear)
constant kAskedSteps = "keep,kept"
constant kKept = "Web Tour Kept"
constant kKeptText = "Kept by the web IDE before the update"
-- The classic controls of Object > New Control (revMenubar), by the last
-- part of their kind
constant kNewControls = "Checkbox,ComboBox,DefaultButton,OptionMenu,PopupMenu,PulldownMenu,RadioButton,RectangleButton,Button,TabPanel,DataGrid,Field,LabelField,TextArea,ListField,TableField,Arrow,FivePointStar,OvalGraphic,RectangleGraphic,RegularGraphic,RoundRectGraphic,SpeechBubble,TenPointStar,CurveGraphic,PolygonGraphic,Image,Player,LittleArrows,Progressbar,Scrollbar,Slider"

-- A JavaScript function of the page (pointer x, y) that finds the window
-- of the tooltip shown below and to the right of the pointer (a small
-- canvas of em-dc.js's) and answers "<width>x<height> back <rgb> ink <rgb>
-- contrast <ratio>": its commonest colour inside its border, the colour
-- that stands out most from it, and their WCAG contrast; "none" when no
-- tooltip shows
constant kTooltipContrastJS = "(function (px, py) { var best = null; var list = document.querySelectorAll('.oxt-window'); for (var i = 0; i < list.length; i++) { var el = list[i]; if (getComputedStyle(el).display === 'none') continue; var cv = el.querySelector('canvas'); if (!cv) continue; var r = cv.getBoundingClientRect(); if (r.width < 8 || r.height < 8 || r.height > 120) continue; if (r.top < py - 4 || r.top > py + 60 || r.left < px - 40 || r.left > px + 60) continue; best = cv; } if (!best) return 'none'; var ctx = best.getContext('2d'); var w = best.width, h = best.height; var d = ctx.getImageData(0, 0, w, h).data; function lum(r, g, b) { var c = [r, g, b].map(function (v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; } var counts = {}, top = null, m = Math.max(3, Math.round(w / best.getBoundingClientRect().width * 3)); for (var y = m; y < h - m; y++) for (var x = m; x < w - m; x++) { var k = (y * w + x) * 4, key = d[k] + ',' + d[k + 1] + ',' + d[k + 2]; counts[key] = (counts[key] || 0) + 1; if (top === null || counts[key] > counts[top]) top = key; } var bg = top.split(',').map(Number), lb = lum(bg[0], bg[1], bg[2]), most = 1, ink = top; for (var y = m; y < h - m; y++) for (var x = m; x < w - m; x++) { var k = (y * w + x) * 4, l = lum(d[k], d[k + 1], d[k + 2]); var c = (Math.max(l, lb) + 0.05) / (Math.min(l, lb) + 0.05); if (c > most) { most = c; ink = d[k] + ',' + d[k + 1] + ',' + d[k + 2]; } } return Math.round(best.getBoundingClientRect().width) + 'x' + Math.round(best.getBoundingClientRect().height) + ' back ' + top + ' ink ' + ink + ' contrast ' + most.toFixed(2); })"

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
      if tOnly is empty and tStep is among the items of kAskedSteps then
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
-- The IDE as it opened: on a page smaller than Home (web_ide_tour.py
-- --size 640x480, openxtalk.org p=25583) the menu bar still spans the
-- page and Home's title bar is on it, below the menu bar, where a user
-- can take it
on tour_start
   local tScreen, tBar, tHome, tWin, tName
   tourShot "01-ide"
   put the screenRect into tScreen
   if there is not a stack "revMenubar" or not the visible of stack "revMenubar" then
      throw "no menu bar:" && tourJoin(the openStacks)
   end if
   put the rect of stack "revMenubar" into tBar
   if item 1 of tBar is not item 1 of tScreen or item 3 of tBar is not item 3 of tScreen then
      throw "the menu bar" && tBar && "does not span the page" && tScreen
   end if
   -- (OXT-Beyond Home, revHub, from 0.2.7-rc.6.12; Home's own window,
   -- revWebHome, before it)
   put empty into tWin
   repeat for each item tName in "revHub,revWebHome"
      if tWin is empty and tName is among the lines of the openStacks then put tName into tWin
   end repeat
   if tWin is not empty then
      put the rect of stack tWin into tHome
      -- (31: the page's title bar above a window, revWebIDEKeepOnPage)
      if item 1 of tHome < item 1 of tScreen or item 2 of tHome - 31 < item 4 of tBar \
            or item 2 of tHome > item 4 of tScreen - 31 then
         throw "Home" && tHome && "is not on the page" && tScreen && "below the menu bar" && tBar
      end if
      tourRecord "INFO Home" && tHome
   end if
end tour_start

-- As the IDE opened, the page's not-saved bar (index.html's #storage)
-- says whether the browser keeps the home folder, where the IDE saves
-- stacks: hidden when it does, and shown with the browser's reason when
-- its storage refused the page from the start, as a private window or a
-- site's blocked storage can (web_ide_tour.py --refuse-storage, which
-- runs this step alone). Before, the page said nothing, and a stack saved
-- there was lost when the tab closed.
on tour_storage_open
   if tourJS("String(window.oxtTour.refused)") is "true" then
      tourCheckStorage true, "refused by the tour", 5000
      tourShot "16-not-saved-at-open"
   else
      tourCheckStorage false, empty, 0
   end if
end tour_storage_open

-- keep (asked for): a stack saved in Documents, with a field's text, and
-- a preference, as a user's work and settings, written to the browser's
-- storage before the page goes
on tour_keep
   local tDefault, tFile
   put specialFolderPath("documents") & "/oxt-web-tour-kept.oxtstack" into tFile
   put the defaultStack into tDefault
   lock messages
   create invisible stack kKept
   set the defaultStack to kKept
   create field "Kept"
   set the text of it to kKeptText
   set the filename of stack kKept to tFile
   save stack kKept
   unlock messages
   set the defaultStack to tDefault
   delete stack kKept
   revIDESetPreference "oxtWebTourKept", kKeptText
   -- the preferences are saved 2 seconds after they change on the web
   -- (revInternal__SavePreferences), and the home folder soon after that
   tourWait 3500
   if there is not a file tFile then
      throw "the stack was not saved:" && tFile
   end if
   tourCheckStorage false, empty, 5000
   tourRecord "INFO kept" && tFile
end tour_keep

-- kept (asked for): what keep saved, there after the update
on tour_kept
   local tFile, tText, tPref
   put specialFolderPath("documents") & "/oxt-web-tour-kept.oxtstack" into tFile
   if there is not a file tFile then
      throw "the stack saved before the update is gone:" && tFile
   end if
   put the text of field "Kept" of stack tFile into tText
   delete stack kKept
   if tText is not kKeptText then
      throw "the stack saved before the update has" && tText
   end if
   put revIDEGetPreference("oxtWebTourKept") into tPref
   if tPref is not kKeptText then
      throw "the preference saved before the update is" && quote & tPref & quote
   end if
   tourRecord "INFO kept from before the update:" && tFile && "and the preference"
end tour_kept

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

-- The section icons in the inspector's header, clicked as a user clicks
-- them (OpenXTalkPaul on rc.6.3, on the web and the Mac: he "can't click
-- the little category tab icons"): each of the first few is clicked in
-- its middle, and the inspector must then show its section
on tour_inspector_tabs
   local tButton, tPI, tHeader, tNav, tHeight, tLeft, tTop, tIndex, tLabel, tX, tY, tShown, tFails
   put tourSample("Push") into tButton
   go stack kSample
   revIDESelectObjects tButton
   revIDEInspectObjects tButton
   tourWait 2000
   put tourStackNamed("revPropertyInspector") into tPI
   if tPI is empty then
      throw "no inspector opened:" && tourJoin(the openStacks)
   end if
   if there is not a widget "header_background" of group "background" of stack tPI then
      throw tPI && "has no header widget"
   end if
   put the long id of widget "header_background" of group "background" of stack tPI into tHeader
   put the navData of tHeader into tNav
   put the height of tHeader into tHeight
   -- the page's point of the header's top left
   put the left of stack tPI + the left of tHeader into tLeft
   put the top of stack tPI + the top of tHeader into tTop
   tourRecord "INFO inspector-tabs header" && the rect of tHeader && "of" && tPI && "at" && \
         the rect of stack tPI & ";" && the number of elements of tNav && "tabs, icons" && the showNavIcons of tHeader
   repeat with tIndex = 2 to min(5, the number of elements of tNav)
      put tNav[tIndex]["label"] into tLabel
      -- a tab is as wide as the header is high, after a padding of 0.225
      -- of that (paletteactions.lcb, calculateRects)
      put round(tLeft + tHeight * (0.225 + tIndex - 0.5)) into tX
      put round(tTop + tHeight * 0.55) into tY
      if tX > tLeft + the navBarRight of tHeader then
         exit repeat
      end if
      tourAct "click" && tX && tY
      tourWait 1500
      dispatch function "inspectorSectionGetName" to stack tPI
      put the result into tShown
      tourRecord "INFO inspector-tabs clicked" && tLabel && "at" && tX & "," & tY & ": shows" && tShown
      if tShown is not tLabel then
         put tLabel & ":" && tShown & "; " after tFails
      end if
   end repeat
   tourShot "03-inspector-tabs"
   tourCloseInspectors
   if tFails is not empty then
      throw "a click on a section's icon did not show it (the icon: the section shown):" && char 1 to -3 of tFails
   end if
end tour_inspector_tabs

-- A button's background colour given in the inspector and then taken
-- away with Reset to default (LittleNemo, openxtalk.org p=25968 and
-- p=25970: in the web IDE the colour stayed until the window was closed).
-- The swatch shows a colour picked in the colour dialog at once, but Reset
-- only sets the property: the swatch shows it again when the engine tells
-- the IDE that the property changed (its property listener, then the
-- IDE's idePropertyChanged), which the web engine never did. As the
-- desktop tour's inspector-reset-colour (ui-tour.livecodescript): a colour
-- given through the swatch, as the colour dialog gives it, is on the
-- button; after Reset the button has no colour of its own and the swatch
-- no longer shows the colour; and a colour a script sets is shown by the
-- swatch, and so is its removal
on tour_inspector_reset_colour
   local tButton, tPI, tEditor, tSwatch, tFails, tError
   put tourSample("Push") into tButton
   set the backgroundColor of tButton to empty
   go stack kSample
   revIDESelectObjects tButton
   revIDEInspectObjects tButton
   tourWait 2000
   put tourStackNamed("revPropertyInspector") into tPI
   if tPI is empty then
      throw "no inspector opened:" && tourJoin(the openStacks)
   end if
   try
      dispatch "inspectorSectionChanged" to stack tPI with "Colors"
      tourWait 1000
      put tourInspectorEditor(tPI, "backgroundColor") into tEditor
      if tEditor is empty then
         throw "the button's inspector has no Background fill"
      end if
      put the long id of control 1 of tEditor into tSwatch
      -- as the colour dialog's answer does (com.livecode.pi.color.behavior)
      set the swatchColor of tSwatch to "0,160,0"
      dispatch "valueChanged" to tEditor
      tourWait 1000
      tourRecord "INFO inspector-reset-colour given 0,160,0: backgroundColor" && quote & the backgroundColor of tButton & quote && \
            "swatch" && quote & the swatchColor of tSwatch & quote
      if the backgroundColor of tButton is not "0,160,0" then
         put "the colour given through the swatch is not on the button:" && quote & the backgroundColor of tButton & quote & return after tFails
      end if
      -- as a pick of Reset to default in the swatch's menu (editorPopupMenu's button)
      if there is not a button "inspectMenu" of tEditor then
         create invisible button "inspectMenu" in tEditor
      end if
      dispatch "menuPick" to button "inspectMenu" of tEditor with "Reset to default"
      repeat 30 times
         if item 1 to 3 of the swatchColor of tSwatch is not "0,160,0" then
            exit repeat
         end if
         tourWait 100
      end repeat
      tourWait 500
      tourRecord "INFO inspector-reset-colour after Reset: backgroundColor" && quote & the backgroundColor of tButton & quote && \
            "swatch" && quote & the swatchColor of tSwatch & quote
      if the backgroundColor of tButton is not empty then
         put "Reset left the backgroundColor" && the backgroundColor of tButton & return after tFails
      end if
      if item 1 to 3 of the swatchColor of tSwatch is "0,160,0" then
         put "after Reset the swatch still shows 0,160,0" & return after tFails
      end if
      tourShot "03-inspector-reset-colour"
      -- a colour that a script sets, and takes away
      set the backgroundColor of tButton to "0,0,200"
      repeat 30 times
         if item 1 to 3 of the swatchColor of tSwatch is "0,0,200" then
            exit repeat
         end if
         tourWait 100
      end repeat
      tourRecord "INFO inspector-reset-colour a script set 0,0,200: swatch" && quote & the swatchColor of tSwatch & quote
      if item 1 to 3 of the swatchColor of tSwatch is not "0,0,200" then
         put "the swatch does not show 0,0,200 that a script set (it shows" && quote & the swatchColor of tSwatch & quote & ")" & return after tFails
      end if
      set the backgroundColor of tButton to empty
      repeat 30 times
         if item 1 to 3 of the swatchColor of tSwatch is not "0,0,200" then
            exit repeat
         end if
         tourWait 100
      end repeat
      if item 1 to 3 of the swatchColor of tSwatch is "0,0,200" then
         put "the swatch still shows 0,0,200 after a script took it away" & return after tFails
      end if
   catch tError
      put tError & return after tFails
   end try
   set the backgroundColor of tButton to empty
   tourCloseInspectors
   if tFails is not empty then
      throw "failed:" && tourJoin(line 1 to -1 of tFails)
   end if
end tour_inspector_reset_colour

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
   -- its Refresh button: its own tooltip, and its icon, not a corner of
   -- the splash's art (littlenemo, openxtalk.org; 0.2.7-rc.6.19)
   local tProblem
   put tourRefreshProblem(tStack) into tProblem
   -- the names of a selected row are white on its blue hilite, here and
   -- in the App Browser (littlenemo, openxtalk.org p=26169; 0.2.7-rc.6.19):
   -- they were the accentColor, a blue, in the Project Browser, and black
   -- in the App Browser's controls list (its cSuspended, saved true)
   if tProblem is empty and revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor")) is not "255,255,255" then
      put "a selected Project Browser row's names are" && revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor")) && \
            "on its hilite, not white" into tProblem
   end if
   -- and black on the grey of a list that does not have the focus, where
   -- white would hardly show (0.2.7-rc.6.19)
   if tProblem is empty and revIDEHilitedTextColor("212,212,212") is not "0,0,0" then
      put "a selected Project Browser row's names are" && revIDEHilitedTextColor("212,212,212") && \
            "on the grey of a list without the focus, not black" into tProblem
   end if
   close stack tStack
   if tProblem is not empty then throw tProblem
   if "App Browser" is among the keys of revIDEPlugins() then
      revIDEOpenPlugin "App Browser"
      tourWait 1000
      if there is a stack "App Browser" then
         if the cSuspended of stack "App Browser" is true then
            put "the App Browser paints its selected rows' names black (its cSuspended is true)" into tProblem
         end if
         try
            dispatch "revAppBrowserFinalise" to stack "App Browser"
         end try
         close stack "App Browser"
      else
         put "the App Browser did not open" into tProblem
      end if
      if tProblem is not empty then throw tProblem
   end if
   tourExtensionStacksNotUsers
end tour_project_browser

-- The Project Browser's Refresh button (pStack is its stack): empty when
-- its tooltip names the Project Browser and its icon is revIcons' image,
-- which no image of another stack in memory shadows; else the problem.
-- A button's icon is found by its ID in every stack in memory, and the
-- splash's art, which until 0.2.7-rc.6.19 took the ID of revIcons'
-- "dark-refresh", showed in its place while the splash was in memory, as
-- the web IDE keeps it (littlenemo, openxtalk.org)
function tourRefreshProblem pStack
   local tButton, tIcon, tMain, tSub, tHits
   put the long id of button "Refresh" of card "list" of stack pStack into tButton
   -- (the tooltip is a property patch of the binary stack, which the
   -- pull requests' screenshot jobs take from the last release: its old
   -- tooltip is recorded, not failed; tools/oxt/ide-stack-patch.sh --check
   -- holds the stack in the repository to the patch)
   if the toolTip of tButton is "Refresh the Application Browser" then
      tourRecord "INFO the Project Browser's Refresh tooltip is the release's stack's:" && the toolTip of tButton
   else if the toolTip of tButton is not "Refresh the Project Browser" then
      return "the Project Browser's Refresh button's tooltip is" && quote & the toolTip of tButton & quote
   end if
   put the icon of tButton into tIcon
   if there is not a stack "revIcons" or there is not an image id tIcon of stack "revIcons" then
      return "the Project Browser's Refresh icon" && tIcon && "is not an image of revIcons"
   end if
   repeat for each line tMain in the mainStacks
      repeat for each line tSub in (tMain & return & the substacks of stack tMain)
         if tSub is empty or tSub is "revIcons" then next repeat
         try
            if there is an image id tIcon of stack tSub then
               put tSub & ": " & the short name of image id tIcon of stack tSub & "; " after tHits
            end if
         catch tError
         end try
      end repeat
   end repeat
   if tHits is not empty then
      return "the Project Browser's Refresh icon" && tIcon && "is shadowed by an image of the same ID in" && tHits
   end if
   return empty
end tourRefreshProblem

-- The stacks the IDE loads from its own Extensions folder are its own, not
-- the user's: until 0.2.7-rc.6.18 the web IDE's Project Browser and App
-- Browser listed the layout guides' library,
-- community.ferruslogic.plugin.devguides (757 lines), first among the
-- user's stacks (LittleNemo, openxtalk.org p=26169). The desktop IDEs' App
-- Browsers did not list it. Both browsers take the user's stacks from
-- revFilterStacksList
command tourExtensionStacksNotUsers
   local tUsers, tExtensions, tStackName, tTheirs
   put revFilterStacksList(the mainStacks) into tUsers
   tourRecord "INFO the user's stacks:" && tourJoin(tUsers)
   put revIDESpecialFolderPath("extensions") & slash into tExtensions
   repeat for each line tStackName in tUsers
      if the effective filename of stack tStackName begins with tExtensions then
         put tStackName & return after tTheirs
      end if
   end repeat
   if tTheirs is not empty then
      throw "the IDE lists its own extensions' stacks among the user's stacks:" && \
            tourJoin(line 1 to -1 of tTheirs) && "(in" && tExtensions & ")"
   end if
end tourExtensionStacksNotUsers

-- A click on the sample's button in browse mode runs its script, which
-- opens an answer dialog: the click comes from the page, as a user's does
on tour_browse
   local tLoc
   go stack kSample
   set the tool to "browse tool"
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

-- One of each control Object > New Control makes, in a stack of their
-- own, as the menu makes them (revIDECreateObject, which gives each its
-- properties' defaults): a property the web engine does not have fails
-- the step, as the player's mirrored did (player-legacy)
on tour_new_controls
   local tStack, tType, tCount
   lock messages
   create stack "Web Tour Controls"
   put the long id of it into tStack
   set the rect of tStack to "320,160,1000,700"
   unlock messages
   go tStack
   put 0 into tCount
   repeat for each item tType in kNewControls
      revIDECreateObject "com.livecode.interface.classic." & tType, tStack, \
            (100 + (tCount mod 6) * 90) & comma & (60 + (tCount div 6) * 80)
      add 1 to tCount
   end repeat
   if the number of controls of card 1 of tStack < tCount then
      throw "made" && the number of controls of card 1 of tStack && "of" && tCount && "controls"
   end if
   tourWait 1000
   tourShot "11-new-controls"
   revIDEDeselectAll
   lock messages
   delete tStack
   unlock messages
end tour_new_controls

-- The page made narrow, as a phone or a small window has it: the IDE
-- follows the page's size (ideDesktopChanged)
on tour_narrow
   go stack kSample
   tourAct "size 900 700"
   tourWait 3000
   tourRecord "INFO screenRect when narrow" && the screenRect
   tourShot "12-narrow-page"
   tourAct "size 1400 900"
   tourWait 2000
end tour_narrow

-- A cascade of the File menu (New Stack's) on a page as narrow as a phone
-- in portrait: with no room on either side of the menu, it opened off the
-- page's left edge (forum report, 2026-10-22); it must be on the page
on tour_phone_menu
   local tMenu, tRects, tFirst, tRect
   tourAct "size 390 844"
   tourWait 3000
   put tourMenuButton("File") into tMenu
   if tMenu is empty then
      throw "no File menu in revMenuBar"
   end if
   tourAct "click" && item 1 of the globalLoc of the loc of tMenu && item 2 of the globalLoc of the loc of tMenu
   tourWait 1500
   put tourMenuRects() into tFirst
   if tFirst is empty then
      throw "the File menu did not open"
   end if
   -- the pointer on the menu's first item, New Stack, opens its cascade
   tourAct "move" && (item 1 of line 1 of tFirst + 40) && (item 2 of line 1 of tFirst + 12)
   tourAct "move" && (item 1 of line 1 of tFirst + 50) && (item 2 of line 1 of tFirst + 13)
   tourWait 1500
   put tourMenuRects() into tRects
   tourRecord "INFO menus on a phone-sized page" && tourJoin(tRects)
   tourShot "13-phone-menu"
   tourAct "key Escape"
   tourWait 800
   tourAct "size 1400 900"
   tourWait 2000
   if the number of lines of tRects < 2 then
      throw "New Stack's cascade did not open:" && tourJoin(tRects)
   end if
   repeat for each line tRect in tRects
      if item 1 of tRect < 0 or item 3 of tRect > 390 then
         throw "a menu is off the page:" && tourJoin(tRects)
      end if
   end repeat
end tour_phone_menu

-- File's items with a submenu, tapped on a touch screen (a finger, not the
-- mouse): the menu that was tapped took the keyboard and lost it again,
-- and that closed the submenu as it opened, so only the first level of a
-- menu could be reached (forum report, 2026-10-23). A tap on New Stack (at
-- the top of the menu) and on Import Stack must each leave its submenu
-- open, on a page as narrow as a phone and on a wide one.
on tour_touch_menu
   local tSize, tItem, tTop, tRects, tFirst, tProblems
   repeat for each item tSize in "390 844,1400 900"
      tourAct "size" && tSize
      tourWait 2500
      repeat for each item tItem in "New Stack,Import Stack"
         tourTapFileMenu
         put the result into tFirst
         if tFirst is empty then
            throw "the File menu did not open with a tap"
         end if
         -- New Stack is the menu's first item, Import Stack its fifth
         if tItem is "New Stack" then
            put 12 into tTop
         else
            put 100 into tTop
         end if
         tourAct "tap" && (item 1 of line 1 of tFirst + 40) && (item 2 of line 1 of tFirst + tTop)
         tourWait 1500
         put tourMenuRects() into tRects
         tourRecord "INFO menus after a tap on" && tItem && "at" && tSize & ":" && tourJoin(tRects)
         if tItem is "New Stack" and word 1 of tSize is 390 then
            tourShot "14-touch-menu"
         end if
         tourAct "key Escape"
         tourWait 500
         tourAct "key Escape"
         tourWait 800
         if the number of lines of tRects < 2 then
            put tItem && "at" && tSize & ":" && tourJoin(tRects) & "; " after tProblems
         end if
      end repeat
   end repeat
   if tProblems is not empty then
      throw "a tap on a menu item with a submenu closed the menu:" && tProblems
   end if
end tour_touch_menu

-- File > Import Stack's HyperCard options are ticked when they are on
-- (revMenubar's toggleMenuItem: "!c" for on, "!n" for off), and a tick
-- must be drawn. The marks are in a submenu of a menu whose top level has
-- none, and until 0.2.7 the engine made a menu's items check items only
-- when a line of its top level began with a mark, so the submenu's
-- ticks were parsed and never drawn: the options looked off whatever
-- they were set to (seth, the web IDE in Brave on Windows 11). The
-- submenu is read twice, its four options on and then off: the strip of
-- it where the ticks go must differ between the two, and the
-- preferences are put back as they were.
constant kImportStackPrefs = "cHyperCardFixScripts,cHyperCardMessageOrder,cHyperCardClassicLook,cHyperCardImportSummary"

on tour_import_stack_marks
   local tPref, tSaved, tOn, tOff, tDiffer, tError
   repeat for each item tPref in kImportStackPrefs
      put revIDEGetPreference(tPref) into tSaved[tPref]
   end repeat
   try
      repeat for each item tPref in kImportStackPrefs
         revIDESetPreference tPref, true
      end repeat
      put tourImportStackStrip("15-import-stack-marks") into tOn
      repeat for each item tPref in kImportStackPrefs
         revIDESetPreference tPref, false
      end repeat
      put tourImportStackStrip("15b-import-stack-no-marks") into tOff
   catch tError
   end try
   repeat for each item tPref in kImportStackPrefs
      revIDESetPreference tPref, tSaved[tPref]
   end repeat
   if tError is not empty then
      throw tError
   end if
   -- a strip of one colour is no menu read (a canvas the page could not
   -- read gives zeros), and would differ in nothing whatever was drawn
   if tourStripSpread(tOff) < 64 then
      throw "the submenu's tick strip was not read: its lumas spread by" && tourStripSpread(tOff)
   end if
   put tourStripsDiffer(tOn, tOff) into tDiffer
   tourRecord "INFO import-stack-marks: the tick strip differs in" && tDiffer && "pixels, options on and off;" && \
         "its lumas spread by" && tourStripSpread(tOff)
   -- a tick is a filled polygon of about 30 pixels, and there are four
   if tDiffer < 40 then
      throw "File > Import Stack's ticks are not drawn: the submenu's tick strip differs in" && \
            tDiffer && "pixels between its options on and off"
   end if
   -- An item that opens a deeper submenu, in a submenu with a mark, keeps
   -- its arrow: drawn at the submenu's right edge, where no word reaches
   local tInk
   put tourStripInk(tourNestedSubmenuStrip("Plain" & return & "Sub" & return & tab & "!cTicked" & return & \
         tab & "Deeper" & return & tab & tab & "Child", "15c-nested-submenu")) into tInk
   tourRecord "INFO import-stack-marks: the nested submenu's arrow has" && tInk && "pixels"
   -- the arrow is a small filled triangle
   if tInk < 6 then
      throw "a submenu item that opens a deeper submenu has no arrow when its submenu has a mark:" && \
            tInk && "pixels stand out at the submenu's right edge"
   end if
end tour_import_stack_marks

-- File > Import Stack's submenu, opened with the pointer, as a screenshot
-- pShot; the result is the luma of each pixel of its left 24 points
-- (where its ticks go), "<width>,<height>,<strip width>:" and then the
-- lumas, a space between each
function tourImportStackStrip pShot
   local tMenu, tFirst, tRects, tStrip
   put tourMenuButton("File") into tMenu
   if tMenu is empty then
      throw "no File menu in revMenuBar"
   end if
   tourAct "click" && item 1 of the globalLoc of the loc of tMenu && item 2 of the globalLoc of the loc of tMenu
   tourWait 1500
   put tourMenuRects() into tFirst
   if tFirst is empty then
      throw "the File menu did not open"
   end if
   -- Import Stack is the menu's fifth item (tour_touch_menu)
   tourAct "move" && (item 1 of line 1 of tFirst + 40) && (item 2 of line 1 of tFirst + 100)
   tourAct "move" && (item 1 of line 1 of tFirst + 50) && (item 2 of line 1 of tFirst + 101)
   tourWait 1500
   put tourMenuRects() into tRects
   tourRecord "INFO import-stack-marks: menus" && tourJoin(tRects)
   tourShot pShot
   put tourSubmenuStrip("left") into tStrip
   tourAct "key Escape"
   tourWait 500
   tourAct "key Escape"
   tourWait 800
   if the number of lines of tRects < 2 or tStrip is empty then
      throw "File > Import Stack's submenu did not open:" && tourJoin(tRects)
   end if
   return tStrip
end tourImportStackStrip

-- The luma of each pixel of a strip pPoints wide (24 when empty) at the
-- pSide (left or right) of the open submenu, the menu furthest right of those open:
-- "<width>,<height>,<strip width>:" and then the lumas, a space between
-- each; empty when no submenu is open
function tourSubmenuStrip pSide, pPoints
   local tFrom
   if pPoints is empty then
      put 24 into pPoints
   end if
   if pSide is "right" then
      put "c.width - sw" into tFrom
   else
      put "0" into tFrom
   end if
   return tourJS("(function () { var w = Array.from(document.querySelectorAll('.oxt-window'))" & \
         ".filter(function(e) { var r = e.getBoundingClientRect(); return e.oxtLayer === 3 && r.width > 0 && r.height > 0; })" & \
         ".sort(function(a, b) { return a.getBoundingClientRect().left - b.getBoundingClientRect().left; });" & \
         " if (w.length < 2) { return ''; }" & \
         " var c = w[w.length - 1].querySelector('canvas'); if (!c) { return ''; }" & \
         " var sw = Math.min(c.width, Math.round(c.width * " & pPoints & " / c.getBoundingClientRect().width));" & \
         " var d = c.getContext('2d').getImageData(" & tFrom & ", 0, sw, c.height).data, o = [];" & \
         " for (var i = 0; i < d.length; i += 4) { o.push(Math.round(0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2])); }" & \
         " return c.width + ',' + c.height + ',' + sw + ':' + o.join(' '); })()")
end tourSubmenuStrip

-- A submenu with a mark that also opens a deeper submenu, in a pulldown
-- menu of a stack of the tour's, whose top level has no mark: pText is
-- the menu's text, and the result the right strip of its submenu
-- (tourSubmenuStrip, 14 points), the menu's second item hovered to open it. The
-- item that opens the deeper submenu must keep its arrow when its
-- submenu's items become check items (codex review of #425: made a
-- check item, it lost the arrow that a menu item draws)
function tourNestedSubmenuStrip pText, pShot
   local tStack, tTool, tDefault, tLoc, tFirst, tRects, tStrip
   put "Web Tour Nested Marks" into tStack
   put the tool into tTool
   lock messages
   if there is a stack tStack then delete stack tStack
   create stack tStack
   set the rect of stack tStack to "320,160,720,460"
   put the defaultStack into tDefault
   set the defaultStack to tStack
   create button "Marks"
   set the style of it to "menu"
   set the menuMode of it to "pulldown"
   set the rect of it to "20,20,140,42"
   set the text of it to pText
   set the defaultStack to tDefault
   unlock messages
   go stack tStack
   set the tool to "browse tool"
   tourWait 800
   put the globalLoc of the loc of button "Marks" of card 1 of stack tStack into tLoc
   tourAct "click" && item 1 of tLoc && item 2 of tLoc
   tourWait 1500
   put tourMenuRects() into tFirst
   if tFirst is not empty then
      -- the second item, Sub
      tourAct "move" && (item 1 of line 1 of tFirst + 30) && (item 2 of line 1 of tFirst + 30)
      tourAct "move" && (item 1 of line 1 of tFirst + 36) && (item 2 of line 1 of tFirst + 31)
      tourWait 1500
      put tourMenuRects() into tRects
      tourRecord "INFO import-stack-marks: nested menus" && tourJoin(tRects)
      tourShot pShot
      put tourSubmenuStrip("right", 14) into tStrip
   end if
   tourAct "key Escape"
   tourWait 500
   tourAct "key Escape"
   tourWait 800
   set the tool to tTool
   lock messages
   delete stack tStack
   unlock messages
   if tStrip is empty then
      throw "the nested menu's submenu did not open:" && tourJoin(tFirst) && "|" && tourJoin(tRects)
   end if
   return tStrip
end tourNestedSubmenuStrip

-- How many pixels of a strip of tourSubmenuStrip stand out from the menu
-- (differ in luma by more than a quarter of the way from black to white
-- from the strip's commonest luma), its outer 3 pixels left out (the
-- menu's border)
function tourStripInk pStrip
   local tSize, tLumas, tWidth, tHeight, tCounts, tLuma, tBack, tMost, tCount, x, y
   set the itemDelimiter to ":"
   put item 1 of pStrip into tSize
   put item 2 of pStrip into tLumas
   set the itemDelimiter to comma
   put item 3 of tSize into tWidth
   put item 2 of tSize into tHeight
   split tLumas by space
   put 0 into tMost
   repeat for each element tLuma in tLumas
      add 1 to tCounts[tLuma]
      if tCounts[tLuma] > tMost then
         put tCounts[tLuma] into tMost
         put tLuma into tBack
      end if
   end repeat
   put 0 into tCount
   repeat with y = 3 to tHeight - 4
      repeat with x = 0 to tWidth - 4
         if abs(tLumas[y * tWidth + x + 1] - tBack) > 64 then
            add 1 to tCount
         end if
      end repeat
   end repeat
   return tCount
end tourStripInk

-- How far apart the lightest and darkest pixel of a strip of
-- tourImportStackStrip are in luma (0 to 255): the item's words reach
-- into it, light on dark or dark on light
function tourStripSpread pStrip
   local tLumas, tLuma, tMin, tMax
   set the itemDelimiter to ":"
   put item 2 of pStrip into tLumas
   put 255 into tMin
   put 0 into tMax
   repeat for each word tLuma in tLumas
      put min(tMin, tLuma) into tMin
      put max(tMax, tLuma) into tMax
   end repeat
   return max(0, tMax - tMin)
end tourStripSpread

-- How many pixels of two strips of tourImportStackStrip differ in luma by
-- more than a quarter of the way from black to white (0 to 255); strips
-- of different sizes throw
function tourStripsDiffer pA, pB
   local tA, tB, tCount, i
   set the itemDelimiter to ":"
   if item 1 of pA is not item 1 of pB then
      throw "the submenu's size changed between its options on and off:" && item 1 of pA && "and" && item 1 of pB
   end if
   put item 2 of pA into tA
   put item 2 of pB into tB
   split tA by space
   split tB by space
   put 0 into tCount
   repeat with i = 1 to the number of elements of tA
      if abs(tA[i] - tB[i]) > 64 then
         add 1 to tCount
      end if
   end repeat
   return tCount
end tourStripsDiffer

-- Opens the File menu with a tap; the result is the open menus' rects
command tourTapFileMenu
   local tMenu
   put tourMenuButton("File") into tMenu
   if tMenu is empty then
      throw "no File menu in revMenuBar"
   end if
   tourAct "tap" && item 1 of the globalLoc of the loc of tMenu && item 2 of the globalLoc of the loc of tMenu
   tourWait 1500
   return tourMenuRects()
end tourTapFileMenu

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

-- The editor of the property pProperty in the inspector pStack: the group
-- revinspectorgroupbehavior.livecodescript names for it, in the row of
-- the section shown (as in ui-tour.livecodescript)
function tourInspectorEditor pStack, pProperty
   local tCard, tControl, i
   put the long id of this card of stack pStack into tCard
   repeat with i = 1 to the number of controls of tCard
      put the long id of control i of tCard into tControl
      if word 1 of tControl is not "group" or the short name of tControl is not pProperty then
         next repeat
      end if
      if the editorProperty["property_name"] of tControl is pProperty then
         return tControl
      end if
   end repeat
   return empty
end tourInspectorEditor

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
-- The page's rects (left,top,right,bottom) of the windows of the menus
-- that are open, one per line, in the order they opened
function tourMenuRects
   return tourJS("Array.from(document.querySelectorAll('.oxt-window'))" & \
         ".filter(function(e) { var r = e.getBoundingClientRect(); return e.oxtLayer === 3 && r.width > 0 && r.height > 0; })" & \
         ".map(function(e) { var r = e.getBoundingClientRect(); return [r.left, r.top, r.right, r.bottom].map(Math.round).join(','); })" & \
         ".join('\n')")
end tourMenuRects

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

-- The page follows the browser between light and dark (index.html's
-- oxt-appearance, seth's choice for item 8 of 2026-10-30): the
-- systemAppearance is the browser's colour scheme (web_ide_tour.py
-- --color-scheme), and when the browser switches, the IDE hears
-- systemAppearanceChanged and the menu bar takes the new appearance's
-- colours (revWebIDELibrary's styleMenubar). The browser is switched to
-- the other scheme and back; each switch must reach the IDE within 5
-- seconds
on tour_appearance
   local tStart, tOther
   if tourJS("window.matchMedia('(prefers-color-scheme: dark)').matches") is "true" then
      put "dark" into tStart
      put "light" into tOther
   else
      put "light" into tStart
      put "dark" into tOther
   end if
   tourCheckAppearance tStart, 0
   tourAct "scheme" && tOther
   tourCheckAppearance tOther, 5000
   tourShot "15-appearance-" & tOther
   tourAct "scheme" && tStart
   tourCheckAppearance tStart, 5000
end tour_appearance

-- A tooltip, as the pointer rests on the sample's button in browse mode,
-- must be readable in both appearances: in the dark one its background is
-- dark (em-theme.cpp), and its text was black on it until the engine wrote
-- it white (bwmilby, openxtalk.org p=26171: the Tools palette's tooltips
-- and the Project Browser's in Safari's dark mode). The page reads the
-- tooltip's window (its canvas) and answers the WCAG contrast of its
-- inkiest pixel with its background, which must be at least 4.5 (AA); it
-- was 1.29 on rc.6.17's engine. The light appearance keeps black on
-- RGB(240,240,240).
on tour_tooltip
   local tStart, tButton, tScheme, tProblems
   if tourJS("window.matchMedia('(prefers-color-scheme: dark)').matches") is "true" then
      put "dark" into tStart
   else
      put "light" into tStart
   end if
   put tourSample("Push") into tButton
   set the toolTip of tButton to "A tooltip of the tour's sample button"
   go stack kSample
   set the tool to "browse tool"
   -- (the engine shows a tooltip only in the window that has the focus,
   -- or a palette: a click on the card, below its controls)
   tourAct "click" && the left of stack kSample + 100 && the top of stack kSample + 325
   tourWait 300
   repeat for each item tScheme in "light,dark"
      tourAct "scheme" && tScheme
      tourCheckAppearance tScheme, 5000
      put tourTooltipProblem(tButton, tScheme) after tProblems
   end repeat
   choose pointer tool
   set the toolTip of tButton to empty
   if tStart is not "dark" then
      tourAct "scheme" && tStart
      tourCheckAppearance tStart, 5000
   end if
   if tProblems is not empty then
      throw char 1 to -3 of tProblems
   end if
end tour_tooltip

-- Rests the pointer on pControl until its tooltip shows (at most 5
-- seconds), takes a screenshot, and answers what is wrong with the
-- tooltip's contrast, followed by "; " (empty when nothing is)
function tourTooltipProblem pControl, pScheme
   local tLoc, tDeadline, tInfo
   put the globalLoc of the loc of pControl into tLoc
   -- (off the button and back, so that the engine opens a new tooltip)
   tourAct "move" && item 1 of tLoc && item 2 of tLoc + 200
   tourWait 300
   tourAct "move" && item 1 of tLoc && item 2 of tLoc
   put the milliseconds + 5000 into tDeadline
   repeat
      put tourJS(kTooltipContrastJS & "(" & item 1 of tLoc & "," & item 2 of tLoc & ")") into tInfo
      if word 1 of tInfo is not "none" or the milliseconds > tDeadline then
         exit repeat
      end if
      wait 100 milliseconds with messages
   end repeat
   tourShot "16-tooltip-" & pScheme
   tourAct "move" && item 1 of tLoc && item 2 of tLoc + 200
   tourRecord "INFO tooltip" && pScheme & ":" && tInfo
   if word 1 of tInfo is "none" then
      return "no tooltip showed in the" && pScheme && "appearance; "
   end if
   if word -1 of tInfo is not a number or word -1 of tInfo < 4.5 then
      return "the tooltip's text does not stand out in the" && pScheme && "appearance (" & tInfo & ", want a contrast of 4.5 or more); "
   end if
   return empty
end tourTooltipProblem

-- A write to the browser's storage that fails (a full disk, a refused or
-- deleted storage) shows the page's not-saved bar with the browser's
-- reason, and the next write that works hides it again. The tour makes
-- the storage refuse each write (IDBObjectStore's put, which the engine's
-- IDBFS writes with, throws), saves a file in the home folder, then lets
-- the storage write again and saves it again.
on tour_storage
   local tFile, tProblem
   put specialFolderPath("documents") & "/oxt-web-tour-storage.txt" into tFile
   tourCheckStorage false, empty, 0
   get tourJS("(function () { var p = IDBObjectStore.prototype; " & \
         "if (!window.oxtTourPut) { window.oxtTourPut = p.put; } " & \
         "p.put = function () { throw new DOMException('refused by the tour', 'QuotaExceededError'); }; " & \
         "return 'refusing'; })()")
   try
      put "not kept" into URL ("file:" & tFile)
      tourCheckStorage true, "refused by the tour", 5000
      tourShot "17-not-saved"
   catch tProblem
   end try
   get tourJS("(function () { if (window.oxtTourPut) { IDBObjectStore.prototype.put = window.oxtTourPut; } " & \
         "return 'writing'; })()")
   if tProblem is empty then
      try
         put "kept" into URL ("file:" & tFile)
         tourCheckStorage false, empty, 5000
      catch tProblem
      end try
   end if
   if there is a file tFile then
      delete file tFile
   end if
   if tProblem is not empty then
      throw tProblem
   end if
end tour_storage

-- Waits (at most pMilliseconds) until the page's not-saved bar is shown
-- with pReason in it (pShown true), or hidden, and the engine's
-- Module.livecodeStorageError says the same
command tourCheckStorage pShown, pReason, pMilliseconds
   local tDeadline, tState, tText, tError, tWant
   put the milliseconds + pMilliseconds into tDeadline
   repeat
      put tourJS("(function () { var e = document.getElementById('storage'); " & \
            "return e ? getComputedStyle(e).display : 'missing'; })()") into tState
      put tourJS("(function () { var e = document.getElementById('storage'); " & \
            "return e ? e.textContent.replace(/\s+/g, ' ') : ''; })()") into tText
      put tourJS("String(window.Module && Module.livecodeStorageError || '')") into tError
      if pShown is true then
         if tState is "block" and pReason is in tText and pReason is in tError then
            exit repeat
         end if
      else if tState is "none" and tError is empty then
         exit repeat
      end if
      if the milliseconds > tDeadline then
         if pShown is true then
            put "shown, with" && quote & pReason & quote into tWant
         else
            put "hidden" into tWant
         end if
         throw "after" && pMilliseconds && "ms the page's not-saved bar is" && tState && \
               "(" & tText & "), Module.livecodeStorageError" && quote & tError & quote & "; want it" && tWant
      end if
      wait 100 milliseconds with messages
   end repeat
   tourRecord "INFO not-saved bar" && tState & ":" && tText
end tourCheckStorage

-- The systemAppearance, the menu bar's colours and the toolbar's pictures
-- all say pAppearance (within pMilliseconds): in dark the pictures are
-- drawn (revMenubar's mbDrawImages), in light they are images-web's files
command tourCheckAppearance pAppearance, pMilliseconds
   local tDeadline, tHeader, tWant, tIcon, tDrawn
   put the milliseconds + pMilliseconds into tDeadline
   if pAppearance is "dark" then
      put "40,45,52" into tWant
   else
      put "244,246,248" into tWant
   end if
   put the long id of image "Tools" of group "icons" of stack "revMenubar" into tIcon
   repeat
      put the backColor of stack "revMenubar" into tHeader
      put the filename of tIcon is empty into tDrawn
      if the systemAppearance is pAppearance and tHeader is tWant and tDrawn is (pAppearance is "dark") then
         exit repeat
      end if
      if the milliseconds > tDeadline then
         throw "after" && pMilliseconds && "ms the systemAppearance is" && the systemAppearance & \
               ", the menu bar's backColor" && tHeader & ", the Tools picture's file" && the filename of tIcon & \
               "; want" && pAppearance && "and" && tWant
      end if
      wait 100 milliseconds with messages
   end repeat
   tourRecord "INFO appearance" && pAppearance & ": menu bar" && tHeader & ", Tools picture" && \
         the filename of tIcon && the width of tIcon & "x" & the height of tIcon
end tourCheckAppearance

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
