class_name EconomyConfig
extends Resource
## Economy tuning (charter §22). All pricing/reward coefficients are data.
## Canonical instance: res://data/economy/economy_config.tres.
## Anti-exploit invariant (tested): sell price must ALWAYS stay below buy
## price at every charisma value — no buy/sell money loops.

@export_group("Prices")
## Charisma shaves this fraction off buy prices per point, up to the cap.
@export_range(0.0, 0.02) var charisma_discount_per_point: float = 0.004
@export_range(0.0, 0.5) var max_charisma_discount: float = 0.25
## Base fraction of item value received when selling.
@export_range(0.0, 1.0) var sell_fraction_base: float = 0.35
## Charisma raises the sell fraction per point, up to the cap.
@export_range(0.0, 0.02) var charisma_sell_per_point: float = 0.002
@export_range(0.0, 1.0) var max_sell_fraction: float = 0.5

@export_group("Combat Gold")
@export_range(1, 1000) var gold_win_base: int = 12
@export_range(0.5, 2.0) var gold_win_exponent: float = 1.15
## Fraction of the win purse granted on defeat (consolation coin).
@export_range(0.0, 1.0) var gold_loss_fraction: float = 0.2
## One-time purse for toppling a champion (on top of normal rewards).
@export_range(0, 10000) var champion_gold_bonus: int = 150
## One-time fame award for toppling a champion.
@export_range(0, 1000) var champion_fame_bonus: int = 25
