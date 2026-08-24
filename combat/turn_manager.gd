class_name TurnManager
extends RefCounted
## Turn/round sequencing (charter §11). Pure logic, no scene access —
## the CombatController owns presentation and event emission.
## Order: the player-controlled fighter ALWAYS opens the fight (owner design,
## session 5 — the first move belongs to the hero); everyone else follows by
## initiative descending, ties broken by a seeded random roll. AI-vs-AI runs
## (smoke test, §35 simulator) have no player flag, so pure initiative rules.

## Priority boost that puts a player-controlled fighter ahead of any
## initiative value (initiative*1000 + tiebreak tops out well below this).
const PLAYER_FIRST_KEY: int = 100_000_000

var round_number: int = 0

var _order: Array[Combatant] = []
var _index: int = -1
var _round_just_started: bool = false


func setup(combatants: Array[Combatant]) -> void:
	assert(combatants.size() >= 2, "TurnManager needs at least two combatants")
	var keyed: Array[Dictionary] = []
	for combatant in combatants:
		keyed.append({
			"combatant": combatant,
			# Initiative dominates; the random component only breaks exact ties.
			"key": (PLAYER_FIRST_KEY if combatant.is_player_controlled else 0)
					+ combatant.initiative_value * 1000 + RngService.randi_range(0, 999),
		})
	keyed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["key"] > b["key"])
	_order.clear()
	for entry in keyed:
		_order.append(entry["combatant"])
	_index = -1
	round_number = 0


## Advances to the next living combatant and returns it.
## After calling, is_round_start() reports whether a new round began.
func advance() -> Combatant:
	_round_just_started = false
	for _attempt in _order.size():
		_index += 1
		if _index >= _order.size():
			_index = 0
		if _index == 0:
			round_number += 1
			_round_just_started = true
		var combatant: Combatant = _order[_index]
		if combatant.is_alive():
			return combatant
	assert(false, "TurnManager.advance(): no living combatants")
	return null


func is_round_start() -> bool:
	return _round_just_started


func current() -> Combatant:
	if _index < 0 or _index >= _order.size():
		return null
	return _order[_index]


func turn_order() -> Array[Combatant]:
	return _order.duplicate()
