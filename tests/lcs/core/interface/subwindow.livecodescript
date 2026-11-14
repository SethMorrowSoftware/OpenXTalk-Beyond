script "CoreInterfaceSubwindow"
/*
Copyright (C) 2016 LiveCode Ltd.

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

on TestSubwindowPropagatesErrors
	create stack "TestStack"
	set the script of stack "TestStack" to "on openStack; throw red; end openStack"
	try
		palette stack "TestStack"
	catch tError
	end try
	TestAssert "Error during subwindow propagates to caller", tError is "red"
end TestSubwindowPropagatesErrors

-- OXT-Beyond: "popup" of a field took the field for a stack and crashed
-- the engine (a HyperCard stack's "popUp 1", made for an external, did
-- it as a card's button was clicked). An object that is neither a button
-- nor a stack is now taken by its value, as a stack's name, as "popup 1"
-- and "popup "name"" always were
on TestSubwindowPopupField
   local tError, tResult
   create stack "TestPopupField"
   set the defaultStack to "TestPopupField"
   create field "F"
   put "TestPopupNoSuchStack" into field "F"
   try
      popup field "F"
      put the result into tResult
   catch tError
   end try
   TestAssert "popup of a field does not stop with an error", tError is empty
   TestAssert "popup of a field looks for a stack named by its text", tResult is "can't find stack"
   put empty into tError
   put empty into tResult
   try
      popup 1
      put the result into tResult
   catch tError
   end try
   TestAssert "popup of a number is as before", tError is empty and tResult is "can't find stack"
   put empty into tError
   try
      popup card 1
   catch tError
   end try
   TestAssert "popup of a card still stops with an error, as before", tError is not empty
   delete stack "TestPopupField"
end TestSubwindowPopupField
