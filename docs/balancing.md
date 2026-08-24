# Balancing Notes

Working observations + tuning log. The §35 battle simulator EXISTS now:
`godot --headless --path . -s res://tools/battle_sim.gd -- --battles=300`
drives the real combat stack (CombatResolver/CombatAI) headlessly.

## Simulation results (2026-08-24, 300 battles/matchup, post-tuning)
```
default kit vs generated  L1   82.0%  avg 22.5 rounds
default kit vs generated  L5   79.0%  avg 19.6 rounds
default kit vs generated  L10  73.7%  avg 18.9 rounds
balanced vs brawler (L1)       55.7%  avg 21.6 rounds
balanced vs swift   (L1)       46.0%  avg 19.8 rounds
brawler  vs swift   (L1)       41.3%  avg 18.9 rounds   (0 stalemates anywhere)
```
Player-vs-generated is deliberately player-favored (~75-82%); all origin-preset
matchups sit inside the 40-60% viability band.

### Tuning applied from this data
- `HIT_CHANCE_PER_POINT` 0.02 -> 0.015: at 2%/point, accuracy stats dominated
  every matchup (pre-tune swift won ~76% vs both presets).
- Swift preset trimmed (AGI 11->10, ATT 10->9, +VIT/+ARC); balanced preset
  gained combat stats (CHA 5->4, ARC 3->2, +DEF/+VIT) — charisma stays a real
  price discount but a starting preset should not sink 8 points into
  not-yet-combat-relevant stats. player_default.tres synced to balanced.

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

## Ranged identity: AMMO-LIMITED BOWS (owner directive, session 3)
Bows shoot real arrows again: CLOSE..LONG bands, 4 arrows per fight, knife sidearm,
switch-to-shoot flow (see docs/combat.md). Melee stays adjacent-only. Sim shows no
stalemates from archer kiting (retreat fatigue + impatience still bound it).

## Known wants (revisit in Phase 10 with simulation data)
- Charisma currently prices-only; crowd system will make it combat-relevant.
- Armour pools may deplete too fast at T1 (fights become HP races after ~R5).
- Champion Maulhilda untested against real player builds beyond unit tests.
