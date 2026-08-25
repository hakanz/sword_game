class_name AffixData
extends Resource
## One modifier that can ride on a weapon or armour piece (charter §16,
## amendment V2 §52). Data only: the affix says WHICH stat it moves and the
## band it moves it within; `ItemAffixes` decides which affixes an item
## carries and what value each one lands on.
##
## Affixes never gate anything and are never stored per character — they are
## derived from the item's own identity, so no save version changes with
## them (see ItemAffixes for the determinism contract).

## Which stat the affix moves. Attribute entries share their names with
## `AttributeBlock` fields on purpose — `ItemAffixes` maps them by name.
enum Stat {
	STRENGTH,
	AGILITY,
	ATTACK,
	DEFENCE,
	VITALITY,
	STAMINA,
	ARCANA,
	CHARISMA,
	## Flat addition to the armour pool.
	ARMOUR,
	## Flat evasion (harder to hit).
	EVASION,
	## Flat accuracy (easier to hit with).
	ACCURACY,
	## Fractional crit chance (0.02 = +2 percentage points).
	CRIT_CHANCE,
	## Fractional armour penetration (0.05 = +5 points of bypass).
	ARMOUR_PENETRATION,
	## Flat damage added to every attack roll.
	DAMAGE,
	## Counts toward the gear mobility that decides move distance.
	MOBILITY,
}

## Which item kinds may roll this affix.
enum Kind {
	ANY,
	WEAPON,
	ARMOUR,
}

## Stable logical id, e.g. &"affix.of_the_bear".
@export var id: StringName
## Localization key for the display name ("of the Bear" / "Ayı Gücü").
@export var name_key: String = ""
@export var stat: Stat = Stat.STRENGTH
@export var value_min: float = 1.0
@export var value_max: float = 3.0
## Relative chance of being picked from the pool (higher = more common).
@export_range(0.1, 100.0) var weight: float = 1.0
## Never appears on items below this rarity — the good modifiers stay rare.
@export var min_rarity: Enums.Rarity = Enums.Rarity.UNCOMMON
@export var applies_to: Kind = Kind.ANY


## True for stats expressed as a fraction (crit chance, armour penetration) —
## they display as percentages and never round to whole numbers.
func is_fractional() -> bool:
	return stat == Stat.CRIT_CHANCE or stat == Stat.ARMOUR_PENETRATION


func can_roll_on(kind: Kind, rarity: Enums.Rarity) -> bool:
	if applies_to != Kind.ANY and applies_to != kind:
		return false
	return rarity >= min_rarity


## Display string for a rolled value, e.g. "+2" or "+3.5%".
func format_value(value: float) -> String:
	if is_fractional():
		return "+%.1f%%" % (value * 100.0)
	return "+%d" % roundi(value)


## Localization key of the stat's own label (shared with the character sheet
## where one exists, so a stat is never named two different ways).
func stat_key() -> String:
	return stat_label_key(stat)


static func stat_label_key(which: Stat) -> String:
	match which:
		Stat.STRENGTH:
			return "attr.strength"
		Stat.AGILITY:
			return "attr.agility"
		Stat.ATTACK:
			return "attr.attack"
		Stat.DEFENCE:
			return "attr.defence"
		Stat.VITALITY:
			return "attr.vitality"
		Stat.STAMINA:
			return "attr.stamina"
		Stat.ARCANA:
			return "attr.arcana"
		Stat.CHARISMA:
			return "attr.charisma"
		Stat.ARMOUR:
			return "stat.armour"
		Stat.EVASION:
			return "stat.evasion"
		Stat.ACCURACY:
			return "stat.accuracy"
		Stat.CRIT_CHANCE:
			return "stat.crit_chance"
		Stat.ARMOUR_PENETRATION:
			return "stat.armour_pen"
		Stat.DAMAGE:
			return "stat.damage"
		_:
			return "stat.mobility"


## The AttributeBlock field this stat maps to, or "" for non-attributes.
static func attribute_field(which: Stat) -> String:
	match which:
		Stat.STRENGTH:
			return "strength"
		Stat.AGILITY:
			return "agility"
		Stat.ATTACK:
			return "attack"
		Stat.DEFENCE:
			return "defence"
		Stat.VITALITY:
			return "vitality"
		Stat.STAMINA:
			return "stamina"
		Stat.ARCANA:
			return "arcana"
		Stat.CHARISMA:
			return "charisma"
		_:
			return ""
