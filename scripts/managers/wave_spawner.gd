extends Node3D

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal all_waves_cleared()

@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_parent: Node3D
@export var spawn_points_parent: Node3D
@export var enemy_manager: Node

@export var start_delay: float = 1.0
@export var time_between_waves: float = 2.0
@export var time_between_spawns: float = 0.25
@export var auto_start: bool = true

@export_group("Spawn Indicators")
@export var spawn_indicator_scene: PackedScene
@export var spawn_indicator_warning_time: float = 0.75
@export var spawn_indicator_linger_time: float = 0.1

@export var wave_spawn_position_offset: float = -30.0
# Each Dictionary means:
# enemy scene index -> amount
@export var waves: Array[Dictionary] = [
	{0: 2},
	{0: 3},
	{0: 3, 1: 1},
	{0: 4, 1: 2},
	{0: 5, 1: 3},
	{0: 3, 1: 2, 2:1}
]

@export var hard_mode_waves: Array[Dictionary] = [
	{0: 3, 1: 1},
	{0: 4, 1: 2, 2: 1},
	{0: 4, 1: 1, 2: 1},
	{0: 5, 1: 2, 2: 3},
	{0: 6, 1: 3, 2: 4},
	{0: 7, 1: 4, 2: 6},
	{0: 12, 1: 8, 2: 8},
	{0: 24, 1: 12, 2: 10},
]



@export var shuffle_wave_spawns: bool = true

var _wave_index: int = -1
var _running: bool = false
var _spawn_points: Array[Marker3D] = []

var _alive_wave_enemies: Array[Node3D] = []
var _spawning_wave: bool = false

var _active_waves: Array[Dictionary] = []

func _ready() -> void:
	_cache_spawn_points()

	if auto_start:
		await get_tree().create_timer(start_delay).timeout
		start_waves()


func _process(_delta: float) -> void:
	if not _running:
		return

	if _spawning_wave:
		return

	_cleanup_dead_wave_enemies()

	if _alive_wave_enemies.size() > 0:
		return

	_finish_current_wave()

	position.z = _wave_index * wave_spawn_position_offset

func start_waves() -> void:
	if _running:
		return

	if enemy_scenes.is_empty():
		push_warning("WaveSpawner: enemy_scenes is empty.")
		return

	for scene in enemy_scenes:
		if scene == null:
			push_warning("WaveSpawner: one enemy scene is not assigned.")
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

	_active_waves = hard_mode_waves if RunState.hard_mode else waves

	if _active_waves.is_empty():
		push_warning("WaveSpawner: active wave list is empty.")
		return

	_wave_index = -1
	_running = true
	_start_next_wave()


func _cache_spawn_points() -> void:
	_spawn_points.clear()

	if spawn_points_parent == null:
		return

	for child in spawn_points_parent.get_children():
		if child is Marker3D:
			print("wave spawner: spawn point added at:", child.global_position)
			_spawn_points.append(child)

func _start_next_wave() -> void:
	print("wave spawner: new wave started")
	_wave_index += 1

	if _wave_index >= _active_waves.size():
		_running = false
		all_waves_cleared.emit()
		return

	var wave_number := _wave_index + 1
	wave_started.emit(wave_number)

	var wave_data: Dictionary = _active_waves[_wave_index]
	_spawn_wave(wave_data)


func _spawn_wave(wave_data: Dictionary) -> void:
	print("wave spawner: spawning")

	_spawning_wave = true
	_alive_wave_enemies.clear()

	var spawn_queue: Array[int] = []

	for enemy_type_index in wave_data.keys():
		var type_index := int(enemy_type_index)
		var enemy_count := int(wave_data[enemy_type_index])

		if type_index < 0 or type_index >= enemy_scenes.size():
			push_warning("WaveSpawner: invalid enemy type index: %s" % type_index)
			continue

		for i in range(enemy_count):
			spawn_queue.append(type_index)

	if shuffle_wave_spawns:
		spawn_queue.shuffle()

	for i in range(spawn_queue.size()):
		var enemy_type_index := spawn_queue[i]
		var spawn_point := _spawn_points[i % _spawn_points.size()]

		var indicator := _spawn_spawn_indicator(spawn_point)

		if spawn_indicator_warning_time > 0.0:
			await get_tree().create_timer(spawn_indicator_warning_time).timeout

		_spawn_enemy(enemy_type_index, spawn_point)

		if spawn_indicator_linger_time > 0.0:
			await get_tree().create_timer(spawn_indicator_linger_time).timeout

		if is_instance_valid(indicator):
			indicator.queue_free()

		await get_tree().create_timer(time_between_spawns).timeout

	_spawning_wave = false

func _spawn_enemy(enemy_type_index: int, spawn_point: Marker3D) -> void:
	if enemy_type_index < 0 or enemy_type_index >= enemy_scenes.size():
		return

	var scene := enemy_scenes[enemy_type_index]
	if scene == null:
		return

	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		return

	enemy_parent.add_child(enemy)
	enemy.global_position = spawn_point.global_position
	enemy.global_rotation = Vector3.ZERO #spawn_point.global_rotation

	_alive_wave_enemies.append(enemy)
	enemy.add_to_group("wave_enemy")

	enemy.tree_exiting.connect(_on_wave_enemy_removed.bind(enemy))

func _on_wave_enemy_removed(enemy: Node3D) -> void:
	_alive_wave_enemies.erase(enemy)


func _cleanup_dead_wave_enemies() -> void:
	for i in range(_alive_wave_enemies.size() - 1, -1, -1):
		var enemy := _alive_wave_enemies[i]

		if not is_instance_valid(enemy):
			_alive_wave_enemies.remove_at(i)

func _finish_current_wave() -> void:
	print("wave spawner: finishing wave")
	_running = false

	var wave_number := _wave_index + 1
	wave_cleared.emit(wave_number)

	await get_tree().create_timer(time_between_waves).timeout

	_running = true
	_start_next_wave()

func get_total_waves() -> int:
	if not _active_waves.is_empty():
		return _active_waves.size()

	var selected_waves := hard_mode_waves if RunState.hard_mode else waves
	return selected_waves.size()


func get_current_wave_number() -> int:
	if _wave_index < 0:
		return 0

	return clampi(_wave_index + 1, 0, get_total_waves())


func get_wave_counter_text() -> String:
	return "WAVE %d/%d" % [get_current_wave_number(), get_total_waves()]

func _spawn_spawn_indicator(spawn_point: Marker3D) -> Node3D:
	if spawn_indicator_scene == null:
		push_warning("WaveSpawner: spawn_indicator_scene is not assigned.")
		return null

	var new_indicator := spawn_indicator_scene.instantiate() as Node3D
	if new_indicator == null:
		push_warning("WaveSpawner: spawn_indicator_scene root must be Node3D.")
		return null

	spawn_point.add_child(new_indicator)

	# Because it is a child of the marker, use local transform.
	#new_indicator.position = Vector3.ZERO
	new_indicator.visible = true

	return new_indicator
	
