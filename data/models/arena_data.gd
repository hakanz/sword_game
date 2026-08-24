class_name ArenaData
extends Resource
## Static definition of an arena (charter §21). Environmental hazards and
## region/tier gating expand in the arena-progression phase.

@export var id: StringName
@export var name_key: String = ""
## Region sequence: order 1 is always unlocked; order N unlocks by completing
## the order N-1 arena's tournament.
@export_range(1, 10) var order: int = 1
@export_range(1, 60) var min_level: int = 1
@export_range(1, 60) var max_level: int = 8
## This arena's handcrafted champion — the tournament's final opponent
## (charter §20/§21).
@export var champion: CharacterData

@export_group("Placeholder Visuals")
## Placeholder palette until real backgrounds exist (charter §27).
@export var sky_color: Color = Color(0.55, 0.42, 0.35)
@export var ground_color: Color = Color(0.76, 0.6, 0.38)
@export var wall_color: Color = Color(0.42, 0.3, 0.24)
