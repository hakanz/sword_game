extends TestCase
## Phase 11 (charter amendment V2 §51) — combat feel.
## Locks down the two things that are easy to break silently later:
##  1. CombatFeel's weapon-weight table stays COMPLETE (every WeaponClass)
##     and keeps its light-to-heavy ordering contract, and its impact freeze
##     stays bounded and accessibility-aware.
##  2. CombatCamera's framing math never reveals the edge of the drawn arena
##     and collapses to the classic static frame when motion is turned off.
## The camera assertions run on pure statics — no viewport, no tree.


func _classes() -> Array:
	return Enums.WeaponClass.values()


# --- CombatFeel: table completeness and ordering ---------------------------

func test_every_weapon_class_has_a_timing_profile() -> void:
	for weapon_class: int in _classes():
		assert_true(CombatFeel.TIMING.has(weapon_class),
				"missing timing for %s" % Enums.WeaponClass.keys()[weapon_class])


func test_timings_are_within_playable_bounds() -> void:
	for weapon_class: int in _classes():
		var wc := weapon_class as Enums.WeaponClass
		var label: String = Enums.WeaponClass.keys()[weapon_class]
		assert_true(CombatFeel.windup_time(wc) >= 0.05 and CombatFeel.windup_time(wc) <= 0.35,
				"windup out of range for %s" % label)
		assert_true(CombatFeel.swing_time(wc) > 0.0 and CombatFeel.swing_time(wc) <= 0.25,
				"swing out of range for %s" % label)
		assert_true(CombatFeel.recovery_time(wc) >= 0.1 and CombatFeel.recovery_time(wc) <= 0.4,
				"recovery out of range for %s" % label)
		assert_true(CombatFeel.shake_scale(wc) > 0.0 and CombatFeel.shake_scale(wc) <= 2.0,
				"shake scale out of range for %s" % label)
		assert_true(CombatFeel.lunge_distance(wc) >= 0.0
				and CombatFeel.lunge_distance(wc) <= 60.0,
				"lunge out of range for %s" % label)


func test_heavier_weapons_wind_up_and_recover_slower() -> void:
	# The design contract of the table: fists < sword < spear < axe < maul.
	var order: Array[Enums.WeaponClass] = [
		Enums.WeaponClass.UNARMED, Enums.WeaponClass.SWORD, Enums.WeaponClass.SPEAR,
		Enums.WeaponClass.AXE, Enums.WeaponClass.BLUNT,
	]
	for i in range(1, order.size()):
		var lighter: Enums.WeaponClass = order[i - 1]
		var heavier: Enums.WeaponClass = order[i]
		assert_true(CombatFeel.windup_time(heavier) > CombatFeel.windup_time(lighter),
				"windup should grow with weight at index %d" % i)
		assert_true(CombatFeel.recovery_time(heavier) > CombatFeel.recovery_time(lighter),
				"recovery should grow with weight at index %d" % i)
		assert_true(CombatFeel.hit_stop_time(heavier, false)
				> CombatFeel.hit_stop_time(lighter, false),
				"hit-stop should grow with weight at index %d" % i)
		assert_true(CombatFeel.shake_scale(heavier) > CombatFeel.shake_scale(lighter),
				"shake should grow with weight at index %d" % i)


## Spears reach, archers hold their ground.
func test_reach_and_stance_match_the_weapon() -> void:
	assert_eq(CombatFeel.lunge_distance(Enums.WeaponClass.RANGED), 0.0,
			"archers must not lunge into the blow")
	var spear: float = CombatFeel.lunge_distance(Enums.WeaponClass.SPEAR)
	for weapon_class: int in _classes():
		if weapon_class == Enums.WeaponClass.SPEAR:
			continue
		assert_true(spear > CombatFeel.lunge_distance(weapon_class as Enums.WeaponClass),
				"spear should reach farthest (vs %s)" % Enums.WeaponClass.keys()[weapon_class])


func test_attack_styles_map_to_the_right_choreography() -> void:
	assert_eq(CombatFeel.attack_style(Enums.WeaponClass.SPEAR), CombatFeel.Style.THRUST)
	assert_eq(CombatFeel.attack_style(Enums.WeaponClass.RANGED), CombatFeel.Style.AIM)
	assert_eq(CombatFeel.attack_style(Enums.WeaponClass.MAGICAL), CombatFeel.Style.CAST)
	for weapon_class: Enums.WeaponClass in [Enums.WeaponClass.UNARMED, Enums.WeaponClass.SWORD,
			Enums.WeaponClass.AXE, Enums.WeaponClass.BLUNT]:
		assert_eq(CombatFeel.attack_style(weapon_class), CombatFeel.Style.SWING,
				"%s should swing" % Enums.WeaponClass.keys()[weapon_class])


# --- CombatFeel: hit-stop -------------------------------------------------

func test_crit_freezes_longer_but_never_past_the_cap() -> void:
	var previous: Variant = SaveManager.get_setting("reduced_fx", false)
	SaveManager.set_setting("reduced_fx", false)
	for weapon_class: int in _classes():
		var wc := weapon_class as Enums.WeaponClass
		var normal: float = CombatFeel.hit_stop_time(wc, false)
		var crit: float = CombatFeel.hit_stop_time(wc, true)
		assert_true(crit > normal, "crit should freeze longer for %s"
				% Enums.WeaponClass.keys()[weapon_class])
		assert_true(crit <= CombatFeel.MAX_HIT_STOP,
				"freeze cap exceeded for %s" % Enums.WeaponClass.keys()[weapon_class])
		assert_true(normal > 0.0, "every impact freezes at least a little")
	SaveManager.set_setting("reduced_fx", previous)


func test_reduced_fx_shortens_the_freeze_for_every_class() -> void:
	var previous: Variant = SaveManager.get_setting("reduced_fx", false)
	for weapon_class: int in _classes():
		var wc := weapon_class as Enums.WeaponClass
		SaveManager.set_setting("reduced_fx", false)
		var full: float = CombatFeel.hit_stop_time(wc, true)
		SaveManager.set_setting("reduced_fx", true)
		var reduced: float = CombatFeel.hit_stop_time(wc, true)
		assert_true(reduced < full, "reduced_fx must shorten the freeze for %s"
				% Enums.WeaponClass.keys()[weapon_class])
		assert_true(reduced > 0.0, "reduced_fx keeps the impact readable")
	SaveManager.set_setting("reduced_fx", previous)


func test_release_always_restores_normal_time_flow() -> void:
	Engine.time_scale = CombatFeel.FREEZE_TIME_SCALE
	CombatFeel.release()
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001, "release must reset time_scale")


func test_hit_stop_is_skipped_in_smoke_runs() -> void:
	# CI/headless must never sleep on presentation, and a smoke run must
	# never leave the engine in slow motion.
	var previous: bool = GameManager.smoke_test
	GameManager.smoke_test = true
	CombatFeel.hit_stop(Engine.get_main_loop() as SceneTree, Enums.WeaponClass.BLUNT, true)
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001, "smoke runs must not freeze time")
	GameManager.smoke_test = previous
	CombatFeel.release()


# --- CombatCamera: framing math -------------------------------------------

func test_zoom_tightens_as_the_fighters_close() -> void:
	var previous: float = CombatCamera.zoom_for_separation(1, 1.0)
	for separation in range(2, 10):
		var current: float = CombatCamera.zoom_for_separation(separation, 1.0)
		assert_true(current <= previous,
				"zoom must not tighten as separation %d grows" % separation)
		previous = current
	assert_true(CombatCamera.zoom_for_separation(1, 1.0)
			> CombatCamera.zoom_for_separation(7, 1.0),
			"an adjacent brawl should frame tighter than a bow duel")


func test_camera_never_zooms_out_past_the_drawn_arena() -> void:
	for motion in [0.0, 0.25, 0.5, 1.0]:
		for separation in range(-2, 12):
			assert_true(CombatCamera.zoom_for_separation(separation, motion) >= 1.0,
					"zoom %d/%s dipped below 1.0" % [separation, motion])


func test_motion_zero_is_the_classic_static_frame() -> void:
	for separation in range(0, 9):
		assert_almost_eq(CombatCamera.zoom_for_separation(separation, 0.0), 1.0)
	assert_almost_eq(CombatCamera.focus_x(150.0, 1130.0, 0.0), CombatCamera.DESIGN.x * 0.5)
	assert_almost_eq(CombatCamera.focus_x(150.0, 290.0, 0.0), CombatCamera.DESIGN.x * 0.5)
	assert_almost_eq(CombatCamera.focus_y(0.0), CombatCamera.DESIGN.y * 0.5)


func test_focus_follows_the_midpoint_between_fighters() -> void:
	var centre: float = CombatCamera.DESIGN.x * 0.5
	# Both fighters left of centre -> the frame leans left, but not past them.
	var left_biased: float = CombatCamera.focus_x(150.0, 290.0, 1.0)
	assert_true(left_biased < centre, "frame should lean toward the action")
	assert_true(left_biased > 220.0, "frame should not overshoot the midpoint")
	# Mirrored positions must mirror the framing.
	var right_biased: float = CombatCamera.focus_x(
			CombatCamera.DESIGN.x - 290.0, CombatCamera.DESIGN.x - 150.0, 1.0)
	assert_almost_eq(right_biased, CombatCamera.DESIGN.x - left_biased, 0.001,
			"framing should be symmetric")
	# Fighters straddling the centre keep the frame centred.
	assert_almost_eq(CombatCamera.focus_x(centre - 200.0, centre + 200.0, 1.0), centre, 0.001)


func test_clamped_view_never_leaves_the_design_box() -> void:
	var view := Vector2(1280.0, 720.0)
	for zoom_level in [1.0, 1.08, 1.16, 1.26]:
		for target_x in [-400.0, 0.0, 150.0, 640.0, 1130.0, 1700.0]:
			var focus: Vector2 = CombatCamera.clamp_focus(
					Vector2(target_x, CombatCamera.FOCUS_Y), zoom_level, view)
			var half: Vector2 = view / (2.0 * zoom_level)
			assert_true(focus.x - half.x >= -0.001 and focus.x + half.x <= CombatCamera.DESIGN.x + 0.001,
					"view escaped horizontally at zoom %s" % zoom_level)
			assert_true(focus.y - half.y >= -0.001 and focus.y + half.y <= CombatCamera.DESIGN.y + 0.001,
					"view escaped vertically at zoom %s" % zoom_level)


func test_oversized_viewports_fall_back_to_centring() -> void:
	# Ultra-wide window at zoom 1.0: the view is wider than the drawn box, so
	# the axis centres exactly like the pre-camera world offset did.
	var focus: Vector2 = CombatCamera.clamp_focus(
			Vector2(200.0, 400.0), 1.0, Vector2(1920.0, 720.0))
	assert_almost_eq(focus.x, CombatCamera.DESIGN.x * 0.5, 0.001)
	assert_almost_eq(focus.y, CombatCamera.DESIGN.y * 0.5, 0.001)
