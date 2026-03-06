extends Node

const SETTINGS_PATH := "user://settings.json"

# Defaults
var data := {
	"mouse_sensitivity": 0.25,  # ajusta a tu gusto (0.1–1.0 típico)
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0
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
		# merge: respeta defaults si faltan keys
		for k in parsed.keys():
			data[k] = parsed[k]
	else:
		# archivo corrupto: vuelve a defaults
		save_settings()

func apply_audio() -> void:
	_set_bus_linear("Master", float(data["master_volume"]))
	_set_bus_linear("Music", float(data["music_volume"]))
	_set_bus_linear("SFX", float(data["sfx_volume"]))

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
