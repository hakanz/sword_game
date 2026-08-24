class_name ProgressionCalculator
## Single home for all attribute -> derived-stat formulas (charter §13.1).
## UI, AI, and tooltips call these — they NEVER recompute stats ad hoc.
## All coefficients are starting values for balancing, not sacred numbers;
## document changes in docs/balancing.md.


static func max_hp(attrs: AttributeBlock, level: int) -> int:
	return 50 + attrs.vitality * 6 + level * 4


static func max_energy(attrs: AttributeBlock, level: int) -> int:
	return 40 + attrs.stamina * 4 + level * 2


static func max_mana(attrs: AttributeBlock, _level: int) -> int:
	return 10 + attrs.arcana * 5


## Base accuracy score before weapon/skill bonuses (HitCalculator adds those).
static func attack_rating(attrs: AttributeBlock) -> int:
	return attrs.attack * 2 + attrs.agility


## Base avoidance score before evasion/stance (HitCalculator adds those).
static func defence_rating(attrs: AttributeBlock) -> int:
	return attrs.defence * 2


## `equipment_evasion_mod` is the summed evasion modifier of worn armour.
static func evasion(attrs: AttributeBlock, equipment_evasion_mod: int = 0) -> int:
	return attrs.agility + equipment_evasion_mod


static func initiative(attrs: AttributeBlock) -> int:
	return attrs.agility * 2 + attrs.attack


## Cells covered by one approach/retreat action (session-5 owner design):
## movement is EARNED, tier by tier — Agility plus gear mobility, never a
## flat rate for everyone. Tiers deliberately coarse (no runaway speed):
##   score < 14 -> 1 cell   |   score >= 14 -> 2 cells (cap)
## where score = agility + 2 * summed gear mobility_bonus.
static func move_cells(agility: int, gear_mobility: int = 0) -> int:
	return 2 if agility + gear_mobility * 2 >= 14 else 1


## XP needed to advance FROM `level` to `level + 1` (charter §14 curve).
static func xp_required(config: ProgressionConfig, level: int) -> int:
	return roundi(config.base_xp * pow(level, config.xp_exponent))


## XP awarded for a duel vs a level-`enemy_level` opponent. Losing still
## grants a fraction; fighting far below your level is clamped down.
## `hits`/`actions` feed the effectiveness multiplier (session-5 owner
## design): XP follows REAL fighting — landed strikes per action taken —
## so stalling with filler moves earns less, never more. Pass actions <= 0
## for a neutral multiplier (old callers, sims without a tally).
static func xp_reward(
		config: ProgressionConfig, player_level: int, enemy_level: int,
		player_won: bool, hits: int = -1, actions: int = -1) -> int:
	var base: float = config.xp_win_base * pow(enemy_level, config.xp_win_exponent)
	var gap: float = clampf(
			1.0 + config.level_gap_step * (enemy_level - player_level),
			config.level_gap_min, config.level_gap_max)
	var xp: float = base * gap * combat_effectiveness(hits, actions)
	if not player_won:
		xp *= config.xp_loss_fraction
	return maxi(roundi(xp), 1)


## Effectiveness multiplier in [0.65, 1.25] — deliberately narrow (the owner
## asked for fairness pressure, not a punishment system): a fight spent
## landing blows tops out at +25%, a fight spent circling bottoms at -35%.
static func combat_effectiveness(hits: int, actions: int) -> float:
	if actions <= 0:
		return 1.0
	var hit_ratio: float = clampf(float(hits) / float(actions), 0.0, 1.0)
	return clampf(0.65 + 0.9 * hit_ratio, 0.65, 1.25)


## Flat damage added to a weapon roll from attributes. Weights differ per
## weapon class so different builds favor different weapons (charter §15).
static func attribute_damage_bonus(attrs: AttributeBlock, weapon_class: Enums.WeaponClass) -> int:
	match weapon_class:
		Enums.WeaponClass.SWORD:
			return roundi(attrs.strength * 0.3 + attrs.agility * 0.2)
		Enums.WeaponClass.AXE, Enums.WeaponClass.BLUNT:
			return roundi(attrs.strength * 0.5)
		Enums.WeaponClass.SPEAR:
			return roundi(attrs.strength * 0.35 + attrs.agility * 0.15)
		Enums.WeaponClass.RANGED:
			return roundi(attrs.agility * 0.4)
		Enums.WeaponClass.MAGICAL:
			return roundi(attrs.arcana * 0.5)
		_:
			return roundi(attrs.strength * 0.25)
