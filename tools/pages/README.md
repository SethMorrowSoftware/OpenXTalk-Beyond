# The GitHub Pages site

The web IDE ([tools/web-ide](../web-ide/README.md)) and the Stack Player
([tools/web-player](../web-player/README.md)) on the repository's GitHub
Pages site, so that anyone can open them with nothing to download:

| Address | What |
| --- | --- |
| `https://<owner>.github.io/<repository>/` | the front page ([index.html](index.html)), which links to both |
| `.../ide/` | the web IDE |
| `.../dictionary/` | the IDE's Dictionary (xTalk Script and xTalk Builder), which Help > Dictionary Online opens |
| `.../player/` | the Stack Player |
| `.../map/` | the [codebase map](../codebase-map/README.md), for contributors, with the binary stacks' scripts as files beside it (`stack-scripts/`, `stack-scripts.zip`) |

The workflow [pages.yml](../../.github/workflows/pages.yml) builds no
part of the IDE or the player: it takes the two sites as a release ships them
(`OXT-Beyond-<version>-web-ide.zip` and `OXT-Beyond-<version>-web-player.zip`),
puts them in their folders with [build_pages.py](build_pages.py) and
deploys the result. The one thing it makes is the codebase map, from
the source of the commit it checks out, with
[build_map.py](../codebase-map/build_map.py); if that fails, the site goes
up without the map.

The Dictionary is made from the web IDE zip, so it is that release's:
[build_dictionary.py](build_dictionary.py) takes the IDE's dictionary
viewer (its page template, styles and scripts) and dictionary data from
the zip's `ide.zip` and writes the page the IDE once made for its browser
Dictionary, titled "OXT-Beyond Dictionary", with the data in one
`built_api.js`. A web IDE without the viewer (one before 0.2.7) leaves the
Dictionary off the site; one whose Dictionary cannot be made stops the
build. The Web IDE workflow makes it from every zip it builds, the
release's too, and reads it in Chromium with
[check_dictionary.py](check_dictionary.py) (its title and APIs, every
entry listed, a search, an entry opened, no missing file); the IDE tour's
dictionary-online step checks that Help > Dictionary Online opens
`https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/dictionary/`.

The Release workflow starts it once a release is
published (its last job, "Web pages"), and it runs by
hand (Actions > Web pages > Run workflow, with a release's tag or none for
the newest). A release that has no web IDE zip takes the web IDE from a Web IDE
run's artifact instead (the input `ide-run`, or main's newest run); the
header of the workflow says how.

A build that is not released yet, such as a release dry run's, goes on
the site by hand with the input `build-run` (that run's id): both zips are
then taken from its artifacts, and the front page marks them "test build".
A dry run starts no deploy itself, so the test build stays until the
release's own run puts the released files there.

Both sites ask for their files with relative addresses, so they run from
a folder of the site. The web engine uses no threads, so GitHub Pages needs
no special headers, and it serves `.wasm` as `application/wasm`. Its
largest file, the engine's `.wasm` (about 23 MB), is well under GitHub
Pages' 100 MB a file, which `build_pages.py` checks.

Pages are served from `<owner>.github.io`, one address for every Pages site
of the owner, so the web IDE's saved stacks and the Stack Player's stacks
(the browser's storage) are kept per browser for that address.

## Turning it on

Once, in the repository's Settings > Pages: under "Build and deployment",
set Source to **GitHub Actions**. Then run Actions > Web pages > Run
workflow, or wait for the next release.

To try the site on your own computer:

```sh
python3 tools/pages/build_pages.py --out site \
    --ide OXT-Beyond-<version>-web-ide.zip --ide-version <version> \
    --player OXT-Beyond-<version>-web-player.zip --player-version <version> \
    [--map out/index.html --map-version main]
cd site && python3 -m http.server 8000
```
