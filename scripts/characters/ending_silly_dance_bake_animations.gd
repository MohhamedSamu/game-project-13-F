@tool
extends EditorScript
## Editor > Ejecutar script: regenera silly_dance en bibliotecas .tres y caches .res.


const SILLY_DANCE_ANIM := "silly_dance"

const LIBRARY_OUTPUTS: Array[Dictionary] = [
	{
		"label": "Character09",
		"output": "res://scenes/characters/gas_station_npc/character_09_animations.tres",
	},
	{
		"label": "Character05",
		"output": "res://scenes/characters/supermarket_npc/character_05_animations.tres",
	},
	{
		"label": "OldLadyGhost",
		"output": "res://scenes/characters/old_lady_ghost/old_lady_ghost_animations.tres",
	},
]

const CACHE_OUTPUTS: Array[Dictionary] = [
	{
		"fbx": "res://assets/characters/policeNpc/animations/silly_dance.fbx",
		"output": "res://assets/characters/policeNpc/animations/silly_dance.res",
		"skeleton_path": "Skeleton3D",
	},
	{
		"fbx": "res://assets/characters/clown/animations/Silly Dancing (1).fbx",
		"output": "res://assets/characters/clown/animations/silly_dance.res",
		"skeleton_path": "Skeleton3D",
	},
	{
		"fbx": "res://assets/characters/mounstro_final/animations/Silly Dancing.fbx",
		"output": "res://assets/characters/mounstro_final/animations/silly_dance.res",
		"skeleton_path": "Skeleton3D",
	},
]


func _run() -> void:
	for target in LIBRARY_OUTPUTS:
		var library := _build_library(String(target.get("label", "")))
		if library == null:
			push_error("%s: biblioteca nula." % target.get("label", ""))
			continue
		if not library.has_animation(SILLY_DANCE_ANIM):
			push_error("%s: falta '%s'." % [target.get("label", ""), SILLY_DANCE_ANIM])
			continue
		var output_path := String(target.get("output", ""))
		var err := ResourceSaver.save(library, output_path)
		if err != OK:
			push_error("%s: error al guardar %s (%s)." % [target.get("label", ""), output_path, err])
			continue
		print(
			"%s: guardado %s (%d animaciones)."
			% [target.get("label", ""), output_path, library.get_animation_list().size()]
		)

	for target in CACHE_OUTPUTS:
		var anim := MixamoLoopAnimationBake.bake_from_fbx(
			String(target.get("fbx", "")),
			SILLY_DANCE_ANIM,
			String(target.get("skeleton_path", "Skeleton3D")),
			true
		)
		if anim == null:
			push_error("Cache: no se pudo bakear '%s'." % target.get("fbx", ""))
			continue
		var output_path := String(target.get("output", ""))
		if MixamoLoopAnimationBake.save_animation(anim, output_path):
			print("Cache: guardado %s" % output_path)


func _build_library(label: String) -> AnimationLibrary:
	match label:
		"Character09":
			return Character09Bake.build_animation_library()
		"Character05":
			return Character05Bake.build_animation_library()
		"OldLadyGhost":
			return OldLadyGhostBake.build_animation_library()
		_:
			return null
