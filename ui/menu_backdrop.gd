class_name MenuBackdrop
extends Control
## Backdrop for the front-end screens. When the painting named by `art_key`
## is installed it is drawn cover-fitted behind the screen; when it is not,
## the original DRAWN dusk-arena silhouette takes over — tiered stands, arched
## gates, pennants under a warm horizon glow, with two guttering torches.
## Either way the drifting dust and the floor wash ride on top, so the
## front-end is never a still image.
##
## Boundaries: pure decoration. It draws nothing gameplay-relevant, uses a
## LOCAL fixed-seed RNG (never RngService, so no seeded replay can be
## disturbed), and honours `reduced_fx` by dropping the animated layers.
## Compatibility-renderer safe: primitives only, no shaders.

## Design-space box the silhouette is composed for; it scales to fit.
const DESIGN := Vector2(1280.0, 720.0)

## Which painting in `ArtLibrary.ui` this screen wears. Set before the node
## enters the tree (or via `install`).
@export var art_key: StringName = &"backdrop_menu"

const SKY_TOP := Color(0.20, 0.13, 0.25)
const SKY_LOW := Color(0.33, 0.18, 0.24)
const GLOW := Color(0.98, 0.62, 0.32)
const STONE_FAR := Color(0.13, 0.09, 0.16)
const STONE_NEAR := Color(0.08, 0.06, 0.11)
const TORCH_CORE := Color(1.0, 0.85, 0.45)

const MOTE_COUNT: int = 46
const TORCH_X: PackedFloat32Array = [150.0, 1130.0]

var _time: float = 0.0
var _motes: Array[Vector3] = []
## Per-mote drift speed/size, parallel to `_motes` (x=speed, y=radius, z=phase).
var _mote_traits: Array[Vector3] = []
var _animated: bool = true
## Smooth vertical gradients, built once. Stacked translucent BANDS would
## double-blend at every seam once the whole backdrop is dimmed on the quieter
## screens, drawing visible hairlines across them.
var _sky: GradientTexture2D = null
var _floor_shade: GradientTexture2D = null
## The painting for `art_key`, or null when the art is not installed.
var _painting: Texture2D = null


## Drops a backdrop in behind an existing screen — for the screens composed
## against a flat `Background` ColorRect rather than an editor-placed backdrop.
##
## That flat fill would sit on top and hide the art, so it is turned down to
## `wash` alpha and becomes the readability scrim over the painting instead.
## Screens with no such node simply get the backdrop at the bottom.
static func install(root: Control, key: StringName,
		wash: float = 0.55) -> MenuBackdrop:
	var backdrop := MenuBackdrop.new()
	backdrop.art_key = key
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.name = "PaintedBackdrop"
	root.add_child(backdrop)
	root.move_child(backdrop, 0)
	var fill := root.get_node_or_null(^"Background") as ColorRect
	if fill != null:
		fill.color = Color(fill.color, wash)
	return backdrop


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painting = ArtLibrary.ui(art_key)
	_sky = _vertical_gradient([SKY_TOP, SKY_LOW])
	_floor_shade = _vertical_gradient(
			[Color(0.03, 0.02, 0.05, 0.0), Color(0.03, 0.02, 0.05, 0.55)])
	_animated = not bool(SaveManager.get_setting(CombatFeel.REDUCED_FX_SETTING, false))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260825  # fixed: the backdrop looks the same every launch
	for i in MOTE_COUNT:
		_motes.append(Vector3(rng.randf_range(-40.0, DESIGN.x + 40.0),
				rng.randf_range(120.0, DESIGN.y), 0.0))
		_mote_traits.append(Vector3(rng.randf_range(4.0, 16.0),
				rng.randf_range(1.0, 2.6), rng.randf_range(0.0, TAU)))
	set_process(_animated)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	for i in _motes.size():
		var mote: Vector3 = _motes[i]
		mote.y -= _mote_traits[i].x * delta
		if mote.y < 100.0:
			mote.y = DESIGN.y + 20.0
		_motes[i] = mote
	queue_redraw()


func _draw() -> void:
	# Everything is composed in design space, then scaled to the real size —
	# the backdrop fills any aspect ratio without stretching the silhouette.
	var scale_factor: float = maxf(size.x / DESIGN.x, size.y / DESIGN.y)
	var offset := (size - DESIGN * scale_factor) * 0.5
	draw_set_transform(offset, 0.0, Vector2(scale_factor, scale_factor))

	if _painting != null:
		_draw_painting()
	else:
		_draw_sky()
		_draw_stands(392.0, 0.75, STONE_FAR)
		_draw_stands(492.0, 1.0, STONE_NEAR)
		_draw_torches()
	if _animated:
		_draw_motes()
	_draw_floor_shadow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Cover-fits the painting inside the design box: the art is 16:9 and the box
## is 16:9, so this is an exact fill at the reference ratio and a centred crop
## at anything else.
func _draw_painting() -> void:
	var art: Vector2 = _painting.get_size()
	if art.x <= 0.0 or art.y <= 0.0:
		return
	var cover: float = maxf(DESIGN.x / art.x, DESIGN.y / art.y)
	var drawn: Vector2 = art * cover
	draw_texture_rect(_painting,
			Rect2((DESIGN - drawn) * 0.5, drawn), false)


func _draw_sky() -> void:
	draw_texture_rect(_sky, Rect2(-200, -200, DESIGN.x + 400, DESIGN.y + 240), false)
	# Low sun sinking behind the arena: three stacked haloes, no shader.
	for i in 3:
		var radius: float = 320.0 - i * 95.0
		draw_circle(Vector2(DESIGN.x * 0.5, 430.0), radius,
				Color(GLOW.r, GLOW.g, GLOW.b, 0.06 + i * 0.05))


## One tier of stands: a stone band pierced by arches, topped with pennants.
func _draw_stands(top: float, depth: float, tint: Color) -> void:
	var height: float = 320.0 * depth
	draw_rect(Rect2(-200, top, DESIGN.x + 400, height), tint)
	# Warm rim light on the parapet, kept faint: the backdrop must recede
	# behind the menu, never compete with it.
	draw_rect(Rect2(-200, top, DESIGN.x + 400, 3.0),
			Color(GLOW.r, GLOW.g, GLOW.b, 0.13 * depth))

	var rim: Color = tint.lerp(Color(0.46, 0.30, 0.26), 0.30 * depth)
	var mouth: Color = tint.darkened(0.45)
	var spacing: float = 168.0 * depth
	var radius: float = 40.0 * depth
	var x: float = -60.0
	while x < DESIGN.x + 80.0:
		# Arched opening: dark mouth under a dressed-stone rim.
		var centre := Vector2(x, top + 104.0 * depth)
		draw_circle(centre, radius, mouth)
		draw_rect(Rect2(centre.x - radius, centre.y, radius * 2.0, 96.0 * depth), mouth)
		draw_arc(centre, radius + 2.0, PI, TAU, 14, rim, 2.5 * depth)
		x += spacing

	# Pennants ride the FAR parapet only — near the buttons they read as
	# clutter rather than depth.
	if depth >= 1.0:
		return
	var flag_rng := RandomNumberGenerator.new()
	flag_rng.seed = 8125
	var flag_x: float = -40.0
	while flag_x < DESIGN.x + 60.0:
		var sway: float = sin(_time * 1.4 + flag_x * 0.03) * 4.0 * depth
		var cloth := Color.from_hsv(flag_rng.randf(), 0.45, 0.34, 0.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(flag_x, top - 1.0),
			Vector2(flag_x + 20.0 * depth + sway, top + 8.0 * depth),
			Vector2(flag_x, top + 19.0 * depth),
		]), cloth)
		flag_x += 240.0 * depth


## Guttering torches flanking the title. The flicker is time-based, not
## random, so two launches look identical.
func _draw_torches() -> void:
	for i in TORCH_X.size():
		var base := Vector2(TORCH_X[i], 470.0)
		var flicker: float = 1.0 + 0.12 * sin(_time * 7.0 + i * 2.1) \
				+ 0.06 * sin(_time * 11.3 + i)
		if not _animated:
			flicker = 1.0
		# Bracket
		draw_rect(Rect2(base.x - 4.0, base.y, 8.0, 64.0), Color(0.13, 0.09, 0.08))
		# Halo, then the flame body, then the hot core
		draw_circle(base, 84.0 * flicker, Color(GLOW.r, GLOW.g, GLOW.b, 0.07))
		draw_circle(base, 44.0 * flicker, Color(GLOW.r, GLOW.g, GLOW.b, 0.11))
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - 13.0, base.y + 6.0),
			Vector2(base.x, base.y - 46.0 * flicker),
			Vector2(base.x + 13.0, base.y + 6.0),
		]), Color(0.95, 0.45, 0.18, 0.9))
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - 6.0, base.y + 4.0),
			Vector2(base.x, base.y - 26.0 * flicker),
			Vector2(base.x + 6.0, base.y + 4.0),
		]), TORCH_CORE)


func _draw_motes() -> void:
	for i in _motes.size():
		var mote: Vector3 = _motes[i]
		var traits: Vector3 = _mote_traits[i]
		var drift: float = sin(_time * 0.6 + traits.z) * 14.0
		var fade: float = clampf((DESIGN.y - mote.y) / DESIGN.y, 0.0, 1.0)
		draw_circle(Vector2(mote.x + drift, mote.y), traits.y,
				Color(0.99, 0.86, 0.66, 0.06 + 0.16 * fade))


## A soft dark wash along the bottom so the menu buttons read against the
## stands instead of fighting them.
func _draw_floor_shadow() -> void:
	draw_texture_rect(_floor_shade,
			Rect2(-200, DESIGN.y - 190.0, DESIGN.x + 400, 200.0), false)


## A 1 x 128 vertical gradient texture from the given stops.
static func _vertical_gradient(stops: Array[Color]) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray(stops)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 1
	texture.height = 128
	return texture
