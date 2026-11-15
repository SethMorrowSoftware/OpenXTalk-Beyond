script "stack_Color_Chooser_button_id_1202"
-- Stack file: ide/Toolset/palettes/revcolorchooser.rev
-- Object: stack "Color Chooser" > card (id 1001) > button "ink" (id 1202)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on menuPick which
  if the selectedObject is empty then exit menuPick
  set the ink of the selectedObject to which
end menuPick
