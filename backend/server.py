#!/usr/bin/env python3
"""PreSlab local observation server (development pilot only).

Exposes the phone's crop pipeline to a live Meta vision model without
putting any key in the app, the repo, or chat:

  app (crops only) -> this server -> Meta API -> observations

The API key is read from a key FILE outside the repo
(PRESLAB_KEY_FILE, default ~/Documents/preslab-key.txt) or from the
LLAMA_API_KEY environment variable. It is never logged, never returned,
and never written anywhere.

Usage:
    python3 backend/server.py [--port 8080]

Then point the app's observer test screen at http://<this-mac>:8080.
POST /observe with {"crops": [{"region": str, "jpeg_b64": str}, ...]}
responds with {"observations": [...], "model": str,
"estimated_cost_usd": float, "latency_s": float}.
GET /health responds with {"ok": true}.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

API_BASE = os.environ.get(
    "MODEL_API_BASE",
    os.environ.get("LLAMA_API_BASE", "https://api.meta.ai/v1"),
)
KEY_FILE = os.environ.get(
    "PRESLAB_KEY_FILE",
    os.path.join(os.path.expanduser("~"), "Documents", "preslab-key.txt"),
)
MAX_CROPS = 10
MAX_BODY_BYTES = 25 * 1024 * 1024

# Muse Spark takes image input on the same chat-completions endpoint.
PREFERRED_MODEL = "muse-spark-1.3"

OBSERVE_PROMPT = (
    "You are a trading-card condition assistant. Look at this close-up crop "
    "of a trading card and respond with ONLY a JSON object (no markdown "
    "fences) with this shape: "
    '{"statement": "<one sentence describing visible wear or lack thereof>", '
    '"limitation": "<what this single crop cannot confirm>"} '
    "Describe only what is visible. Never estimate a grade, a grade range, "
    "or a confidence percentage."
)


def read_key() -> str:
    key = os.environ.get("LLAMA_API_KEY", "").strip()
    if not key:
        key = os.environ.get("META_API_KEY", "").strip()
    if not key and os.path.isfile(KEY_FILE):
        with open(KEY_FILE, "r", encoding="utf-8") as fh:
            key = fh.read().strip()
    return key


def api_post(key: str, path: str, payload: dict):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(API_BASE + path, data=data, method="POST")
    req.add_header("Authorization", "Bearer " + key)
    req.add_header("Content-Type", "application/json")
    start = time.time()
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read().decode()), time.time() - start


class ProviderError(Exception):
    def __init__(self, status: int, snippet: str):
        super().__init__(f"HTTP {status}")
        self.status = status
        self.snippet = snippet


def api_get(key: str, path: str):
    import urllib.error

    req = urllib.request.Request(API_BASE + path, method="GET")
    req.add_header("Authorization", "Bearer " + key)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        raise ProviderError(exc.code, exc.read().decode(errors="replace")[:300])


def pick_vision_model(ids: list) -> str | None:
    if PREFERRED_MODEL in ids:
        return PREFERRED_MODEL
    lowered = {str(mid).lower(): mid for mid in ids}
    for low, mid in lowered.items():
        if "spark" in low:
            return mid
    return None


def estimate_cost(model: str, usage: dict) -> float | None:
    # No published per-token rate is baked in; the dashboard is the source
    # of truth until the validation run records real per-scan cost.
    return None


class State:
    key = ""
    model = ""


def observe_crops(crops: list) -> dict:
    observations = []
    total_cost = 0.0
    total_latency = 0.0
    total_prompt = 0
    total_completion = 0
    for crop in crops[:MAX_CROPS]:
        region = str(crop.get("region", "unknown"))
        payload = {
            "model": State.model,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": OBSERVE_PROMPT},
                        {
                            "type": "image_url",
                            "image_url": {"url": "data:image/jpeg;base64," + crop.get("jpeg_b64", "")},
                        },
                    ],
                }
            ],
            "max_tokens": 256,
            "temperature": 0.2,
        }
        body, latency = api_post(State.key, "/chat/completions", payload)
        total_latency += latency
        content = ""
        try:
            content = body["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError):
            pass
        statement, limitation = content.strip(), ""
        try:
            parsed = json.loads(content.strip().strip("`"))
            statement = str(parsed.get("statement", content)).strip()
            limitation = str(parsed.get("limitation", "")).strip()
        except (ValueError, AttributeError):
            pass
        usage = body.get("usage") or {}
        cost = estimate_cost(State.model, usage) or 0.0
        total_cost += cost
        total_prompt += usage.get("prompt_tokens") or usage.get("input_tokens") or 0
        total_completion += usage.get("completion_tokens") or usage.get("output_tokens") or 0
        observations.append(
            {"region": region, "statement": statement, "limitation": limitation}
        )
    return {
        "observations": observations,
        "model": State.model,
        "prompt_tokens": total_prompt,
        "completion_tokens": total_completion,
        "estimated_cost_usd": round(total_cost, 6),
        "latency_s": round(total_latency, 2),
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "PreSlabPilot/1.0"

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}")

    def send_json(self, status: int, obj: dict):
        data = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            ready = bool(State.key and State.model)
            self.send_json(200, {"ok": True, "ready": ready, "model": State.model})
        else:
            self.send_json(404, {"error": "unknown path"})

    def do_POST(self):
        if self.path != "/observe":
            self.send_json(404, {"error": "unknown path"})
            return
        if not State.key or not State.model:
            self.send_json(503, {"error": "server has no API key or model"})
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY_BYTES:
            self.send_json(413, {"error": "body missing or too large"})
            return
        try:
            body = json.loads(self.rfile.read(length).decode())
            crops = body.get("crops", [])
            assert isinstance(crops, list) and crops
        except (ValueError, AssertionError, UnicodeDecodeError):
            self.send_json(400, {"error": "expected {\"crops\": [{\"region\": str, \"jpeg_b64\": str}]}"})
            return
        print(f"POST /observe: {len(crops)} crop(s)")
        try:
            result = observe_crops(crops)
        except Exception as exc:  # noqa: BLE001 - report provider errors as JSON
            print(f"provider error: {type(exc).__name__}")
            self.send_json(502, {"error": "provider call failed"})
            return
        print(f"done: {len(result['observations'])} observations, "
              f"{result['prompt_tokens']}+{result['completion_tokens']} tokens, "
              f"{result['latency_s']:.1f}s (cost: check your dev.meta.ai dashboard)")
        self.send_json(200, result)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    State.key = read_key()
    if not State.key:
        print("RESULT: FAIL - no API key found.")
        print(f"  Save the Meta key as plain text in: {KEY_FILE}")
        print("  (TextEdit is fine. That file stays on this Mac; it is never committed.)")
        print("  Or export LLAMA_API_KEY in this shell and restart the server.")
        return 2
    print("API key: present (value never printed or logged)")

    try:
        body = api_get(State.key, "/models")
    except ProviderError as exc:
        print(f"RESULT: FAIL - Meta API refused the request (HTTP {exc.status}).")
        if exc.status in (401, 403):
            print("  The key is missing, wrong, or lacks API access. Recopy it from")
            print("  the Meta developer portal (API keys tab) into preslab-key.txt")
            print("  as plain text, one line, no extra spaces or blank lines.")
        else:
            print(f"  Response: {exc.snippet[:200]}")
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"RESULT: FAIL - could not reach Meta API ({type(exc).__name__}).")
        return 1
    items = body.get("data") or body.get("models") or []
    ids = [i if isinstance(i, str) else (i.get("id") or i.get("name")) for i in items]
    ids = [i for i in ids if i]
    State.model = pick_vision_model(ids) or ""
    if not State.model:
        print("RESULT: FAIL - account has no vision-capable model.")
        return 1
    print(f"Model: {State.model}")

    server = ThreadingHTTPServer(("0.0.0.0", args.port), Handler)
    print(f"Serving on port {args.port}. Phone URL: http://<this-mac>:8080")
    print("RESULT: OK - pilot server running.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
