extends Node3D


@export var options_overlay: Control

func _on_play_button_button_up() -> void:
	SceneManager.go_to("res://scenes/level_01.tscn")


func _on_options_button_button_up() -> void:
	if options_overlay:
		options_overlay.open()


func _on_quit_button_button_up() -> void:
	get_tree().quit()
