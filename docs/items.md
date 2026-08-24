# Items & Economy — Technical Detail

Status: Phase 4 implemented. Enchantments, durability, modifiers, rarity rolls
arrive in later phases (design in charter §16).

## Catalog
All content is `.tres` under `data/weapons|armour|skills`, listed explicitly in
`data/registry/item_registry.tres`, indexed by the `ItemDB` autoload
(id -> resource; lazy indexing so headless tools work). Gameplay references
stable ids (`weapon.pit_hatchet`) — never paths.

Current: 13 weapons (5 classes, T1-T4 incl. the champion-unique Doorslab),
12 armour pieces (5 slots, T1-T3), 10 skills. `shop_available = false` marks
champion-unique rewards (excluded from shops AND opponent generation).

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
