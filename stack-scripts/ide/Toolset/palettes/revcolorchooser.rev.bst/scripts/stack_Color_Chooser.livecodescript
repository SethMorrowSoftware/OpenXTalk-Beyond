script "stack_Color_Chooser"
-- Stack file: ide/Toolset/palettes/revcolorchooser.rev
-- Object: stack "Color Chooser"
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

local oldhilite

on refresh
  local s1, s2, hb, c
  put the number of button "Foreground" into s1
  put the number of button "Foregroundcolor" into s2
  set the backcolor of button "Pencolor" to the penColor
  set the backcolor of button "Brushcolor" to the brushColor
  put the hilitedButtonName of group "Index" into hb
  if hb is not "answer" then
    if the selectedObject is empty then
      set the label button "ink" to " "
      put empty into c
      if hb is not "Pen" and hb is not "Brush"
      then set the hilitedButtonName of group "Index" to "Pen"
      repeat with i = s1 to s1 + 7
        disable button i
      end repeat
    else
      set the label button "ink" to the ink of the selectedObject
      put the colors of the selobj into c
      repeat with i = s1 to s1 + 7
        enable button i
        set the label of button i to empty
      end repeat
      if hb is "Pen" or hb is "Brush"
      then set the hilitedButtonName of group "Index" to "Foreground"
      if word 1 of the name of the selobj is "graphic" then
        set the label of button s1 to "Line"
        set the label of button (s1 + 1) to "Fill"
        set the label of button (s1 + 2) to "Marker"
        set the label of button (s1 + 3) to "Marker Fill"
      end if
    end if
    repeat with i = s2 to s2 + 8
      set the backcolor of button i to line i - s2 + 1 of c
    end repeat
  end if
  send "resetcontrols" to group the selectedText of button "Chooser Type"
end refresh

on preOpenStack
   if the lookAndFeel is "Macintosh" or the lookAndFeel is "Appearance Manager"
   then set the textsize of button 1 to 10
   else set the textsize of button 1 to empty
   set the itemDelimiter to numToChar(0)
   if item 1 of the dialogData is "answer color" then
      set the width of me to 224
      set the height of me to 288
      set the width of button 1 to 212
      put the hilitedButtonName of group "Index" into oldhilite
      set the hilitedButtonName of group "Index" to "answer"
      if item 3 of the dialogData is empty
      then set the backcolor of button "answerColor" to the penColor
      else set the backcolor of button "answerColor" to item 3 of the dialogData
      hide group "Patches"
      hide group "Index"
      set the dialogData to empty
   else
      set the width of me to 456
      set the height of me to 242
      set the width of button 1 to 208
      show group "Patches"
      show group "Index"
   end if
   refresh
end preOpenStack

on closeStack
  if oldhilite is not empty then set the hilitedButtonName of group "Index" to oldhilite
end closeStack
