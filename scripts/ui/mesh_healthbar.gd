# mesh_health_bar_3d.gd
extends Node3D
class_name MeshHealthBar3D

@export_range(1, 30, 1) var box_count: int = 10

@export var box_size: Vector3 = Vector3(0.18, 0.08, 0.08)
@export var box_spacing: float = 0.035

## Position relative to the parent unit.

@export var follow_target: Node3D
@export var anchor_name: StringName = &"HealthBarAnchor"

## Small final adjustment only.
## Usually leave this as Vector3.ZERO.
@export var world_offset: Vector3 = Vector3.ZERO

@export var fixed_rotation_degrees: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var follow_in_physics: bool = true



@export var full_color: Color = Color(0.1, 1.0, 0.25, 1.0)
@export var lost_color: Color = Color(1.0, 0.1, 0.05, 1.0)

## Makes the boxes rotate horizontally toward the active camera.
#@export var face_camera: bool = true

var _boxes: Array[MeshInstance3D] = []
var _full_material: StandardMaterial3D
var _lost_material: StandardMaterial3D
var _last_full_boxes: int = -1


func _ready() -> void:
	top_level = true

	if follow_target == null:
		_find_follow_target()

	_full_material = _make_material(full_color)
	_lost_material = _make_material(lost_color)

	_create_boxes()
	update_health(1.0, 1.0)

	call_deferred("_update_world_transform")

	set_process(not follow_in_physics)
	set_physics_process(follow_in_physics)


func update_health(current_health: float, max_health: float) -> void:
	if max_health <= 0.0:
		return

	var health_ratio: float = clamp(current_health / max_health, 0.0, 1.0)
	var full_boxes: int = int(ceil(health_ratio * float(box_count)))

	if full_boxes == _last_full_boxes:
		return

	_last_full_boxes = full_boxes

	for i in range(_boxes.size()):
		if i < full_boxes:
			_boxes[i].material_override = _full_material
		else:
			_boxes[i].material_override = _lost_material


func _process(_delta: float) -> void:
	_update_world_transform()


func _physics_process(_delta: float) -> void:
	_update_world_transform()


func _update_world_transform() -> void:
	if not is_instance_valid(follow_target):
		return

	global_position = follow_target.global_position + world_offset
	global_rotation_degrees = fixed_rotation_degrees


func _create_boxes() -> void:
	for child in get_children():
		child.queue_free()

	_boxes.clear()

	var total_width: float = float(box_count) * box_size.x + float(box_count - 1) * box_spacing
	var start_x: float = -total_width * 0.5 + box_size.x * 0.5

	for i in range(box_count):
		var box := MeshInstance3D.new()
		box.name = "HealthBox_%02d" % i

		var mesh := BoxMesh.new()
		mesh.size = box_size
		box.mesh = mesh

		box.position = Vector3(
			start_x + float(i) * (box_size.x + box_spacing),
			0.0,
			0.0
		)

		add_child(box)
		_boxes.append(box)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _find_follow_target() -> void:
	var parent := get_parent()

	if parent == null:
		return

	var anchor := parent.find_child(str(anchor_name), true, false) as Node3D

	if anchor != null:
		follow_target = anchor
	else:
		follow_target = parent as Node3D
