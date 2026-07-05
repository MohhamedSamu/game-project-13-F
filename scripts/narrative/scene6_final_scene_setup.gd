extends Node3D
class_name Scene6FinalSceneSetup
## Markers y referencias de la escena final (monstruo + muerta).

@export_group("Personajes")
@export var muerta_path: NodePath = ^"Muerta"
@export var monster_path: NodePath = ^"Monster04"

@export_group("Secuencia")
@export var camera_focus_marker: Marker3D
@export var trigger_zone: JumpscareTriggerZone

@export_group("Final de carretera")
## Ruta a `InvisibleWallEndOfRoad`. Desactivar cuando el compañero habilite el acceso.
@export var invisible_wall_path: NodePath
@export var disable_invisible_wall_on_trigger: bool = false

@export_group("Progreso")
@export var completion_flag: String = "scene6_final_chase_started"
@export var require_flag: String = ""
@export var block_if_flag: String = "scene6_final_chase_started"

var _sequence_running: bool = false


func _enter_tree() -> void:
	add_to_group(&"scene6_final_scene_setup")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_resolve_markers()
	_prepare_characters()
	call_deferred("_connect_trigger")


func get_muerta() -> Node3D:
	return get_node_or_null(muerta_path) as Node3D


func get_monster() -> Node3D:
	return get_node_or_null(monster_path) as Node3D


func get_trigger_zone() -> JumpscareTriggerZone:
	_resolve_markers()
	return trigger_zone


func get_camera_focus_position() -> Vector3:
	_resolve_markers()
	if camera_focus_marker != null and camera_focus_marker.is_inside_tree():
		return camera_focus_marker.global_position
	var monster := get_monster()
	if monster != null and monster.is_inside_tree():
		return monster.global_position + Vector3(0.0, 1.4, 0.0)
	return global_position


func get_invisible_wall() -> StaticBody3D:
	if invisible_wall_path.is_empty():
		return null
	return get_node_or_null(invisible_wall_path) as StaticBody3D


func disable_end_of_road_wall() -> void:
	var wall := get_invisible_wall()
	if wall == null:
		push_warning("Scene6FinalSceneSetup: no se encontró InvisibleWallEndOfRoad.")
		return
	if wall.has_method("set_wall_enabled"):
		wall.call("set_wall_enabled", false)
	else:
		wall.set("wall_enabled", false)


func _connect_trigger() -> void:
	var trigger := get_trigger_zone()
	if trigger == null:
		push_error("Scene6FinalSceneSetup: falta ChaseTrigger bajo FinalScene.")
		return
	if trigger.player_entered.is_connected(_on_player_entered):
		return
	trigger.player_entered.connect(_on_player_entered)
	print(
		"Scene6FinalSceneSetup: trigger escena 6 (final del camino) en ",
		trigger.global_position
	)


func _on_player_entered(player: Node3D) -> void:
	if _sequence_running:
		return
	if not require_flag.is_empty() and not GameManager.get_flag(require_flag):
		return
	if not block_if_flag.is_empty() and GameManager.get_flag(block_if_flag):
		return

	print("Scene6FinalSceneSetup: jugador entró al trigger.")
	_sequence_running = true
	await Scene6FinalChaseDirector.start_sequence(self, player)
	_sequence_running = false


func _prepare_characters() -> void:
	var muerta := get_muerta()
	if muerta != null and muerta.has_method("play_animation"):
		muerta.play_animation("laying_seizure")

	var monster := get_monster()
	if monster != null and monster.has_method("play_animation"):
		call_deferred("_play_monster_idle", monster)


func _play_monster_idle(monster: Node3D) -> void:
	if monster == null or not is_instance_valid(monster):
		return
	if monster.has_method("get_animation_names"):
		var names: PackedStringArray = monster.get_animation_names()
		if names.is_empty():
			call_deferred("_play_monster_idle", monster)
			return
	monster.play_animation("zombie_biting_v2")


func _resolve_markers() -> void:
	if camera_focus_marker == null:
		camera_focus_marker = get_node_or_null("CameraFocus") as Marker3D
	if trigger_zone == null:
		trigger_zone = get_node_or_null("ChaseTrigger") as JumpscareTriggerZone
	if invisible_wall_path.is_empty():
		var scene := get_tree().current_scene if is_inside_tree() else null
		if scene != null:
			var wall := scene.get_node_or_null("invisibleObjects/InvisibleWallEndOfRoad")
			if wall != null and is_inside_tree():
				invisible_wall_path = get_path_to(wall)
