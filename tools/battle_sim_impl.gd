extends RefCounted
## Battle simulation implementation (charter §35) — loaded at runtime by
## tools/battle_sim.gd so autoload globals resolve (a `-s` main script
## compiles before autoloads register).

const CreationPresets: GDScript = preload("res://ui/character_creation.gd")
const STARTER_WEAPON := preload("res://data/weapons/training_shortsword.tres")
const STARTER_VEST := preload("res://data/armour/padded_vest.tres")
const SMOKE_SKILLS: Array[String] = [
	"res://data/skills/crushing_blow.tres",
	"res://data/skills/venom_smear.tres",
	"res://data/skills/war_bellow.tres",
]


func run() -> void:
	var battles: int = 200
	var base_seed: int = 1000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--battles="):
			battles = maxi(int(arg.get_slice("=", 1)), 1)
		elif arg.begins_with("--base-seed="):
			base_seed = int(arg.get_slice("=", 1))

	print("=== Arena Legends battle simulation (%d battles/matchup) ===" % battles)
	for level in [1, 5, 10]:
		_run_matchup("default kit vs generated L%d" % level, battles, base_seed,
				func() -> Array[CharacterData]: return [
					_default_kit_character(level),
					OpponentGenerator.generate_at_level(level),
				])
	var preset_pairs: Array[Array] = [[0, 1], [0, 2], [1, 2]]
	for pair in preset_pairs:
		var name_a: String = CreationPresets.PRESETS[pair[0]][0]
		var name_b: String = CreationPresets.PRESETS[pair[1]][0]
		_run_matchup("%s vs %s (L1, equal gear)" % [name_a, name_b], battles, base_seed,
				func() -> Array[CharacterData]: return [
					_preset_character(pair[0]),
					_preset_character(pair[1]),
				])


func _run_matchup(label: String, battles: int, base_seed: int, factory: Callable) -> void:
	var a_wins: int = 0
	var stalemates: int = 0
	var total_rounds: int = 0
	for i in battles:
		RngService.set_seed(base_seed + i)
		var pair: Array[CharacterData] = factory.call()
		var outcome: Dictionary = _simulate(pair[0], pair[1])
		if outcome["stalemate"]:
			stalemates += 1
		if outcome["a_won"]:
			a_wins += 1
		total_rounds += outcome["rounds"]
	print("  %-38s  A wins %5.1f%%  avg rounds %5.1f  stalemates %d" % [
		label, 100.0 * a_wins / battles, float(total_rounds) / battles, stalemates])


## One full AI-vs-AI duel over the real rules. Returns a_won/rounds/stalemate.
func _simulate(data_a: CharacterData, data_b: CharacterData) -> Dictionary:
	var a := Combatant.new()
	var b := Combatant.new()
	# BOTH sides are plain AI: the sim must measure initiative, not the
	# player-first opening rule (session-5 review finding — a true flag here
	# handed fighter A every opening turn and biased the win rates).
	a.setup(data_a, false, false)
	b.setup(data_b, false, true)
	var ctx := CombatContext.new()
	ctx.setup(a, b)
	var manager := TurnManager.new()
	manager.setup([a, b])

	var stalemate: bool = false
	while true:
		var actor: Combatant = manager.advance()
		if manager.is_round_start():
			if manager.round_number > CombatTuning.MAX_ROUNDS:
				stalemate = true
				break
			ctx.round_number = manager.round_number
		actor.on_turn_started()
		actor.tick_cooldowns()
		if not StatusEffectSystem.is_stunned(actor):
			var foe: Combatant = ctx.foe_of(actor)
			CombatResolver.execute(actor, foe, ctx, CombatAI.choose_action(actor, foe, ctx))
		StatusEffectSystem.tick_turn_end(actor)
		if not a.is_alive() or not b.is_alive():
			break

	var a_won: bool = a.is_alive() if a.is_alive() != b.is_alive() \
			else CombatResult.stalemate_player_won(a, b)
	var rounds: int = mini(manager.round_number, CombatTuning.MAX_ROUNDS)
	a.free()
	b.free()
	return {"a_won": a_won, "rounds": rounds, "stalemate": stalemate}


## The smoke-test player kit at a given level (attribute points spread evenly).
func _default_kit_character(level: int) -> CharacterData:
	var profile := PlayerProfile.create_default()
	profile.level = level
	var points: int = (level - 1) * 3
	var attrs := profile.attributes
	var spread: PackedStringArray = ["strength", "vitality", "attack", "agility", "stamina", "defence"]
	for i in points:
		var attr: String = spread[i % spread.size()]
		attrs.set(attr, int(attrs.get(attr)) + 1)
	# Skills only as a real player could have them (1 point / 2 levels).
	var skill_budget: int = mini(level / 2, SMOKE_SKILLS.size())
	for i in skill_budget:
		profile.known_skill_ids.append(load(SMOKE_SKILLS[i]).id)
	return profile.to_character_data()


func _preset_character(index: int) -> CharacterData:
	var preset: Array = CreationPresets.PRESETS[index]
	var data := CharacterData.new()
	data.id = &"character.sim_preset"
	data.name_text = str(preset[0])
	data.is_name_localization_key = false
	data.level = 1
	var attrs := AttributeBlock.new()
	attrs.strength = preset[1]
	attrs.agility = preset[2]
	attrs.attack = preset[3]
	attrs.defence = preset[4]
	attrs.vitality = preset[5]
	attrs.stamina = preset[6]
	attrs.arcana = preset[7]
	attrs.charisma = preset[8]
	data.attributes = attrs
	data.weapon = STARTER_WEAPON
	data.armour_pieces = [STARTER_VEST]
	return data
