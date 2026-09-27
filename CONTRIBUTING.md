# Contributing to OpenXTalk Lite for Windows

Thank you for helping. Bug reports, fixes, documentation, testing on
different Windows setups and work on the plans listed in the
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
have the right to contribute.

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
  [issue](https://github.com/SethMorrowSoftware/winoxt/issues) first to
  talk about the idea. It saves work on both sides.
- Read [BUILDING.md](BUILDING.md) and get a local build working. Changes
  to the engine, externals or build files need to be built and tried
  before review.
- Only Windows x86_64 is built by this project. Code for other
  platforms is still in the tree; try not to break it, but CI does not
  build it.

## Branches and pull requests

- `main` is the only long-lived branch. Releases are tags on `main`
  (see [BUILDING.md](BUILDING.md#10-making-a-release)).
- Work on a feature branch in your fork (or, for maintainers, in this
  repository) with a short descriptive name, for example
  `fix-dark-mode-menus` or `docs-building`.
- Open a pull request against `main` and fill in the template.
- The "Build (Windows)" check must pass before a pull request is merged.
  If it fails, the `build-logs` artifact of the run has `msbuild.log`.
- Keep each pull request to one change, or a few closely related ones.
  Update it by pushing more commits; a maintainer may squash them when
  merging.

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

## Coding style

Follow the style of the file you are editing (including tabs or spaces
and line endings). For new code, the upstream guides still apply:

- C++: [C++ coding style](docs/development/C++-style.md) and
  [use of C++ language features](docs/development/C++-features.md). The
  engine is built with the Visual Studio 2017 (v141) compiler, so do not
  use language features it does not support.
- LiveCode Builder:
  [LiveCode Builder Style Guide](docs/guides/LiveCode%20Builder%20Style%20Guide.md).
- Documentation: [docs/contributing_to_docs.md](docs/contributing_to_docs.md)
  describes the dictionary and guide formats. Its parts about LiveCode's
  CLA, build servers and bug tracker do not apply here.
- Batch and command files (`*.bat`, `*.cmd`) are checked out with
  Windows (CRLF) line endings; keep them that way. Shell scripts
  (`*.sh`, `*.inc`) must use Unix (LF) line endings.

Please do not reformat code you are not otherwise changing; it makes
the real change hard to review.

## What not to commit

Build output and downloaded files: `build-win-x86_64/`,
`win-x86_64-bin/`, `prebuilt/fetched/`, `prebuilt/unpacked/`, `dist/`,
and the files the IDE generates in `ide/` (such as the dictionary data
and `environment_log.txt`). Most are already ignored by Git. Never
commit hand-edited files from `build-win-x86_64`; change the `*.gyp` or
`*.gypi` files and run `config.py` again.

`debug_syms_inputs.txt` in the repository root is different: configuring
rewrites it, but it is tracked by Git (it came with Tom Perry's
changes). If it shows up as modified, restore it with
`git checkout -- debug_syms_inputs.txt` rather than committing the
change with unrelated work.

## Third-party code

`thirdparty/` holds the sources of the third-party libraries. On
Windows, most of them are **not** compiled from `thirdparty/` by the
normal build: the engine links the static libraries in the "Thirdparty"
prebuilt archive, so changing a source file there usually has no effect
on the Windows programs until the prebuilt archive is rebuilt. SQLite is
the exception (it is compiled from `thirdparty/libsqlite`). See
[thirdparty/README.md](thirdparty/README.md) and the "Prebuilt libraries"
section of [BUILDING.md](BUILDING.md#6-prebuilt-libraries).

When you add or update third-party code, update
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) and keep the library's
licence file in the tree.

## Testing

Say in your pull request how you tested the change. At least:

- build Release x64 with `make.cmd` (BUILDING.md, section 5);
- run the IDE from your clone (`win-x86_64-bin\LiveCode-Community.exe`)
  and try the part you changed;
- run `tools\ci\verify-build.ps1` if you changed the build.

The C++ unit tests (`cmd /c ..\make.cmd check`) and the upstream LiveCode
script test suites in `tests/` have not been set up for this fork yet;
help with that is welcome.

## Release notes

Releases use GitHub's generated release notes, which list the merged
pull requests. Give your pull request a title that makes sense in that
list, and describe any change users will notice in its description. The
fragments in `docs/notes/` are upstream LiveCode release notes; do not
add new ones there.

## Reporting bugs

Use the [issue forms](https://github.com/SethMorrowSoftware/winoxt/issues/new/choose)
for bugs, build problems and feature requests. Report security problems
privately as described in [SECURITY.md](SECURITY.md). For general
questions about xTalk programming, the
[OpenXTalk forums](https://openxtalk.org/forum/) are a good place to
ask.
