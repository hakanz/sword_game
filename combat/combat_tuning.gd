class_name CombatTuning
## Central tuning knobs for the combat prototype. Every constant here is a
## BALANCING value, not an architectural rule — tune freely, document big
## swings in docs/balancing.md. Formulas live in the calculators; this file
## only holds their coefficients.

# --- Hit chance (HitCalculator) ---
const BASE_HIT_CHANCE: float = 0.5
## Hit chance shift per point of (accuracy - avoidance).
## Tuned 0.02 -> 0.015 (session 3): §35 simulation showed accuracy stats
## dominating every matchup at 2%/point (swift preset ~76% win rate).
const HIT_CHANCE_PER_POINT: float = 0.015
## Normal attacks are never a guaranteed hit or miss (charter §15).
const MIN_HIT_CHANCE: float = 0.05
const MAX_HIT_CHANCE: float = 0.95

# --- Defend stance ---
const DEFEND_AVOIDANCE_BONUS: int = 8
const DEFEND_DAMAGE_REDUCTION: float = 0.3

# --- Critical hits (session-6 owner design: rare, heavy, for BOTH sides;
# base chance lives per weapon, the class-matched attribute adds on top) ---
const CRIT_MULTIPLIER: float = 2.0
## Crit chance added per point of the weapon class's crit attribute.
const CRIT_ATTR_PER_POINT: float = 0.002
const MIN_CRIT_CHANCE: float = 0.01
const MAX_CRIT_CHANCE: float = 0.25

# --- Action energy (charter §15: builds should use resources differently) ---
const MOVE_ENERGY_COST: int = 2
const REST_ENERGY_RESTORE_FRACTION: float = 0.4
## Rest also patches wounds a little (session-2 design directive).
const REST_HP_RESTORE_FRACTION: float = 0.08

# --- Safety ---
## Hard cap so a stalemate can never hang the game (winner = higher HP %).
const MAX_ROUNDS: int = 100
