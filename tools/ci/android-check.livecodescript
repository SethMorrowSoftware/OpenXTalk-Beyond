script "OXTAndroidCheck"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- The IDE's Android standalone builder, run for tools/ci/android_check.py.
-- Named on the IDE's command line, it is opened once the IDE has started
-- (as tools/ci/web-deploy.livecodescript is), waits for the IDE to finish
-- starting, and then:
--
-- 1. Units: calls the handlers of the builder and of the Android deploy
--    library that need no Android SDK (the manifest's components without
--    android:exported, the 64-bit and extension code warnings, the SDK
--    check on made-up SDK folders, the debug keystore's place) and writes
--    "UNIT OK <name>" or "UNIT FAILED <name>: <why>" for each.
--    OXT_ANDROID_UNITS=skip leaves them out (a released builder, which
--    has none of these handlers, run for the comparison).
--
-- 2. Builds, when OXT_ANDROID_SDK names an Android SDK: makes the probe
--    stack and builds it with the IDE's own builder
--    (revSaveAsMobileStandalone, as File > Save as Standalone Application
--    does), once for each of these, with the standalone settings a user
--    sets on the Android card:
--       debug     "Sign for development only", armv7, arm64, x86 and
--                 x86_64, and a push sender ID (the push receiver)
--       release   "Sign with my key" with OXT_ANDROID_KEYSTORE, arm64 and
--                 x86_64; the builder asks for the alias and the two
--                 passwords, and this script answers its ask dialogs
--       unsigned  "Do not sign", arm64
--       legacy    what a stack that never opened the Android card has:
--                 no architecture and no signing setting
--    and writes "BUILT <name> <apk>" or "BUILD FAILED <name> <why>",
--    "INFO <name> warnings <the builder's warnings>" and
--    "INFO <name> asked <the questions it answered>".
--    With OXT_ANDROID_DEVICE (a device's serial), it then does what Test
--    does for that device (deployDo in ide-support/
--    revdeploylibraryandroid.livecodescript: a Test build for the device's
--    architecture, signed with the debug key, installed with adb and
--    started) and writes "TEST OK <serial>" or "TEST FAILED <why>".
--
-- Then "DONE". The IDE is left running: android_check.py ends it.
--
-- Environment:
--    OXT_ANDROID_LOG       the file for the lines above (UTF-8)
--    OXT_ANDROID_UNITS     "skip" to leave the units out
--    OXT_ANDROID_SDK       the Android SDK (builds only with one)
--    OXT_ANDROID_JDK       the JDK (its bin/javac and bin/keytool)
--    OXT_ANDROID_STACK     where to save the probe stack (used as it is
--                          when the file is there)
--    OXT_ANDROID_OUTPUT    the folder for the packages (<name>.apk)
--    OXT_ANDROID_BUILDS    the builds to make (comma separated; all four
--                          when empty)
--    OXT_ANDROID_KEYSTORE, OXT_ANDROID_ALIAS, OXT_ANDROID_PASSWORD
--                          the release build's keystore, its key's alias,
--                          and the one password of the store and the key
--    OXT_ANDROID_DEVICE    the serial of the device for Test (optional)
--    OXT_ANDROID_WORK      a folder for the units' made-up SDKs

-- The probe's colours: the stack is saved red, and its openStack makes it
-- green, so a screen of green says that the engine ran the stack's script
constant kSavedColor = "204,34,0"
constant kRunColor = "31,158,90"
constant kIdentifier = "org.openxtalk.check.androidprobe"

local sStarted
local sAsked
local sAskMessage

on openStack
   if sStarted is not true and the environment is "development" then
      put true into sStarted
      -- out of the way of the IDE's windows
      hide me
      send "androidWhenStarted 0" to me in 1 second
   end if
   pass openStack
end openStack

-- Waits until the IDE has finished starting (home.livecodescript sets the
-- cREVLaunching of stack "Home" while it opens its palettes), then a
-- little more for their deferred messages
on androidWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then
      put the cREVLaunching of stack "Home" into tLaunching
   end if
   if tLaunching is true and pTries < 240 then
      send "androidWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "androidRun" to me in 2 seconds
   end if
end androidWhenStarted

private command androidLog pLine
   replace return with " | " in pLine
   put textEncode(pLine & lf, "UTF-8") after url ("binfile:" & $OXT_ANDROID_LOG)
end androidLog

on androidRun
   local tError
   androidCatchErrors
   androidLog "INFO version" && the version && the buildNumber
   androidLog "INFO platform" && the platform && the processor
   -- (not "0": an empty variable is 0 to "is", so it would skip them)
   if $OXT_ANDROID_UNITS is not "skip" then
      try
         androidUnits
      catch tError
         androidLog "UNIT FAILED units: script error" && tError
      end try
   end if
   if $OXT_ANDROID_SDK is not empty then
      try
         androidBuilds
      catch tError
         androidLog "ERROR builds:" && tError
      end try
   end if
   if "revStandaloneProgress" is among the lines of the openStacks then
      close stack "revStandaloneProgress"
   end if
   androidLog "DONE"
end androidRun

----------------------------------------------------------------
-- 1. Units
----------------------------------------------------------------

private command androidUnit pName, pOk, pWhy
   if pOk is true then
      androidLog "UNIT OK" && pName
   else
      androidLog "UNIT FAILED" && pName & ":" && pWhy
   end if
end androidUnit

private function sortedLines pText
   sort lines of pText
   return pText
end sortedLines

-- The builder's handlers, by name (the IDE uses both libraries)
private function builderCall pHandler, pArg1, pArg2
   dispatch function pHandler to stack "revSaveAsAndroidStandalone" with pArg1, pArg2
   return the result
end builderCall

private function deployCall pHandler, pArg1
   dispatch function pHandler to stack "revDeployLibraryAndroid" with pArg1
   return the result
end deployCall

private command androidUnits
   local tWork
   put $OXT_ANDROID_WORK into tWork
   if tWork is empty then
      put specialFolderPath("temporary") & "/oxt-android-units" into tWork
   end if
   revSBEnsureFolder tWork
   unitExported tWork
   unit64Bit
   unitExtensionCode
   unitCheckSDK tWork
   unitDebugKeystore
   androidUnit "required-sdk", deployCall("deployRequiredSDK") is "Android 13 (API 33) or newer", \
         "deployRequiredSDK() is" && deployCall("deployRequiredSDK")
end androidUnits

-- androidComponentsWithoutExported over a manifest with every case
private command unitExported pWork
   local tXML, tFile, tFound, tWanted
   put "<?xml version=" & quote & "1.0" & quote && "encoding=" & quote & "utf-8" & quote & "?>" & lf into tXML
   put "<manifest xmlns:android=" & quote & "http://schemas.android.com/apk/res/android" & quote && "package=" & quote & "x.y" & quote & ">" & lf after tXML
   put "<application>" & lf after tXML
   put component("activity", "A", "true", true) after tXML
   put component("activity", "B", empty, true) after tXML
   put component("activity", "C", empty, false) after tXML
   put component("service", "S", empty, true) after tXML
   put component("service", "S2", "false", true) after tXML
   put component("receiver", "R", "false", true) after tXML
   put component("receiver", "R2", empty, true) after tXML
   put component("provider", "P", empty, true) after tXML
   put "<activity-alias android:name=" & quote & "AA" & quote && "android:targetActivity=" & quote & "A" & quote & ">" & \
         "<intent-filter><action android:name=" & quote & "x.AA" & quote & "/></intent-filter></activity-alias>" & lf after tXML
   put "</application>" & lf & "</manifest>" & lf after tXML
   put pWork & "/AndroidManifest.xml" into tFile
   put textEncode(tXML, "UTF-8") into url ("binfile:" & tFile)
   put builderCall("androidComponentsWithoutExported", builderCall("androidManifestToArray", tFile)) into tFound
   put "activity B" & return & "activity-alias AA" & return & "receiver R2" & return & "service S" into tWanted
   androidUnit "components-without-exported", sortedLines(tFound) is tWanted, \
         "found" && quote & tFound & quote & ", wanted" && quote & tWanted & quote

   -- a manifest where every component says android:exported
   put "<?xml version=" & quote & "1.0" & quote && "encoding=" & quote & "utf-8" & quote & "?>" & lf into tXML
   put "<manifest xmlns:android=" & quote & "http://schemas.android.com/apk/res/android" & quote && "package=" & quote & "x.y" & quote & ">" & lf after tXML
   put "<application>" & component("activity", "A", "true", true) & component("receiver", "R", "true", true) & "</application></manifest>" after tXML
   put textEncode(tXML, "UTF-8") into url ("binfile:" & tFile)
   put builderCall("androidComponentsWithoutExported", builderCall("androidManifestToArray", tFile)) into tFound
   androidUnit "components-all-exported", tFound is empty, "found" && quote & tFound & quote
   delete file tFile
end unitExported

private function component pKind, pName, pExported, pFilter
   local tXML
   put "<" & pKind && "android:name=" & quote & pName & quote into tXML
   if pExported is not empty then
      put " android:exported=" & quote & pExported & quote after tXML
   end if
   put ">" after tXML
   if pFilter then
      put "<intent-filter><action android:name=" & quote & "x." & pName & quote & "/></intent-filter>" after tXML
   end if
   put "</" & pKind & ">" & lf after tXML
   return tXML
end component

private function warningsFor pHandler, pArg1, pArg2
   revStandaloneResetWarnings
   dispatch pHandler to stack "revSaveAsAndroidStandalone" with pArg1, pArg2
   return revStandaloneGetWarnings()
end warningsFor

private command unit64Bit
   local tABIs, tWarnings
   put true into tABIs["armeabi-v7a"]
   put warningsFor("androidWarnMissing64Bit", tABIs) into tWarnings
   androidUnit "64bit-armv7-alone", tWarnings contains "built for armv7 and not arm64" and the number of lines of tWarnings is 1, tWarnings
   put true into tABIs["arm64-v8a"]
   put warningsFor("androidWarnMissing64Bit", tABIs) into tWarnings
   androidUnit "64bit-armv7-arm64", tWarnings is empty, tWarnings
   put true into tABIs["x86"]
   put warningsFor("androidWarnMissing64Bit", tABIs) into tWarnings
   androidUnit "64bit-x86-alone", tWarnings contains "built for x86 and not x86_64" and the number of lines of tWarnings is 1, tWarnings
   put true into tABIs["x86_64"]
   put warningsFor("androidWarnMissing64Bit", tABIs) into tWarnings
   androidUnit "64bit-all", tWarnings is empty, tWarnings
   delete variable tABIs
   put true into tABIs["arm64-v8a"]
   put warningsFor("androidWarnMissing64Bit", tABIs) into tWarnings
   androidUnit "64bit-arm64-alone", tWarnings is empty, tWarnings
end unit64Bit

private command unitExtensionCode
   local tFiles, tWarnings
   -- a "code" folder above the extensions too: the extension is the
   -- folder above the last one
   put "/home/u/code/app/Extensions/com.x.foo/code/armv7-android/libfoo.so" & return & \
         "/home/u/code/app/Extensions/com.x.foo/code/arm64-android/libfoo.so" & return & \
         "/home/u/code/app/Extensions/com.x.bar/code/armv7-android/libbar.so" into tFiles
   put warningsFor("androidWarnMissingExtensionCode", "armv7,arm64", tFiles) into tWarnings
   androidUnit "extension-code-missing", tWarnings contains "extension com.x.bar has no native code for arm64" \
         and the number of lines of tWarnings is 1, tWarnings
   put warningsFor("androidWarnMissingExtensionCode", "armv7", tFiles) into tWarnings
   androidUnit "extension-code-complete", tWarnings is empty, tWarnings
   put warningsFor("androidWarnMissingExtensionCode", "armv7,arm64,x86_64", tFiles) into tWarnings
   androidUnit "extension-code-two-missing", tWarnings contains "com.x.bar has no native code for arm64, x86_64" \
         and tWarnings contains "com.x.foo has no native code for x86_64" and the number of lines of tWarnings is 2, tWarnings
   put warningsFor("androidWarnMissingExtensionCode", "armv7,arm64", empty) into tWarnings
   androidUnit "extension-code-none", tWarnings is empty, tWarnings
end unitExtensionCode

-- A file, empty, and the folders above it
private command touchFile pFile
   local tFolder
   set the itemDelimiter to slash
   put item 1 to -2 of pFile into tFolder
   set the itemDelimiter to comma
   revSBEnsureFolder tFolder
   put empty into url ("binfile:" & pFile)
end touchFile

private command removeTree pFolder
   local tItem
   if there is no folder pFolder then
      exit removeTree
   end if
   repeat for each line tItem in files(pFolder)
      delete file (pFolder & slash & tItem)
   end repeat
   repeat for each line tItem in folders(pFolder)
      if tItem is not "." and tItem is not ".." then
         removeTree pFolder & slash & tItem
      end if
   end repeat
   delete folder pFolder
end removeTree

private command unitCheckSDK pWork
   local tSDK, tAnswer, tTool, tExe
   put pWork & "/sdk" into tSDK
   removeTree tSDK

   put deployCall("deployCheckSDK", tSDK) into tAnswer
   androidUnit "sdk-no-folder", tAnswer begins with "there is no folder", tAnswer

   revSBEnsureFolder tSDK
   put deployCall("deployCheckSDK", tSDK) into tAnswer
   androidUnit "sdk-no-platforms", tAnswer contains "no Android platform (no folder" and tAnswer contains "SDK Manager", tAnswer

   revSBEnsureFolder tSDK & "/platforms"
   put deployCall("deployCheckSDK", tSDK) into tAnswer
   androidUnit "sdk-no-platform-tools", tAnswer contains "no Android SDK Platform-Tools", tAnswer

   revSBEnsureFolder tSDK & "/platform-tools"
   touchFile tSDK & "/platforms/android-31/android.jar"
   put deployCall("deployCheckSDK", tSDK) into tAnswer
   androidUnit "sdk-old-platform", tAnswer contains "no Android platform for API 33 or newer" and tAnswer contains "(it has: android-31)", tAnswer

   -- a newer platform than the target, and a preview named by a letter
   touchFile tSDK & "/platforms/android-36.1/android.jar"
   touchFile tSDK & "/platforms/android-35/android.jar"
   touchFile tSDK & "/platforms/android-Baklava/android.jar"
   revSBEnsureFolder tSDK & "/platforms/android-34"
   put deployCall("pathToRootPlatform", tSDK) into tAnswer
   androidUnit "sdk-newer-platform", tAnswer is tSDK & "/platforms/android-35", tAnswer
   put deployCall("deployCheckSDK", tSDK) into tAnswer
   androidUnit "sdk-no-build-tools", tAnswer contains "it has no aapt in" and tAnswer contains "(versions there: none)", tAnswer

   -- the target's platform is taken first, as before
   touchFile tSDK & "/platforms/android-33/android.jar"
   put deployCall("pathToRootPlatform", tSDK) into tAnswer
   androidUnit "sdk-target-platform", tAnswer is tSDK & "/platforms/android-33", tAnswer

   -- every tool but apksigner, then apksigner
   repeat for each item tTool in "aapt,zipalign,d8"
      put tTool into tExe
      if the platform is "win32" then
         if tTool is "d8" then
            put ".bat" after tExe
         else
            put ".exe" after tExe
         end if
      end if
      touchFile tSDK & "/build-tools/34.0.0/" & tExe
   end repeat
   put "adb" into tExe
   if the platform is "win32" then
      put ".exe" after tExe
   end if
   touchFile tSDK & "/platform-tools/" & tExe
   put deployCall("deployCheckSDK", tSDK) into tAnswer
   androidUnit "sdk-no-apksigner", tAnswer contains "it has no apksigner" and tAnswer contains "(versions there: 34.0.0)", tAnswer
   androidUnit "sdk-invalid-without-apksigner", deployCall("deployIsValidSDK", tSDK) is false, deployCall("deployIsValidSDK", tSDK)
   put "apksigner" into tExe
   if the platform is "win32" then
      put ".bat" after tExe
   end if
   touchFile tSDK & "/build-tools/34.0.0/" & tExe
   put deployCall("deployCheckSDK", tSDK) into tAnswer
   androidUnit "sdk-complete", tAnswer is empty, tAnswer
   androidUnit "sdk-valid", deployCall("deployIsValidSDK", tSDK) is true, deployCall("deployIsValidSDK", tSDK)
   removeTree tSDK
end unitCheckSDK

private command unitDebugKeystore
   local tSaved, tAnswer
   put $ANDROID_USER_HOME into tSaved
   put "/tmp/oxt-android-user" into $ANDROID_USER_HOME
   put deployCall("deployDebugKeystore") into tAnswer
   androidUnit "debug-keystore-android-user-home", tAnswer is "/tmp/oxt-android-user/debug.keystore", tAnswer
   put empty into $ANDROID_USER_HOME
   put deployCall("deployDebugKeystore") into tAnswer
   if the platform is "win32" then
      androidUnit "debug-keystore-home", tAnswer ends with "/.android/debug.keystore" and backslash is not in tAnswer, tAnswer
   else
      androidUnit "debug-keystore-home", tAnswer is $HOME & "/.android/debug.keystore", tAnswer
   end if
   put tSaved into $ANDROID_USER_HOME
end unitDebugKeystore

----------------------------------------------------------------
-- 2. Builds
----------------------------------------------------------------

-- The probe stack: red as saved, green once its script has run. A stack
-- file saved by an earlier run is used as it is (loaded, not opened), so
-- that two builders can be given the same one: two stacks made the same
-- way differ in a few bytes, and the stack goes into the engine library.
private command makeProbeStack
   if there is a file $OXT_ANDROID_STACK then
      lock messages
      get the short name of stack $OXT_ANDROID_STACK
      unlock messages
      if it is not "AndroidProbe" then
         throw $OXT_ANDROID_STACK && "is not the probe stack:" && it
      end if
      exit makeProbeStack
   end if
   create stack "AndroidProbe"
   set the rect of stack "AndroidProbe" to 0,0,320,480
   set the backgroundColor of stack "AndroidProbe" to kSavedColor
   set the fullscreenMode of stack "AndroidProbe" to "exactFit"
   set the script of stack "AndroidProbe" to \
         "on openStack" & return & \
         "   set the backgroundColor of me to" && quote & kRunColor & quote & return & \
         "end openStack"
   local tDefault
   put the defaultStack into tDefault
   set the defaultStack to "AndroidProbe"
   create field "Probe"
   set the rect of field "Probe" of stack "AndroidProbe" to 20,20,300,60
   set the text of field "Probe" of stack "AndroidProbe" to "OXT-Beyond Android check"
   set the defaultStack to tDefault
   save stack "AndroidProbe" as $OXT_ANDROID_STACK
   if the result is not empty then
      throw "cannot save the probe stack as" && $OXT_ANDROID_STACK & ":" && the result
   end if
end makeProbeStack

-- The settings of one build (see the header)
private function buildSettings pName
   local tSettings, tArch
   put revSBGetSettings("AndroidProbe", true) into tSettings
   put true into tSettings["android"]
   put "AndroidProbe" into tSettings["name"]
   put kIdentifier into tSettings["android,identifier"]
   put "Android Probe" into tSettings["android,label"]
   repeat for each item tArch in "armv7,arm64,x86,x86_64"
      delete variable tSettings["android," & tArch]
   end repeat
   switch pName
      case "debug"
         put "Sign for development only" into tSettings["android,signing"]
         repeat for each item tArch in "armv7,arm64,x86,x86_64"
            put true into tSettings["android," & tArch]
         end repeat
         put "123456789012" into tSettings["android,pushSenderID"]
         break
      case "release"
         put "Sign with my key" into tSettings["android,signing"]
         put $OXT_ANDROID_KEYSTORE into tSettings["android,key"]
         put true into tSettings["android,arm64"]
         put true into tSettings["android,x86_64"]
         break
      case "unsigned"
         put "Do not sign" into tSettings["android,signing"]
         put true into tSettings["android,arm64"]
         break
      case "legacy"
         delete variable tSettings["android,signing"]
         delete variable tSettings["android,key"]
         break
   end switch
   return tSettings
end buildSettings

private command androidBuilds
   local tBuilds, tName, tApk, tError, tSerial
   -- what Preferences > Mobile Support does with the folders chosen there
   set the cMobileSupport["android.sdk"] of stack "revPreferences" to $OXT_ANDROID_SDK
   set the cMobileSupport["android.jdk"] of stack "revPreferences" to $OXT_ANDROID_JDK
   dispatch "revIDEDeployAndroidInitialize" to stack "revDeployLibrary"
   androidLog "INFO sdk" && the cMobileSupport["android.sdk"] of stack "revPreferences"
   androidLog "INFO jdk" && the cMobileSupport["android.jdk"] of stack "revPreferences"

   makeProbeStack
   if there is not a folder $OXT_ANDROID_OUTPUT then
      create folder $OXT_ANDROID_OUTPUT
   end if
   put $OXT_ANDROID_BUILDS into tBuilds
   if tBuilds is empty then
      put "debug,release,unsigned,legacy" into tBuilds
   end if
   repeat for each item tName in tBuilds
      put $OXT_ANDROID_OUTPUT & slash & tName & ".apk" into tApk
      if there is a file tApk then
         delete file tApk
      end if
      put empty into tError
      put empty into sAsked
      revStandaloneResetWarnings
      if tName is "release" then
         send "androidAnswerAsk 0" to me in 500 milliseconds
         put the result into sAskMessage
      end if
      try
         dispatch "revSaveAsMobileStandalone" to stack "revSaveAsAndroidStandalone" with \
               "AndroidProbe", tApk, "Build", buildSettings(tName)
      catch tError
      end try
      if sAskMessage is not empty then
         cancel sAskMessage
         put empty into sAskMessage
      end if
      androidLog "INFO" && tName && "warnings" && revStandaloneGetWarnings()
      androidLog "INFO" && tName && "asked" && sAsked
      if tError is empty and there is a file tApk then
         androidLog "BUILT" && tName && tApk
      else if tError is empty then
         androidLog "BUILD FAILED" && tName && "the builder made no" && tApk
      else
         androidLog "BUILD FAILED" && tName && tError
      end if
   end repeat

   put $OXT_ANDROID_DEVICE into tSerial
   if tSerial is not empty then
      -- Test reads the stack's own settings: those of the debug build
      revSBSetSettings "AndroidProbe", buildSettings("debug")
      save stack "AndroidProbe"
      put empty into tError
      try
         dispatch "deployDo" to stack "revDeployLibraryAndroid" with "AndroidProbe", "Android" && tSerial
         put the result into tError
      catch tError
      end try
      if tError is empty then
         androidLog "TEST OK" && tSerial
      else
         androidLog "TEST FAILED" && tError
      end if
   end if
end androidBuilds

-- Answers the builder's ask dialogs (the keystore's alias, then its two
-- passwords) as a user types them, and presses OK
on androidAnswerAsk pTries
   local tPrompt, tAnswer
   put empty into sAskMessage
   if there is a stack "Ask Dialog" and the mode of stack "Ask Dialog" is not 0 then
      put the text of field 1 of card 1 of stack "Ask Dialog" into tPrompt
      if tPrompt contains "alias" then
         put $OXT_ANDROID_ALIAS into tAnswer
      else
         put $OXT_ANDROID_PASSWORD into tAnswer
      end if
      put tPrompt & ";" after sAsked
      put tAnswer into field 2 of card 1 of stack "Ask Dialog"
      put tAnswer into field 3 of card 1 of stack "Ask Dialog"
      send "closeAccept" to card 1 of stack "Ask Dialog"
   end if
   if pTries < 600 then
      send "androidAnswerAsk" && pTries + 1 to me in 200 milliseconds
      put the result into sAskMessage
   end if
end androidAnswerAsk

-- Errors in the IDE's scripts go to the log, not to the IDE's error dialog
-- or the debugger (revTestEnvironment, as the IDE's test runner sets it)
private command androidCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      put the defaultStack into tDefault
      set the defaultStack to the short name of me
      lock messages
      create invisible button "oxt_android_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "androidScriptError" & quote & " to stack " & quote & the short name of me & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      androidLog "INFO catching errors:" && tError
   end try
end androidCatchErrors

on androidScriptError pError
   androidLog "ERROR" && pError
end androidScriptError
