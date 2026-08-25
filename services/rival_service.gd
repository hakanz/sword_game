class_name RivalService
## Recurring named opponents (amendment V2 §55). Each arena region fields ONE
## rival who turns up in ordinary duels and remembers how the last meeting
## went — the mirror of the player's own session-6 weapon memory and battle
## fatigue, pointed back at them.
##
## The rivalry is a single number per rival: the player's NET wins. Ahead of
## the player, a rival arrives better armed and a level meaner; behind, they
## turn up with the same blade and one less piece of armour — a setback the
## player can SEE on the sand, not a hidden stat nudge.
##
## Boundaries: builds a CharacterData and reads/writes two small profile
## dictionaries. It never touches combat rules, and it always duplicates the
## template — a rival resource must never accumulate state between fights.

## How often a normal duel in a region fields its rival, once the player has
## fought there at all. Rolled through RngService, so a seeded run repeats.
const APPEARANCE_CHANCE: float = 0.28
## Victories needed in total before rivals start showing up — the debut arc
## belongs to the player alone.
const FIRST_APPEARANCE_AFTER_VICTORIES: int = 2
## How far ahead/behind the record can push a rival's gear and level.
const MOMENTUM_CAP: int = 2


## Net wins the PLAYER holds over `rival_id` (negative = the rival is ahead).
static func score(profile: PlayerProfile, rival_id: StringName) -> int:
	if profile == null:
		return 0
	return int(profile.rival_score.get(rival_id, 0))


## How far the RIVAL is ahead, clamped: +1/+2 = winning, -1/-2 = beaten down.
static func momentum(profile: PlayerProfile, rival_id: StringName) -> int:
	return clampi(-score(profile, rival_id), -MOMENTUM_CAP, MOMENTUM_CAP)


## Should this duel be against the region's rival? Pure decision inputs, one
## RNG draw — the caller owns the "not twice in a row" rule.
static func should_appear(profile: PlayerProfile, arena: ArenaData) -> bool:
	if profile == null or arena == null or arena.rival == null:
		return false
	if profile.victories < FIRST_APPEARANCE_AFTER_VICTORIES:
		return false
	return RngService.chance(APPEARANCE_CHANCE)


## Builds this fight's version of the rival: levelled to the player, armed by
## the rivalry record, carrying the weapon they were last seen with.
static func build(profile: PlayerProfile, arena: ArenaData) -> CharacterData:
	if arena == null or arena.rival == null:
		return null
	var data: CharacterData = arena.rival.duplicate(true)
	var lead: int = momentum(profile, data.id)

	data.level = clampi(profile.level + lead, arena.min_level, arena.max_level)

	var remembered: WeaponData = _remembered_weapon(profile, data.id)
	if remembered != null:
		data.weapon = remembered
	if lead > 0:
		# They have been winning: same fighting style, better steel.
		data.weapon = _upgrade_weapon(data.weapon, lead)
	elif lead < 0 and data.armour_pieces.size() > 0:
		# Beaten last time: still nursing it, and short a piece of kit.
		data.armour_pieces = data.armour_pieces.slice(0, data.armour_pieces.size() - 1)
	return data


## Records the outcome of a fight against `rival_id` and what they wielded.
## Called once per fight from the reward pipeline.
static func record_result(
		profile: PlayerProfile, rival_id: StringName,
		player_won: bool, rival_weapon_id: StringName) -> void:
	if profile == null or rival_id == &"":
		return
	profile.rival_score[rival_id] = score(profile, rival_id) + (1 if player_won else -1)
	if rival_weapon_id != &"":
		profile.rival_weapon[rival_id] = rival_weapon_id


## Localization key for the standings line shown after a rival fight.
static func standing_key(profile: PlayerProfile, rival_id: StringName) -> String:
	var net: int = score(profile, rival_id)
	if net > 0:
		return "rival.standing_ahead"
	if net < 0:
		return "rival.standing_behind"
	return "rival.standing_even"


static func _remembered_weapon(profile: PlayerProfile, rival_id: StringName) -> WeaponData:
	if profile == null:
		return null
	var id: StringName = profile.rival_weapon.get(rival_id, &"")
	if id == &"":
		return null
	var weapon: WeaponData = ItemDB.weapon(id)
	# ItemDB falls back to the first registered weapon for unknown ids; an
	# id that no longer exists must not silently arm a rival with a shiv.
	return weapon if weapon != null and weapon.id == id else null


## The next weapon up in the SAME class, so a rival never changes fighting
## style — they just bring something nastier.
static func _upgrade_weapon(current: WeaponData, steps: int) -> WeaponData:
	var best: WeaponData = current
	for _step in steps:
		var target_tier: int = best.tier + 1
		var candidates: Array[WeaponData] = ItemDB.all_weapons().filter(
				func(w: WeaponData) -> bool:
					return w.weapon_class == best.weapon_class and w.tier == target_tier \
							and w.shop_available and w.rarity < Enums.Rarity.LEGENDARY)
		if candidates.is_empty():
			break
		# Deterministic pick (lowest value at that tier): a rivalry should be
		# repeatable in a seeded run, and this never consumes a combat roll.
		candidates.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.value < b.value)
		best = candidates[0]
	return best
