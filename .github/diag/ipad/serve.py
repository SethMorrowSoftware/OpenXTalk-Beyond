#!/usr/bin/env python3
"""NOT FOR MAIN. Serves this folder on a port, and prints what a page posts
to /log (its time line), so that a case's record is in the job's log
whether or not the driver could read it."""

import http.server
import os
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        size = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(min(size, 65536)).decode('utf-8', 'replace')
        print('POSTED %s' % self.path, flush=True)
        for line in body.splitlines()[:200]:
            print('  | ' + line[:300], flush=True)
        self.send_response(204)
        self.end_headers()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, fmt, *args):
        print('served: ' + (fmt % args)[:200], flush=True)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()


if __name__ == '__main__':
    main()
