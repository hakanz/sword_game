class_name CharacterData
extends Resource
## Static definition of a combatant — used for the player, generated enemies,
## and (later) handcrafted champions. Runtime combat state (current HP, energy,
## armour pool, stance) lives in Combatant, never here.

@export var id: StringName
## Display name. For preset content this is a localization key; for
## player-created or procedurally generated fighters it is a raw name.
## Use display_name() — it resolves both cases.
@export var name_text: String = ""
@export var is_name_localization_key: bool = false
@export_range(1, 60) var level: int = 1
@export var attributes: AttributeBlock
@export var weapon: WeaponData
@export var armour_pieces: Array[ArmourData] = []
## Active combat skills this fighter knows.
@export var skills: Array[SkillData] = []
## Null for the player; enemies must have a personality (charter §20:
## AI is never random).
@export var personality: AIPersonality

@export_group("Placeholder Visuals")
## Placeholder-rig tint colors until real art exists (charter §27).
@export var body_color: Color = Color(0.82, 0.62, 0.45)
@export var accent_color: Color = Color(0.35, 0.28, 0.5)


func display_name() -> String:
	if is_name_localization_key:
		return TranslationServer.translate(name_text)
	return name_text


func total_armour() -> int:
	var total: int = 0
	for piece in armour_pieces:
		total += piece.armour
	return total


func total_evasion_mod() -> int:
	var total: int = 0
	for piece in armour_pieces:
		total += piece.evasion_mod
	return total
