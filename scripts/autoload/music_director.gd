extends Node

const INTRO_MUSIC := preload("res://assets/audio/horrorMusic/intro de demo.mp3")
const AMBIENCE_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/horrorMusic/horror-ambience-1.mp3"),
	preload("res://assets/audio/horrorMusic/horror-ambience-2.mp3"),
	preload("res://assets/audio/horrorMusic/horror-ambience-3.mp3"),
	preload("res://assets/audio/horrorMusic/horror-ambience-4.mp3"),
	preload("res://assets/audio/horrorMusic/horror-ambience-5.mp3"),
	preload("res://assets/audio/horrorMusic/horror-ambience-6.mp3"),
	preload("res://assets/audio/horrorMusic/horror-ambience-7.mp3"),
]

@export_range(1.0, 120.0, 0.5) var ambience_restart_delay: float = 30.0

enum Mode {
	NONE,
	INTRO,
	AMBIENCE,
	TENSION,
}

var _player: AudioStreamPlayer
var _restart_timer: Timer
var _mode: Mode = Mode.NONE
var _last_ambience_index: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.name = "MusicStreamPlayer"
	_player.bus = &"Music"
	_player.finished.connect(_on_player_finished)
	add_child(_player)

	_restart_timer = Timer.new()
	_restart_timer.one_shot = true
	_restart_timer.autostart = false
	_restart_timer.timeout.connect(_on_restart_timer_timeout)
	add_child(_restart_timer)


func play_intro_music_once() -> void:
	_stop_and_reset()
	_mode = Mode.INTRO
	if INTRO_MUSIC == null:
		return
	_player.stream = INTRO_MUSIC
	_player.play()


func play_ambience() -> void:
	if _mode == Mode.TENSION:
		return
	_mode = Mode.AMBIENCE
	_restart_timer.stop()
	if _player.playing:
		return
	_play_next_ambience_track()


func stop_music() -> void:
	_stop_and_reset()


func enter_tension() -> void:
	_mode = Mode.TENSION
	_restart_timer.stop()
	if _player.playing:
		_player.stop()


func exit_tension_and_resume_ambient(delay_seconds: float = 30.0) -> void:
	_mode = Mode.NONE
	_restart_timer.stop()
	_queue_ambient_restart(maxf(delay_seconds, 0.0))


func is_in_tension() -> bool:
	return _mode == Mode.TENSION


func is_playing_ambient() -> bool:
	return _mode == Mode.AMBIENCE and _player.playing


func _play_next_ambience_track() -> void:
	if _mode != Mode.AMBIENCE:
		return
	var track := _pick_next_ambience_track()
	if track == null:
		return
	_player.stream = track
	_player.play()


func _pick_next_ambience_track() -> AudioStream:
	if AMBIENCE_TRACKS.is_empty():
		return null
	var index := _rng.randi_range(0, AMBIENCE_TRACKS.size() - 1)
	if AMBIENCE_TRACKS.size() > 1 and index == _last_ambience_index:
		index = (index + 1) % AMBIENCE_TRACKS.size()
	_last_ambience_index = index
	return AMBIENCE_TRACKS[index]


func _queue_ambient_restart(delay_seconds: float) -> void:
	if _mode == Mode.TENSION:
		return
	if delay_seconds <= 0.0:
		call_deferred("play_ambience")
		return
	_restart_timer.start(delay_seconds)


func _on_player_finished() -> void:
	if _mode == Mode.INTRO:
		_mode = Mode.NONE
		return
	if _mode == Mode.AMBIENCE:
		_queue_ambient_restart(ambience_restart_delay)


func _on_restart_timer_timeout() -> void:
	if _mode == Mode.TENSION:
		return
	play_ambience()


func _stop_and_reset() -> void:
	_restart_timer.stop()
	if _player != null:
		_player.stop()
	_mode = Mode.NONE
