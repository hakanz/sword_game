extends TestCase
## Phase 16 (charter §23) — between-fights encounters.
## What must hold:
##  1. Every authored event is playable and fully translated in both languages
##     (a half-written encounter is worse than none).
##  2. Outcomes only ever move things the game already understands, and can
##     never leave the player with negative gold.
##  3. Wagers stake IN-GAME GOLD ONLY (charter §5) and cannot bet more than
##     the purse holds.
##  4. Encounters stay out of the debut arc and never repeat back to back.


func _profile(gold: int = 500, level: int = 10, victories: int = 5) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.create_default()
	profile.gold = gold
	profile.level = level
	profile.victories = victories
	return profile


# --- Content integrity ------------------------------------------------------

func test_every_event_is_playable_and_translated() -> void:
	var events: Array[EventData] = ItemDB.all_events()
	assert_true(events.size() >= 6, "charter §23 names six kinds of encounter")
	for event: EventData in events:
		assert_true(event.id != &"", "an event needs a stable id")
		for key: String in [event.title_key, event.body_key]:
			assert_true(key != "", "%s is missing text" % event.id)
			assert_true(TranslationServer.translate(key) != key,
					"%s is not translated" % key)
		assert_true(event.choices.size() >= 2,
				"%s offers no actual decision" % event.id)
		for choice: EventChoiceData in event.choices:
			assert_true(TranslationServer.translate(choice.label_key) != choice.label_key,
					"%s: %s is not translated" % [event.id, choice.label_key])
			assert_true(TranslationServer.translate(choice.result_key) != choice.result_key,
					"%s: %s is not translated" % [event.id, choice.result_key])
			if choice.is_wager():
				assert_true(choice.failure_key != "",
						"%s: a wager needs a line for losing" % event.id)
				assert_true(TranslationServer.translate(choice.failure_key)
						!= choice.failure_key, "%s is not translated" % choice.failure_key)


func test_every_event_has_a_free_way_out_or_an_affordable_option() -> void:
	# A penniless gladiator must never meet a wall of options they cannot take.
	for event: EventData in ItemDB.all_events():
		assert_false(event.available_choices(0).is_empty(),
				"%s leaves a broke player with nothing to click" % event.id)


func test_wagers_are_gold_only_and_sanely_priced() -> void:
	for event: EventData in ItemDB.all_events():
		for choice: EventChoiceData in event.choices:
			if not choice.is_wager():
				continue
			assert_true(choice.win_chance > 0.0 and choice.win_chance < 1.0,
					"%s: a wager with no risk or no hope is not a wager" % event.id)
			assert_true(choice.payout_multiplier > 1.0,
					"%s: winning must pay more than the stake" % event.id)
			assert_true(choice.wager_gold <= 500,
					"%s: stakes stay inside a plausible purse" % event.id)
			assert_eq(choice.gold_needed(), maxi(choice.requires_gold, choice.wager_gold),
					"a wager must be gated on being able to cover it")


func test_granted_items_exist_in_the_catalog() -> void:
	for event: EventData in ItemDB.all_events():
		for choice: EventChoiceData in event.choices:
			if choice.item_id == &"":
				continue
			var weapon: WeaponData = ItemDB.weapon(choice.item_id)
			var piece: ArmourData = ItemDB.armour_piece(choice.item_id)
			var known: bool = (weapon != null and weapon.id == choice.item_id) \
					or (piece != null and piece.id == choice.item_id)
			assert_true(known, "%s hands over an unknown item %s" % [event.id, choice.item_id])


# --- Selection --------------------------------------------------------------

func test_encounters_stay_out_of_the_debut() -> void:
	var fresh: PlayerProfile = _profile(500, 1, 0)
	RngService.set_seed(5)
	for _i in 30:
		assert_false(EventService.should_occur(fresh),
				"the first fights belong to the fight itself")
	var veteran: PlayerProfile = _profile(500, 10, 9)
	var occurrences: int = 0
	for _i in 200:
		if EventService.should_occur(veteran):
			occurrences += 1
	assert_true(occurrences > 0, "encounters must actually happen")
	assert_true(occurrences < 200, "...but not after every single fight")


func test_the_same_encounter_never_lands_twice_running() -> void:
	var profile: PlayerProfile = _profile()
	RngService.set_seed(31)
	for _i in 40:
		var first: EventData = EventService.pick(profile, &"")
		assert_true(first != null)
		if first == null:
			continue
		var second: EventData = EventService.pick(profile, first.id)
		assert_true(second != null and second.id != first.id,
				"the excluded encounter came back immediately")


func test_selection_respects_level_and_purse() -> void:
	var rookie: PlayerProfile = _profile(0, 1, 9)
	RngService.set_seed(7)
	for _i in 25:
		var event: EventData = EventService.pick(rookie, &"")
		if event == null:
			continue
		assert_true(event.min_level <= rookie.level,
				"%s should not be offered at level %d" % [event.id, rookie.level])
		assert_false(event.available_choices(rookie.gold).is_empty(),
				"%s was offered with nothing affordable in it" % event.id)


func test_picking_is_seed_reproducible() -> void:
	var profile: PlayerProfile = _profile()
	RngService.set_seed(4242)
	var first: EventData = EventService.pick(profile, &"")
	RngService.set_seed(4242)
	var again: EventData = EventService.pick(profile, &"")
	assert_eq(first.id, again.id, "encounters replay with the seed like everything else")


# --- Outcomes ---------------------------------------------------------------

func test_a_plain_choice_moves_exactly_what_it_says() -> void:
	var profile: PlayerProfile = _profile(200, 5, 5)
	var choice := EventChoiceData.new()
	choice.gold_delta = -30
	choice.fame_delta = 4
	choice.xp_gain = 25
	choice.attribute_points = 1
	var before_xp: int = profile.xp
	var outcome: EventService.Outcome = EventService.apply(profile, choice)
	assert_eq(profile.gold, 170)
	assert_eq(profile.fame, 4)
	assert_eq(profile.xp, before_xp + 25)
	assert_eq(profile.attribute_points, 1)
	assert_eq(outcome.gold_delta, -30)
	assert_false(outcome.wagered)


func test_a_cost_can_never_push_the_purse_below_zero() -> void:
	var profile: PlayerProfile = _profile(10, 5, 5)
	var choice := EventChoiceData.new()
	choice.gold_delta = -500
	EventService.apply(profile, choice)
	assert_eq(profile.gold, 0, "an event must never leave a player in debt")


func test_a_wager_pays_out_or_takes_the_stake() -> void:
	var choice := EventChoiceData.new()
	choice.wager_gold = 100
	choice.payout_multiplier = 2.0
	choice.result_key = "won"
	choice.failure_key = "lost"

	# Certainty in both directions, so neither branch depends on a lucky seed.
	choice.win_chance = 1.0
	var winner: PlayerProfile = _profile(300)
	var won: EventService.Outcome = EventService.apply(winner, choice)
	assert_true(won.wagered and won.wager_won)
	assert_eq(won.gold_delta, 100, "a 2x payout on a 100 stake nets the stake back over")
	assert_eq(winner.gold, 400)
	assert_eq(won.text_key, "won")

	choice.win_chance = 0.0
	var loser: PlayerProfile = _profile(300)
	var lost: EventService.Outcome = EventService.apply(loser, choice)
	assert_true(lost.wagered and not lost.wager_won)
	assert_eq(lost.gold_delta, -100)
	assert_eq(loser.gold, 200)
	assert_eq(lost.text_key, "lost", "losing must say so in its own words")


func test_a_wager_can_never_stake_more_than_the_purse_holds() -> void:
	var choice := EventChoiceData.new()
	choice.wager_gold = 400
	choice.win_chance = 0.0
	choice.payout_multiplier = 2.0
	var profile: PlayerProfile = _profile(50)
	EventService.apply(profile, choice)
	assert_eq(profile.gold, 0, "the stake is capped at what is actually on hand")


func test_an_item_gift_reaches_the_satchel_and_junk_does_not() -> void:
	var profile: PlayerProfile = _profile()
	var weapon_gift := EventChoiceData.new()
	weapon_gift.item_id = &"weapon.bronze_gladius"
	EventService.apply(profile, weapon_gift)
	assert_true(profile.inventory_weapon_ids.has(&"weapon.bronze_gladius"))

	var armour_gift := EventChoiceData.new()
	armour_gift.item_id = &"armour.padded_vest"
	EventService.apply(profile, armour_gift)
	assert_true(profile.inventory_armour_ids.has(&"armour.padded_vest"))

	var junk := EventChoiceData.new()
	junk.item_id = &"weapon.not_a_real_item"
	var weapons_before: int = profile.inventory_weapon_ids.size()
	var armour_before: int = profile.inventory_armour_ids.size()
	EventService.apply(profile, junk)
	assert_eq(profile.inventory_weapon_ids.size(), weapons_before,
			"an unknown id must not silently gift the catalog's first weapon")
	assert_eq(profile.inventory_armour_ids.size(), armour_before)


func test_encounters_are_not_persisted() -> void:
	for key: String in PlayerProfile.create_default().to_dict().keys():
		assert_false(key.contains("event"),
				"an unseen encounter is forgotten on quit, by design (%s)" % key)
