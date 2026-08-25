class_name ArtLibrary
## Lookup for the generated art that is NOT attached to a content resource
## (charter §27 asset pipeline): VFX particle sprites, UI plates, armour
## material patches.
##
## Per-item art belongs on the item — `WeaponData.sprite`, `ArmourData.icon`,
## `ArenaData.backdrop` and friends are real data slots, so gameplay keeps
## referencing logical IDs and never image paths. What is left over is engine
## furniture with no resource to hang off, and that lives here.
##
## Every lookup returns `null` when the file is absent, and EVERY caller must
## keep its primitive-drawn path alive for that case. That is the rule that
## lets the game boot with no art at all, and it is what makes the art a
## genuine drop-in replacement rather than a hard dependency.

const VFX_DIR := "res://assets/generated/vfx/"
const UI_DIR := "res://assets/generated/ui/"
const MATERIAL_DIR := "res://assets/generated/materials/"

## Resolved textures (and confirmed misses, stored as null) by path — the
## `ResourceLoader.exists` probe is not free, and rigs redraw constantly.
static var _cache: Dictionary = {}


## VFX particle sprite by stem, e.g. `spark`, `blood_drop`, `shield_impact`.
static func vfx(stem: StringName) -> Texture2D:
	return _load(VFX_DIR + String(stem) + ".png")


## UI plate/emblem by stem, e.g. `panel_stone`, `button_normal`, `coin`.
static func ui(stem: StringName) -> Texture2D:
	var png: Texture2D = _load(UI_DIR + String(stem) + ".png")
	return png if png != null else _load(UI_DIR + String(stem) + ".webp")


## Tiling armour/cloth material patch by stem, e.g. `steel_plate`.
static func material(stem: StringName) -> Texture2D:
	return _load(MATERIAL_DIR + String(stem) + ".webp")


## True when the generated art set is installed at all — used by the theme and
## the tests to decide whether the textured path is even reachable.
static func has_art() -> bool:
	return ui(&"panel_stone") != null


## Drops every cached handle. Only the tests need this (they assert both the
## textured and the placeholder path, and the cache would hide the switch).
static func clear_cache() -> void:
	_cache.clear()


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		texture = ResourceLoader.load(path, "Texture2D") as Texture2D
	_cache[path] = texture
	return texture
