extends Node

var dialogue_active: bool = false
var has_met_clown: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_dialogue_active(value: bool) -> void:
	dialogue_active = value
