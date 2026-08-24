extends TestCase
## Scene smoke: every menu-flow scene must instantiate and run _ready without
## errors (broken %unique-node paths and @onready nulls surface here).
## The arena scene is exercised end-to-end by the --smoke-test run instead.

const SCENES: PackedStringArray = [
	"res://scenes/menu/main_menu.tscn",
	"res://scenes/character/character_sheet.tscn",
	"res://scenes/shops/shop.tscn",
	"res://scenes/inventory/inventory.tscn",
	"res://scenes/skills/skills.tscn",
	"res://scenes/creation/character_creation.tscn",
	"res://scenes/results/results.tscn",
]


func test_menu_flow_scenes_instantiate_cleanly() -> void:
	var previous_profile: PlayerProfile = GameManager.profile
	GameManager.profile = PlayerProfile.create_default()
	GameManager.profile.inventory_weapon_ids.append(&"weapon.bronze_gladius")
	GameManager.profile.inventory_armour_ids.append(&"armour.rag_hood")

	var tree := Engine.get_main_loop() as SceneTree
	for path in SCENES:
		var packed: PackedScene = load(path)
		assert_true(packed != null, "cannot load %s" % path)
		if packed == null:
			continue
		var node: Node = packed.instantiate()
		tree.root.add_child(node)  # triggers @onready + _ready for real
		assert_true(node.is_inside_tree(), "%s failed to enter the tree" % path)
		tree.root.remove_child(node)
		node.free()

	GameManager.profile = previous_profile
