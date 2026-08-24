extends Control
## Post-battle results (POST_BATTLE state). Reads GameManager.last_combat_result.
## Reward display (XP/gold) attaches here in the progression phase — no fake
## reward numbers before that (charter §41.5).

@onready var _title: Label = %TitleLabel
@onready var _rounds: Label = %RoundsLabel
@onready var _damage: Label = %DamageLabel
@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.text = tr("results.back_to_menu")
	_back.pressed.connect(_on_back_pressed)

	var result: CombatResult = GameManager.last_combat_result
	if result == null:
		# Scene run standalone from the editor — nothing to show.
		_title.text = "—"
		_rounds.text = ""
		_damage.text = ""
		return

	_title.text = tr("results.victory") if result.player_won else tr("results.defeat")
	_title.add_theme_color_override("font_color",
			Color(1.0, 0.84, 0.3) if result.player_won else Color(0.85, 0.35, 0.3))
	_rounds.text = tr("results.rounds").format({"rounds": result.rounds})
	_damage.text = tr("results.damage_dealt").format({"damage": result.player_damage_dealt})

	if GameManager.smoke_test:
		var ok: bool = result.rounds >= 1
		print("SMOKE TEST %s: winner=%s rounds=%d player_damage=%d seed=%d" % [
			"OK" if ok else "FAILED",
			result.victor_name, result.rounds, result.player_damage_dealt,
			RngService.current_seed,
		])
		get_tree().quit(0 if ok else 1)


func _on_back_pressed() -> void:
	GameManager.last_combat_result = null
	SceneRouter.goto_main_menu()
