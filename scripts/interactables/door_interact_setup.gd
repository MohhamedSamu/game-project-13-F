@tool
class_name DoorInteractSetup
extends Node3D
## Prefab reutilizable de puerta interactuable. Configura cada instancia desde el nivel
## (door_mesh_path, bloqueo, bisagra, diálogo, etc.) sin duplicar la escena base.

enum LockMode {
	NONE,
	ITEM_REQUIRED,
}

const DEFAULT_PANEL_CENTER := Vector3(0.0, 0.00448, -0.000335)
const DEFAULT_PANEL_HALF_WIDTH := 0.00525

@export_group("Puerta (mesh)")
## Hermano del setup bajo el mismo padre (p. ej. ../Door_01).
@export var door_mesh_path: NodePath

@export_group("Bloqueo")
@export var lock_mode: LockMode = LockMode.ITEM_REQUIRED

@export var required_item_id: StringName = &"bathroom_key"
@export var consume_key_on_unlock: bool = true
@export var unlocked: bool = false
@export var unlocked_flag: String = "bathroom_door_unlocked"

@export_group("Estado persistente")
## Si no está vacío, recuerda que la puerta ya se abrió (modo sin llave).
@export var open_state_flag: String = ""
@export var restore_as_open: bool = true

@export_group("Interacción")
@export var proximity_radius: float = 3.5
@export var require_ray_target: bool = true

@export var prompt_locked: String = "Presiona [E] para interactuar"
@export var prompt_use_key: String = "Presiona [E] para usar la llave"
@export var prompt_open: String = "Presiona [E] para abrir"

@export_group("Panel / mira")
@export var panel_center: Vector3 = DEFAULT_PANEL_CENTER
@export var panel_half_width: float = DEFAULT_PANEL_HALF_WIDTH
@export var ray_target_thickness: float = 0.002
@export var ray_target_height: float = 0.0105
@export var ray_target_width: float = 0.028

@export_group("Apertura")
@export var hinge_on_positive_y: bool = false

@export var open_angle_degrees: float = 90.0
@export var open_duration: float = 1.8
@export var open_ease: Tween.EaseType = Tween.EASE_OUT
@export var open_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var pivot_rotation_axis: Vector3 = Vector3.FORWARD

@export_group("Diálogo")
@export var dialogue_resource: DialogueResource
@export var locked_dialogue_title: String = "locked"
@export var unlock_dialogue_title: String = "unlocked"

var opened: bool = false
var waiting_for_unlock_dialogue: bool = false

var _door_pivot: Node3D
var _focus_target: Node3D
var _interactable: InteractableDialogueComponent
var _ray_target: Area3D
var _ray_shape: CollisionShape3D
var _proximity_shape: CollisionShape3D
var _door_attached: bool = false


func _enter_tree() -> void:
	_cache_child_refs()
	_apply_configuration()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_load_persistent_state()
	_setup_door_pivot()


func _cache_child_refs() -> void:
	_door_pivot = get_node_or_null("DoorPivot") as Node3D
	_focus_target = get_node_or_null("DialogueFocusPoint") as Node3D
	_interactable = get_node_or_null("InteractableDialogueComponent") as InteractableDialogueComponent
	_ray_target = get_node_or_null("InteractionRayTarget") as Area3D
	if _ray_target != null:
		_ray_shape = _ray_target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _interactable != null:
		_proximity_shape = _interactable.get_node_or_null("CollisionShape3D") as CollisionShape3D


func _apply_configuration() -> void:
	if _interactable != null:
		_interactable.proximity_radius = proximity_radius
		_interactable.require_specific_ray_target = require_ray_target
		_interactable.dialogue_resource = dialogue_resource

	var focus_offset := panel_center
	if _focus_target != null:
		_focus_target.position = focus_offset

	if _proximity_shape != null:
		_proximity_shape.position = focus_offset

	if _ray_shape != null:
		_ray_shape.position = focus_offset
		var box := _ray_shape.shape as BoxShape3D
		if box == null:
			box = BoxShape3D.new()
			_ray_shape.shape = box
		box.size = Vector3(ray_target_thickness, ray_target_height, ray_target_width)

	if _door_pivot != null and Engine.is_editor_hint():
		_door_pivot.position = _compute_hinge_offset()


func _load_persistent_state() -> void:
	if lock_mode == LockMode.ITEM_REQUIRED and not unlocked_flag.is_empty():
		unlocked = GameManager.get_flag(unlocked_flag)
	elif lock_mode == LockMode.NONE and not open_state_flag.is_empty():
		if GameManager.get_flag(open_state_flag):
			opened = true


# --- API delegada desde InteractableDialogueComponent ---

func can_handle_interaction() -> bool:
	return not opened


func get_interaction_prompt() -> String:
	if opened:
		return ""
	if lock_mode == LockMode.ITEM_REQUIRED and not unlocked:
		var player := GameManager.player
		if player != null and player.has_method("is_holding_item"):
			if player.is_holding_item(required_item_id):
				return prompt_use_key
	return prompt_open if lock_mode == LockMode.NONE else prompt_locked


func handle_interaction() -> void:
	try_interact()


func try_interact() -> void:
	if GameManager.dialogue_active:
		return

	if lock_mode == LockMode.NONE or unlocked:
		if not opened:
			_open_or_dialogue()
		return

	var player := GameManager.player
	if player == null:
		return

	if not player.has_method("is_holding_item"):
		push_warning("DoorInteractSetup: el jugador no expone is_holding_item().")
		_start_locked_dialogue()
		return

	if not player.is_holding_item(required_item_id):
		_start_locked_dialogue()
		return

	_unlock_and_open()


func _open_or_dialogue() -> void:
	if dialogue_resource != null and not unlock_dialogue_title.is_empty() and lock_mode == LockMode.NONE:
		waiting_for_unlock_dialogue = true
		DialogueController.dialogue_finished.connect(_on_unlock_dialogue_finished, CONNECT_ONE_SHOT)
		DialogueController.start_dialogue(dialogue_resource, unlock_dialogue_title, _focus_target)
	else:
		open_door()


func _unlock_and_open() -> void:
	if unlocked:
		return

	unlocked = true
	if not unlocked_flag.is_empty():
		GameManager.set_flag(unlocked_flag, true)

	var player := GameManager.player
	if consume_key_on_unlock and player != null and player.has_method("consume_held_item"):
		player.consume_held_item(required_item_id)

	if dialogue_resource != null and not unlock_dialogue_title.is_empty():
		waiting_for_unlock_dialogue = true
		DialogueController.dialogue_finished.connect(_on_unlock_dialogue_finished, CONNECT_ONE_SHOT)
		DialogueController.start_dialogue(dialogue_resource, unlock_dialogue_title, _focus_target)
	else:
		open_door()


func open_door() -> void:
	if opened or _door_pivot == null:
		return
	if not _door_attached:
		call_deferred("open_door")
		return

	opened = true
	if not open_state_flag.is_empty():
		GameManager.set_flag(open_state_flag, true)

	var start_angle := _get_pivot_axis_rotation()
	var target_angle := start_angle + deg_to_rad(open_angle_degrees)

	var tween := create_tween()
	tween.set_trans(open_transition)
	tween.set_ease(open_ease)
	tween.tween_method(_set_pivot_axis_rotation, start_angle, target_angle, open_duration)


func _start_locked_dialogue() -> void:
	if dialogue_resource == null:
		return
	DialogueController.start_dialogue(dialogue_resource, locked_dialogue_title, _focus_target)


func _on_unlock_dialogue_finished() -> void:
	if not waiting_for_unlock_dialogue:
		return
	waiting_for_unlock_dialogue = false
	open_door()


func _setup_door_pivot() -> void:
	if _door_pivot == null:
		push_warning("DoorInteractSetup: falta nodo DoorPivot.")
		return

	_door_pivot.position = _compute_hinge_offset()
	_door_pivot.rotation = Vector3.ZERO
	call_deferred("_attach_door_to_pivot")


func _compute_hinge_offset() -> Vector3:
	var side := 1.0 if hinge_on_positive_y else -1.0
	return panel_center + Vector3(0.0, side * panel_half_width, 0.0)


func _attach_door_to_pivot() -> void:
	if _door_attached or _door_pivot == null:
		return

	if door_mesh_path.is_empty():
		push_warning("DoorInteractSetup: asigna door_mesh_path en esta instancia.")
		return

	var door := get_node_or_null(door_mesh_path) as Node3D
	if door == null:
		push_warning("DoorInteractSetup: no se encontró la puerta en %s" % door_mesh_path)
		return

	if door.get_parent() == _door_pivot:
		_door_attached = true
		_on_door_attached()
		return

	var door_global := door.global_transform
	door.reparent(_door_pivot, false)
	door.global_transform = door_global
	_door_attached = true
	_on_door_attached()


func _on_door_attached() -> void:
	var should_restore := false
	if lock_mode == LockMode.ITEM_REQUIRED:
		should_restore = unlocked and restore_as_open and not opened
	elif lock_mode == LockMode.NONE and not open_state_flag.is_empty():
		should_restore = opened and restore_as_open

	if should_restore:
		_apply_open_state_immediate()


func _apply_open_state_immediate() -> void:
	opened = true
	if _door_pivot == null:
		return
	_set_pivot_axis_rotation(_get_pivot_axis_rotation() + deg_to_rad(open_angle_degrees))


func _get_pivot_axis_rotation() -> float:
	if pivot_rotation_axis.is_equal_approx(Vector3.RIGHT):
		return _door_pivot.rotation.x
	if pivot_rotation_axis.is_equal_approx(Vector3.FORWARD) or pivot_rotation_axis.is_equal_approx(Vector3.BACK):
		return _door_pivot.rotation.z
	return _door_pivot.rotation.y


func _set_pivot_axis_rotation(value: float) -> void:
	if pivot_rotation_axis.is_equal_approx(Vector3.RIGHT):
		_door_pivot.rotation.x = value
	elif pivot_rotation_axis.is_equal_approx(Vector3.FORWARD) or pivot_rotation_axis.is_equal_approx(Vector3.BACK):
		_door_pivot.rotation.z = value
	else:
		_door_pivot.rotation.y = value
