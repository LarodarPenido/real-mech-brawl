
extends Camera3D

@onready var world_environment: WorldEnvironment = $"../../../WorldEnvironment"

# Combat camera settings
@export_group("Combat Camera")
@export var follow_offset: Vector3 = Vector3(0.0, 15.0, 12.0)
@export var combat_fov: float = 65.0
@export var camera_target_offset: float = -5.0

#@export var lead_strength: float = 0.65    # fraction of the way toward the cursor
@export var max_lead: float = 16.0          # hard cap on lead distance (world units)
@export var lead_smooth_speed: float = 2.0 # higher = snappier, lower = floatier



var _is_transitioning: bool = false
var _lead_offset: Vector3 = Vector3.ZERO

# Reference to the player — set in _ready via GameState
var _player: Node3D = null


func _ready() -> void:
	#GameState.mode_changed.connect(_on_mode_changed)
	# Wait one frame for player to register
	await get_tree().process_frame
	_player = get_parent().get_parent()


func _physics_process(_delta: float) -> void:
	if _is_transitioning:
		return
	#if GameState.is_overhead:
		#return
	if not _player:
		return

	var focus := _player.global_position #+ _lead_offset
	global_position = focus + follow_offset
	look_at(focus + Vector3(0, camera_target_offset, 0), Vector3.UP)
	#TODO
	global_position += CameraShake.current_offset
