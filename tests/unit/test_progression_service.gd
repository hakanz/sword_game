extends TestCase
## ProgressionService.apply_combat_rewards: level-ups, point grants, caps.

const CONFIG: ProgressionConfig = preload("res://data/progression/progression_config.tres")
const ECONOMY: EconomyConfig = preload("res://data/economy/economy_config.tres")


func _result(enemy_level: int, won: bool) -> CombatResult:
	var result := CombatResult.new()
	result.player_won = won
	result.enemy_level = enemy_level
	return result


func test_first_win_is_a_debut_payday() -> void:
	# Session-6 owner design: the FIRST victory guarantees the level-up and
	# pays a one-time debut purse on top of normal combat gold.
	var profile := PlayerProfile.create_default()
	var reward := ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, _result(1, true))
	assert_true(reward.first_victory)
	assert_eq(reward.xp_gained, ProgressionCalculator.xp_required(CONFIG, 1),
			"debut XP tops up to exactly one level")
	assert_eq(profile.level, 2, "the first win must level the gladiator")
	assert_eq(profile.victories, 1)
	assert_eq(profile.defeats, 0)
	assert_true(profile.fame > 0, "victory grants fame")
	assert_eq(reward.gold_gained,
			EconomyCalculator.combat_gold_reward(ECONOMY, 1, true) + ECONOMY.first_victory_gold_bonus)
	assert_eq(profile.gold, reward.gold_gained, "gold lands on the profile")


func test_second_win_pays_the_normal_rate() -> void:
	var profile := PlayerProfile.create_default()
	profile.victories = 1  # debut already behind them
	var reward := ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, _result(1, true))
	assert_false(reward.first_victory)
	assert_eq(reward.xp_gained, ProgressionCalculator.xp_reward(CONFIG, 1, 1, true))
	assert_eq(profile.xp, reward.xp_gained, "sub-level XP stays on the profile")
	assert_eq(profile.level, 1, "one easy win past the debut must not level")
	assert_eq(reward.gold_gained, EconomyCalculator.combat_gold_reward(ECONOMY, 1, true))


func test_loss_counts_and_still_teaches() -> void:
	var profile := PlayerProfile.create_default()
	var reward := ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, _result(1, false))
	assert_eq(profile.defeats, 1)
	assert_true(reward.xp_gained >= 1)


func test_multi_level_up_in_one_fight() -> void:
	var profile := PlayerProfile.create_default()
	var reward := ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, _result(10, true))
	# Expectations derived from the same curve the game uses — not hardcoded.
	var xp: int = ProgressionCalculator.xp_reward(CONFIG, 1, 10, true)
	var expected_level: int = 1
	var pool: int = xp
	while pool >= ProgressionCalculator.xp_required(CONFIG, expected_level):
		pool -= ProgressionCalculator.xp_required(CONFIG, expected_level)
		expected_level += 1
	assert_true(expected_level > 2, "test premise: a level-10 win should jump multiple levels")
	assert_eq(profile.level, expected_level)
	assert_eq(profile.xp, pool)
	assert_eq(reward.levels_gained, expected_level - 1)
	assert_eq(profile.attribute_points,
			(expected_level - 1) * CONFIG.attribute_points_per_level)
	var expected_skill: int = 0
	for level in range(2, expected_level + 1):
		if level % CONFIG.skill_point_every_n_levels == 0:
			expected_skill += 1
	assert_eq(profile.skill_points, expected_skill)


func test_level_cap_holds() -> void:
	var profile := PlayerProfile.create_default()
	profile.level = CONFIG.max_level
	profile.xp = 0
	var reward := ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, _result(60, true))
	assert_eq(profile.level, CONFIG.max_level, "level must never exceed the cap")
	assert_eq(reward.levels_gained, 0)
	assert_true(profile.xp < ProgressionCalculator.xp_required(CONFIG, CONFIG.max_level),
			"XP at cap stays below the next-level requirement")
