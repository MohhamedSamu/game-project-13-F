extends OptionButton
## Select de CALIDAD GRÁFICA ("Graphics").
## Controla el tamaño del atlas de sombras vía Settings.apply_graphics_quality().
##   Alta   [4096]  (por defecto en partida nueva)
##   Medios [2048]
##   Bajos  [1024]
## El cambio se aplica EN VIVO al seleccionar (no requiere reiniciar el juego).
##
## NOTA: este control ANTES manejaba el "Movement profile" (Production/Develop).
## Esa funcionalidad se deja COMENTADA al final del archivo por si se necesita restaurar.


func _ready() -> void:
	clear()
	add_item("Alta", Settings.GraphicsQuality.HIGH)
	add_item("Medios", Settings.GraphicsQuality.MEDIUM)
	add_item("Bajos", Settings.GraphicsQuality.LOW)
	_load_saved_value()
	item_selected.connect(_on_item_selected)


func _load_saved_value() -> void:
	var quality := Settings.get_graphics_quality()
	for i in range(get_item_count()):
		if get_item_id(i) == quality:
			select(i)
			return


func _on_item_selected(index: int) -> void:
	var quality := get_item_id(index)
	Settings.set_graphics_quality(quality)
	Settings.save_settings()
	Settings.apply_graphics_quality()


# =============================================================================
# FUNCIONALIDAD ANTERIOR (Movement profile) — DESACTIVADA / COMENTADA
# Se conserva por si se quiere volver a alternar Production/Develop en el futuro.
# =============================================================================
#func _ready() -> void:
#	clear()
#	add_item("Production", Settings.MovementProfile.PRODUCTION)
#	add_item("Develop", Settings.MovementProfile.DEVELOP)
#	_load_saved_value()
#	item_selected.connect(_on_item_selected)
#
#
#func _load_saved_value() -> void:
#	var profile := Settings.get_movement_profile()
#	for i in range(get_item_count()):
#		if get_item_id(i) == profile:
#			select(i)
#			return
#
#
#func _on_item_selected(index: int) -> void:
#	var profile := get_item_id(index) as Settings.MovementProfile
#	Settings.set_movement_profile(profile)
#	Settings.save_settings()
#	Settings.apply_movement_to_player()
