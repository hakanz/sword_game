class_name StatusEffectData
extends Resource
## Static definition of a status effect (charter §18): ONE generic model,
## never bespoke code per effect. All numeric fields are per-stack.
## Periodic damage ticks at the END of the afflicted fighter's turn and goes
## straight to HP (DoTs seep past armour by design — see docs/combat.md);
## the victim's resistance to the damage type still applies.

@export var id: StringName
@export var name_key: String = ""
@export_range(1, 20) var duration_rounds: int = 3
@export_range(1, 10) var max_stacks: int = 1

@export_group("Per-Turn Effects")
@export_range(0, 100) var periodic_damage: int = 0
@export var periodic_damage_type: Enums.DamageType = Enums.DamageType.POISON
@export_range(0, 100) var periodic_heal: int = 0

@export_group("Stat Modifiers (while active)")
@export_range(-50, 50) var accuracy_mod: int = 0
@export_range(-50, 50) var defence_mod: int = 0
@export_range(-50, 50) var evasion_mod: int = 0
## Multiplier on damage DEALT by the bearer (stacks multiply).
@export_range(0.25, 3.0) var damage_dealt_mult: float = 1.0
## Stun-type effects: the bearer loses their action entirely.
@export var skips_turn: bool = false

@export_group("Presentation")
## Placeholder icon/tint color until real icons exist (charter §27).
@export var tint: Color = Color(0.6, 0.9, 0.4)
