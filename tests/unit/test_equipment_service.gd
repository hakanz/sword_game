extends TestCase
## EquipmentService: requirement gating and equip/swap bookkeeping.


func _profile_with(level: int, strength: int = 8, agility: int = 8) -> PlayerProfile:
	var profile := PlayerProfile.create_default()
	profile.level = level
	profile.attributes.strength = strength
	profile.attributes.agility = agility
	return profile


func test_requirements_block_correctly() -> void:
	var profile := _profile_with(1)
	var iron_sword: WeaponData = ItemDB.weapon(&"weapon.iron_longsword")  # lvl8, str12
	assert_eq(EquipmentService.weapon_block_reason(profile, iron_sword), "equip.requires_level")
	profile.level = 8
	assert_eq(EquipmentService.weapon_block_reason(profile, iron_sword), "equip.requires_strength")
	profile.attributes.strength = 12
	assert_eq(EquipmentService.weapon_block_reason(profile, iron_sword), "")

	var bow: WeaponData = ItemDB.weapon(&"weapon.scrap_bow")  # agi10
	profile.attributes.agility = 5
	assert_eq(EquipmentService.weapon_block_reason(profile, bow), "equip.requires_agility")


func test_equip_weapon_swaps_into_inventory() -> void:
	var profile := _profile_with(5)
	var old_weapon: StringName = profile.weapon_id
	profile.inventory_weapon_ids.append(&"weapon.bronze_gladius")
	assert_true(EquipmentService.equip_weapon(profile, &"weapon.bronze_gladius"))
	assert_eq(profile.weapon_id, &"weapon.bronze_gladius")
	assert_true(profile.inventory_weapon_ids.has(old_weapon), "old weapon returns to the satchel")
	assert_false(profile.inventory_weapon_ids.has(&"weapon.bronze_gladius"))


func test_equip_weapon_refuses_unowned_or_blocked() -> void:
	var profile := _profile_with(1)
	assert_false(EquipmentService.equip_weapon(profile, &"weapon.bronze_gladius"),
			"cannot equip what you do not own")
	profile.inventory_weapon_ids.append(&"weapon.iron_longsword")
	assert_false(EquipmentService.equip_weapon(profile, &"weapon.iron_longsword"),
			"level requirement must block equipping")
	assert_true(profile.inventory_weapon_ids.has(&"weapon.iron_longsword"),
			"failed equip must not consume the item")


func test_equip_armour_swaps_same_slot_only() -> void:
	var profile := _profile_with(5)
	# Default kit wears padded_vest (CHEST). Add a chest and a helmet.
	profile.inventory_armour_ids.append(&"armour.boiled_leather_cuirass")
	profile.inventory_armour_ids.append(&"armour.rag_hood")

	assert_true(EquipmentService.equip_armour(profile, &"armour.rag_hood"))
	assert_true(profile.armour_ids.has(&"armour.rag_hood"), "helmet equips into empty slot")
	assert_true(profile.armour_ids.has(&"armour.padded_vest"), "chest untouched by helmet equip")

	assert_true(EquipmentService.equip_armour(profile, &"armour.boiled_leather_cuirass"))
	assert_true(profile.armour_ids.has(&"armour.boiled_leather_cuirass"))
	assert_false(profile.armour_ids.has(&"armour.padded_vest"), "old chest piece unequipped")
	assert_true(profile.inventory_armour_ids.has(&"armour.padded_vest"),
			"old chest piece returns to the satchel")
	assert_true(profile.armour_ids.has(&"armour.rag_hood"), "helmet survives the chest swap")
