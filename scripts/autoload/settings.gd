extends Node

const SETTINGS_PATH := "user://settings.json"

const DEFAULT_MOUSE_SENSITIVITY := 0.25
const DEFAULT_CAMERA_FOV := 75.0
const MAX_CAMERA_FOV := 90.0
const REFERENCE_LOOK_SPEED := 0.002

enum MovementProfile { PRODUCTION, DEVELOP }

const DEVELOP_WALK_SPEED := 7.0
const DEVELOP_SPRINT_SPEED := 10.0
const DEVELOP_FREEFLY_SPEED := 25.0

const PRODUCTION_WALK_SPEED := 3.0
const PRODUCTION_SPRINT_SPEED := 5.5
const DEVELOP_JUMP_VELOCITY := 4.5
## Mitad de altura que develop: v ∝ sqrt(h) → factor sqrt(0.5).
const PRODUCTION_JUMP_VELOCITY := DEVELOP_JUMP_VELOCITY * 0.7071067811865476

var data := {
	"mouse_sensitivity": DEFAULT_MOUSE_SENSITIVITY,
	"camera_fov": DEFAULT_CAMERA_FOV,
	"movement_profile": "production",
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"fullscreen": false,
}


func _ready() -> void:
	load_settings()
	apply_audio()
	_apply_display()


func set_value(key: String, value) -> void:
	data[key] = value


func get_value(key: String, default_value = null):
	if data.has(key):
		return data[key]
	return default_value


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not open settings file for write: " + SETTINGS_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		save_settings()
		return

	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("Could not open settings file for read: " + SETTINGS_PATH)
		return

	var txt := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed.keys():
			data[k] = parsed[k]
	else:
		save_settings()


func apply_audio() -> void:
	_set_bus_linear("Master", float(data["master_volume"]))
	_set_bus_linear("Music", float(data["music_volume"]))
	_set_bus_linear("SFX", float(data["sfx_volume"]))


func apply_controls_to_player(player: Node = null) -> void:
	if player == null:
		player = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("apply_control_settings"):
		return
	var sensitivity := float(get_value("mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY))
	var fov := clampf(float(get_value("camera_fov", DEFAULT_CAMERA_FOV)), 40.0, MAX_CAMERA_FOV)
	player.apply_control_settings(sensitivity, fov)


func mouse_sensitivity_to_look_speed(mouse_sensitivity: float) -> float:
	var sens := maxf(mouse_sensitivity, 0.001)
	return REFERENCE_LOOK_SPEED * (sens / DEFAULT_MOUSE_SENSITIVITY)


func get_movement_profile() -> MovementProfile:
	var raw := str(get_value("movement_profile", "production")).to_lower()
	if raw in ["develop", "development", "testing", "test", "debug"]:
		return MovementProfile.DEVELOP
	return MovementProfile.PRODUCTION


func set_movement_profile(profile: MovementProfile) -> void:
	data["movement_profile"] = "develop" if profile == MovementProfile.DEVELOP else "production"


func get_movement_profile_display_name() -> String:
	return "Develop" if get_movement_profile() == MovementProfile.DEVELOP else "Production"


func get_walk_speed() -> float:
	return DEVELOP_WALK_SPEED if get_movement_profile() == MovementProfile.DEVELOP else PRODUCTION_WALK_SPEED


func get_sprint_speed() -> float:
	return DEVELOP_SPRINT_SPEED if get_movement_profile() == MovementProfile.DEVELOP else PRODUCTION_SPRINT_SPEED


func get_freefly_speed() -> float:
	return DEVELOP_FREEFLY_SPEED if get_movement_profile() == MovementProfile.DEVELOP else 0.0


func get_jump_velocity() -> float:
	return DEVELOP_JUMP_VELOCITY if get_movement_profile() == MovementProfile.DEVELOP else PRODUCTION_JUMP_VELOCITY


func is_freefly_enabled() -> bool:
	return get_movement_profile() == MovementProfile.DEVELOP


func apply_movement_to_player(player: Node = null) -> void:
	if player == null:
		player = GameManager.get_player()
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("apply_movement_profile"):
		player.apply_movement_profile()


func _set_bus_linear(bus_name: String, value: float) -> void:
	var id := AudioServer.get_bus_index(bus_name)
	if id != -1:
		AudioServer.set_bus_volume_linear(id, clamp(value, 0.0, 1.0))


func _apply_display() -> void:
	var fs: bool = bool(get_value("fullscreen", false))
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
