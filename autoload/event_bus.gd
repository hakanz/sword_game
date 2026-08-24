extends Node
## Global signal hub (charter §6: signals over direct coupling).
## Systems emit here; UI and cross-cutting services listen here.
## Keep signals coarse-grained and combat/game-flow focused.

# --- Combat lifecycle ---
signal combat_started(player: Combatant, enemy: Combatant)
signal round_started(round_number: int)
signal turn_started(combatant: Combatant)
signal action_resolved(result: ActionResult)
signal combatant_died(combatant: Combatant)
signal combat_ended(victor: Combatant, loser: Combatant)

# --- Combat presentation ---
## Emitted with an already-localized rich text line for the combat log panel.
signal combat_log_line(text: String)

# --- Debug / tooling ---
## AI decision scores for the debug overlay (charter §34). Keys: action label, values: utility score.
signal ai_scores_computed(combatant_name: String, scores: Dictionary)
