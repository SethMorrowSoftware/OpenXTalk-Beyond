script "IconPickerColors"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

on TestSetup
	TestLoadExtension "com.livecode.library.iconsvg"
	TestLoadExtension "com.livecode.library.widgetutils"
	TestLoadExtension "com.livecode.widget.iconpicker"
end TestSetup

-- OXT-Beyond: the icon picker has no colour properties of its own. In the
-- light appearance it draws what it always has (its frame 188,188,188,
-- black icons), on a dark card too; only in the dark appearance on a dark
-- card does it draw its dark colours (its frame 96,96,96, light grey
-- icons), as the other widgets decide it (bwmilby, openxtalk.org
-- p=26194). The IDE tour checks the icons on the screen in both
-- appearances (tools/ci/ui-tour.livecodescript, the step icon-picker);
-- here the appearance is whatever the tests run in
on TestFrameAndTheAppearance
	local tStack, tDark, tWidget
	put "IconPickerAppearance" & the milliseconds into tStack
	create stack tStack
	set the backgroundColor of card 1 of stack tStack to "30,30,30"
	put the systemAppearance is "dark" into tDark

	create widget "Picker" as "com.livecode.widget.iconpicker" in card 1 of stack tStack
	put it into tWidget
	set the rect of tWidget to "10,10,330,250"
	TestAssert "the frame is shown, as before", the showFrameBorder of tWidget
	if tDark then
		TestAssert "the frame is drawn dark on a dark card in the dark appearance", \
				_PickerFramePixel(tWidget) is "96,96,96"
	else
		TestAssert "the frame is drawn as before on a dark card in the light appearance", \
				_PickerFramePixel(tWidget) is "188,188,188"
	end if

	set the backgroundColor of card 1 of stack tStack to "250,250,250"
	TestAssert "the frame is drawn as before on a light card", \
			_PickerFramePixel(tWidget) is "188,188,188"
	delete stack tStack
end TestFrameAndTheAppearance

-- The red, green and blue of the left edge of the icon picker pWidget, at
-- its middle, as a snapshot of it shows it: its frame
private function _PickerFramePixel pWidget
	local tData, tWidth, tAt
	export snapshot from pWidget to tData as PNG
	create image "PickerPixel" in the owner of pWidget
	set the text of image "PickerPixel" of the owner of pWidget to tData
	put the width of image "PickerPixel" of the owner of pWidget into tWidth
	put the imageData of image "PickerPixel" of the owner of pWidget into tData
	delete image "PickerPixel" of the owner of pWidget
	put (the height of pWidget div 2) * tWidth * 4 into tAt
	return byteToNum(byte tAt + 2 of tData) & comma & byteToNum(byte tAt + 3 of tData) & comma & \
			byteToNum(byte tAt + 4 of tData)
end _PickerFramePixel
