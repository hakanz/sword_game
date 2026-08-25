class_name AiDebugOverlay
extends CanvasLayer
## Dev-only AI decision overlay (charter §34, amendment V2 §53.3).
##
## `EventBus.ai_scores_computed` has been firing on every AI decision since the
## AI phase with nothing listening; this is the consumer. It lists each action
## the AI weighed with its utility score, marks the winner, and names the
## fighter's temperament — which is what makes personality and balance work
## debuggable instead of guesswork.
##
## RELEASE SAFETY: it removes itself outright unless this is a debug build or
## the run was launched with `--debug-ai`, so a shipped build carries no hidden
## panel and no per-decision string work. Toggle with F3 (a debug key is fine:
## the touch-first rule covers GAMEPLAY-critical actions, and this is not one).

const TOGGLE_ACTION_KEY: Key = KEY_F3
const MAX_ROWS: int = 12

var _label: Label = null
var _title: Label = null


## Pure gate, unit-tested: dev builds and an explicit flag only.
static func should_enable(debug_build: bool, user_args: PackedStringArray) -> bool:
	return debug_build or user_args.has("--debug-ai")


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not should_enable(OS.is_debug_build(), args):
		queue_free()
		return
	# A dev build gets it available but OUT OF THE WAY; asking for it by flag
	# opens it immediately. Never on top of a screenshot you did not ask for.
	visible = args.has("--debug-ai")
	if not visible:
		print("AI debug overlay ready — press F3 (or run with --debug-ai)")
	layer = 128  # above the HUD
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(12, 150)
	panel.modulate = Color(1, 1, 1, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	box.add_child(_title)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_label)

	EventBus.ai_scores_computed.connect(_on_scores)
	EventBus.combat_started.connect(func(_p: Combatant, _e: Combatant) -> void: _clear())
	_clear()


func _clear() -> void:
	_title.text = "AI debug (F3)"
	_label.text = ""


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_ACTION_KEY:
		visible = not visible


func _on_scores(combatant_name: String, scores: Dictionary) -> void:
	if not visible:
		return
	_title.text = "AI: %s%s" % [combatant_name, _temperament_suffix(combatant_name)]
	_label.text = format_scores(scores)


## Pure formatting: highest score first, winner marked. Split out so the
## overlay's only real logic is testable without a viewport.
static func format_scores(scores: Dictionary, max_rows: int = MAX_ROWS) -> String:
	var rows: Array = []
	for action_name: String in scores:
		rows.append([float(scores[action_name]), action_name])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lines: PackedStringArray = []
	for i in mini(rows.size(), max_rows):
		lines.append("%s %-18s %7.1f" % ["▶" if i == 0 else " ", rows[i][1], rows[i][0]])
	return "\n".join(lines)


## Names the temperament driving the fighter the scores belong to, when it can
## be identified — the whole point of the overlay is telling personalities apart.
func _temperament_suffix(combatant_name: String) -> String:
	var arena := get_tree().current_scene as CombatController
	if arena == null:
		return ""
	for fighter: Combatant in [arena.player, arena.enemy]:
		if fighter != null and fighter.display_name() == combatant_name \
				and fighter.data.personality != null:
			return "  [%s]" % String(fighter.data.personality.id).replace("personality.", "")
	return ""
