class_name ActionResult
extends RefCounted
## Immutable record of one resolved combat action. The HUD formats log lines
## and floating numbers from this; tests assert on it. Never re-derive combat
## math from UI state.

var actor: Combatant = null
var target: Combatant = null
var action: Enums.ActionType = Enums.ActionType.ATTACK

# Attack fields
var hit: bool = false
var hit_chance: float = 0.0
## A rare heavy blow (CombatTuning.CRIT_CHANCE) — damage already doubled.
var crit: bool = false
var mitigation: DamageCalculator.MitigationResult = null
var killed: bool = false

# Rest fields
var energy_restored: int = 0
var hp_restored: int = 0

# Movement fields
var distance_after: Enums.DistanceBand = Enums.DistanceBand.MEDIUM

# Skill fields
var skill: SkillData = null
## Status applied this action (on-hit debuff or self buff).
var applied_status: StatusEffectData = null
