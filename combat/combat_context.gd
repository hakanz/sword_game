class_name CombatContext
extends RefCounted
## Shared per-combat situational state for a 1v1 duel: the distance band
## between the two fighters. Multi-combatant support (if ever needed) would
## generalize this to positions — documented decision in docs/combat.md.

var distance: Enums.DistanceBand = Enums.DistanceBand.MEDIUM


func approach() -> void:
	distance = (maxi(distance - 1, Enums.DistanceBand.ADJACENT) as Enums.DistanceBand)


func retreat() -> void:
	distance = (mini(distance + 1, Enums.DistanceBand.LONG) as Enums.DistanceBand)


func can_approach() -> bool:
	return distance > Enums.DistanceBand.ADJACENT


func can_retreat() -> bool:
	return distance < Enums.DistanceBand.LONG
