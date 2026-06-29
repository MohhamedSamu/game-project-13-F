extends Node

signal dialogue_finished

var current_balloon: Node = null
var current_focus_target: Node3D = null

func start_dialogue(dialogue_resource: DialogueResource, title: String = "start", focus_target: Node3D = null) -> void:
	_run_start_dialogue(dialogue_resource, title, focus_target)


func _run_start_dialogue(dialogue_resource: DialogueResource, title: String, focus_target: Node3D) -> void:
	if GameManager.dialogue_active:
		return

	if dialogue_resource == null:
		push_warning("DialogueController: dialogue_resource is null.")
		return

	if GameManager.player and GameManager.player.has_method("stop_movement_immediately"):
		GameManager.player.stop_movement_immediately()

	current_focus_target = focus_target
	GameManager.lock_player()

	# Cámara y desplazamiento en paralelo (misma ventana de tiempo).
	if GameManager.player and focus_target and GameManager.player.has_method("focus_camera_on"):
		GameManager.player.focus_camera_on(focus_target)

	var stand_owner := _find_dialogue_stand_owner(focus_target)
	if stand_owner is DialogueFocusPoint and not (stand_owner as DialogueFocusPoint).use_stand_position:
		stand_owner = null
	if (
		GameManager.player
		and stand_owner
		and GameManager.player.has_method("reposition_for_dialogue")
	):
		await GameManager.player.reposition_for_dialogue(stand_owner.get_dialogue_stand_position())

	current_balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, title)

	if current_balloon:
		current_balloon.tree_exited.connect(_on_dialogue_finished)
	else:
		GameManager.unlock_player()


func _find_dialogue_stand_owner(focus_target: Node3D) -> Node:
	if focus_target == null:
		return null
	var node: Node = focus_target
	while node != null:
		if node.has_method("get_dialogue_stand_position"):
			return node
		node = node.get_parent()
	return null


func _on_dialogue_finished() -> void:
	current_balloon = null
	current_focus_target = null
	GameManager.unlock_player()
	if get_tree() != null:
		dialogue_finished.emit()
