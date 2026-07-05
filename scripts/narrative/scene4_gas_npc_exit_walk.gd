extends Node
## Conecta el jumpscare de salida del baño con Scene4BathroomExitSetup del nivel.

@export var jumpscare_path: NodePath
@export var setup_path: NodePath = ^"../Scene4BathroomExitSetup"

var _awaiting_post_dialogue_exit: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_connect_jumpscare")


func _connect_jumpscare() -> void:
	var setup := get_node_or_null(setup_path) as Scene4BathroomExitSetup
	var jumpscare := get_node_or_null(jumpscare_path) as SoftJumpscareSetup
	if jumpscare == null:
		push_warning("Scene4GasNpcExitWalk: no se encontró SoftJumpscareSetup.")
		return
	if setup == null:
		push_warning("Scene4GasNpcExitWalk: asigna Scene4BathroomExitSetup en el nivel.")
		return

	if jumpscare.require_flag.is_empty():
		jumpscare.require_flag = "bathroom_sink_horror_done"
	if jumpscare.trigger_flag.is_empty():
		jumpscare.trigger_flag = "scene4_bathroom_exit_jumpscare_done"
	setup.apply_to_jumpscare(jumpscare)
	jumpscare.refresh_armed_state()

	if not jumpscare.jumpscare_starting.is_connected(_on_jumpscare_starting):
		jumpscare.jumpscare_starting.connect(_on_jumpscare_starting)
	if not jumpscare.jumpscare_dialogue_finished.is_connected(_on_jumpscare_dialogue_finished):
		jumpscare.jumpscare_dialogue_finished.connect(_on_jumpscare_dialogue_finished)
	if not jumpscare.jumpscare_triggered.is_connected(_on_jumpscare_triggered):
		jumpscare.jumpscare_triggered.connect(_on_jumpscare_triggered)

	_log_scene4_setup(jumpscare, setup)


func _log_scene4_setup(jumpscare: SoftJumpscareSetup, setup: Scene4BathroomExitSetup) -> void:
	var spawn := setup.get_run_start_marker()
	var arrival := setup.get_scare_stop_marker()
	var scene := get_tree().current_scene
	var npc := scene.find_child("GasStationNPC", true, false) as GasStationNPC if scene else null
	var trigger_zone := jumpscare.get_node_or_null("TriggerZone") as Node3D
	var spawn_pos := spawn.global_position if spawn != null and spawn.is_inside_tree() else Vector3.ZERO
	var arrival_pos := arrival.global_position if arrival != null and arrival.is_inside_tree() else Vector3.ZERO
	print(
		"Scene4BathroomExitSetup: listo | trigger=%s | spawn=%s | llegada=%s | npc=%s"
		% [
			trigger_zone.global_position if trigger_zone != null and trigger_zone.is_inside_tree() else jumpscare.global_position,
			spawn_pos,
			arrival_pos,
			npc.global_position if npc != null and npc.is_inside_tree() else Vector3.ZERO,
		]
	)


func _on_jumpscare_triggered() -> void:
	_awaiting_post_dialogue_exit = true
	_connect_dialogue_finished_fallback()


func _connect_dialogue_finished_fallback() -> void:
	if DialogueController.dialogue_finished.is_connected(_on_dialogue_closed_fallback):
		DialogueController.dialogue_finished.disconnect(_on_dialogue_closed_fallback)
	DialogueController.dialogue_finished.connect(_on_dialogue_closed_fallback, CONNECT_ONE_SHOT)


func _on_dialogue_closed_fallback() -> void:
	if not _awaiting_post_dialogue_exit:
		return
	_awaiting_post_dialogue_exit = false
	await Scene4BathroomExitDirector.enter_toilet_cubicle()
	MusicDirector.exit_tension_and_resume_ambient(30.0)


func _on_jumpscare_starting() -> void:
	Scene4BathroomExitDirector.clear_bathroom_presentation()
	_lock_gas_station_npc()
	_awaiting_post_dialogue_exit = true
	_connect_dialogue_finished_fallback()


func _lock_gas_station_npc() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var npc := scene.find_child("GasStationNPC", true, false) as GasStationNPC
	if npc != null:
		npc.prepare_for_bathroom_exit_jumpscare()


func _on_jumpscare_dialogue_finished() -> void:
	_awaiting_post_dialogue_exit = false
	await Scene4BathroomExitDirector.enter_toilet_cubicle()
	MusicDirector.exit_tension_and_resume_ambient(30.0)
