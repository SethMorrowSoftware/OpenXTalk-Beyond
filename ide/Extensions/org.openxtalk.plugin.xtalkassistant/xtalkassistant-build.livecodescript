script "org.openxtalk.plugin.xtalkassistant-build"
-- OXT-Beyond: what the xTalk Assistant does to the user's stacks once the
-- user says yes: the changes it makes (its make_changes tool), the code it
-- runs (run_code), and what it reads of a script paused in the debugger
-- (debug_state). The plugin's main stack loads this with "start using"
-- when the assistant is turned on, as it loads the core, and asks the user
-- before it calls anything here that changes or runs something: nothing
-- here asks. It needs no IDE, so the engine tests in
-- tests/lcs/xtalkassistant/build.livecodescript load it the same way.
--
-- Changes. The model sends a batch of changes to one stack: create a
-- control, a card or a stack; set properties, custom properties and
-- scripts; delete a control or a card. xtaBuildPlan checks the whole batch
-- before the user sees it, so that a mistake goes back to the model rather
-- than to the user: every property is one the engine knows (a misspelt
-- one would quietly become a custom property), every value is first set
-- on a stand-in (a copy of the object, or a new one of its kind, in a
-- hidden stack made for the check), so that a value the engine refuses is
-- found then, and every script compiles and is made of handlers.
-- xtaBuildApply makes the changes with messages locked, as the IDE makes
-- an object from the Tools palette (revIDECreateObject), so that none of
-- the user's handlers runs meanwhile, then tells the IDE (ideNewControl and
-- the others) so that the Project Browser keeps up. If a change fails, the
-- changes made before it are taken back: a batch is made whole or not at
-- all.
--
-- The journal. Each batch applied is an entry, and each entry can be
-- undone, newest first, until the assistant is turned off: a created
-- object is deleted; a changed object gets back every property, custom
-- property and its script as they were; a deleted object, kept as a copy
-- in a hidden stack, is copied back with its ids and its layer. An entry
-- remembers how it left each object, and Undo says when the user changed
-- one since (the plugin then asks before it undoes).
--
-- Runs. Code runs in a sandbox, a hidden stack made for the run and
-- deleted after it, or in the user's stack after a checkpoint: the stack's
-- file saved as a copy, which Undo reverts the stack to. Either way the run
-- is a "send" inside try, so an error comes back here rather than to the
-- debugger, with what the code put into the Message Box and what it
-- returned. A run that never ends is stopped only by the engine's
-- interrupt (Control-period, Command-period on a Mac). What a run does
-- outside the stack (files, the network, other programs) cannot be undone;
-- xtaRiskScan names it, so that the user is told before.
--
-- The debugger. While a script of the user's is paused, at a breakpoint
-- or an error with Script Debug Mode on, xtaDebugState reads where it is,
-- the handlers that called it and their variables, through the engine's
-- debugContext, as the IDE's debugger does (revdebuggerlibrary). It only
-- reads. Stepping stays the user's: the assistant's own handlers run
-- inside the debugger's pause, and a step would only happen after they
-- return.
--
-- Two findings about this engine shape the code: "relayer" hangs it, so a
-- layer is put back with "set the layer" and the relayerGroupedControls;
-- and "revert" while the stack is the defaultStack crashes it at the next
-- "there is a stack", so the defaultStack is moved away first.
--
-- Public handlers:
--    xtaBuildPlan(pInput, pStack)     a make_changes batch, checked
--    xtaBuildApply(pPlan)             makes it, all or nothing
--    xtaBuildUndo(pEntry, pForce), xtaBuildUndoAll(pForce)
--    xtaBuildEntries()                the journal, for the window
--    xtaRunPlan(pInput, pStack), xtaRunCode(pRun), xtaRiskScan(pCode)
--    xtaCheckpointSave(pStack), xtaCheckpointRestore(pPath, pStack)
--    xtaDebugState()                  a paused script, for the model
--    xtaStackDump(pStack)             a stack as text, to compare
--    xtaTargetStack(pName, pDefault)  the stack a tool names, checked
--    xtaKeepOnScreen pStack, pShrink  a window moved whole onto the screen
--    xtaOnScreenRect(pRect, pFrame, pArea, pMin)   where it goes
--    xtaThrownText(pError)           an error thrown, in words
--    xtaBuildCleanup                  forgets all of it (turning off)

-- The hidden stacks made here; their names begin with "rev", so the IDE
-- takes them for its own: the copies of deleted objects, the stand-ins of
-- the checks, and the sandbox
constant kHoldStack = "revXTalkAssistantJournal"
constant kStandInStack = "revXTalkAssistantStandIn"
constant kSandboxStack = "revXTalkAssistantSandbox"
-- The handler a sandbox run's statements are put in
constant kRunHandler = "xtaSandboxRun"
-- The most changes in one batch
constant kMaxChanges = 100
-- What a change may not set as a property: what the engine keeps (ids),
-- what has keys of its own in a change (the script, custom properties),
-- and what would lock the user out, or move or join stacks
constant kRefusedProperties = "id,altId,script,properties,customProperties,customPropertySet,customPropertySets,customKeys,password,key,passKey,cantModify,mainStack,substacks,stackFiles,owner,externals,fileName"
-- What is set on the real object only: it depends on the objects around
-- it, or would load a file
constant kNotOnStandIn = "layer,number,defaultButton"
-- The most text of one value, of what a run put into the Message Box and
-- of what it returned, given back to the model
constant kMaxValueChars = 2000
constant kMaxOutputChars = 4000
-- The variables of a paused handler shown, the keys of an array, and the
-- handlers whose variables are read (from the innermost)
constant kMaxVariables = 40
constant kMaxKeys = 20
constant kMaxDebugContexts = 2
-- The execution error whose hint names the object the lines before it
-- were in
constant kObjectNameError = 353

-- The execution errors of a script that was stopped while it ran (the
-- user pressed Control-period, Command-period on a Mac): repeat, wait,
-- do, read, shell, click, drag, move, type, if and a handler, "aborted"
constant kAbortErrors = "98,160,171,240,251,324,470,488,538,604,624"

-- The journal: entries 1 to N, each an array with "number", "kind"
-- ("changes" or "run"), "state" ("applied" or "undone"), "main" (the name
-- of the main stack it changed), "stack" (the long id of the stack),
-- "summary" (a line for the user), "steps" (what to undo, in order),
-- "prints" (how it left each object, by long id), "before" (how the
-- objects of the entries before it on the same stack were when it was
-- made, by long id), and for a run "checkpoint" (the file it reverts to)
local sJournal
-- This session's folder of checkpoints, and how many it has
local sCheckpointFolder, sCheckpointCount

--------------------------------------------------------------------------------
-- The kinds of object a change creates
--
-- The model names what it wants as the Tools palette does ("checkbox",
-- "text area", "round rectangle"...). Each kind is an engine type, the
-- properties the IDE gives it (the "Default" column of its file in
-- ide/Toolset/resources/supporting_files/property_definitions, without the
-- sample text), its size when no rect is given, and its name when none is.

private function xtbKinds
   local tKinds
   xtbKind tKinds, "button", "button", "style=standard", 82, 23, "Button"
   xtbKind tKinds, "default button", "button", "style=standard;default=true", 82, 23, "Button"
   xtbKind tKinds, "checkbox", "button", "style=checkbox;opaque=false;showBorder=false;hiliteBorder=false", 120, 23, "Check"
   xtbKind tKinds, "radio button", "button", "style=radioButton;opaque=false;hiliteBorder=false", 120, 23, "Radio"
   xtbKind tKinds, "option menu", "button", "style=menu;menuMode=option", 120, 22, "Option Menu"
   xtbKind tKinds, "pulldown menu", "button", "style=menu;menuMode=pulldown;textAlign=left", 102, 22, "Pulldown Menu"
   xtbKind tKinds, "popup menu", "button", "style=menu;menuMode=popup", 102, 22, "Popup Menu"
   xtbKind tKinds, "combo box", "button", "style=menu;menuMode=comboBox", 120, 22, "Combo Box"
   xtbKind tKinds, "tab panel", "button", "style=menu;menuMode=tabbed", 234, 144, "Tab Menu"
   xtbKind tKinds, "field", "field", empty, 160, 23, "Field"
   xtbKind tKinds, "text area", "field", "vScrollbar=true", 250, 120, "Field"
   xtbKind tKinds, "label", "field", "lockText=true;opaque=false;showBorder=false;dontWrap=true;traversalOn=false;autoHilite=false", 100, 21, "Label"
   xtbKind tKinds, "list field", "field", "lockText=true;listBehavior=true;vScrollbar=true;autoHilite=true", 250, 120, "List"
   xtbKind tKinds, "table field", "field", "lockText=true;dontWrap=true;vScrollbar=true;basicTableObject=true;cellEdit=true;hGrid=true;vGrid=true;tabStops=75;fixedLineHeight=true", 250, 120, "Table"
   xtbKind tKinds, "rectangle", "graphic", "style=rectangle;opaque=true", 120, 120, "Rectangle"
   xtbKind tKinds, "round rectangle", "graphic", "style=roundRect;opaque=true;roundRadius=15", 120, 120, "Round Rectangle"
   xtbKind tKinds, "oval", "graphic", "style=oval;opaque=true", 120, 120, "Oval"
   xtbKind tKinds, "line", "graphic", "style=line", 120, 20, "Line"
   xtbKind tKinds, "polygon", "graphic", "style=polygon", 100, 100, "Polygon"
   xtbKind tKinds, "regular polygon", "graphic", "style=regular;polySides=8;opaque=true", 100, 100, "Regular Polygon"
   xtbKind tKinds, "curve", "graphic", "style=curve", 100, 100, "Curve"
   xtbKind tKinds, "scrollbar", "scrollbar", "style=scrollbar", 200, 20, "Scrollbar"
   xtbKind tKinds, "slider", "scrollbar", "style=scale;showValue=true;startValue=0;endValue=100;thumbPosition=0", 160, 38, "Slider"
   xtbKind tKinds, "progress bar", "scrollbar", "style=progress;startValue=0;endValue=100;thumbPosition=0", 200, 16, "Progress"
   xtbKind tKinds, "image", "image", empty, 120, 120, "Image"
   xtbKind tKinds, "player", "player", "showController=true", 310, 264, "Player"
   xtbKind tKinds, "group", "group", empty, 0, 0, "Group"
   xtbKind tKinds, "widget", "widget", empty, 160, 160, "Widget"
   xtbKind tKinds, "card", "card", empty, 0, 0, empty
   xtbKind tKinds, "stack", "stack", empty, 0, 0, empty
   return tKinds
end xtbKinds

private command xtbKind @xKinds, pKind, pType, pProperties, pWidth, pHeight, pName
   put pType into xKinds[pKind]["type"]
   put pProperties into xKinds[pKind]["properties"]
   put pWidth into xKinds[pKind]["width"]
   put pHeight into xKinds[pKind]["height"]
   put pName into xKinds[pKind]["name"]
end xtbKind

-- A kind as the model wrote it, as xtbKinds names it ("Check_Box" is
-- "checkbox"), or empty
private function xtbKindName pKind
   put toLower(word 1 to -1 of pKind) into pKind
   replace "_" with space in pKind
   replace "-" with space in pKind
   put word 1 to -1 of pKind into pKind
   repeat while pKind contains "  "
      replace "  " with space in pKind
   end repeat
   switch pKind
      case "push button"
      case "standard button"
         return "button"
      case "check box"
         return "checkbox"
      case "radio"
      case "radiobutton"
         return "radio button"
      case "menu"
      case "option"
      case "optionmenu"
         return "option menu"
      case "pulldown"
         return "pulldown menu"
      case "popup"
         return "popup menu"
      case "combobox"
      case "combo"
         return "combo box"
      case "tabs"
      case "tab"
      case "tabbed"
      case "tab menu"
         return "tab panel"
      case "text field"
      case "entry field"
      case "input"
         return "field"
      case "scrolling field"
      case "textarea"
         return "text area"
      case "label field"
         return "label"
      case "list"
      case "scrolling list"
      case "scrolling list field"
         return "list field"
      case "table"
         return "table field"
      case "rect"
         return "rectangle"
      case "roundrect"
      case "round rect"
      case "rounded rectangle"
         return "round rectangle"
      case "ellipse"
      case "circle"
         return "oval"
      case "regular"
         return "regular polygon"
      case "scale"
         return "slider"
      case "progress"
      case "progressbar"
         return "progress bar"
      case "substack"
         return empty
   end switch
   return pKind
end xtbKindName

-- The kinds, for a message to the model
private function xtbKindList
   local tKinds, tList, tKind
   put xtbKinds() into tKinds
   repeat for each key tKind in tKinds
      put tKind & return after tList
   end repeat
   sort lines of tList
   replace return with ", " in tList
   return char 1 to -3 of tList
end xtbKindList

--------------------------------------------------------------------------------
-- Planning a batch
--
-- A batch is a JSON object: "stack" (the name of the stack, or of one of
-- its substacks; empty for the one the user works on) and "changes", in
-- order. Each change has "action":
--    create   "kind" (xtbKinds), "name", "ref" (a word the later changes of
--             the batch name it by), "card" (an id, a ref or a card's name;
--             the current card when none), "group" (an id or a ref),
--             "rect" (left, top, right, bottom), "widget_kind",
--             "properties", "custom_properties", "script". A kind "stack"
--             is the first change of its batch, and the batch is in it; a
--             kind "card" goes after the stack's current card.
--    set      "object" (an id, "stack" or a ref), "properties",
--             "custom_properties", "script"
--    delete   "object" (an id or a ref): a control, or a card
-- A value may be a JSON string, number or boolean; a list of numbers is
-- the items of one value ([10, 10, 100, 30] is "10,10,100,30"), a list of
-- lists is its lines (points), and an object is an array (dropShadow).
--
-- Returns an array: "ok", "problems" (one per line, for the model; empty
-- when ok), "changes" (each checked and in the form xtaBuildApply takes),
-- "stack" (the long id of the stack; empty when the batch makes it),
-- "newStack" (true when it does), "name" (the stack's name), "count" and
-- "lines" (what each change does, one per line, for the user).

function xtaBuildPlan pInput, pStack
   local tPlan, tChanges, tCount, tIndex, tChange, tRefs, tProblems, tTarget, tFirst, tProblem
   put false into tPlan["ok"]
   put false into tPlan["newStack"]
   put xtaJsonMember(pInput, "changes") into tChanges
   if xtaJsonType(tChanges) is not "array" or xtaJsonCount(tChanges) is 0 then
      put "Give the changes as a list (changes), with one change at least." into tPlan["problems"]
      return tPlan
   end if
   put xtaJsonCount(tChanges) into tCount
   if tCount > kMaxChanges then
      put "A batch has" && kMaxChanges && "changes at most, and this one has" && tCount & ": send it in parts." into tPlan["problems"]
      return tPlan
   end if
   put tCount into tPlan["count"]
   -- The stack: a new one when the batch begins by making it, else the one
   -- named, else the one the user is working on
   put xtaJsonItem(tChanges, 1) into tFirst
   if toLower(word 1 to -1 of xtaJsonText(xtaJsonMember(tFirst, "action"))) is "create" and \
         xtbKindName(xtaJsonText(xtaJsonMember(tFirst, "kind"))) is "stack" then
      put true into tPlan["newStack"]
      put word 1 to -1 of xtaJsonText(xtaJsonMember(tFirst, "name")) into tPlan["name"]
   else
      put xtbTargetStack(xtaJsonText(xtaJsonMember(pInput, "stack")), pStack) into tTarget
      if tTarget["problem"] is not empty then
         put tTarget["problem"] into tPlan["problems"]
         return tPlan
      end if
      put tTarget["stack"] into tPlan["stack"]
      put the short name of tTarget["stack"] into tPlan["name"]
   end if
   repeat with tIndex = 1 to tCount
      put xtbPlanChange(xtaJsonItem(tChanges, tIndex), tIndex, tPlan, tRefs) into tChange
      put tChange into tPlan["changes"][tIndex]
      if tChange["problem"] is not empty then
         put "change" && tIndex & ":" && tChange["problem"] & return after tProblems
      end if
   end repeat
   -- Each value, set first on a stand-in
   if tProblems is empty then
      repeat with tIndex = 1 to tCount
         put xtbTryOnStandIn(tPlan["changes"][tIndex], tPlan, tRefs) into tProblem
         if tProblem is not empty then
            put "change" && tIndex & ":" && tProblem & return after tProblems
         end if
      end repeat
      xtbStandInCleanup
   end if
   if tProblems is not empty then
      delete the last char of tProblems
      put tProblems into tPlan["problems"]
      return tPlan
   end if
   repeat with tIndex = 1 to tCount
      put tPlan["changes"][tIndex]["label"] & return after tPlan["lines"]
   end repeat
   delete the last char of tPlan["lines"]
   put true into tPlan["ok"]
   return tPlan
end xtaBuildPlan

-- The stack a batch or a run is in: pName (the main stack's name, a
-- substack's of it, or another stack's open in the IDE), else pDefault
-- (the long id of the main stack the user works on). An array with
-- "stack" (its long id), or "problem". (xtaTargetStack: the same, for the
-- plugin's tools that save a stack and look at a card.)
function xtaTargetStack pName, pDefault
   return xtbTargetStack(pName, pDefault)
end xtaTargetStack

private function xtbTargetStack pName, pDefault
   local tResult, tMain, tStack, tSub
   put word 1 to -1 of pName into pName
   if pDefault is not empty then
      if there is a pDefault then
         put the long id of pDefault into tMain
      end if
   end if
   if pName is empty then
      if tMain is empty then
         put "No stack of the user's is open. Begin the batch by creating one (kind" && quote & "stack" & quote & \
               "), or ask the user to open theirs." into tResult["problem"]
         return tResult
      end if
      put tMain into tStack
   else if tMain is not empty and pName is the short name of tMain then
      put tMain into tStack
   else
      if tMain is not empty then
         repeat for each line tSub in the substacks of tMain
            if tSub is pName then
               put the long id of stack tSub of tMain into tStack
               exit repeat
            end if
         end repeat
      end if
      if tStack is empty and there is a stack pName then
         put the long id of stack pName into tStack
      end if
      if tStack is empty then
         put "There is no stack named" && quote & pName & quote && "open." into tResult["problem"]
         return tResult
      end if
   end if
   if xtbIsIDEStack(tStack) then
      put "The stack" && quote & the short name of tStack & quote && "is one of the IDE's; the assistant changes only the user's stacks." \
            into tResult["problem"]
      return tResult
   end if
   if xtbIsProtected(tStack) then
      put "The stack" && quote & the short name of tStack & quote && "is password-protected, so the assistant does not change or run it." \
            into tResult["problem"]
      return tResult
   end if
   put tStack into tResult["stack"]
   return tResult
end xtbTargetStack

-- One change, checked: an array as xtaBuildApply takes it, with "problem"
-- when it cannot be made. xRefs has, by ref, the objects the changes
-- before it create ("type", "name", "change").
private function xtbPlanChange pNode, pIndex, @xPlan, @xRefs
   local tChange, tAction
   if xtaJsonType(pNode) is not "object" then
      put "a change is an object with an action (create, set or delete)" into tChange["problem"]
      return tChange
   end if
   put toLower(word 1 to -1 of xtaJsonText(xtaJsonMember(pNode, "action"))) into tAction
   put tAction into tChange["action"]
   switch tAction
      case "create"
         xtbPlanCreate pNode, pIndex, xPlan, xRefs, tChange
         break
      case "set"
         xtbPlanSet pNode, xPlan, xRefs, tChange
         break
      case "delete"
         xtbPlanDelete pNode, xPlan, xRefs, tChange
         break
      default
         put "the action is create, set or delete, not" && quote & tAction & quote into tChange["problem"]
   end switch
   return tChange
end xtbPlanChange

private command xtbPlanCreate pNode, pIndex, @xPlan, @xRefs, @xChange
   local tKinds, tKind, tType, tRef, tWidgetKind, tRect, tRectNode
   put xtbKinds() into tKinds
   put xtbKindName(xtaJsonText(xtaJsonMember(pNode, "kind"))) into tKind
   if tKind is empty or tKinds[tKind]["type"] is empty then
      put "there is no kind" && quote & xtaJsonText(xtaJsonMember(pNode, "kind")) & quote & "; the kinds are" && xtbKindList() into xChange["problem"]
      exit xtbPlanCreate
   end if
   put tKind into xChange["kind"]
   put tKinds[tKind]["type"] into tType
   put tType into xChange["type"]
   put word 1 to -1 of xtaJsonText(xtaJsonMember(pNode, "name")) into xChange["name"]
   if xChange["name"] contains return or xChange["name"] contains quote then
      put "a name is one line, without double quotes" into xChange["problem"]
      exit xtbPlanCreate
   end if
   if tType is "stack" then
      if pIndex is not 1 then
         put "a new stack is made by the first change of its batch, and the batch is then in it" into xChange["problem"]
         exit xtbPlanCreate
      end if
      if xChange["name"] is empty then
         put "a new stack needs a name" into xChange["problem"]
         exit xtbPlanCreate
      end if
      if there is a stack xChange["name"] then
         put "a stack named" && quote & xChange["name"] & quote && "is open already: choose another name" into xChange["problem"]
         exit xtbPlanCreate
      end if
   else if xChange["name"] is empty then
      put tKinds[tKind]["name"] into xChange["name"]
   end if

   put word 1 to -1 of xtaJsonText(xtaJsonMember(pNode, "ref")) into tRef
   if tRef is not empty then
      if not matchText(tRef, "^[A-Za-z_][A-Za-z0-9_]*$") then
         put "a ref is one word of letters, digits and _" into xChange["problem"]
         exit xtbPlanCreate
      end if
      if xRefs[tRef]["type"] is not empty then
         put "the ref" && quote & tRef & quote && "is given twice" into xChange["problem"]
         exit xtbPlanCreate
      end if
      put tRef into xChange["ref"]
   end if

   if tType is "widget" then
      put word 1 to -1 of xtaJsonText(xtaJsonMember(pNode, "widget_kind")) into tWidgetKind
      if tWidgetKind is empty then
         put "a widget needs its widget_kind, such as com.livecode.widget.svgpath" into xChange["problem"]
         exit xtbPlanCreate
      end if
      if not (tWidgetKind is among the lines of the loadedExtensions) then
         put "the widget kind" && quote & tWidgetKind & quote && "is not installed. Installed:" && xtbWidgetKinds() into xChange["problem"]
         exit xtbPlanCreate
      end if
      put tWidgetKind into xChange["widgetKind"]
   end if

   if tType is not "stack" and tType is not "card" then
      xtbPlanContainer pNode, xPlan, xRefs, xChange
      if xChange["problem"] is not empty then
         exit xtbPlanCreate
      end if
   end if

   put xtaJsonMember(pNode, "rect") into tRectNode
   if xtaJsonType(tRectNode) is not "missing" and xtaJsonType(tRectNode) is not "null" then
      if tType is "card" then
         put "a card has no rect of its own: set the stack's width and height" into xChange["problem"]
         exit xtbPlanCreate
      end if
      put xtbRect(xtbValue(tRectNode)) into tRect
      if tRect is empty then
         put "a rect is four whole numbers: left, top, right, bottom (right more than left, bottom more than top)" into xChange["problem"]
         exit xtbPlanCreate
      end if
      put tRect into xChange["rect"]
   end if

   xtbPlanValues pNode, tType, xChange
   if xChange["problem"] is not empty then
      exit xtbPlanCreate
   end if
   if tRef is not empty then
      put tType into xRefs[tRef]["type"]
      put xChange["name"] into xRefs[tRef]["name"]
      put pIndex into xRefs[tRef]["change"]
   end if
   put xtbCreateLabel(xChange, xPlan, xRefs) into xChange["label"]
end xtbPlanCreate

-- Where a new control goes: "in" is "card id N", "card ref R", "group id
-- N", "group ref R" or "first card" (of a stack the batch makes)
private command xtbPlanContainer pNode, @xPlan, @xRefs, @xChange
   local tGroupNode, tCardNode, tValue, tStack, tControl
   put xPlan["stack"] into tStack
   put xtaJsonMember(pNode, "group") into tGroupNode
   if xtaJsonType(tGroupNode) is not "missing" and xtaJsonType(tGroupNode) is not "null" then
      put word 1 to -1 of xtaJsonText(tGroupNode) into tValue
      if xRefs[tValue]["type"] is not empty then
         if xRefs[tValue]["type"] is not "group" then
            put "the ref" && quote & tValue & quote && "is a" && xRefs[tValue]["type"] & ", not a group" into xChange["problem"]
            exit xtbPlanContainer
         end if
         put "group ref" && tValue into xChange["in"]
         exit xtbPlanContainer
      end if
      if tValue is an integer and tStack is not empty then
         if there is a control id tValue of tStack then
            put the long id of control id tValue of tStack into tControl
            if word 1 of tControl is "group" then
               put "group id" && tValue into xChange["in"]
               exit xtbPlanContainer
            end if
         end if
      end if
      put "there is no group" && quote & tValue & quote && "(give a group's id, or the ref of a group this batch creates)" into xChange["problem"]
      exit xtbPlanContainer
   end if
   put xtaJsonMember(pNode, "card") into tCardNode
   if xtaJsonType(tCardNode) is "missing" or xtaJsonType(tCardNode) is "null" then
      if xPlan["newStack"] is true then
         put "first card" into xChange["in"]
      else
         put "card id" && the id of xtbCurrentCard(tStack) into xChange["in"]
      end if
      exit xtbPlanContainer
   end if
   put word 1 to -1 of xtaJsonText(tCardNode) into tValue
   if xRefs[tValue]["type"] is not empty then
      if xRefs[tValue]["type"] is not "card" then
         put "the ref" && quote & tValue & quote && "is a" && xRefs[tValue]["type"] & ", not a card" into xChange["problem"]
         exit xtbPlanContainer
      end if
      put "card ref" && tValue into xChange["in"]
      exit xtbPlanContainer
   end if
   if tStack is not empty then
      if tValue is an integer then
         if there is a card id tValue of tStack then
            put "card id" && tValue into xChange["in"]
            exit xtbPlanContainer
         end if
      else if tValue is not empty and there is a card tValue of tStack then
         put "card id" && the id of card tValue of tStack into xChange["in"]
         exit xtbPlanContainer
      end if
   end if
   put "there is no card" && quote & tValue & quote && "(give a card's id or name, or the ref of a card this batch creates)" into xChange["problem"]
end xtbPlanContainer

-- The properties, custom properties and script of a change, checked
private command xtbPlanValues pNode, pType, @xChange
   local tNames, tNode, tIndex, tRawName, tName, tCount, tScript, tCounts, tCheck, tLine
   put the propertyNames into tNames
   put xtaJsonMember(pNode, "properties") into tNode
   put 0 into tCount
   if xtaJsonType(tNode) is not "missing" and xtaJsonType(tNode) is not "null" then
      if xtaJsonType(tNode) is not "object" then
         put "properties is an object of names and values" into xChange["problem"]
         exit xtbPlanValues
      end if
      repeat with tIndex = 1 to xtaJsonCount(tNode)
         put tNode["names"][tIndex] into tRawName
         put word 1 to -1 of tRawName into tName
         if word 1 of tName is "the" then
            put word 2 to -1 of tName into tName
         end if
         if tName is "script" then
            put "a script goes in script, not in properties" into xChange["problem"]
            exit xtbPlanValues
         end if
         if tName is among the items of "customProperties,customKeys,customPropertySet,customPropertySets" then
            put "custom properties go in custom_properties" into xChange["problem"]
            exit xtbPlanValues
         end if
         if tName is "fileName" and pType is among the items of "image,player" then
            -- Where an image or a player reads its file is one of its own
            -- properties, unlike a stack's file
         else if tName is among the items of kRefusedProperties then
            put "the property" && tName && "is not one the assistant sets" into xChange["problem"]
            exit xtbPlanValues
         end if
         if tName is "name" and pType is "stack" and xChange["action"] is "set" then
            put "the assistant does not rename a stack (its other scripts would not find it); ask the user to" into xChange["problem"]
            exit xtbPlanValues
         end if
         if not (tName is among the lines of tNames) then
            put "there is no property named" && quote & tName & quote && "(a misspelt property would quietly become a custom property);" && \
                  "a custom property goes in custom_properties" into xChange["problem"]
            put xtaNearest(tName, tNames, 3) into tLine
            if tLine is not empty then
               replace return with ", " in tLine
               put "; the nearest properties are" && tLine after xChange["problem"]
            end if
            exit xtbPlanValues
         end if
         add 1 to tCount
         put tName into xChange["properties"][tCount]["name"]
         put xtbValue(tNode["members"][tRawName]) into xChange["properties"][tCount]["value"]
      end repeat
   end if

   put xtaJsonMember(pNode, "custom_properties") into tNode
   put 0 into tCount
   if xtaJsonType(tNode) is not "missing" and xtaJsonType(tNode) is not "null" then
      if xtaJsonType(tNode) is not "object" then
         put "custom_properties is an object of names and values" into xChange["problem"]
         exit xtbPlanValues
      end if
      repeat with tIndex = 1 to xtaJsonCount(tNode)
         put tNode["names"][tIndex] into tRawName
         put word 1 to -1 of tRawName into tName
         if not matchText(tName, "^[A-Za-z_][A-Za-z0-9_]*$") then
            put "a custom property's name is one word of letters, digits and _, not" && quote & tName & quote into xChange["problem"]
            exit xtbPlanValues
         end if
         if tName is among the lines of tNames then
            put tName && "is a property of the engine's: it goes in properties" into xChange["problem"]
            exit xtbPlanValues
         end if
         add 1 to tCount
         put tName into xChange["custom"][tCount]["name"]
         put xtbValue(tNode["members"][tRawName]) into xChange["custom"][tCount]["value"]
      end repeat
   end if

   put xtaJsonMember(pNode, "script") into tNode
   put false into xChange["hasScript"]
   if xtaJsonType(tNode) is not "missing" and xtaJsonType(tNode) is not "null" then
      put true into xChange["hasScript"]
      put xtaJsonText(tNode) into tScript
      replace crlf with return in tScript
      replace numToChar(13) with return in tScript
      if word 1 to -1 of tScript is not empty then
         put xtaScriptCounts(tScript) into tCounts
         if tCounts["handlers"] is 0 then
            put "a script is made of handlers (on mouseUp ... end mouseUp); these lines are outside any handler, and the engine would ignore them" \
                  into xChange["problem"]
            exit xtbPlanValues
         end if
         put xtaCheckScript(tScript, empty) into tCheck
         if tCheck["ok"] is not true then
            put "its script does not compile:" into xChange["problem"]
            repeat for each line tLine in tCheck["issues"]
               put return & "  - " & tLine after xChange["problem"]
            end repeat
            exit xtbPlanValues
         end if
      end if
      put tScript into xChange["script"]
   end if
end xtbPlanValues

private command xtbPlanSet pNode, @xPlan, @xRefs, @xChange
   xtbPlanObject pNode, xPlan, xRefs, xChange
   if xChange["problem"] is not empty then
      exit xtbPlanSet
   end if
   if xtaJsonType(xtaJsonMember(pNode, "properties")) is "missing" and xtaJsonType(xtaJsonMember(pNode, "custom_properties")) is "missing" \
         and xtaJsonType(xtaJsonMember(pNode, "script")) is "missing" then
      put "there is nothing to set: give properties, custom_properties or script" into xChange["problem"]
      exit xtbPlanSet
   end if
   xtbPlanValues pNode, xChange["objectType"], xChange
   if xChange["problem"] is not empty then
      exit xtbPlanSet
   end if
   if xChange["hasScript"] and xChange["longId"] is not empty then
      if xtbIsRunning(xChange["longId"]) then
         put "the script of" && xtbLabel(xChange["longId"]) && "is running (the debugger is paused in it, or it waits):" && \
               "ask the user to stop it (Stop, in the Script Editor), then send the change again" into xChange["problem"]
         exit xtbPlanSet
      end if
   end if
   put xtbSetLabel(xChange, xRefs) into xChange["label"]
end xtbPlanSet

private command xtbPlanDelete pNode, @xPlan, @xRefs, @xChange
   local tObject, tIndex, tControl
   xtbPlanObject pNode, xPlan, xRefs, xChange
   if xChange["problem"] is not empty then
      exit xtbPlanDelete
   end if
   if xChange["objectType"] is "stack" then
      put "the assistant does not delete stacks; ask the user to" into xChange["problem"]
      exit xtbPlanDelete
   end if
   put xChange["longId"] into tObject
   if tObject is not empty then
      if xChange["objectType"] is "card" then
         if the number of cards of xtbStackOf(tObject) is 1 then
            put "a stack keeps one card at least" into xChange["problem"]
            exit xtbPlanDelete
         end if
         -- A group the card shares with other cards would come back as a
         -- copy of its own, not as the same group
         repeat with tIndex = 1 to the number of groups of tObject
            put the long id of group tIndex of tObject into tControl
            if the number of lines of the cardIds of tControl > 1 then
               put "the card shows the group" && quote & the short name of tControl & quote && "that other cards show too;" && \
                     "the assistant does not delete such a card: ask the user to" into xChange["problem"]
               exit xtbPlanDelete
            end if
         end repeat
      else if xChange["objectType"] is "group" then
         if the number of lines of the cardIds of tObject > 1 then
            put "the group is on" && the number of lines of the cardIds of tObject && "cards, and deleting it takes it off all of them;" && \
                  "the assistant does not delete such a group: ask the user to" into xChange["problem"]
            exit xtbPlanDelete
         end if
      end if
      if xtbIsRunning(tObject) then
         put "the script of" && xtbLabel(tObject) && "is running: ask the user to stop it first" into xChange["problem"]
         exit xtbPlanDelete
      end if
      put "Delete" && xtbLabel(tObject) into xChange["label"]
      if xChange["objectType"] is not "card" then
         put " from" && xtbLabel(xtbCardOf(tObject)) after xChange["label"]
      end if
   else
      put "Delete the" && xRefs[word 2 of xChange["object"]]["type"] && quote & xRefs[word 2 of xChange["object"]]["name"] & quote && \
            "made above" into xChange["label"]
   end if
end xtbPlanDelete

-- The object a set or a delete is about: "object" is "stack", "id N" or
-- "ref R"; "objectType" its type; "longId" the long id of one that is
-- there already
private command xtbPlanObject pNode, @xPlan, @xRefs, @xChange
   local tValue, tStack
   put word 1 to -1 of xtaJsonText(xtaJsonMember(pNode, "object")) into tValue
   put xPlan["stack"] into tStack
   if tValue is empty then
      put "give the object: an id from read_stack, " & quote & "stack" & quote & ", or the ref of an object this batch creates" into xChange["problem"]
      exit xtbPlanObject
   end if
   if tValue is "stack" then
      put "stack" into xChange["object"]
      put "stack" into xChange["objectType"]
      put tStack into xChange["longId"]
      exit xtbPlanObject
   end if
   if xRefs[tValue]["type"] is not empty then
      put "ref" && tValue into xChange["object"]
      put xRefs[tValue]["type"] into xChange["objectType"]
      exit xtbPlanObject
   end if
   if tValue is an integer and tStack is not empty then
      if there is a card id tValue of tStack then
         put "id" && tValue into xChange["object"]
         put "card" into xChange["objectType"]
         put the long id of card id tValue of tStack into xChange["longId"]
         exit xtbPlanObject
      end if
      if there is a control id tValue of tStack then
         put "id" && tValue into xChange["object"]
         put the long id of control id tValue of tStack into xChange["longId"]
         put word 1 of xChange["longId"] into xChange["objectType"]
         exit xtbPlanObject
      end if
   end if
   if tStack is empty then
      put "there is no object" && quote & tValue & quote && "(in a stack this batch makes, name objects by their ref)" into xChange["problem"]
   else
      put "the stack" && quote & the short name of tStack & quote && "has no card or control with the id" && quote & tValue & quote into xChange["problem"]
   end if
end xtbPlanObject

-- What a create does, for the user
private function xtbCreateLabel pChange, pPlan, pRefs
   local tLabel, tWhere
   if pChange["type"] is "stack" then
      put "Create a new stack" && quote & pChange["name"] & quote into tLabel
   else if pChange["type"] is "card" then
      put "Create a card" && quote & pChange["name"] & quote into tLabel
   else
      put "Create" && xtbArticle(pChange["kind"]) && pChange["kind"] && quote & pChange["name"] & quote into tLabel
      switch word 1 to 2 of pChange["in"]
         case "card id"
            put " on" && xtbLabel(the long id of card id (word 3 of pChange["in"]) of pPlan["stack"]) into tWhere
            break
         case "card ref"
            put " on the new card" && quote & pRefs[word 3 of pChange["in"]]["name"] & quote into tWhere
            break
         case "group id"
            put " in" && xtbLabel(the long id of control id (word 3 of pChange["in"]) of pPlan["stack"]) into tWhere
            break
         case "group ref"
            put " in the new group" && quote & pRefs[word 3 of pChange["in"]]["name"] & quote into tWhere
            break
      end switch
      put tWhere after tLabel
      if pChange["rect"] is not empty then
         put " at" && pChange["rect"] after tLabel
      end if
   end if
   return tLabel & xtbValuesLabel(pChange)
end xtbCreateLabel

private function xtbSetLabel pChange, pRefs
   local tLabel
   switch word 1 of pChange["object"]
      case "stack"
         if pChange["longId"] is empty then
            put "Change the new stack" into tLabel
         else
            put "Change" && xtbLabel(pChange["longId"]) into tLabel
         end if
         break
      case "ref"
         put "Change the new" && pRefs[word 2 of pChange["object"]]["type"] && quote & pRefs[word 2 of pChange["object"]]["name"] & quote into tLabel
         break
      default
         put "Change" && xtbLabel(pChange["longId"]) into tLabel
   end switch
   return tLabel & xtbValuesLabel(pChange)
end xtbSetLabel

-- ": label, textSize; custom property cScore; a script of 12 lines"
private function xtbValuesLabel pChange
   local tParts, tList, tIndex, tLines
   repeat with tIndex = 1 to the number of elements of pChange["properties"]
      if tList is not empty then
         put ", " after tList
      end if
      put pChange["properties"][tIndex]["name"] after tList
   end repeat
   if tList is not empty then
      put tList into tParts
   end if
   put empty into tList
   repeat with tIndex = 1 to the number of elements of pChange["custom"]
      if tList is not empty then
         put ", " after tList
      end if
      put pChange["custom"][tIndex]["name"] after tList
   end repeat
   if tList is not empty then
      if tParts is not empty then
         put "; " after tParts
      end if
      if the number of elements of pChange["custom"] is 1 then
         put "custom property" && tList after tParts
      else
         put "custom properties" && tList after tParts
      end if
   end if
   if pChange["hasScript"] is true then
      if tParts is not empty then
         put "; " after tParts
      end if
      put the number of lines of pChange["script"] into tLines
      if word 1 to -1 of pChange["script"] is empty then
         put "its script removed" after tParts
      else if tLines is 1 then
         put "a script of 1 line" after tParts
      else
         put "a script of" && tLines && "lines" after tParts
      end if
   end if
   if tParts is empty then
      return empty
   end if
   if pChange["action"] is "create" then
      return ", with" && tParts
   end if
   return ":" && tParts
end xtbValuesLabel

private function xtbArticle pWord
   if char 1 of pWord is among the items of "a,e,i,o,u" then
      return "an"
   end if
   return "a"
end xtbArticle

-- The widget kinds installed, for a message to the model
private function xtbWidgetKinds
   local tList, tLine
   repeat for each line tLine in the loadedExtensions
      if tLine contains ".widget." then
         put tLine & ", " after tList
      end if
   end repeat
   if tList is empty then
      return "none"
   end if
   return char 1 to -3 of tList
end xtbWidgetKinds

--------------------------------------------------------------------------------
-- Values

-- A JSON value (parsed) as the engine takes it: text as it is, a number as
-- written, a boolean as true or false, null as empty; a list of values is
-- their items ([10, 20] is "10,20") and a list of lists is lines of them;
-- an object is an array
private function xtbValue pNode
   local tType, tValue, tIndex, tItem, tLines, tName
   put xtaJsonType(pNode) into tType
   switch tType
      case "string"
      case "number"
      case "boolean"
         return xtaJsonText(pNode)
      case "array"
         put false into tLines
         repeat with tIndex = 1 to xtaJsonCount(pNode)
            if xtaJsonType(xtaJsonItem(pNode, tIndex)) is "array" then
               put true into tLines
            end if
         end repeat
         repeat with tIndex = 1 to xtaJsonCount(pNode)
            put xtbValue(xtaJsonItem(pNode, tIndex)) into tItem
            if tIndex > 1 then
               if tLines then
                  put return after tValue
               else
                  put comma after tValue
               end if
            end if
            put tItem after tValue
         end repeat
         return tValue
      case "object"
         repeat with tIndex = 1 to xtaJsonCount(pNode)
            put pNode["names"][tIndex] into tName
            put xtbValue(pNode["members"][tName]) into tValue[tName]
         end repeat
         return tValue
   end switch
   return empty
end xtbValue

-- A rect of four whole numbers, rounded, or empty when pValue is not one
private function xtbRect pValue
   local tRect, tItem
   if pValue is an array or the number of items of pValue is not 4 then
      return empty
   end if
   repeat for each item tItem in pValue
      put word 1 to -1 of tItem into tItem
      if tItem is not a number then
         return empty
      end if
      if tRect is not empty then
         put comma after tRect
      end if
      put round(tItem) after tRect
   end repeat
   if item 3 of tRect <= item 1 of tRect or item 4 of tRect <= item 2 of tRect then
      return empty
   end if
   return tRect
end xtbRect

-- pValue as one line, cut, for a message
private function xtbShort pValue
   if pValue is an array then
      return "(an array)"
   end if
   replace return with "\n" in pValue
   if the number of chars of pValue > 80 then
      return char 1 to 77 of pValue & "..."
   end if
   return pValue
end xtbShort

-- xtbErrorMessage for the assistant's window
function xtaThrownText pError
   return xtbErrorMessage(pError)
end xtaThrownText

-- The message of the first line of an error the engine threw, or the
-- error as it was thrown by a script
private function xtbErrorMessage pError
   local tLine, tCode, tMessage
   repeat for each line tLine in pError
      put item 1 of tLine into tCode
      if tCode is not an integer then
         if word 1 to -1 of tLine is not empty then
            return tLine
         end if
         next repeat
      end if
      if tCode is kObjectNameError then
         next repeat
      end if
      put empty into tMessage
      if tCode > 0 then
         put line tCode of the scriptExecutionErrors into tMessage
      end if
      if tMessage is empty then
         put "error" && tCode into tMessage
      else
         put " (error" && tCode & ")" after tMessage
      end if
      if item 4 to -1 of tLine is not empty then
         put ", near" && quote & item 4 to -1 of tLine & quote after tMessage
      end if
      return tMessage
   end repeat
   return "an error"
end xtbErrorMessage

--------------------------------------------------------------------------------
-- Stand-ins
--
-- Before the user is asked, each value of a change is set on a stand-in:
-- for a new object, one of its kind; for one that is there already, a copy
-- of it, so that a value that depends on the object (a menu's
-- menuHistory, for one) is tried as it would be. They are made in a hidden
-- stack with messages locked, and the stack goes when the batch is
-- checked. A stack's properties and a widget's are not tried: a stack
-- cannot be copied without its file, and a widget kind may not be.

-- The problem with pChange's values, or empty
private function xtbTryOnStandIn pChange, pPlan, pRefs
   local tObject, tType, tIndex, tName, tValue, tProblem, tError
   if pChange["action"] is "delete" then
      return empty
   end if
   if the number of elements of pChange["properties"] is 0 and the number of elements of pChange["custom"] is 0 and pChange["rect"] is empty then
      return empty
   end if
   if pChange["action"] is "create" then
      put pChange["type"] into tType
   else
      put pChange["objectType"] into tType
   end if
   if tType is "stack" or tType is "widget" then
      return empty
   end if
   put xtbStandIn(pChange, tType) into tObject
   if tObject is empty then
      return empty
   end if
   lock messages
   try
      if pChange["action"] is "create" then
         xtbSetKindDefaults tObject, pChange["kind"]
         if pChange["rect"] is not empty then
            set the rect of tObject to pChange["rect"]
         end if
      end if
      repeat with tIndex = 1 to the number of elements of pChange["properties"]
         put pChange["properties"][tIndex]["name"] into tName
         if tName is among the items of kNotOnStandIn or tName is "fileName" then
            next repeat
         end if
         put pChange["properties"][tIndex]["value"] into tValue
         try
            set tName of tObject to tValue
         catch tError
            put "setting" && tName && "to" && quote & xtbShort(tValue) & quote && "failed:" && xtbErrorMessage(tError) into tProblem
            exit repeat
         end try
      end repeat
   catch tError
      put "it could not be made:" && xtbErrorMessage(tError) into tProblem
   end try
   unlock messages
   return tProblem
end xtbTryOnStandIn

-- A stand-in for pChange's object, of type pType, in the stand-in stack
private function xtbStandIn pChange, pType
   local tStack, tSource, tObject, tOldDefault
   put xtbStandInStack() into tStack
   put pChange["longId"] into tSource
   lock messages
   if pChange["action"] is "set" and tSource is not empty then
      if pType is "card" then
         copy tSource to tStack
      else
         copy tSource to card 1 of tStack
      end if
      put it into tObject
   else if pType is "card" then
      put the defaultStack into tOldDefault
      set the defaultStack to kStandInStack
      create card
      put it into tObject
      set the defaultStack to tOldDefault
   else
      put xtbCreate(pType, "StandIn", empty, the long id of card 1 of tStack) into tObject
   end if
   unlock messages
   return tObject
end xtbStandIn

private function xtbStandInStack
   local tOldDefault
   if there is a stack kStandInStack then
      return the long id of stack kStandInStack
   end if
   put the defaultStack into tOldDefault
   lock messages
   create invisible stack kStandInStack
   set the _ideoverride of stack kStandInStack to true
   set the defaultStack to tOldDefault
   unlock messages
   return the long id of stack kStandInStack
end xtbStandInStack

private command xtbStandInCleanup
   if there is a stack kStandInStack then
      lock messages
      delete stack kStandInStack
      unlock messages
   end if
end xtbStandInCleanup

--------------------------------------------------------------------------------
-- Applying a batch

-- Makes the changes of pPlan (xtaBuildPlan's, ok), in order, with messages
-- locked; when one fails, the changes made before it are taken back.
-- Returns an array: "ok"; "entry" (its number in the journal); "summary"
-- (one line for the user); "text" (for the model: what each change made,
-- with the ids of new objects); or "error" (for both, when nothing was
-- changed).
function xtaBuildApply pPlan
   local tResult, tEntry, tStack, tRefs, tIndex, tChange, tError, tFailed, tOldDefault, tMade, tUndoProblems
   put false into tResult["ok"]
   if pPlan["ok"] is not true then
      put "The batch was not checked." into tResult["error"]
      return tResult
   end if
   put xtbStillThere(pPlan) into tError
   if tError is not empty then
      put "Nothing was changed:" && tError into tResult["error"]
      return tResult
   end if
   put the defaultStack into tOldDefault
   put pPlan["stack"] into tStack
   put "changes" into tEntry["kind"]
   if tStack is not empty then
      put xtbBeforePrints(the short name of xtbMainStackOf(tStack)) into tEntry["before"]
   end if
   lock screen
   lock messages
   repeat with tIndex = 1 to the number of elements of pPlan["changes"]
      put pPlan["changes"][tIndex] into tChange
      try
         xtbApplyChange tChange, tStack, tRefs, tEntry
         put the result into tMade[tIndex]
      catch tError
         put tIndex into tFailed
         exit repeat
      end try
   end repeat
   if tFailed is not empty then
      xtbUndoSteps tEntry["steps"]
      put the result into tUndoProblems
      unlock messages
      xtbRestoreDefaultStack tOldDefault
      unlock screen
      put "Nothing was changed: change" && tFailed && "(" & pPlan["changes"][tFailed]["label"] & ") failed:" && xtbErrorMessage(tError) & \
            ", so what the changes before it made was taken back." into tResult["error"]
      if tUndoProblems is not empty then
         put return & "Taking it back did not all work:" && tUndoProblems after tResult["error"]
      end if
      return tResult
   end if

   put tStack into tEntry["stack"]
   put the short name of xtbMainStackOf(tStack) into tEntry["main"]
   put "applied" into tEntry["state"]
   put the number of elements of sJournal + 1 into tEntry["number"]
   -- The cards made are opened, the last one last to show the user what was
   -- built, before the prints are taken: the engine settles some of what is
   -- on a card when it first opens it (a scrolling field's scrollbarWidth,
   -- for one), which is not the user changing it
   xtbOpenCardsMade tEntry, tStack
   xtbTakePrints tEntry
   unlock messages
   xtbRestoreDefaultStack tOldDefault
   unlock screen
   xtbTellIDEOfSteps tEntry["steps"], false
   xtbMarkEdited tStack

   if the number of elements of pPlan["changes"] is 1 then
      put "Applied 1 change to the stack" && quote & tEntry["main"] & quote into tEntry["summary"]
   else
      put "Applied" && the number of elements of pPlan["changes"] && "changes to the stack" && quote & tEntry["main"] & quote into tEntry["summary"]
   end if
   put tEntry into sJournal[tEntry["number"]]
   put tEntry["number"] into tResult["entry"]
   put tEntry["summary"] into tResult["summary"]
   put tEntry["summary"] & ":" into tResult["text"]
   repeat with tIndex = 1 to the number of elements of pPlan["changes"]
      put return & "- change" && tIndex & ":" && tMade[tIndex] after tResult["text"]
   end repeat
   put return & "The user can undo them." after tResult["text"]
   put true into tResult["ok"]
   return tResult
end xtaBuildApply

-- Moves the window of pStack (a long id or a name) whole into the working
-- area of the screen it is most on (the screen less the taskbar, the Dock
-- and the menu bar), its title bar included, when part of it is outside:
-- a new stack the model gave the rect 0,0,... opened with its title bar
-- above the screen, out of reach, and a window centred on another near
-- the top of the screen grew past it. With pShrink true a resizable
-- window taller or wider than the area is made smaller to fit, down to its
-- minHeight and minWidth; one that is still too large goes to the area's
-- top left. A window that fits is not moved. Returns its new rect, or
-- empty when it was left where it was (also when the engine has no screen,
-- as without a user interface).
command xtaKeepOnScreen pStack, pShrink
   local tArea, tMin, tRect
   if pStack is empty or there is not a stack pStack then
      return empty
   end if
   put line (the screen of stack pStack) of the working screenRects into tArea
   if the number of items of tArea is not 4 then
      put the working screenRect into tArea
   end if
   if pShrink is true and the resizable of stack pStack then
      put the minWidth of stack pStack, the minHeight of stack pStack into tMin
   end if
   put xtaOnScreenRect(the rect of stack pStack, the effective rect of stack pStack, tArea, tMin) into tRect
   if tRect is empty or tRect is the rect of stack pStack then
      return empty
   end if
   set the rect of stack pStack to tRect
   return the rect of stack pStack
end xtaKeepOnScreen

-- Where xtaKeepOnScreen puts a window: pRect is its rect (the card's),
-- pFrame its effective rect (with the title bar and border, the same as
-- pRect while it has no window), pArea the working area of its screen,
-- and pMin empty to keep its size, else the least width and height it may
-- be made to fit. Empty when pArea is no area (no screen).
function xtaOnScreenRect pRect, pFrame, pArea, pMin
   local tTitle, tEdge, tWidth, tHeight, tLeft, tTop
   if item 3 of pArea <= item 1 of pArea or item 4 of pArea <= item 2 of pArea then
      return empty
   end if
   -- The window's frame, at least what the platforms draw while it has
   -- none yet
   put max(32, item 2 of pRect - item 2 of pFrame) into tTitle
   put max(8, item 1 of pRect - item 1 of pFrame) into tEdge
   put item 3 of pRect - item 1 of pRect into tWidth
   put item 4 of pRect - item 2 of pRect into tHeight
   if pMin is not empty then
      put max(item 1 of pMin, min(tWidth, item 3 of pArea - item 1 of pArea - 2 * tEdge)) into tWidth
      put max(item 2 of pMin, min(tHeight, item 4 of pArea - item 2 of pArea - tTitle - tEdge)) into tHeight
   end if
   put max(item 1 of pArea + tEdge, min(item 1 of pRect, item 3 of pArea - tEdge - tWidth)) into tLeft
   put max(item 2 of pArea + tTitle, min(item 2 of pRect, item 4 of pArea - tEdge - tHeight)) into tTop
   return tLeft & comma & tTop & comma & (tLeft + tWidth) & comma & (tTop + tHeight)
end xtaOnScreenRect

-- Empty when every object pPlan names is still there, else what is not
private function xtbStillThere pPlan
   local tIndex, tChange, tObject
   if pPlan["newStack"] is true then
      if there is a stack pPlan["name"] then
         return "a stack named" && quote & pPlan["name"] & quote && "was opened meanwhile."
      end if
      return empty
   end if
   if pPlan["stack"] is empty or there is not a pPlan["stack"] then
      return "the stack" && quote & pPlan["name"] & quote && "is no longer open."
   end if
   repeat with tIndex = 1 to the number of elements of pPlan["changes"]
      put pPlan["changes"][tIndex]["longId"] into tObject
      if tObject is not empty then
         if there is not a tObject then
            return "an object it changes is gone (" & pPlan["changes"][tIndex]["label"] & ")."
         end if
      end if
   end repeat
   return empty
end xtbStillThere

-- Makes one change. xStack is the long id of the batch's stack (set by a
-- create stack), xRefs the long ids of what the batch made, by ref, and
-- xEntry the journal entry being made. The result is what was done, for
-- the model; an error is thrown on.
private command xtbApplyChange pChange, @xStack, @xRefs, @xEntry
   local tObject, tIn, tStep, tCard, tOldDefault, tDone, tCount, tName
   switch pChange["action"]
      case "create"
         switch pChange["type"]
            case "stack"
               create stack pChange["name"]
               put the long id of it into tObject
               put tObject into xStack
               put "createdStack" into tStep["op"]
               put pChange["name"] into tStep["name"]
               put tObject into tStep["object"]
               xtbAddStep xEntry, tStep
               if pChange["rect"] is not empty then
                  set the rect of tObject to pChange["rect"]
               end if
               break
            case "card"
               put the defaultStack into tOldDefault
               set the defaultStack to xtbStackName(xStack)
               put xtbCurrentCard(xStack) into tCard
               create card pChange["name"]
               put the long id of it into tObject
               -- The user stays where they were until the batch is made
               if there is a tCard then
                  go tCard
               end if
               set the defaultStack to tOldDefault
               put "created" into tStep["op"]
               put tObject into tStep["object"]
               xtbAddStep xEntry, tStep
               put tObject into xEntry["lastCard"]
               break
            default
               put xtbContainer(pChange["in"], xStack, xRefs) into tIn
               put xtbCreate(pChange["type"], pChange["name"], pChange["widgetKind"], tIn) into tObject
               put "created" into tStep["op"]
               put tObject into tStep["object"]
               xtbAddStep xEntry, tStep
               xtbSetKindDefaults tObject, pChange["kind"]
               if pChange["rect"] is not empty then
                  set the rect of tObject to pChange["rect"]
               else
                  xtbPlaceNew tObject, pChange["kind"], xStack
               end if
         end switch
         xtbSetValues tObject, pChange
         if pChange["ref"] is not empty then
            put tObject into xRefs[pChange["ref"]]
         end if
         put "created" && xtbLabel(tObject) into tDone
         if pChange["type"] is not "stack" and pChange["type"] is not "card" then
            if word 1 of the long id of the owner of tObject is "group" then
               put " in" && xtbLabel(the long id of the owner of tObject) after tDone
            end if
            put " on" && xtbLabel(xtbCardOf(tObject)) after tDone
         end if
         if pChange["ref"] is not empty then
            put " (ref" && pChange["ref"] & ")" after tDone
         end if
         return tDone
      case "set"
         put xtbObjectOf(pChange["object"], xStack, xRefs) into tObject
         if word 1 of pChange["object"] is not "ref" and xEntry["snapped"][tObject] is not true then
            put "changed" into tStep["op"]
            put tObject into tStep["object"]
            put xtbSnapshot(tObject) into tStep["snapshot"]
            put xtbNamesOf(pChange) into tStep["names"]
            xtbAddStep xEntry, tStep
            put true into xEntry["snapped"][tObject]
         end if
         xtbSetValues tObject, pChange
         return "changed" && xtbLabel(tObject) & xtbValuesLabel(pChange)
      case "delete"
         put xtbObjectOf(pChange["object"], xStack, xRefs) into tObject
         put xtbLabel(tObject) into tName
         if word 1 of pChange["object"] is not "ref" then
            put "deleted" into tStep["op"]
            put xtbKeepForUndo(tObject) into tStep["record"]
            put tObject into tStep["object"]
            xtbAddStep xEntry, tStep
         end if
         delete tObject
         return "deleted" && tName
   end switch
   throw "there is no action" && pChange["action"]
end xtbApplyChange

private command xtbAddStep @xEntry, pStep
   put pStep into xEntry["steps"][the number of elements of xEntry["steps"] + 1]
end xtbAddStep

-- The names of the properties a change sets, one per line, in order
private function xtbNamesOf pChange
   local tNames, tIndex
   repeat with tIndex = 1 to the number of elements of pChange["properties"]
      put pChange["properties"][tIndex]["name"] & return after tNames
   end repeat
   return tNames
end xtbNamesOf

-- Makes a control of pType named pName (a widget of pWidgetKind) in pIn
-- (the long id of a card or a group). Returns its long id.
private function xtbCreate pType, pName, pWidgetKind, pIn
   switch pType
      case "button"
         create button pName in pIn
         break
      case "field"
         create field pName in pIn
         break
      case "graphic"
         create graphic pName in pIn
         break
      case "scrollbar"
         create scrollbar pName in pIn
         break
      case "image"
         create image pName in pIn
         break
      case "player"
         create player pName in pIn
         break
      case "group"
         create group pName in pIn
         break
      case "widget"
         create widget pName as pWidgetKind in pIn
         break
      default
         throw "there is no type" && pType
   end switch
   return the long id of it
end xtbCreate

-- The properties the IDE gives an object of pKind
private command xtbSetKindDefaults pObject, pKind
   local tKinds, tPair, tName, tAt
   put xtbKinds() into tKinds
   set the itemDelimiter to ";"
   repeat for each item tPair in tKinds[pKind]["properties"]
      put offset("=", tPair) into tAt
      put char 1 to tAt - 1 of tPair into tName
      set tName of pObject to char tAt + 1 to -1 of tPair
   end repeat
end xtbSetKindDefaults

-- A new control with no rect given: its kind's size, in the middle of
-- the card, where the IDE puts one (revIDECreateObject)
private command xtbPlaceNew pObject, pKind, pStack
   local tKinds
   put xtbKinds() into tKinds
   if tKinds[pKind]["width"] > 0 then
      set the width of pObject to tKinds[pKind]["width"]
      set the height of pObject to tKinds[pKind]["height"]
      set the loc of pObject to (the width of pStack div 2), (the height of pStack div 2)
   end if
end xtbPlaceNew

-- Sets a change's properties, custom properties and script on pObject
private command xtbSetValues pObject, pChange
   local tIndex, tName
   repeat with tIndex = 1 to the number of elements of pChange["properties"]
      put pChange["properties"][tIndex]["name"] into tName
      if tName is "layer" and word 1 of pObject is not "card" then
         xtbSetLayer pObject, pChange["properties"][tIndex]["value"]
      else
         set tName of pObject to pChange["properties"][tIndex]["value"]
      end if
   end repeat
   repeat with tIndex = 1 to the number of elements of pChange["custom"]
      put pChange["custom"][tIndex]["name"] into tName
      set tName of pObject to pChange["custom"][tIndex]["value"]
   end repeat
   if pChange["hasScript"] is true then
      set the script of pObject to pChange["script"]
      if the result is not empty then
         throw "its script did not compile (" & line 1 of the result & ")"
      end if
   end if
end xtbSetValues

-- Sets the layer of a control. A control in a group keeps to it (the
-- relayerGroupedControls; "relayer" would hang this engine), and the
-- engine sets a layer only on the card that is open (error 345), so the
-- stack goes to that card meanwhile, and a closed stack is opened hidden
-- and closed again, all with messages locked.
private command xtbSetLayer pObject, pLevel
   local tStack, tCard, tCurrent, tOpened, tWasVisible, tOldRelayer, tError
   put xtbStackOf(pObject) into tStack
   put xtbCardOf(pObject) into tCard
   put false into tOpened
   put the relayerGroupedControls into tOldRelayer
   lock screen
   lock messages
   try
      if xtbIsOpen(tStack) then
         put xtbCurrentCard(tStack) into tCurrent
         if tCurrent is not tCard then
            go tCard
         end if
      else
         put the visible of tStack into tWasVisible
         put true into tOpened
         go invisible tCard
      end if
      set the relayerGroupedControls to true
      set the layer of pObject to pLevel
   catch tError
   end try
   set the relayerGroupedControls to tOldRelayer
   if tOpened then
      close tStack
      set the visible of tStack to tWasVisible
   else if tCurrent is not empty and tCurrent is not tCard then
      go tCurrent
   end if
   unlock messages
   unlock screen
   if tError is not empty then
      throw tError
   end if
end xtbSetLayer

-- The long id of the card or group a new control goes in
private function xtbContainer pIn, pStack, pRefs
   switch word 1 to 2 of pIn
      case "card id"
         return the long id of card id (word 3 of pIn) of pStack
      case "group id"
         return the long id of control id (word 3 of pIn) of pStack
      case "card ref"
      case "group ref"
         return pRefs[word 3 of pIn]
      case "first card"
         return the long id of card 1 of pStack
   end switch
   throw "there is no place" && pIn
end xtbContainer

-- The long id of the object a set or a delete is about
private function xtbObjectOf pObject, pStack, pRefs
   switch word 1 of pObject
      case "stack"
         return pStack
      case "ref"
         return pRefs[word 2 of pObject]
      case "id"
         if there is a card id (word 2 of pObject) of pStack then
            return the long id of card id (word 2 of pObject) of pStack
         end if
         return the long id of control id (word 2 of pObject) of pStack
   end switch
   throw "there is no object" && pObject
end xtbObjectOf

--------------------------------------------------------------------------------
-- The journal

-- The journal, for the window: entries 1 to N, each with "number", "kind",
-- "state", "main" and "summary"
function xtaBuildEntries
   local tEntries, tIndex
   repeat with tIndex = 1 to the number of elements of sJournal
      put sJournal[tIndex]["number"] into tEntries[tIndex]["number"]
      put sJournal[tIndex]["kind"] into tEntries[tIndex]["kind"]
      put sJournal[tIndex]["state"] into tEntries[tIndex]["state"]
      put sJournal[tIndex]["main"] into tEntries[tIndex]["main"]
      put sJournal[tIndex]["summary"] into tEntries[tIndex]["summary"]
   end repeat
   return tEntries
end xtaBuildEntries

-- Undoes the entry pEntry, and every later one on the same stack first,
-- newest first. Unless pForce, nothing is undone when the user changed
-- what they made since: then "changed" lists what, for the plugin to ask
-- about. Returns "ok", "undone" (the entries, one per line), "summary"
-- (for the user), "changed", or "error".
function xtaBuildUndo pEntry, pForce
   local tResult, tList, tIndex, tMain
   if pEntry is not an integer or sJournal[pEntry]["state"] is not "applied" then
      put false into tResult["ok"]
      put "That was undone already." into tResult["error"]
      return tResult
   end if
   put sJournal[pEntry]["main"] into tMain
   repeat with tIndex = the number of elements of sJournal down to pEntry
      if sJournal[tIndex]["state"] is "applied" and sJournal[tIndex]["main"] is tMain then
         put tIndex & return after tList
      end if
   end repeat
   return xtbUndoEntries(tList, pForce)
end xtaBuildUndo

-- Undoes every entry still applied, newest first
function xtaBuildUndoAll pForce
   local tList, tIndex, tResult
   repeat with tIndex = the number of elements of sJournal down to 1
      if sJournal[tIndex]["state"] is "applied" then
         put tIndex & return after tList
      end if
   end repeat
   if tList is empty then
      put false into tResult["ok"]
      put "There is nothing to undo." into tResult["error"]
      return tResult
   end if
   return xtbUndoEntries(tList, pForce)
end xtaBuildUndoAll

private function xtbUndoEntries pList, pForce
   local tResult, tIndex, tChanged, tOldDefault, tProblems, tCount
   put false into tResult["ok"]
   if pForce is not true then
      put xtbChangedSince(pList) into tChanged
      if tChanged is not empty then
         delete the last char of tChanged
         put tChanged into tResult["changed"]
         return tResult
      end if
   end if
   put the defaultStack into tOldDefault
   lock screen
   lock messages
   put 0 into tCount
   repeat for each line tIndex in pList
      if sJournal[tIndex]["kind"] is "run" then
         put xtaCheckpointRestore(sJournal[tIndex]["checkpoint"], sJournal[tIndex]["stack"]) into tProblems
      else
         xtbUndoSteps sJournal[tIndex]["steps"]
         put the result into tProblems
      end if
      put "undone" into sJournal[tIndex]["state"]
      add 1 to tCount
      if tProblems is not empty then
         put tProblems & return after tResult["error"]
      end if
   end repeat
   unlock messages
   xtbRestoreDefaultStack tOldDefault
   unlock screen
   repeat for each line tIndex in pList
      if sJournal[tIndex]["kind"] is not "run" then
         xtbTellIDEOfSteps sJournal[tIndex]["steps"], true
      end if
      if there is a sJournal[tIndex]["stack"] then
         xtbMarkEdited sJournal[tIndex]["stack"]
      end if
   end repeat
   put pList into tResult["undone"]
   if tCount is 1 then
      put "Undid 1 set of changes" into tResult["summary"]
   else
      put "Undid" && tCount && "sets of changes" into tResult["summary"]
   end if
   put (tResult["error"] is empty) into tResult["ok"]
   return tResult
end xtbUndoEntries

-- Undoes the steps of an entry, the last first. The result is what could
-- not be undone, if anything.
private command xtbUndoSteps pSteps
   local tIndex, tError, tProblems
   repeat with tIndex = the number of elements of pSteps down to 1
      try
         xtbUndoStep pSteps[tIndex]
      catch tError
         put xtbErrorMessage(tError) & return after tProblems
      end try
   end repeat
   return tProblems
end xtbUndoSteps

private command xtbUndoStep pStep
   local tObject
   put pStep["object"] into tObject
   switch pStep["op"]
      case "createdStack"
         if there is a stack pStep["name"] then
            delete stack pStep["name"]
         end if
         break
      case "created"
         if there is a tObject then
            delete tObject
         end if
         break
      case "changed"
         if there is a tObject then
            xtbRestore tObject, pStep["snapshot"], pStep["names"]
         end if
         break
      case "deleted"
         xtbRestoreDeleted pStep["record"]
         break
   end switch
end xtbUndoStep

-- Everything a change can set on pObject: its properties, script and
-- custom properties (every set)
private function xtbSnapshot pObject
   local tSnap, tSet
   put the properties of pObject into tSnap["properties"]
   put the script of pObject into tSnap["script"]
   put the customPropertySets of pObject into tSnap["sets"]
   put the customProperties of pObject into tSnap["custom"]
   repeat for each line tSet in tSnap["sets"]
      put the customProperties[tSet] of pObject into tSnap["setValues"][tSet]
   end repeat
   return tSnap
end xtbSnapshot

-- Puts pObject back as pSnap has it: its script and custom properties,
-- the properties the change set (pNames), newest first, then any other
-- that changed with them
private command xtbRestore pObject, pSnap, pNames
   local tIndex, tName, tNow, tOldRelayer, tSet, tError, tIsControl
   set the caseSensitive to true
   if the script of pObject is not pSnap["script"] then
      set the script of pObject to pSnap["script"]
   end if
   if xtbValueText(the customProperties of pObject) is not xtbValueText(pSnap["custom"]) then
      set the customProperties of pObject to pSnap["custom"]
   end if
   repeat for each line tSet in pSnap["sets"]
      if xtbValueText(the customProperties[tSet] of pObject) is not xtbValueText(pSnap["setValues"][tSet]) then
         set the customProperties[tSet] of pObject to pSnap["setValues"][tSet]
      end if
   end repeat
   if the customPropertySets of pObject is not pSnap["sets"] then
      set the customPropertySets of pObject to pSnap["sets"]
   end if
   put word 1 of pObject is not among the items of "stack,card" into tIsControl
   put the relayerGroupedControls into tOldRelayer
   set the relayerGroupedControls to true
   repeat with tIndex = the number of lines of pNames down to 1
      put line tIndex of pNames into tName
      if tName is among the keys of pSnap["properties"] then
         try
            if tName is "layer" and tIsControl then
               xtbSetLayer pObject, pSnap["properties"][tName]
            else
               set tName of pObject to pSnap["properties"][tName]
            end if
         catch tError
         end try
      end if
   end repeat
   put the properties of pObject into tNow
   repeat for each key tName in pSnap["properties"]
      if tName is among the items of "id,altId,fileName" then
         next repeat
      end if
      if xtbValueText(tNow[tName]) is not xtbValueText(pSnap["properties"][tName]) then
         try
            if tName is "layer" and tIsControl then
               xtbSetLayer pObject, pSnap["properties"][tName]
            else
               set tName of pObject to pSnap["properties"][tName]
            end if
         catch tError
         end try
      end if
   end repeat
   set the relayerGroupedControls to tOldRelayer
end xtbRestore

-- What is needed to put pObject (a control or a card) back after it is
-- deleted: a copy in the hold stack, and its id, place and layer, and the
-- ids of what it holds, in order
private function xtbKeepForUndo pObject
   local tRecord, tHold, tOwner
   put xtbHoldStack() into tHold
   put word 1 of pObject into tRecord["type"]
   put the id of pObject into tRecord["id"]
   put xtbStackOf(pObject) into tRecord["stack"]
   put xtbControlIds(pObject) into tRecord["ids"]
   if tRecord["type"] is "card" then
      put the number of pObject into tRecord["number"]
      copy pObject to tHold
      put the long id of it into tRecord["copy"]
   else
      put the id of xtbCardOf(pObject) into tRecord["card"]
      put the long id of the owner of pObject into tOwner
      if word 1 of tOwner is "group" then
         put the id of tOwner into tRecord["group"]
      end if
      put the layer of pObject into tRecord["layer"]
      copy pObject to card 1 of tHold
      put the long id of it into tRecord["copy"]
   end if
   return tRecord
end xtbKeepForUndo

-- Copies a deleted object back from the hold stack, with its ids, and its
-- layer or its card's number
private command xtbRestoreDeleted pRecord
   local tStack, tCopy, tInto, tNew, tOldDefault, tCurrent
   put pRecord["stack"] into tStack
   if there is not a tStack then
      throw "the stack it was in is no longer open"
   end if
   put pRecord["copy"] into tCopy
   if there is not a tCopy then
      throw "its copy is gone"
   end if
   if pRecord["type"] is "card" then
      -- A card copied in becomes the current one; the user stays where
      -- they were
      if xtbIsOpen(tStack) then
         put xtbCurrentCard(tStack) into tCurrent
      end if
      put the defaultStack into tOldDefault
      set the defaultStack to xtbStackName(tStack)
      copy tCopy to tStack
      put the long id of it into tNew
      set the defaultStack to tOldDefault
      set the id of tNew to pRecord["id"]
      put the long id of card id pRecord["id"] of tStack into tNew
      set the number of tNew to pRecord["number"]
      xtbRestoreIds tNew, pRecord["ids"]
      if tCurrent is not empty then
         if there is a tCurrent then
            go tCurrent
         end if
      end if
   else
      if pRecord["group"] is not empty then
         put the long id of control id pRecord["group"] of tStack into tInto
      else
         put the long id of card id pRecord["card"] of tStack into tInto
      end if
      copy tCopy to tInto
      put the long id of it into tNew
      set the id of tNew to pRecord["id"]
      put the long id of control id pRecord["id"] of tStack into tNew
      xtbRestoreIds tNew, pRecord["ids"]
      xtbSetLayer tNew, pRecord["layer"]
   end if
   delete tCopy
end xtbRestoreDeleted

-- The ids of the controls a card or a group holds, in order (a copy has
-- them in the same order, with new ids)
private function xtbControlIds pObject
   local tIds, tIndex
   if word 1 of pObject is not "card" and word 1 of pObject is not "group" then
      return empty
   end if
   repeat with tIndex = 1 to the number of controls of pObject
      put the id of control tIndex of pObject & return after tIds
   end repeat
   return tIds
end xtbControlIds

private command xtbRestoreIds pObject, pIds
   local tIndex
   repeat with tIndex = 1 to the number of lines of pIds
      if tIndex > the number of controls of pObject then
         exit repeat
      end if
      if the id of control tIndex of pObject is not line tIndex of pIds then
         set the id of control tIndex of pObject to line tIndex of pIds
      end if
   end repeat
end xtbRestoreIds

-- The stack the copies of deleted objects are kept in: hidden, closed, and
-- never saved
private function xtbHoldStack
   local tOldDefault
   if there is a stack kHoldStack then
      return the long id of stack kHoldStack
   end if
   put the defaultStack into tOldDefault
   lock messages
   create invisible stack kHoldStack
   set the _ideoverride of stack kHoldStack to true
   set the defaultStack to tOldDefault
   -- Closed, it stays in memory, where objects can still be copied in and
   -- out, and cannot become the topStack
   close stack kHoldStack
   unlock messages
   return the long id of stack kHoldStack
end xtbHoldStack

-- Goes to each card the entry made that is still there, in the order they
-- were made, when their stack is open: the user is left on the last one,
-- and what was made on each has been opened once. (What was made on a
-- card that was there already is first opened when the user goes to it,
-- and Undo may then ask whether to undo it anyway.)
private command xtbOpenCardsMade pEntry, pStack
   local tIndex, tStep
   if pEntry["lastCard"] is empty or not xtbIsOpen(pStack) then
      exit xtbOpenCardsMade
   end if
   repeat with tIndex = 1 to the number of elements of pEntry["steps"]
      put pEntry["steps"][tIndex] into tStep
      if tStep["op"] is "created" and word 1 of tStep["object"] is "card" then
         if there is a tStep["object"] then
            go tStep["object"]
         end if
      end if
   end repeat
end xtbOpenCardsMade

-- How the entry left each object it made or changed, to tell later
-- whether the user changed it since
private command xtbTakePrints @xEntry
   local tIndex, tStep, tObject
   repeat with tIndex = 1 to the number of elements of xEntry["steps"]
      put xEntry["steps"][tIndex] into tStep
      if tStep["op"] is "deleted" then
         next repeat
      end if
      put tStep["object"] into tObject
      if there is a tObject then
         put xtbPrint(tObject) into xEntry["prints"][tObject]
      end if
   end repeat
end xtbTakePrints

-- What the user changed since the entries of pList (newest first) were
-- applied, of what they made or changed, one per line, or empty: for the
-- newest on a stack, how each object is now; for an earlier one, how it
-- was when the next on that stack was applied (its "before"), which is how
-- undoing that one leaves it
private function xtbChangedSince pList
   local tIndex, tMain, tNewer, tObject, tNow, tChanged, tLabel
   repeat for each line tIndex in pList
      put sJournal[tIndex]["main"] into tMain
      repeat for each key tObject in sJournal[tIndex]["prints"]
         if tNewer[tMain] is empty then
            if there is not a tObject then
               next repeat
            end if
            put xtbPrint(tObject) into tNow
         else
            if tObject is not among the keys of sJournal[tNewer[tMain]]["before"] then
               next repeat
            end if
            put sJournal[tNewer[tMain]]["before"][tObject] into tNow
         end if
         if tNow is not sJournal[tIndex]["prints"][tObject] then
            put xtbLabel(tObject) into tLabel
            if not (tLabel is among the lines of tChanged) then
               put tLabel & return after tChanged
            end if
         end if
      end repeat
      put tIndex into tNewer[tMain]
   end repeat
   return tChanged
end xtbChangedSince

-- How the objects of the entries still applied on the main stack pMain
-- are now, by long id (for the entry about to be made)
private function xtbBeforePrints pMain
   local tIndex, tObject, tPrints
   repeat with tIndex = 1 to the number of elements of sJournal
      if sJournal[tIndex]["state"] is not "applied" or sJournal[tIndex]["main"] is not pMain then
         next repeat
      end if
      repeat for each key tObject in sJournal[tIndex]["prints"]
         if tObject is among the keys of tPrints then
            next repeat
         end if
         if there is a tObject then
            put xtbPrint(tObject) into tPrints[tObject]
         end if
      end repeat
   end repeat
   return tPrints
end xtbBeforePrints

-- A digest of how the main stack of pStack is, with its substacks
private function xtbDumpPrint pStack
   return base64Encode(md5Digest(textEncode(xtaStackDump(pStack), "UTF-8")))
end xtbDumpPrint

-- A digest of how pObject is, and all it holds
private function xtbPrint pObject
   local tDigest
   put md5Digest(textEncode(xtbStateText(pObject, true, false), "UTF-8")) into tDigest
   return base64Encode(tDigest)
end xtbPrint

--------------------------------------------------------------------------------
-- A stack as text
--
-- An object as text, the same for the same object: its properties, by
-- name, its script and its custom properties, every set; with pDeep, what
-- it holds after it, in order (a stack's cards, a card's controls, a
-- group's). Its layer is left out, as the order says it; so is a stack's
-- id, which is the engine's count of the ids it gave, and unless pAll, a
-- stack's rect (where its window is).

-- The main stack of pStack and its substacks, as text: two stacks that
-- are the same give the same text
function xtaStackDump pStack
   local tMain, tText, tSub
   put xtbMainStackOf(pStack) into tMain
   put xtbStateText(tMain, true, true) into tText
   repeat for each line tSub in the substacks of tMain
      put xtbStateText(the long id of stack tSub of tMain, true, true) after tText
   end repeat
   return tText
end xtaStackDump

private function xtbStateText pObject, pDeep, pAll
   local tText, tType, tProps, tKeys, tKey, tSet, tIndex, tCustom
   put word 1 of the long id of pObject into tType
   if tType is "stack" then
      put "stack" && the short name of pObject & return into tText
   else
      put tType && "id" && the id of pObject & return into tText
   end if
   put the properties of pObject into tProps
   put the keys of tProps into tKeys
   sort lines of tKeys
   repeat for each line tKey in tKeys
      if tKey is "layer" then
         next repeat
      end if
      if tType is "stack" and (tKey is "id" or (tKey is "rect" and not pAll)) then
         next repeat
      end if
      put "  " & tKey & "=" & xtbValueText(tProps[tKey]) & return after tText
   end repeat
   put "  (script)=" & xtbValueText(the script of pObject) & return after tText
   put "  (custom)=" & xtbValueText(the customProperties of pObject) & return after tText
   repeat for each line tSet in the customPropertySets of pObject
      put "  (custom " & tSet & ")=" & xtbValueText(the customProperties[tSet] of pObject) & return after tText
   end repeat
   if not pDeep then
      return tText
   end if
   switch tType
      case "stack"
         repeat with tIndex = 1 to the number of cards of pObject
            put xtbStateText(the long id of card tIndex of pObject, true, pAll) after tText
         end repeat
         break
      case "card"
      case "group"
         repeat with tIndex = 1 to the number of controls of pObject
            put xtbStateText(the long id of control tIndex of pObject, false, pAll) after tText
         end repeat
         break
   end switch
   return tText
end xtbStateText

-- A value as one line: an array's keys sorted, each with its value
private function xtbValueText pValue
   local tKeys, tKey, tText
   if pValue is an array then
      put the keys of pValue into tKeys
      sort lines of tKeys
      repeat for each line tKey in tKeys
         put tKey & ":" & xtbValueText(pValue[tKey]) & ";" after tText
      end repeat
      return "{" & tText & "}"
   end if
   replace "\" with "\\" in pValue
   replace return with "\n" in pValue
   replace numToChar(13) with "\r" in pValue
   return pValue
end xtbValueText

--------------------------------------------------------------------------------
-- Checkpoints
--
-- A checkpoint is the main stack, with its substacks, saved to a file of
-- its own before a run on it: "save as" with messages locked (no
-- saveStackRequest, so the IDE does not count it as saved), then the
-- stack's file set back, so the stack is saved where it was, and an
-- unsaved stack stays unsaved. Restoring is "revert" with the stack's
-- file set to the checkpoint for the moment. The files go when the
-- assistant is turned off.

-- Saves a checkpoint of the main stack of pStack; returns its file, or
-- empty with the reason in the result
function xtaCheckpointSave pStack
   local tMain, tFile, tOldFile, tError, tProblem
   put xtbMainStackOf(pStack) into tMain
   if sCheckpointFolder is empty or there is not a folder sCheckpointFolder then
      put specialFolderPath("temporary") & "/xtalkassistant-" & the seconds & "-" & random(100000) into sCheckpointFolder
      create folder sCheckpointFolder
      if there is not a folder sCheckpointFolder then
         put empty into sCheckpointFolder
         return "the folder for checkpoints could not be made in" && specialFolderPath("temporary") for error
      end if
      -- The copies of the user's stacks are theirs alone to read, where
      -- the system lets that be said (the temporary folder is often shared)
      if the platform is not "Win32" then
         get shell("chmod 700" && quote & sCheckpointFolder & quote)
      end if
   end if
   add 1 to sCheckpointCount
   put sCheckpointFolder & "/checkpoint-" & sCheckpointCount & ".livecode" into tFile
   put the fileName of tMain into tOldFile
   lock messages
   try
      save tMain as tFile
      put the result into tProblem
   catch tError
      put xtbErrorMessage(tError) into tProblem
   end try
   set the fileName of tMain to tOldFile
   unlock messages
   if tProblem is not empty or there is not a file tFile then
      if tProblem is empty then
         put "the file was not written" into tProblem
      end if
      return tProblem for error
   end if
   return tFile
end xtaCheckpointSave

-- Reverts the main stack of pStack to the checkpoint pPath; the result is
-- empty, or what went wrong
function xtaCheckpointRestore pPath, pStack
   local tMain, tName, tOldFile, tOldDefault, tError, tProblem
   if there is not a file pPath then
      return "the checkpoint's file is gone"
   end if
   if there is not a pStack then
      return "the stack is no longer open"
   end if
   put xtbMainStackOf(pStack) into tMain
   put the short name of tMain into tName
   put the fileName of tMain into tOldFile
   -- Reverting the defaultStack crashes this engine at the next "there is
   -- a stack": it is moved to this stack, which stays
   put the defaultStack into tOldDefault
   set the defaultStack to the short name of me
   lock messages
   try
      set the fileName of tMain to pPath
      revert stack tName
   catch tError
      put xtbErrorMessage(tError) into tProblem
   end try
   if there is a stack tName then
      set the fileName of stack tName to tOldFile
   end if
   unlock messages
   if tOldDefault is not empty and there is a stack tOldDefault then
      set the defaultStack to tOldDefault
   end if
   return tProblem
end xtaCheckpointRestore

--------------------------------------------------------------------------------
-- Runs
--
-- A run is JSON: "code" (statements, run as the Message Box runs them:
-- what "put" without a container puts goes into the Message Box, and in
-- the sandbox "return" gives a value back; on the user's stack the code is
-- sent as the Message Box sends it, "send script", which keeps no value
-- that it returns), "where" ("sandbox", the default, or "stack"),
-- for the sandbox "handlers" (handlers the code can call), and for the
-- user's stack "stack" (its name, empty for the one the user works on)
-- and "target" (the id of the card or control that is "me", the current
-- card when none).

-- Checks a run before the user is asked. Returns an array: "ok",
-- "problems" (for the model), "where", "code", "handlers", "stack" (the
-- long id of the user's stack, for a run on it), "target", "risks" (what
-- it does that cannot be undone, as xtaRiskScan gives it) and "label"
-- (for the user).
function xtaRunPlan pInput, pStack
   local tRun, tWhere, tCode, tHandlers, tCounts, tCheck, tLine, tTarget, tTargetValue, tStack
   put false into tRun["ok"]
   put toLower(word 1 to -1 of xtaJsonText(xtaJsonMember(pInput, "where"))) into tWhere
   if tWhere is empty then
      put "sandbox" into tWhere
   end if
   if tWhere is not "sandbox" and tWhere is not "stack" then
      put "where is " & quote & "sandbox" & quote & " or " & quote & "stack" & quote into tRun["problems"]
      return tRun
   end if
   put tWhere into tRun["where"]
   put xtaJsonText(xtaJsonMember(pInput, "code")) into tCode
   replace crlf with return in tCode
   replace numToChar(13) with return in tCode
   if word 1 to -1 of tCode is empty then
      put "Give the code to run (statements, as in the Message Box)." into tRun["problems"]
      return tRun
   end if
   put xtaScriptCounts(tCode) into tCounts
   if tCounts["handlers"] > 0 then
      put "code is statements, run as the Message Box runs them. Handlers go in handlers (in the sandbox), or into the stack with make_changes." \
            into tRun["problems"]
      return tRun
   end if
   put xtaCheckScript(tCode, empty) into tCheck
   if tCheck["ok"] is not true then
      put "The code does not compile:" into tRun["problems"]
      repeat for each line tLine in tCheck["issues"]
         put return & "- " & tLine after tRun["problems"]
      end repeat
      return tRun
   end if
   put tCode into tRun["code"]

   put xtaJsonText(xtaJsonMember(pInput, "handlers")) into tHandlers
   replace crlf with return in tHandlers
   replace numToChar(13) with return in tHandlers
   if word 1 to -1 of tHandlers is not empty then
      if tWhere is "stack" then
         put "handlers run in the sandbox only. To run new handlers in the user's stack, put them there with make_changes first, then run code that calls them." \
               into tRun["problems"]
         return tRun
      end if
      put xtaScriptCounts(tHandlers) into tCounts
      if tCounts["handlers"] is 0 or tCounts["statements"] > 0 then
         put "handlers holds whole handlers only; statements go in code." into tRun["problems"]
         return tRun
      end if
      put xtaCheckScript(tHandlers, empty) into tCheck
      if tCheck["ok"] is not true then
         put "The handlers do not compile:" into tRun["problems"]
         repeat for each line tLine in tCheck["issues"]
            put return & "- " & tLine after tRun["problems"]
         end repeat
         return tRun
      end if
      if matchText(tHandlers, "(?im)^\s*(private\s+)?(on|command|function)\s+(" & kRunHandler & "|msgChanged)\b") then
         put "handlers may not define" && kRunHandler && "or msgChanged: the sandbox uses them." into tRun["problems"]
         return tRun
      end if
   end if
   put tHandlers into tRun["handlers"]

   if tWhere is "stack" then
      put xtbTargetStack(xtaJsonText(xtaJsonMember(pInput, "stack")), pStack) into tTarget
      if tTarget["problem"] is not empty then
         put tTarget["problem"] into tRun["problems"]
         return tRun
      end if
      put tTarget["stack"] into tStack
      put tStack into tRun["stack"]
      put word 1 to -1 of xtaJsonText(xtaJsonMember(pInput, "target")) into tTargetValue
      if tTargetValue is empty then
         put xtbCurrentCard(tStack) into tRun["target"]
      else if tTargetValue is an integer and there is a card id tTargetValue of tStack then
         put the long id of card id tTargetValue of tStack into tRun["target"]
      else if tTargetValue is an integer and there is a control id tTargetValue of tStack then
         put the long id of control id tTargetValue of tStack into tRun["target"]
      else
         put "The stack" && quote & the short name of tStack & quote && "has no card or control with the id" && quote & tTargetValue & quote & "." into tRun["problems"]
         return tRun
      end if
      put "Run on the stack" && quote & the short name of xtbMainStackOf(tStack) & quote & ", as" && xtbLabel(tRun["target"]) into tRun["label"]
   else
      put "Run in a sandbox (a hidden stack made for the run)" into tRun["label"]
   end if
   put xtaRiskScan(tHandlers & return & tCode) into tRun["risks"]
   put true into tRun["ok"]
   return tRun
end xtaRunPlan

-- Runs pRun (xtaRunPlan's, ok). Returns an array: "ok" (true when it ran
-- without an error), "ran" (false when it could not start: then "error"
-- says why), "ms", "value" (what it returned), "output" (what it put into
-- the Message Box), "trace" and "errorText" (an error, in words, with the
-- lines around it), "stopped" (true when the user stopped it while it
-- ran: Control-period), "entry" (for a run on the user's stack, the journal
-- entry that reverts it; none when the run left the stack as it was, whose
-- checkpoint is then deleted), "summary" (for the user) and "text" (for
-- the model).
function xtaRunCode pRun
   local tResult, tCheckpoint, tOldDefault, tOldMsg, tStart, tError, tValue, tOutput, tHandlersLines, tEntry, tWhere, tBeforeRun, tKept, tSame
   put false into tResult["ok"]
   put false into tResult["ran"]
   if pRun["ok"] is not true then
      put "The run was not checked." into tResult["error"]
      return tResult
   end if
   put pRun["where"] into tWhere
   if tWhere is "stack" then
      if there is not a pRun["stack"] or there is not a pRun["target"] then
         put "The stack or the object to run it as is no longer open." into tResult["error"]
         put "Did not run: the stack is no longer open" into tResult["summary"]
         put tResult["error"] into tResult["text"]
         return tResult
      end if
      put xtbBeforePrints(the short name of xtbMainStackOf(pRun["stack"])) into tEntry["before"]
      put xtbDumpPrint(pRun["stack"]) into tBeforeRun
      put xtaCheckpointSave(pRun["stack"]) into tCheckpoint
      if tCheckpoint is empty then
         put "The checkpoint could not be saved (" & the result & "), so nothing ran." into tResult["error"]
         put "Did not run: the checkpoint could not be saved" into tResult["summary"]
         put tResult["error"] into tResult["text"]
         return tResult
      end if
   end if

   put the defaultStack into tOldDefault
   lock messages
   put msg into tOldMsg
   put empty into msg
   if tWhere is "sandbox" then
      xtbMakeSandbox pRun["handlers"], pRun["code"]
      put the result into tHandlersLines
   end if
   unlock messages
   put true into tResult["ran"]
   put the milliseconds into tStart
   try
      if tWhere is "sandbox" then
         set the defaultStack to kSandboxStack
         send kRunHandler to stack kSandboxStack
      else
         set the defaultStack to xtbStackName(xtbStackOf(pRun["target"]))
         send script pRun["code"] to pRun["target"]
      end if
      put the result into tValue
   catch tError
   end try
   put the milliseconds - tStart into tResult["ms"]
   put msg into tOutput
   lock messages
   if tWhere is "sandbox" then
      -- The Message Box shows what it showed before
      put tOldMsg into msg
      if there is a stack kSandboxStack then
         delete stack kSandboxStack
      end if
   end if
   unlock messages
   xtbRestoreDefaultStack tOldDefault

   put xtbCut(tValue, kMaxOutputChars) into tResult["value"]
   put xtbCut(tOutput, kMaxOutputChars) into tResult["output"]
   put tError into tResult["trace"]
   put false into tResult["stopped"]
   if tError is not empty then
      put xtbRunErrorText(tError, pRun, tHandlersLines) into tResult["errorText"]
      put xtbWasStopped(tError) into tResult["stopped"]
   else
      put true into tResult["ok"]
   end if

   -- A run that left the stack as it was (it only read it) keeps no
   -- checkpoint and makes no entry: there is nothing to undo
   put true into tKept
   if tWhere is "stack" then
      if there is a pRun["stack"] then
         -- Digests, compared as text whose case counts
         set the caseSensitive to true
         put ("d" & xtbDumpPrint(pRun["stack"])) is ("d" & tBeforeRun) into tSame
         set the caseSensitive to false
         if tSame then
            put false into tKept
            delete file tCheckpoint
            put the short name of xtbMainStackOf(pRun["stack"]) into tEntry["main"]
         end if
      end if
   end if
   if tWhere is "stack" and tKept then
      put "run" into tEntry["kind"]
      put "applied" into tEntry["state"]
      put tCheckpoint into tEntry["checkpoint"]
      put xtbMainStackOf(pRun["stack"]) into tEntry["stack"]
      put the short name of tEntry["stack"] into tEntry["main"]
      put the number of elements of sJournal + 1 into tEntry["number"]
      put "Ran code on the stack" && quote & tEntry["main"] & quote into tEntry["summary"]
      if there is a tEntry["stack"] then
         put xtbPrint(tEntry["stack"]) into tEntry["prints"][tEntry["stack"]]
      end if
      put tEntry into sJournal[tEntry["number"]]
      put tEntry["number"] into tResult["entry"]
   end if

   if tWhere is "sandbox" then
      put "Ran the code in a sandbox" into tResult["summary"]
      put "Ran in a sandbox (a hidden stack, deleted after the run)" into tResult["text"]
   else if tKept then
      put "Ran the code on the stack" && quote & tEntry["main"] & quote into tResult["summary"]
      put "Ran on the stack" && quote & tEntry["main"] & quote & ", as" && xtbLabel(pRun["target"]) & \
            ", after a checkpoint that the user can go back to" into tResult["text"]
   else
      put "Ran the code on the stack" && quote & tEntry["main"] & quote into tResult["summary"]
      put "Ran on the stack" && quote & tEntry["main"] & quote & ", as" && xtbLabel(pRun["target"]) & \
            ", and left it as it was (so there is nothing to undo)" into tResult["text"]
   end if
   put " in" && tResult["ms"] && "ms" after tResult["text"]
   if tError is empty then
      put ": no error" after tResult["summary"]
      put ": no error." after tResult["text"]
   else if tResult["stopped"] then
      put ": you stopped it" after tResult["summary"]
      put ": the user stopped it before it ended (it may never end by itself). Where it was:" & return & tResult["errorText"] after tResult["text"]
   else
      put ": an error" after tResult["summary"]
      put ": it stopped at an error." & return & tResult["errorText"] after tResult["text"]
   end if
   if tValue is not empty then
      put return & "It returned:" && tResult["value"] after tResult["text"]
   end if
   if tOutput is not empty then
      put return & "It put into the Message Box:" & return & tResult["output"] after tResult["text"]
   end if
   if tValue is empty and tOutput is empty and tError is empty then
      if tWhere is "sandbox" then
         put return & "It returned nothing and put nothing into the Message Box (use return, or put without a container, to see a value)." after tResult["text"]
      else
         put return & "It put nothing into the Message Box (to see a value, put it without a container: return gives nothing back in a run on the stack)." after tResult["text"]
      end if
   end if
   return tResult
end xtaRunCode

-- The sandbox: a hidden stack whose script is the run's handlers, then a
-- handler of the statements, then a msgChanged that keeps what "put"
-- puts into the Message Box from opening it
private command xtbMakeSandbox pHandlers, pCode
   local tOldDefault, tScript, tLines
   if there is a stack kSandboxStack then
      delete stack kSandboxStack
   end if
   put the defaultStack into tOldDefault
   create invisible stack kSandboxStack
   set the _ideoverride of stack kSandboxStack to true
   set the defaultStack to tOldDefault
   -- The result is the number of lines before the run's own handler,
   -- which the line numbers of an error are counted from: those of the
   -- handlers (none when there are none, and a last empty line counts)
   if pHandlers is not empty then
      put pHandlers & return into tScript
   end if
   put the number of lines of tScript into tLines
   put "on" && kRunHandler & return & pCode & return & "end" && kRunHandler & return & \
         "on msgChanged" & return & "end msgChanged" after tScript
   set the script of stack kSandboxStack to tScript
   return tLines
end xtbMakeSandbox

-- True when the run stopped because the user stopped it: its innermost
-- error is one of the engine's "aborted"
private function xtbWasStopped pTrace
   local tLine
   replace crlf with return in pTrace
   repeat for each line tLine in pTrace
      if word 1 to -1 of tLine is empty then
         next repeat
      end if
      return item 1 of tLine is among the items of kAbortErrors
   end repeat
   return false
end xtbWasStopped

-- A run's error in words. In the sandbox, a line number is said as the
-- model wrote it (of the handlers, or of the code); a run on the user's
-- stack has the line numbers of their scripts, and of the code (which the
-- engine counts from the line after its own first).
private function xtbRunErrorText pTrace, pRun, pHandlersLines
   local tText, tLine, tPending, tObject, tWhere, tLineNo, tExcerptSource, tExcerptLine
   replace crlf with return in pTrace
   repeat for each line tLine in pTrace
      if word 1 to -1 of tLine is empty then
         next repeat
      end if
      if item 1 of tLine is not an integer then
         put "- thrown by the script:" && tLine & return after tText
         next repeat
      end if
      if item 1 of tLine is kObjectNameError then
         put item 4 to -1 of tLine into tObject
         -- The lines of the assistant's own handlers are not the run's
         if not xtbIsAssistantObject(tObject) then
            put xtbRunTraceLines(tPending, tObject, pRun, pHandlersLines, tExcerptSource, tExcerptLine) after tText
         end if
         put empty into tPending
         next repeat
      end if
      put tLine & return after tPending
   end repeat
   -- Lines after the last object named are those of the handler that
   -- caught the error, the assistant's
   if tExcerptSource is not empty then
      put "Around that line:" & return & xtaScriptExcerpt(tExcerptSource, tExcerptLine) & return after tText
   end if
   if tText is not empty then
      delete the last char of tText
   end if
   return tText
end xtbRunErrorText

-- The lines of one object of a trace, in words; the first that has a line
-- number in the run's own code or handlers gives the excerpt
private function xtbRunTraceLines pLines, pObject, pRun, pHandlersLines, @xExcerptSource, @xExcerptLine
   local tText, tLine, tCode, tLineNo, tMessage, tWhere, tInSandbox, tHint
   put (pObject contains kSandboxStack) into tInSandbox
   repeat for each line tLine in pLines
      put item 1 of tLine into tCode
      put item 2 of tLine into tLineNo
      put item 4 to -1 of tLine into tHint
      put empty into tMessage
      if tCode > 0 then
         put line tCode of the scriptExecutionErrors into tMessage
      end if
      if tMessage is empty then
         put "error" && tCode into tMessage
      else
         put " (error" && tCode & ")" after tMessage
      end if
      put empty into tWhere
      if tLineNo is an integer and tLineNo > 0 then
         if tInSandbox then
            if tLineNo <= pHandlersLines then
               put ", line" && tLineNo && "of the handlers" into tWhere
               if xExcerptSource is empty then
                  put pRun["handlers"] into xExcerptSource
                  put tLineNo into xExcerptLine
               end if
            else if tLineNo > pHandlersLines + 1 then
               put ", line" && tLineNo - pHandlersLines - 1 && "of the code" into tWhere
               if xExcerptSource is empty then
                  put pRun["code"] into xExcerptSource
                  put tLineNo - pHandlersLines - 1 into xExcerptLine
               end if
            end if
         else
            put ", line" && tLineNo into tWhere
         end if
      end if
      put "- " & tMessage & tWhere after tText
      if tHint is not empty then
         put ", near" && quote & tHint & quote after tText
      end if
      put return after tText
   end repeat
   if pObject is not empty and not tInSandbox then
      put "  (in the script of" && pObject & ")" & return after tText
   end if
   return tText
end xtbRunTraceLines

-- What pCode does that cannot be undone, as words for the user, one per
-- line: "files", "the network", "other programs", "stacks saved, closed
-- or deleted", "quitting", "the clipboard", "printing", "messages sent for
-- later", "code it builds as it runs". It reads the code, so it cannot see
-- what a handler the code calls does: the user is told that too.
function xtaRiskScan pCode
   local tCode, tRisks
   put toLower(pCode) into tCode
   if matchText(tCode, "url\s*\(?\s*\x22(file|binfile|resfile):") or matchText(tCode, "\b(open|close)\s+file\b") \
         or matchText(tCode, "\b(read\s+from|write\s+to)\s+file\b") or matchText(tCode, "\bdelete\s+(file|folder|directory)\b") \
         or matchText(tCode, "\bcreate\s+(folder|directory|alias)\b") or matchText(tCode, "\brename\s") \
         or matchText(tCode, "\brev(copy|delete|move)(file|folder)\b") or matchText(tCode, "\bthe\s+(defaultfolder|directory)\b") then
      put "files" & return after tRisks
   end if
   if matchText(tCode, "url\s*\(?\s*\x22(https?|ftp):") or matchText(tCode, "\b(load|unload)\s+url\b") \
         or matchText(tCode, "\bopen\s+(secure\s+)?socket\b") or matchText(tCode, "\baccept\s+(datagram\s+)?connections\b") \
         or matchText(tCode, "\b(read\s+from|write\s+to)\s+socket\b") or matchText(tCode, "\blaunch\s+url\b") \
         or matchText(tCode, "\bpost\b[^\n]*\bto\s+url\b") or matchText(tCode, "\blibur") then
      put "the network" & return after tRisks
   end if
   if not ("files" is among the lines of tRisks) and not ("the network" is among the lines of tRisks) and matchText(tCode, "\burl\b") then
      put "files or the network" & return after tRisks
   end if
   if matchText(tCode, "\bshell\s*\(") or matchText(tCode, "\b(open|close|kill)\s+process\b") \
         or matchText(tCode, "\blaunch\b(?!\s+url)") or matchText(tCode, "\bthe\s+shellcommand\b") \
         or matchText(tCode, "\bas\s+(applescript|vbscript|javascript)\b") then
      put "other programs" & return after tRisks
   end if
   if matchText(tCode, "\b(save|revert)\b") or matchText(tCode, "\b(delete|close)\s+(this\s+)?stack\b") then
      put "stacks saved, closed or deleted" & return after tRisks
   end if
   if matchText(tCode, "\bquit\b") then
      put "quitting" & return after tRisks
   end if
   if matchText(tCode, "\b(fullclipboarddata|clipboarddata|rawclipboarddata)\b") or matchText(tCode, "\bpaste\b") \
         or matchText(tCode, "(^|\n|\bthen)\s*copy\s*($|\n|\belse)") then
      put "the clipboard" & return after tRisks
   end if
   if matchText(tCode, "\bprint\b") or matchText(tCode, "\bopen\s+printing\b") or matchText(tCode, "\brevprint") then
      put "printing" & return after tRisks
   end if
   if matchText(tCode, "\bsend\b[^\n]*\bin\s+[0-9a-z(]") then
      put "messages sent for later" & return after tRisks
   end if
   if matchText(tCode, "(^|\n|\bthen|\belse)\s*do\b") or matchText(tCode, "\bvalue\s*\(") then
      put "code it builds as it runs" & return after tRisks
   end if
   if tRisks is not empty then
      delete the last char of tRisks
   end if
   return tRisks
end xtaRiskScan

--------------------------------------------------------------------------------
-- The debugger
--
-- While a script is paused in the debugger, the engine runs the IDE's
-- windows (and the assistant's) inside the pause, so the handlers here run
-- after the paused ones in the executionContexts (oldest first). The
-- user's are the last run of handlers that are not the IDE's or the
-- assistant's: what started them may be the IDE's (the Message Box sends
-- what is typed into it). The debugContext names one by its line there,
-- and debugDo evaluates in it.

-- What is paused: an array with "paused" (false when no script of the
-- user's is), "stack" (the long id of the main stack of the innermost
-- paused handler), "object", "handler" and "line" (where it is), "summary"
-- (for the user) and "text" (for the model: the handlers, innermost first,
-- the variables of the innermost few, and the script around the line).
function xtaDebugState
   local tState, tContexts, tIndex, tContext, tInner, tUser, tCount, tText, tShown, tScript, tObject, tExcerpt
   put false into tState["paused"]
   put the executionContexts into tContexts
   -- From the newest: past the assistant's handlers and the IDE's, then
   -- the user's, innermost first, up to the first that is not theirs
   put the number of lines of tContexts into tIndex
   repeat while tIndex > 0
      put xtbParseContext(line tIndex of tContexts) into tContext
      if tContext["object"] is not empty and not xtbIsIDEObject(tContext["object"]) then
         exit repeat
      end if
      subtract 1 from tIndex
   end repeat
   put 0 into tCount
   repeat while tIndex > 0
      put xtbParseContext(line tIndex of tContexts) into tContext
      if tContext["object"] is empty or xtbIsIDEObject(tContext["object"]) then
         exit repeat
      end if
      add 1 to tCount
      put tIndex into tContext["number"]
      put tContext into tInner[tCount]
      subtract 1 from tIndex
   end repeat
   -- Oldest first, as the rest reads them
   repeat with tIndex = 1 to tCount
      put tInner[tCount - tIndex + 1] into tUser[tIndex]
   end repeat
   if tCount is 0 or the traceStack is empty then
      put "The debugger is not paused in a script of the user's." into tState["text"]
      put "Looked at the debugger: it is not paused" into tState["summary"]
      return tState
   end if
   put true into tState["paused"]
   put tUser[tCount] into tContext
   put xtbMainStackOf(xtbStackOf(tContext["object"])) into tState["stack"]
   put tContext["object"] into tState["object"]
   put tContext["handler"] into tState["handler"]
   put tContext["line"] into tState["line"]
   put "The debugger is paused at line" && tContext["line"] && "of the handler" && tContext["handler"] && "in" && xtbScriptOwnerLabel(tContext) & "." & return into tText
   if tCount > 1 then
      put "The handlers that led there, innermost first:" & return after tText
      repeat with tIndex = tCount down to 1
         put "-" && tUser[tIndex]["handler"] & ", line" && tUser[tIndex]["line"] & "," && xtbScriptOwnerLabel(tUser[tIndex]) & return after tText
      end repeat
   end if
   put 0 into tShown
   repeat with tIndex = tCount down to 1
      if tShown >= kMaxDebugContexts then
         exit repeat
      end if
      add 1 to tShown
      put xtbDebugVariables(tUser[tIndex]) after tText
   end repeat
   put xtbScriptOwner(tContext) into tObject
   if tContext["handler"] is not "message" and not xtbIsProtected(xtbStackOf(tObject)) then
      put the script of tObject into tScript
      put xtaScriptExcerpt(tScript, tContext["line"]) into tExcerpt
      if tExcerpt is not empty then
         put "The script of" && xtbLabel(tObject) & ", around line" && tContext["line"] & ":" & return & tExcerpt & return after tText
      end if
   end if
   delete the last char of tText
   put tText into tState["text"]
   put "Read the debugger: paused in" && tContext["handler"] & ", line" && tContext["line"] & "," && xtbLabel(tContext["object"]) into tState["summary"]
   return tState
end xtaDebugState

-- One line of the executionContexts: "object" (a long id, which may have
-- commas in it), "handler", "line", and "behavior" (the behavior whose
-- script the handler is in, if any): the line number is the first item
-- that is a whole number, as the IDE's debugger reads it
private function xtbParseContext pLine
   local tContext, tIndex, tItem
   put 0 into tIndex
   repeat for each item tItem in pLine
      add 1 to tIndex
      if tIndex > 2 and tItem is an integer then
         put item 1 to tIndex - 2 of pLine into tContext["object"]
         put item tIndex - 1 of pLine into tContext["handler"]
         put tItem into tContext["line"]
         put item tIndex + 1 to -1 of pLine into tContext["behavior"]
         exit repeat
      end if
   end repeat
   return tContext
end xtbParseContext

-- The object whose script a context's handler is in: its behavior's, or
-- its own
private function xtbScriptOwner pContext
   if pContext["behavior"] is not empty then
      if there is a pContext["behavior"] then
         return the long id of pContext["behavior"]
      end if
   end if
   if there is a pContext["object"] then
      return the long id of pContext["object"]
   end if
   return pContext["object"]
end xtbScriptOwner

private function xtbScriptOwnerLabel pContext
   -- "send script" (the Message Box) runs its code as a handler named
   -- message, whose lines are those of the code sent
   if pContext["handler"] is "message" then
      return "code sent to" && xtbLabel(pContext["object"]) && "(as the Message Box sends it)"
   end if
   if pContext["behavior"] is not empty then
      return "the behavior" && xtbLabel(pContext["behavior"]) && "of" && xtbLabel(pContext["object"])
   end if
   return "the script of" && xtbLabel(pContext["object"])
end xtbScriptOwnerLabel

-- The variables of one paused handler, read in its context: its
-- parameters, its locals and its script's locals, each with its value
-- (an array as its keys and their values)
private function xtbDebugVariables pContext
   local tText, tNames, tKinds, tKindIndex, tName, tValue, tIsArray, tKeys, tKey, tCount, tError, tLine
   if xtbIsProtected(xtbStackOf(pContext["object"])) then
      return "(The variables of" && pContext["handler"] && "are not read: its stack is password-protected.)" & return
   end if
   put "Variables of" && pContext["handler"] && "(line" && pContext["line"] & "):" & return into tText
   -- Set back to empty after, as the IDE's debugger does after each use
   -- (revdebuggerlibrary): it keeps the context the user picked in its
   -- own variables, and the engine's form of a context ("object,handler,
   -- line") cannot be set back as it reads
   try
      set the debugContext to pContext["number"]
      debugDo "return the variableNames"
      put the result into tNames
   catch tError
      set the debugContext to empty
      return tText & "  (they could not be read)" & return
   end try
   put "parameter,local,script local" into tKinds
   put 0 into tCount
   repeat with tKindIndex = 1 to 3
      put line tKindIndex of tNames into tLine
      repeat for each item tName in tLine
         put word 1 to -1 of tName into tName
         if tName is empty then
            next repeat
         end if
         -- it, when it holds nothing, says nothing
         if tName is "it" then
            try
               debugDo "return it is empty"
               if the result is true then
                  next repeat
               end if
            catch tError
            end try
         end if
         add 1 to tCount
         if tCount > kMaxVariables then
            exit repeat
         end if
         try
            debugDo "return" && tName && "is an array"
            put (the result is true) into tIsArray
            if tIsArray then
               debugDo "return the keys of" && tName
               put the result into tKeys
               sort lines of tKeys
               put "  " & tName && "(" & item tKindIndex of tKinds & ") = an array of" && the number of lines of tKeys && "keys:" after tText
               put 0 into tValue
               repeat for each line tKey in tKeys
                  add 1 to tValue
                  if tValue > kMaxKeys then
                     put " ..." after tText
                     exit repeat
                  end if
                  if tKey contains quote then
                     put space & "[" & tKey & "]" after tText
                     next repeat
                  end if
                  debugDo "return" && tName & "[" & quote & tKey & quote & "]"
                  put space & "[" & tKey & "]=" & xtbShortValue(the result) after tText
               end repeat
               put return after tText
            else
               debugDo "return" && tName
               put "  " & tName && "(" & item tKindIndex of tKinds & ") =" && xtbShortValue(the result) & return after tText
            end if
         catch tError
            put "  " & tName && "(" & item tKindIndex of tKinds & "): could not be read" & return after tText
         end try
      end repeat
   end repeat
   set the debugContext to empty
   if tCount is 0 then
      put "  (none)" & return after tText
   else if tCount > kMaxVariables then
      put "  (and more, left out)" & return after tText
   end if
   return tText
end xtbDebugVariables

-- A value as the model reads it: quoted, on one line, cut
private function xtbShortValue pValue
   if pValue is an array then
      return "(an array)"
   end if
   replace return with "\n" in pValue
   if the number of chars of pValue > kMaxValueChars then
      put char 1 to kMaxValueChars of pValue & "... (" & the number of chars of pValue && "characters)" into pValue
   end if
   return quote & pValue & quote
end xtbShortValue

--------------------------------------------------------------------------------
-- Telling the IDE
--
-- The IDE learns of a new or deleted object from the engine's messages
-- (newButton, deleteCard...), which a locked change does not send, so it
-- is told as revIDECreateObject tells it: ideNewControl and the others,
-- and the stack marked as edited, so that closing it asks to save. Outside
-- the IDE there is nobody to tell.

private command xtbTellIDEOfSteps pSteps, pUndone
   local tIndex, tStep, tObject
   repeat with tIndex = 1 to the number of elements of pSteps
      put pSteps[tIndex] into tStep
      put tStep["object"] into tObject
      switch tStep["op"]
         case "createdStack"
            if pUndone then
               xtbTellIDE "ideDestroyStack", tObject
            else
               xtbTellIDE "ideNewStack", tObject
            end if
            break
         case "created"
            if word 1 of tObject is "card" then
               if pUndone then
                  xtbTellIDE "ideCardDeleted", tObject
               else
                  xtbTellIDE "ideNewCard", tObject
               end if
            else if pUndone then
               xtbTellIDE "ideControlDeleted", tObject
            else
               xtbTellIDE "ideNewControl", tObject
            end if
            break
         case "deleted"
            if word 1 of tObject is "card" then
               if pUndone then
                  xtbTellIDE "ideNewCard", tObject
               else
                  xtbTellIDE "ideCardDeleted", tObject
               end if
            else if pUndone then
               xtbTellIDE "ideNewControl", tObject
            else
               xtbTellIDE "ideControlDeleted", tObject
            end if
            break
      end switch
   end repeat
end xtbTellIDEOfSteps

private command xtbTellIDE pMessage, pTarget
   local tError
   try
      ideMessageSend pMessage, pTarget
   catch tError
   end try
end xtbTellIDE

private command xtbMarkEdited pStack
   local tError
   try
      revIDESetEdited the short name of xtbMainStackOf(pStack)
   catch tError
   end try
end xtbMarkEdited

--------------------------------------------------------------------------------
-- Objects

-- An object for the user and the model: button "OK" (id 1004), card id
-- 1002, stack "Notes"
private function xtbLabel pObject
   local tName, tType
   if pObject is empty or there is not a pObject then
      return pObject
   end if
   put the name of pObject into tName
   put word 1 of tName into tType
   if tType is "stack" then
      return "stack" && quote & the short name of pObject & quote
   end if
   if char 1 of word 2 of tName is quote then
      return tType && quote & the short name of pObject & quote && "(id" && the id of pObject & ")"
   end if
   return tName
end xtbLabel

-- The long id of the stack an object is in (its own for a stack): the end
-- of its long id
private function xtbStackOf pObject
   local tAt
   put the long id of pObject into pObject
   if word 1 of pObject is "stack" then
      return pObject
   end if
   put offset(" of stack ", pObject) into tAt
   return char tAt + 4 to -1 of pObject
end xtbStackOf

-- The long id of a stack's main stack
private function xtbMainStackOf pStack
   put xtbStackOf(pStack) into pStack
   if the owner of pStack is empty then
      return the long id of pStack
   end if
   return the long id of the owner of pStack
end xtbMainStackOf

-- The long id of the card a control is on (as its long id says), or of a
-- card
private function xtbCardOf pObject
   local tAt, tId, tStack
   put the long id of pObject into pObject
   if word 1 of pObject is "card" then
      return pObject
   end if
   put offset(" card id ", pObject) into tAt
   put char tAt + 1 to -1 of pObject into tId
   put word 3 of tId into tId
   put xtbStackOf(pObject) into tStack
   return the long id of card id tId of tStack
end xtbCardOf

-- The long id of a stack's current card
private function xtbCurrentCard pStack
   return the long id of this card of pStack
end xtbCurrentCard

-- A stack's name as "set the defaultStack" takes it: a main stack's short
-- name, a substack's long id
private function xtbStackName pStack
   if the owner of pStack is empty then
      return the short name of pStack
   end if
   return the long id of pStack
end xtbStackName

private function xtbIsOpen pStack
   return the short name of xtbStackOf(pStack) is among the lines of the openStacks
end xtbIsOpen

-- True for one of the IDE's stacks (as the plugin's xtaIsIDEStack, and
-- revIDEStackNameIsIDEStack), or a substack of one
private function xtbIsIDEStack pStack
   local tName
   put the short name of pStack into tName
   if tName begins with "rev" or tName begins with "com.livecode." or tName begins with "org.openxtalk." then
      return true
   end if
   if tName is among the items of "Message Box,Answer Dialog,Ask Dialog,Home" then
      return true
   end if
   if the _ideoverride of pStack is true then
      return true
   end if
   if the owner of pStack is not empty then
      return xtbIsIDEStack(the long id of the owner of pStack)
   end if
   return false
end xtbIsIDEStack

-- True for an object of one of the assistant's own stacks (its plugin,
-- its libraries), but not the sandbox, whose script is the run's
private function xtbIsAssistantObject pObject
   return pObject contains (quote & "org.openxtalk.plugin.xtalkassistant") or pObject contains ("/org.openxtalk.plugin.xtalkassistant/")
end xtbIsAssistantObject

-- True for an object of the IDE's, the assistant's, or a library's that is
-- not the user's (a context in the debugger the user did not write)
private function xtbIsIDEObject pObject
   local tStack, tError
   try
      if there is not a pObject then
         return true
      end if
      put xtbStackOf(pObject) into tStack
      return xtbIsIDEStack(tStack)
   catch tError
      return true
   end try
end xtbIsIDEObject

-- True when the stack (or its main stack) has a password: its scripts are
-- not the assistant's to read or change
private function xtbIsProtected pStack
   local tPassword, tError
   put "protected" into tPassword
   try
      put the password of xtbMainStackOf(pStack) into tPassword
      if tPassword is empty then
         put the password of pStack into tPassword
      end if
   catch tError
   end try
   return tPassword is not empty
end xtbIsProtected

-- True while a handler of pObject's script runs (paused in the debugger,
-- or waiting): its script cannot be set then (engine error 360)
private function xtbIsRunning pObject
   local tLine, tContext
   put the long id of pObject into pObject
   repeat for each line tLine in the executionContexts
      put xtbParseContext(tLine) into tContext
      if tContext["object"] is empty then
         next repeat
      end if
      if there is a tContext["object"] then
         if the long id of tContext["object"] is pObject then
            return true
         end if
      end if
   end repeat
   return false
end xtbIsRunning

private command xtbRestoreDefaultStack pStack
   if pStack is not empty and there is a stack pStack then
      set the defaultStack to pStack
   end if
end xtbRestoreDefaultStack

-- pText cut to pMax characters, saying so
private function xtbCut pText, pMax
   if pText is an array then
      return "(an array)"
   end if
   if the number of chars of pText <= pMax then
      return pText
   end if
   return char 1 to pMax of pText & return & "... (" & the number of chars of pText - pMax && "more characters left out)"
end xtbCut

--------------------------------------------------------------------------------
-- Turning off

-- Forgets the journal and deletes the hidden stacks and the checkpoints:
-- what was applied stays as it is, and can no longer be undone
command xtaBuildCleanup
   local tFile
   put empty into sJournal
   lock messages
   if there is a stack kHoldStack then
      delete stack kHoldStack
   end if
   if there is a stack kStandInStack then
      delete stack kStandInStack
   end if
   if there is a stack kSandboxStack then
      delete stack kSandboxStack
   end if
   unlock messages
   if sCheckpointFolder is not empty and there is a folder sCheckpointFolder then
      repeat for each line tFile in files(sCheckpointFolder)
         delete file (sCheckpointFolder & "/" & tFile)
      end repeat
      delete folder sCheckpointFolder
   end if
   put empty into sCheckpointFolder
   put 0 into sCheckpointCount
end xtaBuildCleanup
