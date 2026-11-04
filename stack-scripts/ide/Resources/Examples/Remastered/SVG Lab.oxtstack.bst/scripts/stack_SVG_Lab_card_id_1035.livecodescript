script "stack_SVG_Lab_card_id_1035"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab" > card "Recolor" (id 1035)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- A drawing keeps its colours as plain text once drawingSvgDecompile writes it out, so a
-- script can restyle any SVG: decompile, change the colours, compile again

local sSvg, sColors, sMode, sPending

on openCard
   svgRefresh
   pass openCard
end openCard

command svgRefresh
   local tDrawing, tToken
   put svgCompile(svgCurrent(), "all") into tDrawing
   if the result is not empty then
      put the result into field "Status"
      exit svgRefresh
   end if
   set the text of image "Original" to tDrawing
   put drawingSvgDecompile(tDrawing) into sSvg
   put empty into sColors
   set the itemDelimiter to quote
   repeat for each item tToken in sSvg
      if char 1 of tToken is "#" and the number of chars of tToken is 7 then
         put true into sColors[tToken]
      end if
   end repeat
   if sMode is empty then
      put "Hue" into sMode
   end if
   recolorNow
end svgRefresh

command recolorMode pMode
   put pMode into sMode
   recolorNow
end recolorMode

-- A drag sends many messages: only the last one recolours
command recolorSoon
   if sPending is not empty then
      cancel sPending
   end if
   send "recolorNow" to me in 60 milliseconds
   put the result into sPending
end recolorSoon

command recolorNow
   local tMap, tColor, tOut, tToken, tDrawing, tStart
   put empty into sPending
   put the milliseconds into tStart
   repeat for each key tColor in sColors
      put recolorColor(tColor, sMode, the thumbPosition of scrollbar "Hue") into tMap[tColor]
   end repeat
   set the itemDelimiter to quote
   repeat for each item tToken in sSvg
      if tMap[tToken] is not empty then
         put tMap[tToken] & quote after tOut
      else
         put tToken & quote after tOut
      end if
   end repeat
   delete the last char of tOut
   put svgCompile(tOut, "all") into tDrawing
   if the result is not empty then
      put the result into field "Status"
      exit recolorNow
   end if
   set the text of image "Recolored" to tDrawing
   put sMode & ":" && the number of elements of sColors && "colours changed in the decompiled SVG, compiled again in" && \
         the milliseconds - tStart && "ms. The slider turns the hue." into field "Status"
end recolorNow

function recolorColor pColor, pMode, pHue
   local tR, tG, tB, tA, tC, tS, tGrey
   put baseConvert(char 2 to 3 of pColor, 16, 10) into tR
   put baseConvert(char 4 to 5 of pColor, 16, 10) into tG
   put baseConvert(char 6 to 7 of pColor, 16, 10) into tB
   put 0.213 * tR + 0.715 * tG + 0.072 * tB into tGrey
   switch pMode
      case "Hue"
         put pHue * pi / 180 into tA
         put cos(tA) into tC
         put sin(tA) into tS
         return recolorHex((0.213 + tC * 0.787 - tS * 0.213) * tR + (0.715 - tC * 0.715 - tS * 0.715) * tG + (0.072 - tC * 0.072 + tS * 0.928) * tB, \
               (0.213 - tC * 0.213 + tS * 0.143) * tR + (0.715 + tC * 0.285 + tS * 0.140) * tG + (0.072 - tC * 0.072 - tS * 0.283) * tB, \
               (0.213 - tC * 0.213 - tS * 0.787) * tR + (0.715 - tC * 0.715 + tS * 0.715) * tG + (0.072 + tC * 0.928 + tS * 0.072) * tB)
      case "Greyscale"
         return recolorHex(tGrey, tGrey, tGrey)
      case "Sepia"
         return recolorHex(tGrey * 1.07, tGrey * 0.74, tGrey * 0.43)
      case "Negative"
         return recolorHex(255 - tR, 255 - tG, 255 - tB)
      case "Blueprint"
         return recolorHex(tGrey * 0.25, tGrey * 0.55, 90 + tGrey * 0.65)
   end switch
   return pColor
end recolorColor

function recolorHex pR, pG, pB
   return format("#%02x%02x%02x", max(0, min(255, round(pR))), max(0, min(255, round(pG))), max(0, min(255, round(pB))))
end recolorHex
