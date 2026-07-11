extends Node
class_name Scene6FinalPresentation
## Audio 2D/3D y viñeta de la escena 6 final.

enum ScreamSound {
	MONSTER_SCREECH,
	DRAGON_ROAR,
}

const DEFAULT_EATING := preload("res://assets/audio/SFX/others/creature-eating.mp3")
const DEFAULT_SCREECH := preload("res://assets/audio/SFX/monsterRoar/monster-screech.mp3")
const DEFAULT_ROAR := preload("res://assets/audio/SFX/monsterRoar/dragon-roar.mp3")
const DEFAULT_CHASE_MUSIC := preload("res://assets/audio/horrorMusic/fearstofathom_humpscare.mp3")
const DEFAULT_HEARTBEAT := preload("res://assets/audio/horrorMusic/heartbeat.mp3")
const DEFAULT_CHASE_FOOTSTEPS: Array[AudioStream] = [
	preload("res://assets/audio/SFX/scene6-footsteps/heavy-walking-footsteps-1.mp3"),
	preload("res://assets/audio/SFX/scene6-footsteps/heavy-walking-footsteps-2.mp3"),
	preload("res://assets/audio/SFX/scene6-footsteps/heavy-walking-footsteps-3.mp3"),
	preload("res://assets/audio/SFX/scene6-footsteps/heavy-walking-footsteps-4.mp3"),
	preload("res://assets/audio/SFX/scene6-footsteps/heavy-walking-footsteps-5.mp3"),
]
const SCARY_BUS := &"Scary"

@export_group("Música")
@export var play_ambience_on_zone_unlock: bool = true
@export var stop_music_on_wall_cross: bool = true

@export_group("Silencio (latidos)")
@export var play_heartbeat_on_wall_cross: bool = true
@export var heartbeat_sound: AudioStream = DEFAULT_HEARTBEAT
@export_range(-12.0, 6.0, 0.5) var heartbeat_volume_db: float = -4.0

@export_group("Masticar (3D)")
@export var eating_sound: AudioStream = DEFAULT_EATING
@export_range(-6.0, 24.0, 0.5) var eating_volume_db: float = 16.0
@export_range(4.0, 64.0, 0.5) var eating_max_distance: float = 40.0
@export_range(0.5, 24.0, 0.25) var eating_unit_size: float = 12.0
@export_range(0.2, 0.8, 0.05) var eating_stop_standup_fraction: float = 0.5

@export_group("Grito (2D)")
@export var scream_sound_choice: ScreamSound = ScreamSound.MONSTER_SCREECH
@export var monster_screech: AudioStream = DEFAULT_SCREECH
@export var dragon_roar: AudioStream = DEFAULT_ROAR
@export_range(-12.0, 12.0, 0.5) var scream_volume_db: float = 4.0

@export_group("Grito (cámara)")
@export var scream_camera_shake_enabled: bool = true
@export_range(0.0, 2.0, 0.05) var scream_shake_rotation_strength: float = 0.4
@export_range(0.0, 0.05, 0.001) var scream_shake_position_strength: float = 0.008
@export_range(1.0, 20.0, 0.5) var scream_shake_frequency: float = 9.0
@export_range(0.05, 2.0, 0.05) var scream_shake_fade_in_time: float = 0.35
@export_range(0.05, 2.0, 0.05) var scream_shake_fade_out_time: float = 0.30

@export_group("Persecución")
@export var chase_music: AudioStream = DEFAULT_CHASE_MUSIC
@export_range(-12.0, 6.0, 0.5) var chase_music_volume_db: float = -4.0

@export_group("Pasos (persecución 3D)")
@export var chase_footstep_sounds: Array[AudioStream] = DEFAULT_CHASE_FOOTSTEPS.duplicate()
@export_range(0.12, 1.0, 0.01) var chase_footstep_interval: float = 0.36
@export_range(0.5, 2.0, 0.05) var chase_footstep_interval_scale: float = 1.0
@export_range(-12.0, 18.0, 0.5) var chase_footsteps_volume_db: float = 6.0
@export_range(4.0, 64.0, 0.5) var chase_footsteps_max_distance: float = 42.0
@export_range(0.5, 24.0, 0.25) var chase_footsteps_unit_size: float = 10.0
@export_range(0.85, 1.2, 0.01) var chase_footstep_pitch_jitter: float = 1.05

@export_group("Persecución (cámara al correr)")
@export var chase_run_shake_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var chase_run_shake_rotation_strength: float = 0.12
@export_range(0.0, 0.02, 0.001) var chase_run_shake_position_strength: float = 0.003
@export_range(1.0, 20.0, 0.5) var chase_run_shake_frequency: float = 8.0
@export_range(0.05, 1.0, 0.05) var chase_run_shake_fade_in_time: float = 0.2
@export_range(0.05, 1.0, 0.05) var chase_run_shake_fade_out_time: float = 0.18

@export_group("Viñeta")
@export var found_footage_filter_path: NodePath
@export_range(0.0, 1.0, 0.01) var chase_vignette_target: float = 0.42
@export_range(0.0, 1.0, 0.01) var chase_softness_target: float = 0.42
@export_range(0.1, 2.0, 0.05) var chase_vignette_fade_seconds: float = 0.65

var _eating_player: AudioStreamPlayer3D
var _scream_player: AudioStreamPlayer
var _heartbeat_player: AudioStreamPlayer
var _chase_music_player: AudioStreamPlayer
var _footsteps_player: AudioStreamPlayer3D
var _monster_anchor: Node3D
var _zone_started: bool = false
var _chase_presentation_active: bool = false
var _eating_stop_generation: int = 0
var _scream_presentation_running: bool = false
var _footstep_cycle_generation: int = 0
var _footstep_index: int = 0
var _chase_footsteps_active: bool = false
var _chase_run_shake_active: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# OPTIMIZACIÓN: _process solo sincroniza posición de audio del monstruo y el shake de
	# la persecución, que no existen hasta la escena final. Sin audio reproduciéndose,
	# _sync_monster_3d_audio() hace early-return y _chase_footsteps_active es false, así que
	# _process no hacía nada útil durante TODA la demo. Lo activamos al empezar la escena
	# final (begin_zone / begin_chase_footsteps). Comportamiento idéntico.
	set_process(false)
	call_deferred("_build_audio_players")


func begin_zone(monster: Node3D) -> void:
	if _zone_started:
		_update_eating_anchor(monster)
		return
	_zone_started = true
	set_process(true)  # OPTIMIZACIÓN: empieza el audio del monstruo → activar sync por frame.
	_update_eating_anchor(monster)
	if play_ambience_on_zone_unlock:
		MusicDirector.play_ambience()
	call_deferred("_start_eating_loop")


func on_wall_crossed() -> void:
	if stop_music_on_wall_cross:
		MusicDirector.stop_music()
	if play_heartbeat_on_wall_cross:
		_start_heartbeat_loop()


func notify_standup_started(monster: Node3D, standup_animation: StringName = &"") -> void:
	_schedule_eating_stop_at_standup_midpoint(monster, standup_animation)


func begin_scream_moment() -> void:
	if _chase_presentation_active:
		return
	_chase_presentation_active = true
	_stop_heartbeat()
	_apply_chase_vignette(true)
	if _scream_presentation_running:
		return
	_scream_presentation_running = true
	_run_scream_presentation()


func _run_scream_presentation() -> void:
	_start_scream_camera_shake()
	await _play_scream_and_wait()
	_stop_scream_camera_shake()
	_scream_presentation_running = false


func begin_chase_music() -> void:
	_start_chase_music()


func begin_chase_footsteps(monster: Node3D, interval_scale: float = 1.0) -> void:
	_monster_anchor = monster
	chase_footstep_interval_scale = maxf(interval_scale, 0.1)
	set_process(true)  # OPTIMIZACIÓN: empiezan pasos/temblor de persecución → activar sync por frame.
	_chase_footsteps_active = true
	_footstep_cycle_generation += 1
	_run_chase_footstep_cycle(_footstep_cycle_generation)


func stop_chase_footsteps() -> void:
	_chase_footsteps_active = false
	_footstep_cycle_generation += 1
	if _footsteps_player != null and _footsteps_player.playing:
		_footsteps_player.stop()
	_stop_chase_run_shake()


func stop_chase_presentation() -> void:
	stop_chase_footsteps()
	if _chase_music_player != null and _chase_music_player.playing:
		_chase_music_player.stop()


func _process(_delta: float) -> void:
	_sync_monster_3d_audio(_eating_player, 1.0)
	_sync_monster_3d_audio(_footsteps_player, 0.15)
	if _chase_footsteps_active:
		_update_chase_run_shake()


func _sync_monster_3d_audio(player: AudioStreamPlayer3D, height_offset: float) -> void:
	if player == null or not player.is_inside_tree() or not player.playing:
		return
	if _monster_anchor == null or not is_instance_valid(_monster_anchor) or not _monster_anchor.is_inside_tree():
		return
	player.global_position = _monster_anchor.global_position + Vector3(0.0, height_offset, 0.0)


func _build_audio_players() -> void:
	_eating_player = AudioStreamPlayer3D.new()
	_eating_player.name = "CreatureEating3D"
	_eating_player.bus = &"SFX"
	_eating_player.volume_db = eating_volume_db
	_eating_player.max_distance = eating_max_distance
	_eating_player.unit_size = eating_unit_size
	_eating_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	var audio_parent: Node = get_parent()
	if audio_parent == null:
		audio_parent = self
	audio_parent.call_deferred("add_child", _eating_player)

	_footsteps_player = AudioStreamPlayer3D.new()
	_footsteps_player.name = "CreatureFootsteps3D"
	_footsteps_player.bus = &"SFX"
	_footsteps_player.volume_db = chase_footsteps_volume_db
	_footsteps_player.max_distance = chase_footsteps_max_distance
	_footsteps_player.unit_size = chase_footsteps_unit_size
	_footsteps_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if audio_parent == null:
		audio_parent = get_parent()
	if audio_parent == null:
		audio_parent = self
	audio_parent.call_deferred("add_child", _footsteps_player)

	_scream_player = AudioStreamPlayer.new()
	_scream_player.name = "MonsterScream2D"
	_scream_player.bus = SCARY_BUS
	_scream_player.volume_db = scream_volume_db
	add_child(_scream_player)

	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.name = "Scene6Heartbeat"
	_heartbeat_player.bus = SCARY_BUS
	_heartbeat_player.volume_db = heartbeat_volume_db
	add_child(_heartbeat_player)

	_chase_music_player = AudioStreamPlayer.new()
	_chase_music_player.name = "Scene6ChaseMusic"
	_chase_music_player.bus = SCARY_BUS
	_chase_music_player.volume_db = chase_music_volume_db
	_chase_music_player.finished.connect(_on_chase_music_finished)
	add_child(_chase_music_player)


func _update_eating_anchor(monster: Node3D) -> void:
	_monster_anchor = monster
	if _eating_player == null or not _eating_player.is_inside_tree():
		return
	if monster != null and is_instance_valid(monster) and monster.is_inside_tree():
		_eating_player.global_position = monster.global_position + Vector3(0.0, 1.0, 0.0)


func _start_eating_loop() -> void:
	if _eating_player == null or eating_sound == null:
		return
	if not _eating_player.is_inside_tree():
		call_deferred("_start_eating_loop")
		return
	var looped := _make_looping_stream(eating_sound)
	_eating_player.stream = looped
	if _monster_anchor != null and _monster_anchor.is_inside_tree():
		_eating_player.global_position = _monster_anchor.global_position + Vector3(0.0, 1.0, 0.0)
	if not _eating_player.playing:
		_eating_player.play()


func _stop_eating() -> void:
	if _eating_player != null and _eating_player.playing:
		_eating_player.stop()


func _schedule_eating_stop_at_standup_midpoint(
	monster: Node3D,
	standup_animation: StringName
) -> void:
	_eating_stop_generation += 1
	var generation := _eating_stop_generation
	var delay := _get_animation_fraction_delay(monster, standup_animation, eating_stop_standup_fraction)
	_run_eating_stop_after_delay(generation, delay)


func _run_eating_stop_after_delay(generation: int, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if generation != _eating_stop_generation:
		return
	_stop_eating()


func _get_animation_fraction_delay(
	monster: Node3D,
	anim_name: StringName,
	fraction: float
) -> float:
	if monster == null:
		return 0.0
	var animation_player := monster.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		return 0.0
	var anim_key := String(anim_name)
	if anim_key.is_empty() or not animation_player.has_animation(anim_key):
		return 0.0
	var anim := animation_player.get_animation(anim_key)
	if anim == null:
		return 0.0
	return anim.length * clampf(fraction, 0.0, 1.0)


func _start_heartbeat_loop() -> void:
	if _heartbeat_player == null or heartbeat_sound == null:
		return
	_heartbeat_player.stream = _make_looping_stream(heartbeat_sound)
	_heartbeat_player.volume_db = heartbeat_volume_db
	if not _heartbeat_player.playing:
		_heartbeat_player.play()


func _stop_heartbeat() -> void:
	if _heartbeat_player != null and _heartbeat_player.playing:
		_heartbeat_player.stop()


func _play_scream_and_wait() -> void:
	if _scream_player == null:
		return
	var stream := _resolve_scream_stream()
	if stream == null:
		return
	_scream_player.stream = stream
	_scream_player.volume_db = scream_volume_db
	_scream_player.play()
	if _scream_player.playing:
		await _scream_player.finished


func _start_scream_camera_shake() -> void:
	if not scream_camera_shake_enabled:
		return
	var player := GameManager.get_player()
	if player == null or not player.has_method("start_nervous_camera_shake"):
		return
	player.start_nervous_camera_shake(
		scream_shake_rotation_strength,
		scream_shake_position_strength,
		scream_shake_frequency,
		scream_shake_fade_in_time
	)


func _stop_scream_camera_shake() -> void:
	if not scream_camera_shake_enabled:
		return
	var player := GameManager.get_player()
	if player == null:
		return
	if player.has_method("force_clear_nervous_camera_shake"):
		player.force_clear_nervous_camera_shake()
	elif player.has_method("stop_nervous_camera_shake"):
		player.stop_nervous_camera_shake(scream_shake_fade_out_time)


func _start_chase_music() -> void:
	if _chase_music_player == null or chase_music == null:
		return
	_chase_music_player.stream = _make_looping_stream(chase_music)
	_chase_music_player.volume_db = chase_music_volume_db
	_chase_music_player.play()


func _run_chase_footstep_cycle(generation: int) -> void:
	var sounds := _resolve_footstep_sounds()
	if sounds.is_empty() or _footsteps_player == null:
		return
	if not _footsteps_player.is_inside_tree():
		call_deferred("_run_chase_footstep_cycle", generation)
		return
	_footstep_index = 0
	while generation == _footstep_cycle_generation:
		var stream := sounds[_footstep_index]
		_play_one_chase_footstep(stream)
		_footstep_index = (_footstep_index + 1) % sounds.size()
		await get_tree().create_timer(_get_chase_footstep_interval()).timeout
		if generation != _footstep_cycle_generation:
			return


func _get_chase_footstep_interval() -> float:
	return maxf(chase_footstep_interval * chase_footstep_interval_scale, 0.08)


func _play_one_chase_footstep(stream: AudioStream) -> void:
	if _footsteps_player == null or stream == null:
		return
	_footsteps_player.stream = stream
	_footsteps_player.volume_db = chase_footsteps_volume_db
	if chase_footstep_pitch_jitter > 0.0:
		_footsteps_player.pitch_scale = randf_range(
			2.0 - chase_footstep_pitch_jitter,
			chase_footstep_pitch_jitter
		)
	else:
		_footsteps_player.pitch_scale = 1.0
	if _monster_anchor != null and is_instance_valid(_monster_anchor) and _monster_anchor.is_inside_tree():
		_footsteps_player.global_position = _monster_anchor.global_position + Vector3(0.0, 0.15, 0.0)
	_footsteps_player.play()


func _resolve_footstep_sounds() -> Array[AudioStream]:
	var resolved: Array[AudioStream] = []
	for stream in chase_footstep_sounds:
		if stream != null:
			resolved.append(stream)
	if resolved.is_empty():
		for stream in DEFAULT_CHASE_FOOTSTEPS:
			resolved.append(stream)
	return resolved


func _update_chase_run_shake() -> void:
	if not chase_run_shake_enabled:
		return
	var player := GameManager.get_player()
	var should_shake := _is_player_chase_sprinting(player)
	if should_shake:
		if not _chase_run_shake_active:
			_start_chase_run_shake()
			_chase_run_shake_active = true
	elif _chase_run_shake_active:
		_stop_chase_run_shake()
		_chase_run_shake_active = false


func _is_player_chase_sprinting(player: Node) -> bool:
	if player == null:
		return false
	var sprint_action := &"sprint"
	if "input_sprint" in player:
		sprint_action = StringName(String(player.get("input_sprint")))
	if not Input.is_action_pressed(sprint_action):
		return false
	if not ("velocity" in player):
		return false
	var velocity: Vector3 = player.get("velocity")
	velocity.y = 0.0
	if velocity.length_squared() < 0.25:
		return false
	if "base_speed" in player:
		return velocity.length() > float(player.get("base_speed")) * 1.05
	return true


func _start_chase_run_shake() -> void:
	var player := GameManager.get_player()
	if player == null or not player.has_method("start_nervous_camera_shake"):
		return
	player.start_nervous_camera_shake(
		chase_run_shake_rotation_strength,
		chase_run_shake_position_strength,
		chase_run_shake_frequency,
		chase_run_shake_fade_in_time
	)


func _stop_chase_run_shake() -> void:
	var player := GameManager.get_player()
	if player == null:
		return
	if player.has_method("stop_nervous_camera_shake"):
		player.stop_nervous_camera_shake(chase_run_shake_fade_out_time)
	elif player.has_method("force_clear_nervous_camera_shake"):
		player.force_clear_nervous_camera_shake()


func _on_chase_music_finished() -> void:
	if not _chase_presentation_active or _chase_music_player == null:
		return
	if _chase_music_player.stream == null:
		return
	_chase_music_player.play()


func _resolve_scream_stream() -> AudioStream:
	match scream_sound_choice:
		ScreamSound.DRAGON_ROAR:
			return dragon_roar if dragon_roar != null else DEFAULT_ROAR
		_:
			return monster_screech if monster_screech != null else DEFAULT_SCREECH


func _apply_chase_vignette(enable: bool) -> void:
	var filter := _resolve_found_footage_filter()
	if filter == null:
		return
	if filter.has_method("animate_chase_vignette"):
		filter.animate_chase_vignette(
			enable,
			chase_vignette_target,
			chase_softness_target,
			chase_vignette_fade_seconds
		)


func _resolve_found_footage_filter() -> Node:
	if not found_footage_filter_path.is_empty():
		var from_path := get_node_or_null(found_footage_filter_path)
		if from_path != null:
			return from_path
	var player := GameManager.get_player()
	if player != null:
		return player.get_node_or_null("FoundFootageFilter")
	return null


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
