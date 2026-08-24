# ARENA LEGENDS — AUTONOMOUS BUILD MASTER PROMPT

> **How to use this file:** This entire document is the task specification. Paste it as the
> opening instruction to the autonomous coding agent (Claude Fable 5 or equivalent) in a fresh
> session rooted at an empty (or near-empty) git repository. The agent should treat this file as
> its permanent charter — copy the relevant durable rules into `AI_GUIDE.md` on the very first
> session (Section 12) and never lose them, even after this original prompt scrolls out of
> context. Everything below is normative unless explicitly marked "example" or "placeholder."

---

## 0. RESEARCH BASIS AND ORIGINALITY BOUNDARY

This project is inspired by the *genre* of classic 2D browser/mobile gladiator RPGs
(e.g. Swords & Sandals 2). Confirmed genre facts used only to calibrate scope — **never to copy**:

- Turn-based, mouse/touch-driven single-player arena combat with ~20-40 active skills.
- A binary Wizard/Warrior class framing in the original — **Arena Legends must deliberately
  avoid this** and use attributes + skills + equipment to create builds instead (see Section 20).
- ~6 arena tiers, ~18-24 named boss "champions," 100-200 items, dozens of achievements.
- Comedic, cartoon-violent tone with gore that stays cartoonish, not realistic.

**Hard originality rules (non-negotiable):**
1. Do not reuse any proper noun from the reference games — no champion names, arena names, item
   names, or class names that match or are near-homophones of known Swords & Sandals content
   (explicitly forbidden examples to never reproduce: names resembling "Pharaoh King," "John the
   Butcher," "Ultra Flavius," "Son of Stylonius," "Emperor Antares," or arena names like "Battle
   Pits" / "Emperor's Palace" verbatim).
2. Do not reuse exact stat tables, exact damage formulas, exact skill names+effects pairs, or any
   copyrighted art/audio/text from any existing game.
3. Before finalizing the working title ("Arena Legends" is a placeholder), the agent must flag in
   `PROJECT_STATE.md` that a human should run a basic trademark/App-Store-name-collision check
   before public release. The agent itself cannot perform legal trademark searches — it must not
   claim this step is done.
4. When naming new content (champions, arenas, weapons), generate original names and verify by
   eye that none of them collide with rule 1. Log this check informally in the commit message or
   `DEVELOPMENT_LOG.md` when adding a batch of named content.

---

## 1. ROLE AND RESPONSIBILITY

You are acting as the combined Lead Game Architect, Senior Godot Engineer, Gameplay Systems
Designer, RPG Systems Designer, Combat Designer, Economy Designer, Technical Artist, UI/UX
Designer, Game AI Engineer, Localization Engineer, Audio/VFX Integrator, QA Engineer, and
Build/Release Engineer for a complete, commercial-quality, original 2D gladiator RPG.

You are building a full shippable product, not a prototype. Scope includes architecture, combat,
progression, character creation, attributes, skills, items, equipment, shops, economy,
tournaments, bosses, NPCs, animation hookups, VFX hookups, audio integration, localization, save
system, UI, mobile controls, web compatibility, desktop compatibility, balancing tools, automated
tests, build pipelines, and content data structures.

---

## 2. CORE GAME CONCEPT

A humorous but mechanically deep 2D turn-based gladiator RPG. Working title **Arena Legends**
(placeholder, replaceable).

Player fantasy: an unknown fighter with almost no equipment gradually becomes the most feared
arena champion in the world.

```
Character Creation
  -> Training / Equipment Preparation
  -> Normal Arena Duels
  -> Gold + XP + Loot
  -> Character Upgrades
  -> New Weapons / Armour / Skills
  -> Tournament Qualification
  -> Tournament Battles
  -> Arena Champion Boss
  -> New Region / Arena Tier
  -> Stronger Enemies and Equipment
  -> Final Championship
  -> Endgame / New Game+ / Challenge Modes
```

Design objective: **easy to understand, difficult to master.** Basic combat must be understandable
within ~2 minutes. Build optimization must stay interesting for dozens of hours.

---

## 3. TARGET PLATFORMS

One project, three targets:

- **Mobile** — Android, iOS. Touch controls, phones and tablets, portrait-safe menus,
  landscape-first combat.
- **Desktop** — Windows, Linux, macOS. Mouse + keyboard, optional controller.
- **Web** — HTML5/WebAssembly/WebGL2. Fast boot, controlled asset size, responsive resolution,
  mouse + touch, playable with zero server dependency.

**Minimum device/browser matrix (must be validated, not assumed):**
- Android: API 26+ (Android 8), reference low-end device class = 2 GB RAM / Adreno 505-class GPU.
- iOS: last 3 major iOS versions at time of each release.
- Desktop: Windows 10+, a common Linux distro (Ubuntu LTS), macOS 12+.
- Web browsers: current Chrome, Firefox, Safari, and their mobile equivalents. Do not use any
  browser API that is Chrome-only.

---

## 4. ENGINE AND TECHNICAL STACK

- Engine: **Godot 4.x — pin an exact stable version number** (e.g. `4.4.x` at project start) in
  `AI_GUIDE.md` and `project.godot`. Do not silently jump minor engine versions mid-project; a
  version bump is an explicit, documented decision (Section 41's decision-log format applies).
- Language: **GDScript only** for the main project. Do not use C# — it breaks/limits Web export.
- Renderer: **Compatibility renderer** by default (mobile/low-end/Web reach). Forward+ only if a
  specific effect truly requires it, and only behind a quality-tier toggle.
  - **Shader budget rule:** every shader-based VFX (fire, frost, lightning chain, armor glow) must
    be authored and tested to run acceptably on the Compatibility renderer on both Web export and
    a low-end Android target before being marked done. If a shader only works well on Forward+,
    provide a cheaper fallback for the other renderer/profile rather than dropping the effect
    silently.

---

## 5. MONETIZATION AND BUSINESS MODEL *(new — was previously undefined)*

Decide and document this before building the economy, because it constrains the enchantment,
gambling-event, and shop systems:

- **Default model: premium/paid or free-with-no-IAP for MVP and vertical slice.** Do not implement
  any real-money purchase, ad SDK, or gacha mechanic during MVP/vertical-slice phases.
- If monetization is added later (post-full-release decision, requires explicit human sign-off):
  - No loot boxes purchasable with real money. Any "gambling event" (Section 25) must only ever
    wager in-game gold, never real currency — several jurisdictions (Belgium, Netherlands, and
    others) regulate real-money loot mechanics, and mobile storefronts increasingly require odds
    disclosure for any chance-based reward.
  - No pay-to-win: cosmetics, convenience (extra save slots, etc.), and optional cosmetic
    enchant re-rolls are the only acceptable IAP categories if this is ever revisited.
  - Any ad or analytics SDK integration must go behind the `PlatformService` abstraction
    (Section 32) — core gameplay code must never call an ad/analytics SDK directly.
- **Telemetry/analytics: off by default, opt-in only, out of scope for MVP entirely.** Do not add
  any telemetry call "just in case" — it complicates Web/store privacy compliance for no MVP
  benefit.

---

## 6. PROJECT ARCHITECTURE

Modular architecture, data-driven content:

```
res://
    autoload/
        game_manager.gd
        save_manager.gd
        audio_manager.gd
        localization_manager.gd
        scene_router.gd
        event_bus.gd
        rng_service.gd

    combat/
        combat_controller.gd
        combatant.gd
        combat_ai.gd
        damage_calculator.gd
        hit_calculator.gd
        status_effect_system.gd
        turn_manager.gd
        combat_action.gd

    characters/
        player/
        enemies/
        champions/
        components/

    data/
        characters/
        skills/
        weapons/
        armour/
        consumables/
        enemies/
        champions/
        arenas/
        tournaments/
        progression/
        events/

    services/
        platform_service.gd
        economy_calculator.gd
        progression_calculator.gd

    scenes/
        boot/
        menu/
        creation/
        town/
        shops/
        arena/
        tournament/
        results/

    ui/
    vfx/
    audio/
    localization/
    assets/
    tests/
    tools/            # balancing/simulation/debug tooling, not shipped in release export
```

Rules:
- Weapons, skills, armour, enemies, champions, arenas, tournaments, status effects, and random
  events are **data (Resources), not code.** Adding content should not require editing combat
  logic. Never write `if weapon_name == "Iron Sword": damage = 30`.
- Separate **data** (`WeaponData`, `SkillData`, ...) from **runtime state**
  (`EquippedWeapon` with durability/enhancement level, etc.).
- Combat math lives only in `DamageCalculator`, `HitCalculator`, `ResistanceCalculator`,
  `ProgressionCalculator`, `EconomyCalculator`. UI, AI, and tooltips call these — they never
  reimplement the formulas.
- No monolithic managers. `GameManager` coordinates; it does not implement every system inline.
  Split into `CombatService`, `InventoryService`, `ProgressionService`, `SaveManager`,
  `AudioManager`, `SceneRouter`, etc.
- Use signals over direct coupling; typed GDScript everywhere; centralized RNG
  (`rng_service.gd`, seedable — see Section 34).

---

## 7. REPOSITORY BOOTSTRAP AND GIT HYGIENE *(new)*

On the very first session, before any gameplay code:

1. `git init` if not already a repo (check `git status` first — do not overwrite an existing repo).
2. Create the project via the Godot editor or `godot --headless --path . --editor` project
   creation flow; commit the generated `project.godot`.
3. Add a Godot-appropriate `.gitignore`:
   - `.godot/` (import cache — never commit)
   - `*.translation` compiled artifacts if auto-generated from `.csv`/`.po` sources
   - export output directories (`/builds/`, `/export/`)
   - any `export_presets.cfg` **credentials** (keystore paths, signing identities) — the
     `export_presets.cfg` file itself may be committed, but never commit actual `.keystore`,
     `.p12`, `.pem`, or provisioning profile files, and never commit passwords found inside it.
4. Adopt small, logically separated commits (one system/feature per commit). Do not bundle
   "rewrite combat + redesign UI + add 15 weapons" into one commit.
5. Use a simple commit message convention, e.g. `combat: add damage calculator with armour
   overflow`, `docs: update PROJECT_STATE after XP system`.

---

## 8. AI CONTINUITY DOCUMENTATION SYSTEM (MANDATORY)

This project will be touched by multiple AI agents and humans over a long period. The repository
itself is the project's long-term memory. Three permanent files, each with a distinct job —
never mix their responsibilities:

### 8.1 `/AI_GUIDE.md` — the permanent constitution
Create immediately. Every agent reads this before touching code. Contains only **durable**
architecture rules, not progress notes. Update only when something permanent changes (new
architecture rule, new supported platform, new coding convention, new persistence strategy, new
asset pipeline decision, new mandatory testing requirement, an engine-version bump). Do **not**
update it because "weapon #31 was added" or "bug #7 was fixed."

Minimum sections: Project Overview, Game Vision, Technology Stack (with pinned Godot version),
Supported Platforms, Project Structure, Architecture Rules, Coding Standards, Godot Rules,
Data-Driven Design Rules, Combat Architecture, Character Architecture, Item Architecture, Skill
Architecture, Enemy AI Architecture, Save System Architecture, Localization Rules, UI Rules,
Asset Pipeline (Section 30), Monetization Boundary (Section 5), Testing Rules, Performance
Rules, Platform Compatibility Rules, Forbidden Practices, Documentation Rules, Current
Development Workflow, How to Start a New Task, How to Finish a Task.

### 8.2 `/PROJECT_STATE.md` — the current snapshot
Create immediately. Represents the CURRENT state only — describes the present, not history.
Every agent reads it before starting and updates it before finishing meaningful work. Remove
outdated info rather than accumulating it.

```markdown
# PROJECT STATE
Last Updated:
Updated By:

## Current Milestone
## Current Game Version          (semver, e.g. 0.1.0 — see Section 38)
## Working Systems
## Partially Implemented Systems
## Known Bugs
## Technical Debt
## Current Test Status
## Platform Status
### Windows / Linux / macOS / Web / Android / iOS
## Current Content
### Arenas / Enemies / Champions / Weapons / Armour / Skills / Status Effects
## Open Asset Requests            (see Section 30 — art/audio not yet supplied)
## Important Recent Decisions
## Files Recently Changed
## Current Blocking Issues
## Recommended Next Task
## Next 5 Tasks
1. 2. 3. 4. 5.
```

### 8.3 `/DEVELOPMENT_LOG.md` — chronological history
Create immediately. Never delete old entries. One entry per meaningful session, with Added /
Changed / Fixed / Tests / Known Problems / Next Recommended Task. Avoid vague notes like "worked
on combat" — write what another engineer can actually act on.

### 8.4 Startup and completion protocol
**Before any task:** read `AI_GUIDE.md` -> read `PROJECT_STATE.md` -> read the latest
`DEVELOPMENT_LOG.md` entries -> inspect relevant source and tests -> only then modify code. Do
not redesign a working system just because another approach would also work; preserve
established architecture unless there's a concrete technical reason to change it (what problem
does it cause, can it be fixed incrementally, what depends on it, what tests protect it, does it
break save compatibility).

**After any task:** run relevant tests -> launch the affected scene -> confirm no runtime errors
-> fix new warnings when practical -> update `PROJECT_STATE.md` -> append
`DEVELOPMENT_LOG.md` -> update `AI_GUIDE.md` only if something permanent changed -> state the
recommended next task. Documentation must reflect reality — if `PROJECT_STATE.md` claims "Web
export works" or "save migration implemented," that must have actually been verified this
session, not assumed from a prior note.

---

## 9. AUTONOMOUS SESSION PROTOCOL *(new)*

Because this is meant to run with minimal human supervision across many sessions:

- **Scope each autonomous run to one coherent chunk** from the phase plan (Section 39) — e.g.
  "implement TurnManager + basic attack/defend/rest," not "build the whole combat system."
  Never attempt "build the entire game" as a single unit of work.
- **Checkpoint via commits, not memory.** Every autonomous run must leave the repo in a
  compiling, runnable state at each commit — never commit code that doesn't parse/run, even
  mid-task. If a run must stop early, stop at the last good commit and record exact next steps in
  `PROJECT_STATE.md`.
- **Budget the run.** If a run has produced 3+ commits worth of work or has been going for a long
  time without reaching a natural stopping point, stop, verify, document, and end the session
  rather than continuing indefinitely.
- **Never fabricate completion.** If a build/export/test could not actually be executed this
  session (e.g. no Android SDK available in this environment), say so explicitly in
  `PROJECT_STATE.md` under "Current Blocking Issues" instead of marking the platform as working.

---

## 10. ENGINEERING RULES (CONSOLIDATED)

1. Never generate giant monolithic scripts; one system, one owner (Section 6).
2. Keep tasks small: "Implement StatusEffect runtime model" -> "Implement Poison using
   StatusEffect" -> "Add Poison Arrow skill," not "implement all skills and status effects."
3. Explain non-obvious architecture decisions in `/docs/architecture.md` or
   `/docs/decisions/<slug>.md` (Decision / Reason / Alternatives considered / Consequences).
4. Keep game data separate from logic; avoid circular dependencies; use typed GDScript; use
   signals to reduce coupling; centralize RNG and combat math (Sections 6, 34).
5. Implement one complete system before moving to the next.
6. Run the project after meaningful implementation steps; fix warnings/errors before continuing.
7. Write tests for mathematical systems (damage, hit chance, XP curve, prices).
8. Do not silently replace existing working architecture (Section 8.4).
9. Avoid premature complexity: no ECS frameworks, no microservices, no event sourcing, no DI
   frameworks, no backend/networking beyond the optional adapters in Section 32. This is a 2D
   indie game — use Godot's strengths directly.
10. Scenes handle presentation/composition/interaction; they are not the source of truth for
    permanent game data.
11. Test the real game, not just unit tests: launch combat after combat changes, open inventory
    after inventory changes, save/close/reload after save changes, check multiple resolutions
    after responsive UI changes.

---

## 11. GAME STATES

Top-level state machine:
```
BOOT -> MAIN_MENU -> PROFILE_SELECT -> CHARACTER_CREATION -> TOWN -> SHOP -> INVENTORY ->
CHARACTER -> SKILLS -> ARENA_SELECT -> PRE_BATTLE -> COMBAT -> POST_BATTLE -> TOURNAMENT ->
CHAMPION_BATTLE -> GAME_OVER -> ENDING
```
Combat sub-state machine:
```
COMBAT_START -> ROUND_START -> PLAYER_TURN -> ACTION_SELECTION -> ACTION_EXECUTION -> AI_TURN ->
STATUS_RESOLUTION -> DEATH_CHECK -> ROUND_END -> COMBAT_END
```
`combat_controller.gd` must orchestrate this without becoming a single giant script — delegate to
`turn_manager.gd`, `damage_calculator.gd`, `status_effect_system.gd`, `combat_ai.gd`.

---

## 12. CHARACTER CREATION AND MODULAR VISUAL PIPELINE

Customization categories: name, body type, height, build, skin tone, face, eyes, eyebrows, hair,
beard, scars, tattoos, voice, victory pose.

Use modular 2D layered parts so equipment visually replaces body layers and progression is
**visible in the arena**, not just in inventory icons:
```
CharacterRoot
  Body, Head, Hair, Beard, FaceDetails,
  TorsoArmour, ShoulderArmour, Arms, Gloves, Belt, LegArmour, Boots,
  MainWeapon, OffhandWeapon, Shield, Cape, Effects
```
Maintain attachment points (`main_hand`, `off_hand`, `head`, `back`, `shield`) so a relatively
small asset library produces thousands of visual combinations via parts + recolors +
accessories + one shared skeleton. NPC/enemy generation reuses the same system. Every visual
asset gets a stable logical ID (`weapon.great_axe_01`, `helmet.iron_03`) — gameplay references
IDs, never raw image paths.

---

## 13. PRIMARY ATTRIBUTES (8 core stats)

| Stat | Affects |
|---|---|
| Strength | Heavy melee damage, axe/mace damage, heavy weapon requirements, knockback |
| Agility | Movement distance, dodge, ranged scaling, sword proficiency, initiative |
| Attack | Melee hit chance, accuracy, critical reliability |
| Defence | Block chance, parry, incoming hit probability |
| Vitality | Max HP, HP regen, bleed resistance |
| Stamina | Max Energy, physical skill costs, energy regen |
| Intelligence/Arcana | Mana, magical damage/skills, elemental resistance penetration |
| Charisma | Shop discounts, audience approval, taunt effectiveness, intimidation, fame gain, sponsor rewards, dialogue events — must be a genuinely viable combat-support stat, not roleplay flavor |

**Attribute gates equipment/skills — level-up decisions must matter.** Example (values
configurable, not fixed): 30 STR -> Heavy Axe access; 45 STR -> Great Hammer access; 30 AGI ->
Longbow access; 25 Arcana -> intermediate spells; 50 Arcana -> high-level magic.

### 13.1 Derived statistics (centralized, never recomputed ad hoc in UI/AI)
`MaxHP, MaxEnergy, MaxMana, MeleeDamage, RangedDamage, SpellPower, Accuracy, Evasion,
BlockChance, CritChance, CritDamage, Armour, PhysicalResistance, FireResistance,
FrostResistance, PoisonResistance, LightningResistance, MovementRange, Initiative,
CrowdInfluence` — all formulas live in `ProgressionCalculator`/`DamageCalculator`.

---

## 14. LEVEL AND XP SYSTEM

Levels 1-60 (first release target). Each level: +3 attribute points; every 2nd level: +1 skill
point. Milestones (values are guidance, tune during balancing):
```
1 beginner | 5 first tournament | 10 second region | 15 specialization begins |
20 elite equipment | 30 advanced skills | 40 champion tier | 50 legendary tier |
60 final championship
```
Later levels must introduce **new mechanics**, not just bigger numbers: new enemy strategies,
elemental resistances, stronger status effects, advanced equipment, build specialization.

XP curve: `xp_required(level) = base_xp * pow(level, 1.55)` as a *starting* configurable formula
in a resource, never hardcoded in logic. Tune via the simulation tools in Section 37.

---

## 15. COMBAT MODEL

Turn-based, side-view 2D arena, one fighter acts per turn.

**Actions:** move, normal attack, power attack, quick attack, defend, jump backward/forward,
taunt, ranged attack, skill, spell, consumable, rest.

**Distance bands:** Adjacent, Close, Medium, Long. Melee requires Close/Adjacent; ranged
weapons and spells can act from distance; characters can approach/retreat.

**Action economy:** every action consumes the turn; physical abilities may cost Energy, magic
costs Mana (e.g. normal attack 0 Energy, heavy attack 15, power skill 25, spell 20 Mana); Rest
restores Energy. Different builds should be pulled toward using resources differently.

**Hit calculation** (bounded, transparent, never permanently 0% or 100% for normal attacks —
suggested band 5%-95%; specific guaranteed-hit skills may explicitly bypass this):
```
accuracy_score  = attacker.attack_rating + skill_accuracy + weapon_accuracy + modifiers
avoidance_score = defender.defence_rating + defender.evasion + stance_bonus
```

**Damage pipeline (strict order, never silently discard excess damage):**
```
Raw Damage -> Weapon Scaling -> Attribute Scaling -> Skill Multiplier -> Critical Modifier ->
Damage Type Modifiers -> Resistance -> Armour -> Shield -> HP
```
If armour hits zero mid-hit, remaining damage carries into HP.

**Damage types:** Slash, Pierce, Blunt, Fire, Frost, Poison, Lightning, Arcane. Weapon classes
have distinct identities (Sword: balanced/slash; Axe: high damage/armour damage; Mace:
blunt/stun/armour penetration; Spear: reach/pierce; Bow: long range; Crossbow: high armour
penetration; Staff: magic scaling).

**Critical hits:** stronger impact animation, screen shake (capped/reducible — see Section 26),
distinct sound, larger damage numbers, crowd reaction. Crit chance must not scale unbounded.

---

## 16. EQUIPMENT SYSTEM

**Slots:** helmet, chest, shoulders, gloves, belt, legs, boots, main hand, offhand, shield,
amulet, ring. Armour contributes to defence, armour pool, resistances, bonuses. Armour classes:
Light (high agility/low armour), Medium (balanced), Heavy (high armour/movement penalty).

**Rarity:** Common, Uncommon, Rare, Epic, Legendary, Mythic — affects modifier count/strength,
visual quality, value. A lower-rarity item can still be the correct build choice; rarity must
never fully replace item design.

**Tiers:** T1 Scrap -> T2 Bronze -> T3 Iron -> T4 Steel -> T5 Knight -> T6 Imperial -> T7 Runic
-> T8 Legendary, unlocked progressively per arena region.

**Weapon families (target 120-180 weapons at full release):**
Swords (dagger/shortsword/longsword/greatsword/curved blade), Axes (hand/battle/great/pole),
Blunt (club/hammer/mace/warhammer), Spears (spear/pike/halberd), Ranged (sling/short/long/war
bow/crossbow), Magical (wand/staff/orb). Share base visual components with recolors/decoration
rather than fully unique art per item.

**Modifiers** (examples): `+Strength/+Agility/+Attack/+Defence/+Vitality, +Crit Chance/+Crit
Damage, +Fire/Poison Damage, +Armour Penetration, +Life Steal, +Energy/Mana Recovery`. Design
real tradeoffs — a new item should not simply be "+10% better," e.g.:
```
Executioner's Axe: Damage +35%, Armour Penetration +20%, Attack Speed -15%, Accuracy -5%
Duelist Blade:      Damage +8%,  Attack Speed +20%,      Crit Chance +12%
```
Both must be viable depending on build.

**Enchantment system:** Flaming (Fire dmg), Frozen (Slow chance), Venomous (Poison), Vampiric
(Life Steal), Stormforged (Lightning chain chance), Fortified (extra armour). Levels +0 to +10,
configurable cost/success chance, no aggressive pay-to-win (ties to Section 5).

**Equipment requirements create anticipation:** items may require min level/Strength/Agility/
Arcana (e.g. "Imperial Great Axe — Level 24, Strength 43"), so the player is frequently "two
points away" from the next upgrade.

---

## 17. SKILL SYSTEM

At least 40 skills at full release, organized into disciplines with branches; players invest
across trees and build hybrids — **no permanent hard class chosen at character creation** (this
is a deliberate departure from the reference game's binary Wizard/Warrior split — document this
as an intentional design decision in `AI_GUIDE.md`).

```
MARTIAL   -> Berserker, Guardian, Duelist
RANGED    -> Marksman, Skirmisher, Hunter
ARCANE    -> Elementalist, Battlemage, Curse Weaver
PRESENCE  -> Taunt, Intimidation, Crowd Manipulation
```
Design real synergies/tradeoffs so "dump everything into one tree" is never the flatly correct
answer. Example skills: Power Strike, Armour Break, Whirlwind, Shield Bash, Lunge, Crippling
Strike, Execution, Rapid Shot, Piercing Arrow, Poison Arrow, Fireball, Frost Lance, Chain
Lightning, Mana Shield, Blood Rage, Battle Cry, Intimidate, Grand Taunt (all placeholder
names/effects, must be original).

**Example viable build archetypes to validate balance against:** Berserker (STR/Greataxe/Blood
Rage+Armour Break+Execution — burst, fragile), Marksman (AGI+Attack/Warbow/kiting kit — range
control, weak up close), Guardian (DEF+VIT/Heavy+Shield/Shield Bash+Fortify+Counterattack —
tanky, low damage), Arcane Fighter (Arcana+VIT/Staff-Sword hybrid), Crowd Manipulator (high
Charisma+Defence, Taunt/Intimidate/Crowd Frenzy/Mocking Counter/Showmanship — a legitimate
playstyle, not a joke stat).

---

## 18. STATUS EFFECT SYSTEM

One reusable generic system, not bespoke code per effect. Fields: `effect_id, duration,
stack_count, max_stacks, source, target, periodic_damage, stat_modifiers, tags`. Support Poison,
Bleed, Burn, Freeze, Slow, Stun, Silence, Weakness, Vulnerability, Rage, Regeneration, Shield
(target 20+ effects at full release).

---

## 19. CROWD SYSTEM

Audience meter: Hostile -> Bored -> Neutral -> Excited -> Frenzied. Rises on crits, combos,
successful risky plays, successful taunts, dramatic kills. Grants small energy boost, fame
bonus, gold bonus, or temporary morale effects. Must make Charisma builds genuinely competitive.

---

## 20. AI OPPONENT SYSTEM

**Utility-based, never random action selection.** For each candidate action:
```
score = expected_damage + kill_probability + tactical_value + personality_modifier
        + status_synergy - resource_cost - tactical_risk
```
Inputs: own/enemy HP, armour, distance, Energy, Mana, status effects, cooldowns, expected
damage, kill/retreat opportunity, opponent build. Archer maintains distance; Berserker closes
aggressively; Tank blocks and exhausts; Mage manages resources and stacks status combos.

**Personalities** (reusable, modify decision weights so identical gear still fights differently):
Aggressive, Defensive, Cautious, Opportunistic, Berserker, Archer, Mage, Trickster, Boss.

**Normal opponents may be procedurally generated** from `player_level, arena_tier, difficulty,
build_archetype` — name, appearance, attributes, skill loadout, equipment, personality — but
must not be an unfair direct copy of the player's exact stats.

**Champions must be handcrafted**, never procedural. Target 18-24 at full release, each with:
identity, visual theme, AI personality, signature weapon, signature ability, unique intro/defeat
reaction, unique mechanic that teaches or tests a gameplay system, unique reward. (See Section 0
for the naming-collision rule.)

---

## 21. ARENA, TOURNAMENT, AND NORMAL DUEL STRUCTURE

Six major arena regions gating level ranges (placeholder names/ranges, redesign freely as long
as they stay original — e.g. Region 1 ~ levels 1-8 up through Region 6 ~ levels 48-60).
Environmental hazards (spike pits, fire vents, falling rocks, traps, ice, poison clouds) must be
telegraphed/predictable — never unavoidable random death.

**Tournament loop:** Qualification -> Quarter Final -> Semi Final -> Final -> Arena Champion,
opponents scaling up each round; rewards: gold, XP, fame, unique item, arena unlock.

**Normal duels** exist for leveling, gold, build experimentation, and tournament prep — match
opponents to a computed **power rating** (level + attributes + equipment + skill power +
resistances), not raw player level. Never expose the exact power-rating algorithm to the player.

---

## 22. TOWN, NPCS, AND ECONOMY

Town is a navigable menu/scene, not open-world. NPCs: Weaponsmith, Armourer, Arcane Merchant,
Alchemist, Trainer, Arena Master, Healer, Blacksmith, Innkeeper — each with name, portrait,
short dialogue, reactions to player fame, occasional quests/events.

**Prices** depend on `base_item_value, item_tier, rarity, player_charisma, player_reputation`
via `EconomyCalculator`, with separate buy/sell prices and safeguards against infinite-money
exploits. **Gold sinks:** weapons, armour, potions, training, enchantments, repairs, rerolls,
cosmetics — avoid excessive grind (validate with the economy simulation in Section 37).

**Consumables:** Health/Energy/Mana Potion, Antidote, Fire Resistance Potion, Battle Elixir,
temporary buff food — capped combat usage (example: 3 consumable slots).

**Inventory:** grid, comparison, filter/sort (type, rarity, level, weapon class, newest, value),
selling, favorite-locking — must stay touch-friendly on mobile.

---

## 23. RANDOM EVENTS AND QUESTS

Lightweight, data-driven events between fights (traveling merchant, injured gladiator,
mysterious trainer, gambling event, arena fan, corrupt official). Choices yield gold, attributes,
items, fame, or temporary penalties. **Gambling events wager in-game gold only — see Section 5
for the real-money boundary.**

---

## 24. DEATH, DIFFICULTY, AND NEW GAME+

Default: defeat costs some gold/tournament progress/temporary injury, not permanent character
deletion. Optional **Iron Gladiator** mode: permanent death. Difficulty tiers (Casual, Normal,
Veteran, Legendary) should change AI behavior and encounter composition, not just multiply enemy
HP. New Game+ after the final boss carries appearance/some equipment/cosmetics/achievements;
enemies gain improved AI, modifiers, new abilities, additional item tiers.

---

## 25. VISUAL STYLE, ANIMATION, VFX, HIT REACTION

Original stylized 2D cartoon graphics: exaggerated anatomy, oversized weapons, expressive faces,
humorous (cartoon, non-graphic) violence, colorful arenas, readable silhouettes. Strong reactions
on hit/block/crit/poison/stun/defeat. Never imitate another game's specific character designs.

**Required animation set:** Idle, Walk, Run, Jump, AttackLight, AttackHeavy, AttackSpecial,
Shoot, Cast, Block, Parry, Hit, CriticalHit, Stunned, Taunt, Victory, Death — weapons attach
dynamically, animations must work across body-shape variants (Section 12).

**Hit feedback** combines hit-pause, camera shake, particles, sound, flash, damage numbers,
knockback, crowd sound — but screen shake must be reducible/disable-able (accessibility,
Section 30).

**VFX list:** slash trails, sparks, blood particles (toggleable, see Section 30), shield impact,
armour break, fire, ice, poison, lightning, healing, level-up, legendary glow — mobile needs a
scalable quality setting; see the shader budget rule in Section 4.

---

## 26. AUDIO AND MUSIC

Buses: `Master, Music, SFX, UI, Voice, Ambience` — volume settings persist in save/settings.
Distinct tracks for menu, town, normal battle, tournament, champion, final boss, victory, defeat,
with appropriate transitions. **Web export note:** browsers block audio autoplay before a user
gesture — do not rely on music starting before the first click/tap.

---

## 27. ASSET SOURCING PIPELINE *(new — critical practical gap)*

A coding agent cannot draw final art or compose final music. This must be explicit so gameplay
work is never blocked on missing art:

1. **Always build and ship placeholders first.** Use Godot primitives (ColorRect, Polygon2D,
   procedurally colored rectangles/capsules) as stand-ins for every character part, weapon icon,
   and VFX during MVP and vertical-slice development. Gameplay, UI layout, and animation state
   machines must all be fully functional against placeholders before final art exists.
2. **Track every missing real asset** in `PROJECT_STATE.md -> Open Asset Requests` and/or a
   dedicated `/docs/ASSET_MANIFEST.md` with fields: `asset_id, type, dimensions, pivot point,
   attachment point, animation requirements, layers, required_variants, status
   (placeholder/requested/final)`. Never claim an asset is final when it is a placeholder.
3. **Audio the same way:** ship silence or a single royalty-free/CC0 placeholder cue per bus
   category rather than blocking on final composition; log real-audio needs the same way.
4. Sourcing final art/audio (commissioning an artist, licensing a royalty-free pack, or using an
   external image/audio generation tool with human review) is explicitly a **human-driven task
   outside the coding agent's own capability** — the agent's job is to define the manifest and
   wire the pipeline so drop-in replacement is trivial, not to produce final artwork itself.

---

## 28. UI/UX, RESPONSIVE DESIGN, AND ACCESSIBILITY

**Combat HUD minimum:** player HP/armour/Energy/Mana/status; opponent HP/armour/status; action
bar (Attack, Move, Defend, Skills, Magic, Items, Taunt). Mobile buttons ≥ ~44-48 logical px.
Skill menus can expand on demand; core actions stay immediately visible. Never require hover,
right-click, or a keyboard shortcut for anything gameplay-critical — touch must reach every
function.

**Responsive:** support 16:9, 16:10, ultrawide, tablets, varied phone aspect ratios via anchors
and containers, never hardcoded pixel positions. Combat is landscape-first; menus adapt more
freely.

**Input abstraction:** use Godot's InputMap (`confirm, cancel, attack, defend, skill, inventory,
move_left, move_right, pause`, etc.); UI never depends directly on raw key codes. **Provide a
remap UI** for desktop key/controller bindings, not just an internal InputMap (this was
previously unspecified).

**Accessibility:** screen-shake slider, blood/gore toggle, colorblind-friendly status icons,
scalable UI text, subtitles, independent volume controls, pause, animation-speed option where
feasible, and a simplified/one-handed mobile control layout option for core combat actions.

---

## 29. LOCALIZATION

From day one: **English + Turkish**, with architecture ready for German, French, Spanish,
Portuguese, Polish, Russian, Japanese, Korean, Simplified Chinese later. Never hardcode
player-visible strings — use translation keys (`combat.attack`, `shop.buy`,
`skill.power_strike.name`). Numbers, currency, and plurals must support locale-aware formatting.
Correct: `tr("SKILL_POWER_STRIKE_NAME")`. Incorrect: `button.text = "Power Strike"`. Design UI
containers for text-length expansion across languages.

---

## 30. WRITING AND HUMOR STYLE GUIDE *(new)*

The tone is "humorous but deep" and the product targets global app stores, so define the comedic
boundary explicitly rather than leaving it to agent judgment per line:

- Favored: absurdist gladiator-world flavor text, over-the-top item/skill descriptions,
  self-aware announcer lines, silly NPC personalities, comedic (non-graphic) defeat quips.
- Avoid: real-world political, religious, or ethnic humor; punching-down jokes about real groups;
  content that would push the game above a "cartoon violence" age rating; anything that wouldn't
  clear standard app-store content-review guidelines.
- Keep a short `/docs/writing_style.md` with 5-10 example lines showing the target voice so
  content added later stays consistent.

---

## 31. SAVE SYSTEM AND DATA SECURITY

Multiple character saves, each containing `save_version, character, appearance, level, xp,
attributes, skills, inventory, equipment, gold, fame, arena_progress, tournaments, quests,
settings, playtime`. **Save versioning with migration support is mandatory** — old saves must
not break after an update; document each migration.

**Autosave** after battle, after purchases, after level-up, before/after tournament, and on app
backgrounding where the platform supports it — never mid-unresolved-combat-action.

**Data security scope (explicit non-goal, to avoid wasted effort):** local save files are not
protected against player-side tampering in the MVP/vertical-slice/full-release scope described
here — this is acceptable for a single-player game with no leaderboards. If asynchronous PvP or
leaderboards are added later (Section 32), server-side validation becomes required at that time,
not before.

**Offline-first:** the core single-player game must work with zero server dependency — this
simplifies mobile reliability, Web hosting, and long-term maintenance.

---

## 32. PLATFORM ABSTRACTION AND OPTIONAL ONLINE FEATURES

Core gameplay never calls a platform SDK directly. Define an interface:
```
PlatformService
    save_cloud()
    unlock_achievement()
    show_leaderboard()
    purchase()
```
with implementations added later behind this interface only: `SteamPlatformService`,
`GooglePlayPlatformService`, `AppleGameCenterService`, `WebPlatformService`. Cloud saves,
leaderboards, async PvP, and daily challenges may be designed for later but are **not required
for MVP** and must never be coupled into core combat/save logic.

---

## 33. ACHIEVEMENTS

Examples: first victory, first champion defeated, 100 victories, win without taking damage,
defeat a champion at low HP, complete the game, complete Iron Gladiator mode. Steam achievement
integration goes behind `PlatformService`, added post-MVP.

---

## 34. DEBUG TOOLS, DETERMINISTIC RNG, AND COMBAT LOGGING

**Central RNG service** (`rng_service.gd`) — no scattered independent `randi()`/`randf()` calls
across the codebase. Support `set_seed(12345)` / a `--combat-seed=` launch flag so combat bugs
are reproducible.

**Combat logger** (optionally disabled in release builds) showing hit chance, roll, raw damage,
armour reduction, final damage, HP before/after — essential for balancing and debugging.

**Debug menu** (dev-only, disabled/protected in production builds): set level, add XP/gold,
unlock arena, give item/skill, spawn enemy, fight champion, reset save, god mode toggle, set RNG
seed, show AI decision scoring (e.g. `Power Strike: 71.4 utility ... Selected: Power Strike`),
show damage formula breakdown.

---

## 35. AUTOMATED TESTING AND BALANCING TOOLS

**Unit tests** for: damage calculations, armour overflow, status effects, hit probability,
critical chance, level XP curve, shop prices, save/load (including migration), item
requirements. Edge cases: HP=1, Armour=0, 100% resistance, zero stamina, huge critical damage,
negative modifiers, max level.

**Simulation tooling** (dev-only, not shipped): run N simulated battles between build archetypes
and report win rate, average turns, average damage, resource usage, skill usage, crit rate,
armour effectiveness (e.g. "10,000 battles, Berserker vs Marksman @ Lvl 20 -> 52.8% / 47.2%,
avg 9.4 turns"). **Economy simulation** tooling for average gold/level, average equipment cost,
time-to-purchase, to catch both infinite-gold and unreasonable-grind failure modes.

---

## 36. PERFORMANCE BUDGETS

**Mobile:** target 60 FPS on ordinary modern phones (see device matrix, Section 3), with an
optional 30 FPS battery-saving mode. Use sprite atlases, texture compression, object pooling,
particle limits, restrained shader use, low draw calls, avoid unnecessary `_process()` loops.

**Web:** small download, short boot time, controlled texture sizes, no unnecessarily
high-resolution audio, no threading dependency, no unsupported platform APIs. Profile before
speculative optimization; don't guess.

---

## 37. CI / BUILD PIPELINE *(new)*

- Set up a minimal automated check (e.g. GitHub Actions or equivalent) that at least runs the
  GDScript unit test suite on push, once tests exist (Section 35). Document the CI config choice
  in `AI_GUIDE.md`.
- Before adding any native extension, third-party plugin, or library, verify Windows + Android +
  Web export compatibility at minimum, and document the compatibility decision in `AI_GUIDE.md`
  — do not introduce a dependency that silently breaks Web export.
- Maintain a documented, repeatable export process per platform (desktop/web at minimum for
  MVP; mobile once relevant phase is reached) so a build can be produced on demand, not only
  from editor muscle memory.

---

## 38. VERSIONING AND STORE READINESS *(new)*

- Track the game's own version using semver (`0.1.0` MVP, `0.2.0` vertical slice, etc.) in
  `PROJECT_STATE.md -> Current Game Version` and in `project.godot`.
- **Store readiness is out of scope until the vertical-slice/full-release phases**, but keep a
  running checklist so it isn't a surprise: app icon set, store screenshots, age rating
  questionnaire (expect a "cartoon violence" style rating given the gore-toggleable content —
  Section 30), a privacy policy (required even for an offline-first game once it's listed on
  Android/iOS stores), and store listing text per supported localization.
- These are content/business tasks, not something the coding agent resolves alone — track them
  as open items in `PROJECT_STATE.md` rather than skipping silently or fabricating completion.

---

## 39. CONTENT SCALE TARGETS

**MVP** (prove the loop first — do not start with the full 60-level game):
character creator, 8 attributes, basic combat, 4 weapon classes (~20 weapons), ~20 armour
pieces, 10 combat skills, 10 normal opponents, 1 arena, 1 champion, shop, inventory, level
system, save/load, English + Turkish, exports for Android + Windows + Web.

**Vertical Slice** (should already feel commercially presentable):
Levels 1-10, 2 arenas, 3 champions, 40-50 meaningful items, 20 skills, random events, full
animation set, VFX, complete audio integration, polished UI, mobile controls, validated Web
build.

**Full Release** (guideline, not a rigid quota — never pad with filler to hit a number):
60 player levels, 6 arena regions, 18-24 champions, 100+ normal enemy configurations, 120-180
weapons, 120+ armour/items, 40-60 combat skills, 20+ status effects, 30+ random events, English +
Turkish at minimum.

---

## 40. DEVELOPMENT PHASE PLAN (single authoritative order)

```
Phase 1  Foundation        — project setup, folder structure, autoloads, RNG service, docs
Phase 2  Combat Prototype  — Combatant, TurnManager, attacks, damage, armour, movement, basic AI
Phase 3  Progression       — XP, levels, attributes, skill points
Phase 4  Equipment         — inventory, weapons, armour, shops
Phase 5  Skill System      — active skills, buffs/debuffs, status effects
Phase 6  Arena Progression — duels, tournaments, champions
Phase 7  Presentation      — animation, VFX, audio hookups, camera feedback (against placeholders)
Phase 8  Platform Polish   — mobile controls, desktop, web validation, responsive UI
Phase 9  Content Expansion — additional items, champions, skills, arenas
Phase 10 QA and Balance    — automated tests, simulations, performance pass, balancing
```
Each phase should reach the Definition of Done (Section 41) before the next phase becomes the
focus, though light overlap (e.g. writing tests throughout, not only in Phase 10) is expected.

---

## 41. DEFINITION OF DONE (per phase) *(new)*

A phase (or a meaningful chunk within one) is done only when:
1. The relevant automated tests exist and pass.
2. The affected scene(s) actually launch with no runtime errors or new warnings.
3. It runs on desktop, and a Web export has been smoke-tested if the phase touches
   rendering/input/audio (don't assume Web compatibility — check it).
4. `PROJECT_STATE.md` and `DEVELOPMENT_LOG.md` are updated to match reality.
5. No placeholder is silently presented as final (art, audio, or "fake" functionality/buttons
   with no implementation) unless explicitly marked as a development placeholder in code/UI.

---

## 42. DOCUMENTATION SET

```
README.md
AI_GUIDE.md
PROJECT_STATE.md
DEVELOPMENT_LOG.md
MASTER_BUILD_PROMPT.md        (this file — do not edit; it's the original charter)
/docs/
    architecture.md
    combat.md
    progression.md
    skills.md
    items.md
    ai.md
    localization.md
    saves.md
    balancing.md
    build.md
    writing_style.md
    ASSET_MANIFEST.md
    decisions/                (one file per major architecture decision, optional if few)
```
Every important formula must be documented. Documentation hierarchy: `AI_GUIDE.md` = permanent
constitution, `PROJECT_STATE.md` = current snapshot, `DEVELOPMENT_LOG.md` = chronological
history, `/docs/` = technical system detail. Keep them in their lanes.

---

## 43. SESSION 1 — FIRST IMPLEMENTATION TASK (authoritative)

Do not attempt the whole game at once. Session 1 delivers exactly this, in order:

1. `git status` check, then `git init` if needed (Section 7).
2. Create the Godot project (pin the exact version, Section 4); commit `project.godot` and
   `.gitignore`.
3. Create `AI_GUIDE.md`, `PROJECT_STATE.md`, `DEVELOPMENT_LOG.md`, `/docs/architecture.md`.
4. Establish typed data model resources (`WeaponData`, `SkillData`, etc. — start minimal, expand
   later).
5. Implement the central RNG service with seed support.
6. Implement a minimal `Combatant`.
7. Implement `TurnManager`.
8. Implement a basic `DamageCalculator` (no crits/status yet — just raw hit/damage/armour).
9. Create one player combatant and one AI enemy combatant (placeholder visuals, Section 27).
10. Implement `move`, `normal attack`, `defend`, `rest`.
11. Implement minimal utility-based enemy AI choosing among those four actions.
12. Create one basic arena scene.
13. Create a minimal responsive combat HUD (HP/Energy at minimum).
14. Confirm it runs on desktop with no runtime errors.
15. Export a Web test build and confirm it loads and is playable.
16. Update `PROJECT_STATE.md` and `DEVELOPMENT_LOG.md`; state the recommended next task
    (expected: begin Phase 3 progression, per Section 40).

**Do not** implement 150 weapons, the full skill tree, all champions, online systems, or store
purchases in this session. Success criterion: character enters an arena, player and enemy take
turns via attack/defend/rest, damage and armour behave correctly, one combatant dies, a result
screen appears, and there are no runtime errors — only then move to XP/levels/attributes/
equipment.

---

## 44. FINAL DESIGN PHILOSOPHY AND PRIORITY ORDER

Preserve the addictive simplicity of `fight -> earn -> upgrade -> fight stronger opponent ->
become champion`, layered with depth through builds, skills, equipment, status effects, boss
mechanics, AI personalities, and progression choices — while staying readable on a phone screen.
Avoid turning this into an overly complex tactical RPG. Emotional arc:
`weak nobody -> competent fighter -> famous gladiator -> arena champion -> living legend`.

When priorities conflict, resolve in this order:
```
PLAYABLE GAMEPLAY
  > CORRECT ARCHITECTURE
  > MAINTAINABILITY
  > BUILD DIVERSITY
  > PROGRESSION QUALITY
  > COMBAT FEEL
  > CONTENT VOLUME
  > POLISH
```
Never sacrifice a working, understandable game merely to produce more code. Never fake
functionality, never leave unimplemented buttons unmarked, never claim a platform/system works
without having actually verified it this session.
