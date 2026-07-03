extends SceneTree

const OUTPUT_PATH := "res://scenes/characters/old_lady_ghost/old_lady_ghost_animations.tres"


func _initialize() -> void:
	var library: AnimationLibrary = OldLadyGhostBake.build_animation_library()
	if library == null or library.get_animation_list().is_empty():
		push_error("OldLadyGhostBakeRunner: biblioteca vacía.")
		quit(1)
		return
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("OldLadyGhostBakeRunner: error al guardar (%s)." % err)
		quit(1)
		return
	print(
		"OldLadyGhostBakeRunner: guardado %s (%d animaciones)."
		% [OUTPUT_PATH, library.get_animation_list().size()]
	)
	quit()
