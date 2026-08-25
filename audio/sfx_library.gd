class_name SfxLibrary
## Procedurally synthesized placeholder SFX (charter §27: ship placeholder
## audio, never block on final assets). Every cue is generated at runtime as
## an AudioStreamWAV — zero external files, works on every export target.
## Real foley replaces these via docs/ASSET_MANIFEST.md; AudioManager.play()
## call sites stay unchanged when it does.

const SAMPLE_RATE: int = 22050

static var _cache: Dictionary = {}


static func get_stream(sfx_name: StringName) -> AudioStreamWAV:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var samples: PackedFloat32Array
	match sfx_name:
		&"hit":
			samples = _mix([_noise_burst(0.14, 8.0), _sine_sweep(0.14, 95.0, 70.0, 9.0, 0.9)])
		&"crit":
			# Heavier, longer, with a ringing overtone — a blow that lands HARD.
			samples = _mix([
				_noise_burst(0.22, 6.0), _sine_sweep(0.22, 130.0, 55.0, 6.0, 1.0),
				_tone(0.2, 1560.0, 10.0, 0.22),
			])
		&"armour_hit":
			samples = _mix([
				_tone(0.16, 1150.0, 14.0, 0.45), _tone(0.16, 1780.0, 18.0, 0.3),
				_noise_burst(0.03, 30.0),
			])
		&"miss":
			samples = _whoosh(0.22)
		&"arrow":
			samples = _mix([_sine_sweep(0.18, 950.0, 280.0, 10.0, 0.4), _noise_burst(0.05, 40.0, 0.3)])
		&"switch":
			samples = _mix([_tone(0.08, 620.0, 26.0, 0.4), _noise_burst(0.04, 45.0, 0.25)])
		&"skill":
			samples = _mix([_sine_sweep(0.26, 330.0, 70.0, 6.0, 0.8), _noise_burst(0.1, 12.0)])
		&"buff":
			samples = _note_run([440.0, 554.0, 659.0], 0.11)
		&"death":
			samples = _sine_sweep(0.5, 210.0, 52.0, 3.5, 0.85)
		&"step":
			samples = _noise_burst(0.05, 40.0, 0.25)
		&"click":
			samples = _tone(0.035, 1900.0, 70.0, 0.35)
		&"coin":
			samples = _mix([_tone(0.12, 1320.0, 16.0, 0.4), _tone(0.12, 1980.0, 20.0, 0.25)])
		&"victory":
			samples = _note_run([392.0, 494.0, 587.0, 784.0], 0.14)
		&"crowd_roar":
			# A pit going up: filtered noise swelling under two shouted
			# overtones. Long and soft so it sits BEHIND the impact cues.
			samples = _mix([
				_swell(0.9), _tone(0.55, 210.0, 2.2, 0.12), _tone(0.5, 320.0, 2.6, 0.09),
			])
		&"crowd_groan":
			# The same crowd losing interest: a short downward mutter.
			samples = _mix([_swell(0.5, 0.55), _sine_sweep(0.45, 190.0, 120.0, 3.0, 0.14)])
		&"defeat":
			samples = _note_run([330.0, 262.0, 196.0], 0.2)
		_:
			push_warning("SfxLibrary: unknown sfx '%s'" % sfx_name)
			samples = _tone(0.05, 440.0, 30.0, 0.2)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = _to_pcm16(samples)
	_cache[sfx_name] = stream
	return stream


# --- Synth building blocks --------------------------------------------------

## White noise with exponential decay.
static func _noise_burst(duration: float, decay: float, amplitude: float = 0.7) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337  # fixed: identical placeholder cue every launch
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t: float = float(i) / SAMPLE_RATE
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-decay * t) * amplitude
	return out


## Single sine with exponential decay.
static func _tone(duration: float, hz: float, decay: float, amplitude: float) -> PackedFloat32Array:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t: float = float(i) / SAMPLE_RATE
		out[i] = sin(TAU * hz * t) * exp(-decay * t) * amplitude
	return out


## Sine sweeping from hz_from down/up to hz_to with exponential decay.
static func _sine_sweep(
		duration: float, hz_from: float, hz_to: float,
		decay: float, amplitude: float) -> PackedFloat32Array:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / SAMPLE_RATE
		var hz: float = lerpf(hz_from, hz_to, t / duration)
		phase += TAU * hz / SAMPLE_RATE
		out[i] = sin(phase) * exp(-decay * t) * amplitude
	return out


## Heavily low-passed noise under a slow rise-and-fall envelope — a crowd,
## not a swing: no transient, just a swell.
static func _swell(duration: float, amplitude: float = 1.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var filtered: float = 0.0
	for i in count:
		var t: float = float(i) / SAMPLE_RATE
		filtered += (rng.randf_range(-1.0, 1.0) - filtered) * 0.045
		out[i] = filtered * pow(sin(PI * t / duration), 1.6) * 2.4 * amplitude
	return out


## Low-passed noise with a sine envelope — reads as a swing/whoosh.
static func _whoosh(duration: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var filtered: float = 0.0
	for i in count:
		var t: float = float(i) / SAMPLE_RATE
		filtered += (rng.randf_range(-1.0, 1.0) - filtered) * 0.18
		out[i] = filtered * sin(PI * t / duration) * 1.6
	return out


## Short ascending/descending note sequence (each note decays).
static func _note_run(notes: Array, note_duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note: float in notes:
		out.append_array(_tone(note_duration, note, 9.0, 0.5))
	return out


## Sums layers (padded to the longest) with soft clipping.
static func _mix(layers: Array) -> PackedFloat32Array:
	var length: int = 0
	for layer: PackedFloat32Array in layers:
		length = maxi(length, layer.size())
	var out := PackedFloat32Array()
	out.resize(length)
	for layer: PackedFloat32Array in layers:
		for i in layer.size():
			out[i] += layer[i]
	for i in length:
		out[i] = clampf(out[i], -1.0, 1.0)
	return out


static func _to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	return bytes
