extends HSlider


func _ready() -> void:
	_load_saved_value()


func _load_saved_value() -> void:
	var saved := clampf(
		float(Settings.get_value("camera_fov", Settings.DEFAULT_CAMERA_FOV)),
		min_value,
		max_value
	)
	set_block_signals(true)
	value = saved
	set_block_signals(false)


func _on_value_changed(v: float) -> void:
	Settings.set_value("camera_fov", v)
	Settings.apply_controls_to_player()


func _on_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Settings.save_settings()
