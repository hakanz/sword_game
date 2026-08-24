class_name AIPersonality
extends Resource
## AI decision weights (charter §20). Personalities modify utility scores so
## identical gear still fights differently. Values are multipliers around 1.0.

@export var id: StringName
## Weight on dealing damage / closing distance.
@export_range(0.0, 3.0) var aggression: float = 1.0
## Weight on defending / retreating when hurt.
@export_range(0.0, 3.0) var caution: float = 1.0
## Weight on conserving/restoring energy before acting.
@export_range(0.0, 3.0) var resource_care: float = 1.0
