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

constant kTasks = "start,new-stack,make-button,make-field,make-checkbox,make-radio,make-option-menu,make-scrollbar,make-graphic,make-label,inspector-name,inspector-label,inspector-colour,inspector-text-size,inspector-stack-name,script-type-apply,script-compile-error,script-fix-apply,browse-runs-it,message-box-line,message-box-lines,select-move-undo,undo-twice-redoes,delete-undo,copy-paste,duplicate,group,ungroup,align,new-card,project-browser-cards,go-card,delete-card,save-as,appbrowser-open,appbrowser-expand,appbrowser-select,appbrowser-script,appbrowser-collapse,close-reopen,save-again,revert-to-saved,se-find-replace,debug-breakpoint,dictionary-search,import-image,image-as-icon,geometry-manager,preferences-change,finish"
-- (the names the tasks give what they make)
constant kStack = "Everyday Stack"
constant kFile = "everyday.oxtstack"

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
   local tTask, tHandler, tError, tWanted
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
      end try
      cancel sWatchdog
      put empty into sReport
      put empty into sSkip
      edUnlockScreen tTask
      edCloseDialogs
   end repeat
   edRecord "DONE"
end edRun

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
-- whether the system's mouse reaches the IDE here
on ed_start
   put specialFolderPath("temporary") & "/oxt-everyday-" & the milliseconds into sWork
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
   if the effective filename of stack sStack is not tPath then throw "the stack's file is" && the effective filename of stack sStack & ", not" && tPath
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
   -- (the field's place for a line can be empty for a moment while the
   -- browser lays it out again)
   get edWaitFor("the number of items of edABNameRect(pAx) is 4", 2000, pLine)
   put edABNameRect(pLine) into tRect
   if the number of items of tRect is not 4 then
      throw "no place for line" && pLine && "of the App Browser's tree (the card" && the short name of this card of stack kAB & "):" && edJoin(the text of edABTree())
   end if
   edRealClickAt kAB, ((item 1 of tRect + item 3 of tRect) div 2) & "," & ((item 2 of tRect + item 4 of tRect) div 2)
end edABClickName

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
   -- (the menu is a popup: its second item picked with the arrow keys,
   -- as a person can)
   send "edABPickSecond" to me in 1200 milliseconds
   edRealClickAt kAB, tLoc, 3
   if not edWaitFor("edStackNamed(" & quote & "revNewScriptEditor" & quote & ") is not empty", 5000) then
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

on edABPickSecond
   put "picked" into sReport["popup"]
   edSystemKeys "Down,Down,Return"
end edABPickSecond

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
   send "edAnswerWith" && quote & "OK" & quote to me in 300 milliseconds
   edMenu "File", "Close and Remove From Memory"
   -- (the mainStacks, not "there is a stack": asked about a stack that
   -- is not in memory, the engine reads it from its file)
   if not edWaitFor("not edInMemory(sStack)", 5000) then
      throw "File > Close and Remove From Memory left the stack in memory (open:" && edJoin(the openStacks) & "; the question:" && sReport["answer"] & ")"
   end if
   -- the App Browser (opened by the tasks before) no longer lists it once
   -- its Refresh is clicked: it is not told of a stack removed, and lists
   -- what is in memory when refreshed
   if edOpen(kAB) then
      edClickAt kAB, the loc of button "Refresh" of group "Cards" of this card of stack kAB
      if not edWaitFor("edABLine(pAx, 0) is 0", 3000, kStack) then
         throw "the App Browser, refreshed, still lists the stack removed:" && edJoin(the text of edABTree())
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

-- the Script Editor's Edit > Find and Replace: Current Tab picked as
-- where, a word typed into Find and its replacement into Replace, and
-- Replace All clicked: the script has the new word, and Apply gives the
-- button it
on ed_se_find_replace
   local tSE, tButton, tField, tFind
   put edOkay() into tButton
   put edOpenScript(tButton) into tSE
   put edSeField(tSE) into tField
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
-- Cmd+A) and pText typed
command edTypeInCombo pStack, pCombo, pText
   local tCombo
   put the long id of button pCombo of card "Main" of stack pStack into tCombo
   edClickAt pStack, (the left of tCombo + 30) & "," & item 2 of the loc of tCombo
   edType pStack, "a", "command"
   edType pStack, pText
   if the label of tCombo is not pText then throw "typing in" && pCombo && "gave" && quote & the label of tCombo & quote
end edTypeInCombo

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
   edGutterClick tSE, 4
   put the breakpoints into sDebug["breakpoints"]
   edRecord "INFO the breakpoints:" && edJoin(sDebug["breakpoints"])
   if sDebug["breakpoints"] is empty then throw "the Script Editor set no breakpoint"
   edToolTile "com.livecode.tool.Browse"
   dispatch "revSetTestEnvironment" to stack "Home" with false
   put empty into sDebug["seen"]
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
   if sSaved["systemFileSelector"] is not empty then set the systemFileSelector to sSaved["systemFileSelector"]
   if sSaved["typingRate"] is not empty then set the typingRate to sSaved["typingRate"]
   edToolFilter empty
   edShotScreen "99-screen-end"
end ed_finish

----------------------------------------------------------------
-- Making a control from the Tools palette

-- The tile pType ("com.livecode.interface.classic." & pType) dragged
-- onto the stack: a new control of pWord (button, field, ...) where it
-- was dropped, selected, with the Pointer tool still chosen
command edMake pType, pWord, pShot
   local tTile, tCount, tTo, tNew, tVia
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
      edSystemDrag edScreenLoc(tTile, "revTools"), (item 1 of tTo + the left of stack sStack) & "," & (item 2 of tTo + the top of stack sStack)
   else
      put "a double-click on its tile (the system's mouse does not reach the IDE)" into tVia
      send "mouseDoubleUp 1" to tTile
   end if
   if not edWaitFor("the number of controls of card 1 of stack sStack is pAx + 1", 6000, tCount) then
      throw "the" && pType && "tile made nothing on the stack (" & tVia & ")"
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
   get edWaitFor("edTileShown(" & quote & "com.livecode.interface.classic." & pText & quote & ")", 2000)
end edToolFilter

function edTile pName
   if there is not a button pName of stack "revTools" then return empty
   return the long id of button pName of stack "revTools"
end edTile

function edTileShown pName
   local tTile
   put edTile(pName) into tTile
   if tTile is empty then return false
   return the visible of tTile and the top of tTile >= 0 and the bottom of tTile <= the height of stack "revTools"
end edTileShown

-- a tool's tile (Run or Edit) clicked
command edToolTile pName
   local tTile
   put edTile(pName) into tTile
   if tTile is empty then
      -- (the classic look names them otherwise; the tool chosen as its
      -- tiles do)
      if pName ends with "Browse" then revIDEChooseBrowseTool
      else revIDEChoosePointerTool
      exit edToolTile
   end if
   edClickAt "revTools", the loc of tTile
end edToolTile

-- The system's mouse pressed at pFrom, moved in steps to pTo and released
-- there (screen points), while the engine handles each event as it comes:
-- the command runs on its own, and this waits for it
command edSystemDrag pFrom, pTo
   local tSteps, tCommand, tScript, i, tX, tY, tMoves
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
         put "osascript -l JavaScript -e " & quote & tScript & quote & " >/dev/null 2>&1 &" into tCommand
         get shell(tCommand)
         break
      case "Win32"
         put "Add-Type -Namespace OxtEd -Name Mouse -MemberDefinition '" & \
               "[DllImport(" & quote & "user32.dll" & quote & ")] public static extern bool SetCursorPos(int x, int y); " & \
               "[DllImport(" & quote & "user32.dll" & quote & ")] public static extern void mouse_event(int f, int x, int y, int d, int e);'" & return & \
               "Start-Sleep -Milliseconds 300" & return & \
               "[OxtEd.Mouse]::SetCursorPos(" & pFrom & ") | Out-Null" & return & \
               "Start-Sleep -Milliseconds 150" & return & \
               "[OxtEd.Mouse]::mouse_event(2, 0, 0, 0, 0)" & return into tScript
         set the itemDelimiter to ";"
         repeat for each item i in tMoves
            put "Start-Sleep -Milliseconds 150" & return & "[OxtEd.Mouse]::SetCursorPos(" & i & ") | Out-Null" & return after tScript
         end repeat
         set the itemDelimiter to comma
         put "Start-Sleep -Milliseconds 200" & return & "[OxtEd.Mouse]::mouse_event(4, 0, 0, 0, 0)" after tScript
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
         put " sleep 0.2 mouseup 1) >/dev/null 2>&1 &" after tCommand
         get shell(tCommand)
         break
   end switch
   -- (the caller waits for what the drag makes)
end edSystemDrag

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
on edAnswerWith pButton, pTries
   local tAD, tButton, i
   put "Answer Dialog" into tAD
   if pTries is empty then put 0 into pTries
   if not (there is a stack tAD and the mode of stack tAD is not 0 and the visible of stack tAD) then
      if pTries < 30 then send "edAnswerWith" && quote & pButton & quote & "," && pTries + 1 to me in 200 milliseconds
      exit edAnswerWith
   end if
   put the text of field 1 of card 1 of stack tAD into sReport["answer"]
   repeat with i = 1 to the number of buttons of card 1 of stack tAD
      if the visible of button i of card 1 of stack tAD and the short name of button i of card 1 of stack tAD is pButton then
         put the long id of button i of card 1 of stack tAD into tButton
      end if
   end repeat
   try
      edShotStack tAD, "zz-answer-" & toLower(pButton)
   catch tError
   end try
   if tButton is empty then
      put " (no button" && pButton & ")" after sReport["answer"]
      close stack tAD
      exit edAnswerWith
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
command edRealClickAt pStack, pLoc, pButton
   local tScreen, tCommand, tScript
   if pButton is empty then put 1 into pButton
   if sInput is not true then
      if pButton is 3 then
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
         put base64Encode(textEncode(tScript, "UTF-16LE")) into tScript
         replace return with empty in tScript
         launch "powershell -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand" && tScript
         break
      default
         get shell("(sleep 0.3; xdotool mousemove" && item 1 of tScreen && item 2 of tScreen && "sleep 0.15 click 3) >/dev/null 2>&1 &")
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
-- Up, Return, Escape (for a menu open now)
command edSystemKeys pKeys
   local tKey, tCommand, tCodes
   switch the platform
      case "MacOS"
         repeat for each item tKey in pKeys
            switch tKey
               case "Down"
                  put "125," after tCodes
                  break
               case "Up"
                  put "126," after tCodes
                  break
               case "Return"
                  put "36," after tCodes
                  break
               case "Escape"
                  put "53," after tCodes
                  break
            end switch
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
            if tKey is "Return" then put "ENTER" into tKey
            if tKey is "Escape" then put "ESC" into tKey
            put "[System.Windows.Forms.SendKeys]::SendWait('{" & toUpper(tKey) & "}'); Start-Sleep -Milliseconds 150" & return after tCommand
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
