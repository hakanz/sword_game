class_name CombatCamera
extends Camera2D
## Dynamic framing camera for a duel (charter amendment V2 §51). Keeps both
## fighters in shot, tightens as they close and widens as they separate, and
## punches in on a crit or a killing blow. It also owns the impact SHAKE now
## (previously an offset on WorldRoot — a world-space shake would be
## cancelled out by a camera that re-frames from world positions every frame).
##
## Boundaries: presentation only, driven entirely by data the 8-cell model
## already exposes (`CombatContext`). It never reads or writes gameplay
## state, never consumes RngService, and is fully static when the player
## turns camera motion off.
##
## Framing math lives in the pure statics below so it is unit-testable
## headlessly (no viewport, no tree). `_process` only composes them.

## The design-space box the arena backdrop is drawn for. The camera never
## frames outside it, so no zoom/pan can reveal the edge of the crowd.
const DESIGN := Vector2(1280.0, 720.0)
## Vertical focus: fighters stand on GROUND_Y=500 and are ~240px tall, so
## their torsos sit here. Only used when there is room to move vertically.
const FOCUS_Y: float = 400.0

## Zoom per cell separation (index = separation, clamped). Never below 1.0:
## zooming OUT past the design box would expose the drawn arena's edges.
const ZOOM_BY_SEPARATION: PackedFloat32Array = [
	1.26, 1.26, 1.16, 1.08, 1.03, 1.0, 1.0, 1.0, 1.0,
]
## Extra zoom on a crit / on the killing blow, decaying back to the frame.
const PUNCH_CRIT: float = 0.05
const PUNCH_KILL: float = 0.09
const PUNCH_RELEASE: float = 0.5
## Setting key + default for the camera-motion accessibility slider. The
## settings screen writes through these same constants, so a rename cannot
## silently disconnect the slider from the camera.
const MOTION_SETTING: String = "camera_motion"
const MOTION_DEFAULT: int = 100
## Exponential smoothing rate (higher = snappier follow).
const RESPONSE: float = 6.0
## Framing leans toward the midpoint but keeps a little of the design centre
## so the camera never feels welded to the fighters.
const MIDPOINT_WEIGHT: float = 0.85

var _left: Combatant = null
var _right: Combatant = null
var _context: CombatContext = null

## 0.0 = fully static framing (accessibility), 1.0 = full motion. Public so
## the settings coupling is testable end to end.
var motion_scale: float = 1.0
var _zoom_level: float = 1.0
var _focus: Vector2 = DESIGN * 0.5
## Extra zoom currently applied by a crit/kill push-in (tweened back to 0).
var punch_zoom: float = 0.0
var _punch_tween: Tween = null
var _shake_tween: Tween = null


func _ready() -> void:
	# Accessibility (charter §28): the settings screen's camera-motion slider.
	# Read once per combat — settings changes apply from the next fight, the
	# same way the other combat-presentation settings behave.
	motion_scale = clampf(
			float(SaveManager.get_setting(MOTION_SETTING, MOTION_DEFAULT)) / 100.0, 0.0, 1.0)
	_zoom_level = zoom_for_separation(5, motion_scale)
	_focus = Vector2(DESIGN.x * 0.5, focus_y(motion_scale))
	zoom = Vector2(_zoom_level, _zoom_level)
	position = clamp_focus(_focus, _zoom_level, _view_size())
	set_process(not GameManager.smoke_test)


## Starts following a duel. Until this is called the camera holds the
## classic static frame, so the scene is safe to instance on its own.
func track(left: Combatant, right: Combatant, context: CombatContext) -> void:
	_left = left
	_right = right
	_context = context


func _process(delta: float) -> void:
	if _left == null or _right == null or _context == null:
		return
	var target_zoom: float = zoom_for_separation(_context.separation(), motion_scale)
	var target_focus := Vector2(
			focus_x(_left.position.x, _right.position.x, motion_scale), focus_y(motion_scale))
	# Frame-rate independent exponential smoothing. During a hit-stop the
	# engine's delta shrinks with time_scale, so the camera freezes WITH the
	# world — exactly the intended slam-and-hold.
	var t: float = 1.0 - exp(-RESPONSE * delta)
	_zoom_level = lerpf(_zoom_level, target_zoom, t)
	_focus = _focus.lerp(target_focus, t)
	var effective: float = _zoom_level * (1.0 + punch_zoom)
	zoom = Vector2(effective, effective)
	position = clamp_focus(_focus, effective, _view_size())


## Push-in accent on a crit or a kill (V2 §51). Scaled by the camera-motion
## accessibility setting like every other camera move.
func punch_in(kill: bool = false) -> void:
	if GameManager.smoke_test or motion_scale <= 0.0:
		return
	if _punch_tween != null:
		_punch_tween.kill()
	punch_zoom = (PUNCH_KILL if kill else PUNCH_CRIT) * motion_scale
	_punch_tween = create_tween()
	_punch_tween.tween_property(self, "punch_zoom", 0.0, PUNCH_RELEASE) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


## Impact shake, in camera-local pixels. Strength is already scaled by the
## screen-shake accessibility slider and the weapon's weight by the caller
## (CombatController._shake / CombatFeel.shake_scale) — one shake policy,
## one place that decides its strength.
func shake(strength: float) -> void:
	if strength <= 0.0:
		return
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "offset",
			Vector2(strength, -strength * 0.5), 0.04)
	_shake_tween.tween_property(self, "offset",
			Vector2(-strength * 0.7, strength * 0.4), 0.05)
	_shake_tween.tween_property(self, "offset",
			Vector2(strength * 0.35, strength * 0.2), 0.05)
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, 0.06)


# --- Pure framing math (unit-tested; no tree/viewport needed) ---------------

## Tighter frame when the fighters are on top of each other, wider as the
## gap opens — bow duels read as "distant" the moment they start. Motion 0
## pins the classic 1.0 frame.
static func zoom_for_separation(separation: int, motion: float) -> float:
	var index: int = clampi(separation, 0, ZOOM_BY_SEPARATION.size() - 1)
	return lerpf(1.0, ZOOM_BY_SEPARATION[index], clampf(motion, 0.0, 1.0))


## Horizontal focus: mostly the midpoint between the fighters, eased back
## toward the arena centre so the frame stays composed.
static func focus_x(left_x: float, right_x: float, motion: float) -> float:
	var centre: float = DESIGN.x * 0.5
	var midpoint: float = (left_x + right_x) * 0.5
	return lerpf(centre, lerpf(centre, midpoint, MIDPOINT_WEIGHT),
			clampf(motion, 0.0, 1.0))


static func focus_y(motion: float) -> float:
	return lerpf(DESIGN.y * 0.5, FOCUS_Y, clampf(motion, 0.0, 1.0))


## Keeps the visible rectangle inside the drawn design box. When the view is
## WIDER than the box (ultra-wide window at zoom 1.0) the axis is simply
## centred — matching the pre-camera behaviour of centring the design space.
static func clamp_focus(focus: Vector2, zoom_level: float, view: Vector2) -> Vector2:
	var half: Vector2 = view / (2.0 * maxf(zoom_level, 0.01))
	return Vector2(_clamp_axis(focus.x, half.x, DESIGN.x), _clamp_axis(focus.y, half.y, DESIGN.y))


static func _clamp_axis(value: float, half: float, extent: float) -> float:
	if half * 2.0 >= extent:
		return extent * 0.5
	return clampf(value, half, extent - half)


func _view_size() -> Vector2:
	var size: Vector2 = get_viewport_rect().size
	return size if size.x > 0.0 and size.y > 0.0 else DESIGN
