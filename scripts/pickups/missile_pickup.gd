# missile_pickup.gd
extends Area3D

@export var ammo_amount: int = 1
@onready var weapon_manager: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	weapon_manager = get_tree().get_first_node_in_group("weapon_manager")
	
func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if weapon_manager == null:
		return

	if not weapon_manager.has_method("add_secondary_ammo"):
		return

	weapon_manager.add_secondary_ammo(ammo_amount)
	queue_free()
