script "oxt_render_test"
-- Renders controls with the native Windows theme and writes them as PNG
-- files, for tools/ci/render_check.py to measure and compare.
--
-- Disabled controls and scrollbars (the first checks, PR #12):
--
--    push, check, radio  a disabled push button, checkbox and radio button,
--                        each also rendered with showName false
--                        (<name>-nolabel.png), so the label's pixels and the
--                        background under them are known, and both again
--                        enabled (<name>-enabled.png and
--                        <name>-enabled-nolabel.png), so the shape of the
--                        disabled label can be compared with one drawn once
--    graphic             a disabled rectangle graphic with a foreColor of
--                        its own, showing its name, rendered the same way
--    tabs                a tab panel whose visible tabs are disabled
--    scrollbar           a vertical scrollbar, its thumb at the top
--    field               a field with a vertical scrollbar, scrolled to the
--                        top
--    card                the whole card, for people to look at
--
-- The light and dark appearance (the appAppearance and stackAppearance,
-- engine/src/appearance.cpp; the colours fitted to each object,
-- MCObject::isdarkappearance in engine/src/object.cpp), one stack each:
--
--    s1-*   the colours of the owner's libMQTTxt demo stack, built here (the
--           stack itself is never used): a light card, a blue band with a
--           white title, white panels, grey captions, white input and
--           scrolling fields with no text colour, checkboxes and push
--           buttons with no colours. It must look as designed, light, in
--           every run
--    s2-*   a stack that sets no colours: dark in the dark appearance
--    s3-*   a card of 30,30,30 and nothing else
--    s4-*   fields with black text of their own and no background colour
--    s5     a field with both colours of its own: the same in every run
--    s6-*   text runs: red text and a yellow highlight in a white field, and
--           a yellow highlight in a field with no colours
--    s7-*   buttons with a light and a dark background of their own
--    s8-*   copies of s2 with the stackAppearance "dark" and "light", which
--           must look like s2 in the other appearance
--    screen 8x8 pixels of the screen, taken after a window was opened: that
--           used to crash the engine
--
-- The native theme and the light and dark colours only exist with a user
-- interface, so this runs as the development engine's home stack, not with
-- -ui. tools/ci/render-test.ps1 copies it to <folder>/Startup.rev, the
-- first file the engine's environment stack (engine/src/environment) looks
-- for in its tools folder, and points REV_TOOLS_PATH at <folder>, so the
-- engine opens this script instead of the IDE. It sets Windows to dark or
-- light mode first (AppsUseLightTheme), once for each run, and runs the
-- engine of the release before this change too, as the reference for the
-- light appearance. That engine has no appAppearance: every use of the new
-- syntax is inside "do", so this script compiles on it, and the parts that
-- need the properties are left out there.
--
-- Environment variables:
--    OXT_RENDER_OUT         folder for the PNG files and render.txt
--                           (required)
--    OXT_RENDER_APPEARANCE  what to set the appAppearance to before
--                           anything is created: light, dark or system;
--                           empty leaves the engine's default
--
-- render.txt has one record per line, fields separated by tabs:
--    INFO   <name> <value>
--    SHOT   label <name> <image> <image without the label>
--                 <image enabled> <image enabled without the label>
--    SHOT   tab <name> <image>
--    SHOT   track <name> <image> <x,y,width,height of the track in the image>
--    SHOT   thumb <name> <image> <x,y,width,height of the part of the
--                 scrollbar between the up arrow and the track, where the
--                 thumb is>
--    SHOT   text <name> <image> <the same without the text>
--    SHOT   face <name> <image> <the same with the control hidden>
--    SHOT   region <name> <image> <x,y,width,height in the image>
--    ERROR  <where> <message>
-- and ends with "INFO done true" when every image was written. What is
-- checked for each text, face and region is in render_check.py, by name.
--
-- Nothing is ever shown: the stacks are created invisible and the images are
-- rendered off screen ("export snapshot from rect ... of card"). The exit
-- code is 0 when the images were written and 2 when the script failed.

constant kStack = "oxt_render_test_controls"
-- Large bold text, so that each glyph has pixels fully covered by the
-- label colour, which render_check.py measures
constant kTextSize = 16

local sOut
local sReport
-- Whether the engine has the appAppearance, and whether it draws stacks
-- that set no appearance dark
local sHasAppearance
local sEffectiveDark

on startup
   set the lockMessages to true
   put empty into sReport
   put $OXT_RENDER_OUT into sOut
   replace "\" with "/" in sOut
   if the last char of sOut is "/" then delete the last char of sOut
   if sOut is empty then
      write "OXT_RENDER_OUT is not set" & return to stdout
      quit 2
   end if
   if there is not a folder sOut then create folder sOut

   try
      setUpAppearance
      renderControls
      renderOwnerPattern
      renderUnstyled "s2", empty
      renderDarkDesigned
      renderExplicitText
      renderExplicitBoth
      renderStyledRuns
      renderButtonColours
      if sHasAppearance then
         renderUnstyled "s8-dark", "dark"
         renderUnstyled "s8-light", "light"
         -- The release before this change crashes here (w32dcs.cpp)
         screenSnapshot
      end if
      addRecord "INFO", "done", "true"
   catch tError
      addRecord "ERROR", "script", oneLine(tError)
   end try
   finishRun
end startup

-- Without the IDE an uncaught error would open a dialog and wait forever
on errorDialog pError
   write "ERROR errorDialog " & oneLine(pError) & return to stdout
   quit 3
end errorDialog

-- Sets the appAppearance for this run, before anything is created, and
-- records the defaults, which render_check.py checks
private command setUpAppearance
   local tValue, tError, tRequested

   addRecord "INFO", "version", the version & " build " & the buildNumber
   addRecord "INFO", "environment", the environment
   addRecord "INFO", "platform", the platform & " " & the systemVersion
   -- "Appearance Manager" when the native Windows theme is active
   addRecord "INFO", "lookAndFeel", the lookAndFeel
   addRecord "INFO", "systemAppearance", the systemAppearance
   -- (without a user interface the engine has no screen to ask)
   if the environment is not "development command line" then
      addRecord "INFO", "screenPixelScale", the screenPixelScale
   end if

   put false into sHasAppearance
   try
      do "get the appAppearance"
      put true into sHasAppearance
   catch tError
   end try
   put $OXT_RENDER_APPEARANCE into tRequested
   addRecord "INFO", "hasAppAppearance", sHasAppearance
   addRecord "INFO", "requestedAppearance", tRequested

   if sHasAppearance then
      do "put the appAppearance into tValue"
      addRecord "INFO", "appAppearanceAtStart", tValue
      do "put the effective appAppearance into tValue"
      addRecord "INFO", "effectiveAppAppearanceAtStart", tValue
      if tRequested is not empty then
         do "set the appAppearance to " & quote & tRequested & quote
      end if
      do "put the appAppearance into tValue"
      addRecord "INFO", "appAppearance", tValue
      do "put the effective appAppearance into tValue"
      addRecord "INFO", "effectiveAppAppearance", tValue
      put tValue is "dark" into sEffectiveDark
   else
      -- Engines before the appAppearance follow the OS
      put the systemAppearance is "dark" into sEffectiveDark
      addRecord "INFO", "effectiveAppAppearance", the systemAppearance
   end if

   -- The paint tools' colours are set once, light, whatever the appearance
   -- (MCWin32UpdateSystemColors); the selection handles follow it
   addRecord "INFO", "penColor", the penColor
   addRecord "INFO", "brushColor", the brushColor
   addRecord "INFO", "selectionHandleColor", the selectionHandleColor
end setUpAppearance

private command renderControls
   local tObject, tRect, tFieldText

   -- The controls are created on the card of this stack; "create" puts
   -- the long id of the new object into "it"
   create invisible stack kStack
   set the defaultStack to kStack
   set the rect of stack kStack to 100,100,700,500
   addRecord "INFO", "cardBackColor", the effective backColor of card 1 of stack kStack

   -- The labels
   create button "push"
   put it into tObject
   set the style of tObject to "standard"
   set the rect of tObject to 20,20,240,60
   set the label of tObject to "Disabled push"
   setUpDisabledLabel tObject
   shootLabel tObject, "push"

   create button "check"
   put it into tObject
   set the style of tObject to "checkbox"
   set the rect of tObject to 20,80,260,112
   set the label of tObject to "Disabled check"
   setUpDisabledLabel tObject
   shootLabel tObject, "check"

   create button "radio"
   put it into tObject
   set the style of tObject to "radioButton"
   set the rect of tObject to 20,130,260,162
   set the label of tObject to "Disabled radio"
   setUpDisabledLabel tObject
   shootLabel tObject, "radio"

   -- A disabled graphic with a foreColor of its own: its label must still
   -- be drawn once in the disabled grey (MCGraphic::draw), although the
   -- foreground colour of the graphic is the foreColor
   create graphic "graphic"
   put it into tObject
   set the style of tObject to "rectangle"
   set the opaque of tObject to false
   set the rect of tObject to 20,310,260,350
   set the foreColor of tObject to "200,0,0"
   set the label of tObject to "Disabled graphic"
   setUpDisabledLabel tObject
   shootLabel tObject, "graphic"

   -- A tab panel narrower than its first two tabs, which are disabled
   -- ("(" in front of a tab disables it), so that every tab face in it is
   -- a disabled one. The selected tab is the third, outside the panel.
   create button "tabs"
   put it into tObject
   set the style of tObject to "menu"
   set the menuMode of tObject to "tabbed"
   set the rect of tObject to 20,190,190,290
   set the text of tObject to "(Disabled one" & return & "(Disabled two" & return & "Selected"
   set the menuHistory of tObject to 3
   -- (a tab panel shows its name in the pane otherwise)
   set the showName of tObject to false
   set the textSize of tObject to kTextSize
   set the textStyle of tObject to "bold"
   put the rect of tObject into tRect
   exportRect tRect, "tabs.png"
   addRecord "SHOT", "tab", "tabs", "tabs.png"

   -- A vertical scrollbar with the thumb at the top, so that the lower
   -- half is track, and the thumb is right below the up arrow
   create scrollbar "scrollbar"
   put it into tObject
   set the style of tObject to "scrollbar"
   set the rect of tObject to 300,20,317,240
   set the startValue of tObject to 0
   set the endValue of tObject to 100
   set the thumbSize of tObject to 10
   set the thumbPosition of tObject to 0
   put the rect of tObject into tRect
   exportRect tRect, "scrollbar.png"
   addRecord "SHOT", "track", "scrollbar", "scrollbar.png", scrollbarRegion("track", item 3 of tRect - item 1 of tRect, item 4 of tRect - item 2 of tRect, 0, 0)
   addRecord "SHOT", "thumb", "scrollbar", "scrollbar.png", scrollbarRegion("thumb", item 3 of tRect - item 1 of tRect, item 4 of tRect - item 2 of tRect, 0, 0)

   -- A field whose text is longer than the field, with a vertical scrollbar
   create field "field"
   put it into tObject
   set the rect of tObject to 340,20,540,200
   set the vScrollbar of tObject to true
   repeat with i = 1 to 60
      put "Line " & i & return after tFieldText
   end repeat
   set the text of tObject to tFieldText
   set the vScroll of tObject to 0
   put the rect of tObject into tRect
   exportRect tRect, "field.png"
   addRecord "INFO", "fieldScrollbar", "borderWidth " & the borderWidth of tObject & ", scrollbarWidth " & the scrollbarWidth of tObject
   addRecord "SHOT", "track", "field", "field.png", scrollbarRegion("track", item 3 of tRect - item 1 of tRect, item 4 of tRect - item 2 of tRect, the borderWidth of tObject, the scrollbarWidth of tObject)
   addRecord "SHOT", "thumb", "field", "field.png", scrollbarRegion("thumb", item 3 of tRect - item 1 of tRect, item 4 of tRect - item 2 of tRect, the borderWidth of tObject, the scrollbarWidth of tObject)

   exportRect the rect of card 1 of stack kStack, "card.png"
end renderControls

-- A snapshot of the screen once a window exists. Creating a window sets its
-- title bar through dwmapi.dll (MCWin32SetWindowDarkMode), and the screen
-- snapshot code then found that library loaded but its
-- DwmIsCompositionEnabled never resolved, and crashed
-- (engine/src/w32dcs.cpp, s_ensure_dwmapi). A crash ends the run with a
-- non-zero exit code and no render.txt, which render-test.ps1 reports.
-- The stack is opened invisible, so nothing is shown; the rectangle is 8
-- pixels at the top left of the screen.
private command screenSnapshot
   local tFile
   create invisible stack "oxt_render_test_window"
   go invisible stack "oxt_render_test_window"
   put sOut & "/screen.png" into tFile
   export snapshot from rect "0,0,8,8" to file tFile as PNG
   if there is not a file tFile then
      throw "export snapshot from rect 0,0,8,8 wrote no file (the result: " & the result & ")"
   end if
   close stack "oxt_render_test_window"
   addRecord "INFO", "screenSnapshot", "written after a window was opened"
end screenSnapshot

private command setUpDisabledLabel pObject
   set the showName of pObject to true
   set the textSize of pObject to kTextSize
   set the textStyle of pObject to "bold"
   -- It is also rendered enabled (shootLabel), where a focus border would
   -- count as part of the label
   set the traversalOn of pObject to false
   set the disabled of pObject to true
end setUpDisabledLabel

-- Renders a control with and without its label. Hiding the label changes
-- nothing else, so the pixels that differ are the label's. Then the same
-- enabled: a second copy of the disabled label in the same grey, a pixel
-- or two off, passes every check of its colour, but not a comparison of its
-- shape with the enabled label, which is drawn once.
--
-- The enabled label is drawn in the disabled grey too (its foreColor, which
-- is the label colour of buttons and graphics): DirectWrite's ClearType
-- text is heavier or lighter by a pixel with the text colour's contrast, so
-- a grey label and a black, white or red one differ in shape although both
-- are drawn once. In the same colour they are drawn with the same pixels.
private command shootLabel pObject, pName
   local tRect, tForeColor
   put the rect of pObject into tRect
   exportRect tRect, pName & ".png"
   set the showName of pObject to false
   exportRect tRect, pName & "-nolabel.png"
   set the showName of pObject to true
   put the foreColor of pObject into tForeColor
   set the foreColor of pObject to disabledGrey()
   set the disabled of pObject to false
   exportRect tRect, pName & "-enabled.png"
   set the showName of pObject to false
   exportRect tRect, pName & "-enabled-nolabel.png"
   set the showName of pObject to true
   set the disabled of pObject to true
   set the foreColor of pObject to tForeColor
   addRecord "SHOT", "label", pName, pName & ".png", pName & "-nolabel.png", \
         pName & "-enabled.png", pName & "-enabled-nolabel.png"
end shootLabel

-- The grey the engine draws disabled labels in on the native Windows
-- theme (MCScreenDC::getdefaultcolors, engine/src/w32dc.cpp): the colour of
-- render_check.py's DISABLED_GREY, for the enabled reference labels. It is
-- that of the appearance the stack is drawn in, which is no longer always
-- the OS setting's.
private function disabledGrey
   if sEffectiveDark then return "137,137,137"
   return "128,128,128"
end disabledGrey

-- Renders a rectangle of the card (card coordinates) off screen
private command exportRect pRect, pFile
   exportStackRect kStack, pRect, pFile
end exportRect

private command exportStackRect pStack, pRect, pFile
   export snapshot from rect (pRect) of card 1 of stack pStack to file (sOut & "/" & pFile) as PNG
   if there is not a file (sOut & "/" & pFile) then
      throw "export snapshot wrote no file " & pFile & " (the result: " & the result & ")"
   end if
end exportStackRect

-- Parts of a vertical scrollbar's image when the thumb is at the top, a few
-- pixels in from the edges. "track": the lower half, above the down arrow
-- (as tall as the scrollbar is wide), which is only track. "thumb": from
-- just below the up arrow down to the track part, where the thumb is; the
-- arrow's glyph is left out. For a field, the scrollbar is inside the
-- border, at the right.
private function scrollbarRegion pPart, pWidth, pHeight, pBorder, pScrollbarWidth
   local tLeft, tBarWidth, tTop, tBottom
   if pScrollbarWidth is 0 then
      put 0 into tLeft
      put pWidth into tBarWidth
   else
      put pWidth - pBorder - pScrollbarWidth into tLeft
      put pScrollbarWidth into tBarWidth
   end if
   if pPart is "thumb" then
      put pBorder + tBarWidth + 2 into tTop
      put pHeight div 2 into tBottom
   else
      put pHeight div 2 into tTop
      put pHeight - pBorder - tBarWidth - 4 into tBottom
   end if
   return (tLeft + 3) & comma & tTop & comma & (tBarWidth - 6) & comma & (tBottom - tTop)
end scrollbarRegion

--------------------------------------------------------------------------------
-- The appearance scenarios

-- A new invisible stack for one scenario, 600x400 at 100,100 unless given;
-- the controls go on its card
private command newScenarioStack pName, pWidth, pHeight
   if pWidth is empty then put 600 into pWidth
   if pHeight is empty then put 400 into pHeight
   create invisible stack pName
   set the defaultStack to pName
   set the rect of stack pName to 100, 100, 100 + pWidth, 100 + pHeight
end newScenarioStack

-- A field with large bold text; its style is set up by the caller
private function newTextField pName, pRect, pText
   create field pName
   set the rect of it to pRect
   set the textSize of it to kTextSize
   set the textStyle of it to "bold"
   set the traversalOn of it to false
   set the text of it to pText
   return it
end newTextField

-- A field that shows its text only: no border, no fill
private command makeLabel pObject
   set the opaque of pObject to false
   set the showBorder of pObject to false
   set the threeD of pObject to false
end makeLabel

-- Renders a field with its text, and without it. The pixels that differ
-- are the text's, the second image gives what is under them. pHide is how
-- the text is taken away: empty clears it, a colour paints the text in it
-- (the colour of a run's own background, which hides the text but keeps
-- the run's background).
private command shootText pStack, pObject, pName, pHide
   local tRect, tText, tHTML
   put the rect of pObject into tRect
   exportStackRect pStack, tRect, pName & ".png"
   if pHide is empty then
      put the text of pObject into tText
      set the text of pObject to empty
      exportStackRect pStack, tRect, pName & "-bare.png"
      set the text of pObject to tText
   else
      put the htmlText of pObject into tHTML
      set the textColor of char 1 to -1 of field (the short name of pObject) of card 1 of stack pStack to pHide
      exportStackRect pStack, tRect, pName & "-bare.png"
      set the htmlText of pObject to tHTML
   end if
   addRecord "SHOT", "text", pName, pName & ".png", pName & "-bare.png"
end shootText

-- Renders a button with its label, and without it
private command shootName pStack, pObject, pName
   local tRect
   put the rect of pObject into tRect
   set the showName of pObject to true
   exportStackRect pStack, tRect, pName & ".png"
   set the showName of pObject to false
   exportStackRect pStack, tRect, pName & "-bare.png"
   set the showName of pObject to true
   addRecord "SHOT", "text", pName, pName & ".png", pName & "-bare.png"
end shootName

-- Renders a control, and the same place with the control hidden: the
-- pixels that differ are the control's (its label is hidden for both,
-- where it has one)
private command shootFace pStack, pObject, pName, pRect
   local tRect, tShowName
   if pRect is empty then put the rect of pObject into tRect
   else put pRect into tRect
   if word 1 of the name of pObject is "button" then
      put the showName of pObject into tShowName
      set the showName of pObject to false
   end if
   exportStackRect pStack, tRect, pName & ".png"
   set the visible of pObject to false
   exportStackRect pStack, tRect, pName & "-bare.png"
   set the visible of pObject to true
   if tShowName is not empty then set the showName of pObject to tShowName
   addRecord "SHOT", "face", pName, pName & ".png", pName & "-bare.png"
end shootFace

-- Renders a rectangle of the card and names a region in it
private command shootRegion pStack, pRect, pName, pRegion
   exportStackRect pStack, pRect, pName & ".png"
   addRecord "SHOT", "region", pName, pName & ".png", pRegion
end shootRegion

-- S1: the colours of the owner's libMQTTxt demo stack (a dump of its
-- colours; the stack file itself is the owner's and is never used). The
-- stack sets no colours; the card is 240,242,246; a band of 44,90,160 holds
-- a transparent title field in white; panels are round rectangles filled
-- 255 with 225,229,236 lines; captions and section titles are transparent
-- fields with a grey and a near-black text colour of their own; the input
-- and scrolling fields are opaque with a white background and a border
-- colour, but no text colour; the checkboxes and push buttons set no
-- colours. In the dark appearance the unset colours must fit the light
-- design: it looks as it does in the light appearance.
private command renderOwnerPattern
   local tStack, tObject, tRect, tText, tHost, tValue
   put "oxt_render_s1" into tStack
   newScenarioStack tStack, 700, 520
   set the backColor of card 1 of stack tStack to "240,242,246"

   create graphic "uiBand"
   put it into tObject
   set the style of tObject to "rectangle"
   set the opaque of tObject to true
   set the lineSize of tObject to 0
   set the backColor of tObject to "44,90,160"
   set the rect of tObject to 0,0,700,48

   put newTextField("uiTitle", "16,8,400,40", "libMQTTxt") into tObject
   makeLabel tObject
   set the foreColor of tObject to "255,255,255"
   shootText tStack, tObject, "s1-title"

   create graphic "mdBrokerPanel"
   put it into tObject
   set the style of tObject to "roundrect"
   set the opaque of tObject to true
   set the foreColor of tObject to "225,229,236"
   set the backColor of tObject to "255,255,255"
   set the borderColor of tObject to "225,229,236"
   set the rect of tObject to 16,64,684,290

   create graphic "mdLogPanel"
   put it into tObject
   set the style of tObject to "roundrect"
   set the opaque of tObject to true
   set the foreColor of tObject to "225,229,236"
   set the backColor of tObject to "255,255,255"
   set the borderColor of tObject to "225,229,236"
   set the rect of tObject to 16,302,684,504

   put newTextField("mdSecBroker", "32,72,300,100", "Broker") into tObject
   makeLabel tObject
   set the foreColor of tObject to "28,34,46"
   shootText tStack, tObject, "s1-section"

   put newTextField("mdHostCap", "32,104,200,130", "Host") into tObject
   makeLabel tObject
   set the foreColor of tObject to "138,146,158"
   shootText tStack, tObject, "s1-caption"

   -- The input fields: "rectangle" style, opaque, white, a border colour,
   -- no text colour
   put newTextField("mdHost", "32,132,330,164", "broker.example.com") into tObject
   put tObject into tHost
   set the opaque of tObject to true
   set the showBorder of tObject to true
   set the threeD of tObject to false
   set the borderWidth of tObject to 1
   set the borderColor of tObject to "203,210,222"
   set the backColor of tObject to "255,255,255"
   shootText tStack, tObject, "s1-host"

   -- Checkboxes with no colours on the panel, one of them ticked
   create button "mdTLS"
   put it into tObject
   set the style of tObject to "checkbox"
   set the rect of tObject to 32,176,200,204
   set the textSize of tObject to kTextSize
   set the textStyle of tObject to "bold"
   set the traversalOn of tObject to false
   set the label of tObject to "Use TLS"
   shootName tStack, tObject, "s1-check"
   shootFace tStack, tObject, "s1-check-box"

   create button "mdAuto"
   put it into tObject
   set the style of tObject to "checkbox"
   set the rect of tObject to 220,176,420,204
   set the textSize of tObject to kTextSize
   set the textStyle of tObject to "bold"
   set the traversalOn of tObject to false
   set the label of tObject to "Auto connect"
   set the hilite of tObject to true
   shootName tStack, tObject, "s1-check-on"

   -- Push buttons with no colours
   create button "mdConnect"
   put it into tObject
   set the style of tObject to "standard"
   set the rect of tObject to 32,220,172,256
   set the textSize of tObject to kTextSize
   set the textStyle of tObject to "bold"
   set the traversalOn of tObject to false
   set the label of tObject to "Connect"
   shootName tStack, tObject, "s1-push"
   shootFace tStack, tObject, "s1-push-face"

   -- A scrolling field: opaque, white, a border colour, a vertical
   -- scrollbar, no text colour
   repeat with i = 1 to 60
      put "Message " & i & return after tText
   end repeat
   put newTextField("mdMessages", "32,318,668,488", tText) into tObject
   set the textSize of tObject to 12
   set the textStyle of tObject to empty
   set the opaque of tObject to true
   set the showBorder of tObject to true
   set the threeD of tObject to false
   set the borderWidth of tObject to 1
   set the borderColor of tObject to "225,229,236"
   set the backColor of tObject to "255,255,255"
   set the vScrollbar of tObject to true
   set the vScroll of tObject to 0
   put the rect of tObject into tRect
   shootRegion tStack, tRect, "s1-messages", scrollbarRegion("track", item 3 of tRect - item 1 of tRect, item 4 of tRect - item 2 of tRect, the borderWidth of tObject, the scrollbarWidth of tObject)

   exportStackRect tStack, the rect of card 1 of stack tStack, "s1-card.png"

   addRecord "INFO", "s1HostEffectiveForeColor", the effective foreColor of tHost
   if sHasAppearance then
      do "put the effective stackAppearance of stack tStack into tValue"
      addRecord "INFO", "s1EffectiveStackAppearance", tValue
   end if
end renderOwnerPattern

-- S2 (and the S8 copies): a stack that sets no colours: a field with a
-- border and text, a transparent label, a checkbox, a push button and a
-- line. In the dark appearance it is dark. pAppearance, when given, is the
-- stack's stackAppearance (S8), set before anything is created in it.
private command renderUnstyled pPrefix, pAppearance
   local tStack, tObject, tRect, tValue
   put "oxt_render_" & pPrefix into tStack
   newScenarioStack tStack, 400, 300
   if pAppearance is not empty then
      do "set the stackAppearance of stack tStack to " & quote & pAppearance & quote
   end if

   put newTextField("field", "20,20,220,60", "Some text") into tObject
   shootText tStack, tObject, pPrefix & "-field"
   put the rect of tObject into tRect
   -- The field's fill, below the text
   shootRegion tStack, tRect, pPrefix & "-field-fill", "8,30,184,6"

   put newTextField("label", "240,20,380,50", "Label") into tObject
   makeLabel tObject
   shootText tStack, tObject, pPrefix & "-label"

   create button "check"
   put it into tObject
   set the style of tObject to "checkbox"
   set the rect of tObject to 20,80,200,108
   set the textSize of tObject to kTextSize
   set the textStyle of tObject to "bold"
   set the traversalOn of tObject to false
   set the label of tObject to "Checkbox"
   shootName tStack, tObject, pPrefix & "-check"

   create button "push"
   put it into tObject
   set the style of tObject to "standard"
   set the rect of tObject to 220,80,360,116
   set the textSize of tObject to kTextSize
   set the textStyle of tObject to "bold"
   set the traversalOn of tObject to false
   set the label of tObject to "Push"
   shootName tStack, tObject, pPrefix & "-push"

   create graphic "line"
   put it into tObject
   set the style of tObject to "line"
   set the lineSize of tObject to 3
   set the points of tObject to "20,150" & return & "360,150"
   shootFace tStack, tObject, pPrefix & "-line", "10,140,370,160"

   -- The card, away from every control
   shootRegion tStack, "300,200,400,300", pPrefix & "-card", "20,20,60,60"

   exportStackRect tStack, the rect of card 1 of stack tStack, pPrefix & ".png"

   if sHasAppearance then
      do "put the effective stackAppearance of stack tStack into tValue"
      addRecord "INFO", pPrefix & "EffectiveStackAppearance", tValue
   end if
end renderUnstyled

-- S3: a card of 30,30,30 and nothing else: a label with no colours
private command renderDarkDesigned
   local tStack, tObject
   put "oxt_render_s3" into tStack
   newScenarioStack tStack, 400, 200
   set the backColor of card 1 of stack tStack to "30,30,30"
   put newTextField("label", "20,20,300,56", "Dark card") into tObject
   makeLabel tObject
   shootText tStack, tObject, "s3-text"
end renderDarkDesigned

-- S4: fields with black text of their own and no background colour, on a
-- card with no colours: a black text colour was meant for a light fill
private command renderExplicitText
   local tStack, tObject, tRect
   put "oxt_render_s4" into tStack
   newScenarioStack tStack, 400, 200

   put newTextField("bordered", "20,20,220,60", "Black") into tObject
   set the opaque of tObject to true
   set the textColor of tObject to "0,0,0"
   put the rect of tObject into tRect
   shootRegion tStack, tRect, "s4-bordered-fill", "8,30,184,6"

   put newTextField("borderless", "20,80,220,120", "Black") into tObject
   set the opaque of tObject to true
   set the showBorder of tObject to false
   set the textColor of tObject to "0,0,0"
   put the rect of tObject into tRect
   shootRegion tStack, tRect, "s4-borderless-fill", "8,30,184,6"

   -- A known limit: a transparent label with a dark text colour of its own
   -- on a card with no colour stays dark on the dark card (recorded only)
   put newTextField("label", "240,20,380,56", "Black") into tObject
   makeLabel tObject
   set the textColor of tObject to "0,0,0"
   shootText tStack, tObject, "s4-label"
end renderExplicitText

-- S5: a field with both colours of its own is drawn as set, in every run
private command renderExplicitBoth
   local tStack, tObject
   put "oxt_render_s5" into tStack
   newScenarioStack tStack, 300, 100
   put newTextField("both", "20,20,260,60", "Explicit") into tObject
   set the opaque of tObject to true
   set the backColor of tObject to "40,40,40"
   set the foreColor of tObject to "220,220,220"
   exportStackRect tStack, the rect of tObject, "s5.png"
end renderExplicitBoth

-- S6: text runs. In a white field: text with no colour of its own, a red
-- run and a run with a yellow background. In a field with no colours: a
-- run with a yellow background and plain text.
private command renderStyledRuns
   local tStack, tObject
   put "oxt_render_s6" into tStack
   newScenarioStack tStack, 400, 360

   put newTextField("plain", "20,20,260,60", "Plain text") into tObject
   set the opaque of tObject to true
   set the backColor of tObject to "255,255,255"
   shootText tStack, tObject, "s6-plain"

   put newTextField("red", "20,80,260,120", "Red text") into tObject
   set the opaque of tObject to true
   set the backColor of tObject to "255,255,255"
   set the textColor of char 1 to -1 of field "red" of card 1 of stack tStack to "255,0,0"
   shootText tStack, tObject, "s6-red"

   put newTextField("yellow", "20,140,260,180", "Yellow run") into tObject
   set the opaque of tObject to true
   set the backColor of tObject to "255,255,255"
   set the backgroundColor of char 1 to -1 of field "yellow" of card 1 of stack tStack to "255,255,0"
   shootText tStack, tObject, "s6-yellow", "255,255,0"

   put newTextField("unstyledYellow", "20,200,260,240", "Yellow run") into tObject
   set the backgroundColor of char 1 to -1 of field "unstyledYellow" of card 1 of stack tStack to "255,255,0"
   shootText tStack, tObject, "s6-unstyled-yellow", "255,255,0"

   put newTextField("unstyledPlain", "20,260,260,300", "Plain text") into tObject
   shootText tStack, tObject, "s6-unstyled-plain"
end renderStyledRuns

-- S7: push buttons with a light and a dark background of their own and no
-- text colour: the label fits the background in the dark appearance
private command renderButtonColours
   local tStack, tObject
   put "oxt_render_s7" into tStack
   newScenarioStack tStack, 400, 160

   create button "white"
   put it into tObject
   set the style of tObject to "standard"
   set the rect of tObject to 20,20,180,60
   set the textSize of tObject to kTextSize
   set the textStyle of tObject to "bold"
   set the traversalOn of tObject to false
   set the backColor of tObject to "255,255,255"
   set the label of tObject to "White"
   shootName tStack, tObject, "s7-white"

   create button "dark"
   put it into tObject
   set the style of tObject to "standard"
   set the rect of tObject to 200,20,360,60
   set the textSize of tObject to kTextSize
   set the textStyle of tObject to "bold"
   set the traversalOn of tObject to false
   set the backColor of tObject to "50,50,50"
   set the label of tObject to "Dark"
   shootName tStack, tObject, "s7-dark"
end renderButtonColours

--------------------------------------------------------------------------------

-- Any parameters after pValue are further fields, left out when empty
private command addRecord pKind, pName, pValue
   local tLine
   put pKind & tab & pName & tab & oneLine(pValue) into tLine
   repeat with i = 4 to the paramCount
      if param(i) is not empty then put tab & param(i) after tLine
   end repeat
   put tLine & return after sReport
   write tLine & return to stdout
end addRecord

private function oneLine pText
   replace return with " " in pText
   replace numToCodepoint(13) with " " in pText
   replace tab with " " in pText
   return pText
end oneLine

private command finishRun
   put textEncode(sReport, "UTF-8") into URL ("binfile:" & sOut & "/render.txt")
   if sReport contains (return & "ERROR" & tab) or sReport begins with ("ERROR" & tab) then
      quit 2
   end if
   quit 0
end finishRun
