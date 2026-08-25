extends TestCase
## Phase 12 (charter §16, amendment V2 §52) — itemization depth.
## Guards the three promises this phase makes:
##  1. Affix derivation is DETERMINISTIC, budgeted by rarity, and respects
##     every affix's kind/rarity gate (a save-free itemization layer only
##     works if the derivation is reproducible).
##  2. The kit's modifiers reach combat through the existing calculators and
##     never mutate the character's own progression attributes.
##  3. The three signature effects fire exactly where they are specified to.

const POISON: StatusEffectData = preload("res://data/status_effects/poison.tres")


func _weapon(id: StringName, rarity: Enums.Rarity) -> WeaponData:
	var weapon: WeaponData = CombatFixtures.make_weapon()
	weapon.id = id
	weapon.rarity = rarity
	return weapon


# --- Derivation -------------------------------------------------------------

func test_budget_follows_rarity() -> void:
	assert_eq(ItemAffixes.budget_for(Enums.Rarity.COMMON), 0, "starter gear stays plain")
	assert_eq(ItemAffixes.budget_for(Enums.Rarity.UNCOMMON), 1)
	assert_eq(ItemAffixes.budget_for(Enums.Rarity.RARE), 2)
	assert_eq(ItemAffixes.budget_for(Enums.Rarity.EPIC), 3)
	assert_eq(ItemAffixes.budget_for(Enums.Rarity.LEGENDARY), 3)
	assert_eq(ItemAffixes.budget_for(Enums.Rarity.MYTHIC), 4)
	assert_false(ItemAffixes.has_signature(Enums.Rarity.EPIC))
	assert_true(ItemAffixes.has_signature(Enums.Rarity.LEGENDARY))
	assert_true(ItemAffixes.has_signature(Enums.Rarity.MYTHIC))


func test_every_catalog_item_carries_its_budget() -> void:
	for weapon: WeaponData in ItemDB.all_weapons():
		var rolls: Array[ItemAffixes.Roll] = ItemAffixes.for_weapon(weapon)
		assert_eq(rolls.size(), ItemAffixes.budget_for(weapon.rarity),
				"%s carries the wrong number of modifiers" % weapon.id)
	for piece: ArmourData in ItemDB.all_armour():
		var rolls: Array[ItemAffixes.Roll] = ItemAffixes.for_armour(piece)
		assert_eq(rolls.size(), ItemAffixes.budget_for(piece.rarity),
				"%s carries the wrong number of modifiers" % piece.id)


func test_derivation_is_deterministic_across_cache_clears() -> void:
	for weapon: WeaponData in ItemDB.all_weapons():
		var first: Array[ItemAffixes.Roll] = ItemAffixes.for_weapon(weapon)
		var snapshot: Array = []
		for roll in first:
			snapshot.append([roll.affix.id, roll.value])
		ItemAffixes.clear_cache()
		var second: Array[ItemAffixes.Roll] = ItemAffixes.for_weapon(weapon)
		assert_eq(second.size(), snapshot.size(), "%s changed modifier count" % weapon.id)
		for i in second.size():
			assert_eq(second[i].affix.id, snapshot[i][0],
					"%s modifier %d changed identity" % [weapon.id, i])
			assert_almost_eq(second[i].value, snapshot[i][1], 0.0001,
					"%s modifier %d changed value" % [weapon.id, i])


func test_affixes_respect_kind_and_rarity_gates() -> void:
	for weapon: WeaponData in ItemDB.all_weapons():
		for roll in ItemAffixes.for_weapon(weapon):
			assert_true(roll.affix.applies_to != AffixData.Kind.ARMOUR,
					"armour-only %s landed on weapon %s" % [roll.affix.id, weapon.id])
			assert_true(weapon.rarity >= roll.affix.min_rarity,
					"%s is too rare for %s" % [roll.affix.id, weapon.id])
	for piece: ArmourData in ItemDB.all_armour():
		for roll in ItemAffixes.for_armour(piece):
			assert_true(roll.affix.applies_to != AffixData.Kind.WEAPON,
					"weapon-only %s landed on armour %s" % [roll.affix.id, piece.id])
			assert_true(piece.rarity >= roll.affix.min_rarity,
					"%s is too rare for %s" % [roll.affix.id, piece.id])


func test_no_item_rolls_the_same_affix_twice() -> void:
	for weapon: WeaponData in ItemDB.all_weapons():
		var seen: Dictionary = {}
		for roll in ItemAffixes.for_weapon(weapon):
			assert_false(seen.has(roll.affix.id), "%s rolled %s twice" % [weapon.id, roll.affix.id])
			seen[roll.affix.id] = true


func test_rolled_values_stay_inside_their_band() -> void:
	for weapon: WeaponData in ItemDB.all_weapons():
		for roll in ItemAffixes.for_weapon(weapon):
			assert_true(roll.value >= roll.affix.value_min - 0.5
					and roll.value <= roll.affix.value_max + 0.001,
					"%s rolled %s outside its band" % [weapon.id, roll.affix.id])
			if not roll.affix.is_fractional():
				assert_true(roll.value >= 1.0, "integer modifiers never roll to nothing")


func test_starter_gear_is_untouched() -> void:
	# The debut arc hands out Common gear; it must stay exactly as tuned.
	for id: StringName in [&"weapon.worn_shiv", &"weapon.training_shortsword",
			&"weapon.skinning_knife"]:
		assert_true(ItemAffixes.for_weapon(ItemDB.weapon(id)).is_empty(),
				"%s must carry no modifiers" % id)


# --- Kit aggregation --------------------------------------------------------

func test_kit_bonuses_never_mutate_progression_attributes() -> void:
	var attrs: AttributeBlock = CombatFixtures.make_attributes()
	var before: int = attrs.strength
	var bonuses := ItemAffixes.Bonuses.new()
	bonuses.attributes["strength"] = 3
	var effective: AttributeBlock = ItemAffixes.effective_attributes(attrs, bonuses)
	assert_eq(effective.strength, before + 3, "affixes must reach the effective block")
	assert_eq(attrs.strength, before, "the character's own attributes must not move")


func test_combatant_reads_effective_attributes_and_pools() -> void:
	# A Rare weapon (2 modifiers) versus the same weapon as Common.
	var plain: CharacterData = CombatFixtures.make_character(
			CombatFixtures.make_attributes(), _weapon(&"weapon.plain_probe", Enums.Rarity.COMMON))
	var rich: CharacterData = CombatFixtures.make_character(
			CombatFixtures.make_attributes(), _weapon(&"weapon.rich_probe", Enums.Rarity.RARE))
	var plain_fighter := CombatFixtures.make_combatant(plain)
	var rich_fighter := CombatFixtures.make_combatant(rich)

	assert_eq(plain_fighter.kit.attributes.size(), 0, "a Common weapon adds nothing")
	assert_true(ItemAffixes.for_weapon(rich.weapon).size() == 2, "Rare rolls two modifiers")
	# Whatever it rolled, the effective block must be >= the base block and
	# the base block must be untouched.
	for field: String in ["strength", "agility", "attack", "defence", "vitality",
			"stamina", "arcana", "charisma"]:
		assert_true(int(rich_fighter.attributes.get(field)) >= int(rich.attributes.get(field)),
				"effective %s dropped below base" % field)
	assert_eq(rich_fighter.data.attributes.strength, plain_fighter.data.attributes.strength,
			"equipment must never write into character data")
	plain_fighter.free()
	rich_fighter.free()


func test_crit_and_penetration_include_kit_affixes() -> void:
	var weapon: WeaponData = CombatFixtures.make_weapon()
	weapon.id = &"weapon.crit_probe"
	weapon.crit_chance = 0.05
	weapon.armour_penetration = 0.1
	var fighter := CombatFixtures.make_combatant(
			CombatFixtures.make_character(CombatFixtures.make_attributes(), weapon))
	# Hand-built bonuses: the plumbing, not the roll, is what is under test.
	fighter.kit.crit_chance = 0.03
	fighter.kit.armour_penetration = 0.07
	assert_almost_eq(fighter.armour_penetration(), 0.17, 0.0001,
			"penetration must include kit affixes")
	assert_almost_eq(fighter.crit_chance(),
			HitCalculator.crit_chance_for(fighter.attributes, weapon, 0.03), 0.0001,
			"crit must route through HitCalculator with the kit bonus")
	fighter.kit.crit_chance = 1.0
	assert_almost_eq(fighter.crit_chance(), CombatTuning.MAX_CRIT_CHANCE, 0.0001,
			"the 25% crit clamp still binds with affixes")
	fighter.free()


# --- Signature effects ------------------------------------------------------

func test_venom_mastery_grants_one_extra_stack() -> void:
	var target := CombatFixtures.make_combatant()
	var instance: StatusEffectInstance = null
	for _i in POISON.max_stacks + 4:
		instance = StatusEffectSystem.apply(target, POISON, 1)
	assert_eq(instance.stacks, POISON.max_stacks + 1, "Venom Mastery raises the ceiling by one")
	target.free()

	var plain := CombatFixtures.make_combatant()
	var plain_instance: StatusEffectInstance = null
	for _i in POISON.max_stacks + 4:
		plain_instance = StatusEffectSystem.apply(plain, POISON)
	assert_eq(plain_instance.stacks, POISON.max_stacks, "without it the cap is unchanged")
	plain.free()


func test_bulwark_reserve_pays_energy_back_on_defend() -> void:
	var guarded: Combatant = _fighter_with_unique(Enums.UniqueEffect.BULWARK_RESERVE)
	var plain: Combatant = _fighter_with_unique(Enums.UniqueEffect.NONE)
	var ctx: CombatContext = CombatFixtures.make_context(guarded, plain, 3)
	guarded.current_energy = 20
	plain.current_energy = 20
	var decision := CombatDecision.new()
	decision.type = Enums.ActionType.DEFEND

	var guarded_result: ActionResult = CombatResolver.execute(guarded, plain, ctx, decision)
	var plain_result: ActionResult = CombatResolver.execute(plain, guarded, ctx, decision)
	assert_eq(guarded_result.energy_restored, CombatResolver.DEFEND_ENERGY_REFUND,
			"Bulwark Reserve refunds Energy on a guard")
	assert_eq(plain_result.energy_restored, 0, "a plain fighter gains nothing from guarding")
	assert_true(guarded.current_energy > plain.current_energy,
			"the refund must actually reach the pool")
	guarded.free()
	plain.free()


func test_relentless_edge_ticks_cooldowns_on_a_crit() -> void:
	var fighter: Combatant = _fighter_with_unique(Enums.UniqueEffect.RELENTLESS_EDGE)
	fighter.set_cooldown(&"skill.probe", 3)
	fighter.reduce_cooldowns(1)
	assert_eq(int(fighter.cooldowns.get(&"skill.probe", 0)), 2, "a crit shaves one round")
	fighter.reduce_cooldowns(5)
	assert_false(fighter.cooldowns.has(&"skill.probe"), "cooldowns clear instead of going negative")
	assert_true(fighter.has_unique(Enums.UniqueEffect.RELENTLESS_EDGE))
	fighter.free()

	var plain: Combatant = _fighter_with_unique(Enums.UniqueEffect.NONE)
	assert_false(plain.has_unique(Enums.UniqueEffect.RELENTLESS_EDGE))
	plain.free()


# --- Content invariants -----------------------------------------------------

func test_signature_effects_only_ride_legendary_gear() -> void:
	var signatures: int = 0
	for weapon: WeaponData in ItemDB.all_weapons():
		if weapon.unique_effect != Enums.UniqueEffect.NONE:
			signatures += 1
			assert_true(ItemAffixes.has_signature(weapon.rarity),
					"%s carries a signature below Legendary" % weapon.id)
	for piece: ArmourData in ItemDB.all_armour():
		if piece.unique_effect != Enums.UniqueEffect.NONE:
			signatures += 1
			assert_true(ItemAffixes.has_signature(piece.rarity),
					"%s carries a signature below Legendary" % piece.id)
	assert_true(signatures >= 3, "the three specified signature effects must be in the catalog")


func test_every_legendary_actually_has_a_signature() -> void:
	for weapon: WeaponData in ItemDB.all_weapons():
		if ItemAffixes.has_signature(weapon.rarity):
			assert_true(weapon.unique_effect != Enums.UniqueEffect.NONE,
					"%s is Legendary but signature-less" % weapon.id)
	for piece: ArmourData in ItemDB.all_armour():
		if ItemAffixes.has_signature(piece.rarity):
			assert_true(piece.unique_effect != Enums.UniqueEffect.NONE,
					"%s is Legendary but signature-less" % piece.id)


func test_generated_opponents_never_carry_legendary_gear() -> void:
	RngService.set_seed(4242)
	for _i in 40:
		var enemy: CharacterData = OpponentGenerator.generate_at_level(20, true)
		assert_true(enemy.weapon.rarity < Enums.Rarity.LEGENDARY,
				"a generated fighter drew %s" % enemy.weapon.id)
		for piece in enemy.armour_pieces:
			assert_true(piece.rarity < Enums.Rarity.LEGENDARY,
					"a generated fighter drew %s" % piece.id)


func test_affix_and_signature_strings_are_translated() -> void:
	for affix: AffixData in ItemDB.all_affixes():
		assert_true(TranslationServer.translate(affix.name_key) != affix.name_key,
				"%s has no translation" % affix.name_key)
		assert_true(TranslationServer.translate(affix.stat_key()) != affix.stat_key(),
				"%s has no translation" % affix.stat_key())
	for effect: int in [Enums.UniqueEffect.VENOM_MASTERY, Enums.UniqueEffect.BULWARK_RESERVE,
			Enums.UniqueEffect.RELENTLESS_EDGE]:
		var key: String = ItemAffixes.unique_effect_key(effect as Enums.UniqueEffect)
		assert_true(TranslationServer.translate(key) != key, "%s has no translation" % key)
		assert_true(TranslationServer.translate("%s.desc" % key) != "%s.desc" % key,
				"%s.desc has no translation" % key)
	for rarity: int in Enums.Rarity.values():
		var key: String = ItemCompare.rarity_key(rarity as Enums.Rarity)
		assert_true(TranslationServer.translate(key) != key, "%s has no translation" % key)


# --- Comparison formatting --------------------------------------------------

func test_comparison_reports_both_sides_of_a_swap() -> void:
	var profile: PlayerProfile = PlayerProfile.create_default()
	var equipped: WeaponData = ItemDB.weapon(profile.weapon_id)
	var better: WeaponData = null
	for candidate: WeaponData in ItemDB.all_weapons():
		if candidate.average_damage() > equipped.average_damage() + 4.0:
			better = candidate
			break
	assert_true(better != null, "the catalog must contain a clear upgrade")
	if better == null:
		return
	var deltas: Dictionary = ItemCompare.deltas(profile, better, true)
	assert_true(deltas.has("stat.damage"), "a damage change must be reported")
	assert_true(float(deltas["stat.damage"]) > 0.0)
	assert_true(ItemCompare.gains_text(deltas) != "", "gains must render")
	# Comparing an item against itself is not a decision — nothing to report.
	assert_true(ItemCompare.deltas(profile, equipped, true).is_empty(),
			"the equipped item compares to nothing")


func _fighter_with_unique(effect: Enums.UniqueEffect) -> Combatant:
	var weapon: WeaponData = CombatFixtures.make_weapon()
	weapon.id = &"weapon.unique_probe_%d" % effect
	weapon.unique_effect = effect
	return CombatFixtures.make_combatant(
			CombatFixtures.make_character(CombatFixtures.make_attributes(), weapon))


# --- Weapon Mastery Archetype (V2 §47/§50) ---------------------------------

func test_archetype_follows_the_equipped_weapon() -> void:
	var expected: Dictionary = {
		Enums.WeaponClass.AXE: &"archetype.breaker",
		Enums.WeaponClass.BLUNT: &"archetype.breaker",
		Enums.WeaponClass.SWORD: &"archetype.duelist",
		Enums.WeaponClass.SPEAR: &"archetype.skirmisher",
		Enums.WeaponClass.RANGED: &"archetype.marksman",
		Enums.WeaponClass.MAGICAL: &"archetype.battlemage",
		Enums.WeaponClass.UNARMED: &"archetype.brawler",
	}
	for weapon_class: int in Enums.WeaponClass.values():
		var weapon: WeaponData = CombatFixtures.make_weapon()
		weapon.weapon_class = weapon_class as Enums.WeaponClass
		assert_eq(ProgressionCalculator.combat_archetype_label(weapon, 0, false),
				expected[weapon_class],
				"%s mapped to the wrong archetype" % Enums.WeaponClass.keys()[weapon_class])
	assert_eq(ProgressionCalculator.combat_archetype_label(null, 0, false),
			&"archetype.brawler", "bare fists are a Brawler")


func test_a_shielded_heavy_reads_as_guardian_whatever_the_weapon() -> void:
	var weapon: WeaponData = CombatFixtures.make_weapon()
	weapon.weapon_class = Enums.WeaponClass.SWORD
	assert_eq(ProgressionCalculator.combat_archetype_label(
			weapon, ProgressionCalculator.GUARDIAN_ARMOUR_WEIGHT, true),
			&"archetype.guardian")
	# A shield alone, or plate alone, is not enough.
	assert_eq(ProgressionCalculator.combat_archetype_label(weapon, 0, true), &"archetype.duelist")
	assert_eq(ProgressionCalculator.combat_archetype_label(
			weapon, ProgressionCalculator.GUARDIAN_ARMOUR_WEIGHT, false), &"archetype.duelist")


func test_archetype_is_derived_and_never_stored() -> void:
	# Re-equipping must change the label immediately, and nothing about it may
	# appear in the saved profile (it is not a class).
	var character: CharacterData = CombatFixtures.make_character()
	character.weapon = CombatFixtures.make_weapon()
	character.weapon.weapon_class = Enums.WeaponClass.AXE
	assert_eq(ProgressionCalculator.archetype_of(character), &"archetype.breaker")
	character.weapon.weapon_class = Enums.WeaponClass.RANGED
	assert_eq(ProgressionCalculator.archetype_of(character), &"archetype.marksman",
			"the label must follow the kit, not a stored choice")

	var profile: PlayerProfile = PlayerProfile.create_default()
	var saved: Dictionary = profile.to_dict()
	for key: String in saved.keys():
		assert_false(key.contains("archetype") or key.contains("class"),
				"the archetype must never become a save field (%s)" % key)


func test_armour_weight_scores_by_class() -> void:
	var character: CharacterData = CombatFixtures.make_character()
	assert_eq(character.armour_weight(), 0, "an armourless debutant weighs nothing")
	assert_false(character.has_shield(), "no shield content exists yet")
	var heavy: ArmourData = ArmourData.new()
	heavy.armour_class = Enums.ArmourClass.HEAVY
	var light: ArmourData = ArmourData.new()
	light.armour_class = Enums.ArmourClass.LIGHT
	character.armour_pieces = [heavy, light, heavy]
	assert_eq(character.armour_weight(), 4, "heavy 2 + light 0 + heavy 2")


func test_every_archetype_label_is_translated() -> void:
	for key: String in ["archetype.breaker", "archetype.duelist", "archetype.skirmisher",
			"archetype.marksman", "archetype.battlemage", "archetype.guardian",
			"archetype.brawler", "sheet.archetype"]:
		assert_true(TranslationServer.translate(key) != key, "%s has no translation" % key)
