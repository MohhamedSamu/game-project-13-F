extends Node
## Escena 4: mirada al baño vacío y salida del NPC al cubículo.

const HORROR_NODE_NAME := &"BathroomSinkHorror"
const GAS_STATION_UNIQUE_NAME := &"Gas_station"
const JUMPSCARE_GROUP := &"scene4_bathroom_exit_jumpscare"
const MIXAMO_YAW_CORRECTION := PI

@export_range(0.5, 5.0, 0.1) var peek_hold_duration: float = 2.0
@export_range(0.4, 3.5, 0.05) var walk_speed: float = 1.1
@export_range(0.05, 1.0, 0.05) var arrival_distance: float = 0.28
@export_range(0.5, 2.0, 0.05) var walk_animation_speed_scale: float = 1.0
@export_range(0.2, 3.0, 0.05) var turn_duration: float = 0.8
@export_range(0.2, 3.0, 0.05) var door_open_wait: float = 1.0
@export_range(0.0, 3.0, 0.05) var door_close_advance_seconds: float = 1.5
@export var idle_animation: StringName = &"idle"
@export var sitting_animation: StringName = &"sitting"
@export_range(-1.0, 1.5, 0.01) var sitting_height_offset: float = 0.8
@export var snap_to_floor: bool = true
@export var floor_ray_height: float = 3.0
@export var floor_ray_depth: float = 12.0
@export var completion_flag: String = "scene4_gas_npc_after_bath_done"
@export var completion_objective: String = "scene4_bathroom_incident_done"

const WALK_ANIM := &"walking"
const WALK_IN_PLACE_ANIM := &"walking_in_place"

var _toilet_exit_running: bool = false


func clear_bathroom_presentation() -> void:
	for node in get_tree().get_nodes_in_group("bathroom_sink_horror"):
		if node.has_method("clear_horror_presentation"):
			node.call("clear_horror_presentation")
			return

	var horror := _find_horror_setup()
	if horror != null and horror.has_method("clear_horror_presentation"):
		horror.clear_horror_presentation()


func peek_into_empty_bathroom() -> void:
	var player := GameManager.get_player()
	var peek_position := _resolve_peek_position()

	if player != null and player.has_method("focus_camera_on_world_point"):
		player.focus_camera_on_world_point(peek_position)

	if peek_hold_duration > 0.0:
		await get_tree().create_timer(peek_hold_duration).timeout

	_restore_dialogue_focus(player)


## Llamado desde el diálogo (`do`) para iniciar la salida al cubículo.
func trigger_toilet_cubicle_exit() -> void:
	enter_toilet_cubicle()


func enter_toilet_cubicle() -> void:
	if _toilet_exit_running:
		return

	var npc := _find_gas_station_npc()
	if npc == null:
		push_warning("Scene4BathroomExitDirector: no se encontró GasStationNPC.")
		return
	if not npc.visible and not completion_flag.is_empty() and GameManager.get_flag(completion_flag):
		return

	_toilet_exit_running = true
	_unlock_player_control()

	var setup := _get_setup()
	if setup == null:
		push_warning("Scene4BathroomExitDirector: falta Scene4BathroomExitSetup.")
		_toilet_exit_running = false
		return

	var door_outside := setup.door_outside_marker
	var door_inside := setup.door_inside_marker
	var dialogue_focus := setup.dialogue_focus_marker
	var door_setup := setup.cubicle_door_setup
	if door_outside == null:
		push_warning("Scene4BathroomExitDirector: asigna door_outside_marker.")
		_toilet_exit_running = false
		return
	if door_inside == null:
		push_warning("Scene4BathroomExitDirector: asigna door_inside_marker.")
		_toilet_exit_running = false
		return

	await get_tree().process_frame
	_lock_npc_for_scripted_exit(npc)
	_stop_talking(npc)

	# 1. Caminar hasta fuera de la puerta del cubículo.
	_play_walking(npc)
	await _walk_npc_to_marker(npc, door_outside)
	_halt_walking(npc)

	# 2. Abrir puerta 005 y esperar 1 s mientras se abre.
	_play_idle(npc)
	if door_setup != null:
		door_setup.open_door()
	if door_open_wait > 0.0:
		await get_tree().create_timer(door_open_wait).timeout

	# 3. Entrar y caminar hasta el marker interior.
	_play_walking(npc)
	await _walk_npc_to_marker(npc, door_inside)
	_halt_walking(npc)

	# 4. Darse la vuelta hacia el punto de diálogo (donde quedó el jugador).
	var look_target := (
		dialogue_focus.global_position
		if dialogue_focus != null
		else door_outside.global_position
	)
	await _turn_npc_over_time(npc, look_target, turn_duration)

	# 5. Sentarse.
	if door_setup != null:
		_queue_close_door_before_animation_ends(
			door_setup,
			npc,
			sitting_animation,
			door_close_advance_seconds
		)
	_play_sitting(npc)
	await _await_animation(npc, sitting_animation)
	_snap_npc_to_seat(npc, door_inside)
	_hold_sitting_pose(npc)

	# 6. Cerrar puerta y desaparecer.
	if door_setup != null:
		await door_setup.wait_for_animation_if_running()

	_finalize_npc_exit(npc)
	_mark_scene_complete()
	_toilet_exit_running = false


func _mark_scene_complete() -> void:
	if not completion_flag.is_empty():
		GameManager.set_flag(completion_flag, true)
	if not completion_objective.is_empty():
		GameManager.complete_objective(completion_objective)


func _lock_npc_for_scripted_exit(npc: Node3D) -> void:
	if npc is GasStationNPC:
		var gas_npc := npc as GasStationNPC
		gas_npc.visible = true
		gas_npc.prepare_for_bathroom_exit_jumpscare()
	else:
		_disable_npc_behavior(npc)


func _finalize_npc_exit(npc: Node3D) -> void:
	if npc is GasStationNPC:
		(npc as GasStationNPC).finish_scripted_exit()
	elif is_instance_valid(npc):
		_set_npc_collision_enabled(npc, false)
		npc.visible = false


func _set_npc_collision_enabled(npc: Node3D, enabled: bool) -> void:
	var collision := npc.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = not enabled


func _disable_npc_behavior(npc: Node3D) -> void:
	if npc is GasStationNPC:
		(npc as GasStationNPC).pause_for_jumpscare()
	elif npc is CharacterBody3D:
		var body := npc as CharacterBody3D
		body.velocity = Vector3.ZERO
		body.set_physics_process(false)


func _stop_talking(npc: Node3D) -> void:
	var animation_player := _get_animation_player(npc)
	if animation_player == null:
		return
	animation_player.speed_scale = 1.0
	if animation_player.current_animation == "talking":
		animation_player.stop()


func _play_walking(npc: Node3D) -> void:
	var animation_player := _get_animation_player(npc)
	if animation_player == null:
		return
	var walk_anim := String(WALK_IN_PLACE_ANIM)
	if not animation_player.has_animation(walk_anim):
		walk_anim = String(WALK_ANIM)
	if npc.has_method("play_animation"):
		npc.play_animation(walk_anim)
	else:
		animation_player.play(walk_anim)
	animation_player.speed_scale = walk_animation_speed_scale


func _halt_walking(npc: Node3D) -> void:
	_play_idle(npc)


func _play_idle(npc: Node3D) -> void:
	var animation_player := _get_animation_player(npc)
	if animation_player == null:
		return
	animation_player.speed_scale = 1.0
	var candidates: Array[String] = [
		String(idle_animation),
		"idle",
		"male_standing_pose",
		"old_man_idle",
	]
	for anim_name in candidates:
		if anim_name.is_empty():
			continue
		if not animation_player.has_animation(anim_name):
			continue
		if npc.has_method("play_animation"):
			npc.play_animation(anim_name)
		else:
			animation_player.play(anim_name)
		return
	animation_player.stop()


func _play_sitting(npc: Node3D) -> void:
	var animation_player := _get_animation_player(npc)
	if animation_player == null:
		return
	var anim_name := String(sitting_animation)
	if not animation_player.has_animation(anim_name):
		push_warning("Scene4BathroomExitDirector: animación '%s' no encontrada." % anim_name)
		return
	if npc.has_method("play_animation"):
		npc.play_animation(anim_name)
	else:
		animation_player.play(anim_name)


func _snap_npc_to_seat(npc: Node3D, seat_marker: Marker3D) -> void:
	if npc == null or seat_marker == null or not seat_marker.is_inside_tree():
		return
	var seated := seat_marker.global_position
	seated.y += sitting_height_offset
	npc.global_position = Vector3(npc.global_position.x, seated.y, npc.global_position.z)


func _hold_sitting_pose(npc: Node3D) -> void:
	var animation_player := _get_animation_player(npc)
	if animation_player == null:
		return
	var anim_name := String(sitting_animation)
	if not animation_player.has_animation(anim_name):
		return
	var anim := animation_player.get_animation(anim_name)
	if anim == null:
		return
	animation_player.play(anim_name)
	animation_player.seek(maxf(anim.length - 0.05, 0.0), true)
	animation_player.pause()


func _walk_npc_to_marker(npc: Node3D, marker: Marker3D) -> void:
	if marker == null:
		return
	await _walk_npc_to(npc, marker.global_position, true)


func _walk_npc_to(npc: Node3D, target: Vector3, use_marker_height: bool = false) -> void:
	var grounded_target := target
	if snap_to_floor and not use_marker_height:
		grounded_target = _project_to_floor(target, npc)
	while is_instance_valid(npc) and npc.is_inside_tree():
		var delta := get_tree().root.get_physics_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		await get_tree().physics_frame
		var offset := grounded_target - npc.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist <= arrival_distance:
			npc.global_position = Vector3(grounded_target.x, grounded_target.y, grounded_target.z)
			break
		var step := minf(dist, walk_speed * delta)
		var direction := offset / dist
		var next_pos := npc.global_position + direction * step
		if snap_to_floor and not use_marker_height:
			next_pos = _project_to_floor(next_pos, npc)
		else:
			next_pos.y = grounded_target.y
		npc.global_position = next_pos
		_face_horizontal(npc, direction)


func _turn_npc_over_time(npc: Node3D, look_target: Vector3, duration: float) -> void:
	_play_idle(npc)
	if duration <= 0.0:
		_face_toward_position(npc, look_target)
		return
	var start_yaw := npc.global_rotation.y
	var end_basis := Basis.looking_at(
		_horizontal_direction(npc.global_position, look_target),
		Vector3.UP
	)
	end_basis = end_basis.rotated(Vector3.UP, MIXAMO_YAW_CORRECTION)
	var end_yaw := end_basis.get_euler().y
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(npc) and npc.is_inside_tree():
		var delta := get_tree().root.get_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		await get_tree().process_frame
		var t := elapsed / duration
		npc.global_rotation.y = lerp_angle(start_yaw, end_yaw, t)
		elapsed += delta


func _face_toward_position(npc: Node3D, look_target: Vector3) -> void:
	_face_horizontal(npc, _horizontal_direction(npc.global_position, look_target))


func _horizontal_direction(from: Vector3, to: Vector3) -> Vector3:
	var direction := to - from
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3.FORWARD
	return direction.normalized()


func _await_animation(npc: Node3D, anim_name: StringName) -> void:
	var animation_player := _get_animation_player(npc)
	if animation_player == null:
		return
	if animation_player.current_animation != String(anim_name):
		return
	await animation_player.animation_finished


func _queue_close_door_before_animation_ends(
	door_setup: DoorInteractSetup,
	npc: Node3D,
	anim_name: StringName,
	advance_seconds: float
) -> void:
	if door_setup == null:
		return

	var animation_player := _get_animation_player(npc)
	if animation_player == null:
		door_setup.close_door()
		return

	var animation := animation_player.get_animation(String(anim_name))
	if animation == null:
		door_setup.close_door()
		return

	var delay := maxf(animation.length - advance_seconds, 0.0)
	if delay <= 0.0:
		door_setup.close_door()
		return

	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(door_setup.close_door, CONNECT_ONE_SHOT)


func _face_horizontal(npc: Node3D, flat_direction: Vector3) -> void:
	if flat_direction.length_squared() < 0.0001:
		return
	var look_basis := Basis.looking_at(flat_direction.normalized(), Vector3.UP)
	look_basis = look_basis.rotated(Vector3.UP, MIXAMO_YAW_CORRECTION)
	npc.global_rotation = look_basis.get_euler()


func _project_to_floor(world_pos: Vector3, context: Node3D) -> Vector3:
	if context == null or not context.is_inside_tree():
		return world_pos
	if not snap_to_floor:
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


func _get_animation_player(npc: Node3D) -> AnimationPlayer:
	if npc.has_method("get_animation_player"):
		return npc.call("get_animation_player") as AnimationPlayer
	return npc.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _find_horror_setup() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child(String(HORROR_NODE_NAME), true, false)


func _get_setup() -> Scene4BathroomExitSetup:
	for node in get_tree().get_nodes_in_group("scene4_bathroom_exit_setup"):
		return node as Scene4BathroomExitSetup
	return null


func _find_gas_station() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("%Gas_station") as Node3D


func _resolve_peek_position() -> Vector3:
	var horror := _find_horror_setup()
	if horror != null:
		var marker := horror.get_node_or_null("BathroomPeekTarget") as Node3D
		if marker != null and marker.is_inside_tree():
			return marker.global_position
		if horror.has_method("get_creature_peek_position"):
			return horror.call("get_creature_peek_position")

	if horror != null and horror.is_inside_tree():
		return horror.to_global(Vector3(-4.87, 1.313, 0.438))

	return Vector3.ZERO


func _restore_dialogue_focus(player: Node) -> void:
	if player == null:
		return

	var focus: Node3D = null
	var setup := _get_setup()
	if setup != null and setup.dialogue_focus_marker != null:
		focus = setup.dialogue_focus_marker

	var npc := _find_gas_station_npc()
	if focus == null and npc != null:
		focus = npc.get_node_or_null("DialogueFocusPoint") as Node3D

	if player.has_method("focus_camera_on"):
		player.focus_camera_on(focus if focus != null else npc)


func _find_gas_station_npc() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("GasStationNPC", true, false) as Node3D


func _unlock_player_control() -> void:
	GameManager.unlock_player()
	var player := GameManager.get_player()
	if player != null and player.has_method("clear_camera_focus"):
		player.clear_camera_focus()
