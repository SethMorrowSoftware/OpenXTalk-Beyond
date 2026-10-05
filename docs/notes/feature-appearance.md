# Light by default, dark mode by choice: appAppearance and stackAppearance

The engine no longer follows the dark mode of Windows and macOS on its own.
It draws in the light appearance unless a script chooses otherwise, with two
new properties:

- **`the appAppearance`** (global): `"light"` (the default), `"dark"` or
  `"system"` (follow the operating system). `the effective appAppearance` is
  `"light"` or `"dark"`, with `"system"` resolved.
- **`the stackAppearance of <stack>`**: empty (the default: a substack uses
  its mainstack's, a mainstack the appAppearance), `"light"`, `"dark"` or
  `"system"`. `the effective stackAppearance of <stack>` is `"light"` or
  `"dark"`.

`the systemAppearance` still reports the operating system's setting, and
`systemAppearanceChanged` is still sent (only) when that setting changes.
Setting either property redraws every window at once and sends no message.
On macOS the systemAppearance is read again each time, so it is the Mac's
setting even while the appAppearance forces light or dark, and the message
is sent once for each change of the Mac's setting.

The names are compound on purpose: a new property name takes precedence over
a variable or custom property of the same name in every script, so a plain
word such as "appearance" would have broken scripts that use it as a
variable.

## Why light is the default

In dark mode, every color a stack leaves unset came from the dark theme:
white text and dark fills. Colors the author did set were drawn as set. A
field with a white background and no text color therefore showed white text
on white, and a checkbox on a light card a white label on the card. Every
stack that exists was designed on a light system, and Windows and macOS both
leave it to each application whether it follows dark mode.

## Standalones

Standalones are light unless they opt in. To follow the system, add one line
to the startup or preOpenStack handler of the mainstack:

    set the appAppearance to "system"

Standalones built with OpenXTalk Lite 1.14 or later, or with OXT-Beyond 0.1.0
or earlier, followed the dark mode of Windows (and of macOS). Built again
with this version, they are light unless they add that line.

Scripts that must also run on older engines can test for the property:

    try
       do "get the appAppearance"
       put true into tHasAppearance
    catch tError
       put false into tHasAppearance
    end try

## Stacks designed light, in the dark appearance

Where a stack is drawn dark, the engine fits each object's unset colors and
native parts to the explicit colors the author set around it: the object's
own fill, its own text color on a default fill, and the panel, image, group
or card it sits on (a panel counts when it is under at least half of the
object, so a checkbox that overhangs its panel still fits it). A
light-designed stack keeps its light look (black text
in its white fields, black checkbox labels, light native buttons and
scrollbars), and a stack that sets no colors is drawn dark. When the engine
cannot tell, it uses light. In the light appearance nothing is fitted: every
object is drawn exactly as before.

Printing is always light. Snapshots are taken in the appearance the objects
are shown in; set the appAppearance (or the stackAppearance) to "light"
around an export to get a light image of a dark stack.

## The IDE

The IDE has two preferences: the appearance of its own windows (light by
default, dark, or following the system), set as the stackAppearance of its
stacks, and the appearance of your stacks (light by default, like a
standalone), set as the appAppearance. With the IDE dark, your stacks still
look as they will in your standalone.

## Known limits

- A transparent label or checkbox with an explicit dark text color, on a
  card with no color, stays dark text on the dark card: the author's color
  is honored, and the card gives nothing to fit to. Give the card a color,
  or set the stackAppearance to "light".
- On Linux the native controls are drawn by the GTK theme, which the engine
  cannot change: every stack follows the GTK theme, and the two properties
  are stored and returned but change nothing. A light-designed stack under a
  dark GTK theme still shows the old problem.
- On macOS the dark appearance needs macOS 10.14 or later. The classic
  native controls (HITheme) only draw Aqua, so the engine draws those of a
  dark stack itself in macOS's dark colours (MCMacDrawThemeDark in
  engine/src/osxtheme.mm): push buttons, checkboxes, radio buttons, option
  menus, combo boxes, little arrows, tabs, field and group frames,
  scrollbars, sliders and progress bars. They follow the shapes of current
  macOS controls, not their exact pixels.
- The stackAppearance is not saved with the stack in this version.
