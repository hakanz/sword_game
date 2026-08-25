class_name ProgressionService
## Applies combat outcomes to a PlayerProfile (charter §14): XP, level-ups
## (possibly several per fight), attribute/skill point grants, win/loss
## record, fame. Math comes from ProgressionCalculator; this service only
## mutates the profile. Callers (GameManager) are responsible for autosaving
## afterwards.


## Unique first-kill drops per champion (data pairing lives here until a
## champion roster resource exists in the content-expansion phase).
const CHAMPION_REWARDS: Dictionary = {
	&"character.champion_maulhilda": &"weapon.doorslab",
	&"character.champion_orzha": &"weapon.sablefang",
}


class RewardResult:
	extends RefCounted
	## Set when this fight was against a recurring rival (results screen).
	var rival_id: StringName = &""
	var xp_gained: int = 0
	var gold_gained: int = 0
	var levels_gained: int = 0
	var new_level: int = 1
	var attribute_points_gained: int = 0
	var skill_points_gained: int = 0
	## First-time champion kill this fight (unique reward granted).
	var champion_defeated: bool = false
	var reward_item_id: StringName = &""
	## Extra purse for completing a region tournament (set by GameManager —
	## only it knows the bracket state).
	var tournament_bonus_gold: int = 0
	## The player's first-ever victory this profile (debut rewards granted).
	var first_victory: bool = false
	var first_victory_gold: int = 0


static func apply_combat_rewards(
		profile: PlayerProfile, config: ProgressionConfig,
		economy: EconomyConfig, result: CombatResult) -> RewardResult:
	var reward := RewardResult.new()
	reward.xp_gained = ProgressionCalculator.xp_reward(
			config, profile.level, result.enemy_level, result.player_won,
			result.player_hits, result.player_actions)
	# Boss anchor (session-5 owner design): the champion final is the level
	# pacer — beating one pays meaningfully more than a normal duel.
	if result.player_won and result.champion_id != &"":
		reward.xp_gained = roundi(reward.xp_gained * config.champion_xp_multiplier)
	reward.gold_gained = EconomyCalculator.combat_gold_reward(
			economy, result.enemy_level, result.player_won)
	profile.gold += reward.gold_gained

	if result.player_won:
		profile.victories += 1
		profile.fame += result.enemy_level
		# Debut rewards (session-6 owner design): the first win pays a bonus
		# purse AND guarantees the level-up — a strong hook into the loop.
		if profile.victories == 1:
			reward.first_victory = true
			reward.first_victory_gold = economy.first_victory_gold_bonus
			reward.gold_gained += reward.first_victory_gold
			profile.gold += reward.first_victory_gold
			reward.xp_gained = maxi(reward.xp_gained,
					ProgressionCalculator.xp_required(config, profile.level))
	else:
		profile.defeats += 1

	# First-time champion kill: unique weapon + purse + fame (charter §20:
	# each champion carries a unique reward). Rematches pay normally only.
	if result.player_won and result.champion_id != &"" \
			and not profile.defeated_champion_ids.has(result.champion_id):
		profile.defeated_champion_ids.append(result.champion_id)
		reward.champion_defeated = true
		reward.reward_item_id = CHAMPION_REWARDS.get(result.champion_id, &"")
		if reward.reward_item_id != &"":
			profile.inventory_weapon_ids.append(reward.reward_item_id)
		reward.gold_gained += economy.champion_gold_bonus
		profile.gold += economy.champion_gold_bonus
		profile.fame += economy.champion_fame_bonus

	# Rivalry bookkeeping (V2 §55): who is ahead now, and what they brought.
	if result.rival_id != &"":
		RivalService.record_result(profile, result.rival_id,
				result.player_won, result.rival_weapon_id)
		reward.rival_id = result.rival_id

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
