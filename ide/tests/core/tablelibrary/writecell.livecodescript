script "TableLibraryWriteCell"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond, a fork of LiveCode Community.

LiveCode is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

LiveCode is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with LiveCode.  If not see <http://www.gnu.org/licenses/>.  */

-- OXT-Beyond: what is typed into a cell of a table field goes into that
-- cell (revWriteCellField of the table library). Up to 0.2.8-dp.2, and in
-- LiveCode Community (LiveCode bug 20494), a cell that was not in the text
-- yet, such as the second column of an empty row above rows with text, got
-- nothing: what was typed went into the start of the next row and a
-- character of the last cell was doubled.

constant kStack = "TestTableWriteCellStack"

on TestSetup
   create invisible stack kStack
   set the defaultStack to kStack
   create field "Table"
   set the tabStops of field "Table" to 100
   set the dontWrap of field "Table" to true
   set the cREVGeneral["table"] of field "Table" to true
   set the cREVTable["celledit"] of field "Table" to true
   set the cREVTable["cellformat"] of field "Table" to false
end TestSetup

on TestTeardown
   if there is a stack kStack then delete stack kStack
end TestTeardown

-- As the library does when a cell has been typed in and is left: the
-- cell's own field holds the new text, and the table remembers which cell
-- it is and what it showed.
private command __Type pColumn, pRow, pText
   local tTable, tCell
   set the defaultStack to kStack
   put the long id of field "Table" of stack kStack into tTable
   set the cREVTable["currentxcell"] of tTable to pColumn
   set the cREVTable["currentycell"] of tTable to pRow
   set the cREVTable["currentview"] of tTable to the htmlText of tTable
   put "revCell-" & pColumn & comma & pRow into tCell
   lock messages
   create field tCell
   put pText into field tCell
   unlock messages
   revWriteCellField tTable
   lock messages
   if there is a field tCell then delete field tCell
   unlock messages
end __Type

private function __Table
   local tText
   put the text of field "Table" of stack kStack into tText
   replace tab with "|" in tText
   replace return with "/" in tText
   return tText
end __Table

on TestCellsThatAreThere
   put "a1" & tab & "b1" & tab & "c1" & return & "a2" & tab & "b2" & tab & "c2" into field "Table" of stack kStack
   __Type 2, 1, "B1"
   TestAssert "a cell in the middle of a row", __Table() is "a1|B1|c1/a2|b2|c2"
   __Type 3, 2, "C2"
   TestAssert "the last cell", __Table() is "a1|B1|c1/a2|b2|C2"
   __Type 1, 2, "A2"
   TestAssert "the first cell of a row", __Table() is "a1|B1|c1/A2|b2|C2"
end TestCellsThatAreThere

on TestACellPastTheEndOfAnEmptyRow
   put return & "a2" & tab & "b2" & tab & "c2" & return & "a3" & tab & "b3" into field "Table" of stack kStack
   __Type 2, 1, "B1"
   TestAssert "the second column of an empty first row", __Table() is "|B1/a2|b2|c2/a3|b3"
   __Type 3, 1, "C1"
   TestAssert "and the third", __Table() is "|B1|C1/a2|b2|c2/a3|b3"
end TestACellPastTheEndOfAnEmptyRow

on TestACellPastTheEndOfAShorterRow
   put "a1" & return & "a2" & tab & "b2" & tab & "c2" into field "Table" of stack kStack
   __Type 3, 1, "C1"
   TestAssert "a column past the end of a shorter row", __Table() is "a1||C1/a2|b2|c2"
end TestACellPastTheEndOfAShorterRow

on TestARowBelowTheLast
   put "a1" & tab & "b1" into field "Table" of stack kStack
   __Type 2, 3, "B3"
   TestAssert "a row below the last one", __Table() is "a1|b1//|B3"
end TestARowBelowTheLast

on TestAnEmptyTable
   __Type 1, 1, "A1"
   TestAssert "the first cell of an empty table", __Table() is "A1"
   __Type 2, 2, "B2"
   TestAssert "then a cell below and beside it", __Table() is "A1/|B2"
end TestAnEmptyTable
