extends TestCase
## Phase 15 (amendment V2 §55) — recurring rivals and champion boss phases.
## The promises:
##  1. A champion changes SHAPE as they fall: signature moves in phase two, a
##     different temperament in phase three — from DATA, with no boss-only
##     code path in the AI.
##  2. A rival remembers. Ahead of the player they arrive better armed; behind,
##     they arrive short a piece of kit and carrying the same blade.
##  3. The rivalry record survives a save/load round trip, and a v6 save
##     upgrades into one without losing anything.

const MAULHILDA: String = "res://data/characters/champions/maulhilda.tres"
const ORZHA: String = "res://data/characters/champions/orzha.tres"


func _champion(path: String) -> CharacterData:
	return (load(path) as CharacterData).duplicate(true)


func _gravelmaw() -> ArenaData:
	return ItemDB.arena(&"arena.gravelmaw")


# --- Boss phases ------------------------------------------------------------

func test_phase_thresholds_are_data_driven() -> void:
	var champion: CharacterData = _champion(MAULHILDA)
	assert_true(champion.has_phases(), "a champion without phases is just a stat block")
	assert_eq(champion.phase_at(1.0), 1)
	assert_eq(champion.phase_at(champion.phase_two_hp + 0.01), 1)
	assert_eq(champion.phase_at(champion.phase_two_hp), 2, "the threshold itself opens the phase")
	assert_eq(champion.phase_at(champion.phase_three_hp), 3)
	assert_eq(champion.phase_at(0.0), 3)

	# An ordinary fighter has none of this and must be unaffected.
	var mook: CharacterData = CombatFixtures.make_character()
	assert_false(mook.has_phases())
	assert_eq(mook.phase_at(0.05), 1, "a fighter with no phases never leaves phase one")


func test_signature_moves_are_held_back_until_phase_two() -> void:
	var champion: CharacterData = _champion(MAULHILDA)
	assert_false(champion.phase_two_skills.is_empty(), "phase two must actually add something")
	var fighter := CombatFixtures.make_combatant(champion)
	var opening: Array[SkillData] = fighter.get_skills()
	for held: SkillData in champion.phase_two_skills:
		assert_false(opening.has(held), "%s must stay holstered in phase one" % held.id)

	# Just BELOW the threshold: rounding a fraction back out of an int HP pool
	# can land a hair above it, which is a test artefact, not a rule.
	fighter.current_hp = roundi(fighter.max_hp * champion.phase_two_hp) - 1
	fighter.refresh_phase()
	assert_eq(fighter.phase, 2)
	var unlocked: Array[SkillData] = fighter.get_skills()
	for held: SkillData in champion.phase_two_skills:
		assert_true(unlocked.has(held), "%s must come out in phase two" % held.id)
	assert_true(unlocked.size() > opening.size())
	fighter.free()


func test_the_temperament_shifts_in_phase_three() -> void:
	var champion: CharacterData = _champion(MAULHILDA)
	assert_true(champion.phase_three_personality != null)
	var fighter := CombatFixtures.make_combatant(champion)
	assert_eq(fighter.active_personality(), champion.personality)
	fighter.current_hp = roundi(fighter.max_hp * champion.phase_three_hp) - 1
	fighter.refresh_phase()
	assert_eq(fighter.phase, 3)
	assert_eq(fighter.active_personality(), champion.phase_three_personality,
			"a cornered champion must fight with a different head")
	assert_true(fighter.active_personality().aggression
			+ fighter.active_personality().wounded_fury
			> champion.personality.aggression,
			"the shift must be toward MORE pressure, not less")
	fighter.free()


func test_phases_never_go_backwards() -> void:
	var fighter := CombatFixtures.make_combatant(_champion(ORZHA))
	fighter.current_hp = roundi(fighter.max_hp * 0.2)
	fighter.refresh_phase()
	assert_eq(fighter.phase, 3)
	fighter.current_hp = fighter.max_hp
	fighter.refresh_phase()
	assert_eq(fighter.phase, 3,
			"healing out of a phase would flicker the banner and take a move away")
	fighter.free()


func test_a_crossing_is_announced_once() -> void:
	var fighter := CombatFixtures.make_combatant(_champion(ORZHA))
	var announced: Array[int] = []
	var handler := func(who: Combatant, phase: int) -> void:
		if who == fighter:
			announced.append(phase)
	EventBus.boss_phase_changed.connect(handler)
	fighter.take_direct_damage(fighter.max_hp - roundi(fighter.max_hp * 0.5))
	fighter.take_direct_damage(1)  # still phase two
	fighter.take_direct_damage(roundi(fighter.max_hp * 0.3))
	EventBus.boss_phase_changed.disconnect(handler)
	assert_eq(announced, [2, 3] as Array[int], "one announcement per crossing")
	fighter.free()


func test_both_champions_have_authored_phase_lines() -> void:
	for path: String in [MAULHILDA, ORZHA]:
		var champion: CharacterData = load(path)
		for phase: int in [2, 3]:
			var key: String = champion.phase_key(phase)
			assert_true(key != "", "%s has no line for phase %d" % [champion.id, phase])
			assert_true(TranslationServer.translate(key) != key,
					"%s is not translated" % key)


# --- Rivals -----------------------------------------------------------------

func test_every_region_fields_a_rival() -> void:
	for arena: ArenaData in ItemDB.all_arenas():
		assert_true(arena.rival != null, "%s has no recurring rival" % arena.id)
		if arena.rival == null:
			continue
		assert_true(arena.rival.weapon != null)
		assert_true(arena.rival.personality != null, "a rival needs a head of their own")
		assert_true(TranslationServer.translate("%s.name" % arena.rival.id)
				!= "%s.name" % arena.rival.id, "%s has no name string" % arena.rival.id)


func test_a_rival_who_is_winning_turns_up_better_armed() -> void:
	var arena: ArenaData = _gravelmaw()
	var profile: PlayerProfile = PlayerProfile.create_default()
	profile.level = 6
	var even: CharacterData = RivalService.build(profile, arena)

	profile.rival_score[arena.rival.id] = -2  # the rival is two ahead
	var winning: CharacterData = RivalService.build(profile, arena)
	assert_true(winning.weapon.tier > even.weapon.tier,
			"a rival on a winning streak must bring better steel")
	assert_eq(winning.weapon.weapon_class, even.weapon.weapon_class,
			"...but never change fighting style")
	assert_true(winning.level >= even.level)


func test_a_beaten_rival_shows_it() -> void:
	var arena: ArenaData = _gravelmaw()
	var profile: PlayerProfile = PlayerProfile.create_default()
	profile.level = 6
	var even: CharacterData = RivalService.build(profile, arena)
	profile.rival_score[arena.rival.id] = 2  # the player is two ahead
	var beaten: CharacterData = RivalService.build(profile, arena)
	assert_true(beaten.armour_pieces.size() < even.armour_pieces.size(),
			"a beaten rival should be visibly short a piece of kit")
	assert_true(beaten.level <= even.level)


func test_a_rival_remembers_what_they_fought_with() -> void:
	var arena: ArenaData = _gravelmaw()
	var profile: PlayerProfile = PlayerProfile.create_default()
	profile.level = 6
	profile.rival_weapon[arena.rival.id] = &"weapon.iron_longsword"
	var remembered: CharacterData = RivalService.build(profile, arena)
	assert_eq(remembered.weapon.id, &"weapon.iron_longsword",
			"the rival opens with the weapon they were last seen carrying")

	# An id that no longer exists must not silently arm them with a fallback.
	profile.rival_weapon[arena.rival.id] = &"weapon.deleted_in_a_patch"
	var fallback: CharacterData = RivalService.build(profile, arena)
	assert_eq(fallback.weapon.id, arena.rival.weapon.id,
			"a stale memory falls back to the rival's own template weapon")


func test_building_a_rival_never_mutates_the_template() -> void:
	var arena: ArenaData = _gravelmaw()
	var profile: PlayerProfile = PlayerProfile.create_default()
	profile.level = 8
	profile.rival_score[arena.rival.id] = -2
	var before_weapon: StringName = arena.rival.weapon.id
	var before_armour: int = arena.rival.armour_pieces.size()
	RivalService.build(profile, arena)
	RivalService.build(profile, arena)
	assert_eq(arena.rival.weapon.id, before_weapon, "the template must stay pristine")
	assert_eq(arena.rival.armour_pieces.size(), before_armour)


func test_the_record_tracks_both_directions_and_the_margin_is_capped() -> void:
	var profile: PlayerProfile = PlayerProfile.create_default()
	var id := &"character.rival_grissa"
	RivalService.record_result(profile, id, true, &"weapon.bronze_gladius")
	assert_eq(RivalService.score(profile, id), 1)
	assert_eq(StringName(profile.rival_weapon[id]), &"weapon.bronze_gladius")
	RivalService.record_result(profile, id, false, &"weapon.iron_longsword")
	RivalService.record_result(profile, id, false, &"weapon.iron_longsword")
	assert_eq(RivalService.score(profile, id), -1)
	for _i in 10:
		RivalService.record_result(profile, id, false, &"weapon.iron_longsword")
	assert_true(RivalService.momentum(profile, id) <= RivalService.MOMENTUM_CAP,
			"a long losing streak must not create an unbeatable rival")


func test_rivals_stay_away_until_the_debut_is_over() -> void:
	var arena: ArenaData = _gravelmaw()
	var profile: PlayerProfile = PlayerProfile.create_default()
	profile.victories = 0
	RngService.set_seed(11)
	for _i in 20:
		assert_false(RivalService.should_appear(profile, arena),
				"the debut arc belongs to the player alone")
	profile.victories = RivalService.FIRST_APPEARANCE_AFTER_VICTORIES
	var appearances: int = 0
	for _i in 200:
		if RivalService.should_appear(profile, arena):
			appearances += 1
	assert_true(appearances > 0, "rivals must actually turn up")
	assert_true(appearances < 200, "...but not every single duel")


func test_standing_line_matches_the_record() -> void:
	var profile: PlayerProfile = PlayerProfile.create_default()
	var id := &"character.rival_grissa"
	assert_eq(RivalService.standing_key(profile, id), "rival.standing_even")
	profile.rival_score[id] = 3
	assert_eq(RivalService.standing_key(profile, id), "rival.standing_ahead")
	profile.rival_score[id] = -3
	assert_eq(RivalService.standing_key(profile, id), "rival.standing_behind")
	for key: String in ["rival.standing_even", "rival.standing_ahead", "rival.standing_behind"]:
		assert_true(TranslationServer.translate(key) != key, "%s is not translated" % key)


# --- Persistence (save v7) --------------------------------------------------

func test_the_rivalry_record_survives_a_round_trip() -> void:
	var profile: PlayerProfile = PlayerProfile.create_default()
	profile.rival_score[&"character.rival_grissa"] = -2
	profile.rival_weapon[&"character.rival_grissa"] = &"weapon.iron_longsword"
	var restored: PlayerProfile = PlayerProfile.from_dict(profile.to_dict())
	assert_eq(RivalService.score(restored, &"character.rival_grissa"), -2)
	assert_eq(StringName(restored.rival_weapon[&"character.rival_grissa"]),
			&"weapon.iron_longsword",
			"JSON keys come back as strings — they must be re-typed on load")


func test_a_v6_save_upgrades_without_losing_anything() -> void:
	var v6: Dictionary = {
		"save_version": 6,
		"profile": {"character_name": "Old Hand", "level": 9, "gold": 300},
	}
	var migrated: Dictionary = SaveManager._migrate_v6_to_v7(v6)
	var fields: Dictionary = migrated["profile"]
	assert_eq(fields["character_name"], "Old Hand", "existing fields must survive")
	assert_eq(fields["level"], 9)
	assert_true(fields.has("rival_score") and fields.has("rival_weapon"))
	assert_true((fields["rival_score"] as Dictionary).is_empty(),
			"a returning gladiator simply has no history with anyone yet")
	assert_eq(SaveManager.SAVE_VERSION, 7, "the version must be bumped with the format")
