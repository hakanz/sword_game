class_name ProgressionCalculator
## Single home for all attribute -> derived-stat formulas (charter §13.1).
## UI, AI, and tooltips call these — they NEVER recompute stats ad hoc.
## All coefficients are starting values for balancing, not sacred numbers;
## document changes in docs/balancing.md.


static func max_hp(attrs: AttributeBlock, level: int) -> int:
	return 50 + attrs.vitality * 6 + level * 4


static func max_energy(attrs: AttributeBlock, level: int) -> int:
	return 40 + attrs.stamina * 4 + level * 2


static func max_mana(attrs: AttributeBlock, _level: int) -> int:
	return 10 + attrs.arcana * 5


## Base accuracy score before weapon/skill bonuses (HitCalculator adds those).
static func attack_rating(attrs: AttributeBlock) -> int:
	return attrs.attack * 2 + attrs.agility


## Base avoidance score before evasion/stance (HitCalculator adds those).
static func defence_rating(attrs: AttributeBlock) -> int:
	return attrs.defence * 2


## `equipment_evasion_mod` is the summed evasion modifier of worn armour.
static func evasion(attrs: AttributeBlock, equipment_evasion_mod: int = 0) -> int:
	return attrs.agility + equipment_evasion_mod


static func initiative(attrs: AttributeBlock) -> int:
	return attrs.agility * 2 + attrs.attack


## Flat damage added to a weapon roll from attributes. Weights differ per
## weapon class so different builds favor different weapons (charter §15).
static func attribute_damage_bonus(attrs: AttributeBlock, weapon_class: Enums.WeaponClass) -> int:
	match weapon_class:
		Enums.WeaponClass.SWORD:
			return roundi(attrs.strength * 0.3 + attrs.agility * 0.2)
		Enums.WeaponClass.AXE, Enums.WeaponClass.BLUNT:
			return roundi(attrs.strength * 0.5)
		Enums.WeaponClass.SPEAR:
			return roundi(attrs.strength * 0.35 + attrs.agility * 0.15)
		Enums.WeaponClass.RANGED:
			return roundi(attrs.agility * 0.4)
		Enums.WeaponClass.MAGICAL:
			return roundi(attrs.arcana * 0.5)
		_:
			return roundi(attrs.strength * 0.25)
