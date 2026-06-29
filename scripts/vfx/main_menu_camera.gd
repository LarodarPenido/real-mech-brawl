@tool
extends Camera3D
@onready var player: Node3D = $"../../../PosedMechWithPilot"


func _process(delta: float) -> void:
	look_at(player.global_position)
