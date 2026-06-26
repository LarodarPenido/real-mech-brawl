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
	if aim_assist.locked_target:
		_target = aim_assist.locked_target
	if _target == null or not is_instance_valid(_target):
		_target = null
		visible = false
		return
	visible = true
	queue_redraw()

	## Only show if primary weapon has ammo
	if not weapon_manager.get_active_primary().is_ready():
		visible = false

func _draw() -> void:
	if camera == null or _target == null or not is_instance_valid(_target):
		return
	if camera.is_position_behind(_target.global_position):
		return
	var screen_pos: Vector2 = camera.unproject_position(_target.global_position)
	draw_circle(screen_pos, dot_radius + outline_radius, outline_color)
	draw_circle(screen_pos, dot_radius, dot_color)


func _on_target_locked(target: Node3D) -> void:
	_target = target


func _on_target_lost() -> void:
	_target = null
