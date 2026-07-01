extends Node3D

@export var sfx_bus_name: String = "SFX"
@export var audio_warmup_time: float = 0.08

@export var load_duration: float = 2.0

@onready var button: Button = $TextureRect/Button

func _ready() -> void:
	_prewarm_sounds()
	await  get_tree().create_timer(load_duration).timeout
	button.show()

func _on_button_button_up() -> void:
	SceneManager.go_to("res://scenes/level_01.tscn")


func _prewarm_sounds() -> void:
	var bus_index := AudioServer.get_bus_index("SFX")

	if bus_index == -1:
		push_warning("Audio bus not found: %s" % "SFX")
		return

	var was_muted := AudioServer.is_bus_mute(bus_index)

	AudioServer.set_bus_mute(bus_index, true)

	var players: Array[AudioStreamPlayer] = []

	for stream in Sounds.get_all_streams():
		var player := AudioStreamPlayer.new()
		add_child(player)

		player.bus = sfx_bus_name
		player.stream = stream
		player.volume_db = 0.0
		player.play()

		players.append(player)

	# Let Godot initialize/play/decode the sounds for a moment.
	await get_tree().create_timer(audio_warmup_time).timeout

	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()

	AudioServer.set_bus_mute(bus_index, was_muted)
