extends TestCase
## SaveManager profile persistence: roundtrip, corruption, versioning,
## migration chain (charter §31 — old saves must never break).

const TEST_PATH: String = "user://test_save_slot.json"


func _with_test_path(callable: Callable) -> void:
	var original: String = SaveManager.profile_path
	var original_writes: bool = SaveManager.disk_writes_enabled
	SaveManager.profile_path = TEST_PATH
	SaveManager.disk_writes_enabled = true
	callable.call()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	SaveManager.profile_path = original
	SaveManager.disk_writes_enabled = original_writes


func test_save_load_roundtrip() -> void:
	_with_test_path(func() -> void:
		var profile := PlayerProfile.create_default()
		profile.character_name = "Rondo"
		profile.level = 4
		profile.gold = 99
		assert_true(SaveManager.save_profile(profile))
		assert_true(SaveManager.has_profile())
		var loaded: PlayerProfile = SaveManager.load_profile()
		assert_true(loaded != null)
		assert_eq(loaded.character_name, "Rondo")
		assert_eq(loaded.level, 4)
		assert_eq(loaded.gold, 99)
	)


func test_corrupt_file_returns_null() -> void:
	_with_test_path(func() -> void:
		var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
		file.store_string("this is { not json !!")
		file.close()
		assert_eq(SaveManager.load_profile(), null)
	)


func test_newer_version_is_rejected() -> void:
	_with_test_path(func() -> void:
		var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify({
			"save_version": SaveManager.SAVE_VERSION + 1,
			"profile": {"character_name": "FromTheFuture"},
		}))
		file.close()
		assert_eq(SaveManager.load_profile(), null,
				"saves from newer game versions must be refused, never guessed")
	)


func test_v0_save_migrates() -> void:
	_with_test_path(func() -> void:
		# v0 = pre-versioning dev format: bare profile fields, no envelope.
		var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify({
			"character_name": "Oldtimer",
			"level": 3,
		}))
		file.close()
		var loaded: PlayerProfile = SaveManager.load_profile()
		assert_true(loaded != null, "v0 saves must migrate, not break")
		assert_eq(loaded.character_name, "Oldtimer")
		assert_eq(loaded.level, 3)
	)


func test_disabled_writes_touch_nothing() -> void:
	_with_test_path(func() -> void:
		SaveManager.disk_writes_enabled = false
		assert_true(SaveManager.save_profile(PlayerProfile.create_default()),
				"disabled writes still report success (smoke mode parity)")
		assert_false(FileAccess.file_exists(TEST_PATH),
				"no file may be written while writes are disabled")
		SaveManager.disk_writes_enabled = true
	)
