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

@export_group("Temperament shifts")
## Extra aggression as this fighter's OWN health drops — a berserker fights
## harder while bleeding (amendment V2 §53.1). 0 = temperament never shifts.
@export_range(0.0, 2.0) var wounded_fury: float = 0.0
## Extra aggression as the FOE nears death — an opportunist smells the finish
## and stops trading carefully.
@export_range(0.0, 2.0) var killer_instinct: float = 0.0


## Aggression AS OF THIS MOMENT. Personalities differ by their weighted
## INPUTS to one shared scoring formula — CombatAI never forks its scoring
## per personality (V2 §53.1), so a new temperament is a data change.
## Both fractions are 0..1 (current / max HP).
func aggression_now(own_hp_fraction: float, foe_hp_fraction: float) -> float:
	var wounded: float = wounded_fury * (1.0 - clampf(own_hp_fraction, 0.0, 1.0))
	var closing: float = killer_instinct * (1.0 - clampf(foe_hp_fraction, 0.0, 1.0))
	return aggression + wounded + closing
