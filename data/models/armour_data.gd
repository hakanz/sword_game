class_name ArmourData
extends Resource
## Static definition of an armour piece (charter §16). Minimal for the combat
## prototype phase — modifiers/resistances expand with the equipment phase.

@export var id: StringName
@export var name_key: String = ""
@export var slot: Enums.EquipSlot = Enums.EquipSlot.CHEST
@export var armour_class: Enums.ArmourClass = Enums.ArmourClass.MEDIUM
## Contribution to the combat armour pool (absorbs damage before HP).
@export_range(0, 999) var armour: int = 5
## Evasion modifier — heavy armour typically negative, light positive/zero.
@export_range(-50, 50) var evasion_mod: int = 0

@export_group("Progression")
@export_range(1, 8) var tier: int = 1
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export_range(0, 100000) var value: int = 10
@export_range(1, 60) var required_level: int = 1
@export_range(0, 200) var required_strength: int = 0
