@tool
extends Camera3D
@onready var player: CharacterBody3D = $"../Player"


func _process(delta: float) -> void:
	look_at(player.global_position)
