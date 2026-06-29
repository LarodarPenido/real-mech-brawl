extends CharacterBody3D

enum State { IDLE, WALKING, AIMING, FIRING }

var state := State.IDLE

# Set by GameModeController when mode changes
var input_enabled: bool = true

# --- Health ---
var health: float
@export var max_health: float = 200
var alive: bool = true

signal health_changed(current: float, maximum: float)
#signal entered_hangar()
#signal exited_hangar()
signal afterburner_changed(active: bool, charge: float)
signal weapon_fired(weapon_name: String, hit_target: bool)

# --- Shield Forcefield ---
#@export var forcefield: Node3D

# --- Movement State ---
var is_moving: bool = false
var move_direction: Vector3 = Vector3.ZERO
var aim_point: Vector3 = Vector3.ZERO
var current_aim_point: Vector3 = Vector3.ZERO
var is_dashing: bool = false
var can_dash: bool = true





# --- Aim ---
@export var max_aim_distance: float = 50.0
@export var aim_sensitivity: float = 0.001


# Terrain L1 + EnemyUnits L3 + Destructibles L8
const AIM_COLLISION_MASK: int = 0b10000101

# --- Afterburner State ---
var afterburner_active: bool = false
var afterburner_charge: float = 1.0

# --- Weight State ---
var _weight: float = 0.0

signal weight_changed(current: float, maximum: float)

# --- Visual Tilt ---
@export_group("Visual Tilt")
@export var max_pitch: float = 3.0
@export var max_roll: float = 5.0
@export var tilt_speed: float = 20.0

@export var torso: Node3D 
@export var torso_pivot: Marker3D 

@export var legs: Node3D 
#@onready var torso: 

var _torso_base_rotation: Vector3
var _legs_base_rotation: Vector3

@export var use_eight_way_rotation := true
@export var eight_way_rotation_steps := 8

# --- Movement ---
@export var rotation_speed: float = 1.0
@export var max_speed: float = 8
@export var afterburner_speed_multiplier: float = 4.0
@export var afterburner_push_force: float = 300.0
@export var afterburner_duration: float = 5.0
@export var afterburner_recharge_time: float = 5.0
@export var acceleration: float = 40
@export var deceleration: float = 200

@export var dash_duration: float = 1.0
@export var dash_speed: float = 42.0
@export var dash_cooldown: float = 0.65
@export_range(0.0, 1.0) var dash_end_velocity_keep: float = 0.25

@export var min_charge_to_activate: float = 0.2
@export var max_weight: float = 100.0
@export var min_weight_multiplier: float = 0.5

# --- Camera ---
@export_group("Camera")
@export var camera_original_fov: float = 60.0
@export var camera_afterburner_fov: float = 60.0

# --- Node References ---

@export_group("Node References")
@onready var camera: Camera3D = get_viewport().get_camera_3d()

@onready var death_timer: Timer = get_node_or_null("DeathTimer")
@onready var aim_assist: Node = $AimAssist
@onready var weapon_manager: Node = $WeaponManager


@onready var mesh_health_bar: Node3D = $HealthBarPivot/MeshHealthBar



#--- VISUALS
@export var torso_animation_player: AnimationPlayer
@export var legs_animation_player: AnimationPlayer
@onready var afterimage_spawner: Node3D = get_node_or_null("Skin/AfterimageSpawner")


@export var explosion_scene: PackedScene

@export var death_freeze_duration: float = 2.0

#const EXPLOSION = preload("uid://cqw67qekwu81w")

## _____ DEGUB DEBUG
@onready var state_label: Label3D = $StateLabel



func _ready() -> void:
	health = max_health
	if legs:
		_legs_base_rotation = legs.rotation
	if torso:
		_torso_base_rotation = torso.rotation
	
	mesh_health_bar.update_health(health, max_health)

func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	if not alive:
		return

	if not is_on_floor():
		velocity -= Vector3(0, 9.8, 0)

	_get_aim_point()
	_update_move_direction()
	_handle_dash_input()
	#_handle_afterburner_input()
	#_update_afterburner(delta)
	_apply_legs_rotation(delta)
	_apply_torso_rotation(delta)
	_apply_movement(delta)
	_apply_tilt(delta)
	#_check_afterburner_collision()
	#_maintain_altitude(delta)
	#_handle_sfx()
	_update_animations()

	#torso_pivot.look_at(_get_aim_point())

	move_and_slide()



# =============================================================================
# AIM
# =============================================================================

func _get_aim_point() -> Vector3:
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = from + dir * 1000.0
	query.collision_mask = AIM_COLLISION_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result := space_state.intersect_ray(query)
	if result:
		current_aim_point = result.position
		return result.position

	# Fallback: ray missed all colliders (aiming at sky / void).
	# Don't intersect a ground plane — near the horizon that hit runs to
	# infinity and jitters, snapping the heli's facing. Instead, glide the
	# aim point around the player using the ray's horizontal heading.
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	if flat_dir.length_squared() < 0.0001:
		# Ray is near-vertical — keep current facing.
		current_aim_point = global_position + global_transform.basis.z * max_aim_distance
		return current_aim_point

	current_aim_point = global_position + flat_dir.normalized() * max_aim_distance
	return current_aim_point

# =============================================================================
# MOVEMENT
# =============================================================================

func _update_move_direction() -> void:
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_down", "move_up")

	if input == Vector2.ZERO:
		move_direction = Vector3.ZERO
		return

	# Camera-relative movement (screen directions)
	var cam_forward := -camera.global_transform.basis.z
	var cam_right := camera.global_transform.basis.x

	# Flatten to horizontal plane
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right.y = 0.0
	cam_right = cam_right.normalized()

	move_direction = (cam_right * input.x + cam_forward * input.y).normalized()


# =============================================================================
# ROTATION
# =============================================================================

func _apply_legs_rotation(delta: float) -> void:
	if not legs or not torso or move_direction.length_squared() < 0.001:
		return

	# Torso's forward and right, flattened to the ground plane.
	var torso_forward := -torso.global_transform.basis.z
	torso_forward.y = 0.0
	torso_forward = torso_forward.normalized()
	var torso_right := torso.global_transform.basis.x
	torso_right.y = 0.0
	torso_right = torso_right.normalized()

	# Split movement into "toward the aim" vs "sideways".
	var forward_amount := move_direction.dot(torso_forward)
	var right_amount := move_direction.dot(torso_right)

	# Fold the backward half into the forward hemisphere so the legs stay
	# forward-ish. The reverse-step (speed_scale) sells the backpedal.
	var leg_dir := torso_forward * absf(forward_amount) + torso_right * right_amount
	if leg_dir.length_squared() < 0.0001:
		return

	var target_angle := atan2(-leg_dir.x, -leg_dir.z)

	if use_eight_way_rotation:
		target_angle = _snap_angle(target_angle, eight_way_rotation_steps)
		legs.rotation.y = target_angle
	else:
		legs.rotation.y = lerp_angle(
			legs.rotation.y,
			target_angle,
			rotation_speed * _get_weight_multiplier() * delta
		)

func _moving_against_torso() -> bool:
	if not torso or move_direction == Vector3.ZERO:
		return false
	var torso_facing := -torso.global_transform.basis.z
	torso_facing.y = 0.0
	return move_direction.dot(torso_facing.normalized()) < 0.0


func _apply_torso_rotation(delta: float) -> void:
	if not torso:
		return

	var dir := current_aim_point - global_position
	dir.y = 0.0

	if dir.length_squared() < 0.001:
		return

	# Face the aim point (mouse raycast)
	var target_angle := atan2(-dir.x, -dir.z)

	if use_eight_way_rotation:
		target_angle = _snap_angle(target_angle, eight_way_rotation_steps)
		torso.rotation.y = target_angle
	else:
		torso.rotation.y = lerp_angle(
			torso.rotation.y, 
			target_angle, 
			rotation_speed * _get_weight_multiplier() * delta
		)

func _snap_angle(angle: float, steps: int) -> float:
	var step_size := TAU / float(steps)
	return round(angle / step_size) * step_size

func _apply_movement(delta: float) -> void:
	if is_dashing:
		return

	var current_max_speed := max_speed

	if afterburner_active and torso:
		# Read the TORSO's facing direction instead of the root body
		var facing_dir := -torso.global_transform.basis.z
		facing_dir.y = 0.0
		facing_dir = facing_dir.normalized()
		
		var alignment := move_direction.dot(facing_dir)  # -1 to 1
		var multiplier := lerpf(1.0, afterburner_speed_multiplier, clampf((alignment + 1.0) / 2.0, 0.0, 1.0))
		current_max_speed = max_speed * multiplier

	# Afterburner forward push
	if afterburner_active and torso:
		var facing := -torso.global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		velocity.x += facing.x * afterburner_push_force * delta
		velocity.z += facing.z * afterburner_push_force * delta

	if move_direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_direction.x * current_max_speed, acceleration * _get_weight_multiplier() * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * current_max_speed, acceleration * _get_weight_multiplier() * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)



func _update_animations() -> void:
	var weapon_is_actually_firing := false
	if velocity.length() > 0.0:
		is_moving = true
		state = State.WALKING
		state_label.text = "WALKING"
	else:
		state = State.IDLE
		is_moving = false
		state_label.text = "IDLE"
	
	if weapon_manager and weapon_manager.has_method("is_primary_actively_firing"):
		weapon_is_actually_firing = weapon_manager.is_primary_actively_firing()

	if weapon_is_actually_firing:
		state = State.FIRING
		state_label.text = "FIRING"
	
	#if aim_assist.locked_target:
		#state = State.AIMING
	
	match state:
		State.IDLE:
			torso_animation_player.play("TorsoIdle")
			legs_animation_player.play("LegsIdle")
			legs_animation_player.speed_scale = 1.5
		State.WALKING:
			torso_animation_player.play("TorsoWalk")
			legs_animation_player.play("LegsWalk")
			legs_animation_player.speed_scale = -1.5 if _moving_against_torso() else 1.5
		State.FIRING:
			torso_animation_player.play("TorsoFire")
			
		State.AIMING:
			torso_animation_player.play("TorsoAim")
		_:
			torso_animation_player.play("TorsoIdle")
			legs_animation_player.play("LegsIdle")

#func _maintain_altitude(delta: float) -> void:
	#var target_altitude := _landed_altitude if is_landed else config.desired_altitude
	#if position.y != target_altitude:
		#position.y = lerp(global_position.y, target_altitude, 0.7 * delta)


# =============================================================================
# VISUAL TILT
# =============================================================================

	
func _apply_tilt(delta: float) -> void:
	if not torso or not legs:
		return

	if velocity.length_squared() < 0.1:
		torso_pivot.rotation.z = lerp(torso_pivot.rotation.z, _torso_base_rotation.z, tilt_speed * delta)
		torso_pivot.rotation.x = lerp(torso_pivot.rotation.x, _torso_base_rotation.x, tilt_speed * delta)
		return

	# Determine forward/right speed relative to where the LEGS are facing
	var local_forward_speed := velocity.dot(-legs.global_transform.basis.z)
	var local_right_speed := velocity.dot(legs.global_transform.basis.x)

	var right_factor := clampf(-local_forward_speed / max_speed, -1.0, 1.0)
	var forward_factor := clampf(local_right_speed / max_speed, -1.0, 1.0)

	var target_pitch := -forward_factor * deg_to_rad(max_pitch)
	var target_roll := -right_factor * deg_to_rad(max_roll)

	torso.rotation.z = lerp(torso.rotation.z, _torso_base_rotation.z - target_pitch, tilt_speed * delta)
	torso.rotation.x = lerp(torso.rotation.x, _torso_base_rotation.x + target_roll, tilt_speed * delta)

# =============================================================================
# DASH
# =============================================================================

func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and can_dash and move_direction != Vector3.ZERO:
		_start_dash()


func _start_dash() -> void:
	if afterimage_spawner:
		afterimage_spawner.start_trail()

	is_dashing = true
	can_dash = false

	var dash_dir := move_direction
	if dash_dir.length_squared() < 0.001:
		dash_dir = -torso.global_transform.basis.z if torso else -global_transform.basis.z

	dash_dir.y = 0.0
	dash_dir = dash_dir.normalized()

	var weighted_dash_speed := dash_speed * _get_weight_multiplier()

	# Hard override = much snappier than velocity +=
	velocity.x = dash_dir.x * weighted_dash_speed
	velocity.z = dash_dir.z * weighted_dash_speed

	get_tree().create_timer(dash_duration).timeout.connect(_end_dash)
	get_tree().create_timer(dash_cooldown).timeout.connect(func(): can_dash = true)


func _end_dash() -> void:
	is_dashing = false

	# Hard cut after dash so it feels like a burst, not a slide.
	velocity.x *= dash_end_velocity_keep
	velocity.z *= dash_end_velocity_keep



# =============================================================================
# AFTERBURNER
# =============================================================================

func _handle_afterburner_input() -> void:
	if Input.is_action_just_pressed("toggle_afterburner"):
		if afterburner_active:
			afterburner_active = false
			afterburner_changed.emit(afterburner_active, afterburner_charge)
		elif afterburner_charge >= min_charge_to_activate:
			afterburner_active = true
			afterburner_changed.emit(afterburner_active, afterburner_charge)
			if afterimage_spawner:
				afterimage_spawner.start_trail()


func _update_afterburner(delta: float) -> void:
	if afterburner_active:
		if camera:
			camera.fov = lerp(camera.fov, camera_afterburner_fov, 3.0 * delta)

		# TODO
		#CameraShake.shake(0.3, 0.1)
		#AudioManager.play_sfx("afterburner_01", global_position) #
		
		var drain_rate : float = 1.0 / afterburner_duration
		afterburner_charge -= drain_rate * delta

		if afterburner_charge <= 0.0:
			afterburner_charge = 0.0
			afterburner_active = false

		afterburner_changed.emit(afterburner_active, afterburner_charge)
	else:
		if camera:
			camera.fov = lerp(camera.fov, camera_original_fov, 3.0 * delta)

		if afterburner_charge < 1.0:
			var recharge_rate : float = 1.0 / afterburner_recharge_time
			afterburner_charge = minf(afterburner_charge + recharge_rate * delta, 1.0)
			afterburner_changed.emit(afterburner_active, afterburner_charge)


func _check_afterburner_collision() -> void:
	if not afterburner_active:
		return

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		if absf(normal.y) < 0.5:
			afterburner_active = false
			velocity.x = clampf(velocity.x, -max_speed, max_speed)
			velocity.z = clampf(velocity.z, -max_speed, max_speed)
			afterburner_changed.emit(afterburner_active, afterburner_charge)
			return


func get_afterburner_charge() -> float:
	return afterburner_charge


func is_afterburner_active() -> bool:
	return afterburner_active


# =============================================================================
# WEIGHT
# =============================================================================

func _get_weight_multiplier() -> float:
	var ratio := clampf(_weight / max_weight, 0.0, 1.0)
	return lerpf(1.0, min_weight_multiplier, ratio)


func add_weight(amount: float) -> void:
	_weight = clampf(_weight + amount, 0.0, max_weight)
	weight_changed.emit(_weight, max_weight)


func remove_weight(amount: float) -> void:
	_weight = clampf(_weight - amount, 0.0, max_weight)
	weight_changed.emit(_weight, max_weight)


func get_weight() -> float:
	return _weight


# =============================================================================
# HEALTH
# =============================================================================

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO
		# TODO
		#AudioManager.stop_loop("afterburner_01")
		#AudioManager.stop_loop("rotor_light")

func take_damage(amount) -> void:
	if not alive:
		return
	#TODO
	#if forcefield and forcefield.is_active():
		#amount = forcefield.absorb(amount)
	
	health -= amount
	health = max(health, 0.0)
	health_changed.emit(health, max_health)
	
	mesh_health_bar.update_health(health, max_health)
	
	CameraShake.shake(0.03 * amount, 0.01 * amount)
	
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	health += amount
	health = min(health, max_health)
	health_changed.emit(health, max_health)

#func land(pad_altitude: float) -> void:
	#if is_landed:
		#return
	#is_landed = true
	#_landed_altitude = pad_altitude
	#entered_hangar.emit()


#func take_off() -> void:
	#if not is_landed:
		#return
	#is_landed = false
	#exited_hangar.emit()

func _die() -> void:
	alive = false
	#GameState.game_over.emit("defeat")
	print("player dead")
	death_timer.start()
	CameraShake.shake(0.5, 0.5)

	
	# Stop sounds
	#TODO
	#AudioManager.stop_loop("afterburner_01")
	#AudioManager.stop_loop("rotor_light") 
	if explosion_scene:
		spawn_explosion(global_position)


func spawn_explosion(world_position: Vector3) -> void:
	if explosion_scene == null:
		return

	HitStopManager.hit_freeze(0.3, death_freeze_duration)

	VFXPool.spawn(
	&"mesh_explosion",
	global_position,
	Basis.IDENTITY,
	{
		"radius": 12.0,
		"lifetime": 1.85
	}
)


# =============================================================================
# SFX
# =============================================================================

#func _handle_sfx() -> void:
	#if not is_landed:
		#AudioManager.start_loop("rotor_light", global_position)
	#else:
		#AudioManager.stop_loop("rotor_light")
#
	#if afterburner_active:
		#AudioManager.start_loop("afterburner_01", global_position)
	#else:
		#AudioManager.stop_loop("afterburner_01")

 ### -----

#func _on_mode_changed(is_overhead: bool) -> void:
	#set_input_enabled(not is_overhead)


func _on_death_timer_timeout() -> void:
	##TODO go to defeat screen
	pass # Replace with function body.
