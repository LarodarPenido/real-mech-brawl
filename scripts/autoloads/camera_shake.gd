extends Node

var active_camera: Camera3D = null
var active_shakes: Array[Dictionary] = []
var last_offset := Vector3.ZERO

var current_offset := Vector3.ZERO
var _active_shakes: Array[Dictionary] = []

@export var max_distance: float = 500.0
@export var min_distance: float = 80.0
@export var distance_curve_power: float = 2.0
@export var global_intensity: float = 1.0 # later connect to settings
@onready var player: CharacterBody3D

func _ready() -> void:
	active_camera = get_tree().get_first_node_in_group("camera")
	player = get_tree().get_first_node_in_group("player")
	#print(active_camera)

func shake(intensity: float, duration: float) -> void:
	_active_shakes.append({
		"intensity": intensity,
		"duration": duration,
		"remaining": duration,
	})


func _process(delta: float) -> void:
	# Tick down and remove expired
	for i in range(_active_shakes.size() - 1, -1, -1):
		_active_shakes[i].remaining -= delta
		if _active_shakes[i].remaining <= 0.0:
			_active_shakes.remove_at(i)

	# Sum offsets from all active shakes
	var offset := Vector3.ZERO
	for s in _active_shakes:
		var t: float = s.remaining / s.duration  # 1→0 fade
		var strength: float = s.intensity * t
		offset += Vector3(
			randf_range(-strength, strength),
			randf_range(-strength, strength),
			randf_range(-strength, strength),
		)

	current_offset = offset

func shake_at_position(world_pos: Vector3, base_strength: float, duration: float = 0.2) -> void:
	#if not GameState.player:
		#return

	var player_pos: Vector3 = player.global_position
	var distance: float = player_pos.distance_to(world_pos)

	var falloff: float = _get_distance_falloff(distance)
	var final_strength: float = base_strength * falloff * global_intensity

	if final_strength <= 0.01:
		return

	shake(final_strength, duration)


func _get_distance_falloff(distance: float) -> float:
	if distance <= min_distance:
		return 1.0

	if distance >= max_distance:
		return 0.0

	var t: float = inverse_lerp(min_distance, max_distance, distance)
	t = clamp(t, 0.0, 1.0)

	# Smooth nonlinear falloff.
	return pow(1.0 - t, distance_curve_power)
