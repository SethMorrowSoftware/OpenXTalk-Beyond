script "stack_SVG_Lab_card_id_1032"
-- Stack file: ide/Resources/Examples/Remastered/SVG Lab.oxtstack
-- Object: stack "SVG Lab" > card "Compare" (id 1032)
-- Made from the stack by tools/oxt/stack-scripts.sh; the stack holds
-- the script that runs, so change it there, not here.

-- The same SVG twice: with no options under the group "Wipe", which shows the left of the
-- line, and with every option beside it. Dragging moves the line

local sDragging

on openCard
   svgRefresh
   pass openCard
end openCard

command svgRefresh
   local tSvg, tOld, tNew
   put svgCurrent() into tSvg
   put svgCompile(tSvg) into tOld
   if the result is not empty then
      put the result into field "Status"
      exit svgRefresh
   end if
   put svgCompile(tSvg, "all") into tNew
   lock screen
   set the text of image "Before" to tOld
   set the text of image "After" to tNew
   compareTo the cSplit of me
   unlock screen
   put svgCurrentName() & ":" && the number of bytes of tOld && "bytes with no options," && \
         the number of bytes of tNew && "with all." into field "Status"
end svgRefresh

-- The line at pX, and the old compile left of it
command compareTo pX
   local tLeft, tRight
   put the left of image "After" into tLeft
   put the right of image "After" into tRight
   put max(tLeft + 1, min(tRight, round(pX))) into pX
   set the cSplit of me to pX
   set the rect of group "Wipe" to tLeft, the top of image "After", pX, the bottom of image "After"
   set the points of graphic "Split" to pX & comma & the top of image "After" & return & pX & comma & the bottom of image "After"
end compareTo

on mouseDown
   if within(image "After", the mouseLoc) or the long id of the target is the long id of graphic "Split" then
      put true into sDragging
      compareTo the mouseH
   end if
   pass mouseDown
end mouseDown

on mouseMove pX, pY
   if sDragging then
      compareTo pX
   end if
   pass mouseMove
end mouseMove

on mouseUp
   put false into sDragging
   pass mouseUp
end mouseUp

on mouseRelease
   put false into sDragging
   pass mouseRelease
end mouseRelease
