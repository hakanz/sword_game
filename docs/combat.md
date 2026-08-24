# Combat System — Technical Detail

Status: combat + skills + status effects implemented. Crits, spells, shields,
consumables and the crowd meter land in later phases; their pipeline slots are marked.

**Session-2 design directives (2026-08-24, owner decision):**
- **Attacks land only toe to toe (ADJACENT).** Every weapon and strike skill hits at
  separation 1 and nowhere else — enforced in DATA (all weapon ranges 0-0), the range
  code stays band-capable if ranged combat ever returns (docs/balancing.md notes the
  paused ranged identity).
- **Movement is personal.** Each fighter stands on their own cell of an 8-cell arena
  line; approach/retreat moves ONLY the acting fighter one cell (never both). Bands
  derive from cell separation: 1=ADJACENT, 2=CLOSE, 3=MEDIUM, 4+=LONG. The arena wall
  (cells 0/7) blocks further retreat.
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
| Attack | weapon `energy_cost` | only at ADJACENT; roll to hit, damage pipeline below |
| Defend | 0 | stance until own next turn: +8 avoidance, −30% damage taken |
| Approach / Retreat | 2 | move OWN cell by 1 (wall-clamped; cannot enter foe's cell) |
| Rest | 0 | +40% max Energy and +8% max HP (invalid only when both are full) |

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
