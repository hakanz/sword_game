# Combat System — Technical Detail

Status: combat + skills + status effects implemented. Crits, spells, shields,
consumables and the crowd meter land in later phases; their pipeline slots are marked.

**Session-2 design directives (2026-08-24, owner decision):**
- **Melee lands only toe to toe (ADJACENT).** Every melee weapon and strike skill hits
  at separation 1 (data-enforced). **Bows are the session-3 exception:** ranged again,
  firing from CLOSE..LONG (never point-blank) with a 4-arrow quiver per fight, a knife
  sidearm auto-carried, and weapon switching as its own action — archers OPEN on the
  knife and must switch to shoot. Arrows are spent hit or miss; empty quiver = knife time.
- **Movement is personal.** Each fighter stands on their own cell of an 8-cell arena
  line; approach/retreat moves ONLY the acting fighter (never both). Bands
  derive from cell separation: 1=ADJACENT, 2=CLOSE, 3=MEDIUM, 4+=LONG. The arena wall
  (cells 0/7) blocks further retreat.
- **Mobility tiers (session 5):** one move covers 1 cell, or 2 when
  `agility + 2*gear mobility_bonus >= 14` (`ProgressionCalculator.move_cells`; boots
  carry the gear bonus). Approach always stops at separation 1; retreat clamps at the
  wall. Step animation speed also scales with agility.
- **The player opens every fight** (session 5): TurnManager puts the player-controlled
  fighter first; everyone else follows by initiative. AI-vs-AI runs keep pure
  initiative order (simulator/CI unchanged).
- **Rest heals too:** 40% max Energy + 8% max HP; valid whenever either is missing.
- **No combat log panel** — feedback is visual/audio (floating numbers, sparks, shake,
  synthesized SFX, announcement banner for champion lines).

## Flow
`CombatController` (scene `scenes/arena/arena.tscn`) orchestrates:
```
COMBAT_START -> [ROUND_START -> per fighter: TURN_START -> action select
(HUD input or CombatAI) -> validate (CombatAction) -> execute (calculators)
-> DEATH_CHECK] -> ... -> COMBAT_END -> results scene
```
- `TurnManager` — initiative order (desc), seeded random tiebreak, corpse skipping,
  round counting. Round cap `CombatTuning.MAX_ROUNDS = 100` (stalemate = higher HP% wins).
- Positioning: per-fighter cells on an 8-cell line (`CombatContext`, session-2 rework —
  replaced the old shared-distance model so movement could be personal).

## Actions (current set)
| Action | Energy | Effect |
|---|---|---|
| Attack | weapon `energy_cost` | melee at ADJACENT; bows CLOSE..LONG with 4 arrows | 
| Defend | 0 | stance until own next turn: +8 avoidance, −30% damage taken |
| Approach / Retreat | 2 | move OWN cell by 1 (wall-clamped; cannot enter foe's cell) |
| Rest | 0 | +40% max Energy and +8% max HP (invalid only when both are full) |
| Switch weapon | 0 | swap main <-> sidearm (archers only for now); consumes the turn |

Validation + costs: single source `CombatAction` (HUD buttons, AI filtering, and controller
execution all call it).

## Hit chance (`HitCalculator`)
```
accuracy  = attack_rating + weapon.accuracy_bonus + modifiers
avoidance = defence_rating + evasion + stance_bonus (defend: +8)
chance    = clamp(0.50 + 0.015 * (accuracy - avoidance), 0.05, 0.95)
            (0.02 -> 0.015 in session 3 — see docs/balancing.md)
```
Normal attacks are never 0%/100% (guaranteed-hit skills must bypass explicitly, later).

## Damage pipeline (`DamageCalculator`, strict order — charter §15)
```
raw = weapon roll [damage_min..damage_max] + attribute bonus (ProgressionCalculator)
   -> [skill multiplier — later]  -> [critical — later]
   -> resistance: raw * (1 - clamp(resist, 0, 1))
   -> defend stance: * (1 - 0.30) if defending
   -> armour penetration: pen% bypasses the armour pool straight to HP
   -> armour pool absorbs the rest 1:1, depleting
   -> overflow (pool emptied mid-hit) carries into HP — NEVER discarded
   -> [shield — later] -> HP
```
`compute_mitigation()` is pure (unit-tested, incl. conservation invariant
`absorbed + hp_damage == after_stance`). `Combatant.take_damage()` applies results.

## Armour model (decision)
Armour is a **depleting pool** refilled each combat (sum of equipped `ArmourData.armour`),
not a flat % reduction: keeps damage numbers readable, makes armour-penetration weapons
(mace/crossbow identity) meaningful, and produces the dramatic "armour broken" mid-fight
beat. Alternatives considered: %-mitigation (opaque, no depletion drama), HP padding
(armour would be a stat, not equipment identity).

## Derived stats (`ProgressionCalculator` — only home of these formulas)
```
max_hp     = 50 + VIT*6 + level*4        max_energy = 40 + STA*4 + level*2
max_mana   = 10 + ARC*5
attack_rating = ATT*2 + AGI              defence_rating = DEF*2
evasion    = AGI + equipment_mod         initiative = AGI*2 + ATT
attribute damage bonus per weapon class:
  sword .3*STR+.2*AGI | axe/blunt .5*STR | spear .35*STR+.15*AGI
  ranged .4*AGI | magical .5*ARC | unarmed .25*STR
```
All coefficients are tuning values (`CombatTuning` for combat, these functions for
progression) — change freely with balancing evidence, document swings in docs/balancing.md.

## Tournaments & regions (charter §21)
Arena regions live in data (`ArenaData.order/min_level/max_level/champion`);
region N+1 unlocks by winning region N's 4-round tournament (Qualification/
Quarter/Semi/Final-vs-champion, single sitting, leaving forfeits). Flow state
sits on GameManager (`tournament_*`); completion persists on the profile
(save v5). Normal-duel opponents clamp to the selected region's level band.

**Session-5 additions:** once the tournament is open (3 victories) and the
player reaches the region band midpoint, `GameManager.tournament_required()`
LOCKS normal duels until the bracket is fought (guarded inside
`start_next_duel`, mirrored by town/results UI). Bracket rounds 1-3 generate
ELITE opponents (`OpponentGenerator.generate_at_level(level, true)`: +1 gear
tier, fuller armour coverage, always 2 skills). Completing the bracket pays
`economy.tournament_gold_bonus` on top of the final's rewards, and champion
wins pay `config.champion_xp_multiplier` XP (the level-pacing anchor).

**Effectiveness XP (session 5):** `CombatResolver` tallies `actions_taken` /
`hits_landed`; XP scales by `combat_effectiveness = clamp(0.65 + 0.9 *
hits/actions, 0.65, 1.25)` — real fighting earns more, stalling less.

**Session-6 additions:**
- **Critical hits:** per-weapon base chance (`WeaponData.crit_chance`) + the
  class-matched attribute (`HitCalculator.crit_attribute`: axe/blunt=STR,
  sword/bow=AGI, spear=ATT, staff=ARC) × `CRIT_ATTR_PER_POINT` (0.2%/pt),
  clamped 1-25%. Damage ×2 at the §15 Critical step; both sides roll the
  same math; AI expected damage includes the crit EV.
- **Opening distance:** default cells 1/6 (LONG) — closing is part of the
  fight. Level-1 opponents and the new player both start armourless.
- **Weapon memory:** a WON fight carries the end-of-fight weapon into the
  next one (`profile.prefers_main_weapon`); a LOSS resets to the sidearm
  and drains the next opening to 60% energy (`battle_fatigue`, save v6).
- **Auto-rest:** a player turn at 0 energy rests automatically.
- **Debut:** the first-ever victory pays `first_victory_gold_bonus` and
  tops XP to a guaranteed level-up.

## Equipment modifiers in the pipeline (session 7 / phase 12 — V2 §52)

Combat reads **`Combatant.attributes`** — the character's progression block plus
the equipped kit's attribute modifiers, computed once in `Combatant.setup` — and
never `data.attributes`. Equipment must never write into progression data.
The rest of the kit folds into the existing calculators without moving a
formula: armour pool, evasion, attack rating, `HitCalculator.crit_chance_for`'s
`bonus` argument, `Combatant.armour_penetration()`, the damage roll, move tier.
Derivation is deterministic and uses a local RNG (see docs/items.md), so seeded
replays are unaffected.

Three Legendary signature effects hook the pipeline at points that already
existed: an on-hit status may exceed its `max_stacks` by one (Venom Mastery),
DEFEND may refund Energy (Bulwark Reserve), and a crit may tick every skill
cooldown down a round (Relentless Edge). Each is a data flag on the item, read
through `Combatant.has_unique()` — never a per-item branch.

## Combat feel & camera (session 7 / phase 11 — V2 §51)

Presentation layer only: **nothing here can change a combat result.** Hit-stop wraps
already-resolved results, the camera reads positions it never writes, and neither touches
`RngService` — `--combat-seed=N` replays identically with the effects on or off.

**`CombatFeel` is the ONE home of weapon-weight pacing** (`combat/combat_feel.gd`). A single
table keyed by `WeaponClass` gives windup, swing, recovery, lunge reach, shake multiplier,
hit-stop duration and attack *style*; the rig and the controller both read it, so a change to
how a maul feels is a one-line change in one file.

| Class | Windup | Recovery | Hit-stop | Shake | Style |
|---|---|---|---|---|---|
| UNARMED | 0.09 | 0.15 | 0.035 | 0.75x | swing |
| SWORD | 0.12 | 0.19 | 0.055 | 0.95x | swing |
| SPEAR | 0.15 | 0.21 | 0.06 | 1.0x | thrust (longest reach: 48px lunge) |
| AXE | 0.20 | 0.27 | 0.095 | 1.35x | swing |
| BLUNT | 0.23 | 0.30 | 0.115 | 1.5x | swing |
| RANGED | 0.19 | 0.20 | 0.045 | 0.8x | draw-hold-loose (no lunge) |
| MAGICAL | 0.21 | 0.24 | 0.07 | 0.9x | cast anticipation |

- **Hit-stop:** `Engine.time_scale` dips to 0.06 for the class's duration, x1.8 on a crit,
  capped at `MAX_HIT_STOP` (0.24s). The freeze timer runs with `ignore_time_scale` so it can
  never stretch itself, `release()` restores time flow on freeze end / combat end /
  `_exit_tree`, and the whole thing is skipped when `GameManager.smoke_test` is set (CI never
  sleeps on presentation).
- **Camera** (`combat/combat_camera.gd`, a `Camera2D` under `WorldRoot`): frames the midpoint
  of the two fighters, zoom 1.26 at ADJACENT easing to 1.0 by separation 5+ (a bow duel reads
  as distant for free), push-in on a crit (+0.05) and a killing blow (+0.09). It never zooms
  BELOW 1.0 and clamps its visible rect to the 1280x720 design box, so no framing can reveal
  the edge of the drawn arena; a viewport wider/taller than the box centres on that axis,
  exactly like the old world-offset behaviour. The framing math is pure statics
  (`zoom_for_separation` / `focus_x` / `focus_y` / `clamp_focus`) and unit-tested headlessly.
- **Shake moved to the camera.** A world-offset shake would be cancelled by a camera that
  re-frames from world positions every frame. `CombatController._shake()` still decides
  strength (base x `CombatFeel.shake_scale` x the `screen_shake` setting) and falls back to
  the old world-offset shake if a scene has no camera.
- **Accessibility:** hit-stop honours the existing `reduced_fx` toggle (x0.4, never a second
  parallel toggle); the camera has its own `camera_motion` slider (settings screen) where 0
  reproduces the classic static frame exactly. Both apply from the next fight.

## Determinism
All combat randomness flows through `RngService` (`--combat-seed=N` reproduces a fight).
Decorative visuals (crowd, sand) use local fixed-seed RNGs so they never consume combat
rolls. Smoke test: `--smoke-test --combat-seed=N` plays AI-vs-AI to the result screen and
exits 0/1; it prints a combat trace per action for CI diagnosis.
