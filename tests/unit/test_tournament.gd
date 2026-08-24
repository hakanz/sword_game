extends TestCase
## Arena regions + tournament flow (charter §21): unlock gating, round
## progression, completion persistence, forfeits. Routing is not exercised
## here (scene changes need a live tree) — GameManager's logic is.

const CONFIG: ProgressionConfig = preload("res://data/progression/progression_config.tres")


func _with_game_state(callable: Callable) -> void:
	var prev_profile: PlayerProfile = GameManager.profile
	var prev_writes: bool = SaveManager.disk_writes_enabled
	SaveManager.disk_writes_enabled = false
	GameManager.profile = PlayerProfile.create_default()
	GameManager.abandon_tournament()
	GameManager.last_combat_result = null
	GameManager.last_reward = null
	callable.call()
	GameManager.profile = prev_profile
	GameManager.abandon_tournament()
	GameManager.last_combat_result = null
	GameManager.last_reward = null
	SaveManager.disk_writes_enabled = prev_writes


func _fight_result(won: bool, champion_id: StringName = &"") -> CombatResult:
	var result := CombatResult.new()
	result.player_won = won
	result.enemy_level = 3
	result.champion_id = champion_id
	return result


func test_registry_arenas_ordered_with_champions() -> void:
	var arenas := ItemDB.all_arenas()
	assert_true(arenas.size() >= 2, "two arena regions expected")
	for index in arenas.size():
		assert_eq(arenas[index].order, index + 1, "arena order must be sequential")
		assert_true(arenas[index].champion != null, "every region needs a champion")
		assert_true(arenas[index].champion.is_champion)


func test_arena_unlock_chain() -> void:
	_with_game_state(func() -> void:
		var gravelmaw: ArenaData = ItemDB.arena(&"arena.gravelmaw")
		var emberholt: ArenaData = ItemDB.arena(&"arena.emberholt")
		assert_true(GameManager.is_arena_unlocked(gravelmaw), "region 1 is always open")
		assert_false(GameManager.is_arena_unlocked(emberholt), "region 2 starts locked")
		GameManager.profile.completed_tournament_arena_ids.append(gravelmaw.id)
		assert_true(GameManager.is_arena_unlocked(emberholt),
				"winning the previous tournament unlocks the next region")
	)


func test_tournament_unlock_needs_wins() -> void:
	_with_game_state(func() -> void:
		var gravelmaw: ArenaData = ItemDB.arena(&"arena.gravelmaw")
		assert_false(GameManager.is_tournament_unlocked(gravelmaw))
		GameManager.profile.victories = GameManager.TOURNAMENT_UNLOCK_VICTORIES
		assert_true(GameManager.is_tournament_unlocked(gravelmaw))
	)


func test_round_wins_advance_and_final_completes() -> void:
	_with_game_state(func() -> void:
		GameManager.tournament_arena_id = &"arena.gravelmaw"
		GameManager.tournament_round = 0
		GameManager.tournament_fight_pending = true

		GameManager.last_combat_result = _fight_result(true)
		GameManager.consume_combat_rewards()
		assert_true(GameManager.in_tournament(), "one win is not the whole bracket")
		assert_eq(GameManager.tournament_round, 1)
		assert_true(GameManager.tournament_won_round)
		assert_false(GameManager.tournament_completed)

		GameManager.tournament_round = GameManager.TOURNAMENT_ROUNDS - 1
		GameManager.tournament_fight_pending = true
		GameManager.last_combat_result = _fight_result(true, &"character.champion_maulhilda")
		var reward := GameManager.consume_combat_rewards()
		assert_true(GameManager.tournament_completed, "final win completes the tournament")
		assert_false(GameManager.in_tournament())
		assert_true(GameManager.profile.completed_tournament_arena_ids.has(&"arena.gravelmaw"))
		assert_true(reward.champion_defeated, "the final is the champion fight")
		assert_true(GameManager.is_arena_unlocked(ItemDB.arena(&"arena.emberholt")),
				"completion opens the next region")
	)


func test_losing_ends_the_run_without_completion() -> void:
	_with_game_state(func() -> void:
		GameManager.tournament_arena_id = &"arena.gravelmaw"
		GameManager.tournament_round = 2
		GameManager.tournament_fight_pending = true
		GameManager.last_combat_result = _fight_result(false)
		GameManager.consume_combat_rewards()
		assert_true(GameManager.tournament_failed)
		assert_false(GameManager.in_tournament())
		assert_false(GameManager.profile.completed_tournament_arena_ids.has(&"arena.gravelmaw"))
	)


func test_consume_is_idempotent_for_tournaments() -> void:
	_with_game_state(func() -> void:
		GameManager.tournament_arena_id = &"arena.gravelmaw"
		GameManager.tournament_round = 0
		GameManager.tournament_fight_pending = true
		GameManager.last_combat_result = _fight_result(true)
		GameManager.consume_combat_rewards()
		GameManager.consume_combat_rewards()
		assert_eq(GameManager.tournament_round, 1,
				"re-reading results must not advance the bracket twice")
	)


func test_generate_for_arena_respects_band() -> void:
	RngService.set_seed(606)
	var emberholt: ArenaData = ItemDB.arena(&"arena.emberholt")
	for _i in 12:
		var enemy := OpponentGenerator.generate_for_arena(2, emberholt)
		assert_true(enemy.level >= emberholt.min_level,
				"a low-level player still meets region-level foes (%d)" % enemy.level)
		assert_true(enemy.level <= emberholt.max_level)


func test_normal_duels_never_advance_a_bracket() -> void:
	# Review finding (critical): stale tournament state must not let ordinary
	# duels progress or complete the bracket.
	_with_game_state(func() -> void:
		GameManager.tournament_arena_id = &"arena.gravelmaw"
		GameManager.tournament_round = 2
		GameManager.tournament_fight_pending = false  # fight came from start_next_duel
		GameManager.last_combat_result = _fight_result(true)
		GameManager.consume_combat_rewards()
		assert_eq(GameManager.tournament_round, 2,
				"a normal duel win must not advance the bracket")
		assert_false(GameManager.tournament_completed)
	)
