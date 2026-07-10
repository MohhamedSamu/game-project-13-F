extends CharacterBody3D

const GHOST_REVEAL_STARTED_FLAG := &"supermarket_ghost_reveal_started"
const GHOST_REVEAL_DONE_FLAG := &"supermarket_ghost_reveal_done"
const READY_FOR_JUMPSCARE_FLAG := &"ready_for_cashier_jumpscare"

@onready var _dialogue: InteractableDialogueComponent = $InteractableDialogueComponent


func _is_ghost_reveal_blocking_interaction() -> bool:
	if GameManager.get_flag(GHOST_REVEAL_DONE_FLAG):
		return false
	return (
		GameManager.get_flag(READY_FOR_JUMPSCARE_FLAG)
		or GameManager.get_flag(GHOST_REVEAL_STARTED_FLAG)
	)


func can_handle_interaction() -> bool:
	if _is_ghost_reveal_blocking_interaction():
		return false
	return true


func get_interaction_prompt() -> String:
	if _is_ghost_reveal_blocking_interaction():
		return ""
	if ChurroCounterFlow.can_place_churro():
		return ChurroCounterFlow.PROMPT_PLACE
	if CocaCounterFlow.can_place_coca():
		return CocaCounterFlow.PROMPT_PLACE
	return _dialogue.prompt_text


func handle_interaction() -> void:
	if _is_ghost_reveal_blocking_interaction():
		return
	if ChurroCounterFlow.can_place_churro():
		ChurroCounterFlow.place_churro_from_cashier($DialogueFocusPoint)
		return
	if CocaCounterFlow.can_place_coca():
		CocaCounterFlow.place_coca_from_cashier($DialogueFocusPoint)
		return
	_dialogue.call("_begin_dialogue_interaction")
