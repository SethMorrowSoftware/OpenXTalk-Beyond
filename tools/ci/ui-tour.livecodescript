script "oxt_ui_tour"
-- Screenshots of the IDE's own windows, run inside the real IDE by
-- tools/ci/ui_tour.py, which names this file on the command line: the
-- engine opens it once the IDE has started (home.livecodescript,
-- revInternal__openStack).
--
-- It waits for the IDE to finish starting, sets it to follow the system
-- (View > Appearance: the IDE and the user's stacks), then opens the IDE's
-- windows one by one: the Tools palette, a stack of the user with the
-- usual controls, the Property Inspector (each section for a button, the
-- Text section of a field, the Colors section of a graphic and of several
-- objects), the Script Editor (and its results of a Find All), the
-- Message Box, the Project Browser, the Dictionary, each pane of
-- Preferences, each card of the Standalone Settings, the Menu Builder, the
-- Extension Manager and Builder, the Message Watcher, Search, the Object
-- Library, the Card Navigator, the About window, the answer and ask
-- dialogs and the icon chooser. Not the Start Center: OpenXTalk Lite 1.15
-- turned it off (no menu opens it and its Preferences are greyed out),
-- and opened by a script it is an empty window. For each it
-- writes a snapshot of the screen around the window (the effective rect
-- of the stack, so with its title bar), and with the mouse over a tool of
-- the Tools palette and over a row of the inspector it snapshots the
-- tooltip. Moving the pointer makes no event on macOS
-- (CGWarpMouseCursorPosition), so there a mouse moved event is posted too
-- (osascript, CGEventPost).
--
-- A step still running after 20 seconds (a dialog it waits on) gets a
-- snapshot of the whole screen and its modal dialogs closed. Script errors
-- in the IDE's windows go to the log instead of a dialog.
--
-- Environment:
--    OXT_TOUR_OUT    the folder for the snapshots (PNG)
--    OXT_TOUR_LOG    the file for the lines below
--    OXT_TOUR_ONLY   comma-separated steps to run (empty: all)
--
-- Lines:
--    STARTED
--    INFO <key> <value>
--    ERROR <a script error, its lines joined with " | ">
--    SHOT <file> <rect>
--    STEP <name> ok | STEP <name> FAILED <error>
--    DONE
-- The script leaves the IDE running; tools/ci/ui_tour.py ends it.

constant kSteps = "appearance,screen,tools,tooltip-tools,hover-tools,menubar,sample,inspector,inspector-text,inspector-graphic,inspector-multiple,tooltip-inspector,script-editor,script-editor-search,message-box,project-browser,dictionary,preferences,standalone-settings,menu-builder,extension-manager,extension-builder,message-watcher,search,object-library,navigator,about,answer,ask,icon-chooser,screen-end"
constant kSample = "OXT Tour Sample"
-- The inspector's sections for a button, as the icons in its header name
-- them (a section the object has not is skipped)
constant kButtonSections = "Basic,Icons,Colors,Text,Position,Effects,Custom,Advanced"

local sOut, sLog, sOnly, sCount, sStarted, sWatchdog, sWatchdogCount

on openStack
   if sStarted is not true then
      put true into sStarted
      put $OXT_TOUR_OUT into sOut
      put $OXT_TOUR_LOG into sLog
      put $OXT_TOUR_ONLY into sOnly
      -- out of the way of the IDE's windows
      hide stack "oxt_ui_tour"
      send "tourWhenStarted 0" to me in 1 second
   end if
   pass openStack
end openStack

-- Waits until the IDE has finished starting (home.livecodescript sets the
-- cREVLaunching of stack "Home" while it opens its palettes), then a
-- little more for their deferred messages
on tourWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then put the cREVLaunching of stack "Home" into tLaunching
   if tLaunching is true and pTries < 120 then
      send "tourWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "tourRun" to me in 2 seconds
   end if
end tourWhenStarted

on tourRun
   local tStep, tHandler, tError
   put 0 into sCount
   tourRecord "STARTED"
   tourRecord "INFO platform" && the platform && the systemVersion && the processor
   tourRecord "INFO version" && the version && the buildNumber
   tourRecord "INFO screenRect" && the screenRect
   tourRecord "INFO openStacks" && tourJoin(the openStacks)
   tourCatchErrors
   repeat for each item tStep in kSteps
      if sOnly is not empty and tStep is not among the items of sOnly then next repeat
      put "tour_" & tStep into tHandler
      replace "-" with "_" in tHandler
      put 0 into sWatchdogCount
      send "tourWatchdog" && quote & tStep & quote to me in 20 seconds
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

-- Errors in the IDE's scripts go to the log, not to the IDE's error dialog
-- or the debugger (revTestEnvironment, as the IDE's test runner sets it),
-- and the desktop stays shown when the IDE's windows get clicked
command tourCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      revIDESetPreference "cDesktopClickToHide", false
      put the defaultStack into tDefault
      set the defaultStack to "oxt_ui_tour"
      lock messages
      create invisible button "oxt_ui_tour_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "tourScriptError" & quote & " to stack " & quote & "oxt_ui_tour" & quote & " with pError" & return & \
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

on tour_appearance
   local tError
   revIDESetAppearance "ide", "system"
   revIDESetAppearance "stacks", "ide"
   tourWait 1000
   tourRecord "INFO systemAppearance" && the systemAppearance
   tourRecord "INFO revIDEIsDark" && revIDEIsDark()
   tourRecord "INFO cIDEAppearance" && revIDEAppearancePreference("ide") && "cStackAppearance" && revIDEAppearancePreference("stacks")
   try
      do "get the effective appAppearance"
      tourRecord "INFO effective appAppearance" && it
      do "get the effective stackAppearance of stack" && quote & "revTools" & quote
      tourRecord "INFO effective stackAppearance of revTools" && it
   catch tError
      tourRecord "INFO appearance properties" && tourJoin(line 1 of tError)
   end try
end tour_appearance

on tour_screen
   tourShotScreen "00-screen-start"
end tour_screen

on tour_tools
   revIDEOpenPalette "tools"
   tourWait 500
   tourShotStack "revTools", "01-tools"
end tour_tools

on tour_tooltip_tools
   local tButton
   revIDEOpenPalette "tools"
   tourWait 300
   put tourControlNamed("revTools", "com.livecode.tool.Pointer") into tButton
   if tButton is empty or the tooltip of tButton is empty then put tourObjectWithTooltip("revTools") into tButton
   if tButton is empty then throw "no control of revTools has a tooltip"
   tourRecord "INFO tooltip" && the short name of tButton & ":" && tourJoin(the tooltip of tButton)
   tourHover tButton, "revTools"
   tourShotAround tButton, "revTools", "02-tooltip-tools"
   tourMouseAway
end tour_tooltip_tools

-- A shape of the Tools palette under the pointer: the palette turns the
-- icon of a classic object one colour (a colour overlay), which must not be
-- the colour of the palette
on tour_hover_tools
   local tButton
   revIDEOpenPalette "tools"
   tourWait 300
   put tourControlNamed("revTools", "com.livecode.interface.classic.RectangleGraphic") into tButton
   if tButton is empty then throw "no Rectangle Graphic in the Tools palette"
   tourHover tButton, "revTools"
   tourRecord "INFO hover" && the short name of tButton & ":" && tourJoin(the colorOverlay["color"] of tButton)
   tourShotAround tButton, "revTools", "02-hover-tools"
   tourMouseAway
end tour_hover_tools

on tour_menubar
   -- Windows and Linux: the IDE's menu bar and toolbar are a stack
   if there is a stack "revMenuBar" and the visible of stack "revMenuBar" then
      tourShotStack "revMenuBar", "03-menubar"
   else
      tourRecord "INFO menubar: no visible revMenuBar stack (the menu bar is the system's)"
   end if
end tour_menubar

on tour_sample
   local tStack
   put tourSampleStack() into tStack
   go tStack
   tourWait 800
   tourShotStack kSample, "04-sample-stack"
end tour_sample

on tour_inspector
   local tPI, tSection, tShown, tIndex
   put tourInspect(tourSample("Push")) into tPI
   put 0 into tIndex
   repeat for each item tSection in kButtonSections
      put tourInspectorSection(tPI, tSection) into tShown
      if tShown is not tSection then
         tourRecord "INFO" && tPI && "has no section" && tSection && "(it shows" && tShown & ")"
         next repeat
      end if
      add 1 to tIndex
      tourShotStack tPI, "05-inspector-button-" & tIndex & "-" & tourFileName(tSection)
   end repeat
end tour_inspector

on tour_inspector_text
   local tPI
   put tourInspect(tourSample("Text")) into tPI
   get tourInspectorSection(tPI, "Text")
   tourShotStack tPI, "06-inspector-field-text"
end tour_inspector_text

on tour_inspector_graphic
   local tPI
   put tourInspect(tourSample("Box")) into tPI
   get tourInspectorSection(tPI, "Colors")
   tourShotStack tPI, "07-inspector-graphic-colors"
end tour_inspector_graphic

on tour_inspector_multiple
   local tPI
   put tourInspect(tourSample("Push") & return & tourSample("Text") & return & tourSample("Box")) into tPI
   get tourInspectorSection(tPI, "Colors")
   tourShotStack tPI, "08-inspector-multiple-colors"
end tour_inspector_multiple

on tour_tooltip_inspector
   local tPI, tControl, tError
   put tourInspect(tourSample("Push")) into tPI
   get tourInspectorSection(tPI, "Colors")
   try
      put the long id of field "rowlabel" of group "Text fill" of stack tPI into tControl
   catch tError
      put empty into tControl
   end try
   if tControl is empty or the tooltip of tControl is empty then put tourObjectWithTooltip(tPI) into tControl
   if tControl is empty then throw "no control of" && tPI && "has a tooltip"
   tourRecord "INFO tooltip" && the short name of tControl & ":" && tourJoin(the tooltip of tControl)
   tourOnScreen tPI
   tourHover tControl, tPI
   tourShotAround tControl, tPI, "09-tooltip-inspector"
   tourMouseAway
   tourCloseInspectors
end tour_tooltip_inspector

on tour_script_editor
   local tSE
   revIDEEditScriptOfObject tourSample("Push")
   tourWait 2000
   put tourStackNamed("revNewScriptEditor") into tSE
   if tSE is empty then throw "no script editor opened:" && tourJoin(the openStacks)
   tourShotStack tSE, "10-script-editor"
   close stack tSE
end tour_script_editor

-- The Search Results pane, as Find All of the Find and Replace dialog
-- fills it: the matches of "mouse" in the scripts of the sample's card
on tour_script_editor_search
   local tSE
   revIDEEditScriptOfObject tourSample("Push")
   tourWait 2000
   put tourStackNamed("revNewScriptEditor") into tSE
   if tSE is empty then throw "no script editor opened:" && tourJoin(the openStacks)
   send "revSEFindAll" && quote & "mouse" & quote & ", false, false, false, true," && quote & "card" & quote to stack tSE
   tourWait 2000
   tourShotStack tSE, "10-script-editor-search"
   close stack tSE
end tour_script_editor_search

on tour_message_box
   revIDEOpenPalette "message box"
   tourWait 800
   tourShotStack revIDEPaletteToStackName("message box"), "11-message-box"
   -- a palette, in front of the windows of the later steps
   close stack revIDEPaletteToStackName("message box")
end tour_message_box

-- With the sample's button shown in it, as Show In Project Browser does:
-- the rows of a stack, a card and controls, with their icons
on tour_project_browser
   local tStack, tButton
   put tourSample("Push") into tButton
   put revIDEPaletteToStackName("project browser") into tStack
   revIDEOpenPalette "project browser"
   tourWait 1000
   revIDEShowInProjectBrowser tButton
   tourWait 1000
   if tStack is empty or there is not a stack tStack then throw "no stack for the palette project browser"
   if not the visible of stack tStack then throw "the palette project browser (" & tStack & ") is not visible"
   tourShotStack tStack, "12-project-browser"
   close stack tStack
end tour_project_browser

on tour_dictionary
   local tBefore, tNew
   put the openStacks into tBefore
   -- as Help > Dictionary does: the dictionary stack, or the documentation
   -- in a browser widget (cDictionaryDisplayMethod)
   send "tNewDictionaryDisplay" to stack "revMenuBar"
   repeat 40 times
      put tourNewStack(tBefore) into tNew
      if tNew is not empty then exit repeat
      tourWait 500
   end repeat
   if tNew is empty then throw "no dictionary window opened"
   tourWait 4000
   tourDictionaryEntry tNew, "try control structure.txt"
   tourShotStack tNew, "13-dictionary"
   close stack tNew
end tour_dictionary

-- The dictionary stack opens on an entry picked at random: it shows the
-- entry pFile instead, as a click on it in the list does, so that each
-- build's snapshot shows the same one. The entry has a parameter list,
-- whose bullets are UTF-8 in the file and showed as two or three wrong
-- characters each when the dictionary read it as native text, and a link
-- of one word and one of two in its description, which must be linked
-- whole: the link of two words was linked as "er[ror]".
command tourDictionaryEntry pStack, pFile
   local tPath, tText, tPhrase, tOffset, tLink, tStart
   if there is not a button "load" of card 1 of stack pStack \
         or there is not a field "path" of card 1 of stack pStack \
         or there is not a field "styledTextField" of card 1 of stack pStack then
      tourRecord "INFO" && pStack && "is not the dictionary stack: its entry stays"
      exit tourDictionaryEntry
   end if
   put the effective filename of stack pStack into tPath
   set the itemDelimiter to slash
   put item 1 to -2 of tPath & "/exports/xtalk/resaved/" & pFile into tPath
   set the itemDelimiter to comma
   if there is not a file tPath then throw "no dictionary entry" && tPath
   put tPath into field "path" of card 1 of stack pStack
   send "mouseDown" to button "load" of card 1 of stack pStack
   tourWait 1500
   if numToCodepoint(0x2022) is not in field "styledTextField" of card 1 of stack pStack then
      throw "the dictionary entry" && pFile && "shows no bullet: its text was not read as UTF-8"
   end if
   put the text of field "styledTextField" of card 1 of stack pStack into tText
   put "series of statements and handle any error messages" into tPhrase
   put offset(tPhrase, tText) into tOffset
   if tOffset is 0 then throw "the dictionary entry" && pFile && "does not say:" && tPhrase
   repeat for each item tLink in "statements,error messages"
      put tOffset + offset(tLink, tPhrase) - 1 into tStart
      if the textStyle of char tStart to tStart + the number of chars in tLink - 1 \
            of field "styledTextField" of card 1 of stack pStack is not "link" then
         throw "the dictionary entry" && pFile && "does not link" && quote & tLink & quote && "whole"
      end if
   end repeat
   tourRecord "INFO dictionary entry" && pFile
end tourDictionaryEntry

on tour_preferences
   local tStack, tPane, tIndex
   put revIDEPaletteToStackName("preferences") into tStack
   revIDEOpenPalette "preferences"
   tourWait 1500
   if there is not a stack tStack or not the visible of stack tStack then throw "Preferences did not open"
   -- each pane, as a click on its name in the list on the left does
   put 0 into tIndex
   repeat for each line tPane in the text of field "Menu" of stack tStack
      if tPane is empty then next repeat
      add 1 to tIndex
      dispatch "revPrefsGoSection" to stack tStack with tPane
      tourWait 700
      tourShotStack tStack, "14-preferences-" & format("%02d", tIndex) & "-" & tourFileName(tPane)
   end repeat
   close stack tStack
end tour_preferences

on tour_standalone_settings
   local tStack, tFile, tCards, tCard, tIndex, tDefault, i
   -- the settings are for a saved stack
   go stack kSample
   put specialFolderPath("temporary") & "/oxt_tour_sample.oxtstack" into tFile
   save stack kSample as tFile
   revIDEStandaloneSettingsForStack the long id of stack kSample
   put "revStandaloneSettings" into tStack
   tourWait 2000
   if there is not a stack tStack or not the visible of stack tStack then throw "the Standalone Settings did not open"
   -- each card, as a click on its button at the top does
   repeat with i = 1 to the number of buttons of group "cards" of stack tStack
      if the visible of button i of group "cards" of stack tStack then
         put the short name of button i of group "cards" of stack tStack & return after tCards
      end if
   end repeat
   put 0 into tIndex
   repeat for each line tCard in tCards
      add 1 to tIndex
      put the defaultStack into tDefault
      set the defaultStack to tStack
      dispatch "navigateToCard" to stack tStack with tCard
      set the defaultStack to tDefault
      tourWait 700
      tourShotStack tStack, "15-standalone-" & format("%02d", tIndex) & "-" & tourFileName(tCard)
   end repeat
   close stack tStack
end tour_standalone_settings

on tour_menu_builder
   tourPalette "menu builder", "16-menu-builder", 1500
end tour_menu_builder

on tour_extension_manager
   tourPalette "extension manager", "17-extension-manager", 2500
end tour_extension_manager

on tour_extension_builder
   tourPalette "extension builder", "18-extension-builder", 2000
end tour_extension_builder

on tour_message_watcher
   tourPalette "message watcher", "19-message-watcher", 1500
end tour_message_watcher

on tour_search
   tourPalette "search", "20-search", 1500
end tour_search

on tour_object_library
   -- with Development > Object Library, which also selects the Objects tab
   -- (the stack was saved with the Images tab selected)
   dispatch "revMenubarDevelopmentMenuPick" to stack "revMenuBar" with "Object Library"
   tourWait 1500
   tourShotStack "revImageLibrary", "22-object-library"
   close stack "revImageLibrary"
end tour_object_library

on tour_navigator
   local tBefore, tNew
   put the openStacks into tBefore
   -- as Tools > Card Navigator does
   send "tOpenNavigator" to stack "revMenuBar"
   tourWait 1500
   put tourNewStack(tBefore) into tNew
   if tNew is empty then throw "no Card Navigator opened"
   tourShotStack tNew, "23-navigator"
   close stack tNew
end tour_navigator

on tour_about
   local tBefore, tNew
   put the openStacks into tBefore
   -- as Help > About does
   send "tOpenAbout" to stack "revMenuBar"
   tourWait 2000
   put tourNewStack(tBefore) into tNew
   if tNew is empty then throw "no About window opened"
   tourShotStack tNew, "24-about"
   close stack tNew
end tour_about

on tour_answer
   send "tourShotDialog" && quote & "25-answer" & quote to me in 1500 milliseconds
   answer warning "A message from the screenshot tour." & return & "Second line." with "Cancel" and "OK"
end tour_answer

on tour_ask
   send "tourShotDialog" && quote & "26-ask" & quote to me in 1500 milliseconds
   ask question "A question from the screenshot tour:" with "An answer"
end tour_ask

-- The icon chooser of the inspector's icon properties, which opens it as
-- a sheet; here a palette, so that the tour need not wait on it
on tour_icon_chooser
   palette stack "revIconChooser"
   tourWait 1000
   tourShotStack "revIconChooser", "27-icon-chooser"
   close stack "revIconChooser"
end tour_icon_chooser

on tour_screen_end
   tourShotScreen "99-screen-end"
end tour_screen_end

----------------------------------------------------------------
-- Helpers

-- Opens a palette, snapshots it after pWait milliseconds and closes it
command tourPalette pPalette, pFile, pWait
   local tStack
   put revIDEPaletteToStackName(pPalette) into tStack
   revIDEOpenPalette pPalette
   tourWait pWait
   if tStack is empty or there is not a stack tStack then throw "no stack for the palette" && pPalette
   if not the visible of stack tStack then throw "the palette" && pPalette && "(" & tStack & ") is not visible"
   tourShotStack tStack, pFile
   close stack tStack
end tourPalette

-- The user's stack the inspector and the editors look at: the usual
-- controls, none with colours of its own
function tourSampleStack
   local tDefault
   if there is a stack kSample then return the long id of stack kSample
   put the defaultStack into tDefault
   lock screen
   lock messages
   create stack kSample
   set the rect of it to "220,140,700,520"
   set the defaultStack to kSample
   create button "Push"
   set the rect of it to "20,20,140,46"
   set the script of it to "on mouseUp pButton" & return & \
         "   -- a comment" & return & \
         "   put " & quote & "a string" & quote & " into tText" & return & \
         "   if pButton is 1 then answer tText" & return & \
         "end mouseUp"
   create button "Default"
   set the rect of it to "160,20,280,46"
   set the default of it to true
   create button "Off"
   set the rect of it to "300,20,420,46"
   set the enabled of it to false
   create button "Check"
   set the style of it to "checkbox"
   set the rect of it to "20,60,140,80"
   set the hilite of it to true
   create button "Radio"
   set the style of it to "radioButton"
   set the rect of it to "160,60,280,80"
   set the hilite of it to true
   create button "Option"
   set the style of it to "menu"
   set the menuMode of it to "option"
   set the text of it to "Choice one" & return & "Choice two"
   set the label of it to "Choice one"
   set the rect of it to "300,58,440,82"
   create field "Text"
   set the rect of it to "20,96,220,176"
   set the text of it to "Text in a field." & return & "A second line."
   create field "List"
   set the listBehavior of it to true
   set the vScrollbar of it to true
   set the rect of it to "240,96,440,176"
   set the text of it to "One" & return & "Two" & return & "Three" & return & "Four" & return & "Five" & return & "Six"
   set the hilitedLine of it to 2
   create scrollbar "Scroll"
   set the rect of it to "20,192,220,208"
   set the endValue of it to 100
   set the thumbPosition of it to 30
   create scrollbar "Progress"
   set the style of it to "progress"
   set the rect of it to "240,190,440,210"
   set the endValue of it to 100
   set the thumbPosition of it to 60
   create button "Tabs"
   set the style of it to "menu"
   set the menuMode of it to "tabbed"
   set the text of it to "First" & return & "Second"
   set the rect of it to "20,224,220,330"
   create graphic "Box"
   set the style of it to "rectangle"
   set the rect of it to "240,230,440,330"
   set the opaque of it to true
   create field "Label"
   set the rect of it to "240,340,440,362"
   set the lockText of it to true
   set the showBorder of it to false
   set the opaque of it to false
   set the text of it to "A label field"
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

-- Selects the objects pObjects (long ids, one a line) and opens the
-- inspector on them, as clicking them with the Pointer tool does; returns
-- the name of the inspector's stack
function tourInspect pObjects
   local tPI, tError
   tourCloseInspectors
   go stack kSample
   revIDESelectObjects pObjects
   revIDEInspectObjects pObjects
   tourWait 1500
   try
      put revIDEInspectorForObject(line 1 of pObjects) into tPI
   catch tError
      put empty into tPI
   end try
   if tPI is not empty and exists(tPI) then
      put the short name of tPI into tPI
   else
      put tourStackNamed("revPropertyInspector") into tPI
   end if
   if tPI is empty then throw "no inspector opened"
   return tPI
end tourInspect

command tourCloseInspectors
   local tStack
   repeat for each line tStack in the openStacks
      if tStack begins with "revPropertyInspector" then close stack tStack
   end repeat
   revIDEDeselectAll
   tourWait 300
end tourCloseInspectors

-- Shows the section pSection ("Colors", "Text", ...: the label of its
-- icon in the inspector's header) of the inspector pStack, as a click on
-- the icon does (revinspectorbehavior.livecodescript), and returns the
-- section it shows (the first one when the object has no pSection)
function tourInspectorSection pStack, pSection
   local tShown
   if pStack is empty or there is not a stack pStack then throw "no inspector stack"
   dispatch "inspectorSectionChanged" to stack pStack with pSection
   tourWait 1000
   dispatch function "inspectorSectionGetName" to stack pStack
   put the result into tShown
   tourRecord "INFO" && pStack && "section" && tShown
   return tShown
end tourInspectorSection

-- The first visible open stack whose name starts with pPrefix
function tourStackNamed pPrefix
   local tStack
   repeat for each line tStack in the openStacks
      if tStack begins with pPrefix and the visible of stack tStack then return tStack
   end repeat
   return empty
end tourStackNamed

-- A visible stack in the openStacks that was not in pBefore
function tourNewStack pBefore
   local tStack
   repeat for each line tStack in the openStacks
      if tStack is not among the lines of pBefore and tStack is not "oxt_ui_tour" and the visible of stack tStack then return tStack
   end repeat
   return empty
end tourNewStack

-- The control named pName on the current card of the stack pStack
function tourControlNamed pStack, pName
   local tCard, i
   if there is not a stack pStack then return empty
   put the long id of this card of stack pStack into tCard
   repeat with i = 1 to the number of controls of tCard
      if the short name of control i of tCard is pName then return the long id of control i of tCard
   end repeat
   return empty
end tourControlNamed

-- A control of the stack pStack (its current card) with a tooltip, shown
-- and in the window
function tourObjectWithTooltip pStack
   local tCard, tControl, tOwner, tShown, i
   put the long id of this card of stack pStack into tCard
   repeat with i = 1 to the number of controls of tCard
      put the long id of control i of tCard into tControl
      if the tooltip of tControl is empty then next repeat
      put the visible of tControl into tShown
      put the long id of the owner of tControl into tOwner
      repeat while tShown and word 1 of tOwner is "group"
         put the visible of tOwner into tShown
         put the long id of the owner of tOwner into tOwner
      end repeat
      if not tShown then next repeat
      if item 1 of the loc of tControl < 0 or item 2 of the loc of tControl < 0 then next repeat
      if item 1 of the loc of tControl > the width of stack pStack or item 2 of the loc of tControl > the height of stack pStack then next repeat
      return tControl
   end repeat
   return empty
end tourObjectWithTooltip

-- Where pObject (a control of the stack pStack) is on the screen
function tourScreenLoc pObject, pStack
   return (item 1 of the loc of pObject + the left of stack pStack) & "," & \
         (item 2 of the loc of pObject + the top of stack pStack)
end tourScreenLoc

-- Moves the pointer onto pObject (of the stack pStack) and waits for its
-- tooltip
command tourHover pObject, pStack
   local tLoc
   -- the screen unlocked, as when the IDE is idle: on Linux a locked screen
   -- kept the Inspector's tooltip from showing
   tourUnlockScreen "hover over" && the short name of pObject
   put tourScreenLoc(pObject, pStack) into tLoc
   -- from just beside it, so that the engine sees the pointer arrive
   tourMoveMouse (item 1 of tLoc - 3) & "," & (item 2 of tLoc - 3)
   tourWait 200
   tourMoveMouse tLoc
   tourWait 2500
end tourHover

command tourMouseAway
   tourMoveMouse (item 3 of the screenRect - 5) & "," & (item 4 of the screenRect - 5)
   tourWait 600
end tourMouseAway

command tourMoveMouse pLoc
   local tCommand
   set the screenMouseLoc to pLoc
   if the platform is "MacOS" then
      -- warping the pointer makes no event on macOS: post a mouse moved one
      put "osascript -l JavaScript -e 'ObjC.import(" & quote & "CoreGraphics" & quote & "); " & \
            "$.CGEventPost(0, $.CGEventCreateMouseEvent(null, 5, {x: " & item 1 of pLoc & ", y: " & item 2 of pLoc & "}, 0));'" into tCommand
      get shell(tCommand)
      if it is not empty then tourRecord "INFO osascript" && tourJoin(it)
   end if
end tourMoveMouse

command tourWait pMilliseconds
   wait pMilliseconds milliseconds with messages
end tourWait

-- Snapshot of the window of pStack with its frame, on screen
command tourShotStack pStack, pFile
   if pStack is empty or there is not a stack pStack then throw "no stack" && pStack
   if the mode of stack pStack is 0 or not the visible of stack pStack then throw "the stack" && pStack && "is not open"
   tourOnScreen pStack
   -- with the title, which Linux in CI, with no window manager, doesn't show
   tourRecord "INFO" && pFile && "stack" && pStack && "rect" && the rect of stack pStack && "effective" && the effective rect of stack pStack && "title" && quote & the title of stack pStack & quote
   tourShotRect the effective rect of stack pStack, pFile
end tourShotStack

-- The screens of the runners are small (1024 by 768 on Windows and the
-- Apple silicon Mac, 1440 by 900 on Linux), and a tall window, such as
-- the Standalone Settings on its Android card, went past the bottom: it
-- moves up, at most to the top of the screen, so that all of it, or as
-- much as fits, is in the snapshot. A window over the Tools palette, as
-- the Inspector and the answer and ask dialogs open, moves to the right
-- of it, as far as the screen allows: on Windows the palette is a system
-- window (tfixwindowsToolsDrag in revtools.livecodescript), in front of
-- every other window, and hid their left side
command tourOnScreen pStack
   local tScreen, tRect, tUp, tTools, tRight
   put the working screenRect into tScreen
   put the effective rect of stack pStack into tRect
   put min(item 4 of tRect - item 4 of tScreen, item 2 of tRect - item 2 of tScreen) into tUp
   if tUp > 0 then
      set the top of stack pStack to the top of stack pStack - tUp
      tourWait 300
   end if
   if pStack is "revTools" or there is not a stack "revTools" then exit tourOnScreen
   if the mode of stack "revTools" is 0 or not the visible of stack "revTools" then exit tourOnScreen
   put the rect of stack "revTools" into tTools
   put the rect of stack pStack into tRect
   if item 1 of tRect < item 3 of tTools and item 3 of tRect > item 1 of tTools \
         and item 2 of tRect < item 4 of tTools and item 4 of tRect > item 2 of tTools then
      -- 20 pixels clear, for the borders round both windows on Windows
      put min(item 3 of tTools + 20 - item 1 of tRect, \
            item 3 of tScreen - item 3 of the effective rect of stack pStack) into tRight
      if tRight > 0 then
         set the left of stack pStack to the left of stack pStack + tRight
         tourWait 300
      end if
   end if
end tourOnScreen

-- Snapshot of the screen around pObject (of the stack pStack), big enough
-- for its tooltip
command tourShotAround pObject, pStack, pFile
   local tRect
   put tourScreenLoc(pObject, pStack) into tRect
   put item 1 of tRect - 40, item 2 of tRect - 40, item 1 of tRect + 420, item 2 of tRect + 120 into tRect
   tourShotRect tRect, pFile
end tourShotAround

command tourShotScreen pFile
   local tRect, tWidth, tHeight
   put the screenRect into tRect
   put (item 3 of tRect - item 1 of tRect) div 2 into tWidth
   put (item 4 of tRect - item 2 of tRect) div 2 into tHeight
   tourShotRect tRect, pFile, tWidth & "," & tHeight
end tourShotScreen

-- A handler of the IDE that locked the screen and stopped on an error, or
-- left the unlock to the end of the event, leaves the screen locked until
-- no handler runs, which for a user is the next moment the IDE is idle,
-- but here not until the tour ends: unlocked, so that the windows show
-- what they hold
command tourUnlockScreen pWhat
   if the lockScreen then
      tourRecord "INFO" && pWhat & ": the screen was locked"
      repeat while the lockScreen
         unlock screen
      end repeat
      tourWait 300
   end if
end tourUnlockScreen

command tourShotRect pRect, pFile, pSize
   local tFile, tScreen
   tourUnlockScreen pFile
   put the screenRect into tScreen
   -- on the screen
   put max(item 1 of pRect, item 1 of tScreen) into item 1 of pRect
   put max(item 2 of pRect, item 2 of tScreen) into item 2 of pRect
   put min(item 3 of pRect, item 3 of tScreen) into item 3 of pRect
   put min(item 4 of pRect, item 4 of tScreen) into item 4 of pRect
   if item 3 of pRect <= item 1 of pRect or item 4 of pRect <= item 2 of pRect then throw "nothing of" && pFile && "is on the screen"
   put sOut & slash & pFile & ".png" into tFile
   if pSize is empty then
      export snapshot from rect pRect to file tFile as PNG
   else
      export snapshot from rect pRect at size pSize to file tFile as PNG
   end if
   if there is not a file tFile then throw "the snapshot" && pFile && "was not written (" & the result & ")"
   add 1 to sCount
   tourRecord "SHOT" && pFile & ".png" && pRect
end tourShotRect

-- "Files & Memory" -> "files-memory"
function tourFileName pName
   local tName, tChar
   repeat for each char tChar in toLower(pName)
      if tChar is among the chars of "abcdefghijklmnopqrstuvwxyz0123456789" then
         put tChar after tName
      else if the last char of tName is not "-" then
         put "-" after tName
      end if
   end repeat
   if the last char of tName is "-" then delete the last char of tName
   if the first char of tName is "-" then delete the first char of tName
   return tName
end tourFileName

-- A step has run for 20 seconds: the screen and the open stacks, and any
-- modal dialog it waits on is closed
on tourWatchdog pStep
   local tError
   add 1 to sWatchdogCount
   tourRecord "INFO" && pStep && "still running after" && 20 * sWatchdogCount && "s; open stacks:" && tourJoin(the openStacks)
   try
      tourShotScreen "zz-" & pStep & "-" & sWatchdogCount
   catch tError
   end try
   tourCloseDialogs true
   if sWatchdogCount < 5 then
      send "tourWatchdog" && quote & pStep & quote to me in 20 seconds
      put the result into sWatchdog
   end if
end tourWatchdog

-- Snapshot of the modal dialog on top, then closes it
on tourShotDialog pFile
   local tStack, tName, tError
   try
      -- the dialog open now: both stay loaded once used, hidden
      put line 1 of the openStacks into tStack
      repeat for each item tName in "Answer Dialog,Ask Dialog"
         if there is a stack tName and the mode of stack tName is not 0 and the visible of stack tName then put tName into tStack
      end repeat
      tourShotStack tStack, pFile
   catch tError
      tourRecord "INFO" && pFile && "FAILED" && tourJoin(tError)
   end try
   tourCloseDialogs
end tourShotDialog

-- Closes the answer and ask dialogs, and with pAnyModal every modal or
-- sheet stack
command tourCloseDialogs pAnyModal
   local tName
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
   put textEncode(pLine & lf, "UTF-8") after URL ("binfile:" & sLog)
end tourRecord

function tourJoin pText
   replace return with " | " in pText
   return pText
end tourJoin
