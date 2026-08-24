class_name CombatResult
extends RefCounted
## Outcome summary of a finished combat, consumed by the results screen and
## (in the progression phase) by the reward pipeline.

var player_won: bool = false
var rounds: int = 0
var player_damage_dealt: int = 0
var victor_name: String = ""
var loser_name: String = ""
## Level of the opponent — input for the XP reward formula.
var enemy_level: int = 1
## Set by GameManager.consume_combat_rewards() to guard double application.
var rewards_applied: bool = false
