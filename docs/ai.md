# Enemy AI — Technical Detail

Status: Phase 2 baseline. Personalities beyond Aggressive, procedural opponent generation,
and champion AI land in later phases.

## Principle
Utility scoring, **never uniform-random** (charter §20). All scores share one currency —
**expected damage** (dealt, or prevented) — so offense and defense stay comparable and no
action can drift into always-dominant.

## Scores (see `combat/combat_ai.gd`)
```
ATTACK   = hit_chance * E[damage after mitigation] * aggression
           + 50 * hit_chance (if expected HP damage >= foe HP)      # kill bonus
           - energy_cost * 0.15 * resource_care
APPROACH = 15 * aggression (when out of attack range), else 1
RETREAT  = [8 * caution if HP < 30%] + [12 if ranged kiting opportunity]
           all / (1 + consecutive_retreats)                          # anti-stall
DEFEND   = (E[incoming if open] - E[incoming if guarding]) * caution
           + 3 * (1 - hp_fraction)                                   # desperation
           all / (1 + consecutive_defends)                           # anti-stall
REST     = 30 * max(resource_care, .5) (cannot afford an attack)
           else (1 - energy_fraction) * 10 * resource_care
```
Estimates reuse the real calculators (`HitCalculator` with hypothetical stance override,
`DamageCalculator.compute_mitigation`) — the AI never has private math.

A seeded jitter `[0, 0.75)` breaks exact ties only; it cannot outvote a real utility gap.

## Anti-stall design (regression-tested)
Found in smoke testing: two AIs could deadlock — foe defends -> my attack estimate drops ->
my defend outscores attack -> both defend forever (101-round draws). Two fixes, both kept:
1. Defend is valued by the incoming damage it actually prevents (not by missing HP).
2. `consecutive_defends` / `consecutive_retreats` counters divide the score — turtling and
   fleeing have sharply diminishing returns.
Regression guards: `tests/unit/test_combat_ai.gd::test_stalling_has_diminishing_returns`,
plus multi-seed smoke runs (fights must resolve well under the 100-round cap; currently
13–21 rounds).

## Personalities (`AIPersonality` resource)
Multipliers around 1.0: `aggression`, `caution`, `resource_care`. Same gear, different
behavior. Current content: `personality.aggressive` (1.35 / 0.65 / 0.9). Player-as-AI
(smoke test) uses a default balanced personality.

## Debugging
Every decision emits `EventBus.ai_scores_computed(name, {ACTION: score})` — the future debug
overlay (charter §34) renders these; smoke mode prints a per-action combat trace already.

## Temperament shifts and archetype pairing (session 7 / phase 14 — V2 §53)

`AIPersonality` carries two extra weights beyond aggression/caution/resource_care:

| Field | Meaning | Who has it |
|---|---|---|
| `wounded_fury` | aggression rises as the fighter's OWN HP drops | Berserker, Maulhilda |
| `killer_instinct` | aggression rises as the FOE nears death | Opportunist, Orzha, Pyx |

`aggression_now(own_hp_fraction, foe_hp_fraction)` folds them into one number and
`CombatAI` reads THAT everywhere it used to read the flat weight. There is still a
single scoring function — temperaments differ by their weighted INPUTS, never by a
per-personality branch. Both fractions are clamped, so a nonsense value cannot run
the aggression away.

**Roster:** aggressive, defensive, cautious, opportunist, berserker, plus one
per champion (`champion_maulhilda`, `champion_orzha`, `champion_pyx`) and the
generic `boss` profile kept for future champions.

**Pairing (V2 §50/§53.2):** `OpponentGenerator` picks the temperament AFTER rolling
the kit, from `PERSONALITY_BY_ARCHETYPE` keyed by the Weapon Mastery Archetype that
kit derives to. A generated marksman can be cautious, defensive or opportunist —
never a charger. Ranged pools deliberately keep one finisher head so archers are not
all identically passive.

**Boss phases (V2 §55):** `Combatant.active_personality()` returns the champion's
phase-three personality once they fall past that threshold, and `get_skills()`
appends `phase_two_skills`. The AI scores both through its normal loop, so a boss
phase is data, not a code path.

## AI score overlay (charter §34 / V2 §53.3)

`EventBus.ai_scores_computed` fired on every decision from the AI phase onward with
nothing listening. `ui/ai_debug_overlay.gd` is the consumer: it ranks every action
the AI weighed, marks the winner, and names the temperament driving it.

- It removes itself from the tree unless `OS.is_debug_build()` or the run carries
  `--debug-ai` — a shipped build has no hidden panel and pays no per-decision cost.
- On a plain dev build it starts hidden (F3 reveals it) so it never lands in a
  screenshot uninvited; `--debug-ai` opens it immediately.
- Its gate (`should_enable`) and formatting (`format_scores`) are pure statics with
  unit tests; the node itself is a thin renderer.

