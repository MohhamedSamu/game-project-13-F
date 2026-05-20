class_name ProximityDialogueComponent
extends Area3D
## Diálogo automático al entrar en esta área. No usa raycast ni tecla E.

@export var dialogue_resource: DialogueResource
@export var dialogue_title: String = "start"

@export var enabled: bool = true
@export var trigger_once: bool = true
@export var already_triggered: bool = false

@export var focus_target: Node3D

@export_group("Flags / Conditions")
@export var required_flag: String = ""
@export var required_flag_value: bool = true
@export var set_flag_on_trigger: String = ""
@export var set_flag_value: bool = true


func _ready() -> void:
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)

	if focus_target == null:
		focus_target = get_parent().get_node_or_null("IceFocusPoint") as Node3D

	call_deferred("_check_overlapping_bodies")


func _check_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		if body is Node3D and body.is_in_group("player"):
			_try_trigger_dialogue()
			return


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_try_trigger_dialogue()


func _try_trigger_dialogue() -> void:
	if not enabled:
		return
	if GameManager.dialogue_active:
		return
	if trigger_once and already_triggered:
		return
	if dialogue_resource == null:
		push_warning("ProximityDialogueComponent: dialogue_resource is null.")
		return
	if required_flag != "":
		if GameManager.get_flag(required_flag) != required_flag_value:
			return

	already_triggered = true

	if set_flag_on_trigger != "":
		GameManager.set_flag(set_flag_on_trigger, set_flag_value)

	DialogueController.start_dialogue(dialogue_resource, dialogue_title, focus_target)
