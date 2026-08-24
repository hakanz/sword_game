class_name CombatResult
extends RefCounted
## Outcome summary of a finished combat, consumed by the results screen and
## (in the progression phase) by the reward pipeline.

var player_won: bool = false
var rounds: int = 0
var player_damage_dealt: int = 0
## Effectiveness tally for the XP multiplier (landed strikes / actions).
var player_hits: int = 0
var player_actions: int = 0
var victor_name: String = ""
var loser_name: String = ""
## Level of the opponent — input for the XP reward formula.
var enemy_level: int = 1
## Set to the champion's CharacterData id when the opponent was a champion.
var champion_id: StringName = &""
## Set by GameManager.consume_combat_rewards() to guard double application.
var rewards_applied: bool = false


## Round-cap stalemate rule (centralized per charter §6): the higher
## remaining HP fraction takes the decision; ties go to the player.
static func stalemate_player_won(player: Combatant, enemy: Combatant) -> bool:
	return float(player.current_hp) / float(player.max_hp) \
			>= float(enemy.current_hp) / float(enemy.max_hp)
