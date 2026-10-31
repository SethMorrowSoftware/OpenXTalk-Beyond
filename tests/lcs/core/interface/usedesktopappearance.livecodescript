script "CoreInterfaceUseDesktopAppearance"
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

/*
OXT-Beyond: the global useDesktopAppearance (seth's decision, 2026-10-31).
While it is true, the systemAppearance on Linux follows the desktop's light
or dark setting; it is false by default, so that the systemAppearance reads
what it always did. These tests run with no screen, where the engine has no
desktop to ask: the systemAppearance stays what it was. The desktop itself
is checked with a screen by tools/ci/appearance_check.py.
*/

on TestUseDesktopAppearanceDefault
   TestAssert "the useDesktopAppearance is false by default", \
         the useDesktopAppearance is false
end TestUseDesktopAppearanceDefault

on TestUseDesktopAppearanceSet
   local tBefore
   put the systemAppearance into tBefore

   set the useDesktopAppearance to true
   TestAssert "it can be set to true", the useDesktopAppearance is true
   if the platform is not "Linux" then
      TestAssert "the systemAppearance is the system's, as before", \
            the systemAppearance is tBefore
   end if

   set the useDesktopAppearance to false
   TestAssert "it can be set back to false", the useDesktopAppearance is false
   TestAssert "and the systemAppearance is what it was", \
         the systemAppearance is tBefore
   if the platform is "Linux" then
      TestAssert "on Linux, light", the systemAppearance is "light"
   end if

   set the useDesktopAppearance to "true"
   TestAssert "it takes a string true", the useDesktopAppearance is true
   set the useDesktopAppearance to false
end TestUseDesktopAppearanceSet

on TestUseDesktopAppearanceNotABoolean
   local tError
   try
      set the useDesktopAppearance to "dark"
   catch tError
   end try
   TestAssert "a value that is not true or false is an error", tError is not empty
   TestAssert "and leaves it false", the useDesktopAppearance is false
end TestUseDesktopAppearanceNotABoolean
