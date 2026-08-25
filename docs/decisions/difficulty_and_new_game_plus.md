# Evaluation — difficulty tiers, Iron Gladiator, New Game+ (charter §24)

Status: **evaluation only, no code written.** Amendment V2 §56 asks phase 16 to
*evaluate* §24 rather than build it. This is that evaluation, written against the
codebase as it stands after phases 11-16 (session 7). It ends in a recommendation
that needs an owner decision before anything is built.

## What §24 actually asks for

1. Defeat costs gold / tournament progress / a temporary injury — never character
   deletion.
2. An optional **Iron Gladiator** mode with permanent death.
3. Difficulty tiers (Casual, Normal, Veteran, Legendary) that change **AI behaviour
   and encounter composition**, not enemy HP multipliers.
4. **New Game+** after the final boss: carries appearance / some equipment /
   cosmetics / achievements; enemies gain better AI, modifiers, new abilities and
   additional item tiers.

## Where the game already is

Point 1 is **done and has been for two sessions**, just not under this name: a loss
pays a reduced purse (`economy.gold_loss_fraction`), forfeits an active tournament
bracket, and inflicts `battle_fatigue` — the next fight opens at 60% Energy. That is
precisely "gold, progress, and a temporary injury". No work needed; the charter item
is satisfied.

Point 3 is the interesting one, because **every mechanism it needs now exists**:

| Tier lever | Existing mechanism | Cost to use |
|---|---|---|
| AI temperament | `AIPersonality` weights + `wounded_fury` / `killer_instinct` (phase 14) | data only |
| Encounter composition | `OpponentGenerator.GROWTH_PROFILES` weights, `elite` flag (phase 16) | data only |
| Opponent gear | tier cap in `_assign_gear`, affix budget by rarity (phase 12) | one offset field |
| Rival pressure | `RivalService.APPEARANCE_CHANCE` / `MOMENTUM_CAP` (phase 15) | data only |
| Crowd support | `CrowdSystem` boon thresholds (phase 13) | data only |

A `DifficultyData` resource holding those five numbers, a profile field naming the
chosen tier, and a picker on the creation screen would deliver all four tiers
**without a single new system** — and without ever multiplying an HP pool, which is
exactly what the charter forbids. Estimated shape: one resource model, four `.tres`
files, one save-version bump, one settings/creation control, one test suite.

Point 2 (Iron Gladiator) is cheap to implement and expensive to get right. The
mechanics are a profile flag plus `SaveManager.delete_profile()` on death. The real
cost is that the game currently autosaves after every fight, purchase and level-up
(charter §31) — permadeath means those autosaves become the thing that kills you,
so the mode needs its own save discipline and a very loud confirmation flow. It is
also a taste decision about what this game IS, which is the owner's call, not an
engineering one.

Point 4 (New Game+) is **blocked, and not by effort**: there is no ending. The
`GameState.ENDING` enum value exists and nothing routes to it — the game currently
stops at "third region champion defeated". NG+ carries progress *past a finish
line* that has not been drawn yet. Building it now would mean inventing the ending
as a side effect of a difficulty feature, which is the wrong order.

## Recommendation

1. **Do not build NG+ yet.** Draw the ending first (a final-region victory flow with
   a real conclusion, charter §30), then NG+ becomes a small carry-over layer.
2. **Difficulty tiers are the best value in §24** and can be built as pure data over
   phase 11-16 systems. Recommended as a future phase in its own right, not bolted
   onto another.
3. **Iron Gladiator needs an owner decision** before any code: it changes what the
   game is for, and it fights the autosave design on purpose.
4. Point 1 needs nothing — it is already shipped; the charter checklist should record
   it as done rather than pending.
