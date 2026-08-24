class_name EconomyCalculator
## Single home for all price/gold formulas (charter §22). Shop UI, reward
## pipeline, and tooltips call these — nothing re-derives prices.
## Reputation modifiers slot in here when the fame/reputation phase lands.


static func buy_price(config: EconomyConfig, item_value: int, charisma: int) -> int:
	var discount: float = minf(
			charisma * config.charisma_discount_per_point,
			config.max_charisma_discount)
	return maxi(roundi(item_value * (1.0 - discount)), 1)


static func sell_price(config: EconomyConfig, item_value: int, charisma: int) -> int:
	var fraction: float = minf(
			config.sell_fraction_base + charisma * config.charisma_sell_per_point,
			config.max_sell_fraction)
	var price: int = roundi(item_value * fraction)
	# Structural anti-exploit guard: selling must never reach the buy price,
	# even if someone tunes the config into a money loop.
	return clampi(price, 0, buy_price(config, item_value, charisma) - 1)


static func combat_gold_reward(config: EconomyConfig, enemy_level: int, player_won: bool) -> int:
	var gold: float = config.gold_win_base * pow(enemy_level, config.gold_win_exponent)
	if not player_won:
		gold *= config.gold_loss_fraction
	return maxi(roundi(gold), 1)
