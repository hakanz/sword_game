class_name ItemCompare
## Shared "is this better for my build?" formatting for shop and inventory
## rows (charter §16, amendment V2 §52.4). Every number here comes from the
## same calculators combat uses — this file formats, it never computes
## gameplay math of its own (AI_GUIDE "Architecture Rules" #3).
##
## Deltas are always measured against what the gladiator is wearing RIGHT NOW
## in that slot, so the row answers the only question that matters at the
## stall: what changes if I take this?

const GAIN_COLOR := Color(0.55, 0.85, 0.5)
const LOSS_COLOR := Color(0.92, 0.5, 0.45)
const AFFIX_COLOR := Color(0.85, 0.75, 0.45)
const SIGNATURE_COLOR := Color(0.95, 0.6, 0.3)

const RARITY_COLORS: Dictionary = {
	Enums.Rarity.COMMON: Color(0.72, 0.7, 0.72),
	Enums.Rarity.UNCOMMON: Color(0.55, 0.82, 0.5),
	Enums.Rarity.RARE: Color(0.45, 0.68, 0.95),
	Enums.Rarity.EPIC: Color(0.75, 0.55, 0.95),
	Enums.Rarity.LEGENDARY: Color(0.98, 0.7, 0.3),
	Enums.Rarity.MYTHIC: Color(0.98, 0.45, 0.55),
}

## Stat rows in display order — deltas print in this order, not by magnitude,
## so the eye lands in the same place on every row.
const STAT_ORDER: PackedStringArray = [
	"stat.damage", "stat.armour", "stat.crit_chance", "stat.armour_pen",
	"stat.accuracy", "stat.evasion", "stat.mobility",
	"attr.strength", "attr.agility", "attr.attack", "attr.defence",
	"attr.vitality", "attr.stamina", "attr.arcana", "attr.charisma",
]
## Keys printed as percentages.
const PERCENT_KEYS: PackedStringArray = ["stat.crit_chance", "stat.armour_pen"]


static func rarity_color(rarity: Enums.Rarity) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[Enums.Rarity.COMMON])


static func rarity_key(rarity: Enums.Rarity) -> String:
	return "rarity.%s" % String(Enums.Rarity.keys()[rarity]).to_lower()


## "◆ +2 Strength · ◆ +1.5% Crit Chance" — "" for an item with no modifiers.
static func affix_summary(item: Resource, is_weapon: bool) -> String:
	var rolls: Array[ItemAffixes.Roll] = _rolls(item, is_weapon)
	if rolls.is_empty():
		return ""
	var parts: PackedStringArray = []
	for roll in rolls:
		parts.append("◆ %s" % roll.label())
	return "  ".join(parts)


## Signature (Legendary+) effect line, "" when the item has none.
static func signature_text(item: Resource) -> String:
	var effect: Enums.UniqueEffect = item.get("unique_effect")
	if effect == Enums.UniqueEffect.NONE:
		return ""
	var key: String = ItemAffixes.unique_effect_key(effect)
	return "★ %s — %s" % [
		TranslationServer.translate(key),
		TranslationServer.translate("%s.desc" % key),
	]


## Everything this item contributes, keyed by localization key. Includes its
## affixes, so two items of the same base power still compare honestly.
static func stat_map(profile: PlayerProfile, item: Resource, is_weapon: bool) -> Dictionary:
	var map: Dictionary = {}
	if item == null:
		return map
	var bonuses: ItemAffixes.Bonuses = ItemAffixes.sum(_rolls(item, is_weapon))

	if is_weapon:
		var weapon := item as WeaponData
		map["stat.damage"] = weapon.average_damage() + bonuses.damage
		# EFFECTIVE crit for THIS gladiator, weapon + attribute + affixes.
		map["stat.crit_chance"] = HitCalculator.crit_chance_for(
				profile.attributes, weapon, bonuses.crit_chance) * 100.0
		map["stat.armour_pen"] = (weapon.armour_penetration
				+ bonuses.armour_penetration) * 100.0
		map["stat.accuracy"] = float(weapon.accuracy_bonus + bonuses.accuracy)
	else:
		var piece := item as ArmourData
		map["stat.armour"] = float(piece.armour + bonuses.armour)
		map["stat.evasion"] = float(piece.evasion_mod + bonuses.evasion)
		map["stat.mobility"] = float(piece.mobility_bonus + bonuses.mobility)

	for field: String in bonuses.attributes:
		map["attr.%s" % field] = float(bonuses.attribute(field))
	return map


## Non-zero differences between `item` and whatever occupies its slot now.
static func deltas(profile: PlayerProfile, item: Resource, is_weapon: bool) -> Dictionary:
	var current: Resource = equipped_counterpart(profile, item, is_weapon)
	if current == item:
		return {}
	var new_map: Dictionary = stat_map(profile, item, is_weapon)
	var old_map: Dictionary = stat_map(profile, current, is_weapon)
	var result: Dictionary = {}
	for key: String in STAT_ORDER:
		var delta: float = float(new_map.get(key, 0.0)) - float(old_map.get(key, 0.0))
		if absf(delta) >= 0.05:
			result[key] = delta
	return result


## What the gladiator wears in the same slot (null when the slot is empty).
static func equipped_counterpart(
		profile: PlayerProfile, item: Resource, is_weapon: bool) -> Resource:
	if profile == null or item == null:
		return null
	if is_weapon:
		return ItemDB.weapon(profile.weapon_id)
	var slot: Enums.EquipSlot = (item as ArmourData).slot
	for worn_id: StringName in profile.armour_ids:
		var worn: ArmourData = ItemDB.armour_piece(worn_id)
		if worn != null and worn.slot == slot:
			return worn
	return null


## "▲ Damage +3.5  Crit Chance +1.5%" — improvements only, "" when none.
static func gains_text(delta_map: Dictionary) -> String:
	return _format_side(delta_map, true)


## "▼ Armour -2" — regressions only, "" when none.
static func losses_text(delta_map: Dictionary) -> String:
	return _format_side(delta_map, false)


static func _format_side(delta_map: Dictionary, gains: bool) -> String:
	var parts: PackedStringArray = []
	for key: String in STAT_ORDER:
		if not delta_map.has(key):
			continue
		var value: float = float(delta_map[key])
		if (value > 0.0) != gains:
			continue
		parts.append("%s %s" % [TranslationServer.translate(key), _format_value(key, value)])
	if parts.is_empty():
		return ""
	return "%s %s" % ["▲" if gains else "▼", "  ".join(parts)]


static func _format_value(key: String, value: float) -> String:
	if PERCENT_KEYS.has(key):
		return "%+.1f%%" % value
	if absf(value - roundf(value)) < 0.01:
		return "%+d" % roundi(value)
	return "%+.1f" % value


static func _rolls(item: Resource, is_weapon: bool) -> Array[ItemAffixes.Roll]:
	if item == null:
		return []
	return ItemAffixes.for_weapon(item as WeaponData) if is_weapon \
			else ItemAffixes.for_armour(item as ArmourData)
