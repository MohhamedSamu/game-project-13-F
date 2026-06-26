extends Node
## Sincroniza una farola con el soft jumpscare: estable al aparecer el payaso,
## parpadeo al ascender, apagón breve al llegar arriba y estable al final.

@export var lamp_path: NodePath
@export var jumpscare_path: NodePath
@export_range(0.25, 8.0, 0.1) var blackout_duration: float = 2.0

var _lamp: StreetLampController
var _jumpscare: SoftJumpscareSetup


func _ready() -> void:
	_jumpscare = get_node_or_null(jumpscare_path) as SoftJumpscareSetup
	_lamp = get_node_or_null(lamp_path) as StreetLampController
	if _jumpscare == null:
		push_warning("JumpscareLampSequence: asigna jumpscare_path.")
		return
	if _lamp == null:
		push_warning("JumpscareLampSequence: asigna lamp_path.")
		return
	_jumpscare.jumpscare_triggered.connect(_on_jumpscare_triggered)
	_jumpscare.jumpscare_rise_started.connect(_on_jumpscare_rise_started)
	_jumpscare.jumpscare_rise_finished.connect(_on_jumpscare_rise_finished)


func _on_jumpscare_triggered() -> void:
	_lamp.set_stable()


func _on_jumpscare_rise_started() -> void:
	_lamp.set_flickering()


func _on_jumpscare_rise_finished() -> void:
	_run_blackout_sequence()


func _run_blackout_sequence() -> void:
	if _lamp == null:
		return
	_lamp.set_off()
	await get_tree().create_timer(blackout_duration).timeout
	if is_instance_valid(_lamp):
		_lamp.set_stable()
