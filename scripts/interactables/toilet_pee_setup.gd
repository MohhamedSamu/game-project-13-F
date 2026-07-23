@tool
class_name ToiletPeeSetup
extends Node3D
## Minijuego de inodoro (opción A): cámara fija externa, fade a negro, chorro con partículas.

enum State { IDLE, ENTERING, ACTIVE, EXITING }

const _FOCUS_PREVIEW_COLOR := Color(0.35, 0.78, 1.0, 0.38)
const _PROXIMITY_PREVIEW_COLOR := Color(0.45, 0.95, 0.55, 0.16)
const _BLADDER_EMPTY_EPSILON := 1.0
const _WANTS_SINK_FLAG := &"wants_bathroom_sink"

@export_group("Cámara")
## Cámara fija colocada en el nivel padre (configurable desde el inspector).
@export var fixed_camera_path: NodePath

@export_group("Interacción")
@export var prompt_enter: String = "Presiona [E] para usar el inodoro"
@export var prompt_exit: String = "Presiona [E] para salir"
@export var aim_hint: String = "Mantén click izquierdo · [E] para salir"
## Centro de la cúpula de interacción (offset local).
@export var focus_offset: Vector3 = Vector3(0.0, 0.45, 0.0):
	set(value):
		focus_offset = value
		_request_rebuild()
## Radio de la cúpula donde la mira activa el raycast (como FocusHitbox del payaso).
@export_range(0.2, 3.0, 0.05) var focus_radius: float = 0.675:
	set(value):
		focus_radius = maxf(value, 0.1)
		_request_rebuild()
## Radio de proximidad para poder interactuar (cúpula exterior).
@export_range(0.5, 6.0, 0.05) var proximity_radius: float = 1.65:
	set(value):
		proximity_radius = maxf(value, 0.2)
		_request_rebuild()

@export_group("Editor")
@export var show_editor_preview: bool = true:
	set(value):
		show_editor_preview = value
		_update_preview_visibility()

@export_group("Fade")
@export var fade_to_black_duration: float = 0.35
@export var fade_from_black_duration: float = 1.2

@export_group("Nozzle / chorro")
@export_range(5.0, 80.0, 1.0) var nozzle_yaw_limit_deg: float = 32.0
@export_range(5.0, 60.0, 1.0) var nozzle_pitch_limit_deg: float = 22.0
@export_range(0.02, 0.5, 0.01) var nozzle_sensitivity: float = 0.14
@export_range(-45.0, 45.0, 1.0) var default_nozzle_yaw_deg: float = 0.0
@export_range(-60.0, 30.0, 1.0) var default_nozzle_pitch_deg: float = -12.0
@export_range(0.4, 2.0, 0.05) var particle_lifetime: float = 0.95
@export var particle_direction: Vector3 = Vector3(0.0, -0.2, -1.0)
@export_range(2.0, 14.0, 0.25) var particle_speed_min: float = 5.0
@export_range(2.0, 16.0, 0.25) var particle_speed_max: float = 8.5
@export_range(0.0, 20.0, 0.5) var particle_gravity: float = 5.5

@export_group("Acceso")
## Puerta principal del baño; el inodoro solo es usable cuando esa puerta está abierta.
@export var bathroom_door_path: NodePath
@export var bathroom_blocker_wall_path: NodePath

@export_group("Vejiga")
@export var bladder_capacity: float = 100.0
## Segundos de chorro continuo para vaciar la vejiga al 100%.
@export var bladder_drain_duration: float = 20.0
@export var show_bladder_ui: bool = true
@export var empty_bladder_thought: String = "ya no tenía deseos de usar el inodoro"
@export var post_sequence_thought: String = "ya no quería ir al baño, era mejor tomar algo"
@export var wash_hands_thought: String = "tengo que lavarme las manos"
@export var wash_hands_partial_thought: String = "tengo que lavarme las manos"
@export_range(1.0, 12.0, 0.5) var wash_hands_reminder_interval: float = 4.0

@export_group("Audio")
@export_subgroup("Zipper")
## Sonido al bajar el cierre (entrada al inodoro).
@export var zipper_down_sound: AudioStream
## Sonido al subir el cierre (salida del inodoro).
@export var zipper_up_sound: AudioStream
@export_subgroup("Chorro")
@export var stream_sound: AudioStream
@export_range(-80.0, 10.0, 0.5) var zipper_volume_db: float = -2.0
@export_range(-80.0, 10.0, 0.5) var stream_volume_db: float = -8.0

var _state: State = State.IDLE
var _nozzle_yaw_deg: float = 0.0
var _nozzle_pitch_deg: float = 0.0
var _bladder_remaining: float = 100.0
var _spraying: bool = false
var _was_in_empty_proximity: bool = false

var _interactable: InteractableDialogueComponent
var _ray_target: Area3D
var _ray_shape: CollisionShape3D
var _focus_target: Node3D
var _proximity_shape: CollisionShape3D
var _owns_ray_shape: bool = false
var _editor_focus_preview: MeshInstance3D
var _editor_proximity_preview: MeshInstance3D
var _focus_preview_material: StandardMaterial3D
var _proximity_preview_material: StandardMaterial3D
var _owns_proximity_shape: bool = false
var _nozzle: Node3D
var _particles: GPUParticles3D
var _overlay: CanvasLayer
var _fade_rect: ColorRect
var _bladder_label: Label
var _bladder_bar: ProgressBar
var _aim_label: Label
var _zipper_down_player: AudioStreamPlayer
var _zipper_up_player: AudioStreamPlayer
var _stream_player: AudioStreamPlayer
var _wash_hands_reminder_timer: Timer


func _enter_tree() -> void:
	_cache_child_refs()
	_rebuild()


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview_visibility()
		return
	_rebuild()
	if _interactable != null:
		_interactable.refresh_ray_target()
	_load_bladder_state()
	_reset_nozzle_angles()
	_set_particles_emitting(false)
	_set_overlay_visible(false)
	if _stream_player != null:
		_stream_player.finished.connect(_on_stream_player_finished)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _state == State.ACTIVE:
		_update_active_controls(delta)
		if _spraying:
			if _is_bladder_empty():
				_bladder_remaining = 0.0
				_save_bladder_state()
				_update_bladder_ui()
				_stop_spray()
			else:
				var drain_rate := _get_bladder_drain_rate()
				_bladder_remaining = maxf(_bladder_remaining - drain_rate * delta, 0.0)
				if _is_bladder_empty():
					_bladder_remaining = 0.0
				_save_bladder_state()
				_update_bladder_ui()
				if _is_bladder_empty():
					_stop_spray()
	_update_empty_bladder_thought()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_READY:
		_update_preview_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.ACTIVE:
		return
	if event.is_action_pressed("ui_cancel"):
		_request_exit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not InputHints.is_gamepad():
		_request_exit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_apply_nozzle_aim(event.relative)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _is_bladder_empty():
				_start_spray()
		else:
			_stop_spray()
		get_viewport().set_input_as_handled()


func _request_rebuild() -> void:
	if is_inside_tree():
		_rebuild()
	elif Engine.is_editor_hint():
		call_deferred("_rebuild")


func _cache_child_refs() -> void:
	_interactable = get_node_or_null("InteractableDialogueComponent") as InteractableDialogueComponent
	_ray_target = get_node_or_null("InteractionRayTarget") as Area3D
	_focus_target = get_node_or_null("DialogueFocusPoint") as Node3D
	if _ray_target != null:
		_ray_shape = _ray_target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_editor_focus_preview = get_node_or_null("EditorFocusPreview") as MeshInstance3D
	_editor_proximity_preview = get_node_or_null("EditorProximityPreview") as MeshInstance3D
	_nozzle = get_node_or_null("Nozzle") as Node3D
	_particles = get_node_or_null("Nozzle/PeeParticles") as GPUParticles3D
	_overlay = get_node_or_null("PeeOverlay") as CanvasLayer
	_zipper_down_player = get_node_or_null("Audio/ZipperDownPlayer") as AudioStreamPlayer
	_zipper_up_player = get_node_or_null("Audio/ZipperUpPlayer") as AudioStreamPlayer
	_stream_player = get_node_or_null("Audio/StreamPlayer") as AudioStreamPlayer
	if _overlay != null:
		_fade_rect = _overlay.get_node_or_null("FadeRect") as ColorRect
		_bladder_label = _overlay.get_node_or_null("BladderLabel") as Label
		_bladder_bar = _overlay.get_node_or_null("BladderBar") as ProgressBar
		_aim_label = _overlay.get_node_or_null("AimLabel") as Label
	if _interactable != null:
		_proximity_shape = _interactable.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _editor_focus_preview != null:
		_editor_focus_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _editor_proximity_preview != null:
		_editor_proximity_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_cache_child_refs()
	_apply_interaction_configuration()
	_sync_editor_previews()
	_update_preview_visibility()
	_apply_audio_configuration()
	_apply_particle_configuration()
	_update_bladder_ui()
	_setup_wash_hands_reminder_timer()


func _apply_interaction_configuration() -> void:
	if _interactable != null:
		_interactable.proximity_radius = proximity_radius
		_interactable.require_specific_ray_target = true
		_interactable.requires_focus_hitbox = false
		_interactable.prompt_text = prompt_enter
		_interactable.use_camera_focus = false
		_interactable.auto_find_focus_target = true

	if _focus_target != null:
		_focus_target.position = focus_offset

	if _ray_shape != null:
		_ray_shape.position = Vector3.ZERO
		var ray_sphere := _unique_ray_sphere()
		ray_sphere.radius = focus_radius
	if _ray_target != null:
		_ray_target.position = focus_offset

	if _proximity_shape != null:
		_proximity_shape.position = focus_offset
		var proximity_sphere := _unique_proximity_sphere()
		proximity_sphere.radius = proximity_radius


func _apply_audio_configuration() -> void:
	if _zipper_down_player != null:
		_zipper_down_player.volume_db = zipper_volume_db
		if zipper_down_sound != null:
			_zipper_down_player.stream = zipper_down_sound
	if _zipper_up_player != null:
		_zipper_up_player.volume_db = zipper_volume_db
		if zipper_up_sound != null:
			_zipper_up_player.stream = zipper_up_sound
	if _stream_player != null:
		_stream_player.volume_db = stream_volume_db
		if stream_sound != null:
			_stream_player.stream = _make_looping_stream(stream_sound)


func _make_looping_stream(source: AudioStream) -> AudioStream:
	if source is AudioStreamMP3:
		var looped := (source as AudioStreamMP3).duplicate()
		looped.loop = true
		return looped
	if source is AudioStreamWAV:
		var looped_wav := (source as AudioStreamWAV).duplicate()
		looped_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return looped_wav
	return source


func _apply_particle_configuration() -> void:
	if _particles == null:
		return
	_particles.lifetime = particle_lifetime
	var material := _particles.process_material as ParticleProcessMaterial
	if material == null:
		return
	var dir := particle_direction
	if dir.length_squared() < 0.0001:
		dir = Vector3(0.0, -0.2, -1.0)
	material.direction = dir.normalized()
	material.initial_velocity_min = particle_speed_min
	material.initial_velocity_max = particle_speed_max
	material.gravity = Vector3(0.0, -particle_gravity, 0.0)


func _sync_editor_previews() -> void:
	if _editor_focus_preview != null:
		var mesh := _unique_focus_preview_mesh()
		mesh.radius = focus_radius
		mesh.height = focus_radius * 2.0
		_editor_focus_preview.position = focus_offset
		_ensure_preview_material(_editor_focus_preview, _FOCUS_PREVIEW_COLOR, _focus_preview_material)
		_focus_preview_material = _editor_focus_preview.material_override as StandardMaterial3D

	if _editor_proximity_preview != null:
		var mesh := _unique_proximity_preview_mesh()
		mesh.radius = proximity_radius
		mesh.height = proximity_radius * 2.0
		_editor_proximity_preview.position = focus_offset
		_ensure_preview_material(_editor_proximity_preview, _PROXIMITY_PREVIEW_COLOR, _proximity_preview_material)
		_proximity_preview_material = _editor_proximity_preview.material_override as StandardMaterial3D


func _ensure_preview_material(
	preview: MeshInstance3D,
	color: Color,
	existing: StandardMaterial3D
) -> void:
	var material := existing
	if material == null:
		material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		preview.material_override = material
	material.albedo_color = color


func _update_preview_visibility() -> void:
	var preview_visible := Engine.is_editor_hint() and show_editor_preview
	if _editor_focus_preview != null:
		_editor_focus_preview.visible = preview_visible
	if _editor_proximity_preview != null:
		_editor_proximity_preview.visible = preview_visible


func _unique_ray_sphere() -> SphereShape3D:
	if not _owns_ray_shape:
		var shared := _ray_shape.shape as SphereShape3D
		var sphere := shared.duplicate() if shared else SphereShape3D.new()
		_ray_shape.shape = sphere
		_owns_ray_shape = true
		return sphere
	return _ray_shape.shape as SphereShape3D


func _unique_proximity_sphere() -> SphereShape3D:
	if not _owns_proximity_shape:
		var shared := _proximity_shape.shape as SphereShape3D
		var sphere := shared.duplicate() if shared else SphereShape3D.new()
		_proximity_shape.shape = sphere
		_owns_proximity_shape = true
		return sphere
	return _proximity_shape.shape as SphereShape3D


func _unique_focus_preview_mesh() -> SphereMesh:
	if _editor_focus_preview == null:
		return SphereMesh.new()
	var mesh := _editor_focus_preview.mesh as SphereMesh
	if mesh == null:
		mesh = SphereMesh.new()
		_editor_focus_preview.mesh = mesh
	return mesh


func _unique_proximity_preview_mesh() -> SphereMesh:
	if _editor_proximity_preview == null:
		return SphereMesh.new()
	var mesh := _editor_proximity_preview.mesh as SphereMesh
	if mesh == null:
		mesh = SphereMesh.new()
		_editor_proximity_preview.mesh = mesh
	return mesh


func can_handle_interaction() -> bool:
	if _state != State.IDLE:
		return false
	if GameManager.get_flag("bathroom_sink_horror_done"):
		return false
	if not _is_bathroom_accessible():
		return false
	return not _is_bladder_empty()


func _is_bathroom_accessible() -> bool:
	if bathroom_door_path.is_empty():
		return true
	var door := get_node_or_null(bathroom_door_path) as DoorInteractSetup
	if door == null:
		return true
	return door.opened


func get_interaction_prompt() -> String:
	if GameManager.get_flag("bathroom_sink_horror_done"):
		return ""
	if _state == State.ACTIVE:
		return _exit_prompt()
	if _state == State.IDLE and _is_bathroom_accessible() and not _is_bladder_empty():
		return prompt_enter
	return ""


func handle_interaction() -> void:
	if _state != State.IDLE or _is_bladder_empty() or GameManager.get_flag("bathroom_sink_horror_done"):
		return
	_begin_sequence()


func _begin_sequence() -> void:
	if _state != State.IDLE:
		return
	_stop_wash_hands_reminder()
	var camera := _get_fixed_camera()
	if camera == null:
		push_warning("ToiletPeeSetup: asigna fixed_camera_path a una Camera3D del nivel.")
		return

	var player := GameManager.player
	if player == null:
		return

	_state = State.ENTERING
	_load_bladder_state()
	_update_bladder_ui()
	GameManager.lock_player_minigame()
	if player.has_method("set_minigame_body_visible"):
		player.set_minigame_body_visible(false)
	if player.has_method("use_external_camera"):
		player.use_external_camera(camera)

	_set_overlay_visible(true)
	_update_hud_labels(true)
	await _run_enter_fade()
	if _state != State.ENTERING:
		return

	_state = State.ACTIVE
	_reset_nozzle_angles()
	_apply_nozzle_rotation()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud_labels(true)


func _request_exit() -> void:
	if _state != State.ACTIVE:
		return
	_state = State.EXITING
	_stop_wash_hands_reminder()
	_stop_spray()
	await _run_exit_sequence()
	_state = State.IDLE


func _run_enter_fade() -> void:
	_stop_spray()
	await _fade_alpha(0.0, 1.0, fade_to_black_duration)
	_play_zipper_down_once()
	await get_tree().create_timer(0.15).timeout
	await _fade_alpha(1.0, 0.0, fade_from_black_duration)


func _run_exit_sequence() -> void:
	_play_zipper_up_once()
	await get_tree().create_timer(0.2).timeout

	var player := GameManager.player
	if player != null and player.has_method("restore_player_camera"):
		player.restore_player_camera()

	_set_overlay_visible(false)
	_update_hud_labels(false)
	_save_bladder_state()
	if _get_bladder_percent() <= _BLADDER_EMPTY_EPSILON:
		GameManager.complete_objective("visited_bathroom")
	GameManager.unlock_player_minigame()
	_on_toilet_minigame_exit()


func _get_fixed_camera() -> Camera3D:
	if fixed_camera_path.is_empty():
		return null
	return get_node_or_null(fixed_camera_path) as Camera3D


func _fade_alpha(from: float, to: float, duration: float) -> void:
	if _fade_rect == null or duration <= 0.0:
		if _fade_rect != null:
			var c := _fade_rect.color
			c.a = to
			_fade_rect.color = c
		return
	var tween := create_tween()
	tween.tween_method(_set_fade_alpha, from, to, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _set_fade_alpha(alpha: float) -> void:
	if _fade_rect == null:
		return
	var c := _fade_rect.color
	c.a = clampf(alpha, 0.0, 1.0)
	_fade_rect.color = c


func _set_overlay_visible(is_visible: bool) -> void:
	if _overlay != null:
		_overlay.visible = is_visible
	if not is_visible and _fade_rect != null:
		_set_fade_alpha(0.0)


func _update_hud_labels(active: bool) -> void:
	if _aim_label != null:
		_aim_label.visible = active
		_aim_label.text = _aim_hint_text()
	if _bladder_label != null:
		_bladder_label.visible = active and show_bladder_ui
	if _bladder_bar != null:
		_bladder_bar.visible = active and show_bladder_ui
	_update_bladder_ui()


func _load_bladder_state() -> void:
	_bladder_remaining = GameManager.get_toilet_bladder_remaining(bladder_capacity)


func _save_bladder_state() -> void:
	GameManager.set_toilet_bladder_remaining(_bladder_remaining, bladder_capacity)


func _is_bladder_empty() -> bool:
	return _get_bladder_percent() <= _BLADDER_EMPTY_EPSILON


func _update_empty_bladder_thought() -> void:
	if _state != State.IDLE or not _is_bathroom_accessible():
		if _was_in_empty_proximity:
			_was_in_empty_proximity = false
		return
	if _interactable == null:
		return
	var in_proximity := _interactable.is_player_in_proximity()
	if in_proximity and not _was_in_empty_proximity:
		_was_in_empty_proximity = true
		var thought := ""
		if GameManager.get_flag("bathroom_sink_horror_done"):
			thought = post_sequence_thought
		elif _is_bladder_empty():
			thought = wash_hands_thought if GameManager.get_flag(_WANTS_SINK_FLAG) else empty_bladder_thought
		else:
			return
		InnerThoughts.show_thought(thought)
	elif not in_proximity and _was_in_empty_proximity:
		_was_in_empty_proximity = false
		InnerThoughts.hide_thought()


func _on_toilet_minigame_exit() -> void:
	GameManager.set_flag(_WANTS_SINK_FLAG, true)
	_set_bathroom_blocker_enabled(true)
	if _is_bladder_empty():
		InnerThoughts.show_thought(wash_hands_thought)
	else:
		InnerThoughts.show_thought(wash_hands_partial_thought)
	_start_wash_hands_reminder()


func _setup_wash_hands_reminder_timer() -> void:
	if _wash_hands_reminder_timer != null:
		return
	_wash_hands_reminder_timer = Timer.new()
	_wash_hands_reminder_timer.one_shot = true
	_wash_hands_reminder_timer.autostart = false
	add_child(_wash_hands_reminder_timer)
	_wash_hands_reminder_timer.timeout.connect(_on_wash_hands_reminder_timeout)


func _start_wash_hands_reminder() -> void:
	_setup_wash_hands_reminder_timer()
	if _wash_hands_reminder_timer == null:
		return
	if GameManager.get_flag("bathroom_sink_horror_done"):
		return
	if _state != State.IDLE or not GameManager.get_flag(_WANTS_SINK_FLAG):
		return
	_wash_hands_reminder_timer.stop()
	_wash_hands_reminder_timer.start(wash_hands_reminder_interval)


func _stop_wash_hands_reminder() -> void:
	if _wash_hands_reminder_timer != null:
		_wash_hands_reminder_timer.stop()


func _on_wash_hands_reminder_timeout() -> void:
	if _state != State.IDLE or not GameManager.get_flag(_WANTS_SINK_FLAG):
		_stop_wash_hands_reminder()
		return
	if GameManager.get_flag("bathroom_sink_horror_done") or GameManager.minigame_active:
		_stop_wash_hands_reminder()
		return
	InnerThoughts.show_thought(wash_hands_thought)
	_start_wash_hands_reminder()


func _set_bathroom_blocker_enabled(enabled: bool) -> void:
	if bathroom_blocker_wall_path.is_empty():
		return
	var wall := _resolve_scene_node(bathroom_blocker_wall_path) as Node
	if wall == null:
		return
	if wall.has_method("set_wall_enabled"):
		wall.call("set_wall_enabled", enabled)
	else:
		wall.set("wall_enabled", enabled)


func _resolve_scene_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var local := get_node_or_null(path)
	if local != null:
		return local
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null(path)


func _get_bladder_drain_rate() -> float:
	if bladder_drain_duration <= 0.0:
		return bladder_capacity
	return bladder_capacity / bladder_drain_duration


func _get_bladder_percent() -> float:
	if bladder_capacity <= 0.0:
		return 0.0
	return clampf(_bladder_remaining / bladder_capacity * 100.0, 0.0, 100.0)


func _update_bladder_ui() -> void:
	var pct := _get_bladder_percent()
	if _bladder_label != null:
		var fmt := tr("UI_BLADDER_FMT")
		if "%d" not in fmt:
			fmt = "Vejiga: %d%%"
		_bladder_label.text = fmt % int(round(pct))
	if _bladder_bar != null:
		_bladder_bar.max_value = 100.0
		_bladder_bar.value = pct


func _reset_nozzle_angles() -> void:
	_nozzle_yaw_deg = default_nozzle_yaw_deg
	_nozzle_pitch_deg = default_nozzle_pitch_deg


func _apply_nozzle_aim(relative: Vector2) -> void:
	_nozzle_yaw_deg = clampf(
		_nozzle_yaw_deg - relative.x * nozzle_sensitivity,
		-nozzle_yaw_limit_deg,
		nozzle_yaw_limit_deg
	)
	_nozzle_pitch_deg = clampf(
		_nozzle_pitch_deg - relative.y * nozzle_sensitivity,
		-nozzle_pitch_limit_deg,
		nozzle_pitch_limit_deg
	)
	_apply_nozzle_rotation()


func _apply_nozzle_rotation() -> void:
	if _nozzle == null:
		return
	_nozzle.rotation_degrees = Vector3(_nozzle_pitch_deg, _nozzle_yaw_deg, 0.0)


func _start_spray() -> void:
	if _state != State.ACTIVE or _is_bladder_empty():
		return
	_spraying = true
	_set_particles_emitting(true)
	if _stream_player == null or _stream_player.stream == null:
		return
	if not _stream_player.playing:
		_stream_player.play()


func _stop_spray() -> void:
	_spraying = false
	_set_particles_emitting(false)
	if _stream_player != null:
		_stream_player.stop()


func _set_particles_emitting(emitting: bool) -> void:
	if _particles != null:
		_particles.emitting = emitting


func _play_zipper_down_once() -> void:
	_play_audio_once(_zipper_down_player)


func _play_zipper_up_once() -> void:
	_play_audio_once(_zipper_up_player)


func _play_audio_once(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()


func _on_stream_player_finished() -> void:
	if _spraying and not _is_bladder_empty() and _stream_player != null:
		_stream_player.play()


func _update_active_controls(delta: float) -> void:
	if InputHints.is_gamepad():
		var device_id := 0
		var pads := Input.get_connected_joypads()
		if not pads.is_empty():
			device_id = int(pads[0])
		var aim := Vector2(
			Input.get_joy_axis(device_id, JoyAxis.JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(device_id, JoyAxis.JOY_AXIS_RIGHT_Y)
		)
		if aim.length() > 0.2:
			_apply_nozzle_aim(aim * nozzle_sensitivity * 120.0 * delta)
		if Input.is_action_pressed("interact") and not _is_bladder_empty():
			if not _spraying:
				_start_spray()
		elif _spraying:
			_stop_spray()


func _aim_hint_text() -> String:
	var exit_label := InputHints.label_menu_back() if InputHints.is_gamepad() else "[E]"
	if Settings.get_locale() == "en":
		return "%s · %s to leave" % [InputHints.label_spray_hold(), exit_label]
	return "%s · %s para salir" % [InputHints.label_spray_hold(), exit_label]


func _exit_prompt() -> String:
	if InputHints.is_gamepad():
		if Settings.get_locale() == "en":
			return "Press %s to leave" % InputHints.label_menu_back()
		return "Presiona %s para salir" % InputHints.label_menu_back()
	return prompt_exit

