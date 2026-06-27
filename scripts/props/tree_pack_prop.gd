@tool
class_name TreePackProp
extends Node3D
## Muestra un solo árbol del pack. Usa `trees.tscn` (colisiones) o `tree_1.glb` como respaldo.

@export var tree_variant: StringName = &"Tree_4":
	set(value):
		tree_variant = value
		_queue_apply_variant()


const COLLISION_LAYER_ACTIVE := 1
const COLLISION_MASK_ACTIVE := 1

var _apply_queued: bool = false


func _ready() -> void:
	_apply_variant()


func _enter_tree() -> void:
	_queue_apply_variant()


func _queue_apply_variant() -> void:
	if _apply_queued:
		return
	_apply_queued = true
	call_deferred("_deferred_apply_variant")


func _deferred_apply_variant() -> void:
	_apply_queued = false
	_apply_variant()


func _get_pack_root() -> Node3D:
	var trees_pack := get_node_or_null("TreesPack")
	if trees_pack != null:
		var nested := trees_pack.get_node_or_null("tree_1") as Node3D
		if nested != null:
			return nested
	return get_node_or_null("tree_1") as Node3D


func _uses_physics_pack() -> bool:
	return get_node_or_null("TreesPack") != null


func _apply_variant() -> void:
	if not is_inside_tree():
		return
	var pack_root := _get_pack_root()
	if pack_root == null:
		return
	if _uses_physics_pack():
		pack_root.transform = Transform3D.IDENTITY
	for child in pack_root.get_children():
		if not child is Node3D:
			continue
		var tree_node := child as Node3D
		var is_active := tree_node.name == tree_variant
		tree_node.visible = is_active
		_set_tree_collision(tree_node, is_active)


func _set_tree_collision(tree_node: Node3D, enabled: bool) -> void:
	var body := tree_node.get_node_or_null("StaticBody3D") as StaticBody3D
	if body == null:
		return
	if enabled:
		body.collision_layer = COLLISION_LAYER_ACTIVE
		body.collision_mask = COLLISION_MASK_ACTIVE
	else:
		body.collision_layer = 0
		body.collision_mask = 0


func get_available_variants() -> PackedStringArray:
	var names := PackedStringArray()
	var pack_root := _get_pack_root()
	if pack_root == null:
		return names
	for child in pack_root.get_children():
		if child is Node3D:
			names.append(child.name)
	return names
