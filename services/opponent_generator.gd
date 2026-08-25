class_name OpponentGenerator
## Procedural NORMAL opponents (charter §20: allowed for normal duels;
## champions are always handcrafted). Generates level-appropriate fighters
## from the starter enemy archetype: scaled attributes, varied name, varied
## personality. Uses RngService — generation is seed-reproducible.
##
## Name pools are original inventions; checked by eye against known gladiator
## games (charter §0.4) — no collisions.

const BASE: CharacterData = preload("res://data/characters/enemy_vosk.tres")

## Every fighter in the game grows on the same budget the player does.
const POINTS_PER_LEVEL: int = 3

const AGGRESSIVE: AIPersonality = preload("res://data/characters/personalities/aggressive.tres")
const DEFENSIVE: AIPersonality = preload("res://data/characters/personalities/defensive.tres")
const CAUTIOUS: AIPersonality = preload("res://data/characters/personalities/cautious.tres")
const BERSERKER: AIPersonality = preload("res://data/characters/personalities/berserker.tres")
const OPPORTUNIST: AIPersonality = preload("res://data/characters/personalities/opportunist.tres")

## Temperaments that FIT each Weapon Mastery Archetype (V2 §50/§53.2): a
## generated marksman must not roll `aggressive` and charge down the sand.
## Keyed by the archetype label ProgressionCalculator derives from the kit,
## so the pairing follows the gear the generator actually rolled.
const PERSONALITY_BY_ARCHETYPE: Dictionary = {
	&"archetype.breaker": [AGGRESSIVE, BERSERKER],
	&"archetype.duelist": [AGGRESSIVE, OPPORTUNIST, DEFENSIVE],
	&"archetype.skirmisher": [CAUTIOUS, OPPORTUNIST],
	# Ranged temperaments never CHARGE, but one of them should still take the
	# finishing shot — two purely passive heads made every archer identical.
	&"archetype.marksman": [CAUTIOUS, DEFENSIVE, OPPORTUNIST],
	&"archetype.battlemage": [CAUTIOUS, DEFENSIVE, OPPORTUNIST],
	&"archetype.guardian": [DEFENSIVE],
	&"archetype.brawler": [AGGRESSIVE, BERSERKER],
}

const FIRST_NAMES: PackedStringArray = [
	"Vosk", "Harga", "Tullo", "Brakka", "Snegg", "Morda", "Ulfen", "Kresh",
	"Dorba", "Yagg", "Petto", "Rulf",
]
const EPITHETS: PackedStringArray = [
	"the Gravel-Chewer", "Ironjaw", "the Unwashed", "Two-Teeth", "the Howler",
	"Mudfist", "the Patient", "Halfboot", "the Wobbly", "Bricktooth",
	"the Modest", "Sandbiter",
]

## Build archetypes a generated fighter can grow into (phase 16). Each one
## says where its level-up points go AND which weapon classes it will pick up,
## so the pit stops being an endless queue of identical brutes — and staves
## finally reach an opponent's hands.
##
## `weight` is how often the archetype is rolled; `weapons` gates gear so the
## build and the kit agree (a mage without a staff is just a bad brute).
const GROWTH_PROFILES: Array[Dictionary] = [
	{
		"id": &"brute", "weight": 3.0, "min_level": 1,
		"growth": {"strength": 0.24, "agility": 0.14, "attack": 0.20,
				"defence": 0.14, "vitality": 0.16, "stamina": 0.12},
		"weapons": [Enums.WeaponClass.AXE, Enums.WeaponClass.BLUNT, Enums.WeaponClass.SWORD],
	},
	{
		"id": &"duelist", "weight": 2.5, "min_level": 1,
		"growth": {"strength": 0.16, "agility": 0.24, "attack": 0.22,
				"defence": 0.14, "vitality": 0.12, "stamina": 0.12},
		"weapons": [Enums.WeaponClass.SWORD, Enums.WeaponClass.SPEAR],
	},
	{
		"id": &"skirmisher", "weight": 2.0, "min_level": 3,
		"growth": {"strength": 0.16, "agility": 0.26, "attack": 0.20,
				"defence": 0.12, "vitality": 0.12, "stamina": 0.14},
		"weapons": [Enums.WeaponClass.SPEAR, Enums.WeaponClass.RANGED],
	},
	{
		"id": &"marksman", "weight": 1.5, "min_level": 6,
		"growth": {"strength": 0.10, "agility": 0.30, "attack": 0.24,
				"defence": 0.10, "vitality": 0.12, "stamina": 0.14},
		"weapons": [Enums.WeaponClass.RANGED],
	},
	{
		"id": &"mage", "weight": 1.0, "min_level": 8,
		"growth": {"arcana": 0.34, "agility": 0.14, "attack": 0.14,
				"defence": 0.12, "vitality": 0.14, "stamina": 0.12},
		"weapons": [Enums.WeaponClass.MAGICAL],
	},
]


static func generate(player_level: int) -> CharacterData:
	return generate_at_level(maxi(1, player_level + RngService.randi_range(-1, 1)))


## Opponent for a normal duel in `arena`: near the player's level but always
## inside the region's band (charter §21 level gating).
static func generate_for_arena(player_level: int, arena: ArenaData) -> CharacterData:
	var level: int = clampi(player_level + RngService.randi_range(-1, 1),
			arena.min_level, arena.max_level)
	return generate_at_level(level)


## `elite` fighters (tournament brackets) fight at the SAME level but come
## properly kitted: one gear tier higher, armour on every likely slot, and
## a full skill loadout — skilled, well-equipped rivals, not stat piles.
static func generate_at_level(level: int, elite: bool = false) -> CharacterData:
	var data: CharacterData = BASE.duplicate(true)
	data.id = &"character.generated"
	data.is_name_localization_key = false
	data.name_text = "%s %s" % [RngService.pick(FIRST_NAMES), RngService.pick(EPITHETS)]
	data.level = level

	# Which kind of fighter is this? Chosen first, because it decides both
	# where the level-up points go and what they can hold.
	var profile: Dictionary = _pick_profile(level)
	var growth: Dictionary = profile["growth"]

	# Distribute the same points a leveling player would earn (3 per level).
	distribute_points(data.attributes, (level - 1) * POINTS_PER_LEVEL, growth)

	_assign_gear(data, level, elite, profile)
	# Temperament comes AFTER the kit: it is chosen to suit what this fighter
	# is actually holding (V2 §53.2), not rolled blind.
	data.personality = _personality_for(data)
	_assign_skills(data, level, elite)

	# Slight cosmetic variation so opponents don't look identical.
	var hue_shift: float = RngService.randf_range(-0.04, 0.04)
	data.body_color = Color.from_hsv(
			wrapf(data.body_color.h + hue_shift, 0.0, 1.0),
			data.body_color.s, data.body_color.v)
	return data


## Picks a temperament that reads right for the generated build's archetype.
static func _personality_for(data: CharacterData) -> AIPersonality:
	var archetype: StringName = ProgressionCalculator.archetype_of(data)
	var pool: Array = PERSONALITY_BY_ARCHETYPE.get(archetype, [AGGRESSIVE])
	return RngService.pick(pool)


## Spends `points` attribute points into `attrs` along a growth profile's
## weights. Shared so anything level-scaled — generated fighters AND the
## handcrafted rivals `RivalService` levels up — grows on one budget rule.
static func distribute_points(attrs: AttributeBlock, points: int, growth: Dictionary) -> void:
	if attrs == null or points <= 0 or growth.is_empty():
		return
	for _i in points:
		var roll: float = RngService.randf()
		var cumulative: float = 0.0
		for attr_name: String in growth.keys():
			cumulative += growth[attr_name]
			if roll <= cumulative:
				attrs.set(attr_name, int(attrs.get(attr_name)) + 1)
				break


## The growth profile that matches a weapon class, so a handcrafted fighter
## being levelled up grows into the build they already are.
static func growth_for_weapon(weapon_class: Enums.WeaponClass) -> Dictionary:
	for profile: Dictionary in GROWTH_PROFILES:
		var classes: Array = profile.get("weapons", [])
		if classes.has(weapon_class):
			return profile["growth"]
	return GROWTH_PROFILES[0]["growth"]


## Weighted archetype roll, restricted to archetypes that can actually hold
## their own weapon at this level. A mage cannot lift any staff in the catalog
## before level ~8 (`required_arcana`), and rolling one anyway left a fighter
## with mage growth carrying the fallback hatchet — a "mage" that is really a
## worse brute, and one the temperament pairing then reads as a Breaker.
static func _pick_profile(level: int) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for profile: Dictionary in GROWTH_PROFILES:
		if level >= int(profile.get("min_level", 1)):
			eligible.append(profile)
	if eligible.is_empty():
		return GROWTH_PROFILES[0]
	var total: float = 0.0
	for profile: Dictionary in eligible:
		total += float(profile["weight"])
	var ticket: float = RngService.randf() * total
	for profile: Dictionary in eligible:
		ticket -= float(profile["weight"])
		if ticket <= 0.0:
			return profile
	return eligible[0]


## Enemies draw from the same item catalog as the player, capped by tier so
## gear power tracks level (T1 at 1-4, T2 at 5-8, T3 at 9+ ...).
static func _assign_gear(data: CharacterData, level: int, elite: bool = false,
		profile: Dictionary = {}) -> void:
	var max_tier: int = 1 + (level - 1) / 4 + (1 if elite else 0)
	# shop_available filter keeps champion-unique rewards out of random hands;
	# the arcana filter keeps staves off the brute archetype (no ARC growth);
	# the rarity filter keeps LEGENDARY signature gear (V2 §52.3) a player
	# chase item / champion reward instead of random pit-fighter loot.
	var classes: Array = profile.get("weapons", [])
	var weapon_pool: Array[WeaponData] = ItemDB.all_weapons().filter(
			func(w: WeaponData) -> bool:
				if w.tier > max_tier or not w.shop_available:
					return false
				if w.rarity >= Enums.Rarity.LEGENDARY:
					return false
				if not classes.is_empty() and not classes.has(w.weapon_class):
					return false
				# The build must actually be able to lift it — this is what
				# keeps a staff out of a brute's hands now that the arcana
				# blanket ban is gone.
				if data.attributes.strength < w.required_strength:
					return false
				if data.attributes.agility < w.required_agility:
					return false
				return data.attributes.arcana >= w.required_arcana)
	if weapon_pool.is_empty() and not classes.is_empty():
		# Nothing in this archetype's classes is within reach yet. Rather than
		# silently leaving the base weapon (and a build that contradicts its
		# own kit), fall back to anything level-appropriate.
		weapon_pool = ItemDB.all_weapons().filter(
				func(w: WeaponData) -> bool:
					return w.tier <= max_tier and w.shop_available \
							and w.rarity < Enums.Rarity.LEGENDARY \
							and w.required_arcana == 0 and w.required_agility == 0 \
							and data.attributes.strength >= w.required_strength)
	if not weapon_pool.is_empty():
		data.weapon = RngService.pick(weapon_pool)

	var pieces: Array[ArmourData] = []
	# Level-1 pit fighters come as bare as the player does (session-6 owner
	# design: everyone starts armourless) — gear appears from level 2 up.
	if level >= 2 or elite:
		_maybe_add_piece(pieces, Enums.EquipSlot.CHEST, 1.0, max_tier)
		_maybe_add_piece(pieces, Enums.EquipSlot.HELMET, 0.95 if elite else 0.7, max_tier)
		_maybe_add_piece(pieces, Enums.EquipSlot.LEGS, 0.8 if elite else 0.5, max_tier)
		_maybe_add_piece(pieces, Enums.EquipSlot.BOOTS, 0.65 if elite else 0.3, max_tier)
	data.armour_pieces = pieces


## From level 3 up, enemies bring 1-2 skills their weapon can actually use —
## the same catalog the player learns from. Elites always carry a full pair.
static func _assign_skills(data: CharacterData, level: int, elite: bool = false) -> void:
	if level < 3:
		return
	var pool: Array[SkillData] = ItemDB.all_skills().filter(
			func(s: SkillData) -> bool:
				return s.required_level <= level and s.usable_with(data.weapon.weapon_class))
	var count: int = mini(2 if elite else RngService.randi_range(1, 2), pool.size())
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
				return a.slot == slot and a.tier <= max_tier and a.shop_available 						and a.rarity < Enums.Rarity.LEGENDARY)
	if not pool.is_empty():
		pieces.append(RngService.pick(pool))
