extends TestCase
## CombatAI: utility selection must respond to the situation (charter §20 —
## never random). Seeded so jitter cannot flake these expectations.


func _duelists() -> Array[Combatant]:
	var attacker := CombatFixtures.make_combatant(CombatFixtures.make_character(
			null, null, null, 1))
	var defender := CombatFixtures.make_combatant()
	return [attacker, defender]


func test_closes_distance_when_out_of_melee_range() -> void:
	RngService.set_seed(11)
	var pair := _duelists()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.LONG
	assert_eq(CombatAI.choose_action(pair[0], pair[1], ctx), Enums.ActionType.APPROACH,
			"melee fighter far away must approach")
	pair[0].free()
	pair[1].free()


func test_attacks_when_adjacent_and_able() -> void:
	RngService.set_seed(11)
	var pair := _duelists()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.ADJACENT
	assert_eq(CombatAI.choose_action(pair[0], pair[1], ctx), Enums.ActionType.ATTACK,
			"healthy fighter in range with energy must attack")
	pair[0].free()
	pair[1].free()


func test_rests_when_exhausted() -> void:
	RngService.set_seed(11)
	var pair := _duelists()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.ADJACENT
	pair[0].current_energy = 0
	assert_eq(CombatAI.choose_action(pair[0], pair[1], ctx), Enums.ActionType.REST,
			"exhausted fighter must recover energy")
	pair[0].free()
	pair[1].free()


func test_stalling_has_diminishing_returns() -> void:
	# Regression for the mutual-defend deadlock: a hurt cautious fighter may
	# guard or flee briefly, but decay must eventually force it to act.
	RngService.set_seed(11)
	var personality := AIPersonality.new()
	personality.aggression = 0.8
	personality.caution = 1.5
	var turtle := CombatFixtures.make_combatant(
			CombatFixtures.make_character(null, null, personality))
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.ADJACENT
	turtle.current_hp = roundi(turtle.max_hp * 0.2)

	var first_choice: Enums.ActionType = CombatAI.choose_action(turtle, foe, ctx)
	assert_true(first_choice == Enums.ActionType.DEFEND or first_choice == Enums.ActionType.RETREAT,
			"hurt cautious fighter should act defensively at first, chose %d" % first_choice)

	turtle.consecutive_defends = 6
	turtle.total_retreats = 6
	assert_eq(CombatAI.choose_action(turtle, foe, ctx), Enums.ActionType.ATTACK,
			"after long stalling, the fighter must go back on the offensive")
	turtle.free()
	foe.free()


func test_crowd_impatience_forces_convergence() -> void:
	# Deep-round pressure must eventually outvote any defensive score.
	RngService.set_seed(11)
	var personality := AIPersonality.new()
	personality.aggression = 0.8
	personality.caution = 1.5
	var turtle := CombatFixtures.make_combatant(
			CombatFixtures.make_character(null, null, personality))
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.ADJACENT
	turtle.current_hp = roundi(turtle.max_hp * 0.2)
	ctx.round_number = 80
	assert_eq(CombatAI.choose_action(turtle, foe, ctx), Enums.ActionType.ATTACK,
			"by round 80 even a hurt turtle must swing")
	turtle.free()
	foe.free()


func test_aggressive_personality_prefers_attack_over_defend() -> void:
	RngService.set_seed(11)
	var personality := AIPersonality.new()
	personality.aggression = 1.35
	personality.caution = 0.65
	var attacker := CombatFixtures.make_combatant(
			CombatFixtures.make_character(null, null, personality))
	var defender := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	ctx.distance = Enums.DistanceBand.ADJACENT
	var attacks: int = 0
	for _i in 10:
		if CombatAI.choose_action(attacker, defender, ctx) == Enums.ActionType.ATTACK:
			attacks += 1
	assert_true(attacks >= 8, "aggressive AI attacked only %d/10 times at full health" % attacks)
	attacker.free()
	defender.free()
