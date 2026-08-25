extends Control
## Inventory (INVENTORY state): equipped gear + satchel, with equip swapping
## via EquipmentService (which owns all requirement gating). Selling happens
## in the shop, not here — one money path (charter §22 anti-exploit).

@onready var _title: Label = %TitleLabel
@onready var _gold: Label = %GoldLabel
@onready var _weapons_title: Label = %WeaponsTitle
@onready var _weapons_list: VBoxContainer = %WeaponsList
@onready var _armour_title: Label = %ArmourTitle
@onready var _armour_list: VBoxContainer = %ArmourList
@onready var _back: Button = %BackButton


func _ready() -> void:
	if GameManager.profile == null:
		SceneRouter.goto_main_menu()
		return
	MenuBackdrop.install(self, &"backdrop_shop")
	_title.text = tr("inventory.title")
	_weapons_title.text = tr("inventory.weapons")
	_armour_title.text = tr("inventory.armour")
	_back.text = tr("common.back")
	_back.pressed.connect(SceneRouter.goto_town)
	_refresh()


func _refresh() -> void:
	var profile: PlayerProfile = GameManager.profile
	_gold.text = tr("shop.gold").format({"gold": profile.gold})

	for child in _weapons_list.get_children():
		child.queue_free()
	for child in _armour_list.get_children():
		child.queue_free()

	# Equipped weapon first, then satchel.
	var equipped_weapon: WeaponData = ItemDB.weapon(profile.weapon_id)
	_add_row(_weapons_list, equipped_weapon, true, "", true, Callable())
	for id in profile.inventory_weapon_ids:
		var weapon: WeaponData = ItemDB.weapon(id)
		if weapon == null or weapon.id != id:
			continue
		var reason: String = EquipmentService.weapon_block_reason(profile, weapon)
		_add_row(_weapons_list, weapon, true,
				_requirement_text(reason, weapon, null), false,
				func() -> void: _equip_weapon(profile, id))

	for id in profile.armour_ids:
		var piece: ArmourData = ItemDB.armour_piece(id)
		if piece != null:
			_add_row(_armour_list, piece, false, "", true, Callable())
	for id in profile.inventory_armour_ids:
		var piece: ArmourData = ItemDB.armour_piece(id)
		if piece == null:
			continue
		var reason: String = EquipmentService.armour_block_reason(profile, piece)
		_add_row(_armour_list, piece, false,
				_requirement_text(reason, null, piece), false,
				func() -> void: _equip_armour(profile, id))

	if profile.inventory_weapon_ids.is_empty() and profile.inventory_armour_ids.is_empty():
		var empty := Label.new()
		empty.text = tr("inventory.empty")
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.7, 0.65, 0.75))
		_armour_list.add_child(empty)


func _equip_weapon(profile: PlayerProfile, id: StringName) -> void:
	if EquipmentService.equip_weapon(profile, id):
		SaveManager.save_profile(profile)
	_refresh()


func _equip_armour(profile: PlayerProfile, id: StringName) -> void:
	if EquipmentService.equip_armour(profile, id):
		SaveManager.save_profile(profile)
	_refresh()


## One satchel/equipped row. Unequipped rows carry the same modifier and
## "what changes if I swap" lines the shop shows (V2 §52.4) — the decision is
## identical, so the information should be too.
func _add_row(
		list: VBoxContainer, item: Resource, is_weapon: bool, requirement: String,
		equipped: bool, on_equip: Callable) -> void:
	var panel := PanelContainer.new()
	list.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# Same painted item icon the shop rows use — the satchel and the stall are
	# the same decision and should read the same way.
	row.add_child(ItemIcons.make_item_icon(item))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var rarity: Enums.Rarity = item.get("rarity")
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info.add_child(name_row)
	var name_label := Label.new()
	name_label.text = tr(item.get("name_key"))
	name_label.add_theme_font_size_override("font_size", 19)
	name_row.add_child(name_label)
	if rarity > Enums.Rarity.COMMON:
		var rarity_label := Label.new()
		rarity_label.text = tr(ItemCompare.rarity_key(rarity))
		rarity_label.add_theme_font_size_override("font_size", 14)
		rarity_label.add_theme_color_override("font_color", ItemCompare.rarity_color(rarity))
		rarity_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(rarity_label)
	var stats_label := Label.new()
	stats_label.text = _weapon_stats(item) if is_weapon else _armour_stats(item)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
	info.add_child(stats_label)
	_add_detail(info, ItemCompare.affix_summary(item, is_weapon), ItemCompare.AFFIX_COLOR)
	_add_detail(info, ItemCompare.signature_text(item), ItemCompare.SIGNATURE_COLOR)
	if not equipped:
		var deltas: Dictionary = ItemCompare.deltas(GameManager.profile, item, is_weapon)
		_add_detail(info, ItemCompare.gains_text(deltas), ItemCompare.GAIN_COLOR)
		_add_detail(info, ItemCompare.losses_text(deltas), ItemCompare.LOSS_COLOR)
	if requirement != "":
		var req_label := Label.new()
		req_label.text = requirement
		req_label.add_theme_font_size_override("font_size", 14)
		req_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
		info.add_child(req_label)

	if equipped:
		var tag := Label.new()
		tag.text = tr("inventory.equipped")
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", Color(0.6, 0.85, 0.55))
		row.add_child(tag)
	else:
		var button := Button.new()
		button.text = tr("inventory.equip")
		button.custom_minimum_size = Vector2(120, 48)
		button.disabled = requirement != ""
		button.pressed.connect(on_equip)
		row.add_child(button)


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


## Adds one small detail line, skipping empty text.
func _add_detail(info: VBoxContainer, text: String, color: Color) -> void:
	if text == "":
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(label)
