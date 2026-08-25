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

---

## Session 7 — 2026-08-25 — Charter amendment: class-system audit + V2 expansion plan (Claude, no gameplay code changed)

### Context
Owner brought a large, class-based (Warrior/Assassin/Archer/Mage, Knight-Online-inspired)
redesign prompt and asked to (1) improve/complete that prompt and (2) audit the repo for
precise next steps. Read AI_GUIDE.md, PROJECT_STATE.md, MASTER_BUILD_PROMPT.md, and
docs/{combat,ai,items,architecture}.md, then verified specific claims against source
(`grep` for Camera2D/hit_stop/debug_menu/rarity usage; read enums.gd, a weapon .tres,
combat_vfx.gd, combat_controller.gd) before writing anything, to avoid re-proposing systems
that already exist (rarity enum, screen shake, status-flavored VFX, crit system, etc.).

### Decision (owner-confirmed, asked via AskUserQuestion)
The pasted prompt's hard 4-class structure conflicts with the existing, deliberate
"no hard classes — builds emerge from attributes+skills+equipment" pillar (6 sessions of
skills/items/AI/saves depend on it). Owner chose to **keep the classless system**. Class
fantasy is instead delivered through a derived, non-gating "Weapon Mastery Archetype" label
(Breaker/Duelist/Skirmisher/Marksman/Battlemage/Guardian) computed from equipped weapon
class + armour weight + shield — used for animation timing, VFX, and AI-personality pairing
only, never for equipment/skill gating. Full rationale logged in `MASTER_BUILD_PROMPT_V2.md`
§47 (Decision/Reason/Alternatives/Consequences format).

### Added
- `MASTER_BUILD_PROMPT_V2.md` — new charter amendment (v1 stays unedited, per the Forbidden
  Practices rule). Contents: role/expertise framing, which v1 pillars are load-bearing and
  not to be reopened (§46), the classless-vs-class decision (§47), a condensed audit of
  already-working systems so they aren't re-proposed (§48), 9 verified code-level gaps (G1-G9,
  §49), the Weapon Mastery Archetype table (§50), and concrete specs for combat feel/camera
  (§51), itemization affixes/uniques (§52), AI personality depth + debug overlay (§53),
  the crowd/Charisma system (§54), and rivals/boss phases (§55), plus a re-sequenced Phase
  11-16 plan (§56).
- Verified gaps worth calling out: no hit-stop/time-scale system anywhere in the repo; no
  dynamic Camera2D in combat (only a world-offset shake); no weapon-weight-differentiated
  attack timing despite WeaponClass already driving damage/accuracy; `Rarity` enum
  (Common..Mythic) already exists on every item but drives no affix/modifier generation yet
  (docs/items.md already flagged this as deferred); only one AIPersonality
  (`aggressive`) ships despite the resource type and docs/ai.md both anticipating more;
  `EventBus.ai_scores_computed` already fires every AI decision but nothing consumes it
  (no debug menu exists); Charisma still only affects shop prices (charter §19 crowd meter
  never built - already PROJECT_STATE's own "Recommended Next Task" independent of this
  audit); no rival NPCs or champion HP-phase transitions.

### Changed
- `AI_GUIDE.md`: added a pointer to `MASTER_BUILD_PROMPT_V2.md` alongside the v1 charter
  reference.
- `PROJECT_STATE.md`: re-sequenced "Recommended Next Task" / "Next 5 Tasks" to the V2 §56
  phase order (combat feel + itemization depth before more raw content, per the charter's
  own priority order); added the classless-builds decision under Important Recent Decisions.

### Tests
None run - no gameplay code touched this session (documentation/planning only).

### Known Problems
Unchanged from session 6 (see PROJECT_STATE.md).

### Next Recommended Task
Phase 11 (MASTER_BUILD_PROMPT_V2.md §51): hit-stop helper + CombatCamera + weapon-weight
timing table.

---

## Session 7 (part 2) — 2026-08-25 — V2 phases 11-12: combat feel + itemization depth (Claude)

### Phase 11 — Combat feel (V2 §51, gaps G1-G3)
- **`CombatFeel`** (new): the ONE table of weapon-weight pacing — windup, swing,
  recovery, lunge reach, shake multiplier, hit-stop duration and attack STYLE per
  `WeaponClass`. The rig and the controller both read it, so a maul now loads up
  visibly while a shiv flicks out, spears thrust with the longest reach, bows
  draw-hold-loose without lunging, and staves take a cast beat.
- **Hit-stop:** a bounded `Engine.time_scale` dip on impact (x1.8 on crits, capped at
  0.24s). The freeze timer runs with `ignore_time_scale` so it can never stretch
  itself; `release()` runs on freeze end, combat end and `_exit_tree` so a scene
  change can never strand the game in slow motion; skipped entirely in smoke runs.
  Honours the EXISTING `reduced_fx` toggle rather than adding a parallel one.
- **`CombatCamera`** (new `Camera2D` under the arena's WorldRoot): frames the
  midpoint of the two fighters, tightens to 1.26x at ADJACENT and eases to 1.0 by
  separation 5+ (a bow duel reads as distant for free), push-in on crits and the
  killing blow. It clamps its visible rect to the 1280x720 design box so no framing
  can reveal the edge of the drawn arena, and it took over the impact shake — a
  world-offset shake would be cancelled by a camera that re-frames from world
  positions every frame. Framing math is pure statics, unit-tested headlessly.
- Accessibility gained a **Camera Motion** slider (0 = the exact classic static
  frame) next to the existing shake/reduced-fx settings.

### Phase 12 — Itemization depth (V2 §52, charter §16, gaps G4-G5)
- **`AffixData` + a 15-affix pool** (`data/affixes/`): attributes, armour, evasion,
  accuracy, crit chance, armour penetration, flat damage, mobility — each with a
  value band, weight, `min_rarity` gate and weapon/armour gate.
- **Rarity finally means something:** Common 0 / Uncommon 1 / Rare 2 / Epic 3 /
  Legendary 3+signature / Mythic 4+signature modifiers.
- **Decision — modifiers are DERIVED, not rolled per drop.** An item's affixes are a
  pure function of its own `id` (local RNG seed) and rarity. Reason: the satchel is
  a list of item IDs, so per-drop rolls would need a per-instance item model, a save
  version with a lossy migration and duplicate-aware inventory UI — and V2 §52
  scopes this phase to "no save-version change". Consequence: the catalog is
  learnable and a shop row can promise what it shows; two copies of an item are
  identical. Full block in `docs/items.md`.
- **Three signature effects** hooking systems that already existed: Venom Mastery
  (on-hit statuses may exceed `max_stacks` by one), Bulwark Reserve (DEFEND refunds
  Energy), Relentless Edge (a crit ticks every cooldown down a round). Homes: the
  two champion weapons became Legendary, plus one new Legendary chase purchase
  (Venomtooth Cleaver, T5 axe, level 15). `OpponentGenerator` now filters Legendary
  out of generated loadouts.
- **Combat reads `Combatant.attributes`** (progression + kit) instead of
  `data.attributes`, so equipment can grant attributes without ever writing into
  progression data. Everything else folds into the existing calculators; the 1-25%
  crit clamp still binds.
- **Equipment comparison** in shop and inventory rows: rarity beside the name, the
  item's modifiers, its signature text, and colour-coded gains/losses against
  whatever occupies that slot right now.

### Fixed (adversarial review, 5-lens + refute/repro workflow — 6 findings, all real)
- MAJOR: the new camera broke the **radial action menu's anchor**. The HUD is a
  CanvasLayer (deliberately not camera-transformed) but positioned the ring with raw
  world coordinates, so at 1.26x zoom the ring drifted ~44px off the fighter (~85px
  near an arena wall) — the ATTACK button could sit on the opponent's head. Now
  projected through `get_global_transform_with_canvas()`, with a zoom-scaled radius
  and unscaled buttons (touch targets).
- MAJOR: the controller presented impacts after only `windup_time`, i.e. while the
  arm was still cocked. It now waits `CombatFeel.impact_delay` (windup + swing).
- MAJOR: the `camera_motion` setting had no end-to-end coverage — a typo on either
  side of the wire, or a flipped default, stayed green. Setting keys are now
  constants owned by the system that READS them, the settings widgets are named, and
  tests drive the real slider/toggle.
- MINOR x2: two assertions could not fail (a cap the data can never reach; a
  fighter pair symmetric about the arena centre). Both replaced with real coverage.
- Also found and closed by a new suite: a script that fails to PARSE still
  instantiates as a bare node, so the scene-smoke suite went green this session
  while two menus were dead. `test_script_integrity.gd` now compiles every `.gd`.

### Tests / balance
27 suites / 3910 assertions green (new: test_combat_feel 240+, test_itemization 644,
test_script_integrity). Smoke seeds 7/99/424242/31337 green with IDENTICAL round and
damage counts to before the change — presentation and itemization are provably
outside the seeded resolution path. §35 sim (150 battles x 6 matchups): presets
40-52.7%, 0 stalemates; default-kit-vs-generated moved 89/78/76% -> 81/63/50% at
L1/5/10 now that generated opponents carry modifier-bearing gear — accepted and
explained in docs/balancing.md (a fighter in rags at level 10 SHOULD struggle).

### Known Problems
- Web export not re-verified in a browser since rendering changed (Camera2D +
  time_scale) — flagged in PROJECT_STATE Platform Status.
- The derived Weapon Mastery Archetype label (V2 §47/§50) is still unbuilt; Phase 14
  needs it for personality pairing.

### Also landed this session
- **Weapon Mastery Archetype** (V2 §47/§50), the last unbuilt piece of the classless
  decision: `ProgressionCalculator.combat_archetype_label()` names the fighter
  Breaker / Duelist / Skirmisher / Marksman / Battlemage / Guardian / Brawler from the
  kit they are actually wearing. Derived on demand, never stored (a test asserts no
  save field mentions it), gates nothing. Shown on the character sheet; phase 14 will
  use it to pair generated opponents with a fitting AI personality. Guardian needs a
  shield behind heavy plate and no shield content exists yet — noted, not papered over.
- **Graphics polish pass** (standing owner preference: polish when a package closes):
  a drawn dusk-arena backdrop (tiered stands, arches, pennants, sinking sun, guttering
  torches, drifting dust) behind the main menu at full strength and behind settings /
  arena select / tournament dimmed, so the front end reads as one place; plus a light
  foreground dust layer in the arena itself. Gradients are drawn as gradient textures
  rather than stacked translucent bands — banded fills double-blend at their seams once
  a layer is dimmed and drew visible hairlines across the quieter screens.
- Exports re-verified: the Windows build passes the smoke test with numbers identical
  to the editor run. The Web build exports, loads and starts in a browser (Godot 4.7.2,
  WebGL2 Compatibility, single-threaded, no JS errors) — but the browser pane could not
  be DISPLAYED in this session, so the canvas never composited a frame and the new
  camera work is not yet visually confirmed on Web.

### Next Recommended Task
Phase 13 (V2 §54): the crowd / audience meter — the last big promise Charisma is
still waiting on.

---

## Session 7 (part 3) — 2026-08-25 — V2 phases 13-16: crowd, AI depth, rivals, content (Claude)

The amendment's whole phase plan (11-16) is now complete.

### Phase 13 — The crowd (charter §19, V2 §54)
Charisma has been a shop discount for six sessions. It now fights. Every gladiator
carries their own standing with the pit for the duration of one fight
(Hostile / Bored / Watching / Excited / Frenzied): it climbs on crits, landed skills,
a guard that turns a blow aside, a finishing blow and taunt-ish moves; it falls on
turtling, running, resting and a fight that drags past round 12. Excited pays Energy
at turn start, Frenzied also steadies the aim. Deliberately small — a build that
ignores Charisma stays viable.

Design points worth keeping: **Charisma scales the CLIMB only** (softening the fall
too would quietly make it a defensive stat as well); stalling is judged with the
anti-stall counters combat already keeps, never a second detector; the judging lives
inside `CombatResolver` so the §35 simulator feels the crowd exactly as a played
fight does; and "taunt-tagged" is `SkillData.crowd_appeal`, authored per skill, not a
hardcoded id list. Runtime state only — no save change.

### Phase 14 — AI depth (V2 §53)
`AIPersonality` gained `wounded_fury` and `killer_instinct`, folded into
`aggression_now()`, which CombatAI reads everywhere it used to read the flat weight:
one scoring formula with personality-weighted inputs, never a per-personality fork.
Berserker and Opportunist joined the roster. `OpponentGenerator` now picks the
temperament AFTER rolling the kit, from a pool keyed by the Weapon Mastery Archetype
that kit derives to — a generated marksman never rolls a charger. The champions
stopped sharing a "boss" profile.

`AiDebugOverlay` finally consumes `EventBus.ai_scores_computed`, which had been
firing since the AI phase with nothing listening. It removes itself unless this is a
debug build or the run carries `--debug-ai`, and starts hidden (F3) so it never lands
in a screenshot uninvited.

### Phase 15 — Rivals and boss phases (V2 §55)
Champions change SHAPE as they fall: signature moves released at 60% HP, temperament
swapped at 30%, both authored as data on the champion resource and consumed by the
existing utility loop — the AI grew no boss-only code path. Phases never go backwards.

Each region fields one recurring rival (Grissa Two-Coin, Vurm the Kindler, and later
Ilsa Hollowreed) who turns up in ordinary duels and REMEMBERS. The rivalry is one
number — the player's net wins. Ahead, the rival arrives a level meaner with better
steel of the same class; behind, same blade and one piece of armour short. They carry
their own weapon memory, the mirror of the player's session-6 one. Save version 7
with a v6→v7 migration.

### Phase 16 — Content and modes (V2 §56, charter §21/§23/§24)
- **Saltmere Bowl** (levels 16-24), its champion **Pyx the Unblinking** (a staff
  duellist who hoards mana and stops conserving anything below 30%), its rival Ilsa,
  and Pyx's unique reward the **Ashquill Rod** — carrying a fourth signature effect,
  Arcane Echo, hooked into the mana pool that already existed.
- **Five opponent build archetypes** (brute, duelist, skirmisher, marksman, mage)
  replacing the single brute growth profile. Each declares where its points go AND
  what it will pick up, and gear now qualifies on the attributes the fighter actually
  grew — so the blanket "no arcana weapons" filter is gone and staves finally reach an
  opponent's hands.
- **Six between-fights encounters** (§23): merchant, injured gladiator, trainer, dice,
  fan, corrupt official. EventService is the only place outcomes apply, wagers stake
  in-game gold only (charter §5) and are capped by the purse, a cost can never leave
  the player in debt, and every encounter always offers a free way out.
- **`tools/economy_sim.gd`** — a new pacing report. It immediately found that the
  third region shipped with nothing on the shelf behind it, which produced the **T6
  gear ladder** (levels 18-19, priced at ~4.4 fights of income — the tightest ratio in
  the game; T1-T5 sit at 1.6-2.6, i.e. the shop has never really been a constraint).
- **§24 evaluated, not built** (docs/decisions/difficulty_and_new_game_plus.md):
  defeat consequences are already shipped under another name; difficulty tiers need no
  new systems and are the best value in §24; NG+ is blocked on the game having no
  ENDING; Iron Gladiator is an owner decision because it fights the autosave design.

### Tests / balance
31 suites / 5161 assertions green (new: test_crowd 82, test_ai_depth 177,
test_rivals_and_bosses 85, test_events 251). §35 sim (150 battles × 6 matchups):
presets 40-52.7%, 0 stalemates — provably undisturbed, because at level 1 with equal
gear the crowd never climbs high enough to pay a boon. Fights got shorter at higher
levels (21 → ~17 rounds): the crowd rewards pressure. default-kit vs generated L10
moved 48.7% → 62.7% when temperaments started matching kits — accepted and explained
in docs/balancing.md.

The suite caught a real content bug within a minute of authoring it: the new Saltmere
Pike shipped with `range_max = CLOSE`, and melee lands ONLY at ADJACENT.

### Known problems
- No ENDING (charter §30): the game stops after the third region's champion. This is
  now the largest structural gap and it blocks NG+.
- Web still unverified visually since rendering changed (Camera2D + Engine.time_scale)
  — this environment cannot composite a browser frame.
- Levels 21-24 have nothing new to buy. Deliberate for now (a "you are kitted, win the
  region" stretch), but it is a thin end to the ladder.

### Next recommended task
The ending + credits flow (§30), then difficulty tiers as data over everything phases
11-16 built.

---

## Session 8 — 2026-08-25 — Textures: the art layer, and the §25 reactions that were missing (Claude)

Owner directive: generate every texture the game needs with the Gemini image model, wire
them in, and finish the animation/VFX work charter §25 still had open.

### The gap this closed
The project had no textures at all AND no slots to hang them on — the only `Texture2D`
field in the whole data layer was `SkillData.icon`. Everything was primitive drawing.
Charter §25's animation list was missing Block, Parry, CriticalHit, Stunned, Taunt and
Walk/Run, and its VFX list was missing blood, shield impact, armour break, ice, lightning,
level-up and legendary glow.

### Added — the art pipeline (`tools/texgen`, docs/art.md)
- **140 textures generated** from a prompt manifest: 38 weapon sprites, 29 armour icons,
  14 skill and 9 status emblems, 3 arena backdrops + 3 ground tiles, 7 tiling armour
  materials, 19 VFX sprites, 12 UI plates/backdrops/emblems, 6 character portraits.
  ~11 MB on disk (lossy WebP for opaque art, PNG where alpha is needed).
- The model returns opaque JPEG only, so transparency is recovered in post: cut-out art is
  painted on flat magenta and distance-keyed with a despill pass; additive VFX are painted
  on black and luminance-keyed; tiles get a mirrored cross-fade so they wrap.
- `generate.py` is resumable and caches raw model output under `.texgen_raw/` (gitignored),
  so `--repost` re-derives every texture with no API calls when the post-processing is
  tuned. The API key is read from the environment and is never committed.
- `bind_resources.py` points the 80-odd content `.tres` files at the files, prunes the
  ext_resources that rebinding orphans, and is safe to re-run.

### Added — texture slots in the DATA layer (the missing half)
`WeaponData.sprite`, `ArmourData.icon` + `material_texture`, `StatusEffectData.icon`,
`ArenaData.backdrop` + `ground_texture`, `CharacterData.portrait`. Everything without a
content resource to hang off (VFX sprites, UI plates, material patches) resolves through
the new `ArtLibrary`. Gameplay still references logical IDs, never image paths.

**No drawing code assumes a texture exists** — rig, arena, town, menu backdrop, theme,
item icons, VFX and status chips all branch on null and keep their primitive path live, so
content authored with an empty slot still renders. Durable rule 16 in AI_GUIDE;
`test_art.gd` drives both halves of every branch.

I first wrote that as "delete `assets/generated/` and the game still plays" and then
measured it: false. A texture bound from a `.tres` is an ordinary resource dependency, and
removing the tree breaks item loading at parse time. Removing only the ArtLibrary-only
directories (`vfx/`, `ui/`) DOES leave a duel that plays out identically on the same seed.
The docs now say the accurate thing.

### Added — where the art actually lands
- **Rig v5:** an equipped weapon with a `sprite` is drawn in the fist, scaled to the
  class's reach, pivoted on the grip (bottom edge; bows at their centre) and leaned into
  the fight. Armour pieces fill their shapes with real leather/mail/plate/scale/linen via
  UV-tiled polygons. A Legendary or Mythic weapon haloes its wielder.
- **Arena:** painted backdrop per region; the ground texture goes on as low-alpha grain
  with a feathered seam, because the backdrop already contains its own painted floor and
  a full-strength tile read as a rug thrown over the arena.
- **UI:** nine-sliced bronze button plates and stone panels; painted backdrops on menu,
  town, shop, creation, results, tournament, inventory, skills and the character sheet;
  per-item icons in shop and inventory rows (weapons on the diagonal, since a sprite
  painted upright is a few pixels wide in a square slot); painted coin; menu crest.
- **Portraits:** champions and regional rivals now have a face — in the combat HUD and on
  the tournament bracket.

### Added — charter §25 completion
- **Animations:** `play_block`, `play_parry`, `play_critical_reaction`, `set_stunned`
  (wobble + circling stars), `play_taunt`, `play_move` (walk vs run by distance crossed).
  Jump is deliberately not built — a turn-based cell duel has nothing to hang it on.
- **Resolver flags** so presentation can tell these apart at all: `target_was_defending`
  (block vs clean hit, parry vs plain miss) and `armour_broken` (the blow that empties a
  pool that had something in it). Both set in `CombatResolver`, so the §35 simulator sees
  the same execution path.
- **VFX:** blood (with its own toggle), shield impact, armour break, crit burst, level-up,
  crowd flare, legendary glow, and per-damage-type flourishes for fire/frost/lightning/
  arcane/poison. Existing sparks, dust and status bursts now draw with painted sprites.
- **Taunting is a data flag** (`SkillData.taunts`), not a hardcoded id list — adding a
  showboating move stays a content task.
- **Accessibility (§30):** blood is a separate setting from `reduced_fx`. Turning the spray
  off must not flatten every other effect, and vice versa; a test asserts exactly that.

### Tuning found by looking at the running game
The dev capture harness earned its keep three times over:
- Nine-slice borders are also MINIMUM sizes. The 256x128 button plate turned every stepper
  button into a slab and pushed the character-creation attribute list off its panel; the
  plates ship at 128x64 now.
- Wide weapons centred exactly on the grip swallowed the fighter's torso (the Doorslab is
  a literal door). Sprites now step forward of the fist in proportion to their width.
- Blood painted "glowing on black" made the model paint a white field, and the luminance
  key had nothing to remove. Anything that does not actually glow is keyed off magenta.

The harness now also captures a KITTED duel against a named champion — the only frame that
shows armour materials, weapon sprites and an opponent portrait at once.

### Removed
13 placeholder skill SVGs superseded by the painted emblems (`skill_focused_loose.svg`
stays: the town screen uses it as the trainer glyph).

### Verified
- 33 suites / 5673 assertions green (Godot 4.7.2), including two new suites:
  `test_art.gd` (content invariants + the fallback paths) and `test_combat_reactions.gd`
  (the resolver flags, the blood toggle, the rig's reaction set).
- The armour-break assertion was checked against a deliberately broken resolver and does
  fail — charter testing rule, assertions must be able to.
- Multi-seed AI-vs-AI smoke green (seeds 7 / 42 / 1337, 14-19 rounds).
- Every front-end screen and two duels eyeballed in a real windowed run.

### Not done
- **Web not re-verified.** This session changed rendering everywhere and added ~11 MB of
  assets; the export needs a browser check before any release build.
- **Audio is still entirely placeholder** and is now the single biggest gap between the
  game and a commercial impression.
- The generated art is `generated`, not `final` — no art-director pass has happened.

---

## Session 9 — 2026-08-25 — Owner feedback: read the arena, read the blow (Claude)

Two owner notes on the session-8 art pass: the fighters were disappearing into
the backdrop, and the swings were over before their effects could be seen.

### The arena reframe
The fighters stood directly in front of the wall, its gates, its torches and
its crowd. Three changes, all needed:

- **The backdrop composition is now a contract with the generator.** Prompts
  pin the layout by percentage — thin sky strip, packed stands from 20% to 62%,
  plain wall 62-72%, and NOTHING below 72%. No gates or torches at fighter
  height, and the stands packed dense so the place reads as enormous.
- **The engine anchors the painting by its HORIZON, not its edges.** New
  `ArenaData.backdrop_horizon` records where the open ground starts in the
  image; ArenaVisual places the backdrop so that line lands just above the
  tallest helmet. A future backdrop with a different composition only needs a
  different number.
- **The engine draws the fighting sand itself**, tiled across the full frame
  and past the bottom edge, so the ground is boundless at any aspect ratio
  rather than ending where a painting happens to end (owner: "kum kısmının
  uçsuz olması gerekiyor"). Ground textures were regenerated near-uniform and
  very low contrast — the first set had blotches and ripples that announced
  every repeat.

Geometry alone still left two brown fighters on a brown wall, so everything
behind the ground line now sits under a cool distance haze.

Depth-scaled ground strips were tried and reverted: the seams between strips
read as horizontal banding, worse than the flat texture they were disguising.

`CombatCamera.FOCUS_Y` moved from 400 to 332 — the sand below the fighters is
boundless and costs nothing to lose, while every pixel of crowd above them is
worth keeping. It cannot go higher: the radial action ring hangs below the
player, and `test_art.gd` now asserts both that bound and the head clearance,
because the framing is four numbers in three files.

### The pacing pass
Slowed by a fixed factor per key — windup x1.20, swing x1.20, recovery x1.35,
hit-stop x1.30 — weighted deliberately rather than uniformly. The unreadable
part was never the wind-up; it was that the blow resolved and the turn moved on
before the impact could register, so most of the extra time went to the beat
AFTER the hit. `CombatVfx.LINGER` (1.35) holds every effect on screen longer,
and painted flashes now hold full brightness for their first third instead of
fading from frame one.

The controller's loose `await _delay(0.25)`-style beats moved into CombatFeel as
named constants (`BEAT_AFTER_ACTION`, `BEAT_SKILL`, ...). Charter rule 10 puts
combat-feel pacing in ONE table, and tuning a fight's rhythm should not mean
hunting through the controller for stray awaits.

One test bound moved with the design: `recovery <= 0.4` became `<= 0.45`. The
windup, swing, impact-delay and freeze-cap bounds all still hold unchanged.

### Verified
- 33 suites / 5690 assertions green.
- Smoke runs are BIT-IDENTICAL to session 8 at seeds 7/42/1337 (same rounds,
  same damage, same XP), which is the proof that the pacing work stayed on the
  presentation side of the line the charter draws.
- All three arena compositions checked against the placement maths; both duel
  frames eyeballed in a real windowed run.

