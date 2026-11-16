# Notice of modifications

OXT-Beyond is a modified version of **LiveCode Community**, the GPLv3
edition of LiveCode by LiveCode Ltd and its contributors, as it was left
in July 2021 (the 9.7 development tree), carried on through Tom Perry's
**OpenXTalk Lite**. GPLv3 section 5(a) asks a modified work to say that
it was modified, and when. This file and the notices it describes say so.

- **Source files.** Every source file that came from LiveCode Community
  and has changed since carries a comment under its LiveCode header that
  begins "Modified from LiveCode Community", names everyone whose changes
  it holds and the years of their changes, and links this repository.
  `python3 tools/ci/modification_notices.py list` lists them, and CI
  checks fails a pull request that changes another such file without
  adding its notice (`modification_notices.py write` adds it).
- **Files that cannot hold a comment**: the IDE's binary stacks
  (`.livecode`, `.rev`, `.oxtstack`), the dictionary entries (`docs/`,
  `.lcdoc`), the guides, pictures, data and settings files, and source
  files that a script writes (`thirdparty/libcef/libcef.gypi`). Those that
  came from LiveCode Community and differ from it were modified for
  OpenXTalk Lite (2023-2026) and OXT-Beyond (2026), and this notice is
  theirs. The text form of every stack's scripts is in `stack-scripts/`.
- **Other projects' libraries** in `thirdparty/` keep their own licences;
  each folder's ORIGIN file says which version it is and what OXT-Beyond
  changed, and the changes are marked "OXT-Beyond" in the sources.

Who changed what, and when, is in this repository's Git history (Tom
Perry's OpenXTalk Lite versions are commits of their own, with their
original dates) and, release by release, in [CHANGELOG.md](CHANGELOG.md).
[README.md](README.md#where-oxt-beyond-comes-from) and
[HISTORY.md](HISTORY.md) tell where OXT-Beyond comes from, and
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) credits the code taken
from other forks and projects.
