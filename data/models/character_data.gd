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

@export_group("Champion")
## Champions are handcrafted, never procedural (charter §20). Defeating one
## is recorded on the profile under this resource's `id`.
@export var is_champion: bool = false
## Optional localized announcer lines (combat log) — champions only.
@export var intro_key: String = ""
@export var defeat_key: String = ""

@export_group("Boss phases")
## HP fraction at or below which phase two opens (0 = this fighter has no
## phases at all). Amendment V2 §55: a champion should change SHAPE as they
## fall, not just lose numbers.
@export_range(0.0, 1.0) var phase_two_hp: float = 0.0
## Signature moves held back until phase two. They are appended to `skills`
## at runtime — the AI then scores them through the same loop as everything
## else, so a phase change needs no bespoke boss code path.
@export var phase_two_skills: Array[SkillData] = []
## HP fraction at or below which the TEMPERAMENT itself shifts.
@export_range(0.0, 1.0) var phase_three_hp: float = 0.0
## Replaces `personality` from phase three on (data, not a hardcoded branch).
@export var phase_three_personality: AIPersonality
## Announcer lines for the two crossings (localization keys).
@export var phase_two_key: String = ""
@export var phase_three_key: String = ""

@export_group("Visuals")
## Painted head-and-shoulders portrait for named fighters (champions and
## regional rivals). Null simply means no portrait is shown — generated
## opponents never have one (charter §27).
@export var portrait: Texture2D

@export_group("Placeholder Visuals")
## Placeholder-rig tint colors until real art exists (charter §27).
@export var body_color: Color = Color(0.82, 0.62, 0.45)
@export var accent_color: Color = Color(0.35, 0.28, 0.5)


func display_name() -> String:
	if is_name_localization_key:
		return TranslationServer.translate(name_text)
	return name_text


## True when this fighter has any phase behaviour authored at all.
func has_phases() -> bool:
	return phase_two_hp > 0.0 or phase_three_hp > 0.0


## Phase (1..3) for an HP fraction. Pure and data-driven: thresholds live on
## the resource, so a new champion is a content task.
func phase_at(hp_fraction: float) -> int:
	if phase_three_hp > 0.0 and hp_fraction <= phase_three_hp:
		return 3
	if phase_two_hp > 0.0 and hp_fraction <= phase_two_hp:
		return 2
	return 1


## Localization key announced when `phase` opens ("" when there is none).
func phase_key(phase: int) -> String:
	if phase == 3:
		return phase_three_key
	if phase == 2:
		return phase_two_key
	return ""


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


## Armour weight score for the derived combat archetype (V2 §50): light 0,
## medium 1, heavy 2 per worn piece. A number, not a category — the archetype
## rule owns the threshold.
func armour_weight() -> int:
	var total: int = 0
	for piece in armour_pieces:
		total += int(piece.armour_class)
	return total


## True when a shield occupies the shield slot. No shield content exists yet
## (docs/items.md) — this is the hook the Guardian archetype reads.
func has_shield() -> bool:
	for piece in armour_pieces:
		if piece.slot == Enums.EquipSlot.SHIELD:
			return true
	return false


func total_mobility_bonus() -> int:
	var total: int = 0
	for piece in armour_pieces:
		total += piece.mobility_bonus
	return total
