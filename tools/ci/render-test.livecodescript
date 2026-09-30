script "oxt_render_test"
-- Renders disabled controls and scrollbars with the native Windows theme
-- and writes them as PNG files, for tools/ci/render_check.py to measure:
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
--    screen              8x8 pixels of the screen, taken after a window was
--                        opened: that used to crash the engine
--
-- The native theme and the light and dark colours only exist with a user
-- interface, so this runs as the development engine's home stack, not with
-- -ui. tools/ci/render-test.ps1 copies it to <folder>/Startup.rev, the
-- first file the engine's environment stack (engine/src/environment) looks
-- for in its tools folder, and points REV_TOOLS_PATH at <folder>, so the
-- engine opens this script instead of the IDE. It sets Windows to dark or
-- light mode first (AppsUseLightTheme), once for each run.
--
-- Environment variables:
--    OXT_RENDER_OUT   folder for the PNG files and render.txt (required)
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
--    ERROR  <where> <message>
-- and ends with "INFO done true" when every image was written.
--
-- Nothing is ever shown: the stack is created invisible and the images are
-- rendered off screen ("export snapshot from rect ... of card"). The exit
-- code is 0 when the images were written and 2 when the script failed.

constant kStack = "oxt_render_test_controls"
-- Large bold text, so that each glyph has pixels fully covered by the
-- label colour, which render_check.py measures
constant kTextSize = 16

local sOut
local sReport

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
      renderControls
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

private command renderControls
   local tObject, tRect, tFieldText

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

   screenSnapshot
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
-- theme (MCScreenDC's gray_pixel, engine/src/w32dcs.cpp): the colour of
-- render_check.py's DISABLED_GREY, for the enabled reference labels
private function disabledGrey
   if the systemAppearance is "dark" then return "137,137,137"
   return "128,128,128"
end disabledGrey

-- Renders a rectangle of the card (card coordinates) off screen
private command exportRect pRect, pFile
   export snapshot from rect (pRect) of card 1 of stack kStack to file (sOut & "/" & pFile) as PNG
   if there is not a file (sOut & "/" & pFile) then
      throw "export snapshot wrote no file " & pFile & " (the result: " & the result & ")"
   end if
end exportRect

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
