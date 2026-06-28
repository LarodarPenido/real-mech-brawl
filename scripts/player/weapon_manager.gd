# WeaponManager — manages primary/secondary weapon slots and fire input.

# The player node must be in the "player" group for _ready() lookup to succeed.
extends Node

## References
@export var aim_assist: Node
@onready var player: Node3D
@export var missile_lock: Node
@export var camera: Node3D

## Weapon slots (assign all available weapons per slot in editor)
@export var primary_weapons: Array[Node] = []
@export var secondary_weapons: Array[Node] = []

## Active indices
var _primary_index: int = 0
var _secondary_index: int = 0

var _is_firing: bool = false
var _is_firing_secondary: bool = false

signal primary_weapon_changed(weapon: Node)
signal secondary_weapon_changed(weapon: Node)


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	# Wire all weapons, then activate only the first of each slot
	for weapon in primary_weapons:
		_wire_weapon(weapon)
		_deactivate_weapon(weapon)

	for weapon in secondary_weapons:
		_wire_weapon(weapon)
		_deactivate_weapon(weapon)

	if primary_weapons.size() > 0:
		_activate_weapon(primary_weapons[_primary_index])

	if secondary_weapons.size() > 0:
		_activate_weapon(secondary_weapons[_secondary_index])


func _process(delta: float) -> void:
	_handle_input()

	var primary := get_active_primary()
	if primary:
		if _is_firing:
			if primary.has_method("trigger_held"):
				primary.trigger_held(delta)
		else:
			if primary.has_method("trigger_released"):
				primary.trigger_released(delta)

	var secondary := get_active_secondary()
	if secondary:
		if _is_firing_secondary:
			if secondary.has_method("trigger_held"):
				secondary.trigger_held(delta)
		else:
			if secondary.has_method("trigger_released"):
				secondary.trigger_released(delta)


func _handle_input() -> void:
	_is_firing = Input.is_action_pressed("shoot_main_gun")
	_is_firing_secondary = Input.is_action_pressed("fire_missiles")


	#TODO if adding multy wep
	#if Input.is_action_just_pressed("swap_primary_weapon") and primary_weapons.size() > 1:
		#equip_primary((_primary_index + 1) % primary_weapons.size())
#
	#if Input.is_action_just_pressed("swap_secondary_weapon") and secondary_weapons.size() > 1:
		#equip_secondary((_secondary_index + 1) % secondary_weapons.size())


# --- Equip API ---

func equip_primary(index: int) -> void:
	if index < 0 or index >= primary_weapons.size():
		return
	if index == _primary_index:
		return
	_deactivate_weapon(primary_weapons[_primary_index])
	_primary_index = index
	_activate_weapon(primary_weapons[_primary_index])
	primary_weapon_changed.emit(primary_weapons[_primary_index])


func equip_secondary(index: int) -> void:
	if index < 0 or index >= secondary_weapons.size():
		return
	if index == _secondary_index:
		return
	_deactivate_weapon(secondary_weapons[_secondary_index])
	_secondary_index = index
	_activate_weapon(secondary_weapons[_secondary_index])
	secondary_weapon_changed.emit(secondary_weapons[_secondary_index])


# --- Getters ---

func get_active_primary() -> Node:
	if _primary_index < primary_weapons.size():
		return primary_weapons[_primary_index]
	return null


func get_active_secondary() -> Node:
	if _secondary_index < secondary_weapons.size():
		return secondary_weapons[_secondary_index]
	return null

func is_primary_actively_firing() -> bool:
	var primary := get_active_primary()

	if primary == null:
		return false

	if primary.has_method("is_actively_firing"):
		return primary.is_actively_firing()

	# Fallback for weapons that do not expose actual firing state yet.
	return _is_firing

func is_primary_overheated() -> bool:
	var primary := get_active_primary()

	if primary == null:
		return false

	if primary.has_method("is_overheated_now"):
		return primary.is_overheated_now()

	return false


# --- Internal ---

func _wire_weapon(weapon: Node) -> void:
	if not weapon:
		return
	if weapon.has_method("set_aim_assist"):
		weapon.set_aim_assist(aim_assist)
	if weapon.has_method("set_missile_lock"):
		weapon.set_missile_lock(missile_lock)
	if weapon.has_method("set_owner_node"):
		weapon.set_owner_node(player)


func _activate_weapon(weapon: Node) -> void:
	if not weapon:
		return
	weapon.visible = true
	weapon.set_process(true)
	weapon.set_physics_process(true)


func _deactivate_weapon(weapon: Node) -> void:
	if not weapon:
		return
	weapon.visible = false
	weapon.set_process(false)
	weapon.set_physics_process(false)

func add_secondary_ammo(amount: int) -> void:
	var secondary := get_active_secondary()

	if secondary == null:
		return

	if secondary.has_method("add_ammo"):
		secondary.add_ammo(amount)
