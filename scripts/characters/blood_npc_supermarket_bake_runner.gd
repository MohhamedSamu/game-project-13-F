extends SceneTree

const Bake := preload("res://scripts/characters/blood_npc_supermarket_bake.gd")
const OUTPUT_PATH := "res://scenes/characters/blood_npc_supermarket/blood_npc_supermarket_animations.tres"


func _initialize() -> void:
	var library: AnimationLibrary = Bake.build_animation_library()
	if library == null:
		push_error("BloodNpcSupermarketBakeRunner: biblioteca nula.")
		quit(1)
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("BloodNpcSupermarketBakeRunner: error al guardar (%s)." % err)
		quit(1)
		return
	print(
		"BloodNpcSupermarketBakeRunner: guardado %s (%d animaciones: %s)."
		% [OUTPUT_PATH, library.get_animation_list().size(), ", ".join(library.get_animation_list())]
	)
	quit()
