extends Node
## Global signal hub (charter §6: signals over direct coupling).
## Systems emit here; UI and cross-cutting services listen here.
## Keep signals coarse-grained and combat/game-flow focused.

# --- Combat lifecycle ---
signal combat_started(player: Combatant, enemy: Combatant)
signal round_started(round_number: int)
signal turn_started(combatant: Combatant)
## The combatant lost their action this turn (stunned).
signal turn_skipped(combatant: Combatant)
signal action_resolved(result: ActionResult)
signal combatant_died(combatant: Combatant)
signal combat_ended(victor: Combatant, loser: Combatant)

# --- Status effects ---
signal status_applied(target: Combatant, instance: StatusEffectInstance)
signal status_expired(target: Combatant, effect: StatusEffectData)
## One StatusEffectSystem.TickResult per active effect after a fighter's
## end-of-turn resolution. (Untyped Array on purpose: typing an autoload
## signal with another class's inner class deadlocks the 4.4 analyzer.)
signal status_ticked(target: Combatant, results: Array)

# --- Crowd (charter §19 / V2 §54) ---
## A fighter crossed into a new crowd state (`state` is a CrowdSystem.State,
## passed as int on purpose: typing an autoload signal with another class's
## inner type deadlocks the GDScript analyzer — same reason status_ticked
## takes a plain Array). `rising` separates a roar from a groan.
signal crowd_state_changed(fighter: Combatant, state: int, rising: bool)

# --- Debug / tooling ---
## AI decision scores for the debug overlay (charter §34). Keys: action label, values: utility score.
signal ai_scores_computed(combatant_name: String, scores: Dictionary)
