extends Node3D

var enemies: Array[CharacterBody3D] = []

signal enemy_spawned
signal enemy_killed

func register_enemy(enemy: CharacterBody3D) -> void:
	if not enemies.has(enemy):
		enemies.append(enemy)
		print("Enemy spawned! Total enemies: ", enemies.size())

func unregister_enemy(enemy: CharacterBody3D) -> void:
	if enemies.has(enemy):
		enemies.erase(enemy)
		print("Enemy died! Total enemies: ", enemies.size())
