# DEVELOPMENT LOG
Chronological, append-only. One entry per meaningful session.

---

## Session 1 — 2026-08-24 — Bootstrap through MVP core loop (Claude, autonomous)

### Added
- **Foundation (P1):** Godot 4.4.1-stable pinned; GL Compatibility renderer; project
  skeleton per charter §6; autoloads (EventBus, RngService seeded + `--combat-seed=`,
  GameManager, SaveManager, ItemDB, LocalizationManager, AudioManager buses, SceneRouter);
  EN+TR localization pipeline (strings.csv, integrity-tested); AI continuity docs.
- **Combat prototype (P2):** typed data models; HitCalculator (5-95% clamp);
  DamageCalculator (armour pool + overflow + penetration; pure mitigation math);
  TurnManager; utility CombatAI + personalities; Combatant runtime; CombatController;
  placeholder rigs/arena; responsive touch-first HUD; boot/menu/arena/results flow;
  end-to-end `--smoke-test` mode with combat trace.
- **Progression (P3):** ProgressionConfig XP curve (100·L^1.55), levels 1-60, +3 attr/level,
  skill point every 2nd level; ProgressionService (multi-level-ups, caps); character sheet
  (pending/confirm allocation + derived-stat preview); OpponentGenerator (seeded, budgeted);
  versioned JSON saves (migration chain) with autosaves; results-screen rewards.
- **Equipment (P4):** EconomyCalculator/Config (charisma pricing, sell<buy invariant,
  combat gold); EquipmentService (requirement gating, slot swaps); shop (buy/sell) and
  inventory screens; catalog to 13 weapons / 12 armour with tier/level/attr gates;
  save v2.
- **Skills (P5):** generic StatusEffectSystem (stacking/refresh/DoT ticks/stun/modifier
  aggregation; 6 effects); SkillData v2 + 10 skills; CombatDecision; skill submenu in HUD;
  status icons; skills learning screen; AI scores skills in the shared expected-damage
  currency; enemies bring skills from level 3; save v3.
- **Arena core (P6):** handcrafted champion Maulhilda the Unmoved (armour-teaching tank,
  boss personality, signature skills, unique shop-excluded weapon, localized announcer
  lines); unlock at 3 wins; one-time rewards with rematch guard; character creation scene
  (presets/colors/live preview); save v4.
- **Presentation pass (P7 partial):** global UITheme (buttons/panels/bars/inputs), menu
  gradient + emblem + title shadow, arena sky gradient/sun/banners, upgraded rigs
  (outlines/straps/headbands), semantic bar colors; dev `--screenshot-dir=` capture mode.
- **Build/CI:** Web (no-threads) + Windows export presets; both exports produced AND
  verified this session (browser playthrough; exe passes smoke). GitHub Actions workflow
  authored (unverified until first push). Custom headless test runner + 19 suites /
  1819 assertions.

### Changed (notable mid-session design corrections — all verified by tests/smoke)
- AI rework after observed stalls: single expected-damage currency; defend valued by
  prevented incoming × swing probability; leaky defend decay; retreat fatigue; finisher
  scaling; crowd impatience. Result: every seeded duel resolves in 9-29 rounds.
- Ranged AI: approach bonus only beyond range_max; retreat bonus inside range_min
  (fixed bow approach/retreat ping-pong found by adversarial review).
- ItemDB lazy indexing (autoload `_ready` doesn't run in `-s` tool contexts).
- Untyped the status-tick autoload signal payload: typing it with another class's inner
  class deadlocked the 4.4 GDScript analyzer.

### Fixed (17 confirmed findings from a 25-agent adversarial review workflow)
Localized champion/preset names; data-driven arena selection; round-cap off-by-one;
world-space re-centering per aspect ratio; ground/HUD overlap; BBCode injection via
fighter names in the log; centralized stalemate rule; localized version/stat-row strings;
armour_penetration doc; (stall findings already fixed by the AI rework).

### Tests
19 suites / 1819 assertions green; multi-seed smoke green (incl. exported Windows exe);
Web build played in-browser. Balance observation: player-favored at even level
(~70-85% over seed batches) — needs the §35 simulation tool before tuning.

### Known Problems
See PROJECT_STATE.md (Known Bugs / Technical Debt / Blocking Issues).

### Next Recommended Task
Tournament structure + second arena region (complete Phase 6, charter §21).

---

## Session 2 — 2026-08-24 — Owner directives: combat feel + UI overhaul (Claude, autonomous)

Pulled the owner's "Update project settings for Godot 4.7" commit untouched; installed
Godot 4.7.2-stable locally + export templates; full suite green under 4.7 before changes.

### Added
- **Positional movement:** per-fighter cells on an 8-cell arena line (CombatContext
  rework). Approach/retreat moves ONLY the acting fighter; arena walls block retreat;
  bands derive from separation. Movement is animated per-actor.
- **Adjacent-only combat:** every weapon and strike skill hits at separation 1 only
  (data change; band-capable code kept). Gutter Lunge reworked reach->precision (+3 acc).
- **Hit feedback:** impact sparks + dust puffs (CPUParticles2D), fixed-pattern screen
  shake around the centered world offset, armour-vs-flesh tinting.
- **Audio:** runtime-synthesized placeholder SFX library (hit/armour/miss/skill/buff/
  death/step/coin/click/victory/defeat) — AudioManager.play(name), global button click
  via node_added hook, victory/defeat stings on results.
- **HUD overhaul:** combat log panel REMOVED (owner directive); enemy Energy bar added;
  stat rows carry heart/bolt/shield icons; action buttons icon+text; the player's
  skills sit INLINE on the action bar as icon buttons (cost amber / cooldown red);
  fading announcement banner replaces log lines for champion intro/defeat; stun shows
  as floating text.
- **Icons:** 19 original SVGs (assets/icons) for actions, stats, skills, coin; SkillData
  gained an `icon` field wired in all 10 skill resources.
- **Rest heals:** +8% max HP on top of the energy restore; valid whenever either pool
  is missing (CombatTuning.REST_HP_RESTORE_FRACTION).
- **Shop auto-equip:** buying a strict upgrade (EquipmentService.is_weapon/armour_upgrade)
  equips it automatically and a dialog offers the old piece at its sell price.

### Changed
- Dead combat.log.* localization keys removed (17); EventBus combat_log_line removed.
- Screenshot capture grants a skill kit so visuals show the inline skill buttons.
- Docs: combat.md/ai-adjacent notes, balancing.md "ranged identity PAUSED",
  ASSET_MANIFEST audio rows now list the synthesized cues, AI_GUIDE engine pin 4.7.

### Tests
20 suites / 1886 assertions green under 4.7.2; 6-seed smoke 11-23 rounds; new suites:
positional movement/band mapping/walls, adjacent-only (weapons+skills, data-level),
rest-heals validity, upgrade heuristics. Screenshots verified menu/creation/arena.

### Known Problems
Ranged weapon identity dormant (owner directive) — see docs/balancing.md.

### Next Recommended Task
Tournament structure + second arena region (complete Phase 6, charter §21).

---

## Session 3 (continued) — 2026-08-24 — Owner batch 2: bows, radial UI, town, merchants (Claude)

### Added (owner directives)
- **Archer redesign:** bows are ranged again (CLOSE..LONG, never point-blank) with a
  4-arrow quiver per fight; every bow auto-carries a Skinning Knife sidearm; fights
  OPEN on the knife and SWITCH_WEAPON is its own action; arrows spend hit-or-miss;
  arrow projectile visual + arrow/switch SFX; AI archer flow (draw bow at range,
  kite, knife when dry/cornered). `--smoke-weapon=` override for CI archer runs.
- **Radial action menu:** combat actions + skills orbit the player's gladiator as
  circular icon buttons with name labels and cost/ammo/cooldown badges (pop-in
  animation, attack slot faces the foe). Bottom bar reduced to the hint line.
- **Street merchants:** shop split into Bragga's Blades (weapons) and Tetta's
  Ironwear (armour), price-sorted rows with tier-tinted item glyphs (13 class/slot
  SVGs), ammo stat line, NPC flavor quotes.
- **Dustwell town hub (charter §22):** procedural street backdrop (buildings, lit
  windows, arena silhouette), location cards (fight/regions/merchants/trainer/
  character/inventory), status panel; main menu leaned to 5 items (overflow fixed);
  all sub-screens return to town.
- **Rig v2 + arena depth:** round-capped capsule limbs, hands/boots/ear/smirk,
  shield visual on defend; arena columns + lit fighting oval; town visual.
- **Skill clarity (owner bug report):** weapon-class requirements now shown on the
  learn screen (Skull Ringer's blunt-only gating was invisible).

### Fixed (18 confirmed findings, 25-agent adversarial review)
- CRITICAL pause soft-lock: _delay timers now pause-respecting; SceneRouter
  defensively unpauses; HUD process_mode ALWAYS (Esc works while paused);
  pause UI closes on combat end; leave guarded post-fight.
- CRITICAL tournament state leak: `tournament_fight_pending` gates bracket
  bookkeeping (normal duels can never advance/complete a bracket — regression
  test added); results Back and start_next_duel forfeit hanging brackets.
- champion line arena-aware ({arena}); mana gets its own hint key; champion tres
  load_steps corrected; tournament markers ASCII-safe for Web fonts; settings
  sliders 44px; dead loc keys removed.

### Tests / balance
22 suites / 2343 assertions green; multi-seed + archer smoke green; §35 sim re-run
(archer enemies included): presets hold 40-60%, 0 stalemates.

---

## Session 4 — 2026-08-24 — Reference-quality visual pass: rig v3 + arena v2 (Claude)

Owner directive: match the classic gladiator-duel genre look in DETAIL and
QUALITY (explicitly not a copy — original designs only). Weapons and armour
must read as real drawings on the character; spectators must be drawn figures.

### Added
- **Rig v3** (`characters/components/placeholder_rig.gd`): muscular 3-tone
  anatomy (skin/highlight/shade), face detail (brow, white-of-eye, nose,
  mouth, ear, hair or helm), heroic torso taper with pec/ab sculpt or a
  riveted muscle-cuirass when a chest piece is worn. EQUIPMENT IS DRAWN ON
  THE BODY per slot (helmet/chest/shoulders/gloves/belt/legs/boots) using
  armour-class material tones lerped toward tier tints; heavy helms get a
  crest + cheek guard. Per-class weapon drawings (sword w/ edge highlight +
  guard + wrapped grip + pommel, bearded axe, studded maul, leaf-blade
  spear, recurve bow w/ string, orb staff) tinted by weapon tier; fist
  redrawn over the grip so the hand visibly holds the weapon.
- **Rig data plumbing** (`combat/combatant.gd`): rig receives the live
  WeaponData + armour_pieces at setup and on weapon switch.
- **Arena v2** (`scenes/arena/arena_visual.gd`): three depth-shaded crowd
  tiers of individually drawn spectators (varied cloth/skin tones, hair
  caps, ~28% cheering with raised arms) on stone steps; parapet with
  pennants; brick-course lower wall; two barred holding-pen gates with
  dressed-stone arches; cylinder-shaded columns with carved bands.
- Creation preview shows the rig at 2.4x so the new detail reads.

### Fixed
- Lit fighting oval painted OVER the lower wall/gates (top edge reached
  y≈397 vs wall at 410) — oval recentred/flattened to stay below y=503.

### Tests / builds
22 suites / 2343 assertions green; smoke seeds 7/99/424242 + archer 31337
green (switch->shoot trace verified); Web + Windows re-exported, exe smoke
green (seed 555). Screenshot-iterated: 3 capture rounds, fighter close-ups
inspected at 3x.
