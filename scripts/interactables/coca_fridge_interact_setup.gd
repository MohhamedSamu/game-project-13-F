extends Node3D

@export var coca_scene: PackedScene = preload("res://scenes/interactables/coca_bottle/coca_bottle.tscn")

@onready var _dialogue: InteractableDialogueComponent = $InteractableDialogueComponent


func can_handle_interaction() -> bool:
	# No llamar _dialogue.can_interact(): el componente ya delega aquí y provoca recursión.
	return true


func get_interaction_prompt() -> String:
	# No llamar _dialogue.get_interaction_prompt(): el componente ya delega aquí.
	return _dialogue.prompt_text


func handle_interaction() -> void:
	DialogueController.dialogue_finished.connect(_on_dialogue_finished_give_coca, CONNECT_ONE_SHOT)
	_dialogue.call("_begin_dialogue_interaction")


func _on_dialogue_finished_give_coca() -> void:
	var player := GameManager.get_player()
	if player == null or not player.has_method("give_left_hand_item"):
		return
	if player.give_left_hand_item(coca_scene):
		CocaCounterFlow.on_coca_received_in_hand()
