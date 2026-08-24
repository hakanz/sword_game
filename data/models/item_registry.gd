class_name ItemRegistry
extends Resource
## Explicit list of all shippable items, indexed by ItemDB at startup.
## Adding content = create the .tres AND list it here (a data task, no code).
## An explicit registry (vs directory scanning) stays reliable inside
## exported .pck files on every platform.

@export var weapons: Array[WeaponData] = []
@export var armour: Array[ArmourData] = []
@export var skills: Array[SkillData] = []
