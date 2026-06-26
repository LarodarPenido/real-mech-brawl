extends Node3D

@export var lifetime: float = 0.45

var _elapsed: float = 0.0
var _active: bool = false


func _ready() -> void:
	visible = false
	set_process(false)


func on_pool_spawned(args: Dictionary = {}) -> void:
	_elapsed = 0.0
	_active = true
	visible = true
	set_process(true)

	if args.has("normal"):
		_orient_to_normal(args["normal"])

func on_pool_despawned() -> void:
	_active = false
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta

	if _elapsed >= lifetime:
		VFXPool.release(self)


func _orient_to_normal(normal: Vector3) -> void:
	if normal.length_squared() < 0.001:
		return

	var target := global_position + normal.normalized()
	var up := Vector3.UP

	if abs(normal.normalized().dot(Vector3.UP)) > 0.98:
		up = Vector3.FORWARD

	look_at(target, up)
