# enemy_weapon.gd - autocannon
extends Node3D

## Projectile settings
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 80.0
@export var projectile_damage: float = 15.0
@export var weapon_range: float = 50.0

## Targeting
@export var target: Node3D
@export var lead_shots: bool = true  ## Aim ahead of moving targets
@export var half_mech_height: float = 2.5
@export var muzzle_point: Marker3D

## VFX hooks
signal fired(position: Vector3, direction: Vector3)


func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")

func get_range() -> float:
	return weapon_range

func fire() -> void:
	if not projectile_scene:
		push_warning("UnitAutocannon: No projectile_scene assigned!")
		return

	var spawn_pos := muzzle_point.global_position
	var direction := _get_fire_direction(spawn_pos)
	var projectile := projectile_scene.instantiate() as Node3D

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_pos

	if projectile.has_method("setup"):
		projectile.setup(direction, projectile_damage, projectile_speed)

	# TODO(3A-3): AudioManager.play_sfx("unit_autocannon", spawn_pos, priority=nearby)
	fired.emit(spawn_pos, direction)


func _get_fire_direction(from: Vector3) -> Vector3:
	if not target or not is_instance_valid(target):
		return -global_transform.basis.z

	var target_pos: Vector3 = _get_target_aim_point()

	if lead_shots and target is CharacterBody3D:
		target_pos = _calculate_lead_position(from, target as CharacterBody3D, target_pos)

	return (target_pos - from).normalized()


func _calculate_lead_position(from: Vector3, moving_target: CharacterBody3D, base_pos: Vector3) -> Vector3:
	var target_vel := moving_target.velocity

	var distance := from.distance_to(base_pos)
	var travel_time := distance / projectile_speed

	var predicted_pos := base_pos + target_vel * travel_time

	# Refine once
	distance = from.distance_to(predicted_pos)
	travel_time = distance / projectile_speed
	predicted_pos = base_pos + target_vel * travel_time

	return predicted_pos

func _get_target_aim_point() -> Vector3:
	
	return Vector3(target.global_position.x, target.global_position.y + half_mech_height, target.global_position.z)
