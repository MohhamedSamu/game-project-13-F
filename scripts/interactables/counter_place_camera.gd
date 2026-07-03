class_name CounterPlaceCamera
extends RefCounted


static func resolve_focus_speed(place_setup: Node, use_camera_focus: bool) -> float:
	if not use_camera_focus:
		return -1.0
	if place_setup != null and place_setup.get("place_camera_focus_speed") != null:
		return float(place_setup.place_camera_focus_speed)
	return 1.35


static func refresh_counter_interact_areas() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("coca_counter_place"):
		if node.has_method("sync_interact_area"):
			node.sync_interact_area()
	for node in tree.get_nodes_in_group("churro_counter_place"):
		if node.has_method("sync_interact_area"):
			node.sync_interact_area()
