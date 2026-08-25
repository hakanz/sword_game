class_name CombatResolver
## Pure combat-action resolution: validation guard, resource spending,
## strikes, stances, movement, rest, anti-stall counters. NO presentation —
## the CombatController wraps this with animation/audio/VFX, and the §35
## battle simulator drives it headlessly. One implementation, two consumers
## (charter §6: nothing re-implements combat rules).


## Energy paid back by Bulwark Reserve on a Defend (V2 §52.3).
const DEFEND_ENERGY_REFUND: int = 6


## Extra status stacks this fighter's kit grants (Venom Mastery).
static func _bonus_stacks(actor: Combatant) -> int:
	return 1 if actor.has_unique(Enums.UniqueEffect.VENOM_MASTERY) else 0


## Executes a decision, mutating actor/foe/ctx state. Returns the record the
## HUD/simulator read. Callers must pre-validate via CombatAction (asserted).
static func execute(
		actor: Combatant, foe: Combatant, ctx: CombatContext,
		decision: CombatDecision) -> ActionResult:
	var type: Enums.ActionType = decision.type
	if type == Enums.ActionType.SKILL:
		assert(CombatAction.is_skill_valid(decision.skill, actor, ctx),
				"Invalid skill reached execution: %s" % decision.skill.id)
	else:
		assert(CombatAction.is_valid(type, actor, ctx),
				"Invalid action reached execution: %s" % Enums.ActionType.keys()[type])

	var result := ActionResult.new()
	result.actor = actor
	result.action = type
	result.distance_after = ctx.band()

	if type == Enums.ActionType.SKILL:
		result.skill = decision.skill
		actor.spend_energy(decision.skill.energy_cost)
		actor.spend_mana(decision.skill.mana_cost)
		actor.set_cooldown(decision.skill.id, decision.skill.cooldown_rounds)
		if decision.skill.target == SkillData.Target.SELF:
			if decision.skill.applies_status != null:
				# Self-buffs keep their own ceiling: Venom Mastery is about
				# what you put ON the other fighter, not your own war cry.
				StatusEffectSystem.apply(actor, decision.skill.applies_status)
				result.applied_status = decision.skill.applies_status
		else:
			result.target = foe
			_resolve_strike(actor, foe, result, decision.skill.power_multiplier,
					decision.skill.accuracy_mod, decision.skill.armour_pen_bonus,
					decision.skill.applies_status)
	else:
		actor.spend_energy(CombatAction.energy_cost(type, actor))
		match type:
			Enums.ActionType.ATTACK:
				result.target = foe
				_resolve_strike(actor, foe, result, 1.0, 0, 0.0, null)
			Enums.ActionType.DEFEND:
				actor.set_stance(Enums.Stance.DEFENDING)
				# Bulwark Reserve (V2 §52.3): a guarded stance pays back
				# Energy, making Defend a real option for a heavy build.
				if actor.has_unique(Enums.UniqueEffect.BULWARK_RESERVE):
					result.energy_restored = actor.restore_energy(DEFEND_ENERGY_REFUND)
			Enums.ActionType.APPROACH:
				# Movement is personal: ONLY the acting fighter steps.
				ctx.approach(actor)
				result.distance_after = ctx.band()
			Enums.ActionType.RETREAT:
				ctx.retreat(actor)
				result.distance_after = ctx.band()
			Enums.ActionType.REST:
				result.energy_restored = actor.restore_energy(
						roundi(actor.max_energy * CombatTuning.REST_ENERGY_RESTORE_FRACTION))
				result.hp_restored = actor.heal(
						roundi(actor.max_hp * CombatTuning.REST_HP_RESTORE_FRACTION))
			Enums.ActionType.SWITCH_WEAPON:
				actor.switch_weapon()

	# Leaky defend counter (not a hard reset): alternating defend/attack
	# patterns still accumulate stall pressure instead of dodging the decay.
	actor.consecutive_defends = actor.consecutive_defends + 1 \
			if type == Enums.ActionType.DEFEND else maxi(actor.consecutive_defends - 1, 0)
	if type == Enums.ActionType.RETREAT:
		actor.total_retreats += 1

	# Effectiveness tally (session-5 XP design): every action counts the
	# denominator; only strikes that actually landed count the numerator.
	actor.actions_taken += 1
	if result.hit:
		actor.hits_landed += 1
	return result


## Shared strike resolution: hit roll -> damage pipeline -> on-hit status.
static func _resolve_strike(
		actor: Combatant, foe: Combatant, result: ActionResult,
		multiplier: float, accuracy_mod: int, pen_bonus: float,
		on_hit_status: StatusEffectData) -> void:
	result.hit_chance = HitCalculator.hit_chance(actor, foe, accuracy_mod)
	result.hit = RngService.chance(result.hit_chance)
	# A loosed arrow is spent whether it lands or not.
	if actor.get_weapon().is_ranged():
		actor.arrows = maxi(actor.arrows - 1, 0)
	if not result.hit:
		return
	# Critical step of the §15 pipeline (after the skill multiplier): a rare
	# heavy blow for BOTH fighters — odds come from the weapon plus the
	# wielder's class-matched attribute (HitCalculator.crit_chance_for).
	result.crit = RngService.chance(actor.crit_chance())
	var crit_multiplier: float = CombatTuning.CRIT_MULTIPLIER if result.crit else 1.0
	# Relentless Edge (V2 §52.3): a crit ticks the wielder's cooldowns down.
	if result.crit and actor.has_unique(Enums.UniqueEffect.RELENTLESS_EDGE):
		actor.reduce_cooldowns(1)
	var raw: int = DamageCalculator.roll_attack_damage(actor, multiplier * crit_multiplier)
	var mitigation := DamageCalculator.compute_mitigation(
			raw,
			foe.get_resistance(actor.get_weapon().damage_type),
			foe.stance == Enums.Stance.DEFENDING,
			clampf(actor.armour_penetration() + pen_bonus, 0.0, 1.0),
			foe.armour_current)
	foe.take_damage(mitigation)
	actor.damage_dealt_total += mitigation.after_stance
	result.mitigation = mitigation
	result.killed = not foe.is_alive()
	if on_hit_status != null and foe.is_alive():
		StatusEffectSystem.apply(foe, on_hit_status, _bonus_stacks(actor))
		result.applied_status = on_hit_status
