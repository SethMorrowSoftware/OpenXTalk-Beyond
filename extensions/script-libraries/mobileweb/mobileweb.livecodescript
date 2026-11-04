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
-- mwStart gets the messages below, sent to the current card of the stack
-- that it names, and only for what happens after it:
--
--    mwViewportChanged pWidth, pHeight, pKeyboardHeight
--    mwSwipe pDirection            (left, right, up or down)
--    mwPinchStart pX, pY
--    mwPinch pScale, pX, pY
--    mwPinchEnd pScale
--    mwLongPress pX, pY
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
-- what mwStart was asked for: sOptions["gestures"], sOptions["fill"]
local sOptions
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
Start the library's messages for a stack.

Parameters:
pStack (string):
The name of the stack that gets the messages, at its current card. Empty
for the default stack.

pGestures (string):
A comma-separated list of the gestures to report: any of "swipe",
"pinch" and "longpress". Empty for all three; "none" for none.

Example:
on openStack
   mwStart the short name of this stack
   mwFillScreen
end openStack

on mwSwipe pDirection
   if pDirection is "left" then go next card
   if pDirection is "right" then go previous card
end mwSwipe

Description:
After <mwStart>, the current card of <pStack> gets:

- mwViewportChanged pWidth, pHeight, pKeyboardHeight: the part of the
  page the stack can be seen in changed: the phone turned, the browser's
  bar came or went, or the on-screen keyboard came up or went away.
  pKeyboardHeight is how many pixels of the bottom of the page the
  keyboard covers.
- mwSwipe pDirection: a quick stroke of one finger, "left", "right", "up"
  or "down" (the way the finger went).
- mwPinchStart pX, pY, then mwPinch pScale, pX, pY as two fingers move,
  and mwPinchEnd pScale: pScale is the distance between the fingers over
  their distance at the start, and pX, pY the point between them.
- mwLongPress pX, pY: a finger held still for about half a second.

Points are in the card's coordinates. The gestures come in addition to
the mouse messages that a touch already sends: a swipe is also a drag of
the mouse, and a long press ends in a mouseUp. A stack can ask
<mwLongPressed> in its mouseUp to tell one from a click.

On a desktop, <mwStart> only remembers the stack: there are no gestures,
and mwViewportChanged is not sent.

References: mwStop (command), mwViewport (function), mwFillScreen (command)
*/
command mwStart pStack, pGestures
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
   put tGestures into sOptions["gestures"]

   if not mwIsWeb() then
      return empty
   end if

   mwInstallBrowserSide
   get mwJS("window.__oxtMobileWeb.start(" & mwQuote(tGestures) & "); return '';")
   put true into sStarted
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
filling the screen keeps the size it has.

References: mwStart (command)
*/
command mwStop
   put empty into sTarget
   put empty into sOptions
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

   if mwIsWeb() then
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
   mwStart
   mwFillScreen
end openStack

on resizeStack pWidth, pHeight
   set the rect of group "Content" to 0, 60, pWidth, pHeight - 56
end resizeStack

Description:
Use <mwFillScreen> for a stack laid out for a phone: the stack becomes
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
   mwFill
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
Use <mwFitStack> for a stack that was laid out for a desktop: the engine
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
   put the short name of stack pStack into sOptions["fit"]
   mwInstallBrowserSide
   get mwJS("window.__oxtMobileWeb.fillPage(); return '';")
   set the fullscreenMode of stack pStack to pMode
   set the fullscreen of stack pStack to true
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
true from the moment <mwLongPress> is sent until the finger has been let
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
   if sTarget is empty or there is not a stack sTarget then
      exit mwFromBrowser
   end if
   switch pKind
      case "viewport"
         put p1 into sViewport
         if sOptions["fill"] is not empty then
            mwFill
         else if sOptions["fit"] is not empty and there is a stack sOptions["fit"] then
            -- the engine fits a fullscreen stack to the screen when it
            -- opens it: set it again for the new screen
            set the fullscreen of stack sOptions["fit"] to false
            set the fullscreen of stack sOptions["fit"] to true
         end if
         mwSend "mwViewportChanged", item 1 of p1, item 2 of p1, item 3 of p1
         break
      case "swipe"
         mwSend "mwSwipe", p1
         break
      case "pinchstart"
         mwToCard p1, p2
         mwSend "mwPinchStart", p1, p2
         break
      case "pinch"
         mwToCard p2, p3
         mwSend "mwPinch", p1, p2, p3
         break
      case "pinchend"
         mwSend "mwPinchEnd", p1
         break
      case "longpress"
         mwToCard p1, p2
         mwSend "mwLongPress", p1, p2
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

-- A point of the stack's window, as the browser reports it, in the
-- card's coordinates: the same unless mwFitStack has the engine scale the
-- stack to the screen, as its fullscreenMode does (stackview.cpp,
-- view_getviewtransform): the scale, the same both ways but for
-- "exactFit", and the stack centred
private command mwToCard @xX, @xY
   local tStack, tPage, tScaleX, tScaleY, tWidth, tHeight
   put sOptions["fit"] into tStack
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

private command mwSend pMessage, p1, p2, p3
   if sTarget is empty or there is not a stack sTarget then
      exit mwSend
   end if
   dispatch pMessage to this card of stack sTarget with p1, p2, p3
end mwSend

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
   put "var lib = " & mwQuote(kLibrary) & ";" & return & \
         "var mw = {gestures: {}, on: false, touches: {}, start0: null, pinch: null, press: null," & return & \
         "  pressed: false, queue: [], timer: null, probe: null, lastView: ''};" & return & \
         "function call(kind, a, b, c) {" & return & \
         "  mw.queue.push([kind, a, b, c]);" & return & \
         "  if (mw.timer === null) mw.timer = setTimeout(flush, 0);" & return & \
         "}" & return & \
         "function flush() {" & return & \
         "  mw.timer = null;" & return & \
         "  var q = mw.queue; mw.queue = [];" & return & \
         "  var h = document.liveCode && document.liveCode.findStackWithName(lib);" & return & \
         "  if (!h || !h.mwFromBrowser) return;" & return & \
         "  for (var i = 0; i < q.length; i++) h.mwFromBrowser(q[i][0], q[i][1], q[i][2], q[i][3]);" & return & \
         "}" & return & \
         "function insets() {" & return & \
         "  if (!mw.probe) {" & return & \
         "    mw.probe = document.createElement('div');" & return & \
         "    mw.probe.style.cssText = 'position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;' +" & return & \
         "      'padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';" & return & \
         "    document.body.appendChild(mw.probe);" & return & \
         "  }" & return & \
         "  var s = getComputedStyle(mw.probe);" & return & \
         "  return [s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft].map(function(v) { return Math.round(parseFloat(v) || 0); });" & return & \
         "}" & return & \
         "function viewport() {" & return & \
         "  var vv = window.visualViewport;" & return & \
         "  var lw = document.documentElement.clientWidth || window.innerWidth;" & return & \
         "  var lh = window.innerHeight;" & return & \
         "  var w = vv ? vv.width * vv.scale : lw, h = vv ? vv.height * vv.scale : lh;" & return & \
         "  var kb = vv ? Math.max(0, lh - vv.height * vv.scale - vv.offsetTop) : 0;" & return & \
         "  if (kb < 60) kb = 0;" & return & \
         "  var i = insets();" & return & \
         "  return [Math.round(w), Math.round(h), Math.round(kb), i[0], i[1], i[2], i[3], lw > lh ? 'landscape' : 'portrait'].join(',');" & return & \
         "}" & return & \
         "function viewChanged() {" & return & \
         "  if (!mw.on) return;" & return & \
         "  var v = viewport();" & return & \
         "  if (v === mw.lastView) return;" & return & \
         "  mw.lastView = v;" & return & \
         "  call('viewport', v);" & return & \
         "}" & return & \
         "var viewTimer = null;" & return & \
         "function viewSoon() { clearTimeout(viewTimer); viewTimer = setTimeout(viewChanged, 120); }" & return & \
         "function canvasOf(e) { var t = e.target; return t && t.tagName === 'CANVAS' ? t : null; }" & return & \
         "function local(canvas, x, y) { var r = canvas.getBoundingClientRect(); return [Math.round(x - r.left), Math.round(y - r.top)]; }" & return & \
         "function cancelPress() { if (mw.press) { clearTimeout(mw.press.timer); mw.press = null; } }" & return & \
         "function onStart(e) {" & return & \
         "  var c = canvasOf(e); if (!c || !mw.on) return;" & return & \
         "  mw.pressed = false;" & return & \
         "  var t = e.touches;" & return & \
         "  if (t.length === 1) {" & return & \
         "    mw.start0 = {x: t[0].clientX, y: t[0].clientY, time: e.timeStamp, canvas: c, multi: false};" & return & \
         "    cancelPress();" & return & \
         "    if (mw.gestures.longpress) {" & return & \
         "      var p = {x: t[0].clientX, y: t[0].clientY, canvas: c};" & return & \
         "      p.timer = setTimeout(function() { if (mw.press === p) { mw.press = null; mw.pressed = true;" & return & \
         "        var l = local(p.canvas, p.x, p.y); call('longpress', l[0], l[1]); } }, 550);" & return & \
         "      mw.press = p;" & return & \
         "    }" & return & \
         "  } else {" & return & \
         "    cancelPress();" & return & \
         "    if (mw.start0) mw.start0.multi = true;" & return & \
         "    if (t.length === 2 && mw.gestures.pinch) {" & return & \
         "      var d = Math.hypot(t[1].clientX - t[0].clientX, t[1].clientY - t[0].clientY) || 1;" & return & \
         "      var m = local(c, (t[0].clientX + t[1].clientX) / 2, (t[0].clientY + t[1].clientY) / 2);" & return & \
         "      mw.pinch = {d: d, canvas: c, scale: 1, frame: null};" & return & \
         "      call('pinchstart', m[0], m[1]);" & return & \
         "    }" & return & \
         "  }" & return & \
         "}" & return & \
         "function onMove(e) {" & return & \
         "  if (!mw.on) return;" & return & \
         "  var t = e.touches;" & return & \
         "  if (mw.press && t.length === 1 && Math.hypot(t[0].clientX - mw.press.x, t[0].clientY - mw.press.y) > 10) cancelPress();" & return & \
         "  if (mw.pinch && t.length >= 2) {" & return & \
         "    var p = mw.pinch;" & return & \
         "    p.scale = Math.hypot(t[1].clientX - t[0].clientX, t[1].clientY - t[0].clientY) / p.d;" & return & \
         "    p.mid = local(p.canvas, (t[0].clientX + t[1].clientX) / 2, (t[0].clientY + t[1].clientY) / 2);" & return & \
         "    if (!p.frame) p.frame = requestAnimationFrame(function() { p.frame = null;" & return & \
         "      if (mw.pinch === p) call('pinch', Math.round(p.scale * 1000) / 1000, p.mid[0], p.mid[1]); });" & return & \
         "  }" & return & \
         "}" & return & \
         "function onEnd(e) {" & return & \
         "  if (!mw.on) return;" & return & \
         "  var t = e.touches;" & return & \
         "  cancelPress();" & return & \
         "  if (mw.pinch && t.length < 2) {" & return & \
         "    var s = mw.pinch.scale; mw.pinch = null;" & return & \
         "    call('pinchend', Math.round(s * 1000) / 1000);" & return & \
         "  }" & return & \
         "  if (t.length === 0 && mw.start0) {" & return & \
         "    var s0 = mw.start0; mw.start0 = null;" & return & \
         "    var u = e.changedTouches[0];" & return & \
         "    if (e.type === 'touchend' && u && !s0.multi && !mw.pressed && mw.gestures.swipe && e.timeStamp - s0.time < 700) {" & return & \
         "      var dx = u.clientX - s0.x, dy = u.clientY - s0.y;" & return & \
         "      var ax = Math.abs(dx), ay = Math.abs(dy);" & return & \
         "      if (Math.max(ax, ay) >= 50 && Math.max(ax, ay) >= 1.5 * Math.min(ax, ay))" & return & \
         "        call('swipe', ax > ay ? (dx < 0 ? 'left' : 'right') : (dy < 0 ? 'up' : 'down'));" & return & \
         "    }" & return & \
         "  }" & return & \
         "  if (mw.pressed) setTimeout(function() { mw.pressed = false; }, 400);" & return & \
         "}" & return & \
         "var touchEvents = [['touchstart', onStart], ['touchmove', onMove], ['touchend', onEnd], ['touchcancel', onEnd]];" & return & \
         "var viewEvents = ['resize', 'orientationchange'];" & return & \
         "window.__oxtMobileWeb = {" & return & \
         "  start: function(gestures) {" & return & \
         "    mw.gestures = {};" & return & \
         "    gestures.split(',').forEach(function(g) { if (g) mw.gestures[g] = true; });" & return & \
         "    if (mw.on) return;" & return & \
         "    mw.on = true; mw.lastView = '';" & return & \
         "    touchEvents.forEach(function(x) { document.addEventListener(x[0], x[1], {capture: true, passive: true}); });" & return & \
         "    viewEvents.forEach(function(x) { window.addEventListener(x, viewSoon); });" & return & \
         "    if (window.visualViewport) { visualViewport.addEventListener('resize', viewSoon); visualViewport.addEventListener('scroll', viewSoon); }" & return & \
         "    viewSoon();" & return & \
         "  }," & return & \
         "  stop: function() {" & return & \
         "    if (!mw.on) return;" & return & \
         "    mw.on = false; cancelPress(); mw.pinch = null; mw.start0 = null;" & return & \
         "    touchEvents.forEach(function(x) { document.removeEventListener(x[0], x[1], {capture: true, passive: true}); });" & return & \
         "    viewEvents.forEach(function(x) { window.removeEventListener(x, viewSoon); });" & return & \
         "    if (window.visualViewport) { visualViewport.removeEventListener('resize', viewSoon); visualViewport.removeEventListener('scroll', viewSoon); }" & return & \
         "  }," & return & \
         "  viewport: viewport," & return & \
         "  pageSize: function() { return [document.documentElement.clientWidth || window.innerWidth, window.innerHeight].join(','); }," & return & \
         "  longPressed: function() { return mw.pressed; }," & return & \
         "  fillPage: function() {" & return & \
         "    var keep = function(el) { return el && el.getAttribute('data-mobile-web-fill') === 'no'; };" & return & \
         "    if (keep(document.documentElement) || keep(document.body)) return 'no';" & return & \
         "    var meta = document.querySelector('meta[name=viewport]');" & return & \
         "    if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; meta.setAttribute('data-oxt-mobile-web', 'made'); document.head.appendChild(meta); }" & return & \
         "    if (!/viewport-fit/.test(meta.content)) {" & return & \
         "      if (!meta.hasAttribute('data-oxt-mobile-web')) meta.setAttribute('data-oxt-mobile-web', meta.content);" & return & \
         "      meta.content = (meta.content ? meta.content + ', ' : '') + 'viewport-fit=cover';" & return & \
         "    }" & return & \
         "    var css = document.getElementById('oxt-mobile-web-fill');" & return & \
         "    if (!css) {" & return & \
         "      css = document.createElement('style'); css.id = 'oxt-mobile-web-fill';" & return & \
         "      css.textContent = 'html,body{margin:0;padding:0;height:100%;overflow:hidden;overscroll-behavior:none}' +" & return & \
         "        '#stack{margin:0!important}';" & return & \
         "      document.head.appendChild(css);" & return & \
         "    }" & return & \
         "    window.scrollTo(0, 0);" & return & \
         "    return 'yes';" & return & \
         "  }," & return & \
         "  unfillPage: function() {" & return & \
         "    var css = document.getElementById('oxt-mobile-web-fill');" & return & \
         "    if (css) css.parentNode.removeChild(css);" & return & \
         "    var meta = document.querySelector('meta[data-oxt-mobile-web]');" & return & \
         "    if (meta) {" & return & \
         "      var was = meta.getAttribute('data-oxt-mobile-web');" & return & \
         "      if (was === 'made') meta.parentNode.removeChild(meta);" & return & \
         "      else { meta.content = was; meta.removeAttribute('data-oxt-mobile-web'); }" & return & \
         "    }" & return & \
         "  }" & return & \
         "};" & return & \
         "return '';" into tScript
   return tScript
end mwBrowserScript
