extends Node3D

@export var lifetime: float = 0.05
@export var width: float = 0.24
@export var color: Color = Color(1.0, 2.0, 1.5, 1.0)
@export var material: Material

var _mesh: MeshInstance3D
var _elapsed: float = 0.0
var _active: bool = false
var _local_material: BaseMaterial3D


func _ready() -> void:
	_create_mesh()
	visible = false
	set_process(false)


func _create_mesh() -> void:
	_mesh = MeshInstance3D.new()
	add_child(_mesh)

	var cylinder := CylinderMesh.new()
	cylinder.top_radius = width
	cylinder.bottom_radius = width
	cylinder.height = 1.0

	if material:
		var duplicated := material.duplicate()
		cylinder.material = duplicated
		_local_material = duplicated as BaseMaterial3D
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cylinder.material = mat
		_local_material = mat

	_mesh.mesh = cylinder
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func fire(from: Vector3, to: Vector3) -> void:
	var offset := to - from
	var distance := offset.length()

	if distance <= 0.001:
		return

	var midpoint := (from + to) * 0.5
	var direction := offset / distance

	global_position = midpoint

	var up := Vector3.UP
	if abs(direction.dot(Vector3.UP)) > 0.98:
		up = Vector3.FORWARD

	look_at(global_position + direction, up)

	# Apply fixed cylinder correction without accumulating from previous shots.
	basis = basis * Basis(Vector3.RIGHT, PI / 2.0)

	_mesh.scale = Vector3(1.0, distance, 1.0)

	_elapsed = 0.0
	_active = true
	visible = true
	set_process(true)

	if _local_material:
		_local_material.albedo_color.a = 1.0
		_local_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta

	var alpha := 1.0 - (_elapsed / lifetime)
	alpha = clampf(alpha, 0.0, 1.0)

	if _local_material:
		_local_material.albedo_color.a = alpha

	if _elapsed >= lifetime:
		_active = false
		visible = false
		set_process(false)


func rotation_object_local_safe(axis: Vector3, angle: float) -> void:
	# Reset basis before rotating, otherwise repeated fire() calls keep accumulating rotation.
	transform.basis = Basis()
	rotate_object_local(axis, angle)
