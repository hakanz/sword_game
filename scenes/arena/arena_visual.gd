class_name ArenaVisual
extends Node2D
## Arena backdrop (charter §27). An arena that carries a painted `backdrop`
## draws that, with its `ground_texture` tiled over the fighting sand; an arena
## that carries neither falls back to the original primitive rendering — sky,
## stands with a drawn crowd, brick wall, pen gates, columns and lit sand.
## Both paths are live, so the art is a genuine drop-in replacement.
##
## NOTE: decorative variation uses a LOCAL fixed-seed RNG on purpose —
## visuals must never consume RngService rolls or combat replays would
## diverge for the same combat seed.

## The 1280x720 design frame the whole scene is composed in, over-extended
## sideways so an expanded aspect ratio never shows void at the edges.
const FRAME := Rect2(-360, 0, 2000, 720)
## Sand starts here in design space — everything below is fighting ground.
const GROUND_TOP: float = 503.0
## Rig-space size of one tile of the ground texture. Big: a small tile turns
## into visible repetition the moment the camera pulls back.
const GROUND_TILE: float = 430.0
## Height of the fade that blends the tiled ground into the backdrop's own
## painted floor, so the two never meet on a hard line.
const GROUND_FADE: float = 96.0


var arena: ArenaData = null:
	set(value):
		arena = value
		queue_redraw()


func _ready() -> void:
	# The ground texture is drawn as a tiled rect, which needs repeat on.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Foreground dust hanging in the arena light (session-7 polish). Its own
	# node so the animated layer redraws WITHOUT repainting the whole crowd
	# every frame — the backdrop below is static and expensive.
	add_child(ArenaDust.new())


func _draw() -> void:
	if arena == null:
		return
	if arena.backdrop != null:
		_draw_painted()
		return
	_draw_primitives()


## Painted path: the backdrop is fitted to the design frame by HEIGHT, so the
## horizon and the wall line land where the fighters stand no matter how wide
## the viewport gets, and the sides are covered by stretching the same art out
## to the frame edges.
func _draw_painted() -> void:
	var size: Vector2 = arena.backdrop.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var height: float = FRAME.size.y
	var width: float = height * size.x / size.y
	var left: float = 640.0 - width / 2.0
	# Side fill first: a wide viewport must not reveal the void beside the art.
	draw_rect(Rect2(FRAME.position.x, 0, FRAME.size.x, height),
			arena.sky_color.darkened(0.35))
	draw_texture_rect(arena.backdrop, Rect2(left, 0, width, height), false)

	if arena.ground_texture != null:
		_draw_ground(0.3)
	# Warm pool of light on the duelling oval, tying fighters to the ground.
	draw_set_transform(Vector2(640, 630), 0.0, Vector2(1.0, 0.17))
	draw_circle(Vector2.ZERO, 540.0, Color(1.0, 0.92, 0.72, 0.10))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ground grain over the fighting sand.
##
## On the painted path the backdrop ALREADY contains its own floor, so the
## tile goes on as a low-alpha grain that adds texture underfoot instead of a
## second surface arguing with the painting — anything heavier reads as a rug
## thrown over the arena. On the primitive path there is no painted floor to
## respect, so the same tile is laid down at full strength.
func _draw_ground(opacity: float) -> void:
	var tile: Vector2 = arena.ground_texture.get_size()
	if tile.x <= 0.0 or tile.y <= 0.0:
		return
	var height: float = FRAME.size.y - GROUND_TOP + 240.0
	draw_set_transform(Vector2(FRAME.position.x, GROUND_TOP), 0.0,
			Vector2(GROUND_TILE, GROUND_TILE) / tile)
	draw_texture_rect(arena.ground_texture,
			Rect2(Vector2.ZERO, Vector2(FRAME.size.x, height) * tile / GROUND_TILE),
			true, Color(1, 1, 1, opacity))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Feathered seam: a few darkening bands standing in for a gradient, which
	# the Compatibility renderer gets for free as flat rects.
	for band in 8:
		var t: float = band / 8.0
		draw_rect(Rect2(FRAME.position.x, GROUND_TOP + t * GROUND_FADE,
				FRAME.size.x, GROUND_FADE / 8.0 + 1.0),
				Color(arena.ground_color.darkened(0.4), 0.3 * (1.0 - t) * opacity))


func _draw_primitives() -> void:
	# Oversized rects so aspect "expand" never shows void at any ratio.
	# Simple 4-band sky gradient (Compatibility-safe, no shaders).
	var sky_top: Color = arena.sky_color.lightened(0.22)
	for band in 4:
		var t: float = band / 3.0
		draw_rect(Rect2(-2000, -2000 + band * 560, 5280, 600),
				sky_top.lerp(arena.sky_color.darkened(0.08), t))
	# Low sun disc with haze
	draw_circle(Vector2(990, 150), 96.0, Color(1.0, 0.9, 0.65, 0.18))
	draw_circle(Vector2(990, 150), 58.0, Color(1.0, 0.92, 0.7, 0.5))

	# --- Stands: stepped stone tiers with a DRAWN crowd (depth-shaded) ------
	var stand_top: float = 236.0
	draw_rect(Rect2(-2000, stand_top, 5280, 160), arena.wall_color.lightened(0.06))
	var crowd_rng := RandomNumberGenerator.new()
	crowd_rng.seed = 133742
	var skin_tones: Array[Color] = [
		Color(0.93, 0.76, 0.6), Color(0.85, 0.64, 0.47), Color(0.72, 0.52, 0.36),
		Color(0.55, 0.38, 0.26),
	]
	for row in 3:
		var row_y: float = 262.0 + row * 46.0
		var depth: float = 1.0 - (2 - row) * 0.16  # back rows dimmer & smaller
		var row_scale: float = 0.78 + row * 0.11
		# Stone step under this tier
		draw_rect(Rect2(-2000, row_y + 12, 5280, 34), arena.wall_color.lightened(0.02 + row * 0.045))
		var x: float = -50.0 + 17.0 * (row % 2)
		while x < 1360.0:
			var cloth := Color.from_hsv(crowd_rng.randf(), 0.55, 0.62 * depth)
			var skin: Color = skin_tones[crowd_rng.randi_range(0, skin_tones.size() - 1)] * depth
			var s: float = row_scale
			# Seated body (shoulder taper), head, and the occasional cheer
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 9 * s, row_y + 14 * s), Vector2(x + 9 * s, row_y + 14 * s),
				Vector2(x + 7 * s, row_y - 4 * s), Vector2(x - 7 * s, row_y - 4 * s),
			]), cloth)
			draw_circle(Vector2(x, row_y - 10 * s), 6.5 * s, skin)
			draw_arc(Vector2(x, row_y - 11 * s), 5.5 * s, PI, TAU, 8,
					cloth.darkened(0.3), 3.0 * s)  # simple hair/hood cap
			if crowd_rng.randf() < 0.28:
				var arm_side: float = 1.0 if crowd_rng.randf() < 0.5 else -1.0
				draw_line(Vector2(x + 6 * s * arm_side, row_y + 2 * s),
						Vector2(x + 11 * s * arm_side, row_y - 16 * s), skin, 3.2 * s)
				draw_circle(Vector2(x + 11 * s * arm_side, row_y - 17 * s), 2.6 * s, skin)
			x += crowd_rng.randf_range(30.0, 44.0)

	# Parapet in front of the crowd with pennants
	draw_rect(Rect2(-2000, 384, 5280, 26), arena.wall_color.darkened(0.12))
	draw_rect(Rect2(-2000, 384, 5280, 5), arena.wall_color.lightened(0.2))
	var banner_rng := RandomNumberGenerator.new()
	banner_rng.seed = 4242
	var banner_x: float = -40.0
	while banner_x < 1360.0:
		var tint := Color.from_hsv(banner_rng.randf(), 0.6, 0.8)
		draw_rect(Rect2(banner_x, 380, 5, 30), Color(0.32, 0.22, 0.16))
		draw_colored_polygon(PackedVector2Array([
			Vector2(banner_x + 5, 382), Vector2(banner_x + 34, 389),
			Vector2(banner_x + 5, 400),
		]), tint)
		banner_x += 200.0

	# --- Lower wall: stone blocks + barred holding gates --------------------
	draw_rect(Rect2(-2000, 410, 5280, 75), arena.wall_color)
	var mortar: Color = arena.wall_color.darkened(0.22)
	for course in 3:
		var line_y: float = 410.0 + course * 25.0
		draw_line(Vector2(-2000, line_y), Vector2(3280, line_y), mortar, 2.0)
		var brick_x: float = -40.0 + (course % 2) * 32.0
		while brick_x < 1360.0:
			draw_line(Vector2(brick_x, line_y), Vector2(brick_x, line_y + 25), mortar, 2.0)
			brick_x += 64.0
	for gate_x in [270.0, 950.0]:
		# Arched pen gate: pitch-dark opening, dressed-stone arch, iron bars
		var opening := Color(0.09, 0.07, 0.08)
		draw_circle(Vector2(gate_x, 448), 30.0, opening)
		draw_rect(Rect2(gate_x - 30, 448, 60, 37), opening)
		draw_arc(Vector2(gate_x, 448), 31.0, PI, TAU, 16, arena.wall_color.lightened(0.28), 6.0)
		draw_rect(Rect2(gate_x - 37, 480, 74, 5), arena.wall_color.lightened(0.2))
		for bar in 5:
			var bar_x: float = gate_x - 20.0 + bar * 10.0
			var bar_top: float = 448.0 - sqrt(maxf(30.0 * 30.0 - (bar_x - gate_x) ** 2, 0.0))
			draw_line(Vector2(bar_x, bar_top + 2), Vector2(bar_x, 484), Color(0.32, 0.3, 0.33), 3.0)
		draw_line(Vector2(gate_x - 28, 464), Vector2(gate_x + 28, 464), Color(0.32, 0.3, 0.33), 3.0)

	# Wall ledge
	draw_rect(Rect2(-2000, 485, 5280, 18), arena.wall_color.darkened(0.25))

	# Flanking stone columns with cylinder shading + carved bands
	for column_x in [30.0, 1200.0]:
		draw_rect(Rect2(column_x, 236, 50, 254), arena.wall_color.lightened(0.1))
		draw_rect(Rect2(column_x + 4, 236, 14, 254), arena.wall_color.lightened(0.3))
		draw_rect(Rect2(column_x + 36, 236, 12, 254), arena.wall_color.darkened(0.18))
		for band_y in [300.0, 380.0, 450.0]:
			draw_line(Vector2(column_x, band_y), Vector2(column_x + 50, band_y),
					arena.wall_color.darkened(0.25), 3.0)
		draw_rect(Rect2(column_x - 8, 224, 66, 16), arena.wall_color.lightened(0.22))
		draw_rect(Rect2(column_x - 6, 240, 62, 6), arena.wall_color.darkened(0.15))
		draw_rect(Rect2(column_x - 8, 486, 66, 16), arena.wall_color.lightened(0.08))

	# Sand with a lit fighting oval (kept BELOW the wall line at 503 so the
	# glow never paints over the gates/brickwork)
	draw_rect(Rect2(-2000, 503, 5280, 1500), arena.ground_color)
	if arena.ground_texture != null:
		_draw_ground(1.0)
	draw_set_transform(Vector2(640, 640), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 560.0, arena.ground_color.lightened(0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var speck_rng := RandomNumberGenerator.new()
	speck_rng.seed = 90210
	for _i in 90:
		var pos := Vector2(speck_rng.randf_range(-100, 1380), speck_rng.randf_range(512, 700))
		draw_circle(pos, speck_rng.randf_range(1.5, 3.5), arena.ground_color.darkened(0.15))


class ArenaDust:
	extends Node2D
	## Slow motes drifting across the sand, drawn in front of the backdrop and
	## behind nothing else. Decorative: LOCAL rng only, and it disappears
	## entirely when the player turns effects down.

	const COUNT: int = 26
	const AREA := Rect2(-40.0, 300.0, 1360.0, 420.0)

	var _time: float = 0.0
	var _motes: Array[Vector3] = []

	func _ready() -> void:
		z_index = 1  # over the sand, under the fighters (which sit above)
		if bool(SaveManager.get_setting(CombatFeel.REDUCED_FX_SETTING, false)):
			set_process(false)
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = 606060
		for _i in COUNT:
			_motes.append(Vector3(
					rng.randf_range(AREA.position.x, AREA.end.x),
					rng.randf_range(AREA.position.y, AREA.end.y),
					rng.randf_range(0.0, TAU)))

	func _process(delta: float) -> void:
		_time += delta
		for i in _motes.size():
			var mote: Vector3 = _motes[i]
			mote.x += (6.0 + 5.0 * sin(mote.z)) * delta
			if mote.x > AREA.end.x:
				mote.x = AREA.position.x
			_motes[i] = mote
		queue_redraw()

	func _draw() -> void:
		for mote in _motes:
			var bob: float = sin(_time * 0.7 + mote.z) * 9.0
			draw_circle(Vector2(mote.x, mote.y + bob), 1.6 + 0.9 * sin(mote.z),
					Color(1.0, 0.93, 0.78, 0.10))
