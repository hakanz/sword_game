class_name UITheme
## Global UI theme (applied to the root window at boot). One place for the
## whole game's look: warm arena-sand accents on deep purple-brown.
##
## Buttons and panels wear the painted bronze plates when that art is
## installed, nine-sliced so they stretch to any control size; without it the
## same colours are drawn as flat rounded boxes, which is exactly what the game
## looked like before. Colours are shared by both paths, so the two never drift
## apart (charter §27).

const BG_PANEL := Color(0.16, 0.12, 0.2, 0.92)
const BG_PANEL_BORDER := Color(0.42, 0.33, 0.5, 0.8)
const BTN_NORMAL := Color(0.27, 0.2, 0.34)
const BTN_HOVER := Color(0.36, 0.27, 0.45)
const BTN_PRESSED := Color(0.2, 0.14, 0.26)
const BTN_DISABLED := Color(0.2, 0.18, 0.24, 0.6)
const BTN_BORDER := Color(0.55, 0.44, 0.65, 0.9)
const ACCENT := Color(0.93, 0.76, 0.35)
const TEXT := Color(0.94, 0.92, 0.96)
const TEXT_DIM := Color(0.62, 0.58, 0.68)
const BAR_BG := Color(0.1, 0.08, 0.13, 0.9)

## Nine-slice borders of the painted plates, in source pixels. These also set
## each control's MINIMUM size (Godot will not slice a box smaller than its
## own borders), so they are kept tight: the button plate ships at 128x64
## precisely so a stepper button stays a stepper button.
const BUTTON_SLICE := Vector2(17, 13)
const PANEL_SLICE: float = 30.0


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16

	# --- Buttons ---
	theme.set_stylebox("normal", "Button",
			_plate(&"button_normal", BTN_NORMAL, Color.WHITE))
	theme.set_stylebox("hover", "Button",
			_plate(&"button_hover", BTN_HOVER, Color.WHITE))
	theme.set_stylebox("pressed", "Button",
			_plate(&"button_pressed", BTN_PRESSED, Color.WHITE))
	# Disabled reuses the normal plate, drained of colour.
	theme.set_stylebox("disabled", "Button",
			_plate(&"button_normal", BTN_DISABLED, Color(0.55, 0.52, 0.58, 0.7),
					false))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)

	# --- Panels ---
	theme.set_stylebox("panel", "PanelContainer", _panel_box())

	# --- Progress bars (fill colors set per-bar in code) ---
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = BAR_BG
	bar_bg.set_corner_radius_all(5)
	bar_bg.set_border_width_all(1)
	bar_bg.border_color = Color(0, 0, 0, 0.5)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill(ACCENT))

	# --- Labels / inputs ---
	theme.set_color("font_color", "Label", TEXT)
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0.11, 0.09, 0.15)
	line.set_corner_radius_all(8)
	line.set_border_width_all(1)
	line.border_color = BG_PANEL_BORDER
	line.set_content_margin_all(10)
	theme.set_stylebox("normal", "LineEdit", line)
	var line_focus: StyleBoxFlat = line.duplicate()
	line_focus.border_color = ACCENT
	theme.set_stylebox("focus", "LineEdit", line_focus)
	theme.set_color("font_color", "LineEdit", TEXT)

	# --- Rich text (combat log) ---
	theme.set_color("default_color", "RichTextLabel", Color(0.88, 0.85, 0.9))

	return theme


## Circular stylebox for radial action buttons ("normal"/"hover"/"pressed"/
## "disabled").
static func round_button_box(state: String) -> StyleBoxFlat:
	var color: Color
	match state:
		"hover": color = BTN_HOVER
		"pressed": color = BTN_PRESSED
		"disabled": color = BTN_DISABLED
		_: color = BTN_NORMAL
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(29)
	box.set_border_width_all(2)
	box.border_color = ACCENT if state == "hover" else BTN_BORDER
	if state == "disabled":
		box.border_color = Color(BTN_BORDER, 0.4)
	return box


## Rounded fill stylebox for a ProgressBar in the given color.
static func bar_fill(color: Color) -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	return fill


## A button face: the painted plate when it exists, the flat box when it does
## not. `tint` colours the art; `color` colours the flat fallback.
static func _plate(art_key: StringName, color: Color, tint: Color,
		bordered: bool = true) -> StyleBox:
	var texture: Texture2D = ArtLibrary.ui(art_key)
	if texture == null:
		return _button_box(color, bordered)
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = tint
	box.texture_margin_left = BUTTON_SLICE.x
	box.texture_margin_right = BUTTON_SLICE.x
	box.texture_margin_top = BUTTON_SLICE.y
	box.texture_margin_bottom = BUTTON_SLICE.y
	box.content_margin_left = 13.0
	box.content_margin_right = 13.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


## A panel face: the painted stone plate when it exists, the flat box when not.
static func _panel_box() -> StyleBox:
	var texture: Texture2D = ArtLibrary.ui(&"panel_stone")
	if texture != null:
		var box := StyleBoxTexture.new()
		box.texture = texture
		box.modulate_color = Color(1.0, 1.0, 1.0, 0.94)
		box.texture_margin_left = PANEL_SLICE
		box.texture_margin_right = PANEL_SLICE
		box.texture_margin_top = PANEL_SLICE
		box.texture_margin_bottom = PANEL_SLICE
		box.set_content_margin_all(17.0)
		return box
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG_PANEL
	panel.set_corner_radius_all(10)
	panel.set_border_width_all(1)
	panel.border_color = BG_PANEL_BORDER
	panel.set_content_margin_all(6)
	return panel


static func _button_box(color: Color, bordered: bool = true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(10)
	if bordered:
		box.set_border_width_all(1)
		box.border_color = BTN_BORDER
	box.set_content_margin_all(8)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_corner_radius_all(10)
	box.set_border_width_all(2)
	box.border_color = ACCENT
	return box
