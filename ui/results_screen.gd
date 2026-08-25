extends Control
## Post-battle results (POST_BATTLE state). Reads GameManager.last_combat_result,
## applies progression rewards exactly once via GameManager, and shows them.

@onready var _title: Label = %TitleLabel
@onready var _rounds: Label = %RoundsLabel
@onready var _damage: Label = %DamageLabel
@onready var _xp: Label = %XPLabel
@onready var _gold: Label = %GoldLabel
@onready var _level_up: Label = %LevelUpLabel
@onready var _points: Label = %PointsLabel
@onready var _champion: Label = %ChampionLabel
@onready var _champion_reward: Label = %ChampionRewardLabel
@onready var _tournament: Label = %TournamentLabel
@onready var _next_round: Button = %NextRoundButton
@onready var _next_duel: Button = %NextDuelButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	MenuBackdrop.install(self, &"backdrop_results")
	_back.text = tr("results.back_to_town")
	_next_duel.text = tr("results.next_duel")
	_next_round.text = tr("results.next_round")
	_back.pressed.connect(_on_back_pressed)
	_next_duel.pressed.connect(_on_next_duel_pressed)
	_next_round.pressed.connect(func() -> void: SceneRouter.goto_tournament())

	var result: CombatResult = GameManager.last_combat_result
	if result == null:
		# Scene run standalone from the editor — nothing to show.
		_title.text = "—"
		_rounds.text = ""
		_damage.text = ""
		_xp.text = ""
		_gold.visible = false
		_level_up.visible = false
		_points.visible = false
		_champion.visible = false
		_champion_reward.visible = false
		_tournament.visible = false
		_next_round.visible = false
		_next_duel.visible = false
		return

	_title.text = tr("results.victory") if result.player_won else tr("results.defeat")
	_title.add_theme_color_override("font_color",
			Color(1.0, 0.84, 0.3) if result.player_won else Color(0.85, 0.35, 0.3))
	if not GameManager.smoke_test:
		AudioManager.play(&"victory" if result.player_won else &"defeat")
	_rounds.text = tr("results.rounds").format({"rounds": result.rounds})
	_damage.text = tr("results.damage_dealt").format({"damage": result.player_damage_dealt})

	var reward: ProgressionService.RewardResult = GameManager.consume_combat_rewards()
	_xp.visible = reward != null
	_gold.visible = reward != null
	_level_up.visible = reward != null and reward.levels_gained > 0
	_points.visible = _level_up.visible
	if _level_up.visible and not GameManager.smoke_test:
		# Charter §25 "level-up" VFX: the moment deserves more than a line of
		# text. Rides on the label so it lands wherever the layout puts it.
		_celebrate_level_up.call_deferred()
	_champion.visible = reward != null and reward.champion_defeated
	_champion_reward.visible = _champion.visible and reward.reward_item_id != &""
	if _champion.visible:
		var arena_name: String = ""
		if GameManager.current_arena != null:
			arena_name = tr(GameManager.current_arena.name_key)
		_champion.text = tr("results.champion_defeated").format({"arena": arena_name})
		if _champion_reward.visible:
			var item: WeaponData = ItemDB.weapon(reward.reward_item_id)
			_champion_reward.text = tr("results.champion_reward").format({
				"item": tr(item.name_key),
			})
	# Tournament flow: mid-run offers the next round; completion/failure
	# lines come from the bookkeeping done in consume_combat_rewards().
	var mid_tournament: bool = GameManager.in_tournament() and GameManager.tournament_won_round
	_next_round.visible = mid_tournament
	_tournament.visible = GameManager.tournament_completed or GameManager.tournament_failed
	if GameManager.tournament_completed:
		_tournament.text = tr("results.tournament_complete")
	elif GameManager.tournament_failed:
		_tournament.text = tr("results.tournament_failed")
	_next_duel.visible = GameManager.profile != null and not mid_tournament
	# The arena's call: when the tournament is due, the quick-duel button
	# becomes the summons and routes to the region list.
	if _next_duel.visible and GameManager.tournament_required():
		_next_duel.text = tr("town.tournament_call")
		_next_duel.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3))
	# Rivalry standings (V2 §55): a recurring opponent only matters if the
	# player is told where the score stands after the fight.
	if reward != null and reward.rival_id != &"":
		var profile: PlayerProfile = GameManager.profile
		# That label is hidden unless a bracket just ended — show it, or the
		# standings are written where nobody can read them.
		_tournament.visible = true
		_tournament.text = tr(RivalService.standing_key(profile, reward.rival_id)).format({
			"name": tr("%s.name" % reward.rival_id),
			"margin": absi(RivalService.score(profile, reward.rival_id)),
		})
	if GameManager.tournament_completed and reward != null \
			and reward.tournament_bonus_gold > 0:
		_tournament.text += "\n" + tr("results.tournament_bonus").format({
			"gold": reward.tournament_bonus_gold,
		})
	if reward != null:
		var xp_text: String = tr("results.xp_gained").format({"xp": reward.xp_gained})
		# Effectiveness verdict (session-5): the fight's XP already reflects
		# it — the line just tells the player WHY.
		var effectiveness: float = ProgressionCalculator.combat_effectiveness(
				result.player_hits, result.player_actions)
		if effectiveness >= 1.1:
			xp_text += "  ·  " + tr("results.xp_fierce")
		elif effectiveness <= 0.8:
			xp_text += "  ·  " + tr("results.xp_stalled")
		_xp.text = xp_text
		_gold.text = tr("results.gold_gained").format({"gold": reward.gold_gained})
		if reward.first_victory:
			_gold.text += "\n" + tr("results.first_victory").format(
					{"gold": reward.first_victory_gold})
		if reward.levels_gained > 0:
			_level_up.text = tr("results.level_up").format({"level": reward.new_level})
			_points.text = tr("results.points_gained").format({
				"attr": reward.attribute_points_gained,
				"skill": reward.skill_points_gained,
			})

	if GameManager.smoke_test:
		var profile: PlayerProfile = GameManager.profile
		var ok: bool = result.rounds >= 1 and reward != null and reward.xp_gained > 0
		print("SMOKE TEST %s: winner=%s rounds=%d player_damage=%d xp=%d level=%d seed=%d" % [
			"OK" if ok else "FAILED",
			result.victor_name, result.rounds, result.player_damage_dealt,
			reward.xp_gained if reward != null else -1,
			profile.level if profile != null else -1,
			RngService.current_seed,
		])
		get_tree().quit(0 if ok else 1)


## Golden rays and rising motes behind the level-up line.
func _celebrate_level_up() -> void:
	if not is_inside_tree():
		return
	var host := Node2D.new()
	add_child(host)
	move_child(host, get_child_count() - 1)
	CombatVfx.spawn_level_up(host, _level_up.global_position
			+ Vector2(_level_up.size.x * 0.5, _level_up.size.y * 0.5))


func _on_back_pressed() -> void:
	# Walking away mid-bracket forfeits the run (single-sitting rule).
	GameManager.abandon_tournament()
	GameManager.last_combat_result = null
	SceneRouter.goto_town()


func _on_next_duel_pressed() -> void:
	# start_next_duel itself honors the arena's call (routes to the region
	# list when the tournament is due).
	GameManager.start_next_duel()
