extends Node3D


@export var mesh_explosion_scene: PackedScene


func _ready() -> void:
	VFXPool.register_pool(
		&"mesh_explosion",
		mesh_explosion_scene,
		8,
		false
	)
