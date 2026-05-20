extends CharacterBody3D

const dialogue_resource = preload("res://dialogues/my_dialogue.dialogue")
var dialogue_title: String = "start"
var trigger_once: bool = false

var player_near: bool = false
var already_talked: bool = false

@export var dialogue_stand_min_distance: float = 1.4
@export var dialogue_stand_max_distance: float = 2.6
@export var dialogue_stand_lateral_tolerance: float = 0.28
@export var dialogue_stand_distance_tolerance: float = 0.25

@onready var interaction_area: Area3D = $InteractionArea
@onready var dialogue_focus_point: Marker3D = $DialogueFocusPoint

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	add_to_group("interactable")
	
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

func can_interact() -> bool:
	if GameManager.dialogue_active:
		return false
	
	if not player_near:
		return false
	
	if trigger_once and already_talked:
		return false
	
	if dialogue_resource == null:
		return false
	
	return true

func interact() -> void:
	if not can_interact():
		return
	
	if GameManager.dialogue_active:
		return
	
	if trigger_once and already_talked:
		return
	
	already_talked = true
	DialogueController.start_dialogue(dialogue_resource, dialogue_title, dialogue_focus_point)

func get_interaction_prompt() -> String:
	return "Presiona [E] para hablar"


func requires_dialogue_focus_aim() -> bool:
	return true


func get_dialogue_focus_point() -> Node3D:
	return dialogue_focus_point


func get_dialogue_stand_position() -> Vector3:
	var player := GameManager.player as Node3D
	if player == null:
		return global_position

	var player_pos := player.global_position
	var offset := player_pos - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return player_pos

	var toward_player := offset.normalized()

	# Siempre quedarse del lado del jugador, nunca detrás del payaso.
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = toward_player
	else:
		forward = forward.normalized()
		if forward.dot(toward_player) < 0.0:
			forward = -forward

	var along := offset.dot(forward)
	if along < 0.0:
		along = offset.length()

	var lateral := offset - forward * along
	var lateral_len := Vector2(lateral.x, lateral.z).length()

	var target_along := along
	if along < dialogue_stand_min_distance:
		target_along = dialogue_stand_min_distance
	elif along > dialogue_stand_max_distance:
		target_along = dialogue_stand_max_distance

	# Ya centrado y a distancia prudencial: no mover.
	if lateral_len <= dialogue_stand_lateral_tolerance:
		if along >= dialogue_stand_min_distance and along <= dialogue_stand_max_distance:
			return player_pos
		if absf(along - target_along) <= dialogue_stand_distance_tolerance:
			return player_pos

	return Vector3(
		global_position.x + forward.x * target_along,
		player_pos.y,
		global_position.z + forward.z * target_along,
	)


func get_dialogue_focus_radius() -> float:
	var shape_node := dialogue_focus_point.get_node_or_null("FocusHitbox/CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is SphereShape3D:
		return (shape_node.shape as SphereShape3D).radius
	return 0.85


func is_player_aiming_at_dialogue_focus(camera: Camera3D, max_distance: float = 2.5) -> bool:
	if camera == null or dialogue_focus_point == null:
		return false
	var origin := camera.global_position
	var direction := (-camera.global_basis.z).normalized()
	var center := dialogue_focus_point.global_position
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

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true

func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false

func _on_dialogue_finished() -> void:
	GameManager.set_dialogue_active(false)
