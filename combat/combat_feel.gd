class_name CombatFeel
## SINGLE source of truth for weapon-weight-driven combat PACING (charter
## amendment V2 §51): how long a swing winds up, how it travels, how long the
## recovery breathes, how hard the world freezes on impact, and how much the
## impact shakes the frame. A dagger and a warhammer are already mechanically
## different (damage/accuracy/energy) — this table is what makes them FEEL
## different.
##
## Boundaries: presentation only. Nothing here touches resolution, RNG, turn
## order or any gameplay number — hit-stop is a real-time freeze wrapped
## AROUND already-resolved results, so `--combat-seed=N` replays are
## bit-identical with or without it. Consumers: PlaceholderRig (animation
## timing) and CombatController (delays, shake strength, hit-stop). Never
## duplicate these numbers anywhere else (AI_GUIDE "Architecture Rules" #3
## in spirit: one home per formula/table).
##
## Accessibility: hit-stop honours the SAME `reduced_fx` toggle CombatVfx
## reads — deliberately not a second, parallel toggle (V2 §51).

## How a fighter delivers the blow — drives the rig's arm/body choreography.
enum Style {
	SWING,   ## over-the-shoulder arc (swords, axes, maces, fists)
	THRUST,  ## straight-line poke with the longest reach (spears)
	AIM,     ## draw, hold, loose (bows)
	CAST,    ## anticipation beat, then release (staves/wands)
}

## Time scale the world drops to during a hit-stop freeze.
const FREEZE_TIME_SCALE: float = 0.06
## Crits freeze noticeably longer (matches the existing bigger crit shake).
const CRIT_HIT_STOP_MULTIPLIER: float = 1.8
## `reduced_fx` shortens the freeze instead of removing the readability cue.
const REDUCED_FX_HIT_STOP_SCALE: float = 0.4
## Safety rail: a freeze may never outlast a blink. Raised alongside the
## session-9 pacing pass so a heavy crit is not silently clipped by the cap.
const MAX_HIT_STOP: float = 0.32

const WINDUP := &"windup"
const SWING := &"swing"
const RECOVERY := &"recovery"
const HIT_STOP := &"hit_stop"
const SHAKE := &"shake"
const LUNGE := &"lunge"
const WIND_ANGLE := &"wind_angle"
const FOLLOW_ANGLE := &"follow_angle"
const STYLE := &"style"

## Per-WeaponClass pacing. Seconds for the time keys, world pixels for
## `lunge`, radians for the arm angles, multiplier for `shake`.
##
## Session 9 (owner directive: "a notch slower, let the player see it"): the
## table was slowed by a fixed factor per key — windup x1.20, swing x1.20,
## recovery x1.35, hit-stop x1.30. Weighted deliberately, not uniformly: the
## unreadable part was never the wind-up, it was that the blow resolved and the
## turn moved on before the impact effects could register, so most of the extra
## time goes to the beat AFTER the hit. Fixed factors keep the light-to-heavy
## ordering the tests lock down.
## Light-to-heavy ordering is the design contract the tests lock down:
## UNARMED < SWORD < SPEAR < AXE < BLUNT for windup/recovery/hit-stop.
const TIMING: Dictionary = {
	Enums.WeaponClass.UNARMED: {
		WINDUP: 0.108, SWING: 0.096, RECOVERY: 0.203, HIT_STOP: 0.046,
		SHAKE: 0.75, LUNGE: 30.0, WIND_ANGLE: -0.7, FOLLOW_ANGLE: 1.0,
		STYLE: Style.SWING,
	},
	Enums.WeaponClass.SWORD: {
		WINDUP: 0.144, SWING: 0.108, RECOVERY: 0.257, HIT_STOP: 0.072,
		SHAKE: 0.95, LUNGE: 34.0, WIND_ANGLE: -0.85, FOLLOW_ANGLE: 1.15,
		STYLE: Style.SWING,
	},
	Enums.WeaponClass.AXE: {
		WINDUP: 0.24, SWING: 0.132, RECOVERY: 0.365, HIT_STOP: 0.124,
		SHAKE: 1.35, LUNGE: 40.0, WIND_ANGLE: -1.15, FOLLOW_ANGLE: 1.45,
		STYLE: Style.SWING,
	},
	Enums.WeaponClass.BLUNT: {
		WINDUP: 0.276, SWING: 0.144, RECOVERY: 0.405, HIT_STOP: 0.15,
		SHAKE: 1.5, LUNGE: 38.0, WIND_ANGLE: -1.25, FOLLOW_ANGLE: 1.5,
		STYLE: Style.SWING,
	},
	Enums.WeaponClass.SPEAR: {
		WINDUP: 0.18, SWING: 0.12, RECOVERY: 0.284, HIT_STOP: 0.078,
		SHAKE: 1.0, LUNGE: 48.0, WIND_ANGLE: -0.35, FOLLOW_ANGLE: 0.25,
		STYLE: Style.THRUST,
	},
	Enums.WeaponClass.RANGED: {
		WINDUP: 0.228, SWING: 0.12, RECOVERY: 0.27, HIT_STOP: 0.059,
		SHAKE: 0.8, LUNGE: 0.0, WIND_ANGLE: -0.55, FOLLOW_ANGLE: -0.45,
		STYLE: Style.AIM,
	},
	Enums.WeaponClass.MAGICAL: {
		WINDUP: 0.252, SWING: 0.12, RECOVERY: 0.324, HIT_STOP: 0.091,
		SHAKE: 0.9, LUNGE: 12.0, WIND_ANGLE: -1.0, FOLLOW_ANGLE: 0.15,
		STYLE: Style.CAST,
	},
}

## Beats that are not weapon-dependent: the pauses the controller holds so a
## resolved action can be read before the next one starts. They live here
## because charter rule 10 puts combat-feel pacing in ONE table, and tuning the
## fight's rhythm should never mean hunting through the controller for stray
## `await` durations. Also slowed in the session-9 pass.
const BEAT_AFTER_ACTION: float = 0.34
const BEAT_SKILL: float = 0.52
const BEAT_MOVE: float = 0.38
const BEAT_REST: float = 0.46
const BEAT_SWITCH: float = 0.46
const BEAT_BLOCK: float = 0.38
const BEAT_TAUNT: float = 0.45
const BEAT_STATUS_TICK: float = 0.46
const BEAT_STUN_SKIPPED: float = 0.7


## Guards against overlapping freezes (a DoT kill landing inside a crit
## freeze must not stack two time_scale writes).
static var _freezing: bool = false


## Setting key for the reduced-effects accessibility toggle. Shared with the
## settings screen so the two sides can never drift apart.
const REDUCED_FX_SETTING: String = "reduced_fx"


## How long after the animation STARTS the blow actually connects: the
## anticipation beat plus the stroke itself. The controller waits this long
## before presenting the resolved result, so the impact VFX/freeze land on
## the frame the weapon arrives — not while it is still cocked back.
static func impact_delay(weapon_class: Enums.WeaponClass) -> float:
	return windup_time(weapon_class) + swing_time(weapon_class)


## Anticipation beat before the blow lands — the controller waits this long
## between starting the animation and presenting the resolved result.
static func windup_time(weapon_class: Enums.WeaponClass) -> float:
	return float(_profile(weapon_class)[WINDUP])


## Travel time of the blow itself (rig-side; the arc/thrust/loose stroke).
static func swing_time(weapon_class: Enums.WeaponClass) -> float:
	return float(_profile(weapon_class)[SWING])


## Breathing room after impact before the next action begins.
static func recovery_time(weapon_class: Enums.WeaponClass) -> float:
	return float(_profile(weapon_class)[RECOVERY])


## How far the body steps into the blow (0 for bows — archers stand their
## ground). Spears reach farthest.
static func lunge_distance(weapon_class: Enums.WeaponClass) -> float:
	return float(_profile(weapon_class)[LUNGE])


## Multiplier on the controller's base impact shake — heavy weapons rattle
## the frame, fists barely do.
static func shake_scale(weapon_class: Enums.WeaponClass) -> float:
	return float(_profile(weapon_class)[SHAKE])


static func wind_angle(weapon_class: Enums.WeaponClass) -> float:
	return float(_profile(weapon_class)[WIND_ANGLE])


static func follow_angle(weapon_class: Enums.WeaponClass) -> float:
	return float(_profile(weapon_class)[FOLLOW_ANGLE])


static func attack_style(weapon_class: Enums.WeaponClass) -> Style:
	return _profile(weapon_class)[STYLE] as Style


## Freeze duration for one impact, already scaled by the crit multiplier and
## the `reduced_fx` accessibility setting. 0 means "do not freeze".
static func hit_stop_time(weapon_class: Enums.WeaponClass, is_crit: bool) -> float:
	return hit_stop_seconds(float(_profile(weapon_class)[HIT_STOP]), is_crit,
			bool(SaveManager.get_setting(REDUCED_FX_SETTING, false)))


## Pure scaling+clamping half of hit_stop_time, split out so the safety rail
## itself is testable with values the table cannot currently produce.
static func hit_stop_seconds(base: float, is_crit: bool, reduced_fx: bool) -> float:
	var seconds: float = maxf(base, 0.0)
	if is_crit:
		seconds *= CRIT_HIT_STOP_MULTIPLIER
	if reduced_fx:
		seconds *= REDUCED_FX_HIT_STOP_SCALE
	return clampf(seconds, 0.0, MAX_HIT_STOP)


## Awaitable impact freeze: dips `Engine.time_scale` for a REAL-time slice
## (the timer ignores the very time scale it sets, so the freeze can never
## stretch itself) and always restores it. Skipped in smoke/headless runs so
## CI never sleeps on presentation.
static func hit_stop(tree: SceneTree, weapon_class: Enums.WeaponClass, is_crit: bool) -> void:
	if tree == null or GameManager.smoke_test or _freezing:
		return
	var seconds: float = hit_stop_time(weapon_class, is_crit)
	if seconds <= 0.0:
		return
	_freezing = true
	Engine.time_scale = FREEZE_TIME_SCALE
	# process_always=true + ignore_time_scale=true: the freeze is bounded in
	# wall-clock time and cannot be trapped by a pause or by its own dip.
	await tree.create_timer(seconds, true, false, true).timeout
	release()


## Safety net — restores normal time flow. Called on freeze end and whenever
## the combat scene leaves the tree (a scene change mid-freeze must never
## leave the whole game in slow motion).
static func release() -> void:
	_freezing = false
	Engine.time_scale = 1.0


static func _profile(weapon_class: Enums.WeaponClass) -> Dictionary:
	# Unknown//future classes fall back to the sword baseline rather than
	# crashing presentation on a data addition.
	return TIMING.get(weapon_class, TIMING[Enums.WeaponClass.SWORD])
