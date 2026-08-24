class_name ProgressionService
## Applies combat outcomes to a PlayerProfile (charter §14): XP, level-ups
## (possibly several per fight), attribute/skill point grants, win/loss
## record, fame. Math comes from ProgressionCalculator; this service only
## mutates the profile. Callers (GameManager) are responsible for autosaving
## afterwards.


class RewardResult:
	extends RefCounted
	var xp_gained: int = 0
	var levels_gained: int = 0
	var new_level: int = 1
	var attribute_points_gained: int = 0
	var skill_points_gained: int = 0


static func apply_combat_rewards(
		profile: PlayerProfile, config: ProgressionConfig,
		result: CombatResult) -> RewardResult:
	var reward := RewardResult.new()
	reward.xp_gained = ProgressionCalculator.xp_reward(
			config, profile.level, result.enemy_level, result.player_won)

	if result.player_won:
		profile.victories += 1
		profile.fame += result.enemy_level
	else:
		profile.defeats += 1

	profile.xp += reward.xp_gained
	while profile.level < config.max_level \
			and profile.xp >= ProgressionCalculator.xp_required(config, profile.level):
		profile.xp -= ProgressionCalculator.xp_required(config, profile.level)
		profile.level += 1
		reward.levels_gained += 1
		reward.attribute_points_gained += config.attribute_points_per_level
		if profile.level % config.skill_point_every_n_levels == 0:
			reward.skill_points_gained += 1

	profile.attribute_points += reward.attribute_points_gained
	profile.skill_points += reward.skill_points_gained

	if profile.level >= config.max_level:
		# At the cap, surplus XP is capped just below the (unreachable) next
		# level so the XP bar stays meaningful and cannot overflow.
		profile.xp = mini(profile.xp,
				ProgressionCalculator.xp_required(config, config.max_level) - 1)

	reward.new_level = profile.level
	return reward
