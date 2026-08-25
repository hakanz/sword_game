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
	SETTINGS,
}

signal state_changed(previous: GameState, next: GameState)

const PROGRESSION_CONFIG: ProgressionConfig = preload("res://data/progression/progression_config.tres")
const ECONOMY_CONFIG: EconomyConfig = preload("res://data/economy/economy_config.tres")

var state: GameState = GameState.BOOT

## Which street merchant the SHOP scene represents (owner design: the
## weaponsmith and the armourer are separate stalls).
enum ShopKind { WEAPONS, ARMOUR }
var shop_kind: ShopKind = ShopKind.WEAPONS

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


## Creates a fresh profile (overwriting any existing save). A new gladiator
## arrives in TOWN first (session-6 owner design) — the first fight is a
## choice, never an ambush.
func start_new_game() -> void:
	profile = PlayerProfile.create_default()
	SaveManager.save_profile(profile)
	SceneRouter.goto_town()


## Creates a profile from the character-creation screen's choices.
## `unspent_points` (session-5 point-buy) carry over as attribute points.
func start_new_game_custom(
		character_name: String, attrs: AttributeBlock,
		body: Color, accent: Color, unspent_points: int = 0) -> void:
	profile = PlayerProfile.create_default()
	if character_name.strip_edges() != "":
		profile.character_name = character_name.strip_edges()
	profile.attributes = attrs.duplicate_block()
	profile.attribute_points += maxi(unspent_points, 0)
	profile.body_color = body
	profile.accent_color = accent
	SaveManager.save_profile(profile)
	SceneRouter.goto_town()


## Loads the saved profile and returns to town. Returns false if load failed.
func continue_game() -> bool:
	profile = SaveManager.load_profile()
	if profile == null:
		return false
	SceneRouter.goto_town()
	return true


## Tournament structure (charter §21): Qualification -> Quarter Final ->
## Semi Final -> Final vs the arena's handcrafted champion.
const TOURNAMENT_ROUNDS: int = 4
## Victories needed before an arena's tournament accepts an entrant.
const TOURNAMENT_UNLOCK_VICTORIES: int = 3
## Opponent level position within the arena band per non-final round.
const TOURNAMENT_ROUND_CURVE: Array[float] = [0.25, 0.55, 0.85]

## Active tournament (empty = none). Runs are single-sitting: leaving or
## losing forfeits progress; COMPLETION persists on the profile.
var tournament_arena_id: StringName = &""
var tournament_round: int = 0
## True only for fights launched by start_tournament_round() — normal duels
## must never advance the bracket.
var tournament_fight_pending: bool = false
## Outcome flags for the results screen (set once in consume_combat_rewards).
var tournament_won_round: bool = false
var tournament_completed: bool = false
var tournament_failed: bool = false


func selected_arena() -> ArenaData:
	if profile == null:
		return ItemDB.all_arenas()[0]
	return ItemDB.arena(profile.selected_arena_id)


## Region gating: order 1 is open; later regions need the previous arena's
## tournament completed (charter §21 arena unlock reward).
func is_arena_unlocked(arena: ArenaData) -> bool:
	if arena.order <= 1:
		return true
	if profile == null:
		return false
	for other in ItemDB.all_arenas():
		if other.order == arena.order - 1:
			return profile.completed_tournament_arena_ids.has(other.id)
	return false


func is_tournament_unlocked(arena: ArenaData) -> bool:
	return profile != null and is_arena_unlocked(arena) \
			and profile.victories >= TOURNAMENT_UNLOCK_VICTORIES


## The arena's call (session-5 owner design): once the tournament is open
## and the player has grown into the region (level at the band midpoint),
## normal duels LOCK until the bracket is fought — progression flows through
## the boss ladder, not through endless safe duels.
func tournament_required() -> bool:
	if profile == null:
		return false
	var arena: ArenaData = selected_arena()
	if profile.completed_tournament_arena_ids.has(arena.id):
		return false
	if not is_tournament_unlocked(arena):
		return false
	return profile.level >= roundi(lerpf(arena.min_level, arena.max_level, 0.5))


func in_tournament() -> bool:
	return tournament_arena_id != &""


## Builds combatants from the profile + a generated opponent, enters the arena.
func start_next_duel() -> void:
	assert(profile != null, "start_next_duel without a profile")
	# The arena's call is binding: when the tournament is due, the gate to
	# casual duels closes (UI mirrors this; the guard is the authority).
	if tournament_required() and not smoke_test:
		SceneRouter.goto_arena_select()
		return
	# A normal duel forfeits any bracket left hanging (leaving = forfeit).
	abandon_tournament()
	var arena: ArenaData = selected_arena()
	current_arena = arena
	player_character = profile.to_character_data()
	next_opponent = OpponentGenerator.generate_for_arena(profile.level, arena)
	last_combat_result = null
	last_reward = null
	SceneRouter.goto_arena()


func start_tournament(arena: ArenaData) -> void:
	assert(is_tournament_unlocked(arena), "tournament started while locked")
	tournament_arena_id = arena.id
	tournament_round = 0
	_clear_tournament_flags()
	SceneRouter.goto_tournament()


func abandon_tournament() -> void:
	tournament_arena_id = &""
	tournament_round = 0
	tournament_fight_pending = false
	_clear_tournament_flags()


## Enters the current tournament round's fight (final = arena champion).
func start_tournament_round() -> void:
	assert(in_tournament(), "no active tournament")
	var arena: ArenaData = ItemDB.arena(tournament_arena_id)
	current_arena = arena
	player_character = profile.to_character_data()
	if tournament_round >= TOURNAMENT_ROUNDS - 1:
		next_opponent = arena.champion.duplicate(true)
	else:
		var t: float = TOURNAMENT_ROUND_CURVE[tournament_round]
		# Bracket fighters are ELITES: same level band, better gear + skills
		# (session-5 owner design — the tournament is the proving ground).
		next_opponent = OpponentGenerator.generate_at_level(
				roundi(lerpf(arena.min_level, arena.max_level, t)), true)
	tournament_fight_pending = true
	last_combat_result = null
	last_reward = null
	SceneRouter.goto_arena()


func _clear_tournament_flags() -> void:
	tournament_won_round = false
	tournament_completed = false
	tournament_failed = false


## Dev-only visual check (`--screenshot-dir=`): captures menu, creation and
## arena frames to PNG then quits. Lives on this autoload so it survives the
## scene changes it drives.
func run_screenshot_capture(dir: String) -> void:
	SaveManager.disk_writes_enabled = false
	SceneRouter.goto_main_menu()
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("menu.png"))
	profile = PlayerProfile.create_default()
	SceneRouter.goto_character_creation()
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("creation.png"))
	# Skills included so the capture shows the inline skill icon buttons.
	profile.known_skill_ids.append_array([
		&"skill.crushing_blow", &"skill.venom_smear", &"skill.war_bellow",
	])
	start_next_duel()
	await get_tree().create_timer(2.4).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("arena.png"))
	SceneRouter.goto_settings()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("settings.png"))
	profile.victories = TOURNAMENT_UNLOCK_VICTORIES
	SceneRouter.goto_arena_select()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("arenas.png"))
	tournament_arena_id = &"arena.gravelmaw"
	tournament_round = 1
	SceneRouter.goto_tournament()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("tournament.png"))
	abandon_tournament()
	SceneRouter.goto_town()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("town.png"))
	SceneRouter.goto_weaponsmith()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("weaponsmith.png"))
	get_tree().quit(0)


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

	# Session-6 ranged flow: a WIN keeps the last-held weapon selected for
	# the next fight; a LOSS resets to the sidearm and leaves the fighter
	# fatigued (drained opening energy next fight).
	if last_combat_result.player_won:
		# Weapon memory only forms in fights where switching was a real
		# choice — a melee-only win must never pre-draw a bow bought later.
		if last_combat_result.player_could_switch:
			profile.prefers_main_weapon = last_combat_result.player_ended_wielding_main
	else:
		profile.prefers_main_weapon = false
		profile.battle_fatigue = true

	# Tournament bookkeeping (once per fight, same idempotence guard).
	_clear_tournament_flags()
	if in_tournament() and tournament_fight_pending:
		tournament_fight_pending = false
		if last_combat_result.player_won:
			tournament_round += 1
			tournament_won_round = true
			if tournament_round >= TOURNAMENT_ROUNDS:
				tournament_completed = true
				if not profile.completed_tournament_arena_ids.has(tournament_arena_id):
					profile.completed_tournament_arena_ids.append(tournament_arena_id)
				# The house pays extra for a completed bracket (session-5).
				last_reward.tournament_bonus_gold = ECONOMY_CONFIG.tournament_gold_bonus
				last_reward.gold_gained += last_reward.tournament_bonus_gold
				profile.gold += last_reward.tournament_bonus_gold
				tournament_arena_id = &""
				tournament_round = 0
		else:
			tournament_failed = true
			tournament_arena_id = &""
			tournament_round = 0

	SaveManager.save_profile(profile)
	return last_reward
