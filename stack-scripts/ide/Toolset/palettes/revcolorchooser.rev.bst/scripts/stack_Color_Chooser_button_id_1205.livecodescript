script "stack_Color_Chooser_button_id_1205"
-- Stack file: ide/Toolset/palettes/revcolorchooser.rev
-- Object: stack "Color Chooser" > card (id 1001) > button "OK" (id 1205)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseUp
  if not the visible of group "Patches" then # answer color mode
    set the dialogData to the backColor of button "answerColor"
    close this stack
  end if
end mouseUp
