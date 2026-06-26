class_name NarrativeObjectiveTrigger
extends Node
## Marca un objetivo narrativo al activarse (señal, área, o llamada manual).

@export var objective_id: String = ""
@export var scene_id: String = ""
@export var trigger_once: bool = true
@export var auto_complete_on_ready: bool = false

var _triggered: bool = false


func _ready() -> void:
	if auto_complete_on_ready:
		trigger()


func trigger() -> void:
	if objective_id.is_empty():
		return
	if trigger_once and _triggered:
		return
	_triggered = true
	GameManager.complete_objective(objective_id, scene_id)
