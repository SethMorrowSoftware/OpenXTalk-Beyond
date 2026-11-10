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
--       bundle    as release, with "android,app bundle": the App Bundle
--                 (<name>.aab) beside the package, signed with the same
--                 key; the builder downloads bundletool for it, once
--    and writes "BUILT <name> <apk>" or "BUILD FAILED <name> <why>",
--    "INFO <name> warnings <the builder's warnings>" and
--    "INFO <name> asked <the questions it answered>"; after a bundle
--    build, "INFO bundletool <the jar the builder keeps>".
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
--    OXT_ANDROID_BUILDS    the builds to make (comma separated; all five
--                          when empty)
--    OXT_ANDROID_KEYSTORE, OXT_ANDROID_ALIAS, OXT_ANDROID_PASSWORD
--                          the release build's keystore, its key's alias,
--                          and the one password of the store and the key
--    OXT_ANDROID_DEVICE    the serial of the device for Test (optional)
--    OXT_ANDROID_WORK      a folder for the units' made-up SDKs
--    OXT_ANDROID_PROBE     "java" for the Java layer's probe (see below),
--                          "busy" for the busy probe (see kBusyTick),
--                          "edge" for the edge probe (see kEdgeWait)
--    OXT_ANDROID_ENGINE    the probe's "android,engine" setting ("beyond"
--                          for OXT-Beyond's own engine; none when empty)
--
-- The Java layer's probe, AndroidJavaProbe, is the probe with more to do
-- before it turns green: it asks the Java layer of the runtime for what
-- Android 10 and newer refuse unless the Java says more (the Android
-- plan's phase 1), each step a call a script makes:
--   - a local notification an hour away (mobileCreateLocalNotification:
--     the alarm's PendingIntent), cancelled again at once;
--   - the app's own external folder (specialFolderPath("external
--     documents")), which the engine asks WRITE_EXTERNAL_STORAGE for
--     first, and androidHasPermission of that permission;
--   - a picture into the shared Pictures folder (mobileExportImageToAlbum
--     of kProbePicture as "oxt-beyond-probe": MediaStore on Android 10
--     and newer; android_check.py device --picture finds it there).
--   - a copy file (the standalone settings' "files", kProbeCopy in
--     oxt-probe.txt beside the stack), read back from the package
--     (specialFolderPath("engine")): the engine opens it at its place in
--     the installed package, so it must be stored there, in an App Bundle's
--     too.
-- It takes every step, says what each answered in the device's log (a
-- put with no container is the engine's log line there, tag LiveCode:
-- android_check.py device prints them), and turns kFailColor when any
-- failed. A Java layer that throws does not stop the app: the engine's
-- call into Java clears the exception (engine/src/mblandroiddc.cpp; its
-- MCLog line is compiled out of a release engine, so the log says
-- nothing) and the call answers no notification. LiveCode 9.6.3's layer
-- does that on Android 13 (Android builder run 42157367103). Its builds
-- declare POST_NOTIFICATIONS (the Android card's "Post Notifications"), so
-- that on Android 13 and newer the Java layer asks the user to allow it as
-- the notification is scheduled (android_check.py device --allow taps
-- Allow and checks that the package holds it), and WRITE_EXTERNAL_STORAGE
-- ("Write External Storage"), which Android 13 and newer refuse without
-- asking and the Java layer counts as granted there (Engine.java,
-- grantedWithoutAsking). Once green, its backKey turns it kBackColor,
-- and it does not pass the message, so the app stays (android_check.py
-- device --back presses the back key: Android 16 sends it to the back
-- callback of an app that targets API 36, which the builder makes of a
-- runtime whose Java layer is ready for it).

-- The probe's colours: the stack is saved red, and its openStack makes it
-- green, so a screen of green says that the engine ran the stack's script
constant kSavedColor = "204,34,0"
constant kRunColor = "31,158,90"
constant kFailColor = "230,160,0"
-- kBackColor: the Java layer's probe got backKey
constant kBackColor = "40,90,200"
-- kWaitColor: a probe's mouseUp (a tap) is waiting kProbeWait seconds
-- with messages, after which it is green again: android_check.py device
-- --density-in-wait changes the density while it waits, as Android makes
-- the activity again then (the engine's doDestroy, which hung there)
constant kWaitColor = "120,60,160"
constant kProbeWait = 20
-- kBusyTick and kBusyColor: the busy probe (OXT_ANDROID_PROBE "busy") is
-- the app probe that, once green, every kBusyTick milliseconds turns its
-- background the other of two greens (kRunColor and kBusyColor, which the
-- device check reads as the same) and sets the text of its field, so that
-- the engine redraws the whole screen, or has drawn it and yielded to
-- Android's thread to show it (MCScreenDC's updatewindow), much of the
-- time. Android 16 relaunching an app for a density change in the middle
-- of that hung LiveCode 9.6.3's engine for good (runs 42558963677 and
-- 42593463112, the app probe's field redrawing its caret); android_check.py
-- device --density --density-times makes Android relaunch it again and
-- again (the Java layer's LiveCodeActivity.onDestroy, Engine.finishDrawing).
-- Run 42601553621 relaunched the busy probe twelve times while it only
-- set its field's text, and none hung
constant kBusyTick = 10
constant kBusyColor = "31,150,90"
-- kEdgeWait: the edge probe (OXT_ANDROID_PROBE "edge") is the app probe
-- built to be drawn edge to edge (its "android,edge to edge" setting, the
-- Android card's "Edge to edge"): the Java layer draws it under the
-- see-through status and navigation bars from Android 11 on
-- (LiveCodeActivity.drawEdgeToEdge), so its green shows where they are.
-- Once green it says, then again kEdgeWait milliseconds later (by when
-- Android has given the window its insets), its screenRect and its
-- effective working screenRect, which leaves the bars, the display's
-- cutout and the keyboard out (Engine.getEffectiveWorkarea):
-- android_check.py device --edge-to-edge checks both. It also has an
-- adaptive icon (the "android,adaptive icon" settings), a themed one:
-- kProbePicture as its foreground and its monochrome image
-- (kProbeIconForeground and kProbeIconMonochrome, beside the stack) over
-- kRunColor (android_check.py verify --adaptive-icon checks the package)
constant kEdgeWait = 1000
constant kProbeIconForeground = "oxt-icon-foreground.png"
constant kProbeIconMonochrome = "oxt-icon-monochrome.png"
constant kIdentifier = "org.openxtalk.check.androidprobe"
-- The Java layer's probe's picture: one pixel, a PNG, as base64
constant kProbePicture = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
-- The Java layer's probe's copy file, oxt-probe.txt, and what it holds
constant kProbeCopyName = "oxt-probe.txt"
constant kProbeCopy = "OXT-Beyond probe copy file"

local sStarted
local sAsked
local sAskMessage
-- unitAppBundle's made-up bundletool, which appears while the builder
-- pauses between two tries of its download (unitBundletoolAppears)
local sBundletoolSource

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
private function builderCall pHandler, pArg1, pArg2, pArg3, pArg4, pArg5
   dispatch function pHandler to stack "revSaveAsAndroidStandalone" with pArg1, pArg2, pArg3, pArg4, pArg5
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
   unitJavaHome tWork
   unitTargetAPI tWork
   unitRelaunch tWork
   unitEdgeToEdge tWork
   unitAdaptiveIcon tWork
   unitEngine
   unitFirstTargetEngine
   unitAppBundle tWork
   androidUnit "required-sdk", deployCall("deployRequiredSDK") is "Android 13 (API 33) or newer", \
         "deployRequiredSDK() is" && deployCall("deployRequiredSDK")
end androidUnits

-- The API a package targets: the newest when the runtime's Java layer is
-- ready for it (its jar names the back callback and the system bars'
-- padding), 33 as before when it is not, and a stack's pin from 33 to the
-- newest; the large-screen property at 36 and only there
private command unitTargetAPI pWork
   local tRuntime, tSettings, tAnswer, tError, tManifest, tPin
   put pWork & "/runtime" into tRuntime
   removeTree tRuntime
   revSBEnsureFolder tRuntime
   androidUnit "target-no-java-layer", builderCall("androidTargetAPI", tSettings, tRuntime) is 33, \
         builderCall("androidTargetAPI", tSettings, tRuntime)
   -- 9.6.3's jar has neither name; one of the two is not enough
   put textEncode("PK" & "com/runrev/android/LiveCodeActivity.class" & \
         "com/runrev/android/LiveCodeActivity$BackCallback.class", "UTF-8") into url ("binfile:" & tRuntime & "/Classes")
   androidUnit "target-java-layer-not-ready", builderCall("androidJavaLayerIsReady", tRuntime) is false and \
         builderCall("androidTargetAPI", tSettings, tRuntime) is 33, builderCall("androidTargetAPI", tSettings, tRuntime)
   put textEncode("PK" & "com/runrev/android/LiveCodeActivity$BackCallback.class" & numToByte(0) & \
         "com/runrev/android/LiveCodeActivity$SystemBarsPadding.class", "UTF-8") into url ("binfile:" & tRuntime & "/Classes")
   put builderCall("androidTargetAPI", tSettings, tRuntime) into tAnswer
   androidUnit "target-java-layer-ready", builderCall("androidJavaLayerIsReady", tRuntime) is true and \
         tAnswer is deployCall("deployNewestTargetSdkVersion") and tAnswer is 36, tAnswer
   -- a pin, with the layer ready or not
   repeat for each item tPin in "33,34,35,36"
      put tPin into tSettings["android,target sdk"]
      androidUnit "target-pinned-" & tPin, builderCall("androidTargetAPI", tSettings, tRuntime) is tPin and \
            builderCall("androidTargetAPI", tSettings, pWork & "/no-runtime") is tPin, \
            builderCall("androidTargetAPI", tSettings, tRuntime)
   end repeat
   repeat for each item tPin in "32,37,thirty,35.5"
      put tPin into tSettings["android,target sdk"]
      put empty into tError
      try
         get builderCall("androidTargetAPI", tSettings, tRuntime)
      catch tError
      end try
      androidUnit "target-pin-refused-" & tPin, tError contains "is not one the builder can make: from 33 to 36", \
            "answered" && it & ", threw" && tError
   end repeat
   removeTree tRuntime
   -- the large-screen property: at 36, once, in the application; below, nothing
   put "<manifest>" & return & "  <application>" & return & "  </application>" & return & "</manifest>" into tManifest
   androidUnit "large-screen-below-36", builderCall("androidKeepLargeScreenLayout", tManifest, 35) is tManifest, \
         builderCall("androidKeepLargeScreenLayout", tManifest, 35)
   put builderCall("androidKeepLargeScreenLayout", tManifest, 36) into tAnswer
   androidUnit "large-screen-36", tAnswer is "<manifest>" & return & "  <application>" & return & \
         "    <property android:name=" & quote & "android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY" & quote && \
         "android:value=" & quote & "true" & quote && "/>" & return & "  </application>" & return & "</manifest>", tAnswer
end unitTargetAPI

-- The Android engine a build takes (androidRuntimeFolder): LiveCode
-- 9.6.3's, Runtime/Android, for a stack that names none or "9.6.3", and
-- OXT-Beyond's own, which the runtimes carry beside it in
-- Runtime/Android/Beyond, for a stack whose "android,engine" is "beyond";
-- asked of runtimes without it, or for an engine of another name, the
-- build stops and says why. The release's runtimes have no Beyond folder
-- (android.yml), so the unit makes one for its "beyond" answers, and takes
-- it away again; one that is there already it leaves as it is
private command unitEngine
   local tSettings, tRuntime, tBeyond, tMade, tError, tName
   put builderCall("revMobileRuntimeFolder", "build") into tRuntime
   put tRuntime & "/Beyond" into tBeyond
   androidUnit "engine-default", builderCall("androidRuntimeFolder", "build", tSettings) is tRuntime, \
         builderCall("androidRuntimeFolder", "build", tSettings)
   put "9.6.3" into tSettings["android,engine"]
   androidUnit "engine-9.6.3", builderCall("androidRuntimeFolder", "build", tSettings) is tRuntime, \
         builderCall("androidRuntimeFolder", "build", tSettings)
   put "beyond" into tSettings["android,engine"]
   put there is not a folder tBeyond into tMade
   if tMade then
      put empty into tError
      try
         get builderCall("androidRuntimeFolder", "build", tSettings)
      catch tError
      end try
      androidUnit "engine-beyond-missing", tError contains "these runtimes do not have it:" && tBeyond, \
            "answered" && it & ", threw" && tError
      revSBEnsureFolder tBeyond
   end if
   androidUnit "engine-beyond", builderCall("androidRuntimeFolder", "build", tSettings) is tBeyond, \
         builderCall("androidRuntimeFolder", "build", tSettings)
   if tMade then
      removeTree tBeyond
   end if
   repeat for each item tName in "beyond2,9.6,oxt-beyond"
      put tName into tSettings["android,engine"]
      put empty into tError
      try
         get builderCall("androidRuntimeFolder", "build", tSettings)
      catch tError
      end try
      androidUnit "engine-unknown-" & tName, tError contains "Unknown Android engine" && quote & tName & quote, \
            "answered" && it & ", threw" && tError
   end repeat
end unitEngine

-- The engine a stack has once the Android card ticks its first
-- architecture (androidEngineOnFirstTarget, from the settings before the
-- tick): OXT-Beyond's own for a stack set up for Android now, the card's
-- own settings of any stack that opens it notwithstanding, when the
-- runtimes carry it; what it had for one set up before (an architecture
-- saved, ticked or not, or the "android" setting, on or off) or that names
-- an engine; and empty, LiveCode 9.6.3's, when the runtimes have none. As
-- in unitEngine, a Beyond folder the unit makes it takes away again
private command unitFirstTargetEngine
   local tSettings, tRuntime, tBeyond, tMade, tArch, tAnswer, tEngine
   put builderCall("revMobileRuntimeFolder", "build") into tRuntime
   put tRuntime & "/Beyond" into tBeyond
   put there is not a folder tBeyond into tMade
   if tMade then
      put builderCall("androidEngineOnFirstTarget", tSettings) into tAnswer
      androidUnit "first-engine-no-beyond", tAnswer is empty, tAnswer
      revSBEnsureFolder tBeyond
   end if
   put builderCall("androidEngineOnFirstTarget", tSettings) into tAnswer
   androidUnit "first-engine-new", tAnswer is "beyond", tAnswer
   put "Google" into tSettings["android,billingProvider"]
   put "com.yourcompany.yourapp" into tSettings["android,identifier"]
   put builderCall("androidEngineOnFirstTarget", tSettings) into tAnswer
   androidUnit "first-engine-new-card-settings", tAnswer is "beyond", tAnswer
   repeat for each item tArch in "armv7,arm64,x86,x86_64"
      repeat for each item tEngine in "true,false"
         delete variable tSettings
         put tEngine into tSettings["Android," & tArch]
         put builderCall("androidEngineOnFirstTarget", tSettings) into tAnswer
         androidUnit "first-engine-had-" & tArch & "-" & tEngine, tAnswer is empty, tAnswer
      end repeat
   end repeat
   repeat for each item tEngine in "true,false"
      delete variable tSettings
      put tEngine into tSettings["android"]
      put builderCall("androidEngineOnFirstTarget", tSettings) into tAnswer
      androidUnit "first-engine-android-" & tEngine, tAnswer is empty, tAnswer
   end repeat
   repeat for each item tEngine in "9.6.3,beyond"
      delete variable tSettings
      put tEngine into tSettings["android,engine"]
      put builderCall("androidEngineOnFirstTarget", tSettings) into tAnswer
      androidUnit "first-engine-names-" & tEngine, tAnswer is tEngine, tAnswer
      put false into tSettings["Android,armv7"]
      put builderCall("androidEngineOnFirstTarget", tSettings) into tAnswer
      androidUnit "first-engine-had-armv7-names-" & tEngine, tAnswer is tEngine, tAnswer
   end repeat
   if tMade then
      removeTree tBeyond
   end if
end unitFirstTargetEngine

-- The engine runs once in a process: the configuration changes the app
-- goes on through (LiveCode's four first, as before, and not the density,
-- for which it starts again), and the activity that starts it again in a
-- new process, declared once in the application where the runtime's Java
-- layer has it and not otherwise (9.6.3's has not), on made-up runtimes
private command unitRelaunch pWork
   local tRuntime, tAnswer, tManifest, tWanted
   put builderCall("androidConfigChanges") into tAnswer
   set the itemDelimiter to "|"
   androidUnit "config-changes", item 1 to 4 of tAnswer is "keyboardHidden|orientation|uiMode|screenSize" and \
         "fontScale" is among the items of tAnswer and "locale" is among the items of tAnswer and \
         "smallestScreenSize" is among the items of tAnswer and "density" is not among the items of tAnswer, tAnswer
   set the itemDelimiter to comma
   put "<manifest>" & return & "  <application>" & return & "  </application>" & return & "</manifest>" into tManifest
   put pWork & "/relaunch-runtime" into tRuntime
   removeTree tRuntime
   revSBEnsureFolder tRuntime
   androidUnit "relaunch-no-java-layer", builderCall("androidDeclareRelaunch", tManifest, tRuntime) is tManifest, \
         builderCall("androidDeclareRelaunch", tManifest, tRuntime)
   put textEncode("PK" & "com/runrev/android/LiveCodeActivity.class", "UTF-8") into url ("binfile:" & tRuntime & "/Classes")
   androidUnit "relaunch-java-layer-without-it", builderCall("androidDeclareRelaunch", tManifest, tRuntime) is tManifest, \
         builderCall("androidDeclareRelaunch", tManifest, tRuntime)
   put textEncode("PK" & "com/runrev/android/LiveCodeActivity.class" & numToByte(0) & \
         "com/runrev/android/RelaunchActivity.class", "UTF-8") into url ("binfile:" & tRuntime & "/Classes")
   put builderCall("androidDeclareRelaunch", tManifest, tRuntime) into tAnswer
   put "<manifest>" & return & "  <application>" & return & \
         "    <activity android:name=" & quote & "com.runrev.android.RelaunchActivity" & quote & return & \
         "      android:process=" & quote & ":relaunch" & quote & return & \
         "      android:theme=" & quote & "@android:style/Theme.Translucent.NoTitleBar" & quote & return & \
         "      android:excludeFromRecents=" & quote & "true" & quote & return & \
         "      android:noHistory=" & quote & "true" & quote & return & \
         "      android:exported=" & quote & "false" & quote && "/>" & return & \
         "  </application>" & return & "</manifest>" into tWanted
   androidUnit "relaunch-declared", tAnswer is tWanted, tAnswer
   removeTree tRuntime
end unitRelaunch

-- A stack drawn edge to edge (its "android,edge to edge" setting): the
-- manifest asks the Java layer for it with one meta-data of the
-- application where the runtime's layer can draw it so (its jar has
-- LiveCodeActivity$EdgeToEdge), the build stops where it cannot (9.6.3's,
-- a made-up runtime without it), and any other stack's manifest is left
-- as it was, on made-up runtimes
private command unitEdgeToEdge pWork
   local tRuntime, tSettings, tAnswer, tManifest, tError, tWanted
   put "<manifest>" & return & "  <application>" & return & "  </application>" & return & "</manifest>" into tManifest
   put pWork & "/edge-runtime" into tRuntime
   removeTree tRuntime
   revSBEnsureFolder tRuntime
   androidUnit "edge-not-asked", builderCall("androidAskForEdgeToEdge", tManifest, tSettings, tRuntime) is tManifest, \
         builderCall("androidAskForEdgeToEdge", tManifest, tSettings, tRuntime)
   put false into tSettings["android,edge to edge"]
   androidUnit "edge-unticked", builderCall("androidAskForEdgeToEdge", tManifest, tSettings, tRuntime) is tManifest, \
         builderCall("androidAskForEdgeToEdge", tManifest, tSettings, tRuntime)
   put true into tSettings["android,edge to edge"]
   -- asked of a runtime with no Java layer, and of one without the class
   repeat for each item tAnswer in "none,without"
      if tAnswer is "without" then
         put textEncode("PK" & "com/runrev/android/LiveCodeActivity.class" & numToByte(0) & \
               "com/runrev/android/LiveCodeActivity$SystemBarsPadding.class", "UTF-8") into url ("binfile:" & tRuntime & "/Classes")
      end if
      put empty into tError
      try
         get builderCall("androidAskForEdgeToEdge", tManifest, tSettings, tRuntime)
      catch tError
      end try
      androidUnit "edge-java-layer-" & tAnswer, tError contains "Java layer cannot draw it so" and \
            tError contains "untick Edge to edge on the Android card", "answered" && it & ", threw" && tError
   end repeat
   put textEncode("PK" & "com/runrev/android/LiveCodeActivity.class" & numToByte(0) & \
         "com/runrev/android/LiveCodeActivity$EdgeToEdge.class", "UTF-8") into url ("binfile:" & tRuntime & "/Classes")
   put builderCall("androidAskForEdgeToEdge", tManifest, tSettings, tRuntime) into tAnswer
   put "<manifest>" & return & "  <application>" & return & \
         "    <meta-data android:name=" & quote & "com.runrev.android.EDGE_TO_EDGE" & quote && \
         "android:value=" & quote & "true" & quote && "/>" & return & \
         "  </application>" & return & "</manifest>" into tWanted
   androidUnit "edge-asked", tAnswer is tWanted, tAnswer
   -- as the card stores it (a string)
   put "true" into tSettings["android,edge to edge"]
   androidUnit "edge-asked-as-stored", builderCall("androidAskForEdgeToEdge", tManifest, tSettings, tRuntime) is tWanted, \
         builderCall("androidAskForEdgeToEdge", tManifest, tSettings, tRuntime)
   removeTree tRuntime
end unitEdgeToEdge

-- The adaptive icon: none for a stack that names no foreground; its
-- images found (relative to the stack's folder), PNG files, its colour
-- read in the three forms it takes; a themed icon only with a foreground;
-- the resources it writes
private command unitAdaptiveIcon pWork
   local tFolder, tSettings, tAnswer, tError, tPNG, tRes, tWanted, tColour, tWritten
   put pWork & "/adaptive-icon" into tFolder
   removeTree tFolder
   revSBEnsureFolder tFolder
   put base64Decode(kProbePicture) into tPNG
   put tPNG into url ("binfile:" & tFolder & "/fg.png")
   put tPNG into url ("binfile:" & tFolder & "/mono.png")
   put "not a picture" into url ("binfile:" & tFolder & "/fg.txt")
   androidUnit "icon-not-asked", builderCall("androidAdaptiveIcon", tSettings, tFolder) is empty, \
         builderCall("androidAdaptiveIcon", tSettings, tFolder)
   repeat for each line tAnswer in "themed only|a themed icon is the monochrome layer" & return & \
         "missing|foreground image is not there:" & return & "not a PNG|foreground image is not a PNG file:" & return & \
         "bad colour|is not one the build can read: give it as #RRGGBB, #AARRGGBB or r,g,b"
      set the itemDelimiter to "|"
      put empty into tSettings
      switch item 1 of tAnswer
         case "themed only"
            put "mono.png" into tSettings["android,themed icon"]
            break
         case "missing"
            put "nothing.png" into tSettings["android,adaptive icon"]
            break
         case "not a PNG"
            put "fg.txt" into tSettings["android,adaptive icon"]
            break
         case "bad colour"
            put "fg.png" into tSettings["android,adaptive icon"]
            put "256,0,0" into tSettings["android,adaptive icon background"]
            break
      end switch
      put empty into tError
      try
         get builderCall("androidAdaptiveIcon", tSettings, tFolder)
      catch tError
      end try
      androidUnit "icon-refused-" & word 1 of item 1 of tAnswer, tError contains item 2 of tAnswer, \
            "answered" && it & ", threw" && tError
      set the itemDelimiter to comma
   end repeat
   put empty into tSettings
   put "fg.png" into tSettings["android,adaptive icon"]
   put builderCall("androidAdaptiveIcon", tSettings, tFolder) into tAnswer
   androidUnit "icon-foreground", tAnswer["foreground"] is (tFolder & "/fg.png") and \
         tAnswer["monochrome"] is empty and tAnswer["background"] is "#FFFFFFFF", \
         tAnswer["foreground"] && tAnswer["monochrome"] && tAnswer["background"]
   put tFolder & "/mono.png" into tSettings["android,themed icon"]
   put "31,158,90" into tSettings["android,adaptive icon background"]
   put builderCall("androidAdaptiveIcon", tSettings, tFolder) into tAnswer
   androidUnit "icon-themed", tAnswer["monochrome"] is (tFolder & "/mono.png") and \
         tAnswer["background"] is "#FF1F9E5A", tAnswer["monochrome"] && tAnswer["background"]
   -- the colour's forms
   repeat for each line tColour in "|#FFFFFFFF" & return & "#1f9e5a|#FF1F9E5A" & return & \
         "#801F9E5A|#801F9E5A" & return & " 0, 128 ,255 |#FF0080FF"
      set the itemDelimiter to "|"
      androidUnit "icon-colour-" & item 2 of tColour, \
            builderCall("androidIconColour", item 1 of tColour) is item 2 of tColour, \
            builderCall("androidIconColour", item 1 of tColour)
      set the itemDelimiter to comma
   end repeat
   repeat for each line tColour in "red" & return & "#12345" & return & "1,2" & return & "-1,0,0" & return & "#GG0000"
      put empty into tError
      try
         get builderCall("androidIconColour", tColour)
      catch tError
      end try
      androidUnit "icon-colour-refused-" & tColour, tError contains "is not one the build can read", \
            "answered" && it & ", threw" && tError
   end repeat
   -- the resources
   put tFolder & "/res" into tRes
   revSBEnsureFolder tRes
   dispatch "androidAddAdaptiveIcon" to stack "revSaveAsAndroidStandalone" with tAnswer, tRes
   put the result into tWritten
   put "<?xml version=" & quote & "1.0" & quote && "encoding=" & quote & "utf-8" & quote & "?>" & lf & \
         "<adaptive-icon xmlns:android=" & quote & "http://schemas.android.com/apk/res/android" & quote & ">" & lf & \
         "    <background android:drawable=" & quote & "@color/oxt_icon_background" & quote & "/>" & lf & \
         "    <foreground android:drawable=" & quote & "@drawable/icon_foreground" & quote & "/>" & lf & \
         "    <monochrome android:drawable=" & quote & "@drawable/icon_monochrome" & quote & "/>" & lf & \
         "</adaptive-icon>" & lf into tWanted
   androidUnit "icon-resources", \
         url ("binfile:" & tRes & "/drawable-nodpi/icon_foreground.png") is tPNG and \
         url ("binfile:" & tRes & "/drawable-nodpi/icon_monochrome.png") is tPNG and \
         textDecode(url ("binfile:" & tRes & "/drawable-anydpi-v26/icon.xml"), "UTF-8") is tWanted and \
         textDecode(url ("binfile:" & tRes & "/values/oxt_icon_background.xml"), "UTF-8") contains \
         "<color name=" & quote & "oxt_icon_background" & quote & ">#FF1F9E5A</color>", \
         "wrote" && files(tRes & "/drawable-nodpi")
   -- and it names what it wrote, which the build deletes with its other
   -- files
   androidUnit "icon-written", tWritten is \
         tRes & "/drawable-nodpi/icon_foreground.png" & return & \
         tRes & "/drawable-nodpi/icon_monochrome.png" & return & \
         tRes & "/drawable-anydpi-v26/icon.xml" & return & \
         tRes & "/values/oxt_icon_background.xml" & return, tWritten
   -- no monochrome image: no monochrome layer
   delete variable tAnswer["monochrome"]
   androidUnit "icon-no-monochrome", not (builderCall("androidAdaptiveIconXML", tAnswer) contains "monochrome"), \
         builderCall("androidAdaptiveIconXML", tAnswer)
   removeTree tFolder
end unitAdaptiveIcon

-- The App Bundle: its name beside the package, where each file of the
-- package goes in the bundle's base module, bundletool's settings, a
-- file's SHA-256, and which bundletool a build runs (the Preferences' copy
-- as it is; the cached one while its SHA-256 is the one asked for; one
-- downloaded otherwise, checked before it is kept), on made-up files with
-- binfile: URLs for the downloads (the bundle build downloads the real
-- one); and the JDK's download (androidDownloadWithJava), which a failed
-- libURL download falls back to, with file: and jar: URLs and this
-- check's JDK
private command unitAppBundle pWork
   local tWanted, tLine, tAnswer, tFolder, tSource, tOther, tCache, tSHA, tError, tJava, tZip, tData, tPart
   put builderCall("androidBundlePath", "/a/b/My App.apk") & "|" & builderCall("androidBundlePath", "C:/a/App.APK") & \
         "|" & builderCall("androidBundlePath", "/a/App") into tAnswer
   androidUnit "bundle-path", tAnswer is "/a/b/My App.aab|C:/a/App.aab|/a/App.aab", tAnswer

   put "AndroidManifest.xml=manifest/AndroidManifest.xml" & return & \
         "resources.pb=resources.pb" & return & \
         "res/drawable/notify_icon.png=res/drawable/notify_icon.png" & return & \
         "assets/fonts/x.ttf=assets/fonts/x.ttf" & return & \
         "assets/oxt-probe.txt=assets/oxt-probe.txt" & return & \
         "lib/arm64-v8a/librevandroid.so=lib/arm64-v8a/librevandroid.so" & return & \
         "lib/1.jar=" & return & \
         "classes.dex=dex/classes.dex" & return & \
         "classes2.dex=dex/classes2.dex" & return & \
         "notes/classes.dex=root/notes/classes.dex" & return & \
         "classes/a.dex=root/classes/a.dex" & return & \
         "kotlin/collections.kotlin_builtins=root/kotlin/collections.kotlin_builtins" into tWanted
   set the itemDelimiter to "="
   repeat for each line tLine in tWanted
      put builderCall("androidBundleModulePath", item 1 of tLine) into tAnswer
      androidUnit "bundle-module-" & item 1 of tLine, tAnswer is item 2 of tLine, \
            "gave" && quote & tAnswer & quote & ", wanted" && quote & item 2 of tLine & quote
   end repeat
   set the itemDelimiter to comma

   put builderCall("androidBundleConfig") into tAnswer
   androidUnit "bundle-config", tAnswer contains quote & "uncompressNativeLibraries" & quote & ": { " & quote & \
         "enabled" & quote & ": false }" and tAnswer contains quote & "uncompressedGlob" & quote & ": [ " & quote & \
         "assets/**" & quote & " ]", tAnswer

   put pWork & "/bundletool" into tFolder
   removeTree tFolder
   revSBEnsureFolder tFolder
   put tFolder & "/source.jar" into tSource
   put "abc" into url ("binfile:" & tSource)
   put builderCall("androidFileSHA256", tSource) into tSHA
   androidUnit "bundle-sha256", tSHA is "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", tSHA
   put tFolder & "/other.jar" into tOther
   put "abd" into url ("binfile:" & tOther)
   put tFolder & "/cache/Android/bundletool.jar" into tCache

   -- the Preferences' copy, as it is
   put builderCall("androidBundletool", tOther, tCache, "binfile:" & tSource, tSHA) into tAnswer
   androidUnit "bundletool-preference", tAnswer is tOther and there is no file tCache, tAnswer
   put empty into tError
   try
      get builderCall("androidBundletool", tFolder & "/none.jar", tCache, "binfile:" & tSource, tSHA)
   catch tError
   end try
   androidUnit "bundletool-preference-missing", tError contains "names" && tFolder & "/none.jar, and there is no such file", \
         "answered" && it & ", threw" && tError
   -- downloaded, checked, and kept in the cache
   put builderCall("androidBundletool", empty, tCache, "binfile:" & tSource, tSHA) into tAnswer
   androidUnit "bundletool-download", tAnswer is tCache and there is a file tCache and \
         url ("binfile:" & tCache) is "abc", tAnswer
   -- the cached one, with nothing to download
   put builderCall("androidBundletool", empty, tCache, "binfile:" & tFolder & "/none.jar", tSHA) into tAnswer
   androidUnit "bundletool-cached", tAnswer is tCache, tAnswer
   -- a cached file that is not the one asked for is downloaded again, and a
   -- download that is not that one is refused, and not kept
   put "ab" into url ("binfile:" & tCache)
   put builderCall("androidBundletool", empty, tCache, "binfile:" & tSource, tSHA) into tAnswer
   androidUnit "bundletool-cached-wrong", tAnswer is tCache and url ("binfile:" & tCache) is "abc", tAnswer
   delete file tCache
   put empty into tError
   try
      get builderCall("androidBundletool", empty, tCache, "binfile:" & tOther, tSHA)
   catch tError
   end try
   androidUnit "bundletool-download-wrong", tError contains "is not the file this builder takes" and \
         there is no file tCache, "answered" && it & ", threw" && tError
   put empty into tError
   try
      get builderCall("androidBundletool", empty, tCache, "binfile:" & tFolder & "/none.jar", tSHA)
   catch tError
   end try
   androidUnit "bundletool-no-download", tError contains "could not download bundletool" and \
         tError contains "(tried 3 times)" and tError contains "put it at" && tCache and \
         there is no file tCache, "answered" && it & ", threw" && tError
   -- a download that fails is tried again: the file appears half a second
   -- after the first try, while the builder pauses before the second
   delete file tSource
   put tSource into sBundletoolSource
   send "unitBundletoolAppears" to me in 500 milliseconds
   put empty into tAnswer
   put empty into tError
   try
      put builderCall("androidBundletool", empty, tCache, "binfile:" & tSource, tSHA) into tAnswer
   catch tError
   end try
   androidUnit "bundletool-download-again", tAnswer is tCache and there is a file tCache and \
         url ("binfile:" & tCache) is "abc", "answered" && tAnswer & ", threw" && tError
   delete file tCache

   -- the JDK's download: a file: URL, and one that is not there
   put deployCall("pathToJava", $OXT_ANDROID_JDK) into tJava
   put tFolder & "/java.part" into tPart
   put builderCall("androidDownloadWithJava", tJava, fileURL(tSource), tPart) into tAnswer
   androidUnit "bundletool-java-download", tAnswer is empty and url ("binfile:" & tPart) is "abc", \
         tJava & ":" && tAnswer
   delete file tPart
   put builderCall("androidDownloadWithJava", tJava, fileURL(tFolder & "/none.jar"), tPart) into tAnswer
   androidUnit "bundletool-java-no-download", tAnswer begins with "the JDK could not download it:" and \
         tAnswer contains "Error:" and there is no file tPart, tAnswer
   -- a download libURL cannot make (a jar: URL, the source in a zip) comes
   -- with the JDK on the second try
   put tFolder & "/source.zip" into tZip
   put "abc" into tData
   revZipOpenArchive tZip, "write"
   revZipAddItemWithData tZip, "source.jar", "tData"
   revZipCloseArchive tZip
   put empty into tAnswer
   put empty into tError
   try
      put builderCall("androidBundletool", empty, tCache, "jar:" & fileURL(tZip) & "!/source.jar", tSHA, tJava) into tAnswer
   catch tError
   end try
   androidUnit "bundletool-download-java", tAnswer is tCache and url ("binfile:" & tCache) is "abc", \
         "answered" && tAnswer & ", threw" && tError
   delete file tCache
   -- and neither can make one that is not there, three times
   put empty into tError
   try
      get builderCall("androidBundletool", empty, tCache, "jar:" & fileURL(tFolder & "/none.zip") & "!/source.jar", tSHA, tJava)
   catch tError
   end try
   androidUnit "bundletool-no-download-java", tError contains "could not download bundletool" and \
         tError contains "the JDK could not download it:" and tError contains "(tried 3 times)" and \
         there is no file tCache, "answered" && it & ", threw" && tError
   removeTree tFolder
   put builderCall("androidBundletoolCacheFile") into tAnswer
   androidUnit "bundletool-cache-file", tAnswer is revEnvironmentUserCachePath() & "/Android/bundletool-all-1.18.3.jar", tAnswer
end unitAppBundle

-- A file's file: URL (file:///C:/a on Windows, file:///a elsewhere)
private function fileURL pPath
   if char 1 of pPath is slash then
      return "file://" & pPath
   end if
   return "file:///" & pPath
end fileURL

-- unitAppBundle's made-up bundletool appears, as a download that worked
-- the second time
on unitBundletoolAppears
   put "abc" into url ("binfile:" & sBundletoolSource)
end unitBundletoolAppears

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

-- The JAVA_HOME that the SDK's d8 and apksigner get: the JDK of
-- Preferences when it is at least as new as JAVA_HOME's, and JAVA_HOME as
-- it was otherwise (unset, newer, or of a version that cannot be read)
private command unitJavaHome pWork
   local tRoot, tJdk17, tJdk8, tJdk21, tNoRelease, tEarly
   put pWork & "/java" into tRoot
   removeTree tRoot
   put tRoot & "/jdk-17" into tJdk17
   put tRoot & "/jdk-8" into tJdk8
   put tRoot & "/jdk-21" into tJdk21
   put tRoot & "/jre" into tNoRelease
   put tRoot & "/jdk-22-ea" into tEarly
   touchFile tJdk17 & "/release"
   put "IMPLEMENTOR=" & quote & "Eclipse Adoptium" & quote & return & "JAVA_VERSION=" & quote & "17.0.20" & quote & return \
         into url ("file:" & tJdk17 & "/release")
   touchFile tJdk8 & "/release"
   put "JAVA_VERSION=" & quote & "1.8.0_462" & quote & numToChar(13) & numToChar(10) \
         into url ("binfile:" & tJdk8 & "/release")
   touchFile tJdk21 & "/release"
   put "JAVA_VERSION=" & quote & "21.0.9" & quote & return into url ("file:" & tJdk21 & "/release")
   revSBEnsureFolder tNoRelease
   touchFile tEarly & "/release"
   put "JAVA_VERSION=" & quote & "22-ea" & quote & return into url ("file:" & tEarly & "/release")
   
   androidUnit "java-home-unset", builderCall("androidJavaHomeFor", tJdk17, empty) is empty, \
         builderCall("androidJavaHomeFor", tJdk17, empty)
   androidUnit "java-home-older", builderCall("androidJavaHomeFor", tJdk17, tJdk8) is tJdk17, \
         builderCall("androidJavaHomeFor", tJdk17, tJdk8)
   androidUnit "java-home-newer", builderCall("androidJavaHomeFor", tJdk17, tJdk21) is tJdk21, \
         builderCall("androidJavaHomeFor", tJdk17, tJdk21)
   androidUnit "java-home-same", builderCall("androidJavaHomeFor", tJdk21, tJdk21) is tJdk21, \
         builderCall("androidJavaHomeFor", tJdk21, tJdk21)
   androidUnit "java-home-unreadable", builderCall("androidJavaHomeFor", tJdk17, tNoRelease) is tNoRelease, \
         builderCall("androidJavaHomeFor", tJdk17, tNoRelease)
   androidUnit "java-home-old-preferences", builderCall("androidJavaHomeFor", tJdk8, tJdk17) is tJdk17, \
         builderCall("androidJavaHomeFor", tJdk8, tJdk17)
   androidUnit "java-home-early-access", builderCall("androidJavaHomeFor", tEarly, tJdk21) is tEarly, \
         builderCall("androidJavaHomeFor", tEarly, tJdk21)
   androidUnit "java-home-no-preferences", builderCall("androidJavaHomeFor", empty, tJdk8) is tJdk8, \
         builderCall("androidJavaHomeFor", empty, tJdk8)
   removeTree tRoot
end unitJavaHome

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
-- With OXT_ANDROID_PROBE "java" it is the Java layer's probe (see the
-- header), and with "busy" the busy probe (see kBusyTick), each a stack
-- of its own name.
private function probeName
   if $OXT_ANDROID_PROBE is "java" then
      return "AndroidJavaProbe"
   end if
   if $OXT_ANDROID_PROBE is "busy" then
      return "AndroidBusyProbe"
   end if
   if $OXT_ANDROID_PROBE is "edge" then
      return "AndroidEdgeProbe"
   end if
   return "AndroidProbe"
end probeName

private function probeScript
   local tScript
   put "on openStack" & return into tScript
   if probeName() is "AndroidJavaProbe" then
      -- every step, each answer said in the log (see the header)
      put "   local tFailed, tId, tFolder, tHas, tExport, tCopy" & return & \
            "   put false into tFailed" & return & \
            "   mobileCreateLocalNotification" && quote & "OXT-Beyond Android check" & quote & comma && \
            quote & "Open" & quote & comma && quote & "probe" & quote & ", the seconds + 3600, false, 0" & return & \
            "   put the result into tId" & return & \
            "   put" && quote & "OXT-Beyond probe: local notification" & quote && "&& tId" & return & \
            "   if tId is not an integer or tId < 1 then" & return & \
            "      put true into tFailed" & return & \
            "   else" & return & \
            "      mobileCancelLocalNotification tId" & return & \
            "   end if" & return & \
            "   put specialFolderPath(" & quote & "external documents" & quote & ") into tFolder" & return & \
            "   put" && quote & "OXT-Beyond probe: external documents" & quote && "&& tFolder" & return & \
            "   if tFolder is empty then put true into tFailed" & return & \
            "   put androidHasPermission(" & quote & "android.permission.WRITE_EXTERNAL_STORAGE" & quote & \
            ") into tHas" & return & \
            "   put" && quote & "OXT-Beyond probe: has WRITE_EXTERNAL_STORAGE" & quote && "&& tHas" & return & \
            "   if tHas is not true then put true into tFailed" & return & \
            "   mobileExportImageToAlbum base64Decode(" & quote & kProbePicture & quote & ")," && \
            quote & "oxt-beyond-probe" & quote & return & \
            "   put the result into tExport" & return & \
            "   put" && quote & "OXT-Beyond probe: export to album" & quote && "&& tExport" & return & \
            "   if tExport is not empty then put true into tFailed" & return & \
            "   put url (" & quote & "binfile:" & quote && "& specialFolderPath(" & quote & "engine" & quote & ") &" && \
            quote & "/" & kProbeCopyName & quote & ") into tCopy" & return & \
            "   put" && quote & "OXT-Beyond probe: copy file" & quote && "&& tCopy" & return & \
            "   if tCopy is not" && quote & kProbeCopy & quote && "then put true into tFailed" & return & \
            "   if tFailed then" & return & \
            "      set the backgroundColor of me to" && quote & kFailColor & quote & return & \
            "      exit openStack" & return & \
            "   end if" & return after tScript
   end if
   put "   set the backgroundColor of me to" && quote & kRunColor & quote & return after tScript
   if probeName() is "AndroidBusyProbe" then
      -- it draws without a pause from the start (see kBusyTick)
      put "   send" && quote & "probeBusy" & quote && "to me in" && kBusyTick && "milliseconds" & return after tScript
   end if
   if probeName() is "AndroidEdgeProbe" then
      -- its screen's rects, now and once its window has its insets (see
      -- kEdgeWait)
      put "   probeEdge" & return & \
            "   send" && quote & "probeEdge" & quote && "to me in" && kEdgeWait && "milliseconds" & return after tScript
   end if
   put "end openStack" after tScript
   if probeName() is "AndroidEdgeProbe" then
      put return & "on probeEdge" & return & \
            "   put" && quote & "OXT-Beyond probe: screenRect" & quote && "&& the screenRect" & return & \
            "   put" && quote & "OXT-Beyond probe: effective working screenRect" & quote && \
            "&& the effective working screenRect" & return & \
            "end probeEdge" after tScript
   end if
   if probeName() is "AndroidBusyProbe" then
      put return & "local sBusy" & return & "on probeBusy" & return & \
            "   add 1 to sBusy" & return & \
            "   if sBusy mod 2 is 1 then" & return & \
            "      set the backgroundColor of me to" && quote & kBusyColor & quote & return & \
            "   else" & return & \
            "      set the backgroundColor of me to" && quote & kRunColor & quote & return & \
            "   end if" & return & \
            "   set the text of field" && quote & "Probe" & quote && "to the milliseconds" & return & \
            "   send" && quote & "probeBusy" & quote && "to me in" && kBusyTick && "milliseconds" & return & \
            "end probeBusy" after tScript
   end if
   -- a tap: a script waiting (kWaitColor), then green again
   put return & "on mouseUp" & return & \
         "   set the backgroundColor of me to" && quote & kWaitColor & quote & return & \
         "   wait" && kProbeWait && "seconds with messages" & return & \
         "   set the backgroundColor of me to" && quote & kRunColor & quote & return & \
         "end mouseUp" after tScript
   if probeName() is "AndroidJavaProbe" then
      -- the back key, not passed (see the header)
      put return & "on backKey" & return & \
            "   set the backgroundColor of me to" && quote & kBackColor & quote & return & \
            "end backKey" after tScript
   end if
   return tScript
end probeScript

private command makeProbeStack
   local tProbe
   put probeName() into tProbe
   if there is a file $OXT_ANDROID_STACK then
      lock messages
      get the short name of stack $OXT_ANDROID_STACK
      unlock messages
      if it is not tProbe then
         throw $OXT_ANDROID_STACK && "is not the probe stack" && tProbe & ":" && it
      end if
      exit makeProbeStack
   end if
   create stack tProbe
   set the rect of stack tProbe to 0,0,320,480
   set the backgroundColor of stack tProbe to kSavedColor
   set the fullscreenMode of stack tProbe to "exactFit"
   set the script of stack tProbe to probeScript()
   local tDefault
   put the defaultStack into tDefault
   set the defaultStack to tProbe
   create field "Probe"
   set the rect of field "Probe" of stack tProbe to 20,20,300,60
   set the text of field "Probe" of stack tProbe to "OXT-Beyond Android check"
   set the defaultStack to tDefault
   save stack tProbe as $OXT_ANDROID_STACK
   if the result is not empty then
      throw "cannot save the probe stack as" && $OXT_ANDROID_STACK & ":" && the result
   end if
end makeProbeStack

-- The settings of one build (see the header)
private function buildSettings pName
   local tSettings, tArch
   put revSBGetSettings(probeName(), true) into tSettings
   put true into tSettings["android"]
   put probeName() into tSettings["name"]
   put kIdentifier into tSettings["android,identifier"]
   put "Android Probe" into tSettings["android,label"]
   -- the engine the probe is built with: OXT-Beyond's own (android_check.py
   -- ide --android-engine beyond), or 9.6.3's as a stack that names none
   if $OXT_ANDROID_ENGINE is not empty then
      put $OXT_ANDROID_ENGINE into tSettings["android,engine"]
   end if
   repeat for each item tArch in "armv7,arm64,x86,x86_64"
      delete variable tSettings["android," & tArch]
   end repeat
   -- the edge probe is drawn edge to edge, and has an adaptive icon that
   -- is a themed one (see kEdgeWait)
   if probeName() is "AndroidEdgeProbe" then
      put true into tSettings["android,edge to edge"]
      set the itemDelimiter to slash
      put base64Decode(kProbePicture) into url ("binfile:" & item 1 to -2 of $OXT_ANDROID_STACK & slash & kProbeIconForeground)
      put base64Decode(kProbePicture) into url ("binfile:" & item 1 to -2 of $OXT_ANDROID_STACK & slash & kProbeIconMonochrome)
      set the itemDelimiter to comma
      put kProbeIconForeground into tSettings["android,adaptive icon"]
      put kProbeIconMonochrome into tSettings["android,themed icon"]
      put kRunColor into tSettings["android,adaptive icon background"]
   end if
   -- the Java layer's probe asks to post notifications, and declares
   -- WRITE_EXTERNAL_STORAGE (see the header)
   if probeName() is "AndroidJavaProbe" then
      put true into tSettings["android,application permissions"]["POST_NOTIFICATIONS"]
      put true into tSettings["android,application permissions"]["WRITE_EXTERNAL_STORAGE"]
      -- its copy file, beside the stack (a path relative to its folder)
      set the itemDelimiter to slash
      put kProbeCopy into url ("binfile:" & item 1 to -2 of $OXT_ANDROID_STACK & slash & kProbeCopyName)
      set the itemDelimiter to comma
      put kProbeCopyName into tSettings["files"]
   end if
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
      case "bundle"
         put "Sign with my key" into tSettings["android,signing"]
         put $OXT_ANDROID_KEYSTORE into tSettings["android,key"]
         put true into tSettings["android,arm64"]
         put true into tSettings["android,x86_64"]
         put true into tSettings["android,app bundle"]
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
      put "debug,release,unsigned,legacy,bundle" into tBuilds
   end if
   repeat for each item tName in tBuilds
      put $OXT_ANDROID_OUTPUT & slash & tName & ".apk" into tApk
      if there is a file tApk then
         delete file tApk
      end if
      if there is a file ($OXT_ANDROID_OUTPUT & slash & tName & ".aab") then
         delete file ($OXT_ANDROID_OUTPUT & slash & tName & ".aab")
      end if
      put empty into tError
      put empty into sAsked
      revStandaloneResetWarnings
      if tName is "release" or tName is "bundle" then
         send "androidAnswerAsk 0" to me in 500 milliseconds
         put the result into sAskMessage
      end if
      try
         dispatch "revSaveAsMobileStandalone" to stack "revSaveAsAndroidStandalone" with \
               probeName(), tApk, "Build", buildSettings(tName)
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
   -- the bundletool a bundle build downloaded (a released builder has none)
   if "bundle" is among the items of tBuilds then
      put empty into tError
      try
         put builderCall("androidBundletoolCacheFile") into tName
      catch tError
         put empty into tName
      end try
      if tName is not empty and there is a file tName then
         androidLog "INFO bundletool" && tName
      end if
   end if

   put $OXT_ANDROID_DEVICE into tSerial
   if tSerial is not empty then
      -- Test reads the stack's own settings: those of the debug build
      revSBSetSettings probeName(), buildSettings("debug")
      save stack probeName()
      put empty into tError
      try
         dispatch "deployDo" to stack "revDeployLibraryAndroid" with probeName(), "Android" && tSerial
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
