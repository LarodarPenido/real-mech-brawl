# AimAssistIndicator — draws a dot on the aim-assist locked target.
# Distinct from the missile lock diamond (orange, world-target).
# Add as a Control child of HUD/CombatHUD, same level as missile_lock_reticle.
extends Control

@export var camera: Camera3D

@export var aim_assist: Node

@export var weapon_manager: Node

## Appearance
@export var dot_radius: float = 5.0
@export var dot_color: Color = Color(1.0, 0.08, 0.08, 1.0)   # Bright red
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.6)
@export var outline_radius: float = 1.5

var _target: Node3D = null

## References

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(_delta: float) -> void:
	if aim_assist == null:
		_target = null
		visible = false
		return

	if not aim_assist.has_lock():
		_target = null
		visible = false
		return

	_target = aim_assist.locked_target

	if _target == null or not is_instance_valid(_target):
		_target = null
		visible = false
		return

	if weapon_manager == null:
		visible = false
		return

	var weapon = weapon_manager.get_active_primary()
	if weapon == null or not weapon.is_ready():
		visible = false
		return

	visible = true
	queue_redraw()

func _draw() -> void:
	if camera == null or _target == null or not is_instance_valid(_target):
		return

	var aim_point: Vector3 = _target.global_position

	if aim_assist != null and aim_assist.has_method("get_fire_point"):
		aim_point = aim_assist.get_fire_point()

	if camera.is_position_behind(aim_point):
		return

	var screen_pos: Vector2 = camera.unproject_position(aim_point)

	draw_circle(screen_pos, dot_radius + outline_radius, outline_color)
	draw_circle(screen_pos, dot_radius, dot_color)


func _on_target_locked(target: Node3D) -> void:
	_target = target


func _on_target_lost() -> void:
	_target = null
