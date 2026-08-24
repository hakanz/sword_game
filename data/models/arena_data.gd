class_name ArenaData
extends Resource
## Static definition of an arena (charter §21). Environmental hazards and
## region/tier gating expand in the arena-progression phase.

@export var id: StringName
@export var name_key: String = ""
@export_range(1, 60) var min_level: int = 1
@export_range(1, 60) var max_level: int = 8

@export_group("Placeholder Visuals")
## Placeholder palette until real backgrounds exist (charter §27).
@export var sky_color: Color = Color(0.55, 0.42, 0.35)
@export var ground_color: Color = Color(0.76, 0.6, 0.38)
@export var wall_color: Color = Color(0.42, 0.3, 0.24)
