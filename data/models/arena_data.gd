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
## This region's RECURRING opponent (amendment V2 §55): a named fighter the
## player meets again and again in ordinary duels, who remembers how the last
## meeting went. Optional — a region without one simply never fields a rival.
@export var rival: CharacterData

@export_group("Visuals")
## Painted backdrop for this arena, drawn behind the fighters. Null falls
## back to ArenaVisual's primitive sky/stands/wall drawing (charter §27).
@export var backdrop: Texture2D
## Tiling texture for the fighting ground. Null falls back to flat sand.
@export var ground_texture: Texture2D

@export_group("Placeholder Visuals")
## Placeholder palette until real backgrounds exist (charter §27).
@export var sky_color: Color = Color(0.55, 0.42, 0.35)
@export var ground_color: Color = Color(0.76, 0.6, 0.38)
@export var wall_color: Color = Color(0.42, 0.3, 0.24)
