script "community.openxtalk.plugin.oxtlite"
/*
* OXT Lite Custom Functions
* No copyright. This is free. There's only one stipulation*
* Feb 2024
* version 0.0.1
*
* This code is intended to provide extra functions to OpenXTalk / OpenXTalk Lite.
* This should be considered free to use by anyone, however there is one stipulation / condition:
* This code should in no part be used in any LiveCode product, or fork bearing the LiveCode product name. This stipulation cannot be modified or altered, and this notice MUST go with this plugin unaltered.
*/

local  sMessageID,  sGridSystem, sThisCard, sControls, sLabels
constant kGuideLineColor = "255,0,255", kGuideLabelColor = "56,56,255", kGuideLineCardColor = "255,128,0", kGuideLabelCardColor = "0,128,0"
local tEditingNow
local tFileNames

on extensionInitialize
   if the target is not me or the long id  of me is among the lines of the backscripts then pass extensionInitialize
   
   insert the script of me into back
   set the _ideoverride of me to true
   
   revIDESubscribe "ideToolChanged"
   revIDESubscribe "ideSelectedObjectChanged"
   revIDESubscribe "ideOpenStack"
   revIDESubscribe "ideResumeStack"
   
   put empty into sMessageID
end extensionInitialize


on extensionFinalize
   if the target is not me then pass extensionFinalize
   revIDEUnsubscribeAll the long id of me
   remove the script of me from back
end extensionFinalize


on closeCard
   -- do something when card closes
   pass closeCard
end closeCard

on preOpenCard
   -- do something on preopencard
   pass preOpenCard
end preOpenCard

on ideToolChanged
   -- tool has been changed
   pass ideToolChanged
end ideToolChanged


on ideSelectedObjectChanged
   -- selected object has been changed
   if there is a stack "Properties" then
      send ideNewSelectedObj to stack "Properties"
   end if
end ideSelectedObjectChanged


on rawKeyDown pKeyCode
   -- a certain raw key pressed
   --answer pKeyCode
   pass rawKeyDown
end rawKeyDown


on rawKeyUp pKeyCode
   -- a certain raw key released
   pass rawKeyUp
end rawKeyUp

on ideResumeStack
   set the tResumedStack of this stack to true
   pass ideResumeStack
end ideResumeStack
   
   
   function OSVersion withplat
   -- return the correct system version
   put "" into tShellCmd
   set hideConsoleWindows to true
   if the platform contains "linux" then put "lsb_release -r |cut -f2" into tShellCmd
   if the platform contains "mac" then put "sw_vers -productVersion" into tShellCmd
   if the platform contains "win" then put "systeminfo | findstr /C:" & QUOTE & "OS Version" & QUOTE into tShellCmd
   put shell(tShellCmd) into tSystemVersionNumber
   -- tidy up for Windows
   if the platform contains "win" then 
      put line 1 of tSystemVersionNumber into tSystemVersionNumber
      replace " N/A " with "-" in tSystemVersionNumber
      replace ":" with return in tSystemVersionNumber
      if the number of lines in tSystemVersionNumber >1 then put line 2 of tSystemVersionNumber into tSystemVersionNumber
      replace "Build " with return in tSystemVersionNumber
      if the number of lines in tSystemVersionNumber >1 then put line 1 of tSystemVersionNumber into tSystemVersionNumber
      replace " " with "" in tSystemVersionNumber
      replace "-" with " " in tSystemVersionNumber
   end if
   if withplat is "platform" then
      put the platform & " " & tSystemVersionNumber into tSystemVersion
      -- the above would return "MacOS 14" for example.
      return line 1 of tSystemVersion
   else
      return line 1 of tSystemVersionNumber
   end if
end OSVersion

-----------------------------------------------------------------------------------------------------------
---------------------- the following is all about external script editing ---------------------------------
-----------------------------------------------------------------------------------------------------------
on ideCheckExternalEditors
   set cursor to watch
   if the platform contains "lin" then put " > /dev/null 2>/dev/null &" into tNoWaitShellCommand
   if there is a fld "pendingEdits" of cd 1 of this stack then
      put fld "pendingEdits" of cd 1 of this stack into tScriptsBeingEdited
      put the cEditingNow of fld "pendingEdits" of cd 1 of this stack into tEditingNow
      put the cFileNames of fld "pendingEdits" of cd 1 of this stack into tFileNames
      put the cExternalEditorCommand of stack "revPreferences" into tExternalEditorCommand
      if tFileNames contains tEditingNow then
         -- already being edited
         put the cFolderpath of fld "pendingEdits" of cd 1 of this stack into tFolderPath
         put tFolderPath & slash & tEditingNow into tFilename
         set the hideconsolewindows to true
         if tExternalEditorCommand is "" then
            -- need to choose an editor
            Answer "You need to choose an external script editor." with "Okay"
            open stack "revPreferencesGUI"
            go cd "Script Editor" of stack "revPreferencesGUI"
         else
            -- chosen an editor
            -- mac allowance
            if the platform contains "mac" then
               if the last char of tExternalEditorCommand is "/" then delete last char of tExternalEditorCommand
               put "open '" & tExternalEditorCommand & "'" into tExternalEditorCommand
            end if
            get shell (tExternalEditorCommand & " '" & tFilename & "'" & tNoWaitShellCommand)
            send hPrepScriptEditSetup to me in 1 millisecond
         end if
      else
         -- we need to update the list of things we are editing
         put the defaultfolder into tOldDefaultFolder
         put the cFolderpath of fld "pendingEdits" of cd 1 of this stack into tFolderPath
         if there is a folder tFolderPath then
            set the defaultfolder to tFolderPath
            put the detailed files into tFilesInHere
            put the itemdelimiter into tOldItemDelimiter
            set the itemdelimiter to ","
            filter lines of tFilesInHere without (slash & ".*") -- filter invisibles
            put 0 into tCount
            repeat the number of lines of tFilesInHere
               add 1 to tCount
               put item 1 of line tcount of tFilesInHere into line tcount of tFileNames
               put item 2 of line tcount of tFilesInHere into line tcount of tFilesInHere
            end repeat
            -- cFileSizes contains file sizes & cFileNames has a list of the files now
            set the cFileSizes of fld "pendingEdits" of cd 1 of this stack to tFilesInHere
            set the cFileNames of fld "pendingEdits" of cd 1 of this stack to tFileNames
            set the itemdelimiter to tOldItemDelimiter
            -- now we edit the current file
            put the cEditingNow of fld "pendingEdits" of cd 1 of this stack into tEditingNow
            put tFolderPath & slash & tEditingNow into tFilename
            set the hideconsolewindows to true
            if tExternalEditorCommand is "" then
               -- need to choose an editor
               Answer "You need to choose an external script editor." with "Okay"
               open stack "revPreferencesGUI"
               go cd "Script Editor" of stack "revPreferencesGUI"
               exit ideCheckExternalEditors
            else
               -- chosen an editor
               -- mac allowance
               if the platform contains "mac" then
                  if the last char of tExternalEditorCommand is "/" then delete last char of tExternalEditorCommand
                  put "open '" & tExternalEditorCommand & "'" into tExternalEditorCommand
               end if
               get shell (tExternalEditorCommand & " '" & tFilename & "'" & tNoWaitShellCommand)
               put tFilename into tfile
               send hPrepScriptEditSetup to me in 1 millisecond
            end if
         end if
         set the defaultfolder to tOldDefaultFolder
         -- folder does not exist
      end if
   end if
end ideCheckExternalEditors

on hPrepScriptEditSetup
   -- now we check for updating of the file
   if not (the pendingmessages contains "hEditorCheckSizes") then
      -- check sizes
      put the cFileSizes of fld "pendingEdits" of cd 1 of this stack into tFileSizes
      put lineOffset(tEditingNow,tFileNames) into tLine
      put the itemdelimiter into tOldDelims
      set the itemdelimiter to ","
      put item 2 of line tLine of tFileSizes into tOldFileSize
      set the cOldSize of fld "pendingEdits" of cd 1 of this stack to tOldFileSize
      set the itemdelimiter to tOldDelims
      set the tResumedStack of this stack to false
      send hEditorCheckSizes to me in 1 second
   end if
end hPrepScriptEditSetup

on hEditorCheckSizes
   put the cEditingNow of fld "pendingEdits" of cd 1 of this stack into tFile
   put (the cFolderpath of fld "pendingEdits" of cd 1 of this stack) & slash & tFile into tAbsFilename
   if there is a file (tAbsFilename) then
      -- file exists, check the size
      put the defaultfolder into tOldDefaultFolder
      put the itemdelimiter into tOldItemDelimiter
      set the defaultfolder to (the cFolderpath of fld "pendingEdits" of cd 1 of this stack)
      set the itemdelimiter to ","
      put the detailed files into tFileSizesList
      put lineOffset(tFile,tFileSizesList) into tLineOffset
      put item 2 of line tLineOffset of tFileSizesList into tNewSize
      set the cNewSize of fld "pendingEdits" of cd 1 of this stack to tNewSize
      set the itemdelimiter to tOldItemDelimiter
      set the defaultfolder to tOldDefaultFolder
      send hEditorCheckLoop to me in 1 second
      --
   else
      -- file doesn't exist
   end if
end hEditorCheckSizes


on hEditorCheckLoop
   put the cNewSize of fld "pendingEdits" of cd 1 of this stack into tNewSize
   put the cOldSize of fld "pendingEdits" of cd 1 of this stack into tOldSize
   put the cEditingNow of fld "pendingEdits" of cd 1 of this stack into tFile   
   put the cEditTarget of fld "pendingEdits" of cd 1 of this stack into tEdTarget
   put (the cFolderpath of fld "pendingEdits" of cd 1 of this stack) & slash & tFile into tAbsFilename
   
   
   if not (tOldSize is tNewSize) then
      -- file was modified
      ---------------------- now we make the script change ----------------
      if the tResumedStack of this stack is true then
         Answer "<b>Are you finished editing the script of:</b><br>" & tEdTarget & "?" with "Done" or "Not yet"
         if it is "done" then
            set the tResumedStack of this stack to ""
            -- set object script
            open file tAbsFilename
            read from file tAbsFilename until EOF
            close file tAbsFilename
            put it into tData
            put the cEditTarget of fld "pendingEdits" of cd 1 of this stack into tEditTarget
            if tData is empty then
               -- error reading script
               Answer "error reading script"
            else
               try
                  set the script of (tEditTarget) to tData
                  delete file (tAbsFilename)
               catch e
               end try
            end if
            set the cOldSize of fld "pendingEdits" of cd 1 of this stack to tNewSize -- update size
            -- end set object script
         end if
         if it is "not yet" then
            set the tResumedStack of this stack to false
         end if
      end if
      ---------------------- end commit script change ---------------------
   else
      -- file is the same size.
      -- assume no changes (I may need to revise this assumption)
   end if
   
   -- put the ticks & ":" & tAbsFilename -- debug
   if there is a file (tAbsFilename) then
      if not (the tResumedStack of this stack is "") then
         if not (the pendingmessages contains "hEditorCheckSizes") then send hEditorCheckSizes to me in 1 second
      end if
   end if
end hEditorCheckLoop
