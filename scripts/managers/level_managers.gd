extends Node3D

class_name GameManager

@onready var ending_scene: Node



func _ready() -> void:
	ending_scene = get_tree().get_first_node_in_group("ending")

func _on_wave_manager_all_waves_cleared() -> void:
	RunState.victory = true
	SceneManager.go_to("res://scenes/ending.tscn")

func _on_player_game_over() -> void:
	RunState.victory = false
	SceneManager.go_to("res://scenes/ending.tscn")
