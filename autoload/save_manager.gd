extends Node
## Persistence service (charter §31).
##
## CURRENT SCOPE (Phase 1-2): app settings only (locale, volumes) in
## user://settings.cfg. Character save slots with save_version + migration
## arrive with the progression phase — do not bolt ad-hoc character
## persistence on top of settings.
##
## Offline-first: everything is local; zero server dependency.

const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "settings"

var _settings := ConfigFile.new()
var _loaded: bool = false


func _ready() -> void:
	_load_settings()


func get_setting(key: String, default_value: Variant = null) -> Variant:
	_load_settings()
	return _settings.get_value(SETTINGS_SECTION, key, default_value)


func set_setting(key: String, value: Variant) -> void:
	_load_settings()
	_settings.set_value(SETTINGS_SECTION, key, value)
	var err: Error = _settings.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SaveManager: failed to save settings (%s)" % error_string(err))


func _load_settings() -> void:
	if _loaded:
		return
	# A missing file on first launch is expected — not an error.
	_settings.load(SETTINGS_PATH)
	_loaded = true
