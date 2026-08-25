# ARENA LEGENDS — CHARTER AMENDMENT V2: DEPTH & PRESENTATION EXPANSION

> **How to use this file:** `MASTER_BUILD_PROMPT.md` is the original charter and is never
> edited (AI_GUIDE.md Forbidden Practices). This file is a **session-7 amendment**, written
> after a full audit of the actual repository against a much larger, class-based redesign
> prompt the project owner was considering. It does not replace v1 — it (a) reaffirms the v1
> decisions that must not be silently reopened, (b) resolves the one real conflict that audit
> surfaced (hard classes vs. the existing classless build system — **resolved: stays
> classless**, owner decision 2026-08-25), and (c) gives a precision-targeted expansion plan
> for what actually moves this game from "playable" to "commercially impressive," grounded in
> what the codebase already does and does not do. Paste this file (together with
> `AI_GUIDE.md` and current `PROJECT_STATE.md`) into a fresh agent session instead of the
> generic class-based prompt. Read order for any task from here on:
> `AI_GUIDE.md -> PROJECT_STATE.md -> DEVELOPMENT_LOG.md (latest) -> this file's relevant
> section -> source + tests -> code`.

---

## §45. ROLE AND EXPERTISE SCOPE

You are acting as the combined **Lead Game Director, Senior Godot Engineer, Combat Designer,
RPG Systems Designer, Technical Artist, UI/UX Designer, Game AI Designer, Economy Designer,
Audio Director, Localization Engineer, and QA/Balance Engineer** for **Arena Legends**, an
original 2D turn-based gladiator-arena RPG already in active, multi-session development.

This is not greenfield work and not a request to bolt on a few buttons or sprites. The job is
to take a *functionally complete but visually/tactically thin* MVP (full loop already works:
creation → duels → XP/levels/attributes → skills → gold → shop/inventory/equipment → regional
tournaments → handcrafted champions → persistent saves, in EN+TR, exported and verified on
Windows and Web) and push it toward a game whose combat *feels* weighty and readable, whose
items and builds create genuine decisions, whose opponents behave with visible intent, and
whose presentation reads as a deliberate, professional 2D fantasy arena game rather than an
engineering prototype.

Every recommendation below is scoped to **this specific codebase** (Godot 4.7, GDScript-only,
Compatibility renderer, data-driven `.tres` content, centralized calculators, versioned JSON
saves, seeded RNG) — not generic engine-agnostic advice. Before touching any system, follow
the v1 charter's own discipline: read what exists, understand why it is shaped the way it is
(`docs/*.md` carry the "why," not just the "what"), and extend it rather than replacing
working systems without a concrete technical reason (AI_GUIDE.md §"Architecture Rules" #9).

---

## §46. RELATIONSHIP TO THE V1 CHARTER — WHAT THIS AMENDMENT DOES NOT REOPEN

The following v1 decisions are **load-bearing** — six sessions of skills, items, saves, AI,
and tests are built on them. Do not revisit them without a new explicit owner decision logged
the same way this one was (a dated decision in this file plus a `DEVELOPMENT_LOG.md` entry):

- **No hard classes.** Builds emerge from 8 attributes + skills + equipment (§47 below).
- **Melee is adjacent-only; bows are the ranged exception** with a 4-arrow quiver + knife
  sidearm + switch action (docs/combat.md). Distance is personal per-fighter cells, not a
  shared "battle line."
- **GDScript only, Compatibility renderer, no C#, no threads on Web** (charter §4, §14).
- **Data-driven content only** — no `if weapon_name == "X"` branches; all combat math lives in
  the calculators (`HitCalculator`, `DamageCalculator`, `ProgressionCalculator`,
  `EconomyCalculator`); UI/AI call them, never reimplement them.
- **Versioned JSON saves** with a tested migration chain (currently v0→v6) — any new
  persistent field is a new save version with a migration, never a silent format change.
- **Centralized seeded RNG** for all gameplay randomness; decorative VFX use local RNGs so
  `--combat-seed=N` stays reproducible.
- **EN + TR localization already complete** for every player-visible string — this is done,
  not a future task; new content must ship with both keys from the start (`localization/strings.csv`).
- **No real-money purchases, ad/analytics SDKs, or telemetry** (charter §5) — still true, no
  reason to reconsider this for a single-player offline game.
- **Priority order when goals conflict** (AI_GUIDE.md): playable gameplay > correct
  architecture > maintainability > build diversity > progression quality > combat feel >
  content volume > polish. The plan in §56 is deliberately ordered to respect this — combat
  feel and build diversity work is sequenced *before* raw content volume (more weapons,
  more arenas), because that is what the priority order actually implies once the MVP loop
  already works.
- **Testing/CI discipline, asset placeholder tracking, monetization boundary, accessibility
  settings (volumes, screen-shake slider, reduced-fx toggle, language)** are already
  implemented, not open items — do not re-derive or re-propose these; extend them.

A generic "start from an audit, invent a folder structure, invent a documentation system"
prompt does not apply here — all of that already exists and is in daily use
(`AI_GUIDE.md`/`PROJECT_STATE.md`/`DEVELOPMENT_LOG.md`/`docs/*.md`). Treat re-deriving it as
wasted effort.

---

## §47. CONFIRMED DECISION — CLASSLESS BUILDS STAY; "WEAPON MASTERY ARCHETYPES" REPLACE HARD CLASSES

**Decision (2026-08-25, owner-confirmed):** Arena Legends will **not** introduce a
Warrior/Assassin/Archer/Mage class selection. The class-fantasy value the owner actually
wants (recognizable silhouettes, weapon-appropriate combat feel, build identity, AI that
"reads" as a certain kind of fighter) is delivered instead through a **derived, non-gating
Weapon Mastery Archetype** — a label computed from the character's *actual* equipped weapon
class + armour weight + shield presence, shown in the character sheet, used to flavor
animation timing, VFX, opponent generation, and AI personality — but **never used to lock
equipment or skills**. A player can freely re-equip out of an archetype at any time; nothing
about it is a permanent choice.

```
Reason:    Six sessions of skills (MARTIAL/RANGED/ARCANE/PRESENCE disciplines), items,
           AI, and saves already assume attributes+equipment define a build, and this is
           logged in AI_GUIDE.md as a *deliberate* departure from the reference genre's
           binary class split, not an oversight.
Alternative considered: hard 4-class pivot (the pasted Knight-Online-style prompt).
Consequences of the alternative: would require re-gating every item/skill by class,
           redesigning AIPersonality and OpponentGenerator around class rosters, a new
           save version with lossy migration for existing "hybrid" builds, and would
           contradict the game's own documented design pillar for no clear gameplay gain —
           the desired *visual/tactical* identity is achievable without the *mechanical*
           lock-in. Rejected.
```

`ProgressionCalculator` gains one new **pure, derived** function (no new persistent field,
no save-version bump):

```gdscript
static func combat_archetype_label(equipped_weapon: WeaponData, armour_weight: int,
        has_shield: bool) -> StringName:
    # derived, display-only — never gates content, never stored, recomputed on demand
```

See §50 for the archetype table this function returns.

---

## §48. AUDIT SUMMARY — WHAT ALREADY EXISTS (DO NOT REBUILD)

Condensed from `PROJECT_STATE.md` + direct source inspection this session, so nobody
re-implements a solved problem:

| Area | Status | Where |
|---|---|---|
| Turn-based combat, positional cells, adjacent-melee/ranged-bow exception | Done | `combat/*` |
| Hit chance, damage pipeline, armour-as-depleting-pool, penetration, overflow | Done, unit-tested | `combat/hit_calculator.gd`, `combat/damage_calculator.gd` |
| Per-weapon-class crits (attribute-matched, ×2, clamped 1–25%) | Done | `combat/hit_calculator.gd` |
| Status effects engine (stacking/refresh/DoT/stun/modifiers), 9 effects | Done | `combat/status_effect_system.gd` |
| Utility AI (single expected-damage currency, anti-stall decay) | Done, regression-tested | `combat/combat_ai.gd`, `docs/ai.md` |
| Impact VFX: sparks, status-flavored particle shapes (fire rises, poison drips, bleed spatters, stun motes), slash arcs, accessibility-scaled screen shake | Done | `combat/combat_vfx.gd` |
| XP/levels 1–60, attribute allocation, skill points, versioned saves v0→v6 | Done | `services/progression_*`, `autoload/save_manager.gd` |
| Economy (charisma-scaled prices, sell<buy invariant, tested at charisma 1–200) | Done | `services/economy_calculator.gd` |
| 30 weapons / 26 armour / 14 skills, tiers T1–T5, `Rarity` enum (Common→Mythic) already defined | Content exists, rarity **not yet used for affix generation** | `data/*`, `data/models/enums.gd` |
| 2 arena regions, 4-round tournaments, 2 handcrafted champions with unique rewards | Done | `services/*`, `data/arenas` |
| Character creation (presets, colors, live rig preview), rig v4 (living animation, per-slot armour draw, tier-tinted weapons, expressions) | Done | `characters/components/placeholder_rig.gd`, `ui/character_creation.gd` |
| Global UI theme, HUD level/XP bars, town hub, victory celebration animation | Done | `ui/*` |
| EN+TR localization, integrity-tested | Done | `localization/strings.csv` |
| Windows + Web export, verified this session's predecessors | Done | `PROJECT_STATE.md` |

**Do not** re-propose a generic "convert flat colors to layered 2D art," "add a localization
system," "add a save system," or "add an AI utility system" task — all shipped. Effort spent
re-deriving these is effort not spent on §49.

---

## §49. VERIFIED GAP LIST (PRECISION FINDINGS)

Each item below was checked against the actual source (not assumed from docs), so this is a
"nokta atışı" list, not a wishlist:

**G1 — No hit-stop / time-freeze on impact.** `grep` for `hit_stop|hitstop|time_scale` across
the repo returns nothing. `combat_vfx.gd::_shake()` exists (world-offset shake, scaled by the
`screen_shake` accessibility setting) but there is no brief `Engine.time_scale` dip on
hits/crits. This is one of the cheapest, highest-perceived-impact additions available (§51).

**G2 — No dynamic combat camera.** `combat_controller.gd` only offsets the arena node for
shake; there is no `Camera2D` that frames both fighters, zooms with separation, or push-ins on
crits/kills. The 8-cell positional model (`combat/combat_context.gd`) already gives exactly
the data a framing camera needs (both fighters' cell positions) — this is additive, not a
rework (§51).

**G3 — No weapon-weight-differentiated timing.** `WeaponClass` (UNARMED/SWORD/AXE/BLUNT/
SPEAR/RANGED/MAGICAL) already drives damage/accuracy/energy cost, but nothing in
`placeholder_rig.gd` or the action-execution flow differentiates swing/windup/recovery timing
or hit-stop duration by weapon class. A dagger-class weapon and a greatsword-class weapon
currently *feel* identical in pacing even though they're already mechanically distinct (§51).

**G4 — Itemization has no affix/modifier layer.** `Rarity` (Common/Uncommon/Rare/Epic/
Legendary/Mythic) is a defined enum and every weapon/armour `.tres` already carries a rarity
value, but `docs/items.md` confirms "enchantments, durability, modifiers, rarity rolls arrive
in later phases" — rarity currently does **not** change anything about an item except its
display tier. This is charter §16's own plan, simply not yet built, and is the single highest-
leverage build-diversity investment available (§52).

**G5 — No equipment comparison UI.** `grep` for `compare` across `ui/*.gd` returns nothing.
`inventory_screen.gd`/`shop_screen.gd` exist but there is no "equipped vs. candidate" delta
view. Charter §16 implies this ("two points away" anticipation) but never names the UI
explicitly — new gap, not previously specced (§52).

**G6 — Only one AI personality shipped.** `docs/ai.md` itself flags this: "Personalities
beyond Aggressive... land in later phases." `AIPersonality` (aggression/caution/
resource_care weights) is a working resource type; only `personality.aggressive` exists as
content. Every generated opponent currently fights with the same temperament (§53).

**G7 — AI debug/score overlay never built despite the event already existing.**
`EventBus.ai_scores_computed(name, {ACTION: score})` fires every AI decision (docs/ai.md), but
there is no on-screen consumer of it (`grep` for `debug_menu|DebugMenu` returns nothing
anywhere in the repo). Charter §34 speced a full debug menu; the hardest part (the data feed)
is already wired. Building just the overlay is a near-free win for all future AI/balance work
(§53).

**G8 — Charisma is combat-irrelevant.** `EconomyCalculator` uses Charisma for shop
prices only. Charter §19 (crowd/audience meter) was never implemented — and
`PROJECT_STATE.md`'s own "Recommended Next Task" already names this as the next system to
build, independent of this audit. This is simultaneously the pasted prompt's most legitimate
ask and the project's own already-agreed next step (§54).

**G9 — No recurring rivals, no boss phase transitions, no random events.** Champions
(Maulhilda, Orzha) have unique weapons/skills/rewards but no HP-threshold phase changes; there
is no NPC that remembers a prior loss/win against the player the way the *player's own*
`weapon_memory`/`battle_fatigue` (session 6) already does. Charter §23 (random events) has no
implementation yet (§55).

---

## §50. WEAPON MASTERY ARCHETYPE TABLE

Purely a display/flavor/AI-tuning layer over existing data — no new enum values needed
(reuses `WeaponClass`), no equipment/skill gating, nothing persisted.

| Archetype (shown in UI, never a save field) | Derived from | Visual/animation direction | Suggested AI personality lean for generated opponents |
|---|---|---|---|
| **Breaker** | AXE or BLUNT equipped | Wide stance, slow heavy windup, biggest hit-stop + shake, armour-cracking VFX emphasis | Aggressive / Berserker-leaning (high aggression, low caution) |
| **Duelist** | SWORD equipped, light-medium armour | Balanced stance, medium-fast timing, clean slash arcs | Balanced / Opportunistic |
| **Skirmisher** | SPEAR equipped | Longer reach poke animation, favors MEDIUM band, quick recovery | Cautious / kiting-aware (reuses existing ranged retreat-bonus logic) |
| **Marksman** | RANGED (bow) equipped | Draw-hold-release timing, visible arrow trail (already exists via `arrow_visual.gd`), prioritizes CLOSE..LONG | Cautious / resource_care-high (manage the 4-arrow quiver) |
| **Battlemage / Elementalist** | MAGICAL equipped | Cast anticipation beat, status-flavored burst on release (already exists in `combat_vfx.gd`), fragile stance cues | resource_care-high, caution-high (mana-conscious) |
| **Guardian** | Shield equipped + heavy armour weight, any weapon class | Wide defensive stance, block/parry animation emphasis, higher `Defend` visual readability | Defensive-leaning (high caution, low aggression) |

`OpponentGenerator` should pick an `AIPersonality` whose weights are *consistent* with the
generated build's archetype (a generated Marksman should not roll `aggressive`) — this is a
generation-time pairing rule, not a new mechanic, and directly answers the "AI should reason
like its class" ask without inventing a class system.

---

## §51. COMBAT FEEL & CAMERA SPEC (addresses G1–G3)

**Hit-stop (`CombatFeel` helper, new small static class alongside `CombatVfx`):**
```
on_hit(weapon_class, is_crit) -> brief Engine.time_scale dip (e.g. 0.05–0.12s), scaled by:
  - weapon_class weight tier (dagger/unarmed shortest, greatsword/warhammer longest)
  - crit multiplier (longer freeze on crit, matching the existing bigger shake on crit)
  - the SAME "reduced_fx"/screen_shake accessibility settings CombatVfx already reads —
    never introduce a second, inconsistent accessibility toggle.
```
Must not desync `RngService`-driven combat resolution — hit-stop is a presentation-layer
`await`/tween around already-resolved results, never something that changes turn order or
timing-sensitive logic (there is none currently, keep it that way).

**`CombatCamera` (new `Camera2D` under the arena scene):**
- Frames the midpoint between both fighters' current cell positions (`CombatContext` already
  exposes these).
- Zoom scales with cell separation: tighter at ADJACENT, wider at LONG — this also makes bow
  combat visually read as "distant" the moment it starts, for free.
- Small push-in on crit and on the killing blow; respects `screen_shake`/`reduced_fx` settings
  for shake amplitude, and should expose its own "camera motion" accessibility scalar if the
  push-in proves intense in playtesting (extend the existing settings screen, don't invent a
  parallel settings system).
- Compatibility-renderer-safe by construction (Camera2D zoom/position, no shader dependency).

**Weapon-weight timing table** (data, not per-weapon special cases — key by `WeaponClass`):
```
UNARMED/SWORD   -> fast windup, fast recovery, short hit-stop
AXE/BLUNT       -> slow windup (visible anticipation beat), long recovery, longest hit-stop + shake
SPEAR           -> medium windup, longest reach animation, medium recovery
RANGED          -> draw (windup) -> hold -> release -> arrow flight (already exists) -> impact
MAGICAL         -> cast anticipation -> release -> travel/impact (reuse status-burst VFX)
```
Implement as a single lookup table consumed by `placeholder_rig.gd`'s action-trigger code and
by the new `CombatFeel` helper — one source of truth, not five hardcoded branches.

---

## §52. ITEMIZATION DEPTH SPEC (addresses G4–G5, executes charter §16)

1. **`AffixData` resource** (new data model, additive — no existing field changes):
   `id, stat_key, value_range, weight, min_rarity`. A small starting pool (10–15 affixes)
   covering the stat set already in `AttributeBlock`/derived stats
   (`+Strength/+Agility/+CritChance/+ArmourPenetration/+FireDamage/...`).
2. **Rarity → affix budget**, using the *existing* `Rarity` enum (no new enum, it already has
   exactly the 6 tiers the pasted prompt asked for): Common = 0 affixes, Uncommon = 1,
   Rare = 2, Epic = 3, Legendary = 3 + one **unique effect**, Mythic = 4 + one unique effect.
3. **Unique/legendary effects should hook systems that already exist**, not invent new hook
   points — this keeps the cost low:
   - "Poison you apply can stack one additional stack" → `StatusEffectSystem` already has
     `max_stacks`; a weapon-level override is a small, contained change.
   - "Blocking restores Energy" → `Defend` action already exists in `CombatAction`; add an
     optional on-defend Energy refund read from the equipped weapon/armour.
   - "Critical hits reduce active skill cooldowns" → skills already track cooldowns; a crit
     hook reducing them is additive.
   These three alone deliver the "is this better for my build?" moment the pasted prompt
   correctly identifies as the goal, without a generic buff/debuff scripting language.
4. **Equipment comparison tooltip** in `inventory_screen.gd`/`shop_screen.gd`: show equipped
   vs. candidate side by side — stat deltas (color-coded gain/loss), unmet requirements,
   rarity, sell value, unique effect text if present. Pure UI work reading from calculators
   that already exist; no new gameplay math.
5. Save impact: equipped-item unique effects read from the item resource at combat start, not
   stored per-character — **no new save version required** for this phase.

---

## §53. AI DEPTH SPEC (addresses G6–G7)

1. **Expand the `AIPersonality` roster** beyond `aggressive`: at minimum Defensive (high
   caution, low aggression), Opportunistic (aggression spikes only near a kill threshold —
   reuse the existing kill-bonus term in `combat_ai.gd`'s ATTACK score), Cautious/
   resource_care-high (for Marksman/Battlemage archetypes, §50), and one Berserker-style
   personality whose aggression *rises* as its own HP drops (a small, testable modifier on
   top of the existing formula — do not fork the scoring function per personality, keep one
   formula with personality-weighted inputs as today).
2. Pair personalities with generated builds via the archetype table (§50) in
   `OpponentGenerator`, and assign a specific, thematically fitting personality to each
   existing and future handcrafted champion individually (Maulhilda/Orzha should not share a
   personality profile with generated fodder).
3. **Debug/AI-score overlay**: a dev-only panel (hidden/disabled in release builds, per
   charter §34) subscribing to the already-firing `EventBus.ai_scores_computed` signal,
   rendering `Action: score` lines and the selected action — this is the single cheapest item
   in this entire amendment relative to its value for all future balance work, because the
   data pipeline is already built and only needs a consumer.

---

## §54. CROWD / CHARISMA COMBAT SYSTEM SPEC (addresses G8, executes charter §19)

This is simultaneously the project's own already-agreed "Recommended Next Task" and the
pasted prompt's best idea — implement it with this concrete shape rather than leaving it as a
one-line charter mention:

```
States (ordered):  Hostile -> Bored -> Neutral -> Excited -> Frenzied
Rises on:  critical hits, successful blocks/parries under pressure, landed skills after a
           near-death moment, successful Taunt-tagged skills (skill system already supports
           tagging), dramatic kills (execute-type finishes)
Decays on: stalling (reuse the EXISTING anti-stall consecutive-defend/retreat counters from
           combat_ai.gd rather than inventing a second stall detector), long fights past a
           round threshold
Effect at Excited/Frenzied:  small, situational — bonus Energy on the crowd-favored fighter's
           next turn, or a temporary small accuracy/damage nudge — NEVER large enough that
           ignoring Charisma is a mistake for every build, per charter's own itemization
           philosophy (a stat should create a real choice, not an auto-include)
Charisma's role: higher Charisma raises the rate the meter climbs and/or unlocks a Taunt-class
           skill effect that manipulates it directly — this is what makes Charisma a genuine
           combat-support stat instead of a shop-discount-only stat, closing the exact gap
           charter §13 already promises ("must be a genuinely viable combat-support stat")
           but §19 never delivered.
```
Implementation notes: this needs one new lightweight runtime value on `Combatant`/
`CombatContext` (the meter state) — not a new save field (it resets every fight, like Energy)
so it does **not** require a save-version bump. HUD gets one small new element (a bar/icon);
reuse existing bar-drawing UI patterns rather than a new widget system.

---

## §55. RIVALS & BOSS PHASES SPEC (addresses G9)

**Rivals:** pick 1 recurring named opponent per arena region (not a new subsystem — reuse the
*player's own* already-built patterns): a rival carries `weapon_memory`-equivalent state
(what it fought with last time) and a `battle_fatigue`-equivalent penalty/buff depending on
whether it beat or lost to the player last time, stored the same way profile state already is
(new small fields, next save version). A rival that has beaten the player should visibly carry
better gear next time; one the player has beaten should show a minor, narratively-flavored
setback. This is symmetry with existing session-6 mechanics, not a new design language.

**Boss phase transitions:** add HP-threshold behavior changes to champions (100–60% normal,
60–30% unlocks a signature ability already defined on the champion, <30% personality shift
toward higher aggression via the existing `AIPersonality` weighting, not a hardcoded branch).
Implement as data on the champion's AI configuration (threshold → personality/ability
override), consumed by the existing utility-AI loop — not a bespoke boss-only code path.

**Random events (charter §23):** lowest priority in this amendment — data-driven event
definitions between fights are well-specified in v1 and not blocked by anything above; pick
up after §51–§54 land, per the phase order below.

---

## §56. UPDATED PHASE PLAN (supersedes only the *ordering* of PROJECT_STATE's "Next 5 Tasks," not their content)

Ordered by the charter's own priority rule — combat feel and build-diversity work before more
raw content, because the loop already works and these are what currently make it read as thin:

```
Phase 11  Combat Feel        — CombatFeel hit-stop helper, CombatCamera, weapon-weight
                                timing table (§51). No save-version change.
Phase 12  Itemization Depth  — AffixData, rarity-driven affix rolls, 3 starter unique
                                effects reusing existing hooks, equipment comparison
                                tooltip (§52). No save-version change (equip-time reads).
Phase 13  Crowd / Charisma   — audience meter, crit/taunt/near-death triggers, situational
                                reward, HUD element (§54). One new save version if any
                                cross-fight Charisma-related state is added; the meter
                                itself resets per fight and needs none.
Phase 14  AI Depth           — personality roster expansion, archetype-personality pairing
                                in OpponentGenerator, per-champion personalities, debug/
                                AI-score overlay (§53). No save-version change.
Phase 15  Rivals & Bosses    — 1 rival per region reusing weapon_memory/battle_fatigue
                                patterns, champion phase transitions (§55). New save
                                version for rival state.
Phase 16  Content & Modes    — third arena region + champion, additional opponent
                                archetypes (mage/skirmisher growth weights per
                                PROJECT_STATE's own note), random events (§23), difficulty
                                tiers/NG+ (§24) evaluation, economy simulation pass.
```
Each phase still closes only when charter §41's Definition of Done is met: tests exist and
pass, affected scenes launch clean, Web smoke-tested if rendering/input/audio changed,
`PROJECT_STATE.md`/`DEVELOPMENT_LOG.md` updated to match reality, no unmarked placeholder.

---

## §57. NON-GOALS REAFFIRMED (do not silently reintroduce these)

- Hard character classes or class-gated equipment/skills (§47).
- Any real-money purchase, ad SDK, or telemetry (charter §5) — still untouched by this
  amendment.
- C#, Forward+-only effects without a Compatibility fallback, threads on Web (charter §4).
- Rebuilding character art, HUD chrome, or the arena backdrop from scratch — rig v4/arena v2
  already clear the bar the pasted prompt worried about (§48); spend art/animation effort on
  §51's timing/camera work instead, which is where the actual "reads as a prototype" feeling
  comes from at this point, not flat character silhouettes.
- More than one save-breaking change per phase (§56 marks which phases need one).
- A generic combat-log panel — the owner explicitly rejected this (docs/combat.md); feedback
  stays visual/audio.

---

## §58. HOW FUTURE AGENTS USE THIS FILE

1. Read `AI_GUIDE.md` → `PROJECT_STATE.md` → latest `DEVELOPMENT_LOG.md` entries → this file's
   relevant phase section (§56) → the source + tests for the system being touched.
2. Scope one phase-11-through-16 chunk at a time, same discipline as v1 §9 (Autonomous Session
   Protocol) — never "do the whole amendment" as one unit of work.
3. On completion of a chunk: run tests, launch the affected scene(s), update
   `PROJECT_STATE.md`, append `DEVELOPMENT_LOG.md`, and update `AI_GUIDE.md` only if something
   *permanent* changed (e.g., a new architecture rule like "combat feel timing lives in one
   lookup table," not "added hit-stop").
4. If a future owner decision reopens §47 (hard classes) or any other reaffirmed pillar in
   §46, log it the same way §47 was logged here — dated, with Reason/Alternatives/
   Consequences — do not silently drift.
