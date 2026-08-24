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

const PROGRESSION_CONFIG: ProgressionConfig = preload("res://data/progression/progression_config.tres")
const ECONOMY_CONFIG: EconomyConfig = preload("res://data/economy/economy_config.tres")

var state: GameState = GameState.BOOT

## The player's persistent progression (loaded/created via menu flows).
var profile: PlayerProfile = null

## The player's character for the current run (set before entering combat).
var player_character: CharacterData = null

## The opponent for the next/current combat encounter.
var next_opponent: CharacterData = null

## Arena for the next/current encounter (data-driven — charter §6). The
## arena-progression phase will set this per region; null lets the combat
## scene fall back to its default.
var current_arena: ArenaData = null

## Result of the most recent combat, consumed by the results screen.
var last_combat_result: CombatResult = null

## Rewards of the most recent combat (guarded against double application).
var last_reward: ProgressionService.RewardResult = null

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


## Creates a fresh profile (overwriting any existing save) and starts a duel.
func start_new_game() -> void:
	profile = PlayerProfile.create_default()
	SaveManager.save_profile(profile)
	start_next_duel()


## Loads the saved profile and starts a duel. Returns false if load failed.
func continue_game() -> bool:
	profile = SaveManager.load_profile()
	if profile == null:
		return false
	start_next_duel()
	return true


## Builds combatants from the profile + a generated opponent, enters the arena.
func start_next_duel() -> void:
	assert(profile != null, "start_next_duel without a profile")
	player_character = profile.to_character_data()
	next_opponent = OpponentGenerator.generate(profile.level)
	last_combat_result = null
	last_reward = null
	SceneRouter.goto_arena()


## Applies XP/level rewards for the finished combat exactly once and
## autosaves (charter §31: autosave after battle & level-up). Safe to call
## repeatedly; returns null when there is nothing to apply.
func consume_combat_rewards() -> ProgressionService.RewardResult:
	if last_combat_result == null or profile == null:
		return null
	if last_combat_result.rewards_applied:
		return last_reward
	last_reward = ProgressionService.apply_combat_rewards(
			profile, PROGRESSION_CONFIG, ECONOMY_CONFIG, last_combat_result)
	last_combat_result.rewards_applied = true
	SaveManager.save_profile(profile)
	return last_reward
