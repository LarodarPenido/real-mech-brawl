# mesh_health_bar_3d.gd
extends Node3D
class_name MeshHealthBar3D

@export_range(1, 30, 1) var box_count: int = 10

@export var box_size: Vector3 = Vector3(0.18, 0.08, 0.08)
@export var box_spacing: float = 0.035

## Position relative to the parent unit.
## Put this close to the feet / base of the mesh.
@export var local_offset: Vector3 = Vector3(0.0, 0.25, 0.0)

@export var full_color: Color = Color(0.1, 1.0, 0.25, 1.0)
@export var lost_color: Color = Color(1.0, 0.1, 0.05, 1.0)

## Makes the boxes rotate horizontally toward the active camera.
@export var face_camera: bool = true

var _boxes: Array[MeshInstance3D] = []
var _full_material: StandardMaterial3D
var _lost_material: StandardMaterial3D
var _last_full_boxes: int = -1


func _ready() -> void:
	_full_material = _make_material(full_color)
	_lost_material = _make_material(lost_color)

	_create_boxes()
	update_health(1.0, 1.0)

	set_process(face_camera)


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
	if not face_camera:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var direction_to_camera: Vector3 = camera.global_position - global_position
	direction_to_camera.y = 0.0

	if direction_to_camera.length_squared() < 0.001:
		return

	var target_yaw: float = atan2(direction_to_camera.x, direction_to_camera.z)
	global_rotation.y = target_yaw


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

		box.position = local_offset + Vector3(
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
