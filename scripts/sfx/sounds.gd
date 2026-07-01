## This project's sound roster. Assign each stream in the inspector (on sounds.tscn),
## then call them by name from anywhere, e.g. Audio.play_sfx(Sounds.gun, 5).
## Registered as the "Sounds" autoload (scene: sounds.tscn) so it's editor-editable.
extends Node

@export_group("Movement")
@export var dash: AudioStream
#@export var servos: AudioStream
@export var footstep: AudioStream

@export_group("Machinery")
@export var coolant: AudioStream
@export var heal: AudioStream
@export var reload: AudioStream


@export_group("Weapons")
@export var machine_gun_01: AudioStream
@export var missile_launch: AudioStream
@export var impact: AudioStream

@export_group("Combat")
@export var explosion_01: AudioStream
@export var explosion_02: AudioStream



@export_group("Ambience")
@export var wind: AudioStream
@export var jets: AudioStream
@export var distant_gunfire: AudioStream

@export_group("UI")
@export var alarm: AudioStream
@export var hover_button: AudioStream
@export var click_button: AudioStream
@export var confirm: AudioStream
@export var cancel: AudioStream



func get_all_streams() -> Array[AudioStream]:
	return [
		dash,
		footstep,

		coolant,
		heal,
		reload,

		machine_gun_01,
		missile_launch,
		impact,

		explosion_01,
		explosion_02,

		wind,
		jets,
		distant_gunfire,

		alarm,
		hover_button,
		click_button,
		confirm,
		cancel,
	].filter(func(stream: AudioStream) -> bool:
		return stream != null
	)
