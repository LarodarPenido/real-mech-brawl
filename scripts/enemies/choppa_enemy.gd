extends CharacterBody3D


@export var stats: Node 

@export var _is_stationery: bool = false
@export var _is_flying: bool = false

# --- Health ---
var hp: float = 0.0
var max_hp: float = 0.0
var is_dead: bool = false

@onready var mesh_health_bar: Node3D = $HealthBarPivot/MeshHealthBar

# --- VFX
@export var explosion_scene: PackedScene
@export var death_time: float = 5.0
@export var turn_speed: float = 0.5
@export var min_move_speed: float = 0.05

var direction: Vector3 = Vector3.ZERO

@onready var enemy_manager: Node3D

@export var time_freeze_duration: float = 0.01

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

@export var grants_health_pickup: bool = false
@export var grants_ammo_pickup: bool = false

@export var ammo_pickup: PackedScene
@export var health_pickup: PackedScene

## Flight
@export var altitude: float = 10
@export var orbit_radius: float = 10

const ORBIT_GRACE_DURATION: float = 1.0
var _orbit_angle: float = 0.0
var _orbit_direction: int = 1
var _orbit_grace_timer: float = 0.0

var player: Node3D

# --- Signals ---
signal died()
signal damaged(amount: float, source_type: String)


#Debug


func _ready() -> void:
	_apply_stats()
	enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	enemy_manager.register_enemy(self)
	#hp = max_hp
	mesh_health_bar.update_health(hp, max_hp)
	player = get_tree().get_first_node_in_group("player")
	

func _on_enemy_spawned():
	enemy_manager.enemies.append(self)
	#print(enemy_manager.enemies.size)

func _apply_stats() -> void:
	if stats:
		max_hp = stats.max_hp
		hp = max_hp

func _physics_process(delta: float) -> void:

	

	if _is_stationery:
		return
	if not is_on_floor() and not _is_flying:
		velocity.y -= 9.8
	
	if not is_dead:
		_tick_orbit(delta)
		#global_position.y = lerp(global_position.y, altitude, 0.5)
	else:
		global_position.y = lerp(global_position.y, 0.0, 0.03)
		if global_position.y >= 0.5:
			rotation.y += 1 * delta
	
	if not is_dead:
		face_movement_direction(direction, delta, turn_speed)
		move_and_slide()
	
	

func _tick_orbit(delta: float) -> void:
	# Tangential orbit: angular speed derived from linear speed / radius
	var radius = orbit_radius
	if radius < 0.001:
		radius = 1.0
	var angular_speed = stats.move_speed / radius
	_orbit_angle += angular_speed * _orbit_direction * delta

	# Desired position on the orbit circle around the target.
	var target_pos: Vector3 = player.global_position
	var desired: Vector3 = target_pos + Vector3(
		cos(_orbit_angle) * radius,
		0.0,
		sin(_orbit_angle) * radius
	)
	desired.y = altitude

	# Move toward the orbit point at unit speed (so a fleeing player can leash us).
	var to_desired: Vector3 = desired - global_position
	var step: float = stats.move_speed * delta
	if to_desired.length() <= step:
		global_position = desired
	else:
		global_position += to_desired.normalized() * step

		# Grace period before the first lock kicks in — lets the heli visually settle.
	if _orbit_grace_timer > 0.0:
		_orbit_grace_timer -= delta
		return


func face_movement_direction(direction: Vector3, delta: float, turn_speed_override: float = -1.0) -> void:
	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		return

	if is_dead:
		return

	var target_yaw: float = atan2(-direction.x, -direction.z)

	if turn_speed_override > 0.0:
		turn_speed = turn_speed_override

	var next_rotation: Vector3 = rotation
	next_rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed)
	rotation = next_rotation

func take_damage(amount: float) -> void:
	if is_dead:
		return

	hp -= amount

	mesh_health_bar.update_health(hp, max_hp)

	if hp <= 0.0:
		enemy_manager.unregister_enemy(self)
		is_dead = true
		_die()
		
	## TODO add hit flash 
	## TODO add hit VFX

func _die():
	grant_pickups()
	collision_shape_3d.disabled = true
	mesh_health_bar.hide()
	
	if explosion_scene:
		spawn_explosion(global_position)
	
	Audio.play_sfx_at_3d(Sounds.explosion_01, global_position, 5, 0.1, 1)

	await get_tree().create_timer(death_time).timeout
	
	
	
	queue_free()


func get_health() -> float:
	return hp

# TODO score reward

func spawn_explosion(world_position: Vector3) -> void:
	if explosion_scene == null:
		return

	VFXPool.spawn(
	&"mesh_explosion",
	global_position,
	Basis.IDENTITY,
	{
		"radius": 6.0,
		"lifetime": 0.85
	}
)

func grant_pickups() -> void:
	if grants_ammo_pickup:
		var _ammo = ammo_pickup.instantiate()
		get_parent().add_child(_ammo)
		_ammo.global_position = global_position
	if grants_health_pickup:
		var _chicken = health_pickup.instantiate()
		get_parent().add_child(_chicken)
		_chicken.global_position = global_position
		
