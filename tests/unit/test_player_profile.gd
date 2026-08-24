extends TestCase
## PlayerProfile serialization roundtrip + graceful degradation.


func test_roundtrip_preserves_everything() -> void:
	var profile := PlayerProfile.create_default()
	profile.character_name = "Testo the Brave"
	profile.level = 7
	profile.xp = 123
	profile.attribute_points = 4
	profile.skill_points = 2
	profile.attributes.strength = 15
	profile.attributes.charisma = 9
	profile.gold = 250
	profile.fame = 31
	profile.victories = 12
	profile.defeats = 3
	profile.weapon_id = &"weapon.pit_hatchet"

	var restored := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(restored.character_name, "Testo the Brave")
	assert_eq(restored.level, 7)
	assert_eq(restored.xp, 123)
	assert_eq(restored.attribute_points, 4)
	assert_eq(restored.skill_points, 2)
	assert_eq(restored.attributes.strength, 15)
	assert_eq(restored.attributes.charisma, 9)
	assert_eq(restored.gold, 250)
	assert_eq(restored.fame, 31)
	assert_eq(restored.victories, 12)
	assert_eq(restored.defeats, 3)
	assert_eq(restored.weapon_id, &"weapon.pit_hatchet")
	assert_eq(restored.armour_ids, profile.armour_ids)
	assert_eq(restored.body_color.to_html(), profile.body_color.to_html())


func test_empty_dict_yields_playable_defaults() -> void:
	var profile := PlayerProfile.from_dict({})
	assert_eq(profile.level, 1)
	assert_true(profile.attributes != null)
	assert_true(profile.armour_ids.size() > 0, "defaults must include starter armour")


func test_to_character_data_resolves_items() -> void:
	var profile := PlayerProfile.create_default()
	var data := profile.to_character_data()
	assert_true(data.weapon != null, "weapon id must resolve via ItemDB")
	assert_eq(data.weapon.id, profile.weapon_id)
	assert_eq(data.armour_pieces.size(), profile.armour_ids.size())
	assert_eq(data.level, profile.level)
	# Mutating the combat copy must never touch the profile (data/state split).
	data.attributes.strength += 10
	assert_true(data.attributes.strength != profile.attributes.strength)


func test_unknown_weapon_id_falls_back() -> void:
	var profile := PlayerProfile.create_default()
	profile.weapon_id = &"weapon.does_not_exist"
	var data := profile.to_character_data()
	assert_true(data.weapon != null, "unknown ids degrade to a fallback weapon, not a crash")
