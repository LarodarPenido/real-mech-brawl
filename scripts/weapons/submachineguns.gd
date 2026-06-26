# Machinegun — hitscan primary weapon. Ported from Canyon Strike.

extends Node3D

## Fire Rate
@export var fire_rate: float = 5.0  # Shots per second

## Heat
@export var max_heat: float = 100.0
@export var heat_per_shot: float = 4.0
@export var cooling_rate: float = 45.0
@export var overheated_cooling_rate: float = 35.0

## Weapon becomes usable again when heat drops below this % of max_heat.
## 0.35 = usable again at 35 heat if max_heat is 100.
@export_range(0.0, 1.0, 0.01) var overheat_recovery_ratio: float = 0.35

## Small delay after the last shot before normal cooling starts.
@export var cooling_delay_after_shot: float = 0.15

var current_heat: float = 0.0
var is_overheated: bool = false
var _cooling_delay_timer: float = 0.0
var _trigger_held: bool = false

## Accuracy
@export var spread: float = 4.0  # Degrees of spread cone

## Damage
@export var damage: float = 60.0
@export var max_range: float = 80.0

## Visual Effect Scenes

const IMPACT_POOL_ID: StringName = &"machinegun_impact"
const CASING_POOL_ID: StringName = &"machinegun_casing"
const MUZZLE_FLASH_POOL_ID: StringName = &"machinegun_muzzle_flare"




@export var tracer_nodes: Array[Node3D] = []

#@export var tracer_scene: PackedScene
@export var impact_scene: PackedScene
@export var muzzle_flash_scene: PackedScene
@export var casing_scene: PackedScene
@export var screen_shake_strength: float = 0.6
@export var screen_shake_duration: float = 0.12

## Muzzle + casing points (Marker3D children)
@export var muzzle_points: Array[Node3D] = []
@export var casing_points: Array[Node3D] = []

var _barrel_index: int = 0

## References (set by WeaponManager)
var _aim_assist: Node
var _owner_node: Node3D

## State
var _time_since_last_shot: float = 0.0
var _is_firing: bool = false
var was_firing: bool = false
var _loop_handle: AudioStreamPlayer3D = null

## Collision mask: Terrain (L1, bit 0) + EnemyUnits (L3, bit 2) + Destructibles (L8, bit 7)
## = 0b10000101 = 133. Layer 8 includes unit missiles, so the gun can shoot them down.
const COLLISION_MASK: int = 0b10000101


func _ready() -> void:
	current_heat = 0.0
	is_overheated = false

	if impact_scene:
		VFXPool.register_pool(IMPACT_POOL_ID, impact_scene, 32, false)

	if casing_scene:
		VFXPool.register_pool(CASING_POOL_ID, casing_scene, 48, false)

	if muzzle_flash_scene:
		VFXPool.register_pool(MUZZLE_FLASH_POOL_ID, muzzle_flash_scene, 8, false)


func _process(delta: float) -> void:
	_update_heat(delta)

func _physics_process(_delta: float) -> void:
	pass
	# Weapon tracks the target point (cursor position on ground, or lock if present).
	#var target_pos := _get_target_position()
	#if target_pos.distance_squared_to(global_position) > 0.01:
		#look_at(target_pos)

	# TODO audio
	#if _is_firing:
		#AudioManager.move_loop("machinegun_02", _get_muzzle_position())

func set_aim_assist(aim_assist: Node) -> void:
	_aim_assist = aim_assist


func set_owner_node(node: Node3D) -> void:
	_owner_node = node


func trigger_held(delta: float) -> void:
	_trigger_held = true

	if not _can_fire_from_heat():
		_is_firing = false
		was_firing = false
		_time_since_last_shot += delta
		return

	_is_firing = true
	_time_since_last_shot += delta

	## TODO AUDIO: start sounds on first shot
	#if not was_firing:
		#was_firing = true
		#AudioManager.start_loop("machinegun_02", global_position)

	var fire_interval := 1.0 / maxf(fire_rate, 0.001)

	if _time_since_last_shot >= fire_interval:
		_fire()
		_time_since_last_shot = 0.0


func trigger_released(delta: float) -> void:
	_trigger_held = false
	_is_firing = false
	was_firing = false

	# Keep accumulating time so first shot is instant when trigger is pressed again.
	_time_since_last_shot += delta

	#AudioManager.stop_loop("machinegun_02")

func _fire() -> void:
	CameraShake.shake(screen_shake_strength, screen_shake_duration)

	_add_heat_from_shot()

	if is_overheated:
		_is_firing = false

	var muzzle_pos := _get_muzzle_position()
	var target_pos := _get_target_position()

	var ray_dir := (target_pos - muzzle_pos).normalized()
	var spread_direction := _apply_spread(ray_dir)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		muzzle_pos,
		muzzle_pos + spread_direction * max_range
	)

	query.exclude = [_owner_node] if _owner_node else []
	query.collision_mask = COLLISION_MASK

	var result := space_state.intersect_ray(query)

	var hit_point: Vector3
	var hit_normal := Vector3.UP
	var hit_target: Node3D = null

	if result:
		hit_point = result.position
		hit_normal = result.normal
		hit_target = result.collider as Node3D

		if hit_target and hit_target.has_method("take_damage"):
			#print("target hit:", hit_target)
			hit_target.take_damage(damage, "player", _owner_node, hit_point)
	else:
		hit_point = muzzle_pos + spread_direction * max_range

	_show_tracer(muzzle_pos, hit_point)
	_spawn_muzzle_flash(muzzle_pos)
	_spawn_casing()

	if result:
		_spawn_impact(hit_point, hit_normal)

	# Alternate barrels
	_barrel_index = (_barrel_index + 1) % max(muzzle_points.size(), 1)

func _add_heat_from_shot() -> void:
	current_heat += heat_per_shot
	current_heat = clampf(current_heat, 0.0, max_heat)

	_cooling_delay_timer = cooling_delay_after_shot

	if current_heat >= max_heat:
		current_heat = max_heat
		is_overheated = true
		_is_firing = false
		was_firing = false

		#TODO overheat sound/effect
		#AudioManager.stop_loop("machinegun_02")


func _update_heat(delta: float) -> void:
	if current_heat <= 0.0:
		current_heat = 0.0
		return

	var should_cool := false

	if is_overheated:
		# Overheated weapons cool even if the trigger is still held.
		should_cool = true
	elif not _trigger_held:
		# Normal cooling only happens when player stops firing.
		should_cool = true

	if not should_cool:
		return

	if not is_overheated and _cooling_delay_timer > 0.0:
		_cooling_delay_timer -= delta
		return

	var rate := cooling_rate

	if is_overheated:
		rate = overheated_cooling_rate

	current_heat -= rate * delta
	current_heat = clampf(current_heat, 0.0, max_heat)

	if is_overheated:
		var recovery_heat := max_heat * overheat_recovery_ratio

		if current_heat <= recovery_heat:
			is_overheated = false
			# Let the gun fire immediately after recovery if the trigger is still held.
			_time_since_last_shot = 1.0 / maxf(fire_rate, 0.001)


func _can_fire_from_heat() -> bool:
	if is_overheated:
		return false

	if current_heat >= max_heat:
		is_overheated = true
		return false

	return true


func get_heat_ratio() -> float:
	if max_heat <= 0.0:
		return 0.0

	return clampf(current_heat / max_heat, 0.0, 1.0)


func _get_muzzle_position() -> Vector3:
	if muzzle_points.size() > 0:
		var point := muzzle_points[_barrel_index]
		if point:
			return point.global_position

	if _owner_node:
		return _owner_node.global_position + Vector3(0, 0.5, 0)

	return global_position

func _get_target_position() -> Vector3:
	if _aim_assist and _aim_assist.has_lock():
		return _aim_assist.get_fire_point()

	# Use player's aim point (cursor ground position)
	if _owner_node and "current_aim_point" in _owner_node:
		return _owner_node.current_aim_point

	# Fallback: fire forward
	return global_position - global_transform.basis.z * max_range


func _apply_spread(direction: Vector3) -> Vector3:
	var spread_rad := deg_to_rad(spread)
	var random_angle := randf() * TAU
	var random_spread := randf() * spread_rad

	var up := Vector3.UP
	if abs(direction.dot(up)) > 0.99:
		up = Vector3.RIGHT

	var right := direction.cross(up).normalized()
	var actual_up := right.cross(direction).normalized()

	var offset := right * cos(random_angle) + actual_up * sin(random_angle)
	return (direction + offset * tan(random_spread)).normalized()


func _show_tracer(from: Vector3, to: Vector3) -> void:
	if tracer_nodes.is_empty():
		return

	var tracer := tracer_nodes[_barrel_index]
	if tracer == null:
		return

	if tracer.has_method("fire"):
		tracer.fire(from, to)


func _spawn_muzzle_flash(pos: Vector3) -> void:
	if not muzzle_flash_scene:
		return

	var spawn_position := pos
	var spawn_basis := global_transform.basis

	if muzzle_points.size() > 0:
		var point := muzzle_points[_barrel_index]
		if point:
			spawn_position = point.global_position
			spawn_basis = point.global_transform.basis

	var flash := VFXPool.spawn(
		MUZZLE_FLASH_POOL_ID,
		spawn_position,
		spawn_basis,
		{
			"target": _get_target_position()
		}
	)

	if flash == null:
		return


func _spawn_casing(_pos: Vector3 = Vector3.ZERO) -> void:
	if not casing_scene:
		return

	var spawn_position := global_position
	var spawn_basis := global_transform.basis

	if casing_points.size() > 0:
		var point := casing_points[_barrel_index]
		if point:
			spawn_position = point.global_position
			spawn_basis = point.global_transform.basis
	elif _owner_node:
		spawn_position = _owner_node.global_position + Vector3(0.5, 0.3, 0.0)

	var eject_dir := global_transform.basis.x + Vector3.UP * 0.5
	eject_dir = eject_dir.normalized()

	var casing := VFXPool.spawn(
		CASING_POOL_ID,
		spawn_position,
		spawn_basis,
		{
			"eject_dir": eject_dir
		}
	)

	if casing == null:
		return


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	if not impact_scene:
		return

	var basis := _basis_from_surface_normal(normal)

	var impact := VFXPool.spawn(
		IMPACT_POOL_ID,
		pos,
		basis,
		{
			"normal": normal
		}
	)

	if impact == null:
		return

func _basis_from_surface_normal(normal: Vector3) -> Basis:
	var y := normal.normalized()

	var x := Vector3.UP.cross(y)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT.cross(y)

	x = x.normalized()
	var z := x.cross(y).normalized()

	return Basis(x, y, z)

func is_ready() -> bool:
	return _can_fire_from_heat()


func is_overheated_now() -> bool:
	return is_overheated


func is_cooling_down() -> bool:
	return is_overheated


func get_cooling_progress() -> float:
	# Returns:
	# 0.0 = just overheated
	# 1.0 = cooled enough to fire again

	if not is_overheated:
		return 1.0

	var recovery_heat := max_heat * overheat_recovery_ratio
	var cooling_range := max_heat - recovery_heat

	if cooling_range <= 0.0:
		return 1.0

	return clampf(1.0 - ((current_heat - recovery_heat) / cooling_range), 0.0, 1.0)
