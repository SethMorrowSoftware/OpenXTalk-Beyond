script "stack_Color_Chooser_group_id_1192"
-- Stack file: ide/Toolset/palettes/colchooser.livecode
-- Object: stack "Color Chooser" > card (id 1001) > group "HSV" (id 1192)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

on scrollbarDrag
  setcolor HSVtoRGB(the thumbPos of scrollbar "H", the thumbPos of scrollbar "S", the thumbPos of scrollbar "V")
end scrollbarDrag

function RGBtoHSV r, g, b
  local maxv, minv, diff, s, rc, gc, bc, h
  set the numberFormat to "0.###############"
  put r / 255 into r
  put g / 255 into g
  put b / 255 into b
  put max(r,g,b) into maxv
  put min(r,g,b) into minv
  put maxv - minv into diff
  if maxv <> 0 and diff <> 0 then
    put diff / maxv into s
    put (maxv - r) / diff into rc
    put (maxv - g) / diff into gc
    put (maxv - b) / diff into bc
    if r = maxv then put bc - gc into h
    else if g = maxv then put 2 + rc - bc into h
  else if b = maxv then put 4 + gc - rc into h
  multiply h by 60
  if h < 0 then
    add 360 to h
  end if
else
  put 0 into s
  put 0 into h
end if
return round(h),round(s * 100),round(maxv * 100)
end RGBtoHSV

function HSVtoRGB h, s, v
  local rgb, i, f, p, q, t
  set the numberFormat to "0.###############"
  divide s by 100
  divide v by 100
  if s is 0 then put v,v,v into rgb
  else
    divide h by 60
    put trunc(h) into i
    put h - i into f
    put v * (1 - s) into p
    put v * (1 - s * f) into q
    put v * (1 - s * (1- f)) into t
    if i is 0 then put v,t,p into rgb
    if i is 1 then put q,v,p into rgb
    if i is 2 then put p,v,t into rgb
    if i is 3 then put p,q,v into rgb
    if i is 4 then put t,p,v into rgb
    if i is 5 then put v,p,q into rgb
  end if
  return round(item 1 of rgb * 255), round(item 2 of rgb * 255), round(item 3 of rgb * 255)
end HSVtoRGB

on resetcontrols
  local pcolor
  put getcolor(false) into pcolor
  if the number of items in pcolor is not 3
  then put "0,0,0" into pcolor
  put RGBtoHSV(item 1 of pcolor, item 2 of pcolor, item 3 of pcolor) into pcolor
  lock messages
  set the thumbPos of scrollbar "H" to item 1 of pcolor
  set the thumbPos of scrollbar "S" to item 2 of pcolor
  set the thumbPos of scrollbar "V" to item 3 of pcolor
  unlock messages
end resetcontrols
