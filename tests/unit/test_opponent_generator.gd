extends TestCase
## OpponentGenerator: level-appropriate, budgeted, seed-reproducible enemies.


func test_generated_opponent_is_level_appropriate() -> void:
	RngService.set_seed(2024)
	for player_level in [1, 5, 20]:
		var enemy := OpponentGenerator.generate(player_level)
		assert_true(absi(enemy.level - player_level) <= 1,
				"enemy level %d strays too far from player %d" % [enemy.level, player_level])
		assert_true(enemy.level >= 1)
		assert_true(enemy.personality != null, "generated enemies must have an AI personality")
		assert_true(enemy.name_text.length() > 0)
		assert_true(enemy.weapon != null)


func test_attribute_budget_matches_player_growth() -> void:
	RngService.set_seed(7)
	var base: CharacterData = OpponentGenerator.BASE
	var base_sum: int = base.attributes.strength + base.attributes.agility \
			+ base.attributes.attack + base.attributes.defence + base.attributes.vitality \
			+ base.attributes.stamina + base.attributes.arcana + base.attributes.charisma
	var enemy := OpponentGenerator.generate(10)
	var enemy_sum: int = enemy.attributes.strength + enemy.attributes.agility \
			+ enemy.attributes.attack + enemy.attributes.defence + enemy.attributes.vitality \
			+ enemy.attributes.stamina + enemy.attributes.arcana + enemy.attributes.charisma
	assert_eq(enemy_sum, base_sum + (enemy.level - 1) * 3,
			"enemies must grow on the same 3-points-per-level budget as the player")


func test_generation_never_mutates_the_base_resource() -> void:
	RngService.set_seed(99)
	var strength_before: int = OpponentGenerator.BASE.attributes.strength
	var name_before: String = OpponentGenerator.BASE.name_text
	OpponentGenerator.generate(15)
	assert_eq(OpponentGenerator.BASE.attributes.strength, strength_before,
			"generator must duplicate, never edit the .tres content")
	assert_eq(OpponentGenerator.BASE.name_text, name_before)


func test_same_seed_same_opponent() -> void:
	RngService.set_seed(31337)
	var first := OpponentGenerator.generate(8)
	RngService.set_seed(31337)
	var second := OpponentGenerator.generate(8)
	assert_eq(first.name_text, second.name_text)
	assert_eq(first.level, second.level)
	assert_eq(first.attributes.strength, second.attributes.strength)
	assert_eq(first.personality.id, second.personality.id)
