class_name CombatVfx
## Combat VFX (charter §25). Every effect is a one-shot CPUParticles2D or a
## short self-freeing Node2D — Compatibility-safe, no shaders.
##
## Each one draws with a painted sprite from `ArtLibrary` when the generated
## art is installed and with flat coloured points when it is not, so the whole
## layer degrades to the original primitive look rather than disappearing.
##
## Deliberately uses NO gameplay RNG: visuals must never consume RngService
## rolls or seeded replays would diverge.

## Blood is separately toggleable per charter §25/§30 — some players want the
## hits without the spray, and the setting must not also flatten every other
## effect the way `reduced_fx` does.
const BLOOD_SETTING := "vfx_blood"
const BLOOD_DEFAULT: bool = true


static func blood_enabled() -> bool:
	return bool(SaveManager.get_setting(BLOOD_SETTING, BLOOD_DEFAULT))


static func _reduced() -> bool:
	return bool(SaveManager.get_setting(CombatFeel.REDUCED_FX_SETTING, false))


## Impact sparks (hits) or a soft dust puff (dodges) at a world position.
static func spawn_sparks(
		parent: Node, pos: Vector2, color: Color,
		amount: int = 14, soft: bool = false) -> void:
	_emit(parent, pos, color, amount,
			ArtLibrary.vfx(&"dust_puff" if soft else &"spark"),
			Vector2.UP, 170.0,
			Vector2(40, 90) if soft else Vector2(160, 300),
			Vector2(0, 300 if soft else 750),
			0.5 if soft else 0.4,
			Vector2(2.0, 4.5), Vector2(0.14, 0.3))


## Blood spray from a wound (charter §25 "blood particles, toggleable"). Silent
## no-op when the player has turned blood off — the hit still lands, it just
## does not bleed.
static func spawn_blood(parent: Node, pos: Vector2, toward_left: bool,
		amount: int = 16) -> void:
	if not blood_enabled():
		return
	var away: Vector2 = Vector2.LEFT if toward_left else Vector2.RIGHT
	_emit(parent, pos, Color(0.62, 0.06, 0.09), amount,
			ArtLibrary.vfx(&"blood_drop"), (away + Vector2.UP * 0.6).normalized(),
			55.0, Vector2(120, 280), Vector2(0, 900), 0.55,
			Vector2(2.0, 4.0), Vector2(0.1, 0.24))
	var splatter: Texture2D = ArtLibrary.vfx(&"blood_splatter")
	if splatter != null and not _reduced():
		_flash(parent, pos, splatter, 78.0, 0.34, away.x < 0.0,
				Color(1.0, 1.0, 1.0, 0.85))


## Shield impact (charter §25): a guarded fighter taking the blow on their
## guard — a hard ring of force rather than a spray.
static func spawn_block_impact(parent: Node, pos: Vector2) -> void:
	var ring: Texture2D = ArtLibrary.vfx(&"shield_impact")
	if ring != null:
		_flash(parent, pos, ring, 96.0, 0.28, false, Color(0.78, 0.88, 1.0, 0.9))
	else:
		var arc := ImpactRing.new()
		arc.position = pos
		arc.tint = Color(0.75, 0.86, 1.0, 0.85)
		parent.add_child(arc)
	_emit(parent, pos, Color(0.8, 0.9, 1.0), 10, ArtLibrary.vfx(&"spark"),
			Vector2.UP, 150.0, Vector2(90, 200), Vector2(0, 500), 0.32,
			Vector2(1.6, 3.4), Vector2(0.1, 0.22))


## Armour break (charter §25): the pool the fighter was hiding behind is gone,
## and the plates come off with it.
static func spawn_armour_break(parent: Node, pos: Vector2) -> void:
	_emit(parent, pos, Color(0.72, 0.76, 0.84), 18,
			ArtLibrary.vfx(&"armour_shard"), Vector2.UP, 165.0,
			Vector2(140, 320), Vector2(0, 900), 0.7,
			Vector2(2.4, 5.0), Vector2(0.16, 0.34))
	var burst: Texture2D = ArtLibrary.vfx(&"crit_burst")
	if burst != null and not _reduced():
		_flash(parent, pos, burst, 88.0, 0.26, false, Color(0.85, 0.9, 1.0, 0.75))


## Critical hit (charter §25): a starburst on the connecting frame, on top of
## the sparks the ordinary blow already threw.
static func spawn_crit_burst(parent: Node, pos: Vector2) -> void:
	var burst: Texture2D = ArtLibrary.vfx(&"crit_burst")
	if burst != null:
		_flash(parent, pos, burst, 132.0, 0.3, false, Color(1.0, 0.9, 0.7, 0.95))
	else:
		var ring := ImpactRing.new()
		ring.position = pos
		ring.tint = Color(1.0, 0.7, 0.25, 0.9)
		parent.add_child(ring)


## Level-up (charter §25): a column of light with motes riding up it.
static func spawn_level_up(parent: Node, pos: Vector2) -> void:
	var ray: Texture2D = ArtLibrary.vfx(&"levelup_ray")
	if ray != null:
		_flash(parent, pos + Vector2(0, -40), ray, 170.0, 0.9, false,
				Color(1.0, 0.9, 0.55, 0.9))
	_emit(parent, pos, Color(1.0, 0.86, 0.45), 26, ArtLibrary.vfx(&"heal_mote"),
			Vector2.UP, 22.0, Vector2(120, 220), Vector2(0, -60), 1.0,
			Vector2(2.5, 5.0), Vector2(0.2, 0.4))


## Crowd swell (V2 §54): warm light washing across the fighter as the stands
## come alive for them.
static func spawn_crowd_flare(parent: Node, pos: Vector2, warm: bool) -> void:
	var flare: Texture2D = ArtLibrary.vfx(&"crowd_flare")
	if flare == null or _reduced():
		return
	_flash(parent, pos, flare, 260.0, 0.55, false,
			Color(1.0, 0.82, 0.42, 0.55) if warm else Color(0.45, 0.45, 0.62, 0.5))


## Element-flavored burst for a skill, keyed by the status it applies
## (session-5 owner design: a flame skill LOOKS like flame). Falls back to a
## tinted burst for statuses without a bespoke shape.
static func spawn_status_burst(parent: Node, pos: Vector2, status: StatusEffectData) -> void:
	var id: String = String(status.id)
	if id.contains("burn") or id.contains("ember"):
		_emit(parent, pos, status.tint, 24, ArtLibrary.vfx(&"fire_wisp"),
				Vector2.UP, 16.0, Vector2(60, 130), Vector2(0, -240), 0.55,
				Vector2(2.5, 5.0), Vector2(0.18, 0.36))  # licking flames rise
	elif id.contains("poison") or id.contains("venom"):
		_emit(parent, pos, status.tint, 16, ArtLibrary.vfx(&"poison_bubble"),
				Vector2.DOWN, 55.0, Vector2(30, 80), Vector2(0, 420), 0.6,
				Vector2(2.5, 5.0), Vector2(0.14, 0.3))  # dripping venom
	elif id.contains("bleed"):
		spawn_blood(parent, pos, false, 14)  # spatter, and it respects the toggle
	elif id.contains("stun"):
		_emit(parent, pos + Vector2(0, -30), status.tint, 10,
				ArtLibrary.vfx(&"stun_star"), Vector2.UP, 80.0,
				Vector2(30, 60), Vector2(0, -60), 0.7,
				Vector2(2.5, 5.0), Vector2(0.2, 0.4))  # dazed motes overhead
	elif id.contains("slow") or id.contains("frost") or id.contains("chill"):
		_emit(parent, pos, status.tint, 14, ArtLibrary.vfx(&"frost_shard"),
				Vector2.DOWN, 70.0, Vector2(20, 70), Vector2(0, 200), 0.7,
				Vector2(2.5, 5.0), Vector2(0.16, 0.32))
	elif id.contains("regen") or id.contains("heal"):
		_emit(parent, pos, status.tint, 16, ArtLibrary.vfx(&"heal_mote"),
				Vector2.UP, 30.0, Vector2(50, 110), Vector2(0, -140), 0.8,
				Vector2(2.5, 5.0), Vector2(0.16, 0.34))
	elif id.contains("rage") or id.contains("weak") or id.contains("hex"):
		_emit(parent, pos, status.tint, 18, ArtLibrary.vfx(&"arcane_rune"),
				Vector2.UP, 100.0, Vector2(40, 110), Vector2(0, -80), 0.7,
				Vector2(2.0, 4.0), Vector2(0.2, 0.42))
	else:
		spawn_sparks(parent, pos, status.tint, 14, true)


## Damage-type flourish on a landed elemental blow (charter §25's fire / ice /
## lightning / poison list). Physical damage types deliberately get nothing —
## they already have sparks and a slash arc.
static func spawn_element_hit(parent: Node, pos: Vector2,
		damage_type: Enums.DamageType) -> void:
	match damage_type:
		Enums.DamageType.FIRE:
			_emit(parent, pos, Color(1.0, 0.6, 0.2), 16,
					ArtLibrary.vfx(&"fire_wisp"), Vector2.UP, 40.0,
					Vector2(70, 170), Vector2(0, -200), 0.45,
					Vector2(2.5, 5.0), Vector2(0.18, 0.36))
		Enums.DamageType.FROST:
			_emit(parent, pos, Color(0.6, 0.9, 1.0), 14,
					ArtLibrary.vfx(&"frost_shard"), Vector2.UP, 150.0,
					Vector2(60, 150), Vector2(0, 380), 0.5,
					Vector2(2.2, 4.5), Vector2(0.14, 0.3))
		Enums.DamageType.LIGHTNING:
			var bolt: Texture2D = ArtLibrary.vfx(&"lightning_bolt")
			if bolt != null:
				_flash(parent, pos + Vector2(0, -30), bolt, 120.0, 0.18, false,
						Color(0.8, 0.9, 1.0, 0.95))
			_emit(parent, pos, Color(0.75, 0.88, 1.0), 12,
					ArtLibrary.vfx(&"spark"), Vector2.UP, 170.0,
					Vector2(180, 340), Vector2(0, 400), 0.3,
					Vector2(1.8, 3.6), Vector2(0.1, 0.22))
		Enums.DamageType.ARCANE:
			var rune: Texture2D = ArtLibrary.vfx(&"arcane_rune")
			if rune != null:
				_flash(parent, pos, rune, 104.0, 0.36, false,
						Color(0.8, 0.6, 1.0, 0.85))
		Enums.DamageType.POISON:
			_emit(parent, pos, Color(0.5, 0.9, 0.35), 12,
					ArtLibrary.vfx(&"poison_bubble"), Vector2.DOWN, 60.0,
					Vector2(40, 110), Vector2(0, 420), 0.5,
					Vector2(2.2, 4.5), Vector2(0.14, 0.3))
		_:
			pass


## White swing-arc streak at the impact point — the "cut" of a melee blow.
static func spawn_slash(parent: Node, pos: Vector2, toward_left: bool) -> void:
	var painted: Texture2D = ArtLibrary.vfx(&"slash_arc")
	if painted != null:
		_flash(parent, pos, painted, 128.0, 0.22, toward_left,
				Color(1.0, 0.97, 0.88, 0.92))
		return
	var arc := SlashArc.new()
	arc.position = pos
	arc.flip = toward_left
	parent.add_child(arc)


## One-shot particle burst. `sprite` may be null — CPUParticles2D then draws
## its default points, which is exactly the pre-art look.
static func _emit(
		parent: Node, pos: Vector2, color: Color, amount: int,
		sprite: Texture2D, direction: Vector2, spread: float,
		velocity: Vector2, gravity: Vector2, lifetime: float,
		point_scale: Vector2, sprite_scale: Vector2) -> void:
	if _reduced():
		amount = maxi(4, amount / 2)
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.95
	particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = velocity.x
	particles.initial_velocity_max = velocity.y
	particles.gravity = gravity
	particles.color = color
	if sprite != null:
		particles.texture = sprite
		# A sprite is scaled as a FRACTION of its own pixel size; a bare point
		# is scaled in pixels. The two numbers are not interchangeable.
		particles.scale_amount_min = sprite_scale.x
		particles.scale_amount_max = sprite_scale.y
		particles.angle_min = -180.0
		particles.angle_max = 180.0
		# The painted art carries its own colour; tinting it again muddies it.
		particles.color = Color(1, 1, 1, color.a)
	else:
		particles.scale_amount_min = point_scale.x
		particles.scale_amount_max = point_scale.y
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## One painted sprite that pops, fades and frees itself — the shape-based half
## of the VFX set (rings, bursts, arcs, rays).
static func _flash(parent: Node, pos: Vector2, texture: Texture2D, width: float,
		seconds: float, flip: bool, tint: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = pos
	sprite.modulate = tint
	sprite.flip_h = flip
	var size: Vector2 = texture.get_size()
	if size.x <= 0.0:
		return
	var base: float = width / size.x
	sprite.scale = Vector2(base, base) * 0.8
	parent.add_child(sprite)
	var tween: Tween = sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(base, base) * 1.15, seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(sprite.queue_free)


class SlashArc:
	extends Node2D
	## One-shot crescent streak that sweeps alpha out in ~0.2s. The drawn
	## fallback for `spawn_slash` when no painted arc is installed.

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


class ImpactRing:
	extends Node2D
	## Expanding ring — the drawn fallback for the block and crit flashes.

	var tint: Color = Color(1.0, 0.9, 0.6, 0.9)

	func _ready() -> void:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.26) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, 0.26)
		tween.chain().tween_callback(queue_free)

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 28, tint, 6.0)
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(tint, tint.a * 0.5), 3.0)
