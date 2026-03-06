extends HSlider

func _ready() -> void:
	# Cargar valor guardado al abrir el menú
	value = float(Settings.get_value("mouse_sensitivity", 0.25))

func _on_value_changed(v: float) -> void:
	# Actualiza en memoria (pero no guardes aún si quieres)
	Settings.set_value("mouse_sensitivity", v)

func _on_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Settings.save_settings()
	
