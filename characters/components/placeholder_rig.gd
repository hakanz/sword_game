class_name PlaceholderRig
extends Node2D
## Procedural gladiator rig v4 (charter §12/§25/§27): muscular cartoon
## anatomy with 3-tone shading, EQUIPPED ARMOUR drawn on the body per slot,
## detailed per-class weapons tinted by tier — and now a LIVING rig
## (session-5 owner design): the weapon arm is its own pivoting node with an
## idle sway, real swing/aim animations, and the face carries expressions
## (fierce on the attack, pained on a hit, worried when the fight turns).
## All shapes are original — the genre look is matched in quality, never in
## specific designs. Gameplay talks only to the animation methods; final art
## swaps in behind the same API (docs/ASSET_MANIFEST.md).

enum Face { NEUTRAL, ANGRY, WORRIED, PAIN }

const OUTLINE := Color(0.14, 0.09, 0.09, 0.95)
const BOOT_LEATHER := Color(0.33, 0.21, 0.12)
## Front-arm shoulder anchor in rig space — the arm node pivots here.
const SHOULDER := Vector2(19, -77)

var body_color: Color = Color(0.85, 0.64, 0.47)
var accent_color: Color = Color(0.35, 0.28, 0.5)
## The wielded weapon (null = bare fists). Tier tints the metal.
var weapon: WeaponData = null:
	set(value):
		weapon = value
		queue_redraw()
		if _arm != null:
			_arm.queue_redraw()
## Worn armour, drawn per slot over the body (charter §12).
var equipment: Array[ArmourData] = []:
	set(value):
		equipment = value
		queue_redraw()
		if _arm != null:
			_arm.queue_redraw()
var facing_left: bool = false

## Kept for callers that only know a class (e.g. creation preview).
var weapon_class: Enums.WeaponClass = Enums.WeaponClass.UNARMED

var _defending: bool = false
var _dead: bool = false
var _expression: Face = Face.NEUTRAL
## Baseline the face returns to after a flash (WORRIED when HP runs low).
var _baseline: Face = Face.NEUTRAL

var _arm: ArmRig = null
var _sway_tween: Tween = null
var _expression_tween: Tween = null


func _ready() -> void:
	if facing_left:
		scale.x = -absf(scale.x)  # keep any caller-set zoom, just mirror it
	_arm = ArmRig.new()
	_arm.position = SHOULDER
	add_child(_arm)
	_start_idle()


## Weapon-arm idle sway: the fighter is never a statue. Deliberately touches
## ONLY _arm.rotation — a position/scale idle would fight the external
## placement that creation/shop screens give the rig.
func _start_idle() -> void:
	_restart_sway()


func _restart_sway() -> void:
	if _sway_tween != null:
		_sway_tween.kill()
	_sway_tween = create_tween()
	_sway_tween.set_loops()
	_sway_tween.tween_property(_arm, "rotation", 0.07, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sway_tween.tween_property(_arm, "rotation", -0.05, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle() -> void:
	if _sway_tween != null:
		_sway_tween.kill()


# --- Expressions ------------------------------------------------------------

## Shows `expr` for `seconds`, then falls back to the baseline face.
func flash_expression(expr: Face, seconds: float = 0.8) -> void:
	if _dead:
		return
	_expression = expr
	queue_redraw()
	if _expression_tween != null:
		_expression_tween.kill()
	_expression_tween = create_tween()
	_expression_tween.tween_interval(seconds)
	_expression_tween.tween_callback(func() -> void:
		_expression = _baseline
		queue_redraw())


## Low HP turns the resting face WORRIED (wired by Combatant on hp_changed).
func set_worried_baseline(worried: bool) -> void:
	_baseline = Face.WORRIED if worried else Face.NEUTRAL
	if _expression_tween == null or not _expression_tween.is_running():
		_expression = _baseline
		queue_redraw()


func set_defending(defending: bool) -> void:
	_defending = defending
	queue_redraw()


# --- Animations -------------------------------------------------------------

## Attack: wind the weapon arm back, lunge in with a full swing, recover.
## Ranged weapons raise to aim instead of swinging.
func play_attack_lunge(ranged: bool = false) -> void:
	flash_expression(Face.ANGRY, 0.9)
	if _sway_tween != null:
		_sway_tween.kill()
	var forward: float = -34.0 if facing_left else 34.0
	var body: Tween = create_tween()
	body.tween_property(self, "position:x", forward, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
	body.tween_property(self, "position:x", -forward, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).as_relative()
	var arm: Tween = create_tween()
	if ranged:
		# Draw and loose: raise to aim, hold through the shot, settle.
		arm.tween_property(_arm, "rotation", -0.55, 0.12) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arm.tween_interval(0.16)
		arm.tween_property(_arm, "rotation", 0.0, 0.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		# Wind-up back over the shoulder, whip through, recover.
		arm.tween_property(_arm, "rotation", -0.85, 0.11) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arm.tween_property(_arm, "rotation", 1.15, 0.1) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		arm.tween_property(_arm, "rotation", 0.0, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arm.tween_callback(_restart_sway)


func play_hit_flash() -> void:
	flash_expression(Face.PAIN, 0.7)
	var tween: Tween = create_tween()
	modulate = Color(1.0, 0.35, 0.35)
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	# Recoil flinch away from the blow.
	var back: float = 7.0 if facing_left else -7.0
	var flinch: Tween = create_tween()
	flinch.tween_property(self, "position:x", back, 0.06).as_relative()
	flinch.tween_property(self, "position:x", -back, 0.12).as_relative()


func play_miss_dodge() -> void:
	var tween: Tween = create_tween()
	var back: float = 14.0 if facing_left else -14.0
	tween.tween_property(self, "position:x", back, 0.1).as_relative()
	tween.tween_property(self, "position:x", -back, 0.12).as_relative()


## Rest: sink into a crouch and rise, the face easing back to neutral.
func play_rest() -> void:
	if _dead:
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale:y", scale.y * 0.9, 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.tween_property(self, "scale:y", scale.y, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Weapon switch: a quick raise-and-present flourish of the weapon arm.
func play_switch_flourish() -> void:
	if _sway_tween != null:
		_sway_tween.kill()
	var tween: Tween = create_tween()
	tween.tween_property(_arm, "rotation", -0.6, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_arm, "rotation", 0.0, 0.18) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_restart_sway)


func play_death() -> void:
	_dead = true
	_stop_idle()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees", -88.0 if not facing_left else 88.0, 0.5) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(0.6, 0.6, 0.6, 0.9), 0.5)
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _worn(slot: Enums.EquipSlot) -> ArmourData:
	for piece in equipment:
		if piece.slot == slot:
			return piece
	return null


## Armour metal/leather tone: class picks the material, tier the finish.
func _armour_tone(piece: ArmourData) -> Color:
	var tier_tint: Color = ItemIcons.tier_tint(piece.tier)
	if piece.armour_class == Enums.ArmourClass.LIGHT:
		return Color(0.52, 0.36, 0.22).lerp(tier_tint, 0.25)
	if piece.armour_class == Enums.ArmourClass.MEDIUM:
		return Color(0.45, 0.38, 0.3).lerp(tier_tint, 0.45)
	return Color(0.52, 0.55, 0.6).lerp(tier_tint, 0.5)


func _metal() -> Color:
	if weapon != null:
		return Color(0.78, 0.8, 0.85).lerp(ItemIcons.tier_tint(weapon.tier), 0.55)
	return Color(0.78, 0.8, 0.85)


func _draw() -> void:
	var skin: Color = body_color
	var skin_hi: Color = body_color.lightened(0.16)
	var skin_sh: Color = body_color.darkened(0.2)

	# Ground shadow
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 36.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_legs(skin, skin_sh)
	_draw_back_arm(skin_sh)
	_draw_torso(skin, skin_hi, skin_sh)
	_draw_head(skin, skin_hi, skin_sh)
	if _defending:
		_draw_shield()
	# Front arm + weapon live on the ArmRig child (drawn above this item).


func _draw_legs(skin: Color, skin_sh: Color) -> void:
	var legs: ArmourData = _worn(Enums.EquipSlot.LEGS)
	var boots: ArmourData = _worn(Enums.EquipSlot.BOOTS)
	var back_thigh: Color = skin_sh
	var front_thigh: Color = skin
	if legs != null:
		back_thigh = _armour_tone(legs).darkened(0.2)
		front_thigh = _armour_tone(legs)

	# Back leg: thigh + calf + foot
	_limb(Vector2(-8, -46), Vector2(-11, -26), 14.0, back_thigh)
	_limb(Vector2(-11, -26), Vector2(-14, -7), 11.0, back_thigh)
	_foot(Vector2(-15, -4), boots, true)
	# Front leg
	_limb(Vector2(8, -46), Vector2(11, -26), 14.0, front_thigh)
	_limb(Vector2(11, -26), Vector2(14, -7), 11.0, front_thigh)
	_foot(Vector2(15, -4), boots, false)
	# Calf highlight on the front leg (subtle — big/bright reads as a patch)
	draw_circle(Vector2(12, -24), 3.0, front_thigh.lightened(0.07))

	# Battle skirt / loincloth over the hips (classic arena garb, original cut)
	var cloth: Color = accent_color
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -52), Vector2(17, -52), Vector2(13, -34), Vector2(-13, -34),
	]), cloth)
	for i in 3:
		var x: float = -9.0 + i * 9.0
		draw_line(Vector2(x, -50), Vector2(x - 1, -35), cloth.darkened(0.25), 3.0)
	# Belt (studded when a belt piece is worn)
	var belt: ArmourData = _worn(Enums.EquipSlot.BELT)
	var belt_color: Color = _armour_tone(belt) if belt != null else accent_color.darkened(0.3)
	_limb(Vector2(-17, -52), Vector2(17, -52), 8.0, belt_color)
	draw_circle(Vector2(0, -52), 4.5, Color(0.9, 0.76, 0.4))
	if belt != null:
		for x in [-11.0, 11.0]:
			draw_circle(Vector2(x, -52), 2.2, belt_color.lightened(0.35))


func _foot(pos: Vector2, boots: ArmourData, back: bool) -> void:
	var color: Color = BOOT_LEATHER if boots == null else _armour_tone(boots)
	if back:
		color = color.darkened(0.2)
	_limb(pos, pos + Vector2(7, 0), 9.0, color)
	if boots != null:
		# Boot shaft
		_limb(pos + Vector2(-1, -2), pos + Vector2(-2, -12), 10.0, color)


func _draw_torso(skin: Color, skin_hi: Color, skin_sh: Color) -> void:
	var chest: ArmourData = _worn(Enums.EquipSlot.CHEST)
	var shoulders: ArmourData = _worn(Enums.EquipSlot.SHOULDERS)

	# Heroic taper: broad chest, narrow waist (outline pass first)
	var torso := PackedVector2Array([
		Vector2(-16, -50), Vector2(16, -50), Vector2(21, -82), Vector2(-21, -82),
	])
	draw_colored_polygon(_grow(torso, 2.0), OUTLINE)
	draw_colored_polygon(torso, skin)

	if chest != null:
		var tone: Color = _armour_tone(chest)
		var cuirass := PackedVector2Array([
			Vector2(-15, -52), Vector2(15, -52), Vector2(20, -81), Vector2(-20, -81),
		])
		draw_colored_polygon(cuirass, tone)
		# Trim + centre ridge + rivets
		draw_line(Vector2(-19, -80), Vector2(19, -80), tone.lightened(0.3), 3.0)
		draw_line(Vector2(0, -79), Vector2(0, -54), tone.darkened(0.25), 2.5)
		draw_line(Vector2(-14, -54), Vector2(14, -54), tone.darkened(0.3), 2.5)
		for x in [-10.0, 10.0]:
			draw_circle(Vector2(x, -76), 1.8, tone.lightened(0.4))
		# Muscle-cuirass sculpt hint
		draw_arc(Vector2(-7, -70), 6.0, PI * 0.15, PI * 0.9, 10, tone.lightened(0.18), 2.0)
		draw_arc(Vector2(7, -70), 6.0, PI * 0.1, PI * 0.85, 10, tone.lightened(0.18), 2.0)
	else:
		# Bare torso musculature: pecs, ab lines, side shadow
		draw_circle(Vector2(-8, -73), 7.5, skin_hi)
		draw_circle(Vector2(8, -73), 7.5, skin_hi)
		draw_line(Vector2(0, -78), Vector2(0, -54), skin_sh, 2.0)
		for i in 3:
			var y: float = -64.0 + i * 6.0
			draw_line(Vector2(-6, y), Vector2(6, y), skin_sh, 1.6)
		draw_line(Vector2(15, -78), Vector2(12, -54), skin_sh, 3.0)
		# Chest strap
		draw_line(Vector2(-17, -78), Vector2(14, -54), accent_color.darkened(0.1), 6.0)

	# Deltoids / pauldrons
	for side in [-1.0, 1.0]:
		var at := Vector2(19.0 * side, -79)
		if shoulders != null:
			var tone: Color = _armour_tone(shoulders)
			draw_circle(at, 11.0, OUTLINE)
			draw_circle(at, 9.5, tone)
			draw_arc(at, 6.5, PI, TAU, 10, tone.lightened(0.3), 2.5)
		else:
			draw_circle(at, 9.0, skin if side > 0 else skin_sh)
			draw_circle(at + Vector2(-2 * side, -2), 4.0, skin_hi if side > 0 else skin_sh)


func _draw_back_arm(skin_sh: Color) -> void:
	var gloves: ArmourData = _worn(Enums.EquipSlot.GLOVES)
	_limb(Vector2(-19, -77), Vector2(-27, -63), 9.5, skin_sh)
	_limb(Vector2(-27, -63), Vector2(-29, -50), 8.0, skin_sh)
	if gloves != null:
		_limb(Vector2(-28, -58), Vector2(-29, -51), 9.0, _armour_tone(gloves).darkened(0.15))
	draw_circle(Vector2(-29, -49), 5.5, skin_sh)


func _draw_head(skin: Color, skin_hi: Color, skin_sh: Color) -> void:
	var helmet: ArmourData = _worn(Enums.EquipSlot.HELMET)
	# Neck
	_limb(Vector2(0, -80), Vector2(0, -88), 10.0, skin_sh)
	# Skull + jaw
	draw_circle(Vector2(0, -100), 17.5, OUTLINE)
	draw_circle(Vector2(0, -100), 16.0, skin)
	draw_circle(Vector2(4, -93), 9.0, skin)  # jaw mass
	draw_circle(Vector2(-11, -99), 4.2, skin_sh)  # ear

	if helmet != null:
		var tone: Color = _armour_tone(helmet)
		# Original dome helm with brow rim; heavy versions add a crest fin
		draw_arc(Vector2(0, -102), 15.5, PI, TAU, 16, tone, 11.0)
		draw_line(Vector2(-15, -105), Vector2(15, -105), tone.darkened(0.25), 4.0)
		if helmet.armour_class == Enums.ArmourClass.HEAVY:
			draw_colored_polygon(PackedVector2Array([
				Vector2(-3, -116), Vector2(3, -116), Vector2(1, -126), Vector2(-1, -126),
			]), accent_color)
			# Cheek guard
			draw_colored_polygon(PackedVector2Array([
				Vector2(9, -104), Vector2(15, -103), Vector2(13, -92), Vector2(9, -94),
			]), tone.darkened(0.12))
	else:
		# Hair: short crop in a darkened accent shade + top highlight
		var hair: Color = accent_color.darkened(0.45)
		draw_arc(Vector2(0, -102), 14.5, PI * 1.02, TAU * 0.98, 16, hair, 9.0)
		draw_circle(Vector2(-9, -111), 5.0, hair)
		draw_arc(Vector2(-2, -104), 12.0, PI * 1.15, PI * 1.6, 8, hair.lightened(0.2), 3.0)

	if _dead:
		var eye := Vector2(9, -101)
		draw_line(eye + Vector2(-4, -4), eye + Vector2(4, 4), OUTLINE, 2.4)
		draw_line(eye + Vector2(-4, 4), eye + Vector2(4, -4), OUTLINE, 2.4)
	else:
		_draw_face(skin_sh)
	# Chin shading
	draw_arc(Vector2(2, -92), 7.0, PI * 0.15, PI * 0.7, 8, skin_hi, 2.0)


## Expression-driven face: brow angle, eye shape and mouth carry the mood
## (session-5 owner design — fierce striking, pained when struck, worried
## when the fight turns).
func _draw_face(skin_sh: Color) -> void:
	var mouth_color := Color(0.5, 0.28, 0.24)
	match _expression:
		Face.ANGRY:
			# Brow slammed down toward the nose, narrowed eye, gritted teeth.
			draw_line(Vector2(4, -108), Vector2(13, -103), OUTLINE, 3.4)
			draw_circle(Vector2(9, -100), 3.0, Color(0.96, 0.94, 0.9))
			draw_circle(Vector2(10, -100), 1.9, Color(0.12, 0.1, 0.12))
			draw_line(Vector2(15, -99), Vector2(17, -96), skin_sh, 2.4)
			draw_rect(Rect2(5, -92.5, 8, 3.4), Color(0.93, 0.9, 0.85))
			draw_rect(Rect2(5, -92.5, 8, 3.4), OUTLINE, false, 1.2)
			draw_line(Vector2(9, -92.5), Vector2(9, -89.1), OUTLINE, 1.0)
		Face.WORRIED:
			# Brow tilted up and in, wide eye, small downturned mouth.
			draw_line(Vector2(4, -103.5), Vector2(13, -106.5), OUTLINE, 3.0)
			draw_circle(Vector2(9, -101), 3.8, Color(0.96, 0.94, 0.9))
			draw_circle(Vector2(9.5, -101), 2.1, Color(0.12, 0.1, 0.12))
			draw_line(Vector2(15, -99), Vector2(17, -96), skin_sh, 2.4)
			draw_arc(Vector2(9, -89), 3.2, PI * 1.15, PI * 1.85, 8, mouth_color, 2.2)
		Face.PAIN:
			# Eye squeezed shut, mouth open in a shout.
			draw_line(Vector2(5, -102), Vector2(13, -100.5), OUTLINE, 2.6)
			draw_line(Vector2(4, -106), Vector2(13, -104.5), OUTLINE, 3.0)
			draw_line(Vector2(15, -99), Vector2(17, -96), skin_sh, 2.4)
			draw_circle(Vector2(9, -90.5), 3.2, Color(0.32, 0.14, 0.13))
		_:
			# Neutral: steady brow, open eye, small closed mouth.
			draw_line(Vector2(4, -106), Vector2(13, -104.5), OUTLINE, 3.0)
			draw_circle(Vector2(9, -101), 3.4, Color(0.96, 0.94, 0.9))
			draw_circle(Vector2(10, -101), 1.9, Color(0.12, 0.1, 0.12))
			draw_line(Vector2(15, -99), Vector2(17, -96), skin_sh, 2.4)
			draw_line(Vector2(6, -91.5), Vector2(11, -90.5), mouth_color, 2.2)


func _draw_shield() -> void:
	draw_circle(Vector2(-30, -60), 19.0, OUTLINE)
	draw_circle(Vector2(-30, -60), 17.0, Color(0.46, 0.5, 0.57))
	draw_circle(Vector2(-30, -60), 11.0, Color(0.56, 0.6, 0.68))
	draw_circle(Vector2(-30, -60), 4.5, Color(0.75, 0.78, 0.85))
	for angle_index in 6:
		var angle: float = TAU * angle_index / 6.0
		draw_circle(Vector2(-30, -60) + Vector2(cos(angle), sin(angle)) * 14.0, 1.8,
				Color(0.72, 0.75, 0.82))


## Round-capped thick stroke — the rig's building block.
func _limb(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width)
	draw_circle(from, width / 2.0, color)
	draw_circle(to, width / 2.0, color)


## Expands a convex polygon outward from its centroid (outline pass).
func _grow(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	var out := PackedVector2Array()
	for p in points:
		out.append(p + (p - center).normalized() * amount)
	return out


# --- Weapon arm (child node so it can pivot at the shoulder) -----------------

class ArmRig:
	extends Node2D
	## The front arm + wielded weapon, drawn in shoulder-local space so the
	## whole assembly rotates naturally for sways, wind-ups and swings.
	## Reads all data (colors, weapon, gloves) from the parent rig.

	## Hand position relative to the shoulder pivot.
	const HAND := Vector2(11, 25)

	func _draw() -> void:
		var rig: PlaceholderRig = get_parent() as PlaceholderRig
		if rig == null:
			return
		var skin: Color = rig.body_color
		var skin_hi: Color = rig.body_color.lightened(0.16)
		var gloves: ArmourData = rig._worn(Enums.EquipSlot.GLOVES)

		# Upper arm with outline, biceps highlight, forearm to the fist.
		_stroke(Vector2.ZERO, Vector2(8, 13), 11.0, PlaceholderRig.OUTLINE)
		_stroke(Vector2.ZERO, Vector2(8, 13), 9.0, skin)
		draw_circle(Vector2(4, 5), 4.5, skin_hi)
		_stroke(Vector2(8, 13), HAND, 8.5, skin)
		if gloves != null:
			_stroke(Vector2(9, 18), HAND, 9.5, rig._armour_tone(gloves))
		draw_circle(HAND, 6.0, skin)

		_draw_weapon(rig)

		# Fist redrawn OVER the grip so the hand visibly holds the weapon.
		if rig.weapon != null or rig.weapon_class != Enums.WeaponClass.UNARMED:
			var fist: Color = rig._armour_tone(gloves) if gloves != null else skin
			draw_circle(HAND, 6.5, PlaceholderRig.OUTLINE)
			draw_circle(HAND, 5.4, fist)
			draw_line(HAND + Vector2(-3, 1.5), HAND + Vector2(3, 1.5),
					fist.darkened(0.2), 1.6)
			draw_circle(HAND + Vector2(-2.5, -1), 2.0, fist.lightened(0.12))

	func _draw_weapon(rig: PlaceholderRig) -> void:
		var wc: Enums.WeaponClass = rig.weapon.weapon_class if rig.weapon != null \
				else rig.weapon_class
		var metal: Color = rig._metal()
		var metal_hi: Color = metal.lightened(0.25)
		var wood := Color(0.42, 0.28, 0.15)
		var wood_hi := Color(0.52, 0.36, 0.2)
		var grip := Color(0.3, 0.18, 0.1)
		var hand := HAND

		match wc:
			Enums.WeaponClass.SWORD:
				# Blade with edge highlight + fuller, guard, wrapped grip, pommel
				var tip := hand + Vector2(14, -66)
				draw_colored_polygon(PackedVector2Array([
					hand + Vector2(-4, -8), hand + Vector2(6, -10),
					tip + Vector2(3, 4), tip, tip + Vector2(-4, 5),
				]), metal)
				draw_line(hand + Vector2(1, -9), tip + Vector2(-1, 3), metal_hi, 2.0)
				_stroke(hand + Vector2(-8, -7), hand + Vector2(9, -11), 5.0, Color(0.62, 0.5, 0.25))
				_stroke(hand + Vector2(-1, -6), hand + Vector2(-4, 6), 5.5, grip)
				for i in 3:
					draw_line(hand + Vector2(-1.5 - i, -3 + i * 3), hand + Vector2(1 - i, -2 + i * 3),
							grip.lightened(0.3), 1.2)
				draw_circle(hand + Vector2(-5, 8), 3.4, Color(0.62, 0.5, 0.25))
			Enums.WeaponClass.AXE:
				_stroke(hand + Vector2(-3, 8), hand + Vector2(8, -46), 5.5, wood)
				draw_line(hand + Vector2(-1, 0), hand + Vector2(7, -40), wood_hi, 1.6)
				for i in 2:
					_stroke(hand + Vector2(1 - i, -12 - i * 14), hand + Vector2(4 - i, -13 - i * 14),
							6.5, grip)
				# Bearded blade with bevel
				var socket := hand + Vector2(8, -44)
				draw_colored_polygon(PackedVector2Array([
					socket, socket + Vector2(16, -8), socket + Vector2(20, 6),
					socket + Vector2(14, 18), socket + Vector2(2, 12),
				]), metal)
				draw_line(socket + Vector2(17, -6), socket + Vector2(16, 15), metal_hi, 2.4)
			Enums.WeaponClass.BLUNT:
				_stroke(hand + Vector2(-2, 8), hand + Vector2(6, -40), 6.0, wood)
				var head := hand + Vector2(7, -46)
				draw_circle(head, 13.0, PlaceholderRig.OUTLINE)
				draw_circle(head, 11.5, metal)
				draw_arc(head, 11.5, PI * 1.1, PI * 1.7, 10, metal_hi, 3.0)
				for angle_index in 5:
					var angle: float = TAU * angle_index / 5.0 + 0.4
					draw_circle(head + Vector2(cos(angle), sin(angle)) * 8.0, 2.2,
							metal.darkened(0.3))
			Enums.WeaponClass.SPEAR:
				_stroke(hand + Vector2(-4, 14), hand + Vector2(12, -62), 4.5, wood)
				draw_line(hand + Vector2(-2, 8), hand + Vector2(11, -58), wood_hi, 1.4)
				_stroke(hand + Vector2(2, -18), hand + Vector2(5, -19), 6.0, grip)
				var neck := hand + Vector2(12, -62)
				draw_colored_polygon(PackedVector2Array([
					neck + Vector2(-4, 2), neck + Vector2(4, 0),
					neck + Vector2(6, -16), neck + Vector2(0, -22), neck + Vector2(-5, -14),
				]), metal)
				draw_line(neck + Vector2(0, -2), neck + Vector2(1, -18), metal_hi, 1.6)
			Enums.WeaponClass.RANGED:
				# Recurve bow: two curved limbs, wrapped grip, taut string
				var grip_at := hand
				draw_arc(grip_at + Vector2(4, -26), 28.0, PI * 0.32, PI * 0.72, 14, wood, 5.0)
				draw_arc(grip_at + Vector2(4, 26), 28.0, PI * 1.28, PI * 1.68, 14, wood, 5.0)
				draw_arc(grip_at + Vector2(4, -26), 28.0, PI * 0.36, PI * 0.6, 8, wood_hi, 1.8)
				_stroke(grip_at + Vector2(2, -5), grip_at + Vector2(2, 5), 7.0, grip)
				var top := grip_at + Vector2(4, -26) + Vector2(cos(PI * 0.32), sin(PI * 0.32)) * 28.0
				var bottom := grip_at + Vector2(4, 26) + Vector2(cos(PI * 1.68), sin(PI * 1.68)) * 28.0
				draw_line(top, bottom, Color(0.9, 0.88, 0.8), 1.4)
			Enums.WeaponClass.MAGICAL:
				_stroke(hand + Vector2(-3, 12), hand + Vector2(6, -58), 5.0, wood.darkened(0.15))
				draw_line(hand + Vector2(-1, 6), hand + Vector2(5, -52), wood_hi, 1.5)
				var orb := hand + Vector2(7, -64)
				draw_circle(orb, 9.5, Color(0.35, 0.6, 0.95, 0.35))
				draw_circle(orb, 6.5, Color(0.5, 0.75, 1.0))
				draw_circle(orb + Vector2(-2, -2), 2.4, Color(0.85, 0.95, 1.0))
				# Claw prongs holding the orb
				for side in [-1.0, 1.0]:
					draw_line(hand + Vector2(6, -58), orb + Vector2(6 * side, 4),
							wood.darkened(0.2), 3.0)
			_:
				pass

	func _stroke(from: Vector2, to: Vector2, width: float, color: Color) -> void:
		draw_line(from, to, color, width)
		draw_circle(from, width / 2.0, color)
		draw_circle(to, width / 2.0, color)
