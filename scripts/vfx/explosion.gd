# mesh_explosion_vfx.gd
extends Node3D
class_name MeshExplosionVFX

@export var default_lifetime: float = 0.65
@export var default_radius: float = 4.0
@export var vertical_bias: float = 0.65

@export var smoke_blob_count: int = 5
@export var shard_count: int = 8
@export var use_scorch_mark: bool = true

@export var flash_color: Color = Color(2.0, 1.5, 0.9, 1.0)
@export var fire_color: Color = Color(2.0, 0.62, 0.15, 0.85)
@export var smoke_color: Color = Color(0.18, 0.16, 0.14, 0.45)
@export var shard_color: Color = Color(1.0, 0.45, 0.12, 0.9)
@export var scorch_color: Color = Color(0.04, 0.035, 0.03, 0.45)

var _flash: MeshInstance3D
var _fireball: MeshInstance3D
var _ring: MeshInstance3D
var _scorch: MeshInstance3D

var _smoke_blobs: Array[MeshInstance3D] = []
var _shards: Array[MeshInstance3D] = []

var _tween: Tween
var _rng := RandomNumberGenerator.new()

var _built: bool = false
var _active: bool = false
var _radius: float
var _lifetime: float


func _ready() -> void:
	visible = false
	set_process(false)


func on_pool_created() -> void:
	_rng.randomize()
	_build()
	visible = false
	set_process(false)


func on_pool_spawned(args: Dictionary = {}) -> void:
	_build()

	_radius = default_radius
	_lifetime = default_lifetime

	if args.has("radius"):
		_radius = float(args["radius"])

	if args.has("lifetime"):
		_lifetime = float(args["lifetime"])

	_active = true
	visible = true
	set_process(false)

	_play()


func on_pool_despawned() -> void:
	_active = false
	visible = false
	set_process(false)

	if _tween:
		_tween.kill()
		_tween = null


func _play() -> void:
	if _tween:
		_tween.kill()

	_reset_all()

	_tween = create_tween()
	_tween.set_parallel(true)

	_animate_flash()
	_animate_fireball()
	_animate_ring()
	_animate_smoke()
	_animate_shards()

	if use_scorch_mark and _scorch:
		_animate_scorch()

	_tween.finished.connect(_finish)


func _finish() -> void:
	if not _active:
		return

	VFXPool.release(self)


func _build() -> void:
	if _built:
		return

	_flash = _make_mesh(_make_sphere_mesh(12, 6), _make_material(flash_color, true, 2.5))
	_fireball = _make_mesh(_make_sphere_mesh(16, 8), _make_material(fire_color, true, 1.5))

	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 20
	torus.ring_segments = 8
	_ring = _make_mesh(torus, _make_material(flash_color, true, 1.8))

	for i in smoke_blob_count:
		var smoke := _make_mesh(_make_sphere_mesh(10, 5), _make_material(smoke_color, false, 0.0))
		_smoke_blobs.append(smoke)

	for i in shard_count:
		var shard := _make_mesh(BoxMesh.new(), _make_material(shard_color, true, 1.2))
		_shards.append(shard)

	if use_scorch_mark:
		var scorch_mesh := CylinderMesh.new()
		scorch_mesh.height = 0.025
		scorch_mesh.radial_segments = 18
		_scorch = _make_mesh(scorch_mesh, _make_material(scorch_color, false, 0.0))

	_built = true


func _make_sphere_mesh(radial_segments: int, rings: int) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	return sphere


func _make_mesh(mesh: Mesh, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _make_material(color: Color, emissive: bool, emission_energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if emissive:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b, 1.0)
		mat.emission_energy_multiplier = emission_energy

	return mat


func _reset_all() -> void:
	_reset_piece(_flash, flash_color, 2.5)
	_flash.position = Vector3.ZERO
	_flash.scale = Vector3.ONE * 0.05
	_flash.visible = true

	_reset_piece(_fireball, fire_color, 1.5)
	_fireball.position = Vector3.ZERO
	_fireball.scale = Vector3.ONE * 0.15
	_fireball.visible = true

	_reset_piece(_ring, flash_color, 1.8)
	_ring.position = Vector3(0.0, 0.05, 0.0)
	_ring.scale = Vector3.ONE * 0.05
	_ring.rotation_degrees = Vector3.ZERO
	_ring.visible = true

	for smoke in _smoke_blobs:
		_reset_piece(smoke, smoke_color, 0.0)
		smoke.position = Vector3.ZERO
		smoke.scale = Vector3.ONE * 0.1
		smoke.visible = true

	for shard in _shards:
		_reset_piece(shard, shard_color, 1.2)
		shard.position = Vector3.ZERO
		shard.scale = Vector3.ONE * 0.05
		shard.visible = true

	if _scorch:
		_reset_piece(_scorch, scorch_color, 0.0)
		_scorch.position = Vector3(0.0, 0.01, 0.0)
		_scorch.scale = Vector3(_radius * 0.35, 1.0, _radius * 0.35)
		_scorch.visible = use_scorch_mark


func _reset_piece(piece: MeshInstance3D, color: Color, emission_energy: float) -> void:
	if piece == null:
		return

	var mat := piece.material_override as StandardMaterial3D
	if mat == null:
		return

	mat.albedo_color = color

	if mat.emission_enabled:
		mat.emission = Color(color.r, color.g, color.b, 1.0)
		mat.emission_energy_multiplier = emission_energy


func _animate_flash() -> void:
	var duration := _lifetime * 0.16
	var mat := _flash.material_override as StandardMaterial3D

	var transparent := flash_color
	transparent.a = 0.0

	_tween.tween_property(_flash, "scale", Vector3.ONE * _radius * 0.95, duration)
	_tween.tween_property(mat, "albedo_color", transparent, duration)
	_tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration)


func _animate_fireball() -> void:
	var duration := _lifetime * 0.45
	var mat := _fireball.material_override as StandardMaterial3D

	var transparent := fire_color
	transparent.a = 0.0

	_tween.tween_property(_fireball, "scale", Vector3.ONE * _radius * 0.72, duration)
	_tween.tween_property(mat, "albedo_color", transparent, duration)
	_tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration)


func _animate_ring() -> void:
	var duration := _lifetime * 0.5
	var mat := _ring.material_override as StandardMaterial3D

	var transparent := flash_color
	transparent.a = 0.0

	_tween.tween_property(_ring, "scale", Vector3.ONE * _radius * 1.25, duration)
	_tween.tween_property(mat, "albedo_color", transparent, duration)
	_tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration)


func _animate_smoke() -> void:
	for smoke in _smoke_blobs:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(_radius * 0.25, _radius * 0.75)
		var height := _rng.randf_range(0.05, _radius * vertical_bias)

		var end_pos := Vector3(
			cos(angle) * distance,
			height,
			sin(angle) * distance
		)

		var final_size := _rng.randf_range(_radius * 0.35, _radius * 0.75)
		var duration := _lifetime * _rng.randf_range(0.75, 1.0)

		var mat := smoke.material_override as StandardMaterial3D
		var transparent := smoke_color
		transparent.a = 0.0

		_tween.tween_property(smoke, "position", end_pos, duration).set_delay(_lifetime * 0.05)
		_tween.tween_property(smoke, "scale", Vector3.ONE * final_size, duration).set_delay(_lifetime * 0.05)
		_tween.tween_property(mat, "albedo_color", transparent, duration).set_delay(_lifetime * 0.12)


func _animate_shards() -> void:
	for shard in _shards:
		var angle := _rng.randf_range(0.0, TAU)

		var dir := Vector3(
			cos(angle),
			_rng.randf_range(0.05, 0.45),
			sin(angle)
		).normalized()

		var distance := _rng.randf_range(_radius * 0.55, _radius * 1.35)
		var end_pos := dir * distance

		var duration := _lifetime * _rng.randf_range(0.35, 0.75)

		shard.rotation = Vector3(
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI)
		)

		shard.scale = Vector3(
			_rng.randf_range(0.04, 0.09) * _radius,
			_rng.randf_range(0.04, 0.09) * _radius,
			_rng.randf_range(0.12, 0.28) * _radius
		)

		var mat := shard.material_override as StandardMaterial3D
		var transparent := shard_color
		transparent.a = 0.0

		_tween.tween_property(shard, "position", end_pos, duration)
		_tween.tween_property(shard, "scale", Vector3.ZERO, duration).set_delay(duration * 0.35)
		_tween.tween_property(mat, "albedo_color", transparent, duration)
		_tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration)


func _animate_scorch() -> void:
	var mat := _scorch.material_override as StandardMaterial3D

	var transparent := scorch_color
	transparent.a = 0.0

	_tween.tween_property(_scorch, "scale", Vector3(_radius * 0.65, 1.0, _radius * 0.65), _lifetime)
	_tween.tween_property(mat, "albedo_color", transparent, _lifetime)
