class_name CombatAI
## Utility-based enemy AI (charter §20) — NEVER uniform-random selection.
## Every valid action (base actions AND known skills) gets a utility score in
## a single currency: EXPECTED DAMAGE dealt or prevented. See docs/ai.md for
## the full formula table and the anti-stall design notes.
##
## Debug: scores are emitted on EventBus.ai_scores_computed for the
## AI-decision overlay (charter §34).

## Fraction of an action's energy cost subtracted from its score.
const ENERGY_COST_WEIGHT: float = 0.15
const TIE_BREAK_JITTER: float = 0.75
## Defend is only worth its mitigation if the foe actually swings next turn —
## they may reposition, rest, or turtle instead. Discounting by this factor
## keeps mutual-defend from being an equilibrium (see docs/ai.md).
const DEFEND_FOE_SWING_PROBABILITY: float = 0.65
## Blood scent: attacks scale up as the foe's HP fraction drops (finish the
## wounded instead of trading pot-shots with a fleeing turtle).
const FINISHER_SCALING: float = 0.8
## Crowd impatience: from this round on, offense gains flat utility per round.
## Guarantees every duel converges long before the MAX_ROUNDS failsafe.
const IMPATIENCE_START_ROUND: int = 20
const IMPATIENCE_PER_ROUND: float = 0.15
## Each retreat this combat makes the next retreat this much less appealing.
const RETREAT_FATIGUE: float = 0.5
## Flat bonus for landing a status the foe doesn't already carry.
const NEW_STATUS_VALUE: float = 6.0


static func choose_action(actor: Combatant, foe: Combatant, ctx: CombatContext) -> CombatDecision:
	var personality: AIPersonality = actor.data.personality
	if personality == null:
		# Player character driven by AI (smoke test): behave like a balanced fighter.
		personality = AIPersonality.new()

	var best: CombatDecision = null
	var best_score: float = -INF
	var debug: Dictionary = {}

	for type: Enums.ActionType in Enums.ActionType.values():
		if type == Enums.ActionType.SKILL:
			continue
		if not CombatAction.is_valid(type, actor, ctx):
			continue
		var score: float = _score_base(type, actor, foe, ctx, personality) \
				+ RngService.randf_range(0.0, TIE_BREAK_JITTER)
		debug[Enums.ActionType.keys()[type]] = snappedf(score, 0.1)
		if score > best_score:
			best_score = score
			best = CombatDecision.base_action(type)

	for skill in actor.get_skills():
		if not CombatAction.is_skill_valid(skill, actor, ctx):
			continue
		var score: float = _score_skill(skill, actor, foe, ctx, personality) \
				+ RngService.randf_range(0.0, TIE_BREAK_JITTER)
		debug[String(skill.id)] = snappedf(score, 0.1)
		if score > best_score:
			best_score = score
			best = CombatDecision.skill_action(skill)

	assert(best != null, "CombatAI: no valid actions (DEFEND should always be reachable)")
	EventBus.ai_scores_computed.emit(actor.display_name(), debug)
	return best


static func _score_base(
		type: Enums.ActionType,
		actor: Combatant,
		foe: Combatant,
		ctx: CombatContext,
		p: AIPersonality) -> float:
	var hp_fraction: float = float(actor.current_hp) / float(actor.max_hp)
	var energy_fraction: float = float(actor.current_energy) / float(actor.max_energy)
	var attack_cost: int = CombatAction.energy_cost(Enums.ActionType.ATTACK, actor)

	match type:
		Enums.ActionType.ATTACK:
			return _score_strike(actor, foe, ctx, p, 1.0, 0, 0.0) \
					- attack_cost * ENERGY_COST_WEIGHT * p.resource_care

		Enums.ActionType.APPROACH:
			# Bonus ONLY when too far to fire. can_attack_from() is also false
			# when too CLOSE (inside a ranged weapon's minimum band) — closing
			# further would be exactly wrong there (retreat handles it).
			if ctx.band() > actor.get_weapon().range_max:
				return 15.0 * _aggression_now(actor, foe, p)
			return 1.0

		Enums.ActionType.RETREAT:
			var value: float = 0.0
			var weapon: WeaponData = actor.get_weapon()
			if hp_fraction < 0.3:
				value += 8.0 * p.caution
			if ctx.band() < weapon.range_min:
				# Inside minimum range — opening distance is the only way to fire.
				value += 14.0
			elif weapon.range_max >= Enums.DistanceBand.MEDIUM \
					and ctx.band() <= Enums.DistanceBand.CLOSE:
				# Kiting instinct: ranged builds prefer space over brawling.
				value += 8.0
			# Retreat fatigue: each flee this combat makes the next one less
			# appealing — a hurt turtle cannot run laps forever.
			return value / (1.0 + actor.total_retreats * RETREAT_FATIGUE)

		Enums.ActionType.DEFEND:
			# Worth the incoming damage it is expected to prevent, discounted
			# by the chance the foe actually attacks next turn.
			var incoming_open: float = _expected_incoming(foe, actor, false, ctx)
			var incoming_guarded: float = _expected_incoming(foe, actor, true, ctx)
			var value: float = (incoming_open - incoming_guarded) \
					* DEFEND_FOE_SWING_PROBABILITY * p.caution
			value += 3.0 * (1.0 - hp_fraction)  # desperation nudge when hurt
			# Anti-stall decay: two cautious fighters must never deadlock.
			return value / (1.0 + actor.consecutive_defends)

		Enums.ActionType.REST:
			if actor.current_energy < attack_cost:
				# Cannot attack at all: recovering is urgent.
				return 30.0 * maxf(p.resource_care, 0.5)
			return (1.0 - energy_fraction) * 10.0 * p.resource_care

		Enums.ActionType.SWITCH_WEAPON:
			# Draw whichever weapon actually works from here (archer flow:
			# open on the knife, switch to the bow to shoot, back to steel
			# when the quiver empties or the foe closes in).
			var current: WeaponData = actor.get_weapon()
			var other: WeaponData = actor.sidearm if actor.wielding_main else actor.main_weapon
			var current_usable: bool = current.can_attack_from(ctx.band()) \
					and (not current.is_ranged() or actor.arrows > 0)
			var other_usable: bool = other.can_attack_from(ctx.band()) \
					and (not other.is_ranged() or actor.arrows > 0)
			if other_usable and not current_usable:
				return 16.0 * _aggression_now(actor, foe, p)
			if not current_usable and other.is_ranged() and actor.arrows > 0:
				return 8.0  # draw the bow, then open distance to fire
			return 0.5

		_:
			return 0.0


static func _score_skill(
		skill: SkillData,
		actor: Combatant,
		foe: Combatant,
		ctx: CombatContext,
		p: AIPersonality) -> float:
	var hp_fraction: float = float(actor.current_hp) / float(actor.max_hp)
	var cost_penalty: float = skill.energy_cost * ENERGY_COST_WEIGHT * p.resource_care

	if skill.target == SkillData.Target.SELF:
		var effect: StatusEffectData = skill.applies_status
		if effect == null:
			return 0.0
		if StatusEffectSystem.find(actor, effect.id) != null:
			return 0.5 - cost_penalty  # refreshing an active buff is rarely urgent
		var value: float = 4.0
		if effect.periodic_heal > 0:
			value += 14.0 * (1.0 - hp_fraction)
		if effect.damage_dealt_mult > 1.0:
			# A damage buff is only good if we can actually reach the foe soon.
			var reach: float = 1.0 if actor.get_weapon().can_attack_from(ctx.band()) else 0.4
			value += 7.0 * _aggression_now(actor, foe, p) * reach
		return value - cost_penalty

	var value: float = _score_strike(actor, foe, ctx, p,
			skill.power_multiplier, skill.accuracy_mod, skill.armour_pen_bonus)
	if skill.applies_status != null \
			and StatusEffectSystem.find(foe, skill.applies_status.id) == null:
		value += NEW_STATUS_VALUE
	return value - cost_penalty


## Shared expected-value math for normal attacks and FOE skills.
static func _score_strike(
		actor: Combatant, foe: Combatant, ctx: CombatContext, p: AIPersonality,
		multiplier: float, accuracy_mod: int, pen_bonus: float) -> float:
	var chance: float = HitCalculator.hit_chance(actor, foe, accuracy_mod)
	var est: DamageCalculator.MitigationResult = _estimate_hit(actor, foe,
			foe.stance == Enums.Stance.DEFENDING, multiplier, pen_bonus)
	var expected: float = chance * float(est.hp_damage + est.absorbed)
	var foe_hp_fraction: float = float(foe.current_hp) / float(foe.max_hp)
	var finisher: float = 1.0 + (1.0 - foe_hp_fraction) * FINISHER_SCALING
	var kill_bonus: float = 0.0
	if est.hp_damage >= foe.current_hp:
		kill_bonus = 50.0 * chance
	# Temperament shifts with the state of the fight (V2 §53.1): a berserker
	# swings harder while bleeding, an opportunist while the foe is dying.
	# ONE formula, personality-weighted inputs — never a per-personality fork.
	return expected * _aggression_now(actor, foe, p) * finisher \
			+ kill_bonus + _impatience(ctx)


## Current aggression for this fighter against this foe.
static func _aggression_now(actor: Combatant, foe: Combatant, p: AIPersonality) -> float:
	return p.aggression_now(
			float(actor.current_hp) / float(actor.max_hp),
			float(foe.current_hp) / float(foe.max_hp))


static func _impatience(ctx: CombatContext) -> float:
	return maxf(0.0, (ctx.round_number - IMPATIENCE_START_ROUND) * IMPATIENCE_PER_ROUND)


## Average-damage mitigation estimate for attacker hitting target.
static func _estimate_hit(
		attacker: Combatant, target: Combatant, target_defending: bool,
		multiplier: float = 1.0, pen_bonus: float = 0.0) -> DamageCalculator.MitigationResult:
	return DamageCalculator.compute_mitigation(
			roundi(DamageCalculator.average_attack_damage(attacker, multiplier)),
			target.get_resistance(attacker.get_weapon().damage_type),
			target_defending,
			clampf(attacker.get_weapon().armour_penetration + pen_bonus, 0.0, 1.0),
			target.armour_current)


## Expected damage `attacker` lands on `target` next turn at the current
## distance (0 when out of range), with `target` optionally guarding.
static func _expected_incoming(
		attacker: Combatant, target: Combatant,
		target_defending: bool, ctx: CombatContext) -> float:
	if not attacker.get_weapon().can_attack_from(ctx.band()):
		return 0.0
	var stance: int = Enums.Stance.DEFENDING if target_defending else Enums.Stance.NEUTRAL
	var chance: float = HitCalculator.hit_chance(attacker, target, 0, stance)
	var est: DamageCalculator.MitigationResult = _estimate_hit(attacker, target, target_defending)
	return chance * float(est.hp_damage + est.absorbed)
