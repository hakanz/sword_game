extends RefCounted
## Economy pacing report (charter §35's sibling for §22). DEV-ONLY — tools/ is
## excluded from exports.
##
## The combat simulator answers "is this fight fair?". This one answers the
## other half: "can a gladiator actually AFFORD the next step?" It walks the
## level range, and for each level asks the same questions the player does —
## what does a win pay, what is the cheapest thing on the shelf I cannot use
## yet, and how many fights away is it?
##
## Everything comes from the real authorities: EconomyCalculator for prices
## and purses, ItemDB for the catalog. Nothing here re-implements a formula.
##
## Loaded at runtime by economy_sim.gd so the autoload singletons exist.

const ECONOMY: EconomyConfig = preload("res://data/economy/economy_config.tres")
## Levels the report walks (the three regions span 1-24).
const LEVELS: Array[int] = [1, 3, 5, 8, 11, 14, 17, 20, 24]
## A fight is only worth its purse if you win it; assume a realistic mix.
const WIN_RATE: float = 0.7


func run() -> void:
	var charisma: int = 5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--charisma="):
			charisma = int(arg.get_slice("=", 1))

	print("=== Arena Legends economy pacing (charisma %d, %.0f%% win rate) ===" % [
		charisma, WIN_RATE * 100.0])
	print("  %-6s %10s %10s   %-28s %8s %7s" % [
		"level", "gold/win", "gold/fight", "cheapest unowned upgrade", "price", "fights"])

	for level in LEVELS:
		var win_gold: int = EconomyCalculator.combat_gold_reward(ECONOMY, level, true)
		var loss_gold: int = EconomyCalculator.combat_gold_reward(ECONOMY, level, false)
		var per_fight: float = win_gold * WIN_RATE + loss_gold * (1.0 - WIN_RATE)
		var target: Resource = _next_upgrade(level)
		if target == null:
			print("  %-6d %10d %10.1f   %-28s %8s %7s" % [
				level, win_gold, per_fight, "(nothing new on the shelf)", "-", "-"])
			continue
		var price: int = EconomyCalculator.buy_price(ECONOMY, int(target.get("value")), charisma)
		var fights: float = price / maxf(per_fight, 1.0)
		print("  %-6d %10d %10.1f   %-28s %8d %7.1f" % [
			level, win_gold, per_fight, String(target.get("id")), price, fights])

	print("--------------------------------")
	print("Reading it: 'fights' is how many duels at that level pay for the next")
	print("piece of gear that JUST unlocked. Single digits mean the shop keeps up")
	print("with the ladder; a jump into the twenties means a wall (docs/balancing.md).")


## The cheapest shop item whose level requirement is exactly satisfied at this
## level — i.e. the thing that just became available to a player standing here.
func _next_upgrade(level: int) -> Resource:
	var best: Resource = null
	var candidates: Array[Resource] = []
	for weapon in ItemDB.all_weapons():
		candidates.append(weapon)
	for piece in ItemDB.all_armour():
		candidates.append(piece)
	for item in candidates:
		if not bool(item.get("shop_available")):
			continue
		var required: int = int(item.get("required_level"))
		# "Just unlocked" = gated at this level or the two below it.
		if required > level or required < level - 2:
			continue
		if best == null or int(item.get("value")) > int(best.get("value")):
			best = item  # the best thing newly in reach, not the cheapest scrap
	return best
