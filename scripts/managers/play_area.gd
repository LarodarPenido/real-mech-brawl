extends StaticBody3D

@export var player: CharacterBody3D
@export var level_advancement_speed: float = 10
@export var limit_position: float = 200

func _process(delta: float) -> void:
	if global_position.z > player.global_position.z and global_position.z < limit_position:
		global_position.z = move_toward(global_position.z, player.global_position.z, delta * level_advancement_speed)
