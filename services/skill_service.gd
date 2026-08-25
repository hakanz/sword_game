class_name SkillService
## Skill learning rules (charter §17): per-skill point costs (session 6),
## level-gated. No hard classes — any build may learn any skill it qualifies
## for; weapon compatibility only matters at use time (CombatAction).

## Which attribute each skill leans on — drives the "suits your build"
## guidance on the skills screen (session-6 owner design). Purely advisory:
## recommendations never gate learning.
const SKILL_AFFINITY: Dictionary = {
	&"skill.crushing_blow": "strength",
	&"skill.skull_ringer": "strength",
	&"skill.sunder_guard": "strength",
	&"skill.gutter_lunge": "agility",
	&"skill.hamstring_cut": "agility",
	&"skill.venom_smear": "agility",
	&"skill.pinning_shot": "agility",
	&"skill.focused_loose": "agility",
	&"skill.ember_bolt": "arcana",
	&"skill.enfeebling_hex": "arcana",
	&"skill.war_bellow": "charisma",
	&"skill.mocking_jab": "charisma",
	&"skill.brace_up": "defence",
	&"skill.second_wind": "stamina",
}


## "" when learnable now, otherwise the blocking reason key.
static func learn_block_reason(profile: PlayerProfile, skill: SkillData) -> String:
	if profile.known_skill_ids.has(skill.id):
		return "skills.hint.known"
	if profile.level < skill.required_level:
		return "equip.requires_level"
	if profile.skill_points < skill.point_cost:
		return "skills.hint.no_points"
	return ""


static func learn(profile: PlayerProfile, skill: SkillData) -> bool:
	if learn_block_reason(profile, skill) != "":
		return false
	profile.skill_points -= skill.point_cost
	profile.known_skill_ids.append(skill.id)
	return true


## The profile's dominant attribute (property name on AttributeBlock).
static func dominant_attribute(profile: PlayerProfile) -> String:
	var best: String = "strength"
	var best_value: int = -1
	for attr in ["strength", "agility", "attack", "defence",
			"vitality", "stamina", "arcana", "charisma"]:
		var value: int = int(profile.attributes.get(attr))
		if value > best_value:
			best_value = value
			best = attr
	return best


## Advisory: the skill leans on one of the player's two strongest
## attributes AND works with the currently equipped weapon.
static func is_recommended(profile: PlayerProfile, skill: SkillData) -> bool:
	if not SKILL_AFFINITY.has(skill.id):
		return false
	var values: Array = []
	for attr in ["strength", "agility", "attack", "defence",
			"vitality", "stamina", "arcana", "charisma"]:
		values.append([int(profile.attributes.get(attr)), attr])
	values.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var top: Array[String] = [values[0][1], values[1][1]]
	if not top.has(SKILL_AFFINITY[skill.id]):
		return false
	var weapon: WeaponData = ItemDB.weapon(profile.weapon_id)
	return weapon != null and skill.usable_with(weapon.weapon_class)
