extends TestCase
## DamageCalculator.compute_mitigation — pure pipeline math (charter §15, §35).


func test_armour_overflow_carries_into_hp() -> void:
	var m := DamageCalculator.compute_mitigation(25, 0.0, false, 0.0, 10)
	assert_eq(m.after_stance, 25)
	assert_eq(m.absorbed, 10, "armour pool should fully deplete")
	assert_eq(m.hp_damage, 15, "excess must carry into HP, never be discarded")
	assert_eq(m.armour_remaining, 0)


func test_armour_fully_absorbs_small_hit() -> void:
	var m := DamageCalculator.compute_mitigation(10, 0.0, false, 0.0, 50)
	assert_eq(m.absorbed, 10)
	assert_eq(m.hp_damage, 0)
	assert_eq(m.armour_remaining, 40)


func test_zero_armour_all_damage_to_hp() -> void:
	var m := DamageCalculator.compute_mitigation(18, 0.0, false, 0.0, 0)
	assert_eq(m.absorbed, 0)
	assert_eq(m.hp_damage, 18)


func test_armour_penetration_bypasses_pool() -> void:
	var m := DamageCalculator.compute_mitigation(20, 0.0, false, 0.5, 100)
	assert_eq(m.bypass, 10)
	assert_eq(m.absorbed, 10)
	assert_eq(m.hp_damage, 10, "bypass damage must reach HP even with armour left")
	assert_eq(m.armour_remaining, 90)


func test_full_resistance_negates_damage() -> void:
	var m := DamageCalculator.compute_mitigation(30, 1.0, false, 0.0, 5)
	assert_eq(m.after_resistance, 0)
	assert_eq(m.hp_damage, 0)
	assert_eq(m.armour_remaining, 5)


func test_resistance_above_one_is_clamped() -> void:
	var m := DamageCalculator.compute_mitigation(30, 1.5, false, 0.0, 5)
	assert_eq(m.after_resistance, 0, "resistance must clamp at 100%, never heal")


func test_partial_resistance_rounds() -> void:
	var m := DamageCalculator.compute_mitigation(10, 0.25, false, 0.0, 0)
	assert_eq(m.after_resistance, 8)
	assert_eq(m.hp_damage, 8)


func test_defend_stance_reduces_damage() -> void:
	var m := DamageCalculator.compute_mitigation(20, 0.0, true, 0.0, 0)
	assert_eq(m.after_stance, 14, "defend should apply 30% reduction")


func test_negative_raw_damage_clamps_to_zero() -> void:
	var m := DamageCalculator.compute_mitigation(-5, 0.0, false, 0.0, 10)
	assert_eq(m.raw_damage, 0)
	assert_eq(m.hp_damage, 0)
	assert_eq(m.armour_remaining, 10)


func test_conservation_invariant() -> void:
	# absorbed + hp_damage must always equal after_stance — nothing lost, nothing invented.
	for raw in [0, 1, 7, 19, 100, 999]:
		for armour in [0, 1, 12, 500]:
			for pen in [0.0, 0.3, 1.0]:
				var m := DamageCalculator.compute_mitigation(raw, 0.1, true, pen, armour)
				assert_eq(m.absorbed + m.hp_damage, m.after_stance,
						"conservation broke at raw=%d armour=%d pen=%.1f" % [raw, armour, pen])
				assert_true(m.armour_remaining >= 0, "armour went negative")
