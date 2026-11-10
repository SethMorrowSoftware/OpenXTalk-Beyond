OXT-Beyond @VERSION@: the web bundle
====================================

The OXT-Beyond web IDE (ide/) and the Stack Player (player/), ready to put
on your own web site. Nothing here needs installing: these are the files a
browser downloads, with compressed copies made once for the release and
the settings the common web servers need.

  ide/       the web IDE: the OXT-Beyond IDE in a web page
  player/    the Stack Player: opens any stack in a browser
  apache/    .htaccess, which ide/ and player/ already carry
  nginx/     nginx.conf and nginx-common.conf
  caddy/     Caddyfile (Caddy gets the HTTPS certificates itself)
  github-pages/pages.yml   a workflow that publishes a folder with Pages

Two host names, one for each
----------------------------

Put ide/ and player/ on two different host names, for example
ide.example.org and play.example.org (or two ports). Both keep their
files in the browser under the same name, so on one origin a stack opened
in the Player could read and overwrite the stacks saved in the IDE.

Shared hosting (cPanel and the like)
------------------------------------

Make two subdomains, upload the files of ide/ into one's folder and those
of player/ into the other's (the hidden .htaccess file included: it sets
the engine's type and hands browsers the compressed copies). Open the
subdomains in a browser.

nginx, Caddy
------------

Copy ide/ and player/ to the server, and use nginx/nginx.conf or
caddy/Caddyfile, with your host names and folders.

GitHub Pages
------------

See the comments at the top of github-pages/pages.yml: one repository for
each folder, each with its own custom domain.

What it keeps, and where
------------------------

Stacks made in the web IDE are kept in the browser that made them
(File > Download Stack gives you a copy). To keep them on your server, so
that they follow you to any browser, run the web host instead, which
serves these same files (tier 2: tools/web-host/README.md in the source):

  python3 oxt_web_host.py --ide OXT-Beyond-@VERSION@-web-ide.zip \
      --player OXT-Beyond-@VERSION@-web-player.zip --password ...

Updating
--------

Replace the folders' files with the next release's. Every file is
checked again on each visit (Cache-Control: no-cache), and the page asks
for the engine by a stamp of its contents, so nobody gets an old copy.

Licence
-------

OXT-Beyond is free software under the GNU General Public License version 3.
Serving it is distributing it: link your site to the source,
@SOURCE@
