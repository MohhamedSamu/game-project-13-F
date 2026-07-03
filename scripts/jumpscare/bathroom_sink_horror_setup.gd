class_name BathroomSinkHorrorSetup
extends Node3D
## Secuencia de susto en lavamanos: cámara fija en HorrorCamera, mira cada stream marker, chorros y parpadeo.

const WANTS_SINK_FLAG := &"wants_bathroom_sink"
const COMPLETION_FLAG := &"bathroom_sink_horror_done"

@export_group("Interacción")
@export var prompt_text: String = "Presiona [E] para lavarte las manos"
@export var bathroom_door_path: NodePath
@export var bathroom_blocker_wall_path: NodePath

@export_group("Referencias")
@export var horror_camera_path: NodePath = ^"HorrorCamera"
@export var stream_markers_parent_path: NodePath = ^"StreamMarkers"
@export var light_flicker_path: NodePath = ^"LightFlicker"
@export var creature_path: NodePath = ^"W3_001"

@export_group("Orden de lavabos")
@export var sink_order: Array[StringName] = [&"Center", &"Right", &"Left"]

@export_group("Pensamientos")
@export var first_stream_thought: String = "¿qué? ¿qué es esto? ...."
@export var second_stream_thought: String = "¿esto es sangre?????"
@export var flee_thought: String = "no sé qué era eso, solo pensé en huir"
@export_range(2.0, 12.0, 0.5) var thought_duration: float = 4.0

@export_group("Criatura")
@export var creature_start_position: Vector3 = Vector3(-7.025, 1.313, 0.438)
@export var creature_end_position: Vector3 = Vector3(-4.87, 1.313, 0.438)
@export_range(0.5, 5.0, 0.1) var creature_move_duration: float = 2.0
@export_range(0.0, 1.5, 0.05) var creature_camera_reaction_delay: float = 0.4

@export_group("Clímax izquierda")
@export var align_player_look_on_exit: bool = true
@export_range(5.0, 45.0, 1.0) var left_extra_yaw_degrees: float = 20.0
@export_range(0.3, 4.0, 0.05) var left_extra_yaw_duration: float = 2.0
@export_range(0.2, 3.0, 0.05) var screen_shake_duration: float = 1.2
@export_range(0.005, 0.08, 0.001) var screen_shake_rotation_deg: float = 0.035

@export_group("Persecución")
@export_range(1.0, 20.0, 0.5) var pursuit_duration: float = 12.0
@export_range(0.2, 4.0, 0.05) var pursuit_travel_distance: float = 2.0
@export_range(0.0, 3.0, 0.05) var pursuit_pause_seconds: float = 1.0
@export var pursuit_sound: AudioStream

@export_group("Audio")
@export var faucet_open_sound: AudioStream = preload(
	"res://assets/audio/SFX/scene4scare/faucet-1.mp3"
)
@export var faucet_loop_sound: AudioStream = preload(
	"res://assets/audio/SFX/scene4scare/faucet-2-repeat.mp3"
)
@export var demon_voices_sound: AudioStream = preload(
	"res://assets/audio/SFX/scene4scare/demon-voices.mp3"
)
@export var demonic_laughter_sound: AudioStream = preload(
	"res://assets/audio/SFX/scene4scare/voice-demonic-laughter.mp3"
)

@export_group("Tiempos")
@export_range(0.2, 3.0, 0.05) var intro_hold_duration: float = 0.65
@export_range(0.3, 4.0, 0.05) var camera_move_duration: float = 1.15
@export_range(0.1, 2.0, 0.05) var tap_delay_duration: float = 0.45
@export_range(0.5, 8.0, 0.1) var stream_duration: float = 2.4

@export_group("Iluminación")
@export_range(0.2, 6.0, 0.1) var horror_light_energy: float = 0.4
@export var horror_light_color: Color = Color(1.0, 0.78, 0.72, 1.0)
@export_range(0.05, 1.0, 0.05) var flicker_max_energy_multiplier: float = 0.28
@export_range(0.01, 0.6, 0.01) var flicker_min_energy_multiplier: float = 0.06

var _camera: Camera3D
var _stream_markers: Node3D
var _light_flicker: DamagedLightFlicker
var _creature: Node3D
var _demon_voices_player: AudioStreamPlayer
var _demonic_laughter_player: AudioStreamPlayer
var _pursuit_player: AudioStreamPlayer
var _camera_home_transform: Transform3D
var _sequence_running: bool = false
var _interactable: InteractableDialogueComponent
var _original_bathroom_light_state: Dictionary = {}
var _post_escape_pursuit_running: bool = false
var _post_escape_pursuit_tween: Tween


func _ready() -> void:
	_camera = get_node_or_null(horror_camera_path) as Camera3D
	_stream_markers = get_node_or_null(stream_markers_parent_path) as Node3D
	_light_flicker = get_node_or_null(light_flicker_path) as DamagedLightFlicker
	_creature = get_node_or_null(creature_path) as Node3D
	_demon_voices_player = get_node_or_null("Audio/DemonVoicesPlayer") as AudioStreamPlayer
	_demonic_laughter_player = get_node_or_null("Audio/DemonicLaughterPlayer") as AudioStreamPlayer
	_pursuit_player = get_node_or_null("Audio/PursuitPlayer") as AudioStreamPlayer
	if not is_in_group(&"bathroom_sink_horror"):
		add_to_group(&"bathroom_sink_horror")
	_cache_interaction_refs()
	if _camera != null:
		_camera.current = false
		_camera_home_transform = _camera.transform
	_prepare_creature_hidden()
	if _interactable != null:
		_interactable.prompt_text = prompt_text
	_cache_bathroom_light_state()


func can_handle_interaction() -> bool:
	if not _is_bathroom_accessible():
		return false
	if not GameManager.get_flag(WANTS_SINK_FLAG):
		return false
	return is_sequence_available() and not is_sequence_running()


func get_interaction_prompt() -> String:
	if can_handle_interaction():
		return prompt_text
	return ""


func handle_interaction() -> void:
	if not can_handle_interaction():
		return
	run_sequence()


func is_sequence_available() -> bool:
	if GameManager.get_flag(COMPLETION_FLAG):
		return false
	return GameManager.get_flag(WANTS_SINK_FLAG)


func is_sequence_running() -> bool:
	return _sequence_running


func run_sequence() -> void:
	if _sequence_running or not is_sequence_available():
		return
	if _camera == null or _stream_markers == null:
		push_warning("BathroomSinkHorrorSetup: faltan cámara o stream markers en %s." % get_path())
		return

	var player := GameManager.player
	if player == null:
		return

	_sequence_running = true
	MusicDirector.enter_tension()
	_prepare_creature_hidden()
	GameManager.lock_player_minigame()
	if player.has_method("set_minigame_body_visible"):
		player.set_minigame_body_visible(false)
	if player.has_method("use_external_camera"):
		player.use_external_camera(_camera)

	_reset_camera_placement()
	_start_light_flicker()
	_play_demon_voices()
	await _play_sink_sequence()

	if is_instance_valid(player):
		if align_player_look_on_exit and _camera != null and player.has_method("apply_look_from_external_camera"):
			player.apply_look_from_external_camera(_camera)
		if player.has_method("restore_player_camera"):
			player.restore_player_camera()
		if player.has_method("set_minigame_body_visible"):
			player.set_minigame_body_visible(true)

	GameManager.set_flag(COMPLETION_FLAG, true)
	get_tree().call_group(&"scene4_bathroom_exit_jumpscare", &"refresh_armed_state")
	GameManager.unlock_player_minigame()
	_set_bathroom_blocker_enabled(false)
	_start_post_escape_pursuit(player)
	_sequence_running = false


func _play_sink_sequence() -> void:
	var first_sink := String(sink_order[0]) if not sink_order.is_empty() else "Center"
	var first_marker := _get_marker(first_sink)
	if first_marker == null:
		return

	_look_at_marker(first_marker)
	await get_tree().create_timer(intro_hold_duration).timeout

	for i in sink_order.size():
		var sink_name := String(sink_order[i])
		var marker := _get_marker(sink_name)
		if marker == null:
			continue
		if i > 0:
			await _tween_look_at(marker, camera_move_duration)
		await get_tree().create_timer(tap_delay_duration).timeout
		_start_stream_at(marker)
		_show_sink_thought(i)

		if sink_name == "Left":
			await _play_left_climax()
			return

		await get_tree().create_timer(stream_duration).timeout


func _show_sink_thought(sink_index: int) -> void:
	match sink_index:
		0:
			if not first_stream_thought.is_empty():
				InnerThoughts.show_thought(first_stream_thought, thought_duration, true)
		1:
			if not second_stream_thought.is_empty():
				InnerThoughts.show_thought(second_stream_thought, thought_duration, true)


func _play_left_climax() -> void:
	await _run_screen_shake(screen_shake_duration)

	var creature_tween := _start_creature_reveal()
	await get_tree().create_timer(creature_camera_reaction_delay).timeout
	await _tween_extra_yaw(left_extra_yaw_degrees, left_extra_yaw_duration)

	if creature_tween != null and creature_tween.is_valid():
		await creature_tween.finished


func _start_creature_reveal() -> Tween:
	if _creature == null:
		return null

	_play_demonic_laughter()
	if not flee_thought.is_empty():
		InnerThoughts.show_thought(flee_thought, thought_duration, true)
	_creature.visible = true
	_creature.position = creature_start_position
	var tween := create_tween()
	tween.tween_property(
		_creature,
		"position",
		creature_end_position,
		creature_move_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func _start_post_escape_pursuit(player: Node3D) -> void:
	_stop_post_escape_pursuit()
	if _creature == null or player == null or not is_instance_valid(player):
		return

	_post_escape_pursuit_running = true
	var forward := _creature.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -Vector3.FORWARD
	forward = forward.normalized()
	var start_pos := _creature.global_position
	var mid_pos := start_pos + forward * (pursuit_travel_distance * 0.5)
	var end_pos := start_pos + forward * pursuit_travel_distance
	var first_duration := maxf((pursuit_duration - pursuit_pause_seconds) * 0.5, 0.05)
	var second_duration := first_duration

	_post_escape_pursuit_tween = create_tween()
	_post_escape_pursuit_tween.set_trans(Tween.TRANS_SINE)
	_post_escape_pursuit_tween.set_ease(Tween.EASE_IN_OUT)
	_post_escape_pursuit_tween.tween_property(_creature, "global_position", mid_pos, first_duration)
	if pursuit_pause_seconds > 0.0:
		_post_escape_pursuit_tween.tween_interval(pursuit_pause_seconds)
	_post_escape_pursuit_tween.tween_property(_creature, "global_position", end_pos, second_duration)

	InnerThoughts.show_thought(flee_thought, pursuit_duration, true)
	if _demon_voices_player != null:
		_demon_voices_player.stop()
	if pursuit_sound != null and _pursuit_player != null:
		_pursuit_player.stream = pursuit_sound
		_pursuit_player.stop()
		_pursuit_player.play()


func _stop_post_escape_pursuit() -> void:
	_post_escape_pursuit_running = false
	if _post_escape_pursuit_tween != null and _post_escape_pursuit_tween.is_valid():
		_post_escape_pursuit_tween.kill()
	_post_escape_pursuit_tween = null
	if _pursuit_player != null:
		_pursuit_player.stop()



func _prepare_creature_hidden() -> void:
	if _creature == null:
		return
	_creature.position = creature_start_position
	_creature.visible = false


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


func _get_marker(sink_name: String) -> Node3D:
	if _stream_markers == null:
		return null
	return _stream_markers.get_node_or_null(NodePath(sink_name)) as Node3D


func _get_emitter(stream_marker: Node3D) -> BloodStreamEmitter:
	for child in stream_marker.get_children():
		if child is BloodStreamEmitter:
			return child as BloodStreamEmitter
	return null


func _reset_camera_placement() -> void:
	if _camera == null:
		return
	_camera.transform = _camera_home_transform


func _look_at_marker(marker: Node3D) -> void:
	if _camera == null or marker == null:
		return
	var look_dir := marker.global_position - _camera.global_position
	if look_dir.length_squared() < 0.0001:
		return
	_camera.look_at(marker.global_position, Vector3.UP)


func _tween_look_at(marker: Node3D, duration: float) -> void:
	if _camera == null or marker == null:
		return
	if duration <= 0.0:
		_look_at_marker(marker)
		return

	var cam_pos := _camera.global_position
	var look_dir := marker.global_position - cam_pos
	if look_dir.length_squared() < 0.0001:
		return

	var from_quat := _camera.global_basis.get_rotation_quaternion()
	var to_basis := Basis.looking_at(look_dir.normalized(), Vector3.UP)
	var to_quat := to_basis.get_rotation_quaternion()
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_camera.global_position = cam_pos
			_camera.global_basis = Basis(from_quat.slerp(to_quat, t)),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _tween_extra_yaw(degrees: float, duration: float) -> void:
	if _camera == null:
		return
	if duration <= 0.0 or absf(degrees) < 0.01:
		return

	var cam_pos := _camera.global_position
	var from_quat := _camera.global_basis.get_rotation_quaternion()
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(degrees))
	var to_quat := (yaw_basis * _camera.global_basis).get_rotation_quaternion()
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_camera.global_position = cam_pos
			_camera.global_basis = Basis(from_quat.slerp(to_quat, t)),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _run_screen_shake(duration: float) -> void:
	if _camera == null or duration <= 0.0:
		return

	var cam_pos := _camera.global_position
	var base_basis := _camera.global_basis
	var elapsed := 0.0
	while elapsed < duration:
		var strength := 1.0 - (elapsed / duration)
		var pitch := deg_to_rad(randf_range(-screen_shake_rotation_deg, screen_shake_rotation_deg) * strength)
		var yaw := deg_to_rad(randf_range(-screen_shake_rotation_deg, screen_shake_rotation_deg) * strength)
		var jitter := Basis.from_euler(Vector3(pitch, yaw, 0.0))
		_camera.global_position = cam_pos
		_camera.global_basis = jitter * base_basis
		await get_tree().process_frame
		elapsed += get_tree().root.get_process_delta_time()

	_camera.global_position = cam_pos
	_camera.global_basis = base_basis


func get_creature_peek_position() -> Vector3:
	if _creature != null and _creature.is_inside_tree():
		return _creature.global_position
	return to_global(creature_end_position)


func clear_horror_presentation() -> void:
	if _creature != null:
		_creature.visible = false
	_stop_post_escape_pursuit()
	_stop_all_streams()
	_stop_all_faucet_audio()
	_stop_horror_audio()
	_stop_light_flicker()
	_restore_bathroom_light_state()
	InnerThoughts.hide_thought()


func _stop_all_streams() -> void:
	if _stream_markers == null:
		return
	for child in _stream_markers.get_children():
		_stop_stream_at(child)


func _stop_stream_at(stream_marker: Node3D) -> void:
	var emitter := _get_emitter(stream_marker)
	if emitter != null:
		emitter.stop_stream()


func _stop_all_faucet_audio() -> void:
	if _stream_markers == null:
		return
	for child in _stream_markers.get_children():
		var player := child.get_node_or_null("FaucetPlayer") as AudioStreamPlayer3D
		if player != null:
			player.stop()


func _stop_horror_audio() -> void:
	if _demon_voices_player != null:
		_demon_voices_player.stop()
	if _demonic_laughter_player != null:
		_demonic_laughter_player.stop()


func _stop_light_flicker() -> void:
	if _light_flicker != null and _light_flicker.has_method("stop_flicker"):
		_light_flicker.stop_flicker(true)


func _start_stream_at(stream_marker: Node3D) -> void:
	var emitter := _get_emitter(stream_marker)
	if emitter != null:
		emitter.start_stream()
	_play_faucet_sound(stream_marker)


func _play_faucet_sound(stream_marker: Node3D) -> void:
	if faucet_open_sound == null or stream_marker == null:
		return

	var player := stream_marker.get_node_or_null("FaucetPlayer") as AudioStreamPlayer3D
	if player == null:
		return

	player.stop()
	player.stream = faucet_open_sound
	player.play()
	player.finished.connect(_on_faucet_intro_finished.bind(player), CONNECT_ONE_SHOT)


func _on_faucet_intro_finished(player: AudioStreamPlayer3D) -> void:
	if faucet_loop_sound == null or player == null:
		return
	player.stream = _make_looping_stream(faucet_loop_sound)
	player.play()


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


func _play_demon_voices() -> void:
	if _demon_voices_player == null:
		return
	if demon_voices_sound != null:
		_demon_voices_player.stream = demon_voices_sound
	_demon_voices_player.bus = &"Music"
	_demon_voices_player.stop()
	_demon_voices_player.play()


func _play_demonic_laughter() -> void:
	if _demonic_laughter_player == null:
		return
	if demonic_laughter_sound != null:
		_demonic_laughter_player.stream = demonic_laughter_sound
	_demonic_laughter_player.bus = &"SFX"
	_demonic_laughter_player.stop()
	_demonic_laughter_player.play()


func _start_light_flicker() -> void:
	_configure_horror_lights()
	if _light_flicker == null:
		return
	if _light_flicker.has_method("ensure_ready"):
		if not _light_flicker.ensure_ready():
			push_warning("BathroomSinkHorrorSetup: no se encontraron luces del baño para parpadeo.")
			return
	_light_flicker.max_energy_multiplier = flicker_max_energy_multiplier
	_light_flicker.min_energy_multiplier = flicker_min_energy_multiplier
	if _light_flicker.has_method("start_flicker"):
		_light_flicker.start_flicker()


func _cache_interaction_refs() -> void:
	var sink_interaction := get_node_or_null("SinkInteraction") as Node3D
	if sink_interaction == null:
		return
	_interactable = sink_interaction.get_node_or_null(
		"InteractableDialogueComponent"
	) as InteractableDialogueComponent


func _is_bathroom_accessible() -> bool:
	if bathroom_door_path.is_empty():
		return true
	var door := _resolve_scene_node(bathroom_door_path) as DoorInteractSetup
	if door == null:
		return true
	return door.opened


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


func _configure_horror_lights() -> void:
	for light_name: StringName in [&"OmniLight3DBath1", &"OmniLight3DBath2"]:
		var light := get_node_or_null(NodePath(String(light_name))) as OmniLight3D
		if light == null:
			continue
		light.light_energy = horror_light_energy
		light.light_color = horror_light_color


func _cache_bathroom_light_state() -> void:
	if not _original_bathroom_light_state.is_empty():
		return

	for light_name: StringName in [&"OmniLight3DBath1", &"OmniLight3DBath2"]:
		var light := get_node_or_null(NodePath(String(light_name))) as OmniLight3D
		if light == null:
			continue
		_original_bathroom_light_state[light.get_instance_id()] = {
			"light": light,
			"energy": light.light_energy,
			"color": light.light_color,
		}


func _restore_bathroom_light_state() -> void:
	if _original_bathroom_light_state.is_empty():
		return

	for entry in _original_bathroom_light_state.values():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var data := entry as Dictionary
		var light := data.get("light") as OmniLight3D
		if light == null:
			continue
		if data.has("energy"):
			light.light_energy = float(data["energy"])
		if data.has("color"):
			light.light_color = data["color"]
