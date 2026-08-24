# Arena Legends (working title)

Original 2D turn-based gladiator RPG built with **Godot 4.4.1** (GDScript, Compatibility
renderer). Single-player, offline-first. Targets: Windows/Linux/macOS, Android/iOS, Web.
Working title is a placeholder pending a human trademark check.

## Current state
Playable combat prototype: main menu (EN/TR) -> arena duel vs an AI gladiator
(attack/defend/approach/retreat/rest, distance bands, armour pool, utility AI) -> results
screen. Placeholder primitive art by design — see `docs/ASSET_MANIFEST.md`.
Details: `PROJECT_STATE.md`.

## Run
Open the project in Godot 4.4.1 and press F5, or:
```
godot --path . 
```

## Tests
```
godot --headless --path . -s res://tests/test_runner.gd     # unit suites
godot --headless --path . -- --smoke-test --combat-seed=42  # full AI-vs-AI duel, exit 0/1
```

## Contributing / agent workflow
Read `AI_GUIDE.md` (constitution) -> `PROJECT_STATE.md` (snapshot) -> `DEVELOPMENT_LOG.md`
(history) before changing anything. The original build charter is `MASTER_BUILD_PROMPT.md`
(do not edit).
