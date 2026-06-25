@tool
extends EditorScript
## Ejecutar desde Editor > Ejecutar script para generar character_09_animations.tres

const OUTPUT_PATH := "res://scenes/characters/gas_station_npc/character_09_animations.tres"


func _run() -> void:
	var library: AnimationLibrary = preload("res://scripts/characters/character_09_bake.gd").build_animation_library()
	if library == null:
		push_error("Character09Bake: no se pudo construir la biblioteca.")
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("Character09Bake: error al guardar (%s)." % err)
		return
	print("Character09Bake: guardado en %s (%d animaciones)." % [OUTPUT_PATH, library.get_animation_list().size()])
