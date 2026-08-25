extends Control
## Settings (charter §28 accessibility): volume sliders per bus, language,
## screen-shake intensity, reduced-effects and blood toggles. Values persist via
## SaveManager settings; consumers read them live (controller shake,
## CombatVfx particle counts). Key-remap UI is still an open item — combat
## is fully pointer/touch driven and no gameplay key bindings exist yet
## (tracked in PROJECT_STATE).

const VOLUME_BUSES: PackedStringArray = ["Master", "Music", "SFX"]

var _volume_sliders: Dictionary = {}

@onready var _title: Label = %TitleLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _back: Button = %BackButton


func _ready() -> void:
	_title.text = tr("settings.title")
	_back.text = tr("common.back")
	_back.pressed.connect(SceneRouter.goto_main_menu)

	for bus in VOLUME_BUSES:
		var slider := _add_slider_row(tr("settings.volume_%s" % bus.to_lower()),
				AudioManager.get_bus_volume(bus) * 100.0)
		slider.value_changed.connect(func(value: float) -> void:
			AudioManager.set_bus_volume(bus, value / 100.0))
		_volume_sliders[bus] = slider

	var shake := _add_slider_row(tr("settings.screen_shake"),
			float(SaveManager.get_setting(CombatController.SHAKE_SETTING, 100)),
			"ScreenShakeSlider")
	shake.value_changed.connect(func(value: float) -> void:
		SaveManager.set_setting(CombatController.SHAKE_SETTING, int(value)))

	# Camera motion (V2 §51): 0 pins the classic static duel frame for
	# players sensitive to the follow/zoom/push-in. Applies from the next
	# fight, like the other combat-presentation settings.
	var camera := _add_slider_row(tr("settings.camera_motion"),
			float(SaveManager.get_setting(
					CombatCamera.MOTION_SETTING, CombatCamera.MOTION_DEFAULT)),
			"CameraMotionSlider")
	camera.value_changed.connect(func(value: float) -> void:
		SaveManager.set_setting(CombatCamera.MOTION_SETTING, int(value)))

	_add_check_row(tr("settings.reduced_fx"),
			bool(SaveManager.get_setting(CombatFeel.REDUCED_FX_SETTING, false)),
			func(pressed: bool) -> void:
				SaveManager.set_setting(CombatFeel.REDUCED_FX_SETTING, pressed),
			"ReducedFxCheck")

	# Charter §25/§30: blood is its own toggle. Turning effects down should not
	# be the only way to stop the spray, and stopping the spray should not
	# flatten every other effect in the fight.
	_add_check_row(tr("settings.blood"),
			CombatVfx.blood_enabled(),
			func(pressed: bool) -> void:
				SaveManager.set_setting(CombatVfx.BLOOD_SETTING, pressed),
			"BloodCheck")

	var language := Button.new()
	language.text = tr("menu.language")
	language.custom_minimum_size = Vector2(280, 52)
	language.pressed.connect(func() -> void:
		LocalizationManager.cycle_locale()
		SceneRouter.goto_settings())  # rebuild with the new locale
	_rows.add_child(language)


## `node_name` makes the control findable by name — the accessibility
## settings have end-to-end tests that drive the real widget.
func _add_slider_row(label_text: String, initial: float, node_name: String = "") -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_rows.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(240, 0)
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = initial
	slider.custom_minimum_size = Vector2(320, 44)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if node_name != "":
		slider.name = node_name
	row.add_child(slider)
	return slider


func _add_check_row(label_text: String, initial: bool, on_toggled: Callable,
		node_name: String = "") -> void:
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = initial
	check.custom_minimum_size = Vector2(0, 44)
	check.add_theme_font_size_override("font_size", 18)
	check.toggled.connect(on_toggled)
	if node_name != "":
		check.name = node_name
	_rows.add_child(check)
