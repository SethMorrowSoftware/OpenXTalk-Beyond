script "com.livecode.pi.pattern.behavior"
on editorInitialize
   set the editorMinWidth of me to 24
   set the editorMaxWidth of me to 24
end editorInitialize

on editorUpdate
   lock screen
   local tValue, tEffective, tEnabled
   put the editorValue of me into tValue
   put the editorEnabled of me into tEnabled
   put the editorEffective of me into tEffective
   lock messages
   set the enabled of graphic 1 of me to tEnabled
   if tEffective then
      set the backgroundpattern of graphic 1 of me to empty
   else
      set the backgroundpattern of graphic 1 of me to tValue
   end if
   unlock messages
   -- OXT-Beyond: the colour beside this pattern in its row enables its
   -- Clear for a pattern too (com.livecode.pi.color.behavior), so it is
   -- told this pattern changed (LittleNemo, openxtalk.org p=26076)
   editorTellColour
   unlock screen
end editorUpdate

private command editorTellColour
   local tProperty
   put the editorProperty["property_name"] of me into tProperty
   if char -7 to -1 of tProperty is not "Pattern" then exit editorTellColour
   put char 1 to -8 of tProperty & "Color" into tProperty
   if there is a group tProperty of the owner of me then
      dispatch "editorPatternUpdated" to group tProperty of the owner of me
   end if
end editorTellColour

on editorResize
   lock screen
   lock messages
   set the rect of graphic 1 of me to the rect of me
   unlock messages
   unlock screen
end editorResize

on valueChanged
   set the editorValue of me to the backgroundpattern of graphic 1 of me
   updateProperty
end valueChanged

on mouseUp pButton
   if pButton is not 1 then exit mouseUp
   --PM-2016-05-02: [[ Bug 17496 ]] Show the ID of the currently selected pattern
   put the backgroundpattern of graphic 1 of me into tIconID
   send "updateIDField tIconID" to card 1 of stack "revIconChooser"
   sheet "revIconChooser"
   if the cReturnValue of stack "revIconChooser" is not empty then
      set the backgroundpattern of graphic 1 of me to the cReturnValue of stack "revIconChooser"
      dispatch "valueChanged"
   end if
end mouseUp
