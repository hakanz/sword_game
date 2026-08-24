class_name ActionResult
extends RefCounted
## Immutable record of one resolved combat action. The HUD formats log lines
## and floating numbers from this; tests assert on it. Never re-derive combat
## math from UI state.

var actor: Combatant = null
var target: Combatant = null
var action: Enums.ActionType = Enums.ActionType.ATTACK

# Attack fields
var hit: bool = false
var hit_chance: float = 0.0
var mitigation: DamageCalculator.MitigationResult = null
var killed: bool = false

# Rest fields
var energy_restored: int = 0

# Movement fields
var distance_after: Enums.DistanceBand = Enums.DistanceBand.MEDIUM
