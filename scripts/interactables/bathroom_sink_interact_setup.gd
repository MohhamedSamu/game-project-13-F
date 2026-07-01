@tool
class_name BathroomSinkInteractSetup
extends Node3D
## Obsoleto: la interacción y las cajas de colisión viven en [BathroomSinkHorrorSetup] / SinkInteraction.
## Mantener solo si necesitas un nodo intermedio en otro nivel; en level_2 ya no se usa.

const WANTS_SINK_FLAG := &"wants_bathroom_sink"

@export_group("Secuencia")
@export var horror_setup_path: NodePath

@export_group("Interacción")
@export var prompt_text: String = "Presiona [E] para lavarte las manos"
@export var focus_offset: Vector3 = Vector3(0.0, 0.9, 0.0)
@export var focus_box_size: Vector3 = Vector3(2.4, 1.2, 0.55)
@export var proximity_box_size: Vector3 = Vector3(2.8, 1.6, 1.35)

@export_group("Acceso")
@export var bathroom_door_path: NodePath

var _interactable: InteractableDialogueComponent
var _ray_target: Area3D
var _ray_shape: CollisionShape3D
var _focus_target: Node3D
var _proximity_shape: CollisionShape3D
var _owns_ray_shape: bool = false
var _owns_proximity_shape: bool = false
var _horror: BathroomSinkHorrorSetup


func _enter_tree() -> void:
	_cache_child_refs()
	_rebuild()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_rebuild()
	if _interactable != null:
		_interactable.refresh_ray_target()
	call_deferred("_resolve_horror_setup")


func _cache_child_refs() -> void:
	_interactable = get_node_or_null("InteractableDialogueComponent") as InteractableDialogueComponent
	_ray_target = get_node_or_null("InteractionRayTarget") as Area3D
	_focus_target = get_node_or_null("DialogueFocusPoint") as Node3D
	if _ray_target != null:
		_ray_shape = _ray_target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _interactable != null:
		_proximity_shape = _interactable.get_node_or_null("CollisionShape3D") as CollisionShape3D


func _resolve_horror_setup() -> void:
	if horror_setup_path.is_empty():
		return
	_horror = _resolve_scene_node(horror_setup_path) as BathroomSinkHorrorSetup


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_cache_child_refs()
	if _interactable != null:
		var reach := maxf(proximity_box_size.x, proximity_box_size.z) * 0.55
		_interactable.proximity_radius = reach
		_interactable.require_specific_ray_target = true
		_interactable.requires_focus_hitbox = false
		_interactable.prompt_text = prompt_text
		_interactable.use_camera_focus = false
		_interactable.auto_find_focus_target = true
	if _focus_target != null:
		_focus_target.position = focus_offset
	if _ray_shape != null:
		var ray_box := _unique_ray_box()
		ray_box.size = focus_box_size
	if _ray_target != null:
		_ray_target.position = focus_offset
	if _proximity_shape != null:
		_proximity_shape.position = focus_offset
		var proximity_box := _unique_proximity_box()
		proximity_box.size = proximity_box_size


func _unique_ray_box() -> BoxShape3D:
	if not _owns_ray_shape:
		var shared := _ray_shape.shape as BoxShape3D
		var box := shared.duplicate() if shared else BoxShape3D.new()
		_ray_shape.shape = box
		_owns_ray_shape = true
		return box
	return _ray_shape.shape as BoxShape3D


func _unique_proximity_box() -> BoxShape3D:
	if not _owns_proximity_shape:
		var shared := _proximity_shape.shape as BoxShape3D
		var box := shared.duplicate() if shared else BoxShape3D.new()
		_proximity_shape.shape = box
		_owns_proximity_shape = true
		return box
	return _proximity_shape.shape as BoxShape3D


func can_handle_interaction() -> bool:
	if not _is_bathroom_accessible():
		return false
	if not GameManager.get_flag(WANTS_SINK_FLAG):
		return false
	if _horror == null:
		return false
	return _horror.is_sequence_available() and not _horror.is_sequence_running()


func get_interaction_prompt() -> String:
	if can_handle_interaction():
		return prompt_text
	return ""


func handle_interaction() -> void:
	if not can_handle_interaction() or _horror == null:
		return
	_horror.run_sequence()


func _is_bathroom_accessible() -> bool:
	if bathroom_door_path.is_empty():
		return true
	var door := _resolve_scene_node(bathroom_door_path) as DoorInteractSetup
	if door == null:
		return true
	return door.opened


func _resolve_scene_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var local := get_node_or_null(path)
	if local != null:
		return local
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null(path)
