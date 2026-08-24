extends TestCase
## HitCalculator: bounded, monotonic hit chances (charter §15: 5%-95% band).


func test_hit_chance_never_exceeds_band() -> void:
	var strong := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(10, 50, 200, 200, 9, 8, 3, 5)))
	var weak := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(10, 1, 1, 1, 9, 8, 3, 5)))
	assert_almost_eq(HitCalculator.hit_chance(strong, weak), 0.95, 0.0001,
			"overwhelming accuracy must cap at 95%")
	assert_almost_eq(HitCalculator.hit_chance(weak, strong), 0.05, 0.0001,
			"hopeless attacker must floor at 5%")
	strong.free()
	weak.free()


func test_even_match_near_base_chance() -> void:
	var a := CombatFixtures.make_combatant()
	var b := CombatFixtures.make_combatant()
	var chance: float = HitCalculator.hit_chance(a, b)
	assert_true(chance > 0.3 and chance < 0.9,
			"evenly matched fighters should land mid-band, got %f" % chance)
	a.free()
	b.free()


func test_defending_lowers_hit_chance() -> void:
	var attacker := CombatFixtures.make_combatant()
	var defender := CombatFixtures.make_combatant()
	var neutral: float = HitCalculator.hit_chance(attacker, defender)
	defender.set_stance(Enums.Stance.DEFENDING)
	var defended: float = HitCalculator.hit_chance(attacker, defender)
	assert_almost_eq(neutral - defended,
			CombatTuning.DEFEND_AVOIDANCE_BONUS * CombatTuning.HIT_CHANCE_PER_POINT, 0.0001,
			"defend stance must shift hit chance by its avoidance bonus")
	attacker.free()
	defender.free()


func test_weapon_accuracy_bonus_counts() -> void:
	var accurate_weapon := CombatFixtures.make_weapon(6, 10, 10)
	var crude_weapon := CombatFixtures.make_weapon(6, 10, 0)
	var a := CombatFixtures.make_combatant(CombatFixtures.make_character(null, accurate_weapon))
	var b := CombatFixtures.make_combatant(CombatFixtures.make_character(null, crude_weapon))
	var target := CombatFixtures.make_combatant()
	assert_true(HitCalculator.hit_chance(a, target) > HitCalculator.hit_chance(b, target),
			"weapon accuracy bonus must raise hit chance")
	a.free()
	b.free()
	target.free()
