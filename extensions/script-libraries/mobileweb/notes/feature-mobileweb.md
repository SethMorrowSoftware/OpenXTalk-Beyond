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
- `mwVibrate`, `mwLongPressed()`, `mwIsWeb()`, `mwIsTouchScreen()` and
  `mwIsInstalled()`.

The Phone Starter (in Home's gallery and the Stack Player) is a stack to
copy that uses all of it, in portrait and in landscape.
