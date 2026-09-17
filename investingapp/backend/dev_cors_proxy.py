"""Local CORS proxy: Flutter Chrome → AWS Elastic IP.

Chrome blocks http://localhost:* from calling http://43.204.159.255 because
the live API does not send Access-Control-Allow-Origin. This process adds it.

  python dev_cors_proxy.py
"""

from __future__ import annotations

from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import sys

UPSTREAM_HOST = "43.204.159.255"
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = 8787
HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "host",
    "origin",
}


def _cors_headers(origin: str) -> list[tuple[str, str]]:
    allowed = origin if origin.startswith(("http://localhost:", "http://127.0.0.1:")) else "*"
    return [
        ("Access-Control-Allow-Origin", allowed),
        ("Access-Control-Allow-Methods", "DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT"),
        (
            "Access-Control-Allow-Headers",
            "accept, authorization, content-type, origin, x-csrftoken, x-requested-with",
        ),
        ("Access-Control-Max-Age", "86400"),
        ("Vary", "Origin"),
    ]


class ProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def do_OPTIONS(self) -> None:  # noqa: N802
        origin = self.headers.get("Origin", "http://localhost")
        self.send_response(204)
        for key, value in _cors_headers(origin):
            self.send_header(key, value)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        self._proxy()

    def do_POST(self) -> None:  # noqa: N802
        self._proxy()

    def do_PUT(self) -> None:  # noqa: N802
        self._proxy()

    def do_PATCH(self) -> None:  # noqa: N802
        self._proxy()

    def do_DELETE(self) -> None:  # noqa: N802
        self._proxy()

    def do_HEAD(self) -> None:  # noqa: N802
        self._proxy()

    def _proxy(self) -> None:
        origin = self.headers.get("Origin", "http://localhost")
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_BY_HOP
        }
        conn = HTTPConnection(UPSTREAM_HOST, 80, timeout=60)
        try:
            conn.request(self.command, self.path, body=body, headers=headers)
            upstream = conn.getresponse()
            payload = upstream.read()
            self.send_response(upstream.status)
            for key, value in _cors_headers(origin):
                self.send_header(key, value)
            for key, value in upstream.getheaders():
                if key.lower() in HOP_BY_HOP or key.lower().startswith("access-control-"):
                    continue
                if key.lower() == "content-length":
                    continue
                self.send_header(key, value)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(payload)
        except Exception as exc:
            message = f'{{"detail":"Proxy could not reach AWS ({exc})."}}'.encode("utf-8")
            self.send_response(502)
            for key, value in _cors_headers(origin):
                self.send_header(key, value)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(message)))
            self.end_headers()
            self.wfile.write(message)
        finally:
            conn.close()


def main() -> None:
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), ProxyHandler)
    print(f"CORS proxy http://{LISTEN_HOST}:{LISTEN_PORT} -> http://{UPSTREAM_HOST}")
    print("Restart Flutter Chrome after this is running.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
