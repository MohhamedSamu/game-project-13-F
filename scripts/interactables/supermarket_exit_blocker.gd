class_name SupermarketExitBlocker
extends RefCounted
## Bloquea la salida del supermercado durante la escena de coca/churro/terror.

const WALL_GROUP := &"supermarket_exit_blocker_wall"
const DONE_FLAG := &"supermarket_ghost_reveal_done"


static func set_enabled(value: bool) -> void:
	for wall in _find_walls():
		_set_wall_enabled(wall, value)


static func sync_from_flags() -> void:
	set_enabled(_should_block_exit())


static func _should_block_exit() -> bool:
	if GameManager.get_flag(DONE_FLAG):
		return false
	return (
		GameManager.get_flag("has_coca_in_left_hand")
		or GameManager.get_flag("coca_placed_on_counter")
		or GameManager.get_flag("needs_churro")
		or GameManager.get_flag("has_churro_in_left_hand")
		or GameManager.get_flag("churro_taken")
		or GameManager.get_flag("churro_placed_on_counter")
		or GameManager.get_flag("ready_for_cashier_jumpscare")
		or GameManager.get_flag("supermarket_ghost_reveal_started")
	)


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
