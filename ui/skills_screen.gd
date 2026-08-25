extends Control
## Skill learning screen (SKILLS state): the full skill catalog with learn
## gating via SkillService. No hard classes — anything level-appropriate is
## learnable (charter §17).

@onready var _title: Label = %TitleLabel
@onready var _points: Label = %PointsLabel
@onready var _list: VBoxContainer = %SkillList
@onready var _back: Button = %BackButton


func _ready() -> void:
	if GameManager.profile == null:
		SceneRouter.goto_main_menu()
		return
	MenuBackdrop.install(self, &"backdrop_creation")
	_title.text = tr("skills.title")
	_back.text = tr("common.back")
	_back.pressed.connect(SceneRouter.goto_town)
	_refresh()


func _refresh() -> void:
	var profile: PlayerProfile = GameManager.profile
	# Build guidance (session-6 owner design): name the dominant trait and
	# tag the skills that suit it.
	_points.text = "%s   ·   %s" % [
		tr("sheet.skill_points").format({"points": profile.skill_points}),
		tr("skills.build_hint").format({
			"attr": tr("attr.%s" % SkillService.dominant_attribute(profile)),
		}),
	]
	for child in _list.get_children():
		child.queue_free()
	for skill in ItemDB.all_skills():
		_add_row(profile, skill)


func _add_row(profile: PlayerProfile, skill: SkillData) -> void:
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
	name_label.text = tr(skill.name_key)
	name_label.add_theme_font_size_override("font_size", 19)
	info.add_child(name_label)

	if SkillService.is_recommended(profile, skill) \
			and not profile.known_skill_ids.has(skill.id):
		var recommended := Label.new()
		recommended.text = tr("skills.recommended").format({
			"attr": tr("attr.%s" % SkillService.SKILL_AFFINITY[skill.id]),
		})
		recommended.add_theme_font_size_override("font_size", 14)
		recommended.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		info.add_child(recommended)

	var desc_label := Label.new()
	desc_label.text = tr(skill.description_key)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)

	var cost_label := Label.new()
	var cost_text: String = tr("skills.point_cost").format({"points": skill.point_cost})
	cost_text += "  ·  " + tr("skills.cost_energy").format({"energy": skill.energy_cost})
	if skill.cooldown_rounds > 0:
		cost_text += "  ·  " + tr("skills.cooldown").format({"rounds": skill.cooldown_rounds})
	if not skill.allowed_weapon_classes.is_empty():
		# Make weapon gating unmissable — a learned skill that never lights
		# up in combat reads as a bug otherwise (owner feedback, session 3).
		var class_names: PackedStringArray = []
		for weapon_class in skill.allowed_weapon_classes:
			class_names.append(tr("class.%s" %
					(Enums.WeaponClass.keys()[weapon_class] as String).to_lower()))
		cost_text += "  ·  " + tr("skills.requires_class").format({
			"classes": ", ".join(class_names),
		})
	cost_label.text = cost_text
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	info.add_child(cost_label)

	var reason: String = SkillService.learn_block_reason(profile, skill)
	if reason == "skills.hint.known":
		var tag := Label.new()
		tag.text = tr("skills.learned")
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", Color(0.6, 0.85, 0.55))
		row.add_child(tag)
	else:
		if reason == "equip.requires_level":
			var req := Label.new()
			req.text = tr("equip.requires_level").format({"value": skill.required_level})
			req.add_theme_font_size_override("font_size", 14)
			req.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
			row.add_child(req)
		var button := Button.new()
		button.text = "%s (%s)" % [tr("skills.learn"),
				tr("skills.point_cost").format({"points": skill.point_cost})]
		button.custom_minimum_size = Vector2(150, 48)
		button.disabled = reason != ""
		button.pressed.connect(_on_learn.bind(skill))
		row.add_child(button)


func _on_learn(skill: SkillData) -> void:
	if SkillService.learn(GameManager.profile, skill):
		SaveManager.save_profile(GameManager.profile)
	_refresh()
