script "com.livecode.pi.string.behavior"
constant kEffectiveTextColor = "100,100,100"
constant kEffectiveTextColorDark = "170,170,170"
constant kConflictedFieldColor = "193,201,215"

on editorInitialize
   set the editorMinWidth of me to 25
   set the editorMaxWidth of me to 0
end editorInitialize

on editorUpdate
   lock screen
   local tValue, tEffective, tEnabled, tConflicted
   put the editorValue of me into tValue
   put the editorEnabled of me into tEnabled
   put the editorEffective of me into tEffective
   put the editorConflicted of me into tConflicted
   
   lock messages
   set the locktext of field 1 of me to not tEnabled
   if tEffective is true then
      if the focusedobject is not the long ID of field 1 of me then
         put tValue into field 1 of me
      end if
      set the textcolor of field 1 of me to effectiveTextColor(the long id of field 1 of me)
      set the textstyle["italic"] of field 1 of me to true
   else
      put tValue into field 1 of me
      set the textstyle of field 1 of me to empty
      if not tEnabled then
      	set the textcolor of field 1 of me to "108,108,108"
      else
      	set the textcolor of field 1 of me to empty
      end if
   end if
   
   if tConflicted then
      set the backcolor of field 1 of me to kConflictedFieldColor
   else
      set the backcolor of field 1 of me to empty
   end if
   unlock messages
   
   unlock screen
end editorUpdate

on openField
   if the editorEffective of me is true then
      lock messages
      put empty into field 1 of me
      # Ensure that when the user types the text is the default color rather than the effective grey
      set the textcolor of field 1 of me to empty
      unlock messages
   end if
end openField

on exitField
   editorUpdate
end exitField

on returnInField
   valueChanged
end returnInField

on enterInField
   valueChanged
end enterInField

on closeField 
   valueChanged
end closeField

on editorResize
   lock screen
   lock messages
   set the height of field 1 of me to the formattedHeight of field 1 of me
   set the width of field 1 of me to the width of me
   set the topleft of field 1 of me to the topleft of me
   unlock messages
   unlock screen
end editorResize

on valueChanged
   set the editorvalue of me to field 1 of me
   updateProperty
end valueChanged

-- OXT-Beyond: the grey of an inherited (effective) value, 100,100,100,
-- cannot be read on the dark appearance's dark controls (richmond62's
-- font menu on rc.6.3); there it is a light grey, chosen by how dark the
-- control it is drawn on is, or where its colour is the theme's pattern
-- rather than a colour (macOS's menus), by the system's appearance
private function effectiveTextColor pObject
   local tBack
   put the effective backgroundColor of pObject into tBack
   if the number of items of tBack is 3 and item 1 of tBack is an integer then
      if item 1 of tBack + item 2 of tBack + item 3 of tBack < 384 then
         return kEffectiveTextColorDark
      end if
   else if the systemAppearance is "dark" then
      return kEffectiveTextColorDark
   end if
   return kEffectiveTextColor
end effectiveTextColor
