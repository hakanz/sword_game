extends Control
## BOOT state: autoloads have self-initialized (settings, locale, audio) by
## the time this scene runs; it only routes onward. In smoke-test mode
## (`--smoke-test` user arg) it creates an in-memory profile (disk writes are
## disabled by SaveManager) and plays a full AI-vs-AI duel — used by CI.

@onready var _loading: Label = %LoadingLabel


func _ready() -> void:
	_loading.text = tr("boot.loading")
	# One frame so the loading frame paints before any scene-change hitch.
	await get_tree().process_frame
	if GameManager.smoke_test:
		GameManager.profile = PlayerProfile.create_default()
		# Give the AI-driven player a skill kit so the smoke run exercises
		# the skill/status path end to end.
		GameManager.profile.known_skill_ids.append_array([
			&"skill.crushing_blow", &"skill.venom_smear", &"skill.war_bellow",
		])
		GameManager.start_next_duel()
	else:
		SceneRouter.goto_main_menu()
