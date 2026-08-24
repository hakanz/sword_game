extends TestCase
## Auto-equip upgrade heuristics (session-2 shop flow).


func test_weapon_upgrade_detection() -> void:
	var profile := PlayerProfile.create_default()  # training_shortsword (6-10)
	assert_true(EquipmentService.is_weapon_upgrade(
			profile, ItemDB.weapon(&"weapon.bronze_gladius")), "9-14 beats 6-10")
	assert_false(EquipmentService.is_weapon_upgrade(
			profile, ItemDB.weapon(&"weapon.training_shortsword")),
			"an identical weapon is not an upgrade")
	profile.weapon_id = &"weapon.crescent_battleaxe"
	assert_false(EquipmentService.is_weapon_upgrade(
			profile, ItemDB.weapon(&"weapon.pit_hatchet")),
			"a weaker weapon is never an upgrade")


func test_armour_upgrade_detection() -> void:
	var profile := PlayerProfile.create_default()  # padded_vest (12, CHEST)
	assert_true(EquipmentService.is_armour_upgrade(
			profile, ItemDB.armour_piece(&"armour.boiled_leather_cuirass")), "16 beats 12")
	assert_false(EquipmentService.is_armour_upgrade(
			profile, ItemDB.armour_piece(&"armour.leather_straps")), "8 loses to 12")
	assert_true(EquipmentService.is_armour_upgrade(
			profile, ItemDB.armour_piece(&"armour.rag_hood")),
			"any piece upgrades an empty slot")


func test_weapon_range_rules() -> void:
	# Session-3 owner design: melee strikes only at ADJACENT; bows are the
	# ranged exception — limited arrows, a knife sidearm, cannot fire adjacent.
	for weapon in ItemDB.all_weapons():
		if weapon.is_ranged():
			assert_true(weapon.range_min >= Enums.DistanceBand.CLOSE,
					"%s must not fire point-blank" % weapon.id)
			assert_eq(weapon.range_max, Enums.DistanceBand.LONG, "%s reaches LONG" % weapon.id)
			assert_eq(weapon.ammo, 4, "%s carries exactly 4 arrows" % weapon.id)
			assert_true(weapon.sidearm != null and not weapon.sidearm.is_ranged(),
					"%s needs a melee sidearm" % weapon.id)
		else:
			assert_eq(weapon.range_min, Enums.DistanceBand.ADJACENT,
					"%s range_min must be ADJACENT" % weapon.id)
			assert_eq(weapon.range_max, Enums.DistanceBand.ADJACENT,
					"%s range_max must be ADJACENT" % weapon.id)
	for skill in ItemDB.all_skills():
		assert_eq(skill.range_extend, 0,
				"%s must not reach past its weapon's bands" % skill.id)
