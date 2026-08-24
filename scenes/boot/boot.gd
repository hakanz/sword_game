extends Control
## BOOT state: autoloads have self-initialized (settings, locale, audio) by
## the time this scene runs; it only routes onward. In smoke-test mode
## (`--smoke-test` user arg) it creates an in-memory profile (disk writes are
## disabled by SaveManager) and plays a full AI-vs-AI duel — used by CI.

@onready var _loading: Label = %LoadingLabel


func _ready() -> void:
	# Global look for every Control in the game (charter §27: placeholder
	# theme now; a real art-directed theme swaps in via UITheme later).
	get_tree().root.theme = UITheme.build()
	_loading.text = tr("boot.loading")
	# One frame so the loading frame paints before any scene-change hitch.
	await get_tree().process_frame

	# Dev-only visual check: `--screenshot-dir=<dir>` captures the main menu
	# and an arena frame to PNG, then quits (windowed run required).
	var screenshot_dir: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			screenshot_dir = arg.get_slice("=", 1)
	if screenshot_dir != "":
		# Fire-and-forget: the capture must live on GameManager because this
		# boot scene is freed by the very first scene change it triggers.
		GameManager.run_screenshot_capture(screenshot_dir)
		return

	if GameManager.smoke_test:
		GameManager.profile = PlayerProfile.create_default()
		# Give the AI-driven player a skill kit so the smoke run exercises
		# the skill/status path end to end.
		GameManager.profile.known_skill_ids.append_array([
			&"skill.crushing_blow", &"skill.venom_smear", &"skill.war_bellow",
		])
		# `--smoke-weapon=weapon.x` forces the player's weapon (CI archer runs).
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--smoke-weapon="):
				GameManager.profile.weapon_id = StringName(arg.get_slice("=", 1))
				GameManager.profile.known_skill_ids.clear()
		GameManager.start_next_duel()
	else:
		SceneRouter.goto_main_menu()
