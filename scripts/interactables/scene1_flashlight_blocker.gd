class_name Scene1FlashlightBlocker
extends RefCounted
## Bloquea el paso frente a la linterna hasta terminar el diálogo de Juan (escena 1).

const WALL_GROUP := &"scene1_flashlight_blocker_wall"
const DONE_FLAG := &"scene1_flashlight_blocker_cleared"


static func set_enabled(value: bool) -> void:
	for wall in _find_walls():
		_set_wall_enabled(wall, value)


static func clear_after_dialogue() -> void:
	GameManager.set_flag(DONE_FLAG, true)
	set_enabled(false)


static func sync_from_flags() -> void:
	set_enabled(not GameManager.get_flag(DONE_FLAG))


static func _find_walls() -> Array[Node]:
	var walls: Array[Node] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return walls
	for node in tree.get_nodes_in_group(WALL_GROUP):
		if is_instance_valid(node):
			walls.append(node)
	return walls


static func _set_wall_enabled(wall: Node, enabled: bool) -> void:
	if wall.has_method("set_wall_enabled"):
		wall.call("set_wall_enabled", enabled)
	else:
		wall.set("wall_enabled", enabled)
