# AimAssist — single-target soft lock with bullet-bending redirect.

#   get_fire_point() -> Vector3    # Target world position, or Vector3.ZERO
#   has_lock() -> bool
extends Node3D

## Targeting
@export var assist_radius: float = 20.0  ## Pixels — range to acquire lock
@export var lock_break_radius: float = 40.0  ## Pixels — range to lose lock
@export var max_lock_range: float = 70.0  ## World units — max distance from player
@export var aim_height_adjustment: float = 1.0 ## adjustment to avoid firing at the ground
@export var prefer_closest_to_cursor: bool = true  ## true = lock nearest cursor; false = lock lowest health

@export var free_aim_ray_distance: float = 400.0
@export var free_aim_arrival_distance: float = 2.0

### Faction filtering (matches missile_lock pattern)
#@export var owner_faction: String = "player"
#@export var hostile_factions: Array[String] = ["enemy", "bandit"] # Add "structures"?

## References
@export var player: Node3D
@export var camera: Camera3D
@export var enemy_manager: Node3D 


## State
var locked_target: Node3D = null

signal target_locked(target: Node3D)
signal target_lost()

func _ready() -> void:
	enemy_manager = get_tree().get_first_node_in_group("enemy_manager")
	

func _process(_delta: float) -> void:
	if not player or not camera:
		return

	if locked_target:
		if _should_break_lock():
			_release_lock()
		return

	_try_acquire_lock()


# --- Public API ---

func get_fire_point() -> Vector3:
	if locked_target and is_instance_valid(locked_target):
		return locked_target.global_position + Vector3(0, aim_height_adjustment, 0)
	return Vector3.ZERO

func get_aim_point(fallback_origin: Vector3, fallback_direction: Vector3) -> Vector3:
	# If there is a lock, use the locked enemy.
	if has_lock():
		return get_fire_point()

	# If camera is missing, fall back to straight ahead.
	if camera == null:
		return fallback_origin + fallback_direction.normalized() * free_aim_ray_distance

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_dir * free_aim_ray_distance

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	if player != null and player is CollisionObject3D:
		query.exclude = [player.get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		return hit.position

	# If the cursor ray hits nothing, aim far into the camera ray.
	return ray_end

func has_lock() -> bool:
	return locked_target != null and is_instance_valid(locked_target)
	
func get_locked_target() -> Node3D:
	if locked_target and is_instance_valid(locked_target):
		return locked_target
	return null

# --- Acquisition ---

func _try_acquire_lock() -> void:
	var candidates := _get_hostiles_in_assist_radius()
	if candidates.is_empty():
		return

	var best_target: Node3D = null

	if prefer_closest_to_cursor:
		var closest_screen: float = INF
		for enemy in candidates:
			var screen_dist := _get_screen_distance_to_cursor(enemy)
			if screen_dist < closest_screen:
				closest_screen = screen_dist
				best_target = enemy
	else:
		var lowest_health: float = INF
		for enemy in candidates:
			var health := _get_enemy_health(enemy)
			if health < lowest_health:
				lowest_health = health
				best_target = enemy

	if best_target:
		locked_target = best_target
		
		target_locked.emit(locked_target)
		# TODO(3A-3): play lock-on sound via AudioManager


# --- Release ---

func _should_break_lock() -> bool:
	if not is_instance_valid(locked_target):
		return true

	# World distance gate
	var world_distance := player.global_position.distance_to(locked_target.global_position)
	if world_distance > max_lock_range:
		return true

	# Screen distance gate
	var screen_distance := _get_screen_distance_to_cursor(locked_target)
	if screen_distance > lock_break_radius:
		print("aim assist - should break lock active")
		return true

	# Dead-but-not-freed fallback (is_instance_valid above catches freed nodes)
	if "hp" in locked_target and locked_target.hp <= 0.0:
		return true

	return false


func _release_lock() -> void:
	locked_target = null
	target_lost.emit()


# --- Candidate scanning ---

func _get_hostiles_in_assist_radius() -> Array[Node3D]:
	var result: Array[Node3D] = []

	for enemy_unit in enemy_manager.enemies:
		if not enemy_unit is Node3D:
			continue
		var unit3d: Node3D = enemy_unit
		if not is_instance_valid(unit3d):
			continue

		# World distance first (cheaper than screen projection)
		var world_distance: float = player.global_position.distance_to(unit3d.global_position)
		if world_distance > max_lock_range:
			continue

		# Then screen distance
		var screen_distance: float = _get_screen_distance_to_cursor(unit3d)
		if screen_distance <= assist_radius:
			result.append(unit3d)

	return result


func _get_screen_distance_to_cursor(target: Node3D) -> float:
	if camera.is_position_behind(target.global_position):
		return INF
	var screen_pos: Vector2 = camera.unproject_position(target.global_position)
	var cursor_pos: Vector2 = get_viewport().get_mouse_position()
	return screen_pos.distance_to(cursor_pos)


func _get_enemy_health(enemy: Node3D) -> float:
	if enemy.has_method("get_health"):
		return enemy.get_health()
	if "hp" in enemy:
		return enemy.hp
	if "health" in enemy:
		return enemy.health
	# Fallback: treat as full health
	return 100.0
