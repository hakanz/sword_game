# PROJECT STATE
Last Updated: 2026-08-24
Updated By: Claude (autonomous session 1)

## Current Milestone
MVP core loop COMPLETE and playable end to end: character creation -> arena duels vs
generated opponents -> XP/levels/attributes/skills -> gold -> shop/inventory/equipment ->
champion challenge. Phases 1-5 done; Phase 6 MVP core done (1 arena, 1 champion; full
tournament brackets NOT yet built). Phase 7 partially done (UI theme + placeholder visual
polish); audio still silent placeholders.

## Current Game Version
0.1.0 (semver; also in project.godot)

## Working Systems
- Combat: turn-based duels, distance bands, hit/damage pipeline (armour pool w/ overflow,
  penetration, resistances hooks), defend/approach/retreat/rest, utility AI with
  personalities + anti-stall design, seeded RNG (`--combat-seed=`)
- Status effects: generic engine; poison/bleed/stun/slow/rage/regeneration
- Skills: 10 active skills, cooldowns, weapon-class gating, learning via skill points
- Progression: XP curve, levels 1-60, attribute allocation UI, multi-level-ups
- Economy: charisma-scaled buy/sell (no-money-loop invariant), combat gold, shop + inventory
  + equip with requirements ("two points away" anticipation)
- Champion: Maulhilda the Unmoved (unlock at 3 wins, one-time unique reward Doorslab)
- Persistence: versioned JSON saves (v4) with a tested v0->v4 migration chain; autosaves
- Localization: EN + TR complete (every player-visible string keyed; integrity-tested)
- Character creation: name, 3 origin presets, colors, live rig preview
- UI theme: global programmatic theme (UITheme), styled menus/HUD/bars

## Partially Implemented Systems
- Arena progression (§21): single arena region; tournaments/brackets NOT started
- Crowd system (§19): only "crowd impatience" pressure inside the AI; no audience meter
- Presentation (§40 P7): placeholder art polished, but no animation library, no VFX
  particles, and NO AUDIO CONTENT (buses + AudioManager wired, nothing plays)
- Accessibility (§28): no settings screen yet (no shake slider/gore toggle/remap UI)

## Known Bugs
- None known failing. Embedded-browser test pane showed a canvas-resize artifact after
  pane resizes (fresh loads at stable size render correctly); verify on a normal browser.

## Technical Debt
- Combat log RichTextLabel is not touch-drag scrollable (Phase 8 platform polish)
- Champion unique-reward pairing lives in ProgressionService.CHAMPION_REWARDS const —
  move into a champion roster resource when the roster grows
- Charter §34 debug menu not built (AI scores are emitted on EventBus but no overlay)
- OpponentGenerator uses one growth-weight archetype; archetype variety in Phase 9

## Current Test Status
GREEN this session: 19 suites / 1819 assertions
(`godot --headless --path . -s res://tests/test_runner.gd`), multi-seed AI-vs-AI smoke
(`--smoke-test --combat-seed=N`) resolves in 9-29 rounds, both sides can win.

## Platform Status
### Windows
WORKS (verified this session): editor run + exported ArenaLegends.exe passes smoke test.
### Linux / macOS
Untested — no environment available. Presets not created.
### Web
WORKS (verified this session): no-threads export loads and is playable in a Chromium
browser (menu -> duel -> damage/armour math visible). ~44 MB wasm.
### Android / iOS
NOT SET UP — no SDK/keystore in this environment. Do not claim until exported and run.

## Current Content
### Arenas: 1 (Gravelmaw) · Enemies: procedural generator (12 names × epithets, 3 AI
personalities + boss) · Champions: 1 (Maulhilda) · Weapons: 13 (5 classes, T1-T4) ·
Armour: 12 (5 slots, T1-T3) · Skills: 10 · Status Effects: 6

## Open Asset Requests
See docs/ASSET_MANIFEST.md — ALL art/audio is placeholder (primitives + silence).
Highest value next: combat SFX set, one music loop per state, real UI theme.

## Important Recent Decisions
- Armour = depleting pool with overflow (docs/combat.md); DoTs bypass armour
- AI utility currency = expected damage; anti-stall via decay+fatigue+impatience (docs/ai.md)
- Saves = versioned JSON, never serialized Resources (docs/saves.md)
- No third-party test framework (60-line runner, export-compat rationale in AI_GUIDE)
- Working title "Arena Legends" NEEDS a human trademark/name-collision check before any
  public release (charter §0.3) — NOT DONE, cannot be done by the agent

## Files Recently Changed
Everything — this was the bootstrap session (see DEVELOPMENT_LOG.md).

## Current Blocking Issues
- Android/iOS/Linux/macOS exports blocked on environment (SDKs/hosts)
- CI workflow authored but unverified until the repo's first GitHub push completes
- Trademark check for the title requires a human

## Recommended Next Task
Phase 6 completion: tournament structure (qualification -> final vs champion) +
a second arena region with level gating, per charter §21.

## Next 5 Tasks
1. Tournament loop (bracket state machine, scaling opponents, rewards, arena unlock)
2. Settings screen (volumes, locale, screen-shake slider, blood toggle stub, remap UI)
3. Crowd/audience meter (§19) wiring Charisma into combat
4. Random events between fights (§23, data-driven)
5. Balancing simulation tool (§35) + first tuning pass with its data
