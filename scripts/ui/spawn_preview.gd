extends SpringArm3D

func _ready() -> void:
	print("wave spawn indicator exists at: ", global_position)
	global_position = get_parent().global_position
	print("wave spawn repositioned to: ", global_position)
