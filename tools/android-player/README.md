# The Android Stack Player

An Android app that opens any stack you give it, the phone's twin of
[the web Stack Player](../web-player/README.md). It is an ordinary
Android standalone of OXT-Beyond's own Android engine
(`Runtime/Android/Beyond`) with one small stack, "OXT Stack Player",
built by the IDE's own Android builder. No engine change was needed for
it.

This is a first proof: it takes a stack in and plays it. The library
screen made for touch, zip archives, HyperCard stacks and the community
gallery come next, and it is in no release yet.

## What it does

A stack comes in three ways:

- **Open a stack...** shows Android's own "Open document" screen, which
  reaches the device's folders, an SD card and other apps' storage
  (Google Drive, for example) with no permission.
- **Open with**: Android offers the player for a stack file opened in a
  file manager, a mail app or a browser. Android knows no kind for a
  stack file's name, so the player is offered for files of an unknown
  kind (`application/octet-stream`), and says so when a file is no stack.
- **Your stacks**: the stacks opened before.

A stack is a file whose name ends with `.oxtstack`, `.livecode`, `.rev`,
`.livecodescript`, `.oxtscript` or `.mc`. Each one is copied into the
player's library (`specialFolderPath("documents") & "/Stack Player"`), in
a folder of its own: a stack that saves itself saves there, and the file
it came from is never written to. It then opens as on the desktop, with
its folder as the `defaultFolder`.

A stack that sets no `fullscreenMode` as it opens is shown whole, scaled
to the screen (`showAll`); one made for phones, which sets its own, keeps
it. Android's Back comes home to the player, unless the stack handles
`backKey` itself; at home it leaves the app. A script error shows in a
dialog, with a way back.

The app asks for the Internet permission and no other, so a stack from a
stranger cannot reach contacts, the camera, the location or the device's
files. It can read and change the other stacks in the player's library,
which share the app's storage.

## The parts

| File | What it is |
| --- | --- |
| `stack-player.livecodescript` | The player's script: its card, the library, taking a file in, playing a stack |
| `stack-player-back.livecodescript` | Its back script: `backKey`, `urlWakeUp` and `errorDialog` while a stack plays |
| `build-player.livecodescript` | Run in the IDE: makes the player's stack and builds it with the Android builder |
| `build_player.py` | Starts the IDE for the build, checks the package, and plays stacks in it on a device |

It uses two things that any Android app can:
[the Android Documents library](../../extensions/libraries/androiddocuments/androiddocuments.lcb)
(`androidPickDocument`, `androidDocumentName`, `androidCopyDocument`) and
the builder's `android,documentTypes` setting, which offers an app for
kinds of document.

## Building it

With an installed or unpacked OXT-Beyond whose runtimes carry OXT-Beyond's
Android engine (0.2.8-dp.1 or later), a JDK, and an Android SDK as the
Android builder asks for:

```sh
python3 tools/ci/android_check.py overlay --root <ide>          # this checkout's builder, into a release's IDE
python3 tools/android-player/build_player.py library --ide <ide>  # the documents library, if the IDE has none
python3 tools/android-player/build_player.py build --ide <ide> --work <work> --sdk <sdk> --jdk <jdk>
python3 tools/android-player/build_player.py verify --work <work> --sdk <sdk>
python3 tools/android-player/build_player.py device --work <work> --serial emulator-5554 --sdk <sdk>
```

`build` writes `<work>/OXT-Stack-Player.apk`, signed for development only
(`--keystore`, `--alias` and `--password` sign it with a key), and the
sample stacks of `device` in `<work>/samples`. `device` installs it and
plays the sample by a file address, a content address and the Open
button, comes home with Back, and starts the app again to find its
library; it reads what the player says in the device's log
(`OXT Stack Player: ...`). The "Android Stack Player" workflow
(`.github/workflows/android-player.yml`) does all of this on an Android 13
emulator.

The player's script runs on the desktop too, for its tests:
`tests/lcs/androidplayer/stack-player.livecodescript`.
