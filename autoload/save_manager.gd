extends Node
## Persistence service (charter §31). Offline-first, local files, no server.
##
## Two responsibilities, two files:
##  - App settings (locale, volumes): user://settings.cfg (ConfigFile).
##  - Player profile: user://save_slot_1.json — versioned JSON with a
##    migration chain. JSON (not serialized Resources) because loading
##    foreign Resource files can execute embedded scripts; JSON cannot.
##
## SAVE VERSIONING IS MANDATORY: bump SAVE_VERSION whenever the persisted
## shape changes AND add a migration step in _MIGRATIONS. Document each
## migration in docs/saves.md. Old saves must never break.

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "settings"
const SAVE_VERSION: int = 1

## Overridable for tests; gameplay always uses the default.
var profile_path: String = "user://save_slot_1.json"

## Smoke tests / CI disable disk writes so headless runs never touch a real
## player's save or settings.
var disk_writes_enabled: bool = true

var _settings := ConfigFile.new()
var _loaded: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--smoke-test"):
		disk_writes_enabled = false
	_load_settings()


# --- Settings ---------------------------------------------------------------

func get_setting(key: String, default_value: Variant = null) -> Variant:
	_load_settings()
	return _settings.get_value(SETTINGS_SECTION, key, default_value)


func set_setting(key: String, value: Variant) -> void:
	_load_settings()
	_settings.set_value(SETTINGS_SECTION, key, value)
	if not disk_writes_enabled:
		return
	var err: Error = _settings.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SaveManager: failed to save settings (%s)" % error_string(err))


func _load_settings() -> void:
	if _loaded:
		return
	# A missing file on first launch is expected — not an error.
	_settings.load(SETTINGS_PATH)
	_loaded = true


# --- Player profile ---------------------------------------------------------

func has_profile() -> bool:
	return FileAccess.file_exists(profile_path)


## Returns true on success (or when writes are disabled — the game must keep
## behaving identically in smoke mode).
func save_profile(profile: PlayerProfile) -> bool:
	if not disk_writes_enabled:
		return true
	var payload: Dictionary = {
		"save_version": SAVE_VERSION,
		"profile": profile.to_dict(),
	}
	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot open %s for writing (%s)"
				% [profile_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


## Returns null when no save exists, the file is corrupt, or the save comes
## from a NEWER game version (never guess forward).
func load_profile() -> PlayerProfile:
	if not has_profile():
		return null
	var file := FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot open %s (%s)"
				% [profile_path, error_string(FileAccess.get_open_error())])
		return null
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file is corrupt, ignoring it")
		return null
	var payload: Dictionary = parsed
	var version: int = int(payload.get("save_version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: save is from a newer game version (%d > %d)"
				% [version, SAVE_VERSION])
		return null
	payload = _migrate(payload, version)
	if payload.is_empty():
		return null
	return PlayerProfile.from_dict(payload.get("profile", {}))


func delete_profile() -> void:
	if not disk_writes_enabled:
		return
	if has_profile():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))


## Applies migration steps sequentially until the payload reaches
## SAVE_VERSION. Each step upgrades exactly one version. Returns {} when no
## migration path exists (treated as unreadable).
func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	var version: int = from_version
	while version < SAVE_VERSION:
		match version:
			0:
				payload = _migrate_v0_to_v1(payload)
			_:
				push_warning("SaveManager: no migration path from save_version %d" % version)
				return {}
		version += 1
		payload["save_version"] = version
	return payload


## v0 = pre-versioning dev saves (bare profile dict, no envelope).
static func _migrate_v0_to_v1(payload: Dictionary) -> Dictionary:
	if not payload.has("profile"):
		var profile_fields: Dictionary = payload.duplicate()
		profile_fields.erase("save_version")
		payload = {"profile": profile_fields}
	return payload
