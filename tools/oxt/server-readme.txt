OXT-Beyond Server {version} ({platform})
==========================================

The server engine of OXT-Beyond: it runs xTalk scripts on a web server,
as LiveCode Server did. A page is a file ending in .lc with xTalk
between <?lc and ?>, and everything outside those marks is sent as it
is. Scripts see the request in $_GET, $_POST, $_FILES, $_COOKIE and
$_SERVER, answer with "put header", "put cookie" and "put", share code
with "include" and "require", and keep state with "start session" and
$_SESSION, as in LiveCode Community 9.

Experimental: this zip is new in OXT-Beyond 0.2.7-rc.6.15. The engine
is the same code as LiveCode Community's server engine and has been
built by every OXT-Beyond release; what is new is this download.


What is in this zip
-------------------

  {engine}    the engine (the name LiveCode
                                       Community's server zip used)
  externals/                           revDB, revXML and revZip, which
                                       the engine loads when it starts
  drivers/                             revDB's database drivers: SQLite,
                                       MySQL, PostgreSQL and ODBC
  README.txt, LICENSE and the rest     this file and the licences

Keep the three together: the engine looks for externals/ next to
itself. A folder set up for LiveCode Community's server zip can take
these files in its place.


Setting it up with Apache
-------------------------

Unzip it into a folder that Apache may run programs from, for example
/usr/lib/cgi-bin/livecode-server (on Windows, C:\livecode-server). Make
sure the engine is executable (chmod 755 on Linux and macOS). Then turn
on mod_cgi (or mod_cgid) and mod_actions, and add to the site's
configuration:

    ScriptAlias /livecode-cgi/ /usr/lib/cgi-bin/livecode-server/
    <Directory /usr/lib/cgi-bin/livecode-server>
        Options +ExecCGI
        Require all granted
    </Directory>
    AddHandler livecode-script .lc
    Action livecode-script /livecode-cgi/{engine}

Restart Apache, put a file test.lc in the site with

    <?lc put "Hello from" && the version ?>

and open it in a browser.


Setting it up with IIS (Windows)
--------------------------------

Turn on the CGI feature of IIS. In IIS Manager, under Handler Mappings,
add a Script Map: request path *.lc, executable
C:\livecode-server\{engine} (with its full path), any name. Allow it
when IIS asks to add it to the ISAPI and CGI Restrictions.


Setting it up with nginx (Linux and macOS)
------------------------------------------

nginx runs no CGI programs itself; fcgiwrap can. It runs each page as a
program of its own, so give every .lc page a first line naming the
engine and make the page executable (chmod 755):

    #!/usr/lib/cgi-bin/livecode-server/{engine}
    <?lc put "Hello from" && the version ?>

and pass DOCUMENT_ROOT with the usual parameters (the engine stops
without a page when it is not set, as LiveCode's did):

    location ~ \.lc$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;
        fastcgi_pass unix:/run/fcgiwrap.socket;
    }

The same first line lets Apache run a page as a CGI program of its own,
without the Action above.


On the command line
-------------------

    {engine} script.lc [arguments]

runs a script without a web server, writing what it puts to standard
output and its errors to standard error.


Before putting it on the internet
---------------------------------

- Script errors are shown in the page by default, with the server's
  file paths. On a public site, set the errorMode to "quiet" (or
  "stderr", which goes to the web server's error log) at the top of
  each page or in an included file.
- Sessions are kept in the system's temporary folder, in files other
  users of the machine can read. On a shared server, set the
  sessionSavePath to a folder of the site's own, outside the web site,
  before "start session".
- Session cookies are HttpOnly, but not Secure: on an HTTPS-only site,
  set your own cookies with "put secure httponly cookie".
- Each request starts the engine anew; there is no FastCGI mode.
- HTTPS (url "https://...") and the database drivers' encrypted
  connections use OpenSSL 3, which needs TLS 1.2 or later. The MySQL
  driver's encrypted connections speak TLS 1.0 only and no longer work.


Differences from LiveCode Community 9.6.3's server
--------------------------------------------------

The same as for OXT-Beyond's desktop engine: "the version" is 9.7.1
with OXT-Beyond's suffix, text is compared and sorted with Unicode 17
(ICU 78), and secure connections need TLS 1.2 (OpenSSL 3). Scripts
written for LiveCode Community 9's server are otherwise meant to run
unchanged; please report any that do not at
https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/issues


Licence
-------

OXT-Beyond is free software under the GNU General Public License,
version 3 (LICENSE), with the permission in LICENSE-EXCEPTION.md. The
engine and drivers include third-party code listed in
THIRD-PARTY-NOTICES.md, whose licence texts are in
"Open Source Licenses.txt". The scripts you run with it are yours: the
GPL does not apply to them. LiveCode is a trademark of LiveCode Ltd;
OXT-Beyond is not made or endorsed by LiveCode Ltd.
