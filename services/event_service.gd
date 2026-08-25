class_name EventService
## Between-fights encounters (charter §23). Picks an event the player is
## eligible for, and applies exactly one chosen outcome to the profile.
##
## Boundaries: the ONLY place event outcomes are applied, so an event can
## never do something the rest of the game does not already understand (it
## moves gold, fame, XP, attribute points, or hands over a catalogued item).
## Wagers stake IN-GAME GOLD ONLY — charter §5's real-money boundary is not
## negotiable, and there is no path here that spends anything else.
##
## Randomness goes through RngService like all gameplay randomness, so a
## seeded run replays its encounters too.

## Chance that leaving the arena runs into something on the way home.
const ENCOUNTER_CHANCE: float = 0.35
## Encounters start once the debut arc is over (the first fights belong to
## the fight itself).
const FIRST_ENCOUNTER_AFTER_VICTORIES: int = 2


## What actually happened, for the screen that has to say it out loud.
class Outcome:
	extends RefCounted
	## Line to show. Already resolved for wagers (win or loss text).
	var text_key: String = ""
	var gold_delta: int = 0
	var fame_delta: int = 0
	var xp_gain: int = 0
	var attribute_points: int = 0
	var item_id: StringName = &""
	## True when this choice was a wager, and whether it came in.
	var wagered: bool = false
	var wager_won: bool = false


## Does an encounter happen at all? One RNG draw, called on the way to town.
static func should_occur(profile: PlayerProfile) -> bool:
	if profile == null or profile.victories < FIRST_ENCOUNTER_AFTER_VICTORIES:
		return false
	if _eligible(profile, &"").is_empty():
		return false
	return RngService.chance(ENCOUNTER_CHANCE)


## Weighted pick from the events this profile qualifies for, avoiding an
## immediate repeat of `exclude_id`. Returns null when nothing fits.
static func pick(profile: PlayerProfile, exclude_id: StringName = &"") -> EventData:
	var pool: Array[EventData] = _eligible(profile, exclude_id)
	if pool.is_empty():
		# Everything but the last one was filtered out — allow the repeat
		# rather than silently skipping the encounter.
		pool = _eligible(profile, &"")
	if pool.is_empty():
		return null
	var total: float = 0.0
	for event in pool:
		total += maxf(event.weight, 0.01)
	var ticket: float = RngService.randf() * total
	for event in pool:
		ticket -= maxf(event.weight, 0.01)
		if ticket <= 0.0:
			return event
	return pool[pool.size() - 1]


## Applies one choice to the profile and reports what happened. The caller
## saves the profile — this never writes to disk.
static func apply(profile: PlayerProfile, choice: EventChoiceData) -> Outcome:
	var outcome := Outcome.new()
	if profile == null or choice == null:
		return outcome
	outcome.text_key = choice.result_key

	if choice.is_wager():
		outcome.wagered = true
		# The stake can never exceed what is actually in the purse.
		var stake: int = mini(choice.wager_gold, profile.gold)
		outcome.wager_won = RngService.chance(choice.win_chance)
		if outcome.wager_won:
			outcome.gold_delta = roundi(stake * (choice.payout_multiplier - 1.0))
		else:
			outcome.gold_delta = -stake
			outcome.text_key = choice.failure_key if choice.failure_key != "" \
					else choice.result_key
	else:
		# A cost may never push the purse below zero.
		outcome.gold_delta = maxi(choice.gold_delta, -profile.gold)

	outcome.fame_delta = choice.fame_delta
	outcome.xp_gain = choice.xp_gain
	outcome.attribute_points = choice.attribute_points
	outcome.item_id = choice.item_id

	profile.gold = maxi(profile.gold + outcome.gold_delta, 0)
	profile.fame = maxi(profile.fame + outcome.fame_delta, 0)
	profile.attribute_points += outcome.attribute_points
	if outcome.xp_gain > 0:
		profile.xp += outcome.xp_gain
	if outcome.item_id != &"":
		_grant_item(profile, outcome.item_id)
	return outcome


## Puts a granted item in the satchel, wherever it belongs. Unknown ids are
## dropped rather than guessed — ItemDB falls back to the first weapon, which
## would quietly gift a shiv.
static func _grant_item(profile: PlayerProfile, item_id: StringName) -> void:
	var weapon: WeaponData = ItemDB.weapon(item_id)
	if weapon != null and weapon.id == item_id:
		profile.inventory_weapon_ids.append(item_id)
		return
	var piece: ArmourData = ItemDB.armour_piece(item_id)
	if piece != null and piece.id == item_id:
		profile.inventory_armour_ids.append(item_id)


static func _eligible(profile: PlayerProfile, exclude_id: StringName) -> Array[EventData]:
	var pool: Array[EventData] = []
	if profile == null:
		return pool
	for event in ItemDB.all_events():
		if event == null or event.id == exclude_id:
			continue
		if profile.level < event.min_level:
			continue
		if event.available_choices(profile.gold).is_empty():
			continue
		pool.append(event)
	return pool
