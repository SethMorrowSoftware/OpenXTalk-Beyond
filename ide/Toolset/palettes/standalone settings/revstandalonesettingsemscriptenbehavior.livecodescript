script "revStandaloneSettingsEmscriptenBehavior"
on preOpenCard
   initialize
   pass preOpenCard
end preOpenCard

on initialize
   -- OXT-Beyond: the controls of the page's settings
   __EnsureWebSettings
   
   local tEnableButton
   put the long id of button "Emscripten" of group "platforms" into tEnableButton
   
   -- Check whether HTML5 deployment is requested for the target stack
   local tStandaloneSettingsA
   put getSettings() into tStandaloneSettingsA
   
   set the visible of tEnableButton to revEngineCheck("Emscripten")
   set the hilite of tEnableButton to (tStandaloneSettingsA["Emscripten"] is true)
   
   -- Decide whether user is permitted to do HTML5 deployment
   local tHaveLicense
   if revLicenseType() is "community" then
      put true into tHaveLicense
   else if ("HTML5" is among the items of line 5 of the revLicenseInfo) then
      put true into tHaveLicense
   else
      put false into tHaveLicense
   end if
   
   -- Disable the checkbox if no license is available
   set the enabled of tEnableButton to tHaveLicense
   
   -- Hide the license prompt if a license is available
   set the visible of group "emscriptenLicenseTip" to not tHaveLicense
   
   -- OXT-Beyond: the page's settings, and what the pane says
   __ShowWebSettings tStandaloneSettingsA
   
   tipDisplayUpdate
end initialize

on tipDisplayUpdate
   set the backColor of graphic "emscriptenNoLicenseBackground" to ideCoreEditionColour()
   
   -- OXT-Beyond: the pane's controls are put in their places
   -- (__LayoutWebSettings), below the license prompt when it shows, rather
   -- than moved as a group: a group is where its controls are, and the
   -- stack file has the HTML5 checkbox far outside the window, where
   -- OpenXTalk Lite put it
   if the visible of group "emscriptenLicenseTip" then
      __LayoutWebSettings 136
   else 
      __LayoutWebSettings 67
   end if
   set the cSize of this card to 567, max(371, the bottom of field "emscriptenDeploymentInfoLabel" of me + 6)
   
   updateCardSize
   
end tipDisplayUpdate

on emscriptenBuyNow
   launch url "https://livecode.com/products/livecode-platform/html5-purchase-info"
end emscriptenBuyNow

--------------------------------------------------------------------------------
-- OXT-Beyond: the settings of the page that the builder writes
-- (revsaveasemscriptenstandalone.livecodescript): its title, its icon, its
-- colour, where the main stack is in it and its appearance, each under the key
-- "emscripten,<setting>" of the standalone settings. OpenXTalk Lite moved
-- the HTML5 checkbox out of the window and wrote a note about Webtalk, an
-- interpreter of its own, in its place. The stack file has no controls for
-- these settings, so they are made here, in memory, the first time the card
-- opens, as copies of the Windows card's controls of the same kinds without
-- their scripts: this behavior handles their messages.
--------------------------------------------------------------------------------

-- The controls that the page's settings use, which are enabled while the
-- standalone is built for HTML5
constant kWebSettingsControls = "emscriptenPageHeading,emscriptenPageLine,emscriptenTitleLabel,emscriptenTitle,emscriptenTitleHint,emscriptenIconLabel,emscriptenIcon,emscriptenIconNone,emscriptenIconChoose,emscriptenColorLabel,emscriptenColorSwatch,emscriptenColorDefault,emscriptenColorChoose,emscriptenPositionLabel,emscriptenPosition,emscriptenAppearanceLabel,emscriptenAppearance"

-- The places of the main stack in the page: the menu's items, and the
-- settings' values (empty for the first, the page's own place)
constant kPositionItems = "Centered at the top,Centered in the window,At the top left"
constant kPositionValues = ",center,topLeft"

-- The appearances of the page: the menu's items, and the settings' values
-- (empty for the first, light always, as every page was)
constant kAppearanceItems = "Light,Follow the browser (light or dark)"
constant kAppearanceValues = ",system"

-- The page's colour when it has none of its own
constant kDefaultPageColor = "#FFFFFF"

private command __EnsureWebSettings
   if there is a field "emscriptenTitle" of me then
      exit __EnsureWebSettings
   end if
   
   local tWindows, tControl
   put the long id of group "Windows" of card "Windows" of the owner of me into tWindows
   lock screen
   lock messages
   
   -- The heading, with its line
   put __CopyControl(the long id of field "Icon Label" of tWindows, "emscriptenPageHeading") into tControl
   set the htmlText of tControl to "<p><b>Web Page</b></p>"
   revFontApplySystemStyle tControl, empty, "bold"
   put __CopyControl(the long id of graphic id 1620 of tWindows, "emscriptenPageLine") into tControl
   
   -- A label for each setting, as the Windows card's "Application Icon:"
   repeat for each item tSetting in "Title,Icon,Color,Position,Appearance"
      put __CopyControl(the long id of field id 1135 of tWindows, "emscripten" & tSetting & "Label") into tControl
      if tSetting is "Color" then
         set the text of tControl to "Background:"
      else
         set the text of tControl to tSetting & ":"
      end if
   end repeat
   
   -- The title, which the user types, with a note of what it is without one
   put __CopyControl(the long id of field "FileDescription" of tWindows, "emscriptenTitle") into tControl
   set the text of tControl to empty
   put __CopyControl(the long id of field id 1135 of tWindows, "emscriptenTitleHint") into tControl
   set the textAlign of tControl to "left"
   set the text of tControl to "(empty: the stack's title)"
   
   -- The icon: a file of the stack's folder or elsewhere, which the
   -- buttons choose and clear, as the Windows card's application icon
   put __CopyControl(the long id of field "iconFile" of tWindows, "emscriptenIcon") into tControl
   set the text of tControl to empty
   put __CopyControl(the long id of button "Use None" of tWindows, "emscriptenIconNone") into tControl
   set the label of tControl to "Use None"
   put __CopyControl(the long id of button "Choose..." of tWindows, "emscriptenIconChoose") into tControl
   set the label of tControl to "Choose..."
   
   -- The colour: a swatch, which a click on it or on Choose... changes
   create graphic "emscriptenColorSwatch" in group "emscriptenSettings" of me
   put it into tControl
   set the style of tControl to "rectangle"
   set the filled of tControl to true
   set the opaque of tControl to true
   set the lineSize of tControl to 1
   set the foregroundColor of tControl to "128,128,128"
   put __CopyControl(the long id of button "Use None" of tWindows, "emscriptenColorDefault") into tControl
   set the label of tControl to "Use White"
   put __CopyControl(the long id of button "Choose..." of tWindows, "emscriptenColorChoose") into tControl
   set the label of tControl to "Choose..."
   
   -- The place of the main stack: an option menu, as the Windows card's
   -- UAC execution level
   put __CopyControl(the long id of button "UAC Execution Level" of tWindows, "emscriptenPosition") into tControl
   set the text of tControl to replaceText(kPositionItems, comma, return)
   set the label of tControl to item 1 of kPositionItems
   
   -- The appearance: light always, or the browser's colour scheme
   put __CopyControl(the long id of button "UAC Execution Level" of tWindows, "emscriptenAppearance") into tControl
   set the text of tControl to replaceText(kAppearanceItems, comma, return)
   set the label of tControl to item 1 of kAppearanceItems

   -- Each control's own tooltip: a copy keeps its template's, which speaks
   -- of the Windows application's icon (.ico) and file description
   set the tooltip of field "emscriptenTitle" of me to "The title of the web page, which the browser shows on its tab (empty: the stack's title)"
   set the tooltip of field "emscriptenIcon" of me to "The image that the browser shows as the page's icon on its tab"
   set the tooltip of button "emscriptenIconNone" of me to "Don't give the page an icon and empty the field"
   set the tooltip of button "emscriptenIconChoose" of me to "Choose an image (.png, .ico, .svg, .gif, .jpg or .webp) for the page's icon"
   set the tooltip of graphic "emscriptenColorSwatch" of me to "The colour of the page around the stack: click to choose another"
   set the tooltip of button "emscriptenColorDefault" of me to "Use white, the page's colour when none is chosen"
   set the tooltip of button "emscriptenColorChoose" of me to "Choose the colour of the page around the stack"
   set the tooltip of button "emscriptenPosition" of me to "Where the main stack is on the page"
   set the tooltip of button "emscriptenAppearance" of me to "Light: the stack draws light in every browser, as before. Follow the browser: the systemAppearance and the controls' default colours follow the browser's light or dark scheme"

   unlock messages
   unlock screen
end __EnsureWebSettings

-- A copy of pTemplate in this card's group of settings, named pName,
-- without the template's script, behavior and custom properties
private function __CopyControl pTemplate, pName
   local tControl
   copy pTemplate to group "emscriptenSettings" of me
   put it into tControl
   set the name of tControl to pName
   set the script of tControl to empty
   set the behavior of tControl to empty
   set the customProperties of tControl to empty
   set the visible of tControl to true
   return tControl
end __CopyControl

-- Each control in its place: the HTML5 checkbox in the first row, at
-- pTop, as the Windows card's checkboxes are in theirs, then the page's
-- settings under their heading, then the text about the standalone
private command __LayoutWebSettings pTop
   local tTop
   lock screen
   set the textAlign of field "Label Field" of me to "left"
   set the rect of field "Label Field" of me to 14, pTop, 101, pTop + 24
   set the visible of field "Label Field" of me to true
   set the rect of button "Emscripten" of group "platforms" of me to 154, pTop + 4, 330, pTop + 24
   
   put pTop + 34 into tTop
   set the rect of field "emscriptenPageHeading" of me to 14, tTop, 300, tTop + 21
   set the rect of graphic "emscriptenPageLine" of me to 14, tTop + 20, 740, tTop + 22
   
   add 32 to tTop
   set the rect of field "emscriptenTitleLabel" of me to 2, tTop, 142, tTop + 24
   set the rect of field "emscriptenTitle" of me to 150, tTop, 533, tTop + 24
   set the rect of field "emscriptenTitleHint" of me to 543, tTop, 740, tTop + 24
   
   add 32 to tTop
   set the rect of field "emscriptenIconLabel" of me to 2, tTop, 142, tTop + 24
   set the rect of field "emscriptenIcon" of me to 150, tTop, 533, tTop + 24
   set the rect of button "emscriptenIconNone" of me to 543, tTop + 1, 643, tTop + 24
   set the rect of button "emscriptenIconChoose" of me to 649, tTop + 1, 739, tTop + 24
   
   add 32 to tTop
   set the rect of field "emscriptenColorLabel" of me to 2, tTop, 142, tTop + 24
   set the rect of graphic "emscriptenColorSwatch" of me to 150, tTop + 1, 190, tTop + 23
   set the rect of button "emscriptenColorDefault" of me to 543, tTop + 1, 643, tTop + 24
   set the rect of button "emscriptenColorChoose" of me to 649, tTop + 1, 739, tTop + 24
   
   add 32 to tTop
   set the rect of field "emscriptenPositionLabel" of me to 2, tTop, 142, tTop + 24
   set the rect of button "emscriptenPosition" of me to 150, tTop + 1, 400, tTop + 23
   
   add 32 to tTop
   set the rect of field "emscriptenAppearanceLabel" of me to 2, tTop, 142, tTop + 24
   set the rect of button "emscriptenAppearance" of me to 150, tTop + 1, 400, tTop + 23
   
   -- the text, as tall as it is at this width
   add 38 to tTop
   set the rect of field "emscriptenDeploymentInfoLabel" of me to 10, tTop, 740, tTop + 84
   set the height of field "emscriptenDeploymentInfoLabel" of me to \
         the formattedHeight of field "emscriptenDeploymentInfoLabel" of me
   set the top of field "emscriptenDeploymentInfoLabel" of me to tTop
   unlock screen
end __LayoutWebSettings

-- The settings in their controls, which are enabled while the standalone
-- is built for HTML5, and what the pane says about the standalone
private command __ShowWebSettings pSettings
   local tEnabled, tValue
   put pSettings["Emscripten"] is true and \
         the visible of button "Emscripten" of group "platforms" of me into tEnabled
   lock screen
   lock messages
   set the text of field "emscriptenTitle" of me to pSettings["emscripten,title"]
   set the text of field "emscriptenIcon" of me to pSettings["emscripten,icon"]
   set the backgroundColor of graphic "emscriptenColorSwatch" of me to \
         __PageColor(pSettings["emscripten,backgroundColor"])
   set the wholeMatches to true
   put itemOffset(pSettings["emscripten,position"], kPositionValues) into tValue
   if pSettings["emscripten,position"] is empty or tValue is 0 then
      put 1 into tValue
   end if
   set the menuHistory of button "emscriptenPosition" of me to tValue
   put itemOffset(pSettings["emscripten,appearance"], kAppearanceValues) into tValue
   if pSettings["emscripten,appearance"] is empty or tValue is 0 then
      put 1 into tValue
   end if
   set the menuHistory of button "emscriptenAppearance" of me to tValue
   repeat for each item tControl in kWebSettingsControls
      set the enabled of control tControl of me to tEnabled
   end repeat
   unlock messages
   
   if the visible of button "Emscripten" of group "platforms" of me then
      put "Save as Standalone Application writes a folder for a web server: the page" && \
            "(<name>.html), the engine (a .js and a .wasm file) and standalone.zip, with the" && \
            "stacks and the files to copy. Browsers run the page from a web server, not from" && \
            "a file on the disk." & return & \
            "To try the stack in a browser, choose a browser in Development > Test Target," && \
            "then Development > Test. The guide Deploying Your Application tells more." into tValue
   else
      put "This installation has no HTML5 engine: its files belong in the folder" && \
            "Runtime/Emscripten/js of the OXT-Beyond folder." into tValue
   end if
   set the text of field "emscriptenDeploymentInfoLabel" of me to tValue
   unlock screen
end __ShowWebSettings

-- The colour of a page as the swatch shows it: the setting, or white
private function __PageColor pSetting
   if matchText(pSetting, "^#[0-9A-Fa-f]{6}$") then
      return pSetting
   end if
   return kDefaultPageColor
end __PageColor

-- The HTML5 checkbox's mouseUp: the page's settings follow it
on buildForEnabled pPlatform
   if pPlatform is "emscripten" then
      __ShowWebSettings getSettings()
   end if
   pass buildForEnabled
end buildForEnabled

-- The title is stored as it is typed, on one line
on textChanged
   if the short name of the target is "emscriptenTitle" then
      setSetting "emscripten,title", line 1 of the text of the target
   end if
   pass textChanged
end textChanged

on returnInField
   if the short name of the target is not "emscriptenTitle" then
      pass returnInField
   end if
end returnInField

on enterInField
   if the short name of the target is not "emscriptenTitle" then
      pass enterInField
   end if
end enterInField

on mouseUp pButton
   if pButton is not 1 or not the enabled of the target then
      pass mouseUp
   end if
   switch the short name of the target
      case "emscriptenIconChoose"
         __ChooseIcon
         break
      case "emscriptenIconNone"
         setSetting "emscripten,icon", empty
         set the text of field "emscriptenIcon" of me to empty
         break
      case "emscriptenColorSwatch"
      case "emscriptenColorChoose"
         __ChooseColor
         break
      case "emscriptenColorDefault"
         setSetting "emscripten,backgroundColor", empty
         set the backgroundColor of graphic "emscriptenColorSwatch" of me to kDefaultPageColor
         break
   end switch
   pass mouseUp
end mouseUp

on menuPick pItem
   if the short name of the target is "emscriptenPosition" then
      setSetting "emscripten,position", item (the menuHistory of the target) of kPositionValues
   end if
   if the short name of the target is "emscriptenAppearance" then
      setSetting "emscripten,appearance", item (the menuHistory of the target) of kAppearanceValues
   end if
   pass menuPick
end menuPick

-- The icon: an image that browsers show as a page's icon, kept relative to
-- the stack's folder when it is in it, as the other cards' icons are (a
-- stack that was never saved has no folder: its path is just a slash)
private command __ChooseIcon
   local tFile, tFolder
   answer file "Choose the page's icon:" with type "Images|png,ico,svg,gif,jpg,jpeg,webp|" or type "All files|*|"
   put it into tFile
   if tFile is empty then
      exit __ChooseIcon
   end if
   put utilityTargetStackPath() into tFolder
   if tFolder is not slash then
      put utilityMakePathRelative(tFile, tFolder) into tFile
   end if
   setSetting "emscripten,icon", tFile
   set the text of field "emscriptenIcon" of me to tFile
end __ChooseIcon

-- The colour: stored as the page's CSS has it, #RRGGBB
private command __ChooseColor
   local tColor
   answer color with __PageColor(getSetting("emscripten,backgroundColor"))
   put it into tColor
   -- empty when the user cancels; else red, green and blue
   if matchText(tColor, "^#[0-9A-Fa-f]{6}$") then
      put toUpper(tColor) into tColor
   else if the number of items of tColor is 3 then
      put format("#%02X%02X%02X", item 1 of tColor, item 2 of tColor, item 3 of tColor) into tColor
   else
      exit __ChooseColor
   end if
   setSetting "emscripten,backgroundColor", tColor
   set the backgroundColor of graphic "emscriptenColorSwatch" of me to tColor
end __ChooseColor
