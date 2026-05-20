class_name InteractableDialogueComponent
extends Area3D
## Diálogo al presionar E dentro de esta área. Reutilizable en puertas, props o NPCs.

@export var dialogue_resource: DialogueResource
@export var dialogue_title: String = "locked"
@export var prompt_text: String = "Presiona [E] para interactuar"

@export var enabled: bool = true
@export var trigger_once: bool = false
@export var already_triggered: bool = false

@export var requires_focus_hitbox: bool = false
@export var focus_hitbox_group: String = "interactable_focus"
@export var focus_target: Node3D
@export var proximity_radius: float = 2.5

var player_near: bool = false


func _ready() -> void:
	add_to_group("interactable")
	# Capa 1: el raycast del jugador debe poder detectar esta área.
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if focus_target == null:
		focus_target = get_parent().get_node_or_null("DoorFocusPoint") as Node3D


func _is_player_in_range() -> bool:
	if player_near:
		return true
	var player := GameManager.player
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= proximity_radius


func can_interact() -> bool:
	if not enabled:
		return false
	if GameManager.dialogue_active:
		return false
	if not _is_player_in_range():
		return false
	if trigger_once and already_triggered:
		return false
	if dialogue_resource == null:
		return false
	return true


func interact() -> void:
	if not can_interact():
		return
	if trigger_once:
		already_triggered = true
	DialogueController.start_dialogue(dialogue_resource, dialogue_title, focus_target)


func get_interaction_prompt() -> String:
	return prompt_text


func requires_dialogue_focus_aim() -> bool:
	return requires_focus_hitbox


func get_focus_hitbox_group() -> String:
	return focus_hitbox_group


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
