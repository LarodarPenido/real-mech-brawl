extends Node

enum BehaviorMode {
	LIGHT_REPOSITION,
	TANK_HOLD
}

enum State {
	IDLE,
	CHASE,
	AIM,
	FIRE,
	REPOSITION,
	COOLDOWN
}

@export var weapon: Node3D
var unit: Node = null 
@onready var stats: Node = $"../EnemyStats"

@onready var telegraph_timer: Timer = $"../TelegraphTimer"
@onready var laser_sight: Node3D = $"../LaserSight"
@onready var muzzle_point: Marker3D = $"../Weapon/MuzzlePoint"


## --- Debug
@onready var state_label: Label3D = $"../StateLabel"
@onready var target_label: Label3D = $"../TargetLabel"

# --- State ---
var state: State = State.IDLE
var behavior_mode: BehaviorMode = BehaviorMode.LIGHT_REPOSITION
var target: Node = null

var target_search_timer: float = 0.0
@export var target_search_interval: float = 1.0


var player: Node3D = null

@export var telegraph_duration: float = 1.5
@export var aim_enter_margin = 2.0
@export var aim_exit_margin = 3.0

@export var aim_settle_time: float = 0.15

var _aim_settle_timer: float = 0.0

# --- Burst fire pacing ---
var burst_shots_remaining: int = 0
var burst_interval_timer: float = 0.0
var cooldown_timer: float = 0.0

func _ready() -> void:
	unit = get_parent()
	player = get_tree().get_first_node_in_group("player")
	
func _process(delta: float) -> void:
	_should_show_laser()
	if _should_show_laser():
		laser_sight.update_laser_sight(muzzle_point.global_position, target.global_position)
	else:
		laser_sight.hide_laser_sight()
	
func _physics_process(delta: float) -> void:
	_debug_state_label()
	if not unit:
		return

	# Tick target search
	target_search_timer -= delta
	if target_search_timer <= 0.0:
		target_search_timer = target_search_interval
		_set_target(player)

	match state:
		State.IDLE:
			_tick_idle(delta)
		State.CHASE:
			_tick_chase(delta)
		State.AIM:
			_tick_aim(delta)
		State.FIRE:
			_tick_fire(delta)
		State.REPOSITION:
			_tick_reposition(delta)
		State.COOLDOWN:
			_tick_cooldown(delta)


func _tick_idle(_delta: float) -> void:
	_set_target(player)

	if not target:
		return

	if player_in_weapon_range():
		_enter_state(State.AIM)
		return

	if player_in_detection_range():
		_enter_state(State.CHASE)
		return
	

func player_in_detection_range() -> bool:
	if not player or not is_instance_valid(player): # or _node_is_dead(player):
		return false
	var dist: float = unit.global_position.distance_to(player.global_position)
	if dist > unit.stats.detection_range:
		return false
	return true

func player_in_weapon_range() -> bool:
	if not player or not is_instance_valid(player): # or _node_is_dead(player):
		return false
	var dist: float = unit.global_position.distance_to(player.global_position)
	if dist > unit.stats.weapon_range:
		return false
	return true


func _set_target(new_target: Node3D) -> void:
	if new_target == null or not is_instance_valid(new_target):
		self.target = null
		return

	self.target = new_target

func _tick_chase(delta: float) -> void:
	if not _has_valid_target() or not player_in_detection_range():
		_enter_state(State.IDLE)
		return

	_point_weapon(target)

	if player_in_weapon_range():
		_stop_moving()
		if _can_enter_aim(target):
			_enter_aim()
			return

	var move_direction: Vector3 = target.global_position - unit.global_position
	move_direction.y = 0.0

	if move_direction.length_squared() < 0.0001:
		_stop_moving()
		return

	move_direction = move_direction.normalized()

	unit.direction = move_direction
	unit.velocity = move_direction * stats.move_speed

func _enter_aim() -> void:
	state = State.AIM
	_aim_settle_timer = 0.0

func _tick_aim(delta: float) -> void:
	if not _has_valid_target() or not player_in_detection_range():
		_enter_state(State.IDLE)
		return

	if not player_in_weapon_range():
		_enter_state(State.CHASE)
		return

	_stop_moving()
	
	_face_target(delta)
	_point_weapon(target)
	
	
	if _can_fire(target):
		_aim_settle_timer += delta
	else:
		_aim_settle_timer = 0.0

	if _aim_settle_timer >= aim_settle_time:
		_enter_state(State.FIRE)

func _face_target(delta: float) -> void:
	if not target:
		return

	_point_weapon(target)

	var to_target: Vector3 = target.global_position - unit.global_position
	to_target.y = 0.0

	if to_target.length() < 0.001:
		return

	unit.look_at(unit.global_position + to_target, Vector3.UP)

func _point_weapon(target):
	if weapon and target:
		weapon.look_at(target.global_position)

func _telegraph_shot(delta) -> void:
	telegraph_timer.start(telegraph_duration)
	

func _tick_fire(delta: float) -> void:
	if not _has_valid_target() or not player_in_detection_range():
		_enter_state(State.IDLE)
		return

	if not player_in_weapon_range():
		_enter_state(State.CHASE)
		return

	_stop_moving()
	_face_target(delta)
	_point_weapon(target)

	if burst_shots_remaining <= 0:
		_enter_state(State.COOLDOWN)
		return

	burst_interval_timer -= delta

	if burst_interval_timer <= 0.0 and _can_fire(target):
		_fire_once()
		burst_shots_remaining -= 1
		burst_interval_timer = stats.burst_interval

func _fire_once() -> void:
	if not weapon:
		return

	if not weapon.has_method("fire"):
		return

	weapon.call("fire")

func _tick_reposition(delta):
	pass

func _tick_cooldown(delta: float) -> void:
	if not _has_valid_target() or not player_in_detection_range():
		_enter_state(State.IDLE)
		return

	if not player_in_weapon_range():
		_enter_state(State.CHASE)
		return

	_stop_moving()
	_face_target(delta)
	_point_weapon(target)

	cooldown_timer -= delta

	if cooldown_timer <= 0.0:
		_enter_state(State.AIM)

func get_state_name() -> String:
	match state:
		State.IDLE:
			return "IDLE"
		State.CHASE:
			return "CHASE"
		State.AIM:
			return "AIM"
		State.FIRE:
			return "FIRE"
		State.REPOSITION:
			return "REPOSITION"
		State.COOLDOWN:
			return "COOLDOWN"
		_:
			return "UNKNOWN"

func _enter_state(new_state: State) -> void:
	if state == new_state:
		return

	var previous_state: State = state

	if previous_state == State.AIM and new_state != State.FIRE:
		telegraph_timer.stop()

	state = new_state

	match state:
		State.IDLE:
			_stop_moving()
			telegraph_timer.stop()

		State.CHASE:
			telegraph_timer.stop()

		State.AIM:
			_stop_moving()
			telegraph_timer.start(telegraph_duration)

		State.FIRE:
			_stop_moving()
			burst_shots_remaining = stats.burst_count
			burst_interval_timer = 0.0

		State.COOLDOWN:
			_stop_moving()
			cooldown_timer = stats.cooldown_duration


func _debug_state_label():
	state_label.text = get_state_name()
	if target:
		target_label.text = target.name
	else:
		target_label.text = "No target"


func _on_telegraph_timer_timeout() -> void:
	if state != State.AIM:
		return

	if not _has_valid_target() or not player_in_detection_range():
		_enter_state(State.IDLE)
		return

	if not player_in_weapon_range():
		_enter_state(State.CHASE)
		return

	_enter_state(State.FIRE)

func _has_valid_target() -> bool:
	return target != null and is_instance_valid(target)


func _stop_moving() -> void:
	if not unit:
		return

	unit.velocity = Vector3.ZERO
	unit.direction = Vector3.ZERO

func _should_show_laser() -> bool:
	return state == State.AIM or state == State.FIRE


func _distance_to_target(target: Node3D) -> float:
	var a : Vector3 = unit.global_position
	var b : Vector3 = target.global_position

	return a.distance_to(b)


func _can_enter_aim(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false

	var distance := _distance_to_target(target)
	return distance <= stats.weapon_range - aim_enter_margin


func _should_leave_aim(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return true

	var distance := _distance_to_target(target)
	return distance > stats.weapon_range + aim_exit_margin


func _can_fire(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false

	var distance := _distance_to_target(target)

	# Use the tighter range here too, so FIRE does not happen right on the edge.
	return distance <= stats.weapon_range - aim_enter_margin
