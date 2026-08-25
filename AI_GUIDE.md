# AI_GUIDE — Arena Legends (Permanent Constitution)

Every agent (AI or human) reads this file **before touching code**. It contains only durable
rules. Progress notes belong in `PROJECT_STATE.md`; history belongs in `DEVELOPMENT_LOG.md`.
The original full task charter is `MASTER_BUILD_PROMPT.md` (never edit it).
`MASTER_BUILD_PROMPT_V2.md` (session 7) is a dated amendment on top of it — read it too; it
reaffirms the no-hard-classes decision (§47), audits what already exists so it isn't
re-proposed, and gives the current precision-targeted expansion plan (combat feel/camera,
itemization affixes, AI depth, crowd/Charisma, rivals+boss phases). Future amendments append
new dated §-sections there rather than editing v1.

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
- **Godot 4.7 (pinned; project owner bumped from 4.4.1 on 2026-08-24, commit "Update
  project settings for Godot 4.7").** Engine version bumps are explicit, documented
  decisions (decision-log format), never silent.
- **GDScript only**, fully typed. No C# (breaks/limits Web export).
- **Compatibility renderer** on all platforms (mobile/Web reach). Forward+ only behind a
  quality toggle if a specific effect demands it, with a Compatibility fallback.
- Local dev binary on this machine: `C:\Users\HAKAN\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`
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
assets/generated/ produced textures (docs/art.md); assets/icons/ original SVG glyphs
audio/ tools/ tools/texgen/  as they gain content
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
10. **Combat-feel pacing lives in ONE table** (`CombatFeel`): windup/swing/recovery/hit-stop/
    shake/lunge per `WeaponClass`. Rig animation and controller timing both read it; nothing
    hardcodes a second copy. Presentation may never change a resolved result — hit-stop wraps
    already-resolved outcomes and camera work only reads positions.
11. **Equipment modifiers are DERIVED, never stored.** `ItemAffixes` computes an item's
    affixes from the item's own identity with a LOCAL rng (docs/items.md decision block), so
    itemization needs no save version. Combat reads `Combatant.attributes` (progression +
    kit) — equipment never writes into a character's own `AttributeBlock`.
12. **A setting key belongs to the system that READS it** (`CombatFeel.REDUCED_FX_SETTING`,
    `CombatController.SHAKE_SETTING`, `CombatCamera.MOTION_SETTING`); the settings screen
    writes through those constants so the two sides cannot drift apart.
13. **Gameplay judgement lives in CombatResolver, not the controller.** The crowd meter,
    signature effects and anti-stall counters are all applied there, because the §35
    simulator drives the resolver directly — anything that changes a fight must be felt by
    a simulated fight too. The controller only PRESENTS.
14. **Personalities and boss phases are weighted DATA, never branches.** One AI scoring
    formula reads `AIPersonality.aggression_now()`; a champion's phase releases skills and
    swaps a personality resource. Adding a temperament or a boss is a content task.
15. **Dev-only tools must remove themselves in release builds** (`AiDebugOverlay`), and
    dev entry points that need autoload singletons must load their implementation at
    RUNTIME — a `-s` main script compiles before autoloads register (docs/build.md).
16. **No drawing code may assume a texture exists.** Per-item textures live in DATA slots
    on the resource (`WeaponData.sprite`, `ArmourData.icon`/`material_texture`,
    `ArenaData.backdrop`, `CharacterData.portrait`, `SkillData`/`StatusEffectData.icon`);
    everything else resolves through `ArtLibrary`, which returns `null` when a file is
    absent. EVERY consumer keeps its primitive-drawn path alive for that null, so an item
    authored with an empty slot still renders. Note the boundary: a texture BOUND from a
    `.tres` is a normal Godot dependency — deleting that file breaks the resource at load
    time, like deleting any other referenced file. Regenerate with `tools/texgen`; never
    delete. Gameplay still references logical IDs, never image paths (docs/art.md).

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
Owner directives (2026-08-24): attacks only at ADJACENT (enforced in weapon data);
movement is personal (per-fighter cells — see docs/combat.md); no combat log panel.
Action execution lives in CombatResolver (pure); CombatController only presents.

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
Visual assets get stable logical IDs.

Textures are GENERATED by `tools/texgen` (pipeline, keying modes and prompt rules in
`docs/art.md`); the API key comes from the environment and is never committed. Generated
art is `generated`, **not** `final`: it has had no art-director pass, and nothing may
describe it as finished art. Signing art off — and producing final audio, still entirely
placeholder — remains a human-driven task.

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
- Assertions must be able to FAIL: a bound the data can never reach, or a value that is
  identical on both sides of the behaviour under test, is not coverage (session-7 review
  found three such). Prefer driving the real widget/helper over asserting a constant.
- `test_script_integrity.gd` compiles every `.gd` in the project — a screen whose script
  fails to parse still instantiates as a bare node, so scene smoke alone can go green while
  a menu is dead.
- Content is testable too: suites assert catalog-wide invariants (every region has a rival,
  every Legendary carries a signature, every event string is translated in both languages,
  melee weapons never reach past ADJACENT). A content bug should fail CI, not playtesting.
- End-to-end smoke: `godot --headless --path . -- --smoke-test --combat-seed=N` plays a full
  AI-vs-AI duel and exits 0/1. Keep it green.
- Balance simulation (charter §35): `godot --headless --path . -s res://tools/battle_sim.gd
  -- --battles=300` runs the REAL combat stack headlessly (CombatResolver — the single
  execution path shared with CombatController). Tune with its data, log in docs/balancing.md.
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
