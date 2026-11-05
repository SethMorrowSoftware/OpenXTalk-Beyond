script "stack_Message_Box"
-- Stack file: ide/Toolset/palettes/message box/revmessagebox.8.rev
-- Object: stack "Message Box"
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on ideInitialiseMessageBox
   dispatch "setAsBehavior" to stack revIDEPaletteResourcePath("/behaviors/revmessageboxbehavior.livecodescript") with the long id of me
   set the behavior of card "Single Line" of me to the long id of stack revIDEMessageBoxBehavior("single line card")
   set the behavior of field "message" of card "Single Line" of me to the long id of stack revIDEMessageBoxBehavior("single line message")
   set the behavior of card "Multiple Lines" of me to the long id of stack revIDEMessageBoxBehavior("multiple lines card")
   set the behavior of field "script" of card "Multiple Lines" of me to the long id of stack revIDEMessageBoxBehavior("multiple lines message")
   set the behavior of group "fields" of card "Multiple Lines" of me to the long id of stack revIDEScriptEditorBehavior("common editor")
   revIDESubscribe "ideMsgChanged"
   -- revIDEOpenPalette "Message Box"
   ensureMBcorrect
end ideInitialiseMessageBox

on ensureMBcorrect
   put revIDEPaletteToStackName("Message Box") into tStackName
   if there is a stack tStackName then
      hide stack tStackName
      -- OXT-Beyond: opened invisible and marked to stay hidden, so that it
      -- does not show for a moment at every start, and left visible, as
      -- the palette command left it
      set the cOXTOpenHidden of stack tStackName to true
      go invisible stack tStackName as palette
      close stack tStackName
      set the cOXTOpenHidden of stack tStackName to empty
      set the visible of stack tStackName to true
      set the blendlevel of stack "message box" to 0
   end if
end ensureMBcorrect

on openstack
   send tWDTroubleshooting to this stack in 1 milliseconds
   pass openstack
end openstack

on tWDTroubleshooting
   -- tperry 16-1-24
   -- change the stack systemwindow and toplevel status, to what is selected in the preferences
   if the crevlaunching of stack "home" is false then set the blendlevel of stack "message box" to 0
   --if the cMsgboxdontTouch of stack "revPreferences" is true then exit tWDTroubleshooting
   
   lock screen
   if the cMsgboxSysWin of stack "revPreferences" is empty then set the cMsgboxSysWin of stack "revPreferences" to false
   set the systemwindow of this stack to the cMsgboxSysWin of stack "revPreferences"
   --
   if the cMsgboxTopLevel of stack "revPreferences" is empty then set the cMsgboxTopLevel of stack "revPreferences" to false
   set the toplevel of this stack to the cMsgboxTopLevel of stack "revPreferences"
   
   --
   unlock screen
   -- debug
   -- put "systemwindow: " & the systemwindow of stack "message box" & return & "toplevel: " & the toplevel of stack "message box"
   if the platform contains "win" then set the systemwindow of this stack to true
   
end tWDTroubleshooting

function tUpdMBTheme tCardID
   exit tUpdMBTheme -- don't use this now
   
   -- update theming for message box as you click through the various tabs (tperry 21-4-24)
   -- dark/light mode checking (tperry 21-4-24)
   if there is a group "objectList" of card id tCardID of this stack then
      if the cUseThemeDark of stack "revPreferences" is true then 
         set the ink of group "objectList" of card id tCardID of this stack to "srcCopy"
      else
         set the ink of group "objectList" of card id tCardID of this stack to "srcCopy"
      end if
      if the platform contains "linux" then
         -- we assess linux dark mode a bit differently
         put the effective Backgroundcolor of this stack into tColourDecision
         put the itemDelimiter into tOldDelim
         set the itemDelimiter to ","
         put item 1 of tColourDecision + item 2 of tColourDecision + item 3 of tColourDecision into tMaxColValues
         -- put tMaxColValues -- debug
         if tMaxColValues <234 then
            -- linux in dark mode
            set the ink of group "objectList" of card id tCardID of this stack to "blendSoftLight"
         else
            -- linux in light mode
            set the ink of group "objectList" of card id tCardID of this stack to "srcCopy"
         end if
      end  if
   else
      -- we don't do anything as theres no group "objectlist"
   end if
end tUpdMBTheme
