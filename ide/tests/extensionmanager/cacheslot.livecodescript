script "IDEExtensionManagerCacheSlot"
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

-- OXT-Beyond: an extension installed after another was uninstalled gets
-- an entry of its own in the Extension Manager's list. LiveCode gave a new
-- entry the index "the number of entries + 1", which, once an entry had
-- gone, was the index of the newest one, so the next install wrote over
-- it: the Box2Dxt Kit installed right after Box2D overwrote Box2D, and was
-- refused with "Dependency org.openxtalk.box2dxt not available"
-- (Emily-Elizabeth, forum, 2026-11-15, LiveCode 9.6.3 and HyperXTalk).
--
-- Three script libraries are packaged here as .lce files: C is installed,
-- then A, then C is uninstalled (a gap BELOW A's entry), then B. Before the
-- fix B took A's entry and A was gone from the list. B does not declare A
-- as a requirement, so that a regression fails this test rather than
-- stopping it at the install's error dialog.

constant kA = "oxtTestSlotA"
constant kB = "oxtTestSlotB"
constant kC = "oxtTestSlotC"

on TestTeardown
   local tName
   repeat for each item tName in kB & comma & kA & comma & kC
      if revIDEExtensionProperty(tName, "status") is not empty then
         revIDEExtensionUninstall tName
      end if
   end repeat
end TestTeardown

-- A package of one script library named pName, made as the Extension
-- Builder makes one (manifest.xml and the stack's file at the root)
private function __Package pName
   local tFolder, tPackage, tManifest
   put specialFolderPath("temporary") & "/oxt_test_cacheslot" into tFolder
   if there is not a folder tFolder then create folder tFolder
   put tFolder & "/" & pName & ".lce" into tPackage
   if there is a file tPackage then delete file tPackage
   put "<package version=" & quote & "0.0" & quote & ">" & return & \
         "  <name>" & pName & "</name>" & return & \
         "  <title>" & pName & "</title>" & return & \
         "  <author>OXT-Beyond tests</author>" & return & \
         "  <version>1.0.0</version>" & return & \
         "  <type>library</type>" & return & \
         "  <license>community</license>" & return & \
         "</package>" & return into tManifest
   revZipOpenArchive tPackage, "write"
   revZipAddItemWithData tPackage, "manifest.xml", "tManifest"
   local tScript
   put "script " & quote & pName & quote & return & \
         "function " & pName & "Ping" & return & \
         "   return " & quote & pName & quote & return & \
         "end " & pName & "Ping" & return into tScript
   revZipAddItemWithData tPackage, pName & ".livecodescript", "tScript"
   revZipCloseArchive tPackage
   return tPackage
end __Package

on TestInstallAfterUninstall
   local tA, tB, tC
   put __Package(kA) into tA
   put __Package(kB) into tB
   put __Package(kC) into tC
   TestAssert "the test packages were made", \
         there is a file tA and there is a file tB and there is a file tC

   revIDEExtensionInstall tC
   revIDEExtensionInstall tA
   TestDiagnostic "A:" && revIDEExtensionProperty(kA, "status") && \
         revIDEExtensionProperty(kA, "error")
   TestAssert "A installs", revIDEExtensionProperty(kA, "status") is "installed"
   revIDEExtensionUninstall kC
   TestAssert "C is uninstalled", revIDEExtensionProperty(kC, "status") is empty

   revIDEExtensionInstall tB
   TestDiagnostic "B:" && revIDEExtensionProperty(kB, "status") && \
         "A:" && revIDEExtensionProperty(kA, "status")
   TestAssert "B installs", revIDEExtensionProperty(kB, "status") is "installed"
   TestAssert "A is still in the list after B installs", \
         revIDEExtensionProperty(kA, "status") is "installed"
   TestAssert "A and B are separate entries", \
         revIDEExtensionProperty(kA, "install_path") is not empty and \
         revIDEExtensionProperty(kA, "install_path") is not \
         revIDEExtensionProperty(kB, "install_path")
end TestInstallAfterUninstall
