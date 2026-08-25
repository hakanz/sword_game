class_name PlaceholderRig
extends Node2D
## Gladiator rig v5 (charter §12/§25/§27): muscular cartoon
## anatomy with 3-tone shading, EQUIPPED ARMOUR drawn on the body per slot,
## detailed per-class weapons tinted by tier — and now a LIVING rig
## (session-5 owner design): the weapon arm is its own pivoting node with an
## idle sway, real swing/aim animations, and the face carries expressions
## (fierce on the attack, pained on a hit, worried when the fight turns).
## v5 adds TEXTURE slots on top of that: an equipped weapon with a painted
## `sprite` is drawn in the fist instead of the primitive weapon, and an
## armour piece with a `material_texture` fills its shapes with real leather /
## mail / plate rather than a flat tone. Both are optional — every drawing
## path still works with no art installed at all, which is what keeps the
## generated set a drop-in replacement (docs/ASSET_MANIFEST.md).
##
## All shapes and designs are original. Gameplay talks only to the animation
## methods; the §25 set (Block, Parry, CriticalHit, Stunned, Taunt, Walk/Run)
## lives here beside the older ones.

enum Face { NEUTRAL, ANGRY, WORRIED, PAIN, HAPPY }

const OUTLINE := Color(0.14, 0.09, 0.09, 0.95)
const BOOT_LEATHER := Color(0.33, 0.21, 0.12)
## Front-arm shoulder anchor in rig space — the arm node pivots here.
const SHOULDER := Vector2(19, -77)
## How far above its feet the rig reaches, in rig units: the tip of the tallest
## helmet crest. The arena framing is built on this — the backdrop's wall base
## has to clear it (test_art.gd asserts the clearance).
const HEIGHT: float = 130.0

var body_color: Color = Color(0.85, 0.64, 0.47)
var accent_color: Color = Color(0.35, 0.28, 0.5)
## The wielded weapon (null = bare fists). Tier tints the metal.
var weapon: WeaponData = null:
	set(value):
		weapon = value
		queue_redraw()
		if _arm != null:
			_arm.queue_redraw()
		_refresh_aura()
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

## Rig-unit size one tile of an armour material patch covers. Small enough
## that a cuirass shows several rivets, large enough not to look like noise.
const MATERIAL_TILE: float = 42.0

## Upright length, in rig units, a painted weapon sprite is scaled to.
const SPRITE_LENGTH: Dictionary = {
	Enums.WeaponClass.SWORD: 76.0,
	Enums.WeaponClass.AXE: 66.0,
	Enums.WeaponClass.BLUNT: 62.0,
	Enums.WeaponClass.SPEAR: 96.0,
	Enums.WeaponClass.RANGED: 74.0,
	Enums.WeaponClass.MAGICAL: 88.0,
}

## Forward lean of a painted sprite about its grip, in radians. A bow is held
## upright; everything else angles its business end into the fight.
const SPRITE_TILT: Dictionary = {
	Enums.WeaponClass.SWORD: 0.20,
	Enums.WeaponClass.AXE: 0.16,
	Enums.WeaponClass.BLUNT: 0.16,
	Enums.WeaponClass.SPEAR: 0.13,
	Enums.WeaponClass.RANGED: 0.0,
	Enums.WeaponClass.MAGICAL: 0.10,
}

var _arm: ArmRig = null
var _sway_tween: Tween = null
var _expression_tween: Tween = null
var _stunned: bool = false
var _stun_node: StunStars = null
var _aura: Sprite2D = null


func _ready() -> void:
	if facing_left:
		scale.x = -absf(scale.x)  # keep any caller-set zoom, just mirror it
	# Armour material patches are UV-tiled across the body shapes, which only
	# works if this canvas item lets its textures repeat.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_arm = ArmRig.new()
	_arm.position = SHOULDER
	_arm.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_arm)
	_start_idle()
	_refresh_aura()


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

## Attack: wind the weapon arm back, lunge in, deliver, recover — with the
## PACING and the choreography taken from CombatFeel (V2 §51), so a warhammer
## visibly loads up while a shiv flicks out. Bows draw-hold-loose, spears
## thrust with the longest reach, staves take a cast beat.
func play_attack_lunge(ranged: bool = false) -> void:
	flash_expression(Face.ANGRY, 0.9)
	if _sway_tween != null:
		_sway_tween.kill()
	var weapon_class: Enums.WeaponClass = _active_weapon_class()
	if ranged:
		weapon_class = Enums.WeaponClass.RANGED
	var style: CombatFeel.Style = CombatFeel.attack_style(weapon_class)
	var windup: float = CombatFeel.windup_time(weapon_class)
	var swing: float = CombatFeel.swing_time(weapon_class)
	var recovery: float = CombatFeel.recovery_time(weapon_class)

	var lunge: float = CombatFeel.lunge_distance(weapon_class)
	if lunge > 0.0:
		var forward: float = -lunge if facing_left else lunge
		var body: Tween = create_tween()
		# Heavy weapons settle back into their swing; light ones dart.
		body.tween_property(self, "position:x", forward * 0.25, windup) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).as_relative()
		body.tween_property(self, "position:x", forward * 0.75, swing) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
		body.tween_property(self, "position:x", -forward, recovery) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).as_relative()

	var arm: Tween = create_tween()
	match style:
		CombatFeel.Style.AIM:
			# Draw and loose: raise to aim, hold through the shot, settle.
			arm.tween_property(_arm, "rotation", CombatFeel.wind_angle(weapon_class), windup) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			arm.tween_property(_arm, "rotation", CombatFeel.follow_angle(weapon_class), swing) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			arm.tween_property(_arm, "rotation", 0.0, recovery) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		CombatFeel.Style.THRUST:
			# Coil the shaft back, then drive it straight out and reset.
			arm.tween_property(_arm, "rotation", CombatFeel.wind_angle(weapon_class), windup) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			arm.tween_property(_arm, "rotation", CombatFeel.follow_angle(weapon_class), swing) \
					.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			arm.tween_property(_arm, "rotation", 0.0, recovery) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		CombatFeel.Style.CAST:
			# Anticipation: the arm rises and HOLDS before the release.
			arm.tween_property(_arm, "rotation", CombatFeel.wind_angle(weapon_class), windup) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			arm.tween_property(_arm, "rotation", CombatFeel.follow_angle(weapon_class), swing) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			arm.tween_property(_arm, "rotation", 0.0, recovery) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_:
			# Wind-up back over the shoulder, whip through, recover.
			arm.tween_property(_arm, "rotation", CombatFeel.wind_angle(weapon_class), windup) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			arm.tween_property(_arm, "rotation", CombatFeel.follow_angle(weapon_class), swing) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			arm.tween_property(_arm, "rotation", 0.0, recovery) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arm.tween_callback(_restart_sway)


## The class actually being wielded: the equipped weapon wins, falling back
## to the class-only field callers like the creation preview set.
func _active_weapon_class() -> Enums.WeaponClass:
	return weapon.weapon_class if weapon != null else weapon_class


## Block (charter §25): the guard comes up and the fighter sets their feet.
## Called when a DEFEND resolves, so the stance is something you SEE, not just
## a shield that pops into existence.
func play_block() -> void:
	if _dead:
		return
	if _sway_tween != null:
		_sway_tween.kill()
	var brace: float = 8.0 if facing_left else -8.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:x", brace, 0.12) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
	tween.parallel().tween_property(_arm, "rotation", -0.55, 0.14) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", -brace, 0.18) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).as_relative()
	tween.parallel().tween_property(_arm, "rotation", -0.2, 0.18) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Parry (charter §25): a guarded fighter turning a blow aside — a sharp
## deflecting flick of the weapon arm rather than the dodge-step of a plain
## miss. The spark that sells it is spawned by the controller.
func play_parry() -> void:
	if _dead:
		return
	flash_expression(Face.ANGRY, 0.5)
	if _sway_tween != null:
		_sway_tween.kill()
	var tween: Tween = create_tween()
	tween.tween_property(_arm, "rotation", -0.95, 0.07) 			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(_arm, "rotation", 0.15, 0.16) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_restart_sway)
	var shove: float = 5.0 if facing_left else -5.0
	var body: Tween = create_tween()
	body.tween_property(self, "position:x", shove, 0.07).as_relative()
	body.tween_property(self, "position:x", -shove, 0.16).as_relative()


## CriticalHit reaction (charter §25): the same beat as a hit, but the blow
## visibly rocks the fighter — deeper knockback, a spin off the vertical, and
## the pain face held long enough to register.
func play_critical_reaction() -> void:
	flash_expression(Face.PAIN, 1.1)
	var tween: Tween = create_tween()
	modulate = Color(1.0, 0.28, 0.28)
	tween.tween_property(self, "modulate", Color.WHITE, 0.35)
	var back: float = 22.0 if facing_left else -22.0
	var flinch: Tween = create_tween()
	flinch.tween_property(self, "position:x", back, 0.08) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
	flinch.tween_property(self, "position:x", -back, 0.3) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).as_relative()
	if _dead:
		return  # a killing crit hands over to play_death; do not fight it
	var spin: float = 13.0 if facing_left else -13.0
	var rock: Tween = create_tween()
	rock.tween_property(self, "rotation_degrees", spin, 0.09) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rock.tween_property(self, "rotation_degrees", 0.0, 0.34) 			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Stunned (charter §25): a looping woozy sway plus circling stars, held for as
## long as the status is on the fighter. Idempotent — the status system
## re-asserts it every round.
func set_stunned(stunned: bool) -> void:
	if stunned == _stunned:
		return
	_stunned = stunned
	if not stunned:
		if _stun_node != null:
			_stun_node.queue_free()
			_stun_node = null
		rotation_degrees = 0.0
		if not _dead:
			_restart_sway()
		return
	if _dead:
		return
	if _sway_tween != null:
		_sway_tween.kill()
	_stun_node = StunStars.new()
	_stun_node.position = Vector2(0, -122)
	add_child(_stun_node)
	var wobble: Tween = create_tween()
	wobble.set_loops()
	wobble.tween_property(self, "rotation_degrees", 5.0, 0.42) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(self, "rotation_degrees", -5.0, 0.42) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_stun_node.tree_exiting.connect(wobble.kill)


## Taunt (charter §25): playing to the crowd — chest out, weapon arm thrown
## wide, a grin. Used by the mocking skills and when the stands turn.
func play_taunt() -> void:
	if _dead:
		return
	flash_expression(Face.HAPPY, 1.2)
	if _sway_tween != null:
		_sway_tween.kill()
	var arm: Tween = create_tween()
	arm.tween_property(_arm, "rotation", 0.9, 0.16) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arm.tween_property(_arm, "rotation", 0.45, 0.22) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arm.tween_property(_arm, "rotation", 0.0, 0.2) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arm.tween_callback(_restart_sway)
	var lean: float = -10.0 if facing_left else 10.0
	var body: Tween = create_tween()
	body.tween_property(self, "position:x", lean, 0.18) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).as_relative()
	body.tween_property(self, "position:y", -6.0, 0.14) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
	body.tween_property(self, "position:y", 6.0, 0.16) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).as_relative()
	body.tween_property(self, "position:x", -lean, 0.22) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).as_relative()


## Walk / Run (charter §25) for a cell step. A turn-based fighter never free-
## roams, so the whole gait is this: a bob whose height and cadence rise with
## how far the fighter is covering. `cells` is the distance being crossed and
## `seconds` the travel time the controller is tweening the body over.
func play_move(cells: int, seconds: float) -> void:
	if _dead:
		return
	var running: bool = cells > 1
	var steps: int = maxi(2, cells * 2)
	var lift: float = 9.0 if running else 5.0
	var beat: float = maxf(seconds / (steps * 2.0), 0.04)
	var tween: Tween = create_tween()
	for _step in steps:
		tween.tween_property(self, "position:y", -lift, beat) 				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
		tween.tween_property(self, "position:y", lift, beat) 				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).as_relative()
	if running:
		# A run leans into the direction of travel.
		var tilt: float = 6.0 if facing_left else -6.0
		var lean: Tween = create_tween()
		lean.tween_property(self, "rotation_degrees", tilt, seconds * 0.3) 				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		lean.tween_property(self, "rotation_degrees", 0.0, seconds * 0.7) 				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


## Victory celebration (session-6 owner design): the champion of the duel
## pumps the weapon arm sky-high and hops on the spot, grinning.
func play_victory() -> void:
	if _dead:
		return
	flash_expression(Face.HAPPY, 3.5)
	if _sway_tween != null:
		_sway_tween.kill()
	var arm: Tween = create_tween()
	arm.tween_property(_arm, "rotation", -2.3, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for _pump in 2:
		arm.tween_property(_arm, "rotation", -1.9, 0.18) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		arm.tween_property(_arm, "rotation", -2.3, 0.18) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arm.tween_property(_arm, "rotation", 0.0, 0.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arm.tween_callback(_restart_sway)
	var hops: Tween = create_tween()
	for _hop in 3:
		hops.tween_property(self, "position:y", -14.0, 0.16) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
		hops.tween_property(self, "position:y", 14.0, 0.16) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).as_relative()


func play_death() -> void:
	_dead = true
	set_stunned(false)
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

	var leg_material: Texture2D = _material_of(legs)
	# Back leg: thigh + calf + foot
	_fill_limb(Vector2(-8, -46), Vector2(-11, -26), 14.0, back_thigh, leg_material)
	_fill_limb(Vector2(-11, -26), Vector2(-14, -7), 11.0, back_thigh, leg_material)
	_foot(Vector2(-15, -4), boots, true)
	# Front leg
	_fill_limb(Vector2(8, -46), Vector2(11, -26), 14.0, front_thigh, leg_material)
	_fill_limb(Vector2(11, -26), Vector2(14, -7), 11.0, front_thigh, leg_material)
	_foot(Vector2(15, -4), boots, false)
	# Calf highlight on the front leg (subtle — big/bright reads as a patch)
	draw_circle(Vector2(12, -24), 3.0, front_thigh.lightened(0.07))

	# Battle skirt / loincloth over the hips (classic arena garb, original cut)
	var cloth: Color = accent_color
	_fill_polygon(PackedVector2Array([
		Vector2(-17, -52), Vector2(17, -52), Vector2(13, -34), Vector2(-13, -34),
	]), cloth, ArtLibrary.material(&"cloth_linen"))
	for i in 3:
		var x: float = -9.0 + i * 9.0
		draw_line(Vector2(x, -50), Vector2(x - 1, -35), cloth.darkened(0.25), 3.0)
	# Belt (studded when a belt piece is worn)
	var belt: ArmourData = _worn(Enums.EquipSlot.BELT)
	var belt_color: Color = _armour_tone(belt) if belt != null else accent_color.darkened(0.3)
	_fill_limb(Vector2(-17, -52), Vector2(17, -52), 8.0, belt_color, _material_of(belt))
	draw_circle(Vector2(0, -52), 4.5, Color(0.9, 0.76, 0.4))
	if belt != null:
		for x in [-11.0, 11.0]:
			draw_circle(Vector2(x, -52), 2.2, belt_color.lightened(0.35))


func _foot(pos: Vector2, boots: ArmourData, back: bool) -> void:
	var color: Color = BOOT_LEATHER if boots == null else _armour_tone(boots)
	if back:
		color = color.darkened(0.2)
	var material: Texture2D = _material_of(boots)
	_fill_limb(pos, pos + Vector2(7, 0), 9.0, color, material)
	if boots != null:
		# Boot shaft
		_fill_limb(pos + Vector2(-1, -2), pos + Vector2(-2, -12), 10.0, color, material)


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
		_fill_polygon(cuirass, tone, _material_of(chest))
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
			_fill_circle(at, 9.5, tone, _material_of(shoulders))
			draw_arc(at, 6.5, PI, TAU, 10, tone.lightened(0.3), 2.5)
		else:
			draw_circle(at, 9.0, skin if side > 0 else skin_sh)
			draw_circle(at + Vector2(-2 * side, -2), 4.0, skin_hi if side > 0 else skin_sh)


func _draw_back_arm(skin_sh: Color) -> void:
	var gloves: ArmourData = _worn(Enums.EquipSlot.GLOVES)
	_limb(Vector2(-19, -77), Vector2(-27, -63), 9.5, skin_sh)
	_limb(Vector2(-27, -63), Vector2(-29, -50), 8.0, skin_sh)
	if gloves != null:
		_fill_limb(Vector2(-28, -58), Vector2(-29, -51), 9.0,
				_armour_tone(gloves).darkened(0.15), _material_of(gloves))
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
		var helmet_material: Texture2D = _material_of(helmet)
		if helmet_material != null:
			var dome := PackedVector2Array()
			for i in 13:
				var sweep: float = PI + PI * i / 12.0
				dome.append(Vector2(0, -102) + Vector2(cos(sweep), sin(sweep)) * 18.5)
			dome.append(Vector2(0, -102))
			_fill_polygon(dome, tone, helmet_material)
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
		Face.HAPPY:
			# Brow lifted, bright eye, wide open grin.
			draw_line(Vector2(4, -107.5), Vector2(13, -107), OUTLINE, 2.8)
			draw_circle(Vector2(9, -101.5), 3.8, Color(0.96, 0.94, 0.9))
			draw_circle(Vector2(10, -101.5), 2.0, Color(0.12, 0.1, 0.12))
			draw_line(Vector2(15, -99), Vector2(17, -96), skin_sh, 2.4)
			draw_arc(Vector2(9, -92), 4.2, PI * 0.15, PI * 0.85, 10, mouth_color, 2.6)
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


# --- Texture helpers --------------------------------------------------------

## Legendary glow (charter §25 VFX list): a wielded Legendary or Mythic weapon
## haloes its owner. Rebuilt whenever the weapon changes; silently does nothing
## when the art is not installed.
func _refresh_aura() -> void:
	if not is_inside_tree():
		return
	var wants: bool = weapon != null and weapon.rarity >= Enums.Rarity.LEGENDARY
	if not wants:
		if _aura != null:
			_aura.queue_free()
			_aura = null
		return
	if _aura != null:
		return
	var glow: Texture2D = ArtLibrary.vfx(&"legendary_glow")
	if glow == null:
		return
	_aura = Sprite2D.new()
	_aura.texture = glow
	_aura.position = Vector2(0, -68)
	_aura.scale = Vector2(190.0, 250.0) / glow.get_size()
	_aura.modulate = Color(1.0, 0.84, 0.45, 0.26)
	_aura.z_index = -1
	add_child(_aura)
	if bool(SaveManager.get_setting(CombatFeel.REDUCED_FX_SETTING, false)):
		return
	var pulse: Tween = create_tween()
	pulse.set_loops()
	pulse.tween_property(_aura, "modulate:a", 0.38, 1.1) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_aura, "modulate:a", 0.20, 1.1) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## UVs that tile a material patch across rig space at a fixed world scale, so
## the same leather reads at the same grain on a helm and on a cuirass.
static func _tile_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for point in points:
		uvs.append(point / MATERIAL_TILE)
	return uvs


## Polygon fill that uses an armour material when the piece carries one and
## falls straight back to the flat tone when it does not.
func _fill_polygon(points: PackedVector2Array, tone: Color, texture: Texture2D) -> void:
	if texture == null:
		draw_colored_polygon(points, tone)
	else:
		draw_colored_polygon(points, tone, _tile_uvs(points), texture)


func _fill_circle(center: Vector2, radius: float, tone: Color,
		texture: Texture2D) -> void:
	if texture == null:
		draw_circle(center, radius, tone)
		return
	var points := PackedVector2Array()
	for i in 16:
		var angle: float = TAU * i / 16.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_fill_polygon(points, tone, texture)


## Textured counterpart of `_limb` — a capsule built from a quad plus two end
## discs, so a greave or a manica carries its material down the limb.
func _fill_limb(from: Vector2, to: Vector2, width: float, tone: Color,
		texture: Texture2D) -> void:
	if texture == null:
		_limb(from, to, width, tone)
		return
	var normal: Vector2 = (to - from).orthogonal().normalized() * (width / 2.0)
	_fill_polygon(PackedVector2Array([
		from + normal, to + normal, to - normal, from - normal,
	]), tone, texture)
	_fill_circle(from, width / 2.0, tone, texture)
	_fill_circle(to, width / 2.0, tone, texture)


## The material patch a worn piece paints itself with (null = flat tone).
static func _material_of(piece: ArmourData) -> Texture2D:
	return piece.material_texture if piece != null else null


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
			_fill_stroke(Vector2(9, 18), HAND, 9.5, rig._armour_tone(gloves),
					PlaceholderRig._material_of(gloves))
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

	## Painted sprite in the fist: scaled to the class's reach, pivoted on the
	## grip (bottom edge for everything held by a handle, dead centre for a
	## bow) and leaned into the fight. No tier tint — the art already carries
	## the metal.
	func _draw_weapon_sprite(sprite: Texture2D, wc: Enums.WeaponClass) -> void:
		var texture_size: Vector2 = sprite.get_size()
		if texture_size.y <= 0.0:
			return
		var length: float = PlaceholderRig.SPRITE_LENGTH.get(wc, 72.0)
		var width: float = length * (texture_size.x / texture_size.y)
		var centred: bool = wc == Enums.WeaponClass.RANGED
		# Nudged forward of the fist so a broad head clears the chest instead
		# of hanging over it; the wider the weapon, the further it steps out.
		var clearance := Vector2(minf(width * 0.18, 12.0), 0.0)
		draw_set_transform(HAND + clearance,
				PlaceholderRig.SPRITE_TILT.get(wc, 0.18), Vector2.ONE)
		draw_texture_rect(sprite, Rect2(
				-width * 0.5, -length * (0.5 if centred else 0.88), width, length),
				false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_weapon(rig: PlaceholderRig) -> void:
		var wc: Enums.WeaponClass = rig.weapon.weapon_class if rig.weapon != null \
				else rig.weapon_class
		if rig.weapon != null and rig.weapon.sprite != null:
			_draw_weapon_sprite(rig.weapon.sprite, wc)
			return
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

	## Material-filled stroke drawn on THIS node. Shoulder-local points are
	## shifted into rig space for the UVs so the grain lines up with the body.
	func _fill_stroke(from: Vector2, to: Vector2, width: float, color: Color,
			texture: Texture2D) -> void:
		if texture == null:
			_stroke(from, to, width, color)
			return
		var normal: Vector2 = (to - from).orthogonal().normalized() * (width / 2.0)
		var quad := PackedVector2Array([
			from + normal, to + normal, to - normal, from - normal,
		])
		var uvs := PackedVector2Array()
		for point in quad:
			uvs.append((point + PlaceholderRig.SHOULDER) / PlaceholderRig.MATERIAL_TILE)
		draw_colored_polygon(quad, color, uvs, texture)
		draw_circle(from, width / 2.0, color)
		draw_circle(to, width / 2.0, color)


class StunStars:
	extends Node2D
	## Three stars circling a stunned fighter's head (charter §25 "Stunned").
	## Uses the painted star when the art is installed and a drawn one when it
	## is not, so the reaction is never invisible.

	const COUNT: int = 3
	const RADIUS := Vector2(26.0, 9.0)

	var _time: float = 0.0
	var _star: Texture2D = null

	func _ready() -> void:
		_star = ArtLibrary.vfx(&"stun_star")

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		for i in COUNT:
			var angle: float = _time * 3.2 + TAU * i / COUNT
			var at := Vector2(cos(angle) * RADIUS.x, sin(angle) * RADIUS.y)
			# Stars swinging behind the head read smaller.
			var depth: float = 0.7 + 0.3 * (0.5 + 0.5 * sin(angle))
			if _star != null:
				var side: float = 15.0 * depth
				draw_texture_rect(_star,
						Rect2(at - Vector2(side, side) / 2.0, Vector2(side, side)), false)
			else:
				draw_circle(at, 4.0 * depth, Color(1.0, 0.87, 0.3))
