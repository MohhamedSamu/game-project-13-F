extends HSlider


func _ready() -> void:
	_load_saved_value()


func _load_saved_value() -> void:
	var saved := float(Settings.get_value("mouse_sensitivity", Settings.DEFAULT_MOUSE_SENSITIVITY))
	set_block_signals(true)
	value = saved
	set_block_signals(false)


func _on_slider_value_changed(v: float) -> void:
	Settings.set_value("mouse_sensitivity", v)
	Settings.apply_controls_to_player()


func _on_drag_ended(did_change: bool) -> void:
	if did_change:
		Settings.save_settings()
