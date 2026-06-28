
extends Control

## Bracket geometry
@export var bracket_arm_length: float = 8.0
@export var bracket_thickness: float = 2.0
@export var bracket_gap_idle: float = 18.0
@export var bracket_gap_cooling: float = 36.0

## Center dot
@export var dot_radius: float = 1.5

## Color — heat states
@export var color_heat_cool: Color = Color(1, 1, 1, 0.9)
@export var color_heat_hot: Color = Color(1, 0.35, 0.25, 0.95)
@export var color_heat_overheated: Color = Color(1.0, 0.08, 0.02, 1.0)

## Cooling feedback
@export_range(0.0, 1.0) var cooling_dim_factor: float = 0.5
@export var color_pulse_outline: Color = Color(1, 1, 0.85, 1.0)  ## Flash when cooling completes
@export var pulse_duration: float = 0.25
@export var pulse_outline_extra_thickness: float = 2.5

## Outline (dark, drawn behind brackets)
@export var outline_color: Color = Color(0, 0, 0, 0.55)
@export var outline_thickness: float = 1.0


## Node References
@onready var player: CharacterBody3D = $"../../Player"


## Missile ammo pips
@export var missile_pip_size: Vector2 = Vector2(8.0, 3.0)
@export var missile_pip_gap: float = 4.0
@export var missile_pip_vertical_offset: float = 34.0

@export var missile_pip_color: Color = Color(0.3, 0.9, 1.0, 0.95)
@export var missile_pip_empty_color: Color = Color(0.3, 0.9, 1.0, 0.2)

@export var missile_show_empty_slots: bool = false

var _missile_launcher: Node = null



## State — lock
var _is_locked: bool = false
var _aim_assist: Node = null
var _camera: Camera3D = null

## State — weapon tracking
var _weapon_manager: Node = null
var _active_primary: Node = null
var _was_cooling_down: bool = false
var _pulse_timer: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_connect_to_player_systems")


func _connect_to_player_systems() -> void:
	if player == null:
		return

	# Aim assist (existing behavior)
	_aim_assist = player.get_node_or_null("AimAssist")
	if _aim_assist:
		_aim_assist.target_locked.connect(_on_target_locked)
		_aim_assist.target_lost.connect(_on_target_lost)
	
	_camera = _find_camera()
	
	# Weapon manager — cache active primary, refresh on swap
	_weapon_manager = player.get_node_or_null("WeaponManager")
	if _weapon_manager:
		_weapon_manager.primary_weapon_changed.connect(_on_primary_changed)
		if _weapon_manager.has_method("get_active_primary"):
			_active_primary = _weapon_manager.get_active_primary()

	_missile_launcher = get_tree().get_first_node_in_group("missile_launcher")

func _on_primary_changed(weapon: Node) -> void:
	_active_primary = weapon
	# Reset cooling tracking so a weapon swap does not trigger a spurious pulse.
	_was_cooling_down = false
	_pulse_timer = 0.0


func _process(delta: float) -> void:
	# Detect cooling-complete transition for the pulse flash.
	var cooling_down: bool = _is_cooling_down()

	if _was_cooling_down and not cooling_down:
		_pulse_timer = pulse_duration

	_was_cooling_down = cooling_down

	if _pulse_timer > 0.0:
		_pulse_timer = max(0.0, _pulse_timer - delta)

	queue_redraw()


func _draw() -> void:
	var pos: Vector2 = _get_reticle_position()

	var heat_ratio: float = _get_heat_ratio()
	var cooling_progress: float = _get_cooling_progress() # 1.0 = ready, 0.0 = just overheated
	var cooling_down: bool = _is_cooling_down()
	var overheated: bool = _is_overheated()
	var pulse_t: float = (_pulse_timer / pulse_duration) if pulse_duration > 0.0 else 0.0

	# Bracket color: heat gradient.
	# Cool = white, hot = red.
	var base_color: Color = color_heat_cool.lerp(color_heat_hot, heat_ratio)

	if overheated:
		base_color = color_heat_overheated

	if cooling_down:
		base_color.a *= cooling_dim_factor

	# Gap opens when overheated, then closes as cooling completes.
	var gap: float = lerp(bracket_gap_cooling, bracket_gap_idle, cooling_progress)

	# Center dot
	draw_circle(pos, dot_radius + outline_thickness + 0.5, outline_color)
	draw_circle(pos, dot_radius, base_color)

	# 4 corner brackets
	_draw_corner(pos + Vector2(-gap, -gap), Vector2.RIGHT, Vector2.DOWN,  base_color, pulse_t)
	_draw_corner(pos + Vector2( gap, -gap), Vector2.LEFT,  Vector2.DOWN,  base_color, pulse_t)
	_draw_corner(pos + Vector2(-gap,  gap), Vector2.RIGHT, Vector2.UP,    base_color, pulse_t)
	_draw_corner(pos + Vector2( gap,  gap), Vector2.LEFT,  Vector2.UP,    base_color, pulse_t)

	# Missile ammo pips
	_draw_missile_pips(pos)


func _draw_corner(corner: Vector2, arm1: Vector2, arm2: Vector2, col: Color, pulse_t: float) -> void:
	var end1: Vector2 = corner + arm1 * bracket_arm_length
	var end2: Vector2 = corner + arm2 * bracket_arm_length

	# Bright pulse outline (drawn first / outermost), fades with pulse_t
	if pulse_t > 0.0:
		var pulse_col: Color = color_pulse_outline
		pulse_col.a *= pulse_t
		var pulse_thickness: float = bracket_thickness + (outline_thickness + pulse_outline_extra_thickness) * 2.0
		draw_line(corner, end1, pulse_col, pulse_thickness)
		draw_line(corner, end2, pulse_col, pulse_thickness)

	# Dark outline
	draw_line(corner, end1, outline_color, bracket_thickness + outline_thickness * 2.0)
	draw_line(corner, end2, outline_color, bracket_thickness + outline_thickness * 2.0)

	# Main stroke
	draw_line(corner, end1, col, bracket_thickness)
	draw_line(corner, end2, col, bracket_thickness)



func _draw_missile_pips(reticle_pos: Vector2) -> void:
	var ammo: int = _get_missile_ammo()
	var max_ammo: int = _get_missile_max_ammo()

	var draw_count: int = ammo

	if missile_show_empty_slots:
		draw_count = max_ammo

	if draw_count <= 0:
		return

	var total_width: float = draw_count * missile_pip_size.x + max(draw_count - 1, 0) * missile_pip_gap

	var start_x: float = reticle_pos.x - total_width * 0.5
	var y: float = reticle_pos.y + missile_pip_vertical_offset

	for i in range(draw_count):
		var pip_pos := Vector2(
			start_x + i * (missile_pip_size.x + missile_pip_gap),
			y
		)

		var rect := Rect2(pip_pos, missile_pip_size)

		var col := missile_pip_color

		if missile_show_empty_slots and i >= ammo:
			col = missile_pip_empty_color

		# Optional outline
		draw_rect(
			Rect2(pip_pos - Vector2.ONE, missile_pip_size + Vector2.ONE * 2.0),
			outline_color
		)

		draw_rect(rect, col)


func _get_missile_ammo() -> int:
	if not is_instance_valid(_missile_launcher):
		_missile_launcher = get_tree().get_first_node_in_group("missile_launcher")

	if not is_instance_valid(_missile_launcher):
		return 0

	if "ammo" in _missile_launcher:
		return max(int(_missile_launcher.ammo), 0)

	return 0


func _get_missile_max_ammo() -> int:
	if not is_instance_valid(_missile_launcher):
		_missile_launcher = get_tree().get_first_node_in_group("missile_launcher")

	if not is_instance_valid(_missile_launcher):
		return 0

	if "max_ammo" in _missile_launcher:
		return max(int(_missile_launcher.max_ammo), 0)

	return 0


# --- Weapon state queries (duck-typed; works with both MG-style and railgun-style APIs) ---

func _is_overheated() -> bool:
	if _active_primary == null or not is_instance_valid(_active_primary):
		return false

	if _active_primary.has_method("is_overheated_now"):
		return _active_primary.is_overheated_now()

	if "is_overheated" in _active_primary:
		return bool(_active_primary.is_overheated)

	return false


func _is_cooling_down() -> bool:
	if _active_primary == null or not is_instance_valid(_active_primary):
		return false

	if _active_primary.has_method("is_cooling_down"):
		return _active_primary.is_cooling_down()

	if "is_overheated" in _active_primary:
		return bool(_active_primary.is_overheated)

	return false


func _get_cooling_progress() -> float:
	# Returns:
	# 1.0 = ready / not cooling
	# 0.0 = cooling just started

	if _active_primary == null or not is_instance_valid(_active_primary):
		return 1.0

	if _active_primary.has_method("get_cooling_progress"):
		return _active_primary.get_cooling_progress()

	# Backward compatibility with old reload weapons.
	if _active_primary.has_method("get_reload_progress"):
		return _active_primary.get_reload_progress()

	if "is_reloading" in _active_primary and "reload_timer" in _active_primary and "reload_time" in _active_primary:
		if not _active_primary.is_reloading:
			return 1.0

		var rt: float = float(_active_primary.reload_time)
		if rt <= 0.0:
			return 1.0

		return 1.0 - (float(_active_primary.reload_timer) / rt)

	return 1.0


func _get_heat_ratio() -> float:
	# Returns:
	# 0.0 = cool
	# 1.0 = max heat

	if _active_primary == null or not is_instance_valid(_active_primary):
		return 0.0

	if _active_primary.has_method("get_heat_ratio"):
		return _active_primary.get_heat_ratio()

	if "current_heat" in _active_primary and "max_heat" in _active_primary:
		var max_h: float = float(_active_primary.max_heat)

		if max_h <= 0.0:
			return 0.0

		return clampf(float(_active_primary.current_heat) / max_h, 0.0, 1.0)

	# Backward compatibility with old ammo weapons.
	if "current_ammo" in _active_primary and "max_ammo" in _active_primary:
		var max_a: float = float(_active_primary.max_ammo)

		if max_a <= 0.0:
			return 0.0

		return 1.0 - clampf(float(_active_primary.current_ammo) / max_a, 0.0, 1.0)

	return 0.0



func _get_reticle_position() -> Vector2:
	if _aim_assist == null or not is_instance_valid(_aim_assist):
		return get_viewport().get_mouse_position()

	if _aim_assist.has_method("has_lock") and not _aim_assist.has_lock():
		return get_viewport().get_mouse_position()

	var camera := _get_camera()
	if camera == null:
		return get_viewport().get_mouse_position()

	var lock_position: Vector3 = _get_lock_world_position()
	if lock_position == Vector3.ZERO:
		return get_viewport().get_mouse_position()

	if camera.is_position_behind(lock_position):
		return get_viewport().get_mouse_position()

	return camera.unproject_position(lock_position)


func _get_lock_world_position() -> Vector3:
	if _aim_assist == null or not is_instance_valid(_aim_assist):
		return Vector3.ZERO

	if _aim_assist.has_method("get_fire_point"):
		return _aim_assist.get_fire_point()

	if "locked_target" in _aim_assist:
		var target: Node = _aim_assist.locked_target
		if target is Node3D and is_instance_valid(target):
			var target_3d: Node3D = target
			return target_3d.global_position

	return Vector3.ZERO


func _get_camera() -> Camera3D:
	if _camera != null and is_instance_valid(_camera):
		return _camera

	_camera = _find_camera()
	return _camera


func _find_camera() -> Camera3D:
	if _aim_assist != null and is_instance_valid(_aim_assist) and "camera" in _aim_assist:
		var aim_camera: Camera3D = _aim_assist.camera
		if aim_camera != null and is_instance_valid(aim_camera):
			return aim_camera

	if player != null:
		var player_camera := player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
		if player_camera != null:
			return player_camera

	return get_viewport().get_camera_3d()



func _on_target_locked(_target: Node3D) -> void:
	_is_locked = true


func _on_target_lost() -> void:
	_is_locked = false
