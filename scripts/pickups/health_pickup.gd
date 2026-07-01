extends Area3D

@export var bonus_health: int = 75

@export var spin_speed: float = 2.8
@export var sway_height: float = 0.35
@export var sway_speed: float = 2.0

@export var pickup_scale_time: float = 0.18

@onready var visual_root: Node3D = $VisualRoot
#@onready var missile_mesh: MeshInstance3D = $VisualRoot/MissileMesh
@onready var glow_core: MeshInstance3D = $VisualRoot/GlowCore
@onready var glow_ring_a: MeshInstance3D = $VisualRoot/GlowRingA
@onready var glow_ring_b: MeshInstance3D = $VisualRoot/GlowRingB

var _base_y: float
var _time: float = 0.0
var _picked_up: bool = false


#@onready var player_missile_launcher: Node3D

func _ready() -> void:
	#player_missile_launcher = get_tree().get_first_node_in_group("missile_launcher")
	_base_y = visual_root.position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _picked_up:
		return

	_time += delta

	visual_root.position.y = _base_y + sin(_time * sway_speed) * sway_height
	visual_root.rotate_y(spin_speed * delta)

	_update_mesh_glow(delta)


func _update_mesh_glow(delta: float) -> void:
	var pulse := 0.85 + sin(_time * 5.0) * 0.15

	glow_core.scale = Vector3.ONE * pulse

	glow_ring_a.rotate_y(delta * 1.8)
	glow_ring_b.rotate_y(-delta * 1.2)

	glow_ring_a.scale = Vector3.ONE * (1.0 + sin(_time * 3.0) * 0.08)
	glow_ring_b.scale = Vector3.ONE * (1.15 + sin(_time * 2.2) * 0.08)


func _on_body_entered(body: Node) -> void:
	if _picked_up:
		return

	if not body.is_in_group("player"):
		return

	if body.health >= body.max_health:
		return

	_picked_up = true
	_collect(body)


func _collect(player: Node) -> void:
	player.heal(bonus_health)

	Audio.play_sfx(Sounds.heal)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(glow_ring_a, "scale", Vector3.ONE * 2.8, pickup_scale_time)
	tween.tween_property(glow_ring_b, "scale", Vector3.ONE * 3.5, pickup_scale_time)
	tween.tween_property(glow_core, "scale", Vector3.ONE * 2.2, pickup_scale_time)

	tween.finished.connect(queue_free)
