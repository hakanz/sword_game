class_name EquipmentService
## Equip/requirement rules shared by the inventory UI, shop UI, and (later)
## opponent validation. One source of truth: UI never re-implements gating.


## "" when equippable; otherwise the localization key of the blocking reason.
## The UI formats requirement details itself (it has the item at hand).
static func weapon_block_reason(profile: PlayerProfile, weapon: WeaponData) -> String:
	if profile.level < weapon.required_level:
		return "equip.requires_level"
	if profile.attributes.strength < weapon.required_strength:
		return "equip.requires_strength"
	if profile.attributes.agility < weapon.required_agility:
		return "equip.requires_agility"
	if profile.attributes.arcana < weapon.required_arcana:
		return "equip.requires_arcana"
	return ""


static func armour_block_reason(profile: PlayerProfile, piece: ArmourData) -> String:
	if profile.level < piece.required_level:
		return "equip.requires_level"
	if profile.attributes.strength < piece.required_strength:
		return "equip.requires_strength"
	return ""


## True when `weapon` outclasses the currently equipped weapon (higher
## expected damage; accuracy breaks ties). Drives the shop's auto-equip.
static func is_weapon_upgrade(profile: PlayerProfile, weapon: WeaponData) -> bool:
	var current: WeaponData = ItemDB.weapon(profile.weapon_id)
	if current == null:
		return true
	if weapon.average_damage() != current.average_damage():
		return weapon.average_damage() > current.average_damage()
	return weapon.accuracy_bonus > current.accuracy_bonus


## True when `piece` beats what is worn in its slot (empty slot = upgrade).
static func is_armour_upgrade(profile: PlayerProfile, piece: ArmourData) -> bool:
	for worn_id in profile.armour_ids:
		var worn: ArmourData = ItemDB.armour_piece(worn_id)
		if worn != null and worn.slot == piece.slot:
			return piece.armour > worn.armour
	return true


static func owns_weapon(profile: PlayerProfile, id: StringName) -> bool:
	return profile.weapon_id == id or profile.inventory_weapon_ids.has(id)


static func owns_armour(profile: PlayerProfile, id: StringName) -> bool:
	return profile.armour_ids.has(id) or profile.inventory_armour_ids.has(id)


## Swaps the equipped weapon with one from the inventory. Returns false when
## the weapon is not owned, not in the inventory, or requirements block it.
static func equip_weapon(profile: PlayerProfile, id: StringName) -> bool:
	if not profile.inventory_weapon_ids.has(id):
		return false
	var weapon: WeaponData = ItemDB.weapon(id)
	if weapon == null or weapon.id != id:
		return false
	if weapon_block_reason(profile, weapon) != "":
		return false
	profile.inventory_weapon_ids.erase(id)
	profile.inventory_weapon_ids.append(profile.weapon_id)
	profile.weapon_id = id
	# A newly equipped main weapon has never been drawn: the first fight
	# opens on the sidearm rule again (session-6 review finding — a melee
	# win must not pre-draw a bow bought afterwards).
	profile.prefers_main_weapon = false
	return true


## Equips an armour piece from the inventory, swapping out any piece already
## worn in the same slot. Returns false when not owned or blocked.
static func equip_armour(profile: PlayerProfile, id: StringName) -> bool:
	if not profile.inventory_armour_ids.has(id):
		return false
	var piece: ArmourData = ItemDB.armour_piece(id)
	if piece == null:
		return false
	if armour_block_reason(profile, piece) != "":
		return false
	profile.inventory_armour_ids.erase(id)
	for worn_id in profile.armour_ids:
		var worn: ArmourData = ItemDB.armour_piece(worn_id)
		if worn != null and worn.slot == piece.slot:
			profile.armour_ids.erase(worn_id)
			profile.inventory_armour_ids.append(worn_id)
			break
	profile.armour_ids.append(id)
	return true
