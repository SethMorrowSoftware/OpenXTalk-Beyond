script "com.livecode.library.mobileweb"
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

-- OXT-Beyond: the Mobile Web library, for stacks that run in a phone's or
-- a tablet's browser (mobile-web/mobile-web-feasibility.md in the
-- project's files says why it is a library and not engine changes).
--
-- It changes nothing until a stack calls one of its handlers: it sends no
-- message of its own and handles none of the engine's. A stack that calls
-- mwStart gets the messages below, and only for what happens after it.
-- The gestures go to the control under the finger, as a mouse message
-- does, and on up the message path to its card and stack if it passes
-- them (or has no handler); the rest go to the current card, by the
-- names LiveCode's iOS and Android engines send them:
--
--    swipe pDirection              (left, right, up or down)
--    pinchStart pX, pY
--    pinch pScale, pX, pY
--    pinchEnd pScale
--    longPress pX, pY
--    orientationChanged
--    keyboardActivated
--    keyboardDeactivated
--
-- mwStart also makes the stack fit the browser's window: a resizable
-- stack fills it (and gets resizeStack, so a Geometry Manager layout or a
-- resizeStack handler lays it out), a stack of a fixed size that is too
-- big for it is scaled down to fit.
--
-- In the web engine it listens to the browser through JavaScript of its
-- own: the engine's touch handling is left as it is (one finger is the
-- mouse, em-event.js), and the library's listeners only look. The
-- browser calls back through the library stack's javascriptHandlers
-- (mwFromBrowser), a little after the event, so that a script never runs
-- inside one of the browser's event handlers. On a desktop the handlers
-- answer as a desktop would (no touch screen, no keyboard over the
-- stack) and the gestures are never sent, so a stack can be made and
-- tried in the IDE as it is.

on extensionInitialize
   if the target is not me then
      pass extensionInitialize
   end if

   insert the script of me into back

   if the environment contains "development" then
      set the _ideoverride of me to true
   end if
end extensionInitialize

on extensionFinalize
   if the target is not me then
      pass extensionFinalize
   end if

   mwStop
   remove the script of me from back
end extensionFinalize

/**
Title: Mobile Web Library

Author: OXT-Beyond

Version: 1.0.0

Description:
The Mobile Web library helps a stack work in the browser of a phone or a
tablet when it is built as an HTML5 standalone. It fills the screen with
the stack and keeps it filled when the phone turns, tells the stack how
much of it the on-screen keyboard covers, reports swipes, pinches and
long presses, and scrolls a field or group with a finger.

On a desktop it answers as a desktop would and sends no gestures, so a
stack that uses it can be made and tried in the IDE. Nothing changes for
a stack that does not call it.

Tags:
html5, mobile, touch
*/

constant kLibrary = "com.livecode.library.mobileweb"
constant kGestures = "swipe,pinch,longpress"

-- the stack that gets the library's messages, by its short name, and
-- whether mwStart has started the browser's side
local sTarget, sStarted
-- what mwStart was asked for: sOptions["gestures"], sOptions["fill"] or
-- sOptions["fit"] (the stack filled or fitted), sOptions["autofit"]
-- (the stack fitted only while it is too big for the window)
local sOptions
-- the keyboard's height and the orientation the browser last reported,
-- for keyboardActivated, keyboardDeactivated and orientationChanged
local sKeyboard, sOrientation
-- the control a pinch began over, which gets pinch and pinchEnd too
local sPinchTarget
-- the browser's last viewport (see mwViewport), as a list of
-- width,height,keyboard,top,right,bottom,left,orientation
local sViewport
-- mwDragScroll's glide: the object, its speed in pixels a tick, and the
-- message that moves it on
local sGlideObject, sGlideSpeed, sGlideMessage

-- mwDragScroll's drag: where it began, whether it has moved, and whether
-- the finger is still down (for mwDragMoved)
local sDragStartV, sDragMoved, sDragActive

/**
Whether the stack runs in a web browser.

Returns (boolean):
true in an HTML5 standalone and the web IDE, false everywhere else.

Example:
if mwIsWeb() then
   mwStart
end if

Description:
Use <mwIsWeb> to choose between what a stack does in a browser and what it
does on a desktop. It is the same as asking whether <platform> is "HTML5".

References: mwIsTouchScreen (function), mwStart (command)
*/
function mwIsWeb
   return the platform is "HTML5"
end mwIsWeb

/**
Whether the stack runs on a touch screen.

Returns (boolean):
true in a browser on a phone, a tablet, or a computer with a touch
screen; false on a desktop and in a browser that has no touch screen.

Example:
if mwIsTouchScreen() then
   set the textSize of field "Notes" to 18
end if

Description:
Use <mwIsTouchScreen> to make controls bigger, or to show hints such as
"swipe to go on", where a finger is used. In a browser, it is true when
the browser reports one touch point or more.

References: mwIsWeb (function)
*/
function mwIsTouchScreen
   if not mwIsWeb() then
      return false
   end if
   return mwJS("return (navigator.maxTouchPoints || 0) > 0 ? 'true' : 'false';") is "true"
end mwIsTouchScreen

/**
Whether the page was opened from the home screen, as an app.

Returns (boolean):
true when the browser shows the page as an installed app, without its
own bar; false in an ordinary tab and on a desktop.

Example:
if mwIsTouchScreen() and not mwIsInstalled() then
   answer "Tip: add this page to your home screen to keep your work."
end if

Description:
On iPhone and iPad, Safari deletes what a page keeps (the files a stack
saves) after some days without a visit, unless the page was added to the
home screen. Use <mwIsInstalled> to suggest adding it.

References: mwIsTouchScreen (function)
*/
function mwIsInstalled
   if not mwIsWeb() then
      return false
   end if
   return mwJS("return (window.matchMedia('(display-mode: standalone)').matches || " & \
         "window.navigator.standalone === true) ? 'true' : 'false';") is "true"
end mwIsInstalled

/**
Make a stack ready for a phone's browser: the screen, and the gestures.

Parameters:
pStack (string):
The name of the stack. Empty for the default stack.

pGestures (string):
A comma-separated list of the gestures to report: any of "swipe",
"pinch" and "longpress". Empty for all three; "none" for none.

pScreen (string):
How the stack meets the browser's window: "fill" (the stack is made as
big as the window), "fit" (the stack keeps its size and is scaled to
the window, see <mwFitStack>), "none" (the stack is left as it is), or
empty to choose: "fill" for a resizable stack, and for a stack of a
fixed size, "fit" while it is too big for the window.

Example:
on openStack
   mwStart
end openStack

-- in a card's script: a swipe anywhere on the card
on swipe pDirection
   if pDirection is "left" then go next card
   if pDirection is "right" then go previous card
end swipe

Example:
-- in the script of a graphic "Photo": a pinch over it
on pinch pScale
   set the width of me to round(200 * pScale)
end pinch

Description:
One line in openStack makes a stack ready for a phone. A resizable
stack fills the browser's window, and fills it again when the phone
turns; it gets resizeStack each time, as on a desktop, so the Geometry
Manager or a resizeStack handler lays it out (see <mwFillScreen>). A
stack of a fixed size that is too big for the window, such as one made
for a desktop, is scaled down to fit, and taps still reach the controls
under them (see <mwFitStack>).

After <mwStart> the stack gets these messages. The gestures go to the
control under the finger, as mouseDown does: a control that has no
handler for one, or passes it, sends it on to its group, its card and
its stack, so a card's script can handle every swipe on the card.

- swipe pDirection: a quick stroke of one finger: "left", "right", "up"
  or "down" (the way the finger went). It goes to the control where the
  stroke began.
- pinchStart pX, pY, then pinch pScale, pX, pY as two fingers move,
  and pinchEnd pScale: pScale is the distance between the fingers over
  their distance at the start, and pX, pY the point between them. All
  three go to the control under that point when the pinch began.
- longPress pX, pY: a finger held still for about half a second.

These go to the current card, as LiveCode's iOS and Android engines send
them:

- orientationChanged: the phone turned (after the stack has been filled
  or fitted again). <mwViewport> says which way it is now.
- keyboardActivated: the on-screen keyboard came up, or changed its
  height while up. <mwViewport> says how much of the page it covers.
- keyboardDeactivated: the keyboard went away.

Points are in the card's coordinates. The gestures come in addition to
the mouse messages that a touch already sends: a swipe is also a drag of
the mouse, and a long press ends in a mouseUp. A stack can ask
<mwLongPressed> in its mouseUp to tell one from a click.

On a desktop, <mwStart> only remembers the stack: the stack keeps its
size, and no gestures are sent, so a stack that calls it can be made and
tried in the IDE.

References: mwStop (command), mwViewport (function), mwFillScreen (command), mwFitStack (command)
*/
command mwStart pStack, pGestures, pScreen
   local tGestures, tGesture

   if pStack is empty then
      put the short name of the defaultStack into pStack
   end if
   if there is not a stack pStack then
      return "no such stack:" && pStack
   end if
   put the short name of stack pStack into sTarget

   if pGestures is empty then
      put kGestures into tGestures
   else if pGestures is "none" then
      put empty into tGestures
   else
      repeat for each item tGesture in pGestures
         put word 1 to -1 of tGesture into tGesture
         if tGesture is not among the items of kGestures then
            return "unknown gesture:" && tGesture
         end if
      end repeat
      put pGestures into tGestures
      replace space with empty in tGestures
   end if
   if pScreen is not among the items of ",fill,fit,none" then
      return "unknown screen:" && pScreen
   end if
   put tGestures into sOptions["gestures"]
   put empty into sKeyboard
   put empty into sOrientation
   put empty into sPinchTarget
   put empty into sViewport

   if not mwIsWeb() then
      return empty
   end if

   mwInstallBrowserSide
   get mwJS("window.__oxtMobileWeb.start(" & mwQuote(tGestures) & "); return '';")
   put true into sStarted

   -- what an earlier mwStart, mwFillScreen or mwFitStack chose is
   -- forgotten: the window's changes now go to this stack, or to none
   put empty into sOptions["fill"]
   put empty into sOptions["fit"]
   put empty into sOptions["autofit"]

   -- the screen: what was asked for, or what suits the stack
   if pScreen is empty then
      if the resizable of stack sTarget then
         put "fill" into pScreen
      else
         put "autofit" into pScreen
      end if
   end if
   switch pScreen
      case "fill"
         mwFillScreen sTarget
         break
      case "fit"
         mwFitStack sTarget
         break
      case "autofit"
         if mwJS("return window.__oxtMobileWeb.fillPage(true);") is not "no" then
            put sTarget into sOptions["autofit"]
            mwAutoFit
         end if
         break
   end switch
   return empty
end mwStart

/**
Stop the library's messages.

Example:
on closeStack
   mwStop
end closeStack

Description:
After <mwStop> no more of the library's messages are sent, and the
browser's listeners that <mwStart> added are removed. A stack that was
filling the screen keeps the size it has, and the page gets back its
margins and its scrolling.

References: mwStart (command)
*/
command mwStop
   put empty into sTarget
   put empty into sOptions
   put empty into sKeyboard
   put empty into sOrientation
   put empty into sPinchTarget
   mwGlideStop
   if mwIsWeb() then
      -- the listeners off, and the page as it was before mwFillScreen
      get mwJS("if (window.__oxtMobileWeb) { window.__oxtMobileWeb.stop(); window.__oxtMobileWeb.unfillPage(); } return '';")
   end if
   put false into sStarted
end mwStop

/**
The part of the page that the stack can be seen in.

Returns (array):
- "width" and "height": the size of the part of the page that can be
  seen, in pixels, without what the on-screen keyboard covers
- "keyboard": how many pixels at the bottom the keyboard covers (0 when
  it is not up)
- "top", "right", "bottom" and "left": the safe-area insets, the pixels
  at each edge under a notch, a rounded corner or the home bar (0 when
  the page does not reach those edges, or there are none)
- "orientation": "portrait" or "landscape"

Example:
local tView
put mwViewport() into tView
set the bottom of group "Form" to tView["height"] - 8

Description:
Use <mwViewport> to keep what matters where it can be seen: above the
keyboard, inside the safe area. The insets are 0 unless the page reaches
the edges of the screen, which <mwFillScreen> asks for.

On a desktop, the width and height are those of the screen the stack is
on, and the keyboard and insets are 0.

References: mwStart (command), mwFillScreen (command)
*/
function mwViewport
   local tList, tView, tRect

   -- after mwStart, what the browser last reported, so that it agrees
   -- with the messages sent for it; else what the browser says now
   if sStarted is true and the number of items of sViewport is 8 then
      put sViewport into tList
   else if mwIsWeb() then
      mwInstallBrowserSide
      put mwJS("return window.__oxtMobileWeb.viewport();") into tList
   end if
   if the number of items of tList is not 8 then
      put the screenRect into tRect
      put item 3 of tRect - item 1 of tRect, item 4 of tRect - item 2 of tRect, \
            0, 0, 0, 0, 0 into tList
      if item 1 of tList > item 2 of tList then
         put ",landscape" after tList
      else
         put ",portrait" after tList
      end if
   end if
   put item 1 of tList into tView["width"]
   put item 2 of tList into tView["height"]
   put item 3 of tList into tView["keyboard"]
   put item 4 of tList into tView["top"]
   put item 5 of tList into tView["right"]
   put item 6 of tList into tView["bottom"]
   put item 7 of tList into tView["left"]
   put item 8 of tList into tView["orientation"]
   return tView
end mwViewport

/**
Make a stack fill the browser's window, and keep it filling it.

Parameters:
pStack (string):
The stack to fill the page with. Empty for the stack that <mwStart>
named, or else the default stack.

Example:
on openStack
   mwStart the short name of me, empty, "none"
   mwFillScreen
end openStack

on resizeStack pWidth, pHeight
   set the rect of group "Content" to 0, 60, pWidth, pHeight - 56
end resizeStack

Description:
<mwStart> fills the screen with a resizable stack by itself; use
<mwFillScreen> for a stack whose size is fixed, or after
mwStart with "none". The stack becomes
as big as the browser's window, its page loses its margins and reaches
the screen's edges (use the insets of <mwViewport> to keep controls out
of the notch), and the stack is resized again when the phone turns.
The stack gets resizeStack each time, as a resizable desktop stack does,
so it lays itself out there.

The page itself keeps still: a finger cannot scroll or zoom it.
<mwStop> gives the page back its margins and lets it scroll again.

On a desktop, <mwFillScreen> does nothing: the stack keeps its size, as
it would in the IDE. Nor does it in a page that shows the stack inside
its own frame, such as the Stack Player's, which says so with the
attribute data-mobile-web-fill="no" on its html or body element: there
the result is "the page keeps its own layout" and the stack keeps its
size.

To show a stack that was laid out for a big screen, use <mwFitStack>.

References: mwFitStack (command), mwViewport (function), mwStart (command)
*/
command mwFillScreen pStack
   if pStack is empty then
      put mwTargetStack() into pStack
   end if
   if there is not a stack pStack then
      return "no such stack:" && pStack
   end if
   if not mwIsWeb() then
      return empty
   end if
   mwInstallBrowserSide
   if mwJS("return window.__oxtMobileWeb.fillPage();") is "no" then
      return "the page keeps its own layout"
   end if
   put the short name of stack pStack into sOptions["fill"]
   put empty into sOptions["fit"]
   put empty into sOptions["autofit"]
   if the fullscreen of stack pStack then
      set the fullscreen of stack pStack to false
   end if
   mwFill
   mwWatchViewport
   return empty
end mwFillScreen

/**
Show a stack made for a big screen at a size that fits the browser's
window.

Parameters:
pStack (string):
The stack to fit. Empty for the stack that <mwStart> named, or else the
default stack.

pMode (string):
How to fit it, one of the <fullscreenMode> values: "showAll" (the whole
stack, as big as fits, with bars at the sides or the top and bottom;
the default), "letterbox", "exactFit" or "noBorder".

Example:
on openStack
   if mwIsTouchScreen() then mwFitStack
end openStack

Description:
<mwStart> fits a stack of a fixed size that is too big for the window
by itself; use <mwFitStack> to fit one whatever its size, or with
another mode. The engine
scales the whole stack, and taps still land on the right controls,
because the engine does the scaling. It sets the stack's
<fullscreenMode> to <pMode> and its <fullscreen> to true, and fits it
again when the phone turns.

On a desktop, <mwFitStack> does nothing.

References: mwFillScreen (command)
*/
command mwFitStack pStack, pMode
   if pStack is empty then
      put mwTargetStack() into pStack
   end if
   if there is not a stack pStack then
      return "no such stack:" && pStack
   end if
   if pMode is empty then
      put "showAll" into pMode
   end if
   if pMode is not among the items of "showAll,letterbox,exactFit,noBorder" then
      return "unknown mode:" && pMode
   end if
   if not mwIsWeb() then
      return empty
   end if
   mwInstallBrowserSide
   if mwJS("return window.__oxtMobileWeb.fillPage();") is "no" then
      return "the page keeps its own layout"
   end if
   put the short name of stack pStack into sOptions["fit"]
   put empty into sOptions["autofit"]
   put empty into sOptions["fill"]
   set the fullscreenMode of stack pStack to pMode
   set the fullscreen of stack pStack to true
   mwWatchViewport
   return empty
end mwFitStack

/**
Buzz the phone.

Parameters:
pMilliseconds (number):
How long to buzz, from 1 to 5000 milliseconds. Empty for 50.

Returns (boolean):
true if the browser buzzed the phone; false where it cannot (iPhone and
iPad browsers, desktops).

Example:
on mouseUp
   mwVibrate 30
end mouseUp

Description:
Use <mwVibrate> to give a short buzz when something happens, such as a
wrong answer in a game. The result is false where the browser has no way
to buzz the phone; the stack goes on as before.

References: mwIsTouchScreen (function)
*/
command mwVibrate pMilliseconds
   if pMilliseconds is empty then
      put 50 into pMilliseconds
   end if
   if pMilliseconds is not an integer or pMilliseconds < 1 or pMilliseconds > 5000 then
      return false
   end if
   if not mwIsWeb() then
      return false
   end if
   return mwJS("return (navigator.vibrate && navigator.vibrate(" & pMilliseconds & ")) ? 'true' : 'false';") is "true"
end mwVibrate

/**
Scroll a field or group with a finger, or with the mouse.

Parameters:
pObject (string):
The long id of a field or group that scrolls.

Example:
-- in the script of a field "List"
on mouseDown
   mwDragScroll the long id of me
end mouseDown

Description:
On a phone, a finger dragged over a field selects its text instead of
scrolling it. Call <mwDragScroll> in the mouseDown of a field or group:
while the finger (or the mouse's button) is down, the object follows it
up and down, and when it lets go quickly the object glides on and slows
to a stop. A tap that does not move scrolls nothing.

The result is "moved" when the finger moved the object, and empty for a
tap that did not. A mouseUp follows either way, and the engine may send
it before <mwDragScroll> has returned, so a list that takes a tap as
picking a line asks <mwDragMoved> in its mouseUp and leaves out a drag.

It works the same on a desktop, with the mouse.

References: mwDragMoved (function), mwStart (command)
*/
command mwDragScroll pObject
   local tStartV, tStartScroll, tLastV, tLastTime, tNow, tSpeed, tMoved, tMax

   if there is not a pObject then
      return "no such object:" && pObject
   end if
   mwGlideStop
   put mwMaxScroll(pObject) into tMax
   put the mouseV into tStartV
   put tStartV into tLastV
   put the vScroll of pObject into tStartScroll
   put the milliseconds into tLastTime
   put 0 into tSpeed
   put false into tMoved
   put tStartV into sDragStartV
   put false into sDragMoved
   put true into sDragActive
   repeat while the mouse is down
      get the mouseV
      if abs(it - tStartV) > 4 then
         put true into tMoved
         put true into sDragMoved
      end if
      if tMoved then
         set the vScroll of pObject to max(0, min(tMax, tStartScroll + tStartV - it))
         put the milliseconds into tNow
         if tNow > tLastTime then
            -- pixels a tick of 16 milliseconds, smoothed
            put (tSpeed + (tLastV - it) * 16 / (tNow - tLastTime)) / 2 into tSpeed
         end if
         put it into tLastV
         put tNow into tLastTime
      end if
      wait 16 milliseconds with messages
   end repeat
   put false into sDragActive
   if tMoved and abs(tSpeed) > 1 and the milliseconds - tLastTime < 100 then
      put pObject into sGlideObject
      put tSpeed into sGlideSpeed
      send "mwGlide" to me in 16 milliseconds
      put the result into sGlideMessage
   end if
   if tMoved then
      return "moved"
   end if
   return empty
end mwDragScroll

/**
Whether the last drag of <mwDragScroll> moved its object.

Returns (boolean):
true when the finger (or the mouse) has moved more than 4 pixels up or
down since the last <mwDragScroll> began, false when it has not.

Example:
-- in the script of a field "List"
on mouseDown
   mwDragScroll the long id of me
end mouseDown

on mouseUp
   if mwDragMoved() then exit mouseUp
   answer "You picked" && the value of the clickLine
end mouseUp

Description:
A drag ends in a mouseUp, as a tap does, and the engine may send that
mouseUp while <mwDragScroll> is still waiting for the finger to let go.
Ask <mwDragMoved> in the mouseUp to leave out what a tap would do: it
also counts the move that ended the drag, which <mwDragScroll> has not
seen yet.

References: mwDragScroll (command)
*/
function mwDragMoved
   if sDragMoved is true then
      return true
   end if
   if sDragActive is true and sDragStartV is a number then
      return abs(the mouseV - sDragStartV) > 4
   end if
   return false
end mwDragMoved

/**
Whether the touch that ended was a long press.

Returns (boolean):
true from the moment longPress is sent until the finger has been let
go and the mouseUp it makes has been handled; false otherwise.

Example:
on mouseUp
   if mwLongPressed() then exit mouseUp
   go next card
end mouseUp

Description:
A long press is still a touch, so it ends in a mouseUp, as a click does.
Use <mwLongPressed> in a mouseUp to leave out what a click would do.

References: mwStart (command)
*/
function mwLongPressed
   if not mwIsWeb() or sStarted is not true then
      return false
   end if
   return mwJS("return window.__oxtMobileWeb && window.__oxtMobileWeb.longPressed() ? 'true' : 'false';") is "true"
end mwLongPressed

-- The browser calls this (it is the library stack's only
-- javascriptHandlers entry) with a kind and its values; see mwStart for
-- the messages
on mwFromBrowser pKind, p1, p2, p3
   local tKeyboard, tOrientation
   -- (a viewport report fills or fits again after mwFillScreen or
   -- mwFitStack alone; the messages need mwStart's stack)
   if pKind is not "viewport" and (sTarget is empty or there is not a stack sTarget) then
      exit mwFromBrowser
   end if
   switch pKind
      case "viewport"
         put p1 into sViewport
         if sOptions["fill"] is not empty then
            mwFill
         else if sOptions["autofit"] is not empty then
            mwAutoFit
         else if sOptions["fit"] is not empty and there is a stack sOptions["fit"] then
            -- the engine fits a fullscreen stack to the screen when it
            -- opens it: set it again for the new screen
            set the fullscreen of stack sOptions["fit"] to false
            set the fullscreen of stack sOptions["fit"] to true
         end if
         -- the first report only says how things are
         put item 8 of p1 into tOrientation
         if sOrientation is not empty and tOrientation is not sOrientation then
            mwSendToCard "orientationChanged"
         end if
         put tOrientation into sOrientation
         put item 3 of p1 into tKeyboard
         if tKeyboard is not a number then
            put 0 into tKeyboard
         end if
         if sKeyboard is a number then
            if tKeyboard > 0 and tKeyboard is not sKeyboard then
               mwSendToCard "keyboardActivated"
            else if tKeyboard is 0 and sKeyboard > 0 then
               mwSendToCard "keyboardDeactivated"
            end if
         end if
         put tKeyboard into sKeyboard
         break
      case "swipe"
         mwToCard p2, p3
         mwSendAt "swipe", mwControlAt(p2, p3), p1
         break
      case "pinchstart"
         mwToCard p1, p2
         put mwControlAt(p1, p2) into sPinchTarget
         mwSendAt "pinchStart", sPinchTarget, p1, p2
         break
      case "pinch"
         mwToCard p2, p3
         mwSendAt "pinch", sPinchTarget, p1, p2, p3
         break
      case "pinchend"
         mwSendAt "pinchEnd", sPinchTarget, p1
         put empty into sPinchTarget
         break
      case "longpress"
         mwToCard p1, p2
         mwSendAt "longPress", mwControlAt(p1, p2), p1, p2
         break
   end switch
end mwFromBrowser

-- The glide after mwDragScroll lets go
on mwGlide
   local tMax, tNew
   put empty into sGlideMessage
   if sGlideObject is empty or there is not a sGlideObject then
      exit mwGlide
   end if
   put sGlideSpeed * 0.94 into sGlideSpeed
   put mwMaxScroll(sGlideObject) into tMax
   put max(0, min(tMax, the vScroll of sGlideObject + round(sGlideSpeed))) into tNew
   set the vScroll of sGlideObject to tNew
   if abs(sGlideSpeed) < 0.5 or tNew is 0 or tNew is tMax then
      put empty into sGlideObject
      exit mwGlide
   end if
   send "mwGlide" to me in 16 milliseconds
   put the result into sGlideMessage
end mwGlide

-- The browser's window watched, so that a stack filled or fitted without
-- mwStart is filled or fitted again when the phone turns (with no
-- gestures: those are mwStart's)
private command mwWatchViewport
   if sStarted is true then
      exit mwWatchViewport
   end if
   get mwJS("window.__oxtMobileWeb.start(''); return '';")
   put true into sStarted
end mwWatchViewport

private command mwGlideStop
   if sGlideMessage is not empty then
      cancel sGlideMessage
   end if
   put empty into sGlideMessage
   put empty into sGlideObject
end mwGlideStop

-- How far a field or group scrolls: its contents (formattedHeight) past
-- its own height
private function mwMaxScroll pObject
   return max(0, the formattedHeight of pObject - the height of pObject)
end mwMaxScroll

-- The stack's size follows the page's (mwFillScreen)
private command mwFill
   local tView, tStack
   put sOptions["fill"] into tStack
   if tStack is empty or there is not a stack tStack then
      exit mwFill
   end if
   put mwJS("return window.__oxtMobileWeb.pageSize();") into tView
   if the number of items of tView is not 2 or item 1 of tView < 1 or item 2 of tView < 1 then
      exit mwFill
   end if
   if the width of stack tStack is not item 1 of tView or the height of stack tStack is not item 2 of tView then
      set the rect of stack tStack to 0, 0, item 1 of tView, item 2 of tView
   end if
end mwFill

-- A stack of a fixed size (mwStart without a screen named): scaled to the
-- window while it is too big for it, and as it is while it fits
private command mwAutoFit
   local tStack, tPage, tFits
   put sOptions["autofit"] into tStack
   if tStack is empty or there is not a stack tStack then
      exit mwAutoFit
   end if
   put mwJS("return window.__oxtMobileWeb.pageSize();") into tPage
   if the number of items of tPage is not 2 or item 1 of tPage < 1 or item 2 of tPage < 1 then
      exit mwAutoFit
   end if
   put the width of stack tStack <= item 1 of tPage and the height of stack tStack <= item 2 of tPage into tFits
   if tFits and the fullscreen of stack tStack then
      set the fullscreen of stack tStack to false
      get mwJS("window.__oxtMobileWeb.unfillPage(); return '';")
   else if not tFits then
      get mwJS("window.__oxtMobileWeb.fillPage(); return '';")
      set the fullscreenMode of stack tStack to "showAll"
      -- set again for the new window
      set the fullscreen of stack tStack to false
      set the fullscreen of stack tStack to true
   end if
end mwAutoFit

-- A point of the stack's window, as the browser reports it, in the
-- card's coordinates: the same unless mwFitStack has the engine scale the
-- stack to the screen, as its fullscreenMode does (stackview.cpp,
-- view_getviewtransform): the scale, the same both ways but for
-- "exactFit", and the stack centred
private command mwToCard @xX, @xY
   local tStack, tPage, tScaleX, tScaleY, tWidth, tHeight
   put sOptions["fit"] into tStack
   if tStack is empty then
      put sOptions["autofit"] into tStack
   end if
   if tStack is empty or there is not a stack tStack then
      exit mwToCard
   end if
   if not the fullscreen of stack tStack then
      exit mwToCard
   end if
   put mwJS("return window.__oxtMobileWeb.pageSize();") into tPage
   put the width of stack tStack into tWidth
   put the height of stack tStack into tHeight
   if the number of items of tPage is not 2 or tWidth < 1 or tHeight < 1 then
      exit mwToCard
   end if
   put item 1 of tPage / tWidth into tScaleX
   put item 2 of tPage / tHeight into tScaleY
   switch the fullscreenMode of stack tStack
      case "exactFit"
         break
      case "noBorder"
         put max(tScaleX, tScaleY) into tScaleX
         put tScaleX into tScaleY
         break
      default
         put min(tScaleX, tScaleY) into tScaleX
         put tScaleX into tScaleY
         break
   end switch
   put round((xX - (item 1 of tPage - tWidth * tScaleX) / 2) / tScaleX) into xX
   put round((xY - (item 2 of tPage - tHeight * tScaleY) / 2) / tScaleY) into xY
end mwToCard

private function mwTargetStack
   if sTarget is not empty and there is a stack sTarget then
      return sTarget
   end if
   return the short name of the defaultStack
end mwTargetStack

-- The top control at a point of the current card of the stack (as
-- controlAtLoc finds it: a control in a group, not the group), or the
-- card where there is none, as a long id
private function mwControlAt pX, pY
   local tDefault, tControl, tCard
   put the long id of this card of stack sTarget into tCard
   if pX is not a number or pY is not a number then
      return tCard
   end if
   put the defaultStack into tDefault
   set the defaultStack to sTarget
   put controlAtLoc(pX & comma & pY) into tControl
   if tControl is not empty then
      put the long id of tControl into tControl
   end if
   set the defaultStack to tDefault
   if tControl is empty then
      return tCard
   end if
   return tControl
end mwControlAt

-- A gesture, to the control it was over (on to its card and stack along
-- the message path), or to the card when that control has gone
private command mwSendAt pMessage, pObject, p1, p2, p3
   if sTarget is empty or there is not a stack sTarget then
      exit mwSendAt
   end if
   if pObject is empty or there is not a pObject then
      put the long id of this card of stack sTarget into pObject
   end if
   dispatch pMessage to pObject with p1, p2, p3
end mwSendAt

private command mwSendToCard pMessage
   if sTarget is empty or there is not a stack sTarget then
      exit mwSendToCard
   end if
   dispatch pMessage to this card of stack sTarget
end mwSendToCard

-- JavaScript's result, as text (empty after an error)
private function mwJS pScript
   local tResult, tError
   try
      do "(function(){" & pScript & "})()" as "JavaScript"
      put the result into tResult
   catch tError
      put empty into tResult
   end try
   return tResult
end mwJS

private function mwQuote pText
   replace "\" with "\\" in pText
   replace "'" with "\'" in pText
   return "'" & pText & "'"
end mwQuote

-- The browser's side: one object, window.__oxtMobileWeb, made once
private command mwInstallBrowserSide
   if mwJS("return window.__oxtMobileWeb ? 'yes' : 'no';") is "yes" then
      exit mwInstallBrowserSide
   end if
   set the cJavascriptHandlers of me to "mwFromBrowser"
   get mwJS(mwBrowserScript())
end mwInstallBrowserSide

private function mwBrowserScript
   local tScript
   -- one line a statement: a single "put" of every line joined with "&"
   -- is an expression as deep as the script is long, and evaluating it
   -- used more of the thread's stack than an iPhone or an iPad gives a
   -- page ("Maximum call stack size exceeded" as the stack opened, and a
   -- blank page)
   put "var lib = " & mwQuote(kLibrary) & ";" & return after tScript
   put "var mw = {gestures: {}, on: false, touches: {}, start0: null, pinch: null, press: null," & return after tScript
   put "  pressed: false, queue: [], timer: null, probe: null, lastView: ''};" & return after tScript
   put "function call(kind, a, b, c) {" & return after tScript
   put "  mw.queue.push([kind, a, b, c]);" & return after tScript
   put "  if (mw.timer === null) mw.timer = setTimeout(flush, 0);" & return after tScript
   put "}" & return after tScript
   put "function flush() {" & return after tScript
   put "  mw.timer = null;" & return after tScript
   put "  var q = mw.queue; mw.queue = [];" & return after tScript
   put "  var h = document.liveCode && document.liveCode.findStackWithName(lib);" & return after tScript
   put "  if (!h || !h.mwFromBrowser) return;" & return after tScript
   put "  for (var i = 0; i < q.length; i++) h.mwFromBrowser(q[i][0], q[i][1], q[i][2], q[i][3]);" & return after tScript
   put "}" & return after tScript
   put "function insets() {" & return after tScript
   put "  if (!mw.probe) {" & return after tScript
   put "    mw.probe = document.createElement('div');" & return after tScript
   put "    mw.probe.style.cssText = 'position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;' +" & return after tScript
   put "      'padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';" & return after tScript
   put "    document.body.appendChild(mw.probe);" & return after tScript
   put "  }" & return after tScript
   put "  var s = getComputedStyle(mw.probe);" & return after tScript
   put "  return [s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft].map(function(v) { return Math.round(parseFloat(v) || 0); });" & return after tScript
   put "}" & return after tScript
   put "function viewport() {" & return after tScript
   put "  var vv = window.visualViewport;" & return after tScript
   put "  var lw = document.documentElement.clientWidth || window.innerWidth;" & return after tScript
   put "  var lh = window.innerHeight;" & return after tScript
   put "  var w = vv ? vv.width * vv.scale : lw, h = vv ? vv.height * vv.scale : lh;" & return after tScript
   put "  var kb = vv ? Math.max(0, lh - vv.height * vv.scale - vv.offsetTop) : 0;" & return after tScript
   put "  if (kb < 60) kb = 0;" & return after tScript
   put "  var i = insets();" & return after tScript
   put "  return [Math.round(w), Math.round(h), Math.round(kb), i[0], i[1], i[2], i[3], lw > lh ? 'landscape' : 'portrait'].join(',');" & return after tScript
   put "}" & return after tScript
   put "function viewChanged() {" & return after tScript
   put "  if (!mw.on) return;" & return after tScript
   put "  var v = viewport();" & return after tScript
   put "  if (v === mw.lastView) return;" & return after tScript
   put "  mw.lastView = v;" & return after tScript
   put "  call('viewport', v);" & return after tScript
   put "}" & return after tScript
   put "var viewTimer = null;" & return after tScript
   put "// once the browser has settled, then twice more: a phone that turns can" & return after tScript
   put "// report its new size in steps, the last without an event" & return after tScript
   put "function viewSoon() { clearTimeout(viewTimer); viewTimer = setTimeout(function() { viewChanged();" & return after tScript
   put "  viewTimer = setTimeout(function() { viewChanged(); viewTimer = setTimeout(viewChanged, 700); }, 380); }, 120); }" & return after tScript
   put "function canvasOf(e) { var t = e.target; return t && t.tagName === 'CANVAS' ? t : null; }" & return after tScript
   put "function local(canvas, x, y) { var r = canvas.getBoundingClientRect(); return [Math.round(x - r.left), Math.round(y - r.top)]; }" & return after tScript
   put "function cancelPress() { if (mw.press) { clearTimeout(mw.press.timer); mw.press = null; } }" & return after tScript
   put "function onStart(e) {" & return after tScript
   put "  var c = canvasOf(e); if (!c || !mw.on) return;" & return after tScript
   put "  mw.pressed = false;" & return after tScript
   put "  var t = e.touches;" & return after tScript
   put "  if (t.length === 1) {" & return after tScript
   put "    var l0 = local(c, t[0].clientX, t[0].clientY);" & return after tScript
   put "    mw.start0 = {x: t[0].clientX, y: t[0].clientY, lx: l0[0], ly: l0[1], time: e.timeStamp, canvas: c, multi: false};" & return after tScript
   put "    cancelPress();" & return after tScript
   put "    if (mw.gestures.longpress) {" & return after tScript
   put "      var p = {x: t[0].clientX, y: t[0].clientY, canvas: c};" & return after tScript
   put "      p.timer = setTimeout(function() { if (mw.press === p) { mw.press = null; mw.pressed = true;" & return after tScript
   put "        var l = local(p.canvas, p.x, p.y); call('longpress', l[0], l[1]); } }, 550);" & return after tScript
   put "      mw.press = p;" & return after tScript
   put "    }" & return after tScript
   put "  } else {" & return after tScript
   put "    cancelPress();" & return after tScript
   put "    if (mw.start0) mw.start0.multi = true;" & return after tScript
   put "    if (t.length === 2 && mw.gestures.pinch) {" & return after tScript
   put "      var d = Math.hypot(t[1].clientX - t[0].clientX, t[1].clientY - t[0].clientY) || 1;" & return after tScript
   put "      var m = local(c, (t[0].clientX + t[1].clientX) / 2, (t[0].clientY + t[1].clientY) / 2);" & return after tScript
   put "      mw.pinch = {d: d, canvas: c, scale: 1, frame: null};" & return after tScript
   put "      call('pinchstart', m[0], m[1]);" & return after tScript
   put "    }" & return after tScript
   put "  }" & return after tScript
   put "}" & return after tScript
   put "function onMove(e) {" & return after tScript
   put "  if (!mw.on) return;" & return after tScript
   put "  var t = e.touches;" & return after tScript
   put "  if (mw.press && t.length === 1 && Math.hypot(t[0].clientX - mw.press.x, t[0].clientY - mw.press.y) > 10) cancelPress();" & return after tScript
   put "  if (mw.pinch && t.length >= 2) {" & return after tScript
   put "    var p = mw.pinch;" & return after tScript
   put "    p.scale = Math.hypot(t[1].clientX - t[0].clientX, t[1].clientY - t[0].clientY) / p.d;" & return after tScript
   put "    p.mid = local(p.canvas, (t[0].clientX + t[1].clientX) / 2, (t[0].clientY + t[1].clientY) / 2);" & return after tScript
   put "    if (!p.frame) p.frame = requestAnimationFrame(function() { p.frame = null;" & return after tScript
   put "      if (mw.pinch === p) call('pinch', Math.round(p.scale * 1000) / 1000, p.mid[0], p.mid[1]); });" & return after tScript
   put "  }" & return after tScript
   put "}" & return after tScript
   put "function onEnd(e) {" & return after tScript
   put "  if (!mw.on) return;" & return after tScript
   put "  var t = e.touches;" & return after tScript
   put "  cancelPress();" & return after tScript
   put "  if (mw.pinch && t.length < 2) {" & return after tScript
   put "    var s = mw.pinch.scale; mw.pinch = null;" & return after tScript
   put "    call('pinchend', Math.round(s * 1000) / 1000);" & return after tScript
   put "  }" & return after tScript
   put "  if (t.length === 0 && mw.start0) {" & return after tScript
   put "    var s0 = mw.start0; mw.start0 = null;" & return after tScript
   put "    var u = e.changedTouches[0];" & return after tScript
   put "    if (e.type === 'touchend' && u && !s0.multi && !mw.pressed && mw.gestures.swipe && e.timeStamp - s0.time < 700) {" & return after tScript
   put "      var dx = u.clientX - s0.x, dy = u.clientY - s0.y;" & return after tScript
   put "      var ax = Math.abs(dx), ay = Math.abs(dy);" & return after tScript
   put "      if (Math.max(ax, ay) >= 50 && Math.max(ax, ay) >= 1.5 * Math.min(ax, ay))" & return after tScript
   put "        call('swipe', ax > ay ? (dx < 0 ? 'left' : 'right') : (dy < 0 ? 'up' : 'down'), s0.lx, s0.ly);" & return after tScript
   put "    }" & return after tScript
   put "  }" & return after tScript
   put "  if (mw.pressed) setTimeout(function() { mw.pressed = false; }, 400);" & return after tScript
   put "}" & return after tScript
   put "var touchEvents = [['touchstart', onStart], ['touchmove', onMove], ['touchend', onEnd], ['touchcancel', onEnd]];" & return after tScript
   put "var viewEvents = ['resize', 'orientationchange'];" & return after tScript
   put "window.__oxtMobileWeb = {" & return after tScript
   put "  start: function(gestures) {" & return after tScript
   put "    mw.gestures = {};" & return after tScript
   put "    gestures.split(',').forEach(function(g) { if (g) mw.gestures[g] = true; });" & return after tScript
   put "    if (mw.on) return;" & return after tScript
   put "    mw.on = true; mw.lastView = '';" & return after tScript
   put "    touchEvents.forEach(function(x) { document.addEventListener(x[0], x[1], {capture: true, passive: true}); });" & return after tScript
   put "    viewEvents.forEach(function(x) { window.addEventListener(x, viewSoon); });" & return after tScript
   put "    if (window.visualViewport) { visualViewport.addEventListener('resize', viewSoon); visualViewport.addEventListener('scroll', viewSoon); }" & return after tScript
   put "    viewSoon();" & return after tScript
   put "  }," & return after tScript
   put "  stop: function() {" & return after tScript
   put "    if (!mw.on) return;" & return after tScript
   put "    mw.on = false; cancelPress(); mw.pinch = null; mw.start0 = null;" & return after tScript
   put "    touchEvents.forEach(function(x) { document.removeEventListener(x[0], x[1], {capture: true, passive: true}); });" & return after tScript
   put "    viewEvents.forEach(function(x) { window.removeEventListener(x, viewSoon); });" & return after tScript
   put "    if (window.visualViewport) { visualViewport.removeEventListener('resize', viewSoon); visualViewport.removeEventListener('scroll', viewSoon); }" & return after tScript
   put "  }," & return after tScript
   put "  viewport: viewport," & return after tScript
   put "  pageSize: function() { return [document.documentElement.clientWidth || window.innerWidth, window.innerHeight].join(','); }," & return after tScript
   put "  longPressed: function() { return mw.pressed; }," & return after tScript
   put "  fillPage: function(ask) {" & return after tScript
   put "    var keep = function(el) { return el && el.getAttribute('data-mobile-web-fill') === 'no'; };" & return after tScript
   put "    if (keep(document.documentElement) || keep(document.body)) return 'no';" & return after tScript
   put "    if (ask) return 'yes';" & return after tScript
   put "    var meta = document.querySelector('meta[name=viewport]');" & return after tScript
   put "    if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; meta.setAttribute('data-oxt-mobile-web', 'made'); document.head.appendChild(meta); }" & return after tScript
   put "    if (!/viewport-fit/.test(meta.content)) {" & return after tScript
   put "      if (!meta.hasAttribute('data-oxt-mobile-web')) meta.setAttribute('data-oxt-mobile-web', meta.content);" & return after tScript
   put "      meta.content = (meta.content ? meta.content + ', ' : '') + 'viewport-fit=cover';" & return after tScript
   put "    }" & return after tScript
   put "    var css = document.getElementById('oxt-mobile-web-fill');" & return after tScript
   put "    if (!css) {" & return after tScript
   put "      css = document.createElement('style'); css.id = 'oxt-mobile-web-fill';" & return after tScript
   put "      css.textContent = 'html,body{margin:0;padding:0;height:100%;overflow:hidden;overscroll-behavior:none}' +" & return after tScript
   put "        '#stack{margin:0!important}';" & return after tScript
   put "      document.head.appendChild(css);" & return after tScript
   put "    }" & return after tScript
   put "    window.scrollTo(0, 0);" & return after tScript
   put "    return 'yes';" & return after tScript
   put "  }," & return after tScript
   put "  unfillPage: function() {" & return after tScript
   put "    var css = document.getElementById('oxt-mobile-web-fill');" & return after tScript
   put "    if (css) css.parentNode.removeChild(css);" & return after tScript
   put "    var meta = document.querySelector('meta[data-oxt-mobile-web]');" & return after tScript
   put "    if (meta) {" & return after tScript
   put "      var was = meta.getAttribute('data-oxt-mobile-web');" & return after tScript
   put "      if (was === 'made') meta.parentNode.removeChild(meta);" & return after tScript
   put "      else { meta.content = was; meta.removeAttribute('data-oxt-mobile-web'); }" & return after tScript
   put "    }" & return after tScript
   put "  }" & return after tScript
   put "};" & return after tScript
   put "return '';" after tScript
   return tScript
end mwBrowserScript
