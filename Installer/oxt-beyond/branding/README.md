# OXT-Beyond artwork: 0.2.1 "Frankenstein"

From 0.2.1 the icon, the splash screens and the installer art are the
"Frankenstein" drawings: a friendly flat-top monster with neck bolts, a
stitched scar and lightning, on a charcoal background. The earlier icon,
Tom Perry's OpenXTalk Lite icon with "Lite" replaced by "Beyond", is in
the history of this folder (up to 0.2.1-rc.6); his original stays in
`ide/OpenXTalk-lite_1024.ico`.

## Files

| File | What it is |
| --- | --- |
| `draw_branding.py` | Draws every picture below and writes every file made from them. |
| `svg/icon.svg` | The icon (1024 × 1024): the head, lightning and "OXT" on a rounded tile. |
| `svg/icon-small.svg` | The head alone on the tile, for 64 px and smaller, where lightning and lettering would be a few pixels. |
| `svg/splash-dark.svg`, `svg/splash-light.svg` | The IDE splash screens (1182 × 612), for the dark and light appearance. |
| `svg/wizard.svg` | The tall image of the Windows installer (534 × 1022). |
| `svg/banner.svg` | The release banner (1280 × 640), for the GitHub release, the repository's social preview and forum posts. |
| `png/oxt-beyond-<size>.png` | The icon at 16, 24, 32, 48, 64, 128, 256, 512 and 1024 px. |
| `art/oxt-beyond-wizard.png`, `art/oxt-beyond-banner.png` | The installer image and the banner. They are kept out of `png/`, whose every file packaging puts into the macOS icon. |

Made by `draw_branding.py` elsewhere in the repository:

| File | Used for |
| --- | --- |
| `ide/OXT-Beyond.ico` | 16 to 128 px as 32-bit bitmaps and 256 px as PNG (`tools/oxt/ico.py`); the installer, shortcuts and file associations. |
| `engine/rsrc/oxt-beyond.ico` | The same icon, compiled into the development engine (packaged as `OXT-Beyond.exe`) as icon 111 by `engine/rsrc/development.rc`. Standalone applications keep their own icon (`standalone.rc` is unchanged). |
| `ide/Toolset/resources/community/ideSkin/splash.png`, `splash-light.png` and their `@extra-high` versions | The splash screens at 591 × 306 and 1182 × 612. |

Made from these files elsewhere:

| What | How |
| --- | --- |
| The macOS app icon, `OXT-Beyond.icns` | `tools/oxt/package.py` with `tools/oxt/icns.py`, from `png/`, when a package is staged. |
| The Linux menu icons | `tools/oxt/package.py` copies `png/oxt-beyond-16.png` to `-512.png` into the package. |
| The installer's wizard images | `Installer/oxt-beyond/make-wizard-images.ps1`: the tall image from `art/oxt-beyond-wizard.png`, the small one from the icon. |
| The icon in the About window and in answer and ask dialogs | Images `oxt-l-32.png` and `oxt-l-64.png` in `ide/Toolset/palettes/revgeneralicons.rev`, replaced with `png/oxt-beyond-32.png` and `-64.png` by the image patch `tools/oxt/ide-stack-patches/branding-dialog-icons.txt`. |

The release name, "Frankenstein", is in `ide/.codename`: the About window
shows it under the version, and the Release workflow puts it in the title
of the GitHub release.

## The splash screens

The IDE writes over the splash (`ide/Toolset/palettes/splash/`, at 1x):
the product and version in field "Info" (4,145 to 582,186), a line about
the project in "moreinfo" (5,190 to 255,275) and the loading status in
"Status" (5,270 to 478,293). So the title stays above y 135, the left
half below it is plain, and the bottom 46 px are a darker band for the
status.

## Making the files again

From the repository root, on any system:

```
python3 -m pip install cairosvg
python3 Installer/oxt-beyond/branding/draw_branding.py
```

It needs CairoSVG and the DejaVu Sans font (part of most Linux
distributions). To change a picture, edit the drawing functions in
`draw_branding.py`, or edit an SVG file in a vector editor and run
`draw_branding.py --render-only`, which keeps the SVG files and only
renders them. After changing `png/oxt-beyond-32.png` or `-64.png`, update
the `from-sha1:` lines of `tools/oxt/ide-stack-patches/branding-dialog-icons.txt`
to the old images' digests and run `tools/oxt/ide-stack-patch.sh`.

## Colours

| Role | Colour |
| --- | --- |
| "OXT" orange (kept from the earlier icon) | `#FF7700` |
| Monster green, light to shadow | `#9BD36A` to `#4E7F2E` |
| Glow and stitches | `#B9F56A` |
| Lightning | `#FFE14D`, edge `#7A5A00` |
| Charcoal background | `#15171A` to `#2B2F36` |
