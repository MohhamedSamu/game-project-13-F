extends Node
## Escena 6: secuencia de animaciones del monstruo y persecución al jugador.

signal player_caught(player: Node3D)

const MIXAMO_YAW_CORRECTION := PI

@export_group("Cámara")
@export_range(0.5, 6.0, 0.1) var camera_focus_duration: float = 2.0
@export_range(25.0, 70.0, 1.0) var camera_zoom_fov: float = 35.0
@export_range(0.2, 3.0, 0.05) var camera_zoom_in_duration: float = 1.0
@export_range(0.2, 3.0, 0.05) var camera_zoom_out_duration: float = 0.85

@export_group("Animaciones")
@export_range(0.05, 1.0, 0.05) var animation_blend_time: float = 0.35
@export_range(0.2, 2.0, 0.05) var turn_to_player_duration: float = 0.75
@export var idle_biting_animation: StringName = &"zombie_biting_v2"
@export var standup_animation: StringName = &"zombie_biting_standing_up_v2"
@export var turn_animation: StringName = &"turn_left"
@export var scream_animation: StringName = &"zombie_scream"
@export var chase_animation: StringName = &"zombie_running"

@export_group("Persecución")
@export_range(3.0, 14.0, 0.1) var chase_speed: float = 7.5
@export_range(0.4, 3.0, 0.05) var catch_distance: float = 1.15
@export var snap_to_floor: bool = true
@export var floor_ray_height: float = 3.0
@export var floor_ray_depth: float = 12.0

var _running: bool = false
var _chasing: bool = false


func start_sequence(setup: Node, player: Node3D) -> void:
	if _running:
		return
	if setup == null or not setup.has_method("get_monster"):
		push_warning("Scene6FinalChaseDirector: falta Scene6FinalSceneSetup.")
		return

	var completion_flag := String(setup.get("completion_flag"))
	if not completion_flag.is_empty() and GameManager.get_flag(completion_flag):
		return

	var monster := setup.call("get_monster") as Node3D
	if monster == null:
		push_warning("Scene6FinalChaseDirector: no se encontró Monster04.")
		return

	_running = true
	if not completion_flag.is_empty():
		GameManager.set_flag(completion_flag, true)

	print("Scene6FinalChaseDirector: iniciando secuencia final.")

	_lock_player(player)
	_focus_player_camera(player, setup.call("get_camera_focus_position"))
	_begin_camera_zoom(player)

	if camera_focus_duration > 0.0:
		await get_tree().create_timer(camera_focus_duration).timeout

	if monster.has_method("prepare_sequence_from"):
		# Biting está en el suelo: no copiar la Y, solo alinear horizontal si hace falta.
		monster.prepare_sequence_from(
			String(idle_biting_animation),
			String(standup_animation),
			true
		)

	await _play_and_wait(monster, standup_animation, animation_blend_time)

	if monster.has_method("prepare_sequence_from"):
		monster.prepare_sequence_from(
			String(standup_animation),
			String(turn_animation),
			true,
			-1
		)
		monster.prepare_sequence_from(String(turn_animation), String(scream_animation))

	await _play_and_wait(monster, turn_animation, animation_blend_time)
	await _turn_monster_toward_player(monster, player, turn_to_player_duration)
	await _play_and_wait(monster, scream_animation, animation_blend_time)

	if setup.get("disable_invisible_wall_on_trigger"):
		if setup.has_method("disable_end_of_road_wall"):
			setup.call("disable_end_of_road_wall")

	_end_camera_zoom(player)
	_unlock_player(player)
	MusicDirector.enter_tension()
	_play_monster_animation(monster, chase_animation)
	await _chase_player(monster, player)
	_running = false


func stop_chase() -> void:
	_chasing = false
	_running = false


func _chase_player(monster: Node3D, player: Node3D) -> void:
	_chasing = true
	while _chasing and is_instance_valid(monster) and is_instance_valid(player):
		var delta := get_tree().root.get_physics_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		await get_tree().physics_frame

		var target := player.global_position
		var offset := target - monster.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist <= catch_distance:
			_chasing = false
			player_caught.emit(player)
			return

		var direction := offset / dist
		var step := minf(dist, chase_speed * delta)
		var next_pos := monster.global_position + direction * step
		if snap_to_floor:
			next_pos = _project_to_floor(next_pos, monster)
		else:
			next_pos.y = target.y
		monster.global_position = next_pos
		_face_horizontal(monster, direction)


func _play_and_wait(monster: Node3D, anim_name: StringName, blend_time: float = 0.0) -> void:
	var animation_player := _get_animation_player(monster)
	if animation_player == null:
		return
	var anim_key := String(anim_name)
	if not animation_player.has_animation(anim_key):
		push_warning("Scene6FinalChaseDirector: animación '%s' no encontrada." % anim_key)
		return
	_play_monster_animation(monster, anim_name, blend_time)
	if animation_player.current_animation != anim_key:
		return
	await animation_player.animation_finished


func _play_monster_animation(
	monster: Node3D,
	anim_name: StringName,
	blend_time: float = 0.0
) -> void:
	if monster.has_method("play_animation_blended"):
		monster.play_animation_blended(String(anim_name), blend_time)
		return
	if monster.has_method("play_animation"):
		monster.play_animation(String(anim_name))
		return
	var animation_player := _get_animation_player(monster)
	if animation_player != null and animation_player.has_animation(String(anim_name)):
		if blend_time > 0.0:
			animation_player.play(String(anim_name), blend_time)
		else:
			animation_player.play(String(anim_name))


func _turn_monster_toward_player(
	monster: Node3D,
	player: Node3D,
	duration: float
) -> void:
	if monster == null or player == null or not monster.is_inside_tree():
		return
	if duration <= 0.0:
		_face_toward_position(monster, player.global_position)
		return

	var start_yaw := monster.global_rotation.y
	var end_basis := Basis.looking_at(
		_horizontal_direction(monster.global_position, player.global_position),
		Vector3.UP
	)
	end_basis = end_basis.rotated(Vector3.UP, MIXAMO_YAW_CORRECTION)
	var end_yaw := end_basis.get_euler().y
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(monster) and monster.is_inside_tree():
		var delta := get_tree().root.get_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		await get_tree().process_frame
		var t := elapsed / duration
		t = t * t * (3.0 - 2.0 * t)
		monster.global_rotation.y = lerp_angle(start_yaw, end_yaw, t)
		elapsed += delta


func _face_toward_position(actor: Node3D, look_target: Vector3) -> void:
	_face_horizontal(actor, _horizontal_direction(actor.global_position, look_target))


func _horizontal_direction(from: Vector3, to: Vector3) -> Vector3:
	var direction := to - from
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.FORWARD
	return direction.normalized()


func _lock_player(player: Node3D) -> void:
	GameManager.lock_player()
	if player == null:
		return
	if player.has_method("stop_movement_immediately"):
		player.stop_movement_immediately()
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)


func _unlock_player(player: Node3D) -> void:
	GameManager.unlock_player()
	if player == null:
		return
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
	if player.has_method("clear_camera_focus"):
		player.clear_camera_focus()


func _focus_player_camera(player: Node3D, world_point: Vector3) -> void:
	if player == null:
		return
	if player.has_method("focus_camera_on_world_point"):
		player.focus_camera_on_world_point(world_point)


func _begin_camera_zoom(player: Node3D) -> void:
	if player == null:
		return
	if player.has_method("begin_cinematic_zoom"):
		player.begin_cinematic_zoom(camera_zoom_fov, camera_zoom_in_duration)


func _end_camera_zoom(player: Node3D) -> void:
	if player == null:
		return
	if player.has_method("end_cinematic_zoom"):
		player.end_cinematic_zoom(camera_zoom_out_duration)


func _get_animation_player(actor: Node3D) -> AnimationPlayer:
	if actor == null:
		return null
	return actor.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _face_horizontal(actor: Node3D, flat_direction: Vector3) -> void:
	if flat_direction.length_squared() < 0.0001:
		return
	var look_basis := Basis.looking_at(flat_direction.normalized(), Vector3.UP)
	look_basis = look_basis.rotated(Vector3.UP, MIXAMO_YAW_CORRECTION)
	actor.global_rotation = look_basis.get_euler()


func _project_to_floor(world_pos: Vector3, context: Node3D) -> Vector3:
	if context == null or not context.is_inside_tree():
		return world_pos
	var space := context.get_world_3d().direct_space_state
	if space == null:
		return world_pos
	var from := world_pos + Vector3.UP * floor_ray_height
	var to := world_pos + Vector3.DOWN * floor_ray_depth
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return world_pos
	return Vector3(world_pos.x, hit.position.y, world_pos.z)
