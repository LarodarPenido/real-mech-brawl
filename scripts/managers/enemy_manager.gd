extends Node3D

var enemies: Array[CharacterBody3D] = []

signal enemy_spawned(enemy: CharacterBody3D)
signal enemy_killed(enemy: CharacterBody3D)
signal all_enemies_cleared()


func register_enemy(enemy: CharacterBody3D) -> void:
	if not enemies.has(enemy):
		enemies.append(enemy)
		enemy_spawned.emit(enemy)
		print("Enemy Manager: Enemy spawned! Total enemies: ", enemies.size())


func unregister_enemy(enemy: CharacterBody3D) -> void:
	if enemies.has(enemy):
		enemies.erase(enemy)
		enemy_killed.emit(enemy)
		print("Enemy Manager: Enemy died! Total enemies: ", enemies.size())

		if enemies.is_empty():
			all_enemies_cleared.emit()
