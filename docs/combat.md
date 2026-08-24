# Combat System — Technical Detail

Status: **Phase 2 (combat prototype) implemented.** Crits, skills, spells, status effects,
shields, consumables and crowd effects land in later phases; their pipeline slots are marked.

## Flow
`CombatController` (scene `scenes/arena/arena.tscn`) orchestrates:
```
COMBAT_START -> [ROUND_START -> per fighter: TURN_START -> action select
(HUD input or CombatAI) -> validate (CombatAction) -> execute (calculators)
-> DEATH_CHECK] -> ... -> COMBAT_END -> results scene
```
- `TurnManager` — initiative order (desc), seeded random tiebreak, corpse skipping,
  round counting. Round cap `CombatTuning.MAX_ROUNDS = 100` (stalemate = higher HP% wins).
- 1v1 duels use a single shared `CombatContext.distance` band (ADJACENT/CLOSE/MEDIUM/LONG)
  instead of per-fighter positions — simplest correct model for a duel; would generalize to
  positions if multi-combatant fights are ever added. (Decision: simpler state, no loss of
  behavior for 1v1; consequence: multi-fighter needs a refactor of CombatContext only.)

## Actions (current set)
| Action | Energy | Effect |
|---|---|---|
| Attack | weapon `energy_cost` | roll to hit, damage pipeline below |
| Defend | 0 | stance until own next turn: +8 avoidance, −30% damage taken |
| Approach / Retreat | 2 | shift distance band by 1 |
| Rest | 0 | restore 40% of max Energy (invalid at full Energy) |

Validation + costs: single source `CombatAction` (HUD buttons, AI filtering, and controller
execution all call it).

## Hit chance (`HitCalculator`)
```
accuracy  = attack_rating + weapon.accuracy_bonus + modifiers
avoidance = defence_rating + evasion + stance_bonus (defend: +8)
chance    = clamp(0.50 + 0.02 * (accuracy - avoidance), 0.05, 0.95)
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

## Determinism
All combat randomness flows through `RngService` (`--combat-seed=N` reproduces a fight).
Decorative visuals (crowd, sand) use local fixed-seed RNGs so they never consume combat
rolls. Smoke test: `--smoke-test --combat-seed=N` plays AI-vs-AI to the result screen and
exits 0/1; it prints a combat trace per action for CI diagnosis.
