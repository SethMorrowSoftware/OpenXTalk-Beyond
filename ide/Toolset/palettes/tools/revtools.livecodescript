script "revTools" with behavior "revPaletteBehavior"
﻿script "revTools" with behavior "revPaletteBehavior"
constant BLOCK_SIZE = 20

constant kToolsColumnCountDefault = 2
on preOpenStack
   if the cREVLaunching of stack "Home" is true then set the blendlevel of this stack to 99 -- tperry 1/5/24
   
   dispatch "setAsBehavior" to revIDEFrameBehavior() with the long id of me
   
   set the title of me to "Tools"
   
   # Preferences
   if revIDEGetPreference("revTools_columns") is not a number then revIDESetPreference "revTools_columns", kToolsColumnCountDefault
   --addFrameItem "revTools_columns", "header", "preference", "View Columns", "enum","2,3,4", "framePreferenceSelected", the long id of me
   --addFrameItem "add_widget","header", "action", "Find More Widgets", "plus", "plus","findMoreWidgets", the long id of me
   
   # Look at the preference setting and validate the entries against the tool data
   local tAllViewList, tObjectData
   put objectTypes() into tObjectData
   repeat for each key tKey in tObjectData
      put tObjectData[tKey]["name"] & comma after tAllViewList
   end repeat
   delete the last char of tAllViewList
   
   local tObjectViewsPreferenceSetting, tObjectViewsToShow
   put revIDEGetPreference("revTools_show") into tObjectViewsPreferenceSetting
   
   # AL-2015-03-13: [[ Bug 14934 ]] Ensure empty preference results in all tools showing in the palette
   if tObjectViewsPreferenceSetting is empty then
      put tAllViewList into tObjectViewsToShow
   else
      repeat for each item tView in tObjectViewsPreferenceSetting
         if tView is among the items of tAllViewList then
            if tObjectViewsToShow is empty then
               put tView into tObjectViewsToShow
            else 
               put comma & tView after tObjectViewsToShow
            end if
         end if
      end repeat
   end if
   
   # Set the preference in the frame
   if tObjectViewsToShow is not tObjectViewsPreferenceSetting then 
      revIDESetPreference "revTools_show", tObjectViewsToShow
   end if
   --addFrameItem "revTools_show", "header", "preference", "Show Sections", "set","widget:Widgets Controls,classic:Classic Controls,graphic:Graphic Objects,graphictools:Graphic Tools,paint:Paint Tools", "framePreferenceSelected", the long id of me
   
   ### Properties
   set the resizable of me to false
   
   # Ensure paint defaults are set
   reset paint
   set the filled to true
end preOpenStack

on openStack
   lock screen
   layoutpalette
   registerForMessages
   set the visible of me to true
   unlock screen
   
   -- is this the last thing that gets called?
   -- change the cursor state to show that we have finished loading the IDE
   set the defaultCursor to 0 -- sets to normal arrow
   
  tToolsFixup
  send tfixwindowsToolsDrag to me in 1 second
  pass openstack
end openStack

on tToolsFixup
   if the platform contains "linux" then
      -- check to see if we need to adjust for problem distros?
      put "icewm,xubuntu,ubuntu,xfce" into tFixDistros -- these are the distros (sessions) to adjust
      set the itemdelimiter to ","
      if $DESKTOP_SESSION_WM or $DESKTOP_SESSION is among the items of tFixDistros then
         -- do I need to do anything for problematic distros?
         set the decorations of this stack to none
         if there is a stack "revMenubar" then set the top of this stack to the bottom of stack "revMenubar"
         set the left of this stack to "0"
      end if -- end linux session check
   end if
end tToolsFixup

on tfixwindowsToolsDrag
   if the platform contains "win" then set the systemwindow of this stack to true
end tfixwindowsToolsDrag

on ensureToolsIsDraggable
   -- make sure the tools are draggable (tperry 14-1-24)
   set the decorations of this wd to "title,menu,close"
   --set the style of stack "revTools" to "toplevel"
   set the cantmodify of stack "revTools" to true
end ensureToolsIsDraggable

on registerForMessages
   ### Messages
   revIDESubscribe "idePreferenceChanged:revTools_columns"
   revIDESubscribe "idePreferenceChanged:revTools_show"
   revIDESubscribe "idePreferenceOfSetChanged"
   revIDESubscribe "ideToolChanged"
   -- revIDESubscribe "ideExtensionsChanged"
   revIDESubscribe "ideAppearanceChanged"
end registerForMessages

-- OXT-Beyond: the IDE's appearance changed (revIDEIsDark): the icon set,
-- the widget icons' colour and the separators are chosen when the palette
-- is generated
on ideAppearanceChanged
   lock screen
   generatePalette
   layoutPalette
   unlock screen
end ideAppearanceChanged

on findMoreWidgets
   lock screen
   revIDEFindMoreWidgets
   unlock screen
end findMoreWidgets

on ideExtensionsChanged
   lock screen
   generatePalette
   layoutPalette
   unlock screen
end ideExtensionsChanged

on idePreferenceChanged pPreference
   switch pPreference
      case  "revTools_columns"
         # User has changed the number of columns they want to see
         resizeStack
         break
      case "revTools_show"
         # User has changed the sections of controls they want to see in their palette
         lock screen
         generatePalette
         resizeStack
         unlock screen
         break
   end switch
end idePreferenceChanged

on idePreferenceOfSetChanged pSet, pPreference
   switch pPreference
      case "uservisible"
         -- Regenerate tools palette after visible of widget changed
         generatePalette
         resizeStack
         break
   end switch
end idePreferenceOfSetChanged

constant kPolygonMenu = "Line Tool\nRectangle Tool\nRounded Rectangle Tool\nOval Tool\nRegular Polygon Tool\nPolygon Tool"
on ideToolChanged
   local tTool
   put the tool into tTool
   set the itemdelimiter to "\n"
   if tTool is among the items of kPolygonMenu then
      put "paint polygon shape tool" into tTool
      put hCreateSuitableImage (tTool) into tImgCmd
      send tDoImgCmd to me in 1 ticks
   end if
   
   local tControlID
   repeat with x = 1 to the number of controls of group "contents"
      put the long id of control x of group "contents" into tControlID
      if the cToolName of tControlID is tTool then
         if tTool is "graphic tool" and the style of the templategraphic is not the cStyle of tControlID then
            next repeat
         end if
         set the loc of graphic "tool_hilite" of group "contents" to the loc of tControlID
         show graphic "tool_hilite" of group "contents" 
         exit ideToolChanged
      end if
   end repeat
end ideToolChanged 

on framePreferenceSelected pPreference, pValue
   switch pPreference
      case "revTools_columns"
         if pValue is not a number then exit framePreferenceSelected
         revIDESetPreference "revTools_columns", pValue
         break
      case "revTools_show"
         local tCurrentPreferenceValue, tPreferencePosition, tItemOffset
         put revIDEGetPreference("revTools_show") into tCurrentPreferenceValue
         put itemOffset(pValue, tCurrentPreferenceValue) into tItemOffset
         if tItemOffset is not 0 then
            delete item tItemOffset of tCurrentPreferenceValue
         else
            if tCurrentPreferenceValue is empty then
               put pValue into tCurrentPreferenceValue
            else
               put comma & pValue after tCurrentPreferenceValue
            end if
         end if
         revIDESetPreference "revTools_show", tCurrentPreferenceValue
         break
   end switch
end framePreferenceSelected

on resizeStack
   lock screen
   lock messages
   layoutPalette
   unlock messages
   unlock screen
end resizeStack

constant kNoSeparatorSections = "runedit,graphictoolscontrols,paintcontrols"
on generatePalette
   lock screen
   # Clean up existing UI
   repeat while there is a group "contents"
      delete group "contents"
   end repeat
   reset the templateGroup
   create group "contents"
   
   # Clear the error group
   if there is a group "errors" then delete group "errors"
   
   # Get the appropriate platform theme folder
   local tThemePath
   put revIDEThemePath() into tThemePath
   -- tperry 19-1-24 (add in support for variable dark themes)
   -- Each theme has a "dark" folder of icons for the dark appearance: Tom
   -- Perry's sets for macOS, Linux and (since OXT Lite 1.07) Windows.
   -- revIDEIsDark() decides on every platform; on Linux it applies the rule
   -- this palette used, the brightness of the window background.
   put "" into tThemeClarify
   if revIDEIsDark() and there is a folder (tThemePath & slash & "dark") then
      put "dark" into tThemeClarify
   end if
   --
   if tThemeClarify is "dark" then
      set the cUsingTheme of stack "revTools" to "dark"
   else
      set the cUsingTheme of stack "revTools" to "light"
   end if
   if tThemeClarify is not empty then put tThemePath & slash & tThemeClarify into tThemePath
   
   # Get the data used for generating the palette
   local tViews, sViewsData
   put revIDEGetPreference("revTools_show") into tViews
   
   put revIDERunEditTools() into sViewsData["runedit"]
   repeat for each item tView in tViews
      switch tView
         case "widget"
            put revIDEWidgets() into sViewsData["widget"]
            break
         case "classic"
            put revIDEClassicControls() into sViewsData["classic"]
            break
         case "graphic"
            put revIDEGraphics() into sViewsData["graphic"]
            break 
         case "graphictools"
            put revIDEGraphicTools() into sViewsData["graphictools"]
            put revIDEGraphicToolControllers() into sViewsData["graphictoolscontrols"]
            break 
         case "paint"
            put revIDEPaintTools() into sViewsData["paint"]
            put revIDEPaintToolControllers() into sViewsData["paintcontrols"]
            break
      end switch
   end repeat
   
   # Generate UI
   lock messages
   
   # Reset the templates we are going to use
   reset the templatebutton
   reset the templategraphic
   reset the templateimage
   
   # Setup the template button
   set the width of the templatebutton to BLOCK_SIZE * 2
   set the height of the templatebutton to BLOCK_SIZE
   set the showname of the templatebutton to false
   set the style of the templatebutton to "transparent"
   
   set the threed of the templatebutton to false
   set the borderwidth of the templatebutton to 0
   set the blendlevel of the templatebutton to 0
   
   # Set up the template graphic
   set the opaque of the templategraphic to true
   set the visible of the templategraphic to false
   set the linesize of the templategraphic to 0
   set the width of the templategraphic to BLOCK_SIZE
   set the height of the templategraphic to BLOCK_SIZE
   -- changes the hilited colour behind the paint and draw tools (tperry)
   set the backgroundcolor of the templategraphic to (the cToolSelectorColor of stack "revPreferences") -- was: revIDEColor("edition_color")
   
   # Create hilite and hover graphic for tools
   create graphic "tool_hover" in group "contents"
   -- this changes the colour behind the "pointer" and "browse" tool when chosen (tperry)
   set the backgroundcolor of the templategraphic to (the cToolSelectorColor of stack "revPreferences") -- was "175,175,175" which was grey
   create graphic "tool_hilite" in group "contents"
   
   set the visible of the templategraphic to true
   set the height of the templategraphic to 1
   -- this is the dividing line between sections in the tools palette (tperry)
   -- (Tom's greys, 175 in light and 60 in dark, are revIDEColor's)
   set the backgroundcolor of the templategraphic to revIDEColor("palette_separator")
   
   set the itemdel to "."
   create group "images" in group "contents"
   
   repeat for each key tView in sViewsData
      if the number of elements of sViewsData[tView] is 0 then next repeat
      
      local tOrder
      put the keys of sViewsData[tView] into tOrder
      if tView is "widget" then
         # AL-2015-05-26: [[ Bug 14561 ]] Order extensions alphabetically
         sort tOrder by sViewsData[tView][each]["title"]
      else
         # Get a list of the ordered keys
         sort lines tOrder numeric ascending by sViewsData[tView][each]["order"]
         if tOrder contains "datagrid" then -- made loading of this conditional (tperry 13-4-24)
            if the cDisableDataGrid of stack "revPreferences" is true then
               replace "com.livecode.interface.classic.DataGrid" with "" in tOrder
               filter lines of tOrder without empty
            end if
         end if
      end if
      
      # Create the group to hold the controls
      create group tView in group "contents" 
      
      set the itemdel to ","
      if tView is not among the items of kNoSeparatorSections then
         create graphic tView in group "contents"
      end if
      
      repeat for each line tControlTypeID in tOrder
         # AL-2015-09-07: Don't show objects in tools palette if specified
         if sViewsData[tView][tControlTypeID]["userVisible"] is false then
            next repeat
         end if
         
         set the itemdel to ","
         put item 1 of tControlTypeID into tControlTypeID
         set the itemdel to "."
         
         # Setup the default button
         set the name of the templatebutton to the last item of tControlTypeID
         set the cType of the templatebutton to tView
         set the cStyle of the templatebutton to sViewsData[tView][tControlTypeID]["properties"]["style"]["default"]
         set the cName of the templatebutton to sViewsData[tView][tControlTypeID]["properties"]["name"]["default"]
         set the cStatus of the templatebutton to sViewsData[tView][tControlTypeID]["status"]
         
         if sViewsData[tView][tControlTypeID]["status"] is "error" then
            # Create a group to store the error icons
            if there is not a group "errors" of group "contents" then create group "errors" in group "contents"
            
            set the filename of the templateimage to revIDESpecialFolderPath("Toolset") & "/resources/supporting_files/images/warning.png"
            set the name of the templateimage to tControlTypeID
            set the visible of the templateimage to true
            create image in group "errors" of group "contents"
            set the id of it to revIDENewIconID()
         end if
         
         local tImageID, tFilename
         if sViewsData[tView][tControlTypeID]["icon"] is not empty then 
            put sViewsData[tView][tControlTypeID]["icon"] into tFilename
         else if there is a file (tThemePath & slash & tControlTypeID & ".icon.png") then 
            put tThemePath & slash & tControlTypeID & ".icon.png" into tFilename
         else
            -- put revIDEDefaultExtensionIcon("widget") into tFilename -- previously, replaced with a 'widget' graphic if it can't find the tool (19-1-24)
            put tThemePath & slash & tControlTypeID & ".icon.png" into tFilename
         end if
         set the name of the templateimage to tControlTypeID & ".icon.png"
         set the visible of the templateimage to false
         set the filename of the templateimage to tFilename
         create image in group "images" of group "contents"
         set the id of it to revIDENewIconID()
         put the long id of image (tControlTypeID & ".icon.png") of group "images" of group "contents" into tImageID
         revIDEResizeImageInBounds tImageID, BLOCK_SIZE * 2,BLOCK_SIZE
         set the icon of the templatebutton to the ID of tImageID
         
         # If the object is a tool, set the key custom properties to make it behave like a tool
         local tToolType
         put sViewsData[tView][tControlTypeID]["type"] into tToolType
         switch tToolType
            case "tool"
            case "option"
            case "paint tool"
               set the cTool of the templatebutton to tToolType
               set the cToolName of the templatebutton to sViewsData[tView][tControlTypeID]["tool"]
               break
            case "graphic tool"
               set the cTool of the templatebutton to tToolType
               set the cToolName of the templatebutton to "graphic tool"
               break
            default
               set the cTool of the templatebutton to empty
               break
         end switch
         
         local tTooltip
         put sViewsData[tView][tControlTypeID]["tooltip"] into tTooltip
         
         if tTooltip is empty then
            put sViewsData[tView][tControlTypeID]["title"] into tTooltip
         end if
         
         if tTooltip is empty then
            put item -1 of tControlTypeID into tTooltip
         end if
         
         set the tooltip of the templatebutton to tTooltip
         
         # Create the button
         if sViewsData[tView][tControlTypeID]["status"] is "error" then
            set the tooltip of the templatebutton to "There was an error while loading widget:" & return & tControlTypeID
            --set the blendlevel of the templatebutton to 50
         end if
         
         put "" into myAccBtnNames
         if sViewsData[tView][tControlTypeID]["svgicon"] is empty then
            create button tControlTypeID in group tView of group "contents"
            if the platform contains "mac" then
               -- we now need to support accent colours behind buttons! -- macOS only
               put the short name of button tControlTypeID of group tView of group "contents" into myAccName
               if there is a graphic myAccName then
                  -- accent colour already exists
               else
                  if myAccName contains "classic" then
                     if myAccName contains "Graphic" or myAccName contains "rectangleButton" or myAccName contains "scrollbar" or myAccName contains "classic.button" or myAccName contains "slider" or myAccName contains "classic.label" or myAccName contains "classic.arrow" or myAccName contains "star" or myAccName contains "image" or myAccName contains "player" or myAccName contains "textArea" or myAccName contains "bubble" or myAccName contains "classic.field" then
                        -- skip
                     else
                        create graphic myAccName
                        set the height of graphic myAccName to 10
                        set the width of graphic myAccName to 10
                        set the backgroundColor of graphic myAccName to the accentColor
                        put return & myAccName & return after myAccBtnNames
                     end if
                  end if
               end if
            end if
            -- end support for accent colour creation
            set the cType of button tControlTypeID to tView
         else
            create widget tControlTypeID as "com.livecode.widget.svgpath" in group tView of group "contents"
            set the width of widget tControlTypeID to BLOCK_SIZE * 2
            set the height of widget tControlTypeID to BLOCK_SIZE
            -- widget icons should be easier to see in dark mode
            set the foregroundColor of widget tControlTypeID to revIDEColor("palette_icon")

            set the iconpath of widget tControlTypeID to sViewsData[tView][tControlTypeID]["svgicon"]
            set the cType of widget tControlTypeID to tView
            set the cStyle of widget tControlTypeID to sViewsData[tView][tControlTypeID]["properties"]["style"]["default"]
            set the cName of widget tControlTypeID to sViewsData[tView][tControlTypeID]["properties"]["name"]["default"]
            set the cStatus of widget tControlTypeID to sViewsData[tView][tControlTypeID]["status"]
            set the cTool of widget tControlTypeID to empty
            set the tooltip of widget tControlTypeID to tTooltip
         end if
      end repeat
   end repeat
   
   # Reset the templates back post use
   reset the templatebutton
   reset the templategraphic
   reset the templateimage
   
   -- ensure we have paint colours correctly set (tperry 5/5/24)
   initPaintCol
   
   unlock messages
   unlock screen
end generatePalette

on layoutPalette
   lock screen
   
   if there is not a group "contents" of me then generatePalette  
   
   # Get the space that the content should fill
   unlock messages
   local tContentRect, tWidth, tPaletteMargin, tPalettePadding, tHeaderHeight
   put the paletteMargin of me into tPaletteMargin
   put the palettePadding of me into tPalettePadding
   put the contentrect of me into tContentRect
   # AL-2015-03-20: [[ Bug 14911 ]] Get the headerHeight with messages unlocked
   put the headerHeight of me into tHeaderHeight
   
   lock messages
   
   # Set the width based on the number of columns in the preference
   local tColumns
   put revIDEGetPreference("revTools_columns") into tColumns
   if tColumns < 2 or tColumns is not a number then put 2 into tColumns
   
   # Set the width of the palette based on number of columns in preference
   local tStackWidth, tStackLeft
   put  (tColumns * BLOCK_SIZE * 2) + (tPaletteMargin * 2) + (tPalettePadding * (tColumns - 1)) into tStackWidth
   set the maxwidth of me to tStackWidth
   set the minwidth of me to tStackWidth
   put the left of me into tStackLeft
   set the width of me to tStackWidth
   put tStackWidth - (tPaletteMargin * 2) into tWidth
   
   local tLeft,tTop, tLastView
   put item 2 of tContentRect + tPaletteMargin into tTop
   
   local tObjectTypeData, tView
   put objectTypes() into tObjectTypeData
   
   repeat with x = 1 to the number of elements of tObjectTypeData
      # Get the column count
      local tColumnCount, tBlockSize
      if  tObjectTypeData[x]["block size"] < 20 then
         put tColumns * 2 into tColumnCount
         put BLOCK_SIZE into tBlockSize
      else
         put tColumns into tColumnCount
         put BLOCK_SIZE * 2 into tBlockSize
      end if
      
      local tPadding
      put (tWidth - (tColumnCount * tBlockSize)) / (tColumnCount *2) into tPadding
      
      put tPaletteMargin  into tLeft
      
      # Check if the group of object type exists
      put tObjectTypeData[x]["name"] into tView
      if there is not a group tView of group "contents" then next repeat
      put tView into tLastView
      
      set the itemdel to ","
      if tView is not among the items of kNoSeparatorSections then        
         set the top of graphic tView of group "contents" to tTop
         set the width of graphic tView of group "contents" to tWidth - (tPadding * 2)
         set the left of graphic tView of group "contents" to tLeft
         add tPaletteMargin to tTop
      end if
      
      repeat with y = 1 to the number of controls of group tView of group "contents"
         # Get the short name of the object
         local tObjectID, tObjectName
         put the long id of control y of group tView of group "contents" into tObjectID
         put the short name of tObjectID into tObjectName
         
         set the width of tObjectID to tBlockSize
         set the topleft of tObjectID to tLeft, tTop
         put the right of tObjectID + (tPadding * 2) into tLeft
         
         # Check if there is an error icon
         if there is an image tObjectName of group "errors" of group "contents" then
            set the topright of image tObjectName of group "errors" of group "contents" to the topright of tObjectID
         end if
         
         if tLeft >= the width of me - tPaletteMargin - 5 then
            put tPaletteMargin  into tLeft
            add BLOCK_SIZE + (tPalettePadding) to tTop
         end if
      end repeat
      
      -- sections padding should now be conditional (tperry 15-1-25)
      if the cToolsSectionNames of stack "revPreferences" is true then
         put 10 into tExtraVertSpacing
      else 
         put 0 into tExtraVertSpacing
      end if
      put the bottom of tObjectID +tExtraVertSpacing + tPaletteMargin into tTop
   end repeat
   
   -- make section names conditional (tperry 15-1-25)
   if the cToolsSectionNames of stack "revPreferences" is true then
      
      -- added +10 on the line above to give a bit more space between sections (tperry 25-4-24)
      -- tweaking vertical spacing of things a bit here... and other bits (I will refine this)
      if there is a group "graphic" of stack "revTools" then 
         set the top of group "graphic" of stack "revTools" to the top of group "graphic" of stack "revTools" +20
      end if
      if there is a group "graphictoolscontrols" of stack "revTools" then 
         set the top of group "graphictoolscontrols" of stack "revTools" to the top of group "graphictoolscontrols" of stack "revTools" +20
      end if
      if there is a group "graphictools" of stack "revTools" then 
         set the top of group "graphictools" of stack "revTools" to the top of group "graphictools" of stack "revTools" +30
      end if
      if there is a graphic "graphictools" of stack "revTools" then
         set the top of graphic "graphictools" of stack "revTools" to the top of graphic "graphictools" of stack "revTools" +10
      end if
      if there is a group "paintcontrols" of stack "revTools" then 
         set the top of group "paintcontrols" of stack "revTools" to the top of group "paintcontrols" of stack "revTools" +20
      end if
      if there is a group "paint" of stack "revTools" then 
         set the top of group "paint" of stack "revTools" to the top of group "paint" of stack "revTools" +30
      end if
      if there is a graphic "paint" of stack "revTools" then
         set the top of graphic "paint" of stack "revTools" to the top of graphic "paint" of stack "revTools" +10
      end if
      -- fix for vector tools align section (tperry 29-12-24)
      local tVectorSectionHeightAdj
      put 0 into tVectorSectionHeightAdj
      if the revTools_columns of stack "revPreferences" >3 then
         if there is a group "graphictools" then
            if there is a group "graphictoolscontrols" then 
               set the left of group "graphictoolscontrols" to the right of group "graphictools" -6
               set the top of group "graphictoolscontrols" to the top of group "graphictools"
               put the height of group "graphictoolscontrols" into tVectorSectionHeightAdj
            end if
         end if
      end if
      -- create various fields if they don't exist
      put "divHeaderVectorShapes,divHeaderVectorTools,divHeaderPaintTools" into tToolSectionHeaders
      replace "," with return in tToolSectionHeaders
      filter lines of tToolSectionHeaders without empty
      put 0 into tToolSectionCount
      repeat the number of lines in tToolSectionHeaders
         add 1 to tToolSectionCount
         put line tToolSectionCount of tToolSectionHeaders into tFldName
         if not (there is a field tFldName) then create field tFldName
         hide fld tFldName
         set the dontwrap of fld tFldName to true
         set the locktext of fld tFldName to true
         set the Opaque of fld tFldName to false
         set the threeD of fld tFldName to false
         set the showBorder of fld tFldName to false
         set the height of fld tFldName to 23
         set the left of fld tFldName to 0
         set the textSize of fld tFldName to 11
         -- OXT-Beyond: the IDE's muted text (127 was 3.4:1 on the dark palette)
         set the foregroundColor of fld tFldName to revIDEColor("text_muted")
         set the traversalOn of fld tFldName to false
         set the showFocusBorder of fld tFldName to false
         -- conditional positioning
         if there is a graphic "graphic" then
            if tFldName is "divHeaderVectorShapes" then
               set the top of fld tFldName to the bottom of graphic "graphic"
               show fld tFldName
               put "Vector Shapes" into fld tFldName
            end if
         end if
         if there is a graphic "graphictools" then
            if tFldName is "divHeaderVectorTools" then
               set the top of fld tFldName to the bottom of graphic "graphictools"
               show fld tFldName
               put "Vector Tools" into fld tFldName
            end if
         end if
         if there is a graphic "paint" then
            if tFldName is "divHeaderPaintTools" then
               set the top of fld tFldName to the bottom of graphic "paint"
               show fld tFldName
               put "Paint Tools" into fld tFldName
            end if
         end if
      end repeat
   else
      -- section names are hidden (tperry 15-1-25)
      put "divHeaderVectorShapes,divHeaderVectorTools,divHeaderPaintTools" into tToolSectionHeaders
      replace "," with return in tToolSectionHeaders
      filter lines of tToolSectionHeaders without empty
      put 0 into tToolSectionCount
      repeat the number of lines in tToolSectionHeaders
         add 1 to tToolSectionCount
         put line tToolSectionCount of tToolSectionHeaders into tFldName
         if not (there is a field tFldName) then create field tFldName
         hide fld tFldName
      end repeat
   end if -- end conditional section headings (tperry 15-1-25)
   
   -- revTools_show
   put revIDEGetPreference("revTools_show") into tToolsOnShow
   if not (the last char of tToolsOnShow is ",") then put tToolsOnShow & "," into tToolsOnShow
   --tToolsOnShow
   
   
   reset the templatebutton
   set the rect of me to tStackLeft, the top of me, tStackLeft+tStackWidth, tTop + the top of me +10 -- added +10 tperry
   
   ideToolChanged
   --layoutFrame
   
   -- can I delete the widget without causing problems? (yes!)
   if there is a widget "header_background" of cd 1 of this stack then delete widget "header_background" of cd 1 of this stack
   
   -- better make sure we have a way to choose tool options
   ---------------------------------- revised popup menu button
   put "toolsOVERRIDEmenu" into tOverideBtnMenu
   if not(there is a btn tOverideBtnMenu of cd 1 of stack "revTools") then create btn tOverideBtnMenu in cd 1 of stack "revTools"
   set the icon of btn "toolsOVERRIDEmenu" of cd 1 of stack "revTools" to 205209 -- arrow > icon
   set the opaque of btn "toolsOVERRIDEmenu" of cd 1 of stack "revTools" to false
   set the showname of btn "toolsOVERRIDEmenu" of cd 1 of stack "revTools" to false
   set the showborder of btn "toolsOVERRIDEmenu" of cd 1 of stack "revTools" to false
   set the borderWidth of btn "toolsOVERRIDEmenu" of cd 1 of stack "revTools" to 0
   set the label of btn tOverideBtnMenu of cd 1 of stack "revTools" to "*"
   set the width of btn tOverideBtnMenu of cd 1 of stack "revTools" to "24"
   set the height of btn tOverideBtnMenu of cd 1 of stack "revTools" to "24"
   set the topright of btn tOverideBtnMenu of cd 1 of stack "revTools" to the width of stack "revTools",0
   put the long name of stack "revTools" into tLongToolsName
   if word 1 of tLongToolsName is "stack" then delete word 1 of tLongToolsName
   if char 1 of tLongToolsName is QUOTE then delete char 1 of tLongToolsName
   if last char of tLongToolsName is QUOTE then delete last char of tLongToolsName
   set the itemdelimiter to slash
   delete last item of tLongToolsName
   put tLongToolsName into tLongPopupName
   put tLongToolsName & SLASH & "toolsPopupOptions.oxtstack" into tLongPopupName
   set the cSpawnPopup of stack "revTools" to tLongPopupName
   put "on mousedown" & return &¬
   "   put the cSpawnPopup of this stack into tTargStack" & return &¬
   "   if the isViewing of stack tTargStack is true then"  & return &¬
   "   set the isViewing of stack tTargStack to false"  & return &¬
   "   set the blendLevel of stack tTargStack to 100"  & return &¬
   "   close stack tTargStack" & return &¬
"else"  & return &¬
"     set the isViewing of stack tTargStack to true" & return &¬
"   set the blendLevel of stack tTargStack to 1" & return &¬
"   open stack tTargStack" & return &¬
"   end if" & return &¬
"end mousedown" into tScriptToSet
set the script of btn tOverideBtnMenu of cd 1 of stack "revTools" to tScriptToSet
------------------------------ end revised popup menu button

if there is a button "toolsOVERRIDEmenu" of cd 1 of this stack then
   set the topright of btn tOverideBtnMenu of cd 1 of stack "revTools" to the width of stack "revTools",0
end if

--
-- if we adjusted the vertical position of things earlier, pick up on those adjustments now
if tVectorSectionHeightAdj > "0" then
   if there is a graphic "paint" then set the top of graphic "paint" to the top of graphic "paint" - tVectorSectionHeightAdj
   if there is a fld "divHeaderPaintTools" then set the top of fld "divHeaderPaintTools" to the top of fld "divHeaderPaintTools" - tVectorSectionHeightAdj
   if there is a group "paint" then set the top of group "paint" to the top of group "paint" - tVectorSectionHeightAdj
   if there is a group "paintcontrols" then set the top of group "paintcontrols" to the top of group "paintcontrols" - tVectorSectionHeightAdj
   set the height of this wd to the height of this wd - tVectorSectionHeightAdj
   if the revTools_columns of stack "revPreferences" is 8 then
      if there is a group "paintcontrols" then set the top of group "paintcontrols" to the top of group "paint"
      if there is a group "paintcontrols" then set the left of group "paintcontrols" to the right of group "paint" -6
      if the revTools_show of stack "revPreferences" contains "paint" then
         set the height of this wd to the height of this wd - tVectorSectionHeightAdj
      end if
   end if
end if
--

if the platform contains "mac" then hPositionAccentsInTools

unlock messages
unlock screen
end layoutPalette

function objectTypes
   local tData
   put "runedit" into tData[1]["name"]
   put 20 into tData[1]["block size"]
   
   put "widget" into tData[2]["name"]
   put 20 into tData[2]["block size"]
   
   put "classic" into tData[3]["name"]
   put 20 into tData[3]["block size"]
   
   put "graphic" into tData[4]["name"]
   put 10 into tData[4]["block size"]
   
   put "graphictools" into tData[5]["name"]
   put 10 into tData[5]["block size"]
   
   put "graphictoolscontrols" into tData[6]["name"]
   put 10 into tData[6]["block size"]
   
   put "paint" into tData[7]["name"]
   put 10 into tData[7]["block size"]
   
   put "paintcontrols" into tData[8]["name"]
   put 10 into tData[8]["block size"]
   
   return tData
end objectTypes

on mouseDoubleUp
   if the mode of the topStack is not 1 or the cantModify of the topStack then  exit mouseDoubleUp
   if the cType of the target is empty then exit mouseDoubleUp
   if the cTool of the target is not empty then exit mouseDoubleUp
   
   lock screen
   local tObject
   revIDECreateObject the short name of the target, the long ID of the topStack, the loc of this cd of the topStack
   put the result into tObject
   
         
   -- tperry (8/11/23) -- this is where we populate scripts for new objects that are added to the card, by double clicking
   -- (if that option is turned on in the preferences)
   if the cPrePopulateScripts of stack "revpreferences" is true then
      -- this is turned on, so adding script to the new object that has just been created (by double click)
      put tPopulateWithScript(tObject) into tPopulateResult -- store the result (we could do something if unsuccessful here)
   end if
   choose pointer tool
   select tObject
   unlock screen
end mouseDoubleUp

on mouseDown pButton
   if the cType of the target is empty then exit mouseDown
   if the target is disabled then exit mouseDown
   if the cStatus of the target is "error" then
      answer "Widget could not be created because there was an error while loading it. To resolve, please go to the extension manager." 
      exit mouseDown
   end if
   switch the cTool of the target
      case "tool"
         revIDESetTool the cToolName of the target
         break
      case "graphic tool"
         revToolsConfigureTemplateGraphic the cStyle of the target, the cName of the target
         revIDESetTool the cToolName of the target
         break
      case "paint tool"
         local tTool
         put the cToolName of the target into tTool
         revToolsConfigurePaint
         revIDESetTool tTool
         put hCreateSuitableImage (tTool) into tImgCmd
         send tDoImgCmd to me in 1 ticks
         
         -- Set the tool cursor
         -- The tool does not actually work without doing this
         switch tTool
            case "spray tool"
               set the spray to the spray
               break
            case "eraser tool"
               set the eraser to the eraser
               break
            case "brush tool"
               set the brush to the brush
               break
            default
               break
         end switch
         break
      case "option"
         revToolsOptionClicked pButton, the long id of the target
         break
      default
         revIDESetCursor "com.livecode.cursor.grabclose"
         break
   end switch
   if the cTool of the target is not empty then 
      exit mouseDown
   end if
   
   reset the templategraphic
   
   if the tool is not "browse tool" and the tool is not "pointer tool" then 
      choose "pointer" tool
   end if
   
   lock messages
   
   # Wait until the mouse has moved a decent distance
   local tStartLoc
   put the screenMouseLoc into tStartLoc
   repeat -- check for some movement before drag
      local tNowLoc
      put the screenMouseLoc into tNowLoc
      if abs(item 1 of tNowLoc - item 1 of tStartLoc) < 8 then
         if the mouse is up then exit mouseDown
         next repeat
      else
         exit repeat
      end if
   end repeat
   unlock messages
   
   local tTarget, tObjectTypeID, tToolsStackID
   put the long ID of the target into tTarget
   put the short name of the target into tObjectTypeID
   put the long ID of this stack into tToolsStackID
   
   # Generate the drag stack
   if not (there is a stack "revDragControl") then hGenDragStack
   
   # Create a control and Generate a drag image
   
   revIDECreateObject tObjectTypeID, the long ID of card 1 of this stack, "0,0"
   if the result is false then exit mouseDown
   
   local tControlLongID
   put the result into tControlLongID
   
   set the width of this stack to the width of tControlLongID
   set the height of this stack to the height of tControlLongID
   set the topleft of tControlLongID to 0,0
   
   # AL-2015-09-25: [[ Bug 16025 ]] Use the actual created dg rather than snapshot
   if tObjectTypeID is not "com.livecode.interface.classic.datagrid" then
      # Create the image for the windowshape
      set the visible of the templateimage to false
      import snapshot from rect (the rect of tControlLongID) of tControlLongID
      reset the templateimage
      
      set the windowshape of this stack to the ID of image 1
      set the rect of this stack to the rect of image 1
   end if
   unlock messages
   unlock screen
   
   # AL-2015-03-26: [[ Bug 14892 ]] Simply set the visible of the revDragControl stack to true
   set the loc of stack "revDragControl" to the screenmouseloc
   show stack "revDragControl"
   
   # Let the user drag around
   local tValidDropStacks
   local tStackList,tStackName,tStackCount
   put revIDEEditableStacks() into tStackList
   put 1 into tStackCount
   repeat for each line tStackName in tStackList
      if tStackName begins with "revDataViewControl" then next repeat
      if tStackName is "revDragControl" then next repeat
      put the long ID of stack tStackName into tValidDropStacks[tStackCount]["long id"]
      put the rect of stack tStackName into tValidDropStacks[tStackCount]["rect"]
      add 1 to tStackCount
   end repeat
   
   local tTargetStack, tTargetStackIndex, tScreenmouseloc
   repeat while the mouse is down
      // Tickle the event queue to ensure screenmouseloc is always updated
      wait for 0
      put the screenmouseloc into tScreenmouseloc
      set the loc of this stack to tScreenmouseloc
      
      if tTargetStack is empty then
         # Find target to drop onto
         local tStackKeys, tStackID
         repeat with x = 1 to the number of elements in tValidDropStacks
            put tValidDropStacks[x]["long id"] into tStackID
            if tScreenmouseloc is within tValidDropStacks[x]["rect"] then
               put tStackID into tTargetStack
               put x into tTargetStackIndex
               # BB 18/2/2015 [[ Bug 14627 ]] - Part 1 - Removed the old way of highlighting the target stack
               __hiliteAdd tTargetStack
               exit repeat
            end if
         end repeat
      else
         if tScreenmouseloc is not within tValidDropStacks[x]["rect"] then
            put empty into tTargetStack
            put empty into tTargetStackIndex
            __hiliteRemove
         end if
      end if
   end repeat
   
   # Change the cursor back
   revIDEResetCursor
   
   local tDropScreenLocation
   put the screenmouseloc into tDropScreenLocation
   
   # BB 18/2/2015 [[ Bug 14627 ]] - Removed the old way of unhighlighting all stacks and replaced with targetting a single stack
   # Clear any hilites
   __hiliteRemove
   
   # Delete the drag stack
   if there is a stack "revDragControl" then 
      delete stack "revDragControl"
   end if
   
   unlock messages
   
   # Check if mouse up occurred over a valid drop stack
   local tLeft, tTop, tCreateObjectID
   repeat with x = 1 to the number of elements in tValidDropStacks
      if tDropScreenLocation is within tValidDropStacks[x]["rect"] then
         put item 1 of tDropScreenLocation - item 1 of tValidDropStacks[x]["rect"] into tLeft
         put item 2 of tDropScreenLocation - item 2 of tValidDropStacks[x]["rect"] into tTop
         
         set the defaultstack to tValidDropStacks[x]["long id"]
         revIDECreateObject tObjectTypeID, tValidDropStacks[x]["long id"], tLeft & comma & tTop
         put the result into tCreateObjectID
         set the defaultstack to tToolsStackID
         revIDESetTool "pointer"
         select tCreateObjectID    
         
         -- this flat rectangle graphic doesn't seem to have an NS styles equivalent in MacOS
         -- we use a kind of hybrid approach of HIToolbox and NSStyles on MacOS
         if the platform contains "mac" then
            if the style of tCreateObjectID is "Rectangle" then
               set the threeD of tCreateObjectID to false
               set the borderWidth of tCreateObjectID to 1
               set the borderColor of tCreateObjectID to "137,137,137"
            end if
         end if
         
         -- tperry (8/11/23) -- this is where we populate scripts for new objects that are added to the card, by dragging
         -- (if that option is turned on in the preferences)
         if the cPrePopulateScripts of stack "revpreferences" is true then
            -- this is turned on, so adding script to the new object that has just been created (by double click)
            put tPopulateWithScript(tCreateObjectID) into tPopulateResult -- store the result (we could do something if unsuccessful here)
         end if
         
         exit repeat 
      end if
   end repeat
end mouseDown

on mouseEnter
   if not (the pendingmessages contains "hConditionalDataGrid") then
      if the cDisableDataGrid of stack "revPreferences" is true then
         send hConditionalDataGrid to stack "revMenubar" in 1 ticks
      end if
   end if
   --
   if the cType of the target is empty then exit mouseEnter
   if the cDisabled of the target is true then exit mouseEnter
   if word 1 of the target is "widget" then
      revIDESetCursor "com.livecode.cursor.grab"
      -- finally, found where the widgets get their hover colour from (tperry)
      set the foregroundColor of the target to (the cToolSelectorColor of stack "revPreferences") -- was revIDEColor("edition_color")
   else if the cTool of the target is empty and the cStatus of the target is not "error" then 
      # We are hovering over a draggable item
      revIDESetCursor "com.livecode.cursor.grab"
      set the coloroverlay["opacity"] of the target to "100" -- was 50 (tperry)
      set the coloroverlay["color"] of the target to "0,0,0"
   else if the cStatus of the target is "error" then
      # Not working on windows.. get the egg timer so disabling for now
      --revIDESetCursor "help"
   else if the cTool of the target is not empty then
      # We are hovering over a tool
      set the loc of graphic "tool_hover" of group "contents" to the loc of the target
      show graphic "tool_hover" of group "contents" 
   end if
end mouseEnter

on mouseLeave
   if the cDisabled of the target is true then exit mouseLeave
   try
      if word 1 of the target is "widget" then
         -- widget icons should be easier to see in dark mode
         set the foregroundColor of the target to revIDEColor("palette_icon")
      else
         hide graphic "tool_hover" of group "contents" 
         if the cTool of the target is empty then
            set the coloroverlay of the target to empty
         end if
      end if
   end try
   revIDEResetCursor
end mouseLeave

on dragEnter
   set the dragAction to "copy"
end dragEnter

on dragDrop
   revIDEInstallExtension the dragData["files"]
end dragDrop

local sHighlightedCard, sOldBGColor, sOldBGPattern
private on __hiliteAdd pStackLongID
   lock screen
   lock messages
   # Store the new card being hilited
   local tCardID
   put the long id of this card of pStackLongID into tCardID
   
   if tCardID is sHighlightedCard then 
      exit __hiliteAdd
   end if
   
   # Remove previous hilite
   if sHighlightedCard is not empty then
      __hiliteRemove
   end if
   
   put tCardID into sHighlightedCard
   put the backcolor of tCardID into sOldBGColor
   put the backPattern of tCardID into sOldBGPattern
   -- the colour the card changes when you drag in a control from the tools palette (tperry)
   set the backgroundcolor of tCardID to "125,125,125" -- was: revIDEColor("edition_color")
   
   unlock messages
   unlock screen
end __hiliteAdd

private on __hiliteRemove
   if not exists(sHighlightedCard) then 
      exit __hiliteRemove
   end if
   
   lock messages
   if sOldBGPattern is not empty then
      set the backpattern of sHighlightedCard to sOldBGPattern
   else
      set the backcolor of sHighlightedCard to sOldBGColor
   end if
   put empty into sHighlightedCard
   put empty into sOldBGColor
   put empty into sOldBGPattern
   unlock messages
end __hiliteRemove

on isolateTool pWhich
   lock screen
   disableTools
   toolEnable pWhich
   unlock screen
end isolateTool

on enableTools
   lock screen
   repeat for each item tItem in "widget,classic,graphic,graphictools,paint"
      groupDisable tItem, false
   end repeat
   toolEnable "com.livecode.tool.Browse" 
   toolEnable "com.livecode.tool.Pointer"
   unlock screen
end enableTools

on disableTools
   lock screen
   repeat for each item tItem in "widget,classic,graphic,graphictools,paint"
      groupDisable tItem, true
   end repeat
   toolDisable "com.livecode.tool.Browse" 
   toolDisable "com.livecode.tool.Pointer"
   unlock screen
end disableTools

on groupDisable pWhich, pDisable
   lock screen
   local tTools
   switch pWhich
      case "widget"
         put revIDEWidgets() into tTools
         break
      case "classic"
         put revIDEClassicControls() into tTools
         break
      case "graphic"
         put revIDEGraphics() into tTools
         break 
      case "graphictools"
         put revIDEGraphicTools() into tTools
         break 
      case "paint"
         put revIDEPaintTools() into tTools
         break
   end switch
   
   repeat for each key tKey in tTools
      if pDisable then
         toolDisable tKey
      else
         toolEnable tKey
      end if
   end repeat
   unlock screen
end groupDisable

on toolDisable pWhich
   local tIsButton
   if there is a button pWhich of me  then
      put true into tIsButton
   else if there is a widget pWhich of me then
      put false into tIsButton
   else
      exit toolDisable
   end if
   
   if tIsButton then
      set the coloroverlay["opacity"] of button pWhich of me to "90"
      set the coloroverlay["color"] of  button pWhich of me to "255,255,255"
      set the cDisabled of button pWhich of me to true
      disable button pWhich of me
   else
      set the cDisabled of widget pWhich of me to true
      set the foregroundColor of widget pWhich of me to revIDEColor("palette_icon_disabled")
   end if
end toolDisable

on toolEnable pWhich
   local tIsButton
   if there is a button pWhich of me  then
      put true into tIsButton
   else if there is a widget pWhich of me then
      put false into tIsButton
   else
      throw "Invalid tool type" && pWhich
   end if
   if tIsButton then
      set the coloroverlay of button pWhich of me to empty
      set the cDisabled of button pWhich of me to false
      enable button pWhich of me
   else
      set the cDisabled of widget pWhich of me to false
      set the foregroundColor of widget pWhich of me to revIDEColor("palette_icon")
   end if
end toolEnable

function absoluteRectOfObject pObject
   local tRect, tTool
   put toolObjectName(pObject) into tTool
   
   if there is a button tTool of me then
      put the rect of button tTool into tRect
   else if there is a widget tTool of me then
      put the rect of widget tTool into tRect
   end if
   return revIDERelativeRectToAbsolute(tRect, me)
end absoluteRectOfObject

on highlightObject pObject
   local tTool
   put toolObjectName(pObject) into tTool
   isolateTool tTool
end highlightObject

function toolObjectName pTool
   local tTool
   switch pTool
      case "Run Mode"
         put "com.livecode.tool.Browse" into tTool
         break
      case "Edit Mode"
         put "com.livecode.tool.Pointer" into tTool
         break
      case "Create Data Grid"
         put "com.livecode.interface.classic.DataGrid" into tTool
         break
      case "Create Label Field"
         put "com.livecode.interface.classic.LabelField" into tTool
         break
      case "Create Button"
         put "com.livecode.interface.classic.Button" into tTool
         break
      case "Create Text Area"
         put "com.livecode.interface.classic.TextArea" into tTool
         break
      case "Create Field"
         put "com.livecode.interface.classic.Field" into tTool
         break
      case "Create Combo Box"
         put "com.livecode.interface.classic.ComboBox" into tTool
         break
      case "Create Option Menu"
         put "com.livecode.interface.classic.OptionMenu" into tTool
         break
      case "Create Popup Menu"
         put "com.livecode.interface.classic.PopupMenu" into tTool
         break
      case "Create Radio Button"
         put "com.livecode.interface.classic.RadioButton" into tTool
         break
      case "Create Image"
         put "com.livecode.interface.classic.Image" into tTool
         break
      case "Create Rectangle Button"
         put "com.livecode.interface.classic.RectangleButton" into tTool
         break
      case "Create Slider"
         put "com.livecode.interface.classic.Slider" into tTool
         break
      case "Create Default Button"
         put "com.livecode.interface.classic.DefaultButton" into tTool
         break
      case "Create Scrollbar"
         put "com.livecode.interface.classic.Scrollbar" into tTool
         break
      case "Create Little Arrows"
         put "com.livecode.interface.classic.LittleArrows" into tTool
         break
      case "Create Tab Panel"
         put "com.livecode.interface.classic.TabPanel" into tTool
         break
      case "Create Checkbox"
         put "com.livecode.interface.classic.Checkbox" into tTool
         break
      case "Create Pulldown Menu"
         put "com.livecode.interface.classic.PulldownMenu" into tTool
         break
      case "Create Player"
         put "com.livecode.interface.classic.Player" into tTool
         break
      case "Create Table Field"
         put "com.livecode.interface.classic.TableField" into tTool
         break
      case "Create List Field"
         put "com.livecode.interface.classic.ListField" into tTool
         break
      case "Create Progress Bar"
         put "com.livecode.interface.classic.ProgressBar" into tTool
         break
      case "Create Regular Graphic"
         put "com.livecode.interface.classic.RegularGraphic" into tTool
         break
      case "Create Oval Graphic"
         put "com.livecode.interface.classic.OvalGraphic" into tTool
         break
      case "Create Round Rect Graphic"
         put "com.livecode.interface.classic.RoundRectGraphic" into tTool
         break
      case "Create Rectangle Graphic"
         put "com.livecode.interface.classic.RectangleGraphic" into tTool
         break
      case "Create Line Graphic"
         put "com.livecode.interface.classic.LineGraphic" into tTool
         break
      default
         # Try and resolve as a reference to a widget creation tool
         if word 1 of pTool is "Create" then
            return word 2 of pTool
         end if
   end switch
   return tTool
end toolObjectName

local sToolColors, sLineSizes, sBrushes, sPolygon, sPolygonSides

on revToolsOptionClicked pButton, pTarget
   local tToolName, tSection
   put the cToolName of the target into tToolName
   put segment 1 of tToolName into tSection
   
   switch tToolName
      case "paint fill color tool"
      case "paint line color tool"
         # Popup the system color dialog (this for the paint, not graphics)
         answer color with sToolColors[tToolName] -- this pops up the system colour select dialog
         -- richmond had talked about possibly replacing this with the old "revcolorchooser.rev"
         if the result is not "Cancel" then
            put it into sToolColors[tToolName]
            # We use a color overlay with the multiply blend mode
            # to just change the white part of the icon to the target color
            set the colorOverlay["color"] of pTarget to sToolColors[tToolName]
            set the colorOverlay["blendMode"] of pTarget to "multiply"
         end if
         break
      case "graphic fill color tool"
      case "graphic line color tool"
         # Popup the system color dialog (this for graphics, not paint)
         answer color with sToolColors[tToolName] -- this pops up the system colour select dialog
         -- richmond had talked about possibly replacing this with the old "revcolorchooser.rev"
         if the result is not "Cancel" then
            if tToolName is "graphic line color tool" then set the tNewGraphicLineCol of this card to it
            if tToolName is "graphic fill color tool" then set the tNewGraphicFillCol of this card to it
            put it into tNewCol
            put it into sToolColors[tToolName]
            # We use a color overlay with the multiply blend mode
            # to just change the white part of the icon to the target color
            set the colorOverlay["color"] of pTarget to sToolColors[tToolName]
            set the colorOverlay["blendMode"] of pTarget to "multiply"
            -- now check if there's a selection or not
            put the selectedObject into tSelObj
            if tSelObj is empty then
               -- no selected object
               revToolsConfigureTemplateGraphicProperties
            else
               -- we have a selection
               if word 1 of tSelObj is "graphic" then -- make sure it's a graphic
                  -- put tSelObj into cd fld "debug" of stack "untitled 1" -- debug
                  if tToolName is "graphic line color tool" then
                     -- we are setting line colour
                     put "set the foregroundColor of " & tSelObj & " to " & tNewCol into tLineColCmd
                     --put tLineColCmd into cd fld "debug" of stack "untitled 1" -- debug out
                     do tLineColCmd
                  end if
                  if tToolName is "graphic fill color tool" then
                     -- we are setting fill colour
                     put "set the backgroundColor of " & tSelObj & " to " & tNewCol into tLineColCmd
                     --put tLineColCmd into cd fld "debug" of stack "untitled 1" -- debug out
                     do tLineColCmd
                  end if
                  --
               end if
            end if
            --
         end if
         break
      case "paint line size tool"
      case "graphic line size tool"
         revToolsPopupLineSizeMenu tToolName
         break
      case "paint polygon shape tool"
         revToolsPopupPolygonMenu tToolName
         break
      case "paint polygon sides tool"
         revToolsPopupPolygonSidesMenu tToolName
         break
      case "paint polygon radius tool"
         revToolsPopupRadiusMenu tToolName
         break
      case "paint brush pattern tool"
         local tBrush, tTool
         put the tool into tTool
         switch tTool
            case "eraser tool"
               put the eraser into tBrush
               break
            case "spray tool"
               put the spray into tBrush
               break
            case "brush tool"
               put the brush into tBrush
               break
         end switch
         # revBrushpopup presents the brush image options
         set the cBrushShape of stack "revBrushpopup" to tBrush
         set the foregroundColor of graphic "marquee" of card 1 of stack "revBrushPopup" to the cToolSelectorColor of stack "revPreferences"
         modal stack "revBrushpopup" -- this doesn't work on linux
         put the cBrushShape of stack "revBrushpopup" into sBrushes[tTool]
         break
   end switch
   
   if tSection is "graphic" then
      revToolsConfigureTemplateGraphicProperties
   else if tSection is "paint" then
      revToolsConfigurePaint
   end if
end revToolsOptionClicked

-- tperry 23-4-24 (this is to fix a bug where brush size doesn't stick)
on reAffirmBrushChoice
   put the cBrushShape of stack "revBrushpopup" into tBrushSizeToSet
   if tBrushSizeToSet is empty then put "1" into tBrushSizeToSet
   if isNumber(tBrushSizeToSet) is false then put "1" into tBrushSizeToSet
   --
   -- make sure the cursor gets set properly!
   -- (done with a mousemove handler in the "brushes card" of stack "revBrushPopup")
   set the penWidth to tBrushSizeToSet
   set the brush to tBrushSizeToSet
end reAffirmBrushChoice


local sPicksA
on menuPick pWhich
   -- don't need this, so deleted. (tperry 25-4-24)
end menuPick

private command setChecked pTarget, pChecked
   
   local tText
   put the text of pTarget into tText
   replace "!c" with empty in tText
   put "!c" before line lineOffset(pChecked,tText) of tText
   set the text of pTarget to tText
   
end setChecked

constant kLineSizeMenu = "None\n1\n2\n3\n4\n6\n8\n10\n-\nOther..."
constant kPolygonSidesMenu = "3\n4\n5\n6\n7\n8\n9\n10\n-\nOther..."
constant kPolygonRadiusMenu = "0\n2\n4\n6\n8\n10\n12\n14\n16\n-\nOther..."

on revToolsPopupLineSizeMenu pTarget
   set the cChosenTool of this card to pTarget -- store tool in card props
   if there is a fld "debug" of stack "untitled 1" then
      put pTarget into cd fld "debug" of stack "Untitled 1"
   end if
   revToolsPopupMenu "lineSizeMenu", pTarget, kLineSizeMenu, 1
end revToolsPopupLineSizeMenu

on revToolsPopupPolygonMenu pTarget
   if there is a fld "debug" of stack "untitled 1" then
      put pTarget into cd fld "debug" of stack "Untitled 1"
   end if
   revToolsPopupMenu "polygonMenu", pTarget, kPolygonMenu, "Line Tool"
end revToolsPopupPolygonMenu

on revToolsPopupPolygonSidesMenu pTarget
   if there is a fld "debug" of stack "untitled 1" then
      put pTarget into cd fld "debug" of stack "Untitled 1"
   end if
   revToolsPopupMenu "polygonSidesMenu", pTarget, kPolygonSidesMenu, 4
end revToolsPopupPolygonSidesMenu

-- restoring the ability to set a radius on the roundRect paint tool
on revToolsPopupRadiusMenu pTarget
   if there is a fld "debug" of stack "untitled 1" then
      put pTarget into cd fld "debug" of stack "Untitled 1"
   end if
   set the cChosenTool of this card to pTarget -- store tool in card props
   revToolsPopupMenu "polygonRadiusMenu", pTarget, kPolygonRadiusMenu, 4
end revToolsPopupRadiusMenu

# Generic popup menu creation
on revToolsPopupMenu pButtonName, pTool, pMenuText, pDefault
   -- tperry, rewriting all this 24-4-24
   
   local tLongID
   if there is a button pButtonName of me then delete button pButtonName of me -- delete the menu if it exists (tperry)
   if there is not a button pButtonName of me then
      set the style of the templatebutton to "menu"
      set the menumode of the templatebutton to "popup"
      set the visible of the templatebutton to false
      local tText
      put pMenuText into tText
      replace "\n" with return in tText
      create button pButtonName
      set the rect of it to -10,-10,-5,-5
      set the text of button pButtonName to tText
      reset the templatebutton
   end if
   
   -- conditional script setting
   set the script of button pButtonName of me to ¬
   "on menuPick" & return &¬
   "put the menuhistory of me into tChosenOption" & return &¬
   "--put tChosenOption" & return &¬
   "set the cPopupBtnName of this card to the short name of me" & return & ¬
   "set the cPopupBtnID of this card to the ID of me" & return & ¬
   "set the cChosenPopupLine of this card to tChosenOption" & QUOTE & return &¬
   "set the cChosenPopupItem of this card to (line tChosenOption of the text of me)" & QUOTE & return &¬
   "send hApplyThePopupSelection to stack " & QUOTE & "revTools" & QUOTE & return &¬
   "end menuPick"
   
   put the long id of button pButtonName of me into tLongID
   set the cName of tLongID to pTool
   put the cChosenPopupItem of this card into tChosenOption
   put the cChosenPopupLine of this card into tChosenPopupLine
   put the text of btn pButtonName into tPopupItems
   
   
   -- I've left the checkmarks out on purpose, (as I don't like them). Could put them back in if people ask
   --put "!c" & line tChosenPopupLine of tPopupItems into line tChosenPopupLine of tPopupItems
   --set the text of btn pButtonName to tPopupItems
   
   popup tLongID
end revToolsPopupMenu

on hApplyThePopupSelection
   -- actually apply what the user has chosen in the popup menu (tperry 25-4-24)
   put the cPopupBtnName of this card into tPopupBtnName
   put the cPopupBtnID of this card into tPopupBtnID
   put the cChosenPopupLine of this card into tChosenPopupLine
   put the cChosenPopupItem of this card into tChosenPopupItem
   put the cChosenTool of this card into tChosenTool
   replace "!c" with "" in tPopupBtnID
   replace "!c" with "" in tChosenPopupLine
   replace "!c" with "" in tChosenPopupItem
   -- output a debug
   -- make a new stack, called "untitled 1" and place a field called "debug" on it to see the following output
   if there is a fld "debug" of stack "untitled 1" then
      put "name: " & tPopupBtnName & return & tPopupBtnID & return & tChosenPopupLine & return & tChosenPopupItem & return & "Tool: " & tChosenTool into fld "debug" of stack "untitled 1"
      if the shiftkey is down then
         answer "name: " & tPopupBtnName & return & tPopupBtnID & return & tChosenPopupLine & return & tChosenPopupItem & return & "Tool: " & tChosenTool into fld "debug" of stack "untitled 1"
      end if
   end if
   -- choose the tool in the polygon menu
   if tChosenPopupItem is "Rectangle Tool" then
      choose Rectangle Tool
      exit hApplyThePopupSelection
   end if
   if tChosenPopupItem is "Rounded Rectangle Tool" then
      choose Rounded Rectangle Tool
      exit hApplyThePopupSelection
   end if
   if tChosenPopupItem is "Oval Tool" then
      choose Oval Tool
      exit hApplyThePopupSelection
   end if
   if tChosenPopupItem is "Regular Polygon Tool" then
      choose Regular Polygon Tool
      exit hApplyThePopupSelection
   end if
   if tChosenPopupItem is "Polygon Tool" then
      choose Polygon Tool
      exit hApplyThePopupSelection
   end if
   if tChosenPopupItem is "Line Tool" then
      choose Line Tool
      exit hApplyThePopupSelection
   end if
   if tChosenTool is "paint line size tool" then
      -- set line size for paint objects
      put tChosenPopupItem into tLineSizeToSet
      if tLineSizeToSet is "none" then put "0" into tLineSizeToSet
      if tLineSizeToSet contains "other" then
         ask "Please specify line size:" with the lineSize
         put it into tInputCheck
         if isNumber(tInputCheck) is false then exit hApplyThePopupSelection -- not a number!
         if tInputCheck > 32767 then exit hApplyThePopupSelection -- larger than maximum allowed value
         if tInputCheck < 0 then exit hApplyThePopupSelection -- smaller than minimum allowed value
         put tInputCheck into tLineSizeToSet
      end if
      set the tNewPaintLineSize of this card to tLineSizeToSet
      set the lineSize to tLineSizeToSet
      exit hApplyThePopupSelection
   end if
   if tChosenTool is "graphic line size tool" then
      -- we apply the line size to vector graphics
      put tChosenPopupItem into tLineSizeToSet
      if tLineSizeToSet contains "other" then
         ask "Please specify line size:" with the lineSize
         put it into tInputCheck
         if isNumber(tInputCheck) is false then exit hApplyThePopupSelection -- not a number!
         if tInputCheck > 32767 then exit hApplyThePopupSelection -- larger than maximum allowed value
         if tInputCheck < 0 then exit hApplyThePopupSelection -- smaller than minimum allowed value
         put tInputCheck into tLineSizeToSet
      end if
      -- now we check for any selected graphics to apply line size to
      put the selectedObject into tSelObj
      if tSelObj is empty then
         -- no selected object
         put false into cLineConErrors -- test for errors
         if isNumber(tLineSizeToSet) is false then put true into cLineConErrors -- not a number!
         if tLineSizeToSet < 0 then put true into cLineConErrors -- smaller than minimum allowed value
         if cLineConErrors is true then put "1" into tLineSizeToSet -- set default if was invalid
         set the tNewGraphicLineSize of card 1 of stack "revTools" to tLineSizeToSet
      else
         put false into cLineConErrors -- test for errors
         if isNumber(tLineSizeToSet) is false then put true into cLineConErrors -- not a number!
         if tLineSizeToSet < 0 then put true into cLineConErrors -- smaller than minimum allowed value
         if cLineConErrors is true then put "1" into tLineSizeToSet -- set default if was invalid
         put "set the linesize of " & tSelObj & " to " & tLineSizeToSet into tLineCmd
         -- put tLineCmd into cd fld "debug" of stack "untitled 1" -- debug out
         do tLineCmd
      end if
      -- see handler revToolsConfigureTemplateGraphicProperties
   end if
   if tPopupBtnName is "polygonSidesMenu" then
      -- we set polygon sides here (min 3)
      put tChosenPopupItem into tPolySidesToSet
      if tPolySidesToSet contains "other" then
         ask "Please specify number of polygon sides:" with the polySides
         put it into tInputCheck
         if isNumber(tInputCheck) is false then exit hApplyThePopupSelection -- not a number!
         if tInputCheck > 1000 then exit hApplyThePopupSelection -- larger than maximum allowed value
         if tInputCheck < 3 then exit hApplyThePopupSelection -- smaller than minimum allowed value
         put tInputCheck into tPolySidesToSet
      end if
      -- tperry 13-8-24 - fix bug setting correct number of polygon sides
      set the polySides to tPolySidesToSet
      repeat 2
         choose regular polygon tool
         set the polySides to tPolySidesToSet
      end repeat
      set the tPassVar of this stack to tPolySidesToSet
      send tDelayedPolysides to me in 3 ticks
   end if
   -- here we set radius of roundrect paint tool (tperry 14-8-2024)
   if tPopupBtnName contains "RadiusMenu" then
      -- we set roundRect radius here (for paint tool)
      put tChosenPopupItem into tRRectRadiusToSet
      if tRRectRadiusToSet contains "other" then
         ask "Please specify radius in pixels (max 400):" with the roundRadius
         put it into tInputCheck
         if isNumber(tInputCheck) is false then exit hApplyThePopupSelection -- not a number!
         if tInputCheck > 400 then exit hApplyThePopupSelection -- larger than maximum allowed value
         if tInputCheck < 3 then exit hApplyThePopupSelection -- smaller than minimum allowed value
         put tInputCheck into tRRectRadiusToSet
      end if
      repeat 2
         choose rounded rectangle tool
         set the roundRadius to tRRectRadiusToSet
      end repeat
   end if
end hApplyThePopupSelection

on revToolsConfigureTemplateGraphic pStyle, pName
   # Make sure the template graphic has the properties selected in the tools palette
   --reset the templategraphic
   if pStyle is not empty then
      set the style of the templategraphic to pStyle
   end if
   if pName is not empty then
      set the name of the templategraphic to pName
   end if
   revToolsConfigureTemplateGraphicProperties
end revToolsConfigureTemplateGraphic

on revToolsConfigureTemplateGraphicProperties
   -- set properties for unselected template graphics
   put the tNewGraphicLineSize of card 1 of stack "revTools" into tLineSizeToSet
   if tLineSizeToSet is "" then put "1" into tLineSizeToSet -- set default to 1 if not set
   set the lineSize of the templategraphic to tLineSizeToSet
   
   put the tNewGraphicLineCol of card 1 of stack "revTools" into tLineColToSet
   if tLineColToSet is "" then put "175,175,175" into tLineColToSet -- set default to neutral grey
   set the foregroundColor of the templategraphic to tLineColToSet
   
   put the tNewGraphicFillCol of card 1 of stack "revTools" into tFillColToSet
   if tFillColToSet is "" then put "120,120,120" into tFillColToSet -- set default to light grey
   set the backgroundColor of the templategraphic to tFillColToSet
   
   -- we are assuming it should be filled
   set the opaque of the templategraphic to true
end revToolsConfigureTemplateGraphicProperties

on revToolsConfigurePaint
   # Make sure the paint properties are those selected in the tools palette
   set the penColor to sToolColors["paint line color tool"]
   set the brushColor to sToolColors["paint fill color tool"]
   set the polysides to sPolygonSides["paint polygon shape tool"] -- tperry 24-4-24 (fixed)
   
   local tTool
   put the tool into tTool
   if there is a fld "debug" of stack "untitled 1" then put tTool into fld "debug" of stack "untitled 1"
   if sBrushes[tTool] is not empty then
      switch tTool
         case "eraser tool"
            set the eraser to sBrushes[tTool]
            break
         case "spray tool"
            set the spray to sBrushes[tTool]
            break
         case "brush tool"
            set the brush to sBrushes[tTool]
            break
      end switch      
   end if
end revToolsConfigurePaint

on revToolsConfigurePolygon pTool
   if the tool is "regular polygon tool" and sPolygonSides[pTool] is not empty then
      set the polysides to sPolygonSides[pTool]
   end if
   revToolsConfigurePaint
end revToolsConfigurePolygon

on moveStack
   ideSetWindowBoundingRect
   pass moveStack
end moveStack

function tPopulateWithScript tNewObject
   set the itemdelimiter to "/"
   put "" into tNewObjectStyle
   put "" into tShortScriptFN
   delete the last item of tToolsPath
   -- conditional, depending on what is added
   put word 1 of tNewObject into tNewObjectType
   if tNewObjectType is "button" then -- work out what the script snippet path would be
      put "put the style of " & tNewObject & " into tNewObjectStyle" into tStyleFind
      do tStyleFind
      if word 1 of the short name of tNewObject is "option" then put "optionmenu" into tNewObjectStyle
      if word 1 of the short name of tNewObject is "pulldown" then put "pulldownmenu" into tNewObjectStyle
      if word 1 of the short name of tNewObject is "combobox" then put "combobox" into tNewObjectStyle
      put tNewObjectStyle & "_" & tNewObjectType into tShortScriptFN
   end if
   if tNewObjectType is "field" then -- work out what the script snippet path would be
      put "put word 1 of the short name of " & tNewObject & " into tNewObjectStyle" into tStyleFind
      do tStyleFind
      if the vScrollbar of tNewObject is true then 
         put "scrollingfield" into tNewObjectStyle
         if the lockText of tNewObject is true then
            put "scrollinglistfield" into tNewObjectStyle
            if word 1 of the short name of tNewObject is "table" then put "table" into tNewObjectStyle
         end if
      end if
      put tNewObjectStyle & "_" & tNewObjectType into tShortScriptFN
   end if
   if tNewObject contains "group" then
      put word 1 of the short name of  tNewObject  into tNewObjectStyle
      if tNewObjectStyle contains "datagrid" then put  "datagrid" & "_" & tNewObjectType into tShortScriptFN
   end if
   if tNewObjectType is "scrollbar" then -- scrollbars
      put word 1 of the short name of tNewObject & "_" & tNewObjectType into tShortScriptFN
   end if
   if word 1 of tNewObject is "image" then put "image"  into tShortScriptFN
   if word 1 of tNewObject is "player" then exit tPopulateWithScript -- player is broken as far as I'm concerned
   if word 1 of tNewObject is "graphic" then 
      put "graphic"  into tShortScriptFN
      send mouseup to tNewObject in 5 ticks -- send the mouseup message to the new graphic, but give it a few moments for the graphic to have it's script populated.
   end if
   
   put toLower(tShortScriptFN) into tShortScriptFN -- make sure it's always lowercase, as MacOS and Linux are case sensitive File systems
   -- set the script
   -- changed this, so instead of loading from files, it loads from stored custom properties instead (tperry 17-4-24)
   put the tShortScriptFN of btn "prePopulateScripts" of cd "Dictionary" of stack "revPreferencesGUI" into tScriptData
   if tScriptData is not "" then
      set the script of  tNewObject to tScriptData
   else
      -- snippet does not exist
      put "please create a snippet for: '" & tLongScriptFN & "'" -- note to user, for what snippet is missing
   end if
end tPopulateWithScript

function hCreateSuitableImage tTool
   -- bug found (tperry, richmond62, & micmac 22-4-24)
   --put "the tool is: " & tTool -- debug (tperry 22-4-24)
   put the short name of the topStack into tTheCurrentStackName
   put the last word of the currentcard of stack tTheCurrentStackName into tCardID
   put the number of images of card id tCardID of stack tTheCurrentStackName into tImgCount
   put "suitable-paintimage" into tNewPaintName
   --
   if there is an image (tNewPaintName) of card id tCardID of stack tTheCurrentStackName then
      set the tNewImgCmd of stack "revTools" to ""
      return true
      exit hCreateSuitableImage
   else
      -- no suitable images on the card
      put "create image " & QUOTE & (tNewPaintName) & QUOTE & " in card id " & tCardID & " of stack " & QUOTE & tTheCurrentStackName & QUOTE into tSuitableImageSetup
      set the tNewImgCmd of stack "revTools" to tSuitableImageSetup
      return false
   end if
end hCreateSuitableImage

on tDoImgCmd -- handler to actually create the paint image we are missing (tperry 22-4-24)
   if tImgCmd is true then exit tDoImgCmd
   if the tNewImgCmd of stack "revTools" is "" then exit tDoImgCmd
   put the tNewImgCmd of stack "revTools" into tImgCmd
   do tImgCmd
   replace QUOTE with return in tImgCmd
   delete line 1 of tImgCmd
   put word 4 of line 2 of tImgCmd into line 2 of tImgCmd
   -- 
   put line 1 of tImgCmd into tImgName
   put line 2 of tImgCmd into tImgID
   put line 3 of tImgCmd into tImgStack
   --
   set the rect of image tImgName of card id tImgID of stack tImgStack to 0,0,the width of stack tImgStack, the height of stack tImgStack
   set the layer of image tImgName of card id tImgID of stack tImgStack to bottom -- just to make sure it doesn't obscure any buttons (tperry 23-4-24)
end tDoImgCmd


on initPaintCol
   -- default paint colours for when the IDE starts
   put 150,150,150 into sToolColors["paint fill color tool"]
   put 150,150,150 into sToolColors["paint line color tool"]
end initPaintCol


on tAdjWdRounding theStack
   if theStack is empty then exit tAdjWdRounding
   set the itemdelimiter to ","
   put "visArea,knockoutArea" into tRectsList -- specify rectangle graphics I want to make
   put theStack into sMatchStack -- this is the stack we are interested in
   if there is a stack sMatchStack then 
      put "_wdshape_" into tWdGrp
      if not(there is a group tWdGrp of cd 1 of stack sMatchStack) then create group tWdGrp in cd 1 of stack sMatchStack
      put 0 into tCount
      repeat the number of items in tRectsList -- make the rectangle graphics specified above
         add 1 to tCount
         put item tCount of tRectsList into tGra
         if not (there is a graphic tGra of group tWdGrp of card 1 of stack sMatchStack) then create graphic tGra in group tWdGrp of card 1 of stack sMatchStack -- ensure it exists, now set props
         set the opaque of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to true
         set the antialiased of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to false
         set the lineSize of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to 0
         set the backgroundcolor of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to none
         set the width of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to the width of stack sMatchStack
         set the height of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to the height of stack sMatchStack
         set the top of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to 0
         set the left of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to 0
         set the style of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to "roundRect"
         set the roundRadius of graphic tGra of group tWdGrp of cd 1 of stack sMatchStack to 14
      end repeat
      -- set properties of the group
      set the layer of group tWdGrp of cd 1 of stack sMatchStack to top
      set the margins of group tWdGrp of cd 1 of stack sMatchStack to 0
      set the topleft of group tWdGrp of cd 1 of stack sMatchStack to 0,0
      --
      set the decorations of stack sMatchStack to none -- now hide the normal window decorations
      --set the top of stack sMatchStack to the bottom of stack "revMenubar" +4 -- keep stack anchored to bottom of revmenubar
      -- we need to provide a way for the window to be dragged now, so prepare the drag script
      put "local sgDragging, sgLeftOffset, sgTopOffset" & return & "on mousedown" & return & "put item 1 of the mouseLoc into sgLeftOffset" & return & ¬
      "put item 2 of the mouseLoc into sgTopOffset" & return & "put true into sgDragging" & return &  ¬
      "if not (the pendingmessages contains " & QUOTE & "tDragMove" & QUOTE & ") then send tDragMove to me in 1 millisecond" & return &¬
      "end mousedown" & return & ¬ 
      "on tDragMove" & return & "lock screen" & return & "if sgDragging is true then" & return & "set the left of this stack to item 1 of globalloc(the mouseLoc) - sgLeftOffset" & return &¬
      "set the top of this stack to item 2 of globalloc(the mouseLoc) - sgTopOffset " & return & "end if"  & return & "unlock screen" & return & "if the mouse is up then" & return & ¬
      "put false into sgDragging" & return & "else" & return & "send tDragMove to me in 1 millisecond" & return & "end if" & return & "end tDragMove" into tDragScript
      -- now make the button that allows the drag
      if not (there  is a button "test-drag" of group tWdGrp of cd 1 of stack sMatchStack) then create button "test-drag" in group tWdGrp of cd 1 of stack sMatchStack
      -- set props of drag button
      set the autohilite of button "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to false
      set the script of button "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to tDragScript
      set the opaque of btn "test-drag"  of group tWdGrp of cd 1 of stack sMatchStack to false
      set the style of btn "test-drag"  of group tWdGrp of cd 1 of stack sMatchStack to "transparent"
      set the threeD of btn "test-drag"  of group tWdGrp of cd 1 of stack sMatchStack to false
      set the showBorder of btn "test-drag"  of group tWdGrp of cd 1 of stack sMatchStack to false
      set the borderWidth of btn "test-drag"  of group tWdGrp of cd 1 of stack sMatchStack to 0
      put theStack into tLabelTitle
      if char 1 to 3 of tLabelTitle is "rev" then delete char 1 to 3 of tLabelTitle
      set the label of btn "test-drag"  of group tWdGrp of cd 1 of stack sMatchStack to tLabelTitle
      set the width of btn "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to the width of stack sMatchStack - 50
      if there is a widget "header_background" of cd 1 of stack sMatchStack then set the height of btn "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to the height of widget "header_background" of cd 1 of stack sMatchStack
      set the top of btn "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to 0
      set the left of btn "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to 0
      set the script of btn "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to tDragScript
      set the textSize of btn "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to 12
      set the textAlign of btn "test-drag" of group tWdGrp of cd 1 of stack sMatchStack to left
      -- now we set the window shape
      put the windowshape of this stack into tWdID
      if tWDID is "0" then
         -- set to custom shape
         put "_maskholder_" into tCustomWDImage
         if not (there is an image tCustomWDImage of cd 1 of stack sMatchStack) then create image tCustomWDImage in card 1 of stack sMatchStack
         hide image tCustomWDImage of cd 1 of stack sMatchStack
         export snapshot from group tWdGrp of cd 1 of stack sMatchStack to image tCustomWDImage of cd 1 of this stack as png -- with mask
         set the windowShape of stack sMatchStack to (the ID of image tCustomWDImage of cd 1 of this stack)
         put 0 into tCount
         repeat the number of items in tRectsList -- now we clean up our rects
            add 1 to tCount
            put item tCount of tRectsList into tGra
            if there is a graphic tGra of group tWdGrp of card 1 of stack sMatchStack then hide graphic tGra of group tWdGrp of card 1 of stack sMatchStack
         end repeat
      else
         -- window is already a custom shape (?)
      end if
   end if
end tAdjWdRounding


on tDelayedPolysides
   -- we do this for MacOS, because it's being stubborn!
   put the tPassVar of this stack into tPolySidesToSet
   set the polysides to tPolySidesToSet
   set the tPassVar of this stack to ""
end tDelayedPolysides

on hGenDragStack
   --generate the drag stack
   lock screen
   lock messages
   
   reset the templatestack
   set the name of the templateStack to "revDragControl"
   set the visible of the templateStack to false
   set the backGroundColor of the templateStack to the hiliteColor
   set the decorations of the templateStack to "noShadow"
   set the blendLevel of the templateStack to 25
   set the loc of the templatestack to -500,-500
   
   create invisible stack
   reset the templatestack
   set the defaultStack to "revDragControl"
   --show stack "revDragControl"
   unlock messages
   unlock screen
end hGenDragStack

on hPositionAccentsInTools
   if the platform contains "mac" then
      put 0 into mycount
      put the number of graphics of stack "revTools" into myRpt
      repeat myRpt
         add 1 to mycount
         if the short name of graphic mycount of stack "revTools" contains "com.livecode.interface.classic" then
            put the short name of graphic mycount of stack "revTools" & return after myaccBtnNames
         end if
      end repeat
      filter lines of myaccBtnNames without empty
      put 0 into mycount
      repeat the number of lines of myaccBtnNames
         add 1 to mycount
         put line mycount of myaccBtnNames into myAcc
         set the layer of graphic myAcc of stack "revTools" to top
         -----------------------------------------
         -- conditional adjustment (for each one!)
         -----------------------------------------
         if myAcc contains "classic.checkbox" then
            set the width of graphic myAcc of stack "revTools" to 14
            set the height of graphic myAcc of stack "revTools" to 14
            set the style of graphic myAcc of stack "revTools" to "roundrect"
            set the roundRadius of graphic myAcc of stack "revTools" to 8
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
         end if
         if myAcc contains "classic.defaultButton" then
            set the width of graphic myAcc of stack "revTools" to 30
            set the height of graphic myAcc of stack "revTools" to 18
            set the style of graphic myAcc of stack "revTools" to "roundrect"
            set the roundRadius of graphic myAcc of stack "revTools" to 8
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
         end if
         if myAcc contains "classic.radio" then
            set the width of graphic myAcc of stack "revTools" to 16
            set the height of graphic myAcc of stack "revTools" to 16
            set the style of graphic myAcc of stack "revTools" to "oval"
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
         end if
         if myAcc contains "classic.tabPanel" then
            set the width of graphic myAcc of stack "revTools" to 7
            set the height of graphic myAcc of stack "revTools" to 6
            set the style of graphic myAcc of stack "revTools" to "roundrect"
            set the roundRadius of graphic myAcc of stack "revTools" to 4
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the top of graphic myAcc of stack "revTools" to the top of graphic myAcc of stack "revTools" -6
            set the right of graphic myAcc of stack "revTools" to the right of graphic myAcc of stack "revTools" +4
         end if
         if myAcc contains "classic.TableField" then
            set the width of graphic myAcc of stack "revTools" to 9
            set the height of graphic myAcc of stack "revTools" to 5
            set the style of graphic myAcc of stack "revTools" to "rectangle"
            set the roundRadius of graphic myAcc of stack "revTools" to 8
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the top of graphic myAcc of stack "revTools" to the top of graphic myAcc of stack "revTools" -3
            set the left of graphic myAcc of stack "revTools" to the left of graphic myAcc of stack "revTools" -3
         end if
         if myAcc contains "listField" then
            set the width of graphic myAcc of stack "revTools" to 13
            set the height of graphic myAcc of stack "revTools" to 3
            set the style of graphic myAcc of stack "revTools" to "rectangle"
            set the layer of graphic myAcc of stack "revTools" to top
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the top of graphic myAcc of stack "revTools" to the top of graphic myAcc of stack "revTools" -4
            set the left of graphic myAcc of stack "revTools" to the left of graphic myAcc of stack "revTools" -6
         end if
         if myAcc contains "datagrid" then
            set the width of graphic myAcc of stack "revTools" to 22
            set the height of graphic myAcc of stack "revTools" to 5
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the top of graphic myAcc of stack "revTools" to the top of graphic myAcc of stack "revTools" +2
            set the left of graphic myAcc of stack "revTools" to the left of graphic myAcc of stack "revTools" -2
         end if
         if myAcc contains "optionmenu" then
            set the width of graphic myAcc of stack "revTools" to 14
            set the height of graphic myAcc of stack "revTools" to 18
            set the style of graphic myAcc of stack "revTools" to "roundrect"
            set the roundRadius of graphic myAcc of stack "revTools" to 4
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the top of graphic myAcc of stack "revTools" to the top of graphic myAcc of stack "revTools" +1
            set the right of graphic myAcc of stack "revTools" to the right of graphic myAcc of stack "revTools" +8
         end if
         if myAcc contains "pulldown" then
            set the width of graphic myAcc of stack "revTools" to 12
            set the height of graphic myAcc of stack "revTools" to 13
            set the style of graphic myAcc of stack "revTools" to "roundrect"
            set the roundRadius of graphic myAcc of stack "revTools" to 4
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the top of graphic myAcc of stack "revTools" to the top of graphic myAcc of stack "revTools" -1
            set the right of graphic myAcc of stack "revTools" to the right of graphic myAcc of stack "revTools" +6
         end if
         if myAcc contains "combobox" then
            set the width of graphic myAcc of stack "revTools" to 17
            set the height of graphic myAcc of stack "revTools" to 19
            set the style of graphic myAcc of stack "revTools" to "roundrect"
            set the roundRadius of graphic myAcc of stack "revTools" to 8
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the right of graphic myAcc of stack "revTools" to the right of graphic myAcc of stack "revTools" +7
         end if
         if myAcc contains "popup" then
            set the width of graphic myAcc of stack "revTools" to 12
            set the height of graphic myAcc of stack "revTools" to 5
            set the style of graphic myAcc of stack "revTools" to "rectangle"
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the top of graphic myAcc of stack "revTools" to the top of graphic myAcc of stack "revTools" -1
         end if
         if myAcc contains "progressbar" then
            set the width of graphic myAcc of stack "revTools" to 18
            set the height of graphic myAcc of stack "revTools" to 8
            set the style of graphic myAcc of stack "revTools" to "roundrect"
            set the roundRadius of graphic myAcc of stack "revTools" to 8
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
            set the left of graphic myAcc of stack "revTools" to the left of graphic myAcc of stack "revTools" -7
         end if
         if myAcc contains "littlearrows" then
            set the width of graphic myAcc of stack "revTools" to 12
            set the height of graphic myAcc of stack "revTools" to 18
            set the style of graphic myAcc of stack "revTools" to "roundrect"
            set the roundRadius of graphic myAcc of stack "revTools" to 8
            set the layer of graphic myAcc of stack "revTools" to bottom
            set the loc of graphic myAcc of stack "revTools" to the loc of button myAcc of stack "revTools"
         end if
         -----------------------------------------
         -- end conditional adjustment
         -----------------------------------------
      end repeat
   end if
end hPositionAccentsInTools


