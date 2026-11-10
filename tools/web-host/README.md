# Self-hosting the web IDE and the Stack Player

The web IDE and the Stack Player are static files, so any web server can
serve them ([tools/web-ide](../web-ide/README.md),
[tools/web-player](../web-player/README.md)). This folder makes that
turn-key, in two tiers. Each adds to the one before, and neither changes
the release's files, the plain static site or the desktop IDE.

| Tier | What you do | What you get | Who it suits |
| --- | --- | --- | --- |
| 1. The web bundle | Unzip `OXT-Beyond-<version>-web-bundle.zip` onto any web host (cPanel, nginx, Caddy, GitHub Pages) | The IDE and the Player, with compressed copies made once, `.htaccess`, an nginx and a Caddy config and a Pages workflow; stacks kept in each browser | Schools and hobby sites on shared hosting |
| 2. The web host | `python3 oxt_web_host.py ...` or `docker run ...` on a small server, a NAS or a spare PC, behind Caddy for HTTPS | Tier 1, plus the stacks kept on the server (they follow you to any browser), a password, and the two origins set up for you | One person, or a class sharing one space |

**The IDE and the Player must not share an origin.** Both engines keep the
home folder in the browser's IndexedDB under the same name, so on one site
a stack opened in the Player could read and overwrite the stacks saved in
the IDE. Give each its own host name (`ide.example.org`,
`play.example.org`) or port. The web host does that by itself.

## Tier 1: the web bundle

Releases carry `OXT-Beyond-<version>-web-bundle.zip` beside the web IDE and
Player zips, from the release after 0.2.7 on. Its `README.txt` says how to
put it on shared hosting, nginx, Caddy or GitHub Pages. Inside:

```
OXT-Beyond-<version>-web-bundle/
  README.txt
  ide/                 the web IDE (the release's files) + .htaccess
  player/              the Stack Player (the release's files) + .htaccess
  apache/.htaccess     the same file, for reference
  nginx/nginx.conf, nginx/nginx-common.conf
  caddy/Caddyfile
  github-pages/pages.yml
```

Beside each big file (the engines, `ide.zip`, the Player's
`standalone.zip`, the pages) are its `.br` and `.gz` copies, made once
with Brotli at level 11 and gzip at level 9, so no host has to. A first
visit to the IDE is 59 MB plain, 38 MB in gzip and 32 MB in Brotli
(0.2.7). The configs hand each browser the best copy it accepts, with the
engine's type (`application/wasm`), and `Cache-Control: no-cache`, so a new
release is picked up at once. The page already counts its progress bar to
the sizes it was built with, so a compressed download does not throw it
off.

[make_bundle.py](make_bundle.py) makes it from the release's two zips:

```sh
python3 tools/web-host/make_bundle.py --ide OXT-Beyond-<v>-web-ide.zip \
    --player OXT-Beyond-<v>-web-player.zip --version <v> \
    --out OXT-Beyond-<v>-web-bundle.zip
```

It needs the `brotli` module (`pip install brotli`), or `--no-brotli` for
gzip copies only. The release workflow runs it in its publish job. The
templates it copies are in [bundle/](bundle).

## Tier 2: the web host

[oxt_web_host.py](oxt_web_host.py) serves the release's two zips as they
are. Python 3.8 or later and nothing else (the `brotli` module, when it is
installed, adds Brotli copies):

```sh
python3 oxt_web_host.py --ide OXT-Beyond-<v>-web-ide.zip \
    --player OXT-Beyond-<v>-web-player.zip [--password ...]
```

The IDE is then at `http://localhost:8000/` and the Player at
`http://localhost:8001/`. The first start unpacks the zips and makes the
compressed copies into `oxt-data/sites` (about three minutes with Brotli);
later starts reuse what has not changed. `--host 0.0.0.0` serves the
network, `--port` and `--player-port` choose the ports, `--data` the
folder, `--no-storage` keeps stacks in each browser only, as tier 1 does.

What it adds to tier 1:

- **The stacks are kept on the server.** The IDE's `~/Documents` is kept in
  `oxt-data/files` as well as in the browser, so a stack saved in one
  browser is there in any other. The page's half is [sync.js](sync.js),
  which the host adds to the IDE's `index.html` as it serves it: before
  the engine starts it brings in the server's newer files, and after each
  change the engine reports (`LiveCodeStorage.changed`, which the engine
  calls after every save) it sends what differs a second later. The
  browser's own copy stays, so with the server down the IDE works as it
  does on any static site. Neither the IDE nor the engine is changed.
- **A password.** `--password` (or `OXT_PASSWORD`) asks for it, with HTTP
  Basic, on the IDE and its storage. The Player gets none, and no storage:
  it runs any stack it is given, so it holds nothing worth taking.
- **Writes only from the IDE's own page.** A write from any other origin
  (the Player's among them) is refused, paths cannot leave the files
  folder, and an upload is limited to 200 MB.
- `ETag` and 304s on repeat visits, `nosniff`, `SAMEORIGIN` and
  `no-referrer` headers, and `/_host/health` for a container's health
  check.

### Docker

```sh
docker build --build-arg OXT_VERSION=0.2.7 -t oxt-beyond-web tools/web-host
docker run -d -p 8000:8000 -p 8001:8001 -v oxt-data:/data \
    -e OXT_PASSWORD=... oxt-beyond-web
```

The image downloads the release's two zips and prepares them while it is
built, so a container starts in about a second; stacks live in the `/data`
volume. It runs as a user of its own, not root.

### On the internet

Basic auth sends the password in the clear, so put HTTPS in front before
the host faces the internet. [compose.yaml](compose.yaml) runs it with
Caddy, which gets the certificates itself; edit the two host names in
[Caddyfile](Caddyfile) first:

```sh
OXT_VERSION=0.2.7 OXT_PASSWORD=... docker compose up -d
```

Behind another proxy (nginx, a tunnel), pass the `Host` header through
unchanged: the host compares it with the page's `Origin` before it takes
a write.

### Limits

- **Newest wins, per file.** Two browsers changing the same stack at once
  keep the later save. Fine for one person; a class sharing one space
  should save to their own file names.
- **One space per server.** Everyone with the password sees the same
  `~/Documents`.
- **Only `~/Documents` follows the user.** The IDE's preferences and the
  Player's library stay in each browser.
- **A stack is a program.** The IDE's origin runs the user's own stacks,
  which can reach the storage as the IDE can; opening a stranger's stack in
  the IDE is the same trust step as on the desktop.
- The IDE's note on its first visit still says stacks are kept in the
  browser: they are, and on the server too.

## Licence

OXT-Beyond is under the GNU GPL version 3, and serving the engine is
distributing it: link your site to the source of the release you serve
(the bundle's README names it).

## Checks

- `tools/ci/tests/test_web_host.py` (CI checks, on every pull request):
  the host and the bundle on made-up release files, with no browser:
  preparing (zips, parts, a new release over an old one), the compressed
  copies, which copy each `Accept-Encoding` gets, 304s, the storage API,
  the password, writes from other origins, paths that would leave the
  site, the bundle's contents, and what `sync.js` counts on in
  `engine/src/em-system.js` and `tools/web-ide/index.html`, so a rename
  there fails here and not silently in a user's browser.
- `.github/workflows/web-host.yml` (on a pull request that changes this
  folder, and by hand): the newest release's real zips, the host and the
  bundle under Apache and nginx, opened in headless Chromium by
  [e2e_check.py](e2e_check.py): a stack saved in one browser reaches the
  server and a fresh browser, a delete reaches both, and the Player opens
  on its own origin. It also builds the Docker image and checks that its
  container answers.
