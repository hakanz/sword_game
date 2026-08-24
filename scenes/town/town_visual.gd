class_name TownVisual
extends Node2D
## Placeholder street backdrop for Dustwell, the fighters' quarter
## (charter §22/§27): dusk sky, building silhouettes with lit windows, two
## shop fronts. Local fixed-seed RNG only — never gameplay RNG.


func _draw() -> void:
	# Dusk sky bands
	var sky_top := Color(0.2, 0.13, 0.26)
	var sky_bottom := Color(0.55, 0.3, 0.28)
	for band in 4:
		draw_rect(Rect2(-2000, -2000 + band * 560, 5280, 600),
				sky_top.lerp(sky_bottom, band / 3.0))
	# Low sun
	draw_circle(Vector2(320, 240), 70.0, Color(1.0, 0.75, 0.5, 0.35))

	# Distant arena silhouette
	draw_circle(Vector2(1050, 400), 190.0, Color(0.16, 0.11, 0.18, 0.8))
	draw_rect(Rect2(860, 400, 380, 80), Color(0.16, 0.11, 0.18, 0.8))

	# Building row
	var rng := RandomNumberGenerator.new()
	rng.seed = 24601
	var x: float = -80.0
	while x < 1400.0:
		var width: float = rng.randf_range(120, 200)
		var height: float = rng.randf_range(160, 300)
		var wall := Color(0.22, 0.16, 0.24).lightened(rng.randf_range(0.0, 0.08))
		draw_rect(Rect2(x, 460 - height, width, height), wall)
		# Roof
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8, 460 - height), Vector2(x + width + 8, 460 - height),
			Vector2(x + width / 2.0, 460 - height - rng.randf_range(24, 50)),
		]), wall.darkened(0.25))
		# Lit windows
		var rows: int = int(height / 56.0)
		for row in rows:
			for col in int(width / 52.0):
				if rng.randf() < 0.55:
					draw_rect(Rect2(x + 14 + col * 52, 460 - height + 18 + row * 56, 18, 24),
							Color(1.0, 0.82, 0.45, 0.9))
		x += width + rng.randf_range(10, 30)

	# Street
	draw_rect(Rect2(-2000, 460, 5280, 1500), Color(0.3, 0.25, 0.28))
	draw_rect(Rect2(-2000, 460, 5280, 12), Color(0.2, 0.16, 0.2))
	for _i in 60:
		draw_circle(Vector2(rng.randf_range(-100, 1380), rng.randf_range(485, 700)),
				rng.randf_range(1.5, 3.5), Color(0.24, 0.2, 0.23))
