script "stack_revPreferencesGUI_card_id_1008"
-- Stack file: ide/Toolset/palettes/revpreferencesgui.rev
-- Object: stack "revPreferencesGUI" > card "Appearance" (id 1008)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- OXT-Beyond: makes the check box for the preference cUseDesktopAppearance
-- on Linux (once; the stack file is not saved), where the Mac's check box
-- would be, and shows its setting. While it is ticked the systemAppearance
-- follows the desktop's light or dark setting (GNOME's color-scheme), so
-- the IDE's palettes go dark with the desktop
on oxtPrefsDesktopAppearanceBox
   local tBox, tRect
   if the platform is not "Linux" then exit oxtPrefsDesktopAppearanceBox
   if there is not a button "useDesktopAppearance" of me then
      lock messages
      copy button "gridCheckAtStartup" of me to group "Appearance" of me
      put it into tBox
      set the name of tBox to "useDesktopAppearance"
      set the label of button "useDesktopAppearance" of me to "Follow the desktop's light or dark setting"
      set the toolTip of button "useDesktopAppearance" of me to "The IDE goes dark when the desktop is set to dark (GNOME's colour scheme), and light again with it"
      put the rect of button "gridCheckAtStartup" of me into tRect
      put item 2 of tRect - 33 into item 2 of tRect
      put item 4 of tRect - 33 into item 4 of tRect
      put item 1 of tRect + 300 into item 3 of tRect
      set the rect of button "useDesktopAppearance" of me to tRect
      set the script of button "useDesktopAppearance" of me to "on mouseUp" & return & "   oxtPrefsSetDesktopAppearance the hilite of me" & return & "end mouseUp"
      unlock messages
   end if
   set the hilite of button "useDesktopAppearance" of me to (the cUseDesktopAppearance of stack "revPreferences" is true)
end oxtPrefsDesktopAppearanceBox

on oxtPrefsSetDesktopAppearance pValue
   local tError
   revIDESetPreference "cUseDesktopAppearance", (pValue is true)
   try
      do "set the useDesktopAppearance to" && (pValue is true)
   catch tError
      -- an engine without the property
   end try
end oxtPrefsSetDesktopAppearance

on preOpenCard
   -- OXT-Beyond: on Linux, the desktop's light or dark setting (the
   -- global useDesktopAppearance)
   oxtPrefsDesktopAppearanceBox
   set the label of button "rulers" to the cREVRulerMeasurement of stack "revPreferences"
   put the cGridSize of stack "revPreferences" into field "gridSize"
   
   if the platform is "MacOS" then
      put "(-" into line -2 of button "backdrop color"
      put "(-" into line -2 of button "selectionHandle color"
      put "(-" into line -2 of button "hypertext color"
      --put "Default" & cr & "(-" & cr & tFontNames into button "Default script font"
   else
      # Can't have dividers in option menus on PC platforms
      put empty into line -2 of button "backdrop color"
      put empty into line -2 of button "selectionHandle color"
      put empty into line -2 of button "hypertext color"
      --      put "Default" & cr & cr & tFontNames into button "Default script font"
   end if
   
   set the label of button "backdrop color" to the cBackDropColor of stack "revPreferences"
   set the backgroundColor of graphic "Backdrop Swatch" to the cBackDropColor of stack "revPreferences"
   set the label of button "selectionhandle color" to "white"
   ---------------------
   --LG-2008-01-24
   --Bug 3486:  cSelectionHandleColor is empty when a user preference 
   --stack doesn't exist. 
   if the cSelectionHandleColor of stack "revPreferences" is empty then
      set the label of button "selectionhandle color" to the cSelectionHandle of stack "revPreferences"
      set the backgroundColor of graphic "Selection Handle Swatch" to the cSelectionHandle of stack "revPreferences"
   else
      set the label of button "selectionhandle color" to the cSelectionHandleColor of stack "revPreferences"
      set the backgroundColor of graphic "Selection Handle Swatch" to the cSelectionHandleColor of stack "revPreferences"
   end if
   ---------------
   ---------------
   -- new section about Tool button colour
   if the cToolSelectorColor of stack "revPreferences" is empty then
      -- if colours not stored in preferences
      set the label of button "toolselector color" to "Purple1" -- going with purple as defaults if no pref set
      set the backgroundColor of graphic "Tool Selector Swatch" to the label of button "toolselector color"
   else
      -- if colours already stored in preferences
      set the label of button "toolselector color" to the cToolSelectorColor of stack "revPreferences" -- load from saved value
      set the backgroundColor of graphic "Tool Selector Swatch" to the cToolSelectorColor of stack "revPreferences"
   end if
   ---------------
   ---------------
   -- check if revMenuBar should be draggable (tperry 10-11-2023)
   if the cMakeRevMenuBarDraggable of stack "revPreferences" is true then
      set the hilite of btn "MakeRevToolBarDraggable" of card "Appearance" of stack "revPreferencesGUI" to true
   else
      set the hilite of btn "MakeRevToolBarDraggable" of card "Appearance" of stack "revPreferencesGUI" to false
   end if--------------
   -- check if revMenuBar should be draggable (tperry amended 15-01-2024)
   if the cMakeRevMenuBarDraggable of stack "revPreferences" is true then
      set the hilite of btn "MakeRevToolBarDraggable" of card "Appearance" of stack "revPreferencesGUI" to true
      set the cMakeRevMenuBarDraggable of stack "revPreferences" to true
   else
      set the hilite of btn "MakeRevToolBarDraggable" of card "Appearance" of stack "revPreferencesGUI" to false
      set the cMakeRevMenuBarDraggable of stack "revPreferences" to false
   end if
   ---------------
   -- check if revMenuBar should be a standard window (tperry amended 15-01-2024)
   if the cMakeRevMenuBarStandard of stack "revPreferences" is true then
      set the hilite of btn "revMenubarStandardWD" of card "Appearance" of stack "revPreferencesGUI" to true
      set the cMakeRevMenuBarStandard of stack "revPreferences" to true
   else
      set the hilite of btn "revMenubarStandardWD" of card "Appearance" of stack "revPreferencesGUI" to false
      set the cMakeRevMenuBarStandard of stack "revPreferences" to false
   end if
   ---------------
   
   set the label of button "hypertext color" to the cREVHelpHiliteColor of stack "revPreferences"
   set the backgroundColor of graphic "Help Hilite Swatch" to the cREVHelpHiliteColor of stack "revPreferences"
   
   put the cREVToolTipDelay of stack "revPreferences" into field "tooltip delay"
   put the toolTipDelay into field "ToolTip Delay"
   
   -- restore grid setting (tperry 02-12-23)
   if the cGrid of stack "revPreferences" is true then
      set the hilite of btn "gridCheckAtStartup" of cd "Appearance" of stack "revPreferencesGUI" to true
      set the grid to true
   else
      set the hilite of btn "gridCheckAtStartup" of cd "Appearance" of stack "revPreferencesGUI" to false
      set the grid to false
   end if
   
   -- add option to tweak size of palette icons (tperry 21-4-24)
   put the revPaletteFrameSize of stack "revPreferences" into vPalLab
   if vPalLab is "" then put "small" into vPalLab
   set the label of btn "frameSize" to vPalLab
   
   -- update the appearance of the arrow tool icon
   set the icon of btn "tArrowBtn" of cd "Appearance" of stack "revPreferencesGUI" to (the id of image "com.livecode.tool.Browse.icon.png" of stack "revTools")
   send tUpdBrowseCursors to stack "home"
   
   -- update the middle mouse btn tool toggle 20-6-24
   if the cMiddleBtnToggle of stack "revPreferences" is true then
      set the hilite of btn "middleButtonToggle" of cd "Appearance" of stack "revPreferencesGUI" to true
   else
      set the hilite of btn "middleButtonToggle" of cd "Appearance" of stack "revPreferencesGUI" to false
   end if
   
   -- make sure hand and arrow icons on the card don't have any opacity 23-6-24
   set the opaque of btn "tHandBtn" of cd "Appearance" of stack "revPreferencesGUI" to false
   set the opaque of btn "tArrowBtn" of cd "Appearance" of stack "revPreferencesGUI" to false
   
   -- OXT-Beyond: the Mac's window colour for stacks (the global
   -- useSystemWindowColor)
   oxtPrefsSystemWindowColorBox
end preOpenCard

-- OXT-Beyond: makes the check box for the preference cUseSystemWindowColor
-- on the Mac (once; the stack file is not saved) and shows its setting
on oxtPrefsSystemWindowColorBox
   local tBox, tRect
   if the platform is not "MacOS" then exit oxtPrefsSystemWindowColorBox
   if there is not a button "useSystemWindowColor" of me then
      lock messages
      copy button "gridCheckAtStartup" of me to group "Appearance" of me
      put it into tBox
      set the name of tBox to "useSystemWindowColor"
      set the label of button "useSystemWindowColor" of me to "Stacks in the Mac's window colour"
      set the toolTip of button "useSystemWindowColor" of me to "Stacks with no background colour of their own are light grey, as Mac windows are, instead of white"
      put the rect of button "gridCheckAtStartup" of me into tRect
      put item 2 of tRect - 33 into item 2 of tRect
      put item 4 of tRect - 33 into item 4 of tRect
      put item 1 of tRect + 260 into item 3 of tRect
      set the rect of button "useSystemWindowColor" of me to tRect
      set the script of button "useSystemWindowColor" of me to "on mouseUp" & return & "   oxtPrefsSetSystemWindowColor the hilite of me" & return & "end mouseUp"
      unlock messages
   end if
   set the hilite of button "useSystemWindowColor" of me to (the cUseSystemWindowColor of stack "revPreferences" is true)
end oxtPrefsSystemWindowColorBox

on oxtPrefsSetSystemWindowColor pValue
   local tError
   revIDESetPreference "cUseSystemWindowColor", (pValue is true)
   try
      do "set the useSystemWindowColor to" && (pValue is true)
   catch tError
      -- an engine without the property
   end try
end oxtPrefsSetSystemWindowColor
