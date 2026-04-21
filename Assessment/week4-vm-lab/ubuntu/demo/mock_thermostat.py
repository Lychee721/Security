#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse
import json
import time


class ThermostatState:
    current_temp = 21
    mode = "auto"


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, payload, code=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{ts}] {self.address_string()} {fmt % args}")

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/status":
            payload = {
                "device": "smart-thermostat",
                "temperature": ThermostatState.current_temp,
                "mode": ThermostatState.mode,
            }
            self._send_json(payload)
            return

        if parsed.path == "/set_temp":
            params = parse_qs(parsed.query)
            try:
                value = int(params.get("value", [ThermostatState.current_temp])[0])
                ThermostatState.current_temp = value
                self._send_json({"ok": True, "temperature": value})
                return
            except ValueError:
                self._send_json({"ok": False, "error": "invalid value"}, code=400)
                return

        self._send_json({"ok": False, "error": "unknown endpoint"}, code=404)


def main():
    server = HTTPServer(("0.0.0.0", 8080), Handler)
    print("[*] Mock thermostat listening on 0.0.0.0:8080")
    print("[*] Endpoints: /status and /set_temp?value=23")
    server.serve_forever()


if __name__ == "__main__":
    main()
