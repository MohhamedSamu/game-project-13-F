extends Node
## Escena 4: al desbloquear la puerta del baño con llave, corte eléctrico + apagón breve de farola.

@export var door_path: NodePath
@export var lamp_path: NodePath
@export var power_failure_sound: AudioStream = preload(
	"res://assets/audio/SFX/varios/power-failure.mp3"
)
@export_range(0.5, 10.0, 0.1) var lamp_off_duration: float = 3.0
@export var completion_flag: String = "bathroom_power_failure_done"

var _door: DoorInteractSetup
var _lamp: StreetLampController
var _sfx: AudioStreamPlayer3D
var _sequence_running: bool = false


func _ready() -> void:
	add_to_group("bathroom_door_power_failure")
	call_deferred("_setup")


func _setup() -> void:
	_sfx = get_node_or_null("PowerFailureSFX") as AudioStreamPlayer3D
	if _sfx != null and power_failure_sound != null:
		_sfx.stream = power_failure_sound
		_sfx.bus = &"SFX"

	_door = _resolve_scene_node(door_path) as DoorInteractSetup
	_lamp = _resolve_scene_node(lamp_path) as StreetLampController
	if _door == null or _lamp == null:
		push_warning(
			"BathroomDoorPowerFailureSetup: no se encontró puerta o farola (%s / %s)."
			% [door_path, lamp_path]
		)
		return

	if _is_sequence_already_done():
		_lamp.set_stable()
		return

	if _door.unlocked:
		_lamp.set_stable()
		if not completion_flag.is_empty() and not GameManager.get_flag(completion_flag):
			GameManager.set_flag(completion_flag, true)
		return

	if not _door.first_unlocked.is_connected(_on_door_first_unlocked):
		_door.first_unlocked.connect(_on_door_first_unlocked, CONNECT_ONE_SHOT)


func _is_sequence_already_done() -> bool:
	return not completion_flag.is_empty() and GameManager.get_flag(completion_flag)


func _on_door_first_unlocked() -> void:
	on_bathroom_door_unlocked()


func on_bathroom_door_unlocked() -> void:
	_run_sequence()


func _run_sequence() -> void:
	if _sequence_running or _is_sequence_already_done():
		return
	_sequence_running = true
	MusicDirector.enter_tension()

	await _wait_for_lamp_ready()

	_play_power_failure_sound()

	if is_instance_valid(_lamp):
		_lamp.set_off()

	await get_tree().create_timer(lamp_off_duration).timeout

	if is_instance_valid(_lamp):
		_lamp.set_stable()

	if not completion_flag.is_empty():
		GameManager.set_flag(completion_flag, true)

	_sequence_running = false


func _play_power_failure_sound() -> void:
	if _sfx == null or _sfx.stream == null:
		return
	_sfx.stop()
	_sfx.play()


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


func _wait_for_lamp_ready() -> void:
	if _lamp == null:
		return
	while is_instance_valid(_lamp) and _lamp.has_method("is_controller_ready"):
		if _lamp.is_controller_ready():
			return
		await get_tree().process_frame
