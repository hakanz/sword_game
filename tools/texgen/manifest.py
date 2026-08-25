"""The complete texture manifest for Arena Legends.

One entry per generated image: where it lands, how it is keyed, how big it
ends up. generate.py walks this list; nothing else in the game reads it.

Art direction is deliberately concentrated in STYLE/NEGATIVE below so the whole
set reads as one hand. Every design here is described from scratch -- no asset
references, imitates, or names any existing game (charter section 0).
"""
from __future__ import annotations

ROOT = "assets/generated"

STYLE = (
    "stylized painterly 2D game art, hand-painted, bold readable shapes, "
    "crisp dark outline, warm gritty desert-arena fantasy palette of rust, "
    "bronze, sun-bleached bone and deep plum shadow, soft rim light from the "
    "upper left, cohesive with a cartoon-proportioned gladiator game"
)
NEGATIVE = (
    "no text, no letters, no numbers, no watermark, no signature, no border, "
    "no frame, no user interface, no photo realism, no 3d render"
)
MAGENTA = (
    "The ENTIRE background is one completely flat uniform pure magenta field, "
    "RGB 255 0 255, with nothing else on it at all: no shadow, no gradient, "
    "no vignette, no ground plane, no glow spilling onto the magenta"
)
BLACK = (
    "The ENTIRE background is pure solid black RGB 0 0 0 with nothing else on "
    "it. The effect itself glows brightly against that black"
)


def _asset(key, prompt, aspect="1:1", mode="cutout", size=(256, 256),
           fmt="png", square=True):
    return {"key": key, "prompt": prompt, "aspect": aspect, "mode": mode,
            "size": size, "fmt": fmt, "square": square}


# --- Weapons -----------------------------------------------------------------
# Orientation matters: the rig draws the sprite in the fist with the grip at the
# BOTTOM CENTRE of the image, so every weapon is painted standing straight up.
WEAPON_ORIENT = {
    "sword": "The blade points straight up, the hilt and pommel sit at the very bottom centre",
    "axe": "The haft runs straight up the middle, the axe head at the top, butt of the haft at the very bottom centre",
    "blunt": "The haft runs straight up the middle, the heavy head at the top, butt of the haft at the very bottom centre",
    "spear": "The shaft runs straight up the middle, the head at the top, butt of the shaft at the very bottom centre",
    "bow": "The bow stands upright, both limbs curving away to the left, the wrapped grip exactly at the centre of the image, the taut string a thin line down the right",
    "staff": "The shaft runs straight up the middle, the focus at the top, butt of the shaft at the very bottom centre",
}

WEAPONS = [
    # (file stem, class key, description)
    ("worn_shiv", "sword", "a pitiful improvised shiv: a snapped, rust-eaten blade barely a hand long, the grip just filthy rag wound round bare tang"),
    ("training_shortsword", "sword", "a blunt wooden training shortsword, pale scarred oak, leather-wrapped grip, chipped edges from a thousand practice bouts"),
    ("skinning_knife", "sword", "a small curved skinning knife, thin worn steel, bone handle stained dark with use"),
    ("bronze_gladius", "sword", "a short broad bronze gladius, warm hammered bronze blade with a leaf taper, ribbed bone grip, round bronze pommel"),
    ("falx_of_the_pits", "sword", "a brutal forward-curving falx, dark pitted iron with an inward hook near the tip, filthy cord grip"),
    ("iron_longsword", "sword", "a straight iron longsword, plain honest crossguard, central fuller, leather-wrapped grip, disc pommel"),
    ("steel_sabre", "sword", "an elegant curved steel sabre, bright polished blade, swept knuckle bow guard, dark ray-skin grip"),
    ("black_iron_greatsword", "sword", "an enormous black-iron greatsword, wide dark blade with a smoky matte finish, long two-handed grip, heavy angular crossguard"),
    ("sunscoured_falchion", "sword", "a heavy sun-bleached falchion, broad cleaver-like blade of pale gold-tinted steel, sun-disc pommel, sand-worn leather grip"),
    ("sablefang", "sword", "a legendary duelist blade: a slender needle-thin sabre of near-black steel with a faint violet edge glow, fang-shaped guard, dark silk grip"),
    ("pit_hatchet", "axe", "a stubby one-handed pit hatchet, chipped iron head lashed to a short knotted branch with rawhide"),
    ("bearded_axe", "axe", "a bearded axe, iron head with a long hooked lower beard, ash haft, iron langets"),
    ("crescent_battleaxe", "axe", "a battleaxe with a wide crescent-moon blade, blued steel, bronze rivets, dark stained haft"),
    ("wolfsplitter_axe", "axe", "a big double-bitted axe, two mirrored steel bits with a wolf-tooth notch pattern along each edge, iron-banded haft"),
    ("riftedge_axe", "axe", "a masterwork axe whose steel bit is split by a thin luminous cyan fracture running through the metal, cold pale-steel finish"),
    ("venomtooth_cleaver", "axe", "a legendary cleaver: a broad hooked blade of oily green-black metal, a hollow fang groove weeping luminous green venom, wrapped snakeskin grip"),
    ("rustpick_club", "blunt", "a crude club: a knobbed length of hardwood with bent rusty nails and a broken pick head driven through it"),
    ("dented_maul", "blunt", "a battered iron maul, square head badly dented and pockmarked, splintered haft bound in wire"),
    ("oaken_warhammer", "blunt", "a solid warhammer, banded oak head with an iron face and a short back spike, sturdy ringed haft"),
    ("horned_maul", "blunt", "a huge maul whose head is a block of dark iron with two curved bull horns bolted to the sides, heavy wrapped haft"),
    ("doorslab", "blunt", "a legendary absurd weapon: a literal iron-banded oak door slab used as a maul, hinges and a door ring still bolted on, worn to a shine where it is gripped"),
    ("mountainbreaker", "blunt", "a colossal warhammer with a wedge-shaped granite head bound in riveted steel straps, faint amber heat glowing in the cracks of the stone"),
    ("reed_spear", "spear", "a poor fighter improvised spear: a slim reed shaft with a small sharpened iron point lashed on with cord"),
    ("boar_spear", "spear", "a boar spear, stout ash shaft, broad leaf-shaped iron head with a crossbar below it to stop a charge"),
    ("gladiators_trident", "spear", "an arena trident, three long bronze tines on a polished dark shaft, ceremonial bronze collar"),
    ("serpent_pike", "spear", "a long pike with a wavy serpentine steel head, snake scale texture chased into the collar, dark green wrapped shaft"),
    ("sunforged_spear", "spear", "a gleaming spear with a golden sun-forged head radiating faint warm light, sunburst collar, pale ash shaft"),
    ("saltmere_pike", "spear", "a coastal war pike, pale salt-crusted steel head with barnacle-like pitting, weather-greyed driftwood shaft, tarred cord grip"),
    ("scrap_bow", "bow", "a crude scrap bow: a bent stick of green wood strung with twisted gut, uneven limbs, rag-wrapped grip"),
    ("hunting_bow", "bow", "a simple hunter shortbow of pale wood, leather grip wrap, plain waxed string"),
    ("composite_warbow", "bow", "a composite warbow of laminated horn and sinew, dark lacquered limbs with bone tip nocks, corded grip"),
    ("longstrider_bow", "bow", "a tall slender longbow of golden yew with fine grain, simple horn nocks, long leather grip"),
    ("longwatch_bow", "bow", "a masterwork recurve warbow, deep red-brown limbs with pale bone inlay along the belly, silver-blue string"),
    ("ashwood_staff", "staff", "a plain ashwood mage staff, knotted pale grey wood, a rough uncut quartz pebble bound at the top with cord"),
    ("emberglass_staff", "staff", "a fire mage staff of charred black wood topped with a floating shard of orange emberglass, sparks drifting from it"),
    ("stormcaller_rod", "staff", "a storm rod: a dark metal shaft ending in a forked copper prong with a small crackling blue-white lightning arc between the tines"),
    ("tidecaller_staff", "staff", "a sea-witch staff of pale driftwood spiralled with kelp and rope, topped by a swirling orb of deep turquoise water"),
    ("ashquill_rod", "staff", "a legendary arcane rod: a slim charcoal-black shaft fletched with three long ash-grey quills, violet runes burning faintly along its length"),
]

WEAPON_CLASS_OF = {stem: cls for stem, cls, _ in WEAPONS}


def weapon_assets():
    out = []
    for stem, cls, desc in WEAPONS:
        prompt = (
            f"A single game weapon sprite: {desc}. "
            f"{WEAPON_ORIENT[cls]}. Straight-on flat side view, no perspective, "
            f"no tilt, the weapon perfectly upright and vertical, filling about "
            f"90 percent of the height of the frame and centred left-to-right. "
            f"{STYLE}. {MAGENTA}. {NEGATIVE}."
        )
        out.append(_asset(f"items/weapons/{stem}", prompt, aspect="3:4",
                          size=(320, 426), square=False))
    return out


# --- Armour ------------------------------------------------------------------
ARMOUR = [
    ("rag_hood", "a filthy torn cloth hood, frayed hem, dull grey-brown sackcloth"),
    ("scrap_helm", "a crude helmet beaten out of scrap plates, mismatched rusty metal riveted together, one dented cheek flap"),
    ("bronze_cap", "a simple domed bronze skull cap with a rolled rim and a leather chin strap"),
    ("crested_bronze_helm", "a bronze arena helm with a tall stiff crimson horsehair crest running front to back, narrow eye slits"),
    ("iron_helm", "a rounded iron helm with a riveted nasal bar and hinged cheek guards, dark forge-scaled finish"),
    ("steel_greathelm", "a heavy flat-topped steel greathelm, narrow cross-shaped vision slit, cold polished plates"),
    ("wardens_greathelm", "a masterwork greathelm of pale salt-white steel with fluted ridges, a brow band of blue-green verdigris and a short crest fin"),
    ("leather_straps", "a bare harness of crossed brown leather straps and buckles, no plate at all"),
    ("padded_vest", "a quilted padded gambeson vest, cream-and-tan stitched channels, worn and stained"),
    ("boiled_leather_cuirass", "a boiled leather cuirass, hardened chestnut-brown shell with tooled edging and bronze buckles"),
    ("scaled_hauberk", "a scale hauberk, overlapping small bronze scales on a leather backing, mail edging"),
    ("iron_chainmail", "an iron chainmail shirt, dense grey riveted rings, short sleeves, leather collar"),
    ("steel_breastplate", "a steel breastplate, smooth muscled cuirass with a raised centre ridge and shoulder straps"),
    ("bulwark_plate", "a massive heavy plate cuirass, thick layered steel with a bolted reinforcing band across the chest, dark blued finish"),
    ("saltplate_cuirass", "a coastal plate cuirass of pale salt-etched steel, verdigris seams, a stylised wave chased across the chest"),
    ("bronze_pauldrons", "a pair of rounded bronze shoulder guards with fluted ridges and leather strapping"),
    ("iron_shoulderguards", "a pair of angular iron shoulder plates with riveted lames and a short spike on the outer edge"),
    ("studded_gloves", "a pair of short leather gloves with iron studs across the knuckles, worn palms"),
    ("gladiator_manica", "an arena arm guard: overlapping laminated bronze bands wrapping a forearm and shoulder, leather backing"),
    ("hide_belt", "a wide hide belt with a plain iron buckle and a hanging strap"),
    ("champion_girdle", "an ornate champion belt, thick dark leather with a large embossed bronze victory medallion and hanging bronze plates"),
    ("canvas_leggings", "a pair of plain canvas leggings, sand-coloured, cord-tied at the waist and knee"),
    ("wooden_greaves", "a pair of leg guards of lashed wooden slats over cloth wraps"),
    ("riveted_leggings", "a pair of leather leggings reinforced with riveted iron strips down the thighs"),
    ("pit_boots", "a pair of scuffed low leather boots, mud-caked soles, mismatched laces"),
    ("windrunner_boots", "a pair of light supple boots with a small feather charm at the ankle and a soft turned-down cuff"),
    ("duelist_boots", "a pair of tall fitted duelling boots in oxblood leather with a buckled ankle strap"),
    ("gale_greaves", "a pair of light armoured greaves in pale silver-blue steel with swept wing-like fins at the calf"),
    ("tidewalker_boots", "a pair of masterwork boots in blue-green scaled leather with coral-shaped steel clasps, damp sheen"),
]


def armour_assets():
    out = []
    for stem, desc in ARMOUR:
        prompt = (
            f"A single game equipment icon: {desc}. Shown alone as a piece of "
            f"gear, three-quarter view, no body wearing it, centred and filling "
            f"about 85 percent of the frame. {STYLE}. {MAGENTA}. {NEGATIVE}."
        )
        out.append(_asset(f"items/armour/{stem}", prompt))
    return out


# --- Skills ------------------------------------------------------------------
SKILLS = [
    ("crushing_blow", "a two-handed hammer smashing down, radiating impact cracks"),
    ("sunder_guard", "a cracked shattering shield with popped rivets flying off"),
    ("gutter_lunge", "a dagger thrusting forward with a sharp motion streak behind it"),
    ("venom_smear", "a curved blade being coated in dripping luminous green venom"),
    ("hamstring_cut", "a low curved slash arc with red droplets trailing from it"),
    ("skull_ringer", "a helmet struck by a club, small ringing bell arcs around it"),
    ("war_bellow", "a roaring open mouth with concentric orange shout rings blasting outward"),
    ("second_wind", "a deep green breath spiral rising around a heart-shaped ember"),
    ("pinning_shot", "an arrow driven through a boot, pinning it to the ground"),
    ("focused_loose", "a drawn bowstring with a single arrow and a narrow focus reticle of light"),
    ("ember_bolt", "a hurled fistful of orange embers forming a comet of fire"),
    ("enfeebling_hex", "a sickly purple hex sigil with drooping withered arms"),
    ("mocking_jab", "a jabbing finger with cheeky yellow insult sparks"),
    ("brace_up", "a planted boot and a squat stone bulwark with an upward shield glow"),
]


def skill_assets():
    return [
        _asset(f"icons/skills/{stem}",
               f"A single fantasy combat ability emblem: {desc}. One bold "
               f"centred symbol, chunky readable silhouette that stays clear at "
               f"small size, no circular badge frame around it. {STYLE}. "
               f"{MAGENTA}. {NEGATIVE}.",
               size=(160, 160))
        for stem, desc in SKILLS
    ]


# --- Status effects ----------------------------------------------------------
STATUSES = [
    ("poison", "a bubbling green skull-shaped droplet"),
    ("bleed", "three falling crimson blood droplets over a torn gash"),
    ("stun", "three yellow cartoon stars circling in a ring"),
    ("slow", "a cracked hourglass leaking blue sand, with a chained weight"),
    ("rage", "a snarling red fist wreathed in furious flame"),
    ("regeneration", "a bright green sprouting leaf over a soft heart glow"),
    ("burn", "a curling orange flame with a charred ember base"),
    ("weakness", "a drooping cracked grey arm with a downward violet arrow"),
    ("stoneguard", "a blocky stone bulwark with a stony shield sheen"),
]


def status_assets():
    return [
        _asset(f"icons/status/{stem}",
               f"A single status-effect emblem: {desc}. One bold centred symbol, "
               f"very high contrast, instantly readable at 32 pixels, no badge "
               f"frame. {STYLE}. {MAGENTA}. {NEGATIVE}.",
               size=(128, 128))
        for stem, desc in STATUSES
    ]


# --- Arena backdrops + ground ------------------------------------------------
# The fighters stand across the middle of the frame, so the backdrop must keep
# its detail ABOVE them: architecture and crowd in the upper band, and nothing
# but open ground below the wall line. The engine tiles the fighting sand over
# that lower half itself, which is what makes it read as boundless at any
# aspect ratio (scenes/arena/arena_visual.gd).
HORIZON = (
    "Composition is strict and must be followed exactly. Reading the image top "
    "to bottom: the top fifth is a narrow strip of sky only. From 20 percent "
    "down to 62 percent of the image height, tall tiered stands PACKED SOLID "
    "with a huge dense crowd of tiny spectators fill the ENTIRE width, curving "
    "away to both sides so the arena reads as enormous. From 62 to 72 percent "
    "is the plain perimeter wall, running level straight across with no gates, "
    "no doors and no torches on it. Below 72 percent is completely flat open "
    "empty ground stretching toward the viewer with absolutely nothing on it: "
    "no objects, no people, no creatures, no cast shadows. Deep atmospheric "
    "haze on the stands so they sit well BEHIND the empty ground"
)

ARENAS = [
    ("gravelmaw",
     "a poor sun-blasted gravel pit arena cut into a dry canyon: rough grey "
     "drystone perimeter wall, crooked wooden scaffolding stands packed with a "
     "rowdy peasant crowd, tattered brown pennants on poles, canyon cliffs and "
     "a hazy pale-gold noon sky beyond the rim",
     "fine dry grey-brown arena sand with a light dusting of tiny grit"),
    ("emberholt",
     "a volcanic ring arena at dusk: black basalt perimeter wall, steep basalt "
     "tiers packed with a roaring crowd lit orange from below, iron braziers "
     "burning along the top parapet, glowing lava seams in the far cliffs, "
     "drifting ash and a deep smoky red-purple sky",
     "fine dark volcanic ash, warm charcoal grey-brown, barely speckled"),
    ("saltmere",
     "a grand coastal amphitheatre at low tide: bleached white-and-turquoise "
     "stone perimeter wall, tall tiers crowded with spectators, salt-crusted "
     "pillars strung with fishing nets and blue banners along the top, a flat "
     "shining sea and a wide pale cyan sky beyond the far rim",
     "fine pale salt-dusted sand, warm bone-beige with the faintest cool tint"),
]


def arena_assets():
    out = []
    for stem, backdrop, ground in ARENAS:
        out.append(_asset(
            f"arenas/{stem}_backdrop",
            f"A wide 2D game battle backdrop painted as a stage seen straight "
            f"on, eye level, no perspective tilt: {backdrop}. {HORIZON}. "
            f"{STYLE}. {NEGATIVE}.",
            aspect="16:9", mode="opaque", size=(1600, 900), fmt="webp",
            square=False))
        out.append(_asset(
            f"arenas/{stem}_ground",
            f"A seamless tiling ground texture, top-down, evenly lit, no "
            f"shadows, no objects: {ground}. VERY low contrast and very fine "
            f"grained, almost uniform in value, so that it does not fight the "
            f"characters standing on it and shows no seams when repeated: no "
            f"large blotches, no dark patches, no bright patches, no cracks, "
            f"no ripples, no stripes and no directional pattern of any kind. "
            f"Perfectly even coverage across the whole square with no focal "
            f"point. {STYLE}. {NEGATIVE}.",
            aspect="1:1", mode="tile", size=(512, 512), fmt="webp",
            square=False))
    return out


# --- Armour material patches -------------------------------------------------
MATERIALS = [
    ("worn_leather", "worn dark brown leather, soft creases and scuffs, faint stitching"),
    ("studded_leather", "tan leather studded with regular rows of small iron domes"),
    ("cloth_linen", "coarse dyed linen cloth with visible weave and a few frayed threads"),
    ("bronze_plate", "hammered bronze plate, warm gold-brown, dimpled peen marks and green verdigris in the low spots"),
    ("iron_mail", "dense riveted iron chainmail rings, cool grey, slightly oily"),
    ("steel_plate", "smooth polished steel plate with faint brushed grain and shallow battle scratches"),
    ("scale_mail", "overlapping bronze armour scales in neat rows, each scale rounded and slightly raised"),
]


def material_assets():
    return [
        _asset(f"materials/{stem}",
               f"A seamless tiling material texture, flat straight-on view, even "
               f"neutral lighting, no shadows, no objects, no edges of the "
               f"material visible: {desc}. Uniform coverage over the whole "
               f"square. {STYLE}. {NEGATIVE}.",
               mode="tile", size=(256, 256), fmt="webp", square=False)
        for stem, desc in MATERIALS
    ]


# --- VFX (painted on black, luminance keyed) ---------------------------------
VFX = [
    ("slash_arc", "a single sweeping crescent sword slash trail, white-hot core fading to pale gold at the thin tips", (512, 256), "16:9"),
    ("spark", "one small hot orange spark mote with a soft bloom", (128, 128), "1:1"),
    ("blood_drop", "a single dark crimson blood droplet with a wet highlight", (128, 128), "1:1"),
    ("blood_splatter", "a splash of dark crimson blood flung sideways, scattered droplets and a ragged leading edge", (512, 512), "1:1", "cutout"),
    ("dust_puff", "a soft round puff of pale sandy dust, wispy edges", (256, 256), "1:1"),
    ("fire_wisp", "a single curling tongue of orange flame, bright yellow at the base", (256, 256), "1:1"),
    ("frost_shard", "a pale cyan ice crystal shard with a cold inner glow", (256, 256), "1:1"),
    ("poison_bubble", "a glossy toxic green bubble of venom with a highlight", (128, 128), "1:1"),
    ("lightning_bolt", "a jagged blue-white lightning arc branching once, electric glow", (256, 512), "9:16"),
    ("arcane_rune", "a glowing violet circular arcane sigil ring with angular inner marks", (512, 512), "1:1"),
    ("heal_mote", "a soft green healing mote shaped like a rising spark of light", (128, 128), "1:1"),
    ("shield_impact", "a bright concentric ring of pale blue-white force, brightest at the rim, like a blocked blow flaring on a guard", (512, 512), "1:1"),
    ("armour_shard", "a jagged broken shard of grey steel plate catching a hot spark of light along one edge", (128, 128), "1:1"),
    ("levelup_ray", "a vertical column of golden light rising and flaring, brightest at the base", (256, 512), "9:16"),
    ("legendary_glow", "a soft radial aura of warm amber-gold light, brightest at the centre, fading smoothly outward", (512, 512), "1:1"),
    ("stun_star", "one bright yellow cartoon five-pointed star with a soft glow", (128, 128), "1:1"),
    ("crit_burst", "an explosive orange-white starburst of radiating spikes, like a devastating impact flash", (512, 512), "1:1"),
    ("crowd_flare", "a warm wide horizontal bloom of amber light, like a roaring crowd catching the sun", (512, 256), "16:9"),
    ("smoke_puff", "a dark grey rolling puff of smoke lit faintly from within", (256, 256), "1:1"),
]


def vfx_assets():
    out = []
    for entry in VFX:
        stem, desc, size, aspect = entry[:4]
        mode = entry[4] if len(entry) > 4 else "glow"
        field = MAGENTA if mode == "cutout" else BLACK
        lit = "" if mode == "cutout" else ", glowing"
        out.append(_asset(
            f"vfx/{stem}",
            f"A single isolated game particle effect: {desc}. Just the effect, "
            f"nothing else, centred{lit}. {field}. {NEGATIVE}.",
            aspect=aspect, mode=mode, size=size, square=False))
    return out


# --- UI ----------------------------------------------------------------------
# Panels/buttons are 9-sliced by the theme, so the plate MUST fill the frame
# edge to edge -- any scenery around it would slice into the border.
PLATE = ("The plate fills the entire image completely, edge to edge and corner "
         "to corner, with absolutely no background, scenery or empty space "
         "visible around it, photographed flat straight-on")

UI = [
    ("panel_parchment",
     "a blank square of aged sand-coloured parchment stretched over a dark "
     "leather backing, with a plain thin bronze border rail running all the way "
     "round the outer edge, softly worn corners, the whole centre completely "
     "empty",
     "1:1", (256, 256), "opaque", "webp", True),
    ("panel_stone",
     "a blank square panel of dark plum-grey arena stone with a thin bronze "
     "rail all the way round the outer edge, faint chisel texture, the centre "
     "completely empty",
     "1:1", (256, 256), "opaque", "webp", True),
    ("button_normal",
     "a blank rectangular fantasy game button plate: dark warm bronze metal "
     "with a raised bevelled rim and small corner rivets, the flat centre "
     "completely empty",
     "16:9", (128, 64), "opaque", "webp", True),
    ("button_hover",
     "a blank rectangular fantasy game button plate: warm bronze metal lit "
     "brighter as if hovered, glowing amber bevelled rim and corner rivets, the "
     "flat centre completely empty",
     "16:9", (128, 64), "opaque", "webp", True),
    ("button_pressed",
     "a blank rectangular fantasy game button plate pressed inward: darkened "
     "recessed bronze metal, shadowed inner bevel and corner rivets, the flat "
     "centre completely empty",
     "16:9", (128, 64), "opaque", "webp", True),
    ("backdrop_menu",
     "a wide title-screen painting of a great gladiator arena at golden dusk "
     "seen from the sand: towering tiered stands full of tiny distant "
     "spectators, stone arches, hanging banners, a low burning sun behind the "
     "far rim, drifting dust and long shadows, deep warm colour, empty "
     "foreground with no characters",
     "16:9", (1600, 900), "opaque", "webp", False),
    ("backdrop_town",
     "a wide painting of a dusty frontier gladiator town street at midday: "
     "sun-bleached mudbrick buildings, striped merchant awnings, a blacksmith "
     "forge smoking on one side, an armourer stall on the other, hanging "
     "lanterns and rope, the great wall of the arena rising in the distance, "
     "empty street with no people",
     "16:9", (1600, 900), "opaque", "webp", False),
    ("backdrop_shop",
     "a wide painting of the interior of a gladiator equipment shop: heavy "
     "timber beams, weapon racks and armour stands lining the walls, a broad "
     "worn counter, a glowing forge in the back, warm lamplight and hanging "
     "tools, empty of people",
     "16:9", (1600, 900), "opaque", "webp", False),
    ("backdrop_creation",
     "a wide painting of a torchlit gladiator preparation chamber under the "
     "arena: rough stone vaults, an iron equipment rack, a scarred wooden "
     "bench, a barred gate at the far end letting in a shaft of hot daylight, "
     "empty of people",
     "16:9", (1600, 900), "opaque", "webp", False),
    ("backdrop_results",
     "a wide painting looking up from the arena sand at a vast roaring crowd in "
     "tiered stands at sunset, thrown flowers and coins in the air, banners "
     "waving, warm haze and floating dust, no individual foreground characters",
     "16:9", (1600, 900), "opaque", "webp", False),
    ("coin",
     "a single thick gold arena coin seen face on, worn milled edge, a blank "
     "embossed laurel ring stamped on its face, warm metallic shine",
     "1:1", (128, 128), "cutout", "png", False),
    ("logo_crest",
     "a heraldic arena crest emblem: two crossed gladiator swords behind a "
     "battered round bronze shield, a laurel branch curving under it, no text "
     "of any kind",
     "1:1", (512, 512), "cutout", "png", False),
]


def ui_assets():
    out = []
    for stem, desc, aspect, size, mode, fmt, plate in UI:
        bg = MAGENTA if mode == "cutout" else ""
        edge = PLATE if plate else ""
        out.append(_asset(f"ui/{stem}",
                          f"{desc}. {edge}. {STYLE}. {bg} {NEGATIVE}.",
                          aspect=aspect, mode=mode, size=size, fmt=fmt,
                          square=False))
    return out


# --- Portraits ---------------------------------------------------------------
PORTRAITS = [
    ("maulhilda", "a woman: an enormous, broad, middle-aged female gladiator "
                  "champion, clearly a woman, with a squashed nose, a long grey "
                  "braid over one shoulder, heavy jaw and a wall of scarred "
                  "muscle, wearing dented heavy plate, utterly unimpressed"),
    ("orzha", "a lean, elegant woman duelist with sharp cheekbones, long black braided "
              "hair, one thin scar across the brow, wearing fitted dark leather, "
              "smiling like this is all very amusing"),
    ("pyx", "a still, pale, hollow-eyed arena mage with a shaved head marked by "
            "faint violet sigils, wearing charcoal robes over light armour, "
            "expression completely blank"),
    ("grissa", "a wiry, grinning street-rat fighter with a shaved side-cut, gold "
               "tooth and a coin flipping between the fingers, patched leathers"),
    ("vurm", "a hulking scowling brute with a matted beard, a broken tusk of a "
             "tooth and a heavy brow, wearing crude scrap armour"),
    ("ilsa", "a tall, weather-beaten coastal spear-fighter with salt-bleached "
             "hair, freckled sunburn and a level stare, wearing scaled sea-green "
             "armour"),
]


def portrait_assets():
    return [
        _asset(f"portraits/{stem}",
               f"A head-and-shoulders character portrait of {desc}. Facing the "
               f"viewer at a slight angle, dramatic arena lighting. Original "
               f"character design. {STYLE}. {MAGENTA}. {NEGATIVE}.",
               aspect="1:1", size=(384, 384))
        for stem, desc in PORTRAITS
    ]


def all_assets():
    return (weapon_assets() + armour_assets() + skill_assets() + status_assets()
            + arena_assets() + material_assets() + vfx_assets() + ui_assets()
            + portrait_assets())


if __name__ == "__main__":
    items = all_assets()
    print(f"{len(items)} assets")
    for a in items:
        print(" ", a["key"], a["mode"], a["size"], a["fmt"])
