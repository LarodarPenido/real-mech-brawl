extends RigidBody3D

@export var lifetime: float = 3.0
@export var eject_force: float = 3.5
@export var upward_force: float = 1.5
@export var spin_force: float = 8.0

var _elapsed: float = 0.0
var _active: bool = false


func _ready() -> void:
	visible = false
	freeze = true
	sleeping = true
	set_physics_process(false)


func on_pool_spawned(args: Dictionary = {}) -> void:
	_elapsed = 0.0
	_active = true

	visible = true
	freeze = false
	sleeping = false
	set_physics_process(true)

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	var eject_dir := Vector3.RIGHT

	if args.has("eject_dir"):
		eject_dir = args["eject_dir"]

	if eject_dir.length_squared() < 0.001:
		eject_dir = Vector3.RIGHT

	eject_dir = eject_dir.normalized()

	var impulse := eject_dir * eject_force
	impulse += Vector3.UP * upward_force

	apply_central_impulse(impulse)

	angular_velocity = Vector3(
		randf_range(-spin_force, spin_force),
		randf_range(-spin_force, spin_force),
		randf_range(-spin_force, spin_force)
	)


func on_pool_despawned() -> void:
	_active = false

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	sleeping = true
	freeze = true
	visible = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta

	if _elapsed >= lifetime:
		VFXPool.release(self)
