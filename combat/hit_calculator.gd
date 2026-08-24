class_name HitCalculator
## Hit-chance math (charter §15). Bounded, transparent, centralized.
## Formula: 50% base, shifted 2% per point of (accuracy - avoidance),
## clamped to [5%, 95%]. Guaranteed-hit skills (later phases) must bypass
## explicitly — never by inflating accuracy.


static func accuracy_score(attacker: Combatant, accuracy_mod: int = 0) -> int:
	var weapon_bonus: int = attacker.get_weapon().accuracy_bonus if attacker.get_weapon() != null else 0
	return attacker.attack_rating + weapon_bonus + accuracy_mod


## `stance_override`: pass an Enums.Stance value to evaluate a hypothetical
## stance (used by AI what-if scoring); -1 uses the defender's actual stance.
static func avoidance_score(defender: Combatant, stance_override: int = -1) -> int:
	var stance: int = defender.stance if stance_override < 0 else stance_override
	var stance_bonus: int = 0
	if stance == Enums.Stance.DEFENDING:
		stance_bonus = CombatTuning.DEFEND_AVOIDANCE_BONUS
	return defender.defence_rating + defender.evasion_value + stance_bonus


static func hit_chance(
		attacker: Combatant, defender: Combatant,
		accuracy_mod: int = 0, stance_override: int = -1) -> float:
	var delta: int = accuracy_score(attacker, accuracy_mod) - avoidance_score(defender, stance_override)
	var chance: float = CombatTuning.BASE_HIT_CHANCE + delta * CombatTuning.HIT_CHANCE_PER_POINT
	return clampf(chance, CombatTuning.MIN_HIT_CHANCE, CombatTuning.MAX_HIT_CHANCE)
