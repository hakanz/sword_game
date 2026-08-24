class_name OpponentGenerator
## Procedural NORMAL opponents (charter §20: allowed for normal duels;
## champions are always handcrafted). Generates level-appropriate fighters
## from the starter enemy archetype: scaled attributes, varied name, varied
## personality. Uses RngService — generation is seed-reproducible.
##
## Name pools are original inventions; checked by eye against known gladiator
## games (charter §0.4) — no collisions.

const BASE: CharacterData = preload("res://data/characters/enemy_vosk.tres")

const PERSONALITY_POOL: Array[AIPersonality] = [
	preload("res://data/characters/personalities/aggressive.tres"),
	preload("res://data/characters/personalities/defensive.tres"),
	preload("res://data/characters/personalities/cautious.tres"),
]

const FIRST_NAMES: PackedStringArray = [
	"Vosk", "Harga", "Tullo", "Brakka", "Snegg", "Morda", "Ulfen", "Kresh",
	"Dorba", "Yagg", "Petto", "Rulf",
]
const EPITHETS: PackedStringArray = [
	"the Gravel-Chewer", "Ironjaw", "the Unwashed", "Two-Teeth", "the Howler",
	"Mudfist", "the Patient", "Halfboot", "the Wobbly", "Bricktooth",
	"the Modest", "Sandbiter",
]

## Attribute growth weights for the brute archetype (more archetypes arrive
## with the arena-progression phase).
const GROWTH_WEIGHTS: Dictionary = {
	"strength": 0.22, "agility": 0.16, "attack": 0.20,
	"defence": 0.14, "vitality": 0.16, "stamina": 0.12,
}


static func generate(player_level: int) -> CharacterData:
	var level: int = maxi(1, player_level + RngService.randi_range(-1, 1))
	var data: CharacterData = BASE.duplicate(true)
	data.id = &"character.generated"
	data.is_name_localization_key = false
	data.name_text = "%s %s" % [RngService.pick(FIRST_NAMES), RngService.pick(EPITHETS)]
	data.level = level
	data.personality = RngService.pick(PERSONALITY_POOL)

	# Distribute the same points a leveling player would earn (3 per level).
	var points: int = (level - 1) * 3
	for _i in points:
		var roll: float = RngService.randf()
		var cumulative: float = 0.0
		for attr_name: String in GROWTH_WEIGHTS.keys():
			cumulative += GROWTH_WEIGHTS[attr_name]
			if roll <= cumulative:
				data.attributes.set(attr_name, int(data.attributes.get(attr_name)) + 1)
				break

	_assign_gear(data, level)
	_assign_skills(data, level)

	# Slight cosmetic variation so opponents don't look identical.
	var hue_shift: float = RngService.randf_range(-0.04, 0.04)
	data.body_color = Color.from_hsv(
			wrapf(data.body_color.h + hue_shift, 0.0, 1.0),
			data.body_color.s, data.body_color.v)
	return data


## Enemies draw from the same item catalog as the player, capped by tier so
## gear power tracks level (T1 at 1-4, T2 at 5-8, T3 at 9+ ...).
static func _assign_gear(data: CharacterData, level: int) -> void:
	var max_tier: int = 1 + (level - 1) / 4
	# shop_available filter keeps champion-unique rewards out of random hands.
	var weapon_pool: Array[WeaponData] = ItemDB.all_weapons().filter(
			func(w: WeaponData) -> bool: return w.tier <= max_tier and w.shop_available)
	if not weapon_pool.is_empty():
		data.weapon = RngService.pick(weapon_pool)

	var pieces: Array[ArmourData] = []
	_maybe_add_piece(pieces, Enums.EquipSlot.CHEST, 1.0, max_tier)
	_maybe_add_piece(pieces, Enums.EquipSlot.HELMET, 0.7, max_tier)
	_maybe_add_piece(pieces, Enums.EquipSlot.LEGS, 0.5, max_tier)
	_maybe_add_piece(pieces, Enums.EquipSlot.BOOTS, 0.3, max_tier)
	data.armour_pieces = pieces


## From level 3 up, enemies bring 1-2 skills their weapon can actually use —
## the same catalog the player learns from.
static func _assign_skills(data: CharacterData, level: int) -> void:
	if level < 3:
		return
	var pool: Array[SkillData] = ItemDB.all_skills().filter(
			func(s: SkillData) -> bool:
				return s.required_level <= level and s.usable_with(data.weapon.weapon_class))
	var count: int = mini(RngService.randi_range(1, 2), pool.size())
	var chosen: Array[SkillData] = []
	for _i in count:
		var pick: SkillData = RngService.pick(pool)
		if not chosen.has(pick):
			chosen.append(pick)
	data.skills = chosen


static func _maybe_add_piece(
		pieces: Array[ArmourData], slot: Enums.EquipSlot,
		probability: float, max_tier: int) -> void:
	if not RngService.chance(probability):
		return
	var pool: Array[ArmourData] = ItemDB.all_armour().filter(
			func(a: ArmourData) -> bool:
				return a.slot == slot and a.tier <= max_tier and a.shop_available)
	if not pool.is_empty():
		pieces.append(RngService.pick(pool))
