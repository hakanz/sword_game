extends TestCase
## EconomyCalculator: pricing bounds + the no-money-loop invariant (charter §22).

const CONFIG: EconomyConfig = preload("res://data/economy/economy_config.tres")


func test_charisma_discounts_buying() -> void:
	var pricey: int = EconomyCalculator.buy_price(CONFIG, 100, 1)
	var cheaper: int = EconomyCalculator.buy_price(CONFIG, 100, 40)
	assert_true(cheaper < pricey, "charisma must lower buy prices")


func test_discount_is_capped() -> void:
	var at_cap: int = EconomyCalculator.buy_price(CONFIG, 100, 100)
	var beyond: int = EconomyCalculator.buy_price(CONFIG, 100, 200)
	assert_eq(at_cap, beyond, "discount must stop growing at the cap")
	assert_true(at_cap >= roundi(100 * (1.0 - CONFIG.max_charisma_discount)))


func test_sell_always_below_buy() -> void:
	# The anti-exploit invariant across the whole catalog and charisma range.
	var values: Array[int] = [1, 8, 25, 100, 999, 100000]
	for item in ItemDB.all_weapons():
		values.append(item.value)
	for item in ItemDB.all_armour():
		values.append(item.value)
	for value in values:
		for charisma in [1, 10, 25, 50, 100, 200]:
			var buy: int = EconomyCalculator.buy_price(CONFIG, value, charisma)
			var sell: int = EconomyCalculator.sell_price(CONFIG, value, charisma)
			assert_true(sell < buy,
					"money loop: sell %d >= buy %d at value=%d cha=%d" % [sell, buy, value, charisma])
			assert_true(sell >= 0)


func test_gold_rewards() -> void:
	var win: int = EconomyCalculator.combat_gold_reward(CONFIG, 3, true)
	var loss: int = EconomyCalculator.combat_gold_reward(CONFIG, 3, false)
	assert_true(win > loss, "victory pays better")
	assert_true(loss >= 1, "even losers get consolation coin")
	assert_true(EconomyCalculator.combat_gold_reward(CONFIG, 10, true) > win,
			"stronger opponents pay more")
