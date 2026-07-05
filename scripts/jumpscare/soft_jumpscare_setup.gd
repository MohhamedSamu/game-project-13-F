@tool
class_name SoftJumpscareSetup
extends Node3D
## Susto no letal: trigger invisible, actor corre al jugador, grito aleatorio y diálogo.
## Señales: [signal jumpscare_triggered] al aparecer el actor; [signal jumpscare_dialogue_finished]
## al cerrar el diálogo; [signal jumpscare_rise_started] / [signal jumpscare_rise_finished] durante la salida;
## [signal jumpscare_completed] cuando termina todo el susto.

signal jumpscare_dialogue_finished
signal jumpscare_completed
signal jumpscare_starting
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

const SPAWN_SIDE_MARKER := 0
const SPAWN_SIDE_PLAYER_RIGHT := 1
const SPAWN_SIDE_PLAYER_LEFT := 2

@export_group("Audio")
## Solo soft o medium. Hard queda reservado para jumpscares letales.
@export var audio_tier: AllowedAudioTier = AllowedAudioTier.SOFT

@export_group("Trigger")
@export var use_trigger_zone: bool = true
@export var trigger_once: bool = true
## Si no está vacío, no se repite tras activarse (persistente en GameManager).
@export var trigger_flag: String = ""
## No dispara hasta que esta flag exista en GameManager (p. ej. fin del susto del baño).
@export var require_flag: String = ""
@export var play_scream_on_trigger: bool = true

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

@export_group("Spawn del actor")
@export_enum("Spawn Marker:0", "Player Right:1", "Player Left:2") var spawn_side: int = SPAWN_SIDE_MARKER
## Si está asignado, el actor aparece en este Marker3D en lugar de junto al jugador.
@export var spawn_marker_path: NodePath
## Si está asignado, la carrera termina en este Marker3D.
@export var arrival_marker_path: NodePath
@export_range(0.5, 12.0, 0.1) var spawn_lateral_distance: float = 3.0
@export_range(-8.0, 8.0, 0.1) var spawn_forward_offset: float = 1.2
## Resta distancia hacia atrás del jugador (suma separación extra al spawn).
@export_range(0.0, 12.0, 0.1) var spawn_backward_offset: float = 0.0
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
## Si usas [member scare_actor_path], el actor no se mueve ni oculta al cargar (p. ej. NPC en bombas).
@export var keep_external_actor_in_place: bool = false
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
var _scare_run_actor: Node3D
var _scare_run_physics_enabled: bool = true

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
	if _trigger_zone != null and use_trigger_zone:
		_trigger_zone.monitoring = false
	call_deferred("_hide_actor_until_trigger")
	call_deferred("_sync_trigger_zone")
	if _trigger_zone != null:
		if use_trigger_zone:
			_trigger_zone.player_entered.connect(_on_player_entered_trigger)
		else:
			_trigger_zone.monitoring = false


func trigger_jumpscare(player: Node3D = null) -> void:
	if Engine.is_editor_hint():
		return
	if not _can_trigger():
		return
	if _triggered and trigger_once:
		return
	if GameManager.dialogue_active or GameManager.minigame_active or GameManager.level_intro_active:
		return
	if player == null:
		player = GameManager.get_player() as Node3D
	if player == null:
		return
	_run_soft_jumpscare(player)


func _on_player_entered_trigger(player: Node3D) -> void:
	trigger_jumpscare(player)


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
		_apply_spawn_transform(target, spawn_xf, true)
	elif target.get_parent() == _spawn_point.get_parent():
		_apply_spawn_transform(target, spawn_xf, false)


func _apply_spawn_transform(target: Node3D, spawn_xf: Transform3D, use_global: bool) -> void:
	if use_global:
		target.global_position = spawn_xf.origin
		target.global_rotation = spawn_xf.basis.get_euler()
	else:
		target.position = spawn_xf.origin
		target.rotation = spawn_xf.basis.get_euler()


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


func refresh_armed_state() -> void:
	_sync_trigger_zone()


func reset_dev_state() -> void:
	_triggered = false
	_owns_active_dialogue = false
	_sync_trigger_zone()


func _can_trigger() -> bool:
	if not require_flag.is_empty() and not GameManager.get_flag(require_flag):
		return false
	if not trigger_flag.is_empty() and GameManager.get_flag(trigger_flag):
		return false
	return true


func _sync_trigger_zone() -> void:
	if _trigger_zone == null or not use_trigger_zone:
		return
	_trigger_zone.monitoring = _can_trigger() and not (_triggered and trigger_once)


func _load_trigger_state() -> void:
	if not trigger_flag.is_empty() and GameManager.get_flag(trigger_flag):
		_triggered = true


func _hide_editor_gizmos() -> void:
	var arrival_gizmo := get_node_or_null("ScareArrivalPoint/ArrivalGizmo") as Node3D
	if arrival_gizmo != null:
		arrival_gizmo.visible = false


func _hide_actor_until_trigger() -> void:
	if not is_inside_tree():
		return
	if _uses_external_scare_actor():
		_hide_builtin_scare_actor_placeholder()
	var actor := _resolve_scare_actor()
	if actor == null:
		return
	if _uses_external_scare_actor() and keep_external_actor_in_place:
		return
	if actor is GasStationNPC:
		return
	_snap_node_to_spawn(actor)
	_set_actor_visible(false)
	if _actor_preview != null and not _uses_external_scare_actor():
		_actor_preview.visible = false


func _hide_builtin_scare_actor_placeholder() -> void:
	if _scare_actor != null:
		_scare_actor.visible = false
	if _actor_preview != null:
		_actor_preview.visible = false


func _run_soft_jumpscare(player: Node3D) -> void:
	_run_soft_jumpscare_async(player)


func _run_soft_jumpscare_async(player: Node3D) -> void:
	if _is_scene4_bathroom_exit_jumpscare():
		await _run_scene4_bathroom_exit_jumpscare(player)
		return

	var actor := _resolve_scare_actor()
	if actor == null:
		push_warning("SoftJumpscareSetup: falta ScareActor o scare_actor_path.")
		return
	if dialogue_resource == null:
		push_warning("SoftJumpscareSetup: asigna dialogue_resource.")
		return

	jumpscare_starting.emit()
	_refresh_exit_setup_markers()
	_stop_linked_bathroom_horror_audio()

	if player != null and player.has_method("stop_movement_immediately"):
		player.stop_movement_immediately()
	if player != null and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	_triggered = true
	if not trigger_flag.is_empty():
		GameManager.set_flag(trigger_flag, true)
		if trigger_flag == "scene4_bathroom_exit_jumpscare_done":
			get_tree().call_group(&"coca_fridge_interact", &"refresh_interaction_state")

	_prepare_external_actor_for_jumpscare(actor)

	if _uses_external_scare_actor() and keep_external_actor_in_place:
		_set_actor_visible(false)

	if play_scream_on_trigger:
		_play_random_scream(player)

	var arrival := _compute_arrival_position(player)
	_place_actor_at_spawn(actor, player)
	if face_player_on_arrival and actor.is_inside_tree():
		_face_actor_toward(actor, arrival)

	_set_actor_visible(true)
	jumpscare_triggered.emit()
	var look_pos := arrival
	if player != null and player.is_inside_tree():
		look_pos = player.global_position
	var run_duration := _compute_scare_run_duration(actor.global_position, arrival)
	_play_actor_animation(_resolve_charge_animation(), run_animation_speed_scale)
	_start_scare_run(actor, arrival, look_pos, run_duration)
	if _scare_tween != null:
		await _scare_tween.finished
	_end_scare_run_physics()
	_stop_charge_animation()
	if actor.is_inside_tree() and _uses_marker_run_path():
		var arrival_marker := _resolve_arrival_marker()
		if arrival_marker != null and arrival_marker.is_inside_tree():
			actor.global_position = arrival_marker.global_position
	elif actor.is_inside_tree():
		var grounded := _project_to_floor(actor.global_position)
		actor.global_position = grounded
	if face_player_on_arrival and actor.is_inside_tree():
		var face_target := player.global_position if player != null and player.is_inside_tree() else arrival
		_face_actor_toward(actor, face_target)
	_play_actor_animation(dialogue_animation)
	_start_dialogue(player)


func _run_scene4_bathroom_exit_jumpscare(player: Node3D) -> void:
	if dialogue_resource == null:
		push_warning("SoftJumpscareSetup: asigna dialogue_resource.")
		return

	_refresh_exit_setup_markers()
	var gas_npc := _resolve_scene4_gas_npc()
	if gas_npc == null:
		push_error(
			"Scene4BathroomExitJumpscare: no se encontró GasStationNPC "
			+ "(scare_actor_path=%s)." % String(scare_actor_path)
		)
		return

	var setup := _get_exit_setup()
	var spawn_marker := setup.get_run_start_marker() if setup != null else null
	var arrival_marker := setup.get_scare_stop_marker() if setup != null else null
	if spawn_marker == null or arrival_marker == null:
		push_error(
			"Scene4BathroomExitJumpscare: faltan markers de spawn/llegada en Scene4BathroomExitSetup."
		)
		return

	jumpscare_starting.emit()
	_stop_linked_bathroom_horror_audio()

	if player != null and player.has_method("stop_movement_immediately"):
		player.stop_movement_immediately()
	if player != null and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	_triggered = true
	if not trigger_flag.is_empty():
		GameManager.set_flag(trigger_flag, true)

	gas_npc.prepare_for_bathroom_exit_jumpscare()
	var spawn_pos := _project_to_floor(
		spawn_marker.global_position,
		spawn_marker.global_position.y
	)
	gas_npc.move_to_global_pose(spawn_pos, spawn_marker.global_rotation)

	if play_scream_on_trigger:
		_play_random_scream(player)

	jumpscare_triggered.emit()
	var arrival_pos := _project_to_floor(
		arrival_marker.global_position,
		arrival_marker.global_position.y
	)
	print(
		"Scene4BathroomExitJumpscare: NPC en spawn ",
		gas_npc.global_position,
		" -> llegada ",
		arrival_pos
	)
	var look_pos := player.global_position if player != null and player.is_inside_tree() else arrival_pos
	var run_duration := _compute_scare_run_duration(spawn_pos, arrival_pos)
	_play_actor_animation_on(gas_npc, _resolve_charge_animation_for(gas_npc), run_animation_speed_scale)
	_start_scare_run_on_actor(gas_npc, spawn_pos, arrival_pos, look_pos, run_duration)
	if _scare_tween != null:
		await _scare_tween.finished
	_end_scare_run_physics()
	_stop_charge_animation_on(gas_npc)
	gas_npc.move_to_global_pose(arrival_pos, gas_npc.global_rotation)
	if face_player_on_arrival and player != null and player.is_inside_tree():
		_face_actor_toward(gas_npc, player.global_position)
	_play_actor_animation_on(gas_npc, dialogue_animation)
	_start_dialogue(player)


func _resolve_scene4_gas_npc() -> GasStationNPC:
	if not scare_actor_path.is_empty():
		var from_path := get_node_or_null(scare_actor_path) as GasStationNPC
		if from_path != null:
			return from_path
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("GasStationNPC", true, false) as GasStationNPC


func _resolve_charge_animation_for(actor: Node3D) -> String:
	if actor == null:
		return run_animation
	if _actor_has_animation(actor, &"walking_in_place"):
		return "walking_in_place"
	return run_animation


func _play_actor_animation_on(actor: Node3D, animation_name: String, speed_scale: float = 1.0) -> void:
	if animation_name.is_empty() or actor == null:
		return
	var player := _resolve_animation_player_for_actor(actor)
	if player == null:
		push_warning("SoftJumpscareSetup: no AnimationPlayer en el actor para '%s'." % animation_name)
		return
	if not player.has_animation(animation_name):
		push_warning("SoftJumpscareSetup: animación '%s' no encontrada." % animation_name)
		return
	player.speed_scale = speed_scale
	player.play(animation_name)


func _stop_charge_animation_on(actor: Node3D) -> void:
	var player := _resolve_animation_player_for_actor(actor)
	if player == null:
		return
	player.speed_scale = 1.0


func _start_scare_run_on_actor(
	actor: Node3D,
	start: Vector3,
	arrival: Vector3,
	look_target: Vector3,
	duration: float
) -> void:
	if actor == null or not actor.is_inside_tree():
		return
	_kill_scare_tween()
	_scare_run_actor = actor
	if actor is CharacterBody3D:
		var body := actor as CharacterBody3D
		_scare_run_physics_enabled = body.is_physics_processing()
		body.set_physics_process(false)
		body.velocity = Vector3.ZERO
	actor.global_position = start
	_scare_tween = create_tween()
	_scare_tween.set_trans(Tween.TRANS_QUAD)
	_scare_tween.set_ease(Tween.EASE_OUT)
	_scare_tween.tween_method(
		func(t: float) -> void:
			_update_scare_run_step(actor, start, arrival, look_target, t),
		0.0,
		1.0,
		duration
	)


func _start_dialogue(player: Node3D) -> void:
	var actor := _resolve_scare_actor()
	var focus := _prepare_dialogue_focus(actor, player)
	var game_player := GameManager.get_player()
	if game_player != null and game_player.has_method("focus_camera_on"):
		game_player.focus_camera_on(focus)
	_owns_active_dialogue = true
	if DialogueController.dialogue_finished.is_connected(_on_jumpscare_dialogue_finished):
		DialogueController.dialogue_finished.disconnect(_on_jumpscare_dialogue_finished)
	DialogueController.dialogue_finished.connect(_on_jumpscare_dialogue_finished, CONNECT_ONE_SHOT)
	DialogueController.start_dialogue(dialogue_resource, dialogue_title, focus)
	if not GameManager.dialogue_active:
		_owns_active_dialogue = false


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

	var setup := _get_exit_setup()
	if setup != null and _is_scene4_bathroom_exit_jumpscare():
		var setup_focus := setup.get_dialogue_focus_marker()
		if setup_focus != null:
			return setup_focus

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


func _set_actor_visible(should_show: bool) -> void:
	var actor := _resolve_scare_actor()
	if actor == null:
		return
	if _is_scene4_bathroom_exit_jumpscare() and actor is GasStationNPC:
		if should_show:
			(actor as GasStationNPC).force_render_visible()
		return
	if _uses_external_scare_actor():
		if keep_external_actor_in_place and not should_show:
			return
		actor.visible = should_show
		return
	if not hide_actor_until_trigger:
		return
	actor.visible = should_show


func _uses_external_scare_actor() -> bool:
	if scare_actor_path.is_empty():
		return false
	var external := get_node_or_null(scare_actor_path) as Node3D
	return external != null and external != _scare_actor


func _prepare_external_actor_for_jumpscare(actor: Node3D) -> void:
	if not _uses_external_scare_actor() or actor == null:
		return
	if not keep_external_actor_in_place:
		return
	if actor is GasStationNPC:
		if _is_scene4_bathroom_exit_jumpscare():
			(actor as GasStationNPC).prepare_for_bathroom_exit_jumpscare()
		else:
			(actor as GasStationNPC).begin_scripted_sequence()
	elif actor.has_method("pause_for_jumpscare"):
		actor.call("pause_for_jumpscare")
	_reset_actor_physics_state(actor)


func _reset_actor_physics_state(actor: Node3D) -> void:
	if actor is CharacterBody3D:
		var body := actor as CharacterBody3D
		body.velocity = Vector3.ZERO


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
	var should_emit := _owns_active_dialogue
	if not should_emit and _triggered and is_in_group(&"scene4_bathroom_exit_jumpscare"):
		should_emit = true
	if not should_emit:
		return
	_owns_active_dialogue = false
	jumpscare_dialogue_finished.emit()
	if (
		not after_dialogue_animation.is_empty()
		and not (_uses_external_scare_actor() and keep_external_actor_in_place)
	):
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
	var marker := _resolve_arrival_marker()
	if marker != null and marker.is_inside_tree():
		return marker.global_position
	var arrival: Vector3
	if arrival_mode == ArrivalMode.MARKER and _arrival_point != null and _arrival_point.is_inside_tree():
		arrival = _arrival_point.global_position
	elif not player.is_inside_tree():
		arrival = global_position
	else:
		var forward := _player_flat_forward(player)
		arrival = player.global_position + forward * arrival_distance
	return _project_to_floor(arrival, _resolve_floor_fallback_y(player))


func _place_actor_at_spawn(actor: Node3D, player: Node3D) -> void:
	if actor == null:
		return
	var spawn_marker := _resolve_spawn_marker()
	if spawn_marker != null and spawn_marker.is_inside_tree():
		var spawn_pos := spawn_marker.global_position
		spawn_pos = _project_to_floor(spawn_pos, spawn_pos.y)
		actor.global_position = spawn_pos
		var arrival_marker := _resolve_arrival_marker()
		if arrival_marker != null and face_player_on_arrival:
			_face_actor_toward(actor, arrival_marker.global_position)
		else:
			actor.global_rotation = spawn_marker.global_rotation
		_reset_actor_physics_state(actor)
		if actor is GasStationNPC:
			(actor as GasStationNPC).visible = true
		return
	if _uses_external_scare_actor() and _is_scene4_bathroom_exit_jumpscare():
		push_warning(
			"SoftJumpscareSetup: asigna spawn_marker en Scene4BathroomExitSetup para el NPC externo."
		)
		return
	var side := _normalized_spawn_side()
	if side == SPAWN_SIDE_MARKER or player == null or not player.is_inside_tree():
		_snap_node_to_spawn(actor)
		return
	var lateral := _player_flat_right(player)
	var side_sign := 1.0 if side == SPAWN_SIDE_PLAYER_RIGHT else -1.0
	var forward := _player_flat_forward(player)
	var spawn_pos := (
		player.global_position
		+ lateral * spawn_lateral_distance * side_sign
		+ forward * (spawn_forward_offset - spawn_backward_offset)
	)
	spawn_pos = _project_to_floor(spawn_pos, _resolve_floor_fallback_y(player))
	if actor.is_inside_tree():
		actor.global_position = spawn_pos
		_reset_actor_physics_state(actor)
		if _spawn_point != null and _spawn_point.is_inside_tree():
			actor.global_rotation = _spawn_point.global_rotation


func _normalized_spawn_side() -> int:
	if spawn_side == SPAWN_SIDE_PLAYER_RIGHT or spawn_side == SPAWN_SIDE_PLAYER_LEFT:
		return spawn_side
	return SPAWN_SIDE_MARKER


func _player_flat_forward(player: Node3D) -> Vector3:
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func _player_flat_right(player: Node3D) -> Vector3:
	var right := player.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		return Vector3.RIGHT
	return right.normalized()


func _resolve_charge_animation() -> String:
	if not _uses_marker_run_path():
		return run_animation
	var actor := _resolve_scare_actor()
	if actor == null:
		return run_animation
	if _actor_has_animation(actor, &"walking_in_place"):
		return "walking_in_place"
	return run_animation


func _stop_charge_animation() -> void:
	var player := _resolve_animation_player()
	if player == null:
		return
	player.speed_scale = 1.0


func _actor_has_animation(actor: Node3D, anim_name: StringName) -> bool:
	var player := _resolve_animation_player_for_actor(actor)
	if player == null:
		return false
	return player.has_animation(String(anim_name))


func _resolve_animation_player_for_actor(actor: Node3D) -> AnimationPlayer:
	if actor == null:
		return null
	if not animation_player_path.is_empty():
		var explicit := actor.get_node_or_null(animation_player_path) as AnimationPlayer
		if explicit != null:
			return explicit
	return _find_animation_player(actor)


func _is_scene4_bathroom_exit_jumpscare() -> bool:
	return is_in_group(&"scene4_bathroom_exit_jumpscare")


func _resolve_spawn_marker() -> Marker3D:
	if not spawn_marker_path.is_empty():
		var explicit := get_node_or_null(spawn_marker_path) as Marker3D
		if explicit != null:
			return explicit
	if not _is_scene4_bathroom_exit_jumpscare():
		return null
	var setup := _get_exit_setup()
	if setup != null:
		return setup.get_run_start_marker()
	return null


func _resolve_arrival_marker() -> Marker3D:
	if not arrival_marker_path.is_empty():
		var explicit := get_node_or_null(arrival_marker_path) as Marker3D
		if explicit != null:
			return explicit
	if not _is_scene4_bathroom_exit_jumpscare():
		return null
	var setup := _get_exit_setup()
	if setup != null:
		return setup.get_scare_stop_marker()
	return null


func _get_exit_setup() -> Scene4BathroomExitSetup:
	for node in get_tree().get_nodes_in_group(&"scene4_bathroom_exit_setup"):
		return node as Scene4BathroomExitSetup
	return null


func _refresh_exit_setup_markers() -> void:
	if not _is_scene4_bathroom_exit_jumpscare():
		return
	var setup := _get_exit_setup()
	if setup != null:
		setup.apply_to_jumpscare(self)


func _uses_marker_run_path() -> bool:
	if not _is_scene4_bathroom_exit_jumpscare():
		return false
	return _resolve_spawn_marker() != null and _resolve_arrival_marker() != null


func _project_to_floor(world_pos: Vector3, fallback_y: float = NAN) -> Vector3:
	if not snap_actor_to_floor or not is_inside_tree():
		return world_pos
	var floor_y := _raycast_floor_y(world_pos)
	if not is_nan(floor_y):
		return Vector3(world_pos.x, floor_y, world_pos.z)
	if not is_nan(fallback_y):
		return Vector3(world_pos.x, fallback_y, world_pos.z)
	return world_pos


func _resolve_floor_fallback_y(player: Node3D) -> float:
	if player == null or not player.is_inside_tree():
		return NAN
	return _raycast_floor_y(player.global_position)


func _raycast_floor_y(world_pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return NAN
	var from := world_pos + Vector3.UP * floor_ray_height
	var to := world_pos + Vector3.DOWN * floor_ray_depth
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return hit.position.y


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
	actor.global_rotation = look_basis.get_euler()


func _stop_linked_bathroom_horror_audio() -> void:
	if require_flag != "bathroom_sink_horror_done" and not is_in_group(&"scene4_bathroom_exit_jumpscare"):
		return
	Scene4BathroomExitDirector.clear_bathroom_presentation()


func _play_random_scream(listener_anchor: Node3D = null) -> void:
	if _scream_player == null:
		return
	var scream_pos := global_position
	var player := listener_anchor
	if player == null:
		player = GameManager.get_player() as Node3D
	if keep_external_actor_in_place and player != null and player.is_inside_tree():
		scream_pos = player.global_position
	else:
		var actor := _resolve_scare_actor()
		if actor != null and actor.is_inside_tree():
			scream_pos = actor.global_position
		elif player != null and player.is_inside_tree():
			scream_pos = player.global_position
	_scream_player.global_position = scream_pos
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
	_scare_run_actor = actor
	if actor is CharacterBody3D:
		var body := actor as CharacterBody3D
		_scare_run_physics_enabled = body.is_physics_processing()
		body.set_physics_process(false)
		body.velocity = Vector3.ZERO
	var start := actor.global_position
	if _uses_marker_run_path():
		var spawn_marker := _resolve_spawn_marker()
		var arrival_marker := _resolve_arrival_marker()
		if spawn_marker != null and spawn_marker.is_inside_tree():
			start = _project_to_floor(spawn_marker.global_position, spawn_marker.global_position.y)
		if arrival_marker != null and arrival_marker.is_inside_tree():
			arrival = _project_to_floor(arrival_marker.global_position, arrival_marker.global_position.y)
	else:
		start = _project_to_floor(start, _resolve_floor_fallback_y(GameManager.get_player() as Node3D))
		arrival = _project_to_floor(arrival, start.y)
	actor.global_position = start
	_scare_tween = create_tween()
	if _uses_marker_run_path():
		_scare_tween.set_trans(Tween.TRANS_QUAD)
		_scare_tween.set_ease(Tween.EASE_OUT)
	else:
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
	if _uses_marker_run_path():
		actor.global_position = start.lerp(arrival, t)
		if t >= 1.0:
			actor.global_position = arrival
	else:
		var flat_start := Vector2(start.x, start.z)
		var flat_arrival := Vector2(arrival.x, arrival.z)
		var flat_pos := flat_start.lerp(flat_arrival, t)
		var grounded := _project_to_floor(
			Vector3(flat_pos.x, start.y, flat_pos.y),
			start.y
		)
		actor.global_position = grounded
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
	_end_scare_run_physics()


func _end_scare_run_physics() -> void:
	if _scare_run_actor is CharacterBody3D and is_instance_valid(_scare_run_actor):
		var body := _scare_run_actor as CharacterBody3D
		body.set_physics_process(_scare_run_physics_enabled)
		body.velocity = Vector3.ZERO
	_scare_run_actor = null
