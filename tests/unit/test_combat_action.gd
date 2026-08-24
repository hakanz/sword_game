extends TestCase
## CombatAction: validity rules + energy costs shared by HUD, AI, controller.
## Session-2 rules: attacks land ONLY toe to toe (ADJACENT); movement is
## per-fighter with the arena wall at each end; rest restores Energy AND HP.


func test_attack_energy_cost_comes_from_weapon() -> void:
	var combatant := CombatFixtures.make_combatant(
			CombatFixtures.make_character(null, CombatFixtures.make_weapon(6, 10, 2, 0.0,
					Enums.DistanceBand.ADJACENT, Enums.DistanceBand.ADJACENT, 9)))
	assert_eq(CombatAction.energy_cost(Enums.ActionType.ATTACK, combatant), 9)
	assert_eq(CombatAction.energy_cost(Enums.ActionType.APPROACH, combatant),
			CombatTuning.MOVE_ENERGY_COST)
	assert_eq(CombatAction.energy_cost(Enums.ActionType.DEFEND, combatant), 0)
	assert_eq(CombatAction.energy_cost(Enums.ActionType.REST, combatant), 0)
	combatant.free()


func test_attack_only_when_adjacent() -> void:
	var attacker := CombatFixtures.make_combatant()
	var foe := CombatFixtures.make_combatant()
	for separation in [2, 3, 4]:
		var ctx := CombatFixtures.make_context(attacker, foe, separation)
		assert_false(CombatAction.is_valid(Enums.ActionType.ATTACK, attacker, ctx),
				"attack must be invalid at separation %d" % separation)
		assert_eq(CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, attacker, ctx),
				"combat.hint.too_far")
	var adjacent := CombatFixtures.make_context(attacker, foe, 1)
	assert_true(CombatAction.is_valid(Enums.ActionType.ATTACK, attacker, adjacent),
			"toe to toe, the attack must be allowed")
	attacker.free()
	foe.free()


func test_attack_invalid_without_energy() -> void:
	var combatant := CombatFixtures.make_combatant()
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(combatant, foe, 1)
	combatant.current_energy = 0
	assert_false(CombatAction.is_valid(Enums.ActionType.ATTACK, combatant, ctx))
	assert_eq(CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, combatant, ctx),
			"combat.hint.no_energy")
	combatant.free()
	foe.free()


func test_movement_blocked_at_adjacency_and_walls() -> void:
	var left := CombatFixtures.make_combatant()
	var right := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(left, right, 1)
	assert_false(CombatAction.is_valid(Enums.ActionType.APPROACH, left, ctx),
			"cannot step into an occupied cell")
	assert_true(CombatAction.is_valid(Enums.ActionType.RETREAT, left, ctx))

	# Back the left fighter into the arena wall (cell 0): no further retreat.
	left.cell = 0
	right.cell = 2
	assert_false(CombatAction.is_valid(Enums.ActionType.RETREAT, left, ctx),
			"the arena wall must block retreat")
	assert_true(CombatAction.is_valid(Enums.ActionType.APPROACH, left, ctx))
	# The right fighter still has room behind them.
	assert_true(CombatAction.is_valid(Enums.ActionType.RETREAT, right, ctx))
	left.free()
	right.free()


func test_movement_is_personal() -> void:
	# Only the acting fighter's cell may change (session-2 directive).
	var left := CombatFixtures.make_combatant()
	var right := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(left, right, 3)
	var right_before: int = right.cell
	ctx.approach(left)
	assert_eq(right.cell, right_before, "approach must not move the other fighter")
	assert_eq(ctx.separation(), 2)
	ctx.retreat(right)
	assert_eq(left.cell, 3, "retreat must not move the other fighter")
	assert_eq(ctx.separation(), 3)
	left.free()
	right.free()


func test_band_mapping() -> void:
	var left := CombatFixtures.make_combatant()
	var right := CombatFixtures.make_combatant()
	var expectations: Dictionary = {
		1: Enums.DistanceBand.ADJACENT,
		2: Enums.DistanceBand.CLOSE,
		3: Enums.DistanceBand.MEDIUM,
		4: Enums.DistanceBand.LONG,
		5: Enums.DistanceBand.LONG,
	}
	for separation: int in expectations.keys():
		var ctx := CombatFixtures.make_context(left, right, separation)
		assert_eq(ctx.band(), expectations[separation],
				"separation %d maps to the wrong band" % separation)
	left.free()
	right.free()


func test_rest_restores_hp_too() -> void:
	var combatant := CombatFixtures.make_combatant()
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(combatant, foe, 2)
	# Both full: nothing to recover.
	assert_false(CombatAction.is_valid(Enums.ActionType.REST, combatant, ctx))
	# Full energy but wounded: rest is now a valid (healing) choice.
	combatant.current_hp = combatant.max_hp / 2
	assert_true(CombatAction.is_valid(Enums.ActionType.REST, combatant, ctx),
			"rest must be available to heal even at full energy")
	combatant.current_hp = combatant.max_hp
	combatant.current_energy = combatant.max_energy / 2
	assert_true(CombatAction.is_valid(Enums.ActionType.REST, combatant, ctx))
	combatant.free()
	foe.free()


func test_defend_always_valid() -> void:
	var combatant := CombatFixtures.make_combatant()
	var foe := CombatFixtures.make_combatant()
	combatant.current_energy = 0
	for separation in [1, 2, 4]:
		var ctx := CombatFixtures.make_context(combatant, foe, separation)
		assert_true(CombatAction.is_valid(Enums.ActionType.DEFEND, combatant, ctx),
				"defend must stay available at separation %d even with zero energy" % separation)
	combatant.free()
	foe.free()
