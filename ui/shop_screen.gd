extends Control
## Merchant screen (SHOP state): the street has TWO shops now (owner design,
## session 3) — Bragga's weapon stall and Tetta's armoury. Which one you are
## standing in comes from GameManager.shop_kind. Stock is sorted by price and
## every row carries the item's tier-tinted glyph. Prices come ONLY from
## EconomyCalculator (charter §22). Buying a strict upgrade auto-equips and
## offers the old piece for sale.

enum Mode { BUY, SELL }

var _mode: Mode = Mode.BUY

## Pending old-item sale offered after an auto-equip: {is_weapon, id, price}.
var _pending_sale: Dictionary = {}

## The fitting-booth doll (session-5 owner design): shows the player wearing
## their CURRENT kit; hovering a row previews that item swapped in so the
## change is visible before a single coin moves.
var _doll: PlaceholderRig = null

@onready var _title: Label = %TitleLabel
@onready var _flavor: Label = %FlavorLabel
@onready var _gold: Label = %GoldLabel
@onready var _gold_icon: TextureRect = %GoldIcon
@onready var _tab_buy: Button = %BuyTabButton
@onready var _tab_sell: Button = %SellTabButton
@onready var _list: VBoxContainer = %ItemList
@onready var _back: Button = %BackButton
@onready var _fitting_anchor: Control = %FittingAnchor
@onready var _fitting_info: Label = %FittingInfo
@onready var _auto_equip_dialog: ConfirmationDialog = %AutoEquipDialog


func _weapons_mode() -> bool:
	return GameManager.shop_kind == GameManager.ShopKind.WEAPONS


func _ready() -> void:
	if GameManager.profile == null:
		SceneRouter.goto_main_menu()
		return
	_title.text = tr("shop.weaponsmith.title") if _weapons_mode() else tr("shop.armourer.title")
	_flavor.text = tr("shop.weaponsmith.flavor") if _weapons_mode() else tr("shop.armourer.flavor")
	_gold_icon.texture = preload("res://assets/icons/coin.svg")
	_tab_buy.text = tr("shop.tab_buy")
	_tab_sell.text = tr("shop.tab_sell")
	_back.text = tr("common.back")
	_auto_equip_dialog.title = tr("shop.auto_equipped_title")
	_auto_equip_dialog.cancel_button_text = tr("shop.keep")
	_auto_equip_dialog.confirmed.connect(_on_sale_confirmed)
	_tab_buy.pressed.connect(func() -> void: _set_mode(Mode.BUY))
	_tab_sell.pressed.connect(func() -> void: _set_mode(Mode.SELL))
	_back.pressed.connect(SceneRouter.goto_town)

	_doll = PlaceholderRig.new()
	_doll.scale = Vector2(1.8, 1.8)
	_fitting_anchor.add_child(_doll)
	_fitting_anchor.resized.connect(_position_doll)
	_position_doll.call_deferred()

	_set_mode(Mode.BUY)


func _position_doll() -> void:
	_doll.position = Vector2(_fitting_anchor.size.x / 2.0, _fitting_anchor.size.y * 0.94)


## Dresses the doll in the player's CURRENT kit, optionally previewing one
## item swapped into its slot (armour) or hand (weapon).
func _dress_doll(preview_item: Resource = null) -> void:
	var profile: PlayerProfile = GameManager.profile
	_doll.body_color = profile.body_color
	_doll.accent_color = profile.accent_color

	var shown_weapon: WeaponData = ItemDB.weapon(profile.weapon_id)
	var pieces: Array[ArmourData] = []
	for worn_id in profile.armour_ids:
		var worn: ArmourData = ItemDB.armour_piece(worn_id)
		if worn != null:
			pieces.append(worn)

	var info_lines: Array[String] = []
	if preview_item is WeaponData:
		var new_weapon := preview_item as WeaponData
		if shown_weapon != null:
			info_lines.append(tr("shop.preview_equipped").format(
					{"item": tr(shown_weapon.name_key)}))
			info_lines.append(tr("shop.delta_damage").format({
				"old_min": shown_weapon.damage_min, "old_max": shown_weapon.damage_max,
				"new_min": new_weapon.damage_min, "new_max": new_weapon.damage_max,
			}))
		shown_weapon = new_weapon
		info_lines.append(tr("shop.preview_new").format(
				{"item": tr(new_weapon.name_key)}))
	elif preview_item is ArmourData:
		var piece := preview_item as ArmourData
		var old_armour: int = 0
		for index in range(pieces.size() - 1, -1, -1):
			if pieces[index].slot == piece.slot:
				old_armour = pieces[index].armour
				info_lines.append(tr("shop.preview_equipped").format(
						{"item": tr(pieces[index].name_key)}))
				pieces.remove_at(index)
		pieces.append(piece)
		info_lines.append(tr("shop.delta_armour").format(
				{"old": old_armour, "new": piece.armour}))
		info_lines.append(tr("shop.preview_new").format(
				{"item": tr(piece.name_key)}))
	elif shown_weapon != null:
		info_lines.append(tr("shop.preview_equipped").format(
				{"item": tr(shown_weapon.name_key)}))

	_doll.weapon = shown_weapon
	_doll.weapon_class = shown_weapon.weapon_class if shown_weapon != null \
			else Enums.WeaponClass.UNARMED
	_doll.equipment = pieces
	_fitting_info.text = "\n".join(info_lines)


func _set_mode(mode: Mode) -> void:
	_mode = mode
	_tab_buy.disabled = mode == Mode.BUY
	_tab_sell.disabled = mode == Mode.SELL
	_refresh()


func _refresh() -> void:
	var profile: PlayerProfile = GameManager.profile
	_gold.text = str(profile.gold)
	for child in _list.get_children():
		child.queue_free()

	if _mode == Mode.BUY:
		if _weapons_mode():
			var stock: Array[WeaponData] = ItemDB.all_weapons().filter(
					func(w: WeaponData) -> bool: return w.shop_available)
			stock.sort_custom(_cheaper_first)
			for weapon in stock:
				_add_buy_row(profile, weapon, true)
		else:
			var stock: Array[ArmourData] = ItemDB.all_armour().filter(
					func(a: ArmourData) -> bool: return a.shop_available)
			stock.sort_custom(_cheaper_first)
			for piece in stock:
				_add_buy_row(profile, piece, false)
	else:
		var any: bool = false
		var ids: Array[StringName] = profile.inventory_weapon_ids if _weapons_mode() \
				else profile.inventory_armour_ids
		var rows: Array[Resource] = []
		for id in ids:
			var item: Resource = ItemDB.weapon(id) if _weapons_mode() else ItemDB.armour_piece(id)
			if item != null and item.get("id") == id:
				rows.append(item)
		rows.sort_custom(_cheaper_first)
		for item in rows:
			any = true
			_add_sell_row(profile, item, _weapons_mode())
		if not any:
			var empty := Label.new()
			empty.text = tr("inventory.empty")
			empty.add_theme_font_size_override("font_size", 18)
			_list.add_child(empty)

	# Re-sync the fitting doll with whatever is actually worn now.
	_dress_doll()


func _cheaper_first(a: Resource, b: Resource) -> bool:
	return int(a.get("value")) < int(b.get("value"))


func _add_buy_row(profile: PlayerProfile, item: Resource, is_weapon: bool) -> void:
	# Level-locked stock is SEALED (session-5 owner design): the crate shows
	# on the shelf, its contents stay hidden until the level unlocks — then
	# the full stats and benefits open up.
	if profile.level < int(item.get("required_level")):
		_add_sealed_row(item, is_weapon)
		return
	var price: int = EconomyCalculator.buy_price(
			GameManager.ECONOMY_CONFIG, item.get("value"), profile.attributes.charisma)
	var owned: bool = EquipmentService.owns_weapon(profile, item.get("id")) if is_weapon \
			else EquipmentService.owns_armour(profile, item.get("id"))
	var reason: String = EquipmentService.weapon_block_reason(profile, item) if is_weapon \
			else EquipmentService.armour_block_reason(profile, item)
	var row: HBoxContainer = _make_row(item, is_weapon,
			_requirement_text(reason, item as WeaponData if is_weapon else null,
					null if is_weapon else item as ArmourData))
	if owned:
		var owned_label := Label.new()
		owned_label.text = tr("shop.owned")
		owned_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		owned_label.add_theme_font_size_override("font_size", 16)
		row.add_child(owned_label)
	else:
		var price_label := Label.new()
		price_label.text = str(price)
		price_label.add_theme_font_size_override("font_size", 18)
		price_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		row.add_child(price_label)
		row.add_child(ItemIcons.make_icon(preload("res://assets/icons/coin.svg"), 5, 20))
		var button := Button.new()
		button.text = tr("shop.buy")
		button.custom_minimum_size = Vector2(110, 48)
		button.disabled = profile.gold < price
		button.pressed.connect(_buy.bind(profile, is_weapon, item))
		row.add_child(button)


func _add_sell_row(profile: PlayerProfile, item: Resource, is_weapon: bool) -> void:
	var price: int = EconomyCalculator.sell_price(
			GameManager.ECONOMY_CONFIG, item.get("value"), profile.attributes.charisma)
	var row: HBoxContainer = _make_row(item, is_weapon, "")
	var button := Button.new()
	button.text = tr("shop.sell").format({"price": price})
	button.custom_minimum_size = Vector2(130, 48)
	button.pressed.connect(_sell.bind(profile, is_weapon, item.get("id") as StringName, int(item.get("value"))))
	row.add_child(button)


## A sealed crate row: silhouette glyph, no name, no stats — just the level
## that will crack it open.
func _add_sealed_row(item: Resource, is_weapon: bool) -> void:
	var panel := PanelContainer.new()
	panel.modulate = Color(0.72, 0.7, 0.78)
	_list.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var glyph: Texture2D = ItemIcons.weapon_icon(item) if is_weapon else ItemIcons.armour_icon(item)
	var icon: Control = ItemIcons.make_icon(glyph, int(item.get("tier")))
	icon.modulate = Color(0.12, 0.1, 0.14)  # blacked-out silhouette
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = tr("shop.locked_name")
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(0.6, 0.56, 0.66))
	info.add_child(name_label)
	var hint := Label.new()
	hint.text = tr("shop.locked_hint").format({"level": int(item.get("required_level"))})
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	info.add_child(hint)


func _make_row(item: Resource, is_weapon: bool, requirement: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	# Hovering any readable row previews the item on the fitting doll;
	# leaving the row re-dresses the doll in the ACTUAL kit.
	panel.mouse_entered.connect(_dress_doll.bind(item))
	panel.mouse_exited.connect(_dress_doll.bind(null))
	_list.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var tier: int = int(item.get("tier"))
	var glyph: Texture2D = ItemIcons.weapon_icon(item) if is_weapon else ItemIcons.armour_icon(item)
	row.add_child(ItemIcons.make_icon(glyph, tier))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = tr(item.get("name_key"))
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", ItemIcons.tier_tint(tier).lightened(0.25))
	info.add_child(name_label)
	var stats_label := Label.new()
	stats_label.text = _weapon_stats(item) if is_weapon else _armour_stats(item)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
	info.add_child(stats_label)
	if requirement != "":
		var req_label := Label.new()
		req_label.text = requirement
		req_label.add_theme_font_size_override("font_size", 14)
		req_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
		info.add_child(req_label)
	return row


func _buy(profile: PlayerProfile, is_weapon: bool, item: Resource) -> void:
	var price: int = EconomyCalculator.buy_price(
			GameManager.ECONOMY_CONFIG, item.get("value"), profile.attributes.charisma)
	if profile.gold < price:
		return
	profile.gold -= price
	AudioManager.play(&"coin")
	if is_weapon:
		profile.inventory_weapon_ids.append(item.get("id"))
	else:
		profile.inventory_armour_ids.append(item.get("id"))

	# Auto-equip upgrades (session-2 directive), then offer the old piece
	# for sale at its current price.
	var old_id: StringName = &""
	if is_weapon:
		var weapon := item as WeaponData
		if EquipmentService.is_weapon_upgrade(profile, weapon) \
				and EquipmentService.weapon_block_reason(profile, weapon) == "":
			old_id = profile.weapon_id
			if not EquipmentService.equip_weapon(profile, weapon.id):
				old_id = &""
	else:
		var piece := item as ArmourData
		if EquipmentService.is_armour_upgrade(profile, piece) \
				and EquipmentService.armour_block_reason(profile, piece) == "":
			old_id = _worn_in_slot(profile, piece.slot)
			if not EquipmentService.equip_armour(profile, piece.id):
				old_id = &""

	SaveManager.save_profile(profile)  # autosave after purchases (charter §31)
	_refresh()
	if old_id != &"":
		_offer_old_item_sale(profile, is_weapon, old_id, item)


## Which piece is worn in `slot` right now ("" when the slot is empty).
func _worn_in_slot(profile: PlayerProfile, slot: Enums.EquipSlot) -> StringName:
	for worn_id in profile.armour_ids:
		var worn: ArmourData = ItemDB.armour_piece(worn_id)
		if worn != null and worn.slot == slot:
			return worn_id
	return &""


func _offer_old_item_sale(
		profile: PlayerProfile, is_weapon: bool, old_id: StringName, new_item: Resource) -> void:
	var old_item: Resource = ItemDB.weapon(old_id) if is_weapon else ItemDB.armour_piece(old_id)
	if old_item == null:
		return
	var price: int = EconomyCalculator.sell_price(
			GameManager.ECONOMY_CONFIG, old_item.get("value"), profile.attributes.charisma)
	_pending_sale = {"is_weapon": is_weapon, "id": old_id, "price": price}
	_auto_equip_dialog.dialog_text = tr("shop.auto_equipped_text").format({
		"new": tr(new_item.get("name_key")),
		"old": tr(old_item.get("name_key")),
		"price": price,
	})
	_auto_equip_dialog.ok_button_text = "%s (+%d)" % [tr("shop.tab_sell"), price]
	_auto_equip_dialog.popup_centered()


func _on_sale_confirmed() -> void:
	if _pending_sale.is_empty():
		return
	var profile: PlayerProfile = GameManager.profile
	if _pending_sale["is_weapon"]:
		profile.inventory_weapon_ids.erase(_pending_sale["id"])
	else:
		profile.inventory_armour_ids.erase(_pending_sale["id"])
	profile.gold += _pending_sale["price"]
	AudioManager.play(&"coin")
	_pending_sale = {}
	SaveManager.save_profile(profile)
	_refresh()


func _sell(profile: PlayerProfile, is_weapon: bool, id: StringName, value: int) -> void:
	var price: int = EconomyCalculator.sell_price(
			GameManager.ECONOMY_CONFIG, value, profile.attributes.charisma)
	if is_weapon:
		profile.inventory_weapon_ids.erase(id)
	else:
		profile.inventory_armour_ids.erase(id)
	profile.gold += price
	AudioManager.play(&"coin")
	SaveManager.save_profile(profile)
	_refresh()


func _weapon_stats(weapon: WeaponData) -> String:
	var text: String = "%s  ·  %s" % [
		tr("item.stat.damage").format({"min": weapon.damage_min, "max": weapon.damage_max}),
		tr("item.stat.tier").format({"tier": weapon.tier}),
	]
	# EFFECTIVE crit for THIS gladiator (weapon base + class-matched
	# attribute) — upgrade decisions should see the real number.
	text += "  ·  " + tr("item.stat.crit").format({"value": roundi(
			HitCalculator.crit_chance_for(GameManager.profile.attributes, weapon) * 100)})
	if weapon.is_ranged():
		text += "  ·  " + tr("item.stat.ammo").format({"ammo": weapon.ammo})
	return text


func _armour_stats(piece: ArmourData) -> String:
	var text: String = "%s  ·  %s" % [
		tr("item.stat.armour").format({"armour": piece.armour}),
		tr("item.stat.tier").format({"tier": piece.tier}),
	]
	if piece.mobility_bonus > 0:
		text += "  ·  " + tr("item.stat.mobility").format({"value": piece.mobility_bonus})
	return text


## Formats the blocking requirement (empty string when unblocked).
func _requirement_text(reason: String, weapon: WeaponData, piece: ArmourData) -> String:
	if reason == "":
		return ""
	var value: int = 0
	match reason:
		"equip.requires_level":
			value = weapon.required_level if weapon != null else piece.required_level
		"equip.requires_strength":
			value = weapon.required_strength if weapon != null else piece.required_strength
		"equip.requires_agility":
			value = weapon.required_agility
		"equip.requires_arcana":
			value = weapon.required_arcana
	return tr(reason).format({"value": value})
