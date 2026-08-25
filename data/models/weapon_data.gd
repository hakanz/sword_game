class_name WeaponData
extends Resource
## Static definition of a weapon (charter §6: data, not code; §16).
## Runtime state (durability, enchant level) will live in a separate
## EquippedWeapon runtime object in the equipment phase — never here.

## Stable logical ID, e.g. &"weapon.rusty_shortsword" (charter §12).
@export var id: StringName
## Localization key for the display name.
@export var name_key: String = ""
@export var weapon_class: Enums.WeaponClass = Enums.WeaponClass.SWORD
## Painted side view of this weapon, drawn standing upright with the grip at
## the BOTTOM EDGE of the image (bows are gripped at their centre instead).
## One texture serves both jobs: the rig draws it in the fist, and shop and
## inventory rows draw it as the item icon. Null falls back to the rig's
## primitive drawing and the shared per-class glyph (charter §27).
@export var sprite: Texture2D
@export var damage_type: Enums.DamageType = Enums.DamageType.SLASH
@export_range(0, 999) var damage_min: int = 1
@export_range(0, 999) var damage_max: int = 3
## Flat bonus added to the attacker's accuracy score.
@export_range(-50, 50) var accuracy_bonus: int = 0
## Fraction of post-mitigation damage (after resistance AND stance reduction)
## that bypasses the armour pool straight to HP (0-1).
@export_range(0.0, 1.0) var armour_penetration: float = 0.0
## Base critical-hit chance of THIS weapon (session-6 owner design: crits
## vary weapon to weapon — daggers bite often, mauls rarely). The wielder's
## class-matched attribute adds on top (HitCalculator.crit_chance_for).
@export_range(0.0, 0.5) var crit_chance: float = 0.05
## Distance bands this weapon can attack from (inclusive).
@export var range_min: Enums.DistanceBand = Enums.DistanceBand.ADJACENT
@export var range_max: Enums.DistanceBand = Enums.DistanceBand.CLOSE
## Energy cost of a normal attack with this weapon.
@export_range(0, 100) var energy_cost: int = 5
## Shots per combat for ranged weapons (0 = melee/unlimited). Owner design:
## bows carry 4 arrows; when they run dry the sidearm takes over.
@export_range(0, 20) var ammo: int = 0
## Backup melee weapon auto-carried alongside this one (bows link a knife).
## Fighters START the fight on the sidearm and must switch to shoot.
@export var sidearm: WeaponData


func is_ranged() -> bool:
	return ammo > 0

@export_group("Signature")
## Legendary/Mythic signature effect (V2 §52). Read at combat start from the
## equipped kit — never stored on the character, so no save version changes.
@export var unique_effect: Enums.UniqueEffect = Enums.UniqueEffect.NONE

@export_group("Progression")
@export_range(1, 8) var tier: int = 1
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
## Unique rewards (champion drops) set this false — never sold in shops.
@export var shop_available: bool = true
## Base gold value (EconomyCalculator derives buy/sell prices from this).
@export_range(0, 100000) var value: int = 10
@export_range(1, 60) var required_level: int = 1
@export_range(0, 200) var required_strength: int = 0
@export_range(0, 200) var required_agility: int = 0
@export_range(0, 200) var required_arcana: int = 0


func average_damage() -> float:
	return (damage_min + damage_max) / 2.0


func can_attack_from(band: Enums.DistanceBand) -> bool:
	return band >= range_min and band <= range_max
