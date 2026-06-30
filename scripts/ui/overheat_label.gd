extends Label


@onready var _weapon_manager: Node 

@onready var _primary_weapon: Node

func _ready() -> void:
	_weapon_manager = get_tree().get_first_node_in_group("weapon_manager")
	#_primary_weapon = _weapon_manager.get_active_primary()

func _process(delta: float) -> void:
	if _weapon_manager.is_primary_overheated():
		show()
	else:
		hide()
