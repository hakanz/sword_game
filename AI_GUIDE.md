# AI_GUIDE — Arena Legends (Permanent Constitution)

Every agent (AI or human) reads this file **before touching code**. It contains only durable
rules. Progress notes belong in `PROJECT_STATE.md`; history belongs in `DEVELOPMENT_LOG.md`.
The original full task charter is `MASTER_BUILD_PROMPT.md` (never edit it).

## Project Overview
Original 2D turn-based gladiator RPG. Working title **"Arena Legends"** (placeholder — a human
must run a trademark/name-collision check before any public release; see `PROJECT_STATE.md`).
Single-player, offline-first, commercial quality target. Inspired by the *genre* of classic
gladiator RPGs — **never copies names, stats, formulas, art, or text from any existing game**.
Forbidden: any proper noun resembling known Swords & Sandals content.

## Game Vision
`fight -> earn -> upgrade -> fight stronger -> become champion`, easy to learn, hard to master.
Emotional arc: weak nobody -> competent fighter -> famous gladiator -> arena champion -> legend.
Humorous cartoon-violence tone (see `docs/writing_style.md`). Priority order when goals clash:
**playable gameplay > correct architecture > maintainability > build diversity > progression
quality > combat feel > content volume > polish.**

## Technology Stack
- **Godot 4.4.1-stable (pinned).** Engine version bumps are explicit, documented decisions
  (decision-log format), never silent.
- **GDScript only**, fully typed. No C# (breaks/limits Web export).
- **Compatibility renderer** on all platforms (mobile/Web reach). Forward+ only behind a
  quality toggle if a specific effect demands it, with a Compatibility fallback.
- Local dev binary on this machine: `C:\Users\HAKAN\Tools\Godot\Godot_v4.4.1-stable_win64_console.exe`
  (machine-specific note; CI downloads its own copy).

## Supported Platforms
Mobile (Android API 26+, iOS last 3 majors), Desktop (Windows 10+, Ubuntu LTS, macOS 12+),
Web (current Chrome/Firefox/Safari + mobile equivalents). No Chrome-only APIs. Web export uses
**no threads** (browser compat; also charter §36). Combat is landscape-first; menus must stay
portrait-safe.

## Project Structure
```
autoload/    global services (EventBus, RngService, GameManager, SaveManager,
             AudioManager, LocalizationManager, SceneRouter)
combat/      combat systems (controller, combatant, turn manager, AI, calculators, tuning)
characters/  visual rigs and (later) character components
data/models/ typed Resource class definitions (WeaponData, SkillData, ...)
data/<cat>/  content instances as .tres (weapons, armour, characters, arenas, ...)
services/    cross-scene calculators (ProgressionCalculator, later EconomyCalculator)
scenes/      composition/presentation scenes (boot, menu, arena, results, ...)
ui/          UI scripts (HUD, menus)
localization/ strings.csv (EN+TR source of truth; .translation files are generated)
tests/       test_runner.gd + test_case.gd + unit/ suites; combat_fixtures.gd factories
audio/ vfx/ assets/ tools/  as they gain content
```

## Architecture Rules
1. **Data-driven content:** weapons, skills, armour, enemies, champions, arenas, status
   effects, events are Resources (`.tres`), never code branches. Never
   `if weapon_name == "X": damage = 30`.
2. **Data vs runtime state:** static definitions (`WeaponData`) never hold per-run state
   (durability, current HP). Runtime state lives in runtime objects (`Combatant`, later
   `EquippedWeapon`).
3. **Combat math is centralized:** `DamageCalculator`, `HitCalculator`,
   `ProgressionCalculator` (later `EconomyCalculator`). UI, AI, tooltips CALL them — nothing
   reimplements a formula. All tuning coefficients live in `CombatTuning`.
4. **No monolithic managers.** `GameManager` coordinates state; systems own their logic.
5. **Signals over coupling:** cross-system communication goes through `EventBus`. Scene-local
   wiring may use direct signals.
6. **Centralized RNG:** all gameplay randomness goes through `RngService` (seedable,
   `--combat-seed=N`). Decorative visuals must use local RNGs so combat replays stay
   deterministic.
7. Scenes are presentation/composition — never the source of truth for permanent data.
8. No premature complexity: no ECS, DI frameworks, event sourcing, microservices, or
   networking beyond the future `PlatformService` interface.
9. Do not redesign working systems without a concrete technical reason (what breaks, what
   depends on it, what tests protect it, does it affect save compatibility).

## Coding Standards
- Typed GDScript everywhere (`var x: int`, typed signals, typed arrays). Fix warnings.
- `class_name` for every reusable class; file names snake_case matching class content.
- Doc comments (`##`) on every class explaining role and boundaries.
- Small commits, one system/concern each: `combat: ...`, `docs: ...`, `data: ...`, `ui: ...`,
  `tests: ...`, `core: ...`, `ci: ...`.
- Commit `.uid` and `.import` sidecar files; never commit `.godot/` or `*.translation`.

## Godot Rules
- Anchors/containers for ALL UI — no hardcoded pixel positions. Base viewport 1280x720,
  stretch `canvas_items` + `expand`.
- Never rely on hover/right-click/keyboard for gameplay-critical actions (touch-first).
- Buttons for combat actions: minimum ~48 logical px touch targets.
- Audio buses: Master/Music/SFX/UI/Voice/Ambience (`audio/default_bus_layout.tres`).
- Web: audio only after first user gesture; no SharedArrayBuffer/threads dependency.

## Combat Architecture
See `docs/combat.md` for formulas. Flow: `CombatController` orchestrates
`TurnManager` (initiative order) -> player HUD input or `CombatAI` (utility scores, see
`docs/ai.md`) -> `CombatAction` validation -> calculators -> `Combatant` state -> `EventBus`
events -> HUD/rig presentation. Damage pipeline order is fixed (charter §15); armour is a
depleting pool; excess damage always carries into HP. Hit chance clamped 5%–95%.

## Character / Item / Skill Architecture
- 8 attributes (`AttributeBlock`): strength, agility, attack, defence, vitality, stamina,
  arcana, charisma. Derived stats ONLY via `ProgressionCalculator`.
- **No hard classes** — builds emerge from attributes + skills + equipment (deliberate design
  decision, departs from the genre's binary class split).
- Charisma must remain combat-relevant (crowd system in a later phase).
- Items: `WeaponData`/`ArmourData` with tiers T1–T8, rarity Common..Mythic, attribute/level
  requirements. Items carry stable logical IDs (`weapon.pit_hatchet`); gameplay references
  IDs, never image paths.
- Skills: `SkillData` resources; combat wiring lands in the skill-system phase.

## Enemy AI Architecture
Utility-based scoring in a single currency (expected damage dealt/prevented) — never uniform
random. Personalities (`AIPersonality` weights) change behavior with identical gear.
Anti-stall: consecutive DEFEND/RETREAT decay (see `docs/ai.md`). Champions are handcrafted;
normal opponents may be procedurally generated later. AI reads state via the same calculators
as the UI.

## Save System Architecture
`SaveManager` (settings now; character slots with **mandatory `save_version` + migration**
when progression lands). Offline-first, local files, no server. Save tampering protection is
an explicit non-goal (single-player). Autosave points: after battle/purchase/level-up,
around tournaments, on app backgrounding — never mid-action.

## Localization Rules
EN + TR from day one. Source of truth `localization/strings.csv` (keys,en,tr). Player-visible
strings ALWAYS via `tr("key")` — hardcoded display text is a bug. Proper names (fighters) are
raw strings. UI containers must tolerate text expansion. Locale-aware number formatting when
currencies/plurals arrive.

## Asset Pipeline
Placeholders first, always (primitive-drawn rigs/arenas, silence for audio). Every missing
real asset is tracked in `docs/ASSET_MANIFEST.md` + `PROJECT_STATE.md -> Open Asset Requests`.
Producing final art/audio is a **human-driven task**; the agent wires drop-in replacement
paths and never claims a placeholder is final. Visual assets get stable logical IDs.

## Monetization Boundary
MVP/vertical slice: premium or free-without-IAP. **No real-money purchases, no ad/analytics
SDKs, no telemetry** (off by default, opt-in only, post-MVP decision requiring human
sign-off). Gambling events wager in-game gold only. Any future store SDK goes behind
`PlatformService` — core gameplay never calls platform SDKs directly.

## Testing Rules
- Custom lightweight runner: `tests/test_runner.gd` (no third-party framework — dependency
  export-compat vetting per charter §37 made a 60-line runner the safer choice).
  Run: `godot --headless --path . -s res://tests/test_runner.gd` (exit 0 = green).
- Unit tests required for all mathematical systems (damage, hit, progression, prices, XP,
  save migration) incl. edge cases (0 armour, 100% resistance, negative values, max level).
- End-to-end smoke: `godot --headless --path . -- --smoke-test --combat-seed=N` plays a full
  AI-vs-AI duel and exits 0/1. Keep it green.
- Also test the real game: launch the affected scene after changes (charter §10.11).

## Performance Rules
60 FPS target on ordinary phones (optional 30 FPS battery mode later). Sprite atlases,
pooling, particle limits when content arrives. Web: small download, no threads. Profile
before optimizing; don't guess.

## Platform Compatibility Rules
Before adding ANY plugin/native extension: verify Windows + Android + Web export compat and
document the decision here. No browser APIs outside the supported matrix.

## Forbidden Practices
- Hardcoded content in logic; formulas re-implemented in UI/AI; scattered `randi()`.
- C#; Chrome-only APIs; threads on Web.
- Fake/unimplemented buttons left unmarked; claiming untested platforms work.
- Real-money mechanics of any kind (see Monetization Boundary).
- Editing `MASTER_BUILD_PROMPT.md`; deleting `DEVELOPMENT_LOG.md` history.
- Copying names/stats/art from existing games (see Project Overview).

## Documentation Rules
`AI_GUIDE.md` = durable rules only. `PROJECT_STATE.md` = current snapshot, updated every
meaningful session, stale info removed. `DEVELOPMENT_LOG.md` = append-only session history.
`/docs/*.md` = per-system technical detail (formulas must be documented there). Decision log
format for big choices: Decision / Reason / Alternatives / Consequences (in
`docs/decisions/` or inline in the system doc).

## Current Development Workflow
Phases (charter §40): 1 Foundation ✓ -> 2 Combat Prototype ✓ -> 3 Progression -> 4 Equipment
-> 5 Skills -> 6 Arena Progression -> 7 Presentation -> 8 Platform Polish -> 9 Content ->
10 QA/Balance. A phase chunk is done only when: tests pass, scenes launch clean, desktop runs,
Web smoke-checked when the phase touches rendering/input/audio, docs updated, no unmarked
placeholders (charter §41).

## How to Start a Task
1. Read this file -> `PROJECT_STATE.md` -> recent `DEVELOPMENT_LOG.md` entries.
2. Inspect the relevant source + tests. 3. Scope one coherent chunk (never "build the game").
4. Only then modify code.

## How to Finish a Task
1. Run unit tests + smoke test; launch affected scenes. 2. Fix new warnings/errors.
3. Update `PROJECT_STATE.md`; append `DEVELOPMENT_LOG.md`; update this file ONLY if something
   permanent changed. 4. Commit in small, labeled steps. 5. State the recommended next task.
