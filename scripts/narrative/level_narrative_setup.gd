class_name LevelNarrativeSetup
extends Node
## Colocar en la raíz de un nivel para registrar escenas narrativas al cargar la escena.

@export var level_id: String = "level_2"
@export var scene_profile: LevelSceneProfile
@export var auto_begin_on_ready: bool = true


func _ready() -> void:
	if not auto_begin_on_ready:
		return
	var initial_scene := scene_profile.initial_scene_id if scene_profile != null else "default"
	GameManager.begin_level(level_id, initial_scene, scene_profile)
