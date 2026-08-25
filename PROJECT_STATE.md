# PROJECT STATE
Last Updated: 2026-08-25
Updated By: Claude (session 7 - phases 11-12: combat feel/camera + itemization depth)

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
level/XP bars in HUD + town;
session 7 (V2 phases 11-12): weapon-weight combat pacing + impact hit-stop +
dynamic framing camera; rarity now grants item modifiers, three Legendary
signature effects, and an equipped-vs-candidate comparison in shop/inventory;
session 6: town-first debut (armourless, Worn Shiv, LONG opening distance, level-1
foes equally bare), first-victory debut purse + guaranteed level-up, weapon-based
crits (per-weapon base + class-matched attribute, x2, shown in shop/sheet), weapon
memory + defeat fatigue (save v6), auto-rest at 0 energy, per-skill point costs +
build-guidance recommendations, victory celebration animation.

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
- Persistence: versioned JSON saves (v6) with a tested v0->v6 migration chain; autosaves
- Localization: EN + TR complete (every player-visible string keyed; integrity-tested)
- Character creation: name, 3 origin presets, colors, live rig preview (2.4x)
- UI theme: global programmatic theme (UITheme), styled menus/HUD/bars
- Visuals: rig v3 (3-tone anatomy, face detail, per-slot armour overlays,
  per-class tier-tinted weapon drawings, grip fist, defend shield); arena v2
  (drawn crowd tiers w/ cheering figures, brick wall, barred pen gates, columns)
- Combat feel (V2 §51): CombatFeel is the one table of weapon-weight pacing
  (windup/swing/recovery/hit-stop/shake/lunge/style per WeaponClass); impact
  hit-stop via a bounded Engine.time_scale dip; CombatCamera frames both
  fighters, zooms with separation and punches in on crits/kills, and owns the
  impact shake. Accessibility: reduced_fx shortens the freeze, a new Camera
  Motion slider (0 = the classic static frame) governs all camera movement
- Itemization depth (V2 §52): rarity grants 0-4 derived modifiers per item from
  a 15-affix pool (deterministic per item id — no save-version change), three
  Legendary signature effects hooked into existing systems, and shop/inventory
  rows showing rarity, modifiers and colour-coded deltas vs the equipped piece

## Partially Implemented Systems
- Crowd system (§19 / V2 §54): only "crowd impatience" pressure inside the AI;
  no audience meter yet - THE next task
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
- Item modifiers are derived per item id, so two copies of an item are identical
  (deliberate - decision block in docs/items.md); per-drop rolls would need a
  per-instance item model and a save migration
- V2 §49's gap list says only the `aggressive` AI personality ships - stale:
  aggressive/defensive/cautious/boss resources all exist and OpponentGenerator
  already picks from three. Phase 14 is about PAIRING them with builds and the
  score overlay, not about creating the roster from nothing

## Current Test Status
GREEN this session: 27 suites / 3910 assertions (Godot 4.7.2); §35 simulator:
6 matchups × 150 battles, 0 stalemates, presets in the 40-53% band
(default-kit-vs-generated dropped to 81/63/50% at L1/5/10 now that generated
opponents carry modifier-bearing gear - accepted, see docs/balancing.md)
(`godot --headless --path . -s res://tests/test_runner.gd`), multi-seed AI-vs-AI smoke
(`--smoke-test --combat-seed=N`) resolves in 9-29 rounds, both sides can win.

## Platform Status
### Windows
WORKS: editor run + exported ArenaLegends.exe pass the smoke test (last verified
session 7, after the camera/hit-stop and itemization work).
### Linux / macOS
Untested — no environment available. Presets not created.
### Web
WORKS: no-threads export loads and is playable in a Chromium browser
(menu -> duel -> damage/armour math visible), ~44 MB wasm. Last browser-verified
session 6; session 7 changed rendering (Camera2D + Engine.time_scale), so
re-verify in a browser before any release build.
### Android / iOS
NOT SET UP — no SDK/keystore in this environment. Do not claim until exported and run.

## Current Content
### Arenas: 2 (Gravelmaw 1-8, Emberholt 8-16) · Enemies: procedural generator (+elite
bracket variant; level-1 foes armourless) · Champions: 2 (Maulhilda, Orzha) ·
Weapons: 31 (6 classes; 4 bows + knife + starter shiv, T1-T5, per-weapon crit;
2 champion Legendaries + 1 Legendary chase purchase) ·
Armour: 26 (7 slots, T1-T5; 3 mobility pieces) · Skills: 14 (point costs 1-3, incl.
2 mana spells) · Status Effects: 9 · Affixes: 15 · Signature effects: 3

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
Session 7 (phases 11-12): NEW combat/{combat_feel,combat_camera}.gd,
services/item_affixes.gd, ui/item_compare.gd, data/models/affix_data.gd,
data/affixes/*.tres (15), data/weapons/venomtooth_cleaver.tres,
tests/unit/{test_combat_feel,test_itemization,test_script_integrity}.gd;
CHANGED combat/{combat_controller,combatant,combat_resolver,damage_calculator,
hit_calculator,status_effect_system,combat_vfx}.gd,
characters/components/placeholder_rig.gd, ui/{combat_hud,shop_screen,
inventory_screen,settings_screen}.gd, services/opponent_generator.gd,
autoload/{item_db,game_manager}.gd, data/models/{enums,weapon_data,armour_data,
item_registry}.gd, scenes/arena/arena.tscn, data/registry/item_registry.tres,
localization/strings.csv, docs/{combat,items,balancing}.md.
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
Phase 13 (MASTER_BUILD_PROMPT_V2.md §54): the crowd / audience meter -
Hostile→Bored→Neutral→Excited→Frenzied, fed by crits, guarded blows under
pressure and taunt-tagged skills, decayed by the EXISTING anti-stall counters;
small situational reward at Excited/Frenzied and Charisma driving the climb
rate. This is what finally makes Charisma a combat stat (charter §13/§19). The
meter resets per fight, so no save-version change unless cross-fight state is
added.

## Next 5 Tasks
(Re-sequenced this session per MASTER_BUILD_PROMPT_V2.md §56, content ordered after
combat-feel/build-diversity work per the charter's own priority order.)
1. Phase 13 - Crowd/audience meter (§19 / V2 §54): excitement states, Charisma/taunt
   hooks, situational reward, HUD element
2. Phase 14 - AI depth: pair the EXISTING personalities with generated builds via the
   Weapon Mastery Archetype table (V2 §50), per-champion personalities, and the
   AI-score debug overlay (the EventBus feed already exists) (V2 §53)
3. Phase 15 - Rivals + champion boss phases (V2 §55); new save version for rival state
4. Phase 16 - Third arena region + champion, random events (§23), difficulty tiers/NG+
   (§24), economy simulation pass
5. Deferred/known: the derived Weapon Mastery Archetype label itself (V2 §47/§50) is
   still unbuilt - `ProgressionCalculator.combat_archetype_label()` plus its character-
   sheet display; it is the input Phase 14's personality pairing needs

## Important Recent Decisions (session 7 addition)
- Classless builds stay; no hard Warrior/Assassin/Archer/Mage classes - confirmed by the
  owner 2026-08-25 after an audit against a class-based redesign prompt. Class-fantasy value
  is delivered via a derived, non-gating "Weapon Mastery Archetype" label instead (see
  MASTER_BUILD_PROMPT_V2.md §47/§50). Full rationale, gap analysis, and phase plan live in
  the new MASTER_BUILD_PROMPT_V2.md charter amendment.
