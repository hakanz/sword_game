extends TestCase
## CombatAction: validity rules + energy costs shared by HUD, AI, controller.


func test_attack_energy_cost_comes_from_weapon() -> void:
	var combatant := CombatFixtures.make_combatant(
			CombatFixtures.make_character(null, CombatFixtures.make_weapon(6, 10, 2, 0.0,
					Enums.DistanceBand.ADJACENT, Enums.DistanceBand.CLOSE, 9)))
	assert_eq(CombatAction.energy_cost(Enums.ActionType.ATTACK, combatant), 9)
	assert_eq(CombatAction.energy_cost(Enums.ActionType.APPROACH, combatant),
			CombatTuning.MOVE_ENERGY_COST)
	assert_eq(CombatAction.energy_cost(Enums.ActionType.DEFEND, combatant), 0)
	assert_eq(CombatAction.energy_cost(Enums.ActionType.REST, combatant), 0)
	combatant.free()


func test_melee_attack_invalid_out_of_range() -> void:
	var combatant := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.LONG
	assert_false(CombatAction.is_valid(Enums.ActionType.ATTACK, combatant, ctx))
	assert_eq(CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, combatant, ctx),
			"combat.hint.too_far")
	ctx.distance = Enums.DistanceBand.CLOSE
	assert_true(CombatAction.is_valid(Enums.ActionType.ATTACK, combatant, ctx))
	combatant.free()


func test_attack_invalid_without_energy() -> void:
	var combatant := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.ADJACENT
	combatant.current_energy = 0
	assert_false(CombatAction.is_valid(Enums.ActionType.ATTACK, combatant, ctx))
	assert_eq(CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, combatant, ctx),
			"combat.hint.no_energy")
	combatant.free()


func test_movement_blocked_at_extremes() -> void:
	var combatant := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.ADJACENT
	assert_false(CombatAction.is_valid(Enums.ActionType.APPROACH, combatant, ctx))
	assert_true(CombatAction.is_valid(Enums.ActionType.RETREAT, combatant, ctx))
	ctx.distance = Enums.DistanceBand.LONG
	assert_true(CombatAction.is_valid(Enums.ActionType.APPROACH, combatant, ctx))
	assert_false(CombatAction.is_valid(Enums.ActionType.RETREAT, combatant, ctx))
	combatant.free()


func test_rest_invalid_at_full_energy() -> void:
	var combatant := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	assert_false(CombatAction.is_valid(Enums.ActionType.REST, combatant, ctx))
	combatant.current_energy = combatant.max_energy / 2
	assert_true(CombatAction.is_valid(Enums.ActionType.REST, combatant, ctx))
	combatant.free()


func test_defend_always_valid() -> void:
	var combatant := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	combatant.current_energy = 0
	for band: Enums.DistanceBand in Enums.DistanceBand.values():
		ctx.distance = band
		assert_true(CombatAction.is_valid(Enums.ActionType.DEFEND, combatant, ctx),
				"defend must stay available at band %d even with zero energy" % band)
	combatant.free()
