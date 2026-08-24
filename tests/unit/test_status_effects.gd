extends TestCase
## StatusEffectSystem: stacking, ticking, expiry, modifiers (charter §18).

const POISON: StatusEffectData = preload("res://data/status_effects/poison.tres")
const STUN: StatusEffectData = preload("res://data/status_effects/stun.tres")
const SLOW: StatusEffectData = preload("res://data/status_effects/slow.tres")
const RAGE: StatusEffectData = preload("res://data/status_effects/rage.tres")
const REGEN: StatusEffectData = preload("res://data/status_effects/regeneration.tres")


func test_apply_stacks_and_caps() -> void:
	var target := CombatFixtures.make_combatant()
	var instance := StatusEffectSystem.apply(target, POISON)
	assert_eq(instance.stacks, 1)
	assert_eq(instance.remaining_rounds, POISON.duration_rounds)
	instance.remaining_rounds = 1
	StatusEffectSystem.apply(target, POISON)
	assert_eq(instance.stacks, 2, "re-applying must stack")
	assert_eq(instance.remaining_rounds, POISON.duration_rounds, "re-applying refreshes duration")
	StatusEffectSystem.apply(target, POISON)
	StatusEffectSystem.apply(target, POISON)
	assert_eq(instance.stacks, POISON.max_stacks, "stacks must cap at max_stacks")
	assert_eq(target.status_effects.size(), 1, "same effect never duplicates entries")
	target.free()


func test_poison_ticks_scale_with_stacks() -> void:
	var target := CombatFixtures.make_combatant()
	var hp_before: int = target.current_hp
	StatusEffectSystem.apply(target, POISON)
	StatusEffectSystem.apply(target, POISON)
	var results := StatusEffectSystem.tick_turn_end(target)
	assert_eq(results.size(), 1)
	assert_eq(results[0].damage, POISON.periodic_damage * 2, "DoT scales per stack")
	assert_eq(target.current_hp, hp_before - POISON.periodic_damage * 2)
	target.free()


func test_effects_expire_after_duration() -> void:
	var target := CombatFixtures.make_combatant()
	StatusEffectSystem.apply(target, POISON)
	for _round in POISON.duration_rounds - 1:
		StatusEffectSystem.tick_turn_end(target)
		assert_eq(target.status_effects.size(), 1)
	var final_tick := StatusEffectSystem.tick_turn_end(target)
	assert_true(final_tick[0].expired, "last tick must mark expiry")
	assert_eq(target.status_effects.size(), 0, "expired effects are removed")
	target.free()


func test_regeneration_heals_and_caps() -> void:
	var target := CombatFixtures.make_combatant()
	target.current_hp = target.max_hp - 2
	StatusEffectSystem.apply(target, REGEN)
	var results := StatusEffectSystem.tick_turn_end(target)
	assert_eq(results[0].healing, 2, "healing must cap at max HP")
	assert_eq(target.current_hp, target.max_hp)
	target.free()


func test_dot_can_finish_a_fighter() -> void:
	var target := CombatFixtures.make_combatant()
	target.current_hp = 3
	StatusEffectSystem.apply(target, POISON)
	StatusEffectSystem.tick_turn_end(target)
	assert_false(target.is_alive(), "DoTs must be able to kill")
	assert_eq(target.current_hp, 0, "HP never goes negative")
	target.free()


func test_stun_flag_and_modifiers() -> void:
	var target := CombatFixtures.make_combatant()
	assert_false(StatusEffectSystem.is_stunned(target))
	StatusEffectSystem.apply(target, STUN)
	assert_true(StatusEffectSystem.is_stunned(target))
	StatusEffectSystem.apply(target, SLOW)
	assert_eq(StatusEffectSystem.evasion_mod(target), SLOW.evasion_mod)
	assert_eq(StatusEffectSystem.accuracy_mod(target), SLOW.accuracy_mod)
	StatusEffectSystem.apply(target, RAGE)
	assert_almost_eq(StatusEffectSystem.damage_dealt_multiplier(target),
			RAGE.damage_dealt_mult, 0.0001)
	target.free()


func test_slow_lowers_avoidance_in_hit_math() -> void:
	var attacker := CombatFixtures.make_combatant()
	var defender := CombatFixtures.make_combatant()
	var before: float = HitCalculator.hit_chance(attacker, defender)
	StatusEffectSystem.apply(defender, SLOW)
	var after: float = HitCalculator.hit_chance(attacker, defender)
	assert_true(after > before, "slowed defenders must be easier to hit")
	attacker.free()
	defender.free()


func test_rage_raises_damage_in_pipeline() -> void:
	var attacker := CombatFixtures.make_combatant()
	var base: float = DamageCalculator.average_attack_damage(attacker)
	StatusEffectSystem.apply(attacker, RAGE)
	assert_almost_eq(DamageCalculator.average_attack_damage(attacker),
			base * RAGE.damage_dealt_mult, 0.001,
			"status multipliers must flow through the damage pipeline")
	attacker.free()
