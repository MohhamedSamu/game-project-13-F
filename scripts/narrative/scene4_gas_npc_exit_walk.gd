extends Node
## Tras el diálogo post-baño: el señor de la gasolinera regresa a revisar las bombas.

@export var jumpscare_path: NodePath
@export var gas_npc_path: NodePath
@export var return_point_path: NodePath
@export_range(0.4, 3.5, 0.05) var walk_speed: float = 1.1
@export_range(0.05, 1.0, 0.05) var arrival_distance: float = 0.28
@export_range(0.5, 2.0, 0.05) var walk_animation_speed_scale: float = 1.0
@export var snap_to_floor: bool = true
@export var floor_ray_height: float = 3.0
@export var floor_ray_depth: float = 12.0
@export var clear_player_camera_focus: bool = true
@export var completion_flag: String = "scene4_gas_npc_after_bath_done"
@export var completion_objective: String = "scene4_bathroom_incident_done"

const WALK_ANIM := &"walking"
const MIXAMO_YAW_CORRECTION := PI

var _exit_running: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_connect_jumpscare")


func _connect_jumpscare() -> void:
	var setup := get_node_or_null(jumpscare_path) as SoftJumpscareSetup
	if setup == null:
		push_warning("Scene4GasNpcExitWalk: no se encontró SoftJumpscareSetup.")
		return

	if setup.require_flag.is_empty():
		setup.require_flag = "bathroom_sink_horror_done"
	if setup.trigger_flag.is_empty():
		setup.trigger_flag = "scene4_gas_npc_after_bath_done"
	setup.refresh_armed_state()

	if not setup.jumpscare_starting.is_connected(_on_jumpscare_starting):
		setup.jumpscare_starting.connect(_on_jumpscare_starting)
	if not setup.jumpscare_dialogue_finished.is_connected(_on_jumpscare_dialogue_finished):
		setup.jumpscare_dialogue_finished.connect(_on_jumpscare_dialogue_finished)


func _on_jumpscare_starting() -> void:
	Scene4BathroomExitDirector.clear_bathroom_presentation()


func _on_jumpscare_dialogue_finished() -> void:
	if _exit_running:
		return
	_exit_running = true
	await _return_npc_to_pumps()
	_mark_scene_complete()
	_exit_running = false


func _mark_scene_complete() -> void:
	if not completion_flag.is_empty():
		GameManager.set_flag(completion_flag, true)
	if not completion_objective.is_empty():
		GameManager.complete_objective(completion_objective)


func _return_npc_to_pumps() -> void:
	var npc := get_node_or_null(gas_npc_path) as Node3D
	var return_point := get_node_or_null(return_point_path) as Marker3D
	if npc == null or return_point == null:
		return

	if clear_player_camera_focus:
		var player := GameManager.get_player()
		if player != null and player.has_method("clear_camera_focus"):
			player.clear_camera_focus()

	await get_tree().process_frame
	_play_walking(npc)
	await _walk_to_marker(npc, return_point.global_position)

	if npc is GasStationNPC:
		(npc as GasStationNPC).resume_inspect_at_pump(0)


func _play_walking(npc: Node3D) -> void:
	var animation_player := _get_animation_player(npc)
	if animation_player == null:
		return
	if npc.has_method("play_animation"):
		npc.play_animation(String(WALK_ANIM))
	else:
		animation_player.play(String(WALK_ANIM))
	animation_player.speed_scale = walk_animation_speed_scale


func _walk_to_marker(npc: Node3D, target: Vector3) -> void:
	var grounded_target := _project_to_floor(target, npc)
	while is_instance_valid(npc) and npc.is_inside_tree():
		await get_tree().physics_frame
		var offset := grounded_target - npc.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist <= arrival_distance:
			npc.global_position = _project_to_floor(
				Vector3(grounded_target.x, npc.global_position.y, grounded_target.z),
				npc
			)
			break
		var step := minf(dist, walk_speed * get_physics_process_delta_time())
		var direction := offset / dist
		var next_pos := npc.global_position + direction * step
		npc.global_position = _project_to_floor(next_pos, npc)
		_face_horizontal(npc, direction)


func _face_horizontal(npc: Node3D, flat_direction: Vector3) -> void:
	if flat_direction.length_squared() < 0.0001:
		return
	var look_basis := Basis.looking_at(flat_direction.normalized(), Vector3.UP)
	look_basis = look_basis.rotated(Vector3.UP, MIXAMO_YAW_CORRECTION)
	npc.global_rotation = look_basis.get_euler()


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


func _get_animation_player(npc: Node3D) -> AnimationPlayer:
	if npc.has_method("get_animation_player"):
		return npc.call("get_animation_player") as AnimationPlayer
	return npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
