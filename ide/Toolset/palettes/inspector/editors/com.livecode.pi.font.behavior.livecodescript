script "com.livecode.pi.font.behavior"
-- Modified from LiveCode Community. This copy, OpenXTalk-Beyond's
-- (https://github.com/SethMorrowSoftware/OpenXTalk-Beyond), has changes by
-- Seth Morrow (2026) and Emily-Elizabeth Howard (2026); its Git history and
-- CHANGELOG.md say what changed.

constant kFontMenuLines = 20

on editorInitialize
   set the editorMinWidth of me to 40
   set the editorMaxWidth of me to 0
   
   local tFontNames
   put the fontNames into tFontNames
   sort tFontNames
   set the text of button 1 of me to tFontNames
   set the menuLines of button 1 of me to kFontMenuLines
end editorInitialize

on editorUpdate
   lock screen
   local tValue, tEffective, tEnabled
   put the editorValue of me into tValue
   put the editorEnabled of me into tEnabled
   put the editorEffective of me into tEffective
   
   set the label of button 1 of me to tValue
   
   set the enabled of me to tEnabled
   -- OXT-Beyond: an inherited (effective) font is shown in italics in
   -- the menu's own text colour, not in the grey italics of the other
   -- editors: on a menu grey reads as disabled, and richmond62 (rc.6.3,
   -- and again on rc.6.13) took the font menu of a control that takes its
   -- font from its stack for a dead one. A disabled editor (editorEnabled
   -- false) is still drawn as the engine draws a disabled control
   set the textcolor of button 1 of me to empty
   if tEffective is true then
      set the textstyle["italic"] of button 1 of me to true
   else
      set the textstyle of button 1 of me to empty
   end if
   unlock messages
   unlock screen
end editorUpdate

on editorResize
   lock screen
   lock messages
   set the rect of button 1 of me to the rect of me
   unlock messages
   unlock screen
end editorResize

on valueChanged
   set the editorValue of me to the label of button 1 of me
   updateProperty
end valueChanged

on closeField
   valueChanged
end closeField
