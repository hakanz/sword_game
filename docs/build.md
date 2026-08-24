# Build & Export — Repeatable Process

Engine: **Godot 4.4.1-stable, pinned** (AI_GUIDE.md). Local binary on this machine:
`C:\Users\HAKAN\Tools\Godot\Godot_v4.4.1-stable_win64_console.exe`.
Export templates: official 4.4.1 `.tpz` installed under
`%APPDATA%\Godot\export_templates\4.4.1.stable\`.

## Verification (run before every export/commit)
```
godot --headless --path . --import
godot --headless --path . -s res://tests/test_runner.gd          # exit 0 required
godot --headless --path . -- --smoke-test --combat-seed=42       # exit 0 required
```

## Web (preset "Web" — threads OFF for browser compat, charter §36)
```
godot --headless --path . --export-release "Web" builds/web/index.html
python -m http.server 8060 --directory builds/web    # any static server works
```
No COOP/COEP headers needed (no-threads build). Verified loading + playable in
a Chromium browser this session. ~44 MB wasm + <1 MB pck.

## Windows (preset "Windows Desktop")
```
godot --headless --path . --export-release "Windows Desktop" builds/windows/ArenaLegends.exe
```
The exported exe passes the headless smoke test
(`ArenaLegends.exe --headless -- --smoke-test --combat-seed=42`).

## Android / iOS / Linux / macOS
NOT yet set up in this environment (no Android SDK/keystore, no macOS host).
Tracked in PROJECT_STATE.md -> Current Blocking Issues. Never claim these work
until actually exported and run (charter §9).

## CI
`.github/workflows/ci.yml`: downloads pinned Linux Godot, imports, runs the
unit suite + 3-seed smoke on every push/PR. (Runs once the repo is pushed to
GitHub; unverified until the first push completes.)

## Dev screenshot mode
`godot --path . -- --screenshot-dir=<dir>` captures menu/creation/arena PNGs
(windowed run; disk writes disabled) — used for visual regression checks.
