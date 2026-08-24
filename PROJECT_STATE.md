# PROJECT STATE
Last Updated: 2026-08-24
Updated By: Claude (autonomous session 5)

## Current Milestone
MVP core loop COMPLETE and playable end to end: character creation -> arena duels vs
generated opponents -> XP/levels/attributes/skills -> gold -> shop/inventory/equipment ->
champion challenge. ALL charter phases now have their core systems in place:
P6 COMPLETE for current scope (arena regions + 4-round tournaments ending in the
region champion; winning unlocks the next region; 2 arenas / 2 champions).
P7: theme/icons/VFX/synth-SFX. P8: settings screen (volumes, language, screen-shake
slider, reduced-fx toggle) + in-combat pause overlay (touch button + Esc).
P9: content grown to 20 weapons / 18 armour / 14 skills / 9 statuses / 2 arenas.
P10: §35 battle simulator EXISTS (tools/battle_sim.gd, drives the real
CombatResolver stack) and its data drove a real tuning pass (docs/balancing.md).
Engine: Godot 4.7 (owner bump; verified with 4.7.2-stable).
Owner directives in effect: melee only at ADJACENT; bows ranged with 4 arrows +
knife sidearm + switch action; per-fighter movement; no combat-log panel; rest heals;
enemy energy visible; RADIAL action menu around the gladiator; split street merchants
(price-sorted, item glyphs); Dustwell town hub; auto-equip upgrades with sell offer;
session 4: genre-reference visual bar — rig v3 draws equipped armour + tier-tinted
weapons ON the body; arena crowd is individually drawn figures (original designs only);
session 5: free point-buy creation (unspent -> attribute points); player always opens
the fight; mobility tiers (agility + gear, 2-cell moves at score 14+); effectiveness
XP (landed/actions in [0.65,1.25], champion x1.5); the arena's call (forced tournament
at band midpoint, elite brackets, house gold bonus); rig v4 living animations +
expressions + 1.35x; elemental skill VFX; shop fitting booth + sealed level-locks;
level/XP bars in HUD + town.

## Current Game Version
0.1.0 (semver; also in project.godot)

## Working Systems
- Arena progression: 2 regions with level bands, per-region 4-round tournaments
  (final = handcrafted champion), region unlock chain, arena select screen
- Combat: turn-based duels, per-fighter positional cells, hit/damage pipeline (armour pool w/ overflow,
  penetration, resistances hooks), defend/approach/retreat/rest, utility AI with
  personalities + anti-stall design, seeded RNG (`--combat-seed=`)
- Status effects: generic engine; poison/bleed/stun/slow/rage/regeneration
- Skills: 10 active skills, cooldowns, weapon-class gating, learning via skill points
- Progression: XP curve, levels 1-60, attribute allocation UI, multi-level-ups
- Economy: charisma-scaled buy/sell (no-money-loop invariant), combat gold, shop + inventory
  + equip with requirements ("two points away" anticipation)
- Champions: Maulhilda (tank, Doorslab) + Orzha Sablewind (duelist, Sablefang) —
  fought as tournament finals; one-time unique rewards with rematch guards
- Persistence: versioned JSON saves (v5) with a tested v0->v5 migration chain; autosaves
- Localization: EN + TR complete (every player-visible string keyed; integrity-tested)
- Character creation: name, 3 origin presets, colors, live rig preview (2.4x)
- UI theme: global programmatic theme (UITheme), styled menus/HUD/bars
- Visuals: rig v3 (3-tone anatomy, face detail, per-slot armour overlays,
  per-class tier-tinted weapon drawings, grip fist, defend shield); arena v2
  (drawn crowd tiers w/ cheering figures, brick wall, barred pen gates, columns)

## Partially Implemented Systems
- Crowd system (§19): only "crowd impatience" pressure inside the AI; no audience meter
- Random events (§23), death/difficulty modes + NG+ (§24), achievements (§33),
  debug menu overlay (§34): not started
- Presentation (§40 P7): placeholder art polished; sparks/shake/synth-SFX exist.
  Still missing: real animation library, music tracks, final foley
- Accessibility (§28): settings has volumes/shake/reduced-fx/language; still missing:
  key-remap UI (no gameplay key bindings exist yet — combat is pointer/touch driven),
  colorblind-checked status icons, text scaling

## Known Bugs
- None known failing. Embedded-browser test pane showed a canvas-resize artifact after
  pane resizes (fresh loads at stable size render correctly); verify on a normal browser.

## Technical Debt
- Champion unique-reward pairing lives in ProgressionService.CHAMPION_REWARDS const —
  move into a champion roster resource when the roster grows
- Charter §34 debug menu not built (AI scores are emitted on EventBus but no overlay)
- OpponentGenerator uses one growth-weight archetype; archetype variety in Phase 9

## Current Test Status
GREEN this session: 22 suites / 2343 assertions (Godot 4.7.2); §35 simulator:
6 matchups × 300 battles, 0 stalemates, presets in the 40-60% band
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
### Arenas: 2 (Gravelmaw 1-8, Emberholt 8-16) · Enemies: procedural generator (+elite
bracket variant) · Champions: 2 (Maulhilda, Orzha) · Weapons: 29 (6 classes; 4 bows +
knife, T1-T5) · Armour: 26 (7 slots, T1-T5; 3 mobility pieces) · Skills: 14 (incl.
2 mana spells) · Status Effects: 9

## Open Asset Requests
See docs/ASSET_MANIFEST.md — all art/audio is placeholder (primitives, original SVG
icons, runtime-synthesized SFX). Highest value next: real foley to replace the
synthesized cues, one music loop per state, art-directed UI theme.

## Important Recent Decisions
- Armour = depleting pool with overflow (docs/combat.md); DoTs bypass armour
- AI utility currency = expected damage; anti-stall via decay+fatigue+impatience (docs/ai.md)
- Saves = versioned JSON, never serialized Resources (docs/saves.md)
- No third-party test framework (60-line runner, export-compat rationale in AI_GUIDE)
- Working title "Arena Legends" NEEDS a human trademark/name-collision check before any
  public release (charter §0.3) — NOT DONE, cannot be done by the agent

## Files Recently Changed
Session 5: combat/{turn_manager,combat_context,combat_resolver,combat_result,
combatant,combat_controller,combat_vfx}, services/{progression_calculator,
progression_service,opponent_generator}, autoload/game_manager,
data/models/{armour_data,character_data,progression_config,economy_config},
characters/components/placeholder_rig.gd (rig v4), ui/{character_creation,
shop_screen,combat_hud,results_screen,town_screen}, scenes (creation, shop),
+16 item .tres + registry, tests/unit/test_session5_rules.gd.
Session 4: rig v3, arena_visual crowd/wall v2 (see DEVELOPMENT_LOG.md).

## Current Blocking Issues
- Android/iOS/Linux/macOS exports blocked on environment (SDKs/hosts)
- CI workflow authored but unverified until the repo's first GitHub push completes
- Trademark check for the title requires a human

## Recommended Next Task
Crowd/audience meter (§19) wiring Charisma into combat — the last big MVP-vision
system without a first implementation.

## Next 5 Tasks
1. Crowd/audience meter (§19): excitement states, Charisma/taunt hooks, small rewards
2. Random events between fights (§23, data-driven)
3. Difficulty tiers + defeat consequences + Iron Gladiator flag (§24)
4. Third arena region + champion; more enemy archetypes (mage/skirmisher growth weights)
5. Economy simulation (§35 second half): gold-per-level vs gear costs, grind check
