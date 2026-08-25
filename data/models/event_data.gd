class_name EventData
extends Resource
## A between-fights encounter (charter §23): the traveling merchant, the
## injured gladiator, the dice game behind the stables. Data only — the text,
## the options and their outcomes. `EventService` picks and applies them.
##
## Events never touch combat and never gate progression; they are texture and
## small decisions, so a player who ignores them all loses nothing important.

## Stable logical id, e.g. &"event.merchant".
@export var id: StringName
@export var title_key: String = ""
@export var body_key: String = ""
## Relative chance of being drawn from the pool.
@export_range(0.1, 100.0) var weight: float = 1.0
## Never offered below this level — the debut arc stays uncluttered.
@export_range(1, 60) var min_level: int = 1
@export var choices: Array[EventChoiceData] = []


## Choices this profile can actually afford right now.
func available_choices(gold: int) -> Array[EventChoiceData]:
	var offered: Array[EventChoiceData] = []
	for choice in choices:
		if choice != null and gold >= choice.gold_needed():
			offered.append(choice)
	return offered
