extends Node
## Tras el diálogo de Juan: espera [code]start_walking[/code], luego [code]walking[/code] y recorre markers.

@export var jumpscare_setup_path: NodePath = ^"../FlashlightJumpscareSetup"
@export var police_npc_path: NodePath = ^"../PoliceNpc"
@export var waypoint_parent_path: NodePath = ^"../JuanExitPath"
@export_range(0.4, 3.5, 0.05) var walk_speed: float = 1.25
@export_range(0.05, 1.0, 0.05) var arrival_distance: float = 0.25
@export_range(0.5, 2.0, 0.05) var walk_animation_speed_scale: float = 1.0
@export var snap_to_floor: bool = true
@export var floor_ray_height: float = 3.0
@export var floor_ray_depth: float = 12.0
@export var hide_on_complete: bool = true
@export var clear_player_camera_focus: bool = true

const START_WALK_ANIM := &"start_walking"
const WALK_ANIM := &"walking"
const MIXAMO_YAW_CORRECTION := PI

var _walking: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_connect_jumpscare")


func _connect_jumpscare() -> void:
	var setup := get_node_or_null(jumpscare_setup_path) as SoftJumpscareSetup
	if setup == null:
		push_warning("Scene1PoliceExitWalk: no se encontró FlashlightJumpscareSetup.")
		return
	if not setup.jumpscare_dialogue_finished.is_connected(_on_jumpscare_dialogue_finished):
		setup.jumpscare_dialogue_finished.connect(_on_jumpscare_dialogue_finished)


func _on_jumpscare_dialogue_finished() -> void:
	await _run_exit_walk()


func _run_exit_walk() -> void:
	var police := get_node_or_null(police_npc_path) as Node3D
	if police == null or not police.is_inside_tree():
		return

	var waypoints := _collect_waypoints()
	if waypoints.is_empty():
		push_warning("Scene1PoliceExitWalk: añade Marker3D hijos en JuanExitPath.")
		return

	if clear_player_camera_focus:
		var player := GameManager.get_player()
		if player != null and player.has_method("clear_camera_focus"):
			player.clear_camera_focus()

	await get_tree().process_frame
	await _await_start_walking(police)
	_play_walking(police)
	_walking = true

	for marker in waypoints:
		if not is_instance_valid(police) or not police.is_inside_tree():
			break
		await _walk_to_marker(police, marker.global_position)

	_walking = false
	if hide_on_complete and is_instance_valid(police):
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


func _await_start_walking(police: Node3D) -> void:
	var animation_player := _get_animation_player(police)
	if animation_player == null:
		return
	if animation_player.current_animation == String(START_WALK_ANIM):
		await _await_animation(police, START_WALK_ANIM)
		return
	if animation_player.has_animation(String(START_WALK_ANIM)):
		if police.has_method("play_animation"):
			police.play_animation(String(START_WALK_ANIM))
		else:
			animation_player.play(String(START_WALK_ANIM))
		await _await_animation(police, START_WALK_ANIM)


func _play_walking(police: Node3D) -> void:
	var animation_player := _get_animation_player(police)
	if animation_player == null:
		return
	if police.has_method("play_animation"):
		police.play_animation(String(WALK_ANIM))
	else:
		animation_player.play(String(WALK_ANIM))
	animation_player.speed_scale = walk_animation_speed_scale


func _walk_to_marker(police: Node3D, target: Vector3) -> void:
	var grounded_target := _project_to_floor(target, police)
	while is_instance_valid(police) and police.is_inside_tree():
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
		var step := minf(dist, walk_speed * get_physics_process_delta_time())
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


func _await_animation(police: Node3D, anim_name: StringName) -> void:
	var animation_player := _get_animation_player(police)
	if animation_player == null:
		return
	if animation_player.current_animation != String(anim_name):
		return
	await animation_player.animation_finished
