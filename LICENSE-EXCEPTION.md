# Licence exception for OpenSSL and ATL

OXT-Beyond is licensed under the GNU General Public License, version 3.
The full licence text is in [LICENSE](LICENSE). This file explains an
additional permission that covers parts of it; read "Where it applies"
below for which parts.

LiveCode Ltd released LiveCode Community under the GPLv3 together with
an additional permission: its GPL code may be combined with Microsoft's
Active Template Library (ATL), which revBrowser uses on Windows, and
with OpenSSL, which the secure sockets and encryption features use.
Both are under licences that are not compatible with the GPL. LiveCode Community
shipped this permission at the top of its LICENSE file. It is copied
below, unchanged, so that LICENSE can hold the plain GPLv3 text.

## Where it applies in this repository

- **Code from LiveCode Community.** Most of this repository (the
  engine, libraries, externals, toolchain and the parts of the IDE in
  `ide/` and `ide-support/` that LiveCode Community shipped) comes from
  LiveCode Community. LiveCode Ltd's code is covered by the permission
  exactly as LiveCode Ltd granted it.
- **Tom Perry's engine changes (commit `38d5712b2`).** Tom Perry's
  OpenXTalk Lite engine work was imported from his working copy without
  a licence statement. His new files `engine/src/respring.cpp` and
  `engine/src/respring.h` are headed "OpenXTalk Contributors" and GPLv3,
  without this permission, and his edits to existing LiveCode files
  (for example `engine/src/w32theme.cpp`) sit in files whose headers
  say GPLv3. It has **not been confirmed** that Tom offers his changes
  with the permission to combine them with ATL and OpenSSL; that still
  has to be asked of him. Until he confirms, treat his changes as plain
  GPLv3.
- **OpenXTalk Lite's IDE changes.** The IDE in `ide/` and `ide-support/`
  is the OpenXTalk Lite 1.15 IDE. Its changes to the LiveCode IDE were
  made by Terry Little, Tom Perry, Paul McClernan and other OpenXTalk
  contributors, and came to this repository from OpenXTalk Lite's
  released files (the commits from `2197b3457` to `523b3b208`; see
  [HISTORY.md](HISTORY.md)), without a licence statement. Tom Perry has
  said that OpenXTalk Lite remains under LiveCode Community's licence,
  the GPLv3. It has **not been confirmed** that these contributors offer
  their changes with the permission to combine them with ATL and
  OpenSSL. Until they confirm, treat their changes as plain GPLv3.
- **Contributions through pull requests.** Changes contributed to this
  repository under [CONTRIBUTING.md](CONTRIBUTING.md) are offered under
  the GPLv3 plus the same permission to combine with ATL and OpenSSL.
- **Files with their own terms.** A file whose header or notice states
  different terms is licensed as it says. In the IDE, for example, Terry
  Little's Quick Dictionary and Report Builder plugins are under the
  GPL version 3 or later, Paul McClernan's macOS Native Tools library
  states the MIT licence, and Tom Perry's
  `community.openxtalk.plugin.oxtlite` carries its own notice with a
  condition. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#the-ide).
- **Third-party code** in `thirdparty/`, `prebuilt/` and elsewhere, and
  the prebuilt standalone runtimes for other platforms that packages
  include, keep their own licences. See
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

This file is not legal advice. If you are unsure whether the permission
covers your use, ask a lawyer.

## The text of the permission, as published by LiveCode Ltd

---

Notes:

The majority of the code in the LiveCode Community edition is copyrighted
by LiveCode Ltd and has been released under the GPLv3.

However, the revBrowser component on Windows and secure sockets and
encryption feature on Windows and Linux utilises code that is under a
license incompatible with the GPL. Specifically revBrowser uses ATL and
the secure sockets and encryption feature uses OpenSSL.

To this end, as a special exception to the terms and conditions of the
GPL listed below, LiveCode Ltd gives you explicit permission to
combine its GPL code contained in LiveCode Community with ATL and
OpenSSL. You may copy and distribute such a combination provided that
you adhere to the terms and conditions of all of the GPL and licenses
of the third-party code; in particular, you must include the source code
of the entire combination insofar as the GPL requires distribution of
source code.

Note that this exception is only needed and only has effect when
distributing applications built with LiveCode Community which use
revBrowser (on Windows) or OpenSSL (on Windows and Linux).

---
