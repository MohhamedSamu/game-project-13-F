extends SceneTree

const OUTPUT_PATH := "res://scenes/characters/gas_station_npc/character_09_animations.tres"


func _init() -> void:
	var library: AnimationLibrary = Character09Bake.build_animation_library()
	if library == null:
		push_error("Character09Bake CLI: no se pudo construir la biblioteca.")
		quit(1)
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("Character09Bake CLI: error al guardar (%s)." % err)
		quit(1)
		return
	print("Character09Bake CLI: guardado en %s (%d animaciones)." % [
		OUTPUT_PATH,
		library.get_animation_list().size(),
	])
	quit()
