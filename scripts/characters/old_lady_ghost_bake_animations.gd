@tool
extends EditorScript
## Editor > Ejecutar script para regenerar old_lady_ghost_animations.tres

const OUTPUT_PATH := "res://scenes/characters/old_lady_ghost/old_lady_ghost_animations.tres"


func _run() -> void:
	var library: AnimationLibrary = OldLadyGhostBake.build_animation_library()
	if library == null or library.get_animation_list().is_empty():
		push_error("OldLadyGhostBake: no se pudo construir la biblioteca.")
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("OldLadyGhostBake: error al guardar (%s)." % err)
		return
	print(
		"OldLadyGhostBake: guardado en %s (%d animaciones)."
		% [OUTPUT_PATH, library.get_animation_list().size()]
	)
