extends CharacterBody3D


@export var stats: Node 

@export var _is_stationery: bool = false

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

@onready var enemy_manager: Node3D = $"../../../../EnemyManager"

@export var time_freeze_duration: float = 0.01

# --- Signals ---
signal died()
signal damaged(amount: float, source_type: String)

func _ready() -> void:
	_apply_stats()
	enemy_manager.register_enemy(self)
	#hp = max_hp
	mesh_health_bar.update_health(hp, max_hp)
	

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
	if not is_on_floor():
		velocity.y -= 9.8
	
	if not is_dead:
		face_movement_direction(direction, delta, turn_speed)
		move_and_slide()
	
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
	## TODO add hit SFX
func _die():

	mesh_health_bar.hide()

	# Tell the global manager to handle the hit freeze
	#HitStopManager.hit_freeze(0.05, time_freeze_duration)
	
	if explosion_scene:
		spawn_explosion(global_position)
	
	
	
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
