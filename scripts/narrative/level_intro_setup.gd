class_name LevelIntroSetup
extends Node
## Inicia la intro en pantalla negra y registra la escena narrativa al terminar.

@export var intro_sequence: LevelIntroSequence
@export var level_id: String = "level_2"
@export var scene_profile: LevelSceneProfile
@export var intro_scene: PackedScene = preload("res://scenes/ui/level_intro_overlay.tscn")


func _ready() -> void:
	if intro_sequence == null:
		_start_narrative_without_intro()
		return
	var intro := intro_scene.instantiate() as LevelIntroController
	if intro == null:
		push_warning("LevelIntroSetup: intro_scene no es LevelIntroController.")
		_start_narrative_without_intro()
		return
	intro.sequence = intro_sequence
	add_child(intro)
	intro.intro_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)


func _on_intro_finished() -> void:
	_start_narrative()


func _start_narrative_without_intro() -> void:
	_start_narrative()


func _start_narrative() -> void:
	var initial_scene := intro_sequence.final_scene_id if intro_sequence != null else "arrival"
	if scene_profile != null and not scene_profile.initial_scene_id.is_empty():
		initial_scene = scene_profile.initial_scene_id
	GameManager.begin_level(level_id, initial_scene, scene_profile)
