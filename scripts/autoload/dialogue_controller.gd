extends Node

var current_balloon: Node = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func start_dialogue(dialogue_resource: DialogueResource, title: String = "start") -> void:
	if GameManager.dialogue_active:
		return
	
	if dialogue_resource == null:
		push_warning("DialogueController: dialogue_resource is null.")
		return
	
	GameManager.lock_player()
	current_balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, title)
	
	if current_balloon:
		current_balloon.tree_exited.connect(_on_dialogue_finished)
	else:
		GameManager.unlock_player()

func _on_dialogue_finished() -> void:
	current_balloon = null
	GameManager.unlock_player()
