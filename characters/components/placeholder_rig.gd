class_name PlaceholderRig
extends Node2D
## Placeholder fighter visual (charter §27: build against placeholders first).
## Draws a cartoonish gladiator from primitives via _draw() — big head,
## oversized weapon, readable silhouette. Replaced by the real modular
## layered-part rig (charter §12) when final art arrives; gameplay code only
## talks to the animation methods below, so the swap is drop-in.
##
## Tracked in docs/ASSET_MANIFEST.md as asset_id "rig.gladiator_placeholder".

var body_color: Color = Color(0.82, 0.62, 0.45)
var accent_color: Color = Color(0.35, 0.28, 0.5)
var weapon_class: Enums.WeaponClass = Enums.WeaponClass.SWORD
var facing_left: bool = false

var _defending: bool = false
var _dead: bool = false


func _ready() -> void:
	if facing_left:
		scale.x = -1.0


func set_defending(defending: bool) -> void:
	_defending = defending
	queue_redraw()


## Quick lunge toward the foe and back — placeholder attack animation.
func play_attack_lunge() -> void:
	var tween: Tween = create_tween()
	var forward: float = -34.0 if facing_left else 34.0
	tween.tween_property(self, "position:x", position.x + forward, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", position.x, 0.15) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func play_hit_flash() -> void:
	var tween: Tween = create_tween()
	modulate = Color(1.0, 0.35, 0.35)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func play_miss_dodge() -> void:
	var tween: Tween = create_tween()
	var back: float = 14.0 if facing_left else -14.0
	tween.tween_property(self, "position:x", position.x + back, 0.1)
	tween.tween_property(self, "position:x", position.x, 0.12)


func play_death() -> void:
	_dead = true
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees", -88.0 if not facing_left else 88.0, 0.5) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(0.6, 0.6, 0.6, 0.9), 0.5)
	queue_redraw()


func _draw() -> void:
	# Shadow
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 30.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Legs
	draw_rect(Rect2(-14, -34, 10, 34), accent_color.darkened(0.2))
	draw_rect(Rect2(4, -34, 10, 34), accent_color.darkened(0.2))

	# Torso (capsule-ish)
	draw_rect(Rect2(-18, -78, 36, 48), body_color)
	draw_circle(Vector2(0, -78), 18.0, body_color)

	# Belt
	draw_rect(Rect2(-18, -40, 36, 8), accent_color)

	# Head (oversized, cartoon proportions)
	draw_circle(Vector2(0, -104), 20.0, body_color.lightened(0.15))
	# Eye (single visible in side view)
	if not _dead:
		draw_circle(Vector2(10, -108), 3.5, Color(0.1, 0.1, 0.12))
	else:
		# Cartoon X-eye on defeat
		var eye := Vector2(10, -108)
		draw_line(eye + Vector2(-4, -4), eye + Vector2(4, 4), Color(0.1, 0.1, 0.12), 2.0)
		draw_line(eye + Vector2(-4, 4), eye + Vector2(4, -4), Color(0.1, 0.1, 0.12), 2.0)

	# Weapon arm + oversized weapon on the facing side
	draw_rect(Rect2(12, -72, 8, 26), body_color.darkened(0.1))
	_draw_weapon()

	# Guard/shield pose when defending
	if _defending:
		draw_rect(Rect2(22, -86, 8, 44), Color(0.55, 0.57, 0.62))
		draw_rect(Rect2(20, -88, 12, 4), Color(0.4, 0.42, 0.47))


func _draw_weapon() -> void:
	var metal := Color(0.78, 0.8, 0.85)
	var grip := Color(0.4, 0.26, 0.13)
	match weapon_class:
		Enums.WeaponClass.AXE:
			draw_rect(Rect2(24, -110, 6, 62), grip)
			draw_rect(Rect2(30, -112, 18, 22), metal)
		Enums.WeaponClass.BLUNT:
			draw_rect(Rect2(24, -104, 6, 56), grip)
			draw_circle(Vector2(27, -110), 12.0, metal.darkened(0.2))
		Enums.WeaponClass.SPEAR:
			draw_rect(Rect2(24, -128, 5, 84), grip)
			draw_rect(Rect2(22, -140, 9, 14), metal)
		Enums.WeaponClass.RANGED:
			draw_arc(Vector2(28, -80), 26.0, -PI / 2.2, PI / 2.2, 12, grip, 4.0)
			draw_line(Vector2(28 + 11, -103), Vector2(28 + 11, -57), Color(0.9, 0.9, 0.9), 1.5)
		Enums.WeaponClass.MAGICAL:
			draw_rect(Rect2(24, -124, 5, 78), grip)
			draw_circle(Vector2(26, -128), 8.0, Color(0.5, 0.8, 1.0))
		_:
			# Sword (also unarmed fallback)
			draw_rect(Rect2(24, -118, 7, 58), metal)
			draw_rect(Rect2(18, -62, 19, 6), grip)
