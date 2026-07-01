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

# --- VFX
@onready var after_image_trail: Node3D = $AfterImageTrail



var aim_assist: Node = null
var owner_body: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var _current_speed: float = 0.0
var _life_left: float = 0.0
var _age: float = 0.0
var _locked_target: Node3D = null


var _fallback_dir: Vector3 = Vector3.FORWARD
var _free_aim_point: Vector3 = Vector3.ZERO
var _has_free_aim_point: bool = false

func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)


	if after_image_trail:
		after_image_trail.start_emitting()

func setup(
	start_direction: Vector3,
	new_aim_assist: Node,
	new_owner_body: Node3D,
	free_aim_point: Vector3 = Vector3.ZERO,
	has_free_aim_point: bool = false,
	locked_target: Node3D = null
) -> void:
	aim_assist = new_aim_assist
	owner_body = new_owner_body
	_locked_target = locked_target

	_life_left = lifetime
	_age = 0.0

	if start_direction.length_squared() < 0.001:
		start_direction = -global_transform.basis.z

	_fallback_dir = start_direction.normalized()

	_free_aim_point = free_aim_point
	_has_free_aim_point = has_free_aim_point

	_current_speed = launch_speed
	velocity = _fallback_dir * _current_speed
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
	var current_dir := _fallback_dir

	if velocity.length_squared() > 0.001:
		current_dir = velocity.normalized()

	var target_pos := Vector3.ZERO
	var has_valid_target := false

	# 1. Prefer the target captured at launch.
	if _locked_target != null and is_instance_valid(_locked_target):
		target_pos = _locked_target.global_position + Vector3(0.0, 1.0, 0.0)
		has_valid_target = true

	# 2. If there was no locked target, use the free aim point captured at launch.
	if not has_valid_target and _has_free_aim_point:
		var to_free_aim := _free_aim_point - global_position

		if to_free_aim.length_squared() > 4.0:
			target_pos = _free_aim_point
			has_valid_target = true
		else:
			_has_free_aim_point = false

	# 3. If there is no target, continue straight.
	if not has_valid_target:
		velocity = current_dir * _current_speed
		_fallback_dir = current_dir
		return

	var desired_dir := target_pos - global_position

	if desired_dir.length_squared() < 0.001:
		velocity = current_dir * _current_speed
		_fallback_dir = current_dir
		return

	var target_dir := desired_dir.normalized()
	var weight := clampf(turn_speed * delta, 0.0, 1.0)
	var new_dir := current_dir.slerp(target_dir, weight).normalized()

	velocity = new_dir * _current_speed
	_fallback_dir = new_dir


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
	if after_image_trail:
		after_image_trail.stop_emitting()
		after_image_trail.clear_trail()
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
