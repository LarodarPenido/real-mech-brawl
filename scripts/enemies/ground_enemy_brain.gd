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

# --- Burst fire pacing ---
var burst_shots_remaining: int = 0
var burst_interval_timer: float = 0.0
var cooldown_timer: float = 0.0

func _ready() -> void:
	unit = get_parent()
	player = get_tree().get_first_node_in_group("player")
	
	
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
	if not target or not player_in_detection_range():
		_enter_state(State.IDLE)
		return

	_point_weapon(target)

	if player_in_weapon_range():
		_enter_state(State.AIM)
		return
	elif player_in_detection_range() and not player_in_weapon_range():
		# Move toward target 
		var direction: Vector3 = target.global_position - unit.global_position
		direction.y = 0.0
		if direction.length() < 0.001:
			_enter_state(State.AIM)
			return



func _tick_aim(delta) -> void:
	if not target or not player_in_detection_range():
		_enter_state(State.IDLE)
		return
	if player_in_detection_range() and not player_in_weapon_range():
		_enter_state(State.CHASE)
		return

	_face_target(delta)
	_point_weapon(target)
	
	_telegraph_shot(delta)
	

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
	


func _tick_fire(delta) -> void:

	burst_shots_remaining = unit.stats.burst_count
	burst_interval_timer = 0.0
	cooldown_timer = 0.0
	
	# Burst-fire rhythm
	if burst_shots_remaining > 0:
		burst_interval_timer -= delta
		if burst_interval_timer <= 0.0:
			_fire_once()
			burst_shots_remaining -= 1
			burst_interval_timer = unit.stats.burst_interval
			if burst_shots_remaining == 0:
				cooldown_timer = unit.stats.cooldown_duration
	else:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			burst_shots_remaining = unit.stats.burst_count
			burst_interval_timer = 0.0

func _fire_once() -> void:
	if not weapon:
		return
	weapon.fire()

func _tick_reposition(delta):
	pass

func _tick_cooldown(delta):
	pass

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

	state = new_state

	match state:
		State.FIRE:
			burst_shots_remaining = unit.stats.burst_count
			burst_interval_timer = 0.0
			cooldown_timer = unit.stats.cooldown_duration


func _debug_state_label():
	state_label.text = get_state_name()
	if target:
		target_label.text = target.name
	else:
		target_label.text = "No target"


func _on_telegraph_timer_timeout() -> void:
	_enter_state(State.FIRE)
