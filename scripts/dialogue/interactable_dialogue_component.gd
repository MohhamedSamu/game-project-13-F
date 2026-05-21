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

@export_group("Flags")
@export var set_flag_on_finish: String = ""
@export var set_flag_on_finish_value: bool = true

var player_near: bool = false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if focus_target == null:
		focus_target = _find_default_focus_target()


func _find_default_focus_target() -> Node3D:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("DialogueFocusPoint") as Node3D


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
	if set_flag_on_finish != "":
		DialogueController.dialogue_finished.connect(
			_on_dialogue_finished_apply_flag,
			CONNECT_ONE_SHOT
		)
	DialogueController.start_dialogue(dialogue_resource, dialogue_title, focus_target)


func _on_dialogue_finished_apply_flag() -> void:
	if set_flag_on_finish != "":
		GameManager.set_flag(set_flag_on_finish, set_flag_on_finish_value)


func get_interaction_prompt() -> String:
	return prompt_text


func requires_dialogue_focus_aim() -> bool:
	return requires_focus_hitbox


func get_focus_hitbox_group() -> String:
	return focus_hitbox_group


func get_dialogue_focus_radius() -> float:
	if focus_target == null:
		return 0.85
	var shape_node := focus_target.get_node_or_null("FocusHitbox/CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is SphereShape3D:
		return (shape_node.shape as SphereShape3D).radius
	return 0.85


func is_player_aiming_at_dialogue_focus(camera: Camera3D, max_distance: float = 2.5) -> bool:
	if camera == null or focus_target == null:
		return false
	var origin := camera.global_position
	var direction := (-camera.global_basis.z).normalized()
	var center := focus_target.global_position
	return _ray_hits_sphere_forward(origin, direction, center, get_dialogue_focus_radius(), max_distance)


func _ray_hits_sphere_forward(origin: Vector3, direction: Vector3, center: Vector3, radius: float, max_distance: float) -> bool:
	var oc := origin - center
	var a := direction.dot(direction)
	var b := 2.0 * oc.dot(direction)
	var c := oc.dot(oc) - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return false
	var sqrt_d := sqrt(discriminant)
	var inv_2a := 1.0 / (2.0 * a)
	for t in [(-b - sqrt_d) * inv_2a, (-b + sqrt_d) * inv_2a]:
		if t > 0.0 and t <= max_distance:
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
