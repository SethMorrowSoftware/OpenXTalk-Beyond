script "BuildAndroidStackPlayer"
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

-- Builds the Android Stack Player (tools/android-player) with the IDE's
-- own Android builder. tools/android-player/build_android_player.py starts the
-- IDE with this script named on its command line (as
-- tools/web-player/build-player.livecodescript is started); once the IDE
-- has started, it
--
--   1. makes the stack "OXT Stack Player": the script of
--      stack-player.livecodescript, the controls its playerMake makes, and
--      the back script of stack-player-back.livecodescript;
--   2. saves it and builds it with revSaveAsMobileStandalone, with
--      OXT-Beyond's own Android engine, every script library and external
--      an Android standalone can have, and every widget and library
--      extension installed for Android, so that a stack the player opens
--      finds what its own app would carry; the app asks for the Internet
--      permission and no other, and is offered for the documents a stack
--      file is to Android (android,documentTypes);
--   3. with OXT_APLAYER_SAMPLES, saves there the stacks that
--      build_android_player.py's device check opens in the player.
--
-- Environment:
--    OXT_APLAYER_SOURCE   the folder of the player's scripts (this one)
--    OXT_APLAYER_WORK     a folder for the player's stack file
--    OXT_APLAYER_APK      the package to build
--    OXT_APLAYER_SDK      the Android SDK
--    OXT_APLAYER_JDK      the JDK
--    OXT_APLAYER_KEYSTORE optional: a keystore to sign with ("Sign with
--                         my key"; the builder asks for its alias and
--                         passwords, answered from OXT_APLAYER_ALIAS and
--                         OXT_APLAYER_PASSWORD); without it the package
--                         is signed for development only
--    OXT_APLAYER_VERSION  optional: the app's version name
--    OXT_APLAYER_SAMPLES  optional: the folder for the sample stacks
--    OXT_APLAYER_LOG      the file for the lines below
--
-- It writes "INFO <name> <value>" lines, then "BUILD OK <apk>" or
-- "BUILD FAILED <reason>" and "DONE" to the log, and leaves the IDE
-- running: build_android_player.py ends it.

constant kPlayerName = "OXT Stack Player"
constant kIdentifier = "org.openxtalk.stackplayer"
-- The kinds of document the app is offered for. Android knows no kind
-- for a stack file's name, so file managers and mail apps hand one over
-- as application/octet-stream (some as application/x-livecode-stack,
-- from the name the desktop gives it)
constant kDocumentTypes = "application/octet-stream,application/x-livecode-stack,application/x-oxtstack"

local sStarted, sAskMessage

on openStack
   if sStarted is not true and the environment is "development" then
      put true into sStarted
      -- out of the way of the IDE's windows
      hide me
      send "playerWhenStarted 0" to me in 1 second
   end if
   pass openStack
end openStack

-- Waits until the IDE has finished starting (home.livecodescript sets the
-- cREVLaunching of stack "Home" while it opens its palettes), then a
-- little more for their deferred messages
on playerWhenStarted pTries
   local tLaunching
   put false into tLaunching
   if there is a stack "Home" then
      put the cREVLaunching of stack "Home" into tLaunching
   end if
   if tLaunching is true and pTries < 240 then
      send "playerWhenStarted" && pTries + 1 to me in 500 milliseconds
   else
      send "playerBuild" to me in 2 seconds
   end if
end playerWhenStarted

private command buildLog pLine
   replace return with " | " in pLine
   put textEncode(pLine & lf, "UTF-8") after url ("binfile:" & $OXT_APLAYER_LOG)
end buildLog

private function fileText pPath
   local tData
   put url ("binfile:" & pPath) into tData
   if the result is not empty then
      throw "cannot read" && pPath & ":" && the result
   end if
   return textDecode(tData, "UTF-8")
end fileText

private function scriptText pName
   local tScript
   put fileText($OXT_APLAYER_SOURCE & slash & pName) into tScript
   if line 1 of tScript begins with "script " then
      delete line 1 of tScript
   end if
   return tScript
end scriptText

on playerBuild
   local tSettings, tError, tApk, tStackFile
   buildLog "INFO version" && the version && the buildNumber
   buildLog "INFO platform" && the platform && the processor
   buildCatchErrors
   put $OXT_APLAYER_APK into tApk
   try
      -- what Preferences > Mobile Support does with the folders chosen there
      set the cMobileSupport["android.sdk"] of stack "revPreferences" to $OXT_APLAYER_SDK
      set the cMobileSupport["android.jdk"] of stack "revPreferences" to $OXT_APLAYER_JDK
      dispatch "revIDEDeployAndroidInitialize" to stack "revDeployLibrary"

      if $OXT_APLAYER_SAMPLES is not empty then
         makeSamples $OXT_APLAYER_SAMPLES
      end if
      makePlayer
      put $OXT_APLAYER_WORK & "/OXT Stack Player.livecode" into tStackFile
      if there is not a folder $OXT_APLAYER_WORK then
         create folder $OXT_APLAYER_WORK
      end if
      save stack kPlayerName as tStackFile
      if the result is not empty then
         throw "cannot save the player's stack as" && tStackFile & ":" && the result
      end if
      put playerSettings(revSBGetSettings(kPlayerName, true)) into tSettings
      buildLog "INFO scriptLibraries" && tSettings["scriptLibraries"]
      buildLog "INFO databaseDrivers" && tSettings["databaseDrivers"]
      buildLog "INFO extensions" && tSettings["extensions"]
      if there is a file tApk then
         delete file tApk
      end if
      revStandaloneResetWarnings
      if $OXT_APLAYER_KEYSTORE is not empty then
         send "playerAnswerAsk 0" to me in 500 milliseconds
         put the result into sAskMessage
      end if
      dispatch "revSaveAsMobileStandalone" to stack "revSaveAsAndroidStandalone" with \
            kPlayerName, tApk, "Build", tSettings
      buildLog "INFO warnings" && revStandaloneGetWarnings()
      if there is not a file tApk then
         throw "the builder made no" && tApk
      end if
   catch tError
   end try
   if sAskMessage is not empty then
      cancel sAskMessage
      put empty into sAskMessage
   end if
   if "revStandaloneProgress" is among the lines of the openStacks then
      close stack "revStandaloneProgress"
   end if
   if tError is empty then
      buildLog "BUILD OK" && tApk
   else
      buildLog "BUILD FAILED" && tError
   end if
   buildLog "DONE"
end playerBuild

-- Answers the builder's ask dialogs (the keystore's alias, then its two
-- passwords) as a user types them, and presses OK
on playerAnswerAsk pTries
   local tPrompt, tAnswer
   put empty into sAskMessage
   if there is a stack "Ask Dialog" and the mode of stack "Ask Dialog" is not 0 then
      put the text of field 1 of card 1 of stack "Ask Dialog" into tPrompt
      if tPrompt contains "alias" then
         put $OXT_APLAYER_ALIAS into tAnswer
      else
         put $OXT_APLAYER_PASSWORD into tAnswer
      end if
      put tAnswer into field 2 of card 1 of stack "Ask Dialog"
      put tAnswer into field 3 of card 1 of stack "Ask Dialog"
      send "closeAccept" to card 1 of stack "Ask Dialog"
   end if
   if pTries < 600 then
      send "playerAnswerAsk" && pTries + 1 to me in 200 milliseconds
      put the result into sAskMessage
   end if
end playerAnswerAsk

-- The player's standalone settings: Android, and everything a stack it
-- opens might use
private function playerSettings pSettings
   local tInclusion, tExtensions, tArch, tAndroid
   put true into pSettings["android"]
   put kPlayerName into pSettings["name"]
   put kIdentifier into pSettings["android,identifier"]
   put kPlayerName into pSettings["android,label"]
   if $OXT_APLAYER_VERSION is not empty then
      put $OXT_APLAYER_VERSION into pSettings["android,version name"]
   end if
   -- OXT-Beyond's own engine (Runtime/Android/Beyond)
   put "beyond" into pSettings["android,engine"]
   repeat for each item tArch in "armv7,arm64,x86,x86_64"
      put true into pSettings["android," & tArch]
   end repeat
   if $OXT_APLAYER_KEYSTORE is not empty then
      put "Sign with my key" into pSettings["android,signing"]
      put $OXT_APLAYER_KEYSTORE into pSettings["android,key"]
   else
      put "Sign for development only" into pSettings["android,signing"]
   end if
   -- the Internet, and nothing else of the device: a stack from a
   -- stranger can ask for no more than the app has
   delete variable pSettings["android,application permissions"]
   put true into pSettings["android,application permissions"]["INTERNET"]
   put kDocumentTypes into pSettings["android,documentTypes"]
   put "select" into pSettings["inclusions"]
   -- the script libraries (revsblibrary's kScriptLibraries), then the
   -- titles of the externals an Android standalone can have
   put "Animation,DataGrid,Geometry,Internet,Printing,Table,XMLRPC,XML,Database,Revolution Zip,SSL & Encryption,PDF Printing" \
         into pSettings["scriptLibraries"]
   replace comma with return in pSettings["scriptLibraries"]
   put "SQLite" & return & "MySQL" into pSettings["databaseDrivers"]
   repeat for each word tArch in "revzip revxml dbsqlite dbmysql revpdfprinter revsecurity"
      put true into pSettings["android,include" && tArch]
   end repeat
   -- every widget and library extension that is installed for Android
   repeat for each element tInclusion in revSBAvailableInclusions()
      if tInclusion["type"] is not among the items of "widget,library" then
         next repeat
      end if
      if "Android" is not among the items of tInclusion["platforms"] then
         next repeat
      end if
      -- but none that asks for a permission of its own (the audio
      -- recorder's microphone): the player has the Internet and no more
      -- (its metadata, as revSBUpdateForDependencies reads it)
      put revIDEExtensionProperty(tInclusion["id"], "android") into tAndroid
      if tAndroid["permissions"] is not empty then
         buildLog "INFO left-out" && tInclusion["id"] && "asks for" && tAndroid["permissions"]
         next repeat
      end if
      put tInclusion["id"] & return after tExtensions
   end repeat
   delete the last char of tExtensions
   sort lines of tExtensions
   if "org.openxtalk.library.androiddocuments" is not among the lines of tExtensions then
      throw "the Android Documents library (org.openxtalk.library.androiddocuments) is not installed in this IDE: the player cannot take a file in without it"
   end if
   put tExtensions into pSettings["extensions"]
   return pSettings
end playerSettings

----------------------------------------------------------------
-- The player's stack
----------------------------------------------------------------

private command makePlayer
   if there is a stack kPlayerName then
      delete stack kPlayerName
   end if
   create invisible stack kPlayerName
   set the title of stack kPlayerName to kPlayerName
   set the rect of stack kPlayerName to 0,0,360,640
   -- the player's own card fills the screen, at the device's own size
   set the fullscreenMode of stack kPlayerName to empty
   set the script of stack kPlayerName to scriptText("stack-player.livecodescript")
   if the result is not empty then
      throw "stack-player.livecodescript does not compile:" && the result
   end if
   -- the texts of the engine's script errors, which a standalone does not
   -- have (playerErrorLine)
   set the cScriptErrors of stack kPlayerName to the scriptExecutionErrors
   dispatch "playerMake" to stack kPlayerName with scriptText("stack-player-back.livecodescript")
   if it is not "handled" then
      throw "the player's script has no playerMake"
   end if
   if the script of button "Player Back Script" of stack kPlayerName is empty then
      throw "stack-player-back.livecodescript does not compile"
   end if
end makePlayer

----------------------------------------------------------------
-- The sample stacks of the device check
----------------------------------------------------------------

-- "PlayerSample.oxtstack": 800 by 600 (wider than a phone held upright),
-- says in the device's log that its own openStack ran and what its
-- defaultFolder is, and on a tap what its card's size is. "PlayerError.livecode"
-- throws from its openCard.
private command makeSamples pFolder
   if there is not a folder pFolder then
      create folder pFolder
   end if
   makeSample pFolder, "Player Sample", "PlayerSample.oxtstack", \
         "on openStack" & return & \
         "   put " & quote & "OXT Stack Player sample: opened in " & quote & " & the defaultFolder" & return & \
         "   put " & quote & "OXT Stack Player sample: size " & quote & " & the width of this stack & comma & the height of this stack && the fullscreenMode of this stack" & return & \
         "end openStack" & return & \
         "on mouseUp" & return & \
         "   put " & quote & "OXT Stack Player sample: tapped at " & quote & " & the mouseLoc" & return & \
         "end mouseUp"
   makeSample pFolder, "Player Error", "PlayerError.livecode", \
         "on openCard" & return & \
         "   put " & quote & "OXT Stack Player sample: about to fail" & quote & return & \
         "   put 1 / 0 into tNothing" & return & \
         "end openCard"
end makeSamples

private command makeSample pFolder, pName, pFile, pScript
   if there is a stack pName then
      delete stack pName
   end if
   create invisible stack pName
   set the rect of stack pName to 0,0,800,600
   set the backgroundColor of stack pName to "31,158,90"
   set the script of stack pName to pScript
   set the defaultStack to pName
   create field "Label"
   set the rect of field "Label" to 40,40,760,120
   set the textSize of field "Label" to 36
   put pName into field "Label"
   -- a label: a field that takes the focus brings up Android's keyboard
   set the lockText of field "Label" to true
   set the traversalOn of field "Label" to false
   set the visible of stack pName to true
   save stack pName as (pFolder & slash & pFile)
   if the result is not empty then
      throw "cannot save" && pFile & ":" && the result
   end if
   delete stack pName
   buildLog "INFO sample" && pFolder & slash & pFile
end makeSample

-- Errors in the IDE's scripts go to the log, not to the IDE's error dialog
-- or the debugger (revTestEnvironment, as the IDE's test runner sets it)
private command buildCatchErrors
   local tError, tDefault
   try
      dispatch "revSetTestEnvironment" to stack "Home" with true
      put the defaultStack into tDefault
      set the defaultStack to the short name of me
      lock messages
      create invisible button "oxt_aplayer_errors"
      set the script of it to "on errorDialog pError" & return & \
            "   dispatch " & quote & "playerBuildError" & quote & " to stack " & quote & the short name of me & quote & " with pError" & return & \
            "end errorDialog"
      insert the script of it into front
      unlock messages
      set the defaultStack to tDefault
   catch tError
      unlock messages
      buildLog "INFO catching errors:" && tError
   end try
end buildCatchErrors

on playerBuildError pError
   buildLog "ERROR" && pError
end playerBuildError
