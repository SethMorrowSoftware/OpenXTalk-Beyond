script "TestIDENewStackPresetSizes"
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

-- File > New Stack's preset sizes are shown unless the user said otherwise:
-- a preference that was never set becomes true, one already true or false
-- (a preferences file from an IDE that has run before) is kept.

private function __Default pValue
   local tResult
   dispatch function "revInternal__ShowPresetSizesDefault" to stack "home" with pValue
   put the result into tResult
   if it is not "handled" then return "not handled"
   return tResult
end __Default

on TestPresetSizesShownByDefault
   TestAssert "a preference never set shows the preset sizes", __Default(empty) is true
end TestPresetSizesShownByDefault

on TestPresetSizesSetByTheUserKept
   TestAssert "a preference set to false stays false", __Default(false) is false
   TestAssert "a preference set to true stays true", __Default(true) is true
end TestPresetSizesSetByTheUserKept
