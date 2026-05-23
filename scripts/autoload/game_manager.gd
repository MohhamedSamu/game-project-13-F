extends Node

var dialogue_active: bool = false
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
	player = player_node


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
