extends TestCase
## Coverage for the generated art layer (charter §27).
##
## Two halves, and they matter for different reasons:
##  * CONTENT invariants — every weapon carries a sprite, every armour piece an
##    icon and a material, every arena a backdrop. A newly authored item with
##    no art should fail CI, not playtesting.
##  * FALLBACK invariants — the primitive path is still reachable, because the
##    whole design of ArtLibrary/ItemIcons/UITheme rests on "null means draw it
##    the old way". A regression there would only show up as a crash on a
##    machine where the art was not installed.

const VFX_KEYS: PackedStringArray = [
	"slash_arc", "spark", "blood_drop", "blood_splatter", "dust_puff",
	"fire_wisp", "frost_shard", "poison_bubble", "lightning_bolt",
	"arcane_rune", "heal_mote", "shield_impact", "armour_shard",
	"levelup_ray", "legendary_glow", "stun_star", "crit_burst", "crowd_flare",
	"smoke_puff",
]
const UI_KEYS: PackedStringArray = [
	"panel_parchment", "panel_stone", "button_normal", "button_hover",
	"button_pressed", "backdrop_menu", "backdrop_town", "backdrop_shop",
	"backdrop_creation", "backdrop_results", "coin", "logo_crest",
]
const MATERIAL_KEYS: PackedStringArray = [
	"worn_leather", "studded_leather", "cloth_linen", "bronze_plate",
	"iron_mail", "steel_plate", "scale_mail",
]
const PORTRAIT_CHARACTERS: PackedStringArray = [
	"res://data/characters/champions/maulhilda.tres",
	"res://data/characters/champions/orzha.tres",
	"res://data/characters/champions/pyx.tres",
	"res://data/characters/rivals/grissa.tres",
	"res://data/characters/rivals/vurm.tres",
	"res://data/characters/rivals/ilsa.tres",
]


# --- Content invariants -----------------------------------------------------

func test_every_weapon_has_a_sprite() -> void:
	for weapon in ItemDB.all_weapons():
		assert_true(weapon.sprite != null, "no sprite on %s" % weapon.id)


## The rig hangs the sprite off the grip at the BOTTOM edge and scales it by
## height, which only works while the art is painted standing upright.
func test_weapon_sprites_are_upright() -> void:
	for weapon in ItemDB.all_weapons():
		if weapon.sprite == null:
			continue
		var size: Vector2 = weapon.sprite.get_size()
		assert_true(size.y > size.x,
				"%s is %dx%d — sprites must be taller than wide"
						% [weapon.id, size.x, size.y])


func test_every_armour_piece_has_icon_and_material() -> void:
	for piece in ItemDB.all_armour():
		assert_true(piece.icon != null, "no icon on %s" % piece.id)
		assert_true(piece.material_texture != null, "no material on %s" % piece.id)


func test_every_skill_has_an_icon() -> void:
	for skill in ItemDB.all_skills():
		assert_true(skill.icon != null, "no icon on %s" % skill.id)


func test_every_arena_is_dressed() -> void:
	for arena in ItemDB.all_arenas():
		assert_true(arena.backdrop != null, "no backdrop on %s" % arena.id)
		assert_true(arena.ground_texture != null, "no ground on %s" % arena.id)
		assert_true(arena.backdrop_horizon > 0.3 and arena.backdrop_horizon < 0.95,
				"%s horizon %.2f is not a plausible wall line"
						% [arena.id, arena.backdrop_horizon])


## The whole point of the arena reframe: a fighter must never be read against
## the wall or the crowd. That holds only while the backdrop hands over to open
## ground ABOVE the tallest helmet, and it is a relationship between four
## numbers in three different files — exactly the kind that rots silently.
func test_the_backdrop_clears_the_fighters() -> void:
	var fighter_height: float = PlaceholderRig.HEIGHT * Combatant.RIG_SCALE
	var head_y: float = CombatController.GROUND_Y - fighter_height
	assert_true(ArenaVisual.GROUND_TOP <= head_y,
			"open ground starts at %.0f but heads reach %.0f — fighters would "
					% [ArenaVisual.GROUND_TOP, head_y]
					+ "be read against the wall again")
	# ...and not so far above that the arena becomes a strip of crowd over a
	# desert. The stands need room to say how big the place is.
	assert_true(ArenaVisual.GROUND_TOP > head_y - 160.0,
			"open ground starts %.0f above the heads — the stands are being "
					% (head_y - ArenaVisual.GROUND_TOP) + "squeezed out")


## The camera may not frame the fight so high that the radial action ring
## hangs off the bottom of the screen.
func test_the_camera_keeps_the_action_ring_on_screen() -> void:
	var tightest: float = CombatCamera.ZOOM_BY_SEPARATION[1]
	var half_view: float = CombatCamera.DESIGN.y / (2.0 * tightest)
	var bottom: float = CombatCamera.focus_y(1.0) + half_view
	# The ring's lowest label sits roughly 80px under the fighters' feet.
	assert_true(bottom >= CombatController.GROUND_Y + 80.0,
			"the frame bottom (%.0f) cuts into the action ring" % bottom)


func test_every_status_effect_has_an_icon() -> void:
	var dir := DirAccess.open("res://data/status_effects")
	assert_true(dir != null, "status effect directory is missing")
	var seen: int = 0
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var status: StatusEffectData = load("res://data/status_effects/" + file)
		assert_true(status.icon != null, "no icon on %s" % status.id)
		seen += 1
	assert_true(seen >= 9, "expected the full status roster, saw %d" % seen)


func test_named_fighters_have_portraits() -> void:
	for path in PORTRAIT_CHARACTERS:
		var character: CharacterData = load(path)
		assert_true(character != null, "missing character %s" % path)
		assert_true(character.portrait != null, "no portrait on %s" % path)


func test_art_library_resolves_every_key_the_game_asks_for() -> void:
	for key in VFX_KEYS:
		assert_true(ArtLibrary.vfx(StringName(key)) != null, "missing vfx %s" % key)
	for key in UI_KEYS:
		assert_true(ArtLibrary.ui(StringName(key)) != null, "missing ui %s" % key)
	for key in MATERIAL_KEYS:
		assert_true(ArtLibrary.material(StringName(key)) != null,
				"missing material %s" % key)


# --- Fallback invariants ----------------------------------------------------

## The whole "art is a drop-in replacement" design rests on a missing texture
## being a quiet null rather than an error.
func test_missing_art_resolves_to_null() -> void:
	assert_eq(ArtLibrary.vfx(&"no_such_effect"), null, "unknown vfx key")
	assert_eq(ArtLibrary.ui(&"no_such_plate"), null, "unknown ui key")
	assert_eq(ArtLibrary.material(&"no_such_material"), null, "unknown material")


## An item with no art still produces an icon — the per-class glyph, tinted by
## tier. Driven through the real widget, not asserted against a constant.
func test_item_without_art_falls_back_to_the_glyph() -> void:
	var bare := CombatFixtures.make_weapon()
	bare.tier = 3
	assert_false(ItemIcons.is_painted(bare), "a bare weapon must not read as painted")
	assert_eq(ItemIcons.weapon_icon(bare),
			ItemIcons.WEAPON_ICONS[Enums.WeaponClass.SWORD],
			"bare weapon should fall back to the class glyph")
	var icon: Control = ItemIcons.make_item_icon(bare)
	assert_true(icon != null, "no icon control built for a bare weapon")
	icon.free()


## ...and an item WITH art is shown untinted, because the metal is painted in.
func test_item_with_art_is_used_directly() -> void:
	var painted: WeaponData = ItemDB.weapon(&"weapon.iron_longsword")
	assert_true(ItemIcons.is_painted(painted), "catalogue weapon should be painted")
	assert_eq(ItemIcons.weapon_icon(painted), painted.sprite,
			"a painted weapon must show its own sprite")
	var icon: Control = ItemIcons.make_item_icon(painted)
	assert_true(icon != null, "no icon control built for a painted weapon")
	icon.free()


## The theme must build with the art installed AND without it; both paths feed
## the same Button/PanelContainer slots.
func test_theme_builds_on_both_paths() -> void:
	var theme: Theme = UITheme.build()
	assert_true(theme.get_stylebox("normal", "Button") is StyleBoxTexture,
			"the painted plate should be in use while the art is installed")
	assert_true(theme.get_stylebox("panel", "PanelContainer") != null,
			"panels always need a stylebox")
	# The flat path is what ships when the art is absent — it must still exist.
	assert_true(UITheme.bar_fill(Color.RED) is StyleBoxFlat, "bar fill")
	assert_true(UITheme.round_button_box("hover") is StyleBoxFlat, "radial button")


## `has_art` is what the docs point at for "is the generated set installed".
func test_has_art_reports_the_installed_set() -> void:
	assert_true(ArtLibrary.has_art(), "the generated art set should be installed")
