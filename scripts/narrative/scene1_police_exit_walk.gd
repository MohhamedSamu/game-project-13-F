extends Node
## Tras el diálogo de Juan: recorre markers y reproduce [code]walking[/code] solo al desplazarse.

@export var jumpscare_setup_path: NodePath = ^"../FlashlightJumpscareSetup"
@export var police_npc_path: NodePath = ^"../PoliceNpc"
@export var waypoint_parent_path: NodePath = ^"../JuanExitPath"
@export_range(0.4, 3.5, 0.05) var walk_speed: float = 1.25
@export_range(0.05, 1.0, 0.05) var arrival_distance: float = 0.25
@export_range(0.5, 2.0, 0.05) var walk_animation_speed_scale: float = 1.0
@export_range(0.6, 2.0, 0.05) var path_clearance_radius: float = 0.85
@export_range(0.8, 2.5, 0.05) var player_standoff_distance: float = 1.35
@export var snap_to_floor: bool = true
@export var floor_ray_height: float = 3.0
@export var floor_ray_depth: float = 12.0
@export var hide_on_complete: bool = false
@export var remove_on_complete: bool = true
@export var clear_player_camera_focus: bool = true
@export var next_scene_id: String = "explore_gas_station"
@export var departure_flag: String = "level2_juan_departed"

const WALK_ANIM := &"walking"
const MIXAMO_YAW_CORRECTION := PI

var _walking: bool = false
var _walk_anim_started: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_connect_jumpscare")
	call_deferred("_sync_blocker_walls")


func _sync_blocker_walls() -> void:
	Scene1FlashlightBlocker.sync_from_flags()


func _connect_jumpscare() -> void:
	var setup := get_node_or_null(jumpscare_setup_path) as SoftJumpscareSetup
	if setup == null:
		push_warning("Scene1PoliceExitWalk: no se encontró FlashlightJumpscareSetup.")
		return
	if not setup.jumpscare_dialogue_finished.is_connected(_on_jumpscare_dialogue_finished):
		setup.jumpscare_dialogue_finished.connect(_on_jumpscare_dialogue_finished)


func _on_jumpscare_dialogue_finished() -> void:
	Scene1FlashlightBlocker.clear_after_dialogue()
	MusicDirector.play_ambience()
	await _run_exit_walk()


func _run_exit_walk() -> void:
	var police := get_node_or_null(police_npc_path) as Node3D
	if police == null or not police.is_inside_tree():
		return

	var waypoints := _collect_waypoints()
	if waypoints.is_empty():
		push_warning("Scene1PoliceExitWalk: añade Marker3D hijos en JuanExitPath.")
		return

	_advance_to_next_narrative_scene()
	_unlock_player_and_clear_camera()

	await get_tree().process_frame
	_walk_anim_started = false
	_stop_dialogue_pose(police)
	await _nudge_player_off_exit_path(police, waypoints[0].global_position)
	_walking = true

	for marker in waypoints:
		if not is_instance_valid(police) or not police.is_inside_tree():
			break
		await _walk_to_marker(police, marker.global_position)

	_walking = false
	_despawn_police(police)


func _advance_to_next_narrative_scene() -> void:
	if not departure_flag.is_empty():
		GameManager.set_flag(departure_flag, true)
	if not next_scene_id.is_empty():
		GameManager.set_level_scene(next_scene_id)


func _unlock_player_and_clear_camera() -> void:
	GameManager.unlock_player()
	if not clear_player_camera_focus:
		return
	var player := GameManager.get_player()
	if player != null and player.has_method("clear_camera_focus"):
		player.clear_camera_focus()


func _despawn_police(police: Node3D) -> void:
	if not is_instance_valid(police):
		return
	if remove_on_complete:
		police.process_mode = Node.PROCESS_MODE_DISABLED
		police.visible = false
		police.queue_free()
	elif hide_on_complete:
		police.visible = false


func _collect_waypoints() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	var parent := get_node_or_null(waypoint_parent_path)
	if parent == null:
		return result
	for child in parent.get_children():
		if child is Marker3D:
			result.append(child as Marker3D)
	return result


func _stop_dialogue_pose(police: Node3D) -> void:
	var animation_player := _get_animation_player(police)
	if animation_player == null:
		return
	animation_player.speed_scale = 1.0
	if animation_player.current_animation in ["breathing_idle", "talking", "idle"]:
		animation_player.stop()


func _nudge_player_off_exit_path(npc: Node3D, first_target: Vector3) -> void:
	var player := GameManager.get_player() as Node3D
	if player == null or not player.has_method("reposition_for_dialogue"):
		return
	if not _player_blocks_exit_path(npc, first_target, player):
		return
	var stand_pos := _get_path_clearance_position(npc, first_target, player)
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	await player.reposition_for_dialogue(stand_pos)
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(true)


func _player_blocks_exit_path(npc: Node3D, target: Vector3, player: Node3D) -> bool:
	var npc_pos := npc.global_position
	var path := target - npc_pos
	path.y = 0.0
	var path_len := path.length()
	if path_len < 0.05:
		return false

	var forward := path / path_len
	var to_player := player.global_position - npc_pos
	to_player.y = 0.0
	var along := to_player.dot(forward)
	if along < -0.2 or along > path_len + 0.3:
		return false

	var lateral := to_player - forward * along
	return Vector2(lateral.x, lateral.z).length() < path_clearance_radius


func _get_path_clearance_position(npc: Node3D, target: Vector3, player: Node3D) -> Vector3:
	var npc_pos := npc.global_position
	var path := target - npc_pos
	path.y = 0.0
	var forward := path.normalized()

	var player_pos := player.global_position
	var to_player := player_pos - npc_pos
	to_player.y = 0.0
	var along := to_player.dot(forward)
	var lateral := to_player - forward * along
	var lateral_len := Vector2(lateral.x, lateral.z).length()

	var side := Vector3(-forward.z, 0.0, forward.x)
	if lateral_len > 0.05 and lateral.dot(side) < 0.0:
		side = -side

	var push_distance := path_clearance_radius - lateral_len + player_standoff_distance
	return Vector3(
		player_pos.x + side.x * push_distance,
		player_pos.y,
		player_pos.z + side.z * push_distance,
	)


func _play_walking(police: Node3D) -> void:
	var animation_player := _get_animation_player(police)
	if animation_player == null:
		return
	if police.has_method("play_animation"):
		police.play_animation(String(WALK_ANIM))
	else:
		animation_player.play(String(WALK_ANIM))
	animation_player.speed_scale = walk_animation_speed_scale


func _start_walk_animations_on_move(police: Node3D) -> void:
	if _walk_anim_started:
		return
	_walk_anim_started = true
	_play_walking(police)


func _walk_to_marker(police: Node3D, target: Vector3) -> void:
	var grounded_target := _project_to_floor(target, police)
	while is_instance_valid(police) and police.is_inside_tree():
		var delta := get_tree().root.get_physics_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0
		await get_tree().physics_frame
		var offset := grounded_target - police.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist <= arrival_distance:
			police.global_position = _project_to_floor(
				Vector3(grounded_target.x, police.global_position.y, grounded_target.z),
				police
			)
			break
		_start_walk_animations_on_move(police)
		var step := minf(dist, walk_speed * delta)
		var direction := offset / dist
		var next_pos := police.global_position + direction * step
		police.global_position = _project_to_floor(next_pos, police)
		_face_horizontal(police, direction)


func _face_horizontal(police: Node3D, flat_direction: Vector3) -> void:
	if flat_direction.length_squared() < 0.0001:
		return
	var look_basis := Basis.looking_at(flat_direction.normalized(), Vector3.UP)
	look_basis = look_basis.rotated(Vector3.UP, MIXAMO_YAW_CORRECTION)
	police.global_rotation = look_basis.get_euler()


func _project_to_floor(world_pos: Vector3, context: Node3D) -> Vector3:
	if not snap_to_floor or context == null or not context.is_inside_tree():
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


func _get_animation_player(police: Node3D) -> AnimationPlayer:
	if police.has_method("get_animation_player"):
		return police.call("get_animation_player") as AnimationPlayer
	return police.find_child("AnimationPlayer", true, false) as AnimationPlayer
