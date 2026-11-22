script "oxt_everyday"
-- Everyday tasks: what a person does with the IDE on an ordinary day,
-- done through the IDE's own windows, each outcome checked and each
-- snapshot taken. Run inside the real IDE by tools/ci/ui_tour.py, which
-- names this file on the command line (--script), as it does the UI
-- tour (tools/ci/ui-tour.livecodescript), on Linux, Windows and macOS,
-- light and dark.
--
-- The tour opens the IDE's windows and looks at them; the smoke test
-- runs the engine on its own, and the standalone check builds and runs a
-- standalone. None of them makes a stack the way a person does: here a
-- new stack comes from File > New Stack, its controls are dragged out of
-- the Tools palette with the system's mouse, they are named and coloured
-- by typing in the Inspector, a handler is typed into the Script Editor
-- and applied (and a mistake in it shows in its Errors pane), the stack
-- is saved and opened again through the IDE's own file dialog, and so
-- on: each task in kTasks below says what it does and what it checks.
--
-- How a task acts, as a person would:
--   - a menu item: the menu bar's own menu as the IDE builds it now (the
--     item must be there and enabled), then the menuPick a pick of it
--     sends (edMenu)
--   - a click, a drag and typing: the engine's click at, drag and type,
--     into the window a person would use, so the IDE's own handlers of
--     the mouse and the keys run (edClickAt, edDragIn, edType)
--   - a control from the Tools palette: the system's mouse drags its tile
--     onto the stack (xdotool, PowerShell's mouse_event or CGEventPost);
--     where the system's mouse does not reach the IDE (edInputWorks) the
--     tile gets the double-click that also makes one, and that is noted
--   - a shortcut: its keys pressed on the system's keyboard (xdotool,
--     SendKeys or CGEventPost) where they reach the IDE (edKeysWork), so
--     that the menu bar's own accelerator answers them; else typed by the
--     engine with the key held, and that is noted (edShortcut)
--   - a file: the IDE's own file dialog (the stack "File Selector",
--     which the engine opens when the systemFileSelector is false): a
--     name typed into it and its Save or Open button clicked
-- Each waits until what it waits for is so (edWaitFor), not a fixed time.
-- A task that fails throws; the next task starts from what the tasks
-- before left, so a task whose stack is missing fails too, by name.
--
-- Environment and lines: as the tour's (OXT_TOUR_OUT, OXT_TOUR_LOG,
-- OXT_TOUR_ONLY, OXT_TOUR_APPEARANCE; STARTED, INFO, ERROR, SHOT, STEP
-- <name> ok | FAILED <why>, DONE). OXT_TOUR_ONLY names tasks; the tasks
-- before a named one that it needs (the stack, its controls) run too.

constant kTasks = "start,new-stack,window-menu,appbrowser-watch,make-button,make-field,make-checkbox,make-radio,make-option-menu,make-scrollbar,make-graphic,make-label,inspector-name,inspector-label,inspector-colour,inspector-text-size,inspector-stack-name,script-type-apply,script-compile-error,script-fix-apply,browse-runs-it,message-box-line,message-box-lines,message-box-shortcut,select-move-undo,undo-twice-redoes,delete-undo,copy-paste,shortcut-copy-paste,duplicate,group,ungroup,align,new-card,project-browser-cards,go-card,delete-card,save-as,appbrowser-still-open,appbrowser-open,appbrowser-names,appbrowser-expand,appbrowser-select,appbrowser-script,appbrowser-collapse,close-reopen,save-again,revert-to-saved,save-as-second-name,se-find-replace,debug-breakpoint,dictionary-search,import-image,image-as-icon,geometry-manager,preferences-change,quick-start-first-lesson,quick-start-dropped-shows,standalone-stopped-build,standalone-mc-stack-file,standalone-built-and-run,standalone-engine-missing,import-image-system-dialog,finish"
-- (the names the tasks give what they make)
constant kStack = "Everyday Stack"
constant kFile = "everyday.oxtstack"
-- the file of save-as-second-name
constant kSecondFile = "everyday-second.oxtstack"
-- the stack of standalone-mc-stack-file, and its file
constant kMcStack = "Everyday Mc"
constant kMcFile = "everyday-old.mc"
-- the stack of standalone-built-and-run, its file, the standalone's name
-- and what its field says (the standalone reports it back)
constant kAppStack = "Everyday App"
constant kAppFile = "everyday-app.livecode"
constant kAppName = "EverydayApp"
constant kAppGreeting = "Hello from a standalone"
-- Learn's first example, the Quick Start Guide (its file in the IDE's
-- Resources folder, and its name), and the lesson done in it
constant kGuideFile = "Examples/Remastered/Quick Start Guide.oxtstack"
constant kGuideStack = "Quick Start Guide"
constant kGuideLesson = "Orientation"
-- the builder's word at the end of a build that worked (its dialog)
constant kBuildSaved = "Standalone application saved successfully."
-- more dialogs than a build has to say (it has that one): at the next
-- one the build is stopped (edBuildSaid)
constant kBuildDialogs = 4
-- the builder's word when the engine it attaches is not there: the first
-- line of its dialog (the file it looked for is the second)
constant kBuildNoEngine = "Ensure that you have not renamed the main OXT-Beyond executable file:"

local sOut, sLog, sOnly, sStarted, sWatchdog, sWatchdogCount
local sWork, sStack, sInput, sSaved, sDebug, sReport, sKeep, sSkip

on openStack
   if sStarted is not true and $OXT_TOUR_LOG is not empty then
      put true into sStarted
      put $OXT_TOUR_OUT into sOut
      put $OXT_TOUR_LOG into sLog
      put $OXT_TOUR_ONLY into sOnly
      hide stack "oxt_everyday"
      send "edWhenStarted 0" to me in 1 second
   end if
   pass openStack
end openStack

-- as the tour: until the IDE has finished starting
on edWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then put the cREVLaunching of stack "Home" into tLaunching
   if tLaunching is true and pTries < 120 then
      send "edWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "edRun" to me in 2 seconds
   end if
end edWhenStarted

on edRun
   local tTask, tHandler, tError, tWanted, tStarted
   edRecord "STARTED"
   edRecord "INFO platform" && the platform && the systemVersion && the processor
   edRecord "INFO version" && the version && the buildNumber
   edRecord "INFO screenRect" && the screenRect
   edCatchErrors
   put edWanted(sOnly) into tWanted
   repeat for each item tTask in kTasks
      if tTask is not among the items of tWanted then next repeat
      put "ed_" & tTask into tHandler
      replace "-" with "_" in tHandler
      put 0 into sWatchdogCount
      put the milliseconds into tStarted
      -- (no dialog answer still waiting from the task before)
      edCancelPending "edAnswerWith,edKitDialogAnswer,edFileDialogAnswer"
      send "edWatchdog" && quote & tTask & quote to me in 30 seconds
      put the result into sWatchdog
      try
         dispatch tHandler to me
         if the result is "skipped" then
            edRecord "STEP" && tTask && "ok (skipped:" && sSkip & ")"
         else
            edRecord "STEP" && tTask && "ok"
         end if
      catch tError
         edRecord "STEP" && tTask && "FAILED" && edJoin(tError)
         try
            edShotScreen "zz-failed-" & tTask
         catch tError
         end try
         edTidyAfterFailure tTask
      end try
      cancel sWatchdog
      edRecord "INFO time" && tTask && the milliseconds - tStarted && "ms"
      edNoteEdited tTask
      put empty into sReport
      put empty into sSkip
      edUnlockScreen tTask
      edCloseDialogs
   end repeat
   edRecord "DONE"
end edRun

-- The task after which the IDE first marked the stack as edited since it
-- was last saved, logged: a task that only looks (the App Browser's) must
-- not mark it, or Close asks to save changes nobody made
local sEditedBy

command edNoteEdited pTask
   local tEdited, tError
   if sStack is empty or not edInMemory(sStack) then
      exit edNoteEdited
   end if
   try
      put revIDEStackIsEdited(the short name of stack sStack) into tEdited
   catch tError
      exit edNoteEdited
   end try
   if tEdited is true and sEditedBy is empty then
      put pTask into sEditedBy
      edRecord "INFO the stack is marked as edited after" && pTask
   else if tEdited is not true and sEditedBy is not empty then
      put empty into sEditedBy
      edRecord "INFO the stack is no longer marked as edited after" && pTask
   end if
end edNoteEdited

-- The tasks to run: all, or those named and every task before them that
-- they build on (start and finish always)
function edWanted pOnly
   local tAll, tTask, tLast, tIndex
   if pOnly is empty then return kTasks
   put 0 into tLast
   put 0 into tIndex
   repeat for each item tTask in kTasks
      add 1 to tIndex
      if tTask is among the items of pOnly then put tIndex into tLast
   end repeat
   put item 1 to tLast of kTasks & ",finish" into tAll
   return tAll
end edWanted

-- Script errors in the IDE's windows go to the log (as the tour does),
-- not to a dialog that would wait for a person
command edCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      revIDESetPreference "cDesktopClickToHide", false
      put the defaultStack into tDefault
      set the defaultStack to "oxt_everyday"
      lock messages
      create invisible button "oxt_everyday_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "edScriptError" & quote & " to stack " & quote & "oxt_everyday" & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      edRecord "INFO catching errors:" && edJoin(tError)
   end try
end edCatchErrors

on edScriptError pError
   edRecord "ERROR" && edJoin(pError)
end edScriptError

----------------------------------------------------------------
-- The tasks

-- A folder of its own for the stack and the picture; the IDE's own file
-- dialog (the systemFileSelector is set back at the end); typing at a
-- person's pace would take minutes, so the typingRate is short; and
-- whether the system's mouse reaches the IDE here.
-- The folder is this run's alone: its name has the process in it. On
-- Linux the light and the dark run start together, and named by the
-- milliseconds alone they once had one folder for both: the dark run's
-- Save As found the light run's stack there and the IDE asked whether to
-- replace it, and each then opened what the other had saved
on ed_start
   put specialFolderPath("temporary") & "/oxt-everyday-" & the milliseconds & "-" & the processID into sWork
   if there is a folder sWork or there is a file sWork then throw "the work folder" && sWork && "is there already: this run would share it"
   create folder sWork
   if there is not a folder sWork then throw "could not make the folder" && sWork
   edRecord "INFO work folder" && sWork
   set the defaultFolder to sWork
   put the systemFileSelector into sSaved["systemFileSelector"]
   put the typingRate into sSaved["typingRate"]
   set the systemFileSelector to false
   set the typingRate to 2
   put revIDEGetPreference("revTools_look") into sSaved["toolsLook"]
   edRecord "INFO the Tools palette's look:" && quote & sSaved["toolsLook"] & quote
   revIDEOpenPalette "tools"
   if not edWaitFor("edOpen(" & quote & "revTools" & quote & ")", 5000) then throw "the Tools palette is not open"
   put edInputWorks() into sInput
   edRecord "INFO the system's mouse reaches the IDE:" && sInput
end ed_start

-- File > New Stack > Default Size: a new stack, in front, to edit
on ed_new_stack
   local tBefore
   put the openStacks into tBefore
   edMenu "File", "New Stack|Default Size"
   if not edWaitFor("edNewStack(pAx) is not empty", 5000, tBefore) then throw "File > New Stack made no stack"
   put edNewStack(tBefore) into sStack
   edRecord "INFO new stack" && sStack && the rect of stack sStack
   if the mode of stack sStack is not 1 then throw "the new stack is not a stack to edit (mode" && the mode of stack sStack & ")"
   if the short name of the topStack is not sStack then throw "the new stack is not in front:" && the short name of the topStack
   if the number of controls of card 1 of stack sStack is not 0 then throw "the new stack is not empty"
   edShotStack sStack, "01-new-stack"
end ed_new_stack

-- The Window menu lists the IDE's windows that are open, not only the
-- user's stacks, the script editors and the Dictionary, the Message Box,
-- the Tools palette and the Project Browser (OpenXTalkPaul, openxtalk.org
-- p=26643): Tools > Extension Manager, then Object > Stack Inspector, and
-- each has its line, after the lines the menu had, which stay as they
-- were; and with the stack in front of the Extension Manager, its line
-- picked brings it back in front
on ed_window_menu
   local tEM, tPI, tItems, tLine, tLabels, tStackAt, tToolsAt, tEMAt, tPIAt, tLast
   put revIDEPaletteToStackName("extension manager") into tEM
   edFront
   edMenu "Tools", "Extension Manager"
   if not edWaitFor("edOpen(pAx)", 10000, tEM) then throw "Tools > Extension Manager opened nothing"
   edCloseInspectors
   edFront
   edMenu "Object", "Stack Inspector"
   put edInspector(5000) into tPI
   put edMenuItems("Window") into tItems
   set the itemDelimiter to tab
   repeat for each line tLine in tItems
      put item 2 of tLine & ", " after tLabels
   end repeat
   set the itemDelimiter to comma
   edRecord "INFO the Window menu:" && char 1 to -3 of tLabels && "(" & edMenuNames(tItems) & ")"
   put edMenuAt(tItems, the name of stack sStack) into tStackAt
   put edMenuAt(tItems, "stack" && quote & "revTools" & quote) into tToolsAt
   put edMenuAt(tItems, "stack" && quote & tEM & quote) into tEMAt
   put edMenuAt(tItems, "stack" && quote & tPI & quote) into tPIAt
   put the number of lines of tItems into tLast
   if tStackAt is 0 then throw "the Window menu does not list the stack" && sStack
   if tToolsAt is 0 then throw "the Window menu does not list the Tools palette"
   if tEMAt is 0 then throw "the Window menu does not list the open Extension Manager"
   if tPIAt is 0 then throw "the Window menu does not list the open Inspector" && tPI
   if line tEMAt of tItems is not ("stack" && quote & tEM & quote & tab & "Extension Manager" & tab & true) then
      throw "the Extension Manager's line is" && line tEMAt of tItems
   end if
   -- (named by what it inspects, its title)
   set the itemDelimiter to tab
   if not (item 2 of line tPIAt of tItems begins with "Inspector: ") then
      throw "the Inspector's line is" && line tPIAt of tItems
   end if
   set the itemDelimiter to comma
   if not (tStackAt < tToolsAt and tToolsAt < tEMAt and tToolsAt < tPIAt) then
      throw "the Window menu's lines are out of order: the stack" && tStackAt & ", Tools" && tToolsAt & ", the Extension Manager" && tEMAt & ", the Inspector" && tPIAt
   end if
   if line tLast of tItems is not ("Send Window to Back" & tab & "Send Window to Back" & tab & true) then
      throw "the Window menu does not end with Send Window to Back:" && line tLast of tItems
   end if
   edCloseInspectors
   go stack sStack
   if not edWaitFor("edFrontOf(pAx, pBx)", 3000, sStack, tEM) then
      throw "the stack did not come in front of the Extension Manager:" && edJoin(the windows)
   end if
   edMenu "Window", "stack" && quote & tEM & quote
   if not edWaitFor("edFrontOf(pAx, pBx)", 5000, tEM, sStack) then
      throw "Window > Extension Manager did not bring it in front of the stack:" && edJoin(the windows)
   end if
   edShotStack tEM, "01-window-menu"
   close stack tEM
   edFront
end ed_window_menu

on ed_make_button
   edMake "Button", "button", "02-make-button"
end ed_make_button

on ed_make_field
   edMake "Field", "field", "03-make-field"
end ed_make_field

on ed_make_checkbox
   edMake "Checkbox", "button", "04-make-checkbox"
end ed_make_checkbox

on ed_make_radio
   edMake "RadioButton", "button", "05-make-radio"
end ed_make_radio

on ed_make_option_menu
   edMake "OptionMenu", "button", "06-make-option-menu"
end ed_make_option_menu

on ed_make_scrollbar
   edMake "Slider", "scrollbar", "07-make-slider"
end ed_make_scrollbar

on ed_make_graphic
   edMake "RectangleGraphic", "graphic", "08-make-graphic"
end ed_make_graphic

on ed_make_label
   edMake "LabelField", "field", "09-make-label"
end ed_make_label

-- Inspector: the name typed into Basic's Name and Return pressed; the
-- button has the name, and the Project Browser and the window's title
-- would show it
on ed_inspector_name
   local tPI, tButton
   put edControl("button") into tButton
   put edInspect(tButton) into tPI
   edTypeInEditor tPI, "name", "Okay"
   if not edWaitFor("the short name of pAx is " & quote & "Okay" & quote, 3000, tButton) then
      throw "the Inspector's Name did not name the button (" & the short name of tButton & ")"
   end if
   -- (its copies will be called Okay too: the tasks find it by its ID)
   put the short id of tButton into sKeep["okay"]
   edShotStack tPI, "10-inspector-name"
end ed_inspector_name

on ed_inspector_label
   local tPI, tButton
   put edControl("button") into tButton
   put edInspect(tButton) into tPI
   edTypeInEditor tPI, "label", "Press me"
   if not edWaitFor("the label of pAx is " & quote & "Press me" & quote, 3000, tButton) then
      throw "the Inspector's Label did not label the button (" & the label of tButton & ")"
   end if
   edShotStack sStack, "11-inspector-label"
end ed_inspector_label

-- Colors: Background fill given as the colour dialog gives it (the tour
-- clicks the swatch's menu; the dialog itself is the system's); the
-- button has the colour and the screen shows it
on ed_inspector_colour
   local tPI, tButton, tEditor, tSwatch, tPoint, tPixel
   put edControl("button") into tButton
   put edInspect(tButton) into tPI
   get edSection(tPI, "Colors")
   put edEditor(tPI, "backgroundColor") into tEditor
   if tEditor is empty then throw "the button's Inspector has no Background fill"
   put the long id of control 1 of tEditor into tSwatch
   set the swatchColor of tSwatch to "0,160,0"
   dispatch "valueChanged" to tEditor
   if not edWaitFor("the backgroundColor of pAx is " & quote & "0,160,0" & quote, 3000, tButton) then
      throw "the Inspector's Background fill did not colour the button (" & the backgroundColor of tButton & ")"
   end if
   edShotStack tPI, "12-inspector-colour"
end ed_inspector_colour

-- Text: the size typed into Text size; the field has it
on ed_inspector_text_size
   local tPI, tField
   put edControl("field") into tField
   put edInspect(tField) into tPI
   get edSection(tPI, "Text")
   edTypeInEditor tPI, "textSize", "20"
   if not edWaitFor("the textSize of pAx is 20", 3000, tField) then
      throw "the Inspector's Text size did not size the field's text (" & the textSize of tField & ")"
   end if
   edShotStack tPI, "13-inspector-text-size"
end ed_inspector_text_size

-- Object > Stack Inspector: the stack's name typed in; the stack is
-- called that from now on (and saved under it)
on ed_inspector_stack_name
   local tPI, tOld
   put sStack into tOld
   edCloseInspectors
   edFront
   edMenu "Object", "Stack Inspector"
   put edInspector(5000) into tPI
   edTypeInEditor tPI, "name", kStack
   if not edWaitFor("there is a stack kStack", 3000) then throw "the Stack Inspector's Name did not rename the stack" && tOld
   put kStack into sStack
   edCloseInspectors
   edShotStack sStack, "09b-stack-renamed"
end ed_inspector_stack_name

-- Object > Object Script on the button; a handler typed (the editor
-- writes its end and indents) and Apply clicked: the button has it
on ed_script_type_apply
   local tSE, tButton, tField
   put edControl("button") into tButton
   put edOpenScript(tButton) into tSE
   put edSeField(tSE) into tField
   edClickAt tSE, the loc of tField
   select text of tField
   edType tSE, "on mouseUp" & return & "put the label of me into field 1" & return & "set the cClicks of me to the cClicks of me + 1"
   edApply tSE
   if not edWaitFor("the script of pAx contains " & quote & "set the cClicks of me" & quote, 3000, tButton) then
      throw "Apply did not give the button its script:" && edJoin(the script of tButton)
   end if
   if edSeErrors(tSE) is not empty then throw "Apply of a script that compiles shows an error:" && edSeErrors(tSE)
   if "end mouseUp" is not in the text of tField then throw "the Script Editor did not end the handler:" && edJoin(the text of tField)
   edShotStack tSE, "14-script-applied"
end ed_script_type_apply

-- a line that does not compile: Apply shows it in the Errors pane, with
-- its line
on ed_script_compile_error
   local tSE, tButton, tField, tBefore, tErrors
   put edControl("button") into tButton
   put the script of tButton into tBefore
   put edOpenScript(tButton) into tSE
   put edSeField(tSE) into tField
   edClickAt tSE, the loc of tField
   select line 2 of tField
   edType tSE, "   put into the label of me"
   edApply tSE
   if not edWaitFor("edSeErrors(pAx) is not empty", 3000, tSE) then throw "Apply of a script that does not compile shows no error"
   put edSeErrors(tSE) into tErrors
   edRecord "INFO the Errors pane:" && edJoin(tErrors)
   if "line 2" is not in tErrors then throw "the error does not name line 2:" && edJoin(tErrors)
   -- (the engine keeps the text of a script that does not compile, as
   -- LiveCode always has, with no handlers: so the button no longer runs)
   edShotStack tSE, "15-script-compile-error"
end ed_script_compile_error

-- the line put right and Apply clicked: no error, the button has it
on ed_script_fix_apply
   local tSE, tButton, tField
   put edControl("button") into tButton
   put edOpenScript(tButton) into tSE
   put edSeField(tSE) into tField
   edClickAt tSE, the loc of tField
   select line 2 of tField
   edType tSE, "   put the label of me into field 1"
   edApply tSE
   if not edWaitFor("edSeErrors(pAx) is empty", 3000, tSE) then throw "the error stays after the script was put right:" && edSeErrors(tSE)
   if line 2 of the script of tButton is not "   put the label of me into field 1" then
      throw "the button's script is not the one put right:" && edJoin(the script of tButton)
   end if
   edShotStack tSE, "16-script-fixed"
   edCloseScriptEditors
end ed_script_fix_apply

-- Run in the Tools palette, and a click on the button runs its handler
on ed_browse_runs_it
   local tButton, tField
   put edControl("button") into tButton
   put edControl("field") into tField
   edToolTile "com.livecode.tool.Browse"
   if not edWaitFor("the tool is " & quote & "browse tool" & quote, 3000) then throw "Run in the Tools palette did not choose the Browse tool (" & the tool & ")"
   put empty into field 1 of card 1 of stack sStack
   edClickAt sStack, the loc of tButton
   if not edWaitFor("the cClicks of pAx is 1", 3000, tButton) then throw "a click on the button in Run mode did not run its mouseUp (" & the cClicks of tButton & ")"
   if field 1 of card 1 of stack sStack is not "Press me" then throw "the handler did not put the label into the field:" && field 1 of card 1 of stack sStack
   edShotStack sStack, "17-browse-runs-it"
   edToolTile "com.livecode.tool.Pointer"
   if not edWaitFor("the tool is " & quote & "pointer tool" & quote, 3000) then throw "Edit in the Tools palette did not choose the Pointer tool (" & the tool & ")"
end ed_browse_runs_it

-- Tools > Message Box, one line typed and Return: its result shows, and
-- the stack in front is the one it acts on
on ed_message_box_line
   local tMB
   edFront
   edMenu "Tools", "Message Box"
   put revIDEPaletteToStackName("message box") into tMB
   if not edWaitFor("edOpen(pAx)", 3000, tMB) then throw "Tools > Message Box opened no Message Box"
   dispatch "showCard" to stack tMB with "Single Line"
   edClickAt tMB, the loc of field "message" of card "Single Line" of stack tMB
   -- (the line the Message Box kept from the IDE's last session, the
   -- light run's on Windows, where both runs share one profile: the click
   -- put the caret inside it and "put 6 * 7" went into its middle, "put:
   -- preposition must be 'before', 'into' or 'after'" (0.2.7-rc.6.16, the
   -- dark run). It is selected, as a person selects it to type over it)
   select text of field "message" of card "Single Line" of stack tMB
   edType tMB, "put 6 * 7" & return
   if not edWaitFor("field " & quote & "results" & quote & " of card " & quote & "Single Line" & quote & " of stack pAx is 42", 3000, tMB) then
      throw "the Message Box did not show 42 for put 6 * 7:" && field "results" of card "Single Line" of stack tMB
   end if
   edType tMB, "put the number of buttons of this card" & return
   if not edWaitFor("field " & quote & "results" & quote & " of card " & quote & "Single Line" & quote & " of stack pAx is the number of buttons of card 1 of stack sStack", 3000, tMB) then
      throw "the Message Box did not act on the stack in front:" && field "results" of card "Single Line" of stack tMB
   end if
   edShotStack tMB, "18-message-box-line"
end ed_message_box_line

-- its Multiple Lines card: lines typed, Return between them, and
-- Control-Return runs them all
on ed_message_box_lines
   local tMB, tField
   put revIDEPaletteToStackName("message box") into tMB
   if not edOpen(tMB) then edMenu "Tools", "Message Box"
   dispatch "showCard" to stack tMB with "Multiple Lines"
   if not edWaitFor("the short name of this card of stack pAx is " & quote & "Multiple Lines" & quote, 3000, tMB) then throw "the Message Box did not show Multiple Lines"
   put the long id of field "script" of card "Multiple Lines" of stack tMB into tField
   edClickAt tMB, the loc of tField
   select text of tField
   edType tMB, "put 2 into x" & return & "repeat 3 times" & return & "multiply x by 2" & return & "end repeat" & return & "put x"
   if the number of lines of the text of tField < 5 then throw "Return in Multiple Lines did not start a new line:" && edJoin(the text of tField)
   -- (Ctrl+Return, as the field's behaviour takes it: Return alone starts a line)
   edType tMB, return, "control"
   if not edWaitFor("field " & quote & "results" & quote & " of card " & quote & "Multiple Lines" & quote & " of stack pAx is 16", 3000, tMB) then
      throw "Control-Return in Multiple Lines did not run the lines to 16:" && field "results" of card "Multiple Lines" of stack tMB
   end if
   edShotStack tMB, "19-message-box-lines"
   dispatch "showCard" to stack tMB with "Single Line"
   close stack tMB
end ed_message_box_lines

-- The Message Box's shortcut, Ctrl+M (Cmd+M on a Mac), pressed with the
-- Tools palette closed: the Message Box opens and the Tools palette stays
-- closed; pressed again, the Message Box closes. A newcomer wrote "when
-- the Tools Palette is not yet visible, Ctrl-M only opens the Tools
-- Palette" (openxtalk.org p=26390). The keys are the system's keyboard's
-- where they reach the IDE (edShortcut): the menu bar's accelerator
-- answers them, as it answers a person's. The Tools palette is shown
-- again whatever happened, for the tasks after
on ed_message_box_shortcut
   local tMB, tKeys, tVia, tMiss
   put revIDEPaletteToStackName("message box") into tMB
   put edShortcutName("m") into tKeys
   edFront
   if edOpen(tMB) then close stack tMB
   -- (closed as a person closes it: its item in the Tools menu)
   if revIDEPaletteIsVisible("tools") then edMenu "Tools", "Tools Palette"
   if not edWaitFor("not revIDEPaletteIsVisible(pAx)", 3000, "tools") then throw "Tools > Tools Palette did not close the Tools palette"
   put edShortcut("m") into tVia
   if not edWaitFor("edOpen(pAx)", 5000, tMB) then
      put tKeys && "(" & tVia & ") opened no Message Box with the Tools palette closed; the Tools palette shown:" && \
            revIDEPaletteIsVisible("tools") & "; the topStack" && the short name of the topStack & "; the focus" && edJoin(the focusedObject) into tMiss
      if tVia is "the system's keyboard" then
         -- (the same keys from the engine, to tell keys that went
         -- elsewhere from a shortcut that does not open it)
         edType sStack, "m", "command"
         put "; typed by the engine it opened one:" && edWaitFor("edOpen(pAx)", 3000, tMB) after tMiss
      end if
   else if revIDEPaletteIsVisible("tools") then
      put tKeys && "(" & tVia & ") opened the Message Box and showed the Tools palette too, which was closed" into tMiss
   else
      edShotScreen "19b-message-box-shortcut"
      get edShortcut("m")
      if not edWaitFor("not edOpen(pAx)", 5000, tMB) then
         put tKeys && "(" & tVia & ") pressed again did not close the Message Box" into tMiss
      else if revIDEPaletteIsVisible("tools") then
         put tKeys && "(" & tVia & ") pressed again showed the Tools palette, which was closed" into tMiss
      end if
   end if
   -- (and its keys are let go: the clicks of the tasks after are plain)
   if tMiss is empty then put edKeysHeld(tKeys) into tMiss
   edToolsBack tMB
   if tMiss is not empty then throw tMiss
   edRecord "INFO" && tKeys && "opened and closed the Message Box by" && tVia & ", the Tools palette closed throughout"
end ed_message_box_shortcut

-- the field clicked with the Pointer tool (selected) and dragged; Edit >
-- Undo puts it back
on ed_select_move_undo
   local tField, tFrom, tTo, tLoc
   put edControl("field") into tField
   edFront
   put the loc of tField into tLoc
   edClickAt sStack, edInside(tField)
   if not edWaitFor("the selected of pAx", 2000, tField) then throw "a click on the field with the Pointer tool did not select it (" & the selObj & ")"
   put edInside(tField) into tFrom
   put (item 1 of tFrom + 40) & "," & (item 2 of tFrom + 30) into tTo
   edDragIn sStack, tFrom, tTo
   if not edWaitFor("the loc of pAx is not pBx", 2000, tField, tLoc) then throw "dragging the selected field did not move it"
   put the loc of tField into sKeep["moved"]
   edRecord "INFO the field moved from" && tLoc && "to" && sKeep["moved"]
   edShotStack sStack, "20-moved"
   edMenu "Edit", "Undo"
   if not edWaitFor("the loc of pAx is pBx", 2000, tField, tLoc) then throw "Edit > Undo did not put the field back (" & the loc of tField & ", was" && tLoc & ")"
   put tLoc into sKeep["home"]
end ed_select_move_undo

-- Undo again: the move comes back (the engine's undo undoes an undo)
on ed_undo_twice_redoes
   local tField
   put edControl("field") into tField
   if sKeep["moved"] is empty then
      put the loc of tField into sKeep["home"]
      edClickAt sStack, edInside(tField)
      edDragIn sStack, edInside(tField), (item 1 of edInside(tField) + 40) & "," & (item 2 of edInside(tField) + 30)
      edPause 300
      put the loc of tField into sKeep["moved"]
      edMenu "Edit", "Undo"
   end if
   edMenu "Edit", "Undo"
   if not edWaitFor("the loc of pAx is sKeep[" & quote & "moved" & quote & "]", 2000, tField) then
      throw "a second Edit > Undo did not redo the move (" & the loc of tField & ", moved to" && sKeep["moved"] & ")"
   end if
   edMenu "Edit", "Undo"
   get edWaitFor("the loc of pAx is sKeep[" & quote & "home" & quote & "]", 2000, tField)
   edShotStack sStack, "16b-undo-redo"
end ed_undo_twice_redoes

-- the checkbox selected and Delete pressed: gone; Edit > Undo: back
on ed_delete_undo
   local tBox, tCount, tName
   put edControl("checkbox") into tBox
   put the short name of tBox into tName
   put the number of controls of card 1 of stack sStack into tCount
   edFront
   edClickAt sStack, edInside(tBox)
   if not edWaitFor("the selected of pAx", 2000, tBox) then throw "the checkbox was not selected"
   edType sStack, numToChar(8)
   if not edWaitFor("the number of controls of card 1 of stack sStack is pAx - 1", 2000, tCount) then
      -- (Backspace and Delete both clear a selection; one is tried, then the other)
      edMenu "Edit", "Clear Objects"
   end if
   if not edWaitFor("the number of controls of card 1 of stack sStack is pAx - 1", 2000, tCount) then throw "the selected checkbox was not deleted"
   edShotStack sStack, "21-deleted"
   edMenu "Edit", "Undo"
   if not edWaitFor("the number of controls of card 1 of stack sStack is pAx", 2000, tCount) then throw "Edit > Undo did not bring the deleted checkbox back"
   if there is not a control tName of card 1 of stack sStack then throw "what Undo brought back is not the checkbox" && tName
end ed_delete_undo

-- Edit > Copy and Paste: a second button like the first
on ed_copy_paste
   local tButton, tCount
   put edControl("button") into tButton
   put the number of buttons of card 1 of stack sStack into tCount
   edSelect tButton
   edMenu "Edit", "copy"
   edMenu "Edit", "paste"
   if not edWaitFor("the number of buttons of card 1 of stack sStack is pAx + 1", 3000, tCount) then throw "Edit > Copy then Paste made no second button"
   if the label of last button of card 1 of stack sStack is not the label of tButton then throw "the pasted button is not a copy (" & the label of last button of card 1 of stack sStack & ")"
   if the script of last button of card 1 of stack sStack is not the script of tButton then throw "the pasted button has not the button's script"
   edShotStack sStack, "22-pasted"
end ed_copy_paste

-- Copy and Paste by their shortcuts, Cmd+C and Cmd+V (Ctrl on Windows
-- and Linux), pressed on the system's keyboard where its keys reach the
-- IDE: the button copy-paste made selected, copied and pasted, then text
-- in the stack's field copied and pasted. Each must work the first time
-- it is pressed: on macOS 15.2 a person found that the two "don't work
-- the first time. The second time I do this it works fine" (CamelCaps,
-- openxtalk.org p=26676, in 0.2.7 and 0.2.8-dp.2). A press that does
-- nothing is pressed again, so that the failure says whether a second
-- press does what the first did not
on ed_shortcut_copy_paste
   local tButton, tCount, tMiss, tField, tFirst, tKept
   -- (the copy that copy-paste made, which lies on the button: a click
   -- there is on it)
   get edControl("button")
   put the long id of last button of card 1 of stack sStack into tButton
   put the number of buttons of card 1 of stack sStack into tCount
   -- the button
   edSelect tButton
   set the clipboardData["text"] to "OXT Everyday clipboard"
   put edPressedOnce("c", "with the button selected did not copy it", "the clipboard is " & quote & "objects" & quote) into tMiss
   if tMiss is empty then
      put edPressedOnce("v", "pasted no button", "the number of buttons of card 1 of stack sStack > pAx", tCount) into tMiss
   end if
   if tMiss is empty then
      if the number of buttons of card 1 of stack sStack is not tCount + 1 then put "one press of" && edShortcutName("v") && "pasted" && the number of buttons of card 1 of stack sStack - tCount && "buttons" into tMiss
   end if
   if tMiss is empty then
      if the label of last button of card 1 of stack sStack is not the label of tButton then put "what" && edShortcutName("v") && "pasted is not a copy of the button (" & the label of last button of card 1 of stack sStack & ")" into tMiss
   end if
   if tMiss is empty then edShotStack sStack, "22b-shortcut-pasted"
   -- (the pastes taken away: the tasks after work on the buttons there
   -- were before)
   revIDEDeselectAll
   repeat while the number of buttons of card 1 of stack sStack > tCount
      delete last button of card 1 of stack sStack
   end repeat
   -- text in the stack's field, in Run mode: copied, then pasted at its
   -- end after a click elsewhere and a click back in it, as a person
   -- copies a line and pastes it. Before each key the menus are as the
   -- IDE builds them with no text selected and no field focused (the
   -- build a click elsewhere makes), so that Copy and Paste are disabled
   -- in them: a click in a field or a selection of text in it builds
   -- nothing, as it never has, and each key must find its item enabled
   -- all the same. (The Script Editor answers both keys itself, before
   -- the menu bar's accelerator: Copy and Paste there worked the first
   -- time before this, and are not the menu bar's to test)
   if tMiss is empty then
      put edControl("field") into tField
      put the text of tField into tKept
      put "Copy me" into tFirst
      set the text of tField to tFirst
      edToolTile "com.livecode.tool.Browse"
      if not edWaitFor("the tool is " & quote & "browse tool" & quote, 3000) then put "Run in the Tools palette did not choose the Browse tool (" & the tool & ")" into tMiss
   end if
   if tMiss is empty then
      set the clipboardData["text"] to "OXT Everyday clipboard"
      put edMenusBuiltBare("Copy") into tMiss
   end if
   if tMiss is empty then
      edClickAt sStack, the loc of tField
      select text of tField
      put edPressedOnce("c", "with the field's text selected did not copy it", "the clipboardData[" & quote & "text" & quote & "] is pAx", tFirst) into tMiss
   end if
   if tMiss is empty then put edMenusBuiltBare("Paste") into tMiss
   if tMiss is empty then
      edClickAt sStack, the loc of tField
      select after text of tField
      put edPressedOnce("v", "did not paste the copied text into the field", "the text of pAx is pBx", tField, tFirst & tFirst) into tMiss
   end if
   if tMiss is empty then edShotStack sStack, "22c-shortcut-pasted-text"
   -- (the field and the tool as they were, whatever happened)
   select empty
   if tField is not empty then set the text of tField to tKept
   edToolTile "com.livecode.tool.Pointer"
   get edWaitFor("the tool is " & quote & "pointer tool" & quote, 3000)
   -- (and the keys let go: the clicks of the tasks after are plain)
   if tMiss is empty then put edKeysHeld(edShortcutName("v")) into tMiss
   if tMiss is not empty then throw tMiss
   edRecord "INFO" && edShortcutName("c") && "and" && edShortcutName("v") && "copied and pasted the button, and text in its field, each the first time it was pressed"
end ed_shortcut_copy_paste

-- No text selected and no field focused, nothing selected, and the
-- menus built as the IDE builds them then (as a click elsewhere builds
-- them): empty if the item pItem of the Edit menu (Copy or Paste) is
-- disabled in them, as it must be for the key after to test anything;
-- else why not, for a throw
function edMenusBuiltBare pItem
   select empty
   revIDEDeselectAll
   focus on nothing
   send "revMenubarBuildMenus" to stack "revMenuBar"
   if edWaitFor("edBuiltOff(pAx)", 3000, pItem) then return empty
   return "with no text selected the menus were built with" && pItem && "enabled (" & edJoin(the text of button "Edit" of group "revMenuBar" of stack "revMenuBar") & ")"
end edMenusBuiltBare

-- whether the Edit menu as the IDE last built it has pItem disabled
function edBuiltOff pItem
   return ("(&" & pItem) is in the text of button "Edit" of group "revMenuBar" of stack "revMenuBar"
end edBuiltOff

-- The shortcut Cmd (Ctrl) and pLetter pressed once, and empty if pTrue
-- (an expression of pAx and pBx, as edWaitFor takes them) is then true.
-- If not, what it did not do (pDid) in words, for a throw, and whether a
-- second press made pTrue true: a person found Cmd+C and Cmd+V doing
-- nothing the first time and working the second (openxtalk.org p=26676)
function edPressedOnce pLetter, pDid, pTrue, pAx, pBx
   local tVia, tMiss
   put edShortcut(pLetter) into tVia
   if edWaitFor(pTrue, 3000, pAx, pBx) then return empty
   put edShortcutName(pLetter) && "(" & tVia & ")" && pDid && "the first time it was pressed" into tMiss
   get edShortcut(pLetter)
   if edWaitFor(pTrue, 3000, pAx, pBx) then
      put "; pressed a second time, it did" after tMiss
   else
      put "; nor did a second press" after tMiss
   end if
   return tMiss
end edPressedOnce

-- Edit > Duplicate on the pasted one: a third, offset from it
on ed_duplicate
   local tCount, tLast
   put the number of buttons of card 1 of stack sStack into tCount
   put the long id of last button of card 1 of stack sStack into tLast
   edSelect tLast
   edMenu "Edit", "Duplicate Objects"
   if not edWaitFor("the number of buttons of card 1 of stack sStack is pAx + 1", 3000, tCount) then throw "Edit > Duplicate made no copy"
   if the loc of last button of card 1 of stack sStack is the loc of tLast then throw "the duplicate is on top of the original"
   edShotStack sStack, "23-duplicated"
end ed_duplicate

-- the two copies, set side by side in a clear part of the card, and a
-- drag of the Pointer tool round them (a person's way to pick several),
-- then Object > Group Selected: one group of the two
on ed_group
   local tCount, tA, tB
   edFront
   put the number of buttons of card 1 of stack sStack into tCount
   if tCount < 3 then throw "no two copies of the button to group (an earlier task did not make them)"
   put the long id of button (tCount - 1) of card 1 of stack sStack into sKeep["a"]
   put the long id of button tCount of card 1 of stack sStack into sKeep["b"]
   put sKeep["a"] into tA
   put sKeep["b"] into tB
   set the topLeft of tA to 170,320
   set the topLeft of tB to 290,345
   edMarquee
   if not edWaitFor("edSelectedTwo()", 2000) then throw "a drag round the two buttons did not select them both (" & edJoin(the selObj) & ")"
   edMenu "Object", "Group Selected"
   if not edWaitFor("the number of groups of card 1 of stack sStack is 1", 3000) then throw "Object > Group Selected made no group"
   if the number of controls of group 1 of card 1 of stack sStack is not 2 then throw "the group holds" && the number of controls of group 1 of card 1 of stack sStack && "controls, not 2"
   edShotStack sStack, "24-grouped"
end ed_group

-- the group clicked and Object > Ungroup Selected: the two are on the
-- card again, no group
on ed_ungroup
   local tCount
   edFront
   if there is not a group 1 of card 1 of stack sStack then throw "no group to ungroup"
   put the number of buttons of card 1 of stack sStack into tCount
   edSelect the long id of group 1 of card 1 of stack sStack
   edMenu "Object", "Ungroup Selected"
   if not edWaitFor("the number of groups of card 1 of stack sStack is 0", 3000) then throw "Object > Ungroup Selected left the group"
   if the number of buttons of card 1 of stack sStack is not tCount then throw "ungrouping lost a button"
   edShotStack sStack, "21b-ungrouped"
end ed_ungroup

-- the two picked again and Object > Align Selected Controls > Left:
-- the same left
on ed_align
   edFront
   if sKeep["a"] is empty or not exists(sKeep["a"]) or not exists(sKeep["b"]) then throw "no two buttons to align (an earlier task did not set them out)"
   revIDEDeselectAll
   edMarquee
   if not edWaitFor("edSelectedTwo()", 2000) then throw "a drag round the two buttons did not select them both (" & edJoin(the selObj) & ")"
   edMenu "Object", "Align Selected Controls|Left"
   if not edWaitFor("the left of pAx is the left of pBx", 3000, sKeep["a"], sKeep["b"]) then
      throw "Align > Left did not line the lefts up"
   end if
   edShotStack sStack, "25-aligned"
end ed_align

-- a drag of the Pointer tool from an empty point of the card round the
-- part of it where sKeep["a"] and sKeep["b"] are
command edMarquee
   edDragIn sStack, "160,310", (the width of stack sStack - 4) & "," & (the height of stack sStack - 4)
end edMarquee

-- whether the selection is the two of sKeep (in either order)
function edSelectedTwo
   local tA, tB, tSel
   put sKeep["a"] into tA
   put sKeep["b"] into tB
   put the selObj into tSel
   if the number of lines in tSel is not 2 then return false
   put the selected of tA into tA
   put the selected of tB into tB
   return tA and tB
end edSelectedTwo

-- Object > New Card: a second card, shown
on ed_new_card
   edFront
   revIDEDeselectAll
   edMenu "Object", "New Card"
   if not edWaitFor("the number of cards of stack sStack is 2", 3000) then throw "Object > New Card made no card"
   if the number of this card of stack sStack is not 2 then throw "the new card is not shown"
   set the name of this card of stack sStack to "Second"
   edShotStack sStack, "24b-new-card"
end ed_new_card

-- Tools > Project Browser lists the stack's two cards
on ed_project_browser_cards
   local tPB, tRows
   edFront
   put revIDEPaletteToStackName("project browser") into tPB
   if not edOpen(tPB) then edMenu "Tools", "Project Browser"
   if not edWaitFor("edOpen(pAx)", 5000, tPB) then throw "Tools > Project Browser opened nothing"
   revIDEShowInProjectBrowser the long id of card 2 of stack sStack
   if not edWaitFor("edPBRow(pAx, the long id of card 2 of stack sStack) is not empty", 5000, tPB) then throw "the Project Browser does not list the new card"
   if edPBRow(tPB, the long id of card 1 of stack sStack) is empty then throw "the Project Browser does not list the first card"
   edShotStack tPB, "26-project-browser-cards"
end ed_project_browser_cards

-- View > Go First and Go Next
on ed_go_card
   edFront
   edMenu "View", "Go First"
   if not edWaitFor("the number of this card of stack sStack is 1", 2000) then throw "View > Go First did not go to card 1"
   edMenu "View", "Go Next"
   if not edWaitFor("the number of this card of stack sStack is 2", 2000) then throw "View > Go Next did not go to card 2"
   edShotStack sStack, "26b-go-card"
end ed_go_card

-- Object > Delete Card on card 2, and Yes to its question: one card left, and the Project Browser
-- no longer lists it
on ed_delete_card
   local tPB, tCard
   edFront
   put the long id of card 2 of stack sStack into tCard
   if the number of this card of stack sStack is not 2 then go card 2 of stack sStack
   -- (it asks first: Yes)
   send "edAnswerWith" && quote & "Yes" & quote to me in 300 milliseconds
   edMenu "Object", "Delete Card"
   if not edWaitFor("the number of cards of stack sStack is 1", 3000) then throw "Object > Delete Card left" && the number of cards of stack sStack && "cards"
   put revIDEPaletteToStackName("project browser") into tPB
   if edOpen(tPB) then
      if not edWaitFor("edPBRow(pAx, pBx) is empty", 3000, tPB, tCard) then throw "the Project Browser still lists the deleted card"
      close stack tPB
   end if
   edShotStack sStack, "26c-card-deleted"
end ed_delete_card

-- File > Save As: the IDE's file dialog, the name typed and Save
-- clicked: the file is there, a stack, with the stack's name
on ed_save_as
   local tPath
   edFront
   put sWork & "/" & kFile into tPath
   edFileDialog kFile, "Save"
   edMenu "File", "Save As..."
   if not edWaitFor("there is a file pAx", 5000, tPath) then throw "File > Save As wrote no file" && tPath & "; the dialog:" && sReport["dialog"]
   -- (the file is there before the save has ended: on Linux, dark, #449's
   -- package job read the stack's filename as empty just after the file
   -- appeared, and the same tree passed in light. So the stack's filename
   -- is waited for too, at most 5 seconds; what is checked is the same)
   if not edWaitFor("the effective filename of stack sStack is pAx", 5000, tPath) then
      throw "the stack's file is" && the effective filename of stack sStack & ", not" && tPath
   end if
   if the number of bytes of URL ("binfile:" & tPath) < 100 then throw "the file saved is" && the number of bytes of URL ("binfile:" & tPath) && "bytes"
   edRecord "INFO saved" && tPath && the number of bytes of URL ("binfile:" & tPath) && "bytes"
end ed_save_as

----------------------------------------------------------------
-- The Application Browser (the App Browser plugin): its tree of stacks
-- and cards is field "Cards" (a line each: the name, a tab, the card's
-- number; a stack's line starts with the icon that expands it), and the
-- controls of the card picked are field "Controls" (a line each, the
-- control's name in its fifth item)

constant kAB = "App Browser"

-- the tree field of the App Browser, on whichever card it shows
function edABTree
   return the long id of field "Cards" of group "Cards" of this card of stack kAB
end edABTree

-- the line of the tree whose name is pName, after line pAfter (0 for
-- the first), or 0
function edABLine pName, pAfter
   local tLine, tName, i
   set the itemDelimiter to tab
   put 0 into i
   repeat for each line tLine in the text of edABTree()
      add 1 to i
      if i <= pAfter then next repeat
      put word 1 to -1 of item 1 of tLine into tName
      if tName is pName then return i
   end repeat
   return 0
end edABLine

-- the line of the tree of the card numbered pNumber, below the line of
-- its stack pStackLine (0 when the stack is not expanded)
function edABCardLine pStackLine, pNumber
   local tLines, i
   set the itemDelimiter to tab
   put the text of edABTree() into tLines
   repeat with i = pStackLine + 1 to the number of lines of tLines
      if item 2 of line i of tLines is empty then return 0
      if word 1 to -1 of item 2 of line i of tLines is pNumber then return i
   end repeat
   return 0
end edABCardLine

-- a click on the name in line pLine of the tree, where a person clicks
-- it (the browser acts on a click on the words of the name only)
command edABClickName pLine
   local tRect
   -- (the browser in front: on a small screen the stack's window or a
   -- palette can be over it, and the click would land there)
   go stack kAB
   edABMouseAway
   -- (the field's place for a line can be empty for a moment while the
   -- browser lays it out again)
   get edWaitFor("the number of items of edABNameRect(pAx) is 4", 2000, pLine)
   put edABNameRect(pLine) into tRect
   if the number of items of tRect is not 4 then
      throw "no place for line" && pLine && "of the App Browser's tree (the card" && the short name of this card of stack kAB & "):" && edJoin(the text of edABTree())
   end if
   edRealClickAt kAB, ((item 1 of tRect + item 3 of tRect) div 2) & "," & ((item 2 of tRect + item 4 of tRect) div 2)
end edABClickName

-- the pointer off the tree for a moment: resting on a line, it has the
-- tree's tooltip (the line's stack or card) shown under it, and on Windows
-- a click there went to the tooltip, not the tree (the second click on
-- the same icon, or the first when the pointer was left there)
command edABMouseAway
   local tError
   try
      set the screenMouseLoc to (the left of stack kAB + 8) & "," & (the bottom of stack kAB - 4)
   catch tError
   end try
   edPause 700
end edABMouseAway

function edABNameRect pLine
   local tWords
   set the itemDelimiter to tab
   put the number of words of item 1 of line pLine of the text of edABTree() into tWords
   -- (a chunk of a field: by its name, not a variable holding its id)
   return the formattedRect of word 1 to tWords of line pLine of field "Cards" of group "Cards" of this card of stack kAB
end edABNameRect

-- a click on the icon that expands or collapses the stack of line pLine
command edABClickIcon pLine
   local tRect
   -- (the browser in front: on a small screen the stack's window or a
   -- palette can be over it, and the click would land there)
   go stack kAB
   edABMouseAway
   put the formattedRect of char 1 of line pLine of field "Cards" of group "Cards" of this card of stack kAB into tRect
   edRealClickAt kAB, ((item 1 of tRect + item 3 of tRect) div 2) & "," & ((item 2 of tRect + item 4 of tRect) div 2)
end edABClickIcon

-- the line of the controls field of the control pControl (by its layer,
-- in its fourth item: copies have the same name), or 0
function edABControlLine pControl
   local tLine, i
   set the itemDelimiter to tab
   put 0 into i
   repeat for each line tLine in the text of field "Controls" of card "Cards and Controls" of stack kAB
      add 1 to i
      if word 1 to -1 of item 4 of tLine is the layer of pControl and word 1 to -1 of item 5 of tLine is the short name of pControl then return i
   end repeat
   return 0
end edABControlLine

-- where a click on line pLine of the controls field lands in its
-- Control column (a click in the Visible or Selectable column changes
-- the control)
function edABControlLoc pLine
   local tRect
   put the formattedRect of line pLine of field "Controls" of card "Cards and Controls" of stack kAB into tRect
   return (the left of button "Control" of group "Control Tabs" of card "Cards and Controls" of stack kAB + 24) & "," & ((item 2 of tRect + item 4 of tRect) div 2)
end edABControlLoc

-- The App Browser left open on the new stack's card, its Cards and
-- Controls, while the tasks after it make controls, edit them in the
-- Inspector, change tools, add, go to and delete cards, rename the stack
-- and save it: the IDE sends the browser each change (#364), and a script
-- error in it would be logged as an ERROR and fail the run. It sits in a
-- corner of the screen, clear of the stack and the palettes
on ed_appbrowser_watch
   local tLine, tCard, tScreen
   ed_appbrowser_open
   ed_appbrowser_expand
   put edABLine(the short name of stack sStack, 0) into tLine
   put edABCardLine(tLine, 1) into tCard
   if tCard is 0 then throw "the stack is not expanded"
   edABClickName tCard
   if not edWaitFor("the short name of this card of stack pAx is " & quote & "Cards and Controls" & quote, 3000, kAB) then
      throw "a click on the card did not show its Cards and Controls (" & the short name of this card of stack kAB & ")"
   end if
   put the working screenRect into tScreen
   put the rect of stack kAB into sKeep["abRect"]
   set the rect of stack kAB to (item 3 of tScreen - 440) & "," & (item 4 of tScreen - 300) & "," & (item 3 of tScreen - 8) & "," & (item 4 of tScreen - 8)
   go stack sStack
   edShotScreen "02a-app-browser-watching"
end ed_appbrowser_watch

-- still open after those tasks, listing the stack under the name it has
-- now (on Cards and Controls, or on its blank card once the card it showed
-- was deleted, as it does), then closed and put back where it was
on ed_appbrowser_still_open
   if not edOpen(kAB) then throw "the App Browser left open is no longer open"
   if not edWaitFor("edABLine(pAx, 0) is not 0", 3000, the short name of stack sStack) then
      throw "the App Browser left open does not list" && the short name of stack sStack & ":" && edJoin(the text of edABTree())
   end if
   edRecord "INFO the App Browser left open is on its card" && the short name of this card of stack kAB
   edShotStack kAB, "26d-app-browser-still-open"
   close stack kAB
   if sKeep["abRect"] is not empty and kAB is among the lines of the mainStacks then
      set the rect of stack kAB to sKeep["abRect"]
   end if
end ed_appbrowser_still_open

-- Development > Plugins > App Browser: the window opens and lists the
-- stack
on ed_appbrowser_open
   edFront
   if edOpen(kAB) then close stack kAB
   edMenu "Development", "Plugins|App Browser"
   if not edWaitFor("edOpen(pAx)", 5000, kAB) then throw "Development > Plugins > App Browser opened nothing"
   -- (clear of the Tools palette, which floats over it)
   if edOpen("revTools") then set the left of stack kAB to the right of stack "revTools" + 16
   edOnScreen kAB
   if not edWaitFor("edABLine(pAx, 0) is not 0", 3000, the short name of stack sStack) then
      throw "the App Browser does not list" && the short name of stack sStack & ":" && edJoin(the text of edABTree())
   end if
   edShotStack kAB, "27a-app-browser"
end ed_appbrowser_open

-- the names in its tree read on its window: light, in the dark grey the
-- IDE gives them since rc.6.17 (64,64,64, revIDEAppBrowserAppearance, #372;
-- the plugin's own 127,127,127 is only 4 to 1 on white); dark, in a grey
-- with the contrast of body text (4.5 to 1) against the tree's background
on ed_appbrowser_names
   local tLinks, tBack, tContrast
   if not edOpen(kAB) then throw "the App Browser is not open"
   put the effective linkColor of stack kAB into tLinks
   if not revIDEAppearanceIsDark() then
      if tLinks is not "64,64,64" then throw "light: the App Browser's names are" && tLinks & ", not the IDE's dark grey 64,64,64"
      edShotStack kAB, "27a2-app-browser-names"
      return empty
   end if
   put edRGB(the effective backgroundColor of field "Cards" of group "Cards" of card 1 of stack kAB) into tBack
   if tBack is empty then put edRGB(the effective backgroundColor of stack kAB) into tBack
   if tBack is empty or edRGB(tLinks) is empty then
      put "the colours are not numbers (names:" && tLinks && "on" && the effective backgroundColor of stack kAB & ")" into sSkip
      return "skipped"
   end if
   put edContrast(edRGB(tLinks), tBack) into tContrast
   edRecord "INFO the App Browser's names:" && tLinks && "on" && tBack & ", contrast" && format("%.1f", tContrast)
   edShotStack kAB, "27a2-app-browser-names"
   if tContrast < 4.5 then throw "dark: the App Browser's names" && tLinks && "on" && tBack && "have a contrast of" && format("%.1f", tContrast) & ", under 4.5"
end ed_appbrowser_names

-- pColour as r,g,b, or empty when it is not three numbers
function edRGB pColour
   if the number of items of pColour is 3 and item 1 of pColour is an integer \
         and item 2 of pColour is an integer and item 3 of pColour is an integer then
      return pColour
   end if
   return empty
end edRGB

-- the WCAG contrast ratio of two r,g,b colours
function edContrast pA, pB
   local tA, tB
   put edLuminance(pA) + 0.05 into tA
   put edLuminance(pB) + 0.05 into tB
   return max(tA, tB) / min(tA, tB)
end edContrast

function edLuminance pRGB
   local tSum, tC, tWeights
   put "0.2126,0.7152,0.0722" into tWeights
   repeat with i = 1 to 3
      put item i of pRGB / 255 into tC
      if tC <= 0.03928 then
         put tC / 12.92 into tC
      else
         put ((tC + 0.055) / 1.055) ^ 2.4 into tC
      end if
      add item i of tWeights * tC to tSum
   end repeat
   return tSum
end edLuminance

-- a click on the stack's icon expands it: its card listed under it
on ed_appbrowser_expand
   local tLine
   put edABLine(the short name of stack sStack, 0) into tLine
   if tLine is 0 then throw "the App Browser does not list the stack"
   if edABCardLine(tLine, 1) is not 0 then
      -- (already expanded: collapsed first, as a person would see it)
      edABClickIcon tLine
      if not edWaitFor("edABCardLine(pAx, 1) is 0", 3000, tLine) then throw "a click on the expanded stack's icon did not collapse it"
   end if
   edABClickIcon tLine
   if not edWaitFor("edABCardLine(pAx, 1) is not 0", 3000, tLine) then
      throw "a click on the stack's icon did not list its card:" && edJoin(the text of edABTree())
   end if
   edShotStack kAB, "27b-app-browser-expanded"
end ed_appbrowser_expand

-- a click on the card's name lists its controls; a click on the button
-- Okay there selects it, and the Inspector open on another control
-- follows
on ed_appbrowser_select
   local tPI, tLine, tCard, tControl, tOkay
   put edOkay() into tOkay
   put edInspect(edControl("field")) into tPI
   -- (the Inspector, a palette, floats over the browser: moved off it,
   -- where a person would drag it, so that the clicks reach the browser)
   if the right of stack kAB + 8 + the width of stack tPI <= item 3 of the working screenRect then
      set the left of stack tPI to the right of stack kAB + 8
   else
      set the right of stack tPI to the left of stack kAB - 8
   end if
   -- (inspecting the field brings its stack to the front, over the
   -- browser on a small screen, 1024 x 768 on Windows: the browser is
   -- brought back in front, as a person would click its window)
   go stack kAB
   put edABLine(the short name of stack sStack, 0) into tLine
   put edABCardLine(tLine, 1) into tCard
   if tCard is 0 then throw "the stack is not expanded"
   edABClickName tCard
   if not edWaitFor("the short name of this card of stack " & quote & kAB & quote & " is " & quote & "Cards and Controls" & quote & " and edABControlLine(pAx) is not 0", 3000, tOkay) then
      throw "a click on the card did not list its controls (" & the short name of this card of stack kAB & "):" && edJoin(the text of field "Controls" of card "Cards and Controls" of stack kAB)
   end if
   edPause 300
   put edABControlLine(tOkay) into tControl
   edRealClickAt kAB, edABControlLoc(tControl)
   if not edWaitFor("the long id of the selObj is pAx", 3000, tOkay) then
      throw "a click on Okay (line" && tControl & ", at" && edABControlLoc(tControl) & ") in the App Browser did not select it but" && the selObj && "(lines selected:" && the hilitedLines of field "Controls" of card "Cards and Controls" of stack kAB & ")"
   end if
   if not edWaitFor("the cSelectedObjects of stack pAx is pBx", 3000, tPI, tOkay) then
      throw "the Inspector did not follow the App Browser to Okay (" & the cSelectedObjects of stack tPI & ")"
   end if
   edShotStack kAB, "27c-app-browser-select"
   edCloseInspectors
end ed_appbrowser_select

-- the controls' menu (a right-click on Okay) > Edit Script: the Script
-- Editor opens on the button
on ed_appbrowser_script
   local tControl, tSE, tLoc
   edCloseScriptEditors
   put edABControlLine(edOkay()) into tControl
   if tControl is 0 then throw "the App Browser does not list Okay"
   put edABControlLoc(tControl) into tLoc
   -- (the browser in front of the stack and the Inspector)
   go stack kAB
   -- (the menu is a popup: its second item picked with the arrow keys,
   -- as a person can)
   put "picked" into sReport["popup"]
   edRealClickAt kAB, tLoc, 3, "Down,Down,Return"
   if not edWaitFor("edStackNamed(" & quote & "revNewScriptEditor" & quote & ") is not empty", 10000) then
      throw "Edit Script in the App Browser's menu opened no Script Editor (" & sReport["popup"] & ")"
   end if
   put edStackNamed("revNewScriptEditor") into tSE
   if not edWaitFor("the text of field " & quote & "Script" & quote & " of group " & quote & "Editor" & quote & " of card " & quote & "Main" & quote & " of stack pAx contains " & quote & "on mouseUp" & quote, 3000, tSE) then
      get the text of field "Script" of group "Editor" of card "Main" of stack tSE
      edCloseScriptEditors
      throw "the Script Editor does not show Okay's script:" && edJoin(it)
   end if
   edShotStack tSE, "27d-app-browser-script"
   edCloseScriptEditors
   edCloseInspectors
end ed_appbrowser_script

-- a click on the expanded stack's icon collapses it
on ed_appbrowser_collapse
   local tLine
   put edABLine(the short name of stack sStack, 0) into tLine
   if edABCardLine(tLine, 1) is 0 then throw "the stack is not expanded"
   go stack kAB
   edABClickIcon tLine
   if not edWaitFor("edABCardLine(pAx, 1) is 0", 3000, tLine) then
      throw "a click on the stack's icon (line" && tLine & ", at" && the formattedRect of char 1 of line tLine of field "Cards" of group "Cards" of this card of stack kAB && "of" && the rect of stack kAB & ") did not collapse it:" && edJoin(the text of edABTree())
   end if
   edShotStack kAB, "27e-app-browser-collapsed"
end ed_appbrowser_collapse

-- File > Close and Remove From Memory (OK to its question), then File >
-- Open Stack and the
-- file picked in the IDE's dialog: the stack with what it held
on ed_close_reopen
   local tCount, tScript, tColour
   edFront
   put the number of controls of card 1 of stack sStack into tCount
   put the script of button id sKeep["okay"] of card 1 of stack sStack into tScript
   put the backgroundColor of button id sKeep["okay"] of card 1 of stack sStack into tColour
   -- (it asks whether to remove it: OK)
   -- (saved by save-as, and changed by nothing since: but the IDE marks a
   -- stack as edited at any click on a control in Edit mode, as when the
   -- field is selected for the Inspector, so Close first asks to save it,
   -- and the answer is Don't Save, as a person who changed nothing would)
   -- (the App Browser, kept open to see the stack leave it, below the
   -- stack's window: over it, it would cover the question asked as a
   -- sheet of that window, and a click on its buttons would land on the
   -- browser, as on macOS)
   if edOpen(kAB) then
      set the top of stack kAB to the bottom of stack sStack + 40
      set the left of stack kAB to the left of stack sStack
   end if
   if sEditedBy is not empty then
      edRecord "INFO close-reopen: the stack is marked as edited since" && sEditedBy & ": Don't Save"
      send "edAnswerWith" && quote & "Don't Save,OK" & quote to me in 300 milliseconds
   else
      send "edAnswerWith" && quote & "OK" & quote to me in 300 milliseconds
   end if
   edMenu "File", "Close and Remove From Memory"
   -- (the mainStacks, not "there is a stack": asked about a stack that
   -- is not in memory, the engine reads it from its file)
   if not edWaitFor("not edInMemory(sStack)", 5000) then
      throw "File > Close and Remove From Memory left the stack in memory (open:" && edJoin(the openStacks) & "; the question:" && sReport["answer"] & ")"
   end if
   -- the App Browser (opened by the tasks before) no longer lists it,
   -- without its Refresh: the IDE tells it of a stack removed (#364)
   if edOpen(kAB) then
      if not edWaitFor("edABLine(pAx, 0) is 0", 3000, kStack) then
         throw "the App Browser still lists the stack removed, until Refresh:" && edJoin(the text of edABTree())
      end if
      edShotStack kAB, "27f-app-browser-removed"
      close stack kAB
   end if
   edFileDialog kFile, "Open"
   -- (then the warning before a stack opens: Continue to open)
   put empty into sReport["kit"]
   send "edKitDialogAnswer" && quote & "Continue to open" & quote && ", 0" to me in 400 milliseconds
   edMenu "File", "Open Stack..."
   if not edWaitFor("edOpen(sStack)", 8000) then throw "File > Open Stack did not open" && kFile & "; the dialog:" && sReport["dialog"] & "; the warning:" && sReport["kit"] & "; in memory:" && edInMemory(sStack) & "; open:" && edJoin(the openStacks)
   if the number of controls of card 1 of stack sStack is not tCount then throw "the stack opened again has" && the number of controls of card 1 of stack sStack && "controls, not" && tCount
   if the script of button id sKeep["okay"] of card 1 of stack sStack is not tScript then throw "the button's script did not come back"
   if the backgroundColor of button id sKeep["okay"] of card 1 of stack sStack is not tColour then throw "the button's colour did not come back"
   if the textSize of edControl("field") is not 20 then throw "the field's text size did not come back"
   edShotStack sStack, "27-reopened"
end ed_close_reopen

-- a change, and File > Save (no dialog: it has its file)
on ed_save_again
   local tPath, tBefore
   edFront
   put the effective filename of stack sStack into tPath
   put the label of button id sKeep["okay"] of card 1 of stack sStack into tBefore
   set the label of button id sKeep["okay"] of card 1 of stack sStack to "Saved label"
   edMenu "File", "Save"
   if not edWaitFor("URL (" & quote & "binfile:" & quote & " & pAx) contains " & quote & "Saved label" & quote, 5000, tPath) then
      throw "File > Save did not write the change to" && tPath
   end if
   edShotStack sStack, "27-saved-again"
end ed_save_again

-- a change not saved, File > Revert to Saved, and Yes to its question:
-- the stack as saved
on ed_revert_to_saved
   local tCount
   edFront
   put the number of controls of card 1 of stack sStack into tCount
   edSelect edOkay()
   edMenu "Edit", "Clear Objects"
   if not edWaitFor("the number of controls of card 1 of stack sStack is pAx - 1", 3000, tCount) then throw "the button was not deleted"
   send "edAnswerWith" && quote & "Yes" & quote to me in 300 milliseconds
   edMenu "File", "Revert to Saved..."
   if not edWaitFor("there is a stack sStack and there is a button id sKeep[" & quote & "okay" & quote & "] of card 1 of stack sStack", 5000) then
      throw "File > Revert to Saved did not bring the saved stack back; the question:" && sReport["answer"]
   end if
   if the label of button id sKeep["okay"] of card 1 of stack sStack is not "Saved label" then throw "the reverted stack is not the one saved"
   edShotStack sStack, "28-reverted"
end ed_revert_to_saved

-- File > Save As under a second name with the Project Browser listing
-- the stack, and then a control renamed: the IDE asks nothing, the stack
-- stays the one just saved and the Project Browser lists its card.
-- (The browser's rows named the stack by the file it had left. At the
-- next thing the browser heard, a control renamed for one, it asked the
-- engine about those rows; the engine read the old file, found a stack
-- of that name in memory already, and the IDE asked "A stack with the
-- same name as the one you are trying to load is already open". A
-- standalone build saves the stack into its folder the same way, and on
-- Windows, where the builder hands out the IDE's waiting messages one at
-- each step, the question came in the middle of the build and failed
-- it: #538, run 43962703701)
on ed_save_as_second_name
   local tPB, tOld, tPath, tListed, tControl, tName, tSettled
   edFront
   put revIDEPaletteToStackName("project browser") into tPB
   if not edOpen(tPB) then edMenu "Tools", "Project Browser"
   if not edWaitFor("edOpen(pAx)", 5000, tPB) then throw "Tools > Project Browser opened nothing"
   revIDEShowInProjectBrowser the long id of card 1 of stack sStack
   if not edWaitFor("edPBRow(pAx, the long id of card 1 of stack sStack) is not empty", 5000, tPB) then
      throw "the Project Browser does not list the stack's card before File > Save As"
   end if
   edFront
   put the effective filename of stack sStack into tOld
   put sWork & "/" & kSecondFile into tPath
   -- (a question the IDE asks from here on is answered with Cancel, which
   -- leaves the stacks as they are, and is what the task fails on)
   put empty into sReport["answer"]
   send "edAnswerWith" && quote & "Cancel,Cancel,Cancel" & quote to me in 300 milliseconds
   edFileDialog kSecondFile, "Save"
   edMenu "File", "Save As..."
   if not edWaitFor("the effective filename of stack sStack is pAx", 8000, tPath) then
      throw "File > Save As under a second name left the stack's file as" && the effective filename of stack sStack & ", not" && tPath & "; the dialog:" && sReport["dialog"] & "; the IDE asked:" && sReport["answer"]
   end if
   -- (the file it left is still there: it is what the engine read)
   if there is not a file tOld then throw "the file the stack was saved in before is gone:" && tOld
   -- the browser lists the card of the stack as it is now, whose long id
   -- names the new file, without waiting to hear of something else (what
   -- it says is kept until the IDE has been seen to ask nothing)
   put edWaitFor("edPBRow(pAx, the long id of card 1 of stack sStack) is not empty", 3000, tPB) into tListed
   put "saved," && edSettled(8000) into tSettled
   -- a control renamed, as the Inspector's Name does, and named back
   put edControl("checkbox") into tControl
   put the short name of tControl into tName
   if sReport["answer"] is empty then
      edCancelPending "edAnswerWith"
      send "edAnswerWith" && quote & "Cancel,Cancel,Cancel" & quote to me in 300 milliseconds
      set the name of tControl to "Renamed After Save As"
      put "; a control renamed," && edSettled(8000) after tSettled
   end if
   if sReport["answer"] is empty then
      set the name of tControl to tName
      put "; named back," && edSettled(8000) after tSettled
   end if
   edCancelPending "edAnswerWith"
   edRecord "INFO save-as-second-name:" && tSettled
   if sReport["answer"] is not empty then
      throw "after File > Save As under a second name (" & tSettled & ") the IDE asked:" && sReport["answer"]
   end if
   if the effective filename of stack sStack is not tPath then
      throw "after File > Save As and a control renamed the stack's file is" && the effective filename of stack sStack & ", not" && tPath
   end if
   if the short name of tControl is not tName then throw "the control did not get its name back"
   if not tListed then
      throw "after File > Save As the Project Browser did not list the stack's card under its new file"
   end if
   if edPBRow(tPB, the long id of card 1 of stack sStack) is empty then
      throw "after a control was renamed the Project Browser no longer lists the stack's card"
   end if
   edShotStack tPB, "28b-saved-under-a-second-name"
end ed_save_as_second_name

-- the Script Editor's Edit > Find and Replace: Current Tab picked as
-- where, a word typed into Find and its replacement into Replace, and
-- Replace All clicked: the script has the new word, and Apply gives the
-- button it
on ed_se_find_replace
   local tSE, tButton, tField, tFind
   put edOkay() into tButton
   put edOpenScript(tButton) into tSE
   put edSeField(tSE) into tField
   -- (as debug-breakpoint: the Script Editor fills its field after it
   -- opens, and the Find dialog takes its word from the field's selection)
   if not edWaitFor("the text of pAx contains " & quote & "cClicks" & quote, 5000, tField) then
      throw "the Script Editor did not show the button's script:" && edJoin(the text of tField)
   end if
   dispatch "menuPick" to button "Edit" of group "Menubar" of card "Main" of stack tSE with "Find and Replace..."
   put "revSEFind" into tFind
   if not edWaitFor("edOpen(pAx)", 3000, tFind) then throw "the Script Editor's Edit > Find and Replace opened nothing"
   edOnScreen tFind
   if the label of button "Location" of card "Main" of stack tFind is not "Current Tab" then
      -- (picked from its menu: the label, then the menuPick)
      set the label of button "Location" of card "Main" of stack tFind to "Current Tab"
      dispatch "menuPick" to button "Location" of card "Main" of stack tFind with "Current Tab"
   end if
   if not the enabled of button "Replace" of card "Main" of stack tFind then throw "Replace is disabled with Current Tab picked"
   edTypeInCombo tFind, "Find", "cClicks"
   edTypeInCombo tFind, "Replace", "cPresses"
   edClickAt tFind, the loc of button "Replace all" of card "Main" of stack tFind
   if not edWaitFor("the text of pAx contains " & quote & "cPresses" & quote & " and not (the text of pAx contains " & quote & "cClicks" & quote & ")", 3000, tField) then
      throw "Replace All did not replace cClicks with cPresses (" & field "Status" of card "Main" of stack tFind & "):" && edJoin(the text of tField)
   end if
   edShotStack tFind, "29-se-find-replace"
   close stack tFind
   edApply tSE
   if not edWaitFor("the script of pAx contains " & quote & "cPresses" & quote, 3000, tButton) then throw "the replaced script did not apply"
   edShotStack tSE, "29-se-replaced"
   edCloseScriptEditors
end ed_se_find_replace

-- a combo box of the Find dialog clicked, all its text selected (Ctrl or
-- Cmd+A) and pText typed. The keys go where the keyboard focus is: on the
-- Intel Mac (main 59072d18, the dark everyday tour) "typing in Find gave
-- \"\"", every key lost, where the same tree passed on every other run.
-- So the Find window (a palette) is waited for until it has the keyboard
-- focus, and the click until the focus is in the combo box (it
-- is clicked again, at most twice more, each time recorded, when the
-- focus is not there yet); a miss then says where the focus was. What is
-- checked is the same: the combo box shows what was typed.
--
-- The focus is not enough. On main fde49edf (the Intel Mac again, dark)
-- the miss named the combo box as the focus, with no click repeated, and
-- the label still empty. A combo box types into a field of its own (its
-- entry), and the engine gives a key to that field only while it is the
-- engine's active field (MCField::kdown: "MCactivefield != this" drops
-- the key, and type reports nothing); the focusedObject is the card's
-- focused control, the button, and stays so when another window's field
-- becomes the active one or the active field is let go (MCStack::kfocusset
-- unselects the entry of a window that is not focused). So the click is
-- waited for until the entry is the active field too: the selectedChunk
-- then ends "of button <the combo box's number>" (the entry's chunk is
-- its button's), as it does on Linux; with the entry let go the keys were
-- lost there too ("select empty" after the click: the label kept, then a
-- second click and the same typing gave it). And a miss now says what
-- moved: the selectedField and selectedChunk before and after the typing,
-- the label before it, the Script Editor's messages still waiting, and
-- the focus messages the Find and Script Editor windows were sent from
-- the click on (a preOpenCard of the Find card is its update, which sets
-- the label again)
command edTypeInCombo pStack, pCombo, pText
   local tCombo, tTries, tBefore, tKeysBefore
   put the long id of button pCombo of card "Main" of stack pStack into tCombo
   if not edWaitFor("edFocusIn(pAx)", 3000, pStack) then
      edRecord "INFO" && pStack && "does not have the keyboard focus before typing in" && pCombo & \
            ": the focus" && edJoin(the focusedObject) & ", the topStack" && the short name of the topStack
   end if
   edWatchKeys true
   put 0 into tTries
   repeat
      add 1 to tTries
      edClickAt pStack, (the left of tCombo + 30) & "," & item 2 of the loc of tCombo
      if edWaitFor("edFocusOn(pAx) and edEntryActive(pAx)", 1000, tCombo) then exit repeat
      edRecord "INFO click" && tTries && "in" && pCombo && "left the keys with" && edKeysAt() & \
            "; the topStack" && the short name of the topStack & "; waiting:" && edSeWaiting() & \
            "; seen:" && edWatched()
      if tTries >= 3 then exit repeat
   end repeat
   put the label of tCombo into tBefore
   put edKeysAt() into tKeysBefore
   edType pStack, "a", "command"
   edType pStack, pText
   if not edWaitFor("the label of pAx is pBx", 1000, tCombo, pText) then
      local tMiss
      put "typing in" && pCombo && "gave" && quote & the label of tCombo & quote & \
            "; the focus" && edJoin(the focusedObject) & ", the topStack" && the short name of the topStack & \
            ", the defaultStack" && the short name of the defaultStack & \
            "; before typing the label" && quote & tBefore & quote && "and" && tKeysBefore & \
            "; after it" && edKeysAt() & "; waiting:" && edSeWaiting() & "; seen:" && edWatched() into tMiss
      edWatchKeys false
      throw tMiss
   end if
   edWatchKeys false
end edTypeInCombo

-- whether the keyboard focus is in a window of the stack pStack (the
-- focusedObject is the focused window's control with the focus, or its
-- card)
function edFocusIn pStack
   local tFocus
   put the focusedObject into tFocus
   return tFocus is not empty and tFocus contains ("stack" && quote & pStack & quote)
end edFocusIn

-- whether the keyboard focus is on the control pControl (a long id)
function edFocusOn pControl
   -- (the focusedObject is a long id, as the engine spells it for
   -- pControl)
   return the focusedObject is pControl
end edFocusOn

-- whether the entry of the combo box pCombo (a long id) is the engine's
-- active field, the one that typed keys reach: the selectedChunk names
-- the active field's text, and an entry's as its button's ("char 0 to 2
-- of button 1" for Find, on Linux); empty when no field is active
function edEntryActive pCombo
   local tChunk
   put the selectedChunk into tChunk
   return tChunk is not empty and word -2 to -1 of tChunk is ("button" && the number of pCombo)
end edEntryActive

-- where typed keys would go, for a record: the focus, and the engine's
-- active field (its selectedChunk and the text selected in it)
function edKeysAt
   return "the focus" && edJoin(the focusedObject) & ", the selectedField" && quote & the selectedField & quote & \
         ", the selectedChunk" && quote & the selectedChunk & quote & ", the selectedText" && quote & edJoin(the selectedText) & quote
end edKeysAt

-- the messages waiting (send ... in) for a Script Editor window, the Find
-- window or the IDE's palette toggle, each as its name and its target's
-- short name: what can still move the keys after a click
function edSeWaiting
   local tLine, tOut
   repeat for each line tLine in the pendingMessages
      if tLine contains "revNewScriptEditor" or tLine contains "revSEFind" or tLine contains "revseutilities" or \
            item 3 of tLine begins with "revSE" then
         put item 3 of tLine & "/" & edShortTarget(item 4 to -1 of tLine) & " " after tOut
      end if
   end repeat
   if tOut is empty then return "nothing"
   return word 1 to -1 of tOut
end edSeWaiting

-- an object's long id cut to its own name and its window's
function edShortTarget pLongID
   local tOut, tError
   put word 1 to 3 of pLongID into tOut
   if pLongID contains "revSEFind" then return tOut && "(Find)"
   if pLongID contains "revNewScriptEditor" then return tOut && "(Script Editor)"
   if pLongID contains "revTools" then
      -- (which tile: the press another tile still held went to the card
      -- and its release to that tile, edDragDone)
      if word 1 of tOut is not "card" and word 1 of tOut is not "stack" then
         try
            return tOut && "(Tools," && the short name of pLongID & ")"
         catch tError
         end try
      end if
      return tOut && "(Tools)"
   end if
   -- (a stack of a file: its file's name)
   if word 1 of tOut is "stack" and tOut contains "/" then
      set the itemDelimiter to "/"
      return "stack" && quote & item -1 of tOut
   end if
   return tOut
end edShortTarget

-- the focus and card messages the Find and Script Editor windows are
-- sent, watched by a front script while a combo box is typed in (true)
-- and no longer (false); edWatched() lists them, each with the
-- milliseconds since the watching began
command edWatchKeys pOn
   local tDefault, tScript, tMessage
   put the defaultStack into tDefault
   set the defaultStack to "oxt_everyday"
   lock messages
   if pOn then
      if there is not a button "oxt_everyday_keys" then create invisible button "oxt_everyday_keys"
      repeat for each item tMessage in "preOpenCard,openCard,closeCard,focusIn,focusOut,openField,exitField,closeField,suspendStack,resumeStack"
         put "on" && tMessage & return & \
               "   if the long id of the target contains " & quote & "revSEFind" & quote & " or the long id of the target contains " & quote & "revNewScriptEditor" & quote & " then" & return & \
               "      dispatch " & quote & "edSeen" & quote & " to stack " & quote & "oxt_everyday" & quote & " with " & quote & tMessage & quote & ", the long id of the target" & return & \
               "   end if" & return & \
               "   pass" && tMessage & return & \
               "end" && tMessage & return after tScript
      end repeat
      set the script of button "oxt_everyday_keys" to tScript
      put empty into sKeep["seen"]
      put the milliseconds into sKeep["watching"]
      insert the script of button "oxt_everyday_keys" into front
   else if there is a button "oxt_everyday_keys" then
      remove the script of button "oxt_everyday_keys" from front
   end if
   unlock messages
   if there is a stack tDefault then set the defaultStack to tDefault
end edWatchKeys

on edSeen pMessage, pTarget, pTool
   put (the milliseconds - sKeep["watching"]) && pMessage && edShortTarget(pTarget) after sKeep["seen"]
   if pTool is not empty then put " (" & pTool & ")" after sKeep["seen"]
   put "; " after sKeep["seen"]
end edSeen

function edWatched
   if sKeep["seen"] is empty then return "nothing"
   return word 1 to -1 of sKeep["seen"]
end edWatched

-- a breakpoint set by a click in the gutter beside the handler's third
-- line, and a click on the button in Run mode: the
-- Script Editor stops there and its Variables pane lists the handler's
-- variable; Step Over runs one line; Run goes on to the end
on ed_debug_breakpoint
   local tSE, tButton, tError
   put edOkay() into tButton
   set the script of tButton to "on mouseUp" & return & "   local tCount" & return & "   put 5 into tCount" & return & \
         "   add 1 to tCount" & return & "   set the cResult of me to tCount" & return & "end mouseUp"
   set the cResult of tButton to empty
   put edOpenScript(tButton) into tSE
   -- (the Script Editor fills its field a moment after it opens: on the
   -- Intel Mac, in the dark tour of main at fe83adb58 and of #409, line 4
   -- was measured as 163,81,163,102, no width at the field's top, so in a
   -- field that did not hold the script yet, and the click set no
   -- breakpoint; so the click waits for the line it aims at)
   if not edWaitFor("the text of pAx contains " & quote & "add 1 to tCount" & quote, 5000, edSeField(tSE)) then
      throw "the Script Editor did not show the button's script:" && edJoin(the text of edSeField(tSE))
   end if
   edGutterClick tSE, 4
   put the breakpoints into sDebug["breakpoints"]
   edRecord "INFO the breakpoints:" && edJoin(sDebug["breakpoints"])
   -- (the IDE's own stacks keep breakpoints of their own, so the list is
   -- not empty when the click set none: the button's line 4 is looked for)
   if not edHasBreakpoint(sDebug["breakpoints"], tButton, 4) then
      throw "the Script Editor set no breakpoint at line 4 of the button:" && edJoin(sDebug["breakpoints"])
   end if
   edToolTile "com.livecode.tool.Browse"
   dispatch "revSetTestEnvironment" to stack "Home" with false
   put empty into sDebug["seen"]
   put 0 into sDebug["varTries"]
   send "edDebugStopped" && quote & tSE & quote to me in 300 milliseconds
   try
      edClickAt sStack, the loc of tButton
   catch tError
   end try
   dispatch "revSetTestEnvironment" to stack "Home" with true
   edToolTile "com.livecode.tool.Pointer"
   set the breakpoints to empty
   edRecord "INFO the debugger:" && edJoin(sDebug["seen"])
   if tError is not empty then throw "the click in Run mode stopped:" && edJoin(tError)
   if sDebug["stopped"] is not true then throw "the handler did not stop at the breakpoint:" && edJoin(sDebug["seen"])
   if sDebug["variable"] is not true then throw "the Variables pane did not show tCount with 5:" && edJoin(sDebug["seen"])
   if sDebug["stepped"] is not true then throw "Step Over did not go to the next line:" && edJoin(sDebug["seen"])
   if the cResult of tButton is not 6 then throw "the handler did not run to its end after Run (cResult" && the cResult of tButton & ")"
   edCloseScriptEditors
end ed_debug_breakpoint

-- whether the breakpoints pBreakpoints (the breakpoints' lines: an
-- object's long id, a comma and a line number) hold the line pLine of
-- the object pObject. The object is matched by its type and id, not its
-- whole long id, whose stack path the engine may spell another way
-- (/private/var for /var on a Mac)
function edHasBreakpoint pBreakpoints, pObject, pLine
   local tBreakpoint
   repeat for each line tBreakpoint in pBreakpoints
      if word 1 to 3 of tBreakpoint is (word 1 of the name of pObject && "id" && the id of pObject) and \
            item -1 of tBreakpoint is pLine then return true
   end repeat
   return false
end edHasBreakpoint

-- a click in the Script Editor's gutter beside the line pLine
command edGutterClick pSE, pLine
   local tField, tRect, tGutter
   put edSeField(pSE) into tField
   put the formattedRect of line pLine of tField into tRect
   put the long id of group "Gutter" of group "Editor" of card "Main" of stack pSE into tGutter
   edRecord "INFO the gutter" && the rect of tGutter && "beside line" && pLine && "at" && tRect
   edClickAt pSE, (the left of tGutter + 8) & "," & ((item 2 of tRect + item 4 of tRect) div 2)
end edGutterClick

-- while the handler is stopped: what the Script Editor shows, then a
-- click on Step Over, then on Run
on edDebugStopped pSE, pTries
   local tLine, tVars
   if pTries is empty then put 0 into pTries
   put the executionContexts into tLine
   if not (sDebug["stopped"] is true) then
      if tLine contains "mouseUp" or (there is a stack pSE and the enabled of button "Step Over" of group "Toolbar" of card "Main" of stack pSE) then
         put true into sDebug["stopped"]
         put "stopped;" after sDebug["seen"]
      else if pTries < 40 then
         send "edDebugStopped" && quote & pSE & quote & "," && pTries + 1 to me in 250 milliseconds
         exit edDebugStopped
      else
         put "never stopped;" after sDebug["seen"]
         exit edDebugStopped
      end if
   end if
   put edSeVariables(pSE) into tVars
   -- (the Variables pane is filled a moment after the stop: on the Intel
   -- Mac it was still empty when first read, so it is waited for)
   if not (tVars contains "tCount=5") and sDebug["varTries"] < 12 then
      add 1 to sDebug["varTries"]
      send "edDebugStopped" && quote & pSE & quote & "," && pTries to me in 250 milliseconds
      exit edDebugStopped
   end if
   put "variables" && tVars & ";" after sDebug["seen"]
   if tVars contains "tCount=5" then put true into sDebug["variable"]
   try
      edShotStack pSE, "30-debug-stopped"
   catch tVars
   end try
   send "edDebugStep" && quote & pSE & quote to me in 100 milliseconds
end edDebugStopped

-- (the click, then nothing: the debugger steps once this handler is done,
-- and its Variables pane is read in the next)
on edDebugStep pSE
   edClickAt pSE, the loc of button "Step Over" of group "Toolbar" of card "Main" of stack pSE
   send "edDebugStepped" && quote & pSE & quote & ", 0" to me in 300 milliseconds
end edDebugStep

on edDebugStepped pSE, pTries
   local tVars
   put edSeVariables(pSE) into tVars
   if not (tVars contains "tCount=6") and pTries < 10 then
      send "edDebugStepped" && quote & pSE & quote & "," && pTries + 1 to me in 300 milliseconds
      exit edDebugStepped
   end if
   put "after Step Over" && tVars & ";" after sDebug["seen"]
   if tVars contains "tCount=6" then put true into sDebug["stepped"]
   edClickAt pSE, the loc of button "Run" of group "Toolbar" of card "Main" of stack pSE
end edDebugStepped

-- Help > Dictionary, "answer file" typed into its search: its list has
-- the entry and shows it
on ed_dictionary_search
   local tBefore, tDict, tGot
   put the openStacks into tBefore
   send "tNewDictionaryDisplay" to stack "revMenuBar"
   if the cDictionaryDisplayMethod of stack "revPreferences" is not true and revIDEBrowserWidgetUnavailable() then
      put "no browser widget: the Dictionary opens in the system's browser" into sSkip
      return "skipped"
   end if
   put revIDEPaletteToStackName("dictionary") into tDict
   if not edWaitFor("edOpen(pAx)", 20000, tDict) then throw "Help > Dictionary opened no Dictionary"
   if there is not a widget "Dictionary" of stack tDict then
      put "the Dictionary is not LiveCode's (the text dictionary is chosen)" into sSkip
      close stack tDict
      return "skipped"
   end if
   -- (its page loads its data once it is open)
   edPause 3000
   put edPageReport(tDict, "$('#ui_filer').val('answer file').keyup();" & \
         "setTimeout(function(){var r=$('#table_list tr');" & \
         "liveCode.oxtEdReport(r.length+'|'+(r.length?$(r[0]).text().replace(/\s+/g,' ').substr(0,80):'')+'|'+" & \
         "document.body.innerText.indexOf('Displays a standard file dialog')+'');},1500);") into tGot
   edRecord "INFO the Dictionary's search for answer file:" && tGot
   set the itemDelimiter to "|"
   if not (item 1 of tGot > 0) then throw "the Dictionary's search for answer file found nothing:" && tGot
   if not (item 2 of tGot contains "answer file") then throw "the Dictionary's first result for answer file is" && item 2 of tGot
   set the itemDelimiter to comma
   edShotStack tDict, "31-dictionary-search"
   close stack tDict
end ed_dictionary_search

-- File > Import As Control > Image File: the IDE's dialog, a PNG picked:
-- an image on the card with the picture's size
on ed_import_image
   local tPNG, tCount, tImage
   put sWork & "/everyday-icon.png" into tPNG
   edWritePng tPNG
   edFront
   revIDEDeselectAll
   put the number of images of card 1 of stack sStack into tCount
   edFileDialog "everyday-icon.png", "Open"
   edMenu "File", "Import As Control|image"
   if not edWaitFor("the number of images of card 1 of stack sStack is pAx + 1", 5000, tCount) then throw "Import As Control > Image File made no image; the dialog:" && sReport["dialog"]
   put the long id of last image of card 1 of stack sStack into tImage
   if the formattedWidth of tImage is not 24 or the formattedHeight of tImage is not 24 then throw "the image imported is" && the formattedWidth of tImage & "x" & the formattedHeight of tImage & ", not 24x24"
   set the name of tImage to "Icon"
   edShotStack sStack, "32-imported-image"
end ed_import_image

-- the Inspector's Icons section of the button: the image's ID typed in
-- as its icon: the button shows it
on ed_image_as_icon
   local tPI, tButton, tImage
   put edOkay() into tButton
   put the long id of image "Icon" of card 1 of stack sStack into tImage
   put edInspect(tButton) into tPI
   get edSection(tPI, "Icons")
   edTypeInEditor tPI, "icon", the short id of tImage
   if not edWaitFor("the icon of pAx is the short id of pBx", 3000, tButton, tImage) then throw "the Inspector's Icon did not give the button the image (" & the icon of tButton & ")"
   edShotStack sStack, "33-image-as-icon"
   edCloseInspectors
end ed_image_as_icon

-- the Geometry Manager in the Inspector: the slider kept to
-- the window's right edge, and the window made wider: it moves with it
on ed_geometry_manager
   local tPI, tSlider, tEditor, tRight, tGap, tShown
   put edControl("scrollbar") into tSlider
   put edInspect(tSlider) into tPI
   put edSection(tPI, "Geometry Manager") into tShown
   put edEditor(tPI, "geometry") into tEditor
   if tEditor is empty then throw "the slider's Inspector has no Geometry Manager (section" && tShown & ")"
   edGeometryRight tPI, tEditor
   if not edWaitFor("the cREVGeometry[" & quote & "Master,moveH" & quote & "] of pAx is true", 3000, tSlider) then
      throw "the Geometry Manager did not keep the slider to the right edge:" && edJoin(edGeometry(tSlider))
   end if
   edCloseInspectors
   put the width of stack sStack - the right of tSlider into tGap
   set the width of stack sStack to the width of stack sStack + 100
   if not edWaitFor("the width of stack sStack - the right of pAx is pBx", 3000, tSlider, tGap) then
      throw "the slider kept to the right edge did not move when the window grew (" & the width of stack sStack - the right of tSlider && "from the edge, was" && tGap & ")"
   end if
   edShotStack sStack, "34-geometry"
   set the width of stack sStack to the width of stack sStack - 100
end ed_geometry_manager

-- Edit > Preferences, a setting changed in its window and changed back:
-- the preference follows each time
on ed_preferences_change
   local tPrefs, tBox, tWas
   edMenu "Edit", "Preferences"
   put revIDEPaletteToStackName("preferences") into tPrefs
   if not edWaitFor("edOpen(pAx)", 5000, tPrefs) then throw "Edit > Preferences opened nothing"
   put edPrefsCheckbox(tPrefs) into tBox
   if tBox is empty then throw "no setting found to change in Preferences"
   put the hilite of tBox into tWas
   edRecord "INFO Preferences: the setting" && the short name of tBox && "is" && tWas && "(" & sReport["pref"] & ")"
   edClickAt tPrefs, the loc of tBox
   if not edWaitFor("the hilite of pAx is not pBx and edPrefValue() is not sReport[" & quote & "prefWas" & quote & "]", 3000, tBox, tWas) then
      throw "a click on" && the short name of tBox && "changed nothing (preference" && sReport["pref"] && "is" && edPrefValue() & ")"
   end if
   edShotStack tPrefs, "35-preferences-changed"
   edClickAt tPrefs, the loc of tBox
   if not edWaitFor("the hilite of pAx is pBx and edPrefValue() is sReport[" & quote & "prefWas" & quote & "]", 3000, tBox, tWas) then
      throw "a second click did not change" && the short name of tBox && "back (preference" && edPrefValue() & ")"
   end if
   close stack tPrefs
end ed_preferences_change

-- The Quick Start Guide's first lesson, done as its notes say. It is the
-- first example Learn offers, and for many the first thing they do in
-- the IDE: a button dragged from the Tools palette onto the lesson's Try
-- It box, named Color in the Inspector, and the lesson's two lines run
-- in the Message Box, which its shortcut opens. The notes must say what
-- a newcomer could not tell from them (openxtalk.org p=26390): that the
-- stack they speak of is this window, where on it the button goes, and
-- that the Message Box is a window the Tools menu opens. The Guide is
-- opened as Learn opens an example, and taken out of memory unsaved
-- whatever happened (edGuideAway). A Guide already in memory is a
-- person's own: the task stops, and it stays as it is (edGuideGone)
on ed_quick_start_first_lesson
   local tFile, tError, tMiss
   put revEnvironmentResourcesPath() & "/" & kGuideFile into tFile
   if there is no file tFile then throw "the Quick Start Guide is not in this IDE:" && tFile
   if edInMemory(kGuideStack) then throw "a stack called" && kGuideStack && "is in memory before the lesson"
   try
      edGuideLesson tFile
   catch tError
      put edJoin(tError) into tMiss
      try
         edShotScreen "zz-quick-start-first-lesson"
      catch tError
      end try
   end try
   edGuideAway
   if tMiss is not empty then throw tMiss
   if edInMemory(kGuideStack) then throw "the Quick Start Guide is still in memory after the lesson"
   edRecord "INFO the Quick Start Guide's first lesson done as its notes say:" && sReport["guide"]
end ed_quick_start_first_lesson

-- What a person drops on the Try It box of the Quick Start Guide's first
-- lesson can be seen, in the look the IDE has on. In the dark look the
-- system draws a new control for a dark window, with white words, and the
-- Try It box stayed light: "when you drag a control over in dark mode it
-- is almost invisible" (openxtalk.org p=26402, on a Mac; the same on
-- Windows 11). The lessons' stages now follow the look. Three kinds of
-- control are dragged from the Tools palette, as the lesson has a button
-- dragged: one with a face of its own, one that is words alone, and one
-- with a mark and words, and each must change what is seen of the box
on ed_quick_start_dropped_shows
   local tFile, tError, tMiss
   put revEnvironmentResourcesPath() & "/" & kGuideFile into tFile
   if there is no file tFile then throw "the Quick Start Guide is not in this IDE:" && tFile
   if edInMemory(kGuideStack) then throw "a stack called" && kGuideStack && "is in memory before the task"
   try
      edGuideDropped tFile
   catch tError
      put edJoin(tError) into tMiss
      try
         edShotScreen "zz-quick-start-dropped-shows"
      catch tError
      end try
   end try
   edGuideAway
   if tMiss is not empty then throw tMiss
   if edInMemory(kGuideStack) then throw "the Quick Start Guide is still in memory after the task"
   edRecord "INFO what is dropped on the Quick Start Guide's Try It box shows:" && sReport["dropped"]
end ed_quick_start_dropped_shows

-- File > Save as Standalone Application... on the stack, and the build
-- stops on an error after the builder has changed the stack in memory:
-- the stack a person is left with is the one they had (openxtalk.org
-- p=26321, tperry2x: now and then a stack "gets a copy of the IDE's
-- Answer and Ask stack embedded in it"). For each target the builder
-- puts the IDE's Answer and Ask dialogs into the stack as substacks,
-- takes its standalone settings off and saves it into the build folder,
-- and up to 0.2.8-dp.1 only the end of a build put it back: one that
-- stopped in between left the build's copy open as the stack being
-- worked on, and the next Save wrote the dialogs into the stack's file.
-- The build is stopped here where its copy is about to be saved, the
-- stack changed and closed and still under its own file name
-- (edStoppedBuild); then a change and File > Save, as a person goes on
on ed_standalone_stopped_build
   local tWhy, tPath, tBefore, tMarker
   put edBuildSkip() into sSkip
   if sSkip is not empty then return "skipped"
   edFront
   edBuildSettings sStack, "Everyday"
   edSaveForBuild sStack
   put the effective filename of stack sStack into tPath
   put URL ("binfile:" & tPath) into tBefore
   put edStoppedBuild(sStack, "Saving stack files...") into tWhy
   if tWhy is not empty then throw tWhy
   edRecord "INFO the build stopped at Saving stack files... after:" && edJoin(sReport["steps"])
   edFront
   put "saved-" & the milliseconds into tMarker
   set the cEverydayBuild of stack sStack to tMarker
   edMenu "File", "Save"
   if not edWaitFor("URL (" & quote & "binfile:" & quote & " & pAx) contains pBx", 5000, tPath, tMarker) then
      throw "File > Save after the build that stopped did not write the change to" && tPath
   end if
   if edHasDialog(URL ("binfile:" & tPath)) and not edHasDialog(tBefore) then
      throw "File > Save after the build that stopped wrote the IDE's Answer or Ask dialog into" && tPath && "(" & the number of bytes of URL ("binfile:" & tPath) && "bytes, before the build" && the number of bytes of tBefore & ")"
   end if
   if the substacks of stack sStack is not empty then throw "the stack saved after the build has the substacks" && edJoin(the substacks of stack sStack)
   edShotStack sStack, "36-standalone-stopped-build"
end ed_standalone_stopped_build

-- A stack whose file is named .mc, as MetaCard's and old LiveCode's
-- were, built from the File menu: up to 0.2.8-dp.1 such a build stopped
-- by itself, which is one way a person met the task before. The IDE
-- opens .mc, .lc, .stk and .oxtscript as stacks, and the builder kept
-- such a file's name for its copy in the build folder but saved the copy
-- with ".oxtstack" added, so the steps after looked for a stack that was
-- not there, and none of these ever built (in this task 0.2.8-dp.1 went
-- on to write the stack's own file again, 713 bytes where 721 were). The
-- build is stopped here where the engine is about to be attached, after
-- the builder has saved its copy once more under the name it expects it
-- to have and taken it out of memory: the stack and its file are as
-- they were then too
on ed_standalone_mc_stack_file
   local tWhy, tPath, tDefault
   put edBuildSkip() into sSkip
   if sSkip is not empty then return "skipped"
   put sWork & "/" & kMcFile into tPath
   put the defaultStack into tDefault
   create stack kMcStack
   set the defaultStack to kMcStack
   create button "Hello"
   set the script of button "Hello" of stack kMcStack to "on mouseUp" & return & "   answer the short name of me" & return & "end mouseUp"
   if there is a stack tDefault then set the defaultStack to tDefault
   -- (its file by script: the subject is the build, and File > Save asks
   -- for a name while the stack's file is not there)
   set the filename of stack kMcStack to tPath
   save stack kMcStack as tPath
   if there is not a file tPath then throw "could not save" && kMcStack && "as" && tPath && "(" & the result & ")"
   go stack kMcStack
   if not edWaitFor("the short name of the topStack is kMcStack", 3000) then throw "the stack" && kMcStack && "is not in front (" & the short name of the topStack & ")"
   edBuildSettings kMcStack, "EverydayMc"
   edSaveForBuild kMcStack
   put edStoppedBuild(kMcStack, "Attaching engine...") into tWhy
   if tWhy is not empty then throw tWhy
   edRecord "INFO the build of" && kMcFile && "reached Attaching engine... after:" && edJoin(sReport["steps"])
   edShotStack kMcStack, "37-standalone-mc-stack-file"
   edRemoveBuiltStack kMcStack
end ed_standalone_mc_stack_file

-- File > Save as Standalone Application... to its end, and the
-- standalone run: what a build is for, and what the two tasks before
-- stop short of. A stack of its own, saved as .livecode as
-- the stacks people bring with them are, is built for this computer with
-- the builder's dialogs on, as a person has them (edFullBuild): the IDE
-- says "Standalone application saved successfully.", the stack is sent
-- savingStandalone and then standaloneSaved with the folder, and the
-- stack and its file are as they were, with no copy of the IDE's
-- dialogs left. Then the standalone is started as a program is. Its
-- stack script (edAppScript) writes what it finds itself to be into a
-- file and quits: it runs as a standalone, under its name, with the
-- controls and the text it was saved with and the Answer and Ask dialogs
-- its settings ask for, and without the standalone settings themselves
-- (the builder takes them, the build folder's path among them, off the
-- copy it builds)
on ed_standalone_built_and_run
   local tWhy, tPath, tRan, tDefault, tExe, tCommand, tOutput, tExit, tReport, tWant
   put edBuildSkip() into sSkip
   if sSkip is not empty then return "skipped"
   -- (a copy of an IDE dialog that a build before left in memory is that
   -- task's to say, as it does: over one, 0.2.8-dp.1 asked about a stack
   -- "answer dialog" already in memory again and again, edBuildSaid)
   if edDialogCopies() is not empty then throw "a build before this one left in memory:" && edDialogCopies() & "; no build is tried over it"
   put sWork & "/" & kAppFile into tPath
   put sWork & "/everyday-app-ran.txt" into tRan
   put the defaultStack into tDefault
   create stack kAppStack
   set the defaultStack to kAppStack
   create field "Greeting"
   put kAppGreeting into field "Greeting" of stack kAppStack
   -- (above the button, which is made where the field was)
   set the rect of field "Greeting" of stack kAppStack to 20,40,236,66
   create button "Hello"
   if there is a stack tDefault then set the defaultStack to tDefault
   set the script of stack kAppStack to edAppScript()
   set the cEverydayRan of stack kAppStack to tRan
   -- (its file by script, as the task before: the subject is the build)
   set the filename of stack kAppStack to tPath
   save stack kAppStack as tPath
   if there is not a file tPath then throw "could not save" && kAppStack && "as" && tPath && "(" & the result & ")"
   go stack kAppStack
   if not edWaitFor("the short name of the topStack is kAppStack", 3000) then throw "the stack" && kAppStack && "is not in front (" & the short name of the topStack & ")"
   edBuildSettings kAppStack, kAppName
   edSaveForBuild kAppStack
   put edFullBuild(kAppStack, "38-standalone-build-said") into tWhy
   if tWhy is not empty then throw tWhy
   edRecord "INFO the build of" && kAppFile && "went through:" && edJoin(sReport["steps"])
   edRecord "INFO the IDE said:" && edJoin(sReport["said"]) && "and sent the stack:" && edJoin(sReport["messages"])
   -- (looked for from the build folder down, and found in the folder
   -- standaloneSaved came with)
   edRecord "INFO the build folder holds:" && edJoin(line 1 to 40 of edListing(edBuildFolder(kAppName), 0))
   put edFindStandalone(edBuildFolder(kAppName), kAppName, 0) into tExe
   if tExe is empty then throw "no standalone" && kAppName && "in the build folder" && edBuildFolder(kAppName)
   if not (tExe begins with sReport["built"]) then throw "the standalone" && tExe && "is not in the folder standaloneSaved came with," && sReport["built"]
   -- started as a program is, and waited for: it quits by itself
   if there is a file tRan then delete file tRan
   put tExe into tCommand
   if the platform is "Win32" then replace "/" with "\" in tCommand
   put shell(quote & tCommand & quote) into tOutput
   put the result into tExit
   if tExit is not empty and tExit is not 0 then throw "the standalone" && tExe && "ended with" && tExit & ":" && edJoin(tOutput)
   if there is not a file tRan then throw "the standalone" && tExe && "ran and wrote nothing to" && tRan && "(it printed:" && edJoin(tOutput) & ")"
   put URL ("file:" & tRan) into tReport
   set the caseSensitive to true
   repeat for each line tWant in "EVERYDAY APP RAN" & return & \
         "environment: standalone application" & return & \
         "stack:" && kAppStack & return & \
         "controls: 2" & return & \
         "greeting:" && kAppGreeting & return & \
         "answer dialog: true" & return & \
         "ask dialog: true" & return & \
         "standalone settings kept: 0"
      if tWant is not among the lines of tReport then throw "the standalone did not report" && quote & tWant & quote & ": it reported" && edJoin(tReport)
   end repeat
   edRecord "INFO the standalone" && tExe && "reported:" && edJoin(tReport)
   edShotStack kAppStack, "39-standalone-built-and-run"
   edRemoveBuiltStack kAppStack
end ed_standalone_built_and_run

-- File > Save as Standalone Application... when the builder cannot
-- build: what it tells a person. The engine it attaches is looked for
-- where there is none (revSetOverrideRuntimePath, the IDE's own way to
-- build with another engine), so the builder stops on its own error,
-- with its dialogs on (edRefusedBuild). Its dialog says the builder's
-- sentence from its first word, "Ensure that you have not renamed the
-- main OXT-Beyond executable file:", and the file it looked for: up to
-- 0.2.8-dp.1 the dialog began at "that you have not renamed". And the
-- stack and its file are as they were, as after any build that stops
on ed_standalone_engine_missing
   local tWhy, tEngine
   put edBuildSkip() into sSkip
   if sSkip is not empty then return "skipped"
   if edDialogCopies() is not empty then throw "a build before this one left in memory:" && edDialogCopies() & "; no build is tried over it"
   edFront
   edBuildSettings sStack, "Everyday"
   edSaveForBuild sStack
   put sWork & "/no-such-engine/Standalone" into tEngine
   if there is a file tEngine then throw "there is a file" && tEngine & ": the build would not be refused"
   put edRefusedBuild(sStack, tEngine, "40-standalone-build-refused") into tWhy
   if tWhy is not empty then throw tWhy
   edRecord "INFO the build with no engine at" && tEngine && "went through:" && edJoin(sReport["steps"])
   edRecord "INFO the IDE said:" && edJoin(sReport["said"])
   edFront
   edShotStack sStack, "41-standalone-engine-missing"
end ed_standalone_engine_missing

-- File > Import As Control > Image File... with the system's own file
-- dialog (the systemFileSelector true, as a person has it) and a lot of
-- windows open, on macOS: the dialog must open, on the screen, in front
-- of the IDE's windows. A person on macOS 15.2 found that "with a lot of
-- windows/stacks open" the item's "Finder window does not always open"
-- (CamelCaps, openxtalk.org p=26676). The dialog holds the IDE until it
-- closes, so the IDE cannot look at it: a watcher of its own
-- (edDialogWatcher), started before the item is picked, lists the
-- system's windows until a new window of the IDE's is there, writes what
-- it found and which windows were in front of it, and presses Escape,
-- which cancels the dialog. Three times: with the stack in front, after
-- a palette was, and after a stack that was just made. Last of the
-- tasks, so that a dialog that held the IDE for good holds no task after
-- it
on ed_import_image_system_dialog
   local tMany, tName, tFront, tRound, tFile, tFound, tMiss, tCount, tN, i
   if the platform is not "MacOS" then
      edRecord "INFO import-image-system-dialog: the system's file dialog is looked at on macOS (CamelCaps, p=26676)"
      return "skipped"
   end if
   if sStack is empty or there is not a stack sStack then throw "the task's stack is not there"
   -- (a lot of windows: a dozen stacks over the screen, and the palettes
   -- a person has open)
   lock messages
   repeat with i = 1 to 12
      put "Everyday Many" && i into tName
      if there is a stack tName then delete stack tName
      create stack tName
      set the rect of stack tName to (40 + i * 30) & "," & (60 + i * 24) & "," & (440 + i * 30) & "," & (360 + i * 24)
      put tName & return after tMany
   end repeat
   unlock messages
   repeat for each line tName in tMany
      go stack tName
   end repeat
   revIDEOpenPalette "message box"
   revIDEOpenPalette "project browser"
   put the number of images of card 1 of stack sStack into tCount
   set the systemFileSelector to true
   repeat for each item tRound in "the stack,a palette,a new stack"
      put empty into tFront
      switch tRound
         case "a palette"
            if there is a stack "Message Box" then go stack "Message Box"
            break
         case "a new stack"
            put "Everyday Many New" into tFront
            if there is a stack tFront then delete stack tFront
            create stack tFront
            set the rect of stack tFront to "300,200,700,500"
            go stack tFront
            break
      end switch
      -- (the item is the stack in front's: Import As Control is enabled
      -- for a stack that can be edited)
      edFront
      -- (a file of each round's own: "the stack" and "a new stack" both
      -- ended in "stack", and the third round found the first's files,
      -- picked the item before its watcher had listed a window and read
      -- the first round's record)
      add 1 to tN
      put sWork & "/dialog-" & tN & ".txt" into tFile
      if there is a file tFile then delete file tFile
      if there is a file (tFile & ".base") then delete file (tFile & ".base")
      edDialogWatcher tFile
      if not edWaitFor("there is a file pAx", 15000, tFile & ".base") then
         put tRound & ": the watcher did not start" & return after tMiss
         next repeat
      end if
      edMenu "File", "Import As Control|image"
      -- (the dialog has closed: Escape, or the watcher's last try)
      if not edWaitFor("there is a file pAx", 15000, tFile) then
         put tRound & ": the watcher wrote nothing" & return after tMiss
         next repeat
      end if
      put textDecode(URL ("binfile:" & tFile), "UTF-8") into tFound
      edRecord "INFO import-image-system-dialog, after" && tRound & ":" && edJoin(tFound)
      if line 1 of tFound is not "opened" then
         put tRound & ":" && line 1 of tFound & return after tMiss
      else if line 2 of tFound is not "in front" then
         put tRound & ": the dialog opened behind" && line 2 of tFound & return after tMiss
      else if line 3 of tFound is not "closed" then
         put tRound & ": Escape did not close the dialog (" & line 3 of tFound & ")" & return after tMiss
      end if
      if tFront is not empty and there is a stack tFront then delete stack tFront
   end repeat
   set the systemFileSelector to false
   repeat for each line tName in tMany
      if there is a stack tName then delete stack tName
   end repeat
   edFront
   if the number of images of card 1 of stack sStack is not tCount then put "a cancelled dialog imported an image" & return after tMiss
   if tMiss is not empty then throw "the system's file dialog with a lot of windows open:" && edJoin(tMiss)
   edRecord "INFO File > Import As Control > Image File... opened the system's file dialog in front of a dozen stacks and the palettes, three times"
end ed_import_image_system_dialog

-- A watcher of the system's windows, for a dialog that holds the IDE
-- while it is open: osascript, in the background, lists the windows
-- (CGWindowListCopyWindowInfo, which needs no permission for what it is
-- asked here: owners, layers and bounds) and writes pFile & ".base" once
-- it has listed those there before. Then, for up to ten seconds, it looks
-- for a window of the IDE's that was not there before (or of the system's
-- service that shows an open panel for a program, should the system show
-- it that way: its owner's name has "Open" or "Panel" in it). pFile says, a
-- line each: "opened" or what it found instead; "in front" or the
-- windows in front of it that overlap it (each owner, layer and bounds;
-- below the Dock's layer, 20, and the menu bar's: a window of the IDE's
-- or of any program, not the system's own);
-- "closed" or what is still there after Escape, pressed up to four
-- times; the dialog; then every window on the screen, front to back, as
-- they were while the dialog was open
command edDialogWatcher pFile
   local tScript
   put "ObjC.import('CoreGraphics'); ObjC.import('Foundation'); " & \
         "var pid = " & the processID & "; var path = '" & pFile & "'; " & \
         "function all() { return ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0))) || []; } " & \
         "function shown() { return ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(17, 0))) || []; } " & \
         "function write(p, t) { $.NSString.alloc.initWithUTF8String(t).writeToFileAtomicallyEncodingError(p, true, 4, null); } " & \
         "function box(w) { var b = w.kCGWindowBounds || {}; return [b.X, b.Y, b.Width, b.Height].join(','); } " & \
         "function say(w) { return w.kCGWindowOwnerName + ' ' + w.kCGWindowOwnerPID + ' layer ' + w.kCGWindowLayer + ' at ' + box(w) + (w.kCGWindowIsOnscreen ? '' : ' (not on the screen)'); } " & \
         "function meets(a, b) { var p = a.kCGWindowBounds, q = b.kCGWindowBounds; " & \
         "return p.X < q.X + q.Width && q.X < p.X + p.Width && p.Y < q.Y + q.Height && q.Y < p.Y + p.Height; } " & \
         "function esc() { [true, false].forEach(function (d) { $.CGEventPost(0, $.CGEventCreateKeyboardEvent(null, 53, d)); delay(0.1); }); } " & \
         "function ours(w) { return (w.kCGWindowOwnerPID == pid || /Open|Panel/.test(w.kCGWindowOwnerName || '')) && !before[w.kCGWindowNumber] && w.kCGWindowLayer >= 0 && w.kCGWindowLayer < 20; } " & \
         "function area(w) { return w.kCGWindowBounds.Width * w.kCGWindowBounds.Height; } " & \
         "var before = {}; all().forEach(function (w) { before[w.kCGWindowNumber] = true; }); write(path + '.base', 'listed'); " & \
         "var t0 = Date.now(), seen = {}, order = []; " & \
         "function look() { all().forEach(function (w) { if (ours(w) && seen[w.kCGWindowNumber] === undefined) { seen[w.kCGWindowNumber] = Date.now() - t0; order.push(w); } }); " & \
         "var on = shown().filter(function (w) { return ours(w) && w.kCGWindowBounds.Width > 1 && w.kCGWindowBounds.Height > 1; }); " & \
         "on.sort(function (a, b) { return (b.kCGWindowLayer - a.kCGWindowLayer) || (area(b) - area(a)); }); return on.length ? on[0] : null; } " & \
         "var found = null; for (var i = 0; i < 40 && !order.length; i++) { delay(0.25); found = look(); } " & \
         "for (var j = 0; j < 32 && order.length && !found; j++) { delay(0.25); found = look(); } " & \
         "var lines = [], now = [], at = -1; if (found) { delay(0.5); found = look() || found; now = shown(); " & \
         "now.forEach(function (w, n) { if (w.kCGWindowNumber == found.kCGWindowNumber) at = n; }); } " & \
         "if (!order.length) { lines.push('no new window of the IDE in ten seconds'); lines.push(''); } " & \
         "else if (!found) { lines.push('opened, but not on the screen in eight seconds'); lines.push(''); } " & \
         "else if (at < 0) { lines.push('opened, but it left the screen: ' + say(found)); lines.push(''); } else { lines.push('opened'); " & \
         "var over = now.slice(0, at).filter(function (w) { return w.kCGWindowLayer >= 0 && w.kCGWindowLayer < 20 && w.kCGWindowBounds.Width > 1 && meets(w, found); }); " & \
         "lines.push(over.length ? over.map(say).join('; ') : 'in front'); } " & \
         "var aim = found || order[0], gone = false; for (var k = 0; k < 4 && !gone; k++) { esc(); delay(1.5); " & \
         "gone = !aim || !all().some(function (w) { return w.kCGWindowNumber == aim.kCGWindowNumber && (w.kCGWindowIsOnscreen || !found); }); } " & \
         "lines.push(gone ? 'closed' : 'still open after Escape four times'); " & \
         "lines.push('the dialog: ' + (found ? say(found) : 'none on the screen')); " & \
         "lines.push('new windows: ' + (order.length ? order.map(function (w) { return say(w) + ' at ' + seen[w.kCGWindowNumber] + ' ms'; }).join('; ') : 'none')); " & \
         "(now.length ? now : shown()).filter(function (w) { return w.kCGWindowLayer >= 0 && w.kCGWindowLayer < 24; }).forEach(function (w) { lines.push(say(w)); }); " & \
         "write(path, lines.join(String.fromCharCode(10)));" into tScript
   get shell("osascript -l JavaScript -e " & quote & tScript & quote & " >/dev/null 2>&1 &")
end edDialogWatcher

-- the stack closed and deleted from memory; what was changed set back
on ed_finish
   local tError
   edCloseInspectors
   edCloseScriptEditors
   if sStack is not empty and there is a stack sStack then
      try
         revIDESetEdited sStack, false
      catch tError
      end try
      delete stack sStack
   end if
   edRemoveBuiltStack kMcStack
   edRemoveBuiltStack kAppStack
   edGuideGone
   edStopBuildAt empty
   dispatch "revSetTestEnvironment" to stack "Home" with true
   dispatch "revSetOverrideRuntimePath" to stack "Home" with empty
   if sSaved["systemFileSelector"] is not empty then set the systemFileSelector to sSaved["systemFileSelector"]
   if sSaved["typingRate"] is not empty then set the typingRate to sSaved["typingRate"]
   edToolFilter empty
   edShotScreen "99-screen-end"
end ed_finish

----------------------------------------------------------------
-- Making a control from the Tools palette

-- The tile pType ("com.livecode.interface.classic." & pType) dragged
-- onto the stack: a new control of pWord (button, field, ...) where it
-- was dropped, selected, with the Pointer tool still chosen.
--
-- The wait for the control starts when the system's mouse has been
-- released, not when the drag was launched. On Windows the drag is a
-- PowerShell that compiles its Add-Type first, and the 6 s counted from
-- the launch were all of the time it had: on main 92b1a1d (the #483
-- merge, Windows, dark) make-label failed "made nothing on the stack"
-- after 6289 ms where every other drag took about 2.4 s, and the record
-- could not say whether the drag had even started. The helper now writes
-- the times of its steps (edSystemDrag), the step waits for the release
-- (20 s at most) and then 6 s for the control, and a miss says where the
-- tile was and whether it showed, the filter, the drag's times, where
-- the mouse and the windows were, and whether a control came late (3 s
-- more, still a failure)
command edMake pType, pWord, pShot
   local tTile, tCount, tTo, tNew, tVia, tFrom, tDrop, tDrag, tMiss
   if sStack is empty or there is not a stack sStack then throw "no stack to make a control on"
   edFront
   edToolFilter pType
   put edTile("com.livecode.interface.classic." & pType) into tTile
   if tTile is empty then throw "the Tools palette has no" && pType && "tile"
   put the number of controls of card 1 of stack sStack into tCount
   -- where on the card it goes: a column down the left, then the right
   put edSpot(tCount) into tTo
   if sInput is true then
      put "a drag of the system's mouse" into tVia
      put edScreenLoc(tTile, "revTools") into tFrom
      put (item 1 of tTo + the left of stack sStack) & "," & (item 2 of tTo + the top of stack sStack) into tDrop
      edSystemDrag tFrom, tDrop
      put edDragDone(20000) into tDrag
   else
      put "a double-click on its tile (the system's mouse does not reach the IDE)" into tVia
      send "mouseDoubleUp 1" to tTile
   end if
   if not edWaitFor("the number of controls of card 1 of stack sStack is pAx + 1", 6000, tCount) then
      put "the" && pType && "tile made nothing on the stack (" & tVia & ")" into tMiss
      if sInput is true then
         put "; the tile at" && the rect of tTile && "of revTools at" && the rect of stack "revTools" && \
               "(shown" && edTileShown("com.livecode.interface.classic." & pType) & ")" && \
               "dragged from" && tFrom && "to" && tDrop && "on the stack at" && the rect of stack sStack & \
               "; the filter" && quote & edToolFilterText() & quote & "; the drag" && tDrag & \
               "; the mouse at" && the screenMouseLoc && "and" && the mouse & "; the tool" && the tool & \
               "; the topStack" && the short name of the topStack & "; the selObj" && edJoin(the selObj) after tMiss
      end if
      if edWaitFor("the number of controls of card 1 of stack sStack > pAx", 3000, tCount) then
         put "; a control came" && the milliseconds - sKeep["dragLaunched"] && "ms after the launch:" && \
               the long id of control (tCount + 1) of card 1 of stack sStack after tMiss
      else
         put "; none came 3 s later either" after tMiss
      end if
      throw tMiss
   end if
   put the long id of control (tCount + 1) of card 1 of stack sStack into tNew
   if word 1 of tNew is not pWord then throw "the" && pType && "tile made a" && word 1 of tNew
   if sInput is true and not (tTo is within the rect of tNew) then
      -- (dropped at tTo, it has tTo inside it)
      throw "the" && pType && "dropped at" && tTo && "is at" && the rect of tNew
   end if
   if not (the loc of tNew is within the rect of card 1 of stack sStack) then
      throw "the new" && pType && "is off the card:" && the rect of tNew
   end if
   edRecord "INFO made" && the short name of tNew && "(" & pType & ") by" && tVia && "at" && the rect of tNew
   if sInput is true then edRecord "INFO the drag" && tDrag
   set the cEverydayType of tNew to pType
   edToolFilter empty
   if the tool is not "pointer tool" then throw "the Tools palette left the" && the tool && "chosen after making a" && pType
   edShotStack sStack, pShot
end edMake

-- Where the control number pIndex + 1 goes on the card
function edSpot pIndex
   if pIndex < 5 then return (80 & "," & (40 + pIndex * 60))
   return (260 & "," & (40 + (pIndex - 5) * 60))
end edSpot

-- the modern Tools palette's filter: the tiles that match pText (a
-- person types it to find a tile); the classic look shows every tile
command edToolFilter pText
   if there is not a stack "revTools" then exit edToolFilter
   if there is not a field "tmFilter" of stack "revTools" then exit edToolFilter
   if not the visible of field "tmFilter" of stack "revTools" then exit edToolFilter
   if pText is empty then
      if field "tmFilter" of stack "revTools" is empty then exit edToolFilter
      dispatch "tmSetFilter" to stack "revTools" with empty
      put empty into field "tmFilter" of stack "revTools"
      exit edToolFilter
   end if
   edClickAt "revTools", the loc of field "tmFilter" of stack "revTools"
   select text of field "tmFilter" of stack "revTools"
   edType "revTools", pText
   if not edWaitFor("edTileShown(" & quote & "com.livecode.interface.classic." & pText & quote & ")", 2000) then
      edRecord "INFO the Tools palette's filter" && quote & edToolFilterText() & quote && "does not show the" && pText && "tile"
   end if
end edToolFilter

-- what the modern Tools palette's filter holds (empty in the classic look)
function edToolFilterText
   if there is not a stack "revTools" then return empty
   if there is not a field "tmFilter" of stack "revTools" then return empty
   return field "tmFilter" of stack "revTools"
end edToolFilterText

function edTile pName
   if there is not a button pName of stack "revTools" then return empty
   return the long id of button pName of stack "revTools"
end edTile

-- The first tile of the Tools palette's Controls (the classic controls,
-- "com.livecode.interface.classic." and a type) in the look it has on:
-- of the tiles shown, the topmost, and of a row the leftmost. The Quick
-- Start Guide's first lesson says which that is (edGuideLesson)
function edFirstControlTile
   local tIndex, tTile, tName, tFirst, tTop, tLeft
   repeat with tIndex = 1 to the number of buttons of stack "revTools"
      put the long id of button tIndex of stack "revTools" into tTile
      put the short name of tTile into tName
      if not (tName begins with "com.livecode.interface.classic.") then next repeat
      if not the effective visible of tTile then next repeat
      if tFirst is empty or the top of tTile < tTop - 4 or (abs(the top of tTile - tTop) <= 4 and the left of tTile < tLeft) then
         put tName into tFirst
         put the top of tTile into tTop
         put the left of tTile into tLeft
      end if
   end repeat
   return tFirst
end edFirstControlTile

-- Whether the Tools palette has its look pLook ("modern" or "classic")
-- on: the modern look's header, or the classic look's "Modern look" button
function edToolsLookOn pLook
   if there is not a stack "revTools" then return false
   if pLook is "classic" then return there is a button "tmModernLook" of card 1 of stack "revTools"
   return there is a group "tmHeader" of card 1 of stack "revTools"
end edToolsLookOn

-- Whether the section pKey of the Tools palette's modern look ("classic"
-- is its Controls) is folded: the arrow of its caption points right. The
-- palette keeps what is folded in its own script, and reads the preference
-- (revTools_modernFolded) only while nothing is folded there, so the
-- preference does not say, and to empty it unfolds nothing
function edToolsFolded pKey
   if there is not a stack "revTools" then return false
   if there is not a button ("tmCapHit:" & pKey) of stack "revTools" then return false
   if there is not an image "tm.chevRight" of stack "revTools" then return false
   return the icon of button ("tmCapHit:" & pKey) of stack "revTools" is the id of image "tm.chevRight" of stack "revTools"
end edToolsFolded

-- The caption of the section pKey is pressed, which folds the section or
-- unfolds it: the palette's own handler, wherever the caption is scrolled
command edToolsCaption pKey
   local tWas
   if there is not a button ("tmCapHit:" & pKey) of stack "revTools" then
      throw "the Tools palette's modern look has no caption for its section" && pKey
   end if
   put edToolsFolded(pKey) into tWas
   send "mouseDown 1" to button ("tmCapHit:" & pKey) of stack "revTools"
   repeat while the lockScreen
      unlock screen
   end repeat
   if not edWaitFor("edToolsFolded(pAx) is not pBx", 3000, pKey, tWas) then
      throw "its caption did not fold or unfold the Tools palette's section" && pKey && "(folded:" && edToolsFolded(pKey) & ")"
   end if
end edToolsCaption

-- Whether the modern look shows its section of the view pView ("classic"
-- is its Controls), by the palette's own account. The palette makes its
-- tiles from the setting (revTools_modernShow) only when it builds the
-- look, so a section is turned on or off with the palette's own command,
-- the one its menu calls, which builds it again (edToolsSection)
function edToolsSectionShown pView
   if there is not a stack "revTools" then return false
   dispatch function "tmShownSections" to stack "revTools"
   return pView is among the items of the result
end edToolsSectionShown

command edToolsSection pView
   local tWas
   put edToolsSectionShown(pView) into tWas
   dispatch "tmToggleSection" to stack "revTools" with pView
   repeat while the lockScreen
      unlock screen
   end repeat
   if not edWaitFor("edToolsSectionShown(pAx) is not pBx", 3000, pView, tWas) then
      throw "the Tools palette did not turn its section" && pView && "on or off (shown:" && edToolsSectionShown(pView) & ")"
   end if
end edToolsSection

-- What the Quick Start Guide's first lesson says of the standard button's
-- tile is so in both of the Tools palette's looks: "the first one under
-- Controls" in the modern look and "the top gray button" in the classic
-- one. The modern look is read with its Controls shown and unfolded, as a
-- new install has them: a section left out is turned on as the palette's
-- menu does it, and a folded one unfolded by its caption, since the
-- palette reads neither setting again by itself (edToolsSectionShown,
-- edToolsFolded). Both are put back after by the same means, and the look
-- as it was
command edGuideTileIsFirst
   local tLook, tTry, tError, tNow, tShown, tUnfolded, tAgain
   put revIDEGetPreference("revTools_look") into tLook
   try
      repeat for each item tTry in "modern,classic"
         if (tTry is "classic") is not (revIDEGetPreference("revTools_look") is "classic") then revIDESetPreference "revTools_look", tTry
         if not edWaitFor("edToolsLookOn(pAx)", 6000, tTry) then throw "the Tools palette did not take its" && tTry && "look"
         if tTry is "modern" then
            if not edToolsSectionShown("classic") then
               edToolsSection "classic"
               put true into tShown
            end if
            if edToolsFolded("classic") then
               edToolsCaption "classic"
               put true into tUnfolded
            end if
         end if
         if not edWaitFor("edToolsLookOn(pAx) and edFirstControlTile() is pBx", 6000, tTry, "com.livecode.interface.classic.button") then
            throw "the notes call the standard button the first under Controls (the top one, in the classic look); in the Tools palette's" && tTry && \
                  "look (on:" && edToolsLookOn(tTry) & ") the first is" && quote & edFirstControlTile() & quote
         end if
         edRecord "INFO the Tools palette's first control tile in its" && tTry && "look:" && edFirstControlTile() && "at" && the topLeft of edTile(edFirstControlTile())
      end repeat
   catch tError
   end try
   if tUnfolded is true or tShown is true then
      -- (in the modern look, which has the caption and the sections)
      try
         if revIDEGetPreference("revTools_look") is "classic" then revIDESetPreference "revTools_look", "modern"
         if not edWaitFor("edToolsLookOn(pAx)", 6000, "modern") then throw "the Tools palette did not take its modern look, to put its Controls back as they were"
         if tUnfolded is true and not edToolsFolded("classic") then edToolsCaption "classic"
         if tShown is true and edToolsSectionShown("classic") then edToolsSection "classic"
      catch tAgain
         if tError is empty then put tAgain into tError
      end try
   end if
   if revIDEGetPreference("revTools_look") is not tLook then revIDESetPreference "revTools_look", tLook
   if tError is not empty then throw tError
   put "modern" into tNow
   if tLook is "classic" then put "classic" into tNow
   if not edWaitFor("edToolsLookOn(pAx)", 6000, tNow) then
      throw "the Tools palette did not take its" && tNow && "look again"
   end if
end edGuideTileIsFirst

-- The same with the Controls as a reader may have them when the check
-- starts, and the check must find the tile all the same and leave them
-- so. pHow "folded": the section folded, the palette in the look it had.
-- pHow "hidden": the section left out of the modern look, and the palette
-- in that look, so that no change of look builds it again. Then the
-- section and the look are put back
command edGuideTileIsFirstWhen pHow
   local tLook, tDid, tShown, tError, tAgain, tNow, tButton
   put "com.livecode.interface.classic.button" into tButton
   put revIDEGetPreference("revTools_look") into tLook
   try
      if tLook is "classic" then revIDESetPreference "revTools_look", "modern"
      if not edWaitFor("edToolsLookOn(pAx)", 6000, "modern") then throw "the Tools palette did not take its modern look, to have its Controls" && pHow
      if pHow is "hidden" then
         if edToolsSectionShown("classic") then
            edToolsSection "classic"
            put true into tDid
         end if
         if edTile(tButton) is not empty then
            throw "the Tools palette's Controls are left out, and it has the standard button's tile"
         end if
      else
         -- (a section left out has no caption: shown for this)
         if not edToolsSectionShown("classic") then
            edToolsSection "classic"
            put true into tShown
         end if
         if not edToolsFolded("classic") then
            edToolsCaption "classic"
            put true into tDid
         end if
         if "classic" is not among the items of revIDEGetPreference("revTools_modernFolded") then
            throw "the Tools palette's Controls are folded, and its setting does not say so:" && revIDEGetPreference("revTools_modernFolded")
         end if
         -- (the check starts in the look the reader has)
         if tLook is "classic" then
            revIDESetPreference "revTools_look", "classic"
            if not edWaitFor("edToolsLookOn(pAx)", 6000, "classic") then throw "the Tools palette did not take its classic look again"
         end if
      end if
      edGuideTileIsFirst
      if revIDEGetPreference("revTools_look") is "classic" then revIDESetPreference "revTools_look", "modern"
      if not edWaitFor("edToolsLookOn(pAx)", 6000, "modern") then throw "the Tools palette did not take its modern look after the check"
      if pHow is "hidden" then
         if edToolsSectionShown("classic") or edTile(tButton) is not empty then
            throw "the check of the tile left the Controls shown, which were left out"
         end if
      else
         if not edToolsFolded("classic") then throw "the check of the tile left the Controls unfolded, which were folded"
         if "classic" is not among the items of revIDEGetPreference("revTools_modernFolded") then
            throw "the check of the tile left the setting of what is folded changed:" && revIDEGetPreference("revTools_modernFolded")
         end if
      end if
      edRecord "INFO with its Controls" && pHow && "first, the check of the tile finds the tile and leaves them" && pHow
   catch tError
   end try
   -- as they were when this began (in the modern look, which has the
   -- caption and the sections)
   if tDid is true or tShown is true then
      try
         if revIDEGetPreference("revTools_look") is "classic" then revIDESetPreference "revTools_look", "modern"
         if not edWaitFor("edToolsLookOn(pAx)", 6000, "modern") then throw "the Tools palette did not take its modern look, to put its Controls back as they were"
         if pHow is "hidden" then
            if not edToolsSectionShown("classic") then
               edToolsSection "classic"
            end if
         else
            if tDid is true and edToolsFolded("classic") then edToolsCaption "classic"
            if tShown is true and edToolsSectionShown("classic") then edToolsSection "classic"
         end if
      catch tAgain
         if tError is empty then put tAgain into tError
      end try
   end if
   if revIDEGetPreference("revTools_look") is not tLook then revIDESetPreference "revTools_look", tLook
   if tError is not empty then throw tError
   put "modern" into tNow
   if tLook is "classic" then put "classic" into tNow
   if not edWaitFor("edToolsLookOn(pAx)", 6000, tNow) then
      throw "the Tools palette did not take its" && tNow && "look again, after the check with its Controls" && pHow
   end if
end edGuideTileIsFirstWhen

-- How much of the control pObj a person can see on its card: the number
-- of pixels of its rect that it changes by 80 or more (of 255) in
-- brightness, between a picture of the card without it and one with it.
-- The pictures are the card as the engine draws it, so a window over the
-- stack does not matter. A word of a label in the colour of what is under
-- it changes none; a word that can be read changes some dozens
-- (openxtalk.org p=26402: in the dark look a control dropped on the Quick
-- Start Guide's light Try It box was "almost invisible")
function edSeenPixels pObj
   local tCard, tRect, tWas, tWith, tWithout, tCount, tIndex, tA, tB
   put the long owner of pObj into tCard
   put the rect of pObj into tRect
   put the visible of pObj into tWas
   lock screen
   set the visible of pObj to true
   put edCardPixels(tCard, tRect) into tWith
   set the visible of pObj to false
   put edCardPixels(tCard, tRect) into tWithout
   set the visible of pObj to tWas
   unlock screen
   if the number of bytes of tWith is 0 or the number of bytes of tWith is not the number of bytes of tWithout then
      throw "the two pictures of" && tRect && "of the card do not match:" && the number of bytes of tWith && "and" && the number of bytes of tWithout && "bytes"
   end if
   put 0 into tCount
   repeat with tIndex = 1 to the number of bytes of tWith step 4
      -- (a pixel is four bytes: nothing, red, green, blue)
      put 299 * byteToNum(byte tIndex + 1 of tWith) + 587 * byteToNum(byte tIndex + 2 of tWith) + 114 * byteToNum(byte tIndex + 3 of tWith) into tA
      put 299 * byteToNum(byte tIndex + 1 of tWithout) + 587 * byteToNum(byte tIndex + 2 of tWithout) + 114 * byteToNum(byte tIndex + 3 of tWithout) into tB
      if abs(tA - tB) >= 80000 then add 1 to tCount
   end repeat
   return tCount
end edSeenPixels

-- The pixels of the rect pRect of the card pCard, as the engine draws the
-- card: its imageData, four bytes a pixel. The picture is made in a stack
-- of its own, which is then deleted, so that the card gets no image
function edCardPixels pCard, pRect
   local tDefault, tData, tError
   put the defaultStack into tDefault
   if there is a stack "edPixels" then delete stack "edPixels"
   create invisible stack "edPixels"
   try
      set the defaultStack to "edPixels"
      import snapshot from rect pRect of pCard
      put the imageData of image 1 of card 1 of stack "edPixels" into tData
   catch tError
   end try
   set the defaultStack to tDefault
   delete stack "edPixels"
   if tError is not empty then throw "no picture of" && pRect && "of the card:" && edJoin(tError)
   return tData
end edCardPixels

function edTileShown pName
   local tTile
   put edTile(pName) into tTile
   if tTile is empty then return false
   return the visible of tTile and the top of tTile >= 0 and the bottom of tTile <= the height of stack "revTools"
end edTileShown

-- a tool's tile (Run or Edit) clicked, and the tool it names waited
-- for. browse-runs-it once found the pointer tool 3 s after the Browse
-- tile's click (macOS Intel, dark, run 43189577663) with the button
-- still selected, which a browse tool chosen and lost would have
-- dropped; nothing said what the click had reached. The click is
-- watched (edWatchClicks), and one that chose nothing in 1.5 s is
-- recorded with what was seen and the palette's state; it is not made
-- again, so the caller's own wait still fails the step
command edToolTile pName
   local tTile, tTool
   put edTile(pName) into tTile
   if tTile is empty then
      -- (the classic look names them otherwise; the tool chosen as its
      -- tiles do)
      if pName ends with "Browse" then revIDEChooseBrowseTool
      else revIDEChoosePointerTool
      exit edToolTile
   end if
   put word 1 of the cToolName of tTile into tTool
   edWatchClicks true
   edClickAt "revTools", the loc of tTile
   if not edWaitFor("word 1 of the tool is pAx", 1500, tTool) then
      edRecord "INFO the" && tTool && "tile's click chose nothing in 1.5 s (" & the tool & "); seen:" && edWatched() & \
            "; the tile at" && the rect of tTile && "shown" && the visible of tTile & \
            "; Tools mode" && the mode of stack "revTools" && "at" && the rect of stack "revTools" && "shown" && the visible of stack "revTools" & \
            "; topStack" && the short name of the topStack & "; mouseStack" && the mouseStack & \
            "; waiting:" && edPendingNames()
   end if
   edWatchClicks false
end edToolTile

-- the mouse and tool messages watched by a front script while a tile is
-- clicked (true) and no longer (false), into what edWatched() lists
command edWatchClicks pOn
   local tDefault, tScript, tMessage
   put the defaultStack into tDefault
   set the defaultStack to "oxt_everyday"
   lock messages
   if pOn then
      if there is not a button "oxt_everyday_clicks" then create invisible button "oxt_everyday_clicks"
      repeat for each item tMessage in "mouseDown,mouseUp,mouseRelease,newTool"
         put "on" && tMessage & return & \
               "   dispatch " & quote & "edSeen" & quote & " to stack " & quote & "oxt_everyday" & quote & " with " & quote & tMessage & quote & \
               ", the long id of the target, the tool" & return & \
               "   pass" && tMessage & return & \
               "end" && tMessage & return after tScript
      end repeat
      set the script of button "oxt_everyday_clicks" to tScript
      put empty into sKeep["seen"]
      put the milliseconds into sKeep["watching"]
      insert the script of button "oxt_everyday_clicks" into front
   else if there is a button "oxt_everyday_clicks" then
      remove the script of button "oxt_everyday_clicks" from front
   end if
   unlock messages
   if there is a stack tDefault then set the defaultStack to tDefault
end edWatchClicks

-- the names of the messages waiting
function edPendingNames
   local tOut, tLine
   repeat for each line tLine in the pendingMessages
      put item 3 of tLine & " " after tOut
   end repeat
   if tOut is empty then return "nothing"
   return word 1 to -1 of tOut
end edPendingNames

-- How many of the messages waiting have their time behind them: what the
-- IDE has to deliver before it is idle again (the pendingMessages gives
-- each its time, as the long seconds)
function edDue
   local tLine, tCount, tNow
   put the long seconds into tNow
   put 0 into tCount
   repeat for each line tLine in the pendingMessages
      if item 2 of tLine is a number and item 2 of tLine <= tNow then add 1 to tCount
   end repeat
   return tCount
end edDue

-- Waits until the IDE has delivered the messages it has due, as a person
-- does who sees it busy: at most pMilliseconds, and no longer than their
-- number goes on falling (one that sends itself again is always due).
-- Returns how many were due and how long they took, for a record.
--
-- A drag of the system's mouse needs it. The helper presses, moves and
-- lets go in about a second, and the Tools palette starts its drag only
-- if the button is still down when its mouseDown arrives (its "check for
-- some movement before drag"). On Windows the press waits its turn behind
-- the messages due before it (MCScreenDC::wait, w32dce.cpp: a waiting
-- message whose time is earlier than the next event's goes first). The
-- lesson's three checks of the tile switch the palette's look over and
-- over with no event handled between; each time the palette is made its
-- tiles are named, each nameChanged tells the IDE that its stacks changed
-- (revSetActiveStacks, revfrontscriptlibrary), and the Message Box
-- answers each with a positionOpenStacksButton sent to itself (its
-- layoutCard). So the lesson's drag on Windows made no button (#532, run
-- 43906149713), and the same drag measured there (#537, run
-- 43934646350): with 2 such messages waiting the tile's mouseDown came
-- 46 ms after the press; with 36, after one check, 430 ms; with 252,
-- after the three, 7.8 s, the mouse long up, in the light and the dark
-- run alike. A wait of 3 s after the checks was not enough (163 still
-- waiting) and a loop of 25 s without the checks did no harm. Linux
-- delivers the same 238 in a tenth of a second. A person switches the
-- look once, and is not pressing a tile in the half second after
function edSettled pMilliseconds
   local tStart, tFirst, tLeast, tLeastAt, tNow
   put the milliseconds into tStart
   put edDue() into tFirst
   put tFirst into tLeast
   put tStart into tLeastAt
   repeat while tLeast > 0 and the milliseconds - tStart < pMilliseconds and the milliseconds - tLeastAt < 1500
      wait 50 milliseconds with messages
      put edDue() into tNow
      if tNow < tLeast then
         put tNow into tLeast
         put the milliseconds into tLeastAt
      end if
   end repeat
   return tFirst && "messages due," && tLeast && "left after" && (the milliseconds - tStart) && "ms"
end edSettled

-- The system's mouse pressed at pFrom, moved in steps to pTo and released
-- there (screen points), while the engine handles each event as it comes:
-- the command runs on its own. It writes what it did to a file of its
-- own (sKeep["dragFile"]), a line a step: "started", "down" and "up" on
-- Windows, each with the milliseconds since the launch, and "up" alone
-- elsewhere; edDragDone waits for its "up". The IDE is first given the
-- time to deliver what it has due (edSettled), and what that was is kept
-- for edDragDone's record
command edSystemDrag pFrom, pTo
   local tSteps, tCommand, tScript, i, tX, tY, tMoves, tFile
   put edSettled(20000) into sKeep["dragSettled"]
   -- (in this run's folder: a file two runs shared would say "up" to
   -- one for the other's drag)
   put sWork & "/drag.txt" into tFile
   if there is a file tFile then delete file tFile
   put tFile into sKeep["dragFile"]
   put the milliseconds into sKeep["dragLaunched"]
   put empty into tMoves
   repeat with i = 1 to 6
      put round(item 1 of pFrom + (item 1 of pTo - item 1 of pFrom) * i / 6) into tX
      put round(item 2 of pFrom + (item 2 of pTo - item 2 of pFrom) * i / 6) into tY
      put tX & "," & tY & ";" after tMoves
   end repeat
   delete the last char of tMoves
   switch the platform
      case "MacOS"
         put "ObjC.import('CoreGraphics'); function ev(t, x, y) { var e = $.CGEventCreateMouseEvent(null, t, {x: x, y: y}, 0); " & \
               "$.CGEventSetIntegerValueField(e, 1, 1); $.CGEventPost(0, e); } " & \
               "delay(0.3); ev(5," & pFrom & "); delay(0.15); ev(1," & pFrom & "); delay(0.2); " into tScript
         set the itemDelimiter to ";"
         repeat for each item i in tMoves
            put "ev(6," & i & "); delay(0.15); " after tScript
         end repeat
         set the itemDelimiter to comma
         put "delay(0.2); ev(2," & pTo & ");" after tScript
         put "(osascript -l JavaScript -e " & quote & tScript & quote & " >/dev/null 2>&1; echo up > '" & tFile & "') >/dev/null 2>&1 &" into tCommand
         get shell(tCommand)
         break
      case "Win32"
         -- ($l: the milliseconds since the launch, the engine's clock
         -- and .NET's both counting from 1970)
         put "$f = '" & tFile & "'; function l($w) { Add-Content -Path $f -Value ($w + ' ' + ([DateTimeOffset]::Now.ToUnixTimeMilliseconds() - " & sKeep["dragLaunched"] & ")) }" & return & \
               "l 'started'" & return & \
               "Add-Type -Namespace OxtEd -Name Mouse -MemberDefinition '" & \
               "[DllImport(" & quote & "user32.dll" & quote & ")] public static extern bool SetCursorPos(int x, int y); " & \
               "[DllImport(" & quote & "user32.dll" & quote & ")] public static extern void mouse_event(int f, int x, int y, int d, int e);'" & return & \
               "Start-Sleep -Milliseconds 300" & return & \
               "[OxtEd.Mouse]::SetCursorPos(" & pFrom & ") | Out-Null" & return & \
               "Start-Sleep -Milliseconds 150" & return & \
               "[OxtEd.Mouse]::mouse_event(2, 0, 0, 0, 0)" & return & \
               "l 'down'" & return into tScript
         set the itemDelimiter to ";"
         repeat for each item i in tMoves
            put "Start-Sleep -Milliseconds 150" & return & "[OxtEd.Mouse]::SetCursorPos(" & i & ") | Out-Null" & return after tScript
         end repeat
         set the itemDelimiter to comma
         put "Start-Sleep -Milliseconds 200" & return & "[OxtEd.Mouse]::mouse_event(4, 0, 0, 0, 0)" & return & "l 'up'" after tScript
         put base64Encode(textEncode(tScript, "UTF-16LE")) into tScript
         replace return with empty in tScript
         put "powershell -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand" && tScript into tCommand
         -- (on its own: the engine goes on while it runs)
         launch tCommand
         break
      default
         put "(sleep 0.3; xdotool mousemove" && item 1 of pFrom && item 2 of pFrom && "sleep 0.15 mousedown 1" into tCommand
         set the itemDelimiter to ";"
         repeat for each item i in tMoves
            set the itemDelimiter to comma
            put " sleep 0.15 mousemove" && item 1 of i && item 2 of i after tCommand
            set the itemDelimiter to ";"
         end repeat
         set the itemDelimiter to comma
         put " sleep 0.2 mouseup 1; echo up > '" & tFile & "') >/dev/null 2>&1 &" after tCommand
         get shell(tCommand)
         break
   end switch
   -- (the caller waits for what the drag makes)
end edSystemDrag

-- Waits, at most pMilliseconds, for the last drag's helper to release the
-- mouse; returns what it wrote, how long that took and what the engine
-- held the mouse over meanwhile (edDragOver), for a record
function edDragDone pMilliseconds
   local tFile, tText, tAt, tTaken
   put sKeep["dragFile"] into tFile
   if tFile is empty then return "(no drag)"
   put empty into sKeep["dragOver"]
   put empty into sKeep["dragOverNow"]
   if edWaitFor("edDragOver() and there is a file pAx and URL (" & quote & "file:" & quote & " & pAx) contains " & quote & "up" & quote, pMilliseconds, tFile) then
      put URL ("file:" & tFile) into tText
      -- The release is the system's; the engine has it only when it has
      -- handled the event. On macOS the Tools palette's drag ends when
      -- the system says the button is up ("the mouse" there is NSEvent's
      -- pressedMouseButtons), which can be before the engine has taken
      -- the mouse-up from its queue, and a wait that has run its time
      -- takes one more event at most. The engine gives a mouse-up to the
      -- window pressed only while that window's stack is the one it holds
      -- the mouse over (MCPlatformHandleMouseUp and
      -- MCPlatformHandleMouseRelease, desktop.cpp), and a task's own
      -- click (click at) makes that the stack clicked while it waits: a
      -- mouse-up taken from the queue then is dropped. The tile dragged
      -- goes on holding the press, and the palette's next press, wherever
      -- it is, goes to the card and its release to that tile. So
      -- quick-start-dropped-shows on both of macOS's test jobs, Intel and
      -- Apple Silicon (#532, run 43906150245), whose lesson before it
      -- drags and then clicks the button made with no event handled
      -- between: "the browse tile's click chose nothing ... seen: 0
      -- mouseDown card id 1002 (Tools); 205 mouseRelease button id 105962
      -- (Tools)", the same tile's id in both; and browse-runs-it's lost
      -- click (edToolTile) came after drags too. This was read in the
      -- engine's code and fits that record to the message; it was not
      -- seen happening here (the path is macOS's alone).
      -- A person makes no click of the engine's: for them the mouse-up is
      -- the next event taken. Here the events are handled for a moment
      -- before the task goes on, as after edClickAt's click, and the
      -- record ends with what the engine holds the mouse over then.
      --
      -- A moment of a fixed length is not enough on macOS. A wait there
      -- takes one event at most each time round its loop, after the
      -- messages the IDE has due (MCScreenDC::wait, desktop-dc.cpp), and
      -- the IDE has just made a control and selected it. In the 24 drags
      -- of main's two macOS test jobs at c77e5264 (run 44094625493) the
      -- engine let go of the tile in the 200 ms after the helper's "up",
      -- in every one, and in none before; in the lesson's drag of #552's
      -- Intel job (run 44126720354, dark, its IDE slower than in those:
      -- 235 ms for the two messages due before the drag, where they
      -- took 197 and 195) it still held the tile when they were over, "the
      -- mouse over: 249 up / 785 up revTools ...Button" and no third
      -- entry, and the next task's click on the Run tile went to the card
      -- and its release to that tile, as above. (Whether the mouse-up
      -- would have been taken a moment later that record cannot say: the
      -- lesson's own click came next.) So on macOS the task first waits
      -- until the engine has let go (edDragHeld), 5 s at most, and the
      -- record says how long that took; a press still held then fails
      -- the step here, where it happened, and not a later task's click
      put the milliseconds into tAt
      if the platform is "MacOS" then
         if edWaitFor("edDragOver() and not edDragHeld()", 5000) then
            put "; the release taken" && the milliseconds - tAt && "ms after the helper's up" into tTaken
         else
            throw "the engine still holds the drag's press" && the milliseconds - tAt && "ms after the system's mouse was released (" & \
                  edJoin(word 1 to -1 of tText) & "): it has not taken the mouse-up; the mouse over:" && edDragWasOver() & \
                  "; the system's mouse at" && the screenMouseLoc & "; waiting:" && edPendingNames()
         end if
      end if
      edPause 200
      get edDragOver()
      return "released" && the milliseconds - sKeep["dragLaunched"] && "ms after the launch (" & edJoin(word 1 to -1 of tText) & "); the mouse over:" && edDragWasOver() & \
            "; before it" && sKeep["dragSettled"] & tTaken
   end if
   if there is a file tFile then put URL ("file:" & tFile) into tText
   return "not released" && the milliseconds - sKeep["dragLaunched"] && "ms after the launch (" & edJoin(word 1 to -1 of tText) & "); the mouse over:" && edDragWasOver() & \
         "; before it" && sKeep["dragSettled"]
end edDragDone

-- Whether the engine still holds a press that the system's mouse has let
-- go of: it holds the mouse over a control of a window that the system's
-- mouse is no longer over. While a button is down the window pressed keeps
-- the mouse (MCMacPlatformHandleMouseMove, mac-core.mm: "If the mouse is
-- grabbed, the mouse window does not change") and its card the control
-- pressed (MCCard::mfocus, card.cpp); once the stack has had the mouse-up
-- it asks its card again what is under the mouse (MCStack::mup,
-- stack.cpp), which away from the window is nothing. The screenMouseLoc
-- is the system's (NSEvent's mouseLocation), whatever the engine has
-- taken from its queue
function edDragHeld
   local tStack, tControl, tError
   put the mouseStack into tStack
   if tStack is empty or there is not a stack tStack then return false
   try
      put the long id of the mouseControl into tControl
   catch tError
      put empty into tControl
   end try
   if tControl is empty then return false
   return the screenMouseLoc is not within the rect of stack tStack
end edDragHeld

-- What the engine holds the mouse over while a drag's helper works: its
-- button, the stack and the control, each time one of them has changed
-- when edDragDone's wait asks (ten times a second, and not while the
-- palette's own drag loop runs), with the milliseconds since the launch.
-- A drag that works reads "up revTools" and the tile's name before the
-- press, and the stack dropped on after the release; a press that never
-- reached the tile says here where the engine held the mouse instead. It
-- only records: it is true whatever it saw, so the wait ends on the
-- helper's "up" alone
function edDragOver
   local tNow, tControl, tError
   try
      put the short name of the mouseControl into tControl
   catch tError
      put empty into tControl
   end try
   put the mouse && the mouseStack && tControl into tNow
   if tNow is not sKeep["dragOverNow"] then
      put tNow into sKeep["dragOverNow"]
      put (the milliseconds - sKeep["dragLaunched"]) && word 1 to -1 of tNow & " / " after sKeep["dragOver"]
   end if
   return true
end edDragOver

function edDragWasOver
   if sKeep["dragOver"] is empty then return "nothing recorded"
   return char 1 to -4 of sKeep["dragOver"]
end edDragWasOver

-- Whether a click of the system's mouse reaches the IDE here: a button
-- of a stack of this script's must get its mouseUp (as the tour's
-- tourClickWorks); the click is a drag of no length
function edInputWorks
   local tStack, tDefault, tLoc, tWorks
   put "OXT Everyday Click Check" into tStack
   if there is a stack tStack then delete stack tStack
   put the defaultStack into tDefault
   lock messages
   create stack tStack
   set the rect of stack tStack to (item 3 of the screenRect - 380) & ",160," & (item 3 of the screenRect - 80) & ",320"
   set the defaultStack to tStack
   create button "Click"
   set the rect of it to "60,50,240,100"
   set the script of it to "on mouseUp" & return & "   set the cClicked of me to true" & return & "end mouseUp"
   unlock messages
   go stack tStack
   choose browse tool
   edPause 500
   put edScreenLoc(the long id of button "Click" of card 1 of stack tStack, tStack) into tLoc
   edSystemDrag tLoc, tLoc
   get edWaitFor("the cClicked of button " & quote & "Click" & quote & " of card 1 of stack pAx is true", 4000, tStack)
   put the cClicked of button "Click" of card 1 of stack tStack is true into tWorks
   choose pointer tool
   delete stack tStack
   if there is a stack tDefault then set the defaultStack to tDefault
   return tWorks
end edInputWorks

----------------------------------------------------------------
-- The Inspector

-- Selects pObject and Object > Object Inspector; returns the inspector
function edInspect pObject
   edCloseInspectors
   edSelect pObject
   edMenu "Object", "Object Inspector"
   return edInspector(5000)
end edInspect

function edInspector pMilliseconds
   local tPI
   if not edWaitFor("edStackNamed(" & quote & "revPropertyInspector" & quote & ") is not empty", pMilliseconds) then
      throw "no Inspector opened"
   end if
   put edStackNamed("revPropertyInspector") into tPI
   edOnScreen tPI
   return tPI
end edInspector

command edCloseInspectors
   local tStack
   repeat for each line tStack in the openStacks
      if tStack begins with "revPropertyInspector" then close stack tStack
   end repeat
   revIDEDeselectAll
end edCloseInspectors

-- the section pSection of the inspector pPI, as a click on its icon in
-- the header shows it; returns the section shown
function edSection pPI, pSection
   local tShown
   dispatch "inspectorSectionChanged" to stack pPI with pSection
   get edWaitFor("edSectionShown(pAx) is pBx", 2000, pPI, pSection)
   return edSectionShown(pPI)
end edSection

function edSectionShown pPI
   dispatch function "inspectorSectionGetName" to stack pPI
   return the result
end edSectionShown

-- the editor group of the property pProperty in the inspector pPI
function edEditor pPI, pProperty
   local tCard, tControl, i
   put the long id of this card of stack pPI into tCard
   repeat with i = 1 to the number of controls of tCard
      put the long id of control i of tCard into tControl
      if word 1 of tControl is not "group" then next repeat
      if the editorProperty["property_name"] of tControl is pProperty then return tControl
   end repeat
   return empty
end edEditor

-- the editor's text field clicked, its text selected and pText typed,
-- then Tab to the next one, which ends the editing (Return would end it
-- in a one-line field and start a line in the Label's)
command edTypeInEditor pPI, pProperty, pText
   local tEditor, tField, i
   put edEditor(pPI, pProperty) into tEditor
   if tEditor is empty then throw "the Inspector has no" && pProperty
   repeat with i = 1 to the number of fields of tEditor
      if the visible of field i of tEditor and not the lockText of field i of tEditor then
         put the long id of field i of tEditor into tField
         exit repeat
      end if
   end repeat
   if tField is empty then throw "the Inspector's" && pProperty && "has no field to type in"
   -- (it waits, as a person would, until the editor shows the object's value)
   edPause 300
   edClickAt pPI, the loc of tField
   select text of tField
   edType pPI, pText & tab
end edTypeInEditor

-- the Geometry Manager's right edge: Position mode, and a click on the
-- right side's line (the squiggle between the object and the edge)
command edGeometryRight pPI, pEditor
   local tTarget
   if there is a button "positioning" of pEditor then
      edClickAt pPI, the loc of button "positioning" of pEditor
      edPause 300
   end if
   if there is a graphic "Right" of group "content" of group "Diagram" of pEditor then
      put the long id of graphic "Right" of group "content" of group "Diagram" of pEditor into tTarget
   else if there is a graphic "Right Object" of pEditor then
      put the long id of graphic "Right Object" of pEditor into tTarget
   end if
   if tTarget is empty then throw "the Geometry Manager has no right side to click"
   edRecord "INFO the Geometry Manager: clicking" && the short name of tTarget && "at" && the loc of tTarget
   edClickAt pPI, the loc of tTarget
end edGeometryRight

function edGeometry pObject
   local tKeys
   get the customProperties["cREVGeometry"] of pObject
   repeat for each key tKey in it
      put tKey & "=" & it[tKey] & return after tKeys
   end repeat
   return tKeys
end edGeometry

----------------------------------------------------------------
-- The Script Editor

function edOpenScript pObject
   local tSE
   edSelect pObject
   edMenu "Object", "Object Script"
   if not edWaitFor("edStackNamed(" & quote & "revNewScriptEditor" & quote & ") is not empty", 5000) then throw "Object > Object Script opened no Script Editor"
   put edStackNamed("revNewScriptEditor") into tSE
   edOnScreen tSE
   return tSE
end edOpenScript

function edSeField pSE
   return the long id of field "Script" of group "Editor" of card "Main" of stack pSE
end edSeField

-- Apply: the toolbar's Compile button clicked, once it is enabled (the
-- editor enables it as it sees the typing)
command edApply pSE
   if not edWaitFor("the enabled of button " & quote & "Compile" & quote & " of group " & quote & "Toolbar" & quote & " of card " & quote & "Main" & quote & " of stack pAx", 3000, pSE) then
      throw "Apply is not enabled after the script was changed"
   end if
   edClickAt pSE, the loc of button "Compile" of group "Toolbar" of card "Main" of stack pSE
   get edWaitFor("not the enabled of button " & quote & "Compile" & quote & " of group " & quote & "Toolbar" & quote & " of card " & quote & "Main" & quote & " of stack pAx", 3000, pSE)
end edApply

-- the rows of the Errors pane, one a line (empty when it says there are
-- none)
function edSeErrors pSE
   local tList, tErrors, i
   put the long id of group "List" of group "Errors" of group "Panes" of card "Main" of stack pSE into tList
   repeat with i = 1 to the number of fields of tList
      if the text of field i of tList is empty then next repeat
      -- (the pane's row when there is none)
      if the text of field i of tList is "No errors occurred" then next repeat
      put the text of field i of tList & return after tErrors
   end repeat
   return line 1 to -1 of tErrors
end edSeErrors

-- the Variables pane's tree: its keys and values, as text
function edSeVariables pSE
   local tTree, tData
   put the long id of widget "tree" of group "Variables" of group "Panes" of card "Main" of stack pSE into tTree
   put the arrayData of tTree into tData
   return edFlatten(tData)
end edSeVariables

function edFlatten pArray
   local tText
   if pArray is not an array then return pArray
   repeat for each key tKey in pArray
      put tKey & "=" & edFlatten(pArray[tKey]) & " " after tText
   end repeat
   return tText
end edFlatten

-- What a task that failed left open of the Script Editor (its windows and
-- its Find dialog) is closed, so that one failure does not become the
-- next task's: on the Intel Mac (main 59072d18) se-find-replace failed
-- with its Script Editor open, debug-breakpoint then set the button's
-- script under it and failed too, and by dictionary-search the editor's
-- modal revSEModifiedExternallyDialog was up. Logged, never thrown
command edTidyAfterFailure pTask
   local tStack, tLeft, tError
   repeat for each line tStack in the openStacks
      if tStack begins with "revNewScriptEditor" or tStack is "revSEFind" or \
            tStack is "revSEModifiedExternallyDialog" then
         put tStack & " " after tLeft
      end if
   end repeat
   -- (a miss in a combo box leaves no watcher in front)
   edWatchKeys false
   edWatchClicks false
   if tLeft is empty then exit edTidyAfterFailure
   edRecord "INFO" && pTask && "failed with these open, closed:" && tLeft
   try
      if there is a stack "revSEModifiedExternallyDialog" and the mode of stack "revSEModifiedExternallyDialog" is not 0 then
         close stack "revSEModifiedExternallyDialog"
      end if
      if there is a stack "revSEFind" and the mode of stack "revSEFind" is not 0 then close stack "revSEFind"
      edCloseScriptEditors
   catch tError
      edRecord "INFO closing what" && pTask && "left open:" && edJoin(tError)
   end try
end edTidyAfterFailure

command edCloseScriptEditors
   local tStack
   repeat for each line tStack in the openStacks
      if tStack begins with "revNewScriptEditor" then close stack tStack
   end repeat
end edCloseScriptEditors

----------------------------------------------------------------
-- The IDE's file dialog and the answer dialog

-- the next file dialog gets pName typed into it and its button pButton
-- (Save or Open) clicked; what it showed goes to sReport["dialog"]
command edFileDialog pName, pButton
   put empty into sReport["dialog"]
   send "edFileDialogAnswer" && quote & pName & quote & "," && quote & pButton & quote && ", 0" to me in 200 milliseconds
end edFileDialog

on edFileDialogAnswer pName, pButton, pTries
   local tFS
   put "File Selector" into tFS
   if not (there is a stack tFS and the mode of stack tFS is not 0 and the visible of stack tFS) then
      if pTries < 40 then
         send "edFileDialogAnswer" && quote & pName & quote & "," && quote & pButton & quote & "," && pTries + 1 to me in 250 milliseconds
      else
         put "never opened" into sReport["dialog"]
      end if
      exit edFileDialogAnswer
   end if
   put the title of stack tFS && "in" && field "Directory" of stack tFS && "button" && the short name of button id 1012 of stack tFS into sReport["dialog"]
   try
      edShotStack tFS, "zz-file-dialog-" & toLower(pButton)
   catch tError
   end try
   edClickAt tFS, the loc of field "Selection" of stack tFS
   select text of field "Selection" of stack tFS
   edType tFS, pName
   if the short name of button id 1012 of stack tFS is not pButton then
      put " (its button is" && the short name of button id 1012 of stack tFS & ", not" && pButton & ")" after sReport["dialog"]
   end if
   edClickAt tFS, the loc of button id 1012 of stack tFS
end edFileDialogAnswer

-- the IDE's dialog in the look of Learn (revKitDialog), as the warning
-- before a stack opens shows it, answered with its button labelled
-- pLabel (clicked): its buttons are groups button1, button2, ... each
-- with its label in a field
on edKitDialogAnswer pLabel, pTries
   local tKD, tButton, i, j
   put "revKitDialog" into tKD
   if not (there is a stack tKD and the mode of stack tKD is not 0 and the visible of stack tKD) then
      if pTries < 40 then
         send "edKitDialogAnswer" && quote & pLabel & quote & "," && pTries + 1 to me in 250 milliseconds
      else
         put "never opened" into sReport["kit"]
      end if
      exit edKitDialogAnswer
   end if
   repeat with i = 1 to 9
      if there is not a group ("button" & i) of card 1 of stack tKD then exit repeat
      repeat with j = 1 to the number of fields of group ("button" & i) of card 1 of stack tKD
         if the text of field j of group ("button" & i) of card 1 of stack tKD is pLabel then
            put the long id of group ("button" & i) of card 1 of stack tKD into tButton
         end if
      end repeat
   end repeat
   try
      edShotStack tKD, "zz-kit-dialog"
   catch tError
   end try
   if tButton is empty then
      put "no button" && pLabel into sReport["kit"]
      close stack tKD
      exit edKitDialogAnswer
   end if
   put "answered" && pLabel into sReport["kit"]
   if sInput is true then
      edSystemDrag edScreenLoc(tButton, tKD), edScreenLoc(tButton, tKD)
   else
      edClickAt tKD, the loc of tButton
   end if
end edKitDialogAnswer

-- cancels this script's pending messages named in the list pNames
command edCancelPending pNames
   local tLine
   repeat for each line tLine in the pendingMessages
      if item 3 of tLine is among the items of pNames and item 4 of tLine is the long id of me then
         cancel item 1 of tLine
      end if
   end repeat
end edCancelPending

-- the answer dialog open now answered with its button pButton (clicked)
-- pButton: the button to click, or several (a comma between them) to
-- click in the questions asked one after the other; a question without
-- the button wanted is waited out while an earlier one in the list is
-- still on its way away
on edAnswerWith pButton, pTries, pAfter
   local tAD, tButton, i, tWanted, tIndex
   put "Answer Dialog" into tAD
   put item 1 of pButton into tWanted
   if pTries is empty then put 0 into pTries
   if not (there is a stack tAD and the mode of stack tAD is not 0 and the visible of stack tAD) then
      if pTries < 30 then send "edAnswerWith" && quote & pButton & quote & "," && pTries + 1 & "," && pAfter to me in 200 milliseconds
      exit edAnswerWith
   end if
   put the text of field 1 of card 1 of stack tAD into sReport["answer"]
   -- (the first of the buttons wanted that this question has: a question
   -- of the list may not be asked, as Close asks to save only an edited
   -- stack)
   repeat with tIndex = 1 to the number of items of pButton
      repeat with i = 1 to the number of buttons of card 1 of stack tAD
         if the visible of button i of card 1 of stack tAD and the short name of button i of card 1 of stack tAD is item tIndex of pButton then
            put the long id of button i of card 1 of stack tAD into tButton
         end if
      end repeat
      if tButton is not empty then
         put item tIndex of pButton into tWanted
         delete item 1 to tIndex of pButton
         exit repeat
      end if
   end repeat
   if tButton is empty and pAfter is true and pTries < 30 then
      -- (the question answered before, not yet gone)
      send "edAnswerWith" && quote & pButton & quote & "," && pTries + 1 & ", true" to me in 200 milliseconds
      exit edAnswerWith
   end if
   try
      edShotStack tAD, "zz-answer-" & toLower(replaceText(tWanted, "[^A-Za-z]", ""))
   catch tError
   end try
   if tButton is empty then
      put " (no button" && tWanted & ")" after sReport["answer"]
      close stack tAD
      exit edAnswerWith
   end if
   if pButton is not empty then
      send "edAnswerWith" && quote & pButton & quote & ", 0, true" to me in 400 milliseconds
   end if
   -- the system's click where it reaches the IDE: the engine's own click
   -- closed the question that File > Close and Remove From Memory asks
   -- (as sheet) without its answer reaching the IDE, which a person's
   -- click does
   if sInput is true then
      edSystemDrag edScreenLoc(tButton, tAD), edScreenLoc(tButton, tAD)
   else
      edClickAt tAD, the loc of tButton
   end if
end edAnswerWith

----------------------------------------------------------------
-- A standalone built from the File menu: stopped, and to its end

-- The standalone target of this computer, as the Standalone Settings
-- name it (kDesktopTargets in revsblibrary): the one whose standalone
-- runs here. A Mac has two: "MacOS Intel 64-bit" (MacOSX x86-64) and
-- "MacOS ARM 64 native" (MacOSX x64-ARM64), which the builder makes with
-- the arm64 code alone, so that it does not start on an Intel Mac ("Bad
-- CPU type in executable")
function edBuildTarget
   if the platform is "MacOS" then
      if the processor is "x86_64" then return "MacOSX x86-64"
      return "MacOSX x64-ARM64"
   end if
   if the platform is "Win32" then
      if the processor is "x86_64" then return "Windows x86-64"
      return "Windows"
   end if
   if the platform is "Linux" then
      if the processor is "x86_64" then return "Linux x64"
      if the processor is "arm64" then return "Linux arm64"
      return "Linux"
   end if
   return empty
end edBuildTarget

-- Why no standalone can be built for this computer here, or empty: the
-- builder makes the ARM 64 Mac one on macOS 14 and later only, and says
-- so in a dialog before it starts
function edBuildSkip
   if edBuildTarget() is empty then return "no standalone target for" && the platform
   if edBuildTarget() is "MacOSX x64-ARM64" then
      set the itemDelimiter to "."
      if item 1 of the systemVersion < 14 then return "the builder makes an ARM 64 Mac standalone on macOS 14 and later only (this is" && the systemVersion & ")"
   end if
   return empty
end edBuildSkip

-- the engine the builder attaches for this computer's target, and
-- whether it is there: for the record of a build that did not start
function edBuildEngine
   local tPath, tError
   try
      put revSBEnginePath(edBuildTarget()) into tPath
   catch tError
      return "revSBEnginePath:" && edJoin(tError)
   end try
   if there is a file tPath then return tPath
   return tPath && "(no such file)"
end edBuildEngine

-- the folder of the work folder that the standalone pName is built into
function edBuildFolder pName
   return sWork & "/standalone-" & toLower(pName)
end edBuildFolder

-- pStack set as the Standalone Settings set it: to build for this
-- computer alone, under the name pName, into a folder of the work folder
-- without asking where (its default build folder), with the Answer and
-- Ask dialogs included whatever its scripts use ("Select inclusions")
command edBuildSettings pStack, pName
   local tTarget, tFolder
   put edBuildFolder(pName) into tFolder
   if there is not a folder tFolder then create folder tFolder
   if there is not a folder tFolder then throw "could not make the build folder" && tFolder
   repeat for each item tTarget in "Windows,Windows x86-64,MacOSX x86-32,MacOSX x86-64,MacOSX x64-ARM64,Linux,Linux x64,Linux armv6-hf,Linux arm64,iOS,Android,Emscripten"
      set the cRevStandaloneSettings[tTarget] of stack pStack to (tTarget is edBuildTarget())
   end repeat
   set the cRevStandaloneSettings["name"] of stack pStack to pName
   set the cRevStandaloneSettings["inclusions"] of stack pStack to "select"
   set the cRevStandaloneSettings["answerDialog"] of stack pStack to true
   set the cRevStandaloneSettings["askDialog"] of stack pStack to true
   set the cRevStandaloneSettings["defaultBuildFolder"] of stack pStack to tFolder
   set the cRevStandaloneSettings["automaticallyBuildInDefaultFolder"] of stack pStack to true
end edBuildSettings

-- pStack, in front, saved with File > Save: its file holds what it is
-- now, and the IDE does not ask to save it before the build
command edSaveForBuild pStack
   local tPath, tMarker
   put the effective filename of stack pStack into tPath
   if tPath is empty then throw "the stack" && pStack && "has no file to save to"
   put "build-" & the milliseconds into tMarker
   set the cEverydayBuild of stack pStack to tMarker
   edMenu "File", "Save"
   if not edWaitFor("URL (" & quote & "binfile:" & quote & " & pAx) contains pBx", 5000, tPath, tMarker) then
      throw "File > Save before the build did not write" && pStack && "to" && tPath
   end if
end edSaveForBuild

-- pStack, in front and saved, built with File > Save as Standalone
-- Application..., and the build stopped by an error when the builder
-- reports the step pStep (edStopBuildAt). Returns what is not as it was
-- before the build, or empty: the stack is open, with the file name, the
-- substacks, the cards, the controls and the standalone settings it had;
-- no copy of an IDE dialog is left in memory; its file is the same bytes;
-- and the IDE asked nothing (the builder's own report of the error is off
-- here, revSetTestEnvironment in edCatchErrors, so any question is one
-- the stack that was left made the IDE ask, as 'A stack "Answer Dialog"
-- is already in memory' was)
function edStoppedBuild pStack, pStep
   local tPath, tBefore, tBytes, tSteps, tWhy
   -- (the builder's steps are compared as they are)
   set the caseSensitive to true
   put the effective filename of stack pStack into tPath
   put edBuildState(pStack) into tBefore
   put URL ("binfile:" & tPath) into tBytes
   put empty into sReport["steps"]
   put empty into sReport["answer"]
   edStopBuildAt pStep
   send "edAnswerWith" && quote & "OK,OK,OK,OK" & quote to me in 300 milliseconds
   try
      edMenu "File", "Save as Standalone Application..."
   finally
      edStopBuildAt empty
   end try
   put sReport["steps"] into tSteps
   -- (a step the builder no longer reports would let the build finish,
   -- and check nothing)
   if pStep is not among the lines of tSteps then
      return "the build did not reach" && quote & pStep & quote & ": it reported" && quote & edJoin(tSteps) & quote && "(the engine for" && edBuildTarget() & ":" && edBuildEngine() & "; the IDE asked:" && edJoin(sReport["answer"]) & ")"
   end if
   put edBuildLeft(pStack, tBefore, tBytes, "the build that stopped at" && pStep) into tWhy
   if tWhy is not empty then return tWhy
   edCancelPending "edAnswerWith"
   if sReport["answer"] is not empty then return "after the build that stopped at" && pStep && "the IDE asked:" && edJoin(sReport["answer"])
   return empty
end edStoppedBuild

-- What a build (pBuild: its name in the reason) left other than it found
-- it, or empty. pBefore is the stack's state before it (edBuildState) and
-- pBytes its file's bytes: the stack is open again (the builder closes
-- the stack it builds, and opens it again at its end) with the file
-- name, the substacks, the cards, the controls and the standalone
-- settings it had; no copy of an IDE dialog is left in memory; and its
-- file is the same bytes
function edBuildLeft pStack, pBefore, pBytes, pBuild
   local tPath, tAfter
   -- (the file's bytes and the stack's state are compared as they are)
   set the caseSensitive to true
   if not edWaitFor("edInMemory(pAx) and edOpen(pAx)", 5000, pStack) then
      return "the stack" && pStack && "is not open after" && pBuild && "(in memory:" && edInMemory(pStack) & ")"
   end if
   put the effective filename of stack pStack into tPath
   put edBuildState(pStack) into tAfter
   if tAfter is not pBefore then
      return "the stack is not as it was after" && pBuild & ". Before:" && edJoin(pBefore) && "After:" && edJoin(tAfter)
   end if
   if edDialogCopies() is not empty then return pBuild && "left in memory:" && edDialogCopies()
   if URL ("binfile:" & tPath) is not pBytes then
      return pBuild && "changed the stack's file" && tPath && "(" & the number of bytes of URL ("binfile:" & tPath) && "bytes, was" && the number of bytes of pBytes & ")"
   end if
   return empty
end edBuildLeft

-- The stack in front, built with File > Save as Standalone
-- Application... with the builder's dialogs on as a person has them
-- (revSetTestEnvironment is off for the build alone: its progress window
-- shows, and it says how the build ended). What the build went through,
-- what the IDE said and what the stack was sent are left in sReport
-- (edWatchBuild, edBuildSaid, edBuildMessage). pShot: the name of the
-- snapshot of the first dialog the build shows
command edBuildWithDialogs pShot
   local tKey
   repeat for each item tKey in "steps,answer,said,lastSaid,answered,messages,built"
      put empty into sReport[tKey]
   end repeat
   put 0 into sReport["dialogs"]
   put pShot into sReport["sayShot"]
   edWatchBuild true
   dispatch "revSetTestEnvironment" to stack "Home" with false
   send "edBuildSaid" && (the milliseconds + 180000) to me in 300 milliseconds
   try
      edMenu "File", "Save as Standalone Application..."
   finally
      dispatch "revSetTestEnvironment" to stack "Home" with true
      edWatchBuild false
      edCancelPending "edBuildSaid,edAnswerWith"
   end try
end edBuildWithDialogs

-- pStack, in front and saved, built to its end with the builder's
-- dialogs on (edBuildWithDialogs). Returns what went wrong or is not as
-- it was before, or empty (pShot: the name of the snapshot of the dialog
-- the build ends on):
--   - the IDE does not keep asking (edBuildSaid)
--   - the build goes through its steps to "Attaching engine..."
--   - the IDE says kBuildSaved, and nothing else (an error is said in
--     the same dialog, and so is in the reason)
--   - the builder has no warnings, and its progress window is gone
--   - the stack and its file are as they were (edBuildLeft)
--   - the stack's own script is sent savingStandalone before the build
--     and standaloneSaved with the folder after it (edAppScript passes
--     them on to edBuildMessage), which leaves the folder in
--     sReport["built"]
function edFullBuild pStack, pShot
   local tPath, tBefore, tBytes, tSteps, tSaid, tMessages, tWarnings, tError, tWhy
   put the effective filename of stack pStack into tPath
   put edBuildState(pStack) into tBefore
   put URL ("binfile:" & tPath) into tBytes
   edBuildWithDialogs pShot
   put sReport["steps"] into tSteps
   put sReport["said"] into tSaid
   put sReport["messages"] into tMessages
   try
      put revStandaloneGetWarnings() into tWarnings
   catch tError
      put "revStandaloneGetWarnings:" && edJoin(tError) into tWarnings
   end try
   -- (its warnings window, which the builder opens in place of its last
   -- word when it has any)
   if edOpen("revBuildResults") then close stack "revBuildResults"
   set the caseSensitive to true
   if sReport["dialogs"] > kBuildDialogs then
      return "the IDE kept asking during the build (" & sReport["dialogs"] && "dialogs, and the build was stopped): it said" && quote & edJoin(tSaid) & quote && "after the steps" && quote & edJoin(tSteps) & quote
   end if
   if "Attaching engine..." is not among the lines of tSteps then
      return "the build did not reach" && quote & "Attaching engine..." & quote & ": it reported" && quote & edJoin(tSteps) & quote && "(the engine for" && edBuildTarget() & ":" && edBuildEngine() & "; the IDE said:" && edJoin(tSaid) & "; warnings:" && edJoin(tWarnings) & ")"
   end if
   if line 1 of tSaid is not kBuildSaved then
      return "the IDE did not say" && quote & kBuildSaved & quote && "after the build: it said" && quote & edJoin(tSaid) & quote && "(warnings:" && edJoin(tWarnings) & ")"
   end if
   -- (one dialog: that sentence and the time the build took)
   if the number of lines of tSaid > 2 then return "the IDE said more than that the standalone was saved:" && edJoin(tSaid)
   if tWarnings is not empty then return "the build has warnings:" && edJoin(tWarnings)
   if edOpen("revStandaloneProgress") then return "the builder's progress window is still open after the build"
   -- (the stack first: one that is not the stack it was got the
   -- messages, or not, as another stack)
   put edBuildLeft(pStack, tBefore, tBytes, "the build") into tWhy
   if tWhy is not empty then return tWhy
   if line 1 of tMessages is not "savingStandalone" or word 1 of line 2 of tMessages is not "standaloneSaved" or the number of lines of tMessages is not 2 then
      return "the stack was not sent savingStandalone and then standaloneSaved: it was sent" && quote & edJoin(tMessages) & quote
   end if
   if sReport["built"] is empty or there is not a folder sReport["built"] then return "standaloneSaved named no folder that is there:" && quote & sReport["built"] & quote
   return empty
end edFullBuild

-- pStack, in front and saved, built with the builder's dialogs on
-- (edBuildWithDialogs) while the engine it attaches is looked for at
-- pEngine, where there is none: the builder's own way to be given
-- another engine (revSetOverrideRuntimePath of stack "Home"), for the
-- build alone. Returns what is not as it should be, or empty (pShot: the
-- name of the snapshot of the dialog the build stops on):
--   - the IDE does not keep asking (edBuildSaid)
--   - the build does not go on to "Attaching engine..."
--   - the IDE says kBuildNoEngine from its first word, then the file it
--     looked for, and nothing else
--   - the builder's progress window is gone
--   - the stack and its file are as they were (edBuildLeft)
function edRefusedBuild pStack, pEngine, pShot
   local tPath, tBefore, tBytes, tSteps, tSaid
   put the effective filename of stack pStack into tPath
   put edBuildState(pStack) into tBefore
   put URL ("binfile:" & tPath) into tBytes
   dispatch "revSetOverrideRuntimePath" to stack "Home" with pEngine
   try
      edBuildWithDialogs pShot
   finally
      dispatch "revSetOverrideRuntimePath" to stack "Home" with empty
   end try
   put sReport["steps"] into tSteps
   put sReport["said"] into tSaid
   set the caseSensitive to true
   if sReport["dialogs"] > kBuildDialogs then
      return "the IDE kept asking during the build that had no engine (" & sReport["dialogs"] && "dialogs, and the build was stopped): it said" && quote & edJoin(tSaid) & quote && "after the steps" && quote & edJoin(tSteps) & quote
   end if
   if "Attaching engine..." is among the lines of tSteps then
      return "the build went on to" && quote & "Attaching engine..." & quote && "with no engine at" && pEngine & ": it reported" && quote & edJoin(tSteps) & quote && "and the IDE said" && quote & edJoin(tSaid) & quote
   end if
   if tSaid is empty then
      return "the IDE said nothing when the build had no engine at" && pEngine & ": the build reported" && quote & edJoin(tSteps) & quote
   end if
   -- (the builder's sentence whole, as it throws it: its first word too)
   if word 1 to -1 of line 1 of tSaid is not kBuildNoEngine then
      return "the IDE did not say" && quote & kBuildNoEngine & quote && "when the build had no engine: it said" && quote & edJoin(tSaid) & quote
   end if
   if word 1 to -1 of line 2 of tSaid is not pEngine then
      return "the IDE did not name the file the builder looked for," && pEngine & ": it said" && quote & edJoin(tSaid) & quote
   end if
   if the number of lines of tSaid > 2 then return "the IDE said more than that the engine is not there:" && edJoin(tSaid)
   if edOpen("revStandaloneProgress") then return "the builder's progress window is still open after the build that had no engine"
   return edBuildLeft(pStack, tBefore, tBytes, "the build that had no engine")
end edRefusedBuild

-- What the IDE says while a build runs with the builder's dialogs on (at
-- its end "Standalone application saved successfully.", or its error):
-- each dialog noted in sReport["said"] and answered with OK, until the
-- time pUntil. Each is noted once and clicked once: the click that
-- answers it is the system's and runs on its own (edSystemDrag: on
-- Windows a PowerShell that has taken six seconds to start), so the
-- dialog is still there for some polls after it. One with other words is
-- another dialog, and one still there 15 s later is clicked again.
--
-- A build that keeps asking is stopped. Over the stack that
-- standalone-stopped-build left in 0.2.8-dp.1 (the IDE's Answer dialog
-- in it) a build stood at "Copying externals..." while the IDE said that
-- a stack "answer dialog" was already in memory, of the build's copy and
-- then of that stack's file, each answer bringing the next, until the
-- watchdog closed one after 30 s (the task does not start over such a
-- stack now). After kBuildDialogs dialogs the build is told to stop at
-- its next step (edWatchBuild), and edFullBuild says what was asked
on edBuildSaid pUntil
   local tAD, tText, tNew, tError
   put "Answer Dialog" into tAD
   if the milliseconds > pUntil then exit edBuildSaid
   if not (there is a stack tAD and the mode of stack tAD is not 0 and the visible of stack tAD) then
      put empty into sReport["answered"]
   else
      put the text of field 1 of card 1 of stack tAD into tText
      put (sReport["answered"] is empty or tText is not sReport["lastSaid"]) into tNew
      if tNew or the milliseconds - sReport["answered"] > 15000 then
         if tNew and sReport["dialogs"] < 2 * kBuildDialogs then put tText & return after sReport["said"]
         put tText into sReport["lastSaid"]
         add 1 to sReport["dialogs"]
         -- (the first thing said, under the name the task gives it and
         -- before the click that closes it: the dialog a person ends a
         -- build on. A snapshot that fails must not stop the answering)
         if sReport["dialogs"] is 1 and sReport["sayShot"] is not empty then
            try
               edShotStack tAD, sReport["sayShot"]
            catch tError
            end try
         end if
         if sReport["dialogs"] > kBuildDialogs then
            set the cEdStopBuild of stack "oxt_everyday" to "the everyday tasks stopped the build: the IDE has asked" && sReport["dialogs"] && "times"
         end if
         put the milliseconds into sReport["answered"]
         edAnswerWith "OK"
      end if
   end if
   send "edBuildSaid" && pUntil to me in 300 milliseconds
end edBuildSaid

-- savingStandalone and standaloneSaved, as the stack being built was
-- sent them (edAppScript)
on edBuildMessage pMessage, pFolder
   if pFolder is empty then
      put pMessage & return after sReport["messages"]
   else
      put pMessage && pFolder & return after sReport["messages"]
   end if
   if pMessage is "standaloneSaved" then put pFolder into sReport["built"]
end edBuildMessage

-- The stack script of the stack of standalone-built-and-run. In the IDE
-- it passes the two messages the builder sends a stack on to this script
-- (edBuildMessage). In the standalone built from it, it writes what it
-- finds itself to be into the file its cEverydayRan names, and quits: in
-- a standalone alone, where the IDE's own openStack of it passes (a quit
-- in the IDE would end the tasks). (' for the quotes of its text)
function edAppScript
   local tScript
   put "on savingStandalone" & return & \
         "   dispatch 'edBuildMessage' to stack 'oxt_everyday' with 'savingStandalone'" & return & \
         "end savingStandalone" & return & return & \
         "on standaloneSaved pFolder" & return & \
         "   dispatch 'edBuildMessage' to stack 'oxt_everyday' with 'standaloneSaved', pFolder" & return & \
         "end standaloneSaved" & return & return & \
         "on openStack" & return & \
         "   if the environment is not 'standalone application' then pass openStack" & return & \
         "   local tReport, tCode, tError, tSettings" & return & \
         "   put 0 into tCode" & return & \
         "   try" & return & \
         "      put 'EVERYDAY APP RAN' & return & 'environment: ' & the environment & return into tReport" & return & \
         "      put 'stack: ' & the short name of me & return after tReport" & return & \
         "      put 'controls: ' & the number of controls of card 1 of me & return after tReport" & return & \
         "      put 'greeting: ' & field 'Greeting' of card 1 of me & return after tReport" & return & \
         "      put 'answer dialog: ' & (there is a stack 'answer dialog') & return after tReport" & return & \
         "      put 'ask dialog: ' & (there is a stack 'ask dialog') & return after tReport" & return & \
         "      put 'engine: ' & the version && the platform && the processor & return after tReport" & return & \
         "      put the customProperties['cRevStandaloneSettings'] of me into tSettings" & return & \
         "      put 'standalone settings kept: ' & the number of lines of the keys of tSettings & return after tReport" & return & \
         "   catch tError" & return & \
         "      put 3 into tCode" & return & \
         "      put 'error: ' & tError & return after tReport" & return & \
         "   end try" & return & \
         "   put tReport into URL ('file:' & the cEverydayRan of me)" & return & \
         "   if the result is not empty and tCode is 0 then put 2 into tCode" & return & \
         "   quit tCode" & return & \
         "end openStack" into tScript
   replace "'" with quote in tScript
   return tScript
end edAppScript

-- the standalone pName under the folder pFolder, as the builder lays it
-- out for this computer (in a folder of its name, and there in one for
-- its platform when it is built for several; a Mac's is the program
-- inside its .app), or empty
function edFindStandalone pFolder, pName, pDepth
   local tPath, tFolder, tFound
   if char -1 of pFolder is "/" then delete char -1 of pFolder
   if pFolder is empty or there is not a folder pFolder then return empty
   switch the platform
      case "MacOS"
         put pFolder & "/" & pName & ".app/Contents/MacOS/" & pName into tPath
         break
      case "Win32"
         put pFolder & "/" & pName & ".exe" into tPath
         break
      default
         put pFolder & "/" & pName into tPath
   end switch
   if there is a file tPath then return tPath
   if pDepth >= 3 then return empty
   repeat for each line tFolder in folders(pFolder)
      if tFolder is "." or tFolder is ".." or tFolder ends with ".app" then next repeat
      put edFindStandalone(pFolder & "/" & tFolder, pName, pDepth + 1) into tFound
      if tFound is not empty then return tFound
   end repeat
   return empty
end edFindStandalone

-- the files and folders under pFolder, three folders down: what a build
-- made, for the record of a standalone that is not where it is looked for
function edListing pFolder, pDepth
   local tList, tName
   if char -1 of pFolder is "/" then delete char -1 of pFolder
   if pFolder is empty or there is not a folder pFolder then return "(no folder" && pFolder & ")"
   repeat for each line tName in files(pFolder)
      put pFolder & "/" & tName & return after tList
   end repeat
   repeat for each line tName in folders(pFolder)
      if tName is "." or tName is ".." then next repeat
      put pFolder & "/" & tName & "/" & return after tList
      if pDepth < 3 then put edListing(pFolder & "/" & tName, pDepth + 1) & return after tList
   end repeat
   return word 1 to -1 of tList
end edListing

-- The next build stops with an error when the builder reports the step
-- pStep: a front script on revStandaloneProgress, the command the
-- builder reports each of its steps with ("Copying resources...",
-- "Saving stack files...", ..., "Preparing main stackfile...",
-- "Attaching engine..."), which also notes every step reported
-- (edBuildStep). The error is the kind a full disk, a path too long or a
-- file in the way gives, at a step chosen. Empty takes it out again
command edStopBuildAt pStep
   edWatchBuild (pStep is not empty), pStep
end edStopBuildAt

-- The steps of the builds from now on noted (pOn true; false takes the
-- front script out again), and a build stopped with an error at the step
-- pStopAt when one is named, or at its next step once the cEdStopBuild
-- of this stack says why (edBuildSaid)
command edWatchBuild pOn, pStopAt
   local tDefault, tError, tStop
   if there is a button "oxt_everyday_build" of stack "oxt_everyday" then
      try
         remove the script of button "oxt_everyday_build" of stack "oxt_everyday" from front
      catch tError
      end try
   end if
   set the cEdStopBuild of stack "oxt_everyday" to empty
   if pOn is not true then exit edWatchBuild
   if pStopAt is not empty then
      put "   if pStep is " & quote & pStopAt & quote & " then throw " & quote & "the everyday tasks stopped the build at " & pStopAt & quote & return into tStop
   end if
   put the defaultStack into tDefault
   set the defaultStack to "oxt_everyday"
   lock messages
   if there is not a button "oxt_everyday_build" then create invisible button "oxt_everyday_build"
   set the script of button "oxt_everyday_build" to "on revStandaloneProgress pStep" & return & \
         "   dispatch " & quote & "edBuildStep" & quote & " to stack " & quote & "oxt_everyday" & quote & " with pStep" & return & \
         tStop & \
         "   if the cEdStopBuild of stack " & quote & "oxt_everyday" & quote & " is not empty then throw the cEdStopBuild of stack " & quote & "oxt_everyday" & quote & return & \
         "   pass revStandaloneProgress" & return & \
         "end revStandaloneProgress"
   insert the script of button "oxt_everyday_build" into front
   unlock messages
   if there is a stack tDefault then set the defaultStack to tDefault
end edWatchBuild

on edBuildStep pStep
   put pStep & return after sReport["steps"]
end edBuildStep

-- What a build must leave as it found it, as lines: the stack's file
-- name, its substacks, its cards, the controls of its first card and its
-- standalone settings
function edBuildState pStack
   local tState, tSubstacks, tSettings, tKeys, tKey
   if not edInMemory(pStack) then return "no stack" && pStack && "in memory"
   put the substacks of stack pStack into tSubstacks
   replace return with comma in tSubstacks
   put "file name:" && the effective filename of stack pStack & return & \
         "substacks:" && tSubstacks & return & \
         "cards:" && the number of cards of stack pStack & return & \
         "controls:" && the number of controls of card 1 of stack pStack & return into tState
   put the customProperties["cRevStandaloneSettings"] of stack pStack into tSettings
   put the keys of tSettings into tKeys
   sort lines of tKeys
   repeat for each line tKey in tKeys
      put "setting" && tKey & ":" && tSettings[tKey] & return after tState
   end repeat
   return tState
end edBuildState

-- The copies of the IDE's dialogs in memory: the IDE's own are main
-- stacks, so a substack of one of those names is a copy the builder made
function edDialogCopies
   local tMain, tSub, tCopies
   repeat for each line tMain in the mainStacks
      repeat for each line tSub in the substacks of stack tMain
         if tSub is among the items of "Answer Dialog,Ask Dialog,Print Dialog,Page Setup Dialog" then
            put tSub && "in" && tMain & ", " after tCopies
         end if
      end repeat
   end repeat
   return char 1 to -3 of tCopies
end edDialogCopies

-- whether the bytes of a stack file hold the IDE's Answer or Ask dialog
function edHasDialog pBytes
   return pBytes contains "Answer Dialog" or pBytes contains "Ask Dialog"
end edHasDialog

-- the stack a standalone task made (pStack) closed and deleted from
-- memory
command edRemoveBuiltStack pStack
   local tError
   if not edInMemory(pStack) then exit edRemoveBuiltStack
   try
      revIDESetEdited pStack, false
   catch tError
   end try
   delete stack pStack
end edRemoveBuiltStack

----------------------------------------------------------------
-- The Quick Start Guide's first lesson

-- The lesson done in the Guide at pFile; what was done goes to
-- sReport["guide"], and a step that fails throws
command edGuideLesson pFile
   local tCard, tNotes, tLine, tCount, tTile, tDrop, tFrom, tMade, tVia, tDrag, tNew, tPI, tMB, tKeys, tCode
   -- as Learn opens an example (leOpenExample in revlearn.livecodescript):
   -- the Run tool, then the stack
   edToolTile "com.livecode.tool.Browse"
   if not edWaitFor("the tool is " & quote & "browse tool" & quote, 3000) then throw "Run in the Tools palette did not choose the Browse tool (" & the tool & ")"
   -- (from here the Guide in memory is this run's own to take away,
   -- edGuideGone: the task has seen that none was in memory)
   put true into sKeep["guide"]
   go stack pFile
   if not edWaitFor("edOpen(pAx) and the short name of the topStack is pAx", 8000, kGuideStack) then
      throw "the Quick Start Guide did not open in front; the topStack is" && the short name of the topStack
   end if
   -- the front page says where the Try Its are done, and its first tile
   -- opens the lesson
   if "this window is the stack" is not in field "step2_text" of card 1 of stack kGuideStack then
      throw "the front page does not say that this window is the stack:" && field "step2_text" of card 1 of stack kGuideStack
   end if
   edClickAt kGuideStack, the loc of group "tile1" of card 1 of stack kGuideStack
   if not edWaitFor("the short name of this card of stack pAx is pBx", 4000, kGuideStack, kGuideLesson) then
      throw "a click on the front page's first tile did not open the lesson" && kGuideLesson && "(" & the short name of this card of stack kGuideStack & ")"
   end if
   put the long id of card kGuideLesson of stack kGuideStack into tCard
   -- what the notes say of the stack and of the Message Box
   put the text of field "Info" of tCard into tNotes
   put line lineOffset("from the tools palette to the stack", tNotes) of tNotes into tLine
   if "this window" is not in tLine or "Try It box" is not in tLine then
      throw "the notes do not say that the stack is this window, nor where on it the button goes:" && quote & tLine & quote
   end if
   -- (which tile of the Tools palette, in its modern look and in its
   -- classic one: "the top gray button" alone fits the classic look only,
   -- openxtalk.org p=26402)
   if "under Controls" is not in tLine or "reads OK" is not in tLine or "classic look" is not in tLine then
      throw "the notes do not say which tile of the Tools palette the standard button is, in its modern look and in its classic one:" && quote & tLine & quote
   end if
   put line lineOffset("Tools > Message Box", tNotes) of tNotes into tLine
   if "menu Tools > Message Box" is not in tLine or "window" is not in tLine or "Cmd-M" is not in tLine then
      throw "the notes do not say that the Message Box is a window the Tools menu opens, nor a Mac's key:" && quote & tLine & quote
   end if
   if there is not a field "canvasHint" of tCard or "here" is not in field "canvasHint" of tCard then throw "the Try It box does not say that the button goes there"
   edShotStack kGuideStack, "35b-quick-start-lesson"

   -- "1. Drag a standard button (the first one under Controls ...) from
   -- the tools palette to the stack": into the Try It box, right of My
   -- First Field
   put the number of buttons of tCard into tCount
   if tCount is not 1 then throw "the lesson has" && tCount && "buttons before one is made: its notes call the new one button 2"
   edGuideTileIsFirst
   edGuideTileIsFirstWhen "folded"
   edGuideTileIsFirstWhen "hidden"
   edToolFilter "button"
   put edTile("com.livecode.interface.classic.button") into tTile
   if tTile is empty then throw "the Tools palette has no button tile"
   put (the right of image "Canvas" of tCard - 48) & "," & (the bottom of image "Canvas" of tCard - 54) into tDrop
   if sInput is true then
      put "a drag of the system's mouse" into tMade
      put edScreenLoc(tTile, "revTools") into tFrom
      edSystemDrag tFrom, (item 1 of tDrop + the left of stack kGuideStack) & "," & (item 2 of tDrop + the top of stack kGuideStack)
      put edDragDone(20000) into tDrag
   else
      put "a double-click on its tile (the system's mouse does not reach the IDE)" into tMade
      send "mouseDoubleUp 1" to tTile
   end if
   if not edWaitFor("the number of buttons of pAx is 2", 6000, tCard) then
      throw "the button tile made no button on the lesson (" & tMade & "; the drag" && tDrag & "; the topStack" && the short name of the topStack & \
            "; the tool" && the tool & "; the lesson's buttons" && the number of buttons of tCard & ")"
   end if
   -- (a drag that worked keeps its record too: it says what the IDE had
   -- due before it, edSettled)
   if sInput is true then edRecord "INFO the lesson's drag" && tDrag
   edToolFilter empty
   put the long id of button 2 of tCard into tNew
   if the short name of tNew is "My First Button" then throw "the button made is not button 2 of the lesson, as its notes call it:" && the long name of button 1 of tCard
   if the long id of the owner of tNew is not tCard then throw "the button made is not on the lesson's card:" && the long owner of tNew
   if sInput is true and not (tDrop is within the rect of tNew) then throw "the button dropped at" && tDrop && "is at" && the rect of tNew
   if the tool is not "pointer tool" then throw "making the button left the" && the tool && "chosen: the notes go on In Edit Mode"

   -- "2. In Edit Mode, double-click the button for its Properties
   -- Inspector or Object > Object Inspector. 3. Enter a Name for the
   -- button: Color"
   edCloseInspectors
   edClickAt kGuideStack, edInside(tNew)
   if not edWaitFor("the selected of pAx", 2000, tNew) then throw "a click with the Pointer tool did not select the button made (" & edJoin(the selObj) & ")"
   edMenu "Object", "Object Inspector"
   put edInspector(5000) into tPI
   edTypeInEditor tPI, "name", "Color"
   if not edWaitFor("the short name of pAx is " & quote & "Color" & quote, 3000, tNew) then
      throw "the Inspector's Name did not name the button (" & the short name of tNew & ")"
   end if

   -- "1. Ctrl-M or menu Tools > Message Box. 2. In the upper field type
   -- and press returnKey", the lesson's two lines as it gives them
   put revIDEPaletteToStackName("message box") into tMB
   if edOpen(tMB) then close stack tMB
   put edShortcutName("m") into tKeys
   put edShortcut("m") into tVia
   if not edWaitFor("edOpen(pAx)", 5000, tMB) then throw tKeys && "(" & tVia & ") opened no Message Box over the lesson"
   -- (its keys let go, before the click on the Message Box's field)
   get edKeysHeld(tKeys)
   if it is not empty then throw it
   dispatch "showCard" to stack tMB with "Single Line"
   edClickAt tMB, the loc of field "message" of card "Single Line" of stack tMB
   select text of field "message" of card "Single Line" of stack tMB
   put line lineOffset("set the backColor of button", tNotes) of tNotes into tCode
   if tCode is empty then throw "the notes have no line that sets the backColor of the button"
   edType tMB, tCode & return
   if not edWaitFor("the backColor of pAx is " & quote & "red" & quote, 3000, tNew) then
      throw "the lesson's line" && quote & tCode & quote && "did not colour the button made (" & the backColor of tNew & "); the Message Box said:" && \
            edJoin(field "results" of card "Single Line" of stack tMB)
   end if
   put line lineOffset("set the showBorder of button", tNotes) of tNotes into tCode
   if tCode is empty then throw "the notes have no line that sets the showBorder of the button"
   select text of field "message" of card "Single Line" of stack tMB
   edType tMB, tCode & return
   if not edWaitFor("the showBorder of pAx is false", 3000, tNew) then
      throw "the lesson's line" && quote & tCode & quote && "did not take the border off the button made (" & the showBorder of tNew & "); the Message Box said:" && \
            edJoin(field "results" of card "Single Line" of stack tMB)
   end if
   edShotScreen "35c-quick-start-first-code"
   put "the button made by" && tMade & ", the Message Box opened by" && tKeys && "(" & tVia & ")" into sReport["guide"]
end edGuideLesson

-- The Guide out of memory unsaved (the lesson changed it), its Message
-- Box and Inspector closed, and the tasks' own stack in front again
-- The Guide opened on its first lesson, and a standard button, a label
-- field and a check box dragged from the Tools palette onto the free row
-- of its Try It box, under My First Field: each must be seen there
-- (edSeenPixels: 30 pixels or more of it; a word of a label is some
-- dozens). The Guide's look must be the IDE's, and the Try It box is
-- kept as the engine draws it, so that it can be looked at where a
-- window was over it on the screen
command edGuideDropped pFile
   local tCard, tWant, tLook, tCanvas, tType, tIndex, tSpot, tTile, tCount, tMade, tDrag, tNew, tSeen, tFile
   put empty into sReport["dropped"]
   edToolTile "com.livecode.tool.Browse"
   if not edWaitFor("the tool is " & quote & "browse tool" & quote, 3000) then throw "Run in the Tools palette did not choose the Browse tool (" & the tool & ")"
   -- (from here the Guide in memory is this run's own to take away)
   put true into sKeep["guide"]
   go stack pFile
   if not edWaitFor("edOpen(pAx) and the short name of the topStack is pAx", 8000, kGuideStack) then
      throw "the Quick Start Guide did not open in front; the topStack is" && the short name of the topStack
   end if
   -- (the front page's tile is the lesson's task's to click)
   go card kGuideLesson of stack kGuideStack
   if not edWaitFor("the short name of this card of stack pAx is pBx", 4000, kGuideStack, kGuideLesson) then
      throw "the Guide did not go to the lesson" && kGuideLesson && "(" & the short name of this card of stack kGuideStack & ")"
   end if
   put the long id of card kGuideLesson of stack kGuideStack into tCard
   put "light" into tWant
   if revIDEAppearanceIsDark() is true then put "dark" into tWant
   put the uLook of stack kGuideStack into tLook
   if tLook is empty then put "light" into tLook
   if tLook is not tWant then throw "the IDE has its" && tWant && "look on and the Quick Start Guide its" && tLook && "one"
   put the rect of image "Canvas" of tCard into tCanvas
   put 0 into tIndex
   repeat for each item tType in "Button,LabelField,Checkbox"
      add 1 to tIndex
      -- (the row between My First Field and the box's hint, left to right)
      put (item 1 of tCanvas + 64 + (tIndex - 1) * 98) & "," & (the bottom of field "Field Test" of tCard + 20) into tSpot
      put the number of controls of tCard into tCount
      edToolFilter tType
      put edTile("com.livecode.interface.classic." & tType) into tTile
      if tTile is empty then throw "the Tools palette has no" && tType && "tile"
      if sInput is true then
         put "a drag of the system's mouse" into tMade
         edSystemDrag edScreenLoc(tTile, "revTools"), (item 1 of tSpot + the left of stack kGuideStack) & "," & (item 2 of tSpot + the top of stack kGuideStack)
         put edDragDone(20000) into tDrag
      else
         put "a double-click on its tile (the system's mouse does not reach the IDE)" into tMade
         send "mouseDoubleUp 1" to tTile
      end if
      if not edWaitFor("the number of controls of pAx is pBx + 1", 6000, tCard, tCount) then
         throw "the" && tType && "tile made nothing on the lesson (" & tMade & "; the drag" && tDrag & "; the topStack" && the short name of the topStack & "; the tool" && the tool & ")"
      end if
      if sInput is true then edRecord "INFO the drag of the" && tType && tDrag
      edToolFilter empty
      put the long id of control (tCount + 1) of tCard into tNew
      if the long id of the owner of tNew is not tCard then throw "the" && tType && "made is not on the lesson's card:" && the long owner of tNew
      if sInput is not true then set the loc of tNew to tSpot
      if not (tSpot is within the rect of tNew) then throw "the" && tType && "dropped at" && tSpot && "is at" && the rect of tNew
      if not (the loc of tNew is within tCanvas) then throw "the" && tType && "is not on the Try It box (" & tCanvas & "):" && the rect of tNew
      -- (as it is when the reader clicks elsewhere: its handles are not it)
      select empty
      put edSeenPixels(tNew) into tSeen
      edRecord "INFO in the" && tLook && "look the" && tType && "dropped on the Try It box at" && the rect of tNew && "changes" && tSeen && "pixels of it; its words" && \
            the effective textColor of tNew && "on" && the effective backColor of tNew
      if tSeen < 30 then
         throw "in the" && tLook && "look the" && tType && "dropped on the Try It box cannot be seen:" && tSeen && "of its pixels differ from the box under it (its words" && \
               the effective textColor of tNew & ", made by" && tMade & ")"
      end if
      put tType && tSeen & "; " after sReport["dropped"]
   end repeat
   put "pixels changed, in the" && tLook && "look, made by" && tMade after sReport["dropped"]
   edShotStack kGuideStack, "35d-quick-start-dropped"
   -- (and the box as the engine draws it)
   put sOut & slash & "everyday-35e-quick-start-try-it-drawn.png" into tFile
   export snapshot from rect tCanvas of tCard to file tFile as PNG
   if there is not a file tFile then throw "the picture of the Try It box was not written (" & the result & ")"
   edRecord "SHOT everyday-35e-quick-start-try-it-drawn.png" && tCanvas
end edGuideDropped

command edGuideAway
   local tMB, tError
   try
      put revIDEPaletteToStackName("message box") into tMB
      if edOpen(tMB) then close stack tMB
      edCloseInspectors
      edToolFilter empty
   catch tError
      edRecord "INFO putting the lesson's windows away:" && edJoin(tError)
   end try
   edGuideGone
   edFront
end edGuideAway

-- The Guide closed and deleted from memory unsaved, if this run opened
-- it (sKeep["guide"], set as edGuideLesson opens the file). A stack of
-- that name in memory before the tasks is a person's own, with work
-- they may not have saved: the lesson's task stops on it and touches
-- nothing, so nothing here may delete it either, at the end of the
-- lesson or of the run (ed_finish, which runs whatever tasks ran)
command edGuideGone
   if sKeep["guide"] is not true then exit edGuideGone
   edRemoveBuiltStack kGuideStack
   put false into sKeep["guide"]
end edGuideGone

----------------------------------------------------------------
-- Preferences: a checkbox in its window that a person might turn on and
-- off, and the preference it keeps

function edPrefsCheckbox pPrefs
   local tCard, tControl, i, tName
   -- the General pane's checkbox Navigation arrows (or its first that
   -- names a preference)
   put the long id of this card of stack pPrefs into tCard
   if there is a button "navigation arrows" of tCard then
      put the long id of button "navigation arrows" of tCard into tControl
      put edPrefOf(tControl) into tName
      if tName is not empty and the enabled of tControl and the visible of tControl then
         put tName into sReport["pref"]
         put edPrefValue() into sReport["prefWas"]
         return tControl
      end if
   end if
   repeat with i = 1 to the number of buttons of tCard
      put the long id of button i of tCard into tControl
      if the style of tControl is not "checkbox" then next repeat
      if not the visible of tControl or not the enabled of tControl then next repeat
      put edPrefOf(tControl) into tName
      if tName is empty then next repeat
      put tName into sReport["pref"]
      put edPrefValue() into sReport["prefWas"]
      return tControl
   end repeat
   return empty
end edPrefsCheckbox

-- the preference a checkbox of Preferences sets: a property of the stack
-- revPreferences named in its script (set the cX of stack "revPreferences"
-- or revIDESetPreference "cX")
function edPrefOf pControl
   local tScript, tWord, tOffset
   put the script of pControl into tScript
   if tScript is empty and the behavior of pControl is not empty then put the script of the behavior of pControl into tScript
   put offset("of stack" && quote & "revPreferences" & quote, tScript) into tOffset
   if tOffset > 0 then
      get char 1 to tOffset - 1 of tScript
      put word -1 of line -1 of it into tWord
      if tWord begins with "c" then return tWord
   end if
   put offset("revIDESetPreference" && quote, tScript) into tOffset
   if tOffset > 0 then
      get char tOffset + 21 to tOffset + 80 of tScript
      return char 1 to offset(quote, it) - 1 of it
   end if
   return empty
end edPrefOf

function edPrefValue
   if sReport["pref"] is empty then return empty
   get the customProperties of stack "revPreferences"
   return revIDEGetPreference(sReport["pref"]) & "|" & it[sReport["pref"]]
end edPrefValue

----------------------------------------------------------------
-- Acting as a person does

-- the menu bar's menu pMenu as the IDE builds it now: the item pPath
-- (its menuPick: "item" or "item|subitem", or the item's tag) must be
-- there and enabled; then its menuPick
command edMenu pMenu, pPath
   local tItems, tState
   put edMenuItems(pMenu) into tItems
   put edMenuState(tItems, pPath) into tState
   if tState is empty then throw pMenu && "has no item" && quote & pPath & quote && "(" & edJoin(edMenuNames(tItems)) & ")"
   if tState is "disabled" then throw pMenu && ">" && pPath && "is disabled"
   edRecord "INFO menu" && pMenu && ">" && pPath
   dispatch "menuPick" to button pMenu of group "revMenuBar" of stack "revMenuBar" with pPath
end edMenu

-- each item of the menu: its menuPick, a tab, enabled or disabled
function edMenuItems pMenu
   local tText, tLine, tDepth, tLabel, tTag, tPath, tParents, tOut, tOff
   dispatch function "buildMenuContext" to stack "revMenuBar"
   get the result
   dispatch function "revMenubarBuildMenu" to stack "revMenuBar" with pMenu, it
   put the result into tText
   if tText is empty then put the text of button pMenu of group "revMenuBar" of stack "revMenuBar" into tText
   repeat for each line tLine in tText
      put 0 into tDepth
      repeat while char 1 of tLine is tab
         add 1 to tDepth
         delete char 1 of tLine
      end repeat
      put false into tOff
      if char 1 of tLine is "(" then
         put true into tOff
         delete char 1 of tLine
      end if
      repeat while char 1 of tLine is "!"
         delete char 1 to 2 of tLine
      end repeat
      if char 1 of tLine is "(" then
         put true into tOff
         delete char 1 of tLine
      end if
      put empty into tTag
      if "|" is in tLine then
         put char offset("|", tLine) + 1 to -1 of tLine into tTag
         put char 1 to offset("|", tLine) - 1 of tLine into tLine
      end if
      if "/" is in tLine then put char 1 to offset("/", tLine) - 1 of tLine into tLine
      replace "&" with empty in tLine
      if tLine is "-" or tLine is empty then next repeat
      if tTag is not empty then put tTag into tLabel
      else put tLine into tLabel
      put tLabel into tParents[tDepth]
      put empty into tPath
      repeat with i = 0 to tDepth
         put tParents[i] & "|" after tPath
      end repeat
      delete the last char of tPath
      put tPath & tab & tLine & tab & (not tOff) & return after tOut
   end repeat
   return tOut
end edMenuItems

-- enabled, disabled or empty (no such item)
function edMenuState pItems, pPath
   set the itemDelimiter to tab
   repeat for each line tLine in pItems
      if item 1 of tLine is pPath or item 2 of tLine is pPath then
         if item 3 of tLine is true then return "enabled"
         return "disabled"
      end if
   end repeat
   return empty
end edMenuState

-- the line of pItems (edMenuItems) whose pick is pPath, or 0
function edMenuAt pItems, pPath
   local tAt
   set the itemDelimiter to tab
   repeat for each line tLine in pItems
      add 1 to tAt
      if item 1 of tLine is pPath then return tAt
   end repeat
   return 0
end edMenuAt

-- whether the window pStack is in front of the window pOther (the
-- windows: front to back)
function edFrontOf pStack, pOther
   local tAt, tStackAt, tOtherAt
   repeat for each line tWindow in the windows
      add 1 to tAt
      if tWindow is pStack and tStackAt is empty then put tAt into tStackAt
      if tWindow is pOther and tOtherAt is empty then put tAt into tOtherAt
   end repeat
   return tStackAt is not empty and tOtherAt is not empty and tStackAt < tOtherAt
end edFrontOf

function edMenuNames pItems
   local tNames
   set the itemDelimiter to tab
   repeat for each line tLine in pItems
      put item 1 of tLine & ", " after tNames
   end repeat
   return char 1 to -3 of tNames
end edMenuNames

-- a click of the engine at pLoc (of the card of pStack), with pKeys
-- ("shift") held
command edClickAt pStack, pLoc, pKeys
   local tDefault
   put the defaultStack into tDefault
   set the defaultStack to pStack
   if pKeys is "shift" then
      click at pLoc with shiftKey
   else
      click at pLoc
   end if
   if there is a stack tDefault then set the defaultStack to tDefault
   edPause 150
end edClickAt

-- a click of the system's mouse (button 1, or 3 for a right-click) at
-- pLoc in the window of pStack, where it reaches the IDE (the App
-- Browser reads where the mouse is, not where the engine's click was);
-- else the engine's click
-- pKeys (a right click only): keys pressed once the menu the click opens
-- is up, in the same system script as the click, so that they never come
-- first: sent on a timer they could reach the IDE before a slow click (a
-- PowerShell's start on Windows), where Down moved the control selected
command edRealClickAt pStack, pLoc, pButton, pKeys
   local tScreen, tCommand, tScript, tKey, tCodes
   if pButton is empty then put 1 into pButton
   if sInput is not true then
      if pButton is 3 then
         if pKeys is not empty then
            send "edSystemKeys pKeys" to me in 1200 milliseconds
         end if
         edRightClickAt pStack, pLoc
      else
         edClickAt pStack, pLoc
      end if
      exit edRealClickAt
   end if
   put (item 1 of pLoc + the left of stack pStack) & "," & (item 2 of pLoc + the top of stack pStack) into tScreen
   if pButton is 1 then
      edSystemDrag tScreen, tScreen
      edPause 1600
      exit edRealClickAt
   end if
   switch the platform
      case "MacOS"
         put "ObjC.import('CoreGraphics'); function ev(t, x, y) { var e = $.CGEventCreateMouseEvent(null, t, {x: x, y: y}, 1); " & \
               "$.CGEventPost(0, e); } delay(0.3); ev(5," & tScreen & "); delay(0.15); ev(3," & tScreen & "); delay(0.1); ev(4," & tScreen & ");" into tScript
         if pKeys is not empty then
            repeat for each item tKey in pKeys
               put edMacKeyCode(tKey) & "," after tCodes
            end repeat
            delete the last char of tCodes
            put " delay(0.8); [" & tCodes & "].forEach(function (k) { " & \
                  "$.CGEventPost(0, $.CGEventCreateKeyboardEvent(null, k, true)); delay(0.1); " & \
                  "$.CGEventPost(0, $.CGEventCreateKeyboardEvent(null, k, false)); delay(0.15); });" after tScript
         end if
         get shell("osascript -l JavaScript -e " & quote & tScript & quote & " >/dev/null 2>&1 &")
         break
      case "Win32"
         put "Add-Type -Namespace OxtEd -Name Mouse3 -MemberDefinition '" & \
               "[DllImport(" & quote & "user32.dll" & quote & ")] public static extern bool SetCursorPos(int x, int y); " & \
               "[DllImport(" & quote & "user32.dll" & quote & ")] public static extern void mouse_event(int f, int x, int y, int d, int e);'" & return & \
               "Start-Sleep -Milliseconds 300" & return & \
               "[OxtEd.Mouse3]::SetCursorPos(" & tScreen & ") | Out-Null" & return & \
               "Start-Sleep -Milliseconds 150" & return & \
               "[OxtEd.Mouse3]::mouse_event(8, 0, 0, 0, 0)" & return & \
               "Start-Sleep -Milliseconds 100" & return & \
               "[OxtEd.Mouse3]::mouse_event(16, 0, 0, 0, 0)" into tScript
         if pKeys is not empty then
            put return & "Add-Type -AssemblyName System.Windows.Forms" & return & \
                  "Start-Sleep -Milliseconds 800" after tScript
            repeat for each item tKey in pKeys
               put return & "[System.Windows.Forms.SendKeys]::SendWait('{" & edWinKeyName(tKey) & "}'); Start-Sleep -Milliseconds 150" after tScript
            end repeat
         end if
         put base64Encode(textEncode(tScript, "UTF-16LE")) into tScript
         replace return with empty in tScript
         launch "powershell -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand" && tScript
         break
      default
         put "(sleep 0.3; xdotool mousemove" && item 1 of tScreen && item 2 of tScreen && "sleep 0.15 click 3" into tCommand
         if pKeys is not empty then
            put " sleep 0.8" after tCommand
            repeat for each item tKey in pKeys
               put " key" && tKey && "sleep 0.15" after tCommand
            end repeat
         end if
         get shell(tCommand & ") >/dev/null 2>&1 &")
         break
   end switch
   edPause 1200
end edRealClickAt

-- a right-click (button 3) at pLoc in the window of pStack
command edRightClickAt pStack, pLoc
   local tDefault
   put the defaultStack into tDefault
   set the defaultStack to pStack
   click button 3 at pLoc
   if there is a stack tDefault then set the defaultStack to tDefault
   edPause 150
end edRightClickAt

-- keys pressed on the system's keyboard, a comma-separated list of Down,
-- Up, Return, Escape (for a menu open now) and the letters m and x
command edSystemKeys pKeys
   local tKey, tCommand, tCodes
   switch the platform
      case "MacOS"
         repeat for each item tKey in pKeys
            put edMacKeyCode(tKey) & "," after tCodes
         end repeat
         delete the last char of tCodes
         put "ObjC.import('CoreGraphics'); [" & tCodes & "].forEach(function (k) { " & \
               "$.CGEventPost(0, $.CGEventCreateKeyboardEvent(null, k, true)); delay(0.1); " & \
               "$.CGEventPost(0, $.CGEventCreateKeyboardEvent(null, k, false)); delay(0.15); });" into tCommand
         get shell("osascript -l JavaScript -e " & quote & tCommand & quote & " >/dev/null 2>&1 &")
         break
      case "Win32"
         put "Add-Type -AssemblyName System.Windows.Forms" & return into tCommand
         repeat for each item tKey in pKeys
            put "[System.Windows.Forms.SendKeys]::SendWait('{" & edWinKeyName(tKey) & "}'); Start-Sleep -Milliseconds 150" & return after tCommand
         end repeat
         put base64Encode(textEncode(tCommand, "UTF-16LE")) into tCommand
         replace return with empty in tCommand
         launch "powershell -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand" && tCommand
         break
      default
         put "(xdotool" into tCommand
         repeat for each item tKey in pKeys
            put " key" && tKey && "sleep 0.15" after tCommand
         end repeat
         get shell(tCommand & ") >/dev/null 2>&1 &")
         break
   end switch
end edSystemKeys

-- Ctrl (Cmd on a Mac) held and the letter pLetter pressed, on the
-- system's keyboard
command edSystemShortcut pLetter
   local tCommand
   switch the platform
      case "MacOS"
         -- (The Command key itself goes down before the letter and up
         -- after it, as a hand presses them: 55 is its key, kVK_Command,
         -- and 1048576 its flag, kCGEventFlagMaskCommand; its key up
         -- carries no flag. The letter's two events alone with the flag
         -- on them picked the menu item just the same, but then no event
         -- ever said that Command was up, and macOS went on holding it:
         -- the commandKey was down for every click after, and the App
         -- Browser added the next control clicked to its selection as it
         -- does for a Command-click. edKeysHeld asks after each shortcut)
         put "ObjC.import('CoreGraphics'); function key(k, d, f) { var e = $.CGEventCreateKeyboardEvent(null, k, d); " & \
               "$.CGEventSetFlags(e, f); $.CGEventPost(0, e); delay(0.1); } " & \
               "key(55, true, 1048576); key(" & edMacKeyCode(pLetter) & ", true, 1048576); " & \
               "key(" & edMacKeyCode(pLetter) & ", false, 1048576); key(55, false, 0);" into tCommand
         get shell("osascript -l JavaScript -e " & quote & tCommand & quote & " >/dev/null 2>&1 &")
         break
      case "Win32"
         put "Add-Type -AssemblyName System.Windows.Forms" & return & \
               "[System.Windows.Forms.SendKeys]::SendWait('^" & toLower(pLetter) & "')" & return into tCommand
         put base64Encode(textEncode(tCommand, "UTF-16LE")) into tCommand
         replace return with empty in tCommand
         launch "powershell -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand" && tCommand
         break
      default
         get shell("(xdotool key ctrl+" & toLower(pLetter) & ") >/dev/null 2>&1 &")
         break
   end switch
end edSystemShortcut

-- the shortcut's name, as its menu item shows it
function edShortcutName pLetter
   if the platform is "MacOS" then return "Cmd+" & toUpper(pLetter)
   return "Ctrl+" & toUpper(pLetter)
end edShortcutName

-- The shortcut Ctrl (Cmd on a Mac) and pLetter pressed as a person
-- presses it: on the system's keyboard where its keys reach the IDE,
-- else typed by the engine with the key held. Returns which, for the
-- record: "the system's keyboard" or what took its place
function edShortcut pLetter
   if edKeysWork() then
      edSystemShortcut pLetter
      return "the system's keyboard"
   end if
   edType the short name of the topStack, pLetter, "command"
   return "the engine's own keys (the system's keyboard does not reach the IDE)"
end edShortcut

-- The modifier keys still down after the shortcut pKeys was pressed and
-- answered, in words for a throw, or empty: each must be let go, as a
-- hand lets go. One that the system goes on holding makes every click
-- after it another click (the App Browser adds a Command-click on a
-- control to its selection, and the Inspector then has two objects)
function edKeysHeld pKeys
   local tHeld
   if edWaitFor("the commandKey is up and the controlKey is up and the optionKey is up and the shiftKey is up", 3000) then return empty
   if the commandKey is down then put " commandKey" after tHeld
   if the controlKey is down then put " controlKey" after tHeld
   if the optionKey is down then put " optionKey" after tHeld
   if the shiftKey is down then put " shiftKey" after tHeld
   return "after" && pKeys && "was pressed, the system still holds a key down:" & tHeld
end edKeysHeld

-- Whether a key of the system's keyboard reaches the IDE here: a field
-- of a stack of this script's must get its letter (as edInputWorks asks
-- of the mouse). Asked once in a run; the stack in front before it is in
-- front again after it, by the system's click where that reaches, so
-- that the keys that follow go where a person's would
function edKeysWork
   local tStack, tDefault, tTop, tTool, tLoc, tWorks
   if sKeep["keysWork"] is not empty then return sKeep["keysWork"]
   put "OXT Everyday Key Check" into tStack
   if there is a stack tStack then delete stack tStack
   put the defaultStack into tDefault
   put the short name of the topStack into tTop
   put the tool into tTool
   lock messages
   create stack tStack
   set the rect of stack tStack to (item 3 of the screenRect - 380) & ",160," & (item 3 of the screenRect - 80) & ",320"
   set the defaultStack to tStack
   create field "Keys"
   set the rect of it to "60,50,240,100"
   unlock messages
   go stack tStack
   choose browse tool
   edPause 500
   put the loc of field "Keys" of card 1 of stack tStack into tLoc
   if sInput is true then
      edRealClickAt tStack, tLoc
   else
      edClickAt tStack, tLoc
   end if
   select after text of field "Keys" of card 1 of stack tStack
   edSystemKeys "x"
   get edWaitFor("field " & quote & "Keys" & quote & " of card 1 of stack pAx is " & quote & "x" & quote, 8000, tStack)
   put field "Keys" of card 1 of stack tStack is "x" into tWorks
   edRecord "INFO the system's keyboard reaches the IDE:" && tWorks && "(the check's field holds" && quote & field "Keys" of card 1 of stack tStack & quote & ")"
   if word 1 of tTool is "browse" then
      choose browse tool
   else
      choose pointer tool
   end if
   delete stack tStack
   if there is a stack tDefault then set the defaultStack to tDefault
   if there is a stack tTop and the mode of stack tTop is 1 then
      go stack tTop
      -- (a click on its title bar's height below its top would be on a
      -- control: the card's bottom right corner is clear of the tasks')
      if sInput is true and tWorks then edRealClickAt tTop, (the width of stack tTop - 6) & "," & (the height of stack tTop - 6)
   end if
   put tWorks into sKeep["keysWork"]
   return tWorks
end edKeysWork

-- The Tools palette shown again and the Message Box pMB closed, after a
-- task that closed the one and opened the other
command edToolsBack pMB
   if pMB is not empty and edOpen(pMB) then close stack pMB
   if not revIDEPaletteIsVisible("tools") then revIDEOpenPalette "tools"
   get edWaitFor("edOpen(" & quote & "revTools" & quote & ")", 5000)
end edToolsBack

-- a key's virtual key code on macOS (Down, Up, Return, Escape, m, x, c, v)
function edMacKeyCode pKey
   switch pKey
      case "Down"
         return 125
      case "Up"
         return 126
      case "Return"
         return 36
      case "Escape"
         return 53
      case "m"
         return 46
      case "x"
         return 7
      case "c"
         return 8
      case "v"
         return 9
   end switch
   return empty
end edMacKeyCode

-- a key's name for Windows' SendKeys (Down, Up, Return, Escape)
function edWinKeyName pKey
   if pKey is "Return" then return "ENTER"
   if pKey is "Escape" then return "ESC"
   return toUpper(pKey)
end edWinKeyName

command edDragIn pStack, pFrom, pTo
   local tDefault
   put the defaultStack into tDefault
   set the defaultStack to pStack
   drag from pFrom to pTo
   if there is a stack tDefault then set the defaultStack to tDefault
   edPause 150
end edDragIn

-- typing in the window of pStack, at the focus there, with pKeys
-- ("control") held
command edType pStack, pText, pKeys
   local tDefault
   put the defaultStack into tDefault
   set the defaultStack to pStack
   if pKeys is "control" then
      type pText with controlKey
   else if pKeys is "command" then
      type pText with commandKey
   else
      type pText
   end if
   if there is a stack tDefault then set the defaultStack to tDefault
   edPause 150
end edType

-- the object clicked with the Pointer tool, alone
command edSelect pObject
   edFront
   revIDEDeselectAll
   if the tool is not "pointer tool" then edToolTile "com.livecode.tool.Pointer"
   edClickAt sStack, edInside(pObject)
   if not edWaitFor("the selected of pAx", 2000, pObject) then
      throw "a click with the Pointer tool did not select" && the short name of pObject && "(" & edJoin(the selObj) & ")"
   end if
end edSelect

-- a point inside pObject clear of its edges (and of a field's text, for
-- a click in edit mode it makes no difference)
function edInside pObject
   -- (a group is clicked on its first control: its own space between them
   -- is not it)
   if word 1 of pObject is "group" and the number of controls of pObject > 0 then return edInside(the long id of control 1 of pObject)
   return (item 1 of the topLeft of pObject + min(12, the width of pObject div 3)) & "," & (item 2 of the loc of pObject)
end edInside

-- the stack in front, as a click on its window makes it, in Edit mode
-- (a task that failed in Run mode does not leave the next one there)
command edFront
   if sStack is empty or there is not a stack sStack then exit edFront
   if the short name of the topStack is not sStack then
      go stack sStack
      get edWaitFor("the short name of the topStack is sStack", 2000)
   end if
   set the defaultStack to sStack
   if the tool is "browse tool" then edToolTile "com.livecode.tool.Pointer"
end edFront

-- the button the Inspector named Okay
function edOkay
   if sKeep["okay"] is empty or sStack is empty or there is not a stack sStack then throw "no button Okay (an earlier task did not name it)"
   if there is not a button id sKeep["okay"] of card 1 of stack sStack then throw "the button Okay is not on the card"
   return the long id of button id sKeep["okay"] of card 1 of stack sStack
end edOkay

-- the control of the stack that the Tools palette made as pWord's tile
-- (the first one of that kind)
function edControl pWord
   local tCard, i, tControl
   if sStack is empty or there is not a stack sStack then throw "no stack: an earlier task did not make it"
   put the long id of card 1 of stack sStack into tCard
   repeat with i = 1 to the number of controls of tCard
      put the long id of control i of tCard into tControl
      if pWord is "checkbox" and the cEverydayType of tControl is "Checkbox" then return tControl
      if pWord is "field" and the cEverydayType of tControl is "Field" then return tControl
      if pWord is "button" and the cEverydayType of tControl is "Button" then return tControl
      if pWord is "graphic" and word 1 of tControl is "graphic" then return tControl
      if pWord is "scrollbar" and word 1 of tControl is "scrollbar" then return tControl
   end repeat
   throw "the stack has no" && pWord && "(an earlier task did not make it)"
end edControl

-- the row of the Project Browser pPB for the object pObject, or empty
function edPBRow pPB, pObject
   dispatch function "getRow" to stack pPB with pObject
   if it is "handled" then return the result
   return empty
end edPBRow

-- runs pJS in the Dictionary's page and returns what it reports
-- (liveCode.oxtEdReport), as the tour's tourPageReport
function edPageReport pStack, pJS
   local tDefault, tHandlers, tError, tData
   put the defaultStack into tDefault
   set the defaultStack to "oxt_everyday"
   lock messages
   if there is not a button "oxt_everyday_report" then create invisible button "oxt_everyday_report"
   set the script of button "oxt_everyday_report" to "on oxtEdReport pData" & return & \
         "   dispatch " & quote & "edReported" & quote & " to stack " & quote & "oxt_everyday" & quote & " with pData" & return & \
         "end oxtEdReport"
   insert the script of button "oxt_everyday_report" into front
   unlock messages
   if there is a stack tDefault then set the defaultStack to tDefault
   put the javascriptHandlers of widget "Dictionary" of stack pStack into tHandlers
   set the javascriptHandlers of widget "Dictionary" of stack pStack to tHandlers & return & "oxtEdReport"
   put empty into sReport["page"]
   try
      do pJS in widget "Dictionary" of stack pStack
      get edWaitFor("sReport[" & quote & "page" & quote & "] is not empty", 8000)
      put sReport["page"] into tData
   catch tError
   end try
   set the javascriptHandlers of widget "Dictionary" of stack pStack to tHandlers
   remove the script of button "oxt_everyday_report" of stack "oxt_everyday" from front
   if tError is not empty then throw tError
   return tData
end edPageReport

on edReported pData
   put pData into sReport["page"]
end edReported

-- a 24 by 24 PNG of two colours, written by the engine
command edWritePng pFile
   local tDefault, tData
   put the defaultStack into tDefault
   set the defaultStack to "oxt_everyday"
   lock messages
   create invisible image "oxt_everyday_png"
   set the width of it to 24
   set the height of it to 24
   repeat 24 * 12
      put numToByte(0) & numToByte(200) & numToByte(40) & numToByte(40) after tData
   end repeat
   repeat 24 * 12
      put numToByte(0) & numToByte(40) & numToByte(40) & numToByte(200) after tData
   end repeat
   set the imageData of image "oxt_everyday_png" to tData
   export image "oxt_everyday_png" to file pFile as PNG
   delete image "oxt_everyday_png"
   unlock messages
   if there is a stack tDefault then set the defaultStack to tDefault
   if there is not a file pFile then throw "could not write the picture" && pFile
end edWritePng

----------------------------------------------------------------
-- Waiting, windows and snapshots

-- Waits until the expression pTrue is true, at most pMilliseconds, going
-- back through the event loop each tenth of a second. Returns whether it
-- was. The expression is evaluated here, where the caller's variables are
-- out of reach: it names the script's locals, and pAx to pDx for the
-- values the caller passes after pMilliseconds
function edWaitFor pTrue, pMilliseconds, pAx, pBx, pCx, pDx
   local tEnd, tValue
   put the milliseconds + pMilliseconds into tEnd
   repeat
      try
         put value(pTrue) into tValue
      catch tValue
         put false into tValue
      end try
      if tValue is true then return true
      if the milliseconds >= tEnd then return false
      wait 100 milliseconds with messages
   end repeat
end edWaitFor

-- a pause in which the IDE handles what comes (a click's mouseUp, a
-- redraw): for what has nothing to wait for
command edPause pMilliseconds
   wait pMilliseconds milliseconds with messages
end edPause

-- whether a main stack named pStack is in memory, loading nothing
function edInMemory pStack
   repeat for each line tStack in the mainStacks
      if tStack is pStack then return true
   end repeat
   return false
end edInMemory

function edOpen pStack
   return there is a stack pStack and the mode of stack pStack is not 0 and the visible of stack pStack
end edOpen

-- the first visible open stack whose name starts with pPrefix
function edStackNamed pPrefix
   repeat for each line tStack in the openStacks
      if tStack begins with pPrefix and the visible of stack tStack then return tStack
   end repeat
   return empty
end edStackNamed

-- a visible open stack of mode 1 that was not in pBefore
function edNewStack pBefore
   repeat for each line tStack in the openStacks
      if tStack is not among the lines of pBefore and tStack is not "oxt_everyday" \
            and the visible of stack tStack and the mode of stack tStack is 1 then return tStack
   end repeat
   return empty
end edNewStack

function edScreenLoc pObject, pStack
   return (item 1 of the loc of pObject + the left of stack pStack) & "," & (item 2 of the loc of pObject + the top of stack pStack)
end edScreenLoc

-- a window past the screen's bottom moves up (the runners' screens are
-- small)
command edOnScreen pStack
   local tScreen, tRect, tUp
   put the working screenRect into tScreen
   put the effective rect of stack pStack into tRect
   put min(item 4 of tRect - item 4 of tScreen, item 2 of tRect - item 2 of tScreen) into tUp
   if tUp > 0 then set the top of stack pStack to the top of stack pStack - tUp
end edOnScreen

command edShotStack pStack, pFile
   if pStack is empty or there is not a stack pStack then throw "no stack" && pStack && "for" && pFile
   if the mode of stack pStack is 0 or not the visible of stack pStack then throw "the stack" && pStack && "is not open for" && pFile
   edOnScreen pStack
   edShotRect the effective rect of stack pStack, pFile
end edShotStack

command edShotScreen pFile
   local tRect
   put the screenRect into tRect
   edShotRect tRect, pFile, ((item 3 of tRect - item 1 of tRect) div 2) & "," & ((item 4 of tRect - item 2 of tRect) div 2)
end edShotScreen

command edUnlockScreen pWhat
   if the lockScreen then
      edRecord "INFO" && pWhat & ": the screen was locked"
      repeat while the lockScreen
         unlock screen
      end repeat
   end if
end edUnlockScreen

command edShotRect pRect, pFile, pSize
   local tFile, tScreen
   edUnlockScreen pFile
   edPause 200
   put the screenRect into tScreen
   put max(item 1 of pRect, item 1 of tScreen) into item 1 of pRect
   put max(item 2 of pRect, item 2 of tScreen) into item 2 of pRect
   put min(item 3 of pRect, item 3 of tScreen) into item 3 of pRect
   put min(item 4 of pRect, item 4 of tScreen) into item 4 of pRect
   if item 3 of pRect <= item 1 of pRect or item 4 of pRect <= item 2 of pRect then throw "nothing of" && pFile && "is on the screen"
   put sOut & slash & "everyday-" & pFile & ".png" into tFile
   if pSize is empty then
      export snapshot from rect pRect to file tFile as PNG
   else
      export snapshot from rect pRect at size pSize to file tFile as PNG
   end if
   if there is not a file tFile then throw "the snapshot" && pFile && "was not written (" & the result & ")"
   edRecord "SHOT everyday-" & pFile & ".png" && pRect
end edShotRect

-- A task still running after 30 seconds (a dialog it waits on): the
-- screen, and its modal dialogs closed
on edWatchdog pTask
   local tError
   add 1 to sWatchdogCount
   edRecord "INFO" && pTask && "still running after" && 30 * sWatchdogCount && "s; open stacks:" && edJoin(the openStacks)
   try
      edShotScreen "zz-" & pTask & "-" & sWatchdogCount
   catch tError
   end try
   edCloseDialogs true
   if sWatchdogCount < 4 then
      send "edWatchdog" && quote & pTask & quote to me in 30 seconds
      put the result into sWatchdog
   end if
end edWatchdog

command edCloseDialogs pAnyModal
   local tName
   repeat for each item tName in "Answer Dialog,Ask Dialog,File Selector"
      if there is a stack tName and the mode of stack tName is not 0 then
         edRecord "INFO closing" && tName
         close stack tName
      end if
   end repeat
   if pAnyModal is true then
      repeat for each line tName in the openStacks
         if there is a stack tName and the mode of stack tName is among the items of "5,6" then
            edRecord "INFO closing the modal stack" && tName
            close stack tName
         end if
      end repeat
   end if
end edCloseDialogs

command edRecord pLine
   put textEncode(pLine & lf, "UTF-8") after URL ("binfile:" & sLog)
end edRecord

function edJoin pText
   replace return with " | " in pText
   return pText
end edJoin
