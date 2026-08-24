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

## Determinism
All combat randomness flows through `RngService` (`--combat-seed=N` reproduces a fight).
Decorative visuals (crowd, sand) use local fixed-seed RNGs so they never consume combat
rolls. Smoke test: `--smoke-test --combat-seed=N` plays AI-vs-AI to the result screen and
exits 0/1; it prints a combat trace per action for CI diagnosis.
