# Architecture Overview

High-level map of how the pieces fit. Durable RULES live in `AI_GUIDE.md`; this file explains
the shape of the code. Per-system detail: `docs/combat.md`, `docs/ai.md`, more as phases land.

## Layers
```
autoload (global services, alive for the whole session)
  EventBus              typed global signals (combat lifecycle, log lines, debug)
  RngService            single seedable RNG for ALL gameplay randomness
  GameManager           top-level state machine + current run context (player, opponent,
                        last combat result, smoke-test flag). Coordinates only.
  SaveManager           settings persistence now; character slots + save_version later
  LocalizationManager   locale switching/persistence (EN+TR)
  AudioManager          bus volumes + one-shot SFX playback (no content yet)
  SceneRouter           the only place that changes scenes

data/models (Resource class definitions = the content type system)
  Enums, AttributeBlock, WeaponData, ArmourData, SkillData, CharacterData,
  AIPersonality, ArenaData
data/** (.tres content instances — the actual game content)

services (pure calculators, no scene access)
  ProgressionCalculator  attributes -> derived stats; XP curve when Phase 3 lands

combat (the combat machine)
  CombatTuning       every combat coefficient in one place
  HitCalculator      accuracy vs avoidance -> clamped hit chance
  DamageCalculator   damage pipeline; pure compute_mitigation()
  CombatAction       validity + energy costs (single source for HUD/AI/controller)
  CombatContext      duel distance band state
  TurnManager        initiative order, rounds, corpse skipping
  CombatAI           utility-based action selection (docs/ai.md)
  Combatant (Node2D) runtime fighter state + signals; owns a PlaceholderRig
  CombatController   orchestrates one encounter, emits EventBus events
  ActionResult / CombatResult   immutable outcome records

scenes + ui (presentation only)
  boot -> main_menu -> arena (controller + HUD CanvasLayer) -> results
  PlaceholderRig draws fighters from primitives until real art exists
  ArenaVisual draws the backdrop from ArenaData palette
```

## Key flows
**Game flow:** `SceneRouter.goto_*()` changes scenes and drives `GameManager.change_state()`.
Presets are `duplicate(true)`-ed into `GameManager.player_character` / `next_opponent` before
combat — runtime never mutates `.tres` content.

**Combat turn:** controller awaits HUD's `action_selected` (player) or asks `CombatAI`
(enemy/smoke). Both paths validate through `CombatAction`, execute through the calculators,
mutate only `Combatant` state, and emit `EventBus.action_resolved(ActionResult)`; the HUD
formats localized log lines from the result and refreshes bars via Combatant signals.

**Determinism:** one seeded RNG (`--combat-seed=N`); decorative visuals use local RNGs.
The smoke test (`--smoke-test`) rides the identical code path the player uses — boot scene
wires AI-vs-AI, results screen quits with an exit code.

## Testing shape
`tests/test_runner.gd` (SceneTree script) discovers `tests/unit/test_*.gd` (extend
`TestCase`); `tests/combat_fixtures.gd` builds throwaway combatants/characters. Pure
calculator functions carry the heaviest asserts (incl. invariants); AI expectations are
seeded to stay deterministic. See AI_GUIDE "Testing Rules" for commands.
