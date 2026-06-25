extends SceneTree

const Bake := preload("res://scripts/characters/character_09_bake.gd")
const OUTPUT_PATH := "res://scenes/characters/gas_station_npc/character_09_animations.tres"


func _initialize() -> void:
	var library: AnimationLibrary = Bake.build_animation_library()
	if library == null:
		push_error("Character09BakeRunner: biblioteca nula.")
		quit(1)
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("Character09BakeRunner: error al guardar (%s)." % err)
		quit(1)
		return
	print(
		"Character09BakeRunner: guardado %s (%d animaciones)."
		% [OUTPUT_PATH, library.get_animation_list().size()]
	)
	quit()
