extends Node
## Audio playback + bus volume management (charter §26).
## Buses: Master, Music, SFX, UI, Voice, Ambience (audio/default_bus_layout.tres).
## Volumes persist via SaveManager settings.
##
## NOTE (asset pipeline, charter §27): no final audio exists yet. This service
## is fully functional but plays nothing until placeholder/final streams are
## registered. Web export: browsers block autoplay until a user gesture —
## never rely on music starting before the first click/tap.

const BUSES: PackedStringArray = ["Master", "Music", "SFX", "UI", "Voice", "Ambience"]


func _ready() -> void:
	for bus in BUSES:
		var saved: float = SaveManager.get_setting("volume_%s" % bus.to_lower(), 1.0)
		set_bus_volume(bus, saved)
	# Global UI click: every button in the game clicks, no per-scene wiring.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(func() -> void: play(&"click", "UI"))


## Plays a named synthesized cue (see SfxLibrary) on the given bus.
func play(sfx_name: StringName, bus: String = "SFX", volume_db: float = 0.0) -> void:
	play_sfx(SfxLibrary.get_stream(sfx_name), bus, volume_db)


## `linear` is 0.0-1.0; persisted and applied to the audio server bus.
func set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("AudioManager: unknown bus '%s'" % bus_name)
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0)
	SaveManager.set_setting("volume_%s" % bus_name.to_lower(), linear)


func get_bus_volume(bus_name: String) -> float:
	return SaveManager.get_setting("volume_%s" % bus_name.to_lower(), 1.0)


## Plays a one-shot sound on the given bus. Returns the player node so
## callers may track it; the node frees itself when done.
func play_sfx(stream: AudioStream, bus: String = "SFX", volume_db: float = 0.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
