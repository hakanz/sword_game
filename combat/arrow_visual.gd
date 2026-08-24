class_name ArrowVisual
extends Node2D
## Placeholder arrow projectile (charter §27) drawn from primitives; the
## controller tweens it from archer to target.


func _draw() -> void:
	var shaft := Color(0.55, 0.4, 0.22)
	var head := Color(0.85, 0.87, 0.9)
	var fletch := Color(0.85, 0.3, 0.25)
	draw_line(Vector2(-16, 0), Vector2(12, 0), shaft, 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, -4), Vector2(22, 0), Vector2(12, 4),
	]), head)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -4), Vector2(-10, 0), Vector2(-16, 4), Vector2(-22, 0),
	]), fletch)
