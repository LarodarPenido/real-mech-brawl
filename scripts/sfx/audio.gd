## Global audio API. ONE job: hand out SFX voices (priority + distance aware),
## play music, set bus volumes. Attach to the root of audio.tscn and register
## that scene as the "Audio" autoload.

## Usage:
##Audio.play_sfx(Sounds.dash, 10)
##Audio.play_sfx(Sounds.gun, 5)
##Audio.play_sfx_at_3d(Sounds.gun, enemy.global_position, 5)   # same stream, positional for enemies

extends Node

# A fixed set of players with priority-based voice stealing. The only complex
# part (which voice to take) lives here, so the omni / 2D / 3D pools share it.
class VoicePool extends RefCounted:
	# Untyped on purpose: the three pools hold different player types, which
	# share no common audio base class beyond Node.
	var players: Array = []
	var priorities: Array[int] = []
	var started_at: Array[int] = []

	## Register this pool's player nodes (one type per pool).
	func setup(player_nodes: Array) -> void:
		for p in player_nodes:
			players.append(p)
			priorities.append(0)
			started_at.append(0)

	## Free voice first; else steal the lowest-priority active voice whose
	## priority <= the newcomer's (oldest first on ties). -1 means drop.
	func claim(priority: int) -> int:
		for i in players.size():
			if not players[i].playing:
				return i
		var best := -1
		for i in players.size():
			if priorities[i] > priority:
				continue
			if best == -1 \
					or priorities[i] < priorities[best] \
					or (priorities[i] == priorities[best] and started_at[i] < started_at[best]):
				best = i
		return best

	## Record what a voice is now playing, for future steal comparisons.
	func mark(index: int, priority: int) -> void:
		priorities[index] = priority
		started_at[index] = Time.get_ticks_msec()


const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

# Distance-to-priority tuning. Every FALLOFF units of distance from the listener
# lowers a sound's effective priority by 1; past CULL it isn't played at all.
# 3D values are world units, 2D values are pixels — tune these per project.
const FALLOFF_3D := 8.0
const CULL_3D := 60.0
const FALLOFF_2D := 200.0
const CULL_2D := 1200.0

var _omni := VoicePool.new()
var _pool_2d := VoicePool.new()
var _pool_3d := VoicePool.new()

# Set these to the player (or a node at the player) so distance is measured from
# there, NOT from a far-away top-down camera. See set_listener_* below.
var _listener_2d: Node2D
var _listener_3d: Node3D

@onready var _music_a: AudioStreamPlayer = $Music/MusicA
@onready var _music_b: AudioStreamPlayer = $Music/MusicB
var _music_active: AudioStreamPlayer


func _ready() -> void:
	_omni.setup($SfxPool.get_children())
	_pool_2d.setup($SfxPool2D.get_children())
	_pool_3d.setup($SfxPool3D.get_children())
	_music_active = _music_a


# --- Omni (non-positional) SFX ------------------------------------------------

## Play a non-positional one-shot (UI, global cues). Returns false if dropped.
func play_sfx(stream: AudioStream, priority: int = 0, pitch_variation: float = 0.0) -> bool:
	if stream == null:
		return false
	var index := _omni.claim(priority)
	if index == -1:
		return false
	var player := _omni.players[index] as AudioStreamPlayer
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
	_omni.mark(index, priority)
	return true


# --- Positional SFX -----------------------------------------------------------

## Play a one-shot at a fixed 2D position. Distance from the 2D listener lowers
## its effective priority (and culls it past CULL_2D). Returns false if dropped.
func play_sfx_at_2d(stream: AudioStream, position: Vector2, priority: int = 0, pitch_variation: float = 0.0) -> bool:
	if stream == null:
		return false
	if _listener_2d != null:
		var d := position.distance_to(_listener_2d.global_position)
		if d > CULL_2D:
			return false
		priority -= int(d / FALLOFF_2D)
	var index := _pool_2d.claim(priority)
	if index == -1:
		return false
	var player := _pool_2d.players[index] as AudioStreamPlayer2D
	player.stream = stream
	player.global_position = position
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
	_pool_2d.mark(index, priority)
	return true


## Play a one-shot at a fixed 3D position. Distance from the 3D listener lowers
## its effective priority (and culls it past CULL_3D). Returns false if dropped.
func play_sfx_at_3d(stream: AudioStream, position: Vector3, priority: int = 0, pitch_variation: float = 0.0) -> bool:
	if stream == null:
		return false
	if _listener_3d != null:
		var d := position.distance_to(_listener_3d.global_position)
		if d > CULL_3D:
			return false
		priority -= int(d / FALLOFF_3D)
	var index := _pool_3d.claim(priority)
	if index == -1:
		return false
	var player := _pool_3d.players[index] as AudioStreamPlayer3D
	player.stream = stream
	player.global_position = position
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
	_pool_3d.mark(index, priority)
	return true


## Point distance measurement at the player (or a node tracking it).
func set_listener_2d(node: Node2D) -> void:
	_listener_2d = node


func set_listener_3d(node: Node3D) -> void:
	_listener_3d = node


# --- Music --------------------------------------------------------------------

## Swap the current music immediately. (Crossfade is a later phase.)
func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	_music_active.stream = stream
	_music_active.play()


func stop_music() -> void:
	_music_active.stop()


# --- Bus volume ---------------------------------------------------------------

## Set a bus volume from a 0..1 linear value (what a UI slider gives you).
func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("Audio bus '%s' not found." % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


## Get a bus volume as a 0..1 linear value.
func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))
