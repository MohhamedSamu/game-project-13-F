class_name CocaCounterFlow
extends RefCounted
## Flujo: Coca en mano izquierda → mostrador → diálogo cajera → needs_churro.

const DIALOGUE: DialogueResource = preload("res://dialogues/coca_counter.dialogue")
const THOUGHT_AFTER_PICKUP := "ahora iré a dejarla en el mostrador"
const PROMPT_PLACE := "Presiona [E] para dejar la coca"


static func can_place_coca() -> bool:
	if GameManager.get_flag("coca_placed_on_counter"):
		return false
	if not GameManager.get_flag("has_coca_in_left_hand"):
		return false
	var player := GameManager.get_player()
	if player != null and player.has_method("has_left_hand_item"):
		return player.has_left_hand_item()
	return true


static func on_coca_received_in_hand() -> void:
	GameManager.set_flag("has_coca_in_left_hand", true)
	GameManager.set_flag("coca_placed_on_counter", false)
	GameManager.set_flag("needs_churro", false)
	CounterPlaceCamera.refresh_counter_interact_areas()
	SupermarketExitBlocker.set_enabled(true)
	InnerThoughts.show_thought(THOUGHT_AFTER_PICKUP)


static func place_coca_from_counter(setup: Node) -> void:
	var focus: Node3D = null
	if setup != null and setup.has_method("get_cashier_focus"):
		focus = setup.get_cashier_focus()
	_execute_place(setup, true, focus)


static func place_coca_from_cashier(focus_target: Node3D) -> void:
	_execute_place(null, false, focus_target)


static func _execute_place(
	setup: Node,
	use_camera_focus: bool,
	focus_target: Node3D
) -> void:
	if not can_place_coca():
		return
	var player := GameManager.get_player()
	if player == null or not player.has_method("clear_left_hand_item"):
		return
	if not player.clear_left_hand_item():
		return

	var place_setup := setup
	if place_setup == null or not place_setup.has_method("spawn_counter_coca"):
		place_setup = _find_place_setup()
	if place_setup == null:
		push_warning("CocaCounterFlow: no se encontró CocaCounterPlaceSetup.")
		return

	place_setup.spawn_counter_coca()

	GameManager.set_flag("has_coca_in_left_hand", false)
	GameManager.set_flag("coca_placed_on_counter", true)
	CounterPlaceCamera.refresh_counter_interact_areas()
	InnerThoughts.hide_thought()

	var focus := focus_target
	if focus == null and place_setup.has_method("get_cashier_focus"):
		focus = place_setup.get_cashier_focus()

	if DialogueController.dialogue_finished.is_connected(_on_counter_dialogue_finished):
		DialogueController.dialogue_finished.disconnect(_on_counter_dialogue_finished)
	DialogueController.dialogue_finished.connect(_on_counter_dialogue_finished, CONNECT_ONE_SHOT)
	var focus_speed := CounterPlaceCamera.resolve_focus_speed(place_setup, use_camera_focus)
	DialogueController.start_dialogue(DIALOGUE, "start", focus, use_camera_focus, focus_speed)


static func _find_place_setup() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("coca_counter_place")


static func _on_counter_dialogue_finished() -> void:
	GameManager.set_flag("needs_churro", true)
	CounterPlaceCamera.refresh_counter_interact_areas()
	InnerThoughts.show_thought(ChurroCounterFlow.THOUGHT_AFTER_COCA, 0.0)
