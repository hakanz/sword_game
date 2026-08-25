class_name Combatant
extends Node2D
## Runtime state of one fighter in combat. Derived stats are computed ONCE
## from CharacterData via ProgressionCalculator at setup — UI reads them from
## here, never recomputes. Visuals live in the PlaceholderRig child.

signal hp_changed(current: int, max_value: int)
signal energy_changed(current: int, max_value: int)
signal armour_changed(current: int, max_value: int)
signal stance_changed(new_stance: Enums.Stance)
## Crowd standing changed (CrowdSystem). Runtime only — never persisted.
signal crowd_changed(value: int, state: CrowdSystem.State)
signal died

## Arena zoom applied to the rig. Named because the arena framing depends on
## it: ArenaVisual puts the backdrop's wall base above the fighters, and how
## tall a fighter actually is on the sand is RIG_SCALE x the rig's own height
## (asserted in test_art.gd).
const RIG_SCALE: float = 1.35

var data: CharacterData = null
var is_player_controlled: bool = false

## Effective attributes for this fight: the character's own progression block
## PLUS the equipped kit's attribute affixes (V2 §52). Combat and the AI read
## THIS, never `data.attributes` — equipment must never mutate progression
## data. Computed once at setup.
var attributes: AttributeBlock = null
## Everything the equipped kit contributes (affix sums + signature effects).
## Fixed at setup: switching to the sidearm mid-fight never rewrites stats.
var kit: ItemAffixes.Bonuses = null

## Dual-wield state (owner design, session 3): ranged mains come with a
## melee sidearm; the fight STARTS on the sidearm and switching weapons is
## its own action. `arrows` is the per-combat ammo pool of the ranged main.
var main_weapon: WeaponData = null
var sidearm: WeaponData = null
var wielding_main: bool = true
var arrows: int = 0

var max_hp: int = 1
var current_hp: int = 1
var max_energy: int = 1
var current_energy: int = 1
var max_mana: int = 0
var current_mana: int = 0

var armour_max: int = 0
var armour_current: int = 0

var attack_rating: int = 0
var defence_rating: int = 0
var evasion_value: int = 0
var initiative_value: int = 0

var stance: Enums.Stance = Enums.Stance.NEUTRAL

## Position on the arena line (see CombatContext) — moving is personal:
## only the acting fighter's cell changes.
var cell: int = 0

## Active status effects (managed by StatusEffectSystem).
var status_effects: Array[StatusEffectInstance] = []

## Skill cooldowns: skill id -> rounds remaining. Ticked at own turn start.
var cooldowns: Dictionary = {}

## Guards the death animation/event against double-firing when a fighter
## falls to a DoT tick after already-resolved damage.
var death_announced: bool = false

## Total damage this fighter dealt (HP + armour), for the results screen.
var damage_dealt_total: int = 0

## Cells covered by one approach/retreat (agility + gear tiers, computed once
## at setup — see ProgressionCalculator.move_cells).
var move_cells: int = 1

## Combat-effectiveness tally (session-5 XP design): actions taken and
## strikes that actually landed — stalling with filler moves earns less XP.
var actions_taken: int = 0
var hits_landed: int = 0

## Boss phase this fighter is currently in (1 = opening shape). Tracked so a
## crossing is announced exactly once; recomputed from HP, never stored.
var phase: int = 1

## Standing with the audience for THIS fight (charter §19 / V2 §54).
## Starts Neutral, resets every duel, never saved.
var crowd: int = CrowdSystem.START

## Consecutive DEFEND actions (leaky counter) — the AI applies diminishing
## returns to turtling so two cautious fighters can never deadlock.
var consecutive_defends: int = 0
## TOTAL retreats this combat (never decays): fleeing is a budget, not a
## strategy — each retreat makes the next one less appealing to the AI.
var total_retreats: int = 0

var rig: PlaceholderRig = null


func setup(character: CharacterData, player_controlled: bool, facing_left: bool) -> void:
	data = character
	is_player_controlled = player_controlled

	kit = ItemAffixes.character_bonuses(data)
	attributes = ItemAffixes.effective_attributes(data.attributes, kit)
	var attrs: AttributeBlock = attributes
	max_hp = ProgressionCalculator.max_hp(attrs, data.level)
	current_hp = max_hp
	max_energy = ProgressionCalculator.max_energy(attrs, data.level)
	current_energy = max_energy
	max_mana = ProgressionCalculator.max_mana(attrs, data.level)
	current_mana = max_mana
	armour_max = data.total_armour() + kit.armour
	armour_current = armour_max
	attack_rating = ProgressionCalculator.attack_rating(attrs) + kit.accuracy
	defence_rating = ProgressionCalculator.defence_rating(attrs)
	evasion_value = ProgressionCalculator.evasion(attrs, data.total_evasion_mod() + kit.evasion)
	initiative_value = ProgressionCalculator.initiative(attrs)
	move_cells = ProgressionCalculator.move_cells(
			attrs.agility, data.total_mobility_bonus() + kit.mobility)

	main_weapon = data.weapon
	sidearm = data.weapon.sidearm
	arrows = data.weapon.ammo
	# Archers open on the knife and must switch to shoot (owner design).
	wielding_main = sidearm == null

	rig = PlaceholderRig.new()
	rig.body_color = data.body_color
	rig.accent_color = data.accent_color
	rig.weapon = get_weapon()
	rig.weapon_class = get_weapon().weapon_class
	rig.equipment = data.armour_pieces
	rig.facing_left = facing_left
	# Arena zoom (session-5 owner design: fighters must dominate the sand).
	rig.scale = Vector2(RIG_SCALE, RIG_SCALE)
	add_child(rig)
	# Low HP turns the resting face worried (rig expression baseline).
	hp_changed.connect(func(current: int, max_value: int) -> void:
		if rig != null:
			rig.set_worried_baseline(current < roundi(max_value * 0.35)))
	# Champions change shape as they fall (V2 §55).
	hp_changed.connect(func(_current: int, _max_value: int) -> void: refresh_phase())


func display_name() -> String:
	return data.display_name()


## Effective crit chance with the kit's affixes folded in (one math home:
## HitCalculator).
func crit_chance() -> float:
	return HitCalculator.crit_chance_for(attributes, get_weapon(), kit.crit_chance)


## Weapon armour penetration plus the kit's affixes, clamped by the caller.
func armour_penetration() -> float:
	return get_weapon().armour_penetration + kit.armour_penetration


## True when the equipped kit carries this signature effect (V2 §52.3).
func has_unique(effect: Enums.UniqueEffect) -> bool:
	return kit != null and kit.has(effect)


## Ticks every active cooldown down by `rounds` (Relentless Edge).
func reduce_cooldowns(rounds: int = 1) -> void:
	for id: StringName in cooldowns.keys():
		var left: int = int(cooldowns[id]) - rounds
		if left <= 0:
			cooldowns.erase(id)
		else:
			cooldowns[id] = left


func get_weapon() -> WeaponData:
	return main_weapon if wielding_main else sidearm


func can_switch_weapon() -> bool:
	return sidearm != null


func switch_weapon() -> void:
	assert(can_switch_weapon())
	wielding_main = not wielding_main
	if rig != null:
		rig.weapon = get_weapon()
		rig.weapon_class = get_weapon().weapon_class
		rig.queue_redraw()


## Resistance fraction (0-1) against a damage type. Always 0 for now —
## elemental resistances arrive with later equipment tiers and will be
## summed here from armour + effects.
func get_resistance(_damage_type: Enums.DamageType) -> float:
	return 0.0


## Known skills, plus the signature moves a boss unlocks in phase two. The AI
## and the HUD both read this, so a phase change needs no special-case code.
func get_skills() -> Array[SkillData]:
	if phase < 2 or data.phase_two_skills.is_empty():
		return data.skills
	var all: Array[SkillData] = data.skills.duplicate()
	for skill in data.phase_two_skills:
		if skill != null and not all.has(skill):
			all.append(skill)
	return all


## The temperament driving this fighter RIGHT NOW — a cornered champion
## fights with a different head (V2 §55), chosen from data, not a branch.
func active_personality() -> AIPersonality:
	if phase >= 3 and data.phase_three_personality != null:
		return data.phase_three_personality
	return data.personality


## Recomputes the boss phase from current HP and announces a crossing once.
## Phases never go backwards: healing out of a phase would flicker the
## announcement and take a signature move away mid-fight.
func refresh_phase() -> void:
	if not data.has_phases() or not is_alive():
		return
	var next: int = data.phase_at(float(current_hp) / float(max_hp))
	if next <= phase:
		return
	phase = next
	EventBus.boss_phase_changed.emit(self, phase)


## Direct HP damage (status DoTs) — bypasses the armour pool by design.
func take_direct_damage(amount: int) -> void:
	if amount <= 0:
		return
	current_hp = maxi(current_hp - amount, 0)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		died.emit()


## Returns the amount actually healed (capped at max HP).
func heal(amount: int) -> int:
	var healed: int = mini(amount, max_hp - current_hp)
	if healed > 0:
		current_hp += healed
		hp_changed.emit(current_hp, max_hp)
	return healed


## Returns the amount actually restored (capped at the pool).
func restore_mana(amount: int) -> int:
	if amount <= 0:
		return 0
	var before: int = current_mana
	current_mana = mini(current_mana + amount, max_mana)
	return current_mana - before


func spend_mana(amount: int) -> void:
	if amount <= 0:
		return
	current_mana = maxi(current_mana - amount, 0)


func set_cooldown(skill_id: StringName, rounds: int) -> void:
	if rounds > 0:
		cooldowns[skill_id] = rounds


func cooldown_remaining(skill_id: StringName) -> int:
	return int(cooldowns.get(skill_id, 0))


func tick_cooldowns() -> void:
	for skill_id: StringName in cooldowns.keys():
		cooldowns[skill_id] = int(cooldowns[skill_id]) - 1
		if int(cooldowns[skill_id]) <= 0:
			cooldowns.erase(skill_id)


func is_alive() -> bool:
	return current_hp > 0


## Applies a precomputed mitigation result (see DamageCalculator).
func take_damage(mitigation: DamageCalculator.MitigationResult) -> void:
	if armour_current != mitigation.armour_remaining:
		armour_current = mitigation.armour_remaining
		armour_changed.emit(armour_current, armour_max)
	if mitigation.hp_damage > 0:
		current_hp = maxi(current_hp - mitigation.hp_damage, 0)
		hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		died.emit()


func spend_energy(amount: int) -> void:
	if amount <= 0:
		return
	current_energy = maxi(current_energy - amount, 0)
	energy_changed.emit(current_energy, max_energy)


## Returns the amount actually restored (capped at max).
func restore_energy(amount: int) -> int:
	var restored: int = mini(amount, max_energy - current_energy)
	if restored > 0:
		current_energy += restored
		energy_changed.emit(current_energy, max_energy)
	return restored


func set_stance(new_stance: Enums.Stance) -> void:
	if stance == new_stance:
		return
	stance = new_stance
	stance_changed.emit(stance)
	if rig != null:
		rig.set_defending(stance == Enums.Stance.DEFENDING)


## Called by the controller at the start of this combatant's turn:
## a defend stance lasts until the defender's next turn begins.
func on_turn_started() -> void:
	set_stance(Enums.Stance.NEUTRAL)
	# The pit throws its weight behind its favourite (V2 §54). Small on
	# purpose: a build that ignores Charisma must stay viable.
	# `spend` = true: accepting the crowd's help costs standing, so the top of
	# the meter is a moment you keep earning, not a passive you park on.
	var boon: int = CrowdSystem.energy_boon(self, true)
	if boon > 0:
		restore_energy(boon)
