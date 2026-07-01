extends Node3D

@export var ghost_scene: PackedScene

@export_group("Trail")
@export var ghost_count: int = 6
@export var spawn_interval: float = 0.06
@export var visible_duration: float = 0.18

@export_group("Source")
@export var source_node: Node3D
@export var position_offset: Vector3 = Vector3.ZERO
@export var rotation_offset_degrees: Vector3 = Vector3.ZERO

@export_group("Behavior")
@export var auto_emit: bool = false
@export var start_hidden: bool = true

var _pool: Array[Node3D] = []
var _life_left: Array[float] = []
var _pool_index: int = 0

var _burst_spawns_remaining: int = 0
var _spawn_timer: float = 0.0
var _emitting: bool = false


func _ready() -> void:
	if source_node == null:
		source_node = get_parent() as Node3D

	_create_pool()

	_emitting = auto_emit
	set_process(true)



func _create_pool() -> void:
	if ghost_scene == null:
		push_warning("AfterimageTrail: ghost_scene is not assigned.")
		return

	if ghost_count <= 0:
		push_warning("AfterimageTrail: ghost_count must be greater than 0.")
		return

	for i in range(ghost_count):
		var ghost := ghost_scene.instantiate() as Node3D
		if ghost == null:
			push_warning("AfterimageTrail: ghost_scene root must be Node3D.")
			continue

		ghost.visible = not start_hidden
		ghost.top_level = true

		_pool.append(ghost)
		_life_left.append(0.0)

	call_deferred("_add_pool_to_scene")


func _add_pool_to_scene() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root

	for ghost in _pool:
		if ghost.get_parent() == null:
			root.add_child(ghost)


func _process(delta: float) -> void:
	_update_ghost_lifetimes(delta)

	if _emitting:
		_spawn_timer += delta
		while _spawn_timer >= spawn_interval:
			_spawn_timer -= spawn_interval
			_spawn_ghost()

	elif _burst_spawns_remaining > 0:
		_spawn_timer += delta
		while _spawn_timer >= spawn_interval and _burst_spawns_remaining > 0:
			_spawn_timer -= spawn_interval
			_burst_spawns_remaining -= 1
			_spawn_ghost()


func _update_ghost_lifetimes(delta: float) -> void:
	for i in range(_pool.size()):
		if _life_left[i] <= 0.0:
			continue

		_life_left[i] -= delta

		if _life_left[i] <= 0.0:
			_pool[i].visible = false


func start_burst(spawn_count: int = -1) -> void:
	if _pool.is_empty():
		return

	if spawn_count < 0:
		spawn_count = ghost_count

	_burst_spawns_remaining = spawn_count
	_spawn_timer = spawn_interval

	# Spawn one immediately so dash feels responsive.
	_burst_spawns_remaining -= 1
	_spawn_ghost()


func start_emitting() -> void:
	_emitting = true
	_spawn_timer = spawn_interval
	_spawn_ghost()


func stop_emitting() -> void:
	_emitting = false
	_spawn_timer = 0.0


func clear_trail() -> void:
	_burst_spawns_remaining = 0
	_emitting = false
	_spawn_timer = 0.0

	for i in range(_pool.size()):
		_life_left[i] = 0.0
		_pool[i].visible = false


func _spawn_ghost() -> void:
	if _pool.is_empty():
		return

	if source_node == null or not is_instance_valid(source_node):
		return

	var ghost := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()

	var rot_offset := Vector3(
		deg_to_rad(rotation_offset_degrees.x),
		deg_to_rad(rotation_offset_degrees.y),
		deg_to_rad(rotation_offset_degrees.z)
	)

	var local_offset := Transform3D(Basis.from_euler(rot_offset), position_offset)

	ghost.global_transform = source_node.global_transform * local_offset
	ghost.visible = true

	_life_left[_pool.find(ghost)] = visible_duration
