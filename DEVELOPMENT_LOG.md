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

---

## Session 5 — 2026-08-25 — Owner batch 3: agency, animation, the arena's call (Claude)

Thirteen owner directives, designed and shipped as one coherent pass:
player agency (free point-buy), combat feel (living rig, elemental VFX),
fairness pressure (effectiveness XP), and a progression spine (forced
tournaments as boss ladders).

### Added
- **Free point-buy creation:** all 8 attributes player-set (56-pt budget,
  floors/ceilings, presets = quick-fill templates); live derived-stat
  readout via the real calculators; unspent points carry into the game as
  attribute points. Options column scrolls (no more overflow).
- **Player-first turn order:** the hero ALWAYS opens the fight
  (TurnManager priority key); AI-vs-AI keeps pure initiative (sim/CI).
- **Mobility tiers:** approach/retreat covers 1 cell, or 2 when
  agility + 2x gear mobility >= 14 (ProgressionCalculator.move_cells);
  clamped at the foe's cell and the wall. ArmourData.mobility_bonus on
  boots (duelist_boots, windrunner_boots, gale_greaves); step animation
  speed follows agility.
- **Effectiveness XP:** landed strikes / actions taken multiplies XP in
  [0.65, 1.25] — stalling earns less, fierce fighting more (results line
  says why); champion finals pay 1.5x (level pacing anchor).
- **The arena's call:** once the tournament is open and the player reaches
  the region band midpoint, normal duels LOCK until the bracket is fought
  (GameManager.tournament_required, guarded in start_next_duel; town card
  turns golden + pulses). Bracket opponents are ELITES (+1 gear tier,
  fuller armour, always 2 skills); completing a bracket pays a house
  bonus (economy.tournament_gold_bonus, shown on results).
- **Rig v4 — the living gladiator:** weapon arm is a pivoting child node
  (idle sway, wind-up->whip melee swing, draw-and-loose bow aim, switch
  flourish, rest crouch); face expressions (fierce on attack, pain when
  struck, worried baseline under 35% HP); fighters render 1.35x in the
  arena (owner: fighters must dominate the sand).
- **Elemental skill VFX:** status-keyed bursts (burn=rising flame,
  venom=drips, bleed=spatter, stun=dazed motes) + melee slash arc.
- **Fitting booth:** both shops show the player wearing their CURRENT
  kit; hovering a row previews the item ON the body with old->new damage/
  armour delta lines; buying re-dresses the doll. Level-locked stock shows
  as SEALED crates (silhouette + unlock level) until the level opens it.
- **Content:** +8 weapons (falx, warhammer, trident, wolfsplitter axe,
  stormcaller rod, greatsword, sunforged spear, composite warbow) and
  +8 armour (mobility boots x2, pauldrons, manica, hauberk, girdle,
  crested helm, bulwark plate), EN+TR names, registry updated.
- **UI:** level + slim gold XP bar in the combat HUD and town status
  panel; stat bars tween smoothly; XP tooltips.

### Fixed
- Rig idle body-bob tween stomped externally-set positions (creation/shop
  dolls rendered at panel top) — idle now animates ONLY the arm rotation.
- Creation layout overflowed 720p (MarginContainer grew both ways,
  clipping title + footer) — options column now scrolls, sizes compacted.

### Fixed (session-5 adversarial review, 8-agent workflow, 2 confirmed)
- MAJOR: battle_sim flagged fighter A player-controlled, so the new
  player-first rule handed A every opening turn and biased sim win rates —
  sim now sets both sides plain AI (pure initiative, as documented).
- Shop fitting-doll hover preview lingered after the pointer left a row —
  mouse_exited now re-dresses the doll in the actual kit.

### Tests / balance
23 suites / 2699 assertions green (new test_session5_rules.gd: turn
order, mobility tiers/clamps, effectiveness bounds, the arena's call,
house bonus, elite tiers); smoke seeds 7/99/424242 + archer 31337 green;
§35 sim (unbiased, post-fix): default kit 89/78/76% vs generated L1/5/10;
presets 43-53.5%, 0 stalemates, 19-22 rounds.

---

## Session 6 — 2026-08-25 — Owner batch 4: the debut arc, crits, weapon memory (Claude)

### Added
- **Debut arc:** a new gladiator lands in TOWN (never straight into a
  fight), starts ARMOURLESS with a Worn Shiv; level-1 opponents are just
  as bare (gear returns from level 2). Opening cells are 1/6 — LONG band,
  several moves apart. The FIRST victory pays a debut purse
  (economy.first_victory_gold_bonus) and tops XP up to a guaranteed
  level-up; the results screen says so.
- **Critical hits:** per-WEAPON base chance (daggers 8-9%, mauls 3%) plus
  the class-matched attribute (axes/mauls scale on Strength, swords/bows
  on Agility, spears on Attack, staves on Arcana; +0.2%/point, clamp
  1-25%) — one math home: HitCalculator.crit_chance_for. Damage x2 at the
  §15 Critical step; AI expected-damage includes the crit EV; shop rows
  and the character sheet show the EFFECTIVE percent so upgrades weigh it.
  Presentation: "KRİTİK! N" burst, heavy shake, dedicated synth SFX.
- **Weapon memory + fatigue (ranged flow):** first bow use still demands
  the switch; a WON fight carries the end-of-fight weapon into the next
  one (profile.prefers_main_weapon), a LOSS resets to the sidearm AND
  drains the next fight's opening energy to 60% (battle_fatigue). Save v6.
- **Auto-rest:** a player turn with 0 energy rests automatically
  ("Bitkin — dinleniyor") — no dead menu.
- **Skill economy + guidance:** per-skill point costs (1-3 SP, in data);
  the skills screen names your dominant trait and tags skills that suit
  your top-two attributes AND your current weapon ("✦ ... yapına uygun").
- **Victory celebration:** the winner pumps the weapon arm, hops and
  grins (Face.HAPPY) before the results screen.
- Brawler preset retuned [11,7,9,7,10,8,2,2] (crit-era balance).

### Tests / balance
24 suites / 2765 assertions green (new test_session6_rules.gd: crit
scaling/mapping/clamps/occurrence, pref+fatigue loop, save roundtrip,
armourless starts, LONG opening, recommendations); smoke seeds
7/99/424242 + archer 31337 green (debut level-up visible); §35 sim:
presets 39.5-54%, 0 stalemates (swift's agility-crit identity noted).

### Fixed (session-6 adversarial review, 9-agent workflow, 2 confirmed)
- MAJOR (charter rule): unit-test runs wrote the REAL user save via
  consume_combat_rewards -> save_profile (test_session5/6 flow tests) —
  the runner now force-disables disk writes for every suite (persistence
  suites opt back in with their own temp path). The on-disk save on this
  dev machine had already been replaced by a test fixture.
- Weapon-memory pollution: melee-only wins set prefers_main_weapon, so a
  bow bought later opened PRE-DRAWN (skipping the mandatory first switch).
  Memory now forms only in fights where switching was a real choice
  (CombatResult.player_could_switch) AND equipping a new main weapon
  clears it. Regression tests added.
