script "OXTTestSvgLab"
-- OXT-Beyond: runs every card of the built "SVG Lab" on a real engine with
-- the drawing library loaded, and fails if one does not do what it says.
--
--    <install>/OXT-Beyond -ui tools/examples/test-svg-lab.livecodescript
--
-- (on Linux, under xvfb-run where there is no display). It opens
-- ide/Resources/Examples/Remastered/SVG Lab.oxtstack, or the stack in
-- OXT_SVG_LAB, and loads revXML and the drawing library from the install
-- it runs in (or the one in OXT_INSTALL), as build-examples does. Then:
--
--    Logo       the logo is drawn again and again, and Pause stops it
--    Compare    the old compile and the new differ, and the line moves
--    Options    each option alone changes the drawing or leaves it be as
--               the logo needs it; with clip off it has no clips; Convert
--               makes graphics in the IDE or says it needs the IDE
--    Zoom       both pictures grow alike, and the bitmap is a PNG
--    Recolor    every mode changes the colours, and the slider does too
--    Open SVG   an SVG of one's own (the stack's cUserSvg) reaches every
--               card, and Logo goes back to the logo
--
-- It writes a line for each check, PASS or FAIL, and ends with "DONE"
-- (exit code 0) or "FAILED <how many>" (exit code 1). With
-- OXT_SVG_LAB_SNAPS set to a folder, it saves a picture of each card there.

-- An SVG of one's own: a star clip over stripes, with a style sheet
constant kOwnSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><style>.a{fill:#e4572e}</style><defs><clipPath id='star.1'><polygon points='50,4 63,36 97,36 69,57 80,92 50,71 20,92 31,57 3,36 37,36'/></clipPath></defs><g clip-path='url(#star.1)'><rect class='a' width='100' height='50'/><rect y='50' width='100' height='50' fill='#17bebb'/></g></svg>"

local sFails, sStack

on startup
   local tInstall, tError
   set the itemDelimiter to slash
   put $OXT_SVG_LAB into sStack
   if sStack is empty then
      put item 1 to -4 of the filename of me & "/ide/Resources/Examples/Remastered/SVG Lab.oxtstack" into sStack
   end if
   put $OXT_INSTALL into tInstall
   if tInstall is empty then
      put the engine folder into tInstall
   end if
   set the itemDelimiter to comma
   put 0 into sFails
   try
      loadDrawing tInstall
      go stack sStack
      dispatch "svgUseLogo" to stack sStack
      go card 1 of stack sStack
      snap
      testLogo
      testCompare
      testOptions
      testZoom
      testRecolor
      testOwnSvg
      go card "How" of stack sStack
      snap
      go card 1 of stack sStack
   catch tError
      write "FAILED" && line 1 of tError & return to stdout
      quit 1
   end try
   if sFails > 0 then
      write "FAILED" && sFails & return to stdout
      quit 1
   end if
   write "DONE" & return to stdout
   quit 0
end startup

private command check pWhat, pOk, pDetail
   if pOk then
      write "PASS" && pWhat & return to stdout
   else
      add 1 to sFails
      write "FAIL" && pWhat & ":" && pDetail & return to stdout
   end if
end check

private command snap
   local tFolder
   put $OXT_SVG_LAB_SNAPS into tFolder
   if tFolder is not empty then
      export snapshot from this card to file (tFolder & "/" & format("%02d", the number of this card) & "-" & the short name of this card & ".png") as PNG
   end if
end snap

private command pause pMs
   wait pMs milliseconds with messages
end pause

private command testLogo
   local tFirst, tSecond, tStopped
   go card "Logo" of stack sStack
   pause 600
   put the text of image "Logo Live" into tFirst
   pause 600
   put the text of image "Logo Live" into tSecond
   check "Logo draws the logo", the number of bytes of tFirst > 1000, the number of bytes of tFirst && "bytes"
   check "Logo draws it again and again", tFirst is not tSecond, "the same drawing twice"
   check "Logo says nothing is wrong", "not loaded" is not in field "Status" and "did not compile" is not in field "Status", field "Status"
   snap
   send "mouseUp" to group "Pause"
   put the text of image "Logo Live" into tStopped
   pause 400
   check "Pause stops it", the text of image "Logo Live" is tStopped and field "Pause_label" of group "Pause" is "Play", field "Pause_label" of group "Pause"
   send "mouseUp" to group "Pause"
   check "Play starts it again", field "Pause_label" of group "Pause" is "Pause", field "Pause_label" of group "Pause"
end testLogo

private command testCompare
   go card "Compare" of stack sStack
   check "Compare draws both", the number of bytes of the text of image "Before" > 0 and the number of bytes of the text of image "After" > 0, field "Status"
   check "Compare: the old compile and the new differ", the text of image "Before" is not the text of image "After", "the same drawing"
   send "compareTo 400" to this card
   check "Compare: the line moves", the right of group "Wipe" is 400 and item 1 of line 1 of the points of graphic "Split" is 400, the rect of group "Wipe"
   snap
end testCompare

private command testOptions
   local tAll, tInfo, tName, tOne
   go card "Options" of stack sStack
   put the text of image "Work" into tAll
   check "Options: every option on", quote & "all" & quote is in field "Status", field "Status"
   put drawingDecode(tAll) into tInfo
   check "Options: the logo has its clips", the number of elements of tInfo["clips"] > 0, "no clips"
   set the hilite of button "clip" to false
   send "mouseUp" to button "clip"
   put drawingDecode(the text of image "Work") into tInfo
   check "Options: clip off, no clips", the number of elements of tInfo["clips"] is 0 and "styles,opacity,ids,gradients" is in field "Status", field "Status"
   set the hilite of button "clip" to true
   repeat for each item tName in "styles,opacity,ids"
      set the hilite of button tName to false
      send "mouseUp" to button tName
      put the text of image "Work" into tOne
      check "Options:" && tName && "changes the logo", tOne is not tAll, "the same drawing without it"
      set the hilite of button tName to true
   end repeat
   send "mouseUp" to button "styles"
   check "Options: all again", the text of image "Work" is tAll, field "Status"
   send "mouseUp" to group "Convert"
   if the environment is "development" then
      check "Convert makes graphics", there is a group "Work graphics" and not the visible of image "Work", field "Status"
   else
      check "Convert says it needs the IDE", "part of the IDE" is in field "Status", field "Status"
   end if
   snap
   send "mouseUp" to button "styles"
   check "Options: a compile takes the graphics away", there is no group "Work graphics" and the visible of image "Work", "graphics left"
end testOptions

private command testZoom
   local tWidth
   go card "Zoom" of stack sStack
   check "Zoom: a bitmap of the drawing", byteToNum(byte 2 of the text of image "Bitmap") is 80 and the number of bytes of the text of image "Vector" > 0, "not a PNG"
   put the width of image "Vector" into tWidth
   send "mouseUp" to group "Zoom In"
   check "Zoom in doubles both", the width of image "Vector" is tWidth * 2 and the width of image "Bitmap" is tWidth * 2, the width of image "Vector"
   snap
   send "mouseUp" to group "Zoom Out"
   check "Zoom out halves them", the width of image "Vector" is tWidth, the width of image "Vector"
end testZoom

private command testRecolor
   local tMode, tLast
   go card "Recolor" of stack sStack
   repeat for each item tMode in "Greyscale,Sepia,Negative,Blueprint,Hue"
      send "mouseUp" to group ("Mode " & tMode)
      check "Recolor:" && tMode, the text of image "Recolored" is not the text of image "Original" and tMode is in field "Status", field "Status"
   end repeat
   put the text of image "Recolored" into tLast
   set the thumbPosition of scrollbar "Hue" to 300
   send "recolorNow" to this card
   check "Recolor: the slider turns the hue", the text of image "Recolored" is not tLast, "the same colours"
   snap
end testRecolor

private command testOwnSvg
   local tCard
   set the cUserSvg of stack sStack to kOwnSvg
   set the cUserName of stack sStack to "star.svg"
   repeat for each item tCard in "Compare,Options,Zoom,Recolor"
      go card tCard of stack sStack
      check tCard && "shows one's own SVG", "did not compile" is not in field "Status" and "not loaded" is not in field "Status", field "Status"
   end repeat
   go card "Options" of stack sStack
   check "Options names one's own SVG", "star.svg" is in field "Status", field "Status"
   send "mouseUp" to group "Use Logo"
   check "Logo goes back to the logo", "OXT-Beyond logo" is in field "Status" and the cUserSvg of stack sStack is empty, field "Status"
end testOwnSvg

-- revXML and the drawing library, as the IDE loads them
private command loadDrawing pInstall
   local tHelper, tLibrary, tError
   try
      if the number of bytes of drawingSvgCompile("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'><path d='M0 0h4' stroke='#000'/></svg>") > 0 then
         exit loadDrawing
      end if
   catch tError
   end try
   put specialFolderPath("temporary") & "/oxt-svg-lab-xml-" & the milliseconds & "-" & random(1000000) & ".livecode" into tHelper
   create stack "oxtSvgLabXml"
   if the platform is "Win32" then
      set the externals of stack "oxtSvgLabXml" to pInstall & "/Externals/revxml.dll"
   else if the platform is "MacOS" then
      set the externals of stack "oxtSvgLabXml" to pInstall & "/Externals/revxml.bundle"
   else
      set the externals of stack "oxtSvgLabXml" to pInstall & "/Externals/revxml.so"
   end if
   save stack "oxtSvgLabXml" as tHelper
   delete stack "oxtSvgLabXml"
   start using stack tHelper
   delete file tHelper
   put pInstall & "/Extensions/com.livecode.library.drawing/drawing.livecodescript" into tLibrary
   if there is no file tLibrary then
      throw "no drawing library at " & tLibrary
   end if
   insert the script of me into back
   dispatch "extensionInitialize" to stack tLibrary
   if the number of bytes of drawingSvgCompile("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 4 4'><path d='M0 0h4' stroke='#000'/></svg>") is 0 then
      throw "the drawing library draws nothing: is revXML loaded?"
   end if
end loadDrawing

-- The library's start-up asks the standalone builder to include it: not here
on revSBAddDependencyForInclusion
end revSBAddDependencyForInclusion
