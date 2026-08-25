class_name ItemAffixes
## The one home of itemization depth (charter §16, amendment V2 §52): which
## modifiers an item carries, what they are worth, and what the fighter's
## whole kit adds up to. UI, combat and the AI all read the same numbers from
## here — nothing recomputes an item bonus locally.
##
## DETERMINISM CONTRACT (decision, 2026-08-25). An item's affixes are a pure
## function of the item's own identity — `id` seeds a LOCAL RandomNumberGenerator,
## `rarity` sets the budget, and the affix pool weights do the rest.
##   Reason:       the satchel is a list of item IDs (`inventory_weapon_ids`),
##                 so two copies of a sword are the same entry; per-drop rolls
##                 would need a per-instance save format, a save-version bump
##                 with a lossy migration, and duplicate-aware inventory UI —
##                 V2 §52 explicitly scopes this phase to "no new save version".
##   Consequence:  a Bronze Gladius always carries the same modifiers, so the
##                 player can LEARN the catalog and shop rows can promise what
##                 they show. Editing the affix pool re-derives every item's
##                 modifiers — that is a content change, never a save break.
##   Alternative:  rolled instances per drop (classic ARPG). Rejected for this
##                 phase; revisit only alongside a per-instance item model.
## The local RNG is also what keeps `--combat-seed=N` reproducible: derivation
## must never draw from RngService (AI_GUIDE "Centralized RNG").

## One modifier an item carries, with the value it landed on.
class Roll:
	extends RefCounted
	var affix: AffixData = null
	var value: float = 0.0

	func _init(from: AffixData = null, rolled: float = 0.0) -> void:
		affix = from
		value = rolled

	## "+2 Strength" / "+3.5% Crit Chance", ready for a UI row.
	func label() -> String:
		return "%s %s" % [affix.format_value(value), TranslationServer.translate(affix.stat_key())]


## Everything an equipped kit contributes, summed once.
class Bonuses:
	extends RefCounted
	## AttributeBlock field name -> flat bonus.
	var attributes: Dictionary = {}
	var armour: int = 0
	var evasion: int = 0
	var accuracy: int = 0
	var crit_chance: float = 0.0
	var armour_penetration: float = 0.0
	var damage: int = 0
	var mobility: int = 0
	## Signature effects carried by the kit (V2 §52.3).
	var unique_effects: Array[Enums.UniqueEffect] = []

	func attribute(field: String) -> int:
		return int(attributes.get(field, 0))

	func has(effect: Enums.UniqueEffect) -> bool:
		return unique_effects.has(effect)


## Affix count by rarity (V2 §52.2) — the existing Rarity enum already has
## exactly the six tiers this needs, so no new enum was introduced.
## Legendary/Mythic additionally carry a signature effect (item data).
const BUDGET: Dictionary = {
	Enums.Rarity.COMMON: 0,
	Enums.Rarity.UNCOMMON: 1,
	Enums.Rarity.RARE: 2,
	Enums.Rarity.EPIC: 3,
	Enums.Rarity.LEGENDARY: 3,
	Enums.Rarity.MYTHIC: 4,
}

## Derived affixes are stable for the whole session; deriving them is pure, so
## caching is safe and keeps AI scoring cheap.
static var _cache: Dictionary = {}


static func budget_for(rarity: Enums.Rarity) -> int:
	return int(BUDGET.get(rarity, 0))


## True for the rarities that also carry a signature effect.
static func has_signature(rarity: Enums.Rarity) -> bool:
	return rarity >= Enums.Rarity.LEGENDARY


static func for_weapon(weapon: WeaponData) -> Array[Roll]:
	if weapon == null:
		return []
	return _derive(weapon.id, weapon.rarity, AffixData.Kind.WEAPON)


static func for_armour(piece: ArmourData) -> Array[Roll]:
	if piece == null:
		return []
	return _derive(piece.id, piece.rarity, AffixData.Kind.ARMOUR)


## Everything the fighter's kit adds. The MAIN weapon is what counts: a
## sidearm is an emergency knife, and letting a mid-fight weapon switch
## rewrite max HP or armour would be a nasty surprise (and all sidearms are
## Common, so nothing is lost).
static func kit_bonuses(weapon: WeaponData, armour_pieces: Array[ArmourData]) -> Bonuses:
	var bonuses := Bonuses.new()
	_accumulate(bonuses, for_weapon(weapon))
	if weapon != null and weapon.unique_effect != Enums.UniqueEffect.NONE:
		bonuses.unique_effects.append(weapon.unique_effect)
	for piece in armour_pieces:
		if piece == null:
			continue
		_accumulate(bonuses, for_armour(piece))
		if piece.unique_effect != Enums.UniqueEffect.NONE \
				and not bonuses.unique_effects.has(piece.unique_effect):
			bonuses.unique_effects.append(piece.unique_effect)
	return bonuses


## Convenience for callers that hold a whole character (combat setup, sheet).
static func character_bonuses(character: CharacterData) -> Bonuses:
	if character == null:
		return Bonuses.new()
	return kit_bonuses(character.weapon, character.armour_pieces)


## Base attributes plus the kit's attribute affixes. Returns a COPY — the
## character's own AttributeBlock is progression data and is never mutated
## by equipment.
static func effective_attributes(base: AttributeBlock, bonuses: Bonuses) -> AttributeBlock:
	var block: AttributeBlock = base.duplicate_block()
	if bonuses == null:
		return block
	for field: String in bonuses.attributes:
		block.set(field, int(block.get(field)) + bonuses.attribute(field))
	return block


## Sums a set of rolls into one Bonuses block — the ONE accumulation path
## (combat setup and the shop comparison both come through here).
static func sum(rolls: Array[Roll]) -> Bonuses:
	var bonuses := Bonuses.new()
	_accumulate(bonuses, rolls)
	return bonuses


## Localization key for a signature effect's short name.
static func unique_effect_key(effect: Enums.UniqueEffect) -> String:
	match effect:
		Enums.UniqueEffect.VENOM_MASTERY:
			return "unique.venom_mastery"
		Enums.UniqueEffect.BULWARK_RESERVE:
			return "unique.bulwark_reserve"
		Enums.UniqueEffect.RELENTLESS_EDGE:
			return "unique.relentless_edge"
		Enums.UniqueEffect.ARCANE_ECHO:
			return "unique.arcane_echo"
		_:
			return ""


## Test/tooling hook: drops the derivation cache (content edits at runtime).
static func clear_cache() -> void:
	_cache.clear()


# --- Derivation -------------------------------------------------------------

static func _derive(id: StringName, rarity: Enums.Rarity, kind: AffixData.Kind) -> Array[Roll]:
	var budget: int = budget_for(rarity)
	if budget <= 0 or id == &"":
		return []
	var cache_key: String = "%s|%d|%d" % [id, rarity, kind]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var pool: Array[AffixData] = []
	for affix in ItemDB.all_affixes():
		if affix != null and affix.can_roll_on(kind, rarity):
			pool.append(affix)
	# Sorted by id so the derivation does not depend on registry ORDER —
	# only on which affixes exist.
	pool.sort_custom(func(a: AffixData, b: AffixData) -> bool: return a.id < b.id)

	# LOCAL rng, seeded by the item's own identity: never RngService, so
	# seeded combat replays are untouched by itemization.
	var rng := RandomNumberGenerator.new()
	rng.seed = String(id).hash()
	var rolls: Array[Roll] = []
	for _slot in budget:
		if pool.is_empty():
			break
		var picked: AffixData = _pick_weighted(pool, rng)
		pool.erase(picked)
		rolls.append(Roll.new(picked, _roll_value(picked, rng)))
	_cache[cache_key] = rolls
	return rolls


static func _pick_weighted(pool: Array[AffixData], rng: RandomNumberGenerator) -> AffixData:
	var total: float = 0.0
	for affix in pool:
		total += maxf(affix.weight, 0.01)
	var ticket: float = rng.randf() * total
	for affix in pool:
		ticket -= maxf(affix.weight, 0.01)
		if ticket <= 0.0:
			return affix
	return pool[pool.size() - 1]


static func _roll_value(affix: AffixData, rng: RandomNumberGenerator) -> float:
	var raw: float = affix.value_min + rng.randf() * (affix.value_max - affix.value_min)
	if affix.is_fractional():
		# Quantized to half-percent steps so tooltips stay readable.
		return snappedf(raw, 0.005)
	return float(maxi(roundi(raw), 1))


static func _accumulate(bonuses: Bonuses, rolls: Array[Roll]) -> void:
	for roll in rolls:
		var field: String = AffixData.attribute_field(roll.affix.stat)
		if field != "":
			bonuses.attributes[field] = bonuses.attribute(field) + roundi(roll.value)
			continue
		match roll.affix.stat:
			AffixData.Stat.ARMOUR:
				bonuses.armour += roundi(roll.value)
			AffixData.Stat.EVASION:
				bonuses.evasion += roundi(roll.value)
			AffixData.Stat.ACCURACY:
				bonuses.accuracy += roundi(roll.value)
			AffixData.Stat.CRIT_CHANCE:
				bonuses.crit_chance += roll.value
			AffixData.Stat.ARMOUR_PENETRATION:
				bonuses.armour_penetration += roll.value
			AffixData.Stat.DAMAGE:
				bonuses.damage += roundi(roll.value)
			AffixData.Stat.MOBILITY:
				bonuses.mobility += roundi(roll.value)
