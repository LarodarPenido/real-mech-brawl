extends AudioStreamPlayer

@export var min_volume_db: float = -30.0 # Quietest the wind gets
@export var max_volume_db: float = -5.0   # Loudest the wind gets
@export var min_duration: float = 3.0    # Fastest ramp time in seconds
@export var max_duration: float = 8.0    # Slowest ramp time in seconds

func _ready() -> void:
	# Ensure the audio is playing and looping
	if not playing:
		play()
	
	# Start the random ramping loop
	_start_random_ramp()

func _start_random_ramp() -> void:
	# Pick a random target volume and a random time it takes to get there
	var target_vol = randf_range(min_volume_db, max_volume_db)
	var duration = randf_range(min_duration, max_duration)
	
	# Create a tween to handle the smooth transition
	var tween = create_tween()
	
	# Animate the "volume_db" property to the target_vol over the random duration.
	# Using TRANS_SINE makes the fade ease in and out smoothly instead of linearly.
	tween.tween_property(self, "volume_db", target_vol, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	# Once this ramp finishes, recursively call this function to start the next one
	tween.finished.connect(_start_random_ramp)
