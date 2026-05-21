extends CharacterBody3D
## NPC payaso: física y reposicionamiento para diálogos. La lógica de diálogo vive en los componentes hijos.

@export var dialogue_stand_min_distance: float = 1.4
@export var dialogue_stand_max_distance: float = 2.6
@export var dialogue_stand_lateral_tolerance: float = 0.28
@export var dialogue_stand_distance_tolerance: float = 0.25

const SPEED := 5.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


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
