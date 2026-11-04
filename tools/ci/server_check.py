#!/usr/bin/env python3
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

"""Check a server zip (tools/oxt/package_server.py) as a web server uses it:
the engine runs pages as a CGI program, and what LiveCode Community's
server scripts rely on gives the results it gave there.

  python3 tools/ci/server_check.py --zip FILE [--platform P]
      [--apache auto|yes|no] [--work DIR] [--log FILE] [--repo DIR]

The zip is extracted to a neutral folder (--work, default a temporary
one), with the Unix modes it stores, and its layout checked: the engine,
externals/ (revdb, revxml, revzip), drivers/ (dbsqlite, dbmysql,
dbpostgresql, dbodbc), README.txt and the licence files. Then the pages
of PAGES are written to a site folder and each case of CASES requested:

  cgi     the engine started as a CGI program, as Apache's mod_cgi or IIS
          start it: the request in the environment (GATEWAY_INTERFACE,
          REQUEST_METHOD, QUERY_STRING, CONTENT_TYPE, CONTENT_LENGTH,
          HTTP_COOKIE, DOCUMENT_ROOT, PATH_TRANSLATED, SCRIPT_FILENAME...)
          and the body on standard input; every platform
  apache  the same cases through a real Apache httpd (a configuration of
          its own on a free local port, mod_cgi and mod_actions, the
          "AddHandler livecode-script .lc" and "Action" lines of the zip's
          README), when one is installed (apache2 or httpd, with its
          modules where Debian, Ubuntu or Fedora keep them); --apache yes
          fails when there is none, auto skips it

A case is a request (method, query, form or multipart body, cookies) and
the checks on the answer: the status, headers and body. They cover the
page syntax (<?lc ?> blocks and literal text), $_GET, $_GET_RAW, $_POST,
$_POST_RAW, $_FILES with the uploaded file's contents, $_COOKIE,
$_SERVER, put header, put new header, a "Status:" header, put cookie
with its attributes, include and require, start session and $_SESSION
over two requests, the outputTextEncoding, the errorMode (a script error
shown in the page, then hidden), and revDB with SQLite, revXML and revZip
loaded from externals/ and drivers/. On Linux and macOS a page that names
the engine on its first line ("#!") is also run as a program of its own,
as fcgiwrap and Apache's ExecCGI do. On the command line it checks the
version, the $# and $0... variables, errors on standard error and quit's
exit status.

The results these pin are the engine's as it was when the checks were
written, which is LiveCode Community's: a change that alters one is a
change for every server script that relies on it (CONTRIBUTING.md,
"Keeping old stacks working").

Each result is logged (PASS/FAIL with what was wanted and what came);
the exit status is the number of failed checks (at most 100), or 101
when the zip could not be checked at all. Under GitHub Actions every
failure is an ::error:: annotation and a table goes to the job summary.

Only the Python 3 standard library is used.
"""

import argparse
import collections
import os
import re
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
import package_server  # noqa: E402

TIMEOUT = 60
GHA = os.environ.get('GITHUB_ACTIONS') == 'true'

# The pages of the site. {sessions} is replaced by the session folder.
PAGES = collections.OrderedDict([
    ('hello.lc', 'before <?lc put "hello" && the version ?> after <?lc put 6 * 7 ?>.\n'),
    ('get.lc', '<?lc\n'
               'put "name=" & $_GET["name"] & ";" & return\n'
               'put "two=" & $_GET["two"] & ";" & return\n'
               'put "keys=" & the number of lines of the keys of $_GET & ";" & return\n'
               'put "raw=" & $_GET_RAW & ";" & return\n'
               'put "method=" & $_SERVER["REQUEST_METHOD"] & ";" & return\n'
               'put "query=" & $_SERVER["QUERY_STRING"] & ";" & return\n'
               'put "root=" & ($_SERVER["DOCUMENT_ROOT"] is not empty) & ";" & return\n'
               '?>'),
    ('post.lc', '<?lc\n'
                'put "a=" & $_POST["a"] & ";" & return\n'
                'put "b=" & $_POST["b"] & ";" & return\n'
                'put "raw=" & $_POST_RAW & ";" & return\n'
                'put "method=" & $_SERVER["REQUEST_METHOD"] & ";" & return\n'
                '?>'),
    ('upload.lc', '<?lc\n'
                  'put "field=" & $_POST["note"] & ";" & return\n'
                  'put "name=" & $_FILES["doc"]["name"] & ";" & return\n'
                  'put "type=" & $_FILES["doc"]["type"] & ";" & return\n'
                  'put "size=" & $_FILES["doc"]["size"] & ";" & return\n'
                  'put "error=" & $_FILES["doc"]["error"] & ";" & return\n'
                  'put "exists=" & (there is a file $_FILES["doc"]["filename"]) & ";" & return\n'
                  'put "data=" & url ("binfile:" & $_FILES["doc"]["filename"]) & ";" & return\n'
                  '?>'),
    ('headers.lc', '<?lc\n'
                   'put header "Content-Type: text/plain; charset=utf-8"\n'
                   'put new header "X-OXT-Check: one"\n'
                   'put new header "X-OXT-Check-Two: two"\n'
                   'put secure httponly cookie "flavour" for "/" with "ginger"\n'
                   'put cookie "plain" with "yes"\n'
                   'put "cookie=" & $_COOKIE["incoming"] & ";" & return\n'
                   '?>'),
    ('status.lc', '<?lc\nput header "Status: 404 Not Found"\nput "gone"\n?>'),
    ('inc.lc', '<?lc\nfunction oxtGreet pWho\n  return "hello" && pWho\nend oxtGreet\n?>'),
    ('include.lc', '<?lc\ninclude "inc.lc"\nput oxtGreet("include") & ";" & return\n?>'),
    ('lib.lc', '<?lc\nfunction oxtLib pWho\n  return "from the library to" && pWho\nend oxtLib\n?>'),
    # require loads a file once however often it is asked: the second
    # require of lib.lc used to crash the engine (srvscript.cpp, Include)
    ('require.lc', '<?lc\nrequire "lib.lc"\nput oxtLib("one") & ";" & return\n'
                   'require "lib.lc"\nput oxtLib("two") & ";" & return\n?>'),
    ('session.lc', '<?lc\n'
                   'set the sessionSavePath to "{sessions}"\n'
                   'start session\n'
                   'add 1 to $_SESSION["count"]\n'
                   'put "count=" & $_SESSION["count"] & ";" & return\n'
                   'put "id=" & (the sessionID is not empty) & ";" & return\n'
                   'stop session\n'
                   '?>'),
    ('utf8.lc', '<?lc\nput header "Content-Type: text/plain; charset=utf-8"\n'
                'set the outputTextEncoding to "utf-8"\n'
                'put "caf" & numToCodepoint(233) & " " & numToCodepoint(0x263A)\n?>'),
    ('error.lc', '<?lc\nput "before;"\nput 1 / 0\n?>'),
    ('quiet.lc', '<?lc\nset the errorMode to "quiet"\nput "before;"\nput 1 / 0\n?>'),
    ('externals.lc', '<?lc\n'
                     'local tDb, tTree, tZip, tData\n'
                     'put revOpenDatabase("sqlite", ":memory:") into tDb\n'
                     'put "db=" & (tDb is an integer) & ";" & return\n'
                     'revExecuteSQL tDb, "create table t (x integer, y text)"\n'
                     'revExecuteSQL tDb, "insert into t values (42, ' "'forty-two'" ')"\n'
                     'put "query=" & revDataFromQuery(",", return, tDb, "select x, y from t") & ";" & return\n'
                     'revCloseDatabase tDb\n'
                     'put revXMLCreateTree("<a><b>xml</b></a>", false, true, false) into tTree\n'
                     'put "xml=" & revXMLNodeContents(tTree, "/a/b") & ";" & return\n'
                     'revXMLDeleteTree tTree\n'
                     'put "{sessions}/check.zip" into tZip\n'
                     'revZipOpenArchive tZip, "write"\n'
                     'put "zipped" into tData\n'
                     'revZipAddItemWithData tZip, "inside.txt", "tData"\n'
                     'revZipCloseArchive tZip\n'
                     'revZipOpenArchive tZip, "read"\n'
                     'put "zip=" & revZipEnumerateItems(tZip) & ";" & return\n'
                     'revZipCloseArchive tZip\n'
                     'delete file tZip\n'
                     '?>'),
])

Request = collections.namedtuple('Request', 'page method query body content_type cookie')


def request(page, method='GET', query='', body=b'', content_type='', cookie=''):
    return Request(page, method, query, body, content_type, cookie)


def multipart(fields, files):
    boundary = '----oxtcheck' + uuid.uuid4().hex
    out = b''
    for name, value in fields:
        out += ('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n'
                % (boundary, name, value)).encode()
    for name, filename, ctype, data in files:
        out += ('--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\n'
                'Content-Type: %s\r\n\r\n' % (boundary, name, filename, ctype)).encode() + data + b'\r\n'
    out += ('--%s--\r\n' % boundary).encode()
    return out, 'multipart/form-data; boundary=%s' % boundary


UPLOAD_BODY, UPLOAD_TYPE = multipart([('note', 'a note')],
                                     [('doc', 'report.txt', 'text/plain', b'uploaded\x00bytes')])

# (name, request, checks): a check is (what, function(response) -> value,
# wanted); a response has status, headers ([(name, value)]) and body
# (bytes). Results LiveCode Community's server gave; see the docstring.
CASES = [
    ('page syntax', request('hello.lc'), [
        ('body', lambda r: r.body_text(), re.compile(r'^before hello 9\.\d+\.\d+\S* after 42\.\s*$')),
        ('content type', lambda r: r.header('Content-Type'), re.compile(r'^text/html')),
        ('status', lambda r: r.status, 200)]),
    ('$_GET', request('get.lc', query='name=a%20b+c&two=2&two=3&flag'), [
        ('name', lambda r: r.field('name'), 'a b c'),
        ('two', lambda r: r.field('two'), '3'),
        ('keys', lambda r: r.field('keys'), '3'),
        ('raw', lambda r: r.field('raw'), 'name=a%20b+c&two=2&two=3&flag'),
        ('method', lambda r: r.field('method'), 'GET'),
        ('query', lambda r: r.field('query'), 'name=a%20b+c&two=2&two=3&flag'),
        ('document root', lambda r: r.field('root'), 'true')]),
    ('$_POST', request('post.lc', method='POST', body=b'a=b%20c&b=%C3%A9',
                       content_type='application/x-www-form-urlencoded'), [
        ('a', lambda r: r.field('a'), 'b c'),
        ('b (bytes, not decoded)', lambda r: r.field_bytes('b'), b'\xc3\xa9'),
        ('raw', lambda r: r.field('raw'), 'a=b%20c&b=%C3%A9'),
        ('method', lambda r: r.field('method'), 'POST')]),
    ('$_FILES', request('upload.lc', method='POST', body=UPLOAD_BODY, content_type=UPLOAD_TYPE), [
        ('field', lambda r: r.field('field'), 'a note'),
        ('name', lambda r: r.field('name'), 'report.txt'),
        ('type', lambda r: r.field('type'), 'text/plain'),
        ('size', lambda r: r.field('size'), '14'),
        ('error', lambda r: r.field('error'), ''),
        ('temporary file', lambda r: r.field('exists'), 'true'),
        ('contents', lambda r: r.field_bytes('data'), b'uploaded\x00bytes')]),
    ('headers and cookies', request('headers.lc', cookie='incoming=from%20browser; other=1'), [
        ('content type', lambda r: r.header('Content-Type'), 'text/plain; charset=utf-8'),
        ('new header', lambda r: r.header('X-OXT-Check'), 'one'),
        ('second new header', lambda r: r.header('X-OXT-Check-Two'), 'two'),
        ('cookie in', lambda r: r.field('cookie'), 'from browser'),
        ('secure cookie', lambda r: r.cookie('flavour'), re.compile(
            r'^flavour=ginger;.*Path=/;.*Secure; HttpOnly$')),
        ('plain cookie', lambda r: r.cookie('plain'), re.compile(r'^plain=yes(;|$)'))]),
    ('Status header', request('status.lc'), [
        ('status', lambda r: r.status, 404),
        ('body', lambda r: r.body_text().strip(), 'gone')]),
    ('include', request('include.lc'), [
        ('a handler of the included file', lambda r: r.body_text().strip(), 'hello include;')]),
    ('require twice', request('require.lc'), [
        ('the page ran to its end', lambda r: r.body_text().split(), ['from', 'the', 'library', 'to', 'one;',
                                                                   'from', 'the', 'library', 'to', 'two;'])]),
    ('outputTextEncoding', request('utf8.lc'), [
        ('bytes', lambda r: r.body.strip(), 'café ☺'.encode('utf-8'))]),
    ('script error shown', request('error.lc'), [
        ('status', lambda r: r.status, 200),
        ('output before the error', lambda r: r.body_text().startswith('before;'), True),
        ('error in the page', lambda r: 'divide by zero' in r.body_text(), True),
        ('the page named', lambda r: 'error.lc' in r.body_text(), True)]),
    ('errorMode quiet', request('quiet.lc'), [
        ('no error in the page', lambda r: 'divide by zero' in r.body_text(), False),
        ('output before the error', lambda r: r.body_text().startswith('before;'), True)]),
    ('externals and drivers', request('externals.lc'), [
        ('revDB with SQLite', lambda r: r.field('db'), 'true'),
        ('query', lambda r: r.field('query'), '42,forty-two'),
        ('revXML', lambda r: r.field('xml'), 'xml'),
        # The engine writes the return after the item as its platform's
        # line end (see field_bytes): what is checked is one item, then
        # one line end.
        ('revZip (one line per item)', lambda r: line_ends((r.field('zip') or '')), 'inside.txt\n')]),
]


def line_ends(text):
    """Text with every line end, CR LF, CR or LF, written as LF."""
    return text.replace('\r\n', '\n').replace('\r', '\n')


class Response(object):
    def __init__(self, status, headers, body):
        self.status, self.headers, self.body = status, headers, body

    def header(self, name):
        for k, v in self.headers:
            if k.lower() == name.lower():
                return v
        return None

    def cookie(self, name):
        for k, v in self.headers:
            if k.lower() == 'set-cookie' and v.startswith(name + '='):
                return v
        return None

    def body_text(self):
        return self.body.decode('latin-1')

    def field_bytes(self, name):
        """The bytes between "name=" and ";" on a line of the body. A
        line ends as the engine writes "return" on its platform: LF on
        Linux, CR LF on Windows and CR on macOS (as LiveCode's server
        engines did), so all three end a line here."""
        m = re.search(rb'(?:^|(?<=[\r\n]))' + re.escape(name.encode()) + rb'=(.*?);(?=[\r\n]|$)', self.body, re.S)
        return m.group(1) if m else None

    def field(self, name):
        v = self.field_bytes(name)
        return None if v is None else v.decode('latin-1')

    def describe(self):
        head = ', '.join('%s: %s' % h for h in self.headers)
        return 'status %s; headers %s; body %r' % (self.status, head, self.body[:400])


def parse_cgi(out):
    """A CGI program's output: headers, a blank line, the body."""
    m = re.search(rb'\r?\n\r?\n', out)
    if not m:
        return Response(None, [], out)
    headers = []
    for line in re.split(rb'\r?\n', out[:m.start()]):
        if b':' in line:
            k, v = line.split(b':', 1)
            headers.append((k.decode('latin-1').strip(), v.decode('latin-1').strip()))
    status = 200
    for k, v in headers:
        if k.lower() == 'status':
            status = int(v.split()[0])
    return Response(status, headers, out[m.end():])


def base_env():
    """What a web server passes on besides the request: the system's
    variables a program needs to start (Windows needs SYSTEMROOT)."""
    keep = ('PATH', 'SYSTEMROOT', 'SystemRoot', 'TEMP', 'TMP', 'TMPDIR', 'WINDIR', 'COMSPEC', 'LANG')
    return {k: os.environ[k] for k in keep if k in os.environ}


class CgiTransport(object):
    name = 'cgi'

    def __init__(self, engine, www):
        self.engine, self.www = engine, www

    def send(self, req):
        page = os.path.join(self.www, req.page)
        env = base_env()
        env.update({
            'GATEWAY_INTERFACE': 'CGI/1.1', 'SERVER_PROTOCOL': 'HTTP/1.1', 'SERVER_SOFTWARE': 'server_check.py',
            'SERVER_NAME': 'localhost', 'SERVER_PORT': '80', 'REMOTE_ADDR': '127.0.0.1',
            'REQUEST_METHOD': req.method, 'QUERY_STRING': req.query,
            'REQUEST_URI': '/' + req.page + ('?' + req.query if req.query else ''),
            'SCRIPT_NAME': '/livecode-cgi/' + os.path.basename(self.engine), 'PATH_INFO': '/' + req.page,
            'PATH_TRANSLATED': page, 'SCRIPT_FILENAME': page, 'DOCUMENT_ROOT': self.www,
            'HTTP_HOST': 'localhost', 'REDIRECT_STATUS': '200'})
        if req.body:
            env['CONTENT_LENGTH'] = str(len(req.body))
            env['CONTENT_TYPE'] = req.content_type
        if req.cookie:
            env['HTTP_COOKIE'] = req.cookie
        return run_cgi([self.engine], env, req.body, self.www)


def run_cgi(argv, env, body, cwd):
    p = subprocess.run(argv, input=body, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       env=env, cwd=cwd, timeout=TIMEOUT)
    r = parse_cgi(p.stdout)
    r.returncode, r.stderr = p.returncode, p.stderr
    return r


APACHE_MODULE_DIRS = ('/usr/lib/apache2/modules', '/usr/lib64/httpd/modules', '/usr/lib/httpd/modules',
                      '/usr/libexec/apache2', '/opt/homebrew/lib/httpd/modules', '/usr/local/lib/httpd/modules')
APACHE_MODULES = ('mpm_prefork', 'authz_core', 'mime', 'alias', 'cgi', 'actions', 'unixd', 'log_config')


def find_apache():
    """(httpd program, modules folder) or None."""
    for exe in ('apache2', 'httpd'):
        path = shutil.which(exe) or next((p for p in ('/usr/sbin/' + exe,) if os.path.isfile(p)), None)
        if not path:
            continue
        for d in APACHE_MODULE_DIRS:
            if os.path.isfile(os.path.join(d, 'mod_cgi.so')) and os.path.isfile(os.path.join(d, 'mod_actions.so')):
                return path, d
    return None


def free_port():
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    port = s.getsockname()[1]
    s.close()
    return port


class ApacheTransport(object):
    """A throw-away Apache with the configuration the zip's README gives."""
    name = 'apache'

    def __init__(self, httpd, modules, server_dir, www, work, log):
        self.httpd, self.www, self.log = httpd, www, log
        self.root = os.path.join(work, 'apache')
        os.makedirs(self.root, exist_ok=True)
        self.port = free_port()
        loads = []
        for m in APACHE_MODULES:
            path = os.path.join(modules, 'mod_%s.so' % m)
            if os.path.isfile(path):
                loads.append('LoadModule %s_module "%s"' % (m, path))
            elif m not in ('unixd', 'log_config'):
                raise CheckError('Apache has no mod_%s in %s' % (m, modules))
        user = ''
        if hasattr(os, 'geteuid') and os.geteuid() == 0:
            # Apache refuses to serve as root; the site must be readable
            user = 'User nobody\nGroup %s\n' % ('nogroup' if _group_exists('nogroup') else 'nobody')
        self.conf = os.path.join(self.root, 'httpd.conf')
        with open(self.conf, 'w') as f:
            f.write('\n'.join(loads) + '\n' + user + '''
ServerRoot "{root}"
ServerName localhost
Listen 127.0.0.1:{port}
PidFile "{root}/httpd.pid"
ErrorLog "{root}/error.log"
DocumentRoot "{www}"
TypesConfig /dev/null
<Directory />
    AllowOverride None
    Require all denied
</Directory>
ScriptAlias /livecode-cgi/ "{server}/"
<Directory "{server}">
    Options +ExecCGI
    Require all granted
</Directory>
<Directory "{www}">
    Options +ExecCGI
    Require all granted
    AddHandler livecode-script .lc
    Action livecode-script /livecode-cgi/{engine}
</Directory>
'''.format(root=self.root, port=self.port, www=www, server=server_dir, engine=package_server.ENGINE))
        self.out = open(os.path.join(self.root, 'output.log'), 'wb')
        self.proc = subprocess.Popen([httpd, '-f', self.conf, '-DFOREGROUND'],
                                     stdout=self.out, stderr=subprocess.STDOUT,
                                     # Apache signals its process group when it stops
                                     start_new_session=True)
        deadline = time.time() + 20
        while time.time() < deadline:
            if self.proc.poll() is not None:
                raise CheckError('Apache stopped at once: %s' % self.error_log())
            try:
                socket.create_connection(('127.0.0.1', self.port), timeout=1).close()
                return
            except OSError:
                time.sleep(0.2)
        self.close()
        raise CheckError('Apache did not start listening on port %d' % self.port)

    def error_log(self):
        text = ''
        for name in ('output.log', 'error.log'):
            try:
                with open(os.path.join(self.root, name), encoding='latin-1') as f:
                    text += f.read()[-3000:]
            except OSError:
                pass
        return text

    def send(self, req):
        url = 'http://127.0.0.1:%d/%s%s' % (self.port, req.page, '?' + req.query if req.query else '')
        r = urllib.request.Request(url, data=req.body if req.method == 'POST' else None, method=req.method)
        if req.body:
            r.add_header('Content-Type', req.content_type)
        if req.cookie:
            r.add_header('Cookie', req.cookie)
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        try:
            with opener.open(r, timeout=TIMEOUT) as resp:
                return Response(resp.status, list(resp.headers.items()), resp.read())
        except urllib.error.HTTPError as e:
            return Response(e.code, list(e.headers.items()), e.read())

    def close(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(10)
        self.out.close()


def _group_exists(name):
    try:
        import grp
        grp.getgrnam(name)
        return True
    except (ImportError, KeyError):
        return False


class CheckError(Exception):
    pass


class Results(object):
    def __init__(self, log):
        self.log, self.rows = log, []

    def add(self, where, what, ok, detail=''):
        self.rows.append((where, what, ok, detail))
        self.log('%s  %s: %s%s' % ('PASS' if ok else 'FAIL', where, what, '' if ok else ' - ' + detail))
        if not ok and GHA:
            print('::error title=Server check::%s: %s - %s' % (where, what, detail[:500]))

    @property
    def failed(self):
        return sum(1 for r in self.rows if not r[2])


def matches(value, wanted):
    if hasattr(wanted, 'match'):
        return isinstance(value, str) and wanted.match(value) is not None
    return value == wanted


def run_cases(transport, results):
    for name, req, checks in CASES:
        where = '%s %s' % (transport.name, name)
        try:
            r = transport.send(req)
        except (OSError, subprocess.SubprocessError, ValueError) as e:
            results.add(where, 'request', False, str(e))
            continue
        for what, get, wanted in checks:
            try:
                value = get(r)
            except Exception as e:  # a check that cannot read the answer fails
                value = '<%s: %s>' % (type(e).__name__, e)
            ok = matches(value, wanted)
            want = 'matching %s' % wanted.pattern if hasattr(wanted, 'pattern') else repr(wanted)
            results.add(where, what, ok, 'wanted %s, got %r; %s' % (want, value, r.describe()))
    # Two requests of one session: the second sends the first's cookie
    where = '%s session' % transport.name
    try:
        first = transport.send(request('session.lc'))
        sid = None
        for k, v in first.headers:
            if k.lower() == 'set-cookie' and v.startswith('LCSESSION='):
                sid = v.split(';')[0]
        results.add(where, 'first request', first.field('count') == '1' and first.field('id') == 'true',
                    first.describe())
        results.add(where, 'session cookie (HttpOnly)', sid is not None and 'HttpOnly' in (first.cookie('LCSESSION') or ''),
                    first.describe())
        second = transport.send(request('session.lc', cookie=sid or ''))
        results.add(where, 'second request sees the first', second.field('count') == '2', second.describe())
    except (OSError, subprocess.SubprocessError, ValueError) as e:
        results.add(where, 'requests', False, str(e))


def run_command_line(engine, work, repo, results):
    where = 'command line'
    script = os.path.join(work, 'cli.lc')
    with open(script, 'w', newline='\n') as f:
        f.write('<?lc\nput "count=" & $# & ";" & return\nput "zero=" & $0 & ";" & return\n'
                'put "one=" & $1 & ";" & return\nput "version=" & the version & ";" & return\n'
                'put "environment=" & the environment & ";" & return\n?>')
    p = subprocess.run([engine, script, 'first', 'second'], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       env=base_env(), cwd=work, timeout=TIMEOUT)
    r = Response(None, [], p.stdout)
    want_version = engine_version(repo)
    results.add(where, 'exit status 0', p.returncode == 0, 'status %s, stderr %r' % (p.returncode, p.stderr[:300]))
    # LiveCode's numbering: the arguments after the script are $0, $1...
    results.add(where, '$# is 2', r.field('count') == '2', r.describe())
    results.add(where, '$0 and $1 are the arguments', (r.field('zero'), r.field('one')) == ('first', 'second'),
                r.describe())
    results.add(where, 'the version is %s...' % want_version,
                (r.field('version') or '').startswith(want_version), r.describe())
    results.add(where, 'the environment is server', r.field('environment') == 'server', r.describe())
    bad = os.path.join(work, 'bad.lc')
    with open(bad, 'w', newline='\n') as f:
        f.write('<?lc\nput 1 +\n?>')
    p = subprocess.run([engine, bad], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=base_env(),
                       cwd=work, timeout=TIMEOUT)
    results.add(where, 'a compile error goes to standard error, status 0',
                p.returncode == 0 and p.stdout.strip() == b'' and b'bad expression' in p.stderr,
                'status %s, stdout %r, stderr %r' % (p.returncode, p.stdout[:200], p.stderr[:300]))
    quit_ = os.path.join(work, 'quit.lc')
    with open(quit_, 'w', newline='\n') as f:
        f.write('<?lc\nquit 3\n?>')
    p = subprocess.run([engine, quit_], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=base_env(),
                       cwd=work, timeout=TIMEOUT)
    results.add(where, 'quit 3 exits with status 3', p.returncode == 3, 'status %s' % p.returncode)


def run_shebang(engine, www, results):
    """A page that names the engine on its first line, run as a CGI
    program itself (fcgiwrap; Apache with ExecCGI on the page): no
    PATH_TRANSLATED, the page in SCRIPT_FILENAME."""
    where = 'cgi #! page'
    page = os.path.join(www, 'direct.lc')
    with open(page, 'w', newline='\n') as f:
        # After a "#!" line the file is script throughout, without <?lc ?>
        f.write('#!%s\nput "direct=" & $_GET["q"] & ";"\n' % engine)
    os.chmod(page, 0o755)
    env = base_env()
    env.update({'GATEWAY_INTERFACE': 'CGI/1.1', 'REQUEST_METHOD': 'GET', 'QUERY_STRING': 'q=shebang',
                'SCRIPT_FILENAME': page, 'SCRIPT_NAME': '/direct.lc', 'DOCUMENT_ROOT': www})
    try:
        r = run_cgi([page], env, b'', www)
    except (OSError, subprocess.SubprocessError) as e:
        results.add(where, 'run', False, str(e))
        return
    results.add(where, 'the page runs as script, without its first line', r.body_text().strip() == 'direct=shebang;',
                r.describe())


def engine_version(repo):
    """"9.7.1" from the version file: the engine's version starts with it."""
    with open(os.path.join(repo, 'version'), encoding='utf-8') as f:
        text = f.read()
    parts = [re.search(r'BUILD_%s_VERSION\s*=\s*(\d+)' % k, text).group(1) for k in ('MAJOR', 'MINOR', 'POINT')]
    return '.'.join(parts)


def extract(zip_path, dest):
    """Extract with the stored Unix modes (zipfile drops them)."""
    with zipfile.ZipFile(zip_path) as z:
        for zi in z.infolist():
            parts = zi.filename.rstrip('/').split('/')
            if zi.filename.startswith('/') or '\\' in zi.filename or any(p in ('', '.', '..') for p in parts):
                raise CheckError('%s: unsafe entry %r' % (zip_path, zi.filename))
            target = os.path.join(dest, *parts)
            if zi.is_dir():
                os.makedirs(target, exist_ok=True)
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(zi) as src, open(target, 'wb') as out:
                shutil.copyfileobj(src, out)
            mode = (zi.external_attr >> 16) & 0o777
            if mode and os.name != 'nt':
                os.chmod(target, mode)
            if stat.S_ISLNK(zi.external_attr >> 16):
                raise CheckError('%s: %s is a symbolic link' % (zip_path, zi.filename))


def check_layout(p, server_dir, results):
    where = 'layout'
    expected = [name for name, _ in package_server.wanted(p)] + \
        [name for _, name in package_server.LICENCES] + ['README.txt']
    found = []
    for dirpath, _, files in os.walk(server_dir):
        for f in files:
            found.append(os.path.relpath(os.path.join(dirpath, f), server_dir).replace(os.sep, '/'))
    results.add(where, 'the files of LiveCode\'s server zip', sorted(found) == sorted(expected),
                'missing %s, not expected %s' % (sorted(set(expected) - set(found)), sorted(set(found) - set(expected))))
    engine = os.path.join(server_dir, package_server.wanted(p)[0][0])
    if os.name != 'nt':
        results.add(where, 'the engine is executable', os.access(engine, os.X_OK), engine)
    return engine


def default_platform():
    if sys.platform.startswith('win'):
        return 'win-x86_64'
    if sys.platform == 'darwin':
        return 'mac-universal'
    import platform as pf
    return 'linux-arm64' if pf.machine().lower() in ('aarch64', 'arm64') else 'linux-x86_64'


def write_site(www, sessions):
    os.makedirs(www, exist_ok=True)
    os.makedirs(sessions, exist_ok=True)
    for name, text in PAGES.items():
        with open(os.path.join(www, name), 'w', encoding='utf-8', newline='\n') as f:
            f.write(text.replace('{sessions}', sessions.replace('\\', '/')))


def summary(results, transports):
    path = os.environ.get('GITHUB_STEP_SUMMARY')
    if not path:
        return
    lines = ['### Server check', '',
             '%d checks, %d failed; requests sent %s.' % (len(results.rows), results.failed, ' and '.join(transports)),
             '']
    failed = [r for r in results.rows if not r[2]]
    if failed:
        lines += ['| Where | Check | Detail |', '| --- | --- | --- |']
        lines += ['| %s | %s | `%s` |' % (w, c, d[:200].replace('|', '\\|').replace('`', "'")) for w, c, _, d in failed]
    with open(path, 'a', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--zip', required=True, help='the server zip')
    ap.add_argument('--platform', choices=list(package_server.PLATFORMS), default=None)
    ap.add_argument('--apache', choices=('auto', 'yes', 'no'), default='auto')
    ap.add_argument('--work', help='folder to work in (default: a temporary one, removed after)')
    ap.add_argument('--log', help='write the log here too')
    ap.add_argument('--repo', default=REPO)
    args = ap.parse_args(argv)
    p = package_server.PLATFORMS[args.platform or default_platform()]

    log_file = open(args.log, 'w', encoding='utf-8') if args.log else None

    def log(msg=''):
        print(msg)
        sys.stdout.flush()
        if log_file:
            log_file.write(msg + '\n')
            log_file.flush()

    work = args.work or tempfile.mkdtemp(prefix='oxt-server-check-')
    os.makedirs(work, exist_ok=True)
    if hasattr(os, 'geteuid') and os.geteuid() == 0:
        os.chmod(work, 0o755)
    results = Results(log)
    transports = []
    apache = None
    try:
        server_dir = os.path.join(work, 'livecode-server')
        www = os.path.join(work, 'www')
        sessions = os.path.join(work, 'sessions')
        shutil.rmtree(server_dir, ignore_errors=True)
        os.makedirs(server_dir)
        extract(args.zip, server_dir)
        log('Server zip   : %s, extracted to %s' % (args.zip, server_dir))
        engine = check_layout(p, server_dir, results)
        write_site(www, sessions)
        if hasattr(os, 'geteuid') and os.geteuid() == 0:
            os.chmod(sessions, 0o777)
        run_command_line(engine, work, args.repo, results)
        run_cases(CgiTransport(engine, www), results)
        transports.append('as a CGI program')
        if p.family != 'windows':
            run_shebang(engine, www, results)
        if args.apache != 'no':
            found = find_apache() if p.family != 'windows' else None
            if found:
                # A session folder of its own: the engine runs as another
                # user under Apache when this runs as root
                shutil.rmtree(sessions, ignore_errors=True)
                os.makedirs(sessions)
                if hasattr(os, 'geteuid') and os.geteuid() == 0:
                    os.chmod(sessions, 0o777)
                apache = ApacheTransport(found[0], found[1], server_dir, www, work, log)
                log('Apache       : %s, port %d' % (found[0], apache.port))
                run_cases(apache, results)
                transports.append('through Apache')
            elif args.apache == 'yes':
                results.add('apache', 'an Apache httpd with mod_cgi and mod_actions', False, 'none found')
            else:
                log('Apache       : none found, skipped')
    except (CheckError, OSError, subprocess.SubprocessError, zipfile.BadZipFile) as e:
        log('error: %s' % e)
        if GHA:
            print('::error title=Server check::%s' % e)
        if apache:
            log(apache.error_log())
        return 101
    finally:
        if apache:
            if results.failed:
                log('Apache error log:\n' + apache.error_log())
            apache.close()
        if not args.work:
            shutil.rmtree(work, ignore_errors=True)
    log('%d checks, %d failed' % (len(results.rows), results.failed))
    summary(results, transports)
    if log_file:
        log_file.close()
    return min(results.failed, 100)


if __name__ == '__main__':
    sys.exit(main())
