class_name LevelSceneDefinition
extends Resource
## Una escena narrativa dentro de un nivel (momento / acto del gameplay).

@export var scene_id: String = ""
@export var display_name: String = ""
## Objetivos conocidos de esta escena (referencia para diseño; no se auto-completan).
@export var objective_ids: PackedStringArray = PackedStringArray()
