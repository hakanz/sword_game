extends Control
## Post-battle results (POST_BATTLE state). Reads GameManager.last_combat_result,
## applies progression rewards exactly once via GameManager, and shows them.

@onready var _title: Label = %TitleLabel
@onready var _rounds: Label = %RoundsLabel
@onready var _damage: Label = %DamageLabel
@onready var _xp: Label = %XPLabel
@onready var _level_up: Label = %LevelUpLabel
@onready var _points: Label = %PointsLabel
@onready var _next_duel: Button = %NextDuelButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.text = tr("results.back_to_menu")
	_next_duel.text = tr("results.next_duel")
	_back.pressed.connect(_on_back_pressed)
	_next_duel.pressed.connect(_on_next_duel_pressed)

	var result: CombatResult = GameManager.last_combat_result
	if result == null:
		# Scene run standalone from the editor — nothing to show.
		_title.text = "—"
		_rounds.text = ""
		_damage.text = ""
		_xp.text = ""
		_level_up.visible = false
		_points.visible = false
		_next_duel.visible = false
		return

	_title.text = tr("results.victory") if result.player_won else tr("results.defeat")
	_title.add_theme_color_override("font_color",
			Color(1.0, 0.84, 0.3) if result.player_won else Color(0.85, 0.35, 0.3))
	_rounds.text = tr("results.rounds").format({"rounds": result.rounds})
	_damage.text = tr("results.damage_dealt").format({"damage": result.player_damage_dealt})

	var reward: ProgressionService.RewardResult = GameManager.consume_combat_rewards()
	_xp.visible = reward != null
	_level_up.visible = reward != null and reward.levels_gained > 0
	_points.visible = _level_up.visible
	_next_duel.visible = GameManager.profile != null
	if reward != null:
		_xp.text = tr("results.xp_gained").format({"xp": reward.xp_gained})
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


func _on_back_pressed() -> void:
	GameManager.last_combat_result = null
	SceneRouter.goto_main_menu()


func _on_next_duel_pressed() -> void:
	GameManager.start_next_duel()
