extends CharacterBody3D


@export var stats: Node 

# --- Health ---
var hp: float = 0.0
var max_hp: float = 0.0
var is_dead: bool = false


# --- VFX
@export var explosion_scene: PackedScene

@export var turn_speed: float = 0.5
@export var min_move_speed: float = 0.05

var direction: Vector3 = Vector3.ZERO

@onready var enemy_manager: Node3D = $"../../EnemyManager"


# --- Signals ---
signal died()
signal damaged(amount: float, source_type: String)

func _ready() -> void:
	_apply_stats()
	enemy_manager.register_enemy(self)
	
	

func _on_enemy_spawned():
	enemy_manager.enemies.append(self)
	#print(enemy_manager.enemies.size)

func _apply_stats() -> void:
	if stats:
		max_hp = stats.max_hp
		hp = max_hp

func _physics_process(delta: float) -> void:
	face_movement_direction(direction, delta, turn_speed)
	if not is_on_floor():
		velocity.y -= 9.8
	move_and_slide()
	
func face_movement_direction(direction: Vector3, delta: float, turn_speed_override: float = -1.0) -> void:
	direction.y = 0.0

	if direction.length_squared() < 0.0001:
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

	if hp <= 0.0:
		is_dead = true
		_die()
		
	## TODO add hit flash 
	## TODO add hit VFX
	## TODO add hit SFX
func _die():
	#print("enemy ded")
	queue_free()
	enemy_manager.unregister_enemy(self)
	#return to pool?

func get_health() -> float:
	return hp

#score reward
