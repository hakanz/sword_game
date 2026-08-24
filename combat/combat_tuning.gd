class_name CombatTuning
## Central tuning knobs for the combat prototype. Every constant here is a
## BALANCING value, not an architectural rule — tune freely, document big
## swings in docs/balancing.md. Formulas live in the calculators; this file
## only holds their coefficients.

# --- Hit chance (HitCalculator) ---
const BASE_HIT_CHANCE: float = 0.5
## Hit chance shift per point of (accuracy - avoidance).
const HIT_CHANCE_PER_POINT: float = 0.02
## Normal attacks are never a guaranteed hit or miss (charter §15).
const MIN_HIT_CHANCE: float = 0.05
const MAX_HIT_CHANCE: float = 0.95

# --- Defend stance ---
const DEFEND_AVOIDANCE_BONUS: int = 8
const DEFEND_DAMAGE_REDUCTION: float = 0.3

# --- Action energy (charter §15: builds should use resources differently) ---
const MOVE_ENERGY_COST: int = 2
const REST_ENERGY_RESTORE_FRACTION: float = 0.4

# --- Safety ---
## Hard cap so a stalemate can never hang the game (winner = higher HP %).
const MAX_ROUNDS: int = 100
