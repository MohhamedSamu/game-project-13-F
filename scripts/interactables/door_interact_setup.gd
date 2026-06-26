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
const DOOR_REFERENCE_SCALE := 100.0

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
## Solo el desbloqueo con llave persiste entre visitas al nivel; abierto/cerrado no.
@export var open_state_flag: String = ""
@export var restore_as_open: bool = false

@export_group("Interacción")
@export_range(0.5, 8.0, 0.1) var proximity_radius: float = 3.5:
	set(value):
		proximity_radius = maxf(value, 0.5)
		_request_rebuild()
@export var require_ray_target: bool = true:
	set(value):
		require_ray_target = value
		_request_rebuild()
@export var require_line_of_sight: bool = true:
	set(value):
		require_line_of_sight = value
		_request_rebuild()
@export_range(0.0, 2.0, 0.05) var line_of_sight_margin: float = 0.25:
	set(value):
		line_of_sight_margin = maxf(value, 0.0)
		_request_rebuild()

@export var prompt_locked: String = "Presiona [E] para interactuar"
@export var prompt_use_key: String = "Presiona [E] para usar la llave"
@export var prompt_open: String = "Presiona [E] para abrir"
@export var prompt_close: String = "Presiona [E] para cerrar"

@export_group("Panel / mira")
## Centro del panel (bisagra, diálogo y referencia de detección).
@export var panel_center: Vector3 = DEFAULT_PANEL_CENTER:
	set(value):
		panel_center = value
		_request_rebuild()
@export var panel_half_width: float = DEFAULT_PANEL_HALF_WIDTH:
	set(value):
		panel_half_width = maxf(value, 0.0001)
		_request_rebuild()
## Desplazamiento extra del centro de proximidad respecto a panel_center.
@export var proximity_center_offset: Vector3 = Vector3.ZERO:
	set(value):
		proximity_center_offset = value
		_request_rebuild()
## Desplazamiento extra del hitbox de mira respecto a panel_center.
@export var ray_target_center_offset: Vector3 = Vector3.ZERO:
	set(value):
		ray_target_center_offset = value
		_request_rebuild()
@export_range(0.0005, 0.02, 0.0005) var ray_target_thickness: float = 0.002:
	set(value):
		ray_target_thickness = maxf(value, 0.0005)
		_request_rebuild()
@export_range(0.002, 0.05, 0.0005) var ray_target_height: float = 0.0105:
	set(value):
		ray_target_height = maxf(value, 0.002)
		_request_rebuild()
@export_range(0.005, 0.08, 0.001) var ray_target_width: float = 0.028:
	set(value):
		ray_target_width = maxf(value, 0.005)
		_request_rebuild()

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

@export_group("Audio")
## Sonido al abrir o cerrar la puerta (bus SFX del proyecto).
@export var open_sound: AudioStream = preload("res://assets/audio/SFX/door/Creaking_Door_2.mp3")

var opened: bool = false
var waiting_for_unlock_dialogue: bool = false

var _door_pivot: Node3D
var _focus_target: Node3D
var _interactable: InteractableDialogueComponent
var _ray_target: Area3D
var _ray_shape: CollisionShape3D
var _proximity_shape: CollisionShape3D
var _door_attached: bool = false
var _open_player: AudioStreamPlayer3D
var _owns_ray_shape: bool = false
var _is_animating: bool = false
var _closed_axis_rotation: float = 0.0
var _door_tween: Tween


func _enter_tree() -> void:
	_cache_child_refs()
	_rebuild()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_load_persistent_state()
	_setup_door_pivot()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_TRANSFORM_CHANGED:
		if Engine.is_editor_hint():
			_rebuild()


func _request_rebuild() -> void:
	if is_inside_tree():
		_rebuild()
	elif Engine.is_editor_hint():
		call_deferred("_rebuild")


func _cache_child_refs() -> void:
	_door_pivot = get_node_or_null("DoorPivot") as Node3D
	_focus_target = get_node_or_null("DialogueFocusPoint") as Node3D
	_interactable = get_node_or_null("InteractableDialogueComponent") as InteractableDialogueComponent
	_ray_target = get_node_or_null("InteractionRayTarget") as Area3D
	if _ray_target != null:
		_ray_shape = _ray_target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _interactable != null:
		_proximity_shape = _interactable.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_open_player = get_node_or_null("Audio/OpenSoundPlayer") as AudioStreamPlayer3D


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_cache_child_refs()
	_apply_configuration()


func _apply_configuration() -> void:
	if _interactable != null:
		_interactable.proximity_radius = proximity_radius
		_interactable.require_specific_ray_target = require_ray_target
		_interactable.require_line_of_sight = require_line_of_sight
		_interactable.line_of_sight_margin = line_of_sight_margin
		_interactable.proximity_center_offset = _to_reference_space_vec(proximity_center_offset)
		_interactable.dialogue_resource = dialogue_resource

	var focus_offset := _to_reference_space_vec(panel_center)
	if _focus_target != null:
		_focus_target.position = focus_offset

	var ray_offset := _get_ray_target_center_local()
	if _ray_shape != null:
		_ray_shape.position = ray_offset
		var box := _unique_ray_box()
		box.size = Vector3(
			_to_reference_space(ray_target_thickness),
			_to_reference_space(ray_target_height),
			_to_reference_space(ray_target_width)
		)

	if _door_pivot != null and Engine.is_editor_hint():
		_door_pivot.position = _compute_hinge_offset()

	_apply_audio_configuration()


func _get_ray_target_center_local() -> Vector3:
	return _to_reference_space_vec(panel_center + ray_target_center_offset)


func _unique_ray_box() -> BoxShape3D:
	if not _owns_ray_shape:
		var shared := _ray_shape.shape as BoxShape3D
		var box := shared.duplicate() if shared else BoxShape3D.new()
		_ray_shape.shape = box
		_owns_ray_shape = true
		return box
	return _ray_shape.shape as BoxShape3D


func _load_persistent_state() -> void:
	opened = false
	if lock_mode == LockMode.ITEM_REQUIRED and not unlocked_flag.is_empty():
		unlocked = GameManager.get_flag(unlocked_flag)


# --- API delegada desde InteractableDialogueComponent ---

func can_handle_interaction() -> bool:
	return not _is_animating


func get_interaction_prompt() -> String:
	if _is_animating:
		return ""
	if opened:
		return prompt_close
	if lock_mode == LockMode.ITEM_REQUIRED and not unlocked:
		var player := GameManager.player
		if player != null and player.has_method("is_holding_item"):
			if player.is_holding_item(required_item_id):
				return prompt_use_key
		return prompt_locked
	return prompt_open


func handle_interaction() -> void:
	try_interact()


func try_interact() -> void:
	if GameManager.dialogue_active or _is_animating:
		return

	if lock_mode == LockMode.ITEM_REQUIRED and not unlocked:
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
		return

	if opened:
		close_door()
	else:
		_open_or_dialogue()


func _open_or_dialogue() -> void:
	if dialogue_resource != null and not unlock_dialogue_title.is_empty() and lock_mode == LockMode.NONE:
		waiting_for_unlock_dialogue = true
		DialogueController.dialogue_finished.connect(_on_unlock_dialogue_finished, CONNECT_ONE_SHOT)
		DialogueController.start_dialogue(dialogue_resource, unlock_dialogue_title, _focus_target)
	else:
		open_door()


func _unlock_and_open() -> void:
	if unlocked:
		if opened:
			return
		open_door()
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
	if opened or _door_pivot == null or _is_animating:
		return
	if not _door_attached:
		call_deferred("open_door")
		return

	opened = true
	var target_angle := _closed_axis_rotation + deg_to_rad(open_angle_degrees)
	_animate_door_to(target_angle)


func close_door() -> void:
	if not opened or _door_pivot == null or _is_animating:
		return
	if not _door_attached:
		return

	opened = false
	_animate_door_to(_closed_axis_rotation)


func _animate_door_to(target_angle: float) -> void:
	_kill_door_tween()
	_is_animating = true
	_play_open_sound()

	var start_angle := _get_pivot_axis_rotation()
	_door_tween = create_tween()
	_door_tween.set_trans(open_transition)
	_door_tween.set_ease(open_ease)
	_door_tween.tween_method(_set_pivot_axis_rotation, start_angle, target_angle, open_duration)
	_door_tween.finished.connect(_on_door_animation_finished)


func _on_door_animation_finished() -> void:
	_is_animating = false
	_door_tween = null


func _kill_door_tween() -> void:
	if _door_tween != null and _door_tween.is_valid() and _door_tween.is_running():
		_door_tween.kill()
	_door_tween = null
	_is_animating = false


func _apply_audio_configuration() -> void:
	if _open_player == null:
		return
	_open_player.position = _to_reference_space_vec(panel_center)
	_open_player.bus = &"SFX"
	if open_sound != null:
		_open_player.stream = open_sound


func _get_setup_uniform_scale() -> float:
	var s := global_transform.basis.get_scale()
	return maxf(abs(s.x), maxf(abs(s.y), abs(s.z)))


func _reference_space_factor() -> float:
	var uniform_scale := _get_setup_uniform_scale()
	if uniform_scale < 0.0001:
		return 1.0
	return DOOR_REFERENCE_SCALE / uniform_scale


func _to_reference_space(value: float) -> float:
	return value * _reference_space_factor()


func _to_reference_space_vec(value: Vector3) -> Vector3:
	return value * _reference_space_factor()


func _play_open_sound() -> void:
	if open_sound == null or _open_player == null:
		return
	_apply_audio_configuration()
	_open_player.stop()
	_open_player.play()


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
	var panel := _to_reference_space_vec(panel_center)
	var half_w := _to_reference_space(panel_half_width)
	var side := 1.0 if hinge_on_positive_y else -1.0
	return panel + Vector3(0.0, side * half_w, 0.0)


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
	_closed_axis_rotation = _get_pivot_axis_rotation()
	if not opened:
		_set_pivot_axis_rotation(_closed_axis_rotation)


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
