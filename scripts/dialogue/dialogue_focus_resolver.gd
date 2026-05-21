class_name DialogueFocusResolver
extends RefCounted
## Utilidad compartida para resolver DialogueFocusPoint desde componentes de diálogo.


static func resolve_focus_target(
	use_camera_focus: bool,
	focus_target: Node3D,
	auto_find: bool,
	node_name: String,
	from_node: Node
) -> Node3D:
	if not use_camera_focus:
		return null
	if focus_target != null:
		return focus_target
	if not auto_find or from_node == null:
		return null
	return find_dialogue_focus_point(from_node, node_name)


static func find_dialogue_focus_point(from_node: Node, node_name: String = "DialogueFocusPoint") -> Node3D:
	var parent := from_node.get_parent()
	if parent == null:
		return null

	if node_name != "":
		var named := parent.get_node_or_null(node_name) as Node3D
		if named != null:
			return named

	for child in parent.get_children():
		if child is DialogueFocusPoint:
			return child as Node3D

	return null
