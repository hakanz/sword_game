class_name ItemIcons
## Shared item iconography: white base glyphs per weapon class / armour slot,
## tinted by tier (modulate) so shops/inventory read at a glance.
## Placeholder art rule applies (charter §27) — final per-item art replaces
## these via the same helper.

const WEAPON_ICONS: Dictionary = {
	Enums.WeaponClass.UNARMED: preload("res://assets/icons/class_sword.svg"),
	Enums.WeaponClass.SWORD: preload("res://assets/icons/class_sword.svg"),
	Enums.WeaponClass.AXE: preload("res://assets/icons/class_axe.svg"),
	Enums.WeaponClass.BLUNT: preload("res://assets/icons/class_blunt.svg"),
	Enums.WeaponClass.SPEAR: preload("res://assets/icons/class_spear.svg"),
	Enums.WeaponClass.RANGED: preload("res://assets/icons/class_bow.svg"),
	Enums.WeaponClass.MAGICAL: preload("res://assets/icons/class_staff.svg"),
}

const ARMOUR_ICONS: Dictionary = {
	Enums.EquipSlot.HELMET: preload("res://assets/icons/slot_helmet.svg"),
	Enums.EquipSlot.CHEST: preload("res://assets/icons/slot_chest.svg"),
	Enums.EquipSlot.SHOULDERS: preload("res://assets/icons/slot_shoulders.svg"),
	Enums.EquipSlot.GLOVES: preload("res://assets/icons/slot_gloves.svg"),
	Enums.EquipSlot.BELT: preload("res://assets/icons/slot_belt.svg"),
	Enums.EquipSlot.LEGS: preload("res://assets/icons/slot_legs.svg"),
	Enums.EquipSlot.BOOTS: preload("res://assets/icons/slot_boots.svg"),
}

## Tier -> metal tint applied via modulate over the white glyphs.
const TIER_TINTS: Dictionary = {
	1: Color(0.78, 0.66, 0.54),
	2: Color(0.9, 0.65, 0.38),
	3: Color(0.8, 0.82, 0.86),
	4: Color(0.68, 0.78, 0.95),
	5: Color(0.98, 0.83, 0.42),
}
const TIER_TINT_HIGH := Color(0.85, 0.6, 0.95)


static func weapon_icon(weapon: WeaponData) -> Texture2D:
	return WEAPON_ICONS.get(weapon.weapon_class, WEAPON_ICONS[Enums.WeaponClass.SWORD])


static func armour_icon(piece: ArmourData) -> Texture2D:
	return ARMOUR_ICONS.get(piece.slot, ARMOUR_ICONS[Enums.EquipSlot.CHEST])


static func tier_tint(tier: int) -> Color:
	return TIER_TINTS.get(tier, TIER_TINT_HIGH)


## Ready-to-place icon widget (glyph + tier tint), used by shop/inventory rows.
static func make_icon(icon: Texture2D, tier: int, size: float = 40.0) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = tier_tint(tier)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect
