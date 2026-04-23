#!/usr/bin/env python3
from collections import Counter, defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse
import hmac
import hashlib
import json
import os
import threading
import time


def env_int(name, default):
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


class Config:
    bind_host = os.getenv("THERMOSTAT_BIND_HOST", "0.0.0.0")
    port = env_int("THERMOSTAT_PORT", 8080)
    api_key = os.getenv("THERMOSTAT_API_KEY", "elec0138-demo-key")
    api_key_fingerprint = hashlib.sha256(api_key.encode("utf-8")).hexdigest()[:12]
    status_limit_count = env_int("THERMOSTAT_STATUS_LIMIT_COUNT", 20)
    status_limit_seconds = env_int("THERMOSTAT_STATUS_LIMIT_SECONDS", 2)
    command_limit_count = env_int("THERMOSTAT_COMMAND_LIMIT_COUNT", 5)
    command_limit_seconds = env_int("THERMOSTAT_COMMAND_LIMIT_SECONDS", 30)
    auth_fail_threshold = env_int("THERMOSTAT_AUTH_FAIL_THRESHOLD", 3)
    auth_fail_window_seconds = env_int("THERMOSTAT_AUTH_FAIL_WINDOW_SECONDS", 60)
    auth_fail_lock_seconds = env_int("THERMOSTAT_AUTH_FAIL_LOCK_SECONDS", 60)
    min_temp = env_int("THERMOSTAT_MIN_TEMP", 5)
    max_temp = env_int("THERMOSTAT_MAX_TEMP", 35)


class ThermostatState:
    current_temp = 21
    mode = "auto"
    updated_at = time.strftime("%Y-%m-%d %H:%M:%S")


class SecurityState:
    lock = threading.Lock()
    request_windows = defaultdict(deque)
    auth_failures = defaultdict(deque)
    blocks = {}
    counters = Counter()
    recent_events = deque(maxlen=60)


def now_ts():
    return time.strftime("%Y-%m-%d %H:%M:%S")


def append_event(event_type, client_ip, detail=None):
    event = {
        "ts": now_ts(),
        "event": event_type,
        "client_ip": client_ip,
    }
    if detail:
        event.update(detail)

    with SecurityState.lock:
        SecurityState.counters[event_type] += 1
        SecurityState.recent_events.append(event)

    print(f"[SECURITY] {json.dumps(event, sort_keys=True)}", flush=True)


def prune_window(bucket, window_seconds, current_time):
    while bucket and current_time - bucket[0] > window_seconds:
        bucket.popleft()


def check_rate_limit(client_ip, scope, limit_count, window_seconds):
    current_time = time.time()
    block_key = (client_ip, scope, "rate")
    bucket_key = (client_ip, scope)

    with SecurityState.lock:
        blocked_until = SecurityState.blocks.get(block_key, 0)
        if blocked_until > current_time:
            retry_after = int(max(1, blocked_until - current_time))
            SecurityState.counters[f"{scope}_blocked"] += 1
            return False, retry_after

        bucket = SecurityState.request_windows[bucket_key]
        prune_window(bucket, window_seconds, current_time)

        if len(bucket) >= limit_count:
            blocked_until = current_time + max(3, window_seconds)
            SecurityState.blocks[block_key] = blocked_until
            retry_after = int(max(1, blocked_until - current_time))
        else:
            bucket.append(current_time)
            return True, None

    append_event(
        "rate_limited",
        client_ip,
        {
            "scope": scope,
            "limit_count": limit_count,
            "window_seconds": window_seconds,
            "retry_after": retry_after,
        },
    )
    return False, retry_after


def record_auth_failure(client_ip):
    current_time = time.time()
    lock_applied = False
    failures = 0

    with SecurityState.lock:
        bucket = SecurityState.auth_failures[client_ip]
        prune_window(bucket, Config.auth_fail_window_seconds, current_time)
        bucket.append(current_time)
        failures = len(bucket)
        if failures >= Config.auth_fail_threshold:
            SecurityState.blocks[(client_ip, "auth", "lock")] = (
                current_time + Config.auth_fail_lock_seconds
            )
            lock_applied = True

    append_event(
        "auth_locked" if lock_applied else "auth_failed",
        client_ip,
        {
            "failures_in_window": failures,
            "window_seconds": Config.auth_fail_window_seconds,
            "lock_seconds": Config.auth_fail_lock_seconds if lock_applied else 0,
        },
    )


def check_auth_lock(client_ip):
    current_time = time.time()
    with SecurityState.lock:
        blocked_until = SecurityState.blocks.get((client_ip, "auth", "lock"), 0)
        if blocked_until > current_time:
            return True, int(max(1, blocked_until - current_time))
    return False, None


def clear_auth_failures(client_ip):
    with SecurityState.lock:
        if client_ip in SecurityState.auth_failures:
            SecurityState.auth_failures[client_ip].clear()


class Handler(BaseHTTPRequestHandler):
    server_version = "ELEC0138DefendedThermostat/1.0"

    def _client_ip(self):
        return self.client_address[0]

    def _send_json(self, payload, code=200, extra_headers=None):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if extra_headers:
            for key, value in extra_headers.items():
                self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def _send_retry_json(self, error, retry_after):
        self._send_json(
            {"ok": False, "error": error, "retry_after": retry_after},
            code=429,
            extra_headers={"Retry-After": str(retry_after)},
        )

    def log_message(self, fmt, *args):
        print(f"[{now_ts()}] {self._client_ip()} {fmt % args}", flush=True)

    def _require_api_key(self):
        client_ip = self._client_ip()
        locked, retry_after = check_auth_lock(client_ip)
        if locked:
            self._send_retry_json("temporarily_locked", retry_after)
            return False

        provided_key = self.headers.get("X-API-Key", "")
        if not hmac.compare_digest(provided_key, Config.api_key):
            record_auth_failure(client_ip)
            self._send_json(
                {"ok": False, "error": "unauthorized"},
                code=401,
                extra_headers={"WWW-Authenticate": "ApiKey"},
            )
            return False

        clear_auth_failures(client_ip)
        return True

    def _handle_status(self):
        client_ip = self._client_ip()
        allowed, retry_after = check_rate_limit(
            client_ip,
            "status",
            Config.status_limit_count,
            Config.status_limit_seconds,
        )
        if not allowed:
            self._send_retry_json("rate_limited", retry_after)
            return

        payload = {
            "device": "defended-smart-thermostat",
            "temperature": ThermostatState.current_temp,
            "mode": ThermostatState.mode,
            "updated_at": ThermostatState.updated_at,
        }
        self._send_json(payload)

    def _handle_set_temp(self, parsed):
        client_ip = self._client_ip()
        if not self._require_api_key():
            return

        allowed, retry_after = check_rate_limit(
            client_ip,
            "command",
            Config.command_limit_count,
            Config.command_limit_seconds,
        )
        if not allowed:
            self._send_retry_json("rate_limited", retry_after)
            return

        params = parse_qs(parsed.query)
        try:
            value = int(params.get("value", [ThermostatState.current_temp])[0])
        except ValueError:
            append_event("invalid_temp_value", client_ip, {"value": params.get("value", [""])[0]})
            self._send_json({"ok": False, "error": "invalid_value"}, code=400)
            return

        if value < Config.min_temp or value > Config.max_temp:
            append_event("out_of_range_temp", client_ip, {"value": value})
            self._send_json(
                {
                    "ok": False,
                    "error": "out_of_range",
                    "allowed_range": [Config.min_temp, Config.max_temp],
                },
                code=400,
            )
            return

        ThermostatState.current_temp = value
        ThermostatState.updated_at = now_ts()
        append_event("set_temp_applied", client_ip, {"value": value})
        self._send_json({"ok": True, "temperature": value, "mode": ThermostatState.mode})

    def _handle_metrics(self):
        client_ip = self._client_ip()
        if not self._require_api_key():
            return

        with SecurityState.lock:
            counters = dict(SecurityState.counters)
            recent_events = list(SecurityState.recent_events)

        payload = {
            "ok": True,
            "device": "defended-smart-thermostat",
            "security_profile": {
                "api_key_fingerprint": Config.api_key_fingerprint,
                "status_rate_limit": {
                    "count": Config.status_limit_count,
                    "seconds": Config.status_limit_seconds,
                },
                "command_rate_limit": {
                    "count": Config.command_limit_count,
                    "seconds": Config.command_limit_seconds,
                },
                "auth_lockout": {
                    "threshold": Config.auth_fail_threshold,
                    "window_seconds": Config.auth_fail_window_seconds,
                    "lock_seconds": Config.auth_fail_lock_seconds,
                },
            },
            "service_state": {
                "temperature": ThermostatState.current_temp,
                "mode": ThermostatState.mode,
                "updated_at": ThermostatState.updated_at,
            },
            "counters": counters,
            "recent_events": recent_events,
        }
        self._send_json(payload)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/status":
            self._handle_status()
            return

        if parsed.path == "/set_temp":
            self._handle_set_temp(parsed)
            return

        if parsed.path == "/admin/metrics":
            self._handle_metrics()
            return

        self._send_json({"ok": False, "error": "unknown_endpoint"}, code=404)


def main():
    server = ThreadingHTTPServer((Config.bind_host, Config.port), Handler)
    print(f"[*] Defended thermostat listening on {Config.bind_host}:{Config.port}")
    print("[*] Security layers enabled:")
    print("[*] 1. API key required for /set_temp and /admin/metrics")
    print("[*] 2. Per-client rate limiting for /status and /set_temp")
    print("[*] 3. Authentication failure lockout with audit logging")
    print("[*] Endpoints:")
    print("[*]   GET /status")
    print("[*]   GET /set_temp?value=23   with X-API-Key header")
    print("[*]   GET /admin/metrics       with X-API-Key header")
    print("[*] API key fingerprint:", Config.api_key_fingerprint)
    server.serve_forever()


if __name__ == "__main__":
    main()
