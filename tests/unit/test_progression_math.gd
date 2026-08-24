extends TestCase
## XP curve + reward formulas (charter §14, §35).

const CONFIG: ProgressionConfig = preload("res://data/progression/progression_config.tres")


func test_xp_required_matches_curve_at_level_one() -> void:
	assert_eq(ProgressionCalculator.xp_required(CONFIG, 1), CONFIG.base_xp)


func test_xp_required_is_strictly_increasing() -> void:
	var previous: int = 0
	for level in range(1, CONFIG.max_level + 1):
		var required: int = ProgressionCalculator.xp_required(CONFIG, level)
		assert_true(required > previous, "curve must rise at level %d" % level)
		previous = required


func test_win_beats_loss() -> void:
	var win: int = ProgressionCalculator.xp_reward(CONFIG, 5, 5, true)
	var loss: int = ProgressionCalculator.xp_reward(CONFIG, 5, 5, false)
	assert_true(win > loss, "winning must grant more XP than losing")
	assert_true(loss >= 1, "losing still grants at least 1 XP")


func test_higher_level_enemies_grant_more() -> void:
	var below: int = ProgressionCalculator.xp_reward(CONFIG, 10, 8, true)
	var even: int = ProgressionCalculator.xp_reward(CONFIG, 10, 10, true)
	var above: int = ProgressionCalculator.xp_reward(CONFIG, 10, 12, true)
	assert_true(above > even and even > below, "reward must scale with enemy level")


func test_seal_clubbing_is_clamped() -> void:
	# Fighting far below your level bottoms out at gap_min, never zero/negative.
	var floor_reward: int = ProgressionCalculator.xp_reward(CONFIG, 60, 1, true)
	var expected: int = maxi(roundi(
			CONFIG.xp_win_base * pow(1, CONFIG.xp_win_exponent) * CONFIG.level_gap_min), 1)
	assert_eq(floor_reward, expected, "gap multiplier must clamp at gap_min")
	assert_true(floor_reward >= 1)
