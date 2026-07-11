@tool
extends Node3D

@export var target_churro_node: Node3D:
	set(value):
		target_churro_node = value
		if is_inside_tree():
			call_deferred("_align_to_target_churro")
@export var required_flag: String = "needs_churro"
@export var hand_item_name: String = "churro"
@export var prompt_text: String = "Presiona [E] para agarrar churro"
@export var hand_hold_offset: Vector3 = Vector3(0.04, -0.1, -0.3)
## Ajuste fino sobre la orientación calculada al agarrar (bolsa de pie, como en el estante).
@export var hand_hold_rotation_offset_deg: Vector3 = Vector3.ZERO
@export_range(0.05, 1.5, 0.01) var hand_size_multiplier: float = 0.52

@onready var _interact: InteractableDialogueComponent = $InteractableDialogueComponent

var _picked: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("churro_pickup")
	call_deferred("_align_to_target_churro")


func _align_to_target_churro() -> void:
	if target_churro_node == null or not is_instance_valid(target_churro_node):
		if not Engine.is_editor_hint():
			push_warning("%s: falta target_churro_node." % name)
		return
	global_position = _get_churro_interaction_point()
	global_basis = target_churro_node.global_transform.basis.orthonormalized()
	if Engine.is_editor_hint():
		return
	if _interact != null:
		_interact.refresh_ray_target()


func _get_churro_interaction_point() -> Vector3:
	if target_churro_node is MeshInstance3D:
		var mesh_instance := target_churro_node as MeshInstance3D
		if mesh_instance.mesh != null:
			return mesh_instance.to_global(mesh_instance.mesh.get_aabb().get_center())
	return target_churro_node.global_position


func _get_world_display_scale() -> float:
	var world_scale := target_churro_node.global_transform.basis.get_scale()
	return (world_scale.x + world_scale.y + world_scale.z) / 3.0


func can_pickup() -> bool:
	if _picked:
		return false
	if not GameManager.get_flag(required_flag):
		return false
	if not GameManager.get_flag("coca_placed_on_counter"):
		return false
	if GameManager.get_flag("churro_taken"):
		return false
	var player := GameManager.get_player()
	if player != null and player.has_method("has_left_hand_item"):
		return not player.has_left_hand_item()
	return true


func can_handle_interaction() -> bool:
	return can_pickup()


func get_interaction_prompt() -> String:
	if can_pickup():
		return prompt_text
	return ""


func handle_interaction() -> void:
	if not can_pickup() or target_churro_node == null:
		return
	var player := GameManager.get_player()
	if player == null or not player.has_method("give_left_hand_visual"):
		return

	var visual := _duplicate_churro_visual()
	if visual == null:
		return

	var attach_scale := _get_world_display_scale() * hand_size_multiplier
	var hold_rotation := _compute_hand_hold_rotation_deg()
	if player.give_left_hand_visual(visual, hand_hold_offset, hold_rotation, attach_scale):
		_hide_source_churro()
		_picked = true
		_interact.enabled = false
		ChurroCounterFlow.on_churro_received_in_hand()
	else:
		_picked = false
		_interact.enabled = true
		visual.queue_free()
		_show_source_churro()


func _compute_hand_hold_rotation_deg() -> Vector3:
	if target_churro_node == null:
		return hand_hold_rotation_offset_deg
	var player := GameManager.get_player()
	if player == null:
		return hand_hold_rotation_offset_deg
	var hand_left := player.get_node_or_null("Head/Camera3D/HandLeft") as Node3D
	if hand_left == null:
		return hand_hold_rotation_offset_deg
	# Conservar la orientación global del estante al pasar al espacio local de HandLeft.
	var shelf_basis := target_churro_node.global_transform.basis.orthonormalized()
	var hand_local_basis := hand_left.global_transform.basis.inverse() * shelf_basis
	var euler := hand_local_basis.get_euler(EULER_ORDER_YXZ)
	return Vector3(
		rad_to_deg(euler.x),
		rad_to_deg(euler.y),
		rad_to_deg(euler.z)
	) + hand_hold_rotation_offset_deg


func _duplicate_churro_visual() -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = "ChurroHandVisual"
	var copy := target_churro_node.duplicate() as MeshInstance3D
	if copy == null:
		wrapper.queue_free()
		return null
	for child in copy.get_children():
		if child is StaticBody3D or child is CollisionShape3D:
			child.queue_free()
	copy.transform = Transform3D.IDENTITY
	wrapper.add_child(copy)
	wrapper.set_meta("held_display_scale", _get_world_display_scale())
	return wrapper


func _hide_source_churro() -> void:
	target_churro_node.visible = false
	for child in target_churro_node.get_children():
		if child is StaticBody3D:
			child.set_collision_layer_value(1, false)
			child.set_collision_mask_value(1, false)


func _show_source_churro() -> void:
	target_churro_node.visible = true
	for child in target_churro_node.get_children():
		if child is StaticBody3D:
			child.set_collision_layer_value(1, true)
			child.set_collision_mask_value(1, true)
