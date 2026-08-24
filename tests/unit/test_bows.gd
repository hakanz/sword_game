extends TestCase
## Session-3 archer design: start on the knife, switch to the bow, four
## arrows, back to steel when they run dry.

const HUNTING_BOW: WeaponData = preload("res://data/weapons/hunting_bow.tres")


func _archer() -> Combatant:
	return CombatFixtures.make_combatant(
			CombatFixtures.make_character(null, HUNTING_BOW))


func test_archer_opens_on_the_knife() -> void:
	var archer := _archer()
	assert_true(archer.can_switch_weapon())
	assert_false(archer.wielding_main, "the fight must start on the sidearm")
	assert_eq(archer.get_weapon().id, &"weapon.skinning_knife")
	assert_eq(archer.arrows, 4)
	archer.free()


func test_switch_is_an_action_that_swaps_weapons() -> void:
	var archer := _archer()
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(archer, foe, 3)
	assert_true(CombatAction.is_valid(Enums.ActionType.SWITCH_WEAPON, archer, ctx))
	var result := CombatResolver.execute(archer, foe, ctx,
			CombatDecision.base_action(Enums.ActionType.SWITCH_WEAPON))
	assert_eq(result.action, Enums.ActionType.SWITCH_WEAPON)
	assert_eq(archer.get_weapon().id, HUNTING_BOW.id, "switching draws the bow")
	# Melee fighters have nothing to switch to.
	assert_false(CombatAction.is_valid(Enums.ActionType.SWITCH_WEAPON, foe, ctx))
	archer.free()
	foe.free()


func test_bow_range_and_ammo_rules() -> void:
	var archer := _archer()
	archer.switch_weapon()  # draw the bow
	var foe := CombatFixtures.make_combatant()
	var adjacent := CombatFixtures.make_context(archer, foe, 1)
	assert_eq(CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, archer, adjacent),
			"combat.hint.too_far", "bows cannot fire point-blank")
	var medium := CombatFixtures.make_context(archer, foe, 3)
	assert_true(CombatAction.is_valid(Enums.ActionType.ATTACK, archer, medium),
			"bows fire from distance")
	archer.arrows = 0
	assert_eq(CombatAction.invalid_reason_key(Enums.ActionType.ATTACK, archer, medium),
			"combat.hint.no_ammo", "an empty quiver blocks shooting")
	archer.free()
	foe.free()


func test_arrows_are_spent_hit_or_miss() -> void:
	RngService.set_seed(88)
	var archer := _archer()
	archer.switch_weapon()
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(archer, foe, 3)
	for expected_left in [3, 2, 1, 0]:
		CombatResolver.execute(archer, foe, ctx,
				CombatDecision.base_action(Enums.ActionType.ATTACK))
		assert_eq(archer.arrows, expected_left, "each loosed arrow must be spent")
	assert_false(CombatAction.is_valid(Enums.ActionType.ATTACK, archer, ctx),
			"the fifth shot must not exist")
	archer.free()
	foe.free()


func test_ai_archer_flow() -> void:
	RngService.set_seed(11)
	var archer := _archer()
	var foe := CombatFixtures.make_combatant()
	# Knife in hand, foe far: draw the bow instead of marching in.
	var far := CombatFixtures.make_context(archer, foe, 3)
	assert_eq(CombatAI.choose_action(archer, foe, far).type,
			Enums.ActionType.SWITCH_WEAPON, "archer should draw the bow at range")
	# Bow in hand but quiver empty and foe adjacent: back to the knife.
	archer.switch_weapon()
	archer.arrows = 0
	var adjacent := CombatFixtures.make_context(archer, foe, 1)
	assert_eq(CombatAI.choose_action(archer, foe, adjacent).type,
			Enums.ActionType.SWITCH_WEAPON, "empty quiver up close means knife time")
	archer.free()
	foe.free()
