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
@export var damage_type: Enums.DamageType = Enums.DamageType.SLASH
@export_range(0, 999) var damage_min: int = 1
@export_range(0, 999) var damage_max: int = 3
## Flat bonus added to the attacker's accuracy score.
@export_range(-50, 50) var accuracy_bonus: int = 0
## Fraction of post-resistance damage that bypasses the armour pool (0-1).
@export_range(0.0, 1.0) var armour_penetration: float = 0.0
## Distance bands this weapon can attack from (inclusive).
@export var range_min: Enums.DistanceBand = Enums.DistanceBand.ADJACENT
@export var range_max: Enums.DistanceBand = Enums.DistanceBand.CLOSE
## Energy cost of a normal attack with this weapon.
@export_range(0, 100) var energy_cost: int = 5

@export_group("Progression")
@export_range(1, 8) var tier: int = 1
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
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
