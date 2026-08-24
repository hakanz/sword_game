extends TestCase
## Skill validation, learning, and AI usage (charter §17).

const CRUSHING: SkillData = preload("res://data/skills/crushing_blow.tres")
const GUTTER_LUNGE: SkillData = preload("res://data/skills/gutter_lunge.tres")
const SECOND_WIND: SkillData = preload("res://data/skills/second_wind.tres")
const PINNING_SHOT: SkillData = preload("res://data/skills/pinning_shot.tres")


func test_registry_serves_all_skills() -> void:
	assert_true(ItemDB.all_skills().size() >= 10, "MVP requires 10 combat skills")
	assert_eq(ItemDB.skill(&"skill.crushing_blow").id, &"skill.crushing_blow")


func test_skill_validation_rules() -> void:
	var fighter := CombatFixtures.make_combatant()
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(fighter, foe, 1)

	assert_eq(CombatAction.skill_invalid_reason(CRUSHING, fighter, ctx), "",
			"sword fighter adjacent with full energy can use Crushing Blow")
	fighter.set_cooldown(CRUSHING.id, 2)
	assert_eq(CombatAction.skill_invalid_reason(CRUSHING, fighter, ctx), "combat.hint.cooldown")
	fighter.cooldowns.clear()
	fighter.current_energy = CRUSHING.energy_cost - 1
	assert_eq(CombatAction.skill_invalid_reason(CRUSHING, fighter, ctx), "combat.hint.no_energy")
	fighter.current_energy = fighter.max_energy
	assert_eq(CombatAction.skill_invalid_reason(PINNING_SHOT, fighter, ctx),
			"combat.hint.wrong_weapon", "bow skill must refuse a sword")
	fighter.free()
	foe.free()


func test_skills_follow_the_adjacent_rule() -> void:
	# Session-2 directive: no attacks from distance — strike skills included.
	var fighter := CombatFixtures.make_combatant()
	var foe := CombatFixtures.make_combatant()
	var far := CombatFixtures.make_context(fighter, foe, 2)
	assert_eq(CombatAction.skill_invalid_reason(CRUSHING, fighter, far), "combat.hint.too_far")
	assert_eq(CombatAction.skill_invalid_reason(GUTTER_LUNGE, fighter, far), "combat.hint.too_far")
	var adjacent := CombatFixtures.make_context(fighter, foe, 1)
	assert_eq(CombatAction.skill_invalid_reason(GUTTER_LUNGE, fighter, adjacent), "")
	assert_true(GUTTER_LUNGE.accuracy_mod > 0,
			"reworked Gutter Lunge trades reach for precision")
	fighter.free()
	foe.free()


func test_cooldown_ticks_down() -> void:
	var fighter := CombatFixtures.make_combatant()
	fighter.set_cooldown(CRUSHING.id, 2)
	fighter.tick_cooldowns()
	assert_eq(fighter.cooldown_remaining(CRUSHING.id), 1)
	fighter.tick_cooldowns()
	assert_eq(fighter.cooldown_remaining(CRUSHING.id), 0)
	fighter.free()


func test_learning_rules() -> void:
	var profile := PlayerProfile.create_default()
	profile.skill_points = 0
	assert_eq(SkillService.learn_block_reason(profile, CRUSHING), "skills.hint.no_points")
	profile.skill_points = 1
	assert_eq(SkillService.learn_block_reason(profile, CRUSHING), "")
	assert_true(SkillService.learn(profile, CRUSHING))
	assert_eq(profile.skill_points, 0, "learning consumes the point")
	assert_true(profile.known_skill_ids.has(CRUSHING.id))
	assert_eq(SkillService.learn_block_reason(profile, CRUSHING), "skills.hint.known")
	profile.skill_points = 5
	var high_level: SkillData = ItemDB.skill(&"skill.focused_loose")  # req lvl 4
	assert_eq(SkillService.learn_block_reason(profile, high_level), "equip.requires_level")


func test_known_skills_reach_combat() -> void:
	var profile := PlayerProfile.create_default()
	profile.skill_points = 1
	SkillService.learn(profile, CRUSHING)
	var data := profile.to_character_data()
	assert_eq(data.skills.size(), 1)
	assert_eq(data.skills[0].id, CRUSHING.id)


func test_ai_prefers_a_clearly_better_skill() -> void:
	RngService.set_seed(11)
	var fighter := CombatFixtures.make_combatant(CombatFixtures.make_character())
	fighter.data.skills = [CRUSHING]
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(fighter, foe, 1)
	var decision := CombatAI.choose_action(fighter, foe, ctx)
	assert_eq(decision.type, Enums.ActionType.SKILL,
			"a 1.6x multiplier should beat a plain attack")
	assert_eq(decision.skill.id, CRUSHING.id)
	fighter.free()
	foe.free()


func test_ai_heals_when_hurt() -> void:
	RngService.set_seed(11)
	var fighter := CombatFixtures.make_combatant(CombatFixtures.make_character())
	fighter.data.skills = [SECOND_WIND]
	fighter.current_hp = roundi(fighter.max_hp * 0.2)
	var foe := CombatFixtures.make_combatant()
	var ctx := CombatFixtures.make_context(fighter, foe, 1)
	var decision := CombatAI.choose_action(fighter, foe, ctx)
	assert_eq(decision.type, Enums.ActionType.SKILL, "badly hurt fighter should trigger Second Wind")
	assert_eq(decision.skill.id, SECOND_WIND.id)
	fighter.free()
	foe.free()
