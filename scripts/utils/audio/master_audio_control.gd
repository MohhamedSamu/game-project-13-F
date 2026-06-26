extends HSlider

@export var audio_bus_name: String = "Master"

var audio_bus_id: int = -1

func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)

	var key: String = _bus_to_settings_key(audio_bus_name)
	var saved: float = float(Settings.get_value(key, 1.0))

	value = clamp(saved, min_value, max_value)
	if audio_bus_id != -1:
		AudioServer.set_bus_volume_linear(audio_bus_id, value)

func _on_slider_value_changed(v: float) -> void:
	if audio_bus_id != -1:
		AudioServer.set_bus_volume_linear(audio_bus_id, v)

	var key: String = _bus_to_settings_key(audio_bus_name)
	Settings.set_value(key, v)

func _on_drag_ended(did_change: bool) -> void:
	if not did_change:
		return

	Settings.save_settings()

	# Beep reflejando el bus editado (Master/Music/SFX)
	UISFX.play_change_on_bus(audio_bus_name)

func _bus_to_settings_key(bus_name: String) -> String:
	match bus_name:
		"Master": return "master_volume"
		"Music":  return "music_volume"
		"SFX":    return "sfx_volume"
		_:        return "bus_" + bus_name.to_lower()
