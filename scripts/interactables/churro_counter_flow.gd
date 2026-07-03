class_name ChurroCounterFlow
extends RefCounted
## Flujo: churro en estantería → HandLeft → mostrador → diálogo cajera → listo para jumpscare.

const DIALOGUE: DialogueResource = preload("res://dialogues/churro_counter.dialogue")
const THOUGHT_AFTER_COCA := "ahora iré por un churro"
const PROMPT_PLACE := "Presiona [E] para dejar el churro"


static func can_place_churro() -> bool:
	return GameManager.can_place_churro_on_counter()


static func on_churro_received_in_hand() -> void:
	GameManager.set_flag("has_churro_in_left_hand", true)
	GameManager.set_flag("churro_taken", true)
	GameManager.set_flag("needs_churro", false)
	InnerThoughts.hide_thought()


static func place_churro_from_counter(setup: Node) -> void:
	var focus: Node3D = null
	if setup != null and setup.has_method("get_cashier_focus"):
		focus = setup.get_cashier_focus()
	_execute_place(setup, true, focus)


static func place_churro_from_cashier(focus_target: Node3D) -> void:
	_execute_place(null, false, focus_target)


static func _execute_place(
	setup: Node,
	use_camera_focus: bool,
	focus_target: Node3D
) -> void:
	if not can_place_churro():
		return
	var player := GameManager.get_player()
	if player == null or not player.has_method("detach_left_hand_item"):
		return
	var item := player.detach_left_hand_item() as Node3D
	if item == null:
		return

	var place_setup := setup
	if place_setup == null or not place_setup.has_method("place_counter_churro"):
		place_setup = _find_place_setup()
	if place_setup == null:
		push_warning("ChurroCounterFlow: no se encontró ChurroCounterPlaceSetup.")
		item.queue_free()
		return

	place_setup.place_counter_churro(item)

	GameManager.set_flag("has_churro_in_left_hand", false)

	var focus := focus_target
	if focus == null and place_setup.has_method("get_cashier_focus"):
		focus = place_setup.get_cashier_focus()

	if DialogueController.dialogue_finished.is_connected(_on_counter_dialogue_finished):
		DialogueController.dialogue_finished.disconnect(_on_counter_dialogue_finished)
	DialogueController.dialogue_finished.connect(_on_counter_dialogue_finished, CONNECT_ONE_SHOT)
	DialogueController.start_dialogue(DIALOGUE, "start", focus, use_camera_focus)


static func _find_place_setup() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("churro_counter_place")


static func _on_counter_dialogue_finished() -> void:
	GameManager.set_flag("churro_placed_on_counter", true)
	GameManager.set_flag("ready_for_cashier_jumpscare", true)
