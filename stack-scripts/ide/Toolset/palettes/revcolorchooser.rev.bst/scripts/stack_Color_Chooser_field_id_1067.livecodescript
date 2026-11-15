script "stack_Color_Chooser_field_id_1067"
-- Stack file: ide/Toolset/palettes/revcolorchooser.rev
-- Object: stack "Color Chooser" > card (id 1001) > group "Name" (id 1190) > field "Color Names" (id 1067)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseUp
  get the clickText
  setcolor it
  put it into field "Color Name"
end mouseUp
