script "stack_revPlugInEditor_button_id_1004"
-- Stack file: ide/Toolset/palettes/revplugineditor.rev
-- Object: stack "revPlugInEditor" > card (id 1002) > button "list" (id 1004)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on menuPick pWhich
  --lock screen
  if pWhich is empty or char 1 of pWhich is "(" then
    disableAll
  else
    enableAll
    put line (the menuHistory of me) of the cStacksList of me into tFilePath
    -- OXT-Beyond: with the settings kept in the user's preferences when
    -- the plugin's stack could not be saved; not over changes made since
    -- this window opened, which are saved when it closes
    if tFilePath is not among the lines of the changedStacksList of this stack then
      revIDEApplyPluginSettings tFilePath
    end if
    -- highlight in the list of messages:
    set the wholeMatches to true
    set the hilitedLines of fld "Message list" to empty
    repeat with x = 1 to the number of lines of field "Message List"
      if the cREVLoadInfo[(line x of field "Message List")] of stack tFilePath
      then set the hilitedLines of field "Message List" to \
          the hilitedLines of field "Message List",x
    end repeat
    -- display "As" setting:
    if the cREVloadInfo["mode"] of stack tFilepath is empty
    then set the hilitedButtonName of group "open as:" to "palette"
    else set the hilitedButtonName of group "open as:" to the cREVloadInfo["mode"] of stack tFilepath
    -- display "When" setting:
    if the cREVLoadInfo["load"] of stack tFilePath is empty then set the hilitedButtonName of group "load:" to "chosen"
    else set the hilitedButtonName of group "load:" to the cREVloadInfo["load"] of stack tFilepath
    if the hilitedButtonName of group "load:" is "chosen" then
      disable btn "Include in Plug-ins menu"
    else
      enable btn "Include in Plug-ins menu"
    end if
  end if
  unlock screen
end menuPick

on disableAll
  disable group "Open plugin:"
  disable field "Message List"
  set the hilitedLines of field "Message List" to empty
end disableAll

on enableAll
  enable group "Open plugin:"
  enable field "Message List"
end enableAll
