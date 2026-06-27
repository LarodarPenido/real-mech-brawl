# armor_plate.gd
extends StaticBody3D
class_name ArmorPlate

#@export var impulse_strength: float = 8.0

@export var _hp: float = 100.0
var _is_destroyed: bool = false

#func _ready() -> void:
	#add_to_group("destructible")

func _process(delta: float) -> void:
	if not owner:
		_is_destroyed = true

func initialize(hp: float) -> void:
	_hp = hp

func take_damage(amount) -> void:
	if _is_destroyed:
		return
	
	_hp -= amount
	if _hp <= 0.0:
		_destroy()

func _destroy() -> void:
	_is_destroyed = true
	
	queue_free()
	#TODO  add gib
	#TODO add vfx
