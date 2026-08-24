class_name SkillData
extends Resource
## Static definition of an active combat skill (charter §17).
## DATA MODEL ONLY in the combat-prototype phase — combat wiring for skills
## lands in the skill-system phase. Kept minimal deliberately; expand fields
## (branches, cooldowns, status payloads) when that phase begins.

@export var id: StringName
@export var name_key: String = ""
@export var description_key: String = ""
@export_range(0, 100) var energy_cost: int = 0
@export_range(0, 100) var mana_cost: int = 0
## Multiplier applied at the Skill Multiplier step of the damage pipeline.
@export_range(0.0, 10.0) var power_multiplier: float = 1.0
@export_range(-50, 50) var accuracy_mod: int = 0
@export_range(1, 60) var required_level: int = 1
