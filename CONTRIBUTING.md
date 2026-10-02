# Contributing to OXT-Beyond

Thank you for helping. Bug reports, fixes, documentation, testing on
different Windows, macOS and Linux setups and work on the plans listed
in the
[README](README.md#known-limitations-and-plans) are all welcome.

This project is small and run by volunteers. Please be patient with
reviews, and be kind to each other.

## Licence of contributions

There is **no contributor licence agreement** (CLA). LiveCode Ltd needed
one because it also sold LiveCode under a commercial licence; this
project does not.

By opening a pull request you agree that your contribution is licensed
under the GNU General Public License version 3 ([LICENSE](LICENSE)) with
the same additional permission to combine the code with OpenSSL and
Microsoft ATL that LiveCode Ltd granted
([LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md)). Only contribute work you
have the right to contribute. If you bring in work by someone else (for
example from an OpenXTalk forum post), say so in the pull request, with
its author, source and licence.

### Sign your commits (recommended)

We recommend adding a `Signed-off-by` line to each commit to certify the
[Developer Certificate of Origin](https://developercertificate.org/)
(DCO): that you wrote the change, or otherwise have the right to submit
it under the project's licence. Git adds the line for you:

```bat
git commit -s
```

The line uses the name and e-mail address in your Git configuration:

```bat
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## Before you start

- For anything bigger than a small fix, open an
  [issue](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/issues) first to
  talk about the idea. It saves work on both sides.
- Read [BUILDING.md](BUILDING.md) and get a local build working. Changes
  to the engine, externals or build files need to be built and tried
  before review. Changes to IDE scripts can be tried on Windows with a
  downloaded `OXT-Beyond-<version>-win-x86_64-binaries.zip` extracted
  into your clone, but the IDE compile check and packaging need
  Python 3.
- This project builds, packages and tests Windows x86-64, macOS (one
  universal app for Apple Silicon and Intel) and Linux x86-64, and
  builds Linux arm64 without packaging it. Code for other platforms
  (iOS, Android and others) is still in the tree; try not to break it,
  but CI does not build it. The Linux and macOS builds run in CI (see
  [BUILDING.md](BUILDING.md#12-building-on-linux), sections 12 and 13),
  so the checks of a pull request build and test a change on all three
  platforms.

## Branches and pull requests

- `main` is the only long-lived branch. Releases are tags on `main`
  (see [BUILDING.md](BUILDING.md#10-making-a-release)).
- Work on a feature branch in your fork (or, for maintainers, in this
  repository) with a short descriptive name, for example
  `fix-dark-mode-menus` or `docs-building`.
- Open a pull request against `main` and fill in the template.
- The checks of the three build workflows must pass before a pull
  request is merged: "Build win-x86_64"; "Build linux-x86_64", "Build
  linux-arm64" and "Package linux-x86_64"; "Build mac-arm64", "Build
  mac-x86_64", "Package mac-universal", "Test mac-universal (arm64)" and
  "Test mac-universal (x86_64)". If one fails, the log artifacts of its
  run help: `build-logs-win-x86_64` (`msbuild.log` and the logs of
  packaging, the smoke test, the IDE compile check and the installer
  test), `build-logs-linux-<arch>` and `build-logs-mac-<arch>` (uploaded
  when a build fails), `package-logs-linux-x86_64`,
  `package-logs-mac-universal` and `test-logs-mac-universal-<arch>`.
- Keep each pull request to one change, or a few closely related ones.
  Update it by pushing more commits.

### How pull requests are merged

- **Ordinary changes** may be merged with "Squash and merge", which
  turns the pull request into one commit on `main`.
- **Pull requests that carry imported history must be merged with
  "Create a merge commit".** Never squash or rebase them. This applies
  to every pull request whose commits record other people's work with
  its original authors and dates, such as the OpenXTalk Lite IDE history
  (commits authored by Terry Little and Tom Perry), a future import of a
  newer OpenXTalk Lite, xTalk Suite or upstream LiveCode change, or any
  other history taken over from another repository. Squashing would
  replace those authors and dates with the maintainer's and lose the
  per-version commits; rebasing would rewrite every commit. Say in the
  pull request description that it carries imported history.

The upstream LiveCode branch model (`develop`, `develop-X.Y`,
`release-X.Y`, described in `docs/development/release_branching_policy.md`)
does not apply here.

## Commit messages

```text
Short summary of the change (about 72 characters at most)

A longer explanation of what the change does and why, wrapped at about
72 characters. Mention anything a reviewer would not guess from the
diff: alternatives you tried, things you could not test, follow-up
work.

Fixes #123

Signed-off-by: Your Name <you@example.com>
```

- Write the summary in the imperative ("Fix crash when ...", not "Fixed"
  or "Fixes").
- Refer to GitHub issues as `#N`. Writing `Fixes #N` in the commit message
  or pull request description closes the issue when the change is merged.
- Old commits use tags such as `[[ Bug 12345 ]]`, which refer to LiveCode
  Ltd's bug tracker (quality.livecode.com). Do not use them for new work.
- A commit that changes a binary stack must say what changed in it (see
  [below](#binary-stacks)), because Git cannot show it.

## Coding style

Follow the style of the file you are editing (including tabs or spaces
and line endings). For new code, the upstream guides still apply:

- C++: [C++ coding style](docs/development/C++-style.md) and
  [use of C++ language features](docs/development/C++-features.md). The
  engine is built with the Visual Studio 2017 (v141) compiler, so do not
  use language features it does not support.
- LiveCode Builder:
  [LiveCode Builder Style Guide](docs/guides/LiveCode%20Builder%20Style%20Guide.md).
- LiveCode script in the IDE: keep the style of the surrounding script.
  Mark changes to inherited scripts with a comment that starts with
  `-- OXT-Beyond:` and says why. Keep the existing dated comments, such
  as Tom Perry's `(tperry 28-6-24)` and Terry Little's; they are the
  record of their changes.
- Python (`tools/oxt/`): Python 3, standard library only, working on
  Windows and Linux.
- PowerShell (`tools/ci/`): must run in both Windows PowerShell 5.1 and
  PowerShell 7, with `$ErrorActionPreference = 'Stop'`, and must check
  `$LASTEXITCODE` after running programs.
- Documentation: [docs/contributing_to_docs.md](docs/contributing_to_docs.md)
  describes the dictionary and guide formats. Its parts about LiveCode's
  CLA, build servers and bug tracker do not apply here.
- Batch and command files (`*.bat`, `*.cmd`) are checked out with
  Windows (CRLF) line endings; keep them that way. Shell scripts
  (`*.sh`, `*.inc`) must use Unix (LF) line endings.

Please do not reformat code you are not otherwise changing; it makes
the real change hard to review.

## Changing the IDE

The IDE is in `ide/` (and 11 libraries in `ide-support/`). Much of it is
stored in binary stacks (`*.livecode`, `*.rev`, `*.oxtstack`), which Git
can store but not diff or merge.

### Prefer script-only stacks

- Put new IDE code in script-only stacks (`*.livecodescript`), for
  example a new library in `ide/Toolset/libraries/`, rather than in a
  binary stack. They can be reviewed, diffed and merged like any other
  text file.
- When you need to change a script that lives inside a binary stack,
  consider moving it into a script-only stack first (for example as a
  behavior), in its own commit.

### Binary stacks

- Do not open and save binary stacks you do not intend to change.
  Saving rewrites the whole file (and can change its stack format
  version and the paths stored in it), even if you changed nothing.
- Change a binary stack only with the IDE built from this repository,
  run from your clone (see
  [BUILDING.md](BUILDING.md#11-working-on-the-ide)), so that it is saved
  by the engine this project ships.
- Keep each binary stack change in its own commit, and say in the commit
  message which objects, properties or scripts changed and why.
- Do not remove other people's credits or dated comments from stacks.
- The "OpenXTalk Lite" text that is still inside binary stacks will be
  changed in reviewable steps like these; please coordinate in an issue
  before changing many stacks at once.

### Check your change

- Run the IDE from your clone and try the part you changed.
- Run the IDE compile check (see
  [BUILDING.md](BUILDING.md#ide-compile-check)). It compiles every
  script, including the object scripts inside binary stacks, and fails
  on errors that are not in `tools/ci/ide-compile-baseline.txt`. If your
  change fixes a known error, remove its line from the baseline in the
  same pull request.
- If you changed anything that runs at start-up, packaging or the
  installer, also try the packaged or installed program.

### Tom Perry's plugin

`ide/Extensions/community.openxtalk.plugin.oxtlite` carries Tom Perry's
notice, which must stay with the plugin unaltered. Do not edit its
header; see
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#tom-perrys-notice-for-communityopenxtalkpluginoxtlite).

## Importing from other projects

- **OpenXTalk Lite or other installed IDEs.**
  [`tools/oxt/layout.py`](tools/oxt/README.md) classifies the files of an
  installed OpenXTalk Lite (or LiveCode) folder, imports its IDE files
  into `ide/` and `ide-support/`, and verifies the result. Use it for any
  future import, in a branch of its own: one commit per upstream version,
  with the original author and date, a message that names the sources
  and credits the people involved, and a merge commit (see
  [above](#how-pull-requests-are-merged)). Record what was left out and
  why.
- **Binaries this repository does not build** (runtimes for other
  platforms, and later extensions from the xTalk Suite repositories at
  pinned versions) are not committed. They are listed in
  [`tools/oxt/external-assets.json`](tools/oxt/external-assets.json) with
  a URL, size and SHA-256, and added by the packager (see
  [BUILDING.md](BUILDING.md#external-assets)).
- Every import must come with its licence: update
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md), and leave out files
  whose terms do not allow redistribution (as `layout.py` does with the
  files it classes "excluded").

## What not to commit

Build output and downloaded files: `build-win-x86_64/`,
`win-x86_64-bin/`, `build-linux-<arch>/`, `linux-<arch>-bin/`,
`build-mac/`, `_build/`, `prebuilt/fetched/`, `prebuilt/unpacked/`,
`prebuilt/fetched-assets/`, `prebuilt/packaged/` and `dist/`. Most are
already ignored by Git.
Never commit hand-edited files from `build-win-x86_64`; change the
`*.gyp` or `*.gypi` files and run `config.py` again.

Files the IDE writes when you run it from your clone: for example
`ide/environment_log.txt` (ignored) and the dictionary's index files in
`ide/Documentation/html_viewer/resources/data/api/exports/*/index.txt`,
which are tracked. If the latter show up as modified after running the
IDE, restore them with `git checkout -- <path>` unless you meant to
change them.

`debug_syms_inputs.txt` in the repository root is different: configuring
rewrites it, but it is tracked by Git (it came with Tom Perry's
changes). If it shows up as modified, restore it with
`git checkout -- debug_syms_inputs.txt` rather than committing the
change with unrelated work.

`ide/.buildnumber` holds the placeholder `0`; do not commit a real
build number (packaging writes it).

## Third-party code

`thirdparty/` holds the sources of the third-party libraries. On
Windows, most of them are **not** compiled from `thirdparty/` by the
normal build: the engine links the static libraries in the "Thirdparty"
prebuilt archive, so changing a source file there usually has no effect
on the Windows programs until the prebuilt archive is rebuilt. SQLite is
the exception (it is compiled from `thirdparty/libsqlite`). See
[thirdparty/README.md](thirdparty/README.md) and the "Prebuilt libraries"
section of [BUILDING.md](BUILDING.md#6-prebuilt-libraries).

When you add or update third-party code, content or an external asset,
update [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and keep the
licence file in the tree (or in the asset).

## Testing

Say in your pull request how you tested the change. Depending on what
you changed:

- build Release x64 with `make.cmd` (BUILDING.md, section 5);
- run the IDE from your clone (`win-x86_64-bin\LiveCode-Community.exe`)
  and try the part you changed;
- run `tools\ci\verify-build.ps1` and `tools\ci\smoke-test.ps1` if you
  changed the engine, externals or build;
- run `tools\ci\package-windows.ps1` and `tools\ci\ide-compile-check.ps1`
  if you changed the IDE or packaging;
- run `tools\ci\build-installer.ps1` and `tools\ci\test-installer.ps1` if
  you changed the installer;
- on Linux or macOS, run `python3 tools/ci/run_livecode_check.py`
  (`smoke` and `compile`), and the checks of the
  [Linux package](BUILDING.md#linux-package) or the
  [macOS app](BUILDING.md#macos-app), if you changed something that
  works differently there.

CI runs all of these on every pull request, on each platform. The C++ unit tests
(`cmd /c ..\make.cmd check`) and the upstream LiveCode script test suites
in `tests/` have not been set up for this project yet; help with that is
welcome.

## Release notes

Releases use GitHub's generated release notes, which list the merged
pull requests, after a description written by the release workflow
(`tools/ci/release_notes.py`: what the release is, which file to
download on each platform, what each platform needs, and how to check
the downloads). Give your pull request a title that makes sense in that
list, and describe any change users will notice in its description. The
fragments in `docs/notes/` are upstream LiveCode release notes; do not
add new ones there. [HISTORY.md](HISTORY.md) records the history up to
OXT-Beyond 0.0.1.

## Reporting bugs

Use the [issue forms](https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/issues/new/choose)
for bugs, build problems and feature requests. Report security problems
privately as described in [SECURITY.md](SECURITY.md). For general
questions about xTalk programming, the
[OpenXTalk forums](https://openxtalk.org/forum/) are a good place to
ask.
