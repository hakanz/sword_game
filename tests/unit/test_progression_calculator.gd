extends TestCase
## ProgressionCalculator: derived-stat formulas (charter §13.1).


func test_max_hp_scales_with_vitality_and_level() -> void:
	var attrs := CombatFixtures.make_attributes(8, 8, 8, 7, 9, 8, 3, 5)
	assert_eq(ProgressionCalculator.max_hp(attrs, 1), 50 + 9 * 6 + 4)
	var tougher := CombatFixtures.make_attributes(8, 8, 8, 7, 10, 8, 3, 5)
	assert_true(ProgressionCalculator.max_hp(tougher, 1) > ProgressionCalculator.max_hp(attrs, 1))
	assert_true(ProgressionCalculator.max_hp(attrs, 10) > ProgressionCalculator.max_hp(attrs, 1))


func test_max_energy_scales_with_stamina() -> void:
	var attrs := CombatFixtures.make_attributes()
	var athletic := CombatFixtures.make_attributes(8, 8, 8, 7, 9, 20, 3, 5)
	assert_true(ProgressionCalculator.max_energy(athletic, 1) > ProgressionCalculator.max_energy(attrs, 1))


func test_damage_bonus_weapon_class_weights() -> void:
	var attrs := CombatFixtures.make_attributes(10, 10, 8, 7, 9, 8, 10, 5)
	assert_eq(ProgressionCalculator.attribute_damage_bonus(attrs, Enums.WeaponClass.SWORD), 5)
	assert_eq(ProgressionCalculator.attribute_damage_bonus(attrs, Enums.WeaponClass.AXE), 5)
	assert_eq(ProgressionCalculator.attribute_damage_bonus(attrs, Enums.WeaponClass.BLUNT), 5)
	assert_eq(ProgressionCalculator.attribute_damage_bonus(attrs, Enums.WeaponClass.RANGED), 4)
	assert_eq(ProgressionCalculator.attribute_damage_bonus(attrs, Enums.WeaponClass.MAGICAL), 5)
	# STR-heavy brute: axes should out-scale swords.
	var brute := CombatFixtures.make_attributes(20, 5, 8, 7, 9, 8, 2, 5)
	assert_true(
			ProgressionCalculator.attribute_damage_bonus(brute, Enums.WeaponClass.AXE)
			> ProgressionCalculator.attribute_damage_bonus(brute, Enums.WeaponClass.SWORD),
			"STR builds must favor axes over swords")


func test_combatant_setup_uses_calculator() -> void:
	var combatant := CombatFixtures.make_combatant()
	assert_eq(combatant.max_hp, ProgressionCalculator.max_hp(combatant.data.attributes, 1))
	assert_eq(combatant.max_energy, ProgressionCalculator.max_energy(combatant.data.attributes, 1))
	assert_eq(combatant.current_hp, combatant.max_hp, "combat starts at full HP")
	combatant.free()
