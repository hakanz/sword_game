"""Points the content .tres files at the generated textures.

The texture slots are real data fields (WeaponData.sprite, ArmourData.icon and
material_texture, StatusEffectData.icon, ArenaData.backdrop/ground_texture,
CharacterData.portrait), so binding them is a data edit, not a code change.
Doing it with a script rather than by hand keeps the 80-odd resources exactly
consistent -- and re-running is safe: a slot that already points somewhere is
left alone unless --force is passed.

    python tools/texgen/bind_resources.py [--force]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GEN = "res://assets/generated"

# Which material patch each armour piece paints its shapes with. Authored by
# hand because it is an ART decision per piece, not something derivable from
# the stats -- a scaled hauberk and a chainmail shirt share an armour class.
ARMOUR_MATERIAL = {
    "rag_hood": "cloth_linen",
    "scrap_helm": "steel_plate",
    "bronze_cap": "bronze_plate",
    "crested_bronze_helm": "bronze_plate",
    "iron_helm": "steel_plate",
    "steel_greathelm": "steel_plate",
    "wardens_greathelm": "steel_plate",
    "leather_straps": "worn_leather",
    "padded_vest": "cloth_linen",
    "boiled_leather_cuirass": "worn_leather",
    "scaled_hauberk": "scale_mail",
    "iron_chainmail": "iron_mail",
    "steel_breastplate": "steel_plate",
    "bulwark_plate": "steel_plate",
    "saltplate_cuirass": "steel_plate",
    "bronze_pauldrons": "bronze_plate",
    "iron_shoulderguards": "steel_plate",
    "studded_gloves": "studded_leather",
    "gladiator_manica": "bronze_plate",
    "hide_belt": "worn_leather",
    "champion_girdle": "worn_leather",
    "canvas_leggings": "cloth_linen",
    "wooden_greaves": "worn_leather",
    "riveted_leggings": "studded_leather",
    "pit_boots": "worn_leather",
    "windrunner_boots": "worn_leather",
    "duelist_boots": "worn_leather",
    "gale_greaves": "steel_plate",
    "tidewalker_boots": "scale_mail",
}

PORTRAIT = {
    "champions/maulhilda": "maulhilda",
    "champions/orzha": "orzha",
    "champions/pyx": "pyx",
    "rivals/grissa": "grissa",
    "rivals/vurm": "vurm",
    "rivals/ilsa": "ilsa",
}


def _next_id(text: str) -> str:
    used = set(re.findall(r'\[ext_resource [^\]]*id="([^"]+)"', text))
    n = 1
    while f"tex{n}" in used:
        n += 1
    return f"tex{n}"


def _prune_unused(text: str) -> str:
    """Drops ext_resource lines nothing references any more -- rebinding an
    icon that used to point at a placeholder SVG orphans its declaration."""
    kept = []
    for line in text.splitlines():
        match = re.match(r'\[ext_resource [^\]]*id="([^"]+)"\]', line)
        if match and f'ExtResource("{match.group(1)}")' not in text:
            continue
        kept.append(line)
    # Collapse the blank runs the removals leave behind.
    return re.sub(r"\n{3,}", "\n\n", "\n".join(kept)) + "\n"


def _refresh_load_steps(text: str) -> str:
    steps = len(re.findall(r"^\[ext_resource ", text, re.M)) \
        + len(re.findall(r"^\[sub_resource ", text, re.M)) + 1
    return re.sub(r"load_steps=\d+", f"load_steps={steps}", text, count=1)


def bind(path: Path, field: str, texture: str, force: bool) -> bool:
    """Points `field` of the resource at `texture` (a res:// path)."""
    text = path.read_text(encoding="utf-8")
    existing = re.search(rf"^{field} = (.+)$", text, re.M)
    if existing and not force:
        return False
    if not (REPO / texture.removeprefix("res://")).exists():
        raise SystemExit(f"missing texture {texture} for {path}")

    ref = re.search(rf'\[ext_resource type="Texture2D" path="{re.escape(texture)}"'
                    r' id="([^"]+)"\]', text)
    if ref:
        ident = ref.group(1)
    else:
        ident = _next_id(text)
        line = (f'[ext_resource type="Texture2D" path="{texture}" '
                f'id="{ident}"]\n')
        # Slot the declaration in with the other ext_resources rather than
        # leaving a stray block above [resource].
        declared = list(re.finditer(r"^\[ext_resource .*$", text, re.M))
        anchor = declared[-1].end() + 1 if declared else text.index("[resource]")
        text = text[:anchor] + line + text[anchor:]

    assignment = f'{field} = ExtResource("{ident}")'
    if existing:
        text = re.sub(rf"^{field} = .+$", assignment, text, count=1, flags=re.M)
    else:
        text = text.rstrip("\n") + "\n" + assignment + "\n"
    path.write_text(_refresh_load_steps(_prune_unused(text)), encoding="utf-8")
    return True


def main(argv: list[str]) -> int:
    force = "--force" in argv
    changed = 0

    for tres in sorted((REPO / "data/weapons").glob("*.tres")):
        changed += bind(tres, "sprite",
                        f"{GEN}/items/weapons/{tres.stem}.png", force)

    for tres in sorted((REPO / "data/armour").glob("*.tres")):
        changed += bind(tres, "icon",
                        f"{GEN}/items/armour/{tres.stem}.png", force)
        material = ARMOUR_MATERIAL.get(tres.stem)
        if material is None:
            raise SystemExit(f"no material mapped for armour piece {tres.stem}")
        changed += bind(tres, "material_texture",
                        f"{GEN}/materials/{material}.webp", force)

    for tres in sorted((REPO / "data/skills").glob("*.tres")):
        changed += bind(tres, "icon",
                        f"{GEN}/icons/skills/{tres.stem}.png", True)

    for tres in sorted((REPO / "data/status_effects").glob("*.tres")):
        changed += bind(tres, "icon",
                        f"{GEN}/icons/status/{tres.stem}.png", force)

    for tres in sorted((REPO / "data/arenas").glob("*.tres")):
        changed += bind(tres, "backdrop",
                        f"{GEN}/arenas/{tres.stem}_backdrop.webp", force)
        changed += bind(tres, "ground_texture",
                        f"{GEN}/arenas/{tres.stem}_ground.webp", force)

    for rel, portrait in PORTRAIT.items():
        changed += bind(REPO / f"data/characters/{rel}.tres", "portrait",
                        f"{GEN}/portraits/{portrait}.png", force)

    print(f"bound {changed} texture slots")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
