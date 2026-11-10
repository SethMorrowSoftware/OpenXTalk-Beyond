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
-- message of its own, and the one engine message it handles,
-- resizeStack, it only looks at for the stacks mwResponsive lays out and
-- always passes on. A stack that calls mwStart gets the messages below,
-- and only for what happens after it.
-- The gestures go to the control under the finger, as a mouse message
-- does, and on up the message path to its card and stack if it passes
-- them (or has no handler); the rest go to the current card, by the
-- names LiveCode's iOS and Android engines send them:
--
--    touchStart pId, pX, pY        (one finger each, pId a number)
--    touchMove pId, pX, pY
--    touchEnd pId, pX, pY
--    touchRelease pId, pX, pY      (the browser took the touch away)
--    swipe pDirection              (left, right, up or down)
--    pinchStart pX, pY
--    pinch pScale, pX, pY
--    pinchEnd pScale
--    longPress pX, pY
--    orientationChanged
--    keyboardActivated
--    keyboardDeactivated
--
-- and while a sensor is started (mwStartSensor), to the current card:
--
--    locationChanged pLatitude, pLongitude, pAltitude
--    headingChanged pHeading
--    accelerationChanged pX, pY, pZ, pTime
--    rotationRateChanged pX, pY, pZ, pTime
--    trackingError pSensor, pError
--
-- and for a stack that mwResponsive lays out, on a desktop as in a
-- browser, to its current card when its size crosses a breakpoint or
-- turns (after its controls' mwLayout rules are followed):
--
--    layoutChanged pClass, pOrientation   ("phone", "tablet" or
--                                          "desktop"; "portrait" or
--                                          "landscape")
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
   -- the stacks mwResponsive lays out forgotten. Not with put here:
   -- sResponsive and sApplied are declared further down the script, and
   -- a handler sees a script local only below its declaration, so here
   -- the two names were new handler locals and the stacks were kept
   mwForgetLayouts
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

It also lays one stack out for a phone, a tablet and a desktop
(mwResponsive): rules on the controls say where each goes at each size,
a group can arrange its controls in columns (mwFlow), and the stack is
told when it crosses from one layout to another (layoutChanged).

On a desktop it answers as a desktop would and sends no gestures, so a
stack that uses it can be made and tried in the IDE. Nothing changes for
a stack that does not call it.

Tags:
html5, mobile, touch
*/

constant kLibrary = "com.livecode.library.mobileweb"
constant kGestures = "swipe,pinch,longpress,touch"
constant kSensors = "location,heading,acceleration,rotation rate"
constant kPhotoSources = "library,camera,rear camera,front camera"
-- a phone's photo is 12 megapixels or more: this keeps it to about 1.2
constant kPhotoMax = 1280
-- the widths at which a stack's layout becomes a tablet's and a
-- desktop's (mwLayoutClass): under 600 is a phone held upright, 600 to
-- 1023 a tablet (and a phone on its side, 640 to 932 wide), 1024 and over
-- a desktop (and a tablet on its side, 1024 to 1366)
constant kBreakpoints = "600,1024"
constant kLayoutClasses = "phone,tablet,desktop"
-- the words of a layout rule (the mwLayout custom property set)
constant kRuleEdges = "left,top,right,bottom,width,height"
constant kRuleWords = "left,top,right,bottom,width,height,hidden,shown,bleed,within,flow,gap"
-- the space between the controls mwFlow arranges, when none is given
constant kFlowGap = 12

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
-- the control each finger touched first (by the finger's number), which
-- gets its touchMove and touchEnd too
local sTouchTarget
-- the sensors started (sSensors[name] is true), the stack whose card
-- gets their messages, and each one's last reading, as the browser sent it
local sSensors, sSensorStack, sReading
-- mwPickPhoto's wait: "waiting", then "done" (sPhoto has the JPEG, in
-- base64) or "cancel"
local sPhotoState, sPhoto
-- the browser's last viewport (see mwViewport), as a list of
-- width,height,keyboard,top,right,bottom,left,orientation
local sViewport
-- mwDragScroll's glide: the object, its speed in pixels a tick, and the
-- message that moves it on
local sGlideObject, sGlideSpeed, sGlideMessage

-- mwDragScroll's drag: where it began, whether it has moved, and whether
-- the finger is still down (for mwDragMoved)
local sDragStartV, sDragMoved, sDragActive

-- mwResponsive: the stacks it lays out (sResponsive[short name] is the
-- class and orientation last sent with layoutChanged, as
-- "phone,portrait"), what each was last laid out for (sApplied[short
-- name]: width, height, class, orientation and insets), and the
-- breakpoints mwSetBreakpoints set (empty for kBreakpoints)
local sResponsive, sApplied, sBreakpoints

-- What extensionFinalize forgets of mwResponsive, below the declaration
-- above so that it reaches the script locals; the breakpoints are kept,
-- as they always were
private command mwForgetLayouts
   put empty into sResponsive
   put empty into sApplied
end mwForgetLayouts

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
"pinch", "longpress" and "touch" (the touch messages, one finger each).
Empty for all four; "none" for none.

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
- touchStart pId, pX, pY when a finger touches the stack, touchMove
  pId, pX, pY as it moves (at most once a frame), and touchEnd pId, pX,
  pY when it lets go (touchRelease when the browser takes the touch away,
  as it can for a call). pId is a number of the finger's own, the same
  in all its messages, so two or more fingers can be followed at once,
  for drawing or a game. All of them go to the control the finger
  touched first, as LiveCode's iOS and Android engines send them.

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
   put empty into sTouchTarget
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
browser's listeners that <mwStart> added are removed. The sensors that
<mwStartSensor> started are stopped, the screen kept on by
<mwKeepAwake> is let go, and an <mwPickPhoto> still waiting is
cancelled. A stack that was
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
   put empty into sTouchTarget
   put empty into sSensors
   put empty into sSensorStack
   put empty into sReading
   if sPhotoState is "waiting" then
      put "cancel" into sPhotoState
   end if
   mwGlideStop
   if mwIsWeb() then
      -- the listeners and the sensors off, the screen let go, a photo
      -- not yet taken forgotten, and the page as it was before
      -- mwFillScreen
      get mwJS("var m = window.__oxtMobileWeb; if (m) { m.stop(); m.sensorsOff(); m.keepAwake(false);" && \
            "m.cancelPhoto(); m.unfillPage(); } return '';")
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
   if mwJS("return window.__oxtMobileWeb.fillPage(false, 'fill');") is "no" then
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

/**
Whether the phone has a sensor the browser can read.

Parameters:
pSensor (string):
"location", "heading", "acceleration" or "rotation rate".

Returns (boolean):
true where the browser has a way to read the sensor; false on a desktop,
in a browser without one, and for a name that is not a sensor.

Example:
if mwSensorAvailable("location") then
   show button "Where am I"
end if

Description:
Use <mwSensorAvailable> to show only what the phone can do. A browser
that has the way may still find no sensor, or the user may say no: then
<mwStartSensor> sends trackingError.

References: mwStartSensor (command), mwSensorReading (function)
*/
function mwSensorAvailable pSensor
   if pSensor is not among the items of kSensors or not mwIsWeb() then
      return false
   end if
   mwInstallBrowserSide
   return mwJS("return window.__oxtMobileWeb.sensorAvailable(" & mwQuote(pSensor) & ");") is "true"
end mwSensorAvailable

/**
Start reading a sensor: where the phone is, which way it points, how it
is tilted or turning.

Parameters:
pSensor (string):
"location", "heading", "acceleration" or "rotation rate".

pLoosely (boolean):
true to read it less often or less exactly, which saves the battery:
the location from the network rather than the GPS, the heading when it
changes by 5 degrees, the motion five times a second. Empty for false.

Example:
on mouseUp
   mwStartSensor "location"
end mouseUp

on locationChanged pLatitude, pLongitude
   put "You are at" && pLatitude & comma & pLongitude into field "Where"
   mwStopSensor "location"
end locationChanged

Example:
-- a ball that rolls as the phone tilts
on openCard
   mwStartSensor "acceleration"
end openCard

on accelerationChanged pX, pY
   set the loc of graphic "Ball" to \
         item 1 of the loc of graphic "Ball" + round(pX * -10), \
         item 2 of the loc of graphic "Ball" + round(pY * 10)
end accelerationChanged

Description:
After <mwStartSensor> the current card of the stack that was the
default stack gets a message each time the sensor has a new reading,
by the names LiveCode's iOS and Android engines use:

- locationChanged pLatitude, pLongitude, pAltitude (degrees, and meters;
  the altitude is empty where the phone does not know it)
- headingChanged pHeading (degrees from north, clockwise)
- accelerationChanged pX, pY, pZ, pTime: in g, gravity included, so a
  phone lying flat reads about 0, 0 and 1 or -1; pTime in seconds
- rotationRateChanged pX, pY, pZ, pTime: how fast it turns about each
  axis, in radians a second

If the sensor cannot be read, the card gets trackingError pSensor,
pError ("permission denied" when the user said no) and the sensor is
stopped. <mwSensorReading> gives the last reading at any time.

Browsers ask the user before they give the location, and an iPhone
asks before the motion and the heading too; an iPhone asks only when
<mwStartSensor> is called from a tap (in mouseUp). The location needs a
page served over https (or from the same computer).

The result is "not available" where the browser has no way to read the
sensor, as on a desktop, and "unknown sensor: " and the name for a name
that is not one.

References: mwStopSensor (command), mwSensorReading (function), mwSensorAvailable (function)
*/
command mwStartSensor pSensor, pLoosely
   local tResult
   if pSensor is not among the items of kSensors then
      return "unknown sensor:" && pSensor
   end if
   if pLoosely is empty then
      put false into pLoosely
   end if
   if pLoosely is not a boolean then
      return "loosely is not true or false:" && pLoosely
   end if
   if not mwIsWeb() then
      return "not available"
   end if
   mwInstallBrowserSide
   put mwTargetStack() into sSensorStack
   put true into sSensors[pSensor]
   put mwJS("return window.__oxtMobileWeb.sensorOn(" & mwQuote(pSensor) & comma & pLoosely & ");") into tResult
   if tResult is not empty then
      delete variable sSensors[pSensor]
   end if
   return tResult
end mwStartSensor

/**
Stop reading a sensor.

Parameters:
pSensor (string):
"location", "heading", "acceleration" or "rotation rate".

Example:
on closeCard
   mwStopSensor "acceleration"
end closeCard

Description:
After <mwStopSensor> the card gets no more of that sensor's messages.
Stop a sensor when it is not needed: reading one uses the battery.
<mwStop> stops them all.

References: mwStartSensor (command)
*/
command mwStopSensor pSensor
   if pSensor is not among the items of kSensors then
      return "unknown sensor:" && pSensor
   end if
   delete variable sSensors[pSensor]
   delete variable sReading[pSensor]
   if mwIsWeb() then
      get mwJS("if (window.__oxtMobileWeb) window.__oxtMobileWeb.sensorOff(" & mwQuote(pSensor) & "); return '';")
   end if
   return empty
end mwStopSensor

/**
A sensor's last reading.

Parameters:
pSensor (string):
"location", "heading", "acceleration" or "rotation rate".

pDetailed (boolean):
true for an array with every value the browser gave; empty or false for
the main values, separated by commas.

Returns (string):
For "location", the latitude, longitude and altitude; for "heading",
the heading; for "acceleration" and "rotation rate", x, y and z. With
pDetailed, an array: "latitude", "longitude", "altitude", "horizontal
accuracy", "vertical accuracy", "speed", "course" and "timestamp" for a
location; "heading", "accuracy" and "timestamp" for a heading; "x", "y",
"z" and "timestamp" for the others. Empty before the first reading.

Example:
put mwSensorReading("location") into tWhere
if tWhere is not empty then
   put "Latitude:" && item 1 of tWhere into field "Where"
end if

Description:
Use <mwSensorReading> to look at a sensor's reading when it is needed,
instead of keeping each message's. The sensor must be started with
<mwStartSensor>; its reading is kept until it is stopped.

References: mwStartSensor (command)
*/
function mwSensorReading pSensor, pDetailed
   local tValues, tReading, tKeys, i
   if sSensors[pSensor] is not true then
      return empty
   end if
   put sReading[pSensor] into tValues
   if tValues is empty then
      return empty
   end if
   if pDetailed is not true then
      if pSensor is "heading" then
         return item 1 of tValues
      end if
      return item 1 to 3 of tValues
   end if
   switch pSensor
      case "location"
         put "latitude,longitude,altitude,horizontal accuracy,vertical accuracy,speed,course,timestamp" into tKeys
         break
      case "heading"
         put "heading,accuracy,timestamp" into tKeys
         break
      default
         put "x,y,z,timestamp" into tKeys
         break
   end switch
   repeat with i = 1 to the number of items of tKeys
      put item i of tValues into tReading[item i of tKeys]
   end repeat
   return tReading
end mwSensorReading

/**
Share text or a link through the phone's share sheet.

Parameters:
pText (string):
The text to share.

pURL (string):
A link to share. Empty for none.

pTitle (string):
A title, which some apps show. Empty for none.

Example:
on mouseUp
   mwShare "My best score is" && field "Score", "https://example.com/game"
   if the result is "copied" then answer "Copied, ready to paste."
end mouseUp

Description:
On a phone, <mwShare> opens the share sheet, where the user picks an
app (a message, an email, a note) to share with. Call it from a tap: a
browser opens the sheet only then. Where the browser has no share sheet,
as on most desktops, the text and the link are copied instead, ready to
paste, and the result is "copied". It is "not supported" where neither
can be done, "nothing to share" when the text and the link are empty,
and "not from a tap" when it was not called from a tap and the browser
can tell that it would not open the sheet.

References: mwVibrate (command)
*/
command mwShare pText, pURL, pTitle
   if pText is empty and pURL is empty then
      return "nothing to share"
   end if
   if not mwIsWeb() then
      if pText is not empty and pURL is not empty then
         set the clipboardData["text"] to pText && pURL
      else
         set the clipboardData["text"] to pText & pURL
      end if
      return "copied"
   end if
   mwInstallBrowserSide
   return mwJS("return window.__oxtMobileWeb.share(" & mwQuote(pText) & comma & mwQuote(pURL) & comma & mwQuote(pTitle) & ");")
end mwShare

/**
Keep the phone's screen on, or let it turn off again.

Parameters:
pAwake (boolean):
true to keep the screen on, false to let it turn off as usual.

Example:
-- a recipe, read while cooking
on openCard
   mwKeepAwake true
end openCard

on closeCard
   mwKeepAwake false
end closeCard

Description:
A phone turns its screen off after a while without a touch. Use
<mwKeepAwake> for a stack that is read or watched without being touched:
a recipe, a timer, a game played with the sensors. The screen stays on
while the page is in front, and again when the user comes back to it.
<mwStop> lets it go.

The result is "not supported" where the browser cannot keep the screen
on, as on a desktop or a page not served over https.

References: mwStop (command)
*/
command mwKeepAwake pAwake
   if pAwake is not a boolean then
      return "not true or false:" && pAwake
   end if
   if not mwIsWeb() then
      return "not supported"
   end if
   mwInstallBrowserSide
   return mwJS("return window.__oxtMobileWeb.keepAwake(" & pAwake & ");")
end mwKeepAwake

/**
Show the stack on the whole screen, without the browser's bars, or put
the bars back.

Parameters:
pFull (boolean):
true for the whole screen, false for the browser's bars back.

Example:
on mouseUp
   mwFullScreen not mwIsFullScreen()
end mouseUp

Description:
A phone's browser keeps its address bar (and on some phones, buttons)
over part of the screen. <mwFullScreen> true asks for the whole screen,
as a video does; the stack gets resizeStack (when <mwStart> fills the
screen with it) and is laid out for the new size. The user can leave
with the phone's back gesture.

Call it from a tap: a browser gives the whole screen only then. The
result is "not supported" where the browser cannot, such as on an iPhone
(an iPad can) and on a desktop outside a browser, and "not from a tap"
when it was not called from a tap. On an iPhone, a page added to the
home screen opens without the bars instead (see <mwIsInstalled>).

References: mwIsFullScreen (function), mwIsInstalled (function), mwStart (command)
*/
command mwFullScreen pFull
   if pFull is not a boolean then
      return "not true or false:" && pFull
   end if
   if not mwIsWeb() then
      return "not supported"
   end if
   mwInstallBrowserSide
   return mwJS("return window.__oxtMobileWeb.fullScreen(" & pFull & ");")
end mwFullScreen

/**
Whether the stack is on the whole screen, without the browser's bars.

Returns (boolean):
true after <mwFullScreen> true, until the user or <mwFullScreen> false
puts the bars back; false on a desktop.

Example:
if mwIsFullScreen() then
   set the label of button "Full" to "Show the bars"
end if

References: mwFullScreen (command)
*/
function mwIsFullScreen
   if not mwIsWeb() then
      return false
   end if
   mwInstallBrowserSide
   return mwJS("return window.__oxtMobileWeb.isFullScreen();") is "true"
end mwIsFullScreen

/**
Take a photo with the camera, or choose one of the phone's pictures, as
a new image on the card.

Parameters:
pSource (string):
"camera" or "rear camera" (the camera on the back), "front camera", or
"library" (a picture the phone has). Empty for "library".

pMaxWidth (number):
The widest the image may be, in pixels. Empty for 1280.

pMaxHeight (number):
The tallest the image may be, in pixels. Empty for 1280.

Example:
on mouseUp
   mwPickPhoto "camera", 600, 600
   if the result is "cancel" then exit mouseUp
   -- the photo is the card's last image
   set the rect of last image to the rect of graphic "Frame"
end mouseUp

Description:
<mwPickPhoto> opens the phone's camera, or its pictures, and waits until
the user has taken or chosen a photo. The photo becomes a new image on
the current card, the last image, made smaller to fit in pMaxWidth by
pMaxHeight (a phone's photo is far bigger than its screen); the result
is empty. When the user closes the camera without one, no image is made
and the result is "cancel". The stack goes on getting its messages while
<mwPickPhoto> waits.

Call it from a tap: a browser opens the camera only then. Called
otherwise, the result is "not from a tap" at once where the browser can
tell (Safari 16.4 and later, Chrome, Firefox), and no image is made. A
browser that cannot open the camera itself, as on a desktop, shows its
file chooser instead. In the IDE, "library" asks for a picture file and the
cameras give "not supported".

References: mwShare (command)
*/
command mwPickPhoto pSource, pMaxWidth, pMaxHeight
   local tData, tStack, tDefault, tImage, tScale, tStarted
   if pSource is empty then
      put "library" into pSource
   end if
   if pSource is not among the items of kPhotoSources then
      return "unknown source:" && pSource
   end if
   if pMaxWidth is empty then
      put kPhotoMax into pMaxWidth
   end if
   if pMaxHeight is empty then
      put kPhotoMax into pMaxHeight
   end if
   if pMaxWidth is not an integer or pMaxWidth < 1 or pMaxHeight is not an integer or pMaxHeight < 1 then
      return "not a size:" && pMaxWidth & comma & pMaxHeight
   end if
   if sPhotoState is "waiting" then
      return "busy"
   end if
   put mwTargetStack() into tStack

   if mwIsWeb() then
      mwInstallBrowserSide
      put empty into sPhoto
      put "waiting" into sPhotoState
      -- (a browser opens the camera only from a tap: "not from a tap"
      -- when it can tell that it would not, rather than waiting for a
      -- photo that cannot come)
      put mwJS("return window.__oxtMobileWeb.pickPhoto(" & mwQuote(pSource) & comma & pMaxWidth & comma & pMaxHeight & ");") into tStarted
      if tStarted is not empty then
         put empty into sPhotoState
         return tStarted
      end if
      wait until sPhotoState is not "waiting" with messages
      if sPhotoState is not "done" then
         put empty into sPhotoState
         return "cancel"
      end if
      put base64Decode(sPhoto) into tData
      put empty into sPhoto
      put empty into sPhotoState
   else
      if pSource is not "library" then
         return "not supported"
      end if
      answer file "Choose a photo:" with type "Pictures|jpg,jpeg,png,gif,bmp|"
      if it is empty then
         return "cancel"
      end if
      put URL ("binfile:" & it) into tData
   end if
   if there is not a stack tStack then
      return "cancel"
   end if

   put the defaultStack into tDefault
   set the defaultStack to tStack
   lock screen
   create image
   put it into tImage
   set the text of tImage to tData
   -- (a picture from the IDE's chooser keeps its pixels, and is shown
   -- smaller)
   put min(1, pMaxWidth / max(1, the width of tImage), pMaxHeight / max(1, the height of tImage)) into tScale
   if tScale < 1 then
      set the resizeQuality of tImage to "good"
      set the lockLoc of tImage to true
      set the width of tImage to max(1, round(the width of tImage * tScale))
      set the height of tImage to max(1, round(the height of tImage * tScale))
   end if
   set the loc of tImage to round(the width of stack tStack / 2), round(the height of stack tStack / 2)
   unlock screen
   set the defaultStack to tDefault
   return empty
end mwPickPhoto

/**
Which kind of screen a stack's size is laid out for: a phone's, a
tablet's or a desktop's.

Parameters:
pWidthOrStack:
A width in pixels, or the name of a stack (its width is used). Empty
for the <defaultStack>.

Returns (string):
"phone", "tablet" or "desktop".

Example:
if mwLayoutClass() is "phone" then
   hide group "Sidebar"
else
   show group "Sidebar"
end if

Example:
put mwLayoutClass(700) -- "tablet"

Description:
Use <mwLayoutClass> to lay a stack out by the room it has, as a web page
does with its breakpoints. It goes by the width alone: under 600 pixels
is "phone" (a phone held upright), 600 to 1023 is "tablet" (a tablet, or
a phone on its side), and 1024 and over is "desktop" (a computer's
window, or a big tablet on its side). <mwSetBreakpoints> changes the two
widths.

It answers the same on a desktop, in the IDE and in a browser, so a
stack can be tried in all three layouts in the IDE by making its window
narrower or wider. <mwResponsive> sends layoutChanged when the class
changes, and lays out the controls that have rules for it.

References: mwResponsive (command), mwSetBreakpoints (command), mwBreakpoints (function), mwPointer (function)
*/
function mwLayoutClass pWidthOrStack
   local tWidth, tBreaks
   if pWidthOrStack is empty then
      put the width of the defaultStack into tWidth
   else if pWidthOrStack is a number then
      put pWidthOrStack into tWidth
   else if there is a stack pWidthOrStack then
      put the width of stack pWidthOrStack into tWidth
   else
      return empty
   end if
   put mwBreakpoints() into tBreaks
   if tWidth < item 1 of tBreaks then
      return "phone"
   else if tWidth < item 2 of tBreaks then
      return "tablet"
   end if
   return "desktop"
end mwLayoutClass

/**
The widths at which <mwLayoutClass> changes.

Returns (string):
Two numbers, separated by a comma: the width from which a stack is laid
out as a tablet's, and the width from which it is laid out as a
desktop's. "600,1024" unless <mwSetBreakpoints> changed them.

Example:
put item 2 of mwBreakpoints() into tDesktopWidth

References: mwSetBreakpoints (command), mwLayoutClass (function)
*/
function mwBreakpoints
   if sBreakpoints is empty then
      return kBreakpoints
   end if
   return sBreakpoints
end mwBreakpoints

/**
Change the widths at which <mwLayoutClass> changes.

Parameters:
pTablet (number):
The width, in pixels, from which a stack is laid out as a tablet's.

pDesktop (number):
The width from which it is laid out as a desktop's: more than pTablet.

Example:
-- a stack whose desktop layout needs more room
mwSetBreakpoints 600, 1200

Example:
-- back to 600 and 1024
mwSetBreakpoints

Description:
With no parameters, the widths go back to 600 and 1024. The breakpoints
are the same for every stack. The stacks that <mwResponsive> lays out
are laid out again for the new widths, and get layoutChanged if their
class changes.

If the widths are not two whole numbers, the second more than the first,
nothing changes and the result is "bad breakpoints".

References: mwBreakpoints (function), mwLayoutClass (function), mwResponsive (command)
*/
command mwSetBreakpoints pTablet, pDesktop
   local tStack
   if pTablet is empty and pDesktop is empty then
      put empty into sBreakpoints
   else
      if pTablet is not an integer or pDesktop is not an integer or pTablet < 1 or pDesktop <= pTablet then
         return "bad breakpoints"
      end if
      put pTablet & comma & pDesktop into sBreakpoints
   end if
   repeat for each key tStack in sResponsive
      mwCheckLayout tStack
   end repeat
   return empty
end mwSetBreakpoints

/**
What the stack is used with: a finger, a mouse, or both.

Returns (string):
"touch", "mouse" or "both".

Example:
-- bigger targets for a finger, hover effects for a mouse
if mwPointer() is "touch" then
   set the height of button "Save" to 48
else
   set the height of button "Save" to 32
end if

Description:
In a browser, "touch" is a phone or a tablet, "mouse" a computer with a
mouse or a trackpad, and "both" a computer with a touch screen or a
tablet with a trackpad, as the browser reports them (the CSS any-pointer
media feature). On a desktop it is "mouse".

The pointer and the size go apart: a tablet on its side is as wide as a
small computer's window. Use <mwLayoutClass> to arrange the controls, and
<mwPointer> to size them for a finger and to choose whether hovering
shows anything.

References: mwLayoutClass (function), mwIsTouchScreen (function)
*/
function mwPointer
   local tPointer
   if not mwIsWeb() then
      return "mouse"
   end if
   put mwJS("var m = function(q) { return !!(window.matchMedia && window.matchMedia(q).matches); };" && \
         "var c = m('(any-pointer: coarse)'), f = m('(any-pointer: fine)');" && \
         "if (!c && !f) return (navigator.maxTouchPoints || 0) > 0 ? 'touch' : 'mouse';" && \
         "return c && f ? 'both' : (c ? 'touch' : 'mouse');") into tPointer
   if tPointer is not among the items of "touch,mouse,both" then
      return "mouse"
   end if
   return tPointer
end mwPointer

/**
Whether the browser or the computer is set to a dark look.

Returns (string):
"dark" or "light".

Example:
if mwAppearance() is "dark" then
   set the backColor of this stack to "#111827"
end if

Description:
In a browser, <mwAppearance> is what the browser asks pages for (the CSS
prefers-color-scheme), whatever the standalone's settings. On a desktop
it is the <systemAppearance>.

The <systemAppearanceChanged> message says when it changes: on a desktop,
and in an HTML5 standalone built with Appearance set to "Follow the
browser" in the Web pane of the Standalone Application Settings.

References: systemAppearance (property), systemAppearanceChanged (message)
*/
function mwAppearance
   local tLook, tError
   if mwIsWeb() then
      put mwJS("return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';") into tLook
   else
      try
         put the systemAppearance into tLook
      catch tError
         put "light" into tLook
      end try
   end if
   if tLook is "dark" then
      return "dark"
   end if
   return "light"
end mwAppearance

/**
Lay a stack out for a phone, a tablet or a desktop, and again whenever its
size changes.

Parameters:
pStack (string):
The name of the stack. Empty for the <defaultStack>.

pOn (boolean):
false to stop. Empty or true to start.

Example:
on preOpenStack
   mwStart -- fill a phone's screen (does nothing on a desktop)
   mwResponsive -- and lay the stack out for its size
end preOpenStack

on layoutChanged pClass, pOrientation
   -- "phone", "tablet" or "desktop"; "portrait" or "landscape"
   set the label of button "Menu" to pClass
end layoutChanged

Example:
-- rules that the library follows: a sidebar on a desktop, none on a phone
set the mwLayout["desktop"] of group "Sidebar" to "left 0, top 0, bottom 0, width 240"
set the mwLayout["phone"] of group "Sidebar" to "hidden"
set the mwLayout["desktop"] of group "Cards" to "left 256, top 16, right 16, bottom 16, flow 3"
set the mwLayout["all"] of group "Cards" to "left 16, top 16, right 16, bottom 72, flow"

Description:
<mwResponsive> makes one stack fit a phone, a tablet and a desktop, as a
web page does. Each time the stack's size changes, on a desktop or in a
browser, it does two things:

1. It lays out the controls that have rules: the keys of their mwLayout
   custom property set, below.
2. When the stack's layout class (<mwLayoutClass>) or orientation has
   changed, it sends layoutChanged pClass, pOrientation to the current
   card, so a script can do the rest. It is sent once at once, when
   <mwResponsive> starts.

A rule is a key of a control's mwLayout custom property set: "phone",
"tablet" or "desktop", any of them followed by a space and "portrait" or
"landscape" ("phone landscape"), or "all". The most particular key that
the control has is used: "phone landscape", then "phone", then "all". A
control with no key that fits is left alone. A rule is a list of these,
separated by commas:

- left N, top N, right N, bottom N: the distance from that edge of the
  card (right and bottom from the right and bottom edges). N is in
  pixels, or a percentage of the card's width or height ("50%").
- width N, height N: the size. With left and right both given, the
  width follows from them; with neither, the control keeps its place.
  The same goes for top, bottom and height.
- hidden: the control is hidden in this layout. In a layout whose rule
  does not say hidden, it is shown again; a control that a script hid
  stays hidden.
- within: measure from the group the control is in, not from the card:
  for the controls of a card in a grid, or of a panel.
- bleed: an edge at 0 reaches on past the safe area to the edge of the
  screen (or of the group, with within). The distances are measured
  inside the safe area, out of a phone's notch and home bar, once
  <mwStart> fills the screen (on a desktop there is none); a bar's
  background with "bleed, top 0, height 56" fills the notch above it,
  while the title in it stays below the notch.
- flow N, and gap N: for a group, arrange the controls in it in N
  columns, as <mwFlow> does; flow alone chooses 1, 2 or 3 columns by
  the class.

The rules are followed for every card of the stack, and a control
shared by cards (a group placed on them) once. A group's controls move
with it, and a group placed by a rule keeps the rectangle it is given
(its lockLocation is set to true); the rules within a group are followed
after the group is placed and its controls flowed.

The stack's size changes reach the library as resizeStack: if the stack
has a resizeStack handler, it must pass the message, as for the Geometry
Manager. A resizeStack handler that wants the rules followed first, so
as to place other controls by the ones they moved, calls
<mwApplyLayout> before it does so.

On its own, <mwResponsive> neither fills a phone's screen nor sends the
gestures: <mwStart> does those. Together, a resizable stack fills the
browser's window and is laid out for it again as the phone turns.

If the stack does not exist, the result is "no such stack:" and its name.

References: mwLayoutClass (function), mwApplyLayout (command), mwFlow (command), mwSetBreakpoints (command), mwStart (command), mwPointer (function)
*/
command mwResponsive pStack, pOn
   if pStack is empty then
      put the short name of the defaultStack into pStack
   end if
   if pOn is false then
      if there is a stack pStack then
         put the short name of stack pStack into pStack
      end if
      delete variable sResponsive[pStack]
      delete variable sApplied[pStack]
      return empty
   end if
   if there is not a stack pStack then
      return "no such stack:" && pStack
   end if
   put the short name of stack pStack into pStack
   put empty into sResponsive[pStack]
   delete variable sApplied[pStack]
   mwCheckLayout pStack
   return empty
end mwResponsive

/**
Follow a stack's layout rules now.

Parameters:
pStack (string):
The name of the stack. Empty for the <defaultStack>.

Example:
on resizeStack
   mwApplyLayout -- the rules first
   -- then a control placed by one that a rule moved
   set the top of field "Note" to the bottom of group "Header" + 8
   pass resizeStack
end resizeStack

Description:
<mwApplyLayout> lays out the controls of every card of the stack that
have rules for its size now, the keys of their mwLayout custom property
set (see <mwResponsive>). <mwResponsive> does it each time the stack's
size changes; call it to have it done before your own code, or after
making controls or changing their rules. It sends no message.

It works on any stack, whether <mwResponsive> started or not, and on a
desktop as in a browser.

A rule that cannot be read is left out, and the result is "bad rule:",
the control's name and the rule; otherwise the result is empty.

References: mwResponsive (command), mwFlow (command)
*/
command mwApplyLayout pStack
   local tClass, tOrient, tCard, tCount, i, tControl, tId
   local tDone, tRule, tFlows, tFlow, tFirstError, tKey, tWithin
   if pStack is empty then
      put the short name of the defaultStack into pStack
   end if
   if there is not a stack pStack then
      return "no such stack:" && pStack
   end if
   put the short name of stack pStack into pStack
   put mwLayoutKey(pStack) into tKey
   put item 3 of tKey into tClass
   put item 4 of tKey into tOrient

   lock screen
   repeat with tCard = 1 to the number of cards of stack pStack
      put the number of controls of card tCard of stack pStack into tCount
      repeat with i = 1 to tCount
         put the long id of control i of card tCard of stack pStack into tControl
         -- a group placed on several cards, and the controls in it, once
         put the id of tControl into tId
         if tDone[tId] then
            next repeat
         end if
         put true into tDone[tId]
         put mwRuleFor(tControl, tClass, tOrient) into tRule
         if tRule is empty then
            next repeat
         end if
         -- a rule "within" its group: once the groups are placed and
         -- their controls flowed (in the order of the controls, a
         -- group's before those in it)
         if mwRuleIsWithin(tRule) then
            put tControl & return after tWithin
            next repeat
         end if
         -- "ok" or "bad", then for a group to flow: "flow", its columns
         -- and its gap
         put mwFollowRule(tControl, tRule, pStack, tKey) into tFlow
         if item 1 of tFlow is "bad" and tFirstError is empty then
            put "bad rule:" && the short name of tControl & ":" && tRule into tFirstError
         end if
         if item 2 of tFlow is "flow" then
            -- a group's own controls after every control's rule
            put tControl & tab & item 3 of tFlow & tab & item 4 of tFlow & return after tFlows
         end if
      end repeat
   end repeat
   set the itemDelimiter to tab
   repeat for each line tFlow in tFlows
      if there is a (item 1 of tFlow) then
         mwFlow item 1 of tFlow, item 2 of tFlow, item 3 of tFlow
      end if
   end repeat
   set the itemDelimiter to comma
   repeat for each line tControl in tWithin
      if there is not a tControl then
         next repeat
      end if
      put mwRuleFor(tControl, tClass, tOrient) into tRule
      put mwFollowRule(tControl, tRule, pStack, tKey) into tFlow
      if item 1 of tFlow is "bad" and tFirstError is empty then
         put "bad rule:" && the short name of tControl & ":" && tRule into tFirstError
      end if
      if item 2 of tFlow is "flow" then
         mwFlow tControl, item 3 of tFlow, item 4 of tFlow
      end if
   end repeat
   unlock screen

   put tKey into sApplied[pStack]
   return tFirstError
end mwApplyLayout

/**
Arrange the controls in a group in columns, as a grid of cards.

Parameters:
pGroup:
A reference to the group, such as the long id of a group.

pColumns (number):
The number of columns. Empty for one on a phone, two on a tablet and
three on a desktop, by the <mwLayoutClass> of the group's stack.

pGap (number):
The space between the controls, and around them, in pixels. Empty for
12.

Returns:
The height that the controls take up, from the top of the group, in
the result.

Example:
-- a grid of cards that reflows by the width of the window
on resizeStack pWidth, pHeight
   set the rect of group "Cards" to 0, 56, pWidth, pHeight
   mwFlow the long id of group "Cards"
   pass resizeStack
end resizeStack

Description:
<mwFlow> places the visible controls that are directly in the group, in
the order of their layers, left to right in rows: every control is made
as wide as a column, keeps its height, and a row is as tall as its
tallest control. A hidden control is left out. Then the rules "within" the
controls it placed are followed (see <mwResponsive>), so a group in the
grid can lay out its own controls for its new width. The group keeps its
rectangle (its lockLocation is set to true); if the controls need more
height than it has, give it a scroll bar or use <mwDragScroll> on it. Its
scroll is kept, as far as the new height allows.

A rule of the mwLayout custom property set with "flow" does the same each
time the stack's size changes (see <mwResponsive>).

If pGroup is not a group, the result is "no such group".

References: mwResponsive (command), mwLayoutClass (function), mwDragScroll (command)
*/
command mwFlow pGroup, pColumns, pGap
   local tGroup, tStack, tCount, i, tChild, tKids, tLeft, tTop, tWidth, tColWidth
   local tCol, tX, tY, tRowHeight, tScroll, tScrollbar, tHeight, tError
   try
      put the long id of pGroup into tGroup
   catch tError
      return "no such group"
   end try
   if word 1 of tGroup is not "group" then
      return "no such group"
   end if
   if pColumns is empty then
      put mwStackOfObject(tGroup) into tStack
      switch mwLayoutClass(tStack)
         case "phone"
            put 1 into pColumns
            break
         case "tablet"
            put 2 into pColumns
            break
         default
            put 3 into pColumns
            break
      end switch
   end if
   if pColumns is not an integer or pColumns < 1 then
      put 1 into pColumns
   end if
   if pGap is not a number or pGap < 0 then
      put kFlowGap into pGap
   end if

   -- the group's own controls, not the controls of the groups in it
   put the number of controls of tGroup into tCount
   repeat with i = 1 to tCount
      put the long id of control i of tGroup into tChild
      if the long id of the owner of tChild is not tGroup then
         next repeat
      end if
      if not the visible of tChild then
         next repeat
      end if
      put tChild & return after tKids
   end repeat

   lock screen
   set the lockLocation of tGroup to true
   -- laid out unscrolled, then scrolled back as far as it still goes
   put the vScroll of tGroup into tScroll
   if tScroll is not 0 then
      set the vScroll of tGroup to 0
   end if
   put 0 into tScrollbar
   if the vScrollbar of tGroup then
      put the scrollbarWidth of tGroup into tScrollbar
   end if
   put the left of tGroup + pGap into tLeft
   put the top of tGroup + pGap into tTop
   put the width of tGroup - tScrollbar - 2 * pGap into tWidth
   put max(1, (tWidth - (pColumns - 1) * pGap) / pColumns) into tColWidth
   put tTop into tY
   put 0 into tRowHeight
   put 0 into tCol
   repeat for each line tChild in tKids
      if tCol is pColumns then
         put tY + tRowHeight + pGap into tY
         put 0 into tRowHeight
         put 0 into tCol
      end if
      put round(tLeft + tCol * (tColWidth + pGap)) into tX
      put the height of tChild into tHeight
      -- (a group's controls move with its topLeft, not with its rect;
      -- and it keeps the rect it is given, rather than shrinking to them)
      if word 1 of tChild is "group" then
         set the lockLocation of tChild to true
      end if
      set the topLeft of tChild to tX, tY
      set the rect of tChild to tX, tY, round(tLeft + tCol * (tColWidth + pGap) + tColWidth), tY + tHeight
      put max(tRowHeight, tHeight) into tRowHeight
      add 1 to tCol
   end repeat
   if tKids is not empty then
      put tY + tRowHeight + pGap into tY
   end if
   -- the rules "within" the controls placed, now that they have their
   -- size (a card in the grid laid out inside itself)
   if tStack is empty then
      put mwStackOfObject(tGroup) into tStack
   end if
   repeat for each line tChild in tKids
      if word 1 of tChild is "group" then
         mwApplyWithin tChild, tStack
      end if
   end repeat
   if tScroll is not 0 then
      set the vScroll of tGroup to min(tScroll, max(0, (tY - the top of tGroup) - the height of tGroup))
   end if
   unlock screen
   return tY - the top of tGroup
end mwFlow

-- The rules "within" a group, of the controls in it (and in the groups
-- in it), for its stack's size now
private command mwApplyWithin pGroup, pStack
   local tKey, i, tControl, tRule, tFlow
   if pStack is empty or there is not a stack pStack then
      exit mwApplyWithin
   end if
   put mwLayoutKey(pStack) into tKey
   repeat with i = 1 to the number of controls of pGroup
      put the long id of control i of pGroup into tControl
      put mwRuleFor(tControl, item 3 of tKey, item 4 of tKey) into tRule
      if tRule is empty or not mwRuleIsWithin(tRule) then
         next repeat
      end if
      put mwFollowRule(tControl, tRule, pStack, tKey) into tFlow
      if item 2 of tFlow is "flow" then
         mwFlow tControl, item 3 of tFlow, item 4 of tFlow
      end if
   end repeat
end mwApplyWithin

-- Whether a rule is measured within the control's group
private function mwRuleIsWithin pRule
   replace comma with space in pRule
   return "within" is among the words of pRule
end mwRuleIsWithin

-- A stack that mwResponsive lays out has changed its size: its rules
-- followed, and layoutChanged when its class or orientation is new.
-- (Only the stacks mwResponsive started; the message always goes on.)
on resizeStack
   local tStack
   if sResponsive is an array then
      put mwStackOfObject(the long id of the target) into tStack
      if tStack is not empty and tStack is among the lines of the keys of sResponsive then
         mwCheckLayout tStack
      end if
   end if
   pass resizeStack
end resizeStack

-- The stack's rules followed, unless they already were for its size (as
-- when its own resizeStack called mwApplyLayout), and layoutChanged sent
-- to its card when its class or its orientation has changed
private command mwCheckLayout pStack
   local tNow
   if there is not a stack pStack then
      delete variable sResponsive[pStack]
      delete variable sApplied[pStack]
      exit mwCheckLayout
   end if
   if sApplied[pStack] is not mwLayoutKey(pStack) then
      mwApplyLayout pStack
   end if
   put item 3 to 4 of sApplied[pStack] into tNow
   if tNow is not sResponsive[pStack] then
      put tNow into sResponsive[pStack]
      dispatch "layoutChanged" to this card of stack pStack with item 1 of tNow, item 2 of tNow
   end if
end mwCheckLayout

-- What a stack is laid out for: width, height, class, orientation, and
-- the safe area's insets (top, right, bottom, left)
private function mwLayoutKey pStack
   local tW, tH, tOrient
   put the width of stack pStack into tW
   put the height of stack pStack into tH
   if tW > tH then
      put "landscape" into tOrient
   else
      put "portrait" into tOrient
   end if
   return tW, tH, mwLayoutClass(tW), tOrient, mwInsetsFor(pStack)
end mwLayoutKey

-- The safe area's insets (top, right, bottom, left) for a stack's
-- rules: the notch's and the home bar's where the library fills a
-- phone's screen with the stack, 0 everywhere else
private function mwInsetsFor pStack
   local tView
   if not mwIsWeb() or sOptions["fill"] is not pStack then
      return "0,0,0,0"
   end if
   put mwViewport() into tView
   return max(0, tView["top"]), max(0, tView["right"]), max(0, tView["bottom"]), max(0, tView["left"])
end mwInsetsFor

-- The short name of the stack an object is in (its own, for a stack), or
-- empty
private function mwStackOfObject pObject
   local tObject, tError, i
   put pObject into tObject
   try
      repeat with i = 1 to 100
         if word 1 of tObject is "stack" then
            return the short name of tObject
         end if
         put the long owner of tObject into tObject
         if tObject is empty then
            exit repeat
         end if
      end repeat
   catch tError
   end try
   return empty
end mwStackOfObject

-- A control's rule for a class and orientation: its mwLayout key
-- "<class> <orientation>", else "<class>", else "all"; empty for none
private function mwRuleFor pControl, pClass, pOrient
   local tRules
   put the customProperties["mwLayout"] of pControl into tRules
   if tRules is not an array then
      return empty
   end if
   if tRules[pClass && pOrient] is not empty then
      return tRules[pClass && pOrient]
   end if
   if tRules[pClass] is not empty then
      return tRules[pClass]
   end if
   return tRules["all"]
end mwRuleFor

-- A distance of a rule in pixels: N, or N% of pWhole; empty if it is
-- neither
private function mwRuleValue pText, pWhole
   if char -1 of pText is "%" then
      delete char -1 of pText
      if pText is not a number then
         return empty
      end if
      return round(pWhole * pText / 100)
   end if
   if pText is not a number then
      return empty
   end if
   return round(pText)
end mwRuleValue

-- One control placed by its rule (see mwResponsive) for its stack's
-- layout now, pKey (mwLayoutKey: width, height, class, orientation and
-- the safe area's insets, top, right, bottom and left). Returns "ok", or
-- "bad" when a part of the rule cannot be read (the rest is followed);
-- then for a group with "flow", "flow", its columns (empty to choose by
-- the class) and its gap
private function mwFollowRule pControl, pRule, pStack, pKey
   local tPart, tWord, tValue, tSpec, tHide, tBleed, tWithin, tFlow, tGap, tNew, tOk
   local tBox, tOwner, tL, tT, tR, tB, tAreaW, tAreaH, tRect, tX1, tY1, tX2, tY2
   put "ok" into tOk
   repeat for each item tPart in pRule
      put word 1 to -1 of tPart into tPart
      if tPart is empty then
         next repeat
      end if
      put word 1 of tPart into tWord
      put word 2 of tPart into tValue
      if tWord is not among the items of kRuleWords or the number of words of tPart > 2 then
         put "bad" into tOk
         next repeat
      end if
      switch tWord
         case "hidden"
            put true into tHide
            break
         case "shown"
            break
         case "bleed"
            put true into tBleed
            break
         case "within"
            put true into tWithin
            break
         case "flow"
            if tValue is empty then
               put "auto" into tFlow
            else if tValue is an integer and tValue > 0 then
               put tValue into tFlow
            else
               put "bad" into tOk
            end if
            break
         case "gap"
            if tValue is a number and tValue >= 0 then
               put tValue into tGap
            else
               put "bad" into tOk
            end if
            break
         default
            put tValue into tSpec[tWord]
            break
      end switch
   end repeat

   -- hidden in this layout; shown again in a layout that does not say
   -- so, if a rule hid it (a control that a script hid stays hidden). The
   -- mark is kept with the control, so that it lasts when the stack is
   -- saved and opened again
   if tHide then
      if the visible of pControl then
         set the visible of pControl to false
         set the mwLayoutHid of pControl to true
      end if
      return tOk
   end if
   if the mwLayoutHid of pControl is true then
      set the mwLayoutHid of pControl to false
      set the visible of pControl to true
   end if

   -- the box the rule is in (the card, or with "within" the control's
   -- group), and the part of it the distances are measured in: inside
   -- the safe area, out of a notch and a home bar
   put 0, 0, item 1 of pKey, item 2 of pKey into tBox
   if tWithin then
      put the long id of the owner of pControl into tOwner
      if word 1 of tOwner is "group" then
         put the rect of tOwner into tBox
      end if
   end if
   -- An edge of the box that lies in the strip a notch or the home bar
   -- covers (from the stack's edge to the inset) is moved out of it. An
   -- edge outside the stack, as a card of a grid below the window or
   -- scrolled above it has, is left where it is: measuring it against the
   -- window would leave the card's controls no room at all
   put item 1 of tBox into tL
   if tL >= 0 and tL < item 8 of pKey then
      put item 8 of pKey into tL
   end if
   put item 2 of tBox into tT
   if tT >= 0 and tT < item 5 of pKey then
      put item 5 of pKey into tT
   end if
   put item 3 of tBox into tR
   if tR <= item 1 of pKey and tR > item 1 of pKey - item 6 of pKey then
      put item 1 of pKey - item 6 of pKey into tR
   end if
   put item 4 of tBox into tB
   if tB <= item 2 of pKey and tB > item 2 of pKey - item 7 of pKey then
      put item 2 of pKey - item 7 of pKey into tB
   end if
   put max(0, tR - tL) into tAreaW
   put max(0, tB - tT) into tAreaH
   repeat for each item tWord in kRuleEdges
      if tSpec[tWord] is empty then
         next repeat
      end if
      if tWord is among the items of "left,right,width" then
         put mwRuleValue(tSpec[tWord], tAreaW) into tSpec[tWord]
      else
         put mwRuleValue(tSpec[tWord], tAreaH) into tSpec[tWord]
      end if
      if tSpec[tWord] is empty then
         put "bad" into tOk
         delete variable tSpec[tWord]
      end if
   end repeat

   put the rect of pControl into tRect
   put item 1 of tRect into tX1
   put item 2 of tRect into tY1
   put item 3 of tRect into tX2
   put item 4 of tRect into tY2
   if tSpec["left"] is not empty and tSpec["right"] is not empty then
      put tL + tSpec["left"] into tX1
      put tR - tSpec["right"] into tX2
   else if tSpec["left"] is not empty then
      put tL + tSpec["left"] into tX1
      if tSpec["width"] is not empty then
         put tX1 + tSpec["width"] into tX2
      else
         put tX1 + item 3 of tRect - item 1 of tRect into tX2
      end if
   else if tSpec["right"] is not empty then
      put tR - tSpec["right"] into tX2
      if tSpec["width"] is not empty then
         put tX2 - tSpec["width"] into tX1
      else
         put tX2 - (item 3 of tRect - item 1 of tRect) into tX1
      end if
   else if tSpec["width"] is not empty then
      put tX1 + tSpec["width"] into tX2
   end if
   if tSpec["top"] is not empty and tSpec["bottom"] is not empty then
      put tT + tSpec["top"] into tY1
      put tB - tSpec["bottom"] into tY2
   else if tSpec["top"] is not empty then
      put tT + tSpec["top"] into tY1
      if tSpec["height"] is not empty then
         put tY1 + tSpec["height"] into tY2
      else
         put tY1 + item 4 of tRect - item 2 of tRect into tY2
      end if
   else if tSpec["bottom"] is not empty then
      put tB - tSpec["bottom"] into tY2
      if tSpec["height"] is not empty then
         put tY2 - tSpec["height"] into tY1
      else
         put tY2 - (item 4 of tRect - item 2 of tRect) into tY1
      end if
   else if tSpec["height"] is not empty then
      put tY1 + tSpec["height"] into tY2
   end if
   -- "bleed": an edge at 0 from the safe area's reaches on to the box's
   -- (under the notch, or the home bar)
   if tBleed then
      if tSpec["left"] is 0 then
         put item 1 of tBox into tX1
      end if
      if tSpec["top"] is 0 then
         put item 2 of tBox into tY1
      end if
      if tSpec["right"] is 0 then
         put item 3 of tBox into tX2
      end if
      if tSpec["bottom"] is 0 then
         put item 4 of tBox into tY2
      end if
   end if
   put max(tX1, tX2) into tX2
   put max(tY1, tY2) into tY2
   put tX1, tY1, tX2, tY2 into tNew
   if tNew is not tRect then
      -- a group's controls move with its topLeft (not with its rect, which
      -- only changes its own bounds), so the group's contents go with it;
      -- and it keeps the rect it is given, rather than shrinking to them
      if word 1 of pControl is "group" then
         set the lockLocation of pControl to true
         set the topLeft of pControl to tX1, tY1
      end if
      set the rect of pControl to tNew
   end if

   if tFlow is not empty and word 1 of pControl is "group" then
      if tFlow is "auto" then
         put empty into tFlow
      end if
      return tOk & ",flow," & tFlow & comma & tGap
   end if
   return tOk
end mwFollowRule

-- The browser calls this (it is the library stack's only
-- javascriptHandlers entry) with a kind and its values; see mwStart for
-- the messages
on mwFromBrowser pKind, p1, p2, p3, p4
   local tKeyboard, tOrientation, tObject, tStack
   -- a photo, and the sensors: whether or not mwStart was called
   switch pKind
      case "photo"
         if sPhotoState is "waiting" then
            put p1 into sPhoto
            put "done" into sPhotoState
         end if
         exit mwFromBrowser
      case "photocancel"
         if sPhotoState is "waiting" then
            put "cancel" into sPhotoState
         end if
         exit mwFromBrowser
      case "sensor"
         mwSensorSays p1, p2
         exit mwFromBrowser
      case "sensorerror"
         if sSensors[p1] is true then
            delete variable sSensors[p1]
            mwSendToCardOf sSensorStack, "trackingError", p1, p2
         end if
         exit mwFromBrowser
   end switch
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
         -- the stacks laid out by mwResponsive, for a new safe area (a
         -- new size has laid them out already, through resizeStack)
         repeat for each key tStack in sResponsive
            mwCheckLayout tStack
         end repeat
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
      case "touchstart"
         mwToCard p2, p3
         put mwControlAt(p2, p3) into sTouchTarget[p1]
         mwSendAt "touchStart", sTouchTarget[p1], p1, p2, p3
         break
      case "touchmove"
         mwToCard p2, p3
         mwSendAt "touchMove", sTouchTarget[p1], p1, p2, p3
         break
      case "touchend"
      case "touchrelease"
         mwToCard p2, p3
         put sTouchTarget[p1] into tObject
         delete variable sTouchTarget[p1]
         if pKind is "touchend" then
            mwSendAt "touchEnd", tObject, p1, p2, p3
         else
            mwSendAt "touchRelease", tObject, p1, p2, p3
         end if
         break
   end switch
end mwFromBrowser

-- A sensor's reading, as the browser sent it (items, see mwSensorReading),
-- kept and sent on to the card
private command mwSensorSays pSensor, pValues
   if sSensors[pSensor] is not true then
      exit mwSensorSays
   end if
   put pValues into sReading[pSensor]
   switch pSensor
      case "location"
         mwSendToCardOf sSensorStack, "locationChanged", item 1 of pValues, item 2 of pValues, item 3 of pValues
         break
      case "heading"
         mwSendToCardOf sSensorStack, "headingChanged", item 1 of pValues
         break
      case "acceleration"
         mwSendToCardOf sSensorStack, "accelerationChanged", item 1 of pValues, item 2 of pValues, \
               item 3 of pValues, item 4 of pValues
         break
      case "rotation rate"
         mwSendToCardOf sSensorStack, "rotationRateChanged", item 1 of pValues, item 2 of pValues, \
               item 3 of pValues, item 4 of pValues
         break
   end switch
end mwSensorSays

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

private command mwSendToCardOf pStack, pMessage, p1, p2, p3, p4
   if pStack is empty or there is not a stack pStack then
      exit mwSendToCardOf
   end if
   dispatch pMessage to this card of stack pStack with p1, p2, p3, p4
end mwSendToCardOf

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
   put "var mw = {gestures: {}, on: false, fingers: {}, nextFinger: 1, moveFrame: null, start0: null, pinch: null, press: null," & return after tScript
   put "  pressed: false, queue: [], timer: null, probe: null, lastView: '', sensors: {}, wantWake: false, wake: null, waking: false, photo: null, tallest: {}};" & return after tScript
   put "function call(kind, a, b, c, d) {" & return after tScript
   put "  mw.queue.push([kind, a, b, c, d]);" & return after tScript
   put "  if (mw.timer === null) mw.timer = setTimeout(flush, 0);" & return after tScript
   put "}" & return after tScript
   put "function flush() {" & return after tScript
   put "  mw.timer = null;" & return after tScript
   put "  var q = mw.queue; mw.queue = [];" & return after tScript
   put "  var h = document.liveCode && document.liveCode.findStackWithName(lib);" & return after tScript
   put "  if (!h || !h.mwFromBrowser) return;" & return after tScript
   put "  for (var i = 0; i < q.length; i++) h.mwFromBrowser(q[i][0], q[i][1], q[i][2], q[i][3], q[i][4]);" & return after tScript
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
   put "// The safe area can change after the last event of a turn (Safari on an" & return after tScript
   put "// iPhone moves the notch's inset to the side once the turn has settled):" & return after tScript
   put "// a box sized by the insets tells of each change as a resize" & return after tScript
   put "function watchInsets(on) {" & return after tScript
   put "  if (!on) { if (mw.insetWatch) { mw.insetWatch.disconnect(); mw.insetWatch = null; } return; }" & return after tScript
   put "  if (mw.insetWatch || typeof ResizeObserver !== 'function') return;" & return after tScript
   put "  if (!mw.insetBox) {" & return after tScript
   put "    mw.insetBox = document.createElement('div');" & return after tScript
   put "    mw.insetBox.style.cssText = 'position:fixed;left:0;top:0;visibility:hidden;pointer-events:none;' +" & return after tScript
   put "      'width:calc(1px + env(safe-area-inset-left) + 3 * env(safe-area-inset-right));' +" & return after tScript
   put "      'height:calc(1px + env(safe-area-inset-top) + 3 * env(safe-area-inset-bottom))';" & return after tScript
   put "    document.body.appendChild(mw.insetBox);" & return after tScript
   put "  }" & return after tScript
   put "  mw.insetWatch = new ResizeObserver(function() { viewSoon(); });" & return after tScript
   put "  mw.insetWatch.observe(mw.insetBox);" & return after tScript
   put "}" & return after tScript
   put "// A web app opened from an iPhone's Home Screen (navigator.standalone) has" & return after tScript
   put "// no toolbar to come and go, and Safari takes nothing from innerHeight for" & return after tScript
   put "// the keyboard: its page is as tall at a width as it ever was. Yet once it" & return after tScript
   put "// has turned and turned back, WebKit can say the page is shorter, for as" & return after tScript
   put "// long as the app runs (the stack's bottom up, black under it). There the" & return after tScript
   put "// tallest height seen at a width stands, while the page is as wide as the" & return after tScript
   put "// screen (an iPad's window can be any size); everywhere else innerHeight" & return after tScript
   put "function homeScreenApp(lw) {" & return after tScript
   put "  if (window.navigator.standalone !== true || !window.screen) return false;" & return after tScript
   put "  return lw === screen.width || lw === screen.height;" & return after tScript
   put "}" & return after tScript
   put "function pageHeight(lw) {" & return after tScript
   put "  var lh = window.innerHeight;" & return after tScript
   put "  if (!homeScreenApp(lw)) return lh;" & return after tScript
   put "  var best = mw.tallest[lw] || 0, most = Math.max(screen.width, screen.height);" & return after tScript
   put "  if (lh > best && lh <= most) { mw.tallest[lw] = lh; best = lh; }" & return after tScript
   put "  return Math.max(lh, best);" & return after tScript
   put "}" & return after tScript
   put "// the fill's html and body as tall as pageHeight, where it is more than" & return after tScript
   put "// innerHeight (100% everywhere else, as before)" & return after tScript
   put "function fillHeight(lh, ph) {" & return after tScript
   put "  var s = document.documentElement.style;" & return after tScript
   put "  if (ph > lh) s.setProperty('--oxt-mobile-web-height', ph + 'px');" & return after tScript
   put "  else s.removeProperty('--oxt-mobile-web-height');" & return after tScript
   put "}" & return after tScript
   put "function viewport() {" & return after tScript
   put "  var vv = window.visualViewport;" & return after tScript
   put "  var lw = document.documentElement.clientWidth || window.innerWidth;" & return after tScript
   put "  var lh = window.innerHeight, ph = pageHeight(lw);" & return after tScript
   put "  var w = vv ? vv.width * vv.scale : lw, h = (vv ? vv.height * vv.scale : lh) + ph - lh;" & return after tScript
   put "  var kb = vv ? Math.max(0, lh - vv.height * vv.scale - vv.offsetTop) : 0;" & return after tScript
   put "  if (kb < 60) kb = 0;" & return after tScript
   put "  var i = insets();" & return after tScript
   put "  return [Math.round(w), Math.round(h), Math.round(kb), i[0], i[1], i[2], i[3], lw > ph ? 'landscape' : 'portrait'].join(',');" & return after tScript
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
   put "// touchStart, touchMove, touchEnd and touchRelease: one finger each, by a" & return after tScript
   put "// number of the library's own; the moves at most once a frame, and a" & return after tScript
   put "// finger's last move before its end" & return after tScript
   put "function fingerStart(e, c) {" & return after tScript
   put "  if (!mw.gestures.touch) return;" & return after tScript
   put "  for (var i = 0; i < e.changedTouches.length; i++) {" & return after tScript
   put "    var u = e.changedTouches[i];" & return after tScript
   put "    if (mw.fingers[u.identifier]) continue;" & return after tScript
   put "    var l = local(c, u.clientX, u.clientY), f = {id: mw.nextFinger++, canvas: c, x: l[0], y: l[1], moved: false};" & return after tScript
   put "    mw.fingers[u.identifier] = f;" & return after tScript
   put "    call('touchstart', f.id, f.x, f.y);" & return after tScript
   put "  }" & return after tScript
   put "}" & return after tScript
   put "function fingerFlush() {" & return after tScript
   put "  if (mw.moveFrame) { cancelAnimationFrame(mw.moveFrame); mw.moveFrame = null; }" & return after tScript
   put "  for (var k in mw.fingers) { var f = mw.fingers[k]; if (f.moved) { f.moved = false; call('touchmove', f.id, f.x, f.y); } }" & return after tScript
   put "}" & return after tScript
   put "function fingerAt(f, u) {" & return after tScript
   put "  var l = local(f.canvas, u.clientX, u.clientY);" & return after tScript
   put "  if (l[0] !== f.x || l[1] !== f.y) { f.x = l[0]; f.y = l[1]; f.moved = true; }" & return after tScript
   put "  return f.moved;" & return after tScript
   put "}" & return after tScript
   put "function fingerMove(e) {" & return after tScript
   put "  var any = false;" & return after tScript
   put "  for (var i = 0; i < e.changedTouches.length; i++) {" & return after tScript
   put "    var f = mw.fingers[e.changedTouches[i].identifier];" & return after tScript
   put "    if (f && fingerAt(f, e.changedTouches[i])) any = true;" & return after tScript
   put "  }" & return after tScript
   put "  if (any && !mw.moveFrame) mw.moveFrame = requestAnimationFrame(function() { mw.moveFrame = null; fingerFlush(); });" & return after tScript
   put "}" & return after tScript
   put "function fingerEnd(e) {" & return after tScript
   put "  var ended = [];" & return after tScript
   put "  for (var i = 0; i < e.changedTouches.length; i++) {" & return after tScript
   put "    var u = e.changedTouches[i], f = mw.fingers[u.identifier];" & return after tScript
   put "    if (!f) continue;" & return after tScript
   put "    fingerAt(f, u); ended.push(f); delete mw.fingers[u.identifier];" & return after tScript
   put "  }" & return after tScript
   put "  if (!ended.length) return;" & return after tScript
   put "  ended.forEach(function(f) { if (f.moved) { f.moved = false; call('touchmove', f.id, f.x, f.y); } });" & return after tScript
   put "  fingerFlush();" & return after tScript
   put "  ended.forEach(function(f) { call(e.type === 'touchcancel' ? 'touchrelease' : 'touchend', f.id, f.x, f.y); });" & return after tScript
   put "}" & return after tScript
   put "function cancelPress() { if (mw.press) { clearTimeout(mw.press.timer); mw.press = null; } }" & return after tScript
   put "function onStart(e) {" & return after tScript
   put "  var c = canvasOf(e); if (!c || !mw.on) return;" & return after tScript
   put "  fingerStart(e, c);" & return after tScript
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
   put "  fingerMove(e);" & return after tScript
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
   put "  fingerEnd(e);" & return after tScript
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
   put "// The sensors: each sends its readings with call('sensor', name, values)" & return after tScript
   put "// until it is stopped, or call('sensorerror', name, why) once" & return after tScript
   put "function round3(v) { return Math.round(v * 1000) / 1000; }" & return after tScript
   put "function seconds() { return (Date.now() / 1000).toFixed(3); }" & return after tScript
   put "function touchy() { return (navigator.maxTouchPoints || 0) > 0 || 'ontouchstart' in window; }" & return after tScript
   put "// A browser opens the camera, the share sheet or the whole screen only" & return after tScript
   put "// from a tap: without one nothing opens and nothing answers. Where the" & return after tScript
   put "// browser can tell (Safari 16.4 and later, Chrome, Firefox), say so." & return after tScript
   put "// (Not for the sensors: a phone that was allowed them once gives them" & return after tScript
   put "// again without a tap.)" & return after tScript
   put "function noTap() { return !!(navigator.userActivation && navigator.userActivation.isActive === false); }" & return after tScript
   put "function sensorAvailable(name) {" & return after tScript
   put "  if (name === 'location') return !!navigator.geolocation;" & return after tScript
   put "  if (name === 'heading') return 'DeviceOrientationEvent' in window && touchy();" & return after tScript
   put "  return 'DeviceMotionEvent' in window && touchy();" & return after tScript
   put "}" & return after tScript
   put "// iPhones and iPads ask the user first, and only from a tap" & return after tScript
   put "function permitted(klass, s, then) {" & return after tScript
   put "  if (klass && typeof klass.requestPermission === 'function') {" & return after tScript
   put "    klass.requestPermission().then(function(r) {" & return after tScript
   put "      if (s.stopped) return;" & return after tScript
   put "      // (Chrome answers 'prompt' where it asks nobody: only a no is a no)" & return after tScript
   put "      if (r !== 'denied') then(); else { s.stopped = true; delete mw.sensors[s.name]; call('sensorerror', s.name, 'permission denied'); }" & return after tScript
   put "    }, function(err) {" & return after tScript
   put "      if (s.stopped) return;" & return after tScript
   put "      s.stopped = true; delete mw.sensors[s.name]; call('sensorerror', s.name, 'permission denied');" & return after tScript
   put "    });" & return after tScript
   put "  } else then();" & return after tScript
   put "}" & return after tScript
   put "function listen(s, type, h) {" & return after tScript
   put "  window.addEventListener(type, h);" & return after tScript
   put "  s.off = function() { window.removeEventListener(type, h); };" & return after tScript
   put "}" & return after tScript
   put "function sensorOn(name, loosely) {" & return after tScript
   put "  if (mw.sensors[name]) return '';" & return after tScript
   put "  if (!sensorAvailable(name)) return 'not available';" & return after tScript
   put "  var s = {name: name, stopped: false, off: null};" & return after tScript
   put "  mw.sensors[name] = s;" & return after tScript
   put "  if (name === 'location') {" & return after tScript
   put "    var w = navigator.geolocation.watchPosition(function(p) {" & return after tScript
   put "      if (s.stopped) return;" & return after tScript
   put "      var c = p.coords, n = function(v) { return v === null || v === undefined || isNaN(v) ? '' : v; };" & return after tScript
   put "      call('sensor', name, [c.latitude, c.longitude, n(c.altitude), n(c.accuracy), n(c.altitudeAccuracy), n(c.speed), n(c.heading), (p.timestamp / 1000).toFixed(3)].join(','));" & return after tScript
   put "    }, function(err) {" & return after tScript
   put "      if (s.stopped) return;" & return after tScript
   put "      s.stopped = true; delete mw.sensors[name]; navigator.geolocation.clearWatch(w);" & return after tScript
   put "      call('sensorerror', name, err.code === 1 ? 'permission denied' : 'location unavailable');" & return after tScript
   put "    }, {enableHighAccuracy: !loosely, maximumAge: loosely ? 60000 : 0});" & return after tScript
   put "    s.off = function() { navigator.geolocation.clearWatch(w); };" & return after tScript
   put "  } else if (name === 'heading') {" & return after tScript
   put "    var abs = 'ondeviceorientationabsolute' in window, last = null, step = loosely ? 5 : 1;" & return after tScript
   put "    permitted(window.DeviceOrientationEvent, s, function() {" & return after tScript
   put "      listen(s, abs ? 'deviceorientationabsolute' : 'deviceorientation', function(e) {" & return after tScript
   put "        var v = null;" & return after tScript
   put "        if (typeof e.webkitCompassHeading === 'number') v = e.webkitCompassHeading;" & return after tScript
   put "        else if ((abs || e.absolute) && typeof e.alpha === 'number') v = (360 - e.alpha) % 360;" & return after tScript
   put "        if (v === null || s.stopped) return;" & return after tScript
   put "        v = Math.round(v * 10) / 10;" & return after tScript
   put "        if (last !== null && Math.abs(((v - last + 540) % 360) - 180) < step) return;" & return after tScript
   put "        last = v;" & return after tScript
   put "        call('sensor', name, [v, typeof e.webkitCompassAccuracy === 'number' ? e.webkitCompassAccuracy : '', seconds()].join(','));" & return after tScript
   put "      });" & return after tScript
   put "    });" & return after tScript
   put "  } else {" & return after tScript
   put "    var gap = loosely ? 200 : 50, then = 0, g = 9.80665, rad = Math.PI / 180;" & return after tScript
   put "    permitted(window.DeviceMotionEvent, s, function() {" & return after tScript
   put "      listen(s, 'devicemotion', function(e) {" & return after tScript
   put "        var now = Date.now(), v;" & return after tScript
   put "        if (s.stopped || now - then < gap) return;" & return after tScript
   put "        if (name === 'acceleration') {" & return after tScript
   put "          var a = e.accelerationIncludingGravity;" & return after tScript
   put "          if (!a || typeof a.x !== 'number') return;" & return after tScript
   put "          v = [round3(a.x / g), round3(a.y / g), round3(a.z / g)];" & return after tScript
   put "        } else {" & return after tScript
   put "          var r = e.rotationRate;" & return after tScript
   put "          if (!r || typeof r.alpha !== 'number') return;" & return after tScript
   put "          v = [round3(r.beta * rad), round3(r.gamma * rad), round3(r.alpha * rad)];" & return after tScript
   put "        }" & return after tScript
   put "        then = now;" & return after tScript
   put "        v.push(seconds());" & return after tScript
   put "        call('sensor', name, v.join(','));" & return after tScript
   put "      });" & return after tScript
   put "    });" & return after tScript
   put "  }" & return after tScript
   put "  return '';" & return after tScript
   put "}" & return after tScript
   put "function sensorOff(name) {" & return after tScript
   put "  var s = mw.sensors[name];" & return after tScript
   put "  if (!s) return;" & return after tScript
   put "  s.stopped = true; delete mw.sensors[name];" & return after tScript
   put "  if (s.off) s.off();" & return after tScript
   put "}" & return after tScript
   put "// The screen kept on, while the page is in front (a phone lets go of it" & return after tScript
   put "// when the page is hidden: it is asked for again when it comes back)" & return after tScript
   put "function wakeAsk() {" & return after tScript
   put "  if (!mw.wantWake || mw.wake || mw.waking || document.visibilityState !== 'visible') return;" & return after tScript
   put "  mw.waking = true;" & return after tScript
   put "  navigator.wakeLock.request('screen').then(function(l) {" & return after tScript
   put "    mw.waking = false;" & return after tScript
   put "    if (!mw.wantWake) { l.release(); return; }" & return after tScript
   put "    mw.wake = l;" & return after tScript
   put "    l.addEventListener('release', function() { if (mw.wake === l) mw.wake = null; });" & return after tScript
   put "  }, function() { mw.waking = false; });" & return after tScript
   put "}" & return after tScript
   put "function keepAwake(on) {" & return after tScript
   put "  if (!('wakeLock' in navigator)) return 'not supported';" & return after tScript
   put "  mw.wantWake = on;" & return after tScript
   put "  if (on) { document.addEventListener('visibilitychange', wakeAsk); wakeAsk(); }" & return after tScript
   put "  else {" & return after tScript
   put "    document.removeEventListener('visibilitychange', wakeAsk);" & return after tScript
   put "    if (mw.wake) { var l = mw.wake; mw.wake = null; l.release().catch(function() {}); }" & return after tScript
   put "  }" & return after tScript
   put "  return '';" & return after tScript
   put "}" & return after tScript
   put "function isFullScreen() { return !!(document.fullscreenElement || document.webkitFullscreenElement); }" & return after tScript
   put "function fullScreen(on) {" & return after tScript
   put "  var el = document.documentElement, ask = el.requestFullscreen || el.webkitRequestFullscreen;" & return after tScript
   put "  var leave = document.exitFullscreen || document.webkitExitFullscreen;" & return after tScript
   put "  if (!ask || document.fullscreenEnabled === false) return 'not supported';" & return after tScript
   put "  if (on && !isFullScreen() && noTap()) return 'not from a tap';" & return after tScript
   put "  try {" & return after tScript
   put "    var p = null;" & return after tScript
   put "    if (on && !isFullScreen()) p = ask.call(el, {navigationUI: 'hide'});" & return after tScript
   put "    else if (!on && isFullScreen()) p = leave.call(document);" & return after tScript
   put "    if (p && p.catch) p.catch(function() {});" & return after tScript
   put "  } catch (err) { return 'not supported'; }" & return after tScript
   put "  return '';" & return after tScript
   put "}" & return after tScript
   put "function share(text, url, title) {" & return after tScript
   put "  if (noTap()) return 'not from a tap';" & return after tScript
   put "  var d = {};" & return after tScript
   put "  if (text) d.text = text;" & return after tScript
   put "  if (url) d.url = url;" & return after tScript
   put "  if (title) d.title = title;" & return after tScript
   put "  if (navigator.share && (!navigator.canShare || navigator.canShare(d))) {" & return after tScript
   put "    try { navigator.share(d).catch(function() {}); return ''; } catch (err) {}" & return after tScript
   put "  }" & return after tScript
   put "  if (navigator.clipboard && navigator.clipboard.writeText) {" & return after tScript
   put "    navigator.clipboard.writeText([text, url].filter(Boolean).join(' ')).catch(function() {});" & return after tScript
   put "    return 'copied';" & return after tScript
   put "  }" & return after tScript
   put "  return 'not supported';" & return after tScript
   put "}" & return after tScript
   put "// A photo from the camera or the phone's pictures, made no bigger than" & return after tScript
   put "// maxW by maxH and sent as JPEG, in base64: call('photo', data), or" & return after tScript
   put "// call('photocancel', why) when none was taken or chosen" & return after tScript
   put "function shrink(file, maxW, maxH, done) {" & return after tScript
   put "  var url = URL.createObjectURL(file), img = new Image();" & return after tScript
   put "  img.onload = function() {" & return after tScript
   put "    var w = img.naturalWidth, h = img.naturalHeight, k = Math.min(1, maxW / w, maxH / h);" & return after tScript
   put "    var cv = document.createElement('canvas');" & return after tScript
   put "    cv.width = Math.max(1, Math.round(w * k)); cv.height = Math.max(1, Math.round(h * k));" & return after tScript
   put "    cv.getContext('2d').drawImage(img, 0, 0, cv.width, cv.height);" & return after tScript
   put "    URL.revokeObjectURL(url);" & return after tScript
   put "    var data = cv.toDataURL('image/jpeg', 0.85);" & return after tScript
   put "    done(data.slice(data.indexOf(',') + 1));" & return after tScript
   put "  };" & return after tScript
   put "  img.onerror = function() { URL.revokeObjectURL(url); done(null, 'not a picture'); };" & return after tScript
   put "  img.src = url;" & return after tScript
   put "}" & return after tScript
   put "function pickPhoto(source, maxW, maxH) {" & return after tScript
   put "  if (mw.photo) mw.photo.finish('photocancel', '');" & return after tScript
   put "  if (noTap()) return 'not from a tap';" & return after tScript
   put "  var input = document.createElement('input'), job = {done: false, chosen: false};" & return after tScript
   put "  input.type = 'file'; input.accept = 'image/*';" & return after tScript
   put "  if (source !== 'library') input.setAttribute('capture', source === 'front camera' ? 'user' : 'environment');" & return after tScript
   put "  input.style.cssText = 'position:fixed;left:0;top:0;width:1px;height:1px;opacity:0;pointer-events:none';" & return after tScript
   put "  // without a cancel event (older browsers), the page coming back with" & return after tScript
   put "  // nothing chosen is a cancel" & return after tScript
   put "  var back = function() {" & return after tScript
   put "    if (document.visibilityState !== 'visible') return;" & return after tScript
   put "    setTimeout(function() { if (!job.chosen) job.finish('photocancel', ''); }, 3000);" & return after tScript
   put "  };" & return after tScript
   put "  job.finish = function(kind, data) {" & return after tScript
   put "    if (job.done) return;" & return after tScript
   put "    job.done = true;" & return after tScript
   put "    window.removeEventListener('focus', back); document.removeEventListener('visibilitychange', back);" & return after tScript
   put "    if (input.parentNode) input.parentNode.removeChild(input);" & return after tScript
   put "    if (mw.photo === job) mw.photo = null;" & return after tScript
   put "    call(kind, data || '');" & return after tScript
   put "  };" & return after tScript
   put "  input.addEventListener('change', function() {" & return after tScript
   put "    job.chosen = true;" & return after tScript
   put "    var f = input.files && input.files[0];" & return after tScript
   put "    if (!f) { job.finish('photocancel', ''); return; }" & return after tScript
   put "    shrink(f, maxW, maxH, function(data, why) { if (data) job.finish('photo', data); else job.finish('photocancel', why); });" & return after tScript
   put "  });" & return after tScript
   put "  input.addEventListener('cancel', function() { job.finish('photocancel', ''); });" & return after tScript
   put "  setTimeout(function() { if (!job.done) { window.addEventListener('focus', back); document.addEventListener('visibilitychange', back); } }, 500);" & return after tScript
   put "  document.body.appendChild(input);" & return after tScript
   put "  mw.photo = job;" & return after tScript
   put "  try { input.click(); } catch (err) { job.finish('photocancel', 'not allowed'); }" & return after tScript
   put "  return '';" & return after tScript
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
   put "    watchInsets(true);" & return after tScript
   put "    viewSoon();" & return after tScript
   put "  }," & return after tScript
   put "  stop: function() {" & return after tScript
   put "    if (!mw.on) return;" & return after tScript
   put "    mw.on = false; cancelPress(); mw.pinch = null; mw.start0 = null;" & return after tScript
   put "    if (mw.moveFrame) { cancelAnimationFrame(mw.moveFrame); mw.moveFrame = null; }" & return after tScript
   put "    mw.fingers = {};" & return after tScript
   put "    touchEvents.forEach(function(x) { document.removeEventListener(x[0], x[1], {capture: true, passive: true}); });" & return after tScript
   put "    viewEvents.forEach(function(x) { window.removeEventListener(x, viewSoon); });" & return after tScript
   put "    if (window.visualViewport) { visualViewport.removeEventListener('resize', viewSoon); visualViewport.removeEventListener('scroll', viewSoon); }" & return after tScript
   put "    watchInsets(false);" & return after tScript
   put "  }," & return after tScript
   put "  viewport: viewport," & return after tScript
   put "  sensorAvailable: function(name) { return sensorAvailable(name) ? 'true' : 'false'; }," & return after tScript
   put "  sensorOn: sensorOn," & return after tScript
   put "  sensorOff: sensorOff," & return after tScript
   put "  sensorsOff: function() { Object.keys(mw.sensors).forEach(sensorOff); }," & return after tScript
   put "  keepAwake: keepAwake," & return after tScript
   put "  fullScreen: fullScreen," & return after tScript
   put "  isFullScreen: function() { return isFullScreen() ? 'true' : 'false'; }," & return after tScript
   put "  share: share," & return after tScript
   put "  pickPhoto: pickPhoto," & return after tScript
   put "  cancelPhoto: function() { if (mw.photo) mw.photo.finish('photocancel', ''); }," & return after tScript
   put "  pageSize: function() {" & return after tScript
   put "    var lw = document.documentElement.clientWidth || window.innerWidth, ph = pageHeight(lw);" & return after tScript
   put "    if (document.getElementById('oxt-mobile-web-fill')) fillHeight(window.innerHeight, ph);" & return after tScript
   put "    return [lw, ph].join(',');" & return after tScript
   put "  }," & return after tScript
   put "  longPressed: function() { return mw.pressed; }," & return after tScript
   put "  fillPage: function(ask, how) {" & return after tScript
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
   put "      css.textContent = 'html,body{margin:0;padding:0;height:var(--oxt-mobile-web-height,100%);overflow:hidden;overscroll-behavior:none}' +" & return after tScript
   put "        '#stack{margin:0!important}';" & return after tScript
   put "      document.head.appendChild(css);" & return after tScript
   put "    }" & return after tScript
   put "    // the html element says how: 'fill' for a stack as big as the page, which" & return after tScript
   put "    // keeps out of the notch itself (the Stack Player's play.html then takes" & return after tScript
   put "    // its own padding off), 'fit' for one the engine scales" & return after tScript
   put "    document.documentElement.setAttribute('data-mobile-web-filled', how === 'fill' ? 'fill' : 'fit');" & return after tScript
   put "    window.scrollTo(0, 0);" & return after tScript
   put "    return 'yes';" & return after tScript
   put "  }," & return after tScript
   put "  unfillPage: function() {" & return after tScript
   put "    var css = document.getElementById('oxt-mobile-web-fill');" & return after tScript
   put "    if (css) css.parentNode.removeChild(css);" & return after tScript
   put "    document.documentElement.removeAttribute('data-mobile-web-filled');" & return after tScript
   put "    document.documentElement.style.removeProperty('--oxt-mobile-web-height');" & return after tScript
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
