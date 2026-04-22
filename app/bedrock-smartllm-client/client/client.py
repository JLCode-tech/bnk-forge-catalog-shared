"""
Bedrock Smart-LLM demo client — sends varied prompts through the BNK Gateway,
pacing with a Poisson process so the load is naturally bursty (real clients,
not a metronome).

Metrics exposed on :9100 so kube-prometheus-stack scrapes client-side latency,
request rate, and which backend model served each request — letting the dashboard
show "what the clients see" alongside "what the analyzer is doing".
"""
import json
import logging
import os
import pathlib
import random
import time
import urllib.error
import urllib.request
from threading import Thread

from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)
from prometheus_client.core import REGISTRY
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

GATEWAY_URL = os.environ["GATEWAY_URL"].rstrip("/")  # e.g. http://10.0.10.100
REQUEST_RATE = float(os.environ.get("REQUEST_RATE", "1.0"))  # req/sec (Poisson mean)
MAX_TOKENS = int(os.environ.get("MAX_TOKENS", "128"))
REQUEST_TIMEOUT = float(os.environ.get("REQUEST_TIMEOUT", "30.0"))
PROMPTS_PATH = pathlib.Path(os.environ.get("PROMPTS_PATH", "/etc/prompts/prompts.txt"))
METRICS_PORT = int(os.environ.get("METRICS_PORT", "9100"))
CLIENT_ID = os.environ.get("CLIENT_ID", "client-0")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("smartllm-client")

m_reqs = Counter(
    "smartllm_client_requests_total",
    "Chat completions attempted by the client",
    ["client_id", "status", "model_served"],
)
m_lat = Histogram(
    "smartllm_client_request_duration_seconds",
    "Client-observed end-to-end latency",
    ["client_id", "model_served"],
    buckets=[0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30],
)
m_tokens = Counter(
    "smartllm_client_tokens_total",
    "Tokens counted from responses",
    ["client_id", "model_served", "direction"],
)


def load_prompts() -> list[str]:
    if not PROMPTS_PATH.exists():
        log.warning("prompts file %s missing — using a minimal fallback", PROMPTS_PATH)
        return ["Hello", "What's 2+2?", "Name three cities."]
    return [ln.strip() for ln in PROMPTS_PATH.read_text().splitlines() if ln.strip() and not ln.lstrip().startswith("#")]


def send_one(prompt: str) -> None:
    payload = json.dumps(
        {
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": MAX_TOKENS,
            "temperature": 0.7,
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        f"{GATEWAY_URL}/v1/chat/completions",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    started = time.monotonic()
    model_served = "unknown"
    status = "error"
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        model_served = body.get("model", "unknown")
        usage = body.get("usage", {}) or {}
        m_tokens.labels(CLIENT_ID, model_served, "prompt").inc(int(usage.get("prompt_tokens", 0)))
        m_tokens.labels(CLIENT_ID, model_served, "completion").inc(int(usage.get("completion_tokens", 0)))
        status = "ok"
    except urllib.error.HTTPError as e:
        status = f"http_{e.code}"
        log.warning("chat HTTP %s: %s", e.code, e.reason)
    except Exception as e:
        log.warning("chat failed: %s", e)
    finally:
        elapsed = time.monotonic() - started
        m_reqs.labels(CLIENT_ID, status, model_served).inc()
        m_lat.labels(CLIENT_ID, model_served).observe(elapsed)


class _MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/metrics":
            body = generate_latest(REGISTRY)
            self.send_response(200)
            self.send_header("Content-Type", CONTENT_TYPE_LATEST)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path in ("/health", "/"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *_args, **_kwargs) -> None:  # suppress default access log
        return


def serve_metrics() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", METRICS_PORT), _MetricsHandler)
    log.info("metrics listening on :%d", METRICS_PORT)
    server.serve_forever()


def main() -> None:
    prompts = load_prompts()
    log.info(
        "starting loop id=%s gateway=%s rate=%.2f/s prompts=%d",
        CLIENT_ID,
        GATEWAY_URL,
        REQUEST_RATE,
        len(prompts),
    )
    Thread(target=serve_metrics, daemon=True).start()
    while True:
        prompt = random.choice(prompts)
        send_one(prompt)
        # Poisson inter-arrival times → naturally bursty without hand-rolling a state machine.
        time.sleep(random.expovariate(REQUEST_RATE))


if __name__ == "__main__":
    main()
