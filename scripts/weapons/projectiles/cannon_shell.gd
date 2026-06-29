# AutocannonProjectile — straight-line Area3D projectile fired by UnitAutocannon.

#extends Area3D
#
#var speed: float
#@export var damage: float = 90
#@export var lifetime: float = 5.0
#@export var projectile_color: Color = Color(1.0, 0.3, 0.1)
#
#var _direction: Vector3 = Vector3.FORWARD
#var _elapsed: float = 0.0
##var _source_faction: String = "neutral"
##var _light: OmniLight3D
##var _source_unit: Node = null
#
#func _ready() -> void:
	#body_entered.connect(_on_body_entered)
#
#func setup(direction: Vector3, dmg: float = -1.0, spd: float = -1.0) -> void:
	#_direction = direction.normalized()
	#if dmg > 0:
		#damage = dmg
	#if spd > 0:
		#speed = spd
#
#func _physics_process(delta: float) -> void:
	#global_position += _direction * speed * delta
#
	#if _direction.length_squared() > 0.01:
		#look_at(global_position + _direction, Vector3.UP)
#
	#_elapsed += delta
	#if _elapsed >= lifetime:
		#queue_free()
#
#func _on_body_entered(body: Node3D) -> void:
	## Friendly-fire guard — skip bodies of the same faction as the shooter.
	#if not body.is_in_group("player"):
		#return
#
	#if body.has_method("take_damage"):
		#body.take_damage(damage)
#
	#_spawn_impact()
	#queue_free()
#
#func _spawn_impact() -> void:
	#var flash := OmniLight3D.new()
	#flash.light_color = projectile_color
	#flash.light_energy = 5.0
	#flash.omni_range = 4.0
	#get_tree().current_scene.add_child(flash)
	#flash.global_position = global_position
#
	#var tween := flash.create_tween()
	#tween.tween_property(flash, "light_energy", 0.0, 0.15)
	#tween.tween_callback(flash.queue_free)




#------------------------------



# Cannon_shell.gd — straight-line CharacterBody3D projectile.

extends CharacterBody3D

var speed: float = 80.0

@export var damage: float = 90.0
@export var lifetime: float = 5.0
@export var projectile_color: Color = Color(1.0, 0.3, 0.1)

@export var explosion_scene: PackedScene

var _direction: Vector3 = Vector3.FORWARD
var _elapsed: float = 0.0
var _has_hit: bool = false
var _source_unit: Node3D = null


func setup(
	direction: Vector3,
	dmg: float = -1.0,
	spd: float = -1.0,
	source_unit: Node3D = null
) -> void:
	_direction = direction.normalized()
	_source_unit = source_unit
	_elapsed = 0.0
	_has_hit = false

	if dmg > 0.0:
		damage = dmg

	if spd > 0.0:
		speed = spd


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	var motion: Vector3 = _direction * speed * delta

	var collision := move_and_collide(motion)

	if collision != null:
		_handle_collision(collision)
		return

	if _direction.length_squared() > 0.01:
		look_at(global_position + _direction, Vector3.UP)

	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()


func _handle_collision(collision: KinematicCollision3D) -> void:
	if _has_hit:
		return

	var collider := collision.get_collider()

	if collider == _source_unit:
		return

	_has_hit = true

	global_position = collision.get_position()

	if collider is Node:
		var node := collider as Node

		if node.is_in_group("player") and node.has_method("take_damage"):
			node.take_damage(damage)

	_spawn_impact()
	queue_free()


func _spawn_impact() -> void:
	if explosion_scene:
		spawn_explosion(global_position)

	Audio.play_sfx_at_3d(Sounds.explosion_01, global_position, 5, 0.1, 1)

	queue_free()

func spawn_explosion(world_position: Vector3) -> void:
	if explosion_scene == null:
		return

	VFXPool.spawn(
		&"mesh_explosion",
		global_position,
		Basis.IDENTITY,
		{
			"radius": 3.5,
			"lifetime": 0.55
		}
	)
