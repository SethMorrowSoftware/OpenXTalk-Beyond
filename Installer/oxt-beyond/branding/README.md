# OXT-Beyond icon and splash artwork

The OXT-Beyond icon is **Tom Perry's OpenXTalk Lite icon** with the word
"Lite" replaced by "Beyond". Tom Perry (tperry2x) made the icon and the IDE
splash screens for OpenXTalk Lite, which he built and maintained from version
0.91 to 1.15; OXT-Beyond continues from OpenXTalk Lite 1.15 and adapts his
artwork with credit to him.

## Files

| File | What it is |
| --- | --- |
| `source/oxt-lite-icon-512.png` | Tom Perry's original: the largest image (512 × 512 px) in `ide/OpenXTalk-lite_1024.ico`, unchanged. |
| `png/oxt-beyond-<size>.png` | The OXT-Beyond icon at 16, 24, 32, 48, 64, 128, 256, 512 and 1024 px. The source is 512 px, so the 1024 px image is the source enlarged, with the "Beyond" lettering drawn at full resolution. |
| `make-branding.ps1` | Makes everything listed here from the source icon. |

Made by `make-branding.ps1` elsewhere in the repository:

| File | Used for |
| --- | --- |
| `ide/OXT-Beyond.ico` | 16, 24, 32, 48, 64 and 128 px as 32-bit bitmaps and 256 px as PNG; for the installer, shortcuts and file associations. |
| `engine/rsrc/oxt-beyond.ico` | The same icon, compiled into the development engine (packaged as `OXT-Beyond.exe`) as icon 111 by `engine/rsrc/development.rc`. Standalone applications keep their own icon (`standalone.rc` is unchanged). |
| `ide/Toolset/resources/community/ideSkin/splash.png`, `splash-light.png` and their `@extra-high` versions | Tom Perry's splash screens with the new icon. |

## How the icon is made

1. The pixels of the yellow "Lite" letters and their dark outline are
   removed. Inside the circle, the background behind them is filled in by
   continuing the circle's own shading around the circle (the shading is
   concentric); outside the circle they become transparent.
2. "Beyond" is drawn in Arial Black, in the orange of the "OXT" letters
   (`#FF7700`) with a black outline 9 px wide at 512 px, in the band that
   "Lite" used.
3. The lower parts of the "OXT" letters are drawn again in front, with the
   same drop shadow they cast on "Lite" (9 px down, 49 % brightness).
4. The smaller sizes are scaled down from the 512 px image.

For the splash screens, the script finds the old icon in each image, removes
it together with its drop shadow (offset and darkness measured from the
image), and draws the new icon there with a matching shadow.

## Making the files again

On Windows, from the repository root:

```
powershell -ExecutionPolicy Bypass -File Installer\oxt-beyond\branding\make-branding.ps1 -Splash
```

It needs Windows PowerShell 5.1 or PowerShell 7 on Windows (System.Drawing),
the Arial Black font that comes with Windows, and, for `-Splash`, git: the
original splash images are read from commit `523b3b208` (the OpenXTalk Lite
1.15 IDE), so the step can be repeated. `-FillColor '#FFE400'` draws the
lettering in the yellow that "Lite" used; `-Preview <file>` also writes a
256 px preview.

## Artwork still to replace

Some copies of the OpenXTalk Lite icon are images inside binary stacks, which
are not changed in this phase:

- `ide/Toolset/palettes/revgeneralicons.rev`: image 210111 `oxt-l-32.png` and
  image 210112 `oxt-l-64.png` (the icon in answer dialogs and the About
  window). `png/oxt-beyond-32.png` and `png/oxt-beyond-64.png` are the
  replacements. Image 210096 `lc-64.png` in the same stack is the LiveCode
  logo.
