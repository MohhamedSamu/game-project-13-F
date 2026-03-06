extends Node


const ENTER_SFX = preload("res://assets/audio/menu/enter.ogg")
const BACK_SFX  = preload("res://assets/audio/menu/back.ogg")
const CHANGE_SFX = preload("res://assets/audio/menu/audio_test.ogg")

@export var enter_stream: AudioStream
@export var back_stream: AudioStream
@export var change_stream: AudioStream  # el beep de sliders

var _enter: AudioStreamPlayer
var _back: AudioStreamPlayer
var _change: AudioStreamPlayer

func _ready() -> void:
	_enter = AudioStreamPlayer.new()
	_back = AudioStreamPlayer.new()
	_change = AudioStreamPlayer.new()

	# Bus por defecto (puedes cambiar)
	_enter.bus = "SFX"
	_back.bus = "SFX"
	_change.bus = "SFX"

	add_child(_enter)
	add_child(_back)
	add_child(_change)

	_enter.stream = ENTER_SFX
	_back.stream = BACK_SFX
	_change.stream = CHANGE_SFX

func play_enter() -> void:
	if _enter.stream:
		_enter.stop()
		_enter.play()

func play_back() -> void:
	if _back.stream:
		_back.stop()
		_back.play()

func play_change_on_bus(bus_name: String) -> void:
	if _change.stream:
		_change.bus = bus_name
		_change.stop()
		_change.play()
