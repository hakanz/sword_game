class_name SkillData
extends Resource
## Static definition of an active combat skill (charter §17). Data only —
## execution lives in the combat controller + calculators; the AI and HUD
## share CombatAction's validity rules.

enum Target {
	FOE,
	SELF,
}

@export var id: StringName
@export var name_key: String = ""
@export var description_key: String = ""
## HUD/skill-screen icon (original placeholder SVGs in assets/icons).
@export var icon: Texture2D
@export var target: Target = Target.FOE

@export_group("Costs")
@export_range(0, 100) var energy_cost: int = 0
@export_range(0, 100) var mana_cost: int = 0
@export_range(0, 10) var cooldown_rounds: int = 0

@export_group("Strike (FOE skills)")
## Multiplier applied at the Skill Multiplier step of the damage pipeline.
@export_range(0.0, 10.0) var power_multiplier: float = 1.0
@export_range(-50, 50) var accuracy_mod: int = 0
## Added to the weapon's armour penetration (sum clamped to 1.0).
@export_range(0.0, 1.0) var armour_pen_bonus: float = 0.0
## Extends the weapon's maximum range by this many distance bands.
@export_range(0, 3) var range_extend: int = 0

@export_group("Status")
## Applied to the target on hit (FOE) or to self (SELF buffs).
@export var applies_status: StatusEffectData

@export_group("Requirements")
@export_range(1, 60) var required_level: int = 1
## Skill points needed to learn (session-6 owner design: every skill has its
## own price — stronger arts cost more AND gate on level).
@export_range(1, 5) var point_cost: int = 1
## Empty = usable with any weapon.
@export var allowed_weapon_classes: Array[Enums.WeaponClass] = []


func usable_with(weapon_class: Enums.WeaponClass) -> bool:
	return allowed_weapon_classes.is_empty() or allowed_weapon_classes.has(weapon_class)
