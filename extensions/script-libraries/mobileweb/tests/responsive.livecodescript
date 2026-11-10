script "TestMobileWebResponsive"
/*
Copyright (C) 2026 OXT-Beyond contributors.

This file is part of OXT-Beyond.

OXT-Beyond is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License v3 as published by the Free
Software Foundation.

OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

-- The Mobile Web library's layouts for a phone, a tablet and a desktop
-- (mwResponsive, mwApplyLayout, mwFlow, mwLayoutClass), on a desktop
-- engine: they work the same there as in a browser, as they go by the
-- stack's size. The stack's size changes are made by setting its rect,
-- for which the engine sends resizeStack, as when a window is resized.
-- tools/ci/responsive_web_check.py checks the Responsive Starter in the
-- web engine at a phone's, a tablet's and a desktop's sizes.

local sLib

on TestSetup
   local tScript, i
   put TestGetEngineRepositoryPath() & "/extensions/script-libraries/mobileweb/mobileweb.livecodescript" into sLib
   start using stack sLib
   create stack "ResponsiveTest"
   set the resizable of stack "ResponsiveTest" to true
   set the rect of stack "ResponsiveTest" to 0, 0, 400, 700
   -- the card writes down each layoutChanged, and each resizeStack it
   -- passes on (a ~ stands for a quote)
   put "global gGot" & return & \
         "on layoutChanged pClass, pOrientation" & return & \
         "   put ~layout ~ & pClass & comma & pOrientation & return after gGot" & return & \
         "end layoutChanged" into tScript
   replace "~" with quote in tScript
   set the script of card 1 of stack "ResponsiveTest" to tScript
   create button "Fixed" in card 1 of stack "ResponsiveTest"
   set the rect of button "Fixed" of card 1 of stack "ResponsiveTest" to 10, 10, 60, 40
   create button "Bar" in card 1 of stack "ResponsiveTest"
   set the rect of button "Bar" of card 1 of stack "ResponsiveTest" to 0, 0, 100, 50
   create field "Side" in card 1 of stack "ResponsiveTest"
   set the rect of field "Side" of card 1 of stack "ResponsiveTest" to 0, 0, 100, 100
   -- a group of five tiles, one of them hidden, then a group in it
   create group "Tiles" in card 1 of stack "ResponsiveTest"
   repeat with i = 1 to 5
      create button ("Tile" && i) in group "Tiles" of card 1 of stack "ResponsiveTest"
      set the rect of button ("Tile" && i) of card 1 of stack "ResponsiveTest" to 0, 0, 50, 40 + i * 10
   end repeat
   hide button "Tile 4" of card 1 of stack "ResponsiveTest"
   create group "Nest" in group "Tiles" of card 1 of stack "ResponsiveTest"
   create button "Inner" in group "Nest" of card 1 of stack "ResponsiveTest"
   set the rect of button "Inner" of card 1 of stack "ResponsiveTest" to 0, 0, 50, 30
end TestSetup

on TestTearDown
   global gGot
   send "mwSetBreakpoints" to stack sLib
   send "mwResponsive" && quote & "ResponsiveTest" & quote & ", false" to stack sLib
   if there is a stack "ResponsiveTest" then
      delete stack "ResponsiveTest"
   end if
   stop using stack sLib
   put empty into gGot
end TestTearDown

private function _Got
   global gGot
   return gGot
end _Got

private command _ClearGot
   global gGot
   put empty into gGot
end _ClearGot

-- The stack resized: the engine sends resizeStack when its rect is set
-- (TestResizeStackGoesOn sees it)
private command _Resize pWidth, pHeight
   set the rect of stack "ResponsiveTest" to 0, 0, pWidth, pHeight
end _Resize

private function _Rect pName
   return the rect of control pName of card 1 of stack "ResponsiveTest"
end _Rect

on TestLayoutClass
   TestAssert "a narrow width is a phone's", mwLayoutClass(390) is "phone"
   TestAssert "a width of 599 is a phone's", mwLayoutClass(599) is "phone"
   TestAssert "a width of 600 is a tablet's", mwLayoutClass(600) is "tablet"
   TestAssert "a width of 1023 is a tablet's", mwLayoutClass(1023) is "tablet"
   TestAssert "a width of 1024 is a desktop's", mwLayoutClass(1024) is "desktop"
   TestAssert "a stack's width", mwLayoutClass("ResponsiveTest") is "phone"
   set the rect of stack "ResponsiveTest" to 0, 0, 800, 600
   TestAssert "a stack made wider is a tablet's", mwLayoutClass("ResponsiveTest") is "tablet"
   TestAssert "no such stack: empty", mwLayoutClass("No Such Stack Here") is empty
   TestAssert "the breakpoints at first", mwBreakpoints() is "600,1024"
end TestLayoutClass

on TestSetBreakpoints
   mwSetBreakpoints 500, 1200
   TestAssert "new breakpoints are taken", the result is empty and mwBreakpoints() is "500,1200"
   TestAssert "a width of 550 is now a tablet's", mwLayoutClass(550) is "tablet"
   TestAssert "a width of 1100 is now a tablet's", mwLayoutClass(1100) is "tablet"
   mwSetBreakpoints 900, 800
   TestAssert "a desktop narrower than a tablet is refused", the result is "bad breakpoints"
   mwSetBreakpoints "wide", 800
   TestAssert "a word is refused", the result is "bad breakpoints"
   mwSetBreakpoints 0, 800
   TestAssert "a width of 0 is refused", the result is "bad breakpoints"
   TestAssert "a refused change changes nothing", mwBreakpoints() is "500,1200"
   mwSetBreakpoints
   TestAssert "none goes back to the first", mwBreakpoints() is "600,1024"
end TestSetBreakpoints

on TestPointerAndAppearanceOffTheWeb
   TestAssert "a mouse on a desktop", mwPointer() is "mouse"
   TestAssert "dark or light", mwAppearance() is among the items of "dark,light"
end TestPointerAndAppearanceOffTheWeb

on TestRulesPlaceControls
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 0, right 0, top 0, height 56"
   set the mwLayout["phone"] of field "Side" of card 1 of stack "ResponsiveTest" to "hidden"
   set the mwLayout["desktop"] of field "Side" of card 1 of stack "ResponsiveTest" to "left 0, top 56, bottom 0, width 25%"
   set the mwLayout["tablet"] of field "Side" of card 1 of stack "ResponsiveTest" to "right 10, bottom 10, width 200, height 50%"
   mwApplyLayout "ResponsiveTest"
   TestAssert "no error", the result is empty
   TestAssert "phone: the bar spans the card", _Rect("Bar") is "0,0,400,56"
   TestAssert "phone: the side is hidden", not the visible of field "Side" of card 1 of stack "ResponsiveTest"
   TestAssert "a control without rules is left alone", _Rect("Fixed") is "10,10,60,40"

   set the rect of stack "ResponsiveTest" to 0, 0, 800, 600
   mwApplyLayout "ResponsiveTest"
   TestAssert "tablet: the bar spans the card", _Rect("Bar") is "0,0,800,56"
   TestAssert "tablet: the side is shown", the visible of field "Side" of card 1 of stack "ResponsiveTest"
   TestAssert "tablet: from the right and the bottom, a percentage high", _Rect("Side") is "590,290,790,590"

   set the rect of stack "ResponsiveTest" to 0, 0, 1200, 800
   mwApplyLayout "ResponsiveTest"
   TestAssert "desktop: a quarter of the width, top to bottom", _Rect("Side") is "0,56,300,800"
   TestAssert "a control without rules is still left alone", _Rect("Fixed") is "10,10,60,40"
end TestRulesPlaceControls

on TestRulesByOrientation
   set the mwLayout["phone"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 0, right 0, top 0, height 56"
   set the mwLayout["phone landscape"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 0, right 0, top 0, height 40"
   set the rect of stack "ResponsiveTest" to 0, 0, 400, 700
   mwApplyLayout "ResponsiveTest"
   TestAssert "upright: the phone rule", _Rect("Bar") is "0,0,400,56"
   set the rect of stack "ResponsiveTest" to 0, 0, 560, 380
   mwApplyLayout "ResponsiveTest"
   TestAssert "on its side: the phone landscape rule", _Rect("Bar") is "0,0,560,40"
   set the rect of stack "ResponsiveTest" to 0, 0, 900, 400
   mwApplyLayout "ResponsiveTest"
   TestAssert "a tablet with no rule of its own: left alone", _Rect("Bar") is "0,0,560,40"
end TestRulesByOrientation

on TestRulesKeepWhatTheyDoNotSay
   set the rect of button "Bar" of card 1 of stack "ResponsiveTest" to 20, 30, 120, 80
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "right 10"
   mwApplyLayout "ResponsiveTest"
   TestAssert "from the right, keeping its width and top", _Rect("Bar") is "290,30,390,80"
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "bottom 0, height 20"
   mwApplyLayout "ResponsiveTest"
   TestAssert "at the bottom, keeping its left and width", _Rect("Bar") is "290,680,390,700"
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "width 50%"
   mwApplyLayout "ResponsiveTest"
   TestAssert "half as wide as the card, keeping its left", _Rect("Bar") is "290,680,490,700"
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 10, right 300"
   mwApplyLayout "ResponsiveTest"
   TestAssert "between the two edges", _Rect("Bar") is "10,680,100,700"
end TestRulesKeepWhatTheyDoNotSay

on TestBadRules
   set the rect of button "Bar" of card 1 of stack "ResponsiveTest" to 20, 30, 120, 80
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 5, top lots, spin 3"
   mwApplyLayout "ResponsiveTest"
   TestAssert "a bad rule is reported", the result begins with "bad rule: Bar:"
   TestAssert "what can be read is followed", _Rect("Bar") is "5,30,105,80"
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 5 6"
   mwApplyLayout "ResponsiveTest"
   TestAssert "two numbers are bad", the result begins with "bad rule: Bar:"
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 5, flow 0"
   mwApplyLayout "ResponsiveTest"
   TestAssert "a flow of 0 is bad", the result begins with "bad rule: Bar:"
   mwApplyLayout "No Such Stack Here"
   TestAssert "no such stack", the result begins with "no such stack"
end TestBadRules

on TestRulesOnEveryCard
   create card in stack "ResponsiveTest"
   create button "Elsewhere" in card 2 of stack "ResponsiveTest"
   set the mwLayout["all"] of button "Elsewhere" of card 2 of stack "ResponsiveTest" to "left 0, right 0"
   mwApplyLayout "ResponsiveTest"
   TestAssert "a control on another card is laid out too", \
         item 1 of the rect of button "Elsewhere" of card 2 of stack "ResponsiveTest" is 0 and \
         item 3 of the rect of button "Elsewhere" of card 2 of stack "ResponsiveTest" is 400
end TestRulesOnEveryCard

on TestFlow
   local tGroup, tHeight, tOffset
   put the long id of group "Tiles" of card 1 of stack "ResponsiveTest" into tGroup
   put the top of button "Inner" of tGroup - the top of group "Nest" of tGroup into tOffset
   set the rect of tGroup to 0, 100, 400, 700
   mwFlow tGroup, 2, 10
   put the result into tHeight
   -- the tiles in two columns of 185: 1 and 2, 3 and (4 hidden) 5, then
   -- the group Nest
   TestAssert "tile 1 at the top left", the rect of button "Tile 1" of tGroup is "10,110,195,160"
   TestAssert "tile 2 beside it", the rect of button "Tile 2" of tGroup is "205,110,390,170"
   TestAssert "tile 3 below the taller of the row", the rect of button "Tile 3" of tGroup is "10,180,195,250"
   TestAssert "the hidden tile is left out", the rect of button "Tile 5" of tGroup is "205,180,390,270"
   TestAssert "a group in it is one control", item 1 of the rect of group "Nest" of tGroup is 10 and \
         item 2 of the rect of group "Nest" of tGroup is 280
   TestAssert "and its own controls go with it", the top of button "Inner" of tGroup - 280 is tOffset
   TestAssert "the height used", tHeight is 280 + the height of group "Nest" of tGroup + 10 - 100
   TestAssert "the group keeps its rect", the rect of tGroup is "0,100,400,700"
   mwFlow tGroup, 1, 0
   TestAssert "one column, no gap", the rect of button "Tile 1" of tGroup is "0,100,400,150" and \
         item 2 of the rect of button "Tile 2" of tGroup is 150
   mwFlow "no group here"
   TestAssert "not a group", the result is "no such group"
   mwFlow the long id of button "Fixed" of card 1 of stack "ResponsiveTest"
   TestAssert "a button is not a group", the result is "no such group"
end TestFlow

on TestFlowColumnsByClass
   local tGroup
   put the long id of group "Tiles" of card 1 of stack "ResponsiveTest" into tGroup
   set the mwLayout["all"] of tGroup to "left 0, right 0, top 0, bottom 0, flow, gap 0"
   mwApplyLayout "ResponsiveTest"
   TestAssert "phone: one column", the left of button "Tile 2" of tGroup is 0
   set the rect of stack "ResponsiveTest" to 0, 0, 800, 600
   mwApplyLayout "ResponsiveTest"
   TestAssert "tablet: two columns", the left of button "Tile 2" of tGroup is 400
   set the rect of stack "ResponsiveTest" to 0, 0, 1200, 600
   mwApplyLayout "ResponsiveTest"
   TestAssert "desktop: three columns", the left of button "Tile 3" of tGroup is 800
   set the mwLayout["all"] of tGroup to "left 0, right 0, top 0, bottom 0, flow 4, gap 0"
   mwApplyLayout "ResponsiveTest"
   TestAssert "flow 4: four columns", the left of button "Tile 3" of tGroup is 600
end TestFlowColumnsByClass

on TestResponsiveSendsLayoutChanged
   _ClearGot
   mwResponsive "ResponsiveTest"
   TestAssert "started", the result is empty
   TestAssert "layoutChanged at once", _Got() is "layout phone,portrait" & return
   _ClearGot
   _Resize 420, 720
   TestAssert "no message within the same layout", _Got() is empty
   _Resize 800, 1000
   TestAssert "a tablet's width", _Got() is "layout tablet,portrait" & return
   _ClearGot
   _Resize 1000, 800
   TestAssert "turned", _Got() is "layout tablet,landscape" & return
   _ClearGot
   _Resize 1280, 800
   TestAssert "a desktop's width", _Got() is "layout desktop,landscape" & return
   _ClearGot
   mwSetBreakpoints 600, 1400
   TestAssert "new breakpoints lay it out again", _Got() is "layout tablet,landscape" & return
   _ClearGot
   mwResponsive "ResponsiveTest", false
   _Resize 400, 700
   TestAssert "no message after it stops", _Got() is empty
   mwResponsive "No Such Stack Here"
   TestAssert "no such stack", the result begins with "no such stack"
end TestResponsiveSendsLayoutChanged

-- extensionFinalize (the library unloaded, as when the IDE reloads its
-- extensions) forgets the stacks mwResponsive lays out: loaded again,
-- the library lays out only those a stack asks for again. Until this
-- was fixed the handler cleared two handler locals of the same names
-- (the script locals are declared below it), so a stack started before
-- the reload still got layoutChanged after it
on TestFinalizeForgetsResponsiveStacks
   mwResponsive "ResponsiveTest"
   _ClearGot
   send "extensionFinalize" to stack sLib
   _Resize 800, 1000
   TestAssert "forgotten: no layoutChanged after finalize", _Got() is empty
   mwResponsive "ResponsiveTest"
   TestAssert "asked again: laid out again", _Got() is "layout tablet,portrait" & return
end TestFinalizeForgetsResponsiveStacks

on TestResponsiveFollowsRulesOnResize
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 0, right 0, top 0, height 56"
   _Resize 500, 700
   TestAssert "not started: the rules wait", _Rect("Bar") is "0,0,100,50"
   mwResponsive "ResponsiveTest"
   TestAssert "started: the rules are followed", _Rect("Bar") is "0,0,500,56"
   _Resize 700, 700
   TestAssert "resized: followed again", _Rect("Bar") is "0,0,700,56"
end TestResponsiveFollowsRulesOnResize

on TestResizeStackGoesOn
   -- a backscript after the library still gets resizeStack
   local tScript
   create button "Watcher" in card 1 of stack "ResponsiveTest"
   put "global gGot" & return & "on resizeStack" & return & \
         "   put ~resize~ & return after gGot" & return & \
         "   pass resizeStack" & return & "end resizeStack" into tScript
   replace "~" with quote in tScript
   set the script of button "Watcher" of card 1 of stack "ResponsiveTest" to tScript
   insert the script of button "Watcher" of card 1 of stack "ResponsiveTest" into back
   mwResponsive "ResponsiveTest"
   _ClearGot
   _Resize 410, 700
   TestAssert "a stack mwResponsive lays out: passed on", _Got() is "resize" & return
   mwResponsive "ResponsiveTest", false
   _ClearGot
   _Resize 420, 700
   TestAssert "any other stack: passed on", _Got() is "resize" & return
   remove the script of button "Watcher" of card 1 of stack "ResponsiveTest" from back
end TestResizeStackGoesOn

on TestRulesWaitForThoseThatAsk
   -- a stack that never calls the library: rules or not, nothing moves
   set the mwLayout["all"] of button "Bar" of card 1 of stack "ResponsiveTest" to "left 0, right 0"
   _Resize 600, 700
   TestAssert "nothing moves without mwResponsive or mwApplyLayout", _Rect("Bar") is "0,0,100,50"
   _Resize 1200, 700
   TestAssert "nor at a desktop's width", _Rect("Bar") is "0,0,100,50"
end TestRulesWaitForThoseThatAsk

on TestRuleMovesAGroupWithItsControls
   local tNest, tOffset
   put the long id of group "Nest" of card 1 of stack "ResponsiveTest" into tNest
   put the top of button "Inner" of tNest - the top of tNest into tOffset
   set the mwLayout["all"] of tNest to "left 100, top 300"
   mwApplyLayout "ResponsiveTest"
   TestAssert "the group is placed", item 1 to 2 of the rect of tNest is "100,300"
   TestAssert "its controls go with it", the top of button "Inner" of tNest - the top of tNest is tOffset
end TestRuleMovesAGroupWithItsControls

on TestHiddenByARuleShownByTheNext
   local tSide
   put the long id of field "Side" of card 1 of stack "ResponsiveTest" into tSide
   set the mwLayout["phone"] of tSide to "hidden"
   set the mwLayout["tablet"] of tSide to "left 0, width 100"
   mwApplyLayout "ResponsiveTest"
   TestAssert "hidden by the phone rule", not the visible of tSide
   set the rect of stack "ResponsiveTest" to 0, 0, 800, 600
   mwApplyLayout "ResponsiveTest"
   TestAssert "shown by the tablet rule", the visible of tSide
   -- a control a script hides stays hidden whatever the rule
   hide tSide
   set the rect of stack "ResponsiveTest" to 0, 0, 820, 600
   mwApplyLayout "ResponsiveTest"
   TestAssert "a control a script hid stays hidden", not the visible of tSide
   set the rect of stack "ResponsiveTest" to 0, 0, 400, 600
   mwApplyLayout "ResponsiveTest"
   set the rect of stack "ResponsiveTest" to 0, 0, 800, 600
   mwApplyLayout "ResponsiveTest"
   TestAssert "and through a hidden layout and back", not the visible of tSide
end TestHiddenByARuleShownByTheNext

on TestHiddenByARuleKeptWithTheStack
   -- the mark that a rule hid it is the control's own, so it lasts
   -- when the stack is saved and opened again (and the library's
   -- memory is gone)
   local tSide
   put the long id of field "Side" of card 1 of stack "ResponsiveTest" into tSide
   set the mwLayout["phone"] of tSide to "hidden"
   set the mwLayout["tablet"] of tSide to "left 0"
   mwApplyLayout "ResponsiveTest"
   TestAssert "marked as hidden by a rule", the mwLayoutHid of tSide is true
   stop using stack sLib
   start using stack sLib
   set the rect of stack "ResponsiveTest" to 0, 0, 800, 600
   mwApplyLayout "ResponsiveTest"
   TestAssert "shown again by the library started afresh", the visible of tSide
end TestHiddenByARuleKeptWithTheStack

on TestWithinAGroup
   local tNest
   put the long id of group "Nest" of card 1 of stack "ResponsiveTest" into tNest
   set the mwLayout["all"] of tNest to "left 100, top 300, width 200, height 100"
   set the mwLayout["all"] of button "Inner" of tNest to "within, left 10, right 10, bottom 0, height 20"
   mwApplyLayout "ResponsiveTest"
   TestAssert "placed within its group", the rect of button "Inner" of tNest is "110,380,290,400"
   set the mwLayout["all"] of button "Inner" of tNest to "within, left 0, top 0, right 0, bottom 0, bleed"
   mwApplyLayout "ResponsiveTest"
   TestAssert "filling its group", the rect of button "Inner" of tNest is "100,300,300,400"
end TestWithinAGroup

on TestWithinAGroupOutsideTheWindow
   -- a card of a grid that is below the window (or scrolled above it) is
   -- laid out within itself, all of it, not within the part that shows
   local tNest
   put the long id of group "Nest" of card 1 of stack "ResponsiveTest" into tNest
   set the mwLayout["all"] of tNest to "left 100, top 650, width 200, height 100"
   set the mwLayout["all"] of button "Inner" of tNest to "within, left 0, top 0, right 0, bottom 0"
   mwApplyLayout "ResponsiveTest"
   TestAssert "below the window: the whole group", the rect of button "Inner" of tNest is "100,650,300,750"
   set the mwLayout["all"] of tNest to "left 100, top 900, width 200, height 100"
   mwApplyLayout "ResponsiveTest"
   TestAssert "all of it below the window: the whole group", the rect of button "Inner" of tNest is "100,900,300,1000"
   set the mwLayout["all"] of tNest to "left 100, top -60, width 200, height 100"
   mwApplyLayout "ResponsiveTest"
   TestAssert "above the window: the whole group", the rect of button "Inner" of tNest is "100,-60,300,40"
   set the mwLayout["all"] of button "Inner" of tNest to "within, left 10, right 10, bottom 0, height 20"
   set the mwLayout["all"] of tNest to "left 100, top 900, width 200, height 100"
   mwApplyLayout "ResponsiveTest"
   TestAssert "from the bottom of a group below the window", the rect of button "Inner" of tNest is "110,980,290,1000"
end TestWithinAGroupOutsideTheWindow

on TestWithinACardOfAGrid
   -- a card of a grid lays itself out for its new width after the flow
   local tGroup
   put the long id of group "Tiles" of card 1 of stack "ResponsiveTest" into tGroup
   set the mwLayout["all"] of button "Inner" of tGroup to "within, left 0, right 0, top 0, height 30"
   set the rect of tGroup to 0, 100, 400, 700
   mwFlow tGroup, 2, 10
   TestAssert "the card's control spans the card's new width", \
         item 1 of the rect of button "Inner" of tGroup is item 1 of the rect of group "Nest" of tGroup and \
         item 3 of the rect of button "Inner" of tGroup is item 3 of the rect of group "Nest" of tGroup
   TestAssert "the card is a column wide", the width of group "Nest" of tGroup is 185
end TestWithinACardOfAGrid
