class_name CombatVfx
## Placeholder combat VFX from engine primitives (charter §27) — impact
## sparks and dust puffs as one-shot CPUParticles2D (Compatibility-safe,
## no shaders). Deliberately uses NO gameplay RNG: visuals must never
## consume RngService rolls or seeded replays would diverge.


## Impact sparks (hits) or a soft dust puff (dodges) at a world position.
static func spawn_sparks(
		parent: Node, pos: Vector2, color: Color,
		amount: int = 14, soft: bool = false) -> void:
	if bool(SaveManager.get_setting(CombatFeel.REDUCED_FX_SETTING, false)):
		amount = maxi(4, amount / 2)
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = 0.5 if soft else 0.4
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 170.0
	particles.initial_velocity_min = 40.0 if soft else 160.0
	particles.initial_velocity_max = 90.0 if soft else 300.0
	particles.gravity = Vector2(0, 300 if soft else 750)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	particles.color = color
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Element-flavored burst for a skill, keyed by the status it applies
## (session-5 owner design: a flame skill LOOKS like flame). Falls back to a
## tinted burst for statuses without a bespoke shape.
static func spawn_status_burst(parent: Node, pos: Vector2, status: StatusEffectData) -> void:
	var id: String = String(status.id)
	if id.contains("burn") or id.contains("ember"):
		_spawn_shaped(parent, pos, status.tint, Vector2.UP, 24, 16.0,
				Vector2(60, 130), Vector2(0, -240), 0.55)  # licking flames rise
	elif id.contains("poison") or id.contains("venom"):
		_spawn_shaped(parent, pos, status.tint, Vector2.DOWN, 16, 55.0,
				Vector2(30, 80), Vector2(0, 420), 0.6)  # dripping venom
	elif id.contains("bleed"):
		_spawn_shaped(parent, pos, status.tint, Vector2.DOWN, 14, 35.0,
				Vector2(60, 140), Vector2(0, 600), 0.45)  # spatter
	elif id.contains("stun"):
		_spawn_shaped(parent, pos + Vector2(0, -30), status.tint, Vector2.UP, 10, 80.0,
				Vector2(30, 60), Vector2(0, -60), 0.7)  # dazed motes over the head
	else:
		spawn_sparks(parent, pos, status.tint, 14, true)


## White swing-arc streak at the impact point — the "cut" of a melee blow.
static func spawn_slash(parent: Node, pos: Vector2, toward_left: bool) -> void:
	var arc := SlashArc.new()
	arc.position = pos
	arc.flip = toward_left
	parent.add_child(arc)


static func _spawn_shaped(
		parent: Node, pos: Vector2, color: Color, direction: Vector2,
		amount: int, spread: float, velocity: Vector2, gravity: Vector2,
		lifetime: float) -> void:
	if bool(SaveManager.get_setting(CombatFeel.REDUCED_FX_SETTING, false)):
		amount = maxi(4, amount / 2)
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.9
	particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = velocity.x
	particles.initial_velocity_max = velocity.y
	particles.gravity = gravity
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.0
	particles.color = color
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


class SlashArc:
	extends Node2D
	## One-shot crescent streak that sweeps alpha out in ~0.2s.

	var flip: bool = false

	func _ready() -> void:
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.22) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(self, "scale", Vector2(1.25, 1.25), 0.22)
		tween.tween_callback(queue_free)

	func _draw() -> void:
		var sweep_start: float = -PI * 0.75 if flip else -PI * 0.25
		var sweep_end: float = -PI * 0.25 if flip else PI * 0.25
		draw_arc(Vector2.ZERO, 42.0, sweep_start, sweep_end, 18,
				Color(1.0, 0.98, 0.9, 0.85), 7.0)
		draw_arc(Vector2.ZERO, 42.0, sweep_start, sweep_end, 18,
				Color(1.0, 0.85, 0.4, 0.4), 13.0)
