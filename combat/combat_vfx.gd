class_name CombatVfx
## Placeholder combat VFX from engine primitives (charter §27) — impact
## sparks and dust puffs as one-shot CPUParticles2D (Compatibility-safe,
## no shaders). Deliberately uses NO gameplay RNG: visuals must never
## consume RngService rolls or seeded replays would diverge.


## Impact sparks (hits) or a soft dust puff (dodges) at a world position.
static func spawn_sparks(
		parent: Node, pos: Vector2, color: Color,
		amount: int = 14, soft: bool = false) -> void:
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
