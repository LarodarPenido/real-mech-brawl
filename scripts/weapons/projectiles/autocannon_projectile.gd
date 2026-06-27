# AutocannonProjectile — straight-line Area3D projectile fired by UnitAutocannon.

extends Area3D

var speed: float
@export var damage: float = 15.0
@export var lifetime: float = 5.0
@export var projectile_color: Color = Color(1.0, 0.3, 0.1)

var _direction: Vector3 = Vector3.FORWARD
var _elapsed: float = 0.0
#var _source_faction: String = "neutral"
#var _light: OmniLight3D
#var _source_unit: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(direction: Vector3, dmg: float = -1.0, spd: float = -1.0) -> void:
	_direction = direction.normalized()
	if dmg > 0:
		damage = dmg
	if spd > 0:
		speed = spd

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

	if _direction.length_squared() > 0.01:
		look_at(global_position + _direction, Vector3.UP)

	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	# Friendly-fire guard — skip bodies of the same faction as the shooter.
	if not body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	_spawn_impact()
	queue_free()

func _spawn_impact() -> void:
	var flash := OmniLight3D.new()
	flash.light_color = projectile_color
	flash.light_energy = 5.0
	flash.omni_range = 4.0
	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position

	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)
