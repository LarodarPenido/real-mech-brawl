@tool
extends Camera3D
@export var player: Node3D


func _process(delta: float) -> void:
	if player:
		look_at(player.global_position)
