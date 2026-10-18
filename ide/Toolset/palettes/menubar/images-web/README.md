# The web IDE's toolbar icons

The web IDE's toolbar shows these icons in place of `../images`
(revMenubar's `revMenubarButtonNameToIconPath`). The desktop IDE does not
use them.

Each icon is a [Lucide](https://lucide.dev) icon (lucide-static 0.469.0,
ISC licence, below), drawn 20 pixels square in the middle of a 28-pixel
image, with a stroke 1.85 pixels wide. Each `@extra-high` file is the
same at twice the size.

| Button | File name | Lucide icon |
| --- | --- | --- |
| Inspector | `inspector` | `sliders-horizontal` |
| Script | `code` | `code-xml` |
| Tools | `tools` | `pencil-ruler` |
| Message Box | `message-box` | `square-terminal` |
| Group (hilited: Ungroup) | `group` | `group` (hilited: `ungroup`) |
| Edit Group | `edit-group` | `square-pen` |
| Select Grouped | `select-grouped` | `square-mouse-pointer` |
| Messages (hilited: suppressed) | `messages` | `message-square` (hilited: `message-square-off`) |
| Errors | `errors` | `triangle-alert` |
| Sample Stacks | `sample-stacks` | `layers` |
| Tutorials | `tutorials` | `graduation-cap` |
| Resources | `resources` | `lightbulb` |
| Dictionary | `dictionary` | `book-a` |
| Test | `test` | `play` |

The states revMenubar asks for, by the end of the file name:

| State | Stroke | Behind the icon |
| --- | --- | --- |
| (none) | `#3b4554` | nothing |
| `-disabled` | `#3b4554`, 32% opaque | nothing |
| `-depressed` | `#17202a` | a square with corners of 7 pixels, `#dde2e8` |
| `-hilited` (a toggle that is on) | `#c45f00` | the same square, `#ffe8cf` |
| `-hilited-depressed` | `#9a4a00` | the same square, `#ffd7a8` |

Group's hilited states are Ungroup, an action rather than a toggle, so
they look like the plain and depressed states.

`divide.png` is the line between groups of buttons: 2 by 41 pixels (the
size layoutMenu gives it), with a line 1 pixel wide, `#d3d9e0`, from 8
pixels below the top to 8 pixels above the bottom.

## Lucide's licence

ISC License

Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as
part of Feather (MIT). All other copyright (c) for Lucide are held by
Lucide Contributors 2022.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
