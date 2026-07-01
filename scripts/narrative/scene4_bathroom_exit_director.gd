extends Node
## Escena 4: mirada al baño vacío tras el encuentro con el NPC de la gasolinera.

const HORROR_NODE_NAME := &"BathroomSinkHorror"
const PEEK_MARKER_NAME := &"BathroomPeekTarget"
const JUMPSCARE_GROUP := &"scene4_bathroom_exit_jumpscare"

@export_range(0.5, 5.0, 0.1) var peek_hold_duration: float = 2.0


func clear_bathroom_presentation() -> void:
	for node in get_tree().get_nodes_in_group("bathroom_sink_horror"):
		if node.has_method("clear_horror_presentation"):
			node.call("clear_horror_presentation")
			return

	var horror := _find_horror_setup()
	if horror != null and horror.has_method("clear_horror_presentation"):
		horror.clear_horror_presentation()


func peek_into_empty_bathroom() -> void:
	var player := GameManager.get_player()
	var peek_position := _resolve_peek_position()

	if player != null and player.has_method("focus_camera_on_world_point"):
		player.focus_camera_on_world_point(peek_position)

	if peek_hold_duration > 0.0:
		await get_tree().create_timer(peek_hold_duration).timeout

	_restore_dialogue_focus(player)


func _find_horror_setup() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child(String(HORROR_NODE_NAME), true, false)


func _resolve_peek_position() -> Vector3:
	var horror := _find_horror_setup()
	if horror != null:
		var marker := horror.get_node_or_null(String(PEEK_MARKER_NAME)) as Node3D
		if marker != null and marker.is_inside_tree():
			return marker.global_position
		if horror.has_method("get_creature_peek_position"):
			return horror.call("get_creature_peek_position")

	if horror != null and horror.is_inside_tree():
		return horror.to_global(Vector3(-4.87, 1.313, 0.438))

	return Vector3.ZERO


func _restore_dialogue_focus(player: Node) -> void:
	if player == null:
		return

	var npc := _find_gas_station_npc()
	if npc == null:
		if player.has_method("clear_camera_focus"):
			player.clear_camera_focus()
		return

	var focus := npc.get_node_or_null("DialogueFocusPoint") as Node3D
	if player.has_method("focus_camera_on"):
		player.focus_camera_on(focus if focus != null else npc)


func _find_gas_station_npc() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("GasStationNPC", true, false) as Node3D
