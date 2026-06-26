class_name LevelSceneProfile
extends Resource
## Define las escenas narrativas disponibles en un nivel.

@export var level_id: String = ""
@export var initial_scene_id: String = "default"
@export var scenes: Array[LevelSceneDefinition] = []


func get_scene_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for scene_def in scenes:
		if scene_def != null and not scene_def.scene_id.is_empty():
			ids.append(scene_def.scene_id)
	return ids


func has_scene(scene_id: String) -> bool:
	if scene_id.is_empty():
		return false
	for scene_def in scenes:
		if scene_def != null and scene_def.scene_id == scene_id:
			return true
	return false
