@tool
extends EditorScript
## Editor > Ejecutar script para regenerar blood_npc_supermarket_animations.tres


const OUTPUT_PATH := "res://scenes/characters/blood_npc_supermarket/blood_npc_supermarket_animations.tres"


func _run() -> void:
	var library: AnimationLibrary = preload(
		"res://scripts/characters/blood_npc_supermarket_bake.gd"
	).build_animation_library()
	if library == null:
		push_error("BloodNpcSupermarketBake: no se pudo construir la biblioteca.")
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("BloodNpcSupermarketBake: error al guardar (%s)." % err)
		return
	print(
		"BloodNpcSupermarketBake: guardado en %s (%d animaciones)."
		% [OUTPUT_PATH, library.get_animation_list().size()]
	)
