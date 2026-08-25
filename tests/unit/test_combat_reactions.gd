extends TestCase
## Coverage for the charter §25 reaction set added on top of the existing
## hit/miss feedback: the resolver flags that tell a BLOCK from a clean hit, a
## PARRY from a plain miss and an ARMOUR BREAK from ordinary chip damage, plus
## the animation entry points the controller calls and the blood toggle.
##
## The flags live on ActionResult and are set in CombatResolver, which is the
## single execution path the §35 simulator drives too — so they are asserted
## by running real actions, never by re-deriving the maths here.

func _duel(defender_armour: int = 0) -> Dictionary:
	var attacker: Combatant = CombatFixtures.make_combatant()
	var defender_character: CharacterData = CombatFixtures.make_character()
	if defender_armour > 0:
		var plate := ArmourData.new()
		plate.id = &"armour.test_plate"
		plate.slot = Enums.EquipSlot.CHEST
		plate.armour = defender_armour
		defender_character.armour_pieces = [plate] as Array[ArmourData]
	var defender: Combatant = CombatFixtures.make_combatant(defender_character)
	var ctx: CombatContext = CombatFixtures.make_context(attacker, defender, 1)
	return {"attacker": attacker, "defender": defender, "ctx": ctx}


## One swing. Energy is topped up first: these tests care about what a landed
## blow REPORTS, and a fighter who runs dry would fail the resolver's own
## validity assert long before the armour pool empties.
func _attack(duel: Dictionary) -> ActionResult:
	var attacker: Combatant = duel["attacker"]
	attacker.restore_energy(attacker.max_energy)
	var decision := CombatDecision.new()
	decision.type = Enums.ActionType.ATTACK
	if not CombatAction.is_valid(decision.type, attacker, duel["ctx"]):
		return null
	return CombatResolver.execute(attacker, duel["defender"], duel["ctx"], decision)


func _free(duel: Dictionary) -> void:
	duel["attacker"].free()
	duel["defender"].free()


# --- Block / parry ----------------------------------------------------------

## A guarded target is recorded as guarded whether the blow lands or not —
## that one flag is what separates the block reaction from the parry one.
func test_guarded_target_is_flagged() -> void:
	var duel: Dictionary = _duel()
	duel["defender"].set_stance(Enums.Stance.DEFENDING)
	RngService.set_seed(11)
	var result: ActionResult = _attack(duel)
	assert_true(result.target_was_defending,
			"a defending target must be flagged, hit=%s" % result.hit)
	_free(duel)


func test_unguarded_target_is_not_flagged() -> void:
	var duel: Dictionary = _duel()
	duel["defender"].set_stance(Enums.Stance.NEUTRAL)
	RngService.set_seed(11)
	var result: ActionResult = _attack(duel)
	assert_false(result.target_was_defending, "a neutral target must not be flagged")
	_free(duel)


# --- Armour break -----------------------------------------------------------

## The break fires on the blow that empties a pool that had something in it,
## and never again while the pool stays empty. Driven by swinging until the
## armour actually runs out rather than by asserting a hand-computed round.
func test_armour_break_fires_once_when_the_pool_empties() -> void:
	var duel: Dictionary = _duel(30)
	RngService.set_seed(5)
	assert_true(duel["defender"].armour_current > 0, "test needs a starting pool")
	var breaks: int = 0
	var breaks_after_empty: int = 0
	var swings: int = 0
	# The defender is kept alive so the pool can be beaten flat and then hit
	# again — the point is what happens AFTER the break, not the kill.
	while swings < 60:
		duel["defender"].heal(duel["defender"].max_hp)
		var was_empty: bool = duel["defender"].armour_current == 0
		var result: ActionResult = _attack(duel)
		if result == null:
			break
		swings += 1
		if result.armour_broken:
			breaks += 1
			if was_empty:
				breaks_after_empty += 1
		if breaks > 0 and swings > 30:
			break
	assert_eq(breaks, 1, "armour should break exactly once (%d swings)" % swings)
	assert_eq(breaks_after_empty, 0, "an empty pool cannot break again")
	assert_eq(duel["defender"].armour_current, 0, "the pool should be flat by now")
	_free(duel)


func test_unarmoured_target_never_reports_a_break() -> void:
	var duel: Dictionary = _duel(0)
	RngService.set_seed(9)
	assert_eq(duel["defender"].armour_current, 0, "test needs an empty pool")
	var breaks: int = 0
	var swings: int = 0
	for _swing in 12:
		duel["defender"].heal(duel["defender"].max_hp)
		var result: ActionResult = _attack(duel)
		if result == null:
			break
		swings += 1
		if result.armour_broken:
			breaks += 1
	assert_true(swings >= 10, "the loop must actually swing, got %d" % swings)
	assert_eq(breaks, 0, "a fighter with no armour has nothing to break")
	_free(duel)


# --- Blood toggle (charter §25/§30) ----------------------------------------

## Blood is its own setting, independent of `reduced_fx` — turning the spray
## off must not flatten every other effect, and vice versa.
func test_blood_toggle_is_independent_of_reduced_fx() -> void:
	var blood_before: Variant = SaveManager.get_setting(
			CombatVfx.BLOOD_SETTING, CombatVfx.BLOOD_DEFAULT)
	var fx_before: Variant = SaveManager.get_setting(
			CombatFeel.REDUCED_FX_SETTING, false)

	SaveManager.set_setting(CombatVfx.BLOOD_SETTING, false)
	SaveManager.set_setting(CombatFeel.REDUCED_FX_SETTING, false)
	assert_false(CombatVfx.blood_enabled(), "blood off should read as off")
	assert_false(bool(SaveManager.get_setting(CombatFeel.REDUCED_FX_SETTING, false)),
			"turning blood off must not turn reduced effects on")

	SaveManager.set_setting(CombatVfx.BLOOD_SETTING, true)
	SaveManager.set_setting(CombatFeel.REDUCED_FX_SETTING, true)
	assert_true(CombatVfx.blood_enabled(),
			"reduced effects must not force blood off")

	SaveManager.set_setting(CombatVfx.BLOOD_SETTING, blood_before)
	SaveManager.set_setting(CombatFeel.REDUCED_FX_SETTING, fx_before)


func test_blood_defaults_on() -> void:
	assert_true(CombatVfx.BLOOD_DEFAULT,
			"blood ships on; the setting exists to turn it OFF")


# --- Rig animation set (charter §25) ---------------------------------------

## Every §25 reaction the controller calls must exist on the rig. A missing
## one is a runtime error deep in a fight, which no other suite would catch.
func test_rig_exposes_the_full_reaction_set() -> void:
	var rig := PlaceholderRig.new()
	for method in ["play_block", "play_parry", "play_critical_reaction",
			"set_stunned", "play_taunt", "play_move", "play_attack_lunge",
			"play_hit_flash", "play_miss_dodge", "play_rest", "play_victory",
			"play_death", "play_switch_flourish"]:
		assert_true(rig.has_method(method), "rig is missing %s" % method)
	rig.free()


## Driving the real rig: the reactions must run without a scene tree behind
## them (the shop's fitting doll and the creation preview both do this) and
## the stun state must be reversible.
func test_rig_reactions_run_and_stun_clears() -> void:
	var rig := PlaceholderRig.new()
	Engine.get_main_loop().root.add_child(rig)
	rig.play_block()
	rig.play_parry()
	rig.play_critical_reaction()
	rig.play_taunt()
	rig.play_move(2, 0.3)
	rig.set_stunned(true)
	assert_true(rig.get_children().any(func(child: Node) -> bool:
			return child is PlaceholderRig.StunStars),
			"stun should add the circling stars")
	rig.set_stunned(false)
	assert_false(rig.get_children().any(func(child: Node) -> bool:
			return child is PlaceholderRig.StunStars and not child.is_queued_for_deletion()),
			"clearing stun should drop the stars")
	rig.queue_free()


## The taunt animation is driven by a DATA flag, not a hardcoded skill id, so
## adding a showboating move stays a content task (charter architecture §1).
func test_taunting_is_a_data_flag() -> void:
	var plain := SkillData.new()
	assert_false(plain.taunts, "skills must not taunt by default")
	var tagged: int = 0
	for skill in ItemDB.all_skills():
		if skill.taunts:
			tagged += 1
	assert_true(tagged > 0, "no skill is tagged as a taunt")
	assert_true(tagged < ItemDB.all_skills().size(),
			"if every skill taunts, the flag says nothing")
