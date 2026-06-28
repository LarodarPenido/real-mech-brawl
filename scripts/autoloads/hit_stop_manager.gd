extends Node

# Keeps track of how many overlapping freezes are currently happening
var _active_freezes: int = 0

func hit_freeze(time_scale: float, duration: float) -> void:
	# 1. Apply the slow motion
	Engine.time_scale = time_scale
	
	# 2. Register that a freeze has started
	_active_freezes += 1
	
	# 3. Wait for the duration. 
	# The 4th argument (true) ensures this timer ignores Engine.time_scale!
	await get_tree().create_timer(duration, true, false, true).timeout
	
	# 4. The freeze is over, so unregister it
	_active_freezes -= 1
	
	# 5. Only reset the time scale if no other freezes are currently active
	if _active_freezes <= 0:
		_active_freezes = 0
		Engine.time_scale = 1.0
