class_name SkillService
## Skill learning rules (charter §17): 1 skill point per skill, level-gated.
## No hard classes — any build may learn any skill it qualifies for; weapon
## compatibility only matters at use time (CombatAction).


## "" when learnable now, otherwise the blocking reason key.
static func learn_block_reason(profile: PlayerProfile, skill: SkillData) -> String:
	if profile.known_skill_ids.has(skill.id):
		return "skills.hint.known"
	if profile.level < skill.required_level:
		return "equip.requires_level"
	if profile.skill_points < 1:
		return "skills.hint.no_points"
	return ""


static func learn(profile: PlayerProfile, skill: SkillData) -> bool:
	if learn_block_reason(profile, skill) != "":
		return false
	profile.skill_points -= 1
	profile.known_skill_ids.append(skill.id)
	return true
