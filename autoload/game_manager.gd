extends Node
## Top-level game flow coordinator (charter §11).
## Holds the top-level state machine and the current run context.
## It COORDINATES — combat/inventory/progression logic lives in their
## own systems, never inline here (charter §6: no monolithic managers).

enum GameState {
	BOOT,
	MAIN_MENU,
	PROFILE_SELECT,
	CHARACTER_CREATION,
	TOWN,
	SHOP,
	INVENTORY,
	CHARACTER_SHEET,
	SKILLS,
	ARENA_SELECT,
	PRE_BATTLE,
	COMBAT,
	POST_BATTLE,
	TOURNAMENT,
	CHAMPION_BATTLE,
	GAME_OVER,
	ENDING,
}

signal state_changed(previous: GameState, next: GameState)

var state: GameState = GameState.BOOT

## The player's character for the current run (set before entering combat).
var player_character: CharacterData = null

## The opponent for the next/current combat encounter.
var next_opponent: CharacterData = null

## Result of the most recent combat, consumed by the results screen.
var last_combat_result: CombatResult = null

## True when launched with `--smoke-test`: the game auto-plays one full
## AI-vs-AI duel at zero delay and quits with an exit code (dev/CI only).
var smoke_test: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	smoke_test = args.has("--smoke-test")


func change_state(next: GameState) -> void:
	if next == state:
		return
	var previous: GameState = state
	state = next
	state_changed.emit(previous, next)
