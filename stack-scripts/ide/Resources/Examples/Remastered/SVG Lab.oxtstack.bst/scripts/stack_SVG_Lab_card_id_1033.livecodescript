script "stack_SVG_Lab_card_id_1033"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab" > card "Options" (id 1033)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- Compiles the SVG with the options ticked; Convert makes it into graphics (the IDE's
-- revIDEConvertDrawingToGraphics), and Export writes it out as SVG (drawingSvgDecompile)

constant kOptions = "styles,opacity,ids,clip,gradients"

on openCard
   svgRefresh
   pass openCard
end openCard

on closeCard
   -- (the graphics are made for the moment: the saved stack keeps none)
   optionsForget
   pass closeCard
end closeCard

-- The options ticked, as the compile takes them
function optionsList
   local tName, tList
   repeat for each item tName in kOptions
      if the hilite of button tName then
         put tName & comma after tList
      end if
   end repeat
   delete the last char of tList
   if the number of items of tList is the number of items of kOptions then
      return "all"
   end if
   return tList
end optionsList

command svgRefresh
   local tDrawing, tStart, tInfo, tOptions
   optionsForget
   put optionsList() into tOptions
   put the milliseconds into tStart
   put svgCompile(svgCurrent(), tOptions) into tDrawing
   if the result is not empty then
      put the result into field "Status"
      exit svgRefresh
   end if
   put the milliseconds - tStart into tStart
   set the text of image "Work" to tDrawing
   put drawingDecode(tDrawing) into tInfo
   put svgCurrentName() & ":" && the number of elements of tInfo["shapes"] && "shapes," && \
         the number of elements of tInfo["clips"] && "clips." & return & \
         "drawingSvgCompile(tSvg, " & quote & tOptions & quote & ") took" && tStart && "ms." into field "Status"
end svgRefresh

command optionsForget
   lock messages
   if there is a group "Work graphics" then
      delete group "Work graphics"
   end if
   unlock messages
   show image "Work"
end optionsForget

command optionsConvert
   local tGroup, tError
   if the environment is not "development" then
      put "Convert to Graphics is part of the IDE: open SVG Lab there." into field "Status"
      exit optionsConvert
   end if
   optionsForget
   put revIDEConvertDrawingToGraphics(the long id of image "Work") into tGroup
   put the result into tError
   if tError is not empty then
      put "Could not convert:" && tError into field "Status"
      exit optionsConvert
   end if
   hide image "Work"
   put "Made" && the number of graphics of tGroup && "polygon graphics, each with its colours, gradients and opacity." & \
         return & "Select one with the pointer tool to edit it; any change here compiles again." into field "Status"
end optionsConvert

command optionsExport
   local tSvg, tPath
   put drawingSvgDecompile(the text of image "Work") into tSvg
   if the result is not empty then
      put "Could not export:" && the result into field "Status"
      exit optionsExport
   end if
   ask file "Save the SVG as:" with "exported.svg"
   put it into tPath
   if tPath is empty then
      exit optionsExport
   end if
   put textEncode(tSvg, "UTF-8") into url ("binfile:" & tPath)
   if the result is not empty then
      put "Could not write the file:" && the result into field "Status"
      exit optionsExport
   end if
   put "drawingSvgDecompile wrote" && the number of bytes of tSvg && "bytes of SVG." into field "Status"
end optionsExport
