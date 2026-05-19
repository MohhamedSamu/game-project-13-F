extends Node

var dialogue_active: bool = false
var player: Node = null
var has_met_clown: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_dialogue_active(value: bool) -> void:
	dialogue_active = value

func register_player(player_node: Node) -> void:
	player = player_node

func lock_player() -> void:
	dialogue_active = true

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

func unlock_player() -> void:
	dialogue_active = false

	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
