class_name DamageCalculator
## Damage pipeline (charter §15, strict order):
## Raw -> Weapon Scaling -> Attribute Scaling -> [Skill Multiplier] ->
## [Critical] -> Damage Type Modifiers -> Resistance -> Armour -> Shield -> HP
##
## Combat-prototype scope: no crits, no skill multipliers, no shields yet —
## those steps slot into compute_mitigation()/roll_attack_damage() when their
## phases land. Excess damage is NEVER silently discarded: when the armour
## pool empties mid-hit, the remainder carries into HP.
##
## compute_mitigation() is PURE (no mutation) so it is trivially unit-testable;
## Combatant.take_damage() applies the result.


class MitigationResult:
	extends RefCounted
	var raw_damage: int = 0
	## After resistance percentage (clamped 0-100%).
	var after_resistance: int = 0
	## After defend-stance reduction — total damage the target must absorb.
	var after_stance: int = 0
	## Portion that bypassed armour via armour penetration.
	var bypass: int = 0
	## Portion removed from the armour pool.
	var absorbed: int = 0
	## Portion that reached HP (bypass + armour overflow).
	var hp_damage: int = 0
	var armour_remaining: int = 0


## Rolls raw attack damage: weapon roll + attribute scaling, then the
## skill multiplier step (1.0 for normal attacks) and status multipliers
## (Rage and friends) — matching the charter §15 pipeline order.
static func roll_attack_damage(attacker: Combatant, skill_multiplier: float = 1.0) -> int:
	var weapon: WeaponData = attacker.get_weapon()
	var weapon_roll: int = RngService.randi_range(weapon.damage_min, weapon.damage_max)
	var base: int = weapon_roll + ProgressionCalculator.attribute_damage_bonus(
			attacker.data.attributes, weapon.weapon_class)
	return roundi(base * skill_multiplier * StatusEffectSystem.damage_dealt_multiplier(attacker))


## Expected value of roll_attack_damage — used by AI estimates and tooltips.
static func average_attack_damage(attacker: Combatant, skill_multiplier: float = 1.0) -> float:
	var weapon: WeaponData = attacker.get_weapon()
	var base: float = weapon.average_damage() + ProgressionCalculator.attribute_damage_bonus(
			attacker.data.attributes, weapon.weapon_class)
	return base * skill_multiplier * StatusEffectSystem.damage_dealt_multiplier(attacker)


## Direct-to-HP damage (status DoTs): resistance applies, armour does not.
static func compute_direct_damage(raw_damage: int, resistance: float) -> int:
	return roundi(maxi(raw_damage, 0) * (1.0 - clampf(resistance, 0.0, 1.0)))


## Pure mitigation math. `resistance` is the target's resistance fraction to
## the incoming damage type (0-1); `armour_penetration` is the fraction of
## post-resistance damage that ignores the armour pool (0-1).
static func compute_mitigation(
		raw_damage: int,
		resistance: float,
		defending: bool,
		armour_penetration: float,
		armour_current: int) -> MitigationResult:
	var result := MitigationResult.new()
	result.raw_damage = maxi(raw_damage, 0)

	result.after_resistance = roundi(result.raw_damage * (1.0 - clampf(resistance, 0.0, 1.0)))

	result.after_stance = result.after_resistance
	if defending:
		result.after_stance = roundi(result.after_resistance * (1.0 - CombatTuning.DEFEND_DAMAGE_REDUCTION))

	result.bypass = roundi(result.after_stance * clampf(armour_penetration, 0.0, 1.0))
	result.absorbed = mini(armour_current, result.after_stance - result.bypass)
	result.hp_damage = result.after_stance - result.absorbed
	result.armour_remaining = armour_current - result.absorbed
	return result
