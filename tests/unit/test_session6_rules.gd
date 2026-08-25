extends TestCase
## Session-6 owner rules: weapon-based crits, debut rewards, the ranged
## weapon-preference/fatigue loop, armourless starts and the long opening
## distance.


func _attrs_with(attr_name: String, value: int) -> AttributeBlock:
	var attrs := CombatFixtures.make_attributes()
	attrs.set(attr_name, value)
	return attrs


# --- Critical hits -----------------------------------------------------------

func test_crit_scales_with_the_class_matched_attribute() -> void:
	var maul := CombatFixtures.make_weapon(10, 14, 0, 0.0,
			Enums.DistanceBand.ADJACENT, Enums.DistanceBand.ADJACENT, 5,
			Enums.WeaponClass.BLUNT)
	maul.crit_chance = 0.03
	var weak := HitCalculator.crit_chance_for(_attrs_with("strength", 5), maul)
	var strong := HitCalculator.crit_chance_for(_attrs_with("strength", 20), maul)
	assert_true(strong > weak, "strength must sharpen a blunt weapon's crits")
	assert_eq(strong, 0.03 + 20 * CombatTuning.CRIT_ATTR_PER_POINT)
	# Agility must NOT move a blunt weapon's crits.
	var agile := HitCalculator.crit_chance_for(_attrs_with("agility", 20), maul)
	assert_eq(agile, 0.03 + 8 * CombatTuning.CRIT_ATTR_PER_POINT,
			"blunt crits read strength, not agility")


func test_crit_attribute_mapping() -> void:
	assert_eq(HitCalculator.crit_attribute(Enums.WeaponClass.BLUNT), "strength")
	assert_eq(HitCalculator.crit_attribute(Enums.WeaponClass.AXE), "strength")
	assert_eq(HitCalculator.crit_attribute(Enums.WeaponClass.SWORD), "agility")
	assert_eq(HitCalculator.crit_attribute(Enums.WeaponClass.RANGED), "agility")
	assert_eq(HitCalculator.crit_attribute(Enums.WeaponClass.SPEAR), "attack")
	assert_eq(HitCalculator.crit_attribute(Enums.WeaponClass.MAGICAL), "arcana")


func test_crit_chance_is_clamped() -> void:
	var dagger := CombatFixtures.make_weapon()
	dagger.crit_chance = 0.5
	assert_eq(HitCalculator.crit_chance_for(_attrs_with("agility", 50), dagger),
			CombatTuning.MAX_CRIT_CHANCE, "crit chance caps out")


func test_crits_occur_and_hurt_more() -> void:
	RngService.set_seed(2024)
	var striker := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 8, 30, 1, 9, 8, 3, 5)))
	striker.max_energy = 10_000
	striker.current_energy = 10_000
	var target := CombatFixtures.make_combatant(CombatFixtures.make_character(
			CombatFixtures.make_attributes(8, 1, 8, 1, 30, 8, 3, 5)))
	var ctx := CombatFixtures.make_context(striker, target, 1)
	var strike := CombatDecision.new()
	strike.type = Enums.ActionType.ATTACK
	var crits: int = 0
	var swings: int = 0
	for _i in 600:
		target.current_hp = target.max_hp
		target.armour_current = 0
		if CombatAction.is_valid(Enums.ActionType.ATTACK, striker, ctx):
			var result: ActionResult = CombatResolver.execute(striker, target, ctx, strike)
			if result.hit:
				swings += 1
				if result.crit:
					crits += 1
	assert_true(swings > 300, "fixture must actually swing")
	var rate: float = float(crits) / float(swings)
	assert_true(rate > 0.01 and rate < 0.2,
			"crit rate lands near the configured chance (got %.3f)" % rate)
	striker.free()
	target.free()


# --- Ranged preference + fatigue (session-6 loop) ----------------------------

func test_win_keeps_the_chosen_weapon_and_loss_resets_it() -> void:
	var saved_profile: PlayerProfile = GameManager.profile
	var profile := PlayerProfile.create_default()
	GameManager.profile = profile

	var won := CombatResult.new()
	won.player_won = true
	won.enemy_level = 1
	won.player_ended_wielding_main = true
	won.player_could_switch = true
	GameManager.last_combat_result = won
	GameManager.consume_combat_rewards()
	assert_true(profile.prefers_main_weapon, "a win carries the held weapon forward")
	assert_false(profile.battle_fatigue, "victory leaves no fatigue")

	# Melee-only wins must NOT form weapon memory (session-6 review finding:
	# a shiv victory would otherwise pre-draw a bow bought afterwards).
	profile.prefers_main_weapon = false
	var melee_win := CombatResult.new()
	melee_win.player_won = true
	melee_win.enemy_level = 1
	melee_win.player_ended_wielding_main = true
	melee_win.player_could_switch = false
	GameManager.last_combat_result = melee_win
	GameManager.consume_combat_rewards()
	assert_false(profile.prefers_main_weapon,
			"a fight with no switch choice carries no weapon memory")

	var lost := CombatResult.new()
	lost.player_won = false
	lost.enemy_level = 1
	lost.player_ended_wielding_main = true
	GameManager.last_combat_result = lost
	GameManager.consume_combat_rewards()
	assert_false(profile.prefers_main_weapon, "a loss resets to the sidearm rule")
	assert_true(profile.battle_fatigue, "a loss leaves the fighter drained")

	GameManager.last_combat_result = null
	GameManager.profile = saved_profile


func test_equipping_a_new_weapon_clears_weapon_memory() -> void:
	var profile := PlayerProfile.create_default()
	profile.prefers_main_weapon = true
	profile.level = 4
	profile.attributes.agility = 13
	profile.inventory_weapon_ids.append(&"weapon.hunting_bow")
	assert_true(EquipmentService.equip_weapon(profile, &"weapon.hunting_bow"))
	assert_false(profile.prefers_main_weapon,
			"a never-drawn main weapon starts on the sidearm rule")


func test_profile_roundtrips_the_new_fields() -> void:
	var profile := PlayerProfile.create_default()
	profile.prefers_main_weapon = true
	profile.battle_fatigue = true
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_true(copy.prefers_main_weapon)
	assert_true(copy.battle_fatigue)


# --- Starter experience ------------------------------------------------------

func test_new_gladiator_starts_bare_with_a_shiv() -> void:
	var profile := PlayerProfile.create_default()
	assert_eq(profile.weapon_id, &"weapon.worn_shiv")
	assert_eq(profile.armour_ids.size(), 0)


func test_level_one_opponents_come_armourless() -> void:
	RngService.set_seed(99)
	for _i in 10:
		var rookie: CharacterData = OpponentGenerator.generate_at_level(1)
		assert_eq(rookie.armour_pieces.size(), 0,
				"level-1 pit fighters start as bare as the player")
	var veteran: CharacterData = OpponentGenerator.generate_at_level(6)
	assert_true(veteran.armour_pieces.size() > 0,
			"gear returns from level 2 up (chest is guaranteed)")


func test_default_opening_distance_is_long() -> void:
	var left := CombatFixtures.make_combatant()
	var right := CombatFixtures.make_combatant()
	var ctx := CombatContext.new()
	ctx.setup(left, right)
	assert_eq(ctx.separation(), 5, "openers stand several moves apart")
	assert_eq(ctx.band(), Enums.DistanceBand.LONG)
	left.free()
	right.free()


# --- Skill guidance ----------------------------------------------------------

func test_recommendations_follow_the_dominant_attribute() -> void:
	var profile := PlayerProfile.create_default()
	profile.attributes.strength = 15  # dominant
	profile.weapon_id = &"weapon.rustpick_club"  # BLUNT: crushing blow usable
	assert_eq(SkillService.dominant_attribute(profile), "strength")
	assert_true(SkillService.is_recommended(profile, ItemDB.skill(&"skill.crushing_blow")))
	assert_false(SkillService.is_recommended(profile, ItemDB.skill(&"skill.ember_bolt")),
			"an arcana spell is no match for a strength brute")
