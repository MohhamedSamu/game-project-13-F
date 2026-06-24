extends Node

var dialogue_active: bool = false
var minigame_active: bool = false
var player: Node = null
var has_met_clown: bool = false
var flags: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func set_dialogue_active(value: bool) -> void:
	dialogue_active = value

func register_player(player_node: Node) -> void:
	if player != null and is_instance_valid(player) and player != player_node:
		if player.tree_exited.is_connected(_on_player_tree_exited):
			player.tree_exited.disconnect(_on_player_tree_exited)
	player = player_node
	if player != null and not player.tree_exited.is_connected(_on_player_tree_exited):
		player.tree_exited.connect(_on_player_tree_exited)
	Settings.apply_controls_to_player()
	Settings.apply_movement_to_player(player)


func get_player() -> Node:
	if player != null and not is_instance_valid(player):
		player = null
	return player


func _on_player_tree_exited() -> void:
	player = null


func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value


func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func _set_crosshair_dialogue_hidden(hidden: bool) -> void:
	var crosshair := get_tree().get_first_node_in_group("interaction_crosshair") as Control
	if crosshair and crosshair.has_method("set_dialogue_hidden"):
		crosshair.set_dialogue_hidden(hidden)


func lock_player() -> void:
	dialogue_active = true
	_set_crosshair_dialogue_hidden(true)

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func unlock_player() -> void:
	dialogue_active = false
	_set_crosshair_dialogue_hidden(false)

	if player and player.has_method("clear_camera_focus"):
		player.clear_camera_focus()

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)

	if player and player.has_method("capture_mouse"):
		player.capture_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func lock_player_minigame() -> void:
	minigame_active = true
	_set_crosshair_dialogue_hidden(true)

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	if player and player.has_method("release_mouse"):
		player.release_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func unlock_player_minigame() -> void:
	minigame_active = false
	_set_crosshair_dialogue_hidden(false)

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)

	if player and player.has_method("capture_mouse"):
		player.capture_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
