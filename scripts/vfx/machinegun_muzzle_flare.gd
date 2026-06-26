extends Node3D

@export var lifetime: float = 0.04

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

	if args.has("target"):
		look_at(args["target"])


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
