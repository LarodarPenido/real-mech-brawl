extends Node3D


enum State { VICTORY, DEFEAT }

var state: State = State.VICTORY

@export var play_button: Button
@export var quit_button: Button

@export var defeat_mech: MeshInstance3D
@export var victory_mech: Node3D

@onready var player: CharacterBody3D


func _process(delta: float) -> void:
	if RunState.victory:
		state = State.VICTORY
	else:
		state = State.DEFEAT
	
	match state:
		State.VICTORY:
			play_button.text = "PLAY AGAIN"
			defeat_mech.hide()
			victory_mech.show()
			## TODO victory music
		State.DEFEAT:
			play_button.text = "RETRY"
			defeat_mech.show()
			victory_mech.hide()

func _on_quit_button_button_up() -> void:
	get_tree().quit()


func _on_play_button_button_up() -> void:
	SceneManager.go_to("res://scenes/level_01.tscn")
