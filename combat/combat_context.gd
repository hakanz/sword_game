class_name CombatContext
extends RefCounted
## Per-combat positional state. Each fighter stands on their OWN cell of an
## 8-cell arena line — moving is a personal action: the fighter who steps is
## the only one who moves (design directive, session 2). Distance bands are
## derived from cell separation:
##   separation 1 = ADJACENT, 2 = CLOSE, 3 = MEDIUM, 4+ = LONG
## Fighters can never share a cell (approach stops at separation 1).

const CELLS: int = 8

## Current round — inputs the AI's crowd-impatience pressure (long fights
## push both fighters toward offense; precursor of the §19 crowd system).
var round_number: int = 1

var _left: Combatant = null
var _right: Combatant = null


func setup(left: Combatant, right: Combatant, left_cell: int = 2, right_cell: int = 5) -> void:
	_left = left
	_right = right
	_left.cell = left_cell
	_right.cell = right_cell


func separation() -> int:
	return absi(_left.cell - _right.cell)


func band() -> Enums.DistanceBand:
	return (clampi(separation() - 1, Enums.DistanceBand.ADJACENT,
			Enums.DistanceBand.LONG) as Enums.DistanceBand)


func foe_of(actor: Combatant) -> Combatant:
	return _right if actor == _left else _left


## Toward the foe: +1 or -1 along the line.
func direction_to_foe(actor: Combatant) -> int:
	return signi(foe_of(actor).cell - actor.cell)


func can_approach(_actor: Combatant) -> bool:
	return separation() > 1


func can_retreat(actor: Combatant) -> bool:
	var target: int = actor.cell - direction_to_foe(actor)
	return target >= 0 and target < CELLS


## Moves ONLY the actor toward their foe, up to their mobility tier
## (Combatant.move_cells) — always stopping at separation 1 (never sharing
## or crossing the foe's cell).
func approach(actor: Combatant) -> void:
	var steps: int = mini(maxi(actor.move_cells, 1), separation() - 1)
	actor.cell += direction_to_foe(actor) * steps


## Moves ONLY the actor away from their foe, up to their mobility tier,
## clamped by the arena wall (cells 0 / CELLS-1).
func retreat(actor: Combatant) -> void:
	var direction: int = direction_to_foe(actor)
	var target: int = clampi(actor.cell - direction * maxi(actor.move_cells, 1), 0, CELLS - 1)
	actor.cell = target
