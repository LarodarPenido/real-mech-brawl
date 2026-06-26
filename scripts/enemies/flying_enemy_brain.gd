extends Node

enum BehaviorMode {
	LIGHT_REPOSITION,
	TANK_HOLD
}

enum State {
	APPROACH,
	ORBIT,
	LOCK,
	FIRE,
	BREAK,
}

func set_target(new_target: Node3D) -> void:
	pass

func fire() -> void:
	pass
