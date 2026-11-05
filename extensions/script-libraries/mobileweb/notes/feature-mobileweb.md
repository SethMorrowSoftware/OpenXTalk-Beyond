# Mobile Web Library

A new script library, `com.livecode.library.mobileweb`, helps a stack
built for HTML5 work in a phone's browser. A stack that uses none of it
works as before; on a desktop every handler does nothing, or answers what
a desktop has, so one stack can run in the IDE and on a phone.

One line makes a stack ready for a phone:

```
on openStack
   mwStart
end openStack
```

- A resizable stack then fills the browser's window, and fills it again
  when the phone turns, with a `resizeStack` each time, as on a desktop.
  A stack of a fixed size that is too big for the window, such as one
  made for a desktop, is scaled down to fit, and taps still reach the
  controls under them.
- Gestures come as messages to the control under the finger, as mouse
  messages do, and pass on to its group, card and stack: `swipe
  pDirection`, `pinchStart`, `pinch pScale`, `pinchEnd`, `longPress`.
- The current card gets `orientationChanged`, `keyboardActivated` and
  `keyboardDeactivated`, the names LiveCode's iOS and Android engines
  use.
- `mwViewport()` gives the part of the page that can be seen, the
  keyboard's height, the notch's insets and the orientation.
- `mwDragScroll` and `mwDragMoved()` scroll a field or group with a
  finger, with a glide, and tell a drag from a tap.
- `mwFillScreen` and `mwFitStack` choose the screen by hand, and `mwStop`
  gives the page back its own look. A page that shows the stack in a
  frame of its own, as the Stack Player does, says
  `data-mobile-web-fill="no"` and keeps its layout.
- `touchStart`, `touchMove`, `touchEnd` and `touchRelease` follow each
  finger on its own, for drawing and games with more than one finger,
  to the control the finger touched first, as on iOS and Android.
- `mwStartSensor` and `mwStopSensor` read the phone's sensors, with the
  messages LiveCode's iOS and Android engines send: `locationChanged`,
  `headingChanged`, `accelerationChanged`, `rotationRateChanged`, and
  `trackingError` when the user says no. `mwSensorReading()` gives the
  last reading and `mwSensorAvailable()` says whether there is one.
- `mwPickPhoto` takes a photo with the camera, or picks one of the
  phone's pictures, as a new image on the card, made small enough for
  the stack, and waits for it as LiveCode's `mobilePickPhoto` does
  (`the result` is "cancel" when there is none).
- `mwShare` opens the phone's share sheet (or copies, where there is
  none), `mwKeepAwake` keeps the screen on, and `mwFullScreen` and
  `mwIsFullScreen()` hide and show the browser's bars.
- `mwVibrate`, `mwLongPressed()`, `mwIsWeb()`, `mwIsTouchScreen()` and
  `mwIsInstalled()`.

The camera, the share sheet, the full screen and, on an iPhone, the
motion sensors open only from a tap, so call them in `mouseUp`. The
location and keeping the screen on need a page served over https.

The Phone Starter (in Home's gallery and the Stack Player) is a stack to
copy that uses all of it, in portrait and in landscape: its Phone card
takes a photo, shares, finds where the phone is, rolls a ball as the
phone tilts, keeps the screen on and hides the browser's bars.

With **Search for required inclusions** on, the standalone builder now
finds the library in a stack that calls its handlers and includes it, so
an HTML5 build of such a stack needs nothing ticked by hand. (It could
not find any library extension before: the manifest of a script library
named none of its handlers, the IDE dropped them for a script library,
and the builder wrote the extension it found over. Only the Mobile Web
library's manifest names its handlers, so no other stack's inclusions
change.) The guide *Stacks for Phones* in the Dictionary shows how to
make a stack for phones.

## One stack for every screen

A stack can now lay itself out for a phone, a tablet and a desktop, as a
web page does with its breakpoints, in the IDE as in a browser:

- `mwLayoutClass()` names the layout for a width: "phone" under 600
  pixels, "tablet" to 1023, "desktop" from 1024. `mwSetBreakpoints`
  changes the two widths and `mwBreakpoints()` gives them.
- `mwResponsive` lays the stack out each time its size changes and sends
  the card `layoutChanged pClass, pOrientation` when the layout or the
  orientation changes.
- Rules kept on the controls, in their `mwLayout` custom properties (by
  "phone", "tablet landscape", "all" and so on), say where each goes:
  `left`, `top`, `right`, `bottom`, `width` and `height` in pixels or
  percentages, `hidden`, `within` its group, `bleed` past a phone's notch,
  and `flow N` for a grid of N columns. `mwApplyLayout` follows them now,
  and says which rule it could not read.
- `mwFlow` sets a group's controls out in columns from a script.
- `mwPointer()` says whether the stack is used with a finger, a mouse or
  both, and `mwAppearance()` whether the browser or the computer is dark.

Nothing changes for a stack that does not call `mwResponsive` or
`mwApplyLayout`, nor for a control with no rules. The Responsive Starter
(in Home's gallery and the Stack Player) is a stack to copy that uses
all of it: a tab bar on a phone, a rail on a tablet and a sidebar on a
desktop, a grid of places in one, two or three columns, details in a
sheet or a pane, and a dark look. The guide *Stacks for Every Screen* in
the Dictionary shows how.
