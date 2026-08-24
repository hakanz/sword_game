extends Control
## The Armoury (SHOP state): buy from the full catalog, sell unequipped
## inventory. Prices come ONLY from EconomyCalculator (charter §22).
## Buying an item you cannot equip yet is allowed on purpose — "two points
## away from the next upgrade" anticipation (charter §16).

enum Mode { BUY, SELL }

var _mode: Mode = Mode.BUY

@onready var _title: Label = %TitleLabel
@onready var _gold: Label = %GoldLabel
@onready var _tab_buy: Button = %BuyTabButton
@onready var _tab_sell: Button = %SellTabButton
@onready var _list: VBoxContainer = %ItemList
@onready var _back: Button = %BackButton


func _ready() -> void:
	if GameManager.profile == null:
		SceneRouter.goto_main_menu()
		return
	_title.text = tr("shop.title")
	_tab_buy.text = tr("shop.tab_buy")
	_tab_sell.text = tr("shop.tab_sell")
	_back.text = tr("common.back")
	_tab_buy.pressed.connect(func() -> void: _set_mode(Mode.BUY))
	_tab_sell.pressed.connect(func() -> void: _set_mode(Mode.SELL))
	_back.pressed.connect(SceneRouter.goto_main_menu)
	_set_mode(Mode.BUY)


func _set_mode(mode: Mode) -> void:
	_mode = mode
	_tab_buy.disabled = mode == Mode.BUY
	_tab_sell.disabled = mode == Mode.SELL
	_refresh()


func _refresh() -> void:
	var profile: PlayerProfile = GameManager.profile
	_gold.text = tr("shop.gold").format({"gold": profile.gold})
	for child in _list.get_children():
		child.queue_free()
	if _mode == Mode.BUY:
		for weapon in ItemDB.all_weapons():
			_add_buy_row(profile, weapon.name_key, _weapon_stats(weapon),
					_requirement_text(EquipmentService.weapon_block_reason(profile, weapon), weapon, null),
					weapon.value, EquipmentService.owns_weapon(profile, weapon.id),
					func() -> void: _buy(profile, true, weapon))
		for piece in ItemDB.all_armour():
			_add_buy_row(profile, piece.name_key, _armour_stats(piece),
					_requirement_text(EquipmentService.armour_block_reason(profile, piece), null, piece),
					piece.value, EquipmentService.owns_armour(profile, piece.id),
					func() -> void: _buy(profile, false, piece))
	else:
		var any: bool = false
		for id in profile.inventory_weapon_ids:
			var weapon: WeaponData = ItemDB.weapon(id)
			if weapon != null and weapon.id == id:
				any = true
				_add_sell_row(profile, weapon.name_key, _weapon_stats(weapon), weapon.value,
						func() -> void: _sell(profile, true, id, weapon.value))
		for id in profile.inventory_armour_ids:
			var piece: ArmourData = ItemDB.armour_piece(id)
			if piece != null:
				any = true
				_add_sell_row(profile, piece.name_key, _armour_stats(piece), piece.value,
						func() -> void: _sell(profile, false, id, piece.value))
		if not any:
			var empty := Label.new()
			empty.text = tr("inventory.empty")
			empty.add_theme_font_size_override("font_size", 18)
			_list.add_child(empty)


func _buy(profile: PlayerProfile, is_weapon: bool, item: Resource) -> void:
	var price: int = EconomyCalculator.buy_price(
			GameManager.ECONOMY_CONFIG, item.get("value"), profile.attributes.charisma)
	if profile.gold < price:
		return
	profile.gold -= price
	if is_weapon:
		profile.inventory_weapon_ids.append(item.get("id"))
	else:
		profile.inventory_armour_ids.append(item.get("id"))
	SaveManager.save_profile(profile)  # autosave after purchases (charter §31)
	_refresh()


func _sell(profile: PlayerProfile, is_weapon: bool, id: StringName, value: int) -> void:
	var price: int = EconomyCalculator.sell_price(
			GameManager.ECONOMY_CONFIG, value, profile.attributes.charisma)
	if is_weapon:
		profile.inventory_weapon_ids.erase(id)
	else:
		profile.inventory_armour_ids.erase(id)
	profile.gold += price
	SaveManager.save_profile(profile)
	_refresh()


func _add_buy_row(
		profile: PlayerProfile, name_key: String, stats: String, requirement: String,
		value: int, owned: bool, on_buy: Callable) -> void:
	var price: int = EconomyCalculator.buy_price(
			GameManager.ECONOMY_CONFIG, value, profile.attributes.charisma)
	var row: HBoxContainer = _make_row(name_key, stats, requirement)
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
		var button := Button.new()
		button.text = tr("shop.buy")
		button.custom_minimum_size = Vector2(110, 48)
		button.disabled = profile.gold < price
		button.pressed.connect(on_buy)
		row.add_child(button)


func _add_sell_row(
		_profile: PlayerProfile, name_key: String, stats: String, value: int,
		on_sell: Callable) -> void:
	var price: int = EconomyCalculator.sell_price(
			GameManager.ECONOMY_CONFIG, value, GameManager.profile.attributes.charisma)
	var row: HBoxContainer = _make_row(name_key, stats, "")
	var button := Button.new()
	button.text = tr("shop.sell").format({"price": price})
	button.custom_minimum_size = Vector2(130, 48)
	button.pressed.connect(on_sell)
	row.add_child(button)


func _make_row(name_key: String, stats: String, requirement: String) -> HBoxContainer:
	var panel := PanelContainer.new()
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

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = tr(name_key)
	name_label.add_theme_font_size_override("font_size", 19)
	info.add_child(name_label)
	var stats_label := Label.new()
	stats_label.text = stats
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


func _weapon_stats(weapon: WeaponData) -> String:
	return "%s  ·  %s" % [
		tr("item.stat.damage").format({"min": weapon.damage_min, "max": weapon.damage_max}),
		tr("item.stat.tier").format({"tier": weapon.tier}),
	]


func _armour_stats(piece: ArmourData) -> String:
	return "%s  ·  %s" % [
		tr("item.stat.armour").format({"armour": piece.armour}),
		tr("item.stat.tier").format({"tier": piece.tier}),
	]


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
