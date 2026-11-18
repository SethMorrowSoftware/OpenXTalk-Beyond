script "TestAndroidDocumentsLibrary"
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

-- The Android documents library (org.openxtalk.library.androiddocuments)
-- as a script meets it. Its handlers work on Android only: anywhere else
-- each one throws, and nothing else happens. On Android, an address that
-- is none Android lent the app has no name and cannot be copied; choosing
-- a document needs a person (or the emulator check of the Stack Player,
-- tools/android-player, which taps for one).

on TestSetup
   TestSkipIfNot "lcb"
   TestLoadExtension "org.openxtalk.library.androiddocuments"
end TestSetup

on PickADocument
   get androidPickDocument(empty)
end PickADocument

on NameADocument
   get androidDocumentName("content://org.openxtalk.none/nothing")
end NameADocument

on CopyADocument
   androidCopyDocument "content://org.openxtalk.none/nothing", the tempName
end CopyADocument

on TestOnlyOnAndroid
   if the platform is "android" then
      TestSkip "off Android", "this is Android"
      exit TestOnlyOnAndroid
   end if
   TestAssertThrow "choosing a document throws off Android", \
         "PickADocument", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   TestAssertThrow "a document's name throws off Android", \
         "NameADocument", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   TestAssertThrow "copying a document throws off Android", \
         "CopyADocument", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
end TestOnlyOnAndroid

on TestAnAddressOfNobody
   if the platform is not "android" then
      TestSkip "an address nobody owns", "needs Android"
      exit TestAnAddressOfNobody
   end if
   local tFile
   put the tempName into tFile
   TestAssertThrow "an address nobody owns cannot be copied", \
         "CopyADocument", the long id of me, "EE_EXTENSION_ERROR_DOMAIN"
   TestAssert "nothing was written for it", there is not a file tFile
end TestAnAddressOfNobody
