# laser_sight.gd - shows a mesh from muzzle point to target
extends Node3D

@export var lifetime: float = 0.05
@export var width: float = 0.24
@export var color: Color = Color(1.0, 2.0, 1.5, 1.0)
@export var material: Material

## Blink behavior
@export var min_blink_hz: float = 2.0      # Slow blink at start of aim
@export var max_blink_hz: float = 14.0     # Fast blink right before firing
@export var off_alpha: float = 0.08        # Use 0.0 for fully invisible
@export var on_alpha: float = 1.0
@export var solid_while_firing: bool = true

var _mesh: MeshInstance3D
var _elapsed: float = 0.0
var _active: bool = false
var _local_material: BaseMaterial3D

var _fire_progress: float = 0.0 # 0.0 = far from firing, 1.0 = about to fire
var _blink_phase: float = 0.0
var _force_solid: bool = false


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


func update_laser_sight(from: Vector3, to: Vector3, fire_progress: float = 0.0, force_solid: bool = false) -> void:
	var offset := to - from
	var distance := offset.length()

	if distance <= 0.001:
		return

	_fire_progress = clampf(fire_progress, 0.0, 1.0)
	_force_solid = force_solid

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

	_active = true
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return

	if _force_solid and solid_while_firing:
		_set_laser_alpha(on_alpha)
		return

	var blink_hz := lerpf(min_blink_hz, max_blink_hz, _fire_progress)

	_blink_phase += delta * blink_hz

	# Keeps the number small forever.
	if _blink_phase >= 1.0:
		_blink_phase -= floorf(_blink_phase)

	# Square blink: on for half the cycle, off for half.
	var is_on := _blink_phase < 0.5
	var alpha := on_alpha if is_on else off_alpha

	_set_laser_alpha(alpha)


func _set_laser_alpha(alpha: float) -> void:
	if not _local_material:
		_mesh.visible = alpha > 0.01
		return

	var albedo := _local_material.albedo_color
	albedo.a = alpha
	_local_material.albedo_color = albedo

	if _local_material is StandardMaterial3D:
		var mat := _local_material as StandardMaterial3D
		var emission := color
		emission.a = alpha
		mat.emission = emission

	_mesh.visible = alpha > 0.01


func hide_laser_sight() -> void:
	_active = false
	visible = false
	set_process(false)
