# Asset Manifest

Every real (non-placeholder) art/audio asset the game will need, tracked so gameplay never
blocks on art (charter §27). Producing final assets is a **human-driven task** (commission /
license / generation-with-review). Status values: `placeholder` (in-game stand-in exists),
`requested`, `final`.

## Visual

| asset_id | type | in-game placeholder today | needs (dimensions/pivot/notes) | status |
|---|---|---|---|---|
| rig.gladiator_placeholder | layered character rig | `PlaceholderRig` `_draw()` primitives | Full modular layer set per charter §12 (Body/Head/Hair/…/MainWeapon/Effects) on one shared skeleton; attachment points main_hand, off_hand, head, back, shield; anims: Idle, Walk, Run, Jump, AttackLight, AttackHeavy, AttackSpecial, Shoot, Cast, Block, Parry, Hit, CriticalHit, Stunned, Taunt, Victory, Death | placeholder |
| weapon.training_shortsword | weapon sprite + icon | rig-drawn rectangle sword | side-view sprite w/ grip pivot + 64px icon | placeholder |
| weapon.pit_hatchet | weapon sprite + icon | rig-drawn axe shape | same | placeholder |
| armour.padded_vest | torso overlay + icon | none (rig tint only) | torso layer variants per body type | placeholder |
| armour.scrap_helm | head overlay + icon | none (rig tint only) | head layer | placeholder |
| armour.leather_straps | torso overlay + icon | none (rig tint only) | torso layer | placeholder |
| arena.gravelmaw.backdrop | background set | `ArenaVisual` `_draw()` primitives (sky/wall/crowd/sand) | layered parallax-capable backdrop, 1920x1080 safe | placeholder |
| ui.theme | UI theme/skin | Godot default theme | full themed controls (buttons, bars, panels) | placeholder |
| app.icon | icon set | original `icon.svg` (sword-on-disc) | store icon sizes per platform | placeholder |

## Audio

| asset_id | type | in-game placeholder today | needs | status |
|---|---|---|---|---|
| music.menu / music.battle / music.victory / music.defeat | tracks | **silence** (buses wired, nothing plays) | loopable tracks per state (charter §26 list) | placeholder |
| sfx.hit / sfx.miss / sfx.block / sfx.death / sfx.crowd | one-shots | silence | cartoon-weight combat foley + crowd beds | placeholder |
| ui.click / ui.confirm | one-shots | silence | subtle UI set | placeholder |

Pipeline note: `AudioManager.play_sfx(stream, bus)` and the bus layout are live — dropping a
stream into `assets/` and referencing it from data is all that's needed when real audio lands.
