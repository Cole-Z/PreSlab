#!/usr/bin/env python3
"""PreSlab backend connectivity check (Phase 1, step 1).

Verifies Meta's Llama API end to end:
  1. Lists models available on the account (GET /v1/models).
  2. Picks the strongest vision-capable model.
  3. Sends ONE vision test call with a card photo and a fixed grading prompt.
  4. Prints the raw model output, token usage, latency, and a cost estimate.

The API key is read from the LLAMA_API_KEY environment variable only.
It is never hardcoded, never printed, and never written to disk.

Usage:
    export LLAMA_API_KEY="your key from https://llama.developer.meta.com"
    backend/.venv/bin/python backend/connectivity_check.py [--image PATH]

Without --image, a tiny synthetic placeholder image is sent so the vision
path is still exercised. Pass --image with a real card photo for a
meaningful grading response.

This script deliberately does NOT run SAM and does NOT run the 100-card
validation. It is a connectivity check only.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import struct
import sys
import time
import urllib.error
import urllib.request
import zlib

API_BASE = os.environ.get("LLAMA_API_BASE", "https://api.llama.com/v1")

# Vision-capable models, strongest first. Used to rank the account's model
# list; the first match present wins. Falls back to any model ID containing
# a vision hint if none of these exact IDs are listed.
VISION_PRIORITY = [
    "Llama-4-Maverick-17B-128E-Instruct-FP8",
    "Llama-4-Maverick-17B-128E-Instruct",
    "Llama-4-Scout-17B-16E-Instruct-FP8",
    "Llama-4-Scout-17B-16E-Instruct",
    "Llama-3.2-90B-Vision-Instruct",
    "Llama-3.2-11B-Vision-Instruct",
]
VISION_HINTS = ("vision", "scout", "maverick")

GRADING_PROMPT = (
    "You are a trading-card pre-grading assistant. This is a photo of a "
    "trading card. Respond with ONLY a JSON object (no markdown fences) "
    "with this shape: "
    '{"estimated_grade": <number 1-10 or null>, '
    '"subgrades": {"centering": <1-10>, "corners": <1-10>, '
    '"edges": <1-10>, "surface": <1-10>}, '
    '"reasons": {"centering": "<one sentence>", "corners": "<one sentence>", '
    '"edges": "<one sentence>", "surface": "<one sentence>"}, '
    '"confidence": "<low|medium|high>", '
    '"unverifiable": "<what the photo could not confirm, or empty string>"} '
    "If the image is not a real trading-card photo, say so in "
    '"unverifiable" and set estimated_grade to null. '
    "Never claim this is an official grade; it is an estimate."
)

# Published hosted rates (USD per 1M tokens) used ONLY for estimating cost
# when the API response carries token usage but no billed amount.
# Maverick $0.22/$0.85 and Scout $0.15/$0.50 as reported at the Llama 4
# launch; actual billing on your Meta dashboard (or preview credits) may
# differ. Override with PRESLAB_RATE_IN_PER_MTOK / _OUT_PER_MTOK if needed.
RATES_PER_MTOK = {
    "maverick": (0.22, 0.85),
    "scout": (0.15, 0.50),
}
DEFAULT_RATE = (0.22, 0.85)


def api_key() -> str:
    key = os.environ.get("LLAMA_API_KEY", "").strip()
    if not key:
        key = os.environ.get("META_API_KEY", "").strip()
    return key


def http_json(method: str, url: str, key: str, payload: dict | None = None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {key}")
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = json.loads(resp.read().decode())
            return resp.status, body, time.time() - start
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode(errors="replace")[:1000]
        return exc.code, {"error_body": raw}, time.time() - start


def model_ids(body: dict) -> list[str]:
    items = body.get("data") or body.get("models") or []
    ids = []
    for item in items:
        if isinstance(item, str):
            ids.append(item)
        elif isinstance(item, dict):
            mid = item.get("id") or item.get("name") or item.get("model")
            if mid:
                ids.append(mid)
    return ids


def pick_vision_model(ids: list[str]) -> str | None:
    for wanted in VISION_PRIORITY:
        if wanted in ids:
            return wanted
    lowered = {mid.lower(): mid for mid in ids}
    for hint in VISION_HINTS:
        for low, mid in lowered.items():
            if hint in low:
                return mid
    return None


def placeholder_png() -> bytes:
    # Minimal valid PNG (64x80, solid color) built with stdlib only, so the
    # vision endpoint is exercised even when no card photo is available.
    w, h = 64, 80
    raw = b"".join(b"\x00" + bytes([180, 60, 60]) * w for _ in range(h))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def rate_for(model: str) -> tuple[float, float]:
    if "scout" in model.lower():
        return RATES_PER_MTOK["scout"]
    return DEFAULT_RATE


def estimate_cost(model: str, usage: dict) -> float | None:
    prompt = usage.get("prompt_tokens") or usage.get("input_tokens")
    completion = usage.get("completion_tokens") or usage.get("output_tokens")
    if prompt is None and completion is None:
        return None
    rate_in, rate_out = rate_for(model)
    rate_in = float(os.environ.get("PRESLAB_RATE_IN_PER_MTOK", rate_in))
    rate_out = float(os.environ.get("PRESLAB_RATE_OUT_PER_MTOK", rate_out))
    return (prompt or 0) / 1e6 * rate_in + (completion or 0) / 1e6 * rate_out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", help="Path to a card photo (jpg/png).")
    parser.add_argument(
        "--list-only", action="store_true", help="Only list models; skip the test call."
    )
    args = parser.parse_args()

    print("PreSlab backend connectivity check")
    print(f"API base: {API_BASE}")

    key = api_key()
    if not key:
        print("RESULT: FAIL - no API key found.")
        print("  LLAMA_API_KEY is not set in the environment.")
        print("  Get a key at https://llama.developer.meta.com (API keys tab), then run:")
        print('    export LLAMA_API_KEY="your key"')
        print("    backend/.venv/bin/python backend/connectivity_check.py --image <card photo>")
        print("  The key is read from the environment only; it is never stored in this repo.")
        return 2
    print(f"API key: present (length {len(key)}; value never printed)")

    # 1. List models on the account.
    status, body, latency = http_json("GET", f"{API_BASE}/models", key)
    print(f"\nGET /models -> HTTP {status} in {latency:.2f}s")
    if status != 200:
        print(f"  Response: {json.dumps(body)[:800]}")
        print("RESULT: FAIL - could not list models. Check the key and account access.")
        return 1
    ids = model_ids(body)
    print(f"Models available on this account ({len(ids)}):")
    for mid in ids:
        print(f"  - {mid}")
    if not ids:
        print(f"  Raw response: {json.dumps(body)[:800]}")

    vision = pick_vision_model(ids)
    if vision:
        print(f"Vision-capable models detected: "
              f"{[m for m in ids if any(h in m.lower() for h in VISION_HINTS)]}")
        print(f"Strongest vision model selected: {vision}")
    else:
        print("No vision-capable model found in the account's model list.")
        print("RESULT: FAIL - Meta API account has no vision model; "
              "Together AI fallback would be needed (per preslab-plan.md).")
        return 1

    if args.list_only:
        print("\nRESULT: OK (list-only; test call skipped).")
        return 0

    # 2. One test vision call.
    if args.image:
        with open(args.image, "rb") as fh:
            img_bytes = fh.read()
        mime = "image/png" if args.image.lower().endswith(".png") else "image/jpeg"
        image_note = f"user-supplied photo: {args.image} ({len(img_bytes)} bytes)"
    else:
        img_bytes = placeholder_png()
        mime = "image/png"
        image_note = "no --image given; synthetic placeholder PNG (not a real card)"
    data_url = f"data:{mime};base64," + base64.b64encode(img_bytes).decode()

    payload = {
        "model": vision,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": GRADING_PROMPT},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            }
        ],
        "max_tokens": 512,
        "temperature": 0.2,
    }
    print(f"\nTest call: POST /chat/completions, model={vision}")
    print(f"Image: {image_note}")
    status, body, latency = http_json("POST", f"{API_BASE}/chat/completions", key, payload)
    print(f"POST /chat/completions -> HTTP {status} in {latency:.2f}s")
    if status != 200:
        print(f"  Response: {json.dumps(body)[:1200]}")
        print("RESULT: FAIL - test call failed (see response above).")
        return 1

    content = ""
    try:
        content = body["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        pass
    print("\nModel returned:")
    print(content or json.dumps(body)[:1500])

    usage = body.get("usage") or {}
    print(f"\nToken usage: {json.dumps(usage) if usage else 'not reported by API'}")
    cost = estimate_cost(vision, usage)
    if cost is not None:
        print(f"Estimated cost of this call: ${cost:.6f} "
              f"(published hosted rates; check your Meta dashboard for billed actuals, "
              f"preview credits may cover it)")
    else:
        print("Estimated cost: unknown (API did not report token usage).")
    print(f"Latency: {latency:.2f}s")
    print("\nRESULT: OK - Meta API reachable, vision model responded.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
