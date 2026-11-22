# The welcome pages: OXT-Beyond for people coming from LiveCode

Four pages of the GitHub Pages site, at
<https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/welcome/>, for
people who use LiveCode. They say there is another road for their stacks,
let them check a stack in the browser, explain the GPL for in-house tools,
and guide them across. `tools/pages/build_pages.py` copies this folder to
the site's `welcome/` with every site it builds, without `src/`, `tests/`
and this README.

## Look at it

The pages show the site's own logo (`../brand/`, which is
[tools/pages/brand](../brand)), so serve `tools/pages` and open
`welcome/`:

```sh
python3 -m http.server 8000 --directory tools/pages
```

then <http://localhost:8000/welcome/>. Plain HTML, CSS and JavaScript: no
framework, nothing to build before serving it, and no request outside the
site. Every font, picture and script is in this folder. Opening a page
straight from the disk works too, checker included, but a browser then
won't load the bundled fonts, or the logo from `../brand/` unless the
folder is in its place in `tools/pages`.

## The pages

| Page | What it is for |
| --- | --- |
| `index.html` | The front page: "There's another road for your stacks." A stack window that reads a stack dropped on it, four numbers, the stack checker with a sample report and three more ways to try OXT-Beyond, every stack format it opens, what is in it (each with the release it arrived in), the Stack Player, what it isn't yet, the 3D work in the preview, and the downloads, always the stable release and the preview side by side, with this computer's files marked. |
| `check.html` | The stack checker. Drop a stack, a script-only stack, a HyperCard stack or a `.zip` of them: it reports the format and the LiveCode that saved it, the widgets, the libraries its scripts call, the platforms it was set up for, passwords and damage, then what to do next. Two of LiveCode Community's sample stacks are there to try. Nothing is uploaded, and nothing in the stack runs. |
| `in-house.html` | "Free for your in-house tools": the GPL in plain words, a "Who will get a copy?" helper with seven cases (each quotes the licence and links where it comes from), three example tools, E2NB, where OXT-Beyond doesn't fit, where to ask a lawyer, and the sources. It says it is not legal advice. |
| `guide.html` | Coming from LiveCode: five steps to try it, what opens, where its files live beside LiveCode, where each library went (tsNet, mergJSON, revDB, the browser widget and more), what is different, where every feature stands (Ready today, In the preview, Experimental, Not available, Not tested yet, with a filter for each), where OXT-Beyond comes from, and how to report a stack that doesn't open. A bar under the top one follows the reader through the page. |

## How it is made

- `src/build.py` writes the four pages from `src/pages/*.html` (a
  page's own script, if it has one, in `src/pages/<page>.tail`), putting
  in what every page shares: the head with its link-preview tags, the bar
  at the top, the sky and the footer. Edit the page in `src/pages/` or
  the shared part in `build.py`, never the page it writes, then run
  `python3 -I tools/pages/welcome/src/build.py` and commit both.
  `--check` says which pages differ from what it would write.
- `assets/site.css`: the look, the OXT-Beyond website's own (the night
  sky over a planet whose rim is lit orange, the road, the fire-rim
  cards), with status pills, a feature grid, and tables that turn into
  labelled cards on a phone. Colours are tokens on `:root`, with a dark
  set used when the system is dark or the theme button says so (kept in
  `localStorage` as `oxtb-theme`). Things move as they scroll in, on
  hover, focus or a click, and not at all for someone who asks for
  reduced motion; nothing moves without end at rest, the site's rule.
- `assets/fonts/`: Bricolage Grotesque (headings), Inter (text) and
  JetBrains Mono (code), the Latin subsets of the variable fonts in
  Fontsource's 5.3.0 packages, each under the SIL Open Font License,
  whose text is beside it.
- `assets/site.js`: the theme button, the top bar, its reading line and
  the phone menu, things rising into place as they scroll in, the light
  that follows the pointer over cards, the clips that play on hover or
  tap, the guide's section bar and status filters, marking the downloads
  for this computer, and the front page's stack window.
- `assets/stackcheck.js`: the stack reader. It reads a file's bytes the
  way the engine's loader does and stops before anything could run. The
  comments at its top name the engine source each part follows
  (`stack3.cpp`, `object.cpp`, `widget.cpp`, `objectpropsets.cpp` and
  others).
  `assets/check-ui.js` draws its reports, and `assets/sample-stacks.js`
  holds LiveCode Community's Book Library and Balls sample stacks
  (GPLv3) for its Try buttons.
- `media/`: the three 3D clips, made from the xTalk Suite's demo GIFs
  with a poster frame each, and pictures of the Stack Player, the web
  IDE, the IDE's Home window (`.github/images/home-*.png`), the xTalk
  Academy (`.github/images/academy.png`) and E2NB.

## Link previews

Each page names its one address (`rel=canonical` and `og:url`, so
`tools/pages/seo.py` adds none) and has the Open Graph and X tags that
chat apps and social sites read to draw a card when its address is
shared: a title, a description, and a picture of its own in `share/`,
1200 by 630 (the size Facebook, LinkedIn, X, Mastodon, Discord and Slack
show large), each under 300 KB (WhatsApp shows none bigger), with alt
text. `src/build.py` writes the tags (`BASE`, and `share` and
`share_alt` for each page in `PAGES`).

The pictures are drawn in the pages' look from `src/share.html`, one
card a page, each with the page's own headline. After changing a card,
draw them again and commit them:

```sh
node tools/pages/welcome/src/share.js
```

It needs Node and Playwright with its Chromium. A site caches a card
when it first sees an address, so a new picture shows in a site's cards
only once it looks again (Facebook's Sharing Debugger and LinkedIn's
Post Inspector ask it to).

## Tests

[test_pages_welcome.py](../../ci/tests/test_pages_welcome.py), in CI
with the other tests of `tools/ci/tests`, holds the section: the pages
are what `src/build.py` writes; every file they name is there; they ask
no other host for anything; each has its link-preview tags, naming its
address and a picture of the right size that is there; `seo.py` adds
nothing to them; nothing moves without end at rest; the site gets the
pages without the tools; git keeps every file of the section; the
checker's report names the releases the downloads offer; and, with Node,
the checker gives each file in `tests/files` and both samples the verdict
it should, reads the platforms ticked in their Standalone Settings as
OXT-Beyond's engine does, and finds a script's calls however they are
capitalized, without taking English words for them:

```sh
node tools/pages/welcome/tests/run.js                 # every test file
node tools/pages/welcome/tests/run.js some.livecode   # the report for a file
```

The repository's `.gitignore` leaves out every `.zip`, so a new `.zip`
in `tests/files` goes in with `git add -f`, as the games'
`standalone.zip` files do (and every folder named `build/`, which is why
the builder is in `src/`).

[check_site_rest.py](../check_site_rest.py) holds the front page at
rest in a browser, as it does the site's other pages (pages.yml runs it
on the site it is about to deploy).

## Keeping it current

The pages are written by hand, and every fact on them names its release
or its date. With each release:

1. **Downloads.** The front page's Downloads link the files of v0.2.7
   (stable) and v0.2.8-dp.2.1 (preview), with their sizes as GitHub's
   release page gives them (MB and GB of 1,024). Point both at
   the new releases, and keep offering both. The checker's report names
   them too (`STABLE` and `PREVIEW` in `assets/stackcheck.js`, which a
   test holds to the downloads).
2. **Where everything stands.** The guide's board is the one list to move
   a feature along as it changes (Preview to Ready when 0.2.8 is stable,
   for instance), with the release named on each.
3. **Not tested yet:** stacks from LiveCode 10 and 11, and round trips
   back to LiveCode. The pages and the checker say so; change them when
   that is tested.
4. **The 3D clips** show box3dxt and render3dxt, in the preview since
   0.2.8-dp.2.1. Their chips say so; move them to the stable release's
   when 0.2.8 is stable.
5. **Dates.** The footers and the page comments say "as of 21 November
   2026"; change them with the facts.

And always:

- **LiveCode** is named only to say who the pages are for, with the
  trademark line in every footer, and no LiveCode logo. LiveCode's
  commercial licence is named only as the way to make a closed app. No
  prices, and no comparison with LiveCode's own products.
- **The in-house page** quotes the GPLv3 as OXT-Beyond ships it and the
  FSF's GPL FAQ, says it is not legal advice, and says where to ask a
  lawyer. Keep its quotations the licence's own words.

## Where the facts come from

Every feature claim is dated to a release. The ones most likely to
change:

| Claim | Source |
| --- | --- |
| Stable 0.2.7 of 10 November 2026; preview 0.2.8-dp.2.1 of 21 November; file sizes | The GitHub releases; `CHANGELOG.md` |
| The browser widget and revBrowser on Chromium 156 on Windows and Linux x86-64 in 0.2.8-dp.2 (Chromium 74 before; the Mac's unchanged; none on 64-bit ARM Linux) | `CHANGELOG.md` 0.2.8-dp.2; `README.md` |
| tsNetCompat (dp.2); WebSockets on the web, MySQL 8.4 and SCRAM logins, Beyond's engine for new Android stacks (dp.1) | `CHANGELOG.md` |
| Its own folders for preferences, caches and logs; the engine's licence file in `%APPDATA%\RunRev\Licenses` | `README.md`, "Where OXT-Beyond keeps your files" |
| Never downloads or installs an update itself | `README.md`, "Updates" |
| Stack formats and which LiveCode saved each | `docs/glossary/s/stack-version.lcdoc`; `save stack ... with format` from `docs/dictionary/command/save.lcdoc` |
| A widget whose extension is missing opens as a placeholder and keeps its settings | `engine/src/widget.cpp` (`MCWidget::draw`, `MCWidget::save`) |
| Password-protected stacks don't open, as in LiveCode Community | `engine/src/stack3.cpp` ("Encrypted stacks cannot be opened in Community Edition") |
| About 1,800 scripts compared on the old and new externals | `README.md` (the revXML, XSLT and revZip update) |
| Web IDE first visit about 62 MB; 74 lessons in Learn; Android target API 36 | `README.md`; `CHANGELOG.md` |
| Where OXT-Beyond comes from: Terry Little began OpenXTalk Lite, Tom Perry built it from 0.91 to 1.15 | `README.md`, "Where OXT-Beyond comes from" and "Credits" |
| The ATL and OpenSSL exception, and which parts carry it | `LICENSE-EXCEPTION.md` |
| Box3D is Erin Catto's 3D engine, the successor of Box2D | the xTalk Suite's `box3dxt/README.md` |
| box3dxt, render3dxt, audioxt, xlsxt, gamepadxt, webpxt and barcodext built in, in 0.2.8-dp.2.1; Render3D Tour a Stack Player sample | `CHANGELOG.md` 0.2.8-dp.2.1 |
| LiveCode 11's kinds of array and `as`; SQLite's math functions and REGEXP in every connection (0.2.8-dp.2.1) | `CHANGELOG.md` 0.2.8-dp.2.1 |
| The xTalk Suite's extensions and what each binds: libsodium, libtorrent, ENet, libdatachannel, Box2D v3, trezor-crypto and libsecp256k1; Tor and Nostr in plain script | the xTalk Suite's `README.md`, the table of members |
| Quotations of the GPLv3 | `LICENSE` in this repository, the same text as gnu.org |
