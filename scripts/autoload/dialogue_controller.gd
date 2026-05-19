extends Node

var current_balloon: Node = null
var current_focus_target: Node3D = null

func start_dialogue(dialogue_resource: DialogueResource, title: String = "start", focus_target: Node3D = null) -> void:
	if GameManager.dialogue_active:
		return

	if dialogue_resource == null:
		push_warning("DialogueController: dialogue_resource is null.")
		return

	current_focus_target = focus_target

	GameManager.lock_player()

	if GameManager.player and focus_target and GameManager.player.has_method("focus_camera_on"):
		GameManager.player.focus_camera_on(focus_target)

	current_balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, title)

	if current_balloon:
		current_balloon.tree_exited.connect(_on_dialogue_finished)
	else:
		GameManager.unlock_player()

func _on_dialogue_finished() -> void:
	current_balloon = null
	current_focus_target = null
	GameManager.unlock_player()
