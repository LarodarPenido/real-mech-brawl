# simple_missile_launcher.gd
extends Node3D

@export var missile_scene: PackedScene

@export var left_muzzle: Marker3D
@export var right_muzzle: Marker3D

@export var stagger_launch_time: float = 0.3

@export var max_ammo: int = 4
@export var ammo: int = 0

@export var fire_cooldown: float = 1.0

var aim_assist: Node = null
var owner_body: Node3D = null

var _cooldown_left: float = 0.0
var _trigger_was_held: bool = false


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


# Called by WeaponManager while fire_missiles is held.
func trigger_held(delta: float) -> void:
	# Fire only once per button press.
	if _trigger_was_held:
		return

	_trigger_was_held = true
	try_fire()


# Called by WeaponManager when fire_missiles is released.
func trigger_released(delta: float) -> void:
	_trigger_was_held = false


func try_fire() -> bool:
	if not can_fire():
		return false

	ammo -= 1
	_cooldown_left = fire_cooldown

	_spawn_missile(left_muzzle)
	await get_tree().create_timer(stagger_launch_time).timeout
	_spawn_missile(right_muzzle)

	return true


func can_fire() -> bool:
	if missile_scene == null:
		return false

	if ammo <= 0:
		return false

	if _cooldown_left > 0.0:
		return false

	if aim_assist == null:
		return false

	if not aim_assist.has_method("has_lock"):
		return false

	if not aim_assist.has_lock():
		return false

	return true


func add_ammo(amount: int) -> void:
	ammo = clampi(ammo + amount, 0, max_ammo)


func set_aim_assist(new_aim_assist: Node) -> void:
	aim_assist = new_aim_assist


func set_owner_node(new_owner: Node3D) -> void:
	owner_body = new_owner


# Optional compatibility with your WeaponManager.
# You do not need missile_lock for this simple version.
func set_missile_lock(new_missile_lock: Node) -> void:
	pass


func _spawn_missile(muzzle: Marker3D) -> void:
	if muzzle == null:
		return

	var missile := missile_scene.instantiate() as Area3D
	get_tree().current_scene.add_child(missile)

	missile.global_transform = muzzle.global_transform

	var start_dir := -muzzle.global_transform.basis.z

	if missile.has_method("setup"):
		missile.setup(start_dir, aim_assist, owner_body)
