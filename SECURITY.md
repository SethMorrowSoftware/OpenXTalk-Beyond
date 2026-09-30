# Security policy

## Reporting a vulnerability

Please report security problems privately, not in a public issue.

Use GitHub's private reporting form:
<https://github.com/SethMorrowSoftware/winoxt/security/advisories/new>
(you need to be signed in to GitHub). Only the maintainers can see the
report. GitHub's documentation explains
[how private reporting works](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability).

At the time of writing, private reporting has not been turned on for
this repository yet, so the form may say that it is not available. In
that case, open an ordinary
[issue](https://github.com/SethMorrowSoftware/winoxt/issues) that says
only that you have a security report and would like a private way to
send it. Do not include any details of the problem in that issue. A
maintainer can then open a draft security advisory, which only the
maintainers and the people added to it can see, and
[add you to it](https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/adding-a-collaborator-to-a-repository-security-advisory)
so that you can send the details there.

Please include:

- the OXT-Beyond version and build number (the version is in the title
  of the menubar window, for example "OXT-Beyond 0.0.1", and in
  `ide/.version` of a source checkout; the build number is under
  *Preferences > Automatic Updates*) and your Windows version;
- whether you use the installed or the portable copy;
- what an attacker can do, and what they need first (for example, "a
  user opens a crafted stack file");
- steps or a small stack or script that shows the problem.

This is a small volunteer project. There is no bug bounty and no
guaranteed response time, but reports will be read and answered as soon
as possible. Please give us a reasonable amount of time to fix a problem
before you publish details.

Problems in OpenXTalk Lite itself, in LiveCode or in the OpenXTalk
forums' own software are outside this project; report those to their
maintainers.

## Supported versions

Only the latest release, and the `main` branch, get fixes. OXT-Beyond
0.0.1 is the first release.

## Downloads and signatures

The Windows binaries (the installer, `OXT-Beyond.exe` and the other
programs and libraries) are **not code-signed**, so Windows SmartScreen
may warn about them. The macOS app is **signed ad hoc**, with a
signature that lets macOS check that the app's files are intact but
names no Apple Developer ID, and it is not notarized by Apple, so macOS
blocks it until you allow it (see the README's macOS section). The Linux package is not signed. Download
them only from this repository's
[Releases page](https://github.com/SethMorrowSoftware/winoxt/releases)
and check them against the `SHA256SUMS` file of the same release, which
lists every file of the release, for example:

```bat
certutil -hashfile OXT-Beyond-0.1.0-win-x86_64-setup.exe SHA256
```

On macOS, `shasum -a 256 <file>`; on Linux, in the folder with the
download and `SHA256SUMS`, `sha256sum -c SHA256SUMS --ignore-missing`.

Development builds (workflow artifacts on the Actions tab) are made by
the same workflows but are not reviewed as releases.

The packages also contain prebuilt files that are not built from this
repository: the standalone runtimes for 32-bit Windows, Linux and
Android, taken unchanged from OpenXTalk Lite 1.15. The packager
downloads them from this repository's `runtimes-1.15` release and
refuses them unless their SHA-256 matches the one recorded in
[`tools/oxt/external-assets.json`](tools/oxt/external-assets.json).
They are old builds (stock LiveCode 9.6.3 files and files as Tom Perry
shipped them, among them his 9.7.1-OXT Linux engine), and the
Linux runtimes include shared libraries of other projects at the
versions Tom shipped; they have not been rebuilt or updated. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md#standalone-runtimes-for-other-platforms).

## Updates

OXT-Beyond's update check (*Help > Check for Updates*, and the
automatic check if you turn it on in *Preferences > Automatic Updates*;
it is off by default):

- asks GitHub's API (`api.github.com`) over HTTPS for this repository's
  latest release, and for the list of its releases when the latest one
  is not an OXT-Beyond version (for example `prebuilts-v1`) or when you
  run a pre-release, and reads the version number (the release's `v`
  tag), name and notes from the answer; pre-releases are offered only
  to people who already run a pre-release;
- identifies itself to GitHub as OXT-Beyond with its version number
  (the User-Agent header), and sends nothing else about you or your
  computer beyond what any web request carries (such as your IP
  address);
- if the release is newer than yours, shows its notes and a button that
  opens the release page on github.com in your browser, and does nothing
  else;
- never downloads, installs or runs anything, never writes into the
  program folder and never asks for administrator rights;
- never contacts OpenXTalk Lite's update servers (tsites.co.uk,
  openxtalk.net).

You update by downloading the new installer, disk image or archive from
the Releases page yourself and checking it as described above.

OpenXTalk Lite's own updater worked differently: it downloaded IDE
files from Tom Perry's servers and copied them into the program folder
with a script run with administrator rights. OXT-Beyond does not use
it. Its stack (`Toolset/palettes/updates/updates.livecode`) is still in
the program folder, unchanged, because binary stacks were not re-saved
for this release, but the IDE no longer opens it.

Some *Help* menu items open web pages in your browser, for example the
OpenXTalk forums (openxtalk.org) and *Dictionary Online* (openxtalk.net).
They are ordinary links; nothing is downloaded into OXT-Beyond.

## Known issues in bundled components

The Windows build still uses the third-party libraries that LiveCode
Community last shipped. They are old, no longer supported by their
authors, and have publicly known vulnerabilities:

| Component | Version in this build | Status |
| --- | --- | --- |
| OpenSSL | 1.1.1g (2020) on Windows; 1.1.1w (2023, the last 1.1.1 release) on Linux and macOS | The 1.1.1 series reached end of life in September 2023 ([announcement](https://openssl-library.org/post/2023-09-11-eol-111/)). 1.1.1w has the fixes up to then; the Windows prebuilts are still 1.1.1g until they are rebuilt. Later vulnerabilities are fixed only in OpenSSL 3. |
| curl (libcurl) | 7.51.0 (2016) | Many vulnerabilities have been fixed since; see curl's [vulnerability table](https://curl.se/docs/vulnerabilities.html). Used by the server engine. |
| CEF / Chromium | CEF 74.1.19, Chromium 74.0.3729.157 (2019) | Years of unpatched browser vulnerabilities. Used by the browser widget and revBrowser. Do not use them to display content you do not trust. |
| ICU | 58.2 (2016) | Old; later releases include security fixes. |
| MySQL Connector/C | 6.0.0 | Old client library used by the MySQL database driver. |
| libpq (PostgreSQL) | from PostgreSQL 8.1.8 | Old client library used by the PostgreSQL database driver. |

Other libraries in `thirdparty/` (libxml2 2.9.4, libpng 1.6.26, zlib
1.2.8, PCRE 8.39 and others) are also several years old. SQLite was
updated to 3.51.1.

Upgrading these libraries is planned. It needs new prebuilt archives
built from source, which is tracked as future work. Until then, treat
the browser components and any network or file-parsing features as
unsafe for untrusted input. [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)
lists every bundled component.

Stacks are programs: opening a stack can run its scripts. Only open
stacks from sources you trust.
