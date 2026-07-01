# simple_missile.gd
extends Area3D

@export var max_speed: float = 210.0
@export var acceleration: float = 150.0
@export var boost_delay: float = 0.1
@export var boost_acceleration: float = 190.0
@export var launch_speed: float = 0.0
@export var turn_speed: float = 8.0
@export var damage: float = 50.0
@export var lifetime: float = 4.0
@export var explosion_scene: PackedScene

@export var shake_power: float = 0.2
@export var shake_duration: float = 0.2

var aim_assist: Node = null
var owner_body: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var _current_speed: float = 0.0
var _life_left: float = 0.0
var _age: float = 0.0

func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)


func setup(start_direction: Vector3, new_aim_assist: Node, new_owner_body: Node3D) -> void:
	aim_assist = new_aim_assist
	owner_body = new_owner_body
	_life_left = lifetime

	if start_direction.length_squared() < 0.001:
		start_direction = -global_transform.basis.z

	_current_speed = launch_speed
	velocity = start_direction.normalized() * _current_speed
	_face_velocity()

	Audio.play_sfx_at_3d(Sounds.jets, global_position, 9)

func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0:
		_explode()
		return

	_age += delta

	var accel := acceleration
	if _age >= boost_delay:
		accel = boost_acceleration

	_current_speed = move_toward(
		_current_speed,
		max_speed,
		accel * delta
	)

	_update_homing(delta)

	global_position += velocity * delta
	_face_velocity()


func _update_homing(delta: float) -> void:
	if aim_assist == null:
		return

	if not aim_assist.has_method("has_lock"):
		return

	if not aim_assist.has_lock():
		return

	if not aim_assist.has_method("get_fire_point"):
		return

	var target_pos: Vector3 = aim_assist.get_fire_point()
	if target_pos == Vector3.ZERO:
		return

	var desired_dir := target_pos - global_position
	if desired_dir.length_squared() < 0.001:
		return

	var current_dir := velocity.normalized()
	var target_dir := desired_dir.normalized()

	var weight := clampf(turn_speed * delta, 0.0, 1.0)
	var new_dir := current_dir.slerp(target_dir, weight).normalized()

	velocity = new_dir * _current_speed


func _face_velocity() -> void:
	if velocity.length_squared() < 0.001:
		return

	var dir := velocity.normalized()
	var up := Vector3.UP

	if abs(dir.dot(Vector3.UP)) > 0.98:
		up = Vector3.FORWARD

	look_at(global_position + dir, up)


func _on_body_entered(body: Node3D) -> void:
	if body == owner_body:
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	_explode()


func _explode() -> void:
	if explosion_scene:
		spawn_explosion(global_position)

	queue_free()

func spawn_explosion(world_position: Vector3) -> void:
	if explosion_scene == null:
		return

	VFXPool.spawn(&"mesh_explosion", global_position)

	CameraShake.shake(shake_power, shake_duration)

	Audio.play_sfx_at_3d(Sounds.explosion_01, global_position, 5, 0.1, 1)

	#VFXPool.spawn(
		#&"mesh_explosion",
		#global_position,
		#Basis.IDENTITY,
		#{
			#"radius": 3.5,
			#"lifetime": 0.55
		#}
	#)
	
	# LArge Explosion
	#VFXPool.spawn(
	#&"mesh_explosion",
	#global_position,
	#Basis.IDENTITY,
	#{
		#"radius": 6.0,
		#"lifetime": 0.85
	#}
#)
