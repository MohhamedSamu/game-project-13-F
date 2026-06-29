@tool
class_name SoftJumpscareSetup
extends Node3D
## Susto no letal: trigger invisible, actor corre al jugador, grito aleatorio y diálogo.
## Señales: [signal jumpscare_triggered] al aparecer el actor; [signal jumpscare_dialogue_finished]
## al cerrar el diálogo; [signal jumpscare_rise_started] / [signal jumpscare_rise_finished] durante la salida;
## [signal jumpscare_completed] cuando termina todo el susto.

signal jumpscare_dialogue_finished
signal jumpscare_completed
signal jumpscare_triggered
signal jumpscare_rise_started
signal jumpscare_rise_finished

enum AllowedAudioTier {
	SOFT,
	MEDIUM,
}

enum ArrivalMode {
	## Punto frente al jugador según [member arrival_distance].
	PLAYER_RELATIVE,
	## Usa la posición global de [member ScareArrivalPoint].
	MARKER,
}

@export_group("Audio")
## Solo soft o medium. Hard queda reservado para jumpscares letales.
@export var audio_tier: AllowedAudioTier = AllowedAudioTier.SOFT

@export_group("Trigger")
@export var trigger_once: bool = true
## Si no está vacío, no se repite tras activarse (persistente en GameManager).
@export var trigger_flag: String = ""

@export_group("Carrera del susto")
## Velocidad de acercamiento (m/s). Si [member use_run_speed_for_duration] está activo, define la duración del charge.
@export_range(1.0, 16.0, 0.25) var scare_run_speed: float = 7.5
@export var use_run_speed_for_duration: bool = true
## Duración manual del charge si [member use_run_speed_for_duration] está desactivado.
@export_range(0.15, 4.0, 0.05) var scare_duration: float = 0.8
@export_range(0.15, 2.0, 0.05) var min_scare_duration: float = 0.35
@export_range(0.5, 5.0, 0.1) var max_scare_duration: float = 2.5
@export_range(0.5, 3.0, 0.05) var run_animation_speed_scale: float = 1.85
@export var arrival_mode: ArrivalMode = ArrivalMode.PLAYER_RELATIVE
@export_range(0.5, 4.0, 0.1) var arrival_distance: float = 1.6
@export var face_player_on_arrival: bool = true
## Ajuste fino extra (normalmente 0; Mixamo ya se corrige en código).
@export_range(-180.0, 180.0, 1.0) var actor_yaw_offset_deg: float = 0.0
@export_range(1.0, 2.5, 0.05) var actor_focus_height: float = 1.55
@export var snap_actor_to_floor: bool = true
@export var floor_ray_height: float = 3.0
@export var floor_ray_depth: float = 12.0

@export_group("Diálogo")
@export var dialogue_resource: DialogueResource
@export var dialogue_title: String = "start"
## Punto donde debe mirar la cámara del jugador (Marker3D en el nivel). Si está vacío, usa [member CameraFocusPoint].
@export var camera_focus_path: NodePath

@export_group("Actor")
## Raíz del personaje importado. Si está vacío, usa el placeholder [member ScareActor].
@export var scare_actor_path: NodePath
@export var hide_actor_until_trigger: bool = true
## AnimationPlayer del actor. Si está vacío, se busca el primero bajo el actor.
@export var animation_player_path: NodePath

@export_group("Animaciones")
@export var run_animation: String = ""
@export var dialogue_animation: String = ""
@export var after_dialogue_animation: String = ""

@export_group("Salida tras diálogo")
@export var exit_after_dialogue: bool = true
@export_range(1.0, 20.0, 0.25) var exit_rise_height: float = 5.0
@export_range(0.5, 12.0, 0.1) var exit_rise_duration: float = 3.5

@export_group("Editor")
@export var show_actor_preview: bool = true:
	set(value):
		show_actor_preview = value
		if is_inside_tree():
			_update_actor_preview_visibility()

var _triggered: bool = false
var _owns_active_dialogue: bool = false
var _scare_tween: Tween
var _exit_tween: Tween

var _trigger_zone: JumpscareTriggerZone
var _spawn_point: Node3D
var _arrival_point: Node3D
var _scare_actor: Node3D
var _camera_focus_point: Node3D
var _actor_preview: MeshInstance3D
var _scream_player: AudioStreamPlayer3D
var _actor_preview_material: StandardMaterial3D

const _ACTOR_PREVIEW_COLOR := Color(0.85, 0.2, 0.35, 0.55)
## Mixamo suele exportar el personaje mirando +Z; Godot usa -Z como frente.
const _MIXAMO_YAW_CORRECTION := PI


func _enter_tree() -> void:
	_cache_nodes()
	if Engine.is_editor_hint():
		call_deferred("_sync_editor_layout")


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_sync_editor_layout")
		return

	_load_trigger_state()
	_hide_editor_gizmos()
	call_deferred("_hide_actor_until_trigger")
	if _trigger_zone != null:
		_trigger_zone.player_entered.connect(_on_player_entered_trigger)


func _hide_editor_gizmos() -> void:
	var arrival_gizmo := get_node_or_null("ScareArrivalPoint/ArrivalGizmo") as Node3D
	if arrival_gizmo != null:
		arrival_gizmo.visible = false


func _notification(what: int) -> void:
	if Engine.is_editor_hint() and what == NOTIFICATION_TRANSFORM_CHANGED:
		call_deferred("_sync_editor_layout")


func _cache_nodes() -> void:
	_trigger_zone = get_node_or_null("TriggerZone") as JumpscareTriggerZone
	_spawn_point = get_node_or_null("ScareSpawnPoint") as Node3D
	_arrival_point = get_node_or_null("ScareArrivalPoint") as Node3D
	_scare_actor = get_node_or_null("ScareActor") as Node3D
	_camera_focus_point = get_node_or_null("CameraFocusPoint") as Node3D
	_actor_preview = get_node_or_null("ScareActor/EditorPreview") as MeshInstance3D
	_scream_player = get_node_or_null("Audio/ScreamPlayer") as AudioStreamPlayer3D


func _sync_editor_layout() -> void:
	if not is_inside_tree():
		return
	_cache_nodes()
	_snap_node_to_spawn(_scare_actor)
	_update_actor_preview_visibility()


func _snap_node_to_spawn(target: Node3D) -> void:
	if target == null or _spawn_point == null:
		return
	var spawn_xf: Transform3D
	if _spawn_point.is_inside_tree():
		spawn_xf = _spawn_point.global_transform
	elif target.get_parent() == _spawn_point.get_parent():
		spawn_xf = _spawn_point.transform
	else:
		return
	spawn_xf.origin = _project_to_floor(spawn_xf.origin)
	if target.is_inside_tree() and _spawn_point.is_inside_tree():
		target.global_transform = spawn_xf
	elif target.get_parent() == _spawn_point.get_parent():
		target.transform = spawn_xf


func _update_actor_preview_visibility() -> void:
	if _actor_preview == null:
		return
	if _actor_preview_material == null:
		_actor_preview_material = StandardMaterial3D.new()
		_actor_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_actor_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_actor_preview_material.albedo_color = _ACTOR_PREVIEW_COLOR
		_actor_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_actor_preview.material_override = _actor_preview_material
	else:
		_actor_preview_material.albedo_color = _ACTOR_PREVIEW_COLOR
	_actor_preview.visible = Engine.is_editor_hint() and show_actor_preview


func _load_trigger_state() -> void:
	if not trigger_flag.is_empty() and GameManager.get_flag(trigger_flag):
		_triggered = true


func _hide_actor_until_trigger() -> void:
	if not is_inside_tree():
		return
	var actor := _resolve_scare_actor()
	if actor == null:
		return
	_snap_node_to_spawn(actor)
	_set_actor_visible(false)
	if _actor_preview != null:
		_actor_preview.visible = false


func _on_player_entered_trigger(player: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if _triggered and trigger_once:
		return
	if GameManager.dialogue_active or GameManager.minigame_active:
		return
	_run_soft_jumpscare(player)


func _run_soft_jumpscare(player: Node3D) -> void:
	_run_soft_jumpscare_async(player)


func _run_soft_jumpscare_async(player: Node3D) -> void:
	var actor := _resolve_scare_actor()
	if actor == null:
		push_warning("SoftJumpscareSetup: falta ScareActor o scare_actor_path.")
		return
	if dialogue_resource == null:
		push_warning("SoftJumpscareSetup: asigna dialogue_resource.")
		return

	if player != null and player.has_method("stop_movement_immediately"):
		player.stop_movement_immediately()
	if player != null and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	_triggered = true
	if not trigger_flag.is_empty():
		GameManager.set_flag(trigger_flag, true)

	var arrival := _compute_arrival_position(player)
	_snap_node_to_spawn(actor)
	if face_player_on_arrival and actor.is_inside_tree():
		_face_actor_toward(actor, arrival)

	_set_actor_visible(true)
	jumpscare_triggered.emit()
	var look_pos := arrival
	if player != null and player.is_inside_tree():
		look_pos = player.global_position
	var run_duration := _compute_scare_run_duration(actor.global_position, arrival)
	_play_actor_animation(run_animation, run_animation_speed_scale)
	_play_random_scream()
	_start_scare_run(actor, arrival, look_pos, run_duration)
	if _scare_tween != null:
		await _scare_tween.finished
	if actor.is_inside_tree():
		var grounded := _project_to_floor(actor.global_position)
		actor.global_position = grounded
	if face_player_on_arrival and actor.is_inside_tree() and player != null and player.is_inside_tree():
		_face_actor_toward(actor, player.global_position)
	_play_actor_animation(dialogue_animation)
	_start_dialogue(player)


func _start_dialogue(player: Node3D) -> void:
	var actor := _resolve_scare_actor()
	var focus := _prepare_dialogue_focus(actor, player)
	var game_player := GameManager.get_player()
	if game_player != null and game_player.has_method("focus_camera_on"):
		game_player.focus_camera_on(focus)
	_owns_active_dialogue = true
	if not DialogueController.dialogue_finished.is_connected(_on_jumpscare_dialogue_finished):
		DialogueController.dialogue_finished.connect(_on_jumpscare_dialogue_finished, CONNECT_ONE_SHOT)
	DialogueController.start_dialogue(dialogue_resource, dialogue_title, focus)


func _resolve_scare_actor() -> Node3D:
	if not scare_actor_path.is_empty():
		var external := get_node_or_null(scare_actor_path) as Node3D
		if external != null:
			return external
	return _scare_actor


func _resolve_dialogue_focus(actor: Node3D) -> Node3D:
	if not camera_focus_path.is_empty():
		var custom_focus := get_node_or_null(camera_focus_path) as Node3D
		if custom_focus != null:
			return custom_focus

	var actor_focus := actor.get_node_or_null("DialogueFocusPoint") as Node3D
	if actor_focus != null:
		return actor_focus

	if _camera_focus_point != null and actor.is_inside_tree():
		_camera_focus_point.global_position = actor.global_position + Vector3(0.0, actor_focus_height, 0.0)
		return _camera_focus_point

	return actor if actor != null else self


func _prepare_dialogue_focus(actor: Node3D, player: Node3D) -> Node3D:
	if face_player_on_arrival and actor != null and player != null:
		if actor.is_inside_tree() and player.is_inside_tree():
			_face_actor_toward(actor, player.global_position)
	return _resolve_dialogue_focus(actor)


func _set_actor_visible(is_visible: bool) -> void:
	if not hide_actor_until_trigger:
		return
	var actor := _resolve_scare_actor()
	if actor == null:
		return
	actor.visible = is_visible


func _resolve_animation_player() -> AnimationPlayer:
	var actor := _resolve_scare_actor()
	if actor == null:
		return null
	if not animation_player_path.is_empty():
		var explicit := actor.get_node_or_null(animation_player_path) as AnimationPlayer
		if explicit != null:
			return explicit
	return _find_animation_player(actor)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_actor_animation(animation_name: String, speed_scale: float = 1.0) -> void:
	if animation_name.is_empty():
		return
	var player := _resolve_animation_player()
	if player == null:
		push_warning("SoftJumpscareSetup: no AnimationPlayer en el actor para '%s'." % animation_name)
		return
	if not player.has_animation(animation_name):
		push_warning("SoftJumpscareSetup: animación '%s' no encontrada." % animation_name)
		return
	player.speed_scale = speed_scale
	player.play(animation_name)


func _on_jumpscare_dialogue_finished() -> void:
	_run_post_dialogue_sequence()


func _run_post_dialogue_sequence() -> void:
	if not _owns_active_dialogue:
		return
	_owns_active_dialogue = false
	jumpscare_dialogue_finished.emit()
	_play_actor_animation(after_dialogue_animation)
	if exit_after_dialogue:
		jumpscare_rise_started.emit()
		await _run_exit_rise_sequence()
	jumpscare_completed.emit()


func _run_exit_rise_sequence() -> void:
	var actor := _resolve_scare_actor()
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	_kill_exit_tween()
	var start_pos := actor.global_position
	var end_y := start_pos.y + exit_rise_height
	_exit_tween = create_tween()
	_exit_tween.set_trans(Tween.TRANS_QUAD)
	_exit_tween.set_ease(Tween.EASE_IN)
	_exit_tween.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(actor) or not actor.is_inside_tree():
				return
			actor.global_position = Vector3(start_pos.x, lerpf(start_pos.y, end_y, t), start_pos.z),
		0.0,
		1.0,
		exit_rise_duration
	)
	await _exit_tween.finished
	jumpscare_rise_finished.emit()
	if is_instance_valid(actor):
		actor.visible = false


func _compute_arrival_position(player: Node3D) -> Vector3:
	var arrival: Vector3
	if arrival_mode == ArrivalMode.MARKER and _arrival_point != null and _arrival_point.is_inside_tree():
		arrival = _arrival_point.global_position
	elif not player.is_inside_tree():
		arrival = global_position
	else:
		var forward := -player.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
		arrival = player.global_position + forward * arrival_distance
	return _project_to_floor(arrival)


func _project_to_floor(world_pos: Vector3) -> Vector3:
	if not snap_actor_to_floor or not is_inside_tree():
		return world_pos
	var space := get_world_3d().direct_space_state
	if space == null:
		return world_pos
	var from := world_pos + Vector3.UP * floor_ray_height
	var to := world_pos + Vector3.DOWN * floor_ray_depth
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return world_pos
	return Vector3(world_pos.x, hit.position.y, world_pos.z)


func _face_actor_toward(actor: Node3D, world_target: Vector3) -> void:
	if not actor.is_inside_tree():
		return
	var pos := actor.global_position
	var direction := world_target - pos
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var look_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	look_basis = look_basis.rotated(Vector3.UP, _MIXAMO_YAW_CORRECTION + deg_to_rad(actor_yaw_offset_deg))
	actor.global_transform = Transform3D(look_basis, pos)


func _play_random_scream() -> void:
	if _scream_player == null:
		return
	var actor := _resolve_scare_actor()
	if actor != null and actor.is_inside_tree():
		_scream_player.global_position = actor.global_position
	var tier := JumpscareScreamLibrary.Tier.SOFT
	if audio_tier == AllowedAudioTier.MEDIUM:
		tier = JumpscareScreamLibrary.Tier.MEDIUM
	var stream := JumpscareScreamLibrary.pick_random(tier)
	if stream == null:
		push_warning("SoftJumpscareSetup: no hay clips para tier %s" % tier)
		return
	_scream_player.stream = stream
	_scream_player.play()


func _compute_scare_run_duration(start: Vector3, arrival: Vector3) -> float:
	if not use_run_speed_for_duration or scare_run_speed <= 0.01:
		return scare_duration
	var horizontal_start := Vector3(start.x, 0.0, start.z)
	var horizontal_arrival := Vector3(arrival.x, 0.0, arrival.z)
	var distance := horizontal_start.distance_to(horizontal_arrival)
	return clampf(distance / scare_run_speed, min_scare_duration, max_scare_duration)


func _start_scare_run(actor: Node3D, arrival: Vector3, look_target: Vector3, duration: float) -> void:
	if not actor.is_inside_tree():
		return
	_kill_scare_tween()
	var start := actor.global_position
	_scare_tween = create_tween()
	_scare_tween.set_trans(Tween.TRANS_LINEAR)
	_scare_tween.set_ease(Tween.EASE_IN_OUT)
	_scare_tween.tween_method(
		func(t: float) -> void:
			_update_scare_run_step(actor, start, arrival, look_target, t),
		0.0,
		1.0,
		duration
	)


func _update_scare_run_step(
	actor: Node3D,
	start: Vector3,
	arrival: Vector3,
	look_target: Vector3,
	t: float
) -> void:
	if not actor.is_inside_tree():
		return
	actor.global_position = start.lerp(arrival, t)
	if not face_player_on_arrival:
		return
	var face_target := arrival if t < 0.92 else look_target
	_face_actor_toward(actor, face_target)


func _kill_exit_tween() -> void:
	if _exit_tween != null and _exit_tween.is_valid() and _exit_tween.is_running():
		_exit_tween.kill()
	_exit_tween = null


func _kill_scare_tween() -> void:
	if _scare_tween != null and _scare_tween.is_valid() and _scare_tween.is_running():
		_scare_tween.kill()
	_scare_tween = null
