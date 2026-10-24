script "oxt_ui_tour"
-- Screenshots of the IDE's own windows, run inside the real IDE by
-- tools/ci/ui_tour.py, which names this file on the command line: the
-- engine opens it once the IDE has started (home.livecodescript,
-- revInternal__openStack).
--
-- It waits for the IDE to finish starting, records the system's
-- appearance, which the IDE follows, then opens the IDE's
-- windows one by one: the Tools palette (also in its modern look, at its
-- first size, wide, with its names and with Large Icons, and checks of how that look
-- behaves: tools-modern-check, -sizes, -use and -switch), a stack of
-- the user with the usual controls (and stacks opened with their title
-- bars above the screen, which the IDE moves where they can be dragged:
-- title-bar), the Property Inspector (each section for a button, the
-- Text section of a field, the Colors section of a graphic and of several
-- objects, and the graphic's Fill gradient popup, which must open beside
-- the Inspector and off the graphic), the Script Editor (and its results
-- of a Find All), the
-- Message Box, the Project Browser, LiveCode's Dictionary (with the
-- entries of both languages and of the extensions, which its page
-- reports) and its guides, the text dictionary, each pane of Preferences, each card
-- of the Standalone Settings (and mergJSON, which the IDE loads from its
-- Ext folder: ext-mergjson), the Menu Builder, the
-- Extension Manager and Builder, the Message Watcher, Search, the Object
-- Library, the Card Navigator, the About window, the Release Notes
-- window, the IDE's own dialog in the look of Learn (revIDEKitDialog),
-- Learn's lessons, the xTalk Academy (its courses, and a lesson with an
-- example run in its playground), the xTalk Assistant's window, Settings
-- and Memory (no key, no request: only the windows), xTalk Chat before it
-- goes online, the answer and ask dialogs and the icon chooser. Not the Start Center: OpenXTalk Lite 1.15
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

constant kSteps = "appearance,screen,tools,tooltip-tools,hover-tools,tools-modern,tools-modern-wide,tools-modern-names,tools-modern-large,tools-modern-check,tools-modern-sizes,tools-modern-use,tools-modern-switch,menubar,sample,title-bar,inspector,inspector-text,inspector-graphic,inspector-gradient,inspector-multiple,tooltip-inspector,script-editor,script-editor-search,message-box,project-browser,dictionary,guides,text-dictionary,preferences,standalone-settings,ext-mergjson,menu-builder,extension-manager,extension-builder,message-watcher,search,object-library,navigator,about,release-notes,home,kit-dialog,learn,academy,xtalk-assistant,xtalk-chat,answer,ask,icon-chooser,screen-end"
constant kSample = "OXT Tour Sample"
-- The inspector's sections for a button, as the icons in its header name
-- them (a section the object has not is skipped)
constant kButtonSections = "Basic,Icons,Colors,Text,Position,Effects,Custom,Advanced"
-- The learning windows new in 0.2.7 and the plugins' windows (the steps
-- learn, academy, xtalk-assistant and xtalk-chat)
constant kLearn = "revLearn"
constant kAcademy = "revAcademy"
constant kXtaMain = "org.openxtalk.plugin.xtalkassistant"
constant kXtaWindow = "revXTalkAssistant"
constant kXtaSettings = "revXTalkAssistantSettings"
constant kXtaMemory = "revXTalkAssistantMemory"
constant kChatMain = "org.openxtalk.plugin.xtalkchat"
constant kChatCore = "org.openxtalk.plugin.xtalkchat-core"
constant kChatWindow = "revXTalkChat"

local sOut, sLog, sOnly, sCount, sStarted, sWatchdog, sWatchdogCount, sReport

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
   -- The Tools palette opens in its modern look, the default; the steps
   -- before the modern look's take it in its classic look, as they always
   -- have, and the modern look's steps turn it on themselves
   tourRecord "INFO tools look at start" && quote & revIDEGetPreference("revTools_look") & quote
   tourToolsClassic
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
   -- The IDE follows the system's appearance as OpenXTalk Lite 1.15 does
   tourWait 1000
   tourRecord "INFO systemAppearance" && the systemAppearance
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

-- The Tools palette in its modern look (Tools > Modern Tools Palette):
-- at the size it first opens at, made wide, and wide with the names of
-- its objects. Each step puts the classic look back, which the other
-- steps expect. A release whose palette has no modern look is noted and
-- skipped.
on tour_tools_modern
   if tourToolsModern(empty, false) then
      tourShotStack "revTools", "01-tools-modern"
   end if
   tourToolsClassic
end tour_tools_modern

on tour_tools_modern_wide
   if tourToolsModern(340, false) then
      tourShotStack "revTools", "01-tools-modern-wide"
   end if
   tourToolsClassic
end tour_tools_modern_wide

on tour_tools_modern_names
   if tourToolsModern(380, true) then
      tourShotStack "revTools", "01-tools-modern-names"
   end if
   tourToolsClassic
end tour_tools_modern_names

-- Large Icons, chosen in the palette's menu as a user does: the icons and
-- the tiles half as large again, and the palette as wide as two columns
-- need (a palette without the option is snapshotted as it is)
on tour_tools_modern_large
   if tourToolsModern(empty, false) then
      revIDESetPreference "revTools_modernLarge", false
      dispatch "tmMenuPick" to stack "revTools" with "Large Icons"
      tourWait 500
      tourRecord "INFO tools-modern-large" && revIDEGetPreference("revTools_modernLarge") && "rect" && the rect of stack "revTools"
      tourShotStack "revTools", "01-tools-modern-large"
      revIDESetPreference "revTools_modernLarge", false
   end if
   tourToolsClassic
end tour_tools_modern_large

-- Turns the modern look on, at its first size or pWidth wide, with or
-- without names; false when the palette has no modern look
function tourToolsModern pWidth, pNames
   revIDEOpenPalette "tools"
   tourWait 300
   dispatch function "tmIsModern" to stack "revTools"
   if it is not "handled" then
      tourRecord "INFO tools-modern: this palette has no modern look"
      return false
   end if
   revIDESetPreference "revTools_modernSize", empty
   revIDESetPreference "revTools_modernNames", pNames
   revIDESetPreference "revTools_modernFolded", empty
   revIDESetPreference "revTools_modernShow", empty
   revIDESetPreference "revTools_look", "modern"
   tourWait 800
   if pWidth is a number then
      set the width of stack "revTools" to pWidth
      set the left of stack "revTools" to item 1 of the working screenRect + 10
      tourWait 500
   end if
   tourRecord "INFO tools-modern rect" && the rect of stack "revTools" && "resizable" && the resizable of stack "revTools"
   return true
end tourToolsModern

command tourToolsClassic
   -- (an empty preference is the modern look, the default)
   if revIDEGetPreference("revTools_look") is not "classic" then
      revIDESetPreference "revTools_look", "classic"
      tourWait 500
   end if
end tourToolsClassic

-- Checks of the modern look, beside its snapshots: what it builds keeps
-- the classic look's names and properties (which the classic mouseDown,
-- the tutorial and Home use), its tiles fit the window at every size,
-- the filter, the folds, the sections, the names, choosing a tool and
-- making an object work, and switching back gives the classic look as it
-- was. Each check that fails is listed, and the step then fails.
-- A release whose palette has no modern look is noted and skipped.
local sTmClassic, sTmClassicPrefs, sTmChecks, sTmFails

on tour_tools_modern_check
   local tModern, tName, tKey, tLine, tCount
   if not tourTmStart("tools-modern-check") then exit tour_tools_modern_check
   -- the classic look, as the other steps leave it
   tourToolsClassic
   put tourTmTiles() into sTmClassic
   put revIDEGetPreference("revTools_show") & "|" & revIDEGetPreference("revTools_columns") into sTmClassicPrefs
   tourTmCheck the number of elements of sTmClassic > 10, "the classic look has its tiles (" & the number of elements of sTmClassic & ")"
   tourTmCheck tourTmNamed("tmHeader") is empty, "the classic look has no modern controls"

   if tourToolsModern(empty, false) is not true then throw "the modern look did not turn on"
   tourTmCheck the resizable of stack "revTools", "the modern look is resizable"
   tourTmCheck the minWidth of stack "revTools" >= 96 and the minHeight of stack "revTools" >= 160, \
         "the modern look has a smallest size (" & the minWidth of stack "revTools" & "," & the minHeight of stack "revTools" & ")"
   repeat for each item tName in "tmHeader,tmSearch,tmGrip,tmMenuBtn,tmFilter,contents,images,runedit,tool_hover,tool_hilite"
      tourTmCheck tourTmNamed(tName) is not empty, "the modern look has its" && tName
   end repeat
   repeat for each item tName in "toolsOVERRIDEmenu,divHeaderVectorShapes,divHeaderVectorTools,divHeaderPaintTools"
      tourTmCheck tourTmNamed(tName) is empty, "the classic" && tName && "is gone in the modern look"
   end repeat
   -- the sections it shows at first: widgets, controls and shapes
   repeat for each item tName in "widget,classic,graphic"
      tourTmCheck tourTmGroup(tName) is not empty, "the modern look shows the section" && tName && "at first"
   end repeat
   repeat for each item tName in "graphictools,paint"
      tourTmCheck tourTmGroup(tName) is empty, "the modern look hides the section" && tName && "at first"
   end repeat
   -- the same names and properties as the classic look's
   put tourTmTiles() into tModern
   put 0 into tCount
   repeat for each key tKey in tModern
      if sTmClassic[tKey] is empty then next repeat
      add 1 to tCount
      tourTmCheck item 2 to -1 of tModern[tKey] is item 2 to -1 of sTmClassic[tKey], \
            tKey && "keeps its classic properties (" & item 2 to -1 of tModern[tKey] & " / " & item 2 to -1 of sTmClassic[tKey] & ")"
   end repeat
   repeat for each key tKey in sTmClassic
      if item 1 of sTmClassic[tKey] is among the items of "runedit,classic,graphic" then
         tourTmCheck tModern[tKey] is not empty, tKey && "of the classic section" && item 1 of sTmClassic[tKey] && "is in the modern look"
      end if
   end repeat
   tourTmCheck tCount >= 20, tCount && "tiles compared with the classic look's"
   repeat for each key tKey in tModern
      if item 1 of tModern[tKey] is "widget" then
         tourTmCheck tourTmNamed("tmIcon:" & tKey) is not empty or the icon of tourTmNamed(tKey) is not 0, "the widget" && tKey && "has an icon"
      end if
   end repeat
   -- a shape's icon is drawn, sharp at any size, where the classic look's
   -- is a picture of 12 to 14 points
   repeat for each key tKey in tModern
      if item 1 of tModern[tKey] is "graphic" then
         tourTmCheck tourTmShapeIcon(tKey) > 14, "the shape" && tKey && "has a drawn icon (" & tourTmShapeIcon(tKey) & ")"
      end if
   end repeat
   -- the icon images, which Home reads (the Browse tool's as a cursor)
   tourTmCheck tourTmNamed("com.livecode.tool.Browse.icon.png") is not empty, "the Browse tool's icon image is there"
   -- the tutorial's calls
   dispatch function "toolObjectName" to stack "revTools" with "Create Button"
   put the result into tName
   tourTmCheck tourTmNamed(tName) is not empty, "toolObjectName gives a tile (" & tName & ")"
   dispatch "disableTools" to stack "revTools"
   tourTmCheck the cDisabled of tourTmNamed("com.livecode.tool.Pointer") is true and \
         the cDisabled of tourTmNamed("com.livecode.interface.classic.Button") is true, "disableTools disables the tiles"
   dispatch "enableTools" to stack "revTools"
   tourTmCheck the cDisabled of tourTmNamed("com.livecode.tool.Pointer") is not true and \
         the cDisabled of tourTmNamed("com.livecode.interface.classic.Button") is not true, "enableTools enables them again"
   dispatch "isolateTool" to stack "revTools" with "com.livecode.interface.classic.Field"
   tourTmCheck the cDisabled of tourTmNamed("com.livecode.interface.classic.Field") is not true and \
         the cDisabled of tourTmNamed("com.livecode.interface.classic.Button") is true, "isolateTool leaves one tile enabled"
   dispatch "enableTools" to stack "revTools"
   tourTmLayoutOK "at its first size"
   tourTmFinish "tools-modern-check"
end tour_tools_modern_check

-- Sizes: the tiles fit the window at each width, in more columns when
-- wider; what doesn't fit its height scrolls; the size is kept
on tour_tools_modern_sizes
   local tW, tCols, tLast, tMax, tTop, tShape, tWidget
   if not tourTmStart("tools-modern-sizes") then exit tour_tools_modern_sizes
   if tourToolsModern(empty, false) is not true then throw "the modern look did not turn on"
   put 0 into tLast
   repeat for each item tW in "96,120,170,240,400,700"
      set the rect of stack "revTools" to 40, 120, 40 + tW, 120 + 520
      tourWait 150
      tourTmLayoutOK "at" && the width of stack "revTools" & "x" & the height of stack "revTools"
      put tourTmColumns("classic") into tCols
      tourTmCheck tCols >= tLast, "the controls take as many columns or more when wider (" & tCols && "at" && tW & ")"
      put tCols into tLast
   end repeat
   tourTmCheck tLast >= 6, "a wide palette shows its controls in many columns (" & tLast & ")"
   -- names: one column of names when narrow, more when wide
   revIDESetPreference "revTools_modernNames", true
   set the rect of stack "revTools" to 40, 120, 40 + 170, 120 + 520
   tourWait 200
   tourTmLayoutOK "with names, narrow"
   tourTmCheck tourTmColumns("classic") is 1, "names in one column when narrow (" & tourTmColumns("classic") & ")"
   tourTmNamesWhole "narrow"
   -- the width of the names snapshot, where two long names were cut off
   set the rect of stack "revTools" to 40, 120, 40 + 390, 120 + 520
   tourWait 200
   tourTmLayoutOK "with names, at 390"
   tourTmNamesWhole "at 390"
   set the rect of stack "revTools" to 40, 120, 40 + 640, 120 + 520
   tourWait 200
   tourTmLayoutOK "with names, wide"
   tourTmNamesWhole "wide"
   tourTmCheck tourTmColumns("classic") >= 3, "names in columns when wide (" & tourTmColumns("classic") & ")"
   revIDESetPreference "revTools_modernNames", false
   -- short: it scrolls with the wheel, and no further than its end
   set the rect of stack "revTools" to 40, 120, 40 + 120, 120 + 200
   tourWait 200
   tourTmLayoutOK "short"
   tourTmCheck the visible of tourTmNamed("tmThumb"), "a short palette shows its scroll thumb"
   send "rawKeyDown 65308" to card 1 of stack "revTools"
   tourTmCheck the vScroll of tourTmNamed("contents") > 0, "the wheel scrolls it (" & the vScroll of tourTmNamed("contents") & ")"
   repeat 200 times
      send "rawKeyDown 65308" to card 1 of stack "revTools"
   end repeat
   put the vScroll of tourTmNamed("contents") into tMax
   tourTmCheck tMax > 0 and tMax < 4000, "it scrolls no further than its end (" & tMax & ")"
   put the bottom of tourTmNamed("contents") into tTop
   tourTmCheck tourTmLowestTile() <= tTop + 2 and tourTmLowestTile() >= tTop - 120, \
         "scrolled to its end, its last tile is at the bottom (" & tourTmLowestTile() && tTop & ")"
   repeat 200 times
      send "rawKeyDown 65309" to card 1 of stack "revTools"
   end repeat
   tourTmCheck the vScroll of tourTmNamed("contents") is 0, "it scrolls back to its top"
   -- tall: no thumb
   set the rect of stack "revTools" to 40, 120, 40 + 400, 120 + 600
   tourWait 200
   tourTmCheck not the visible of tourTmNamed("tmThumb"), "a palette tall enough shows no thumb"
   -- Large Icons, from the menu: the tiles and the drawn icons half as
   -- large again, still fitting, and back again
   revIDESetPreference "revTools_modernLarge", false
   set the rect of stack "revTools" to 40, 120, 40 + 260, 120 + 520
   tourWait 200
   put tourTmShapeIcon("com.livecode.interface.classic.OvalGraphic") into tShape
   put the width of widget 1 of tourTmGroup("widget") into tWidget
   dispatch "tmMenuPick" to stack "revTools" with "Large Icons"
   tourWait 300
   tourTmCheck revIDEGetPreference("revTools_modernLarge") is true, "the menu turns Large Icons on"
   tourTmLayoutOK "with Large Icons"
   tourTmCheck tShape > 14 and tourTmShapeIcon("com.livecode.interface.classic.OvalGraphic") is round(tShape * 1.5), \
         "with Large Icons a shape's icon is drawn half as large again (" & tShape && "and" && \
         tourTmShapeIcon("com.livecode.interface.classic.OvalGraphic") & ")"
   tourTmCheck the width of widget 1 of tourTmGroup("widget") is round(tWidget * 1.5), \
         "and a widget's icon (" & tWidget && "and" && the width of widget 1 of tourTmGroup("widget") & ")"
   dispatch "tmMenuPick" to stack "revTools" with "Large Icons"
   tourWait 300
   tourTmCheck revIDEGetPreference("revTools_modernLarge") is false and \
         tourTmShapeIcon("com.livecode.interface.classic.OvalGraphic") is tShape, "the menu turns Large Icons off again"
   tourTmLayoutOK "after Large Icons"
   -- the size is kept for the next time
   set the rect of stack "revTools" to 40, 120, 40 + 260, 120 + 420
   tourWait 1200
   tourTmCheck revIDEGetPreference("revTools_modernSize") is "260,420", "its size is kept (" & revIDEGetPreference("revTools_modernSize") & ")"
   revIDESetPreference "revTools_look", "classic"
   tourWait 400
   revIDESetPreference "revTools_look", "modern"
   tourWait 600
   tourTmCheck the width of stack "revTools" is 260 and the height of stack "revTools" is 420, \
         "it opens again at the size kept (" & the width of stack "revTools" & "," & the height of stack "revTools" & ")"
   tourTmFinish "tools-modern-sizes"
end tour_tools_modern_sizes

-- Use: the filter, a fold, the sections, choosing a tool, the pointer
-- over a tile, a double click making an object, the Tools menu
on tour_tools_modern_use
   local tAll, tShown, tObj, tStack, tCount, tShow, tTime
   if not tourTmStart("tools-modern-use") then exit tour_tools_modern_use
   if tourToolsModern(260, false) is not true then throw "the modern look did not turn on"
   set the height of stack "revTools" to 600
   tourWait 200
   put tourTmShownTiles() into tAll
   dispatch "tmSetFilter" to stack "revTools" with "button"
   put tourTmShownTiles() into tShown
   tourTmCheck tShown > 0 and tShown < tAll, "the filter keeps only what matches (" & tShown && "of" && tAll & ")"
   tourTmCheck the visible of tourTmNamed("com.livecode.interface.classic.Button") and \
         not the visible of tourTmNamed("com.livecode.interface.classic.Field"), "the filter shows Button and not Field"
   tourTmCheck the visible of tourTmNamed("tmFilterClear") and not the visible of tourTmNamed("tmFilterHint"), "a filter shows its clear button"
   tourTmLayoutOK "filtered"
   dispatch "tmSetFilter" to stack "revTools" with "zzqq"
   tourTmCheck tourTmShownTiles() is 0 and the visible of tourTmNamed("tmEmpty"), "nothing matching says so"
   tourTmClick tourTmNamed("tmFilterClear")
   tourTmCheck tourTmShownTiles() is tAll and not the visible of tourTmNamed("tmEmpty") and field "tmFilter" of stack "revTools" is empty, \
         "clearing the filter shows everything again"
   -- typing in the filter
   put "graph" into field "tmFilter" of stack "revTools"
   dispatch "textChanged" to field "tmFilter" of stack "revTools"
   tourTmCheck tourTmShownTiles() > 0 and tourTmShownTiles() < tAll, "typing in the filter filters (" & tourTmShownTiles() & ")"
   send "rawKeyDown 65307" to field "tmFilter" of stack "revTools"
   tourTmCheck tourTmShownTiles() is tAll, "Esc clears the filter"
   -- a fold
   tourTmClick tourTmNamed("tmCapHit:classic")
   tourTmCheck not the visible of tourTmGroup("classic") and "classic" is among the items of revIDEGetPreference("revTools_modernFolded"), "a caption folds its section"
   tourTmLayoutOK "folded"
   tourTmClick tourTmNamed("tmCapHit:classic")
   tourTmCheck the visible of tourTmGroup("classic") and "classic" is not among the items of revIDEGetPreference("revTools_modernFolded"), "and unfolds it"
   -- the sections from its menu (a rebuild of the palette, timed)
   put the milliseconds into tTime
   dispatch "tmMenuPick" to stack "revTools" with "Paint Tools"
   tourRecord "INFO tools-modern-use: a section shown in" && the milliseconds - tTime && "ms"
   dispatch "tmMenuPick" to stack "revTools" with "Vector Tools"
   tourTmCheck tourTmGroup("paint") is not empty and tourTmGroup("graphictools") is not empty, "the menu shows the paint and vector tools"
   tourTmLayoutOK "with every section"
   dispatch "tmMenuPick" to stack "revTools" with "Widgets"
   tourTmCheck tourTmGroup("widget") is empty, "the menu hides the widgets"
   dispatch "tmMenuPick" to stack "revTools" with "Widgets"
   tourTmCheck tourTmGroup("widget") is not empty, "and shows them again"
   tourTmCheck revIDEGetPreference("revTools_show") & "|" & revIDEGetPreference("revTools_columns") is sTmClassicPrefs, \
         "the classic look's settings are untouched (" & revIDEGetPreference("revTools_show") & ")"
   tourTmCheck not the lockScreen, "the screen is not left locked (" & the lockScreen & ")"
   -- choosing a tool lights its tile, and Run and Edit theirs
   tourTmClick tourTmNamed("com.livecode.tool.Pencil")
   tourWait 100
   tourTmCheck the tool is "pencil tool", "the Pencil tile chooses the pencil tool (" & the tool & ")"
   tourTmCheck the visible of tourTmNamed("tool_hilite") and the rect of tourTmNamed("tool_hilite") is the rect of tourTmNamed("com.livecode.tool.Pencil"), \
         "the Pencil tile is lit (" & the visible of tourTmNamed("tool_hilite") && the rect of tourTmNamed("tool_hilite") && the rect of tourTmNamed("com.livecode.tool.Pencil") & ")"
   choose browse tool
   tourWait 100
   tourTmCheck not the visible of tourTmNamed("tool_hilite"), "no tool tile is lit in Run mode"
   tourTmCheck the visible of tourTmNamed("tmSegHilite") and the rect of tourTmNamed("tmSegHilite") is the rect of tourTmNamed("com.livecode.tool.Browse"), \
         "Run is lit in Run mode (" & the visible of tourTmNamed("tmSegHilite") && the rect of tourTmNamed("tmSegHilite") && the rect of tourTmNamed("com.livecode.tool.Browse") & ")"
   choose pointer tool
   tourWait 100
   tourTmCheck the rect of tourTmNamed("tmSegHilite") is the rect of tourTmNamed("com.livecode.tool.Pointer"), "Edit is lit in Edit mode"
   -- the pointer over a tile
   put tourTmNamed("com.livecode.interface.classic.Field") into tObj
   send "mouseEnter" to tObj
   tourTmCheck the visible of tourTmNamed("tool_hover") and the rect of tourTmNamed("tool_hover") is the rect of tObj, "the tile under the pointer shows"
   send "mouseLeave" to tObj
   tourTmCheck not the visible of tourTmNamed("tool_hover"), "and stops showing when it leaves"
   -- a double click makes the object on the stack in front
   put "OXT Tour Tools Check" into tStack
   if there is a stack tStack then delete stack tStack
   create stack tStack
   set the rect of stack tStack to 500, 200, 900, 500
   go stack tStack
   tourWait 300
   put the number of fields of card 1 of stack tStack into tCount
   send "mouseDoubleUp 1" to tObj
   tourWait 300
   tourTmCheck the number of fields of card 1 of stack tStack is tCount + 1, "a double click on Field makes a field (" & tCount && "then" && the number of fields of card 1 of stack tStack & ")"
   delete stack tStack
   choose pointer tool
   -- Tools > Paint and Draw Tools
   if there is a stack "revMenuBar" then
      put tourTmGroup("paint") is not empty into tShow
      tourTmCheck tourTmMenuChecked("Paint and Draw Tools") is tShow, "Tools > Paint and Draw Tools is checked when the paint tools show"
      tourTmCheck tourTmMenuChecked("Modern Tools Palette") is true, "Tools > Modern Tools Palette is checked"
      dispatch "revMenubarToolsMenuPick" to stack "revMenuBar" with "paint and draw tools"
      tourTmCheck (tourTmGroup("paint") is not empty) is not tShow, "Tools > Paint and Draw Tools shows or hides the paint tools"
      tourTmCheck tourTmMenuChecked("Paint and Draw Tools") is not tShow, "and its check follows"
      dispatch "revMenubarToolsMenuPick" to stack "revMenuBar" with "paint and draw tools"
      tourTmCheck (tourTmGroup("paint") is not empty) is tShow, "and again"
      tourTmCheck tourTmMenuChecked("Paint and Draw Tools") is tShow, "and its check again"
      tourTmCheck revIDEGetPreference("revTools_show") & "|" & revIDEGetPreference("revTools_columns") is sTmClassicPrefs, \
            "the classic look's settings are still untouched"
   end if
   tourTmFinish "tools-modern-use"
end tour_tools_modern_use

-- Switching: back and forth a few times, the modern look builds the same
-- each time, and the classic look comes back as it was
on tour_tools_modern_switch
   local tFirst, tN, tClassic, tKey, tDiff
   if not tourTmStart("tools-modern-switch") then exit tour_tools_modern_switch
   if tourToolsModern(empty, false) is not true then throw "the modern look did not turn on"
   put the number of controls of card 1 of stack "revTools" into tFirst
   repeat 3 times
      revIDESetPreference "revTools_look", "classic"
      tourWait 200
      revIDESetPreference "revTools_look", "modern"
      tourWait 200
   end repeat
   put the number of controls of card 1 of stack "revTools" into tN
   tourTmCheck tN is tFirst, "the modern look builds the same each time (" & tFirst && "then" && tN && "controls)"
   -- from the Tools menu
   if there is a stack "revMenuBar" then
      dispatch "revMenubarToolsMenuPick" to stack "revMenuBar" with "Modern Tools Palette"
      tourTmCheck revIDEGetPreference("revTools_look") is "classic", "Tools > Modern Tools Palette turns it off"
      dispatch "revMenubarToolsMenuPick" to stack "revMenuBar" with "Modern Tools Palette"
      tourTmCheck revIDEGetPreference("revTools_look") is "modern", "and on"
   end if
   -- the modern menu's Classic Look
   dispatch "tmMenuPick" to stack "revTools" with "Classic Look"
   tourWait 500
   tourTmCheck revIDEGetPreference("revTools_look") is "classic", "the menu's Classic Look turns it off"
   put tourTmTiles() into tClassic
   repeat for each key tKey in sTmClassic
      if tClassic[tKey] is not sTmClassic[tKey] then put tKey & ": " & tClassic[tKey] && "/" && sTmClassic[tKey] & "; " after tDiff
   end repeat
   repeat for each key tKey in tClassic
      if sTmClassic[tKey] is empty then put tKey & " is new; " after tDiff
   end repeat
   tourTmCheck tDiff is empty, "the classic look comes back as it was" && tDiff
   tourTmCheck tourTmNamed("tmHeader") is empty and tourTmNamed("tmGrip") is empty and tourTmNamed("tmThumb") is empty, "and with nothing of the modern look"
   tourTmCheck tourTmNamed("toolsOVERRIDEmenu") is not empty, "and with its own options button"
   tourTmCheck revIDEGetPreference("revTools_show") & "|" & revIDEGetPreference("revTools_columns") is sTmClassicPrefs, "and its own settings"
   -- a look changed while the palette is closed, when it hears no
   -- preference: it opens in that look, with nothing of the other one
   -- (the classic look stopped at an error on the modern look's controls)
   close stack "revTools"
   revIDESetPreference "revTools_look", "modern"
   revIDEOpenPalette "tools"
   tourWait 600
   tourTmCheck tourTmNamed("tmHeader") is not empty and tourTmNamed("toolsOVERRIDEmenu") is empty, \
         "a palette closed in the classic look opens in the modern look chosen meanwhile"
   close stack "revTools"
   revIDESetPreference "revTools_look", "classic"
   revIDEOpenPalette "tools"
   tourWait 600
   tourTmCheck tourTmNamed("tmHeader") is empty and tourTmNamed("toolsOVERRIDEmenu") is not empty, \
         "and one closed in the modern look opens in the classic look chosen meanwhile"
   tourTmFinish "tools-modern-switch"
   tourTmReset
end tour_tools_modern_switch

function tourTmStart pStep
   put 0 into sTmChecks
   put empty into sTmFails
   revIDEOpenPalette "tools"
   tourWait 200
   dispatch function "tmIsModern" to stack "revTools"
   if it is not "handled" then
      tourRecord "INFO" && pStep & ": this palette has no modern look"
      return false
   end if
   if sTmClassicPrefs is empty then
      put revIDEGetPreference("revTools_show") & "|" & revIDEGetPreference("revTools_columns") into sTmClassicPrefs
   end if
   return true
end tourTmStart

command tourTmCheck pTrue, pWhat
   add 1 to sTmChecks
   if pTrue is not true then put pWhat & return after sTmFails
end tourTmCheck

command tourTmFinish pStep
   local tFails
   put sTmFails into tFails
   tourRecord "INFO" && pStep & ":" && sTmChecks && "checks," && the number of lines of tFails && "failed"
   if tFails is not empty then
      tourShotStack "revTools", "zz-" & pStep
      tourTmReset
      throw "failed:" && tourJoin(line 1 to -1 of tFails)
   end if
   tourToolsClassic
end tourTmFinish

command tourTmReset
   local tName
   revIDESetPreference "revTools_look", "classic"
   repeat for each item tName in "revTools_modernSize,revTools_modernNames,revTools_modernFolded,revTools_modernShow,revTools_modernLarge"
      revIDESetPreference tName, empty
   end repeat
   tourWait 300
end tourTmReset

-- A click on a control of the palette, as the IDE gets it: through the
-- IDE's front script, whose Linux window fix locks the screen without
-- unlocking it (a click ends at idle, which unlocks it; a sent message
-- does not)
command tourTmClick pObj
   send "mouseDown 1" to pObj
   repeat while the lockScreen
      unlock screen
   end repeat
   tourWait 50
end tourTmClick

-- Whether an item of the IDE's Tools menu is checked, as the menu bar
-- builds it; empty when the menu has no such item
function tourTmMenuChecked pItem
   local tLine
   dispatch function "revMenubarBuildMenu" to stack "revMenuBar" with "Tools"
   repeat for each line tLine in the result
      if tLine contains pItem then return char 1 to 2 of tLine is "!c"
   end repeat
   return empty
end tourTmMenuChecked

-- A control of the Tools palette by its name
function tourTmNamed pName
   return tourControlNamed("revTools", pName)
end tourTmNamed

-- A section's group in the palette's group "contents"
function tourTmGroup pView
   if there is not a group "contents" of stack "revTools" then return empty
   if there is not a group pView of group "contents" of stack "revTools" then return empty
   return the long id of group pView of group "contents" of stack "revTools"
end tourTmGroup

-- The width of a shape's drawn icon (the palette's tmShapeSvg), or empty
-- when its tile shows a picture
function tourTmShapeIcon pTypeID
   local tID
   if tourTmNamed(pTypeID) is empty then return empty
   put the icon of tourTmNamed(pTypeID) into tID
   if tID is not an integer or tID is 0 then return empty
   if there is not an image id tID of stack "revTools" then return empty
   if the short name of image id tID of stack "revTools" is not ("tm.shape:" & pTypeID) then return empty
   return the width of image id tID of stack "revTools"
end tourTmShapeIcon

-- The tiles: the controls with the classic properties, by name, as
-- "<their group>,<cType>,<cTool>,<cToolName>,<cStyle>,<cName>"; not
-- their rects, which each look lays out its own way
function tourTmTiles
   local tCard, i, tObj, tTiles, tToolName
   put the long id of card 1 of stack "revTools" into tCard
   repeat with i = 1 to the number of controls of tCard
      put the long id of control i of tCard into tObj
      if the cType of tObj is empty then next repeat
      if word 1 of tObj is "group" then next repeat
      -- (the classic look leaves an object's cToolName as the template
      -- button's last one; only a tool's is read)
      if the cTool of tObj is empty then
         put empty into tToolName
      else
         put the cToolName of tObj into tToolName
      end if
      put the short name of the owner of tObj & comma & the cType of tObj & comma & the cTool of tObj & comma & \
            tToolName & comma & the cStyle of tObj & comma & the cName of tObj into tTiles[the short name of tObj]
   end repeat
   return tTiles
end tourTmTiles

-- The tiles shown (in a section shown)
function tourTmShownTiles
   local tCount, tView, tGroup, i
   put 0 into tCount
   repeat for each item tView in "widget,classic,graphic,graphictools,graphictoolscontrols,paint,paintcontrols"
      put tourTmGroup(tView) into tGroup
      if tGroup is empty or not the visible of tGroup then next repeat
      repeat with i = 1 to the number of buttons of tGroup
         if the visible of button i of tGroup then add 1 to tCount
      end repeat
   end repeat
   return tCount
end tourTmShownTiles

-- In how many columns a section's tiles are laid out
function tourTmColumns pView
   local tGroup, i, tTop, tCols
   put tourTmGroup(pView) into tGroup
   if tGroup is empty then return 0
   put empty into tTop
   put 0 into tCols
   repeat with i = 1 to the number of buttons of tGroup
      if not the visible of button i of tGroup then next repeat
      if tTop is empty then put the top of button i of tGroup into tTop
      if the top of button i of tGroup is tTop then add 1 to tCols
   end repeat
   return tCols
end tourTmColumns

-- The bottom of the lowest tile shown
function tourTmLowestTile
   local tView, tGroup, i, tMax
   put 0 into tMax
   repeat for each item tView in "widget,classic,graphic,graphictools,graphictoolscontrols,paint,paintcontrols"
      put tourTmGroup(tView) into tGroup
      if tGroup is empty or not the visible of tGroup then next repeat
      repeat with i = 1 to the number of buttons of tGroup
         if the visible of button i of tGroup then put max(tMax, the bottom of button i of tGroup) into tMax
      end repeat
   end repeat
   return tMax
end tourTmLowestTile

-- Every name shown is whole: on one line it is no wider than its field, or
-- on two lines no taller, and never smaller than 10 points
command tourTmNamesWhole pWhere
   local tView, tGroup, i, tLabel, tBad
   repeat for each item tView in "widget,classic,graphic,graphictools,graphictoolscontrols,paint,paintcontrols"
      put tourTmGroup(tView) into tGroup
      if tGroup is empty or not the visible of tGroup then next repeat
      repeat with i = 1 to the number of buttons of tGroup
         if not the visible of button i of tGroup then next repeat
         put tourTmNamed("tmLabel:" & the short name of button i of tGroup) into tLabel
         if tLabel is empty or not the visible of tLabel then next repeat
         if the textSize of tLabel < 10 then
            put the text of tLabel && "at" && the textSize of tLabel && "points; " after tBad
         else if the dontWrap of tLabel and the formattedWidth of tLabel > the width of tLabel then
            put the text of tLabel && "cut off (" & the formattedWidth of tLabel & ">" & the width of tLabel & "); " after tBad
         else if not the dontWrap of tLabel and the formattedHeight of tLabel > the height of tLabel then
            put the text of tLabel && "cut off below (" & the formattedHeight of tLabel & ">" & the height of tLabel & "); " after tBad
         else if tourTmTextCut(tLabel) is not empty then
            put the text of tLabel && "cut off," && tourTmTextCut(tLabel) & "; " after tBad
         end if
      end repeat
   end repeat
   tourTmCheck tBad is empty, "every name is whole" && pWhere & ":" && tBad
end tourTmNamesWhole

-- What of a label's text its field cuts off: the box of its first line
-- above the field's top, or of its last line below its bottom, from the
-- formattedRect of the lines, which is where they are drawn. (The
-- formattedHeight cannot tell: with margins of 0 it is 12 points short of
-- the lines, and sizing the labels by it was what cut the captions off.)
function tourTmTextCut pLabel
   local tFirst, tLast
   do "put the formattedRect of line 1 of" && pLabel && "into tFirst"
   do "put the formattedRect of line (the number of lines of the text of" && pLabel && ") of" && pLabel && "into tLast"
   if item 2 of tFirst < the top of pLabel then
      return "its first line above its top (" & item 2 of tFirst & "<" & the top of pLabel & ")"
   end if
   if item 4 of tLast > the bottom of pLabel then
      return "its last line below its bottom (" & item 4 of tLast & ">" & the bottom of pLabel & ")"
   end if
   return empty
end tourTmTextCut

-- The layout at its size: the header's controls and every tile shown
-- inside the window's width, below the filter, and no two tiles over
-- each other; a name inside its tile
command tourTmLayoutOK pWhen
   local tW, tView, tGroup, i, j, tRects, tR, tS, tBad, tTop, tLabel, tName
   put the width of stack "revTools" into tW
   repeat for each item tName in "tmHeadBg,tmMenuBtn,tmSearchBg,tmFilter,tmFilterClear,tmGrip"
      put the rect of tourTmNamed(tName) into tR
      if item 1 of tR < 0 or item 3 of tR > tW then put tName && tR & "; " after tBad
   end repeat
   put the right of tourTmNamed("com.livecode.tool.Pointer") into tR
   if tR >= the left of tourTmNamed("tmMenuBtn") then put "Edit runs into the menu button; " after tBad
   put the bottom of tourTmNamed("tmSearchBg") into tTop
   repeat for each item tView in "widget,classic,graphic,graphictools,graphictoolscontrols,paint,paintcontrols"
      put tourTmGroup(tView) into tGroup
      if tGroup is empty or not the visible of tGroup then next repeat
      repeat with i = 1 to the number of buttons of tGroup
         if not the visible of button i of tGroup then next repeat
         put the rect of button i of tGroup into tR
         if item 1 of tR < 0 or item 3 of tR > tW - 4 or item 3 of tR <= item 1 of tR then
            put the short name of button i of tGroup && tR & "; " after tBad
         end if
         if item 2 of tR < tTop and the vScroll of tourTmNamed("contents") is 0 then
            put the short name of button i of tGroup && "above the filter" && tR & "; " after tBad
         end if
         put tourTmNamed("tmLabel:" & the short name of button i of tGroup) into tLabel
         if tLabel is not empty and the visible of tLabel then
            if the right of tLabel > item 3 of tR + 1 or the left of tLabel < item 1 of tR then
               put "the name of" && the short name of button i of tGroup && "outside its tile; " after tBad
            end if
         end if
         put tR into tRects[the number of elements of tRects + 1]
      end repeat
   end repeat
   -- the sections' captions, whole in their labels
   repeat for each item tName in "widget,classic,graphic,vector,paint"
      put tourTmNamed("tmCapLabel:" & tName) into tLabel
      if tLabel is empty or not the visible of tLabel or not the visible of the owner of tLabel then next repeat
      if tourTmTextCut(tLabel) is not empty then
         put "the caption" && the text of tLabel && "cut off," && tourTmTextCut(tLabel) & "; " after tBad
      end if
   end repeat
   repeat with i = 1 to the number of elements of tRects
      put tRects[i] into tR
      repeat with j = i + 1 to the number of elements of tRects
         put tRects[j] into tS
         if item 1 of tR < item 3 of tS and item 1 of tS < item 3 of tR and item 2 of tR < item 4 of tS and item 2 of tS < item 4 of tR then
            put "tiles over each other" && tR && tS & "; " after tBad
            exit repeat
         end if
      end repeat
   end repeat
   tourTmCheck tBad is empty, "the layout fits" && pWhen & ":" && tBad
end tourTmLayoutOK

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

-- A stack opened with its title bar above the top of the screen (a
-- HyperCard stack at 0,0, or a stack whose own preOpenStack puts it there)
-- is moved down just far enough to be dragged (revIDEKeepTitleBarOnScreen,
-- sent by the front script); one whose title bar shows stays where it is,
-- and a window with no title bar is left alone. None is marked as changed.
on tour_title_bar
   local tArea, tName, tFails, tRect, tFrame, tTitle, tEdited, tWant
   put line 1 of the working screenRects into tArea
   tourTbMake "oxt_tb_above", item 1 of tArea + 40, item 2 of tArea - 200, empty
   tourTbMake "oxt_tb_script", item 1 of tArea + 80, item 2 of tArea + 120, \
         "on preOpenStack" & return & "   set the topLeft of this stack to 0,0" & return & "end preOpenStack"
   tourTbMake "oxt_tb_fine", item 1 of tArea + 120, item 2 of tArea + 140, empty
   tourTbMake "oxt_tb_plain", item 1 of tArea + 160, item 2 of tArea - 100, empty
   lock messages
   set the decorations of stack "oxt_tb_plain" to empty
   unlock messages
   repeat for each item tName in "oxt_tb_above,oxt_tb_script,oxt_tb_fine,oxt_tb_plain"
      put revIDEStackIsEdited(tName) into tEdited[tName]
      go stack tName
   end repeat
   tourWait 1000
   repeat for each item tName in "oxt_tb_above,oxt_tb_script,oxt_tb_fine,oxt_tb_plain"
      put the rect of stack tName into tRect
      put the effective rect of stack tName into tFrame
      put max(32, item 2 of tRect - item 2 of tFrame) into tTitle
      tourRecord "INFO title-bar" && tName & ": rect" && tRect & ", effective rect" && tFrame & ", working screenRect" && tArea
      if revIDEStackIsEdited(tName) is not tEdited[tName] then
         put tName && "was marked as changed" & return after tFails
      end if
      switch tName
         case "oxt_tb_above"
         case "oxt_tb_script"
            if item 2 of tRect - tTitle < item 2 of tArea or item 2 of tRect > item 2 of tArea + tTitle + 40 then
               put tName && "has its title bar off the screen or was moved too far (" & tRect & ")" & return after tFails
            end if
            break
         case "oxt_tb_fine"
            put item 1 of tArea + 120, item 2 of tArea + 140 into tWant
            if item 1 to 2 of tRect is not tWant then
               put tName && "was moved from" && tWant && "to" && item 1 to 2 of tRect & return after tFails
            end if
            break
      end switch
   end repeat
   tourShotScreen "04b-title-bar"
   lock messages
   repeat for each item tName in "oxt_tb_above,oxt_tb_script,oxt_tb_fine,oxt_tb_plain"
      if there is a stack tName then delete stack tName
   end repeat
   unlock messages
   if tFails is not empty then throw "failed:" && tourJoin(line 1 to -1 of tFails)
end tour_title_bar

command tourTbMake pName, pLeft, pTop, pScript
   local tDefault
   put the defaultStack into tDefault
   lock messages
   if there is a stack pName then delete stack pName
   create stack pName
   set the rect of stack pName to pLeft, pTop, pLeft + 320, pTop + 200
   set the script of stack pName to pScript
   -- create opens the stack (here with messages locked): closed, it opens
   -- again as a user's does, with preOpenStack
   close stack pName
   set the defaultStack to tDefault
   unlock messages
end tourTbMake

on tour_inspector
   local tPI, tSection, tShown, tIndex
   put tourInspect(tourSample("Push")) into tPI
   tourInspectorHeaderCheck tPI
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

-- The Fill gradient popup, opened as a click on its row of the Colors
-- section opens it, with the Inspector right of the Tools palette and the
-- sample at the right of the screen. It must be all on the screen, and
-- where the screen has room for it beside the Inspector off the graphic
-- (to the Inspector's right or left, or below or above it), it must cover
-- neither (richmond62 on rc.6.3: it opened on top of the graphic; here
-- rc.6.3 put it left of the Inspector, two thirds of it off the screen).
-- Then with the graphic over the whole screen, so that every place covers
-- it: to the Inspector's left, as before, where it fits there.
on tour_inspector_gradient
   local tSampleRect, tBox, tBoxRect, tPI, tScreen, tLeft, tPopRect, tPIRect, tRoom, tError
   put tourSample("Box") into tBox
   put the rect of stack kSample into tSampleRect
   put the rect of tBox into tBoxRect
   put tourInspect(tBox) into tPI
   get tourInspectorSection(tPI, "Colors")
   put the working screenRect into tScreen
   put item 1 of tScreen + 10 into tLeft
   if there is a stack "revTools" and the mode of stack "revTools" is not 0 and the visible of stack "revTools" then
      put max(tLeft, the right of stack "revTools" + 20) into tLeft
   end if
   set the topLeft of stack tPI to tLeft, item 2 of tScreen + 40
   set the topRight of stack kSample to item 3 of tScreen - 10, item 2 of tScreen + 40
   tourWait 500
   try
      put tourGradientPopup(tPI) into tPopRect
      put the rect of stack tPI into tPIRect
      put tourScreenRectOf(tBox) into tBoxRect
      put tourRoomBeside(tPIRect, tPopRect, tBoxRect, tScreen) into tRoom
      tourRecord "INFO inspector-gradient popup" && tPopRect && "inspector" && tPIRect && "graphic" && tBoxRect && \
            "screen" && tScreen && "room off the graphic:" && tourJoin(tRoom)
      tourShotScreen "07-inspector-gradient"
      tourCloseGradientPopup
      if not tourRectWithin(tPopRect, tScreen) then throw "the popup" && tPopRect && "is not all on the screen" && tScreen
      if tRoom is not empty then
         if tourRectsOverlap(tPopRect, tPIRect) then throw "the popup" && tPopRect && "covers the Inspector" && tPIRect
         if tourRectsOverlap(tPopRect, tBoxRect) then throw "the popup" && tPopRect && "covers the graphic" && tBoxRect
      end if
      -- every place covers the graphic: the Inspector's left, as before
      set the rect of stack kSample to tScreen
      set the rect of tBox to the rect of card 1 of stack kSample
      set the topLeft of stack tPI to item 1 of tScreen + 400, item 2 of tScreen + 40
      tourWait 500
      put tourGradientPopup(tPI) into tPopRect
      put the rect of stack tPI into tPIRect
      put tourRoomBeside(tPIRect, tPopRect, tourScreenRectOf(tBox), tScreen) into tRoom
      tourRecord "INFO inspector-gradient over the graphic: popup" && tPopRect && "inspector" && tPIRect && \
            "room off the graphic:" && tourJoin(tRoom)
      tourCloseGradientPopup
      if tRoom is not empty then throw "the graphic leaves room beside the Inspector:" && tourJoin(tRoom)
      if not tourRectWithin(tPopRect, tScreen) then throw "the popup" && tPopRect && "is not all on the screen" && tScreen
      if item 3 of tPopRect > item 1 of tPIRect then
         throw "with the graphic everywhere, the popup" && tPopRect && "is not left of the Inspector" && tPIRect
      end if
   catch tError
   end try
   tourCloseGradientPopup
   tourCloseInspectors
   set the rect of tBox to tBoxRect
   set the rect of stack kSample to tSampleRect
   if tError is not empty then throw tError
end tour_inspector_gradient

-- Opens the Fill gradient popup of the inspector pPI, as a click on its
-- row of the Colors section does, and returns the popup's rect once it has
-- placed itself (as it opens, and again a moment later)
function tourGradientPopup pPI
   local tRow, tEditor, i
   put the long id of group "Fill gradient" of group "inspector" of card 1 of stack pPI into tRow
   repeat with i = 1 to the number of groups of tRow
      if the editorProperty["property_name"] of group i of tRow is "fillGradient" then
         put the long id of group i of tRow into tEditor
         exit repeat
      end if
   end repeat
   if tEditor is empty then throw "no Fill gradient editor in the row"
   send "mouseUp 1" to tEditor
   if not tourWaitOpen("revPropertyPopup fillGradient", 3000) then throw "the Fill gradient popup did not open"
   tourWait 1000
   return the rect of stack "revPropertyPopup fillGradient"
end tourGradientPopup

command tourCloseGradientPopup
   if there is a stack "revPropertyPopup fillGradient" then
      close stack "revPropertyPopup fillGradient"
      tourWait 500
   end if
end tourCloseGradientPopup

-- The rect of the control pObj on the screen
function tourScreenRectOf pObj
   local tRect, tStack
   put the rect of pObj into tRect
   put revIDEStackOfObject(pObj) into tStack
   return item 1 of tRect + the left of tStack, item 2 of tRect + the top of tStack, \
         item 3 of tRect + the left of tStack, item 4 of tRect + the top of tStack
end tourScreenRectOf

-- Whether two rects share any point
function tourRectsOverlap pA, pB
   return item 1 of pA < item 3 of pB and item 1 of pB < item 3 of pA and \
         item 2 of pA < item 4 of pB and item 2 of pB < item 4 of pA
end tourRectsOverlap

-- Whether the rect pA is all inside pB
function tourRectWithin pA, pB
   return item 1 of pA >= item 1 of pB and item 2 of pA >= item 2 of pB and \
         item 3 of pA <= item 3 of pB and item 4 of pA <= item 4 of pB
end tourRectWithin

-- The places, of right, left, below and above, where a window the size of
-- pWindow fits on the screen pScreen 5 points from the rect pBeside (at
-- its top, or at its left, moved to stay on the screen) without covering
-- the rect pAvoid
function tourRoomBeside pBeside, pWindow, pAvoid, pScreen
   local tW, tH, tTop, tLeft, tPlace, tRect, tRoom
   put item 3 of pWindow - item 1 of pWindow into tW
   put item 4 of pWindow - item 2 of pWindow into tH
   put max(item 2 of pScreen, min(item 2 of pBeside, item 4 of pScreen - tH)) into tTop
   put max(item 1 of pScreen, min(item 1 of pBeside, item 3 of pScreen - tW)) into tLeft
   repeat for each item tPlace in "right,left,below,above"
      switch tPlace
         case "right"
            put item 3 of pBeside + 5, tTop, item 3 of pBeside + 5 + tW, tTop + tH into tRect
            break
         case "left"
            put item 1 of pBeside - 5 - tW, tTop, item 1 of pBeside - 5, tTop + tH into tRect
            break
         case "below"
            put tLeft, item 4 of pBeside + 5, tLeft + tW, item 4 of pBeside + 5 + tH into tRect
            break
         case "above"
            put tLeft, item 2 of pBeside - 5 - tH, tLeft + tW, item 2 of pBeside - 5 into tRect
            break
      end switch
      if tourRectWithin(tRect, pScreen) and not tourRectsOverlap(tRect, pAvoid) then
         put tPlace & return after tRoom
      end if
   end repeat
   return line 1 to -1 of tRoom
end tourRoomBeside

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

-- As Help > Dictionary does: LiveCode's Dictionary, the default, in a
-- palette with a browser widget, or in the system's browser where there is
-- no browser widget (revIDEBrowserWidgetUnavailable); the text dictionary
-- when Preferences > Dictionary chooses it (cDictionaryDisplayMethod)
on tour_dictionary
   local tBefore, tNew
   put the openStacks into tBefore
   send "tNewDictionaryDisplay" to stack "revMenuBar"
   if the cDictionaryDisplayMethod of stack "revPreferences" is not true and revIDEBrowserWidgetUnavailable() then
      tourDictionaryPage
      exit tour_dictionary
   end if
   repeat 40 times
      put tourNewStack(tBefore) into tNew
      if tNew is not empty then exit repeat
      tourWait 500
   end repeat
   if tNew is empty then throw "no dictionary window opened"
   tourWait 4000
   if tNew is revIDEPaletteToStackName("dictionary") then
      tourDictionaryData tNew
   else
      tourDictionaryEntry tNew, "try control structure.txt"
   end if
   tourShotStack tNew, "13-dictionary"
   close stack tNew
end tour_dictionary

-- Tom Perry's text dictionary, as Help > Dictionary opens it when
-- Preferences > Dictionary chooses it, on an entry that
-- tools/oxt/text_dictionary.py wrote; the preferences are restored after
on tour_text_dictionary
   local tMethod, tQuick, tBefore, tNew, tError
   put the cDictionaryDisplayMethod of stack "revPreferences" into tMethod
   put the cQuickDictionary of stack "revPreferences" into tQuick
   set the cDictionaryDisplayMethod of stack "revPreferences" to true
   set the cQuickDictionary of stack "revPreferences" to false
   try
      put the openStacks into tBefore
      send "tNewDictionaryDisplay" to stack "revMenuBar"
      repeat 40 times
         put tourNewStack(tBefore) into tNew
         if tNew is not empty then exit repeat
         tourWait 500
      end repeat
      if tNew is empty then throw "no text dictionary window opened"
      if there is not a field "styledTextField" of card 1 of stack tNew then
         throw tNew && "opened, not the text dictionary"
      end if
      tourWait 2000
      tourDictionaryEntry tNew, "try control structure.txt"
      tourShotStack tNew, "13-dictionary-text"
      close stack tNew
   catch tError
   end try
   set the cDictionaryDisplayMethod of stack "revPreferences" to tMethod
   set the cQuickDictionary of stack "revPreferences" to tQuick
   if tError is not empty then throw tError
end tour_text_dictionary

-- LiveCode's Dictionary in the palette pStack: its page must list the
-- entries of both languages, with the docs of the extensions that the IDE
-- loaded (each a library of its own; the widgets' among them)
command tourDictionaryData pStack
   local tError, tData, tEntry, tLine, tScript, tBuilder
   try
      -- one line per API: its name, entries, libraries and widget libraries
      put tourPageReport(pStack, "liveCode.oxtTourReport(dictionary_data.docs.map(function(d){" & \
            "var n={};d.doc.forEach(function(e){n[e.library||'']=1;});var l=Object.keys(n);" & \
            "return [d.name,d.doc.length,l.length,l.filter(function(k){return k.indexOf('com.livecode.widget.')==0;}).length].join(' ');" & \
            "}).join('\n'))") into tData
      -- then the entry of the text dictionary's snapshot, as a click on it
      -- in the list shows it, so that each build's snapshot shows the
      -- same one: the page must show its text
      put tourPageReport(pStack, "goEntryName('livecode_script','try','control structure');" & \
            "setTimeout(function(){liveCode.oxtTourReport(document.body.innerText.indexOf(" & \
            "'series of statements and handle any error messages')>=0?'shown':'not shown');},1000);") into tEntry
   catch tError
      throw "LiveCode's Dictionary: " & tourJoin(tError)
   end try
   if tData is empty then throw "LiveCode's Dictionary did not report its data"
   if tEntry is not "shown" then throw "LiveCode's Dictionary does not show the entry try (" & tEntry & ")"
   tourRecord "INFO LiveCode's Dictionary shows the entry try"
   repeat for each line tLine in tData
      tourRecord "INFO LiveCode's Dictionary" && word 1 of tLine & ":" && word 2 of tLine && "entries," && \
            word 3 of tLine && "libraries (" & word 4 of tLine && "widgets)"
      if word 1 of tLine is "livecode_script" then put tLine into tScript
      if word 1 of tLine is "livecode_builder" then put tLine into tBuilder
   end repeat
   -- (OXT-Beyond 0.2.4: 3162 and 609 entries, 18 widgets)
   if not (word 2 of tScript >= 2500) then throw "LiveCode's Dictionary has too few xTalk Script entries:" && word 2 of tScript
   if not (word 4 of tScript >= 10) then throw "LiveCode's Dictionary has too few widgets:" && word 4 of tScript
   if not (word 2 of tBuilder >= 500) then throw "LiveCode's Dictionary has too few xTalk Builder entries:" && word 2 of tBuilder
end tourDictionaryData

-- The guides, in the Guide tab of LiveCode's Dictionary: each once (the
-- docs builder makes them from docs/guides and ide/Documentation/guides,
-- which had copies of the same guides), and the Printing guide with its
-- images, which are in Documentation/guides/images
on tour_guides
   local tBefore, tNew, tData, tError
   if the cDictionaryDisplayMethod of stack "revPreferences" is true or revIDEBrowserWidgetUnavailable() then
      tourRecord "INFO the guides are not checked: no browser widget shows LiveCode's Dictionary"
      exit tour_guides
   end if
   put the openStacks into tBefore
   send "tNewDictionaryDisplay" to stack "revMenuBar"
   repeat 40 times
      put tourNewStack(tBefore) into tNew
      if tNew is not empty then exit repeat
      tourWait 500
   end repeat
   if tNew is empty then throw "no dictionary window opened"
   if tNew is not revIDEPaletteToStackName("dictionary") then throw tNew && "opened, not LiveCode's Dictionary"
   tourWait 4000
   dispatch "showGuides" to stack tNew
   tourWait 4000
   -- the guides (but those of extensions), the guides named twice, and the
   -- images of the Printing guide and how many of them loaded
   try
      put tourPageReport(tNew, "var g=tUserGuideData.guides,n={},t=[],d=[],p=-1;" & \
            "g.forEach(function(v,i){if(v.name=='printing')p=i;if(v.group=='Extensions')return;" & \
            "t.push(v['display name']);if(n[v['display name']])d.push(v['display name']);n[v['display name']]=1;});" & \
            "if(p<0){liveCode.oxtTourReport(t.length+' 0 0 '+(d.join(',')||'-'));}else{loadGuide(p);" & \
            "setTimeout(function(){var m=document.querySelectorAll('#documentation img'),k=0;" & \
            "for(var i=0;i<m.length;i++){if(m[i].complete&&m[i].naturalWidth>0)k++;}" & \
            "liveCode.oxtTourReport(t.length+' '+m.length+' '+k+' '+(d.join(',')||'-'));},2000);}") into tData
   catch tError
      throw "the guides: " & tourJoin(tError)
   end try
   if tData is empty then throw "the guides: the page did not report them"
   tourRecord "INFO the guides:" && word 1 of tData && "guides; Printing shows" && word 3 of tData && "of its" && \
         word 2 of tData && "images"
   if word 4 to -1 of tData is not "-" then throw "the guides: named twice:" && word 4 to -1 of tData
   -- (OXT-Beyond 0.2.4: 16 guides; Printing has 11 images)
   if not (word 1 of tData >= 12) then throw "the guides: too few:" && word 1 of tData
   if not (word 2 of tData > 0) then throw "the guides: no Printing guide, or it shows no images"
   if word 3 of tData is not word 2 of tData then
      throw "the guides: the Printing guide shows" && word 3 of tData && "of its" && word 2 of tData && "images"
   end if
   tourShotStack tNew, "13-guides"
   close stack tNew
end tour_guides

-- Runs the JavaScript pJS in the page of the browser widget "Dictionary"
-- of pStack and returns the data it gives liveCode.oxtTourReport (empty
-- after 10 seconds without it): a JavaScript handler of the widget, which
-- a frontscript of this stack handles (do ... in widget returns nothing)
function tourPageReport pStack, pJS
   local tDefault, tHandlers, tError, tData
   if there is not a widget "Dictionary" of stack pStack then
      throw pStack && "has no browser widget"
   end if
   put the defaultStack into tDefault
   set the defaultStack to "oxt_ui_tour"
   lock messages
   if there is not a button "oxt_ui_tour_report" then create invisible button "oxt_ui_tour_report"
   set the script of button "oxt_ui_tour_report" to "on oxtTourReport pData" & return & \
         "   dispatch " & quote & "tourReported" & quote & " to stack " & quote & "oxt_ui_tour" & quote & " with pData" & return & \
         "end oxtTourReport"
   insert the script of button "oxt_ui_tour_report" into front
   unlock messages
   set the defaultStack to tDefault
   put the javascriptHandlers of widget "Dictionary" of stack pStack into tHandlers
   set the javascriptHandlers of widget "Dictionary" of stack pStack to tHandlers & return & "oxtTourReport"
   put empty into sReport
   try
      do pJS in widget "Dictionary" of stack pStack
      repeat 40 times
         if sReport is not empty then exit repeat
         tourWait 250
      end repeat
      put sReport into tData
   catch tError
   end try
   set the javascriptHandlers of widget "Dictionary" of stack pStack to tHandlers
   remove the script of button "oxt_ui_tour_report" of stack "oxt_ui_tour" from front
   if tError is not empty then throw tError
   return tData
end tourPageReport

on tourReported pData
   put pData into sReport
end tourReported

-- LiveCode's Dictionary in the system's browser, where there is no browser
-- widget: the page the IDE wrote for it, and its data
command tourDictionaryPage
   local tPage, tData, tBytes
   put revIDEGetDictionaryUrl("api") into tPage
   put revIDESpecialFolderPath("documentation cache") & "/built_api.js" into tData
   if there is not a file tPage then throw "LiveCode's Dictionary: no page" && tPage
   if there is a file tData then put the number of bytes of URL ("binfile:" & tData) into tBytes
   -- (OXT-Beyond 0.2.4: about 6 MB)
   if not (tBytes > 1000000) then throw "LiveCode's Dictionary: no data in" && tData
   tourRecord "INFO LiveCode's Dictionary opens in the system's browser:" && tPage && "(data" && tBytes && "bytes)"
end tourDictionaryPage

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
   -- the HTML5 option shows when the IDE finds the web runtime
   -- (revEngineCheck in revsblibrary): what it looked at, for the log
   tourRecord "INFO web runtime check" && revEngineCheck("Emscripten") && \
         "installed" && revEnvironmentIsInstalled() && "runtime" && revEnvironmentRuntimePath() && \
         "user runtime" && revEnvironmentUserRuntimePath() && "folder" && \
         (there is a folder (revEnvironmentRuntimePath() & "/Emscripten/js"))
   if not revEngineCheck("Emscripten") then
      throw "the web runtime is not found (revEngineCheck), so the Web card has no HTML5 option; runtime" && \
            revEnvironmentRuntimePath() & ", user runtime" && revEnvironmentUserRuntimePath()
   end if
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
      -- the Web card makes its page's settings when it first opens: the
      -- HTML5 option and those settings are there
      if tCard is "Emscripten" then
         if not the visible of button "Emscripten" of group "platforms" of card "Emscripten" of stack tStack then
            throw "the Web card shows no HTML5 option"
         end if
         if there is not a field "emscriptenTitle" of card "Emscripten" of stack tStack then
            throw "the Web card has no settings for its page"
         end if
      end if
   end repeat
   close stack tStack
end tour_standalone_settings

-- mergJSON, built from its source into Ext/mergJSON (tools/oxt/package.py
-- EXT_FILES), as LiveCode's installer put its mergExt collection there:
-- the IDE loads the folder's external and its library
-- (revInternal__SetupExternals and revInternal__InitialiseLibraries in
-- home.livecodescript), so JSONToArray and ArrayToJSON work, and the
-- standalone builder finds the external for this computer's platform. A
-- release before it was built has no such folder, and the step fails there.
on tour_ext_mergjson
   local tFolder, tFile, tTarget, tFails, tA, tJson, tLibrary, tIncluded
   put revEnvironmentExtPath() & "/mergJSON" into tFolder
   if there is not a folder tFolder then throw "there is no" && tFolder
   switch the platform
      case "Win32"
         if the processor is "x86_64" then
            put "mergJSON-x64.dll,Windows x86-64" into tFile
         else
            put "mergJSON-x86.dll,Windows" into tFile
         end if
         break
      case "MacOS"
         if the processor is "arm64" then
            put "mergJSON.bundle,MacOSX x64-ARM64" into tFile
         else
            put "mergJSON.bundle,MacOSX x86-64" into tFile
         end if
         break
      default
         if the processor is "x86_64" then
            put "mergJSON-x64.so,Linux x64" into tFile
         else if the processor is among the items of "arm64,aarch64" then
            put "mergJSON-arm64.so,Linux arm64" into tFile
         else
            put "mergJSON-x86.so,Linux" into tFile
         end if
         break
   end switch
   put item 2 of tFile into tTarget
   put tFolder & "/" & item 1 of tFile into tFile
   tourRecord "INFO ext-mergjson" && tFile && "target" && tTarget && "files" && tourJoin(files(tFolder) & return & folders(tFolder))
   if there is not a file tFile and there is not a folder tFile then
      put "there is no" && tFile & return after tFails
   end if

   -- the external
   if tFile is not among the lines of the externals of stack "Home" then
      put "Home's externals do not have it:" && tourJoin(the externals of stack "Home") & return after tFails
   end if
   if "mergJSONDecode" is not among the lines of the externalFunctions of stack "Home" or \
         "mergJSONEncode" is not among the lines of the externalFunctions of stack "Home" then
      put "its functions are not loaded:" && tourJoin(the externalFunctions of stack "Home") & return after tFails
   end if

   -- its library
   put "ws.goulding.script-library.mergjson" into tLibrary
   if there is not a stack tLibrary then
      put "its library is not loaded" & return after tFails
   else
      if the effective filename of stack tLibrary is not tFolder & "/mergJSONLibrary.livecodescript" then
         put "the library is" && the effective filename of stack tLibrary & return after tFails
      end if
      if the long id of stack tLibrary is not among the lines of the backScripts then
         put "the library is not in the back scripts" & return after tFails
      end if
   end if

   -- JSON both ways, through the library and the external
   put "{" & quote & "a" & quote & ":[1,{" & quote & "b" & quote & ":true}]}" into tJson
   try
      put JSONToArray(tJson) into tA
      if tA["a"][2]["b"] is not "true" then
         put "JSONToArray gives" && tourJoin(the keys of tA) & return after tFails
      end if
      if ArrayToJSON(tA) is not tJson then
         put "ArrayToJSON gives" && ArrayToJSON(tA) & return after tFails
      end if
   catch tA
      put "JSON both ways:" && tourJoin(tA) & return after tFails
   end try

   -- the standalone builder (revsblibrary): it offers the external for this
   -- platform, and would include this file for this computer's target. A
   -- Mac bundle is a folder, which the builder names with a slash at its
   -- end (__EnumerateFolder, __FilterExternalsForDesktop), as it did
   -- LiveCode's mergExt bundles in Ext
   try
      if "mergJSON" is not among the lines of revSBAdditionalExternalsList(revSBTargetToPlatform(tTarget)) then
         put "the standalone builder does not offer it:" && \
               tourJoin(revSBAdditionalExternalsList(revSBTargetToPlatform(tTarget))) & return after tFails
      else
         put revSBIncludedExternalPath(tTarget, "mergJSON") into tIncluded
         if the platform is "MacOS" and the last char of tIncluded is slash then
            delete the last char of tIncluded
         end if
         if tIncluded is not tFile then
            put "the standalone builder would include" && revSBIncludedExternalPath(tTarget, "mergJSON") & return after tFails
         end if
      end if
   catch tA
      put "the standalone builder:" && tourJoin(tA) & return after tFails
   end try

   if tFails is not empty then throw "failed:" && tourJoin(line 1 to -1 of tFails)
end tour_ext_mergjson

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

on tour_release_notes
   local tBefore, tNew
   put the openStacks into tBefore
   -- as Help > Release Notes does
   send "tOpenReleaseNotes" to card "Automatic Updates" of stack "revPreferencesGUI"
   tourWait 2000
   put tourNewStack(tBefore) into tNew
   if tNew is empty then throw "no Release Notes window opened"
   tourShotStack tNew, "24b-release-notes"
   close stack tNew
end tour_release_notes

-- Home on the desktop, as Help > Welcome to OXT-Beyond opens it, at the
-- size it opens at and made bigger, where its pages stay in the middle
on tour_home
   local tBefore, tNew, tRect
   put the openStacks into tBefore
   send "tOpenHome" to stack "revMenuBar"
   tourWait 2500
   put tourNewStack(tBefore) into tNew
   if tNew is empty then throw "no Home window opened"
   tourShotStack tNew, "24a-home"
   put the rect of stack tNew into tRect
   set the rect of stack tNew to item 1 of tRect, item 2 of tRect, item 1 of tRect + 1200, item 2 of tRect + 760
   tourWait 1500
   tourShotStack tNew, "24a-home-resized"
   close stack tNew
end tour_home

-- The IDE's own dialog in the look of Learn (palettes/kitdialog), as the
-- update check and the warning before a stack opens show it: modal, so it
-- is snapshot and closed by a message sent before it opens
on tour_kit_dialog
   local tSpec, tChoice
   put "OXT-Beyond Updates" into tSpec["title"]
   put "A message from the screenshot tour" into tSpec["heading"]
   put "In the look of Learn" into tSpec["subheading"]
   put "rocket" into tSpec["icon"]
   put "What it says:" & return & "- A first line" & return & "- A second line" & return & return & \
         "A last paragraph, long enough to wrap onto a second line of the dialog's panel of text." into tSpec["text"]
   put "A tip, on Learn's tinted panel." into tSpec["callout"]
   put "tip" into tSpec["calloutKind"]
   put "on mouseUp" & return & "   answer " & quote & "Hello" & quote & " -- in Learn's colours" & return & "end mouseUp" into tSpec["code"]
   put "Later" & return & "Open Release Page" into tSpec["buttons"]
   put "Later" into tSpec["cancel"]
   send "tourShotKitDialog" to me in 1500 milliseconds
   if not revIDEKitDialog(tSpec, tChoice) then throw "the dialog did not open"
   if tChoice is not "Later" then throw "the dialog chose" && quote & tChoice & quote & ", not Later"
end tour_kit_dialog

on tourShotKitDialog
   local tError
   try
      tourShotStack "revKitDialog", "24c-kit-dialog"
   catch tError
      tourRecord "INFO 24c-kit-dialog FAILED" && tourJoin(tError)
   end try
   if there is a stack "revKitDialog" and the mode of stack "revKitDialog" is not 0 then
      close stack "revKitDialog"
   end if
end tourShotKitDialog

-- Learn (palettes/learn), as Help > Lessons opens it: the first page of
-- the lessons, whose banner has "New to coding? Try the Academy", which
-- must be there, whole, where the page shows it
on tour_learn
   local tButton, tLabel, tOwner, tView, tRect, tError
   dispatch "revMenubarHelpMenuPick" to stack "revMenuBar" with "Lessons"
   if not tourWaitOpen(kLearn, 10000) then throw "Learn did not open"
   try
      -- (its first page, wherever Learn was left this session)
      dispatch "leShowSection" to stack kLearn with "lessons", 1
      tourWait 1500
      tourShotStack kLearn, "24d-learn"
      if there is not a group "p_heroB3" of this card of stack kLearn then
         throw "Learn's first page of the lessons has no third button (New to coding? Try the Academy)"
      end if
      put the long id of group "p_heroB3" of this card of stack kLearn into tButton
      put field "p_heroB3_label" of this card of stack kLearn into tLabel
      tourRecord "INFO Learn's Academy button:" && quote & tLabel & quote && "rect" && the rect of tButton
      if tLabel is not "New to coding? Try the Academy" then
         throw "Learn's third button says" && quote & tLabel & quote & ", not New to coding? Try the Academy"
      end if
      if not the visible of tButton then throw "Learn's Academy button is hidden"
      -- whole: inside each group that holds it (each clips what it holds:
      -- the banner, the page, the part of the window the page shows) and
      -- inside the window
      put the rect of tButton into tRect
      put the long id of the owner of tButton into tOwner
      repeat while word 1 of tOwner is "group"
         put the rect of tOwner into tView
         if item 1 of tRect < item 1 of tView or item 2 of tRect < item 2 of tView \
               or item 3 of tRect > item 3 of tView or item 4 of tRect > item 4 of tView then
            throw "Learn's Academy button (" & tRect & ") is cut off by the group" && the short name of tOwner && "(" & tView & ")"
         end if
         put the long id of the owner of tOwner into tOwner
      end repeat
      if item 3 of tRect > the width of stack kLearn or item 4 of tRect > the height of stack kLearn then
         throw "Learn's Academy button (" & tRect & ") is cut off by the window (" & the width of stack kLearn & "x" & the height of stack kLearn & ")"
      end if
   catch tError
   end try
   if there is a stack kLearn and the mode of stack kLearn is not 0 then close stack kLearn
   if tError is not empty then throw tError
end tour_learn

-- The xTalk Academy (palettes/academy), as Help > xTalk Academy opens it:
-- the first page of its first course, with the courses in the sidebar,
-- then the lesson "Hello, xTalk" with its first example tried in the
-- playground, as its Try it does, which must have run and put its line.
-- What the Academy keeps of a learner (the preferences cAcademy: the
-- place, the lessons done, the drafts) is put back as it was, and the
-- Message Box closed again when the step opened it.
on tour_academy
   local tSaved, tMsgOpen, tError, tCourses, tStatus, tOut, tExample, i
   if there is not a stack "revPreferences" then throw "no revPreferences stack"
   put the customProperties["cAcademy"] of stack "revPreferences" into tSaved
   put (there is a stack "Message Box" and the mode of stack "Message Box" is not 0) into tMsgOpen
   try
      dispatch "revMenubarHelpMenuPick" to stack "revMenuBar" with "xTalk Academy"
      if not tourWaitOpen(kAcademy, 10000) then throw "the Academy did not open"
      -- the first page of the first course, wherever a learner left it
      dispatch "acGoTo" to stack kAcademy with "basics", 0
      tourWait 1500
      tourShotStack kAcademy, "24e-academy"
      -- the courses in the sidebar, one each
      dispatch function "revAcademyCourses" to stack kAcademy
      put the result into tCourses
      tourRecord "INFO the Academy's courses:" && tCourses["count"]
      if not (tCourses["count"] >= 3) then throw "the Academy has" && tCourses["count"] && "courses, not 3 or more"
      repeat with i = 1 to tCourses["count"]
         if there is not a control ("nav_" & i) of this card of stack kAcademy then
            throw "the Academy's sidebar does not list the course" && tCourses[i]["title"]
         end if
      end repeat
      if the number of lines of field "idx" of stack kAcademy < 3 then throw "the Academy's sidebar has no index of the lessons"
      -- a lesson, and its first example tried: its Try it button is
      -- p_c<N>_try, N the example's block of the lesson, and sends
      -- lkAction "try N" (acCodeBlock)
      dispatch "acGoTo" to stack kAcademy with "basics", "hello"
      tourWait 1200
      put empty into tExample
      repeat with i = 1 to 40
         if there is a control ("p_c" & i & "_try") of this card of stack kAcademy then
            put i into tExample
            exit repeat
         end if
      end repeat
      if tExample is empty then throw "the lesson Hello, xTalk has no Try it button"
      dispatch "lkAction" to stack kAcademy with "try" && tExample
      tourWait 1500
      put field "outStatus" of stack kAcademy into tStatus
      put the text of field "out" of stack kAcademy into tOut
      tourRecord "INFO the Academy's output:" && quote & tStatus & quote && "|" && tourJoin(tOut)
      -- What an example puts goes to the Academy's output only (the IDE's
      -- Message Box opened over the lesson until the IDE left the
      -- Academy's stage out of it)
      if not tMsgOpen and there is a stack "Message Box" and the mode of stack "Message Box" is not 0 then
         close stack "Message Box"
         throw "the Message Box opened over the Academy when the example ran"
      end if
      tourShotStack kAcademy, "24e-academy-lesson"
      if not (field "playWhat" of stack kAcademy begins with "An example from the lesson") then
         throw "the playground does not have the example (" & field "playWhat" of stack kAcademy & ")"
      end if
      if tStatus is "Stopped" or not (tStatus begins with "Ran") then
         throw "the example did not run:" && tStatus & ":" && tourJoin(tOut)
      end if
      if line 1 of tOut is not "Hello, world!" then
         throw "the example put" && quote & tourJoin(tOut) & quote & ", not Hello, world!"
      end if
      close stack kAcademy
   catch tError
   end try
   if there is a stack kAcademy and the mode of stack kAcademy is not 0 then close stack kAcademy
   if not tMsgOpen and there is a stack "Message Box" and the mode of stack "Message Box" is not 0 then close stack "Message Box"
   set the customProperties["cAcademy"] of stack "revPreferences" to tSaved
   if tError is not empty then throw tError
end tour_academy

-- The xTalk Assistant (ide/Extensions/org.openxtalk.plugin.xtalkassistant):
-- its window, its Settings dialog and its Memory window, in Learn's look.
-- Only the windows are opened: there is no key (the API keys of the
-- environment are put aside for the step) and no server of the user's
-- own, and a model is chosen, so it asks no provider for anything, and
-- Send is never pressed. With no key it asks for one in its Settings when
-- it opens, as it does for a user who has just turned it on. Both dialogs
-- are modal, so each is snapshot and closed (which saves nothing) by a
-- message sent before it opens. Then it is put back: turned off again as
-- its More menu does, its windows, error hook and libraries gone (the
-- frontScripts and the stacksInUse as they were, which the step checks),
-- and its preferences and the environment as they were.
local sXta

on tour_xtalk_assistant
   local tPrefs, tPref, tSaved, tWasOn, tWasOpen, tSockets, tFront, tInUse, tPending, tError
   if there is not a stack kXtaMain then
      tourRecord "INFO xtalk-assistant: this IDE has no xTalk Assistant"
      exit tour_xtalk_assistant
   end if
   if toLower($OXTBEYOND_XTALK_ASSISTANT) is among the items of "off,0,false,no" then
      tourRecord "INFO xtalk-assistant: turned off by OXTBEYOND_XTALK_ASSISTANT, so not opened"
      exit tour_xtalk_assistant
   end if
   put "cXTalkAssistant,enabled" & return & "cXTalkAssistant,provider" & return & \
         "cXTalkAssistant,model,anthropic" & return & "cXTalkAssistant,baseUrl,anthropic" into tPrefs
   repeat for each line tPref in tPrefs
      put revIDEGetPreference(tPref) into tSaved[tPref]
   end repeat
   put $ANTHROPIC_API_KEY into tSaved["$ANTHROPIC_API_KEY"]
   put $OPENAI_API_KEY into tSaved["$OPENAI_API_KEY"]
   dispatch function "xtaIsEnabled" to stack kXtaMain
   put (the result is true) into tWasOn
   put (there is a stack kXtaWindow and the mode of stack kXtaWindow is not 0) into tWasOpen
   put the openSockets into tSockets
   put the frontScripts into tFront
   put the stacksInUse into tInUse
   put empty into sXta
   try
      revIDESetPreference "cXTalkAssistant,enabled", true
      revIDESetPreference "cXTalkAssistant,provider", "anthropic"
      revIDESetPreference "cXTalkAssistant,baseUrl,anthropic", empty
      if revIDEGetPreference("cXTalkAssistant,model,anthropic") is empty then
         revIDESetPreference "cXTalkAssistant,model,anthropic", "claude-opus-5-5"
      end if
      put empty into $ANTHROPIC_API_KEY
      put empty into $OPENAI_API_KEY
      -- Development > Plugins > xTalk Assistant; with no key it asks for
      -- one in its Settings, over its window, at once
      send "tourShotXta" to me in 2500 milliseconds
      put the result into tPending
      dispatch "xtalkAssistantMenuPick" to stack kXtaMain
      if sXta["settings"] is empty then cancel tPending
      if not tourWaitOpen(kXtaWindow, 5000) then throw "the xTalk Assistant's window did not open"
      tourWait 500
      tourXtaLook kXtaWindow, "Send,Provider,Model,More"
      if the mode of stack kXtaWindow is not 4 then tourXtaProblem "the window is not a palette (mode" && the mode of stack kXtaWindow & ")"
      if field "Status" of stack kXtaWindow is empty then tourXtaProblem "the window's status line is empty"
      tourRecord "INFO xTalk Assistant status:" && field "Status" of stack kXtaWindow
      tourShotStack kXtaWindow, "24f-xtalk-assistant"
      -- More > Settings..., when it did not ask for a key as it opened
      if sXta["settings"] is empty then
         send "tourShotXta" to me in 1500 milliseconds
         dispatch "xtaMoreMenuPick" to stack kXtaMain with "Settings..."
      end if
      if sXta["settings"] is empty then throw "the xTalk Assistant's Settings did not open"
      -- More > Memory...
      send "tourShotXtaMemory" to me in 1500 milliseconds
      dispatch "xtaMoreMenuPick" to stack kXtaMain with "Memory..."
      if sXta["memory"] is empty then throw "the xTalk Assistant's Memory window did not open"
      if sXta["problems"] is not empty then throw "the xTalk Assistant:" && tourJoin(sXta["problems"])
      if the openSockets is not tSockets then
         throw "the xTalk Assistant opened a socket:" && tourJoin(the openSockets)
      end if
   catch tError
   end try
   -- put back
   if there is a stack kXtaSettings and the mode of stack kXtaSettings is not 0 then close stack kXtaSettings
   if there is a stack kXtaMemory and the mode of stack kXtaMemory is not 0 then close stack kXtaMemory
   -- turned off as it was, as More > Turn Off xTalk Assistant does once
   -- its question is answered Turn Off (xtaTurnOff: its windows, the
   -- error hook and its libraries go). Not with extensionFinalize, which
   -- the IDE's own frontscripts hear too: one of them took itself out of
   -- the message path.
   if not tWasOn then
      dispatch function "xtaIsEnabled" to stack kXtaMain
      if the result is true then
         send "tourXtaTurnOff" to me in 1000 milliseconds
         dispatch "xtaMoreMenuPick" to stack kXtaMain with "Turn Off xTalk Assistant"
      end if
   else if not tWasOpen and there is a stack kXtaWindow and the mode of stack kXtaWindow is not 0 then
      close stack kXtaWindow
   end if
   repeat for each line tPref in tPrefs
      revIDESetPreference tPref, tSaved[tPref]
   end repeat
   put tSaved["$ANTHROPIC_API_KEY"] into $ANTHROPIC_API_KEY
   put tSaved["$OPENAI_API_KEY"] into $OPENAI_API_KEY
   if tError is empty and not tWasOn then
      if there is a stack kXtaWindow then put "its window is still there" into tError
      if the frontScripts is not tFront then
         put "the frontScripts are not as they were:" && tourJoin(the frontScripts) into tError
      end if
      if the stacksInUse is not tInUse then
         put "the stacksInUse are not as they were:" && tourJoin(the stacksInUse) into tError
      end if
      if tError is not empty then put "the xTalk Assistant was not put back:" && tError into tError
   end if
   if tError is not empty then throw tError
end tour_xtalk_assistant

-- (sent) Answers the question of More > Turn Off xTalk Assistant with
-- Turn Off, as a click on that button of the Answer Dialog does
on tourXtaTurnOff
   if there is a stack "Answer Dialog" and the mode of stack "Answer Dialog" is not 0 \
         and there is a button "Turn Off" of stack "Answer Dialog" then
      send "mouseUp" to button "Turn Off" of stack "Answer Dialog"
   else
      tourXtaProblem "Turn Off xTalk Assistant asked nothing"
      tourCloseDialogs
   end if
end tourXtaTurnOff

-- (sent) The assistant's Settings dialog, then closed
on tourShotXta
   local tError
   try
      if not tourWaitOpen(kXtaSettings, 5000) then throw "the Settings did not open"
      tourWait 500
      tourXtaLook kXtaSettings, "Save,Cancel"
      tourShotStack kXtaSettings, "24f-xtalk-assistant-settings"
      put true into sXta["settings"]
   catch tError
      tourXtaProblem tourJoin(tError)
   end try
   -- (closed, as its close box does, it saves nothing: xtaSettingsDone)
   if there is a stack kXtaSettings and the mode of stack kXtaSettings is not 0 then close stack kXtaSettings
end tourShotXta

on tourShotXtaMemory
   local tError
   try
      if not tourWaitOpen(kXtaMemory, 5000) then throw "the Memory window did not open"
      tourWait 500
      tourXtaLook kXtaMemory, "Save,Cancel,Forget"
      if there is not a field "You" of stack kXtaMemory then tourXtaProblem "the Memory window has no notes about you"
      tourShotStack kXtaMemory, "24f-xtalk-assistant-memory"
      put true into sXta["memory"]
   catch tError
      tourXtaProblem tourJoin(tError)
   end try
   -- (closed, it answers Cancel: cXtaChoice)
   if there is a stack kXtaMemory and the mode of stack kXtaMemory is not 0 then close stack kXtaMemory
end tourShotXtaMemory

-- Learn's look (#167): the card on Learn's slate, the dark header with
-- the violet mark, and the buttons pButtons
command tourXtaLook pStack, pButtons
   local tName
   if the backgroundColor of this card of stack pStack is not "241,245,249" then
      tourXtaProblem pStack && "is not on Learn's slate (" & the backgroundColor of this card of stack pStack & ")"
   end if
   repeat for each item tName in "uiBand,uiMark"
      if there is not a graphic tName of this card of stack pStack then tourXtaProblem pStack && "has no" && tName
   end repeat
   repeat for each item tName in pButtons
      if there is not a button tName of this card of stack pStack then tourXtaProblem pStack && "has no button" && tName
   end repeat
end tourXtaLook

command tourXtaProblem pText
   tourRecord "INFO xtalk-assistant:" && pText
   put pText & return after sXta["problems"]
end tourXtaProblem

-- xTalk Chat (ide/Extensions/org.openxtalk.plugin.xtalkchat), as
-- Development > Plugins > xTalk Chat opens it, before going online: its
-- welcome. It goes online only when the user presses Go online, or when
-- they were online as they last closed it (its preference autoOnline),
-- which is turned off for the step, so nothing connects; it must still be
-- offline, with no relay and no new socket, when it is snapshot. Its
-- preferences are put back as they were, and closing the window lets its
-- core go (xtchWindowClosed).
on tour_xtalk_chat
   local tPrefs, tPref, tSaved, tSockets, tOnline, tRelays, tError
   if there is not a stack kChatMain then
      tourRecord "INFO xtalk-chat: this IDE has no xTalk Chat"
      exit tour_xtalk_chat
   end if
   if toLower($OXTBEYOND_XTALK_CHAT) is among the items of "off,0,false,no" then
      tourRecord "INFO xtalk-chat: turned off by OXTBEYOND_XTALK_CHAT, so not opened"
      exit tour_xtalk_chat
   end if
   if there is a stack kChatWindow and the mode of stack kChatWindow is not 0 then
      tourRecord "INFO xtalk-chat: its window is open already, so not snapshot"
      exit tour_xtalk_chat
   end if
   put "autoOnline,showClient,relays,muted,lastView" into tPrefs
   repeat for each item tPref in tPrefs
      put revIDEGetPreference("cXTalkChat," & tPref) into tSaved[tPref]
   end repeat
   put the openSockets into tSockets
   try
      revIDESetPreference "cXTalkChat,autoOnline", false
      dispatch "xtalkChatMenuPick" to stack kChatMain
      if not tourWaitOpen(kChatWindow, 10000) then throw "xTalk Chat's window did not open"
      tourWait 1500
      dispatch function "xtcIsOnline" to stack kChatCore
      put the result into tOnline
      dispatch function "xtcRelayStatus" to stack kChatCore
      put the result into tRelays
      tourRecord "INFO xTalk Chat: online" && tOnline & "; relays" && quote & tourJoin(tRelays) & quote
      tourShotStack kChatWindow, "24g-xtalk-chat"
      if tOnline is not false then throw "xTalk Chat is online (" & tOnline & ")"
      if tRelays is not empty then throw "xTalk Chat has relays:" && tourJoin(tRelays)
      if the openSockets is not tSockets then throw "xTalk Chat opened a socket:" && tourJoin(the openSockets)
      if there is not a group "welcome" of this card of stack kChatWindow then throw "xTalk Chat does not show its welcome"
   catch tError
   end try
   if there is a stack kChatWindow and the mode of stack kChatWindow is not 0 then close stack kChatWindow
   tourWait 300
   repeat for each item tPref in tPrefs
      revIDESetPreference "cXTalkChat," & tPref, tSaved[tPref]
   end repeat
   if tError is not empty then throw tError
end tour_xtalk_chat

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
-- The inspector's header must show its sections as tabs: on macOS 26 a
-- forum report (viewtopic.php?p=25148) showed a button's inspector with
-- the header strip empty and no way to reach any section but Basic
command tourInspectorHeaderCheck pStack
   local tNav
   if there is not a widget "header_background" of group "background" of stack pStack then
      throw pStack && "has no header widget, so no section tabs"
   end if
   put the navData of widget "header_background" of group "background" of stack pStack into tNav
   if the number of elements of tNav < 2 then
      throw pStack && "shows" && the number of elements of tNav && "section tabs in its header"
   end if
   tourRecord "INFO" && pStack && "header:" && the number of elements of tNav && "section tabs"
end tourInspectorHeaderCheck

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

-- Waits, at most pMilliseconds, for the stack pStack to be open and shown
function tourWaitOpen pStack, pMilliseconds
   repeat (pMilliseconds div 250) times
      if there is a stack pStack and the mode of stack pStack is not 0 and the visible of stack pStack then return true
      tourWait 250
   end repeat
   return there is a stack pStack and the mode of stack pStack is not 0 and the visible of stack pStack
end tourWaitOpen

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
