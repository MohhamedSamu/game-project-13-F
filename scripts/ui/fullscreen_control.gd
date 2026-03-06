extends CheckButton

func _ready() -> void:
	# Carga el setting guardado (default: false)
	var fs: bool = bool(Settings.get_value("fullscreen", false))
	button_pressed = fs
	_apply_fullscreen(fs)

func _on_toggled(toggled_on: bool) -> void:
	Settings.set_value("fullscreen", toggled_on)
	Settings.save_settings()
	_apply_fullscreen(toggled_on)

func _apply_fullscreen(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
