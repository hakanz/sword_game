class_name CrowdSystem
## The audience (charter §19, amendment V2 §54) — and the reason Charisma is a
## combat stat at last, not just a shop discount.
##
## Every fighter carries their OWN standing with the crowd for the duration of
## one fight: it climbs when they do something worth watching (crits, landed
## skills, a guard that holds, a dramatic finish, a taunt) and falls when they
## bore the pit (turtling, running, resting, dragging the fight out). At
## Excited the crowd throws energy behind their favourite; at Frenzied it also
## steadies their aim.
##
## Boundaries and promises:
##  - Runtime state ONLY. The meter lives on `Combatant`, resets every fight,
##    and is never persisted — no save version changes for this system.
##  - Stalling is measured with the anti-stall counters `CombatResolver` and
##    `CombatAI` already keep (`consecutive_defends`, `total_retreats`), never
##    with a second, competing stall detector (V2 §54).
##  - The boons are deliberately SMALL. A build that ignores Charisma must
##    still be viable; the crowd is a lever, never a tax (charter §16's
##    itemization philosophy applied to a stat).
##  - Pure functions + one mutator. The resolver (shared with the §35
##    simulator) drives it, so simulated fights feel the crowd too.

enum State {
	HOSTILE,   ## jeering — you have lost the pit
	BORED,     ## slow handclaps
	NEUTRAL,   ## watching
	EXCITED,   ## on their feet
	FRENZIED,  ## the arena is a wall of noise
}

const START: int = 50
const MINIMUM: int = 0
const MAXIMUM: int = 100

## Lower bound of each state, ordered. Read through `state_of`.
const HOSTILE_BELOW: int = 20
const BORED_BELOW: int = 40
const EXCITED_AT: int = 70
const FRENZIED_AT: int = 90

# --- What the pit pays for -------------------------------------------------
const CRIT_GAIN: int = 12
## A finishing blow is the loudest moment a duel has.
const KILL_GAIN: int = 18
const SKILL_GAIN: int = 6
## Landing a skill while nearly dead — the comeback beat (V2 §54).
const DESPERATE_GAIN: int = 12
const DESPERATE_HP_FRACTION: float = 0.3
## A guard that actually turns a blow aside.
const GUARD_HELD_GAIN: int = 5

# --- What the pit punishes -------------------------------------------------
## Applied once the EXISTING consecutive-defend counter says this is turtling.
const TURTLE_LOSS: int = -8
const TURTLE_AFTER_DEFENDS: int = 2
const RETREAT_LOSS: int = -6
const REST_LOSS: int = -4
## Every action after this round bleeds a little interest away.
const LONG_FIGHT_ROUND: int = 12
const LONG_FIGHT_LOSS: int = -2

## Charisma raises the CLIMB rate only — a charming fighter wins the pit
## faster, but nobody is punished harder for being dull.
const CHARISMA_GAIN_PER_POINT: float = 0.02

# --- What the crowd gives back ---------------------------------------------
const EXCITED_ENERGY: int = 3
const FRENZIED_ENERGY: int = 5
const FRENZIED_ACCURACY: int = 4


static func state_of(value: int) -> State:
	if value < HOSTILE_BELOW:
		return State.HOSTILE
	if value < BORED_BELOW:
		return State.BORED
	if value >= FRENZIED_AT:
		return State.FRENZIED
	if value >= EXCITED_AT:
		return State.EXCITED
	return State.NEUTRAL


static func label_key(state: State) -> String:
	match state:
		State.HOSTILE:
			return "crowd.hostile"
		State.BORED:
			return "crowd.bored"
		State.EXCITED:
			return "crowd.excited"
		State.FRENZIED:
			return "crowd.frenzied"
		_:
			return "crowd.neutral"


## Gains scale with Charisma; losses never do.
static func gain_multiplier(charisma: int) -> float:
	return 1.0 + maxi(charisma, 0) * CHARISMA_GAIN_PER_POINT


## Applies a raw delta to a fighter's standing, scaling POSITIVE deltas by
## their Charisma, and announces a state change. Returns the new value.
static func shift(fighter: Combatant, delta: int) -> int:
	if fighter == null or delta == 0:
		return 0
	var scaled: int = delta
	if delta > 0:
		scaled = roundi(delta * gain_multiplier(fighter.attributes.charisma))
	var before: State = state_of(fighter.crowd)
	fighter.crowd = clampi(fighter.crowd + scaled, MINIMUM, MAXIMUM)
	var after: State = state_of(fighter.crowd)
	fighter.crowd_changed.emit(fighter.crowd, after)
	if after != before:
		EventBus.crowd_state_changed.emit(fighter, after, after > before)
	return fighter.crowd


## Energy the crowd hands their favourite at the start of their turn.
static func energy_boon(fighter: Combatant) -> int:
	match state_of(fighter.crowd):
		State.FRENZIED:
			return FRENZIED_ENERGY
		State.EXCITED:
			return EXCITED_ENERGY
		_:
			return 0


## Accuracy the roar is worth — only at the very top of the meter.
static func accuracy_bonus(fighter: Combatant) -> int:
	return FRENZIED_ACCURACY if state_of(fighter.crowd) == State.FRENZIED else 0


## The crowd's verdict on one resolved action, as a raw (pre-Charisma) delta.
## Pure: the resolver applies it, this only judges it.
static func delta_for(result: ActionResult, round_number: int) -> int:
	var actor: Combatant = result.actor
	var delta: int = 0
	match result.action:
		Enums.ActionType.REST:
			delta += REST_LOSS
		Enums.ActionType.RETREAT:
			delta += RETREAT_LOSS
		Enums.ActionType.DEFEND:
			# Turtling only counts once the fighter's OWN anti-stall counter
			# says so — one stall detector for the whole game (V2 §54).
			if actor.consecutive_defends >= TURTLE_AFTER_DEFENDS:
				delta += TURTLE_LOSS
		_:
			pass

	if result.hit:
		if result.crit:
			delta += CRIT_GAIN
		if result.skill != null:
			delta += SKILL_GAIN + result.skill.crowd_appeal
			if actor.current_hp <= roundi(actor.max_hp * DESPERATE_HP_FRACTION):
				delta += DESPERATE_GAIN
		if result.killed:
			delta += KILL_GAIN

	if round_number > LONG_FIGHT_ROUND:
		delta += LONG_FIGHT_LOSS
	return delta


## The defender's share: a guard that held, or a dodge that made the pit gasp.
static func defender_delta(result: ActionResult) -> int:
	if result.target == null or result.hit:
		return 0
	if result.target.stance == Enums.Stance.DEFENDING:
		return GUARD_HELD_GAIN
	return 0
