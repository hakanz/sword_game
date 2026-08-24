class_name ProgressionConfig
extends Resource
## Progression tuning (charter §14). ALL leveling coefficients live here as
## data — never hardcoded in logic. The canonical instance is
## res://data/progression/progression_config.tres.

@export_group("XP Curve")
## XP needed to advance FROM level L is base_xp * L^xp_exponent.
@export_range(1, 10000) var base_xp: int = 100
@export_range(1.0, 3.0) var xp_exponent: float = 1.55
@export_range(2, 200) var max_level: int = 60

@export_group("Level-Up Grants")
@export_range(0, 20) var attribute_points_per_level: int = 3
## A skill point is granted on every Nth level (level % N == 0).
@export_range(1, 10) var skill_point_every_n_levels: int = 2

@export_group("Combat XP Rewards")
## Winning vs a level-L enemy yields ~xp_win_base * L^xp_win_exponent.
@export_range(1, 1000) var xp_win_base: int = 45
@export_range(0.5, 2.0) var xp_win_exponent: float = 1.1
## Fraction of the win XP granted on defeat (losing still teaches a little).
@export_range(0.0, 1.0) var xp_loss_fraction: float = 0.25
## Fighting above/below your level scales XP by 1 + step * level_difference,
## clamped to [gap_min, gap_max] — discourages seal-clubbing.
@export_range(0.0, 1.0) var level_gap_step: float = 0.15
@export_range(0.1, 1.0) var level_gap_min: float = 0.4
@export_range(1.0, 5.0) var level_gap_max: float = 2.0
