# Items & Economy — Technical Detail

Status: Phase 4 + phase 12 implemented. Rarity now drives item MODIFIERS and
Legendary signature effects (below). Durability and enchanting-as-a-verb (the
player improving an item) are still future phases.

## Catalog
All content is `.tres` under `data/weapons|armour|skills`, listed explicitly in
`data/registry/item_registry.tres`, indexed by the `ItemDB` autoload
(id -> resource; lazy indexing so headless tools work). Gameplay references
stable ids (`weapon.pit_hatchet`) — never paths.

Current: 31 weapons (6 classes + the unarmed fallback, T1-T5, incl. the two
champion-unique Legendaries), 26 armour pieces (7 slots, T1-T5), 14 skills, and
a 15-entry affix pool (`data/affixes/`). `shop_available = false` marks
champion-unique rewards (excluded from shops AND opponent generation);
Legendary rarity is additionally excluded from generated loadouts.

## Weapon identity levers
damage range, accuracy bonus, armour penetration, distance bands
(spears reach MEDIUM, bows fire CLOSE..LONG but not ADJACENT), energy cost,
attribute scaling per class (ProgressionCalculator), requirements
(level/STR/AGI/ARC) that create "two points away" anticipation (charter §16).

## Prices (EconomyCalculator + EconomyConfig — the only price authority)
```
buy  = value * (1 - min(charisma * 0.004, 0.25))
sell = value * min(0.35 + charisma * 0.002, 0.5), clamped < buy  # no money loops
```
The sell<buy invariant is enforced structurally AND tested across the catalog
at charisma 1..200. Reputation modifiers slot in with the fame phase.

## Ownership model
Profile: equipped (`weapon_id`, `armour_ids`) + satchel (`inventory_*_ids`).
`EquipmentService` owns requirement gating and swap bookkeeping (same-slot
armour swap; failed equips never consume items). Shop buys allow items you
cannot equip yet — anticipation is a feature; the row shows the requirement.

## Item modifiers (phase 12 — charter §16, amendment V2 §52)

### Decision: modifiers are DERIVED, not rolled per drop
```
Decision:      an item's affixes are a pure function of its own identity —
               `id` seeds a local RandomNumberGenerator, `rarity` sets how many
               modifiers it gets, the pool's weights pick them.
Reason:        the satchel is a list of item IDs (`inventory_weapon_ids`), so two
               copies of a sword ARE the same entry. Per-drop rolls would need a
               per-instance item model, a new save version with a lossy migration
               for existing inventories, and duplicate-aware inventory UI —
               V2 §52 scopes this phase to "no save-version change".
Consequences:  a Bronze Gladius always carries the same modifiers, so the player
               can LEARN the catalog and a shop row can promise what it shows.
               Editing the affix pool re-derives every item (a content change,
               never a save break). Two identical items are never "one good roll,
               one bad roll" — that trade-off is accepted.
Alternative:   classic ARPG per-drop rolls. Rejected for this phase; revisit only
               together with a per-instance item runtime model.
```
The derivation uses a LOCAL rng, never `RngService` — combat replays for a given
`--combat-seed` are byte-identical with or without itemization (AI_GUIDE
"Centralized RNG").

### Rarity -> modifier budget
| Rarity | Modifiers | Signature effect |
|---|---|---|
| Common | 0 | — |
| Uncommon | 1 | — |
| Rare | 2 | — |
| Epic | 3 | — |
| Legendary | 3 | yes |
| Mythic | 4 | yes |

Common carries nothing on purpose: the debut arc's starter gear (Worn Shiv,
Training Shortsword, Skinning Knife) must stay exactly as tuned.

### The pool (`data/affixes/*.tres`, listed in the item registry)
15 affixes covering the 8 attributes plus armour, evasion, accuracy, crit
chance, armour penetration, flat damage and mobility. Each carries a value band,
a selection weight, a `min_rarity` gate (crit / penetration / arcana / mobility
are Rare+) and a weapon/armour/any gate. Bands are deliberately modest
(attributes +1..3, armour +1..4, crit +1..4%, penetration +3..10%) — one
Uncommon drop should shift a fight, not decide it.

### Where modifiers take effect
`ItemAffixes.kit_bonuses()` sums the MAIN weapon plus worn armour once, at
combat start (`Combatant.setup`). Combat then reads `Combatant.attributes` —
base progression attributes plus the kit's attribute modifiers — and never
`data.attributes`, so equipment can grant Strength without ever writing into
progression data. The remaining bonuses fold into the existing calculators
(armour pool, evasion, attack rating, `HitCalculator.crit_chance_for` bonus
argument, weapon penetration, damage roll, move tier).

Fixed at fight start, from the **main** weapon: switching to the sidearm
mid-duel never rewrites max HP or armour (and every sidearm is Common anyway).

### Signature effects (Legendary+, `Enums.UniqueEffect`)
A small CLOSED set that hooks systems which already exist — never a scripting
language:
| Effect | Item | Hook |
|---|---|---|
| Venom Mastery | Venomtooth Cleaver (T5 axe, shop, level 15) | `StatusEffectSystem.apply` bonus-stack ceiling, on-hit statuses only |
| Bulwark Reserve | Doorslab (Maulhilda's reward) | DEFEND branch refunds `CombatResolver.DEFEND_ENERGY_REFUND` Energy |
| Relentless Edge | Sablefang (Orzha's reward) | a crit ticks every skill cooldown down one round |
| Arcane Echo | Ashquill Rod (Pyx's reward) | a skill that CONNECTS refunds half its mana cost |

`OpponentGenerator` filters Legendary out of generated loadouts: signature gear
is a player chase item or a champion reward, never random pit-fighter kit.

### Comparison UI (`ui/item_compare.gd`)
Shop and inventory rows show rarity beside the name, the item's modifiers, its
signature effect text, and colour-coded deltas against whatever occupies that
slot right now (gains on one line, losses on the next). It formats only — every
number comes from the calculators combat uses.

Prices are unchanged: the authored `value` remains the single price authority
(EconomyCalculator), and modifiers are part of what that value buys.

## T6 — the Saltmere ladder (session 7 / phase 16)

Six weapons and three armour pieces gated at levels 18-19, added because
`tools/economy_sim.gd` showed the new third region had nothing on the shelf behind
it. Priced so a purchase costs ~4.4 fights of income at that level — the tightest
ratio in the game (T1-T5 sit at 1.6-2.6, i.e. the shop has never really been a
constraint). Levels 21-24 deliberately stay a "you are kitted, now win the region"
stretch with nothing new to buy.

Run the report with:

```
godot --headless --path . -s res://tools/economy_sim.gd -- --charisma=20
```

## Rivals and gear (V2 §55)

`RivalService` arms a region's recurring rival from the rivalry record: ahead of the
player they carry the next tier UP IN THE SAME WEAPON CLASS (a rival never changes
fighting style, they just bring something nastier), behind they carry the same blade
and one piece of armour fewer. Legendary rarity is filtered out of that upgrade path
for the same reason it is filtered out of `OpponentGenerator`: signature gear is a
player chase item or a champion reward, never something you meet in an ordinary duel.

