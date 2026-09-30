## Summary

<!-- What does this change do, and why? Describe any change users will
notice; the title and this text end up in the release notes. -->

## Linked issue

<!-- For example "Fixes #123". Write "None" if there is no issue. -->

## How was it tested?

<!-- Tick what you did and describe the rest. The pull request's checks
build and test Windows, macOS and Linux; say here what you tried
yourself. -->

- [ ] Built Release x64 with `make.cmd` on Windows, or the Linux or macOS build (see BUILDING.md)
- [ ] Ran the IDE from the build (for example `win-x86_64-bin\LiveCode-Community.exe`) and tried the change
- [ ] Ran `tools\ci\verify-build.ps1`, or on Linux or macOS `tools/ci/run_livecode_check.py`
- [ ] Not needed (documentation only, or similar); explain:

Platforms tried:

- [ ] Windows x64
- [ ] macOS Apple Silicon
- [ ] macOS Intel
- [ ] Linux x86-64

Operating system versions used for testing:

## Checklist

- [ ] The commits are signed off (`git commit -s`), certifying the
      [Developer Certificate of Origin](https://developercertificate.org/)
- [ ] I agree that this contribution is licensed under the GPLv3 with the
      additional permission in `LICENSE-EXCEPTION.md` (see CONTRIBUTING.md)
- [ ] The change is limited to one topic, and does not reformat unrelated code
- [ ] Documentation is updated if needed (README.md, BUILDING.md, the dictionary in `docs/`)
- [ ] `THIRD-PARTY-NOTICES.md` is updated if third-party code was added or changed
- [ ] No build output or generated files are included (`build-win-x86_64/`, `win-x86_64-bin/`, `build-linux-*/`, `linux-*-bin/`, `build-mac/`, `_build/`, `prebuilt/fetched/`, `prebuilt/unpacked/`, `prebuilt/packaged/`, `dist/`)
