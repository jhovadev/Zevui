"""Local Initializr UI/API; binds to loopback only, no external services."""
from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from .generator import CATALOG, InputError, archive, validate

UI = Path(__file__).with_name('index.html').read_bytes()
MAX_REQUEST = 16384


class Handler(BaseHTTPRequestHandler):
    def respond(self, code: int, body: bytes, mime: str, *, attachment: str | None = None):
        self.send_response(code)
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; object-src 'none'; frame-ancestors 'none'")
        if attachment:
            self.send_header('Content-Disposition', f'attachment; filename="{attachment}"')
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == '/':
            return self.respond(200, UI, 'text/html; charset=utf-8')
        if self.path == '/static/app.js':
            return self.respond(200, Path(__file__).with_name('app.js').read_bytes(), 'text/javascript; charset=utf-8')
        if self.path == '/static/style.css':
            return self.respond(200, Path(__file__).with_name('style.css').read_bytes(), 'text/css; charset=utf-8')
        if self.path == '/api/catalog':
            return self.respond(200, json.dumps(CATALOG).encode(), 'application/json; charset=utf-8')
        return self.respond(404, b'Not found', 'text/plain; charset=utf-8')

    def do_POST(self):
        if self.path != '/api/generate':
            return self.respond(404, b'Not found', 'text/plain; charset=utf-8')
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if length < 1 or length > MAX_REQUEST:
                raise InputError('Request size outside allowed limits')
            config = validate(json.loads(self.rfile.read(length)))
            return self.respond(200, archive(config), 'application/zip', attachment=config['name'] + '.zip')
        except (ValueError, TypeError, UnicodeError) as e:
            return self.respond(400, json.dumps({'error': str(e)}).encode(), 'application/json; charset=utf-8')


def main():
    parser = argparse.ArgumentParser(description='Zevui Initializr local web UI')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    if not (1024 <= args.port <= 65535):
        parser.error('--port must be between 1024 and 65535')
    with ThreadingHTTPServer(('127.0.0.1', args.port), Handler) as httpd:
        print(f'Zevui Initializr: http://127.0.0.1:{args.port}/', flush=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nZevui Initializr stopped.", flush=True)


if __name__ == '__main__':
    main()
