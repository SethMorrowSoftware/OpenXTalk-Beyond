script "CoreEngineAndroidPermissions"
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

-- androidPermissionExists, androidHasPermission and androidRequestPermission
-- of a permission that Android lists in no permission group. Android 10 and
-- newer list most of them in none (INTERNET, ACCESS_NETWORK_STATE, ...),
-- and the Java layer (Engine.java, checkPermissionExists) looked for a name
-- only in the groups, so androidPermissionExists said false of INTERNET and
-- androidHasPermission returned empty, neither true nor false (seen in
-- #572's probe on Android 13). The engine's "bad permission name" error
-- stops no script on Android (exec-keywords.cpp: a mobile handler's error
-- is not thrown, AL-2014-03-14), so the value is empty and nothing throws;
-- androidRequestPermission asked for nothing. The app the script tests
-- run in on Android asks for
-- INTERNET and ACCESS_NETWORK_STATE (tools/ci/android-check.livecodescript,
-- buildSettings), which are normal permissions: Android grants them when
-- the app is installed, and asks the user nothing. A name Android does not
-- know still does not exist, and androidHasPermission still returns empty
-- for it, without a throw (the first run on the emulator, of #586, had this
-- test expect a throw, and both engines said otherwise).

constant kInternet = "android.permission.INTERNET"
constant kNetworkState = "android.permission.ACCESS_NETWORK_STATE"
constant kMadeUp = "org.openxtalk.permission.NOTHING_AT_ALL"

on TestSetup
   TestSkipIfNot "platform", "android"
end TestSetup

on TestAPermissionInNoGroupExists
   TestAssert "INTERNET exists", androidPermissionExists(kInternet) is true
   TestAssert "ACCESS_NETWORK_STATE exists", androidPermissionExists(kNetworkState) is true
end TestAPermissionInNoGroupExists

on TestAPermissionInAGroupExists
   -- (as before: a permission that Android asks the user for, which it
   -- lists in a group)
   TestAssert "CAMERA exists", androidPermissionExists("android.permission.CAMERA") is true
end TestAPermissionInAGroupExists

on TestAPermissionInNoGroupIsHeld
   local tHeld, tError
   try
      put androidHasPermission(kInternet) into tHeld
   catch tError
   end try
   TestDiagnostic "androidHasPermission of INTERNET:" && tHeld && "threw:" && line 1 of tError
   TestAssert "androidHasPermission does not throw for INTERNET", tError is empty
   TestAssert "the app holds INTERNET", tHeld is true
   put empty into tHeld
   put empty into tError
   try
      put androidHasPermission(kNetworkState) into tHeld
   catch tError
   end try
   TestAssert "the app holds ACCESS_NETWORK_STATE", tError is empty and tHeld is true
end TestAPermissionInNoGroupIsHeld

on TestAskingForAPermissionInNoGroup
   local tError
   -- (held already, so Android shows nothing and the answer is at once)
   try
      androidRequestPermission kInternet
   catch tError
   end try
   TestAssert "androidRequestPermission does not throw for INTERNET", tError is empty
   -- (the command leaves the result empty, as it always has)
   TestAssert "and the app holds it after", androidHasPermission(kInternet) is true
end TestAskingForAPermissionInNoGroup

on TestANameAndroidDoesNotKnow
   local tHeld, tError
   TestAssert "a made-up name does not exist", androidPermissionExists(kMadeUp) is false
   TestAssert "an empty name does not exist", androidPermissionExists(empty) is false
   -- (as before: empty, neither true nor false, and no throw)
   put "unset" into tHeld
   try
      put androidHasPermission(kMadeUp) into tHeld
   catch tError
   end try
   TestDiagnostic "androidHasPermission of a made-up name:" && tHeld && "threw:" && line 1 of tError
   TestAssert "androidHasPermission of a made-up name does not throw", tError is empty
   TestAssert "androidHasPermission of a made-up name returns empty", tHeld is empty
end TestANameAndroidDoesNotKnow
