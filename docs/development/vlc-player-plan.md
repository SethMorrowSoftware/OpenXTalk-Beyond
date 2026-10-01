# libVLC player backend: exploration and plan

Status: **phase 1 in progress: first Windows backend (`engine/src/vlc-player.cpp`) written, awaiting a test build**  
Goal: make the `player` object as functional as possible on Windows and Linux  
Scope: Windows and Linux; macOS only where it comes cheaply  
Branch: `vlc-player` (from `main` at OXT-Beyond 0.2.0)

"As functional as possible" means every property and message in the table in
section 2 works on Windows and Linux the way it does on macOS today, plus the
broader format and stream support libVLC brings. libVLC is therefore the default
backend on both platforms; DirectShow remains only as the Windows fallback when
libVLC cannot be loaded.

## 1. Recommendation

Add libVLC as a new backend *behind the existing `player` object*, not as a new
widget or external:

* Implement one `MCPlatformPlayer` subclass on top of libVLC 3.x (currently
  3.0.24; 4.0 is still in beta).
* Load libVLC at run time (`LoadLibrary` / `dlopen`), so the engine has no
  link-time dependency and can fall back when libVLC is absent.
* Render through `libvlc_video_set_callbacks` into a frame buffer that the
  engine draws, rather than giving libVLC a native window. The engine already
  has this path (`MCPlayer::draw` → `MCPlatformLockPlayerBitmap`); the macOS
  AVFoundation backend uses it and the Windows backend never implemented it.
* Move Linux from the legacy mplayer player onto the platform player so the same
  backend serves both targets.

Scripts keep using `player` exactly as today, the engine-drawn controller comes
for free, and video starts working in the places the native-window design cannot
reach: `alwaysBuffer`, snapshots, printing, visual effects, edit mode, layered or
shaped stacks, and objects drawn over the video.

## 2. How the player works today

The script-facing class is chosen at compile time (`engine/src/sysdefs.h:33-69`,
`engine/src/player.h:23-27`):

| | Windows | macOS | Linux |
|---|---|---|---|
| Front end | `player-platform.cpp` | `player-platform.cpp` | `player-legacy.cpp` |
| Backend | DirectShow + VMR9 (`w32-ds-player.cpp`) | AVFoundation (`mac-av-player.mm`) | `/usr/bin/mplayer -slave -wid` (`lnxmplayer.cpp`) |
| Video surface | Native child HWND in an `MCNativeLayer` | Native view, or offscreen frames | Bare GDK child window, no native layer |
| Offscreen / `alwaysBuffer` | Stubbed: shows **no video** | Works | No-op |
| Controller | Engine-drawn | Engine-drawn | **None** |
| `callbacks`, `currentTimeChanged` | Work (100 ms timer) | Work | Never fire |
| `currentTime`, `duration` | Work (timescale 10^7) | Work | Byte offsets; set is a no-op |
| start/end time, `playSelection` | Work | Work | No-op |
| Tracks, balance, pan | Empty or unimplemented | Work | Unsupported |

The backend interface is `MCPlatformPlayer` (`engine/src/platform-internal.h:238-274`):
`GetNativeView`, `SetNativeParentView`, `IsPlaying`, `Start(rate)`, `Stop`, `Step`,
`LockBitmap` / `UnlockBitmap`, `Set/GetProperty` (enum `MCPlatformPlayerProperty`,
`engine/src/platform.h:984-1022`), and the four track methods. Backends report
back through `MCPlatformCallbackSendPlayer{FrameChanged,MarkerChanged,
CurrentTimeChanged,Finished,BufferUpdated}`, which must run on the main thread
(`engine/src/platform.cpp:404-454`, routed in `engine/src/desktop.cpp:1405-1477`).
The backend is created in `MCPlatformCreatePlayer` (`engine/src/platform-player.cpp:186-220`).

The OpenXTalk Lite 1.15 "Linux video reworked to use GStreamer" change is not in
this repository (its commit carries IDE files only).

## 3. Options considered

**A. libVLC backend behind `player` (recommended).** One C++ class shared by all
platforms; existing stacks and the controller keep working; offscreen rendering
fixes long-standing gaps. Costs engine work, including the Linux migration
(section 5).

**B. LCB widget plus a native C shim.** No engine changes, and the native layer
works on Windows (HWND) and Linux (X11 XID, via `GtkSocket`) as the browser
widget shows. But it is a new API rather than `player`; it needs its own
controller; a native-window video surface inherits every limitation of today's
Windows player; and shipping is blocked today. The standalone builder copies
only the top level of `code/<platform>/` (`ide-support/revsblibrary.livecodescript:2596-2724`),
so libVLC's `plugins/` folder would not travel, and `tools/oxt/xtalk_extensions.py`
cannot describe subfolders or `resources/`. Drawing frames from LCB instead would
copy about 8 MB per 1080p frame through LCB `Data`, which is unlikely to keep up.

**C. Classic external.** Same native-window drawbacks as B with an older API
and no advantage over A.

## 4. Proposed backend design

New file `engine/src/vlc-player.cpp`, class `MCLibVLCPlayer : public MCPlatformPlayer`.

**Loading.** On first use, resolve about 30 libVLC symbols into a function table.
Windows search order: bundled `Externals/VLC/libvlc.dll`, then the installed VLC
(registry `HKLM\Software\VideoLAN\VLC\InstallDir`). Linux: `libvlc.so.5`. If
loading fails, `MCPlatformCreatePlayer` falls back: DirectShow on Windows; a
player whose `status` reports the missing dependency on Linux. Pass
`--no-xlib` on Linux, because the engine never calls `XInitThreads`.

**Rendering.** Use `libvlc_video_set_format_callbacks` to pick the chroma and
size, then `libvlc_video_set_callbacks` for lock, unlock and display. Keep two
buffers under a mutex. `display` marks a frame ready and posts one coalesced
notification to the main thread, which raises FrameChanged. `LockBitmap` returns
the latest frame; the engine scales it (`player-platform.cpp:2398-2400`).

* **Size.** The size offered to the format callback is the decoder's aligned
  buffer (1040×610 for a 1028×582 video), and keeping it makes libVLC stretch the
  picture. Request the track's stored width and height from the parse instead,
  and do *not* fold the sample aspect ratio in: any size other than the stored
  one makes libVLC rescale every frame (1080p cost 78% of a core with rescaling,
  23% without). Apply the aspect ratio in `MCPlayer::draw`, which scales anyway.
* **Pixels.** Engine pixel order is BGRA on Windows and RGBA on Linux and macOS
  (`libgraphics/include/graphics.h:52-58`). Request `RV32` (BGRA, fourth byte
  already 0xFF) on every platform. On Linux, swap red and blue during the
  decode-to-front copy that happens anyway. libVLC's own `RGBA` conversion has no
  fast path. Measured in WSL:

  | | `RGBA` from libVLC | `RV32` + swap |
  |---|---|---|
  | 1080p | 64% of a core | 26% |
  | 4K | 160% of a core, only 15 fps | 93%, full frame rate |
* **Startup.** The format callback runs up to three times per start, as libVLC
  tries D3D11 and DXVA2 surfaces before falling back to software decoding;
  `--avcodec-hw=none` did not prevent it. On Linux the equivalents are VA-API
  and VDPAU surfaces. The first frame still arrives about 170-200 ms after
  `play` on both platforms, and the backend must reallocate safely on each call.
* **Pause.** While paused, libVLC calls `display` again about every 80 ms with the
  same picture. Raise FrameChanged then only after a seek or step.

Report `Offscreen` as always true and `GetNativeView` as false;
`SetNativeParentView` must still return true (`player-platform.cpp:1502-1505`).

**Threading.** libVLC events and video callbacks arrive on libVLC threads.
Marshal everything to the main thread (`MCNotifyPush`, `engine/src/notify.h:28`).
Never call back into the libVLC player from inside a libVLC event callback.
Some events are raised synchronously on the *calling* thread: `stop` delivers
`Stopped` on the main thread before it returns. The event handler must therefore
never take a lock that the main thread holds while calling libVLC.

**Property mapping (libVLC 3.x).**

| Engine property | libVLC |
|---|---|
| Filename / URL | `libvlc_media_new_path` / `libvlc_media_new_location`, then async parse for duration |
| Timescale | report 1000 (milliseconds; also avoids the 32-bit save limit, section 8) |
| CurrentTime, Duration | `get_time` / `set_time`, `get_length`; while paused, report the time last set or stepped to, because `get_time` lags by up to 400 ms |
| PlayRate | `set_rate` (2.0 measured exact at HD; 4K could not keep up) |
| Volume | `audio_set_volume`, but cache the value and re-apply it on every `Playing` event: reads lag writes, and the system mixer restores the last level between runs on both Windows and PulseAudio (section 8) |
| Start(rate), Stop | `set_rate` + `play`, `set_pause(1)` |
| Step | `set_time(current ± n / frame rate)` while paused; `next_frame` is imprecise on Windows (first step jumped about 400 ms), never updates the reported time on Linux, and is forward only |
| Start/FinishTime, OnlyPlaySelection | enforced by the backend's timer |
| Loop | media option `:input-repeat=65535`: near-seamless (77 ms gap at HD, 155 ms at 4K, against 33 ms per frame), no `EndReached`, no restart. If looping is switched off mid-play, stop at the next wrap |
| Finished | `MediaPlayerEndReached` when not looping; libVLC 3 then needs `stop` before `play` |
| Markers, CurrentTimeChanged | timer, as the DirectShow backend does |
| Mirrored | flip while copying the frame |
| MediaTypes, tracks, natural size | `libvlc_media_tracks_get` after a local parse (about 40-200 ms), `video_set_track` / `audio_set_track` |
| Balance, pan | `libvlc_audio_set_channel` gives left, right and stereo only; true balance needs more work |

## 5. Linux: moving to the platform player

1. Define `FEATURE_PLATFORM_PLAYER` for `_LINUX_DESKTOP` and drop `FEATURE_MPLAYER`
   (`engine/src/sysdefs.h:63-69`).
2. In `engine/engine-sources.gypi`, stop excluding `player-platform.cpp` on Linux
   (around line 1233) and exclude `player-legacy.cpp` and `lnxmplayer.*`.
3. Add a Linux branch to `MCPlatformCreatePlayer`.
4. Supply the `MCPlatformCallbackSendPlayer*` and `MCPlatformHandlePlayer*`
   functions, which live in `platform.cpp` and `desktop.cpp` (both excluded on Linux).
5. Supply `MCPlatformBreakWait` / `MCPlatformWaitForEvent`, modelled on
   `engine/src/w32-core-compat.cpp:26-35`.
6. Remove or guard the mplayer `SIGCHLD` handling in `engine/src/dsklnx.cpp:488-531`.

The existing `FEATURE_PLATFORM_PLAYER` hooks then switch on for Linux, and Linux
gains the controller, `callbacks`, `currentTimeChanged`, `status` and `mirrored`.
Mplayer is lost as a fallback, so Linux without libVLC has no video.

## 6. Shipping libVLC

**Windows.** Ship `libvlc.dll`, `libvlccore.dll` and a pruned `plugins/` in
`Externals/VLC/`, pinned as an external asset (`tools/oxt/external-assets.json`)
from the official `vlc-<ver>-win64.7z`, with `exclude` patterns for the GUI, Lua and
other unused plugins. A full VLC 3 install has 364 plugin DLLs (about 130 MB); the
pruned size still has to be measured. Standalones need a copy step modelled on
`revCopyCEFResources` (`ide-support/revsaveasstandalone.livecodescript:2329-2429`).

**Linux.** Use the system libVLC: Debian and Ubuntu `libvlc5` plus
`vlc-plugin-base`; Fedora and RHEL only through RPM Fusion. Add an optional
"media" use class to `Installer/linux/libraries.txt`, the launcher and
`tools/ci/check_linux_libraries.py`, following the precedent of the optional CEF
"browser" class (`Installer/linux/oxt-beyond:22-33`). Because the engine loads it
with `dlopen`, `tools/ci/check_native_deps.py` is unaffected. Bundling libVLC on
Linux is deferred.

**macOS.** Keep AVFoundation as the default. The backend compiles unchanged;
enabling it would mean bundling VLC.app's `lib/` and `plugins/` as universal
binaries. The fork already ad-hoc signs every Mach-O and does not notarize, so
this is moderate work, not a blocker.

**Licences.** libVLC is LGPL-2.1+, which is compatible with the GPLv3 engine.
Each shipped component needs a `THIRD-PARTY-NOTICES.md` row and its licence text;
LGPL also needs the source or a written offer; and the plugins carry their own
licences (mostly LGPL or GPLv2+), which need auditing. Redistributing codec
binaries can also raise patent questions in some countries. Not legal advice.

## 7. Phased plan

0. **Feasibility probe (outside the engine).** `tools/vlc-spike/vlcspike.c`
   loads libVLC at run time, renders into memory, and exercises every operation
   above. Build with `build-win.cmd` or `run-linux.sh`.
   * **Windows: done**, against the installed VLC 3.0.18 on the repo's
     `ide/Resources/Examples/neville-segments.mp4` and 1080p and 4K versions of it.
     The registry lookup and plugin discovery work with no extra setup.
     Everything in section 4 works, with the quirks noted there. CPU for
     memory rendering with software decoding, as a share of one core:
     | Video | CPU |
     |---|---|
     | 1028×582 | 16% |
     | 1080p | 23% |
     | 4K | 60% |
     | Audio-only MP3 | 2% |

     These clips are mostly static, so real footage will cost more.
   * **Linux: works under WSL** (Ubuntu 24.04, distro libVLC 3.0.20 with
     `libvlc5` and `vlc-plugin-base`). `dlopen("libvlc.so.5")` finds the plugins
     with no setup, and it fails cleanly when libVLC is missing. Behaviour
     matches Windows apart from the `RGBA` cost and `next_frame` noted in
     section 4. WSL timings are indicative only.
   * **Next: real Linux.** Repeat on Kubuntu 24.04, where the engine and IDE
     already run: `sudo apt install libvlc5 vlc-plugin-base`, then
     `tools/vlc-spike/run-linux.sh <clips>`, and the `--chroma RV32 --swizzle`
     comparison.
   * Still to measure: the pruned `plugins/` set and its size.
1. **Windows backend.** `MCLibVLCPlayer` behind `player`, falling back to
   DirectShow. Developer testing against the installed VLC.
   * First version: `engine/src/vlc-player.cpp`, chosen in
     `MCPlatformCreatePlayer` (`engine/src/platform-player.cpp`).
   * libVLC is looked for in these places, in order:
     1. `%OXT_LIBVLC_DIR%`
     2. `Externals\VLC` next to the executable
     3. the installed 64-bit VLC (registry `InstallDir`)

     Only 3.x is accepted. Setting `OXT_PLAYER_BACKEND=directshow` forces the
     old player for comparison.
   * Two more libVLC 3 behaviours, found with the probe's `--prime` mode, shape
     the code:
     * `:start-paused` stops before the first picture, and one `next_frame`
       then shows it.
     * A seek while paused shows nothing, even after `next_frame`. Playing
       muted until one picture arrives, then pausing, shows the new frame
       within 10-25 ms and stays exactly on the target time.
   * Not yet done:
     * true balance and pan
     * a "loaded time" for streams
     * seamless looping when looping is switched on after loading (it then
       restarts on `EndReached`)
2. **Linux.** Section 5, then the same backend.
3. **Packaging and CI.** External asset, standalone copy step, Linux launcher
   class, notices, and a smoke test that plays a short clip, checks that
   `currentTime` advances, and checks that a snapshot is not black.
4. **macOS (optional).** Only if it stays cheap.

## 8. Open questions

* Is "no video without libVLC" acceptable on Linux, given that mplayer goes away?
* What size budget does the Windows package have for the libVLC runtime?
* **Per-player volume.** Each run started at the volume the previous run left,
  on Windows (per-application session volume) and in WSL (PulseAudio's stream
  restore). Re-applying each player's own level on `Playing` handles that. On
  Windows two players in one stack may also share one session volume. Test two
  players early in phase 1; candidate fixes are `--aout=directsound` or VLC's
  software gain.
* **Memory rendering cost.** Hardware decoding is abandoned because libVLC 3
  cannot convert GPU surfaces to `RV32` here ("Failed to create video converter").
  Software decoding is fine up to 1080p; 4K at 60 fps may need a native-window
  fast path or a YUV path with GPU copy-back later.
* New script-level features VLC makes possible (subtitles, network streams,
  audio device selection) are out of scope for the first pass.

Problems found in the current player, independent of VLC:

* `MCWin32DSPlayer::GetVolume` has no `return true` (`engine/src/w32-ds-player.cpp:1185-1196`).
* Unhandled `GetProperty` cases leave callers' outputs uninitialised (for example
  `getduration`, `engine/src/player-platform.cpp:1270-1278`).
* `startTime` and `endTime` are saved as 32-bit values (`player-platform.cpp:1179-1182`);
  with the Windows timescale of 10^7 that overflows past about 429 seconds.
* Linux sets the mplayer property `looping`; mplayer's property is `loop`
  (`engine/src/lnxmplayer.cpp:551-554`).
