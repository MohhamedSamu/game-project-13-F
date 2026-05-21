class_name DialogueFocusPoint
extends Marker3D
## Punto opcional de enfoque de cámara y posición recomendada del jugador durante diálogos.

@export_group("Dialogue Stand Position")
@export var use_stand_position: bool = true
@export var stand_min_distance: float = 1.4
@export var stand_max_distance: float = 2.6
@export var stand_lateral_tolerance: float = 0.28
@export var stand_distance_tolerance: float = 0.25


func get_dialogue_stand_position() -> Vector3:
	if not use_stand_position:
		var player := GameManager.player as Node3D
		if player != null:
			return player.global_position
		return global_position

	var player := GameManager.player as Node3D
	if player == null:
		return global_position

	var owner_node := get_parent() as Node3D
	if owner_node == null:
		owner_node = self

	var player_pos := player.global_position
	var origin_pos := owner_node.global_position

	var offset := player_pos - origin_pos
	offset.y = 0.0

	if offset.length_squared() < 0.01:
		return player_pos

	var toward_player := offset.normalized()

	var forward := -owner_node.global_transform.basis.z
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
	if along < stand_min_distance:
		target_along = stand_min_distance
	elif along > stand_max_distance:
		target_along = stand_max_distance

	if lateral_len <= stand_lateral_tolerance:
		if along >= stand_min_distance and along <= stand_max_distance:
			return player_pos
		if absf(along - target_along) <= stand_distance_tolerance:
			return player_pos

	return Vector3(
		origin_pos.x + forward.x * target_along,
		player_pos.y,
		origin_pos.z + forward.z * target_along,
	)
