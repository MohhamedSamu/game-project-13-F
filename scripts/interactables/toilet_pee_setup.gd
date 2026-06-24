@tool
class_name ToiletPeeSetup
extends Node3D
## Minijuego de inodoro (opción A): cámara fija externa, fade a negro, chorro con partículas.

enum State { IDLE, ENTERING, ACTIVE, EXITING }

const _FOCUS_PREVIEW_COLOR := Color(0.35, 0.78, 1.0, 0.38)
const _PROXIMITY_PREVIEW_COLOR := Color(0.45, 0.95, 0.55, 0.16)

@export_group("Cámara")
## Cámara fija colocada en el nivel padre (configurable desde el inspector).
@export var fixed_camera_path: NodePath

@export_group("Interacción")
@export var prompt_enter: String = "Presiona [E] para usar el inodoro"
@export var prompt_exit: String = "Presiona [E] para salir"
@export var aim_hint: String = "Mantén click izquierdo"
## Centro de la cúpula de interacción (offset local).
@export var focus_offset: Vector3 = Vector3(0.0, 0.45, 0.0):
	set(value):
		focus_offset = value
		_request_rebuild()
## Radio de la cúpula donde la mira activa el raycast (como FocusHitbox del payaso).
@export_range(0.2, 3.0, 0.05) var focus_radius: float = 0.9:
	set(value):
		focus_radius = maxf(value, 0.1)
		_request_rebuild()
## Radio de proximidad para poder interactuar (cúpula exterior).
@export_range(0.5, 6.0, 0.05) var proximity_radius: float = 2.2:
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

@export_group("Vejiga (futuro)")
@export var bladder_capacity: float = 100.0
@export var show_bladder_ui: bool = true

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
var _aim_label: Label
var _zipper_down_player: AudioStreamPlayer
var _zipper_up_player: AudioStreamPlayer
var _stream_player: AudioStreamPlayer


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
	_bladder_remaining = bladder_capacity
	_reset_nozzle_angles()
	_set_particles_emitting(false)
	_set_overlay_visible(false)
	if _stream_player != null:
		_stream_player.finished.connect(_on_stream_player_finished)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_READY:
		_update_preview_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.ACTIVE:
		return
	if event.is_action_pressed("interact"):
		_request_exit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_apply_nozzle_aim(event.relative)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
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
	_update_bladder_label()


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
	var visible := Engine.is_editor_hint() and show_editor_preview
	if _editor_focus_preview != null:
		_editor_focus_preview.visible = visible
	if _editor_proximity_preview != null:
		_editor_proximity_preview.visible = visible


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
	return _state == State.IDLE


func get_interaction_prompt() -> String:
	if _state == State.ACTIVE:
		return prompt_exit
	if _state == State.IDLE:
		return prompt_enter
	return ""


func handle_interaction() -> void:
	if _state == State.IDLE:
		_begin_sequence()


func _begin_sequence() -> void:
	if _state != State.IDLE:
		return
	var camera := _get_fixed_camera()
	if camera == null:
		push_warning("ToiletPeeSetup: asigna fixed_camera_path a una Camera3D del nivel.")
		return

	var player := GameManager.player
	if player == null:
		return

	_state = State.ENTERING
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
	GameManager.unlock_player_minigame()


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


func _set_overlay_visible(visible: bool) -> void:
	if _overlay != null:
		_overlay.visible = visible
	if not visible and _fade_rect != null:
		_set_fade_alpha(0.0)


func _update_hud_labels(active: bool) -> void:
	if _aim_label != null:
		_aim_label.visible = active
		_aim_label.text = aim_hint
	if _bladder_label != null:
		_bladder_label.visible = active and show_bladder_ui
		_update_bladder_label()


func _update_bladder_label() -> void:
	if _bladder_label == null:
		return
	var pct := 0.0
	if bladder_capacity > 0.0:
		pct = clampf(_bladder_remaining / bladder_capacity * 100.0, 0.0, 100.0)
	_bladder_label.text = "Vejiga: %d%%" % int(round(pct))


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
	if _state != State.ACTIVE:
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
	if _spraying and _stream_player != null:
		_stream_player.play()
