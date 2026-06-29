extends Node
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $"."


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		audio_stream_player_3d.play()
