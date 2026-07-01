extends Control


@onready var master_slider: HSlider = $Panel/VBoxContainer/MasterVolume/MasterSlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicVolume/MusicSlider
@onready var effects_slider: HSlider = $Panel/VBoxContainer/EffectsVolume/EffectsSlider

var is_showing: bool = false

func _ready() -> void:
	hide()

func open() -> void:
	if not is_showing:
		show()
		is_showing = true
		get_tree().paused = true
	else:
		hide()
		is_showing = false
		get_tree().paused = false
		
func _on_back_button_button_up() -> void:
	hide()
	is_showing = false
	get_tree().paused = false

func _on_master_slider_value_changed(value: float) -> void:
	Audio.set_bus_volume("Master", value)


func _on_music_slider_value_changed(value: float) -> void:
	Audio.set_bus_volume("Music", value)


func _on_effects_slider_value_changed(value: float) -> void:
	Audio.set_bus_volume("SFX", value)
