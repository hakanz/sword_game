class_name CombatFixtures
## Shared factories for combat unit tests. Combatant is a Node — callers MUST
## free() what they create (see helpers' docs) or the headless run leaks.


static func make_attributes(
		strength: int = 8, agility: int = 8, attack: int = 8, defence: int = 7,
		vitality: int = 9, stamina: int = 8, arcana: int = 3, charisma: int = 5) -> AttributeBlock:
	var attrs := AttributeBlock.new()
	attrs.strength = strength
	attrs.agility = agility
	attrs.attack = attack
	attrs.defence = defence
	attrs.vitality = vitality
	attrs.stamina = stamina
	attrs.arcana = arcana
	attrs.charisma = charisma
	return attrs


static func make_weapon(
		damage_min: int = 6, damage_max: int = 10, accuracy_bonus: int = 2,
		armour_penetration: float = 0.0,
		range_min: Enums.DistanceBand = Enums.DistanceBand.ADJACENT,
		range_max: Enums.DistanceBand = Enums.DistanceBand.CLOSE,
		energy_cost: int = 5,
		weapon_class: Enums.WeaponClass = Enums.WeaponClass.SWORD) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = &"weapon.test"
	weapon.damage_min = damage_min
	weapon.damage_max = damage_max
	weapon.accuracy_bonus = accuracy_bonus
	weapon.armour_penetration = armour_penetration
	weapon.range_min = range_min
	weapon.range_max = range_max
	weapon.energy_cost = energy_cost
	weapon.weapon_class = weapon_class
	return weapon


static func make_character(
		attrs: AttributeBlock = null, weapon: WeaponData = null,
		personality: AIPersonality = null, level: int = 1) -> CharacterData:
	var character := CharacterData.new()
	character.id = &"character.test"
	character.name_text = "Test Fighter"
	character.level = level
	character.attributes = attrs if attrs != null else make_attributes()
	character.weapon = weapon if weapon != null else make_weapon()
	character.personality = personality
	return character


## Caller owns the returned node — call .free() when done.
static func make_combatant(
		character: CharacterData = null, player_controlled: bool = false) -> Combatant:
	var combatant := Combatant.new()
	combatant.setup(
			character if character != null else make_character(),
			player_controlled, false)
	return combatant
