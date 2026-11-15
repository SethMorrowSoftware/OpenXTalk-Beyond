script "stack_Color_Chooser_card_id_1001"
-- Stack file: ide/Toolset/palettes/revcolorchooser.rev
-- Object: stack "Color Chooser" > card (id 1001)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on setcolor which
  local cindex, setstring
  put the short name of button (the hilitedButton of group "Index")\
      of group "Index" into cindex
  put "color" after cindex
  set the backColor of button cindex to which
  if cindex is "PenColor"
  then set the penColor to which
  else if cindex is "BrushColor"
  then set the brushColor to which
  else if the selectedObject is not empty then
    repeat for each line l in the selectedObjects
      put format("set the %s of %s to \"%s\"\n", cindex, l, which) after setstring
    end repeat
    do setstring
  end if
end setcolor

function getcolor nameOK
  local cindex
  put the short name of button (the hilitedButton of group "Index")\
      of group "Index" into cindex
  put "color" after cindex
  if nameOK or the number of items in the backColor of button cindex is 3
  then return the backColor of button cindex
  else
    get the effective backPixel of button cindex
    set the backColor of button cindex to empty
    set the backPixel of button cindex to it
    return the effective backColor of button cindex
  end if
end getcolor
