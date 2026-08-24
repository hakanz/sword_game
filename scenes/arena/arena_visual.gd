class_name ArenaVisual
extends Node2D
## Placeholder arena backdrop (charter §27): sky, colosseum wall, crowd dots,
## and sand — all primitives, palette-driven by ArenaData. Replaced by real
## background art later; tracked in docs/ASSET_MANIFEST.md.
##
## NOTE: decorative variation uses a LOCAL fixed-seed RNG on purpose —
## visuals must never consume RngService rolls or combat replays would
## diverge for the same combat seed.

var arena: ArenaData = null:
	set(value):
		arena = value
		queue_redraw()


func _draw() -> void:
	if arena == null:
		return
	# Oversized rects so aspect "expand" never shows void at any ratio.
	draw_rect(Rect2(-2000, -2000, 5280, 2340), arena.sky_color)

	# Colosseum wall band with crowd (ground line = combat GROUND_Y at 500)
	draw_rect(Rect2(-2000, 240, 5280, 245), arena.wall_color)
	var crowd_rng := RandomNumberGenerator.new()
	crowd_rng.seed = 133742
	for row in 3:
		var y: float = 288.0 + row * 62.0
		var offset: float = 14.0 * (row % 2)
		var x: float = -60.0 + offset
		while x < 1360.0:
			var tint := Color.from_hsv(crowd_rng.randf(), 0.45, 0.75)
			draw_circle(Vector2(x, y), 13.0, tint)
			draw_circle(Vector2(x, y - 16.0), 8.0, tint.lightened(0.25))
			x += 52.0
	# Wall ledge
	draw_rect(Rect2(-2000, 485, 5280, 18), arena.wall_color.darkened(0.25))

	# Sand
	draw_rect(Rect2(-2000, 503, 5280, 1500), arena.ground_color)
	var speck_rng := RandomNumberGenerator.new()
	speck_rng.seed = 90210
	for _i in 90:
		var pos := Vector2(speck_rng.randf_range(-100, 1380), speck_rng.randf_range(512, 700))
		draw_circle(pos, speck_rng.randf_range(1.5, 3.5), arena.ground_color.darkened(0.15))
