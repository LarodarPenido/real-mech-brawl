extends Node



var _pool_root: Node3D

var _scenes: Dictionary = {}
var _available: Dictionary = {}
var _active: Dictionary = {}
var _allow_growth: Dictionary = {}


func _ready() -> void:
	_pool_root = Node3D.new()
	_pool_root.name = "VFXPoolRoot"
	add_child(_pool_root)


func register_pool(
	pool_id: StringName,
	scene: PackedScene,
	initial_size: int,
	allow_growth: bool = false
) -> void:
	if scene == null:
		push_warning("VFXPool: Cannot register null scene for pool: %s" % pool_id)
		return

	if _scenes.has(pool_id):
		return

	_scenes[pool_id] = scene
	_available[pool_id] = []
	_active[pool_id] = []
	_allow_growth[pool_id] = allow_growth

	for i in range(initial_size):
		var instance := _create_instance(pool_id)
		_release_to_available(pool_id, instance)


func spawn(
	pool_id: StringName,
	position: Vector3,
	basis: Basis = Basis.IDENTITY,
	args: Dictionary = {}
) -> Node3D:
	if not _scenes.has(pool_id):
		push_warning("VFXPool: Pool not registered: %s" % pool_id)
		return null

	var node: Node3D = null

	if not _available[pool_id].is_empty():
		node = _available[pool_id].pop_back()
	else:
		if _allow_growth[pool_id]:
			node = _create_instance(pool_id)
		else:
			node = _recycle_oldest(pool_id)

	if node == null:
		return null

	_active[pool_id].append(node)

	node.global_transform = Transform3D(basis, position)
	node.visible = true

	if node.has_method("on_pool_spawned"):
		node.on_pool_spawned(args)

	return node


func release(node: Node3D) -> void:
	if node == null:
		return

	if not node.has_meta("pool_id"):
		node.visible = false
		return

	var pool_id: StringName = node.get_meta("pool_id")

	if not _available.has(pool_id):
		node.visible = false
		return

	_active[pool_id].erase(node)

	if node.has_method("on_pool_despawned"):
		node.on_pool_despawned()

	_release_to_available(pool_id, node)


func _create_instance(pool_id: StringName) -> Node3D:
	var scene: PackedScene = _scenes[pool_id]
	var instance := scene.instantiate() as Node3D

	if instance == null:
		push_warning("VFXPool: Scene for pool %s is not a Node3D." % pool_id)
		return null

	_pool_root.add_child(instance)

	instance.set_meta("pool_id", pool_id)
	instance.top_level = true
	instance.visible = false

	if instance.has_method("on_pool_created"):
		instance.on_pool_created()

	return instance


func _release_to_available(pool_id: StringName, node: Node3D) -> void:
	if node == null:
		return

	node.visible = false
	_available[pool_id].append(node)


func _recycle_oldest(pool_id: StringName) -> Node3D:
	if _active[pool_id].is_empty():
		return null

	var node: Node3D = _active[pool_id].pop_front()

	if node.has_method("on_pool_despawned"):
		node.on_pool_despawned()

	return node
