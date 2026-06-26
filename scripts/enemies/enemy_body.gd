extends Node


@export var stats: Node 

# --- Health ---
var hp: float = 0.0
var max_hp: float = 0.0
var is_dead: bool = false


# --- VFX
@export var explosion_scene: PackedScene

@export var turn_speed: float = 0.5
@export var min_move_speed: float = 0.05
@export var weight: float = 50
var direction: Vector3 = Vector3.ZERO
var rotation: Vector3 = Vector3.ZERO

# --- Signals ---
signal died(unit_type: String, faction: String, killer_type: String)
signal damaged(amount: float, source_type: String)

func _ready() -> void:
	_apply_stats()

func _apply_stats() -> void:
	if stats:
		max_hp = stats.max_hp
		hp = max_hp

func _physics_process(delta: float) -> void:
	face_movement_direction(direction, delta, turn_speed)
	
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



#take_damage()
#death VFX
#score reward
#basic velocity movement
