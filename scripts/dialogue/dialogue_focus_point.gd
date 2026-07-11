class_name DialogueFocusPoint
extends Marker3D
## Punto opcional de enfoque de cámara y posición recomendada del jugador durante diálogos.

@export_group("Dialogue Stand Position")
@export var use_stand_position: bool = true
@export var stand_min_distance: float = 1.4
@export var stand_max_distance: float = 2.6
@export var stand_lateral_tolerance: float = 0.28
@export var stand_distance_tolerance: float = 0.25
## Desplazamiento ideal perpendicular a forward (+ = derecha del NPC).
@export var stand_lateral_offset: float = 0.0


func get_dialogue_stand_position() -> Vector3:
	var player := GameManager.player as Node3D
	if not use_stand_position:
		if player != null:
			return player.global_position
		return global_position

	if player == null:
		return global_position

	var owner_node := get_parent() as Node3D
	if owner_node == null:
		owner_node = self

	var player_pos := player.global_position
	var origin_pos := global_position
	origin_pos.y = player_pos.y

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

	var target_along := clampf(along, stand_min_distance, stand_max_distance)

	var ideal_pos := Vector3(
		origin_pos.x + forward.x * target_along,
		player_pos.y,
		origin_pos.z + forward.z * target_along,
	)

	if absf(stand_lateral_offset) > 0.001:
		var right := forward.cross(Vector3.UP)
		if right.length_squared() > 0.0001:
			ideal_pos += right.normalized() * stand_lateral_offset

	var horizontal_delta := Vector2(
		player_pos.x - ideal_pos.x,
		player_pos.z - ideal_pos.z
	).length()

	if horizontal_delta <= maxf(stand_lateral_tolerance, stand_distance_tolerance):
		return player_pos

	return ideal_pos
