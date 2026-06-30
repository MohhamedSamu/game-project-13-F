extends SceneTree

const Bake := preload("res://scripts/characters/character_05_bake.gd")
const OUTPUT_PATH := "res://scenes/characters/supermarket_npc/character_05_animations.tres"


func _initialize() -> void:
	var library: AnimationLibrary = Bake.build_animation_library()
	if library == null:
		push_error("Character05BakeRunner: biblioteca nula.")
		quit(1)
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("Character05BakeRunner: error al guardar (%s)." % err)
		quit(1)
		return
	print(
		"Character05BakeRunner: guardado %s (%d animaciones)."
		% [OUTPUT_PATH, library.get_animation_list().size()]
	)
	quit()
