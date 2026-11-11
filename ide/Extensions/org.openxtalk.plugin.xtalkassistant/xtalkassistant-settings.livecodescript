script "org.openxtalk.plugin.xtalkassistant-settings"
-- OXT-Beyond: the behavior of the xTalk Assistant's Settings dialog (the
-- stack "revXTalkAssistantSettings", which the plugin's main stack builds
-- each time it is opened, from More > Settings...). It hands every click
-- to the main stack, org.openxtalk.plugin.xtalkassistant, which fills the
-- dialog and keeps what it says. Here "me" is the dialog.
--
-- The key is typed or pasted into an ordinary field. The engine's "ask
-- password" dialog keeps only the keys typed one by one (it stores each in
-- a hidden field as its keyDown comes), so a key pasted into it, which is
-- how API keys are entered, came back empty: in 0.2.5-rc.3 the assistant
-- went on saying there was no key.

constant kMain = "org.openxtalk.plugin.xtalkassistant"

-- The caret goes in the field the main stack named (the key's, when it
-- asks for one)
on openStack
   if the cFocus of me is not empty and there is a field (the cFocus of me) of me then
      focus on field (the cFocus of me) of me
   end if
   pass openStack
end openStack

on mouseUp pButton
   if pButton is not 1 then
      pass mouseUp
   end if
   switch the short name of the target
      case "Save"
         dispatch "xtaSettingsSave" to stack kMain
         break
      case "Cancel"
         close me
         break
      case "Get Models"
         dispatch "xtaSettingsGetModels" to stack kMain
         break
      case "Forget Key"
         dispatch "xtaSettingsForgetKey" to stack kMain
         break
      -- A switch the others depend on: changing stacks needs the tools,
      -- and the short guide sends none
      case "Tools"
      case "Short Guide"
         dispatch "xtaSettingsSwitches" to stack kMain
         pass mouseUp
      default
         pass mouseUp
   end switch
end mouseUp

on menuPick pItem
   if the short name of the target is "Provider" then
      dispatch "xtaSettingsProvider" to stack kMain with pItem
   else if the short name of the target is "Local" then
      dispatch "xtaSettingsLocal" to stack kMain with pItem
   else if the short name of the target is "Services" then
      dispatch "xtaSettingsService" to stack kMain with pItem
   else
      pass menuPick
   end if
end menuPick

-- A key pasted with a line break after it (as copying a line gives) would
-- scroll the field out of sight; the line breaks go at once
on textChanged
   local tText
   if the short name of the target is "Key" then
      put the text of the target into tText
      if tText contains return or tText contains numToChar(13) then
         replace return with empty in tText
         replace numToChar(13) with empty in tText
         lock messages
         set the text of the target to tText
         unlock messages
         select after text of the target
      end if
   end if
   pass textChanged
end textChanged

-- Return in a one-line field saves, as the default button would
on returnInField
   if the short name of the target is among the items of "Key,Base URL,Context Length,Max Tokens,Fix Rounds,Timeout" then
      dispatch "xtaSettingsSave" to stack kMain
   else
      pass returnInField
   end if
end returnInField

on enterInField
   returnInField
end enterInField

on escapeKey
   close me
end escapeKey
