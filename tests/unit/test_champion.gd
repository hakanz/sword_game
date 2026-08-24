extends TestCase
## Champion challenge: handcrafted preset, unlock rule, one-time rewards.

const CONFIG: ProgressionConfig = preload("res://data/progression/progression_config.tres")
const ECONOMY: EconomyConfig = preload("res://data/economy/economy_config.tres")
const MAULHILDA: CharacterData = preload("res://data/characters/champions/maulhilda.tres")


func _champion_win() -> CombatResult:
	var result := CombatResult.new()
	result.player_won = true
	result.enemy_level = MAULHILDA.level
	result.champion_id = MAULHILDA.id
	return result


func test_champion_preset_is_complete() -> void:
	assert_true(MAULHILDA.is_champion)
	assert_true(MAULHILDA.personality != null, "champions need a handcrafted personality")
	assert_true(MAULHILDA.skills.size() >= 1, "champions need a signature ability")
	assert_true(MAULHILDA.weapon != null and not MAULHILDA.weapon.shop_available,
			"the signature weapon must be champion-unique, not shop stock")
	assert_true(MAULHILDA.intro_key != "" and MAULHILDA.defeat_key != "")
	assert_true(MAULHILDA.total_armour() > 30,
			"Maulhilda's mechanic is armour: she must open heavily plated")


func test_first_kill_grants_unique_rewards() -> void:
	var profile := PlayerProfile.create_default()
	var reward := ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, _champion_win())
	assert_true(reward.champion_defeated)
	assert_eq(reward.reward_item_id, &"weapon.doorslab")
	assert_true(profile.inventory_weapon_ids.has(&"weapon.doorslab"))
	assert_true(profile.defeated_champion_ids.has(MAULHILDA.id))
	var base_gold: int = EconomyCalculator.combat_gold_reward(ECONOMY, MAULHILDA.level, true)
	assert_eq(reward.gold_gained, base_gold + ECONOMY.champion_gold_bonus)
	assert_eq(profile.gold, base_gold + ECONOMY.champion_gold_bonus,
			"the champion purse must actually land in the pocket")


func test_rematch_pays_no_unique_rewards() -> void:
	var profile := PlayerProfile.create_default()
	ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, _champion_win())
	var second := ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, _champion_win())
	assert_false(second.champion_defeated)
	assert_eq(profile.inventory_weapon_ids.count(&"weapon.doorslab"), 1,
			"the unique weapon must never duplicate")


func test_losing_to_champion_grants_nothing_special() -> void:
	var profile := PlayerProfile.create_default()
	var result := _champion_win()
	result.player_won = false
	var reward := ProgressionService.apply_combat_rewards(profile, CONFIG, ECONOMY, result)
	assert_false(reward.champion_defeated)
	assert_false(profile.defeated_champion_ids.has(MAULHILDA.id))


func test_second_champion_preset_is_complete() -> void:
	var orzha: CharacterData = preload("res://data/characters/champions/orzha.tres")
	assert_true(orzha.is_champion)
	assert_true(orzha.personality != null)
	assert_true(orzha.skills.size() >= 2, "Orzha needs her signature kit")
	assert_true(orzha.weapon != null and not orzha.weapon.shop_available)
	assert_true(orzha.intro_key != "" and orzha.defeat_key != "")
	assert_true(ProgressionService.CHAMPION_REWARDS.has(orzha.id),
			"every champion carries a unique first-kill reward")
	# Duelist identity: she dodges, she doesn't tank.
	assert_true(orzha.attributes.agility > orzha.attributes.defence)
