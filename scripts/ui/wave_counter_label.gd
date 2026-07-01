extends Label

@export var wave_spawner: Node3D

func _ready() -> void:
	if wave_spawner == null:
		wave_spawner = get_tree().get_first_node_in_group("wave_spawner")

	if wave_spawner == null:
		text = "WAVE -/-"
		return

	wave_spawner.wave_started.connect(_on_wave_started)
	wave_spawner.wave_cleared.connect(_on_wave_cleared)
	wave_spawner.all_waves_cleared.connect(_on_all_waves_cleared)

	_update_text()


func _on_wave_started(_wave_number: int) -> void:
	_update_text()


func _on_wave_cleared(_wave_number: int) -> void:
	_update_text()


func _on_all_waves_cleared() -> void:
	text = "WAVES CLEARED"


func _update_text() -> void:
	text = wave_spawner.get_wave_counter_text()
