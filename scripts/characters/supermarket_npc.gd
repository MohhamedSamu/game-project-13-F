extends CharacterBody3D

@onready var _dialogue: InteractableDialogueComponent = $InteractableDialogueComponent


func can_handle_interaction() -> bool:
	return true


func get_interaction_prompt() -> String:
	if CocaCounterFlow.can_place_coca():
		return CocaCounterFlow.PROMPT_PLACE
	return _dialogue.prompt_text


func handle_interaction() -> void:
	if CocaCounterFlow.can_place_coca():
		CocaCounterFlow.place_coca_from_cashier($DialogueFocusPoint)
		return
	_dialogue.call("_begin_dialogue_interaction")
