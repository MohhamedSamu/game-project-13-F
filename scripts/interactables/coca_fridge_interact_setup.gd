extends Node3D

@export var coca_scene: PackedScene = preload("res://scenes/interactables/coca_bottle/coca_bottle.tscn")
@export var require_scene4_complete: bool = true

@onready var _dialogue: InteractableDialogueComponent = $InteractableDialogueComponent


func _ready() -> void:
	_sync_dialogue_enabled()


func can_handle_interaction() -> bool:
	if require_scene4_complete and not GameManager.is_supermarket_scene5_unlocked():
		return false
	if GameManager.get_flag("has_coca_in_left_hand") or GameManager.get_flag("coca_placed_on_counter"):
		return false
	return true


func get_interaction_prompt() -> String:
	if not can_handle_interaction():
		return ""
	return _dialogue.prompt_text


func handle_interaction() -> void:
	if not can_handle_interaction():
		return
	DialogueController.dialogue_finished.connect(_on_dialogue_finished_give_coca, CONNECT_ONE_SHOT)
	_dialogue.call("_begin_dialogue_interaction")


func _on_dialogue_finished_give_coca() -> void:
	var player := GameManager.get_player()
	if player == null or not player.has_method("give_left_hand_item"):
		return
	if player.give_left_hand_item(coca_scene):
		CocaCounterFlow.on_coca_received_in_hand()


func _sync_dialogue_enabled() -> void:
	if _dialogue == null:
		return
	# Mantener el Area activo mientras escena 4 esté pendiente; can_handle_interaction() filtra en runtime.
	var blocked_by_coca := (
		GameManager.get_flag("has_coca_in_left_hand")
		or GameManager.get_flag("coca_placed_on_counter")
	)
	_dialogue.enabled = not blocked_by_coca


func refresh_interaction_state() -> void:
	_sync_dialogue_enabled()
