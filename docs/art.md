# Art pipeline

How Arena Legends' textures are produced, where they live, and the one rule
every drawing path obeys. Companion to `docs/ASSET_MANIFEST.md`, which tracks
*what* each asset is; this file covers *how*.

## The rule that governs everything here

**No drawing code assumes a texture exists.** Each consumer keeps its
primitive-drawn path alive and takes the texture only when it is actually
there:

| Consumer | With art | Without art |
|---|---|---|
| `PlaceholderRig` weapon | painted sprite in the fist | per-class primitive weapon drawing |
| `PlaceholderRig` armour | material patch filling the shape | flat `_armour_tone` colour |
| `ArenaVisual` | painted backdrop + ground grain | drawn sky/stands/crowd/wall/sand |
| `TownVisual` | painted street | drawn dusk skyline |
| `MenuBackdrop` | painted screen art | drawn dusk-arena silhouette |
| `UITheme` | nine-sliced bronze plates | flat rounded `StyleBoxFlat` |
| `ItemIcons` | per-item painted icon | white class/slot glyph, tinted by tier |
| `CombatVfx` | painted particle sprites | flat coloured points and drawn arcs |
| `CombatHud` status chip | painted emblem | tinted colour swatch |

So a weapon authored with an empty `sprite`, an arena with no `backdrop`, or a
run with `ArtLibrary` finding nothing all render the way the game did before the
art existed. `test_art.gd` drives both halves of every one of those branches.

**Where that stops.** A texture BOUND from a `.tres` is an ordinary Godot
dependency: delete `assets/generated/items/weapons/pit_hatchet.png` and
`data/weapons/pit_hatchet.tres` fails to parse, exactly as it would if you
deleted a referenced status-effect resource. "Optional" means the drawing code
copes with an empty slot — not that files can be pulled out from under bound
resources. Verified by measurement, not assumption: removing the whole
generated tree breaks item loading, while removing the two ArtLibrary-only
directories (`vfx/`, `ui/`) leaves a duel that plays out identically on the same
seed. To go back to primitives, unbind the slots (or regenerate the files) —
never just delete.

## Where a texture is referenced from

Two places, and the split is deliberate.

**Per-item art hangs off the item.** These are real `@export` slots on the
content resources, so gameplay keeps referencing logical IDs and never image
paths (AI_GUIDE architecture rule 1):

| Slot | On | Used by |
|---|---|---|
| `sprite` | `WeaponData` | the rig's fist AND the shop/inventory icon |
| `icon` | `ArmourData` | shop/inventory rows |
| `material_texture` | `ArmourData` | the shapes the rig fills for that piece |
| `icon` | `SkillData` | HUD radial buttons, skill screen |
| `icon` | `StatusEffectData` | HUD status chips |
| `backdrop`, `ground_texture` | `ArenaData` | `ArenaVisual` |
| `portrait` | `CharacterData` | combat HUD, tournament bracket |

**Everything else goes through `ArtLibrary`** (`services/art_library.gd`) —
VFX particle sprites, UI plates, material patches. These are engine furniture
with no content resource to hang off. Lookups are cached and return `null` for
anything missing.

## Generating the set

`tools/texgen/` drives the Gemini image model. The three parts:

- `manifest.py` — the whole asset list: one entry per image with its prompt,
  aspect ratio, keying mode, output size and format. Art direction lives in the
  shared `STYLE` / `NEGATIVE` strings so the set reads as one hand.
- `imageops.py` — post-processing. The model returns opaque JPEG only, so
  transparency is recovered here.
- `generate.py` — the runner: resumable, parallel, retrying.

```bash
GEMINI_API_KEY=... python tools/texgen/generate.py            # everything missing
GEMINI_API_KEY=... python tools/texgen/generate.py vfx/ ui/   # only these prefixes
GEMINI_API_KEY=... python tools/texgen/generate.py --force vfx/slash_arc
python tools/texgen/generate.py --repost                      # re-derive, no API calls
python tools/texgen/bind_resources.py                         # point .tres at the files
```

The API key is passed through the environment and is **never** written into the
repository.

### Keying modes

Because the model cannot emit alpha, every cut-out asset is painted against a
flat field that post-processing removes:

- **`cutout`** — art on flat magenta (`255,0,255`). Distance-keyed with a
  feathered band, then despilled so no pink fringe survives on the silhouette.
- **`glow`** — additive VFX painted on black. Luminance becomes alpha and the
  RGB is re-normalised, so a dim wisp keeps its hue when drawn additively.
  *Anything that does not actually glow must use `cutout` instead* — asking for
  dark blood "glowing on black" makes the model paint a white field, and the
  luminance key then has nothing to remove.
- **`opaque`** — backdrops and plates; no keying.
- **`tile`** — opaque plus a mirrored cross-fade at the edges so the texture
  wraps seamlessly.

Weapons are the fussy case: the rig hangs the sprite off the grip at the
**bottom edge** and scales it by height, so every weapon is painted standing
straight up (bows are gripped at their centre instead). `test_art.gd` asserts
that every weapon sprite is taller than it is wide, which is the cheap proxy
for "still painted upright".

### Re-running is cheap

Raw model output is cached under `.texgen_raw/` (gitignored). An asset whose
output file already exists is skipped, so an interrupted run costs nothing to
restart, and `--repost` re-derives every texture from the cache when the
post-processing is tuned — no API calls, no cost.

## Nine-slice sizes are minimum sizes

`UITheme`'s plate borders (`BUTTON_SLICE`, `PANEL_SLICE`) also set each
control's **minimum** size — Godot will not slice a box smaller than its own
borders. The button plate therefore ships at 128x64 rather than 256x128: at the
larger size the nine-slice floor turned every stepper button into a slab and
pushed the character-creation attribute list off the bottom of its panel.
Changing plate resolution means re-checking the small-button screens.

## Verifying it

```bash
godot --headless --path . -s res://tests/test_runner.gd
godot --path . --resolution 1280x720 -- --screenshot-dir=<dir>
```

The second one is the dev capture harness (`GameManager.run_screenshot_capture`):
it plays through menu, creation, town, shop, inventory, tournament and two
duels — including one kitted fight against a named champion, which is the only
frame that shows armour materials, weapon sprites and an opponent portrait all
at once — then quits. It needs a windowed run; headless cannot composite a
frame. Captures occasionally come back blank when the machine is loaded; re-run
rather than chasing it.

## Size budget

The generated set is ~11 MB on disk: backdrops and tiles as lossy WebP, cut-out
art as PNG (alpha). Web export size is the constraint to watch — see the
performance rules in `AI_GUIDE.md` before adding another backdrop-sized asset.
