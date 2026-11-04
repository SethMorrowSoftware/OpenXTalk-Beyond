# Mobile Web Library

A new script library, `com.livecode.library.mobileweb`, helps a stack
built for HTML5 work in a phone's browser. A stack that uses none of it
works as before; on a desktop every handler does nothing, or answers what
a desktop has, so one stack can run in the IDE and on a phone.

- `mwStart` and `mwStop`: the stack gets `mwSwipe`, `mwPinchStart`,
  `mwPinch`, `mwPinchEnd`, `mwLongPress` and `mwViewportChanged` (the
  phone turned, or the on-screen keyboard came up or went away)
- `mwFillScreen`: the stack fills the browser's window, and fills it again
  when the phone turns; `mwStop` gives the page back its own look. A page
  that shows the stack in a frame of its own, as the Stack Player does,
  says `data-mobile-web-fill="no"` and keeps its layout
- `mwFitStack`: a stack laid out for a big screen is shown as big as fits,
  and taps still reach the controls they are over
- `mwViewport()`: the part of the page that can be seen, the keyboard's
  height, the notch's insets and the orientation
- `mwDragScroll` and `mwDragMoved()`: a field or group scrolls with a
  finger and glides on, and a drag is not taken for a tap
- `mwVibrate`, `mwLongPressed()`, `mwIsWeb()`, `mwIsTouchScreen()` and
  `mwIsInstalled()`

The Phone Starter (in Home's gallery and the Stack Player) is a stack to
copy that uses all of it.
