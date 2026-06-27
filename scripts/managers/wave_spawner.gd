extends Node

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal all_waves_cleared()

@export var enemy_scene: PackedScene
@export var enemy_parent: Node3D
@export var spawn_points_parent: Node3D
@export var enemy_manager: Node

@export var start_delay: float = 1.0
@export var time_between_waves: float = 2.0
@export var time_between_spawns: float = 0.25
@export var auto_start: bool = true

# Tiny jam-friendly wave table.
# Each entry is: enemy count for that wave.
@export var waves: Array[int] = [2, 3, 4, 5, 6]

var _wave_index: int = -1
var _running: bool = false
var _spawn_points: Array[Marker3D] = []


func _ready() -> void:
	_cache_spawn_points()

	if auto_start:
		await get_tree().create_timer(start_delay).timeout
		start_waves()


func _process(_delta: float) -> void:
	if not _running:
		return

	if enemy_manager == null:
		return

	if enemy_manager.enemies.size() > 0:
		return

	_finish_current_wave()


func start_waves() -> void:
	if _running:
		return

	if enemy_scene == null:
		push_warning("WaveSpawner: enemy_scene is not assigned.")
		return

	if enemy_parent == null:
		push_warning("WaveSpawner: enemy_parent is not assigned.")
		return

	if spawn_points_parent == null:
		push_warning("WaveSpawner: spawn_points_parent is not assigned.")
		return

	if enemy_manager == null:
		push_warning("WaveSpawner: enemy_manager is not assigned.")
		return

	if _spawn_points.is_empty():
		push_warning("WaveSpawner: no Marker3D spawn points found.")
		return

	_running = true
	_start_next_wave()


func _cache_spawn_points() -> void:
	_spawn_points.clear()

	if spawn_points_parent == null:
		return

	for child in spawn_points_parent.get_children():
		if child is Marker3D:
			_spawn_points.append(child)


func _start_next_wave() -> void:
	_wave_index += 1

	if _wave_index >= waves.size():
		_running = false
		all_waves_cleared.emit()
		return

	var wave_number := _wave_index + 1
	wave_started.emit(wave_number)

	var enemy_count := waves[_wave_index]
	_spawn_wave(enemy_count)


func _spawn_wave(enemy_count: int) -> void:
	for i in range(enemy_count):
		_spawn_enemy(i)
		await get_tree().create_timer(time_between_spawns).timeout


func _spawn_enemy(spawn_index: int) -> void:
	var enemy := enemy_scene.instantiate() as Node3D
	if enemy == null:
		return

	var spawn_point := _spawn_points[spawn_index % _spawn_points.size()]

	enemy_parent.add_child(enemy)
	enemy.global_position = spawn_point.global_position
	enemy.global_rotation = spawn_point.global_rotation


func _finish_current_wave() -> void:
	_running = false

	var wave_number := _wave_index + 1
	wave_cleared.emit(wave_number)

	await get_tree().create_timer(time_between_waves).timeout

	_running = true
	_start_next_wave()
