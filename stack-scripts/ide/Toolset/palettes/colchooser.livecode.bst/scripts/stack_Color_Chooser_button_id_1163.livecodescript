script "stack_Color_Chooser_button_id_1163"
-- Stack file: ide/Toolset/palettes/colchooser.livecode
-- Object: stack "Color Chooser" > card (id 1001) > group "Name" (id 1190) > button "Clear" (id 1163)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on mouseUp
  setcolor empty
  put empty into field "Color Name"
end mouseUp
