class_name NpcDialogueBeat
extends Resource
## Un beat de diálogo con condiciones. Los perfiles se evalúan en orden: gana el primero que cumpla.

@export var beat_id: String = ""
@export var dialogue_title: String = "start"

@export_group("Scene")
## Escena narrativa requerida. Vacío = cualquier escena del nivel actual.
@export var required_scene_id: String = ""

@export_group("Objectives")
## Todos deben estar completados. Por defecto se buscan en la escena actual del nivel.
@export var required_objectives: PackedStringArray = PackedStringArray()
## Si no está vacío, los objetivos requeridos se buscan en esta escena concreta.
@export var required_objectives_scene_id: String = ""
## Si true, basta con que el objetivo exista en cualquier escena del nivel.
@export var required_objectives_any_scene: bool = false
@export var forbidden_objectives: PackedStringArray = PackedStringArray()

@export_group("Legacy Flags")
@export var required_flags: PackedStringArray = PackedStringArray()

@export_group("On Play")
@export var play_once: bool = false
@export var complete_objectives_on_finish: PackedStringArray = PackedStringArray()
## Escena narrativa a la que avanzar al terminar este beat (vacío = no cambia).
@export var set_scene_on_finish: String = ""
@export var set_flags_on_finish: Dictionary = {}
