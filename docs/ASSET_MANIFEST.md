# Asset Manifest

Every real (non-placeholder) art/audio asset the game will need, tracked so gameplay never
blocks on art (charter §27). Status values: `placeholder` (in-game stand-in exists),
`requested`, `generated` (produced by `tools/texgen`, in the game, reviewable and
regenerable — see `docs/art.md`), `final` (human-reviewed and signed off).

**`generated` is not `final`.** The set below was produced by an image model and eyeballed
against the running game; none of it has had an art-director pass, and none of it should be
described as finished art. Every consumer still keeps its primitive-drawn fallback alive, so
any of these can be REPLACED without touching gameplay code — but the ones bound into a
`.tres` are normal resource dependencies, so unbind before removing rather than deleting
files (docs/art.md).

## Visual

| asset_id | type | in-game today | needs (dimensions/pivot/notes) | status |
|---|---|---|---|---|
| rig.gladiator_placeholder | layered character rig | `PlaceholderRig` v5: 3-tone anatomy, expressions, per-slot armour drawn with real material textures, painted weapon sprite in the fist | Full modular layer set per charter §12 (Body/Head/Hair/…/MainWeapon/Effects) on one shared skeleton; attachment points main_hand, off_hand, head, back, shield | placeholder |
| rig.animations | animation set | Idle, AttackLight/Heavy (weight from `CombatFeel`), Shoot, Cast, Block, Parry, Hit, CriticalHit, Stunned, Taunt, Walk/Run, Victory, Death — all as procedural tweens | hand-authored frames on a real rig; Jump has no gameplay to hang on in a turn-based cell duel | placeholder |
| items.weapons.* (38) | weapon sprite + icon | painted upright sprite per weapon, grip at the bottom edge; one texture serves the fist and the shop row | art-director pass; per-tier variants | generated |
| items.armour.* (29) | armour icon | painted three-quarter icon per piece | art-director pass | generated |
| materials.* (7) | tiling material patch | worn/studded leather, linen, bronze, mail, steel, scale — filled into the rig's armour shapes | more variety per tier | generated |
| arenas.\*.backdrop (3) | background | painted 16:9 backdrop per region (Gravelmaw / Emberholt / Saltmere) | layered parallax version | generated |
| arenas.\*.ground (3) | tiling ground | painted per-region ground, laid over the backdrop as low-alpha grain | — | generated |
| ui.backdrops (5) | screen art | menu / town / shop / creation / results paintings | art-director pass | generated |
| ui.plates | theme skin | painted bronze button plates (normal/hover/pressed) + stone and parchment panels, nine-sliced by `UITheme` | full art-directed theme incl. sliders, checkboxes, tabs | generated |
| ui.icons.skills (14) | icon set | painted per-skill emblems | — | generated |
| ui.icons.status (9) | icon set | painted per-status emblems | colorblind check (§28) | generated |
| ui.coin / ui.logo_crest | icons | painted arena coin, heraldic crest on the main menu | — | generated |
| ui.icons.actions/slots/classes | icon set | original SVGs in `assets/icons` (actions, stats, item classes/slots) — still the fallback path for unpainted items | final icon set, same ids | placeholder |
| vfx.* (19) | particle sprites | painted slash arc, sparks, blood drop/splatter, dust, smoke, fire, frost, poison, lightning, arcane rune, heal mote, shield impact, armour shard, level-up ray, legendary glow, stun star, crit burst, crowd flare | — | generated |
| portraits.* (6) | character portraits | painted head-and-shoulders for the 3 champions and 3 regional rivals | portraits for generated opponents (probably never — they are procedural) | generated |
| app.icon | icon set | original `icon.svg` (sword-on-disc) | store icon sizes per platform | placeholder |

## Audio

| asset_id | type | in-game placeholder today | needs | status |
|---|---|---|---|---|
| music.menu / music.battle / music.victory / music.defeat | tracks | **silence** (buses wired; victory/defeat play short synthesized stings) | loopable tracks per state (charter §26 list) | placeholder |
| sfx.hit / sfx.armour_hit / sfx.miss / sfx.skill / sfx.buff / sfx.death / sfx.step / sfx.coin | one-shots | **runtime-synthesized cues** (audio/sfx_library.gd — real placeholders, audible in game) | cartoon-weight combat foley + crowd beds | placeholder |
| ui.click | one-shot | runtime-synthesized tick on every button | subtle UI set | placeholder |

Audio is now the biggest remaining gap: `AudioManager.play_sfx(stream, bus)` and the bus
layout are live, so dropping a stream into `assets/` and referencing it from data is all
that is needed when real audio lands.

Pipeline note: regenerating or extending the visual set is documented in `docs/art.md`
(`tools/texgen/generate.py` + `tools/texgen/bind_resources.py`).
