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

## Session 7 / phases 13-16 — crowd, temperaments, content (2026-08-25)

`godot --headless --path . -s res://tools/battle_sim.gd -- --battles=150`, after the
crowd meter (phase 13), AI temperaments + archetype pairing (phase 14) and rivals /
boss phases (phase 15):

```
default kit vs generated L1      84.0%   avg 18.7 rounds
default kit vs generated L5      65.3%   avg 16.9 rounds
default kit vs generated L10     62.7%   avg 17.8 rounds
balanced vs brawler (L1)         52.7%   avg 19.9 rounds
balanced vs swift   (L1)         40.0%   avg 19.1 rounds
brawler  vs swift   (L1)         44.7%   avg 17.6 rounds   (0 stalemates anywhere)
```

Reading it:

- **Presets are untouched** (40-52.7%, inside the viability band) across all four
  phases. At level 1 with equal gear and no skills the crowd meter never climbs high
  enough to pay a boon, so the opening balance is provably undisturbed.
- **Fights got shorter at higher levels** (21.2 -> ~17 rounds): the crowd rewards
  pressure and punishes turtling/kiting, which is exactly what it was for.
- **default-kit vs generated L10 moved 48.7% -> 62.7%** when temperaments started
  matching kits. An in-character marksman kites instead of charging, which is
  thematically right and mechanically less optimal against a naked opponent. Accepted:
  the matchup measures a gladiator who reached level 10 and never bought anything, and
  62% for a fighter in rags is still a real fight.

### Economy pacing (`tools/economy_sim.gd`, new this session)

```
level   gold/win  gold/fight   next unlock                   price   fights
1             12        9.0    weapon.scrap_bow                 34      3.8
5             76       57.7    weapon.dented_maul               93      1.6
11           189      143.7    weapon.horned_maul              265      1.8
14           250      190.0    weapon.black_iron_greatsword    421      2.2
17           312      237.0    weapon.venomtooth_cleaver       627      2.6
20           376      285.7    weapon.mountainbreaker         1254      4.4
```

Two findings, both acted on:

1. **Levels 20+ had nothing to buy** — the third region shipped without gear behind
   it. Fixed by the T6 tier (docs/items.md).
2. **The shop has never been a real constraint**: 1.6-2.6 fights per upgrade through
   the whole T1-T5 ladder. T6 is priced at 4.4 deliberately, as a first step toward
   gear being a decision rather than a formality. Tightening the earlier tiers would
   be a separate, owner-visible pacing change and is NOT done here.

### After the phase 13-16 review fixes (same session)

The adversarial review measured the crowd meter behaving as a plateau rather
than an economy (Excited-or-better on 54.6% of turns, worth ~9 points of win
rate; skill-less builds stuck at Neutral for 92% of turns; bow builds parked in
Hostile for 24.9%). Four changes followed — a landed ordinary attack pays +2,
SELF buffs count as landed skills, retreats are free up to the anti-stall
budget, and accepting the crowd's help SPENDS 8 standing. Re-measured, 150
battles per matchup:

```
default kit vs generated L1      82.0%   avg 17.7 rounds
default kit vs generated L5      68.7%   avg 18.8 rounds
default kit vs generated L10     62.0%   avg 19.8 rounds
balanced vs brawler (L1)         52.0%   avg 19.7 rounds
balanced vs swift   (L1)         39.3%   avg 19.0 rounds
brawler  vs swift   (L1)         43.3%   avg 17.5 rounds   (0 stalemates anywhere)
```

The ladder did not move (all six cells within noise of the pre-fix run), which
is the point: the meter became something you spend and re-earn instead of a
passive, without changing who wins.

Rivals also stopped being level-scaled in name only — they were arriving with
their authored attribute block, which measured at an 8% win rate at the top of
a band and 100% at the bottom. They now grow on the same 3-points-per-level
budget as every other fighter.

