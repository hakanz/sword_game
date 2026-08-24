class_name CombatDecision
extends RefCounted
## One chosen combat action: a base action, or SKILL + which skill.
## Produced by the HUD (player) and CombatAI (enemies); consumed by the
## controller's executor.

var type: Enums.ActionType = Enums.ActionType.ATTACK
var skill: SkillData = null


static func base_action(action_type: Enums.ActionType) -> CombatDecision:
	var decision := CombatDecision.new()
	decision.type = action_type
	return decision


static func skill_action(skill_data: SkillData) -> CombatDecision:
	var decision := CombatDecision.new()
	decision.type = Enums.ActionType.SKILL
	decision.skill = skill_data
	return decision
