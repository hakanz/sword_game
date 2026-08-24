extends Node
## Item lookup service: stable logical ID -> item resource (charter §12:
## gameplay references IDs, never paths). Content lives in
## data/registry/item_registry.tres.
##
## Indexing is LAZY (first access), not in _ready(): in headless `-s` tool
## contexts (test runner) autoload singletons exist but never enter the tree,
## so _ready() would not run there.

const REGISTRY: ItemRegistry = preload("res://data/registry/item_registry.tres")

var _weapons: Dictionary = {}
var _armour: Dictionary = {}
var _skills: Dictionary = {}
var _indexed: bool = false


func _index_if_needed() -> void:
	if _indexed:
		return
	_indexed = true
	for weapon_data in REGISTRY.weapons:
		if _weapons.has(weapon_data.id):
			push_warning("ItemDB: duplicate weapon id %s" % weapon_data.id)
		_weapons[weapon_data.id] = weapon_data
	for piece in REGISTRY.armour:
		if _armour.has(piece.id):
			push_warning("ItemDB: duplicate armour id %s" % piece.id)
		_armour[piece.id] = piece
	for skill_data in REGISTRY.skills:
		if _skills.has(skill_data.id):
			push_warning("ItemDB: duplicate skill id %s" % skill_data.id)
		_skills[skill_data.id] = skill_data


func weapon(id: StringName) -> WeaponData:
	_index_if_needed()
	if not _weapons.has(id):
		push_warning("ItemDB: unknown weapon id '%s', falling back to first registered" % id)
		return REGISTRY.weapons[0]
	return _weapons[id]


func armour_piece(id: StringName) -> ArmourData:
	_index_if_needed()
	if not _armour.has(id):
		push_warning("ItemDB: unknown armour id '%s'" % id)
		return null
	return _armour[id]


func skill(id: StringName) -> SkillData:
	_index_if_needed()
	if not _skills.has(id):
		push_warning("ItemDB: unknown skill id '%s'" % id)
		return null
	return _skills[id]


func all_weapons() -> Array[WeaponData]:
	return REGISTRY.weapons.duplicate()


func all_armour() -> Array[ArmourData]:
	return REGISTRY.armour.duplicate()


func all_skills() -> Array[SkillData]:
	return REGISTRY.skills.duplicate()
