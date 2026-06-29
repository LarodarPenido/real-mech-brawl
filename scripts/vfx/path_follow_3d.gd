extends PathFollow3D

@onready var progress_speed: float = 0.5

func _process(delta: float) -> void:
	progress += progress_speed * delta
