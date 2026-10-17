script "TestXTalkAssistantBuild"
-- OXT-Beyond: tests of what the xTalk Assistant does to a user's stack
-- once the user says yes
-- (ide/Extensions/org.openxtalk.plugin.xtalkassistant/xtalkassistant-build.livecodescript),
-- loaded with the core as the plugin loads them, with a stand-in for the
-- IDE handlers it tells: that a batch of changes is checked before anyone
-- is asked (an unknown property, a value the engine refuses, a script that
-- does not compile or is not made of handlers each go back to the model),
-- that it is made whole or not at all, that Undo puts the stack back
-- exactly as it was (the plan's gate 2: the stack as text is the same
-- before and after), that Undo says when the user changed what it would
-- take back, that a checkpoint brings a stack back, that code runs in a
-- sandbox or on the stack with what it returned, put and threw, and that
-- turning the assistant off leaves nothing behind. The debugger's paused
-- state needs the IDE's debugger; here it is only seen not paused.

constant kBuild = "org.openxtalk.plugin.xtalkassistant-build"
constant kHoldStack = "revXTalkAssistantJournal"
constant kStandInStack = "revXTalkAssistantStandIn"
constant kSandboxStack = "revXTalkAssistantSandbox"
constant kUserStack = "xtaTestUserStack"

on TestSetup
   local tFolder, tStub
   put TestGetIDERepositoryPath() & "/Extensions/org.openxtalk.plugin.xtalkassistant" into tFolder
   start using stack (tFolder & "/xtalkassistant-core.livecodescript")
   start using stack (tFolder & "/xtalkassistant-build.livecodescript")
   -- The IDE's handlers the library calls, recording what they were told
   put "local sTold, sEdited" & return & \
         "on ideMessageSend pMessage, pTarget" & return & "put pMessage && pTarget & return after sTold" & return & \
         "end ideMessageSend" & return & \
         "on revIDESetEdited pStack" & return & "put pStack & return after sEdited" & return & "end revIDESetEdited" & return & \
         "function xtaTestTold" & return & "return sTold" & return & "end xtaTestTold" & return & \
         "function xtaTestEdited" & return & "return sEdited" & return & "end xtaTestEdited" & return into tStub
   create invisible stack "xtaTestIDE"
   set the script of stack "xtaTestIDE" to tStub
   start using stack "xtaTestIDE"
end TestSetup

--------------------------------------------------------------------------------
-- Checking a batch

on TestPlanRefusesMistakes
   local tStack, tDump, tPlan
   put TestUserStack() into tStack
   put xtaStackDump(tStack) into tDump

   put TestPlan("{`changes`:[]}", tStack) into tPlan
   TestAssert "no changes", tPlan["ok"] is false and tPlan["problems"] contains "one change at least"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`gizmo`}]}", tStack) into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "an unknown kind, with the kinds", tPlan["ok"] is false and tPlan["problems"] contains "there is no kind" \
         and tPlan["problems"] contains "checkbox"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`properties`:{`lable`:`Go`}}]}", tStack) into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "a misspelt property", tPlan["ok"] is false and tPlan["problems"] contains "no property named" \
         and tPlan["problems"] contains "lable"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`field`,`properties`:{`textSize`:`big`}}]}", tStack) into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "a value the engine refuses, found on a stand-in", tPlan["ok"] is false and tPlan["problems"] contains "textSize" \
         and tPlan["problems"] contains "failed"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`properties`:{`id`:5000}}]}", tStack) into tPlan
   TestAssert "a property the assistant does not set", tPlan["ok"] is false and tPlan["problems"] contains "not one the assistant sets"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`script`:`on mouseUp\n  if then\nend mouseUp`}]}", tStack) into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "a script that does not compile", tPlan["ok"] is false and tPlan["problems"] contains "does not compile"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`script`:`put 1 into x`}]}", tStack) into tPlan
   TestAssert "a script of statements alone", tPlan["ok"] is false and tPlan["problems"] contains "made of handlers"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`ref`:`a`},{`action`:`create`,`kind`:`field`,`ref`:`a`}]}", tStack) into tPlan
   TestAssert "a ref given twice", tPlan["ok"] is false and tPlan["problems"] contains "given twice"

   put TestPlan("{`changes`:[{`action`:`set`,`object`:99999,`properties`:{`label`:`x`}}]}", tStack) into tPlan
   TestAssert "an object that is not there", tPlan["ok"] is false and tPlan["problems"] contains "no card or control with the id"

   put TestPlan("{`changes`:[{`action`:`set`,`object`:`stack`,`properties`:{`name`:`Other`}}]}", tStack) into tPlan
   TestAssert "a stack is not renamed", tPlan["ok"] is false and tPlan["problems"] contains "does not rename a stack"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`custom_properties`:{`textSize`:3}}]}", tStack) into tPlan
   TestAssert "a custom property named as the engine's", tPlan["ok"] is false and tPlan["problems"] contains "is a property of the engine's"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`group`:`nogroup`}]}", tStack) into tPlan
   TestAssert "a group that is not there", tPlan["ok"] is false and tPlan["problems"] contains "there is no group"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`},{`action`:`create`,`kind`:`stack`,`name`:`New`}]}", tStack) into tPlan
   TestAssert "a new stack only as the first change", tPlan["ok"] is false and tPlan["problems"] contains "first change"

   put TestPlan("{`stack`:`revXTalkAssistantJournalNot`,`changes`:[{`action`:`create`,`kind`:`button`}]}", tStack) into tPlan
   TestAssert "a stack that is not open", tPlan["ok"] is false and tPlan["problems"] contains "no stack named"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`rect`:[10,10,5,5]}]}", tStack) into tPlan
   TestAssert "a rect the wrong way round", tPlan["ok"] is false and tPlan["problems"] contains "four whole numbers"

   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`widget`,`widget_kind`:`com.example.nothing`}]}", tStack) into tPlan
   TestAssert "a widget kind that is not installed", tPlan["ok"] is false and tPlan["problems"] contains "is not installed"

   TestAssert "the stand-in stack is gone", there is not a stack kStandInStack
   TestAssert "nothing changed in the user's stack", xtaStackDump(tStack) is tDump
end TestPlanRefusesMistakes

on TestPlanRefusesWhatUndoCannotPutBack
   local tStack, tPlan, tGroup
   put TestUserStack() into tStack
   put TestPlan("{`changes`:[{`action`:`delete`,`object`:`stack`}]}", tStack) into tPlan
   TestAssert "a stack is not deleted", tPlan["ok"] is false and tPlan["problems"] contains "does not delete stacks"
   -- A group on two cards
   put the long id of group "Box" of card 1 of tStack into tGroup
   set the sharedBehavior of tGroup to true
   lock messages
   place tGroup onto card 2 of tStack
   unlock messages
   put TestPlan("{`changes`:[{`action`:`delete`,`object`:" & the id of tGroup & "}]}", tStack) into tPlan
   TestAssert "a group shown on two cards is not deleted", tPlan["ok"] is false and tPlan["problems"] contains "cards"
   put TestPlan("{`changes`:[{`action`:`delete`,`object`:" & the id of card 2 of tStack & "}]}", tStack) into tPlan
   TestAssert "a card that shows a shared group is not deleted", tPlan["ok"] is false and tPlan["problems"] contains "other cards show too"
   -- The last card
   put TestNewStack("xtaTestOneCard") into tStack
   put TestPlan("{`changes`:[{`action`:`delete`,`object`:" & the id of card 1 of tStack & "}]}", tStack) into tPlan
   TestAssert "the last card is not deleted", tPlan["ok"] is false and tPlan["problems"] contains "one card at least"
end TestPlanRefusesWhatUndoCannotPutBack

on TestPlanSaysWhatItWillDo
   local tStack, tPlan
   put TestUserStack() into tStack
   put TestPlan("{`changes`:[" & \
         "{`action`:`create`,`kind`:`check box`,`name`:`Agree`,`properties`:{`label`:`I agree`,`hilite`:true}}," & \
         "{`action`:`create`,`kind`:`card`,`name`:`Third`,`ref`:`c3`}," & \
         "{`action`:`create`,`kind`:`text area`,`name`:`Log`,`card`:`c3`,`rect`:[10,10,210,110],`custom_properties`:{`cMax`:5}}," & \
         "{`action`:`set`,`object`:" & the id of button "Go" of card 1 of tStack & ",`script`:`on mouseUp\n  answer 1\nend mouseUp`}" & \
         "]}", tStack) into tPlan
   TestDiagnostic tPlan["problems"]
   TestDiagnostic tPlan["lines"]
   TestAssert "the batch is checked", tPlan["ok"] is true and tPlan["problems"] is empty
   TestAssert "four lines", the number of lines of tPlan["lines"] is 4
   TestAssert "a kind named as the palette names it", line 1 of tPlan["lines"] contains "checkbox" and line 1 of tPlan["lines"] contains "Agree" \
         and line 1 of tPlan["lines"] contains "label, hilite"
   TestAssert "a new card", line 2 of tPlan["lines"] contains "card" and line 2 of tPlan["lines"] contains "Third"
   TestAssert "a control on the new card", line 3 of tPlan["lines"] contains "new card" and line 3 of tPlan["lines"] contains "cMax"
   TestAssert "a script set", line 4 of tPlan["lines"] contains "Go" and line 4 of tPlan["lines"] contains "a script of 3 lines"
   TestAssert "the stack named", tPlan["name"] is kUserStack
end TestPlanSaysWhatItWillDo

--------------------------------------------------------------------------------
-- Applying and undoing

on TestApplyAndUndoCreates
   local tStack, tDump, tPlan, tApplied, tUndone, tCard, tButton, tGroup, tMade, tSince, tWhy
   put TestUserStack() into tStack
   put xtaStackDump(tStack) into tDump
   put TestPlan("{`changes`:[" & \
         "{`action`:`create`,`kind`:`button`,`name`:`Save`,`rect`:[20,200,120,223],`script`:`on mouseUp\n  beep\nend mouseUp`}," & \
         "{`action`:`create`,`kind`:`group`,`name`:`Panel`,`ref`:`panel`}," & \
         "{`action`:`create`,`kind`:`label`,`name`:`Title`,`group`:`panel`,`properties`:{`text`:`Hello`,`textSize`:18}}," & \
         "{`action`:`create`,`kind`:`card`,`name`:`Third`,`ref`:`c3`}," & \
         "{`action`:`create`,`kind`:`list field`,`name`:`Items`,`card`:`c3`,`properties`:{`text`:[[`a`],[`b`]]}}," & \
         "{`action`:`set`,`object`:`stack`,`properties`:{`title`:`My Notes`},`custom_properties`:{`cVersion`:2}}" & \
         "]}", tStack) into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "the batch is checked", tPlan["ok"] is true
   put xtaBuildApply(tPlan) into tApplied
   TestDiagnostic tApplied["error"]
   TestDiagnostic tApplied["text"]
   TestAssert "applied", tApplied["ok"] is true and tApplied["entry"] is 1
   TestAssert "the summary", tApplied["summary"] is ("Applied 6 changes to the stack" && quote & kUserStack & quote)
   TestAssert "the model is told the ids", tApplied["text"] contains "(id"
   put xtaStackDump(tStack) into tMade

   put the long id of button "Save" of card 1 of tStack into tButton
   TestAssert "the button is made where it was asked", the rect of tButton is "20,200,120,223"
   TestAssert "with its script", the script of tButton contains "beep"
   put the long id of group "Panel" of card 1 of tStack into tGroup
   TestAssert "the label is in the group", there is a field "Title" of tGroup
   TestAssert "the label has the kind's properties", the lockText of field "Title" of tGroup and not the showBorder of field "Title" of tGroup
   TestAssert "and its own", field "Title" of tGroup is "Hello" and the textSize of field "Title" of tGroup is 18
   TestAssert "the new card", there is a card "Third" of tStack
   put the long id of card "Third" of tStack into tCard
   TestAssert "the list on the new card", field "Items" of tCard is ("a" & return & "b")
   TestAssert "the list is a list", the listBehavior of field "Items" of tCard
   TestAssert "the stack's title", the title of tStack is "My Notes" and the cVersion of tStack is 2
   TestAssert "the user is shown the new card", the long id of this card of tStack is tCard
   TestAssert "the IDE is told of the new controls", xtaTestTold() contains "ideNewControl" and xtaTestTold() contains "ideNewCard"
   TestAssert "the stack is marked as edited", kUserStack is among the lines of xtaTestEdited()

   -- The user did nothing since, so Undo does not ask: the new card was
   -- opened before the batch's prints were taken (the engine settles some
   -- of what is on a card when it first opens it). If it asks, the label
   -- says about what, and what changed in the stack since the batch.
   put TestDumpDifference(tMade, xtaStackDump(tStack)) into tSince
   put xtaBuildUndo(1, false) into tUndone
   TestDiagnostic tUndone["error"] & tUndone["changed"]
   put tUndone["error"] & return & tUndone["changed"] into tWhy
   if tSince is not empty then
      put return & "since the batch," && line 1 to 3 of tSince after tWhy
   end if
   TestAssert "undone" & TestWhy(tWhy), tUndone["ok"] is true and tUndone["undone"] contains 1
   TestAssertSameDump "the stack is as it was (gate 2)", tDump, xtaStackDump(tStack)
   TestAssert "the IDE is told they are gone", xtaTestTold() contains "ideControlDeleted" and xtaTestTold() contains "ideCardDeleted"
   put xtaBuildUndo(1, false) into tUndone
   TestAssert "undone only once", tUndone["ok"] is false and tUndone["error"] contains "undone already"
end TestApplyAndUndoCreates

on TestUndoDoesNotAskAfterTheNewCardOpens
   local tStack, tDump, tPlan, tApplied, tUndone
   put TestUserStack() into tStack
   put xtaStackDump(tStack) into tDump
   -- A field given a scrollbar on a card the batch makes: the engine
   -- settles its scrollbarWidth when the card first opens, which is not
   -- the user changing it
   put TestPlan("{`changes`:[" & \
         "{`action`:`create`,`kind`:`card`,`name`:`Third`,`ref`:`c3`}," & \
         "{`action`:`create`,`kind`:`field`,`name`:`Log`,`card`:`c3`,`properties`:{`vScrollbar`:true}}" & \
         "]}", tStack) into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "the batch is checked", tPlan["ok"] is true
   put xtaBuildApply(tPlan) into tApplied
   TestDiagnostic tApplied["error"]
   TestAssert "applied", tApplied["ok"] is true
   TestAssert "the user is shown the new card", the short name of this card of tStack is "Third"
   put xtaBuildUndo(tApplied["entry"], false) into tUndone
   TestAssert "undone without asking" & TestWhy(tUndone["error"] & return & tUndone["changed"]), tUndone["ok"] is true
   TestAssertSameDump "the stack is as it was", tDump, xtaStackDump(tStack)
end TestUndoDoesNotAskAfterTheNewCardOpens

on TestApplyAndUndoChangesAndDeletes
   local tStack, tDump, tPlan, tApplied, tUndone, tGo, tInner, tNotes, tCardId, tInnerId
   put TestUserStack() into tStack
   put xtaStackDump(tStack) into tDump
   put the long id of button "Go" of card 1 of tStack into tGo
   put the long id of field "Notes" of card 1 of tStack into tNotes
   put the id of button "Inner" of card 1 of tStack into tInnerId
   put the id of card 2 of tStack into tCardId
   put TestPlan("{`changes`:[" & \
         "{`action`:`set`,`object`:" & the id of tGo & ",`properties`:{`label`:`Start`,`textSize`:20,`layer`:1},`script`:`on mouseUp\n  answer 2\nend mouseUp`," & \
         "`custom_properties`:{`cCount`:7}}," & \
         "{`action`:`set`,`object`:" & the id of tNotes & ",`properties`:{`text`:`changed`,`backgroundColor`:`255,0,0`}}," & \
         "{`action`:`set`,`object`:" & the id of tNotes & ",`properties`:{`textStyle`:`bold`}}," & \
         "{`action`:`delete`,`object`:" & tInnerId & "}," & \
         "{`action`:`delete`,`object`:" & tCardId & "}" & \
         "]}", tStack) into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "the batch is checked", tPlan["ok"] is true
   put xtaBuildApply(tPlan) into tApplied
   TestDiagnostic tApplied["error"]
   TestAssert "applied", tApplied["ok"] is true
   TestAssert "the button changed", the label of tGo is "Start" and the textSize of tGo is 20 and the cCount of tGo is 7 \
         and the script of tGo contains "answer 2"
   TestAssert "the field changed", field "Notes" of tStack is "changed" and the textStyle of tNotes is "bold"
   TestAssert "the grouped button is gone", there is not a button id tInnerId of tStack
   TestAssert "the card is gone", there is not a card id tCardId of tStack
   TestAssert "a copy is kept", there is a stack kHoldStack

   put xtaBuildUndoAll(false) into tUndone
   TestDiagnostic tUndone["error"] & tUndone["changed"]
   TestAssert "undone", tUndone["ok"] is true
   TestAssert "the button is back in its group, with its id", there is a button id tInnerId of tStack \
         and the long id of the owner of button id tInnerId of tStack contains "group"
   TestAssert "the card is back, with its id and its place", the id of card 2 of tStack is tCardId
   TestAssertSameDump "the stack is as it was (gate 2)", tDump, xtaStackDump(tStack)
   TestAssert "the copy is used up", the number of cards of stack kHoldStack is 1 and the number of controls of card 1 of stack kHoldStack is 0
end TestApplyAndUndoChangesAndDeletes

on TestUndoANewStack
   local tPlan, tApplied, tUndone
   put TestPlan("{`changes`:[" & \
         "{`action`:`create`,`kind`:`stack`,`name`:`xtaTestMade`,`rect`:[100,100,500,400]}," & \
         "{`action`:`create`,`kind`:`button`,`name`:`OK`}," & \
         "{`action`:`create`,`kind`:`card`,`name`:`Two`}" & \
         "]}", empty) into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "a batch that makes its stack needs none", tPlan["ok"] is true and tPlan["newStack"] is true
   put xtaBuildApply(tPlan) into tApplied
   TestDiagnostic tApplied["error"]
   TestAssert "applied", tApplied["ok"] is true
   TestAssert "the stack is made", there is a stack "xtaTestMade"
   TestAssert "with its button", there is a button "OK" of card 1 of stack "xtaTestMade"
   TestAssert "and its cards", the number of cards of stack "xtaTestMade" is 2
   TestAssert "the button in the middle of the card", the loc of button "OK" of card 1 of stack "xtaTestMade" is "200,150"
   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`stack`,`name`:`xtaTestMade`}]}", empty) into tPlan
   TestAssert "a stack of that name is open now", tPlan["ok"] is false and tPlan["problems"] contains "open already"
   put xtaBuildUndo(tApplied["entry"], false) into tUndone
   TestDiagnostic tUndone["error"]
   TestAssert "undone", tUndone["ok"] is true
   TestAssert "the stack is gone", there is not a stack "xtaTestMade"
end TestUndoANewStack

on TestABatchThatFailsChangesNothing
   local tStack, tDump, tPlan, tApplied
   put TestUserStack() into tStack
   put xtaStackDump(tStack) into tDump
   -- A layer is not tried on a stand-in, so this one fails when it is made
   put TestPlan("{`changes`:[" & \
         "{`action`:`create`,`kind`:`button`,`name`:`One`}," & \
         "{`action`:`set`,`object`:" & the id of field "Notes" of card 1 of tStack & ",`properties`:{`text`:`gone`}}," & \
         "{`action`:`delete`,`object`:" & the id of button "Go" of card 1 of tStack & "}," & \
         "{`action`:`create`,`kind`:`button`,`name`:`Two`,`properties`:{`layer`:`top of the world`}}" & \
         "]}", tStack) into tPlan
   TestAssert "the batch is checked", tPlan["ok"] is true
   put xtaBuildApply(tPlan) into tApplied
   TestDiagnostic tApplied["error"]
   TestAssert "it failed", tApplied["ok"] is false and tApplied["error"] contains "Nothing was changed: change 4"
   TestAssertSameDump "the stack is as it was", tDump, xtaStackDump(tStack)
   TestAssert "nothing in the journal", the number of elements of xtaBuildEntries() is 0
end TestABatchThatFailsChangesNothing

on TestUndoSaysWhatTheUserChanged
   local tStack, tPlan, tApplied, tUndone, tButton
   put TestUserStack() into tStack
   put TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`name`:`Mine`}]}", tStack) into tPlan
   put xtaBuildApply(tPlan) into tApplied
   TestAssert "applied", tApplied["ok"] is true
   put the long id of button "Mine" of card 1 of tStack into tButton
   set the label of tButton to "Edited by hand"
   put xtaBuildUndo(tApplied["entry"], false) into tUndone
   TestDiagnostic tUndone["changed"]
   TestAssert "not undone: the user changed the button", tUndone["ok"] is false and tUndone["changed"] contains "Mine"
   TestAssert "the button is still there", there is a tButton
   put xtaBuildUndo(tApplied["entry"], true) into tUndone
   TestAssert "undone when the user says so", tUndone["ok"] is true and there is not a button "Mine" of card 1 of tStack
end TestUndoSaysWhatTheUserChanged

on TestUndoTakesLaterEntriesFirst
   local tStack, tDump, tPlan, tApplied, tUndone, tEntries
   put TestUserStack() into tStack
   put xtaStackDump(tStack) into tDump
   put xtaBuildApply(TestPlan("{`changes`:[{`action`:`create`,`kind`:`button`,`name`:`First`}]}", tStack)) into tApplied
   TestAssert "the first applied", tApplied["ok"] is true
   put xtaBuildApply(TestPlan("{`changes`:[{`action`:`set`,`object`:" & the id of button "First" of card 1 of tStack & \
         ",`properties`:{`label`:`Changed`}}]}", tStack)) into tApplied
   TestAssert "the second applied", tApplied["ok"] is true and tApplied["entry"] is 2
   put xtaBuildUndo(1, false) into tUndone
   TestDiagnostic tUndone["error"] & tUndone["changed"]
   TestAssert "both undone, the later first", tUndone["ok"] is true and tUndone["undone"] is ("2" & return & "1" & return)
   put xtaBuildEntries() into tEntries
   TestAssert "the journal says so", tEntries[1]["state"] is "undone" and tEntries[2]["state"] is "undone"
   TestAssertSameDump "the stack is as it was", tDump, xtaStackDump(tStack)
   put xtaBuildUndoAll(false) into tUndone
   TestAssert "nothing left to undo", tUndone["ok"] is false and tUndone["error"] contains "nothing to undo"
end TestUndoTakesLaterEntriesFirst

--------------------------------------------------------------------------------
-- Checkpoints

on TestCheckpointBringsAStackBack
   local tStack, tFile, tCheckpoint, tProblem, tDump
   -- The folder of the checkpoints is made the user's alone with chmod,
   -- through shell()
   TestSkipIfNot "shell"
   put TestUserStack() into tStack
   -- A stack never saved, then one saved in a file
   put xtaStackDump(tStack) into tDump
   put xtaCheckpointSave(tStack) into tCheckpoint
   TestDiagnostic the result
   TestAssert "a checkpoint of an unsaved stack", tCheckpoint is not empty and there is a file tCheckpoint
   TestAssert "the stack is still unsaved", the fileName of tStack is empty
   create button "Extra" in card 1 of tStack
   put "changed" into field "Notes" of card 1 of tStack
   put xtaCheckpointRestore(tCheckpoint, tStack) into tProblem
   TestDiagnostic tProblem
   TestAssert "restored", tProblem is empty
   put the long id of stack kUserStack into tStack
   TestAssert "the button made since is gone", there is not a button "Extra" of card 1 of tStack
   TestAssert "the field is as it was", field "Notes" of card 1 of tStack is "hello"
   TestAssert "the stack is still unsaved after it", the fileName of tStack is empty
   TestAssertSameDump "the stack is as it was", tDump, xtaStackDump(tStack)

   put specialFolderPath("temporary") & "/xtaTestUser-" & the milliseconds & ".livecode" into tFile
   save tStack as tFile
   put xtaCheckpointSave(tStack) into tCheckpoint
   TestAssert "a checkpoint of a saved stack", tCheckpoint is not empty and tCheckpoint is not tFile
   TestAssert "the stack keeps its file", the fileName of tStack is tFile
   delete button "Go" of card 1 of tStack
   put xtaCheckpointRestore(tCheckpoint, tStack) into tProblem
   TestAssert "restored", tProblem is empty
   TestAssert "the deleted button is back", there is a button "Go" of card 1 of stack kUserStack
   TestAssert "the stack keeps its file after it", the fileName of stack kUserStack is tFile
   delete file tFile
   xtaBuildCleanup
   TestAssert "the checkpoint goes when the assistant is turned off", there is not a file tCheckpoint
end TestCheckpointBringsAStackBack

--------------------------------------------------------------------------------
-- Runs

on TestRunInTheSandbox
   local tRun, tRan
   put "before" into msg
   put TestRunPlan("{`code`:`put 6 * 7`}", empty) into tRun
   TestDiagnostic tRun["problems"]
   TestAssert "a run is checked", tRun["ok"] is true and tRun["where"] is "sandbox"
   put xtaRunCode(tRun) into tRan
   TestDiagnostic tRan["text"]
   TestAssert "it ran", tRan["ok"] is true and tRan["ran"] is true
   TestAssert "what it put", tRan["output"] is 42
   TestAssert "the Message Box is as it was", msg is "before"
   TestAssert "the sandbox is gone", there is not a stack kSandboxStack

   put xtaRunCode(TestRunPlan("{`code`:`return double(21)`,`handlers`:`function double pX\n  return pX * 2\nend double`}", empty)) into tRan
   TestDiagnostic tRan["text"]
   TestAssert "what it returned, from a handler of its own", tRan["ok"] is true and tRan["value"] is 42 \
         and tRan["text"] contains "It returned: 42"

   put xtaRunCode(TestRunPlan("{`code`:`local tX\nput 1 into tX\nput tX + double(\`abc\`) into tX`," & \
         "`handlers`:`function double pX\n  return pX * 2\nend double`}", empty)) into tRan
   TestDiagnostic tRan["text"]
   TestAssert "an error", tRan["ok"] is false and tRan["ran"] is true and tRan["errorText"] is not empty
   TestAssert "its line in the handlers", tRan["errorText"] contains "line 2 of the handlers"
   TestAssert "and in the code", tRan["errorText"] contains "line 3 of the code"
   TestAssert "the sandbox is gone after an error too", there is not a stack kSandboxStack

   -- With no handlers, the code is the sandbox's first lines (this was
   -- one line out, in the real IDE)
   put xtaRunCode(TestRunPlan("{`code`:`local tX\nput 1 into tX\nput tX + \`abc\` into tX`}", empty)) into tRan
   TestDiagnostic tRan["text"]
   TestAssert "with no handlers, the line in the code", tRan["errorText"] contains "line 3 of the code"
   TestAssert "and the lines around it", tRan["errorText"] contains ">3:"
   TestAssert "an error is not a stop", tRan["stopped"] is false and tRan["text"] contains "stopped at an error"
end TestRunInTheSandbox

on TestRunPlanRefusesMistakes
   local tRun, tStack
   put TestRunPlan("{`code`:`on mouseUp\n beep\nend mouseUp`}", empty) into tRun
   TestAssert "code is statements", tRun["ok"] is false and tRun["problems"] contains "statements"
   put TestRunPlan("{`code`:`repeat with tX = 1\nend if`}", empty) into tRun
   TestDiagnostic tRun["problems"]
   TestAssert "code that does not compile", tRun["ok"] is false and tRun["problems"] contains "does not compile"
   put TestRunPlan("{`code`:`beep`,`where`:`moon`}", empty) into tRun
   TestAssert "where", tRun["ok"] is false and tRun["problems"] contains "sandbox"
   put TestRunPlan("{`code`:`beep`,`handlers`:`on xtaSandboxRun\nend xtaSandboxRun`}", empty) into tRun
   TestAssert "the sandbox's own handler", tRun["ok"] is false and tRun["problems"] contains "may not define"
   put TestRunPlan("{`code`:`beep`,`handlers`:`beep`}", empty) into tRun
   TestAssert "handlers are handlers", tRun["ok"] is false and tRun["problems"] contains "whole handlers"
   put TestUserStack() into tStack
   put TestRunPlan("{`code`:`beep`,`where`:`stack`,`handlers`:`on x\nend x`}", tStack) into tRun
   TestAssert "no handlers on the user's stack", tRun["ok"] is false and tRun["problems"] contains "sandbox only"
   put TestRunPlan("{`code`:`beep`,`where`:`stack`,`target`:99999}", tStack) into tRun
   TestAssert "a target that is not there", tRun["ok"] is false and tRun["problems"] contains "no card or control"
   put TestRunPlan("{`code`:`beep`,`where`:`stack`}", empty) into tRun
   TestAssert "no stack open", tRun["ok"] is false and tRun["problems"] contains "No stack"
end TestRunPlanRefusesMistakes

on TestRunOnTheStackCanBeUndone
   local tStack, tDump, tRun, tRan, tUndone, tEntries
   -- A run on the stack saves a checkpoint first (shell(), as above)
   TestSkipIfNot "shell"
   put TestUserStack() into tStack
   put xtaStackDump(tStack) into tDump
   put TestRunPlan("{`code`:`put the short name of me\nput 3 into field \`Notes\`\ncreate button \`Made by code\``,`where`:`stack`}", tStack) into tRun
   TestDiagnostic tRun["problems"]
   TestAssert "a run on the stack is checked", tRun["ok"] is true and tRun["stack"] is tStack
   TestAssert "as the current card", tRun["target"] is the long id of card 1 of tStack
   put xtaRunCode(tRun) into tRan
   TestDiagnostic tRan["text"]
   TestAssert "it ran", tRan["ok"] is true
   TestAssert "as the card", tRan["output"] is "Main"
   TestAssert "on the stack", field "Notes" of card 1 of tStack is 3 and there is a button "Made by code" of card 1 of tStack
   put xtaBuildEntries() into tEntries
   TestAssert "it is in the journal", tRan["entry"] is 1 and tEntries[1]["kind"] is "run"
   put xtaBuildUndo(tRan["entry"], false) into tUndone
   TestDiagnostic tUndone["error"] & tUndone["changed"]
   TestAssert "undone", tUndone["ok"] is true
   put the long id of stack kUserStack into tStack
   TestAssertSameDump "the stack is as it was (gate 2)", tDump, xtaStackDump(tStack)
end TestRunOnTheStackCanBeUndone

on TestRiskScan
   TestAssert "nothing risky", TestRisks("put 1 + 1 into tX" & return & "set the label of button 1 to tX") is empty
   TestAssert "files", "files" is among the lines of TestRisks("put url (`file:/tmp/x`) into tX")
   TestAssert "files written", "files" is among the lines of TestRisks("open file tPath for write")
   TestAssert "the network", "the network" is among the lines of TestRisks("put url `https://example.com` into tX")
   TestAssert "a url of a variable", "files or the network" is among the lines of TestRisks("put url tWhere into tX")
   TestAssert "other programs", "other programs" is among the lines of TestRisks("get shell(`ls`)")
   TestAssert "saving", "stacks saved, closed or deleted" is among the lines of TestRisks("save this stack")
   TestAssert "quitting", "quitting" is among the lines of TestRisks("quit")
   TestAssert "the clipboard", "the clipboard" is among the lines of TestRisks("set the clipboardData[`text`] to 1")
   TestAssert "later", "messages sent for later" is among the lines of TestRisks("send `tick` to me in 1 second")
   TestAssert "code built as it runs", "code it builds as it runs" is among the lines of TestRisks("do tScript")
end TestRiskScan

--------------------------------------------------------------------------------
-- The debugger, and turning off

on TestDebugStateWhenNotPaused
   local tState
   put xtaDebugState() into tState
   TestAssert "not paused", tState["paused"] is false and tState["text"] contains "not paused"
end TestDebugStateWhenNotPaused

on TestDebugStateWhenPaused
   local tStack, tButton, tStub, tState, tPlan
   put TestUserStack() into tStack
   put the long id of button "Go" of card 1 of tStack into tButton
   set the script of tButton to "on xtaTestPause pName" & return & \
         "   local tCount, tList" & return & \
         "   put 42 into tCount" & return & \
         "   put " & quote & "one" & quote & " into tList[" & quote & "first" & quote & "]" & return & \
         "   breakpoint" & return & \
         "end xtaTestPause"
   -- As the IDE's debugger takes a breakpoint (revdebuggerlibrary's
   -- traceBreak): the traceStack is set while it is paused, and the
   -- assistant's tools run inside the pause. Here they run in traceBreak
   -- itself, which then goes on (the traceReturn).
   put "local sState, sPlanJson, sStack, sPlan" & return & \
         "on traceBreak pHandler, pLine" & return & \
         "   set the traceStack to " & quote & kUserStack & quote & return & \
         "   put xtaDebugState() into sState" & return & \
         "   put xtaBuildPlan(xtaJsonParse(sPlanJson), sStack) into sPlan" & return & \
         "   set the traceStack to empty" & return & \
         "   set the traceReturn to true" & return & \
         "end traceBreak" & return & \
         "command xtaTestSetPlan pJson, pStack" & return & "put pJson into sPlanJson" & return & "put pStack into sStack" & return & \
         "end xtaTestSetPlan" & return & \
         "function xtaTestPaused" & return & "return sState" & return & "end xtaTestPaused" & return & \
         "function xtaTestPausedPlan" & return & "return sPlan" & return & "end xtaTestPausedPlan" into tStub
   -- A frontscript, as the IDE's debugger is (revdebuggerlibrary inserts
   -- itself into front): while a script is paused the engine sends no
   -- message to the objects in the paused stack's window, and to their
   -- libraries and backscripts, but a frontscript sees it first. A stack
   -- with no window (an engine run with -ui) would not show the
   -- difference; the web engine's stacks all have one.
   create invisible stack "revXtaTestDebugger"
   set the script of stack "revXtaTestDebugger" to tStub
   insert the script of stack "revXtaTestDebugger" into front
   xtaTestSetPlan TestJson("{`changes`:[{`action`:`set`,`object`:" & the id of tButton & ",`script`:`on mouseUp\nend mouseUp`}]}"), tStack
   -- Sent as the Message Box sends what is typed into it, from a stack
   -- of the IDE's, which the user's handlers then follow
   create invisible stack "revXtaTestMessageBox"
   set the script of stack "revXtaTestMessageBox" to "command xtaTestType pScript, pObject" & return & \
         "send script pScript to pObject" & return & "end xtaTestType"
   dispatch "xtaTestType" to stack "revXtaTestMessageBox" with "xtaTestPause" && quote & "Ann" & quote, tButton
   put xtaTestPaused() into tState
   TestDiagnostic tState["text"]
   TestAssert "paused", tState["paused"] is true
   TestAssert "where", tState["handler"] is "xtaTestPause" and tState["line"] is 5 and tState["object"] is tButton
   TestAssert "the summary", tState["summary"] contains "xtaTestPause" and tState["summary"] contains "line 5"
   TestAssert "its parameter", tState["text"] contains ("pName (parameter) =" && quote & "Ann" & quote)
   TestAssert "its locals", tState["text"] contains ("tCount (local) =" && quote & "42" & quote)
   TestAssert "an array's keys", tState["text"] contains ("[first]=" & quote & "one" & quote)
   TestAssert "the script around the line", tState["text"] contains ">5:"
   put xtaTestPausedPlan() into tPlan
   TestDiagnostic tPlan["problems"]
   TestAssert "a running script is not set", tPlan["ok"] is false and tPlan["problems"] contains "is running"
   put xtaDebugState() into tState
   TestAssert "not paused after it", tState["paused"] is false
end TestDebugStateWhenPaused

on TestCleanupLeavesNothing
   local tStack, tApplied, tRan
   -- A run on the stack saves a checkpoint first (shell(), as above)
   TestSkipIfNot "shell"
   put TestUserStack() into tStack
   put xtaBuildApply(TestPlan("{`changes`:[{`action`:`delete`,`object`:" & the id of button "Go" of card 1 of tStack & "}]}", tStack)) into tApplied
   TestAssert "applied", tApplied["ok"] is true
   put xtaRunCode(TestRunPlan("{`code`:`put 1`,`where`:`stack`}", tStack)) into tRan
   TestAssert "ran", tRan["ok"] is true
   xtaBuildCleanup
   TestAssert "the journal is empty", the number of elements of xtaBuildEntries() is 0
   TestAssert "the copies are gone", there is not a stack kHoldStack
   TestAssert "what was applied stays", there is not a button "Go" of card 1 of stack kUserStack
end TestCleanupLeavesNothing

--------------------------------------------------------------------------------
-- Helpers

-- JSON written with ` for each double quote, checked as a batch
private function TestPlan pJson, pStack
   return xtaBuildPlan(xtaJsonParse(TestJson(pJson)), pStack)
end TestPlan

private function TestJson pJson
   replace "`" with quote in pJson
   return pJson
end TestJson

-- What xtaRiskScan finds in code written with ` for each double quote
private function TestRisks pCode
   replace "`" with quote in pCode
   return xtaRiskScan(pCode)
end TestRisks

private function TestRunPlan pJson, pStack
   replace "`" with quote in pJson
   return xtaRunPlan(xtaJsonParse(pJson), pStack)
end TestRunPlan

-- A user's stack: card "Main" with a button with a script, a field with a
-- custom property, and a group of a button and a field; card "Other" with
-- a graphic; a custom property set on the stack
private function TestUserStack
   local tStack, tCard, tGroup, tObject
   put TestNewStack(kUserStack) into tStack
   put the long id of card 1 of tStack into tCard
   set the name of tCard to "Main"
   create button "Go" in tCard
   put it into tObject
   set the script of tObject to "on mouseUp" & return & "  beep" & return & "end mouseUp"
   set the rect of tObject to "10,10,90,33"
   create field "Notes" in tCard
   put it into tObject
   set the rect of tObject to "10,40,200,100"
   set the text of tObject to "hello"
   set the cNote of tObject to "kept"
   create group "Box" in tCard
   put it into tGroup
   create button "Inner" in tGroup
   put it into tObject
   set the rect of tObject to "220,10,300,33"
   create field "InnerF" in tGroup
   put it into tObject
   set the rect of tObject to "220,40,300,80"
   set the text of tObject to "inside"
   set the defaultStack to kUserStack
   create card "Other"
   create graphic "Shape" in the long id of card "Other" of tStack
   put it into tObject
   set the style of tObject to "oval"
   go tCard
   set the customProperties["cData"] of tStack to TestArray()
   return tStack
end TestUserStack

private function TestArray
   local tArray
   put 1 into tArray["one"]
   put "two" & return & "lines" into tArray["two"]
   return tArray
end TestArray

private function TestNewStack pName
   create stack pName
   set the width of stack pName to 400
   set the height of stack pName to 300
   return the long id of stack pName
end TestNewStack

-- That two dumps are the same; when they are not, the label says where
-- (the first lines that differ), since the job's log shows the labels of
-- the checks that failed and not the diagnostics
private command TestAssertSameDump pLabel, pBefore, pAfter
   local tDifference
   put TestDumpDifference(pBefore, pAfter) into tDifference
   TestAssert pLabel & TestWhy(line 1 to 3 of tDifference), tDifference is empty
end TestAssertSameDump

-- The first lines that differ between two dumps (the diagnostics show
-- them whole), or empty
private function TestDumpDifference pBefore, pAfter
   local tIndex, tShown, tText
   if pBefore is pAfter then
      return empty
   end if
   put 0 into tShown
   repeat with tIndex = 1 to max(the number of lines of pBefore, the number of lines of pAfter)
      if line tIndex of pBefore is not line tIndex of pAfter then
         TestDiagnostic "line" && tIndex & ":" && line tIndex of pBefore && "/" && line tIndex of pAfter
         put "line" && tIndex & ":" && char 1 to 160 of line tIndex of pBefore && "/" && char 1 to 160 of line tIndex of pAfter & return after tText
         add 1 to tShown
         if tShown > 8 then
            exit repeat
         end if
      end if
   end repeat
   return tText
end TestDumpDifference

-- pWhy as the end of a check's label: empty when it has nothing to say,
-- else its lines in parentheses, on one line
private function TestWhy pWhy
   filter lines of pWhy without empty
   if pWhy is empty then
      return empty
   end if
   replace return with "; " in pWhy
   return " (" & pWhy & ")"
end TestWhy

-- Windows are kept whole on the screen (xtaOnScreenRect): one that fits
-- stays where it is; one above the top (a new stack's rect 0,0,...) comes
-- down below the title bar's room; one past an edge comes in; a larger one
-- is made smaller only when it may be, never below its least size; and an
-- engine with no screen leaves it alone
on TestWindowsAreKeptOnScreen
   local tArea
   put "0,0,1280,680" into tArea
   TestAssert "a window that fits stays", \
         xtaOnScreenRect("300,200,700,500", "292,170,708,508", tArea, empty) is "300,200,700,500"
   TestAssert "one at the top is moved down by its title bar", \
         xtaOnScreenRect("0,0,400,300", "0,0,400,300", tArea, empty) is "8,32,408,332"
   TestAssert "the frame it has decides the room", \
         xtaOnScreenRect("0,0,400,300", "-10,-40,410,310", tArea, empty) is "10,40,410,340"
   TestAssert "one past the bottom right comes in", \
         xtaOnScreenRect("1100,600,1400,800", "1100,600,1400,800", tArea, empty) is "972,472,1272,672"
   TestAssert "a tall one keeps its size and goes to the top", \
         xtaOnScreenRect("100,100,660,900", "100,100,660,900", tArea, empty) is "100,32,660,832"
   TestAssert "a tall resizable one is made shorter", \
         xtaOnScreenRect("100,100,660,900", "100,100,660,900", tArea, "460,520") is "100,32,660,672"
   TestAssert "never below its least height", \
         xtaOnScreenRect("100,100,660,900", "100,100,660,900", "0,0,1280,400", "460,520") is "100,32,660,552"
   TestAssert "on a second screen", \
         xtaOnScreenRect("1200,-50,1600,250", "1200,-50,1600,250", "1280,0,2560,1040", empty) is "1288,32,1688,332"
   TestAssert "no screen, no move", xtaOnScreenRect("0,0,400,300", "0,0,400,300", "0,0,0,0", empty) is empty
end TestWindowsAreKeptOnScreen
