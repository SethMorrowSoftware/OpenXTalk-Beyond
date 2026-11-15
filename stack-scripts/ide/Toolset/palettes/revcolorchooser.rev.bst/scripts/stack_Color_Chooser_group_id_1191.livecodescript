script "stack_Color_Chooser_group_id_1191"
-- Stack file: ide/Toolset/palettes/revcolorchooser.rev
-- Object: stack "Color Chooser" > card (id 1001) > group "RGB" (id 1191)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on scrollbarDrag
  local newcolor
  put the thumbPos of scrollbar "R", the thumbPos of scrollbar "G", the thumbPos of scrollbar "B" into newcolor
  setcolor newcolor
end scrollbarDrag

on resetcontrols
  local pcolor
  put getcolor(false) into pcolor
  if the number of items in pcolor is not 3
  then put "0,0,0" into pcolor
  lock messages
  set the thumbPos of scrollbar "R" to item 1 of pcolor
  set the thumbPos of scrollbar "G" to item 2 of pcolor
  set the thumbPos of scrollbar "B" to item 3 of pcolor
  unlock messages
end resetcontrols
