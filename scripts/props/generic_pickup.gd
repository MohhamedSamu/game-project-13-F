extends Node3D

## Prop recogible / soltar (Q). Sin acciones extras (ej. F). Pensado para puzzle / inventario físico simple.

@export_group("UI")
@export var pickup_prompt: String = "[E] Recoger objeto"

@export_group("Identity")
@export var item_id: StringName = &""

@export_group("En la mano")
@export var hold_offset: Vector3 = Vector3(0.12, -0.12, -0.38)
@export var hold_rotation_deg: Vector3 = Vector3(-90.0, 180.0, 0.0)

@export_group("Al soltar")
## Impulso horizontal al soltar (objetos ligeros/pequeños: bajar para evitar atravesar el suelo).
@export var drop_forward_speed: float = 1.4
@export var drop_up_speed: float = 0.35
@export var drop_spawn_forward: float = 0.35
@export var drop_spawn_lift: float = 0.08
## Raycast hacia abajo para no reaparecer dentro del piso al soltar.
@export var drop_snap_to_floor: bool = true
@export var drop_floor_snap_margin: float = 0.04

var _rb: RigidBody3D
var _collision_shape: CollisionShape3D
var _saved_layer: int = 1
var _saved_mask: int = 1


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("pickup")
	_rb = find_child("RigidBody3D", true, false) as RigidBody3D
	if _rb:
		_saved_layer = _rb.collision_layer
		_saved_mask = _rb.collision_mask
	_collision_shape = find_child("CollisionShape3D", true, false) as CollisionShape3D


func get_interaction_prompt() -> String:
	return pickup_prompt


func get_item_id() -> StringName:
	return item_id


func pickup_to_hand(hand: Node3D) -> void:
	if _rb == null:
		return
	var p := get_parent()
	if p != null:
		p.remove_child(self)
	hand.add_child(self)
	var euler := Vector3(
		deg_to_rad(hold_rotation_deg.x),
		deg_to_rad(hold_rotation_deg.y),
		deg_to_rad(hold_rotation_deg.z)
	)
	transform = Transform3D(Basis.from_euler(euler), hold_offset)
	_rb.transform = Transform3D.IDENTITY
	_rb.freeze = true
	_rb.linear_velocity = Vector3.ZERO
	_rb.angular_velocity = Vector3.ZERO
	_rb.collision_layer = 0
	_rb.collision_mask = 0
	if _collision_shape:
		_collision_shape.disabled = true


func drop_soft(forward_dir: Vector3, drop_parent: Node) -> void:
	if _rb == null:
		return
	var fwd := forward_dir.normalized()
	var gp := global_position
	var gb := global_basis
	var pr := get_parent()
	if pr != null:
		pr.remove_child(self)
	drop_parent.add_child(self)
	global_position = gp + fwd * drop_spawn_forward + Vector3(0.0, drop_spawn_lift, 0.0)
	global_basis = gb.orthonormalized()
	_rb.linear_velocity = Vector3.ZERO
	_rb.angular_velocity = Vector3.ZERO
	_rb.collision_layer = _saved_layer
	_rb.collision_mask = _saved_mask
	if _collision_shape:
		_collision_shape.disabled = false
	_rb.freeze = true
	if drop_snap_to_floor:
		_snap_drop_above_floor()
	var toss := fwd * drop_forward_speed + Vector3(0.0, drop_up_speed, 0.0)
	call_deferred("_complete_drop", toss)


func _snap_drop_above_floor() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var start := global_position + Vector3(0.0, 0.5, 0.0)
	var end := global_position + Vector3(0.0, -4.0, 0.0)
	var pq := PhysicsRayQueryParameters3D.create(start, end)
	pq.collide_with_bodies = true
	pq.collide_with_areas = false
	pq.collision_mask = _saved_mask if _saved_mask != 0 else 0xFFFFFFFF
	if _rb != null:
		pq.exclude = [_rb.get_rid()]
	var hit := space.intersect_ray(pq)
	if hit.is_empty():
		return
	var safe_y: float = (hit.position as Vector3).y + drop_floor_snap_margin
	if global_position.y < safe_y:
		global_position = Vector3(global_position.x, safe_y, global_position.z)


func _complete_drop(toss: Vector3) -> void:
	if not is_instance_valid(_rb):
		return
	_rb.freeze = false
	_rb.linear_velocity = toss
	_rb.angular_velocity = Vector3(
		randf_range(-2.0, 2.0),
		randf_range(-2.0, 2.0),
		randf_range(-2.0, 2.0)
	)
