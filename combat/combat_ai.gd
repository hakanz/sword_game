class_name CombatAI
## Utility-based enemy AI (charter §20) — NEVER uniform-random selection.
## Every valid action gets a utility score in a single currency: EXPECTED
## DAMAGE (dealt, or incoming-damage prevented). That keeps offense and
## defense comparable, so no action can drift into always-dominant:
##   attack  ~ hit_chance * expected_damage * aggression + kill_bonus - cost
##   defend  ~ (incoming if I stand - incoming if I guard) * caution
##   retreat ~ escape value when hurt / kiting value for ranged builds
## Repeated DEFEND/RETREAT decay via consecutive-use counters — a fighter can
## turtle or flee for a moment, never forever (anti-stall, see docs/ai.md).
## A tiny seeded jitter (< 0.75) only breaks near-ties.
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
## Crowd impatience: from this round on, ATTACK gains flat utility per round.
## Guarantees every duel converges long before the MAX_ROUNDS failsafe.
const IMPATIENCE_START_ROUND: int = 20
const IMPATIENCE_PER_ROUND: float = 0.15
## Each retreat this combat makes the next retreat this much less appealing.
const RETREAT_FATIGUE: float = 0.5


static func choose_action(actor: Combatant, foe: Combatant, ctx: CombatContext) -> Enums.ActionType:
	var personality: AIPersonality = actor.data.personality
	if personality == null:
		# Player character driven by AI (smoke test): behave like a balanced fighter.
		personality = AIPersonality.new()

	var scores: Dictionary = {}
	for type: Enums.ActionType in Enums.ActionType.values():
		if CombatAction.is_valid(type, actor, ctx):
			scores[type] = _score(type, actor, foe, ctx, personality) \
					+ RngService.randf_range(0.0, TIE_BREAK_JITTER)

	assert(not scores.is_empty(), "CombatAI: no valid actions (DEFEND should always be reachable)")

	var best_type: Enums.ActionType = scores.keys()[0]
	var best_score: float = scores[best_type]
	for type: Enums.ActionType in scores.keys():
		if scores[type] > best_score:
			best_score = scores[type]
			best_type = type

	EventBus.ai_scores_computed.emit(actor.display_name(), _debug_scores(scores))
	return best_type


static func _score(
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
			var chance: float = HitCalculator.hit_chance(actor, foe)
			var est: DamageCalculator.MitigationResult = _estimate_hit(actor, foe,
					foe.stance == Enums.Stance.DEFENDING)
			var expected: float = chance * float(est.hp_damage + est.absorbed)
			var foe_hp_fraction: float = float(foe.current_hp) / float(foe.max_hp)
			var finisher: float = 1.0 + (1.0 - foe_hp_fraction) * FINISHER_SCALING
			var kill_bonus: float = 0.0
			if est.hp_damage >= foe.current_hp:
				kill_bonus = 50.0 * chance
			return expected * p.aggression * finisher + kill_bonus + _impatience(ctx) \
					- attack_cost * ENERGY_COST_WEIGHT * p.resource_care

		Enums.ActionType.APPROACH:
			# Bonus ONLY when too far to fire. can_attack_from() is also false
			# when too CLOSE (inside a ranged weapon's minimum band) — closing
			# further would be exactly wrong there (retreat handles it).
			if ctx.distance > actor.get_weapon().range_max:
				return 15.0 * p.aggression
			return 1.0

		Enums.ActionType.RETREAT:
			var value: float = 0.0
			var weapon: WeaponData = actor.get_weapon()
			if hp_fraction < 0.3:
				value += 8.0 * p.caution
			if ctx.distance < weapon.range_min:
				# Inside minimum range — opening distance is the only way to fire.
				value += 14.0
			elif weapon.range_max >= Enums.DistanceBand.MEDIUM \
					and ctx.distance <= Enums.DistanceBand.CLOSE:
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

		_:
			return 0.0


static func _impatience(ctx: CombatContext) -> float:
	return maxf(0.0, (ctx.round_number - IMPATIENCE_START_ROUND) * IMPATIENCE_PER_ROUND)


## Average-damage mitigation estimate for attacker hitting target.
static func _estimate_hit(
		attacker: Combatant, target: Combatant,
		target_defending: bool) -> DamageCalculator.MitigationResult:
	return DamageCalculator.compute_mitigation(
			roundi(DamageCalculator.average_attack_damage(attacker)),
			target.get_resistance(attacker.get_weapon().damage_type),
			target_defending,
			attacker.get_weapon().armour_penetration,
			target.armour_current)


## Expected damage `attacker` lands on `target` next turn at the current
## distance (0 when out of range), with `target` optionally guarding.
static func _expected_incoming(
		attacker: Combatant, target: Combatant,
		target_defending: bool, ctx: CombatContext) -> float:
	if not attacker.get_weapon().can_attack_from(ctx.distance):
		return 0.0
	var stance: int = Enums.Stance.DEFENDING if target_defending else Enums.Stance.NEUTRAL
	var chance: float = HitCalculator.hit_chance(attacker, target, 0, stance)
	var est: DamageCalculator.MitigationResult = _estimate_hit(attacker, target, target_defending)
	return chance * float(est.hp_damage + est.absorbed)


static func _debug_scores(scores: Dictionary) -> Dictionary:
	var readable: Dictionary = {}
	for type: Enums.ActionType in scores.keys():
		readable[Enums.ActionType.keys()[type]] = snappedf(scores[type], 0.1)
	return readable
