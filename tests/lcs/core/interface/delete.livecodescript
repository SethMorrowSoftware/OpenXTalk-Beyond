script "CoreInterfaceDelete"
/*
Copyright (C) 2017 LiveCode Ltd.

This file is part of LiveCode.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

on TestDeleteStackWithSubstack
	local tMainstack
	create stack
	put the short name of it into tMainstack
	
	local tScript
	put "on closeStack" into tScript
	put return & "local tTarget, tStack" after tScript
	put return & "put the long id of the target into tTarget" after tScript
	put return & "get wordOffset(" & quote & "stack" & quote & ", tTarget)" after tScript
	put return & "put word it to (it + 1) of tTarget into tStack" after tScript
	put return & "get the mainstack of stack tStack" after tScript
	put return & "end closeStack" after tScript
	
	create stack
	set the script of card 1 of it to tScript
	set the mainstack of it to tMainstack

	delete stack tMainstack
	
	TestAssert "delete stack with substack no crash", true
end TestDeleteStackWithSubstack

on TestDeleteSelectedObjects
	create stack
	set the defaultStack to the short name of it
	
	create button
	create field
	select button 1 and field 1
	
	delete
	
	TestAssert "delete selected objects", the number of controls is 0
end TestDeleteSelectedObjects

local sGroup

on TestDeleteSelectedCantDelete
	create stack
	set the defaultStack to the short name of it
	
	create button
	
	create group
	put it into sGroup
	
	create field in sGroup
	set the cantDelete of sGroup to true
	
	select button 1
	delete
	
	TestAssertThrow "can't delete group with cantDelete true", "__TestDeleteGroup", \
      the long id me, "EE_OBJECT_CANTREMOVE"
	
	local tThereIsAGroup
	put there is a sGroup into tThereIsAGroup
		
	undo
	
	TestAssert "undo previous delete after failed delete", there is a button 1
end TestDeleteSelectedCantDelete

on __TestDeleteGroup
	select sGroup
	delete
end __TestDeleteGroup

on TestUndoAfterDeleteNothing
	create stack
	set the defaultStack to the short name of it
	
	create button
	select button 1
	delete

	select empty
	delete
	undo
	
	TestAssert "undo previous delete after failed delete", there is a button 1
end TestUndoAfterDeleteNothing

on TestDeleteComboBox
	create stack
	set the defaultStack to the short name of it
	
	create button
	set the style of it to "menu"
	set the menumode of it to "combobox"
	select it
	delete
	undo
		
	TestAssert "undo delete of combo box", there is a button 1
end TestDeleteComboBox

on TestDeleteUndoChanged
	create stack
	set the defaultStack to the short name of it
	set the script of this card to \ 
		"on undoChanged; set the cCardReceived of this stack to true; end undoChanged"
	
	create button
	set the script of it to \ 
		"on undoChanged; set the cCardReceived of this stack to false; end undoChanged"
	select it
	delete

	TestAssert "undoChanged sent to current card", the cCardReceived of this stack
end TestDeleteUndoChanged
-- OXT-Beyond: a script that deletes the group of the control its message
-- was sent to, while that message is still being handled, freed the
-- control under the message: the engine went on to use it, reading and
-- writing freed memory, and crashed when that memory had been given to
-- something else (mwieder and tperry2x, openxtalk.org, the Script
-- Editor's Breakpoints pane, whose click rebuilds the pane). The control
-- now lives until its message is done, as a control whose own deletion a
-- script asks for always has. A use of freed memory need not crash, so
-- these tests also run under valgrind on Linux (tools/ci/memcheck_tests.py,
-- in build-linux.yml), which on 0.2.7-rc.6.9 reports an invalid read and
-- an invalid write for each. (A deleted control is not "the target" any
-- more, before or after the fix: the handler does not ask for it.)
on TestDeleteGroupOfTarget
	create stack
	set the defaultStack to the short name of it
	
	create group "G"
	create button "B" in group "G"
	set the script of this card to \
		"on mouseUp" & return & \
		"   if the short name of the target is not " & quote & "B" & quote & " then exit mouseUp" & return & \
		"   delete group " & quote & "G" & quote & return & \
		"   set the cControlsAfterDelete of this stack to the number of controls of this card" & return & \
		"end mouseUp"
	
	send "mouseUp" to button "B"
	
	TestAssert "delete the group of the target: the group is gone", there is not a group "G"
	TestAssert "delete the group of the target: its controls are gone", the number of controls of this card is 0
	TestAssert "delete the group of the target: the handler goes on after the delete", \
		the cControlsAfterDelete of this stack is 0
end TestDeleteGroupOfTarget

-- The same for a stack deleted by a library while its card is the target:
-- the card was freed with its stack under the card's message
on TestDeleteStackOfTarget
	local tStack, tLibrary
	create stack
	put the short name of it into tStack
	
	create stack
	put the short name of it into tLibrary
	set the script of stack tLibrary to \
		"on mouseUp" & return & \
		"   if the short name of the owner of the target is not " & quote & tStack & quote & " then pass mouseUp" & return & \
		"   delete stack " & quote & tStack & quote & return & \
		"   set the cGoneAfterDelete of stack " & quote & tLibrary & quote & " to (there is not a stack " & quote & tStack & quote & ")" & return & \
		"end mouseUp"
	start using stack tLibrary
	
	send "mouseUp" to card 1 of stack tStack
	stop using stack tLibrary
	
	TestAssert "delete the stack of the target: the stack is gone", there is not a stack tStack
	TestAssert "delete the stack of the target: the handler goes on after the delete", \
		the cGoneAfterDelete of stack tLibrary is true
end TestDeleteStackOfTarget
