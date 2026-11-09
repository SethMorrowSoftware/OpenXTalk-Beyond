# OXT-Beyond artwork: 0.2.7 "Make It So"

From 0.2.1 the icon is an orange "OXT" struck by lightning over a
stitched seam and "BEYOND", on a charcoal tile with an orange rim. In
0.2.7 it is redrawn as SVG for SVG Lab
(`tools/pages/games/svg-lab/beyond-logo.svg`, written by `genlogo.py`
there): the words as paths, so it needs no font, a flame gradient on
"OXT", a gold bolt, light rays and a glow on the tile, electric arcs and
sparks. That file is the one source of the icon: `draw_branding.py`
makes every icon, the logo on the splash screens, the installer and the
banner, and the web pages' logo from it, so to change the logo, change
`genlogo.py` and run both. In 0.2.7 "Make It So" the installer art and
the release banner are a star-streak "jump" on a night-blue sky, as in
the 0.2.7 promo stills: the logo at the streaks' vanishing point,
"OXT-Beyond" in orange and "MAKE IT SO" in gold with a drawn sparkle
(no Star Trek logos or art; the name is a wink). Its release candidates,
frozen for play testing, had the "Bug Hunt" drawings there (and on the
splash screens until rc.6.13): a friendly teal beetle caught under an
orange-handled magnifying glass, over a trail of footprints, on a
charcoal background; they are in the history of `draw_branding.py`.
0.2.1 to 0.2.6 had the "Frankenstein" drawings (a friendly flat-top
monster with neck bolts, a stitched scar and lightning), which are in the
history of this folder. The earlier icon,
Tom Perry's OpenXTalk Lite icon with "Lite" replaced by "Beyond", is in
the history of this folder (up to 0.2.1-rc.6); his original stays in
`ide/OpenXTalk-lite_1024.ico`.

## Files

| File | What it is |
| --- | --- |
| `draw_branding.py` | Draws every picture below and writes every file made from them. |
| `svg/icon.svg` | The icon (1024 × 1024): SVG Lab's logo as it is. |
| `svg/icon-small.svg` | "OXT" and the lightning alone, larger, for 16 to 48 px, where the seam, "BEYOND", the arcs and the sparks would be a pixel or two. |
| `svg/icon-animated.svg` | The logo, moving, in the file itself (SMIL), so it plays wherever an SVG image does: the rays turn, the glow breathes, the arcs crackle, the sparks twinkle and a shine sweeps across "OXT". |
| `svg/splash-dark.svg`, `svg/splash-light.svg` | The IDE splash screens (1182 × 612), for the dark and light appearance: the logo, "OXT-Beyond", the release's name and the loading bar's track. |
| `svg/wizard.svg` | The tall image of the Windows installer (534 × 1022). |
| `svg/banner.svg` | The release banner (1280 × 640), for the GitHub release, the repository's social preview and forum posts. |
| `png/oxt-beyond-<size>.png` | The icon at 16, 24, 32, 48, 64, 128, 256, 512 and 1024 px. |
| `art/oxt-beyond-wizard.png`, `art/oxt-beyond-banner.png` | The installer image and the banner. They are kept out of `png/`, whose every file packaging puts into the macOS icon. |

Made by `draw_branding.py` elsewhere in the repository:

| File | Used for |
| --- | --- |
| `ide/OXT-Beyond.ico` | 16 to 128 px as 32-bit bitmaps and 256 px as PNG (`tools/oxt/ico.py`); the installer, shortcuts and file associations. Only the Windows package has it (`WINDOWS_ONLY_IDE_FILES` in `tools/oxt/package.py`). |
| `engine/rsrc/oxt-beyond.ico` | The same icon, compiled into the development engine (packaged as `OXT-Beyond.exe`) as icon 111 by `engine/rsrc/development.rc`. Standalone applications keep their own icon (`standalone.rc` is unchanged). |
| `ide/Toolset/resources/community/ideSkin/splash.png`, `splash-light.png` and their `@extra-high` versions | The splash screens at 591 × 306 and 1182 × 612. |
| `tools/pages/brand/` | The web pages' logo, which `tools/pages/build_pages.py` puts beside the front page: `logo-animated.svg` in the front page's header (`logo.svg`, the still one, for a reader who asks for less motion), `icon.svg` (the small icon) as its favicon and by the site's name, and `social.png` (the banner) for link previews. |
| `tools/web-player/assets/oxt-beyond-128.png` | The Stack Player's icon. |
| The `<link rel="icon">` of `tools/web-ide/index.html` | The web IDE's favicon, the small icon in the page itself. |

Made from these files elsewhere:

| What | How |
| --- | --- |
| The macOS app icon, `OXT-Beyond.icns` | `tools/oxt/package.py` with `tools/oxt/icns.py`, from `png/`, when a package is staged. |
| The Linux menu icons | `tools/oxt/package.py` copies `png/oxt-beyond-16.png` to `-512.png` into the package. |
| The installer's wizard images | `Installer/oxt-beyond/make-wizard-images.ps1`: the tall image from `art/oxt-beyond-wizard.png`, the small one from the icon. |
| The icon in the About window and in answer and ask dialogs | Images `oxt-l-32.png` and `oxt-l-64.png` in `ide/Toolset/palettes/revgeneralicons.rev`, replaced with `png/oxt-beyond-32.png` and `-64.png` by the image patch `tools/oxt/ide-stack-patches/branding-dialog-icons.txt`. |

The release name, "Make It So" ("Bug Hunt" for 0.2.7's release
candidates), is in `ide/.codename`: the About window
shows it under the version, and the Release workflow puts it in the title
of the GitHub release.

## The splash screens

From 0.2.7-rc.6.14 the splash looks like the web IDE's loading screen
(`tools/web-ide/index.html`): one centred card on the web IDE's slate
desktop (a light one for the light appearance) with the logo, "OXT-Beyond"
with "OXT" in orange, the release's name (`ide/.codename`) in a small pill
and the track of a loading bar. Until rc.6.13 the art was the "Bug Hunt"
beetle beside the logo, with the words at the left.

The IDE writes the rest over the art, centred
(`ide/Toolset/palettes/splash/revsplashstackbehavior.livecodescript`, at
1x): "<version> · Thank you, bug hunters!" in grey 13 px text
("Happy hunting!" in 0.2.7's release candidates) (field "moreinfo",
0,199 to 591,225), the loading bar's orange fill over the track (graphic
"progress", 196,242 to 395,245, which the splash makes when it opens and
moves on by one step for each status the IDE shows) and the loading
status (field "Status", 0,252 to 591,276). The stack's own field "Info"
(product and version) is hidden. Those places are `SPLASH_*` in
`draw_branding.py`, and `tools/ci/tests/test_branding.py` holds the
script and the art to them.

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
renders them. The icon was last drawn for 0.2.7 (the SVG logo), with
CairoSVG 2.9.1: another CairoSVG renders it a few pixels differently, so
when only the splash, installer or banner art changes, keep the icon
files (`png/`, both `.ico` files, `svg/icon*.svg`, `tools/pages/brand/`
bar `social.png`, the Stack Player's icon and the web IDE's favicon) as
they were (`git checkout` them after the run). After changing
`png/oxt-beyond-32.png` or `-64.png`, update the `from-sha1:` lines of
`tools/oxt/ide-stack-patches/branding-dialog-icons.txt` to the old
images' digests and run `tools/oxt/ide-stack-patch.sh` with a Linux
development engine (a release's `linux-x86_64-binaries` has one).
`tools/ci/tests/test_branding.py` holds the drawings to the logo and the
web pages' copies to the drawings.

## Colours

| Role | Colour |
| --- | --- |
| "OXT" orange (kept from the earlier icon); in the SVG logo a flame gradient | `#FF7700`; `#FFC04D` to `#FF6A00` |
| The logo's rim | `#FFC24D` to `#FF7700` to `#FF3D00` |
| Night sky, at the vanishing point to the edges ("Make It So") | `#22314F` to `#0D1322` |
| Star streaks and stars | `#CFE0FF`, 12 to 62 % |
| The release's name and its sparkle | `#FFB547` (`#A0560A` on the light splash's pill) |
| Lightning (the icon) | `#FFF9C4` to `#FFC92E` (plain `#FFE14D`), edge `#7A5A00`; arcs `#BFEFFF`, sparks `#FFF4B0` |
| Charcoal background | `#15171A` to `#2B2F36` |
