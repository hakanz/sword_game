class_name Combatant
extends Node2D
## Runtime state of one fighter in combat. Derived stats are computed ONCE
## from CharacterData via ProgressionCalculator at setup — UI reads them from
## here, never recomputes. Visuals live in the PlaceholderRig child.

signal hp_changed(current: int, max_value: int)
signal energy_changed(current: int, max_value: int)
signal armour_changed(current: int, max_value: int)
signal stance_changed(new_stance: Enums.Stance)
signal died

var data: CharacterData = null
var is_player_controlled: bool = false

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

	var attrs: AttributeBlock = data.attributes
	max_hp = ProgressionCalculator.max_hp(attrs, data.level)
	current_hp = max_hp
	max_energy = ProgressionCalculator.max_energy(attrs, data.level)
	current_energy = max_energy
	max_mana = ProgressionCalculator.max_mana(attrs, data.level)
	current_mana = max_mana
	armour_max = data.total_armour()
	armour_current = armour_max
	attack_rating = ProgressionCalculator.attack_rating(attrs)
	defence_rating = ProgressionCalculator.defence_rating(attrs)
	evasion_value = ProgressionCalculator.evasion(attrs, data.total_evasion_mod())
	initiative_value = ProgressionCalculator.initiative(attrs)

	rig = PlaceholderRig.new()
	rig.body_color = data.body_color
	rig.accent_color = data.accent_color
	rig.weapon_class = data.weapon.weapon_class
	rig.facing_left = facing_left
	add_child(rig)


func display_name() -> String:
	return data.display_name()


func get_weapon() -> WeaponData:
	return data.weapon


## Resistance fraction (0-1) against a damage type. Always 0 for now —
## elemental resistances arrive with later equipment tiers and will be
## summed here from armour + effects.
func get_resistance(_damage_type: Enums.DamageType) -> float:
	return 0.0


func get_skills() -> Array[SkillData]:
	return data.skills


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
