extends CanvasLayer

@export var fade_time: float = 0.3
@onready var _fade: ColorRect = $Fade
var _busy: bool = false

func _ready() -> void:
	_fade.color.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func go_to(path: String) -> void:
	if _busy:
		return  # guard against double-clicks firing two swaps
	_busy = true

	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, fade_time)
	await t.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame  # let the new scene become current before fading in

	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, fade_time)
	await t2.finished

	_busy = false
