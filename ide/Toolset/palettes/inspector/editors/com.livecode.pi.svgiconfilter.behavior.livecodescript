script "com.livecode.pi.svgiconfilter.behavior"
on preOpenStack
   set the text of field "FilterText" to "Search"
   set the filterString of widget "iconList" of me to empty
   set the showSelectedElement of widget "iconList" of me to false
   set the iconSize of widget "iconList" of me to 55
   set the showNames of widget "iconList" of me to true
   set the selectedIcon of widget "iconList" of me to the dialogData
   svgIconFilterShowAppearance
   
   set the behavior of me to the long id of stack "com.livecode.pi.svgiconfilter.behavior"
   focus on nothing
end preOpenStack

-- OXT-Beyond: the icon picker widget draws its icons and names light grey
-- only in the dark appearance on a dark card (MCWidgetGetMyAppearanceIsDark,
-- #422), and black otherwise. On Linux the systemAppearance is "light"
-- unless Preferences > Appearance follows the desktop, while a dark GTK
-- theme still draws this card dark: black icons on it could hardly be seen.
-- The IDE reads the desktop as dark there (revIDEAppearanceIsDark: the GTK
-- window colour) and asks the widget for its dark colours (its darkIcons).
-- Anywhere the widget already decides for itself, the systemAppearance dark
-- on macOS, Windows, or Linux following the desktop, and in every light
-- appearance, darkIcons is false, so the chooser is drawn exactly as before
command svgIconFilterShowAppearance
   set the darkIcons of widget "iconList" of me to \
         svgIconFilterNeedsDark(revIDEAppearanceIsDark(), the systemAppearance)
end svgIconFilterShowAppearance

-- true when the desktop is dark (pDesktopDark, revIDEAppearanceIsDark())
-- but the widget, which follows the systemAppearance pAppearance, would
-- still draw black icons
function svgIconFilterNeedsDark pDesktopDark, pAppearance
   return pDesktopDark is true and pAppearance is not "dark"
end svgIconFilterNeedsDark

on mouseUp
   if the short name of the target is "iconList" then
      if the selectedIcon of widget "iconList" of me is not empty then
         set the dialogData to the selectedIcon of widget "iconList" of me
      end if
      close this stack
   end if
end mouseUp

on openField
   if the short name of the target is "FilterText" then
      if field "FilterText" is "Search" then
         set the text of field "FilterText" to empty
      end if
   end if
end openField

on enterField
   if the short name of the target is "FilterText" then
      if field "FilterText" is "Search" then
         set the text of field "FilterText" to empty
      end if
   end if
end enterField

on closeField
   if the short name of the target is "FilterText" then
      if field "FilterText" is empty then
         set the text of field "FilterText" to "Search"
      end if
   end if
end closeField

on exitField
   if the short name of the target is "FilterText" then
      if field "FilterText" is empty then
         set the text of field "FilterText" to "Search"
      end if
   end if
end exitField

on textChanged
   local tFilterText
   
   if the short name of the target is "FilterText" then      
      put field "FilterText" into tFilterText      
      set the filterString of widget "iconList" of me to tFilterText
   end if
end textChanged

on returnInField
   // Do nothing
end returnInField

on escapeKey
   close this stack
end escapeKey
