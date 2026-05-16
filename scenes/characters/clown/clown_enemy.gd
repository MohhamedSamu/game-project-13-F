extends CharacterBody3D

const dialogue_resource = preload("res://dialogues/my_dialogue.dialogue")
var dialogue_title: String = "start"
var trigger_once: bool = false

var player_near: bool = false
var already_talked: bool = false

@onready var interaction_area: Area3D = $InteractionArea

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	return

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
	
	if player_near and Input.is_action_just_pressed("interact"):
		request_dialogue()

func request_dialogue() -> void:
	if GameManager.dialogue_active:
		return
	
	if trigger_once and already_talked:
		return
	
	already_talked = true
	DialogueController.start_dialogue(dialogue_resource, dialogue_title)

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true

func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false

func _on_dialogue_finished() -> void:
	GameManager.set_dialogue_active(false)
