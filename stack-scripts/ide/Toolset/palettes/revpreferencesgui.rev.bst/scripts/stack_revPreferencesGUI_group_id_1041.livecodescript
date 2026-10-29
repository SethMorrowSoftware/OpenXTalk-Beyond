script "stack_revPreferencesGUI_group_id_1041"
-- Stack file: ide/Toolset/palettes/revpreferencesgui.rev
-- Object: stack "revPreferencesGUI" > card "Files & Memory" (id 1007) > group "Files & Memory" (id 1041)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

# OK-2007-12-12
# Parameters
#   <none>
# Description
#   Prompts the user to choose a customization path, and sets the cCustomizationPath of the preferences stack to the chosen folder.
#   If the user cancels the folder choose prompt or doesn't select a valid folder, nothing is done.
command chooseCustomizationPath
  local tPath
  answer folder "Please choose the user additions folder (extensions, externals, plugins and more)"
  put it into tPath
  if tPath is empty then
    exit chooseCustomizationPath
  end if
  
  local tChanged
  put false into tChanged
  if tPath <> the cCustomizationPath of stack "revPreferences" then
    put true into tChanged
  end if
  
  set the cCustomizationPath of stack "revPreferences" to tPath
  put tPath into field "Customization Path" of me
  
  if tChanged then
    answer warning "OXT-Beyond must be restarted to complete this change." with "Later" or "Quit"
    if it is "Quit" then
      quit
    end if
  end if
end chooseCustomizationPath

# OK-2007-12-12
# Parameters
#   <none>
# Description
#   Updates the customization path field to reflect the current setting in the preferences.
command updateCustomizationPath
  set the text of field "Customization Path" of me to revEnvironmentCustomizationPath()
end updateCustomizationPath

# OK-2007-12-12
on openBackground
  updateCustomizationPath
  pass openBackground
end openBackground







