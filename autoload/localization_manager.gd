extends Node
## Locale management (charter §29). English + Turkish from day one.
## Player-visible strings ALWAYS go through translation keys — never
## hardcode display text in scenes or scripts.

const SUPPORTED_LOCALES: PackedStringArray = ["en", "tr"]
const DEFAULT_LOCALE: String = "en"

signal locale_changed(locale: String)


func _ready() -> void:
	var saved: String = SaveManager.get_setting("locale", "")
	if saved != "" and SUPPORTED_LOCALES.has(saved):
		set_locale(saved)
	else:
		var os_locale: String = OS.get_locale_language()
		set_locale(os_locale if SUPPORTED_LOCALES.has(os_locale) else DEFAULT_LOCALE)


func set_locale(locale: String) -> void:
	assert(SUPPORTED_LOCALES.has(locale), "Unsupported locale: %s" % locale)
	TranslationServer.set_locale(locale)
	SaveManager.set_setting("locale", locale)
	locale_changed.emit(locale)


func get_locale() -> String:
	return TranslationServer.get_locale().substr(0, 2)


## Cycles to the next supported locale (used by the simple language toggle
## until a full settings screen exists).
func cycle_locale() -> void:
	var index: int = SUPPORTED_LOCALES.find(get_locale())
	var next: String = SUPPORTED_LOCALES[(index + 1) % SUPPORTED_LOCALES.size()]
	set_locale(next)
