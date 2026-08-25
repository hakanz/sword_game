class_name StatusEffectSystem
## The one reusable status-effect engine (charter §18). Pure logic over
## Combatant.status_effects; the controller calls tick_turn_end() in the
## STATUS_RESOLUTION step, calculators query the modifier sums.


class TickResult:
	extends RefCounted
	var effect: StatusEffectData = null
	var damage: int = 0
	var healing: int = 0
	var expired: bool = false


## Applies (or stacks/refreshes) an effect. Re-applying refreshes duration
## and adds a stack up to max_stacks. `bonus_stacks` raises that ceiling for
## THIS application — the hook Venom Mastery (V2 §52.3) rides on; the effect
## resource itself is never mutated.
static func apply(target: Combatant, effect: StatusEffectData,
		bonus_stacks: int = 0) -> StatusEffectInstance:
	var existing: StatusEffectInstance = find(target, effect.id)
	if existing != null:
		existing.stacks = mini(existing.stacks + 1, effect.max_stacks + maxi(bonus_stacks, 0))
		existing.remaining_rounds = effect.duration_rounds
		EventBus.status_applied.emit(target, existing)
		return existing
	var instance := StatusEffectInstance.new(effect)
	target.status_effects.append(instance)
	EventBus.status_applied.emit(target, instance)
	return instance


static func find(target: Combatant, effect_id: StringName) -> StatusEffectInstance:
	for instance in target.status_effects:
		if instance.data.id == effect_id:
			return instance
	return null


## End-of-turn resolution for one combatant: periodic damage/healing, then
## duration countdown and expiry. Returns what happened for logging/UI.
static func tick_turn_end(combatant: Combatant) -> Array[TickResult]:
	var results: Array[TickResult] = []
	var expired: Array[StatusEffectInstance] = []
	for instance in combatant.status_effects:
		var result := TickResult.new()
		result.effect = instance.data
		if instance.data.periodic_damage > 0 and combatant.is_alive():
			var raw: int = instance.data.periodic_damage * instance.stacks
			result.damage = DamageCalculator.compute_direct_damage(
					raw, combatant.get_resistance(instance.data.periodic_damage_type))
			combatant.take_direct_damage(result.damage)
		if instance.data.periodic_heal > 0 and combatant.is_alive():
			result.healing = combatant.heal(instance.data.periodic_heal * instance.stacks)
		instance.remaining_rounds -= 1
		if instance.remaining_rounds <= 0:
			result.expired = true
			expired.append(instance)
		results.append(result)
	for instance in expired:
		combatant.status_effects.erase(instance)
		EventBus.status_expired.emit(combatant, instance.data)
	return results


# --- Modifier aggregation (queried by HitCalculator / DamageCalculator) -----

static func accuracy_mod(combatant: Combatant) -> int:
	var total: int = 0
	for instance in combatant.status_effects:
		total += instance.data.accuracy_mod * instance.stacks
	return total


static func defence_mod(combatant: Combatant) -> int:
	var total: int = 0
	for instance in combatant.status_effects:
		total += instance.data.defence_mod * instance.stacks
	return total


static func evasion_mod(combatant: Combatant) -> int:
	var total: int = 0
	for instance in combatant.status_effects:
		total += instance.data.evasion_mod * instance.stacks
	return total


static func damage_dealt_multiplier(combatant: Combatant) -> float:
	var multiplier: float = 1.0
	for instance in combatant.status_effects:
		for _stack in instance.stacks:
			multiplier *= instance.data.damage_dealt_mult
	return multiplier


static func is_stunned(combatant: Combatant) -> bool:
	for instance in combatant.status_effects:
		if instance.data.skips_turn:
			return true
	return false
