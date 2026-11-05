script "com.livecode.pi.color.behavior"
local sNamedColor
constant kColorEditorSize = 24
constant kClearGap = 4
constant kClearButton = "clearColour"

-- OXT-Beyond: a Clear button beside the swatch, as LiveCode 7's Inspector
-- had beside each colour of "Colours & Patterns". LiveCode 9's Inspector
-- dropped it, and an object's colour could be taken away only with the
-- swatch's right-click "Reset to default", which nobody finds (LittleNemo,
-- openxtalk.org p=25961 and p=25967; TerryL's "how to choose no color",
-- p=25957). Clear sets the property to empty, so the object has no colour
-- of its own and inherits its owner's, as "Reset to default" does for a
-- classic object's colour and the menu's "Clear" does for a widget's. It
-- is enabled only while the object has a colour of its own (or the
-- objects inspected have different colours). The button is made here, in
-- the editor's copy of the template, so the editor's stack file is
-- unchanged; the swatch is still control 1, and the swatch, its colour
-- dialog and its right-click menu work as before.
on editorInitialize
   local tWidth
   lock messages
   if there is not a button kClearButton of me then
      create button kClearButton in me
      -- whatever a script has made of the templateButton, the button is
      -- the theme's plain push button, as the Inspector's menus are
      set the script of it to empty
      set the behavior of it to empty
      set the style of it to "standard"
      set the showName of it to true
      set the label of it to "Clear"
      set the icon of it to 0
      set the hiliteIcon of it to 0
      set the armedIcon of it to 0
      set the disabledIcon of it to 0
      set the showIcon of it to false
      set the menuMode of it to empty
      set the autoHilite of it to true
      set the sharedHilite of it to true
      set the showBorder of it to true
      set the threeD of it to true
      set the opaque of it to true
      set the colors of it to empty
      set the patterns of it to empty
      set the textFont of it to empty
      set the textSize of it to empty
      set the textStyle of it to empty
      set the textAlign of it to "center"
      set the margins of it to 4
      set the traversalOn of it to false
      set the blendLevel of it to 0
      set the ink of it to "srcCopy"
      set the layerMode of it to "static"
      set the visible of it to true
      set the toolTip of it to "Clear: no color or pattern of its own, so it takes its owner's"
   end if
   put the formattedWidth of button kClearButton of me into tWidth
   if tWidth < 40 then put 40 into tWidth
   set the width of button kClearButton of me to tWidth
   set the height of button kClearButton of me to kColorEditorSize
   unlock messages
   set the editorMinWidth of me to kColorEditorSize + kClearGap + tWidth
   set the editorMaxWidth of me to kColorEditorSize + kClearGap + tWidth
end editorInitialize

-- Whether Clear has a colour to take away: the objects inspected have a
-- colour of their own (not one inherited, shown as the effective value),
-- or have different colours. Or a pattern: a colour's row may hold its
-- pattern beside it (backgroundColor and backgroundPattern share
-- "Background fill", and so on for each colour with a pattern), and a
-- pattern fills where the colour would, so Clear takes it away too. In
-- rc.6.15 Clear looked only at the colour, and a fill that was a pattern
-- could be taken away only from the pattern's right-click menu
-- (LittleNemo, openxtalk.org p=26076)
getProp editorClearable
   if not the editorEnabled of me then return false
   if the editorProperty["read_only"] of me is true then return false
   if ";" is in the editorProperty["property_name"] of me then return false
   if editorPatternClearable() then return true
   if the editorConflicted of me is true then return true
   if the editorEffective of me then return false
   return the editorValue of me is not empty
end editorClearable

-- The long id of the pattern editor in this colour's row (the group named
-- for the property, as the row names each of its editors), or empty: a
-- row with no pattern, or a property not named "...Color"
private function editorPatternSibling
   local tProperty
   put the editorProperty["property_name"] of me into tProperty
   if char -5 to -1 of tProperty is not "Color" then return empty
   put char 1 to -6 of tProperty & "Pattern" into tProperty
   if there is not a group tProperty of the owner of me then return empty
   if the editorProperty["editor"] of group tProperty of the owner of me is not "com.livecode.pi.pattern" then
      return empty
   end if
   return the long id of group tProperty of the owner of me
end editorPatternSibling

-- Whether this colour's row has a pattern Clear can take away: one of the
-- objects' own, or different patterns, as for the colour
private function editorPatternClearable
   local tPattern
   put editorPatternSibling() into tPattern
   if tPattern is empty then return false
   if the editorProperty["read_only"] of tPattern is true then return false
   if not the editorEnabled of tPattern then return false
   if the editorConflicted of tPattern is true then return true
   if the editorEffective of tPattern then return false
   return the editorValue of tPattern is not empty
end editorPatternClearable

-- Sent by the pattern editor beside this colour when it shows a new
-- pattern: the rows update their editors in no set order, so the colour's
-- own editorUpdate may have come first, with the pattern as it was
on editorPatternUpdated
   local tClearable
   if there is not a button kClearButton of me then exit editorPatternUpdated
   put the editorClearable of me into tClearable
   lock messages
   set the enabled of button kClearButton of me to tClearable
   unlock messages
end editorPatternUpdated

on editorUpdate
   lock screen
   local tValue, tEffective, tEnabled, tClearable
   put the editorValue of me into tValue
   put the editorEnabled of me into tEnabled
   put the editorEffective of me into tEffective
   -- (read before the messages are locked: it is a getProp)
   put the editorClearable of me into tClearable
   
   lock messages
   if tValue is not empty and \
         the number of items in tValue < 3 then
      put true into sNamedColor
      put revIDENamedColorToRGB(tValue) into tValue
   else
      put false into sNamedColor
   end if 
   
   set the enabled of control 1 of me to tEnabled
   if tEffective then
      set the swatchcolor of control 1 of me to empty
   else
      set the swatchcolor of control 1 of me to item 1 to 3 of tValue
   end if
   if there is a button kClearButton of me then
      set the enabled of button kClearButton of me to tClearable
   end if
   unlock messages
   unlock screen
end editorUpdate

on editorResize
   lock screen
   lock messages
   set the rect of control 1 of me to 0,0,kColorEditorSize,kColorEditorSize
   set the topleft of control 1 of me to the topleft of me
   if there is a button kClearButton of me then
      set the topleft of button kClearButton of me to \
            the right of control 1 of me + kClearGap, the top of me
   end if
   unlock messages
   unlock screen
end editorResize

on valueChanged
   local tColor, tNamedColor
   put item 1 to 3 of the swatchcolor of control 1 of me into tColor
   if sNamedColor then
      put revIDERGBToNamedColor(tColor) into tNamedColor
   end if
   
   if tNamedColor is not empty then
      set the editorValue of me to tNamedColor
   else
      set the editorValue of me to tColor
      put false into sNamedColor
   end if
   
   updateProperty
end valueChanged

-- The property set to empty, as the right-click menu's Clear does. The
-- swatch and the button show it at once, as the colour dialog's answer is
-- shown at once, rather than waiting for the engine to say the property
-- changed (the Reset that stayed on screen, p=25968)
command editorClearColour
   local tPattern
   if not the editorClearable of me then exit editorClearColour
   lock screen
   -- the pattern first, read before the colour is set: setting it may
   -- have the inspector show the row again
   if editorPatternClearable() then put editorPatternSibling() into tPattern
   set the editorValue of me to empty
   put false into sNamedColor
   updateProperty
   -- an empty colour leaves a pattern in place (MCObject::SetColor), so
   -- the pattern is set to empty too, through its own editor, as its
   -- right-click menu's "Reset to default" does
   if tPattern is not empty and exists(tPattern) then
      set the editorValue of tPattern to empty
      dispatch "updateProperty" to tPattern with true
      dispatch "editorUpdate" to tPattern
   end if
   lock messages
   set the swatchcolor of control 1 of me to empty
   set the enabled of button kClearButton of me to false
   unlock messages
   unlock screen
end editorClearColour

on mouseUp pButton
   if pButton is not 1 then 
      pass mouseUp
      exit mouseUp 
   end if
   
   if the short name of the target is kClearButton and \
         word 1 of the target is "button" then
      editorClearColour
      exit mouseUp
   end if
   
   answer color with item 1 to 3 of the swatchcolor of control 1 of me
   if it is not empty then
      set the swatchcolor of control 1 of me to it
      dispatch "valueChanged"
   end if
end mouseUp
