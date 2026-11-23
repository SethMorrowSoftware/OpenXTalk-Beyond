script "TestKitPageEnd"
-- OXT-Beyond: tests of revLearnKit's lkPageEnd
-- (ide/Toolset/palettes/learn/revlearnkit.livecodescript). The page of
-- File > Community Stacks, of the Release Notes and the panel of the
-- About window are labels of the kit (lkLabel: a top margin of 4, none
-- below) that scroll. The engine stops a field's scroll 12 points short of
-- its text and two margins (MCField::vscroll, TEXT_Y_OFFSET), so at the
-- end of the scroll the lower 8 points of the last line stayed below the
-- field: the Easing library's page in Community Stacks, reported for
-- 0.2.8-dp.2 on Linux and macOS. lkPageEnd gives such a field the bottom
-- margin the scroll needs.

-- Whether the kit was in memory before the test, which leaves it so
local sFound
-- The field the tests fill, made as the windows make their pages, in a
-- stack of the test's own
constant kField = "TestKitPageEndPage"
constant kStack = "TestKitPageEndSample"

on TestSetup
   TestSkipIfNot "ide"
   put there is a stack "revLearnKit" into sFound
   get the long id of stack (TestGetIDERepositoryPath() & "/Toolset/palettes/learn/revlearnkit.livecodescript")
   if there is a stack kStack then
      delete stack kStack
   end if
   create stack kStack
   set the rect of stack kStack to 100, 100, 700, 600
   set the defaultStack to kStack
   -- As the kit's lkLabel makes a label, and Community Stacks' csBuild
   -- its page: 14 point, lines 21 high, a margin of 14 at the right
   create field kField
   set the lockText of field kField of stack kStack to true
   set the showBorder of field kField of stack kStack to false
   set the opaque of field kField of stack kStack to false
   set the margins of field kField of stack kStack to "0,4,0,0"
   set the dontWrap of field kField of stack kStack to false
   set the textSize of field kField of stack kStack to 14
   set the rect of field kField of stack kStack to 20, 36, 500, 400
   set the textHeight of field kField of stack kStack to 21
   set the rightMargin of field kField of stack kStack to 14
end TestSetup

on TestTeardown
   if there is a stack kStack then
      delete stack kStack
   end if
   if sFound is not true and there is a stack "revLearnKit" then
      delete stack "revLearnKit"
   end if
end TestTeardown

-- A page longer than the field: a description at 16 points, as the
-- window puts one first, and lines with letters that reach below them
private command __FillLong
   local tHtml, tCount
   put "<p><font size=" & quote & "16" & quote & ">What the library does, at sixteen points</font></p>" into tHtml
   repeat with tCount = 1 to 60
      put "<p>Line" && tCount && "of a long page, with gypsy letters</p>" after tHtml
   end repeat
   set the htmlText of field kField of stack kStack to tHtml
end __FillLong

-- How far the last line reaches below the field at the end of the scroll
private function __CutAtTheEnd
   local tRect
   set the vScroll of field kField of stack kStack to 30000
   put the formattedRect of line -1 of field kField of stack kStack into tRect
   TestDiagnostic "the last line is" && item 2 of tRect && "to" && item 4 of tRect && "in the field's" && \
         the top of field kField of stack kStack && "to" && the bottom of field kField of stack kStack & ", margins" && \
         the margins of field kField of stack kStack
   return max(0, item 4 of tRect - the bottom of field kField of stack kStack)
end __CutAtTheEnd

private command __PageEnd
   dispatch "lkPageEnd" to stack "revLearnKit" with the long id of field kField of stack kStack
end __PageEnd

on TestWithoutItTheLastLineIsCut
   -- (what the fix is for: if the engine's scroll ever goes on to the end
   -- of the text by itself, this says so)
   __FillLong
   TestAssert "the page is longer than the field", \
         the formattedHeight of field kField of stack kStack > the height of field kField of stack kStack
   TestAssert "a kit label's last line is cut at the end of the scroll", __CutAtTheEnd() > 0
end TestWithoutItTheLastLineIsCut

on TestTheLastLineComesWhollyIntoView
   __PageEnd
   __FillLong
   TestAssert "the last line is wholly in view at the end of the scroll", __CutAtTheEnd() is 0
end TestTheLastLineComesWhollyIntoView

on TestTheTextStartsWhereItDid
   local tBefore
   __FillLong
   set the vScroll of field kField of stack kStack to 0
   put the formattedRect of line 1 of field kField of stack kStack into tBefore
   __PageEnd
   set the vScroll of field kField of stack kStack to 0
   TestAssert "the first line is where it was", the formattedRect of line 1 of field kField of stack kStack is tBefore
   TestAssert "the top and side margins are as they were", \
         item 1 to 3 of the margins of field kField of stack kStack is "0,4,14"
end TestTheTextStartsWhereItDid

on TestABottomMarginAlreadyRoomyIsKept
   set the bottomMargin of field kField of stack kStack to 20
   __PageEnd
   TestAssert "a larger bottom margin is kept", the bottomMargin of field kField of stack kStack is 20
end TestABottomMarginAlreadyRoomyIsKept
