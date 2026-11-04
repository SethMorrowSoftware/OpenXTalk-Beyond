script "stack_SVG_Lab"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab"
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

--SVG Lab: what OXT-Beyond 0.2.7 does with SVG, made for OXT-Beyond in 2026

--Each card's program is its card's script. What they share is here: the SVG the cards show,
--which is the OXT-Beyond logo (the stack's cLogoSvg) until you open one of your own.

-- The SVG the cards show
function svgCurrent
   if the cUserSvg of me is not empty then
      return the cUserSvg of me
   end if
   return the cLogoSvg of me
end svgCurrent

function svgCurrentName
   if the cUserName of me is not empty then
      return the cUserName of me
   end if
   return "The OXT-Beyond logo"
end svgCurrentName

-- Asks for an SVG file, and shows it from now on; false when none was chosen
function svgOpenFile
   local tPath, tText
   answer file "Open an SVG file:" with type "SVG files|svg"
   put it into tPath
   if tPath is empty then
      return false
   end if
   put textDecode(url ("binfile:" & tPath), "UTF-8") into tText
   if tText is empty then
      return false
   end if
   set the cUserSvg of me to tText
   set the itemDelimiter to slash
   set the cUserName of me to the last item of tPath
   return true
end svgOpenFile

command svgUseLogo
   set the cUserSvg of me to empty
   set the cUserName of me to empty
end svgUseLogo

-- pSvg compiled with pOptions ("all", a comma list, or empty for none). An error, or the
-- drawing library missing where this stack runs, goes into the result
function svgCompile pSvg, pOptions
   local tDrawing, tError
   try
      put drawingSvgCompile(pSvg, pOptions) into tDrawing
   catch tError
      return "The drawing library is not loaded here: open SVG Lab in OXT-Beyond's IDE." for error
   end try
   if the result is not empty then
      return "The SVG did not compile:" && line 1 of the result for error
   end if
   return tDrawing for value
end svgCompile
