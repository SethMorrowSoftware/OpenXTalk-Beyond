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

- the OpenXTalk Lite version (Help > About LiveCode, or the `version` file in a
  source checkout) and your Windows version;
- what an attacker can do, and what they need first (for example, "a
  user opens a crafted stack file");
- steps or a small stack or script that shows the problem.

This is a small volunteer project. There is no bug bounty and no
guaranteed response time, but reports will be read and answered as soon
as possible. Please give us a reasonable amount of time to fix a problem
before you publish details.

## Supported versions

Only the latest release, and the `main` branch, get fixes. No release
has been published yet.

## Known issues in bundled components

The Windows build still uses the third-party libraries that LiveCode
Community last shipped. They are old, no longer supported by their
authors, and have publicly known vulnerabilities:

| Component | Version in this build | Status |
| --- | --- | --- |
| OpenSSL | 1.1.1g (2020) | The 1.1.1 series reached end of life in September 2023 ([announcement](https://openssl-library.org/post/2023-09-11-eol-111/)). Many vulnerabilities have been fixed in later releases. |
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

The binaries are not code-signed. Download them only from this
repository's Releases page and check them against the published
`SHA256SUMS` file.
