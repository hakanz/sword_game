class_name Enums
## Shared gameplay enums. Data resources and combat systems reference these —
## keep them stable; reordering values breaks saved .tres content.


enum DamageType {
	SLASH,
	PIERCE,
	BLUNT,
	FIRE,
	FROST,
	POISON,
	LIGHTNING,
	ARCANE,
}

enum WeaponClass {
	UNARMED,
	SWORD,
	AXE,
	BLUNT,
	SPEAR,
	RANGED,
	MAGICAL,
}

## Distance between the two fighters, in bands (charter §15).
## Melee acts at ADJACENT/CLOSE; ranged weapons and spells act from farther out.
enum DistanceBand {
	ADJACENT,
	CLOSE,
	MEDIUM,
	LONG,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC,
}

enum ArmourClass {
	LIGHT,
	MEDIUM,
	HEAVY,
}

enum EquipSlot {
	HELMET,
	CHEST,
	SHOULDERS,
	GLOVES,
	BELT,
	LEGS,
	BOOTS,
	MAIN_HAND,
	OFF_HAND,
	SHIELD,
	AMULET,
	RING,
}

## Combat actions available in the current phase. Spells/consumables extend
## this in later phases (charter §15 lists the full target set).
enum ActionType {
	ATTACK,
	DEFEND,
	APPROACH,
	RETREAT,
	REST,
	SKILL,
	SWITCH_WEAPON,
}

enum Stance {
	NEUTRAL,
	DEFENDING,
}


## Localization key for a distance band label.
static func distance_band_key(band: DistanceBand) -> String:
	match band:
		DistanceBand.ADJACENT:
			return "combat.distance.adjacent"
		DistanceBand.CLOSE:
			return "combat.distance.close"
		DistanceBand.MEDIUM:
			return "combat.distance.medium"
		_:
			return "combat.distance.long"
