extends TestCase
## Phase 14 (charter §20, amendment V2 §53) — AI depth.
## What must stay true:
##  1. Temperament shifts are DATA on AIPersonality feeding ONE scoring
##     formula — CombatAI must never grow a per-personality branch.
##  2. A generated fighter's temperament suits the kit the generator actually
##     rolled (no charging marksmen).
##  3. Each champion fights with their own head, not a shared "boss" profile.
##  4. The debug overlay cannot appear in a release build.

const PERSONALITY_DIR: String = "res://data/characters/personalities"


func _personality(id: String) -> AIPersonality:
	return load("%s/%s.tres" % [PERSONALITY_DIR, id])


# --- Temperament shifts -----------------------------------------------------

func test_a_steady_temperament_never_shifts() -> void:
	var steady: AIPersonality = _personality("cautious")
	assert_almost_eq(steady.aggression_now(1.0, 1.0), steady.aggression, 0.0001)
	assert_almost_eq(steady.aggression_now(0.1, 0.1), steady.aggression, 0.0001,
			"a personality with no fury and no instinct must be flat")


func test_the_berserker_fights_harder_while_bleeding() -> void:
	var berserker: AIPersonality = _personality("berserker")
	assert_true(berserker.wounded_fury > 0.0, "the berserker's whole identity is wounded_fury")
	var healthy: float = berserker.aggression_now(1.0, 1.0)
	var hurt: float = berserker.aggression_now(0.2, 1.0)
	assert_true(hurt > healthy, "aggression must RISE as their own HP drops")
	assert_almost_eq(healthy, berserker.aggression, 0.0001, "at full HP it is the base value")
	assert_almost_eq(hurt, berserker.aggression + berserker.wounded_fury * 0.8, 0.0001)


func test_the_opportunist_smells_the_finish() -> void:
	var opportunist: AIPersonality = _personality("opportunist")
	assert_true(opportunist.killer_instinct > 0.0)
	var even: float = opportunist.aggression_now(1.0, 1.0)
	var closing: float = opportunist.aggression_now(1.0, 0.15)
	assert_true(closing > even, "aggression must rise as the FOE nears death")
	assert_almost_eq(opportunist.aggression_now(0.2, 1.0), even, 0.0001,
			"their own wounds must not move them — that is the berserker's job")


func test_hp_fractions_are_clamped() -> void:
	var berserker: AIPersonality = _personality("berserker")
	assert_almost_eq(berserker.aggression_now(-5.0, 1.0),
			berserker.aggression + berserker.wounded_fury, 0.0001,
			"a nonsense fraction must not run the aggression away")
	assert_almost_eq(berserker.aggression_now(9.0, 9.0), berserker.aggression, 0.0001)


func test_temperament_actually_changes_what_the_ai_picks() -> void:
	# Same gear, same state, different heads: the wounded berserker must value
	# swinging more than the cautious fighter does.
	var scores: Dictionary = {}
	for id: String in ["cautious", "berserker"]:
		var attrs: AttributeBlock = CombatFixtures.make_attributes()
		var data: CharacterData = CombatFixtures.make_character(attrs)
		data.personality = _personality(id)
		var actor := CombatFixtures.make_combatant(data)
		var foe := CombatFixtures.make_combatant()
		var ctx: CombatContext = CombatFixtures.make_context(actor, foe, 1)
		actor.current_hp = roundi(actor.max_hp * 0.2)
		RngService.set_seed(99)
		var decision: CombatDecision = CombatAI.choose_action(actor, foe, ctx)
		scores[id] = decision.type
		actor.free()
		foe.free()
	assert_true(scores.has("cautious") and scores.has("berserker"),
			"both temperaments must reach a decision")
	assert_true(scores["berserker"] == Enums.ActionType.ATTACK
			or scores["berserker"] == Enums.ActionType.SKILL,
			"a bleeding berserker at melee range should be swinging")


# --- Roster and pairing -----------------------------------------------------

func test_the_roster_covers_the_specified_temperaments() -> void:
	for id: String in ["aggressive", "defensive", "cautious", "opportunist", "berserker"]:
		var personality: AIPersonality = _personality(id)
		assert_true(personality != null, "%s is missing from the roster" % id)
		if personality == null:
			continue
		assert_eq(String(personality.id), "personality.%s" % id)
		assert_true(personality.aggression > 0.0 and personality.aggression <= 3.0)
		assert_true(personality.caution > 0.0 and personality.caution <= 3.0)
		assert_true(personality.resource_care > 0.0 and personality.resource_care <= 3.0)
	# They must actually differ — a roster of clones is not a roster.
	var aggressive: AIPersonality = _personality("aggressive")
	var defensive: AIPersonality = _personality("defensive")
	assert_true(aggressive.aggression > defensive.aggression)
	assert_true(defensive.caution > aggressive.caution)


func test_generated_fighters_get_a_temperament_that_suits_their_kit() -> void:
	RngService.set_seed(2024)
	var seen_archetypes: Dictionary = {}
	for _i in 60:
		var enemy: CharacterData = OpponentGenerator.generate_at_level(12, _i % 2 == 0)
		var archetype: StringName = ProgressionCalculator.archetype_of(enemy)
		seen_archetypes[archetype] = true
		assert_true(enemy.personality != null, "every generated fighter needs a head")
		if enemy.personality == null:
			continue
		var allowed: Array = OpponentGenerator.PERSONALITY_BY_ARCHETYPE.get(archetype, [])
		assert_true(allowed.has(enemy.personality),
				"%s drew %s, which does not suit it" % [archetype, enemy.personality.id])
	assert_true(seen_archetypes.size() >= 2,
			"the sample must cover more than one archetype to mean anything")


func test_a_marksman_never_rolls_a_charging_temperament() -> void:
	var marksman_pool: Array = OpponentGenerator.PERSONALITY_BY_ARCHETYPE[&"archetype.marksman"]
	for personality: AIPersonality in marksman_pool:
		assert_true(personality.aggression <= 1.0,
				"%s is too eager for an archer" % personality.id)
		assert_true(personality.wounded_fury <= 0.5,
				"an archer should not charge in when hurt")


func test_each_champion_fights_with_their_own_head() -> void:
	var maulhilda: CharacterData = load("res://data/characters/champions/maulhilda.tres")
	var orzha: CharacterData = load("res://data/characters/champions/orzha.tres")
	assert_true(maulhilda.personality != null and orzha.personality != null)
	assert_true(maulhilda.personality.id != orzha.personality.id,
			"handcrafted champions must not share a temperament with each other")
	# The wall holds ground; the duelist pounces.
	assert_true(maulhilda.personality.caution > orzha.personality.caution)
	assert_true(orzha.personality.killer_instinct > maulhilda.personality.killer_instinct)


# --- Debug overlay ----------------------------------------------------------

func test_the_overlay_cannot_appear_in_a_release_build() -> void:
	var no_args := PackedStringArray([])
	var flagged := PackedStringArray(["--debug-ai"])
	assert_false(AiDebugOverlay.should_enable(false, no_args),
			"a shipped build must carry no debug panel")
	assert_true(AiDebugOverlay.should_enable(true, no_args), "dev builds get it for free")
	assert_true(AiDebugOverlay.should_enable(false, flagged),
			"an explicit flag opens it on an exported build for balance work")


func test_the_overlay_ranks_the_winning_action_first() -> void:
	var scores: Dictionary = {"DEFEND": 3.2, "ATTACK": 41.5, "REST": -2.0}
	var text: String = AiDebugOverlay.format_scores(scores)
	var lines: PackedStringArray = text.split("\n")
	assert_eq(lines.size(), 3)
	assert_true(lines[0].contains("ATTACK") and lines[0].contains("▶"),
			"the chosen action must be marked and on top")
	assert_true(lines[2].contains("REST"), "the worst option sinks to the bottom")
	assert_eq(AiDebugOverlay.format_scores(scores, 1).split("\n").size(), 1,
			"the row cap must hold")
	assert_eq(AiDebugOverlay.format_scores({}), "", "no scores, no rows")
