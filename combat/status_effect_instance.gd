class_name StatusEffectInstance
extends RefCounted
## Runtime state of one status effect on one combatant.
## Data/state split (charter §6): definition in StatusEffectData, never here.

var data: StatusEffectData = null
var stacks: int = 1
var remaining_rounds: int = 1


func _init(effect_data: StatusEffectData) -> void:
	data = effect_data
	stacks = 1
	remaining_rounds = effect_data.duration_rounds
