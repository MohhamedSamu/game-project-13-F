@tool
extends EditorScript
## Editor > Ejecutar script para regenerar character_05_animations.tres

const OUTPUT_PATH := "res://scenes/characters/supermarket_npc/character_05_animations.tres"


func _run() -> void:
	var library: AnimationLibrary = preload("res://scripts/characters/character_05_bake.gd").build_animation_library()
	if library == null:
		push_error("Character05Bake: no se pudo construir la biblioteca.")
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("Character05Bake: error al guardar (%s)." % err)
		return
	print("Character05Bake: guardado en %s (%d animaciones)." % [OUTPUT_PATH, library.get_animation_list().size()])
