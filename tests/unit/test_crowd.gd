extends TestCase
## Phase 13 (charter §19, amendment V2 §54) — the crowd.
## The promises under test:
##  1. The meter's states, bounds and boons are exactly what the HUD and the
##     balance notes claim they are.
##  2. Charisma speeds up the CLIMB and nothing else — being dull costs every
##     build the same.
##  3. Stalling is judged by the anti-stall counters combat already keeps, not
##     by a second detector.
##  4. It is runtime state: nothing about it reaches a save file.


func _fighter(charisma: int = 5) -> Combatant:
	var attrs: AttributeBlock = CombatFixtures.make_attributes()
	attrs.charisma = charisma
	return CombatFixtures.make_combatant(CombatFixtures.make_character(attrs))


func _attack_result(actor: Combatant, crit: bool = false, killed: bool = false) -> ActionResult:
	var result := ActionResult.new()
	result.actor = actor
	result.action = Enums.ActionType.ATTACK
	result.hit = true
	result.crit = crit
	result.killed = killed
	return result


# --- States and bounds ------------------------------------------------------

func test_states_map_to_the_documented_bands() -> void:
	assert_eq(CrowdSystem.state_of(0), CrowdSystem.State.HOSTILE)
	assert_eq(CrowdSystem.state_of(CrowdSystem.HOSTILE_BELOW - 1), CrowdSystem.State.HOSTILE)
	assert_eq(CrowdSystem.state_of(CrowdSystem.HOSTILE_BELOW), CrowdSystem.State.BORED)
	assert_eq(CrowdSystem.state_of(CrowdSystem.BORED_BELOW - 1), CrowdSystem.State.BORED)
	assert_eq(CrowdSystem.state_of(CrowdSystem.BORED_BELOW), CrowdSystem.State.NEUTRAL)
	assert_eq(CrowdSystem.state_of(CrowdSystem.EXCITED_AT - 1), CrowdSystem.State.NEUTRAL)
	assert_eq(CrowdSystem.state_of(CrowdSystem.EXCITED_AT), CrowdSystem.State.EXCITED)
	assert_eq(CrowdSystem.state_of(CrowdSystem.FRENZIED_AT - 1), CrowdSystem.State.EXCITED)
	assert_eq(CrowdSystem.state_of(CrowdSystem.FRENZIED_AT), CrowdSystem.State.FRENZIED)
	assert_eq(CrowdSystem.state_of(CrowdSystem.MAXIMUM), CrowdSystem.State.FRENZIED)
	assert_eq(CrowdSystem.state_of(CrowdSystem.START), CrowdSystem.State.NEUTRAL,
			"every fight opens with the pit merely watching")


func test_standing_is_clamped_at_both_ends() -> void:
	var fighter := _fighter()
	CrowdSystem.shift(fighter, 500)
	assert_eq(fighter.crowd, CrowdSystem.MAXIMUM, "the pit cannot love you more than completely")
	CrowdSystem.shift(fighter, -500)
	assert_eq(fighter.crowd, CrowdSystem.MINIMUM, "nor hate you more than completely")
	fighter.free()


func test_charisma_speeds_the_climb_but_not_the_fall() -> void:
	var dull := _fighter(0)
	var showman := _fighter(20)
	CrowdSystem.shift(dull, 10)
	CrowdSystem.shift(showman, 10)
	assert_true(showman.crowd > dull.crowd, "Charisma must buy a faster climb")
	assert_eq(dull.crowd, CrowdSystem.START + 10, "no Charisma means the raw gain")

	var dull_before: int = dull.crowd
	var showman_before: int = showman.crowd
	CrowdSystem.shift(dull, -10)
	CrowdSystem.shift(showman, -10)
	assert_eq(dull_before - dull.crowd, 10, "losses are flat")
	assert_eq(showman_before - showman.crowd, 10,
			"Charisma must NOT soften the fall — that would make it a defensive stat too")
	assert_almost_eq(CrowdSystem.gain_multiplier(0), 1.0, 0.0001)
	assert_true(CrowdSystem.gain_multiplier(20) > CrowdSystem.gain_multiplier(10))
	dull.free()
	showman.free()


# --- What the pit judges ----------------------------------------------------

func test_spectacle_raises_and_dullness_lowers() -> void:
	var fighter := _fighter()
	assert_true(CrowdSystem.delta_for(_attack_result(fighter, true), 1) >= CrowdSystem.CRIT_GAIN,
			"a crit must please the pit")
	assert_true(CrowdSystem.delta_for(_attack_result(fighter, false, true), 1)
			>= CrowdSystem.KILL_GAIN, "a finish is the loudest moment")
	var plain: ActionResult = _attack_result(fighter)
	assert_eq(CrowdSystem.delta_for(plain, 1), 0, "an ordinary landed hit is just the job")

	var rest := ActionResult.new()
	rest.actor = fighter
	rest.action = Enums.ActionType.REST
	assert_eq(CrowdSystem.delta_for(rest, 1), CrowdSystem.REST_LOSS)

	var retreat := ActionResult.new()
	retreat.actor = fighter
	retreat.action = Enums.ActionType.RETREAT
	assert_eq(CrowdSystem.delta_for(retreat, 1), CrowdSystem.RETREAT_LOSS)
	fighter.free()


func test_turtling_is_judged_by_the_existing_anti_stall_counter() -> void:
	var fighter := _fighter()
	var defend := ActionResult.new()
	defend.actor = fighter
	defend.action = Enums.ActionType.DEFEND

	fighter.consecutive_defends = 1
	assert_eq(CrowdSystem.delta_for(defend, 1), 0, "one guard is tactics, not turtling")
	fighter.consecutive_defends = CrowdSystem.TURTLE_AFTER_DEFENDS
	assert_eq(CrowdSystem.delta_for(defend, 1), CrowdSystem.TURTLE_LOSS,
			"the pit boos a fighter who hides behind their guard")
	fighter.free()


func test_a_skill_landed_near_death_is_worth_more() -> void:
	var fighter := _fighter()
	var skill := SkillData.new()
	skill.id = &"skill.probe"
	var result: ActionResult = _attack_result(fighter)
	result.skill = skill

	var healthy: int = CrowdSystem.delta_for(result, 1)
	fighter.current_hp = roundi(fighter.max_hp * 0.2)
	var desperate: int = CrowdSystem.delta_for(result, 1)
	assert_eq(healthy, CrowdSystem.SKILL_GAIN)
	assert_eq(desperate, CrowdSystem.SKILL_GAIN + CrowdSystem.DESPERATE_GAIN,
			"the comeback beat is the whole point of the meter")

	# Crowd appeal rides on the skill DATA, not on a hardcoded id list.
	skill.crowd_appeal = 10
	fighter.current_hp = fighter.max_hp
	assert_eq(CrowdSystem.delta_for(result, 1), CrowdSystem.SKILL_GAIN + 10)
	fighter.free()


func test_a_dragging_fight_bleeds_interest() -> void:
	var fighter := _fighter()
	var result: ActionResult = _attack_result(fighter)
	assert_eq(CrowdSystem.delta_for(result, CrowdSystem.LONG_FIGHT_ROUND), 0,
			"the decay must not start early")
	assert_eq(CrowdSystem.delta_for(result, CrowdSystem.LONG_FIGHT_ROUND + 1),
			CrowdSystem.LONG_FIGHT_LOSS)
	fighter.free()


func test_only_a_guard_that_holds_pays_the_defender() -> void:
	var attacker := _fighter()
	var defender := _fighter()
	var result := ActionResult.new()
	result.actor = attacker
	result.target = defender
	result.action = Enums.ActionType.ATTACK

	result.hit = false
	defender.stance = Enums.Stance.NEUTRAL
	assert_eq(CrowdSystem.defender_delta(result), 0, "a plain dodge is not a highlight")
	defender.stance = Enums.Stance.DEFENDING
	assert_eq(CrowdSystem.defender_delta(result), CrowdSystem.GUARD_HELD_GAIN)
	result.hit = true
	assert_eq(CrowdSystem.defender_delta(result), 0, "a guard that failed pays nothing")
	attacker.free()
	defender.free()


# --- What the crowd gives back ---------------------------------------------

func test_boons_only_arrive_at_the_top_of_the_meter() -> void:
	var fighter := _fighter()
	for value: int in [0, CrowdSystem.START, CrowdSystem.EXCITED_AT - 1]:
		fighter.crowd = value
		assert_eq(CrowdSystem.energy_boon(fighter), 0, "no boon below Excited (%d)" % value)
		assert_eq(CrowdSystem.accuracy_bonus(fighter), 0, "no aim help below Frenzied (%d)" % value)
	fighter.crowd = CrowdSystem.EXCITED_AT
	assert_eq(CrowdSystem.energy_boon(fighter), CrowdSystem.EXCITED_ENERGY)
	assert_eq(CrowdSystem.accuracy_bonus(fighter), 0, "Excited pays energy only")
	fighter.crowd = CrowdSystem.FRENZIED_AT
	assert_eq(CrowdSystem.energy_boon(fighter), CrowdSystem.FRENZIED_ENERGY)
	assert_eq(CrowdSystem.accuracy_bonus(fighter), CrowdSystem.FRENZIED_ACCURACY)
	# Small enough to be a lever, never a tax (V2 §54).
	assert_true(CrowdSystem.FRENZIED_ENERGY <= 6 and CrowdSystem.FRENZIED_ACCURACY <= 5,
			"the crowd must never decide a fight on its own")
	fighter.free()


func test_the_boon_actually_reaches_the_pool_and_the_aim() -> void:
	var fighter := _fighter()
	fighter.spend_energy(fighter.max_energy - 1)
	fighter.crowd = CrowdSystem.FRENZIED_AT
	var before: int = fighter.current_energy
	fighter.on_turn_started()
	assert_eq(fighter.current_energy, before + CrowdSystem.FRENZIED_ENERGY,
			"the roar must arrive as real Energy at turn start")

	var foe := _fighter()
	var frenzied_score: int = HitCalculator.accuracy_score(fighter)
	fighter.crowd = CrowdSystem.START
	var calm_score: int = HitCalculator.accuracy_score(fighter)
	assert_eq(frenzied_score - calm_score, CrowdSystem.FRENZIED_ACCURACY,
			"the accuracy nudge must go through HitCalculator, not a second formula")
	fighter.free()
	foe.free()


# --- Integration through the shared resolver -------------------------------

func test_the_resolver_lets_the_pit_judge_every_action() -> void:
	var actor := _fighter()
	var foe := _fighter()
	var ctx: CombatContext = CombatFixtures.make_context(actor, foe, 3)
	var before: int = actor.crowd

	actor.spend_energy(actor.max_energy - 1)  # makes REST valid
	var decision := CombatDecision.new()
	decision.type = Enums.ActionType.REST
	CombatResolver.execute(actor, foe, ctx, decision)
	assert_true(actor.crowd < before, "resting in front of a paying crowd costs standing")
	assert_eq(foe.crowd, CrowdSystem.START, "the other fighter is untouched by it")
	actor.free()
	foe.free()


func test_the_state_change_is_announced_once_per_crossing() -> void:
	var fighter := _fighter(0)
	var crossings: Array[int] = []
	var handler := func(who: Combatant, state: int, rising: bool) -> void:
		if who == fighter:
			crossings.append(state if rising else -state)
	EventBus.crowd_state_changed.connect(handler)
	CrowdSystem.shift(fighter, CrowdSystem.EXCITED_AT - CrowdSystem.START)
	CrowdSystem.shift(fighter, 1)  # still Excited — no second announcement
	CrowdSystem.shift(fighter, CrowdSystem.FRENZIED_AT - fighter.crowd)
	EventBus.crowd_state_changed.disconnect(handler)
	assert_eq(crossings.size(), 2, "one announcement per crossing, not per point")
	assert_eq(crossings[0], CrowdSystem.State.EXCITED)
	assert_eq(crossings[1], CrowdSystem.State.FRENZIED)
	fighter.free()


# --- Contracts --------------------------------------------------------------

func test_the_meter_is_never_persisted() -> void:
	var profile: PlayerProfile = PlayerProfile.create_default()
	for key: String in profile.to_dict().keys():
		assert_false(key.contains("crowd"), "the crowd meter must reset every fight (%s)" % key)


func test_every_crowd_string_is_translated() -> void:
	for state: int in [CrowdSystem.State.HOSTILE, CrowdSystem.State.BORED,
			CrowdSystem.State.NEUTRAL, CrowdSystem.State.EXCITED, CrowdSystem.State.FRENZIED]:
		var key: String = CrowdSystem.label_key(state as CrowdSystem.State)
		assert_true(TranslationServer.translate(key) != key, "%s has no translation" % key)
	for key: String in ["combat.hud.crowd", "combat.float.crowd_up", "combat.float.crowd_down"]:
		assert_true(TranslationServer.translate(key) != key, "%s has no translation" % key)
