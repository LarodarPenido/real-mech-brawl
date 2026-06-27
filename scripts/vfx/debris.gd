extends MeshInstance3D

var min_scale: float = 0.0
var max_scale: float = 2.0

var min_rotation: float = 0.0
var max_rotation: float = 359.0


var min_position: float = -1.0
var max_position: float = 1.0


func _ready() -> void:
	randomize_scale()
	randomize_rotation()
	randomize_position()
	
func randomize_scale():
	scale = Vector3(randf_range(min_scale, max_scale), randf_range(min_scale, max_scale), randf_range(min_scale, max_scale))

func randomize_rotation():
	rotation = Vector3(randf_range(min_rotation, max_rotation), randf_range(min_rotation, max_rotation), randf_range(min_rotation, max_rotation))

func randomize_position():
	position = Vector3(randf_range(min_position, max_position), global_position.y, randf_range(min_position, max_position))
