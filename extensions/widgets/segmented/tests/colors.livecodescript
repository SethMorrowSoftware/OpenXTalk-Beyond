script "SegmentedControlColors"
/*
Copyright (C) 2015 LiveCode Ltd.

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

on TestSetup
	TestLoadExtension "com.livecode.library.iconsvg"
	TestLoadExtension "com.livecode.library.widgetutils"
	TestLoadExtension "com.livecode.library.scriptitems"
	TestLoadExtension "com.livecode.widget.segmented"
end TestSetup

function randomColor
	local tColorArray
	repeat with x = 1 to 3
		put random(256) - 1 into tColorArray[x]
	end repeat
	combine tColorArray with comma
	return tColorArray
end randomColor

on TestColors
	create stack
	create widget as "com.livecode.widget.segmented"
	
	local tColor
	
	put randomColor() into tColor	
	set the backColor of it to tColor
	TestAssert "set segment color", the backColor of it is tColor
	
	put randomColor() into tColor
	set the hiliteColor of it to tColor
	TestAssert "set segment selected color", the hiliteColor of it is tColor
	
	put randomColor() into tColor
	set the foreColor of it to tColor
	TestAssert "set segment label color", the foreColor of it is tColor
	
	put randomColor() into tColor
	set the hilitedTextColor of it to tColor
	TestAssert "set segment selected color", the hilitedTextColor of it is tColor
end TestColors

on TestEmptyColors
	create stack
	create widget as "com.livecode.widget.segmented"
	
	local tColor
	
	put randomColor() into tColor	
	set the backColor of it to tColor
	set the backColor of it to empty
	TestAssert "set segment color empty", the backColor of it is empty
	
	put randomColor() into tColor
	set the hiliteColor of it to tColor
	set the hiliteColor of it to empty
	TestAssert "set segment selected color empty", the hiliteColor of it is empty
	
	put randomColor() into tColor
	set the foreColor of it to tColor
	set the foreColor of it to empty
	TestAssert "set segment label color", the foreColor of it is empty
	
	put randomColor() into tColor
	set the hilitedTextColor of it to tColor
	set the hilitedTextColor of it to empty
	TestAssert "set segment selected color", the hilitedTextColor of it is empty
end TestEmptyColors

on TestDisplayText
	create stack
	create widget as "com.livecode.widget.segmented"
	set the itemStyle of it to "icon"
	TestAssert "no runtime error when setting segment display to icon", true
end TestDisplayText

-- OXT-Beyond: the colours the IDE gives a new segmented control (its
-- metadata's defaults, 244,244,244 behind its labels) are drawn as they
-- are in the light appearance, on a dark card too: only in the dark
-- appearance on a dark card are they drawn in the dark (64,64,64), and a
-- colour set by hand is drawn as set in both (seth's choice 2A of
-- 2026-10-31). The properties read what they were set to in either. The
-- IDE tour checks the dark appearance on a Mac and on Windows
-- (tools/ci/ui-tour.livecodescript, the steps widget-appearance and
-- system-switch); here the appearance is whatever the tests run in
on TestDefaultColorsAndTheAppearance
	local tStack, tDark, tWidget
	put "SegmentedAppearance" & the milliseconds into tStack
	create stack tStack
	set the backgroundColor of card 1 of stack tStack to "30,30,30"
	put the systemAppearance is "dark" into tDark

	create widget "Defaults" as "com.livecode.widget.segmented" in card 1 of stack tStack
	put it into tWidget
	set the rect of tWidget to "10,10,310,50"
	set the hilitedItems of tWidget to empty
	set the foregroundColor of tWidget to "0,0,0"
	set the backgroundColor of tWidget to "244,244,244"
	set the borderColor of tWidget to "109,109,109"
	if tDark then
		TestAssert "the light default is drawn in the dark on a dark card in the dark appearance", \
				_SegmentPixel(tStack, tWidget) is "64,64,64"
	else
		TestAssert "the light default is drawn as it is on a dark card in the light appearance", \
				_SegmentPixel(tStack, tWidget) is "244,244,244"
	end if
	TestAssert "its colours read the light defaults", \
			the foregroundColor of tWidget is "0,0,0" and \
			the backgroundColor of tWidget is "244,244,244" and \
			the borderColor of tWidget is "109,109,109"

	set the backgroundColor of tWidget to "200,120,40"
	TestAssert "a colour set by hand is drawn as set", _SegmentPixel(tStack, tWidget) is "200,120,40"

	set the backgroundColor of card 1 of stack tStack to "250,250,250"
	set the backgroundColor of tWidget to "244,244,244"
	TestAssert "the light default is drawn as it is on a light card", \
			_SegmentPixel(tStack, tWidget) is "244,244,244"
	delete stack tStack
end TestDefaultColorsAndTheAppearance

-- The red, green and blue of the segmented control pWidget of the stack
-- pStack, as a snapshot of it shows it, 10 points in from its left at its
-- middle: in its first segment, left of its label
private function _SegmentPixel pStack, pWidget
	local tData, tWidth, tAt
	export snapshot from pWidget to tData as PNG
	create image "SegmentPixel" in card 1 of stack pStack
	set the text of image "SegmentPixel" of card 1 of stack pStack to tData
	put the width of image "SegmentPixel" of card 1 of stack pStack into tWidth
	put the imageData of image "SegmentPixel" of card 1 of stack pStack into tData
	delete image "SegmentPixel" of card 1 of stack pStack
	put ((the height of pWidget div 2) * tWidth + 10) * 4 into tAt
	return byteToNum(byte tAt + 2 of tData) & comma & byteToNum(byte tAt + 3 of tData) & comma & \
			byteToNum(byte tAt + 4 of tData)
end _SegmentPixel
