script "stack_SVG_Lab_card_id_1034"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab" > card "Zoom" (id 1034)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- The SVG as a drawing on the left, and as a 200 pixel bitmap of the same drawing on the
-- right, both zoomed by the same amount about the same spot

local sZoom, sFocusX, sFocusY

on openCard
   svgRefresh
   pass openCard
end openCard

command svgRefresh
   local tDrawing, tPng
   put svgCompile(svgCurrent(), "all") into tDrawing
   if the result is not empty then
      put the result into field "Status"
      exit svgRefresh
   end if
   lock screen
   set the text of image "Vector" to tDrawing
   set the rect of image "Vector" to 0, 0, 200, 200
   export snapshot from image "Vector" at size 200,200 to tPng as PNG
   set the text of image "Bitmap" to tPng
   set the resizeQuality of image "Bitmap" to "normal"
   set the cDrawingBytes of me to the number of bytes of tDrawing
   set the cPngBytes of me to the number of bytes of tPng
   put 0.5 into sFocusX
   put 0.5 into sFocusY
   if sZoom is empty then
      put 300 into sZoom
   end if
   zoomTo sZoom
   unlock screen
end svgRefresh

command zoomTo pPercent
   local tSize, tX, tY
   put max(100, min(1600, round(pPercent))) into sZoom
   put round(200 * sZoom / 100) into tSize
   put item 1 of the loc of group "VectorPanel" - round(tSize * sFocusX) into tX
   put item 2 of the loc of group "VectorPanel" - round(tSize * sFocusY) into tY
   set the rect of image "Vector" to tX, tY, tX + tSize, tY + tSize
   put item 1 of the loc of group "BitmapPanel" - round(tSize * sFocusX) into tX
   set the rect of image "Bitmap" to tX, tY, tX + tSize, tY + tSize
   put sZoom & "%: a" && the cDrawingBytes of me && "byte drawing, sharp at any size, beside a" && \
         the cPngBytes of me && "byte PNG of it. Click a picture to zoom in on that spot." into field "Status"
end zoomTo

command zoomBy pFactor
   zoomTo sZoom * pFactor
end zoomBy

-- A click on either picture puts that spot of both in the middle
command zoomFocus pImage
   put max(0, min(1, (the mouseH - the left of pImage) / the width of pImage)) into sFocusX
   put max(0, min(1, (the mouseV - the top of pImage) / the height of pImage)) into sFocusY
   zoomTo sZoom
end zoomFocus
