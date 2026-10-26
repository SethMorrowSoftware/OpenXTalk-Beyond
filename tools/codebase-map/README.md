# The codebase map

One page that shows how OXT-Beyond fits together, for anyone about to
change it: the engine's subsystems and headers, the IDE's stacks and
libraries and the order the message path searches them, the IDE's message
bus and globals, the extensions and the xTalk Suite members built into
it, the build and CI, the project's history, and a "what breaks if I
change..." search over all of it. It is on the GitHub Pages site at
`<site>/map/`, and the page's own "How it was made" view says how each
number is counted.

The workflow [pages.yml](../../.github/workflows/pages.yml) makes it from
the commit it checks out every time it builds the site (each release, or
by hand), so it is as new as the site. Making it is allowed to fail: the
site then goes up without it and the run's summary says so.

| File | What it does |
| --- | --- |
| [build_map.py](build_map.py) | reads the repository and its git history, xtalk-suite and the stack dumps, and writes `map-data.json`, `index.html` (the page for any web host) and `codebase-map.html` (the same page for a claude.ai Artifact) |
| [lcs.py](lcs.py) | the LiveCode Script scanner: handlers, the names a script calls, `send` and `dispatch` targets, stack references, globals, front and back inserts, `start using`, the IDE message bus |
| [template.html](template.html) | the page; `build_map.py` puts the data in it |
| [make_dumps.sh](make_dumps.sh) | writes out the scripts of every binary IDE stack with a released engine and [ide-stack-dump.livecodescript](../oxt/ide-stack-dump.livecodescript) (headless, messages locked, nothing saved) |

Everything is read as text: nothing is built or run, so a link made at
run time (a `send` to a name put together in a variable, say) is not on
the map. Without the stack dumps the binary stacks' scripts are left
out, and the page says which.

## Making it on your own computer

Linux, Python 3 (PyYAML adds the CI view), a released Linux engine, and
a clone with its history (`--filter=blob:none` is enough; in a shallow
clone the oldest commit's files are left out of the churn, because git
cannot tell what it changed):

```sh
git clone --filter=blob:none https://github.com/SethMorrowSoftware/OpenXTalk-Beyond.git
git clone --depth 1 https://github.com/SethMorrowSoftware/xtalk-suite.git
gh release download <tag> --repo SethMorrowSoftware/OpenXTalk-Beyond --pattern '*-linux-x86_64-binaries.tar.xz'
tar -xJf OXT-Beyond-*-linux-x86_64-binaries.tar.xz
npm pack d3@7.9.0 && tar -xzf d3-7.9.0.tgz   # dist/d3.min.js: sha256 f2094bbf...b86539
bash OpenXTalk-Beyond/tools/codebase-map/make_dumps.sh OpenXTalk-Beyond linux-x86_64-bin/LiveCode-Community dumps
python3 OpenXTalk-Beyond/tools/codebase-map/build_map.py --beyond OpenXTalk-Beyond \
    --suite xtalk-suite --dumps dumps --d3 package/dist/d3.min.js --out out
```

`out/index.html` is the whole page in one file, d3 and its licence
included, so it can go on any web host as it is (cPanel's `public_html`,
for example). Without `--d3` it loads d3 from cdnjs instead. `--since`
(default 2026-05-01) sets where the history starts. Two runs on the same
commit give the same page but for the time it was made.
