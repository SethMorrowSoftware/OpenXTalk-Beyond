script "com.livecode.pi.enum.behavior" with behavior "revInspectorEditorBehavior"
-- Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
-- (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
-- Seth Morrow (2026), Tom Perry (2026) and Emily-Elizabeth Howard (2026);
-- its Git history and CHANGELOG.md say what changed.

constant kEffectiveTextColor = "100,100,100"
constant kEffectiveTextColorDark = "170,170,170"
global gRevLanguageNames

-- OXT-Beyond: an option of the property's own list (the Options of its
-- row in a .tsv file, or a widget's metadata) can be a label and a value,
-- "Label|value", and the value can be empty: iconGravity's empty value
-- read as a blank line in its menu (tperry2x, openxtalk.org p=25419), so
-- its list gives it the label Default ("Default|"). The menu shows the
-- labels, or with the Inspector's language names (gRevLanguageNames) the
-- values but the label of an empty value, and a pick sets the value. The
-- labels were meant to work so (theme's "Native|native"), but the menu
-- showed such an option as it is written, with its "|" (the loop that was
-- to take out its label or its value changed a copy of the line), and a
-- pick of one changed nothing. An option with no "|" is shown and set as
-- it is, as before, and so is every option of a list a script makes
-- ("execute:", the main stacks), whose "|" can be in a stack's name. Where
-- the objects inspected have different values, a new editor's menu shows
-- nothing, as before, not Default.
on editorInitialize
   set the editorMinWidth of me to 40
   set the editorMaxWidth of me to 0
   
   local tText, tOptions, tLine, tNumber
   put the editorOptions of me into tOptions
   put tOptions into tText
   if optionsHaveLabels() then
      put 0 into tNumber
      repeat for each line tLine in tOptions
         add 1 to tNumber
         if tLine contains "|" then
            put optionShown(tLine) into line tNumber of tText
         end if
      end repeat
   end if
   set the text of button "pulldown" of me to tText

end editorInitialize

on editorUpdate
   lock screen
   local tValue, tEffective, tEnabled
   put the editorValue of me into tValue
   put the editorEnabled of me into tEnabled
   put the editorEffective of me into tEffective
   
   local tOptions, tLabels, tConflicted
   put the editorOptions of me into tOptions
   put optionsHaveLabels() into tLabels
   put the editorConflicted of me into tConflicted
   
   lock messages
   local tLabel, tLine
   
   -- what the menu shows for the value: its option's label, or with the
   -- language names the value itself, as the menu's lines do. When the
   -- objects inspected have different values (editorConflicted) the
   -- Inspector does not set the editor's value, so it is not theirs (in a
   -- new editor, empty): an empty one shows nothing, as before, rather
   -- than the label of an empty value (Default), which none of them may have
   put tValue into tLabel
   if tConflicted is not true or tValue is not empty then
      repeat for each line tLine in tOptions
         if tLabels and tLine contains "|" then
            if tValue is optionValue(tLine) then
               put optionShown(tLine) into tLabel
               exit repeat
            end if
         else if tValue is tLine then
            if not gRevLanguageNames then put tLine into tLabel
            exit repeat
         end if
      end repeat
   end if
   
   set the label of button "pulldown" of me to tLabel
   
   set the enabled of me to tEnabled
   if tEffective is true then
      set the textcolor of button "pulldown" of me to effectiveTextColor(the long id of button "pulldown" of me)
      set the textstyle["italic"] of button "pulldown" of me to true
   else
      set the textcolor of button "pulldown" of me to empty
      set the textstyle of button "pulldown" of me to empty
      -- prevents pulldown / popup menus on mac inspector from losing their text colour on MacOS (tperry 16-10-2025)
      --if the platform contains "mac" then set the foregroundColor of button "pulldown" of me to black
      
   end if
   unlock messages
   unlock screen
end editorUpdate

on editorResize
   lock screen
   lock messages
   set the rect of button "pulldown" of me to the rect of me
   unlock messages
   unlock screen
end editorResize

on valueChanged
   local tOptions, tLabels, tPicked, tLine
   put the editorOptions of me into tOptions
   put optionsHaveLabels() into tLabels
   -- a pick makes the menu's label the line picked
   put the label of button "pulldown" of me into tPicked
   repeat for each line tLine in tOptions
      if tLabels and tLine contains "|" then
         if optionShown(tLine) is tPicked then
            set the editorValue of me to optionValue(tLine)
            exit repeat
         end if
      else if tLine is tPicked then
         set the editorValue of me to tLine
         exit repeat
      end if
   end repeat
   updateProperty
end valueChanged

-- OXT-Beyond: true when the options are the property's own list, whose
-- options can have labels; false when a script makes them ("execute:"),
-- as revInspectorEditorBehavior's editorOptions does
private function optionsHaveLabels
   return not (the editorProperty["options"] of me begins with "execute")
end optionsHaveLabels

-- The value of the option "Label|value" pOption: what follows its first
-- "|", which can be empty
private function optionValue pOption
   set the itemdelimiter to "|"
   return item 2 to -1 of pOption
end optionValue

-- What the menu shows for the option "Label|value" pOption: its label,
-- or with the language names its value, unless that is empty; its value
-- when it has no label
private function optionShown pOption
   local tLabel, tValue
   set the itemdelimiter to "|"
   put item 1 of pOption into tLabel
   put item 2 to -1 of pOption into tValue
   if tLabel is empty or (gRevLanguageNames and tValue is not empty) then
      return tValue
   end if
   return tLabel
end optionShown

-- OXT-Beyond: the grey of an inherited (effective) value, 100,100,100,
-- cannot be read on the dark appearance's dark controls (richmond62's
-- font menu on rc.6.3); there it is a light grey, chosen by how dark the
-- control it is drawn on is. A colour of the control's own is drawn as it
-- is. Without one these controls (opaque, with a border) are drawn in the
-- theme's colour, whatever colour the Inspector's window has (its
-- background preference). On macOS and Windows that follows the system's
-- appearance, which decides (for a button's or a menu's colour macOS
-- gives scripts a stand-in, controlHighlightColor, rather than the colour
-- it draws). On Linux the GTK theme's is the control's effective colour,
-- unless something the control is in has a colour of its own: then it is
-- the effective colour of a template, which is in nothing.
private function effectiveTextColor pObject
   local tBack, tOwner
   put the backgroundColor of pObject into tBack
   if tBack is empty and the platform is among the items of "MacOS,Win32" then
      if the systemAppearance is "dark" then
         return kEffectiveTextColorDark
      end if
      return kEffectiveTextColor
   end if
   if tBack is empty then
      put the effective backgroundColor of pObject into tBack
      put pObject into tOwner
      repeat while word 1 of tOwner is not "stack"
         put the long id of the owner of tOwner into tOwner
         if the backgroundColor of tOwner is not empty then
            if word 1 of pObject is "field" then
               put the effective backgroundColor of the templateField into tBack
            else
               put the effective backgroundColor of the templateButton into tBack
            end if
            exit repeat
         end if
      end repeat
   end if
   if the number of items of tBack is 3 and item 1 of tBack is an integer then
      if item 1 of tBack + item 2 of tBack + item 3 of tBack < 384 then
         return kEffectiveTextColorDark
      end if
   end if
   return kEffectiveTextColor
end effectiveTextColor
