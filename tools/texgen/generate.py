"""Generates the game's textures from manifest.py via the Gemini image model.

Usage (the key is NEVER stored in the repo -- pass it through the environment):

    GEMINI_API_KEY=... python tools/texgen/generate.py               # everything missing
    GEMINI_API_KEY=... python tools/texgen/generate.py vfx/ ui/coin  # only these prefixes
    GEMINI_API_KEY=... python tools/texgen/generate.py --force vfx/  # redo them

Behaviour that matters:
  * RESUMABLE -- an asset whose output file already exists is skipped, so an
    interrupted run costs nothing to restart.
  * The raw model output is cached under .texgen_raw/ (gitignored) so the
    post-processing can be re-tuned without paying for generation again;
    --repost re-derives every texture from that cache with no API calls.
  * Failures are collected and reported at the end rather than aborting.
"""
from __future__ import annotations

import base64
import io as _io
import os
import sys
import threading
import time
import traceback
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import imageops
import manifest

MODEL = "models/gemini-3.1-flash-lite-image"
REPO = Path(__file__).resolve().parents[2]
OUT_ROOT = REPO / manifest.ROOT
RAW_ROOT = REPO / ".texgen_raw"
WORKERS = int(os.environ.get("TEXGEN_WORKERS", "4"))
ATTEMPTS = 4

_print_lock = threading.Lock()


def log(*parts) -> None:
    with _print_lock:
        print(*parts, flush=True)


def _client():
    from google import genai
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        raise SystemExit("GEMINI_API_KEY is not set; refusing to run.")
    return genai.Client(api_key=key)


def request_image(client, spec) -> bytes:
    """One generation call. Returns raw encoded image bytes."""
    config = {
        "temperature": 1,
        "max_output_tokens": 65536,
        "top_p": 0.95,
        "thinking_level": "minimal",
        "image_config": {"image_size": "1K", "aspect_ratio": spec["aspect"]},
    }
    interaction = client.interactions.create(
        model=MODEL,
        input=spec["prompt"],
        generation_config=config,
        response_modalities=["image", "text"],
    )
    for step in interaction.steps:
        if step.type != "model_output" or not step.content:
            continue
        for part in step.content:
            if part.type == "image":
                return base64.b64decode(part.data)
    raise RuntimeError("model returned no image")


def postprocess(raw: bytes, spec) -> Image.Image:
    """Raw model bytes -> the exact texture the game imports."""
    src = Image.open(_io.BytesIO(raw))
    mode = spec["mode"]
    if mode == "cutout":
        art = imageops.cutout(src)
        art = imageops.trim(art) if spec["square"] else imageops.trim_vertical(art)
        art = imageops.soften_edge(art)
        return imageops.contain(art, spec["size"]) if not spec["square"] \
            else imageops.fit(art, spec["size"], cover=False)
    if mode == "glow":
        art = imageops.soften_edge(imageops.glow(src))
        return imageops.fit(art, spec["size"], cover=True)
    if mode == "tile":
        return imageops.seamless(imageops.fit(src, spec["size"], cover=True))
    return imageops.fit(src.convert("RGB"), spec["size"], cover=True)


def out_path(spec) -> Path:
    return OUT_ROOT / f"{spec['key']}.{spec['fmt']}"


def raw_path(spec) -> Path:
    return RAW_ROOT / f"{spec['key']}.jpg"


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix == ".webp":
        image.convert("RGB").save(path, "WEBP", quality=92, method=5)
    else:
        image.save(path, "PNG", optimize=True)


def produce(client, spec, force: bool) -> str:
    dest = out_path(spec)
    if dest.exists() and not force:
        return "skip"
    cached = raw_path(spec)
    raw = None
    if cached.exists() and not force:
        raw = cached.read_bytes()
    if raw is None:
        last = None
        for attempt in range(ATTEMPTS):
            try:
                raw = request_image(client, spec)
                break
            except Exception as exc:  # noqa: BLE001 - report, keep the batch alive
                last = exc
                time.sleep(2.0 * (attempt + 1))
        if raw is None:
            raise RuntimeError(f"generation failed: {last}")
        cached.parent.mkdir(parents=True, exist_ok=True)
        cached.write_bytes(raw)
    save(postprocess(raw, spec), dest)
    return "made"


def main(argv: list[str]) -> int:
    force = "--force" in argv
    repost = "--repost" in argv
    prefixes = [a for a in argv if not a.startswith("--")]

    specs = manifest.all_assets()
    if prefixes:
        specs = [s for s in specs if any(s["key"].startswith(p) for p in prefixes)]
    if not specs:
        log("nothing matched")
        return 1

    if repost:
        done = 0
        for spec in specs:
            cached = raw_path(spec)
            if not cached.exists():
                continue
            save(postprocess(cached.read_bytes(), spec), out_path(spec))
            done += 1
        log(f"re-processed {done}/{len(specs)} from the raw cache")
        return 0

    client = _client()
    counts = {"made": 0, "skip": 0}
    failures: list[tuple[str, str]] = []
    total = len(specs)
    started = time.time()

    def work(index_spec):
        index, spec = index_spec
        try:
            status = produce(client, spec, force)
        except Exception as exc:  # noqa: BLE001
            failures.append((spec["key"], f"{exc}"))
            log(f"[{index + 1}/{total}] FAIL {spec['key']}: {exc}")
            return
        counts[status] += 1
        if status == "made":
            elapsed = time.time() - started
            log(f"[{index + 1}/{total}] {spec['key']}  ({elapsed:.0f}s)")

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        list(pool.map(work, enumerate(specs)))

    log(f"done: {counts['made']} generated, {counts['skip']} already present, "
        f"{len(failures)} failed, {time.time() - started:.0f}s")
    for key, reason in failures:
        log(f"  FAILED {key}: {reason}")
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        sys.exit(2)
