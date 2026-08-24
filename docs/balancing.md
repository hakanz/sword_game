# Balancing Notes

Working observations + tuning log. The proper N-battle simulation tooling
(charter §35) is still to be built (Phase 10) — numbers below come from seeded
smoke runs, not statistically robust simulation. Do not over-trust them.

## Current smoke-run picture (v0.1.0, level-1 start)
- AI-vs-AI duels resolve in ~9-29 rounds across seeds; no round-cap hits since
  the anti-stall rework (see docs/ai.md).
- Balanced default player vs generated level ±1 enemies: player-favored
  (~70-85% across seed batches); enemies do win (aggressive brutes with axes,
  bow users at range). Needs a real win-rate simulation before tuning further.
- Skills shift fights noticeably: War Bellow + Crushing Blow bursts ~24-28
  vs ~12 normal hits; Venom Smear finishes turtles.

## Tuning knob map
- Combat feel: `CombatTuning` (hit band, defend bonuses, rest fraction).
- AI temperament: `combat/combat_ai.gd` consts + `AIPersonality` resources.
- Curves/rewards: `data/progression/progression_config.tres`,
  `data/economy/economy_config.tres`.
- Content: item/skill/status `.tres` files.

## Ranged identity: PAUSED (owner directive, 2026-08-24)
All weapons attack at ADJACENT only ("no attacks from distance"). Bows/spears keep
their class stats but fight point-blank; the band-range code and AI kiting logic
remain data-driven and dormant. If ranged combat returns, restore per-weapon ranges
in data/weapons/*.tres and re-add a reach test.

## Known wants (revisit in Phase 10 with simulation data)
- Charisma currently prices-only; crowd system will make it combat-relevant.
- Armour pools may deplete too fast at T1 (fights become HP races after ~R5).
- Champion Maulhilda untested against real player builds beyond unit tests.
