class_name PlayerProfile
extends Resource
## The player's persistent progression state (charter §31). Runtime-only —
## persisted as a versioned JSON dictionary by SaveManager (NOT as a serialized
## Resource: loading foreign Resources can execute scripts; JSON cannot).
## Combat consumes this via to_character_data(); combat never mutates it
## directly — ProgressionService applies rewards.

const STARTER: CharacterData = preload("res://data/characters/player_default.tres")

@export var character_name: String = ""
@export_range(1, 200) var level: int = 1
## XP progress within the current level (not lifetime XP).
@export var xp: int = 0
@export var attribute_points: int = 0
@export var skill_points: int = 0
@export var attributes: AttributeBlock
@export var gold: int = 0
@export var fame: int = 0
@export var victories: int = 0
@export var defeats: int = 0
@export var weapon_id: StringName = &"weapon.training_shortsword"
@export var armour_ids: Array[StringName] = []
## Owned but not equipped (charter §16 inventory).
@export var inventory_weapon_ids: Array[StringName] = []
@export var inventory_armour_ids: Array[StringName] = []
## Learned active skills (charter §17).
@export var known_skill_ids: Array[StringName] = []
## Champions this gladiator has toppled (by CharacterData id).
@export var defeated_champion_ids: Array[StringName] = []
## Arena the player currently fights in (charter §21 regions).
@export var selected_arena_id: StringName = &"arena.gravelmaw"
## Arenas whose tournament has been won — unlocks the next region.
@export var completed_tournament_arena_ids: Array[StringName] = []
@export var body_color: Color = Color(0.85, 0.64, 0.47)
@export var accent_color: Color = Color(0.22, 0.36, 0.6)

## Session-6 owner design (ranged flow): a bow-wielder must SWITCH to the
## bow the first time — but after a WON fight, whatever weapon was in hand
## at the end comes back selected. A LOSS resets this to the sidearm.
@export var prefers_main_weapon: bool = false
## Set on defeat: the next fight starts with drained energy, then clears.
@export var battle_fatigue: bool = false


static func create_default() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.character_name = TranslationServer.translate("character.default_name")
	profile.attributes = STARTER.attributes.duplicate_block()
	profile.weapon_id = STARTER.weapon.id
	for piece in STARTER.armour_pieces:
		profile.armour_ids.append(piece.id)
	profile.body_color = STARTER.body_color
	profile.accent_color = STARTER.accent_color
	return profile


## Builds the runtime combat definition for this profile.
func to_character_data() -> CharacterData:
	var data := CharacterData.new()
	data.id = &"character.player"
	data.name_text = character_name
	data.is_name_localization_key = false
	data.level = level
	data.attributes = attributes.duplicate_block()
	data.weapon = ItemDB.weapon(weapon_id)
	var pieces: Array[ArmourData] = []
	for armour_id in armour_ids:
		var piece: ArmourData = ItemDB.armour_piece(armour_id)
		if piece != null:
			pieces.append(piece)
	data.armour_pieces = pieces
	var skill_list: Array[SkillData] = []
	for skill_id in known_skill_ids:
		var skill: SkillData = ItemDB.skill(skill_id)
		if skill != null:
			skill_list.append(skill)
	data.skills = skill_list
	data.personality = null
	data.body_color = body_color
	data.accent_color = accent_color
	return data


func to_dict() -> Dictionary:
	return {
		"character_name": character_name,
		"level": level,
		"xp": xp,
		"attribute_points": attribute_points,
		"skill_points": skill_points,
		"attributes": {
			"strength": attributes.strength,
			"agility": attributes.agility,
			"attack": attributes.attack,
			"defence": attributes.defence,
			"vitality": attributes.vitality,
			"stamina": attributes.stamina,
			"arcana": attributes.arcana,
			"charisma": attributes.charisma,
		},
		"gold": gold,
		"fame": fame,
		"victories": victories,
		"defeats": defeats,
		"weapon_id": String(weapon_id),
		"armour_ids": armour_ids.map(func(id: StringName) -> String: return String(id)),
		"inventory_weapon_ids": inventory_weapon_ids.map(
				func(id: StringName) -> String: return String(id)),
		"inventory_armour_ids": inventory_armour_ids.map(
				func(id: StringName) -> String: return String(id)),
		"known_skill_ids": known_skill_ids.map(
				func(id: StringName) -> String: return String(id)),
		"defeated_champion_ids": defeated_champion_ids.map(
				func(id: StringName) -> String: return String(id)),
		"selected_arena_id": String(selected_arena_id),
		"completed_tournament_arena_ids": completed_tournament_arena_ids.map(
				func(id: StringName) -> String: return String(id)),
		"body_color": body_color.to_html(),
		"accent_color": accent_color.to_html(),
		"prefers_main_weapon": prefers_main_weapon,
		"battle_fatigue": battle_fatigue,
	}


## Missing fields fall back to sane defaults — malformed saves degrade
## gracefully instead of crashing (details logged by SaveManager).
static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := create_default()
	profile.character_name = str(data.get("character_name", profile.character_name))
	profile.level = int(data.get("level", 1))
	profile.xp = int(data.get("xp", 0))
	profile.attribute_points = int(data.get("attribute_points", 0))
	profile.skill_points = int(data.get("skill_points", 0))
	var attrs: Dictionary = data.get("attributes", {})
	profile.attributes.strength = int(attrs.get("strength", profile.attributes.strength))
	profile.attributes.agility = int(attrs.get("agility", profile.attributes.agility))
	profile.attributes.attack = int(attrs.get("attack", profile.attributes.attack))
	profile.attributes.defence = int(attrs.get("defence", profile.attributes.defence))
	profile.attributes.vitality = int(attrs.get("vitality", profile.attributes.vitality))
	profile.attributes.stamina = int(attrs.get("stamina", profile.attributes.stamina))
	profile.attributes.arcana = int(attrs.get("arcana", profile.attributes.arcana))
	profile.attributes.charisma = int(attrs.get("charisma", profile.attributes.charisma))
	profile.gold = int(data.get("gold", 0))
	profile.fame = int(data.get("fame", 0))
	profile.victories = int(data.get("victories", 0))
	profile.defeats = int(data.get("defeats", 0))
	profile.weapon_id = StringName(str(data.get("weapon_id", String(profile.weapon_id))))
	if data.has("armour_ids"):
		profile.armour_ids.clear()
		for id in data["armour_ids"]:
			profile.armour_ids.append(StringName(str(id)))
	for id in data.get("inventory_weapon_ids", []):
		profile.inventory_weapon_ids.append(StringName(str(id)))
	for id in data.get("inventory_armour_ids", []):
		profile.inventory_armour_ids.append(StringName(str(id)))
	for id in data.get("known_skill_ids", []):
		profile.known_skill_ids.append(StringName(str(id)))
	for id in data.get("defeated_champion_ids", []):
		profile.defeated_champion_ids.append(StringName(str(id)))
	profile.selected_arena_id = StringName(str(
			data.get("selected_arena_id", String(profile.selected_arena_id))))
	for id in data.get("completed_tournament_arena_ids", []):
		profile.completed_tournament_arena_ids.append(StringName(str(id)))
	profile.body_color = Color.from_string(str(data.get("body_color", "")), profile.body_color)
	profile.accent_color = Color.from_string(str(data.get("accent_color", "")), profile.accent_color)
	profile.prefers_main_weapon = bool(data.get("prefers_main_weapon", false))
	profile.battle_fatigue = bool(data.get("battle_fatigue", false))
	return profile
