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
@export_range(3.0, 16.0, 0.1) var chase_speed: float = 9.4
## Radio de agarre (horizontal). El monstruo no llega a montarse encima del jugador.
@export_range(0.8, 3.0, 0.05) var catch_distance: float = 1.5
@export_range(0.8, 1.6, 0.05) var chase_animation_speed_scale: float = 1.12
@export var snap_to_floor: bool = true
@export var floor_ray_height: float = 3.0
@export var floor_ray_depth: float = 12.0

var _running: bool = false
var _chasing: bool = false
var _active_setup: Node
var _player_was_caught: bool = false


func reset_session_state() -> void:
	_running = false
	_chasing = false
	_active_setup = null
	_player_was_caught = false


func start_sequence(setup: Node, player: Node3D) -> void:
	if _running:
		return
	if setup == null or not setup.has_method("get_monster"):
		return

	var completion_flag := String(setup.get("completion_flag"))
	if not completion_flag.is_empty() and GameManager.get_flag(completion_flag):
		return

	var monster := setup.call("get_monster") as Node3D
	if monster == null:
		return

	_running = true
	_active_setup = setup
	_player_was_caught = false
	if not completion_flag.is_empty():
		GameManager.set_flag(completion_flag, true)

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

	_play_monster_animation(monster, standup_animation, animation_blend_time)
	_notify_standup_started(setup, monster, standup_animation)
	await _wait_animation_finished(monster, standup_animation)

	if monster.has_method("prepare_sequence_from"):
		monster.prepare_sequence_from(
			String(standup_animation),
			String(turn_animation),
			true,
			-1
		)

	await _play_and_wait(monster, turn_animation, animation_blend_time)
	await _turn_monster_toward_player(monster, player, turn_to_player_duration)
	if monster.has_method("prepare_sequence_from"):
		# Solo alinear XZ; el scream conserva el movimiento vertical (pies en suelo).
		monster.prepare_sequence_from(
			String(turn_animation),
			String(scream_animation),
			true
		)
	_begin_scream_moment(setup)
	await _play_and_wait(monster, scream_animation, animation_blend_time)

	_end_camera_zoom(player)
	_unlock_player(player)
	if setup.has_method("begin_chase_access"):
		setup.call("begin_chase_access")
	_begin_chase_music(setup)
	_begin_chase_footsteps(setup, monster)
	_set_monster_animation_speed(monster, chase_animation_speed_scale)
	_play_monster_animation(monster, chase_animation)
	await _chase_player(monster, player)
	_stop_chase_footsteps(setup)
	if _player_was_caught:
		await Scene6FinalDeathDirector.play_sequence(setup, player, monster)
		_running = false
		_active_setup = null
		return
	if setup.has_method("end_chase_access"):
		setup.call("end_chase_access")
	_running = false
	_active_setup = null


func _notify_standup_started(
	setup: Node,
	monster: Node3D,
	standup_animation: StringName
) -> void:
	if setup == null or not setup.has_method("get_presentation"):
		return
	var presentation := setup.call("get_presentation") as Scene6FinalPresentation
	if presentation != null:
		presentation.notify_standup_started(monster, standup_animation)


func _begin_scream_moment(setup: Node) -> void:
	if setup == null or not setup.has_method("get_presentation"):
		return
	var presentation := setup.call("get_presentation") as Scene6FinalPresentation
	if presentation != null:
		presentation.begin_scream_moment()


func _begin_chase_music(setup: Node) -> void:
	if setup == null or not setup.has_method("get_presentation"):
		return
	var presentation := setup.call("get_presentation") as Scene6FinalPresentation
	if presentation != null:
		presentation.begin_chase_music()


func _begin_chase_footsteps(setup: Node, monster: Node3D) -> void:
	if setup == null or not setup.has_method("get_presentation"):
		return
	var presentation := setup.call("get_presentation") as Scene6FinalPresentation
	if presentation != null:
		var interval_scale := 1.0 / maxf(chase_animation_speed_scale, 0.1)
		presentation.begin_chase_footsteps(monster, interval_scale)


func _stop_chase_footsteps(setup: Node) -> void:
	if setup == null or not setup.has_method("get_presentation"):
		return
	var presentation := setup.call("get_presentation") as Scene6FinalPresentation
	if presentation != null:
		presentation.stop_chase_footsteps()


func stop_chase() -> void:
	_chasing = false
	_running = false
	var setup := _active_setup
	if setup != null:
		_stop_chase_footsteps(setup)
		if setup.has_method("end_chase_access"):
			setup.call("end_chase_access")
	_active_setup = null


func _chase_player(monster: Node3D, player: Node3D) -> void:
	_chasing = true
	while _chasing and is_instance_valid(monster) and is_instance_valid(player):
		var delta := get_tree().root.get_physics_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		await get_tree().physics_frame

		var target := _get_chase_target_position(player)
		var offset := target - monster.global_position
		offset.y = 0.0
		var dist := offset.length()
		var step_budget := chase_speed * delta

		if _should_catch_player(dist, step_budget):
			_trigger_catch(monster, player)
			return

		if dist <= 0.0001:
			_trigger_catch(monster, player)
			return

		var direction := offset / dist
		var step := minf(dist, step_budget)
		if dist - step <= catch_distance:
			_trigger_catch(monster, player)
			return

		var next_pos := monster.global_position + direction * step
		if snap_to_floor:
			next_pos = _project_to_floor(next_pos, monster)
		else:
			next_pos.y = target.y
		monster.global_position = next_pos
		_face_horizontal(monster, direction)


func _should_catch_player(dist: float, step_budget: float) -> bool:
	return dist <= catch_distance or dist - step_budget <= catch_distance


func _trigger_catch(monster: Node3D, player: Node3D) -> void:
	_chasing = false
	_player_was_caught = true
	_begin_catch_attack(monster, player)
	player_caught.emit(player)


func _get_chase_target_position(player: Node3D) -> Vector3:
	if player == null or not player.is_inside_tree():
		return Vector3.ZERO
	if player.has_node("Head"):
		var head := player.get_node("Head") as Node3D
		if head != null and head.is_inside_tree():
			return head.global_position
	return player.global_position


func _begin_catch_attack(monster: Node3D, player: Node3D) -> void:
	if monster == null or player == null:
		return
	_lock_player(player)
	_set_monster_animation_speed(monster, 1.0)
	_face_toward_position(monster, player.global_position)


func _play_and_wait(monster: Node3D, anim_name: StringName, blend_time: float = 0.0) -> void:
	_play_monster_animation(monster, anim_name, blend_time)
	await _wait_animation_finished(monster, anim_name)


func _wait_animation_finished(monster: Node3D, anim_name: StringName) -> void:
	var animation_player := _get_animation_player(monster)
	if animation_player == null:
		return
	var anim_key := String(anim_name)
	if not animation_player.has_animation(anim_key):
		return
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


func _set_monster_animation_speed(monster: Node3D, speed_scale: float) -> void:
	var animation_player := _get_animation_player(monster)
	if animation_player == null:
		return
	animation_player.speed_scale = maxf(speed_scale, 0.1)


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
