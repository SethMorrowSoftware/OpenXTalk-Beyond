script "TestScriptEditorDragDropUndo"
-- OXT-Beyond: tests that one Undo in the script editor takes back a whole
-- drag and drop of text (textDropText, which dragDrop calls, in
-- ide/Toolset/palettes/script editor/behaviors/revsecommoneditorbehavior.livecodescript).
-- textDropText opened an undo group "Drag", but each textReplace in it of
-- more than one char opened a group of its own, so a moved word took
-- three Undos: the first deleted the dropped text, the second put it back
-- where it came from and the third (the empty "Drag" group) did nothing.
-- Reported in the rc.6.17 Bug Hunt.

-- The behavior has syntax that compiles only in the IDE (_internal), so
-- the test compiles the undo handlers on their own, from the behavior's
-- file, as the script of a group holding a field "Script", with stubs for
-- the editor's other handlers. textReplaceRaw, the one that changes the
-- field, is stubbed with a plain put. In kStubs "|" stands for a return
-- and "~" for a quote.
constant kHandlers = "textBeginGroup,textEndGroup,textMark,textReplaceNewGroupNeeded,undoAvailable,redoAvailable,textUndo,textRedo,textReplace,textDropText"

constant kStubs = "local sObjectId,sTextOperationOffsets,sTextOperationNewTexts,sTextOperationOldTexts,sTextOperationIndex,sTextOperationTop,sTextGroupLabels,sTextGroupLengths,sTextGroupIndex,sTextGroupTop,sTextMark,sPlaceholders,sEditChunks,sEditPlaceholder|command testStart pText|put the long id of me into sObjectId|put 0 into sTextOperationIndex[sObjectId]|put 0 into sTextOperationTop[sObjectId]|put 0 into sTextGroupIndex[sObjectId]|put 0 into sTextGroupTop[sObjectId]|put pText into field ~Script~ of me|end testStart|private command __BracketCompletion pOffset, @xOldText, @xNewText|return empty for value|end __BracketCompletion|private command textReplaceRaw pOffset, @pOldText, @pNewText|put pNewText into char pOffset to max(0, pOffset + the length of pOldText - 1) of field ~Script~ of me|end textReplaceRaw|private function revRuggedId pObject|return pObject|end revRuggedId|command revDebuggerSuspendBreakpoints|end revDebuggerSuspendBreakpoints|command seSetObjectState|end seSetObjectState|private command __ClearCurrentPlaceholder|end __ClearCurrentPlaceholder|private command __ClearHighlights|end __ClearHighlights|command selectionUpdateRequest|end selectionUpdateRequest|private command __UpdateAutoCompleteList|end __UpdateAutoCompleteList|command setDirty|end setDirty"

local sEditor

on TestSetup
   local tText, tScript, tStart, tEnd, tKind, tName
   put textDecode(url ("binfile:" & TestGetIDERepositoryPath() & "/Toolset/palettes/script editor/behaviors/revsecommoneditorbehavior.livecodescript"), "UTF-8") into tText
   -- A Windows checkout has CRLF line ends, and the search below goes by
   -- returns
   replace crlf with return in tText
   put kStubs into tScript
   replace "|" with return in tScript
   replace "~" with quote in tScript
   repeat for each item tName in kHandlers
      put 0 into tStart
      repeat for each item tKind in "on,command,function,private command,private function"
         put offset(return & tKind && tName & return, tText) into tStart
         if tStart is 0 then
            put offset(return & tKind && tName & space, tText) into tStart
         end if
         if tStart is not 0 then
            exit repeat
         end if
      end repeat
      put offset(return & "end " & tName & return, tText, tStart) into tEnd
      TestAssert "found" && tName, tStart is not 0 and tEnd is not 0
      put return & char tStart + 1 to tStart + tEnd + length("end " & tName) of tText after tScript
   end repeat
   create stack "TestScriptEditorDragDropUndoStack"
   set the defaultStack to "TestScriptEditorDragDropUndoStack"
   create field "Script"
   group field "Script"
   put the long id of the last group into sEditor
   set the script of sEditor to tScript
   TestAssert "the handlers compile", the result is empty and "textDropText" is in the revAvailableHandlers of sEditor
end TestSetup

on TestTeardown
   if there is a stack "TestScriptEditorDragDropUndoStack" then
      delete stack "TestScriptEditorDragDropUndoStack"
   end if
end TestTeardown

private function __Text
   return the text of field "Script" of sEditor
end __Text

private function __UndoAvailable
   dispatch "undoAvailable" to sEditor
   return the result
end __UndoAvailable

on TestMoveForwardIsOneUndo
   dispatch "testStart" to sEditor with "one two three"
   -- "two " (chars 5 to 8) dropped after "three"
   dispatch "textDropText" to sEditor with 14, 5, 8, "two ", "cut"
   TestAssert "the text moved", __Text() is "one threetwo "
   dispatch "textUndo" to sEditor
   TestAssert "one undo puts the text back", __Text() is "one two three"
   TestAssert "one undo takes back the whole drop", __UndoAvailable() is false
   dispatch "textRedo" to sEditor
   TestAssert "one redo moves it again", __Text() is "one threetwo "
end TestMoveForwardIsOneUndo

on TestMoveBackwardIsOneUndo
   dispatch "testStart" to sEditor with "one two three"
   -- "three" (chars 9 to 13) dropped before "one"
   dispatch "textDropText" to sEditor with 1, 9, 13, "three", "cut"
   TestAssert "the text moved", __Text() is "threeone two "
   dispatch "textUndo" to sEditor
   TestAssert "one undo puts the text back", __Text() is "one two three"
   TestAssert "one undo takes back the whole drop", __UndoAvailable() is false
end TestMoveBackwardIsOneUndo

on TestCopyDropIsOneUndo
   -- Text dragged in from somewhere else, or with the copy key down
   dispatch "testStart" to sEditor with "one two"
   dispatch "textDropText" to sEditor with 4, 0, -1, " and", "copy"
   TestAssert "the text was added", __Text() is "one and two"
   dispatch "textUndo" to sEditor
   TestAssert "one undo removes it", __Text() is "one two"
   TestAssert "one undo takes back the whole drop", __UndoAvailable() is false
end TestCopyDropIsOneUndo

on TestDropOnSelectionLeavesNoUndo
   dispatch "testStart" to sEditor with "one two three"
   dispatch "textDropText" to sEditor with 6, 5, 8, "two ", "cut"
   TestAssert "the text is unchanged", __Text() is "one two three"
   TestAssert "no undo step was left", __UndoAvailable() is false
end TestDropOnSelectionLeavesNoUndo
