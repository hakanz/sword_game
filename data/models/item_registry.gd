class_name ItemRegistry
extends Resource
## Explicit list of all shippable items, indexed by ItemDB at startup.
## Adding content = create the .tres AND list it here (a data task, no code).
## An explicit registry (vs directory scanning) stays reliable inside
## exported .pck files on every platform.

@export var weapons: Array[WeaponData] = []
@export var armour: Array[ArmourData] = []
@export var skills: Array[SkillData] = []
## Item modifier pool (V2 §52). Which affixes an item ends up with is derived
## from the item itself — see ItemAffixes.
@export var affixes: Array[AffixData] = []
## Arena regions, ordered by ArenaData.order.
@export var arenas: Array[ArenaData] = []
