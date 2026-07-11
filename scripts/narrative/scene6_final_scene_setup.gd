extends Node3D
class_name Scene6FinalSceneSetup
## Markers y referencias de la escena final (monstruo + muerta).

@export_group("Personajes")
@export var muerta_path: NodePath = ^"Muerta"
@export var monster_path: NodePath = ^"Monster04"

@export_group("Secuencia")
@export var camera_focus_marker: Marker3D
@export var trigger_zone: JumpscareTriggerZone
@export var atmosphere_path: NodePath = ^"Scene6Atmosphere"
@export var presentation_path: NodePath = ^"Scene6Presentation"

@export_group("Final de carretera")
## Trigger de cruce (solo se desactiva al desbloquear; no vuelve a activarse).
@export var invisible_wall_path: NodePath
## Bloquea el retroceso tras cruzar el trigger de EndOfRoad.
@export var end_of_road_wall_2_path: NodePath
@export var final_scene_wall_1_path: NodePath
@export var final_scene_wall_2_path: NodePath
@export var disable_invisible_wall_on_trigger: bool = false

@export_group("Movimiento")
@export var disable_sprint_in_production_until_chase: bool = true
@export_range(1.0, 1.5, 0.01) var chase_sprint_speed_multiplier: float = 1.18

@export_group("Progreso")
@export var completion_flag: String = "scene6_final_chase_started"
## No muestra personajes ni quita la pared hasta que esta flag exista (fin escena 5).
@export var unlock_require_flag: String = "scene6_final_accessible"
@export var require_flag: String = "scene6_final_accessible"
@export var block_if_flag: String = "scene6_final_chase_started"

@export_group("Pruebas")
## Desbloquea la escena 6 al cruzar InvisibleWallEndOfRoad sin terminar la escena 5.
@export var unlock_on_end_of_road_cross: bool = true

@export_group("Endcam")
@export_range(0.5, 4.0, 0.05) var endcam_height_scale: float = 2.0
@export_range(-0.2, 0.8, 0.01) var endcam_face_look_z: float = 0.18
@export_range(0.8, 3.5, 0.05) var endcam_forward_distance_scale: float = 2.0
@export_range(0.0, 2.0, 0.05) var endcam_forward_pull_offset: float = 0.55
@export_range(-1.0, 1.0, 1.0) var endcam_forward_axis_sign: float = 1.0
@export_range(0.0, 1.0, 0.05) var endcam_look_level_blend: float = 0.8
@export var endcam_catch_fade_enabled: bool = true

@export_group("Endcam Impacto / Sangre")
@export_range(7.5, 9.0, 0.05) var endcam_ground_impact_time: float = 8.05
@export_range(0.0, 0.8, 0.01) var endcam_blood_fade_in: float = 0.08
@export_range(0.0, 1.5, 0.02) var endcam_blood_intensity: float = 1.05
@export_range(0.0, 1.0, 0.02) var endcam_blood_drip_amount: float = 0.9
@export_range(0.0, 1.0, 0.02) var endcam_blood_splat_amount: float = 1.0
@export_range(0.0, 1.0, 0.02) var endcam_blood_edge_pool: float = 0.78

@export_group("Endcam Mordida")
@export_range(0.04, 0.55, 0.01) var endcam_eating_speed_scale: float = 0.12
@export_range(0.0, 1.4, 0.05) var endcam_eating_approach_distance: float = 0.72
@export_range(0.2, 2.5, 0.05) var endcam_eating_approach_duration: float = 1.15
## Distancia horizontal final cámara→monstruo (más bajo = más cerca / más centrado).
@export_range(0.35, 2.5, 0.05) var endcam_eating_target_camera_distance: float = 0.95
## Empuje lateral extra en espacio de cámara (+derecha / -izquierda).
@export_range(-0.8, 0.8, 0.05) var endcam_eating_lateral_bias: float = 0.0

@export_group("Endcam Insta Pickup")
@export_range(2.0, 5.0, 0.05) var endcam_pickup_scream_duration: float = 3.0
@export_range(22.0, 55.0, 1.0) var endcam_pickup_scream_fov: float = 34.0
@export_range(0.0, 4.0, 0.05) var endcam_pickup_camera_local_x: float = 0.0
@export_range(0.5, 4.5, 0.02) var endcam_pickup_camera_local_y: float = 3.5
@export_range(-1.0, 4.0, 0.05) var endcam_pickup_camera_local_z: float = 2.5
@export_range(0.5, 4.5, 0.02) var endcam_pickup_camera_look_local_y: float = 3.5
@export_range(0.18, 0.85, 0.02) var endcam_pickup_face_distance_from_camera: float = 0.48
@export_range(1.2, 2.5, 0.05) var endcam_pickup_face_look_height: float = 2.05
@export_range(-0.1, 0.35, 0.01) var endcam_pickup_face_vertical_offset: float = 0.1

var _sequence_running: bool = false
var _access_unlocked: bool = false
var _saved_can_sprint: bool = true
var _sprint_locked: bool = false
var _saved_sprint_speed: float = -1.0
var _chase_sprint_boost_active: bool = false


func _enter_tree() -> void:
	add_to_group(&"scene6_final_scene_setup")


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_resolve_markers()
	_hide_characters()
	if unlock_require_flag.is_empty() or GameManager.get_flag(unlock_require_flag):
		call_deferred("unlock_final_scene_access")
	elif unlock_on_end_of_road_cross:
		call_deferred("_prepare_dev_end_of_road_entry")
	call_deferred("_connect_trigger")


func unlock_final_scene_access() -> void:
	if _access_unlocked:
		return
	_access_unlocked = true
	if not unlock_require_flag.is_empty():
		GameManager.set_flag(unlock_require_flag, true)
	_reveal_characters()
	_begin_post_scene_5_access()
	_arm_final_atmosphere()
	_begin_zone_presentation()


func _begin_post_scene_5_access() -> void:
	_set_wall_enabled(get_final_scene_wall_1(), true)
	_set_wall_enabled(get_final_scene_wall_2(), false)
	_set_wall_enabled(get_end_of_road_wall_2(), false)
	disable_end_of_road_wall()
	_lock_production_sprint()


func on_end_of_road_crossed() -> void:
	_set_wall_enabled(get_end_of_road_wall_2(), true)
	_set_wall_enabled(get_final_scene_wall_2(), true)
	_set_wall_enabled(get_final_scene_wall_1(), false)


func ensure_unlocked_from_end_of_road_cross() -> void:
	if not unlock_on_end_of_road_cross or _access_unlocked:
		return
	unlock_final_scene_access()


func _prepare_dev_end_of_road_entry() -> void:
	if _access_unlocked:
		return
	_set_wall_enabled(get_final_scene_wall_1(), true)
	_set_wall_enabled(get_final_scene_wall_2(), false)
	_set_wall_enabled(get_end_of_road_wall_2(), false)
	disable_end_of_road_wall()
	_arm_dev_wall_crossing()


func _arm_dev_wall_crossing() -> void:
	var atmosphere := get_atmosphere()
	var wall := get_invisible_wall()
	if atmosphere == null or wall == null:
		return
	atmosphere.begin_scene_6_zone(wall)


func begin_chase_access() -> void:
	_set_wall_enabled(get_end_of_road_wall_2(), false)
	_unlock_production_sprint()
	_apply_chase_sprint_boost()


func end_chase_access() -> void:
	_restore_chase_sprint_boost()


func _hide_characters() -> void:
	_set_character_visible(get_muerta(), false)
	_set_character_visible(get_monster(), false)


func _reveal_characters() -> void:
	_set_character_visible(get_muerta(), true)
	_set_character_visible(get_monster(), true)
	_prepare_characters()


func _set_character_visible(character: Node3D, should_show: bool) -> void:
	if character == null:
		return
	character.visible = should_show
	_set_visual_instances_visible(character, should_show)


func _set_visual_instances_visible(node: Node, should_show: bool) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = should_show
	for child in node.get_children():
		_set_visual_instances_visible(child, should_show)


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


func get_atmosphere() -> Scene6FinalAtmosphere:
	return get_node_or_null(atmosphere_path) as Scene6FinalAtmosphere


func get_presentation() -> Scene6FinalPresentation:
	return get_node_or_null(presentation_path) as Scene6FinalPresentation


func get_endcam_height_scale() -> float:
	return endcam_height_scale


func get_endcam_face_look_z() -> float:
	return endcam_face_look_z


func get_endcam_forward_distance_scale() -> float:
	return endcam_forward_distance_scale


func get_endcam_forward_pull_offset() -> float:
	return endcam_forward_pull_offset


func get_endcam_forward_axis_sign() -> float:
	return endcam_forward_axis_sign


func get_endcam_look_level_blend() -> float:
	return endcam_look_level_blend


func get_endcam_catch_fade_enabled() -> bool:
	return endcam_catch_fade_enabled


func get_endcam_ground_impact_time() -> float:
	return endcam_ground_impact_time


func get_endcam_blood_fade_in() -> float:
	return endcam_blood_fade_in


func get_endcam_blood_intensity() -> float:
	return endcam_blood_intensity


func get_endcam_blood_drip_amount() -> float:
	return endcam_blood_drip_amount


func get_endcam_blood_splat_amount() -> float:
	return endcam_blood_splat_amount


func get_endcam_blood_edge_pool() -> float:
	return endcam_blood_edge_pool


func get_endcam_eating_speed_scale() -> float:
	return endcam_eating_speed_scale


func get_endcam_eating_approach_distance() -> float:
	return endcam_eating_approach_distance


func get_endcam_eating_approach_duration() -> float:
	return endcam_eating_approach_duration


func get_endcam_eating_target_camera_distance() -> float:
	return endcam_eating_target_camera_distance


func get_endcam_eating_lateral_bias() -> float:
	return endcam_eating_lateral_bias


func get_endcam_pickup_scream_duration() -> float:
	return endcam_pickup_scream_duration


func get_endcam_pickup_scream_fov() -> float:
	return endcam_pickup_scream_fov


func get_endcam_pickup_face_distance_from_camera() -> float:
	return endcam_pickup_face_distance_from_camera


func get_endcam_pickup_grab_distance() -> float:
	return endcam_pickup_face_distance_from_camera


func get_endcam_pickup_face_look_height() -> float:
	return endcam_pickup_face_look_height


func get_endcam_pickup_face_height() -> float:
	return endcam_pickup_face_look_height


func get_endcam_pickup_face_vertical_offset() -> float:
	return endcam_pickup_face_vertical_offset


func get_endcam_pickup_camera_local_x() -> float:
	return endcam_pickup_camera_local_x


func get_endcam_pickup_camera_local_y() -> float:
	return endcam_pickup_camera_local_y


func get_endcam_pickup_camera_local_z() -> float:
	return endcam_pickup_camera_local_z


func get_endcam_pickup_camera_look_local_y() -> float:
	return endcam_pickup_camera_look_local_y


func _begin_zone_presentation() -> void:
	var presentation := get_presentation()
	if presentation == null:
		return
	presentation.begin_zone(get_monster())


func _arm_final_atmosphere() -> void:
	var atmosphere := get_atmosphere()
	if atmosphere == null:
		return
	atmosphere.begin_scene_6_zone(get_invisible_wall())


func get_invisible_wall() -> StaticBody3D:
	if invisible_wall_path.is_empty():
		return null
	return get_node_or_null(invisible_wall_path) as StaticBody3D


func get_end_of_road_wall_2() -> StaticBody3D:
	if end_of_road_wall_2_path.is_empty():
		return null
	return get_node_or_null(end_of_road_wall_2_path) as StaticBody3D


func get_final_scene_wall_1() -> StaticBody3D:
	if final_scene_wall_1_path.is_empty():
		return null
	return get_node_or_null(final_scene_wall_1_path) as StaticBody3D


func get_final_scene_wall_2() -> StaticBody3D:
	if final_scene_wall_2_path.is_empty():
		return null
	return get_node_or_null(final_scene_wall_2_path) as StaticBody3D


func disable_end_of_road_wall() -> void:
	_set_wall_enabled(get_invisible_wall(), false)


func _set_wall_enabled(wall: StaticBody3D, enabled: bool) -> void:
	if wall == null:
		return
	if wall.has_method("set_wall_enabled"):
		wall.call("set_wall_enabled", enabled)
	else:
		wall.set("wall_enabled", enabled)


func _lock_production_sprint() -> void:
	if not disable_sprint_in_production_until_chase:
		return
	if Settings.get_movement_profile() != Settings.MovementProfile.PRODUCTION:
		return
	var player := GameManager.get_player()
	if player == null:
		return
	if "can_sprint" in player:
		_saved_can_sprint = bool(player.get("can_sprint"))
		player.set("can_sprint", false)
		_sprint_locked = true


func _unlock_production_sprint() -> void:
	if not _sprint_locked:
		return
	var player := GameManager.get_player()
	if player == null:
		_sprint_locked = false
		return
	if "can_sprint" in player:
		player.set("can_sprint", _saved_can_sprint)
	_sprint_locked = false


func _apply_chase_sprint_boost() -> void:
	if _chase_sprint_boost_active:
		return
	var player := GameManager.get_player()
	if player == null or not ("sprint_speed" in player):
		return
	_saved_sprint_speed = float(player.get("sprint_speed"))
	player.set("sprint_speed", _saved_sprint_speed * chase_sprint_speed_multiplier)
	_chase_sprint_boost_active = true


func _restore_chase_sprint_boost() -> void:
	if not _chase_sprint_boost_active:
		return
	var player := GameManager.get_player()
	if player != null and _saved_sprint_speed >= 0.0 and "sprint_speed" in player:
		player.set("sprint_speed", _saved_sprint_speed)
	_saved_sprint_speed = -1.0
	_chase_sprint_boost_active = false


func _connect_trigger() -> void:
	var trigger := get_trigger_zone()
	if trigger == null:
		return
	if trigger.player_entered.is_connected(_on_player_entered):
		return
	trigger.player_entered.connect(_on_player_entered)


func _on_player_entered(player: Node3D) -> void:
	if _sequence_running:
		return
	if not require_flag.is_empty() and not GameManager.get_flag(require_flag):
		return
	if not block_if_flag.is_empty() and GameManager.get_flag(block_if_flag):
		return

	_sequence_running = true
	var atmosphere := get_atmosphere()
	if atmosphere != null:
		atmosphere.begin_chase_lamps()
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
	if end_of_road_wall_2_path.is_empty():
		var scene := get_tree().current_scene if is_inside_tree() else null
		if scene != null:
			var wall := scene.get_node_or_null("invisibleObjects/InvisibleWallEndOfRoad2")
			if wall != null and is_inside_tree():
				end_of_road_wall_2_path = get_path_to(wall)
	if final_scene_wall_1_path.is_empty():
		var scene := get_tree().current_scene if is_inside_tree() else null
		if scene != null:
			var wall := scene.get_node_or_null("invisibleObjects/InvisibleWallFinalScene1")
			if wall != null and is_inside_tree():
				final_scene_wall_1_path = get_path_to(wall)
	if final_scene_wall_2_path.is_empty():
		var scene := get_tree().current_scene if is_inside_tree() else null
		if scene != null:
			var wall := scene.get_node_or_null("invisibleObjects/InvisibleWallFinalScene2")
			if wall != null and is_inside_tree():
				final_scene_wall_2_path = get_path_to(wall)
