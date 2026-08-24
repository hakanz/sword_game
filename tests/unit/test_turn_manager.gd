extends TestCase
## TurnManager: initiative ordering, round counting, corpse skipping.


func _fast_and_slow() -> Array[Combatant]:
	var fast := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 20, 8, 7, 9, 8, 3, 5)))
	var slow := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 2, 8, 7, 9, 8, 3, 5)))
	return [fast, slow]


func test_higher_initiative_acts_first() -> void:
	RngService.set_seed(4242)
	var pair := _fast_and_slow()
	var manager := TurnManager.new()
	manager.setup(pair)
	assert_eq(manager.advance(), pair[0], "high-agility fighter must open the round")
	assert_true(manager.is_round_start())
	assert_eq(manager.round_number, 1)
	assert_eq(manager.advance(), pair[1])
	assert_false(manager.is_round_start())
	assert_eq(manager.round_number, 1)
	pair[0].free()
	pair[1].free()


func test_round_increments_on_wrap() -> void:
	RngService.set_seed(4242)
	var pair := _fast_and_slow()
	var manager := TurnManager.new()
	manager.setup(pair)
	manager.advance()
	manager.advance()
	assert_eq(manager.advance(), pair[0], "order must wrap back to the fastest")
	assert_true(manager.is_round_start())
	assert_eq(manager.round_number, 2)
	pair[0].free()
	pair[1].free()


func test_dead_combatants_are_skipped() -> void:
	RngService.set_seed(4242)
	var pair := _fast_and_slow()
	var manager := TurnManager.new()
	manager.setup(pair)
	manager.advance()
	pair[1].current_hp = 0
	assert_eq(manager.advance(), pair[0], "dead fighter must be skipped")
	assert_eq(manager.round_number, 2, "skipping a corpse still wraps the round")
	pair[0].free()
	pair[1].free()
