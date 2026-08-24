# Progression — Technical Detail

Status: Phase 3 implemented (XP, levels 1-60, attribute points, skill points),
plus champion record (Phase 6 core).

## XP curve (ProgressionConfig — data, never hardcoded)
```
xp_required(L -> L+1) = base_xp * L^1.55            (base_xp = 100)
```
Level-ups grant +3 attribute points; every 2nd level +1 skill point. Cap: 60
(XP at cap clamps below the next-level requirement so bars stay sane).

## Combat XP reward
```
reward = 45 * enemy_level^1.1
       * clamp(1 + 0.15*(enemy_level - player_level), 0.4, 2.0)   # anti-seal-clubbing
       * (loss ? 0.25 : 1.0)                                       # losing still teaches
```
Gold reward (EconomyConfig): `12 * enemy_level^1.15 * (loss ? 0.2 : 1)`.
Champion first-kill: +150 gold, +25 fame, unique weapon (ProgressionService.CHAMPION_REWARDS).

## Flow
`CombatController` fills `CombatResult` -> results screen calls
`GameManager.consume_combat_rewards()` (idempotent via `rewards_applied`) ->
`ProgressionService.apply_combat_rewards()` mutates the profile (multi-level-up
loop, point grants, win/loss record, fame, champion record) -> autosave.

## Allocation
Character sheet: pending-then-confirm attribute spending with live derived-stat
preview (all numbers from ProgressionCalculator). Skills screen: 1 point per
skill, level-gated (SkillService).

## Opponent matching
`OpponentGenerator.generate(player_level)`: level ±1, the same 3-points-per-level
attribute budget as the player (weighted brute spread), tier-capped gear
(T1@1-4, T2@5-8, T3@9+), 1-2 weapon-compatible skills from level 3, varied
personality — seed-reproducible. Proper power-rating matchmaking (charter §21)
is a later-phase upgrade; document the algorithm there when it lands (and never
expose it to the player).
