extends Node3D
class_name Scene4BathroomExitSetup
## Markers y puerta de la escena 4. Coloca los Marker3D como hijos o asígnalos en el inspector.

@export_group("Susto NPC")
@export var run_start_marker: Marker3D
@export var scare_stop_marker: Marker3D
@export var dialogue_focus_marker: Marker3D

@export_group("Salida al cubículo")
@export var door_outside_marker: Marker3D
@export var door_inside_marker: Marker3D
@export var cubicle_door_setup: DoorInteractSetup


func _enter_tree() -> void:
	add_to_group(&"scene4_bathroom_exit_setup")


func _ready() -> void:
	_resolve_markers()


func apply_to_jumpscare(jumpscare: SoftJumpscareSetup) -> void:
	if jumpscare == null:
		return
	_resolve_markers()
	if run_start_marker != null and jumpscare.is_inside_tree():
		jumpscare.spawn_marker_path = jumpscare.get_path_to(run_start_marker)
	if scare_stop_marker != null and jumpscare.is_inside_tree():
		jumpscare.arrival_marker_path = jumpscare.get_path_to(scare_stop_marker)
	if dialogue_focus_marker != null and jumpscare.is_inside_tree():
		jumpscare.camera_focus_path = jumpscare.get_path_to(dialogue_focus_marker)


func get_run_start_marker() -> Marker3D:
	_resolve_markers()
	return run_start_marker


func get_scare_stop_marker() -> Marker3D:
	_resolve_markers()
	return scare_stop_marker


func get_dialogue_focus_marker() -> Marker3D:
	_resolve_markers()
	return dialogue_focus_marker


func _resolve_markers() -> void:
	if run_start_marker == null:
		run_start_marker = get_node_or_null("ExitNpcRunStart") as Marker3D
	if scare_stop_marker == null:
		scare_stop_marker = get_node_or_null("ExitNpcScareStop") as Marker3D
	if dialogue_focus_marker == null:
		dialogue_focus_marker = get_node_or_null("ExitNpcDialogueFocus") as Marker3D
	if door_outside_marker == null:
		door_outside_marker = get_node_or_null("ExitNpcDoorOutside") as Marker3D
	if door_inside_marker == null:
		door_inside_marker = get_node_or_null("ExitNpcDoorInside") as Marker3D
	if cubicle_door_setup == null:
		cubicle_door_setup = _find_cubicle_door_setup()


func _find_cubicle_door_setup() -> DoorInteractSetup:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return null
	var gas_station := scene.get_node_or_null("%Gas_station")
	if gas_station == null:
		return null
	return gas_station.get_node_or_null("ToiletCubicleDoor005Setup") as DoorInteractSetup
