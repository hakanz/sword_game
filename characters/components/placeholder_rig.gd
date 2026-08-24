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
	var outline := Color(0.12, 0.08, 0.1, 0.95)
	var skin := body_color.lightened(0.12)
	var boot := Color(0.3, 0.19, 0.11)

	# Shadow
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 34.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- Cartoon limb rig: thick round-capped strokes over an outline pass ---
	# Back leg + boot
	_capsule(Vector2(-7, -40), Vector2(-13, -6), 12.0, outline)
	_capsule(Vector2(-7, -40), Vector2(-13, -6), 9.0, accent_color.darkened(0.35))
	draw_circle(Vector2(-14, -5), 7.0, boot.darkened(0.25))
	# Front leg + boot
	_capsule(Vector2(7, -40), Vector2(13, -6), 12.0, outline)
	_capsule(Vector2(7, -40), Vector2(13, -6), 9.0, accent_color.darkened(0.12))
	draw_circle(Vector2(14, -5), 7.5, boot)

	# Back arm (behind torso), hand visible
	_capsule(Vector2(-9, -72), Vector2(-24, -52), 8.5, skin.darkened(0.3))
	draw_circle(Vector2(-25, -51), 5.0, skin.darkened(0.25))

	# Torso: outlined capsule with a two-tone tunic + chest strap
	_capsule(Vector2(0, -44), Vector2(0, -78), 40.0, outline)
	_capsule(Vector2(0, -44), Vector2(0, -78), 36.0, body_color)
	_capsule(Vector2(7, -46), Vector2(7, -76), 18.0, body_color.darkened(0.14))
	draw_line(Vector2(-15, -74), Vector2(13, -48), accent_color.darkened(0.08), 7.0)
	# Belt with buckle
	_capsule(Vector2(-17, -42), Vector2(17, -42), 9.0, accent_color)
	draw_circle(Vector2(0, -42), 5.0, Color(0.9, 0.76, 0.4))

	# Front arm + hand (weapon hand)
	_capsule(Vector2(10, -72), Vector2(25, -58), 9.5, outline)
	_capsule(Vector2(10, -72), Vector2(25, -58), 7.5, skin)
	draw_circle(Vector2(26, -58), 6.0, skin)

	# Head: outlined, oversized, with ear, brow, eye and headband
	draw_circle(Vector2(0, -104), 22.5, outline)
	draw_circle(Vector2(0, -104), 20.0, skin)
	draw_circle(Vector2(-14, -103), 5.0, skin.darkened(0.12))  # ear
	draw_rect(Rect2(-19, -119, 38, 7), accent_color)
	draw_circle(Vector2(-17, -115), 4.0, accent_color.darkened(0.2))  # band knot
	if not _dead:
		draw_circle(Vector2(10, -106), 3.6, Color(0.1, 0.1, 0.12))
		draw_line(Vector2(5, -113), Vector2(15, -111), Color(0.1, 0.1, 0.12), 2.6)
		draw_line(Vector2(14, -96), Vector2(19, -95), Color(0.55, 0.3, 0.25), 2.0)  # smirk
	else:
		var eye := Vector2(10, -106)
		draw_line(eye + Vector2(-4, -4), eye + Vector2(4, 4), Color(0.1, 0.1, 0.12), 2.2)
		draw_line(eye + Vector2(-4, 4), eye + Vector2(4, -4), Color(0.1, 0.1, 0.12), 2.2)

	_draw_weapon()

	# Guard/shield pose when defending
	if _defending:
		draw_circle(Vector2(28, -66), 17.0, outline)
		draw_circle(Vector2(28, -66), 15.0, Color(0.5, 0.53, 0.6))
		draw_circle(Vector2(28, -66), 9.0, Color(0.62, 0.65, 0.72))
		draw_circle(Vector2(28, -66), 3.5, Color(0.78, 0.8, 0.86))


## Round-capped thick stroke — the building block of the cartoon rig.
func _capsule(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width)
	draw_circle(from, width / 2.0, color)
	draw_circle(to, width / 2.0, color)


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
