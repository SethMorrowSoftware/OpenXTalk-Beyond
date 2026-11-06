# The GitHub Pages site

The web IDE ([tools/web-ide](../web-ide/README.md)) and the Stack Player
([tools/web-player](../web-player/README.md)) on the repository's GitHub
Pages site, so that anyone can open them with nothing to download:

| Address | What |
| --- | --- |
| `https://<owner>.github.io/<repository>/` | the front page ([index.html](index.html)), which links to both |
| `.../ide/` | the web IDE |
| `.../dictionary/` | the IDE's Dictionary (xTalk Script and xTalk Builder), which Help > Dictionary Online opens |
| `.../lessons/` | the lessons: xTalk from the first line to xTalk Builder, and the extensions that come with OXT-Beyond, a page a lesson, searchable ([lessons/](lessons/)) |
| `.../player/` | the Stack Player |
| `.../extensions/` | the xTalk Suite's extensions, built into OXT-Beyond, each with its `.lce` packages to download ([extensions/index.html](extensions/index.html)) |
| `.../play/` | the bare player: a stack and nothing around it (`?stack=`, `?play=`; see [tools/web-player](../web-player/README.md)), on the Stack Player's engine |
| `.../games/` | web games, such as Pixel Platformer Maker: each page runs its `standalone.zip` on the Stack Player's engine |
| `.../map/` | the [codebase map](../codebase-map/README.md), for contributors, with the binary stacks' scripts as files beside it (`stack-scripts/`, `stack-scripts.zip`) |

The front page is one self-contained file: its look (a night sky over an
orange horizon, a small stack whose button answers as its script says,
and a card for each part) is drawn with its own CSS and SVG, and it asks
no other host for anything. `build_pages.py` drops every block of a part
it was not given (a part can have more than one: its card, and its
button in the header). [test_pages_front.py](../ci/tests/test_pages_front.py)
builds it with every set of parts and holds its links to the folders
that are there, its own anchors and the project on GitHub;
[check_front_page.py](check_front_page.py) reads it in a browser, wide
and narrow, light and dark (the Web IDE workflow runs it beside the
Dictionary's check).
[check_site_rest.py](check_site_rest.py) holds the gallery, the Stack
Player's home, the bare player with no stack, the codebase map, and the
lessons' front page and a lesson to the front page's rule at rest:
nothing big moves without end unless it is pointed at, no frame is drawn,
and the browser keeps at most 10% of a core busy (pages.yml runs it on
the site it is about to deploy, as a warning;
[test_pages_at_rest.py](../ci/tests/test_pages_at_rest.py) holds the
pages without a browser).

The extensions page has a card for each xTalk Suite extension (sodiumxt,
torrentxt, enetxt, datachannelxt, box2dxt, coinxt, onionxt and nostrxt),
in the web stacks gallery's look, with its own repository and a link to
each of its `.lce` packages. The packages are the files that the suite's
`lce-packages.yml` attaches to a suite release, named
`<package>-<version>.lce`; pages.yml finds the suite's newest release
that has any and gives its file names to `build_pages.py`
(`--suite-release TAG --suite-assets FILE`), so the page links the files
of the newest packaged release each time the site is built. Only the
files the release has get a link; a package the page's table
(`EXTENSIONS` in `build_pages.py`) does not name is linked under "More
from the suite"; and without a release with packages each card links the
suite's releases page instead. After them come OXT-Beyond's own two
plugins, the xTalk Assistant and the xTalk MCP Bridge (`PLUGINS`), each
linked to its `.lce` in the release the front page's Downloads links
(`--release`), or to OXT-Beyond's releases without one. The page goes
up with every site, and the front page has its card. [test_pages_extensions.py](../ci/tests/test_pages_extensions.py)
holds it.

With a release (`--release TAG --release-assets FILE`, which pages.yml
gives: the release on the site, or the newest when the site has a test
build), the front page also has a Downloads section, as the forum posts
have: the Windows, macOS and Linux packages, the web zips and the
plugins, each linked straight to its file, with links to the release's
page, earlier releases and a bug report. A file the release does not
have gets no link.

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

## The lessons

The lessons are written here, in [lessons/src](lessons/src), a file a
lesson (`NN-<slug>.html`: a header of title, level, minutes, summary and
the words it teaches, then the lesson's HTML), and
[build_lessons.py](build_lessons.py) makes them into the site's
`lessons/`: a page a lesson in the site's look, with the lessons beside
it and the lesson's own sections, a front page of every lesson by level,
and a search of every section, which reads `search-index.js` and needs no
server. They go up with every site, and link the web IDE and the
Dictionary when the site has them. The build refuses a lesson out of
level order, an example without what its check needs, a picture that is
missing or that no example shows, and a link to a lesson or a place in
one that is not there.

Every example is checked on a real engine:
[lessons_check.py](../ci/lessons_check.py) runs each in the xTalk
Academy's own runner, as a reader runs it in the playground, with the
extensions, externals (the database commands) and `lc-compile` the IDE
has, and compares what it puts with the Output its page shows. An example
can say instead that it stops with an error (on which line), that it only
compiles (a dialog, a click, the internet), or that it is an xTalk
Builder module, which `lc-compile` compiles and the examples after it
load. An example whose page shows the stage (`data-shot`, with the
picture's words for a reader who cannot see it) has its card drawn by
the engine and compared with `lessons/shots/<id>.png`, at twice the
stage's size; on Linux the check points fontconfig at the checkout's
fonts, so that the picture does not depend on the machine.

The lessons about objects start where a beginner starts: the reader
builds a card with the Tools palette and the Property Inspector, from a
`<div class="build">` of numbered steps, and the xTalk that makes the
same card goes in its `<pre class="setup">`, which the page leaves out.
An example on that card (`data-card`) is lines for the Message Box
(`data-in="message"`), or a script for one of its objects (`data-script`:
`button "Go"`, `this card`, `this stack`) that the reader then clicks in
Run mode (`data-click`); `data-after` names the scripts the reader put in
before it. The check builds the card with messages locked, puts the
scripts in, makes the clicks as the engine does (a check box or radio
button changes first), and holds the example to what the Message Box
shows after each click. A widget is built the same way, but the check
cannot click one as a reader does, so an example sends a widget's message
from the Message Box instead.

The Extensions level teaches the extensions that come with OXT-Beyond:
the libraries, the widgets and the xTalk Suite. An example names the ones
it needs in `data-needs`: an extension by its id
(`com.livecode.library.qr`, `com.livecode.widget.switchbutton`), one of
the xTalk Suite's script libraries by its folder in the package (`coinxt`,
`onionxt`: [xtalk-extensions.json](../oxt/xtalk-extensions.json)), or an
external (`external:revxml`). The check loads each as the IDE does: a
compiled module with its code libraries and resources, from a folder
named with its version too, and a script library by sending it
`extensionInitialize`, with a stand-in for the standalone builder that
some call as they start. A widget's needs include the libraries it uses
(`com.livecode.library.iconsvg com.livecode.library.widgetutils`). The
levels are listed once, in `LEVELS` in build_lessons.py, which makes the
front page's filters from it.

```sh
python3 tools/pages/build_lessons.py --out /tmp/lessons      # the pages alone
python3 tools/ci/lessons_check.py --engine <OXT-Beyond>/oxt-beyond [--only <slug>|<example id>] [--update-shots]
```

`--update-shots` writes the engine's pictures as the page's (for a new
example, or a change you have looked at). The Linux build checks the
lessons with the engine it built (build-linux.yml, "Lessons check"), and
[lessons.yml](../../.github/workflows/lessons.yml) checks a change to
them with the latest release's engine, uploading the engine's pictures,
with what changed beside any that differs.
[test_pages_lessons.py](../ci/tests/test_pages_lessons.py) holds the
build, the example rules (the palette's among them), the code the check
runs on a card, the links and the picture comparison without an engine.

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
