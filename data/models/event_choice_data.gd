class_name EventChoiceData
extends Resource
## One option the player can take in a between-fights event (charter §23).
##
## Outcomes are DATA, never a script hook: a choice moves gold, fame, XP,
## attribute points, or hands over an item, and may stake gold on a roll.
## `EventService` is the only thing that applies these, so an event can never
## invent an effect the rest of the game does not already understand.
##
## Gambling stakes IN-GAME GOLD ONLY (charter §5 real-money boundary).

## Button label.
@export var label_key: String = ""
## Line shown after taking this choice (or after WINNING a wager).
@export var result_key: String = ""
## Line shown when a wager LOSES. Only used when `wager_gold` > 0.
@export var failure_key: String = ""

@export_group("Rewards and costs")
## Signed: negative takes gold away. Never takes more than the player has.
@export_range(-5000, 5000) var gold_delta: int = 0
@export_range(-100, 100) var fame_delta: int = 0
@export_range(0, 5000) var xp_gain: int = 0
@export_range(0, 5) var attribute_points: int = 0
## Optional gift. Weapons and armour both resolve through ItemDB.
@export var item_id: StringName = &""

@export_group("Wager (in-game gold only)")
## Gold staked on the roll. 0 = this choice is not a gamble.
@export_range(0, 5000) var wager_gold: int = 0
@export_range(0.0, 1.0) var win_chance: float = 0.5
## Winnings multiplier applied to the stake (2.0 = double or nothing).
@export_range(0.0, 10.0) var payout_multiplier: float = 2.0

@export_group("Availability")
## Hidden unless the player can actually pay this much gold.
@export_range(0, 5000) var requires_gold: int = 0


func is_wager() -> bool:
	return wager_gold > 0


## Gold the player must have on hand for this choice to be offered at all.
func gold_needed() -> int:
	return maxi(requires_gold, maxi(wager_gold, -gold_delta))
