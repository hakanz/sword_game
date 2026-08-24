class_name CombatAction
## Action validation + costs, shared by the HUD (button states), the AI
## (candidate filtering), and the controller (execution guard). One source
## of truth — none of those three reimplement these rules.


static func energy_cost(type: Enums.ActionType, actor: Combatant) -> int:
	match type:
		Enums.ActionType.ATTACK:
			return actor.get_weapon().energy_cost
		Enums.ActionType.APPROACH, Enums.ActionType.RETREAT:
			return CombatTuning.MOVE_ENERGY_COST
		_:
			return 0


static func is_valid(type: Enums.ActionType, actor: Combatant, ctx: CombatContext) -> bool:
	return invalid_reason_key(type, actor, ctx) == ""


## Returns "" when valid, otherwise the localization key of the reason —
## the HUD shows it as the hint line.
static func invalid_reason_key(type: Enums.ActionType, actor: Combatant, ctx: CombatContext) -> String:
	if actor.current_energy < energy_cost(type, actor):
		return "combat.hint.no_energy"
	match type:
		Enums.ActionType.ATTACK:
			if not actor.get_weapon().can_attack_from(ctx.distance):
				return "combat.hint.too_far"
		Enums.ActionType.APPROACH:
			if not ctx.can_approach():
				return "combat.hint.too_far"  # already adjacent; button simply disables
		Enums.ActionType.RETREAT:
			if not ctx.can_retreat():
				return "combat.hint.too_far"
		Enums.ActionType.REST:
			if actor.current_energy >= actor.max_energy:
				return "combat.hint.no_energy"  # nothing to restore; button disables
		_:
			pass
	return ""
