# Steps for updating CEF

Since CEF 156 one `include` folder and one `libcef_dll` folder serve every
platform: CEF's wrapper names its platform sources `*_win.cc`, `*_linux.cc`
and `*_mac.cc`/`*_mac.mm` (`libcef.gyp` keeps each to its platform), and
its platform headers `*_win.h`, `*_linux.h` and `*_mac.h`.

- Find the version at <https://cef-builds.spotifycdn.com/index.html>. Add the
  SHA-1 of each distribution `prebuilt/scripts/build-cef.sh` and
  `prebuilt/build-libraries-windows.ps1` fetch (Spotify's `index.json`) to
  `prebuilt/cef-sha1sums`, and the version to `prebuilt/versions/cef`,
  `cef_buildrevision` and `cefchromium`.
- Delete `thirdparty/libcef/include` and `thirdparty/libcef/libcef_dll`, and
  copy `include` and `libcef_dll` from the Linux 64-bit minimal distribution.
  Copy in the Windows distribution's `*_win.h` and `*_win.cc` files that the
  Linux one lacks.
- `include/cef_config.h` differs per platform: keep the guards at its end
  (`CEF_X11` on Linux only, `CEF_V8_ENABLE_SANDBOX` on 64-bit builds only),
  checking them against each distribution's copy.
- `cd thirdparty/libcef`, then run
  `python3 gen_libcef_paths.py libcef_dll > libcef.gypi` and
  `python3 gen_libcef_stubs.py include > libcef.stubs`. Stderr lists the
  types the stub generator does not know: add them to its table and run it
  again (the Windows entry points `HINSTANCE`, `LPWSTR`, `mainPtr` and
  `wWinMainPtr`, and the test-only `cef_test_cert_type_t`, are left out on
  purpose). What only one platform's or the test libcef exports is an
  optional (`?`) stub, so the other platforms still load.
  `tools/ci/tests/test_libcef_stubs.py` fails while either file is stale.
- List the files of the new distributions in `tools/ci/cef-156-files.txt`
  (renamed for the version), regenerate `prebuilt/libcef.gyp` from it, and
  update `Installer/package.txt` (components `Externals.CEF.*`) and
  `tools/oxt/package.py` (the `cef` files) to the same names.
- Reconfigure and build; fix any API changes.
- Run `tools/ci/browser_compat_check.py` against the new build: what a
  script sees of htmlText and url must not change.
