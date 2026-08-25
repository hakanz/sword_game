class_name ItemIcons
## Shared item iconography for shop and inventory rows.
##
## An item that carries its own painted art (`WeaponData.sprite`,
## `ArmourData.icon`) is shown as-is — the art already says which weapon it is
## and what it is made of. An item without one falls back to the original
## white per-class / per-slot glyph tinted by tier, which is what the whole
## catalogue looked like before the art existed (charter §27).

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

const COIN_GLYPH := preload("res://assets/icons/coin.svg")


## The painted sprite when the weapon has one, else the class glyph.
static func weapon_icon(weapon: WeaponData) -> Texture2D:
	if weapon.sprite != null:
		return weapon.sprite
	return WEAPON_ICONS.get(weapon.weapon_class, WEAPON_ICONS[Enums.WeaponClass.SWORD])


## The painted icon when the piece has one, else the slot glyph.
static func armour_icon(piece: ArmourData) -> Texture2D:
	if piece.icon != null:
		return piece.icon
	return ARMOUR_ICONS.get(piece.slot, ARMOUR_ICONS[Enums.EquipSlot.CHEST])


## True when this item draws itself — painted art must NOT be tier-tinted, the
## metal is already in the paint.
static func is_painted(item: Resource) -> bool:
	if item is WeaponData:
		return (item as WeaponData).sprite != null
	if item is ArmourData:
		return (item as ArmourData).icon != null
	return false


## Ready-to-place icon for a weapon or armour piece. Painted art is drawn
## untinted (the metal is already in the paint) and a weapon sprite is laid on
## the diagonal, because a weapon painted standing straight up is a few pixels
## wide once it is letterboxed into a square row slot.
static func make_item_icon(item: Resource, size: float = 44.0) -> Control:
	var painted: bool = is_painted(item)
	var weapon: bool = item is WeaponData
	var icon := ItemIconRect.new()
	icon.texture = weapon_icon(item as WeaponData) if weapon 			else armour_icon(item as ArmourData)
	icon.tint = Color.WHITE if painted else tier_tint(int(item.get("tier")))
	icon.angle = -PI / 4.0 if painted and weapon else 0.0
	icon.custom_minimum_size = Vector2(size, size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


class ItemIconRect:
	extends Control
	## Draws one item texture scaled to fit its box at `angle`, so a tall
	## weapon sprite uses the square's diagonal instead of its width.

	var texture: Texture2D = null
	var tint: Color = Color.WHITE
	var angle: float = 0.0

	func _draw() -> void:
		if texture == null:
			return
		var src: Vector2 = texture.get_size()
		if src.x <= 0.0 or src.y <= 0.0:
			return
		# Bounding box of the rotated sprite, solved for the largest scale
		# that still fits the control.
		var horizontal: float = absf(cos(angle))
		var vertical: float = absf(sin(angle))
		var fit: float = minf(
				size.x / (src.x * horizontal + src.y * vertical),
				size.y / (src.x * vertical + src.y * horizontal))
		var drawn: Vector2 = src * fit
		draw_set_transform(size * 0.5, angle, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-drawn * 0.5, drawn), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The gold coin used wherever a price or a purse is shown.
static func coin() -> Texture2D:
	var painted: Texture2D = ArtLibrary.ui(&"coin")
	return painted if painted != null else COIN_GLYPH


## Coin widget for a price row. The painted coin is already gold, so it is
## only tinted when the flat glyph is standing in for it.
static func make_coin(size: float = 20.0) -> TextureRect:
	var painted: Texture2D = ArtLibrary.ui(&"coin")
	var rect: TextureRect = make_icon(coin(), 5, size)
	if painted != null:
		rect.modulate = Color.WHITE
	return rect


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
