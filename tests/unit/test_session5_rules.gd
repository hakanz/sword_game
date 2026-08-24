extends TestCase
## Session-5 owner rules: player-first turn order, agility/gear mobility
## tiers, XP effectiveness, the arena's tournament call, elite brackets and
## the champion XP anchor.

const CONFIG: ProgressionConfig = preload("res://data/progression/progression_config.tres")
const ECONOMY: EconomyConfig = preload("res://data/economy/economy_config.tres")


# --- Turn order --------------------------------------------------------------

func test_player_always_opens_the_fight() -> void:
	RngService.set_seed(777)
	# Player is SLOW (agility 2) vs a lightning-fast AI — the hero still opens.
	var player := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 2, 8, 7, 9, 8, 3, 5)), true)
	var enemy := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 20, 8, 7, 9, 8, 3, 5)))
	var manager := TurnManager.new()
	manager.setup([enemy, player])
	assert_eq(manager.advance(), player, "player-controlled fighter must act first")
	assert_eq(manager.advance(), enemy)
	player.free()
	enemy.free()


func test_ai_vs_ai_still_uses_initiative() -> void:
	RngService.set_seed(777)
	var fast := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 20, 8, 7, 9, 8, 3, 5)))
	var slow := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 2, 8, 7, 9, 8, 3, 5)))
	var manager := TurnManager.new()
	manager.setup([slow, fast])
	assert_eq(manager.advance(), fast, "no player flag -> initiative decides")
	fast.free()
	slow.free()


# --- Mobility tiers ----------------------------------------------------------

func test_move_cells_tiers() -> void:
	assert_eq(ProgressionCalculator.move_cells(8), 1, "average agility walks 1 cell")
	assert_eq(ProgressionCalculator.move_cells(13), 1)
	assert_eq(ProgressionCalculator.move_cells(14), 2, "agility 14 reaches tier 2")
	assert_eq(ProgressionCalculator.move_cells(10, 2), 2, "gear mobility counts double")
	assert_eq(ProgressionCalculator.move_cells(20, 5), 2, "tier 2 is the cap")


func test_combatant_move_cells_includes_gear() -> void:
	var character := CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 10, 8, 7, 9, 8, 3, 5))
	var boots := ArmourData.new()
	boots.id = &"armour.test_boots"
	boots.slot = Enums.EquipSlot.BOOTS
	boots.mobility_bonus = 2
	character.armour_pieces = [boots]
	var combatant := CombatFixtures.make_combatant(character)
	assert_eq(combatant.move_cells, 2, "agility 10 + mobility 2 gear = tier 2")
	combatant.free()


func test_fast_approach_never_crosses_the_foe() -> void:
	var left := CombatFixtures.make_combatant()
	var right := CombatFixtures.make_combatant()
	left.move_cells = 2
	var ctx := CombatFixtures.make_context(left, right, 2)
	ctx.approach(left)
	assert_eq(ctx.separation(), 1, "2-cell move must stop at ADJACENT, never overlap")
	left.free()
	right.free()


func test_fast_retreat_clamps_at_the_wall() -> void:
	var left := CombatFixtures.make_combatant()
	var right := CombatFixtures.make_combatant()
	left.move_cells = 2
	var ctx := CombatContext.new()
	ctx.setup(left, right, 1, 5)  # one cell from the left wall
	ctx.retreat(left)
	assert_eq(left.cell, 0, "retreat clamps at cell 0, never leaves the arena")
	left.free()
	right.free()


func test_resolver_tracks_actions_and_hits() -> void:
	RngService.set_seed(11)
	var attacker := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 8, 30, 1, 9, 8, 3, 5)))
	var target := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 1, 8, 1, 9, 8, 3, 5)))
	var ctx := CombatFixtures.make_context(attacker, target, 1)
	var rest := CombatDecision.new()
	rest.type = Enums.ActionType.DEFEND
	CombatResolver.execute(attacker, target, ctx, rest)
	assert_eq(attacker.actions_taken, 1)
	assert_eq(attacker.hits_landed, 0, "defend is filler, not a landed strike")
	var strike := CombatDecision.new()
	strike.type = Enums.ActionType.ATTACK
	for _i in 12:
		if CombatAction.is_valid(Enums.ActionType.ATTACK, attacker, ctx):
			CombatResolver.execute(attacker, target, ctx, strike)
	assert_true(attacker.hits_landed > 0, "a 30-attack fighter lands strikes")
	assert_true(attacker.hits_landed < attacker.actions_taken,
			"the defend never counts as a hit")
	attacker.free()
	target.free()


# --- XP effectiveness --------------------------------------------------------

func test_effectiveness_bounds() -> void:
	assert_eq(ProgressionCalculator.combat_effectiveness(0, 0), 1.0,
			"no tally -> neutral")
	assert_eq(ProgressionCalculator.combat_effectiveness(0, 10), 0.65,
			"pure stalling bottoms at 0.65")
	assert_eq(ProgressionCalculator.combat_effectiveness(10, 10), 1.25,
			"every action a landed strike caps at 1.25")


func test_xp_rises_with_real_fighting() -> void:
	var stalled: int = ProgressionCalculator.xp_reward(CONFIG, 3, 3, true, 1, 20)
	var neutral: int = ProgressionCalculator.xp_reward(CONFIG, 3, 3, true)
	var fierce: int = ProgressionCalculator.xp_reward(CONFIG, 3, 3, true, 9, 12)
	assert_true(stalled < neutral, "stalling must earn less than the neutral rate")
	assert_true(fierce > neutral, "landed blows must earn more")
	assert_true(fierce <= roundi(neutral * 1.3), "the bonus stays modest (owner: no excess)")


func test_champion_win_pays_anchor_xp() -> void:
	var normal := CombatResult.new()
	normal.player_won = true
	normal.enemy_level = 5
	var champion := CombatResult.new()
	champion.player_won = true
	champion.enemy_level = 5
	champion.champion_id = &"character.champion_maulhilda"
	var profile_a := PlayerProfile.create_default()
	var profile_b := PlayerProfile.create_default()
	var reward_a := ProgressionService.apply_combat_rewards(profile_a, CONFIG, ECONOMY, normal)
	var reward_b := ProgressionService.apply_combat_rewards(profile_b, CONFIG, ECONOMY, champion)
	assert_eq(reward_b.xp_gained, roundi(reward_a.xp_gained * CONFIG.champion_xp_multiplier),
			"champion final pays the anchor multiplier")


# --- The arena's call (forced tournament) ------------------------------------

func test_tournament_required_gating() -> void:
	var saved_profile: PlayerProfile = GameManager.profile
	var profile := PlayerProfile.create_default()
	GameManager.profile = profile
	var arena: ArenaData = GameManager.selected_arena()
	var midpoint: int = roundi(lerpf(arena.min_level, arena.max_level, 0.5))

	profile.victories = GameManager.TOURNAMENT_UNLOCK_VICTORIES
	profile.level = midpoint - 1
	assert_false(GameManager.tournament_required(),
			"below the band midpoint the arena stays quiet")
	profile.level = midpoint
	assert_true(GameManager.tournament_required(),
			"at the midpoint with the tournament open, the call is binding")
	profile.victories = GameManager.TOURNAMENT_UNLOCK_VICTORIES - 1
	assert_false(GameManager.tournament_required(),
			"a locked tournament can never be required")
	profile.victories = GameManager.TOURNAMENT_UNLOCK_VICTORIES
	profile.completed_tournament_arena_ids.append(arena.id)
	assert_false(GameManager.tournament_required(),
			"a completed bracket never calls again")
	GameManager.profile = saved_profile


func test_tournament_completion_pays_house_bonus() -> void:
	var saved_profile: PlayerProfile = GameManager.profile
	var profile := PlayerProfile.create_default()
	profile.level = 6
	GameManager.profile = profile
	GameManager.tournament_arena_id = &"arena.gravelmaw"
	GameManager.tournament_round = GameManager.TOURNAMENT_ROUNDS - 1
	GameManager.tournament_fight_pending = true
	var result := CombatResult.new()
	result.player_won = true
	result.enemy_level = 7
	result.champion_id = &"character.champion_maulhilda"
	GameManager.last_combat_result = result
	var gold_before: int = profile.gold
	var reward: ProgressionService.RewardResult = GameManager.consume_combat_rewards()
	assert_true(GameManager.tournament_completed)
	assert_eq(reward.tournament_bonus_gold, ECONOMY.tournament_gold_bonus,
			"completing the bracket pays the house bonus")
	assert_eq(profile.gold - gold_before, reward.gold_gained,
			"profile gold moves by exactly the reported reward")
	GameManager.last_combat_result = null
	GameManager.abandon_tournament()
	GameManager.profile = saved_profile


# --- Elite brackets ----------------------------------------------------------

func test_elite_opponents_get_better_gear_tier() -> void:
	RngService.set_seed(4321)
	for _i in 8:
		var normal: CharacterData = OpponentGenerator.generate_at_level(5)
		assert_true(normal.weapon.tier <= 2, "level 5 normal gear caps at T2")
		var elite: CharacterData = OpponentGenerator.generate_at_level(5, true)
		assert_true(elite.weapon.tier <= 3, "level 5 elite gear caps at T3")
		assert_true(elite.skills.size() >= 1, "elites always bring skills")
