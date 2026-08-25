class_name ArmourData
extends Resource
## Static definition of an armour piece (charter §16). Minimal for the combat
## prototype phase — modifiers/resistances expand with the equipment phase.

@export var id: StringName
@export var name_key: String = ""
@export var slot: Enums.EquipSlot = Enums.EquipSlot.CHEST
@export var armour_class: Enums.ArmourClass = Enums.ArmourClass.MEDIUM
## Painted icon of the piece on its own, for shop and inventory rows. Null
## falls back to the shared per-slot glyph (charter §27).
@export var icon: Texture2D
## Tiling material patch the rig fills this piece's shapes with (leather,
## mail, plate, cloth...). Null leaves the rig's flat tone alone.
@export var material_texture: Texture2D
## Contribution to the combat armour pool (absorbs damage before HP).
@export_range(0, 999) var armour: int = 5
## Evasion modifier — heavy armour typically negative, light positive/zero.
@export_range(-50, 50) var evasion_mod: int = 0
## Mobility gear bonus (session-5 owner design): counts toward the arena
## move-distance tier alongside Agility. Boots/leg pieces mostly.
@export_range(0, 5) var mobility_bonus: int = 0

@export_group("Signature")
## Legendary/Mythic signature effect (V2 §52). Read at combat start from the
## equipped kit — never stored on the character, so no save version changes.
@export var unique_effect: Enums.UniqueEffect = Enums.UniqueEffect.NONE

@export_group("Progression")
@export_range(1, 8) var tier: int = 1
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
## Unique rewards (champion drops) set this false — never sold in shops.
@export var shop_available: bool = true
@export_range(0, 100000) var value: int = 10
@export_range(1, 60) var required_level: int = 1
@export_range(0, 200) var required_strength: int = 0
