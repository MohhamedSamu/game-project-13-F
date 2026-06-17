class_name LockedDoorComponent
extends Node
## Puerta bloqueada por item en mano. Delegado desde InteractableDialogueComponent.

@export_group("Required Item")
@export var required_item_id: StringName = &"bathroom_key"
@export var consume_key_on_unlock: bool = true

@export_group("State")
@export var unlocked: bool = false
@export var opened: bool = false
@export var unlocked_flag: String = "bathroom_door_unlocked"
@export var restore_as_open: bool = true

@export_group("Door Motion")
@export var door_pivot: Node3D
@export var door_node_path: NodePath = NodePath("../../Door_01")
@export var hinge_offset: Vector3 = Vector3(0, -0.00525, 0.00448)
@export var open_angle_degrees: float = 90.0
@export var open_duration: float = 0.8
@export var open_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var open_transition: Tween.TransitionType = Tween.TRANS_SINE
## Eje local del pivot que apunta al mundo vertical en Door01InteractSetup (Z local).
@export var pivot_rotation_axis: Vector3 = Vector3.FORWARD

@export_group("Dialogue")
@export var dialogue_resource: DialogueResource
@export var locked_dialogue_title: String = "locked"
@export var unlock_dialogue_title: String = "unlocked"
@export var focus_target: Node3D

@export_group("References")
@export var interactable_component: InteractableDialogueComponent

var waiting_for_unlock_dialogue: bool = false
var _door_attached: bool = false


func _ready() -> void:
	if focus_target == null:
		focus_target = get_parent().get_node_or_null("DialogueFocusPoint") as Node3D
	if interactable_component == null:
		interactable_component = get_parent().get_node_or_null(
			"InteractableDialogueComponent"
		) as InteractableDialogueComponent

	if GameManager.get_flag(unlocked_flag):
		unlocked = true

	_setup_door_pivot()


func can_handle_interaction() -> bool:
	if unlocked and opened:
		return false
	return true


func get_interaction_prompt() -> String:
	if unlocked and opened:
		return ""
	if not unlocked:
		var player := GameManager.player
		if player != null and player.has_method("is_holding_item"):
			if player.is_holding_item(required_item_id):
				return "Presiona [E] para usar la llave"
	return "Presiona [E] para interactuar"


func handle_interaction() -> void:
	try_interact()


func try_interact() -> void:
	if GameManager.dialogue_active:
		return

	if unlocked:
		if not opened:
			open_door()
		return

	var player := GameManager.player
	if player == null:
		return

	if not player.has_method("is_holding_item"):
		push_warning("LockedDoorComponent: el jugador no expone is_holding_item().")
		_start_locked_dialogue()
		return

	if not player.is_holding_item(required_item_id):
		_start_locked_dialogue()
		return

	unlock_and_open()


func unlock_and_open() -> void:
	if unlocked:
		return

	unlocked = true
	GameManager.set_flag(unlocked_flag, true)

	var player := GameManager.player
	if consume_key_on_unlock and player != null and player.has_method("consume_held_item"):
		player.consume_held_item(required_item_id)

	if dialogue_resource != null and not unlock_dialogue_title.is_empty():
		waiting_for_unlock_dialogue = true
		DialogueController.dialogue_finished.connect(_on_unlock_dialogue_finished, CONNECT_ONE_SHOT)
		DialogueController.start_dialogue(dialogue_resource, unlock_dialogue_title, focus_target)
	else:
		open_door()


func open_door() -> void:
	if opened or door_pivot == null:
		return
	if not _door_attached:
		call_deferred("open_door")
		return

	opened = true
	var start_angle := _get_pivot_axis_rotation()
	var target_angle := start_angle + deg_to_rad(open_angle_degrees)

	var tween := create_tween()
	tween.set_trans(open_transition)
	tween.set_ease(open_ease)
	tween.tween_method(_set_pivot_axis_rotation, start_angle, target_angle, open_duration)


func is_open() -> bool:
	return opened


func can_unlock() -> bool:
	var player := GameManager.player
	if player == null or not player.has_method("is_holding_item"):
		return false
	return player.is_holding_item(required_item_id)


func _start_locked_dialogue() -> void:
	if dialogue_resource == null:
		return
	DialogueController.start_dialogue(dialogue_resource, locked_dialogue_title, focus_target)


func _on_unlock_dialogue_finished() -> void:
	if not waiting_for_unlock_dialogue:
		return
	waiting_for_unlock_dialogue = false
	open_door()


func _setup_door_pivot() -> void:
	if door_pivot == null:
		door_pivot = get_parent().get_node_or_null("DoorPivot") as Node3D
	if door_pivot == null:
		push_warning("LockedDoorComponent: falta DoorPivot.")
		return

	door_pivot.position = hinge_offset
	call_deferred("_attach_door_to_pivot")


func _attach_door_to_pivot() -> void:
	if _door_attached or door_pivot == null:
		return

	var door := get_node_or_null(door_node_path) as Node3D
	if door == null:
		push_warning("LockedDoorComponent: no se encontró la puerta en %s" % door_node_path)
		return

	if door.get_parent() == door_pivot:
		_door_attached = true
		_on_door_attached()
		return

	door.reparent(door_pivot, true)
	_door_attached = true
	_on_door_attached()


func _on_door_attached() -> void:
	if unlocked and restore_as_open and not opened:
		_apply_open_state_immediate()


func _apply_open_state_immediate() -> void:
	opened = true
	if door_pivot == null:
		return
	_set_pivot_axis_rotation(_get_pivot_axis_rotation() + deg_to_rad(open_angle_degrees))


func _get_pivot_axis_rotation() -> float:
	if pivot_rotation_axis.is_equal_approx(Vector3.RIGHT):
		return door_pivot.rotation.x
	if pivot_rotation_axis.is_equal_approx(Vector3.FORWARD) or pivot_rotation_axis.is_equal_approx(Vector3.BACK):
		return door_pivot.rotation.z
	return door_pivot.rotation.y


func _set_pivot_axis_rotation(value: float) -> void:
	if pivot_rotation_axis.is_equal_approx(Vector3.RIGHT):
		door_pivot.rotation.x = value
	elif pivot_rotation_axis.is_equal_approx(Vector3.FORWARD) or pivot_rotation_axis.is_equal_approx(Vector3.BACK):
		door_pivot.rotation.z = value
	else:
		door_pivot.rotation.y = value
