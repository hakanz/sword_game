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

## Session 7 / phase 12 — itemization affixes land (2026-08-25)

`godot --headless --path . -s res://tools/battle_sim.gd -- --battles=150`, run
AFTER rarity started granting modifiers (V2 §52):

```
default kit vs generated L1      80.7%   avg 19.7 rounds
default kit vs generated L5      63.3%   avg 21.2 rounds
default kit vs generated L10     50.0%   avg 21.6 rounds
balanced vs brawler (L1)         52.7%   avg 20.0 rounds
balanced vs swift   (L1)         40.0%   avg 19.1 rounds
brawler  vs swift   (L1)         44.7%   avg 17.6 rounds   (0 stalemates anywhere)
```

Reading it: the origin presets are unchanged inside the 40-60% viability band —
they fight at level 1 in Common gear, which carries no modifiers by design, so
this confirms affixes did NOT disturb the starting balance.

The "default kit" line moved a lot (was 89/78/76% at L1/L5/L10): that matchup is
a gladiator who reached level N and **never bought anything** — Worn Shiv, no
armour — against a generated fighter who now carries modifier-bearing gear. A
50% win rate at level 10 for a fighter in rags is the intended consequence of
making equipment matter; the previous 76% said the shop was optional. This is a
deliberate accepted swing, not a regression — but it makes the shop the pacing
gate, so watch gold income if level-10 players report feeling stuck (the
`first_victory_gold_bonus` / arena purses are the knobs).

Affix value bands were kept modest on purpose (attributes +1..3, armour +1..4,
crit +1..4%, penetration +3..10%) so a single Uncommon drop shifts a fight
without deciding it. The 1-25% crit clamp still binds with affixes stacked.

